import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/data/models/server.dart';
import 'package:fortiva_vpn/services/path_finder.dart';
import 'package:fortiva_vpn/services/ping_service.dart';

/// A failed door check says why: whether the address took a TCP
/// connection, and what the core said. Until this, every failed check
/// reached the backend with no reason and, from the checklist, no time.
Server door(String host, String door) => Server(
  id: 'dedicated-$host:443',
  name: host,
  country: '',
  city: host,
  connectionUri:
      'vless://00000000-0000-0000-0000-000000000000@$host:443'
      '?type=ws&security=tls&sni=cdn.example.site#$host',
  flagEmoji: '🌍',
  isDedicated: true,
  door: door,
  doorLabel: door,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const tunnel = MethodChannel('com.vpn.fortivavpn/tunnel');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final cdn = door('198.51.100.215', 'ws-tls');

  tearDown(() => messenger.setMockMethodCallHandler(tunnel, null));

  group('the reason in words', () {
    test('an open address, then nothing', () {
      final e = DoorCheckFailed.fromNative({
        'ms': -1,
        'tcp': 'ok',
        'tcpMs': 84,
        'error': 'EOF',
      });
      expect(e.reason, 'tcp ok 84ms; EOF');
      expect(e.toString(), 'tcp ok 84ms; EOF');
    });

    test('a dropped address', () {
      final e = DoorCheckFailed.fromNative({
        'ms': -1,
        'tcp': 'timeout',
        'tcpMs': 2500,
        'error': 'no answer in 3000 ms',
      });
      expect(e.reason, 'tcp timeout; no answer in 3000 ms');
    });

    test('nothing to say still says something', () {
      expect(DoorCheckFailed.fromNative({'ms': -1}).reason, 'no answer');
      expect(
        DoorCheckFailed.fromNative({
          'ms': -1,
          'error': 'link could not be read',
        }).reason,
        'link could not be read',
      );
    });
  });

  group('checkDoor', () {
    test('an open door is its time', () async {
      messenger.setMockMethodCallHandler(tunnel, (call) async {
        expect(call.method, 'realPingDetail');
        return {'ms': 212, 'elapsedMs': 230};
      });
      expect(await PingService().checkDoor(cdn), 212);
    });

    test('a failed door throws its reason', () async {
      messenger.setMockMethodCallHandler(tunnel, (call) async {
        return {
          'ms': -1,
          'elapsedMs': 3004,
          'tcp': 'ok',
          'tcpMs': 91,
          'error': 'EOF',
        };
      });
      await expectLater(
        PingService().checkDoor(cdn),
        throwsA(
          isA<DoorCheckFailed>().having(
            (e) => e.reason,
            'reason',
            'tcp ok 91ms; EOF',
          ),
        ),
      );
    });

    test(
      'a native side without the detail falls back to the plain check',
      () async {
        final calls = <String>[];
        messenger.setMockMethodCallHandler(tunnel, (call) async {
          calls.add(call.method);
          if (call.method == 'realPingDetail') throw MissingPluginException();
          return 150;
        });
        expect(await PingService().checkDoor(cdn), 150);
        expect(calls, ['realPingDetail', 'realPing']);
      },
    );

    test('no answer at all names the wait', () async {
      messenger.setMockMethodCallHandler(tunnel, (call) async {
        await Future<void>.delayed(const Duration(milliseconds: 200));
        return {'ms': 10};
      });
      await expectLater(
        PingService().checkDoor(cdn, timeout: const Duration(milliseconds: 20)),
        throwsA(
          isA<DoorCheckFailed>().having(
            (e) => e.reason,
            'reason',
            'no answer in 20 ms',
          ),
        ),
      );
    });

    test('a link the app cannot read is never sent', () async {
      var called = false;
      messenger.setMockMethodCallHandler(tunnel, (call) async {
        called = true;
        return {'ms': 1};
      });
      final broken = Server(
        id: 'x',
        name: 'x',
        country: '',
        city: 'x',
        connectionUri: 'vless://short',
        flagEmoji: '🌍',
      );
      await expectLater(
        PingService().checkDoor(broken),
        throwsA(isA<DoorCheckFailed>()),
      );
      expect(called, isFalse);
    });
  });

  group('the checklist keeps it', () {
    test('a failed check carries the reason and how long it took', () async {
      final finder = PathFinder(
        probe: (p) async {
          await Future<void>.delayed(const Duration(milliseconds: 30));
          throw const DoorCheckFailed('tcp ok 84ms; EOF');
        },
        internet: () async => true,
      );
      final finding = await finder.find([cdn]);
      final check = finding.checks.single;
      expect(check.state, PathCheckState.blocked);
      expect(check.error, 'tcp ok 84ms; EOF');
      expect(check.ms, greaterThanOrEqualTo(30));
      expect(check.reportable, isTrue);
    });

    test('a probe that only says -1 still gets a time', () async {
      final finder = PathFinder(
        probe: (p) async => -1,
        internet: () async => true,
      );
      final check = (await finder.find([cdn])).checks.single;
      expect(check.state, PathCheckState.blocked);
      expect(check.error, isNull);
      expect(check.ms, isNotNull);
    });
  });
}
