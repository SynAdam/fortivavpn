import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import '../../api/api_client.dart';
import '../../api/config_service.dart';
import '../../data/models/psiphon_settings.dart';
import '../../data/models/server.dart';
import '../../data/models/checklist_settings.dart';
import '../../services/community_checks.dart';
import '../../services/connect_diagnostics.dart';
import '../../services/connect_trace.dart';
import '../../services/path_finder.dart';
import '../../services/door_sweep.dart';
import '../../services/door_pair.dart';
import '../../services/failure_verdict.dart';
import '../../services/ipv6_reach.dart';
import '../../services/network_keys.dart';
import '../../services/path_memory.dart';
import '../../services/recent_taps.dart';
import '../../services/tunnel_channels.dart';
import '../../utils/shared_link.dart';
import '../../utils/standby_doors.dart';
import '../../utils/tls_fragment.dart';
import '../../utils/vless_link.dart';
import '../../utils/vless_link_host.dart';
import '../../services/ping_service.dart';
import '../../services/vpn_event_reporter.dart';
import '../../services/vpn_service.dart';
import '../form_factor.dart';

/// How a fallback through shared links ended. See [ConnectFlow].
enum _Fallback {
  /// Connected, or the run was stopped or replaced; nothing left to do.
  ended,

  /// No shared link was open, or there was none to try.
  nothingOpen,

  /// A shared link was open and its tunnel failed.
  failed,
}

/// What a last pass will check, and what it leaves out. See
/// [ConnectFlow._lastPassRows].
typedef _LastPassPlan = ({
  List<PathCheck> rows,
  List<PathCheck> over,
  List<PathCheck> noIpv6,
  Set<String> hinted,
});

/// What a check of the doors says to do with a tunnel the stall watch
/// found throttled ([ConnectFlow.checkThrottled], StallRecovery).
enum ThrottleStep {
  /// The door in use checks open and no door checks faster. The tunnel
  /// stays, because a move did not help on 2026-10-23: the next session
  /// carried about half as much whether it moved or not.
  stay,

  /// A door checks faster ([ThrottleCheck] door). The tunnel moves there.
  move,

  /// The door in use is not shown open: it checks closed to a new
  /// connection and no door of this connect checks open, or it cannot be
  /// checked. The tunnel is left as a dead one is, and the search runs in
  /// full, shared links and the backup network included, as builds up to
  /// 2.2.0 do.
  leave,
}

/// A [ThrottleStep], with the door to move to for [ThrottleStep.move].
typedef ThrottleCheck = ({ThrottleStep step, Server? door});

/// Where the connect button's work stands.
enum ConnectStage {
  idle,

  /// Dialling the door that worked last time on this network, with no
  /// checks. Past the backend's FastPathSettings.besideAfter the checklist
  /// starts beside it ([diagnosing]).
  fastPath,

  /// The checklist: testing doors until one is open.
  diagnosing,

  /// A door was open; the tunnel is coming up through it.
  connecting,

  /// Connected and verified.
  done,

  /// The control fetch failed, no door checked beside it was open, and no
  /// shared link checked after them was open either.
  noInternet,

  /// As [noInternet], but a site inside the country answered the control
  /// fetch ([NetReach.cut]): the phone's network is up and its way abroad
  /// is cut, as in Iran in June 2025 and January 2026. Every door got its
  /// whole search, and the tap keeps trying ([RetrySettings]).
  cutOff,

  /// Every door checked was blocked.
  nothingOpen,

  /// A door was open on the check but the tunnel still failed through it.
  failed,

  /// Nothing carried a tunnel, and the tap tries again by itself after a
  /// wait ([RetrySettings]). A tap on the button stops it.
  waiting,
  cancelled,
}

/// The kinds of route a tap tries, in the order it tries them. The screen
/// shows each kind as a stage of the search (clients #342).
enum RouteKind {
  /// The doors of this device's own servers.
  own,

  /// The shared links the fallback checks once no own door carried a
  /// tunnel: the community links, and our shared servers before them. A
  /// shared link the user picked is one too.
  community,

  /// The backup network ([Server.psiphon]).
  backup;

  /// The kind of route [server] is.
  static RouteKind of(Server server) => server.isPsiphon
      ? backup
      : server.isDedicated
      ? own
      : community;
}

/// Where one stage of a try stands ([ConnectFlow.stageState]).
enum StageState {
  /// Not tried yet on this try, and it may still be.
  pending,

  /// Routes of this kind are being checked or dialled now.
  running,

  /// The tunnel came up through a route of this kind and carries traffic.
  connected,

  /// Tried on this try, and nothing of this kind connected so far.
  failed,

  /// Not tried on this try: there was none to try, or it was not allowed.
  skipped,
}

/// The connect button, from tap to verified tunnel.
///
/// Three moods. The fast path: the door that worked last time on this
/// network is dialled straight away, no checklist, two seconds. The
/// diagnosis: that door failed, or the network is new, so the checklist
/// appears and doors are tested several at a time (DoorCheckSettings),
/// taking the first open one in order; the moment it is known the app
/// connects through it and stops checking. Nothing open: every door
/// failed, the user is told plainly, and the backend hears which doors
/// were tried so the fleet learns.
///
/// A server the user picked is their choice and the door is the app's.
/// Diagnosis starts with that server's doors and only then moves to the
/// other servers. Without a pick it follows the backend's order, which
/// ranks the doors that work on the phone's carrier first. When it lands
/// on another server the selection follows, so the card shows what is
/// actually in use. That move is not a pick, so the next tap does not
/// check every door of a server the backend ranks bad before the others.
///
/// Every diagnosis is reported. A phone that connected on the fast path
/// reports one success and nothing else, which keeps the scoreboard right
/// without spending data on checks nobody needed.
class ConnectFlow extends ChangeNotifier {
  ConnectFlow({
    required VpnService vpn,
    PathMemory? memory,
    PathFinder? finder,
    VpnEventReporter? reporter,
    DoorSweep? sweep,
    Ipv6Reach? ipv6,
    Future<String> Function()? networkKey,
    Future<String?> Function()? carrier,
    CommunityChecks? communityChecks,
    ChecklistSettings? Function()? checklist,
    ConnectTraces? traces,
    Stream<String> Function()? networkChanges,
    double Function()? random,
    this.networkSettle = const Duration(seconds: 2),
    DoorPairCheck? Function()? doorPair,
    DoorPairRunner? pairs,
    this.attemptTimeout = const Duration(seconds: 45),
    PsiphonSettings? Function()? psiphon,
    PsiphonDevice? Function()? psiphonDevice,
    bool Function()? android,
    bool Function()? tv,
    bool Function(DateTime since)? answeredSince,
    RecentTaps? recentTaps,
  }) : _vpn = vpn,
       recentTaps = recentTaps ?? RecentTaps(),
       _answeredSince = answeredSince ?? ApiClient.answeredSince,
       _psiphon = psiphon ?? _currentPsiphon,
       _psiphonDevice = psiphonDevice ?? _noPsiphonDevice,
       _android = android ?? _isAndroid,
       _tv = tv ?? _isTv,
       _doorPair = doorPair ?? _noDoorPair,
       _communityChecks = communityChecks,
       _checklist = checklist ?? _currentChecklist,
       _traces = traces ?? ConnectTraces(),
       _networkChanges = networkChanges,
       _random = random ?? Random().nextDouble,
       _memory = memory ?? PathMemory(),
       _ipv6 = ipv6 ?? Ipv6Reach(),
       _finder =
           finder ??
           PathFinder(
             read: _defaultRead,
             internet: _defaultInternet,
             home: _defaultHome,
           ),
       // VpnService's reporter rather than one of its own. A reporter of
       // its own never flushed: on 2026-10-07 the door checks it could not
       // send waited for VpnService's flush, which stopped at an event it
       // could not send either.
       _reporter = reporter ?? vpn.reporter,
       _networkKey = networkKey ?? _defaultNetworkKey,
       _carrier = carrier ?? _defaultCarrier {
    _reporter.reportsGoThroughTunnel ??= () =>
        Platform.isAndroid ? false : _vpn.isConnected;
    // The same reporter, not another one. Its reportsGoThroughTunnel is
    // what tells the backend whether it may read the carrier off the
    // source address, and a second instance would default to "through the
    // tunnel" and lose the carrier on every swept row.
    _sweep =
        sweep ??
        DoorSweep(
          read: _defaultRead,
          internet: _defaultInternet,
          reporter: _reporter,
        );
    _pairs = pairs ?? DoorPairRunner(sweep: _sweep, reporter: _reporter);
    _finder.answered = () => _answeredThisTap;
    _finder.addListener(notifyListeners);
    _vpn.addListener(_followCore);
  }

  static final _channel = TunnelChannels.method;

  final VpnService _vpn;

  /// Whether our API answered the phone on its own network at or after a
  /// time (ApiClient.answeredSince). Passed in by tests.
  final bool Function(DateTime since) _answeredSince;

  /// When the latest tap began. Null before the first.
  DateTime? _tapStartedAt;

  /// How this phone's latest taps ended, for the support chat
  /// (SupportState). One entry per run, given the outcome its trace gets,
  /// whether or not the backend has the trace on ([_begin]).
  final RecentTaps recentTaps;

  /// Whether our API answered the phone on its own network since the latest
  /// tap began. Such a tap has internet whatever its control fetch says, so
  /// it does not end at no internet or a cut way abroad: it gets the whole
  /// search a phone with internet gets. Read by the finder too
  /// (PathFinder.answered).
  bool get _answeredThisTap => _answeredAfter(_tapStartedAt);

  bool _answeredAfter(DateTime? since) {
    if (since == null) return false;
    try {
      return _answeredSince(since);
    } catch (e) {
      debugPrint('ConnectFlow: could not tell whether the API answered: $e');
      return false;
    }
  }

  /// The doors of this connect, in the order they would be tried. The
  /// standby doors of an attempt are picked from these.
  List<Server> _standbyPool = const [];

  /// The server the user picked for this connect, whose doors [_standbyPool]
  /// holds first. Null when they picked none.
  Server? _poolPreferred;

  /// Whether the standby doors of this connect may include doors dialled
  /// at an IPv6 address. Read once per connect, see [Ipv6Reach].
  bool _standbyIpv6 = true;
  final PathMemory _memory;
  final Ipv6Reach _ipv6;
  final PathFinder _finder;
  final VpnEventReporter _reporter;
  late final DoorSweep _sweep;

  /// The carrier's paired door test, if it has one (DedicatedState.doorPair).
  final DoorPairCheck? Function() _doorPair;
  late final DoorPairRunner _pairs;
  static DoorPairCheck? _noDoorPair() => null;
  final Future<String> Function() _networkKey;
  final Future<String?> Function() _carrier;

  /// Where the fallback's checks of community links go. Null sends them
  /// nowhere. main.dart passes the app's reporter.
  final CommunityChecks? _communityChecks;

  /// The backend's settings for the checklist, read once per tap. Null
  /// keeps the checklist as it was before the backend sent any.
  final ChecklistSettings? Function() _checklist;

  static ChecklistSettings? _currentChecklist() => ChecklistSettings.current;

  /// The backend's settings for the backup network, read when a tap ends
  /// without a tunnel. Null keeps it off. See [_backupNetwork].
  final PsiphonSettings? Function() _psiphon;
  static PsiphonSettings? _currentPsiphon() => PsiphonSettings.current;

  /// What this device's answers from the backend say about the backup
  /// network. main.dart passes DedicatedState's. Null keeps it off.
  final PsiphonDevice? Function() _psiphonDevice;
  static PsiphonDevice? _noPsiphonDevice() => null;

  /// Whether this is Android, and whether it is a TV. Asked by the backup
  /// network only, and passed in by tests.
  final bool Function() _android;
  final bool Function() _tv;
  static bool _isAndroid() => Platform.isAndroid;
  static bool _isTv() => FormFactor.isTv;

  /// Records and queues what each tap did, while the backend has the
  /// trace on. See [ConnectTraces].
  final ConnectTraces _traces;

  /// The trace of the latest tap. With the trace off, one that keeps only
  /// the outcome ([ConnectTrace.outcomeOnly]). Null before the first tap.
  /// Written to only by a run that is not stale, which is then the latest
  /// one.
  ConnectTrace? _trace;

  /// Whether the last tunnel attempt was given up on, rather than failing
  /// on its own: after [attemptTimeout], or for a door the checklist found
  /// open beside it ([_leaveDial]). For the trace.
  bool _attemptTimedOut = false;

  /// How long one tunnel attempt gets before it is called failed. Covers
  /// the service's own connect watchdog plus its traffic verification.
  final Duration attemptTimeout;

  ConnectStage _stage = ConnectStage.idle;
  Server? _chosen;
  bool _cancelled = false;
  int _run = 0;

  /// Whether a tunnel attempt on this tap failed because the VPN
  /// permission was refused or is held by another app. No fallback asks
  /// for it again.
  bool _permissionRefused = false;

  /// Whether the next dial is the first of a tap: the one dial that may
  /// take the phone's VPN slot from another VPN app
  /// (VpnService.allowTakingSlot). The rest of the tap's search and the
  /// search after a dead tunnel never may. A tap that dialled nothing
  /// leaves it to the first dial of a try later ([connect]).
  bool _tapDial = false;

  /// Whether another app's VPN was up when the user tapped. Asked at the
  /// tap, read before its search ([_takeSlotFirst]) and at its first dial
  /// ([_tapMayTakeSlot]). Null once the tap is over.
  Future<bool>? _otherVpnAtTap;

  /// How many VPN networks were not this app's when the user tapped
  /// (VpnService.otherVpnCount). Kept while the tap's take of the slot is
  /// ([_tapDial]), so a dial can tell whether a VPN came up since.
  Future<int?>? _vpnsAtTap;

  /// How many times [_armTapDial] has run, so a tap that ends after a newer
  /// one began leaves the newer one's [_otherVpnAtTap] alone.
  int _taps = 0;

  /// The run whose search was cut at the backend's
  /// [PsiphonSettings.startAfter] ([_cutSearch]). Null before any was.
  int? _cutRun;

  /// How the run in [_cutRun] ends when its search was cut ([_cutEnding]).
  ConnectStage _cutStage = ConnectStage.nothingOpen;

  /// A run whose cut came while the tunnel of a dial in flight was still
  /// being checked, which reads as a tunnel that carries ([_cutSearch]).
  /// The cut is made when that dial ends ([_attempt]). Null when none
  /// waits.
  int? _cutWaitRun;

  /// How the run in [_cutWaitRun] ends when its cut is made.
  ConnectStage _cutWaitStage = ConnectStage.nothingOpen;

  /// The latest run that set how it ended ([_finish], [_endOnAllowance]).
  int _endedRun = 0;

  /// Joins every row this tap produces: the door checks and the tunnel
  /// events that follow them. Null before the first connect.
  String? _attemptId;
  Completer<bool>? _pending;

  /// The door the tunnel settled on, and who to tell when it changes
  /// server. Kept from the last connect so a move the core makes later in
  /// the session is handled like one it made while connecting.
  Server? _onDoor;
  void Function(Server server)? _onSwitchedServer;

  /// Reads the server the selection names now, so a move is compared with
  /// what the card shows rather than with the server the tap started on.
  Server? Function()? _selection;

  /// Who to tell when the core moves from a shared link the fallback
  /// dialled to one of its spares (StandbyDoors.shared).
  void Function(Server server)? _onShared;

  /// Whether the allowance is spent now, for a tap that dials only shared
  /// links ([connectShared]). Null for any other tap.
  bool Function()? _blocked;

  /// The tap's question about the allowance, kept for the backup network,
  /// which asks it once more before it dials. Null when the tap has none.
  Future<bool> Function()? _allowanceSpent;

  /// That question, asked the first time a check of the run needs it
  /// ([_spent]), and its answer once it has come. Null when the run has not
  /// asked it.
  _AllowanceQuestion? _allowance;

  /// The fast path's dial in flight ([_fastPath]): its run, the network,
  /// the door's key and when the dial started. For [stop]. Null when none
  /// is in flight.
  ({int run, String network, String key, DateTime started})? _fastDial;

  /// The remembered door whose fast-path dial failed by itself in the run
  /// `run`, while that failure waits to be written down: from the moment
  /// the dial failed, through the allowance question ([_fastPath]), until
  /// the search says whether the phone has internet ([_connect]). For
  /// [cancel]. Null when none waits.
  ({int run, String network, String key})? _fastFailed;

  /// The latest forget of the door to try first ([_forgetFirst]). The next
  /// tap waits for it before it reads the memory ([_recall]).
  Future<void>? _forgetting;

  /// The wait before a tap tries again ([ConnectStage.waiting]), and how
  /// many tries the tap has made. See [_retryLater].
  Timer? _retry;
  int _retries = 0;

  /// Running since the latest try began: a tap, or a try after a wait. A
  /// try the wait's timer starts while the phone has no network waits for
  /// it to pass the longest wait ([_retryLater]).
  final Stopwatch _sinceTry = Stopwatch();

  /// The stage the try before the wait ended on. See [waitingAfter].
  ConnectStage? _waitingAfter;

  /// Whether the run under way was started because the tunnel stopped
  /// carrying data ([VpnService.stalled]), not by a tap. See [afterStall].
  bool _afterStall = false;

  /// Whether the latest try found no way abroad, at no internet or cut off,
  /// and nothing since has said the way is back: a check made while the
  /// tap waits ([_recheckWhileWaiting]), another network, a tunnel that
  /// came up, or a tap. StallRecovery sets it too ([noteOffline]).
  ///
  /// A try then skips the fast path. On a phone with no internet that dial
  /// brings the tunnel up only to fail, on every try of the wait, and the
  /// door it dials is the one to dial first once the internet is back. The
  /// checklist still checks that door, and finds it open when the phone
  /// has internet after all.
  bool _noWayAbroad = false;

  /// The checks of the way abroad a wait after no internet makes
  /// ([_recheckWhileWaiting]). Null while none runs.
  Timer? _recheck;

  /// Whether one of those checks is in flight.
  bool _rechecking = false;

  /// The latest run that started a diagnosis. From then on the finder's
  /// rows are that run's own ([_closedHere]).
  int _diagnosedRun = 0;

  // The stages of the try under way, or of the last one, for the screen
  // (clients #342). See [stageState].

  /// Whether a try is under way: from [_begin] to its end. False after a
  /// stop.
  bool _trying = false;

  /// The kind of route the try entered last ([_enter]).
  RouteKind? _route;

  /// The kinds the try has entered, the kinds it marked as not tried, and
  /// the kind it connected through.
  final Set<RouteKind> _entered = {};
  final Set<RouteKind> _skippedStages = {};
  RouteKind? _connectedOn;

  /// The kind the try entered first. The next try after a wait starts
  /// there too.
  RouteKind? _firstRoute;

  /// Whether the backup network could run on this try, as far as its
  /// settings and this device go ([_backupMayRun]).
  bool _backupAvailable = false;

  /// When the try under way started.
  DateTime? _searchStarted;

  /// When the wait before the next try ends ([ConnectStage.waiting]).
  DateTime? _retryAt;

  /// The door the fast path is dialling now: the one that last worked on
  /// this network, or a shared link the user picked. Null otherwise.
  Server? _fastDoor;

  /// The stages that get another turn later in this try, after the one
  /// that runs now: the own doors after a pick, and after the shared links
  /// while some are still to be checked or are checked again alone; the
  /// shared links after a pick. Such a stage reads pending until its next
  /// turn, not failed ([stageState]). A turn of its own takes it out
  /// ([_enter]).
  final Set<RouteKind> _again = {};

  /// Whether the wait before the next try is over, and that try is being
  /// made ready ([_retryLater]). The screen says it starts now, rather than
  /// counting down at 0:00.
  bool _retryStarting = false;

  /// The phone's network as [currentNetworkKey] names it, each time it
  /// changes. Watched while a tap waits to try again, so a phone whose
  /// network changes, or comes back, tries at once. Null watches nothing.
  /// main.dart passes the platform's.
  final Stream<String> Function()? _networkChanges;
  StreamSubscription<String>? _networkWatch;

  /// A number from 0 to 1, to spread the long waits of [_retryLater].
  final double Function() _random;

  /// How long after the network changed a waiting tap tries again: the
  /// new network's routes and names are not always ready the moment it
  /// is reported.
  final Duration networkSettle;

  ConnectStage get stage => _stage;

  /// The door the tunnel is going up through, or went up through.
  Server? get chosen => _chosen;

  /// The rows of the checklist, updated as each check completes.
  List<PathCheck> get checks => _finder.checks;

  /// Whether the phone has internet, for the checklist's internet row. Null
  /// while that is not known yet ([PathFinder.internet]).
  bool? get internet => _finder.internet;

  /// Whether a site inside the country answered once no site abroad did,
  /// for the same row ([PathFinder.cut]).
  bool? get cut => _finder.cut;

  /// While the tap waits to try again, the stage its last try ended on, so
  /// the screen can say why it waits. Null at any other stage.
  ConnectStage? get waitingAfter =>
      _stage == ConnectStage.waiting ? _waitingAfter : null;

  /// While the first search after a dead tunnel runs, so the screen can say
  /// why the app is looking without a tap. False at any other time, and
  /// from the first wait on: then the wait says why it waits.
  bool get afterStall =>
      _afterStall && isBusy && _stage != ConnectStage.waiting;

  bool get isBusy =>
      _stage == ConnectStage.fastPath ||
      _stage == ConnectStage.diagnosing ||
      _stage == ConnectStage.connecting ||
      _stage == ConnectStage.waiting;

  bool get isDiagnosing => _stage == ConnectStage.diagnosing;

