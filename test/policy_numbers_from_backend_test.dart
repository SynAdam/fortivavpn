import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/api/referral_service.dart';
import 'package:fortiva_vpn/core/state/app_config_state.dart';
import 'package:fortiva_vpn/core/state/locale_state.dart';
import 'package:fortiva_vpn/core/state/referral_state.dart';
import 'package:fortiva_vpn/data/models/app_config.dart';
import 'package:fortiva_vpn/l10n/generated/app_localizations.dart';
import 'package:fortiva_vpn/screens/invite_screen.dart';
import 'package:fortiva_vpn/screens/settings_screen.dart';
import 'package:fortiva_vpn/widgets/invite_code_dialog.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The claim window, the qualifying days and the retention period are
/// rules the backend sets. The app shows them only as the backend sends
/// them, and names no number when it sends none, so changing a rule never
/// needs an app release. The app used to say 72 hours, "a couple of days"
/// and 30 days on its own.
///
/// test/no_policy_numbers_test.dart checks the text itself. These tests
/// check the behaviour: the backend's number reaches the screen, and with
/// no number from the backend no digit is shown, in all 12 languages.

const _languages = [
  'ar',
  'de',
  'en',
  'es',
  'fa',
  'fr',
  'hi',
  'id',
  'ja',
  'ko',
  'pt',
  'ru',
  'tr',
  'uk',
  'ur',
  'uz',
  'vi',
  'zh',
];

final _digit = RegExp(r'\p{Nd}', unicode: true);

/// Japanese writes "per day" as 1日の or 1日最大. That names the window the
/// allowance refills in, not a rule, and no_policy_numbers_test.dart lets
/// it through for the same reason.
final _jaPerDay = RegExp(r'[1１一]\s?日(?=\s*(?:の|最大))', unicode: true);

bool _hasDigit(String text) => _digit.hasMatch(text.replaceAll(_jaPerDay, ''));

/// A code with no digits, so a digit on screen can only come from a rule.
ReferralStatus _status({
  int? claimWindowHours,
  int? confirmActiveDays,
  int? perReferral,
}) => ReferralStatus(
  code: 'ABCDEF',
  shareUrl: 'https://fortivavpn.com/i/ABCDEF',
  invitedCount: 0,
  confirmedCount: 0,
  bonusBytes: 0,
  bonusPerReferralBytes: perReferral,
  claimWindowHours: claimWindowHours,
  confirmActiveDays: confirmActiveDays,
);

class _FakeReferral extends ReferralState {
  ReferralStatus? _fixed;
  _FakeReferral(this._fixed);

  /// What the status reads after a successful claim, as the real state
  /// reloads it then.
  ReferralStatus? afterClaim;

  @override
  ReferralStatus? get status => _fixed;

  @override
  bool get isLoading => false;

  @override
  Future<void> refresh() async {}

  @override
  Future<ReferralClaimResult> claim(
    String code, {
    String source = 'manual',
  }) async {
    if (afterClaim != null) _fixed = afterClaim;
    return const ReferralClaimResult.ok();
  }
}

/// An app config state that never fetches, with a fixed retention period.
/// Null is a phone that has no config from the backend yet.
class _FixedConfig extends AppConfigState {
  _FixedConfig(this._days)
    : super(fetch: () async => throw StateError('no fetch in tests'));

  final int? _days;

  @override
  int? get deletedDataRetentionDays => _days;
}

Map<String, dynamic> _configJson(Object? retention) => {
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
  'deleted_data_retention_days': ?retention,
};

Widget _app(Widget home, {String locale = 'en', ReferralState? referral}) =>
    ChangeNotifierProvider<ReferralState>.value(
      value: referral ?? _FakeReferral(null),
      child: MaterialApp(
        localizationsDelegates: S.localizationsDelegates,
        supportedLocales: S.supportedLocales,
        locale: Locale(locale),
        home: home,
      ),
    );

/// Every Text on screen, except the two invite counts, which come from
/// the backend and are not rules.
List<String> _texts(WidgetTester tester) => [
  for (final w in tester.widgetList<Text>(find.byType(Text)))
    if (w.data != null &&
        !RegExp(r'^\p{Nd}+$', unicode: true).hasMatch(w.data!))
      w.data!,
];

/// The text a helper returns in [locale].
Future<String> _textIn(
  WidgetTester tester,
  String locale,
  String Function(BuildContext) build,
) async {
  late String text;
  await tester.pumpWidget(
    _app(
      Builder(
        builder: (context) {
          text = build(context);
          return const SizedBox();
        },
      ),
      locale: locale,
    ),
  );
  return text;
}

