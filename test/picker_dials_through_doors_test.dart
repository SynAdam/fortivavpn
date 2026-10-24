import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/api/config_service.dart';
import 'package:fortiva_vpn/core/state/connect_flow.dart';
import 'package:fortiva_vpn/core/state/dedicated_state.dart';
import 'package:fortiva_vpn/core/state/dial_server.dart';
import 'package:fortiva_vpn/core/state/server_state.dart';
import 'package:fortiva_vpn/data/models/connection_info.dart';
import 'package:fortiva_vpn/data/models/psiphon_settings.dart';
import 'package:fortiva_vpn/data/models/server.dart';
import 'package:fortiva_vpn/l10n/generated/app_localizations.dart';
import 'package:fortiva_vpn/screens/my_servers_screen.dart';
import 'package:fortiva_vpn/services/door_sweep.dart';
import 'package:fortiva_vpn/services/path_finder.dart';
import 'package:fortiva_vpn/services/path_memory.dart';
import 'package:fortiva_vpn/services/vpn_event_reporter.dart';
import 'package:fortiva_vpn/services/vpn_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A server picked on the servers screen is dialled the way the connect
/// button dials it: through its doors, and on to another server's when
/// none of them work.
///
/// Phones picked a server while connected. The screen dialled that
/// server's one link, TLS to it was being reset, and they got "Server not
/// working, try another" again and again while other doors worked.

Server _door(String id, String host, String door, int serverId) => Server(
  id: id,
  name: id,
  country: 'Germany',
  city: 'Nuremberg',
  connectionUri: 'vless://u@$host:443?type=tcp#$id',
  flagEmoji: '',
  isDedicated: true,
  door: door,
  serverId: serverId,
);

final _a1 = _door('a1', 'edge-a.example', 'xhttp-reality', 7);
final _b1 = _door('b1', 'cdn-b.example', 'ws-tls', 8);
final _b2 = _door('b2', 'edge-b.example', 'xhttp-reality', 8);

/// The servers screen lists one entry per server, with no door: its
/// server's first link and the backend id.
Server _entry(String name, Server firstDoor) => Server(
  id: 'dedicated-$name',
  name: name,
  country: 'Germany',
  city: 'Nuremberg',
  connectionUri: firstDoor.connectionUri,
  flagEmoji: '',
  isDedicated: true,
  serverId: firstDoor.serverId,
);

final _serverA = _entry('Server A', _a1);
final _serverB = _entry('Server B', _b1);

class _FakeDedicated extends DedicatedState {
  _FakeDedicated({this.withPaths = true});

  /// Whether the device's servers have loaded. A test can flip it while a
  /// tap runs, as a fetch that lands meanwhile does.
  bool withPaths;
  Server? _selected;

  @override
  List<Server> get servers => [_serverA, _serverB];

  @override
  List<Server> get paths => withPaths ? [_a1, _b1, _b2] : const [];

  @override
  bool get hasServers => true;

  @override
  bool get isBlocked => false;

  @override
  bool get isLoading => false;

  @override
  QuotaStatus? get quota => null;

  @override
  Server? get selectedServer => _selected ?? _serverA;

  bool _byUser = false;

  @override
  bool get selectedByUser => _byUser;

  @override
  void select(Server server, {bool byUser = true}) {
    // Like the real DedicatedState: a door the flow switched to is mapped
    // back to its server entry, so selectedServer carries the friendly name.
    _selected =
        servers.where((s) => s.sameServerAs(server)).firstOrNull ?? server;
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
}

class _FakeServers extends ServerState {
  _FakeServers({this.community = const []});

  final List<Server> community;

  @override
  List<Server> get communityServers => community;

  @override
  bool get isLoading => false;

  @override
  Future<void> loadServers({bool forceRefresh = false}) async {}

  @override
  Future<void> pingServer(Server server) async {}
}

/// Up on server A, and able to come up only through the links in [works].
class _FakeVpn extends VpnService {
  _FakeVpn(this.works);

  final Set<String> works;
  final connects = <Server>[];
  VpnStatus _fake = VpnStatus.connected;

  /// Told of each dial as it starts.
  void Function(Server server)? onConnect;

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
  bool get onPsiphon => connects.lastOrNull?.isPsiphon ?? false;

  @override
  Future<void> connect(
    Server server, {
    String? attemptId,
    List<Server> standby = const [],
    LinkSource? source,
  }) async {
    connects.add(server);
    onConnect?.call(server);
    _fake = VpnStatus.connecting;
    notifyListeners();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    _fake = works.contains(server.id) ? VpnStatus.connected : VpnStatus.error;
    notifyListeners();
  }

  @override
  void clearError() {
    if (_fake == VpnStatus.error) _fake = VpnStatus.disconnected;
    notifyListeners();
  }

