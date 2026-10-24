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

/// An allowance that runs out during a session must not be shown as a
/// dead server.
///
/// On 2026-10-02 a new install used 103.6 MB of its 100 MB in fourteen
/// minutes. The backend turned its servers off, and the next tap ended at
/// "Server not working, try another" because the screen still held the
/// allowance it had read at launch.
const _ours = Server(
  id: 'dedicated-0',
  name: 'Fortiva DE',
  country: 'Germany',
  city: 'Nuremberg',
  connectionUri: 'vless://ours@198.51.100.215:443?security=tls&type=ws#ours',
  flagEmoji: '\u{1F1E9}\u{1F1EA}',
  isDedicated: true,
  door: 'ws-tls',
  serverId: 10,
);

QuotaStatus _quota({required bool blocked}) => QuotaStatus(
  unlimited: false,
  limitBytes: 100 << 20,
  usedBytes: blocked ? 103 << 20 : 60 << 20,
  remainingBytes: blocked ? 0 : 40 << 20,
  blocked: blocked,
  resetsAt: DateTime.now().add(const Duration(hours: 3)),
);

/// A device with its own server loaded, whose next [refresh] reports
/// whatever the backend says by then.
class _FakeDedicated extends DedicatedState {
  /// What the backend would answer now.
  bool spentOnBackend = false;
  bool _blocked = false;
  int refreshes = 0;

  @override
  QuotaStatus? get quota => _quota(blocked: _blocked);

  @override
  bool get isBlocked => _blocked;

  // Over the allowance the backend withholds the servers.
  @override
  Server? get selectedServer => _blocked ? null : _ours;

  @override
  bool get hasServers => !_blocked;

  @override
  List<Server> get servers => _blocked ? const [] : const [_ours];

  @override
  List<Server> get paths => _blocked ? const [] : const [_ours];

  @override
  void select(Server server, {bool byUser = true}) {}

  @override
  Future<void> refresh({bool? viaTunnel}) async {
    refreshes++;
    _blocked = spentOnBackend;
    notifyListeners();
  }

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

/// A tunnel that fails through every link, as one does once the backend
/// has turned the device's servers off.
class _FakeVpn extends VpnService {
  final connects = <Server>[];
  VpnStatus _fake = VpnStatus.disconnected;
  String? _error;

  @override
  VpnStatus get status => _fake;

  @override
  String? get errorMessage => _error;

  @override
  bool get isConnected => false;

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
    _fake = VpnStatus.error;
    _error = 'Server not working, try another';
    notifyListeners();
  }

  @override
  void clearError() {
    _error = null;
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
      finder: PathFinder(probe: (p) async => 120, internet: () async => true),
      reporter: reporter,
      sweep: DoorSweep(appBypassesTunnel: false, reporter: reporter),
      networkKey: () async => 'mobile:Irancell',
      carrier: () async => 'Irancell',
      attemptTimeout: const Duration(seconds: 2),
    );
  }

  Future<void> pumpHome(
    WidgetTester tester, {
    required _FakeDedicated dedicated,
    required _FakeVpn vpn,
  }) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<DedicatedState>.value(value: dedicated),
          ChangeNotifierProvider<ServerState>(create: (_) => _Servers()),
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
  Future<void> tapConnect(WidgetTester tester) async {
    await tester.tap(find.byType(PowerButton));
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('a failed connect on a spent allowance says so', (tester) async {
    final vpn = _FakeVpn();
    final dedicated = _FakeDedicated();
    await pumpHome(tester, dedicated: dedicated, vpn: vpn);
    expect(find.text('Tap to connect'), findsOneWidget);

    // The allowance runs out after the screen last read it.
    dedicated.spentOnBackend = true;
    final before = dedicated.refreshes;
    await tapConnect(tester);

    expect(vpn.connects, [_ours]);
    expect(dedicated.refreshes, before + 1);
    expect(find.text('Daily data used up'), findsOneWidget);
    expect(find.text('Could not connect'), findsNothing);
    expect(vpn.errorMessage, isNull);
  });

  testWidgets('a failed connect with allowance left is still a failure', (
    tester,
  ) async {
    final vpn = _FakeVpn();
    final dedicated = _FakeDedicated();
    await pumpHome(tester, dedicated: dedicated, vpn: vpn);

    await tapConnect(tester);

    expect(vpn.connects, [_ours]);
    expect(find.text('Daily data used up'), findsNothing);
    expect(vpn.errorMessage, 'Server not working, try another');
  });
}