  /// Whether the connect button's work is still looking for a way in, for
  /// the support chat, which sends it with a message: the search, the wait
  /// before the next try ([ConnectStage.waiting]), and every dial, the
  /// backup network's ([tryingBackup]) and the fast path's included. The
  /// same stages as [isBusy]. main.dart adds a tunnel that is being checked
  /// (VpnService.isVerifying).
  bool get searching => isBusy;

  /// Whether the backup network is being dialled, because nothing else
  /// connected on this try ([_backupNetwork]).
  bool get tryingBackup =>
      _stage == ConnectStage.connecting && (_chosen?.isPsiphon ?? false);

  /// Whether a try is searching now: dialling the door that last worked,
  /// checking doors or links, or bringing a tunnel up through one. A later
  /// stage may still run then. False while the tap waits to try again,
  /// where [searching], for the support chat, is true.
  bool get searchRunning =>
      stage == ConnectStage.fastPath ||
      stage == ConnectStage.diagnosing ||
      stage == ConnectStage.connecting;

  /// Whether the screen shows the search: the stages and the checklist.
  /// From the first second of a try, the fast path included, through the
  /// wait for the next try, and after a try while its rows explain how it
  /// ended ([showChecklist]).
  bool get showStages =>
      searchRunning || stage == ConnectStage.waiting || showChecklist;

  /// Whether the checklist's rows ([checks]) are this try's. The finder
  /// keeps the last try's rows until this one starts its first check.
  bool get checksAreThisTry => _diagnosedRun == _run;

  /// The kind of route the try is on while it searches, or null.
  RouteKind? get route => searchRunning && _trying ? _route : null;

  /// Where the stage of [kind] stands on the try under way, or on the last
  /// one once it has ended.
  ///
  /// A stage can run more than once in a try. A pick goes before the own
  /// doors, and the shared links come after them. The flow goes back to
  /// the own doors after the shared links when some own doors are still to
  /// be checked, or are checked again alone. Between its turns a stage
  /// reads pending, and it reads failed only once it has no turn left.
  /// Found 2026-10-24 in review: read failed between its turns, the screen
  /// said our servers did not connect after one door was checked, and then
  /// tried them again.
  StageState stageState(RouteKind kind) {
    if (_connectedOn == kind) return StageState.connected;
    if (_route == kind && _trying && searchRunning) return StageState.running;
    if (_again.contains(kind) && _trying && searchRunning) {
      return StageState.pending;
    }
    if (_entered.contains(kind)) return StageState.failed;
    if (!_trying || _skippedStages.contains(kind)) return StageState.skipped;
    return StageState.pending;
  }

  /// Whether the stage of [kind] belongs on screen at all. The backup
  /// network does not where it can never run: not on this device, off in
  /// the backend's settings, or not allowed for this device.
  bool stageAvailable(RouteKind kind) =>
      kind != RouteKind.backup || _backupAvailable || _entered.contains(kind);

  /// How far the try has got, while it searches: the furthest stage it has
  /// entered, counted among the stages on screen. Null otherwise.
  ///
  /// The number never goes down within a try, also when the try goes back
  /// to the own doors after the shared links, or tries a pick before them.
  /// Found 2026-10-24 in review: counted from the stage that ran at that
  /// moment, it read "Stage 2 of 3", then "Stage 1 of 3", then 2 again.
  ({int number, int count})? get stageProgress {
    if (route == null) return null;
    final shown = RouteKind.values.where(stageAvailable).toList();
    final reached = shown.lastIndexWhere(_entered.contains);
    return reached < 0 ? null : (number: reached + 1, count: shown.length);
  }

  /// While the tap waits to try again, the stage the next try starts
  /// with: the one the last try started with. Null at any other stage.
  RouteKind? get nextTryFrom =>
      stage == ConnectStage.waiting ? _firstRoute ?? RouteKind.own : null;

  /// While the tap waits to try again, when the next try starts. Null at
  /// any other stage, and once the wait is over ([nextTryStarting]).
  DateTime? get retryAt =>
      stage == ConnectStage.waiting && !_retryStarting ? _retryAt : null;

  /// Whether the wait before the next try is over and that try is being
  /// made ready: the shared links and this device's servers are asked for
  /// again, which can take several seconds (the caller's beforeRetry). The
  /// screen says the next try starts now. Found 2026-10-24 in review: the
  /// countdown read 0:00 for up to 8 seconds.
  bool get nextTryStarting => stage == ConnectStage.waiting && _retryStarting;

  /// Whether the backup network may run on a try on this device, as its
  /// settings and this device stand now. For the screen before a try has
  /// started, when [stageAvailable] still reads the last try.
  bool get backupMayRun => _backupMayRun();

  /// When the try under way started, while it searches. Null otherwise.
  DateTime? get searchStarted => searchRunning ? _searchStarted : null;

  /// The door the fast path is dialling now, while the try searches: the
  /// one that last worked on this network, or a shared link the user
  /// picked. Null when no such dial is in flight.
  Server? get fastPathDoor => searchRunning && _trying ? _fastDoor : null;

  /// Whether this try's checks found [server] closed: at least one of its
  /// rows read blocked, and none read open. For a server of this device's
  /// own, any of its doors counts. The error bar does not offer a server
  /// the screen has just shown blocked.
  bool foundClosed(Server server) {
    if (!checksAreThisTry) return false;
    var closed = false;
    for (final c in checks) {
      final same = server.isDedicated
          ? c.path.isDedicated && c.path.sameServerAs(server)
          : c.path.pathKey == server.pathKey;
      if (!same) continue;
      if (c.state == PathCheckState.open) return false;
      if (c.state == PathCheckState.blocked) closed = true;
    }
    return closed;
  }

  /// The try enters the stage of [kind]: it checks or dials a route of
  /// that kind now. Entering the backup network marks the stages it
  /// passed over without trying them as skipped, and no stage comes back
  /// after it.
  void _enter(RouteKind kind) {
    if (!_trying) return;
    _skippedStages.remove(kind);
    _entered.add(kind);
    _firstRoute ??= kind;
    if (kind == RouteKind.backup) {
      for (final k in RouteKind.values) {
        if (!_entered.contains(k)) _skippedStages.add(k);
      }
      _again.clear();
    }
    if (_route == kind) return;
    // The turn the stage was waiting for, if it was ([_again]).
    _again.remove(kind);
    _route = kind;
    notifyListeners();
  }

  /// The try starts with [picked], a shared link the user picked or one
  /// the fallback chose before: its stage runs now, from its first second.
  /// The own doors come after it, and the other shared links too when
  /// [sharedAfter], so their stages read pending until then.
  void _pickFirst(Server picked, {required bool sharedAfter}) {
    // Before the entry, which tells the screen.
    _again.add(RouteKind.own);
    _enter(RouteKind.of(picked));
    // After it: this entry is not the shared links' later turn.
    if (sharedAfter) _again.add(RouteKind.community);
  }

  /// The try ended without dialling the backup network it had entered
  /// ([_backupNetwork]): its stage reads skipped, not failed.
  void _passOverBackup() {
    _entered.remove(RouteKind.backup);
    _skippedStages.add(RouteKind.backup);
    if (_firstRoute == RouteKind.backup) _firstRoute = null;
  }

  /// A new try starts with no stage entered.
  void _startStages() {
    _trying = true;
    _route = null;
    _entered.clear();
    _skippedStages.clear();
    _again.clear();
    _connectedOn = null;
    _firstRoute = null;
    _fastDoor = null;
    _searchStarted = DateTime.now();
    _backupAvailable = _backupMayRun();
    // On the screen, but not on this round (PsiphonSettings.allowsRound).
    if (_backupAvailable && !(_psiphon()?.allowsRound(_retries) ?? false)) {
      _skippedStages.add(RouteKind.backup);
    }
  }

  /// Whether the backup network may run on some try on this device, as
  /// the gates of [_backupNetwork] that do not depend on the try stand.
  bool _backupMayRun() {
    final settings = _psiphon();
    return settings != null &&
        settings.stages.isNotEmpty &&
        _backupOnThisDevice(settings) &&
        _backupAllowed(settings, _psiphonDevice());
  }

  /// Whether the checklist has something to show: a diagnosis is running,
  /// or one just ended and its rows explain the outcome.
  bool get showChecklist =>
      checks.isNotEmpty &&
      (_stage == ConnectStage.diagnosing ||
          _stage == ConnectStage.connecting ||
          _stage == ConnectStage.nothingOpen ||
          _stage == ConnectStage.cutOff ||
          _stage == ConnectStage.failed ||
          _stage == ConnectStage.waiting);

  /// Stop whatever is in flight because the user tapped the button: as
  /// [cancel], and when the fast path's dial of the remembered door had run
  /// for the backend's FastPathSettings.forgetAfter without a verified
  /// tunnel, that door is forgotten on this network (PathMemory.forget), so
  /// the next tap starts with the checklist.
  ///
  /// Not counted as a failure. On Tehran day 2026-10-23, 564 taps were
  /// stopped on 159 phones, and about a third of the remembered-door dials
  /// the user stopped were of doors that worked. Dialled first again, the
  /// door costs the next tap the same wait.
  ///
  /// A pick of another server during a dial is not a stop: it only
  /// replaces the run ([cancel]). A stop after the dial failed by itself
  /// forgets the door as [cancel] does.
  void stop() {
    final dial = _fastDial;
    final after =
        (_checklist()?.fastPath ?? FastPathSettings.standard).forgetAfter;
    if (dial != null &&
        after != null &&
        dial.run == _run &&
        !_stale(dial.run) &&
        DateTime.now().difference(dial.started) >= after) {
      _forgetFirst(dial.network, dial.key);
    }
    cancel();
  }

  /// Stop whatever is in flight. The user tapped again, or picked another
  /// server, which starts a new run.
  ///
  /// The run in flight is stale from here on. It checks no more doors,
  /// dials nothing, falls back on nothing, and does not set the stage it
  /// would have ended on.
  ///
  /// When the fast path's dial of the remembered door failed by itself in
  /// that run, and the failure was not written down yet ([_fastFailed]),
  /// the door is forgotten on its network, with no failure counted
  /// ([_forgetFirst]). The failure waits for the search to say whether the
  /// phone has internet, and a stale run writes nothing. Found in review on
  /// 2026-10-24: a user who stopped during that search kept the dead door
  /// first, and the next tap dialled it again before any check. The forget
  /// starts here, not in the stale run, so the next tap is sure to wait for
  /// it before it reads the memory ([_recall]).
  void cancel() {
    final failed = _fastFailed;
    if (failed != null && failed.run == _run && !_stale(failed.run)) {
      _forgetFirst(failed.network, failed.key);
    }
    _fastFailed = null;
    _cancelled = true;
    _afterStall = false;
    // A stopped tap takes the slot no more ([_tapDial]).
    _tapDial = false;
    _otherVpnAtTap = null;
    _vpnsAtTap = null;
    _run++;
    _retry?.cancel();
    _retry = null;
    _stopWatchingNetwork();
    _finder.cancel();
    _trying = false;
    _fastDoor = null;
    // An attempt in flight stops waiting on the tunnel; the caller takes
    // the tunnel itself down.
    if (!(_pending?.isCompleted ?? true)) _pending!.complete(false);
    if (isBusy) _set(ConnectStage.cancelled);
  }

  /// Clear a finished outcome, so the screen goes back to "tap to connect".
  void reset() {
    if (isBusy) return;
    _set(ConnectStage.idle);
  }

  /// Connect through one of [paths], every door of every server this
  /// device owns, in the order the backend gave them.
  ///
  /// [preferred] is the server the user picked; its doors are tried first,
  /// and the fast path dials the remembered door only when it is one of
  /// them. Null when they picked none: the doors keep the backend's order,
  /// which ranks the ones that work on this carrier first, and the
  /// remembered door is dialled first whatever server it is on.
  ///
  /// [onSwitchedServer] is told when the door the tunnel comes up through
  /// belongs to another server than the selection, so the selection can
  /// follow. [selection] reads the server the selection names; without it,
  /// [preferred] stands in for it.
  ///
  /// [picked] is a shared link the user chose off the official or
  /// community list. It is not one of [paths]. It goes before anything
  /// else because the user chose it: it is checked on its own and dialled
  /// when it is open ([_checkPick]). When it is closed, or its tunnel
  /// fails, the tap carries on through [paths] instead of ending on an
  /// error.
  ///
  /// [allowanceSpent] is asked when a tunnel through one of [paths] fails,
  /// and when the checklist finds no door open: has this device used up
  /// its allowance? Once in a try: the first of those asks, and the others
  /// read its answer. The backend turns the device's servers off when it
  /// has, and from the phone that looks the same as every server being
  /// dead. On 2026-10-02 a new install went 3.6 MB over its 100 MB, was
  /// turned off, and its next tap ended at "Server not working, try
  /// another". When the answer is yes the flow stops and goes back to
  /// idle, and the screen says the allowance is spent.
  ///
  /// [shared] gives the shared links to fall back on when none of [paths]
  /// carried a tunnel, in the order the caller prefers them. The one that
  /// last worked on this network goes first whatever that order is. Ones
  /// under the name of an own door this tap found closed, and ones that
  /// failed on this network today, go last.
  /// [onShared] is told when the tunnel came up through one of them, so
  /// the selection can follow. On 2026-10-05 a phone on home wifi found
  /// every door of its own blocked and ended at "All routes are blocked"
  /// three times in two minutes, one minute after a shared link had
  /// connected it.
  ///
  /// [shared] is asked only then, so the links are the ones known at that
  /// moment, and the caller may load them first. It must give up on its
  /// own after a bounded wait; the checklist waits for its answer. A phone
  /// on home wifi once had an empty public list in memory after a fetch
  /// that never arrived, and ended at "All routes are blocked" with no
  /// shared link tried.
  ///
  /// [ownFirst] when [picked] is a shared link the fallback chose, not
  /// one the user picked: with the backend's [FallbackSettings.ownFirst],
  /// some of the device's own doors are checked beside it first, and one
  /// found open is dialled instead (see [_ownFirst]).
  ///
  /// With the backend's [RetrySettings], a tap that ended with nothing
  /// open tries again by itself after each of its waits, and [beforeRetry]
  /// runs before each try: the caller fetches the shared links again, and
  /// this device's own servers. [latest] gives the device's doors as they
  /// stand at each try, so a try after the backend moved a server to a new
  /// address dials the new one. Null, or none, keeps [paths].
  ///
  /// While the backend has the connect trace on, the tap is recorded step
  /// by step ([ConnectTrace]) and queued when it ends, however it ends.
  ///
  /// [trigger] is what started this run, for its trace: a tap on Connect
  /// or a pick of a server. With [afterStall] it is [TraceTrigger.stall]
  /// whatever is given. Each try the flow makes by itself after it says
  /// how that try started instead ([_retryLater]).
  Future<void> connect(
    List<Server> paths, {
    Server? preferred,
    Server? Function()? selection,
    Server? picked,
    bool ownFirst = false,
    Future<List<Server>> Function()? shared,
    void Function(Server server)? onSwitchedServer,
    void Function(Server server)? onShared,
    Future<bool> Function()? allowanceSpent,
    Future<void> Function()? beforeRetry,
    List<Server> Function()? latest,
    bool afterStall = false,
    TraceTrigger trigger = TraceTrigger.tap,
  }) async {
    if (isBusy || paths.isEmpty) return;
    _retries = 0;
    _afterStall = afterStall;
    final armed = _armTapDial(afterStall);
    // A tap is someone asking now, often because the internet is back. A
    // search after a dead tunnel keeps what StallRecovery found
    // ([_noWayAbroad]).
    if (!afterStall) _noWayAbroad = false;
    List<Server> doors() {
      final now = latest?.call();
      return now == null || now.isEmpty ? paths : now;
    }

    Future<void> tap(TraceTrigger trigger) => _tap(
      doors(),
      trigger: trigger,
      preferred: preferred,
      selection: selection,
      picked: picked,
      ownFirst: ownFirst,
      shared: shared,
      onSwitchedServer: onSwitchedServer,
      onShared: onShared,
      allowanceSpent: allowanceSpent,
    );
    await tap(afterStall ? TraceTrigger.stall : trigger);
    _tapOver(armed);
    // A tap a newer one replaced schedules no try of its own: the newer
    // tap's run owns the stage it would read.
    if (armed == _taps) _retryLater(tap, beforeRetry);
  }

  /// Let the first dial of this tap take the VPN slot ([_tapDial]), unless
  /// nobody tapped: the search after a dead tunnel ([afterStall]). Returns
  /// the tap's number, for [_tapOver].
  int _armTapDial(bool afterStall) {
    _tapDial = !afterStall;
    _otherVpnAtTap = afterStall ? null : _vpn.otherVpnUp();
    _vpnsAtTap = afterStall ? null : _vpn.otherVpnCount();
    return ++_taps;
  }

  /// The tap numbered [armed] has made its first try. One that dialled has
  /// used its take of the slot. One that dialled nothing, as most taps in a
  /// blackout do, leaves it to the first dial of a try later, which takes
  /// the slot only while no other app's VPN is up ([_tapMayTakeSlot]). After
  /// a reboot, or once another VPN app has run, Android gives this app no
  /// tunnel until it takes the slot, and the tries would never connect.
  void _tapOver(int armed) {
    if (armed == _taps) _otherVpnAtTap = null;
  }

  /// A tap made while another app's VPN was up takes the slot before its
  /// search (VpnService.takeSlotForTap), so the door checks and the control
  /// fetch see the phone's own network and not that VPN's, and the doors
  /// they find open are open here. Nothing for a try later or the search
  /// after a dead tunnel. Called at the start of a try, in [_connect] and
  /// [_connectShared], before either reads the network.
  Future<void> _takeSlotFirst() async {
    final atTap = _otherVpnAtTap;
    if (!_tapDial || atTap == null || !await atTap) return;
    // Taken: the switch the tap asked for is made. From here the tap's
    // first dial takes the slot only if no VPN has come up since, as for a
    // tap made with none up, so one the user turns back on during the
    // search stays on. Not when a newer tap has armed its own.
    if (await _vpn.takeSlotForTap() && identical(_otherVpnAtTap, atTap)) {
      _otherVpnAtTap = Future.value(false);
      _vpnsAtTap = _vpn.otherVpnCount();
    }
  }

  /// Another app's VPN holds the slot, and nobody tapped to take it back:
  /// the user has switched to that app. The tap ends as a stop ends it,
  /// with no next door, no retry and no failure reported, and the screen
  /// keeps no error from before.
  void _giveWay() {
    cancel();
    _vpn.clearAfterGivingWay();
  }

  /// Whether the tap's first dial may take the VPN slot: yes, unless another
  /// app's VPN came up after the tap. A user who tapped while one was up
  /// asked to switch to this app. A user who turned one on while this app
  /// was still searching has switched away from it.
  ///
  /// Another VPN that came up since is found two ways: one that carries
  /// this app's traffic, and one more VPN network than at the tap, which
  /// also finds a VPN for a few apps only. Such a VPN does not carry this
  /// app, and the first try of a retry could run minutes after the tap. A
  /// VPN up at the tap, in a work profile for one, does not stop the take.
  Future<bool> _tapMayTakeSlot() async {
    if (await (_otherVpnAtTap ?? Future.value(false))) return true;
    if (await _vpn.otherVpnUp()) return false;
    final before = await (_vpnsAtTap ?? Future<int?>.value());
    final now = await _vpn.otherVpnCount();
    return before == null || now == null || now <= before;
  }

