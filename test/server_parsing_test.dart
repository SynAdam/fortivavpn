import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/data/models/server.dart';

/// [Server.fromConnectionUri] parses untrusted strings scraped from
/// Telegram channels. ServerRepository wraps every call in a try/catch and
/// skips whatever throws, so the contract these tests pin is that the
/// parser degrades to a usable Server instead of throwing, that it never
/// puts the UUID credential into anything the UI displays, and that the
/// name is a country or a number: never the poster's label, never the host.
void main() {
  const real =
      'vless://c1d2e3f4-a5b6-4c7d-8e9f-0a1b2c3d4e5f@198.51.100.202:443'
      '?type=tcp&security=reality&pbk=3xm9PTo&fp=chrome&sni=www.samsung.com'
      '&spx=%2F&sid=d590c3503068fc30&flow=xtls-rprx-vision'
      '#Fortiva%20FI%20Helsinki';

  group('Server.fromConnectionUri naming', () {
    test('keeps the decoded fragment as the remark, not the name', () {
      final server = Server.fromConnectionUri(real);
      expect(server.remark, 'Fortiva FI Helsinki');
      expect(server.name, 'Community 1');
    });

    test('never names a link by its host', () {
      final server = Server.fromConnectionUri(
        'vless://uuid@198.51.100.202:443?type=tcp',
        index: 2,
      );
      expect(server.name, 'Community 3');
      expect(server.name, isNot(contains('198.51.100.202')));
    });

    test('numbers a link that is nothing at all', () {
      expect(
        Server.fromConnectionUri('not a link at all', index: 4).name,
        'Community 5',
      );
    });

    test('a domain host stays searchable as the remark', () {
      final server = Server.fromConnectionUri('vless://uuid@example.com:8443');
      expect(server.remark, 'example.com');
      expect(server.name, 'Community 1');
    });

    test('a fragment pasted with raw non-ASCII keeps its remark', () {
      // Uri.decodeComponent throws on this; the remark must not fall back
      // to the host because a channel did not percent-encode a bolt.
      final server = Server.fromConnectionUri(
        'vless://uuid@1.2.3.4:443#\u{26A1} Fast | @channel',
      );
      expect(server.remark, '\u{26A1} Fast | @channel');
    });

    test('the number is the position in the list, from one', () {
      expect(Server.fromConnectionUri(real).communityNumber, 1);
      expect(Server.fromConnectionUri(real, index: 41).communityNumber, 42);
      expect(
        const Server(
          id: '7',
          name: 'DE-Falkenstein',
          country: 'Germany',
          city: 'Falkenstein',
          connectionUri: 'vless://uuid@h:443',
          flagEmoji: '',
        ).communityNumber,
        0,
      );
    });
  });

  group('Server.fromConnectionUri flags', () {
    test('lifts a leading flag out of the name into the flag and country', () {
      final server = Server.fromConnectionUri(
        'vless://uuid@1.2.3.4:443#%F0%9F%87%BA%F0%9F%87%B8161315%20%7C%20Telegram',
      );
      expect(server.flagEmoji, '\u{1F1FA}\u{1F1F8}');
      expect(server.country, 'United States');
      expect(server.name, 'United States');
      // The channel's label is kept so search still finds it.
      expect(server.remark, '161315 | Telegram');
    });

    test('drops the separator that followed the flag', () {
      final server = Server.fromConnectionUri(
        'vless://uuid@1.2.3.4:443#\u{1F1E9}\u{1F1EA} | Frankfurt',
      );
      expect(server.country, 'Germany');
      expect(server.name, 'Germany');
      expect(server.remark, 'Frankfurt');
    });

    test('a name that is only a flag keeps it', () {
      final server = Server.fromConnectionUri(
        'vless://uuid@1.2.3.4:443#\u{1F1E8}\u{1F1E6}',
      );
      expect(server.flagEmoji, '\u{1F1E8}\u{1F1E6}');
      expect(server.name, 'Canada');
    });

    test('a name without a flag gets the globe, no country and a number', () {
      final server = Server.fromConnectionUri(real);
      expect(server.flagEmoji, '\u{1F30D}');
      expect(server.country, isEmpty);
      expect(server.name, 'Community 1');
      expect(server.remark, 'Fortiva FI Helsinki');
    });
  });

  group('Server.fromConnectionUri never throws', () {
    // Everything here has been seen in, or is one keystroke away from,
    // a real Telegram post. None of it may take down the list.
    const hostile = <String>[
      '',
      'vless://',
      'vless://@',
      'vless://uuid@',
      'vless://uuid@:443',
      'vless://uuid@host',
      'vless://uuid@host:',
      '#justafragment',
      'vless://uuid@host:443#Bad%ZZ',
      'vless://uuid@host:443#%',
      'ss://not-even-vless@host:443',
      'vless://uuid@host:443?a=1#name#name',
      'vless://uuid@[2001:db8::1]:443',
      '   ',
      'vless://uuid@host:443#',
    ];

    for (var i = 0; i < hostile.length; i++) {
      test('input ${i + 1} yields a Server rather than an exception', () {
        final server = Server.fromConnectionUri(hostile[i], index: i);
        expect(server.name, isNotEmpty);
        expect(server.id, 'telegram-$i');
        expect(server.connectionUri, hostile[i]);
      });
    }
  });

  group('Server.fromConnectionUri credentials', () {
    test('the UUID never reaches the display name', () {
      const uuid = 'c1d2e3f4-a5b6-4c7d-8e9f-0a1b2c3d4e5f';
      expect(Server.fromConnectionUri(real).name, isNot(contains(uuid)));

      // Also when there is no fragment and the remark comes from the host.
      final unnamed = Server.fromConnectionUri('vless://$uuid@host:443');
      expect(unnamed.name, isNot(contains(uuid)));
      expect(unnamed.remark, isNot(contains(uuid)));
      expect(unnamed.remark, 'host');
    });

    test('the full link is kept intact, because connecting needs it', () {
      expect(Server.fromConnectionUri(real).connectionUri, real);
    });
  });

  group('Server.fromConnectionUri fixed fields', () {
    test('community servers know they are community', () {
      expect(Server.fromConnectionUri(real).isCommunity, isTrue);
      expect(Server.fromDedicatedUri(real).isCommunity, isFalse);
    });

    test('community servers are never premium', () {
      expect(Server.fromConnectionUri(real).isPremium, isFalse);
    });

    test('country is empty and latency is unmeasured', () {
      final server = Server.fromConnectionUri(real);
      expect(server.country, isEmpty);
      expect(server.city, isEmpty);
      expect(server.latencyMs, isNull);
      expect(server.load, ServerLoad.normal);
    });

    test('ids are positional, so two links never collide', () {
      final first = Server.fromConnectionUri(real, index: 0);
      final second = Server.fromConnectionUri(real, index: 1);
      expect(first.id, isNot(second.id));
    });
  });

  group('Server.fromApiJson', () {
    test('prefers the remark as the display name', () {
      final server = Server.fromApiJson({
        'id': 7,
        'country_code': 'FI',
        'city': 'Helsinki',
        'remark': 'Fortiva FI 1',
        'uri': real,
        'type': 'free',
      });
      expect(server.name, 'Fortiva FI 1');
      expect(server.country, 'Finland');
      expect(server.flagEmoji, '\u{1F1EB}\u{1F1EE}');
      expect(server.id, '7');
      expect(server.isPremium, isFalse);
    });

    test('falls back to the city, then to the country name', () {
      final city = Server.fromApiJson({
        'id': 1,
        'country_code': 'DE',
        'city': 'Frankfurt',
        'uri': real,
      });
      expect(city.name, 'Frankfurt');

      final country = Server.fromApiJson({
        'id': 2,
        'country_code': 'DE',
        'uri': real,
      });
      expect(country.name, 'Germany');
    });

    test('an unmapped country code is shown as the code itself', () {
      final server = Server.fromApiJson({
        'id': 3,
        'country_code': 'NG',
        'uri': real,
      });
      // The name table covers the fleet, not the world, so a code outside
      // it stands in for itself. The flag is still correct, because that
      // is pure arithmetic on the two letters rather than a lookup.
      expect(server.country, 'NG');
      expect(server.flagEmoji, '\u{1F1F3}\u{1F1EC}');
    });

    test('a missing country code degrades to the globe', () {
      final server = Server.fromApiJson({'id': 4, 'uri': real});
      expect(server.flagEmoji, '\u{1F30D}');
    });

    test('type premium marks the server premium', () {
      final server = Server.fromApiJson({
        'id': 5,
        'country_code': 'US',
        'uri': real,
        'type': 'premium',
      });
      expect(server.isPremium, isTrue);
      expect(server.country, 'United States');
    });
  });

  group('Server.fromDedicatedUri', () {
    test('names the server by place, not by the raw label', () {
      final server = Server.fromDedicatedUri(real);
      expect(server.name, 'Helsinki');
      expect(server.city, 'Helsinki');
      expect(server.country, 'Finland');
      expect(server.flagEmoji, '\u{1F1EB}\u{1F1EE}');
    });

    test('marks the server as belonging to this device', () {
      expect(Server.fromDedicatedUri(real).isDedicated, isTrue);
      expect(Server.fromConnectionUri(real).isDedicated, isFalse);
    });

    test('identifies the server by endpoint, so a reorder cannot move it', () {
      // The backend omits any server it could not reach on a given call,
      // which shifts the positions of the rest. A positional id would
      // reattach the stored choice, and the last latency reading, to a
      // different server after that happened.
      final first = Server.fromDedicatedUri(real, index: 0);
      final third = Server.fromDedicatedUri(real, index: 2);
      expect(first.id, third.id);
      expect(first.id, 'dedicated-198.51.100.202:443');
    });

    test('two different endpoints never share an id', () {
      final other = real.replaceFirst('198.51.100.202', '198.51.100.213');
      expect(
        Server.fromDedicatedUri(real).id,
        isNot(Server.fromDedicatedUri(other).id),
      );
    });

    test('never puts the UUID credential into a displayed field', () {
      final server = Server.fromDedicatedUri(real);
      for (final shown in [
        server.id,
        server.name,
        server.city,
        server.remark,
      ]) {
        expect(shown.contains('78cf9bd9'), isFalse);
      }
    });

    test('falls back to the host when the link carries no label', () {
      final bare =
          'vless://c1d2e3f4-a5b6-4c7d-8e9f-0a1b2c3d4e5f@fi.example.com:443?type=tcp';
      final server = Server.fromDedicatedUri(bare);
      expect(server.name, 'fi.example.com');
      expect(server.flagEmoji, '\u{1F30D}');
      expect(server.isDedicated, isTrue);
    });

    test('an unmapped region still yields a flag and the code', () {
      final label = real.replaceFirst(
        'Fortiva%20FI%20Helsinki',
        'Fortiva%20ZZ%20Nowhere',
      );
      final server = Server.fromDedicatedUri(label);
      expect(server.name, 'Nowhere');
      expect(server.country, 'ZZ');
    });
  });
}
