import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/api/api_client.dart';
import 'package:fortiva_vpn/api/api_routes.dart';
import 'package:fortiva_vpn/api/billing_service.dart';
import 'package:fortiva_vpn/data/models/billing.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The payment calls and how their answers are read.
///
/// The backend for these routes was built at the same time as the app, so
/// the app reads every field leniently: a missing field or one of the wrong
/// type gives null or false, never an exception that takes the Premium
/// screen down. A refusal carries its reason in `detail.reason`, which
/// ApiException.message cannot hold (an object `detail` becomes 'Validation
/// error' there), so the reason is read from the body.
///
/// Every path sits under /api/v1/devices/{id}/, because the relays forward
/// nothing else. The tests pin each path.
///
/// Every copy of the app sends store=play. The answer below is the one an
/// older backend gave the channel APK, with USDT and Stars prices, the
/// crypto and Telegram rails and the crypto networks. The app shows no such
/// way to pay and reads past all of it.

Map<String, dynamic> _infoJson({bool enabled = true}) => {
  'enabled': enabled,
  'premium': {
    'active': true,
    'until': '2026-11-08T10:00:00Z',
    'plan': 'unlimited_30d',
    'source': 'voucher',
    'auto_renewing': null,
    'code': 'K7QD-3MWX-9TZB-H2CF',
  },
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
    'google_play': false,
    'crypto': true,
    'telegram': true,
    'codes': true,
  },
  'networks': [
    {'id': 'ton_usdt', 'label': 'USDT on TON'},
  ],
  'move_limit': 3,
  'move_window_days': 30,
};

/// A client whose only route answers with [status] and [body], and that
/// remembers each request.
(ApiClient, List<http.Request>) _client(int status, Object? body) {
  final seen = <http.Request>[];
  final client = ApiClient.forTest(
    direct: MockClient((request) async {
      seen.add(request);
      return http.Response(
        body == null ? '' : jsonEncode(body),
        status,
        headers: {'content-type': 'application/json'},
      );
    }),
  );
  return (client, seen);
}

