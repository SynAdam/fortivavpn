import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/services/keeper.dart';
import 'package:fortiva_vpn/services/stored_from_background.dart';
import 'package:fortiva_vpn/services/vpn_event_reporter.dart';
import 'package:fortiva_vpn/services/vpn_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

/// The app's engine outlives the activity (AppEngine on Android). The
/// keeper marks an attempt it found dead from its own engine while the
/// app's engine waits without an activity, and the app's copy of the stored
/// values does not have the mark. The app reads the mark again when it comes
/// back and removes it, as a new engine used to. Left in place, it made
/// every later keeper run take the attempt as reported: no heartbeat, no
/// dropped event and no notification.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.vpn.fortivavpn/tunnel');
  late VpnService service;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => null);
    service = VpnService(events: VpnEventReporter(send: (_, _, _) async {}));
  });

  tearDown(() {
    service.dispose();
    StoredFromBackground.readOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('a mark the keeper left while the app was away is removed', () async {
    final prefs = await SharedPreferences.getInstance();
    final store = SharedPreferencesStorePlatform.instance;
    StoredFromBackground.readOverride = (key) async =>
        (await store.getAll())['flutter.$key'] as String?;
    service.debugAttemptId = 'tap-1';

    // The app looked at the attempt once, before the user swiped it away.
    await service.checkStall();
    // Then the keeper found the tunnel dead and marked the attempt. The
    // mark reaches the platform, not the app engine's copy.
    await store.setValue('String', 'flutter.${Keeper.stalledKey}', 'tap-1');
    expect(prefs.getString(Keeper.stalledKey), isNull);

    // The user opens the app again.
    await service.checkStall();
    expect(
      (await store.getAll()).containsKey('flutter.${Keeper.stalledKey}'),
      isFalse,
    );
  });
}