  /// Wait, and then run [again], when the tap that just ended found
  /// nothing open and the backend's [RetrySettings] leave it a try.
  ///
  /// Taps ended at "All routes are blocked" on networks where most
  /// community links were cut too, and the user had to tap again. Psiphon
  /// and Lantern keep trying with a fresh list instead, and so does this,
  /// with longer and longer waits ([RetrySettings.waitBefore]) until data
  /// flows. Not after a stop, a spent allowance or a refused VPN
  /// permission: none of those is helped by waiting.
  ///
  /// Also after a cut way abroad ([ConnectStage.cutOff]) and after no
  /// internet, since 1.9.0. Before, a tap stopped there for good, and in a
  /// cut like Iran's of June 2025 that was every tap: the control sites
  /// abroad fail first, while a way through can open at any hour.
  ///
  /// The waits past the backend's list are spread by up to a fifth either
  /// way, so phones cut off by the same event do not all try at the same
  /// moment once it ends. A change of the phone's network ends the wait
  /// early ([networkSettle]), and the waits start over from the first.
  ///
  /// While the phone has no network at all, a try the wait's timer starts
  /// is skipped, unless the longest wait ([RetrySettings.longest], the
  /// backend's retry_longest_seconds) has passed since the last try began.
  /// Each skipped try waits as long as the next try would have, and the
  /// network is still watched, so a network that comes back tries within
  /// [networkSettle].
  /// With no network every route fails at once. On the four Tehran days to
  /// 2026-10-23, 1,409 taps that came within 12 minutes of a failed one
  /// started with no network: 1,350 of them ended at no internet and 31
  /// connected. A tap on the button is not skipped: 58 of 374 first taps
  /// with no network connected. Without a longest wait the waits end after
  /// the backend's list, and none is skipped.
  ///
  /// [again] is told what started each try, for its trace: the wait ran
  /// out ([TraceTrigger.retry]), the phone moved to another network
  /// ([TraceTrigger.network]), or a site abroad answered again
  /// ([TraceTrigger.recheck]).
  void _retryLater(
    Future<void> Function(TraceTrigger trigger) again,
    Future<void> Function()? before,
  ) {
    _stopWatchingNetwork();
    final retry = _checklist()?.retry;
    if (retry == null || _cancelled || _permissionRefused) return;
    if (!_tryAgainAfter.contains(_stage)) return;
    final wait = retry.waitBefore(_retries);
    if (wait == null) return;
    final spread = _retries < retry.after.length ? wait : _spread(wait);
    final waitIndex = _retries;
    _retries++;
    final run = _run;
    bool still() => run == _run && _stage == ConnectStage.waiting;
    Future<void> fire(TraceTrigger trigger) async {
      _retry?.cancel();
      _retry = null;
      _stopWatchingNetwork();
      if (!still()) return;
      // Another VPN app is up: the user has switched to it. A try would
      // check the doors through it, and its dial may not take the slot
      // back. The wait ends as a stop ends it. Up to 2.2.0 the try took the
      // slot and tore the other app's VPN down.
      if (await _vpn.otherVpnUp()) {
        if (still()) _giveWay();
        return;
      }
      // The wait is over. Making the next try ready can take several
      // seconds (the traces below, and [before]), and meanwhile the screen
      // says it starts now.
      _retryStarting = true;
      notifyListeners();
      // The traces of the taps before go ahead of the config request in
      // [before], so the backend has them when it answers it. Within
      // [_tracesFirstTimeout]: a phone that cannot reach the backend does
      // not wait longer on them before it tries.
      await _traces.sendWaiting().timeout(
        _tracesFirstTimeout,
        onTimeout: () {},
      );
      if (!still()) return;
      try {
        await before?.call();
      } catch (e) {
        debugPrint('ConnectFlow: could not get ready to try again: $e');
      }
      if (!still()) return;
      await again(trigger);
      _retryLater(again, before);
    }

    // What the timer runs: the try, unless the phone has no network and
    // the longest wait has not passed since the last try. A skipped try
    // waits as long as the next try would have, and no longer than the
    // longest wait from the last try.
    final longest = retry.longest;
    var skipped = 0;
    Future<void> timed() async {
      _retry = null;
      if (!still()) return;
      if (longest != null &&
          _sinceTry.elapsed < longest &&
          await _noNetwork()) {
        // A change of network or a recheck may have started the try while
        // the network was read.
        if (!still() || _retry != null) return;
        skipped++;
        final next = retry.waitBefore(waitIndex + skipped) ?? longest;
        final left = longest - _sinceTry.elapsed;
        final delay = next < left ? next : left;
        _retry = Timer(delay, timed);
        // The countdown on screen moves to the try after the skipped one
        // (clients #342).
        _retryAt = DateTime.now().add(delay);
        notifyListeners();
        return;
      }
      await fire(TraceTrigger.retry);
    }

    _waitingAfter = _stage;
    _afterStall = false;
    _retryAt = DateTime.now().add(spread);
    _retryStarting = false;
    _set(ConnectStage.waiting);
    _retry = Timer(spread, timed);
    _watchNetwork(() {
      if (!still()) return;
      // Another network may well have the internet this one did not.
      _noWayAbroad = false;
      _retries = 0;
      _retry?.cancel();
      _retry = Timer(
        networkSettle,
        () => unawaited(fire(TraceTrigger.network)),
      );
      _retryAt = DateTime.now().add(networkSettle);
      notifyListeners();
    });
    final every = retry.recheck;
    if (every != null && _offlineEndings.contains(_waitingAfter)) {
      _recheckWhileWaiting(every, still, () {
        // The way is back: try now, and start the waits over, as after a
        // change of network.
        _noWayAbroad = false;
        _retries = 0;
        _retry?.cancel();
        // fire() runs next and says the next try starts now.
        _retry = Timer(
          Duration.zero,
          () => unawaited(fire(TraceTrigger.recheck)),
        );
      });
    }
  }

  /// The endings of a try that found no way abroad: the phone has no
  /// internet, or only its way abroad is cut ([_noWayAbroad]).
  static const _offlineEndings = {ConnectStage.noInternet, ConnectStage.cutOff};

  /// Whether the platform says the phone is on no network at all: no
  /// Wi-Fi, no mobile data, no other. A read that fails says no.
  Future<bool> _noNetwork() async {
    try {
      return await _networkKey() == 'none';
    } catch (_) {
      return false;
    }
  }

  /// While a tap waits after a try that found no way abroad, ask every
  /// [every] whether the phone reaches a site abroad again
  /// (PathFinder.reachesAbroad), and call [back] the first time it does.
  ///
  /// The waits alone are not enough. Internet that comes back on the same
  /// network brings no change of network ([_watchNetwork]), and by a tap's
  /// fifth try the waits are 1 to 10 minutes long. A phone whose tunnel
  /// died with its network, as 248 of 493 dead tunnels did in the 72 hours
  /// to 2026-10-20 21:00 UTC, was connected again a median of 15 minutes
  /// later. With this it tries within [every] of the way coming back.
  ///
  /// One check at a time, and none once the wait is over ([still]). Each
  /// phone's checks run from the moment its own wait began, so phones cut
  /// off by the same event do not all try in the same second when it ends.
  void _recheckWhileWaiting(
    Duration every,
    bool Function() still,
    void Function() back,
  ) {
    _recheck = Timer.periodic(every, (_) async {
      if (_rechecking || !still()) return;
      _rechecking = true;
      try {
        final reaches = await _finder.reachesAbroad();
        if (reaches && still()) back();
      } finally {
        _rechecking = false;
      }
    });
  }

  /// The stages a tap can end on that a later try can change.
  static const _tryAgainAfter = {
    ConnectStage.nothingOpen,
    ConnectStage.failed,
    ConnectStage.cutOff,
    ConnectStage.noInternet,
  };

  /// [wait], longer or shorter by up to a fifth.
  Duration _spread(Duration wait) => Duration(
    microseconds: (wait.inMicroseconds * (0.8 + 0.4 * _random())).round(),
  );

  /// Calls [changed] each time the phone moves to another network than the
  /// one it is on now, except to none, until [_stopWatchingNetwork].
  void _watchNetwork(void Function() changed) {
    final changes = _networkChanges;
    if (changes == null) return;
    String? seen;
    unawaited(() async {
      try {
        final now = await _networkKey();
        seen ??= now;
      } catch (_) {}
    }());
    try {
      _networkWatch = changes().listen(
        (network) {
          final before = seen;
          seen = network;
          if (before == null || network == before || network == 'none') {
            return;
          }
          changed();
        },
        onError: (Object e) =>
            debugPrint('ConnectFlow: could not watch the network: $e'),
      );
    } catch (e) {
      debugPrint('ConnectFlow: could not watch the network: $e');
    }
  }

  /// Stop watching the network, and the checks of the way abroad that go
  /// with the same wait ([_recheckWhileWaiting]).
  void _stopWatchingNetwork() {
    unawaited(_networkWatch?.cancel());
    _networkWatch = null;
    _recheck?.cancel();
    _recheck = null;
  }

  /// One go at connecting: what [connect] does for a tap, and again for
  /// each try after it.
  /// Connect a phone that has no servers of its own: [picked] first, then
  /// the other links [shared] gives, several at a time, as the fallback
  /// checks them after a phone's own doors.
  ///
  /// Until 2026-10-11 such a phone dialled the one link on its card and
  /// stopped at "Server not working" when that link was blocked. It is the
  /// phone that most needs the rest: its own servers did not load because
  /// its network cuts our calls, and its links are the public list or the
  /// fallback file. A tunnel through any of them lets the app reach us
  /// again, and then its own servers load.
  ///
  /// [own] gives the device's own doors as they stand now. Its servers can
  /// arrive while this runs: a tap waits only a few seconds for them. As
  /// soon as there are some, at the start of a try or after the pick
  /// failed, the run hands over to the full checklist ([connect]'s path)
  /// with [preferredOwn], [onSwitchedServer] and [allowanceSpent]. [picked]
  /// goes first there only when [pickIsChoice]: a link that only stood in
  /// for servers that had not loaded is not the user's pick.
  /// [preferredOwn] is the server the user picked, as [connect]'s
  /// `preferred` is, and [selection] reads the server the selection names,
  /// as [connect]'s does, so a landing on another server moves the card
  /// without making that server a pick.
  ///
  /// [blocked] says whether the allowance is spent now. The shared links
  /// are unmetered, so a spent allowance ends the run before any dial.
  ///
  /// With the backend's [RetrySettings], a tap that found nothing open
  /// tries again by itself, as [connect] does. [trigger] is read as
  /// [connect] reads it.
  Future<void> connectShared(
    Server picked, {
    required Future<List<Server>> Function() shared,
    List<Server> Function()? own,
    Server? Function()? preferredOwn,
    Server? Function()? selection,
    bool pickIsChoice = false,
    bool pickByFallback = false,
    bool Function()? blocked,
    void Function(Server server)? onSwitchedServer,
    void Function(Server server)? onShared,
    Future<bool> Function()? allowanceSpent,
    Future<void> Function()? beforeRetry,
    bool afterStall = false,
    TraceTrigger trigger = TraceTrigger.tap,
  }) async {
    if (isBusy) return;
    _retries = 0;
    _afterStall = afterStall;
    final armed = _armTapDial(afterStall);
    // As in [connect].
    if (!afterStall) _noWayAbroad = false;
    Future<void> handOver(
      List<Server> paths,
      int run,
      String attemptId,
      ConnectTrace? trace, {
      required bool withPick,
    }) => _connect(
      paths,
      run,
      attemptId,
      trace,
      preferred: preferredOwn?.call(),
      // The user's pick, or a link the fallback chose before, goes first,
      // as on the normal path; the latter with our doors beside it.
      picked: withPick && (pickIsChoice || pickByFallback) ? picked : null,
      ownFirst: withPick && pickByFallback,
      // A pick that failed on this try is not checked again in the
      // fallback.
      exclude: withPick ? null : picked,
      shared: shared,
      // A landing on another server moves the selection through
      // [onSwitchedServer], which _begin keeps for _follow.
      onShared: onShared,
      allowanceSpent: allowanceSpent,
    );
    Future<void> tap(TraceTrigger trigger) => _begin(
      trigger: trigger,
      onSwitchedServer: onSwitchedServer,
      selection: selection,
      onShared: onShared,
      blocked: blocked,
      allowanceSpent: allowanceSpent,
      body: (run, attemptId, trace) {
        final paths = own?.call() ?? const <Server>[];
        if (paths.isNotEmpty) {
          return handOver(paths, run, attemptId, trace, withPick: true);
        }
        // No servers of this device's own to try yet. A handover to them
        // enters their stage after all. The pick's stage shows from its
        // first second, and the other shared links come after it.
        _skippedStages.add(RouteKind.own);
        _enter(RouteKind.of(picked));
        _again.add(RouteKind.community);
        return _connectShared(
          picked,
          run,
          attemptId,
          trace,
          shared: shared,
          own: own,
          blocked: blocked,
          pickIsChoice: pickIsChoice || pickByFallback,
          onShared: onShared,
          handOver: (paths) =>
              handOver(paths, run, attemptId, trace, withPick: false),
        );
      },
    );
    await tap(afterStall ? TraceTrigger.stall : trigger);
    _tapOver(armed);
    // A tap a newer one replaced schedules no try of its own: the newer
    // tap's run owns the stage it would read.
    if (armed == _taps) _retryLater(tap, beforeRetry);
  }

  Future<void> _connectShared(
    Server picked,
    int run,
    String attemptId,
    ConnectTrace? trace, {
    required Future<List<Server>> Function() shared,
    required Future<void> Function(List<Server> paths) handOver,
    List<Server> Function()? own,
    bool Function()? blocked,
    bool pickIsChoice = false,
    void Function(Server server)? onShared,
  }) async {
    if (_finder.isRunning) {
      await _finder.idle;
      if (_halted(run)) return;
    }
    if (_spentNow(blocked)) return;
    // Busy from here, while the network is read, so a tap on the button
    // stops this run rather than starting another beside it.
    _set(ConnectStage.diagnosing);
    // As before the own doors' checks: a tap made while another app's VPN
    // is up takes the slot first, so the control fetch and the pick's check
    // see the phone's own network ([_takeSlotFirst]). The pick has been
    // checked before its dial since 2.2.0, and that check went through the
    // other app's VPN.
    await _takeSlotFirst();
    if (_halted(run)) return;
    // The control fetch for the fallback's rows, started before the pick's
    // check and dial so it has their time to answer. Until 2026-10-12 this
    // path ran none. An offline phone sent a failed community check for
    // every link it looked at, which reached the backend once it was back
    // online, and put each of those links at the back for the day on that
    // network.
    final control = _finder.controlFetch();
    // Whether the phone reaches a site inside the country when it reaches
    // none abroad, which tells a cut way abroad from no internet.
    final reach = _finder.reach;
    // Read beside the pick's check, which does not wait for it.
    final networkKey = _networkKey();
    // The pick is checked before it is dialled. A closed one is not
    // dialled, and the other links are checked next.
    final pickOpen = await _checkPick(picked, run, networkKey, trace, control);
    if (pickOpen == null) return;
    if (pickOpen) {
      // The allowance can be found spent while the pick was checked. The
      // shared links are unmetered, so none is dialled then.
      if (_spentNow(blocked)) return;
      _set(ConnectStage.connecting, picked);
      if (await _attempt(picked, run)) {
        // A link that only stood in for servers that had not loaded now
        // carries the tunnel, so it becomes the shared server in use, as a
        // link the fallback found does. Otherwise the card would name the
        // device's own server once that loads, while the tunnel stays
        // here.
        if (!pickIsChoice) onShared?.call(picked);
        _finish(ConnectStage.done, picked, run);
        await _rememberShared(picked);
        return;
      }
      if (_stale(run)) return;
      // The VPN permission was refused or is held by another app: no other
      // link needs anything else, and the error on screen says what to do.
      if (_permissionRefused) {
        _finish(ConnectStage.failed, picked, run);
        return;
      }
    }
    // The device's own servers arrived while the pick was checked or
    // dialled.
    final paths = own?.call() ?? const <Server>[];
    if (paths.isNotEmpty) {
      _vpn.clearError();
      // A pick found closed is written down by its check ([_checkPick]).
      if (pickOpen) await _memory.markFailed(await networkKey, picked.pathKey);
      if (_halted(run)) return;
      return handOver(paths);
    }
    if (_spentNow(blocked)) return;
    // The failure is already reported. Left on screen, it would tell the
    // user to try another server while the app is doing exactly that.
    _vpn.clearError();
    final network = await networkKey;
    if (_stale(run)) return;
    // The other links are checked even when the control fetch failed, as
    // in the diagnosis after the own doors (_connect). A failed fetch does
    // not prove the phone is offline: in the 24 hours to 01:00 Tehran on
    // 2026-10-12, 19 of 30 traces of first taps that ended at no internet
    // reached the backend within 2 minutes. Their rows and the links found
    // closed wait for the fetch in _fallBack, so a phone that is offline
    // sends none of them and writes none of them down. After a cut
    // ([_cutSearch]) it checks none, and the pick's failure below is still
    // written down, as for a pick whose dial failed without a cut.
    final (how, failed) = await _fallBack(
      shared,
      picked,
      network,
      run,
      onShared,
      trace,
      control,
    );
    // A stopped tap writes nothing more. Found 2026-10-12 in review: a tap
    // stopped while its control fetch still ran wrote the pick's failure
    // once the fetch answered. By then the next tap had connected through
    // the same pick, and the memory forgot it as the shared link that last
    // worked on this network.
    if (_stale(run)) return;
    // A link found open says the phone has internet. Without one, the
    // control fetch started before the dial says it, and it has nearly
    // always answered by now.
    final linkOpen =
        how == _Fallback.failed ||
        (how == _Fallback.ended && _stage == ConnectStage.done);
    // So does an answer from our API since the tap began: our API is abroad.
    final online = linkOpen || await control || _answeredThisTap;
    if (_stale(run)) return;
    // The pick's tunnel failed. Written down only on a phone with internet:
    // on one without, every dial fails, and the failure would put the pick
    // at the back for the day on this network. A pick found closed was not
    // dialled, and its check wrote it down ([_checkPick]).
    if (online && pickOpen) await _memory.markFailed(network, picked.pathKey);
    if (how == _Fallback.ended || _halted(run)) return;
    // The device's own servers arrived during the race: they get their
    // turn now, rather than after the retry wait or never.
    final arrived = own?.call() ?? const <Server>[];
    // Not after a refused VPN permission: the error says what to do, and a
    // door of ours would ask for the same permission again.
    if (arrived.isNotEmpty && !_permissionRefused) {
      _vpn.clearError();
      return handOver(arrived);
    }
    // No link open and the fetch failed: the phone has no internet, as far
    // as it can tell, or only its way abroad is cut. The screen says which,
    // and the run tries again (_retryLater).
    if (!online) {
      final cut = await reach == NetReach.cut;
      if (_halted(run)) return;
      _finish(cut ? ConnectStage.cutOff : ConnectStage.noInternet, null, run);
      return;
    }
    _finish(
      how == _Fallback.failed ? ConnectStage.failed : ConnectStage.nothingOpen,
      failed,
      run,
    );
  }

  /// Whether [blocked] says the allowance is spent. Ends the run the way
  /// [_spent] does: no error, back to idle, the trace says why.
  bool _spentNow(bool Function()? blocked) {
    if (!(blocked?.call() ?? false)) return false;
    _endOnAllowance();
    return true;
  }

  /// End the run on a spent allowance: no error, back to idle, and the
  /// trace says why. The screen says the allowance is spent.
  void _endOnAllowance() {
    _endedRun = _run;
    _vpn.clearError();
    _set(ConnectStage.idle);
    _trace?.end(TraceOutcome.allowance);
  }

  /// The words the connect trace gives the endings a later try can change,
  /// as [PsiphonSettings.stages] names them.
  static const _endingWords = {
    ConnectStage.nothingOpen: 'all_closed',
    ConnectStage.failed: 'failed',
    ConnectStage.cutOff: 'cut_off',
    ConnectStage.noInternet: 'no_internet',
  };

  /// The last thing a try that ended without a tunnel does: dial the
  /// backup network (Server.psiphon, clients #299).
  ///
  /// It runs after the try's own doors and its community links have both
  /// had their turn, on the tap and on every try after a wait
  /// ([_retryLater]), and only when all of these hold:
  ///
  /// - no tunnel is up and carrying data ([_tunnelCarries]). The dial
  ///   takes the tunnel that is up down first, and a tap or a pick can end
  ///   with nothing open while the tunnel it started on still works. A
  ///   dead one ([VpnService.stalled]) is replaced, as a door would replace
  ///   it;
  /// - this is Android, and not a TV unless the backend lets TVs use it;
  /// - the backend sent the network's settings ([PsiphonSettings]);
  /// - the device's last answer from the backend lets it use the network,
  ///   or, on a phone with no such answer yet, the settings do;
  /// - the allowance is not spent, asked of the backend once more, and
  ///   when it cannot be asked, as the phone last heard it. Nothing meters
  ///   the backup network, so a spent allowance would mean no limit;
  /// - the VPN permission was not refused on this tap: the network needs
  ///   the same permission;
  /// - the try ended on a stage the settings name, it was not stopped or
  ///   replaced, and its round is one the settings allow.
  ///
  /// Connected, the tap ends there, and the trace says so. Nothing about
  /// it is written to the door memory, the selection does not move to it,
  /// and no door is checked or swept after it: it is neither a door of
  /// ours nor a link a later tap should try first. When it fails, the try
  /// ends as it ended before, so the screen and the retries see what they
  /// would have seen without it.
  ///
  /// With the backend's [PsiphonSettings.startAfter], a try can get here
  /// before it has checked every door and link: see [_cutSearch].
  Future<void> _backupNetwork(int run, ConnectTrace? trace) async {
    final ended = _stage;
    final settings = _backupGates(run, ended);
    if (settings == null) return;
    final endedOn = _chosen;
    // The way the try ended before, for the screen and the retries.
    void endAsBefore() {
      _chosen = endedOn;
      _set(ended);
    }

    // Busy from here, while the allowance is asked too, so a tap on the
    // button stops this rather than starting another tap beside it.
    _set(ConnectStage.connecting, Server.psiphon);
    final within = await _backupWithinAllowance(settings, run);
    if (_stale(run)) {
      // Stopped: the tap ended on the stop, not on how the try ended.
      trace?.end(TraceOutcome.stopped);
      return;
    }
    if (!within) {
      // Not dialled: its stage was passed over after all.
      _passOverBackup();
      // A spent allowance has ended the run already.
      if (_stage == ConnectStage.connecting) endAsBefore();
      return;
    }
    // A tunnel that came up late, after its attempt was given up on, while
    // the allowance was asked.
    if (_tunnelCarries) {
      _passOverBackup();
      endAsBefore();
      return;
    }
    // A failed tunnel through a door before it leaves the service in
    // error, which would end this attempt before it starts.
    _vpn.clearError();
    final ok = await _attempt(
      Server.psiphon,
      run,
      source: LinkSource.psiphon,
      standby: const [],
      // Its own time to come up, then the traffic check every attempt has.
      timeout: settings.establishTimeout + attemptTimeout,
    );
    if (_stale(run)) {
      trace?.end(TraceOutcome.stopped);
      return;
    }
    if (ok) {
      _finish(
        ConnectStage.done,
        Server.psiphon,
        run,
        outcome: TraceOutcome.psiphon,
      );
      return;
    }
    // The failure is reported already. Left on screen, it would name a
    // network the user never chose. A refused VPN permission stays, since
    // its message says what to do.
    if (!_permissionRefused) _vpn.clearError();
    endAsBefore();
    if (_permissionRefused) trace?.reword(_outcomeOf(ended));
  }

