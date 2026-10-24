import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/api_client.dart';
import '../api/device_service.dart';
import '../api/server_clock.dart';
import '../core/state/dedicated_state.dart';
import '../data/models/server.dart';
import '../data/models/variant_test.dart';
import '../utils/tls_fragment.dart';
import 'candidate_prober.dart';
import 'community_checks.dart';
import 'connect_diagnostics.dart';
import 'path_finder.dart';
import 'ping_service.dart';
import 'tunnel_channels.dart';
import 'vpn_event_reporter.dart';

/// What one variant check dials: the backend's core [config], or [link]
/// when the backend sent no config. [url] is what the check fetches through
/// it and [wait] how long the core waits for data, both the backend's.
class VariantDial {
  const VariantDial({
    required this.test,
    required this.url,
    required this.wait,
    this.config,
    this.link,
  });

  final VariantTest test;
  final Map<String, dynamic>? config;
  final Server? link;
  final String url;
  final Duration wait;
}

/// Checks one variant. Null when the check did not run, so there is nothing
/// to report. Never throws for a closed variant.
typedef VariantCheck = Future<DoorOutcome?> Function(VariantDial dial);

/// Sends one report of variant tests.
typedef VariantResultSender =
    Future<void> Function(
      String deviceId,
      List<Map<String, dynamic>> results,
      bool viaTunnel,
    );

/// Runs this phone's variant tests: variants of its own doors that the
/// backend's learner wants measured from the phone's network.
///
/// The /configs/dedicated answer carries them as `variant_tests` only while
/// the backend's VARIANT_TESTS switch is on and this build qualifies, with
/// `variant_test_params` saying how to run them (variant loop contract v2,
/// section 1). An answer without tests leaves this with nothing to do: it
/// reads no setting, sends no request and dials nothing. An answer whose
/// parameters are missing or unusable runs no test at all.
///
/// Each test comes with the core config the backend wants checked, which
/// the native door check runs as written (PingService.readConfig). A test
/// from a backend that sends no config is dialled from its link
/// (PingService.readDoor). Either way it is the timed check the door checks
/// use, in a core of its own that is torn down after it. A test is never
/// connected through, listed or shown. It needs no VPN permission and
/// leaves the user's own connection alone. The check is fenced in:
///
/// * the diagnostics setting must be on;
/// * nothing the user waits on may be under way ([idle]), with no other
///   native test running and no candidate run, and, when the backend says
///   so, the tunnel must be down;
/// * the phone must have a network, and a control site must answer, or a
///   phone that simply lost its connection would report every variant as
///   blocked;
/// * one test at a time, in the order sent, and no more in one run than
///   the backend says, with at least the backend's gap between runs. A
///   test that runs beside another can dial with the other's split
///   (TestLink.config on Android), so a result during which another test
///   started is not sent, and the test waits for a later quiet moment;
/// * once per hand-out. A test whose deadline has passed is dropped
///   unchecked.
///
/// Every count, wait, gap and address comes from the backend. The app has
/// none of its own for these tests.
///
/// While the app is out of sight, ReportSchedule's timer is stopped. When
/// the latest answer's parameters carry `background_minutes`, a timer of
/// this class tries the tests that often until the app is back ([hidden],
/// [shown]), behind every fence above. An answer without tests stops it.
/// With the key, a check that took much longer than its waits allow was
/// cut short by a pause, such as the phone sleeping. It is not sent, and
/// the test waits for a later run. Without the key, as from every backend
/// before it, nothing here changes.
///
/// The results go to POST /api/v1/devices/{device_id}/variant-results with
/// the carrier name and network type the door checks send, and no address.
/// One report holds the results of one answer's tests, never more, so it
/// stays within what the backend takes in one report. Nothing is kept on
/// the phone: a report that cannot be sent is tried once more and then
/// dropped, as for CommunityChecks.
class VariantTester {
  VariantTester(
    this._dedicated, {
    required bool Function() idle,
    bool Function()? tunnelUp,
    bool Function()? throughTunnel,
    VariantCheck? check,
    InternetCheck? internet,
    VariantResultSender? send,
    BackendPost? post,
    DateTime Function()? clock,
    Future<String> Function()? deviceId,
    Future<String> Function()? appVersion,
    NetworkTypeProbe? networkType,
    Future<String?> Function()? carrier,
    int Function()? checksRunning,
    int Function()? checksStarted,
  }) : _idle = idle,
       _tunnelUp = tunnelUp ?? (() => true),
       _throughTunnel = throughTunnel ?? (() => true),
       _check = check ?? _defaultCheck,
       _internet = internet ?? _defaultInternet,
       _send = send ?? _postResults(post ?? _apiPost, clock ?? DateTime.now),
       _clock = clock ?? DateTime.now,
       _deviceId = deviceId ?? (() => DeviceService().getDeviceId()),
       _appVersion = appVersion ?? (() => DeviceService().getAppVersion()),
       _networkType = networkType ?? VpnEventReporter.currentNetworkType,
       _carrier = carrier ?? _defaultCarrier,
       _checksRunning = checksRunning ?? (() => PingService.running),
       _checksStarted = checksStarted ?? (() => PingService.started) {
    _dedicated.addListener(_heard);
  }

