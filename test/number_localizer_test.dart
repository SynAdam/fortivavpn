import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/utils/number_localizer.dart';

/// Digit conversion for the locales that do not use western digits.
///
/// A pure function, but one that runs over every number the app shows to
/// a Persian, Arabic or Urdu speaker, which is most of the user base.
void main() {
  group('NumberLocalizer.localizeForLocale', () {
    test('converts every western digit to Persian', () {
      expect(
        NumberLocalizer.localizeForLocale('0123456789', 'fa'),
        '۰۱۲۳۴۵۶۷۸۹',
      );
    });

    test('converts every western digit to Arabic', () {
      expect(
        NumberLocalizer.localizeForLocale('0123456789', 'ar'),
        '٠١٢٣٤٥٦٧٨٩',
      );
    });

    test('Urdu uses the Persian digit set, not the Arabic one', () {
      // Both scripts are written right to left and both are sometimes
      // called "Arabic numerals", but Urdu takes the Eastern Arabic-Indic
      // forms. Mixing them produces text that looks subtly wrong.
      expect(
        NumberLocalizer.localizeForLocale('4567', 'ur'),
        NumberLocalizer.localizeForLocale('4567', 'fa'),
      );
      expect(
        NumberLocalizer.localizeForLocale('4567', 'ur'),
        isNot(NumberLocalizer.localizeForLocale('4567', 'ar')),
      );
    });

    test('leaves locales with western digits untouched', () {
      for (final locale in ['en', 'de', 'fr', 'tr', 'pt', 'ru', 'ja', 'ko']) {
        expect(
          NumberLocalizer.localizeForLocale('42 GB', locale),
          '42 GB',
          reason: 'locale $locale should not have its digits rewritten',
        );
      }
    });

    test('Hindi keeps western digits', () {
      // Devanagari has its own digits, but the app does not map them, and
      // modern Hindi UI conventionally uses western ones. Pinned so the
      // absence is a decision rather than an oversight.
      expect(NumberLocalizer.localizeForLocale('2026', 'hi'), '2026');
    });

    test('an unknown locale is returned unchanged', () {
      expect(NumberLocalizer.localizeForLocale('99', 'xx'), '99');
    });

    test('converts digits embedded in surrounding text', () {
      expect(
        NumberLocalizer.localizeForLocale('12.5 GB / 20 GB', 'fa'),
        '۱۲.۵ GB / ۲۰ GB',
      );
    });

    test('non-digit characters survive, including the separators', () {
      final result = NumberLocalizer.localizeForLocale('1,234.56 ms', 'ar');
      expect(result, contains(','));
      expect(result, contains('.'));
      expect(result, endsWith(' ms'));
      expect(result, isNot(contains('1')));
    });

    test('an empty string stays empty', () {
      expect(NumberLocalizer.localizeForLocale('', 'fa'), '');
    });

    test('text with no digits is returned as-is', () {
      expect(NumberLocalizer.localizeForLocale('Connected', 'fa'), 'Connected');
    });

    test('repeated digits are all converted, not just the first', () {
      expect(NumberLocalizer.localizeForLocale('111', 'fa'), '۱۱۱');
    });

    test('conversion is not applied twice to its own output', () {
      // The maps only cover western digits, so re-running is a no-op.
      // Worth pinning: a map that ever gained a reverse entry would make
      // this silently corrupt every number shown twice.
      final once = NumberLocalizer.localizeForLocale('2026', 'fa');
      expect(NumberLocalizer.localizeForLocale(once, 'fa'), once);
    });
  });

  group('NumberLocalizer.localizeAmountForLocale', () {
    test('Persian, Arabic and Urdu write the momayyez as the decimal mark', () {
      // A full stop next to the ring-shaped Persian zero reads as a stray
      // dot: "۲۰.۰ GB".
      expect(
        NumberLocalizer.localizeAmountForLocale('20.0 GB', 'fa'),
        '۲۰\u066B۰ GB',
      );
      expect(
        NumberLocalizer.localizeAmountForLocale('20.0 GB', 'ar'),
        '٢٠\u066B٠ GB',
      );
      expect(
        NumberLocalizer.localizeAmountForLocale('9.6 GB', 'ur'),
        '۹\u066B۶ GB',
      );
    });

    test('every amount in a line, and only a point between digits', () {
      expect(
        NumberLocalizer.localizeAmountForLocale('1.5 GB of 20.0 GB.', 'fa'),
        '۱\u066B۵ GB of ۲۰\u066B۰ GB.',
      );
      expect(NumberLocalizer.localizeAmountForLocale('512 MB', 'fa'), '۵۱۲ MB');
    });

    test('western digits keep the full stop', () {
      for (final locale in ['en', 'de', 'ru', 'tr', 'hi', 'xx']) {
        expect(
          NumberLocalizer.localizeAmountForLocale('20.0 GB', locale),
          '20.0 GB',
          reason: locale,
        );
      }
    });

    test('a version keeps its dots through localize', () {
      // Versions are not amounts. The splash and Settings show them with
      // dots, and their tests read them so.
      expect(NumberLocalizer.localizeForLocale('1.11.0', 'fa'), '۱.۱۱.۰');
    });

    // One rule for every amount on screen. The quota card and the speed
    // test each had their own copy of it, so the invite screen's amounts
    // kept the full stop.
    test('no code outside NumberLocalizer writes the momayyez', () {
      final offenders = <String>[];
      final files = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .where((f) => !f.path.contains('/l10n/'))
          .where((f) => !f.path.endsWith('utils/number_localizer.dart'));
      for (final file in files) {
        final lines = file.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i].trim();
          if (line.startsWith('//')) continue;
          if (line.contains('\u066B') ||
              line.contains('\\u066B') ||
              line.contains('\\u066b')) {
            offenders.add('${file.path}:${i + 1}');
          }
        }
      }
      expect(offenders, isEmpty);
    });
  });
}
