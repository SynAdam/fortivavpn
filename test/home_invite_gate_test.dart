import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/core/form_factor.dart';
import 'package:fortiva_vpn/core/state/billing_state.dart';
import 'package:fortiva_vpn/core/state/invite_events.dart';
import 'package:fortiva_vpn/core/state/invite_prompt.dart';
import 'package:fortiva_vpn/core/state/message_state.dart';
import 'package:fortiva_vpn/core/state/notice_permission_prompt.dart';
import 'package:fortiva_vpn/core/state/premium_prompt.dart';
import 'package:fortiva_vpn/core/state/review_prompt.dart';
import 'package:fortiva_vpn/data/models/app_config.dart';
import 'package:fortiva_vpn/data/models/billing.dart';
import 'package:fortiva_vpn/data/models/in_app_message.dart';
import 'package:fortiva_vpn/data/models/version_info.dart';
import 'package:fortiva_vpn/screens/home_screen.dart';
import 'package:fortiva_vpn/services/invite_share.dart';
import 'package:fortiva_vpn/services/notice_channel.dart';
import 'package:fortiva_vpn/services/vpn_service.dart';
import 'package:fortiva_vpn/widgets/message_dialog.dart';
import 'package:fortiva_vpn/widgets/update_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/invite_home.dart';

