import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/utils/vless_link.dart';

/// A real link as issued by the backend, including the percent-encoded
/// label and the Reality query parameters.
const _real =
    'vless://c1d2e3f4-a5b6-4c7d-8e9f-0a1b2c3d4e5f@198.51.100.202:443'
    '?type=tcp&security=reality&pbk=3xm9PTo&fp=chrome&sni=www.samsung.com'
    '&spx=%2F&sid=d590c3503068fc30&flow=xtls-rprx-vision'
    '#Fortiva%20FI%20Helsinki';

void main() {
  group('VlessLink.label', () {
    test('decodes the fragment the backend set', () {
      expect(VlessLink.label(_real, 0), 'Fortiva FI Helsinki');
    });

    test('falls back to a positional name when there is no fragment', () {
      expect(VlessLink.label('vless://uuid@host:443?x=1', 2), 'Server 3');
    });

    test('falls back when the fragment is empty', () {
      expect(VlessLink.label('vless://uuid@host:443#', 0), 'Server 1');
    });

    test('a malformed escape degrades instead of throwing', () {
      expect(VlessLink.label('vless://uuid@host:443#Bad%ZZ', 0), 'Bad%ZZ');
    });
  });

  group('VlessLink.host', () {
    test('returns host:port without the query string', () {
      expect(VlessLink.host(_real), '198.51.100.202:443');
    });

    test('never exposes the UUID credential', () {
      expect(VlessLink.host(_real).contains('78cf9bd9'), isFalse);
    });

    test('handles a fragment with no query string', () {
      expect(
        VlessLink.host('vless://uuid@node.example.com:443#Label'),
        'node.example.com:443',
      );
    });

    test('returns empty for a link with no authority separator', () {
      expect(VlessLink.host('not-a-link'), '');
    });
  });

  group('VlessLink.parts', () {
    test('reads the bare country code the backend stores today', () {
      final parsed = VlessLink.parts('Fortiva FI Helsinki');
      expect(parsed.region, 'FI');
      expect(parsed.place, 'Helsinki');
    });

    test('reads a flag emoji in the same position', () {
      // The column is two characters wide and holds either form, so a
      // fleet configured with emoji must parse identically.
      final parsed = VlessLink.parts('Fortiva \u{1F1EB}\u{1F1EE} Helsinki');
      expect(parsed.region, 'FI');
      expect(parsed.place, 'Helsinki');
    });

    test('keeps a multi-word place intact', () {
      final parsed = VlessLink.parts('Fortiva DE Frankfurt am Main');
      expect(parsed.region, 'DE');
      expect(parsed.place, 'Frankfurt am Main');
    });

    test('a place beginning with a two-letter word is not a country', () {
      // "Ho" would match a bare two-letter code if case were ignored, and
      // the city would lose its first word on screen.
      final parsed = VlessLink.parts('Fortiva Ho Chi Minh City');
      expect(parsed.region, '');
      expect(parsed.place, 'Ho Chi Minh City');
    });

    test('survives an empty region column', () {
      final parsed = VlessLink.parts('Fortiva  Helsinki');
      expect(parsed.region, '');
      expect(parsed.place, 'Helsinki');
    });

    test('a label with no place still yields the region', () {
      final parsed = VlessLink.parts('Fortiva FI');
      expect(parsed.region, 'FI');
      expect(parsed.place, '');
    });

    test('a positional fallback label carries neither', () {
      final parsed = VlessLink.parts('Server 3');
      expect(parsed.region, '');
      expect(parsed.place, 'Server 3');
    });
  });

  group('VlessLink hostname / port / sni', () {
    test('splits host and port and reads the sni', () {
      expect(VlessLink.hostname(_real), '198.51.100.202');
      expect(VlessLink.port(_real), 443);
      expect(VlessLink.sni(_real), 'www.samsung.com');
    });

    test('defaults the port and tolerates a missing sni', () {
      expect(VlessLink.port('vless://u@example.com?type=tcp'), 443);
      expect(
        VlessLink.hostname('vless://u@example.com?type=tcp'),
        'example.com',
      );
      expect(VlessLink.sni('vless://u@example.com:8443?type=tcp'), isNull);
      expect(VlessLink.port('vless://u@example.com:8443?type=tcp'), 8443);
    });

    test('handles an IPv6 literal', () {
      expect(
        VlessLink.hostname('vless://u@[2001:db8:f21::1]:2053?sni=a.b'),
        '2001:db8:f21::1',
      );
      expect(VlessLink.port('vless://u@[2001:db8:f21::1]:2053?sni=a.b'), 2053);
    });
  });

  group('strategy', () {
    test('reads every knob a censor could be reacting to', () {
      final s = VlessLink.strategy(
        'vless://u@edge.example.com:443'
        '?type=ws&security=tls&sni=edge.example.com&fp=chrome'
        '&alpn=h2&path=%2Fws&host=edge.example.com#Fortiva',
      );
      expect(s['transport'], 'ws');
      expect(s['security'], 'tls');
      expect(s['port'], 443);
      expect(s['sni'], 'edge.example.com');
      expect(s['fp'], 'chrome');
      expect(s['alpn'], 'h2');
      expect(s['path'], '/ws');
    });

    test('a key the link does not set is absent, not null', () {
      final s = VlessLink.strategy('vless://u@a.b?type=tcp&security=reality');
      expect(s.containsKey('fp'), isFalse);
      expect(s.containsKey('alpn'), isFalse);
      expect(s['transport'], 'tcp');
      expect(s['security'], 'reality');
    });

    test('keeps only enough of the Reality key to tell a rotation apart', () {
      final s = VlessLink.strategy(
        'vless://u@a.b?type=tcp&security=reality&pbk=AbCdEfGhIjKlMnOpQrSt',
      );
      expect(s['pbk_prefix'], 'AbCdEfGh');
      expect(s.containsKey('pbk'), isFalse);
    });

    test('a link with no query still yields the defaults', () {
      final s = VlessLink.strategy('vless://u@a.b');
      expect(s['transport'], 'tcp');
      expect(s['security'], 'none');
      expect(s['port'], 443);
    });
  });
}
