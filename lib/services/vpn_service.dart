import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/connection_info.dart';
export '../../data/models/connection_info.dart' show VpnStatus;
import '../../data/models/server.dart';
import '../api/api_client.dart';
import '../data/models/connection_data.dart';
import '../data/models/door_outbound.dart';
import '../data/models/psiphon_settings.dart';
import '../data/models/stall_watch_settings.dart';
import '../utils/link_source.dart';
// Every override of [VpnService.connect] names it.
export '../utils/link_source.dart' show LinkSource;
import '../utils/tls_fragment.dart';
import '../utils/vless_link.dart';
import 'connect_diagnostics.dart';
import 'failure_verdict.dart';
import 'keeper.dart';
import 'psiphon_entries.dart';
import 'stall_watch.dart';
import 'tunnel_channels.dart';
import 'vpn_event_reporter.dart';

/// A fresh id for one connection attempt: 32 hex characters from the
/// platform's secure random.
///
/// Random rather than derived from anything about the phone or the user, so
/// it joins rows from one tap and says nothing else. It lives for the length
/// of the attempt and is never stored.
String newAttemptId() {
  final rng = Random.secure();
  final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
  return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

/// Splits a native status line into the status and, when the platform said
/// why the tunnel went away, the reason.
///
/// The stream carries a bare word ("connected", "disconnected") and, for a
/// teardown Android could explain, "disconnected:killed" and friends. See
/// the REASON_ constants on V2RayVpnService for the vocabulary.
({String status, String? reason}) splitNativeStatus(String raw) {
  final line = raw.trim().toLowerCase();
  final colon = line.indexOf(':');
  if (colon == -1) return (status: line, reason: null);
  final reason = line.substring(colon + 1).trim();
  return (
    status: line.substring(0, colon).trim(),
    reason: reason.isEmpty ? null : reason,
  );
}

/// What the app files when the tunnel died and nothing could say why. iOS
/// has no equivalent of the Android callbacks, so every drop there is this.
const dropReasonUnknown = 'unknown';

/// What the app files when it found the tunnel up and carrying nothing
/// ([StallWatch]). The app itself ends such a session, by moving to another
/// door or taking the tunnel down.
const dropReasonStalled = 'stalled';

/// Service class for managing VPN connections.
///
/// Both platforms start in full VPN mode and then verify traffic (see
/// _trafficFlows):
///   1. Android: through the core's SOCKS5 inbound (port 10808), because
///      the app is left out of its own tunnel
///   2. iOS: with an ordinary request, which the tunnel carries
class VpnService extends ChangeNotifier {
  static final _methodChannel = TunnelChannels.method;
  static final _eventChannel = TunnelChannels.status;

  VpnStatus _status = VpnStatus.disconnected;
  ConnectionInfo? _currentConnection;
  String? _errorMessage;
  bool _isVerifying = false;
  bool _isEnablingVpn = false; // true while switching from proxy → VPN mode
  bool _errorNeedsVpnSettings = false;
  bool _failedOnPermission = false;
  Timer? _connectWatchdog;
  Timer? _heartbeat;

  /// Android's VPN permission dialog is on screen for the current attempt.
  /// Neither the watchdog here nor the connect flow's deadline counts that
  /// time: it is the user reading, not the tunnel failing to start.
  bool _awaitingPermission = false;

  /// Why the platform said the tunnel went away, carried from the status
  /// stream to the event the drop is reported as. Cleared once reported.
  String? _dropReason;

  /// A start that has said nothing for this long is not coming back on its
  /// own. Generous: the core stops the old tunnel, rebuilds the config and
  /// spawns tun2socks before it reports anything.
  static const _connectTimeout = Duration(seconds: 20);

  /// What a start through the backup network gets on top of the network's
  /// own time to come up (PsiphonSettings.establishTimeout): the same
  /// building of the core and the tunnel as any start.
  static const psiphonStartSlack = Duration(seconds: 15);

  /// How long the current start may say nothing: [_connectTimeout], or
  /// longer for the backup network.
  Duration _startTimeout = _connectTimeout;

  VpnStatus get status => _status;
  bool get awaitingPermission => _awaitingPermission;
  ConnectionInfo? get currentConnection => _currentConnection;
  String? get errorMessage => _errorMessage;
  bool get isConnected => _status == VpnStatus.connected;
  bool get isConnecting => _status == VpnStatus.connecting || _isEnablingVpn;
  bool get isVerifying => _isVerifying;

  /// How many passes of the traffic check have failed on the tunnel being
  /// checked now ([isVerifying]). 0 until its first pass has failed, and
  /// whenever no tunnel is being checked.
  ///
  /// A tunnel that works usually passes on its first pass, about a second
  /// after the settle delay. The connect flow leaves a dial for a door its
  /// checklist found open only while the tunnel is not up yet, or once a
  /// pass through it has failed (ConnectFlow._dialLeavable).
  int get trafficMisses => _isVerifying ? _trafficMisses : 0;
  int _trafficMisses = 0;

  /// True when the current error is one the user can only clear from the
  /// system VPN screen, so the UI can offer a shortcut there.
  bool get errorNeedsVpnSettings => _errorNeedsVpnSettings;

  /// Whether the last connect failed because the VPN permission was
  /// refused, or Android would not ask for it. Kept until the next connect,
  /// not cleared with the error, so the connect flow can still tell after
  /// it has cleared the message off the screen.
  bool get failedOnPermission => _failedOnPermission;

  /// Whether the last attempt failed after its tunnel came up: the check
  /// through it carried nothing ([_failVerification]), rather than the
  /// tunnel never starting. Kept until the next connect, like
  /// [failedOnPermission], so the connect flow can read it after the error
  /// is gone. The flow tries one more own door in the same tap after such
  /// a failure (ConnectFlow._anotherOwnDoor).
  bool get failedAfterUp => _failedAfterUp;
  bool _failedAfterUp = false;

  /// The verdict of the last failure's diagnosis, completed by that
  /// failure's own report as soon as its diagnosis is kept. Null before the
  /// first failure. Each failure gets its own, taken by its report before
  /// the report's first wait, so a late report never answers for a newer
  /// failure.
  Completer<FailureVerdict?>? _verdictReady;

  /// What the last failure's diagnosis found ([failureVerdict]), once it
  /// is in, or null when it had none or took longer than [wait]. The
  /// failure itself is on screen before its diagnosis has run, so a caller
  /// that must know whether the phone was offline waits here. The failure
  /// is the one before this call: a dial after it does not change the
  /// answer.
  Future<FailureVerdict?> failureSettled({
    Duration wait = const Duration(seconds: 12),
  }) async {
    final ready = _verdictReady;
    if (ready == null) return _failureVerdict;
    try {
      return await ready.future.timeout(wait);
    } catch (_) {
      return null;
    }
  }

  bool get canConnect =>
      _status == VpnStatus.disconnected || _status == VpnStatus.error;

  VpnService({
    VpnEventReporter? events,
    ConnectDiagnostics? diagnostics,
    PsiphonSettings? Function()? psiphon,
    Future<String?> Function(PsiphonSettings settings)? psiphonEntries,
    @visibleForTesting Future<bool> Function()? trafficCheck,
  }) : _events = events ?? VpnEventReporter(),
       _diagnostics =
           diagnostics ?? ConnectDiagnostics(channel: _methodChannel),
       _psiphon = psiphon ?? _currentPsiphon,
       _psiphonEntries = psiphonEntries ?? PsiphonEntries.instance.fileFor,
       _trafficCheck = trafficCheck {
    // The reporter needs to say whether a batch left through the tunnel,
    // because the backend reads the carrier from the address the request
    // arrived on and that address is our own exit server when it did.
    //
    // On Android it never does. V2RayVpnService excludes this app from the
    // TUN and has to, or its own outbound traffic loops back through it, so
    // a report leaves on the real network whether or not a user is
    // connected. Saying otherwise cost us the carrier on every successful
    // connect, which is the reading the per-carrier rules compare failures
    // against. iOS carries the app's own traffic, so there the tunnel being
    // up is the answer. The backend checks the claim against its own exit
    // addresses either way.
    _events.reportsGoThroughTunnel = () =>
        Platform.isAndroid ? false : isConnected;
    // For the same reason a call that the phone's own network drops can be
    // sent again through the core's SOCKS port, and only while a tunnel is
    // up: with none, nothing listens there.
    ApiClient.tunnelSocksPort = () async =>
        Platform.isAndroid && isConnected ? await _socksPort() : null;
    // The heartbeat's lifetime is exactly the tunnel's, and every path that
    // changes the tunnel's state already notifies. Hanging it off that is
    // one rule in one place instead of a start and a stop in a dozen
    // branches, one of which would eventually be missed.
    addListener(_syncHeartbeat);
    addListener(_syncThroughput);
    addListener(_syncStallWatch);
    _listenToStatusUpdates();
    // Anything queued while the phone was offline goes out at startup.
    unawaited(_events.flush());
  }

  /// Reports transitions to the backend; see VpnEventReporter for why every
  /// call is fire-and-forget.
  final VpnEventReporter _events;

  /// The backup network's settings, read when it is dialled.
  final PsiphonSettings? Function() _psiphon;
  static PsiphonSettings? _currentPsiphon() => PsiphonSettings.current;

  /// The path of the backup network's server list kept on the phone, when
  /// it is the one the settings name (PsiphonEntries.fileFor).
  final Future<String?> Function(PsiphonSettings settings) _psiphonEntries;

  /// Stands in for one pass of the traffic check ([_trafficFlows]) in
  /// tests, where the check itself would need a network.
  final Future<bool> Function()? _trafficCheck;

  /// Whether the tunnel being started, or up, goes through the backup
  /// network (Server.psiphon). Kept with the connection, so an app reopened
  /// over such a tunnel says so too.
  bool get onPsiphon => _currentConnection?.serverId == Server.psiphonId;

  /// Where the backup network's traffic leaves, as two capital letters,
  /// once the tunnel has said. Null before, and on any other tunnel.
  String? get psiphonRegion {
    final strategy = _currentStrategy;
    if (strategy?['src'] != LinkSource.psiphon.wire) return null;
    final region = strategy?['egress'];
    return region is String && _region.hasMatch(region) ? region : null;
  }

  static final _region = RegExp(r'^[A-Z]{2}$');

  /// A client version as the backup network names one: a whole number.
  static final _upgradeVersion = RegExp(r'^[0-9]{1,12}$');

  /// The newer client version the backup network says it has
  /// (`psiphon_upgrade` in [stats]), during a session on it. Null on any
  /// other tunnel, and for anything that is not a version.
  String? _psiphonUpgrade(Map<String, dynamic> stats) {
    if (!onPsiphon) return null;
    final version = stats['psiphon_upgrade'];
    return version is String && _upgradeVersion.hasMatch(version)
        ? version
        : null;
  }

  /// Takes the region the tunnel says the backup network's traffic leaves
  /// from (`psiphon_region`) into the strategy every event of the session
  /// carries. Only the region: nothing else the network says about itself
  /// or about the phone leaves the platform.
  void _notePsiphonRegion(Map<String, dynamic> stats) {
    final strategy = _currentStrategy;
    if (strategy?['src'] != LinkSource.psiphon.wire) return;
    final region = stats['psiphon_region'];
    if (region is! String || !_region.hasMatch(region)) return;
    if (strategy!['egress'] == region) return;
    _currentStrategy = {...strategy, 'egress': region};
    unawaited(_saveConnectionInfo(onlyIfKept: true));
    notifyListeners();
  }

  /// Send whatever reports are waiting on the phone. Called once the
  /// device has registered: until then the backend answers 404 to every
  /// batch, and nothing else would send them before the next event. Also
  /// called on a network change and on a timer (ReportSchedule).
  Future<void> flushReports() => _events.flush();

  /// The reporter this service sends through. ConnectFlow and its door
  /// sweep send their door checks through the same one, so the app has one
  /// reporter that knows whether its requests go through the tunnel.
  VpnEventReporter get reporter => _events;

  int? _socksPortCache;

  /// The core's local SOCKS port, read once from the platform. The core's
  /// default when the platform cannot say.
  Future<int> _socksPort() async {
    final known = _socksPortCache;
    if (known != null) return known;
    try {
      final port = await _methodChannel.invokeMethod<int>('socksPort');
      if (port != null && port > 0) return _socksPortCache = port;
    } catch (e) {
      debugPrint('VpnService: could not read the SOCKS port ($e)');
    }
    return 10808;
  }

  /// Runs the checks that say why a connection failed. Without it every
  /// failure reaches the backend as a bare string and no verdict can be
  /// computed from it, which is what happened for the first two weeks this
  /// existed: the collector was written and nothing ever called it.
  final ConnectDiagnostics _diagnostics;

  /// Running since the tap that started the current attempt.
  ///
  /// One clock rather than a set of timestamps, so every mark is already
  /// the number the report wants: milliseconds since the user asked.
  Stopwatch? _attemptClock;

  /// How far the current attempt had got, and when.
  ///
  /// A tunnel that comes up in twelve seconds and one that comes up in
  /// two are both reported as connected today, so a carrier that has
  /// started shaping us is invisible until users say it feels slow. These
  /// are the marks that make it a number.
  final Map<String, int> _timeline = {};

  /// Record how long the current attempt took to reach [step].
  ///
  /// First mark wins: the platform can repeat a status, and a second
  /// "connected" for the same attempt is the same milestone, not a later
  /// one.
  void _mark(String step) {
    final clock = _attemptClock;
    if (clock == null) return;
    _timeline.putIfAbsent(step, () => clock.elapsedMilliseconds);
  }

  /// The marks so far, or null when there is nothing to say. Copied,
  /// because the next attempt clears the map this came from.
  Map<String, int>? get _timelineReport =>
      _timeline.isEmpty ? null : Map<String, int>.of(_timeline);

  /// What the checks found when the last attempt failed.
  ///
  /// Kept for the screen. The diagnosis was already being collected for
  /// the report and then thrown away, so the app knew "TCP to this server
  /// timed out while the internet works" and told the user "Server not
  /// working, try another".
  Map<String, dynamic>? _lastDiagnosis;

  /// The raw diagnosis behind [failureVerdict], for the details expander
  /// and for the people who screenshot it to us.
  Map<String, dynamic>? get lastDiagnosis =>
      _lastDiagnosis == null ? null : Map<String, dynamic>.of(_lastDiagnosis!);

  FailureVerdict? _failureVerdict;

  /// What went wrong, in a form the screen can turn into one sentence.
  /// Null when nothing has failed, or when the failure carried no
  /// diagnosis to read.
  FailureVerdict? get failureVerdict => _failureVerdict;

  /// Remember what a failure's checks found, and what they mean.
  ///
  /// Set from the reporting path, which is where the diagnosis is already
  /// collected. Running the checks a second time for the screen would
  /// double the cost and could disagree with the report.
  ///
  /// [ready] is the failure's own [_verdictReady], completed with the
  /// verdict.
  ///
  /// [since] is when the failed attempt's tap began ([_tapStartedAt]), read
  /// before the diagnosis, because the next dial replaces it.
  void _keepDiagnosis(
    Map<String, dynamic>? diag,
    String? error,
    Completer<FailureVerdict?>? ready,
    DateTime? since,
  ) {
    _lastDiagnosis = diag;
    final verdict = _failureVerdict = verdictFor(
      diag: diag,
      error: error,
      online: since != null && ApiClient.answeredSince(since),
    );
    if (ready != null && !ready.isCompleted) ready.complete(verdict);
    notifyListeners();
  }

  void _forgetDiagnosis() {
    _lastDiagnosis = null;
    _failureVerdict = null;
  }

  /// When the tap the current attempt belongs to began, from [tapStarted],
  /// or when the attempt began. An answer from our API on the phone's own
  /// network after it says the phone had internet when the attempt failed
  /// ([_keepDiagnosis], verdictFor).
  DateTime? _tapStartedAt;

  /// When the tap the next [connect] belongs to began. The connect flow
  /// sets it just before each dial, and [connect] takes it and clears it,
  /// so a dial that no tap started reads from its own start. A field rather
  /// than an argument of [connect], so the test doubles that override
  /// [connect] keep their shape.
  DateTime? tapStarted;

  /// The link behind the current attempt. Kept because a diagnosis needs the
  /// port and the Reality SNI, and only the link carries them; the host on
  /// its own cannot say which handshake was supposed to happen.
  String? _currentUri;

  /// Host of the server the current attempt dialled, without the port or
  /// the credential. Null when the connection was restored from a running
  /// tunnel and the app no longer knows which server it is.
  String? _currentServerHost;
  // The door the current link goes through, when it is one of this
  // device's own. Travels on every event so the backend can tell a door
  // that failed from a server that failed.
  String? _currentDoor;

  /// Every door the core was given for this tunnel: the one dialled, then
  /// the ones standing by. One entry when the core holds one door.
  List<Server> _doors = const [];

  /// Where in [_doors] the core is now.
  int _doorIndex = 0;

  /// The path key of the door the tunnel was on when the app last saved
  /// the attempt ([_attemptFacts]), put back for an app reopened over a
  /// running tunnel, which has no [_doors]. Null once the app knows its
  /// doors again, or knows the core left that door ([_followDoor]).
  String? _restoredDoorKey;

  /// The time, in the core's milliseconds, of the newest door move already
  /// handled. The core keeps its last moves and hands them all over on
  /// every read, so this is what tells a new move from one already seen.
  int _movesSeenUntil = 0;

  /// Why the core left the door the app last knew it was on, as the core
  /// put it: `failover`, `faster`, `recovered` or `startup`. Null when the
  /// core gave no reason. Set before listeners hear of the move.
  String? _switchReason;

  /// Bytes the core reported outside a heartbeat. Reading its counters
  /// resets them, so these are owed to the next beat.
  int _carriedUp = 0;
  int _carriedDown = 0;

  /// When this session's traffic was verified (the `verified_ms` mark), for
  /// the heartbeat's `verified_s`. Null until it is.
  DateTime? _verifiedAt;

  /// Moves between doors since the connect, and those the core made
  /// because the door it left failed, for the heartbeat. Counted where the
  /// moves are found ([_followDoor]), the ones made while verifying too, so
  /// they can be more than the door_switched rows, which start after it.
  int _moves = 0;
  int _failovers = 0;

  /// The door the tunnel is on, or null before the first connect.
  ///
  /// With standby doors the core can leave the door it was told to dial for
  /// another that works, at connect or later. This follows it.
  Server? get activeDoor =>
      _doorIndex < _doors.length ? _doors[_doorIndex] : null;

  /// The path key (Server.pathKey) of the door the tunnel is on:
  /// [activeDoor]'s, or, in an app reopened over a running tunnel, the one
  /// the attempt kept. Null when neither is known.
  ///
  /// StallRecovery forgets this door when the tunnel stops carrying data.
  /// Until 2.2.0 it read [activeDoor], which a reopened app does not have,
  /// so the search after a dead tunnel dialled the dead door first again.
  String? get activeDoorKey => activeDoor?.pathKey ?? _restoredDoorKey;

  /// Why the core left the previous door for [activeDoor]. A move for
  /// speed is not a failure of the door it left; every other move is.
  String? get switchReason => _switchReason;

  /// One id for everything this tap produces: the tunnel events and the
  /// door checks a diagnosis wrote before them. Made when the user asks to
  /// connect and kept until the next ask.
  ///
  /// Without it a phone that tests six doors and walks through the seventh
  /// writes rows across two tables with nothing joining them, and the order
  /// it tried them in cannot be read back. The attempt, not the event, is
  /// the unit anything learns over.
  String? _currentAttemptId;

  /// The dialling settings behind the current attempt: transport, security,
  /// SNI, the TLS fingerprint the core imitates, and where the link came
  /// from ([LinkSource]). Read off the link once rather than parsed again
  /// on every event.
  Map<String, dynamic>? _currentStrategy;

  /// Where the link [connect] dialled came from. The standby doors next to
  /// one of this device's own doors are its own too (StandbyDoors.pick),
  /// so a move to one of them is [LinkSource.own]. The ones next to a
  /// community link the connect flow fell back on are community links of
  /// the same fallback (StandbyDoors.shared), which the user did not pick
  /// either.
  LinkSource _dialledSource = LinkSource.own;

  /// The [LinkSource] of the door at [index] of the doors the core holds.
  LinkSource _sourceOf(int index) {
    if (index == 0) return _dialledSource;
    final door = _doors[index];
    if (_dialledSource == LinkSource.communityFallback && door.isCommunity) {
      return LinkSource.communityFallback;
    }
    return LinkSource.of(door);
  }

  /// True between the user asking to disconnect and the tunnel confirming
  /// it, so a 'disconnected' from the platform is not mistaken for a drop.
  bool _userDisconnecting = false;

  /// Increased by every connect and every stop. The work an attempt starts
  /// and then waits on (the dial on its way to the platform, the watchdog,
  /// the traffic check) reads it again after each wait, and gives up when
  /// it has changed: the user stopped that attempt, or another replaced it.
  int _attemptRun = 0;

  /// The user stopped the current attempt before its traffic was verified.
  /// It has no connected row, so its end is not recorded as a disconnect.
  bool _stoppedBeforeVerified = false;

  /// Until when the platform may still be finishing a start the user
  /// stopped. See [_lateAfterStop].
  DateTime? _stoppedStartUntil;

  /// The platform has answered the stop that set [_stoppedStartUntil]. Its
  /// "disconnected" for that stop comes after this answer, so one that
  /// comes before it is about something else.
  bool _stopAnswered = false;

  /// Set by a stop during a start, and kept until the next attempt's dial
  /// has reached the platform. A "failed" before then cannot be that
  /// attempt's, because its start has not begun. It is the stopped start's.
  bool _dropFailedUntilDialled = false;

  /// How long after a stop a start can still report. Longer than the 20
  /// seconds [_connectTimeout] gives a start to say anything at all. A
  /// start through the backup network can take longer, and its hold is as
  /// much longer ([_holdAfterStop]).
  static const stoppedStartHold = Duration(seconds: 30);

  /// [stoppedStartHold], or longer for a start that has longer to report.
  Duration get _holdAfterStop {
    final hold = _startTimeout + const Duration(seconds: 10);
    return hold > stoppedStartHold ? hold : stoppedStartHold;
  }

  static String? _hostOf(Server server) {
    // Never an address of the backup network's.
    if (server.isPsiphon) return Server.psiphonHost;
    final hostPort = VlessLink.host(server.connectionUri);
    if (hostPort.isEmpty) return null;
    // IPv6 literals carry colons of their own; only strip a trailing :port.
    final colon = hostPort.lastIndexOf(':');
    if (colon == -1 || hostPort.contains(']') && !hostPort.endsWith(']')) {
      return hostPort.split(']').first.replaceFirst('[', '');
    }
    return hostPort.substring(0, colon);
  }

  /// Take one status line from the platform, in the form the event
  /// channel sends it.
  ///
  /// The listener below calls this rather than doing the work itself, so
  /// a test drives the same path a real status update takes instead of a
  /// copy of it that can drift.
  @visibleForTesting
  void applyNativeStatus(String raw) {
    final line = splitNativeStatus(raw);
    if (_lateAfterStop(line.status)) return;
    if (line.status == 'awaiting_permission') {
      // Not a tunnel state: the attempt stays "connecting" while the user
      // answers the dialog.
      _awaitingPermission = true;
      notifyListeners();
      return;
    }
    if (line.reason != null) _dropReason = line.reason;
    _updateStatus(_parseStatus(line.status));
  }

  /// Whether [status] comes from a start the user already stopped. Such a
  /// status is not shown.
  ///
  /// A stop can reach the platform before its service listens for one, for
  /// example while the link is still being imported. That stop is lost, and
  /// the start reports "connected" a second or two later. The screen then
  /// went back to "Connected" after the user had stopped, with a tunnel up
  /// that the user did not want. So for [stoppedStartHold] after a stop, a
  /// "connected" from the platform is answered with the stop again. Reports
  /// of progress or failure are ignored, because the user is not waiting
  /// for that start and its failure is not theirs.
  ///
  /// A start reports one outcome, so the hold ends at the first "connected"
  /// or "failed". It also ends when the platform confirms the stop with
  /// "disconnected": a start the stop reached reports nothing after that.
  /// A tunnel started after it, from the quick settings tile or by
  /// Android's always-on VPN, then stays up. The next connect ends the
  /// hold too, and [_dropFailedUntilDialled] covers the rest of its wait.
  bool _lateAfterStop(String status) {
    if (status == 'failed' && _dropFailedUntilDialled) {
      _stoppedStartUntil = null;
      return true;
    }
    final until = _stoppedStartUntil;
    if (until == null) return false;
    if (DateTime.now().isAfter(until)) {
      _stoppedStartUntil = null;
      return false;
    }
    switch (status) {
      case 'connected':
        _stoppedStartUntil = null;
        unawaited(_stopPlatform());
        return true;
      case 'failed':
        _stoppedStartUntil = null;
        return true;
      case 'disconnected':
        if (_stopAnswered) _stoppedStartUntil = null;
        return false;
      case 'connecting':
      case 'retrying':
      case 'awaiting_permission':
        return true;
      default:
        return false;
    }
  }

  /// Ask the platform to take the tunnel down. Never throws, and gives up
  /// after 3 seconds, because no caller can do more when the call fails.
  Future<void> _stopPlatform() async {
    try {
      await _methodChannel
          .invokeMethod('disconnect')
          .timeout(const Duration(seconds: 3), onTimeout: () => null);
    } catch (_) {}
  }

  /// How far the current attempt has got. See [_timeline].
  @visibleForTesting
  Map<String, int> get debugTimeline =>
      Map<String, int>.unmodifiable(_timeline);

  /// Listen to native VPN status updates
  void _listenToStatusUpdates() {
    _eventChannel.receiveBroadcastStream().listen(
      (event) => applyNativeStatus(event.toString()),
      onError: (error) {
        _errorMessage = error.toString();
        _updateStatus(VpnStatus.error);
      },
    );

    // Fallback: poll native status after a short delay
    // Catches cases where the initial EventChannel event was missed,
    // or where VPN status was detected but connection info wasn't restored.
    Future.delayed(const Duration(seconds: 2), () async {
      if (_status == VpnStatus.connected && _currentConnection == null) {
        // VPN detected but connection info missing — restore it
        await _restoreConnectionInfo();
        notifyListeners();
      } else if (_status == VpnStatus.disconnected) {
        try {
          final result = await _methodChannel.invokeMethod<String>('getStatus');
          if (result == 'connected') {
            await _restoreConnectionInfo();
            _status = VpnStatus.connected;
            notifyListeners();
          }
        } catch (_) {}
      }
    });
  }

  /// Parse status string from native code
  VpnStatus _parseStatus(String status) {
    switch (status) {
      // switch statement starts here
      case 'connected':
        return VpnStatus.connected;
      case 'connecting':
      case 'retrying':
        return VpnStatus.connecting;
      case 'disconnected':
        return VpnStatus.disconnected;
      case 'failed':
        return VpnStatus.error;
      case 'disconnecting':
        return VpnStatus.disconnecting;
      default:
        return VpnStatus.disconnected;
    }
  }

  /// Update status and notify listeners
  void _updateStatus(VpnStatus newStatus) {
    // Must come first. The guards below deliberately drop the stale
    // "disconnected" that trails a teardown, and a failed start used to arrive
    // as exactly that — so the attempt died silently and the UI sat on
    // "Connecting" forever, offering nothing to connect, cancel or retry.
    if (newStatus == VpnStatus.error) {
      _failConnect(
        _errorMessage ?? 'The tunnel did not start. Try another location.',
      );
      return;
    }

    // During enableVpn: proxy stops (disconnected) then VPN starts (connected)
    // This MUST be checked first because _status is already "connected" from
    // the proxy phase, so the duplicate check below would silently drop the
    // VPN's "connected" event.
    if (_isEnablingVpn) {
      if (newStatus == VpnStatus.connected) {
        // VPN mode is now active — fully connected!
        _mark('vpn_ms');
        _isEnablingVpn = false;
        _isVerifying = false;
        _status = VpnStatus.connected;
        _saveConnectionInfo();
        notifyListeners();
      }
      // Ignore disconnected/connecting from proxy→VPN switch
      return;
    }

    if (_status == newStatus) return;

    // Ignore stale "disconnected" events while connecting to a new server.
    if (_status == VpnStatus.connecting &&
        newStatus == VpnStatus.disconnected) {
      return;
    }

    // Ignore stale native events during verification
    if (_isVerifying && newStatus != VpnStatus.connected) {
      return;
    }

    // Don't let native 'disconnected' overwrite our error (from _failVerification)
    if (_status == VpnStatus.error && newStatus == VpnStatus.disconnected) {
      return;
    }

    final oldStatus = _status;
    _status = newStatus;

    if (newStatus == VpnStatus.connected && oldStatus == VpnStatus.connecting) {
      _mark('tunnel_ms');
      _cancelConnectWatchdog();
      _errorMessage = null;
      // Show "Connected" immediately — don't block the UI
      _status = VpnStatus.connected;
      // Verifying from this same notification. The connect flow reads
      // "connected and not verifying" as a tunnel that carries traffic, and
      // set only inside _verifyTrafficInBackground this came one
      // notification late: a link whose tunnel came up and then carried
      // nothing was called a success, and the flow never tried the next.
      _isVerifying = true;
      _saveConnectionInfo();
      notifyListeners();
      // Verify traffic in the background; disconnect if it fails
      _verifyTrafficInBackground();
      return;
    } else if (newStatus == VpnStatus.connected &&
        oldStatus == VpnStatus.disconnected) {
      // App started with VPN already running — restore connection info
      // Must await before notifying so UI has complete state
      // A tunnel this run did not start is not the one found dead.
      _stall = null;
      _restoreConnectionInfo().then((_) {
        notifyListeners();
      });
      unawaited(checkPrivateDns());
      return; // Don't call notifyListeners() below — the .then() handles it
    } else if (newStatus == VpnStatus.disconnected) {
      _cancelConnectWatchdog();
      final wasUp =
          oldStatus == VpnStatus.connected ||
          oldStatus == VpnStatus.disconnecting;
      if (wasUp) {
        // The one transition nobody else reports: a tunnel that was up and
        // is not any more. The user asked for it, or something took it —
        // and which of the four things it was decides what to fix, so the
        // reason travels both as the error string the digest groups on and
        // as a field the rules can read.
        final reason = _dropReason ?? dropReasonUnknown;
        final host = _currentServerHost;
        final uri = _currentUri;
        final duration = _currentConnection?.duration;
        // The last chance to collect this session's sites. A session shorter
        // than heartbeatInterval never reached a periodic beat, so without
        // this its sites would be dropped with the tunnel. On Android the app
        // is outside its own tunnel, so this leaves over the plain network.
        unawaited(_reportSites());
        if (_userDisconnecting) {
          // An attempt the user stopped before it was verified has no
          // connected row to close, like one replaced in [connect].
          // Nor one already reported as dropped because it carried
          // nothing ([_reportStall]).
          if (!_stoppedBeforeVerified && _stall == null) {
            unawaited(
              _events.record(
                VpnEventType.disconnected,
                door: _currentDoor,
                attemptId: _currentAttemptId,
                strategy: _currentStrategy,
                serverHost: host,
                duration: duration,
              ),
            );
          }
        } else {
          // The tunnel is already down here, so the probes run on the real
          // network without waiting for anything. On iOS `drop_reason` is
          // always "unknown", which is why it alone was never enough: the
          // platform has no callback saying what took the tunnel, and the
          // checks are the only thing that can answer it.
          // Not twice for a tunnel already reported as dropped because it
          // carried nothing ([_reportStall]).
          if (_stall == null) {
            unawaited(reportDrop(host, uri, duration, reason));
          }
        }
      }
      _dropReason = null;
      _stall = null;
      _userDisconnecting = false;
      _currentConnection = null;
      _isVerifying = false;
      _isEnablingVpn = false;
      _clearConnectionInfo();
    }

    notifyListeners();
  }

  /// How often a live tunnel reports in.
  ///
  /// Five minutes: a beat is about 300 bytes, so twelve an hour costs the
  /// user nothing, and it is short enough that "connected but nothing flows"
  /// shows up in our monitoring before the user has given up and switched
  /// server. Backed by an ordinary timer, so it fires while the app is
  /// running and never wakes a sleeping phone to send one.
  static const heartbeatInterval = Duration(minutes: 5);

  /// How long to wait for the platform's byte counters.
  static const _statsTimeout = Duration(seconds: 5);

  // ── dead tunnel ─────────────────────────────────────────────────────

  /// Watches a live tunnel for one that carries nothing. See [StallWatch].
  late final StallWatch _stallWatch = StallWatch(
    read: _stallCounts,
    probe: _stallProbe,
    onStall: _stalled,
    onThrottle: _throttled,
    onChange: notifyListeners,
  );

  /// What the watch found, from the moment it called this tunnel dead until
  /// the tunnel goes down or another one replaces it. Null otherwise.
  StallFinding? _stall;

  /// Whether the tunnel is up and was found carrying nothing.
  bool get stalled => _stall != null && isConnected;

  /// Whether the tunnel is up and being checked, because one check through
  /// it failed already (StallWatch.doubting). The screen says the
  /// connection is being checked then, not that it is connected.
  bool get checkingTunnel =>
      isConnected && _stall == null && _stallWatch.doubting;

  /// One check of the stall watch. With a download check set
  /// (StallWatchSettings.probeBytes), the tunnel must bring that many bytes
  /// in time, because a throttled tunnel still answers a 204 page; when the
  /// download's page itself refuses, the older check decides.
  ///
  /// The download's time starts once the page's headers have arrived
  /// (MainActivity.throughputSample): the connection to the page and its
  /// answer have their own limits, each [StallWatchSettings.probeTimeout],
  /// and the bytes get that long after them. Until 2.2.0 the setup counted
  /// against the bytes' time, so a tunnel with a slow first round trip
  /// failed checks it would have passed. Hence three limits here, and two
  /// seconds for the platform.
  Future<bool> _stallProbe() async {
    final settings = StallWatchSettings.current;
    if (Platform.isAndroid && settings.probeBytes > 0) {
      Map<Object?, Object?>? sample;
      try {
        sample = await _methodChannel
            .invokeMethod<Map<Object?, Object?>>('throughputSample', {
              'bytes': settings.probeBytes,
              'capMs': settings.probeTimeout.inMilliseconds,
            })
            .timeout(settings.probeTimeout * 3 + const Duration(seconds: 2));
      } catch (e) {
        debugPrint('VpnService: download check failed to run ($e)');
      }
      final passed = StallWatch.downloadPassed(sample, settings.probeBytes);
      if (passed != null) return passed;
    }
    return _trafficFlows();
  }

  /// Told once when a tunnel is found dead, after the drop is filed. Set by
  /// the app once, for StallRecovery, which looks for another door.
  void Function()? onStall;

  /// Told when the stall watch found the tunnel throttled
  /// (StallWatch.triggerThrottle), after the finding is reported. The
  /// tunnel stays up. Set by the app once, for StallRecovery, which checks
  /// the doors and leaves this one ([leaveThrottled]) only for a faster
  /// door, or when its door is not shown open.
  void Function(StallFinding finding)? onThrottle;

  /// Runs the watch exactly while a verified tunnel is up and has not been
  /// found dead, the same way as [_syncHeartbeat].
  void _syncStallWatch() {
    if (StallWatch.enabled &&
        StallWatch.supported &&
        isConnected &&
        !_isVerifying &&
        _stall == null) {
      _stallWatch.start();
      unawaited(_checkKeeperFinding());
    } else {
      _stallWatch.stop();
    }
  }

  /// The attempt [_checkKeeperFinding] last looked at.
  String? _keeperFindingSeen;

  /// A tunnel the keeper found dead while the app was away (Keeper, which
  /// told the user in a notification) is checked again as soon as the app
  /// watches it, rather than at the watch's first minute: a user who opens
  /// the app from that notification is moved to another path at once.
  /// Looked at once per attempt, and only once the attempt is known: an
  /// app reopened over its tunnel puts the attempt back a moment after the
  /// watch can start.
  Future<void> _checkKeeperFinding() async {
    final attempt = _currentAttemptId;
    if (attempt == null || attempt == _keeperFindingSeen) return;
    _keeperFindingSeen = attempt;
    try {
      final prefs = await SharedPreferences.getInstance();
      final found = prefs.getString(Keeper.stalledKey);
      if (found == null) return;
      await prefs.remove(Keeper.stalledKey);
      if (found != attempt) return;
      await _stallWatch.resumed();
    } catch (e) {
      debugPrint('VpnService: could not read the keeper\'s finding ($e)');
    }
  }

  /// Look now, for an app that came to the front with the tunnel up.
  Future<void> checkStall() => _stallWatch.resumed();

  /// The counters since the last read, for the watch. Carried into the next
  /// heartbeat, the way the throughput sample keeps them, so no byte goes
  /// unreported.
  Future<TunnelCounts?> _stallCounts() async {
    final stats = await _tunnelStats();
    if (stats == null) return null;
    _carry(stats);
    _followDoor(stats);
    _stallStats = stats;
    final up = (stats['bytes_up'] as num?)?.toInt();
    final down = (stats['bytes_down'] as num?)?.toInt();
    if (up == null || down == null) return null;
    return (up: up, down: down);
  }

  /// The last reading the watch took, for the carrier it names.
  Map<String, dynamic>? _stallStats;

  void _stalled(StallFinding finding) {
    if (!isConnected || _isVerifying || _stall != null) return;
    _stall = finding;
    _tellOutcome(VpnEventType.dropped);
    unawaited(_reportStall(finding));
    notifyListeners();
    try {
      onStall?.call();
    } catch (e) {
      debugPrint('VpnService: stall listener failed: $e');
    }
  }

  /// The stall watch found the tunnel carrying far less than its own normal,
  /// and every download check failed (StallWatch.triggerThrottle). Until
  /// 2.2.0 that ended the session like a dead tunnel: on 2026-10-23 it made
  /// 106 drops on 72 phones, and the next session carried about half as
  /// much whether it moved to another door or not. The heartbeats before
  /// those drops were mostly as large as the session's own normal.
  ///
  /// Now the finding is reported on a heartbeat of its own, with the bytes
  /// owed to the next one and the finding's facts (StallFinding.facts,
  /// stall_trigger "throttle"), and [onThrottle] is told. No drop is filed
  /// here: the tunnel is left alone unless [onThrottle] leaves it
  /// ([leaveThrottled]).
  void _throttled(StallFinding finding) {
    if (!isConnected || _isVerifying || _stall != null) return;
    unawaited(_reportThrottle(finding));
    try {
      onThrottle?.call(finding);
    } catch (e) {
      debugPrint('VpnService: throttle listener failed: $e');
    }
  }

  Future<void> _reportThrottle(StallFinding finding) async {
    final stats = _stallStats;
    final (up, down) = _takeCarried();
    await _events.record(
      VpnEventType.heartbeat,
      door: _currentDoor,
      attemptId: _currentAttemptId,
      strategy: _currentStrategy,
      serverHost: _currentServerHost,
      duration: _currentConnection?.duration,
      bytesUp: up,
      bytesDown: down,
      diag: {if (stats != null) ..._networkOf(stats), ...finding.facts},
    );
  }

  /// Leave a tunnel the stall watch found throttled ([onThrottle]), because
  /// a door check found a faster door, or did not find its door open
  /// (ConnectFlow.checkThrottled). It ends as a dead tunnel does: the drop
  /// is filed with [finding], and [onStall] runs the search. Nothing when
  /// the tunnel is down, being checked, or already found dead.
  void leaveThrottled(StallFinding finding) => _stalled(finding);

  /// File the dead tunnel as a drop now, while the app runs, rather than
  /// when the session ends: that may be after Android has stopped the app,
  /// or never. Nothing else is filed for the session afterwards, however it
  /// ends. The checks run on the phone's own network, around the tunnel on
  /// Android, so they say whether the server is reachable at all.
  Future<void> _reportStall(StallFinding finding) async {
    // Before the first await, for the reason given in reportVerifyFailure.
    final door = _currentDoor;
    final attemptId = _currentAttemptId;
    final strategy = _currentStrategy;
    final host = _currentServerHost;
    final uri = _currentUri;
    final duration = _currentConnection?.duration;
    final stats = _stallStats;
    final diag = await diagnose(host, uri) ?? <String, dynamic>{};
    await _events.record(
      VpnEventType.dropped,
      door: door,
      attemptId: attemptId,
      strategy: strategy,
      serverHost: host,
      duration: duration,
      error: dropReasonStalled,
      diag: {
        ...diag,
        if (stats != null) ..._networkOf(stats),
        ...finding.facts,
        'drop_reason': dropReasonStalled,
      },
    );
  }

  /// Take down a tunnel found dead, when no other door could replace it.
  /// The drop is on record already, so this files nothing more.
  Future<void> dropStalled() async {
    if (!stalled) return;
    await disconnect();
  }

  @visibleForTesting
  StallWatch get stallWatch => _stallWatch;

  /// What the watch does once its checks fail, for tests, which have no
  /// core to read counters from.
  @visibleForTesting
  void debugStall(StallFinding finding) => _stalled(finding);

  /// What the watch does once the throttle trigger's checks fail, for
  /// tests.
  @visibleForTesting
  void debugThrottle(StallFinding finding) => _throttled(finding);

  // ── throughput sample ───────────────────────────────────────────────

  /// How long after a verified connect to measure the tunnel's speed.
  ///
  /// A shaped tunnel looks connected and passes a trickle, so "connected"
  /// on its own says nothing on day one of a shaping campaign. Thirty
  /// seconds is late enough that the connect itself is over and early
  /// enough to be in the session the user is actually having.
  static const throughputDelay = Duration(seconds: 30);

  /// How much to download for the reading, and the most it may take.
  static const throughputBytes = 1000000;

  /// A quarter of that where the user pays by the megabyte. A tenth of a
  /// percent of the daily allowance is worth a reading; a full percent is
  /// not, and the number is a ratio, so a smaller object measures the
  /// same thing.
  static const throughputBytesMetered = 256000;
  static const throughputCap = Duration(seconds: 10);

  Timer? _throughputTimer;

  /// Once per session: this is a reading about the network, and taking it
  /// repeatedly would spend the user's data to learn the same thing.
  bool _throughputTaken = false;

  /// Whether the user is running a speed test of their own right now.
  ///
  /// Set by the app once, because two downloads at once measure each
  /// other rather than the tunnel, and theirs is the one they are
  /// watching. Left null in tests and anywhere the wiring is absent,
  /// which reads as "no test running".
  bool Function()? speedTestRunning;

  /// Told of each connect, failure and drop as it is reported, whether or
  /// not diagnostics sharing is on. Set by the app once, for ReviewPrompt,
  /// which asks for a rating only after good days with no recent failure.
  void Function(VpnEventType type)? onOutcome;

  void _tellOutcome(VpnEventType type) {
    try {
      onOutcome?.call(type);
    } catch (e) {
      debugPrint('VpnService: outcome listener failed: $e');
    }
  }

  /// Keeps the heartbeat running exactly while the tunnel is up. Called on
  /// every notification, so no state change can leave it running after a
  /// disconnect or stopped through one.
  void _syncHeartbeat() {
    // A tunnel found dead is a session that ended on the backend's books
    // ([_reportStall]). Beats after that would show it as still up.
    if (isConnected && _stall == null) {
      _heartbeat ??= Timer.periodic(
        heartbeatInterval,
        (_) => unawaited(_sendHeartbeat()),
      );
    } else {
      _heartbeat?.cancel();
      _heartbeat = null;
    }
  }

  /// Arms the one throughput reading of this session, and disarms it the
  /// moment the tunnel is not up. Same shape as [_syncHeartbeat], so no
  /// state change can leave a measurement pending over a dead tunnel.
  void _syncThroughput() {
    if (isConnected && !isVerifying) {
      if (_throughputTaken) return;
      _throughputTimer ??= Timer(
        throughputDelay,
        () => unawaited(_sampleThroughput()),
      );
    } else {
      _throughputTimer?.cancel();
      _throughputTimer = null;
    }
  }

  /// Measure what the tunnel is actually carrying, and send it.
  ///
  /// Reported on a heartbeat rather than an event of its own, because the
  /// backend's event type is a fixed set and a beat already means "still
  /// connected, and this is what it carried".
  @visibleForTesting
  Future<void> sampleThroughput() => _sampleThroughput();

  Future<void> _sampleThroughput() async {
    _throughputTimer = null;
    if (_throughputTaken) return;
    // Their download and ours would measure each other rather than the
    // tunnel, and theirs is the one they are watching.
    if (speedTestRunning?.call() ?? false) return;

    _throughputTaken = true;
    // The platform answers with nothing at all when the tunnel is not up,
    // so this is the liveness check as well as the counters the beat
    // needs. Read before the download, because it is what says how much
    // of the user's data the reading may cost.
    final facts = await _tunnelStats();
    if (facts == null) return;
    _carry(facts);
    _followDoor(facts);

    final metered = facts['metered'] == true;
    final kbps = await _measureThroughput(
      metered ? throughputBytesMetered : throughputBytes,
    );
    // The download can take ten seconds, and a tunnel that went down in
    // the middle of it must not send a beat saying it is still up. The
    // bytes read above stay carried for the next beat.
    if (kbps == null || !isConnected) return;

    // Everything carried, the read above included, goes on this beat and
    // is no longer owed to the next. Sending the read here while also
    // carrying it counted those bytes twice.
    final (up, down) = _takeCarried();
    await _events.record(
      VpnEventType.heartbeat,
      door: _currentDoor,
      attemptId: _currentAttemptId,
      strategy: _currentStrategy,
      serverHost: _currentServerHost,
      duration: _currentConnection?.duration,
      bytesUp: up,
      bytesDown: down,
      diag: {'throughput_kbps': kbps, ..._beatFacts(facts)},
    );
    // This beat lands about half a minute in, long before the first periodic
    // one, so draining here gets a short session's sites out while the tunnel
    // is known to be up.
    await _reportSites();
  }

  /// Kilobits per second through the tunnel, or null when the platform
  /// could not measure it.
  ///
  /// The platform does the download, because on Android this app is
  /// excluded from its own tunnel and a request from here would time the
  /// bare carrier and call it the tunnel's speed.
  Future<int?> _measureThroughput(int bytes) async {
    try {
      final raw = await _methodChannel
          .invokeMethod<Map<Object?, Object?>>('throughputSample', {
            'bytes': bytes,
            'capMs': throughputCap.inMilliseconds,
          })
          // The connection and the answer before the bytes have their
          // own limits (MainActivity.throughputSample).
          .timeout(throughputCap * 2 + const Duration(seconds: 5));
      if (raw == null) return null;
      // Since the headers arrived, so the rate is the tunnel's, without the
      // connection's setup (MainActivity.throughputSample).
      final read = (raw['bytes'] as num?)?.toInt() ?? 0;
      final ms = (raw['ms'] as num?)?.toInt() ?? 0;
      if (read <= 0 || ms <= 0) return null;
      return (read * 8) ~/ ms;
    } on MissingPluginException {
      return null; // iOS has no sampler yet
    } catch (_) {
      return null;
    }
  }

  /// One beat: the tunnel is still up, and this is what it carried since the
  /// last one.
  ///
  /// Queued through the same reporter as everything else and flushed at once,
  /// which is safe even mid-incident: on Android the app is excluded from its
  /// own tunnel, so the batch leaves around a tunnel that is carrying nothing.
  ///
  /// A beat with no reading is not sent at all. Reporting zero bytes because
  /// the platform would not answer would be indistinguishable from a stalled
  /// tunnel, which is exactly the thing this is here to detect.
  @visibleForTesting
  Future<void> sendHeartbeat() => _sendHeartbeat();

  Future<void> _sendHeartbeat() async {
    if (!isConnected) return;
    // As the heartbeat, so the session readings close their interval on
    // this read and hand over its block.
    final stats = await _tunnelStats(beat: true);
    if (stats == null) return;
    final read = (stats['bytes_up'] as num?)?.toInt();
    final readDown = (stats['bytes_down'] as num?)?.toInt();
    if (read == null || readDown == null) return;
    _carry(stats);
    final (up, down) = _takeCarried();
    _followDoor(stats);
    await _events.record(
      VpnEventType.heartbeat,
      door: _currentDoor,
      attemptId: _currentAttemptId,
      strategy: _currentStrategy,
      serverHost: _currentServerHost,
      duration: _currentConnection?.duration,
      bytesUp: up,
      bytesDown: down,
      // The carrier travels with every beat, because the backend cannot read
      // it from the address a batch arrives on while the tunnel is up, and a
      // stall that names no carrier says nothing about who is throttling.
      diag: _beatFacts(stats),
    );
    await _reportSites();
  }

  /// The sites drained from the core's log but not yet accepted by the
  /// backend. A drain advances the native cursor, so whatever it returns is
  /// gone from the log; holding it here is what stops a failed send from
  /// losing it. Counts only, same as everything that leaves this class.
  final Map<String, int> _pendingSites = {};

  /// The most distinct sites to hold while the backend cannot be reached.
  /// Matches the backend's own per-report ceiling, so a held batch is never
  /// larger than one it would accept anyway.
  static const maxPendingSites = 2000;

  /// The drain currently running, so a second one queues behind it rather
  /// than overlapping it. Two overlapping drains would each send a snapshot
  /// of [_pendingSites], and the backend adds what it is sent, so the sites
  /// in both snapshots would be counted twice on the very dashboard this
  /// feeds. Serialising is what keeps the counts true.
  Future<void> _sitesReport = Future<void>.value();

  /// Drain the sniffed-domain counts the core logged since the last drain and
  /// send them, for the aggregate Sites view.
  ///
  /// Called from every point where a session can produce counts: the periodic
  /// beat, the one throughput beat, and the end of the session. The last one
  /// matters most, because a session shorter than [heartbeatInterval] never
  /// reaches a periodic beat, and before it was added those sessions reported
  /// nothing at all.
  ///
  /// Queued behind any drain already in flight. The returned future completes
  /// when this one has had its turn, so a caller that awaits it knows its own
  /// counts were offered.
  Future<void> _reportSites() {
    // _drainSites never throws, so the chain cannot break and leave every
    // later drain inheriting a dead future.
    final queued = _sitesReport.then((_) => _drainSites());
    _sitesReport = queued;
    return queued;
  }

  /// One drain and one send. Only ever runs from [_reportSites], one at a
  /// time.
  ///
  /// Anything the backend did not accept stays in [_pendingSites] and goes out
  /// with the next attempt, because the drain already advanced the native
  /// cursor and the log cannot be read twice. Never throws, so a failure here
  /// cannot break the caller or the queue.
  Future<void> _drainSites() async {
    try {
      final raw = await _methodChannel.invokeMethod<Map<Object?, Object?>>(
        'drainSiteStats',
      );
      raw?.forEach((k, v) {
        final host = k?.toString();
        final n = (v as num?)?.toInt() ?? 0;
        if (host == null || host.isEmpty || n <= 0) return;
        // A site already held keeps counting up, so a retry sends the whole
        // session rather than only what arrived since the failure.
        if (_pendingSites.containsKey(host) ||
            _pendingSites.length < maxPendingSites) {
          _pendingSites[host] = (_pendingSites[host] ?? 0) + n;
        }
      });
      if (_pendingSites.isEmpty) return;
      // Sent as one map, so the backend folds a retry and a fresh drain in
      // the same upsert it would have done for either alone.
      final sent = Map.of(_pendingSites);
      if (!await _events.reportDomains(sent)) return;
      // Take off exactly what went, never the whole map. Clearing it would
      // throw away anything that arrived while the send was in flight, which
      // the backend has not seen and the log cannot give back.
      sent.forEach((host, n) {
        final left = (_pendingSites[host] ?? 0) - n;
        if (left > 0) {
          _pendingSites[host] = left;
        } else {
          _pendingSites.remove(host);
        }
      });
    } catch (e) {
      debugPrint('VpnService: site stats report failed: $e');
    }
  }

  /// The link as the platform wants it: the API sends ampersands
  /// HTML-encoded, and sometimes a trailing one.
  static String _sendable(String link) {
    var clean = link.replaceAll('&amp;', '&').trim();
    while (clean.endsWith('&')) {
      clean = clean.substring(0, clean.length - 1);
    }
    return clean;
  }

  /// Asks the core which door it is on. Only when it holds more than one.
  ///
  /// The answer comes with the traffic counters, and reading those resets
  /// them, so the bytes are kept for the next heartbeat.
  Future<void> _learnDoor() async {
    if (_doors.length < 2) return;
    await _readDoor();
  }

  /// Reads the door the core is on, and keeps the bytes that came with it
  /// for the next heartbeat.
  Future<void> _readDoor() async {
    final stats = await _tunnelStats();
    if (stats == null) return;
    _carry(stats);
    _followDoor(stats);
  }

  /// Keeps the bytes in [stats] for the next heartbeat.
  void _carry(Map<String, dynamic> stats) {
    _carriedUp += (stats['bytes_up'] as num?)?.toInt() ?? 0;
    _carriedDown += (stats['bytes_down'] as num?)?.toInt() ?? 0;
  }

  /// The bytes owed to a heartbeat, which is about to send them. Each byte
  /// goes on exactly one beat: the backend adds them up.
  (int, int) _takeCarried() {
    final taken = (_carriedUp, _carriedDown);
    _carriedUp = 0;
    _carriedDown = 0;
    return taken;
  }

  /// Points the current door at the one the core says it is on, and
  /// reports every move the core made since the last read.
  ///
  /// Everything reported from here on carries that door: a heartbeat that
  /// named the dialled door after the core left it would credit a door
  /// that is not carrying the traffic.
  ///
  /// Not through the backup network, which is no door and has no doors to
  /// move between: nothing a reading says about doors is taken from it.
  void _followDoor(Map<String, dynamic> stats) {
    if (onPsiphon) return;
    final group = _doorGroup(stats);
    final index = (stats['door_index'] as num?)?.toInt();
    final moved =
        index != null &&
        index >= 0 &&
        index < _doors.length &&
        index != _doorIndex;
    final from = activeDoor;
    final previous = _doorIndex;
    final moves = group == null ? const <_DoorMove>[] : _newMoves(group);
    var forgot = false;
    if (_doors.isEmpty && index != null && index != _doorIndex) {
      // Reopened over a running tunnel, the app has the door it last knew
      // but not the list of doors (see _restoreConnectionInfo). A core on
      // another door is on one the app cannot name, so the reports name
      // none, as they did before the door was kept.
      _doorIndex = index;
      _currentDoor = null;
      _currentStrategy = null;
      _currentServerHost = null;
      _currentUri = null;
      _restoredDoorKey = null;
      forgot = true;
    }
    if (group != null) {
      _moves += moves.length;
      _failovers += moves.where((m) => m.reason == 'failover').length;
    } else if (moved) {
      _moves++;
    }
    if (moved) {
      _doorIndex = index;
      final door = _doors[index];
      final link = TlsFragment.apply(door.connectionUri);
      _currentUri = link;
      _currentDoor = door.door;
      _currentStrategy = _sourceOf(index).strategy(door, link);
      _currentServerHost = _hostOf(door);
      final left = moves.where((m) => m.from == previous).firstOrNull;
      _switchReason = left?.reason;
    }
    // A move while connecting or verifying shows up in the connected event,
    // which names the door in use. A move after it gets a row of its own, so
    // the switch and the door it left are on record when it happens and not
    // only inferred from the next heartbeat.
    if (isConnected && !_isVerifying) {
      if (group != null) {
        for (final move in moves) {
          unawaited(_reportMove(move, group, stats));
        }
      } else if (moved) {
        unawaited(_reportSwitch(from, index, stats));
      }
    }
    // Kept for a reopened app, which goes on reporting this door and count.
    // A door forgotten is kept as none, or the next reopen would put back
    // the door the core left.
    if (moved || moves.isNotEmpty || forgot) {
      unawaited(_saveConnectionInfo(onlyIfKept: true));
    }
    if (moved) notifyListeners();
  }

  /// What the core's door group says about itself, from a stats reply.
  /// Null when the core holds one door or the reply carries none.
  static Map<String, dynamic>? _doorGroup(Map<String, dynamic> stats) {
    final raw = stats['door_status'];
    if (raw is! String || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  /// The moves in [group] newer than the last one handled, oldest first.
  ///
  /// The core's own first pick has no door it left, so it is not a move.
  /// A move naming a door this tunnel was not given is not reported.
  List<_DoorMove> _newMoves(Map<String, dynamic> group) {
    final out = <_DoorMove>[];
    var newest = _movesSeenUntil;
    for (final raw in (group['switches'] as List?) ?? const []) {
      if (raw is! Map) continue;
      final at = (raw['at'] as num?)?.toInt() ?? 0;
      if (at <= _movesSeenUntil) continue;
      if (at > newest) newest = at;
      final from = (raw['from'] as num?)?.toInt();
      final to = (raw['to'] as num?)?.toInt();
      if (from == null || to == null) continue;
      if (from < 0 || from >= _doors.length) continue;
      if (to < 0 || to >= _doors.length) continue;
      out.add(
        _DoorMove(
          from: from,
          to: to,
          reason: raw['reason'] as String?,
          at: DateTime.fromMillisecondsSinceEpoch(at, isUtc: true),
        ),
      );
    }
    _movesSeenUntil = newest;
    return out;
  }

  /// What the core measured about each door when the app last read it.
  ///
  /// Read at most a few minutes after the move it rides along with, so it
  /// describes the doors around that move, not at its exact moment.
  List<Map<String, dynamic>> _doorStates(Map<String, dynamic> group) => [
    for (final raw in (group['doors'] as List?) ?? const [])
      if (raw is Map &&
          raw['index'] is num &&
          (raw['index'] as num).toInt() < _doors.length)
        {
          ...Map<String, dynamic>.from(raw),
          'door': _doors[(raw['index'] as num).toInt()].door,
          'server_id': _doors[(raw['index'] as num).toInt()].serverId,
        },
  ];

  /// The carrier and network a stats reply carried, for an event that has
  /// no other way to name them. The live feed falls back to whoever owns
  /// the address a batch arrived from, which is not always the carrier.
  static Map<String, dynamic> _networkOf(Map<String, dynamic> stats) => {
    if (stats['carrier'] != null) 'carrier': stats['carrier'],
    if (stats['network'] != null) 'network': stats['network'],
  };

  /// What a heartbeat says besides its bytes: the carrier and network, and
  /// with standby doors each door's measurements and the group's own state
  /// (`ok`, `degraded`, `down`...), so a session's moves can be read
  /// against what the core saw between them. Then how the session has gone
  /// ([_sessionFacts]).
  Map<String, dynamic> _beatFacts(Map<String, dynamic> stats) => {
    ..._networkOf(stats),
    if (!onPsiphon)
      if (_doorGroup(stats) case final group?) ...{
        'door_states': _doorStates(group),
        'switch_count': ?group['switch_count'],
        'group_state': ?group['state'],
      },
    // The backup network's library is built into the app, so a newer one
    // needs a release. The backend counts the phones that hear of one.
    'psiphon_upgrade': ?_psiphonUpgrade(stats),
    ..._sessionFacts(stats),
  };

  /// How good the session has been, not only that it is up (backend #365):
  ///
  /// - `verified_s`: seconds since its traffic was verified
  /// - `moves`, `failovers`: moves between doors since the connect, and
  ///   those away from a door that failed
  /// - `session`: the tunnel process's readings since the last heartbeat,
  ///   as it sent them, when the backend turned them on (see
  ///   SessionMeter.report on the Android side). Totals live only in
  ///   there: the beat's own bytes stay the bytes since the last beat.
  ///
  /// No reconnect count: the app does not reconnect by itself. A new
  /// connect is a new attempt id, which the backend reads from the events.
  Map<String, dynamic> _sessionFacts(Map<String, dynamic> stats) {
    final verified = _verifiedAt;
    final session = stats['session'];
    return {
      if (verified != null)
        'verified_s': max(0, DateTime.now().difference(verified).inSeconds),
      'moves': _moves,
      'failovers': _failovers,
      if (session is Map)
        'session': {
          for (final entry in session.entries)
            entry.key.toString(): entry.value,
        },
    };
  }

  /// [_followDoor] for tests: what a stats reply naming [stats]'s
  /// door_index does.
  @visibleForTesting
  void followDoor(Map<String, dynamic> stats) => _followDoor(stats);

  /// The doors the core holds, as [connect] sets them. For tests that
  /// drive [followDoor] without a platform to connect through.
  @visibleForTesting
  set debugDoors(List<Server> doors) {
    _doors = doors;
    _doorIndex = 0;
    _movesSeenUntil = 0;
    _switchReason = null;
  }

  /// Whether traffic verification is running, for tests that need the
  /// state between "connected" and the connected event.
  @visibleForTesting
  set debugVerifying(bool value) => _isVerifying = value;

  /// When the session's traffic was verified, for tests, where the check
  /// itself would need a network.
  @visibleForTesting
  set debugVerifiedAt(DateTime? at) => _verifiedAt = at;

  /// The end of a check through the tunnel that never answered, for tests,
  /// where the check itself would need a network: the same as after its
  /// deadline.
  @visibleForTesting
  void debugFailVerification(String reason) => _failVerification(reason);

  /// One move the core made, with the reason it gave and when it made it.
  Future<void> _reportMove(
    _DoorMove move,
    Map<String, dynamic> group,
    Map<String, dynamic> stats,
  ) {
    final to = _doors[move.to];
    final from = _doors[move.from];
    return _events.record(
      VpnEventType.doorSwitched,
      door: to.door,
      attemptId: _currentAttemptId,
      strategy: _sourceOf(
        move.to,
      ).strategy(to, TlsFragment.apply(to.connectionUri)),
      serverHost: _hostOf(to),
      at: move.at,
      diag: {
        'from_door': from.door,
        'from_host': _hostOf(from),
        'from_index': move.from,
        'from_server_id': ?from.serverId,
        'door_index': move.to,
        'server_id': ?to.serverId,
        'doors': _doors.length,
        'reason': ?move.reason,
        'switch_count': ?group['switch_count'],
        'door_states': _doorStates(group),
        ..._networkOf(stats),
      },
    );
  }

  /// A move the app saw only as a new door index: the core gave no list of
  /// moves, so there is no reason and no time but now.
  Future<void> _reportSwitch(
    Server? from,
    int index,
    Map<String, dynamic> stats,
  ) => _events.record(
    VpnEventType.doorSwitched,
    door: _currentDoor,
    attemptId: _currentAttemptId,
    strategy: _currentStrategy,
    serverHost: _currentServerHost,
    diag: {
      'from_door': from?.door,
      'from_host': from == null ? null : _hostOf(from),
      'from_server_id': ?from?.serverId,
      'door_index': index,
      'server_id': ?_doors[index].serverId,
      'doors': _doors.length,
      ..._networkOf(stats),
    },
  );

  /// The read in flight, so the next one waits for it. See [_tunnelStats].
  Future<void> _statsQueue = Future<void>.value();

  /// Bytes the tunnel has carried since this was last asked, plus the carrier
  /// and transport. Null when there is no reading to be had.
  ///
  /// [beat] is the periodic heartbeat asking. While the session readings
  /// run, only its answer carries their block, so a read for anything else
  /// (the door, the speed sample, the update dialog, the stall watch) does
  /// not cut the heartbeat's interval short.
  ///
  /// One at a time. The platform holds one question at a time: a second
  /// answers the first with nothing, and the reply to the first then finds
  /// nobody waiting. Each read resets the core's counters, so those bytes
  /// were lost from the heartbeats. The stall watch reads every minute, which
  /// made two at once likely enough to matter.
  Future<Map<String, dynamic>?> _tunnelStats({bool beat = false}) {
    final read = _statsQueue.then((_) => _readTunnelStats(beat: beat));
    _statsQueue = read.then((_) {});
    return read;
  }

  Future<Map<String, dynamic>?> _readTunnelStats({bool beat = false}) async {
    try {
      final raw = await _methodChannel
          .invokeMethod<Map<Object?, Object?>>(
            'tunnelStats',
            beat ? const {'beat': true} : null,
          )
          .timeout(_statsTimeout);
      if (raw == null) return null;
      final stats = raw.map((k, v) => MapEntry(k.toString(), v));
      _notePsiphonRegion(stats);
      return stats;
    } on MissingPluginException {
      return null; // iOS has no counters to read yet
    } catch (_) {
      return null;
    }
  }

  /// How long to let the tunnel settle before the first check.
  ///
  /// A packet tunnel reports "connected" as soon as its provider returns,
  /// which is before routes and DNS are reliably usable. Checking at
  /// 500ms caught a tunnel that was up but not yet ready and tore it
  /// down, so a working server looked broken. See _verifyTrafficInBackground.
  static const _verifySettleDelay = Duration(seconds: 2);

  /// How long to keep retrying before calling the tunnel dead.
  ///
  /// A deadline rather than a retry count, so the worst case stays a
  /// number the user can wait through. A dead server costs this much
  /// before the error appears; a healthy one usually passes on the first
  /// try, about a second after the settle delay.
  static const _verifyDeadline = Duration(seconds: 16);
  static const _verifyRetryGap = Duration(milliseconds: 1500);
  static const _verifyRequestTimeout = Duration(seconds: 4);

  /// Endpoints to test through the tunnel, tried in order within each
  /// attempt.
  ///
  /// More than one because a single blocked or unreachable host must not
  /// be enough to condemn the tunnel. Both answer 204 with an empty body
  /// and are the standard captive-portal probes on Android and for
  /// Cloudflare, so they are cheap and widely reachable.
  static const _verifyUrls = [
    'http://connectivitycheck.gstatic.com/generate_204',
    'http://cp.cloudflare.com/generate_204',
  ];

  /// Verify traffic in the background after showing "Connected".
  ///
  /// The user sees "Connected" immediately. The tunnel is only torn down
  /// once every attempt has failed, because tearing down a healthy tunnel
  /// is far worse for the user than briefly leaving a dead one up: the
  /// dead one shows no traffic and they switch server, while the healthy
  /// one that was killed looks like the app cannot connect at all.
  Future<void> _verifyTrafficInBackground() async {
    // The user may stop this attempt, or a new one may start, while this
    // waits. A new one sets the flag again, so the flag alone would let
    // this check carry on as if it were the new attempt's.
    final run = _attemptRun;
    bool gone() => run != _attemptRun || !_isVerifying;
    _isVerifying = true;
    _trafficMisses = 0;
    notifyListeners();

    await Future.delayed(_verifySettleDelay);

    final deadline = DateTime.now().add(_verifyDeadline);
    while (true) {
      if (gone()) return;

      if (await (_trafficCheck ?? _trafficFlows)()) {
        _mark('verified_ms');
        _verifiedAt ??= DateTime.now();
        // With standby doors the core may already have left the dialled
        // door for one that works. Learn which, before anything is told
        // that this attempt succeeded through the dialled one. Through the
        // backup network, where its traffic leaves, for the same reason.
        await (onPsiphon ? _readDoor() : _learnDoor());
        if (gone()) return;
        _isVerifying = false;
        // The door and the time it was verified, for an app reopened over
        // this tunnel.
        unawaited(_saveConnectionInfo(onlyIfKept: true));
        notifyListeners();
        unawaited(checkPrivateDns());
        unawaited(
          reportConnected(
            _currentServerHost,
            _currentConnection == null
                ? null
                : DateTime.now().difference(_currentConnection!.startTime),
          ),
        );
        return;
      }

      if (gone()) return;
      _trafficMisses++;
      notifyListeners();
      if (DateTime.now().isAfter(deadline)) break;
      await Future.delayed(_verifyRetryGap);
    }

    if (gone()) return;
    _failVerification('Server not working, try another');
  }

  /// One pass of the traffic check, for a screen that has to know whether a
  /// tunnel that says it is connected still carries anything. The check
  /// after connecting runs once, and a tunnel can die after it has passed.
  /// The forced update dialog runs this while it covers the home screen.
  Future<bool> checkTraffic() => _trafficFlows();

  /// Bytes the tunnel brought down since its counters were last read, or
  /// null when the platform has no reading (no tunnel, no reply, or iOS,
  /// which has no counters yet).
  ///
  /// The counters reset on every read, and the heartbeat reports them, so
  /// what this reads is carried into the next beat, the way the throughput
  /// sample does, and no byte goes unreported.
  Future<int?> tunnelBytesDown() async {
    final stats = await _tunnelStats();
    if (stats == null) return null;
    _carry(stats);
    _followDoor(stats);
    return (stats['bytes_down'] as num?)?.toInt();
  }

  /// One pass of the traffic check. True as soon as anything answers.
  Future<bool> _trafficFlows() async {
    if (Platform.isAndroid) {
      // Android: native SOCKS proxy test, because the app is excluded
      // from the TUN and cannot test by making an ordinary request.
      try {
        final result = await _methodChannel
            .invokeMethod('testConnection')
            .timeout(const Duration(seconds: 8));
        return result == true;
      } catch (_) {
        return false;
      }
    }

    // iOS: an ordinary request, which the tunnel carries.
    for (final url in _verifyUrls) {
      HttpClient? client;
      try {
        client = HttpClient();
        client.connectionTimeout = _verifyRequestTimeout;
        final request = await client
            .getUrl(Uri.parse(url))
            .timeout(_verifyRequestTimeout);
        final response = await request.close().timeout(_verifyRequestTimeout);
        if (response.statusCode == 204 || response.statusCode == 200) {
          return true;
        }
      } catch (_) {
        // Try the next endpoint, then the next attempt.
      } finally {
        client?.close(force: true);
      }
    }
    return false;
  }

  /// What was true about the network when this attempt failed.
  ///
  /// Never throws and never returns half an answer as a failure: a report
  /// that could not be collected must not stop the event that carries it.
  /// The host and link are passed in rather than read from the fields,
  /// because the teardown that follows a failure clears them.
  ///
  /// The backup network has no server of ours to check, so only the
  /// control fetch and the platform report run for it.
  @visibleForTesting
  Future<Map<String, dynamic>?> diagnose(String? host, String? uri) async {
    final psiphon = host == Server.psiphonHost;
    try {
      final diag = await _diagnostics.collect(
        host: psiphon ? null : host,
        port: uri == null || psiphon ? 443 : VlessLink.port(uri),
        sni: uri == null || psiphon ? null : VlessLink.sni(uri),
      );
      return diag.isEmpty ? null : diag;
    } catch (e) {
      debugPrint('VpnService: diagnosis failed: $e');
      return null;
    }
  }

  /// Handle verification failure: show the error, tear the tunnel down, and
  /// report what the network looked like once it is down.
  void _failVerification(String reason) {
    final host = _currentServerHost;
    final uri = _currentUri;
    _cancelConnectWatchdog();
    _isVerifying = false;
    _isEnablingVpn = false;
    _errorMessage = reason;
    // Before the listeners hear of the error: the connect flow reads it
    // as soon as its attempt ends.
    _failedAfterUp = true;
    _status = VpnStatus.error;
    _currentConnection = null;
    notifyListeners();

    _verdictReady = Completer<FailureVerdict?>();
    unawaited(reportVerifyFailure(host, uri, reason));
  }

  /// Tear the tunnel down, then diagnose, then report. That order matters.
  ///
  /// A verification failure happens while the tunnel is still up. On iOS the
  /// app's own traffic goes through it, so probing before the teardown would
  /// measure the dead tunnel and call a working network broken. Waiting for
  /// the disconnect first means every probe runs on the real network, which
  /// is the same thing Android measures and the only thing the verdict rules
  /// can read.
  @visibleForTesting
  Future<void> reportVerifyFailure(
    String? host,
    String? uri,
    String reason,
  ) async {
    _tellOutcome(VpnEventType.verifyFailed);
    // Read before the first await. The connect flow dials the next door as
    // soon as this attempt fails, and that overwrites all four; read after
    // the teardown and the diagnosis, a failed shared link was reported
    // under the door that replaced it.
    final door = _currentDoor;
    final attemptId = _currentAttemptId;
    final strategy = _currentStrategy;
    // This failure's own, for the same reason ([failureSettled]).
    final ready = _verdictReady;
    final since = _tapStartedAt;
    // The timeline says how far this attempt got before it stalled: a
    // tunnel that came up in one second and then carried nothing is a
    // different fault from one that never came up.
    final timeline = _timelineReport;
    try {
      await _methodChannel
          .invokeMethod('disconnect')
          .timeout(const Duration(seconds: 3), onTimeout: () => null);
    } catch (_) {
      // A teardown that failed is not a reason to lose the report.
    }
    await _tunnelGone();
    final diag = await diagnose(host, uri);
    _keepDiagnosis(diag, reason, ready, since);
    await _events.record(
      VpnEventType.verifyFailed,
      door: door,
      attemptId: attemptId,
      strategy: strategy,
      serverHost: host,
      error: reason,
      diag: timeline == null ? diag : {...?diag, 'timeline': timeline},
    );
  }

  /// The longest a failure's diagnosis waits for the platform to say the
  /// tunnel is down, and the pause after it says so.
  static const _teardownWait = Duration(seconds: 2);
  static const _teardownSettle = Duration(milliseconds: 300);

  /// Waits until the platform says no tunnel is up, for at most
  /// [_teardownWait], then [_teardownSettle] more.
  ///
  /// Android's `disconnect` returns as soon as it has asked the service to
  /// stop, while the tunnel is still going down and the phone is moving its
  /// traffic back to its own network. A diagnosis started then can find
  /// "no internet" on a phone that has it: in the 24 hours to 10:15 Tehran
  /// on 2026-10-20, 7 of the 28 verification failures whose diagnosis said
  /// the phone was offline had their checks fail within 16 to 200 ms.
  /// Returns at once on a platform without the call.
  Future<void> _tunnelGone() async {
    final until = DateTime.now().add(_teardownWait);
    while (DateTime.now().isBefore(until)) {
      var up = true;
      try {
        final native = await _methodChannel
            .invokeMethod<String>('getStatus')
            .timeout(const Duration(milliseconds: 500));
        up = native == 'connected';
      } on MissingPluginException {
        return;
      } catch (_) {
        // No answer in time: ask again, up to the limit.
      }
      if (!up) break;
      await Future.delayed(const Duration(milliseconds: 100));
    }
    await Future.delayed(_teardownSettle);
  }

  void _cancelConnectWatchdog() {
    _connectWatchdog?.cancel();
    _connectWatchdog = null;
  }

  /// Give up on an attempt that never reported an outcome, or reported failure.
  void _failConnect(String reason) {
    _verdictReady = Completer<FailureVerdict?>();
    unawaited(reportConnectFailure(_currentServerHost, _currentUri, reason));
    _failedAfterUp = false;
    _cancelConnectWatchdog();
    _isVerifying = false;
    _isEnablingVpn = false;
    _errorMessage = reason;
    _errorNeedsVpnSettings = false;
    _status = VpnStatus.error;
    _currentConnection = null;
    _clearConnectionInfo();
    notifyListeners();
  }

  /// Report a connection that worked.
  ///
  /// The platform report always runs. It is what buys the carrier, which
  /// the backend cannot read from the address a success arrives on, since
  /// that batch leaves through the tunnel. Without it every per-carrier
  /// failure rate has a numerator and no denominator.
  ///
  /// Once a day per network the full diagnosis runs too: DNS, TCP, TLS and
  /// the control fetch, the same four checks a failure gets. Successes used
  /// to carry none of them, which meant every DNS, TCP and TLS timing we
  /// held came from an attempt that failed. Anything learned from that
  /// learns "was measured, therefore failed" and nothing about the network.
  ///
  /// Once a day rather than every time, because the checks cost about a
  /// second and the user is watching. A daily reading per network is enough
  /// for a baseline and cheap enough that nobody notices it.
  @visibleForTesting
  Future<void> reportConnected(String? host, Duration? duration) async {
    _tellOutcome(VpnEventType.connected);
    // Before the first await, for the reason given in reportVerifyFailure.
    final door = _currentDoor;
    final attemptId = _currentAttemptId;
    final strategy = _currentStrategy;
    final timeline = _timelineReport;
    final uri = _currentUri;
    // Held in the queue now, before the platform report and the day's
    // diagnosis: "Connected" is on screen, and the app can be closed before
    // they finish (VpnEventReporter.hold).
    final held = _events.hold(
      VpnEventType.connected,
      door: door,
      attemptId: attemptId,
      strategy: strategy,
      serverHost: host,
      duration: duration,
      diag: timeline == null ? null : {'timeline': timeline},
    );
    Map<String, dynamic>? diag;
    try {
      final report = await _diagnostics.platformReport();
      if (report.isNotEmpty) diag = report;
      // Not through the backup network: its diagnosis checks no server, and
      // would take the day's measure of this network without one.
      if (host != Server.psiphonHost && await _baselineDue(report)) {
        final full = await diagnose(host, uri);
        if (full != null && full.isNotEmpty) {
          // Merged rather than replaced. The carrier is the one key a
          // success must never arrive without, and a full diagnosis that
          // lost its platform half would take it with it.
          diag = {...report, ...full};
          await _markBaselineTaken(report);
        }
      }
    } catch (e) {
      debugPrint('VpnService: platform report failed: $e');
    }
    if (timeline != null) diag = {...?diag, 'timeline': timeline};
    await _events.recordHeld(
      held,
      VpnEventType.connected,
      door: door,
      attemptId: attemptId,
      strategy: strategy,
      serverHost: host,
      duration: duration,
      diag: diag,
    );
  }

  /// Where the "measured a success on this network today" marks live.
  static const baselineMarksKey = 'fortiva_success_baseline_days';

  /// How many networks keep a mark. Only today's are ever read, so this is
  /// a ceiling on a phone that meets many networks in one day.
  static const maxBaselineMarks = 20;

  /// Which network a baseline is remembered against: the transport and the
  /// carrier, the same two facts that decide whether a door works.
  static String _baselineKey(Map<String, dynamic> report) {
    final network = report['network']?.toString() ?? '?';
    final carrier =
        (report['carrier'] ?? report['sim_carrier'])?.toString() ?? '?';
    return '$network|$carrier';
  }

  static String _today() =>
      DateTime.now().toUtc().toIso8601String().split('T').first;

  /// True when this network has no measured success today.
  ///
  /// Never throws: a preferences read that fails must not cost the event.
  /// It answers false in that case, so a broken store means fewer probes
  /// rather than one on every connect.
  Future<bool> _baselineDue(Map<String, dynamic> report) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final seen = prefs.getStringList(baselineMarksKey) ?? const [];
      return !seen.contains('${_baselineKey(report)}@${_today()}');
    } catch (e) {
      debugPrint('VpnService: could not read baseline marks: $e');
      return false;
    }
  }

  /// Remember that this network was measured today. Capped, because a phone
  /// that meets many networks must not grow this without bound, and only
  /// today's marks are ever read.
  Future<void> _markBaselineTaken(Map<String, dynamic> report) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = _today();
      final seen = (prefs.getStringList(baselineMarksKey) ?? const [])
          .where((e) => e.endsWith('@$today'))
          .toList();
      seen.add('${_baselineKey(report)}@$today');
      while (seen.length > maxBaselineMarks) {
        seen.removeAt(0);
      }
      await prefs.setStringList(baselineMarksKey, seen);
    } catch (e) {
      debugPrint('VpnService: could not store baseline mark: $e');
    }
  }

  /// Diagnose and report a tunnel that went away without the user asking.
  @visibleForTesting
  Future<void> reportDrop(
    String? host,
    String? uri,
    Duration? duration,
    String reason,
  ) async {
    _tellOutcome(VpnEventType.dropped);
    // Before the first await, for the reason given in reportVerifyFailure.
    final door = _currentDoor;
    final attemptId = _currentAttemptId;
    final strategy = _currentStrategy;
    final diag = await diagnose(host, uri) ?? <String, dynamic>{};
    await _events.record(
      VpnEventType.dropped,
      door: door,
      attemptId: attemptId,
      strategy: strategy,
      serverHost: host,
      duration: duration,
      error: reason,
      diag: {...diag, 'drop_reason': reason},
    );
  }

  /// Diagnose and report a connect failure. The tunnel never came up here,
  /// so unlike a verification failure there is nothing to tear down first.
  @visibleForTesting
  Future<void> reportConnectFailure(
    String? host,
    String? uri,
    String reason,
  ) async {
    _tellOutcome(VpnEventType.connectFailed);
    // Before the first await, for the reason given in reportVerifyFailure.
    final door = _currentDoor;
    final attemptId = _currentAttemptId;
    final strategy = _currentStrategy;
    final ready = _verdictReady;
    final since = _tapStartedAt;
    final diag = await diagnose(host, uri);
    _keepDiagnosis(diag, reason, ready, since);
    await _events.record(
      VpnEventType.connectFailed,
      door: door,
      attemptId: attemptId,
      strategy: strategy,
      serverHost: host,
      error: reason,
      diag: diag,
    );
  }

  /// Backstop for an attempt that reports nothing at all — a native crash, a
  /// killed daemon process, a lost broadcast. Without it the UI has no exit
  /// from "Connecting" but killing the app.
  void _armConnectWatchdog() {
    _cancelConnectWatchdog();
    final run = _attemptRun;
    _connectWatchdog = Timer(_startTimeout, () async {
      if (_status != VpnStatus.connecting) return;
      if (_awaitingPermission) {
        _armConnectWatchdog();
        return;
      }

      // The tunnel may well be up with only its broadcast lost, so ask the
      // platform directly before calling a live connection a failure.
      try {
        final native = await _methodChannel.invokeMethod<String>('getStatus');
        // Stopped or replaced while the platform answered: whatever it
        // says is about an attempt nobody is waiting for.
        if (run != _attemptRun) return;
        if (native == 'connected') {
          _cancelConnectWatchdog();
          _updateStatus(VpnStatus.connected);
          return;
        }
        // The dialog is open and its event was missed.
        if (native == 'awaiting_permission') {
          _awaitingPermission = true;
          _armConnectWatchdog();
          return;
        }
      } catch (_) {}

      if (run != _attemptRun || _status != VpnStatus.connecting) return;
      _failConnect('Could not start the tunnel. Try another location.');
      // Leave nothing half-started behind.
      _methodChannel
          .invokeMethod('disconnect')
          .timeout(const Duration(seconds: 3), onTimeout: () => null);
    });
  }

  /// Connect to a VPN server.
  /// Dial [server].
  ///
  /// [attemptId] joins these events to the door checks that led here. The
  /// flow makes one id when the user taps and hands the same one to every
  /// step; a caller that dials directly leaves it null and gets a fresh id,
  /// because an attempt with no id cannot be read back at all.
  ///
  /// [standby] are other doors for the core to hold next to this one and
  /// move to when it fails. See StandbyDoors.
  ///
  /// [source] is where [server] came from, for the `src` of every event of
  /// this attempt. Null works it out from [server] ([LinkSource.of]); the
  /// connect flow names a community link it dialled as its fallback.
  ///
  /// [Server.psiphon] dials the backup network with the settings in force
  /// (PsiphonSettings), through the platform's `connectPsiphon`. Its start
  /// gets the network's own time to come up on top of the usual one, and
  /// its events name the server "psiphon" and no door.
  Future<void> connect(
    Server server, {
    String? attemptId,
    List<Server> standby = const [],
    LinkSource? source,
  }) async {
    // Read again after every wait below. A stop that lands in one of them
    // must not be followed by a dial.
    final run = ++_attemptRun;
    _stoppedStartUntil = null;
    _stoppedBeforeVerified = false;
    // Cleared before the first wait below, so a caller waiting for a dead
    // tunnel to be replaced (StallRecovery) sees at once that it is being
    // replaced, and does not take down the new one while it comes up.
    final replacingStalled = _stall != null;
    _stall = null;
    // Before the teardown below, not after it: the user's wait starts at
    // the tap, and taking down a live tunnel first is part of it.
    _attemptClock = Stopwatch()..start();
    // Taken before the first wait, so a later dial's value is never read.
    _tapStartedAt = tapStarted ?? DateTime.now();
    tapStarted = null;
    _timeline.clear();
    _throughputTaken = false;
    _throughputTimer?.cancel();
    _throughputTimer = null;
    // Last attempt's diagnosis describes a server and a network that may
    // both have changed. Cleared here rather than on success, so a
    // failure never shows the reason the previous one failed.
    _forgetDiagnosis();

    // If already connected or verifying, disconnect old tunnel first
    if (_status == VpnStatus.connected ||
        _status == VpnStatus.connecting ||
        _isVerifying ||
        _isEnablingVpn) {
      // A verified tunnel moved to another server ends by the user's choice.
      // Recorded here, under its own door and attempt, because everything
      // below replaces them. An attempt still being verified has no
      // connected row to close, so it ends without one.
      // One found dead was reported as dropped already ([_reportStall]).
      if (_status == VpnStatus.connected &&
          !_isVerifying &&
          !_isEnablingVpn &&
          !replacingStalled) {
        unawaited(
          _events.record(
            VpnEventType.disconnected,
            door: _currentDoor,
            attemptId: _currentAttemptId,
            strategy: _currentStrategy,
            serverHost: _currentServerHost,
            duration: _currentConnection?.duration,
          ),
        );
      }
      _isVerifying = false;
      _isEnablingVpn = false;
      // Connecting from before the teardown, so the platform's
      // "disconnected" for the old tunnel is the stale one _updateStatus
      // ignores. Still "connected" when it arrived, it was reported as a
      // drop with no reason: on 2026-10-03, 39 of 108 drops in two days were
      // users picking another server.
      _status = VpnStatus.connecting;
      try {
        await _methodChannel.invokeMethod('disconnect');
      } catch (_) {}
      // Brief pause to let the tunnel fully tear down
      await Future.delayed(const Duration(milliseconds: 500));
      if (run != _attemptRun) return;
    }

    // Clear previous states
    _errorMessage = null;
    _errorNeedsVpnSettings = false;
    _failedOnPermission = false;
    _failedAfterUp = false;
    _cancelConnectWatchdog();
    final psiphon = server.isPsiphon ? _psiphon() : null;
    _startTimeout = psiphon == null
        ? _connectTimeout
        : psiphon.establishTimeout + psiphonStartSlack;
    _isVerifying = false;
    _isEnablingVpn = false;

    // Set connecting state immediately
    _userDisconnecting = false;
    _dropReason = null;
    _currentServerHost = _hostOf(server);
    // Dialled as the probes dial it, so the fragment the link carries is
    // in the strategy the reports record.
    final link = TlsFragment.apply(server.connectionUri);
    // The backup network has no link to diagnose or to keep.
    _currentUri = server.isPsiphon ? null : link;
    _currentDoor = server.door;
    _doors = [server, ...standby];
    _doorIndex = 0;
    _restoredDoorKey = null;
    _movesSeenUntil = 0;
    _switchReason = null;
    _carriedUp = 0;
    _carriedDown = 0;
    _verifiedAt = null;
    _moves = 0;
    _failovers = 0;
    _currentAttemptId = attemptId ?? newAttemptId();
    _dialledSource = source ?? LinkSource.of(server);
    _currentStrategy = _dialledSource.strategy(server, link);
    _status = VpnStatus.connecting;
    _currentConnection = ConnectionInfo(
      startTime: DateTime.now(),
      serverId: server.id,
      serverName: server.name,
    );
    notifyListeners();
    _armConnectWatchdog();

    try {
      final cleanLink = _sendable(link);
      final alternates = [
        for (final door in standby)
          _sendable(TlsFragment.apply(door.connectionUri)),
      ];
      // The backend's own outbound of each door, in the order of the link
      // and then the alternates, "" for a door without one. Android dials
      // a door that has one with it (DoorOutbound). Left out when no door
      // has one, so such a connect is sent as before.
      final outbounds = [
        for (final door in [server, ...standby])
          DoorOutbounds.nativeFor(
                door.connectionUri,
                TlsFragment.apply(door.connectionUri),
              ) ??
              '',
      ];

      final prefs = await SharedPreferences.getInstance();
      final remoteDns = prefs.getString('pref_remote_dns');
      // The network's server list, when the phone has the one the
      // settings name. Without it the network starts as it always has.
      final entries = psiphon == null ? null : await _psiphonEntries(psiphon);
      if (run != _attemptRun) return;
      // How the tunnel's process reads its byte counters this session, as
      // the backend set it. Zero when it set none, which turns the readings
      // off, so a value from an earlier connect never lingers there.
      final readings = ConnectionData.current;
      final readingsOn = readings.sessionReadings;
      final session = {
        'session_sample_ms': readingsOn
            ? readings.sessionSample!.inMilliseconds
            : 0,
        'session_stall_ms': readingsOn
            ? readings.stallAfter!.inMilliseconds
            : 0,
        'session_busy_bytes': readingsOn ? readings.busyBytes : 0,
      };
      if (server.isPsiphon && psiphon == null) {
        // The backend turned the network off between the decision to dial
        // it and the dial.
        _failConnect('The backup network is off.');
        return;
      }

      try {
        if (psiphon != null) {
          await _methodChannel.invokeMethod('connectPsiphon', {
            'config': psiphon.tunnelConfig,
            'establish_timeout_ms': psiphon.establishTimeout.inMilliseconds,
            'server_entries_file': ?entries,
            ...session,
          });
        } else {
          await _methodChannel.invokeMethod('connect', {
            'link': cleanLink,
            if (alternates.isNotEmpty) 'alternates': alternates,
            // The server each door sends traffic out from, in the order of the
            // link and then the alternates. A failover in the core prefers a
            // door on the server it is leaving, so the address the user's
            // traffic leaves from does not change when it does not have to.
            // Empty for a door that is not on one of our servers.
            if (alternates.isNotEmpty)
              'exits': [
                for (final door in [server, ...standby])
                  door.serverId?.toString() ?? '',
              ],
            // The backend's penalty for each door, in the same order. The core
            // adds it to the door's score, so a door that answers its probes
            // fast and then fails in the middle of sessions stops winning on
            // its probes alone. Left out when no door has one.
            if (alternates.isNotEmpty &&
                [server, ...standby].any((door) => door.penaltyMs > 0))
              'penalties': [
                for (final door in [server, ...standby]) door.penaltyMs,
              ],
            if (outbounds.any((o) => o.isNotEmpty)) 'doorOutbounds': outbounds,
            if (remoteDns != null && remoteDns.isNotEmpty) 'dns': remoteDns,
            ...session,
          });
        }
      } finally {
        // From here a "failed" can be this attempt's own.
        if (run == _attemptRun) _dropFailedUntilDialled = false;
        // The call returns once the user has answered the dialog. The start
        // gets its full time from here, not what was left of it before.
        if (_awaitingPermission && run == _attemptRun) {
          _awaitingPermission = false;
          if (_status == VpnStatus.connecting) _armConnectWatchdog();
          notifyListeners();
        }
      }

      // Flow: connect (proxy-only) → "connected" → _verifyTraffic → enableVpn → "connected" → done
    } on PlatformException catch (e) {
      // A superseded request belongs to an attempt the user already replaced —
      // failing here would clobber the state of the attempt still in flight.
      if (e.code == 'PERMISSION_SUPERSEDED') return;
      // Stopped by the user or replaced while the platform answered. A
      // failure of an attempt the user ended is not shown and not reported.
      if (run != _attemptRun) return;

      _cancelConnectWatchdog();
      _errorMessage = _messageForPlatformError(e);
      _errorNeedsVpnSettings = _needsVpnSettings(e.code);
      _failedOnPermission = _isPermissionError(e.code);
      unawaited(reportConnectFailure(_currentServerHost, _currentUri, e.code));
      _status = VpnStatus.error;
      _currentConnection = null;
      _isVerifying = false;
      _isEnablingVpn = false;
      notifyListeners();
      // Permission outcomes are already surfaced through errorMessage, and
      // every caller fires connect() without awaiting it.
      if (!_isPermissionError(e.code)) rethrow;
    } catch (e) {
      if (run != _attemptRun) return;
      _cancelConnectWatchdog();
      _errorMessage = 'Unexpected error: $e';
      unawaited(
        reportConnectFailure(
          _currentServerHost,
          _currentUri,
          'Unexpected error: $e',
        ),
      );
      _status = VpnStatus.error;
      _currentConnection = null;
      _isVerifying = false;
      _isEnablingVpn = false;
      notifyListeners();
      rethrow;
    }
  }

  static bool _isPermissionError(String code) =>
      code == 'PERMISSION_DENIED' ||
      code == 'PERMISSION_BLOCKED' ||
      code == 'PERMISSION_UNAVAILABLE' ||
      code == 'PERMISSION_GRANTED_NO_LINK';

  static bool _needsVpnSettings(String code) =>
      code == 'PERMISSION_BLOCKED' || code == 'PERMISSION_UNAVAILABLE';

  String? _privateDnsHost;

  /// The provider Android's Private DNS is set to, when name lookups fail
  /// through it while the tunnel is up. Null when Private DNS is off or
  /// automatic, when lookups work, or when the platform will not say.
  ///
  /// Android keeps asking that provider while the tunnel is up. Most
  /// providers answer through the tunnel and need nothing from the user.
  /// Some providers in Iran answer only phones inside Iran, and then every
  /// lookup fails; only in that case does the home screen ask the user to
  /// change the setting.
  String? get privateDnsHost => _privateDnsHost;

  /// Check the Private DNS setting and whether lookups work. Never throws.
  ///
  /// Only Android answers; elsewhere the call fails and the warning stays
  /// off.
  Future<void> checkPrivateDns() async {
    String? host;
    try {
      host = await _methodChannel.invokeMethod<String>('privateDns');
    } catch (_) {
      // An older native side, or a platform that would not say. Leave the
      // warning off rather than guess.
      host = null;
    }
    if (host != null && host.trim().isEmpty) host = null;
    if (host == _privateDnsHost) return;
    _privateDnsHost = host;
    notifyListeners();
  }

  /// Open the system network settings, where Private DNS lives.
  Future<bool> openNetworkSettings() async {
    if (!Platform.isAndroid) return false;
    try {
      return await _methodChannel.invokeMethod<bool>('openNetworkSettings') ??
          false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Open the system VPN screen. Returns false when the device has no such
  /// screen to open, so the caller can leave the message as the only guidance.
  Future<bool> openVpnSettings() async {
    if (!Platform.isAndroid) return false;
    try {
      return await _methodChannel.invokeMethod<bool>('openVpnSettings') ??
          false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Turn a native error into something a user can act on.
  String _messageForPlatformError(PlatformException e) {
    switch (e.code) {
      case 'PERMISSION_DENIED':
        return 'VPN permission is required. Tap connect and choose OK.';
      case 'PERMISSION_BLOCKED':
        final blocker = e.details is String ? e.details as String : null;
        return blocker != null
            ? '$blocker is set as your always-on VPN, so Android will not ask '
                  'for permission. Turn it off in VPN settings, then try again.'
            : 'Android would not show the VPN permission request. Turn off '
                  'always-on VPN for any other VPN app, then try again.';
      case 'PERMISSION_GRANTED_NO_LINK':
        return 'VPN permission granted. Tap connect to continue.';
      case 'PERMISSION_UNAVAILABLE':
        return 'This device would not show the VPN permission request. '
            'Check whether another VPN app is set as always-on.';
      default:
        return e.message ?? 'Connection failed';
    }
  }

  /// Take the tunnel down, or stop the attempt that is bringing it up.
  ///
  /// This is the user's stop, and it works from every state a connect can
  /// be in: the dial still on its way to the platform, a start the platform
  /// has not confirmed, a tunnel up and still being verified, or one that
  /// is verified. The screen shows "Disconnecting" from this call on. What
  /// the attempt still has in flight gives up (see [_attemptRun]), and
  /// nothing it reports afterwards is shown as a connection or a failure.
  Future<void> disconnect() async {
    if (_status == VpnStatus.error) return _dropFailure();
    if (_status == VpnStatus.disconnecting) {
      // Already stopping. Asking the platform again costs nothing.
      return _stopPlatform();
    }
    if (!_status.isActive && !_isVerifying && !_isEnablingVpn) return;

    final run = ++_attemptRun;
    final starting = _status == VpnStatus.connecting || _isEnablingVpn;
    _stoppedBeforeVerified = starting || _isVerifying;
    // The platform has not confirmed the start, so it may still finish it.
    if (starting) {
      _stoppedStartUntil = DateTime.now().add(_holdAfterStop);
      _stopAnswered = false;
      _dropFailedUntilDialled = true;
    }
    _awaitingPermission = false;
    try {
      _userDisconnecting = true;
      _cancelConnectWatchdog();
      _isVerifying = false;
      _isEnablingVpn = false;
      _updateStatus(VpnStatus.disconnecting);
      // Safety: if native doesn't send "disconnected" within 4s, force it.
      // Armed before the platform is asked, so a call that never returns
      // cannot leave the screen on "Disconnecting".
      Future.delayed(const Duration(seconds: 4), () {
        if (run == _attemptRun && _status == VpnStatus.disconnecting) {
          _status = VpnStatus.disconnected;
          _currentConnection = null;
          notifyListeners();
        }
      });
      await _methodChannel.invokeMethod('disconnect');
      if (run == _attemptRun) _stopAnswered = true;
    } on PlatformException catch (e) {
      _errorMessage = e.message ?? 'Disconnection failed';
      _updateStatus(VpnStatus.error);
      rethrow;
    }
  }

  /// A stop while the status is a failure. A failed door leaves it there
  /// while the connect flow moves on to the next door. The user ended the
  /// search, so the failure is no longer the result to show. It was
  /// reported when it happened.
  Future<void> _dropFailure() async {
    _attemptRun++;
    _errorMessage = null;
    _errorNeedsVpnSettings = false;
    _forgetDiagnosis();
    _status = VpnStatus.disconnected;
    _currentConnection = null;
    notifyListeners();
    // A failed attempt has already been taken down. A stop still makes
    // sure, because a half-started tunnel would hold the phone's routes.
    await _stopPlatform();
  }

  /// Get current connection duration
  Duration? get connectionDuration {
    if (_currentConnection == null || !isConnected) return null;
    return _currentConnection!.duration;
  }

  @override
  void dispose() {
    _cancelConnectWatchdog();
    _stallWatch.dispose();
    _heartbeat?.cancel();
    _heartbeat = null;
    _throughputTimer?.cancel();
    _throughputTimer = null;
    super.dispose();
  }

  /// Clear error message
  void clearError() {
    _errorMessage = null;
    _errorNeedsVpnSettings = false;
    _forgetDiagnosis();
    if (_status == VpnStatus.error) {
      _updateStatus(VpnStatus.disconnected);
    }
    notifyListeners();
  }

  // --- Persistence helpers ---

  static const _prefServerId = 'vpn_connected_server_id';
  static const _prefServerName = 'vpn_connected_server_name';
  static const _prefStartTime = 'vpn_connected_start_time';

  /// The attempt behind the tunnel, as JSON: its id, the door in use and
  /// its position, the dialling strategy, the server host and link, when it
  /// was verified, and its moves. Without it a reopened app sent every
  /// heartbeat with no door, attempt or strategy.
  static const _prefAttempt = 'vpn_connected_attempt';

  /// Keeps the connection for an app reopened over this tunnel.
  ///
  /// With [onlyIfKept] it only updates a record that is still there. That
  /// is every save in the middle of a session: deleting the account removes
  /// the record while the tunnel can stay up, and a door move after that
  /// must not write the deleted account's link and attempt back. Only the
  /// tunnel coming up creates the record.
  Future<void> _saveConnectionInfo({bool onlyIfKept = false}) async {
    // Read once: a tunnel that drops while prefs load clears the field, and
    // reading it again after the await threw.
    final connection = _currentConnection;
    if (connection == null) return;
    final attempt = _attemptFacts();
    final prefs = await SharedPreferences.getInstance();
    if (onlyIfKept && !prefs.containsKey(_prefServerId)) return;
    // Started together, with no await between the check and the writes, so
    // a deletion cannot land between them and lose half of its removals.
    await Future.wait([
      prefs.setString(_prefServerId, connection.serverId),
      prefs.setString(_prefServerName, connection.serverName),
      prefs.setString(_prefStartTime, connection.startTime.toIso8601String()),
      prefs.setString(_prefAttempt, jsonEncode(attempt)),
    ]);
  }

  Map<String, dynamic> _attemptFacts() => {
    'attempt_id': ?_currentAttemptId,
    'door': ?_currentDoor,
    'door_key': ?activeDoorKey,
    'door_index': _doorIndex,
    'strategy': ?_currentStrategy,
    'server_host': ?_currentServerHost,
    'link': ?_currentUri,
    'verified_at': ?_verifiedAt?.toUtc().toIso8601String(),
    'moves': _moves,
    'failovers': _failovers,
  };

  Future<void> _restoreConnectionInfo() async {
    if (_currentConnection != null) return; // already set
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_prefServerId);
    final name = prefs.getString(_prefServerName);
    final startStr = prefs.getString(_prefStartTime);
    if (id != null && name != null && startStr != null) {
      _currentConnection = ConnectionInfo(
        startTime: DateTime.tryParse(startStr) ?? DateTime.now(),
        serverId: id,
        serverName: name,
      );
      // The door put back is the one the app last knew. The core may have
      // left it while the app was closed, so it is read at once, before a
      // drop or a beat can name it. Otherwise the first read could come
      // from the speed sample or the first beat, minutes later.
      if (_restoreAttempt(prefs.getString(_prefAttempt))) {
        unawaited(_readDoor());
      }
    }
  }

  /// Puts back what [_attemptFacts] kept, when this run of the app has no
  /// attempt of its own. True when it did. The doors themselves are not
  /// kept, so moves made after the reopen are not followed (see
  /// [_followDoor]).
  bool _restoreAttempt(String? saved) {
    if (saved == null || _currentAttemptId != null) return false;
    Map<String, dynamic> facts;
    try {
      final decoded = jsonDecode(saved);
      if (decoded is! Map<String, dynamic>) return false;
      facts = decoded;
    } catch (_) {
      return false;
    }
    String? text(String key) => facts[key] is String ? facts[key] : null;
    int whole(String key) => facts[key] is int ? facts[key] : 0;
    final strategy = facts['strategy'];
    _currentAttemptId = text('attempt_id');
    _currentDoor = text('door');
    _restoredDoorKey = text('door_key');
    _doorIndex = whole('door_index');
    _currentStrategy = strategy is Map<String, dynamic> ? strategy : null;
    _currentServerHost = text('server_host');
    _currentUri = text('link');
    _verifiedAt = DateTime.tryParse(text('verified_at') ?? '');
    _moves = whole('moves');
    _failovers = whole('failovers');
    return true;
  }

  Future<void> _clearConnectionInfo() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefServerId);
    await prefs.remove(_prefServerName);
    await prefs.remove(_prefStartTime);
    await prefs.remove(_prefAttempt);
  }
}

/// One move between doors, as the core recorded it.
class _DoorMove {
  const _DoorMove({
    required this.from,
    required this.to,
    required this.reason,
    required this.at,
  });

  /// Positions in the doors the tunnel was given.
  final int from;
  final int to;

  /// The core's word for why: `failover`, `faster`, `recovered`...
  final String? reason;

  final DateTime at;
}
