import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/api/api_client.dart';
import 'package:fortiva_vpn/api/api_routes.dart';
import 'package:fortiva_vpn/api/billing_service.dart';
import 'package:fortiva_vpn/api/config_service.dart';
import 'package:fortiva_vpn/core/form_factor.dart';
import 'package:fortiva_vpn/core/state/billing_state.dart';
import 'package:fortiva_vpn/core/state/dedicated_state.dart';
import 'package:fortiva_vpn/data/models/billing.dart';
import 'package:fortiva_vpn/services/play_billing.dart';
import 'package:fortiva_vpn/services/vpn_event_reporter.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The gate every Premium offer goes through (BillingState.upsellOn).
///
/// An offer shows only when all of these hold: the backend's `upsell`
/// block names its surface, this copy can buy through Google Play here and
/// the device is not Premium, and the tunnel has worked on this install. A
/// copy Google Play did not sign, such as the channel APK, cannot buy
/// through Play, so it is offered nothing. The backend leaves
/// the block out for any device it wants no offer on, and with no block
/// nothing offers Premium. Where the phone is plays no part, see
/// test/offers_every_country_test.dart.
///
/// Nothing is offered on a TV, so the remote's focus order stays as it is.

/// Billing with a fixed answer. [googleSigned] is what the signature check
/// said: true for the copy Google Play signed, false for any other.
class _FixedBilling extends BillingState {
  _FixedBilling(
    BillingInfo info, {
    bool worked = true,
    super.dedicated,
    bool googleSigned = true,
    bool playAvailable = true,
  }) : super(
         service: BillingService(
           client: ApiClient.forTest(
             direct: MockClient((_) async => throw http.ClientException('no')),
           ),
         ),
         playBilling: () => _Play(),
         deviceId: () async => 'DEV-1',
       ) {
    adoptForTest(
      info,
      googleSigned: googleSigned,
      playAvailable: playAvailable,
    );
    adoptWorkedForTest(worked: worked);
  }

  @override
  Future<void> refresh() async {}
}

const _playPlan = Plan(
  code: 'unlimited_30d',
  google: PlayProductRef(productId: 'premium', basePlanId: 'p30'),
);

/// Every surface on, with the numbers each needs.
final _allSurfaces = Upsell(
  surfaces: UpsellSurface.values.toSet(),
  nudgeUsedPercent: 80,
  promptEveryHours: 168,
  promptMax: 3,
);

BillingInfo _on({Upsell? upsell, Renewal? renewal}) => BillingInfo(
  enabled: true,
  plans: const [_playPlan],
  rails: const Rails(googlePlay: true, codes: true),
  upsell: upsell,
  renewal: renewal,
);

BillingInfo _off({Upsell? upsell}) =>
    BillingInfo(enabled: false, upsell: upsell);

BillingInfo _onAndPremium({Upsell? upsell}) => BillingInfo(
  enabled: true,
  premium: const Premium(active: true),
  plans: const [_playPlan],
  rails: const Rails(googlePlay: true, codes: true),
  upsell: upsell,
);

/// What the backend answers when it sells nothing to this device: sales
/// on, no plans, only the code box.
BillingInfo _codesOnly({Upsell? upsell}) =>
    BillingInfo(enabled: true, rails: const Rails(codes: true), upsell: upsell);

class _UsedToday extends DedicatedState {
  @override
  QuotaStatus? get quota => const QuotaStatus(
    unlimited: false,
    limitBytes: 100,
    usedBytes: 10,
    remainingBytes: 90,
    blocked: false,
  );
}

/// A backend that records every request and answers [routes] by path
/// suffix, 404 otherwise.
class _Backend {
  final requests = <http.Request>[];
  final Map<String, (int, Object?)> routes = {};

  List<http.Request> to(String suffix) => [
    for (final r in requests)
      if (r.url.path.endsWith(suffix)) r,
  ];

  ApiClient get client => ApiClient.forTest(
    direct: MockClient((request) async {
      requests.add(request);
      final answer =
          [
            for (final e in routes.entries)
              if (request.url.path.endsWith(e.key)) e.value,
          ].firstOrNull ??
          (404, {'detail': 'Not Found'});
      return http.Response(
        answer.$2 == null ? '' : jsonEncode(answer.$2),
        answer.$1,
        headers: {'content-type': 'application/json'},
      );
    }),
  );
}

