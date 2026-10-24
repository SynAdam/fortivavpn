import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/data/models/server.dart';
import 'package:fortiva_vpn/utils/server_sort.dart';

Server server(String id, {String country = ''}) => Server(
  id: id,
  name: id,
  country: country,
  city: '',
  connectionUri: 'vless://u@h:443',
  flagEmoji: '',
);

List<String> order(List<Server> servers, Map<String, int> latency) =>
    sortForDisplay(servers, (s) => latency[s.id]).map((s) => s.id).toList();

void main() {
  group('sortForDisplay', () {
    test('tested rows lead, fastest first, timeouts last', () {
      final servers = [
        server('slow'),
        server('timeout'),
        server('fast'),
        server('untested'),
      ];
      expect(order(servers, {'slow': 300, 'timeout': -1, 'fast': 40}), [
        'fast',
        'slow',
        'untested',
        'timeout',
      ]);
    });

    test('untested rows group by country, unflagged ones after', () {
      final servers = [
        server('x1'),
        server('us1', country: 'United States'),
        server('de1', country: 'Germany'),
        server('x2'),
        server('us2', country: 'United States'),
      ];
      expect(order(servers, {}), ['de1', 'us1', 'us2', 'x1', 'x2']);
    });

    test('ties keep their incoming order', () {
      final servers = [server('b'), server('a'), server('c')];
      expect(order(servers, {'b': 50, 'a': 50, 'c': 50}), ['b', 'a', 'c']);
      expect(order(servers, {}), ['b', 'a', 'c']);
    });

    test('a tested row outranks an untested one even from a country', () {
      final servers = [server('de', country: 'Germany'), server('x')];
      expect(order(servers, {'x': 900}), ['x', 'de']);
    });
  });
}
