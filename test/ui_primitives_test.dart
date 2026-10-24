import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/core/design_system.dart';
import 'package:fortiva_vpn/core/form_factor.dart';
import 'package:fortiva_vpn/core/haptics.dart';
import 'package:fortiva_vpn/core/page_transitions.dart';
import 'package:fortiva_vpn/data/models/connection_info.dart';
import 'package:fortiva_vpn/l10n/generated/app_localizations.dart';
import 'package:fortiva_vpn/widgets/power_button.dart';
import 'package:fortiva_vpn/widgets/power_face.dart';
import 'package:fortiva_vpn/widgets/state_wash.dart';
import 'package:fortiva_vpn/widgets/ui/pressable.dart';
import 'package:fortiva_vpn/widgets/ui/section_label.dart';
import 'package:fortiva_vpn/widgets/ui/sheet_handle.dart';
import 'package:fortiva_vpn/widgets/ui/signal_bars.dart';

/// The shared pieces every screen is built from: the design tokens that
/// carry rules (latency, the app's language), the tappable surface, the
/// signal bars, the section heading, the sheet handle, haptics, and the
/// stubs the power button work builds on.

Widget _app(Widget child, {Locale locale = const Locale('en')}) => MaterialApp(
  locale: locale,
  localizationsDelegates: S.localizationsDelegates,
  supportedLocales: S.supportedLocales,
  home: Scaffold(body: Center(child: child)),
);

