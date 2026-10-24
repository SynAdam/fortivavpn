import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/core/design_system.dart';
import 'package:fortiva_vpn/core/state/connect_flow.dart';
import 'package:fortiva_vpn/data/models/server.dart';
import 'package:fortiva_vpn/l10n/generated/app_localizations.dart';
import 'package:fortiva_vpn/services/path_finder.dart';
import 'package:fortiva_vpn/services/path_memory.dart';
import 'package:fortiva_vpn/services/vpn_event_reporter.dart';
import 'package:fortiva_vpn/services/vpn_service.dart';
import 'package:fortiva_vpn/widgets/path_checklist.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The search as stages on screen (clients #342): Fortiva servers, then
/// community servers, then the backup network, each pending, running,
/// connected, failed or skipped. Only the running stage shows its rows, and
/// a finished one is one line. Every name and address here is made up.
Server door(String city, int n) => Server(
  id: 'dedicated-$city-$n',
  name: city,
  country: '',
  city: city,
  connectionUri: 'vless://u@$city$n.example:443?type=tcp#$city',
  flagEmoji: '',
  isDedicated: true,
  door: 'door-$n',
);

Server community(int i) => Server(
  id: '${Server.communityIdPrefix}$i',
  name: 'Community ${i + 1}',
  country: '',
  city: '',
  connectionUri: 'vless://c$i@198.51.100.${10 + i}:443#c',
  flagEmoji: '',
);

final nuremberg = [for (var n = 0; n < 4; n++) door('Nuremberg', n)];
final helsinki = [for (var n = 0; n < 4; n++) door('Helsinki', n)];
final links = [for (var i = 0; i < 3; i++) community(i)];

PathCheck row(Server s, PathCheckState state, {int? ms}) =>
    PathCheck(s, state: state, ms: ms);

/// Every own door read blocked.
List<PathCheck> ownBlocked() => [
  for (final d in [...nuremberg, ...helsinki]) row(d, PathCheckState.blocked),
];

/// A flow held where a test puts it.
class _Held extends ConnectFlow {
  _Held({
    this.fixed = ConnectStage.diagnosing,
    this.rows = const [],
    this.running,
    this.states = const {},
    this.on,
    this.next,
    this.at,
    this.backup = true,
    this.fast,
    this.fresh = true,
    this.starting = false,
  }) : super(
         vpn: VpnService(events: VpnEventReporter(send: (_, _, _) async {})),
       );

  final ConnectStage fixed;
  final List<PathCheck> rows;
  final RouteKind? running;
  final Map<RouteKind, StageState> states;
  final Server? on;
  final RouteKind? next;
  final DateTime? at;
  final bool backup;
  final Server? fast;
  final bool fresh;
  final bool starting;

  @override
  bool get nextTryStarting => starting;

  @override
  bool get backupMayRun => backup;

  @override
  Server? get fastPathDoor => fast;

  @override
  bool get checksAreThisTry => fresh;

  @override
  ConnectStage get stage => fixed;

  @override
  Server? get chosen => on;

  @override
  List<PathCheck> get checks => rows;

  @override
  bool? get internet => true;

  @override
  RouteKind? get route => running;

  @override
  StageState stageState(RouteKind kind) => states[kind] ?? StageState.pending;

  @override
  bool stageAvailable(RouteKind kind) => backup || kind != RouteKind.backup;

  @override
  ({int number, int count})? get stageProgress => running == null
      ? null
      : (number: running!.index + 1, count: backup ? 3 : 2);

  @override
  RouteKind? get nextTryFrom => next;

