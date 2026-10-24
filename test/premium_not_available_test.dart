import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/api/api_client.dart';
import 'package:fortiva_vpn/api/api_routes.dart';
import 'package:fortiva_vpn/api/billing_service.dart';
import 'package:fortiva_vpn/core/state/billing_state.dart';
import 'package:fortiva_vpn/core/state/dedicated_state.dart';
import 'package:fortiva_vpn/l10n/generated/app_localizations.dart';
import 'package:fortiva_vpn/screens/premium_screen.dart';
import 'package:fortiva_vpn/services/play_billing.dart';
import 'package:fortiva_vpn/widgets/redeem_code_dialog.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The refusal `not_available`: Premium is not sold to this device.
/// Redeem and Google Play can both send it (422).
///
/// Every place that shows a refusal has its own translated text for it,
/// instead of "that did not work" or "try again", which would send the
/// user round the same refusal. The Google Play line also says what to do
/// if the user was charged.

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

const _text = 'Premium is not available on this phone right now.';
const _playText =
    'Premium is not available on this phone right now. If you were charged, '
    'contact support.';

/// What GET .../billing answers, as the backend writes it.
const _infoJson = {
  'enabled': true,
  'premium': {'active': false},
  'plans': [
    {
      'code': 'unlimited_30d',
      'days': 30,
      'google': {'product_id': 'premium', 'base_plan_id': 'p30'},
    },
  ],
  'rails': {'google_play': true, 'codes': true},
};

/// A backend that answers GET .../billing and refuses every payment call
/// with not_available.
ApiClient _refusingBackend() => ApiClient.forTest(
  direct: MockClient((request) async {
    final load =
        request.method == 'GET' && request.url.path.endsWith('/billing');
    return http.Response(
      jsonEncode(
        load
            ? _infoJson
            : {
                'detail': {'reason': 'not_available', 'message': 'Not here'},
              },
      ),
      load ? 200 : 422,
      headers: {'content-type': 'application/json'},
    );
  }),
);

class _FakePlay implements PlayBilling {
  final controller = StreamController<List<PlayPurchase>>.broadcast();
  List<PlayPurchase> holding = const [];
  final completed = <String>[];

  @override
  Stream<List<PlayPurchase>> get purchases => controller.stream;
  @override
  Future<bool> isAvailable() async => true;
  @override
  Future<List<PlayProduct>> products(Set<String> productIds) async => const [
    PlayProduct(productId: 'premium', basePlanId: 'p30', price: 'EUR 4,99'),
  ];
  @override
  Future<bool> buy(PlayProduct product, {required String accountId}) async =>
      true;
  @override
  Future<void> complete(PlayPurchase purchase) async =>
      completed.add(purchase.token);
  @override
  Future<List<PlayPurchase>> owned() async => holding;
}

class _FakeDedicated extends DedicatedState {
  @override
  Future<void> refresh({bool? viaTunnel}) async {}
}

BillingState _billing({PlayBilling? play}) => BillingState(
  service: BillingService(client: _refusingBackend()),
  playBilling: () => play,
  googleSigned: () async => true,
  deviceId: () async => 'DEV-1',
)..adoptWorkedForTest();

Widget _app(BillingState billing, Widget home) => MultiProvider(
  providers: [
    ChangeNotifierProvider<BillingState>.value(value: billing),
    ChangeNotifierProvider<DedicatedState>.value(value: _FakeDedicated()),
  ],
  child: MaterialApp(
    localizationsDelegates: S.localizationsDelegates,
    supportedLocales: S.supportedLocales,
    locale: const Locale('en'),
    home: home,
  ),
);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ApiRelays.resetForTest();
  });

  group('the texts', () {
    final en = lookupS(const Locale('en'));

    test('the code dialog has its own text for it', () {
      expect(
        redeemFailureText(
          en,
          BillingException(BillingException.notAvailable, statusCode: 422),
        ),
        _text,
      );
    });

    for (final lang in _languages) {
      test('[$lang] both texts are translated and name no number', () {
        final s = lookupS(Locale(lang));
        for (final (text, english) in [
          (s.premiumNotAvailable, en.premiumNotAvailable),
          (s.premiumPlayNotAvailable, en.premiumPlayNotAvailable),
        ]) {
          expect(text.trim(), isNotEmpty);
          if (lang != 'en') expect(text, isNot(english), reason: text);
          expect(
            RegExp(r'\p{Nd}', unicode: true).hasMatch(text),
            isFalse,
            reason: text,
          );
          expect(text, isNot(contains('\u2014')), reason: text);
          expect(text, isNot(contains('\u2013')), reason: text);
        }
        // Not the text for a backend that is down, which says to try
        // again later.
        expect(s.premiumNotAvailable, isNot(s.redeemUnavailable));
      });
    }
  });

  group('Google Play', () {
    testWidgets('a purchase refused as not available says so, and what to '
        'do if the user was charged', (tester) async {
      final play = _FakePlay();
      final billing = _billing(play: play);
      await tester.runAsync(billing.refresh);
      await tester.pumpWidget(_app(billing, const PremiumScreen()));
      await tester.pump();
      expect(find.text('EUR 4,99'), findsOneWidget);

      await tester.runAsync(() async {
        play.controller.add(const [
          PlayPurchase(
            productId: 'premium',
            token: 'token-1',
            status: PlayPurchaseStatus.purchased,
            needsCompleting: true,
          ),
        ]);
        await pumpEventQueue();
      });
      await tester.pump();

      expect(billing.playFlow, PlayFlow.notAvailable);
      expect(find.text(_playText), findsOneWidget);
      expect(
        find.text(
          'We could not confirm this purchase. If you were charged, contact '
          'support.',
        ),
        findsNothing,
      );
      expect(play.completed, isEmpty);
    });

    testWidgets('Restore refused as not available says so', (tester) async {
      final play = _FakePlay()
        ..holding = const [
          PlayPurchase(
            productId: 'premium',
            token: 'token-2',
            status: PlayPurchaseStatus.purchased,
          ),
        ];
      final billing = _billing(play: play);
      await tester.runAsync(billing.refresh);
      await tester.pumpWidget(_app(billing, const PremiumScreen()));
      await tester.pump();

      await tester.tap(find.text('Restore purchases'));
      await tester.runAsync(pumpEventQueue);
      await tester.pump();

      expect(find.text(_text), findsOneWidget);
      expect(
        find.text('Could not restore your purchase. Try again later.'),
        findsNothing,
      );
    });
  });
}
