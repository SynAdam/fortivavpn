import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/core/state/app_config_state.dart';
import 'package:fortiva_vpn/core/state/connect_flow.dart';
import 'package:fortiva_vpn/core/state/dedicated_state.dart';
import 'package:fortiva_vpn/core/state/locale_state.dart';
import 'package:fortiva_vpn/core/state/server_state.dart';
import 'package:fortiva_vpn/data/models/server.dart';
import 'package:fortiva_vpn/l10n/generated/app_localizations.dart';
import 'package:fortiva_vpn/screens/home_screen.dart';
import 'package:fortiva_vpn/screens/speed_test_screen.dart';
import 'package:fortiva_vpn/services/speed_test_service.dart';
import 'package:fortiva_vpn/services/vpn_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The speed test and the invite screen sit on the home screen as well as
/// in Settings. Invite follows the backend's switch, the same as Settings.
const _server = Server(
  id: 'official-1',
  name: 'DE Falkenstein',
  country: 'Germany',
  city: 'Falkenstein',
  connectionUri: 'vless://u@198.51.100.201:443?security=reality#DE',
  flagEmoji: '\u{1F1E9}\u{1F1EA}',
);

class _Dedicated extends DedicatedState {
  @override
  Server? get selectedServer => null;

  @override
  bool get hasServers => false;

  @override
  Future<void> refresh({bool? viaTunnel}) async {}

  @override
  int? pingFor(String serverId) => null;

  @override
  Future<void> pingServer(Server server) async {}
}

class _Servers extends ServerState {
  @override
  Server? get selectedServer => _server;

  @override
  Future<void> loadServers({bool forceRefresh = false}) async {}

  @override
  int? getPingResult(String serverId) => 42;

  @override
  Future<void> pingServer(Server server) async {}
}

/// The backend's referral switch, set by the test.
class _Config extends AppConfigState {
  _Config({required this.referrals});

  final bool referrals;

  @override
  bool get referralsEnabled => referrals;
}

void main() {
  const tunnel = MethodChannel('com.vpn.fortivavpn/tunnel');
  const statusChannel = EventChannel('com.vpn.fortivavpn/tunnel/status');

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(tunnel, (call) async {
      return call.method == 'getStatus' ? 'disconnected' : null;
    });
    messenger.setMockStreamHandler(
      statusChannel,
      MockStreamHandler.inline(onListen: (_, _) {}),
    );
  });

  tearDown(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(tunnel, null);
    messenger.setMockStreamHandler(statusChannel, null);
  });

  Future<void> pumpHome(WidgetTester tester, {required bool referrals}) async {
    final vpn = VpnService();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AppConfigState>.value(
            value: _Config(referrals: referrals),
          ),
          ChangeNotifierProvider<DedicatedState>.value(value: _Dedicated()),
          ChangeNotifierProvider<ServerState>.value(value: _Servers()),
          ChangeNotifierProvider<VpnService>.value(value: vpn),
          ChangeNotifierProvider<ConnectFlow>(
            create: (_) => ConnectFlow(vpn: vpn),
          ),
          ChangeNotifierProvider<LocaleState>(create: (_) => LocaleState()),
          ChangeNotifierProvider<SpeedTestService>(
            create: (_) => SpeedTestService(),
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: S.localizationsDelegates,
          supportedLocales: S.supportedLocales,
          locale: Locale('en'),
          home: HomeScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
  }

  testWidgets('shows the speed test and invite under the server card', (
    tester,
  ) async {
    await pumpHome(tester, referrals: true);

    final card = tester.getRect(find.text('Falkenstein, Germany'));
    final speed = tester.getRect(find.text('Speed test'));
    final invite = tester.getRect(find.text('Invite friends'));
    expect(speed.top, greaterThan(card.bottom));
    expect(invite.top, greaterThan(card.bottom));
    expect(tester.takeException(), isNull);
  });

  testWidgets('leaves invite out while the backend has referrals off', (
    tester,
  ) async {
    await pumpHome(tester, referrals: false);

    expect(find.text('Speed test'), findsOneWidget);
    expect(find.text('Invite friends'), findsNothing);
  });

  testWidgets('opens the speed test', (tester) async {
    await pumpHome(tester, referrals: false);

    await tester.tap(find.text('Speed test'));
    await tester.pumpAndSettle();

    expect(find.byType(SpeedTestScreen), findsOneWidget);
  });
}
