import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/api_client.dart';
import '../api/config_service.dart';
import '../api/device_service.dart';
import '../data/models/probe_candidate.dart';
import '../data/models/server.dart';
import '../utils/vless_link.dart';
import 'ping_service.dart';
import 'vpn_event_reporter.dart';

/// Measures links an operator wants tested, from the network this phone is on.
///
/// The one reading the backend cannot take for itself. Its own probes sit
/// outside Iran, so they can only say a server is up; whether a link survives
/// the filtering between an Iranian carrier and that server is a fact only a
/// phone in Iran can establish. This is how it is asked.
///
/// What it does not do matters as much as what it does. A candidate is never
/// connected through, never added to the server list, and never shown to the
/// user; it is dialled by the core's proxy-only delay test, which starts a
/// temporary core, fetches a tiny page through the link and tears it down. No
/// VPN permission, no tunnel, and the user's own connection untouched.
///
/// The cost to the user is a few seconds of radio and a disclosure of their
/// address to whoever runs the far end, so the run is fenced in on four
/// sides: the diagnostics setting must be on, the tunnel must be down, no
/// other core work may be in flight, and it happens at most once every
/// [interval]. Anything less and a launch turns into a measurement session.
typedef CandidateProbe = Future<int> Function(Server link);
typedef CandidateResultSender =
    Future<void> Function(
      String deviceId,
      List<Map<String, dynamic>> probes,
      bool viaTunnel,
    );

class CandidateProber {
  CandidateProber({
    CandidateSource? source,
    CandidateProbe? probe,
    CandidateResultSender? send,
    BackendPost? post,
    DateTime Function()? clock,
    Future<String> Function()? deviceId,
    Future<String> Function()? appVersion,
    String? platform,
    this.probeTimeout = const Duration(seconds: 8),
    this.interval = const Duration(hours: 6),
  }) : _source = source ?? ConfigService(),
       _probe = probe ?? ((link) => _defaultProbe(link, probeTimeout)),
       _send = send ?? _postResults(post ?? _apiPost, clock ?? DateTime.now),
       _deviceId = deviceId ?? (() => DeviceService().getDeviceId()),
       _appVersion = appVersion ?? (() => DeviceService().getAppVersion()),
       _platform = platform ?? DeviceService().platform;

  /// When this phone last ran a batch, so a relaunch does not re-run it.
  static const lastRunKey = 'fortiva_candidate_probe_last_run';

  /// Never test more than this in one run, whatever the backend offers. It
  /// caps a run at eight core starts even if a candidate list arrives long,
  /// and the backend takes at most eight results in one report. It was
  /// three, and the rest of a longer list was never tested on that phone.
  static const maxPerRun = 8;

  final CandidateSource _source;
  final CandidateProbe _probe;
  final CandidateResultSender _send;
  final Future<String> Function() _deviceId;
  final Future<String> Function() _appVersion;
  final String _platform;

  /// How long one candidate gets before it is called blocked. The core
  /// waits this long for data, and the app a little longer for the core's
  /// answer ([answerSlack]).
  final Duration probeTimeout;

  /// The floor between runs on one device.
  final Duration interval;

  bool _running = false;

  /// Whether a run is going now, in any instance. The variant tests wait
  /// for it (VariantTester): two background tests side by side can dial
  /// with each other's split.
  static bool get anyRunning => _runs > 0;
  static int _runs = 0;

  /// How much longer than the core's wait the app waits for its answer, so
  /// the core gives up first and the app reads its answer. The variant
  /// tests wait the same.
  static const answerSlack = Duration(seconds: 2);

  /// The native test of [link] with the core waiting [wait] for data. It
  /// used to wait its own 3 s while this side waited 8, so a candidate that
  /// needed 4 s was reported as "no data within 8s".
  static Future<int> _defaultProbe(Server link, Duration wait) => PingService()
      .pingServer(link, coreTimeout: wait, timeout: wait + answerSlack);

  static Future<void> _apiPost(String path, Map<String, dynamic> body) async {
    await ApiClient().post(path, body: body);
  }

  /// The default [CandidateResultSender]. [clock] is read for `sent_at`
  /// only; the run's `client_ts` is still the phone's own time.
  static CandidateResultSender _postResults(
    BackendPost post,
    DateTime Function() clock,
  ) =>
      (deviceId, probes, viaTunnel) =>
          post('/api/v1/devices/$deviceId/candidate-probes', {
            'probes': probes,
            'via_tunnel': viaTunnel,
            // The server compares this with its own clock and corrects
            // each client_ts by the gap, because some phones' clocks are
            // hours or days off.
            'sent_at': clock().toUtc().toIso8601String(),
          });

