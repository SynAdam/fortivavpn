import 'dart:async';
import 'dart:convert';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/api/api_client.dart';
import 'package:fortiva_vpn/api/config_service.dart';
import 'package:fortiva_vpn/api/server_clock.dart';
import 'package:fortiva_vpn/core/state/dedicated_state.dart';
import 'package:fortiva_vpn/data/models/connection_data.dart';
import 'package:fortiva_vpn/data/models/probe_candidate.dart';
import 'package:fortiva_vpn/data/models/variant_test.dart';
import 'package:fortiva_vpn/services/candidate_prober.dart';
import 'package:fortiva_vpn/services/path_finder.dart';
import 'package:fortiva_vpn/services/variant_tests.dart';
import 'package:fortiva_vpn/services/vpn_event_reporter.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Variant tests: variants of this phone's own doors that the backend's
/// learner hands out in the /configs/dedicated answer, with the
/// parameters to run them by
/// (variant loop contract v2). The phone checks each one in the background
/// and reports what the timed check found to POST
/// /devices/{id}/variant-results.

const _uuid = 'b831381d-6324-4d53-ad4f-8cda48b30811';

/// A Reality variant's link: no hello split to write, so the app dials it
/// as sent.
const reality =
    'vless://$_uuid@203.0.113.7:8443?type=xhttp&security=reality'
    '&sni=www.samsung.com&pbk=key&fp=chrome&mode=packet-up#variant';

/// A TLS variant that says it sends the hello whole.
const tlsOff =
    'vless://$_uuid@198.51.100.215:443?type=ws&security=tls'
    '&sni=cdn.example.site&path=%2Fws&fragment=off#variant';

/// The same TLS link with no fragment value: the app would add its own
/// split to it.
const tlsBare =
    'vless://$_uuid@198.51.100.215:443?type=ws&security=tls'
    '&sni=cdn.example.site&path=%2Fws#variant';

/// The phone's own door, the one the variants are written onto.
const door =
    'vless://$_uuid@203.0.113.7:8443?type=xhttp&security=reality'
    '&sni=www.samsung.com&pbk=key#Row13';

final t0 = DateTime.utc(2026, 10, 18, 9);

/// A variant's core config as the backend writes it: the outbound tagged
/// proxy, then the splitter it dials through.
Map<String, dynamic> config({String address = '203.0.113.7'}) => {
  'outbounds': [
    {
      'tag': 'proxy',
      'protocol': 'vless',
      'settings': {
        'vnext': [
          {
            'address': address,
            'port': 8443,
            'users': [
              {'id': _uuid, 'encryption': 'none'},
            ],
          },
        ],
      },
      'streamSettings': {
        'network': 'xhttp',
        'security': 'reality',
        'realitySettings': {'serverName': 'www.samsung.com'},
        'sockopt': {'dialerProxy': 'fragment'},
      },
    },
    {
      'tag': 'fragment',
      'protocol': 'freedom',
      'settings': {
        'fragment': {
          'packets': 'tlshello',
          'length': '100-200',
          'interval': '10-20',
        },
      },
    },
  ],
};

/// `variant_test_params` as the backend sends them, with
/// `background_minutes` only when [backgroundMinutes] is given.
Map<String, dynamic> params({
  String url = 'https://cp.cloudflare.com/generate_204',
  int timeoutMs = 4000,
  int perRun = 8,
  int gapMinutes = 0,
  bool onlyDown = true,
  int? backgroundMinutes,
}) => {
  'test_url': url,
  'timeout_ms': timeoutMs,
  'max_per_run': perRun,
  'min_gap_minutes': gapMinutes,
  'only_when_tunnel_down': onlyDown,
  'background_minutes': ?backgroundMinutes,
};

/// One `variant_tests` row as the backend sends it (schemas.VariantTest),
/// with its config unless [withConfig] is false.
Map<String, dynamic> row(
  int id, {
  String uri = reality,
  String doorId = 'xhttp-reality',
  DateTime? deadline,
  bool withConfig = true,
}) => {
  'assignment_id': id,
  'variant_key': '$doorId#v=a3f1c2d0e5b$id',
  'server_id': 13,
  'door': doorId,
  'uri': uri,
  'deadline': (deadline ?? t0.add(const Duration(hours: 2))).toIso8601String(),
  // A v1 field the app no longer reads: the parameters' wait counts.
  'timeout_ms': 9999,
  if (withConfig) 'config': config(),
};

/// A /configs/dedicated answer, with [tests] as its `variant_tests` and
/// [testParams] as its `variant_test_params` when given.
Map<String, dynamic> answer({
  List<Map<String, dynamic>>? tests,
  Object? testParams,
}) => {
  'configs': [door],
  'paths': [
    {
      'server_id': 13,
      'inbound_id': 2,
      'door': 'xhttp-reality',
      'label': 'xhttp-reality',
      'uri': door,
      'preferred': true,
    },
  ],
  'quota': {
    'unlimited': false,
    'limit_bytes': 100,
    'used_bytes': 10,
    'remaining_bytes': 90,
    'blocked': false,
  },
  'google': {'linked': false},
  'variant_tests': ?tests,
  'variant_test_params': ?testParams,
};

/// Every field a result may carry (backend schemas.VariantResultIn). No
/// address among them.
const resultFields = {
  'assignment_id',
  'ok',
  'app_version',
  'phase',
  'ms',
  'error',
  'tcp_ms',
  'first_byte_ms',
  'bytes_out',
  'bytes_in',
  'began_ms',
  'boot_ms',
  'cold_ms',
  'dial_ms',
  'reply_ms',
  'dns_ms',
  'tls_ms',
  'dials',
  'dial_fails',
  'carrier',
  'network_type',
  'client_ts',
};

/// A tester on a real DedicatedState, with every outside read stubbed and
/// every check recorded.
class Rig {
  Rig() {
    dedicated = DedicatedState(
      now: () => now,
      fetch: ({bool? viaTunnel}) async => DedicatedConfigs.fromJson(next),
    );
    tester = VariantTester(
      dedicated,
      idle: () {
        idleAsked++;
        return idle;
      },
      tunnelUp: () => tunnelUp,
      throughTunnel: () => through,
      check: _check,
      internet: () async {
        internetAsked++;
        return internet;
      },
      send: (deviceId, results, viaTunnel) async {
        sends++;
        final failure = failures.isEmpty ? null : failures.removeAt(0);
        if (failure != null) throw failure;
        sent.add((device: deviceId, results: results, viaTunnel: viaTunnel));
      },
      clock: () => now,
      deviceId: () async => 'DEV-1',
      appVersion: () async => '1.12.0',
      networkType: () async {
        networkAsked++;
        return networkType;
      },
      carrier: () async => carrier,
      checksRunning: () => running,
      checksStarted: () => started,
    );
  }

