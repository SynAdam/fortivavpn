import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/api/api_client.dart';
import 'package:fortiva_vpn/api/api_routes.dart';
import 'package:fortiva_vpn/api/billing_service.dart';
import 'package:fortiva_vpn/core/state/billing_state.dart';
import 'package:fortiva_vpn/core/state/dedicated_state.dart';
import 'package:fortiva_vpn/data/models/billing.dart';
import 'package:fortiva_vpn/l10n/generated/app_localizations.dart';
import 'package:fortiva_vpn/screens/premium_screen.dart';
import 'package:fortiva_vpn/services/play_billing.dart';
import 'package:fortiva_vpn/widgets/limit_sheet.dart';
import 'package:fortiva_vpn/widgets/premium_offers.dart';
import 'package:fortiva_vpn/widgets/redeem_code_dialog.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Prices, plan lengths and move limits on the Premium screens come from
/// the backend or from Google Play, never from the app (the rule in
/// test/no_policy_numbers_test.dart). Here the backend sends no number at
/// all, and the values it does send (a price, a key) hold no digit, so any
/// digit on screen would be one the app wrote itself. Every screen is drawn
/// in all 18 languages.
///
/// The Premium offers (the limit sheet, the calm card, the next-step card,
/// locked locations, the reminders) follow the same rule, and so does the
/// line a copy that cannot buy through Google Play shows. Their texts also
/// never name a way to pay outside Google Play, because every copy shows
/// them, and never use a dash in place of punctuation.

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

/// Every piece of text on screen, selectable text included.
List<String> _shown(WidgetTester tester) => [
  for (final w in tester.widgetList<Text>(find.byType(Text)))
    ?(w.data ?? w.textSpan?.toPlainText()),
  for (final w in tester.widgetList<SelectableText>(
    find.byType(SelectableText),
  ))
    ?(w.data ?? w.textSpan?.toPlainText()),
];

/// Premium with no end date and a key with no digit.
const _premium = Premium(
  active: true,
  source: 'voucher',
  autoRenewing: true,
  code: 'ABCD-EFGH-JKMN-PQRS',
);

/// A plan with no length.
const _plan = Plan(
  code: 'unlimited',
  google: PlayProductRef(productId: 'premium', basePlanId: 'base'),
);

class _IdlePlay implements PlayBilling {
  @override
  Stream<List<PlayPurchase>> get purchases => const Stream.empty();
  @override
  Future<bool> isAvailable() async => true;
  @override
  Future<List<PlayProduct>> products(Set<String> productIds) async => const [];
  @override
  Future<bool> buy(PlayProduct product, {required String accountId}) async =>
      true;
  @override
  Future<void> complete(PlayPurchase purchase) async {}
  @override
  Future<List<PlayPurchase>> owned() async => const [];
}

class _FixedBilling extends BillingState {
  _FixedBilling(
    BillingInfo info, {
    bool googleSigned = true,
    List<PlayProduct> products = const [
      PlayProduct(productId: 'premium', basePlanId: 'base', price: 'X'),
    ],
  }) : super(
         service: BillingService(
           client: ApiClient.forTest(
             direct: MockClient((_) async => throw http.ClientException('no')),
           ),
         ),
         playBilling: () => _IdlePlay(),
         deviceId: () async => 'DEVICE',
       ) {
    adoptForTest(info, products: products, googleSigned: googleSigned);
    adoptWorkedForTest();
  }

  @override
  Future<void> refresh() async {}
}

class _FakeDedicated extends DedicatedState {
  @override
  Future<void> refresh({bool? viaTunnel}) async {}
}

Widget _app(BillingState billing, Widget home, String locale) => MultiProvider(
  providers: [
    ChangeNotifierProvider<BillingState>.value(value: billing),
    ChangeNotifierProvider<DedicatedState>.value(value: _FakeDedicated()),
  ],
  child: MaterialApp(
    localizationsDelegates: S.localizationsDelegates,
    supportedLocales: S.supportedLocales,
    locale: Locale(locale),
    home: home,
  ),
);

/// Every text the Premium offers added, with each placeholder filled by a
/// word that holds no digit.
List<String> _offerTexts(S l10n) => [
  l10n.premiumNotNow,
  l10n.premiumLimitSheetTitle,
  l10n.premiumLimitWait,
  l10n.premiumLimitInvite,
  l10n.premiumNoDailyLimit,
  l10n.premiumCalmTitle,
  l10n.premiumCalmBody,
  l10n.premiumNextStepTitle,
  l10n.premiumNextStepBody,
  l10n.premiumLockedTag,
  l10n.premiumLockedTitle('Helsinki'),
  l10n.premiumLockedBody,
  l10n.premiumHeadlineLimit,
  l10n.premiumHeadlineLocked('Helsinki'),
  l10n.premiumFreeStays,
  l10n.premiumEndsOn('X'),
  l10n.premiumEndedOn('X'),
  l10n.premiumNeedsPlayVersion,
];