  /// Run a batch if this is a moment when running one is free of cost.
  ///
  /// [idle] is the caller's answer to "is the core doing anything else": a
  /// tunnel up or coming up, or a ping sweep in flight. False and nothing
  /// happens. A batch started beside a connect's checks used to fail some
  /// of both with closed-pipe errors, because the cores of tests share one
  /// dialer and a newer core could lack the splitter a TLS test dials
  /// through. Since 2026-10-12 every test's core carries one (PingService),
  /// and a batch still waits so it takes no threads from a connect. The
  /// question belongs to the caller, which can see the VPN and the ping
  /// service; this class only refuses to guess it.
  ///
  /// Never throws. A candidate measurement is the least important thing the
  /// app does, and nothing about it is worth surfacing to a user.
  Future<void> maybeRun({required bool idle}) async {
    if (_running || !idle) return;
    _running = true;
    _runs++;
    try {
      final prefs = await SharedPreferences.getInstance();

      // The same switch that gates every other report. Off means the user
      // asked not to be measured, and that covers this before anything else.
      if (prefs.getBool(VpnEventReporter.sharePrefKey) == false) return;

      final last = prefs.getInt(lastRunKey);
      if (last != null) {
        final since = DateTime.now().difference(
          DateTime.fromMillisecondsSinceEpoch(last),
        );
        // Negative means the clock moved back; treated as due rather than
        // waiting out an interval that may never elapse.
        if (!since.isNegative && since < interval) return;
      }

      final candidates = await _source.getProbeCandidates();

      // Stamped even when there is nothing to test, which is the usual case.
      // Otherwise every launch spends a request asking, and the list is
      // empty for weeks at a time.
      await prefs.setInt(lastRunKey, DateTime.now().millisecondsSinceEpoch);
      if (candidates.isEmpty) return;

      final results = <Map<String, dynamic>>[];
      final appVersion = await _appVersion();
      final now = DateTime.now().toUtc().toIso8601String();

      // The ones the test can dial, so a link it cannot does not take the
      // place of one it can.
      final testable = [
        for (final candidate in candidates)
          if (_asLink(candidate) case final link?) (candidate, link),
      ].take(maxPerRun);

      // Sequential, for the same reason pingAllServers is: two cores at
      // once produce closed-pipe errors rather than faster answers.
      for (final (candidate, link) in testable) {
        final ms = await _probe(link);
        final ok = ms >= 0;
        results.add(<String, dynamic>{
          'candidate_id': candidate.id,
          'ok': ok,
          if (ok) 'ms': ms,
          // A failed delay test reports no reason of its own, so the honest
          // error is that nothing came back inside the budget. The backend
          // reads a blocked link off `ok`, not off this.
          if (!ok) 'error': 'no data within ${probeTimeout.inSeconds}s',
          'app_version': appVersion,
          'platform': _platform,
          'client_ts': now,
        });
      }
      if (results.isEmpty) return;

      // Always false: this only runs with the tunnel down, and it is the
      // whole value of the reading. Claimed via_tunnel true, the backend
      // would refuse to attribute the result to a carrier and the run would
      // have measured nothing.
      await _send(await _deviceId(), results, false);
    } catch (e) {
      debugPrint('CandidateProber: could not measure candidates: $e');
    } finally {
      _running = false;
      _runs--;
    }
  }

  /// A candidate as the thing the delay test takes.
  ///
  /// Deliberately local and deliberately not returned anywhere: this is the
  /// only place a candidate becomes a [Server], it lives for one call, and
  /// the id is prefixed so a leak into a list would be obvious rather than
  /// look like a real server.
  ///
  /// Null for a link the test would refuse without dialling, of a kind the
  /// core cannot dial or with allowInsecure ([PingService.canTest]): it
  /// would be reported as blocked without having been tried.
  Server? _asLink(ProbeCandidate candidate) {
    try {
      if (!PingService.canTest(candidate.uri)) return null;
      final host = VlessLink.host(candidate.uri);
      if (host.isEmpty) return null;
      return Server(
        id: 'candidate-${candidate.id}',
        name: candidate.label,
        country: '',
        city: '',
        connectionUri: candidate.uri,
        flagEmoji: '',
      );
    } catch (_) {
      return null;
    }
  }
}
