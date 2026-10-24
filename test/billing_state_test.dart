import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/api/api_client.dart';
import 'package:fortiva_vpn/api/api_routes.dart';
import 'package:fortiva_vpn/api/billing_service.dart';
import 'package:fortiva_vpn/api/config_service.dart';
import 'package:fortiva_vpn/core/state/billing_state.dart';
import 'package:fortiva_vpn/core/state/dedicated_state.dart';
import 'package:fortiva_vpn/data/models/billing.dart';
import 'package:fortiva_vpn/services/play_billing.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Premium's state: what it offers, and the Google Play purchase flow.
///
/// Everything ships dark, so nothing may be offered until GET .../billing
/// says sales are on, and Play is not even asked anything until the
/// backend sells through it on this device.
///
/// Every copy of the app runs this code. Only a copy signed with Google
/// Play's app signing certificate may use Play, so these tests say what the
/// signature check answered (googleSigned). A copy Google did not sign, such
/// as the channel APK, never touches Play and is offered nothing to buy.
///
/// Play refunds a purchase nobody acknowledges within a few days, and the
/// app must only acknowledge one the backend has confirmed. So a purchase
/// is completed in Play only after POST .../billing/google answered 200,
/// and its token stays on the phone until then and is sent again at launch
/// and on every return to the app.

const _device = 'DEV-1';

Map<String, dynamic> _premium({
  bool active = false,
  String? code,
  String source = 'voucher',
}) => {
  'active': active,
  'until': active ? '2026-11-08T10:00:00Z' : null,
  'plan': active ? 'unlimited_30d' : null,
  'source': active ? source : null,
  'auto_renewing': null,
  'code': code,
};

const _unlimited = {
  'unlimited': true,
  'limit_bytes': 0,
  'used_bytes': 0,
  'remaining_bytes': 0,
  'blocked': false,
};

const _fullPlan = {
  'code': 'unlimited_30d',
  'days': 30,
  'google': {'product_id': 'premium', 'base_plan_id': 'p30'},
  'usdt': '4.99',
  'stars': 350,
};

const _tonUsdt = {'id': 'ton_usdt', 'label': 'USDT on TON'};

Map<String, dynamic> _info({
  bool enabled = true,
  bool googlePlay = false,
  bool crypto = false,
  bool telegram = false,
  bool codes = true,
  bool playRestore = false,
  bool premium = false,
  String source = 'voucher',
  List<Map<String, Object?>> plans = const [_fullPlan],
  List<Map<String, Object?>> networks = const [_tonUsdt],
  Map<String, Object?>? upsell,
}) => {
  'enabled': enabled,
  'premium': _premium(active: premium, source: source),
  'plans': plans,
  'rails': {
    'google_play': googlePlay,
    'crypto': crypto,
    'telegram': telegram,
    'codes': codes,
    'play_restore': playRestore,
  },
  'networks': networks,
  'upsell': ?upsell,
};

/// The backend's offer block. Without a block nothing offers Premium.
const Map<String, Object?> _offers = {
  'surfaces': ['top_chip'],
};

/// What the backend answers when it sells nothing to this device: sales
/// on, no plans, and only the code box.
Map<String, dynamic> _codesOnly() => _info(plans: const [], networks: const []);

/// A refusal because Premium is not sold to this device.
const (int, Object?) _notAvailable = (
  422,
  {
    'detail': {'reason': 'not_available', 'message': 'Not here'},
  },
);

/// The answer to a background send of a purchase that runs on another
/// phone that still exists.
const (int, Object?) _heldElsewhere = (
  409,
  {
    'detail': {
      'reason': 'held_elsewhere',
      'message': 'This purchase is in use on another phone.',
    },
  },
);

/// Google is slow, so the send gets no answer for good.
const (int, Object?) _slow = (
  503,
  {
    'detail': {'reason': 'unavailable', 'message': 'Slow'},
  },
);

/// The auto flag of each POST .../billing/google, in order.
List<Object?> _autoFlags(_Backend backend) => [
  for (final r in backend.to('/billing/google')) jsonDecode(r.body)['auto'],
];

/// Everything this phone keeps, so a test can switch between two phones.
Future<Map<String, Object>> _prefsOfThisPhone() async {
  final prefs = await SharedPreferences.getInstance();
  return {for (final k in prefs.getKeys()) k: prefs.get(k)!};
}

/// The backend, answering each payment route from what the test set.
class _Backend {
  Map<String, dynamic> info = _info();
  final List<(int, Object?)> google = [];
  (int, Object?) redeem = (
    200,
    {
      'kind': 'premium',
      'premium': _premium(active: true, code: 'K7QD-3MWX-9TZB-H2CF'),
      'moved': false,
      'quota': _unlimited,
    },
  );
  final List<Object?> orders = [];

  /// Answers POST .../billing/google when set, before [google], for a test
  /// that keeps its own record of which phone holds a purchase.
  (int, Object?) Function(http.Request request)? onGoogle;

  /// Answers by path suffix that come before everything else, such as a
  /// refusal for '/billing/orders'.
  final Map<String, (int, Object?)> refuse = {};
  final List<http.Request> requests = [];

  /// How many times GET .../billing was asked.
  int get loads => to('/billing').length;

  List<http.Request> to(String suffix) => [
    for (final r in requests)
      if (r.url.path.endsWith(suffix)) r,
  ];

  ApiClient get client => ApiClient.forTest(
    direct: MockClient((request) async {
      requests.add(request);
      final path = request.url.path;
      final refusal = [
        for (final e in refuse.entries)
          if (path.endsWith(e.key)) e.value,
      ].firstOrNull;
      final (int, Object?) answer;
      if (refusal != null) {
        answer = refusal;
      } else if (path.endsWith('/billing')) {
        answer = (200, info);
      } else if (path.endsWith('/billing/google') && onGoogle != null) {
        answer = onGoogle!(request);
      } else if (path.endsWith('/billing/google')) {
        answer = google.isEmpty
            ? (
                200,
                {
                  'premium': {
                    'active': true,
                    'source': 'google_play',
                    'auto_renewing': true,
                  },
                  'quota': _unlimited,
                },
              )
            : google.removeAt(0);
      } else if (path.endsWith('/billing/redeem')) {
        answer = redeem;
      } else if (path.contains('/billing/orders')) {
        answer = (200, orders.removeAt(0));
      } else if (path.endsWith('/billing/telegram')) {
        answer = (200, {'url': 'https://t.me/fortiva_pay_bot?start=buy_x'});
      } else {
        answer = (404, {'detail': 'Not Found'});
      }
      return http.Response(
        jsonEncode(answer.$2),
        answer.$1,
        headers: {'content-type': 'application/json'},
      );
    }),
  );
}

class _FakePlay implements PlayBilling {
  final controller = StreamController<List<PlayPurchase>>.broadcast();
  List<PlayProduct> catalog = const [
    PlayProduct(productId: 'premium', basePlanId: 'p30', price: 'EUR 4,99'),
  ];
  List<PlayPurchase> holding = const [];
  final bought = <(String, String)>[];
  final completed = <String>[];
  int calls = 0;

  /// How many times the prices were asked for, and what is owned.
  int productCalls = 0;
  int ownedCalls = 0;

  /// Set to make owned() fail, as a Play query that went wrong does.
  Object? ownedError;