BillingState _live(
  _Backend backend, {
  PlayBilling? play,
  Duration sendEvery = const Duration(minutes: 1),
}) => BillingState(
  service: BillingService(client: backend.client),
  playBilling: () => play,
  googleSigned: () async => true,
  deviceId: () async => 'DEV-1',
  upsellSendEvery: sendEvery,
);

Map<String, dynamic> _infoJson({Map<String, dynamic>? upsell}) => {
  'enabled': true,
  'premium': {'active': false},
  'plans': [
    {
      'code': 'unlimited_30d',
      'google': {'product_id': 'premium', 'base_plan_id': 'p30'},
    },
  ],
  'rails': {'google_play': true, 'codes': true},
  'upsell': ?upsell,
};

class _Play implements PlayBilling {
  final controller = StreamController<List<PlayPurchase>>.broadcast();
  List<PlayPurchase> holding = const [];

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
  Future<void> complete(PlayPurchase purchase) async {}
  @override
  Future<List<PlayPurchase>> owned() async => holding;
}

PlayPurchase _paid(String token) => PlayPurchase(
  productId: 'premium',
  token: token,
  status: PlayPurchaseStatus.purchased,
  needsCompleting: true,
);

const _grant = {
  'premium': {'active': true, 'source': 'google_play', 'auto_renewing': true},
  'quota': {
    'unlimited': true,
    'limit_bytes': 0,
    'used_bytes': 0,
    'remaining_bytes': 0,
    'blocked': false,
  },
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ApiRelays.resetForTest();
  });

  tearDown(() => FormFactor.isTvForTest = false);

  group('reading the upsell block', () {
    test('an unknown surface is dropped and the known ones stay', () {
      final info = BillingInfo.fromJson(
        _infoJson(
          upsell: {
            'surfaces': ['top_chip', 'ad_blocker', 'limit_sheet', 7, null],
          },
        ),
      );
      expect(info.upsell?.surfaces, {
        UpsellSurface.topChip,
        UpsellSurface.limitSheet,
      });
    });

    test('a nudge of 0 or 101 reads as none, and 1 to 100 is kept', () {
      Upsell? read(Object? nudge) =>
          Upsell.fromJson({'surfaces': [], 'nudge_used_percent': nudge});
      expect(read(0)?.nudgeUsedPercent, isNull);
      expect(read(101)?.nudgeUsedPercent, isNull);
      expect(read(-5)?.nudgeUsedPercent, isNull);
      expect(read('80')?.nudgeUsedPercent, isNull);
      expect(read(80.0)?.nudgeUsedPercent, isNull);
      expect(read(1)?.nudgeUsedPercent, 1);
      expect(read(100)?.nudgeUsedPercent, 100);
    });

    test('the calm card numbers must be whole numbers above zero', () {
      final upsell = Upsell.fromJson({
        'prompt_every_hours': 0,
        'prompt_max': '3',
      });
      expect(upsell?.promptEveryHours, isNull);
      expect(upsell?.promptMax, isNull);
      final good = Upsell.fromJson({
        'prompt_every_hours': 168,
        'prompt_max': 3,
      });
      expect(good?.promptEveryHours, 168);
      expect(good?.promptMax, 3);
    });

    test('a locked server needs an id, a two-letter country and a city, '
        'and keeps nothing else', () {
      final upsell = Upsell.fromJson({
        'locked_servers': [
          {
            'id': 7,
            'country_code': 'fi',
            'city': 'Helsinki',
            // Never sent, and never kept if it were.
            'host': '203.0.113.5',
          },
          {'id': 8, 'country_code': 'DE'},
          {'country_code': 'DE', 'city': 'Falkenstein'},
          {'id': '9', 'country_code': 'DE', 'city': 'Falkenstein'},
          {'id': 10, 'country_code': 'Germany', 'city': 'Falkenstein'},
          'Helsinki',
        ],
      });
      final locked = upsell!.lockedServers.single;
      expect(locked.id, 7);
      expect(locked.countryCode, 'FI');
      expect(locked.city, 'Helsinki');
    });

    test('sales off drop the block, and keep the renewal', () {
      final info = BillingInfo.fromJson({
        'enabled': false,
        'premium': {'active': true, 'until': '2026-11-08T10:00:00Z'},
        'upsell': {
          'surfaces': ['top_chip'],
        },
        'renewal': {
          'until': '2026-11-08T10:00:00Z',
          'notice_hours': 72,
          'can_renew': true,
        },
      });
      expect(info.upsell, isNull);
      expect(info.renewal?.until, DateTime.utc(2026, 11, 8, 10));
      expect(info.renewal?.noticeHours, 72);
    });

    test('an answer with no block has none, and keeps it through a grant', () {
      expect(BillingInfo.fromJson(_infoJson()).upsell, isNull);
      final info = BillingInfo.fromJson(
        _infoJson(
          upsell: {
            'surfaces': ['top_chip'],
          },
        ),
      );
      expect(info.withPremium(Premium.none).upsell?.surfaces, {
        UpsellSurface.topChip,
      });
    });
  });

  group('the gate', () {
    for (final surface in UpsellSurface.values) {
      Upsell only(UpsellSurface s) => Upsell(surfaces: {s});

      test('${surface.wire} is on with sales on and its block', () {
        expect(
          _FixedBilling(_on(upsell: only(surface))).upsellOn(surface),
          isTrue,
        );
      });

      for (final (name, billing) in [
        ('sales are off', () => _FixedBilling(_off(upsell: only(surface)))),
        (
          'the device has Premium',
          () => _FixedBilling(_onAndPremium(upsell: only(surface))),
        ),
        (
          'only the code box is on offer',
          () => _FixedBilling(_codesOnly(upsell: only(surface))),
        ),
        ('the backend sent no block', () => _FixedBilling(_on())),
        (
          'the block does not name it',
          () => _FixedBilling(
            _on(
              upsell: Upsell(
                surfaces: UpsellSurface.values.toSet()..remove(surface),
              ),
            ),
          ),
        ),
        (
          'the tunnel has not worked on this install yet',
          () => _FixedBilling(_on(upsell: only(surface)), worked: false),
        ),
        (
          'this copy cannot buy through Google Play',
          () => _FixedBilling(_on(upsell: only(surface)), googleSigned: false),
        ),
        (
          'Play says it cannot sell here',
          () => _FixedBilling(_on(upsell: only(surface)), playAvailable: false),
        ),
      ]) {
        test('${surface.wire} is off when $name', () {
          expect(billing().upsellOn(surface), isFalse);
        });
      }

      test('${surface.wire} is off on a TV', () {
        FormFactor.isTvForTest = true;
        expect(
          _FixedBilling(_on(upsell: only(surface))).upsellOn(surface),
          isFalse,
        );
      });
    }

    test('use of the allowance today counts as a working connection', () {
      final billing = _FixedBilling(
        _on(upsell: _allSurfaces),
        worked: false,
        dedicated: _UsedToday(),
      );
      expect(billing.upsellOn(UpsellSurface.topChip), isTrue);
    });

    test('a working connection, once noted, is kept on the phone', () async {
      final backend = _Backend()..routes['/billing'] = (200, _infoJson());
      final first = _live(backend);
      await first.start();
      await first.noteWorkingConnection();

      final next = _live(
        backend
          ..routes['/billing'] = (
            200,
            _infoJson(
              upsell: {
                'surfaces': ['top_chip'],
              },
            ),
          ),
        play: _Play(),
      );
      await next.start();
      expect(next.upsellOn(UpsellSurface.topChip), isTrue);
    });

    test('a surface is listed only when the block names it, and never on '
        'a TV', () {
      final listed = _FixedBilling(
        _on(upsell: Upsell(surfaces: {UpsellSurface.limitSheet})),
        worked: false,
      );
      expect(listed.upsellListed(UpsellSurface.limitSheet), isTrue);
      // Listed, but the tunnel has not worked on this install yet.
      expect(listed.upsellOn(UpsellSurface.limitSheet), isFalse);
      expect(
        _FixedBilling(_on()).upsellListed(UpsellSurface.limitSheet),
        isFalse,
      );
      FormFactor.isTvForTest = true;
      expect(listed.upsellListed(UpsellSurface.limitSheet), isFalse);
    });

    test('the reminder is never due for Premium made by hand', () {
      final now = DateTime.utc(2026, 11, 8, 10);
      final until = now.add(const Duration(hours: 10));
      final renewal = Renewal(until: until, noticeHours: 72);
      expect(
        renewal.reminderDue(
          Premium(active: true, until: until, source: 'stars'),
          now,
        ),
        isTrue,
      );
      expect(
        renewal.reminderDue(
          Premium(active: true, until: until, source: 'manual'),
          now,
        ),
        isFalse,
      );
    });
  });

  group('the older ways in (offersAllowed)', () {
    // The quota card, the spent notice and the Settings tile were there
    // before the upsell block. They need the block too.
    test('are open with something to buy and a block', () {
      final billing = _FixedBilling(_on(upsell: const Upsell()), worked: false);
      expect(billing.offersAllowed, isTrue);
      expect(billing.tile, PremiumTile.premium);
    });

    test('are shut with no block', () {
      final billing = _FixedBilling(_on());
      expect(billing.showUpsell, isTrue);
      expect(billing.offersAllowed, isFalse);
      // No price: only the code box, which sells nothing.
      expect(billing.tile, PremiumTile.enterCode);
    });

    test('with no block and no code box on offer, there is no tile', () {
      final billing = _FixedBilling(
        const BillingInfo(
          enabled: true,
          plans: [_playPlan],
          rails: Rails(googlePlay: true),
        ),
      );
      expect(billing.tile, PremiumTile.hidden);
    });

    test('a Premium device keeps its tile', () {
      final billing = _FixedBilling(_onAndPremium());
      expect(billing.offersAllowed, isFalse);
      expect(billing.tile, PremiumTile.premium);
    });

    test('are shut in a copy that cannot buy through Google Play, and the '
        'tile reads Enter a code', () {
      final billing = _FixedBilling(
        _on(upsell: _allSurfaces),
        googleSigned: false,
      );
      expect(billing.canBuy, isFalse);
      expect(billing.showUpsell, isFalse);
      expect(billing.offersAllowed, isFalse);
      expect(billing.tile, PremiumTile.enterCode);
      // A Premium device keeps its tile there too.
      expect(
        _FixedBilling(
          _onAndPremium(upsell: _allSurfaces),
          googleSigned: false,
        ).tile,
        PremiumTile.premium,
      );
    });
  });

  group('offer events', () {
    test('shown counts once per surface per run; taps and closes each '
        'time', () {
      final billing = _live(_Backend());
      billing
        ..logUpsell(UpsellSurface.topChip, UpsellAction.shown)
        ..logUpsell(UpsellSurface.topChip, UpsellAction.shown)
        ..logUpsell(UpsellSurface.topChip, UpsellAction.tapped)
        ..logUpsell(UpsellSurface.topChip, UpsellAction.tapped)
        ..logUpsell(UpsellSurface.limitSheet, UpsellAction.shown)
        ..logUpsell(UpsellSurface.limitSheet, UpsellAction.dismissed);
      expect(
        [
          for (final e in billing.pendingUpsellEvents)
            '${e['surface']} ${e['action']}',
        ],
        [
          'top_chip shown',
          'top_chip tapped',
          'top_chip tapped',
          'limit_sheet shown',
          'limit_sheet dismissed',
        ],
      );
      billing.dispose();
    });

    test('go in one call to the events route once the wait is over', () async {
      final backend = _Backend()
        ..routes['/billing/upsell-events'] = (204, null);
      final billing = _live(
        backend,
        sendEvery: const Duration(milliseconds: 20),
      );
      billing
        ..logUpsell(UpsellSurface.topChip, UpsellAction.shown)
        ..logUpsell(UpsellSurface.topChip, UpsellAction.tapped);
      expect(backend.requests, isEmpty);
      await Future<void>.delayed(const Duration(milliseconds: 60));

      final sent = backend.to('/billing/upsell-events').single;
      expect(sent.method, 'POST');
      expect(sent.url.path, '/api/v1/devices/DEV-1/billing/upsell-events');
      expect(sent.url.queryParameters, {'store': 'play'});
      final body = jsonDecode(sent.body) as Map;
      expect(DateTime.parse(body['sent_at'] as String).isUtc, isTrue);
      final events = body['events'] as List;
      expect(events, hasLength(2));
      expect(events.first['surface'], 'top_chip');
      expect(events.first['action'], 'shown');
      expect(DateTime.parse(events.first['at'] as String).isUtc, isTrue);
      expect(billing.pendingUpsellEvents, isEmpty);
    });

    test('a send with no answer keeps them for the next one', () async {
      final backend = _Backend()
        ..routes['/billing/upsell-events'] = (503, {'detail': 'busy'});
      final billing = _live(backend);
      billing.logUpsell(UpsellSurface.calmCard, UpsellAction.shown);
      await billing.sendUpsellEvents();
      expect(billing.pendingUpsellEvents, hasLength(1));

      backend.routes['/billing/upsell-events'] = (204, null);
      await billing.sendUpsellEvents();
      expect(billing.pendingUpsellEvents, isEmpty);
      expect(backend.to('/billing/upsell-events'), hasLength(2));
    });

    test('a backend without the route gets them once and drops them', () async {
      final backend = _Backend();
      final billing = _live(backend);
      billing.logUpsell(UpsellSurface.calmCard, UpsellAction.shown);
      await billing.sendUpsellEvents();
      expect(billing.pendingUpsellEvents, isEmpty);
      await billing.sendUpsellEvents();
      expect(backend.to('/billing/upsell-events'), hasLength(1));
    });

    test('at most as many wait as the route takes', () {
      final billing = _live(_Backend());
      for (var i = 0; i < BillingService.maxEvents + 7; i++) {
        billing.logUpsell(UpsellSurface.topChip, UpsellAction.tapped);
      }
      expect(billing.pendingUpsellEvents, hasLength(BillingService.maxEvents));
      billing.dispose();
    });

    test('go at once when a Premium screen opens, before anything can be '
        'bought there', () async {
      final backend = _Backend()
        ..routes['/billing/upsell-events'] = (204, null);
      final billing = _live(backend);
      billing
        ..logUpsell(UpsellSurface.topChip, UpsellAction.shown)
        ..logUpsell(UpsellSurface.topChip, UpsellAction.tapped)
        ..premiumScreenOpened(PremiumSource.topChip);
      await pumpEventQueue();

      final sent = backend.to('/billing/upsell-events').single;
      expect(
        [
          for (final e in (jsonDecode(sent.body) as Map)['events'] as List)
            e['action'],
        ],
        ['shown', 'tapped'],
      );
      expect(billing.pendingUpsellEvents, isEmpty);
      billing.dispose();
    });

    test(
      'ones that arrive while a send is going follow it when asked',
      () async {
        final firstAnswer = Completer<void>();
        final bodies = <Map<String, dynamic>>[];
        final billing = BillingState(
          service: BillingService(
            client: ApiClient.forTest(
              direct: MockClient((request) async {
                bodies.add(jsonDecode(request.body) as Map<String, dynamic>);
                if (bodies.length == 1) await firstAnswer.future;
                return http.Response('', 204);
              }),
            ),
          ),
          playBilling: () => null,
          deviceId: () async => 'DEV-1',
        );
        billing.logUpsell(UpsellSurface.calmCard, UpsellAction.shown);
        final first = billing.sendUpsellEvents();
        await pumpEventQueue();
        expect(bodies, hasLength(1));

        billing
          ..logUpsell(UpsellSurface.calmCard, UpsellAction.tapped)
          ..premiumScreenOpened(PremiumSource.calmCard);
        await pumpEventQueue();
        expect(bodies, hasLength(1));

        firstAnswer.complete();
        await first;
        await pumpEventQueue();
        expect(bodies, hasLength(2));
        expect((bodies.last['events'] as List).single['action'], 'tapped');
        expect(billing.pendingUpsellEvents, isEmpty);
        billing.dispose();
      },
    );

    group('and the diagnostics switch', () {
      test('none are kept or sent while it is off', () async {
        SharedPreferences.setMockInitialValues({
          VpnEventReporter.sharePrefKey: false,
        });
        final backend = _Backend()
          ..routes['/billing'] = (200, _infoJson())
          ..routes['/billing/upsell-events'] = (204, null);
        final billing = _live(backend);
        await billing.start();
        billing
          ..logUpsell(UpsellSurface.topChip, UpsellAction.shown)
          ..logUpsell(UpsellSurface.topChip, UpsellAction.tapped);
        expect(billing.pendingUpsellEvents, isEmpty);
        await billing.sendUpsellEvents();
        expect(backend.to('/billing/upsell-events'), isEmpty);
        billing.dispose();
      });

      test('turning it off drops the ones waiting, and keeps no new ones '
          'until it is on again', () async {
        final backend = _Backend()
          ..routes['/billing/upsell-events'] = (204, null);
        final billing = _live(backend);
        billing
          ..logUpsell(UpsellSurface.topChip, UpsellAction.shown)
          ..logUpsell(UpsellSurface.topChip, UpsellAction.tapped);
        expect(billing.pendingUpsellEvents, hasLength(2));

        billing.sharingChanged(false);
        expect(billing.pendingUpsellEvents, isEmpty);
        billing.logUpsell(UpsellSurface.calmCard, UpsellAction.dismissed);
        expect(billing.pendingUpsellEvents, isEmpty);
        await billing.sendUpsellEvents();
        expect(backend.requests, isEmpty);

        billing
          ..sharingChanged(true)
          ..logUpsell(UpsellSurface.calmCard, UpsellAction.dismissed);
        expect(billing.pendingUpsellEvents, hasLength(1));
        billing.dispose();
      });

      test('is read again before a send, and off sends nothing', () async {
        final backend = _Backend()
          ..routes['/billing/upsell-events'] = (204, null);
        final billing = _live(backend);
        billing.logUpsell(UpsellSurface.topChip, UpsellAction.shown);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(VpnEventReporter.sharePrefKey, false);

        await billing.sendUpsellEvents();
        expect(backend.requests, isEmpty);
        expect(billing.pendingUpsellEvents, isEmpty);
        billing.dispose();
      });

      test('a purchase still names the offer it came from', () async {
        SharedPreferences.setMockInitialValues({
          VpnEventReporter.sharePrefKey: false,
        });
        final backend = _Backend()
          ..routes['/billing'] = (200, _infoJson())
          ..routes['/billing/google'] = (200, _grant);
        final play = _Play();
        final billing = _live(backend, play: play);
        await billing.start();
        billing.premiumScreenOpened(PremiumSource.calmCard);
        await billing.buyOnPlay(billing.playPlans.single);
        play.controller.add([_paid('token-1')]);
        await pumpEventQueue();
        expect(
          jsonDecode(backend.to('/billing/google').single.body)['source'],
          'calm_card',
        );
        expect(backend.to('/billing/upsell-events'), isEmpty);
        billing.dispose();
      });
    });

    test('deleting the account forgets them', () {
      final billing = _live(_Backend());
      billing.logUpsell(UpsellSurface.topChip, UpsellAction.tapped);
      billing.reset();
      expect(billing.pendingUpsellEvents, isEmpty);
    });

    test('a Premium device notes no offer as shown', () {
      final billing = _live(_Backend());
      billing
        ..adoptForTest(_onAndPremium())
        ..logUpsell(UpsellSurface.topChip, UpsellAction.shown)
        ..logUpsell(UpsellSurface.topChip, UpsellAction.tapped);
      expect(
        [for (final e in billing.pendingUpsellEvents) e['action']],
        ['tapped'],
      );
      billing.dispose();
    });

    test('a view still waiting when the purchase it led to lands is not '
        'sent, and the tap is', () async {
      // The backend checks the offer gate when a batch arrives. A Premium
      // device is outside it, so the buyer's own view would be counted as
      // one shown to a device that may not see offers.
      final backend = _Backend()
        ..routes['/billing/upsell-events'] = (204, null);
      final billing = _live(backend);
      billing
        ..adoptForTest(_on())
        ..logUpsell(UpsellSurface.limitSheet, UpsellAction.shown)
        ..logUpsell(UpsellSurface.limitSheet, UpsellAction.tapped)
        ..adoptForTest(_onAndPremium());
      await billing.sendUpsellEvents();

      final sent = jsonDecode(backend.to('/billing/upsell-events').single.body);
      expect([for (final e in sent['events'] as List) e['action']], ['tapped']);
      expect(sent['store'], 'play');
      expect(billing.pendingUpsellEvents, isEmpty);
      billing.dispose();
    });

    test('a batch of only views sends nothing once the device has '
        'Premium', () async {
      final backend = _Backend()
        ..routes['/billing/upsell-events'] = (204, null);
      final billing = _live(backend);
      billing
        ..adoptForTest(_on())
        ..logUpsell(UpsellSurface.calmCard, UpsellAction.shown)
        ..adoptForTest(_onAndPremium());
      await billing.sendUpsellEvents();
      expect(backend.requests, isEmpty);
      expect(billing.pendingUpsellEvents, isEmpty);
      billing.dispose();
    });
  });

  group('where a purchase came from', () {
    late _Backend backend;

    setUp(() {
      backend = _Backend()
        ..routes['/billing'] = (200, _infoJson())
        ..routes['/billing/google'] = (200, _grant);
    });

    /// Buy the only plan on Play and let Play report it paid.
    Future<Map<String, dynamic>> buy(BillingState billing, _Play play) async {
      expect(await billing.buyOnPlay(billing.playPlans.single), isTrue);
      play.controller.add([_paid('token-1')]);
      await pumpEventQueue();
      return jsonDecode(backend.to('/billing/google').single.body)
          as Map<String, dynamic>;
    }

    test('with no Premium screen open, nothing is added', () async {
      final play = _Play();
      final billing = _live(backend, play: play);
      await billing.start();
      billing
        ..premiumScreenOpened(PremiumSource.calmCard)
        ..premiumScreenClosed(PremiumSource.calmCard);

      expect(await buy(billing, play), isNot(contains('source')));
    });

    test('the newest open screen wins', () async {
      final play = _Play();
      final billing = _live(backend, play: play);
      await billing.start();
      billing
        ..premiumScreenOpened(PremiumSource.settings)
        ..premiumScreenOpened(PremiumSource.limitSheet);

      expect((await buy(billing, play))['source'], 'limit_sheet');
    });

    test('a Play purchase made on the screen carries it, one found in the '
        'background does not', () async {
      final play = _Play();
      final billing = _live(backend, play: play);
      await billing.start();

      billing.premiumScreenOpened(PremiumSource.serverCard);
      expect(await billing.buyOnPlay(billing.playPlans.single), isTrue);
      play.controller.add([_paid('token-1')]);
      await pumpEventQueue();
      final bought = jsonDecode(backend.to('/billing/google').single.body);
      expect(bought['source'], 'server_card');
      expect(bought['auto'], isFalse);

      play.holding = [_paid('token-2')];
      billing.resumed();
      await pumpEventQueue();
      final found = jsonDecode(backend.to('/billing/google').last.body);
      expect(found['purchase_token'], 'token-2');
      expect(found, isNot(contains('source')));
    });

    test('a Play purchase sent again later keeps its source', () async {
      final play = _Play();
      backend.routes['/billing/google'] = (503, {'detail': 'busy'});
      final billing = _live(backend, play: play);
      await billing.start();

      billing.premiumScreenOpened(PremiumSource.quotaLine);
      await billing.buyOnPlay(billing.playPlans.single);
      play.controller.add([_paid('token-1')]);
      await pumpEventQueue();
      billing.premiumScreenClosed(PremiumSource.quotaLine);

      // Play still holds it, so the background check finds it too. It is
      // sent once more, with the source it was bought with.
      play.holding = [_paid('token-1')];
      backend.routes['/billing/google'] = (200, _grant);
      billing.resumed();
      await pumpEventQueue();
      final sent = backend.to('/billing/google');
      expect(sent, hasLength(2));
      expect(jsonDecode(sent.last.body)['source'], 'quota_line');
      expect(jsonDecode(sent.last.body)['auto'], isFalse);
    });
  });
}
