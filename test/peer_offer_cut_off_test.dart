import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/api/bootstrap.dart';
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

/// The offer to get help from a friend's phone (#265) when only the way
/// abroad is cut (#269). The hosts abroad are what failed then, and a
/// friend's phone may have the file they could not give.
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

/// A flow held at [fixed].
class _Held extends ConnectFlow {
  _Held(VpnService vpn, this.fixed) : super(vpn: vpn);

  final ConnectStage fixed;

  @override
  ConnectStage get stage => fixed;
}

/// A phone whose last read of the hosts found nothing.
class _NothingFound extends Bootstrap {
  _NothingFound() : super(seed: () async => null, builtIn: const []);

  @override
  bool get nothingFound => true;
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

  Future<void> pumpHome(WidgetTester tester, ConnectStage stage) async {
    final vpn = _Vpn();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<DedicatedState>.value(value: _Dedicated()),
          ChangeNotifierProvider<ServerState>.value(value: _Servers()),
          ChangeNotifierProvider<VpnService>.value(value: vpn),
          ChangeNotifierProvider<ConnectFlow>(create: (_) => _Held(vpn, stage)),
          ChangeNotifierProvider<Bootstrap>.value(value: _NothingFound()),
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

  const offer =
      'Still cannot connect? A friend whose Fortiva works can help from '
      'their phone.';

  testWidgets('the offer shows when only the way abroad is cut', (
    tester,
  ) async {
    await pumpHome(tester, ConnectStage.cutOff);
    expect(find.text(offer), findsOneWidget);
  });

  testWidgets('and still when every door was closed', (tester) async {
    await pumpHome(tester, ConnectStage.nothingOpen);
    expect(find.text(offer), findsOneWidget);
  });

  testWidgets('not before a tap has ended', (tester) async {
    await pumpHome(tester, ConnectStage.idle);
    expect(find.text(offer), findsNothing);
  });
}
