import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/api/api_client.dart';
import 'package:fortiva_vpn/api/api_routes.dart';
import 'package:fortiva_vpn/api/billing_service.dart';
import 'package:fortiva_vpn/api/config_service.dart';
import 'package:fortiva_vpn/core/design_system.dart';
import 'package:fortiva_vpn/core/state/billing_state.dart';
import 'package:fortiva_vpn/core/state/dedicated_state.dart';
import 'package:fortiva_vpn/data/models/billing.dart';
import 'package:fortiva_vpn/l10n/generated/app_localizations.dart';
import 'package:fortiva_vpn/widgets/quota_card.dart';
import 'package:fortiva_vpn/widgets/redeem_code_dialog.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/app_theme.dart';

/// The "Enter a code" dialog.
///
/// Every refusal the backend can send has its own translated text, because
/// "that did not work" leaves a user with an expired key or a key that has
/// moved too often no idea what to do. And a key that worked must show on
/// the quota card at once: the dialog closes onto a card that says
/// Unlimited, not onto the old allowance until the next refresh.

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

/// Every reason the backend sends, and the English text for each.
const _reasons = {
  'invalid_code': 'That does not look like a code. Check it and try again.',
  'unknown_code': 'We do not know this code. Check it and try again.',
  'expired': 'This code has expired.',
  'revoked': 'This code is no longer valid.',
  'moved_too_often':
      'This key has moved between phones too often lately. Try again later.',
  'exhausted': 'This code has been used up.',
  'already_redeemed': 'This phone has already used this code.',
  'unmetered':
      'This phone already has unlimited data, so it does not need this code.',
  'unavailable': 'This is not available right now. Try again later.',
  // Premium is not sold to this device.
  'not_available': 'Premium is not available on this phone right now.',
};

/// The status each reason arrives with.
int _statusOf(String reason) => switch (reason) {
  'moved_too_often' || 'already_redeemed' => 409,
  'unavailable' => 503,
  _ => 422,
};

QuotaStatus _spent() => const QuotaStatus(
  unlimited: false,
  limitBytes: 100,
  usedBytes: 100,
  remainingBytes: 0,
  blocked: true,
);

class _FakeDedicated extends DedicatedState {
  int refreshes = 0;

  @override
  Future<void> refresh({bool? viaTunnel}) async {
    refreshes++;
  }
}

/// A backend whose redeem route answers [status] with [body].
BillingState _billing(int status, Object body, _FakeDedicated dedicated) =>
    BillingState(
      service: BillingService(
        client: ApiClient.forTest(
          direct: MockClient(
            (_) async => http.Response(
              jsonEncode(body),
              status,
              headers: {'content-type': 'application/json'},
            ),
          ),
        ),
      ),
      dedicated: dedicated,
      playBilling: () => null,
      deviceId: () async => 'DEV-1',
    );

/// A backend that counts the redeem calls it hears and refuses each one.
BillingState _counting(List<http.Request> heard, _FakeDedicated dedicated) =>
    BillingState(
      service: BillingService(
        client: ApiClient.forTest(
          direct: MockClient((request) async {
            heard.add(request);
            return http.Response(
              jsonEncode({'reason': 'unknown_code'}),
              422,
              headers: {'content-type': 'application/json'},
            );
          }),
        ),
      ),
      dedicated: dedicated,
      playBilling: () => null,
      deviceId: () async => 'DEV-1',
    );

/// A page with the quota card and a button that opens the dialog.
Widget _host(
  BillingState billing,
  DedicatedState dedicated, {
  String locale = 'en',
}) => MultiProvider(
  providers: [
    ChangeNotifierProvider<BillingState>.value(value: billing),
    ChangeNotifierProvider<DedicatedState>.value(value: dedicated),
  ],
  child: MaterialApp(
    localizationsDelegates: S.localizationsDelegates,
    supportedLocales: S.supportedLocales,
    locale: Locale(locale),
    home: Scaffold(
      body: Consumer<DedicatedState>(
        builder: (context, d, _) => Column(
          children: [
            if (d.quota != null) QuotaCard(quota: d.quota!),
            TextButton(
              onPressed: () => showRedeemCodeDialog(context),
              child: const Text('open'),
            ),
          ],
        ),
      ),
    ),
  ),
);

