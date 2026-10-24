import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/core/design_system.dart';
import 'package:fortiva_vpn/data/models/connection_session.dart';
import 'package:fortiva_vpn/l10n/generated/app_localizations.dart';
import 'package:fortiva_vpn/screens/analytics_screen.dart';
import 'package:fortiva_vpn/screens/dns_settings_screen.dart';
import 'package:fortiva_vpn/screens/ip_info_screen.dart';
import 'package:fortiva_vpn/screens/speed_test_screen.dart';
import 'package:fortiva_vpn/services/session_tracker.dart';
import 'package:fortiva_vpn/services/speed_test_service.dart';
import 'package:fortiva_vpn/services/vpn_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/app_theme.dart';

/// The speed test, Check my IP, History and DNS screens.
///
/// They showed hard-coded English ("RUN DIAGNOSTICS", "TUNNEL ACTIVE",
/// "Avg Duration", "Mon") on every phone. These pin that every word now
/// comes from the app's language, that the numbers use the language's
/// digits, that Persian draws in Vazirmatn, and that the screens draw no
/// frames at rest. What the screens measure and save is unchanged.
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

  group('speed test', () {
    testWidgets('before a run: sentence case words and no console text', (
      tester,
    ) async {
      await _pump(tester, const SpeedTestScreen(), speed: _FakeSpeed());

      expect(find.text('Start test'), findsOneWidget);
      expect(
        find.text('See how fast your connection is right now.'),
        findsOneWidget,
      );
      expect(find.text('Download'), findsOneWidget);
      expect(find.text('Upload'), findsOneWidget);
      expect(find.text('Ping'), findsOneWidget);
      expect(find.text('Testing direct connection'), findsOneWidget);
      for (final old in ['RUN DIAGNOSTICS', 'THROUGHPUT', 'IDLE']) {
        expect(find.text(old), findsNothing, reason: old);
      }
      expect(find.byType(FilledButton), findsOneWidget);
      expect(_gauge(tester).fraction, 0);
      // The tiles show their labels only: a muted "0 ms" read as a
      // perfect measurement. Their value lines are kept but hidden, so the
      // tiles do not grow when the result arrives.
      expect(find.text('ms'), findsNothing);
      expect(find.text('Mbps'), findsOneWidget, reason: 'the dial only');
      final hidden = tester
          .widgetList<Visibility>(find.byType(Visibility))
          .where((v) => !v.visible && v.maintainSize);
      expect(hidden, hasLength(2));
      // A still bar in each tile says nothing is measured yet, so the
      // tiles do not look empty.
      expect(_placeholder, findsNWidgets(2));
      // The dial at rest is a plain zero, not "0.0".
      expect(find.text('0.0'), findsNothing);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('the button sits at the bottom, outside the readings', (
      tester,
    ) async {
      await _pump(tester, const SpeedTestScreen(), speed: _FakeSpeed());
      final button = find.byType(FilledButton);
      expect(
        find.ancestor(of: button, matching: find.byType(Scrollable)),
        findsNothing,
      );
      expect(tester.getRect(button).bottom, moreOrLessEquals(915 - 16));
    });

    testWidgets('a result fills the dial and the tiles', (tester) async {
      final speed = _FakeSpeed()
        ..result = SpeedTestResult(
          downloadMbps: 42.5,
          uploadMbps: 8.34,
          pingMs: 87,
          timestamp: DateTime(2026, 10, 17),
        );
      await _pump(tester, const SpeedTestScreen(), speed: speed);

      expect(find.text('42.5'), findsOneWidget);
      expect(find.text('8.3'), findsOneWidget);
      expect(find.text('87'), findsOneWidget);
      expect(find.text('ms'), findsOneWidget);
      expect(
        tester
            .widgetList<Visibility>(find.byType(Visibility))
            .where((v) => !v.visible),
        isEmpty,
      );
      expect(_placeholder, findsNothing);
      expect(find.text('Test finished'), findsOneWidget);
      expect(find.text('Test again'), findsOneWidget);
      expect(_gauge(tester).fraction, greaterThan(0));
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('a run names its step and keeps the button focusable', (
      tester,
    ) async {
      final speed = _FakeSpeed()
        ..running = true
        ..progressValue = 0.5
        ..phaseText = 'Testing download speed...';
      await _pump(tester, const SpeedTestScreen(), speed: speed, settle: false);

      expect(find.text('Measuring download speed'), findsOneWidget);
      expect(find.text('Testing'), findsOneWidget);
      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNotNull);
      await tester.tap(find.byType(FilledButton));
      await tester.pump();
      expect(speed.runs, 0, reason: 'a tap during a run starts nothing');
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a run that ended with no result says so', (tester) async {
      final speed = _FakeSpeed()..phaseText = 'Error';
      await _pump(tester, const SpeedTestScreen(), speed: speed);
      expect(
        find.text(
          'The test could not finish. Check your internet and try again.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('the app bar follows the readings under it', (tester) async {
      await _pump(tester, const SpeedTestScreen(), speed: _FakeSpeed());
      expect(
        tester.widget<AppBar>(find.byType(AppBar)).backgroundColor,
        same(AppDesign.appBarColor),
      );
    });

    testWidgets('Start runs the test', (tester) async {
      final speed = _FakeSpeed();
      await _pump(tester, const SpeedTestScreen(), speed: speed);
      await tester.tap(find.text('Start test'));
      await tester.pump();
      expect(speed.runs, 1);
    });

    testWidgets('Persian: own words, own digits, Vazirmatn', (tester) async {
      final speed = _FakeSpeed()
        ..result = SpeedTestResult(
          downloadMbps: 12.5,
          uploadMbps: 3,
          pingMs: 140,
          timestamp: DateTime(2026, 10, 17),
        );
      await _pump(
        tester,
        const SpeedTestScreen(),
        speed: speed,
        locale: const Locale('fa'),
      );

      // Persian writes the decimal point as the momayyez.
      expect(find.text('۱۲٫۵'), findsOneWidget);
      expect(find.text('۳٫۰'), findsOneWidget);
      expect(find.text('۱۴۰'), findsOneWidget);
      expect(find.text('تست دوباره'), findsOneWidget);
      expect(
        tester.widget<Text>(find.text('تست تمام شد')).style?.fontFamily,
        'Vazirmatn',
      );
      _expectNoLatinWords(tester, allowed: {'ms'});
    });
  });

  group('Check my IP', () {
    testWidgets('says the connection state in words and drops the old '
        'console labels', (tester) async {
      await _pump(tester, const IpInfoScreen(), vpn: _FakeVpn(connected: true));

      expect(find.text('Connected'), findsOneWidget);
      expect(find.text('IP address'), findsOneWidget);
      for (final old in [
        'TUNNEL ACTIVE',
        'ASSIGNED ENDPOINT',
        'NETWORK DETAILS',
        'COMPLIANCE CHECK',
        'DNS Leak Protection',
        'WebRTC Leak Guard',
        'IPv6 Leak Prevention',
        'IP Address Masked',
      ]) {
        expect(find.text(old), findsNothing, reason: old);
      }
      // The list heading icon used to be checklist_rtl, which points one
      // way in every language.
      expect(find.byIcon(Icons.checklist_rtl_rounded), findsNothing);
    });

    testWidgets('makes no claim about what the connection protects', (
      tester,
    ) async {
      // The app checks none of it, routes some sites outside the tunnel,
      // and reads the address over the phone's own network, so a ticked
      // "Your address is hidden" sat above the phone's own address.
      await _pump(tester, const IpInfoScreen(), vpn: _FakeVpn(connected: true));

      expect(
        find.textContaining(RegExp('protect', caseSensitive: false)),
        findsNothing,
      );
      expect(find.textContaining('hidden'), findsNothing);
      expect(find.textContaining('covered'), findsNothing);
      expect(find.byIcon(Icons.check_circle_rounded), findsNothing);
    });

    testWidgets('while not connected it says so', (tester) async {
      await _pump(tester, const IpInfoScreen(), vpn: _FakeVpn());

      expect(find.text('Not connected'), findsOneWidget);
      expect(find.byIcon(Icons.shield_outlined), findsOneWidget);
    });

    testWidgets('an address that could not be read offers Try again', (
      tester,
    ) async {
      await _pump(tester, const IpInfoScreen(), vpn: _FakeVpn());

      // The test binding answers every request with an error, so the
      // lookup ends with no address.
      expect(find.text('Could not check your address'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Try again'), findsOneWidget);
      expect(find.byTooltip('Refresh'), findsOneWidget);
    });

    testWidgets('Persian: every line in Persian and in Vazirmatn', (
      tester,
    ) async {
      await _pump(
        tester,
        const IpInfoScreen(),
        vpn: _FakeVpn(connected: true),
        locale: const Locale('fa'),
      );

      expect(find.text('آدرس آی‌پی'), findsOneWidget);
      expect(
        tester.widget<Text>(find.text('وصل شد')).style?.fontFamily,
        'Vazirmatn',
      );
      expect(
        tester
            .widget<Text>(find.text('بررسی آدرس شما انجام نشد'))
            .style
            ?.fontFamily,
        'Vazirmatn',
      );
      _expectNoLatinWords(tester);
    });
  });

  group('History', () {
    testWidgets('names its totals, the week and the list in the app '
        'language', (tester) async {
      await _pump(
        tester,
        const AnalyticsScreen(),
        tracker: _FakeTracker(_sessions()),
      );

      expect(find.text('Sessions'), findsOneWidget);
      expect(find.text('Time connected'), findsOneWidget);
      expect(find.text('Average connection'), findsOneWidget);
      // The chart ends today, so it is not the calendar week.
      expect(find.text('Recent days'), findsOneWidget);
      expect(find.text('This week'), findsNothing);
      expect(find.text('Recent connections'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.textContaining('Today at '), findsOneWidget);
      expect(find.textContaining('Yesterday at '), findsOneWidget);
      for (final old in [
        'Tunnel Time',
        'Avg Duration',
        'TUNNEL ACTIVITY',
        'TUNNEL SESSIONS',
      ]) {
        expect(find.text(old), findsNothing, reason: old);
      }
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('durations use the language\'s own units and digits', (
      tester,
    ) async {
      late BuildContext en;
      late BuildContext fa;
      await tester.pumpWidget(
        Column(
          children: [
            _localized(const Locale('en'), (c) => en = c),
            _localized(const Locale('fa'), (c) => fa = c),
          ],
        ),
      );

      String d(BuildContext c, int seconds) =>
          AnalyticsScreen.durationText(c, Duration(seconds: seconds));
      expect(d(en, 3725), '1 h 2 min');
      expect(d(en, 7200), '2 h');
      expect(d(en, 125), '2 min');
      expect(d(en, 42), '42 s');
      expect(d(fa, 3725), '۱ ساعت و ۲ دقیقه');
      expect(d(fa, 42), '۴۲ ثانیه');
    });

    testWidgets('weekday names fit seven to a row in every language', (
      tester,
    ) async {
      late BuildContext fa;
      late BuildContext de;
      late BuildContext ar;
      late BuildContext ur;
      await tester.pumpWidget(
        Column(
          children: [
            _localized(const Locale('fa'), (c) => fa = c),
            _localized(const Locale('de'), (c) => de = c),
            _localized(const Locale('ar'), (c) => ar = c),
            _localized(const Locale('ur'), (c) => ur = c),
          ],
        ),
      );
      final week = [for (var i = 12; i <= 18; i++) DateTime(2026, 10, i)];

      final persian = AnalyticsScreen.weekdayLabels(fa, week);
      expect(persian, hasLength(7));
      for (final name in persian) {
        expect(name.characters.length, lessThanOrEqualTo(2), reason: name);
      }
      expect(persian.toSet(), hasLength(7), reason: 'every day apart');
      final german = AnalyticsScreen.weekdayLabels(de, week);
      expect(german.first, startsWith('Mo'));
      expect(german.first.length, lessThanOrEqualTo(4));

      // Urdu's one letter form is the English S, M, T, W, T, F, S. Arabic
      // and Urdu must name their days in their own script.
      for (final (code, context) in [('ar', ar), ('ur', ur)]) {
        final names = AnalyticsScreen.weekdayLabels(context, week);
        expect(names, hasLength(7), reason: code);
        expect(names.toSet(), hasLength(7), reason: '$code: $names');
        for (final name in names) {
          expect(name, isNot(contains(RegExp('[A-Za-z]'))), reason: code);
        }
      }
    });

    testWidgets('Urdu weekday names fit their bars', (tester) async {
      await _pump(
        tester,
        const AnalyticsScreen(),
        tracker: _FakeTracker(_sessions()),
        locale: const Locale('ur'),
        size: const Size(320, 568),
      );
      // _pump fails on any overflow. The long short names are drawn
      // smaller instead of being cut.
      expect(find.text('جمعرات'), findsOneWidget);
      expect(
        find.ancestor(
          of: find.text('جمعرات'),
          matching: find.byType(FittedBox),
        ),
        findsOneWidget,
      );
    });

    testWidgets('the bars do not animate under reduce motion', (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ChangeNotifierProvider<SessionTracker>.value(
          value: _FakeTracker(_sessions()),
          child: MaterialApp(
            theme: appThemeFor(const Locale('en')),
            localizationsDelegates: S.localizationsDelegates,
            supportedLocales: S.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: child!,
            ),
            home: const AnalyticsScreen(),
          ),
        ),
      );
      final bars = tester.widgetList<AnimatedContainer>(
        find.byType(AnimatedContainer),
      );
      expect(bars, hasLength(7));
      for (final bar in bars) {
        expect(bar.duration, Duration.zero);
      }
    });

    testWidgets('an older start reads as the date at the time', (tester) async {
      late BuildContext en;
      await tester.pumpWidget(_localized(const Locale('en'), (c) => en = c));
      final text = AnalyticsScreen.startedText(en, DateTime(2026, 1, 5, 9, 5));
      expect(text, startsWith('Jan 5, 2026 at '));
    });

    testWidgets('Persian: Vazirmatn and Persian digits', (tester) async {
      await _pump(
        tester,
        const AnalyticsScreen(),
        tracker: _FakeTracker(_sessions()),
        locale: const Locale('fa'),
      );

      expect(find.text('۳'), findsOneWidget);
      expect(
        tester.widget<Text>(find.text('روزهای اخیر')).style?.fontFamily,
        'Vazirmatn',
      );
      // Each caption sits right under its number, so a tile reads as one
      // fact, and the three numbers start on one line. A caption pinned to
      // the bottom of its tile floated far below a short number.
      final captions = ['اتصال‌ها', 'مدت اتصال', 'میانگین هر اتصال'];
      final valueTops = <double>{};
      for (final c in captions) {
        final tile = find
            .ancestor(of: find.text(c), matching: find.byType(Column))
            .first;
        final texts = find.descendant(of: tile, matching: find.byType(Text));
        expect(texts, findsNWidgets(2), reason: c);
        final value = tester.getRect(texts.first);
        valueTops.add(value.top);
        expect(
          tester.getTopLeft(find.text(c)).dy - value.bottom,
          closeTo(4, 0.5),
          reason: c,
        );
        expect(
          tester.widget<Text>(find.text(c)).style?.fontSize,
          greaterThanOrEqualTo(12.5),
          reason: 'the Persian floor',
        );
      }
      expect(valueTops, hasLength(1), reason: '$valueTops');
      // The hours and minutes totals, not the whole unit labels over the
      // chart bars, which may shrink.
      final totals = find.textContaining(' و ');
      expect(totals, findsWidgets);
      for (final total in totals.evaluate()) {
        expect(
          find.ancestor(
            of: find.byWidget(total.widget),
            matching: find.byType(FittedBox),
          ),
          findsNothing,
          reason: 'a duration is wrapped, not scaled down',
        );
      }
      // The server's own name is kept as it was saved.
      _expectNoLatinWords(tester, allowed: {'ms', 'Helsinki'});
    });

    testWidgets('the latest connections are one card with hairlines between '
        'the rows', (tester) async {
      await _pump(
        tester,
        const AnalyticsScreen(),
        tracker: _FakeTracker(_sessions()),
      );
      // Three rows, two hairlines, in one card like the groups in Settings.
      expect(find.byType(Divider), findsNWidgets(2));
      expect(find.text('Helsinki'), findsNWidgets(3));
    });

    testWidgets('a session saved with no country shows the steel globe', (
      tester,
    ) async {
      final sessions = [
        for (final s in _sessions())
          ConnectionSession(
            id: s.id,
            serverName: s.serverName,
            serverCountry: '',
            serverFlagEmoji: '\u{1F310}',
            startTime: s.startTime,
            endTime: s.endTime,
            avgLatencyMs: s.avgLatencyMs,
          ),
      ];
      await _pump(
        tester,
        const AnalyticsScreen(),
        tracker: _FakeTracker(sessions),
      );
      expect(find.text('\u{1F310}'), findsNothing);
      expect(find.byIcon(Icons.public_rounded), findsNWidgets(3));
    });

    testWidgets('Persian numbers keep their digits together, and a reply '
        'time reads number then unit', (tester) async {
      await _pump(
        tester,
        const AnalyticsScreen(),
        tracker: _FakeTracker(_sessions()),
        locale: const Locale('fa'),
      );
      // Vazirmatn's tabular Persian digits sit in full-width cells, so a
      // tabular "۱۱" read as two numbers.
      for (final text in tester.widgetList<Text>(find.byType(Text))) {
        expect(
          text.style?.fontFeatures ?? const [],
          isEmpty,
          reason: '${text.data}',
        );
      }
      final latency = find.text('۱۲۰ ms');
      expect(latency, findsNWidgets(3));
      for (final text in tester.widgetList<Text>(latency)) {
        expect(text.textDirection, TextDirection.ltr);
      }
    });

    testWidgets('with no history it says so', (tester) async {
      await _pump(tester, const AnalyticsScreen(), tracker: _FakeTracker([]));
      expect(find.text('No session data'), findsOneWidget);
      expect(find.text('Connect to start tracking'), findsOneWidget);
    });
  });

  group('a small phone with large text', () {
    final result = SpeedTestResult(
      downloadMbps: 123.4,
      uploadMbps: 45.6,
      pingMs: 1234,
      timestamp: DateTime(2026, 10, 17),
    );
    for (final lang in ['en', 'fa', 'de', 'ru']) {
      for (final (name, screen) in <(String, Widget)>[
        ('speed', const SpeedTestScreen()),
        ('ip', const IpInfoScreen()),
        ('history', const AnalyticsScreen()),
        ('dns', const DnsSettingsScreen()),
      ]) {
        testWidgets('the $name screen lays out in $lang', (tester) async {
          // _pump fails on any overflow.
          await _pump(
            tester,
            screen,
            speed: _FakeSpeed()..result = result,
            vpn: _FakeVpn(connected: true),
            tracker: _FakeTracker(_sessions()),
            locale: Locale(lang),
            size: const Size(320, 568),
            textScale: 1.3,
          );
          await tester.pumpWidget(const SizedBox());
        });
      }
    }
  });

  group('DNS', () {
    testWidgets('saves both addresses under the keys the tunnel reads', (
      tester,
    ) async {
      await _pumpDns(tester);

      expect(find.text('What is DNS?'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, '9.9.9.9');
      await tester.enterText(find.byType(TextField).last, '1.0.0.1');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('pref_remote_dns'), '9.9.9.9,1.0.0.1');
      expect(prefs.getString('pref_domestic_dns'), '9.9.9.9,1.0.0.1');
      expect(find.text('DNS settings saved'), findsOneWidget);
    });

    testWidgets('refuses an address that is not one', (tester) async {
      await _pumpDns(tester);

      await tester.enterText(find.byType(TextField).first, '300.1.1.1');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pump();

      expect(
        find.text('That primary DNS address is not valid'),
        findsOneWidget,
      );
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('pref_remote_dns'), isNull);
      expect(find.byType(DnsSettingsScreen), findsOneWidget);
    });

    testWidgets('in English the addresses sit on the left', (tester) async {
      await _pumpDns(tester);
      for (final field in tester.widgetList<TextField>(
        find.byType(TextField),
      )) {
        expect(field.textAlign, TextAlign.left);
      }
    });

    testWidgets('Persian draws in Vazirmatn', (tester) async {
      await _pumpDns(tester, locale: const Locale('fa'));
      expect(
        tester.widget<Text>(find.text('DNS اصلی')).style?.fontFamily,
        'Vazirmatn',
      );
    });

    testWidgets('the addresses read left to right in Persian', (tester) async {
      await _pumpDns(tester, locale: const Locale('fa'));
      for (final field in tester.widgetList<TextField>(
        find.byType(TextField),
      )) {
        expect(field.textDirection, TextDirection.ltr);
        expect(field.decoration?.hintTextDirection, TextDirection.ltr);
        // At the start edge of the page, under its label, as Check my IP
        // shows an address.
        expect(field.textAlign, TextAlign.right);
      }
      for (final editable in tester.widgetList<EditableText>(
        find.byType(EditableText),
      )) {
        expect(editable.textDirection, TextDirection.ltr);
      }
    });
  });
}

Future<void> _pump(
  WidgetTester tester,
  Widget screen, {
  _FakeSpeed? speed,
  _FakeVpn? vpn,
  SessionTracker? tracker,
  Locale locale = const Locale('en'),
  bool settle = true,
  Size size = const Size(412, 915),
  double textScale = 1.0,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<SpeedTestService>.value(
          value: speed ?? _FakeSpeed(),
        ),
        ChangeNotifierProvider<VpnService>.value(value: vpn ?? _FakeVpn()),
        ChangeNotifierProvider<SessionTracker>.value(
          value: tracker ?? _FakeTracker(const []),
        ),
      ],
      child: MaterialApp(
        locale: locale,
        theme: appThemeFor(locale),
        localizationsDelegates: S.localizationsDelegates,
        supportedLocales: S.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: screen,
      ),
    ),
  );
  if (screen is IpInfoScreen) await _waitForLookup(tester);
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
  expect(tester.takeException(), isNull);
  // VpnService checks the native status once, two seconds after it is
  // made. Let that pass now, so no timer is left when the test ends.
  await tester.pump(const Duration(seconds: 3));
}

/// Lets the address lookup of Check my IP finish. It goes through real
/// input and output, which the test clock does not move, and the test
/// binding answers it with an error.
Future<void> _waitForLookup(WidgetTester tester) async {
  for (var i = 0; i < 50; i++) {
    final loading = find.byType(CircularProgressIndicator).evaluate();
    if (loading.isEmpty) return;
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();
  }
}

Future<void> _pumpDns(WidgetTester tester, {Locale? locale}) async {
  final shown = locale ?? const Locale('en');
  await tester.pumpWidget(
    MaterialApp(
      locale: shown,
      theme: appThemeFor(shown),
      localizationsDelegates: S.localizationsDelegates,
      supportedLocales: S.supportedLocales,
      // A route under the screen, so Save has somewhere to go back to.
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const DnsSettingsScreen(),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

/// A widget that hands its context, under the app's localizations for
/// [locale], to [use].
Widget _localized(Locale locale, void Function(BuildContext) use) {
  return SizedBox(
    height: 10,
    child: Localizations(
      locale: locale,
      delegates: S.localizationsDelegates,
      child: Builder(
        builder: (context) {
          use(context);
          return const SizedBox.shrink();
        },
      ),
    ),
  );
}

/// The still bar a result tile shows before anything is measured.
final _placeholder = find.byKey(const ValueKey('speed-tile-placeholder'));

GaugePainter _gauge(WidgetTester tester) {
  final paint = tester
      .widgetList<CustomPaint>(find.byType(CustomPaint))
      .firstWhere((p) => p.painter is GaugePainter);
  return paint.painter! as GaugePainter;
}

/// No Text on screen holds an English word, beyond [allowed] and the
/// Latin names that stay Latin in every language.
void _expectNoLatinWords(
  WidgetTester tester, {
  Set<String> allowed = const {},
}) {
  const always = {'DNS', 'IP', 'VPN'};
  final word = RegExp(r'[A-Za-z]{2,}');
  for (final text in tester.widgetList<Text>(find.byType(Text))) {
    final data = text.data ?? '';
    for (final m in word.allMatches(data)) {
      final w = m[0]!;
      expect(
        always.contains(w) || allowed.contains(w),
        isTrue,
        reason: 'English word "$w" in "$data"',
      );
    }
  }
}

List<ConnectionSession> _sessions() {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day, 0, 30);
  final yesterday = today.subtract(const Duration(hours: 20));
  final earlier = today.subtract(const Duration(hours: 70));
  ConnectionSession s(String id, DateTime start, int minutes) =>
      ConnectionSession(
        id: id,
        serverName: 'Helsinki',
        serverCountry: 'FI',
        serverFlagEmoji: '\u{1F1EB}\u{1F1EE}',
        startTime: start,
        endTime: start.add(Duration(minutes: minutes)),
        avgLatencyMs: 120,
      );
  return [s('a', today, 20), s('b', yesterday, 95), s('c', earlier, 3)];
}

class _FakeSpeed extends SpeedTestService {
  bool running = false;
  double progressValue = 0;
  String phaseText = '';
  SpeedTestResult? result;
  int runs = 0;

  @override
  bool get isRunning => running;

  @override
  double get progress => progressValue;

  @override
  String get phase => phaseText;

  @override
  SpeedTestResult? get lastResult => result;

  @override
  Future<void> runTest() async {
    if (running) return;
    runs++;
  }
}

class _FakeVpn extends VpnService {
  _FakeVpn({this.connected = false});

  final bool connected;

  @override
  VpnStatus get status =>
      connected ? VpnStatus.connected : VpnStatus.disconnected;

  @override
  bool get isConnected => connected;

  @override
  bool get isConnecting => false;
}

class _FakeTracker extends SessionTracker {
  _FakeTracker(this._list);

  final List<ConnectionSession> _list;

  @override
  List<ConnectionSession> get sessions => _list;

  @override
  int get totalSessions => _list.length;

  @override
  Duration get totalConnectionTime =>
      _list.fold(Duration.zero, (sum, s) => sum + s.duration);

  @override
  Duration get averageSessionDuration => _list.isEmpty
      ? Duration.zero
      : Duration(
          milliseconds: totalConnectionTime.inMilliseconds ~/ _list.length,
        );

  @override
  Map<DateTime, Duration> get dailyConnectionTime {
    final now = DateTime.now();
    final days = <DateTime, Duration>{
      for (var i = 6; i >= 0; i--)
        DateTime(now.year, now.month, now.day - i): Duration.zero,
    };
    for (final s in _list) {
      final day = DateTime(
        s.startTime.year,
        s.startTime.month,
        s.startTime.day,
      );
      if (days.containsKey(day)) days[day] = days[day]! + s.duration;
    }
    return days;
  }
}
