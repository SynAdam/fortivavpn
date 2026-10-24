import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/api/config_service.dart';
import 'package:fortiva_vpn/core/page_transitions.dart';
import 'package:fortiva_vpn/core/state/connect_flow.dart';
import 'package:fortiva_vpn/core/state/dedicated_state.dart';
import 'package:fortiva_vpn/core/state/locale_state.dart';
import 'package:fortiva_vpn/core/state/server_state.dart';
import 'package:fortiva_vpn/data/models/connection_info.dart';
import 'package:fortiva_vpn/data/models/server.dart';
import 'package:fortiva_vpn/l10n/generated/app_localizations.dart';
import 'package:fortiva_vpn/screens/home_screen.dart';
import 'package:fortiva_vpn/screens/my_servers_screen.dart';
import 'package:fortiva_vpn/screens/server_list_screen.dart';
import 'package:fortiva_vpn/services/vpn_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Picking a server on any server list goes straight back to the home
/// screen, with the pick applied.
///
/// On 2026-10-09 the owner reported two screens that stayed put after a
/// pick. On Your servers, tapping Nuremberg showed "Now using Nuremberg"
/// and left him on the list. On the community list the row was marked
/// and he was still on a list, because that list is opened from Your
/// servers and a pick closed only the community list itself.
///
/// Buttons on a list that are not a pick (Ping, Test all, Copy link)
/// must leave the user where they are.

const _nuremberg = Server(
  id: 'dedicated-0',
  name: 'Nuremberg',
  country: 'Germany',
  city: 'Nuremberg',
  connectionUri: 'vless://a@203.0.113.220:443?security=reality#Nuremberg',
  flagEmoji: '',
  isDedicated: true,
);

const _helsinki = Server(
  id: 'dedicated-1',
  name: 'Helsinki',
  country: 'Finland',
  city: 'Helsinki',
  connectionUri: 'vless://b@203.0.113.221:443?security=reality#Helsinki',
  flagEmoji: '',
  isDedicated: true,
);

const _netherlands = Server(
  id: 'telegram-0',
  name: 'Netherlands',
  country: 'Netherlands',
  city: '',
  // A link the door check can read: a pick is checked before it is
  // dialled.
  connectionUri:
      'vless://00000000-0000-4000-8000-000000000002@203.0.113.222:2087'
      '?security=tls#NL',
  flagEmoji: '',
);

const _estonia = Server(
  id: 'telegram-1',
  name: 'Estonia',
  country: 'Estonia',
  city: '',
  connectionUri: 'vless://e@6.6.6.6:443?security=tls#EE',
  flagEmoji: '',
);

/// This device's own servers. Helsinki is in use, so a pick of Nuremberg
/// is a change the test can see.
class _FakeDedicated extends DedicatedState {
  _FakeDedicated({this.own = const [_nuremberg, _helsinki]})
    : _selected = own.isEmpty ? null : _helsinki;

  final List<Server> own;
  Server? _selected;
  int pingAllCalls = 0;

  @override
  List<Server> get servers => own;

  /// No doors, so a move while connected dials the pick on its own and the
  /// test does not have to run the connect flow. The flow is covered in
  /// picker_dials_through_doors_test.dart.
  @override
  List<Server> get paths => const [];

  @override
  bool get hasServers => own.isNotEmpty;

  @override
  bool get isBlocked => false;

  @override
  bool get isLoading => false;

  @override
  QuotaStatus? get quota => null;

  @override
  Server? get selectedServer => _selected;

  bool _byUser = false;

  @override
  bool get selectedByUser => _byUser;

  @override
  void select(Server server, {bool byUser = true}) {
    _selected = server;
    _byUser = byUser;
    notifyListeners();
  }

  @override
  Future<void> refresh({bool? viaTunnel}) async {}

  @override
  int? pingFor(String serverId) => null;

  @override
  bool isPinging(String serverId) => false;

  @override
  Future<void> pingServer(Server server) async {}

  @override
  Future<void> pingAll() async => pingAllCalls++;
}

/// The real selection logic, with the network reads and pings stubbed.
class _FakeServers extends ServerState {
  _FakeServers({this.pings = const {}});

  /// Ping results by server id. Empty leaves every row with its Ping
  /// button.
  final Map<String, int> pings;
  final pinged = <Server>[];
  int pingAllCalls = 0;

  @override
  List<Server> get communityServers => const [_netherlands, _estonia];

  @override
  bool get isLoading => false;

  @override
  Future<void> loadServers({bool forceRefresh = false}) async {}

  @override
  Future<void> refreshServers() async {}

  @override
  int? getPingResult(String serverId) => pings[serverId];

  @override
  Future<void> pingServer(Server server) async => pinged.add(server);

  @override
  Future<void> pingServers(
    List<Server> servers, {
    required int tabIndex,
  }) async => pingAllCalls++;
}