  @override
  Future<void> disconnect() async {
    _fake = VpnStatus.disconnected;
    notifyListeners();
  }
}

/// [checksPass] are the doors whose checks pass, by id. Without it, a
/// door's check passes exactly when its tunnel would come up. [backup]
/// turns the backup network on for an Android phone the backend let in.
ConnectFlow _flowFor(
  _FakeVpn vpn, {
  Set<String>? checksPass,
  PsiphonSettings? backup,
}) {
  final reporter = VpnEventReporter(
    send: (_, _, _) async {},
    sendProbes: (_, _, _) async {},
    deviceId: () async => 'DEV-1',
    appVersion: () async => '1.6.5',
    platform: 'android',
    networkType: () async => 'mobile',
  );
  return ConnectFlow(
    vpn: vpn,
    memory: PathMemory(),
    finder: PathFinder(
      probe: (p) async => (checksPass ?? vpn.works).contains(p.id) ? 120 : -1,
      internet: () async => true,
    ),
    reporter: reporter,
    sweep: DoorSweep(appBypassesTunnel: false, reporter: reporter),
    networkKey: () async => 'mobile:Irancell',
    carrier: () async => 'Irancell',
    attemptTimeout: const Duration(seconds: 2),
    psiphon: backup == null ? null : () => backup,
    psiphonDevice: backup == null
        ? null
        : () => const PsiphonDevice(allowed: true, quotaFresh: true),
    android: () => true,
    tv: () => false,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const tunnel = MethodChannel('com.vpn.fortivavpn/tunnel');
  const statusChannel = EventChannel('com.vpn.fortivavpn/tunnel/status');

  setUp(() {
    SharedPreferences.setMockInitialValues({});
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
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(tunnel, null);
    messenger.setMockStreamHandler(statusChannel, null);
  });

  group('dialServer', () {
    test('dials the picked server through a door of it that works', () async {
      final vpn = _FakeVpn({_a1.id, _b2.id});
      final dedicated = _FakeDedicated();

      await dialServer(
        _serverB,
        vpn: vpn,
        flow: _flowFor(vpn),
        dedicated: dedicated,
        servers: _FakeServers(),
      );

      expect(vpn.connects, [_b2]);
      expect(vpn.isConnected, isTrue);
    });

    test('moves to another server when none of the picked one\'s doors '
        'work, and the selection follows', () async {
      final vpn = _FakeVpn({_a1.id});
      final dedicated = _FakeDedicated()..select(_serverB);

      await dialServer(
        _serverB,
        vpn: vpn,
        flow: _flowFor(vpn),
        dedicated: dedicated,
        servers: _FakeServers(),
      );

      expect(vpn.connects, [_a1]);
      expect(vpn.isConnected, isTrue);
      expect(dedicated.selectedServer?.sameServerAs(_serverA), isTrue);
    });

    // A server the flow moved the selection to is where an earlier tap
    // landed, not a pick. Up to 1.7.0 its doors went first on every later
    // tap, even when its IPv4 addresses rarely passed on the phone's
    // carrier.
    test('a server the flow moved to keeps the backend\'s door order, and '
        'the selection follows the door that opens', () async {
      final vpn = _FakeVpn({_a1.id, _b2.id});
      final dedicated = _FakeDedicated()..select(_b2, byUser: false);

      await dialServer(
        dedicated.selectedServer!,
        vpn: vpn,
        flow: _flowFor(vpn),
        dedicated: dedicated,
        servers: _FakeServers(),
      );

      expect(vpn.connects, [_a1]);
      expect(dedicated.selectedServer?.sameServerAs(_serverA), isTrue);
      expect(dedicated.selectedByUser, isFalse);
    });

    test('a server the user picked has its doors tried first, and stays '
        'picked', () async {
      final vpn = _FakeVpn({_a1.id, _b2.id});
      final dedicated = _FakeDedicated()..select(_serverB);

      await dialServer(
        dedicated.selectedServer!,
        vpn: vpn,
        flow: _flowFor(vpn),
        dedicated: dedicated,
        servers: _FakeServers(),
      );

      expect(vpn.connects, [_b2]);
      expect(dedicated.selectedServer?.sameServerAs(_serverB), isTrue);
      expect(dedicated.selectedByUser, isTrue);
    });

    test('a pick none of whose doors work is given up for the server the '
        'tap landed on', () async {
      final vpn = _FakeVpn({_a1.id});
      final dedicated = _FakeDedicated()..select(_serverB);

      await dialServer(
        dedicated.selectedServer!,
        vpn: vpn,
        flow: _flowFor(vpn),
        dedicated: dedicated,
        servers: _FakeServers(),
      );

      expect(vpn.connects, [_a1]);
      expect(dedicated.selectedServer?.sameServerAs(_serverA), isTrue);
      expect(dedicated.selectedByUser, isFalse);
    });

    // Until 2026-10-12 the selection moved to the door the checklist found
    // open before its tunnel was dialled. When that tunnel failed, the card
    // named a server no tunnel had come up through, and the user's pick was
    // gone: the move is not a pick.
    test('a door of another server whose check passes and whose tunnel '
        'fails leaves the pick as it was', () async {
      final vpn = _FakeVpn({});
      final dedicated = _FakeDedicated()..select(_serverB);
      final flow = _flowFor(vpn, checksPass: {_a1.id});

      await dialServer(
        dedicated.selectedServer!,
        vpn: vpn,
        flow: flow,
        dedicated: dedicated,
        servers: _FakeServers(),
      );

      expect(vpn.connects, [_a1]);
      expect(flow.stage, ConnectStage.failed);
      expect(dedicated.selectedServer?.sameServerAs(_serverB), isTrue);
      expect(dedicated.selectedByUser, isTrue);
    });

    // A tap with no servers of its own dials a shared link, and hands over
    // to the device's servers when they land meanwhile (connectShared).
    // The handover follows the same rules as a tap that had them: only a
    // pick has its doors tried first, and the server the tap lands on is
    // not a pick.
    final sharedLink = Server.fromConnectionUri(
      'vless://u@shared.example:443?type=tcp&security=reality'
      '&sni=www.samsung.com&pbk=key#Shared',
      index: 0,
    );

    test('a handover from a shared link to servers that landed keeps the '
        'backend\'s door order, and the move it makes is not a pick', () async {
      final vpn = _FakeVpn({_a1.id, _b2.id});
      // The selection an earlier tap landed on, restored with the servers.
      final dedicated = _FakeDedicated(withPaths: false)
        ..select(_b2, byUser: false);
      vpn.onConnect = (s) {
        if (!s.isDedicated) dedicated.withPaths = true;
      };

      // The link's check passes, so it is dialled, and the servers land
      // during its dial.
      await dialServer(
        sharedLink,
        vpn: vpn,
        flow: _flowFor(vpn, checksPass: {sharedLink.id, ...vpn.works}),
        dedicated: dedicated,
        servers: _FakeServers(),
      );

      expect(vpn.connects, [sharedLink, _a1]);
      expect(dedicated.selectedServer?.sameServerAs(_serverA), isTrue);
      expect(dedicated.selectedByUser, isFalse);
    });

    test('a handover from a shared link tries a server the user picked '
        'first, and it stays picked', () async {
      final vpn = _FakeVpn({_a1.id, _b2.id});
      final dedicated = _FakeDedicated(withPaths: false)..select(_serverB);
      vpn.onConnect = (s) {
        if (!s.isDedicated) dedicated.withPaths = true;
      };

      // The link's check passes, so it is dialled, and the servers land
      // during its dial.
      await dialServer(
        sharedLink,
        vpn: vpn,
        flow: _flowFor(vpn, checksPass: {sharedLink.id, ...vpn.works}),
        dedicated: dedicated,
        servers: _FakeServers(),
      );

      expect(vpn.connects, [sharedLink, _b2]);
      expect(dedicated.selectedServer?.sameServerAs(_serverB), isTrue);
      expect(dedicated.selectedByUser, isTrue);
    });

    test('dials the server on its own when the device has no doors', () async {
      final vpn = _FakeVpn({_serverB.id});

      await dialServer(
        _serverB,
        vpn: vpn,
        flow: _flowFor(vpn),
        dedicated: _FakeDedicated(withPaths: false),
        servers: _FakeServers(),
      );
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(vpn.connects, [_serverB]);
    });
  });

  testWidgets('picking a server while connected goes through its doors', (
    tester,
  ) async {
    final vpn = _FakeVpn({_a1.id, _b2.id});
    final dedicated = _FakeDedicated();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<DedicatedState>.value(value: dedicated),
          ChangeNotifierProvider<ServerState>.value(value: _FakeServers()),
          ChangeNotifierProvider<VpnService>.value(value: vpn),
          ChangeNotifierProvider<ConnectFlow>(create: (_) => _flowFor(vpn)),
        ],
        child: const MaterialApp(
          localizationsDelegates: S.localizationsDelegates,
          supportedLocales: S.supportedLocales,
          locale: Locale('en'),
          home: MyServersScreen(),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Server B'));
    // Not pumpAndSettle: let the flow and the toast run out.
    for (var i = 0; i < 50; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(vpn.connects, [_b2]);
    expect(vpn.isConnected, isTrue);
    expect(dedicated.selectedServer?.sameServerAs(_serverB), isTrue);

    // Down, which stops the heartbeat and throughput timers a connected
    // tunnel starts.
    await vpn.disconnect();
    await tester.pump();
  });

  testWidgets('a pick whose doors all fail falls back, and the toast names '
      'the server actually in use', (tester) async {
    // Only A works. Picking B lands on A, so the toast must say A, not the B
    // that was tapped.
    final vpn = _FakeVpn({_a1.id});
    final dedicated = _FakeDedicated();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<DedicatedState>.value(value: dedicated),
          ChangeNotifierProvider<ServerState>.value(value: _FakeServers()),
          ChangeNotifierProvider<VpnService>.value(value: vpn),
          ChangeNotifierProvider<ConnectFlow>(create: (_) => _flowFor(vpn)),
        ],
        child: const MaterialApp(
          localizationsDelegates: S.localizationsDelegates,
          supportedLocales: S.supportedLocales,
          locale: Locale('en'),
          home: MyServersScreen(),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Server B'));
    // Full loop, not an early break: it also drains the toast's 2 s timer
    // before the tree is torn down.
    var toastNamesA = false;
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      toastNamesA =
          toastNamesA || find.text('Now using Server A').evaluate().isNotEmpty;
    }

    expect(vpn.connects, [_a1]);
    expect(dedicated.selectedServer?.sameServerAs(_serverA), isTrue);
    expect(
      toastNamesA,
      isTrue,
      reason: 'the toast must name A, the server the tunnel landed on',
    );
    expect(find.text('Now using Server B'), findsNothing);

    await vpn.disconnect();
    await tester.pump();
  });

  // The backup network never moves the selection, so the selection still
  // names the pick when it carries the tunnel.
  testWidgets('a pick that lands on the backup network names it', (
    tester,
  ) async {
    // B's door passes its check and its tunnel fails, nothing else opens,
    // and the backup network comes up.
    final vpn = _FakeVpn({Server.psiphon.id});
    final dedicated = _FakeDedicated();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<DedicatedState>.value(value: dedicated),
          ChangeNotifierProvider<ServerState>.value(value: _FakeServers()),
          ChangeNotifierProvider<VpnService>.value(value: vpn),
          ChangeNotifierProvider<ConnectFlow>(
            create: (_) => _flowFor(
              vpn,
              checksPass: {_b2.id},
              backup: const PsiphonSettings(
                network: {
                  'PropagationChannelId': '0123456789ABCDEF',
                  'SponsorId': '0123456789ABCDEF',
                },
                enabled: true,
                establishTimeout: Duration(seconds: 1),
              ),
            ),
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: S.localizationsDelegates,
          supportedLocales: S.supportedLocales,
          locale: Locale('en'),
          home: MyServersScreen(),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Server B'));
    var toastNamesBackup = false;
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      toastNamesBackup =
          toastNamesBackup ||
          find.text('Now using Backup network').evaluate().isNotEmpty;
    }

    expect(vpn.connects, [_b2, Server.psiphon]);
    expect(vpn.isConnected, isTrue);
    expect(dedicated.selectedServer?.sameServerAs(_serverB), isTrue);
    expect(toastNamesBackup, isTrue);
    expect(find.text('Now using Server B'), findsNothing);

    await vpn.disconnect();
    await tester.pump();
  });

  testWidgets('a pick that lands on a shared link names that link', (
    tester,
  ) async {
    // None of our doors work. The fallback carries the tunnel on a shared
    // link, so the toast must name it, not Server A or Server B.
    const estonia = Server(
      id: 'telegram-0',
      name: 'Estonia',
      country: 'Estonia',
      city: '',
      connectionUri: 'vless://s@ee.example:443?type=tcp#Estonia',
      flagEmoji: '',
    );
    final vpn = _FakeVpn({estonia.id});
    final dedicated = _FakeDedicated();
    final servers = _FakeServers(community: const [estonia]);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<DedicatedState>.value(value: dedicated),
          ChangeNotifierProvider<ServerState>.value(value: servers),
          ChangeNotifierProvider<VpnService>.value(value: vpn),
          ChangeNotifierProvider<ConnectFlow>(create: (_) => _flowFor(vpn)),
        ],
        child: const MaterialApp(
          localizationsDelegates: S.localizationsDelegates,
          supportedLocales: S.supportedLocales,
          locale: Locale('en'),
          home: MyServersScreen(),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Server B'));
    var toastNamesEstonia = false;
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      toastNamesEstonia =
          toastNamesEstonia ||
          find.text('Now using Estonia').evaluate().isNotEmpty;
    }

    expect(vpn.connects.last, estonia);
    expect(servers.isChosen, isTrue);
    expect(toastNamesEstonia, isTrue);
    expect(find.text('Now using Server A'), findsNothing);
    expect(find.text('Now using Server B'), findsNothing);

    await vpn.disconnect();
    await tester.pump();
  });
}
