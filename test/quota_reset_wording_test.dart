import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The daily data "resets"; it never "fills up". On 2026-10-09 a user whose
/// connect failed saw a full 21 GB bar next to «تا ۲۲ ساعت دیگر پر می‌شود»
/// ("fills up in 22 hours") and took it to mean they had to wait 22 hours
/// to use the app. Each language below had a word for filling up or
/// recharging in these strings. Arabic, Russian and Turkish say "renews",
/// which reads correctly next to a full bar.
const _keys = [
  'quotaResetsShortly',
  'quotaResetsInHours',
  'quotaResetsInMinutes',
  'myServersBlockedWait',
  'premiumLimitWait',
];

final _fillWords = <String, RegExp>{
  'en': RegExp('refill|top.?up', caseSensitive: false),
  'fa': RegExp('پر[‌ ]?(می|شود|بشه|میشه)|شارژ'),
  'de': RegExp('füll', caseSensitive: false),
  'fr': RegExp('recharg', caseSensitive: false),
  'pt': RegExp('recarreg|recarga', caseSensitive: false),
  'ru': RegExp('пополн', caseSensitive: false),
  'hi': RegExp('भर'),
  'ur': RegExp('بھر'),
  'ko': RegExp('충전|채워'),
  'ja': RegExp('回復'),
  'es': RegExp('recarg|rellen|llen', caseSensitive: false),
  'id': RegExp('isi ulang|terisi|diisi|mengisi|penuh', caseSensitive: false),
  'zh': RegExp('充值|填满|充满|补满|恢复|加满|续满'),
  'uk': RegExp('поповн|наповн', caseSensitive: false),
  'uz': RegExp("to[\u02bb\u02bc']ld|toldir", caseSensitive: false),
  'vi': RegExp('nạp|đầy', caseSensitive: false),
};

void main() {
  for (final MapEntry(key: lang, value: banned) in _fillWords.entries) {
    test('the $lang strings say the daily data resets, not fills up', () {
      final arb =
          jsonDecode(File('lib/l10n/app_$lang.arb').readAsStringSync())
              as Map<String, dynamic>;
      for (final key in _keys) {
        final value = arb[key] as String?;
        expect(value, isNotNull, reason: '$key is missing in app_$lang.arb');
        expect(
          banned.hasMatch(value!),
          isFalse,
          reason: '$key [$lang]: $value',
        );
      }
    });
  }

  test('the Persian time line says ریست', () {
    final arb =
        jsonDecode(File('lib/l10n/app_fa.arb').readAsStringSync())
            as Map<String, dynamic>;
    for (final key in _keys.take(3)) {
      expect(arb[key], contains('ریست'), reason: key);
    }
  });
}
