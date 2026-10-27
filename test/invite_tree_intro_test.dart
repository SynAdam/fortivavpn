import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/api/referral_service.dart';
import 'package:fortiva_vpn/core/form_factor.dart';
import 'package:fortiva_vpn/core/state/invite_events.dart';
import 'package:fortiva_vpn/core/state/invite_prompt.dart';
import 'package:fortiva_vpn/core/state/invite_tree_intro.dart';
import 'package:fortiva_vpn/core/state/referral_state.dart';
import 'package:fortiva_vpn/l10n/generated/app_localizations.dart';
import 'package:fortiva_vpn/screens/invite_screen.dart';
import 'package:fortiva_vpn/screens/invite_tree_intro_screen.dart';
import 'package:fortiva_vpn/services/invite_share.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/app_theme.dart';
import 'helpers/invite_home.dart';
import 'helpers/invite_tree.dart';
import 'helpers/limit_sheet.dart';

/// The introduction to the invite tree: four steps that explain slots,
/// pairs, friends further away and the user's data from friends, built from
/// the user's own referral answer. It exists only under the tree rule, opens
/// by itself once, and names only the backend's numbers.
void main() {
  /// A no-break space, as the screens join an amount to its unit.
  const nb = ' ';
  final intro = find.byType(InviteTreeIntroScreen);
  final next = find.byKey(const Key('invite-tree-intro-next'));
  final en = lookupS(const Locale('en'));

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    FormFactor.isTvForTest = false;
    for (final events in madeEvents) {
      events.dispose();
    }
    madeEvents.clear();
  });

  ReferralStatus tree([Map<String, dynamic>? json]) =>
      ReferralStatus.fromJson(json ?? treeAnswer());

  /// The invite screen over [referrals], with the record that keeps the
  /// introduction to once when [record] is given.
  Future<void> pumpInvite(
    WidgetTester tester,
    ReferralState referrals, {
    InviteTreeIntroRecord? record,
    InviteEvents? events,
  }) async {
    screenFor(tester, size: const Size(400, 3000));
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ReferralState>.value(value: referrals),
          if (record != null)
            Provider<InviteTreeIntroRecord>.value(value: record),
          if (events != null) Provider<InviteEvents>.value(value: events),
        ],
        child: MaterialApp(
          theme: appThemeFor(const Locale('en')),
          localizationsDelegates: S.localizationsDelegates,
          supportedLocales: S.supportedLocales,
          locale: const Locale('en'),
          home: const InviteScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // The story opens a moment after the screen has loaded.
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
  }

  group('opening by itself', () {
    testWidgets('opens once under the tree rule, after the first load', (
      tester,
    ) async {
      final record = InviteTreeIntroRecord();
      final events = keptEvents();
      await pumpInvite(
        tester,
        ReferralBackend(answer: treeAnswer()).state,
        record: record,
        events: events,
      );
      expect(intro, findsOneWidget);
      expect(await record.seen(), isTrue);
      expect([
        for (final e in events.queued) '${e['surface']}/${e['action']}',
      ], contains('tree_intro/shown'));
      endEvents();

      // The same install again: it does not open a second time.
      await tester.pumpWidget(const SizedBox());
      await pumpInvite(
        tester,
        ReferralBackend(answer: treeAnswer()).state,
        record: InviteTreeIntroRecord(),
      );
      expect(intro, findsNothing);
    });

    testWidgets('never under today\'s rule', (tester) async {
      final record = InviteTreeIntroRecord();
      await pumpInvite(
        tester,
        ReferralBackend(answer: oldAnswer()).state,
        record: record,
      );
      expect(intro, findsNothing);
      expect(await record.seen(), isFalse);
      expect(find.byKey(const Key('invite-tree-intro-open')), findsNothing);
    });

    testWidgets('never on a TV', (tester) async {
      FormFactor.isTvForTest = true;
      await pumpInvite(
        tester,
        ReferralBackend(answer: treeAnswer()).state,
        record: InviteTreeIntroRecord(),
      );
      expect(intro, findsNothing);
    });

    testWidgets('never without the record that keeps it to once', (
      tester,
    ) async {
      await pumpInvite(tester, ReferralBackend(answer: treeAnswer()).state);
      expect(intro, findsNothing);
    });

    testWidgets('a record that cannot be read counts as seen', (tester) async {
      final record = InviteTreeIntroRecord(
        prefs: () async => throw StateError('no store'),
      );
      expect(await record.seen(), isTrue);
      await record.markSeen();
    });
  });

  testWidgets('How it works opens it again', (tester) async {
    SharedPreferences.setMockInitialValues({
      InviteTreeIntroRecord.seenKey: true,
    });
    await pumpInvite(
      tester,
      ReferralBackend(answer: treeAnswer()).state,
      record: InviteTreeIntroRecord(),
    );
    expect(intro, findsNothing);
    final link = find.byKey(const Key('invite-tree-intro-open'));
    expect(link, findsOneWidget);
    expect(find.text('Show me step by step'), findsOneWidget);
    await tester.tap(link);
    await tester.pumpAndSettle();
    expect(intro, findsOneWidget);
  });

  testWidgets('a status that stops being a tree closes it', (tester) async {
    final referrals = heldStatus(tree());
    await pumpIntro(tester, referrals);
    expect(intro, findsOneWidget);
    referrals.adoptForTest(ReferralStatus.fromJson(oldAnswer()));
    await tester.pumpAndSettle();
    expect(intro, findsNothing);
  });

  group('events', () {
    List<String> wires(InviteEvents events) => [
      for (final e in events.queued) '${e['surface']}/${e['action']}',
    ];

    testWidgets('Skip notes the story was left early', (tester) async {
      final events = keptEvents();
      await pumpIntro(tester, heldStatus(tree()), events: events);
      await tester.tap(find.byKey(const Key('invite-tree-intro-skip')));
      await tester.pumpAndSettle();
      expect(intro, findsNothing);
      expect(wires(events), ['tree_intro/shown', 'tree_intro/dismissed']);
      endEvents();
    });

    testWidgets('back before the last step notes it too, and closes the '
        'story rather than stepping back', (tester) async {
      final events = keptEvents();
      await pumpIntro(tester, heldStatus(tree()), events: events);
      await tester.tap(next);
      await tester.pumpAndSettle();
      await tester.state<NavigatorState>(find.byType(Navigator)).maybePop();
      await tester.pumpAndSettle();
      expect(intro, findsNothing);
      expect(wires(events), ['tree_intro/shown', 'tree_intro/dismissed']);
      endEvents();
    });

    testWidgets('Done and back on the last step note nothing more', (
      tester,
    ) async {
      for (final close in ['done', 'back']) {
        final events = keptEvents();
        await pumpIntro(tester, heldStatus(tree()), events: events);
        for (var i = 0; i < 3; i++) {
          await tester.tap(next);
          await tester.pumpAndSettle();
        }
        if (close == 'done') {
          await tester.tap(find.byKey(const Key('invite-tree-intro-done')));
        } else {
          await tester.state<NavigatorState>(find.byType(Navigator)).maybePop();
        }
        await tester.pumpAndSettle();
        expect(intro, findsNothing, reason: close);
        expect(wires(events), ['tree_intro/shown'], reason: close);
        endEvents();
      }
    });

    testWidgets('Share on the last step shares, ends the invite card, and '
        'closes', (tester) async {
      final calls = <MethodCall>[];
      mockTunnel(calls);
      InviteShare.nativeForTest = true;
      addTearDown(() {
        InviteShare.nativeForTest = null;
        unmockTunnel();
      });
      final events = keptEvents();
      final prompt = InvitePrompt();
      await pumpIntro(
        tester,
        heldStatus(tree()),
        events: events,
        prompt: prompt,
      );
      for (var i = 0; i < 3; i++) {
        await tester.tap(next);
        await tester.pumpAndSettle();
      }
      await tester.tap(find.byKey(const Key('invite-tree-intro-share')));
      await tester.pumpAndSettle();
      final share = calls.singleWhere((c) => c.method == 'shareInvite');
      expect(
        (share.arguments as Map)['text'],
        contains('https://fortivavpn.com/i/AB3D7K'),
      );
      expect(intro, findsNothing);
      expect(wires(events), ['tree_intro/shown', 'tree_intro/other_apps']);
      final prefs = await SharedPreferences.getInstance();
      final saved =
          jsonDecode(prefs.getString(InvitePrompt.inviteStateKey)!)
              as Map<String, dynamic>;
      expect(saved['done'], isTrue);
      endEvents();
    });

    testWidgets('a share that opened nothing keeps the story open', (
      tester,
    ) async {
      mockTunnel([], share: 'none');
      InviteShare.nativeForTest = true;
      addTearDown(() {
        InviteShare.nativeForTest = null;
        unmockTunnel();
      });
      final events = keptEvents();
      await pumpIntro(tester, heldStatus(tree()), events: events);
      for (var i = 0; i < 3; i++) {
        await tester.tap(next);
        await tester.pumpAndSettle();
      }
      await tester.tap(find.byKey(const Key('invite-tree-intro-share')));
      await tester.pumpAndSettle();
      expect(intro, findsOneWidget);
      expect(wires(events), ['tree_intro/shown']);
      endEvents();
    });
  });

  group('the numbers', () {
    testWidgets('are the backend\'s, from the answer', (tester) async {
      await pumpIntro(tester, heldStatus(tree()));
      // Step 1: the slots counted from the pairs.
      expect(
        find.text(
          'Share your code. The first 6 friends who qualify fill your '
          'slots, in pairs.',
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('invite-tree-intro-pair-2')), findsOneWidget);
      expect(find.byKey(const Key('invite-tree-intro-pair-3')), findsNothing);

      // Step 2: the first pair's own amounts.
      await tester.tap(next);
      await tester.pumpAndSettle();
      expect(
        find.text(
          'When both friends in your first pair are active, it adds '
          '2${nb}GB a day. When only one of them is active, it adds '
          '1${nb}GB a day.',
        ),
        findsOneWidget,
      );
      expect(find.text('+2${nb}GB a day'), findsOneWidget);
      expect(find.text('Your other pairs add less.'), findsOneWidget);
      expect(
        find.text(
          'A friend is active while they have used Fortiva on at least 2 '
          'days in the last 30 days.',
        ),
        findsOneWidget,
      );

      // Step 3: no number at all.
      await tester.tap(next);
      await tester.pumpAndSettle();
      expect(
        find.text(
          "From your friend's slots, only their first pair adds data for "
          'you.',
        ),
        findsOneWidget,
      );

      // Step 4: now, the most, the kept part, the total and the next one.
      await tester.tap(next);
      await tester.pumpAndSettle();
      expect(find.text('2.5${nb}GB a day'), findsOneWidget);
      expect(find.text('7${nb}GB a day'), findsOneWidget);
      expect(find.text('1${nb}GB a day'), findsOneWidget);
      expect(
        find.byKey(const Key('invite-tree-intro-kept-row')),
        findsOneWidget,
      );
      expect(
        find.text(
          'Free data plus data from friends can reach 10${nb}GB a day.',
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          'Your next friend adds 300${nb}MB a day once they start using '
          'Fortiva.',
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          'Your bonus lasts while your friends keep using Fortiva. If a '
          'friend stops, it goes down.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('one active friend alone that adds nothing says so', (
      tester,
    ) async {
      final json = treeAnswer();
      (json['pairs'] as List)[0] = {
        'states': ['active', 'joined'],
        'full_bytes': 2 << 30,
        'one_bytes': 0,
        'now_bytes': 0,
      };
      await pumpIntro(tester, heldStatus(tree(json)));
      await tester.tap(next);
      await tester.pumpAndSettle();
      expect(
        find.text(
          'When both friends in your first pair are active, it adds '
          '2${nb}GB a day. When only one of them is active, it adds '
          'nothing.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('with every number missing, no step shows a digit and each '
        'shows its line with no number', (tester) async {
      final json = treeAnswer(
        nextInviteBytes: null,
        keptBytes: null,
        activeDays: null,
        activeWindowDays: null,
        maxBonusBytes: null,
      )..remove('max_total_bytes');
      json['pairs'] = <Object?>[];
      json['bonus_bytes'] = 0;
      final status = tree(json);
      expect(status.isTree, isTrue);
      await pumpIntro(tester, heldStatus(status));
      final expected = [
        en.inviteTreeHowSlotsNoNumber,
        en.inviteTreeHowPair,
        en.inviteTreeHowFriendsSlots,
        // With no next amount the backend says the next friend adds
        // nothing, so the last step says invites add no more.
        en.premiumLimitInvitesFull,
      ];
      for (var page = 0; page < 4; page++) {
        if (page > 0) {
          await tester.tap(next);
          await tester.pumpAndSettle();
        }
        expect(find.text(expected[page]), findsOneWidget, reason: '$page');
        if (page == 1) {
          expect(find.text(en.inviteTreeHowActiveNoNumber), findsOneWidget);
        }
        if (page == 3) {
          expect(find.text(en.inviteTreeNothingYet), findsOneWidget);
          expect(
            find.byKey(const Key('invite-tree-intro-next-friend')),
            findsNothing,
          );
        }
        final digits = [
          for (final t in allTexts(tester))
            if (RegExp(r'\d').hasMatch(t) && !t.startsWith('Step ')) t,
        ];
        expect(digits, isEmpty, reason: 'step ${page + 1}');
      }
    });

    testWidgets('with no most amount the last step names none', (tester) async {
      final json = treeAnswer(maxBonusBytes: null)..remove('max_total_bytes');
      await pumpIntro(tester, heldStatus(tree(json)));
      for (var i = 0; i < 3; i++) {
        await tester.tap(next);
        await tester.pumpAndSettle();
      }
      expect(find.text(en.inviteTreeHowCapNoAmount), findsOneWidget);
      expect(find.byKey(const Key('invite-tree-intro-bar')), findsNothing);
    });

    testWidgets('at the most it says invites add no more, with no next '
        'friend', (tester) async {
      final json = treeAnswer()..['bonus_bytes'] = 7 << 30;
      await pumpIntro(tester, heldStatus(tree(json)));
      for (var i = 0; i < 3; i++) {
        await tester.tap(next);
        await tester.pumpAndSettle();
      }
      expect(find.text(en.premiumLimitInvitesFull), findsOneWidget);
      expect(
        find.byKey(const Key('invite-tree-intro-next-friend')),
        findsNothing,
      );
    });

    testWidgets('no kept row when nothing was kept', (tester) async {
      await pumpIntro(tester, heldStatus(tree(treeAnswer(keptBytes: null))));
      for (var i = 0; i < 3; i++) {
        await tester.tap(next);
        await tester.pumpAndSettle();
      }
      expect(find.byKey(const Key('invite-tree-intro-kept-row')), findsNothing);
      expect(
        find.byKey(const Key('invite-tree-intro-note-kept')),
        findsNothing,
      );
    });

    testWidgets('in Persian, every number is in Persian digits', (
      tester,
    ) async {
      await pumpIntro(tester, heldStatus(tree()), locale: 'fa');
      for (var page = 0; page < 4; page++) {
        if (page > 0) {
          await tester.tap(next);
          await tester.pumpAndSettle();
        }
        expect(
          allTexts(tester).where((t) => RegExp('[0-9]').hasMatch(t)),
          isEmpty,
          reason: 'step ${page + 1}',
        );
      }
      expect(find.text('۲٫۵${nb}GB در روز'), findsOneWidget);
    });
  });

  group('motion', () {
    testWidgets('under reduced motion every step shows its last frame at '
        'once', (tester) async {
      screenFor(tester, reduced: true);
      await pumpIntro(tester, heldStatus(tree()));
      expect(tester.binding.hasScheduledFrame, isFalse);
      await tester.tap(next);
      await tester.pump();
      // The chip already says what the pair adds with both active.
      expect(find.text('+2${nb}GB a day'), findsOneWidget);
      await tester.pumpAndSettle();
      expect(tester.binding.hasScheduledFrame, isFalse);
      await tester.tap(next);
      await tester.pump();
      await tester.pumpAndSettle();
      expect(tester.binding.hasScheduledFrame, isFalse);
      await tester.tap(next);
      await tester.pump();
      await tester.pumpAndSettle();
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('every step comes to rest', (tester) async {
      await pumpIntro(tester, heldStatus(tree()));
      expect(tester.binding.hasScheduledFrame, isFalse);
      for (var i = 0; i < 3; i++) {
        await tester.tap(next);
        await tester.pumpAndSettle();
        expect(tester.binding.hasScheduledFrame, isFalse, reason: '$i');
      }
    });

    testWidgets('the pair turns active as it plays', (tester) async {
      await pumpIntro(tester, heldStatus(tree()));
      await tester.tap(next);
      // The page slides in, then the drawing starts from its first frame:
      // the chip says what one active friend adds before both are active.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump(const Duration(milliseconds: 700));
      expect(find.text('+1${nb}GB a day'), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.text('+2${nb}GB a day'), findsOneWidget);
    });
  });

  test('the record key is cleared with the account', () {
    expect(InviteTreeIntroRecord.seenKey, 'invite_tree_intro_seen');
  });
}
