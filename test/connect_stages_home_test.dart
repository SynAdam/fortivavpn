import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/api/config_service.dart';
import 'package:fortiva_vpn/core/form_factor.dart';
import 'package:fortiva_vpn/core/state/connect_flow.dart';
import 'package:fortiva_vpn/core/state/dedicated_state.dart';
import 'package:fortiva_vpn/core/state/locale_state.dart';
import 'package:fortiva_vpn/core/state/server_state.dart';
import 'package:fortiva_vpn/data/models/checklist_settings.dart';
import 'package:fortiva_vpn/data/models/connection_info.dart';
import 'package:fortiva_vpn/data/models/server.dart';
import 'package:fortiva_vpn/l10n/generated/app_localizations.dart';
import 'package:fortiva_vpn/screens/home_screen.dart';
import 'package:fortiva_vpn/services/failure_verdict.dart';
import 'package:fortiva_vpn/services/path_finder.dart';
import 'package:fortiva_vpn/services/path_memory.dart';
import 'package:fortiva_vpn/services/vpn_event_reporter.dart';
import 'package:fortiva_vpn/services/vpn_service.dart';
import 'package:fortiva_vpn/widgets/path_checklist.dart';
import 'package:fortiva_vpn/widgets/power_button.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The home screen around the stages of the search (clients #342): the
/// status line names the stage, the red bar waits until the search has
/// ended and never offers a server the search found closed, a second line
/// says the search can take a while, and a connection through a community
/// server says so. Every name and address here is made up.
const _helsinki = Server(
  id: 'dedicated-hel',
  name: 'Fortiva FI',
  country: 'Finland',
  city: 'Helsinki',
  connectionUri: 'vless://u@203.0.113.226:443?type=tcp#FI',
  flagEmoji: '',
  isDedicated: true,
  door: 'tcp-reality',
  serverId: 13,
);

const _nuremberg = Server(
  id: 'dedicated-nue',
  name: 'Fortiva DE',
  country: 'Germany',
  city: 'Nuremberg',
  connectionUri: 'vless://u@203.0.113.227:443?type=tcp#DE',
  flagEmoji: '',
  isDedicated: true,
  door: 'tcp-reality',
  serverId: 14,
);

const _falkenstein = Server(
  id: 'dedicated-fsn',
  name: 'Fortiva DE2',
  country: 'Germany',
  city: 'Falkenstein',
  connectionUri: 'vless://u@203.0.113.228:443?type=tcp#DE2',
  flagEmoji: '',
  isDedicated: true,
  door: 'tcp-reality',
  serverId: 15,
);

final _community = Server(
  id: '${Server.communityIdPrefix}1',
  name: 'Community 2',
  country: '',
  city: '',
  connectionUri: 'vless://c@198.51.100.11:443#c',
  flagEmoji: '',
);

class _Dedicated extends DedicatedState {
  _Dedicated(this.own);

  final List<Server> own;
  Server? picked;

  @override
  QuotaStatus? get quota => null;

  @override
  bool get isBlocked => false;

  @override
  Server? get selectedServer => picked ?? own.first;

  @override
  bool get hasServers => true;

  @override
  List<Server> get servers => own;

  @override
  List<Server> get paths => own;

  @override
  void select(Server server, {bool byUser = true}) => picked = server;

  @override
  Future<void> refresh({bool? viaTunnel}) async {}

  @override
  int? pingFor(String serverId) => null;

  @override
  Future<void> pingServer(Server server) async {}
}

/// A device whose own servers have not arrived yet. The request that asks
/// for them waits on [gate].
class _NoServersYet extends DedicatedState {
  final gate = Completer<void>();

  @override
  QuotaStatus? get quota => null;

  @override
  bool get isBlocked => false;

  @override
  Server? get selectedServer => null;

  @override
  bool get hasServers => false;

  @override
  List<Server> get servers => const [];

  @override
  List<Server> get paths => const [];

  @override
  void select(Server server, {bool byUser = true}) {}

