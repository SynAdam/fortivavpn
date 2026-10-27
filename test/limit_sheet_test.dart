import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/api/referral_service.dart';
import 'package:fortiva_vpn/core/form_factor.dart';
import 'package:fortiva_vpn/core/state/invite_events.dart';
import 'package:fortiva_vpn/core/state/invite_prompt.dart';
import 'package:fortiva_vpn/l10n/generated/app_localizations.dart';
import 'package:fortiva_vpn/screens/invite_screen.dart';
import 'package:fortiva_vpn/screens/invite_tree_intro_screen.dart';
import 'package:fortiva_vpn/services/invite_share.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/invite_home.dart';
import 'helpers/invite_tree.dart';
import 'helpers/limit_sheet.dart';

/// The limit sheet once the daily data is used up: while invites can still
/// add data it leads with an invite card that shares from the sheet itself,
/// with Premium after it as an outlined button. Every amount on it is the
/// backend's, under either invite rule.
void main() {
  /// A no-break space, as the sheet joins an amount to its unit.
  const nb = ' ';
  final en = lookupS(const Locale('en'));
  final card = find.byKey(const Key('limit-sheet-invite-card'));
  final share = find.byKey(const Key('limit-sheet-share'));
  final premium = find.byKey(const Key('limit-sheet-premium'));
  final sheet = find.byType(BottomSheet);
  late List<MethodCall> calls;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    calls = [];
    mockTunnel(calls);
    InviteShare.nativeForTest = true;
  });

  tearDown(() {
    InviteShare.nativeForTest = null;
    FormFactor.isTvForTest = false;
    unmockTunnel();
  });

  ReferralStatus status(Map<String, dynamic> json) =>
      ReferralStatus.fromJson(json);

  List<String> wires(InviteEvents events) => [
    for (final e in events.queued) '${e['surface']}/${e['action']}',
  ];

  Iterable<MethodCall> shares() =>
      calls.where((c) => c.method == 'shareInvite');

  Future<void> done(WidgetTester tester) async {
    endEvents();
    await inviteHomeDone(tester);
  }

  group('the invite-led sheet', () {
    testWidgets('puts the invite card before Premium, with Share its one '
        'filled button and Premium outlined', (tester) async {
      await pumpSheetHost(tester, referrals: heldStatus(status(treeAnswer())));
      await openSheet(tester);
      expect(card, findsOneWidget);
      expect(
        tester.getRect(card).bottom,
        lessThan(tester.getRect(premium).top),
      );
      final filled = find.descendant(
        of: sheet,
        matching: find.byWidgetPredicate((w) => w is FilledButton),
      );
      expect(filled, findsOneWidget);
      expect(
        find.descendant(of: filled, matching: find.text('Share invite')),
        findsOneWidget,
      );
      expect(tester.widget(premium), isA<OutlinedButton>());
      // The header says the wait, in one block.
      expect(find.text(en.premiumLimitSheetTitle), findsOneWidget);
      expect(find.byKey(const Key('limit-sheet-reset')), findsOneWidget);
      expect(find.text(en.premiumLimitWait), findsNothing);
      await done(tester);
    });

    testWidgets('without Premium it has the card and no Premium button', (
      tester,
    ) async {
      await pumpSheetHost(
        tester,
        referrals: heldStatus(status(treeAnswer())),
        premium: false,
      );
      await openSheet(tester);
      expect(card, findsOneWidget);
      expect(premium, findsNothing);
      await done(tester);
    });

    for (final (name, json) in [
      ('today\'s rule at the most', oldAnswer()..['bonus_bytes'] = 10 << 30),
      ('the tree with no next amount', treeAnswer(nextInviteBytes: null)),
    ]) {
      testWidgets('once invites add no more ($name) it has no card and '
          'Premium is filled', (tester) async {
        await pumpSheetHost(tester, referrals: heldStatus(status(json)));
        await openSheet(tester);
        expect(card, findsNothing);
        expect(share, findsNothing);
        expect(tester.widget(premium), isA<FilledButton>());
        await done(tester);
      });
    }

    testWidgets('with invites off, on a TV, or with no invite state, it is '
        'the plain sheet', (tester) async {
      await pumpSheetHost(
        tester,
        referrals: heldStatus(status(treeAnswer())),
        invitesOn: false,
      );
      await openSheet(tester);
      expect(card, findsNothing);
      await done(tester);

      FormFactor.isTvForTest = true;
      await pumpSheetHost(tester, referrals: heldStatus(status(treeAnswer())));
      await openSheet(tester);
      expect(card, findsNothing);
      await done(tester);
      FormFactor.isTvForTest = false;

      await pumpSheetHost(tester);
      await openSheet(tester);
      expect(card, findsNothing);
      expect(tester.widget(premium), isA<FilledButton>());
      await done(tester);
    });
  });

  group('the amount line', () {
    Future<void> expectLine(
      WidgetTester tester,
      Map<String, dynamic> json,
      String line,
    ) async {
      await pumpSheetHost(tester, referrals: heldStatus(status(json)));
      await openSheet(tester);
      expect(find.text(line), findsOneWidget, reason: line);
      await done(tester);
    }

    testWidgets('under the tree it names the next friend\'s amount', (
      tester,
    ) async {
      await expectLine(
        tester,
        treeAnswer(),
        'Your next friend adds 300${nb}MB a day once they qualify and are '
        "active. It does not add to today's data.",
      );
    });

    testWidgets('under today\'s rule it names the amount and the days', (
      tester,
    ) async {
      await expectLine(
        tester,
        oldAnswer(),
        'Your next friend adds 1${nb}GB a day once they have used Fortiva on '
        "2 different days. It does not add to today's data.",
      );
    });

    testWidgets('under today\'s rule with no days it names no days', (
      tester,
    ) async {
      await expectLine(
        tester,
        oldAnswer()..remove('confirm_active_days'),
        'Your next friend adds 1${nb}GB a day once they have used Fortiva '
        "for a while. It does not add to today's data.",
      );
    });

    testWidgets('under today\'s rule it never names more than the room left', (
      tester,
    ) async {
      await expectLine(
        tester,
        oldAnswer()..['bonus_bytes'] = (10 << 30) - (512 << 20),
        'Your next friend adds 512${nb}MB a day once they have used Fortiva '
        "on 2 different days. It does not add to today's data.",
      );
    });

    testWidgets('with no amount it names no number', (tester) async {
      await expectLine(
        tester,
        oldAnswer()..remove('bonus_per_referral_bytes'),
        en.premiumLimitInviteNoAmount,
      );
    });

    testWidgets('while the status loads it names no number, and fills in '
        'when it lands', (tester) async {
      final backend = ReferralBackend(answer: treeAnswer())
        ..gate = Completer<void>();
      await pumpSheetHost(tester, referrals: backend.state);
      await tester.tap(find.byKey(const Key('open-sheet')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(card, findsOneWidget);
      expect(find.text(en.premiumLimitInviteNoAmount), findsOneWidget);
      // The tree link waits for a tree status.
      expect(find.byKey(const Key('limit-sheet-intro')), findsNothing);
      backend.gate!.complete();
      await tester.pumpAndSettle();
      expect(find.textContaining('300${nb}MB'), findsOneWidget);
      expect(find.byKey(const Key('limit-sheet-intro')), findsOneWidget);
      await done(tester);
    });

    testWidgets('in Persian it is in Persian digits', (tester) async {
      await pumpSheetHost(
        tester,
        referrals: heldStatus(status(oldAnswer())),
        locale: 'fa',
      );
      await openSheet(tester);
      final texts = allTexts(tester);
      expect(texts.where((t) => RegExp('[0-9]').hasMatch(t)), isEmpty);
      expect(texts.where((t) => t.contains('۱${nb}GB')), hasLength(1));
      await done(tester);
    });
  });

  group('the tree introduction link', () {
    testWidgets('shows only for a loaded tree status, and opens the story', (
      tester,
    ) async {
      await pumpSheetHost(tester, referrals: heldStatus(status(oldAnswer())));
      await openSheet(tester);
      expect(find.byKey(const Key('limit-sheet-intro')), findsNothing);
      await done(tester);

      final events = keptEvents();
      await pumpSheetHost(
        tester,
        referrals: heldStatus(status(treeAnswer())),
        events: events,
      );
      await openSheet(tester);
      await tester.tap(find.byKey(const Key('limit-sheet-intro')));
      await tester.pumpAndSettle();
      expect(sheet, findsNothing);
      expect(find.byType(InviteTreeIntroScreen), findsOneWidget);
      expect(wires(events), ['limit_sheet_offer/shown', 'tree_intro/shown']);
      await done(tester);
    });
  });

  group('Share', () {
    testWidgets('opening with no status starts the load and does not wait '
        'for it', (tester) async {
      final backend = ReferralBackend(answer: treeAnswer())
        ..gate = Completer<void>();
      await pumpSheetHost(tester, referrals: backend.state);
      await tester.tap(find.byKey(const Key('open-sheet')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(sheet, findsOneWidget);
      expect(backend.reads, 1);
      backend.gate!.complete();
      await tester.pumpAndSettle();
      await done(tester);
    });

    testWidgets('a tap during that load waits for it, then shares, with one '
        'read', (tester) async {
      final backend = ReferralBackend(answer: treeAnswer())
        ..gate = Completer<void>();
      final events = keptEvents();
      await pumpSheetHost(tester, referrals: backend.state, events: events);
      await tester.tap(find.byKey(const Key('open-sheet')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(share);
      await tester.pump();
      expect(
        find.descendant(
          of: share,
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );
      expect(shares(), isEmpty);
      backend.gate!.complete();
      await tester.pumpAndSettle();
      expect(backend.reads, 1);
      final sent = shares().single.arguments as Map;
      expect(sent['text'], contains('https://fortivavpn.com/i/AB3D7K'));
      expect(sent['text'], isNot(contains('s=card')));
      expect(wires(events), [
        'limit_sheet_offer/shown',
        'limit_sheet_offer/other_apps',
      ]);
      await done(tester);
    });

    testWidgets('a failed load says so inside the sheet', (tester) async {
      final backend = ReferralBackend();
      await pumpSheetHost(tester, referrals: backend.state);
      await openSheet(tester);
      expect(find.byKey(const Key('limit-sheet-error')), findsNothing);
      await tester.tap(share);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('limit-sheet-error')), findsOneWidget);
      expect(find.text(en.inviteLoadFailed), findsOneWidget);
      expect(shares(), isEmpty);
      expect(sheet, findsOneWidget);
      await done(tester);
    });

    testWidgets('after a share the sheet stays open and offers another, and '
        'the invite card is ended', (tester) async {
      final events = keptEvents();
      final prompt = InvitePrompt();
      await pumpSheetHost(
        tester,
        referrals: heldStatus(status(treeAnswer())),
        events: events,
        prompt: prompt,
      );
      await openSheet(tester);
      expect(find.byKey(const Key('limit-sheet-pair-line')), findsNothing);
      await tester.tap(share);
      await tester.pumpAndSettle();
      expect(sheet, findsOneWidget);
      expect(find.text(en.premiumLimitShareAgain), findsOneWidget);
      expect(find.byKey(const Key('limit-sheet-pair-line')), findsOneWidget);
      final prefs = await SharedPreferences.getInstance();
      expect(
        (jsonDecode(prefs.getString(InvitePrompt.inviteStateKey)!)
            as Map)['done'],
        isTrue,
      );
      // Closed after a share: not a dismissal.
      await tester.tap(find.byKey(const Key('limit-sheet-not-now')));
      await tester.pumpAndSettle();
      expect(wires(events), [
        'limit_sheet_offer/shown',
        'limit_sheet_offer/other_apps',
      ]);
      await done(tester);
    });

    testWidgets('a share that opened nothing changes nothing', (tester) async {
      unmockTunnel();
      mockTunnel(calls, share: 'none');
      final events = keptEvents();
      await pumpSheetHost(
        tester,
        referrals: heldStatus(status(oldAnswer())),
        events: events,
      );
      await openSheet(tester);
      await tester.tap(share);
      await tester.pumpAndSettle();
      expect(find.text(en.inviteShareAction), findsOneWidget);
      expect(wires(events), ['limit_sheet_offer/shown']);
      await done(tester);
    });

    testWidgets('a status that arrives saying invites add no more leaves one '
        'line, and Premium keeps its look', (tester) async {
      final backend = ReferralBackend(answer: treeAnswer(nextInviteBytes: null))
        ..gate = Completer<void>();
      await pumpSheetHost(tester, referrals: backend.state);
      await tester.tap(find.byKey(const Key('open-sheet')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(share, findsOneWidget);
      expect(tester.widget(premium), isA<OutlinedButton>());
      backend.gate!.complete();
      await tester.pumpAndSettle();
      expect(card, findsOneWidget);
      expect(find.text(en.premiumLimitInvitesFull), findsOneWidget);
      expect(share, findsNothing);
      expect(find.byKey(const Key('limit-sheet-invites')), findsNothing);
      expect(tester.widget(premium), isA<OutlinedButton>());
      await done(tester);
    });
  });

  group('events', () {
    testWidgets('closing with no share is a dismissal, Premium included', (
      tester,
    ) async {
      for (final close in ['not now', 'premium']) {
        final events = keptEvents();
        await pumpSheetHost(
          tester,
          referrals: heldStatus(status(treeAnswer())),
          events: events,
        );
        await openSheet(tester);
        await tester.tap(
          close == 'premium'
              ? premium
              : find.byKey(const Key('limit-sheet-not-now')),
        );
        await tester.pumpAndSettle();
        expect(wires(events), [
          'limit_sheet_offer/shown',
          'limit_sheet_offer/dismissed',
        ], reason: close);
        await done(tester);
      }
    });

    testWidgets('See your invites opens the invite screen, which notes '
        'limit_sheet as before', (tester) async {
      final events = keptEvents();
      await pumpSheetHost(
        tester,
        referrals: heldStatus(status(oldAnswer())),
        events: events,
      );
      await openSheet(tester);
      await tester.tap(find.byKey(const Key('limit-sheet-invites')));
      await tester.pumpAndSettle();
      expect(find.byType(InviteScreen), findsOneWidget);
      expect(wires(events), ['limit_sheet_offer/shown', 'limit_sheet/shown']);
      await done(tester);
    });

    testWidgets('the plain sheet notes no invite event', (tester) async {
      final events = keptEvents();
      await pumpSheetHost(
        tester,
        referrals: heldStatus(status(oldAnswer()..['bonus_bytes'] = 10 << 30)),
        events: events,
      );
      await openSheet(tester);
      await tester.tap(find.byKey(const Key('limit-sheet-not-now')));
      await tester.pumpAndSettle();
      expect(wires(events), isEmpty);
      await done(tester);
    });
  });

  group('motion', () {
    testWidgets('the drawing plays once and comes to rest', (tester) async {
      await pumpSheetHost(tester, referrals: heldStatus(status(treeAnswer())));
      await openSheet(tester);
      expect(find.byKey(const Key('limit-sheet-drawing')), findsOneWidget);
      expect(tester.binding.hasScheduledFrame, isFalse);
      await done(tester);
    });

    testWidgets('a short screen or large text leaves the drawing out', (
      tester,
    ) async {
      screenFor(tester, size: const Size(360, 560));
      await pumpSheetHost(tester, referrals: heldStatus(status(treeAnswer())));
      await openSheet(tester);
      expect(find.byKey(const Key('limit-sheet-drawing')), findsNothing);
      await done(tester);

      screenFor(tester, textScale: 1.3);
      await pumpSheetHost(tester, referrals: heldStatus(status(treeAnswer())));
      await openSheet(tester);
      expect(find.byKey(const Key('limit-sheet-drawing')), findsNothing);
      await done(tester);
    });

    testWidgets('under reduced motion nothing moves', (tester) async {
      screenFor(tester, reduced: true);
      await pumpSheetHost(tester, referrals: heldStatus(status(treeAnswer())));
      await tester.tap(find.byKey(const Key('open-sheet')));
      await tester.pumpAndSettle();
      expect(tester.binding.hasScheduledFrame, isFalse);
      await done(tester);
    });
  });
}