class _FakeVpn extends VpnService {
  _FakeVpn({VpnStatus status = VpnStatus.disconnected}) : _fake = status;

  VpnStatus _fake;
  final connects = <Server>[];

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

  /// Comes up on whatever it is given, at once.
  @override
  Future<void> connect(
    Server server, {
    String? attemptId,
    List<Server> standby = const [],
    LinkSource? source,
  }) async {
    connects.add(server);
    _fake = VpnStatus.connected;
    notifyListeners();
  }

  @override
  Future<void> disconnect() async {
    _fake = VpnStatus.disconnected;
    notifyListeners();
  }
}

final _home = find.byType(HomeScreen);
final _yourServers = find.byType(MyServersScreen);
final _community = find.byType(ServerListScreen);

/// Lets route transitions and the toast's entrance run. Not pumpAndSettle,
/// because a connected home screen animates without end.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Runs out the toast's two second timer, so no timer is left when the
/// tree is torn down.
Future<void> _drainToast(WidgetTester tester) async {
  for (var i = 0; i < 30; i++) {
    await tester.pump(const Duration(milliseconds: 100));
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
      // A picked shared link is checked before it is dialled, and here it
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
    required _FakeDedicated dedicated,
    required _FakeServers servers,
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

  /// Home, then the server card, the way a user gets to the lists. The
  /// card is headed by the kind of server in use.
  Future<void> openFromHomeCard(
    WidgetTester tester, {
    String heading = 'YOUR SERVER',
  }) async {
    await tester.tap(find.text(heading));
    await _settle(tester);
  }

  /// Home, Your servers, then Shared servers: the community list as the
  /// owner reached it.
  Future<void> openCommunity(WidgetTester tester) async {
    await openFromHomeCard(tester);
    expect(_yourServers, findsOneWidget);
    await tester.tap(find.text('Shared servers'));
    await _settle(tester);
    expect(_community, findsOneWidget);
  }

  void expectHome() {
    expect(_home, findsOneWidget);
    expect(_yourServers, findsNothing);
    expect(_community, findsNothing);
  }

  group('a pick on Your servers', () {
    testWidgets('goes home, uses the server and says so there', (tester) async {
      final dedicated = _FakeDedicated();
      final servers = _FakeServers()..selectServer(_netherlands);
      final vpn = _FakeVpn();
      await pumpHome(tester, dedicated: dedicated, servers: servers, vpn: vpn);

      await openFromHomeCard(tester, heading: 'COMMUNITY SERVER');
      expect(_yourServers, findsOneWidget);

      await tester.tap(find.text('Nuremberg'));
      await _settle(tester);

      expectHome();
      expect(dedicated.selectedServer, _nuremberg);
      // A pick, so its doors go first on the next tap.
      expect(dedicated.selectedByUser, isTrue);
      // A community pick is given up when one of ours is picked.
      expect(servers.isChosen, isFalse);
      expect(find.text('Nuremberg, Germany'), findsOneWidget);
      expect(find.text('Now using Nuremberg'), findsOneWidget);
      // Disconnected: picking does not dial.
      expect(vpn.connects, isEmpty);

      await _drainToast(tester);
    });

    testWidgets('closes every screen above home, not only the list', (
      tester,
    ) async {
      final dedicated = _FakeDedicated();
      await pumpHome(
        tester,
        dedicated: dedicated,
        servers: _FakeServers(),
        vpn: _FakeVpn(),
      );

      // Settings opens Your servers on top of itself. A screen in between
      // stands in for it, since only the depth matters here.
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('Settings stand-in')),
        ),
      );
      await _settle(tester);
      navigator.push(SlideUpFadeTransition(page: const MyServersScreen()));
      await _settle(tester);
      expect(_yourServers, findsOneWidget);

      await tester.tap(find.text('Nuremberg'));
      await _settle(tester);

      expectHome();
      expect(find.text('Settings stand-in'), findsNothing);
      expect(dedicated.selectedServer, _nuremberg);

      await _drainToast(tester);
    });

    testWidgets('while connected moves the tunnel, then goes home and names '
        'the server there', (tester) async {
      final dedicated = _FakeDedicated();
      final vpn = _FakeVpn(status: VpnStatus.connected);
      await pumpHome(
        tester,
        dedicated: dedicated,
        servers: _FakeServers(),
        vpn: vpn,
      );

      await openFromHomeCard(tester);
      await tester.tap(find.text('Nuremberg'));
      await _settle(tester);

      expectHome();
      expect(vpn.connects, [_nuremberg]);
      expect(dedicated.selectedServer, _nuremberg);
      // The toast waits for the move and is shown on the home screen,
      // after the list has closed.
      expect(find.text('Now using Nuremberg'), findsOneWidget);

      await _drainToast(tester);
      // Down, which stops the timers a connected tunnel starts.
      await vpn.disconnect();
      await tester.pump();
    });

    testWidgets('Test all and Copy link stay on the list', (tester) async {
      final dedicated = _FakeDedicated();
      await pumpHome(
        tester,
        dedicated: dedicated,
        servers: _FakeServers(),
        vpn: _FakeVpn(),
      );
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String?;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      await openFromHomeCard(tester);

      await tester.tap(find.text('Test all'));
      await _settle(tester);
      expect(dedicated.pingAllCalls, 1);
      expect(_yourServers, findsOneWidget);

      await tester.tap(find.byTooltip('Copy link').first);
      await _settle(tester);
      expect(copied, _nuremberg.connectionUri);
      expect(_yourServers, findsOneWidget);
      expect(find.text('Link copied'), findsOneWidget);

      expect(dedicated.selectedServer, _helsinki);
      await _drainToast(tester);
    });
  });

  group('a pick on the community list', () {
    testWidgets('opened from Your servers goes all the way home', (
      tester,
    ) async {
      final servers = _FakeServers();
      final vpn = _FakeVpn();
      await pumpHome(
        tester,
        dedicated: _FakeDedicated(),
        servers: servers,
        vpn: vpn,
      );

      await openCommunity(tester);
      await tester.tap(find.text('Netherlands'));
      await _settle(tester);

      expectHome();
      expect(servers.isChosen, isTrue);
      expect(servers.selectedServer, _netherlands);
      expect(find.text('COMMUNITY SERVER'), findsOneWidget);
      expect(find.text('Now using Netherlands'), findsOneWidget);
      expect(vpn.connects, isEmpty);

      await _drainToast(tester);
    });

    testWidgets('opened straight from home, on a device with no servers of '
        'its own, goes home', (tester) async {
      final servers = _FakeServers();
      await pumpHome(
        tester,
        dedicated: _FakeDedicated(own: const []),
        servers: servers,
        vpn: _FakeVpn(),
      );

      await openFromHomeCard(tester);
      expect(_community, findsOneWidget);

      await tester.tap(find.text('Estonia'));
      await _settle(tester);

      expectHome();
      expect(servers.selectedServer, _estonia);
      expect(servers.isChosen, isTrue);

      await _drainToast(tester);
    });

    testWidgets('from search results goes home', (tester) async {
      final servers = _FakeServers();
      await pumpHome(
        tester,
        dedicated: _FakeDedicated(),
        servers: servers,
        vpn: _FakeVpn(),
      );

      await openCommunity(tester);
      await tester.enterText(find.byType(TextField), 'esto');
      await tester.pump();
      expect(find.text('Netherlands'), findsNothing);

      await tester.tap(find.text('Estonia'));
      await _settle(tester);

      expectHome();
      expect(servers.selectedServer, _estonia);

      await _drainToast(tester);
    });

    testWidgets('on the Fastest row goes home', (tester) async {
      final servers = _FakeServers(
        pings: {_netherlands.id: 180, _estonia.id: 42},
      );
      await pumpHome(
        tester,
        dedicated: _FakeDedicated(),
        servers: servers,
        vpn: _FakeVpn(),
      );

      await openCommunity(tester);
      await tester.tap(find.text('Fastest'));
      await _settle(tester);

      expectHome();
      expect(servers.selectedServer, _estonia);

      await _drainToast(tester);
    });

    testWidgets('while connected dials the pick and goes home', (tester) async {
      final servers = _FakeServers();
      final vpn = _FakeVpn(status: VpnStatus.connected);
      await pumpHome(
        tester,
        dedicated: _FakeDedicated(),
        servers: servers,
        vpn: vpn,
      );

      await openCommunity(tester);
      await tester.tap(find.text('Netherlands'));
      await _settle(tester);

      expectHome();
      expect(vpn.connects, [_netherlands]);
      expect(servers.selectedServer, _netherlands);

      await _drainToast(tester);
      await vpn.disconnect();
      await tester.pump();
    });

    testWidgets('Ping stays on the list and picks nothing', (tester) async {
      final servers = _FakeServers();
      await pumpHome(
        tester,
        dedicated: _FakeDedicated(),
        servers: servers,
        vpn: _FakeVpn(),
      );

      await openCommunity(tester);
      await tester.tap(find.text('Ping').first);
      await _settle(tester);

      expect(_community, findsOneWidget);
      expect(servers.pinged, hasLength(1));
      expect(servers.isChosen, isFalse);
      expect(find.textContaining('Now using'), findsNothing);
    });

    testWidgets('Test all stays on the list and picks nothing', (tester) async {
      final servers = _FakeServers();
      await pumpHome(
        tester,
        dedicated: _FakeDedicated(),
        servers: servers,
        vpn: _FakeVpn(),
      );

      await openCommunity(tester);
      await tester.tap(find.text('Test all'));
      await _settle(tester);

      expect(_community, findsOneWidget);
      expect(servers.pingAllCalls, 1);
      expect(servers.isChosen, isFalse);
    });
  });
}