  /// The longest error kept, as for a door check.
  static const _maxError = 200;

  final DedicatedState _dedicated;

  /// Whether nothing is under way that a background test would get in the
  /// way of: no tunnel coming up or going down, no connect, no list being
  /// tested, no size probe. Asked again before every test.
  final bool Function() _idle;

  /// Whether the tunnel is up. Asked when the backend runs tests only with
  /// the tunnel down. Null counts as up.
  final bool Function() _tunnelUp;

  /// Whether the app's own requests go through the tunnel right now. A
  /// report sent through our tunnel cannot be placed on a carrier, so then
  /// nothing is sent. Null counts as yes.
  final bool Function() _throughTunnel;

  final VariantCheck _check;
  final InternetCheck _internet;
  final VariantResultSender _send;
  final DateTime Function() _clock;
  final Future<String> Function() _deviceId;
  final Future<String> Function() _appVersion;
  final NetworkTypeProbe _networkType;
  final Future<String?> Function() _carrier;
  final int Function() _checksRunning;
  final int Function() _checksStarted;

  /// The tests not run yet, by assignment id, in the order they came. Each
  /// carries the number of the answer it came in, so a report never holds
  /// more results than one answer held tests.
  final Map<int, ({VariantTest test, int answer})> _pending = {};

  /// Every assignment id taken in, with its deadline, so a test is never
  /// taken in twice. Forgotten once the deadline has passed, when the test
  /// is dropped anyway.
  final Map<int, DateTime> _seen = {};

  /// How tests run: the parameters of the latest answer that carried
  /// tests. Null runs none.
  VariantTestParams? _params;

  /// When the last run started its first test.
  DateTime? _lastRun;

  /// The DedicatedState generation the tests in [_pending] came from.
  int? _generation;
  int _answers = 0;
  bool _running = false;

  /// Whether the app is out of sight ([hidden]).
  bool _hidden = false;
  bool _disposed = false;

  /// How often the latest answer asks the tests to be tried while the app
  /// is out of sight. Unlike [_params], an answer without tests clears it,
  /// as while the backend's tests are off, so the timer stops while the
  /// tests already held still wait for an answer or a network change.
  Duration? _askedEvery;

  /// Tries the tests every [_backgroundEvery] while the app is out of
  /// sight and the latest answer asks for it.
  Timer? _background;
  Duration? _backgroundEvery;

  /// Whether a run is going now.
  bool get running => _running;

  /// How many tests wait to be run.
  @visibleForTesting
  int get pendingCount => _pending.length;

  /// Whether the background timer is running.
  @visibleForTesting
  bool get backgroundTimer => _background != null;

  /// Stop following the device's answers, and stop the background timer.
  void dispose() {
    _disposed = true;
    _dedicated.removeListener(_heard);
    _syncBackground();
  }

  void _heard() => unawaited(maybeRun());

  /// The app went out of sight. Starts the background timer when the
  /// parameters carry `background_minutes`.
  void hidden() {
    _hidden = true;
    _syncBackground();
  }

