import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/api/referral_service.dart';
import 'package:fortiva_vpn/core/form_factor.dart';
import 'package:fortiva_vpn/core/state/billing_state.dart';
import 'package:fortiva_vpn/core/state/invite_prompt.dart';
import 'package:fortiva_vpn/core/state/invite_tree_intro.dart';
import 'package:fortiva_vpn/core/state/locale_state.dart';
import 'package:fortiva_vpn/core/state/message_state.dart';
import 'package:fortiva_vpn/core/state/notice_permission_prompt.dart';
import 'package:fortiva_vpn/core/state/referral_state.dart';
import 'package:fortiva_vpn/core/state/review_prompt.dart';
import 'package:fortiva_vpn/data/models/app_config.dart';
import 'package:fortiva_vpn/data/models/billing.dart';
import 'package:fortiva_vpn/data/models/in_app_message.dart';
import 'package:fortiva_vpn/data/models/version_info.dart';
import 'package:fortiva_vpn/l10n/generated/app_localizations.dart';
import 'package:fortiva_vpn/screens/invite_tree_intro_screen.dart';
import 'package:fortiva_vpn/screens/language_setup_screen.dart';
import 'package:fortiva_vpn/services/invite_share.dart';
import 'package:fortiva_vpn/services/notice_channel.dart';
import 'package:fortiva_vpn/services/vpn_service.dart';
import 'package:fortiva_vpn/widgets/message_dialog.dart';
import 'package:fortiva_vpn/widgets/update_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/app_theme.dart';
import 'helpers/invite_home.dart';
import 'helpers/invite_tree.dart';
import 'helpers/limit_sheet.dart';

