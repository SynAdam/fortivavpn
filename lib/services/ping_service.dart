import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import '../data/models/connection_data.dart';
import '../data/models/door_outbound.dart';
import '../data/models/server.dart';
import '../utils/shared_link.dart';
import '../utils/tls_fragment.dart';
import 'path_finder.dart';
import 'tunnel_channels.dart';

/// A door check that failed, and why, in the words the backend stores with
/// the check (see [PingService.checkDoor]).
///
/// The reason starts with how a plain TCP connection to the door's address
/// went, when the phone could tell: "tcp timeout" means the address itself
/// is blocked on this network; "tcp ok 80ms" means the address is open and
/// what failed came after it, the handshake or our server. Then the core's
/// own words, usually "EOF" or "no answer in 3000 ms".
class DoorCheckFailed implements Exception {
  const DoorCheckFailed(this.reason);

  /// From the map the native `realPingDetail` returns.
  factory DoorCheckFailed.fromNative(Map<dynamic, dynamic> result) {
    final parts = <String>[];
    final tcp = result['tcp'];
    if (tcp is String && tcp.isNotEmpty) {
      final ms = result['tcpMs'];
      parts.add(
        tcp == 'ok' && ms is num ? 'tcp ok ${ms.toInt()}ms' : 'tcp $tcp',
      );
    }
    final error = result['error'];
    if (error is String && error.isNotEmpty) parts.add(error);
    return DoorCheckFailed(parts.isEmpty ? 'no answer' : parts.join('; '));
  }

  final String reason;

  @override
  String toString() => reason;
}

/// Real proxy ping service — measures actual tunnel outbound latency
///
/// Instead of a simple TCP port check (which incorrectly shows "green"
/// for disabled links), this service calls the native tunnel core
/// to start a temporary proxy instance and route an HTTP request through it.
///
/// On Android: uses native core's measureOutboundDelay()
/// On iOS:     uses native core's ping()
///
/// If the server link is disabled or broken, the native core correctly
/// returns -1 (timeout), which the UI shows as "timeout".
class PingService {
  static final PingService _instance = PingService._internal();
  factory PingService() => _instance;
  PingService._internal();

  /// Method channel shared with VpnService
  static final _channel = TunnelChannels.method;

  /// Cancellation signal for the current bulk ping operation
  Completer<void>? _cancelCompleter;

  /// Whether a cancellation has been requested
  bool get isCancelled => _cancelCompleter?.isCompleted ?? false;

  /// How many native tests are under way now, from every caller: the
  /// checklist, the sweep, the server lists, the candidate and variant
  /// tests. A test that runs beside another can dial with the other's
  /// split (TestLink.config on Android), so a background test starts only
  /// when this is 0, and reads [started] to tell whether another began
  /// while it ran (VariantTester).
  static int get running => _running;
  static int _running = 0;

  /// How many native tests have started in this run.
  static int get started => _started;
  static int _started = 0;

  /// [call], counted in [running] and [started].
  static Future<T> _counted<T>(Future<T> Function() call) async {
    _running++;
    _started++;
    try {
      return await call();
    } finally {
      _running--;
    }
  }

  /// Cancel the current bulk ping operation.
  /// The loop will stop after the currently-in-flight ping finishes.
  void cancelAll() {
    if (_cancelCompleter != null && !_cancelCompleter!.isCompleted) {
      _cancelCompleter!.complete();
    }
  }

  /// Whether [link] is worth sending to the native test: a link of a kind
  /// the core can dial (vless, vmess, trojan or ss) without allowInsecure,
  /// and not one that is plainly broken. False is never a check that ran.
  static bool canTest(String link) => _isValidConnectionUri(link);

  /// Quick validation: is this connection URI worth sending to native code?
  /// Returns false for obviously malformed links that would fail instantly.
  ///
  /// Only vless links used to pass. vmess, trojan and ss links on the
  /// public list then showed as a timeout after "Test all" and counted as
  /// closed in the fallback, although the tunnel dials all of them.
  static bool _isValidConnectionUri(String link) {
    if (!SharedLink.usable(link)) return false;

    // A vless link must have a UUID and host at minimum
    if (link.startsWith('vless://') && link.length < 50) return false;

    // Backticks crash Java URI parser — check entire URL
    if (link.contains('`')) return false;

    // Check for double fragment (#...#...) which is malformed
    final fragmentIndex = link.indexOf('#');
    if (fragmentIndex > 0) {
      final afterFragment = link.substring(fragmentIndex + 1);
      if (afterFragment.contains('#')) return false;
    }

    return true;
  }