/// Words that name a way to pay outside Google Play, in the app's
/// languages.
final _otherRails = RegExp(
  r'telegram|stars|crypto|usdt|تلگرام|استارز|ارز دیجیتال|تيليجرام|تيليغرام|'
  r'العملات|телеграм|звезд|звёзд|крипт|テレグラム|暗号|텔레그램|암호|'
  r'टेलीग्राम|क्रिप्टो|ٹیلیگرام|کرپٹو|kripto|yıldız',
  caseSensitive: false,
);

const _helsinki = LockedServer(id: 14, countryCode: 'FI', city: 'Helsinki');

/// Sales on with every offer turned on and no number sent.
const _offers = BillingInfo(
  enabled: true,
  plans: [_plan],
  rails: Rails(googlePlay: true, codes: true),
  upsell: Upsell(
    surfaces: {
      UpsellSurface.topChip,
      UpsellSurface.limitSheet,
      UpsellSurface.serverCard,
      UpsellSurface.quotaLine,
      UpsellSurface.myServersCard,
      UpsellSurface.calmCard,
      UpsellSurface.lockedServers,
    },
    lockedServers: [_helsinki],
  ),
);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ApiRelays.resetForTest();
  });

  for (final lang in _languages) {
    group('[$lang] the Premium offers', () {
      test('every new text names no number, no other way to pay and no '
          'dash', () {
        final l10n = lookupS(Locale(lang));
        for (final text in _offerTexts(l10n)) {
          expect(_digit.hasMatch(text), isFalse, reason: text);
          expect(_otherRails.hasMatch(text), isFalse, reason: text);
          expect(text, isNot(contains('\u2014')), reason: text);
          expect(text, isNot(contains('\u2013')), reason: text);
          expect(text, isNot(contains('--')), reason: text);
          expect(text.trim(), isNotEmpty);
        }
        expect(l10n.premiumLockedTitle('Helsinki'), contains('Helsinki'));
        expect(l10n.premiumHeadlineLocked('Helsinki'), contains('Helsinki'));
        expect(l10n.premiumEndsOn('X'), contains('X'));
        expect(l10n.premiumEndedOn('X'), contains('X'));
      });

      testWidgets('the limit sheet names no number', (tester) async {
        final billing = _FixedBilling(_offers);
        await tester.pumpWidget(
          _app(
            billing,
            Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showLimitSheet(context),
                  child: const Text('open'),
                ),
              ),
            ),
            lang,
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        final texts = _shown(tester);
        final l10n = lookupS(Locale(lang));
        expect(texts, contains(l10n.premiumLimitSheetTitle));
        expect(texts, contains(l10n.premiumNoDailyLimit));
        // No refill time from the backend: the line names none.
        expect(texts, contains(l10n.myServersBlockedWait));
        expect(texts.where(_digit.hasMatch), isEmpty);
        await tester.pumpWidget(const SizedBox());
        billing.dispose();
      });

      testWidgets('a locked location names no number', (tester) async {
        final billing = _FixedBilling(_offers);
        await tester.pumpWidget(
          _app(
            billing,
            const Scaffold(body: LockedServerTile(server: _helsinki)),
            lang,
          ),
        );
        await tester.tap(find.byType(LockedServerTile));
        await tester.pumpAndSettle();

        final texts = _shown(tester);
        final l10n = lookupS(Locale(lang));
        expect(texts, contains(l10n.premiumLockedTitle('Helsinki')));
        expect(texts, contains(l10n.premiumLockedBody));
        expect(texts, contains(l10n.premiumLockedTag));
        expect(texts.where(_digit.hasMatch), isEmpty);
      });

      testWidgets('the offer cards name no number', (tester) async {
        final billing = _FixedBilling(_offers);
        await tester.pumpWidget(
          _app(
            billing,
            Builder(
              builder: (context) {
                final l10n = S.of(context)!;
                return Scaffold(
                  body: ListView(
                    children: [
                      PremiumOfferCard(
                        title: l10n.premiumCalmTitle,
                        body: l10n.premiumCalmBody,
                        onGetUnlimited: () {},
                        onNotNow: () {},
                      ),
                      PremiumOfferCard(
                        title: l10n.premiumNextStepTitle,
                        body: l10n.premiumNextStepBody,
                        onGetUnlimited: () {},
                      ),
                    ],
                  ),
                );
              },
            ),
            lang,
          ),
        );
        await tester.pump();

        final texts = _shown(tester);
        expect(texts, contains(lookupS(Locale(lang)).premiumCalmBody));
        expect(texts.where(_digit.hasMatch), isEmpty);
      });

      for (final (source, place) in [
        (PremiumSource.limitSheet, null),
        (PremiumSource.lockedServer, 'Helsinki'),
      ]) {
        testWidgets('the Premium screen from ${source.wire} names no '
            'number', (tester) async {
          final billing = _FixedBilling(_offers);
          await tester.pumpWidget(
            _app(billing, PremiumScreen(source: source, place: place), lang),
          );
          await tester.pump();

          final texts = _shown(tester);
          final l10n = lookupS(Locale(lang));
          expect(texts, contains(l10n.premiumFreeStays));
          expect(
            texts,
            contains(
              place == null
                  ? l10n.premiumHeadlineLimit
                  : l10n.premiumHeadlineLocked(place),
            ),
          );
          expect(texts.where(_digit.hasMatch), isEmpty);
        });
      }
    });
  }

  for (final lang in _languages) {
    group('[$lang]', () {
      testWidgets('the Play build names no number', (tester) async {
        final billing = _FixedBilling(
          const BillingInfo(
            enabled: true,
            premium: _premium,
            plans: [_plan],
            rails: Rails(googlePlay: true, codes: true),
          ),
        );
        await tester.pumpWidget(_app(billing, const PremiumScreen(), lang));
        await tester.pump();

        final texts = _shown(tester);
        final l10n = lookupS(Locale(lang));
        expect(texts, contains(l10n.premiumActiveNoDate));
        expect(texts, contains(l10n.premiumKeyMovesNoNumber));
        expect(texts, contains(l10n.premiumPlanNoDays));
        expect(texts.where(_digit.hasMatch), isEmpty);
      });

      testWidgets('a Play subscription names no number of its own', (
        tester,
      ) async {
        // Billed every month: the one comes from Play's period, P1M, and
        // the text for it names no number.
        final billing = _FixedBilling(
          const BillingInfo(
            enabled: true,
            plans: [_plan],
            rails: Rails(googlePlay: true),
          ),
          products: const [
            PlayProduct(
              productId: 'premium',
              basePlanId: 'base',
              price: 'X',
              renews: true,
              billingPeriod: 'P1M',
            ),
          ],
        );
        await tester.pumpWidget(_app(billing, const PremiumScreen(), lang));
        await tester.pump();

        final texts = _shown(tester);
        final l10n = lookupS(Locale(lang));
        expect(texts, contains(l10n.premiumRenewsMonths(1)));
        expect(texts, contains(l10n.premiumPlayCancelNote));
        expect(texts, contains(l10n.premiumManageSubscription));
        expect(texts.where(_digit.hasMatch), isEmpty);
      });

      testWidgets('a Play subscriber\'s view names no number', (tester) async {
        final billing = _FixedBilling(
          const BillingInfo(
            enabled: true,
            premium: Premium(
              active: true,
              plan: 'unlimited',
              source: 'google_play',
              autoRenewing: true,
            ),
            plans: [_plan],
            rails: Rails(googlePlay: true),
          ),
          products: const [
            PlayProduct(
              productId: 'premium',
              basePlanId: 'base',
              price: 'X',
              renews: true,
            ),
          ],
        );
        await tester.pumpWidget(_app(billing, const PremiumScreen(), lang));
        await tester.pump();

        final texts = _shown(tester);
        final l10n = lookupS(Locale(lang));
        expect(texts, contains(l10n.premiumCurrentPlan));
        expect(texts, contains(l10n.premiumPlaySubscribed));
        expect(texts, contains(l10n.premiumRenewsNoPeriod));
        expect(texts.where(_digit.hasMatch), isEmpty);
      });

      testWidgets('a copy Google did not sign names no number', (tester) async {
        final billing = _FixedBilling(
          const BillingInfo(
            enabled: true,
            plans: [_plan],
            rails: Rails(googlePlay: true, codes: true),
          ),
          googleSigned: false,
        );
        await tester.pumpWidget(_app(billing, const PremiumScreen(), lang));
        await tester.pump();

        final texts = _shown(tester);
        final l10n = lookupS(Locale(lang));
        expect(texts, contains(l10n.premiumNeedsPlayVersion));
        expect(texts, contains(l10n.premiumEnterCode));
        expect(texts.where(_digit.hasMatch), isEmpty);
        expect(texts.where(_otherRails.hasMatch), isEmpty);
      });

      testWidgets('the code dialog names no number', (tester) async {
        final billing = _FixedBilling(const BillingInfo(enabled: true));
        await tester.pumpWidget(
          _app(
            billing,
            Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showRedeemCodeDialog(context),
                  child: const Text('open'),
                ),
              ),
            ),
            lang,
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        final texts = _shown(tester);
        expect(texts, contains(lookupS(Locale(lang)).redeemTitle));
        expect(texts.where(_digit.hasMatch), isEmpty);
      });
    });
  }
}
