import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/api/api_client.dart';
import 'package:fortiva_vpn/api/config_service.dart';
import 'package:fortiva_vpn/core/state/app_config_state.dart';
import 'package:fortiva_vpn/core/state/connect_flow.dart';
import 'package:fortiva_vpn/core/state/dedicated_state.dart';
import 'package:fortiva_vpn/core/state/locale_state.dart';
import 'package:fortiva_vpn/core/state/message_state.dart';
import 'package:fortiva_vpn/core/state/review_prompt.dart';
import 'package:fortiva_vpn/core/state/server_state.dart';
import 'package:fortiva_vpn/data/models/app_config.dart';
import 'package:fortiva_vpn/data/models/connection_info.dart';
import 'package:fortiva_vpn/data/models/in_app_message.dart';
import 'package:fortiva_vpn/data/models/server.dart';
import 'package:fortiva_vpn/l10n/generated/app_localizations.dart';
import 'package:fortiva_vpn/screens/home_screen.dart';
import 'package:fortiva_vpn/services/vpn_service.dart';
import 'package:fortiva_vpn/widgets/message_dialog.dart';
import 'package:fortiva_vpn/widgets/update_dialog.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The home screen asks for the rating card only at a calm moment: the
/// tunnel up a while, nothing else on screen or waiting, no update
/// pending, and never after another popup in the same run.

const _shared = Server(
  id: 'official-1',
  name: 'DE Falkenstein',
  country: 'Germany',
  city: 'Falkenstein',
  connectionUri: 'vless://u@198.51.100.201:443?security=reality#DE',
  flagEmoji: '\u{1F1E9}\u{1F1EA}',
);

/// The waits in the home screen's state: the rating card's, and the
/// message popup's.
const _reviewSettle = Duration(seconds: 10);
const _popupSettle = Duration(seconds: 5);

