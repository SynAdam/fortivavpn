import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/data/models/ip_info.dart';

/// The IP check used to call ip-api.com over plain HTTP, which handed a
/// VPN user's real address to a third party. Guideline 5.4 forbids that,
/// and our own privacy policy already said we did not do it. It reads our
/// backend now, which answers with less, so these pin that "less" renders
/// as absent rather than as "Unknown" and "0.0, 0.0".
void main() {
  group('IpInfo.fromBackend', () {
    test('resolves the country code to a name and a flag', () {
      final info = IpInfo.fromBackend({
        'ip': '198.51.100.202',
        'country': 'FI',
      });
      expect(info.ip, '198.51.100.202');
      expect(info.countryCode, 'FI');
      expect(info.country, 'Finland');
      expect(info.flagEmoji, '\u{1F1EB}\u{1F1EE}');
    });

    test('leaves the fields the backend does not report empty', () {
      final info = IpInfo.fromBackend({'ip': '1.2.3.4', 'country': 'DE'});
      expect(info.city, isEmpty);
      expect(info.isp, isEmpty);
      expect(info.org, isEmpty);
      expect(info.timezone, isEmpty);
      expect(info.lat, 0);
      expect(info.lon, 0);
    });

    test('an unmapped code stands in for itself rather than blanking', () {
      expect(
        IpInfo.fromBackend({'ip': '1.2.3.4', 'country': 'NG'}).country,
        'NG',
      );
    });

    test('a response missing both fields still yields a usable object', () {
      final info = IpInfo.fromBackend({});
      expect(info.ip, 'Unknown');
      expect(info.country, isEmpty);
      expect(info.flagEmoji, '\u{1F30D}');
    });
  });
}