  /// The arguments of a native test of [link]. [coreTimeout], when given,
  /// is how long the core waits for data; without it the native side waits
  /// its own 3 s, which the connect checklist's checks are built around.
  /// The native side used to wait 3 s whatever the caller's own wait was,
  /// so an 8 s candidate check gave up at 3 s and was reported as "no data
  /// within 8s".
  ///
  /// `splitter` is the app's split ([TlsFragment.spec]), sent with every
  /// link and not only the TLS ones it is added to. Android puts a splitter
  /// with it into every test's core, because the cores of tests that run
  /// side by side share one dialer, and a TLS test looks its splitter up
  /// in the newest core (TestLink.config on Android). Every test goes
  /// through here: the checklist, the shared fallback, the sweep, the test
  /// point, the candidate prober and the server list.
  ///
  /// On a phone whose own TLS doors carry a split of their own (a door
  /// experiment's test arm, or a promoted split), that split is sent in
  /// place of the app's ([TlsFragment.doorSpec]). A TLS door test retries
  /// its dial through the splitter of the newest core. On 2026-10-12, with
  /// the pinned core and a filter that reset any first segment over 100
  /// bytes, a door whose own split was `tlshello,200-400,1-2` read open in
  /// 5 of 5 runs when a Reality test beside it carried the app's 10-20
  /// split, and closed in 5 of 5 alone or when that test carried the
  /// door's split. Its tunnel dials with its own split only, so that door
  /// was dialled and reset, and the experiment counted the app's split as
  /// the test arm's.
  ///
  /// `doorOutbound` is the backend's own outbound for the door, when the
  /// door has one and is dialled as the backend wrote its link
  /// ([DoorOutbounds.nativeFor]). Android then checks that outbound in
  /// place of the one it reads from the link. Absent for every other link.
  static Map<String, Object> _testArgs(String link, Duration? coreTimeout) {
    final sent = TlsFragment.apply(link);
    return {
      'link': sent,
      'splitter': TlsFragment.doorSpec ?? TlsFragment.spec,
      if (coreTimeout != null) 'timeoutMs': coreTimeout.inMilliseconds,
      'doorOutbound': ?DoorOutbounds.nativeFor(link, sent),
    };
  }

  /// Ping a single server using real proxy-level test
  ///
  /// Sends the connection URI to the native side, which:
  /// 1. Parses the link into a tunnel config
  /// 2. Starts a temporary tunnel instance
  /// 3. Routes an HTTP request through the proxy outbound
  /// 4. Returns the latency in ms, or -1 for timeout/failure
  ///
  /// [coreTimeout] is how long the core waits for data (see [_testArgs]);
  /// [timeout] is how long this waits for the native side, and has to be
  /// longer.
  Future<int> pingServer(
    Server server, {
    Duration timeout = const Duration(seconds: 10),
    Duration? coreTimeout,
  }) async {
    // Pre-validate the link — skip obviously broken ones without calling native
    if (!_isValidConnectionUri(server.connectionUri)) {
      return -1;
    }

    try {
      final result = await _counted(
        () => _channel
            .invokeMethod<dynamic>(
              'realPing',
              _testArgs(server.connectionUri, coreTimeout),
            )
            .timeout(timeout),
      );

      if (result is int) {
        return result;
      }
      // Handle potential long/double from native
      if (result is num) {
        return result.toInt();
      }
      return -1;
    } catch (_) {
      return -1;
    }
  }

  /// A door check for the connect checklist, the sweep and the test point:
  /// how many milliseconds data took to flow through [server]'s link, or a
  /// [DoorCheckFailed] that says why it did not. [readDoor] says more.
  Future<int> checkDoor(
    Server server, {
    Duration timeout = const Duration(seconds: 10),
    Duration? coreTimeout,
  }) async {
    final reading = await readDoor(
      server,
      timeout: timeout,
      coreTimeout: coreTimeout,
    );
    if (reading.open) return reading.ms;
    throw DoorCheckFailed(reading.error ?? 'no answer');
  }