  /// What isAvailable() says, and an error to throw instead, as on a phone
  /// with no Play Store.
  bool available = true;
  Object? availableError;

  @override
  Stream<List<PlayPurchase>> get purchases {
    calls++;
    return controller.stream;
  }

  @override
  Future<bool> isAvailable() async {
    calls++;
    final error = availableError;
    if (error != null) throw error;
    return available;
  }

  @override
  Future<List<PlayProduct>> products(Set<String> productIds) async {
    calls++;
    productCalls++;
    return [
      for (final p in catalog)
        if (productIds.contains(p.productId)) p,
    ];
  }

  @override
  Future<bool> buy(PlayProduct product, {required String accountId}) async {
    calls++;
    bought.add((product.productId, accountId));
    return true;
  }

  @override
  Future<void> complete(PlayPurchase purchase) async {
    completed.add(purchase.token);
  }

  @override
  Future<List<PlayPurchase>> owned() async {
    calls++;
    ownedCalls++;
    final error = ownedError;
    if (error != null) throw error;
    return holding;
  }

  void deliver(PlayPurchase purchase) => controller.add([purchase]);
}

PlayPurchase _paid(String token, {bool needsCompleting = true}) => PlayPurchase(
  productId: 'premium',
  token: token,
  status: PlayPurchaseStatus.purchased,
  needsCompleting: needsCompleting,
);

class _FakeDedicated extends DedicatedState {
  int refreshes = 0;

  @override
  Future<void> refresh({bool? viaTunnel}) async {
    refreshes++;
  }
}

BillingState _state(
  _Backend backend, {
  PlayBilling? play,
  _FakeDedicated? dedicated,
  bool googleSigned = true,
  DateTime Function()? now,
  String device = _device,
}) => BillingState(
  service: BillingService(client: backend.client),
  dedicated: dedicated,
  playBilling: () => play,
  googleSigned: () async => googleSigned,
  deviceId: () async => device,
  now: now,
);

/// A plan sold through another base plan of the same Play product.
const _yearPlan = {
  'code': 'unlimited_365d',
  'days': 365,
  'google': {'product_id': 'premium', 'base_plan_id': 'p365'},
};