void main() {
  group('parsing', () {
    ReferralStatus parse(Map<String, dynamic> extra) =>
        ReferralStatus.fromJson({'code': 'ABCDEF', ...extra});

    test('the referral status reads both rules', () {
      final s = parse({'claim_window_hours': 48, 'confirm_active_days': 3});
      expect(s.claimWindowHours, 48);
      expect(s.confirmActiveDays, 3);
    });

    test('an older backend that sends neither gives null', () {
      final s = parse({});
      expect(s.claimWindowHours, isNull);
      expect(s.confirmActiveDays, isNull);
    });

    for (final bad in <Object>[0, -5, '72', 72.5, 72.0, true]) {
      test('$bad (${bad.runtimeType}) reads as null', () {
        final s = parse({
          'claim_window_hours': bad,
          'confirm_active_days': bad,
        });
        expect(s.claimWindowHours, isNull);
        expect(s.confirmActiveDays, isNull);
      });
    }

    test('the app config reads the retention period', () {
      expect(AppConfig.fromJson(_configJson(14)).deletedDataRetentionDays, 14);
      expect(
        AppConfig.fromJson(_configJson(null)).deletedDataRetentionDays,
        isNull,
      );
    });

    for (final bad in <Object>[0, -1, '30', 30.5, false]) {
      test('a retention of $bad reads as null and keeps the config', () {
        final config = AppConfig.fromJson(_configJson(bad));
        expect(config.deletedDataRetentionDays, isNull);
        expect(config.privacyPolicyUrl, 'https://example.com/privacy');
      });
    }

    test('the retention period survives a round trip', () {
      final config = AppConfig.fromJson(_configJson(21));
      expect(AppConfig.fromJson(config.toJson()).deletedDataRetentionDays, 21);
    });
  });

  group('invite screen', () {
    Future<void> pump(
      WidgetTester tester,
      ReferralStatus status, {
      String locale = 'en',
    }) async {
      // Tall enough for the whole screen, down to the have-code tile at the
      // end: the texts are read from what is on screen.
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _app(
          const InviteScreen(),
          locale: locale,
          referral: _FakeReferral(status),
        ),
      );
      await tester.pump();
    }

    testWidgets('names the claim window the backend sends', (tester) async {
      await pump(tester, _status(claimWindowHours: 48));
      expect(find.text('Enter it in your first 48 hours'), findsOneWidget);
    });

    testWidgets('a one-hour window reads in the singular', (tester) async {
      await pump(tester, _status(claimWindowHours: 1));
      expect(find.text('Enter it in your first hour'), findsOneWidget);
    });

    testWidgets('without a window, names no number', (tester) async {
      await pump(tester, _status());
      expect(find.text('Enter it soon after installing'), findsOneWidget);
      expect(find.textContaining('72'), findsNothing);
    });

    testWidgets('names the qualifying days the backend sends', (tester) async {
      await pump(tester, _status(confirmActiveDays: 2, perReferral: 1 << 30));
      expect(
        find.text(
          'Share your code. When someone installs the app, enters it, and '
          'uses the VPN on 2 different days, you get 1\u00A0GB added to your '
          'daily data. It stays on your account.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('days without an amount', (tester) async {
      await pump(tester, _status(confirmActiveDays: 3));
      expect(
        find.textContaining('on 3 different days, you get more data every day'),
        findsOneWidget,
      );
    });

    testWidgets('without days, names no number of days', (tester) async {
      await pump(tester, _status());
      expect(find.textContaining('uses the VPN for a while'), findsOneWidget);
      expect(find.textContaining('couple'), findsNothing);
    });

    testWidgets('Persian shows the window and the days in Persian digits', (
      tester,
    ) async {
      await pump(
        tester,
        _status(claimWindowHours: 72, confirmActiveDays: 2),
        locale: 'fa',
      );
      expect(find.text('آن را در ۷۲ ساعت اول وارد کنید'), findsOneWidget);
      expect(find.textContaining('در ۲ روز مختلف'), findsOneWidget);
    });

    testWidgets('Arabic uses the dual for two days', (tester) async {
      await pump(
        tester,
        _status(claimWindowHours: 72, confirmActiveDays: 2),
        locale: 'ar',
      );
      expect(find.text('أدخله خلال أول ٧٢ ساعة'), findsOneWidget);
      expect(find.textContaining('في يومين مختلفين'), findsOneWidget);
    });

    testWidgets('Russian picks the plural form for the number', (tester) async {
      await pump(
        tester,
        _status(claimWindowHours: 72, confirmActiveDays: 5),
        locale: 'ru',
      );
      expect(
        find.text('Введите его в течение 72 часов после установки'),
        findsOneWidget,
      );
      expect(find.textContaining('в 5 разных дней'), findsOneWidget);
    });

    for (final locale in _languages) {
      testWidgets('[$locale] with no rules from the backend, no digit', (
        tester,
      ) async {
        await pump(tester, _status(), locale: locale);
        final withDigits = _texts(tester).where(_hasDigit).toList();
        expect(withDigits, isEmpty);
      });
    }
  });

  group('invite code dialog', () {
    testWidgets('opened from the invite screen, shows the window and '
        'confirms with the days', (tester) async {
      final referral = _FakeReferral(
        _status(claimWindowHours: 24, confirmActiveDays: 4),
      );
      await tester.pumpWidget(_app(const InviteScreen(), referral: referral));
      await tester.pump();

      // The tile is last on the screen, laid out below the fold.
      await tester.ensureVisible(
        find.text('Have an invite code?', skipOffstage: false),
      );
      await tester.pump();
      await tester.tap(find.text('Have an invite code?'));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Enter it in your first 24 hours'),
        ),
        findsOneWidget,
      );

      await tester.enterText(find.byType(TextField), 'XYZWVU');
      // Apply turns on with the frame after the field gets text.
      await tester.pump();
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Invite accepted. Your friend earns bonus data once you have '
          'used the VPN on 4 different days.',
        ),
        findsOneWidget,
      );
    });

    // The dialog is public. Opened before the status has loaded, it must
    // not fall back to a number of its own.
    for (final locale in _languages) {
      testWidgets('[$locale] opened with no status, names no number', (
        tester,
      ) async {
        await tester.pumpWidget(
          _app(
            Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showInviteCodeDialog(context),
                  child: const Text('open'),
                ),
              ),
            ),
            locale: locale,
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        expect(_texts(tester).where(_hasDigit), isEmpty);

        await tester.enterText(find.byType(TextField), 'XYZWVU');
        await tester.pump();
        await tester.tap(find.byType(FilledButton));
        await tester.pumpAndSettle();
        expect(find.byType(SnackBar), findsOneWidget);
        expect(_texts(tester).where(_hasDigit), isEmpty);
      });
    }

    testWidgets('the confirmation reads the status the claim reloaded', (
      tester,
    ) async {
      final referral = _FakeReferral(null)
        ..afterClaim = _status(confirmActiveDays: 2);
      await tester.pumpWidget(
        _app(
          Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showInviteCodeDialog(context),
                child: const Text('open'),
              ),
            ),
          ),
          locale: 'fa',
          referral: referral,
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('آن را کمی پس از نصب وارد کنید'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'XYZWVU');
      await tester.pump();
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      expect(find.textContaining('در ۲ روز مختلف'), findsOneWidget);
    });
  });

  group('delete-account retention line', () {
    testWidgets('names the days the backend sends', (tester) async {
      expect(
        await _textIn(tester, 'en', (c) => deleteAccountRetentionText(c, 14)),
        'Your account record is removed immediately. Copies in backups and '
        'anonymous server logs are cleared within 14 days.',
      );
    });

    testWidgets('one day reads in the singular', (tester) async {
      expect(
        await _textIn(tester, 'en', (c) => deleteAccountRetentionText(c, 1)),
        endsWith('cleared within 1 day.'),
      );
    });

    testWidgets('Persian and Arabic digits', (tester) async {
      expect(
        await _textIn(tester, 'fa', (c) => deleteAccountRetentionText(c, 30)),
        contains('ظرف ۳۰ روز'),
      );
      expect(
        await _textIn(tester, 'ar', (c) => deleteAccountRetentionText(c, 30)),
        contains('خلال ٣٠ يومًا'),
      );
    });

    for (final locale in _languages) {
      testWidgets('[$locale] without days, names no number', (tester) async {
        final text = await _textIn(
          tester,
          locale,
          (c) => deleteAccountRetentionText(c, null),
        );
        expect(text, isNotEmpty);
        expect(_hasDigit(text), isFalse);
      });
    }
  });

  // The confirmation opened from the real Settings screen, so a number
  // written into settings_screen.dart fails here, not only in the helper.
  group('delete-account confirmation in Settings', () {
    /// Every Text in the confirmation dialog.
    Future<List<String>> dialogTexts(
      WidgetTester tester,
      int? days, {
      String locale = 'en',
    }) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AppConfigState>.value(
              value: _FixedConfig(days),
            ),
            ChangeNotifierProvider<LocaleState>(create: (_) => LocaleState()),
          ],
          child: _app(const SettingsScreen(), locale: locale),
        ),
      );
      await tester.pumpAndSettle();
      final tile = find.text(lookupS(Locale(locale)).deleteAccount);
      await tester.scrollUntilVisible(
        tile,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      // scrollUntilVisible ends with an ensureVisible scroll that needs a
      // frame; without it the tap lands where the tile was, which in the
      // languages with a taller diagnostics tile is just off the screen.
      await tester.pumpAndSettle();
      await tester.tap(tile);
      await tester.pumpAndSettle();
      return [
        for (final w in tester.widgetList<Text>(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(Text),
          ),
        ))
          if (w.data != null) w.data!,
      ];
    }

    testWidgets('names the days the backend sends', (tester) async {
      final texts = await dialogTexts(tester, 14);
      expect(texts, contains(endsWith('cleared within 14 days.')));
    });

    for (final locale in _languages) {
      testWidgets('[$locale] with no config, names no number', (tester) async {
        final texts = await dialogTexts(tester, null, locale: locale);
        final l10n = lookupS(Locale(locale));
        expect(texts, contains(l10n.deleteAccountConfirmRetentionNoDays));
        expect(texts.where(_hasDigit), isEmpty);
      });
    }
  });
}