  /// [checkDoor], with how far the check got and how long the plain TCP
  /// connection took (see [readingOf]). A closed door is a reading, not an
  /// error.
  ///
  /// Uses the native `realPingDetail`, and falls back to [pingServer] where
  /// that is missing, so a failure there carries no reason, as before.
  /// [coreTimeout] and [timeout] are as for [pingServer]. [url] is what the
  /// check fetches through the link; the native side's own when null, as
  /// for every door check.
  Future<DoorOutcome> readDoor(
    Server server, {
    Duration timeout = const Duration(seconds: 10),
    Duration? coreTimeout,
    String? url,
  }) async {
    final began = CheckTimeline(began: DateTime.now());
    if (!_isValidConnectionUri(server.connectionUri)) {
      return DoorOutcome(
        ms: -1,
        error: 'link could not be read',
        timeline: began,
      );
    }
    final Object? result;
    try {
      result = await _counted(
        () => _channel
            .invokeMethod<dynamic>('realPingDetail', {
              ..._testArgs(server.connectionUri, coreTimeout),
              // The core's timed check, when the backend turned it on. The
              // native side falls back to the plain check when it cannot
              // run it, and says which one ran.
              if (ConnectionData.current.timedChecks) 'timed': true,
              'url': ?url,
            })
            .timeout(timeout),
      );
    } on MissingPluginException {
      final ms = await pingServer(
        server,
        timeout: timeout,
        coreTimeout: coreTimeout,
      );
      return ms >= 0
          ? DoorOutcome(ms: ms, timeline: began)
          : DoorOutcome(ms: -1, error: 'no answer', timeline: began);
    } on TimeoutException {
      return DoorOutcome(
        ms: -1,
        error: 'no answer in ${timeout.inMilliseconds} ms',
        timeline: began,
      );
    }
    if (result is Map) return readingOf(result, began: began);
    return DoorOutcome(ms: -1, error: 'no answer', timeline: began);
  }

  /// [readDoor] for a variant test that comes with its own core [config]
  /// (variant loop contract v2, section 1): the native `realPingConfig`
  /// runs it through the same check, fetching [url], and answers with the
  /// same map. [coreTimeout] and [timeout] are as for [pingServer].
  ///
  /// Null when the check did not run: no native method for it on this
  /// platform, or a config the native side would not run. Nothing was
  /// dialled, so there is nothing to report.
  Future<DoorOutcome?> readConfig(
    Map<String, dynamic> config, {
    required String url,
    required Duration coreTimeout,
    required Duration timeout,
  }) async {
    final began = CheckTimeline(began: DateTime.now());
    final Object? result;
    try {
      result = await _counted(
        () => _channel
            .invokeMethod<dynamic>('realPingConfig', {
              'config': jsonEncode(config),
              'url': url,
              'timeoutMs': coreTimeout.inMilliseconds,
              // Every test's core carries the app's split, as in
              // [_testArgs].
              'splitter': TlsFragment.doorSpec ?? TlsFragment.spec,
              if (ConnectionData.current.timedChecks) 'timed': true,
            })
            .timeout(timeout),
      );
    } on MissingPluginException {
      return null;
    } on TimeoutException {
      return DoorOutcome(
        ms: -1,
        error: 'no answer in ${timeout.inMilliseconds} ms',
        timeline: began,
      );
    }
    if (result is! Map || result['refused'] == true) return null;
    return readingOf(result, began: began);
  }

