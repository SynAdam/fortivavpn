import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/api_client.dart';
import '../api/device_service.dart';
import 'device_place.dart';
import 'link_facts.dart';
import '../data/models/connection_data.dart';
import 'log_privacy.dart';
import 'network_history.dart';
import 'network_keys.dart';
import 'path_finder.dart';
import 'report_queue.dart';
import 'stored_from_background.dart';

/// What happened to the tunnel, as the backend wants to hear it.
///
/// Mirrors `VpnEventType` on the backend. `connected` means verified, not
/// merely "the platform said up": the app only reports it once real traffic
/// has flowed through the tunnel. `heartbeat` is the one that is not a
/// transition: it says the tunnel is still up, and how many bytes it carried
/// since the previous beat. `doorSwitched` says the core moved the tunnel to
/// one of its standby doors in the middle of a session; it is not an attempt
/// and not a failure.
enum VpnEventType {
  connected,
  connectFailed,
  verifyFailed,
  dropped,
  disconnected,
  heartbeat,
  doorSwitched;

  String get wire => switch (this) {
    connected => 'connected',
    connectFailed => 'connect_failed',
    verifyFailed => 'verify_failed',
    dropped => 'dropped',
    disconnected => 'disconnected',
    heartbeat => 'heartbeat',
    doorSwitched => 'door_switched',
  };
}

typedef EventSender =
    Future<void> Function(
      String deviceId,
      List<Map<String, dynamic>> events,
      bool viaTunnel,
    );

/// Sends one upload of door checks to the backend: one piece of a
/// diagnosis, a sweep or a test point (see
/// [VpnEventReporter.probeUploadBytes]).
typedef ProbeSender =
    Future<void> Function(
      String deviceId,
      List<Map<String, dynamic>> probes,
      bool viaTunnel,
    );

/// Reads where the phone is, for the `place` of an events batch. Null when
/// there is nothing to send.
typedef PlaceReader = Future<Map<String, dynamic>?> Function();

/// Posts one JSON body to a backend path.
///
/// What the default senders stand on. A test passes its own to read the
/// body exactly as it would leave the phone, `sent_at` included.
typedef BackendPost =
    Future<void> Function(String path, Map<String, dynamic> body);

/// Why a door was checked.
///
/// A diagnosis only runs when the user could not connect, and it stops at
/// the first door that opens, so its rows answer "which door works once
/// the usual one is broken". A sweep checks every door whether or not one
/// was needed. The two cannot share an average, so the reason travels on
/// the row. Mirrors `ProbeSource` on the backend.
enum ProbeSource {
  diagnosis,
  sweep,

  /// A test point's timed check of every door.
  testpoint,

  /// A test point trying a ClientHello split users do not get.
  experiment;

  String get wire => switch (this) {
    diagnosis => 'diagnosis',
    sweep => 'sweep',
    testpoint => 'testpoint',
    experiment => 'experiment',
  };
}

/// One door the app tested during a diagnosis, and what it found.
///
/// Not a tunnel event: the phone that checks six doors and walks through
/// the seventh made one attempt, and the backend keeps these apart from
/// the events so no alert rule reads six failures.
class ProbeResult {
  const ProbeResult({
    required this.door,
    required this.ok,
    this.serverHost,
    this.ms,
    this.error,
    this.strategy,
    this.tcpMs,
    this.phase,
    this.timeline,
    this.doorKey,
  });

  final String door;
  final bool ok;
  final String? serverHost;
  final int? ms;
  final String? error;

  /// How long the plain TCP connection to the door's address took, when it
  /// connected. See DoorOutcome.tcpMs.
  final int? tcpMs;

  /// How far the check got: "ok", "tcp", "tls", and from a timed check
  /// also "proxy" or "late"; null when the phone cannot tell. See
  /// DoorOutcome.phase.
  final String? phase;

  /// When the check began and, for a timed check, how far it got on the
  /// sockets the core opened. See CheckTimeline.
  final CheckTimeline? timeline;

  /// The door as the backend's server row and door name ("13:ws-tls",
  /// ConnectTrace.doorKey). The phone's network history keeps doors by it:
  /// every Cloudflare door is dialled at one shared address, so the address
  /// would mix the doors of different servers. Never sent.
  final String? doorKey;

  /// The settings the check dialled with, the same shape a connect event's
  /// strategy has (see [VlessLink.strategy]), split ClientHello included.
  /// Without it a claim such as "splitting stopped working on Hamrah Aval"
  /// can only be checked against connects, which are survivor-biased.
  final Map<String, dynamic>? strategy;
}

/// Resolves the transport the device is on right now: 'wifi', 'mobile', or
/// 'other'. Null when it cannot be determined.
typedef NetworkTypeProbe = Future<String?> Function();

/// Reports tunnel transitions to the backend so operators can see users get
/// disconnected, and why, without anyone opening a support ticket.
///
/// Events are queued on the device and flushed opportunistically. That is
/// not a nicety: the moment a tunnel drops is precisely when the phone may
/// have no route to the backend, so `record` never awaits the network. The
/// queue survives restarts, is capped so a device that is offline for a week
/// cannot grow it without bound, and is flushed in batches the backend
/// accepts.
///
/// Nothing personal is sent: the server host the app dialled, the app and OS
/// version, a duration, and the app's own error string.
class VpnEventReporter {
  VpnEventReporter({
    EventSender? send,
    ProbeSender? sendProbes,
    BackendPost? post,
    DateTime Function()? clock,
    Future<String> Function()? deviceId,
    Future<String> Function()? appVersion,
    String? platform,
    String? osVersion,
    NetworkTypeProbe? networkType,
    PlaceReader? place,
    Future<void> Function()? register,
    Future<Map<String, Object>> Function()? linkFacts,
    List<ReportQueue>? queues,
  }) : _send =
           send ??
           _postEvents(
             post ?? _apiPost,
             clock ?? DateTime.now,
             place ?? DevicePlace().read,
           ),
       _sendProbes =
           sendProbes ?? _postProbes(post ?? _apiPost, clock ?? DateTime.now),
       _post = post ?? _apiPost,
       _deviceId = deviceId ?? (() => DeviceService().getDeviceId()),
       _appVersion = appVersion ?? (() => DeviceService().getAppVersion()),
       _platform = platform ?? DeviceService().platform,
       _osVersion = osVersion ?? _defaultOsVersion(),
       _networkType = networkType ?? currentNetworkType,
       _linkFacts = linkFacts ?? LinkFacts().read,
       _clock = clock ?? DateTime.now,
       _register =
           register ?? (() async => await DeviceService().registerDevice()),
       _queues =
           queues ??
           [
             ReportQueue.sizeProbes(
               post: post,
               deviceId: deviceId,
               register: register,
               clock: clock,
             ),
             ReportQueue.connectTraces(
               post: post,
               deviceId: deviceId,
               register: register,
               clock: clock,
             ),
             ReportQueue.deliveryLog(
               post: post,
               deviceId: deviceId,
               register: register,
               clock: clock,
             ),
           ];