  @override
  DateTime? get retryAt => at;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Widget wrap(
    ConnectFlow flow, {
    String locale = 'en',
    bool reduce = false,
    DateTime Function()? clock,
    bool gettingServers = false,
  }) => MaterialApp(
    localizationsDelegates: S.localizationsDelegates,
    supportedLocales: S.supportedLocales,
    locale: Locale(locale),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: reduce),
      child: child!,
    ),
    home: Scaffold(
      body: ListenableBuilder(
        listenable: flow,
        builder: (_, _) => PathChecklist(
          flow: flow,
          clock: clock,
          gettingServers: gettingServers,
        ),
      ),
    ),
  );

  /// Clears the tree and lets the service's first look at the platform
  /// run, so no test ends with its timer pending.
  Future<void> done(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
  }

  /// The mark of the stage named [name].
  Finder markOf(String name, IconData icon) => find.descendant(
    of: find.ancestor(of: find.text(name), matching: find.byType(Row)).first,
    matching: find.byIcon(icon),
  );

  group('each stage state', () {
    testWidgets('the running stage shows its rows, a finished one is one '
        'line, and one still to come is its name', (tester) async {
      await tester.pumpWidget(
        wrap(
          _Held(
            running: RouteKind.community,
            states: const {
              RouteKind.own: StageState.failed,
              RouteKind.community: StageState.running,
            },
            rows: [
              ...ownBlocked(),
              row(links[0], PathCheckState.blocked),
              row(links[1], PathCheckState.running),
            ],
          ),
        ),
      );

      expect(find.text('Stage 2 of 3'), findsOneWidget);
      // Finished: one line, and none of its eight rows.
      expect(find.text('Fortiva servers'), findsOneWidget);
      expect(find.text('8 paths tried, blocked here'), findsOneWidget);
      expect(find.text('Nuremberg, path 1'), findsNothing);
      expect(find.text('Helsinki, path 4'), findsNothing);
      expect(markOf('Fortiva servers', Icons.cancel_rounded), findsOneWidget);
      // Running: its rows, under it.
      expect(find.text('Community servers'), findsOneWidget);
      expect(
        markOf('Community servers', Icons.radio_button_checked),
        findsOneWidget,
      );
      expect(find.text('Community server 1, path 1'), findsOneWidget);
      expect(find.text('Community server 2, path 1'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Community server 1, path 1')).dy,
        greaterThan(tester.getTopLeft(find.text('Community servers')).dy),
      );
      // To come: its name only.
      expect(find.text('Backup network'), findsOneWidget);
      expect(markOf('Backup network', Icons.circle_outlined), findsOneWidget);
      // The one spinner is on the row being checked, not on a stage.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await done(tester);
    });

    testWidgets('a stage with an open path whose tunnel failed says none '
        'connected', (tester) async {
      await tester.pumpWidget(
        wrap(
          _Held(
            fixed: ConnectStage.failed,
            states: const {
              RouteKind.own: StageState.failed,
              RouteKind.community: StageState.skipped,
              RouteKind.backup: StageState.skipped,
            },
            rows: [
              row(nuremberg[0], PathCheckState.open, ms: 90),
              row(nuremberg[1], PathCheckState.blocked),
              // Never checked: not counted.
              row(nuremberg[2], PathCheckState.pending),
            ],
          ),
        ),
      );

      expect(find.text('2 paths tried, none connected'), findsOneWidget);
      expect(find.text('Skipped this time'), findsNWidgets(2));
      expect(find.textContaining('Stage'), findsNothing);
      await done(tester);
    });

    testWidgets('one path reads in the singular, and a stage with none '
        'reads did not connect', (tester) async {
      await tester.pumpWidget(
        wrap(
          _Held(
            fixed: ConnectStage.nothingOpen,
            states: const {
              RouteKind.own: StageState.failed,
              RouteKind.community: StageState.failed,
              RouteKind.backup: StageState.failed,
            },
            rows: [row(nuremberg[0], PathCheckState.blocked)],
          ),
        ),
      );

      expect(find.text('1 path tried, blocked here'), findsOneWidget);
      // The community stage ran but its rows are not on screen any more,
      // and the backup network has no rows.
      expect(find.text('Did not connect'), findsNWidgets(2));
      await done(tester);
    });

    testWidgets('the stage that connected says so', (tester) async {
      await tester.pumpWidget(
        wrap(
          _Held(
            fixed: ConnectStage.done,
            on: links[1],
            states: const {
              RouteKind.own: StageState.failed,
              RouteKind.community: StageState.connected,
              RouteKind.backup: StageState.skipped,
            },
            rows: ownBlocked(),
          ),
        ),
      );

      expect(find.text('Connected here'), findsOneWidget);
      expect(
        markOf('Community servers', Icons.check_circle_rounded),
        findsOneWidget,
      );
      await done(tester);
    });

    testWidgets('a running stage of many paths folds the blocked ones and '
        'the ones still to check, so the next stages stay on screen', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          _Held(
            running: RouteKind.own,
            states: const {RouteKind.own: StageState.running},
            rows: [
              for (final d in nuremberg) row(d, PathCheckState.blocked),
              row(helsinki[0], PathCheckState.blocked),
              row(helsinki[1], PathCheckState.running),
              row(helsinki[2], PathCheckState.pending),
              row(helsinki[3], PathCheckState.pending),
              row(door('Falkenstein', 0), PathCheckState.pending),
            ],
          ),
        ),
      );

      // Four lines: the blocked ones, the one being checked, one still to
      // check, and the rest of those.
      expect(find.text('5 paths tried, blocked here'), findsOneWidget);
      expect(find.text('Nuremberg, path 1'), findsNothing);
      expect(find.text('Helsinki, path 1'), findsNothing);
      expect(find.text('Helsinki, path 2'), findsOneWidget);
      expect(find.text('Helsinki, path 3'), findsOneWidget);
      expect(find.text('Helsinki, path 4'), findsNothing);
      expect(find.text('2 more paths to check'), findsOneWidget);
      expect(find.text('Community servers'), findsOneWidget);
      expect(find.text('Backup network'), findsOneWidget);
      // In that order, top to bottom.
      final ys = [
        '5 paths tried, blocked here',
        'Helsinki, path 2',
        'Helsinki, path 3',
        '2 more paths to check',
        'Community servers',
      ].map((t) => tester.getTopLeft(find.text(t)).dy).toList();
      expect(ys, orderedEquals([...ys]..sort()));
      await done(tester);
    });

    testWidgets('every path being checked shows, and a stage that fits '
        'shows its rows as they are', (tester) async {
      await tester.pumpWidget(
        wrap(
          _Held(
            running: RouteKind.community,
            states: const {
              RouteKind.own: StageState.failed,
              RouteKind.community: StageState.running,
            },
            rows: [
              for (final l in links) row(l, PathCheckState.running),
              row(community(3), PathCheckState.running),
              row(community(4), PathCheckState.open, ms: 80),
              row(community(5), PathCheckState.pending),
            ],
          ),
        ),
      );

      // Five rows being checked or found open: all shown, past the four
      // lines, and only the one still to check folds.
      expect(find.text('Community server 1, path 1'), findsOneWidget);
      expect(find.text('Community server 4, path 1'), findsOneWidget);
      expect(find.text('Community server 5, path 1'), findsOneWidget);
      expect(find.text('Community server 6, path 1'), findsNothing);
      expect(find.text('1 more path to check'), findsOneWidget);
      expect(find.textContaining('blocked here'), findsNothing);

      // Four rows fit: nothing folds.
      await tester.pumpWidget(
        wrap(
          _Held(
            running: RouteKind.own,
            states: const {RouteKind.own: StageState.running},
            rows: [
              for (final d in nuremberg.take(3)) row(d, PathCheckState.blocked),
              row(nuremberg[3], PathCheckState.running),
            ],
          ),
        ),
      );
      expect(find.text('Nuremberg, path 1'), findsOneWidget);
      expect(find.text('Nuremberg, path 4'), findsOneWidget);
      expect(find.textContaining('paths tried'), findsNothing);
      await done(tester);
    });

    testWidgets('where the backup network never runs, two stages', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          _Held(
            backup: false,
            running: RouteKind.own,
            states: const {RouteKind.own: StageState.running},
            rows: [row(nuremberg[0], PathCheckState.running)],
          ),
        ),
      );

      expect(find.text('Stage 1 of 2'), findsOneWidget);
      expect(find.text('Backup network'), findsNothing);
      await done(tester);
    });
  });

  group('the fast path', () {
    testWidgets('is on screen from its first second: the stage, and the '
        'server that worked last time, with no internet row', (tester) async {
      final hel = door('Helsinki', 0);
      await PathMemory().remember('wifi', hel.pathKey);
      final vpn = _HangingVpn();
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
          networkType: () async => 'wifi',
        ),
        networkKey: () async => 'wifi',
        carrier: () async => null,
      );

      final run = flow.connect([hel, door('Helsinki', 1)]);
      await tester.pumpWidget(wrap(flow));
      await tester.runAsync(() async {
        while (vpn.dials == 0) {
          await Future<void>.delayed(Duration.zero);
        }
      });
      await tester.pump();

      expect(flow.stage, ConnectStage.fastPath);
      expect(find.text('Stage 1 of 2'), findsOneWidget);
      expect(find.text('Fortiva servers'), findsOneWidget);
      expect(find.text('Last server that worked: Helsinki'), findsOneWidget);
      expect(find.text('Community servers'), findsOneWidget);
      // The fast path checks nothing, so it shows no internet row and no
      // row left from an earlier tap.
      expect(find.text('Checking your internet'), findsNothing);

      flow.cancel();
      await tester.pump(const Duration(seconds: 50));
      await run;
    });

    testWidgets('names the server that worked last only for its own dial: '
        'a door the checklist found is dialled with no such row', (
      tester,
    ) async {
      // The service listens to the platform's status as it starts. Real
      // time runs below, so that listen needs an answer.
      const status = EventChannel('com.vpn.fortivavpn/tunnel/status');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockStreamHandler(
        status,
        MockStreamHandler.inline(onListen: (_, _) {}),
      );
      addTearDown(() => messenger.setMockStreamHandler(status, null));
      final hel = door('Helsinki', 0);
      final nue = door('Nuremberg', 0);
      await PathMemory().remember('wifi', hel.pathKey);
      final vpn = _HangingVpn();
      final flow = ConnectFlow(
        vpn: vpn,
        memory: PathMemory(),
        finder: PathFinder(
          probe: (p) async => p.pathKey == nue.pathKey ? 120 : -1,
          internet: () async => true,
        ),
        reporter: VpnEventReporter(
          send: (_, _, _) async {},
          sendProbes: (_, _, _) async {},
          deviceId: () async => 'DEV-1',
          appVersion: () async => '2.2.0',
          platform: 'android',
          networkType: () async => 'wifi',
        ),
        networkKey: () async => 'wifi',
        carrier: () async => null,
      );
      await tester.pumpWidget(wrap(flow));

      late Future<void> run;
      await tester.runAsync(() async {
        run = flow.connect([hel, nue]);
        while (vpn.dials == 0) {
          await Future<void>.delayed(Duration.zero);
        }
      });
      await tester.pump();
      expect(flow.stage, ConnectStage.fastPath);
      expect(flow.fastPathDoor, hel);
      expect(find.text('Last server that worked: Helsinki'), findsOneWidget);

      // The remembered door fails, the checklist finds Nuremberg open, and
      // the flow dials it.
      await tester.runAsync(() async {
        vpn.fail();
        while (vpn.dials < 2 || flow.stage != ConnectStage.connecting) {
          await Future<void>.delayed(const Duration(milliseconds: 2));
        }
      });
      await tester.pump();
      expect(flow.chosen, nue);
      expect(flow.fastPathDoor, isNull);
      expect(find.textContaining('Last server that worked'), findsNothing);
      expect(find.text('Connecting through Nuremberg'), findsOneWidget);

      await tester.runAsync(() async {
        flow.cancel();
        await run;
      });
      await done(tester);
    });
  });

  testWidgets('the fast path of a new tap shows none of the last tap\'s '
      'rows', (tester) async {
    await tester.pumpWidget(
      wrap(
        _Held(
          fixed: ConnectStage.fastPath,
          running: RouteKind.own,
          states: const {RouteKind.own: StageState.running},
          // The finder still holds the last tap's rows.
          rows: ownBlocked(),
          fresh: false,
          fast: helsinki[0],
        ),
      ),
    );

    expect(find.text('Last server that worked: Helsinki'), findsOneWidget);
    expect(find.text('Nuremberg, path 1'), findsNothing);
    expect(find.textContaining('blocked here'), findsNothing);
    expect(find.text('Checking your internet'), findsNothing);
    await done(tester);
  });

  group('in Persian', () {
    testWidgets('reads right to left, with Persian digits', (tester) async {
      await tester.pumpWidget(
        wrap(
          _Held(
            running: RouteKind.community,
            states: const {
              RouteKind.own: StageState.failed,
              RouteKind.community: StageState.running,
            },
            rows: [...ownBlocked(), row(links[0], PathCheckState.running)],
          ),
          locale: 'fa',
        ),
      );

      expect(find.text('مرحله ۲ از ۳'), findsOneWidget);
      expect(find.text('سرورهای فورتیوا'), findsOneWidget);
      expect(find.text('۸ مسیر امتحان شد، اینجا مسدود است'), findsOneWidget);
      expect(find.text('سرورهای عمومی'), findsOneWidget);
      expect(find.text('شبکه جایگزین'), findsOneWidget);
      // The mark sits at the start of the line, on the right.
      final mark = markOf('سرورهای فورتیوا', Icons.cancel_rounded);
      expect(
        tester.getCenter(mark).dx,
        greaterThan(tester.getCenter(find.text('سرورهای فورتیوا')).dx),
      );
      // The running stage's rows are set in from the right.
      final rowLabel = find.text('سرور عمومی ۱، مسیر ۱');
      expect(
        tester.getTopRight(rowLabel).dx,
        lessThan(tester.getTopRight(find.text('سرورهای عمومی')).dx),
      );
      await done(tester);
    });

    testWidgets('a long running stage folds in Persian digits', (tester) async {
      await tester.pumpWidget(
        wrap(
          _Held(
            running: RouteKind.own,
            states: const {RouteKind.own: StageState.running},
            rows: [
              for (final d in nuremberg) row(d, PathCheckState.blocked),
              row(helsinki[0], PathCheckState.running),
              for (final d in helsinki.skip(1)) row(d, PathCheckState.pending),
            ],
          ),
          locale: 'fa',
        ),
      );

      expect(find.text('۴ مسیر امتحان شد، اینجا مسدود است'), findsOneWidget);
      expect(find.text('۲ مسیر دیگر در نوبت بررسی'), findsOneWidget);
      await done(tester);
    });
  });

  group('reduced motion', () {
    testWidgets('nothing turns, and rows are simply there', (tester) async {
      await tester.pumpWidget(
        wrap(
          _Held(
            running: RouteKind.own,
            states: const {RouteKind.own: StageState.running},
            rows: [
              row(nuremberg[0], PathCheckState.blocked),
              row(nuremberg[1], PathCheckState.running),
            ],
          ),
          reduce: true,
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byIcon(Icons.pending_outlined), findsOneWidget);
      final fade = tester.widget<FadeTransition>(
        find
            .ancestor(
              of: find.text('Nuremberg, path 2'),
              matching: find.byType(FadeTransition),
            )
            .first,
      );
      expect(fade.opacity.value, 1);
      await done(tester);
    });

    testWidgets('with motion, the row being checked has its spinner', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          _Held(
            running: RouteKind.own,
            states: const {RouteKind.own: StageState.running},
            rows: [row(nuremberg[1], PathCheckState.running)],
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byIcon(Icons.pending_outlined), findsNothing);
      await done(tester);
    });
  });

  group('waiting to try again', () {
    testWidgets('says which stage the next try starts with, and counts '
        'down to it', (tester) async {
      var now = DateTime(2026, 10, 23, 12);
      await tester.pumpWidget(
        wrap(
          _Held(
            fixed: ConnectStage.waiting,
            states: const {
              RouteKind.own: StageState.failed,
              RouteKind.community: StageState.failed,
              RouteKind.backup: StageState.skipped,
            },
            rows: ownBlocked(),
            next: RouteKind.own,
            at: now.add(const Duration(seconds: 30)),
          ),
          clock: () => now,
        ),
      );

      expect(
        find.text('Next try starts with Fortiva servers in 0:30'),
        findsOneWidget,
      );

      now = now.add(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(
        find.text('Next try starts with Fortiva servers in 0:29'),
        findsOneWidget,
      );
      expect(find.textContaining('Stage'), findsNothing);

      await done(tester);
    });

    testWidgets('in Persian digits', (tester) async {
      final now = DateTime(2026, 10, 23, 12);
      await tester.pumpWidget(
        wrap(
          _Held(
            fixed: ConnectStage.waiting,
            states: const {RouteKind.own: StageState.failed},
            next: RouteKind.own,
            at: now.add(const Duration(seconds: 75)),
          ),
          locale: 'fa',
          clock: () => now,
        ),
      );

      expect(
        find.text('تلاش بعدی ۱:۱۵ دیگر با سرورهای فورتیوا شروع می‌شود'),
        findsOneWidget,
      );
      await done(tester);
    });

    testWidgets('once the wait is over, says the next try starts now, with '
        'no countdown at zero', (tester) async {
      final now = DateTime(2026, 10, 23, 12);
      await tester.pumpWidget(
        wrap(
          _Held(
            fixed: ConnectStage.waiting,
            states: const {RouteKind.own: StageState.failed},
            next: RouteKind.own,
            starting: true,
          ),
          clock: () => now,
        ),
      );

      expect(
        find.text('Starting the next try with Fortiva servers'),
        findsOneWidget,
      );
      expect(find.textContaining('0:00'), findsNothing);
      expect(find.textContaining('Next try starts'), findsNothing);
      await done(tester);
    });

    testWidgets('the next try starting, in Persian', (tester) async {
      await tester.pumpWidget(
        wrap(
          _Held(
            fixed: ConnectStage.waiting,
            states: const {RouteKind.community: StageState.failed},
            next: RouteKind.community,
            starting: true,
          ),
          locale: 'fa',
        ),
      );

      const fa = 'تلاش بعدی همین حالا با سرورهای عمومی شروع می‌شود';
      expect(find.text(fa), findsOneWidget);
      expect(
        Directionality.of(tester.element(find.text(fa))),
        TextDirection.rtl,
      );
      await done(tester);
    });

    test('the countdown reads minutes and seconds, rounded up', () {
      expect(countdownText(Duration.zero), '0:00');
      expect(countdownText(const Duration(seconds: -3)), '0:00');
      expect(countdownText(const Duration(milliseconds: 29001)), '0:30');
      expect(countdownText(const Duration(seconds: 61)), '1:01');
      expect(countdownText(const Duration(minutes: 10)), '10:00');
      expect(countdownText(const Duration(hours: 1, seconds: 5)), '1:00:05');
    });
  });

  group('while the tap gets this device\'s servers', () {
    // A phone with none of its own yet waits up to a few seconds for them
    // before its first try (connectFromButton). Found 2026-10-24 in review:
    // the screen showed only "Connecting" then.
    testWidgets('the first stage runs and says so, and none of the last '
        'try shows', (tester) async {
      await tester.pumpWidget(
        wrap(
          // The last try's ending, which this view leaves out.
          _Held(
            fixed: ConnectStage.idle,
            states: const {
              RouteKind.own: StageState.failed,
              RouteKind.community: StageState.failed,
            },
            rows: ownBlocked(),
          ),
          gettingServers: true,
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Stage 1 of 3'), findsOneWidget);
      expect(find.text('Getting your servers'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('getting servers')),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );
      expect(
        markOf('Fortiva servers', Icons.radio_button_checked),
        findsOneWidget,
      );
      expect(
        markOf('Community servers', Icons.circle_outlined),
        findsOneWidget,
      );
      expect(markOf('Backup network', Icons.circle_outlined), findsOneWidget);
      expect(find.textContaining('paths tried'), findsNothing);
      expect(find.textContaining('Nuremberg'), findsNothing);
      expect(find.text('Checking your internet'), findsNothing);
      await done(tester);
    });

    testWidgets('where the backup network never runs, two stages', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          _Held(fixed: ConnectStage.idle, backup: false),
          gettingServers: true,
        ),
      );
      expect(find.text('Stage 1 of 2'), findsOneWidget);
      expect(find.text('Backup network'), findsNothing);
      await done(tester);
    });

    testWidgets('in Persian, right to left with Persian digits', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          _Held(fixed: ConnectStage.idle),
          locale: 'fa',
          gettingServers: true,
        ),
      );
      expect(find.text('مرحله ۱ از ۳'), findsOneWidget);
      const row = 'در حال گرفتن سرورهای شما';
      expect(find.text(row), findsOneWidget);
      expect(
        Directionality.of(tester.element(find.text(row))),
        TextDirection.rtl,
      );
      await done(tester);
    });

    testWidgets('under reduced motion, its row has a still mark', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          _Held(fixed: ConnectStage.idle),
          reduce: true,
          gettingServers: true,
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('getting servers')),
          matching: find.byIcon(Icons.pending_outlined),
        ),
        findsOneWidget,
      );
      await done(tester);
    });
  });

  testWidgets('a stage is never green before the tunnel is verified', (
    tester,
  ) async {
    // Connecting through a door that was open on its check: the stage
    // runs, and only the check's own row is ticked.
    await tester.pumpWidget(
      wrap(
        _Held(
          fixed: ConnectStage.connecting,
          on: nuremberg[0],
          running: RouteKind.own,
          states: const {RouteKind.own: StageState.running},
          rows: [row(nuremberg[0], PathCheckState.open, ms: 80)],
        ),
        clock: () => DateTime(2026),
      ),
    );

    expect(find.text('Connecting through Nuremberg'), findsOneWidget);
    final ticks = tester.widgetList<Icon>(
      find.byIcon(Icons.check_circle_rounded),
    );
    // The internet row and the open check, and no stage.
    expect(ticks, hasLength(2));
    expect(find.text('Connected here'), findsNothing);
    expect(
      tester
          .widget<Icon>(markOf('Fortiva servers', Icons.radio_button_checked))
          .color,
      AppDesign.steelLight,
    );
    await done(tester);
  });
}

/// A tunnel that starts and never settles: the fast path's dial stays in
/// flight until the test stops it.
class _HangingVpn extends VpnService {
  _HangingVpn() : super(events: VpnEventReporter(send: (_, _, _) async {}));

  int dials = 0;
  VpnStatus _fake = VpnStatus.disconnected;

  @override
  VpnStatus get status => _fake;

  @override
  bool get isConnecting => _fake == VpnStatus.connecting;

  @override
  Future<void> connect(
    Server server, {
    String? attemptId,
    List<Server> standby = const [],
    LinkSource? source,
  }) async {
    dials++;
    _fake = VpnStatus.connecting;
    notifyListeners();
  }

  @override
  Future<void> disconnect() async {
    _fake = VpnStatus.disconnected;
    notifyListeners();
  }

  /// The dial in flight fails.
  void fail() {
    _fake = VpnStatus.error;
    notifyListeners();
  }

  @override
  void clearError() {
    if (_fake == VpnStatus.error) _fake = VpnStatus.disconnected;
    notifyListeners();
  }
}
