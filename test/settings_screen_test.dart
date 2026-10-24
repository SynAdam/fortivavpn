import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/core/design_system.dart';
import 'package:fortiva_vpn/core/state/app_config_state.dart';
import 'package:fortiva_vpn/core/state/locale_state.dart';
import 'package:fortiva_vpn/core/state/referral_state.dart';
import 'package:fortiva_vpn/l10n/generated/app_localizations.dart';
import 'package:fortiva_vpn/screens/settings_screen.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/app_theme.dart';

/// The look of Settings (lib/screens/settings_screen.dart) that the
/// redesign set: sentence case headings, rows with a visible ripple, the
/// diagnostics disclosure read with its switch, and the version in the
/// language's own digits. What the rows do is pinned elsewhere
/// (premium_entry_points_test, channel_link_test).
void main() {
  setUpAll(
    () => PackageInfo.setMockInitialValues(
      appName: 'Fortiva',
      packageName: 'com.vpn.fortivavpn',
      version: '1.11.0',
      buildNumber: '71',
      buildSignature: '',
    ),
  );
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<S> pump(WidgetTester tester, {String locale = 'en'}) async {
    tester.view.physicalSize = const Size(400, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AppConfigState>(
            create: (_) => AppConfigState(
              fetch: () async => throw StateError('no fetch in tests'),
              retryGaps: const [],
            ),
          ),
          ChangeNotifierProvider<LocaleState>(create: (_) => LocaleState()),
          ChangeNotifierProvider<ReferralState>(create: (_) => ReferralState()),
        ],
        child: MaterialApp(
          locale: Locale(locale),
          theme: appThemeFor(Locale(locale)),
          localizationsDelegates: S.localizationsDelegates,
          supportedLocales: S.supportedLocales,
          home: const SettingsScreen(),
        ),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pumpAndSettle();
    return lookupS(Locale(locale));
  }

  for (final locale in ['en', 'fa', 'de']) {
    testWidgets('[$locale] section headings are in sentence case and are '
        'headings', (tester) async {
      final s = await pump(tester, locale: locale);
      for (final title in [
        s.connection,
        s.tools,
        s.settingsGeneral,
        s.account,
        s.about,
      ]) {
        expect(find.text(title), findsOneWidget, reason: title);
        // Scripts with no capitals read the same either way.
        if (title != title.toUpperCase()) {
          expect(find.text(title.toUpperCase()), findsNothing, reason: title);
        }
        final style = tester.widget<Text>(find.text(title)).style;
        expect(style?.fontFamily, isNot('monospace'), reason: title);
      }
      final handle = tester.ensureSemantics();
      expect(
        tester.getSemantics(find.text(s.connection)),
        containsSemantics(label: s.connection, isHeader: true),
      );
      handle.dispose();
    });
  }

  testWidgets('the diagnostics disclosure is read with its switch', (
    tester,
  ) async {
    final s = await pump(tester);
    expect(find.byType(Switch), findsOneWidget);
    final handle = tester.ensureSemantics();
    final node = tester.getSemantics(find.byType(Switch));
    expect(node.label, contains(s.shareDiagnosticsTitle));
    expect(node.label, contains(s.shareDiagnosticsBody));
    handle.dispose();

    // The text sits beside the switch, on the same row.
    final body = tester.getRect(find.text(s.shareDiagnosticsBody));
    final toggle = tester.getRect(find.byType(Switch));
    expect(toggle.left, greaterThan(body.right));
    expect(toggle.center.dy, inInclusiveRange(body.top, body.bottom));
  });

  testWidgets('the diagnostics icon stands beside its title', (tester) async {
    final s = await pump(tester);
    // Not beside the middle of the disclosure under the title, which is
    // eight lines long. The switch stays beside the disclosure (above).
    // The test font is wide enough to wrap the title, so this is its
    // first line.
    final icon = tester.getCenter(find.byIcon(Icons.troubleshoot_outlined));
    final title = find.text(s.shareDiagnosticsTitle);
    final style = tester.widget<Text>(title).style!;
    final firstLine = style.fontSize! * style.height!;
    expect(icon.dy, closeTo(tester.getTopLeft(title).dy + firstLine / 2, 1));
    // The disclosure is set at the reading size, not as fine print.
    final body = tester.widget<Text>(find.text(s.shareDiagnosticsBody));
    expect(body.style?.fontSize, AppDesign.textTheme.bodyMedium?.fontSize);
    expect(body.style?.color, AppDesign.textSecondary);
  });

  testWidgets('the bar takes a tone once the groups scroll under it', (
    tester,
  ) async {
    await pump(tester);
    tester.view.physicalSize = const Size(400, 700);
    await tester.pumpAndSettle();
    Color? bar() => tester
        .widget<Material>(
          find
              .descendant(
                of: find.byType(AppBar),
                matching: find.byType(Material),
              )
              .first,
        )
        .color;
    expect(bar(), AppDesign.canvas);
    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(bar(), AppDesign.surface);
  });

  testWidgets('rows are tall enough and show their ripple on the group', (
    tester,
  ) async {
    final s = await pump(tester);
    for (final title in [
      s.myServersTitle,
      s.dnsConfiguration,
      s.speedTest,
      s.language,
      s.deleteAccount,
      s.privacyPolicy,
      s.website,
    ]) {
      final row = find.ancestor(
        of: find.text(title),
        matching: find.byType(InkWell),
      );
      expect(row, findsOneWidget, reason: title);
      expect(
        tester.getSize(row).height,
        greaterThanOrEqualTo(SettingsScreen.rowMinHeight),
        reason: title,
      );
      // The ink paints on the nearest Material, which must be the group's
      // fill and not something under it.
      final material = tester.widget<Material>(
        find.ancestor(of: row, matching: find.byType(Material)).first,
      );
      expect(material.color, AppDesign.surfaceLow, reason: title);
    }
  });

  testWidgets('links that leave the app say so, and Delete account has no '
      'arrow', (tester) async {
    final s = await pump(tester);
    Finder inRow(String title, IconData icon) => find.descendant(
      of: find.ancestor(of: find.text(title), matching: find.byType(InkWell)),
      matching: find.byIcon(icon),
    );

    for (final title in [s.privacyPolicy, s.website, s.contactUs]) {
      expect(
        inRow(title, Icons.open_in_new_rounded),
        findsOneWidget,
        reason: title,
      );
    }
    expect(inRow(s.dnsConfiguration, Icons.chevron_right_rounded), findsOne);
    expect(inRow(s.deleteAccount, Icons.chevron_right_rounded), findsNothing);
    expect(
      tester.widget<Text>(find.text(s.deleteAccount)).style?.color,
      AppDesign.error,
    );
  });

  testWidgets('the version is in the language\'s own digits', (tester) async {
    await pump(tester, locale: 'fa');
    expect(find.textContaining('۱.۱۱.۰'), findsOneWidget);
    expect(find.textContaining('1.11.0'), findsNothing);
  });

  for (final locale in ['fa', 'ar', 'ur']) {
    testWidgets('[$locale] the footer\'s words keep the 12.5sp floor', (
      tester,
    ) async {
      final s = await pump(tester, locale: locale);
      for (final words in [s.copyright, s.openSourceLicence]) {
        final style = tester.widget<Text>(find.text(words)).style;
        expect(style?.fontSize, greaterThanOrEqualTo(12.5), reason: words);
        expect(style?.color, AppDesign.textTertiary, reason: words);
      }
    });
  }

  testWidgets('the delete confirmation starts on Keep my account', (
    tester,
  ) async {
    final s = await pump(tester);
    await tester.tap(find.text(s.deleteAccount));
    await tester.pumpAndSettle();
    final keep = find.ancestor(
      of: find.text(s.deleteAccountCancel),
      matching: find.byType(TextButton),
    );
    expect(tester.widget<TextButton>(keep).autofocus, isTrue);
    final focused = FocusManager.instance.primaryFocus?.context;
    expect(
      focused?.findAncestorWidgetOfExactType<TextButton>(),
      tester.widget<TextButton>(keep),
    );
    await tester.tap(keep);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  });
}
