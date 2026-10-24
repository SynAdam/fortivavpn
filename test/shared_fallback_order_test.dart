import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/core/state/dial_server.dart';
import 'package:fortiva_vpn/core/state/server_state.dart';
import 'package:fortiva_vpn/data/models/server.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The shared links the connect flow falls back on, in the order it
/// checks them: ours, then the community links in the backend's order,
/// then the ones whose test on this phone failed.
///
/// The backend's order is for the phone's carrier, with the links a phone
/// on it got through most recently first. On 2026-10-10 such a link passed
/// a fallback check 30% of the time, and one with no success on the
/// carrier in 24 hours 3%. The phone's own results used to go first,
/// fastest first, whatever their age.
Server _link(String id) => Server(
  id: id,
  name: id,
  country: '',
  city: '',
  connectionUri: 'vless://s@$id.example:443?type=tcp#$id',
  flagEmoji: '🌍',
);

class _Servers extends ServerState {
  _Servers(this.official, this.community, this.pings);

  final List<Server> official;
  final List<Server> community;
  final Map<String, int> pings;

  @override
  List<Server> get officialServers => official;

  @override
  List<Server> get communityServers => community;

  @override
  int? getPingResult(String serverId) => pings[serverId];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('ours first, then community in the backend order, failed last', () {
    final ours = _link('official-1');
    final fresh = _link('telegram-fresh');
    final never = _link('telegram-never');
    final dead = _link('telegram-dead');
    final fast = _link('telegram-fast');

    final order = sharedFallback(
      _Servers([ours], [fresh, never, dead, fast], {
        fresh.id: 900,
        fast.id: 120,
        dead.id: -1,
      }),
    );

    // A fast reading on this phone does not move a link ahead of one the
    // backend ranks higher for the carrier.
    expect(order, [ours, fresh, never, fast, dead]);
  });

  test('a reading of zero counts as failed', () {
    final first = _link('telegram-first');
    final second = _link('telegram-second');

    final order = sharedFallback(
      _Servers(const [], [first, second], {first.id: 0}),
    );

    expect(order, [second, first]);
  });

  test('nothing to fall back on is an empty list', () {
    expect(sharedFallback(_Servers(const [], const [], const {})), isEmpty);
  });
}
