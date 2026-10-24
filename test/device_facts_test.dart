import 'dart:async';
import 'dart:convert';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/api/api_client.dart';
import 'package:fortiva_vpn/api/device_facts.dart';
import 'package:fortiva_vpn/api/device_identity.dart';
import 'package:fortiva_vpn/api/device_service.dart';
import 'package:fortiva_vpn/services/device_place.dart';
import 'package:fortiva_vpn/services/test_lab.dart';
import 'package:fortiva_vpn/services/vpn_event_reporter.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The backend has had device_model and os_version since the first
/// release, and on 2026-10-09 they were empty on every device looked at:
/// no build sent them. Register now does, on Android.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('test/device_facts');
  const samsung = (
    manufacturer: 'samsung',
    model: 'SM-A515F',
    release: '13',
    sdk: 33,
  );

  late List<Map<String, dynamic>> bodies;
  late int reads;

  DeviceService service({AndroidBuild build = samsung, bool android = true}) {
    final client = ApiClient.forTest(
      direct: MockClient((request) async {
        bodies.add(jsonDecode(request.body) as Map<String, dynamic>);
        return http.Response(
          jsonEncode({
            'id': 1,
            'device_id': 'known-to-the-backend',
            'platform': 'android',
            'app_version': '1.6.18',
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
      testLab: TestLab(channel: channel, android: false),
      facts: DeviceFacts(
        android: () async {
          reads++;
          return build;
        },
        isAndroid: android,
      ),
    );
  }

  setUp(() {
    bodies = [];
    reads = 0;
    SharedPreferences.setMockInitialValues({
      DeviceIdentity.legacyPrefsKey: 'known-to-the-backend',
    });
  });

  group('register', () {
    test('sends the model and the Android version', () async {
      await service().registerDevice();
      expect(bodies.single['device_model'], 'samsung SM-A515F');
      expect(bodies.single['os_version'], 'Android 13 (API 33)');
    });

    test('sends them on every register, read from the phone once', () async {
      final devices = service();
      await devices.registerDevice();
      await devices.registerDevice();
      expect(bodies.map((b) => b['device_model']), [
        'samsung SM-A515F',
        'samsung SM-A515F',
      ]);
      expect(reads, 1);
    });

    test('a caller that names them wins', () async {
      await service().registerDevice(deviceModel: 'x', osVersion: 'y');
      expect(bodies.single['device_model'], 'x');
      expect(bodies.single['os_version'], 'y');
    });

    test('sends neither while sharing is off', () async {
      SharedPreferences.setMockInitialValues({
        DeviceIdentity.legacyPrefsKey: 'known-to-the-backend',
        VpnEventReporter.sharePrefKey: false,
      });
      await service().registerDevice();
      expect(bodies.single.containsKey('device_model'), isFalse);
      expect(bodies.single.containsKey('os_version'), isFalse);
      expect(bodies.single['device_id'], 'known-to-the-backend');
    });

    test('off Android sends neither, as before', () async {
      await service(android: false).registerDevice();
      expect(bodies.single.containsKey('device_model'), isFalse);
      expect(bodies.single.containsKey('os_version'), isFalse);
      expect(reads, 0);
    });

    test('a phone that will not say still registers', () async {
      final devices = DeviceService.forTest(
        client: ApiClient.forTest(
          direct: MockClient((request) async {
            bodies.add(jsonDecode(request.body) as Map<String, dynamic>);
            return http.Response(
              jsonEncode({
                'id': 1,
                'device_id': 'known-to-the-backend',
                'platform': 'android',
                'app_version': '1.6.18',
                'created_at': '2026-10-09T00:00:00Z',
              }),
              200,
            );
          }),
          tunnelPort: () async => null,
        ),
        place: DevicePlace(channel: channel),
        testLab: TestLab(channel: channel, android: false),
        facts: DeviceFacts(
          android: () async => throw PlatformException(code: 'boom'),
          isAndroid: true,
        ),
      );
      await devices.registerDevice();
      expect(bodies.single.containsKey('device_model'), isFalse);
    });
  });

  group('the words', () {
    test('the model is the maker and the model, trimmed', () {
      expect(DeviceFacts.modelOf(samsung), 'samsung SM-A515F');
      expect(
        DeviceFacts.modelOf((
          manufacturer: ' Xiaomi ',
          model: '',
          release: null,
          sdk: null,
        )),
        'Xiaomi',
      );
      expect(
        DeviceFacts.modelOf((
          manufacturer: null,
          model: null,
          release: '14',
          sdk: 34,
        )),
        isNull,
      );
    });

    test('the version names Android and the API level', () {
      expect(DeviceFacts.osVersionOf(samsung), 'Android 13 (API 33)');
      expect(
        DeviceFacts.osVersionOf((
          manufacturer: null,
          model: null,
          release: null,
          sdk: 29,
        )),
        '(API 29)',
      );
      expect(
        DeviceFacts.osVersionOf((
          manufacturer: null,
          model: null,
          release: ' ',
          sdk: null,
        )),
        isNull,
      );
    });

    test('both fit the backend columns, or register would fail', () {
      final long = (
        manufacturer: 'm' * 200,
        model: 'n' * 200,
        release: 'r' * 80,
        sdk: 35,
      );
      expect(DeviceFacts.modelOf(long)!.length, 255);
      expect(DeviceFacts.osVersionOf(long)!.length, 50);
    });
  });

  test('a phone that never answers is asked again next time', () {
    fakeAsync((async) {
      var asked = 0;
      final stalled = Completer<AndroidBuild>();
      final facts = DeviceFacts(
        android: () {
          asked++;
          return stalled.future;
        },
        isAndroid: true,
      );
      ({String? model, String? osVersion})? first;
      facts.read().then((v) => first = v);
      async.elapse(DeviceFacts.timeout);
      expect(first?.model, isNull);
      expect(first, isNotNull);

      facts.read();
      async.flushMicrotasks();
      expect(asked, 2);
      async.elapse(DeviceFacts.timeout);
    });
  });
}
