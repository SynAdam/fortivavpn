import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/api/api_client.dart';
import 'package:fortiva_vpn/api/referral_service.dart';
import 'package:fortiva_vpn/core/state/app_config_state.dart';
import 'package:fortiva_vpn/core/state/billing_state.dart';
import 'package:fortiva_vpn/core/state/dedicated_state.dart';
import 'package:fortiva_vpn/core/state/invite_events.dart';
import 'package:fortiva_vpn/core/state/invite_prompt.dart';
import 'package:fortiva_vpn/core/state/invite_tree_intro.dart';
import 'package:fortiva_vpn/core/state/referral_state.dart';
import 'package:fortiva_vpn/data/models/billing.dart';
import 'package:fortiva_vpn/l10n/generated/app_localizations.dart';
import 'package:fortiva_vpn/screens/invite_tree_intro_screen.dart';
import 'package:fortiva_vpn/screens/invite_tree_questions_screen.dart';
import 'package:fortiva_vpn/widgets/invite_slots.dart';
import 'package:fortiva_vpn/widgets/limit_sheet.dart';
import 'package:fortiva_vpn/core/state/notice_permission_prompt.dart';
import 'package:fortiva_vpn/services/notice_channel.dart';
import 'package:fortiva_vpn/services/vpn_service.dart';
import 'package:fortiva_vpn/widgets/message_dialog.dart';
import 'package:fortiva_vpn/widgets/update_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';

import 'app_theme.dart';
import 'invite_home.dart';
import 'invite_tree.dart';

/// What the tests of the limit sheet and the invite tree introduction
/// share. The numbers here are the tests' own, never the backend's start
/// values.

/// Sales on, with Premium offered on the limit sheet.
const sheetOffers = BillingInfo(
  enabled: true,
  plans: [
    Plan(
      code: 'unlimited',
      google: PlayProductRef(productId: 'premium', basePlanId: 'base'),
    ),
  ],
  rails: Rails(googlePlay: true, codes: true),
  upsell: Upsell(surfaces: {UpsellSurface.limitSheet}),
);

/// A fake backend for the referral status. [answer] is what the status
/// read returns, or null for a refusal. While [gate] is set the read waits
/// for it. [reads] counts the reads.
class ReferralBackend {
  ReferralBackend({this.answer});

  Map<String, dynamic>? answer;
  Completer<void>? gate;
  int reads = 0;

  late final ReferralState state = ReferralState(
    service: ReferralService.forTest(
      client: ApiClient.forTest(
        direct: MockClient((request) async {
          reads++;
          final hold = gate;
          if (hold != null) await hold.future;
          final body = answer;
          const json = {'content-type': 'application/json'};
          if (body == null) {
            return http.Response('{"detail": "refused"}', 400, headers: json);
          }
          return http.Response(jsonEncode(body), 200, headers: json);
        }),
      ),
    ),
    deviceId: () async => 'DEV-1',
    register: () async {},
    pendingReferrer: () async => null,
    settleReferrer: () async {},
  );
}

/// A referral state that already holds [status] and loads nothing more.
ReferralState heldStatus(ReferralStatus? status) {
  final backend = ReferralBackend();
  if (status != null) backend.state.adoptForTest(status);
  return backend.state;
}

/// Set the screen to [size] at [textScale], and, with [reduced], the
/// phone's setting for less motion. Undone when the test ends.
void screenFor(
  WidgetTester tester, {
  Size size = const Size(360, 780),
  double textScale = 1,
  bool reduced = false,
}) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  if (reduced) {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
  }
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
}

/// A screen with one button that opens the limit sheet, with whichever
/// providers are given. Premium is offered with [premium].
Future<void> pumpSheetHost(
  WidgetTester tester, {
  ReferralState? referrals,
  bool premium = true,
  bool invitesOn = true,
  InviteEvents? events,
  InvitePrompt? prompt,
  InviteTreeIntroRecord? record,
  String locale = 'en',
  DedicatedState? dedicated,
}) async {
  // A phone, unless the test chose a screen.
  if (tester.view.devicePixelRatio == 3 &&
      tester.view.physicalSize == const Size(2400, 1800)) {
    screenFor(tester);
  }
  final config = await inviteConfig(referrals: invitesOn);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<DedicatedState>.value(
          value: dedicated ?? FakeDedicated(inviteQuota(blocked: true)),
        ),
        ChangeNotifierProvider<AppConfigState>.value(value: config),
        ChangeNotifierProvider<BillingState>.value(
          value: FixedBilling(
            premium ? sheetOffers : const BillingInfo(enabled: false),
          ),
        ),
        if (referrals != null)
          ChangeNotifierProvider<ReferralState>.value(value: referrals),
        if (events != null) Provider<InviteEvents>.value(value: events),
        if (prompt != null)
          ChangeNotifierProvider<InvitePrompt>.value(value: prompt),
        if (record != null)
          Provider<InviteTreeIntroRecord>.value(value: record),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: appThemeFor(Locale(locale)),
        localizationsDelegates: S.localizationsDelegates,
        supportedLocales: S.supportedLocales,
        locale: Locale(locale),
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: TextButton(
                key: const Key('open-sheet'),
                onPressed: () => unawaited(showLimitSheet(context)),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

/// Open the sheet on the host and let it settle.
Future<void> openSheet(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('open-sheet')));
  await tester.pumpAndSettle();
}

