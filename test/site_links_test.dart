import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/utils/site_links.dart';

void main() {
  test('Persian opens the Persian pages under /fa/', () {
    expect(
      sitePage('/privacy', 'fa').toString(),
      'https://fortivavpn.com/fa/privacy',
    );
    expect(sitePage('/', 'fa').toString(), 'https://fortivavpn.com/fa/');
  });

  test('every other language opens the English pages at the root', () {
    for (final code in ['en', 'ar', 'ru', 'de', 'zh']) {
      expect(
        sitePage('/privacy', code).toString(),
        'https://fortivavpn.com/privacy',
      );
      expect(sitePage('/', code).toString(), 'https://fortivavpn.com/');
    }
  });
}
