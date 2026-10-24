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
import 'package:fortiva_vpn/services/failure_verdict.dart';
import 'package:fortiva_vpn/services/vpn_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The app runs a one second diagnosis on every failure and knew things
/// like "TCP to this server timed out while the internet works" while
/// telling the user "Server not working, try another". These tests pin
/// the sentence and the offer onto the screen.
const _first = Server(
  id: 'dedicated-0',
  name: 'Fortiva DE',
  country: 'Germany',
  city: 'Falkenstein',
  connectionUri: 'vless://u@198.51.100.201:443?security=reality#DE',
  flagEmoji: '\u{1F1E9}\u{1F1EA}',
  isDedicated: true,
);

const _second = Server(
  id: 'dedicated-1',
  name: 'Fortiva FI',
  country: 'Finland',
  city: 'Helsinki',
  connectionUri: 'vless://u@198.51.100.202:443?security=reality#FI',
  flagEmoji: '\u{1F1EB}\u{1F1EE}',
  isDedicated: true,
);

QuotaStatus _quota() => QuotaStatus(
  unlimited: false,
  limitBytes: 100 << 20,
  usedBytes: 10 << 20,
  remainingBytes: 90 << 20,
  blocked: false,
  resetsAt: DateTime.now().add(const Duration(hours: 3)),
);

class _FakeDedicated extends DedicatedState {
  _FakeDedicated({this.own = const [_first, _second]});

  final List<Server> own;
  Server? _selected = _first;

  @override
  QuotaStatus? get quota => _quota();

  @override
  bool get isBlocked => false;

  @override
  Server? get selectedServer => _selected;

  @override
  bool get hasServers => true;

  @override
  List<Server> get servers => List.unmodifiable(own);

  @override
  List<Server> get paths => List.unmodifiable(own);

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
  Future<void> pingServer(Server server) async {}
}

const _shared = Server(
  id: 'official-1',
  name: 'DE Falkenstein',
  country: 'Germany',
  city: 'Falkenstein',
  // A link the door check can read: a pick is checked before it is
  // dialled.
  connectionUri:
      'vless://00000000-0000-4000-8000-000000000001@203.0.113.201:443'
      '?security=reality#SHARED',
  flagEmoji: '\u{1F1E9}\u{1F1EA}',
);

class _Servers extends ServerState {
  _Servers({this.shared = const []});

  final List<Server> shared;

  @override
  List<Server> get officialServers => List.unmodifiable(shared);

  @override
  Future<void> loadServers({bool forceRefresh = false}) async {}

  @override
  int? getPingResult(String serverId) => 42;

  @override
  Future<void> pingServer(Server server) async {}
}

/// A tunnel that has already failed, with the diagnosis the failure left.
class _FailedVpn extends VpnService {
  _FailedVpn({
    required this.diag,
    required this.reason,
    this.needsSettings = false,
  });

  final Map<String, dynamic>? diag;
  final String reason;
  final bool needsSettings;
  final connects = <Server>[];
  int settingsOpened = 0;

  @override
  VpnStatus get status => VpnStatus.error;

  @override
  bool get isConnected => false;

  @override
  bool get isConnecting => false;

  @override
  bool get isVerifying => false;

  @override
  ConnectionInfo? get currentConnection => null;

  @override
  String? get errorMessage => reason;

  @override
  bool get errorNeedsVpnSettings => needsSettings;

  @override
  Map<String, dynamic>? get lastDiagnosis => diag;

  @override
  FailureVerdict? get failureVerdict => verdictFor(diag: diag, error: reason);

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
  Future<void> disconnect() async {}

  @override
  void clearError() {}