Map<String, dynamic> _refusal(String reason) => {
  'detail': {'reason': reason, 'message': 'Refused in English'},
};

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ApiRelays.resetForTest();
  });

  group('reading the answers', () {
    test('the billing answer is read, and the crypto and Telegram parts of '
        'an older one are read past', () {
      final info = BillingInfo.fromJson(_infoJson());

      expect(info.enabled, isTrue);
      expect(info.premium.active, isTrue);
      expect(info.premium.until, DateTime.utc(2026, 11, 8, 10));
      expect(info.premium.plan, 'unlimited_30d');
      expect(info.premium.source, 'voucher');
      expect(info.premium.autoRenewing, isNull);
      expect(info.premium.code, 'K7QD-3MWX-9TZB-H2CF');
      final plan = info.plans.single;
      expect(plan.code, 'unlimited_30d');
      expect(plan.days, 30);
      expect(plan.google?.productId, 'premium');
      expect(plan.google?.basePlanId, 'p30');
      expect(info.rails.googlePlay, isFalse);
      expect(info.rails.codes, isTrue);
      expect(info.rails.playRestore, isFalse);
      expect(info.moveLimit, 3);
      expect(info.moveWindowDays, 30);
    });

    test('with sales off, nothing is on sale but Premium still shows', () {
      // The backend sends empty lists then. A stray plan or rail must not
      // open a way to pay anyway.
      final info = BillingInfo.fromJson(_infoJson(enabled: false));

      expect(info.enabled, isFalse);
      expect(info.plans, isEmpty);
      expect(info.rails.googlePlay, isFalse);
      expect(info.rails.codes, isFalse);
      expect(info.premium.active, isTrue);
      expect(info.premium.code, 'K7QD-3MWX-9TZB-H2CF');
    });

    test('an answer that is not an object reads as sales off', () {
      for (final odd in <Object?>[null, 'off', 42, <Object?>[]]) {
        final info = BillingInfo.fromJson(odd);
        expect(info.enabled, isFalse, reason: '$odd');
        expect(info.premium.active, isFalse);
      }
    });

    test('fields of the wrong type read as missing', () {
      final info = BillingInfo.fromJson({
        'enabled': 'yes',
        'premium': {'active': 'true', 'until': 12, 'code': 7},
      });
      expect(info.enabled, isFalse);
      expect(info.premium.active, isFalse);
      expect(info.premium.until, isNull);
      expect(info.premium.code, isNull);

      final plans = BillingInfo.fromJson({
        'enabled': true,
        'plans': [
          {'code': 'a_plan', 'days': '30', 'usdt': 4.99, 'stars': -1},
          {'days': 30},
          'not a plan',
          {
            'code': 'b_plan',
            'days': 0,
            'google': {'base_plan_id': 'x'},
          },
        ],
        'networks': [
          {'id': 'ton_usdt'},
          {'label': 'no id'},
        ],
        'move_limit': 2.5,
      });
      expect(plans.plans.map((p) => p.code), ['a_plan', 'b_plan']);
      final a = plans.plans.first;
      expect(a.days, isNull);
      expect(a.google, isNull);
      final b = plans.plans.last;
      expect(b.days, isNull);
      // A Play product with no product id is no Play product.
      expect(b.google, isNull);
      expect(plans.moveLimit, isNull);
    });

    test('a redeem answer with a broken quota still reads', () {
      final result = RedeemResult.fromJson({
        'kind': 'promo',
        'bonus_bytes': 1 << 30,
        'premium': {'active': false},
        'moved': false,
        'quota': {'unlimited': 'yes'},
      });
      expect(result.isPremium, isFalse);
      expect(result.bonusBytes, 1 << 30);
      expect(result.quota, isNull);
    });
  });

  group('the calls', () {
    test('GET billing sends store=play and reads the answer', () async {
      final (client, seen) = _client(200, _infoJson());

      final info = await BillingService(client: client).info('DEV-1');

      // Every copy sends play, the channel APK included. Only builds
      // 1.6.16 and 1.6.17 sent direct.
      expect(info.enabled, isTrue);
      expect(seen.single.method, 'GET');
      expect(seen.single.url.path, '/api/v1/devices/DEV-1/billing');
      expect(seen.single.url.queryParameters, {'store': 'play'});
    });

    test('redeem posts the code as typed', () async {
      final (client, seen) = _client(200, {
        'kind': 'premium',
        'premium': {'active': true, 'code': 'K7QD-3MWX-9TZB-H2CF'},
        'moved': true,
        'quota': {
          'unlimited': true,
          'limit_bytes': 0,
          'used_bytes': 0,
          'remaining_bytes': 0,
          'blocked': false,
        },
      });

      final result = await BillingService(
        client: client,
      ).redeem('DEV-1', 'k7qd 3mwx 9tzb h2cf');

      expect(seen.single.url.path, '/api/v1/devices/DEV-1/billing/redeem');
      expect(jsonDecode(seen.single.body), {'code': 'k7qd 3mwx 9tzb h2cf'});
      expect(result.isPremium, isTrue);
      expect(result.moved, isTrue);
      expect(result.quota?.unlimited, isTrue);
    });

    test('a Play purchase posts the product, token and base plan', () async {
      final (client, seen) = _client(200, {
        'premium': {'active': true, 'source': 'google_play'},
        'quota': null,
      });

      final result = await BillingService(client: client).confirmPlay(
        'DEV-1',
        productId: 'premium',
        purchaseToken: 'token-1',
        basePlanId: 'p30',
      );

      expect(seen.single.url.path, '/api/v1/devices/DEV-1/billing/google');
      expect(jsonDecode(seen.single.body), {
        'product_id': 'premium',
        'purchase_token': 'token-1',
        'base_plan_id': 'p30',
        // Only the background check of owned purchases sends true.
        'auto': false,
      });
      expect(result.premium.source, 'google_play');
      expect(result.quota, isNull);
    });

    test('a Play purchase from the background check posts auto true', () async {
      final (client, seen) = _client(200, {
        'premium': {'active': true, 'source': 'google_play'},
        'quota': null,
      });

      await BillingService(client: client).confirmPlay(
        'DEV-1',
        productId: 'premium',
        purchaseToken: 'token-1',
        auto: true,
      );

      expect(jsonDecode(seen.single.body)['auto'], isTrue);
    });

    test('a Play purchase names the offer it came from', () async {
      final (play, playSeen) = _client(200, {
        'premium': {'active': true},
      });
      await BillingService(client: play).confirmPlay(
        'DEV-1',
        productId: 'premium',
        purchaseToken: 'token-1',
        source: 'limit_sheet',
      );
      expect(jsonDecode(playSeen.single.body)['source'], 'limit_sheet');
    });

    test('offer events go to their own route, all in one call', () async {
      final (client, seen) = _client(204, null);
      final events = [
        {'surface': 'top_chip', 'action': 'shown', 'at': '2026-10-08T10:00Z'},
        {'surface': 'top_chip', 'action': 'tapped', 'at': '2026-10-08T10:01Z'},
      ];

      await BillingService(client: client).upsellEvents('DEV-1', events);

      expect(seen.single.method, 'POST');
      expect(
        seen.single.url.path,
        '/api/v1/devices/DEV-1/billing/upsell-events',
      );
      // play, as for the billing answer, from every copy.
      expect(seen.single.url.queryParameters, {'store': 'play'});
      expect(jsonDecode(seen.single.body), {'events': events, 'store': 'play'});
    });

    test('offer events carry the phone\'s clock as they go out', () async {
      final (client, seen) = _client(204, null);
      // The backend moves each event by the gap between this and its own
      // clock. It goes as UTC, whatever the phone's zone.
      final sentAt = DateTime.utc(2026, 10, 8, 5, 30);
      await BillingService(
        client: client,
      ).upsellEvents('DEV-1', const [], sentAt: sentAt.toLocal());

      expect(seen.single.url.queryParameters, {'store': 'play'});
      final body = jsonDecode(seen.single.body) as Map;
      expect(body['sent_at'], '2026-10-08T05:30:00.000Z');
      // On the batch too, for a backend that reads it there.
      expect(body['store'], 'play');
      expect(body['events'], isEmpty);
    });
  });

  group('refusals', () {
    Future<BillingException> refused(int status, Object? body) async {
      final (client, _) = _client(status, body);
      try {
        await BillingService(client: client).redeem('DEV-1', 'ABCD');
      } on BillingException catch (e) {
        return e;
      }
      fail('no refusal');
    }

    test('the reason comes from detail.reason', () async {
      final e = await refused(422, _refusal('expired'));
      expect(e.reason, 'expired');
      expect(e.statusCode, 422);
      expect(e.isRetryable, isFalse);
    });

    test('a 409 keeps its reason', () async {
      final e = await refused(409, _refusal('moved_too_often'));
      expect(e.reason, 'moved_too_often');
      expect(e.statusCode, 409);
    });

    test('a purchase held on another phone is final, not retried', () async {
      final e = await refused(409, _refusal('held_elsewhere'));
      expect(e.reason, BillingException.heldElsewhere);
      expect(e.statusCode, 409);
      expect(e.isRetryable, isFalse);
    });

    test('429 is too many calls, whatever the body says', () async {
      final e = await refused(429, {'detail': 'Too many requests'});
      expect(e.reason, BillingException.rateLimited);
      expect(e.isRetryable, isTrue);
    });

    test('a 503 with its reason is unavailable', () async {
      final e = await refused(503, _refusal('unavailable'));
      expect(e.reason, BillingException.unavailable);
      expect(e.isRetryable, isTrue);
    });

    test('statuses with no reason get one', () async {
      expect((await refused(404, {'detail': 'Not Found'})).reason, 'not_found');
      expect((await refused(500, 'oops')).reason, 'server');
      expect((await refused(502, null)).reason, 'server');
      expect((await refused(422, {'detail': []})).reason, 'unknown');
    });

    test('no route at all is a network failure', () async {
      final client = ApiClient.forTest(
        direct: MockClient((_) async => throw http.ClientException('cut')),
      );
      try {
        await BillingService(client: client).redeem('DEV-1', 'ABCD');
        fail('no refusal');
      } on BillingException catch (e) {
        expect(e.reason, BillingException.network);
        expect(e.statusCode, 0);
        expect(e.isRetryable, isTrue);
      }
    });

    test('a 2xx that is not the answer is a bad answer', () async {
      final (client, _) = _client(200, ['not', 'an', 'object']);
      try {
        await BillingService(client: client).redeem('DEV-1', 'ABCD');
        fail('no refusal');
      } on BillingException catch (e) {
        expect(e.reason, BillingException.badAnswer);
      }
    });
  });
}
