import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/api/api_client.dart';
import 'package:fortiva_vpn/api/config_service.dart';
import 'package:fortiva_vpn/core/state/app_config_state.dart';
import 'package:fortiva_vpn/core/state/connect_flow.dart';
import 'package:fortiva_vpn/core/state/dedicated_state.dart';
import 'package:fortiva_vpn/core/state/locale_state.dart';
import 'package:fortiva_vpn/core/state/notice_permission_prompt.dart';
import 'package:fortiva_vpn/core/state/server_state.dart';
import 'package:fortiva_vpn/data/models/app_config.dart';
import 'package:fortiva_vpn/data/models/connection_info.dart';
import 'package:fortiva_vpn/data/models/server.dart';
import 'package:fortiva_vpn/l10n/generated/app_localizations.dart';
import 'package:fortiva_vpn/screens/home_screen.dart';
import 'package:fortiva_vpn/services/notice_channel.dart';
import 'package:fortiva_vpn/services/vpn_service.dart';
import 'package:fortiva_vpn/widgets/message_dialog.dart';
import 'package:fortiva_vpn/widgets/update_dialog.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// When the home screen asks Android to allow message notifications
/// (HomeScreen._checkNoticePrompt): soon after a connect the user watched,
/// on an idle screen for users who never connect, whatever version they
/// run, and never on top of another page.

const _shared = Server(
  id: 'official-1',
  name: 'DE Falkenstein',
  country: 'Germany',
  city: 'Falkenstein',
  connectionUri: 'vless://u@198.51.100.201:443?security=reality#DE',
  flagEmoji: '\u{1F1E9}\u{1F1EA}',
);

/// A newer version is on Play than the one running, so the rating card's
/// gate would hold the question back for good.
AppConfig _behind() => AppConfig.fromJson({
  'privacy_policy_url': 'https://example.com/privacy',
  'terms_of_service_url': 'https://example.com/terms',
  'eula_url': 'https://example.com/eula',
  'support_email': 'support@example.com',
  'force_update': {
    for (final os in ['ios', 'android'])
      os: {
        'latest_version': '1.9.1',
        'minimum_version': '1.6.9',
        'update_url': 'https://example.com/update',
      },
  },
  'feature_flags': {'review_prompt': false},
});

class _FakeDedicated extends DedicatedState {
  @override
  QuotaStatus? get quota => null;

  @override
  bool get isBlocked => false;

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

class _FakeServers extends ServerState {
  @override
  Server? get selectedServer => _shared;

  @override
  Future<void> loadServers({bool forceRefresh = false}) async {}

  @override
  int? getPingResult(String serverId) => 42;

  @override
  Future<void> pingServer(Server server) async {}
}

class _FakeVpn extends VpnService {
  _FakeVpn(this._fake);

  VpnStatus _fake;

  void become(VpnStatus status) {
    _fake = status;
    notifyListeners();
  }

  @override
  VpnStatus get status => _fake;

  @override
  bool get isConnected => _fake == VpnStatus.connected;

  @override
  bool get isConnecting => _fake == VpnStatus.connecting;

  @override
  bool get isVerifying => false;

  @override
  ConnectionInfo? get currentConnection => _fake == VpnStatus.connected
      ? ConnectionInfo(
          startTime: DateTime.now(),
          serverId: 'x',
          serverName: 'DE',
        )
      : null;

  @override
  Future<void> disconnect() async => become(VpnStatus.disconnected);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const tunnel = MethodChannel('com.vpn.fortivavpn/tunnel');
  const statusChannel = EventChannel('com.vpn.fortivavpn/tunnel/status');

