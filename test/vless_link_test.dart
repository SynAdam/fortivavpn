import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/data/models/door_outbound.dart';
import 'package:fortiva_vpn/data/models/server.dart';
import 'package:fortiva_vpn/services/ping_service.dart';
import 'package:fortiva_vpn/utils/shared_link.dart';
import 'package:fortiva_vpn/utils/tls_fragment.dart';
import 'package:fortiva_vpn/utils/vless_link.dart';

/// A real link as issued by the backend, including the percent-encoded
/// label and the Reality query parameters.
const _real =
    'vless://c1d2e3f4-a5b6-4c7d-8e9f-0a1b2c3d4e5f@198.51.100.202:443'
    '?type=tcp&security=reality&pbk=3xm9PTo&fp=chrome&sni=www.samsung.com'
    '&spx=%2F&sid=d590c3503068fc30&flow=xtls-rprx-vision'
    '#Fortiva%20FI%20Helsinki';

const _vmessId = 'c1d2e3f4-a5b6-4c7d-8e9f-0a1b2c3d4e5f';

/// A VMess link in query form, with an '@', and not the base64 JSON of a
/// shared vmess link.
const _vmessQuery =
    'vmess://$_vmessId@203.0.113.7:12345'
    '?type=xhttp&security=none&path=%2Fa1b2&mode=auto'
    '#Fortiva%20%F0%9F%87%AB%F0%9F%87%AE%20Helsinki';

const _vmessPacketUp =
    'vmess://$_vmessId@203.0.113.7:12345'
    '?type=xhttp&security=none&path=%2Fa1b2&mode=packet-up'
    '#Fortiva%20DE%20Frankfurt%20am%20Main';

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

  group('a vmess link in query form', () {
    test('reads as a vless link does, not as base64 JSON', () {
      expect(VlessLink.vmess(_vmessQuery), isNull);
    });

    test('keeps the label the backend set', () {
      expect(
        VlessLink.label(_vmessQuery, 0),
        'Fortiva \u{1F1EB}\u{1F1EE} Helsinki',
      );
      final parsed = VlessLink.parts(VlessLink.label(_vmessQuery, 0));
      expect(parsed.region, 'FI');
      expect(parsed.place, 'Helsinki');
      expect(
        VlessLink.label(_vmessPacketUp, 0),
        'Fortiva DE Frankfurt am Main',
      );
    });

    test('names the address and port it dials, and never the credential', () {
      expect(VlessLink.host(_vmessQuery), '203.0.113.7:12345');
      expect(VlessLink.hostname(_vmessQuery), '203.0.113.7');
      expect(VlessLink.port(_vmessQuery), 12345);
      expect(VlessLink.endpoint(_vmessQuery), '203.0.113.7:12345');
    });

    test('reads its transport, security, path and mode', () {
      expect(VlessLink.transport(_vmessQuery), 'xhttp');
      expect(VlessLink.security(_vmessQuery), 'none');
      expect(VlessLink.param(_vmessQuery, 'path'), '/a1b2');
      expect(VlessLink.param(_vmessQuery, 'mode'), 'auto');
      expect(VlessLink.param(_vmessPacketUp, 'mode'), 'packet-up');
      expect(VlessLink.sni(_vmessQuery), isNull);
    });

    test('its strategy names the settings and not the credential', () {
      final s = VlessLink.strategy(_vmessQuery);
      expect(s, {
        'transport': 'xhttp',
        'security': 'none',
        'port': 12345,
        'mode': 'auto',
        'path': '/a1b2',
      });
      expect('$s'.contains(_vmessId), isFalse);
    });

    test('a door of this link is named by its place', () {
      final door = Server.fromDedicatedPath(
        uri: _vmessQuery,
        door: 'xhttp-test',
        doorLabel: 'Helsinki',
      );
      expect(door.name, 'Helsinki');
      expect(door.city, 'Helsinki');
      expect(door.country, 'Finland');
      expect(door.flagEmoji, '\u{1F1EB}\u{1F1EE}');
      expect(door.isDedicated, isTrue);
      expect(door.id, 'dedicated-203.0.113.7:12345');
      expect(door.pathKey, '203.0.113.7:12345|xhttp-test');
      for (final shown in [door.id, door.name, door.city, door.remark]) {
        expect(shown.contains(_vmessId), isFalse);
      }
    });

    test('the app tests and dials it on Android', () {
      SharedLink.windowsOverride = false;
      addTearDown(() => SharedLink.windowsOverride = null);
      expect(SharedLink.usable(_vmessQuery), isTrue);
      expect(PingService.canTest(_vmessQuery), isTrue);
    });

    test('the Windows core does not read it', () {
      SharedLink.windowsOverride = true;
      addTearDown(() => SharedLink.windowsOverride = null);
      expect(SharedLink.usable(_vmessQuery), isFalse);
      expect(PingService.canTest(_vmessQuery), isFalse);
    });

    test('it is dialled as written, so the door keeps its own outbound', () {
      final sent = TlsFragment.apply(
        _vmessQuery,
        spec: 'tlshello,10-20,1-2',
        android: true,
      );
      expect(sent, _vmessQuery);
      final entry = DoorOutbound.fromPath({
        'outbound': {'tag': 'proxy', 'protocol': 'vmess'},
      });
      DoorOutbounds.adopt({_vmessQuery: entry!});
      addTearDown(() => DoorOutbounds.adopt(const {}));
      expect(DoorOutbounds.nativeFor(_vmessQuery, sent), entry.native);
    });
  });
}
