import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/api/referral_service.dart';
import 'package:fortiva_vpn/core/state/referral_state.dart';
import 'package:fortiva_vpn/l10n/generated/app_localizations.dart';
import 'package:fortiva_vpn/services/invite_share.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/invite_home.dart';
import 'helpers/invite_tree.dart';
import 'helpers/limit_sheet.dart';

/// Under the tree rule the backend sends no next_invite_bytes in two
/// different cases: invites already add the most they can, or the bonus is
/// the part kept from earlier invites and one more friend would not lift it
/// above that. Only the first means invites add no more. The second is the
/// usual state of anyone who invited under the old rule, and they still
/// get the invite offer (backend tests/test_referral_tree_db.py,
/// test_the_status_of_a_device_with_no_one_under_it).
void main() {
  final en = lookupS(const Locale('en'));

  /// The backend's own case: 2 GiB kept, all three pairs open, no next
  /// amount, and the bonus is the kept part.
  Map<String, dynamic> keptCase() {
    final json = treeAnswer(keptBytes: 2 << 30, nextInviteBytes: null)
      ..['bonus_bytes'] = 2 << 30
      ..['invited_count'] = 2
      ..['confirmed_count'] = 2;
    for (final p in json['pairs'] as List) {
      (p as Map)['states'] = ['empty', 'empty'];
      p['now_bytes'] = 0;
    }
    json['levels'] = <Object?>[];
    return json;
  }

  ReferralState held(Map<String, dynamic> json) =>
      heldStatus(ReferralStatus.fromJson(json));

  group('ReferralState', () {
    test('the kept part with no next amount is not "adds no more"', () {
      final state = held(keptCase());
      expect(state.invitesAddNoMore, isFalse);
      expect(state.nextFriendBelowKept, isTrue);
    });

    test('at the most, invites add no more', () {
      final state = held(
        treeAnswer(nextInviteBytes: null)..['bonus_bytes'] = 7 << 30,
      );
      expect(state.invitesAddNoMore, isTrue);
      expect(state.nextFriendBelowKept, isFalse);
    });

    test('a kept part at or above the most still adds no more', () {
      final json = treeAnswer(
        keptBytes: 8 << 30,
        maxBonusBytes: 8 << 30,
        nextInviteBytes: null,
      )..['bonus_bytes'] = 8 << 30;
      final state = held(json);
      expect(state.invitesAddNoMore, isTrue);
      expect(state.nextFriendBelowKept, isFalse);
    });

    test('friends adding more than the kept part with no next amount: no '
        'more', () {
      // The bonus is above the kept part, so the kept part is not why the
      // backend sent no amount.
      final state = held(treeAnswer(nextInviteBytes: null));
      expect(state.invitesAddNoMore, isTrue);
      expect(state.nextFriendBelowKept, isFalse);
    });

    test('a bonus of nothing never reads as "adds the most"', () {
      final json = treeAnswer(nextInviteBytes: null, keptBytes: null)
        ..['bonus_bytes'] = 0;
      expect(held(json).invitesAddNoMore, isFalse);
    });

    test('under today\'s rule nothing changes', () {
      final state = held(oldAnswer());
      expect(state.invitesAddNoMore, isFalse);
      expect(state.nextFriendBelowKept, isFalse);
    });
  });

  group('the limit sheet', () {
    late List<MethodCall> calls;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      calls = [];
      mockTunnel(calls);
      InviteShare.nativeForTest = true;
    });

    tearDown(() {
      InviteShare.nativeForTest = null;
      unmockTunnel();
    });

    testWidgets('still offers Share, and says when friends add again', (
      tester,
    ) async {
      await pumpSheetHost(tester, referrals: held(keptCase()));
      await openSheet(tester);
      expect(find.byKey(const Key('limit-sheet-share')), findsOneWidget);
      expect(find.byKey(const Key('limit-sheet-invites-full')), findsNothing);
      expect(find.text(en.premiumLimitInvitesFull), findsNothing);
      expect(find.text(en.inviteTreeKeptFloor), findsOneWidget);
      // The short link to the story, on one line.
      expect(find.text(en.inviteTreeIntroGuide), findsOneWidget);
      endEvents();
      await inviteHomeDone(tester);
    });
  });

  group('the introduction', () {
    testWidgets('never says invites add the most, and says when friends add '
        'again', (tester) async {
      screenFor(tester);
      await pumpIntro(tester, held(keptCase()));
      for (var page = 0; page < 7; page++) {
        expect(
          find.text(en.premiumLimitInvitesFull),
          findsNothing,
          reason: 'step ${page + 1}',
        );
        if (page < 6) {
          await tester.tap(find.byKey(const Key('invite-tree-intro-next')));
          await tester.pumpAndSettle();
        }
      }
      // Step 7 of 7: the data from friends.
      await tester.tap(find.byKey(const Key('invite-tree-intro-back')));
      await tester.pumpAndSettle();
      expect(find.text(en.inviteTreeKeptFloor), findsOneWidget);
    });
  });
}
