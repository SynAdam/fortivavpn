import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/api/config_service.dart';
import 'package:fortiva_vpn/api/referral_service.dart';
import 'package:fortiva_vpn/core/form_factor.dart';
import 'package:fortiva_vpn/core/state/app_config_state.dart';
import 'package:fortiva_vpn/data/models/app_config.dart';
import 'package:fortiva_vpn/data/models/billing.dart';
import 'package:fortiva_vpn/screens/invite_screen.dart';
import 'package:fortiva_vpn/screens/premium_screen.dart';
import 'package:fortiva_vpn/services/vpn_service.dart';
import 'package:fortiva_vpn/widgets/message_dialog.dart';
import 'package:fortiva_vpn/widgets/update_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/invite_home.dart';

/// The invite link on the home data line: "Invite friends for more data",
/// offered once the backend's share of the daily allowance is used and
/// before it runs out, so an invite has a chance to pay before the data
/// does. The share is the backend's (feature_flags.invite_nudge_percent),
/// and a backend that sends none gets no link.

const _invite = Key('quota-line-invite');
const _unlimited = Key('quota-line-unlimited');
const _words = 'Invite friends for more data';

/// [used] MiB of a 100 MiB allowance.
QuotaStatus _quota(int used, {bool blocked = false, bool unlimited = false}) =>
    QuotaStatus(
      unlimited: unlimited,
      limitBytes: unlimited ? 0 : 100 << 20,
      usedBytes: used << 20,
      remainingBytes: unlimited ? 0 : (100 - used).clamp(0, 100) << 20,
      blocked: blocked,
      resetsAt: unlimited ? null : DateTime.now().add(const Duration(hours: 3)),
    );

/// Billing that offers "Get unlimited" on the data line from [nudge]
/// percent, as BillingInfo carries it.
BillingInfo _premiumOffer({int nudge = 70}) => BillingInfo(
  enabled: true,
  premium: Premium.none,
  plans: const [
    Plan(
      code: 'unlimited_30d',
      google: PlayProductRef(productId: 'premium', basePlanId: 'p30'),
    ),
  ],
  rails: const Rails(googlePlay: true, codes: true),
  upsell: Upsell(
    surfaces: const {UpsellSurface.quotaLine},
    nudgeUsedPercent: nudge,
  ),
);