  /// The backend's settings for the backup network when every gate of
  /// [_backupNetwork] but the allowance question is open for a try of
  /// [run] that ended on [ended], or null when one is closed. The same
  /// gates decide whether the try may be cut short for it ([_armCut]).
  PsiphonSettings? _backupGates(int run, ConnectStage ended) {
    if (_stale(run) || _permissionRefused || _tunnelCarries) return null;
    final word = _endingWords[ended];
    if (word == null) return null;
    final settings = _psiphon();
    if (settings == null || !_backupOnThisDevice(settings)) return null;
    if (!settings.stages.contains(word)) return null;
    if (!settings.allowsRound(_retries)) return null;
    if (!_backupAllowed(settings, _psiphonDevice())) return null;
    return settings;
  }

  /// Starts the clock of the backend's [PsiphonSettings.startAfter] for
  /// [run]. Only when the backend sends one, and when every gate of the
  /// backup network that does not wait on how the try ends is open for a
  /// try that ends at nothing open ([_backupGates]). Null otherwise: the
  /// try runs to its own end, as before. The function returned disarms it:
  /// [_begin] calls it once the try's search is over.
  void Function()? _armCut(int run) {
    final after = _psiphon()?.startAfter;
    if (after == null || _backupGates(run, ConnectStage.nothingOpen) == null) {
      return null;
    }
    var armed = true;
    final timer = Timer(after, () async {
      final ending = await _cutEnding();
      if (armed) _cutSearch(run, ending);
    });
    return () {
      armed = false;
      timer.cancel();
    };
  }

  /// How a try that is cut now ends, from what its control fetch found. At
  /// nothing open when the phone reaches a site abroad, or found a door or
  /// a link open. At cut off when it reaches only a site inside the
  /// country, and at no internet when it reaches neither: the endings a
  /// search that ran to its end would have had. A fetch that has not
  /// answered yet is waited for, so the search goes on meanwhile.
  Future<ConnectStage> _cutEnding() async {
    if (_finder.internet == true || _answeredThisTap) {
      return ConnectStage.nothingOpen;
    }
    return switch (await _finder.reach) {
      NetReach.open => ConnectStage.nothingOpen,
      NetReach.cut => ConnectStage.cutOff,
      NetReach.offline => ConnectStage.noInternet,
    };
  }

  /// The backend's [PsiphonSettings.startAfter] has passed on [run], the
  /// try has no tunnel, and it ends on [ending] when it is cut now
  /// ([_cutEnding]). The search stops at its next safe point, so the
  /// backup network is dialled sooner.
  ///
  /// Not when the try has ended, nor when a gate of the backup network is
  /// closed for [ending] ([_backupGates]): a tunnel came up and carries
  /// data, the VPN permission was refused, the allowance was found spent,
  /// the backend changed its answer, or [PsiphonSettings.stages] leaves
  /// that ending out. So a phone whose control fetch failed is cut only
  /// when the stages name no_internet, or cut_off when only its way abroad
  /// is cut. Otherwise its search runs to its end, as before.
  ///
  /// The checks running now stop as they stop when the user stops the tap
  /// ([PathFinder.cutShort]): a search of several checks at once ends at
  /// once, and a search of one check at a time, or a race of shared links,
  /// once the checks in flight have answered. From here the try starts no
  /// check and no race of shared links ([_halted]). A door or link it
  /// found open before the cut, or in a check that ran to its end after
  /// it, is still dialled, as it would have been. When none connects, the
  /// next safe point ends the try on [ending] ([_endOnCut]). So
  /// [_backupNetwork] runs at once, with all its gates, the allowance
  /// question included.
  ///
  /// A dial in flight is not touched. One that connects ends the try
  /// connected, as before. One that fails is handled as before, its door's
  /// failure mark included.
  ///
  /// The doors and links the cut left unchecked are not written to the
  /// door memory or marked failed, and nothing is remembered because of
  /// the cut: on the phone it writes what a stop writes. The own doors the
  /// search did check go to the backend as the rows of a search whose time
  /// ran out do, and the trace gives the ones it left that reason.
  void _cutSearch(int run, ConnectStage ending) {
    if (_endedRun == run) return;
    if (_backupGates(run, ending)?.startAfter == null) {
      // A dial in flight holds the VPN up while its tunnel's traffic is
      // checked, and that reads as a tunnel that carries. How the dial
      // ends decides: the cut is made then, when the gates are open.
      if (_vpn.isConnected && _vpn.isVerifying && !_stale(run)) {
        _cutWaitRun = run;
        _cutWaitStage = ending;
      }
      return;
    }
    _cutWaitRun = null;
    _cutRun = run;
    _cutStage = ending;
    _finder.cutShort();
  }

  /// Whether the search of [run] was cut ([_cutSearch]) and the cut holds:
  /// the run is not stale, has not ended, and has had no VPN permission
  /// refused. After a refusal the try ends as before: the backup network
  /// needs the same permission, so it would not be dialled.
  bool _cutHere(int run) =>
      run == _cutRun && _endedRun != run && !_permissionRefused && !_stale(run);

  /// Whether [run] is to start no further check, race or dial: it was
  /// stopped or replaced ([_stale]), or its search was cut ([_cutHere])
  /// and it holds no [found], a door or link found open that a cut run
  /// still dials. Each place that asks returns as it does for a stop.
  bool _halted(int run, [Server? found]) =>
      _stale(run) || (found == null && _cutHere(run));

  /// Ends [run] on the ending [_cutSearch] chose when its search was cut and
  /// it has not ended otherwise, with the cut as a step in [trace]: its ms
  /// is how long the tap had run since [started].
  void _endOnCut(int run, ConnectTrace? trace, DateTime started) {
    if (!_cutHere(run)) return;
    final now = DateTime.now();
    trace?.add(
      Server.psiphon,
      TraceStage.cut,
      TraceResult.cut,
      ms: now.difference(started).inMilliseconds,
      began: now,
    );
    _finish(_cutStage, null, run);
  }

  /// Whether a tunnel is up and has not been found dead. The backup
  /// network leaves it alone ([_backupNetwork]).
  bool get _tunnelCarries => _vpn.isConnected && !_vpn.stalled;

  /// Whether this device is one the backup network runs on.
  bool _backupOnThisDevice(PsiphonSettings settings) =>
      _android() && (!_tv() || settings.tv);

  /// Whether [device] may use the backup network, as its answers stand.
  static bool _backupAllowed(PsiphonSettings settings, PsiphonDevice? device) =>
      device != null && (device.allowed ?? settings.enabled) && !device.blocked;

  /// Whether the allowance leaves room for the backup network. Asks the
  /// tap's question once more, within [_spentTimeout]. A yes ends the run
  /// as [_spent] does. No answer in time, an error, or an answer that did
  /// not reach the backend leaves it to the allowance the phone last heard:
  /// spent, or nothing left on a metered allowance, is no.
  Future<bool> _backupWithinAllowance(PsiphonSettings settings, int run) async {
    final ask = _allowanceSpent;
    bool? spent;
    if (ask != null) {
      try {
        spent = await ask().timeout(_spentTimeout);
      } on TimeoutException {
        spent = null;
      } catch (e) {
        debugPrint('ConnectFlow: could not ask about the allowance: $e');
        spent = null;
      }
    }
    if (_stale(run)) return false;
    if (spent == true) {
      _endOnAllowance();
      return false;
    }
    // The answer can have changed what the device is allowed.
    final device = _psiphonDevice();
    if (!_backupAllowed(settings, device)) return false;
    if (spent == null || !device!.quotaFresh) return !device!.quotaSpent;
    return true;
  }

  Future<void> _tap(
    List<Server> paths, {
    required TraceTrigger trigger,
    Server? preferred,
    Server? Function()? selection,
    Server? picked,
    bool ownFirst = false,
    Future<List<Server>> Function()? shared,
    void Function(Server server)? onSwitchedServer,
    void Function(Server server)? onShared,
    Future<bool> Function()? allowanceSpent,
  }) => _begin(
    trigger: trigger,
    onSwitchedServer: onSwitchedServer,
    selection: selection,
    onShared: onShared,
    allowanceSpent: allowanceSpent,
    body: (run, attemptId, trace) => _connect(
      paths,
      run,
      attemptId,
      trace,
      preferred: preferred,
      picked: picked,
      ownFirst: ownFirst,
      shared: shared,
      onShared: onShared,
      allowanceSpent: allowanceSpent,
    ),
  );

  /// Start a tap: a new run, a new attempt id and trace, and [body] to do
  /// the work. The trace is ended and sent however [body] ends.
  ///
  /// When [body] ends without a tunnel, the backup network may be dialled
  /// before the trace goes ([_backupNetwork]). With the backend's
  /// [PsiphonSettings.startAfter], [body] can be cut short for it
  /// ([_cutSearch]).
  ///
  /// The trace says what started the run ([trigger]). Each run has its
  /// own attempt id, the tries the flow makes by itself included, and
  /// nothing else the phone sends tells a person's tap from those tries.
  Future<void> _begin({
    required TraceTrigger trigger,
    required Future<void> Function(
      int run,
      String attemptId,
      ConnectTrace? trace,
    )
    body,
    void Function(Server server)? onSwitchedServer,
    Server? Function()? selection,
    void Function(Server server)? onShared,
    bool Function()? blocked,
    Future<bool> Function()? allowanceSpent,
  }) async {
    final run = ++_run;
    _blocked = blocked;
    _allowanceSpent = allowanceSpent;
    _allowance = null;
    _cancelled = false;
    _chosen = null;
    // One id for the whole tap: the door checks below and the tunnel events
    // the service writes after them. Made here rather than in the service
    // because the checks happen first, and an attempt whose probes carry a
    // different id than its outcome cannot be reassembled.
    final attemptId = _attemptId = newAttemptId();
    _standbyPool = const [];
    _poolPreferred = null;
    _standbyIpv6 = true;
    _onDoor = null;
    _onSwitchedServer = onSwitchedServer;
    _selection = selection;
    _onShared = onShared;
    _permissionRefused = false;
    _startStages();
    final started = _tapStartedAt = DateTime.now();
    final tap = recentTaps.began();
    // With the trace off, a trace that keeps only the outcome, for
    // [recentTaps]. Only one the backend asked for is sent.
    final sent = _traces.start(attemptId);
    final trace = _trace =
        sent ??
        ConnectTrace.outcomeOnly(attemptId: attemptId, startedAt: started);
    trace.startedBy(trigger);
    _sinceTry
      ..reset()
      ..start();
    final disarm = _armCut(run);
    try {
      await body(run, attemptId, trace);
      disarm?.call();
      _endOnCut(run, trace, started);
      await _backupNetwork(run, trace);
    } finally {
      disarm?.call();
      // The try is over: a stage it did not enter was not tried. A stopped
      // run leaves this to [cancel], and a newer run owns the stages.
      if (run == _run && _trying) {
        _trying = false;
        if (!_disposed) notifyListeners();
      }
      // Every way the tap ends sets the outcome, except a stop, which the
      // trace reads as its default. A run that is not stale and set none
      // ended on an error.
      if (trace.outcome == null && !_stale(run)) {
        trace.end(TraceOutcome.failed);
      }
      recentTaps.ended(tap, trace.outcome ?? TraceOutcome.stopped);
      if (sent != null) unawaited(_traces.send(sent));
    }
  }

