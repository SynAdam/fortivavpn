import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/api/referral_service.dart';
import 'package:fortiva_vpn/core/state/referral_state.dart';
import 'package:fortiva_vpn/l10n/generated/app_localizations.dart';
import 'package:fortiva_vpn/screens/invite_tree_questions_screen.dart';
import 'package:provider/provider.dart';

import 'helpers/app_theme.dart';
import 'helpers/invite_tree.dart';
import 'helpers/limit_sheet.dart';

/// The questions and answers about the invite tree: which questions show
/// for which user, in their order, each answer built from the user's own
/// referral answer with the backend's numbers, and a line that names no
/// number for each one the backend did not send.
void main() {
  /// A no-break space, as the screens join an amount to its unit.
  const nb = '\u00A0';
  final en = lookupS(const Locale('en'));

  Future<ReferralState> pumpQuestions(
    WidgetTester tester,
    ReferralStatus status, {
    String locale = 'en',
  }) async {
    screenFor(tester, size: const Size(400, 6000));
    final referrals = heldStatus(status);
    await tester.pumpWidget(
      ChangeNotifierProvider<ReferralState>.value(
        value: referrals,
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
    return referrals;
  }

  /// The ids of the questions on the page, in order.
  List<String> ids(WidgetTester tester) => [
    for (final w in tester.widgetList(
      find.byWidgetPredicate(
        (w) =>
            w.key is ValueKey<String> &&
            (w.key! as ValueKey<String>).value.startsWith('invite-tree-qa-'),
      ),
    ))
      (w.key! as ValueKey<String>).value.substring('invite-tree-qa-'.length),
  ];

  Future<void> open(WidgetTester tester, String id) async {
    final row = find.byKey(Key('invite-tree-qa-$id'));
    await tester.scrollUntilVisible(
      row,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(row);
    await tester.pumpAndSettle();
  }

  /// The answer under question [id], as its paragraphs.
  List<String> answer(WidgetTester tester, String id) {
    final tile = find
        .ancestor(
          of: find.byKey(Key('invite-tree-qa-$id')),
          matching: find.byType(Material),
        )
        .first;
    final question = tester
        .widget<Text>(
          find.descendant(
            of: find.byKey(Key('invite-tree-qa-$id')),
            matching: find.byType(Text),
          ),
        )
        .data;
    return [
      for (final t in tester.widgetList<Text>(
        find.descendant(of: tile, matching: find.byType(Text)),
      ))
        if (t.data != question) t.data!,
    ];
  }

  ReferralStatus status([Map<String, dynamic>? json]) =>
      ReferralStatus.fromJson(json ?? treeAnswer());

  Map<String, dynamic> claimedWithPremium() => treeAnswer()
    ..['claimed_code'] = 'QW8RT2'
    ..['earns'] = true
    ..['reward_premium_days'] = 3
    ..['premium_days_max'] = 30;

  group('which questions show', () {
    testWidgets('every question for a user who joined with a code, kept a '
        'bonus and gets Premium days, in order', (tester) async {
      await pumpQuestions(tester, status(claimedWithPremium()));
      expect(ids(tester), everyQuestion);
    });

    testWidgets('no question about people not invited without a claimed '
        'code, none about a kept bonus without one, and none about Premium '
        'days without them', (tester) async {
      await pumpQuestions(tester, status(treeAnswer(keptBytes: null)));
      expect(ids(tester), [
        'changed',
        'count',
        'down',
        'full',
        'start',
        'cost',
        'friends',
        'sum',
        'slot',
        'phone',
        'privacy',
        'limit',
        'gets',
      ]);
    });

    testWidgets('Premium days only when the invite screen shows them', (
      tester,
    ) async {
      final json = claimedWithPremium()..['earns'] = false;
      await pumpQuestions(tester, status(json));
      expect(ids(tester), isNot(contains('premium')));
    });
  });

  group('the answers', () {
    testWidgets('start closed, open and close, and several stay open', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpQuestions(tester, status());
      expect(find.text(en.inviteTreeQaCountDay), findsNothing);
      expect(
        tester.getSemantics(find.byKey(const Key('invite-tree-qa-count'))),
        containsSemantics(
          isButton: true,
          hasExpandedState: true,
          isExpanded: false,
        ),
      );
      await open(tester, 'count');
      await open(tester, 'down');
      expect(find.text(en.inviteTreeQaCountDay), findsOneWidget);
      expect(find.text(en.inviteTreeQaDownLater), findsOneWidget);
      expect(
        tester.getSemantics(find.byKey(const Key('invite-tree-qa-count'))),
        containsSemantics(
          isButton: true,
          hasExpandedState: true,
          isExpanded: true,
        ),
      );
      await open(tester, 'count');
      expect(find.text(en.inviteTreeQaCountDay), findsNothing);
      expect(find.text(en.inviteTreeQaDownLater), findsOneWidget);
      handle.dispose();
    });

    testWidgets('say the backend\'s numbers', (tester) async {
      await pumpQuestions(tester, status(claimedWithPremium()));
      for (final id in everyQuestion) {
        await open(tester, id);
      }
      expect(answer(tester, 'count'), [
        'Your friend must enter your code on their invite screen within 72 '
            'hours of installing Fortiva.',
        'After that, they must use the VPN on 2 different days. Then they '
            'qualify and take the next open slot.',
        en.inviteTreeQaCountDay,
        'Until they qualify, your invite screen counts them in "Invited", '
            'but not yet in "Qualified".',
        en.inviteTreeIntroJoinPlay,
        en.inviteTreeQaCountOther,
      ]);
      expect(answer(tester, 'down'), [
        en.inviteTreeQaDownA,
        'A friend is active while they have used the VPN on at least 2 days '
            'in the last 30 days.',
        en.inviteTreeQaDownLater,
        en.inviteTreeQaDownRemoved,
        'Your bonus does not go below 1${nb}GB a day, the bonus you had from '
            'earlier invites. This amount can go down only if one of your '
            'invites is removed.',
      ]);
      // The fixture's third pair is open, so the next friend takes it and
      // the answer has no amount of its own.
      expect(answer(tester, 'full'), [
        en.inviteTreeIntroFullBody,
        en.inviteTreeQaFullFurther,
        en.inviteTreeIntroFullLess,
      ]);
      expect(answer(tester, 'others'), [
        en.inviteTreeQaOthersA,
        en.inviteTreeIntroOthersYours,
      ]);
      expect(answer(tester, 'sum'), [
        en.inviteTreeQaSumA,
        en.inviteTreeQaKeptMore,
      ]);
      // Both limits in one sentence, each named.
      expect(answer(tester, 'limit'), [
        'Friends can add up to 7${nb}GB a day. Your free data and the data '
            'from friends together can reach 10${nb}GB a day.',
        en.inviteTreeQaLimitMore,
      ]);
      expect(answer(tester, 'start'), [en.inviteTreeQaStartA]);
      expect(answer(tester, 'cost'), [en.inviteTreeQaCostA]);
      expect(answer(tester, 'phone'), [en.inviteTreeQaPhoneA]);
      expect(answer(tester, 'kept'), [
        'Your bonus does not go below 1${nb}GB a day, the bonus you had from '
            'earlier invites. This amount can go down only if one of your '
            'invites is removed.',
        en.inviteTreeQaKeptMore,
        en.inviteTreeQaKeptRemoved,
      ]);
      expect(answer(tester, 'changed'), hasLength(2));
      expect(answer(tester, 'premium'), [
        'Each friend who qualifies with your code also adds 3 days of '
            'Premium for you.',
        'Invites can add up to 30 days of Premium.',
        en.inviteTreeQaPremiumOwn,
      ]);
      expect(answer(tester, 'gets'), [
        en.inviteTreeQaGetsA,
        en.inviteTreeQaGetsSee,
      ]);
    });

    testWidgets('name the next friend\'s amount only once every own slot is '
        'taken and invites still add more', (tester) async {
      final json = treeAnswer();
      (json['pairs'] as List)[2] = {
        'states': ['joined', 'joined'],
        'full_bytes': 600 << 20,
        'one_bytes': 0,
        'now_bytes': 0,
      };
      await pumpQuestions(tester, status(json));
      await open(tester, 'full');
      expect(
        answer(tester, 'full').last,
        'Your next friend adds 300${nb}MB a day once they qualify and are '
        'active.',
      );

      // At the most, invites add no more: no amount.
      await tester.pumpWidget(const SizedBox());
      await pumpQuestions(tester, status(json..['bonus_bytes'] = 7 << 30));
      await open(tester, 'full');
      expect(answer(tester, 'full'), hasLength(3));
    });

    testWidgets('leave out the total when the kept bonus is at or above the '
        'limit', (tester) async {
      await pumpQuestions(
        tester,
        status(treeAnswer(keptBytes: 8 << 30, maxBonusBytes: 7 << 30)),
      );
      await open(tester, 'limit');
      expect(answer(tester, 'limit'), [
        'Invites can add up to 7${nb}GB a day.',
        en.inviteTreeQaLimitMore,
      ]);
    });

    testWidgets('with every number missing, name none', (tester) async {
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
            ..remove('claim_window_hours')
            ..['claimed_code'] = 'QW8RT2';
      json['pairs'] = <Object?>[];
      await pumpQuestions(tester, status(json));
      for (final id in ids(tester)) {
        await open(tester, id);
      }
      expect(answer(tester, 'count').take(2), [
        en.inviteTreeIntroJoinCodeNoNumber,
        en.inviteTreeIntroJoinQualifyNoNumber,
      ]);
      expect(answer(tester, 'down')[1], en.inviteTreeHowActiveNoNumber);
      expect(answer(tester, 'limit'), [
        en.inviteTreeHowCapNoAmount,
        en.inviteTreeQaLimitMore,
      ]);
      final digits = [
        for (final t in tester.widgetList<Text>(find.byType(Text)))
          if (RegExp(r'\d').hasMatch(t.data ?? '')) t.data,
      ];
      expect(digits, isEmpty);
    });

    testWidgets('in Persian, every number is in Persian digits', (
      tester,
    ) async {
      await pumpQuestions(tester, status(claimedWithPremium()), locale: 'fa');
      for (final id in everyQuestion) {
        await open(tester, id);
      }
      // Each answer as its paragraphs, read from the screen's builder so a
      // paragraph scrolled out of the list is checked too.
      final context = tester.element(find.byType(InviteTreeQuestionsScreen));
      final paragraphs = [
        for (final q in inviteTreeQuestions(
          context,
          ReferralStatus.fromJson(claimedWithPremium()),
          noMore: false,
        ))
          ...q.answer,
      ];
      expect(paragraphs.where((p) => RegExp('[0-9]').hasMatch(p)), isEmpty);
      expect(paragraphs.where((p) => p.contains('۷۲')), hasLength(1));
      expect(paragraphs.where((p) => p.contains('۳۰')), isNotEmpty);
    });
  });

  testWidgets('a status that stops being a tree closes the page', (
    tester,
  ) async {
    screenFor(tester);
    final referrals = heldStatus(status());
    await tester.pumpWidget(
      ChangeNotifierProvider<ReferralState>.value(
        value: referrals,
        child: MaterialApp(
          localizationsDelegates: S.localizationsDelegates,
          supportedLocales: S.supportedLocales,
          locale: const Locale('en'),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                key: const Key('open-questions'),
                onPressed: () => InviteTreeQuestionsScreen.open(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('open-questions')));
    await tester.pumpAndSettle();
    expect(find.byType(InviteTreeQuestionsScreen), findsOneWidget);
    referrals.adoptForTest(ReferralStatus.fromJson(oldAnswer()));
    await tester.pumpAndSettle();
    expect(find.byType(InviteTreeQuestionsScreen), findsNothing);
  });

  testWidgets('the page ends with a way to the story itself', (tester) async {
    await pumpQuestions(tester, status());
    final link = find.byKey(const Key('invite-tree-questions-intro'));
    await tester.scrollUntilVisible(
      link,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Show me step by step'), findsOneWidget);
    // Under every question.
    final last = find.byKey(const Key('invite-tree-qa-gets'));
    expect(tester.getRect(link).top, greaterThan(tester.getRect(last).top));
  });

  testWidgets('the kept answer says when friends add again, while the bonus '
      'is the kept part', (tester) async {
    // The backend's own case: 2 GiB kept, all slots open, no next amount.
    final json = treeAnswer(keptBytes: 2 << 30, nextInviteBytes: null)
      ..['bonus_bytes'] = 2 << 30;
    for (final p in json['pairs'] as List) {
      (p as Map)['states'] = ['empty', 'empty'];
      p['now_bytes'] = 0;
    }
    await pumpQuestions(tester, status(json));
    await open(tester, 'kept');
    expect(answer(tester, 'kept'), contains(en.inviteTreeKeptFloor));
  });

  testWidgets('the title is a heading', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpQuestions(tester, status());
    expect(
      tester.getSemantics(find.text('Questions and answers')),
      containsSemantics(isHeader: true, label: 'Questions and answers'),
    );
    handle.dispose();
  });
}
