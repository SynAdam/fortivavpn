import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/core/design_system.dart';
import 'package:fortiva_vpn/core/state/connect_flow.dart';
import 'package:fortiva_vpn/core/state/dedicated_state.dart';
import 'package:fortiva_vpn/core/state/locale_state.dart';
import 'package:fortiva_vpn/core/state/server_state.dart';
import 'package:fortiva_vpn/data/models/connection_info.dart';
import 'package:fortiva_vpn/l10n/generated/app_localizations.dart';
import 'package:fortiva_vpn/screens/home_screen.dart';
import 'package:fortiva_vpn/services/vpn_service.dart';
import 'package:fortiva_vpn/widgets/elapsed_time.dart';
import 'package:fortiva_vpn/widgets/power_button.dart';
import 'package:fortiva_vpn/widgets/power_face.dart';
import 'package:fortiva_vpn/widgets/state_wash.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/app_theme.dart';
import 'helpers/invite_home.dart';

/// The power button's face and the light behind it come from the same
/// signals as the status line, so the button and the words never disagree.
/// A connect the user did not start in front of them gets no success
/// moment.

/// A tunnel the test moves through its states.
class _Vpn extends VpnService {
  VpnStatus fake = VpnStatus.disconnected;
  bool verifying = false;
  bool dead = false;
  bool checking = false;
  final DateTime _since = DateTime.now().subtract(const Duration(minutes: 1));

  void become(
    VpnStatus status, {
    bool verifying = false,
    bool dead = false,
    bool checking = false,
  }) {
    fake = status;
    this.verifying = verifying;
    this.dead = dead;
    this.checking = checking;
    notifyListeners();
  }

  @override
  VpnStatus get status => fake;
  @override
  bool get isConnected => fake == VpnStatus.connected;
  @override
  bool get isConnecting => fake == VpnStatus.connecting;
  @override
  bool get isVerifying => verifying;
  @override
  bool get stalled => dead && fake == VpnStatus.connected;
  @override
  bool get checkingTunnel => checking && fake == VpnStatus.connected && !dead;
  @override
  ConnectionInfo? get currentConnection => fake == VpnStatus.connected
      ? ConnectionInfo(startTime: _since, serverId: 'x', serverName: 'DE')
      : null;
  @override
  Future<void> disconnect() async => become(VpnStatus.disconnected);
}

/// A flow the test holds at a stage, searching after a dead tunnel or not.
class _Flow extends ConnectFlow {
  _Flow(VpnService vpn) : super(vpn: vpn);

  ConnectStage fixed = ConnectStage.idle;
  bool stall = false;

  void hold(ConnectStage stage, {bool stall = false}) {
    fixed = stage;
    this.stall = stall;
    notifyListeners();
  }