  @override
  Future<void> refresh({bool? viaTunnel}) => gate.future;

  @override
  int? pingFor(String serverId) => null;

  @override
  Future<void> pingServer(Server server) async {}
}

/// The shared list with [link] standing in for this device's servers:
/// not a pick.
class _StandIn extends ServerState {
  _StandIn(this.link);

  final Server link;

  @override
  Server? get selectedServer => link;

  @override
  bool get isChosen => false;

  @override
  Future<void> loadServers({bool forceRefresh = false}) async {}

  @override
  int? getPingResult(String serverId) => null;

  @override
  Future<void> pingServer(Server server) async {}

  @override
  Future<List<Server>> communityForFallback({
    Duration? wait,
    bool refresh = false,
  }) async => const [];
}

class _Servers extends ServerState {
  _Servers({this.chosen});

  final Server? chosen;

  @override
  Server? get selectedServer => chosen;

  @override
  bool get isChosen => chosen != null;

  @override
  Future<void> loadServers({bool forceRefresh = false}) async {}

  @override
  int? getPingResult(String serverId) => null;

  @override
  Future<void> pingServer(Server server) async {}

  @override
  Future<List<Server>> communityForFallback({
    Duration? wait,
    bool refresh = false,
  }) async => const [];
}

/// A service held at [fixed]. With [error], a tunnel failed before with a
/// diagnosis that says the server was not reached.
class _Vpn extends VpnService {
  _Vpn(this.fixed, {this.error = false, this.verifying = false})
    : super(events: VpnEventReporter(send: (_, _, _) async {}));

  final VpnStatus fixed;
  final bool error;
  final bool verifying;
  final connects = <Server>[];

  static const _unreached = {
    'control': 'ok',
    'dns': 'ok',
    'tcp': 'timeout',
    'tls': 'skipped',
  };

  @override
  VpnStatus get status => fixed;

  @override
  bool get isConnected => fixed == VpnStatus.connected;

  @override
  bool get isConnecting => fixed == VpnStatus.connecting;

  @override
  bool get isVerifying => verifying;

  @override
  String? get errorMessage => error ? 'Server not working, try another' : null;

  @override
  Map<String, dynamic>? get lastDiagnosis => error ? _unreached : null;

  @override
  FailureVerdict? get failureVerdict =>
      error ? verdictFor(diag: _unreached, error: 'Server not working') : null;

  @override
  ConnectionInfo? get currentConnection => fixed == VpnStatus.connected
      ? ConnectionInfo(
          startTime: DateTime.now(),
          serverId: 'x',
          serverName: 'x',
        )
      : null;

  @override
  Future<void> connect(
    Server server, {
    String? attemptId,
    List<Server> standby = const [],
    LinkSource? source,
  }) async => connects.add(server);

  @override
  Future<void> disconnect() async {}

  @override
  void clearError() {}
}

/// A flow held where a test puts it.
class _Held extends ConnectFlow {
  _Held(
    VpnService vpn,
    this.fixed, {
    this.running,
    this.states = const {},
    this.rows = const [],
    this.since,
  }) : super(vpn: vpn);

  final ConnectStage fixed;
  final RouteKind? running;
  final Map<RouteKind, StageState> states;
  final List<PathCheck> rows;
  final DateTime? since;

  @override
  ConnectStage get stage => fixed;

  @override
  bool get isBusy => searchRunning || fixed == ConnectStage.waiting;

  @override
  bool get showStages => searchRunning || fixed == ConnectStage.nothingOpen;

  @override
  List<PathCheck> get checks => rows;

  @override
  bool? get internet => true;

  @override
  RouteKind? get route => running;

  @override
  StageState stageState(RouteKind kind) => states[kind] ?? StageState.pending;

  @override
  DateTime? get searchStarted => since;
}

/// A flow held searching, whose search can start over ([restart]).
class _Restarting extends _Held {
  _Restarting(VpnService vpn, this.at)
    : super(
        vpn,
        ConnectStage.diagnosing,
        running: RouteKind.own,
        states: const {RouteKind.own: StageState.running},
      );

