import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/core/state/app_config_state.dart';
import 'package:fortiva_vpn/core/state/locale_state.dart';
import 'package:fortiva_vpn/core/state/referral_state.dart';
import 'package:fortiva_vpn/data/models/app_config.dart';
import 'package:fortiva_vpn/l10n/generated/app_localizations.dart';
import 'package:fortiva_vpn/screens/settings_screen.dart';
import 'package:fortiva_vpn/widgets/kill_switch_row.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/app_theme.dart';

/// The Settings row about Android's own block of connections without a
/// VPN: shown only when the backend turns it on, on Android 8.0 and later,
/// and it only opens the steps and Android's VPN settings.
Future<AppConfigState> _config({required bool on}) async {
  final config = AppConfigState(
    fetch: () async => AppConfig.fromJson({
      'privacy_policy_url': 'https://example.com/privacy',
      'terms_of_service_url': 'https://example.com/terms',
      'eula_url': 'https://example.com/eula',
      'support_email': 'support@example.com',
      'force_update': {
        for (final os in ['ios', 'android'])
          os: {
            'latest_version': '1.0.0',
            'minimum_version': '1.0.0',
            'update_url': 'https://example.com/update',
          },
      },
      'feature_flags': {'enable_kill_switch': on},
    }),
    retryGaps: const [],
  );
  await config.load();
  return config;
}

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
  tearDown(() => KillSwitchStatus.sdkIntForTest = null);

  Future<S> pumpRow(
    WidgetTester tester, {
    required AppConfigState config,
    Future<int> Function()? sdk,
    bool shown = true,
    Future<bool> Function()? open,
    String locale = 'en',
  }) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<AppConfigState>.value(
        value: config,
        child: MaterialApp(
          locale: Locale(locale),
          theme: appThemeFor(Locale(locale)),
          localizationsDelegates: S.localizationsDelegates,
          supportedLocales: S.supportedLocales,
          home: Scaffold(
            body: KillSwitchStatus(
              shown: () => shown,
              sdkInt: sdk ?? () async => 26,
              openSettings: open ?? () async => true,
              builder: (context, openSheet) => ListTile(
                title: Text(S.of(context)!.killSwitchTitle),
                subtitle: Text(S.of(context)!.killSwitchSubtitle),
                onTap: openSheet,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return lookupS(Locale(locale));
  }

  testWidgets('hidden unless the backend turns it on', (tester) async {
    final s = await pumpRow(tester, config: await _config(on: false));
    expect(find.text(s.killSwitchTitle), findsNothing);
  });

  testWidgets('shown with the flag on, on Android 8.0', (tester) async {
    final s = await pumpRow(tester, config: await _config(on: true));
    expect(find.text(s.killSwitchTitle), findsOneWidget);
    expect(find.text(s.killSwitchSubtitle), findsOneWidget);
  });

  testWidgets('hidden below Android 8.0, when the version cannot be read, '
      'and where it is not shown', (tester) async {
    final config = await _config(on: true);
    var s = await pumpRow(tester, config: config, sdk: () async => 25);
    expect(find.text(s.killSwitchTitle), findsNothing);
    s = await pumpRow(
      tester,
      config: config,
      sdk: () async => throw StateError('no answer'),
    );
    expect(find.text(s.killSwitchTitle), findsNothing);
    s = await pumpRow(tester, config: config, shown: false);
    expect(find.text(s.killSwitchTitle), findsNothing);
  });

  testWidgets('a tap opens the steps, and the button opens Android\'s VPN '
      'settings and changes nothing else', (tester) async {
    var opened = 0;
    final s = await pumpRow(
      tester,
      config: await _config(on: true),
      open: () async {
        opened++;
        return true;
      },
    );
    final prefs = await SharedPreferences.getInstance();
    final before = {for (final k in prefs.getKeys()) k: prefs.get(k)};
    await tester.tap(find.text(s.killSwitchTitle));
    await tester.pumpAndSettle();
    expect(find.text(s.killSwitchSteps), findsOneWidget);
    expect(find.text(s.killSwitchUndo), findsOneWidget);
    await tester.tap(find.text(s.openVpnSettings));
    await tester.pumpAndSettle();
    expect(opened, 1);
    expect({for (final k in prefs.getKeys()) k: prefs.get(k)}, before);
  });

  for (final locale in ['en', 'de', 'fa', 'ur']) {
    testWidgets('[$locale] the sheet fits a small phone with large text', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final s = await pumpRow(
        tester,
        config: await _config(on: true),
        locale: locale,
      );
      await tester.tap(find.text(s.killSwitchTitle));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text(s.openVpnSettings), findsOneWidget);
    });
  }

  testWidgets('in Settings it sits under the DNS row, and Settings keeps '
      'one switch', (tester) async {
    tester.view.physicalSize = const Size(400, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    KillSwitchStatus.sdkIntForTest = () async => 30;
    final config = await _config(on: true);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AppConfigState>.value(value: config),
          ChangeNotifierProvider<LocaleState>(create: (_) => LocaleState()),
          ChangeNotifierProvider<ReferralState>(create: (_) => ReferralState()),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          theme: appThemeFor(const Locale('en')),
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
    final s = lookupS(const Locale('en'));
    expect(find.text(s.killSwitchTitle), findsOneWidget);
    final dns = tester.getTopLeft(find.text(s.dnsConfiguration)).dy;
    final row = tester.getTopLeft(find.text(s.killSwitchTitle)).dy;
    final peer = tester.getTopLeft(find.text(s.peerShareTitle)).dy;
    expect(dns < row && row < peer, isTrue);
    expect(find.byType(Switch), findsOneWidget);
  });
}