  /// The tap [connect] started, as the run [run] with the attempt id
  /// [attemptId]. Its steps go into [trace] when there is one.
  Future<void> _connect(
    List<Server> paths,
    int run,
    String attemptId,
    ConnectTrace? trace, {
    Server? preferred,
    Server? picked,
    bool ownFirst = false,
    Future<List<Server>> Function()? shared,
    void Function(Server server)? onShared,
    Future<bool> Function()? allowanceSpent,
    Server? exclude,
  }) async {
    // A search the user stopped can still have a check in flight. A tap
    // right after a stop waits for a one-at-a-time search to end, rather
    // than starting a second search that writes the same rows. A search
    // with several checks at once ends at once on a stop, and a late
    // answer from it changes none of the next tap's rows (PathFinder.idle).
    if (_finder.isRunning) {
      await _finder.idle;
      if (_halted(run)) return;
    }

    // Own doors found closed beside the pick, or whose tunnel failed there.
    // The fast path below does not dial them again.
    final closedFirst = <String>{};
    // The ones of those the diagnosis checks after the other own doors
    // (_ownFirst says which).
    final demoted = <String>{};
    var pickedClosed = false;
    // Whether [picked] was checked on its own and found closed
    // ([_checkPick]). It was not dialled then, and its check wrote it down.
    var pickCheckedClosed = false;
    final ownFirstDoors = ownFirst ? _checklist()?.fallback?.ownFirst : null;
    // The try starts with the pick, whose stage shows from the first
    // second (clients #342). With ownFirst our doors are checked beside it
    // first, which is their stage.
    if (picked != null && ownFirstDoors == null) {
      _pickFirst(picked, sharedAfter: shared != null);
    }
    // A tap made while another app's VPN is up takes the slot before
    // anything below reads the network ([_takeSlotFirst]): the network key
    // and the door memory under it, the pick's check, the own doors checked
    // beside a fallback's pick, the fast path's dial and the search, which
    // can start beside that dial. All of them would see that VPN's network
    // otherwise. A handover from [_connectShared] has taken it already.
    // After the pick's stage, which shows from the first second.
    await _takeSlotFirst();
    if (_halted(run)) return;
    if (picked != null && ownFirstDoors != null) {
      final pickedOpen = await _ownFirst(
        paths,
        preferred,
        picked,
        run,
        ownFirstDoors,
        attemptId,
        trace,
        closedFirst,
        demoted,
      );
      // The pick's dial after the check is its stage's turn.
      if (pickedOpen ?? false) _pickFirst(picked, sharedAfter: shared != null);
      if (pickedOpen == null) return;
      pickedClosed = !pickedOpen;
    } else if (picked != null) {
      final pickedOpen = await _checkPick(
        picked,
        run,
        _networkKey(),
        trace,
        _finder.controlFetch(),
      );
      if (pickedOpen == null) return;
      pickedClosed = pickCheckedClosed = !pickedOpen;
    }

    if (picked != null && !pickedClosed) {
      // The allowance can be found spent while the pick was checked, as in
      // _connectShared: on a tap of a shared link that handed over to the
      // device's own servers ([_blocked] is set then). The shared links are
      // unmetered, so none is dialled then.
      if (_spentNow(_blocked)) return;
      _set(ConnectStage.connecting, picked);
      if (await _attempt(picked, run)) {
        _finish(ConnectStage.done, picked, run);
        await _rememberShared(picked);
        return;
      }
      if (_stale(run)) return;
      // The failure is already reported. Left on screen, it would tell the
      // user to try another server while the app is doing exactly that.
      _vpn.clearError();
    }

    final network = await _networkKey();
    _reportNetwork = network;
    if (picked != null && !pickCheckedClosed) {
      await _memory.markFailed(network, picked.pathKey);
    }
    if (_halted(run)) return;
    final ordered = _ordered(paths, preferred);
    _standbyPool = ordered;
    _poolPreferred = preferred;
    // A platform read, or one from storage: no network call.
    _standbyIpv6 = await _ipv6.usable(network);
    if (_halted(run)) return;
    // The first stage of the search: this device's own servers, from the
    // fast path on (clients #342).
    _enter(RouteKind.own);

    // Fast path: the door that carried traffic last time on this network.
    // When the user picked their server, only when it is one of that
    // server's doors: another server's door is not what they asked for,
    // and is still what the diagnosis tries first if their server turns
    // out to be dead. When they picked none, whatever server it is on, and
    // the selection follows it. The selection is then only where an
    // earlier tap landed, maybe on another network, and the remembered
    // door is what worked here: in the 24 hours to 01:00 Tehran on
    // 2026-10-12, own-door fast-path dials got through on the first door
    // 243 of 247 times, leaving out phones with no internet.
    final remembered = await _recall(network);
    if (_halted(run)) return;
    // Not while the phone is known to have no way abroad ([_noWayAbroad]).
    // The checklist below then checks the remembered door like any other,
    // with no tunnel brought up for it.
    final first = remembered == null || _noWayAbroad
        ? null
        : ordered
              .where((p) => p.pathKey == remembered)
              .where((p) => preferred == null || _sameServer(p, preferred))
              .where((p) => !closedFirst.contains(p.pathKey))
              .firstOrNull;

    // Diagnosis. Read before the fast path, because its search can start
    // beside the fast path's dial ([_fastPath]). The remembered door goes
    // last, rather than being checked first: its dial is under way, or has
    // failed just now.
    final settings = _checklist();
    // Several own doors at once unless the backend says otherwise. Without
    // a word from it this is DoorCheckSettings.standard, not the search of
    // 1.7.0: a phone that never reached the backend needs it most.
    final doorChecks = settings?.doors ?? DoorCheckSettings.standard;
    final skip = await _memory.skippable(
      network,
      holding: [for (final p in ordered) p.pathKey],
      rule: settings?.skip,
    );
    // Checked here and not left to the finder: it forgets a stop that
    // came before the search started.
    if (_halted(run)) return;
    // The own doors _ownFirst moved back go after the others too, and before
    // the remembered door: the ones that failed beside a fallback's pick for
    // a reason other than "no answer", and the one whose tunnel failed
    // there. They are moved, never dropped. One found closed seconds ago
    // would cost a check before any door not looked at yet. One whose
    // tunnel just failed would pass its check again and be dialled again,
    // and when that dial failed too the tap went to the shared links with
    // the doors after it never checked. In the 24 hours to 01:00 Tehran on
    // 2026-10-12, 121 taps started on a community link the fallback chose
    // while the phone had none of its own servers, so they dialled the link
    // with no check. Since #256 the phone keeps its own servers between
    // launches (DedicatedState.prefSaved), so most of those taps now run
    // that check.
    final candidates = [
      for (final p in ordered)
        if (p != first && !demoted.contains(p.pathKey)) p,
      for (final p in ordered)
        if (p != first && demoted.contains(p.pathKey)) p,
      ?first,
    ];
    // With the backend's FallbackSettings.after, the own doors get that
    // long before the shared links are checked.
    final early = shared == null ? null : settings?.fallback?.after;
    // How long a search goes on starting door checks once its control fetch
    // failed: FallbackSettings.after, or PathFinder's default without it.
    final offlineFor =
        settings?.fallback?.after ?? PathFinder.defaultOfflineBudget;
    // When the search started, beside the fast path's dial or after it.
    var searched = DateTime.now();
    Future<PathFinding> search() {
      _set(ConnectStage.diagnosing);
      searched = DateTime.now();
      return _finder.find(
        candidates,
        skip: skip,
        budget: early,
        // A tap whose control fetch failed gets the same time on its own
        // doors before the shared links are checked (PathFinder.find).
        offlineBudget: offlineFor,
        parallel: doorChecks.parallel,
        stagger: doorChecks.stagger,
      );
    }

    // Whether the fast path dialled [first] and its tunnel failed. Written
    // down once the search below says whether the phone has internet.
    var fastPathFailed = false;
    // The search, when it started beside the fast path's dial.
    Future<PathFinding>? beside;
    if (first != null) {
      final fast = await _fastPath(
        first,
        run,
        network,
        settings,
        search: search,
        paths: paths,
        preferred: preferred,
        allowanceSpent: allowanceSpent,
      );
      if (fast == null) return;
      fastPathFailed = fast.failed;
      beside = fast.search;
    }
    if (beside == null && _halted(run)) return;
    var finding = await (beside ?? search());
    // The control fetch that ran beside the search. Rows with no door open
    // go to the backend only once it has passed (_reportOnline).
    final control = finding.control;
    // The fast path's failure, written down only now, and only on a phone
    // with internet ([PathFinding.internet]). Until 2.2.0 it was written at
    // once. On a phone without internet every dial fails, and the mark
    // forgot the door that works again once the internet is back: the next
    // try started without it, and three such marks in a day skipped it
    // until the next day (PathMemory.skippable). A run stopped or replaced
    // before this point forgot the door instead ([cancel]).
    if (_fastFailed?.run == run) _fastFailed = null;
    if (fastPathFailed && finding.internet && !_stale(run)) {
      await _memory.markFailed(network, first!.pathKey);
    }
    // The own rows. Later findings can hold the shared links' rows too.
    final ownRows = finding.checks;
    // An own door read "no answer" beside other checks gets a check alone
    // (_checkAlone). The checks alone have their own time on this tap, all
    // their rounds together: the finder's budget, or [offlineFor] when the
    // control fetch failed. Each round counts from its own start, so the
    // time the search beside them took is not counted. Until 2026-10-12
    // they had only what was left of the search's budget. In a test at one
    // tenth of real time that day, 12 own doors read "no answer" and one of
    // d3 to d6 was open alone. 1.7.0, one door at a time, connected through
    // it. Four at once checked only d0 to d2 alone and ended at "All routes
    // are blocked".
    final alone = <PathCheck>{};
    // Whether the search runs as on a phone with internet: the control
    // fetch passed, a door was open, or only the way abroad is cut
    // (PathFinding.cut). Then every door has its full search, but the rows
    // still go out, and the memory still learns, only on [finding.internet].
    bool searching(PathFinding f) => f.internet || f.cut;
    final aloneFor = searching(finding) ? _finder.budget : offlineFor;
    var aloneSpent = Duration.zero;
    // One round of checks alone over [rows], stopped at [by] when that
    // comes before the end of the time left.
    Future<PathFinding> checkAlone(
      PathFinding found,
      List<PathCheck> rows, {
      DateTime? by,
    }) async {
      final from = DateTime.now();
      final left = from.add(aloneFor - aloneSpent);
      final again = await _checkAlone(
        found,
        rows,
        alone,
        run,
        until: by != null && by.isBefore(left) ? by : left,
      );
      aloneSpent += DateTime.now().difference(from);
      return again;
    }

    // The first round, before the shared links and before any row is sent.
    // With shared links to follow, it stays within the time the own doors
    // have before them (FallbackSettings.after, or the finder's budget
    // without it), so they are checked no later than before. In the same
    // test, on a line where every own door was cut and a shared link
    // worked, the link connected after 18.3 seconds of real time, and after
    // 24.9 when this round had its full time. The rows it does not reach
    // get their check alone once the shared links found nothing open
    // (afterShared).
    //
    // Also when the control fetch failed: a door found open alone shows
    // the phone has internet (_checkAlone). Found 2026-10-12 in review: a
    // top door open alone that read "no answer" beside the other checks
    // ended the tap at "No internet" where door_parallel 1 connected
    // through it. A failed fetch does not prove the phone is offline: 19 of
    // 30 such first taps reached the backend within 2 minutes
    // (PathFinder.find). Only rows whose address took a TCP connection are
    // checked, so an offline phone, whose checks fail at TCP, checks none.
    if (doorChecks.parallel > 1 &&
        finding.open == null &&
        !finding.cancelled &&
        !_halted(run)) {
      finding = await checkAlone(
        finding,
        ownRows,
        by: shared == null
            ? null
            : searched.add(
                searching(finding) ? early ?? _finder.budget : offlineFor,
              ),
      );
    }
    // How the shared links went, once they have been checked on this tap.
    // They are checked at most once.
    (_Fallback, Server?)? fell;
    // [ownAfter] when the own doors get another turn after the shared
    // links: their stage reads pending meanwhile, not failed (clients #342).
    Future<(_Fallback, Server?)> fallBack({bool ownAfter = false}) async {
      final done = fell;
      if (done != null) return done;
      if (ownAfter) _again.add(RouteKind.own);
      return fell = await _fallBack(
        shared,
        picked ?? exclude,
        network,
        run,
        onShared,
        trace,
        control,
      );
    }

    // One more round of checks alone, once the shared links found nothing
    // open ([how]): the own rows that read "no answer" and were not checked
    // alone yet, within the time the checks alone have left. The shared
    // links are still checked once, at the same point of the tap as before
    // this round existed: [fallBack] keeps how they went. Found 2026-10-12
    // in review: with 8 own doors, all checked before FallbackSettings.after,
    // a dead top door that read "no answer" took the first round's only
    // check, and an open door below it that read "no answer" beside the
    // others was never checked alone. The tap ended at "All routes are
    // blocked" where door_parallel 1 connected through it in about 6
    // seconds. Not after a refused VPN permission, which no other door
    // needs asked again.
    //
    // [checksAgain] says whether that round runs after [found]. Asked
    // before the shared links too, for their stage on screen.
    bool checksAgain(PathFinding found) =>
        doorChecks.parallel > 1 &&
        !_permissionRefused &&
        found.open == null &&
        !found.cancelled &&
        !(alone.isNotEmpty && aloneSpent >= aloneFor) &&
        ownRows.any((c) => c.noAnswerAfterTcp && !alone.contains(c));
    Future<PathFinding> afterShared(PathFinding found, _Fallback how) async {
      if (!checksAgain(found)) return found;
      // Back to the own doors after the shared links.
      _enter(RouteKind.own);
      _set(ConnectStage.diagnosing);
      final before = alone.length;
      final again = await checkAlone(found, ownRows);
      if (found.internet) {
        // The rows are in the trace already, with the result they had
        // before the shared links. Each one checked again gets a step for
        // that check too.
        trace?.checks(
          alone.skip(before),
          TraceStage.checklist,
          stopAtOpen: true,
        );
      } else if (again.open != null) {
        // A tap whose fetch failed has put no rows in the trace. It has
        // internet after all, and its rows go in as they stand.
        trace?.checks(ownRows, TraceStage.checklist, stopAtOpen: true);
      }
      // A shared link whose tunnel failed leaves the service in error, which
      // would end the dial of the door found here before it starts. Kept
      // when no door was found, so the error names that link.
      if (again.open != null && how == _Fallback.failed) _vpn.clearError();
      return again;
    }

    // Whether the checklist's rows are in the trace already, and whether
    // the allowance was asked about.
    var traced = false;
    var asked = false;
    if (early != null &&
        searching(finding) &&
        finding.open == null &&
        !finding.cancelled &&
        !_halted(run)) {
      final own = finding.checks;
      final left = [
        for (final c in own)
          if (c.state == PathCheckState.pending) c,
      ];
      // The control fetch passed. With only the way abroad cut, nothing
      // below is asked of the backend, sent, or put in the trace: the
      // backend is out of reach, and every row is closed for that reason.
      final online = finding.internet;
      if (left.isNotEmpty) {
        // A search cut at the backend's time ([_cutSearch]) checks no more
        // own doors. The ones left get their step, and the rows checked so
        // far go out, as the rows of a search whose time ran out do.
        bool endedByCut() {
          if (!_cutHere(run)) return false;
          if (online) {
            trace?.skipped(left, TraceStage.checklist, TraceReason.budget);
          }
          _reportOnline(
            [
              for (final c in own)
                if (c.reportable) c,
            ],
            attemptId,
            control,
          );
          return true;
        }

        // The same question the search below asks when it finds nothing.
        asked = true;
        if (online && await _spent(allowanceSpent, run)) {
          trace?.checks(
            own,
            TraceStage.checklist,
            unreached: TraceReason.allowance,
            stopAtOpen: true,
          );
          return;
        }
        if (_stale(run)) return;
        // The rows checked so far. The ones not reached get their step
        // when they are checked below.
        if (online) {
          trace?.checks(own, TraceStage.checklist, stopAtOpen: true);
        }
        traced = true;
        // The own doors left come after the shared links.
        final (how, _) = await fallBack(ownAfter: true);
        if (how == _Fallback.ended) {
          // Connected through a shared link, or stopped. The own doors
          // checked so far are not reported: they are part of a search,
          // and the backend would read a few closed ones as an attempt
          // that found every door closed. The sweep reads all of them.
          if (!_stale(run) && _stage != ConnectStage.idle) {
            _sweepAfter(paths, network);
          }
          return;
        }
        // A stopped tap does nothing more, however the fallback ended. In
        // a test on 2026-10-12, a stop during the fallback's last write to
        // the memory sent the stopped tap back to its own doors, and its
        // stage stayed at "diagnosing" after it returned.
        if (_stale(run) || endedByCut()) return;
        if (_permissionRefused) {
          _finish(
            how == _Fallback.failed
                ? ConnectStage.failed
                : ConnectStage.nothingOpen,
            fell?.$2,
            run,
          );
          return;
        }
        // A shared link whose tunnel failed leaves the service in error,
        // which would end the next attempt before it starts.
        if (how == _Fallback.failed) _vpn.clearError();
        _enter(RouteKind.own);
        _set(ConnectStage.diagnosing);
        // The rest of the own doors, checked as the first ones were.
        var rest = doorChecks.parallel > 1
            ? await _finder.findInOrder(
                left,
                parallel: doorChecks.parallel,
                stagger: doorChecks.stagger,
                budget: _finder.budget - early,
              )
            : await _finder.findRest(
                left,
                parallel: 1,
                timeout: _finder.probeTimeout,
                budget: _finder.budget - early,
              );
        if (doorChecks.parallel > 1 &&
            rest.open == null &&
            !rest.cancelled &&
            !_halted(run)) {
          // Every own row not checked alone yet, the first search's too,
          // within the time the checks alone have left. Until 2026-10-12
          // this round ended when the rest of the own doors had used their
          // time, which the search above had nearly used up. In the test
          // above with FallbackSettings.after, 1.7.0 connected through an
          // open door at d1 to d6, and four at once only at d1 to d3.
          final before = alone.length;
          // The whole search's rows as they stand before this round. A stop
          // during it still sends them, as a stop during the last pass does:
          // every own door was checked and none was open. Taken first,
          // because checkAgain forgets the row it is checking.
          final whole = _probeResults(own);
          rest = await checkAlone(rest, own);
          if (_halted(run, rest.open)) {
            if (online) {
              unawaited(_report(whole, attemptId, network: _reportNetwork));
            }
            return;
          }
          // The first search's rows are in the trace already, with the
          // result they had before the shared links. Each one checked
          // again gets a step for that check too.
          if (online) {
            trace?.checks(
              [
                for (final c in alone.skip(before))
                  if (!left.contains(c)) c,
              ],
              TraceStage.checklist,
              stopAtOpen: true,
            );
          }
        }
        if (online || rest.open != null) {
          // A door found open says the phone has internet after all, and
          // the rows of a tap whose fetch failed go in as they stand.
          trace?.checks(
            online ? left : own,
            TraceStage.checklist,
            unreached: _unreached(rest, run),
            stopAtOpen: true,
          );
        }
        finding = PathFinding(
          checks: own,
          internet: online || rest.open != null,
          cut: !online && rest.open == null,
          open: rest.open,
          cancelled: rest.cancelled,
          control: control,
        );
      }
    }
    // Every door closed, on a phone with internet, is also what a spent
    // allowance looks like. Asked before the last pass and the report,
    // because the last pass would check doors the backend turned off, and
    // those rows would tell the backend that every door is blocked on
    // this carrier.
    final spent =
        !asked &&
        finding.internet &&
        finding.open == null &&
        !finding.cancelled &&
        !_halted(run) &&
        await _spent(allowanceSpent, run);
    // The checklist's rows as they stand now, before a last pass changes
    // them. A tap that ends at no internet names none, as before 1.7.1,
    // although its doors are now checked beside the control fetch.
    if (finding.internet && !traced) {
      trace?.checks(
        finding.checks,
        TraceStage.checklist,
        unreached: _unreached(finding, run, spent: spent),
        stopAtOpen: true,
      );
    }
    if (spent) return;
    // A search the user stopped or replaced reports nothing. Its rows cover
    // only the doors it reached, and the backend would read a few closed
    // ones as an attempt that found every door closed.
    if (_stale(run)) return;
    // The rows checked so far, in the order they ran. The last pass adds
    // its rows after them.
    final checked = [
      for (final c in finding.checks)
        if (c.reportable) c,
    ];
    // A search cut at the backend's time ([_cutSearch]) checks nothing
    // more. The rows it checked go out, as the rows of a search whose time
    // ran out do: its trace says the same. A door it found open is dialled
    // below.
    if (_cutHere(run) && finding.open == null) {
      _reportOnline(checked, attemptId, control);
      return;
    }
    final lastPass = settings?.lastPass;
    if (lastPass != null &&
        searching(finding) &&
        finding.open == null &&
        !finding.cancelled) {
      // With only the way abroad cut the last pass runs too, and puts
      // nothing in the trace: see the early fallback above.
      final online = finding.internet;
      final plan = await _lastPassRows(
        finding.checks,
        network,
        lastPass,
        failed: first,
      );
      final rest = plan.rows;
      // The doors the background sweep found open, which the last pass
      // puts first, in its order.
      for (final c in [...rest, ...plan.over]) {
        if (online && plan.hinted.contains(c.path.pathKey)) {
          trace?.add(c.path, TraceStage.sweepHint, TraceResult.ok);
        }
      }
      // Stopped or replaced during the last pass: the checklist's own rows
      // still go out. They are a whole search that found every door
      // closed, and the same rows a build without the last pass sent. The
      // backend's stuck rules count them. The last pass's rows stay out,
      // because they cover only the doors it reached.
      if (_halted(run)) {
        _reportOnline(checked, attemptId, control);
        return;
      }
      if (rest.isNotEmpty) {
        final found = await _finder.findRest(
          rest,
          parallel: lastPass.parallel,
          timeout: lastPass.timeout,
        );
        // findRest says nothing about the control fetch. A door found open
        // says the phone has internet; without one, what the search before
        // it found still holds.
        finding = PathFinding(
          checks: found.checks,
          internet: online || found.open != null,
          cut: finding.cut && found.open == null,
          open: found.open,
          cancelled: found.cancelled,
          control: control,
        );
        if (online || found.open != null) {
          trace?.checks(
            rest,
            TraceStage.lastPass,
            unreached: _stale(run)
                ? TraceReason.stopped
                : _cutHere(run) && found.open == null
                ? TraceReason.budget
                : null,
          );
        }
      }
      // The rows the last pass left out, when none it checked was open:
      // past the backend's number of doors, or dialled at an IPv6 address
      // on a network with none.
      if (finding.open == null && online) {
        trace
          ?..skipped(plan.over, TraceStage.lastPass, TraceReason.budget)
          ..skipped(plan.noIpv6, TraceStage.lastPass, TraceReason.noIpv6);
      }
      // A door the last pass found open is dialled after a cut too.
      if (_halted(run, finding.open)) {
        _reportOnline(checked, attemptId, control);
        return;
      }
      checked.addAll(rest.where((c) => c.reportable));
    }
    // With the control fetch passed, the rows go out now, before the shared
    // links are checked, as they did before. A row that afterShared checks
    // alone after them has gone out by then with the result it had beside
    // the other checks, the same row this tap sent before that round
    // existed. The rows are not held back for that round: when a shared
    // link then connected, they would be dated after its connect, and the
    // backend's stuck rules would count a connected phone as stuck.
    if (finding.internet) _reportOnline(checked, attemptId, control);
    // No door open and the control fetch failed: the phone may be offline.
    // Its rows teach nothing either. On an offline phone every check fails,
    // and Ipv6Reach would read its IPv6 rows ("tcp unreachable") as a
    // network with no IPv6.
    if (!finding.internet) {
      // A failed fetch does not prove the phone is offline. In the 24 hours
      // to 01:00 Tehran on 2026-10-12, 19 of 30 traces of first taps that
      // ended at no internet reached the backend within 2 minutes
      // (PathFinder.find). So the shared links get their check first, as
      // after an own door whose tunnel failed, and the tap ends at no
      // internet only when none is open. Their rows wait for the fetch in
      // _fallBack, so a phone that is offline sends none of them. Until
      // 2026-10-12 the tap ended here with no shared link checked, and no
      // later try helps a tap that ends at no internet (_retryLater).
      if (shared != null) {
        final (how, failedShared) = await fallBack(
          ownAfter: checksAgain(finding),
        );
        if (how == _Fallback.ended || _halted(run)) return;
        finding = await afterShared(finding, how);
        if (_halted(run, finding.open)) return;
        if (finding.open == null && how == _Fallback.failed) {
          // A shared link was open, so the phone has internet.
          _finish(ConnectStage.failed, failedShared, run);
          return;
        }
      }
      if (finding.open == null) {
        // Only the way abroad is cut, or the phone has no internet. Both
        // try again (_retryLater); the screen says which.
        _finish(
          finding.cut ? ConnectStage.cutOff : ConnectStage.noInternet,
          null,
          run,
        );
        return;
      }
      // An own door found open alone after the shared links. The rows wait
      // for the fetch, which failed, so they go out only now, at once, as
      // rows with a door open do.
      _reportOnline(checked, attemptId, control);
    }
    // What these checks found about IPv6 counts for the dial below too,
    // where the platform cannot tell.
    await _ipv6.learn(network, _readings(finding.checks));
    _standbyIpv6 = await _ipv6.usable(network);
    // A door found open is dialled after a cut too ([_cutSearch]).
    if (_halted(run, finding.open)) return;

    var open = finding.open;
    if (open == null) {
      if (finding.cancelled) {
        _finish(ConnectStage.cancelled, null, run);
        return;
      }
      final (how, failedShared) = await fallBack(
        ownAfter: checksAgain(finding),
      );
      if (how == _Fallback.ended || _halted(run)) return;
      finding = await afterShared(finding, how);
      if (_halted(run, finding.open)) return;
      open = finding.open;
      if (open == null) {
        _finish(
          how == _Fallback.failed
              ? ConnectStage.failed
              : ConnectStage.nothingOpen,
          failedShared,
          run,
        );
        return;
      }
    }

    // A door skipped for the day waits behind the shared links. Only the
    // last pass checks one, and only when no other door of this device was
    // open. Its tunnel failed on this network often enough today to be
    // skipped, so an open shared link goes first, as it did before the
    // last pass. When no shared link carries a tunnel, the skipped door is
    // dialled after all: its check passed just now, and one such door was
    // once the only one open on a phone on home wifi.
    final wasSkipped = skip.contains(open.pathKey);
    if (wasSkipped) {
      // After a cut ([_cutSearch]) no shared link is checked, and the
      // skipped door is dialled at once. Its dial is the own stage's turn
      // after the shared links.
      final (how, failedShared) = await fallBack(ownAfter: true);
      // A stopped tap does not dial the skipped door, and the selection
      // does not move to it.
      if (how == _Fallback.ended || _halted(run, open)) return;
      // The same reason the fallback gives for not asking again.
      if (_permissionRefused) {
        _finish(
          how == _Fallback.failed
              ? ConnectStage.failed
              : ConnectStage.nothingOpen,
          failedShared,
          run,
        );
        return;
      }
      // A shared link whose tunnel failed leaves the service in error,
      // which would end this attempt before it starts.
      if (how == _Fallback.failed) _vpn.clearError();
    }

    // The checklist names [open] while it connects (chosen), and the
    // selection moves only once the tunnel is up, as on the fast path.
    // Until 2026-10-12 it moved to [open] before the dial. In a test that
    // day, a tap on a picked server whose doors were closed checked another
    // server's door open, and the tunnel through it failed. The card then
    // named that server, and the pick was lost, because a move the flow
    // makes is not a pick (DedicatedState.select).
    _set(ConnectStage.connecting, open);
    if (await _attempt(open, run)) {
      final used = await _settle(open, network);
      if (_stale(run)) return;
      // [used] is [open], or the standby door the core moved to while
      // connecting. One call covers both.
      _follow(used, preferred);
      _finish(ConnectStage.done, used, run);
      _sweepAfter(paths, network);
      return;
    }
    if (_stale(run)) return;
    // Read before anything else dials: the next connect resets both.
    final starved = _vpn.failedAfterUp;
    final leftOn = _vpn.activeDoor;
    // The failure's diagnosis runs while the steps below do. Its verdict
    // decides the ending and whether [open] failed, at the end.
    final settled = _vpn.failureSettled();
    if (await _spent(allowanceSpent, run, afterDial: true)) return;
    if (_stale(run)) return;
    // Whether [open] has been marked failed yet.
    var marked = false;
    // The shared links were tried before it. After a cut the try ends at
    // the cut, as it does when the dial of any other door fails then.
    if (wasSkipped) {
      final verdict = await settled;
      if (!_offline(verdict)) await _memory.markFailed(network, open.pathKey);
      if (_halted(run)) return;
      _endAfterDial(verdict, open, run);
      return;
    }
    if (starved) {
      final next = await _anotherOwnDoor(
        finding,
        open,
        leftOn,
        skip,
        run,
        attemptId,
        control,
        trace,
        doorChecks,
      );
      if (_stale(run)) return;
      if (next != null) {
        // A door answered, so the phone has internet and [open] failed.
        await _memory.markFailed(network, open.pathKey);
        marked = true;
        if (_halted(run, next)) return;
        _set(ConnectStage.connecting, next);
        if (await _attempt(next, run)) {
          final used = await _settle(next, network);
          if (_stale(run)) return;
          _follow(used, preferred);
          _finish(ConnectStage.done, used, run);
          _sweepAfter(paths, network);
          return;
        }
        if (_stale(run)) return;
        if (await _spent(allowanceSpent, run, afterDial: true)) return;
        if (_stale(run)) return;
        await _memory.markFailed(network, next.pathKey);
        open = next;
      }
    }
    final (how, failedShared) = await fallBack();
    // A door answered, or the verdict says the phone was online: [open]
    // failed. Decided before a stop returns, as it was before the verdict
    // was waited for.
    final verdict = marked ? null : await settled;
    if (!marked && !_offline(verdict)) {
      await _memory.markFailed(network, open.pathKey);
    }
    if (how == _Fallback.ended || _halted(run)) return;
    if (how == _Fallback.failed) {
      _finish(ConnectStage.failed, failedShared ?? open, run);
      return;
    }
    _endAfterDial(verdict, open, run);
  }