  DateTime at;

  @override
  DateTime? get searchStarted => at;

  void restart() {
    at = DateTime.now();
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

  Future<void> pumpHome(
    WidgetTester tester,
    VpnService vpn,
    ConnectFlow Function(VpnService vpn) flow, {
    List<Server> own = const [_helsinki, _nuremberg],
    Server? chosen,
    String locale = 'en',
    DedicatedState? dedicated,
    ServerState? servers,
  }) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<DedicatedState>.value(
            value: dedicated ?? _Dedicated(own),
          ),
          ChangeNotifierProvider<ServerState>.value(
            value: servers ?? _Servers(chosen: chosen),
          ),
          ChangeNotifierProvider<VpnService>.value(value: vpn),
          ChangeNotifierProvider<ConnectFlow>(create: (_) => flow(vpn)),
          ChangeNotifierProvider<LocaleState>(create: (_) => LocaleState()),
        ],
        child: MaterialApp(
          localizationsDelegates: S.localizationsDelegates,
          supportedLocales: S.supportedLocales,
          locale: Locale(locale),
          home: const HomeScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
  }

  Future<void> done(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
  }

  PathCheck blocked(Server s) => PathCheck(s, state: PathCheckState.blocked);

  group('the status line names the stage', () {
    testWidgets('our servers, from the first second', (tester) async {
      await pumpHome(
        tester,
        _Vpn(VpnStatus.connecting),
        (vpn) => _Held(
          vpn,
          ConnectStage.fastPath,
          running: RouteKind.own,
          states: const {RouteKind.own: StageState.running},
        ),
      );
      expect(find.text('Trying Fortiva servers'), findsOneWidget);
      expect(find.byType(PathChecklist), findsOneWidget);
      await done(tester);
    });

    testWidgets('also while a tunnel through the stage is checked, which is '
        'not yet a connection', (tester) async {
      await pumpHome(
        tester,
        _Vpn(VpnStatus.connected, verifying: true),
        (vpn) => _Held(
          vpn,
          ConnectStage.fastPath,
          running: RouteKind.own,
          states: const {RouteKind.own: StageState.running},
        ),
      );
      expect(find.text('Trying Fortiva servers'), findsOneWidget);
      expect(find.text('Checking connection'), findsNothing);
      expect(find.text('Connected'), findsNothing);
      await done(tester);
    });

    testWidgets('the community servers once ours did not connect', (
      tester,
    ) async {
      await pumpHome(
        tester,
        _Vpn(VpnStatus.disconnected),
        (vpn) => _Held(
          vpn,
          ConnectStage.diagnosing,
          running: RouteKind.community,
          states: const {
            RouteKind.own: StageState.failed,
            RouteKind.community: StageState.running,
          },
        ),
      );
      expect(
        find.text(
          'Fortiva servers did not connect here. Trying community servers.',
        ),
        findsOneWidget,
      );
      await done(tester);
    });

    testWidgets('the community servers first, on a phone without servers of '
        'its own', (tester) async {
      await pumpHome(
        tester,
        _Vpn(VpnStatus.connecting),
        (vpn) => _Held(
          vpn,
          ConnectStage.fastPath,
          running: RouteKind.community,
          states: const {
            RouteKind.own: StageState.skipped,
            RouteKind.community: StageState.running,
          },
        ),
      );
      expect(find.text('Trying community servers'), findsOneWidget);
      await done(tester);
    });

    testWidgets('in Persian', (tester) async {
      await pumpHome(
        tester,
        _Vpn(VpnStatus.disconnected),
        (vpn) => _Held(
          vpn,
          ConnectStage.diagnosing,
          running: RouteKind.community,
          states: const {
            RouteKind.own: StageState.failed,
            RouteKind.community: StageState.running,
          },
        ),
        locale: 'fa',
      );
      expect(
        find.text(
          'سرورهای فورتیوا اینجا وصل نشدند. حالا سرورهای عمومی را امتحان '
          'می‌کنیم.',
        ),
        findsOneWidget,
      );
      await done(tester);
    });
  });

