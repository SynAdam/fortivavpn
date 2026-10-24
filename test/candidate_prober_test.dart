import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/api/config_service.dart';
import 'package:fortiva_vpn/data/models/probe_candidate.dart';
import 'package:fortiva_vpn/data/models/server.dart';
import 'package:fortiva_vpn/services/candidate_prober.dart';
import 'package:fortiva_vpn/services/vpn_event_reporter.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Measuring an operator's candidate links from this phone's network, and
/// the four fences that stop it happening at a bad moment.

class _FakeSource implements CandidateSource {
  _FakeSource(this.candidates, {this.throws = false});

  final List<ProbeCandidate> candidates;
  final bool throws;
  int calls = 0;

  @override
  Future<List<ProbeCandidate>> getProbeCandidates() async {
    calls++;
    if (throws) throw Exception('offline');
    return candidates;
  }
}

ProbeCandidate candidate(int id, {String host = 'panel.example.com'}) =>
    ProbeCandidate(
      id: id,
      uri:
          'vless://b831381d-6324-4d53-ad4f-8cda48b30811@$host:443'
          '?security=tls&type=ws&path=%2F699#CF-WS-TLS',
      label: 'candidate-$id',
    );

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  ({
    CandidateProber prober,
    _FakeSource source,
    List<Server> probed,
    List<List<Map<String, dynamic>>> sent,
    List<bool> viaTunnel,
  })
  build({
    List<ProbeCandidate> candidates = const [],
    int Function(Server link)? probe,
    bool sourceThrows = false,
    Duration interval = const Duration(hours: 6),
  }) {
    final source = _FakeSource(candidates, throws: sourceThrows);
    final probed = <Server>[];
    final sent = <List<Map<String, dynamic>>>[];
    final viaTunnel = <bool>[];
    final prober = CandidateProber(
      source: source,
      probe: (link) async {
        probed.add(link);
        return probe?.call(link) ?? 210;
      },
      send: (deviceId, probes, tunnel) async {
        sent.add(probes);
        viaTunnel.add(tunnel);
      },
      deviceId: () async => 'device-1',
      appVersion: () async => '1.6.0',
      platform: 'android',
      interval: interval,
    );
    return (
      prober: prober,
      source: source,
      probed: probed,
      sent: sent,
      viaTunnel: viaTunnel,
    );
  }

  // ── the fences ────────────────────────────────────────────────────────

  test('does nothing at all when the core is busy', () async {
    final t = build(candidates: [candidate(1)]);

    await t.prober.maybeRun(idle: false);

    // Not even the fetch: a request is cheap, but the point of the gate is
    // that a busy core is left alone.
    expect(t.source.calls, 0);
    expect(t.probed, isEmpty);
    expect(t.sent, isEmpty);
  });

  test('does nothing when the user turned diagnostics off', () async {
    SharedPreferences.setMockInitialValues({
      VpnEventReporter.sharePrefKey: false,
    });
    final t = build(candidates: [candidate(1)]);

    await t.prober.maybeRun(idle: true);

    expect(t.source.calls, 0);
    expect(t.sent, isEmpty);
  });

  test('runs once, then holds off for the interval', () async {
    final t = build(candidates: [candidate(1)]);

    await t.prober.maybeRun(idle: true);
    await t.prober.maybeRun(idle: true);

    expect(t.source.calls, 1);
    expect(t.sent, hasLength(1));
  });

  test('an empty list still starts the interval', () async {
    // Otherwise every launch spends a request asking, and the list is empty
    // for weeks at a time.
    final t = build(candidates: []);

    await t.prober.maybeRun(idle: true);
    await t.prober.maybeRun(idle: true);

    expect(t.source.calls, 1);
    expect(t.sent, isEmpty);
  });

  test('runs again once the interval has elapsed', () async {
    final t = build(candidates: [candidate(1)], interval: Duration.zero);

    await t.prober.maybeRun(idle: true);
    await t.prober.maybeRun(idle: true);

    expect(t.source.calls, 2);
  });

  test(
    'a clock that moved backwards does not park the prober forever',
    () async {
      SharedPreferences.setMockInitialValues({
        CandidateProber.lastRunKey: DateTime.now()
            .add(const Duration(days: 30))
            .millisecondsSinceEpoch,
      });
      final t = build(candidates: [candidate(1)]);

      await t.prober.maybeRun(idle: true);

      expect(t.source.calls, 1);
    },
  );

  // ── what it reports ───────────────────────────────────────────────────

  test('reports a link that carried data with its round trip', () async {
    final t = build(candidates: [candidate(7)], probe: (_) => 260);

    await t.prober.maybeRun(idle: true);

    expect(t.sent, hasLength(1));
    final probe = t.sent.single.single;
    expect(probe['candidate_id'], 7);
    expect(probe['ok'], isTrue);
    expect(probe['ms'], 260);
    expect(probe['platform'], 'android');
    expect(probe['app_version'], '1.6.0');
    expect(probe.containsKey('error'), isFalse);
  });

  test(
    'reports a link that carried nothing as not ok, with no latency',
    () async {
      final t = build(candidates: [candidate(7)], probe: (_) => -1);

      await t.prober.maybeRun(idle: true);

      final probe = t.sent.single.single;
      expect(probe['ok'], isFalse);
      expect(probe.containsKey('ms'), isFalse);
      expect(probe['error'], contains('no data'));
    },
  );

  test('always claims the report went around the tunnel', () async {
    // It only runs with the tunnel down, and claiming otherwise would make
    // the backend discard the carrier -- which is the whole reading.
    final t = build(candidates: [candidate(1)]);

    await t.prober.maybeRun(idle: true);

    expect(t.viaTunnel, [false]);
  });

  test('tests each candidate once, in order', () async {
    final t = build(
      candidates: [
        candidate(1, host: 'a.example.com'),
        candidate(2, host: 'b.example.com'),
      ],
    );

    await t.prober.maybeRun(idle: true);

    expect(t.probed.map((s) => s.id), ['candidate-1', 'candidate-2']);
    expect(t.sent.single.map((p) => p['candidate_id']), [1, 2]);
  });

  test('never tests more than the per-run cap, however many arrive', () async {
    final t = build(
      candidates: [
        for (var i = 1; i <= 10; i++) candidate(i, host: 'h$i.example.com'),
      ],
    );

    await t.prober.maybeRun(idle: true);

    expect(t.probed, hasLength(CandidateProber.maxPerRun));
  });

  test('a link the test cannot dial does not take a place', () async {
    final t = build(
      candidates: [
        const ProbeCandidate(id: 90, uri: 'hy2://pw@h.example:443', label: 'h'),
        const ProbeCandidate(
          id: 91,
          uri:
              'vless://b831381d-6324-4d53-ad4f-8cda48b30811@i.example:443'
              '?security=tls&allowInsecure=1#i',
          label: 'i',
        ),
        for (var i = 1; i <= 10; i++) candidate(i, host: 'h$i.example.com'),
      ],
    );

    await t.prober.maybeRun(idle: true);

    expect(t.probed.map((s) => s.id), [
      for (var i = 1; i <= 8; i++) 'candidate-$i',
    ]);
    expect(t.sent.single, hasLength(8));
  });

  test('tests vmess, trojan and ss candidates too', () async {
    final t = build(
      candidates: const [
        ProbeCandidate(
          id: 1,
          // {"add":"v.example","port":"443","id":"x","net":"ws"}
          uri:
              'vmess://eyJhZGQiOiJ2LmV4YW1wbGUiLCJwb3J0IjoiNDQzIiwiaWQiOiJ4Iiw'
              'ibmV0Ijoid3MifQ==',
          label: 'v',
        ),
        ProbeCandidate(id: 2, uri: 'trojan://pw@t.example:443#t', label: 't'),
        ProbeCandidate(
          id: 3,
          uri: 'ss://YWVzLTEyOC1nY206cHc@s.example:8388#s',
          label: 's',
        ),
      ],
    );

    await t.prober.maybeRun(idle: true);

    expect(t.sent.single.map((p) => p['candidate_id']), [1, 2, 3]);
  });

  test('the core waits as long as the candidate gets', () async {
    // It used to wait 3 s while the report said "no data within 8s".
    TestWidgetsFlutterBinding.ensureInitialized();
    const tunnel = MethodChannel('com.vpn.fortivavpn/tunnel');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final args = <Object?>[];
    messenger.setMockMethodCallHandler(tunnel, (call) async {
      args.add(call.arguments);
      return 640;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(tunnel, null));
    final sent = <Map<String, dynamic>>[];
    final prober = CandidateProber(
      source: _FakeSource([candidate(1)]),
      send: (_, probes, _) async => sent.addAll(probes),
      deviceId: () async => 'device-1',
      appVersion: () async => '1.6.14',
      platform: 'android',
    );

    await prober.maybeRun(idle: true);

    expect((args.single as Map)['timeoutMs'], 8000);
    expect(sent.single['ms'], 640);
  });

  test('a candidate is never marked dedicated or community', () async {
    // A leak into the server list would be a link a user could connect
    // through, which is the one thing this must not produce.
    final t = build(candidates: [candidate(1)]);

    await t.prober.maybeRun(idle: true);

    final link = t.probed.single;
    expect(link.isDedicated, isFalse);
    expect(link.isCommunity, isFalse);
    expect(link.id, startsWith('candidate-'));
  });

  test('the batch carries sent_at in UTC, read when it is sent', () async {
    // The server corrects client_ts by the gap between sent_at and its own
    // clock, so sent_at has to be the time the request left, not the time
    // the run started. Probing takes seconds, which the clock steps across.
    var now = DateTime.utc(2026, 9, 27, 10);
    final posted = <(String, Map<String, dynamic>)>[];
    final prober = CandidateProber(
      source: _FakeSource([candidate(1)]),
      probe: (_) async {
        now = now.add(const Duration(seconds: 8));
        return 210;
      },
      post: (path, body) async => posted.add((path, body)),
      clock: () => now,
      deviceId: () async => 'device-1',
      appVersion: () async => '1.6.1',
      platform: 'android',
    );

    await prober.maybeRun(idle: true);

    final (path, body) = posted.single;
    expect(path, '/api/v1/devices/device-1/candidate-probes');
    expect(body['probes'], hasLength(1));
    expect(body['via_tunnel'], isFalse);
    expect(body['sent_at'], '2026-09-27T10:00:08.000Z');
    expect(DateTime.parse(body['sent_at'] as String).isUtc, isTrue);
  });

  // ── failure is silent ─────────────────────────────────────────────────

  test('a fetch that fails is swallowed and sends nothing', () async {
    final t = build(sourceThrows: true);

    await t.prober.maybeRun(idle: true);

    expect(t.sent, isEmpty);
  });

  test('a malformed candidate is skipped, not reported', () async {
    final t = build(
      candidates: [
        const ProbeCandidate(id: 1, uri: 'not-a-link', label: 'broken'),
        candidate(2),
      ],
    );

    await t.prober.maybeRun(idle: true);

    expect(t.probed.map((s) => s.id), ['candidate-2']);
    expect(t.sent.single.map((p) => p['candidate_id']), [2]);
  });

  // ── the model ─────────────────────────────────────────────────────────

  test('a row without an id or uri is dropped rather than half-built', () {
    expect(ProbeCandidate.fromJson({'label': 'x'}), isNull);
    expect(ProbeCandidate.fromJson({'id': 1}), isNull);
    expect(ProbeCandidate.fromJson({'id': '1', 'uri': 'vless://x'}), isNull);
    expect(ProbeCandidate.fromJson({'id': 1, 'uri': ''}), isNull);
  });

  test('a row with no label falls back to one naming the id', () {
    final c = ProbeCandidate.fromJson({'id': 4, 'uri': 'vless://u@h:443'});
    expect(c!.label, 'candidate-4');
  });
}
