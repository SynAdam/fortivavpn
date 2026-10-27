import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/api/api_client.dart';
import 'package:fortiva_vpn/api/billing_service.dart';
import 'package:fortiva_vpn/api/referral_service.dart';
import 'package:fortiva_vpn/core/form_factor.dart';
import 'package:fortiva_vpn/core/state/billing_state.dart';
import 'package:fortiva_vpn/core/state/invite_events.dart';
import 'package:fortiva_vpn/core/state/invite_prompt.dart';
import 'package:fortiva_vpn/core/state/invite_tree_intro.dart';
import 'package:fortiva_vpn/core/state/message_state.dart';
import 'package:fortiva_vpn/core/state/notice_permission_prompt.dart';
import 'package:fortiva_vpn/core/state/premium_prompt.dart';
import 'package:fortiva_vpn/core/state/review_prompt.dart';
import 'package:fortiva_vpn/data/models/app_config.dart';
import 'package:fortiva_vpn/data/models/billing.dart';
import 'package:fortiva_vpn/data/models/in_app_message.dart';
import 'package:fortiva_vpn/data/models/version_info.dart';
import 'package:fortiva_vpn/screens/home_screen.dart';
import 'package:fortiva_vpn/screens/invite_tree_intro_screen.dart';
import 'package:fortiva_vpn/services/invite_share.dart';
import 'package:fortiva_vpn/services/notice_channel.dart';
import 'package:fortiva_vpn/services/play_billing.dart';
import 'package:fortiva_vpn/services/vpn_event_reporter.dart';
import 'package:fortiva_vpn/services/vpn_service.dart';
import 'package:fortiva_vpn/widgets/message_dialog.dart';
import 'package:fortiva_vpn/widgets/power_button.dart';
import 'package:fortiva_vpn/widgets/update_dialog.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/invite_home.dart';
import 'helpers/invite_tree.dart';