  group('the red bar', () {
    testWidgets('waits while a later stage may still connect', (tester) async {
      await pumpHome(
        tester,
        _Vpn(VpnStatus.error, error: true),
        (vpn) => _Held(
          vpn,
          ConnectStage.diagnosing,
          running: RouteKind.community,
          states: const {
            RouteKind.own: StageState.failed,
            RouteKind.community: StageState.running,
          },
          rows: [blocked(_nuremberg)],
        ),
      );
      expect(
        find.textContaining('cannot be reached from your network'),
        findsNothing,
      );
      expect(find.textContaining('Start a new search'), findsNothing);
      await done(tester);
    });

    testWidgets('shows once the search has ended, and never offers a server '
        'this search found closed', (tester) async {
      await pumpHome(
        tester,
        _Vpn(VpnStatus.error, error: true),
        (vpn) => _Held(
          vpn,
          ConnectStage.nothingOpen,
          states: const {
            RouteKind.own: StageState.failed,
            RouteKind.community: StageState.skipped,
          },
          rows: [blocked(_helsinki), blocked(_nuremberg)],
        ),
        own: const [_helsinki, _nuremberg, _falkenstein],
      );
      expect(
        find.textContaining('cannot be reached from your network'),
        findsOneWidget,
      );
      // Nuremberg's paths read blocked on this search: Falkenstein, which
      // it did not reach, is offered, as a new search.
      expect(find.text('Start a new search on Fortiva DE'), findsNothing);
      expect(find.text('Start a new search on Fortiva DE2'), findsOneWidget);
      await done(tester);
    });

    testWidgets('offers nothing when every other server was found closed', (
      tester,
    ) async {
      await pumpHome(
        tester,
        _Vpn(VpnStatus.error, error: true),
        (vpn) => _Held(
          vpn,
          ConnectStage.nothingOpen,
          states: const {RouteKind.own: StageState.failed},
          rows: [blocked(_helsinki), blocked(_nuremberg)],
        ),
      );
      expect(
        find.textContaining('cannot be reached from your network'),
        findsOneWidget,
      );
      expect(find.textContaining('Start a new search'), findsNothing);
      await done(tester);
    });

    testWidgets('an offer while the app waits to try again starts a new '
        'search', (tester) async {
      final vpn = _Vpn(VpnStatus.error, error: true);
      // Every door closed, and a long wait before the next try.
      final flow = ConnectFlow(
        vpn: vpn,
        memory: PathMemory(),
        finder: PathFinder(probe: (_) async => -1, internet: () async => true),
        reporter: VpnEventReporter(
          send: (_, _, _) async {},
          sendProbes: (_, _, _) async {},
          deviceId: () async => 'DEV-1',
          appVersion: () async => '2.2.0',
          platform: 'android',
          networkType: () async => 'mobile',
        ),
        networkKey: () async => 'mobile',
        carrier: () async => null,
        checklist: () => const ChecklistSettings(
          retry: RetrySettings(after: [Duration(minutes: 5)]),
        ),
      );
      final stages = <ConnectStage>[];
      flow.addListener(() {
        if (stages.isEmpty || stages.last != flow.stage) stages.add(flow.stage);
      });
      await pumpHome(
        tester,
        vpn,
        (_) => flow,
        own: const [_helsinki, _falkenstein],
      );
      await tester.runAsync(() => flow.connect(const [_nuremberg]));
      await tester.pump();
      expect(flow.stage, ConnectStage.waiting);
      expect(find.text('Start a new search on Fortiva DE2'), findsOneWidget);

      stages.clear();
      await tester.tap(find.text('Start a new search on Fortiva DE2'));
      await tester.pump();

      // The wait ended, and a search started on the server the bar named,
      // where before the tap only stopped the wait.
      expect(stages.first, ConnectStage.cancelled);
      expect(stages, contains(ConnectStage.diagnosing));
      flow.cancel();
      await tester.pump(const Duration(seconds: 30));
      await done(tester);
    });
  });