AppConfig configWith({required bool reviewPrompt}) => AppConfig.fromJson({
  'privacy_policy_url': 'https://example.com/privacy',
  'terms_of_service_url': 'https://example.com/terms',
  'eula_url': 'https://example.com/eula',
  'support_email': 'support@example.com',
  'force_update': {
    for (final os in ['ios', 'android'])
      os: {
        'latest_version': '1.6.11',
        'minimum_version': '1.6.9',
        'update_url': 'https://example.com/update',
      },
  },
  'feature_flags': {'review_prompt': reviewPrompt},
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

/// A tunnel that has been up and checked for [upFor].
class _FakeVpn extends VpnService {
  _FakeVpn(Duration upFor)
    : _since = DateTime.now().subtract(upFor),
      _fake = VpnStatus.connected;

  final DateTime _since;
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
      ? ConnectionInfo(startTime: _since, serverId: 'x', serverName: 'DE')
      : null;

  @override
  Future<void> disconnect() async => become(VpnStatus.disconnected);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const tunnel = MethodChannel('com.vpn.fortivavpn/tunnel');
  const statusChannel = EventChannel('com.vpn.fortivavpn/tunnel/status');

  late int requests;

  /// Test time passed by [wait]. Timers run on test time but DateTime.now
  /// does not, so the prompt's clock adds it.
  late Duration elapsed;

  setUp(() {
    // Three good days on record, the last one today.
    final today = DateTime.now();
    SharedPreferences.setMockInitialValues({
      ReviewPrompt.stateKey: jsonEncode({
        'days': [
          for (var i = 2; i >= 0; i--)
            ReviewPrompt.tehranDay(today.subtract(Duration(days: i))),
        ],
        'asks': 0,
      }),
    });
    requests = 0;
    elapsed = Duration.zero;
    ApiConfig.appVersion = '1.6.11';
    UpdateDialog.resetForTest();
    MessageDialog.resetForTest();
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
    ApiConfig.appVersion = null;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(tunnel, null);
    messenger.setMockStreamHandler(statusChannel, null);
  });

  /// The home screen over a tunnel up for [upFor], with the switch as
  /// given and [messages] above it.
  Future<_FakeVpn> pumpHome(
    WidgetTester tester, {
    Duration upFor = const Duration(minutes: 30),
    bool enabled = true,
    MessageState? messages,
  }) async {
    final vpn = _FakeVpn(upFor);
    final config = AppConfigState(
      fetch: () async => configWith(reviewPrompt: enabled),
    );
    await config.load();
    final review = ReviewPrompt(
      installer: () async => ReviewPrompt.playInstaller,
      request: () async {
        requests++;
        return null;
      },
      clock: () => DateTime.now().add(elapsed),
    );
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
          ChangeNotifierProvider<ReviewPrompt>.value(value: review),
          if (messages != null)
            ChangeNotifierProvider<MessageState>(
              lazy: false,
              create: (_) => messages,
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
    return vpn;
  }

  /// Bring the tunnel down at the end of a test, which stops the timers
  /// the screen and the service run while connected.
  Future<void> down(WidgetTester tester, _FakeVpn vpn) async {
    vpn.become(VpnStatus.disconnected);
    await tester.pump(const Duration(seconds: 1));
  }

  /// Let [time] pass in steps, so timers and the futures they start run.
  Future<void> wait(WidgetTester tester, Duration time) async {
    for (var i = 0; i < time.inSeconds; i++) {
      elapsed += const Duration(seconds: 1);
      await tester.pump(const Duration(seconds: 1));
    }
  }

  testWidgets('asks once the screen has been calm for the settle time', (
    tester,
  ) async {
    final vpn = await pumpHome(tester);
    await wait(tester, _reviewSettle - const Duration(seconds: 1));
    expect(requests, 0);
    await wait(tester, const Duration(seconds: 2));
    expect(requests, 1);
    await wait(tester, const Duration(minutes: 1));
    expect(requests, 1);
    await down(tester, vpn);
  });

  testWidgets('waits until the tunnel has been up five minutes', (
    tester,
  ) async {
    final vpn = await pumpHome(tester, upFor: const Duration(minutes: 1));
    await wait(tester, const Duration(minutes: 3, seconds: 58));
    expect(requests, 0);
    await wait(tester, const Duration(seconds: 5));
    expect(requests, 1);
    await down(tester, vpn);
  });

  testWidgets('never while the switch is off', (tester) async {
    final vpn = await pumpHome(tester, enabled: false);
    await wait(tester, const Duration(seconds: 30));
    expect(requests, 0);
    await down(tester, vpn);
  });

  testWidgets('not if the user disconnects before the settle', (tester) async {
    final vpn = await pumpHome(tester);
    await wait(tester, const Duration(seconds: 5));
    vpn.become(VpnStatus.disconnected);
    await wait(tester, const Duration(seconds: 30));
    expect(requests, 0);
    await down(tester, vpn);
  });

  testWidgets('not while an update is waiting', (tester) async {
    ApiConfig.appVersion = '1.6.10';
    final vpn = await pumpHome(tester);
    await wait(tester, const Duration(seconds: 30));
    expect(requests, 0);
    await down(tester, vpn);
  });

  testWidgets('not after a message popped up in the same run', (tester) async {
    final sent = DateTime.now().toUtc().subtract(const Duration(minutes: 1));
    final messages = MessageState(
      fetch: (_, _) async => MessagesPage.fromJson({
        'server_time': DateTime.now().toUtc().toIso8601String(),
        'messages': [
          {
            'id': 1,
            'language': 'en',
            'title': 'News',
            'body': 'Body',
            'button': null,
            'link': null,
            'sent_at': sent.toIso8601String(),
            'ends_at': sent.add(const Duration(days: 7)).toIso8601String(),
          },
        ],
      }),
      post: (_, _) async {},
      deviceId: () async => 'DEV-1',
      register: () async {},
      language: () => 'en',
      flushDelay: const Duration(days: 1),
    );
    await messages.refresh();
    final vpn = await pumpHome(tester, messages: messages);
    await wait(tester, _popupSettle + const Duration(seconds: 1));
    await tester.pump();
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Body'),
      ),
      findsOneWidget,
    );
    // Closed again, so only the run's earlier popup stands in the way.
    await tester.tap(find.text('Close'));
    await tester.pump();
    await wait(tester, const Duration(seconds: 30));
    expect(messages.poppedThisRun, isTrue);
    expect(requests, 0);
    await down(tester, vpn);
  });
}
