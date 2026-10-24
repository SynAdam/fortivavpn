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
import 'package:fortiva_vpn/services/vpn_event_reporter.dart';
import 'package:fortiva_vpn/services/vpn_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A phone with Android's Private DNS set to a provider by name keeps
/// asking that provider while the tunnel is up. On 2026-10-02 a user's
/// phone moved data through the tunnel while YouTube failed with "DNS
/// address could not be found". The home screen says so while connected.
const _ours = Server(
  id: 'dedicated-0',
  name: 'Fortiva DE',
  country: 'Germany',
  city: 'Nuremberg',
  connectionUri: 'vless://ours@198.51.100.212:8443?security=reality#ours',
  flagEmoji: '\u{1F1E9}\u{1F1EA}',
  isDedicated: true,
  door: 'xhttp-reality',
  serverId: 10,
);

final _quota = QuotaStatus(
  unlimited: false,
  limitBytes: 1 << 30,
  usedBytes: 10 << 20,
  remainingBytes: (1 << 30) - (10 << 20),
  blocked: false,
  resetsAt: DateTime.now().add(const Duration(hours: 3)),
);

class _FakeDedicated extends DedicatedState {
  @override
  QuotaStatus? get quota => _quota;

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

/// A tunnel that is up, with the Private DNS host the test sets.
class _FakeVpn extends VpnService {
  _FakeVpn({required this.connected, this.host})
    : super(events: VpnEventReporter(send: (_, _, _) async {}));

  bool connected;
  String? host;
  int settingsOpened = 0;

  @override
  VpnStatus get status =>
      connected ? VpnStatus.connected : VpnStatus.disconnected;

  @override
  bool get isConnected => connected;

  @override
  bool get isConnecting => false;

  @override
  bool get isVerifying => false;

  @override
  ConnectionInfo? get currentConnection => null;

  @override
  String? get privateDnsHost => host;

  @override
  Future<void> checkPrivateDns() async {}

  @override
  Future<bool> openNetworkSettings() async {
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

  Future<void> pumpHome(WidgetTester tester, _FakeVpn vpn) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<DedicatedState>(
            create: (_) => _FakeDedicated(),
          ),
          ChangeNotifierProvider<ServerState>(create: (_) => _Servers()),
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

  final warning = find.textContaining('Private DNS is on (free.shecan.ir)');

  testWidgets('connected with Private DNS on: the warning names the host', (
    tester,
  ) async {
    final vpn = _FakeVpn(connected: true, host: 'free.shecan.ir');
    await pumpHome(tester, vpn);

    expect(warning, findsOneWidget);
    await tester.tap(find.text('Open network settings'));
    expect(vpn.settingsOpened, 1);
  });

  testWidgets('closed, it stays closed for the same host', (tester) async {
    final vpn = _FakeVpn(connected: true, host: 'free.shecan.ir');
    await pumpHome(tester, vpn);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();
    expect(warning, findsNothing);

    // Another provider is a new reason to say it.
    vpn.host = 'dns.403.online';
    vpn.notifyListeners();
    await tester.pump();
    expect(
      find.textContaining('Private DNS is on (dns.403.online)'),
      findsOneWidget,
    );
    // Down again, which stops the heartbeat a connected service keeps.
    vpn.connected = false;
    vpn.notifyListeners();
    await tester.pump();
  });

  testWidgets('no warning with Private DNS off', (tester) async {
    await pumpHome(tester, _FakeVpn(connected: true));
    expect(find.textContaining('Private DNS'), findsNothing);
  });

  testWidgets('no warning while disconnected', (tester) async {
    await pumpHome(tester, _FakeVpn(connected: false, host: 'free.shecan.ir'));
    expect(find.textContaining('Private DNS'), findsNothing);
  });

  group('VpnService.checkPrivateDns', () {
    late List<String> calls;
    Object? answer;

    setUp(() {
      calls = [];
      answer = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(tunnel, (call) async {
            calls.add(call.method);
            if (call.method == 'privateDns') {
              if (answer is Exception) throw answer!;
              return answer;
            }
            return call.method == 'getStatus' ? 'disconnected' : null;
          });
    });

    test(
      'reads the host the platform reports',
      () async {
        final vpn = VpnService(
          events: VpnEventReporter(send: (_, _, _) async {}),
        );
        answer = 'free.shecan.ir';
        await vpn.checkPrivateDns();
        expect(vpn.privateDnsHost, 'free.shecan.ir');

        answer = null;
        await vpn.checkPrivateDns();
        expect(vpn.privateDnsHost, isNull);
        expect(calls.where((c) => c == 'privateDns'), hasLength(2));
      },
      skip: !const bool.fromEnvironment('dart.library.io'),
    );

    test('a platform that will not say leaves the warning off', () async {
      final vpn = VpnService(
        events: VpnEventReporter(send: (_, _, _) async {}),
      );
      answer = PlatformException(code: 'nope');
      await vpn.checkPrivateDns();
      expect(vpn.privateDnsHost, isNull);
    });
  });
}