  /// The fast path: dial [first], the door that last carried traffic on
  /// [network], with no checks. When it connects the tap ends there.
  ///
  /// With the backend's FastPathSettings.besideAfter, a dial not verified
  /// by then gets the checklist beside it: [search] starts while the dial
  /// goes on. Whichever finds a way first carries the tunnel. A door the
  /// search finds open while the dial still runs is dialled instead once
  /// the dial may be left ([_dialLeavable]): its tunnel has not come up, or
  /// a pass of the traffic check through it has failed. The remembered
  /// door is then left: its dial reads as given up on ([_leaveDial]), and
  /// it is not marked failed, but it is no longer the door to try first
  /// here (PathMemory.forget). A dial whose tunnel is up and passing its
  /// first traffic check is waited for, and the open door is dialled only
  /// if it fails. A dial that connects stops the search, and its rows go
  /// nowhere, as on a fast path that needed no checks.
  ///
  /// On Tehran day 2026-10-23, 113 remembered-door dials failed at about 21
  /// seconds each before the checklist started, and users stopped a tap
  /// after 10 to 15 seconds. A dead door's tunnel comes up too: of 148
  /// own-door dials of 2.1.3 that failed that day, 128 came up, at a median
  /// of 1.0 seconds, and failed only at the end of the traffic check, 2
  /// seconds to settle and up to 16 of passes. A working one usually passes
  /// on the first pass: of 1,823 own-door connects, 1,521 passed within 4.5
  /// seconds of coming up (VpnService.trafficMisses). So a dial in its
  /// first pass is not torn down for another door, and one whose pass has
  /// failed is.
  ///
  /// Only where a door check taken while a tunnel is coming up reads the
  /// carrier rather than the tunnel (DoorSweep.measuresRealNetwork), and
  /// never while the VPN permission dialog is on screen: its time does not
  /// count, as it does not for the dial's own wait ([_outcome]).
  ///
  /// Null when the run ended here: connected, stopped or replaced, or on a
  /// spent allowance. Otherwise `failed` says whether the dial failed by
  /// itself, and `search` is the search when it started beside the dial.
  Future<({bool failed, Future<PathFinding>? search})?> _fastPath(
    Server first,
    int run,
    String network,
    ChecklistSettings? settings, {
    required Future<PathFinding> Function() search,
    required List<Server> paths,
    Server? preferred,
    Future<bool> Function()? allowanceSpent,
  }) async {
    _set(ConnectStage.fastPath);
    _fastDial = (
      run: run,
      network: network,
      key: first.pathKey,
      started: DateTime.now(),
    );
    final dial = _attempt(first, run);
    final besideAfter = _checksBesideDial
        ? (settings?.fastPath ?? FastPathSettings.standard).besideAfter
        : null;
    Future<PathFinding>? beside;
    // Whether the dial was left for a door the search found open.
    var left = false;
    var ok = besideAfter == null
        ? await dial
        : await _dialWithin(dial, run, besideAfter);
    if (ok == null && !_halted(run)) {
      final searching = beside = search();
      final settled = await Future.any<Object>([dial, searching]);
      final found = settled is PathFinding ? settled.open : null;
      if (found != null && found.pathKey != first.pathKey && !_stale(run)) {
        left = await _leaveWhenLeavable(dial, run);
      }
    }
    ok ??= await dial;
    if (_fastDial?.run == run) _fastDial = null;
    if (ok) {
      // The search beside the dial, if any, stops here.
      if (beside != null) _finder.cancel();
      final used = await _settle(first, network);
      if (_stale(run)) return null;
      _follow(used, preferred);
      _finish(ConnectStage.done, used, run);
      _sweepAfter(paths, network);
      return null;
    }
    // A dial left for a door found open beside it is not marked failed. It
    // is forgotten as the door to try first on this network, with no
    // failure counted. Found in review on 2026-10-24: kept, it was dialled
    // first again on every later try and tap until some door carried
    // traffic, and the open door was dialled only after it was left again,
    // about 5 to 10 seconds later each time. A door that carries traffic is
    // remembered again then ([_settle]). Forgotten even when the run was
    // stopped just now: it was left before that.
    if (left) await _forgetFirst(network, first.pathKey);
    if (_stale(run)) return null;
    if (left) return (failed: false, search: beside);
    // The dial failed by itself. From here a stop or a pick forgets the
    // door ([cancel]), also while the allowance question below runs. Found
    // in review on 2026-10-24: set only after this question, which waits
    // up to 4 seconds, a stop during it kept the dead door first.
    _fastFailed = (run: run, network: network, key: first.pathKey);
    // Asked before the door is marked failed: a door the backend turned
    // off for this device is not a door that stopped working here. So it
    // is not forgotten either.
    if (await _spent(allowanceSpent, run, afterDial: true)) {
      if (_fastFailed?.run == run) _fastFailed = null;
      if (beside != null) _finder.cancel();
      return null;
    }
    if (_stale(run)) return null;
    return (failed: true, search: beside);
  }

  /// Whether a door check taken while a tunnel is up or coming up reads
  /// the carrier: on Android, where the app is left out of its own tunnel.
  bool get _checksBesideDial => _sweep.measuresRealNetwork(connected: true);

  /// [dial]'s result when it comes within [wait], or null once [wait] has
  /// passed without one. The time the VPN permission dialog is on screen
  /// does not count, and neither does any time after [run] went stale.
  Future<bool?> _dialWithin(Future<bool> dial, int run, Duration wait) {
    final result = Completer<bool?>();
    Timer? timer;
    void arm() {
      timer = Timer(wait, () {
        if (_vpn.awaitingPermission && !_stale(run)) return arm();
        if (!result.isCompleted) result.complete(null);
      });
    }

    arm();
    unawaited(
      dial.then(
        (ok) {
          timer?.cancel();
          if (!result.isCompleted) result.complete(ok);
        },
        onError: (Object e) {
          timer?.cancel();
          if (!result.isCompleted) result.complete(false);
        },
      ),
    );
    return result.future;
  }

  /// Whether the fast path's dial may be left for a door the checklist
  /// found open beside it ([_fastPath]): never while the VPN permission
  /// dialog is on screen, and only while the tunnel has not come up, or
  /// once a pass of the traffic check through it has failed.
  bool get _dialLeavable =>
      !_vpn.awaitingPermission &&
      (!(_vpn.isConnected || _vpn.isVerifying) || _vpn.trafficMisses > 0);

  /// Leave [dial] for a door found open beside it as soon as
  /// [_dialLeavable] holds, unless the dial ends first or [run] is stopped
  /// or replaced. Whether it was left.
  Future<bool> _leaveWhenLeavable(Future<bool> dial, int run) {
    final left = Completer<bool>();
    void check() {
      if (left.isCompleted || _stale(run) || !_dialLeavable) return;
      left.complete(_leaveDial());
    }

    void ended(Object? _) {
      if (!left.isCompleted) left.complete(false);
    }

    _vpn.addListener(check);
    unawaited(dial.then(ended, onError: ended));
    check();
    return left.future.whenComplete(() => _vpn.removeListener(check));
  }

  /// Stop waiting on the dial in flight, because the checklist found a
  /// door open beside it ([_fastPath]). The dial reads as given up on
  /// ([_attemptTimedOut]), and its tunnel comes down when the next dial
  /// starts (VpnService.connect). False when the dial had already ended.
  bool _leaveDial() {
    final pending = _pending;
    if (pending == null || pending.isCompleted) return false;
    _attemptTimedOut = true;
    pending.complete(false);
    return true;
  }

  /// Forget [key] as the door to try first on [network] (PathMemory.forget),
  /// with no failure counted, after any forget started before it. The next
  /// tap waits for it before it reads the memory ([_recall]).
  Future<void> _forgetFirst(String network, String key) {
    final before = _forgetting;
    Future<void> forget() async {
      try {
        if (before != null) await before;
        await _memory.forget(network, key);
      } catch (e) {
        debugPrint('ConnectFlow: could not forget the remembered door: $e');
      }
    }

    return _forgetting = forget();
  }

  /// The door to try first on [network] (PathMemory.recall), once the
  /// latest forget of one ([_forgetFirst]) has landed.
  Future<String?> _recall(String network) async {
    final forgetting = _forgetting;
    if (forgetting != null) await forgetting;
    return _memory.recall(network);
  }

  /// Check [picked], a shared link the user chose or one a tap fell back
  /// on before, on its own before it is dialled. [control] is the tap's
  /// control fetch, started before this.
  ///
  /// Until 2.2.0 the pick was dialled with no check. On Tehran day
  /// 2026-10-23, 165 such dials on 67 phones worked 28.5% of the time, and
  /// a dead one cost about 21 seconds: 2 to settle and a 16 second traffic
  /// check. A check of a closed link takes a few seconds at most.
  ///
  /// The row is a checklist step in [trace], and a community check when
  /// the pick is a community link, as in [_fallBack]. A pick found closed
  /// goes behind the other links in the next fallbacks on the network
  /// [network] names (PathMemory.markClosed). Like the fallback's rows,
  /// both wait for [control] to pass, and do not hold up the tap
  /// meanwhile, and neither does the read of [network]. The mark is not
  /// written once the tap is stopped or replaced: a later tap may have
  /// connected through the pick by then.
  ///
  /// Null when the run ended here: stopped, replaced, or cut with the pick
  /// closed ([_halted]). Otherwise whether the pick was found open.
  Future<bool?> _checkPick(
    Server picked,
    int run,
    Future<String> network,
    ConnectTrace? trace,
    Future<bool> control,
  ) async {
    _set(ConnectStage.diagnosing);
    final finding = await _finder.race([picked], parallel: 1, append: false);
    final rows = finding.checks;
    trace?.checks(
      rows,
      TraceStage.checklist,
      unreached: _unreached(finding, run),
    );
    final online = _online(rows, control);
    unawaited(() async {
      if (!await online) return;
      await _reportCommunity(rows);
      if (finding.open != null || _stale(run)) return;
      try {
        await _memory.markClosed(await network, [
          for (final c in rows)
            if (c.state == PathCheckState.blocked) c.path.pathKey,
        ]);
      } catch (e) {
        debugPrint('ConnectFlow: could not write down the closed pick: $e');
      }
    }());
    if (_halted(run, finding.open)) return null;
    return finding.open != null;
  }

  /// Whether [verdict], a failed dial's diagnosis, says the phone was
  /// offline or cut off from abroad when the dial failed, rather than the
  /// door failing. Never once our API has answered the phone on its own
  /// network during the tap ([_answeredThisTap]): the service reads that
  /// answer when the diagnosis ends (verdictFor), and this reads one that
  /// came after it.
  bool _offline(FailureVerdict? verdict) =>
      !_answeredThisTap &&
      (verdict == FailureVerdict.noInternet ||
          verdict == FailureVerdict.cutOff);

  /// Ends [run] after the dial of [open] failed and nothing after it
  /// connected: at no internet or a cut way abroad when the failure's
  /// diagnosis said so ([verdict]), else at failed.
  ///
  /// The trace still says the tap failed, as it did before, so the counts
  /// the backend keeps from it stay comparable across builds. The backend
  /// reads the diagnosis itself from the failure's event.
  ///
  /// Until 2026-10-20 such a tap always ended at failed: the line under
  /// the button said the path was open and the tunnel did not come up,
  /// while the bar above it said the phone had no internet. In the 24 hours
  /// to 10:15 Tehran that day, 28 of 44 taps whose tunnel came up and
  /// carried nothing had a diagnosis that found no internet at all.
  void _endAfterDial(FailureVerdict? verdict, Server open, int run) {
    final stage = switch (verdict) {
      _ when !_offline(verdict) => ConnectStage.failed,
      FailureVerdict.noInternet => ConnectStage.noInternet,
      FailureVerdict.cutOff => ConnectStage.cutOff,
      _ => ConnectStage.failed,
    };
    if (stage == ConnectStage.failed) {
      _finish(ConnectStage.failed, open, run);
      return;
    }
    _finish(stage, null, run, outcome: TraceOutcome.failed);
  }

  /// After the tunnel through [failed] came up and carried nothing, the own
  /// door to dial next in the same tap, or null.
  ///
  /// The rows the search had not reached, in the checklist's order, are
  /// checked until one is open; a row already found open is taken as it
  /// is. Left out: [failed] and [leftOn], the door the core was on when the
  /// check failed; the doors skipped for the day ([skip]), which wait
  /// behind the shared links; and IPv6 doors on a network without IPv6.
  /// The checks get the finder's own budget.
  ///
  /// Until 2026-10-20 the tap went straight to the shared links and then
  /// ended. In the 24 hours to 10:15 Tehran that day, 12 taps had a tunnel
  /// that came up on a phone with working internet and carried nothing; 6
  /// of those phones connected through another door within 2 minutes, on a
  /// later tap.
  ///
  /// Not after a fixed few seconds of silence: on the 3 days to that day,
  /// 699 of 6,732 tunnels that went on to carry traffic first carried it
  /// more than 6 seconds after they came up, and the core moves between
  /// the doors it holds by itself in that time.
  Future<Server?> _anotherOwnDoor(
    PathFinding finding,
    Server failed,
    Server? leftOn,
    Set<String> skip,
    int run,
    String attemptId,
    Future<bool> control,
    ConnectTrace? trace,
    DoorCheckSettings doorChecks,
  ) async {
    bool tried(PathCheck c) =>
        c.path.pathKey == failed.pathKey || c.path.pathKey == leftOn?.pathKey;
    final rows = [
      for (final c in finding.checks)
        if (!c.path.isCommunity &&
            !tried(c) &&
            !skip.contains(c.path.pathKey) &&
            (_standbyIpv6 || !StandbyDoors.dialsIpv6(c.path)) &&
            (c.state == PathCheckState.pending ||
                c.state == PathCheckState.open))
          c,
    ];
    if (rows.isEmpty) return null;
    if (rows.first.state == PathCheckState.open) return rows.first.path;
    final pending = [
      for (final c in rows)
        if (c.state == PathCheckState.pending) c,
    ];
    final found = await _finder.findRest(
      pending,
      parallel: doorChecks.parallel,
      timeout: _finder.probeTimeout,
      budget: _finder.budget,
    );
    if (_stale(run)) return null;
    final checked = [
      for (final c in pending)
        if (c.state != PathCheckState.pending && c.reportable) c,
    ];
    trace?.checks(checked, TraceStage.checklist, stopAtOpen: true);
    _reportOnline(checked, attemptId, control);
    // An open row the search had already found comes before the rows
    // checked here, in the checklist's order.
    final already = rows.where((c) => c.state == PathCheckState.open);
    return already.firstOrNull?.path ?? found.open;
  }

  /// Check again, one at a time and in the checklist's order, the rows of
  /// [own] that failed with the address open at TCP and no answer in time
  /// ([PathCheck.noAnswerAfterTcp]), until one is open. Rows in [done] were
  /// checked alone on this tap already and are left as they are. Each row
  /// checked here is added to it.
  ///
  /// The native check gives up after 3 seconds, and it cannot stop the
  /// core, which goes on moving data after that. With several checks at
  /// once (DoorCheckSettings) the top door shares a slow line with the
  /// checks started beside it, where in 1.7.0 it had the line to itself,
  /// and an open door can then read "tcp ok; no answer in 3000 ms". Read
  /// from production on 2026-10-12, by a rough estimate: of 246 open
  /// own-door checks of 1.7.0 diagnoses in 3 days, 18 took more than 1.8
  /// seconds alone and 9 more than 2.3 seconds. Of 1500 doors such a
  /// diagnosis found open in 7 days, the sweep, 12 checks at once, found
  /// 84% open of those that took 1 second or less alone and 67 to 70% of
  /// the slower ones, and nearly every check it missed said "no answer".
  /// Read closed, such a door can end the tap at "All routes are blocked"
  /// or on a shared link, where 1.7.0 dialled it.
  ///
  /// The tap's first such row is always checked: it is the door 1.7.0
  /// would most likely have dialled. Each one after it only until [until].
  /// A row found open here is the door the search takes, and every own row
  /// below it goes back to pending, as PathFinder leaves the rows below the
  /// door a search returns: one at a time, none of them would have been
  /// checked yet.
  ///
  /// Returns [finding] with the door found open, or as stopped when the
  /// tap was stopped or replaced. A door found open says the phone has
  /// internet, whatever the control fetch said, as in PathFinder.find: no
  /// phone without internet finds one open. Without that, a tap whose
  /// fetch failed went on to end at "No internet" with the door unused.
  Future<PathFinding> _checkAlone(
    PathFinding finding,
    List<PathCheck> own,
    Set<PathCheck> done,
    int run, {
    required DateTime until,
  }) async {
    PathCheck? open;
    var checked = false;
    for (final c in own) {
      if (!c.noAnswerAfterTcp || done.contains(c)) continue;
      if (_halted(run)) break;
      if (done.isNotEmpty && DateTime.now().isAfter(until)) break;
      done.add(c);
      checked = true;
      final again = await _finder.checkAgain(c);
      // A door found open is taken after a cut too ([_cutSearch]).
      if (again.cancelled || _halted(run, again.open)) break;
      if (again.open != null) {
        open = c;
        break;
      }
    }
    if (!checked) return finding;
    if (open != null) {
      for (final c in own.skip(own.indexOf(open) + 1)) {
        if (c.state == PathCheckState.blocked) c.forget();
      }
      notifyListeners();
    }
    return PathFinding(
      checks: finding.checks,
      internet: finding.internet || open != null,
      cut: finding.cut && open == null,
      open: open?.path,
      cancelled: finding.cancelled || _halted(run, open?.path),
      control: finding.control,
    );
  }

  /// The rows of [checks] a last pass checks, in the order to prefer them,
  /// at most [LastPassSettings.doors] of them (`rows`), with what the
  /// trace says about the plan: the rows ranked past that number (`over`),
  /// the IPv6 rows left out (`noIpv6`), and the doors that went first
  /// because the sweep found them open (`hinted`).
  ///
  /// Only rows the checklist did not check. First the ones its budget did
  /// not reach, then the ones it skipped for the day. A skipped door is
  /// one whose tunnel failed on this network again and again today, so it
  /// goes behind every door that has not, and [connect] tries the shared
  /// links before it dials one. Within each of the two, in order:
  ///
  /// 1. Doors the background sweep on [network] found open within
  ///    [LastPassSettings.sweptOpenFor].
  /// 2. One door at each address no row has dialled yet. A censor blocks
  ///    an address, and every door dialled at it fails with it, so each
  ///    address gets a check before any address gets a second one.
  /// 3. The other doors at an address that already has a row.
  /// 4. [failed], the remembered door whose tunnel failed on this tap.
  ///
  /// Within each group the rows keep the checklist's order: the server the
  /// user picked first, when they picked one, then the backend's order.
  ///
  /// Doors dialled at an IPv6 address are left out when this network has
  /// no IPv6 ([_standbyIpv6]). There they fail at once, almost always with
  /// "tcp unreachable". Each row is one more to upload from a line that
  /// delivers small uploads only. The checklist itself still checks them in
  /// its order.
  Future<_LastPassPlan> _lastPassRows(
    List<PathCheck> checks,
    String network,
    LastPassSettings settings, {
    Server? failed,
  }) async {
    bool notChecked(PathCheck c) =>
        c.state == PathCheckState.pending || c.state == PathCheckState.skipped;
    final noIpv6 = [
      for (final c in checks)
        if (notChecked(c) && !_standbyIpv6 && StandbyDoors.dialsIpv6(c.path)) c,
    ];
    List<PathCheck> left(PathCheckState state) => [
      for (final c in checks)
        if (c.state == state && !noIpv6.contains(c)) c,
    ];
    final unreached = left(PathCheckState.pending);
    final skipped = left(PathCheckState.skipped);
    if (unreached.isEmpty && skipped.isEmpty) {
      return (
        rows: const <PathCheck>[],
        over: const <PathCheck>[],
        noIpv6: noIpv6,
        hinted: const <String>{},
      );
    }
    final within = settings.sweptOpenFor;
    final swept = within == null
        ? const <String>{}
        : await _memory.sweptOpen(network, within);
    final covered = {
      for (final c in checks)
        if (c.reportable) _addressOf(c.path),
    };
    // The doors ranked first because the sweep found them open.
    final hinted = <String>{};
    // Ranked in the checklist's order, so the first door at an address is
    // the one that counts as its check. The unreached rows are ranked
    // first, because they are checked first.
    List<PathCheck> ranked(List<PathCheck> rows) {
      covered.addAll([
        for (final c in rows)
          if (swept.contains(c.path.pathKey)) _addressOf(c.path),
      ]);
      int rank(PathCheck c) {
        if (failed != null && c.path.pathKey == failed.pathKey) return 3;
        if (swept.contains(c.path.pathKey)) return 0;
        return covered.add(_addressOf(c.path)) ? 1 : 2;
      }

      final ranks = {for (final c in rows) c: rank(c)};
      hinted.addAll([
        for (final c in rows)
          if (ranks[c] == 0) c.path.pathKey,
      ]);
      return [
        for (final r in const [0, 1, 2, 3]) ...rows.where((c) => ranks[c] == r),
      ];
    }

    final all = [...ranked(unreached), ...ranked(skipped)];
    return (
      rows: all.take(settings.doors).toList(),
      over: all.skip(settings.doors).toList(),
      noIpv6: noIpv6,
      hinted: hinted,
    );
  }

  /// Why the rows a search of [run] did not reach were not reached, for the
  /// trace, or null when they need no step because it found a door open.
  /// [spent] when the allowance ended the tap right after the search. A
  /// search that was cut ([_cutSearch]) ran out of the tap's time.
  TraceReason? _unreached(PathFinding finding, int run, {bool spent = false}) {
    if (finding.open != null) return null;
    if (finding.cancelled) {
      return _cutHere(run) ? TraceReason.budget : TraceReason.stopped;
    }
    return spent ? TraceReason.allowance : TraceReason.budget;
  }

  /// What a censor blocks [door] by: the address it dials, or for a door
  /// behind Cloudflare, whose address every such door shares, the name it
  /// asks for.
  static String _addressOf(Server door) {
    final uri = door.connectionUri;
    final name = VlessLink.security(uri) == 'tls'
        ? VlessLink.sni(uri) ?? VlessLink.param(uri, 'host')
        : null;
    return name ?? VlessLinkHost.of(door);
  }

