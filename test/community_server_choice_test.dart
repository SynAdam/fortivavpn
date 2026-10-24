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
import 'package:fortiva_vpn/widgets/power_button.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A user opens the community list because our own servers are not
/// working on their carrier. If the app overrules that pick and connects
/// through the device's own server anyway, the list is decoration and the
/// user has no way out of a block. These tests pin the pick.
const _ours = Server(
  id: 'dedicated-0',
  name: 'Fortiva DE',
  country: 'Germany',
  city: 'Falkenstein',
  connectionUri: 'vless://ours@198.51.100.201:443?security=reality#ours',
  flagEmoji: '\u{1F1E9}\u{1F1EA}',
  isDedicated: true,
);

const _theirs = Server(
  id: 'telegram-3',
  name: 'Netherlands',
  country: 'Netherlands',
  city: '',
  // A link the door check can read: it is checked before it is dialled.
  connectionUri:
      'vless://00000000-0000-4000-8000-000000000003@203.0.113.222:2087'
      '?security=tls#NL',
  flagEmoji: '\u{1F1F3}\u{1F1F1}',
);

QuotaStatus _quota({required bool blocked}) => QuotaStatus(
  unlimited: false,
  limitBytes: 100 << 20,
  usedBytes: blocked ? 100 << 20 : 10 << 20,
  remainingBytes: blocked ? 0 : 90 << 20,
  blocked: blocked,
  resetsAt: DateTime.now().add(const Duration(hours: 3)),
);

/// A provisioned device: it always has a server of its own selected,
/// which is the state that used to swallow the user's pick.
class _FakeDedicated extends DedicatedState {
  final QuotaStatus _fixed;
  Server? _selected = _ours;

  _FakeDedicated(this._fixed);

  @override
  QuotaStatus? get quota => _fixed;

  @override
  bool get isBlocked => _fixed.blocked;

  @override
  Server? get selectedServer => _selected;

  @override
  bool get hasServers => true;

  @override
  List<Server> get servers => const [_ours];

  @override
  List<Server> get paths => const [_ours];

  @override
  void select(Server server, {bool byUser = true}) {
    _selected = server;
    notifyListeners();
  }

  @override
  Future<void> refresh({bool? viaTunnel}) async {}

  @override
  int? pingFor(String serverId) => null;

  @override
  Future<void> pingServer(Server server) async {}
}

/// The real selection logic, with only the network reads stubbed out.
class _Servers extends ServerState {
  @override
  Future<void> loadServers({bool forceRefresh = false}) async {}

  @override
  int? getPingResult(String serverId) => 42;

  @override
  Future<void> pingServer(Server server) async {}
}

class _FakeVpn extends VpnService {
  VpnStatus _fake;
  final connects = <Server>[];

  _FakeVpn({VpnStatus status = VpnStatus.disconnected}) : _fake = status;

  @override
  VpnStatus get status => _fake;

  @override
  bool get isConnected => _fake == VpnStatus.connected;

  @override
  bool get isConnecting => _fake == VpnStatus.connecting;

  @override
  bool get isVerifying => false;

  @override
  ConnectionInfo? get currentConnection => null;

  @override
  Future<void> connect(
    Server server, {
    String? attemptId,
    List<Server> standby = const [],
    LinkSource? source,
  }) async {
    connects.add(server);
  }

  @override
  Future<void> disconnect() async {
    _fake = VpnStatus.disconnected;
    notifyListeners();
  }
}

void main() {
  const tunnel = MethodChannel('com.vpn.fortivavpn/tunnel');
  const statusChannel = EventChannel('com.vpn.fortivavpn/tunnel/status');

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(tunnel, (call) async {
      // A picked shared link is checked before it is dialled, and this one
      // is open.
      if (call.method == 'realPingDetail') return {'ms': 120};
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
    WidgetTester tester, {
    required DedicatedState dedicated,
    required ServerState servers,
    required _FakeVpn vpn,
  }) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<DedicatedState>.value(value: dedicated),
          ChangeNotifierProvider<ServerState>.value(value: servers),
          ChangeNotifierProvider<VpnService>.value(value: vpn),
          ChangeNotifierProvider<ConnectFlow>(
            create: (_) => ConnectFlow(vpn: vpn),
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

  group('a shared server the user picked', () {
    testWidgets('is what the home card names and what connect dials', (
      tester,
    ) async {
      final vpn = _FakeVpn();
      final servers = _Servers()..selectServer(_theirs);

      await pumpHome(
        tester,
        dedicated: _FakeDedicated(_quota(blocked: false)),
        servers: servers,
        vpn: vpn,
      );

      expect(find.text('COMMUNITY SERVER'), findsOneWidget);
      expect(find.text('Netherlands'), findsOneWidget);
      expect(find.text('YOUR SERVER'), findsNothing);

      await tester.tap(find.byType(PowerButton));
      await tester.pump();
      // The pick's check answers first.
      await tester.pump(const Duration(milliseconds: 100));

      expect(vpn.connects, [_theirs]);

      // This fake never settles, so stop the attempt rather than wait out
      // its timer.
      tester.element(find.byType(HomeScreen)).read<ConnectFlow>().cancel();
      await tester.pump();
    });

    testWidgets('is given up again once one of ours is picked', (tester) async {
      final vpn = _FakeVpn();
      final servers = _Servers()..selectServer(_theirs);
      servers.clearChoice();

      await pumpHome(
        tester,
        dedicated: _FakeDedicated(_quota(blocked: false)),
        servers: servers,
        vpn: vpn,
      );

      expect(find.text('YOUR SERVER'), findsOneWidget);
      expect(find.text('Falkenstein, Germany'), findsOneWidget);
      expect(find.text('Netherlands'), findsNothing);
    });

    testWidgets('still leaves a way back to this device\'s own servers', (
      tester,
    ) async {
      final vpn = _FakeVpn();
      final servers = _Servers()..selectServer(_theirs);

      await pumpHome(
        tester,
        dedicated: _FakeDedicated(_quota(blocked: false)),
        servers: servers,
        vpn: vpn,
      );

      await tester.tap(find.text('COMMUNITY SERVER'));
      await tester.pumpAndSettle();

      // The card leads to the device's own servers, which is the only
      // screen that can take the user back off a community pick.
      expect(find.text('Your servers'), findsOneWidget);
    });

    testWidgets('does not survive a spent allowance', (tester) async {
      final vpn = _FakeVpn();
      final servers = _Servers()..selectServer(_theirs);

      await pumpHome(
        tester,
        dedicated: _FakeDedicated(_quota(blocked: true)),
        servers: servers,
        vpn: vpn,
      );

      expect(find.text('Netherlands'), findsNothing);
      expect(find.text('Daily limit reached'), findsOneWidget);

      await tester.tap(find.byType(PowerButton));
      await tester.pump();

      expect(vpn.connects, isEmpty);
    });
  });

  group('ServerState', () {
    test('records the pick and writes it down by link, not by id', () async {
      final servers = _Servers();
      expect(servers.isChosen, isFalse);

      servers.selectServer(_theirs);
      expect(servers.isChosen, isTrue);
      expect(servers.selectedServer, _theirs);

      await servers.choiceWritten;
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      expect(prefs.getString(ServerState.prefChosenUri), _theirs.connectionUri);
    });

    test('clearing the pick leaves the fallback selection in place', () async {
      final servers = _Servers()..selectServer(_theirs);
      servers.clearChoice();

      expect(servers.isChosen, isFalse);
      expect(servers.selectedServer, _theirs);

      await servers.choiceWritten;
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      expect(prefs.getString(ServerState.prefChosenUri), isNull);
    });
  });
}
