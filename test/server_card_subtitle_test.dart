import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/data/models/server.dart';
import 'package:fortiva_vpn/widgets/server_card.dart';

/// The second line of a Locations tile. For a community link it says how
/// the link is secured and on which port, and never its host: a raw
/// address or someone else's hostname is nothing a user can act on, and
/// it is what a screenshot of the list must not show.
void main() {
  group('ServerCard.subtitleFor community links', () {
    test('security and port, never the host', () {
      final server = Server.fromConnectionUri(
        'vless://uuid@198.51.100.201:443?type=tcp&security=reality'
        '#\u{1F1E9}\u{1F1EA} 12 | @chan',
      );
      expect(server.name, 'Germany');
      expect(ServerCard.subtitleFor(server), 'REALITY · 443');
    });

    test('no hostname either, when the link has no label', () {
      final server = Server.fromConnectionUri(
        'vless://uuid@example.com:8443?security=tls',
      );
      expect(ServerCard.subtitleFor(server), 'TLS · 8443');
      expect(ServerCard.subtitleFor(server), isNot(contains('example.com')));
    });

    test('names the transport when there is no security', () {
      final server = Server.fromConnectionUri(
        'vless://uuid@1.2.3.4:80?type=ws#\u{1F1FA}\u{1F1F8}',
      );
      expect(ServerCard.subtitleFor(server), 'WS · 80');
    });

    test('defaults to tcp and 443 when the link says nothing', () {
      final server = Server.fromConnectionUri('vless://uuid@1.2.3.4#x');
      expect(ServerCard.subtitleFor(server), 'TCP · 443');
    });
  });

  group('ServerCard.subtitleFor our servers', () {
    const base = Server(
      id: '7',
      name: 'DE-Falkenstein',
      country: 'Germany',
      city: 'Falkenstein',
      connectionUri: 'vless://uuid@h:443',
      flagEmoji: '',
    );

    test('country and city', () {
      expect(ServerCard.subtitleFor(base), 'Germany · Falkenstein');
    });

    test('country alone when the city repeats it or is missing', () {
      expect(ServerCard.subtitleFor(base.copyWith(city: 'Germany')), 'Germany');
      expect(ServerCard.subtitleFor(base.copyWith(city: '')), 'Germany');
    });

    test('city alone when there is no country', () {
      expect(ServerCard.subtitleFor(base.copyWith(country: '')), 'Falkenstein');
    });
  });
}
