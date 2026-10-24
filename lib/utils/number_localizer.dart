import 'package:flutter/material.dart';

class NumberLocalizer {
  static const Map<String, List<String>> _digitMaps = {
    'fa': ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'],
    'ar': ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'],
    'ur': ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'],
  };

  /// Localizes a string containing western digits to the target locale's digits
  static String localize(String input, BuildContext context) {
    try {
      final locale = Localizations.localeOf(context).languageCode;
      return localizeForLocale(input, locale);
    } catch (_) {
      // Fallback if context/locale is not available (though unlikely in UI)
      return input;
    }
  }

  /// Localizes a string for a specific locale code
  static String localizeForLocale(String input, String localeCode) {
    final digits = _digitMaps[localeCode];
    if (digits == null) return input;

    String result = input;
    for (int i = 0; i < 10; i++) {
      result = result.replaceAll('$i', digits[i]);
    }
    return result;
  }

  /// The decimal mark of the languages with their own digits: the
  /// momayyez, U+066B.
  static const String _decimalMark = '\u066B';

  /// A full stop with a western digit on each side.
  static final RegExp _decimalPoint = RegExp(r'(?<=[0-9])\.(?=[0-9])');

  /// Like [localize], for an amount with a decimal point ("20.0 GB"): in
  /// Persian, Arabic and Urdu the point becomes the momayyez as well
  /// ("۲۰٫۰ GB"). Next to the ring-shaped Persian zero a full stop reads as
  /// a stray dot. Only for amounts: a version such as "1.11.0" keeps its
  /// dots, so it goes through [localize].
  ///
  /// The one place this rule lives. Data amounts (QuotaCard.localizedBytes,
  /// the home "used today" line, the invite screen, the redeem dialog) and
  /// the speed test's readings all come through here, so every amount on
  /// screen writes its decimal sign the same way.
  static String localizeAmount(String input, BuildContext context) {
    try {
      final locale = Localizations.localeOf(context).languageCode;
      return localizeAmountForLocale(input, locale);
    } catch (_) {
      return input;
    }
  }

  /// [localizeAmount] for a specific locale code.
  static String localizeAmountForLocale(String input, String localeCode) {
    if (!_digitMaps.containsKey(localeCode)) return input;
    return localizeForLocale(
      input.replaceAll(_decimalPoint, _decimalMark),
      localeCode,
    );
  }
}
