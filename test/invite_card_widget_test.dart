import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/data/models/invite_prompt_rules.dart';
import 'package:fortiva_vpn/l10n/generated/app_localizations.dart';
import 'package:fortiva_vpn/widgets/invite_card.dart';

import 'helpers/invite_home.dart';

/// The invite card itself (clients #271): its reward line and its buttons
/// in both directions. The home screen's layout with the card is in
/// invite_layout_latin_test.dart and invite_layout_rtl_test.dart.
void main() {
  final rules = InvitePromptRules.fromJson(inviteRulesJson)!;

  // Labels as wide as on a phone, not the test font's squares, so whether
  // the buttons fit one row is decided as it would be there.
  setUpAll(() => loadShippedFonts(rtl: false));

  Future<BuildContext> pumpCard(
    WidgetTester tester, {
    String locale = 'en',
    InvitePromptRules? with_,
    double width = 360,
    double scale = 1,
  }) async {
    late BuildContext captured;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: S.localizationsDelegates,
        supportedLocales: S.supportedLocales,
        locale: Locale(locale),
        home: Scaffold(
          body: Builder(
            builder: (context) {
              captured = context;
              final l10n = S.of(context)!;
              return MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: SingleChildScrollView(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: SizedBox(
                      width: width,
                      child: InviteCard(
                        margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                        title: l10n.inviteCardTitle,
                        body: l10n.inviteCardBody,
                        rewardLine: InviteCard.rewardLineFor(
                          context,
                          with_ ?? rules,
                        ),
                        onTarget: (_) {},
                        onClose: () {},
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.pump();
    return captured;
  }

  group('the reward line', () {
    testWidgets('names the days when the backend sends them', (tester) async {
      await pumpCard(tester);
      expect(
        find.textContaining(
          'When your friend starts using Fortiva, you get 3 days of Premium.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('names no number when the backend sends none', (tester) async {
      await pumpCard(
        tester,
        with_: InvitePromptRules.fromJson({
          ...inviteRulesJson,
          'reward_premium_days': null,
        }),
      );
      expect(
        find.textContaining(
          'When your friend starts using Fortiva, you get Premium as a gift.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('is not there at the cap or for a device that cannot earn', (
      tester,
    ) async {
      await pumpCard(
        tester,
        with_: InvitePromptRules.fromJson({...inviteRulesJson, 'earns': false}),
      );
      expect(find.textContaining('Premium'), findsNothing);
      expect(
        find.textContaining('Send your friend the install link'),
        findsOneWidget,
      );
      expect(
        find.text('Is Fortiva working well for you? Send it to a friend'),
        findsOneWidget,
      );
    });

    testWidgets('one day reads as one', (tester) async {
      await pumpCard(
        tester,
        with_: InvitePromptRules.fromJson({
          ...inviteRulesJson,
          'reward_premium_days': 1,
        }),
      );
      expect(
        find.textContaining(
          'When your friend starts using Fortiva, you get 1 day of Premium.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('Persian digits in Persian', (tester) async {
      await pumpCard(tester, locale: 'fa');
      expect(find.textContaining('۳ روز پریمیوم'), findsOneWidget);
    });
  });

  group('the buttons', () {
    final targets = [
      InviteTarget.telegram,
      InviteTarget.whatsapp,
      InviteTarget.copyLink,
      InviteTarget.otherApps,
    ];
    Rect rectOf(WidgetTester tester, InviteTarget t) =>
        tester.getRect(find.byKey(Key('invite-card-${t.name}')));

    testWidgets('run start to end in English', (tester) async {
      await pumpCard(tester);
      expect(find.byKey(const Key('invite-card-one-row')), findsOneWidget);
      final xs = [for (final t in targets) rectOf(tester, t).center.dx];
      expect(xs, orderedEquals([...xs]..sort()));
    });

    for (final locale in ['fa', 'ar', 'ur']) {
      testWidgets('[$locale] Telegram is at the right, icons not mirrored', (
        tester,
      ) async {
        await pumpCard(tester, locale: locale);
        Rect at(InviteTarget t) => rectOf(tester, t);
        // Right to left: Telegram at the right of the first row, and each
        // button left of the one before it in its row.
        final telegram = at(InviteTarget.telegram);
        for (final t in targets.skip(1)) {
          expect(
            telegram.right,
            greaterThanOrEqualTo(at(t).right),
            reason: '$t',
          );
        }
        expect(
          telegram.center.dx,
          greaterThan(at(InviteTarget.whatsapp).center.dx),
        );
        expect(
          at(InviteTarget.copyLink).center.dx,
          greaterThan(at(InviteTarget.otherApps).center.dx),
        );
        expect(telegram.top, lessThanOrEqualTo(at(InviteTarget.otherApps).top));
        for (final icon in tester.widgetList<Icon>(
          find.descendant(
            of: find.byKey(const Key('invite-card')),
            matching: find.byType(Icon),
          ),
        )) {
          if (icon.icon == Icons.close) continue;
          expect(icon.textDirection, TextDirection.ltr, reason: '${icon.icon}');
        }
      });
    }

    testWidgets('are full tap targets in one row, and so is the close '
        'button', (tester) async {
      await pumpCard(tester);
      expect(find.byKey(const Key('invite-card-one-row')), findsOneWidget);
      for (final t in targets) {
        expect(
          rectOf(tester, t).height,
          greaterThanOrEqualTo(48),
          reason: '$t',
        );
      }
      final close = tester.getSize(find.byKey(const Key('invite-card-close')));
      expect(close.width, greaterThanOrEqualTo(48));
      expect(close.height, greaterThanOrEqualTo(48));
    });

    testWidgets('wrap to two rows of two when a label does not fit', (
      tester,
    ) async {
      await pumpCard(tester, locale: 'de', width: 220, scale: 1.3);
      expect(find.byKey(const Key('invite-card-two-rows')), findsOneWidget);
      expect(
        rectOf(tester, InviteTarget.telegram).top,
        rectOf(tester, InviteTarget.whatsapp).top,
      );
      expect(
        rectOf(tester, InviteTarget.copyLink).top,
        greaterThan(rectOf(tester, InviteTarget.telegram).top),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('are full tap targets in two rows too', (tester) async {
      await pumpCard(tester, locale: 'de', width: 220, scale: 1.3);
      expect(find.byKey(const Key('invite-card-two-rows')), findsOneWidget);
      for (final t in targets) {
        expect(
          rectOf(tester, t).height,
          greaterThanOrEqualTo(48),
          reason: '$t',
        );
      }
    });

    testWidgets('stay in one row with a label on two lines where one line '
        'does not fit, all as tall as each other', (tester) async {
      // Russian on a 412dp phone: "Скопировать ссылку" needs two lines.
      await pumpCard(tester, locale: 'ru', width: 412);
      expect(find.byKey(const Key('invite-card-one-row')), findsOneWidget);
      final heights = {for (final t in targets) rectOf(tester, t).height};
      expect(heights, hasLength(1));
      expect(heights.single, greaterThanOrEqualTo(48));
      expect(
        rectOf(tester, InviteTarget.copyLink).top,
        rectOf(tester, InviteTarget.telegram).top,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('the close button covers none of them, even where the line '
        'over them fits on one row', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pumpCard(tester, width: 1100);
      // The line under the title is on one row here.
      expect(
        tester.getSize(find.byKey(const Key('invite-card-body'))).height,
        lessThan(20),
      );
      final close = tester.getRect(find.byKey(const Key('invite-card-close')));
      for (final t in targets) {
        final target = rectOf(tester, t);
        expect(
          target.overlaps(close),
          isFalse,
          reason: '$t at $target, close at $close',
        );
      }
    });

    testWidgets('no brand name but the two messengers, and no state app', (
      tester,
    ) async {
      await pumpCard(tester);
      for (final name in [
        'Eitaa',
        'Rubika',
        'Bale',
        'Soroush',
        'Shad',
        'iGap',
      ]) {
        expect(find.textContaining(name), findsNothing);
      }
    });
  });

  test('the card never opens a state messenger', () {
    // The card's targets are exactly these four.
    expect(InviteTarget.values.map((t) => t.name), [
      'telegram',
      'whatsapp',
      'copyLink',
      'otherApps',
    ]);
  });

  test('the platform channel name is the tunnel channel', () {
    expect(tunnelChannel.name, 'com.vpn.fortivavpn/tunnel');
    expect(
      const MethodChannel('com.vpn.fortivavpn/tunnel').name,
      tunnelChannel.name,
    );
  });
}