  @override
  ConnectStage get stage => fixed;
  @override
  bool get afterStall => stall;
  @override
  bool get isBusy => const {
    ConnectStage.fastPath,
    ConnectStage.diagnosing,
    ConnectStage.connecting,
    ConnectStage.waiting,
  }.contains(fixed);
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    mockTunnel([]);
  });
  tearDown(unmockTunnel);

  Future<(_Vpn, _Flow)> pumpHome(
    WidgetTester tester, {
    DedicatedState? dedicated,
  }) async {
    final vpn = _Vpn();
    final flow = _Flow(vpn);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<DedicatedState>.value(
            value: dedicated ?? FakeDedicated(),
          ),
          ChangeNotifierProvider<ServerState>.value(value: FakeServers()),
          ChangeNotifierProvider<VpnService>.value(value: vpn),
          ChangeNotifierProvider<ConnectFlow>.value(value: flow),
          ChangeNotifierProvider<LocaleState>(create: (_) => LocaleState()),
        ],
        child: MaterialApp(
          localizationsDelegates: S.localizationsDelegates,
          supportedLocales: S.supportedLocales,
          locale: const Locale('en'),
          theme: appThemeFor(const Locale('en')),
          home: const HomeScreen(),
        ),
      ),
    );
    await tester.pump();
    return (vpn, flow);
  }

  PowerButton button(WidgetTester tester) =>
      tester.widget<PowerButton>(find.byType(PowerButton));

  PowerFace wash(WidgetTester tester) =>
      tester.widget<StateWash>(find.byType(StateWash)).face;

  /// Take the tunnel down, which stops its timers, then the screen.
  Future<void> done(WidgetTester tester) async {
    final vpn =
        tester.element(find.byType(HomeScreen)).read<VpnService>() as _Vpn;
    vpn.become(VpnStatus.disconnected);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
  }

  testWidgets('the face follows the status line through a connect', (
    tester,
  ) async {
    final (vpn, flow) = await pumpHome(tester);
    void expectFace(PowerFace face, String status) {
      expect(button(tester).face, face, reason: status);
      expect(wash(tester), face, reason: status);
      expect(find.text(status), findsOneWidget);
      // A screen reader on the button hears the line's words.
      expect(button(tester).semanticLabel, status);
    }

    expectFace(PowerFace.off, 'Tap to connect');

    flow.hold(ConnectStage.diagnosing);
    await tester.pump();
    expectFace(PowerFace.connecting, 'Finding a path');

    flow.hold(ConnectStage.connecting);
    vpn.become(VpnStatus.connecting);
    await tester.pump();
    expectFace(PowerFace.connecting, 'Connecting');

    // Up but still being checked: busy, never drawn as connected.
    vpn.become(VpnStatus.connected, verifying: true);
    await tester.pump();
    expectFace(PowerFace.verifying, 'Checking connection');

    flow.hold(ConnectStage.done);
    vpn.become(VpnStatus.connected);
    await tester.pump();
    expectFace(PowerFace.connected, 'Connected');

    vpn.become(VpnStatus.connected, dead: true);
    await tester.pump();
    expectFace(PowerFace.stalled, 'Connected, but no data is getting through');

    vpn.become(VpnStatus.disconnecting);
    await tester.pump();
    expectFace(PowerFace.disconnecting, 'Disconnecting');
    await done(tester);
  });

  testWidgets('every failure the line names is a failed face', (tester) async {
    final (vpn, flow) = await pumpHome(tester);
    for (final (stage, status) in [
      (ConnectStage.noInternet, 'Your phone has no internet right now.'),
      (ConnectStage.nothingOpen, null),
      (ConnectStage.cutOff, null),
      (ConnectStage.failed, null),
    ]) {
      flow.hold(stage);
      await tester.pump();
      expect(button(tester).face, PowerFace.failed, reason: '$stage');
      if (status != null) expect(find.text(status), findsOneWidget);
    }
    flow.hold(ConnectStage.idle);
    vpn.become(VpnStatus.error);
    await tester.pump();
    expect(button(tester).face, PowerFace.failed);
    expect(find.text('Could not connect'), findsOneWidget);

    // Trying again soon is still part of connecting.
    flow.hold(ConnectStage.waiting);
    vpn.become(VpnStatus.disconnected);
    await tester.pump();
    expect(button(tester).face, PowerFace.connecting);
    await done(tester);
  });

  testWidgets('a spent allowance is the spent face', (tester) async {
    await pumpHome(
      tester,
      dedicated: FakeDedicated(inviteQuota(blocked: true)),
    );
    expect(button(tester).face, PowerFace.spent);
    expect(wash(tester), PowerFace.spent);
    expect(find.text('Daily data used up'), findsOneWidget);
    await done(tester);
  });

  testWidgets('a connect the user watches lands with its success moment', (
    tester,
  ) async {
    final (vpn, flow) = await pumpHome(tester);
    // The first frame after the app opens never celebrates.
    expect(button(tester).celebrate, isFalse);

    flow.hold(ConnectStage.connecting);
    vpn.become(VpnStatus.connecting);
    await tester.pump();
    expect(button(tester).celebrate, isTrue);

    flow.hold(ConnectStage.done);
    vpn.become(VpnStatus.connected);
    await tester.pump();
    expect(button(tester).face, PowerFace.connected);
    expect(button(tester).celebrate, isTrue);
    await done(tester);
  });

  testWidgets('a tunnel in doubt says it is being checked, not connected', (
    tester,
  ) async {
    final (vpn, flow) = await pumpHome(tester);
    flow.hold(ConnectStage.done);
    vpn.become(VpnStatus.connected);
    await tester.pump();
    expect(button(tester).face, PowerFace.connected);
    expect(find.text('Connected'), findsOneWidget);

    // A check through the tunnel failed once: it may be dead or throttled.
    vpn.become(VpnStatus.connected, checking: true);
    await tester.pump();
    expect(button(tester).face, PowerFace.verifying);
    expect(wash(tester), PowerFace.verifying);
    expect(find.text('Checking connection'), findsOneWidget);
    expect(find.text('Connected'), findsNothing);

    // The check passed: connected again, with no success moment, because
    // nobody tapped.
    vpn.become(VpnStatus.connected);
    await tester.pump();
    expect(button(tester).face, PowerFace.connected);
    expect(button(tester).celebrate, isFalse);

    // The check failed every try: the tunnel is called dead.
    vpn.become(VpnStatus.connected, checking: true);
    await tester.pump();
    vpn.become(VpnStatus.connected, dead: true);
    await tester.pump();
    expect(button(tester).face, PowerFace.stalled);
    await done(tester);
  });

  testWidgets('a connection that came back by itself is not celebrated', (
    tester,
  ) async {
    final (vpn, flow) = await pumpHome(tester);
    vpn.become(VpnStatus.connected, dead: true);
    await tester.pump();

    // The app looks for another path on its own.
    flow.hold(ConnectStage.diagnosing, stall: true);
    await tester.pump();
    expect(button(tester).face, PowerFace.connecting);
    expect(button(tester).celebrate, isFalse);

    // The flow stops saying so before the new tunnel is checked; the
    // connect is still the one that came back by itself.
    flow.hold(ConnectStage.connecting);
    vpn.become(VpnStatus.connected, verifying: true);
    await tester.pump();
    expect(button(tester).celebrate, isFalse);

    flow.hold(ConnectStage.done);
    vpn.become(VpnStatus.connected);
    await tester.pump();
    expect(button(tester).face, PowerFace.connected);
    expect(button(tester).celebrate, isFalse);

    // That connect is over: the next one the user starts celebrates.
    vpn.become(VpnStatus.disconnected);
    await tester.pump();
    flow.hold(ConnectStage.connecting);
    vpn.become(VpnStatus.connecting);
    await tester.pump();
    expect(button(tester).celebrate, isTrue);
    await done(tester);
  });

  testWidgets('a connect that finished while the app was away is not '
      'celebrated on the frame it first shows', (tester) async {
    final (vpn, flow) = await pumpHome(tester);
    flow.hold(ConnectStage.connecting);
    vpn.become(VpnStatus.connecting);
    await tester.pump();
    expect(button(tester).celebrate, isTrue);

    // The user leaves; the connect lands while no frame is drawn.
    final binding = tester.binding;
    for (final state in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
    ]) {
      binding.handleAppLifecycleStateChanged(state);
    }
    flow.hold(ConnectStage.done);
    vpn.become(VpnStatus.connected);

    // Back in front: the first frame shows it connected, with no moment.
    for (final state in [
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      binding.handleAppLifecycleStateChanged(state);
    }
    await tester.pump();
    expect(button(tester).face, PowerFace.connected);
    expect(button(tester).celebrate, isFalse);

    // Only that frame: the next connect the user watches celebrates.
    vpn.become(VpnStatus.disconnected);
    await tester.pump();
    flow.hold(ConnectStage.connecting);
    vpn.become(VpnStatus.connecting);
    await tester.pump();
    expect(button(tester).celebrate, isTrue);
    await done(tester);
  });

  testWidgets('a state is a title and a sentence is body text', (tester) async {
    final (vpn, flow) = await pumpHome(tester);
    TextStyle style(String text) => tester.widget<Text>(find.text(text)).style!;

    vpn.become(VpnStatus.connected);
    await tester.pump();
    expect(style('Connected').fontSize, 20);
    expect(style('Connected').fontWeight, FontWeight.w600);

    vpn.become(VpnStatus.disconnected);
    flow.hold(ConnectStage.noInternet);
    await tester.pump();
    final sentence = style('Your phone has no internet right now.');
    expect(sentence.fontSize, 16);
    expect(sentence.fontWeight, FontWeight.w400);
    expect(sentence.color, AppDesign.textPrimary);
    await done(tester);
  });

  testWidgets('the status line is a live region and the timer is not', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final (vpn, _) = await pumpHome(tester);
    vpn.become(VpnStatus.connected);
    await tester.pump();
    final timer = find.descendant(
      of: find.byType(ElapsedTime),
      matching: find.byType(Text),
    );
    expect(timer, findsOneWidget);
    final live = find.ancestor(
      of: find.text('Connected'),
      matching: find.byWidgetPredicate(
        (w) => w is Semantics && (w.properties.liveRegion ?? false),
      ),
    );
    expect(live, findsOneWidget);
    expect(
      find.ancestor(
        of: timer,
        matching: find.byWidgetPredicate(
          (w) => w is Semantics && (w.properties.liveRegion ?? false),
        ),
      ),
      findsNothing,
    );
    semantics.dispose();
    await done(tester);
  });

  testWidgets('the status line and timer stop growing at 1.3 text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final (vpn, _) = await pumpHome(tester);
    vpn.become(VpnStatus.connected);
    await tester.pump();

    // titleLarge, 20 at a line height of 1.3, scaled by 1.3 and no more.
    expect(tester.getSize(find.text('Connected')).height, closeTo(33.8, 0.5));
    // The timer's slot is its own line at that size (labelLarge, 15 at
    // 1.3), not a fixed height that cuts it off.
    final timer = find.descendant(
      of: find.byType(ElapsedTime),
      matching: find.byType(Text),
    );
    final slot = find
        .ancestor(of: find.byType(ElapsedTime), matching: find.byType(SizedBox))
        .first;
    expect(tester.getSize(slot).height, closeTo(15 * 1.3 * 1.3, 0.1));
    expect(
      tester.getSize(timer).height,
      lessThanOrEqualTo(tester.getSize(slot).height + 0.1),
    );
    await done(tester);
  });
}
