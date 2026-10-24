import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/core/design_system.dart';
import 'package:fortiva_vpn/l10n/generated/app_localizations.dart';
import 'package:fortiva_vpn/widgets/elapsed_time.dart';

/// The connection clock used to freeze at whatever it read when the tunnel
/// came up, and only jump forward when something unrelated rebuilt the
/// tree. On a device that looked like a timer that ran only while the app
/// was in the background.
///
/// The cause was that VpnService notifies on status changes, never on a
/// clock, so these pin that the widget advances on its own.
void main() {
  group('ElapsedTime.format', () {
    test('reads m:ss below an hour', () {
      expect(ElapsedTime.format(const Duration(seconds: 7)), '00:07');
      expect(
        ElapsedTime.format(const Duration(minutes: 9, seconds: 5)),
        '09:05',
      );
      expect(
        ElapsedTime.format(const Duration(minutes: 59, seconds: 59)),
        '59:59',
      );
    });

    test('grows to h:mm:ss at the hour', () {
      expect(ElapsedTime.format(const Duration(hours: 1)), '1:00:00');
      expect(
        ElapsedTime.format(const Duration(hours: 12, minutes: 3, seconds: 4)),
        '12:03:04',
      );
    });

    test('a backwards wall clock never renders a negative time', () {
      expect(ElapsedTime.format(const Duration(seconds: -30)), '00:00');
    });
  });

  group('ElapsedTime widget', () {
    testWidgets('advances without anything else rebuilding it', (tester) async {
      final start = DateTime(2026, 1, 1, 12);
      var now = start;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ElapsedTime(startTime: start, clock: () => now),
          ),
        ),
      );

      expect(find.text('00:00'), findsOneWidget);

      // Nothing here calls setState on the parent and no provider fires,
      // so only the widget's own ticker can move this on.
      now = start.add(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('00:01'), findsOneWidget);

      now = start.add(const Duration(seconds: 2));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('00:02'), findsOneWidget);
    });

    testWidgets('catches up after the app was suspended', (tester) async {
      // iOS stops timers in the background. The widget measures against the
      // wall clock rather than counting ticks, so one tick after resuming
      // shows the true elapsed time instead of the time it was awake.
      final start = DateTime(2026, 1, 1, 12);
      var now = start;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ElapsedTime(startTime: start, clock: () => now),
          ),
        ),
      );
      expect(find.text('00:00'), findsOneWidget);

      now = start.add(const Duration(minutes: 8, seconds: 20));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('08:20'), findsOneWidget);
    });

    testWidgets('waits while another screen covers it, and is right again '
        'on return', (tester) async {
      // Under another screen nobody sees the clock, so it draws no frame a
      // second there. It reads the wall clock, so coming back shows the
      // true time at once.
      final start = DateTime(2026, 1, 1, 12);
      var now = start;
      Widget clock({required bool shown}) => MaterialApp(
        home: Scaffold(
          body: TickerMode(
            enabled: shown,
            child: ElapsedTime(startTime: start, clock: () => now),
          ),
        ),
      );

      await tester.pumpWidget(clock(shown: false));
      await tester.pump();
      now = start.add(const Duration(seconds: 3));
      await tester.pump(const Duration(seconds: 3));
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(find.text('00:00'), findsOneWidget);

      await tester.pumpWidget(clock(shown: true));
      expect(find.text('00:03'), findsOneWidget);
    });

    testWidgets('stops ticking once it leaves the tree', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ElapsedTime(startTime: DateTime.now())),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      // A timer left running past dispose fails the test binding, which is
      // what makes this worth asserting rather than assuming.
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: SizedBox.shrink())),
      );
      await tester.pump(const Duration(seconds: 2));

      expect(find.textContaining(':'), findsNothing);
    });

    testWidgets('a label weight in the protected color, with tabular figures '
        'in Latin script only', (tester) async {
      final start = DateTime(2026, 1, 1, 12);
      Widget clock(String language) => MaterialApp(
        localizationsDelegates: S.localizationsDelegates,
        supportedLocales: S.supportedLocales,
        locale: Locale(language),
        home: Scaffold(
          body: ElapsedTime(
            startTime: start,
            clock: () => start.add(const Duration(seconds: 12)),
          ),
        ),
      );

      await tester.pumpWidget(clock('en'));
      var style = tester.widget<Text>(find.text('00:12')).style!;
      expect(style.fontSize, 15);
      expect(style.fontWeight, FontWeight.w600);
      expect(style.color, AppDesign.protected);
      expect(style.fontFeatures, [const FontFeature.tabularFigures()]);

      // Vazirmatn's tabular Persian digits sit in full-width cells, so the
      // zeros left holes in the line.
      AppDesign.activeLocale = const Locale('fa');
      addTearDown(() => AppDesign.activeLocale = const Locale('en'));
      await tester.pumpWidget(clock('fa'));
      style = tester.widget<Text>(find.text('۰۰:۱۲')).style!;
      expect(style.fontWeight, FontWeight.w600);
      expect(style.fontFeatures, isEmpty);
    });
  });
}