  /// The check before a tap dials [picked], a shared link the fallback
  /// chose on an earlier tap: [count] of the device's own doors, the one
  /// that last carried traffic on this network first, and [picked], all
  /// at once. An own door found open is dialled, and the tap ends there
  /// when its tunnel comes up.
  ///
  /// Without it the next tap dials [picked] first, as a link the user
  /// picked is, and a phone stays on a community link while it works,
  /// however long ago our own doors came back. The own door goes first in
  /// the check's order, so it wins when both are open.
  ///
  /// Null when the run ended here: connected, or stopped. Otherwise
  /// whether [picked] was found open. The own doors found closed, or whose
  /// tunnel failed, are added to [closed], which the fast path does not
  /// dial. The ones the diagnosis checks after the other own doors are
  /// added to [demoted]: see below for which.
  Future<bool?> _ownFirst(
    List<Server> paths,
    Server? preferred,
    Server picked,
    int run,
    int count,
    String attemptId,
    ConnectTrace? trace,
    Set<String> closed,
    Set<String> demoted,
  ) async {
    final network = await _networkKey();
    _reportNetwork = network;
    if (_halted(run)) return null;
    final ordered = _ordered(paths, preferred);
    final remembered = await _recall(network);
    if (_halted(run)) return null;
    final own = [
      ...ordered.where((p) => p.pathKey == remembered),
      ...ordered.where((p) => p.pathKey != remembered),
    ].take(count).toList();
    if (own.isEmpty) return true;
    // The own doors go first in this check, so it is their stage.
    _enter(RouteKind.own);
    _set(ConnectStage.diagnosing);
    // A control fetch beside these checks, as in the diagnosis
    // (PathFinder.find). Rows with nothing open wait for it. Until
    // 2026-10-12 this check ran no fetch and sent its rows at once. On a
    // phone with no internet every row failed, and the rows reached the
    // backend once the phone was back online. The backend reads an attempt
    // whose rows are all closed as one that found every door closed, and
    // the stuck rules count it.
    final control = _finder.controlFetch();
    final finding = await _finder.race(
      [...own, picked],
      parallel: own.length + 1,
      append: false,
    );
    final rows = finding.checks;
    trace?.checks(
      rows,
      TraceStage.checklist,
      unreached: _unreached(finding, run),
    );
    // Each row is a whole check, so the own ones are door checks like any
    // other, and the pick, when it is a community link, a community check.
    // The own rows and the pick's row come from one check, so when any of
    // them is open, all of them go at once.
    final online = _online(rows, control);
    _reportOnline(
      [
        for (final c in rows)
          if (c.path.isDedicated) c,
      ],
      attemptId,
      online,
    );
    unawaited(() async {
      if (await online) await _reportCommunity(rows);
    }());
    closed.addAll([
      for (final c in rows)
        if (c.path.isDedicated && c.state == PathCheckState.blocked)
          c.path.pathKey,
    ]);
    // A row that read "tcp ok; no answer" keeps its place in the diagnosis.
    // It shared the line with the pick's check, and an open door can read
    // that way then (_checkAlone). Found 2026-10-12 in review: moved to the
    // back, the door that last worked here was past the search's budget.
    // In a test with every other own door cut, the tap ended at "All routes
    // are blocked" with door_parallel 4 and with door_parallel 1, where
    // 1.7.0 checked that door alone at its place and connected.
    demoted.addAll([
      for (final c in rows)
        if (c.path.isDedicated &&
            c.state == PathCheckState.blocked &&
            !c.noAnswerAfterTcp)
          c.path.pathKey,
    ]);
    // After a cut ([_cutSearch]) a door or the pick found open is still
    // dialled: the pick by the caller.
    if (_halted(run, finding.open)) return null;
    final pickedOpen = rows.last.state == PathCheckState.open;
    final open = finding.open;
    if (open == null || !open.isDedicated) return pickedOpen;

    _standbyPool = ordered;
    _poolPreferred = preferred;
    _standbyIpv6 = await _ipv6.usable(network);
    if (_halted(run, open)) return null;
    _set(ConnectStage.connecting, open);
    if (await _attempt(open, run)) {
      final used = await _settle(open, network);
      if (_stale(run)) return null;
      _follow(used, preferred);
      _finish(ConnectStage.done, used, run);
      _sweepAfter(paths, network);
      return null;
    }
    if (_stale(run)) return null;
    // Left on screen, the failure would end the dial of the pick before it
    // starts.
    _vpn.clearError();
    await _memory.markFailed(network, open.pathKey);
    // A stop while the failure was written. The caller would otherwise set
    // the stage of a tap the user stopped, and it stayed busy, so the next
    // tap on the button only stopped it. Found 2026-10-12 in review; 1.7.0
    // had the same gap. After a cut, only a pick found open is dialled.
    if (_halted(run, pickedOpen ? picked : null)) return null;
    closed.add(open.pathKey);
    demoted.add(open.pathKey);
    return pickedOpen;
  }

  /// At most this many shared links are checked in one fallback, when the
  /// backend sends no [FallbackSettings]. The finder's budget usually ends
  /// the search sooner.
  static const sharedFallbackLimit = 6;

  /// The last resort, when none of this device's own doors carried a
  /// tunnel: the same checklist carries on through [shared] links, and the
  /// tunnel comes up through the first one open.
  ///
  /// With the backend's [FallbackSettings], up to
  /// [FallbackSettings.links] of them are checked,
  /// [FallbackSettings.parallel] at a time ([PathFinder.race]). Without
  /// them, at most [sharedFallbackLimit] are checked one at a time within
  /// the finder's budget, as before.
  ///
  /// [_Fallback.ended] when the run ended here, connected or stopped by
  /// the user. [_Fallback.nothingOpen] when no shared link was open, and
  /// the caller says so as before. [_Fallback.failed] when one was open
  /// and its tunnel failed; the caller ends the run on that link, so the
  /// status, the last checklist row and the error bar all name it.
  ///
  /// After a cut ([_cutSearch]) no link is asked for or checked, and this
  /// says none was open: the caller dials a door it has found open, or
  /// the try ends at the cut. A link found open before the cut, or in a
  /// check that ran to its end after it, is still dialled.
  ///
  /// Not run once the user refused the VPN permission on this tap, or
  /// another app holds it: a shared link needs the same permission, and
  /// asking again right after a "no" is the opposite of what they chose.
  ///
  /// These rows are not reported as door checks. The scoreboard is about
  /// this device's own doors, and a shared link says nothing about them.
  /// The community links among them are reported as community checks
  /// instead ([CommunityChecks]): a phone in Iran that checked them is the
  /// best reading there is of which ones work on its carrier.
  ///
  /// A community link the tunnel then comes up through is dialled as
  /// [LinkSource.communityFallback], so its events say the user did not
  /// pick it.
  ///
  /// The rows go into [trace], the tap's trace, as checklist steps: they
  /// are the same checklist carrying on.
  ///
  /// [control] is the tap's control fetch: the one beside its own search,
  /// or the one [connectShared] started before its dial. The community
  /// rows go out, and the links found closed are written to the memory,
  /// only once it has passed, or at once when a link was found open
  /// ([_online]).
  Future<(_Fallback, Server?)> _fallBack(
    Future<List<Server>> Function()? shared,
    Server? picked,
    String network,
    int run,
    void Function(Server server)? onShared,
    ConnectTrace? trace,
    Future<bool> control,
  ) async {
    if (_permissionRefused) return (_Fallback.nothingOpen, null);
    // A cut search asks for no links ([_cutSearch]): [shared] can wait on
    // a fetch.
    if (_cutHere(run)) return (_Fallback.nothingOpen, null);
    // Read before the shared rows are added below them.
    final closedHere = _closedOwnEndpoints();
    final links = await _sharedLinks(shared);
    if (_stale(run)) return (_Fallback.ended, null);
    if (_cutHere(run)) return (_Fallback.nothingOpen, null);
    final settings = _checklist();
    final skip = await _memory.skippable(network, rule: settings?.skip);
    final fallback = settings?.fallback;
    final candidates = await _sharedCandidates(
      links,
      picked,
      network,
      skip,
      closedHere,
      limit: fallback?.links ?? sharedFallbackLimit,
      closedFor: fallback?.closedFor,
    );
    if (_stale(run)) return (_Fallback.ended, null);
    if (_cutHere(run) || candidates.isEmpty) {
      return (_Fallback.nothingOpen, null);
    }
    // The second stage of the search: the shared links (clients #342).
    _enter(RouteKind.community);

    _set(ConnectStage.diagnosing);
    // The race returns as soon as the first open link in order is known,
    // without waiting for the checks still running below it: on Tehran day
    // 2026-10-23 that wait cost about 3.1 seconds a race. Their rows go
    // back to pending, so they are the spares the core may move to, and
    // they are not reported.
    final finding = fallback == null
        ? await _finder.find(candidates, append: true, online: true)
        : await _finder.race(
            candidates,
            parallel: fallback.parallel,
            returnAtFirst: true,
          );
    // The ones found closed go to the back of the next fallback on this
    // network, so the next tap checks others first. Not reported as door
    // checks: see above.
    final rows = finding.checks
        .skip(finding.checks.length - candidates.length)
        .toList();
    // Checked several at a time, the rows after the open one can have
    // results of their own, and they are steps too.
    trace?.checks(
      rows,
      TraceStage.checklist,
      unreached: _unreached(finding, run),
      stopAtOpen: fallback == null,
    );
    // Not when this tap's control fetch failed, for the reason in
    // _reportOnline. Sent even when the user has stopped the tap: every row
    // with a result is a check that ran to its end.
    final online = _online(rows, control);
    unawaited(() async {
      if (await online) await _reportCommunity(rows);
    }());
    // Not from a tap whose fetch failed either. On an offline phone every
    // link fails its check, and markClosed would put every link checked at
    // the back for the day on this network, and forget the one that last
    // worked here. With a link found open this does not wait for the
    // fetch, so the dial below does not either. With none, the fetch has
    // nearly always answered by now: it gives up within about 10 seconds
    // (ConnectDiagnostics.controlCheck), and it started before the own
    // doors' checks, or before connectShared's dial.
    if (await online) {
      await _memory.markClosed(network, [
        for (final c in rows)
          if (c.state == PathCheckState.blocked) c.path.pathKey,
      ]);
    }
    if (_stale(run)) return (_Fallback.ended, null);
    final open = finding.open;
    // The own door's failure stays on screen until a shared link is open:
    // when none is, it is still the explanation the user needs. After a
    // cut too, the link found open is dialled.
    if (open == null) return (_Fallback.nothingOpen, null);

    // The allowance can be found spent while the links were checked. The
    // shared links are unmetered, so none is dialled then.
    if (_spentNow(_blocked)) return (_Fallback.ended, null);

    // A failed tunnel through an own door leaves the service in error,
    // which would end the next attempt before it starts, and would tell
    // the user to try another server while the app is doing just that.
    _vpn.clearError();
    _set(ConnectStage.connecting, open);
    final source = open.isCommunity ? LinkSource.communityFallback : null;
    // The other links this fallback found open, then the ones it did not
    // reach, in its order, for the core to move to when the open one dies.
    final spares = StandbyDoors.shared(open, [
      for (final c in rows)
        if (c.state == PathCheckState.open) c.path,
      for (final c in rows)
        if (c.state == PathCheckState.pending) c.path,
    ], count: fallback?.standby);
    if (await _attempt(open, run, source: source, standby: spares)) {
      onShared?.call(open);
      // Followed like an own door: a move the core makes to a spare
      // later in the session moves the selection with it (_followCore).
      _onDoor = open;
      _finish(ConnectStage.done, open, run);
      await _memory.rememberShared(network, open.pathKey);
      return (_Fallback.ended, null);
    }
    if (_stale(run)) return (_Fallback.ended, null);
    await _memory.markFailed(network, open.pathKey);
    // A stop while the failure was written. The caller would otherwise
    // carry on with a tap the user stopped. After a cut the caller ends
    // the try at the cut.
    if (_stale(run)) return (_Fallback.ended, null);
    return (_Fallback.failed, open);
  }

  /// Sends what the fallback found about the community links among [rows].
  /// Our own shared links are left out: the report is about links from
  /// public channels.
  Future<void> _reportCommunity(List<PathCheck> rows) async {
    final reporter = _communityChecks;
    if (reporter == null) return;
    final at = DateTime.now();
    final checks = [
      for (final c in rows)
        if (c.reportable && c.path.isCommunity)
          CommunityCheck(
            link: c.path.connectionUri,
            kind: CommunityCheckKind.fallback,
            ok: c.state == PathCheckState.open,
            at: at,
            ms: c.ms,
            error: c.error,
          ),
    ];
    if (checks.isEmpty) return;
    try {
      await reporter.report(checks, carrier: await _carrier());
    } catch (e) {
      debugPrint('ConnectFlow: could not report community checks: $e');
    }
  }

  /// The shared links [shared] gives, or none when it fails.
  Future<List<Server>> _sharedLinks(
    Future<List<Server>> Function()? shared,
  ) async {
    if (shared == null) return const [];
    try {
      return await shared();
    } catch (e) {
      debugPrint('ConnectFlow: could not get the shared links: $e');
      return const [];
    }
  }

  /// Where this tap found a door of the device's own closed: the server
  /// name or address each one reaches ([VlessLink.endpoint]).
  Set<String> _closedOwnEndpoints() => {
    for (final c in _finder.checks)
      if (c.path.isDedicated && c.state == PathCheckState.blocked)
        VlessLink.endpoint(c.path.connectionUri),
  };

  /// The shared links a fallback checks, in order: the one that last
  /// carried traffic on [network], then [shared] as given, then the ones
  /// that reach a name or address in [closedHere], then the ones found
  /// closed or failed on [network] today, or in the [closedFor] before now
  /// when the backend sets it ([FallbackSettings.closedFor]). Never
  /// [picked], which already failed on this tap, never one skipped for the
  /// day, never one the core cannot dial ([SharedLink]), and each link
  /// once. At most [limit] of them.
  ///
  /// A phone on home wifi had 156 public links saved and every tap checked
  /// the same few at the top. Our own two shared links went first, and they
  /// reach our servers under the same Cloudflare names as the device's own
  /// doors that the carrier was filtering.
  Future<List<Server>> _sharedCandidates(
    List<Server> shared,
    Server? picked,
    String network,
    Set<String> skip,
    Set<String> closedHere, {
    required int limit,
    Duration? closedFor,
  }) async {
    final seen = <String>{if (picked != null) picked.pathKey, ...skip};
    final usable = [
      for (final s in shared)
        if (!s.isDedicated &&
            SharedLink.usable(s.connectionUri) &&
            seen.add(s.pathKey))
          s,
    ];
    final remembered = await _memory.recallShared(network);
    final failed = await _memory.failedToday(network, within: closedFor);
    final first = usable.where((s) => s.pathKey == remembered).firstOrNull;
    int rank(Server s) {
      if (failed.contains(s.pathKey)) return 2;
      if (closedHere.contains(VlessLink.endpoint(s.connectionUri))) return 1;
      return 0;
    }

    final rest = usable.where((s) => s != first).toList();
    return [
      ?first,
      for (final r in const [0, 1, 2]) ...rest.where((s) => rank(s) == r),
    ].take(limit).toList();
  }

  /// Remember that the shared link [picked] carried traffic, so a later
  /// fallback on this network tries it first.
  Future<void> _rememberShared(Server picked) async {
    try {
      await _memory.rememberShared(await _networkKey(), picked.pathKey);
    } catch (e) {
      debugPrint('ConnectFlow: could not remember the shared link: $e');
    }
  }

  /// How long the allowance question may take. It goes to the backend,
  /// and a phone that cannot reach the backend must not wait on it before
  /// trying its other doors.
  static const _spentTimeout = Duration(seconds: 4);

  /// How long a try after a wait waits for the traces of the taps before
  /// it to go (ConnectTraces.sendWaiting). The allowance question's wait,
  /// for the same reason: they go to the backend too. Of the trace uploads
  /// that went through in the 24 h to the evening of 2026-10-23, 4,405 of
  /// 4,553 took 4 s or less, and the median took 438 ms.
  static const _tracesFirstTimeout = _spentTimeout;

  /// Whether the allowance is spent, by [allowanceSpent], and end the run
  /// when the answer is yes.
  ///
  /// True when the run ended here. No answer in time, or an error, counts
  /// as no: the flow carries on as it did before it could ask.
  ///
  /// Asked once in a try: the first check asks, and the later ones read
  /// that answer ([_allowance]), waiting only for what is left of
  /// [_spentTimeout] since it was asked. Until 2.2.0 each check asked anew
  /// and waited up to [_spentTimeout] each time, on the lines where the
  /// backend is slowest to reach. A question that ended in an error is
  /// asked again at the next check.
  ///
  /// Never before something has failed in the try: a tunnel, or the
  /// checklist finding no door open. The question is the device's config
  /// request with via_tunnel false (DedicatedState.refresh), and the
  /// backend reads every such request as one the app makes after a failed
  /// try. Asked when a tap starts, it would make a tap the user stopped, or
  /// one that ended at no internet, read as a failed one.
  ///
  /// [afterDial] when it is asked because a tunnel attempt just failed.
  /// When the answer is yes, the trace says that attempt failed because of
  /// the allowance.
  Future<bool> _spent(
    Future<bool> Function()? allowanceSpent,
    int run, {
    bool afterDial = false,
  }) async {
    if (allowanceSpent == null) return false;
    final spent = await _spentAnswer(allowanceSpent, run);
    if (!spent || _stale(run)) return false;
    // The failure on screen says to try another server, and no other
    // server will work until the allowance refills.
    if (afterDial) _trace?.dialEndedBy(TraceReason.allowance);
    _endOnAllowance();
    return true;
  }

  /// The answer for [_spent]: [run]'s question ([_allowance]), asked now
  /// when [run] has not asked it yet, or when it ended in an error. Waited
  /// for only for what is left of [_spentTimeout] since it was asked. No
  /// answer in time, or an error, is no.
  Future<bool> _spentAnswer(
    Future<bool> Function() allowanceSpent,
    int run,
  ) async {
    var asked = _allowance;
    if (asked == null || asked.run != run || asked.failed) {
      asked = _allowance = _AllowanceQuestion(run, allowanceSpent);
    }
    final known = asked.value;
    if (known != null) return known;
    final left = _spentTimeout - DateTime.now().difference(asked.at);
    if (left <= Duration.zero) return false;
    return await asked.answer.timeout(left, onTimeout: () => null) ?? false;
  }

  /// Check the doors nobody needed, now that the user is connected.
  ///
  /// The fast path is the common case and it reports one success and
  /// nothing else, so the doors below the working one are never measured.
  /// That is why production held 216 readings for the door everyone uses
  /// and single digits for the two we most wanted to learn about.
  ///
  /// Not awaited and never blocking: the user is already connected and
  /// this must not delay anything they can see. The sweep decides for
  /// itself whether it is due, so calling it on every connect is cheap.
  void _sweepAfter(List<Server> paths, String network) {
    unawaited(() async {
      try {
        // Read the carrier here rather than letting the reporter resolve
        // it from the source address: the tunnel is up, so that address is
        // ours and would attribute the whole sweep to the wrong network.
        final carrier = await _carrier();
        final results = await _sweep.run(
          paths,
          network: network,
          connected: true,
          carrier: carrier,
        );
        // The doors found open go first in a last pass on this network.
        // The results are in the order of the doors the sweep took.
        if (results.isNotEmpty) {
          final swept = paths.take(DoorSweep.maxDoors).toList();
          await _memory.markSwept(network, [
            for (final (i, r) in results.indexed)
              if (r.ok && i < swept.length) swept[i].pathKey,
          ]);
        }
        await _ipv6.learn(network, [
          for (final r in results)
            (host: r.serverHost ?? '', ok: r.ok, error: r.error),
        ]);
        // After the sweep, never beside it: its checks run side by side,
        // and a pair's two checks must each run alone (DoorPairRunner).
        // Only where a check taken now reads the carrier, not the tunnel.
        final pair = _doorPair();
        if (pair != null && _sweep.measuresRealNetwork(connected: true)) {
          await _pairs.run(pair, paths, network: network, carrier: carrier);
        }
      } catch (e) {
        debugPrint('ConnectFlow: sweep failed: $e');
      }
    }());
  }

  /// The checks of a diagnosis that ran, as [Ipv6Reach] reads them.
  static List<DoorReading> _readings(List<PathCheck> checks) => [
    for (final c in checks)
      if (c.reportable)
        (
          host: VlessLinkHost.of(c.path),
          ok: c.state == PathCheckState.open,
          error: c.error,
        ),
  ];

  /// The server the user picked first, in the backend's door order, then
  /// the rest. With no pick, the backend's order as it is (see dialServer).
  static List<Server> _ordered(List<Server> paths, Server? preferred) {
    if (preferred == null) return List.of(paths);
    return [
      ...paths.where((p) => _sameServer(p, preferred)),
      ...paths.where((p) => !_sameServer(p, preferred)),
    ];
  }

  /// Tells [_onSwitchedServer] that the tunnel is on [door], when [door]
  /// belongs to another server than the selection names now ([_selection],
  /// or [preferred] without it). Nothing without either: there is no
  /// selection to follow.
  void _follow(Server door, Server? preferred) {
    final named = _selection?.call() ?? preferred;
    if (named != null && !_sameServer(door, named)) {
      _onSwitchedServer?.call(door);
    }
  }

  static bool _sameServer(Server a, Server b) => a.sameServerAs(b);

  bool _stale(int run) => _cancelled || run != _run;

  void _set(ConnectStage stage, [Server? chosen]) {
    _stage = stage;
    if (stage == ConnectStage.diagnosing) _diagnosedRun = _run;
    if (chosen != null) _chosen = chosen;
    // A tunnel coming up through [chosen] is a try of its kind of route.
    if (chosen != null && stage == ConnectStage.connecting) {
      _enter(RouteKind.of(chosen));
    }
    notifyListeners();
  }

  /// Set [stage] as the end of [run], unless [run] was stopped or replaced.
  /// Then [cancel] has already set the stage, or a newer run owns it.
  /// [outcome] is what the trace says, when [stage] alone does not say it.
  void _finish(
    ConnectStage stage,
    Server? chosen,
    int run, {
    TraceOutcome? outcome,
  }) {
    if (_stale(run)) return;
    _endedRun = run;
    switch (stage) {
      case ConnectStage.noInternet || ConnectStage.cutOff:
        _noWayAbroad = true;
      case ConnectStage.done || ConnectStage.nothingOpen || ConnectStage.failed:
        // A tunnel came up, or a door or link answered or was open: the
        // phone reaches abroad.
        _noWayAbroad = false;
      default:
        break;
    }
    if (stage == ConnectStage.done && chosen != null) {
      _connectedOn = RouteKind.of(chosen);
    }
    _set(stage, chosen);
    _trace?.end(outcome ?? _outcomeOf(stage), chosen: chosen);
  }