  /// A [DoorOutcome] from the map the native `realPingDetail` returns.
  ///
  /// The core's check says only that data flowed or did not. Beside it the
  /// phone opens a plain TCP connection to the door's address (DoorCheck on
  /// Android), which gives the two things read here:
  ///
  /// * `tcp_ms`: how long that connection took, when it connected. On an
  ///   open door the native side gives it only when it was already in.
  /// * `phase`: "ok" when data flowed; "tcp" when the address took no TCP
  ///   connection; "tls" when it did, or was not measured, and the core's
  ///   error names the handshake (a TLS alert, a certificate, x509). Null
  ///   otherwise: after "tcp ok" an "EOF" or "no answer" can be a cut
  ///   handshake or a silent server, and the plain check does not say which.
  ///
  /// A timed check (`timed` true in the map, Fortivacore.checkDoorTimed on
  /// Android) says more, from the sockets the core opened to the door: the
  /// connect time, the first byte back, the reply, bytes each way
  /// ([CheckTimeline]), and its own `phase`: "tcp", "tls", "proxy" (the
  /// handshake was answered, no reply came) or "late" (the reply came after
  /// the wait). Its phase is taken over the guess above. A plain check
  /// exposes none of it.
  static DoorOutcome readingOf(
    Map<dynamic, dynamic> result, {
    CheckTimeline? began,
  }) {
    final ms = result['ms'];
    final tcp = result['tcp'];
    final tcpMs = result['tcpMs'];
    final connectMs = tcp == 'ok' && tcpMs is num && tcpMs >= 0
        ? tcpMs.toInt()
        : null;
    final timed = result['timed'] == true;
    final timeline = began == null
        ? null
        : (timed ? began.withCore(result) : began);
    if (ms is num && ms >= 0) {
      return DoorOutcome(
        ms: ms.toInt(),
        tcpMs: connectMs,
        phase: 'ok',
        timeline: timeline,
      );
    }
    final error = result['error'];
    final corePhase = result['phase'];
    final String? phase;
    if (timed && corePhase is String && _corePhases.contains(corePhase)) {
      phase = corePhase;
    } else if (tcp is String && tcp.isNotEmpty && tcp != 'ok') {
      phase = 'tcp';
    } else if (error is String && _handshakeWords.hasMatch(error)) {
      phase = 'tls';
    } else {
      phase = null;
    }
    return DoorOutcome(
      ms: -1,
      error: DoorCheckFailed.fromNative(result).reason,
      tcpMs: connectMs,
      phase: phase,
      timeline: timeline,
    );
  }

  /// The words a timed check uses for how far a failed check got.
  static const _corePhases = {'tcp', 'tls', 'proxy', 'late'};

  /// Words the core uses only when the TLS handshake failed.
  static final _handshakeWords = RegExp(
    r'\btls:|handshake|x509|certificate',
    caseSensitive: false,
  );

  /// Ping all servers sequentially with cancellation support
  ///
  /// Runs pings one at a time, which fills the list in order. Running
  /// several at once used to fail some of them with "io: read/write on
  /// closed pipe": the native cores share one dialer per process, and a TLS
  /// link's test found no splitter in a newer Reality test's core. Since
  /// 2026-10-12 every test's core carries one (see [_testArgs]).
  ///
  /// Calls [onResult] for each server as its ping completes,
  /// enabling incremental UI updates.
  ///
  /// Returns `true` if cancelled early, `false` if completed normally.
  Future<({Map<String, int> results, bool cancelled})> pingAllServers(
    List<Server> servers, {
    void Function(String serverId, int latencyMs)? onResult,
    void Function(String serverId)? onBeforePing,
  }) async {
    _cancelCompleter = Completer<void>();
    final results = <String, int>{};

    // One at a time, see above.
    for (final server in servers) {
      // Check cancellation before starting next ping
      if (_cancelCompleter!.isCompleted) {
        return (results: results, cancelled: true);
      }

      // Notify caller that this server is about to be pinged
      onBeforePing?.call(server.id);

      // Yield to the event loop so Flutter can paint the spinner
      await Future.delayed(const Duration(milliseconds: 50));

      if (_cancelCompleter!.isCompleted) {
        return (results: results, cancelled: true);
      }

      final latency = await pingServer(server);

      // Check cancellation after ping completes
      if (_cancelCompleter!.isCompleted) {
        results[server.id] = latency;
        onResult?.call(server.id, latency);
        return (results: results, cancelled: true);
      }

      results[server.id] = latency;
      onResult?.call(server.id, latency);

      // Yield so the UI can paint the result before moving to next server
      await Future.delayed(const Duration(milliseconds: 50));
    }

    _cancelCompleter = null;
    return (results: results, cancelled: false);
  }
}
