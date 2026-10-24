import 'dart:async';

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
import 'package:fortiva_vpn/services/path_memory.dart';
import 'package:fortiva_vpn/services/vpn_event_reporter.dart';
import 'package:fortiva_vpn/services/vpn_service.dart';
import 'package:fortiva_vpn/widgets/power_button.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The power button stops a connect the moment it is tapped, whatever part
/// of the connect is running. On 2026-10-07 the screen said "Checking
/// connection" and a tap did nothing: the button ignored every tap while it
/// was busy.
///
/// The one exception is the second tap of a double tap. Within
/// HomeScreen.doubleTapGuard of the tap that started the connect, a tap on
/// the button does not stop it.
const _own = Server(
  id: 'dedicated-edge.example:443',
  name: 'edge',
  country: 'Germany',
  city: 'Nuremberg',
  connectionUri: 'vless://u@edge.example:443?type=tcp#edge',
  flagEmoji: '',
  isDedicated: true,
  door: 'tcp-reality',
);

const _shared = Server(
  id: 'official-1',
  name: 'DE Falkenstein',
  country: 'Germany',
  city: 'Falkenstein',
  connectionUri: 'vless://u@198.51.100.201:443?security=reality#DE',
  flagEmoji: '',
);

/// This device's servers. [paths] empty is a device whose servers have not
/// arrived yet, and [refreshGate] holds the request that asks for them.
class _FakeDedicated extends DedicatedState {
  _FakeDedicated({this.own = true});

  final bool own;
  Completer<void>? refreshGate;

  @override
  QuotaStatus? get quota => null;

  @override
  bool get isBlocked => false;

  @override
  Server? get selectedServer => own ? _own : null;

  @override
  bool get hasServers => own;

  @override
  List<Server> get servers => own ? const [_own] : const [];

  @override
  List<Server> get paths => own ? const [_own] : const [];

  @override
  void select(Server server, {bool byUser = true}) {}

  @override
  Future<void> refresh({bool? viaTunnel}) async => refreshGate?.future;

  @override
  int? pingFor(String serverId) => null;

  @override
  Future<void> pingServer(Server server) async {}
}

/// The shared list, loaded, with a link in it that is not a pick.
class _FakeServers extends ServerState {
  @override
  Server? get selectedServer => _shared;

  @override
  Future<void> loadServers({bool forceRefresh = false}) async {}

  @override
  int? getPingResult(String serverId) => 42;

  @override
  Future<void> pingServer(Server server) async {}

  /// No other shared link to fall back on, and no fetch for one.
  @override
  Future<List<Server>> communityForFallback({
    Duration? wait,
    bool refresh = false,
  }) async => const [];
}

/// Records what the screen asks of the tunnel. A stop shows as
/// "Disconnecting" and stays there, the way it does while the platform
/// takes the tunnel down. With [fails], every tunnel fails as it starts.
class _FakeVpn extends VpnService {
  _FakeVpn({
    VpnStatus status = VpnStatus.disconnected,
    bool verifying = false,
    this.fails = false,
  }) : _fake = status,
       _verifying = verifying;

  final bool fails;
  VpnStatus _fake;
  bool _verifying;
  final connects = <Server>[];
  int disconnects = 0;

  @override
  VpnStatus get status => _fake;

  @override
  bool get isConnected => _fake == VpnStatus.connected;

  @override
  bool get isConnecting => _fake == VpnStatus.connecting;