Future<void> _enter(WidgetTester tester, String code) async {
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField), code);
  await tester.pump();
  await tester.tap(find.widgetWithText(FilledButton, 'Apply'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ApiRelays.resetForTest();
  });

  group('every refusal has its own text', () {
    final l10n = lookupS(const Locale('en'));

    _reasons.forEach((reason, text) {
      test(reason, () {
        final e = BillingException(reason, statusCode: _statusOf(reason));
        expect(redeemFailureText(l10n, e), text);
      });
    });

    test('too many tries, whatever the reason says', () {
      expect(
        redeemFailureText(l10n, BillingException('anything', statusCode: 429)),
        'Too many tries. Wait a little and try again.',
      );
    });

    test('no route to the backend', () {
      expect(
        redeemFailureText(l10n, BillingException(BillingException.network)),
        'Could not reach the server. Check your connection and try again.',
      );
    });

    test('a reason the app does not know yet', () {
      expect(
        redeemFailureText(
          l10n,
          BillingException('something_new', statusCode: 422),
        ),
        'That code did not work. Check it and try again.',
      );
    });

    test('no two reasons share a text', () {
      final texts = {
        for (final r in _reasons.keys)
          redeemFailureText(l10n, BillingException(r, statusCode: 422)),
      };
      expect(texts, hasLength(_reasons.length));
    });

    for (final lang in _languages) {
      test('[$lang] every text is translated and names no number', () {
        final s = lookupS(Locale(lang));
        for (final reason in [
          ..._reasons.keys,
          BillingException.network,
          BillingException.rateLimited,
          'something_new',
        ]) {
          final text = redeemFailureText(
            s,
            BillingException(reason, statusCode: 422),
          );
          expect(text, isNotEmpty, reason: reason);
          expect(
            RegExp(r'\p{Nd}', unicode: true).hasMatch(text),
            isFalse,
            reason: '$reason: $text',
          );
        }
      });
    }
  });

  group('the dialog', () {
    for (final reason in _reasons.keys) {
      testWidgets('shows the text for $reason', (tester) async {
        final dedicated = _FakeDedicated()..adoptQuota(_spent());
        final billing = _billing(_statusOf(reason), {
          'detail': {'reason': reason, 'message': 'English from the server'},
        }, dedicated);
        await tester.pumpWidget(_host(billing, dedicated));

        await _enter(tester, 'K7QD-3MWX-9TZB-H2CF');

        expect(find.text(_reasons[reason]!), findsOneWidget);
        // The server's English is never shown.
        expect(find.text('English from the server'), findsNothing);
        // The dialog stays open so the code can be fixed.
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(dedicated.refreshes, 0);
      });
    }

    testWidgets('a key that works shows Unlimited on the quota card at once', (
      tester,
    ) async {
      final dedicated = _FakeDedicated()..adoptQuota(_spent());
      final billing = _billing(200, {
        'kind': 'premium',
        'premium': {'active': true, 'code': 'K7QD-3MWX-9TZB-H2CF'},
        'moved': false,
        'quota': {
          'unlimited': true,
          'limit_bytes': 0,
          'used_bytes': 0,
          'remaining_bytes': 0,
          'blocked': false,
        },
      }, dedicated);
      await tester.pumpWidget(_host(billing, dedicated));
      expect(find.text('Daily limit reached'), findsOneWidget);

      await _enter(tester, 'K7QD-3MWX-9TZB-H2CF');
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Premium is on. Enjoy unlimited data.'), findsOneWidget);
      expect(find.text('Unlimited data'), findsOneWidget);
      expect(find.text('Daily limit reached'), findsNothing);
      expect(dedicated.refreshes, 1);
      expect(billing.premium.active, isTrue);
    });

    testWidgets('the message after a key works is readable in the app\'s '
        'theme', (tester) async {
      // The theme had no snackbar style, so Material drew the text in the
      // dark colour it pairs with its own light bar, on the app's dark bar.
      final dedicated = _FakeDedicated();
      final billing = _billing(200, {
        'kind': 'premium',
        'premium': {'active': true, 'code': 'K7QD-3MWX-9TZB-H2CF'},
        'moved': false,
      }, dedicated);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<BillingState>.value(value: billing),
            ChangeNotifierProvider<DedicatedState>.value(value: dedicated),
          ],
          child: MaterialApp(
            theme: AppDesign.darkThemeForLocale(const Locale('fa')),
            localizationsDelegates: S.localizationsDelegates,
            supportedLocales: S.supportedLocales,
            locale: const Locale('fa'),
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showRedeemCodeDialog(context),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'K7QD-3MWX-9TZB-H2CF');
      await tester.pump();
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      final text = lookupS(const Locale('fa')).premiumNowOn;
      final shown = find.descendant(
        of: find.byType(SnackBar),
        matching: find.text(text),
      );
      expect(shown, findsOneWidget);
      final color =
          tester.widget<Text>(shown).style?.color ??
          DefaultTextStyle.of(tester.element(shown)).style.color;
      expect(color, AppDesign.textPrimary);
    });

    testWidgets('a key from another phone says it moved', (tester) async {
      final dedicated = _FakeDedicated();
      final billing = _billing(200, {
        'kind': 'premium',
        'premium': {'active': true},
        'moved': true,
      }, dedicated);
      await tester.pumpWidget(_host(billing, dedicated));

      await _enter(tester, 'K7QD-3MWX-9TZB-H2CF');
      await tester.pumpAndSettle();

      expect(find.text('Premium moved to this phone.'), findsOneWidget);
    });

    testWidgets('a promo code names the data the backend says it added', (
      tester,
    ) async {
      final dedicated = _FakeDedicated();
      final billing = _billing(200, {
        'kind': 'promo',
        'bonus_bytes': 2 << 30,
        'premium': {'active': false},
        'moved': false,
      }, dedicated);
      await tester.pumpWidget(_host(billing, dedicated));

      await _enter(tester, 'WELCOME');
      await tester.pumpAndSettle();

      expect(
        find.text('Code accepted. 2 GB of extra data added.'),
        findsOneWidget,
      );
    });

    // The amount writes its decimal sign as the quota card does: the
    // momayyez between Persian digits, a point in English.
    testWidgets('a promo amount with a fraction writes the language\'s '
        'decimal sign', (tester) async {
      const result = RedeemResult(kind: 'promo', bonusBytes: 3 << 29);
      final texts = <String, String>{};
      for (final locale in const ['en', 'fa']) {
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: S.localizationsDelegates,
            supportedLocales: S.supportedLocales,
            locale: Locale(locale),
            home: Builder(
              builder: (context) {
                texts[locale] = redeemSuccessText(context, result);
                return const SizedBox();
              },
            ),
          ),
        );
      }
      expect(texts['en'], 'Code accepted. 1.5 GB of extra data added.');
      expect(texts['fa'], contains('۱\u066B۵ GB'));
      expect(texts['fa'], isNot(contains('۱.۵')));
    });

    testWidgets('a promo code with no amount names none', (tester) async {
      final dedicated = _FakeDedicated();
      final billing = _billing(200, {
        'kind': 'promo',
        'premium': {'active': false},
      }, dedicated);
      await tester.pumpWidget(_host(billing, dedicated));

      await _enter(tester, 'WELCOME');
      await tester.pumpAndSettle();

      expect(find.text('Code accepted. Extra data added.'), findsOneWidget);
    });

    testWidgets('takes letters, digits, dashes and spaces, in capitals', (
      tester,
    ) async {
      final dedicated = _FakeDedicated();
      await tester.pumpWidget(_host(_billing(200, {}, dedicated), dedicated));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // Persian digits from a Persian keyboard become Latin ones.
      await tester.enterText(find.byType(TextField), 'k7qd-۳mwx 9tzb@h2cf!');
      await tester.pump();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'K7QD-3MWX 9TZBH2CF',
      );
    });

    testWidgets('takes at most 32 characters', (tester) async {
      final dedicated = _FakeDedicated();
      await tester.pumpWidget(_host(_billing(200, {}, dedicated), dedicated));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'A' * 40);
      await tester.pump();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'A' * 32,
      );
    });

    testWidgets('Apply waits for at least 4 letters or digits', (tester) async {
      final dedicated = _FakeDedicated();
      await tester.pumpWidget(_host(_billing(200, {}, dedicated), dedicated));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      final apply = find.widgetWithText(FilledButton, 'Apply');

      await tester.enterText(find.byType(TextField), 'AB- C');
      await tester.pump();
      expect(tester.widget<FilledButton>(apply).onPressed, isNull);

      await tester.enterText(find.byType(TextField), 'AB-CD');
      await tester.pump();
      expect(tester.widget<FilledButton>(apply).onPressed, isNotNull);
    });
  });

  // While a code is being sent nothing goes disabled, because a disabled
  // button loses a TV remote's focus. Taps then do nothing.
  testWidgets('every button stays enabled while the code is sent, and a '
      'tap then does nothing', (tester) async {
    final heard = <http.Request>[];
    final answer = Completer<void>();
    var reads = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.getData') reads++;
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );
    final dedicated = _FakeDedicated();
    final billing = BillingState(
      service: BillingService(
        client: ApiClient.forTest(
          direct: MockClient((request) async {
            heard.add(request);
            await answer.future;
            return http.Response(
              jsonEncode({
                'detail': {'reason': 'unknown_code'},
              }),
              422,
              headers: {'content-type': 'application/json'},
            );
          }),
        ),
      ),
      dedicated: dedicated,
      playBilling: () => null,
      deviceId: () async => 'DEV-1',
    );
    await tester.pumpWidget(_host(billing, dedicated));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'K7QD-3MWX');
    await tester.pump();
    final apply = find.byWidgetPredicate((w) => w is FilledButton);
    await tester.tap(apply);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(heard, hasLength(1));
    expect(
      find.descendant(
        of: apply,
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
    );
    expect(tester.widget<FilledButton>(apply).onPressed, isNotNull);
    final paste = find.byKey(const Key('redeem-paste'));
    expect(tester.widget<TextButton>(paste).onPressed, isNotNull);
    final cancel = find.widgetWithText(TextButton, 'Cancel');
    expect(tester.widget<TextButton>(cancel).onPressed, isNotNull);

    await tester.tap(apply);
    await tester.tap(paste);
    await tester.tap(cancel);
    await tester.pump();
    expect(heard, hasLength(1));
    expect(reads, 0);
    expect(find.byType(AlertDialog), findsOneWidget);

    answer.complete();
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(
      find.text('We do not know this code. Check it and try again.'),
      findsOneWidget,
    );
  });

  // Paste reads the clipboard only when it is tapped, puts the code it
  // finds in the field, and sends nothing until Apply.
  group('Paste', () {
    late int reads;
    late String? clipboard;

    setUp(() {
      reads = 0;
      clipboard = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'Clipboard.getData') {
              reads++;
              return {'text': clipboard};
            }
            return null;
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    testWidgets('fills the field with the key from a message, and sends '
        'nothing', (tester) async {
      clipboard = 'My key: k7qd-\u06F3mwx-9tzb-h2cf, keep it safe';
      final heard = <http.Request>[];
      final dedicated = _FakeDedicated();
      await tester.pumpWidget(_host(_counting(heard, dedicated), dedicated));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(reads, 0, reason: 'nothing reads the clipboard before the tap');
      expect(find.byType(TextField), findsOneWidget);

      await tester.tap(find.byKey(const Key('redeem-paste')));
      await tester.pumpAndSettle();
      expect(reads, 1);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'K7QD-3MWX-9TZB-H2CF',
      );
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(heard, isEmpty);
      final apply = find.widgetWithText(FilledButton, 'Apply');
      expect(tester.widget<FilledButton>(apply).onPressed, isNotNull);
    });

    testWidgets('with no code on the clipboard, says so', (tester) async {
      clipboard = 'hi';
      final dedicated = _FakeDedicated();
      await tester.pumpWidget(_host(_counting([], dedicated), dedicated));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('redeem-paste')));
      await tester.pumpAndSettle();
      expect(
        find.text('That does not look like a code. Check it and try again.'),
        findsOneWidget,
      );
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
    });
  });

  group('the code found in pasted text', () {
    test('is the longest run of letters and digits joined by dashes', () {
      expect(
        redeemCodeIn('Your key K7QD-3MWX-9TZB-H2CF. Enter it soon.'),
        'K7QD-3MWX-9TZB-H2CF',
      );
      expect(redeemCodeIn('spring24'), 'SPRING24');
    });

    test('folds Persian and Arabic digits and keeps to 32 characters', () {
      expect(redeemCodeIn('\u06F1\u06F2\u0663\u0664AB'), '1234AB');
      expect(redeemCodeIn('A' * 40), 'A' * 32);
    });

    test('is nothing when no run is long enough to send', () {
      expect(redeemCodeIn('ok go'), isNull);
      expect(redeemCodeIn(''), isNull);
    });

    test('is a run that looks like a code before a longer word', () {
      expect(redeemCodeIn('Congratulations, your code is WELCOME'), 'WELCOME');
      expect(redeemCodeIn('Congratulations! Use SPRING24 today'), 'SPRING24');
      expect(redeemCodeIn('Welcome aboard: ab-cd'), 'AB-CD');
      // With nothing like a code, still the longest run.
      expect(redeemCodeIn('please welcome'), 'WELCOME');
    });
  });

  // The field holds a code, which reads left to right in the middle of the
  // field in every language, in monospace. What goes in it is words in the
  // app's own font, which monospace and letter spacing pulled apart: a
  // label on the field's top edge, so the centred caret does not cross it.
  testWidgets('the code is monospace and the label is in the app font', (
    tester,
  ) async {
    final dedicated = _FakeDedicated();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<BillingState>.value(
            value: _billing(200, {}, dedicated),
          ),
          ChangeNotifierProvider<DedicatedState>.value(value: dedicated),
        ],
        child: MaterialApp(
          localizationsDelegates: S.localizationsDelegates,
          supportedLocales: S.supportedLocales,
          locale: const Locale('fa'),
          theme: appThemeFor(const Locale('fa')),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showRedeemCodeDialog(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.textDirection, TextDirection.ltr);
    expect(field.textAlign, TextAlign.center);
    expect(field.style?.fontFamily, 'monospace');
    // A code is Latin in every language, so it keeps its spacing in
    // Persian too.
    expect(field.style?.letterSpacing, greaterThan(0));
    final decoration = field.decoration!;
    expect(decoration.hintText, isNull);
    expect(decoration.labelText, 'کد');
    expect(decoration.floatingLabelBehavior, FloatingLabelBehavior.always);
    expect(decoration.labelStyle?.fontFamily, 'Vazirmatn');
    expect(decoration.labelStyle?.letterSpacing, 0);
    expect(decoration.labelStyle?.locale, const Locale('fa'));
  });
}
