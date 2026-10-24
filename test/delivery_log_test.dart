import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/api/api_client.dart';
import 'package:fortiva_vpn/api/api_routes.dart';
import 'package:fortiva_vpn/services/delivery_log.dart';
import 'package:fortiva_vpn/services/report_queue.dart';
import 'package:fortiva_vpn/services/vpn_event_reporter.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The record of the app's own uploads. A line can carry every small call
/// and none of the larger uploads, on any route, and the backend cannot
/// see it, because what it lacks is the uploads that never arrived. Each
/// try now leaves a row.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const relay = ApiRelay(url: 'https://203.0.113.5:443', pin: _pin);
  final now = DateTime.utc(2026, 10, 9, 6, 30);

  late List<Map<String, dynamic>> uploads;

  /// A log whose queue sends through [post], or nowhere.
  (DeliveryLog, ReportQueue) logWith({
    Future<void> Function(String, Map<String, dynamic>)? post,
    NetworkTypeProbe? networkType,
  }) {
    final queue = ReportQueue.deliveryLog(
      post: post ?? (_, body) async => uploads.add(body),
      deviceId: () async => 'c0ffee00deadbeef',
      clock: () => now,
    );
    return (
      DeliveryLog(
        queue: queue,
        networkType: networkType ?? () async => 'wifi',
        clock: () => now,
      ),
      queue,
    );
  }

  RouteAttempt attempt({
    String method = 'POST',
    String endpoint = '/api/v1/devices/c0ffee00deadbeef/events',
    String route = 'direct',
    int bytes = 6843,
    int ms = 10012,
    int? status,
    Object? error,
  }) => RouteAttempt(
    method: method,
    endpoint: endpoint,
    route: route,
    bytes: bytes,
    elapsed: Duration(milliseconds: ms),
    status: status,
    error: error,
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ReportQueue.resetForTest();
    uploads = [];
  });
  tearDown(() => ApiClient.onRouteAttempt = null);

  group('a try becomes a row', () {
    test('a failed upload, with its size, route and kind of failure', () async {
      final (log, queue) = logWith();
      log.record(
        attempt(error: TimeoutException('after 0:00:10.000000'), ms: 10012),
      );
      final rows = await queue.pending();
      expect(rows, [
        {
          'endpoint': '/devices/{id}/events',
          'route': 'direct',
          'bytes': 6843,
          'ok': false,
          'status': null,
          'ms': 10012,
          'error': 'timeout',
          'network_type': 'wifi',
          // When the try started, not when it ended.
          'client_ts': '2026-10-09T06:29:49.988Z',
        },
      ]);
    });

    test('an upload that arrived', () async {
      final (log, queue) = logWith();
      log.record(attempt(route: 'relay:203.0.113.5', status: 200, ms: 640));
      final row = (await queue.pending()).single;
      expect(row['ok'], isTrue);
      expect(row['status'], 200);
      expect(row['error'], isNull);
      expect(row['route'], 'relay:203.0.113.5');
    });

    test('an answer that is not 2xx is a failed try with its status', () async {
      final (log, queue) = logWith();
      log.record(attempt(status: 403));
      final row = (await queue.pending()).single;
      expect(row['ok'], isFalse);
      expect(row['status'], 403);
      expect(row['error'], isNull);
    });

    test('downloads are not uploads and are not kept', () async {
      final (log, queue) = logWith();
      log.record(attempt(method: 'GET', endpoint: '/api/v1/app/config'));
      expect(await queue.pending(), isEmpty);
    });

    test('a read of the fallback file is kept, under the host it came '
        'from', () async {
      final (log, queue) = logWith();
      log.record(
        attempt(
          method: 'GET',
          endpoint: '/bootstrap',
          route: 'mirror:cdn.jsdelivr.net',
          bytes: 0,
          status: 200,
          ms: 900,
        ),
      );
      final row = (await queue.pending()).single;
      expect(row['endpoint'], '/bootstrap');
      expect(row['route'], 'mirror:cdn.jsdelivr.net');
      expect(row['ok'], isTrue);
    });

    test('the log never keeps its own uploads', () async {
      final (log, queue) = logWith();
      log.record(
        attempt(endpoint: '/api/v1/devices/c0ffee00deadbeef/delivery-log'),
      );
      log.record(attempt(endpoint: '/api/v1/probe/bytes'));
      expect(await queue.pending(), isEmpty);
    });

    // The backend would file it under the carrier the log is sent from
    // later, which is not the line the try failed on.
    test('a try made with no network is not kept', () async {
      final (log, queue) = logWith(networkType: () async => null);
      log.record(attempt(error: const SocketException('Failed host lookup')));
      log.record(attempt(status: 200));
      expect(await queue.pending(), isEmpty);
    });

    test('nor one whose network the platform does not say in time', () async {
      final (log, queue) = logWith(
        networkType: () => Completer<String?>().future,
      );
      log.record(attempt(error: const SocketException('reset')));
      expect(await queue.pending(), isEmpty);
    });

    test('nothing is kept while sharing is off', () async {
      SharedPreferences.setMockInitialValues({'pref_share_diagnostics': false});
      final (log, queue) = logWith();
      log.record(attempt(error: const SocketException('reset')));
      expect(await queue.pending(), isEmpty);
    });
  });

  group('the endpoint is a template', () {
    for (final (endpoint, template) in [
      ('/api/v1/devices/c0ffee00deadbeef/events', '/devices/{id}/events'),
      ('/api/v1/devices/c0ffee00deadbeef/probes', '/devices/{id}/probes'),
      ('/api/v1/devices/register', '/devices/register'),
      ('/api/v1/devices/link-google', '/devices/link-google'),
      (
        '/api/v1/devices/c0ffee00deadbeef/billing?store=play',
        '/devices/{id}/billing',
      ),
      (
        '/api/v1/devices/c0ffee00deadbeef/support/1234/read',
        '/devices/{id}/support/{id}/read',
      ),
      // A device id with no digit in it is still an id.
      ('/api/v1/devices/abcdefabcdef/events', '/devices/{id}/events'),
      (
        '/api/v1/configs/'
            'abcdefghijklmnopqrstuvwxyzabcdefghijkl',
        '/configs/{id}',
      ),
    ]) {
      test('$endpoint reads $template', () {
        expect(DeliveryLog.pathTemplate(endpoint), template);
      });
    }
  });

  group('the kind of failure, never the address', () {
    for (final (error, kind) in <(Object, String)>[
      (TimeoutException('x'), 'timeout'),
      (
        const SocketException(
          'Connection refused',
          osError: OSError('Connection refused', 111),
          address: null,
          port: 443,
        ),
        'refused',
      ),
      (
        const SocketException('Connection reset by peer (OS Error: errno 104)'),
        'reset',
      ),
      (const SocketException('Network is unreachable'), 'unreachable'),
      (const SocketException('Failed host lookup: api.fortivavpn.com'), 'dns'),
      (const SocketException('Connection timed out'), 'timeout'),
      (
        const HandshakeException('Connection terminated during handshake'),
        'tls',
      ),
      (
        const HandshakeException(
          'Handshake error in client (OS Error: CERTIFICATE_VERIFY_FAILED)',
        ),
        'certificate',
      ),
      (const SocksException('proxy could not connect (reply 5)'), 'socks'),
      (http.ClientException('Connection closed before full header'), 'closed'),
      (const SocketException('something else, address = 10.1.2.3'), 'socket'),
      (StateError('odd'), 'StateError'),
    ]) {
      test('${error.runtimeType}: $kind', () {
        final got = DeliveryLog.errorClass(error)!;
        expect(got, kind);
        expect(got, isNot(contains('.')));
      });
    }
  });

  test('the 2026-10-07 line: a large upload is cut, a small one passes, '
      'and the log says so in the same flush', () async {
    final delivered = <String, List<Map<String, dynamic>>>{};
    late ApiClient client;
    Future<void> post(String path, Map<String, dynamic> body) async {
      await client.post(path, body: body);
    }

    client = ApiClient.forTest(
      // Every route carries a small body and cuts a large one.
      direct: MockClient((request) async {
        if (request.bodyBytes.length > 1000) {
          throw const SocketException('Connection reset by peer');
        }
        (delivered[request.url.path] ??= []).add(
          jsonDecode(request.body) as Map<String, dynamic>,
        );
        return http.Response('{"accepted": 1}', 200);
      }),
      tunnelPort: () async => null,
    );
    final (log, _) = logWith(post: post);
    DeliveryLog.install(log);
    final reporter = VpnEventReporter(
      post: post,
      deviceId: () async => 'c0ffee00deadbeef',
      appVersion: () async => '1.6.18',
      platform: 'android',
      networkType: () async => 'wifi',
      place: () async => null,
      linkFacts: () async => const {},
      register: () async {},
      queues: [
        // The same clock as the log: rows stamped [now] are older than
        // keptFor on the real clock from 18:30 UTC on 2026-10-09, and this
        // queue would drop them without sending.
        ReportQueue.deliveryLog(
          post: post,
          deviceId: () async => 'c0ffee00deadbeef',
          clock: () => now,
        ),
      ],
    );

    // A disconnect keeps the core log, so its upload is several KB.
    await reporter.record(
      VpnEventType.disconnected,
      diag: {'core_log': 'x' * 6000},
    );
    await reporter.flush();
    await reporter.flush();

    expect(delivered['/api/v1/devices/c0ffee00deadbeef/events'], isNull);
    final items = [
      for (final body
          in delivered['/api/v1/devices/c0ffee00deadbeef/delivery-log']!)
        ...(body['items'] as List).cast<Map<String, dynamic>>(),
    ];
    final cut = items.firstWhere(
      (i) => i['endpoint'] == '/devices/{id}/events',
    );
    expect(cut['ok'], isFalse);
    expect(cut['error'], 'reset');
    expect(cut['bytes'] as int, greaterThan(6000));
    expect(cut['route'], 'direct');
    // The log never names the device, and never logs itself.
    expect(jsonEncode(items), isNot(contains('c0ffee00deadbeef')));
    expect(items.map((i) => i['endpoint']), isNot(contains(endsWith('log'))));
  });

  group('through the real client', () {
    test('a direct route that drops the call and a relay that carries it '
        'are two rows', () async {
      final (log, queue) = logWith();
      DeliveryLog.install(log);
      final client = ApiClient.forTest(
        direct: MockClient(
          (_) async => throw const SocketException('Connection reset by peer'),
        ),
        relay: (_) => MockClient((_) async => http.Response('{}', 200)),
        relays: () async => [relay],
        tunnelPort: () async => null,
      );
      final body = {
        'events': [
          {'type': 'heartbeat'},
        ],
        'via_tunnel': false,
      };
      await client.post('/api/v1/devices/c0ffee00deadbeef/events', body: body);

      final rows = await queue.pending();
      expect(rows.map((r) => (r['route'], r['ok'], r['error'])), [
        ('direct', false, 'reset'),
        ('relay:203.0.113.5', true, null),
      ]);
      expect(rows.first['bytes'], utf8.encode(jsonEncode(body)).length);
    });

    test('sending the log adds nothing to the log, so it drains', () async {
      late ApiClient client;
      final (log, queue) = logWith(
        post: (path, body) async {
          await client.post(path, body: body);
        },
      );
      DeliveryLog.install(log);
      var failDirect = true;
      final sizes = <int>[];
      client = ApiClient.forTest(
        direct: MockClient((request) async {
          if (failDirect) throw const SocketException('Connection reset');
          if (request.url.path.endsWith('/delivery-log')) {
            sizes.add(request.bodyBytes.length);
          }
          return http.Response('{"accepted": 1}', 200);
        }),
        tunnelPort: () async => null,
      );

      // One failed upload of a report.
      await expectLater(
        client.post('/api/v1/devices/c0ffee00deadbeef/events', body: {}),
        throwsA(isA<ApiException>()),
      );
      expect(await queue.pending(), hasLength(1));

      // The line recovers; the log goes out and is empty after.
      failDirect = false;
      await queue.flush();
      await queue.flush();
      expect(sizes, hasLength(1));
      expect(sizes.single, lessThan(1000));
      expect(await queue.pending(), isEmpty);
    });
  });
}

const _pin = 'cdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcd';
