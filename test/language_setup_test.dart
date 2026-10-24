import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/core/design_system.dart';
import 'package:fortiva_vpn/core/form_factor.dart';
import 'package:fortiva_vpn/core/state/locale_state.dart';
import 'package:fortiva_vpn/l10n/generated/app_localizations.dart';
import 'package:fortiva_vpn/screens/language_setup_screen.dart';
import 'package:fortiva_vpn/widgets/language_picker.dart';
import 'package:fortiva_vpn/widgets/ui/sheet_handle.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/app_theme.dart';

/// The first-run language question (lib/screens/language_setup_screen.dart)
/// and the language sheet (lib/widgets/language_picker.dart): every name in
/// its own type and direction at the start edge, the suggested or current
/// language selected and in view, and the arrow named for a screen reader.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => FormFactor.isTvForTest = false);

  void phone(WidgetTester tester, {Size size = const Size(360, 640)}) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Widget app(Widget home, {Locale locale = const Locale('en')}) => MaterialApp(
    locale: locale,
    theme: appThemeFor(locale),
    localizationsDelegates: S.localizationsDelegates,
    supportedLocales: S.supportedLocales,
    home: home,
  );

  Future<({LocaleState state, List<int> done})> pumpSetup(
    WidgetTester tester, {
    String suggested = 'en',
    Locale locale = const Locale('en'),
  }) async {
    final state = LocaleState();
    final done = <int>[];
    await tester.pumpWidget(
      app(
        LanguageSetupScreen(
          localeState: state,
          suggested: suggested,
          onDone: () => done.add(1),
        ),
        locale: locale,
      ),
    );
    await tester.pumpAndSettle();
    return (state: state, done: done);
  }

  Text nameText(WidgetTester tester, String name) => tester.widget<Text>(
    find.descendant(of: find.byType(LanguageOption), matching: find.text(name)),
  );

  group('first-run language', () {
    testWidgets('writes every name in its own type and direction', (
      tester,
    ) async {
      phone(tester, size: const Size(360, 2000));
      await pumpSetup(tester);

      for (final entry in LocaleState.supportedLanguages.entries) {
        final text = nameText(tester, entry.value);
        final own = Locale(entry.key);
        expect(
          text.style?.fontFamily,
          AppDesign.fontFamilyForLocale(own),
          reason: entry.key,
        );
        expect(
          text.textDirection,
          AppDesign.isRtlLocale(own) ? TextDirection.rtl : TextDirection.ltr,
          reason: entry.key,
        );
      }
      expect(nameText(tester, 'فارسی').style?.fontFamily, 'Vazirmatn');
      expect(nameText(tester, 'فارسی').style?.letterSpacing, 0);
      expect(nameText(tester, 'English').style?.fontFamily, 'Inter');
    });

    for (final (locale, rtl) in [
      (const Locale('en'), false),
      (const Locale('fa'), true),
    ]) {
      testWidgets('[${locale.languageCode}] lines every name up at the '
          'start edge, whatever its own direction', (tester) async {
        phone(tester, size: const Size(360, 2000));
        await pumpSetup(tester, locale: locale);

        double edge(String name) {
          final rect = tester.getRect(find.text(name));
          return rtl ? rect.right : rect.left;
        }

        final english = edge('English');
        for (final name in ['فارسی', 'العربية', 'اردو', 'Русский']) {
          expect(edge(name), moreOrLessEquals(english), reason: name);
        }
      });
    }

    testWidgets('starts on the suggested language, scrolled into view', (
      tester,
    ) async {
      phone(tester);
      // The last language, far below the fold on a small phone.
      await pumpSetup(tester, suggested: 'zh');

      final name = find.text('简体中文');
      final rect = tester.getRect(name);
      final button = tester.getRect(find.byType(FilledButton));
      expect(rect.top, greaterThanOrEqualTo(0));
      expect(rect.bottom, lessThanOrEqualTo(button.top));
      final selected = find.ancestor(
        of: find.byIcon(Icons.check_circle_rounded),
        matching: find.byType(LanguageOption),
      );
      expect(selected, findsOneWidget);
      expect(tester.widget<LanguageOption>(selected).code, 'zh');
    });

    testWidgets('rows are at least 56 high', (tester) async {
      phone(tester);
      await pumpSetup(tester);
      for (final row in tester.widgetList<LanguageOption>(
        find.byType(LanguageOption),
      )) {
        final size = tester.getSize(find.byWidget(row));
        expect(size.height, greaterThanOrEqualTo(56), reason: row.code);
      }
    });

    testWidgets('a tap moves the choice, and the arrow saves it', (
      tester,
    ) async {
      phone(tester, size: const Size(360, 2000));
      final setup = await pumpSetup(tester, suggested: 'en');

      await tester.tap(find.text('Deutsch'));
      await tester.pumpAndSettle();
      final selected = find.ancestor(
        of: find.byIcon(Icons.check_circle_rounded),
        matching: find.byType(LanguageOption),
      );
      expect(tester.widget<LanguageOption>(selected).code, 'de');
      expect(setup.done, isEmpty);

      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      expect(setup.done, [1]);
      expect(setup.state.locale, const Locale('de'));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getKeys(), isNotEmpty);
    });

    testWidgets('accepting the suggestion as it is still saves it', (
      tester,
    ) async {
      phone(tester);
      final setup = await pumpSetup(tester, suggested: 'fa');
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      expect(setup.done, [1]);
      expect(setup.state.locale, const Locale('fa'));
      expect(setup.state.hasChosen, isTrue);
    });

    testWidgets('the arrow is named, in the language being chosen', (
      tester,
    ) async {
      phone(tester);
      final handle = tester.ensureSemantics();
      await pumpSetup(tester, suggested: 'en');
      expect(find.bySemanticsLabel('Next'), findsOneWidget);

      await tester.ensureVisible(find.text('فارسی'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('فارسی'));
      await tester.pumpAndSettle();
      expect(
        find.bySemanticsLabel(lookupS(const Locale('fa')).peerShareNext),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('on a TV, the remote starts on the suggested language', (
      tester,
    ) async {
      FormFactor.isTvForTest = true;
      phone(tester, size: const Size(960, 540));
      await pumpSetup(tester, suggested: 'ru');
      final focused = FocusManager.instance.primaryFocus?.context;
      expect(focused, isNotNull);
      final row = focused!.findAncestorWidgetOfExactType<LanguageOption>();
      expect(row?.code, 'ru');
    });
  });

  testWidgets('on a TV, a press keeps the focus on the row pressed', (
    tester,
  ) async {
    FormFactor.isTvForTest = true;
    phone(tester, size: const Size(960, 540));
    final state = LocaleState();
    await tester.pumpWidget(
      app(
        LanguageSetupScreen(localeState: state, suggested: 'en', onDone: () {}),
      ),
    );
    await tester.pumpAndSettle();

    // Two presses in a row, the way a remote moves down the list.
    for (final (name, code) in [('Deutsch', 'de'), ('Français', 'fr')]) {
      Focus.of(tester.element(find.text(name))).requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      final selected = find.ancestor(
        of: find.byIcon(Icons.check_circle_rounded),
        matching: find.byType(LanguageOption),
      );
      expect(tester.widget<LanguageOption>(selected).code, code);
      final focused = FocusManager.instance.primaryFocus?.context;
      expect(
        focused?.findAncestorWidgetOfExactType<LanguageOption>()?.code,
        code,
      );
    }
  });

  group('language sheet', () {
    Future<LocaleState> openSheet(
      WidgetTester tester, {
      String current = 'en',
    }) async {
      final state = LocaleState();
      await state.setLocale(Locale(current));
      await tester.pumpWidget(
        app(
          Scaffold(
            appBar: AppBar(actions: [LanguageButton(localeState: state)]),
          ),
          locale: Locale(current),
        ),
      );
      await tester.tap(find.byType(LanguageButton));
      await tester.pumpAndSettle();
      return state;
    }

    testWidgets('has a handle, a title and the current language in view', (
      tester,
    ) async {
      phone(tester);
      await openSheet(tester, current: 'uz');

      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.byType(SheetHandle), findsOneWidget);
      expect(find.text(lookupS(const Locale('uz')).language), findsOneWidget);
      final rect = tester.getRect(find.text('Oʻzbekcha'));
      expect(rect.top, greaterThanOrEqualTo(0));
      expect(rect.bottom, lessThanOrEqualTo(640));
      final selected = find.ancestor(
        of: find.byIcon(Icons.check_circle_rounded),
        matching: find.byType(LanguageOption),
      );
      expect(tester.widget<LanguageOption>(selected).code, 'uz');
    });

    testWidgets('a tap switches the language and closes the sheet', (
      tester,
    ) async {
      phone(tester, size: const Size(360, 1400));
      final state = await openSheet(tester);
      await tester.tap(find.text('Türkçe'));
      await tester.pumpAndSettle();
      expect(state.locale, const Locale('tr'));
      expect(find.byType(BottomSheet), findsNothing);
    });

    testWidgets('on a TV the sheet keeps to 640 wide, and the title starts '
        'on the rows\' edge', (tester) async {
      phone(tester, size: const Size(960, 540));
      await openSheet(tester);

      // The sheet's surface: the BottomSheet widget itself spans the
      // screen and centres the surface inside its limits.
      final sheet = tester.getRect(
        find
            .descendant(
              of: find.byType(BottomSheet),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(sheet.width, 640);
      expect(sheet.center.dx, 480);
      final title = tester.getRect(
        find.text(lookupS(const Locale('en')).language),
      );
      final row = tester.getRect(find.byType(LanguageOption).first);
      expect(title.left, row.left);
    });

    testWidgets('the header button is a 48dp target named by the language', (
      tester,
    ) async {
      phone(tester);
      final handle = tester.ensureSemantics();
      final state = LocaleState();
      await state.setLocale(const Locale('fa'));
      await tester.pumpWidget(
        app(
          Scaffold(
            appBar: AppBar(actions: [LanguageButton(localeState: state)]),
          ),
          locale: const Locale('fa'),
        ),
      );
      final size = tester.getSize(find.byType(LanguageButton));
      expect(size.height, greaterThanOrEqualTo(48));
      expect(size.width, greaterThanOrEqualTo(48));
      expect(find.text('FA'), findsOneWidget);
      expect(find.bySemanticsLabel('فارسی'), findsOneWidget);
      handle.dispose();
    });
  });
}
