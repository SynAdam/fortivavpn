import 'dart:async';

import 'package:flutter/material.dart';
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

import 'helpers/app_theme.dart';

/// The checklist is what the user watches while a diagnosis runs. It has
/// to name doors in words a user can follow, number them per server, and
/// show each row's outcome as it lands.
Server door(String city, String door) => Server(
  id: 'dedicated-$city:443',
  name: city,
  country: '',
  city: city,
  connectionUri: 'vless://u@$city:443?type=tcp#$city',
  flagEmoji: '🌍',
  isDedicated: true,
  door: door,
  doorLabel: door,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Widget wrap(ConnectFlow flow, {String locale = 'en'}) => MaterialApp(
    localizationsDelegates: S.localizationsDelegates,
    supportedLocales: S.supportedLocales,
    locale: Locale(locale),
    // The home screen watches the flow through Provider; here the
    // builder plays that part so rows repaint as checks land.
    home: Scaffold(
      body: ListenableBuilder(
        listenable: flow,
        builder: (_, _) => PathChecklist(flow: flow),
      ),
    ),
  );

  ConnectFlow flowWith(PathFinder finder) => ConnectFlow(
    vpn: VpnService(events: VpnEventReporter(send: (_, _, _) async {})),
    memory: PathMemory(),
    finder: finder,
    reporter: VpnEventReporter(
      send: (_, _, _) async {},
      sendProbes: (_, _, _) async {},
      deviceId: () async => 'DEV-1',
      appVersion: () async => '1.5.0',
      platform: 'android',
      networkType: () async => 'mobile',
    ),
    networkKey: () async => 'wifi',
    carrier: () async => null,
  );

  testWidgets('rows are numbered per server and fill in as checks land', (
    tester,
  ) async {
    final hel1 = door('Helsinki', 'tcp-reality');
    final hel2 = door('Helsinki', 'xhttp-reality');
    final fsn1 = door('Falkenstein', 'tcp-reality');
    final gate = Completer<int>();
    final flow = flowWith(
      PathFinder(
        probe: (p) => p == hel1 ? Future.value(-1) : gate.future,
        internet: () async => true,
      ),
    );

    final run = flow.connect([hel1, hel2, fsn1], preferred: hel1);
    await tester.pumpWidget(wrap(flow));
    await tester.pump();
    await tester.pump();

    expect(find.text('Checking your internet'), findsOneWidget);
    expect(find.text('Helsinki, path 1'), findsOneWidget);
    expect(find.text('Helsinki, path 2'), findsOneWidget);
    expect(find.text('Falkenstein, path 1'), findsOneWidget);
    expect(find.text('blocked'), findsOneWidget);

    gate.complete(210);
    await tester.pump();
    await tester.pump();
    expect(find.text('open · 210 ms'), findsOneWidget);
    expect(find.text('Connecting through Helsinki'), findsOneWidget);

    flow.cancel();
    // A check in flight ends at its own timeout, and the service's connect
    // watchdog and start-up poll have to fire too; under fake time every
    // one of those needs a pump before the flow can finish.
    await tester.pump(const Duration(seconds: 30));
    await run;
  });

  // The internet row shows the control fetch as it stands. Until 2026-10-12
  // it read the stage and showed a tick whenever the checklist was on
  // screen. In an emulator test that day it showed one while the fetch had
  // not answered, or had failed, above rows that all said "blocked".
  group('the internet row', () {
    Finder inInternetRow(Finder what) => find.descendant(
      of: find
          .ancestor(
            of: find.text('Checking your internet'),
            matching: find.byType(Row),
          )
          .first,
      matching: what,
    );
    final running = find.byType(CircularProgressIndicator);
    final ticked = find.byIcon(Icons.check_circle_rounded);
    final crossed = find.byIcon(Icons.cancel_rounded);

    testWidgets('runs while the fetch runs, and shows a cross when it fails', (
      tester,
    ) async {
      final hel1 = door('Helsinki', 'tcp-reality');
      final hel2 = door('Helsinki', 'xhttp-reality');
      final fetch = Completer<bool>();
      final flow = flowWith(
        PathFinder(probe: (p) async => -1, internet: () => fetch.future),
      );

      final run = flow.connect([hel1, hel2], preferred: hel1);
      await tester.pumpWidget(wrap(flow));
      await tester.pump();
      await tester.pump();

      // The door rows stay as they are.
      expect(find.text('blocked'), findsNWidgets(2));
      expect(inInternetRow(running), findsOneWidget);
      expect(inInternetRow(ticked), findsNothing);
      expect(inInternetRow(crossed), findsNothing);

      fetch.complete(false);
      await tester.pump();
      await tester.pump();
      expect(inInternetRow(crossed), findsOneWidget);
      expect(inInternetRow(running), findsNothing);
      expect(inInternetRow(ticked), findsNothing);

      await tester.pump(const Duration(seconds: 30));
      await run;
      expect(flow.stage, ConnectStage.noInternet);
    });

    testWidgets('says the way abroad is cut when a site inside the country '
        'answered', (tester) async {
      final hel1 = door('Helsinki', 'tcp-reality');
      final flow = flowWith(
        PathFinder(
          probe: (p) async => -1,
          internet: () async => false,
          home: () async => true,
        ),
      );

      final run = flow.connect([hel1], preferred: hel1);
      await tester.pumpWidget(wrap(flow));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(seconds: 30));
      await run;

      expect(flow.stage, ConnectStage.cutOff);
      expect(find.text('Checking your internet'), findsNothing);
      expect(
        find.text('International internet is cut on this network'),
        findsOneWidget,
      );
    });

    testWidgets('shows a tick once the fetch passes, while doors are still '
        'checked', (tester) async {
      final hel1 = door('Helsinki', 'tcp-reality');
      final fetch = Completer<bool>();
      final flow = flowWith(
        PathFinder(
          probe: (p) => Completer<int>().future,
          internet: () => fetch.future,
        ),
      );

      final run = flow.connect([hel1], preferred: hel1);
      await tester.pumpWidget(wrap(flow));
      await tester.pump();
      await tester.pump();
      expect(inInternetRow(running), findsOneWidget);

      fetch.complete(true);
      await tester.pump();
      await tester.pump();
      expect(inInternetRow(ticked), findsOneWidget);
      expect(inInternetRow(running), findsNothing);
      expect(flow.isDiagnosing, isTrue);

      flow.cancel();
      // A check in flight ends at its own timeout, and the service's
      // connect watchdog and start-up poll have to fire too; under fake
      // time every one of those needs a pump before the flow can finish.
      await tester.pump(const Duration(seconds: 30));
      await run;
    });

    testWidgets('a door found open shows a tick before the fetch answers, '
        'and a failed fetch after it leaves the tick', (tester) async {
      final hel1 = door('Helsinki', 'tcp-reality');
      final fetch = Completer<bool>();
      final flow = flowWith(
        PathFinder(probe: (p) async => 210, internet: () => fetch.future),
      );

      final run = flow.connect([hel1], preferred: hel1);
      await tester.pumpWidget(wrap(flow));
      await tester.pump();
      await tester.pump();
      expect(find.text('open · 210 ms'), findsOneWidget);
      expect(inInternetRow(ticked), findsOneWidget);

      fetch.complete(false);
      await tester.pump();
      await tester.pump();
      expect(inInternetRow(ticked), findsOneWidget);
      expect(inInternetRow(crossed), findsNothing);

      flow.cancel();
      await tester.pump(const Duration(seconds: 30));
      await run;
    });
  });

  testWidgets('doors with their own ids in one city are numbered 1, 2, 3', (
    tester,
  ) async {
    // What the backend hands a phone: every door has its own endpoint and
    // so its own id, and two servers can sit in one city. On 2026-10-05
    // all three rows read "Nuremberg, path 1".
    Server nuremberg(String endpoint, String door, int serverId) => Server(
      id: 'dedicated-$endpoint',
      name: 'Nuremberg',
      country: 'Germany',
      city: 'Nuremberg',
      connectionUri: 'vless://u@$endpoint?type=tcp#DE-Nuremberg',
      flagEmoji: '🇩🇪',
      isDedicated: true,
      door: door,
      doorLabel: door,
      serverId: serverId,
    );
    final direct = nuremberg('198.51.100.210:8443', 'xhttp-reality', 10);
    final cdn10 = nuremberg('media.example:443', 'ws-tls', 10);
    final cdn11 = nuremberg('cdn.example:443', 'ws-tls', 11);
    final flow = flowWith(
      PathFinder(
        probe: (p) => Completer<int>().future,
        internet: () async => true,
      ),
    );

    final run = flow.connect([direct, cdn10, cdn11], preferred: direct);
    await tester.pumpWidget(wrap(flow, locale: 'fa'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Nuremberg، مسیر ۱'), findsOneWidget);
    expect(find.text('Nuremberg، مسیر ۲'), findsOneWidget);
    expect(find.text('Nuremberg، مسیر ۳'), findsOneWidget);

    flow.cancel();
    await tester.pump(const Duration(seconds: 30));
    await run;
  });

  testWidgets('reads in Persian', (tester) async {
    final hel1 = door('Helsinki', 'tcp-reality');
    final flow = flowWith(
      PathFinder(
        probe: (p) => Completer<int>().future,
        internet: () async => true,
      ),
    );
    final run = flow.connect([hel1], preferred: hel1);
    await tester.pumpWidget(wrap(flow, locale: 'fa'));
    await tester.pump();
    await tester.pump();

    expect(find.text('بررسی اینترنت گوشی'), findsOneWidget);
    expect(find.text('Helsinki، مسیر ۱'), findsOneWidget);

    flow.cancel();
    // A check in flight ends at its own timeout, and the service's connect
    // watchdog and start-up poll have to fire too; under fake time every
    // one of those needs a pump before the flow can finish.
    await tester.pump(const Duration(seconds: 30));
    await run;
  });

  // The checklist in the app's own theme: rows that ease in as they land,
  // a small steel spinner on the row being worked on, and marks in the
  // state colors.
  group('the look', () {
    Widget themed(ConnectFlow flow, {bool reduce = false}) => MaterialApp(
      theme: appThemeFor(null),
      localizationsDelegates: S.localizationsDelegates,
      supportedLocales: S.supportedLocales,
      locale: const Locale('en'),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduce),
        child: child!,
      ),
      home: Scaffold(
        body: ListenableBuilder(
          listenable: flow,
          builder: (_, _) => PathChecklist(flow: flow),
        ),
      ),
    );

    double opacityOf(WidgetTester tester, String text) => tester
        .widget<FadeTransition>(
          find
              .ancestor(
                of: find.text(text),
                matching: find.byType(FadeTransition),
              )
              .first,
        )
        .opacity
        .value;

    Future<ConnectFlow> start(
      WidgetTester tester, {
      bool reduce = false,
      required List<Future<void>> runs,
    }) async {
      final hel1 = door('Helsinki', 'tcp-reality');
      final flow = flowWith(
        PathFinder(
          probe: (p) => Completer<int>().future,
          internet: () async => true,
        ),
      );
      runs.add(flow.connect([hel1], preferred: hel1));
      await tester.pumpWidget(themed(flow, reduce: reduce));
      await tester.pump();
      await tester.pump();
      return flow;
    }

    Future<void> finish(
      WidgetTester tester,
      ConnectFlow flow,
      List<Future<void>> runs,
    ) async {
      flow.cancel();
      await tester.pump(const Duration(seconds: 30));
      await Future.wait(runs);
    }

    testWidgets('a new row fades in and rises into place, then is still', (
      tester,
    ) async {
      final runs = <Future<void>>[];
      final flow = await start(tester, runs: runs);
      const row = 'Helsinki, path 1';
      expect(opacityOf(tester, row), lessThan(1));
      final entering = tester.getTopLeft(find.text(row)).dy;

      await tester.pump(AppMotion.medium);
      await tester.pump(const Duration(milliseconds: 50));
      expect(opacityOf(tester, row), 1);
      final settled = tester.getTopLeft(find.text(row)).dy;
      expect(entering, greaterThan(settled));
      expect(entering - settled, lessThanOrEqualTo(6));

      await finish(tester, flow, runs);
    });

    testWidgets('rows are simply there under reduce motion', (tester) async {
      final runs = <Future<void>>[];
      final flow = await start(tester, reduce: true, runs: runs);
      expect(opacityOf(tester, 'Helsinki, path 1'), 1);
      expect(opacityOf(tester, 'Checking your internet'), 1);
      await finish(tester, flow, runs);
    });

    testWidgets('the row being checked has a small steel spinner, and the '
        'marks are 16dp in the state colors', (tester) async {
      final runs = <Future<void>>[];
      final flow = await start(tester, runs: runs);

      final spinner = find.byType(CircularProgressIndicator);
      expect(spinner, findsOneWidget);
      expect(
        tester.widget<CircularProgressIndicator>(spinner).color,
        AppDesign.steelLight,
      );
      expect(tester.getSize(spinner), const Size.square(14));

      final tick = find.byIcon(Icons.check_circle_rounded);
      expect(tester.widget<Icon>(tick).size, 16);
      expect(tester.widget<Icon>(tick).color, AppDesign.protected);

      // The door still being checked reads brighter than the check that
      // is done.
      Color? colorOf(String text) =>
          tester.widget<Text>(find.text(text)).style?.color;
      expect(colorOf('Helsinki, path 1'), AppDesign.textPrimary);
      expect(colorOf('Checking your internet'), AppDesign.textSecondary);

      await finish(tester, flow, runs);
    });
  });
}