  @override
  Future<bool> openVpnSettings() async {
    settingsOpened++;
    return true;
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

  Future<_FakeDedicated> pumpHome(
    WidgetTester tester,
    _FailedVpn vpn, {
    ServerState? servers,
    List<Server> own = const [_first, _second],
  }) async {
    final dedicated = _FakeDedicated(own: own);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<DedicatedState>.value(value: dedicated),
          ChangeNotifierProvider<ServerState>.value(
            value: servers ?? _Servers(),
          ),
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
    return dedicated;
  }

  testWidgets('a cut handshake is named, not called "try another"', (
    tester,
  ) async {
    final vpn = _FailedVpn(
      diag: const {'control': 'ok', 'dns': 'ok', 'tcp': 'ok', 'tls': 'reset'},
      reason: 'Server not working, try another',
    );
    await pumpHome(tester, vpn);

    expect(
      find.textContaining('being cut while it is being set up'),
      findsOneWidget,
    );
    expect(find.text('Server not working, try another'), findsNothing);
  });

  testWidgets('an unreachable server offers the next one by name', (
    tester,
  ) async {
    final vpn = _FailedVpn(
      diag: const {
        'control': 'ok',
        'dns': 'ok',
        'tcp': 'timeout',
        'tls': 'skipped',
      },
      reason: 'Server not working, try another',
    );
    final dedicated = await pumpHome(tester, vpn);

    expect(
      find.textContaining('cannot be reached from your network'),
      findsOneWidget,
    );
    expect(find.text('Start a new search on Fortiva FI'), findsOneWidget);

    await tester.tap(find.text('Start a new search on Fortiva FI'));
    await tester.pump();

    // The offer moves the device onto the server it named. Dialling it is
    // the connect button's existing path: one of this device's own goes
    // through ConnectFlow, which picks the door.
    expect(dedicated.selectedServer, _second);
    // The user tapped an offer that names it, so it is a pick.
    expect(dedicated.selectedByUser, isTrue);
  });

  testWidgets('a shared server offered instead is dialled on the tap', (
    tester,
  ) async {
    final vpn = _FailedVpn(
      diag: const {
        'control': 'ok',
        'dns': 'ok',
        'tcp': 'timeout',
        'tls': 'skipped',
      },
      reason: 'Server not working, try another',
    );
    final servers = _Servers(shared: const [_shared]);
    // Only one server of our own, so the alternative has to come off the
    // shared list. That path does not go through the door checklist.
    await pumpHome(tester, vpn, servers: servers, own: const [_first]);

    expect(find.text('Start a new search on DE Falkenstein'), findsOneWidget);
    await tester.tap(find.text('Start a new search on DE Falkenstein'));
    await tester.pump();
    // The pick's check answers first.
    await tester.pump(const Duration(milliseconds: 100));

    expect(vpn.connects.single.id, _shared.id);
    expect(servers.selectedServer, _shared);
    expect(servers.isChosen, isTrue);
  });

  testWidgets('no internet says so and offers no server', (tester) async {
    final vpn = _FailedVpn(
      diag: const {'control': 'fail'},
      reason: 'Server not working, try another',
    );
    await pumpHome(tester, vpn);

    expect(find.textContaining('no internet connection'), findsOneWidget);
    expect(find.text('Check your internet'), findsOneWidget);
    expect(find.textContaining('Fortiva FI'), findsNothing);
  });

  testWidgets('a permission failure still leads to VPN settings', (
    tester,
  ) async {
    final vpn = _FailedVpn(
      diag: const {'control': 'ok', 'vpn_permission': false},
      reason: 'VPN permission is required',
      needsSettings: true,
    );
    await pumpHome(tester, vpn);

    expect(find.textContaining('does not have permission'), findsOneWidget);
    await tester.tap(find.text('Open VPN settings'));
    await tester.pump();
    expect(vpn.settingsOpened, 1);
  });

  testWidgets('the raw checks are behind a details tap', (tester) async {
    final vpn = _FailedVpn(
      diag: const {
        'control': 'ok',
        'dns': 'ok',
        'tcp': 'ok',
        'tls': 'reset',
        'carrier': 'Irancell',
        'core_log': 'thousands of characters of logcat',
      },
      reason: 'Server not working, try another',
    );
    await pumpHome(tester, vpn);

    expect(find.textContaining('tls: reset'), findsNothing);
    await tester.tap(find.text('Details'));
    await tester.pump();

    expect(find.textContaining('tls: reset'), findsOneWidget);
    expect(find.textContaining('carrier: Irancell'), findsOneWidget);
    // The log is already on the event this failure sent, and it would
    // fill the screen.
    expect(find.textContaining('logcat'), findsNothing);
  });

  testWidgets('a failure with no diagnosis keeps the plain message', (
    tester,
  ) async {
    final vpn = _FailedVpn(diag: null, reason: 'Unexpected error: broken pipe');
    await pumpHome(tester, vpn);

    expect(find.text('Unexpected error: broken pipe'), findsOneWidget);
    expect(find.text('Details'), findsNothing);
  });
}