/// When the invite card shows on the home screen (clients #271): after
/// good days, once per run, and never with the rating card, the Premium
/// card or any other popup in the same run, nor on the rating card's
/// Tehran day.
void main() {
  final card = find.byKey(const Key('invite-card'));
  late List<MethodCall> calls;
  late NoticePermissionPrompt originalNotice;

  setUp(() {
    SharedPreferences.setMockInitialValues({...inviteRecord()});
    calls = [];
    mockTunnel(calls);
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

  /// The home screen with every provider the card needs, the tunnel up for
  /// an hour, and enough good days saved.
  Future<
    ({
      FakeVpn vpn,
      InvitePrompt invite,
      InviteEvents events,
      CountingReferral referrals,
    })
  >
  pumpReady(
    WidgetTester tester, {
    Map<String, Object?>? rules = inviteRulesJson,
    bool referralsOn = true,
    bool reviewOn = false,
    BillingState? billing,
    ReviewPrompt? review,
    PremiumPrompt? premium,
    MessageState? messages,
    CountingReferral? referrals,
    FakeDedicated? dedicated,
    bool withInvite = true,
    bool withDevice = true,
    bool withBilling = true,
  }) async {
    final vpn = FakeVpn(VpnStatus.connected);
    final invite = InvitePrompt();
    final events = keptEvents();
    final referral = referrals ?? (CountingReferral(answer: shareStatus));
    await pumpInviteHome(
      tester,
      vpn: vpn,
      invite: withInvite ? invite : null,
      events: events,
      device: withDevice
          ? await registeredDevice(inviteDevice(rules: rules))
          : null,
      config: await inviteConfig(
        referrals: referralsOn,
        reviewPrompt: reviewOn,
      ),
      billing: withBilling ? (billing ?? FixedBilling()) : null,
      referrals: referral,
      review: review,
      premium: premium,
      messages: messages,
      dedicated: dedicated,
    );
    return (vpn: vpn, invite: invite, events: events, referrals: referral);
  }

  /// Let a page or a sheet open or close. The power button animates for
  /// as long as it is on screen, so the screen never settles.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  List<String> actions(InviteEvents events) => [
    for (final e in events.queued) '${e['surface']}/${e['action']}',
  ];

  Future<Map<String, dynamic>> saved() async {
    final prefs = await SharedPreferences.getInstance();
    return jsonDecode(prefs.getString(InvitePrompt.inviteStateKey)!)
        as Map<String, dynamic>;
  }

  testWidgets('shows after the calm wait, counted when drawn', (tester) async {
    final r = await pumpReady(tester);
    await waitSeconds(tester, 19);
    expect(card, findsNothing);
    await waitSeconds(tester, 2);
    expect(card, findsOneWidget);
    expect(r.invite.shownThisRun, isTrue);
    expect(actions(r.events), ['after_connect/shown']);
    expect((await saved())['shows'], 1);
    expect(
      find.textContaining(
        'When your friend starts using Fortiva, you get 3 days of Premium.',
      ),
      findsOneWidget,
    );
    await inviteHomeDone(tester);
  });

  testWidgets('the close icon logs dismissed, and once per run', (
    tester,
  ) async {
    final r = await pumpReady(tester);
    await waitSeconds(tester, 21);
    await tester.tap(find.byKey(const Key('invite-card-close')));
    await tester.pump();
    expect(card, findsNothing);
    expect(actions(r.events), [
      'after_connect/shown',
      'after_connect/dismissed',
    ]);

    // A new connection in the same run brings no second card.
    r.vpn.become(VpnStatus.disconnected);
    await tester.pump();
    r.vpn.become(VpnStatus.connected);
    await waitSeconds(tester, 40);
    expect(card, findsNothing);
    // Down again, which stops the tunnel service's heartbeat.
    r.vpn.become(VpnStatus.disconnected);
    await inviteHomeDone(tester);
  });

  testWidgets('a share ends it for good', (tester) async {
    final r = await pumpReady(tester);
    await waitSeconds(tester, 21);
    await tester.tap(find.byKey(const Key('invite-card-telegram')));
    await tester.pump();
    await tester.pump();
    expect(card, findsNothing);
    final share = calls.singleWhere((c) => c.method == 'shareInvite');
    final args = share.arguments as Map;
    expect(args['target'], 'telegram');
    expect(args['exclude'], InviteShare.builtInExclude);
    expect(args['text'], contains('https://fortivavpn.com/fa/i/AB3D7K?s=card'));
    expect(args['text'], contains('AB3D7K'));
    expect(actions(r.events), [
      'after_connect/shown',
      'after_connect/telegram',
    ]);
    await tester.pump();
    expect((await saved())['done'], isTrue);
    await inviteHomeDone(tester);
  });

  testWidgets('Copy link copies the whole message', (tester) async {
    final copied = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            copied.add((call.arguments as Map)['text'] as String);
          }
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );
    final r = await pumpReady(tester);
    await waitSeconds(tester, 21);
    await tester.tap(find.byKey(const Key('invite-card-copyLink')));
    await tester.pump();
    await tester.pump();
    expect(copied.single, contains('?s=card'));
    expect(card, findsNothing);
    expect(actions(r.events).last, 'after_connect/copy_link');
    await inviteHomeDone(tester);
  });

  testWidgets('a button loads the status first, and a failed load shares '
      'nothing', (tester) async {
    final referrals = CountingReferral();
    final r = await pumpReady(tester, referrals: referrals);
    await waitSeconds(tester, 21);
    await tester.tap(find.byKey(const Key('invite-card-otherApps')));
    await tester.pump();
    await tester.pump();
    expect(referrals.reads, 1);
    expect(card, findsOneWidget);
    expect(find.text('Could not load your invite code'), findsOneWidget);
    expect(calls.where((c) => c.method == 'shareInvite'), isEmpty);
    expect(actions(r.events), ['after_connect/shown']);
    await inviteHomeDone(tester);
  });

  testWidgets('gone when the tunnel drops, with no event', (tester) async {
    final r = await pumpReady(tester);
    await waitSeconds(tester, 21);
    expect(card, findsOneWidget);
    r.vpn.become(VpnStatus.disconnected);
    await tester.pump();
    expect(card, findsNothing);
    expect(actions(r.events), ['after_connect/shown']);
    await inviteHomeDone(tester);
  });

  testWidgets('gone when another screen opens', (tester) async {
    await pumpReady(tester);
    await waitSeconds(tester, 21);
    expect(card, findsOneWidget);
    final home = tester.element(find.byType(HomeScreen));
    unawaited(
      Navigator.of(
        home,
      ).push(MaterialPageRoute<void>(builder: (_) => const Scaffold())),
    );
    await settle(tester);
    Navigator.of(home).pop();
    await settle(tester);
    expect(card, findsNothing);
    await inviteHomeDone(tester);
  });

  testWidgets('never on a TV', (tester) async {
    FormFactor.isTvForTest = true;
    await pumpReady(tester);
    await waitSeconds(tester, 40);
    expect(card, findsNothing);
    await inviteHomeDone(tester);
  });

  testWidgets('never without the backend block or with invites off', (
    tester,
  ) async {
    await pumpReady(tester, rules: null);
    await waitSeconds(tester, 40);
    expect(card, findsNothing);
    await inviteHomeDone(tester);

    await pumpReady(tester, referralsOn: false);
    await waitSeconds(tester, 40);
    expect(card, findsNothing);
    await inviteHomeDone(tester);
  });

  testWidgets('never before the good days', (tester) async {
    SharedPreferences.setMockInitialValues({...inviteRecord(goodDays: 2)});
    await pumpReady(tester);
    await waitSeconds(tester, 40);
    expect(card, findsNothing);
    await inviteHomeDone(tester);
  });

  for (final (name, flags) in [
    ('InvitePrompt', (invite: false, device: true, billing: true)),
    ('DeviceState', (invite: true, device: false, billing: true)),
    ('BillingState', (invite: true, device: true, billing: false)),
  ]) {
    testWidgets('a home screen with no $name shows no card and throws '
        'nothing', (tester) async {
      await pumpReady(
        tester,
        withInvite: flags.invite,
        withDevice: flags.device,
        withBilling: flags.billing,
      );
      await waitSeconds(tester, 40);
      expect(card, findsNothing);
      expect(tester.takeException(), isNull);
      await inviteHomeDone(tester);
    });
  }

  group('next to the other popups', () {
    ReviewPrompt playReview({List<int>? asked}) => ReviewPrompt(
      installer: () async => ReviewPrompt.playInstaller,
      request: () async {
        asked?.add(1);
        return null;
      },
    );

    testWidgets('yields to the rating card when it is due, and never in '
        'its run', (tester) async {
      SharedPreferences.setMockInitialValues({
        ...inviteRecord(),
        ...reviewRecord(),
      });
      final asked = <int>[];
      final review = playReview(asked: asked);
      await pumpReady(tester, review: review, reviewOn: true);
      await waitSeconds(tester, 60);
      expect(asked, [1]);
      expect(review.askedThisRun, isTrue);
      expect(card, findsNothing);
      await inviteHomeDone(tester);
    });

    testWidgets('never on the Tehran day the rating card was asked', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        ...inviteRecord(),
        ...reviewRecord(askedAt: DateTime.now()),
      });
      final review = playReview();
      await pumpReady(tester, review: review, reviewOn: true);
      await waitSeconds(tester, 60);
      expect(review.askedThisRun, isFalse);
      expect(card, findsNothing);
      await inviteHomeDone(tester);
    });

    testWidgets('the rating card never on the day the invite card showed', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        ...inviteRecord(lastShownDay: ReviewPrompt.tehranDay(DateTime.now())),
        ...reviewRecord(),
      });
      final asked = <int>[];
      final review = playReview(asked: asked);
      // The block is missing, so the invite card cannot show either.
      await pumpReady(tester, review: review, reviewOn: true, rules: null);
      await waitSeconds(tester, 60);
      expect(asked, isEmpty);
      expect(card, findsNothing);
      await inviteHomeDone(tester);
    });

    testWidgets('the rating card never in a run the invite card showed in', (
      tester,
    ) async {
      // Two rating days: the rating card is not due on this connection.
      SharedPreferences.setMockInitialValues({
        ...inviteRecord(),
        ReviewPrompt.stateKey: jsonEncode({
          'days': ['2026-01-01', '2026-01-02'],
          'asks': 0,
        }),
      });
      final asked = <int>[];
      final review = playReview(asked: asked);
      final r = await pumpReady(tester, review: review, reviewOn: true);
      await waitSeconds(tester, 21);
      expect(card, findsOneWidget);
      await tester.tap(find.byKey(const Key('invite-card-close')));
      await tester.pump();

      // A third day, and a new connection: due now, but not in this run.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        ReviewPrompt.stateKey,
        jsonEncode({
          'days': ['2026-01-01', '2026-01-02', '2026-01-03'],
          'asks': 0,
        }),
      );
      r.vpn.become(VpnStatus.disconnected);
      await tester.pump();
      r.vpn.become(VpnStatus.connected);
      await waitSeconds(tester, 60);
      expect(asked, isEmpty);
      r.vpn.become(VpnStatus.disconnected);
      await inviteHomeDone(tester);
    });

    testWidgets('never in a run the Premium card showed in', (tester) async {
      final billing = FixedBilling(
        BillingInfo(
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
        ),
      );
      final premium = PremiumPrompt(billing: billing);
      await pumpReady(tester, billing: billing, premium: premium);
      await waitSeconds(tester, 60);
      expect(premium.shownThisRun, isTrue);
      expect(find.text('Want no daily limit?'), findsOneWidget);
      expect(card, findsNothing);
      await inviteHomeDone(tester);
    });

    testWidgets('never in a run a message popped up in', (tester) async {
      final sent = DateTime.now().toUtc().subtract(const Duration(minutes: 1));
      final messages = MessageState(
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
      await messages.refresh();
      await pumpReady(tester, messages: messages);
      await waitSeconds(tester, 6);
      expect(find.text('Body'), findsOneWidget);
      await tester.tap(find.byType(TextButton).last);
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await waitSeconds(tester, 60);
      expect(card, findsNothing);
      await inviteHomeDone(tester);
    });

    testWidgets('never in a run the update dialog showed in', (tester) async {
      await pumpReady(tester);
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
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await waitSeconds(tester, 60);
      expect(card, findsNothing);
      await inviteHomeDone(tester);
    });

    testWidgets('never in a run the notification question was asked in', (
      tester,
    ) async {
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
      await waitSeconds(tester, 60);
      expect(asks, 1);
      expect(card, findsNothing);
      await inviteHomeDone(tester);
    });

    testWidgets('never while the renewal reminder is due', (tester) async {
      final now = DateTime.now();
      final billing = FixedBilling(
        BillingInfo(
          enabled: true,
          premium: Premium(
            active: true,
            until: now.add(const Duration(hours: 10)),
            source: 'voucher',
          ),
          rails: const Rails(codes: true),
          renewal: Renewal(
            until: now.add(const Duration(hours: 10)),
            noticeHours: 72,
          ),
        ),
      );
      await pumpReady(tester, billing: billing);
      await waitSeconds(tester, 60);
      expect(find.textContaining('Premium ends on'), findsOneWidget);
      expect(card, findsNothing);
      await inviteHomeDone(tester);
    });

    testWidgets('the limit sheet still opens when it is due, and the card '
        'is gone', (tester) async {
      final dedicated = FakeDedicated();
      await pumpReady(tester, dedicated: dedicated);
      await waitSeconds(tester, 21);
      expect(card, findsOneWidget);
      dedicated.become(inviteQuota(blocked: true));
      await waitSeconds(tester, 7);
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(card, findsNothing);
      await inviteHomeDone(tester);
    });

    testWidgets('never in a run the limit sheet opened in', (tester) async {
      final dedicated = FakeDedicated(inviteQuota(blocked: true));
      await pumpReady(tester, dedicated: dedicated);
      await waitSeconds(tester, 7);
      expect(find.byType(BottomSheet), findsOneWidget);
      final home = tester.element(find.byType(HomeScreen));
      Navigator.of(home).pop();
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      dedicated.become(inviteQuota());
      await waitSeconds(tester, 60);
      expect(card, findsNothing);
      await inviteHomeDone(tester);
    });
  });
}

PlatformVersion _update() => PlatformVersion(
  latestVersion: '9.9.9',
  minimumVersion: '1.0.0',
  updateRequired: false,
  updateUrl: 'https://play.google.com/store/apps/details?id=com.vpn.fortivavpn',
  releaseNotes: null,
);
