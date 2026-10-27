import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/api/api_client.dart';
import 'package:fortiva_vpn/api/api_routes.dart';
import 'package:fortiva_vpn/api/billing_service.dart';
import 'package:fortiva_vpn/core/design_system.dart';
import 'package:fortiva_vpn/core/state/billing_state.dart';
import 'package:fortiva_vpn/core/state/dedicated_state.dart';
import 'package:fortiva_vpn/data/models/billing.dart';
import 'package:fortiva_vpn/l10n/generated/app_localizations.dart';
import 'package:fortiva_vpn/screens/premium_screen.dart';
import 'package:fortiva_vpn/services/play_billing.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/app_theme.dart';

/// The Premium screen, the same in every copy of the app.
///
/// Every copy shows Google Play's plans, Restore purchases, the link to
/// manage the subscription and "Enter a code". The Play parts need the
/// copy Google Play signed, because Play sells in no other. A copy Google
/// did not sign, such as the APK posted in the Telegram channel, shows
/// "Enter a code" and one line saying that buying through Google Play
/// needs the Google Play version. No copy ever shows, names or links
/// another way to pay, even when an older backend still sends crypto and
/// Telegram rails. Here the signature check's answer is passed in
/// (googleSigned).

const _plan = Plan(
  code: 'unlimited_30d',
  days: 30,
  google: PlayProductRef(productId: 'premium', basePlanId: 'p30'),
);

const _everything = Rails(googlePlay: true, codes: true);

BillingInfo _info({
  Rails rails = _everything,
  Premium premium = Premium.none,
  bool enabled = true,
}) => BillingInfo(
  enabled: enabled,
  premium: premium,
  plans: const [_plan],
  rails: rails,
);

/// What an older backend sent the channel APK of builds 1.6.16 and 1.6.17,
/// with Google Play turned on as well: USDT and Stars prices, crypto
/// networks and the crypto and Telegram rails.
BillingInfo _olderAnswer({bool enabled = true}) => BillingInfo.fromJson({
  'enabled': enabled,
  'premium': {'active': false},
  'plans': [
    {
      'code': 'unlimited_30d',
      'days': 30,
      'google': {'product_id': 'premium', 'base_plan_id': 'p30'},
      'usdt': '4.99',
      'stars': 350,
    },
  ],
  'rails': {
    'google_play': true,
    'crypto': true,
    'telegram': true,
    'codes': true,
    'play_restore': true,
  },
  'networks': [
    {'id': 'ton_usdt', 'label': 'USDT on TON'},
  ],
  'renewal': {'can_renew': true},
});

/// The line a copy that cannot buy through Google Play shows.
const _needsPlayVersion =
    'To buy through Google Play, you need the Google Play version of Fortiva.';

/// No text that names, prices or links a way to pay outside Google Play.
void _expectNoOtherWayToPay() {
  for (final word in ['Telegram', 'Stars', 'crypto', 'USDT', 'bot']) {
    expect(find.textContaining(word), findsNothing, reason: word);
  }
  expect(find.text('Pay with crypto'), findsNothing);
  expect(find.text('Buy in Telegram'), findsNothing);
}

/// A Play that is there but is never used by these tests.
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

/// Billing with a fixed answer that never loads anything. [googleSigned]
/// is what the signature check said: true for the copy Google Play signed,
/// false for any other, such as the channel APK.
class _FixedBilling extends BillingState {
  _FixedBilling(
    BillingInfo info, {
    List<PlayProduct> products = const [],
    Set<String> owned = const {},
    PlayBilling? play,
    bool googleSigned = true,
  }) : super(
         service: BillingService(client: _noBackend()),
         playBilling: () => play,
         deviceId: () async => 'DEV-1',
       ) {
    adoptForTest(
      info,
      products: products,
      owned: owned,
      googleSigned: googleSigned,
    );
    adoptWorkedForTest();
  }

  /// The places the open Premium screens were opened from, newest last.
  final List<PremiumSource> open = [];

  @override
  void premiumScreenOpened(PremiumSource source) {
    open.add(source);
    super.premiumScreenOpened(source);
  }

  @override
  void premiumScreenClosed(PremiumSource source) {
    open.remove(source);
    super.premiumScreenClosed(source);
  }

  @override
  Future<void> refresh() async {}
}

/// Billing whose Play flow the test turns on and off: a Buy tap starts
/// it, and [setBusy] stands for a purchase Play finishes or reports later.
class _FlowBilling extends _FixedBilling {
  _FlowBilling(super.info, {super.products, super.play});

  bool _busy = false;
  final bought = <String>[];

  @override
  bool get playBusy => _busy;

  @override
  Future<bool> buyOnPlay(Plan plan) async {
    bought.add(plan.code);
    setBusy(true);
    return true;
  }

  void setBusy(bool busy) {
    _busy = busy;
    notifyListeners();
  }
}