/// The invite card at its two moments: right after a good session the user
/// ended with the power button, and with a short wait when the app comes to
/// the front with the tunnel up long enough already. The rating card, the
/// Premium card, the introduction to the invite tree and the notification
/// question keep their turn before it at both.
void main() {
  final card = find.byKey(const Key('invite-card'));
  late NoticePermissionPrompt originalNotice;

  setUp(() {
    SharedPreferences.setMockInitialValues({...inviteRecord()});
    mockTunnel([]);
    UpdateDialog.resetForTest();
    MessageDialog.resetForTest();
    InviteShare.nativeForTest = true;
    InviteShare.sdkIntForTest = () async => 33;
    originalNotice = NoticePermissionPrompt.instance;
    // Already allowed: the question is never asked unless a test says so.
    NoticePermissionPrompt.instance = NoticePermissionPrompt(
      permission: () async => NoticePermission.granted,
      isTv: () => false,
    );
  });

  tearDown(() {
    FormFactor.isTvForTest = false;
    InviteShare.nativeForTest = null;
    InviteShare.sdkIntForTest = null;
    NoticePermissionPrompt.instance = originalNotice;
    unmockTunnel();
  });

  const afterStopRules = {...inviteRulesJson, 'after_disconnect': true};

  /// The home screen with every provider the card needs and enough good
  /// days saved, the tunnel up for [upFor].
  Future<({FakeVpn vpn, InvitePrompt invite, InviteEvents events})> pumpReady(
    WidgetTester tester, {
    Map<String, Object?>? rules = afterStopRules,
    Duration upFor = const Duration(hours: 1),
    VpnStatus status = VpnStatus.connected,
    bool verified = true,
    Duration? teardown,
    bool reviewOn = false,
    bool limitSheet = true,
    BillingState? billing,
    ReviewPrompt? review,
    PremiumPrompt? premium,
    CountingReferral? referrals,
    InviteTreeIntroRecord? treeIntro,
    String? treeRules,
    InvitePrompt? invite,
    MessageState? messages,
    FakeDedicated? dedicated,
    DateTime? claimOpenUntil,
  }) async {
    final vpn = FakeVpn(
      status,
      upFor: upFor,
      verified: verified,
      teardown: teardown,
    );
    final prompt = invite ?? InvitePrompt();
    final events = keptEvents();
    await pumpInviteHome(
      tester,
      vpn: vpn,
      invite: prompt,
      events: events,
      device: await registeredDevice(
        inviteDevice(rules: rules, claimOpenUntil: claimOpenUntil),
      ),
      config: await inviteConfig(
        reviewPrompt: reviewOn,
        referralRules: treeRules,
        limitSheet: limitSheet,
      ),
      billing: billing ?? FixedBilling(),
      referrals: referrals ?? CountingReferral(answer: shareStatus),
      review: review,
      premium: premium,
      treeIntro: treeIntro,
      messages: messages,
      dedicated: dedicated,
    );
    return (vpn: vpn, invite: prompt, events: events);
  }

  /// Let a page, a sheet or the card's one-frame trial come and go. The
  /// power button animates for as long as it is on screen, so the screen
  /// never settles.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// A tap on the power button.
  Future<void> tapPower(WidgetTester tester) async {
    await tester.tap(find.byType(PowerButton));
    await tester.pump();
  }

  void hide(WidgetTester tester) {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
  }

  void bringBack(WidgetTester tester) {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  }

  List<String> actions(InviteEvents events) => [
    for (final e in events.queued) '${e['surface']}/${e['action']}',
  ];

  Future<Map<String, dynamic>> saved() async {
    final prefs = await SharedPreferences.getInstance();
    return jsonDecode(prefs.getString(InvitePrompt.inviteStateKey)!)
        as Map<String, dynamic>;
  }

  /// A saved record with [goodDays], [shows] and the last show at
  /// [lastShownAt].
  Map<String, Object> record({
    int goodDays = 3,
    int shows = 0,
    DateTime? lastShownAt,
  }) => {
    InvitePrompt.inviteStateKey: jsonEncode({
      'good_days': goodDays,
      'last_good_day': '2026-01-01',
      'shows': shows,
      if (lastShownAt != null)
        'last_shown_at': lastShownAt.millisecondsSinceEpoch,
      'done': false,
      'seeded': true,
    }),
  };

  ReviewPrompt playReview({List<int>? asked}) => ReviewPrompt(
    installer: () async => ReviewPrompt.playInstaller,
    request: () async {
      asked?.add(1);
      return null;
    },
  );

  FixedBilling calmCardBilling() => FixedBilling(_calmCardInfo);

  /// The notification question not asked yet, and asked when due. [asks]
  /// counts the asks.
  NoticePermissionPrompt askingNotice(List<int> asks) => NoticePermissionPrompt(
    permission: () async => NoticePermission.ask,
    ask: () async {
      asks.add(1);
      return NoticePermission.granted;
    },
    rationale: () async => false,
    openSettings: () async => true,
    isTv: () => false,
  );

  group('right after a good session ends', () {
    testWidgets('shows after the user stops a long checked session with the '
        'power button, counted when drawn', (tester) async {
      final r = await pumpReady(tester);
      await waitSeconds(tester, 1);
      expect(card, findsNothing);
      await tapPower(tester);
      expect(r.vpn.status, VpnStatus.disconnected);
      await tester.pump(const Duration(milliseconds: 1300));
      expect(card, findsNothing);
      await settle(tester);
      expect(card, findsOneWidget);
      expect(r.invite.shownThisRun, isTrue);
      expect(actions(r.events), ['after_disconnect/shown']);
      expect((await saved())['shows'], 1);
      expect(
        find.text(
          'Does Fortiva work well for you? '
          'Send\u00A0it\u00A0to\u00A0a\u00A0friend',
        ),
        findsOneWidget,
      );
      expectPowerButtonOnScreen(
        tester,
        tester.view.physicalSize / tester.view.devicePixelRatio,
        'stopped',
      );
      // It stays while the screen rests.
      await waitSeconds(tester, 30);
      expect(card, findsOneWidget);
      await inviteHomeDone(tester);
    });

    testWidgets('waits for the tunnel to come down', (tester) async {
      final r = await pumpReady(tester, teardown: const Duration(seconds: 2));
      await waitSeconds(tester, 1);
      await tapPower(tester);
      expect(r.vpn.status, VpnStatus.disconnecting);
      await tester.pump(const Duration(milliseconds: 1900));
      expect(card, findsNothing);
      await tester.pump(const Duration(milliseconds: 200));
      expect(r.vpn.status, VpnStatus.disconnected);
      await tester.pump(const Duration(milliseconds: 1300));
      expect(card, findsNothing);
      await settle(tester);
      expect(card, findsOneWidget);
      expect(actions(r.events), ['after_disconnect/shown']);
      await inviteHomeDone(tester);
    });

    testWidgets('its buttons and close icon log under after_disconnect', (
      tester,
    ) async {
      final r = await pumpReady(tester);
      await waitSeconds(tester, 1);
      await tapPower(tester);
      await waitSeconds(tester, 3);
      // Grown into its place, and taking taps.
      await settle(tester);
      await tester.tap(find.byKey(const Key('invite-card-close')));
      await tester.pump();
      expect(card, findsNothing);
      expect(actions(r.events), [
        'after_disconnect/shown',
        'after_disconnect/dismissed',
      ]);
      await inviteHomeDone(tester);

      SharedPreferences.setMockInitialValues({...inviteRecord()});
      final s = await pumpReady(tester);
      await waitSeconds(tester, 1);
      await tapPower(tester);
      await waitSeconds(tester, 3);
      await settle(tester);
      await tester.tap(find.byKey(const Key('invite-card-telegram')));
      await tester.pump();
      await tester.pump();
      expect(card, findsNothing);
      expect(actions(s.events), [
        'after_disconnect/shown',
        'after_disconnect/telegram',
      ]);
      await tester.pump();
      expect((await saved())['done'], isTrue);
      await inviteHomeDone(tester);
    });

    testWidgets('goes when the user taps connect', (tester) async {
      await pumpReady(tester);
      await waitSeconds(tester, 1);
      await tapPower(tester);
      await waitSeconds(tester, 3);
      expect(card, findsOneWidget);
      await tapPower(tester);
      expect(card, findsNothing);
      await waitSeconds(tester, 10);
      expect(card, findsNothing);
      await inviteHomeDone(tester);
    });

    testWidgets('goes when a sheet opens over it, and stays gone', (
      tester,
    ) async {
      await pumpReady(tester);
      await waitSeconds(tester, 1);
      await tapPower(tester);
      await waitSeconds(tester, 3);
      expect(card, findsOneWidget);
      final home = tester.element(find.byType(HomeScreen));
      unawaited(
        showModalBottomSheet<void>(
          context: home,
          builder: (_) => const SizedBox(height: 200),
        ),
      );
      await settle(tester);
      Navigator.of(home).pop();
      await settle(tester);
      expect(card, findsNothing);
      await waitSeconds(tester, 10);
      expect(card, findsNothing);
      await inviteHomeDone(tester);
    });

    testWidgets('goes when the app is hidden', (tester) async {
      await pumpReady(tester);
      await waitSeconds(tester, 1);
      await tapPower(tester);
      await waitSeconds(tester, 3);
      expect(card, findsOneWidget);
      hide(tester);
      await tester.pump();
      bringBack(tester);
      await waitSeconds(tester, 10);
      expect(card, findsNothing);
      await inviteHomeDone(tester);
    });

    testWidgets('never when the app is hidden before it shows', (tester) async {
      await pumpReady(tester);
      await waitSeconds(tester, 1);
      await tapPower(tester);
      await tester.pump(const Duration(milliseconds: 500));
      hide(tester);
      await waitSeconds(tester, 3);
      bringBack(tester);
      await waitSeconds(tester, 10);
      expect(card, findsNothing);
      await inviteHomeDone(tester);
    });

    testWidgets('never after a short session', (tester) async {
      await pumpReady(tester, upFor: const Duration(minutes: 4));
      await waitSeconds(tester, 1);
      await tapPower(tester);
      await waitSeconds(tester, 10);
      expect(card, findsNothing);
      await inviteHomeDone(tester);
    });

    testWidgets('never after a session that was never checked', (tester) async {
      await pumpReady(tester, verified: false);
      await waitSeconds(tester, 1);
      await tapPower(tester);
      await waitSeconds(tester, 10);
      expect(card, findsNothing);
      await inviteHomeDone(tester);
    });

    testWidgets('never after a drop', (tester) async {
      final r = await pumpReady(tester);
      await waitSeconds(tester, 1);
      r.invite.record(VpnEventType.dropped);
      r.vpn.become(VpnStatus.disconnected);
      await waitSeconds(tester, 10);
      expect(card, findsNothing);
      await inviteHomeDone(tester);
    });

    testWidgets('never after a stop from the notification or the quick '
        'settings tile', (tester) async {
      // The tunnel goes down without a tap on the screen.
      final r = await pumpReady(tester);
      await waitSeconds(tester, 1);
      r.vpn.become(VpnStatus.disconnected);
      await waitSeconds(tester, 10);
      expect(card, findsNothing);
      await inviteHomeDone(tester);
    });

    testWidgets('never after a stop while the app is away', (tester) async {
      final r = await pumpReady(tester);
      await waitSeconds(tester, 1);
      hide(tester);
      await tester.pump();
      r.vpn.become(VpnStatus.disconnected);
      await waitSeconds(tester, 2);
      bringBack(tester);
      await waitSeconds(tester, 10);
      expect(card, findsNothing);
      await inviteHomeDone(tester);
    });

    testWidgets('never after a session with a failure in it', (tester) async {
      final r = await pumpReady(tester);
      await waitSeconds(tester, 1);
      r.invite.record(VpnEventType.verifyFailed);
      await tester.pump();
      await tapPower(tester);
      await waitSeconds(tester, 10);
      expect(card, findsNothing);
      await inviteHomeDone(tester);
    });

    testWidgets('never without the backend block (the holdout)', (
      tester,
    ) async {
      await pumpReady(tester, rules: null);
      await waitSeconds(tester, 1);
      await tapPower(tester);
      await waitSeconds(tester, 10);
      expect(card, findsNothing);
      await inviteHomeDone(tester);
    });

    testWidgets('never without after_disconnect, while the card during a '
        'session still shows', (tester) async {
      for (final rules in [
        inviteRulesJson,
        {...inviteRulesJson, 'after_disconnect': false},
        {...inviteRulesJson, 'after_disconnect': 'true'},
      ]) {
        SharedPreferences.setMockInitialValues({...inviteRecord()});
        await pumpReady(tester, rules: rules);
        await waitSeconds(tester, 1);
        await tapPower(tester);
        await waitSeconds(tester, 10);
        expect(card, findsNothing, reason: '$rules');
        await inviteHomeDone(tester);

        SharedPreferences.setMockInitialValues({...inviteRecord()});
        final r = await pumpReady(tester, rules: rules);
        await waitSeconds(tester, 5);
        expect(card, findsOneWidget, reason: '$rules');
        expect(actions(r.events), ['after_connect/shown']);
        await inviteHomeDone(tester);
      }
    });

    testWidgets('never before the good days', (tester) async {
      SharedPreferences.setMockInitialValues({...record(goodDays: 2)});
      await pumpReady(tester);
      await waitSeconds(tester, 1);
      await tapPower(tester);
      await waitSeconds(tester, 10);
      expect(card, findsNothing);
      await inviteHomeDone(tester);
    });

    testWidgets('never within every_days of the last show', (tester) async {
      SharedPreferences.setMockInitialValues({
        ...record(
          shows: 1,
          lastShownAt: DateTime.now().subtract(const Duration(days: 13)),
        ),
      });
      await pumpReady(tester);
      await waitSeconds(tester, 1);
      await tapPower(tester);
      await waitSeconds(tester, 10);
      expect(card, findsNothing);
      await inviteHomeDone(tester);

      // After the wait it shows again, and the shows add up.
      SharedPreferences.setMockInitialValues({
        ...record(
          shows: 1,
          lastShownAt: DateTime.now().subtract(const Duration(days: 15)),
        ),
      });
      await pumpReady(tester);
      await waitSeconds(tester, 1);
      await tapPower(tester);
      await waitSeconds(tester, 3);
      expect(card, findsOneWidget);
      expect((await saved())['shows'], 2);
      await inviteHomeDone(tester);
    });

    testWidgets('never after max_shows, counted with the card during a '
        'session', (tester) async {
      SharedPreferences.setMockInitialValues({
        ...record(
          shows: 3,
          lastShownAt: DateTime.now().subtract(const Duration(days: 30)),
        ),
      });
      await pumpReady(tester);
      await waitSeconds(tester, 1);
      await tapPower(tester);
      await waitSeconds(tester, 10);
      expect(card, findsNothing);
      await inviteHomeDone(tester);
    });

    testWidgets('never in a run the card already showed in', (tester) async {
      final r = await pumpReady(tester);
      await waitSeconds(tester, 5);
      expect(card, findsOneWidget);
      await settle(tester);
      await tester.tap(find.byKey(const Key('invite-card-close')));
      await tester.pump();
      await tapPower(tester);
      await waitSeconds(tester, 10);
      expect(card, findsNothing);
      expect(actions(r.events), [
        'after_connect/shown',
        'after_connect/dismissed',
      ]);
      await inviteHomeDone(tester);
    });

    testWidgets('never in a run the Premium card showed in', (tester) async {
      final billing = calmCardBilling();
      final premium = PremiumPrompt(billing: billing);
      await pumpReady(tester, billing: billing, premium: premium);
      await waitSeconds(tester, 20);
      expect(premium.shownThisRun, isTrue);
      await tapPower(tester);
      await waitSeconds(tester, 10);
      expect(card, findsNothing);
      await inviteHomeDone(tester);
    });

    testWidgets('never in a run the introduction to the invite tree opened '
        'in', (tester) async {
      await pumpReady(
        tester,
        referrals: CountingReferral(
          answer: ReferralStatus.fromJson(treeAnswer()),
        ),
        treeIntro: InviteTreeIntroRecord(),
        treeRules: 'tree',
      );
      await waitSeconds(tester, 7);
      expect(find.byType(InviteTreeIntroScreen), findsOneWidget);
      await tester.tap(find.byKey(const Key('invite-tree-intro-skip')));
      await settle(tester);
      await tapPower(tester);
      await waitSeconds(tester, 10);
      expect(card, findsNothing);
      await inviteHomeDone(tester);
    });

    testWidgets('gives way to the introduction to the invite tree while it '
        'may still open in this run', (tester) async {
      final r = await pumpReady(
        tester,
        referrals: CountingReferral(
          answer: ReferralStatus.fromJson(treeAnswer()),
        ),
        treeIntro: InviteTreeIntroRecord(),
        treeRules: 'tree',
      );
      // Stopped before the introduction's wait was over.
      await waitSeconds(tester, 1);
      await tapPower(tester);
      await waitSeconds(tester, 10);
      expect(card, findsNothing);
      expect(find.byType(InviteTreeIntroScreen), findsNothing);
      expect(r.invite.shownThisRun, isFalse);
      // It opens on the next calm moment with the tunnel up, and the card
      // waits for the next run.
      r.vpn.become(VpnStatus.connected);
      await waitSeconds(tester, 7);
      expect(find.byType(InviteTreeIntroScreen), findsOneWidget);
      await tester.tap(find.byKey(const Key('invite-tree-intro-skip')));
      await settle(tester);
      await tapPower(tester);
      await waitSeconds(tester, 10);
      expect(card, findsNothing);
      expect(actions(r.events), isNot(contains('after_disconnect/shown')));
      await inviteHomeDone(tester);
    });

    testWidgets('shows under the tree rule once the introduction opened on '
        'an earlier run', (tester) async {
      SharedPreferences.setMockInitialValues({
        ...inviteRecord(),
        InviteTreeIntroRecord.seenKey: true,
      });
      final referrals = CountingReferral(
        answer: ReferralStatus.fromJson(treeAnswer()),
      );
      final r = await pumpReady(
        tester,
        referrals: referrals,
        treeIntro: InviteTreeIntroRecord(),
        treeRules: 'tree',
      );
      await waitSeconds(tester, 1);
      await tapPower(tester);
      await waitSeconds(tester, 3);
      expect(card, findsOneWidget);
      expect(actions(r.events), ['after_disconnect/shown']);
      expect(referrals.reads, 0, reason: 'nothing loads the referral answer');
      await inviteHomeDone(tester);
    });

    testWidgets('waits for the introduction\'s last look, and shows when it '
        'opens nothing', (tester) async {
      final referrals = _SlowReferral(
        answer: ReferralStatus.fromJson(oldAnswer()),
      );
      final r = await pumpReady(
        tester,
        referrals: referrals,
        treeIntro: InviteTreeIntroRecord(),
        treeRules: 'tree',
      );
      // The introduction's wait is over, and its referral answer is on its
      // way when the user stops.
      await waitSeconds(tester, 6);
      expect(referrals.reads, 1);
      await tapPower(tester);
      await waitSeconds(tester, 5);
      expect(card, findsNothing);
      // The answer says today's rule: nothing opens, and the card has its
      // turn after the stop.
      referrals.gate.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1300));
      expect(card, findsNothing);
      await settle(tester);
      expect(find.byType(InviteTreeIntroScreen), findsNothing);
      expect(card, findsOneWidget);
      expect(actions(r.events), ['after_disconnect/shown']);
      await inviteHomeDone(tester);
    });

    testWidgets('gives way to the rating card when it is due', (tester) async {
      SharedPreferences.setMockInitialValues({
        ...inviteRecord(),
        ...reviewRecord(),
      });
      await pumpReady(tester, review: playReview(), reviewOn: true);
      await waitSeconds(tester, 1);
      await tapPower(tester);
      await waitSeconds(tester, 10);
      expect(card, findsNothing);
      await inviteHomeDone(tester);
    });

    testWidgets('never on a TV', (tester) async {
      FormFactor.isTvForTest = true;
      await pumpReady(tester);
      await waitSeconds(tester, 1);
      await tapPower(tester);
      await waitSeconds(tester, 10);
      expect(card, findsNothing);
      await inviteHomeDone(tester);
    });

    testWidgets('never in a run the update dialog showed in', (tester) async {
      final r = await pumpReady(tester);
      final home = tester.element(find.byType(HomeScreen));
      unawaited(
        UpdateDialog.maybeShow(
          home,
          ForceUpdate(ios: _update(), android: _update()),
          currentVersion: '1.4.1',
          android: true,
          open: (_) async {},
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(UpdateDialog.isShowing, isTrue);
      Navigator.of(home).pop();
      await settle(tester);
      await tapPower(tester);
      await waitSeconds(tester, 10);
      expect(card, findsNothing);
      expect(actions(r.events), isEmpty);
      await inviteHomeDone(tester);
    });

    testWidgets('never while a message popup waits', (tester) async {
      final messages = _waitingMessage();
      await messages.refresh();
      expect(messages.pendingPopup, isNotNull);
      final r = await pumpReady(tester, messages: messages);
      // Stopped before the popup's calm wait was over. It pops up only
      // with the tunnel up, so it is still waiting after the stop.
      await waitSeconds(tester, 1);
      await tapPower(tester);
      await waitSeconds(tester, 10);
      expect(messages.pendingPopup, isNotNull);
      expect(card, findsNothing);
      expect(actions(r.events), isEmpty);
      await inviteHomeDone(tester);
    });

    testWidgets('never once the allowance is spent', (tester) async {
      // The app stops the tunnel when the allowance is spent
      // (refreshAllowance), so here it runs out just after the user's stop.
      // With the limit sheet off, only the spent allowance keeps the card
      // away.
      final dedicated = FakeDedicated();
      final r = await pumpReady(
        tester,
        dedicated: dedicated,
        limitSheet: false,
      );
      await waitSeconds(tester, 1);
      await tapPower(tester);
      expect(r.vpn.status, VpnStatus.disconnected);
      dedicated.become(inviteQuota(blocked: true));
      await waitSeconds(tester, 10);
      expect(find.byType(BottomSheet), findsNothing);
      expect(card, findsNothing);
      expect(actions(r.events), isEmpty);
      expect(r.invite.shownThisRun, isFalse);
      await inviteHomeDone(tester);
    });

    testWidgets('never in a run the notification question was asked in', (
      tester,
    ) async {
      final asks = <int>[];
      NoticePermissionPrompt.instance = askingNotice(asks);
      final r = await pumpReady(tester);
      await waitSeconds(tester, 15);
      expect(asks, [1]);
      await tapPower(tester);
      await waitSeconds(tester, 10);
      expect(card, findsNothing);
      expect(actions(r.events), isEmpty);
      await inviteHomeDone(tester);
    });

    testWidgets('gives way to the notification question when it is due', (
      tester,
    ) async {
      final asks = <int>[];
      NoticePermissionPrompt.instance = askingNotice(asks);
      final r = await pumpReady(tester);
      // Stopped before the question was asked.
      await waitSeconds(tester, 1);
      expect(asks, isEmpty);
      await tapPower(tester);
      await waitSeconds(tester, 10);
      expect(card, findsNothing);
      expect(actions(r.events), isEmpty);
      await inviteHomeDone(tester);
    });

    testWidgets('gives way to the Premium card when it is due', (tester) async {
      final billing = calmCardBilling();
      final premium = PremiumPrompt(billing: billing);
      final r = await pumpReady(tester, billing: billing, premium: premium);
      // Stopped before the Premium card's wait was over: it is due, and
      // has not shown.
      await waitSeconds(tester, 1);
      await tapPower(tester);
      await waitSeconds(tester, 10);
      expect(premium.shownThisRun, isFalse);
      expect(card, findsNothing);
      expect(actions(r.events), isEmpty);
      await inviteHomeDone(tester);
    });

    testWidgets('never while the payments have not answered', (tester) async {
      // At app start, before the payments' first answer, the Premium card
      // cannot tell whether it is due.
      final r = await pumpReady(tester, billing: _LateBilling());
      await waitSeconds(tester, 1);
      await tapPower(tester);
      await waitSeconds(tester, 10);
      expect(card, findsNothing);
      expect(actions(r.events), isEmpty);
      await inviteHomeDone(tester);
    });

    testWidgets('never after a stop on a stalled tunnel', (tester) async {
      final r = await pumpReady(tester);
      await waitSeconds(tester, 1);
      r.vpn.stalledForTest = true;
      r.vpn.changed();
      await tester.pump();
      await tapPower(tester);
      await waitSeconds(tester, 10);
      expect(card, findsNothing);
      expect(actions(r.events), isEmpty);
      await inviteHomeDone(tester);
    });

    testWidgets('never after a stop with a failure on screen', (tester) async {
      final r = await pumpReady(tester, teardown: const Duration(seconds: 2));
      await waitSeconds(tester, 1);
      r.vpn.errorForTest = 'The connection failed';
      r.vpn.changed();
      await tester.pump();
      await tapPower(tester);
      expect(r.vpn.status, VpnStatus.disconnecting);
      // Gone before the tunnel is down, so the screen then comes to rest
      // as after any stop.
      r.vpn.errorForTest = null;
      r.vpn.changed();
      await waitSeconds(tester, 10);
      expect(r.vpn.status, VpnStatus.disconnected);
      expect(card, findsNothing);
      expect(actions(r.events), isEmpty);
      await inviteHomeDone(tester);
    });

    testWidgets('goes when a failure shows', (tester) async {
      final r = await pumpReady(tester);
      await waitSeconds(tester, 1);
      await tapPower(tester);
      await waitSeconds(tester, 3);
      expect(card, findsOneWidget);
      r.vpn.errorForTest = 'The connection failed';
      r.vpn.changed();
      await tester.pump();
      expect(card, findsNothing);
      await inviteHomeDone(tester);
    });

    testWidgets('never when connect is tapped while the record is read', (
      tester,
    ) async {
      final gate = Completer<void>();
      final invite = InvitePrompt(
        prefs: () async {
          await gate.future;
          return SharedPreferences.getInstance();
        },
      );
      final r = await pumpReady(tester, invite: invite);
      await waitSeconds(tester, 1);
      await tapPower(tester);
      // The calm wait is over, and the card waits for its record.
      await waitSeconds(tester, 2);
      r.vpn.become(VpnStatus.connecting);
      await tester.pump();
      gate.complete();
      await settle(tester);
      expect(card, findsNothing);
      expect(invite.shownThisRun, isFalse);
      expect(actions(r.events), isNot(contains('after_disconnect/shown')));
      await inviteHomeDone(tester);
    });

    testWidgets('under the tree rule, a phone with Premium gets the card '
        'after a stop', (tester) async {
      // With Premium the introduction never opens, so the card does not
      // wait for it.
      final billing = FixedBilling(
        BillingInfo(
          enabled: true,
          premium: Premium(
            active: true,
            until: DateTime.now().add(const Duration(days: 20)),
            source: 'voucher',
          ),
          rails: const Rails(codes: true),
        ),
      );
      final r = await pumpReady(
        tester,
        billing: billing,
        referrals: CountingReferral(
          answer: ReferralStatus.fromJson(treeAnswer()),
        ),
        treeIntro: InviteTreeIntroRecord(),
        treeRules: 'tree',
      );
      await waitSeconds(tester, 1);
      await tapPower(tester);
      await waitSeconds(tester, 3);
      expect(find.byType(InviteTreeIntroScreen), findsNothing);
      expect(card, findsOneWidget);
      expect(actions(r.events), ['after_disconnect/shown']);
      await inviteHomeDone(tester);
    });
  });

  group('when the app comes to the front with the tunnel up', () {
    testWidgets('a tunnel that came up with the app open waits for the '
        'calm wait', (tester) async {
      final r = await pumpReady(tester, status: VpnStatus.disconnected);
      await waitSeconds(tester, 1);
      // It came up after the app did. Up for min_session_minutes by the
      // time it is asked, but not when the app came to the front.
      r.vpn.become(VpnStatus.connected, upFor: const Duration(minutes: 5));
      await waitSeconds(tester, 19);
      expect(card, findsNothing);
      await waitSeconds(tester, 2);
      expect(card, findsOneWidget);
      expect(actions(r.events), ['after_connect/shown']);
      // Down again, which stops the tunnel service's heartbeat.
      r.vpn.become(VpnStatus.disconnected);
      await inviteHomeDone(tester);
    });

    testWidgets('back in front, it shows after the short wait', (tester) async {
      final r = await pumpReady(tester);
      await waitSeconds(tester, 2);
      hide(tester);
      await waitSeconds(tester, 30);
      expect(card, findsNothing);
      bringBack(tester);
      await waitSeconds(tester, 3);
      expect(card, findsNothing);
      await waitSeconds(tester, 2);
      expect(card, findsOneWidget);
      expect(actions(r.events), ['after_connect/shown']);
      await inviteHomeDone(tester);
    });

    testWidgets('a tunnel up less than min_session_minutes waits as before', (
      tester,
    ) async {
      await pumpReady(tester, upFor: const Duration(minutes: 4));
      await waitSeconds(tester, 30);
      expect(card, findsNothing);
      await inviteHomeDone(tester);
    });

    testWidgets('a no is asked once per visit, and again on the next', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({...record(goodDays: 2)});
      final r = await pumpReady(tester);
      await waitSeconds(tester, 5);
      expect(card, findsNothing);
      // A good day more, as if the user connected on another day. Within
      // this visit the card is not asked again, however often the screen
      // changes.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        InvitePrompt.inviteStateKey,
        jsonEncode({
          'good_days': 3,
          'last_good_day': '2026-01-02',
          'shows': 0,
          'done': false,
          'seeded': true,
        }),
      );
      for (var i = 0; i < 6; i++) {
        r.vpn.become(VpnStatus.connected);
        await waitSeconds(tester, 5);
      }
      expect(card, findsNothing);
      // The next time the app comes to the front, it is asked again.
      hide(tester);
      await tester.pump();
      bringBack(tester);
      await waitSeconds(tester, 5);
      expect(card, findsOneWidget);
      r.vpn.become(VpnStatus.disconnected);
      await inviteHomeDone(tester);
    });

    testWidgets('a sheet open at the moment holds it off without a no', (
      tester,
    ) async {
      await pumpReady(tester);
      final home = tester.element(find.byType(HomeScreen));
      unawaited(
        showModalBottomSheet<void>(
          context: home,
          builder: (_) => const SizedBox(height: 200),
        ),
      );
      await waitSeconds(tester, 6);
      expect(card, findsNothing);
      Navigator.of(home).pop();
      await settle(tester);
      // Back in front with the sheet gone: asked again.
      hide(tester);
      await tester.pump();
      bringBack(tester);
      await waitSeconds(tester, 5);
      expect(card, findsOneWidget);
      await inviteHomeDone(tester);
    });

    testWidgets('the rating card keeps its turn', (tester) async {
      SharedPreferences.setMockInitialValues({
        ...inviteRecord(),
        ...reviewRecord(),
      });
      final asked = <int>[];
      final review = playReview(asked: asked);
      await pumpReady(tester, review: review, reviewOn: true);
      await waitSeconds(tester, 5);
      expect(card, findsNothing);
      await waitSeconds(tester, 10);
      expect(asked, [1]);
      await waitSeconds(tester, 30);
      expect(card, findsNothing);
      await inviteHomeDone(tester);
    });

    testWidgets('the Premium card keeps its turn', (tester) async {
      final billing = calmCardBilling();
      final premium = PremiumPrompt(billing: billing);
      await pumpReady(tester, billing: billing, premium: premium);
      await waitSeconds(tester, 5);
      expect(card, findsNothing);
      await waitSeconds(tester, 15);
      expect(premium.shownThisRun, isTrue);
      expect(find.text('Want no daily limit?'), findsOneWidget);
      expect(card, findsNothing);
      await inviteHomeDone(tester);
    });

    testWidgets('the Premium card keeps its turn when the payments answer '
        'after the short wait', (tester) async {
      // At app start the payments answer some seconds after the screen is
      // built, and the short wait counts from their answer.
      final billing = _LateBilling();
      final premium = PremiumPrompt(billing: billing);
      final r = await pumpReady(tester, billing: billing, premium: premium);
      await waitSeconds(tester, 6);
      expect(card, findsNothing);
      billing.adoptForTest(_calmCardInfo);
      billing.adoptWorkedForTest();
      await waitSeconds(tester, 30);
      expect(premium.shownThisRun, isTrue);
      expect(r.invite.shownThisRun, isFalse);
      expect(card, findsNothing);
      await inviteHomeDone(tester);
    });

    testWidgets('waits for the payments\' answer, then the short wait', (
      tester,
    ) async {
      final billing = _LateBilling();
      final r = await pumpReady(tester, billing: billing);
      await waitSeconds(tester, 6);
      expect(card, findsNothing);
      // No Premium card is offered here, so the card has its turn.
      billing.adoptForTest(const BillingInfo(enabled: false));
      await waitSeconds(tester, 3);
      expect(card, findsNothing);
      await waitSeconds(tester, 2);
      expect(card, findsOneWidget);
      expect(actions(r.events), ['after_connect/shown']);
      await inviteHomeDone(tester);
    });

    testWidgets('the notification question keeps its turn', (tester) async {
      var asks = 0;
      NoticePermissionPrompt.instance = NoticePermissionPrompt(
        permission: () async => NoticePermission.ask,
        ask: () async {
          asks++;
          return NoticePermission.granted;
        },
        rationale: () async => false,
        openSettings: () async => true,
        isTv: () => false,
      );
      await pumpReady(tester);
      await waitSeconds(tester, 5);
      expect(card, findsNothing);
      await waitSeconds(tester, 10);
      expect(asks, 1);
      expect(card, findsNothing);
      await inviteHomeDone(tester);
    });

    testWidgets('the introduction to the invite tree keeps its turn', (
      tester,
    ) async {
      await pumpReady(
        tester,
        referrals: CountingReferral(
          answer: ReferralStatus.fromJson(treeAnswer()),
        ),
        treeIntro: InviteTreeIntroRecord(),
        treeRules: 'tree',
      );
      await waitSeconds(tester, 4);
      await tester.pump(const Duration(milliseconds: 500));
      expect(card, findsNothing);
      await waitSeconds(tester, 2);
      expect(find.byType(InviteTreeIntroScreen), findsOneWidget);
      await inviteHomeDone(tester);
    });

    testWidgets('an introduction that opens nothing gives the card its turn', (
      tester,
    ) async {
      final referrals = CountingReferral(
        answer: ReferralStatus.fromJson(oldAnswer()),
      );
      final r = await pumpReady(
        tester,
        referrals: referrals,
        treeIntro: InviteTreeIntroRecord(),
        treeRules: 'tree',
      );
      await waitSeconds(tester, 6);
      expect(referrals.reads, 1);
      expect(find.byType(InviteTreeIntroScreen), findsNothing);
      expect(card, findsNothing);
      await waitSeconds(tester, 5);
      expect(card, findsOneWidget);
      expect(actions(r.events), ['after_connect/shown']);
      await inviteHomeDone(tester);
    });
  });

  group('how the card comes and goes on a phone', () {
    final button = find.byType(PowerButton);
    final statusLine = find.byWidgetPredicate(
      (w) => w.runtimeType.toString() == '_StatusLine',
    );
    final serverCard = find
        .ancestor(of: find.text('OUR SERVER'), matching: find.byType(InkWell))
        .first;
    final codeRow = find.byKey(const Key('home-have-code'));

    /// A phone held upright, [size] in logical pixels.
    void phone(WidgetTester tester, Size size) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }

    /// Frame by frame until the card is drawn, checking on each frame
    /// before that that [still] has not moved. At most two seconds.
    Future<void> untilDrawn(WidgetTester tester, List<Finder> still) async {
      final at = [for (final f in still) tester.getRect(f)];
      for (var i = 0; i < 125; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        if (card.evaluate().isNotEmpty) return;
        for (var j = 0; j < still.length; j++) {
          expect(tester.getRect(still[j]), at[j], reason: '${still[j]}');
        }
      }
    }

    testWidgets('nothing moves while the card is tried, and the power button '
        'glides up as the card grows in', (tester) async {
      phone(tester, const Size(412, 915));
      await pumpReady(tester);
      await waitSeconds(tester, 1);
      await tapPower(tester);
      await tester.pump(const Duration(seconds: 1));
      final from = tester.getRect(button).top;
      await untilDrawn(tester, [button, statusLine, serverCard]);
      expect(card, findsOneWidget);
      final tops = <double>[];
      for (var i = 0; i < 25; i++) {
        tops.add(tester.getRect(button).top);
        await tester.pump(const Duration(milliseconds: 16));
      }
      final to = tester.getRect(button).top;
      expect(to, lessThan(from - 20));
      // No frame moves it more than a third of the way.
      var last = from;
      for (final top in [...tops, to]) {
        expect(last - top, lessThan((from - to) / 3));
        expect(last - top, greaterThanOrEqualTo(-0.01));
        last = top;
      }
      expectPowerButtonOnScreen(
        tester,
        const Size(412, 915),
        'card up',
        line: true,
      );
      await inviteHomeDone(tester);
    });

    testWidgets('where the card does not fit, nothing on screen moves for '
        'its trial', (tester) async {
      phone(tester, const Size(320, 568));
      final r = await pumpReady(tester);
      await waitSeconds(tester, 1);
      await tapPower(tester);
      await tester.pump(const Duration(seconds: 1));
      await untilDrawn(tester, [button, statusLine, serverCard]);
      expect(card, findsNothing);
      expect(actions(r.events), isEmpty);
      expect((await saved())['shows'], 0);
      // The line under the button is cut on this phone with no card at
      // all, which is the screen's own layout, not the card's.
      expectPowerButtonOnScreen(tester, const Size(320, 568), 'gave way');
      await inviteHomeDone(tester);
    });

    testWidgets('a tap meant for the server card while the code row makes '
        'way does not share', (tester) async {
      phone(tester, const Size(412, 915));
      final calls = <MethodCall>[];
      mockTunnel(calls);
      final r = await pumpReady(
        tester,
        claimOpenUntil: DateTime.now().add(const Duration(hours: 5)),
      );
      await waitSeconds(tester, 1);
      expect(codeRow, findsOneWidget);
      await tapPower(tester);
      await tester.pump(const Duration(seconds: 1));
      final server = tester.getRect(serverCard);
      // The code row stays while the card is tried.
      await untilDrawn(tester, [button, serverCard, codeRow]);
      expect(card, findsOneWidget);
      // Grown in, and the server card has moved down under it.
      await tester.pump(const Duration(milliseconds: 300));
      expect(codeRow, findsNothing);
      expect(tester.getRect(serverCard).top, greaterThan(server.top + 20));
      // One of the card's buttons now covers where the top of the server
      // card was a moment ago.
      Offset? spot;
      // Copy link last: it needs the clipboard, which these tests leave out.
      for (final target in [
        InviteTarget.otherApps,
        InviteTarget.telegram,
        InviteTarget.whatsapp,
        InviteTarget.copyLink,
      ]) {
        final shared = tester
            .getRect(find.byKey(Key('invite-card-${target.name}')))
            .intersect(server);
        if (shared.width > 8 && shared.height > 8) {
          spot = shared.center;
          break;
        }
      }
      expect(spot, isNotNull, reason: 'a button where the server card was');
      await tester.tapAt(spot!);
      await tester.pump();
      await tester.pump();
      expect(actions(r.events), ['after_disconnect/shown']);
      expect(calls.where((c) => c.method == 'shareInvite'), isEmpty);
      expect(card, findsOneWidget);
      // Once the card takes taps, the same tap shares.
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tapAt(spot);
      await tester.pump();
      await tester.pump();
      expect(actions(r.events), hasLength(2));
      expect(actions(r.events).last, startsWith('after_disconnect/'));
      expect(calls.where((c) => c.method == 'shareInvite'), hasLength(1));
      await settle(tester);
      await inviteHomeDone(tester);
    });
  });
}

