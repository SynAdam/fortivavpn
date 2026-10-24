import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/api/api_client.dart';
import 'package:fortiva_vpn/api/config_service.dart';
import 'package:fortiva_vpn/api/referral_service.dart';
import 'package:fortiva_vpn/core/state/referral_state.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fortiva_vpn/data/models/app_config.dart';
import 'package:fortiva_vpn/services/install_referrer.dart';

/// Tests for the parts of the referral client that decide something.
///
/// The network calls are the backend's to prove; what matters here is the
/// parsing that runs on data we did not write, and the defaults that keep
/// the feature hidden until the backend says otherwise.
void main() {
  group('ReferralStatus parsing', () {
    test('reads a full response', () {
      final status = ReferralStatus.fromJson({
        'code': 'AB3D7K',
        'share_url': 'https://fortivavpn.com/i/AB3D7K',
        'invited_count': 5,
        'confirmed_count': 2,
        'bonus_bytes': 524288000,
        'bonus_expires_at': null,
        'claimed_code': 'ZZ9Q2M',
      });

      expect(status.code, 'AB3D7K');
      expect(status.shareUrl, 'https://fortivavpn.com/i/AB3D7K');
      expect(status.invitedCount, 5);
      expect(status.confirmedCount, 2);
      expect(status.bonusBytes, 524288000);
      expect(status.bonusExpiresAt, isNull);
      expect(status.claimedCode, 'ZZ9Q2M');
      expect(status.hasClaimed, isTrue);
    });

    test('survives a response with every field missing', () {
      final status = ReferralStatus.fromJson(const {});

      expect(status.code, '');
      expect(status.invitedCount, 0);
      expect(status.bonusBytes, 0);
      expect(status.hasClaimed, isFalse);
    });

    test('pending is invited minus confirmed', () {
      final status = ReferralStatus.fromJson({
        'invited_count': 7,
        'confirmed_count': 3,
      });
      expect(status.pendingCount, 4);
    });

    test('pending never goes negative', () {
      // Cannot happen today, but a clamp here is cheaper than a "-1
      // invites waiting" screenshot from a user.
      final status = ReferralStatus.fromJson({
        'invited_count': 1,
        'confirmed_count': 4,
      });
      expect(status.pendingCount, 0);
    });

    test('parses an end date when the backend sets one by hand', () {
      final status = ReferralStatus.fromJson({
        'bonus_expires_at': '2026-12-01T10:00:00',
      });
      expect(status.bonusExpiresAt, DateTime.parse('2026-12-01T10:00:00'));
    });

    test('reads the reward amounts when the backend sends them', () {
      final status = ReferralStatus.fromJson({
        'code': 'AB3D7K',
        'bonus_per_referral_bytes': 1 << 30,
        'max_bonus_bytes': 10 << 30,
      });

      expect(status.bonusPerReferralBytes, 1 << 30);
      expect(status.maxBonusBytes, 10 << 30);
    });

    test('reward amounts are null on a backend that does not send them', () {
      final status = ReferralStatus.fromJson({
        'code': 'AB3D7K',
        'invited_count': 2,
        'confirmed_count': 1,
        'bonus_bytes': 1 << 30,
      });

      expect(status.bonusPerReferralBytes, isNull);
      expect(status.maxBonusBytes, isNull);
      expect(status.code, 'AB3D7K');
      expect(status.bonusBytes, 1 << 30);
    });

    test('a reward amount that is not a positive whole number is null', () {
      for (final bad in <Object?>[null, 0, -1, '1 GB', 1.5, true, double.nan]) {
        final status = ReferralStatus.fromJson({
          'code': 'AB3D7K',
          'bonus_per_referral_bytes': bad,
          'max_bonus_bytes': bad,
        });

        expect(status.bonusPerReferralBytes, isNull, reason: '$bad');
        expect(status.maxBonusBytes, isNull, reason: '$bad');
        expect(status.code, 'AB3D7K', reason: '$bad');
      }
    });

    test('a whole number sent as a float still reads', () {
      final status = ReferralStatus.fromJson({
        'bonus_per_referral_bytes': 1073741824.0,
      });
      expect(status.bonusPerReferralBytes, 1 << 30);
    });
  });

  group('InstallReferrer.parseCode', () {
    test('reads the code from a bare referrer', () {
      expect(InstallReferrer.parseCode('ref=AB3D7K'), 'AB3D7K');
    });

    test('reads the code alongside campaign parameters', () {
      expect(
        InstallReferrer.parseCode(
          'utm_source=telegram&ref=AB3D7K&utm_medium=x',
        ),
        'AB3D7K',
      );
    });

    test('ignores the organic referrer Play sends when nobody set one', () {
      expect(
        InstallReferrer.parseCode('utm_source=google-play&utm_medium=organic'),
        isNull,
      );
    });

    test('returns null for nothing at all', () {
      expect(InstallReferrer.parseCode(null), isNull);
      expect(InstallReferrer.parseCode(''), isNull);
    });

    test('treats an empty ref as absent', () {
      expect(InstallReferrer.parseCode('ref='), isNull);
    });

    test('does not throw on a referrer that is not a query string', () {
      expect(InstallReferrer.parseCode('%%%not a query%%%'), isNull);
    });
  });

  group('QuotaStatus referral bonus', () {
    test('reads the bonus the backend reports', () {
      final quota = QuotaStatus.fromJson({
        'unlimited': false,
        'limit_bytes': 367001600,
        'used_bytes': 0,
        'remaining_bytes': 367001600,
        'blocked': false,
        'bonus_bytes': 262144000,
      });

      expect(quota.bonusBytes, 262144000);
      expect(quota.hasReferralBonus, isTrue);
    });

    test('defaults to no bonus on a backend that does not report one', () {
      final quota = QuotaStatus.fromJson({
        'unlimited': false,
        'limit_bytes': 104857600,
        'used_bytes': 0,
        'remaining_bytes': 104857600,
        'blocked': false,
      });

      expect(quota.bonusBytes, 0);
      expect(quota.hasReferralBonus, isFalse);
    });

    test('an unmetered device never shows a bonus', () {
      // Premium skips the quota check entirely, so a bonus on that row
      // would be a number with nothing to add to.
      final quota = QuotaStatus.fromJson({
        'unlimited': true,
        'limit_bytes': 0,
        'used_bytes': 0,
        'remaining_bytes': 0,
        'blocked': false,
        'bonus_bytes': 262144000,
      });

      expect(quota.hasReferralBonus, isFalse);
    });
  });

  group('FeatureFlags', () {
    test('referrals default to off', () {
      // Unlike the older flags, which default on. A build that cannot
      // reach the config endpoint must not offer a screen whose
      // endpoints may not exist yet.
      expect(const FeatureFlags().enableReferrals, isFalse);
      expect(FeatureFlags.fromJson(const {}).enableReferrals, isFalse);
    });

    test('reads the flag when the backend sends it', () {
      final flags = FeatureFlags.fromJson({'enable_referrals': true});
      expect(flags.enableReferrals, isTrue);
    });

    test('round-trips through json', () {
      final flags = FeatureFlags.fromJson({'enable_referrals': true});
      expect(FeatureFlags.fromJson(flags.toJson()).enableReferrals, isTrue);
    });
  });

  group('ReferralStatus reward B and the exclude list', () {
    test('reads them when the backend sends them', () {
      final status = ReferralStatus.fromJson({
        'code': 'AB3D7K',
        'share_exclude_packages': ['ir.eitaa.messenger', 3, '', 'net.iGap'],
        'reward_premium_days': 3,
        'premium_days_each': 3,
        'premium_days_earned': 6,
        'premium_days_max': 30,
        'earns': true,
        'claim_open_until': '2026-10-23T08:00:00Z',
      });
      expect(status.shareExcludePackages, ['ir.eitaa.messenger', 'net.iGap']);
      expect(status.rewardPremiumDays, 3);
      expect(status.premiumDaysEach, 3);
      expect(status.premiumDaysEarned, 6);
      expect(status.premiumDaysMax, 30);
      expect(status.earns, isTrue);
      expect(status.claimOpenUntil, DateTime.utc(2026, 10, 23, 8));
    });

    test('an older backend sends none of them', () {
      final status = ReferralStatus.fromJson({'code': 'AB3D7K'});
      expect(status.shareExcludePackages, isEmpty);
      expect(status.rewardPremiumDays, isNull);
      expect(status.premiumDaysEach, isNull);
      expect(status.premiumDaysEarned, 0);
      expect(status.premiumDaysMax, isNull);
      expect(status.earns, isFalse);
      expect(status.claimOpenUntil, isNull);
    });

    test('a list that is not a list reads as empty', () {
      final status = ReferralStatus.fromJson({
        'share_exclude_packages': 'ir.eitaa.messenger',
      });
      expect(status.shareExcludePackages, isEmpty);
    });
  });

  group('claim refusals', () {
    ApiException refusal(int status, Object? body) =>
        ApiException(statusCode: status, message: 'x', body: body);

    test('every slug from an object detail', () {
      const slugs = {
        'already_claimed': (409, ReferralClaimFailure.alreadyClaimed),
        'too_late': (422, ReferralClaimFailure.tooLate),
        'invalid_code': (422, ReferralClaimFailure.unknownCode),
        'unknown_code': (422, ReferralClaimFailure.unknownCode),
        'self_referral': (422, ReferralClaimFailure.ownCode),
        'mutual_referral': (422, ReferralClaimFailure.mutual),
      };
      slugs.forEach((slug, expected) {
        final e = refusal(expected.$1, {
          'detail': {'reason': slug, 'message': 'English text'},
        });
        expect(ReferralService.failureFor(e), expected.$2, reason: slug);
      });
    });

    test('an unknown slug falls back to the status code', () {
      final e = refusal(422, {
        'detail': {'reason': 'something_new'},
      });
      expect(ReferralService.failureFor(e), ReferralClaimFailure.rejected);
    });

    test('a string detail on 429, 404 and a 422 refusal', () {
      expect(
        ReferralService.failureFor(refusal(429, {'detail': 'Too many'})),
        ReferralClaimFailure.limited,
      );
      expect(
        ReferralService.failureFor(refusal(404, {'detail': 'Not found'})),
        ReferralClaimFailure.unknownDevice,
      );
      expect(
        ReferralService.failureFor(
          refusal(422, {'detail': 'Invite codes can only be used early.'}),
        ),
        ReferralClaimFailure.rejected,
      );
      expect(
        ReferralService.failureFor(refusal(409, {'detail': 'Already'})),
        ReferralClaimFailure.alreadyClaimed,
      );
    });

    test("FastAPI's own 422 sends a list", () {
      final e = refusal(422, {
        'detail': [
          {
            'loc': ['body', 'code'],
            'msg': 'field required',
            'type': 'missing',
          },
        ],
      });
      expect(ReferralService.failureFor(e), ReferralClaimFailure.rejected);
    });

    test('a body that is not an object', () {
      expect(
        ReferralService.failureFor(refusal(422, 'Unprocessable')),
        ReferralClaimFailure.rejected,
      );
      expect(
        ReferralService.failureFor(refusal(502, '<html>')),
        ReferralClaimFailure.network,
      );
      expect(
        ReferralService.failureFor(refusal(0, null)),
        ReferralClaimFailure.network,
      );
    });

    test('a status the claim route does not send is unexpected', () {
      for (final status in [400, 401, 403, 405]) {
        expect(
          ReferralService.failureFor(refusal(status, '<html>')),
          ReferralClaimFailure.unexpected,
          reason: '$status',
        );
      }
    });
  });

  group('ReferralClaimResult.fromBody', () {
    test('reads the claimed code, already and the days', () {
      final result = ReferralClaimResult.fromBody({
        'claimed': true,
        'claimed_code': 'AB3D7K',
        'already': true,
        'confirm_active_days': 2,
      });
      expect(result.claimed, isTrue);
      expect(result.claimedCode, 'AB3D7K');
      expect(result.already, isTrue);
      expect(result.confirmActiveDays, 2);
    });

    test('a body that is not an object is still a success', () {
      final result = ReferralClaimResult.fromBody(null);
      expect(result.claimed, isTrue);
      expect(result.claimedCode, isNull);
      expect(result.already, isFalse);
      expect(result.confirmActiveDays, isNull);
    });
  });

  group('ReferralState with a backend', () {
    late List<http.Request> calls;

    /// A backend whose claim answers [claim] with [claimBody], and whose
    /// status answers the default status.
    ReferralState make({
      int claim = 200,
      Object? claimBody,
      String Function()? language,
      Future<String?> Function()? pending,
      Future<void> Function()? settle,
      bool throwOnClaim = false,
    }) {
      final client = ApiClient.forTest(
        direct: MockClient((request) async {
          calls.add(request);
          if (request.url.path.endsWith('/claim')) {
            if (throwOnClaim) throw http.ClientException('cut');
            return http.Response(
              jsonEncode(claimBody ?? {'claimed': true}),
              claim,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response(
            jsonEncode({
              'code': 'ZZ9Q2M',
              'share_url': 'https://fortivavpn.com/fa/i/ZZ9Q2M',
              'claimed_code': 'AB3D7K',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      return ReferralState(
        language: language,
        service: ReferralService.forTest(client: client),
        deviceId: () async => 'DEV-1',
        register: () async {},
        pendingReferrer: pending,
        settleReferrer: settle,
      );
    }

    setUp(() => calls = []);

    Iterable<http.Request> statusReads() =>
        calls.where((c) => c.url.path.endsWith('/referral'));

    test('the language callback reaches ?lang=', () async {
      final state = make(language: () => 'fa');
      await state.refresh();
      expect(statusReads().single.url.queryParameters['lang'], 'fa');
      expect(state.status?.code, 'ZZ9Q2M');
    });

    test('a home-row claim reloads nothing, so no code is minted', () async {
      final state = make(
        claimBody: {
          'claimed': true,
          'claimed_code': 'AB3D7K',
          'confirm_active_days': 2,
        },
      );
      final result = await state.claim('AB3D7K', source: 'paste');
      expect(result.claimed, isTrue);
      expect(result.confirmActiveDays, 2);
      expect(state.hasClaimed, isTrue);
      expect(statusReads(), isEmpty);
      final body = jsonDecode(calls.single.body) as Map<String, dynamic>;
      expect(body, {'code': 'AB3D7K', 'source': 'paste'});
    });

    test('a claim from the invite screen reloads the status', () async {
      final state = make();
      await state.refresh();
      calls.clear();
      await state.claim('AB3D7K');
      expect(statusReads(), hasLength(1));
      expect(state.status?.claimedCode, 'AB3D7K');
    });

    test('already: true on 200 is a success', () async {
      final state = make(
        claimBody: {'claimed': true, 'claimed_code': 'AB3D7K', 'already': true},
      );
      final result = await state.claim('AB3D7K');
      expect(result.claimed, isTrue);
      expect(result.already, isTrue);
      expect(state.hasClaimed, isTrue);
    });

    test('a 409 is another code, with no status reload', () async {
      final state = make(
        claim: 409,
        claimBody: {
          'detail': {'reason': 'already_claimed', 'message': 'x'},
        },
      );
      final result = await state.claim('AB3D7K');
      expect(result.failure, ReferralClaimFailure.alreadyClaimed);
      expect(statusReads(), isEmpty);
      expect(state.hasClaimed, isFalse);
    });

    group('the install referrer retry', () {
      late int settled;
      setUp(() => settled = 0);

      ReferralState referrer({
        int claim = 200,
        Object? body,
        bool cut = false,
      }) => make(
        claim: claim,
        claimBody: body,
        throwOnClaim: cut,
        pending: () async => 'AB3D7K',
        settle: () async => settled++,
      );

      test('kept when the claim is lost on the network', () async {
        await referrer(cut: true).claimFromInstallReferrer();
        expect(settled, 0);
        final claim = calls.firstWhere((c) => c.url.path.endsWith('/claim'));
        expect(jsonDecode(claim.body)['source'], 'play_referrer');
      });

      test('kept on a server error and on 429', () async {
        await referrer(
          claim: 503,
          body: {'detail': 'down'},
        ).claimFromInstallReferrer();
        await referrer(
          claim: 429,
          body: {'detail': 'slow down'},
        ).claimFromInstallReferrer();
        expect(settled, 0);
      });

      test('kept on a status the claim route does not send', () async {
        // Something on the way, such as a proxy, answered for the backend.
        await referrer(
          claim: 403,
          body: 'Forbidden',
        ).claimFromInstallReferrer();
        await referrer(
          claim: 400,
          body: {'detail': 'Bad request'},
        ).claimFromInstallReferrer();
        expect(settled, 0);
      });

      test('cleared on success, 409 and 422', () async {
        await referrer().claimFromInstallReferrer();
        await referrer(
          claim: 409,
          body: {
            'detail': {'reason': 'already_claimed'},
          },
        ).claimFromInstallReferrer();
        await referrer(
          claim: 422,
          body: {
            'detail': {'reason': 'too_late'},
          },
        ).claimFromInstallReferrer();
        await referrer(
          claim: 422,
          body: {'detail': 'old text'},
        ).claimFromInstallReferrer();
        expect(settled, 4);
      });

      test('nothing happens without a code', () async {
        final state = make(
          pending: () async => null,
          settle: () async => settled++,
        );
        await state.claimFromInstallReferrer();
        expect(calls, isEmpty);
        expect(settled, 0);
      });
    });
  });
}