  group('while a tap waits for this device\'s servers', () {
    // A phone with none of its own yet waits up to a few seconds for them
    // before its first try (connectFromButton). Found 2026-10-24 in review:
    // the screen showed only "Connecting" then, and the second line came
    // about 8 seconds late.
    testWidgets('the stages show at once, the red bar from before stays '
        'away, and the second line counts from the tap', (tester) async {
      final vpn = _Vpn(VpnStatus.error, error: true);
      final dedicated = _NoServersYet();
      await pumpHome(
        tester,
        vpn,
        (vpn) => ConnectFlow(vpn: vpn),
        dedicated: dedicated,
        servers: _StandIn(_community),
      );
      // The last tap's failure, before this one.
      expect(
        find.textContaining('cannot be reached from your network'),
        findsOneWidget,
      );

      await tester.tap(find.byType(PowerButton));
      await tester.pump();

      expect(find.byType(PathChecklist), findsOneWidget);
      expect(find.text('Stage 1 of 2'), findsOneWidget);
      expect(find.text('Getting your servers'), findsOneWidget);
      expect(find.text('Connecting'), findsOneWidget);
      expect(
        find.textContaining('cannot be reached from your network'),
        findsNothing,
      );
      const hint =
          'This can take a minute or two. Tap the button to stop the search.';
      expect(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.hint == hint,
        ),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 14));
      expect(find.text(hint), findsNothing);
      await tester.pump(const Duration(seconds: 1));
      expect(find.text(hint), findsOneWidget);

      // A stop ends the wait and its stages.
      await tester.tap(find.byType(PowerButton));
      await tester.pump();
      expect(find.text('Getting your servers'), findsNothing);
      expect(find.text('Search stopped'), findsOneWidget);
      dedicated.gate.complete();
      await tester.pump(HomeScreen.stoppedNote);
      await done(tester);
    });
  });

  group('a long search', () {
    testWidgets('says after 15 seconds that it can take a while and that '
        'the button stops it', (tester) async {
      await pumpHome(
        tester,
        _Vpn(VpnStatus.disconnected),
        (vpn) => _Held(
          vpn,
          ConnectStage.diagnosing,
          running: RouteKind.own,
          states: const {RouteKind.own: StageState.running},
          since: DateTime.now(),
        ),
      );
      const hint =
          'This can take a minute or two. Tap the button to stop the search.';
      // A screen reader on the button hears it for the whole search.
      expect(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.hint == hint,
        ),
        findsOneWidget,
      );
      // pumpHome waited 3 seconds already.
      await tester.pump(const Duration(seconds: 11));
      expect(find.text(hint), findsNothing);

      await tester.pump(const Duration(seconds: 1));
      expect(find.text(hint), findsOneWidget);
      await done(tester);
    });

    testWidgets('a new search starts the clock of the second line over', (
      tester,
    ) async {
      const hint =
          'This can take a minute or two. Tap the button to stop the search.';
      late _Restarting flow;
      await pumpHome(
        tester,
        _Vpn(VpnStatus.disconnected),
        (vpn) => flow = _Restarting(vpn, DateTime.now()),
      );
      await tester.pump(const Duration(seconds: 12));
      expect(find.text(hint), findsOneWidget);

      flow.restart();
      await tester.pump();
      expect(find.text(hint), findsNothing);
      await tester.pump(const Duration(seconds: 14));
      expect(find.text(hint), findsNothing);
      await tester.pump(const Duration(seconds: 1));
      expect(find.text(hint), findsOneWidget);
      await done(tester);
    });

    testWidgets('a stop while another search goes on does not say the '
        'search stopped', (tester) async {
      // The flow stays busy after the stop: a search that a pick started,
      // for one.
      await pumpHome(
        tester,
        _Vpn(VpnStatus.disconnected),
        (vpn) => _Held(
          vpn,
          ConnectStage.diagnosing,
          running: RouteKind.own,
          states: const {RouteKind.own: StageState.running},
        ),
      );

      await tester.tap(find.byType(PowerButton));
      await tester.pump();

      expect(find.text('Search stopped'), findsNothing);
      expect(find.text('Trying Fortiva servers'), findsOneWidget);
      await tester.pump(HomeScreen.stoppedNote);
      await done(tester);
    });

    testWidgets('in Persian', (tester) async {
      await pumpHome(
        tester,
        _Vpn(VpnStatus.disconnected),
        (vpn) => _Held(
          vpn,
          ConnectStage.diagnosing,
          running: RouteKind.own,
          states: const {RouteKind.own: StageState.running},
          since: DateTime.now().subtract(HomeScreen.slowSearchHint),
        ),
        locale: 'fa',
      );
      expect(
        find.text(
          'این کار ممکن است یکی دو دقیقه طول بکشد. برای توقف جستجو، دکمه را '
          'بزنید.',
        ),
        findsOneWidget,
      );
      await done(tester);
    });
  });

  testWidgets('connected through a community server, the line says so', (
    tester,
  ) async {
    await pumpHome(
      tester,
      _Vpn(VpnStatus.connected),
      (vpn) => _Held(vpn, ConnectStage.done),
      chosen: _community,
    );
    expect(find.text('Connected through a community server'), findsOneWidget);
    expect(find.text('Connected'), findsNothing);
    // Nothing more for a screen reader once connected.
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is Semantics &&
            w.properties.hint ==
                'This can take a minute or two. Tap the button to stop the '
                    'search.',
      ),
      findsNothing,
    );
    // No stage list once connected.
    expect(find.byType(PathChecklist), findsNothing);
    await done(tester);
  });

  testWidgets('connected through a community server, in Persian', (
    tester,
  ) async {
    await pumpHome(
      tester,
      _Vpn(VpnStatus.connected),
      (vpn) => _Held(vpn, ConnectStage.done),
      chosen: _community,
      locale: 'fa',
    );
    expect(find.text('از طریق سرور عمومی وصل شد'), findsOneWidget);
    await done(tester);
  });
  testWidgets('on a TV the stages sit beside the button, fit the screen, '
      'and the remote starts on the button', (tester) async {
    FormFactor.isTvForTest = true;
    addTearDown(() => FormFactor.isTvForTest = false);
    // 960 by 540 in logical pixels.
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final doors = [
      for (var i = 0; i < 9; i++)
        Server(
          id: 'dedicated-nue',
          name: 'Fortiva DE',
          country: 'Germany',
          city: 'Nuremberg',
          connectionUri: 'vless://u@203.0.113.227:44$i?type=tcp#DE',
          flagEmoji: '',
          isDedicated: true,
          door: 'door-$i',
          serverId: 14,
        ),
    ];
    await pumpHome(
      tester,
      _Vpn(VpnStatus.disconnected),
      (vpn) => _Held(
        vpn,
        ConnectStage.diagnosing,
        running: RouteKind.own,
        states: const {RouteKind.own: StageState.running},
        rows: [
          for (final d in doors.take(6)) blocked(d),
          PathCheck(doors[6], state: PathCheckState.running),
          for (final d in doors.skip(7)) PathCheck(d),
        ],
      ),
    );
    await tester.pump(Duration.zero);

    // A RenderFlex overflow is reported as an exception.
    expect(tester.takeException(), isNull);
    expect(find.text('6 paths tried, blocked here'), findsOneWidget);
    final button = tester.getRect(find.byType(PowerButton));
    for (final name in ['Fortiva servers', 'Community servers']) {
      final at = tester.getRect(find.text(name));
      expect(at.left, greaterThanOrEqualTo(button.right));
      expect(at.bottom, lessThanOrEqualTo(540));
    }
    final power = Focus.of(
      tester.element(
        find.descendant(
          of: find.byType(PowerButton),
          matching: find.byType(GestureDetector),
        ),
      ),
    );
    expect(power.hasPrimaryFocus, isTrue);
    await done(tester);
  });
}
