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
import 'package:fortiva_vpn/services/path_finder.dart';
import 'package:fortiva_vpn/services/vpn_service.dart';
import 'package:fortiva_vpn/widgets/path_checklist.dart';
import 'package:fortiva_vpn/widgets/server_title.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// What the screens say about the backup network (clients #299): the
/// status line while it is dialled and once it carries the tunnel, the
/// home card, the checklist row and the session history. None of them
/// names the network.
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
  int? pingFor(String serverId) => 42;

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
  _Vpn({
    this.fixed = VpnStatus.disconnected,
    this.verifying = false,
    this.dead = false,
    this.backup = false,
    this.region,
  });

  final VpnStatus fixed;
  final bool verifying;
  final bool dead;
  final bool backup;
  final String? region;

  @override
  VpnStatus get status => fixed;

  @override
  bool get isConnected => fixed == VpnStatus.connected;

  @override
  bool get isConnecting => fixed == VpnStatus.connecting;

  @override
  bool get isVerifying => verifying;

  @override
  bool get stalled => dead;

  @override
  bool get onPsiphon => backup;

  @override
  String? get psiphonRegion => region;

  @override
  ConnectionInfo? get currentConnection => fixed == VpnStatus.disconnected
      ? null
      : ConnectionInfo(
          startTime: DateTime.now(),
          serverId: backup ? Server.psiphonId : _ours.id,
          serverName: backup ? Server.psiphonName : _ours.name,
        );

  @override
  Future<void> disconnect() async {}
}

/// A flow held at [fixed], on [on], with the stage of [route] running.
class _Held extends ConnectFlow {
  _Held(
    VpnService vpn,
    this.fixed, {
    this.on,
    this.rows = const [],
    this.running,
  }) : super(vpn: vpn);

  final ConnectStage fixed;
  final Server? on;
  final List<PathCheck> rows;
  final RouteKind? running;

  @override
  RouteKind? get route => running;

  @override
  StageState stageState(RouteKind kind) =>
      kind == running ? StageState.running : StageState.pending;

  @override
  bool stageAvailable(RouteKind kind) => true;

  @override
  ConnectStage get stage => fixed;

  @override
  Server? get chosen => on;

  @override
  List<PathCheck> get checks => rows;

  @override
  bool? get internet => true;

