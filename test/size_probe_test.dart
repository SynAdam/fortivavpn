import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/api/api_routes.dart';
import 'package:fortiva_vpn/data/models/app_config.dart';
import 'package:fortiva_vpn/services/report_queue.dart';
import 'package:fortiva_vpn/services/network_keys.dart';
import 'package:fortiva_vpn/services/size_probe.dart';
import 'package:fortiva_vpn/services/vpn_event_reporter.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The size probe: which transfer sizes reach the backend from this
/// network, on each route. A line can carry small calls and none of the
/// larger uploads, and nothing on the phone could say where the line was.
/// Every number here comes from the config.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Map<String, dynamic> block({
    Object? enabled = true,
    Object? down = const [200, 1400, 6000],
    Object? up = const [200, 3000],
    Object? minutes = 360,
    Object? timeoutMs = 8000,
  }) => {
    'enabled': ?enabled,
    'down_sizes': ?down,
    'up_sizes': ?up,
    'min_interval_minutes': ?minutes,
    'timeout_ms': ?timeoutMs,
  };

  group('the config block', () {
    test('a full block reads every number from the backend', () {
      final s = SizeProbeSettings.fromJson(block())!;
      expect(s.downSizes, [200, 1400, 6000]);
      expect(s.upSizes, [200, 3000]);
      expect(s.minInterval, const Duration(minutes: 360));
      expect(s.timeout, const Duration(milliseconds: 8000));
    });

    test('a missing block is off', () {
      expect(SizeProbeSettings.fromJson(null), isNull);
      final config = AppConfig.fromJson(_config(null));
      expect(config.sizeProbe, isNull);
      expect(config.privacyPolicyUrl, 'https://example.com/privacy');
    });

    test('enabled false, or not a JSON true, is off', () {
      expect(SizeProbeSettings.fromJson(block(enabled: false)), isNull);
      expect(SizeProbeSettings.fromJson(block(enabled: 'true')), isNull);
      expect(SizeProbeSettings.fromJson(block(enabled: null)), isNull);
    });

    test('without an interval or a wait it is off, with no default', () {
      expect(SizeProbeSettings.fromJson(block(minutes: null)), isNull);
      expect(SizeProbeSettings.fromJson(block(timeoutMs: null)), isNull);
      expect(SizeProbeSettings.fromJson(block(minutes: 0)), isNull);
      expect(SizeProbeSettings.fromJson(block(timeoutMs: -1)), isNull);
      expect(SizeProbeSettings.fromJson(block(minutes: '360')), isNull);
      expect(SizeProbeSettings.fromJson(block(timeoutMs: 8000.5)), isNull);
    });

    test('bad sizes are skipped, and no sizes at all is off', () {
      final s = SizeProbeSettings.fromJson(
        block(down: [200, 0, -5, '800', 1.5, 1200], up: 'many'),
      )!;
      expect(s.downSizes, [200, 1200]);
      expect(s.upSizes, isEmpty);
      expect(SizeProbeSettings.fromJson(block(down: [], up: [])), isNull);
    });

    test('a bad block never throws away the rest of the config', () {
      final config = AppConfig.fromJson(_config('not a block'));
      expect(config.sizeProbe, isNull);
      expect(config.supportEmail, 'support@example.com');
    });

    test('the settings survive a round trip through the config', () {
      final config = AppConfig.fromJson(_config(block()));
      final again = AppConfig.fromJson(config.toJson()).sizeProbe!;
      expect(again.downSizes, [200, 1400, 6000]);
      expect(again.upSizes, [200, 3000]);
      expect(again.minInterval, const Duration(minutes: 360));
      expect(again.timeout, const Duration(milliseconds: 8000));
    });
  });

  group('the runner', () {
    late SizeProbeSettings? settings;
    late bool busy;
    late bool throughTunnel;
    late bool stale;
    late int reloads;
    late void Function() onReload;
    late String network;
    late String? networkType;
    late DateTime now;
    late List<http.BaseRequest> requests;
    late List<Map<String, dynamic>> uploads;
    late http.Response Function(http.Request request, SizeProbeRoute route)
    answer;

    const routes = [
      SizeProbeRoute(name: 'direct', base: 'https://api.example.com'),
      SizeProbeRoute(name: 'relay:203.0.113.5', base: 'https://203.0.113.5'),
    ];

    /// The backend's answer: the bytes asked for, or the count received.
    http.Response honest(http.Request request, SizeProbeRoute route) {
      if (request.method == 'GET') {
        final n = int.parse(request.url.queryParameters['n']!);
        return http.Response.bytes(List.filled(n, 7), 200);
      }
      return http.Response(
        jsonEncode({'received': request.bodyBytes.length}),
        200,
      );
    }

    late ReportQueue results;

    SizeProbeRunner runner({Future<String> Function()? networkKey}) =>
        SizeProbeRunner(
          settings: () => settings,
          busy: () => busy,
          throughTunnel: () => throughTunnel,
          stale: () => stale,
          reload: () async {
            reloads++;
            onReload();
          },
          network: networkKey ?? () async => network,
          networkType: () async => networkType,
          routes: () async => routes,
          client: (route, timeout) => MockClient((request) async {
            requests.add(request);
            return answer(request, route);
          }),
          results: results,
          now: () => now,
          newId: () => 'run-1',
        );

    Future<List<Map<String, dynamic>>> queued() => results.pending();

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      ReportQueue.resetForTest();
      settings = SizeProbeSettings.fromJson(block());
      busy = false;
      throughTunnel = false;
      stale = false;
      reloads = 0;
      onReload = () {};
      network = 'wifi';
      networkType = 'wifi';
      now = DateTime.utc(2026, 10, 9, 6);
      requests = [];
      uploads = [];
      answer = honest;
      results = ReportQueue.sizeProbes(
        // Fails, so the readings stay in the queue for the test to read.
        post: (_, body) async {
          uploads.add(body);
          throw Exception('offline');
        },
        deviceId: () async => 'DEV-1',
        clock: () => now,
      );
    });

    test('every size, both ways, on every route, in order', () async {
      final count = await runner().maybeRun();
      expect(count, 10);
      expect(requests.map((r) => '${r.method} ${r.url.host} ${r.url.query}'), [
        for (final host in ['api.example.com', '203.0.113.5']) ...[
          'GET $host n=200',
          'GET $host n=1400',
          'GET $host n=6000',
          'POST $host ',
          'POST $host ',
        ],
      ]);
      for (final r in requests) {
        expect(r.url.path, '/api/v1/probe/bytes');
      }
      final posts = requests.whereType<http.Request>().where(
        (r) => r.method == 'POST',
      );
      expect(posts.map((r) => r.bodyBytes.length), [200, 3000, 200, 3000]);
      expect(
        posts.first.headers['Content-Type'],
        startsWith('application/octet-stream'),
      );

      final rows = await queued();
      expect(rows, hasLength(10));
      expect(rows.first.keys.toSet(), {
        'direction',
        'size',
        'ok',
        'ms',
        'error',
        'route',
        'network_type',
        'client_ts',
        'attempt_id',
      });
      expect(rows.first['direction'], 'down');
      expect(rows.first['size'], 200);
      expect(rows.first['ok'], isTrue);
      expect(rows.first['error'], isNull);
      expect(rows.first['route'], 'direct');
      expect(rows.first['network_type'], 'wifi');
      expect(rows.first['attempt_id'], 'run-1');
      expect(rows.first['client_ts'], '2026-10-09T06:00:00.000Z');
      expect(rows.last['direction'], 'up');
      expect(rows.last['route'], 'relay:203.0.113.5');
    });

    test('a transfer that does not arrive whole is a failure', () async {
      answer = (request, route) {
        if (request.method == 'GET') {
          final n = int.parse(request.url.queryParameters['n']!);
          // A line that cuts large answers short.
          return http.Response.bytes(List.filled(n > 1400 ? 1400 : n, 7), 200);
        }
        final n = request.bodyBytes.length;
        return http.Response(jsonEncode({'received': n > 200 ? 0 : n}), 200);
      };
      await runner().maybeRun();
      final rows = await queued();
      final direct = rows.where((r) => r['route'] == 'direct').toList();
      expect(direct.map((r) => (r['direction'], r['size'], r['ok'])), [
        ('down', 200, true),
        ('down', 1400, true),
        ('down', 6000, false),
        ('up', 200, true),
        ('up', 3000, false),
      ]);
      expect(direct[2]['error'], 'received 1400 of 6000');
      expect(direct[4]['error'], 'received 0 of 3000');
    });

    test('a timeout is named the way the delivery log names it', () async {
      final runner = SizeProbeRunner(
        settings: () => settings,
        busy: () => false,
        network: () async => 'wifi',
        networkType: () async => 'wifi',
        routes: () async => routes.take(1).toList(),
        client: (route, timeout) =>
            MockClient((_) async => throw TimeoutException('waited', timeout)),
        results: results,
        now: () => now,
        newId: () => 'run-1',
      );
      await runner.maybeRun();
      final rows = await queued();
      expect(rows.map((r) => r['error']).toSet(), {'timeout'});
      expect(rows.every((r) => r['ok'] == false), isTrue);
    });

    test('a route that does not serve the probe stops after one row', () async {
      answer = (request, route) => route.name == 'direct'
          ? honest(request, route)
          : http.Response('', 404);
      await runner().maybeRun();
      final rows = await queued();
      final relay = rows.where((r) => r['route'] != 'direct').toList();
      expect(relay, hasLength(1));
      expect(relay.single['error'], 'status 404');
      expect(rows.where((r) => r['route'] == 'direct'), hasLength(5));
    });

    // A rate limit or a deploy that begins partway through a run must not
    // read as the line cutting every size from there up.
    for (final code in [429, 502, 503]) {
      test('a $code answer stops the route after one row', () async {
        answer = (request, route) {
          final n = request.method == 'GET'
              ? int.parse(request.url.queryParameters['n']!)
              : request.bodyBytes.length;
          if (route.name == 'direct' && n >= 6000) {
            return http.Response('', code);
          }
          return honest(request, route);
        };
        await runner().maybeRun();
        final rows = await queued();
        final direct = rows.where((r) => r['route'] == 'direct').toList();
        expect(direct.map((r) => (r['direction'], r['size'], r['ok'])), [
          ('down', 200, true),
          ('down', 1400, true),
          ('down', 6000, false),
        ]);
        expect(direct.last['error'], 'status $code');
        // The up sizes were not tried on that route.
        expect(
          requests.where((r) => r.url.host == 'api.example.com'),
          hasLength(3),
        );
        // The next route is measured as usual.
        expect(rows.where((r) => r['route'] != 'direct'), hasLength(5));
      });
    }

    test('readings go out in uploads under 1 KB', () async {
      results = ReportQueue.sizeProbes(
        post: (_, body) async => uploads.add(body),
        deviceId: () async => 'DEV-1',
        clock: () => now,
      );
      await runner().maybeRun();
      // The runner starts the flush and does not wait for it.
      await results.flush();
      expect(uploads.length, greaterThan(1));
      for (final body in uploads) {
        expect(
          utf8.encode(jsonEncode(body)).length,
          lessThanOrEqualTo(VpnEventReporter.probeUploadBytes),
        );
      }
      expect(uploads.expand((b) => b['items'] as List), hasLength(10));
      expect(await queued(), isEmpty);
    });

    group('when it runs', () {
      test('not at all without settings', () async {
        settings = null;
        expect(await runner().maybeRun(), 0);
        expect(requests, isEmpty);
      });

      test('once per network per interval', () async {
        final r = runner();
        expect(await r.maybeRun(), 10);
        requests.clear();

        now = now.add(const Duration(minutes: 359));
        expect(await r.maybeRun(), 0);
        expect(requests, isEmpty);

        // Another network is measured at once.
        network = 'mobile:MCI';
        expect(await r.maybeRun(), 10);

        // The first network again, once its interval is over.
        network = 'wifi';
        now = now.add(const Duration(minutes: 2));
        expect(await r.maybeRun(), 10);
      });

      test('the interval is the config\'s, not the app\'s', () async {
        settings = SizeProbeSettings.fromJson(block(minutes: 30));
        final r = runner();
        await r.maybeRun();
        now = now.add(const Duration(minutes: 31));
        expect(await r.maybeRun(), 10);
      });

      test('never while the user waits on a connect', () async {
        busy = true;
        expect(await runner().maybeRun(), 0);
        expect(requests, isEmpty);
      });

      test(
        'after an account deletion an old Wi-Fi key is not marked',
        () async {
          addTearDown(NetworkKeys.resetForTest);
          NetworkKeys.close();
          NetworkKeys.reopen();
          network = 'wifi:0123456789abcdef';
          expect(await runner().maybeRun(), 10);
          final prefs = await SharedPreferences.getInstance();
          expect(prefs.getStringList(SizeProbeRunner.marksKey), isNull);
        },
      );

      test('never where the app\'s requests go through the tunnel', () async {
        throughTunnel = true;
        expect(await runner().maybeRun(), 0);
        expect(requests, isEmpty);
      });

      test('never while sharing is off', () async {
        SharedPreferences.setMockInitialValues({
          VpnEventReporter.sharePrefKey: false,
        });
        expect(await runner().maybeRun(), 0);
        expect(requests, isEmpty);
      });

      // Every transfer would fail at once, and the backend would file the
      // failures under the carrier the phone reached next.
      test('never with no network, and the network is not marked', () async {
        networkType = null;
        network = SizeProbeRunner.noNetwork;
        final r = runner();
        expect(await r.maybeRun(), 0);
        expect(requests, isEmpty);
        expect(await queued(), isEmpty);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getStringList(SizeProbeRunner.marksKey), isNull);

        // Back on a line, it runs at once.
        networkType = 'wifi';
        network = 'wifi';
        expect(await r.maybeRun(), 10);
      });

      test('never on a network the platform does not name', () async {
        // Only the tunnel's own entry, or a failed read.
        networkType = null;
        expect(await runner().maybeRun(), 0);
        // The two reads disagree: the key says no network.
        networkType = 'wifi';
        network = SizeProbeRunner.noNetwork;
        expect(await runner().maybeRun(), 0);
        expect(requests, isEmpty);
      });

      test('a network that changes mid-run drops that route, and the run '
          'is not marked', () async {
        var reads = 0;
        // The first read starts the run; the phone has moved to mobile data
        // by the time the first route is done.
        Future<String> moving() async => reads++ == 0 ? 'wifi' : 'mobile:MCI';
        final r = runner(networkKey: moving);
        expect(await r.maybeRun(), 0);
        expect(requests, hasLength(5), reason: 'the first route ran');
        expect(await queued(), isEmpty);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getStringList(SizeProbeRunner.marksKey), isNull);

        // Back on the same wifi, it is still due.
        expect(await runner().maybeRun(), 10);
      });

      group('the settings are the backend\'s current ones', () {
        test('stale settings are fetched again before a run', () async {
          stale = true;
          onReload = () {
            stale = false;
            settings = SizeProbeSettings.fromJson(block(down: [800], up: []));
          };
          expect(await runner().maybeRun(), 2);
          expect(reloads, 1);
          expect(requests.map((r) => r.url.query), ['n=800', 'n=800']);
        });

        test('with no fresh settings after the fetch, nothing runs', () async {
          stale = true;
          final r = runner();
          expect(await r.maybeRun(), 0);
          expect(reloads, 1);
          expect(requests, isEmpty);
          final prefs = await SharedPreferences.getInstance();
          expect(prefs.getStringList(SizeProbeRunner.marksKey), isNull);
        });

        test('a fetch that turns the probe off stops it', () async {
          stale = true;
          onReload = () {
            stale = false;
            settings = null;
          };
          expect(await runner().maybeRun(), 0);
          expect(requests, isEmpty);
        });

        test('a network that is not due fetches nothing', () async {
          final r = runner();
          expect(await r.maybeRun(), 10);
          stale = true;
          now = now.add(const Duration(minutes: 30));
          expect(await r.maybeRun(), 0);
          expect(reloads, 0);
        });
      });

      test('a connect that starts mid-run stops it, and the network is '
          'measured again next time', () async {
        answer = (request, route) {
          // The user taps Connect during the third transfer.
          if (requests.length == 3) busy = true;
          return honest(request, route);
        };
        final r = runner();
        expect(await r.maybeRun(), 3);
        expect(requests, hasLength(3));
        // What was measured is kept.
        expect(await queued(), hasLength(3));

        busy = false;
        requests.clear();
        answer = honest;
        expect(await r.maybeRun(), 10);
      });

      test('two calls at once make one run', () async {
        final gate = Completer<void>();
        answer = (request, route) => honest(request, route);
        final r = SizeProbeRunner(
          settings: () => settings,
          busy: () => false,
          network: () async {
            await gate.future;
            return 'wifi';
          },
          networkType: () async => 'wifi',
          routes: () async => routes,
          client: (route, timeout) => MockClient((request) async {
            requests.add(request);
            return answer(request, route);
          }),
          results: results,
          now: () => now,
        );
        final first = r.maybeRun();
        final second = r.maybeRun();
        gate.complete();
        expect(await second, 0);
        expect(await first, 10);
      });
    });
  });

  test('a default client for the direct route is a plain one', () {
    final client = SizeProbeRunner.defaultClient(
      const SizeProbeRoute(name: 'direct', base: 'https://api.example.com'),
      const Duration(seconds: 8),
    );
    expect(client, isA<http.Client>());
    client.close();
  });

  test('the default routes are the direct one, then each relay', () async {
    SharedPreferences.setMockInitialValues({});
    // The relays the backend sent, so the test does not depend on the ones
    // compiled in, which the public copy of the repo does not have.
    ApiRelays.resetForTest();
    addTearDown(ApiRelays.resetForTest);
    const pin =
        'efefefefefefefefefefefefefefefefefefefefefefefefefefefefefefefef';
    await ApiRelays.adopt(const [
      ApiRelay(url: 'https://203.0.113.5:443', pin: pin),
      ApiRelay(url: 'https://[2001:db8::5]:443', pin: pin),
    ]);
    final routes = await SizeProbeRunner.defaultRoutes();
    expect(routes, hasLength(3));
    expect(routes.first.name, 'direct');
    expect(routes.first.relay, isNull);
    for (final r in routes.skip(1)) {
      expect(r.name, startsWith('relay:'));
      expect(r.relay, isNotNull);
      expect(Uri.parse(r.base).scheme, 'https');
    }
    // The app never measures through its own tunnel.
    expect(routes.map((r) => r.name), isNot(contains('tunnel')));
    expect(InternetAddress.tryParse(Uri.parse(routes[1].base).host), isNotNull);
  });
}

Map<String, dynamic> _config(Object? sizeProbe) => {
  'privacy_policy_url': 'https://example.com/privacy',
  'terms_of_service_url': 'https://example.com/terms',
  'eula_url': 'https://example.com/eula',
  'support_email': 'support@example.com',
  'force_update': {
    for (final os in ['ios', 'android'])
      os: {
        'latest_version': '1.0.0',
        'minimum_version': '1.0.0',
        'update_url': 'https://example.com/update',
      },
  },
  'size_probe': ?sizeProbe,
};
