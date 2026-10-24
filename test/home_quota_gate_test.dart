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
import 'package:fortiva_vpn/services/ipv6_reach.dart';
import 'package:fortiva_vpn/services/path_finder.dart';
import 'package:fortiva_vpn/services/path_memory.dart';
import 'package:fortiva_vpn/services/vpn_event_reporter.dart';
import 'package:fortiva_vpn/services/vpn_service.dart';
import 'package:fortiva_vpn/widgets/power_button.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The daily allowance is metered on this device's own servers only. The
/// shared links the app falls back to before provisioning lands are not
/// metered by anything, so if the home screen kept offering them once the
/// allowance was spent, the limit would only ever apply to users who did
/// not tap the button again. These tests pin the gate that stops that.
const _shared = Server(
  id: 'official-1',
  name: 'DE Falkenstein',
  country: 'Germany',
  city: 'Falkenstein',
  connectionUri: 'vless://u@198.51.100.201:443?security=reality#DE',
  flagEmoji: '\u{1F1E9}\u{1F1EA}',
);

QuotaStatus _quota({required bool blocked}) => QuotaStatus(
  unlimited: false,
  limitBytes: 100 << 20,
  usedBytes: blocked ? 100 << 20 : 10 << 20,
  remainingBytes: blocked ? 0 : 90 << 20,
  blocked: blocked,
  resetsAt: DateTime.now().add(const Duration(hours: 3)),
);

/// A device whose provisioning has answered, but with the servers
/// withheld: exactly what the backend returns over the allowance.
class _FakeDedicated extends DedicatedState {
  final QuotaStatus _fixed;
  _FakeDedicated(this._fixed);

  @override
  QuotaStatus? get quota => _fixed;

  @override
  bool get isBlocked => _fixed.blocked;

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

/// The shared list, already loaded, with one server picked.
class _FakeServers extends ServerState {
  int loads = 0;

  @override
  Server? get selectedServer => _shared;

  @override
  Future<void> loadServers({bool forceRefresh = false}) async {
    loads++;
  }

  @override
  int? getPingResult(String serverId) => 42;

  @override
  Future<void> pingServer(Server server) async {}
}

/// Records what the screen asks of the tunnel instead of dialling.
class _FakeVpn extends VpnService {
  VpnStatus _fake;
  final connects = <Server>[];
  int disconnects = 0;

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
    disconnects++;
    _fake = VpnStatus.disconnected;
    notifyListeners();
  }
}

/// The connect flow these screens dial through, with nothing that reaches
/// a platform channel: a widget test has none to answer. A phone with no
/// servers of its own races the shared links after a failed pick, and
/// that asks for the network type and checks links.
ConnectFlow _testFlow(VpnService vpn) => ConnectFlow(
  vpn: vpn,
  memory: PathMemory(),
  // A shared link's check passes, so a pick is dialled as the home screen
  // button dials it: checked first, then dialled. Our own doors are closed.
  finder: PathFinder(
    probe: (p) async => p.isDedicated ? -1 : 100,
    internet: () async => true,
  ),
  reporter: VpnEventReporter(
    send: (_, _, _) async {},
    sendProbes: (_, _, _) async {},
    deviceId: () async => 'DEV-1',
    appVersion: () async => '1.7.0',
    platform: 'android',
    networkType: () async => 'wifi',
  ),
  ipv6: Ipv6Reach(route: () async => false),
  networkKey: () async => 'wifi',
  carrier: () async => null,
  attemptTimeout: const Duration(seconds: 2),
);

void main() {
  /// The connect flow the last pump built.
  ConnectFlow? flow;

  /// Stop the dial a test started. The fake tunnel never settles by
  /// itself, and the flow's wait for it must not outlive the test.
  Future<void> stopConnect(WidgetTester tester) async {
    flow?.cancel();
    await tester.pump(const Duration(seconds: 30));
  }

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
            create: (_) => flow = _testFlow(vpn),
          ),
          // The header carries a language button, so the home screen
          // needs this the same way the real tree provides it.
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
    // Let the post-frame quota refresh and the service's start-up status
    // poll both run, so no timer is left pending at the end of the test.
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
  }

  group('home screen over the allowance', () {
    testWidgets('does not fall back to a shared server', (tester) async {
      final vpn = _FakeVpn();
      final servers = _FakeServers();
      await pumpHome(
        tester,
        dedicated: _FakeDedicated(_quota(blocked: true)),
        servers: servers,
        vpn: vpn,
      );

      expect(find.textContaining('Falkenstein'), findsNothing);
      expect(find.text('Daily data used up'), findsOneWidget);
      expect(find.text('Daily limit reached'), findsOneWidget);
      expect(find.text('Resets in 2h'), findsOneWidget);

      await tester.tap(find.byType(PowerButton));
      await tester.pump();

      expect(vpn.connects, isEmpty);
      expect(servers.loads, 0);
    });

    testWidgets('takes down a tunnel the allowance no longer covers', (
      tester,
    ) async {
      final vpn = _FakeVpn(status: VpnStatus.connected);
      await pumpHome(
        tester,
        dedicated: _FakeDedicated(_quota(blocked: true)),
        servers: _FakeServers(),
        vpn: vpn,
      );

      expect(vpn.disconnects, 1);
    });
  });

  group('home screen within the allowance', () {
    testWidgets('still uses the shared server before provisioning lands', (
      tester,
    ) async {
      final vpn = _FakeVpn();
      await pumpHome(
        tester,
        dedicated: _FakeDedicated(_quota(blocked: false)),
        servers: _FakeServers(),
        vpn: vpn,
      );

      expect(find.textContaining('Falkenstein'), findsOneWidget);
      expect(find.text('Tap to connect'), findsOneWidget);

      await tester.tap(find.byType(PowerButton));
      await tester.pump();

      expect(vpn.connects, [_shared]);
      expect(vpn.disconnects, 0);
      await stopConnect(tester);
    });
  });
}
