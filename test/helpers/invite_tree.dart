import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/api/referral_service.dart';
import 'package:fortiva_vpn/core/state/referral_state.dart';
import 'package:fortiva_vpn/l10n/generated/app_localizations.dart';
import 'package:fortiva_vpn/screens/invite_screen.dart';
import 'package:provider/provider.dart';

import 'app_theme.dart';

/// What the invite tree tests share (backend #548). The numbers here are
/// the tests' own, never the backend's start values.

/// A referral answer under the tree rule: one pair with one friend active,
/// one full pair, one empty pair, and three levels: the people in the
/// device's own slots (the 4 in the pairs, 3 of them active), the people in
/// their slots, and people three steps away. Every pair's one-active amount
/// is above nothing, as the backend computes it, and the next friend, who
/// goes into the empty pair, adds that pair's one-active amount.
Map<String, dynamic> treeAnswer({
  Object? nextInviteBytes = 300 << 20,
  Object? keptBytes = 1 << 30,
  Object? activeDays = 2,
  Object? activeWindowDays = 30,
  Object? maxBonusBytes = 7 << 30,
}) => {
  'code': 'AB3D7K',
  'share_url': 'https://fortivavpn.com/i/AB3D7K',
  'invited_count': 5,
  'confirmed_count': 3,
  'bonus_bytes': 5 << 29,
  'max_bonus_bytes': maxBonusBytes,
  'confirm_active_days': 2,
  'claim_window_hours': 72,
  'rules': 'tree',
  'pairs': [
    {
      'states': ['active', 'joined'],
      'full_bytes': 2 << 30,
      'one_bytes': 1 << 30,
      'now_bytes': 1 << 30,
    },
    {
      'states': ['active', 'active'],
      'full_bytes': 3 << 29,
      'one_bytes': 3 << 28,
      'now_bytes': 3 << 29,
    },
    {
      'states': ['empty', 'empty'],
      'full_bytes': 600 << 20,
      'one_bytes': 300 << 20,
      'now_bytes': 0,
    },
  ],
  'levels': [
    {'level': 1, 'people': 4, 'active': 3, 'bytes': 5 << 29},
    {'level': 2, 'people': 1, 'active': 0, 'bytes': 0},
    {'level': 3, 'people': 2, 'active': 0, 'bytes': 0},
  ],
  'next_invite_bytes': nextInviteBytes,
  'kept_bytes': keptBytes,
  'active_days': activeDays,
  'active_window_days': activeWindowDays,
  'max_total_bytes': 10 << 30,
};

/// A referral answer from a backend on today's rule, with every field it
/// sends today.
Map<String, dynamic> oldAnswer() => {
  'code': 'AB3D7K',
  'share_url': 'https://fortivavpn.com/i/AB3D7K',
  'invited_count': 5,
  'confirmed_count': 3,
  'bonus_bytes': 3 << 30,
  'bonus_per_referral_bytes': 1 << 30,
  'max_bonus_bytes': 10 << 30,
  'confirm_active_days': 2,
  'claim_window_hours': 72,
};

/// A referral state that always holds [_fixed] and never loads.
class FixedReferral extends ReferralState {
  FixedReferral(this._fixed);
  final ReferralStatus _fixed;

  @override
  ReferralStatus? get status => _fixed;

  @override
  bool get isLoading => false;

  @override
  Future<void> refresh() async {}
}

/// The invite screen with [status], in [locale], with the app's theme.
/// [size] is the screen; the default is tall enough that every card is
/// laid out.
Future<void> pumpInviteScreen(
  WidgetTester tester,
  ReferralStatus status, {
  String locale = 'en',
  Size size = const Size(400, 3000),
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await tester.pumpWidget(
    ChangeNotifierProvider<ReferralState>.value(
      value: FixedReferral(status),
      child: MaterialApp(
        theme: appThemeFor(Locale(locale)),
        localizationsDelegates: S.localizationsDelegates,
        supportedLocales: S.supportedLocales,
        locale: Locale(locale),
        home: const InviteScreen(),
      ),
    ),
  );
  await tester.pump();
}

/// Every piece of text on screen, in the order it is laid out.
List<String> textsOnScreen(WidgetTester tester) => [
  for (final t in tester.widgetList<Text>(find.byType(Text))) ?t.data,
];

/// The invite screen under the tree rule for [locales], on a small phone
/// and on one with large text: nothing overflows, the two slots of each
/// pair sit on one line, and in a right to left language the first slot
/// is on the right.
void inviteTreeLayoutTests(List<String> locales) {
  for (final (width, scale) in const [(320.0, 1.0), (360.0, 1.3)]) {
    for (final locale in locales) {
      testWidgets('[$locale ${width.toInt()} wide at $scale] the tree screen '
          'fits', (tester) async {
        // Tall, so every card is laid out and checked.
        await pumpInviteScreen(
          tester,
          ReferralStatus.fromJson(treeAnswer()),
          locale: locale,
          size: Size(width, 4000),
          textScale: scale,
        );
        expect(tester.takeException(), isNull);
        for (final key in [
          'invite-tree-pairs',
          'invite-tree-friends',
          'invite-tree-next',
          'invite-tree-live',
          'invite-tree-kept',
        ]) {
          final rect = tester.getRect(find.byKey(Key(key)));
          expect(rect.left, greaterThanOrEqualTo(0), reason: key);
          expect(rect.right, lessThanOrEqualTo(width), reason: key);
        }
        final rtl = const ['fa', 'ar', 'ur'].contains(locale);
        for (var i = 0; i < 3; i++) {
          final marks = find.descendant(
            of: find.byKey(Key('invite-tree-pair-$i')),
            matching: find.byWidgetPredicate(
              (w) => w is Semantics && w.properties.label != null,
            ),
          );
          final first = tester.getRect(marks.at(0));
          final second = tester.getRect(marks.at(1));
          expect(first.top, second.top, reason: 'pair $i');
          expect(
            rtl ? first.left > second.left : first.left < second.left,
            isTrue,
            reason: 'pair $i',
          );
        }
      });
    }
  }
}
