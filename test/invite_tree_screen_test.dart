import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/api/referral_service.dart';

import 'helpers/invite_tree.dart';

/// The invite screen under the tree rule (backend #548): the live bonus,
/// the slots in pairs, what friends give, the next friend, the kept
/// minimum and "How it works", all from the backend's numbers. Under
/// today's rule the screen is as it was.
void main() {
  /// A no-break space, as the screen joins an amount to its unit.
  const nb = ' ';

  group('under the tree rule', () {
    testWidgets('shows the live bonus, the next friend and the kept minimum', (
      tester,
    ) async {
      await pumpInviteScreen(tester, ReferralStatus.fromJson(treeAnswer()));
      expect(find.text('+2.5${nb}GB every day'), findsOneWidget);
      expect(
        find.text(
          'Your bonus lasts while your friends keep using Fortiva. If a '
          'friend stops, it goes down.',
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
          'Your bonus never goes below 1${nb}GB a day, because of friends '
          'you invited before.',
        ),
        findsOneWidget,
      );
      // The next friend is said under the share button, inside its card.
      final share = tester.getRect(find.text('Share invite'));
      final next = tester.getRect(find.byKey(const Key('invite-tree-next')));
      expect(next.top, greaterThan(share.bottom));
      expect(
        tester.getRect(find.byKey(const Key('invite-tree-live'))).top,
        greaterThan(next.bottom),
      );
    });

    testWidgets('draws each pair with its slots, what it gives now and when '
        'full', (tester) async {
      await pumpInviteScreen(tester, ReferralStatus.fromJson(treeAnswer()));
      final card = find.byKey(const Key('invite-tree-pairs'));
      expect(
        find.descendant(of: card, matching: find.text('Your slots')),
        findsOneWidget,
      );

      Finder inPair(int i, Finder f) => find.descendant(
        of: find.byKey(Key('invite-tree-pair-$i')),
        matching: f,
      );
      List<String?> slots(int i) => [
        for (final s in tester.widgetList<Semantics>(
          inPair(
            i,
            find.byWidgetPredicate(
              (w) => w is Semantics && w.properties.label != null,
            ),
          ),
        ))
          s.properties.label,
      ];

      expect(slots(0), ['Active', 'Not active now']);
      expect(inPair(0, find.text('+1${nb}GB a day now')), findsOneWidget);
      expect(
        inPair(0, find.text('+2${nb}GB a day when both are active')),
        findsOneWidget,
      );

      // A full pair already gives its full amount: one line.
      expect(slots(1), ['Active', 'Active']);
      expect(inPair(1, find.text('+1.5${nb}GB a day now')), findsOneWidget);
      expect(inPair(1, find.textContaining('when both')), findsNothing);

      expect(slots(2), ['Open slot', 'Open slot']);
      expect(inPair(2, find.text('Nothing yet')), findsOneWidget);
      expect(
        inPair(2, find.text('+600${nb}MB a day when both are active')),
        findsOneWidget,
      );
    });

    testWidgets('lists what friends give, with people and active', (
      tester,
    ) async {
      await pumpInviteScreen(tester, ReferralStatus.fromJson(treeAnswer()));
      final card = find.byKey(const Key('invite-tree-friends'));
      expect(
        find.descendant(of: card, matching: find.text('Through your slots')),
        findsOneWidget,
      );
      Finder inRow(int i, Finder f) => find.descendant(
        of: find.byKey(Key('invite-tree-friends-$i')),
        matching: f,
      );
      expect(inRow(0, find.text('In your slots')), findsOneWidget);
      expect(inRow(0, find.text('3 people, 3 active')), findsOneWidget);
      expect(inRow(0, find.text('+2.5${nb}GB a day now')), findsOneWidget);
      expect(inRow(1, find.text('In their slots')), findsOneWidget);
      expect(inRow(1, find.text('1 person, 0 active')), findsOneWidget);
      expect(inRow(1, find.text('Nothing yet')), findsOneWidget);
      expect(inRow(2, find.text('3 steps away')), findsOneWidget);
      expect(inRow(2, find.text('2 people, 0 active')), findsOneWidget);
    });

    testWidgets('a duplicate level from the backend draws one row and '
        'never throws', (tester) async {
      final json = treeAnswer()
        ..['levels'] = [
          {'level': 2, 'people': 1, 'active': 0, 'bytes': 0},
          {'level': 1, 'people': 5, 'active': 5, 'bytes': 1 << 30},
          {'level': 1, 'people': 3, 'active': 9, 'bytes': 1 << 30},
          {'level': 1, 'people': 4, 'active': 1, 'bytes': 1 << 30},
        ];
      await pumpInviteScreen(tester, ReferralStatus.fromJson(json));
      expect(tester.takeException(), isNull);
      expect(find.text('In your slots'), findsOneWidget);
      expect(find.text('5 people, 5 active'), findsOneWidget);
      expect(find.text('4 people, 1 active'), findsNothing);
      expect(find.text('In their slots'), findsOneWidget);
    });

    testWidgets('no friends card while nobody is in it', (tester) async {
      final json = treeAnswer()..['levels'] = <Object?>[];
      await pumpInviteScreen(tester, ReferralStatus.fromJson(json));
      expect(find.byKey(const Key('invite-tree-pairs')), findsOneWidget);
      expect(find.byKey(const Key('invite-tree-friends')), findsNothing);
    });

    testWidgets('at the kept minimum it promises no drop and no next friend', (
      tester,
    ) async {
      // The tree gives 2.5 GB, the old rule keeps 3 GB, so the bonus is the
      // 3 GB minimum. A friend who stops changes nothing, and the backend
      // sends no next amount because the next friend changes nothing.
      final json = treeAnswer(nextInviteBytes: null, keptBytes: 3 << 30)
        ..['bonus_bytes'] = 3 << 30;
      final status = ReferralStatus.fromJson(json);
      final levelsTotal = status.levels.fold(0, (n, l) => n + (l.bytes ?? 0));
      expect(status.keptBytes, status.bonusBytes);
      expect(status.keptBytes, greaterThan(levelsTotal));
      await pumpInviteScreen(tester, status);
      expect(find.text('+3${nb}GB every day'), findsOneWidget);
      expect(find.byKey(const Key('invite-tree-live')), findsNothing);
      expect(find.textContaining('goes down'), findsNothing);
      expect(find.byKey(const Key('invite-tree-next')), findsNothing);
      expect(find.textContaining('Your next friend'), findsNothing);
      expect(
        find.text(
          'Your bonus never goes below 3${nb}GB a day, because of friends '
          'you invited before.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('above the kept minimum it says the bonus can go down', (
      tester,
    ) async {
      await pumpInviteScreen(
        tester,
        ReferralStatus.fromJson(treeAnswer(keptBytes: 2 << 30)),
      );
      expect(find.byKey(const Key('invite-tree-live')), findsOneWidget);
      expect(find.byKey(const Key('invite-tree-kept')), findsOneWidget);
      final live = tester.getRect(find.byKey(const Key('invite-tree-live')));
      final kept = tester.getRect(find.byKey(const Key('invite-tree-kept')));
      expect(kept.top, greaterThan(live.bottom));
    });

    testWidgets('a bonus of nothing says nothing goes down', (tester) async {
      final json = treeAnswer(keptBytes: null)..['bonus_bytes'] = 0;
      await pumpInviteScreen(tester, ReferralStatus.fromJson(json));
      expect(find.byKey(const Key('invite-tree-live')), findsNothing);
      expect(find.byKey(const Key('invite-tree-kept')), findsNothing);
    });

    testWidgets('with no slots that can be read, How it works is still the '
        "tree's and names no number of slots", (tester) async {
      for (final pairs in <Object?>[
        <Object?>[],
        null,
        ['x', 1],
      ]) {
        final json = treeAnswer()..['pairs'] = pairs;
        if (pairs == null) json.remove('pairs');
        await pumpInviteScreen(tester, ReferralStatus.fromJson(json));
        expect(json.containsKey('bonus_per_referral_bytes'), isFalse);
        expect(
          find.byKey(const Key('invite-tree-pairs')),
          findsNothing,
          reason: '$pairs',
        );
        expect(
          find.text(
            'Share your code. The first friends who qualify fill your '
            'slots, in pairs.',
          ),
          findsOneWidget,
          reason: '$pairs',
        );
        expect(
          find.textContaining('Share your code. When someone'),
          findsNothing,
          reason: '$pairs',
        );
        expect(
          textsOnScreen(
            tester,
          ).where((t) => RegExp('stays|permanent|forever').hasMatch(t)),
          isEmpty,
          reason: '$pairs',
        );
        expect(find.byKey(const Key('invite-tree-friends')), findsOneWidget);
        expect(find.byKey(const Key('invite-tree-live')), findsOneWidget);
      }
    });

    testWidgets('How it works names the backend numbers in English', (
      tester,
    ) async {
      await pumpInviteScreen(tester, ReferralStatus.fromJson(treeAnswer()));
      for (final line in [
        'Share your code. The first 6 friends who qualify fill your slots, '
            'in pairs.',
        'A pair adds more data when both people in it are active.',
        'When your slots are full, your next friends who qualify take the '
            'next open slots, further from you. They still add data for you, '
            'less the further they are.',
        'Your first pair can also take people you did not invite. They add '
            'data for you in the same way.',
        'A friend is active while they have used Fortiva on at least 2 days '
            'in the last 30 days.',
        'Invites can add up to 7${nb}GB a day.',
      ]) {
        expect(find.text(line), findsOneWidget, reason: line);
      }
      // Today's rule's sentences are gone, the cap that says earn with them.
      expect(
        find.textContaining('Share your code. When someone'),
        findsNothing,
      );
      expect(find.textContaining('earn'), findsNothing);
    });

    testWidgets('How it works in Persian, in Persian digits', (tester) async {
      await pumpInviteScreen(
        tester,
        ReferralStatus.fromJson(treeAnswer()),
        locale: 'fa',
      );
      for (final line in [
        'کدتان را به اشتراک بگذارید. ۶ دوست اولی که واجد شرایط شوند، '
            'جایگاه‌های شما را جفت‌جفت پر می‌کنند.',
        'هر جفت وقتی هر دوی آن‌ها فعال باشند، پاداش بیشتری می‌دهد.',
        'وقتی جایگاه‌های شما پر شود، دوستان بعدی‌تان که واجد شرایط شوند '
            'جایگاه‌های خالی بعدی را می‌گیرند که از شما دورترند. آن‌ها هم به '
            'دیتای شما اضافه می‌کنند، ولی هرچه دورتر باشند، کمتر.',
        'جفت اول شما ممکن است با کسانی پر شود که دعوتشان نکرده‌اید. آن‌ها هم '
            'به همین شکل به دیتای شما اضافه می‌کنند.',
        'هر دوست تا وقتی فعال حساب می‌شود که در ۳۰ روز گذشته، دست‌کم در ۲ '
            'روز از فورتیوا استفاده کرده باشد.',
        'دعوت‌ها می‌توانند تا ۷${nb}GB در روز به دیتای شما اضافه کنند.',
      ]) {
        expect(find.text(line), findsOneWidget, reason: line);
      }
      expect(find.text('از طریق جایگاه‌هایتان'), findsOneWidget);
      expect(find.text('در جایگاه‌های شما'), findsOneWidget);
      expect(find.text('در جایگاه‌های آن‌ها'), findsOneWidget);
      expect(find.text('با ۳ قدم فاصله'), findsOneWidget);
      expect(find.text('فعلاً غیرفعال'), findsWidgets);
      expect(
        find.text(
          'پاداش شما به‌خاطر دوستانی که قبلاً دعوت کرده‌اید، هیچ‌وقت از '
          '۱${nb}GB در روز کمتر نمی‌شود.',
        ),
        findsOneWidget,
      );
      expect(find.text('+۱${nb}GB در روز، اکنون'), findsOneWidget);
      // The code is SelectableText, so it is not among these.
      expect(
        textsOnScreen(tester).where((t) => RegExp('[0-9]').hasMatch(t)),
        isEmpty,
        reason: 'every number is in Persian digits',
      );
    });

    testWidgets('names no number when the backend sends none', (tester) async {
      await pumpInviteScreen(
        tester,
        ReferralStatus.fromJson(
          treeAnswer(
            nextInviteBytes: null,
            keptBytes: 0,
            activeDays: null,
            activeWindowDays: 30,
            maxBonusBytes: null,
          ),
        ),
      );
      expect(
        find.text('A friend is active while they keep using Fortiva.'),
        findsOneWidget,
      );
      expect(
        find.text('There is a daily limit to what invites can add.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('invite-tree-next')), findsNothing);
      expect(find.byKey(const Key('invite-tree-kept')), findsNothing);
      expect(find.byKey(const Key('invite-tree-live')), findsOneWidget);
    });

    // Under the tree rule the bonus goes down when a friend stops, so no
    // text may say it stays. Only the kept bonus from old invites stays.
    for (final (locale, stays) in [
      ('en', RegExp('stays|permanent|forever|always', caseSensitive: false)),
      ('fa', RegExp('می‌ماند|همیشه|دائمی|باقی')),
    ]) {
      testWidgets('[$locale] no tree text says the bonus stays', (
        tester,
      ) async {
        await pumpInviteScreen(
          tester,
          ReferralStatus.fromJson(treeAnswer(keptBytes: null)),
          locale: locale,
        );
        expect(textsOnScreen(tester).where(stays.hasMatch), isEmpty);
      });
    }
  });

  group('the tree strings', () {
    final arbs = {
      for (final f in Directory('lib/l10n').listSync().whereType<File>())
        if (RegExp(r'app_(\w+)\.arb$').firstMatch(f.path) case final m?)
          m[1]!: jsonDecode(f.readAsStringSync()) as Map<String, dynamic>,
    };

    /// Words that say the bonus is kept for good, in each language's own
    /// wording of today's rule ("It stays on your account").
    final staysWords = <String, RegExp>{
      'en': RegExp('stays|permanent|forever', caseSensitive: false),
      'fa': RegExp('همیشه|باقی می‌ماند|دائمی'),
      'ar': RegExp('تبقى في حسابك|دائم'),
      'de': RegExp('dauerhaft|für immer', caseSensitive: false),
      'es': RegExp('se quedan en tu cuenta|para siempre'),
      'fr': RegExp('définitivement|pour toujours'),
      'pt': RegExp('para sempre'),
      'ru': RegExp('навсегда'),
      'uk': RegExp('залишається у вашому обліковому записі|назавжди'),
      'tr': RegExp('hesabında kalır|kalıcı'),
      'id': RegExp('tetap ada di akun|selamanya'),
      'vi': RegExp('được giữ lại trên tài khoản|mãi mãi'),
      'uz': RegExp('hisobingizda saqlanib qoladi|doimiy'),
      'ja': RegExp('そのまま残ります|ずっと'),
      'ko': RegExp('계속 유지됩니다|영구'),
      'zh': RegExp('一直保留|永久'),
      'hi': RegExp('हमेशा'),
      'ur': RegExp('برقرار رہے گا|ہمیشہ'),
    };

    test('every language is checked', () {
      expect(staysWords.keys.toSet(), arbs.keys.toSet());
    });

    for (final lang in staysWords.keys) {
      test('[$lang] no tree text but the kept bonus says the bonus stays', () {
        final arb = arbs[lang]!;
        final hits = [
          for (final e in arb.entries)
            if (e.key.startsWith('inviteTree') &&
                e.key != 'inviteTreeKept' &&
                staysWords[lang]!.hasMatch(e.value as String))
              e.key,
        ];
        expect(hits, isEmpty);
      });
    }

    /// Words the tree text must not use in each language: the word for
    /// level or rank, people placed under or below the user, and paying,
    /// earning, income or wages from them. The text talks about friends
    /// and data instead.
    final levelWords = <String, RegExp>{
      'en': RegExp(
        r'\blevels?\b|\btiers?\b|\bunder\b|below you|\bearn|income|wages?'
        r'|recruit|downline|\bpays?\b',
        caseSensitive: false,
      ),
      'fa': RegExp('سطح|زیر|درآمد'),
      'ar': RegExp('مستو|تحت|يكسب|عمولة'),
      'de': RegExp(
        'Ebene|Stufe|unter dir|unter die|verdien|Einkommen',
        caseSensitive: false,
      ),
      'es': RegExp('nivel|debajo|gana|ingreso', caseSensitive: false),
      'fr': RegExp('niveau|sous les|rapporte|revenu', caseSensitive: false),
      'pt': RegExp(
        'nível|níveis|abaixo das|rende|renda|ganha',
        caseSensitive: false,
      ),
      'ru': RegExp('уров|под тех|доход', caseSensitive: false),
      'uk': RegExp('рівен|рівн|під тих|дохід', caseSensitive: false),
      'tr': RegExp('seviye|kişilerin altına|kazandır', caseSensitive: false),
      'id': RegExp(
        'level|di bawah orang|menghasilkan|penghasilan',
        caseSensitive: false,
      ),
      'vi': RegExp('cấp|xếp dưới|thu nhập', caseSensitive: false),
      'uz': RegExp('daraja|ostiga|daromad', caseSensitive: false),
      'hi': RegExp('स्तर|नीचे|कमा|आय'),
      'ur': RegExp('سطح|نیچے|کما|آمدنی'),
      'ja': RegExp('レベル|段階|下に|収入'),
      'ko': RegExp('단계|레벨|아래에|수입'),
      'zh': RegExp('层|级|下面|收入'),
    };

    test('every language is checked for level words', () {
      expect(levelWords.keys.toSet(), arbs.keys.toSet());
    });

    for (final lang in levelWords.keys) {
      test('[$lang] no tree text talks about levels or people under you', () {
        final arb = arbs[lang]!;
        final hits = [
          for (final e in arb.entries)
            if (e.key.startsWith('inviteTree') &&
                e.value is String &&
                levelWords[lang]!.hasMatch(e.value as String))
              '${e.key}: ${e.value}',
        ];
        expect(hits, isEmpty);
      });
    }
  });

  group('under today\'s rule', () {
    testWidgets('the screen is as it was', (tester) async {
      await pumpInviteScreen(tester, ReferralStatus.fromJson(oldAnswer()));
      expect(find.text('+3${nb}GB every day'), findsOneWidget);
      expect(
        find.text(
          'Share your code. When someone installs the app, enters it, and '
          'uses the VPN on 2 different days, you get 1${nb}GB added to your '
          'daily data. It stays on your account.',
        ),
        findsOneWidget,
      );
      expect(
        find.text('You can earn up to 10${nb}GB a day from invites.'),
        findsOneWidget,
      );
      for (final key in [
        'invite-tree-pairs',
        'invite-tree-friends',
        'invite-tree-next',
        'invite-tree-kept',
        'invite-tree-live',
      ]) {
        expect(find.byKey(Key(key)), findsNothing, reason: key);
      }
      expect(find.textContaining('slots'), findsNothing);
      expect(find.text('Have an invite code?'), findsOneWidget);
    });

    testWidgets('the screen draws the same widgets as before the tree', (
      tester,
    ) async {
      // The same answer with and without the tree keys of an older shape
      // ("rules" missing) draws the same text in the same order.
      await pumpInviteScreen(tester, ReferralStatus.fromJson(oldAnswer()));
      final before = textsOnScreen(tester);
      final withExtras = oldAnswer()
        ..['pairs'] = treeAnswer()['pairs']
        ..['levels'] = treeAnswer()['levels'];
      await pumpInviteScreen(tester, ReferralStatus.fromJson(withExtras));
      expect(textsOnScreen(tester), before);
    });
  });
}