  late int asks;
  late NoticePermissionPrompt original;
  final navigator = GlobalKey<NavigatorState>();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    asks = 0;
    ApiConfig.appVersion = '1.9.0';
    UpdateDialog.resetForTest();
    MessageDialog.resetForTest();
    original = NoticePermissionPrompt.instance;
    NoticePermissionPrompt.instance = NoticePermissionPrompt(
      permission: () async => NoticePermission.ask,
      ask: () async {
        asks++;
        return NoticePermission.granted;
      },
      rationale: () async => false,
      openSettings: () async => true,
      isTv: () => false,
    );
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(tunnel, (call) async {
      return call.method == 'getStatus' ? 'connected' : null;
    });
    messenger.setMockStreamHandler(
      statusChannel,
      MockStreamHandler.inline(onListen: (_, _) {}),
    );
  });

  tearDown(() {
    NoticePermissionPrompt.instance = original;
    ApiConfig.appVersion = null;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(tunnel, null);
    messenger.setMockStreamHandler(statusChannel, null);
  });

  Future<_FakeVpn> pumpHome(WidgetTester tester, VpnStatus start) async {
    final vpn = _FakeVpn(start);
    final config = AppConfigState(fetch: () async => _behind());
    await config.load();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<DedicatedState>.value(value: _FakeDedicated()),
          ChangeNotifierProvider<ServerState>.value(value: _FakeServers()),
          ChangeNotifierProvider<VpnService>.value(value: vpn),
          ChangeNotifierProvider<ConnectFlow>(
            create: (_) => ConnectFlow(vpn: vpn),
          ),
          ChangeNotifierProvider<LocaleState>(create: (_) => LocaleState()),
          ChangeNotifierProvider<AppConfigState>.value(value: config),
        ],
        child: MaterialApp(
          navigatorKey: navigator,
          localizationsDelegates: S.localizationsDelegates,
          supportedLocales: S.supportedLocales,
          locale: const Locale('en'),
          home: const HomeScreen(),
        ),
      ),
    );
    await tester.pump();
    return vpn;
  }

  /// Let [time] pass in steps, so timers and the futures they start run.
  Future<void> wait(WidgetTester tester, Duration time) async {
    const step = Duration(milliseconds: 250);
    for (var t = Duration.zero; t < time; t += step) {
      await tester.pump(step);
    }
  }

  Future<void> end(WidgetTester tester, _FakeVpn vpn) async {
    vpn.become(VpnStatus.disconnected);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpWidget(const SizedBox());
  }

  testWidgets('asked 2 s after the tunnel comes up on screen, even with a '
      'newer version waiting', (tester) async {
    final vpn = await pumpHome(tester, VpnStatus.connecting);
    await wait(tester, const Duration(seconds: 3));
    expect(asks, 0, reason: 'not while connecting');

    vpn.become(VpnStatus.connected);
    await wait(tester, const Duration(seconds: 1));
    expect(asks, 0);
    await wait(tester, const Duration(seconds: 2));
    expect(asks, 1);

    await wait(tester, const Duration(seconds: 30));
    expect(asks, 1, reason: 'once per run');
    await end(tester, vpn);
  });

  testWidgets('opened with the tunnel already up: asked after 10 s of calm', (
    tester,
  ) async {
    final vpn = await pumpHome(tester, VpnStatus.connected);
    await wait(tester, const Duration(seconds: 8));
    expect(asks, 0);
    await wait(tester, const Duration(seconds: 3));
    expect(asks, 1);
    await end(tester, vpn);
  });

  testWidgets('never connected: asked on an idle home screen after 10 s, '
      'because the background check reaches them through the public file', (
    tester,
  ) async {
    final vpn = await pumpHome(tester, VpnStatus.disconnected);
    await wait(tester, const Duration(seconds: 11));
    expect(asks, 1);
    await end(tester, vpn);
  });

  testWidgets('a page on top holds the question; it comes once the page '
      'closes', (tester) async {
    final vpn = await pumpHome(tester, VpnStatus.connected);
    await wait(tester, const Duration(seconds: 2));
    navigator.currentState!.push(
      MaterialPageRoute<void>(builder: (_) => const Scaffold()),
    );
    await wait(tester, const Duration(seconds: 15));
    expect(asks, 0);

    navigator.currentState!.pop();
    await wait(tester, const Duration(seconds: 6));
    expect(asks, 1);
    await end(tester, vpn);
  });

  testWidgets('connecting resets the wait; nothing lands on the user\'s tap', (
    tester,
  ) async {
    final vpn = await pumpHome(tester, VpnStatus.disconnected);
    await wait(tester, const Duration(seconds: 8));
    vpn.become(VpnStatus.connecting);
    await wait(tester, const Duration(seconds: 5));
    expect(asks, 0);
    vpn.become(VpnStatus.connected);
    await wait(tester, const Duration(seconds: 3));
    expect(asks, 1);
    await end(tester, vpn);
  });
}