/// Payments offering the calm Premium card.
final _calmCardInfo = BillingInfo(
  enabled: true,
  plans: const [
    Plan(
      code: 'unlimited_30d',
      google: PlayProductRef(productId: 'premium', basePlanId: 'p30'),
    ),
  ],
  rails: const Rails(googlePlay: true, codes: true),
  upsell: Upsell(
    surfaces: {UpsellSurface.calmCard},
    promptEveryHours: 168,
    promptMax: 3,
  ),
);

/// Payments with no answer yet, as in the app before its first load ends.
/// A test gives the answer with adoptForTest.
class _LateBilling extends BillingState {
  _LateBilling()
    : super(
        service: BillingService(
          client: ApiClient.forTest(
            direct: MockClient((_) async => throw http.ClientException('no')),
          ),
        ),
        playBilling: () => _NoPlay(),
        deviceId: () async => 'DEV-1',
      ) {
    madeBilling.add(this);
  }

  @override
  Future<void> refresh() async {}
}

class _NoPlay implements PlayBilling {
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

/// A message that waits to pop up once the screen is calm with the tunnel
/// up. Call refresh before the screen is built.
MessageState _waitingMessage() {
  final sent = DateTime.now().toUtc().subtract(const Duration(minutes: 1));
  return MessageState(
    fetch: (_, _) async => MessagesPage.fromJson({
      'server_time': DateTime.now().toUtc().toIso8601String(),
      'messages': [
        {
          'id': 1,
          'language': 'en',
          'title': 'News',
          'body': 'Body',
          'button': null,
          'link': null,
          'sent_at': sent.toIso8601String(),
          'ends_at': sent.add(const Duration(days: 7)).toIso8601String(),
        },
      ],
    }),
    post: (_, _) async {},
    deviceId: () async => 'DEV-1',
    register: () async {},
    language: () => 'en',
    flushDelay: const Duration(days: 1),
  );
}

PlatformVersion _update() => PlatformVersion(
  latestVersion: '9.9.9',
  minimumVersion: '1.0.0',
  updateRequired: false,
  updateUrl: 'https://play.google.com/store/apps/details?id=com.vpn.fortivavpn',
  releaseNotes: null,
);

/// A referral state whose answer comes only once [gate] is complete.
class _SlowReferral extends CountingReferral {
  _SlowReferral({required super.answer});

  final gate = Completer<void>();

  @override
  Future<void> refresh() async {
    reads++;
    await gate.future;
    final status = answer;
    if (status != null) adoptForTest(status);
  }
}
