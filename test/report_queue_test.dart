import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/api/api_client.dart';
import 'package:fortiva_vpn/services/report_queue.dart';
import 'package:fortiva_vpn/services/vpn_event_reporter.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The queue the size probe readings and the delivery log wait in. Every
/// upload has to stay under 1 KB, a size that a line which cuts larger
/// uploads can still carry, and rows have to survive a failed upload.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<({String path, Map<String, dynamic> body})> posts;
  late Object? Function(String path)? fail;
  late int registers;
  late DateTime now;

  ReportQueue queue({
    String key = 'test_queue',
    String path = 'size-probes',
    Duration keptFor = const Duration(minutes: 30),
    int maxRows = 50,
    bool Function(List<Map<String, dynamic>>)? sendWhen,
  }) => ReportQueue(
    storageKey: key,
    path: path,
    keptFor: keptFor,
    maxRows: maxRows,
    sendWhen: sendWhen,
    post: (p, body) async {
      final error = fail?.call(p);
      if (error != null) throw error;
      posts.add((path: p, body: jsonDecode(jsonEncode(body))));
    },
    deviceId: () async => 'DEV-1',
    register: () async => registers++,
    clock: () => now,
  );

  /// A size probe row of the size the app writes.
  Map<String, dynamic> row(int i, {bool ok = true}) => {
    'direction': i.isEven ? 'down' : 'up',
    'size': 200 + i,
    'ok': ok,
    'ms': 812 + i,
    'error': ok ? null : 'timeout',
    'route': 'relay:203.0.113.5',
    'network_type': 'wifi',
    'client_ts': '2026-10-09T06:12:41.123456Z',
    'attempt_id': '0123456789abcdef0123456789abcdef',
  };

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ReportQueue.resetForTest();
    posts = [];
    fail = null;
    registers = 0;
    now = DateTime.utc(2026, 10, 9, 6);
  });

  test('every upload stays under 1 KB and every row goes, in order', () async {
    final q = queue();
    final rows = [for (var i = 0; i < 30; i++) row(i)];
    await q.add(rows);
    await q.flush();

    expect(posts, isNotEmpty);
    expect(posts.length, greaterThan(1));
    for (final p in posts) {
      expect(p.path, '/api/v1/devices/DEV-1/size-probes');
      expect(
        utf8.encode(jsonEncode(p.body)).length,
        lessThanOrEqualTo(VpnEventReporter.probeUploadBytes),
      );
      expect(p.body.keys, ['items', 'sent_at']);
    }
    final sent = [
      for (final p in posts)
        for (final item in p.body['items'] as List) item,
    ];
    expect(sent, rows);
    expect(await q.pending(), isEmpty);
  });

  // The backend moves each client_ts onto its own clock by the gap between
  // sent_at and the time the upload arrived.
  test('every upload says when it left, read on each try', () async {
    final q = queue(keptFor: const Duration(hours: 12));
    await q.add([row(1)]);
    fail = (_) => ApiException(statusCode: 0, message: 'No internet');
    await q.flush();

    now = now.add(const Duration(hours: 3));
    fail = null;
    await q.flush();
    expect(posts.single.body['sent_at'], '2026-10-09T09:00:00.000Z');
  });

  test('the size counted for an upload is the size sent, with the longest '
      'sent_at the clock writes', () async {
    // A clock with microseconds writes the longest stamp.
    now = DateTime.utc(2026, 10, 9, 6, 12, 41, 123, 456);
    final q = queue();
    await q.add([row(1), row(2)]);
    await q.flush();
    final body = posts.single.body;
    expect(body['sent_at'], '2026-10-09T06:12:41.123456Z');
    expect(
      ReportQueue.uploadBytes([row(1), row(2)]),
      utf8.encode(jsonEncode(body)).length,
    );
  });

  test('a stored row never carries the queue\'s own id out', () async {
    final q = queue();
    await q.add([row(1)]);
    await q.flush();
    final item = (posts.single.body['items'] as List).single as Map;
    expect(item.containsKey('id'), isFalse);
    expect(item.containsKey('at'), isFalse);
  });

  test('a row larger than one upload goes alone', () {
    final big = {'error': 'x' * 1500};
    final small = row(1);
    final piece = ReportQueue.head([
      {'id': 'a', 'at': '', 'item': big},
      {'id': 'b', 'at': '', 'item': small},
    ]);
    expect(piece, hasLength(1));
    expect(piece.single['id'], 'a');
  });

  test('a failed upload keeps the rows for the next try', () async {
    final q = queue();
    await q.add([row(1), row(2)]);
    fail = (_) => ApiException(statusCode: 0, message: 'No internet');
    await q.flush();
    expect(posts, isEmpty);
    expect(await q.pending(), hasLength(2));

    fail = null;
    await q.flush();
    expect(await q.pending(), isEmpty);
    expect(posts.single.body['items'], hasLength(2));
  });

  test('an upload the backend refuses for good is dropped', () async {
    final q = queue();
    await q.add([row(1)]);
    fail = (_) => ApiException(statusCode: 422, message: 'Validation error');
    await q.flush();
    expect(await q.pending(), isEmpty);
  });

  test('a 404 registers the device and sends again', () async {
    final q = queue();
    await q.add([row(1)]);
    var calls = 0;
    fail = (_) =>
        calls++ == 0 ? ApiException(statusCode: 404, message: 'x') : null;
    await q.flush();
    expect(registers, 1);
    expect(posts, hasLength(1));
    expect(await q.pending(), isEmpty);
  });

  test(
    'a backend without the endpoint is not asked again in this run',
    () async {
      final q = queue();
      await q.add([row(1)]);
      var calls = 0;
      fail = (_) {
        calls++;
        return ApiException(statusCode: 404, message: 'Not Found');
      };
      await q.flush();
      expect(calls, 2);
      expect(registers, 1);
      // Kept, in case a later run of the app finds the endpoint.
      expect(await q.pending(), hasLength(1));

      await q.flush();
      expect(calls, 2, reason: 'no upload and no register on every flush');
      expect(registers, 1);
    },
  );

  test('rows past their time are dropped, not sent', () async {
    final q = queue(keptFor: const Duration(minutes: 30));
    await q.add([row(1)]);
    now = now.add(const Duration(minutes: 31));
    await q.add([row(2)]);
    await q.flush();
    expect(posts.single.body['items'], [row(2)]);
  });

  test('at most maxRows wait, the oldest dropped first', () async {
    final q = queue(maxRows: 3);
    await q.add([row(1), row(2), row(3), row(4)]);
    expect(await q.pending(), [row(2), row(3), row(4)]);
  });

  group('the sharing switch', () {
    test('off stores nothing and sends nothing', () async {
      SharedPreferences.setMockInitialValues({
        VpnEventReporter.sharePrefKey: false,
      });
      final q = queue();
      await q.add([row(1)]);
      await q.flush();
      expect(await q.pending(), isEmpty);
      expect(posts, isEmpty);
    });

    test('turned off drops every queue', () async {
      final sizes = ReportQueue.sizeProbes(
        post: (_, _) async => throw Exception('offline'),
        deviceId: () async => 'DEV-1',
      );
      final log = ReportQueue.deliveryLog(
        post: (_, _) async => throw Exception('offline'),
        deviceId: () async => 'DEV-1',
      );
      await sizes.add([row(1)]);
      await log.add([row(2, ok: false)]);
      expect(await sizes.pending(), hasLength(1));
      expect(await log.pending(), hasLength(1));

      await VpnEventReporter.setSharing(false);
      expect(await sizes.pending(), isEmpty);
      expect(await log.pending(), isEmpty);
    });
  });

  group('a queue sent on a failure or in full uploads (the delivery log)', () {
    List<Object?> sentItems() => [
      for (final p in posts)
        for (final item in p.body['items'] as List) item,
    ];

    test('the delivery log uses this rule', () async {
      final log = ReportQueue.deliveryLog(
        post: (_, body) async => posts.add((path: '', body: body)),
        deviceId: () async => 'DEV-1',
        clock: () => now,
      );
      await log.add([row(1), row(2)]);
      await log.flush();
      expect(posts, isEmpty);
      await log.add([row(3, ok: false)]);
      await log.flush();
      expect(sentItems(), [row(1), row(2), row(3, ok: false)]);
    });

    test('tries that worked and fit in one upload wait for more', () async {
      final q = queue(sendWhen: ReportQueue.failedOrFull);
      await q.add([row(1), row(2), row(3)]);
      await q.flush();
      expect(posts, isEmpty);
      expect(await q.pending(), hasLength(3));
    });

    test('tries that worked go once they fill an upload, in full uploads, '
        'and the rest wait', () async {
      final q = queue(sendWhen: ReportQueue.failedOrFull);
      final many = [for (var i = 0; i < 12; i++) row(i)];
      await q.add(many);
      await q.flush();
      expect(posts, isNotEmpty);
      final waiting = await q.pending();
      expect(waiting, isNotEmpty);
      expect(sentItems(), many.sublist(0, many.length - waiting.length));
      // What waits is less than one upload: a full upload would have gone.
      expect(
        ReportQueue.uploadBytes(waiting),
        lessThanOrEqualTo(VpnEventReporter.probeUploadBytes),
      );
      // Each upload that went was full: the next row would not have fitted.
      var next = 0;
      for (final p in posts) {
        final items = (p.body['items'] as List).cast<Map<String, dynamic>>();
        next += items.length;
        expect(
          ReportQueue.uploadBytes([...items, many[next]]),
          greaterThan(VpnEventReporter.probeUploadBytes),
        );
      }
    });

    test('a failure goes with the tries around it', () async {
      final q = queue(sendWhen: ReportQueue.failedOrFull);
      await q.add([row(1), row(2)]);
      await q.add([row(3, ok: false)]);
      await q.flush();
      expect(sentItems(), [row(1), row(2), row(3, ok: false)]);
      expect(await q.pending(), isEmpty);
    });

    test(
      'tries after the last failure wait once they fit in one upload',
      () async {
        final q = queue(sendWhen: ReportQueue.failedOrFull);
        final many = [row(0, ok: false), for (var i = 1; i < 12; i++) row(i)];
        await q.add(many);
        await q.flush();
        final sent = sentItems();
        expect(sent.first, row(0, ok: false));
        expect(sent.length, lessThan(many.length));
        final waiting = await q.pending();
        expect(waiting, many.sublist(sent.length));
        expect(
          ReportQueue.uploadBytes(waiting),
          lessThanOrEqualTo(VpnEventReporter.probeUploadBytes),
        );
      },
    );
  });

  test('two flushes at once send each upload once', () async {
    final q = queue();
    await q.add([for (var i = 0; i < 10; i++) row(i)]);
    await Future.wait([q.flush(), q.flush(), queue().flush()]);
    final sent = [
      for (final p in posts)
        for (final item in p.body['items'] as List) item,
    ];
    expect(sent, hasLength(10));
  });
}