/// A Play whose availability answer waits for [answer], so a restore stays
/// under way until the test lets it end.
class _SlowPlay extends _IdlePlay {
  final answer = Completer<bool>();

  @override
  Future<bool> isAvailable() => answer.future;
}

ApiClient _noBackend() => ApiClient.forTest(
  direct: MockClient((_) async => throw http.ClientException('no backend')),
);

class _FakeDedicated extends DedicatedState {
  @override
  Future<void> refresh({bool? viaTunnel}) async {}
}

Widget _app(BillingState billing, Widget home, {String locale = 'en'}) =>
    MultiProvider(
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

const _playProducts = [
  PlayProduct(productId: 'premium', basePlanId: 'p30', price: 'EUR 4,99'),
];

/// Two base plans of one Play subscription, as Play gives them.
const _yearPlan = Plan(
  code: 'unlimited_365d',
  days: 365,
  google: PlayProductRef(productId: 'premium', basePlanId: 'p365'),
);

PlayProduct _renewing(String basePlan, String price, String? period) =>
    PlayProduct(
      productId: 'premium',
      basePlanId: basePlan,
      price: price,
      renews: true,
      billingPeriod: period,
    );

final _subscriptions = [
  _renewing('p30', 'EUR 4,99', 'P1M'),
  _renewing('p365', 'EUR 39,99', 'P1Y'),
];

BillingInfo _playInfo({
  Premium premium = Premium.none,
  bool enabled = true,
  Rails rails = const Rails(googlePlay: true, codes: true),
}) => BillingInfo(
  enabled: enabled,
  premium: premium,
  plans: const [_plan, _yearPlan],
  rails: rails,
);

/// What url_launcher was asked to open, for the duration of a test.
List<String> _recordLaunches() {
  final launched = <String>[];
  const channel = MethodChannel('plugins.flutter.io/url_launcher');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(channel, (call) async {
    if (call.method == 'launch') {
      launched.add((call.arguments as Map)['url'] as String);
    }
    return true;
  });
  addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
  return launched;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ApiRelays.resetForTest();
  });

  group('the copy Google Play signed', () {
    testWidgets('sells through Google Play with Play\'s price', (tester) async {
      final billing = _FixedBilling(
        _info(),
        products: _playProducts,
        play: _IdlePlay(),
      );
      await tester.pumpWidget(_app(billing, const PremiumScreen()));
      await tester.pump();

      expect(find.text('30 days of unlimited data'), findsOneWidget);
      expect(find.text('EUR 4,99'), findsOneWidget);
      expect(find.text('Buy'), findsOneWidget);
      expect(find.text('Restore purchases'), findsOneWidget);
      expect(find.text('Enter a code'), findsOneWidget);
    });

    testWidgets('never shows crypto or Telegram, even when an older backend '
        'sends them', (tester) async {
      final billing = _FixedBilling(
        _olderAnswer(),
        products: _playProducts,
        play: _IdlePlay(),
      );
      await tester.pumpWidget(_app(billing, const PremiumScreen()));
      await tester.pump();

      expect(find.text('EUR 4,99'), findsOneWidget);
      expect(find.text('Buy'), findsOneWidget);
      expect(find.text('Enter a code'), findsOneWidget);
      expect(find.text(_needsPlayVersion), findsNothing);
      _expectNoOtherWayToPay();
    });

    testWidgets('says so when Play has no price for the plan', (tester) async {
      final billing = _FixedBilling(_info(), play: _IdlePlay());
      await tester.pumpWidget(_app(billing, const PremiumScreen()));
      await tester.pump();

      expect(
        find.text('Google Play is not available right now. Try again later.'),
        findsOneWidget,
      );
      expect(find.text('Buy'), findsNothing);
    });

    testWidgets('the code box shows only when the backend allows it', (
      tester,
    ) async {
      final billing = _FixedBilling(
        _info(rails: const Rails(googlePlay: true)),
        products: _playProducts,
        play: _IdlePlay(),
      );
      await tester.pumpWidget(_app(billing, const PremiumScreen()));
      await tester.pump();

      expect(find.text('Enter a code'), findsNothing);
    });
  });

  // Google Play's subscriptions policy: the offer says it renews, how
  // often Play bills, and how to cancel, and the app links to Play's page
  // for managing the subscription. The period is Play's own.
  group('a Play subscription', () {
    testWidgets('says how often it bills, that it renews, and how to '
        'cancel', (tester) async {
      final launched = _recordLaunches();
      final billing = _FixedBilling(
        _playInfo(),
        products: _subscriptions,
        play: _IdlePlay(),
      );
      await tester.pumpWidget(_app(billing, const PremiumScreen()));
      await tester.pump();

      expect(
        find.text('Billed every month. Renews automatically until you cancel.'),
        findsOneWidget,
      );
      expect(
        find.text('Billed every year. Renews automatically until you cancel.'),
        findsOneWidget,
      );
      expect(find.text('EUR 4,99'), findsOneWidget);
      expect(find.text('EUR 39,99'), findsOneWidget);
      expect(find.text('Buy'), findsNWidgets(2));
      // Not a pass that ends after a number of days.
      expect(find.textContaining('days'), findsNothing);
      expect(find.text('Unlimited data'), findsNWidgets(2));
      expect(
        find.text(
          'You can cancel anytime in Google Play. Premium stays on until '
          'the end of the time you paid for.',
        ),
        findsOneWidget,
      );

      final manage = find.text('Manage or cancel subscription');
      await tester.scrollUntilVisible(manage, 100);
      await tester.tap(manage);
      await tester.pump();
      expect(launched, ['https://play.google.com/store/account/subscriptions']);
    });

    testWidgets('a period of several months names Play\'s number', (
      tester,
    ) async {
      final billing = _FixedBilling(
        _playInfo(),
        products: [_renewing('p30', 'EUR 12,99', 'P3M')],
        play: _IdlePlay(),
      );
      await tester.pumpWidget(_app(billing, const PremiumScreen()));
      await tester.pump();

      expect(
        find.text(
          'Billed every 3 months. Renews automatically until you cancel.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('with no period from Play, it still says it renews', (
      tester,
    ) async {
      final billing = _FixedBilling(
        _playInfo(),
        products: [_renewing('p30', 'EUR 4,99', null)],
        play: _IdlePlay(),
      );
      await tester.pumpWidget(_app(billing, const PremiumScreen()));
      await tester.pump();

      expect(find.text('30 days of unlimited data'), findsOneWidget);
      expect(
        find.text('Renews automatically until you cancel.'),
        findsOneWidget,
      );
    });

    testWidgets('the plan this phone is on reads Current plan, and the other '
        'plan of it is not sold', (tester) async {
      final launched = _recordLaunches();
      final billing = _FixedBilling(
        _playInfo(
          premium: const Premium(
            active: true,
            plan: 'unlimited_30d',
            source: 'google_play',
            autoRenewing: true,
          ),
        ),
        products: _subscriptions,
        play: _IdlePlay(),
      );
      await tester.pumpWidget(_app(billing, const PremiumScreen()));
      await tester.pump();

      expect(find.text('Current plan'), findsOneWidget);
      expect(find.text('Buy'), findsNothing);
      expect(
        find.text(
          'You already have a Google Play subscription. Manage or cancel it '
          'in Google Play.',
        ),
        findsOneWidget,
      );

      final manage = find.text('Manage or cancel subscription');
      await tester.scrollUntilVisible(manage, 100);
      await tester.tap(manage);
      await tester.pump();
      expect(launched, [
        'https://play.google.com/store/account/subscriptions'
            '?sku=premium&package=com.vpn.fortivavpn',
      ]);
    });

    testWidgets('a subscriber who turned renewing off sees the end date and '
        'the link to Google Play, and no Renew', (tester) async {
      // The backend never lets a Play subscription renew here
      // (can_renew false); the link to manage it does not depend on that.
      final until = DateTime.now().add(const Duration(hours: 30));
      final billing = _FixedBilling(
        BillingInfo(
          enabled: true,
          premium: Premium(
            active: true,
            until: until,
            plan: 'unlimited_30d',
            source: 'google_play',
            autoRenewing: false,
          ),
          plans: const [_plan, _yearPlan],
          rails: const Rails(googlePlay: true, codes: true),
          renewal: Renewal(until: until, noticeHours: 72),
        ),
        products: _subscriptions,
        play: _IdlePlay(),
      );
      await tester.pumpWidget(_app(billing, const PremiumScreen()));
      await tester.pump();

      expect(find.textContaining('Unlimited data until'), findsOneWidget);
      expect(find.textContaining('Renew to keep unlimited data'), findsNothing);
      expect(find.text('Renew'), findsNothing);
      final manage = find.text('Manage or cancel subscription');
      await tester.scrollUntilVisible(manage, 100);
      expect(manage, findsOneWidget);
    });

    testWidgets('an account that owns the product is not sold it again, '
        'whatever this phone\'s Premium came from', (tester) async {
      final billing = _FixedBilling(
        _playInfo(),
        products: _subscriptions,
        owned: const {'premium'},
        play: _IdlePlay(),
      );
      await tester.pumpWidget(_app(billing, const PremiumScreen()));
      await tester.pump();

      expect(find.text('Buy'), findsNothing);
      expect(find.text('Current plan'), findsNothing);
      expect(
        find.textContaining('You already have a Google Play subscription.'),
        findsOneWidget,
      );
    });

    testWidgets('with sales off, a phone that may restore gets Restore and '
        'the manage link, and nothing on sale', (tester) async {
      final billing = _FixedBilling(
        _playInfo(enabled: false, rails: const Rails(playRestore: true)),
        products: _subscriptions,
        owned: const {'premium'},
        play: _IdlePlay(),
      );
      await tester.pumpWidget(_app(billing, const PremiumScreen()));
      await tester.pump();

      expect(find.text('Premium is not on sale right now.'), findsOneWidget);
      expect(find.text('Restore purchases'), findsOneWidget);
      expect(find.text('Manage or cancel subscription'), findsOneWidget);
      expect(find.text('Choose a plan'), findsNothing);
      expect(find.text('Buy'), findsNothing);
      expect(find.text('Enter a code'), findsNothing);
    });

    testWidgets('with sales and restores off, there is no Restore', (
      tester,
    ) async {
      final billing = _FixedBilling(
        _playInfo(enabled: false, rails: Rails.none),
        play: _IdlePlay(),
      );
      await tester.pumpWidget(_app(billing, const PremiumScreen()));
      await tester.pump();

      expect(find.text('Restore purchases'), findsNothing);
      expect(find.text('Manage or cancel subscription'), findsNothing);
    });
  });

  // The channel APK runs the same code, signed with our upload key. Google
  // Play refuses to sell in it, so it shows no Play part at all.
  group('a copy Google did not sign', () {
    testWidgets('shows Enter a code and one line about the Google Play '
        'version, and nothing else to buy', (tester) async {
      final billing = _FixedBilling(
        _info(),
        products: _playProducts,
        play: _IdlePlay(),
        googleSigned: false,
      );
      await tester.pumpWidget(_app(billing, const PremiumScreen()));
      await tester.pump();

      expect(find.text(_needsPlayVersion), findsOneWidget);
      expect(find.text('Enter a code'), findsOneWidget);
      expect(find.text('Choose a plan'), findsNothing);
      expect(find.text('EUR 4,99'), findsNothing);
      expect(find.text('Buy'), findsNothing);
      expect(find.text('Restore purchases'), findsNothing);
      expect(find.text('Manage or cancel subscription'), findsNothing);
      _expectNoOtherWayToPay();

      // The line sits above the code box.
      expect(
        tester.getTopLeft(find.text(_needsPlayVersion)).dy,
        lessThan(tester.getTopLeft(find.text('Enter a code')).dy),
      );
    });

    testWidgets('names no other way to pay, even when an older backend '
        'sends crypto and Telegram', (tester) async {
      final billing = _FixedBilling(
        _olderAnswer(),
        play: _IdlePlay(),
        googleSigned: false,
      );
      await tester.pumpWidget(_app(billing, const PremiumScreen()));
      await tester.pump();

      expect(find.text(_needsPlayVersion), findsOneWidget);
      expect(find.text('Enter a code'), findsOneWidget);
      expect(find.text('Restore purchases'), findsNothing);
      _expectNoOtherWayToPay();
    });

    testWidgets('says it in Persian', (tester) async {
      final billing = _FixedBilling(_info(), googleSigned: false);
      await tester.pumpWidget(
        _app(billing, const PremiumScreen(), locale: 'fa'),
      );
      await tester.pump();

      expect(
        find.text(
          'برای خرید از طریق گوگل پلی به نسخه گوگل پلی فورتیوا نیاز دارید.',
        ),
        findsOneWidget,
      );
      expect(find.text('وارد کردن کد'), findsOneWidget);
    });

    // Every copy sends store=play, so the backend's codes rail decides the
    // code box here as well (BILLING_PLAY_CODES on the backend). The channel
    // APKs of 1.6.16 and 1.6.17 sent store=direct and got the box whatever
    // that setting said.
    testWidgets('the code box shows only when the backend allows it, as in '
        'the copy Google signed', (tester) async {
      final billing = _FixedBilling(
        _info(rails: const Rails(googlePlay: true)),
        play: _IdlePlay(),
        googleSigned: false,
      );
      await tester.pumpWidget(_app(billing, const PremiumScreen()));
      await tester.pump();

      expect(find.text(_needsPlayVersion), findsOneWidget);
      expect(find.text('Enter a code'), findsNothing);
    });

    testWidgets('with nothing sold through Play, the line is left out', (
      tester,
    ) async {
      final billing = _FixedBilling(
        _info(rails: const Rails(codes: true)),
        googleSigned: false,
      );
      await tester.pumpWidget(_app(billing, const PremiumScreen()));
      await tester.pump();

      expect(find.text(_needsPlayVersion), findsNothing);
      expect(find.text('Enter a code'), findsOneWidget);
    });

    testWidgets('with sales off, it says nothing is on sale and shows no '
        'Restore', (tester) async {
      final billing = _FixedBilling(
        _olderAnswer(enabled: false),
        play: _IdlePlay(),
        googleSigned: false,
      );
      await tester.pumpWidget(_app(billing, const PremiumScreen()));
      await tester.pump();

      expect(find.text('Premium is not on sale right now.'), findsOneWidget);
      expect(find.text(_needsPlayVersion), findsNothing);
      expect(find.text('Restore purchases'), findsNothing);
      expect(find.text('Manage or cancel subscription'), findsNothing);
    });

    testWidgets('a Premium device still sees its key and status', (
      tester,
    ) async {
      final billing = _FixedBilling(
        _info(
          premium: Premium(
            active: true,
            until: DateTime.utc(2026, 11, 8, 10),
            source: 'stars',
            code: 'K7QD-3MWX-9TZB-H2CF',
          ),
        ),
        googleSigned: false,
      );
      await tester.pumpWidget(_app(billing, const PremiumScreen()));
      await tester.pump();

      expect(find.text('Premium is on'), findsOneWidget);
      expect(find.text('Activated with a key'), findsOneWidget);
      expect(find.text('K7QD-3MWX-9TZB-H2CF'), findsOneWidget);
      _expectNoOtherWayToPay();
    });
  });

  group('status', () {
    testWidgets('an active Premium shows its end, its source and its key', (
      tester,
    ) async {
      final billing = _FixedBilling(
        _info(
          premium: Premium(
            active: true,
            until: DateTime.utc(2026, 11, 8, 10),
            source: 'voucher',
            code: 'K7QD-3MWX-9TZB-H2CF',
          ),
        ),
        products: _playProducts,
        play: _IdlePlay(),
      );
      await tester.pumpWidget(_app(billing, const PremiumScreen()));
      await tester.pump();

      expect(find.text('Premium is on'), findsOneWidget);
      expect(find.text('Unlimited data until Nov 8, 2026'), findsOneWidget);
      expect(find.text('Activated with a key'), findsOneWidget);
      expect(find.text('Your key'), findsOneWidget);
      expect(find.text('K7QD-3MWX-9TZB-H2CF'), findsOneWidget);
      expect(
        find.text(
          'A key can move to another phone only a limited number of times.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('in Persian the end is on the Jalali calendar', (tester) async {
      final billing = _FixedBilling(
        _info(
          premium: Premium(
            active: true,
            until: DateTime.utc(2026, 11, 8, 10),
            source: 'voucher',
          ),
        ),
        products: _playProducts,
        play: _IdlePlay(),
      );
      await tester.pumpWidget(
        _app(billing, const PremiumScreen(), locale: 'fa'),
      );
      await tester.pump();
      expect(find.text('حجم نامحدود تا ۱۷ آبان ۱۴۰۵'), findsOneWidget);
    });

    for (final source in ['crypto', 'stars']) {
      for (final signed in [true, false]) {
        testWidgets('every copy calls $source Premium a key (signed by '
            'Google: $signed)', (tester) async {
          // It reaches the app only as a typed key, and no copy names a way
          // to pay outside Google Play.
          final billing = _FixedBilling(
            _info(premium: Premium(active: true, source: source)),
            products: _playProducts,
            play: _IdlePlay(),
            googleSigned: signed,
          );
          await tester.pumpWidget(_app(billing, const PremiumScreen()));
          await tester.pump();

          expect(find.text('Activated with a key'), findsOneWidget);
          _expectNoOtherWayToPay();
        });
      }
    }

    testWidgets('the move limit is the one the backend sends', (tester) async {
      await tester.pumpWidget(
        _app(
          _FixedBilling(_info()),
          const Scaffold(
            body: PremiumKeyCard(
              code: 'K7QD-3MWX-9TZB-H2CF',
              moveLimit: 3,
              moveWindowDays: 30,
            ),
          ),
        ),
      );
      expect(
        find.text('A key can move to another phone up to 3 times in 30 days.'),
        findsOneWidget,
      );
    });

    testWidgets('a load that fails says so and offers to try again', (
      tester,
    ) async {
      final billing = BillingState(
        service: BillingService(client: _noBackend()),
        playBilling: () => null,
        googleSigned: () async => false,
        deviceId: () async => 'DEV-1',
      );
      await tester.pumpWidget(_app(billing, const PremiumScreen()));
      // Waiting for the first load, not failed yet.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        find.text(
          'Could not load Premium. Check your connection and try again.',
        ),
        findsOneWidget,
      );
      expect(find.text('Try again'), findsOneWidget);
      expect(find.text('Enter a code'), findsNothing);
    });

    testWidgets('with sales off and no Premium, nothing is on sale', (
      tester,
    ) async {
      final billing = _FixedBilling(_info(enabled: false));
      await tester.pumpWidget(_app(billing, const PremiumScreen()));
      await tester.pump();

      expect(find.text('Premium is not on sale right now.'), findsOneWidget);
      expect(find.text('Enter a code'), findsNothing);
      expect(find.text('Choose a plan'), findsNothing);
    });

    testWidgets('a plan with no length from the backend names none', (
      tester,
    ) async {
      // A Play product that does not renew, so the title is the plan's.
      final billing = _FixedBilling(
        const BillingInfo(
          enabled: true,
          plans: [
            Plan(
              code: 'p',
              google: PlayProductRef(productId: 'premium', basePlanId: 'p30'),
            ),
          ],
          rails: _everything,
        ),
        products: _playProducts,
        play: _IdlePlay(),
      );
      await tester.pumpWidget(_app(billing, const PremiumScreen()));
      await tester.pump();
      expect(find.text('Unlimited data'), findsWidgets);
      expect(find.textContaining('days'), findsNothing);
    });
  });

  group('what the screen leads with', () {
    for (final (source, headline) in [
      (PremiumSource.settings, 'Get unlimited data'),
      (PremiumSource.topChip, 'Get unlimited data'),
      (PremiumSource.calmCard, 'Get unlimited data'),
      (PremiumSource.limitSheet, 'No daily limit'),
      (PremiumSource.serverCard, 'No daily limit'),
      (PremiumSource.quotaLine, 'No daily limit'),
      (PremiumSource.quotaCard, 'No daily limit'),
      (PremiumSource.spentNotice, 'No daily limit'),
    ]) {
      testWidgets('opened from ${source.wire}: $headline', (tester) async {
        await tester.pumpWidget(
          _app(
            _FixedBilling(_info(), products: _playProducts, play: _IdlePlay()),
            PremiumScreen(source: source),
          ),
        );
        await tester.pump();
        expect(find.text(headline), findsOneWidget);
      });
    }

    testWidgets('opened from a locked location, it names the place', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          _FixedBilling(_info(), products: _playProducts, play: _IdlePlay()),
          const PremiumScreen(
            source: PremiumSource.lockedServer,
            place: 'Helsinki',
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Unlock Helsinki with Premium'), findsOneWidget);
    });

    testWidgets('says under the plans that the free plan keeps working', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          _FixedBilling(_info(), products: _playProducts, play: _IdlePlay()),
          const PremiumScreen(),
        ),
      );
      await tester.pump();
      final line = find.text('The free plan keeps working without Premium.');
      expect(line, findsOneWidget);
      expect(
        tester.getTopLeft(line).dy,
        greaterThan(tester.getTopLeft(find.text('Buy')).dy),
      );
    });

    testWidgets('does not say it to a Premium device', (tester) async {
      await tester.pumpWidget(
        _app(
          _FixedBilling(
            _info(premium: const Premium(active: true)),
            products: _playProducts,
            play: _IdlePlay(),
          ),
          const PremiumScreen(),
        ),
      );
      await tester.pump();
      expect(
        find.text('The free plan keeps working without Premium.'),
        findsNothing,
      );
    });

    testWidgets('has a back button from the first frame', (tester) async {
      final billing = _FixedBilling(
        _info(),
        products: _playProducts,
        play: _IdlePlay(),
      );
      await tester.pumpWidget(
        _app(
          billing,
          Builder(
            builder: (context) => TextButton(
              onPressed: () =>
                  PremiumScreen.open(context, source: PremiumSource.topChip),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1));
      expect(find.byType(BackButton), findsOneWidget);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.byType(PremiumScreen), findsNothing);
    });

    testWidgets('tells billing where it was opened from, until it closes, '
        'so a purchase made on it carries that', (tester) async {
      final billing = _FixedBilling(
        _info(),
        products: _playProducts,
        play: _IdlePlay(),
      );
      await tester.pumpWidget(
        _app(
          billing,
          Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) =>
                      const PremiumScreen(source: PremiumSource.calmCard),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(billing.open, [PremiumSource.calmCard]);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(billing.open, isEmpty);
    });
  });

  // No copy has a Renew button: a Google Play subscription is turned back
  // on in Google Play, and a key is bought outside the app.
  group('when Premium ends', () {
    for (final signed in [true, false]) {
      testWidgets('a key about to end names the end alone, with no call to '
          'renew (signed by Google: $signed)', (tester) async {
        final until = DateTime.now().add(const Duration(hours: 20));
        await tester.pumpWidget(
          _app(
            _FixedBilling(
              BillingInfo(
                enabled: true,
                premium: Premium(active: true, until: until, source: 'voucher'),
                plans: const [_plan],
                rails: _everything,
                renewal: Renewal(until: until, noticeHours: 72),
              ),
              products: _playProducts,
              play: _IdlePlay(),
              googleSigned: signed,
            ),
            const PremiumScreen(),
          ),
        );
        await tester.pump();
        expect(find.textContaining('Unlimited data until'), findsOneWidget);
        expect(find.textContaining('Renew'), findsNothing);
      });
    }

    testWidgets('after the end it says when Premium ended', (tester) async {
      await tester.pumpWidget(
        _app(
          _FixedBilling(
            BillingInfo(
              enabled: true,
              plans: const [_plan],
              rails: _everything,
              renewal: Renewal(endedAt: DateTime.utc(2026, 11, 8, 10)),
            ),
            products: _playProducts,
            play: _IdlePlay(),
          ),
          const PremiumScreen(),
        ),
      );
      await tester.pump();
      expect(
        find.text('Premium ended on Nov 8, 2026. Your free plan is back.'),
        findsOneWidget,
      );
    });
  });

  // The look of the screen: what the redesign keeps true on purpose.
  group('the look', () {
    Widget themed(BillingState billing, {String locale = 'en'}) =>
        MultiProvider(
          providers: [
            ChangeNotifierProvider<BillingState>.value(value: billing),
            ChangeNotifierProvider<DedicatedState>.value(
              value: _FakeDedicated(),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: S.localizationsDelegates,
            supportedLocales: S.supportedLocales,
            locale: Locale(locale),
            theme: appThemeFor(Locale(locale)),
            home: const PremiumScreen(),
          ),
        );

    testWidgets('Play\'s price reads left to right at the start of its '
        'card, with Buy at the end, in Persian', (tester) async {
      final billing = _FixedBilling(
        _playInfo(),
        products: _subscriptions,
        play: _IdlePlay(),
      );
      await tester.pumpWidget(themed(billing, locale: 'fa'));
      await tester.pump();
      final price = find.text('EUR 4,99');
      expect(
        tester
            .widget<Directionality>(
              find
                  .ancestor(of: price, matching: find.byType(Directionality))
                  .first,
            )
            .textDirection,
        TextDirection.ltr,
      );
      final buy = find
          .ancestor(
            of: find.text('خرید'),
            matching: find.byWidgetPredicate((w) => w is FilledButton),
          )
          .first;
      // Right to left: the price at the right, Buy left of it.
      expect(
        tester.getRect(price).left,
        greaterThan(tester.getRect(buy).right),
      );
    });

    testWidgets('every Buy is a full tap target in the app theme', (
      tester,
    ) async {
      final billing = _FixedBilling(
        _playInfo(),
        products: _subscriptions,
        play: _IdlePlay(),
      );
      await tester.pumpWidget(themed(billing));
      await tester.pump();
      final buys = find.ancestor(
        of: find.text('Buy'),
        matching: find.byWidgetPredicate((w) => w is FilledButton),
      );
      expect(buys, findsNWidgets(2));
      for (final e in buys.evaluate()) {
        expect(
          tester.getSize(find.byWidget(e.widget)).height,
          greaterThanOrEqualTo(48),
        );
      }
    });

    testWidgets('the offer leads with the shield, and a Premium device with '
        'its status', (tester) async {
      await tester.pumpWidget(
        themed(
          _FixedBilling(
            _playInfo(),
            products: _subscriptions,
            play: _IdlePlay(),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(Image), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Get unlimited data')).dy,
        lessThan(tester.getTopLeft(find.text('Choose a plan')).dy),
      );

      await tester.pumpWidget(
        themed(
          _FixedBilling(
            _playInfo(
              premium: Premium(active: true, until: DateTime(2026, 11, 8)),
            ),
            products: _subscriptions,
            play: _IdlePlay(),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(Image), findsNothing);
      expect(find.text('Get unlimited data'), findsNothing);
      expect(
        tester.getTopLeft(find.text('Premium is on')).dy,
        lessThan(tester.getTopLeft(find.text('Choose a plan')).dy),
      );
    });

    testWidgets('Restore stays a button while it runs, with a spinner in '
        'it, and a second tap does nothing', (tester) async {
      final play = _SlowPlay();
      final billing = _FixedBilling(
        _info(),
        products: _playProducts,
        play: play,
      );
      await tester.pumpWidget(themed(billing));
      await tester.pump();
      final restore = find.ancestor(
        of: find.text('Restore purchases'),
        matching: find.byWidgetPredicate((w) => w is TextButton),
      );
      expect(
        find.descendant(
          of: restore,
          matching: find.byType(CircularProgressIndicator),
        ),
        findsNothing,
      );

      await tester.tap(find.text('Restore purchases'));
      await tester.pump();
      expect(billing.isRestoring, isTrue);
      // Enabled, so a TV remote keeps its focus on it.
      expect(tester.widget<TextButton>(restore).onPressed, isNotNull);
      expect(
        find.descendant(
          of: restore,
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Restore purchases'));
      await tester.pump();
      // The second tap reached no restore, so no "not available" line.
      expect(
        find.text('Google Play is not available right now. Try again later.'),
        findsNothing,
      );

      play.answer.complete(true);
      await tester.pump();
      await tester.pump();
      expect(billing.isRestoring, isFalse);
      expect(
        find.text('Google Play has no purchase to restore.'),
        findsOneWidget,
      );
    });

    testWidgets('the spinner in Buy follows only a purchase started from '
        'that Buy', (tester) async {
      final billing = _FlowBilling(
        _playInfo(),
        products: _subscriptions,
        play: _IdlePlay(),
      );
      await tester.pumpWidget(themed(billing));
      await tester.pump();
      final spinners = find.descendant(
        of: find.byWidgetPredicate((w) => w is FilledButton),
        matching: find.byType(CircularProgressIndicator),
      );

      await tester.tap(find.text('Buy').first);
      await tester.pump();
      expect(billing.bought, ['unlimited_30d']);
      expect(spinners, findsOneWidget);
      // Enabled while Play's sheet is open, and a second tap buys nothing.
      final buy = find.ancestor(
        of: spinners,
        matching: find.byWidgetPredicate((w) => w is FilledButton),
      );
      expect(tester.widget<FilledButton>(buy).onPressed, isNotNull);
      await tester.tap(buy);
      await tester.pump();
      expect(billing.bought, ['unlimited_30d']);

      // Play's flow ends, then a purchase found later is confirmed: no
      // Buy tapped here, so no Buy spins.
      billing.setBusy(false);
      await tester.pump();
      expect(spinners, findsNothing);
      billing.setBusy(true);
      await tester.pump();
      expect(spinners, findsNothing);
    });

    group('Play\'s price', () {
      Future<void> pumpCard(
        WidgetTester tester, {
        required double width,
        required double scale,
        String price = 'EUR 39,99',
        String title = 'Unlimited data',
        String locale = 'en',
      }) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          MaterialApp(
            locale: Locale(locale),
            localizationsDelegates: S.localizationsDelegates,
            supportedLocales: S.supportedLocales,
            theme: appThemeFor(Locale(locale)),
            home: MediaQuery(
              data: MediaQueryData(
                size: Size(width, 900),
                textScaler: TextScaler.linear(scale),
              ),
              child: Scaffold(
                body: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    PremiumPlanCard(
                      title: title,
                      prices: [price],
                      note: 'Billed every year.',
                      action: FilledButton(
                        onPressed: () {},
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(104, 52),
                        ),
                        child: const Text('Buy'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }

      double oneLine(double scale) {
        final style = AppDesign.textTheme.headlineSmall!;
        return style.fontSize! * (style.height ?? 1.2) * scale;
      }

      Finder buy() => find.ancestor(
        of: find.text('Buy'),
        matching: find.byWidgetPredicate((w) => w is FilledButton),
      );

      testWidgets('sits beside Buy where both fit on one line', (tester) async {
        await pumpCard(tester, width: 412, scale: 1);
        final price = tester.getRect(find.text('EUR 39,99'));
        expect(price.height, lessThan(oneLine(1) * 1.5));
        final button = tester.getRect(buy());
        expect(button.left, greaterThan(price.right));
        expect(button.top, lessThan(price.bottom));
      });

      for (final (width, scale) in [(320.0, 1.3), (360.0, 2.0)]) {
        testWidgets('stays on one line over a full width Buy where it '
            'does not fit beside it ($width at $scale)', (tester) async {
          await pumpCard(tester, width: width, scale: scale);
          final price = tester.getRect(find.text('EUR 39,99'));
          expect(price.height, lessThan(oneLine(scale) * 1.5));
          final button = tester.getRect(buy());
          expect(button.top, greaterThanOrEqualTo(price.bottom));
          // The card's inside: the list's 16, the card's 1dp edge and its
          // own 16, on each side.
          expect(button.width, closeTo(width - 66, 0.5));
          expect(button.height, greaterThanOrEqualTo(52));
          expect(tester.takeException(), isNull);
        });
      }

      testWidgets('goes over Buy where the title\'s longest word would not '
          'fit beside it', (tester) async {
        // The test font draws each letter as a square of the font size:
        // the price fits beside Buy here, the title's one long word does
        // not.
        await pumpCard(
          tester,
          width: 360,
          scale: 1,
          price: 'EUR 4,99',
          title: 'Unlimiteddata',
        );
        final title = tester.getRect(find.text('Unlimiteddata'));
        final style = AppDesign.textTheme.titleMedium!;
        expect(
          title.height,
          lessThan(style.fontSize! * (style.height ?? 1.2) * 1.5),
        );
        expect(
          tester.getRect(buy()).top,
          greaterThanOrEqualTo(tester.getRect(find.text('EUR 4,99')).bottom),
        );
      });

      testWidgets('starts at the right in Persian, over a full width Buy', (
        tester,
      ) async {
        await pumpCard(tester, width: 320, scale: 1.3, locale: 'fa');
        final price = tester.getRect(find.text('EUR 39,99'));
        final button = tester.getRect(buy());
        expect(price.right, closeTo(button.right, 0.5));
        expect(button.top, greaterThanOrEqualTo(price.bottom));
      });
    });
  });
}