  /// The app is in front again, where ReportSchedule's tries take over.
  /// Stops the background timer.
  void shown() {
    _hidden = false;
    _syncBackground();
  }

  /// Start, keep or stop the background timer to match the app and the
  /// latest answer. The timer only asks [maybeRun], so every fence still
  /// applies.
  void _syncBackground() {
    final every = _hidden && !_disposed ? _askedEvery : null;
    if (every == _backgroundEvery) return;
    _background?.cancel();
    _background = every == null
        ? null
        : Timer.periodic(every, (_) => unawaited(maybeRun()));
    _backgroundEvery = every;
  }

  static Future<void> _apiPost(String path, Map<String, dynamic> body) async {
    await ApiClient().post(path, body: body);
  }

  /// The default [VariantResultSender]. [clock] is read for `sent_at` only;
  /// each result's `client_ts` is still when its test ended.
  static VariantResultSender _postResults(
    BackendPost post,
    DateTime Function() clock,
  ) =>
      (deviceId, results, viaTunnel) =>
          post('/api/v1/devices/$deviceId/variant-results', {
            'results': results,
            'via_tunnel': viaTunnel,
            // The server compares this with its own clock and corrects
            // each client_ts by the gap, because some phones' clocks are
            // hours or days off.
            'sent_at': clock().toUtc().toIso8601String(),
          });

  /// The timed check of the door checks, with the backend's wait as the
  /// core's and the candidate checks' margin on top, so the core gives up
  /// first and the app reads its answer.
  static Future<DoorOutcome?> _defaultCheck(VariantDial dial) {
    final timeout = dial.wait + CandidateProber.answerSlack;
    final config = dial.config;
    if (config != null) {
      return PingService().readConfig(
        config,
        url: dial.url,
        coreTimeout: dial.wait,
        timeout: timeout,
      );
    }
    return PingService().readDoor(
      dial.link!,
      url: dial.url,
      coreTimeout: dial.wait,
      timeout: timeout,
    );
  }

  static Future<bool> _defaultInternet() async {
    final r = await ConnectDiagnostics(
      channel: TunnelChannels.method,
    ).controlCheck();
    return r['control'] == 'ok';
  }

  static Future<String?> _defaultCarrier() async {
    try {
      final report = await ConnectDiagnostics(
        channel: TunnelChannels.method,
      ).platformReport();
      final c = report['carrier'] ?? report['sim_carrier'];
      return c is String && c.isNotEmpty ? c : null;
    } catch (_) {
      return null;
    }
  }

  /// The backend's time now, for its deadlines (ServerClock.notBefore).
  DateTime _now() => ServerClock.notBefore(_clock());

  /// Take in the tests of the device's latest answer that are new, and
  /// drop those whose deadline has passed. An account deleted since the
  /// last look takes every waiting test with it. An answer whose
  /// parameters cannot be used takes none in, and stops the ones that wait.
  void _take() {
    final generation = _dedicated.generation;
    if (generation != _generation) {
      _pending.clear();
      _seen.clear();
      _params = null;
      _lastRun = null;
      _generation = generation;
    }
    final now = _now();
    _seen.removeWhere((_, deadline) => !deadline.isAfter(now));
    _pending.removeWhere((_, p) => !p.test.deadline.isAfter(now));
    final tests = _dedicated.variantTests;
    _askedEvery = tests.isEmpty
        ? null
        : _dedicated.variantTestParams?.backgroundEvery;
    if (tests.isEmpty) return;
    _params = _dedicated.variantTestParams;
    if (_params == null) return;
    int? answer;
    for (final test in tests) {
      if (_seen.containsKey(test.assignmentId)) continue;
      if (!test.deadline.isAfter(now)) continue;
      answer ??= ++_answers;
      _seen[test.assignmentId] = test.deadline;
      _pending[test.assignmentId] = (test: test, answer: answer);
    }
  }

  /// Whether a test may start now.
  bool _free(VariantTestParams params) =>
      _idle() &&
      !(params.onlyWhenTunnelDown && _tunnelUp()) &&
      _checksRunning() == 0 &&
      !CandidateProber.anyRunning;