/// The introduction to the invite tree, on its own, over [referrals].
Future<void> pumpIntro(
  WidgetTester tester,
  ReferralState referrals, {
  String locale = 'en',
  InviteEvents? events,
  InvitePrompt? prompt,
}) async {
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<ReferralState>.value(value: referrals),
        if (events != null) Provider<InviteEvents>.value(value: events),
        if (prompt != null)
          ChangeNotifierProvider<InvitePrompt>.value(value: prompt),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: appThemeFor(Locale(locale)),
        localizationsDelegates: S.localizationsDelegates,
        supportedLocales: S.supportedLocales,
        locale: Locale(locale),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                key: const Key('open-intro'),
                onPressed: () => unawaited(InviteTreeIntroScreen.open(context)),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.byKey(const Key('open-intro')));
  await tester.pumpAndSettle();
}

/// Every piece of text on screen, in the order it is laid out.
List<String> allTexts(WidgetTester tester) => [
  for (final t in tester.widgetList<Text>(find.byType(Text)))
    ?(t.data ?? t.textSpan?.toPlainText()),
];

/// The sizes the layout tests check: a small phone and a common one, at
/// the default text size and at large text.
const layoutScreens = [
  (Size(320, 568), 1.0),
  (Size(320, 568), 1.3),
  (Size(360, 780), 1.0),
  (Size(360, 780), 1.3),
];

const _rtl = {'fa', 'ar', 'ur'};

/// The tree fixture for a user who joined with a code and gets Premium
/// days: every step of the introduction and every question.
ReferralStatus everyStepStatus() => ReferralStatus.fromJson(
  treeAnswer()
    ..['claimed_code'] = 'QW8RT2'
    ..['earns'] = true
    ..['reward_premium_days'] = 3
    ..['premium_days_max'] = 30,
);

