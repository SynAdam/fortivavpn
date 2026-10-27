import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/core/state/invite_prompt.dart';
import 'package:fortiva_vpn/core/state/review_prompt.dart';
import 'package:fortiva_vpn/data/models/device.dart';
import 'package:fortiva_vpn/data/models/invite_prompt_rules.dart';
import 'package:fortiva_vpn/services/vpn_event_reporter.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The invite card's record and the backend's rules for it (clients #271).
///
/// Every number comes from the register answer's invite_prompt block. The
/// card is off with the block missing or any number missing, so these
/// tests use numbers of their own and never the start values.
void main() {
  const full = {
    'min_good_days': 3,
    'min_session_minutes': 5,
    'quiet_after_failure_hours': 24,
    'every_days': 14,
    'max_shows': 3,
    'earns': true,
    'reward_premium_days': 3,
  };

  group('InvitePromptRules.fromJson', () {
    test('reads a full block', () {
      final rules = InvitePromptRules.fromJson(full)!;
      expect(rules.minGoodDays, 3);
      expect(rules.minSessionMinutes, 5);
      expect(rules.quietAfterFailureHours, 24);
      expect(rules.everyDays, 14);
      expect(rules.maxShows, 3);
      expect(rules.earns, isTrue);
      expect(rules.rewardPremiumDays, 3);
    });

    test('no block means no card', () {
      expect(InvitePromptRules.fromJson(null), isNull);
      expect(InvitePromptRules.fromJson('on'), isNull);
      expect(InvitePromptRules.fromJson(const <String, Object?>{}), isNull);
    });

    for (final key in [
      'min_good_days',
      'min_session_minutes',
      'quiet_after_failure_hours',
      'every_days',
      'max_shows',
    ]) {
      test('no card when $key is missing, zero or of the wrong type', () {
        for (final bad in <Object?>[null, 0, -1, '3', 3.5, 3.0, true]) {
          final block = Map<String, Object?>.of(full);
          if (bad == null) {
            block.remove(key);
          } else {
            block[key] = bad;
          }
          expect(InvitePromptRules.fromJson(block), isNull, reason: '$bad');
        }
      });
    }

    test('the reward days are read only when the device earns', () {
      final atCap = InvitePromptRules.fromJson({...full, 'earns': false})!;
      expect(atCap.earns, isFalse);
      expect(atCap.rewardPremiumDays, isNull);

      final noNumber = InvitePromptRules.fromJson({
        ...full,
        'reward_premium_days': null,
      })!;
      expect(noNumber.earns, isTrue);
      expect(noNumber.rewardPremiumDays, isNull);

      final notTrue = InvitePromptRules.fromJson({...full, 'earns': 'yes'})!;
      expect(notTrue.earns, isFalse);
    });

    test('the register answer carries the block and the claim window', () {
      final device = Device.fromJson({
        'id': 42,
        'device_id': 'dev',
        'platform': 'android',
        'app_version': '1.9.0',
        'is_premium': false,
        'created_at': '2026-10-20T08:00:00Z',
        'invite_prompt': full,
        'referral_claim_open_until': '2026-10-23T08:00:00Z',
      });
      expect(device.invitePrompt?.maxShows, 3);
      expect(device.referralClaimOpenUntil, DateTime.utc(2026, 10, 23, 8));
      final again = Device.fromJson(device.toJson());
      expect(again.invitePrompt?.rewardPremiumDays, 3);
      expect(again.referralClaimOpenUntil, DateTime.utc(2026, 10, 23, 8));
    });

    test('after_disconnect is read only when it is true', () {
      expect(InvitePromptRules.fromJson(full)!.afterDisconnect, isFalse);
      for (final bad in <Object?>[false, null, 'true', 1]) {
        expect(
          InvitePromptRules.fromJson({
            ...full,
            'after_disconnect': bad,
          })!.afterDisconnect,
          isFalse,
          reason: '$bad',
        );
      }
      final on = InvitePromptRules.fromJson({
        ...full,
        'after_disconnect': true,
      })!;
      expect(on.afterDisconnect, isTrue);
      expect(InvitePromptRules.fromJson(on.toJson())!.afterDisconnect, isTrue);
      // It turns on a moment, never the card: the block still needs all
      // five numbers.
      expect(
        InvitePromptRules.fromJson({'after_disconnect': true, 'max_shows': 3}),
        isNull,
      );
    });

    test('an older backend sends neither', () {
      final device = Device.fromJson({
        'id': 42,
        'device_id': 'dev',
        'platform': 'android',
        'app_version': '1.8.0',
        'created_at': '2026-10-20T08:00:00Z',
      });
      expect(device.invitePrompt, isNull);
      expect(device.referralClaimOpenUntil, isNull);
    });
  });

  group('InvitePrompt', () {
    final rules = InvitePromptRules.fromJson(full)!;
    late DateTime now;
    InvitePrompt make() => InvitePrompt(clock: () => now);

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      // 12:00 Tehran.
      now = DateTime.utc(2026, 10, 20, 8, 30);
    });

    Future<Map<String, dynamic>> saved() async {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(InvitePrompt.inviteStateKey);
      return raw == null ? {} : jsonDecode(raw) as Map<String, dynamic>;
    }

    Future<void> goodDays(InvitePrompt prompt, int count) async {
      for (var i = 0; i < count; i++) {
        prompt.record(VpnEventType.connected);
        now = now.add(const Duration(days: 1));
      }
      await prompt.lastShownDay();
    }

    DateTime upFor(Duration d) => now.subtract(d);

    test('counts one good day per Tehran day', () async {
      final prompt = make();
      prompt.record(VpnEventType.connected);
      prompt.record(VpnEventType.connected);
      now = now.add(const Duration(hours: 2));
      prompt.record(VpnEventType.connected);
      await prompt.lastShownDay();
      expect((await saved())['good_days'], 1);

      // 23:55 Tehran is still the same day; 00:05 is the next.
      now = DateTime.utc(2026, 10, 20, 20, 25);
      prompt.record(VpnEventType.connected);
      now = DateTime.utc(2026, 10, 20, 20, 35);
      prompt.record(VpnEventType.connected);
      await prompt.lastShownDay();
      expect((await saved())['good_days'], 2);
      expect((await saved())['last_good_day'], '2026-10-21');
    });

    test('outcomes reported together are all kept', () async {
      final prompt = make();
      prompt.record(VpnEventType.connected);
      prompt.record(VpnEventType.dropped);
      now = now.add(const Duration(days: 1));
      prompt.record(VpnEventType.connected);
      await prompt.lastShownDay();
      final state = await saved();
      expect(state['good_days'], 2);
      expect(state['failed_at'], isNotNull);
    });

    test('other outcomes are not counted', () async {
      final prompt = make();
      prompt.record(VpnEventType.disconnected);
      await prompt.lastShownDay();
      expect((await saved())['good_days'], 0);
      expect(prompt.hadGoodDay, isFalse);
    });

    test('hadGoodDay turns true on the first connect and notifies', () async {
      final prompt = make();
      await prompt.lastShownDay();
      var told = 0;
      prompt.addListener(() => told++);
      expect(prompt.hadGoodDay, isFalse);
      prompt.record(VpnEventType.connected);
      expect(prompt.hadGoodDay, isTrue);
      expect(told, 1);
      prompt.record(VpnEventType.connected);
      expect(told, 1);
    });

    test('seeds the good days from the rating card once', () async {
      SharedPreferences.setMockInitialValues({
        ReviewPrompt.stateKey: jsonEncode({
          'days': ['2026-10-17', '2026-10-15', '2026-10-16'],
          'asks': 0,
        }),
      });
      final prompt = make();
      await Future<void>.delayed(Duration.zero);
      await prompt.lastShownDay();
      expect(prompt.hadGoodDay, isTrue);
      var state = await saved();
      expect(state['good_days'], 3);
      expect(state['last_good_day'], '2026-10-17');
      expect(state['seeded'], isTrue);

      // The rating card's record changing later moves nothing.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        ReviewPrompt.stateKey,
        jsonEncode({
          'days': ['2026-10-18'],
        }),
      );
      final again = make();
      await again.lastShownDay();
      state = await saved();
      expect(state['good_days'], 3);
    });

    test('an unreadable record starts over', () async {
      SharedPreferences.setMockInitialValues({
        InvitePrompt.inviteStateKey: 'not json',
      });
      final prompt = make();
      expect(
        await prompt.due(
          rules: rules,
          upSince: upFor(const Duration(hours: 1)),
          ratingAskDay: null,
        ),
        isFalse,
      );
    });

    group('due', () {
      test('true once every rule allows it', () async {
        final prompt = make();
        await goodDays(prompt, 3);
        expect(
          await prompt.due(
            rules: rules,
            upSince: upFor(const Duration(minutes: 5)),
            ratingAskDay: null,
          ),
          isTrue,
        );
      });

      test('never without rules', () async {
        final prompt = make();
        await goodDays(prompt, 5);
        expect(
          await prompt.due(
            rules: null,
            upSince: upFor(const Duration(hours: 1)),
            ratingAskDay: null,
          ),
          isFalse,
        );
      });

      test('never with no tunnel or a young one', () async {
        final prompt = make();
        await goodDays(prompt, 3);
        expect(
          await prompt.due(rules: rules, upSince: null, ratingAskDay: null),
          isFalse,
        );
        expect(
          await prompt.due(
            rules: rules,
            upSince: upFor(const Duration(minutes: 4, seconds: 59)),
            ratingAskDay: null,
          ),
          isFalse,
        );
      });

      test('never before the good days', () async {
        final prompt = make();
        await goodDays(prompt, 2);
        expect(
          await prompt.due(
            rules: rules,
            upSince: upFor(const Duration(hours: 1)),
            ratingAskDay: null,
          ),
          isFalse,
        );
      });

      test('never soon after a failure', () async {
        final prompt = make();
        await goodDays(prompt, 3);
        prompt.record(VpnEventType.verifyFailed);
        now = now.add(const Duration(hours: 23, minutes: 59));
        expect(
          await prompt.due(
            rules: rules,
            upSince: upFor(const Duration(hours: 1)),
            ratingAskDay: null,
          ),
          isFalse,
        );
        now = now.add(const Duration(minutes: 2));
        expect(
          await prompt.due(
            rules: rules,
            upSince: upFor(const Duration(hours: 1)),
            ratingAskDay: null,
          ),
          isTrue,
        );
      });

      test('once per run, then after the wait, up to the most shows', () async {
        final prompt = make();
        await goodDays(prompt, 3);
        final up = upFor(const Duration(hours: 1));
        expect(
          await prompt.due(rules: rules, upSince: up, ratingAskDay: null),
          isTrue,
        );
        await prompt.shown();
        expect(prompt.shownThisRun, isTrue);
        expect(
          await prompt.due(rules: rules, upSince: up, ratingAskDay: null),
          isFalse,
        );

        for (var show = 2; show <= 3; show++) {
          now = now.add(const Duration(days: 13, hours: 23));
          var next = make();
          expect(
            await next.due(
              rules: rules,
              upSince: upFor(const Duration(hours: 1)),
              ratingAskDay: null,
            ),
            isFalse,
            reason: 'show $show before the wait',
          );
          now = now.add(const Duration(hours: 2));
          next = make();
          expect(
            await next.due(
              rules: rules,
              upSince: upFor(const Duration(hours: 1)),
              ratingAskDay: null,
            ),
            isTrue,
            reason: 'show $show after the wait',
          );
          await next.shown();
        }
        expect((await saved())['shows'], 3);
        now = now.add(const Duration(days: 60));
        expect(
          await make().due(
            rules: rules,
            upSince: upFor(const Duration(hours: 1)),
            ratingAskDay: null,
          ),
          isFalse,
        );
      });

      test('never again after a share', () async {
        final prompt = make();
        await goodDays(prompt, 3);
        await prompt.shared();
        now = now.add(const Duration(days: 365));
        expect(
          await make().due(
            rules: rules,
            upSince: upFor(const Duration(hours: 1)),
            ratingAskDay: null,
          ),
          isFalse,
        );
      });

      test('never on the Tehran day the rating card was asked', () async {
        final prompt = make();
        await goodDays(prompt, 3);
        final up = upFor(const Duration(hours: 1));
        expect(
          await prompt.due(
            rules: rules,
            upSince: up,
            ratingAskDay: ReviewPrompt.tehranDay(now),
          ),
          isFalse,
        );
        expect(
          await prompt.due(
            rules: rules,
            upSince: up,
            ratingAskDay: ReviewPrompt.tehranDay(
              now.subtract(const Duration(days: 1)),
            ),
          ),
          isTrue,
        );
      });

      test('after a stop, the session is measured to its end', () async {
        final prompt = make();
        await goodDays(prompt, 3);
        // A session of 5 minutes that ended a while ago.
        final ended = now.subtract(const Duration(seconds: 2));
        expect(
          await prompt.due(
            rules: rules,
            upSince: ended.subtract(const Duration(minutes: 5)),
            endedAt: ended,
            ratingAskDay: null,
          ),
          isTrue,
        );
        // Up 4 minutes: the time since the stop does not make it longer.
        final ended2 = now.subtract(const Duration(minutes: 3));
        expect(
          await prompt.due(
            rules: rules,
            upSince: ended2.subtract(const Duration(minutes: 4)),
            endedAt: ended2,
            ratingAskDay: null,
          ),
          isFalse,
        );
      });

      test('never with a failure inside the session, however short the '
          'quiet time', () async {
        final prompt = make();
        await goodDays(prompt, 3);
        final quick = InvitePromptRules.fromJson({
          ...full,
          'quiet_after_failure_hours': 1,
        });
        final start = now;
        now = now.add(const Duration(hours: 1));
        prompt.record(VpnEventType.dropped);
        now = now.add(const Duration(hours: 2));
        for (final endedAt in [null, now]) {
          expect(
            await prompt.due(
              rules: quick,
              upSince: start,
              endedAt: endedAt,
              ratingAskDay: null,
            ),
            isFalse,
            reason: endedAt == null ? 'while up' : 'after the stop',
          );
        }
        // A session that began after it is fine once the quiet time ends.
        expect(
          await prompt.due(
            rules: quick,
            upSince: now.subtract(const Duration(minutes: 30)),
            endedAt: now,
            ratingAskDay: null,
          ),
          isTrue,
        );
      });

      test('the numbers are the backend\'s, not the app\'s', () async {
        final prompt = make();
        await goodDays(prompt, 1);
        final one = InvitePromptRules.fromJson({
          ...full,
          'min_good_days': 1,
          'min_session_minutes': 1,
        });
        expect(
          await prompt.due(
            rules: one,
            upSince: upFor(const Duration(minutes: 1)),
            ratingAskDay: null,
          ),
          isTrue,
        );
      });
    });

    test('shown records the Tehran day', () async {
      final prompt = make();
      await prompt.shown();
      expect(await prompt.lastShownDay(), ReviewPrompt.tehranDay(now));
      final state = await saved();
      expect(state['shows'], 1);
      expect(state['last_shown_day'], '2026-10-20');
    });
  });

  group('ReviewPrompt.lastAskDay', () {
    test('is the Tehran day of the last ask', () async {
      SharedPreferences.setMockInitialValues({});
      final at = DateTime.utc(2026, 10, 20, 21);
      final review = ReviewPrompt(
        installer: () async => ReviewPrompt.playInstaller,
        request: () async => null,
        clock: () => at,
      );
      expect(await review.lastAskDay(), isNull);
      await review.ask();
      // 21:00 UTC is 00:30 the next day in Tehran.
      expect(await review.lastAskDay(), '2026-10-21');
    });
  });
}
