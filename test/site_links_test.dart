import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/core/state/locale_state.dart';
import 'package:fortiva_vpn/utils/site_links.dart';

void main() {
  group('the Website tile', () {
    // The address of the site's home page in each language it has. A language
    // the site does not have opens the English page.
    const home = {
      'en': 'https://fortivavpn.com/',
      'de': 'https://fortivavpn.com/',
      'ja': 'https://fortivavpn.com/',
      'ko': 'https://fortivavpn.com/ko/',
      'fr': 'https://fortivavpn.com/fr-fr/',
      'ar': 'https://fortivavpn.com/ar-ae/',
      'ru': 'https://fortivavpn.com/ru/',
      'fa': 'https://fortivavpn.com/fa/',
      'tr': 'https://fortivavpn.com/tr/',
      'hi': 'https://fortivavpn.com/hi/',
      'ur': 'https://fortivavpn.com/ur/',
      'pt': 'https://fortivavpn.com/pt-br/',
      'es': 'https://fortivavpn.com/es/',
      'id': 'https://fortivavpn.com/id/',
      'vi': 'https://fortivavpn.com/vi/',
      'uk': 'https://fortivavpn.com/uk/',
      'uz': 'https://fortivavpn.com/uz/',
      'zh': 'https://fortivavpn.com/zh-hans/',
    };

    test('names every language of the app', () {
      expect(home.keys.toSet(), LocaleState.supportedLanguages.keys.toSet());
    });

    for (final MapEntry(key: code, value: url) in home.entries) {
      test('$code opens $url', () {
        expect(sitePage('/', code).toString(), url);
      });
    }

    test('a language the app does not know opens the English page', () {
      expect(sitePage('/', 'sv').toString(), 'https://fortivavpn.com/');
    });
  });

  group('a page the site has only in English and Persian', () {
    test('Persian opens the Persian page under /fa/', () {
      expect(
        sitePage('/privacy', 'fa').toString(),
        'https://fortivavpn.com/fa/privacy',
      );
    });

    test('every other language opens the English page', () {
      for (final code in LocaleState.supportedLanguages.keys) {
        if (code == 'fa') continue;
        expect(
          sitePage('/privacy', code).toString(),
          'https://fortivavpn.com/privacy',
          reason: code,
        );
      }
    });
  });
}