  @override
  bool get tryingBackup =>
      fixed == ConnectStage.connecting && (on?.isPsiphon ?? false);
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
    Server? on,
    String locale = 'en',
  }) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<DedicatedState>.value(value: _Dedicated()),
          ChangeNotifierProvider<ServerState>.value(value: _Servers()),
          ChangeNotifierProvider<VpnService>.value(value: vpn),
          ChangeNotifierProvider<ConnectFlow>(
            create: (_) => _Held(vpn, stage, on: on),
          ),
          ChangeNotifierProvider<LocaleState>(create: (_) => LocaleState()),
        ],
        child: MaterialApp(
          localizationsDelegates: S.localizationsDelegates,
          supportedLocales: S.supportedLocales,
          locale: Locale(locale),
          home: const HomeScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
  }

  void expectNoName() {
    expect(
      find.textContaining(RegExp('psiphon', caseSensitive: false)),
      findsNothing,
    );
  }

  group('the home screen', () {
    testWidgets('says so while it dials the backup network', (tester) async {
      await pumpHome(
        tester,
        _Vpn(fixed: VpnStatus.connecting, backup: true),
        ConnectStage.connecting,
        on: Server.psiphon,
      );
      expect(
        find.text('Nothing else connected. Trying a backup network now.'),
        findsOneWidget,
      );
      expectNoName();
    });

    testWidgets('says so once connected through it, and the card says what '
        'it is', (tester) async {
      await pumpHome(
        tester,
        _Vpn(fixed: VpnStatus.connected, backup: true),
        ConnectStage.done,
        on: Server.psiphon,
      );
      expect(find.text('Connected through a backup network'), findsOneWidget);
      expect(find.text('Connected'), findsNothing);
      expect(find.text('BACKUP NETWORK'), findsOneWidget);
      expect(
        find.text(
          'Used when nothing else connects. It can be slower than our '
          'servers.',
        ),
        findsOneWidget,
      );
      expect(find.text('Location picked automatically'), findsOneWidget);
      // Not the selection's name, place or ping: none of them carries the
      // traffic.
      expect(find.text('Falkenstein, Germany'), findsNothing);
      expect(find.text('42 ms'), findsNothing);
      expect(find.text('YOUR SERVER'), findsNothing);
      expectNoName();
    });

    testWidgets('names the country the traffic leaves from once known', (
      tester,
    ) async {
      await pumpHome(
        tester,
        _Vpn(fixed: VpnStatus.connected, backup: true, region: 'DE'),
        ConnectStage.done,
        on: Server.psiphon,
      );
      expect(find.text('Germany'), findsOneWidget);
      expect(find.text('\u{1F1E9}\u{1F1EA}'), findsOneWidget);
      expect(find.text('Location picked automatically'), findsNothing);
    });

    testWidgets('a region the app has no name for reads as picked '
        'automatically', (tester) async {
      await pumpHome(
        tester,
        _Vpn(fixed: VpnStatus.connected, backup: true, region: 'XQ'),
        ConnectStage.done,
        on: Server.psiphon,
      );
      expect(find.text('Location picked automatically'), findsOneWidget);
      expect(find.text('XQ'), findsNothing);
    });

    testWidgets('a dead tunnel through it says so, as on any other', (
      tester,
    ) async {
      await pumpHome(
        tester,
        _Vpn(fixed: VpnStatus.connected, backup: true, dead: true),
        ConnectStage.done,
        on: Server.psiphon,
      );
      expect(
        find.text('Connected, but no data is getting through'),
        findsOneWidget,
      );
    });

    testWidgets('the traffic check says so, as on any other', (tester) async {
      await pumpHome(
        tester,
        _Vpn(fixed: VpnStatus.connected, backup: true, verifying: true),
        ConnectStage.connecting,
        on: Server.psiphon,
      );
      expect(find.text('Checking connection'), findsOneWidget);
    });

    testWidgets('in Persian', (tester) async {
      await pumpHome(
        tester,
        _Vpn(fixed: VpnStatus.connected, backup: true),
        ConnectStage.done,
        on: Server.psiphon,
        locale: 'fa',
      );
      expect(find.text('از طریق شبکه جایگزین وصل شد'), findsOneWidget);
      expect(find.text('شبکه جایگزین'), findsOneWidget);
      expect(find.text('موقعیت به‌صورت خودکار انتخاب می‌شود'), findsOneWidget);
      expectNoName();
    });

    testWidgets('on our own server, as before', (tester) async {
      await pumpHome(
        tester,
        _Vpn(fixed: VpnStatus.connected),
        ConnectStage.done,
        on: _ours,
      );
      expect(find.text('Connected'), findsOneWidget);
      expect(find.text('YOUR SERVER'), findsOneWidget);
      expect(find.text('BACKUP NETWORK'), findsNothing);
      expect(find.text('Falkenstein, Germany'), findsOneWidget);
    });
  });

  group('the checklist and the history', () {
    Widget wrap(Widget child, {String locale = 'en'}) => MaterialApp(
      localizationsDelegates: S.localizationsDelegates,
      supportedLocales: S.supportedLocales,
      locale: Locale(locale),
      home: Scaffold(body: child),
    );

    testWidgets('the checklist row names it by what it is', (tester) async {
      final vpn = _Vpn();
      final flow = _Held(
        vpn,
        ConnectStage.connecting,
        on: Server.psiphon,
        rows: [PathCheck(_ours, state: PathCheckState.blocked)],
        running: RouteKind.backup,
      );
      await tester.pumpWidget(wrap(PathChecklist(flow: flow)));

      expect(find.text('Connecting through Backup network'), findsOneWidget);
      expectNoName();
      // The service's first look at the platform.
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('a session stored through it is shown in the phone\'s '
        'language', (tester) async {
      late String title;
      late String stored;
      await tester.pumpWidget(
        wrap(
          Builder(
            builder: (context) {
              title = serverTitle(context, Server.psiphon);
              stored = storedServerTitle(context, Server.psiphonName);
              return const SizedBox();
            },
          ),
          locale: 'fa',
        ),
      );
      expect(title, 'شبکه جایگزین');
      expect(stored, 'شبکه جایگزین');
    });
  });
}