  @override
  bool get isVerifying => _verifying;

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
    if (fails) {
      _fake = VpnStatus.error;
      notifyListeners();
    }
  }

  @override
  Future<void> disconnect() async {
    disconnects++;
    if (_fake == VpnStatus.connected || _fake == VpnStatus.connecting) {
      _verifying = false;
      _fake = VpnStatus.disconnecting;
      notifyListeners();
    }
  }

  @override
  void clearError() {
    if (_fake == VpnStatus.error) _fake = VpnStatus.disconnected;
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

  /// A flow whose door checks answer as [probe] does.
  ConnectFlow probedFlow(VpnService vpn, DoorProbe probe) => ConnectFlow(
    vpn: vpn,
    memory: PathMemory(),
    finder: PathFinder(probe: probe, internet: () async => true),
    reporter: VpnEventReporter(
      send: (_, _, _) async {},
      sendProbes: (_, _, _) async {},
      deviceId: () async => 'DEV-1',
      appVersion: () async => '1.6.13',
      platform: 'android',
      networkType: () async => 'mobile',
    ),
    networkKey: () async => 'mobile:Irancell',
    carrier: () async => 'Irancell',
  );

  /// A flow whose door checks wait on [gate], so a test can tap while the
  /// checklist is on screen.
  ConnectFlow heldFlow(VpnService vpn, Completer<int> gate) =>
      probedFlow(vpn, (_) => gate.future);

  /// A flow for a tap on a phone with no servers of its own: only the
  /// shared links are checked and dialled, and their checks pass.
  ConnectFlow sharedFlow(VpnService vpn) => probedFlow(vpn, (_) async => 120);

  Future<void> pumpHome(
    WidgetTester tester, {
    required _FakeVpn vpn,
    _FakeDedicated? dedicated,
    ConnectFlow? flow,
  }) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<DedicatedState>.value(
            value: dedicated ?? _FakeDedicated(),
          ),
          ChangeNotifierProvider<ServerState>.value(value: _FakeServers()),
          ChangeNotifierProvider<VpnService>.value(value: vpn),
          ChangeNotifierProvider<ConnectFlow>(
            create: (_) => flow ?? ConnectFlow(vpn: vpn),
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
    // Let the post-frame quota refresh and the service's start-up status
    // poll both run, so no timer is left pending at the end of the test.
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
  }

  Future<void> tapButton(WidgetTester tester) async {
    await tester.tap(find.byType(PowerButton));
    await tester.pump();
  }

  testWidgets('a tap while the tunnel is being checked stops it at once', (
    tester,
  ) async {
    final vpn = _FakeVpn(status: VpnStatus.connected, verifying: true);
    await pumpHome(tester, vpn: vpn);
    expect(find.text('Checking connection'), findsOneWidget);

    await tapButton(tester);

    expect(vpn.disconnects, 1);
    expect(vpn.connects, isEmpty);
    expect(find.text('Checking connection'), findsNothing);
    expect(find.text('Disconnecting'), findsOneWidget);
  });

  testWidgets('a tap while the tunnel is starting stops it at once', (
    tester,
  ) async {
    final vpn = _FakeVpn(status: VpnStatus.connecting);
    await pumpHome(tester, vpn: vpn);
    expect(find.text('Connecting'), findsOneWidget);

    await tapButton(tester);

    expect(vpn.disconnects, 1);
    expect(find.text('Disconnecting'), findsOneWidget);
  });

  testWidgets('a tap while the checklist runs stops it, and the door it was '
      'checking is not dialled', (tester) async {
    final vpn = _FakeVpn();
    final gate = Completer<int>();
    final flow = heldFlow(vpn, gate);
    await pumpHome(tester, vpn: vpn, flow: flow);

    await tester.runAsync(() async {
      unawaited(flow.connect(const [_own], preferred: _own));
      while (!flow.isDiagnosing) {
        await Future<void>.delayed(Duration.zero);
      }
    });
    await tester.pump();
    expect(find.text('Trying Fortiva servers'), findsOneWidget);

    await tapButton(tester);

    expect(flow.stage, ConnectStage.cancelled);
    expect(find.text('Trying Fortiva servers'), findsNothing);
    // The screen says the search stopped, for a moment (clients #342).
    expect(find.text('Search stopped'), findsOneWidget);
    await tester.pump(HomeScreen.stoppedNote);
    expect(find.text('Search stopped'), findsNothing);
    expect(find.text('Tap to connect'), findsOneWidget);

    // The check in flight comes back open, after the stop.
    await tester.runAsync(() async {
      gate.complete(120);
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await tester.pump();
    expect(vpn.connects, isEmpty);
    expect(flow.stage, ConnectStage.cancelled);
  });

  testWidgets('a tap while waiting for this device\'s servers stops it, and '
      'nothing is dialled when they arrive', (tester) async {
    final vpn = _FakeVpn();
    final dedicated = _FakeDedicated(own: false);
    await pumpHome(tester, vpn: vpn, dedicated: dedicated);
    dedicated.refreshGate = Completer<void>();

    await tapButton(tester);
    expect(find.text('Connecting'), findsOneWidget);

    // Past the double-tap guard: this tap is a deliberate stop.
    await tester.pump(HomeScreen.doubleTapGuard);
    expect(find.text('Connecting'), findsOneWidget);
    await tapButton(tester);
    expect(find.text('Search stopped'), findsOneWidget);

    dedicated.refreshGate!.complete();
    await tester.pump();
    await tester.pump();
    expect(vpn.connects, isEmpty);
    expect(find.text('Search stopped'), findsOneWidget);
    await tester.pump(HomeScreen.stoppedNote);
    expect(find.text('Tap to connect'), findsOneWidget);
  });

  testWidgets('the second tap of a double tap does not stop the connect the '
      'first one started', (tester) async {
    final vpn = _FakeVpn();
    final dedicated = _FakeDedicated(own: false);
    final flow = sharedFlow(vpn);
    await pumpHome(tester, vpn: vpn, dedicated: dedicated, flow: flow);
    dedicated.refreshGate = Completer<void>();

    await tapButton(tester);
    await tester.pump(const Duration(milliseconds: 300));
    await tapButton(tester);

    expect(find.text('Connecting'), findsOneWidget);
    expect(vpn.disconnects, 0);
    expect(flow.stage, isNot(ConnectStage.cancelled));

    // The ignored tap did not count as a stop, so the connect the first
    // tap started still dials when this device's servers have been asked
    // for.
    dedicated.refreshGate!.complete();
    await tester.pump();
    await tester.pump();
    expect(vpn.connects, [_shared]);
    expect(flow.isBusy, isTrue);
    // A phone with no servers of its own tries the shared links.
    expect(find.text('Trying community servers'), findsOneWidget);

    // The tunnel never answers in this test: end the attempt rather than
    // leave its timeout pending.
    flow.cancel();
    await tester.pump();
  });

  testWidgets('the guard holds back only a stop: a tap after a connect that '
      'has ended connects again', (tester) async {
    final vpn = _FakeVpn(fails: true);
    final flow = sharedFlow(vpn);
    await pumpHome(
      tester,
      vpn: vpn,
      dedicated: _FakeDedicated(own: false),
      flow: flow,
    );

    await tapButton(tester);
    await tester.pump();
    expect(vpn.connects, [_shared]);
    expect(flow.stage, ConnectStage.nothingOpen);
    expect(find.text('Connecting'), findsNothing);

    // Still within the guard of the first tap.
    await tester.pump(const Duration(milliseconds: 300));
    await tapButton(tester);
    await tester.pump();
    expect(vpn.connects, [_shared, _shared]);
    expect(vpn.disconnects, 0);
  });

  testWidgets('a tap while the tunnel is coming down does nothing', (
    tester,
  ) async {
    final vpn = _FakeVpn(status: VpnStatus.disconnecting);
    await pumpHome(tester, vpn: vpn);

    await tapButton(tester);

    expect(vpn.connects, isEmpty);
    expect(vpn.disconnects, 0);
    expect(find.text('Disconnecting'), findsOneWidget);
  });
}