void main() {
  setUp(() {
    mockTunnel([]);
    UpdateDialog.resetForTest();
    MessageDialog.resetForTest();
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    FormFactor.isTvForTest = false;
    unmockTunnel();
  });

  group('the backend\'s share', () {
    test('is read from the feature flags', () {
      expect(
        FeatureFlags.fromJson({'invite_nudge_percent': 70}).inviteNudgePercent,
        70,
      );
      expect(const FeatureFlags().inviteNudgePercent, isNull);
      expect(FeatureFlags.fromJson({}).inviteNudgePercent, isNull);
    });

    test('anything but a whole percent from 1 to 100 is no share, and the '
        'other flags are kept', () {
      for (final value in [0, -3, 101, 70.5, '70', true, null]) {
        final flags = FeatureFlags.fromJson({
          'enable_referrals': true,
          'invite_nudge_percent': value,
        });
        expect(flags.inviteNudgePercent, isNull, reason: '$value');
        expect(flags.enableReferrals, isTrue);
      }
      expect(
        FeatureFlags.fromJson({'invite_nudge_percent': 1}).inviteNudgePercent,
        1,
      );
      expect(
        FeatureFlags.fromJson({'invite_nudge_percent': 100}).inviteNudgePercent,
        100,
      );
    });

    test('survives the trip through toJson', () {
      const flags = FeatureFlags(enableReferrals: true, inviteNudgePercent: 70);
      expect(FeatureFlags.fromJson(flags.toJson()).inviteNudgePercent, 70);
    });

    test('counts only while invites are on', () async {
      expect((await inviteConfig(inviteNudge: 70)).inviteNudgePercent, 70);
      expect(
        (await inviteConfig(
          referrals: false,
          inviteNudge: 70,
        )).inviteNudgePercent,
        isNull,
      );
      expect((await inviteConfig()).inviteNudgePercent, isNull);
      // Before a config has landed.
      expect(
        AppConfigState(
          fetch: () async => throw StateError('no fetch in tests'),
        ).inviteNudgePercent,
        isNull,
      );
    });
  });

  group('the data line', () {
    testWidgets('offers invites once the share is used, and opens the invite '
        'screen, noted as the data line', (tester) async {
      final events = keptEvents();
      await pumpInviteHome(
        tester,
        vpn: FakeVpn(VpnStatus.disconnected),
        events: events,
        config: await inviteConfig(inviteNudge: 70),
        referrals: CountingReferral(answer: shareStatus),
        dedicated: FakeDedicated(_quota(70)),
      );
      expect(find.byKey(_invite), findsOneWidget);
      expect(
        find.descendant(of: find.byKey(_invite), matching: find.text(_words)),
        findsOneWidget,
      );
      // No Premium offer here, so the invite link is the only one.
      expect(find.byKey(_unlimited), findsNothing);
      // A tap on the amounts opens nothing.
      await tester.tap(find.textContaining('used today'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(InviteScreen), findsNothing);

      await tester.tap(find.byKey(_invite));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.byType(InviteScreen), findsOneWidget);
      expect(
        tester.widget<InviteScreen>(find.byType(InviteScreen)).entry,
        InviteEntry.quotaLine,
      );
      expect(
        [for (final e in events.queued) (e['surface'], e['action'])],
        [('quota_line', 'shown')],
      );
      await inviteHomeDone(tester);
    });

    for (final (name, used, nudge, referrals) in [
      ('below the share', 69, 70, true),
      ('when the backend sent no share', 99, null, true),
      ('while invites are off, whatever the share', 99, 70, false),
    ]) {
      testWidgets('says nothing more $name', (tester) async {
        await pumpInviteHome(
          tester,
          vpn: FakeVpn(VpnStatus.disconnected),
          config: await inviteConfig(referrals: referrals, inviteNudge: nudge),
          referrals: CountingReferral(answer: shareStatus),
          dedicated: FakeDedicated(_quota(used)),
        );
        expect(find.byKey(_invite), findsNothing);
        expect(find.text(_words), findsNothing);
        await inviteHomeDone(tester);
      });
    }

    testWidgets('says nothing more on an unmetered device', (tester) async {
      await pumpInviteHome(
        tester,
        vpn: FakeVpn(VpnStatus.disconnected),
        config: await inviteConfig(inviteNudge: 1),
        referrals: CountingReferral(answer: shareStatus),
        dedicated: FakeDedicated(_quota(50, unlimited: true)),
      );
      expect(find.byKey(_invite), findsNothing);
      await inviteHomeDone(tester);
    });

    testWidgets('says nothing more on a Premium device', (tester) async {
      await pumpInviteHome(
        tester,
        vpn: FakeVpn(VpnStatus.disconnected),
        config: await inviteConfig(inviteNudge: 70),
        billing: FixedBilling(
          const BillingInfo(
            enabled: true,
            premium: Premium(active: true),
            rails: Rails(codes: true),
          ),
        ),
        referrals: CountingReferral(answer: shareStatus),
        dedicated: FakeDedicated(_quota(90)),
      );
      expect(find.byKey(_invite), findsNothing);
      await inviteHomeDone(tester);
    });

    testWidgets('leaves spent data to the limit sheet', (tester) async {
      await pumpInviteHome(
        tester,
        vpn: FakeVpn(VpnStatus.disconnected),
        config: await inviteConfig(inviteNudge: 70),
        referrals: CountingReferral(answer: shareStatus),
        dedicated: FakeDedicated(_quota(100, blocked: true)),
      );
      expect(find.byKey(_invite), findsNothing);
      await inviteHomeDone(tester);
    });

    testWidgets('says nothing more once invites can add no more data', (
      tester,
    ) async {
      final referrals = CountingReferral(
        answer: const ReferralStatus(
          code: 'AB3D7K',
          shareUrl: 'https://example.com/i/AB3D7K',
          invitedCount: 12,
          confirmedCount: 10,
          bonusBytes: 10 << 30,
          maxBonusBytes: 10 << 30,
        ),
      );
      await referrals.refresh();
      await pumpInviteHome(
        tester,
        vpn: FakeVpn(VpnStatus.disconnected),
        config: await inviteConfig(inviteNudge: 70),
        referrals: referrals,
        dedicated: FakeDedicated(_quota(90)),
      );
      expect(find.byKey(_invite), findsNothing);
      await inviteHomeDone(tester);
    });

    testWidgets('keeps offering while invites can still add data', (
      tester,
    ) async {
      final referrals = CountingReferral(
        answer: const ReferralStatus(
          code: 'AB3D7K',
          shareUrl: 'https://example.com/i/AB3D7K',
          invitedCount: 3,
          confirmedCount: 2,
          bonusBytes: 2 << 30,
          maxBonusBytes: 10 << 30,
        ),
      );
      await referrals.refresh();
      await pumpInviteHome(
        tester,
        vpn: FakeVpn(VpnStatus.disconnected),
        config: await inviteConfig(inviteNudge: 70),
        referrals: referrals,
        dedicated: FakeDedicated(_quota(90)),
      );
      expect(find.byKey(_invite), findsOneWidget);
      await inviteHomeDone(tester);
    });

    testWidgets('says nothing more while a connect is under way', (
      tester,
    ) async {
      await pumpInviteHome(
        tester,
        vpn: FakeVpn(VpnStatus.connecting),
        config: await inviteConfig(inviteNudge: 70),
        referrals: CountingReferral(answer: shareStatus),
        dedicated: FakeDedicated(_quota(90)),
      );
      expect(find.byKey(_invite), findsNothing);
      await inviteHomeDone(tester);
    });

    testWidgets('says nothing more on a TV', (tester) async {
      FormFactor.isTvForTest = true;
      await pumpInviteHome(
        tester,
        vpn: FakeVpn(VpnStatus.disconnected),
        config: await inviteConfig(inviteNudge: 70),
        referrals: CountingReferral(answer: shareStatus),
        dedicated: FakeDedicated(_quota(90)),
      );
      expect(find.byKey(_invite), findsNothing);
      expect(find.text(_words), findsNothing);
      await inviteHomeDone(tester);
    });
  });

  group('with Premium offered on the data line too', () {
    for (final locale in ['en', 'fa']) {
      testWidgets('[$locale] the invite link comes first, then Get '
          'unlimited, each a full target and neither over the amounts', (
        tester,
      ) async {
        await pumpInviteHome(
          tester,
          vpn: FakeVpn(VpnStatus.disconnected),
          config: await inviteConfig(inviteNudge: 70),
          billing: FixedBilling(_premiumOffer()),
          referrals: CountingReferral(answer: shareStatus),
          dedicated: FakeDedicated(_quota(80)),
          locale: locale,
        );
        expect(tester.takeException(), isNull);
        final invite = tester.getRect(find.byKey(_invite));
        final premium = tester.getRect(find.byKey(_unlimited));
        for (final box in [invite, premium]) {
          expect(box.height, greaterThanOrEqualTo(48));
          expect(box.width, greaterThanOrEqualTo(48));
        }
        expect(invite.overlaps(premium), isFalse);
        // In reading order: from the start of the line, or above where
        // they take a row each (the test font is far wider than a real one).
        if ((invite.center.dy - premium.center.dy).abs() < 1) {
          if (locale == 'fa') {
            expect(invite.center.dx, greaterThan(premium.center.dx));
          } else {
            expect(invite.center.dx, lessThan(premium.center.dx));
          }
        } else {
          expect(invite.bottom, lessThanOrEqualTo(premium.top + 0.5));
        }
        // The amounts are words, not a button, and under neither target.
        final amounts = tester.getRect(
          find.textContaining(locale == 'fa' ? 'امروز' : 'used today'),
        );
        expect(amounts.overlaps(invite), isFalse);
        expect(amounts.overlaps(premium), isFalse);
        await inviteHomeDone(tester);
      });
    }

    testWidgets('Get unlimited still opens Premium', (tester) async {
      await pumpInviteHome(
        tester,
        vpn: FakeVpn(VpnStatus.disconnected),
        config: await inviteConfig(inviteNudge: 70),
        billing: FixedBilling(_premiumOffer()),
        referrals: CountingReferral(answer: shareStatus),
        dedicated: FakeDedicated(_quota(80)),
      );
      await tester.tap(find.byKey(_unlimited));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.byType(PremiumScreen), findsOneWidget);
      expect(find.byType(InviteScreen), findsNothing);
      await inviteHomeDone(tester);
    });

    testWidgets('below the invite share, only Premium is offered', (
      tester,
    ) async {
      await pumpInviteHome(
        tester,
        vpn: FakeVpn(VpnStatus.disconnected),
        config: await inviteConfig(inviteNudge: 90),
        billing: FixedBilling(_premiumOffer(nudge: 70)),
        referrals: CountingReferral(answer: shareStatus),
        dedicated: FakeDedicated(_quota(80)),
      );
      expect(find.byKey(_invite), findsNothing);
      expect(find.byKey(_unlimited), findsOneWidget);
      await inviteHomeDone(tester);
    });
  });
}
