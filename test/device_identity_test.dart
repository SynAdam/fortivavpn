import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/api/device_identity.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// This identifier is the only credential behind a device's VLESS configs
/// and its rolling allowance, so two devices must never resolve to the
/// same one.
///
/// They used to. `_platformInstallId` read `DeviceInfoPlugin().androidInfo.id`,
/// which the package populates from `Build.ID`: the ROM build label, the
/// same string on every phone running that build. Every install that
/// derived its identity therefore shared a device row, a VLESS client and
/// a 100 MB daily allowance with every other install on that build, and
/// the value was guessable by anyone holding the APK. See #124.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final channel = DeviceIdentity.platformChannel;
  late List<String> asked;
  String? answer;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    asked = [];
    answer = 'a1b2c3d4e5f60718';
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          asked.add(call.method);
          return call.method == 'installId' ? answer : null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test(
    'a stored id wins, so an existing install never changes identity',
    () async {
      // Step 3 of the resolution order is load-bearing: changing an existing
      // id resets that device's quota and orphans its panel clients.
      SharedPreferences.setMockInitialValues({
        DeviceIdentity.legacyPrefsKey: 'known-to-the-backend',
      });

      expect(await DeviceIdentity.instance.resolve(), 'known-to-the-backend');
      expect(asked, isEmpty, reason: 'nothing should be derived at all');
    },
  );

  test(
    'two devices with different platform ids get different identities',
    () async {
      answer = 'device-one';
      final first = await _freshResolve();

      answer = 'device-two';
      final second = await _freshResolve();

      expect(first, isNot(second));
    },
  );

  test('the raw platform id never leaves the phone', () async {
    answer = 'a1b2c3d4e5f60718';
    final id = await _freshResolve();

    // Hashed with an app salt, so learning a device's hardware id does not
    // hand over its Fortiva identity.
    expect(id, isNot(contains('a1b2c3d4e5f60718')));
    expect(id, matches(RegExp(r'^[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}$')));
  });

  test('a platform that answers nothing gets a random identity', () async {
    answer = null;
    final first = await _freshResolve();
    final second = await _freshResolve();

    // Random rather than derived: it loses reinstall survival and nothing
    // else, which beats a value shared with other devices.
    expect(first, isNot(second));
  });

  test('a blank answer is treated as no answer', () async {
    answer = '';
    final first = await _freshResolve();
    final second = await _freshResolve();

    expect(first, isNot(second));
  });

  test(
    'the identity is asked for over the platform channel, not device_info',
    () async {
      await _freshResolve();

      // device_info_plus offers Build.ID and calls it `id`. Reading it is
      // the bug in #124, and the only guard against it coming back is that
      // this asks the platform a question device_info_plus cannot answer.
      expect(asked, contains('installId'));
    },
  );
}

/// Resolve on an install that has nothing stored yet.
///
/// DeviceIdentity is a singleton with an in-memory cache, so a test that
/// wants a second first-launch has to clear both.
Future<String> _freshResolve() async {
  SharedPreferences.setMockInitialValues({});
  await DeviceIdentity.instance.clear();
  return DeviceIdentity.instance.resolve();
}