  /// Whether the backend's gap since the last run has passed. A clock
  /// moved back counts as passed.
  bool _gapPassed(VariantTestParams params) {
    final last = _lastRun;
    if (last == null) return true;
    final since = _clock().difference(last);
    return since.isNegative || since >= params.minGap;
  }

  /// Run the waiting tests if this is a moment when running them costs the
  /// user nothing, and report what they found. Called when the device's
  /// answer changes, with every try of the waiting reports, and by the
  /// background timer. Never throws, and never runs twice at once.
  Future<void> maybeRun() async {
    _take();
    // A new answer without tests or without background_minutes, or a new
    // generation, stops the background timer.
    _syncBackground();
    final params = _params;
    if (_running || _pending.isEmpty || params == null) return;
    if (!_gapPassed(params) || !_free(params)) return;
    _running = true;
    try {
      // The same switch that gates every other report. Off means the user
      // asked not to be measured.
      if (!await _sharing()) return;
      // No network, or none the platform can name: every check would fail
      // at once and read as a blocked variant.
      if (await _networkType() == null) return;
      if (!await _internet()) return;

      final generation = _generation;
      final done = <({int answer, Map<String, dynamic> row})>[];
      final appVersion = await _appVersion();
      var started = 0;
      for (final id in _pending.keys.toList()) {
        if (started >= params.maxPerRun) break;
        if (!_free(params) || _dedicated.generation != generation) break;
        final pending = _pending[id];
        if (pending == null) continue;
        final test = pending.test;
        if (!test.deadline.isAfter(_now())) {
          _pending.remove(id);
          continue;
        }
        final dial = dialOf(test, params);
        if (dial == null) {
          // Never dialled, so never reported: a result would be about
          // settings the backend did not write.
          debugPrint('VariantTester: ${test.variantKey} cannot be checked');
          _pending.remove(id);
          continue;
        }
        final before = _checksStarted();
        final began = _clock();
        if (started == 0) _lastRun = began;
        started++;
        final reading = await _check(dial);
        final ended = _clock();
        // More than this test started while it ran: another check ran
        // beside it, and either may have dialled with the other's split.
        // The test stays for a later quiet moment.
        if (_checksStarted() - before > 1) break;
        // Only while the parameters carry background_minutes: a check that
        // took more than twice its waits was paused, by a phone asleep or
        // an app Android froze, and its result says nothing about the
        // variant. The test stays for a later run.
        if (params.backgroundEvery != null &&
            ended.difference(began) >
                dial.wait * 2 + CandidateProber.answerSlack) {
          debugPrint('VariantTester: ${test.variantKey} was paused');
          break;
        }
        _pending.remove(id);
        if (reading == null) {
          debugPrint('VariantTester: ${test.variantKey} did not run');
          continue;
        }
        debugPrint(
          'VariantTester: ${test.variantKey} on ${test.door}: '
          '${reading.open ? 'open' : (reading.phase ?? 'closed')}',
        );
        done.add((
          answer: pending.answer,
          row: row(
            test,
            reading,
            began: began,
            ended: ended,
            appVersion: appVersion,
          ),
        ));
      }
      if (done.isEmpty) return;
      // The account was deleted while the tests ran.
      if (_dedicated.generation != generation) return;

      // Read once for the run, as a door-check batch reads them: the tests
      // ran within seconds of each other on one network.
      final networkType = await _networkType();
      final carrier = await _carrier();
      final deviceId = await _deviceId();
      final answers = <int, List<Map<String, dynamic>>>{};
      for (final d in done) {
        (answers[d.answer] ??= []).add({
          ...d.row,
          'carrier': ?carrier,
          'network_type': ?networkType,
        });
      }
      for (final results in answers.values) {
        // Read again before every report, as for door checks: a switch
        // turned off, or a tunnel the app's requests now go through,
        // stops the rest.
        if (!await _sharing() || _throughTunnel()) return;
        if (_dedicated.generation != generation) return;
        if (!await _deliver(deviceId, results)) return;
      }
    } catch (e) {
      debugPrint('VariantTester: run failed: $e');
    } finally {
      _running = false;
    }
  }