/// The introduction for [locales]: no step overflows, and in a right to
/// left language the user is on the right, the progress fills from the
/// right, Next is on the left, the friend in step 2 starts on the right,
/// and the slots of step 3 are on the right of their amounts.
void introLayoutTests(List<String> locales) {
  for (final (size, scale) in layoutScreens) {
    for (final locale in locales) {
      testWidgets('[$locale ${size.width.toInt()}x${size.height.toInt()} at '
          '$scale] every step of the introduction fits', (tester) async {
        screenFor(tester, size: size, textScale: scale);
        await pumpIntro(tester, heldStatus(everyStepStatus()), locale: locale);
        final rtl = _rtl.contains(locale);
        bool before(Offset a, Offset b) => rtl ? a.dx > b.dx : a.dx < b.dx;
        Offset centre(String key) => tester.getCenter(find.byKey(Key(key)));
        for (var page = 0; page < 8; page++) {
          if (page > 0) {
            await tester.tap(find.byKey(const Key('invite-tree-intro-next')));
            await tester.pumpAndSettle();
          }
          expect(tester.takeException(), isNull, reason: 'step ${page + 1}');
          for (final key in [
            'invite-tree-intro-progress-0',
            'invite-tree-intro-art-$page',
          ]) {
            final rect = tester.getRect(find.byKey(Key(key)));
            expect(rect.left, greaterThanOrEqualTo(0), reason: key);
            expect(rect.right, lessThanOrEqualTo(size.width), reason: key);
          }
          switch (page) {
            case 0:
              expect(
                before(
                  centre('invite-tree-intro-progress-0'),
                  centre('invite-tree-intro-progress-7'),
                ),
                isTrue,
              );
              expect(
                before(
                  centre('invite-tree-intro-you'),
                  centre('invite-tree-intro-pair-0'),
                ),
                isTrue,
              );
            case 1:
              expect(
                before(
                  centre('invite-tree-intro-back'),
                  centre('invite-tree-intro-next'),
                ),
                isTrue,
              );
              // The drawing keeps its words at every size: inside it, or
              // under the card.
              for (final key in ['code', 'use', 'slot']) {
                expect(
                  find.byKey(Key('invite-tree-intro-caption-$key')),
                  findsOneWidget,
                  reason: 'caption $key',
                );
              }
              // In reading order: before it on the same line, or on a
              // line above it.
              final code = tester.getRect(
                find.byKey(const Key('invite-tree-intro-caption-code')),
              );
              final slot = tester.getRect(
                find.byKey(const Key('invite-tree-intro-caption-slot')),
              );
              expect(
                code.bottom <= slot.top || before(code.center, slot.center),
                isTrue,
              );
              expect(
                before(
                  centre('invite-tree-intro-join-code'),
                  centre('invite-tree-intro-join-pair'),
                ),
                isTrue,
              );
            case 2:
              final capsule = tester.getCenter(
                find
                    .descendant(
                      of: find.byKey(const Key('invite-tree-intro-row-0')),
                      matching: find.byType(PairCapsule),
                    )
                    .first,
              );
              expect(
                before(capsule, centre('invite-tree-intro-both-0')),
                isTrue,
              );
              expect(
                before(
                  centre('invite-tree-intro-both-0'),
                  centre('invite-tree-intro-one-0'),
                ),
                isTrue,
              );
            case 4:
              expect(
                before(
                  centre('invite-tree-intro-you-full'),
                  centre('invite-tree-intro-friend'),
                ),
                isTrue,
              );
              // All six own slots taken, and the friend's pair further on.
              for (var i = 0; i < 3; i++) {
                expect(
                  find.byKey(Key('invite-tree-intro-full-pair-$i')),
                  findsOneWidget,
                );
              }
              expect(
                before(
                  centre('invite-tree-intro-friend'),
                  centre('invite-tree-intro-their-pair'),
                ),
                isTrue,
              );
              expect(
                find.byKey(const Key('invite-tree-intro-caption-pair')),
                findsOneWidget,
              );
            case 5:
              expect(
                before(
                  centre('invite-tree-intro-you-others'),
                  centre('invite-tree-intro-first-pair'),
                ),
                isTrue,
              );
              // The people the user did not invite come from the person who
              // invited the user, on the start side, not from further away.
              expect(
                before(
                  centre('invite-tree-intro-inviter'),
                  centre('invite-tree-intro-you-others'),
                ),
                isTrue,
              );
              for (final key in ['inviter', 'others']) {
                expect(
                  find.byKey(Key('invite-tree-intro-caption-$key')),
                  findsOneWidget,
                  reason: 'caption $key',
                );
              }
            case 7:
              final share = tester.getRect(
                find.byKey(const Key('invite-tree-intro-share')),
              );
              expect(share.bottom, lessThanOrEqualTo(size.height));
              // The questions are in the bar, so they never scroll away.
              final questions = tester.getRect(
                find.byKey(const Key('invite-tree-intro-questions')),
              );
              expect(questions.bottom, lessThanOrEqualTo(size.height));
              expect(questions.top, greaterThan(share.bottom));
          }
        }
      });
    }
  }
}

/// Every question of the invite tree, in the order the page lists them
/// for [everyStepStatus].
const everyQuestion = [
  'changed',
  'kept',
  'count',
  'down',
  'full',
  'start',
  'cost',
  'friends',
  'others',
  'sum',
  'slot',
  'phone',
  'privacy',
  'limit',
  'premium',
  'gets',
];