  static const storageKey = 'fortiva_vpn_events_queue';

  /// Settings switch. Unset means on: the report is what lets us fix the
  /// thing the user is looking at, and it carries nothing about them.
  static const sharePrefKey = 'pref_share_diagnostics';

  /// Set the settings switch. Turning it off also drops every report
  /// waiting on the phone (events, door checks, size probe readings,
  /// connect traces and the delivery log), because the user has said no
  /// and a report queued earlier must not go out after that. Door checks
  /// can wait up to [closedProbesKeptFor] and are tried on a timer and on
  /// every network change, so they would otherwise keep going out for
  /// hours.
  static Future<void> setSharing(bool on) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(sharePrefKey, on);
    if (on) return;
    await _serialized(() async {
      await prefs.remove(storageKey);
      await prefs.remove(probeStorageKey);
    });
    await ReportQueue.clear(ReportQueue.allKeys);
  }

  /// Whether the user lets the app send reports. Unset means yes. Read
  /// again before every upload, so a run that is already going when the
  /// switch is turned off sends nothing more.
  static Future<bool> _sharing() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.get(sharePrefKey) != false;
  }

  static const maxQueued = 200;
  static const batchSize = 50; // the backend's MAX_EVENTS_PER_BATCH

  /// Where door checks wait when they could not be sent.
  static const probeStorageKey = 'fortiva_vpn_probes_queue';

  /// How long door checks may wait when at least one door was open. A
  /// reading of the network is worth sending late, but not much later than
  /// this: past it, it describes a block that may already have moved.
  static const probesKeptFor = Duration(minutes: 30);

  /// How long a diagnosis may wait when it found every door closed.
  ///
  /// That phone could not connect at all, and its door checks are the only
  /// report it makes. They are also the report least likely to get out,
  /// because the line that blocks every door can cut our uploads too. A
  /// phone can find every door closed on its home line, fail to send the
  /// checks from that line, and reach us hours later from another network.
  /// Checks kept for 30 minutes are dropped by then, and the backend never
  /// learns the block from that phone.
  ///
  /// 12 hours covers a wait of that kind, and most late failure events
  /// arrive within it. The backend moves each client_ts back to when the
  /// check ran, and files a late wifi check sent over mobile data under no
  /// carrier, so a late reading is not filed as fresh news from the network
  /// that carried it. It is not kept longer because the backend's
  /// monitoring counts a row from when it arrives, and the older a reading
  /// is, the more likely the block it describes has changed.
  static const closedProbesKeptFor = Duration(hours: 12);

  /// The most one door-check upload should carry, in bytes of JSON body.
  ///
  /// A line that blocks every door can also pass a phone's small calls
  /// (register, the allowance check, a short candidate check) and cut its
  /// larger door-check uploads and failure events. Size may not be the whole
  /// reason. But small calls were the only ones that got through while
  /// every door was closed. So every door-check upload is sent in pieces of
  /// at most this size, each one queued and sent on its own: a diagnosis, a
  /// sweep and a test point alike. Until
  /// 2026-10-09 only a diagnosis that found every door closed was cut up,
  /// and an emulator test that day sent the 12 checks of one sweep as one
  /// upload of 4,794 bytes.
  ///
  /// The backend puts the pieces of one tap or sweep back together by
  /// attempt_id. No reader there goes by upload. A piece of a diagnosis
  /// that found every door closed reads the same as the whole of it. A
  /// diagnosis that found an open door has that row in one piece only, so
  /// until that piece arrives the other pieces read as a tap whose every
  /// door was closed. The tap's own events clear that reading too: the
  /// stuck rule counts a phone as stuck only when no connect came after its
  /// closed tap, and the dashboard leaves out a tap that wrote an event. So
  /// the wrong reading lasts only while the piece with the open row and the
  /// tap's events are both still on the phone.
  ///
  /// Each piece of a closed diagnosis is enough for the stuck rule on its
  /// own: it needs one tap whose every check was closed, not every check of
  /// the tap. Most closed diagnoses are a few KB, so in pieces they make a
  /// few uploads, each under 1,000 bytes.
  static const probeUploadBytes = 1000;

  /// At most this many waiting door-check uploads, the oldest dropped
  /// first. It counts pieces, not taps.
  ///
  /// It holds one press of the connect button on a phone where every door
  /// is closed, with the tries the tap then makes by itself, and a few
  /// pieces queued before that press. Measured on 2026-10-12 from the rows
  /// recordProbes builds on Android, which carry tcp_ms, phase and the link
  /// facts since 2026-10-09: a closed row is 440 to 510 bytes. One that
  /// failed with "tcp ok; no answer" is 480 bytes or more and goes in a
  /// piece of its own; a shorter one, such as "tcp timeout", shares a piece
  /// with one more. A phone has 19 to 22 doors, and since the own doors
  /// are checked several at once, a tap that finds every door closed
  /// reports nearly all of them, plus one row from the own-first check
  /// (ConnectFlow._ownFirst). With the backend's 4 tries after a tap
  /// (CHECKLIST_RETRY_SECONDS 5,10,20,30 on 2026-10-11), one press makes 5
  /// taps of up to 23 pieces: 115.
  ///
  /// Until 2026-10-12 this was 40, sized when a tap had 7 rows at the
  /// median. Found that day in review: such a press pushed out older
  /// pieces that were not repeats of its own. One was the piece with the
  /// open row of an earlier tap whose other pieces had gone out, and the
  /// backend then read that tap as one that found every door closed.
  ///
  /// A sweep of 12 doors takes 6 to 12 pieces, by the size of its rows. One
  /// test point round takes up to 28: it checks up to `DoorSweep.maxDoors`
  /// doors and then up to `TestPointRunner.maxVariants` experiments, and
  /// its rows keep the whole strategy, so each row goes in a piece of its
  /// own. While the flush is stopped, for example by the backend's limit
  /// on probe uploads, a test point phone starts dropping its oldest
  /// pieces in its fifth round. Each upload is at most [probeUploadBytes]
  /// unless one row is larger on its own, as an F&F experiment row is, so
  /// the stored queue stays at about 130 KB at most.
  static const maxQueuedProbeBatches = 120;

  final EventSender _send;
  final ProbeSender _sendProbes;
  final BackendPost _post;
  final Future<String> Function() _deviceId;
  final Future<String> Function() _appVersion;
  final String _platform;
  final String? _osVersion;
  final NetworkTypeProbe _networkType;
  final Future<Map<String, Object>> Function() _linkFacts;
  final DateTime Function() _clock;

  /// The small reports sent after the events: size probe readings, connect
  /// traces and the delivery log. See [ReportQueue].
  final List<ReportQueue> _queues;

  /// Registers this device with the backend. Called when a send is
  /// answered 404, which means the backend has never seen this device: on
  /// 2026-10-06 a phone whose register call was cut kept its failed connect
  /// and its door checks for an hour, and the backend refused them all.
  final Future<void> Function() _register;

  /// Whether this app's own requests leave through the tunnel, which is not
  /// the same question as whether the tunnel is up: Android excludes this
  /// app from the TUN, so its reports go out on the real network even while
  /// a user is connected. Set by VpnService, which owns the answer.
  ///
  /// Left null the reporter assumes they do, because that is the reading
  /// that makes the backend discard the carrier rather than attribute an
  /// event to the wrong network.
  bool Function()? reportsGoThroughTunnel;

  /// The flush of the waiting door checks that is running now, in any
  /// instance, and whether another call came in while it ran.
  ///
  /// Shared by every instance because the queue is: ConnectFlow, the
  /// sweep, the test point and VpnService all queue door checks, and two
  /// flushes reading the same queue would both send the same upload. The
  /// backend does not recognise a door check it has already stored, so the
  /// checks would count twice.
  static Future<void>? _probeRun;
  static bool _probesAgain = false;

  /// The same for the events queue, per instance: only VpnService's
  /// reporter records events, and ConnectFlow shares it. The backend
  /// recognises an event it has already stored.
  Future<void>? _eventRun;
  bool _eventsAgain = false;

  /// How many rounds one run makes at most.
  ///
  /// A report queued while a run is in flight joins that run instead of
  /// starting a second one, so two runs never send the same upload. Each
  /// round reads the stored queue again before every upload, but that is
  /// not enough on its own, for two reasons. The report may be stored after
  /// the round's last read, while the run is still finishing. Or the round
  /// may have stopped at an upload that failed, for example on the network
  /// the phone has just left. Without another round, that report would
  /// wait for the next try, which can be 5 minutes or more away. So a run
  /// in which a report was queued goes round once more. The bound stops it
  /// going round for ever on a line where every upload fails while new taps
  /// keep being queued. ReportQueue's runs use the same bound.
  static const maxRounds = 3;

  /// Every change to the stored queue runs through this, one at a time, in
  /// every instance, because they all share one stored queue.
  ///
  /// Without it an event recorded while a batch was in flight was lost: the
  /// flush stored the copy of the queue it read before sending, minus the
  /// batch, over the one that held the new event. Two records at the same
  /// moment could do the same to each other. On 2026-10-02 a connected event
  /// went that way, recorded while the batch before it was being sent, and
  /// 11 of 192 sessions on 1.6.2 that day had heartbeats and no connected.
  static Future<void> _queueLock = Future.value();

  static Future<T> _serialized<T>(Future<T> Function() body) {
    final run = _queueLock.then((_) => body());
    _queueLock = run.then((_) {}, onError: (_) {});
    return run;
  }

  static String? _defaultOsVersion() {
    try {
      final v = Platform.operatingSystemVersion.trim();
      return v.isEmpty ? null : (v.length > 50 ? v.substring(0, 50) : v);
    } catch (_) {
      return null;
    }
  }

  /// The transport in use, as connectivity_plus reports it.
  ///
  /// A live tunnel shows up as its own entry on some platforms and hides the
  /// transport underneath, so `vpn` is skipped rather than reported: the
  /// useful answer is what the phone is actually on, and an event recorded
  /// while the tunnel is up is one the backend will not attribute anyway.
  static Future<String?> currentNetworkType() async {
    try {
      final results = await Connectivity().checkConnectivity();
      for (final r in results) {
        switch (r) {
          case ConnectivityResult.wifi:
            return 'wifi';
          case ConnectivityResult.mobile:
            return 'mobile';
          case ConnectivityResult.vpn:
            continue;
          case ConnectivityResult.none:
            return null;
          default:
            return 'other';
        }
      }
      return null;
    } catch (e) {
      debugPrint('VpnEventReporter: could not read connectivity: $e');
      return null;
    }
  }

  static String? _string(Object? v) => v is String && v.isNotEmpty ? v : null;

  static Future<void> _apiPost(String path, Map<String, dynamic> body) async {
    await ApiClient().post(path, body: body);
  }

  /// The default [EventSender]. [clock] is read for `sent_at` only; each
  /// event's `client_ts` is still the phone's time when it was recorded.
  static EventSender _postEvents(
    BackendPost post,
    DateTime Function() clock,
    PlaceReader place,
  ) => (deviceId, events, viaTunnel) async {
    // Read before sent_at, so sent_at stays the last thing stamped before
    // the request leaves.
    final where = await place();
    await post('/api/v1/devices/$deviceId/events', {
      'events': events,
      'via_tunnel': viaTunnel,
      // Read on every attempt, so a batch that failed and goes out
      // again later says when it really left. The server compares it
      // with its own clock and corrects each client_ts by the gap.
      'sent_at': clock().toUtc().toIso8601String(),
      // Where the phone is now, read when the batch leaves. It describes
      // the sender, not the events, so a batch sent after hours offline
      // still says where the phone is today.
      'place': ?where,
    });
  };

  /// The default [ProbeSender]. [clock] is read for `sent_at` only.
  static ProbeSender _postProbes(BackendPost post, DateTime Function() clock) =>
      (deviceId, probes, viaTunnel) =>
          post('/api/v1/devices/$deviceId/probes', {
            'probes': probes,
            'via_tunnel': viaTunnel,
            // The server compares this with its own clock and corrects
            // each client_ts by the gap, because some phones' clocks are
            // hours or days off.
            'sent_at': clock().toUtc().toIso8601String(),
          });

  /// Send what a diagnosis found. Never throws.
  ///
  /// A probe is a reading of the network at one moment, and a reading
  /// delivered tomorrow would steer tomorrow's phones by yesterday's block.
  /// So a batch that cannot be sent waits at most [probesKeptFor], or
  /// [closedProbesKeptFor] when every door was closed, and goes out with
  /// the next [flush]. It used to be dropped at once, and the door checks
  /// of a phone whose network was cutting our calls never arrived: the
  /// phones that most needed reading.
  ///
  /// The checks are queued first and sent from the queue. They used to be
  /// queued only after every route had failed, which takes 10 seconds or
  /// more per route, and an app closed in that time lost them. A user whose
  /// line blocks every door often closes the app and opens it again.
  ///
  /// [network] is the memory key of the network the checks ran on
  /// (ConnectFlow.currentNetworkKey). With it, and while the backend turns
  /// network keys on, each row also says what this phone saw of that network
  /// before (NetworkHistory) and, on Wi-Fi, the network's key for the
  /// backend (NetworkKeys); then the batch is added to that history.
  Future<void> recordProbes(
    List<ProbeResult> results, {
    String? carrier,
    String? attemptId,
    ProbeSource source = ProbeSource.diagnosis,
    String? network,
  }) async {
    if (results.isEmpty) return;
    // Before the first await: a key read after an account deletion began
    // would have been made with the salt it removes.
    final generation = NetworkKeys.generation;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(sharePrefKey) == false) return;
      final networkType = await _networkType();
      final netKey = _oneKeyPerAttempt(
        attemptId,
        (await NetworkKeys.sharedFor(network))?.shared,
      );
      final facts = await _networkFacts(
        network,
        results,
        netKey,
        networkType,
        generation,
      );
      final appVersion = await _appVersion();
      // The line the checks ran on, read once for the batch: the checks of
      // one tap or sweep run within seconds of each other on one network.
      final link = await _linkFacts();
      final at = DateTime.now();
      final now = at.toUtc().toIso8601String();
      final probes = [
        for (final (i, r) in results.indexed)
          <String, dynamic>{
            'door': r.door,
            'ok': r.ok,
            // The same id the tunnel events from this tap carry, so the
            // ordered list of doors tried and the outcome of the one that
            // was walked through can be read back as one attempt.
            if (attemptId != null && attemptId.isNotEmpty)
              'attempt_id': attemptId,
            // Which check this was in the sequence. A door that wins first
            // and a door that wins sixth are not the same result. A sweep
            // checks every door, so its positions are just an order.
            'position': i + 1,
            'source': source.wire,
            'app_version': appVersion,
            'platform': _platform,
            if (r.serverHost != null && r.serverHost!.isNotEmpty)
              'server_host': r.serverHost,
            'ms': ?r.ms,
            if (r.error != null && r.error!.isNotEmpty)
              'error': r.error!.length > 200
                  ? r.error!.substring(0, 200)
                  : r.error,
            'network_type': ?networkType,
            'carrier': ?_string(carrier),
            'strategy': ?_probeStrategy(r.strategy, source),
            if (facts != null) ...facts[i].toRow(),
            'net_key': ?netKey,
            // How far the check got and how long the bare TCP connect took,
            // so "tcp ok; no answer" can be split into a cut handshake and a
            // slow or silent server without reading the error text.
            'tcp_ms': ?r.tcpMs,
            'phase': ?r.phase,
            ...timelineKeys(r.timeline, at),
            // link_mtu, private_dns and transport, when Android gave them.
            ...link,
            'client_ts': now,
          },
      ];
      // Only a diagnosis says the phone could not connect. A sweep runs
      // after a connect, and a test point checks on a timer, so neither is
      // the report of a phone that is stuck, and their pieces keep the
      // shorter time. Every upload goes in pieces (see [probeUploadBytes]).
      final closed =
          source == ProbeSource.diagnosis && results.every((r) => !r.ok);
      await _queueProbes(
        probePieces(probes),
        closed: closed,
        viaTunnel: reportsGoThroughTunnel?.call() ?? true,
        generation: generation,
      );
    } catch (e) {
      debugPrint('VpnEventReporter: could not queue probes: $e');
      return;
    }
    await _flushProbes(queued: true);
  }

  /// The Wi-Fi key each recent attempt sent, newest last.
  static final _attemptKeys = <String, String>{};

  /// Account deletion: the keys the recent attempts sent are made with the
  /// old salt. Each is replaced by a marker no key matches, so a later
  /// batch of an attempt that spans the deletion still goes without a key.
  static void forgetAttemptKeys() {
    for (final id in _attemptKeys.keys.toList()) {
      _attemptKeys[id] = '';
    }
  }

  /// [netKey], or null when [attemptId] already sent another key. One tap
  /// sends its rows in more than one batch, and when the key's period ends
  /// between two of them, two keys under one attempt id would tell the
  /// backend they are the same network. The later batch then goes without
  /// a key, and so without Wi-Fi facts.
  static String? _oneKeyPerAttempt(String? attemptId, String? netKey) {
    if (netKey == null || attemptId == null || attemptId.isEmpty) {
      return netKey;
    }
    final sent = _attemptKeys[attemptId];
    if (sent != null) return sent == netKey ? netKey : null;
    _attemptKeys[attemptId] = netKey;
    while (_attemptKeys.length > 16) {
      _attemptKeys.remove(_attemptKeys.keys.first);
    }
    return netKey;
  }

  /// What this phone saw before of the network [results] ran on, or null.
  ///
  /// A mobile network's history is kept under its carrier, and read only
  /// while the row's transport ([networkType]) is mobile: a tap that began
  /// on mobile data and ended on Wi-Fi sends rows that say Wi-Fi. A Wi-Fi
  /// network's is kept under [netKey], its key for the backend in this
  /// period, so nothing sent with the key comes from before the key began
  /// (NetworkHistory). A Wi-Fi network with no key to send has no facts.
  /// Plain `wifi`, `mobile` and `other` lump many networks together, so
  /// they get no facts and no history either. Never throws.
  static Future<List<NetworkFacts>?> _networkFacts(
    String? network,
    List<ProbeResult> results,
    String? netKey,
    String? networkType,
    int generation,
  ) async {
    if (network == null || !ConnectionData.current.networkKeys) return null;
    // An account deletion is removing what the phone knows of networks, or
    // ran since this batch began.
    if (NetworkKeys.closed || NetworkKeys.generation != generation) {
      return null;
    }
    final String history;
    if (network.startsWith('mobile:') && networkType == 'mobile') {
      history = network;
    } else if (network.startsWith('wifi:') && netKey != null) {
      history = 'wifi-period:$netKey';
    } else {
      return null;
    }
    try {
      return await NetworkHistory.instance.factsThenNote(
        history,
        [
          for (final r in results)
            (door: r.doorKey ?? '${r.serverHost ?? ''}|${r.door}', ok: r.ok),
        ],
        keep: () => !NetworkKeys.closed && NetworkKeys.generation == generation,
      );
    } catch (e) {
      debugPrint('VpnEventReporter: no network history: $e');
      return null;
    }
  }

  /// A check's [CheckTimeline] as row keys (backend issue #365, item 1).
  /// `began_ms` is how long before the row's `client_ts` the check began,
  /// so a row says when its own check ran while `client_ts` stays the
  /// batch's time. The rest comes from a timed check only; a field it did
  /// not reach is left out. The variant tests send the same keys
  /// (VariantTester).
  static Map<String, dynamic> timelineKeys(CheckTimeline? t, DateTime at) {
    if (t == null) return const {};
    final before = at.difference(t.began).inMilliseconds;
    return {
      if (before >= 0) 'began_ms': before,
      'boot_ms': ?t.bootMs,
      'cold_ms': ?t.coldMs,
      'dns_ms': ?t.dnsMs,
      'dial_ms': ?t.dialMs,
      'first_byte_ms': ?t.firstByteMs,
      'tls_ms': ?t.tlsMs,
      'reply_ms': ?t.replyMs,
      'bytes_out': ?t.bytesOut,
      'bytes_in': ?t.bytesIn,
      'dials': ?t.dials,
      'dial_fails': ?t.dialFails,
    };
  }

  /// The strategy keys a diagnosis or sweep row keeps.
  ///
  /// The rest (transport, security, port, fingerprint, path, mode and the
  /// like) is fixed by the door, which the row already names. Leaving it
  /// out takes the median 1.6.13 row of a closed tap from 537 to 411
  /// bytes (7 days to 2026-10-07). These are the keys the backend reads
  /// from a door check, or that change on the phone rather than with the
  /// door: host and sni name the server behind a Cloudflare door,
  /// fragment, ech and fm are the ClientHello split the phone applied, and
  /// pbk_prefix tells a phone holding a key we have since rotated.
  static const _checkStrategyKeys = [
    'host',
    'sni',
    'fragment',
    'ech',
    'fm',
    'pbk_prefix',
  ];

  /// What a door-check row carries of the settings it dialled with. A test
  /// point keeps all of them: it runs on a phone of ours, on a line that
  /// works, and its rows are read to compare settings.
  static Map<String, dynamic>? _probeStrategy(
    Map<String, dynamic>? strategy,
    ProbeSource source,
  ) {
    if (strategy == null || strategy.isEmpty) return null;
    if (source == ProbeSource.testpoint || source == ProbeSource.experiment) {
      return strategy;
    }
    final out = <String, dynamic>{
      for (final key in _checkStrategyKeys)
        if (strategy[key] != null) key: strategy[key],
    };
    // The backend reads host first and sni after it, so a host that
    // repeats the sni says nothing more.
    if (out['host'] == out['sni']) out.remove('host');
    return out.isEmpty ? null : out;
  }

  /// [probes] cut into uploads of at most [probeUploadBytes] each, in
  /// order. A row that is larger on its own goes alone.
  @visibleForTesting
  static List<List<Map<String, dynamic>>> probePieces(
    List<Map<String, dynamic>> probes,
  ) {
    final pieces = <List<Map<String, dynamic>>>[];
    var piece = <Map<String, dynamic>>[];
    for (final row in probes) {
      if (piece.isNotEmpty && uploadBytes([...piece, row]) > probeUploadBytes) {
        pieces.add(piece);
        piece = [];
      }
      piece.add(row);
    }
    if (piece.isNotEmpty) pieces.add(piece);
    return pieces;
  }

  /// The size of the body one door-check upload of [probes] would have,
  /// with the batch fields the default sender adds.
  @visibleForTesting
  static int uploadBytes(List<Map<String, dynamic>> probes) => utf8
      .encode(
        jsonEncode({
          'probes': probes,
          'via_tunnel': false,
          'sent_at': '2026-10-07T10:17:41.123456Z',
        }),
      )
      .length;

  /// Send one batch of door checks. True when it is done with: sent, or
  /// refused for good (see [refusedForGood]). A 404 registers the device
  /// and tries once more. False keeps the batch for a later try and stops
  /// the flush.
  Future<bool> _deliverProbes(
    List<Map<String, dynamic>> probes,
    bool viaTunnel, {
    int? generation,
  }) async {
    final deviceId = await _deviceId();
    for (var attempt = 0; attempt < 2; attempt++) {
      // Checked before each try: a deletion can come between the first
      // try and the one after registering the new device.
      final body = generation != null && _keysMoved(generation)
          ? withoutNetwork(probes)
          : probes;
      try {
        await _sendProbes(deviceId, body, viaTunnel);
        return true;
      } on ApiException catch (e) {
        if (refusedForGood(e)) {
          debugPrint('VpnEventReporter: backend refused probes, dropped: $e');
          return true;
        }
        if (!e.isNotFound || attempt > 0 || !await _registered()) return false;
      } catch (e) {
        debugPrint('VpnEventReporter: could not send probes: $e');
        return false;
      }
    }
    return false;
  }

  /// Whether the answer [e] means the same upload would be refused again.
  ///
  /// Only these answers can change on a later try, so only they keep an
  /// upload: no answer at all (status 0, the route did not carry the
  /// call), 404 (the device is not registered yet), 408 (the request timed
  /// out), 429 (rate limited) and any 5xx (a fault on our side). Every
  /// other 4xx is about the upload itself, such as 400, 413 or 422, or a
  /// 403 from Cloudflare for that body. Such an upload is dropped, because
  /// it stays at the head of the queue, and a closed one waits up to
  /// [closedProbesKeptFor]: kept, it would hold back every newer door check
  /// for that long.
  static bool refusedForGood(ApiException e) =>
      e.statusCode >= 400 &&
      e.statusCode < 500 &&
      !e.isNotFound &&
      e.statusCode != 408 &&
      e.statusCode != 429;

  /// Queue door-check uploads. [viaTunnel] is kept with each one, because
  /// any instance may be the one that sends it, and the instances do not
  /// all know whether the app's requests go through the tunnel.
  Future<void> _queueProbes(
    List<List<Map<String, dynamic>>> pieces, {
    required bool closed,
    required bool viaTunnel,
    int? generation,
  }) async {
    await _serialized(() async {
      final queue = await _loadProbes();
      final at = _clock().toUtc().toIso8601String();
      // After the last await: an account deletion that began since the
      // batch did takes its network facts and key with it.
      if (generation != null && _keysMoved(generation)) {
        pieces = [for (final p in pieces) withoutNetwork(p)];
      }
      for (final probes in pieces) {
        queue.add({
          'queued_at': at,
          if (closed) 'all_closed': true,
          'via_tunnel': viaTunnel,
          'probes': probes,
        });
      }
      while (queue.length > maxQueuedProbeBatches) {
        queue.removeAt(0);
      }
      await _storeProbes(queue);
    });
  }

  /// Send the waiting door checks. One run at a time across every
  /// instance; a call made while one runs waits for it. A call that has
  /// just [queued] something makes the run go round once more, so what it
  /// queued is sent too.
  Future<void> _flushProbes({bool queued = false}) {
    if (_probeRun != null) {
      if (queued) _probesAgain = true;
      return _probeRun!;
    }
    return _probeRun = _probeRounds();
  }

  Future<void> _probeRounds() async {
    try {
      for (var round = 0; round < maxRounds; round++) {
        _probesAgain = false;
        try {
          await _flushProbesOnce();
        } catch (e) {
          debugPrint('VpnEventReporter: probe flush error: $e');
        }
        if (!_probesAgain) return;
      }
    } finally {
      _probeRun = null;
    }
  }

  /// Send the door checks that are waiting, oldest first, and drop those
  /// past their time. Stops at the first upload that fails in a way a later
  /// try could fix: on a line that cuts uploads, each try costs 10 seconds
  /// or more per route. Sends nothing, and drops the queue, once the user
  /// has turned sharing off.
  Future<void> _flushProbesOnce() async {
    final tried = <String>{};
    while (true) {
      // Read again every round: checks queued while the last upload was in
      // flight are in the stored queue, not in any copy of it.
      final now = _clock();
      final next = await _serialized(() async {
        if (!await _sharing()) {
          await _storeProbes(const []);
          return null;
        }
        final queue = await _loadProbes();
        final fresh = [
          for (final entry in queue)
            if (_youngerThan(entry['queued_at'], _keptFor(entry), now)) entry,
        ];
        if (fresh.length != queue.length) await _storeProbes(fresh);
        for (final entry in fresh) {
          if (!tried.contains(jsonEncode(entry))) return entry;
        }
        return null;
      });
      if (next == null) return;
      final key = jsonEncode(next);
      tried.add(key);
      // Read with the queue: a deletion after this point means the copy in
      // hand may hold a key made with the salt it removed.
      final generation = NetworkKeys.generation;
      final probes = (next['probes'] as List)
          .whereType<Map>()
          .map((m) => m.cast<String, dynamic>())
          .toList();
      final via = next['via_tunnel'];
      final viaTunnel = via is bool
          ? via
          : reportsGoThroughTunnel?.call() ?? true;
      if (!await _deliverProbes(probes, viaTunnel, generation: generation)) {
        return;
      }
      await _serialized(() async {
        final queue = await _loadProbes();
        await _storeProbes([
          for (final e in queue)
            if (jsonEncode(e) != key) e,
        ]);
      });
    }
  }

  /// Whether an account deletion runs, or ran, since [generation].
  static bool _keysMoved(int generation) =>
      NetworkKeys.closed || NetworkKeys.generation != generation;

  /// [probes] without what they say about a network (NetworkFacts.rowKeys).
  @visibleForTesting
  static List<Map<String, dynamic>> withoutNetwork(
    List<Map<String, dynamic>> probes,
  ) => [
    for (final p in probes)
      {
        for (final e in p.entries)
          if (!NetworkFacts.rowKeys.contains(e.key)) e.key: e.value,
      },
  ];

  static Duration _keptFor(Map<String, dynamic> entry) =>
      entry['all_closed'] == true ? closedProbesKeptFor : probesKeptFor;

  static bool _youngerThan(Object? stamp, Duration limit, DateTime now) {
    final at = DateTime.tryParse(stamp?.toString() ?? '');
    return at != null && now.difference(at) < limit;
  }

  Future<List<Map<String, dynamic>>> _loadProbes() async {
    final prefs = await SharedPreferences.getInstance();
    // As stored: the keeper's engine sends and removes rows too.
    final raw = await StoredFromBackground.current(prefs, probeStorageKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .where((m) => m['probes'] is List)
          .map((m) => m.cast<String, dynamic>())
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _storeProbes(List<Map<String, dynamic>> queue) async {
    final prefs = await SharedPreferences.getInstance();
    if (queue.isEmpty) {
      await prefs.remove(probeStorageKey);
    } else {
      await prefs.setString(probeStorageKey, jsonEncode(queue));
    }
  }

  /// Register the device. True when that worked.
  Future<bool> _registered() async {
    try {
      await _register();
      return true;
    } catch (e) {
      debugPrint('VpnEventReporter: could not register the device: $e');
      return false;
    }
  }

  /// How many door-check batches are waiting. For tests and diagnostics.
  Future<int> pendingProbeBatches() async => (await _loadProbes()).length;

  /// Report the sites this device reached since the last report, as a count
  /// per host. Opt-in and privacy sensitive, so it honours the same share
  /// switch as everything else, and sends nothing when the switch is off or
  /// there is nothing to send. Counts only, no times, no order. Never throws.
  ///
  /// Returns whether the caller may drop these counts. False means only one
  /// thing: the send failed and the same counts should be offered again.
  /// Sharing being off returns true, because those counts are meant to be
  /// dropped, not kept and sent once the switch comes back on.
  Future<bool> reportDomains(Map<String, int> counts) async {
    if (counts.isEmpty) return true;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(sharePrefKey) == false) return true;
      final deviceId = await _deviceId();
      await _post('/api/v1/devices/$deviceId/domains', {'domains': counts});
      return true;
    } catch (e) {
      debugPrint('VpnEventReporter: could not report sites: $e');
      return false;
    }
  }

  /// The events that are sent without the core log: the failures.
  static const _sentWithoutCoreLog = {
    VpnEventType.connectFailed,
    VpnEventType.verifyFailed,
  };

  /// [diag] as an event of [type] carries it.
  ///
  /// A failure event (connect_failed, verify_failed) leaves the core log on
  /// the phone. The log is the large part of a failure: over the two days
  /// to 2026-10-07 the median verify_failed diagnosis had 6,748 characters,
  /// and its core log had about 6,000 of them (245 events). That made a
  /// failure event about 7 KB. A line can carry none of those events while
  /// it passes every small call from the same phone, and a failure is the
  /// event most likely to be sent from such a line.
  /// Without the log a failure event is about 1 KB. The attempt timeline
  /// stays, because it is about 20 characters. The screen keeps the whole
  /// diagnosis, log included (VpnService.lastDiagnosis), for a user who
  /// opens the details.
  ///
  /// Every other event keeps the log, without the lines that name a site
  /// or an address (LogPrivacy). The native side leaves those lines out
  /// where it reads the log, and this runs the same filter again. No
  /// backend rule reads the log, but the team reads it by hand. The lines
  /// that showed the 2026-09-13 DNS sinkhole ("dialing TCP to
  /// tcp:10.10.34.x") and DNS over TLS (":853") are left out now, and the
  /// native summary line counts them instead. The backend trims a log that
  /// is too long.
  static Map<String, dynamic>? _diagFor(
    VpnEventType type,
    Map<String, dynamic>? diag,
  ) {
    if (diag == null || diag.isEmpty) return null;
    if (!diag.containsKey('core_log')) return diag;
    final out = Map<String, dynamic>.of(diag);
    final log = out.remove('core_log');
    if (!_sentWithoutCoreLog.contains(type) && log is String) {
      final kept = LogPrivacy.scrub(log);
      if (kept.trim().isNotEmpty) out['core_log'] = kept;
    }
    return out.isEmpty ? null : out;
  }

  /// How long an outcome put in the queue by [hold] waits there, in this
  /// run, for [recordHeld] to fill it in. The longest wait is the day's
  /// first diagnosis after a connect, about 18 seconds.
  static const holdFor = Duration(seconds: 60);

  /// The local keys of a held row. Never sent.
  static const _holdKey = '_hold';
  static const _heldAtKey = '_held_ms';

  /// This run of the app. A held row from another run is one nothing will
  /// fill in any more.
  static String _run = _newRunId();

  static String _newRunId() {
    final r = Random();
    return List.generate(8, (_) => r.nextInt(16).toRadixString(16)).join();
  }

  /// A new run, as after the app was closed and opened again (tests).
  @visibleForTesting
  static void startNewRunForTest() => _run = _newRunId();

  /// Time since this run began, on a clock that never jumps: a held row's
  /// age is measured on it, so a phone clock set forward does not send a
  /// row before it could be filled in.
  @visibleForTesting
  static Duration Function() elapsed = _sinceStart;
  static final _started = Stopwatch()..start();
  static Duration _sinceStart() => _started.elapsed;

  int _holdCount = 0;

  /// The hold the [record] now starting fills in ([recordHeld]).
  HeldEvent? _filling;

  /// Put a tap's connected event in the queue now, before what its report
  /// waits for: the platform report and, once a day per network, a full
  /// diagnosis, up to about 18 seconds. "Connected" is on screen by then,
  /// and when the app's process ends in that time (a kill in the
  /// background, a swipe out of recents, Back on older Android) while the
  /// tunnel runs on in its own process, the event was lost: on 2026-10-16
  /// about 0.7% of the taps whose trace said connected had none.
  ///
  /// The held row is not sent while [recordHeld] with the returned handle
  /// may still fill it in: for [holdFor], in this run. That record replaces
  /// it, keeping its time. After that, or in a later run, it is sent as it
  /// is, with `held` in diag, and the record adds nothing.
  ///
  /// Only for connected. A failure row without its diagnosis reads on the
  /// backend as the door's fault (monitoring.verdict), also when the phone
  /// had no internet at all, so failures are still recorded once complete.
  /// Never throws.
  HeldEvent hold(
    VpnEventType type, {
    String? serverHost,
    String? door,
    String? attemptId,
    Map<String, dynamic>? strategy,
    Duration? duration,
    Map<String, dynamic>? diag,
  }) {
    final id = '$_run:${_holdCount++}';
    final stored = () async {
      try {
        final event = await _build(
          type,
          serverHost: serverHost,
          door: door,
          attemptId: attemptId,
          strategy: strategy,
          duration: duration,
          diag: diag,
        );
        if (event == null) return false;
        event[_holdKey] = id;
        event[_heldAtKey] = elapsed().inMilliseconds;
        await _serialized(() async {
          final queue = await _load();
          queue.add(event);
          while (queue.length > maxQueued) {
            queue.removeAt(0);
          }
          await _store(queue);
        });
        return true;
      } catch (e) {
        debugPrint('VpnEventReporter: could not hold event: $e');
        return false;
      }
    }();
    return HeldEvent._(id, stored);
  }

  /// [record], filling in the row [held] put in the queue: it replaces that
  /// row and keeps its time. When the row was sent as it was in the
  /// meantime, nothing is added, as the backend has the event already.
  /// With [held] null it is a plain [record].
  Future<void> recordHeld(
    HeldEvent? held,
    VpnEventType type, {
    String? serverHost,
    String? door,
    String? attemptId,
    Map<String, dynamic>? strategy,
    Duration? duration,
    String? error,
    Map<String, dynamic>? diag,
  }) {
    // Read by record before its first await, then cleared, so no other
    // record can take it.
    _filling = held;
    try {
      return record(
        type,
        serverHost: serverHost,
        door: door,
        attemptId: attemptId,
        strategy: strategy,
        duration: duration,
        error: error,
        diag: diag,
      );
    } finally {
      _filling = null;
    }
  }

  /// Whether [event] is a held row this run may still fill in.
  bool _heldBack(Map<String, dynamic> event) {
    final hold = event[_holdKey];
    if (hold is! String || !hold.startsWith('$_run:')) return false;
    final at = event[_heldAtKey];
    return at is int && elapsed().inMilliseconds - at < holdFor.inMilliseconds;
  }

  /// [event] as the backend gets it: a held row without its local keys and
  /// with `held` in diag, so it can be told from a filled-in one.
  static Map<String, dynamic> _wire(Map<String, dynamic> event) {
    if (!event.containsKey(_holdKey)) return event;
    final out = Map<String, dynamic>.from(event)
      ..remove(_holdKey)
      ..remove(_heldAtKey);
    final diag = out['diag'];
    out['diag'] = {
      if (diag is Map) ...diag.cast<String, dynamic>(),
      'held': true,
    };
    return out;
  }

  /// The event row for [record] and [hold], or null while the user has
  /// sharing off.
  Future<Map<String, dynamic>?> _build(
    VpnEventType type, {
    String? serverHost,
    String? door,
    String? attemptId,
    Map<String, dynamic>? strategy,
    Duration? duration,
    String? error,
    Map<String, dynamic>? diag,
    int? bytesUp,
    int? bytesDown,
    DateTime? at,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(sharePrefKey) == false) return null;
    // Read before queueing: this is the moment the fact is true. A batch
    // flushed hours later says nothing about what the phone was on when
    // the tunnel died. A second at most, so the row is stored before the
    // app can be closed.
    final network =
        await _networkType()
            .then<String?>((v) => v)
            .timeout(const Duration(seconds: 1), onTimeout: () => null) ??
        _string(diag?['network']);
    final carrier = _string(diag?['carrier']) ?? _string(diag?['sim_carrier']);
    return <String, dynamic>{
      'type': type.wire,
      'app_version': await _appVersion(),
      'platform': _platform,
      if (serverHost != null && serverHost.isNotEmpty)
        'server_host': serverHost,
      if (door != null && door.isNotEmpty) 'door': door,
      // Ties this row to every other row from the same tap, including the
      // door checks in path_probes. Without it a phone that tests six
      // doors and walks through the seventh writes seven rows across two
      // tables with nothing joining them, and the order it tried them in
      // is unrecoverable.
      if (attemptId != null && attemptId.isNotEmpty) 'attempt_id': attemptId,
      // The settings inside the door: transport, security, sni, the TLS
      // fingerprint. The door id alone cannot tell two experiments apart.
      if (strategy != null && strategy.isNotEmpty) 'strategy': strategy,
      if (_osVersion != null) 'os_version': _osVersion,
      'network_type': ?network,
      'carrier': ?carrier,
      if (duration != null) 'duration_seconds': duration.inSeconds,
      if (error != null && error.isNotEmpty)
        'error': error.length > 500 ? error.substring(0, 500) : error,
      // Heartbeats only, and top level rather than inside diag: the
      // backend's stall rule filters and sums on these on every poll.
      'bytes_up': ?bytesUp,
      'bytes_down': ?bytesDown,
      'diag': ?_diagFor(type, diag),
      // [at] when the event is recorded after it happened: the core keeps
      // its door moves with their own time, and the app reads them only
      // every few minutes.
      'client_ts': (at ?? DateTime.now()).toUtc().toIso8601String(),
    };
  }

  /// Queue one event and try to send. Never throws, never blocks the caller
  /// on the network.
  ///
  /// Called through [recordHeld], it fills in a held row instead.
  Future<void> record(
    VpnEventType type, {
    String? serverHost,
    String? door,
    String? attemptId,
    Map<String, dynamic>? strategy,
    Duration? duration,
    String? error,
    Map<String, dynamic>? diag,
    int? bytesUp,
    int? bytesDown,
    DateTime? at,
  }) async {
    try {
      final filling = _filling;
      _filling = null;
      final held = filling != null && await filling.stored ? filling.id : null;
      final event = await _build(
        type,
        serverHost: serverHost,
        door: door,
        attemptId: attemptId,
        strategy: strategy,
        duration: duration,
        error: error,
        diag: diag,
        bytesUp: bytesUp,
        bytesDown: bytesDown,
        at: at,
      );
      if (event == null) return;
      await _serialized(() async {
        final queue = await _load();
        if (held != null) {
          final i = queue.indexWhere((e) => e[_holdKey] == held);
          // Sent as it was, or about to be: no second copy.
          if (i < 0 || !_heldBack(queue[i])) return;
          event['client_ts'] = queue[i]['client_ts'];
          queue.removeAt(i);
        }
        queue.add(event);
        while (queue.length > maxQueued) {
          queue.removeAt(0);
        }
        await _store(queue);
      });
    } catch (e) {
      debugPrint('VpnEventReporter: could not queue event: $e');
      return;
    }
    // Fire and forget. A failure leaves the queue intact for the next flush.
    unawaited(_flushAll(queuedEvent: true));
  }

  /// Send everything queued: the waiting door checks first, then the
  /// events, oldest first, in batches. Never throws.
  ///
  /// The two queues go out independently. Door checks used to wait until
  /// every event had gone, and one failure event that a line would not
  /// carry could hold a phone's door checks back for hours, until they had
  /// expired. They go first because they are small and are the only report
  /// of a tap that found every door closed, and because the stuck rule
  /// compares when reports arrive: a late check that found every door
  /// closed has to arrive before the connected event that followed it, or
  /// the phone reads as still stuck.
  ///
  /// That order holds only within one call. Two cases break it. A call
  /// made while an events run is in flight starts a door-check run beside
  /// that events run, and the events run can send a connected event before
  /// those door checks are out. And when one piece of a closed tap fails,
  /// the pieces after it wait for a later call, which sends them after
  /// this call's events.
  ///
  /// Nothing is sent once the user has turned sharing off, and what is
  /// waiting is dropped (see [setSharing]).
  ///
  /// The small reports go last: size probe readings, connect traces, then
  /// the delivery log. The log goes after every other upload of this call,
  /// so it carries how they went.
  ///
  /// Events stop at the first failed batch and keep the rest for later,
  /// except a batch the backend refuses as invalid (422). Sending that
  /// again can never succeed, and keeping it would hold back every event
  /// queued behind it, so the batch is sent again one event at a time and
  /// only the refused events are dropped. A batch answered 404 registers
  /// the device and is sent once more. Safe to call any time: a call made
  /// while a flush is running waits for that run.
  Future<void> flush() => _flushAll();

  Future<void> _flushAll({bool queuedEvent = false}) async {
    await _flushProbes();
    await _flushQueuedEvents(queued: queuedEvent);
    for (final queue in _queues) {
      await queue.flush();
    }
  }

  Future<void> _flushQueuedEvents({bool queued = false}) {
    if (_eventRun != null) {
      if (queued) _eventsAgain = true;
      return _eventRun!;
    }
    return _eventRun = _eventRounds();
  }

  Future<void> _eventRounds() async {
    try {
      for (var round = 0; round < maxRounds; round++) {
        _eventsAgain = false;
        try {
          await _flushEvents();
        } catch (e) {
          debugPrint('VpnEventReporter: flush error: $e');
        }
        if (!_eventsAgain) return;
      }
    } finally {
      _eventRun = null;
    }
  }

  /// Send the queued events. True when the queue was emptied.
  Future<bool> _flushEvents() async {
    if ((await _load()).isEmpty) return true;
    final deviceId = await _deviceId();
    var size = batchSize;
    var registerTried = false;
    while (true) {
      if (!await _sharing()) {
        await _serialized(() => _store(const []));
        return true;
      }
      // Read again every round: events recorded while the last batch was
      // in flight are in the stored queue, not in any copy of it.
      final queue = await _load();
      if (queue.isEmpty) return true;
      // A held outcome this run may still fill in waits; the rest go round
      // it, so a heartbeat is never held back by it.
      final ready = [
        for (final e in queue)
          if (!_heldBack(e)) e,
      ];
      if (ready.isEmpty) return false;
      final batch = ready.take(size).toList();
      try {
        await _send(deviceId, [
          for (final e in batch) _wire(e),
        ], reportsGoThroughTunnel?.call() ?? true);
      } on ApiException catch (e) {
        if (e.isNotFound && !registerTried) {
          // The backend has never seen this device. Register it and send
          // the same batch again; one try per flush.
          registerTried = true;
          if (await _registered()) continue;
        }
        if (!e.isValidationError) {
          debugPrint(
            'VpnEventReporter: flush failed, keeping ${queue.length}: $e',
          );
          return false;
        }
        if (batch.length > 1) {
          // Find the event it refuses: the rest of this flush goes one by
          // one.
          size = 1;
          continue;
        }
        debugPrint('VpnEventReporter: backend refused an event, dropped: $e');
      } catch (e) {
        debugPrint(
          'VpnEventReporter: flush failed, keeping ${queue.length}: $e',
        );
        return false;
      }
      await _serialized(() => _remove(batch));
    }
  }

  /// Takes [batch] out of the stored queue and keeps everything else,
  /// including what was recorded after the batch was read.
  Future<void> _remove(List<Map<String, dynamic>> batch) async {
    final sent = {for (final e in batch) jsonEncode(e)};
    final queue = await _load();
    await _store([
      for (final e in queue)
        if (!sent.contains(jsonEncode(e))) e,
    ]);
  }

  /// The stored events queue as it is, held rows included (tests).
  @visibleForTesting
  Future<List<Map<String, dynamic>>> queuedForTest() => _load();

  Future<List<Map<String, dynamic>>> _load() async {
    final prefs = await SharedPreferences.getInstance();
    // As stored: the keeper's engine adds, sends and removes rows too.
    final raw = await StoredFromBackground.current(prefs, storageKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map((m) => m.cast<String, dynamic>())
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _store(List<Map<String, dynamic>> queue) async {
    final prefs = await SharedPreferences.getInstance();
    if (queue.isEmpty) {
      await prefs.remove(storageKey);
    } else {
      await prefs.setString(storageKey, jsonEncode(queue));
    }
  }

  /// How many events are waiting. For tests and diagnostics.
  Future<int> pending() async => (await _load()).length;
}

/// A tap's outcome put in the queue by [VpnEventReporter.hold], for
/// [VpnEventReporter.recordHeld] to fill in.
class HeldEvent {
  HeldEvent._(this.id, this.stored);

  /// The held row's local id.
  final String id;

  /// Whether the held row was stored: false while sharing is off, or when
  /// storing failed.
  final Future<bool> stored;
}
