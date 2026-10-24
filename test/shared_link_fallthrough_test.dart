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
import 'package:fortiva_vpn/services/door_sweep.dart';
import 'package:fortiva_vpn/services/path_finder.dart';
import 'package:fortiva_vpn/services/path_memory.dart';
import 'package:fortiva_vpn/services/vpn_event_reporter.dart';
import 'package:fortiva_vpn/services/vpn_service.dart';
import 'package:fortiva_vpn/widgets/power_button.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The connect button must not stop at a dead shared link while the phone
/// has working servers of its own.
///
/// On 2026-09-27 the official Cloudflare link failed 50 times out of 55
/// from Iran. Every failure ended at "Server not working, try another" on
/// a phone whose own Reality door would have connected.
const _ours = Server(
  id: 'dedicated-0',
  name: 'Fortiva DE',
  country: 'Germany',
  city: 'Nuremberg',
  connectionUri: 'vless://ours@198.51.100.209:8443?security=reality#ours',
  flagEmoji: '\u{1F1E9}\u{1F1EA}',
  isDedicated: true,
  door: 'xhttp-reality',
  serverId: 7,
);

const _official = Server(
  id: 'official-9',
  name: 'Fortiva DE Nuremberg (CDN)',
  country: 'Germany',
  city: 'Nuremberg',
  connectionUri: 'vless://shared@198.51.100.215:443?security=tls&type=ws#cdn',
  flagEmoji: '\u{1F1E9}\u{1F1EA}',
);

final _quota = QuotaStatus(
  unlimited: false,
  limitBytes: 100 << 20,
  usedBytes: 10 << 20,
  remainingBytes: 90 << 20,
  blocked: false,
  resetsAt: DateTime.now().add(const Duration(hours: 3)),
);

/// A device whose own servers are loaded from the start, or by the first
/// [refresh] after [loadOnRefresh] is set.
class _FakeDedicated extends DedicatedState {
  _FakeDedicated({required bool loaded}) : _loaded = loaded;

  bool _loaded;
  bool loadOnRefresh = false;
  int refreshes = 0;
  Server? _selected;

  @override
  QuotaStatus? get quota => _quota;

  @override
  bool get isBlocked => false;

  @override
  Server? get selectedServer => _loaded ? (_selected ?? _ours) : null;

  @override
  bool get hasServers => _loaded;

  @override
  List<Server> get servers => _loaded ? const [_ours] : const [];

  @override
  List<Server> get paths => _loaded ? const [_ours] : const [];

  @override
  void select(Server server, {bool byUser = true}) {
    _selected = server;
    notifyListeners();
  }

  @override
  Future<void> refresh({bool? viaTunnel}) async {
    refreshes++;
    if (loadOnRefresh) _loaded = true;
    notifyListeners();
  }

  @override
  int? pingFor(String serverId) => null;

  @override
  Future<void> pingServer(Server server) async {}
}

/// The real selection logic, with the official link as the fallback.
class _Servers extends ServerState {
  @override
  Server? get selectedServer => super.selectedServer ?? _official;

  @override
  Future<void> loadServers({bool forceRefresh = false}) async {}

  @override
  int? getPingResult(String serverId) => 42;

  @override
  Future<void> pingServer(Server server) async {}
}

/// A tunnel that comes up through the links in [works] and fails through
/// everything else.
class _FakeVpn extends VpnService {
  _FakeVpn(this.works);

  final Set<String> works;
  final connects = <Server>[];
  VpnStatus _fake = VpnStatus.disconnected;

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

  ConnectFlow flowFor(_FakeVpn vpn) {
    final reporter = VpnEventReporter(
      send: (_, _, _) async {},
      sendProbes: (_, _, _) async {},
      deviceId: () async => 'DEV-1',
      appVersion: () async => '1.6.2',
      platform: 'android',
      networkType: () async => 'mobile',
    );
    return ConnectFlow(
      vpn: vpn,
      memory: PathMemory(),
      // Every check passes, our doors and the shared links alike: a pick is
      // checked before it is dialled. Whether a tunnel comes up is the
      // fake tunnel's to say.
      finder: PathFinder(probe: (p) async => 120, internet: () async => true),
      reporter: reporter,
      sweep: DoorSweep(appBypassesTunnel: false, reporter: reporter),
      networkKey: () async => 'mobile:IR-MCI',
      carrier: () async => 'IR-MCI',
      attemptTimeout: const Duration(seconds: 2),
    );
  }

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
          ChangeNotifierProvider<ConnectFlow>(create: (_) => flowFor(vpn)),
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

  /// Let the tap run to its end. Not pumpAndSettle: the button animates
  /// for as long as it is connecting.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> tapConnect(WidgetTester tester) async {
    await tester.tap(find.byType(PowerButton));
    await settle(tester);
  }

  /// Take the tunnel down, which stops the service's heartbeat and
  /// throughput timers that a connected tunnel starts.
  Future<void> disconnect(WidgetTester tester, _FakeVpn vpn) async {
    await vpn.disconnect();
    await tester.pump();
  }

  testWidgets('a picked shared link that fails falls through to our own', (
    tester,
  ) async {
    final vpn = _FakeVpn({_ours.id});
    final servers = _Servers()..selectServer(_official);

    await pumpHome(
      tester,
      dedicated: _FakeDedicated(loaded: true),
      servers: servers,
      vpn: vpn,
    );
    await tapConnect(tester);

    expect(vpn.connects, [_official, _ours]);
    expect(vpn.isConnected, isTrue);
    // Given up, so the next tap does not dial the dead link again.
    expect(servers.isChosen, isFalse);
    await disconnect(tester, vpn);
  });

  testWidgets('a picked shared link that works is kept', (tester) async {
    final vpn = _FakeVpn({_official.id, _ours.id});
    final servers = _Servers()..selectServer(_official);

    await pumpHome(
      tester,
      dedicated: _FakeDedicated(loaded: true),
      servers: servers,
      vpn: vpn,
    );
    await tapConnect(tester);

    expect(vpn.connects, [_official]);
    expect(servers.isChosen, isTrue);
    await disconnect(tester, vpn);
  });

  testWidgets(
    'a fallback link is not dialled when our own servers load on the tap',
    (tester) async {
      final vpn = _FakeVpn({_ours.id});
      final dedicated = _FakeDedicated(loaded: false);

      await pumpHome(
        tester,
        dedicated: dedicated,
        servers: _Servers(),
        vpn: vpn,
      );
      // The launch refresh failed; the card fell back to the official link.
      expect(dedicated.paths, isEmpty);
      dedicated.loadOnRefresh = true;

      await tapConnect(tester);

      expect(vpn.connects, [_ours]);
      expect(vpn.isConnected, isTrue);
      await disconnect(tester, vpn);
    },
  );

  testWidgets('the fallback link is still dialled when ours never load', (
    tester,
  ) async {
    final vpn = _FakeVpn({_official.id});
    final dedicated = _FakeDedicated(loaded: false);

    await pumpHome(tester, dedicated: dedicated, servers: _Servers(), vpn: vpn);
    final before = dedicated.refreshes;
    await tapConnect(tester);

    expect(dedicated.refreshes, before + 1);
    expect(vpn.connects, [_official]);
    await disconnect(tester, vpn);
  });
}