  /// What the check of [test] dials under [params], or null for a test the
  /// app would not dial as sent.
  ///
  /// A test with a config is dialled with it. One without is dialled from
  /// its link ([linkOf]). [android] is for tests.
  @visibleForTesting
  static VariantDial? dialOf(
    VariantTest test,
    VariantTestParams params, {
    bool? android,
  }) {
    final config = test.config;
    if (config != null) {
      return VariantDial(
        test: test,
        config: config,
        url: params.testUrl,
        wait: params.timeout,
      );
    }
    final link = linkOf(test, android: android);
    if (link == null) return null;
    return VariantDial(
      test: test,
      link: link,
      url: params.testUrl,
      wait: params.timeout,
    );
  }

  /// The link of a test the backend sent without a config, as the thing
  /// the timed check takes, or null for one the app would not dial as
  /// written.
  ///
  /// Null for a link of a kind the core cannot dial or with allowInsecure
  /// ([PingService.canTest]), and for a TLS link the app would add its own
  /// hello split to ([TlsFragment.apply]): the backend writes a `fragment`
  /// value into every TLS variant, `off` for no split, and a link without
  /// one would be checked with a split the variant does not have.
  /// [android] is for tests; the check decides by the platform.
  ///
  /// Local and short-lived, as CandidateProber's: the id is prefixed so a
  /// leak into a list would be obvious rather than look like a server.
  @visibleForTesting
  static Server? linkOf(VariantTest test, {bool? android}) {
    try {
      if (test.uri.isEmpty || !PingService.canTest(test.uri)) return null;
      if (TlsFragment.apply(test.uri, android: android) != test.uri) {
        return null;
      }
      return Server(
        id: 'variant-${test.assignmentId}',
        name: test.variantKey,
        country: '',
        city: '',
        connectionUri: test.uri,
        flagEmoji: '',
      );
    } catch (_) {
      return null;
    }
  }

  /// The result the backend stores for [test], without the carrier and
  /// network type, which the run adds. The fields mean what they mean on a
  /// door check: `ms` is the round trip of a check that passed and how long
  /// one that failed took to fail, `began_ms` how long before `client_ts`
  /// the check began, and `client_ts` when it ended.
  @visibleForTesting
  static Map<String, dynamic> row(
    VariantTest test,
    DoorOutcome reading, {
    required DateTime began,
    required DateTime ended,
    required String appVersion,
  }) {
    final ok = reading.open;
    final took = ended.difference(began).inMilliseconds;
    final error = reading.error;
    return {
      'assignment_id': test.assignmentId,
      'ok': ok,
      'app_version': appVersion,
      'phase': ?reading.phase,
      if (ok) 'ms': reading.ms else if (took >= 0) 'ms': took,
      if (!ok && error != null && error.isNotEmpty)
        'error': error.length > _maxError
            ? error.substring(0, _maxError)
            : error,
      'tcp_ms': ?reading.tcpMs,
      ...VpnEventReporter.timelineKeys(
        reading.timeline ?? CheckTimeline(began: began),
        ended,
      ),
      'client_ts': ended.toUtc().toIso8601String(),
    };
  }

  /// Send one report. True when it went. One more try after a failure that
  /// a second try can get past (CommunityChecks.worthAnotherTry); none
  /// after one it cannot, such as a 404 from a backend without the
  /// endpoint.
  Future<bool> _deliver(
    String deviceId,
    List<Map<String, dynamic>> results,
  ) async {
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        // Always false: nothing is sent while the app's requests go
        // through the tunnel (see [_throughTunnel]).
        await _send(deviceId, results, false);
        return true;
      } on ApiException catch (e) {
        debugPrint('VariantTester: backend answered $e');
        if (!CommunityChecks.worthAnotherTry(e)) return false;
      } catch (e) {
        debugPrint('VariantTester: could not send: $e');
      }
    }
    return false;
  }

  /// Whether the user lets the app send reports. Unset means yes, as for
  /// every other report. Read again before every upload.
  static Future<bool> _sharing() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.get(VpnEventReporter.sharePrefKey) != false;
  }
}