  late final DedicatedState dedicated;
  late final VariantTester tester;

  DateTime now = t0;
  Map<String, dynamic> next = answer();

  /// Starts false, so an answer does not start a run before the test asks.
  bool idle = false;
  bool tunnelUp = false;
  bool through = false;
  bool internet = true;
  String? networkType = 'mobile';
  String? carrier = 'IR-MCI';

  /// The native tests the stand-in PingService counts.
  int running = 0;
  int started = 0;

  int idleAsked = 0;
  int internetAsked = 0;
  int networkAsked = 0;
  int sends = 0;

  /// Thrown by the next sends, in order.
  final failures = <Object>[];

  final dials = <VariantDial>[];
  final sent =
      <({String device, List<Map<String, dynamic>> results, bool viaTunnel})>[];

  /// What a check finds. Null: open in 240 ms, with a timed check's
  /// timeline. A function that returns null says the check did not run.
  DoorOutcome? Function(VariantDial dial)? outcome;

  /// Run inside each check, after it began.
  void Function(VariantDial dial)? during;

  Future<DoorOutcome?> _check(VariantDial dial) async {
    dials.add(dial);
    started++;
    running++;
    try {
      final began = now;
      during?.call(dial);
      now = now.add(const Duration(milliseconds: 900));
      if (outcome != null) return outcome!(dial);
      return DoorOutcome(
        ms: 240,
        tcpMs: 61,
        phase: 'ok',
        timeline: CheckTimeline(began: began).withCore({
          'bootMs': 120,
          'coldMs': 700,
          'dialMs': 60,
          'firstByteMs': 230,
          'tlsMs': 210,
          'replyMs': 240,
          'bytesOut': 2100,
          'bytesIn': 14800,
          'dials': 1,
          'dialFails': 0,
        }),
      );
    } finally {
      running--;
    }
  }

  /// A fresh answer from the backend, with [tests] and [testParams].
  Future<void> load(
    List<Map<String, dynamic>>? tests, {
    Object? testParams = const _Default(),
  }) async {
    next = answer(
      tests: tests,
      testParams: testParams is _Default
          ? (tests == null ? null : params())
          : testParams,
    );
    await dedicated.refresh();
    await pumpEventQueue();
  }

  /// The phone goes idle and the tester is asked to run.
  Future<void> run() async {
    idle = true;
    await tester.maybeRun();
  }

  List<int> get checkedIds => [for (final d in dials) d.test.assignmentId];

  List<List<int>> get reportedIds => [
    for (final s in sent)
      [for (final r in s.results) r['assignment_id'] as int],
  ];
}