void main() {
  group('latency', () {
    test('the color follows the reply time, and no reply is an error', () {
      expect(AppDesign.latencyColor(-1), AppDesign.error);
      expect(AppDesign.latencyColor(0), AppDesign.protected);
      expect(
        AppDesign.latencyColor(AppDesign.latencyGoodMs - 1),
        AppDesign.protected,
      );
      expect(
        AppDesign.latencyColor(AppDesign.latencyGoodMs),
        AppDesign.warning,
      );
      expect(
        AppDesign.latencyColor(AppDesign.latencyFairMs - 1),
        AppDesign.warning,
      );
      expect(AppDesign.latencyColor(AppDesign.latencyFairMs), AppDesign.error);
    });

    test('the bars use the same steps as the color', () {
      expect(AppDesign.latencyLevel(-1), 0);
      expect(AppDesign.latencyLevel(AppDesign.latencyGoodMs - 1), 3);
      expect(AppDesign.latencyLevel(AppDesign.latencyGoodMs), 2);
      expect(AppDesign.latencyLevel(AppDesign.latencyFairMs - 1), 2);
      expect(AppDesign.latencyLevel(AppDesign.latencyFairMs), 1);
      expect(AppDesign.latencyLevel(5000), 1);
    });
  });

  group('the app language', () {
    tearDown(() => AppDesign.activeLocale = const Locale('en'));

    test('English by default, with Inter and Latin tracking', () {
      expect(AppDesign.activeLocale, const Locale('en'));
      expect(AppDesign.ls(0.5), 0.5);
      final body = AppDesign.textTheme.bodyLarge!;
      expect(body.fontFamily, 'Inter');
      expect(body.letterSpacing, -0.15);
      expect(body.height, 1.5);
      expect(body.fontSize, 16);
    });

    for (final code in ['fa', 'ar', 'ur']) {
      test('$code: no letter spacing anywhere, and taller lines', () {
        AppDesign.activeLocale = Locale(code);
        expect(AppDesign.ls(0.5), 0);
        expect(AppDesign.ls(-1), 0);
        final theme = AppDesign.textTheme;
        expect(theme.bodyLarge!.fontFamily, 'Vazirmatn');
        expect(theme.bodyLarge!.height, 1.75);
        expect(theme.titleMedium!.height, 1.6);
        for (final style in [
          theme.displayLarge,
          theme.displayMedium,
          theme.displaySmall,
          theme.headlineLarge,
          theme.headlineMedium,
          theme.headlineSmall,
          theme.titleLarge,
          theme.titleMedium,
          theme.titleSmall,
          theme.bodyLarge,
          theme.bodyMedium,
          theme.bodySmall,
          theme.labelLarge,
          theme.labelMedium,
          theme.labelSmall,
        ]) {
          expect(style!.letterSpacing, 0);
        }
      });
    }

    test('a Latin language other than English keeps the tracking', () {
      AppDesign.activeLocale = const Locale('de');
      expect(AppDesign.ls(0.5), 0.5);
      expect(AppDesign.textTheme.displayLarge!.letterSpacing, -1.0);
    });

    // AppDesign.numberFeatures drops tabular figures in Persian, Arabic
    // and Urdu, where Vazirmatn's tabular digits sit in wide cells. A
    // literal list on a screen kept them there.
    test('numbers take AppDesign.numberFeatures, never a literal list', () {
      final offenders = [
        for (final file in Directory(
          'lib',
        ).listSync(recursive: true).whereType<File>())
          if (file.path.endsWith('.dart') &&
              !file.path.endsWith('core/design_system.dart') &&
              file.readAsStringSync().contains('tabularFigures'))
            file.path,
      ];
      expect(offenders, isEmpty);
      AppDesign.activeLocale = const Locale('fa');
      expect(AppDesign.numberFeatures, isEmpty);
      AppDesign.activeLocale = const Locale('en');
      expect(AppDesign.numberFeatures, [const FontFeature.tabularFigures()]);
    });

    test('the text theme is built once per language', () {
      expect(
        identical(
          AppDesign.textThemeForLocale(const Locale('fa')),
          AppDesign.textThemeForLocale(const Locale('fa')),
        ),
        isTrue,
      );
    });
  });

  group('theme', () {
    test('every color role is set, none falls back to white or purple', () {
      final scheme = AppDesign.darkThemeForLocale(const Locale('en'));
      expect(scheme.colorScheme.primary, AppDesign.brand);
      expect(scheme.colorScheme.outline, AppDesign.outline);
      expect(scheme.colorScheme.outlineVariant, AppDesign.outlineVariant);
      expect(scheme.colorScheme.surfaceTint, Colors.transparent);
      expect(scheme.colorScheme.surfaceContainerHigh, AppDesign.surfaceHigh);
      expect(scheme.scaffoldBackgroundColor, AppDesign.canvas);
      expect(scheme.splashFactory, InkRipple.splashFactory);
    });

    test('the theme text is in the font of its language', () {
      final fa = AppDesign.darkThemeForLocale(const Locale('fa'));
      expect(fa.textTheme.bodyMedium!.fontFamily, 'Vazirmatn');
      expect(fa.textTheme.bodyMedium!.letterSpacing, 0);
      expect(fa.snackBarTheme.contentTextStyle!.color, AppDesign.textPrimary);
    });
  });

  group('AppMotion', () {
    testWidgets('reduced follows the phone setting', (tester) async {
      late bool reduced;
      Widget probe(bool off) => MediaQuery(
        data: MediaQueryData(disableAnimations: off),
        child: Builder(
          builder: (context) {
            reduced = AppMotion.reduced(context);
            return const SizedBox();
          },
        ),
      );
      await tester.pumpWidget(probe(true));
      expect(reduced, isTrue);
      await tester.pumpWidget(probe(false));
      expect(reduced, isFalse);
    });

    test('the route keeps its type and gets the shorter timing', () {
      final route = SlideUpFadeTransition(page: const SizedBox());
      expect(route.transitionDuration, const Duration(milliseconds: 300));
      expect(
        route.reverseTransitionDuration,
        const Duration(milliseconds: 220),
      );
    });
  });

  group('Pressable', () {
    testWidgets('a tap and a long press reach their callbacks', (tester) async {
      var taps = 0;
      var longPresses = 0;
      await tester.pumpWidget(
        _app(
          Pressable(
            onTap: () => taps++,
            onLongPress: () => longPresses++,
            padding: const EdgeInsets.all(16),
            child: const Text('Germany'),
          ),
        ),
      );
      await tester.tap(find.text('Germany'));
      await tester.longPress(find.text('Germany'));
      await tester.pumpAndSettle();
      expect(taps, 1);
      expect(longPresses, 1);
    });

    testWidgets('the ripple draws on the fill, not under it', (tester) async {
      await tester.pumpWidget(
        _app(
          Pressable(
            onTap: () {},
            color: AppDesign.surfaceHigh,
            border: const BorderSide(color: AppDesign.hairline),
            child: const Text('Row'),
          ),
        ),
      );
      // Ink paints on the nearest Material above the InkWell. That Material
      // is the fill itself, so nothing opaque sits between them.
      final material = tester.widget<Material>(
        find
            .ancestor(of: find.byType(InkWell), matching: find.byType(Material))
            .first,
      );
      expect(material.color, AppDesign.surfaceHigh);
      expect(material.clipBehavior, Clip.antiAlias);
      final shape = material.shape! as RoundedRectangleBorder;
      expect(shape.side.color, AppDesign.hairline);
      expect(shape.borderRadius, BorderRadius.circular(AppDesign.radiusMedium));
    });

    testWidgets('a TV remote can focus it', (tester) async {
      final focus = FocusNode();
      addTearDown(focus.dispose);
      await tester.pumpWidget(
        _app(
          Pressable(onTap: () {}, focusNode: focus, child: const Text('Row')),
        ),
      );
      focus.requestFocus();
      await tester.pump();
      expect(focus.hasFocus, isTrue);
    });

    testWidgets('a screen reader hears a button with its label', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _app(
          Pressable(
            onTap: () {},
            semanticsLabel: 'Change server',
            child: const SizedBox(width: 48, height: 48),
          ),
        ),
      );
      expect(
        tester.getSemantics(find.byType(Pressable)),
        containsSemantics(
          label: 'Change server',
          isButton: true,
          hasTapAction: true,
        ),
      );
      handle.dispose();
    });

    testWidgets('directional radii follow the text direction', (tester) async {
      await tester.pumpWidget(
        _app(
          Pressable(
            onTap: () {},
            borderRadius: const BorderRadiusDirectional.only(
              topStart: Radius.circular(20),
            ),
            child: const Text('Row'),
          ),
          locale: const Locale('fa'),
        ),
      );
      final material = tester.widget<Material>(
        find
            .ancestor(of: find.byType(InkWell), matching: find.byType(Material))
            .first,
      );
      final shape = material.shape! as RoundedRectangleBorder;
      expect(
        shape.borderRadius,
        const BorderRadius.only(topRight: Radius.circular(20)),
      );
    });
  });

  group('SignalBars and LatencyChip', () {
    testWidgets('lit bars are drawn in the color, the rest in steel', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(const SignalBars(level: 2, color: AppDesign.warning)),
      );
      final paint = tester.renderObject(
        find.descendant(
          of: find.byType(SignalBars),
          matching: find.byType(CustomPaint),
        ),
      );
      expect(
        paint,
        paints
          ..rrect(color: AppDesign.warning)
          ..rrect(color: AppDesign.warning)
          ..rrect(color: AppDesign.steelDark),
      );
      expect(tester.getSize(find.byType(SignalBars)), const Size(14, 14));
    });

    testWidgets('a level out of range is clamped', (tester) async {
      await tester.pumpWidget(
        _app(const SignalBars(level: 7, color: AppDesign.protected)),
      );
      final painter =
          tester
                  .widget<CustomPaint>(
                    find.descendant(
                      of: find.byType(SignalBars),
                      matching: find.byType(CustomPaint),
                    ),
                  )
                  .painter!
              as SignalBarsPainter;
      expect(painter.level, 3);
    });

    testWidgets('the reply time is its own Text, in tabular figures', (
      tester,
    ) async {
      await tester.pumpWidget(_app(const LatencyChip(ms: 191)));
      expect(find.text('191 ms'), findsOneWidget);
      final text = tester.widget<Text>(find.text('191 ms'));
      // The bars carry the latency color; the number stays quiet, so a
      // usual reply time does not read as a warning.
      expect(text.style!.color, AppDesign.textSecondary);
      expect(text.style!.fontSize, 13);
      expect(text.style!.fontWeight, FontWeight.w600);
      expect(
        text.style!.fontFeatures,
        contains(const FontFeature.tabularFigures()),
      );
      final bars = tester.widget<SignalBars>(find.byType(SignalBars));
      expect(bars.level, AppDesign.latencyLevel(191));
      expect(bars.color, AppDesign.latencyColor(191));
    });

    testWidgets('Persian shows Persian digits', (tester) async {
      await tester.pumpWidget(
        _app(const LatencyChip(ms: 191), locale: const Locale('fa')),
      );
      expect(find.text('۱۹۱ ms'), findsOneWidget);
      // The number stays before its unit in a right to left line.
      expect(
        tester.widget<Text>(find.text('۱۹۱ ms')).textDirection,
        TextDirection.ltr,
      );
    });

    testWidgets('no reply shows the label the caller passes', (tester) async {
      await tester.pumpWidget(
        _app(const LatencyChip(ms: -1, timeoutLabel: 'Timeout')),
      );
      expect(find.text('Timeout'), findsOneWidget);
      expect(
        tester.widget<Text>(find.text('Timeout')).style!.color,
        AppDesign.error,
      );
      expect(find.textContaining('ms'), findsNothing);
      final bars = tester.widget<SignalBars>(find.byType(SignalBars));
      expect(bars.level, 0);
      expect(bars.color, AppDesign.error);
    });
  });

  group('SectionLabel', () {
    testWidgets('a heading for screen readers, in the tertiary color', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_app(const SectionLabel('Network')));
      expect(
        tester.getSemantics(find.text('Network')),
        containsSemantics(label: 'Network', isHeader: true),
      );
      final text = tester.widget<Text>(find.text('Network'));
      expect(text.style!.color, AppDesign.textTertiary);
      handle.dispose();
    });

    testWidgets('it starts at the start edge in RTL', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('fa'),
          localizationsDelegates: S.localizationsDelegates,
          supportedLocales: S.supportedLocales,
          home: const Scaffold(body: Column(children: [SectionLabel('شبکه')])),
        ),
      );
      final screen = tester.getSize(find.byType(Scaffold));
      final right = tester.getTopRight(find.text('شبکه')).dx;
      // 16 in, on the line where the rows of the card under it start.
      expect(right, screen.width - 16);
    });
  });

  group('SheetHandle', () {
    testWidgets('36 by 4 and silent', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_app(const SheetHandle()));
      final bar = find.descendant(
        of: find.byType(SheetHandle),
        matching: find.byType(Container),
      );
      expect(
        tester.getSize(bar),
        const Size(SheetHandle.width, SheetHandle.height),
      );
      final decoration =
          tester.widget<Container>(bar).decoration! as BoxDecoration;
      expect(decoration.color, AppDesign.steelDark);
      expect(
        find.descendant(
          of: find.byType(SheetHandle),
          matching: find.byType(ExcludeSemantics),
        ),
        findsOneWidget,
      );
      handle.dispose();
    });
  });

  group('AppHaptics', () {
    late List<MethodCall> calls;

    setUp(() => calls = []);

    tearDown(() {
      FormFactor.isTvForTest = false;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    void listen() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            calls.add(call);
            return null;
          });
    }

    testWidgets('each moment has its own kind of feedback', (tester) async {
      listen();
      AppHaptics.tap();
      AppHaptics.success();
      AppHaptics.selection();
      AppHaptics.light();
      await tester.pump();
      expect(calls.map((c) => c.method).toSet(), {'HapticFeedback.vibrate'});
      expect(calls.map((c) => c.arguments), [
        'HapticFeedbackType.mediumImpact',
        'HapticFeedbackType.heavyImpact',
        'HapticFeedbackType.selectionClick',
        'HapticFeedbackType.lightImpact',
      ]);
    });

    testWidgets('nothing on a TV', (tester) async {
      listen();
      FormFactor.isTvForTest = true;
      AppHaptics.tap();
      AppHaptics.success();
      AppHaptics.selection();
      AppHaptics.light();
      await tester.pump();
      expect(calls, isEmpty);
    });

    testWidgets('a platform error is swallowed', (tester) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            throw PlatformException(code: 'no-vibrator');
          });
      AppHaptics.tap();
      AppHaptics.success();
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });

  group('power button stubs', () {
    test('a bare status gives the face it draws', () {
      expect(
        powerFaceFor(VpnStatus.disconnected, isVerifying: false),
        PowerFace.off,
      );
      expect(
        powerFaceFor(VpnStatus.connecting, isVerifying: false),
        PowerFace.connecting,
      );
      // Up but not yet known to work: busy, never connected.
      expect(
        powerFaceFor(VpnStatus.connected, isVerifying: true),
        PowerFace.connecting,
      );
      expect(
        powerFaceFor(VpnStatus.connected, isVerifying: false),
        PowerFace.connected,
      );
      expect(
        powerFaceFor(VpnStatus.disconnecting, isVerifying: false),
        PowerFace.disconnecting,
      );
      expect(
        powerFaceFor(VpnStatus.error, isVerifying: false),
        PowerFace.failed,
      );
    });

    testWidgets('PowerButton takes a face, celebrate and a label', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        _app(
          PowerButton(
            status: VpnStatus.connected,
            isVerifying: false,
            onTap: () => taps++,
            face: PowerFace.stalled,
            celebrate: false,
            semanticLabel: 'Connection stalled',
          ),
        ),
      );
      await tester.tap(find.byType(PowerButton));
      await tester.pump(const Duration(milliseconds: 200));
      expect(taps, 1);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('StateWash leaves its child as it is', (tester) async {
      const key = Key('hero');
      await tester.pumpWidget(
        _app(
          const StateWash(
            face: PowerFace.connected,
            child: SizedBox(key: key, width: 120, height: 80),
          ),
        ),
      );
      expect(tester.getSize(find.byKey(key)), const Size(120, 80));
      expect(tester.getSize(find.byType(StateWash)), const Size(120, 80));
    });
  });
}
