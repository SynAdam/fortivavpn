import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/l10n/generated/app_localizations.dart';
import 'package:fortiva_vpn/utils/app_date.dart';

/// Dates in Persian are written on the Iranian calendar, which is what
/// people who read the app in Persian use. The date helper used to know
/// only the Gregorian calendar, so the Premium screen said "۸ نوامبر ۲۰۲۶"
/// where a Persian reader expects ۱۷ آبان ۱۴۰۵. Every other language keeps
/// the date its locale writes.

/// [date] as appDate writes it in [language], drawn in a real widget tree.
Future<String> _shown(
  WidgetTester tester,
  String language,
  DateTime date,
) async {
  late String text;
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: S.localizationsDelegates,
      supportedLocales: S.supportedLocales,
      locale: Locale(language),
      home: Builder(
        builder: (context) {
          text = appDate(context, date);
          return const SizedBox();
        },
      ),
    ),
  );
  return text;
}

void main() {
  group('toJalali', () {
    for (final (gregorian, jalali) in [
      // The cases the build spec names.
      ((2026, 11, 7), (1405, 8, 16)),
      ((2026, 11, 8), (1405, 8, 17)),
      ((2026, 3, 21), (1405, 1, 1)),
      ((2026, 3, 20), (1404, 12, 29)),
      // 1403 is a leap year: Esfand has a thirtieth day.
      ((2025, 3, 20), (1403, 12, 30)),
      // Nowruz on 20 March, and the day before it.
      ((2024, 3, 20), (1403, 1, 1)),
      ((2024, 3, 19), (1402, 12, 29)),
      // The first day of the seventh month, where months turn to 30 days.
      ((2025, 9, 23), (1404, 7, 1)),
      ((2025, 9, 22), (1404, 6, 31)),
      // New Year's Day in the middle of Dey.
      ((2026, 1, 1), (1404, 10, 11)),
      // A Gregorian leap day.
      ((2028, 2, 29), (1406, 12, 10)),
    ]) {
      test('$gregorian is $jalali', () {
        final (gy, gm, gd) = gregorian;
        final (jy, jm, jd) = jalali;
        expect(toJalali(gy, gm, gd), (year: jy, month: jm, day: jd));
      });
    }

    test('every day of a span of years follows the one before it', () {
      // Day by day from 1395 to 1415: the day goes up by one, or the month
      // turns over to day one, or the year does at Nowruz. Months 1 to 6
      // end on 31, 7 to 11 on 30, and 12 on 29 or 30.
      var day = DateTime.utc(2016, 3, 20);
      var before = toJalali(day.year, day.month, day.day);
      expect(before, (year: 1395, month: 1, day: 1));
      while (day.year < 2036) {
        day = day.add(const Duration(hours: 24));
        final now = toJalali(day.year, day.month, day.day);
        if (now.day != 1) {
          expect(now, (
            year: before.year,
            month: before.month,
            day: before.day + 1,
          ));
          before = now;
          continue;
        }
        final length = before.month <= 6
            ? 31
            : before.month <= 11
            ? 30
            : null;
        if (length != null) expect(before.day, length, reason: '$before');
        if (before.month == 12) {
          expect(before.day, anyOf(29, 30), reason: '$before');
          expect(now, (year: before.year + 1, month: 1, day: 1));
        } else {
          expect(now, (year: before.year, month: before.month + 1, day: 1));
        }
        before = now;
      }
    });
  });

  group('appDate', () {
    testWidgets('Persian is on the Iranian calendar, in Persian digits', (
      tester,
    ) async {
      // Noon UTC is the same calendar day in every time zone a test runs in.
      expect(
        await _shown(tester, 'fa', DateTime.utc(2026, 11, 8, 12)),
        '۱۷ آبان ۱۴۰۵',
      );
      expect(
        await _shown(tester, 'fa', DateTime.utc(2026, 11, 7, 12)),
        '۱۶ آبان ۱۴۰۵',
      );
      expect(
        await _shown(tester, 'fa', DateTime.utc(2026, 3, 21, 12)),
        '۱ فروردین ۱۴۰۵',
      );
      expect(
        await _shown(tester, 'fa', DateTime.utc(2026, 3, 20, 12)),
        '۲۹ اسفند ۱۴۰۴',
      );
      expect(
        await _shown(tester, 'fa', DateTime.utc(2025, 3, 20, 12)),
        '۳۰ اسفند ۱۴۰۳',
      );
    });

    testWidgets('English keeps the Gregorian date', (tester) async {
      expect(
        await _shown(tester, 'en', DateTime.utc(2026, 11, 8, 12)),
        'Nov 8, 2026',
      );
    });

    testWidgets('Arabic and Urdu keep the Gregorian calendar', (tester) async {
      for (final language in ['ar', 'ur']) {
        final text = await _shown(tester, language, DateTime.utc(2026, 11, 8));
        expect(text, isNot(contains('آبان')), reason: language);
      }
    });
  });
}
