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

/// What the home screen says about a tunnel that is up and carries nothing
/// (#289): before, it said "Connected" for as long as the tunnel stayed up.
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
  _Vpn({this.up = false, this.dead = false});

  final bool up;
  final bool dead;

  @override
  VpnStatus get status => up ? VpnStatus.connected : VpnStatus.disconnected;

  @override
  bool get isConnected => up;

  @override
  bool get isConnecting => false;

  @override
  bool get isVerifying => false;

  @override
  bool get stalled => up && dead;

  @override
  ConnectionInfo? get currentConnection => null;

  @override
  Future<void> disconnect() async {}
}

/// A flow held at [fixed], searching after a dead tunnel or not, on the
/// stage [running] when one is given.
class _Held extends ConnectFlow {
  _Held(VpnService vpn, this.fixed, {this.stall = false, this.running})
    : super(vpn: vpn);

  final ConnectStage fixed;
  final bool stall;
  final RouteKind? running;

  @override
  ConnectStage get stage => fixed;

  @override
  bool get afterStall => stall;

  @override
  RouteKind? get route => running;
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
    _Vpn vpn,
    ConnectStage stage, {
    bool stall = false,
    RouteKind? running,
  }) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<DedicatedState>.value(value: _Dedicated()),
          ChangeNotifierProvider<ServerState>.value(value: _Servers()),
          ChangeNotifierProvider<VpnService>.value(value: vpn),
          ChangeNotifierProvider<ConnectFlow>(
            create: (_) => _Held(vpn, stage, stall: stall, running: running),
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

  testWidgets('a dead tunnel is not called connected', (tester) async {
    await pumpHome(tester, _Vpn(up: true, dead: true), ConnectStage.done);
    expect(
      find.text('Connected, but no data is getting through'),
      findsOneWidget,
    );
    expect(find.text('Connected'), findsNothing);
  });

  testWidgets('a live tunnel still says connected', (tester) async {
    await pumpHome(tester, _Vpn(up: true), ConnectStage.done);
    expect(find.text('Connected'), findsOneWidget);
  });

  testWidgets('the search after it says why it runs', (tester) async {
    await pumpHome(
      tester,
      _Vpn(up: true, dead: true),
      ConnectStage.diagnosing,
      stall: true,
    );
    expect(
      find.text('The connection stopped working. Finding another path.'),
      findsOneWidget,
    );
    expect(find.text('Finding a path'), findsNothing);
  });

  // The search after a dead tunnel runs the same stages as a tap's. Its
  // line still says why it runs, not which stage it is on.
  testWidgets('the search after it says why it runs while it tries our '
      'servers', (tester) async {
    await pumpHome(
      tester,
      _Vpn(up: true, dead: true),
      ConnectStage.diagnosing,
      stall: true,
      running: RouteKind.own,
    );
    expect(
      find.text('The connection stopped working. Finding another path.'),
      findsOneWidget,
    );
    expect(find.text('Trying Fortiva servers'), findsNothing);
  });

  testWidgets('a search after a tap says what it always said', (tester) async {
    await pumpHome(tester, _Vpn(), ConnectStage.diagnosing);
    expect(find.text('Finding a path'), findsOneWidget);
  });
}