/// The parameters [Rig.load] sends when a test names none.
class _Default {
  const _Default();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ServerClock.resetForTest();
  });

  group('reading the answer', () {
    test('a row the backend sends is read whole, with its config', () {
      final t = VariantTest.fromJson(row(12))!;
      expect(t.assignmentId, 12);
      expect(t.variantKey, 'xhttp-reality#v=a3f1c2d0e5b12');
      expect(t.serverId, 13);
      expect(t.door, 'xhttp-reality');
      expect(t.uri, reality);
      expect(t.config, config());
      expect(t.deadline, t0.add(const Duration(hours: 2)));
      expect(t.deadline.isUtc, isTrue);
    });

    test('a row from a backend without configs keeps its link', () {
      final t = VariantTest.fromJson(row(1, withConfig: false))!;
      expect(t.config, isNull);
      expect(t.uri, reality);
    });

    test('the deadline is read in UTC whatever offset it is written in', () {
      final t = VariantTest.fromJson({
        ...row(1),
        'deadline': '2026-10-18T12:30:00+03:30',
      })!;
      expect(t.deadline, t0);
    });

    test(
      'a Cloudflare door has no server, and a missing key logs the door',
      () {
        final t = VariantTest.fromJson({
          ...row(1, doorId: 'ws-tls'),
          'server_id': null,
          'variant_key': null,
        })!;
        expect(t.serverId, isNull);
        expect(t.variantKey, 'ws-tls');
      },
    );

    test('a row the app cannot use is dropped, and the rest are kept', () {
      Map<String, dynamic> withProxy(Map<String, dynamic> first) => {
        'outbounds': [first],
      };
      final tests = VariantTest.listFromJson([
        row(1),
        {...row(2), 'assignment_id': '2'},
        {...row(3)}..remove('assignment_id'),
        {...row(4), 'door': ''},
        {...row(5), 'deadline': 'tomorrow'},
        {...row(6)}..remove('deadline'),
        {...row(7), 'config': 'vless://x'},
        {...row(8), 'config': <String, dynamic>{}},
        {
          ...row(9),
          'config': {'outbounds': <Object>[]},
        },
        // The check dials the first outbound, which must be the proxy.
        {
          ...row(10),
          'config': {
            'outbounds': [
              {'tag': 'fragment', 'protocol': 'freedom'},
              {'tag': 'proxy', 'protocol': 'vless'},
            ],
          },
        },
        {
          ...row(11),
          'config': withProxy({'tag': 'proxy'}),
        },
        {
          ...row(12),
          'config': withProxy({'tag': 'proxy', 'protocol': ' '}),
        },
        // Neither a config nor a link.
        {...row(13, withConfig: false), 'uri': ''},
        'vless://not-a-row',
        null,
        // A config needs no link, and a link needs no config.
        {...row(14), 'uri': null},
        row(15, withConfig: false),
      ]);
      expect([for (final t in tests) t.assignmentId], [1, 14, 15]);
    });

    test('no list, or something else, is no tests', () {
      expect(VariantTest.listFromJson(null), isEmpty);
      expect(VariantTest.listFromJson({'assignment_id': 1}), isEmpty);
      expect(VariantTest.listFromJson('[]'), isEmpty);
    });

    test('the parameters are read whole', () {
      final p = VariantTestParams.fromJson(
        params(
          url: ' https://www.gstatic.com/generate_204 ',
          timeoutMs: 6500,
          perRun: 3,
          gapMinutes: 45,
          onlyDown: false,
        ),
      )!;
      expect(p.testUrl, 'https://www.gstatic.com/generate_204');
      expect(p.timeout, const Duration(milliseconds: 6500));
      expect(p.maxPerRun, 3);
      expect(p.minGap, const Duration(minutes: 45));
      expect(p.onlyWhenTunnelDown, isFalse);
      expect(
        VariantTestParams.fromJson(params(gapMinutes: 0))!.minGap,
        Duration.zero,
      );
      expect(
        VariantTestParams.fromJson(
          params(url: 'http://cp.cloudflare.com/generate_204'),
        ),
        isNotNull,
      );
    });

    test('parameters with any value missing or unusable are none', () {
      final good = params();
      final bad = <Object?>[
        null,
        'params',
        <String, dynamic>{},
        for (final key in good.keys) {...good}..remove(key),
        {...good, 'test_url': ''},
        {...good, 'test_url': 'cp.cloudflare.com/generate_204'},
        {...good, 'test_url': 'ftp://cp.cloudflare.com/x'},
        {...good, 'test_url': 'https:///generate_204'},
        {...good, 'test_url': 7},
        {...good, 'timeout_ms': 0},
        {...good, 'timeout_ms': -1},
        {...good, 'timeout_ms': '4000'},
        {...good, 'timeout_ms': 4000.5},
        {...good, 'max_per_run': 0},
        {...good, 'max_per_run': null},
        {...good, 'min_gap_minutes': -1},
        {...good, 'min_gap_minutes': 1.5},
        {...good, 'only_when_tunnel_down': 'true'},
        {...good, 'only_when_tunnel_down': 1},
      ];
      for (final json in bad) {
        expect(VariantTestParams.fromJson(json), isNull, reason: '$json');
      }
    });

    test('parameters without background_minutes are read as before, with '
        'no background timer', () {
      final p = VariantTestParams.fromJson(params())!;
      expect(p.backgroundEvery, isNull);
      expect(p.testUrl, 'https://cp.cloudflare.com/generate_204');
      expect(p.timeout, const Duration(milliseconds: 4000));
      expect(p.maxPerRun, 8);
      expect(p.minGap, Duration.zero);
      expect(p.onlyWhenTunnelDown, isTrue);
    });

    test('background_minutes is read in minutes from 1 to 1440', () {
      for (final minutes in [1, 15, 1440]) {
        expect(
          VariantTestParams.fromJson(
            params(backgroundMinutes: minutes),
          )!.backgroundEvery,
          Duration(minutes: minutes),
        );
      }
    });

    test('a bad background_minutes is none, and the rest still count', () {
      for (final bad in <Object?>[0, -1, 1441, '15', 15.5, true, null]) {
        final p = VariantTestParams.fromJson({
          ...params(perRun: 3, gapMinutes: 30, onlyDown: false),
          'background_minutes': bad,
        });
        expect(p, isNotNull, reason: '$bad');
        expect(p!.backgroundEvery, isNull, reason: '$bad');
        expect(p.testUrl, 'https://cp.cloudflare.com/generate_204');
        expect(p.timeout, const Duration(milliseconds: 4000));
        expect(p.maxPerRun, 3);
        expect(p.minGap, const Duration(minutes: 30));
        expect(p.onlyWhenTunnelDown, isFalse);
      }
    });

    test('the dedicated answer carries the tests and their parameters, and '
        'one without them has none', () {
      final withTests = DedicatedConfigs.fromJson(
        answer(tests: [row(1), row(2)], testParams: params()),
      );
      expect([for (final t in withTests.variantTests) t.assignmentId], [1, 2]);
      expect(withTests.variantTestParams!.maxPerRun, 8);

      final without = DedicatedConfigs.fromJson(answer());
      expect(without.variantTests, isEmpty);
      expect(without.variantTestParams, isNull);
      // The rest of the answer is read the same either way.
      expect(withTests.configs, without.configs);
      expect(
        [for (final p in withTests.paths) p.uri],
        [for (final p in without.paths) p.uri],
      );
    });
  });

  group('the device state', () {
    DedicatedState state(Map<String, dynamic> body) => DedicatedState(
      now: () => t0,
      fetch: ({bool? viaTunnel}) async => DedicatedConfigs.fromJson(body),
    );

    test('holds a fresh answer\'s tests and parameters, and never lists a '
        'test as a server or a door', () async {
      final s = state(
        answer(
          tests: [row(1, uri: tlsOff, doorId: 'ws-tls')],
          testParams: params(),
        ),
      );
      await s.refresh();

      expect([for (final t in s.variantTests) t.assignmentId], [1]);
      expect(s.variantTestParams, isNotNull);
      final links = [
        ...s.servers.map((x) => x.connectionUri),
        ...s.paths.map((x) => x.connectionUri),
        ...s.configs,
      ];
      expect(links, isNot(contains(tlsOff)));
      expect(s.paths.single.connectionUri, door);
    });

    test(
      'does not keep them on the phone, and a kept answer gives none',
      () async {
        final s = state(answer(tests: [row(1)], testParams: params()));
        await s.refresh();
        await pumpEventQueue();

        final prefs = await SharedPreferences.getInstance();
        final kept = jsonDecode(prefs.getString(DedicatedState.prefSaved)!);
        final body = (kept as Map)['body'] as Map;
        expect(body.containsKey('variant_tests'), isFalse);
        expect(body.containsKey('variant_test_params'), isFalse);
        expect(body['paths'], isNotEmpty);

        // Even a kept answer that has them, as no build writes one.
        SharedPreferences.setMockInitialValues({
          DedicatedState.prefSaved: jsonEncode({
            'at': t0.toIso8601String(),
            'body': answer(tests: [row(2)], testParams: params()),
          }),
        });
        final offline = DedicatedState(
          now: () => t0,
          fetch: ({bool? viaTunnel}) async =>
              throw ApiException(statusCode: 0, message: 'No internet'),
        );
        await offline.refresh();
        expect(offline.fromSaved, isTrue);
        expect(offline.variantTests, isEmpty);
        expect(offline.variantTestParams, isNull);
      },
    );

    test(
      'an account deletion drops them and starts a new generation',
      () async {
        final s = state(answer(tests: [row(1)], testParams: params()));
        await s.refresh();
        final before = s.generation;

        s.reset();

        expect(s.variantTests, isEmpty);
        expect(s.variantTestParams, isNull);
        expect(s.generation, isNot(before));
      },
    );
  });

  group('when tests run', () {
    test('an answer with no tests leaves everything as it was', () async {
      final r = Rig()..idle = true;
      await r.load(null);
      await r.tester.maybeRun();
      await r.load([]);
      await r.tester.maybeRun();

      // Not even asked whether the phone is idle.
      expect(r.idleAsked, 0);
      expect(r.internetAsked, 0);
      expect(r.networkAsked, 0);
      expect(r.dials, isEmpty);
      expect(r.sends, 0);
    });

    test('tests without usable parameters never run, and are not even '
        'considered', () async {
      for (final bad in <Object?>[null, params(timeoutMs: 0), 'x']) {
        final r = Rig()..idle = true;
        await r.load([row(1)], testParams: bad);
        await r.tester.maybeRun();

        expect(r.idleAsked, 0, reason: '$bad');
        expect(r.dials, isEmpty, reason: '$bad');
        expect(r.tester.pendingCount, 0, reason: '$bad');
        expect(r.sends, 0, reason: '$bad');
      }
    });

    test('a later answer with unusable parameters stops the tests that '
        'wait', () async {
      final r = Rig();
      await r.load([row(1)]);
      expect(r.tester.pendingCount, 1);
      await r.load([row(2)], testParams: params(perRun: 0));

      await r.run();

      expect(r.dials, isEmpty);
      expect(r.sends, 0);
    });

    test(
      'an answer with tests starts a run by itself when the phone is idle',
      () async {
        final r = Rig()..idle = true;
        await r.load([row(1), row(2)]);
        await pumpEventQueue();

        expect(r.checkedIds, [1, 2]);
        expect(r.reportedIds, [
          [1, 2],
        ]);
      },
    );

    test('each test runs once, in the order sent, with the backend\'s '
        'config, wait and address', () async {
      final r = Rig();
      await r.load(
        [row(1), row(2)],
        testParams: params(
          url: 'https://www.gstatic.com/generate_204',
          timeoutMs: 6500,
        ),
      );
      await r.run();
      await r.tester.maybeRun();
      // The same hand-out in a later answer is not run again.
      await r.load([row(2)]);
      await r.run();

      expect(r.checkedIds, [1, 2]);
      for (final d in r.dials) {
        expect(d.config, config());
        expect(d.link, isNull);
        // Not the row's own timeout_ms.
        expect(d.wait, const Duration(milliseconds: 6500));
        expect(d.url, 'https://www.gstatic.com/generate_204');
      }
      expect(r.sent, hasLength(1));
    });

    test('no more tests in a run than the backend says', () async {
      final r = Rig();
      await r.load([row(1), row(2), row(3)], testParams: params(perRun: 2));

      await r.run();
      expect(r.checkedIds, [1, 2]);
      expect(r.reportedIds, [
        [1, 2],
      ]);
      expect(r.tester.pendingCount, 1);

      await r.tester.maybeRun();
      expect(r.checkedIds, [1, 2, 3]);
      expect(r.reportedIds, [
        [1, 2],
        [3],
      ]);
    });

    test('a run waits the backend\'s gap after the last one', () async {
      final r = Rig();
      await r.load([
        row(1),
        row(2),
        row(3),
        row(4),
      ], testParams: params(perRun: 1, gapMinutes: 30));

      await r.run();
      expect(r.checkedIds, [1]);

      r.now = t0.add(const Duration(minutes: 29));
      await r.tester.maybeRun();
      expect(r.checkedIds, [1]);

      r.now = t0.add(const Duration(minutes: 30));
      await r.tester.maybeRun();
      expect(r.checkedIds, [1, 2]);

      // A clock moved back does not hold the tests forever.
      r.now = t0.subtract(const Duration(days: 1));
      await r.tester.maybeRun();
      expect(r.checkedIds, [1, 2, 3]);
    });

    test('with the tunnel up a test waits, when the backend says so', () async {
      final r = Rig()..tunnelUp = true;
      await r.load([row(1)], testParams: params(onlyDown: true));

      await r.run();
      expect(r.dials, isEmpty);
      expect(r.tester.pendingCount, 1);

      r.tunnelUp = false;
      await r.tester.maybeRun();
      expect(r.checkedIds, [1]);
    });

    test(
      'with the tunnel up a test runs, when the backend allows it',
      () async {
        final r = Rig()..tunnelUp = true;
        await r.load([row(1)], testParams: params(onlyDown: false));

        await r.run();

        expect(r.checkedIds, [1]);
        expect(r.reportedIds, [
          [1],
        ]);
      },
    );

    test('nothing runs while the phone is busy, and the tests wait', () async {
      final r = Rig();
      await r.load([row(1)]);

      await r.tester.maybeRun();
      expect(r.dials, isEmpty);
      expect(r.tester.pendingCount, 1);

      await r.run();
      expect(r.checkedIds, [1]);
    });

    test(
      'a later answer without tests does not drop the earlier ones',
      () async {
        // The phone connected after the first answer, and asked again.
        final r = Rig();
        await r.load([row(1), row(2)]);
        await r.load(null);
        expect(r.dedicated.variantTests, isEmpty);
        expect(r.dedicated.variantTestParams, isNull);

        await r.run();

        expect(r.checkedIds, [1, 2]);
      },
    );

    test(
      'a run stops when the phone stops being idle, and the rest wait',
      () async {
        final r = Rig();
        await r.load([row(1), row(2), row(3)]);
        // The user taps connect during the first check.
        r.during = (dial) {
          if (dial.test.assignmentId == 1) r.idle = false;
        };

        await r.run();
        expect(r.checkedIds, [1]);
        expect(r.reportedIds, [
          [1],
        ]);
        expect(r.tester.pendingCount, 2);

        await r.run();
        expect(r.checkedIds, [1, 2, 3]);
        expect(r.reportedIds, [
          [1],
          [2, 3],
        ]);
      },
    );

    test('nothing runs beside another native test', () async {
      final r = Rig();
      await r.load([row(1)]);
      r.running = 1;

      await r.run();
      expect(r.dials, isEmpty);

      r.running = 0;
      await r.tester.maybeRun();
      expect(r.checkedIds, [1]);
    });

    test('a result during which another test started is not sent, and the '
        'test runs again later', () async {
      final r = Rig();
      await r.load([row(1), row(2)]);
      // A server list's Test all starts while the first check runs.
      r.during = (_) {
        if (r.dials.length == 1) r.started++;
      };

      await r.run();
      expect(r.checkedIds, [1]);
      expect(r.sent, isEmpty);
      expect(r.tester.pendingCount, 2);

      await r.run();
      expect(r.checkedIds, [1, 1, 2]);
      expect(r.reportedIds, [
        [1, 2],
      ]);
    });

    test('nothing runs while the candidate checks run', () async {
      final r = Rig();
      await r.load([row(1)]);
      final release = Completer<void>();
      final prober = CandidateProber(
        source: _OneCandidate(),
        probe: (_) async {
          await release.future;
          return 200;
        },
        send: (_, _, _) async {},
        deviceId: () async => 'DEV-1',
        appVersion: () async => '1.12.0',
        platform: 'android',
      );
      final candidates = prober.maybeRun(idle: true);
      await pumpEventQueue();
      expect(CandidateProber.anyRunning, isTrue);

      await r.run();
      expect(r.dials, isEmpty);

      release.complete();
      await candidates;
      expect(CandidateProber.anyRunning, isFalse);
      await r.tester.maybeRun();
      expect(r.checkedIds, [1]);
    });

    test('a test past its deadline is dropped without being dialled', () async {
      final r = Rig();
      await r.load([
        row(1, deadline: t0.subtract(const Duration(seconds: 1))),
        row(2, deadline: t0.add(const Duration(minutes: 10))),
        row(3, deadline: t0.add(const Duration(hours: 3))),
      ]);
      expect(r.tester.pendingCount, 2);

      // The tunnel stays up for an hour.
      r.now = t0.add(const Duration(hours: 1));
      await r.run();

      expect(r.checkedIds, [3]);
      expect(r.tester.pendingCount, 0);
    });

    test('nothing runs while the user has diagnostics off', () async {
      SharedPreferences.setMockInitialValues({
        VpnEventReporter.sharePrefKey: false,
      });
      final r = Rig();
      await r.load([row(1)]);

      await r.run();

      expect(r.dials, isEmpty);
      expect(r.sends, 0);
    });

    test('nothing runs with no network, or when no control site answers, '
        'and the tests wait', () async {
      final r = Rig()..networkType = null;
      await r.load([row(1)]);

      await r.run();
      expect(r.dials, isEmpty);

      r
        ..networkType = 'wifi'
        ..internet = false;
      await r.tester.maybeRun();
      expect(r.dials, isEmpty);
      expect(r.tester.pendingCount, 1);

      r.internet = true;
      await r.tester.maybeRun();
      expect(r.checkedIds, [1]);
    });

    test('a test without a config is dialled from its link, and a link the '
        'app would not dial as written is never dialled', () async {
      final r = Rig();
      await r.load([
        row(1, uri: 'vless://short', withConfig: false),
        row(
          2,
          uri: reality.replaceFirst('#', '&allowInsecure=1#'),
          withConfig: false,
        ),
        row(3, withConfig: false),
        row(4),
      ]);

      await r.run();

      expect(r.checkedIds, [3, 4]);
      expect(r.dials[0].config, isNull);
      expect(r.dials[0].link!.connectionUri, reality);
      expect(r.dials[0].url, 'https://cp.cloudflare.com/generate_204');
      expect(r.dials[1].config, config());
      expect(r.dials[1].link, isNull);
      expect(r.reportedIds, [
        [3, 4],
      ]);
      expect(r.tester.pendingCount, 0);
    });

    test(
      'a check that did not run is not reported, and not tried again',
      () async {
        final r = Rig();
        await r.load([row(1), row(2)]);
        r.outcome = (dial) => dial.test.assignmentId == 1
            ? null
            : const DoorOutcome(ms: 300, phase: 'ok');

        await r.run();
        await r.tester.maybeRun();

        expect(r.checkedIds, [1, 2]);
        expect(r.reportedIds, [
          [2],
        ]);
        expect(r.tester.pendingCount, 0);
      },
    );

    test('an account deleted before the run takes the tests with it', () async {
      final r = Rig();
      await r.load([row(1)]);

      r.dedicated.reset();
      await r.run();

      expect(r.dials, isEmpty);
      expect(r.tester.pendingCount, 0);
    });

    test('an account deleted during the run sends nothing', () async {
      final r = Rig();
      await r.load([row(1), row(2)]);
      r.during = (_) => r.dedicated.reset();

      await r.run();

      expect(r.checkedIds, [1]);
      expect(r.sends, 0);
    });

    test(
      'an account deletion that starts during the run sends nothing',
      () async {
        final r = Rig();
        await r.load([row(1), row(2)]);
        r.during = (_) => r.dedicated.forgetAccount();

        await r.run();

        expect(r.checkedIds, [1]);
        expect(r.sends, 0);
      },
    );

    test('a disposed tester no longer follows the answers', () async {
      final r = Rig()..idle = true;
      r.tester.dispose();

      await r.load([row(1)]);
      await pumpEventQueue();

      expect(r.dials, isEmpty);
    });
  });

  group('while the app is out of sight', () {
    /// Later than any run here, so no test is dropped for its deadline.
    final later = t0.add(const Duration(hours: 12));

    /// Runs [body] in fake time on a fresh rig.
    void inFakeTime(void Function(FakeAsync async, Rig r) body) {
      fakeAsync((async) {
        final r = Rig();
        body(async, r);
        r.tester.dispose();
      });
    }

    /// [Rig.load] in fake time.
    void load(
      FakeAsync async,
      Rig r,
      List<Map<String, dynamic>>? tests,
      Object? testParams,
    ) {
      unawaited(r.load(tests, testParams: testParams));
      async.elapse(Duration.zero);
    }

    /// [d] passes on the rig's clock and on the timers, [times] times.
    void pass(FakeAsync async, Rig r, Duration d, {int times = 1}) {
      for (var i = 0; i < times; i++) {
        r.now = r.now.add(d);
        async.elapse(d);
      }
    }

    const quarter = Duration(minutes: 15);

    test('without background_minutes no timer runs, and only an answer '
        'starts a run', () {
      inFakeTime((async, r) {
        load(async, r, [row(1, deadline: later)], params());
        r.idle = true;
        r.tester.hidden();
        final asked = r.idleAsked;

        expect(r.tester.backgroundTimer, isFalse);
        pass(async, r, quarter, times: 8);
        expect(r.dials, isEmpty);
        // Not even asked whether the phone is idle.
        expect(r.idleAsked, asked);

        load(async, r, [row(2, deadline: later)], params());
        expect(r.checkedIds, [1, 2]);
      });
    });

    test('with background_minutes the tests are tried that often', () {
      inFakeTime((async, r) {
        load(async, r, [
          for (var id = 1; id <= 3; id++) row(id, deadline: later),
        ], params(perRun: 1, backgroundMinutes: 15));
        r.idle = true;
        r.tester.hidden();
        expect(r.tester.backgroundTimer, isTrue);

        pass(async, r, const Duration(minutes: 14));
        expect(r.dials, isEmpty);
        pass(async, r, const Duration(minutes: 1));
        expect(r.checkedIds, [1]);
        pass(async, r, quarter);
        expect(r.checkedIds, [1, 2]);
        expect(r.reportedIds, [
          [1],
          [2],
        ]);
      });
    });

    test('an answer with background_minutes while out of sight starts the '
        'timer', () {
      inFakeTime((async, r) {
        r.tester.hidden();
        expect(r.tester.backgroundTimer, isFalse);

        load(async, r, [
          row(1, deadline: later),
        ], params(backgroundMinutes: 15));
        expect(r.tester.backgroundTimer, isTrue);
        r.idle = true;
        pass(async, r, quarter);
        expect(r.checkedIds, [1]);
      });
    });

    test('a try from elsewhere keeps the timer\'s beat', () {
      inFakeTime((async, r) {
        load(async, r, [
          row(1, deadline: later),
        ], params(backgroundMinutes: 15));
        r.tester.hidden();

        pass(async, r, const Duration(minutes: 10));
        // A network change while the phone is busy.
        unawaited(r.tester.maybeRun());
        async.flushMicrotasks();
        expect(r.dials, isEmpty);

        r.idle = true;
        pass(async, r, const Duration(minutes: 5));
        expect(r.checkedIds, [1]);
      });
    });

    test('the timer keeps the backend\'s gap and its count per run', () {
      inFakeTime((async, r) {
        load(async, r, [
          for (var id = 1; id <= 6; id++) row(id, deadline: later),
        ], params(perRun: 2, gapMinutes: 30, backgroundMinutes: 15));
        r.idle = true;
        r.tester.hidden();

        pass(async, r, quarter);
        expect(r.checkedIds, [1, 2]);
        pass(async, r, quarter);
        expect(r.checkedIds, [1, 2]);
        pass(async, r, quarter);
        expect(r.checkedIds, [1, 2, 3, 4]);
        expect(r.reportedIds, [
          [1, 2],
          [3, 4],
        ]);
      });
    });

    test('with the tunnel up the timer runs nothing, when the backend says '
        'so', () {
      inFakeTime((async, r) {
        r.tunnelUp = true;
        load(async, r, [
          row(1, deadline: later),
        ], params(onlyDown: true, backgroundMinutes: 15));
        r.idle = true;
        r.tester.hidden();

        pass(async, r, quarter, times: 4);
        expect(r.dials, isEmpty);
        expect(r.tester.pendingCount, 1);

        r.tunnelUp = false;
        pass(async, r, quarter);
        expect(r.checkedIds, [1]);
      });
    });

    test('when no control site answers the timer runs nothing, and the test '
        'waits', () {
      inFakeTime((async, r) {
        r.internet = false;
        load(async, r, [
          row(1, deadline: later),
        ], params(backgroundMinutes: 15));
        r.idle = true;
        r.tester.hidden();

        pass(async, r, quarter, times: 2);
        expect(r.internetAsked, 2);
        expect(r.dials, isEmpty);
        expect(r.tester.pendingCount, 1);

        r.internet = true;
        pass(async, r, quarter);
        expect(r.checkedIds, [1]);
      });
    });

    test('the app back in front stops the timer', () {
      inFakeTime((async, r) {
        load(async, r, [
          row(1, deadline: later),
        ], params(backgroundMinutes: 15));
        r.idle = true;
        r.tester.hidden();
        r.tester.shown();

        expect(r.tester.backgroundTimer, isFalse);
        pass(async, r, quarter, times: 4);
        expect(r.dials, isEmpty);

        r.tester.hidden();
        pass(async, r, quarter);
        expect(r.checkedIds, [1]);
      });
    });

    test('an answer without background_minutes stops the timer', () {
      inFakeTime((async, r) {
        load(async, r, [
          row(1, deadline: later),
        ], params(backgroundMinutes: 15));
        r.tester.hidden();

        load(async, r, [row(2, deadline: later)], params());
        expect(r.tester.backgroundTimer, isFalse);
        r.idle = true;
        pass(async, r, quarter, times: 4);
        expect(r.dials, isEmpty);
        expect(r.tester.pendingCount, 2);
      });
    });

    test('an answer without tests stops the timer, and the tests held wait '
        'for an answer', () {
      inFakeTime((async, r) {
        load(async, r, [
          row(1, deadline: later),
        ], params(backgroundMinutes: 15));
        r.tester.hidden();

        // As when the backend's tests are turned off.
        load(async, r, null, null);
        expect(r.tester.backgroundTimer, isFalse);
        r.tester.shown();
        r.tester.hidden();
        expect(r.tester.backgroundTimer, isFalse);
        r.idle = true;
        pass(async, r, quarter, times: 4);
        expect(r.dials, isEmpty);
        expect(r.tester.pendingCount, 1);

        // An answer still runs the test held, with its own parameters.
        load(async, r, null, null);
        expect(r.checkedIds, [1]);
        expect(r.reportedIds, [
          [1],
        ]);
        expect(r.tester.backgroundTimer, isFalse);
      });
    });

    test('a later answer with another background_minutes moves the timer to '
        'it', () {
      inFakeTime((async, r) {
        load(async, r, [
          row(1, deadline: later),
        ], params(backgroundMinutes: 15));
        r.tester.hidden();
        load(async, r, [
          row(2, deadline: later),
        ], params(perRun: 1, backgroundMinutes: 60));
        r.idle = true;

        pass(async, r, quarter, times: 3);
        expect(r.dials, isEmpty);
        pass(async, r, quarter);
        expect(r.checkedIds, [1]);
      });
    });

    test('an account deletion stops the timer', () {
      inFakeTime((async, r) {
        load(async, r, [
          row(1, deadline: later),
        ], params(backgroundMinutes: 15));
        r.idle = true;
        r.tester.hidden();

        r.dedicated.reset();
        async.flushMicrotasks();
        expect(r.tester.backgroundTimer, isFalse);
        pass(async, r, quarter, times: 4);
        expect(r.dials, isEmpty);
      });
    });

    test('a disposed tester stops the timer and starts no other', () {
      inFakeTime((async, r) {
        load(async, r, [
          row(1, deadline: later),
        ], params(backgroundMinutes: 15));
        r.idle = true;
        r.tester.hidden();

        r.tester.dispose();
        expect(r.tester.backgroundTimer, isFalse);
        r.tester.hidden();
        expect(r.tester.backgroundTimer, isFalse);
        pass(async, r, quarter, times: 4);
        expect(r.dials, isEmpty);
      });
    });
  });

  group('a check cut short by a pause', () {
    /// A failed check that took [span] in all, as the phone's clock saw it.
    void takes(Rig r, Duration span) {
      // The rig's check adds 900 ms of its own.
      r
        ..during = (dial) {
          if (r.dials.length == 1) {
            r.now = r.now.add(span - const Duration(milliseconds: 900));
          }
        }
        ..outcome = (_) => const DoorOutcome(ms: -1, error: 'no answer');
    }

    test('with background_minutes it is not sent, and the test waits for '
        'the next run', () async {
      final r = Rig();
      await r.load([row(1), row(2)], testParams: params(backgroundMinutes: 15));
      // Twice the 4 s wait and the 2 s margin is 10 s.
      takes(r, const Duration(seconds: 10, milliseconds: 1));

      await r.run();
      expect(r.checkedIds, [1]);
      expect(r.sends, 0);
      expect(r.tester.pendingCount, 2);

      await r.tester.maybeRun();
      expect(r.checkedIds, [1, 1, 2]);
      expect(r.reportedIds, [
        [1, 2],
      ]);
    });

    test('with background_minutes one within its waits is sent', () async {
      final r = Rig();
      await r.load([row(1)], testParams: params(backgroundMinutes: 15));
      takes(r, const Duration(seconds: 10));

      await r.run();

      expect(r.sent.single.results.single['ms'], 10000);
      expect(r.tester.pendingCount, 0);
    });

    test('without background_minutes it is sent, as before', () async {
      final r = Rig();
      await r.load([row(1)], testParams: params());
      takes(r, const Duration(minutes: 10));

      await r.run();

      final result = r.sent.single.results.single;
      expect(result['ok'], isFalse);
      expect(result['ms'], 600000);
      expect(r.tester.pendingCount, 0);
    });
  });

  group('which links are dialled as sent, for a test without a config', () {
    VariantTest of(String uri) =>
        VariantTest.fromJson(row(1, uri: uri, withConfig: false))!;
    final p = VariantTestParams.fromJson(params())!;

    test('a Reality link, and a TLS link that names its split', () {
      expect(VariantTester.linkOf(of(reality), android: true), isNotNull);
      expect(VariantTester.linkOf(of(tlsOff), android: true), isNotNull);
      expect(
        VariantTester.linkOf(
          of(tlsBare.replaceFirst('#', '&fragment=tlshello,1-3,1-1#')),
          android: true,
        ),
        isNotNull,
      );
    });

    test('not a TLS link the app would add its own split to', () {
      expect(VariantTester.linkOf(of(tlsBare), android: true), isNull);
      expect(VariantTester.dialOf(of(tlsBare), p, android: true), isNull);
    });

    test('a test with a config dials it, whatever its link', () {
      final t = VariantTest.fromJson(row(1, uri: tlsBare))!;
      final dial = VariantTester.dialOf(t, p, android: true)!;
      expect(dial.config, config());
      expect(dial.link, isNull);
    });

    test('the link stays a stand-in that cannot pass for a server', () {
      final link = VariantTester.linkOf(of(reality), android: true)!;
      expect(link.id, 'variant-1');
      expect(link.isDedicated, isFalse);
      expect(link.door, isNull);
      expect(link.connectionUri, reality);
    });
  });

  group('what is reported', () {
    test('an open check, with the timed check\'s timeline, carrier and '
        'network type', () async {
      final r = Rig();
      await r.load([row(12)]);

      await r.run();

      final batch = r.sent.single;
      expect(batch.device, 'DEV-1');
      expect(batch.viaTunnel, isFalse);
      expect(batch.results.single, {
        'assignment_id': 12,
        'ok': true,
        'app_version': '1.12.0',
        'phase': 'ok',
        'ms': 240,
        'tcp_ms': 61,
        'began_ms': 900,
        'boot_ms': 120,
        'cold_ms': 700,
        'dial_ms': 60,
        'first_byte_ms': 230,
        'tls_ms': 210,
        'reply_ms': 240,
        'bytes_out': 2100,
        'bytes_in': 14800,
        'dials': 1,
        'dial_fails': 0,
        'carrier': 'IR-MCI',
        'network_type': 'mobile',
        'client_ts': t0
            .add(const Duration(milliseconds: 900))
            .toIso8601String(),
      });
    });

    test('a failed check says how far it got and how long it took', () async {
      final r = Rig()
        ..carrier = null
        ..outcome = (_) => DoorOutcome(
          ms: -1,
          error: 'tcp ok 61ms; ${'x' * 300}',
          tcpMs: 61,
          phase: 'tls',
          timeline: CheckTimeline(began: t0),
        );
      await r.load([row(3)]);

      await r.run();

      final result = r.sent.single.results.single;
      expect(result['ok'], isFalse);
      expect(result['phase'], 'tls');
      expect(result['ms'], 900);
      expect((result['error'] as String).length, 200);
      expect(result['error'], startsWith('tcp ok 61ms; '));
      expect(result['tcp_ms'], 61);
      // A plain check reached none of the core's steps.
      expect(result.containsKey('boot_ms'), isFalse);
      expect(result.containsKey('carrier'), isFalse);
      expect(result['network_type'], 'mobile');
    });

    test('a failed check under a clock moved back sends no time for it', () {
      final reading = DoorOutcome(ms: -1, error: 'EOF');
      final result = VariantTester.row(
        VariantTest.fromJson(row(1))!,
        reading,
        began: t0,
        ended: t0.subtract(const Duration(seconds: 5)),
        appVersion: '1.12.0',
      );
      expect(result.containsKey('ms'), isFalse);
      expect(result.containsKey('began_ms'), isFalse);
      expect(result['error'], 'EOF');
    });

    test('a result carries only the fields the backend takes, and no '
        'address', () async {
      final r = Rig();
      await r.load([
        row(1),
        row(2, uri: tlsOff, doorId: 'ws-tls', withConfig: false),
      ]);
      var n = 0;
      r.outcome = (_) => n++ == 0
          ? const DoorOutcome(ms: 300, phase: 'ok')
          : const DoorOutcome(ms: -1, error: 'EOF', phase: 'proxy');

      await r.run();

      for (final result in r.sent.single.results) {
        expect(
          resultFields.containsAll(result.keys),
          isTrue,
          reason: '$result',
        );
        expect(jsonEncode(result), isNot(contains('203.0.113.7')));
        expect(jsonEncode(result), isNot(contains('198.51.100.215')));
        expect(jsonEncode(result), isNot(contains(_uuid)));
      }
    });

    test('one report per answer, so a report never holds more results than '
        'one answer held tests', () async {
      final r = Rig();
      await r.load([row(1), row(2)]);
      await r.load([row(3)]);

      await r.run();

      expect(r.checkedIds, [1, 2, 3]);
      expect(r.reportedIds, [
        [1, 2],
        [3],
      ]);
    });

    test(
      'nothing is sent while the app\'s requests go through the tunnel',
      () async {
        final r = Rig()..through = true;
        await r.load([row(1)]);

        await r.run();

        expect(r.checkedIds, [1]);
        expect(r.sends, 0);
      },
    );

    test('a report that failed for a reason a second try can get past is '
        'sent once more', () async {
      final r = Rig();
      r.failures.add(ApiException(statusCode: 503, message: 'busy'));
      await r.load([row(1)]);

      await r.run();

      expect(r.sends, 2);
      expect(r.reportedIds, [
        [1],
      ]);
    });

    test('a report the backend refused is not tried again, and the rest '
        'are not sent', () async {
      final r = Rig();
      r.failures.add(ApiException(statusCode: 404, message: 'Not Found'));
      await r.load([row(1)]);
      await r.load([row(2)]);

      await r.run();

      expect(r.checkedIds, [1, 2]);
      expect(r.sends, 1);
      expect(r.sent, isEmpty);
    });

    test('the report goes to the variant results endpoint with the time it '
        'left', () async {
      final posts = <(String, Map<String, dynamic>)>[];
      final sentAt = DateTime.utc(2026, 10, 18, 9, 12, 5);
      final dedicated = DedicatedState(
        now: () => t0,
        fetch: ({bool? viaTunnel}) async => DedicatedConfigs.fromJson(
          answer(tests: [row(7)], testParams: params()),
        ),
      );
      var now = t0;
      var idle = false;
      final tester = VariantTester(
        dedicated,
        idle: () => idle,
        tunnelUp: () => false,
        throughTunnel: () => false,
        check: (_) async => const DoorOutcome(ms: 200, phase: 'ok'),
        internet: () async => true,
        post: (path, body) async => posts.add((path, body)),
        clock: () => now,
        deviceId: () async => 'DEV-9',
        appVersion: () async => '1.12.0',
        networkType: () async => 'wifi',
        carrier: () async => null,
        checksRunning: () => 0,
        checksStarted: () => 0,
      );
      await dedicated.refresh();
      now = sentAt;
      idle = true;

      await tester.maybeRun();
      tester.dispose();

      final (path, body) = posts.single;
      expect(path, '/api/v1/devices/DEV-9/variant-results');
      expect(body.keys.toSet(), {'results', 'via_tunnel', 'sent_at'});
      expect(body['via_tunnel'], isFalse);
      expect(body['sent_at'], sentAt.toIso8601String());
      expect((body['results'] as List).single['assignment_id'], 7);
    });
  });

  group('the check itself', () {
    const tunnel = MethodChannel('com.vpn.fortivavpn/tunnel');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    tearDown(() {
      messenger.setMockMethodCallHandler(tunnel, null);
      ConnectionData.current = ConnectionData.off;
    });

    /// A tester with the real check, against [native] as the tunnel
    /// channel, for one answer with [tests]. Returns the native calls and
    /// the results sent.
    Future<({List<MethodCall> calls, List<Map<String, dynamic>> results})>
    runReal(
      List<Map<String, dynamic>> tests,
      Future<Object?> Function(MethodCall call) native,
    ) async {
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(tunnel, (call) async {
        calls.add(call);
        return native(call);
      });
      final sent = <Map<String, dynamic>>[];
      final dedicated = DedicatedState(
        now: () => t0,
        fetch: ({bool? viaTunnel}) async => DedicatedConfigs.fromJson(
          answer(
            tests: tests,
            testParams: params(
              url: 'https://www.gstatic.com/generate_204',
              timeoutMs: 4500,
            ),
          ),
        ),
      );
      var idle = false;
      final tester = VariantTester(
        dedicated,
        idle: () => idle,
        tunnelUp: () => false,
        throughTunnel: () => false,
        internet: () async => true,
        send: (_, results, _) async => sent.addAll(results),
        clock: () => t0,
        deviceId: () async => 'DEV-1',
        appVersion: () async => '1.12.0',
        networkType: () async => 'mobile',
        carrier: () async => 'Irancell',
      );
      await dedicated.refresh();
      idle = true;
      await tester.maybeRun();
      tester.dispose();
      return (calls: calls, results: sent);
    }

    const timedFailure = {
      'ms': -1,
      'error': 'EOF',
      'tcp': 'ok',
      'tcpMs': 58,
      'timed': true,
      'phase': 'proxy',
      'bootMs': 110,
      'dialMs': 58,
      'firstByteMs': 190,
      'tlsMs': 180,
      'bytesOut': 1900,
      'bytesIn': 2400,
      'dials': 1,
      'dialFails': 0,
    };

    test('a test with a config runs it through the native door check, with '
        'the backend\'s address and wait', () async {
      ConnectionData.current = const ConnectionData(timedChecks: true);
      final run = await runReal([
        row(5),
      ], (call) async => call.method == 'realPingConfig' ? timedFailure : null);

      final call = run.calls.singleWhere((c) => c.method == 'realPingConfig');
      final args = call.arguments as Map;
      expect(jsonDecode(args['config'] as String), config());
      expect(args['url'], 'https://www.gstatic.com/generate_204');
      expect(args['timeoutMs'], 4500);
      expect(args['timed'], isTrue);
      expect(args.containsKey('splitter'), isTrue);
      expect(args.containsKey('link'), isFalse);
      expect(run.calls.where((c) => c.method == 'realPingDetail'), isEmpty);
      // The app's own check counts as the one test that ran, so its result
      // is sent.
      final result = run.results.single;
      expect(result['ok'], isFalse);
      expect(result['phase'], 'proxy');
      expect(result['error'], 'tcp ok 58ms; EOF');
      expect(result['tcp_ms'], 58);
      expect(result['boot_ms'], 110);
      expect(result['first_byte_ms'], 190);
      expect(result['bytes_in'], 2400);
      expect(result['carrier'], 'Irancell');
    });

    test('a test without a config is the door checks\' timed check of its '
        'link, with the backend\'s address and wait', () async {
      ConnectionData.current = const ConnectionData(timedChecks: true);
      final run = await runReal([
        row(6, withConfig: false),
      ], (call) async => call.method == 'realPingDetail' ? timedFailure : null);

      final call = run.calls.singleWhere((c) => c.method == 'realPingDetail');
      final args = call.arguments as Map;
      expect(args['link'], reality);
      expect(args['url'], 'https://www.gstatic.com/generate_204');
      expect(args['timeoutMs'], 4500);
      expect(args['timed'], isTrue);
      expect(run.results.single['phase'], 'proxy');
    });

    test('a config the native side would not run, or a platform without the '
        'check, reports nothing', () async {
      final refused = await runReal(
        [row(7)],
        (call) async => call.method == 'realPingConfig'
            ? {'ms': -1, 'refused': true, 'error': 'config could not be read'}
            : null,
      );
      expect(
        refused.calls.where((c) => c.method == 'realPingConfig'),
        hasLength(1),
      );
      expect(refused.results, isEmpty);

      final missing = await runReal([row(8)], (call) async {
        if (call.method == 'realPingConfig') {
          throw MissingPluginException();
        }
        return null;
      });
      expect(missing.results, isEmpty);
    });
  });
}

class _OneCandidate implements CandidateSource {
  @override
  Future<List<ProbeCandidate>> getProbeCandidates() async => [
    const ProbeCandidate(id: 1, uri: reality, label: 'candidate-1'),
  ];
}