const _bothBasePlans = [
  PlayProduct(productId: 'premium', basePlanId: 'p30', price: 'EUR 4,99'),
  PlayProduct(productId: 'premium', basePlanId: 'p365', price: 'EUR 39,99'),
];

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ApiRelays.resetForTest();
  });

  group('what is offered', () {
    test('nothing before the backend has answered', () {
      final billing = _state(_Backend());
      expect(billing.enabled, isFalse);
      expect(billing.showUpsell, isFalse);
      expect(billing.plans, isEmpty);
    });

    test(
      'sales on, something to buy and no Premium shows the upsell',
      () async {
        final billing = _state(
          _Backend()..info = _info(googlePlay: true, upsell: _offers),
          play: _FakePlay(),
        );
        await billing.refresh();
        expect(billing.enabled, isTrue);
        expect(billing.playBilling, isTrue);
        expect(billing.canBuy, isTrue);
        expect(billing.showUpsell, isTrue);
        expect(billing.tile, PremiumTile.premium);
        expect(billing.hasLoaded, isTrue);
      },
    );

    test('sales on with only the code box offers nothing to buy', () async {
      final billing = _state(
        _Backend()..info = _codesOnly(),
        play: _FakePlay(),
      );
      await billing.refresh();
      expect(billing.enabled, isTrue);
      expect(billing.rails.codes, isTrue);
      expect(billing.canBuy, isFalse);
      expect(billing.showUpsell, isFalse);
      expect(billing.tile, PremiumTile.enterCode);
    });

    // (what the backend offers, whether this copy can buy it)
    for (final (name, info, canBuy) in [
      ('Google Play', _info(googlePlay: true), true),
      (
        'Google Play with no Play product on any plan',
        _info(
          googlePlay: true,
          plans: const [
            {'code': 'p', 'days': 30, 'usdt': '4.99'},
          ],
        ),
        false,
      ),
      (
        'crypto and Telegram from an older backend',
        _info(crypto: true, telegram: true),
        false,
      ),
      ('only the code box', _info(), false),
      (
        'everything while sales are off',
        _info(enabled: false, googlePlay: true, crypto: true, telegram: true),
        false,
      ),
    ]) {
      test('${canBuy ? 'can' : 'cannot'} buy: $name', () async {
        final billing = _state(_Backend()..info = info, play: _FakePlay());
        await billing.refresh();
        expect(billing.canBuy, canBuy);
        expect(billing.showUpsell, canBuy);
      });
    }

    test('Play that says it cannot sell here offers nothing', () async {
      final play = _FakePlay()..available = false;
      final billing = _state(
        _Backend()..info = _info(googlePlay: true, upsell: _offers),
        play: play,
      );
      await billing.refresh();
      expect(billing.playSupported, isTrue);
      expect(billing.playBilling, isFalse);
      expect(billing.canBuy, isFalse);
      expect(billing.offersAllowed, isFalse);
      expect(billing.tile, PremiumTile.enterCode);
    });

    test('a phone with no Play Store offers nothing, and nothing '
        'throws', () async {
      final play = _FakePlay()..availableError = Exception('no Play Store');
      final billing = _state(
        _Backend()..info = _info(googlePlay: true, upsell: _offers),
        play: play,
      );
      await billing.start();
      expect(billing.playBilling, isFalse);
      expect(billing.canBuy, isFalse);
      expect(billing.tile, PremiumTile.enterCode);
    });

    test('a device that has Premium is not offered it again', () async {
      final backend = _Backend()..info = _info(premium: true);
      final billing = _state(backend);
      await billing.refresh();
      expect(billing.premium.active, isTrue);
      expect(billing.showUpsell, isFalse);
    });

    test('sales off hides everything but keeps the status', () async {
      final backend = _Backend()..info = _info(enabled: false, premium: true);
      final billing = _state(backend);
      await billing.refresh();
      expect(billing.enabled, isFalse);
      expect(billing.showUpsell, isFalse);
      expect(billing.premium.active, isTrue);
      // The key stays one tap away.
      expect(billing.tile, PremiumTile.premium);
    });

    test('the Settings tile follows the answer', () async {
      final backend = _Backend();
      final billing = _state(backend, play: _FakePlay());
      expect(billing.tile, PremiumTile.hidden, reason: 'before any answer');

      for (final (info, tile) in [
        (_info(enabled: false), PremiumTile.hidden),
        (_info(enabled: false, premium: true), PremiumTile.premium),
        (_info(googlePlay: true, upsell: _offers), PremiumTile.premium),
        // No offer block: nothing offers Premium, and the code box stays.
        (_info(googlePlay: true), PremiumTile.enterCode),
        (_info(googlePlay: true, codes: false), PremiumTile.hidden),
        (_info(googlePlay: true, premium: true), PremiumTile.premium),
        (_codesOnly(), PremiumTile.enterCode),
        (_info(premium: true, plans: const []), PremiumTile.premium),
        (_info(codes: false, plans: const []), PremiumTile.hidden),
      ]) {
        backend.info = info;
        await billing.refresh();
        expect(billing.tile, tile, reason: '$info');
      }
    });

    test('a backend that cannot be reached leaves sales off', () async {
      final billing = BillingState(
        service: BillingService(
          client: ApiClient.forTest(
            direct: MockClient((_) async => throw http.ClientException('cut')),
          ),
        ),
        playBilling: () => null,
        deviceId: () async => _device,
      );
      await billing.refresh();
      expect(billing.enabled, isFalse);
      expect(billing.loadFailed, isTrue);
      expect(billing.hasLoaded, isFalse);
    });

    test('a backend without these routes leaves sales off', () async {
      final billing = BillingState(
        service: BillingService(
          client: ApiClient.forTest(
            direct: MockClient(
              (_) async => http.Response('{"detail":"Not Found"}', 404),
            ),
          ),
        ),
        playBilling: () => null,
        deviceId: () async => _device,
      );
      await billing.refresh();
      expect(billing.enabled, isFalse);
    });

    test('every copy sends store=play', () async {
      for (final signed in [true, false]) {
        final backend = _Backend();
        await _state(backend, googleSigned: signed).refresh();
        expect(
          backend.requests.single.url.queryParameters['store'],
          'play',
          reason: 'signed by Google: $signed',
        );
      }
    });

    test('an older answer with crypto and Telegram rails offers only '
        'Google Play', () async {
      final backend = _Backend()
        ..info = _info(googlePlay: true, crypto: true, telegram: true);
      final billing = _state(backend, play: _FakePlay());
      await billing.refresh();
      expect(billing.rails.googlePlay, isTrue);
      expect(billing.rails.codes, isTrue);
      expect(billing.canBuy, isTrue);
      expect(billing.playPlans.single.code, 'unlimited_30d');
    });

    // The channel APK: the same code, signed with our upload key, where
    // Play refuses to sell.
    test('a copy Google did not sign never touches Play and offers '
        'nothing to buy', () async {
      final play = _FakePlay()..holding = [_paid('token-x')];
      final backend = _Backend()
        ..info = _info(googlePlay: true, playRestore: true, upsell: _offers);
      final billing = _state(backend, play: play, googleSigned: false);
      await billing.start();
      billing.resumed();
      await pumpEventQueue();

      expect(play.calls, 0);
      expect(billing.playSupported, isFalse);
      expect(billing.playBilling, isFalse);
      expect(billing.canBuy, isFalse);
      expect(billing.offersAllowed, isFalse);
      expect(billing.upsellOn(UpsellSurface.topChip), isFalse);
      expect(billing.playPlans, isEmpty);
      // The code box stays one tap away in Settings.
      expect(billing.tile, PremiumTile.enterCode);
      expect(await billing.restorePlay(), RestoreOutcome.unavailable);
      expect(backend.to('/billing/google'), isEmpty);
      expect(play.calls, 0);
    });

    test('a signature check that throws reads as not signed', () async {
      final play = _FakePlay();
      final billing = BillingState(
        service: BillingService(
          client: (_Backend()..info = _info(googlePlay: true)).client,
        ),
        playBilling: () => play,
        googleSigned: () async => throw Exception('no package manager'),
        deviceId: () async => _device,
      );
      await billing.start();
      expect(billing.playSupported, isFalse);
      expect(billing.canBuy, isFalse);
      expect(play.calls, 0);
    });
  });

  group('Google Play', () {
    test('Play is not touched while Play sales are off', () async {
      final play = _FakePlay();
      final backend = _Backend()..info = _info(googlePlay: false);
      final billing = _state(backend, play: play);
      await billing.start();
      billing.resumed();
      await pumpEventQueue();
      expect(play.calls, 0);
      expect(billing.playPlans, isEmpty);
    });

    test('prices come from Play', () async {
      final play = _FakePlay();
      final backend = _Backend()..info = _info(googlePlay: true);
      final billing = _state(backend, play: play);
      await billing.refresh();
      final plan = billing.playPlans.single;
      expect(billing.playProductFor(plan)?.price, 'EUR 4,99');
    });

    test('a plan Play does not sell is not offered', () async {
      final play = _FakePlay()
        ..catalog = const [
          PlayProduct(productId: 'premium', basePlanId: 'p90', price: 'X'),
        ];
      final backend = _Backend()..info = _info(googlePlay: true);
      final billing = _state(backend, play: play);
      await billing.refresh();
      expect(billing.playPlans, isEmpty);
    });

    test(
      'a purchase is completed only after the backend answered 200',
      () async {
        final play = _FakePlay();
        final dedicated = _FakeDedicated();
        final backend = _Backend()..info = _info(googlePlay: true);
        final billing = _state(backend, play: play, dedicated: dedicated);
        await billing.refresh();

        expect(await billing.buyOnPlay(billing.playPlans.single), isTrue);
        expect(billing.playFlow, PlayFlow.buying);
        // The account id is a hash of the device id, never the id itself.
        final accountId = play.bought.single.$2;
        expect(accountId, sha256.convert(utf8.encode(_device)).toString());
        expect(accountId, isNot(contains(_device)));

        play.deliver(_paid('token-1'));
        await pumpEventQueue();

        final sent = backend.to('/billing/google').single;
        expect(jsonDecode(sent.body), {
          'product_id': 'premium',
          'purchase_token': 'token-1',
          'base_plan_id': 'p30',
          // Bought in the app, so the backend may move it here.
          'auto': false,
        });
        expect(play.completed, ['token-1']);
        expect(billing.playFlow, PlayFlow.done);
        expect(billing.premium.active, isTrue);
        expect(billing.premium.autoRenewing, isTrue);
        // The quota card turns Unlimited without waiting for a refresh.
        expect(dedicated.quota?.unlimited, isTrue);
        expect(dedicated.refreshes, greaterThan(0));
        expect(await billing.savedPlayTokens(), isEmpty);
      },
    );

    test('an unconfirmed token is kept, never completed, and sent again on '
        'return to the app', () async {
      final play = _FakePlay();
      final backend = _Backend()
        ..info = _info(googlePlay: true)
        ..google.add((
          503,
          {
            'detail': {'reason': 'unavailable', 'message': 'Google is slow'},
          },
        ));
      final billing = _state(backend, play: play);
      await billing.start();

      play.deliver(_paid('token-2'));
      await pumpEventQueue();

      expect(billing.playFlow, PlayFlow.retrying);
      expect(play.completed, isEmpty);
      expect(await billing.savedPlayTokens(), ['token-2']);

      billing.resumed();
      await pumpEventQueue();

      expect(backend.to('/billing/google'), hasLength(2));
      expect(await billing.savedPlayTokens(), isEmpty);
      expect(billing.premium.active, isTrue);
      // The line under the plans no longer says it is still trying.
      expect(billing.playFlow, PlayFlow.done);
    });

    test('a token saved by an earlier run is sent at launch', () async {
      SharedPreferences.setMockInitialValues({
        'billing_play_unconfirmed': jsonEncode([
          {
            'product_id': 'premium',
            'purchase_token': 'token-3',
            'base_plan_id': 'p30',
          },
        ]),
      });
      // Sales are off now, and the purchase still reaches the backend.
      final backend = _Backend()..info = _info(enabled: false);
      final billing = _state(backend);
      await billing.start();

      final sent = backend.to('/billing/google').single;
      expect(jsonDecode(sent.body)['purchase_token'], 'token-3');
      expect(await billing.savedPlayTokens(), isEmpty);
    });

    test('a purchase the backend refuses for good is dropped', () async {
      final play = _FakePlay();
      final backend = _Backend()
        ..info = _info(googlePlay: true)
        ..google.add((
          422,
          {
            'detail': {'reason': 'invalid_purchase', 'message': 'No'},
          },
        ));
      final billing = _state(backend, play: play);
      await billing.refresh();

      play.deliver(_paid('token-4'));
      await pumpEventQueue();

      expect(billing.playFlow, PlayFlow.refused);
      expect(play.completed, isEmpty);
      expect(await billing.savedPlayTokens(), isEmpty);
      expect(billing.premium.active, isFalse);
    });

    test('a plan the backend does not know yet is kept and retried', () async {
      final play = _FakePlay();
      final backend = _Backend()
        ..info = _info(googlePlay: true)
        ..google.add((
          422,
          {
            'detail': {'reason': 'unknown_product', 'message': 'No plan'},
          },
        ));
      final billing = _state(backend, play: play);
      await billing.refresh();

      play.deliver(_paid('token-5'));
      await pumpEventQueue();

      expect(billing.playFlow, PlayFlow.retrying);
      expect(await billing.savedPlayTokens(), ['token-5']);
    });

    test('a pending payment says so and sends nothing', () async {
      final play = _FakePlay();
      final backend = _Backend()..info = _info(googlePlay: true);
      final billing = _state(backend, play: play);
      await billing.refresh();

      play.deliver(
        const PlayPurchase(
          productId: 'premium',
          token: 'token-6',
          status: PlayPurchaseStatus.pending,
        ),
      );
      await pumpEventQueue();

      expect(billing.playFlow, PlayFlow.pending);
      expect(backend.to('/billing/google'), isEmpty);
    });

    test('a canceled sheet goes back to idle', () async {
      final play = _FakePlay();
      final backend = _Backend()..info = _info(googlePlay: true);
      final billing = _state(backend, play: play);
      await billing.refresh();
      await billing.buyOnPlay(billing.playPlans.single);

      play.deliver(
        const PlayPurchase(
          productId: 'premium',
          token: '',
          status: PlayPurchaseStatus.canceled,
        ),
      );
      await pumpEventQueue();

      expect(billing.playFlow, PlayFlow.idle);
      expect(billing.playBusy, isFalse);
    });

    test('a purchase Play still holds is confirmed at launch', () async {
      final play = _FakePlay()..holding = [_paid('token-7')];
      final backend = _Backend()..info = _info(googlePlay: true);
      final billing = _state(backend, play: play);
      await billing.start();

      expect(backend.to('/billing/google'), hasLength(1));
      // Found by the background check, so it may not move the purchase.
      expect(_autoFlags(backend), [true]);
      expect(play.completed, ['token-7']);
      expect(billing.premium.active, isTrue);
      // Found in the background, so the screen's line is left alone.
      expect(billing.playFlow, PlayFlow.idle);
    });

    test(
      'Restore sends what the account owns, even when acknowledged',
      () async {
        final play = _FakePlay()
          ..holding = [_paid('token-8', needsCompleting: false)];
        final backend = _Backend()..info = _info(googlePlay: true);
        final billing = _state(backend, play: play);
        await billing.refresh();
        // Already acknowledged, so the launch check left it alone.
        expect(backend.to('/billing/google'), isEmpty);

        expect(await billing.restorePlay(), RestoreOutcome.restored);
        expect(backend.to('/billing/google'), hasLength(1));
        expect(billing.premium.active, isTrue);
      },
    );

    test('Restore with nothing owned says so', () async {
      final play = _FakePlay();
      final backend = _Backend()..info = _info(googlePlay: true);
      final billing = _state(backend, play: play);
      await billing.refresh();
      expect(await billing.restorePlay(), RestoreOutcome.nothing);
    });

    test('without Play on this phone, Restore is unavailable', () async {
      final billing = _state(_Backend()..info = _info(googlePlay: true));
      await billing.refresh();
      expect(billing.playSupported, isFalse);
      expect(await billing.restorePlay(), RestoreOutcome.unavailable);
    });
  });

  group('codes', () {
    test('a key turns Premium on and the quota card Unlimited', () async {
      final dedicated = _FakeDedicated();
      final backend = _Backend();
      final billing = _state(backend, dedicated: dedicated);
      await billing.refresh();

      final result = await billing.redeem('K7QD-3MWX-9TZB-H2CF');

      expect(result.isPremium, isTrue);
      expect(billing.premium.active, isTrue);
      expect(billing.premium.code, 'K7QD-3MWX-9TZB-H2CF');
      expect(billing.showUpsell, isFalse);
      expect(dedicated.quota?.unlimited, isTrue);
      expect(dedicated.refreshes, 1);
    });

    test('a refusal throws with its reason and changes nothing', () async {
      final dedicated = _FakeDedicated();
      final backend = _Backend()
        ..redeem = (
          409,
          {
            'detail': {'reason': 'moved_too_often', 'message': 'No'},
          },
        );
      final billing = _state(backend, dedicated: dedicated);
      await billing.refresh();

      await expectLater(
        billing.redeem('K7QD-3MWX-9TZB-H2CF'),
        throwsA(
          isA<BillingException>().having(
            (e) => e.reason,
            'reason',
            'moved_too_often',
          ),
        ),
      );
      expect(billing.premium.active, isFalse);
      expect(dedicated.refreshes, 0);
    });
  });

  // The backend refuses with not_available when Premium is not sold to
  // this device. What the phone loaded earlier still offers it, so a
  // refusal the user caused loads the answer again and the entry points
  // follow at once. A Play purchase refused this way is not kept and not
  // completed, so Play refunds it.
  group('not available here', () {
    Matcher refusedAsNotAvailable() => throwsA(
      isA<BillingException>().having(
        (e) => e.reason,
        'reason',
        BillingException.notAvailable,
      ),
    );

    test('a code refused as not available loads the answer again', () async {
      final backend = _Backend()..redeem = _notAvailable;
      final billing = _state(backend);
      await billing.refresh();
      expect(backend.loads, 1);

      await expectLater(
        billing.redeem('K7QD-3MWX-9TZB-H2CF'),
        refusedAsNotAvailable(),
      );
      await pumpEventQueue();

      expect(backend.loads, 2);
      expect(billing.premium.active, isFalse);
    });

    test('other refusals do not load again', () async {
      final backend = _Backend()
        ..redeem = (
          422,
          {
            'detail': {'reason': 'expired', 'message': 'Old'},
          },
        );
      final billing = _state(backend);
      await billing.refresh();

      await expectLater(
        billing.redeem('K7QD-3MWX-9TZB-H2CF'),
        throwsA(isA<BillingException>()),
      );
      await pumpEventQueue();

      expect(backend.loads, 1);
    });

    test('a Play purchase refused as not available says so, is dropped '
        'and never completed', () async {
      final play = _FakePlay();
      final backend = _Backend()
        ..info = _info(googlePlay: true)
        ..google.add(_notAvailable);
      final billing = _state(backend, play: play);
      await billing.refresh();
      final loads = backend.loads;

      play.deliver(_paid('token-na'));
      await pumpEventQueue();

      expect(billing.playFlow, PlayFlow.notAvailable);
      expect(play.completed, isEmpty);
      expect(await billing.savedPlayTokens(), isEmpty);
      expect(billing.premium.active, isFalse);
      expect(backend.loads, loads + 1);
    });

    test('a purchase found in the background and refused as not '
        'available loads nothing again', () async {
      // A load finds the purchase again, so loading on its refusal would
      // go round in a circle.
      final play = _FakePlay()..holding = [_paid('token-bg')];
      final backend = _Backend()
        ..info = _info(googlePlay: true)
        ..refuse['/billing/google'] = _notAvailable;
      final billing = _state(backend, play: play);
      await billing.start();
      await pumpEventQueue();

      expect(backend.to('/billing/google'), hasLength(1));
      expect(backend.loads, 1);
      expect(billing.playFlow, PlayFlow.idle);
      expect(play.completed, isEmpty);
    });

    test('Restore refused as not available says so', () async {
      final play = _FakePlay()
        ..holding = [_paid('token-r', needsCompleting: false)];
      final backend = _Backend()
        ..info = _info(googlePlay: true)
        ..refuse['/billing/google'] = _notAvailable;
      final billing = _state(backend, play: play);
      await billing.refresh();

      expect(await billing.restorePlay(), RestoreOutcome.notAvailable);
      await pumpEventQueue();
      expect(backend.loads, 2);
    });

    test('Restore that restores one purchase is a restore, whatever the '
        'others got', () async {
      final play = _FakePlay()
        ..holding = [
          _paid('token-a', needsCompleting: false),
          _paid('token-b', needsCompleting: false),
        ];
      final backend = _Backend()
        ..info = _info(googlePlay: true)
        ..google.add(_notAvailable);
      final billing = _state(backend, play: play);
      await billing.refresh();

      expect(await billing.restorePlay(), RestoreOutcome.restored);
    });
  });

  // Restoring is apart from selling. The backend sends play_restore on
  // whenever Google Play is set up on its side, whatever is on sale, so a
  // subscriber on a new phone gets Premium back, and a purchase Play still
  // holds is always reported. Both happen in the background: no new way in
  // shows while they do.
  group('Google Play restores, apart from sales', () {
    test('sales off keeps play_restore and nothing else', () {
      final info = BillingInfo.fromJson(
        _info(
          enabled: false,
          googlePlay: true,
          crypto: true,
          telegram: true,
          playRestore: true,
        ),
      );
      expect(info.enabled, isFalse);
      expect(info.rails.playRestore, isTrue);
      expect(info.rails.googlePlay, isFalse);
      expect(info.rails.codes, isFalse);
      expect(info.plans, isEmpty);
    });

    test('with only restores on, Play is asked what the account owns at '
        'launch and sells nothing', () async {
      final play = _FakePlay();
      final backend = _Backend()
        ..info = _info(enabled: false, playRestore: true);
      final billing = _state(backend, play: play);
      await billing.start();

      expect(play.ownedCalls, 1);
      expect(play.productCalls, 0);
      expect(billing.playPlans, isEmpty);
      expect(billing.canBuy, isFalse);
      expect(billing.tile, PremiumTile.hidden);
      expect(backend.to('/billing/google'), isEmpty);
    });

    test('a purchase Play still holds is confirmed at launch while sales '
        'are off', () async {
      final play = _FakePlay()..holding = [_paid('token-held')];
      final backend = _Backend()
        ..info = _info(enabled: false, playRestore: true);
      final billing = _state(backend, play: play);
      await billing.start();

      expect(backend.to('/billing/google'), hasLength(1));
      expect(play.completed, ['token-held']);
      expect(billing.premium.active, isTrue);
    });

    test('a purchase Play holds is confirmed on return to the app', () async {
      final play = _FakePlay();
      final backend = _Backend()
        ..info = _info(enabled: false, playRestore: true);
      final billing = _state(backend, play: play);
      await billing.start();
      expect(backend.to('/billing/google'), isEmpty);

      // A slow payment went through while the app was in the background.
      play.holding = [_paid('token-late')];
      billing.resumed();
      await pumpEventQueue();

      expect(backend.loads, 1, reason: 'the answer is fresh');
      expect(backend.to('/billing/google'), hasLength(1));
      expect(play.completed, ['token-late']);
    });

    test('a phone without Premium gets back what the account pays for at '
        'launch, with no way in shown first', () async {
      final play = _FakePlay()
        ..holding = [_paid('token-owned', needsCompleting: false)];
      final backend = _Backend()
        ..info = _info(enabled: false, playRestore: true);
      final billing = _state(backend, play: play);
      expect(billing.tile, PremiumTile.hidden);
      await billing.start();

      final sent = backend.to('/billing/google').single;
      expect(jsonDecode(sent.body)['purchase_token'], 'token-owned');
      expect(jsonDecode(sent.body)['auto'], isTrue);
      expect(billing.premium.active, isTrue);
      // Shown now because the device has Premium.
      expect(billing.tile, PremiumTile.premium);
    });

    test('a purchase is restored on its own once per phone', () async {
      final play = _FakePlay()
        ..holding = [_paid('token-once', needsCompleting: false)];
      final backend = _Backend()
        ..info = _info(enabled: false, playRestore: true);
      await _state(backend, play: play).start();
      expect(backend.to('/billing/google'), hasLength(1));

      // The next launch finds it gone from this phone: another phone on the
      // same Google account took it back. This phone does not take it again.
      final next = _state(backend, play: play);
      await next.start();
      next.resumed();
      await pumpEventQueue();
      expect(backend.to('/billing/google'), hasLength(1));

      // The user can still restore it by hand, which may move it here.
      expect(await next.restorePlay(), RestoreOutcome.restored);
      expect(_autoFlags(backend), [true, false]);
    });

    test('a send that gets no answer is sent again until the backend '
        'answers, and is not restored on its own again', () async {
      final play = _FakePlay()
        ..holding = [_paid('token-r', needsCompleting: false)];
      final backend = _Backend()
        ..info = _info(enabled: false, playRestore: true)
        ..google.addAll([
          (
            503,
            {
              'detail': {'reason': 'unavailable', 'message': 'Slow'},
            },
          ),
          (
            409,
            {
              'detail': {'reason': 'moved_too_often', 'message': 'No'},
            },
          ),
        ]);
      final billing = _state(backend, play: play);
      await billing.start();

      // The first try got no answer, and the kept token was sent again
      // before launch was done. The backend refused it for good.
      expect(backend.to('/billing/google'), hasLength(2));
      expect(await billing.savedPlayTokens(), isEmpty);
      expect(billing.premium.active, isFalse);

      await _state(backend, play: play).start();
      expect(backend.to('/billing/google'), hasLength(2));
    });

    test('a phone that has Premium restores nothing on its own', () async {
      final play = _FakePlay()
        ..holding = [_paid('token-p', needsCompleting: false)];
      final backend = _Backend()
        ..info = _info(enabled: false, playRestore: true, premium: true);
      await _state(backend, play: play).start();

      expect(play.ownedCalls, 1);
      expect(backend.to('/billing/google'), isEmpty);
    });

    test('without play_restore, nothing is restored on its own', () async {
      // Sales on, from a backend older than play_restore.
      final play = _FakePlay()
        ..holding = [_paid('token-old', needsCompleting: false)];
      final backend = _Backend()..info = _info(googlePlay: true);
      await _state(backend, play: play).start();

      expect(backend.to('/billing/google'), isEmpty);
    });

    test('a copy Google did not sign never restores from Play', () async {
      final play = _FakePlay()..holding = [_paid('token-x')];
      final backend = _Backend()
        ..info = _info(enabled: false, playRestore: true);
      final billing = _state(backend, play: play, googleSigned: false);
      await billing.start();
      billing.resumed();
      await pumpEventQueue();

      expect(billing.playSupported, isFalse);
      expect(play.calls, 0);
      expect(backend.to('/billing/google'), isEmpty);
      expect(billing.tile, PremiumTile.hidden);
    });
  });

  // Two phones signed in to one Google account both see its purchases.
  // The background check sends auto true, and the backend then never moves
  // a purchase that runs on another phone: it answers held_elsewhere. Each
  // phone notes every token it has handled and never sends it from the
  // background check again, so neither phone takes the subscription from
  // the other on its own, and the move limit is spent only when a user
  // taps Restore purchases.
  group('two phones on one Google account', () {
    test(
      'neither phone takes the purchase from the other on its own',
      () async {
        // The backend's record: which phone the purchase runs on, and how
        // many times it moved between phones.
        String? holder;
        var moves = 0;
        (int, Object?) answer(http.Request request) {
          final phone = request.url.pathSegments[3];
          final auto = jsonDecode(request.body)['auto'] == true;
          if (holder != null && holder != phone) {
            if (auto) return _heldElsewhere;
            moves++;
          }
          holder = phone;
          return (
            200,
            {
              'premium': {'active': true, 'source': 'google_play'},
              'quota': _unlimited,
            },
          );
        }

        // Phone A buys in the app.
        final backendA = _Backend()
          ..info = _info(googlePlay: true, playRestore: true)
          ..onGoogle = answer;
        final playA = _FakePlay();
        final phoneA = _state(backendA, play: playA, device: 'PHONE-A');
        await phoneA.start();
        expect(await phoneA.buyOnPlay(phoneA.playPlans.single), isTrue);
        playA.deliver(_paid('token-shared'));
        await pumpEventQueue();

        expect(holder, 'PHONE-A');
        expect(_autoFlags(backendA), [false]);
        expect(await phoneA.handledPlayTokens(), {'token-shared'});
        final prefsA = await _prefsOfThisPhone();

        // Phone B has no Premium and finds the purchase at launch and on
        // every return to the app, then launches again.
        SharedPreferences.setMockInitialValues({});
        final backendB = _Backend()
          ..info = _info(enabled: false, playRestore: true)
          ..onGoogle = answer;
        final playB = _FakePlay()
          ..holding = [_paid('token-shared', needsCompleting: false)];
        final phoneB = _state(backendB, play: playB, device: 'PHONE-B');
        await phoneB.start();
        for (var i = 0; i < 3; i++) {
          phoneB.resumed();
          await pumpEventQueue();
        }
        await _state(backendB, play: playB, device: 'PHONE-B').start();

        // Asked once with auto true, refused, and never asked again.
        expect(_autoFlags(backendB), [true]);
        expect(holder, 'PHONE-A');
        expect(moves, 0);
        expect(phoneB.premium.active, isFalse);
        expect(phoneB.playFlow, PlayFlow.idle);
        expect(phoneB.isRestoring, isFalse);
        expect(await phoneB.savedPlayTokens(), isEmpty);
        expect(await phoneB.handledPlayTokens(), {'token-shared'});

        // Phone B's user taps Restore purchases, which moves it there once.
        expect(await phoneB.restorePlay(), RestoreOutcome.restored);
        expect(_autoFlags(backendB), [true, false]);
        expect(holder, 'PHONE-B');
        expect(moves, 1);

        // Phone A has no Premium now and still sees the purchase in Play. It
        // bought it, so its background check does not take it back.
        SharedPreferences.setMockInitialValues(prefsA);
        playA.holding = [_paid('token-shared', needsCompleting: false)];
        final nextA = _state(backendA, play: playA, device: 'PHONE-A');
        await nextA.start();
        nextA.resumed();
        await pumpEventQueue();

        expect(_autoFlags(backendA), [false]);
        expect(holder, 'PHONE-B');
        expect(moves, 1);
      },
    );

    test('a background send with no answer is sent again with auto true, '
        'and held_elsewhere ends it for good', () async {
      final play = _FakePlay()
        ..holding = [_paid('token-held', needsCompleting: false)];
      final backend = _Backend()
        ..info = _info(enabled: false, playRestore: true)
        ..google.addAll([_slow, _heldElsewhere]);
      final billing = _state(backend, play: play);
      await billing.start();

      // The kept token was sent again from the phone's notes before
      // launch was done, with the flag it was first sent with.
      expect(_autoFlags(backend), [true, true]);
      expect(await billing.savedPlayTokens(), isEmpty);
      expect(await billing.handledPlayTokens(), {'token-held'});
      expect(billing.premium.active, isFalse);
      expect(billing.playFlow, PlayFlow.idle);

      billing.resumed();
      await pumpEventQueue();
      await _state(backend, play: play).start();
      expect(_autoFlags(backend), [true, true]);
    });

    test('a purchase Play still waits on goes with auto true, and once '
        'held elsewhere it is only completed in Play', () async {
      final play = _FakePlay()..holding = [_paid('token-wait')];
      final backend = _Backend()
        ..info = _info(enabled: false, playRestore: true)
        ..google.add(_heldElsewhere);
      final billing = _state(backend, play: play);
      await billing.start();

      expect(_autoFlags(backend), [true]);
      expect(play.completed, isEmpty);
      expect(await billing.handledPlayTokens(), {'token-wait'});

      // The next check does not ask the backend again. Another phone's
      // license holds the purchase, so Play is told it was delivered.
      billing.resumed();
      await pumpEventQueue();
      expect(_autoFlags(backend), [true]);
      expect(play.completed, ['token-wait']);
    });

    test('a purchase and Restore purchases send auto false and note their '
        'tokens', () async {
      final play = _FakePlay();
      final backend = _Backend()..info = _info(googlePlay: true);
      final billing = _state(backend, play: play);
      await billing.start();

      await billing.buyOnPlay(billing.playPlans.single);
      play.deliver(_paid('token-bought'));
      await pumpEventQueue();
      play.holding = [_paid('token-other', needsCompleting: false)];
      expect(await billing.restorePlay(), RestoreOutcome.restored);

      expect(_autoFlags(backend), [false, false]);
      expect(await billing.handledPlayTokens(), {
        'token-bought',
        'token-other',
      });

      // Premium has ended on this phone, and Play still lists both. The
      // background check sends neither.
      backend.info = _info(googlePlay: true, playRestore: true);
      play.holding = [
        _paid('token-bought', needsCompleting: false),
        _paid('token-other', needsCompleting: false),
      ];
      final next = _state(backend, play: play);
      await next.start();
      next.resumed();
      await pumpEventQueue();
      expect(_autoFlags(backend), [false, false]);
    });

    test('Restore purchases that got no answer is sent again with auto '
        'false', () async {
      final play = _FakePlay()
        ..holding = [_paid('token-hand', needsCompleting: false)];
      final backend = _Backend()
        ..info = _info(googlePlay: true)
        ..google.add(_slow);
      final billing = _state(backend, play: play);
      await billing.refresh();

      expect(await billing.restorePlay(), RestoreOutcome.failed);
      expect(await billing.savedPlayTokens(), ['token-hand']);
      expect(await billing.handledPlayTokens(), isEmpty);

      // The next launch restores on its own, but this token is waiting as
      // the user's request, and goes again as they asked.
      backend.info = _info(googlePlay: true, playRestore: true);
      final next = _state(backend, play: play);
      await next.start();

      expect(_autoFlags(backend), [false, false]);
      expect(next.premium.active, isTrue);
      expect(await next.handledPlayTokens(), {'token-hand'});
    });

    test('a purchase still waiting for the backend keeps auto false when the '
        'background check finds it', () async {
      final play = _FakePlay();
      final backend = _Backend()
        ..info = _info(googlePlay: true, playRestore: true)
        ..google.add(_slow);
      final billing = _state(backend, play: play);
      await billing.start();

      await billing.buyOnPlay(billing.playPlans.single);
      play.deliver(_paid('token-mine'));
      await pumpEventQueue();
      expect(billing.playFlow, PlayFlow.retrying);

      // The next launch's check finds it in Play before the kept token is
      // sent again. It was bought here, so it still goes with auto false.
      play.holding = [_paid('token-mine')];
      await _state(backend, play: play).start();

      expect(_autoFlags(backend), [false, false]);
      expect(play.completed, ['token-mine']);
      expect(await billing.savedPlayTokens(), isEmpty);
    });
  });

  group('the line under the plans', () {
    test('a purchase refused for good on a later try says so', () async {
      final play = _FakePlay();
      final backend = _Backend()
        ..info = _info(googlePlay: true)
        ..google.addAll([
          (
            503,
            {
              'detail': {'reason': 'unavailable', 'message': 'Slow'},
            },
          ),
          (
            422,
            {
              'detail': {'reason': 'invalid_purchase', 'message': 'No'},
            },
          ),
        ]);
      final billing = _state(backend, play: play);
      await billing.start();

      play.deliver(_paid('token-r'));
      await pumpEventQueue();
      expect(billing.playFlow, PlayFlow.retrying);

      billing.resumed();
      await pumpEventQueue();
      expect(billing.playFlow, PlayFlow.refused);
      expect(await billing.savedPlayTokens(), isEmpty);
    });

    test('a pending payment confirmed in the background says Premium is '
        'on', () async {
      final play = _FakePlay();
      final backend = _Backend()..info = _info(googlePlay: true);
      final billing = _state(backend, play: play);
      await billing.start();

      play.deliver(
        const PlayPurchase(
          productId: 'premium',
          token: 'token-p',
          status: PlayPurchaseStatus.pending,
        ),
      );
      await pumpEventQueue();
      expect(billing.playFlow, PlayFlow.pending);

      // It went through while the app was away, and Play reports it when
      // asked rather than on the stream.
      play.holding = [_paid('token-p')];
      billing.resumed();
      await pumpEventQueue();

      expect(billing.premium.active, isTrue);
      expect(billing.playFlow, PlayFlow.done);
    });

    test('another purchase confirmed in the background leaves the line '
        'alone', () async {
      final play = _FakePlay();
      final backend = _Backend()
        ..info = _info(googlePlay: true)
        ..google.add((
          503,
          {
            'detail': {'reason': 'unavailable', 'message': 'Slow'},
          },
        ));
      final billing = _state(backend, play: play);
      await billing.start();

      play.deliver(_paid('token-a'));
      await pumpEventQueue();
      expect(billing.playFlow, PlayFlow.retrying);

      play.holding = [_paid('token-b', needsCompleting: false)];
      expect(await billing.restorePlay(), RestoreOutcome.restored);
      expect(billing.playFlow, PlayFlow.retrying);
    });
  });

  group('a Play query that fails', () {
    test('Restore says Play is not available, not that nothing is '
        'owned', () async {
      final play = _FakePlay()..ownedError = const PlayQueryException('down');
      final backend = _Backend()..info = _info(googlePlay: true);
      final billing = _state(backend, play: play);
      await billing.start();

      expect(await billing.restorePlay(), RestoreOutcome.unavailable);
    });

    PurchaseDetails purchase(String token) =>
        GooglePlayPurchaseDetails.fromPurchase(
          PurchaseWrapper(
            orderId: 'GPA.1',
            packageName: 'com.vpn.fortivavpn',
            purchaseTime: 0,
            purchaseToken: token,
            signature: 'sig',
            products: const ['premium'],
            isAutoRenewing: true,
            originalJson: '{}',
            isAcknowledged: true,
            purchaseState: PurchaseStateWrapper.purchased,
          ),
        ).single;

    IAPError error() =>
        IAPError(source: 'google_play', code: 'restore_failed', message: 'x');

    test('a failed query with nothing in it throws', () {
      expect(
        () => GooglePlayBilling.ownedFrom(
          QueryPurchaseDetailsResponse(pastPurchases: const [], error: error()),
        ),
        throwsA(isA<PlayQueryException>()),
      );
    });

    test('what came back is kept when only the other half failed', () {
      final owned = GooglePlayBilling.ownedFrom(
        QueryPurchaseDetailsResponse(
          pastPurchases: [purchase('token-sub') as GooglePlayPurchaseDetails],
          error: error(),
        ),
      );
      expect(owned.single.token, 'token-sub');
    });

    test('a query that worked and found nothing is nothing', () {
      expect(
        GooglePlayBilling.ownedFrom(
          QueryPurchaseDetailsResponse(pastPurchases: const []),
        ),
        isEmpty,
      );
    });
  });

  // A return to the app loads the answer again only once it is old.
  group('back in the app', () {
    test('a return soon after a load loads nothing, and a return after '
        'refreshAfter loads again', () async {
      var clock = DateTime.utc(2026, 10, 8, 12);
      final backend = _Backend()..info = _info(googlePlay: true);
      final billing = _state(backend, now: () => clock);
      await billing.start();
      expect(backend.loads, 1);

      clock = clock.add(const Duration(minutes: 2));
      billing.resumed();
      await pumpEventQueue();
      expect(backend.loads, 1);

      clock = clock.add(BillingState.refreshAfter);
      billing.resumed();
      await pumpEventQueue();
      expect(backend.loads, 2);
    });
  });

  // The support chat sends play_billing with each question.
  group('whether this copy can buy through Play, for the support chat', () {
    test('true in the copy Google signed, where Play can sell', () async {
      final billing = _state(_Backend(), play: _FakePlay());
      expect(await billing.checkPlayBilling(), isTrue);
    });

    test('asks Play itself when no load has, as while Play sales are '
        'off', () async {
      final play = _FakePlay();
      final billing = _state(
        _Backend()..info = _info(enabled: false),
        play: play,
      );
      await billing.start();
      expect(play.calls, 0);
      expect(await billing.checkPlayBilling(), isTrue);
      expect(billing.playBilling, isTrue);
    });

    test('false in a copy Google did not sign, without asking Play', () async {
      final play = _FakePlay();
      final billing = _state(_Backend(), play: play, googleSigned: false);
      expect(await billing.checkPlayBilling(), isFalse);
      expect(play.calls, 0);
    });

    test('false where Play cannot sell, or does not answer', () async {
      final billing = _state(_Backend(), play: _FakePlay()..available = false);
      expect(await billing.checkPlayBilling(), isFalse);

      final broken = _state(
        _Backend(),
        play: _FakePlay()..availableError = Exception('no Play Store'),
      );
      expect(await broken.checkPlayBilling(), isFalse);
    });

    test('false off Android, where there is no Play', () async {
      final billing = _state(_Backend());
      expect(await billing.checkPlayBilling(), isFalse);
    });
  });

  // docs/payments.md lets a plan name a Play product and no base plan: it
  // takes the product's base plans no other plan names, as the backend
  // matches purchases.
  group('a plan with a Play product and no base plan', () {
    const looseYear = {
      'code': 'unlimited_365d',
      'days': 365,
      'google': {'product_id': 'premium'},
    };

    test('takes the base plan no other plan names, whatever Play\'s '
        'order', () async {
      for (final catalog in [
        _bothBasePlans,
        _bothBasePlans.reversed.toList(),
      ]) {
        final play = _FakePlay()..catalog = catalog;
        final backend = _Backend()
          ..info = _info(googlePlay: true, plans: const [_fullPlan, looseYear]);
        final billing = _state(backend, play: play);
        await billing.refresh();

        final month = billing.plans.firstWhere(
          (p) => p.code == 'unlimited_30d',
        );
        final year = billing.plans.firstWhere(
          (p) => p.code == 'unlimited_365d',
        );
        expect(billing.playProductFor(month)?.basePlanId, 'p30');
        expect(billing.playProductFor(year)?.basePlanId, 'p365');
        expect(billing.playProductFor(year)?.price, 'EUR 39,99');

        // A purchase of it says which base plan it bought.
        await billing.buyOnPlay(year);
        play.deliver(_paid('token-year'));
        await pumpEventQueue();
        final sent = jsonDecode(backend.to('/billing/google').single.body);
        expect(sent['base_plan_id'], 'p365');
      }
    });

    test('is not offered when several base plans are left', () async {
      final play = _FakePlay()..catalog = _bothBasePlans;
      final backend = _Backend()
        ..info = _info(googlePlay: true, plans: const [looseYear]);
      final billing = _state(backend, play: play);
      await billing.refresh();

      expect(billing.playProductFor(billing.plans.single), isNull);
      expect(billing.playPlans, isEmpty);
    });

    test('takes a product\'s only base plan', () async {
      final play = _FakePlay();
      final backend = _Backend()
        ..info = _info(googlePlay: true, plans: const [looseYear]);
      final billing = _state(backend, play: play);
      await billing.refresh();

      expect(billing.playProductFor(billing.plans.single)?.basePlanId, 'p30');
    });
  });

  test('the account id is the SHA-256 of the device id in lower-case hex', () {
    for (final id in ['DEV-1', 'a1B2-c3D4', 'device id with spaces']) {
      final account = BillingState.playAccountId(id);
      expect(account, matches(RegExp(r'^[0-9a-f]{64}$')));
      expect(account, sha256.convert(utf8.encode(id)).toString());
    }
  });

  // Play holds one base plan of a subscription per account at a time.
  group('a phone that already subscribes', () {
    test('is not sold another plan of the product the account owns', () async {
      final play = _FakePlay()
        ..catalog = _bothBasePlans
        ..holding = [_paid('token-sub', needsCompleting: false)];
      final backend = _Backend()
        ..info = _info(googlePlay: true, plans: const [_fullPlan, _yearPlan]);
      final billing = _state(backend, play: play);
      await billing.refresh();

      for (final plan in billing.playPlans) {
        expect(billing.playSubscribedTo(plan), isTrue, reason: plan.code);
        expect(await billing.buyOnPlay(plan), isFalse);
      }
      expect(play.bought, isEmpty);
      expect(billing.playFlow, PlayFlow.idle);
      expect(
        billing.playManageUrl,
        Uri.parse(
          'https://play.google.com/store/account/subscriptions'
          '?sku=premium&package=com.vpn.fortivavpn',
        ),
      );
    });

    test('sees the plan its Premium comes from as the current one', () async {
      final play = _FakePlay()..catalog = _bothBasePlans;
      final backend = _Backend()
        ..info = _info(
          googlePlay: true,
          premium: true,
          source: 'google_play',
          plans: const [_fullPlan, _yearPlan],
        );
      final billing = _state(backend, play: play);
      await billing.refresh();

      final month = billing.plans.firstWhere((p) => p.code == 'unlimited_30d');
      final year = billing.plans.firstWhere((p) => p.code == 'unlimited_365d');
      expect(billing.isCurrentPlayPlan(month), isTrue);
      expect(billing.isCurrentPlayPlan(year), isFalse);
      expect(billing.playSubscribedTo(year), isTrue);
      expect(billing.playManageUrl.queryParameters, {
        'sku': 'premium',
        'package': 'com.vpn.fortivavpn',
      });
    });

    test('a phone with Premium from a key is still sold Play plans', () async {
      final play = _FakePlay()..catalog = _bothBasePlans;
      final backend = _Backend()
        ..info = _info(
          googlePlay: true,
          premium: true,
          plans: const [_fullPlan, _yearPlan],
        );
      final billing = _state(backend, play: play);
      await billing.refresh();

      expect(billing.playPlans.any(billing.playSubscribedTo), isFalse);
      expect(billing.currentPlayPlan, isNull);
      // With nothing to point at, the link opens every subscription.
      expect(
        billing.playManageUrl,
        Uri.parse('https://play.google.com/store/account/subscriptions'),
      );
    });
  });

  group('billing periods from Play', () {
    for (final (iso, count, unit) in [
      ('P1D', 1, PlayPeriodUnit.day),
      ('P7D', 7, PlayPeriodUnit.day),
      ('P1W', 1, PlayPeriodUnit.week),
      ('P1M', 1, PlayPeriodUnit.month),
      ('P3M', 3, PlayPeriodUnit.month),
      ('P6M', 6, PlayPeriodUnit.month),
      ('P1Y', 1, PlayPeriodUnit.year),
      (' p1m ', 1, PlayPeriodUnit.month),
    ]) {
      test('$iso is $count $unit', () {
        final period = PlayPeriod.parse(iso);
        expect(period?.count, count);
        expect(period?.unit, unit);
      });
    }

    for (final iso in [null, '', 'P', 'P0M', 'P1Y6M', 'PT1H', 'P1.5M', '1M']) {
      test('"$iso" is no period', () => expect(PlayPeriod.parse(iso), isNull));
    }
  });

  test('account deletion forgets the status and the catalog', () async {
    final backend = _Backend()..info = _info(premium: true);
    final billing = _state(backend);
    await billing.refresh();
    billing.reset();
    expect(billing.enabled, isFalse);
    expect(billing.premium.active, isFalse);
    expect(billing.plans, isEmpty);
  });

  test('a grant hands the quota to the servers state', () {
    // The same object the quota card reads.
    final dedicated = _FakeDedicated();
    dedicated.adoptQuota(
      const QuotaStatus(
        unlimited: true,
        limitBytes: 0,
        usedBytes: 0,
        remainingBytes: 0,
        blocked: false,
      ),
    );
    expect(dedicated.quota?.unlimited, isTrue);
    expect(dedicated.isBlocked, isFalse);
  });
}