/// The introduction to the invite tree opens by itself once per install,
/// on the home screen, at the first calm moment of a run that knows the
/// tree rule is on: from the app config, or from a referral answer already
/// loaded. It loads the referral answer at most once per run, and only
/// under the tree rule. It never opens under today's rule, on a TV, in the
/// run that asked for the language, with Premium, over anything else or
/// after another popup, and once open it is the run's one popup.
void main() {
  final intro = find.byType(InviteTreeIntroScreen);
  late List<MethodCall> calls;
  late NoticePermissionPrompt originalNotice;
  late int noticeAsks;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    calls = [];
    mockTunnel(calls);
    UpdateDialog.resetForTest();
    MessageDialog.resetForTest();
    InviteShare.nativeForTest = true;
    noticeAsks = 0;
    originalNotice = NoticePermissionPrompt.instance;
    // Allowed already, unless a test says otherwise: the question then
    // never shows.
    NoticePermissionPrompt.instance = NoticePermissionPrompt(
      permission: () async => NoticePermission.granted,
      isTv: () => false,
    );
  });

  tearDown(() {
    FormFactor.isTvForTest = false;
    LanguageSetupScreen.shownThisRunForTest = false;
    InviteShare.nativeForTest = null;
    NoticePermissionPrompt.instance = originalNotice;
    unmockTunnel();
  });

  /// The home screen with the record, the config naming [rules], and the
  /// referral backend, the tunnel up for an hour unless [vpn] says other.
  Future<({FakeVpn vpn, InviteTreeIntroRecord record})> pumpHome(
    WidgetTester tester, {
    required ReferralState referrals,
    String? rules = 'tree',
    bool referralsOn = true,
    bool limitSheet = true,
    bool reviewOn = false,
    FakeVpn? vpn,
    BillingState? billing,
    FakeDedicated? dedicated,
    MessageState? messages,
    InvitePrompt? invite,
    ReviewPrompt? review,
    bool withDevice = false,
  }) async {
    final fake = vpn ?? FakeVpn(VpnStatus.connected);
    final record = InviteTreeIntroRecord();
    await pumpInviteHome(
      tester,
      vpn: fake,
      treeIntro: record,
      config: await inviteConfig(
        referrals: referralsOn,
        referralRules: rules,
        limitSheet: limitSheet,
        reviewPrompt: reviewOn,
      ),
      referrals: referrals,
      billing: billing ?? FixedBilling(),
      dedicated: dedicated,
      messages: messages,
      invite: invite,
      events: invite == null ? null : keptEvents(),
      review: review,
      device: withDevice
          ? await registeredDevice(
              inviteDevice(
                claimOpenUntil: DateTime.now().add(const Duration(hours: 5)),
              ),
            )
          : null,
    );
    return (vpn: fake, record: record);
  }

  /// Close the story, as Skip does, and let it slide away.
  Future<void> closeStory(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('invite-tree-intro-skip')));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('opens once, at the first calm moment, when the config says '
      'tree', (tester) async {
    final backend = ReferralBackend(answer: treeAnswer());
    final home = await pumpHome(tester, referrals: backend.state);
    await waitSeconds(tester, 4);
    expect(intro, findsNothing);
    expect(backend.reads, 0, reason: 'nothing is asked before the wait ends');
    await waitSeconds(tester, 3);
    expect(intro, findsOneWidget);
    expect(backend.reads, 1);
    expect(await home.record.seen(), isTrue);
    expect(home.record.shownThisRun, isTrue);
    await closeStory(tester);
    await inviteHomeDone(tester);

    // The next run of the same install: seen, so nothing opens, and the
    // referral answer is not asked for.
    final again = ReferralBackend(answer: treeAnswer());
    await pumpHome(tester, referrals: again.state);
    await waitSeconds(tester, 15);
    expect(intro, findsNothing);
    expect(again.reads, 0);
    await inviteHomeDone(tester);
  });

  testWidgets('never under today\'s rule, with no rule named, or with '
      'invites off, and no referral answer is asked for', (tester) async {
    for (final (rules, on) in [('flat', true), (null, true), ('tree', false)]) {
      final backend = ReferralBackend(answer: treeAnswer());
      final home = await pumpHome(
        tester,
        referrals: backend.state,
        rules: rules,
        referralsOn: on,
      );
      await waitSeconds(tester, 15);
      expect(intro, findsNothing, reason: '$rules $on');
      expect(backend.reads, 0, reason: '$rules $on');
      expect(await home.record.seen(), isFalse, reason: '$rules $on');
      await inviteHomeDone(tester);
    }
  });

  testWidgets('a tree answer already loaded in this run counts, with no '
      'rule in the config', (tester) async {
    final referrals = heldStatus(ReferralStatus.fromJson(treeAnswer()));
    await pumpHome(tester, referrals: referrals, rules: null);
    await waitSeconds(tester, 7);
    expect(intro, findsOneWidget);
    await closeStory(tester);
    await inviteHomeDone(tester);
  });

  testWidgets('never on a TV', (tester) async {
    FormFactor.isTvForTest = true;
    final backend = ReferralBackend(answer: treeAnswer());
    await pumpHome(tester, referrals: backend.state);
    await waitSeconds(tester, 15);
    expect(intro, findsNothing);
    expect(backend.reads, 0);
    await inviteHomeDone(tester);
  });

  testWidgets('never in the run that showed the language screen', (
    tester,
  ) async {
    LanguageSetupScreen.shownThisRunForTest = true;
    final backend = ReferralBackend(answer: treeAnswer());
    final home = await pumpHome(tester, referrals: backend.state);
    await waitSeconds(tester, 15);
    expect(intro, findsNothing);
    expect(backend.reads, 0);
    expect(await home.record.seen(), isFalse);
    await inviteHomeDone(tester);
  });

  testWidgets('never while the phone has Premium', (tester) async {
    final backend = ReferralBackend(answer: treeAnswer());
    await pumpHome(
      tester,
      referrals: backend.state,
      billing: FixedBilling(
        BillingInfo(
          enabled: true,
          premium: Premium(
            active: true,
            until: DateTime.now().add(const Duration(days: 10)),
            source: 'voucher',
          ),
          rails: const Rails(codes: true),
        ),
      ),
    );
    await waitSeconds(tester, 15);
    expect(intro, findsNothing);
    expect(backend.reads, 0);
    await inviteHomeDone(tester);
  });

  testWidgets('never over another page; it opens once that page is closed', (
    tester,
  ) async {
    final backend = ReferralBackend(answer: treeAnswer());
    await pumpHome(tester, referrals: backend.state);
    await waitSeconds(tester, 2);
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('another page')),
      ),
    );
    await waitSeconds(tester, 15);
    expect(find.text('another page'), findsOneWidget);
    expect(intro, findsNothing);
    navigator.pop();
    await waitSeconds(tester, 8);
    expect(intro, findsOneWidget);
    await closeStory(tester);
    await inviteHomeDone(tester);
  });

  testWidgets('never while the data is used up', (tester) async {
    final backend = ReferralBackend(answer: treeAnswer());
    await pumpHome(
      tester,
      referrals: backend.state,
      limitSheet: false,
      dedicated: FakeDedicated(inviteQuota(blocked: true)),
    );
    await waitSeconds(tester, 15);
    expect(intro, findsNothing);
    expect(backend.reads, 0);
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
    final backend = ReferralBackend(answer: treeAnswer());
    await pumpHome(tester, referrals: backend.state, messages: messages);
    await waitSeconds(tester, 6);
    expect(find.text('Body'), findsOneWidget);
    expect(intro, findsNothing);
    await tester.tap(find.byType(TextButton).last);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await waitSeconds(tester, 30);
    expect(intro, findsNothing);
    expect(backend.reads, 0);
    await inviteHomeDone(tester);
  });

  testWidgets('waits while a connect runs, and opens once it ends and the '
      'screen has settled', (tester) async {
    final backend = ReferralBackend(answer: treeAnswer());
    final home = await pumpHome(
      tester,
      referrals: backend.state,
      vpn: FakeVpn(VpnStatus.connecting),
    );
    await waitSeconds(tester, 15);
    expect(intro, findsNothing);
    expect(backend.reads, 0);
    home.vpn.become(VpnStatus.connected);
    await waitSeconds(tester, 3);
    expect(intro, findsNothing);
    await waitSeconds(tester, 4);
    expect(intro, findsOneWidget);
    await closeStory(tester);
    // Stops the tunnel service's own timers, which a connect started.
    home.vpn.become(VpnStatus.disconnected);
    await inviteHomeDone(tester);
  });

  testWidgets('once it has opened, the rating card, the invite card and the '
      'notification question wait for the next run', (tester) async {
    SharedPreferences.setMockInitialValues({
      ...inviteRecord(),
      ...reviewRecord(),
    });
    NoticePermissionPrompt.instance = NoticePermissionPrompt(
      permission: () async => NoticePermission.ask,
      ask: () async {
        noticeAsks++;
        return NoticePermission.granted;
      },
      rationale: () async => false,
      openSettings: () async => true,
      isTv: () => false,
    );
    final asked = <int>[];
    final review = ReviewPrompt(
      installer: () async => ReviewPrompt.playInstaller,
      request: () async {
        asked.add(1);
        return null;
      },
    );
    final invite = InvitePrompt();
    final backend = ReferralBackend(answer: treeAnswer());
    await pumpHome(
      tester,
      referrals: backend.state,
      invite: invite,
      review: review,
      reviewOn: true,
      withDevice: true,
    );
    await waitSeconds(tester, 7);
    expect(intro, findsOneWidget);
    await closeStory(tester);
    await waitSeconds(tester, 60);
    expect(asked, isEmpty, reason: 'the rating card');
    expect(invite.shownThisRun, isFalse, reason: 'the invite card');
    expect(find.byKey(const Key('invite-card')), findsNothing);
    expect(noticeAsks, 0, reason: 'the notification question');
    await inviteHomeDone(tester);
  });

  testWidgets('a load that fails opens nothing, keeps the record unset, and '
      'is not tried again in the run', (tester) async {
    final backend = ReferralBackend();
    final home = await pumpHome(tester, referrals: backend.state);
    await waitSeconds(tester, 7);
    expect(intro, findsNothing);
    expect(backend.reads, 1);
    expect(await home.record.seen(), isFalse);
    await waitSeconds(tester, 40);
    expect(backend.reads, 1);
    expect(intro, findsNothing);
    await inviteHomeDone(tester);
  });

  testWidgets('an answer that says today\'s rule opens nothing and keeps the '
      'record unset', (tester) async {
    final backend = ReferralBackend(answer: oldAnswer());
    final home = await pumpHome(tester, referrals: backend.state);
    await waitSeconds(tester, 15);
    expect(intro, findsNothing);
    expect(backend.reads, 1);
    expect(await home.record.seen(), isFalse);
    await inviteHomeDone(tester);
  });

  /// A message state with one message, fetched when [MessageState.refresh]
  /// is called, once [gate] is complete when there is one.
  MessageState oneMessage({Completer<void>? gate}) {
    final sent = DateTime.now().toUtc().subtract(const Duration(minutes: 1));
    return MessageState(
      fetch: (_, _) async {
        await gate?.future;
        return MessagesPage.fromJson({
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
        });
      },
      post: (_, _) async {},
      deviceId: () async => 'DEV-1',
      register: () async {},
      language: () => 'en',
      flushDelay: const Duration(days: 1),
    );
  }

  /// The notification question, still to be asked, counted in [noticeAsks].
  void noticeToAsk() {
    NoticePermissionPrompt.instance = NoticePermissionPrompt(
      permission: () async => NoticePermission.ask,
      ask: () async {
        noticeAsks++;
        return NoticePermission.granted;
      },
      rationale: () async => false,
      openSettings: () async => true,
      isTv: () => false,
    );
  }

  group('the notification question', () {
    testWidgets('is asked with the tunnel down, under the tree as under '
        'today\'s rule', (tester) async {
      for (final rules in ['flat', 'tree']) {
        // A fresh install each time: the question counts its asks.
        SharedPreferences.setMockInitialValues({});
        noticeAsks = 0;
        noticeToAsk();
        final backend = ReferralBackend(answer: treeAnswer());
        await pumpHome(
          tester,
          referrals: backend.state,
          rules: rules,
          vpn: FakeVpn(VpnStatus.disconnected),
        );
        await waitSeconds(tester, 30);
        expect(noticeAsks, 1, reason: rules);
        // The story opens only with the tunnel up, so not here.
        expect(intro, findsNothing, reason: rules);
        expect(backend.reads, 0, reason: rules);
        await inviteHomeDone(tester);
      }
    });

    testWidgets('follows a message popup, under the tree as under today\'s '
        'rule', (tester) async {
      for (final rules in ['flat', 'tree']) {
        // A fresh install each time: the question counts its asks, and the
        // message is noted as shown.
        SharedPreferences.setMockInitialValues({});
        noticeAsks = 0;
        noticeToAsk();
        final messages = oneMessage();
        await messages.refresh();
        final backend = ReferralBackend(answer: treeAnswer());
        await pumpHome(
          tester,
          referrals: backend.state,
          rules: rules,
          messages: messages,
        );
        await waitSeconds(tester, 6);
        expect(find.text('Body'), findsOneWidget, reason: rules);
        await tester.tap(find.byType(TextButton).last);
        for (var i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        await waitSeconds(tester, 30);
        expect(noticeAsks, 1, reason: rules);
        // The message was this run's popup.
        expect(intro, findsNothing, reason: rules);
        await inviteHomeDone(tester);
      }
    });
  });

  testWidgets('a message that lands while the story is open waits in the '
      'inbox', (tester) async {
    final gate = Completer<void>();
    final messages = oneMessage(gate: gate);
    unawaited(messages.refresh());
    final backend = ReferralBackend(answer: treeAnswer());
    await pumpHome(tester, referrals: backend.state, messages: messages);
    await waitSeconds(tester, 7);
    expect(intro, findsOneWidget);
    // The fetch lands now, on a slow network, with the story on top.
    gate.complete();
    await tester.pump();
    await tester.pump();
    expect(messages.pendingPopup, isNotNull);
    await waitSeconds(tester, 10);
    await closeStory(tester);
    await waitSeconds(tester, 30);
    expect(find.text('Body'), findsNothing);
    await inviteHomeDone(tester);
  });

  testWidgets('the language screen notes that this run showed it', (
    tester,
  ) async {
    expect(LanguageSetupScreen.shownThisRun, isFalse);
    await tester.pumpWidget(
      MaterialApp(
        theme: appThemeFor(const Locale('en')),
        localizationsDelegates: S.localizationsDelegates,
        supportedLocales: S.supportedLocales,
        locale: const Locale('en'),
        home: LanguageSetupScreen(
          localeState: LocaleState(),
          suggested: 'en',
          onDone: () {},
        ),
      ),
    );
    await tester.pump();
    expect(LanguageSetupScreen.shownThisRun, isTrue);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('never in a run the limit sheet showed in, even once the data '
      'is back', (tester) async {
    final dedicated = FakeDedicated(inviteQuota(blocked: true));
    final backend = ReferralBackend(answer: treeAnswer());
    await pumpHome(tester, referrals: backend.state, dedicated: dedicated);
    await waitSeconds(tester, 7);
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(intro, findsNothing);
    // The sheet closes, and the data comes back.
    await tester.tapAt(const Offset(10, 10));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    dedicated.become(inviteQuota());
    await waitSeconds(tester, 30);
    expect(intro, findsNothing);
    await inviteHomeDone(tester);
  });

  testWidgets('never in a run the update dialog showed in', (tester) async {
    final backend = ReferralBackend(answer: treeAnswer());
    await pumpHome(tester, referrals: backend.state);
    final home = tester.element(find.byType(Scaffold).first);
    unawaited(
      UpdateDialog.maybeShow(
        home,
        ForceUpdate(
          ios: PlatformVersion(
            latestVersion: '9.9.9',
            minimumVersion: '1.0.0',
            updateRequired: false,
            updateUrl: 'https://example.com/app',
            releaseNotes: null,
          ),
          android: PlatformVersion(
            latestVersion: '9.9.9',
            minimumVersion: '1.0.0',
            updateRequired: false,
            updateUrl: 'https://example.com/app',
            releaseNotes: null,
          ),
        ),
        currentVersion: '1.4.1',
        android: true,
        open: (_) async {},
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(UpdateDialog.isShowing, isTrue);
    await waitSeconds(tester, 10);
    expect(intro, findsNothing);
    Navigator.of(home, rootNavigator: true).pop();
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await waitSeconds(tester, 30);
    expect(intro, findsNothing);
    await inviteHomeDone(tester);
  });

  testWidgets('a connect that starts while the referral answer loads holds '
      'the story until the screen has settled again', (tester) async {
    final backend = ReferralBackend(answer: treeAnswer())
      ..gate = Completer<void>();
    final home = await pumpHome(tester, referrals: backend.state);
    await waitSeconds(tester, 6);
    expect(backend.reads, 1, reason: 'the load is under way');
    home.vpn.become(VpnStatus.connecting);
    await tester.pump();
    backend.gate!.complete();
    await waitSeconds(tester, 10);
    expect(intro, findsNothing);
    home.vpn.become(VpnStatus.connected);
    await waitSeconds(tester, 3);
    expect(intro, findsNothing);
    await waitSeconds(tester, 4);
    expect(intro, findsOneWidget);
    await closeStory(tester);
    home.vpn.become(VpnStatus.disconnected);
    await inviteHomeDone(tester);
  });

  test('the config names the rule, and only a rule the app knows', () async {
    for (final (value, tree) in <(Object?, bool)>[
      ('tree', true),
      ('flat', false),
      ('other', false),
      (1, false),
      (null, false),
    ]) {
      final config = await inviteConfig(
        referralRules: value is String ? value : null,
      );
      expect(config.inviteTreeOn, tree, reason: '$value');
    }
    final off = await inviteConfig(referrals: false, referralRules: 'tree');
    expect(off.inviteTreeOn, isFalse);
    expect(jsonEncode(off.flags.toJson()), contains('"referral_rules":"tree"'));
  });
}
