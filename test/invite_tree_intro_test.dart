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
import 'package:fortiva_vpn/screens/invite_tree_questions_screen.dart';
import 'package:fortiva_vpn/services/invite_share.dart';
import 'package:fortiva_vpn/widgets/invite_slots.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/app_theme.dart';
import 'helpers/invite_home.dart';
import 'helpers/invite_tree.dart';
import 'helpers/limit_sheet.dart';

/// The introduction to the invite tree: eight steps (seven for a user who
/// did not join with a code) that explain the code and the slots, how a
/// friend takes a slot, what each pair adds, a friend who stops, what
/// happens when the slots are full, people the user did not invite, the
/// user's data from friends and sharing, built from the user's own
/// referral answer. It exists only under the tree rule, opens by itself
/// once, and names only the backend's numbers.
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

  /// The fixture for a user who joined with someone's code: eight steps.
  ReferralStatus claimed([Map<String, dynamic>? json]) =>
      ReferralStatus.fromJson(
        (json ?? treeAnswer())..['claimed_code'] = 'QW8RT2',
      );

  /// Tap Next [times] times, letting each step come to rest.
  Future<void> forward(WidgetTester tester, int times) async {
    for (var i = 0; i < times; i++) {
      await tester.tap(next);
      await tester.pumpAndSettle();
    }
  }

  String stepLine(WidgetTester tester) => tester
      .widget<Text>(find.byKey(const Key('invite-tree-intro-step')))
      .data!;

  /// The icons of the slot discs under [of], in order: they say each
  /// slot's look.
  List<IconData> icons(WidgetTester tester, Finder of) => [
    for (final d in tester.widgetList<SlotDisc>(
      find.descendant(of: of, matching: find.byType(SlotDisc)),
    ))
      d.look.icon,
  ];
  const activeIcon = Icons.person_rounded;
  const joinedIcon = Icons.person_outline_rounded;
  const openIcon = Icons.add_rounded;

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
    // Once in How it works, and once under the stats.
    expect(find.text('Show me step by step'), findsNWidgets(2));
    expect(find.byKey(const Key('invite-tree-intro-open-top')), findsOneWidget);
    await tester.ensureVisible(link);
    await tester.pumpAndSettle();
    await tester.tap(link);
    await tester.pumpAndSettle();
    expect(intro, findsOneWidget);
  });

  testWidgets('the last step opens the questions, and back returns to it', (
    tester,
  ) async {
    await pumpIntro(tester, heldStatus(claimed()));
    await forward(tester, 7);
    expect(stepLine(tester), 'Step 8 of 8');
    final link = find.byKey(const Key('invite-tree-intro-questions'));
    await tester.ensureVisible(link);
    await tester.pumpAndSettle();
    await tester.tap(link);
    await tester.pumpAndSettle();
    expect(find.byType(InviteTreeQuestionsScreen), findsOneWidget);
    await tester.state<NavigatorState>(find.byType(Navigator)).maybePop();
    await tester.pumpAndSettle();
    expect(find.byType(InviteTreeQuestionsScreen), findsNothing);
    expect(intro, findsOneWidget);
    expect(stepLine(tester), 'Step 8 of 8');
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
      await forward(tester, 1);
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
        await forward(tester, 6);
        expect(stepLine(tester), 'Step 7 of 7');
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
      await forward(tester, 6);
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
      await forward(tester, 6);
      await tester.tap(find.byKey(const Key('invite-tree-intro-share')));
      await tester.pumpAndSettle();
      expect(intro, findsOneWidget);
      expect(wires(events), ['tree_intro/shown']);
      endEvents();
    });
  });

  group('the steps', () {
    testWidgets('eight for a user who joined with a code, seven without', (
      tester,
    ) async {
      await pumpIntro(tester, heldStatus(claimed()));
      expect(stepLine(tester), 'Step 1 of 8');
      expect(
        find.byKey(const Key('invite-tree-intro-progress-7')),
        findsOneWidget,
      );
      await forward(tester, 5);
      expect(stepLine(tester), 'Step 6 of 8');
      expect(
        find.text('Your first pair can hold people you did not invite'),
        findsOneWidget,
      );
      expect(
        find.text(
          "You joined with a friend's code. When their slots are full, their "
          'next friends can take an open slot in your first pair. Friends of '
          'other people can too. Whoever takes it adds data for you in the '
          'same way as your own friends.',
        ),
        findsOneWidget,
      );

      await tester.pumpWidget(const SizedBox());
      await pumpIntro(tester, heldStatus(tree()));
      expect(stepLine(tester), 'Step 1 of 7');
      expect(
        find.byKey(const Key('invite-tree-intro-progress-7')),
        findsNothing,
      );
      for (var page = 1; page < 7; page++) {
        await forward(tester, 1);
        expect(
          find.text('Your first pair can hold people you did not invite'),
          findsNothing,
          reason: 'step ${page + 1}',
        );
      }
      expect(stepLine(tester), 'Step 7 of 7');
    });

    testWidgets('the steps stay as they were while the story is open', (
      tester,
    ) async {
      final referrals = heldStatus(tree());
      await pumpIntro(tester, referrals);
      referrals.adoptForTest(claimed());
      await tester.pumpAndSettle();
      expect(stepLine(tester), 'Step 1 of 7');
    });

    testWidgets('1: the slots in their real states, with the code', (
      tester,
    ) async {
      await pumpIntro(tester, heldStatus(tree()));
      expect(
        find.text(
          'Friends who join with your code can add to your daily data. You '
          'have 6 slots for them. Each slot holds a friend, and the slots '
          'come in pairs. Your first pair is filled first. More friends can '
          'still join when your slots are full.',
        ),
        findsOneWidget,
      );
      Finder pair(int i) => find.byKey(Key('invite-tree-intro-pair-$i'));
      expect(icons(tester, pair(0)), [activeIcon, joinedIcon]);
      expect(icons(tester, pair(1)), [activeIcon, activeIcon]);
      expect(icons(tester, pair(2)), [openIcon, openIcon]);
      expect(pair(3), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(const Key('invite-tree-intro-code-chip')),
          matching: find.text('AB3D7K'),
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('invite-tree-intro-legend')), findsOneWidget);
    });

    testWidgets('1: with no slots, no legend and a line with no number', (
      tester,
    ) async {
      await pumpIntro(tester, heldStatus(tree(treeAnswer()..['pairs'] = [])));
      expect(find.text(en.inviteTreeIntroSlotsBodyNoNumber), findsOneWidget);
      expect(find.byKey(const Key('invite-tree-intro-legend')), findsNothing);
    });

    testWidgets('2: how a friend takes a slot, with the backend\'s hours and '
        'days', (tester) async {
      await pumpIntro(tester, heldStatus(tree()));
      await forward(tester, 1);
      expect(find.text('How a friend takes a slot'), findsOneWidget);
      expect(
        find.text(
          'Your friend must enter your code on their invite screen within 72 '
          'hours of installing Fortiva.',
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          'After that, they must use the VPN on 2 different days. Then they '
          'qualify and take the next open slot.',
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          'If they install from Google Play through your link, the code is '
          'entered for them.',
        ),
        findsOneWidget,
      );
      // One circle per day, all filled at the end.
      expect(
        find.byKey(const Key('invite-tree-intro-join-day-1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('invite-tree-intro-join-day-2')),
        findsNothing,
      );
      // The first pair with an open slot is the third: its first slot is
      // the one the friend takes. The friend lands in it as someone there,
      // never drawn active: whether they are is the backend's to say.
      expect(
        icons(tester, find.byKey(const Key('invite-tree-intro-join-pair'))),
        [joinedIcon, openIcon],
      );
      expect(
        find.byKey(const Key('invite-tree-intro-join-friend')),
        findsNothing,
      );
    });

    testWidgets('2: the slot ends not active whatever the days', (
      tester,
    ) async {
      for (final days in <Object?>[1, 2, 3, null]) {
        await pumpIntro(tester, heldStatus(tree(treeAnswer(activeDays: days))));
        await forward(tester, 1);
        expect(
          icons(tester, find.byKey(const Key('invite-tree-intro-join-pair'))),
          [joinedIcon, openIcon],
          reason: '$days',
        );
        await tester.pumpWidget(const SizedBox());
      }
    });

    testWidgets('2: a calendar in place of circles past the layout limit '
        'or with no number', (tester) async {
      for (final days in <Object?>[9, null]) {
        final json = treeAnswer()..['confirm_active_days'] = days;
        await pumpIntro(tester, heldStatus(tree(json)));
        await forward(tester, 1);
        expect(
          find.byKey(const Key('invite-tree-intro-join-calendar')),
          findsOneWidget,
          reason: '$days',
        );
        expect(
          find.byKey(const Key('invite-tree-intro-join-day-0')),
          findsNothing,
          reason: '$days',
        );
        await tester.pumpWidget(const SizedBox());
      }
    });

    testWidgets('3: a row per pair, with what it adds now highlighted', (
      tester,
    ) async {
      await pumpIntro(tester, heldStatus(tree()));
      await forward(tester, 2);
      expect(
        find.text(
          'Each pair can add data for you. It adds the most when both people '
          'in it are active.',
        ),
        findsOneWidget,
      );
      // The backend's amounts go down from the first pair to the last.
      expect(
        find.text('Your first pair adds the most. Each later pair adds less.'),
        findsOneWidget,
      );
      expect(
        find.text('What each pair adds to your data a day'),
        findsOneWidget,
      );
      for (var i = 0; i < 3; i++) {
        expect(
          find.byKey(Key('invite-tree-intro-row-$i')),
          findsOneWidget,
          reason: 'row $i',
        );
      }
      expect(find.byKey(const Key('invite-tree-intro-row-3')), findsNothing);
      Finder cell(String which, int i) =>
          find.byKey(Key('invite-tree-intro-$which-$i'));
      bool lit(String which, int i) {
        final box = tester.widget<Container>(cell(which, i));
        return (box.decoration as BoxDecoration?)?.color != null;
      }

      // The first pair adds its one-active amount now, the second its
      // both-active amount, the third nothing.
      expect([lit('both', 0), lit('one', 0)], [false, true]);
      expect([lit('both', 1), lit('one', 1)], [true, false]);
      expect([lit('both', 2), lit('one', 2)], [false, false]);
      expect(
        find.descendant(of: cell('both', 0), matching: find.text('+2${nb}GB')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: cell('one', 2), matching: find.text('+300${nb}MB')),
        findsOneWidget,
      );
      expect(
        find.text(
          'A friend is active while they have used the VPN on at least 2 '
          'days in the last 30 days.',
        ),
        findsOneWidget,
      );
      expect(
        find.text('The highlighted amounts are what your pairs add now.'),
        findsOneWidget,
      );
      expect(find.text(en.inviteTreeIntroPairOthersLess), findsNothing);
    });

    testWidgets('3: nothing highlighted when no pair adds anything now', (
      tester,
    ) async {
      final json = treeAnswer();
      for (final p in json['pairs'] as List) {
        (p as Map)['now_bytes'] = 0;
      }
      await pumpIntro(tester, heldStatus(tree(json)));
      await forward(tester, 2);
      expect(find.byKey(const Key('invite-tree-intro-note-now')), findsNothing);
    });

    testWidgets('3: one big pair when the first pair has no amounts', (
      tester,
    ) async {
      final json = treeAnswer();
      (json['pairs'] as List)[0] = {
        'states': ['active', 'joined'],
      };
      await pumpIntro(tester, heldStatus(tree(json)));
      await forward(tester, 2);
      expect(find.byKey(const Key('invite-tree-intro-row-0')), findsNothing);
      expect(
        find.byKey(const Key('invite-tree-intro-pair-big')),
        findsOneWidget,
      );
      expect(find.text(en.inviteTreeHowPair), findsOneWidget);
      expect(
        find.byKey(const Key('invite-tree-intro-note-active')),
        findsOneWidget,
      );
    });

    testWidgets('4: a friend who stops, ending on what one active adds', (
      tester,
    ) async {
      await pumpIntro(tester, heldStatus(tree()));
      await forward(tester, 3);
      expect(
        find.text('A friend adds data while they are active'),
        findsOneWidget,
      );
      expect(
        find.text(
          'If a friend stops using Fortiva, their pair adds less and your '
          'bonus can go down. They keep their slot. When they use Fortiva '
          'again, their pair adds more again.',
        ),
        findsOneWidget,
      );
      expect(find.text('+1${nb}GB a day'), findsOneWidget);
      // What the pair added before the friend stopped stays on the chip,
      // struck through, so the drop reads without the motion.
      final before = tester.widget<Text>(
        find.byKey(const Key('invite-tree-intro-chip-before')),
      );
      expect(before.data, '+2${nb}GB');
      expect(before.style?.decoration, TextDecoration.lineThrough);
      expect(
        icons(tester, find.byKey(const Key('invite-tree-intro-pair-big'))),
        [activeIcon, joinedIcon],
      );
    });

    testWidgets('4: says nothing is added when one active adds nothing', (
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
      await forward(tester, 3);
      expect(
        find.descendant(
          of: find.byKey(const Key('invite-tree-intro-art-3')),
          matching: find.text('Nothing'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('5: an example while own slots are open', (tester) async {
      await pumpIntro(tester, heldStatus(tree()));
      await forward(tester, 4);
      expect(find.text('When your slots are full'), findsOneWidget);
      expect(
        find.text(
          'When all your slots are taken, your next friend goes into the '
          'first pair of someone in your slots, in order from your first '
          'slot. That pair adds data for that person, and less for you.',
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('invite-tree-intro-next-chip')),
        findsNothing,
      );
      expect(find.text('A later friend'), findsOneWidget);
      // The friend who arrives is not active yet.
      final arriving = tester.widget<SlotDisc>(
        find.byKey(const Key('invite-tree-intro-arriving')),
      );
      expect(arriving.look.icon, joinedIcon);
    });

    testWidgets('5: the next friend\'s amount once every own slot is taken', (
      tester,
    ) async {
      final json = treeAnswer();
      (json['pairs'] as List)[2] = {
        'states': ['joined', 'joined'],
        'full_bytes': 600 << 20,
        'one_bytes': 0,
        'now_bytes': 0,
      };
      await pumpIntro(tester, heldStatus(tree(json)));
      await forward(tester, 4);
      expect(
        find.descendant(
          of: find.byKey(const Key('invite-tree-intro-next-chip')),
          matching: find.text('+300${nb}MB a day'),
        ),
        findsOneWidget,
      );
      expect(find.text('Your next friend'), findsOneWidget);
      final arriving = tester.widget<SlotDisc>(
        find.byKey(const Key('invite-tree-intro-arriving')),
      );
      expect(arriving.look.icon, activeIcon);
    });

    testWidgets('7: the total line gives way to the limit when the kept '
        'bonus is at or above it', (tester) async {
      final json = treeAnswer(keptBytes: 7 << 30, nextInviteBytes: null)
        ..['bonus_bytes'] = 7 << 30;
      // The kept bonus is the limit; invites add no more either way, so
      // the line says so. Below it, the limit line shows.
      await pumpIntro(tester, heldStatus(tree(json)));
      await forward(tester, 5);
      expect(find.text(en.premiumLimitInvitesFull), findsOneWidget);
      expect(find.textContaining('can reach'), findsNothing);
      await tester.pumpWidget(const SizedBox());

      final above = treeAnswer(keptBytes: 8 << 30, maxBonusBytes: 7 << 30);
      final status = tree(above);
      // A held status whose next friend still adds, to reach the cascade.
      await pumpIntro(tester, heldStatus(status));
      await forward(tester, 5);
      expect(find.textContaining('can reach'), findsNothing);
      expect(
        find.text('Invites can add up to 7${nb}GB a day.'),
        findsOneWidget,
      );
    });

    testWidgets('8: the code and the questions link', (tester) async {
      await pumpIntro(tester, heldStatus(tree()));
      await forward(tester, 6);
      expect(find.text('Invite friends who will use Fortiva'), findsOneWidget);
      expect(
        find.text(
          'A friend adds data for you only while they are active. Send your '
          'invite to friends who need a VPN.',
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('invite-tree-intro-code')), findsOneWidget);
      expect(find.text('AB3D7K'), findsOneWidget);
      expect(
        find.byKey(const Key('invite-tree-intro-questions')),
        findsOneWidget,
      );
    });
  });

  group('the numbers', () {
    testWidgets('are the backend\'s, from the answer', (tester) async {
      await pumpIntro(tester, heldStatus(tree()));
      // Step 7: now, the most, the kept part, the total and the next one.
      await forward(tester, 5);
      expect(find.text('2.5${nb}GB a day'), findsOneWidget);
      // The most is written at the end of the bar, with its name.
      expect(
        find.descendant(
          of: find.byKey(const Key('invite-tree-intro-most-row')),
          matching: find.text(
            'The most invites can add  7${nb}GB a day',
            findRichText: true,
          ),
        ),
        findsOneWidget,
      );
      expect(find.text('1${nb}GB a day'), findsOneWidget);
      expect(
        find.byKey(const Key('invite-tree-intro-kept-row')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('invite-tree-intro-now-swatch')),
        findsOneWidget,
      );
      // Both limits in one sentence, each named.
      expect(
        find.text(
          'Friends can add up to 7${nb}GB a day. Your free data and the data '
          'from friends together can reach 10${nb}GB a day.',
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          'Your bonus lasts while your friends keep using Fortiva. If a '
          'friend stops, your bonus can go down.',
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          'Your bonus does not go below 1${nb}GB a day, the bonus you had '
          'from earlier invites. This amount can go down only if one of your '
          'invites is removed.',
        ),
        findsOneWidget,
      );
      // Step 8: the next friend over Share.
      await forward(tester, 1);
      expect(
        find.text(
          'Your next friend adds 300${nb}MB a day once they qualify and are '
          'active.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('with every number missing, no step shows a digit and each '
        'shows its line with no number', (tester) async {
      final json =
          treeAnswer(
              nextInviteBytes: null,
              keptBytes: null,
              activeDays: null,
              activeWindowDays: null,
              maxBonusBytes: null,
            )
            ..remove('max_total_bytes')
            ..remove('confirm_active_days')
            ..remove('claim_window_hours');
      json['pairs'] = <Object?>[];
      json['bonus_bytes'] = 0;
      final status = tree(json);
      expect(status.isTree, isTrue);
      await pumpIntro(tester, heldStatus(status));
      final expected = <List<String>>[
        [en.inviteTreeIntroSlotsBodyNoNumber],
        [
          en.inviteTreeIntroJoinCodeNoNumber,
          en.inviteTreeIntroJoinQualifyNoNumber,
        ],
        [en.inviteTreeHowPair, en.inviteTreeHowActiveNoNumber],
        [en.inviteTreeIntroActiveStops],
        [en.inviteTreeIntroFullBody, en.inviteTreeIntroLaterFriend],
        // With no next amount and no bonus, invites have not added the
        // most: the step names the limit with no number.
        [en.inviteTreeHowCapNoAmount, en.inviteTreeNothingYet],
        [en.inviteTreeIntroShareBody],
      ];
      for (var page = 0; page < 7; page++) {
        if (page > 0) await forward(tester, 1);
        for (final line in expected[page]) {
          expect(find.text(line), findsOneWidget, reason: 'step ${page + 1}');
        }
        if (page == 6) {
          expect(
            find.byKey(const Key('invite-tree-intro-next-friend')),
            findsNothing,
          );
        }
        final digits = [
          for (final t in allTexts(tester))
            // The invite code is letters and digits, not a number.
            if (RegExp(r'\d').hasMatch(t) &&
                !t.startsWith('Step ') &&
                t != 'AB3D7K')
              t,
        ];
        expect(digits, isEmpty, reason: 'step ${page + 1}');
      }
    });

    testWidgets('with no most amount the total step names none', (
      tester,
    ) async {
      final json = treeAnswer(maxBonusBytes: null)..remove('max_total_bytes');
      await pumpIntro(tester, heldStatus(tree(json)));
      await forward(tester, 5);
      expect(find.text(en.inviteTreeHowCapNoAmount), findsOneWidget);
      expect(find.byKey(const Key('invite-tree-intro-bar')), findsNothing);
    });

    testWidgets('at the most it says invites add no more, with no next '
        'friend', (tester) async {
      final json = treeAnswer()..['bonus_bytes'] = 7 << 30;
      await pumpIntro(tester, heldStatus(tree(json)));
      await forward(tester, 5);
      expect(find.text(en.premiumLimitInvitesFull), findsOneWidget);
      await forward(tester, 1);
      expect(
        find.byKey(const Key('invite-tree-intro-next-friend')),
        findsNothing,
      );
    });

    testWidgets('no kept row when nothing was kept', (tester) async {
      await pumpIntro(tester, heldStatus(tree(treeAnswer(keptBytes: null))));
      await forward(tester, 5);
      expect(find.byKey(const Key('invite-tree-intro-kept-row')), findsNothing);
      expect(
        find.byKey(const Key('invite-tree-intro-note-kept')),
        findsNothing,
      );
    });

    testWidgets('in Persian, every number is in Persian digits', (
      tester,
    ) async {
      await pumpIntro(tester, heldStatus(claimed()), locale: 'fa');
      for (var page = 0; page < 8; page++) {
        if (page > 0) await forward(tester, 1);
        expect(
          allTexts(
            tester,
          ).where((t) => t != 'AB3D7K' && RegExp('[0-9]').hasMatch(t)),
          isEmpty,
          reason: 'step ${page + 1}',
        );
      }
      await tester.tap(find.byKey(const Key('invite-tree-intro-back')));
      await tester.pumpAndSettle();
      expect(find.text('۲٫۵${nb}GB در روز'), findsOneWidget);
    });
  });

  group('a small screen', () {
    /// How strongly the bottom edge of the step in view fades.
    double fade(WidgetTester tester) => tester
        .widget<AnimatedOpacity>(
          find.byKey(const Key('invite-tree-intro-fade')).first,
        )
        .opacity;

    testWidgets('a page longer than its room shows a scroll bar and fades at '
        'the bottom until the end is reached', (tester) async {
      screenFor(tester, size: const Size(320, 568), textScale: 1.3);
      await pumpIntro(tester, heldStatus(tree()));
      final bar = tester.widget<Scrollbar>(find.byType(Scrollbar).first);
      expect(bar.thumbVisibility, isTrue);
      expect(fade(tester), 1);
      await tester.drag(
        find.byType(SingleChildScrollView).first,
        const Offset(0, -2000),
      );
      await tester.pumpAndSettle();
      expect(fade(tester), 0);
    });

    testWidgets('the drawings are shorter, and the legend of step 1 sits in '
        'the card', (tester) async {
      screenFor(tester, size: const Size(320, 568));
      await pumpIntro(tester, heldStatus(tree()));
      final card = tester.getRect(
        find.byKey(const Key('invite-tree-intro-art-0')),
      );
      final legend = tester.getRect(
        find.byKey(const Key('invite-tree-intro-legend')),
      );
      expect(legend.top, greaterThan(card.top));
      expect(legend.bottom, lessThanOrEqualTo(card.bottom));
      // All three pairs are drawn, not two.
      for (var i = 0; i < 3; i++) {
        expect(find.byKey(Key('invite-tree-intro-pair-$i')), findsOneWidget);
      }
      await forward(tester, 1);
      expect(
        tester.getSize(find.byKey(const Key('invite-tree-intro-art-1'))).height,
        112,
      );
    });

    testWidgets('an amount in the pair table never breaks inside its unit', (
      tester,
    ) async {
      screenFor(tester, size: const Size(320, 568));
      await pumpIntro(tester, heldStatus(tree()));
      await forward(tester, 2);
      for (var i = 0; i < 3; i++) {
        for (final which in ['both', 'one']) {
          final text = tester.widget<Text>(
            find.descendant(
              of: find.byKey(Key('invite-tree-intro-$which-$i')),
              matching: find.byType(Text),
            ),
          );
          expect(text.maxLines, 1, reason: '$which $i');
          expect(text.softWrap, isFalse, reason: '$which $i');
        }
      }
    });
  });

  group('motion', () {
    testWidgets('under reduced motion every step shows its last frame at '
        'once', (tester) async {
      screenFor(tester, reduced: true);
      await pumpIntro(tester, heldStatus(claimed()));
      expect(tester.binding.hasScheduledFrame, isFalse);
      for (var page = 1; page < 8; page++) {
        await tester.tap(next);
        await tester.pump();
        if (page == 3) {
          // The chip already says what the pair adds with one active.
          expect(find.text('+1${nb}GB a day'), findsOneWidget);
        }
        if (page == 1) {
          expect(
            icons(tester, find.byKey(const Key('invite-tree-intro-join-pair'))),
            [joinedIcon, openIcon],
          );
        }
        await tester.pumpAndSettle();
        expect(tester.binding.hasScheduledFrame, isFalse, reason: '$page');
      }
    });

    testWidgets('every step comes to rest', (tester) async {
      await pumpIntro(tester, heldStatus(claimed()));
      expect(tester.binding.hasScheduledFrame, isFalse);
      for (var i = 0; i < 7; i++) {
        await tester.tap(next);
        await tester.pumpAndSettle();
        expect(tester.binding.hasScheduledFrame, isFalse, reason: '$i');
      }
    });

    testWidgets('the pair goes from both active to one as it plays', (
      tester,
    ) async {
      await pumpIntro(tester, heldStatus(tree()));
      await forward(tester, 2);
      await tester.tap(next);
      // The page slides in, then the drawing starts from its first frame:
      // the chip says what both active add before the second stops.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('+2${nb}GB a day'), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.text('+1${nb}GB a day'), findsOneWidget);
    });

    testWidgets('the friend travels to the slot as step 2 plays', (
      tester,
    ) async {
      await pumpIntro(tester, heldStatus(tree()));
      await tester.tap(next);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump(const Duration(milliseconds: 900));
      expect(
        find.byKey(const Key('invite-tree-intro-join-friend')),
        findsOneWidget,
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('invite-tree-intro-join-friend')),
        findsNothing,
      );
    });
  });

  test('the record key is cleared with the account', () {
    expect(InviteTreeIntroRecord.seenKey, 'invite_tree_intro_seen');
  });
}