  /// How a tap that ended on [stage] ended, as the trace says it. A tap
  /// that ended after the VPN permission was refused ended on that,
  /// unless it connected.
  TraceOutcome _outcomeOf(ConnectStage stage) => switch (stage) {
    ConnectStage.done => TraceOutcome.connected,
    ConnectStage.noInternet => TraceOutcome.noInternet,
    ConnectStage.cutOff => TraceOutcome.cutOff,
    ConnectStage.cancelled => TraceOutcome.stopped,
    _ when _permissionRefused => TraceOutcome.permission,
    ConnectStage.failed => TraceOutcome.failed,
    _ => TraceOutcome.allClosed,
  };

  /// Records what a verified tunnel taught, and returns the door it is on.
  ///
  /// That is [dialled], unless the core held standby doors and left it.
  /// Then the door in use is the one to remember for this network, and the
  /// dialled one failed like any other door that did, unless the core only
  /// left it for a faster one.
  Future<Server> _settle(Server dialled, String network) async {
    final used = _vpn.activeDoor ?? dialled;
    if (used.pathKey != dialled.pathKey && _leftForFailure) {
      await _memory.markFailed(network, dialled.pathKey);
    }
    await _memory.remember(network, used.pathKey, holding: _held);
    _onDoor = used;
    return used;
  }

  /// Every door of the last connect, for [PathMemory.remember]. Null
  /// before the first one has its doors.
  Iterable<String>? get _held =>
      _standbyPool.isEmpty ? null : [for (final p in _standbyPool) p.pathKey];

  /// Follows the core onto another door after the tunnel is up.
  ///
  /// With standby doors the core leaves a door that stops answering in the
  /// middle of a session. [_settle] handles a move made while connecting;
  /// this handles the ones after it, the same way. The door it left failed
  /// on this network unless the core left it for a faster one, the new one
  /// is the one to try first next time, and
  /// when the new one belongs to another server the selection follows, so
  /// the home screen names the server that carries the traffic.
  void _followCore() {
    if (_stage != ConnectStage.done || !_vpn.isConnected) return;
    final from = _onDoor;
    final to = _vpn.activeDoor;
    if (from == null || to == null || to.pathKey == from.pathKey) return;
    _onDoor = to;
    _chosen = to;
    if (to.door == null) {
      // A spare of a shared link the fallback dialled. Remembered as the
      // shared link that last worked here, never as an own door.
      unawaited(_rememberSharedSwitch(from, to, failed: _leftForFailure));
      _onShared?.call(to);
      notifyListeners();
      return;
    }
    unawaited(_rememberSwitch(from, to, failed: _leftForFailure));
    if (!_sameServer(from, to)) _onSwitchedServer?.call(to);
    notifyListeners();
  }

  /// Whether the core left the previous door because it failed.
  ///
  /// A door left for a faster one still works, and marking it failed would
  /// count it towards being skipped for the day. On 2026-10-02 phones moved
  /// between two working doors every few minutes. Without a reason from the
  /// core, the move counts as a failure, as it did before the core gave one.
  bool get _leftForFailure => _vpn.switchReason != 'faster';

  Future<void> _rememberSharedSwitch(
    Server from,
    Server to, {
    required bool failed,
  }) async {
    try {
      final network = await _networkKey();
      if (failed) await _memory.markFailed(network, from.pathKey);
      await _memory.rememberShared(network, to.pathKey);
    } catch (e) {
      debugPrint('ConnectFlow: could not record the switch: $e');
    }
  }

  /// The tunnel through [door] stopped carrying data ([VpnService.stalled]).
  /// It is no longer the door to try first on this network, and counts one
  /// failure there, the same as a door the core left because it failed.
  /// Without this the search that follows dials that door first again.
  ///
  /// Not the backup network, which the memory never holds.
  Future<void> forgetStalledDoor(Server door) =>
      forgetStalledDoorKey(door.pathKey);

  /// [forgetStalledDoor] for the door with [pathKey] (Server.pathKey): all
  /// an app reopened over a running tunnel knows of the door it is on
  /// (VpnService.activeDoorKey).
  Future<void> forgetStalledDoorKey(String pathKey) async {
    if (pathKey == Server.psiphon.pathKey) return;
    try {
      final network = await _networkKey();
      await _memory.markFailed(network, pathKey);
    } catch (e) {
      debugPrint('ConnectFlow: could not forget the dead door: $e');
    }
  }

  /// The most doors [checkThrottled] checks beside the one the tunnel is
  /// on: with it, as many as a sweep checks at once (DoorSweep.maxDoors).
  static const fasterDoorChecks = DoorSweep.maxDoors - 1;

  /// How much of the check time of the door the tunnel is on a door's check
  /// may take, at most, for [checkThrottled] to call it faster. A door
  /// check fetches a small page through a core of its own, not a download,
  /// so it says something about a throttled door only when the gap is
  /// wide.
  static const fasterShare = 0.5;

  /// After the stall watch found the tunnel throttled (StallRecovery): what
  /// a check of this connect's doors says to do ([ThrottleStep]). A door is
  /// faster when it checks open while the door in use checks closed to a
  /// new connection, or open in at most [fasterShare] of the time the door
  /// in use took.
  ///
  /// The door in use and up to [fasterDoorChecks] other doors of this
  /// connect, in its order, are checked at once, the way the background
  /// sweep checks beside a live tunnel, and nothing is reported. When the
  /// user picked their server, only that server's doors: the move goes
  /// through the fast path, which dials only those (preferDoor). The door
  /// in use is checked even when there is no other door, as for a shared
  /// link.
  ///
  /// On 2026-10-23 the throttle trigger ended 106 sessions on 72 phones,
  /// and the next session carried about half as much whether it moved or
  /// not. So the tunnel stays only when the door in use checks open and no
  /// door is faster. Every other way it is left, as builds up to 2.2.0 do,
  /// because a door closed to a new connection is a tunnel that cannot open
  /// one, while its old connections can keep it above the dead tunnel's
  /// line (StallWatch.minDown) for a long time. The tunnel is left without
  /// a check when this flow did not connect it, on the backup network, and
  /// where a check would go through the tunnel
  /// (DoorSweep.measuresRealNetwork).
  ///
  /// [ThrottleStep.stay], with nothing to do, when there is no tunnel or a
  /// tap is under way, before the checks or during them.
  Future<ThrottleCheck> checkThrottled() async {
    const ThrottleCheck stay = (step: ThrottleStep.stay, door: null);
    const ThrottleCheck leave = (step: ThrottleStep.leave, door: null);
    if (!_vpn.isConnected || isBusy) return stay;
    final current = _vpn.activeDoor ?? _onDoor;
    if (_stage != ConnectStage.done ||
        current == null ||
        current.isPsiphon ||
        !_sweep.measuresRealNetwork(connected: true)) {
      return leave;
    }
    final picked = _poolPreferred;
    final others = [
      for (final p in _standbyPool)
        if (p.pathKey != current.pathKey &&
            (picked == null || _sameServer(p, picked)))
          p,
    ].take(fasterDoorChecks).toList();
    final List<ProbeResult> results;
    try {
      results = await _sweep.probeAll([current, ...others]);
    } catch (e) {
      debugPrint('ConnectFlow: could not check the doors: $e');
      return leave;
    }
    if (_stage != ConnectStage.done || !_vpn.isConnected) return stay;
    if (results.length != others.length + 1) return leave;
    final mine = results.first;
    Server? best;
    var bestMs = 0;
    for (final (i, r) in results.skip(1).indexed) {
      final ms = r.ms;
      if (!r.ok || ms == null || (best != null && ms >= bestMs)) continue;
      best = others[i];
      bestMs = ms;
    }
    final mineMs = mine.ms;
    if (best != null &&
        (!mine.ok || (mineMs != null && bestMs <= mineMs * fasterShare))) {
      return (step: ThrottleStep.move, door: best);
    }
    return mine.ok ? stay : leave;
  }

  /// Make [door] the door the next search dials first on this network, on
  /// its fast path (PathMemory.prefer). For a move to a door [checkThrottled]
  /// found: StallRecovery then runs the search.
  Future<void> preferDoor(Server door) async {
    try {
      final network = await _networkKey();
      await _memory.prefer(network, door.pathKey);
    } catch (e) {
      debugPrint('ConnectFlow: could not put the faster door first: $e');
    }
  }

  /// Whether the phone reaches a site abroad now, asked as the checklist's
  /// control fetch asks, with nothing on screen changing
  /// (PathFinder.reachesAbroad). For StallRecovery: a tunnel also stops
  /// carrying data when the phone's own internet goes away, and then its
  /// door is not at fault.
  Future<bool> reachesAbroad() => _finder.reachesAbroad();

  /// The phone has no way abroad, as a check made outside a try found
  /// (StallRecovery, before the search that follows a dead tunnel). That
  /// search, and the tries after it, skip the fast path until the way is
  /// back ([_noWayAbroad]).
  void noteOffline() => _noWayAbroad = true;

  Future<void> _rememberSwitch(
    Server from,
    Server to, {
    required bool failed,
  }) async {
    try {
      final network = await _networkKey();
      if (failed) await _memory.markFailed(network, from.pathKey);
      await _memory.remember(network, to.pathKey, holding: _held);
    } catch (e) {
      debugPrint('ConnectFlow: could not record the switch: $e');
    }
  }

  /// One tunnel attempt through [path]: true once traffic is verified.
  ///
  /// Dials nothing for a stale run. The callers check too, but a check
  /// missed there would bring a tunnel up after the user stopped.
  ///
  /// [source] is where [path] came from, when [LinkSource.of] cannot tell.
  /// [standby] stands in for the own doors StandbyDoors.pick would hold.
  /// [timeout] stands in for [attemptTimeout].
  Future<bool> _attempt(
    Server path,
    int run, {
    LinkSource? source,
    List<Server>? standby,
    Duration? timeout,
  }) async {
    if (_stale(run)) return false;
    // This run's trace: a run that is not stale is the latest one.
    final trace = _trace;
    final started = DateTime.now();
    _chosen = path;
    // The fast path's dial, which the screen names from the first second.
    final fast = _stage == ConnectStage.fastPath;
    if (fast) _fastDoor = path;
    _enter(RouteKind.of(path));
    notifyListeners();
    // The tap's first dial alone may take the slot from another VPN app.
    var takeSlot = false;
    if (_tapDial) {
      _tapDial = false;
      takeSlot = await _tapMayTakeSlot();
      if (_stale(run)) return false;
    }
    final outcome = _outcome(timeout ?? attemptTimeout);
    if (takeSlot) _vpn.allowTakingSlot();
    // For the failure's verdict: an answer from our API since the tap began
    // says the phone had internet (VpnService.tapStarted).
    _vpn.tapStarted = _tapStartedAt;
    // Not awaited: the service reports through its status, and its own
    // call can outlive the attempt (a platform that never answers is one
    // of the failures the watchdog exists for). The outcome is the truth.
    unawaited(
      _vpn
          .connect(
            path,
            attemptId: _attemptId,
            standby:
                standby ??
                StandbyDoors.pick(
                  path,
                  _standbyPool,
                  ipv6: _standbyIpv6,
                  closed: _closedHere(run),
                ),
            source: source,
          )
          .then(
            (_) {},
            onError: (e) => debugPrint('ConnectFlow: connect threw: $e'),
          ),
    );
    final ok = await outcome;
    if (fast && !_stale(run)) _fastDoor = null;
    // Read before anyone clears the error: the flow clears it after a
    // failed pick, and with it the reason.
    if (!ok && _vpn.failedOnPermission) _permissionRefused = true;
    // Another VPN app holds the slot, and this dial was not allowed to take
    // it: the user has switched to that app. The tap ends here as a stop
    // ends it, with no next door, no retry and no failure reported.
    if (!ok && _vpn.lostSlot && !_stale(run)) _giveWay();
    // Why it failed is in the tunnel events under the same attempt id. The
    // trace says only whether the user stopped it or the wait ran out.
    trace?.add(
      path,
      TraceStage.dial,
      ok ? TraceResult.ok : TraceResult.fail,
      reason: ok
          ? null
          : _stale(run)
          ? TraceReason.stopped
          : _attemptTimedOut
          ? TraceReason.timeout
          : TraceReason.other,
      ms: DateTime.now().difference(started).inMilliseconds,
      began: started,
    );
    // A cut that waited for this dial's tunnel to be checked is made now.
    // When the tunnel carries, the gates stay closed and nothing is cut.
    if (_cutWaitRun == run) {
      _cutWaitRun = null;
      _cutSearch(run, _cutWaitStage);
    }
    return ok && !_stale(run);
  }

  /// The doors [run]'s own checks found closed, by path key, for the
  /// standby doors of its dials (StandbyDoors.pick, which puts them last).
  /// Empty before [run] diagnosed: the finder's rows are then another
  /// run's, maybe on another network.
  Set<String> _closedHere(int run) => _diagnosedRun != run
      ? const {}
      : {
          for (final c in _finder.checks)
            if (c.state == PathCheckState.blocked) c.path.pathKey,
        };

  /// Resolves when the service settles: verified up, or down.
  ///
  /// Gives up after [timeout], not counting the time Android's VPN
  /// permission dialog is on screen. A user who reads it for a minute
  /// before tapping OK has not watched the tunnel fail.
  Future<bool> _outcome(Duration timeout) {
    final done = Completer<bool>();
    _pending = done;
    _attemptTimedOut = false;
    var sawAttempt = false;
    var waitedOnUser = false;
    Timer? deadline;
    void arm() {
      deadline?.cancel();
      deadline = Timer(timeout, () {
        if (_vpn.awaitingPermission) return arm();
        if (!done.isCompleted) {
          _attemptTimedOut = true;
          done.complete(false);
        }
      });
    }

    void check() {
      if (done.isCompleted) return;
      if (_vpn.awaitingPermission) {
        waitedOnUser = true;
      } else if (waitedOnUser) {
        // The user answered: the attempt starts its clock now.
        waitedOnUser = false;
        arm();
      }
      if (_vpn.isConnected && !_vpn.isVerifying) {
        done.complete(true);
      } else if (_vpn.status == VpnStatus.error) {
        done.complete(false);
      } else if (_vpn.isConnecting || _vpn.isVerifying) {
        sawAttempt = true;
      } else if (_vpn.status == VpnStatus.disconnected && sawAttempt) {
        done.complete(false);
      }
    }

    _vpn.addListener(check);
    arm();
    // The service may already have settled before the first notification
    // reaches us, so look once without waiting for one.
    scheduleMicrotask(check);
    return done.future.whenComplete(() {
      deadline?.cancel();
      _vpn.removeListener(check);
    });
  }

  /// The door checks in [checked], the rows of a diagnosis in the order
  /// they ran, last pass included, as they stand now.
  static List<ProbeResult> _probeResults(List<PathCheck> checked) => [
    for (final c in checked)
      if (c.reportable)
        ProbeResult(
          door: c.path.door ?? '',
          ok: c.state == PathCheckState.open,
          serverHost: VlessLinkHost.of(c.path),
          ms: c.ms,
          error: c.error,
          tcpMs: c.tcpMs,
          phase: c.phase,
          timeline: c.timeline,
          doorKey: ConnectTrace.doorKey(c.path),
          // What the check dialled with: the probe applies the same split.
          strategy: VlessLink.strategy(TlsFragment.apply(c.path.connectionUri)),
        ),
  ];

  /// Sends [results] under [attemptId], the id of the run that made them.
  /// Not [_attemptId], which a later tap replaces while this waits on the
  /// carrier.
  ///
  /// [network] is the memory key of the network the tap's checks ran on,
  /// for the network facts each row carries (VpnEventReporter.recordProbes).
  Future<void> _report(
    List<ProbeResult> results,
    String attemptId, {
    String? network,
  }) async {
    if (results.isEmpty) return;
    await _reporter.recordProbes(
      results,
      carrier: await _carrier(),
      attemptId: attemptId,
      network: network,
    );
  }

  /// The network the latest tap's checks ran on, read where the tap reads
  /// its memory key. Taken when a report is queued, before any wait, so a
  /// later tap cannot change it.
  String? _reportNetwork;

  /// Sends [checked] as [_report] does: at once when one of them is open,
  /// otherwise once [control], the control fetch beside the search, has
  /// passed. Not awaited.
  ///
  /// Since 1.7.1 the fetch runs beside the door checks, so a tap can have
  /// rows and a failed fetch. Rows with no door open then stay on the
  /// phone. On an offline phone every check fails, and its rows would read
  /// like a carrier that started blocking every door, which is why
  /// DoorSweep.run makes the same fetch before it reports anything.
  ///
  /// Rows with a door open are queued at once, before the dial, as in
  /// 1.7.0. Found 2026-10-12 in review: the search returns as soon as a
  /// door is open, and the fetch can take about 10 seconds more where the
  /// control sites are slow (ConnectDiagnostics.controlCheck). Rows that
  /// waited for it could be queued after the tunnel was up and its
  /// "connected" event had gone out. The open row goes in the last of the
  /// tap's pieces (VpnEventReporter.probeUploadBytes), so the backend
  /// could hold the closed pieces dated after the connect, and the
  /// backend's stuck rules would count a connected phone as stuck. The
  /// fetch is not needed there: no phone without internet finds a door
  /// open.
  ///
  /// The rows are read when this is called, not when the fetch answers. A
  /// row checked again alone after the call (afterShared in _connect) then
  /// goes out once, as it stood here.
  void _reportOnline(
    List<PathCheck> checked,
    String attemptId,
    Future<bool> control,
  ) {
    final results = _probeResults(checked);
    final network = _reportNetwork;
    if (_anyOpen(checked)) {
      unawaited(_report(results, attemptId, network: network));
      return;
    }
    // The tap these rows belong to, for an answer from our API that says
    // the phone was online ([_answeredThisTap]) after its fetch failed.
    final since = _tapStartedAt;
    unawaited(() async {
      if (await control || _answeredAfter(since)) {
        await _report(results, attemptId, network: network);
      }
    }());
  }

  /// [control], or true at once when one of [rows] is open. A phone that
  /// found a door or a link open has internet, whatever the fetch says, so
  /// the rows of that check need not wait for the fetch.
  static Future<bool> _online(List<PathCheck> rows, Future<bool> control) =>
      _anyOpen(rows) ? Future.value(true) : control;

  static bool _anyOpen(List<PathCheck> rows) =>
      rows.any((c) => c.state == PathCheckState.open);

  /// Whether [dispose] has run. A try that ends after it says nothing.
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    _retry?.cancel();
    _stopWatchingNetwork();
    _finder.removeListener(notifyListeners);
    _vpn.removeListener(_followCore);
    super.dispose();
  }

  // ── defaults, wired to the platform ─────────────────────────────────

  static Future<DoorOutcome> _defaultRead(Server path) =>
      PingService().readDoor(path, timeout: const Duration(seconds: 5));

  static Future<bool> _defaultInternet() async {
    final r = await ConnectDiagnostics(channel: _channel).controlCheck();
    return r['control'] == 'ok';
  }

  static Future<bool> _defaultHome() async {
    final r = await ConnectDiagnostics(channel: _channel).homeCheck();
    return r['control_home'] == 'ok';
  }

  static Future<String?> _defaultCarrier() async {
    try {
      final report = await ConnectDiagnostics(
        channel: _channel,
      ).platformReport();
      final c = report['carrier'] ?? report['sim_carrier'];
      return c is String && c.isNotEmpty ? c : null;
    } catch (_) {
      return null;
    }
  }

  /// The key this phone's network is remembered by, as the door memory and
  /// the sweep read it. The size probe uses it too, so one network is
  /// measured once per interval however often the phone comes back to it.
  static Future<String> currentNetworkKey() => _defaultNetworkKey();

  /// What the memory is keyed on: the transport and the carrier, and on
  /// Wi-Fi the network's own key when the backend turns network keys on
  /// (`wifi:<key>`, see NetworkKeys; plain `wifi` otherwise). Two phones on
  /// Irancell mobile data are on the same network for this purpose; one
  /// phone on Irancell and then on home wifi is on two.
  static Future<String> _defaultNetworkKey() async {
    var transport = 'unknown';
    try {
      final results = await Connectivity().checkConnectivity();
      for (final r in results) {
        if (r == ConnectivityResult.vpn) continue;
        transport = switch (r) {
          ConnectivityResult.wifi => 'wifi',
          ConnectivityResult.mobile => 'mobile',
          ConnectivityResult.none => 'none',
          _ => 'other',
        };
        break;
      }
    } catch (_) {}
    // A Wi-Fi network has a key of its own while the backend turns network
    // keys on (NetworkKeys), so each Wi-Fi network remembers its own door.
    if (transport == 'wifi') return NetworkKeys.wifiMemoryKey();
    final carrier = transport == 'mobile' ? await _defaultCarrier() : null;
    return carrier == null ? transport : '$transport:$carrier';
  }
}

/// A try's question about the allowance ([ConnectFlow._spentAnswer]):
/// asked the first time a check of the try needs it, and its answer once
/// it has come.
class _AllowanceQuestion {
  _AllowanceQuestion(this.run, Future<bool> Function() ask)
    : at = DateTime.now() {
    answer = _ask(ask);
  }

  /// The run that asked.
  final int run;

  /// When it was asked.
  final DateTime at;

  /// The answer, or null after an error.
  late final Future<bool?> answer;

  /// The answer once it has come. Null while the question runs, and after
  /// an error.
  bool? value;

  /// Whether the question ended in an error.
  bool failed = false;

  Future<bool?> _ask(Future<bool> Function() ask) async {
    try {
      return value = await ask();
    } catch (e) {
      debugPrint('ConnectFlow: could not ask about the allowance: $e');
      failed = true;
      return null;
    }
  }
}