/// The questions page for [locales], with every answer open: nothing
/// overflows, and in a right to left language each question starts on the
/// right with its chevron on the left.
void questionsLayoutTests(List<String> locales) {
  for (final (size, scale) in layoutScreens) {
    for (final locale in locales) {
      testWidgets('[$locale ${size.width.toInt()}x${size.height.toInt()} at '
          '$scale] every answer of the questions page fits', (tester) async {
        screenFor(tester, size: size, textScale: scale);
        await tester.pumpWidget(
          ChangeNotifierProvider<ReferralState>.value(
            value: heldStatus(everyStepStatus()),
            child: MaterialApp(
              theme: appThemeFor(Locale(locale)),
              localizationsDelegates: S.localizationsDelegates,
              supportedLocales: S.supportedLocales,
              locale: Locale(locale),
              home: const InviteTreeQuestionsScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final rtl = _rtl.contains(locale);
        for (final id in everyQuestion) {
          final row = find.byKey(Key('invite-tree-qa-$id'));
          await tester.scrollUntilVisible(
            row,
            200,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.pumpAndSettle();
          await tester.tap(row);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: id);
          final rect = tester.getRect(row);
          expect(rect.left, greaterThanOrEqualTo(0), reason: id);
          expect(rect.right, lessThanOrEqualTo(size.width), reason: id);
          final chevron = tester.getCenter(
            find.descendant(
              of: row,
              matching: find.byIcon(Icons.expand_more_rounded),
            ),
          );
          expect(
            rtl ? chevron.dx < rect.center.dx : chevron.dx > rect.center.dx,
            isTrue,
            reason: id,
          );
        }
      });
    }
  }
}

/// The limit sheet for [locales] on small phones: nothing overflows with
/// the invite card and Premium, and in a right to left language the
/// hourglass is on the right.
void sheetLayoutTests(List<String> locales) {
  for (final (size, scale) in layoutScreens) {
    if (size.width > 320) continue;
    for (final locale in locales) {
      testWidgets('[$locale ${size.width.toInt()}x${size.height.toInt()} at '
          '$scale] the limit sheet fits', (tester) async {
        screenFor(tester, size: size, textScale: scale);
        for (final answer in [treeAnswer(), oldAnswer()]) {
          await pumpSheetHost(
            tester,
            referrals: heldStatus(ReferralStatus.fromJson(answer)),
            locale: locale,
          );
          await openSheet(tester);
          expect(tester.takeException(), isNull);
          final card = tester.getRect(
            find.byKey(const Key('limit-sheet-invite-card')),
          );
          expect(card.left, greaterThanOrEqualTo(0));
          expect(card.right, lessThanOrEqualTo(size.width));
          final hourglass = tester.getCenter(
            find.byKey(const Key('limit-sheet-hourglass')),
          );
          final reset = tester.getCenter(
            find.byKey(const Key('limit-sheet-reset')),
          );
          final rtl = _rtl.contains(locale);
          expect(
            rtl ? hourglass.dx > reset.dx : hourglass.dx < reset.dx,
            isTrue,
          );
          // The sheet scrolls to its last button.
          await tester.scrollUntilVisible(
            find.byKey(const Key('limit-sheet-not-now')),
            100,
            scrollable: find
                .descendant(
                  of: find.byType(BottomSheet),
                  matching: find.byType(Scrollable),
                )
                .first,
          );
          expect(tester.takeException(), isNull);
          await inviteHomeDone(tester);
        }
      });
    }
  }
}

/// Stop the invite events a test made, whose send timer would outlive it.
void endEvents() {
  for (final events in madeEvents) {
    events.dispose();
  }
  madeEvents.clear();
}

/// The home screen of a spent phone on a small phone, for [locales]: the
/// invite link on the server card fits, and the power button stays wholly
/// on screen beside it.
void spentCardLayoutTests(List<String> locales) {
  late NoticePermissionPrompt originalNotice;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    mockTunnel([]);
    UpdateDialog.resetForTest();
    MessageDialog.resetForTest();
    originalNotice = NoticePermissionPrompt.instance;
    NoticePermissionPrompt.instance = NoticePermissionPrompt(
      permission: () async => NoticePermission.granted,
      isTv: () => false,
    );
  });

  tearDown(() {
    NoticePermissionPrompt.instance = originalNotice;
    unmockTunnel();
  });

  for (final (size, scale) in const [
    (Size(320, 568), 1.0),
    (Size(360, 640), 1.0),
    (Size(320, 640), 1.3),
  ]) {
    for (final locale in locales) {
      testWidgets('[$locale ${size.width.toInt()}x${size.height.toInt()} at '
          '$scale] the power button stays on screen beside the invite link', (
        tester,
      ) async {
        screenFor(tester, size: size, textScale: scale);
        await pumpInviteHome(
          tester,
          vpn: FakeVpn(VpnStatus.disconnected),
          config: await inviteConfig(),
          billing: FixedBilling(),
          referrals: heldStatus(ReferralStatus.fromJson(treeAnswer())),
          dedicated: FakeDedicated(inviteQuota(blocked: true)),
          locale: locale,
        );
        await tester.pump(const Duration(seconds: 1));
        expect(tester.takeException(), isNull);
        final link = find.byKey(const Key('server-card-invite'));
        expect(link, findsOneWidget);
        expectPowerButtonOnScreen(tester, size, locale);
        final rect = tester.getRect(link);
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(size.width));
        await inviteHomeDone(tester);
      });
    }
  }
}
