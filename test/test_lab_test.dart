import 'dart:async';
import 'dart:convert';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/api/api_client.dart';
import 'package:fortiva_vpn/api/device_identity.dart';
import 'package:fortiva_vpn/api/device_service.dart';
import 'package:fortiva_vpn/services/device_place.dart';
import 'package:fortiva_vpn/services/test_lab.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Google Play runs every uploaded build on its pre-launch test devices
/// (Firebase Test Lab), and those runs report like any other phone. On
/// 2026-10-09 one such device made 12 of the 15 "every door closed" taps on
/// our dashboard. Register now says when the phone is one of them,
/// so the backend can leave it out, and says nothing on every other phone.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('test/test_lab');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  late List<String> asked;

  void answer(Object? Function(MethodCall call) handler) {
    messenger.setMockMethodCallHandler(channel, (call) async {
      asked.add(call.method);
      return handler(call);
    });
  }

  setUp(() {
    asked = [];
    // A stored id, so registering derives nothing from the platform.
    SharedPreferences.setMockInitialValues({
      DeviceIdentity.legacyPrefsKey: 'known-to-the-backend',
    });
  });
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  group('register', () {
    late List<Map<String, dynamic>> bodies;

    DeviceService service({required bool android}) {
      final client = ApiClient.forTest(
        direct: MockClient((request) async {
          bodies.add(jsonDecode(request.body) as Map<String, dynamic>);
          return http.Response(
            jsonEncode({
              'id': 1,
              'device_id': 'known-to-the-backend',
              'platform': 'android',
              'app_version': '1.6.17',
              'created_at': '2026-10-09T00:00:00Z',
            }),
            200,
          );
        }),
        tunnelPort: () async => null,
      );
      return DeviceService.forTest(
        client: client,
        place: DevicePlace(channel: channel),
        testLab: TestLab(channel: channel, android: android),
      );
    }

    setUp(() => bodies = []);

    test('a Test Lab device sends test_lab: true', () async {
      answer((call) => call.method == 'isTestLab' ? true : null);

      await service(android: true).registerDevice();

      expect(bodies.single['test_lab'], isTrue);
    });

    test('any other phone sends no test_lab key at all', () async {
      answer((call) => call.method == 'isTestLab' ? false : null);

      await service(android: true).registerDevice();

      expect(bodies.single.containsKey('test_lab'), isFalse);
      // The rest of the body is unchanged.
      expect(bodies.single['device_id'], 'known-to-the-backend');
    });

    test('the platform is asked once, not on every register', () async {
      answer((call) => call.method == 'isTestLab' ? true : null);
      final devices = service(android: true);

      await devices.registerDevice();
      await devices.registerDevice();

      expect(bodies.map((b) => b['test_lab']), [true, true]);
      expect(asked.where((m) => m == 'isTestLab'), hasLength(1));
    });
  });

  group('TestLab.read', () {
    test('off Android it is false and the platform is not asked', () async {
      answer((_) => true);

      expect(await TestLab(channel: channel, android: false).read(), isFalse);
      expect(asked, isEmpty);
    });

    test('a platform without the call, or one that fails, is false', () async {
      // No handler: MissingPluginException.
      expect(await TestLab(channel: channel, android: true).read(), isFalse);

      answer((_) => throw PlatformException(code: 'boom'));
      expect(await TestLab(channel: channel, android: true).read(), isFalse);

      answer((_) => null);
      expect(await TestLab(channel: channel, android: true).read(), isFalse);
    });

    test('a platform that never answers is false after the timeout', () {
      fakeAsync((async) {
        final stalled = Completer<Object?>();
        messenger.setMockMethodCallHandler(channel, (call) {
          asked.add(call.method);
          return stalled.future;
        });
        final lab = TestLab(channel: channel, android: true);

        bool? first;
        lab.read().then((v) => first = v);
        async.elapse(TestLab.timeout);
        expect(first, isFalse);

        // A timeout is not an answer, so the next read asks again.
        lab.read();
        async.flushMicrotasks();
        expect(asked, ['isTestLab', 'isTestLab']);
        async.elapse(TestLab.timeout);
      });
    });
  });
}
