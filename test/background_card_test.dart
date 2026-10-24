import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/l10n/generated/app_localizations.dart';
import 'package:fortiva_vpn/services/notice_pull.dart';
import 'package:fortiva_vpn/widgets/background_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The card that asks the user to let Fortiva run in the background, on
/// phones that stop its background checks (lib/widgets/background_card.dart).
void main() {
  final now = DateTime.utc(2026, 10, 13, 12);
  const plain = BackgroundFacts(brand: 'google', optimized: true);

  group('when the card shows', () {
    test('nothing on a phone that lets the checks run', () {
      expect(
        backgroundReason(
          plain,
          now: now,
          lastCheck: now.subtract(const Duration(minutes: 20)),
        ),
        isNull,
      );
    });

    test('restricted by the user, or by Android', () {
      expect(
        backgroundReason(
          const BackgroundFacts(brand: 'google', restricted: true),
          now: now,
        ),
        BackgroundReason.restricted,
      );
      expect(
        backgroundReason(
          const BackgroundFacts(
            brand: 'samsung',
            bucket: BackgroundFacts.restrictedBucket,
          ),
          now: now,
        ),
        BackgroundReason.restricted,
      );
    });

    test('Data Saver on', () {
      expect(
        backgroundReason(
          const BackgroundFacts(brand: 'google', dataSaver: true),
          now: now,
        ),
        BackgroundReason.dataSaver,
      );
    });

    test('no check for a day, on any phone, Samsung included', () {
      expect(
        backgroundReason(
          const BackgroundFacts(brand: 'samsung', optimized: true),
          now: now,
          lastCheck: now.subtract(const Duration(hours: 25)),
        ),
        BackgroundReason.noRecentCheck,
      );
      expect(
        backgroundReason(
          plain,
          now: now,
          watchSince: now.subtract(const Duration(hours: 25)),
        ),
        BackgroundReason.noRecentCheck,
        reason: 'no check ever since the app first looked',
      );
      expect(
        backgroundReason(plain, now: now, watchSince: now),
        isNull,
        reason: 'a new install has had no time yet',
      );
    });

    test('a gap that began before the phone restarted is not blamed on the '
        'battery settings: nothing runs until the app starts again', () {
      expect(
        backgroundReason(
          BackgroundFacts(
            brand: 'samsung',
            optimized: true,
            bootedAt: now.subtract(const Duration(hours: 2)),
          ),
          now: now,
          lastCheck: now.subtract(const Duration(hours: 50)),
        ),
        isNull,
      );
    });

    test('Xiaomi and the like, once, until the user opens the settings or '
        'closes the card', () {
      const xiaomi = BackgroundFacts(brand: 'xiaomi', optimized: true);
      expect(backgroundReason(xiaomi, now: now), BackgroundReason.strictMaker);
      expect(
        backgroundReason(
          xiaomi,
          now: now,
          openedAt: now.subtract(const Duration(days: 30)),
        ),
        isNull,
      );
      expect(
        backgroundReason(
          const BackgroundFacts(brand: 'xiaomi', optimized: false),
          now: now,
        ),
        isNull,
        reason: 'battery optimization already off',
      );
    });

    test('closed or used: away for a week, then back if still needed', () {
      const restricted = BackgroundFacts(brand: 'google', restricted: true);
      expect(
        backgroundReason(
          restricted,
          now: now,
          hiddenAt: now.subtract(const Duration(days: 6)),
        ),
        isNull,
      );
      expect(
        backgroundReason(
          restricted,
          now: now,
          hiddenAt: now.subtract(const Duration(days: 8)),
        ),
        BackgroundReason.restricted,
      );
    });
  });

  group('the card', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    Future<void> pump(WidgetTester tester, Widget child) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: S.localizationsDelegates,
          supportedLocales: S.supportedLocales,
          locale: const Locale('en'),
          home: Scaffold(body: Column(children: [child])),
        ),
      );
      await tester.pumpAndSettle();
    }

    const text =
        'Your phone may hold back messages from the Fortiva team while the '
        'app is closed. Let Fortiva run in the background so they reach you.';

    testWidgets('Allow opens the phone\'s settings and the card goes', (
      tester,
    ) async {
      var opened = 0;
      await pump(
        tester,
        BackgroundCard(
          shown: () => true,
          now: () => now,
          notificationsOn: () async => true,
          facts: () async =>
              const BackgroundFacts(brand: 'xiaomi', optimized: true),
          open: () async => opened++,
        ),
      );
      expect(find.text(text), findsOneWidget);
      await tester.tap(find.text('Allow'));
      await tester.pumpAndSettle();
      expect(opened, 1);
      expect(find.text(text), findsNothing);
    });

    testWidgets('Data Saver: the card says so, and what to turn on', (
      tester,
    ) async {
      await pump(
        tester,
        BackgroundCard(
          shown: () => true,
          now: () => now,
          notificationsOn: () async => true,
          facts: () async =>
              const BackgroundFacts(brand: 'google', dataSaver: true),
        ),
      );
      expect(
        find.text(
          'Data Saver on your phone may stop messages from the Fortiva team '
          'while the app is closed.',
        ),
        findsOneWidget,
      );
      expect(
        find.text('On the next screen, turn on Unrestricted data.'),
        findsOneWidget,
      );
    });

    testWidgets('Not now closes it for a week', (tester) async {
      await pump(
        tester,
        BackgroundCard(
          shown: () => true,
          now: () => now,
          notificationsOn: () async => true,
          facts: () async =>
              const BackgroundFacts(brand: 'google', dataSaver: true),
        ),
      );
      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();
      expect(find.text(text), findsNothing);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(BackgroundCard.hiddenAtKey), isNotNull);
    });

    testWidgets('nothing while notifications are off: the other card asks '
        'for those first', (tester) async {
      await pump(
        tester,
        BackgroundCard(
          shown: () => true,
          now: () => now,
          notificationsOn: () async => false,
          facts: () async =>
              const BackgroundFacts(brand: 'google', dataSaver: true),
        ),
      );
      expect(find.text(text), findsNothing);
    });

    testWidgets('a phone whose checks ran lately sees nothing', (tester) async {
      SharedPreferences.setMockInitialValues({
        NoticePull.lastCheckKey: now
            .subtract(const Duration(minutes: 30))
            .toIso8601String(),
        BackgroundCard.watchSinceKey: now
            .subtract(const Duration(days: 10))
            .toIso8601String(),
      });
      await pump(
        tester,
        BackgroundCard(
          shown: () => true,
          now: () => now,
          notificationsOn: () async => true,
          facts: () async => plain,
        ),
      );
      expect(find.text(text), findsNothing);
    });
  });
}
