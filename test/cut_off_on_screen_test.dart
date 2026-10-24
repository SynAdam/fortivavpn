import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/api/config_service.dart';
import 'package:fortiva_vpn/core/state/connect_flow.dart';
import 'package:fortiva_vpn/core/state/dedicated_state.dart';
import 'package:fortiva_vpn/core/state/locale_state.dart';
import 'package:fortiva_vpn/core/state/server_state.dart';
import 'package:fortiva_vpn/data/models/connection_info.dart';
import 'package:fortiva_vpn/data/models/server.dart';
import 'package:fortiva_vpn/l10n/generated/app_localizations.dart';
import 'package:fortiva_vpn/screens/home_screen.dart';
import 'package:fortiva_vpn/services/vpn_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// What the home screen says when the way abroad is cut, and why a tap that
/// keeps searching is waiting (#269). Before 1.9.0 every wait said "Every
/// path is blocked", and a cut way abroad said "Your phone has no
/// internet", which was not true.
const _ours = Server(
  id: 'dedicated-0',
  name: 'Fortiva DE',
  country: 'Germany',
  city: 'Falkenstein',
  connectionUri: 'vless://ours@198.51.100.201:443?security=reality#ours',
  flagEmoji: '\u{1F1E9}\u{1F1EA}',
  isDedicated: true,
);

class _Dedicated extends DedicatedState {
  @override
  QuotaStatus? get quota => QuotaStatus(
    unlimited: false,
    limitBytes: 100 << 20,
    usedBytes: 10 << 20,
    remainingBytes: 90 << 20,
    blocked: false,
    resetsAt: DateTime.now().add(const Duration(hours: 3)),
  );

  @override
  bool get isBlocked => false;

  @override
  Server? get selectedServer => _ours;

  @override
  bool get hasServers => true;

  @override
  List<Server> get servers => const [_ours];

  @override
  List<Server> get paths => const [_ours];

  @override
  Future<void> refresh({bool? viaTunnel}) async {}

  @override
  int? pingFor(String serverId) => null;

  @override
  Future<void> pingServer(Server server) async {}
}

class _Servers extends ServerState {
  @override
  Future<void> loadServers({bool forceRefresh = false}) async {}

  @override
  int? getPingResult(String serverId) => 42;

  @override
  Future<void> pingServer(Server server) async {}
}

class _Vpn extends VpnService {
  @override
  VpnStatus get status => VpnStatus.disconnected;

  @override
  bool get isConnected => false;

  @override
  bool get isConnecting => false;

  @override
  bool get isVerifying => false;

  @override
  ConnectionInfo? get currentConnection => null;

  @override
  Future<void> disconnect() async {}
}

/// A flow held at [fixed], waiting after [after].
class _Held extends ConnectFlow {
  _Held(VpnService vpn, this.fixed, [this.after]) : super(vpn: vpn);

  final ConnectStage fixed;
  final ConnectStage? after;

  @override
  ConnectStage get stage => fixed;

  @override
  ConnectStage? get waitingAfter =>
      fixed == ConnectStage.waiting ? after : null;
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

  Future<void> pumpHome(
    WidgetTester tester,
    ConnectStage stage, [
    ConnectStage? after,
  ]) async {
    final vpn = _Vpn();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<DedicatedState>.value(value: _Dedicated()),
          ChangeNotifierProvider<ServerState>.value(value: _Servers()),
          ChangeNotifierProvider<VpnService>.value(value: vpn),
          ChangeNotifierProvider<ConnectFlow>(
            create: (_) => _Held(vpn, stage, after),
          ),
          ChangeNotifierProvider<LocaleState>(create: (_) => LocaleState()),
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

  testWidgets('a cut way abroad is named, not called no internet', (
    tester,
  ) async {
    await pumpHome(tester, ConnectStage.cutOff);
    expect(
      find.text(
        'Your network cannot reach the international internet right now. '
        'Tap to try again.',
      ),
      findsOneWidget,
    );
    expect(find.text('Your phone has no internet right now.'), findsNothing);
  });

  testWidgets('a wait after a cut says why', (tester) async {
    await pumpHome(tester, ConnectStage.waiting, ConnectStage.cutOff);
    expect(
      find.text(
        'Your network cannot reach the international internet right now. '
        'Trying again soon.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('a wait after no internet says why', (tester) async {
    await pumpHome(tester, ConnectStage.waiting, ConnectStage.noInternet);
    expect(
      find.text('Your phone has no internet right now. Trying again soon.'),
      findsOneWidget,
    );
  });

  testWidgets('a wait after every path was closed says so, as before', (
    tester,
  ) async {
    await pumpHome(tester, ConnectStage.waiting, ConnectStage.nothingOpen);
    expect(
      find.text('Every path is blocked right now. Trying again soon.'),
      findsOneWidget,
    );
  });
}
