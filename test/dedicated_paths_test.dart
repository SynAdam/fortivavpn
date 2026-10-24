import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/api/config_service.dart';
import 'package:fortiva_vpn/core/state/dedicated_state.dart';
import 'package:fortiva_vpn/data/models/server.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The dedicated response now carries every door of every server. Old
/// backends carry none, and the app must keep working on them.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const uri =
      'vless://u@hel.example.com:443?type=tcp&security=reality#Fortiva%20FI%20Helsinki';

  test('paths are read with their door, label and order', () {
    final parsed = DedicatedConfigs.fromJson({
      'configs': [uri],
      'paths': [
        {
          'server_id': 7,
          'inbound_id': 1,
          'door': 'tcp-reality',
          'label': 'Reality',
          'uri': uri,
          'preferred': true,
        },
        {
          'server_id': 7,
          'inbound_id': 3,
          'door': 'xhttp-reality',
          'label': 'Reality over XHTTP',
          'uri': '$uri-x',
          'preferred': false,
        },
        {'door': '', 'uri': ''}, // unusable, dropped
      ],
      'quota': {},
    });
    expect(parsed.configs, [uri]);
    expect(parsed.paths.map((p) => p.door), ['tcp-reality', 'xhttp-reality']);
    expect(parsed.paths.first.preferred, isTrue);
    expect(parsed.paths.first.serverId, 7);
    expect(parsed.paths[1].inboundId, 3);
  });

  test('a backend without paths yields none, and configs still parse', () {
    final parsed = DedicatedConfigs.fromJson({
      'configs': [uri],
      'quota': {},
    });
    expect(parsed.configs, [uri]);
    expect(parsed.paths, isEmpty);
  });

  test('a path becomes a server that names its door', () {
    final s = Server.fromDedicatedPath(
      uri: uri,
      door: 'xhttp-reality',
      doorLabel: 'Reality over XHTTP',
      serverId: 7,
    );
    expect(s.isDedicated, isTrue);
    expect(s.door, 'xhttp-reality');
    expect(s.doorLabel, 'Reality over XHTTP');
    expect(s.serverId, 7);
    expect(s.city, 'Helsinki');
    // The id names the server, so the servers screen and the memory
    // agree on what is being chosen.
    expect(s.id, Server.fromDedicatedUri(uri).id);
    expect(s.pathKey, 'hel.example.com:443|xhttp-reality');
  });

  test('the door survives a round trip through json', () {
    final s = Server.fromDedicatedPath(
      uri: uri,
      door: 'ws-tls',
      doorLabel: 'TLS over WebSocket',
      serverId: 8,
    );
    final back = Server.fromJson(s.toJson());
    expect(back.door, 'ws-tls');
    expect(back.doorLabel, 'TLS over WebSocket');
    expect(back.serverId, 8);
  });

  // The backend penalizes a door that answers probes fast and still fails
  // in the middle of sessions. The core adds the penalty to the door's
  // score.
  test('a path carries the penalty the backend sent for its door', () {
    final parsed = DedicatedConfigs.fromJson({
      'configs': [uri],
      'paths': [
        {
          'server_id': 7,
          'door': 'ws-tls',
          'uri': '$uri-cdn',
          'penalty_ms': 1200,
        },
        {'server_id': 7, 'door': 'tcp-reality-v6', 'uri': '$uri-v6'},
        {
          'server_id': 7,
          'door': 'grpc-tls',
          'uri': '$uri-g',
          'penalty_ms': 450.0,
        },
      ],
      'quota': {},
    });
    expect(parsed.paths.map((p) => p.penaltyMs), [1200, 0, 450]);
  });

  test('a penalty that is not a positive number is none', () {
    for (final value in <Object?>[null, 0, -300, '900', true, double.nan]) {
      expect(DedicatedPath.penaltyOf(value), 0, reason: '$value');
    }
    // The core holds a penalty as a 32-bit number.
    expect(DedicatedPath.penaltyOf(1 << 40), DedicatedPath.maxPenaltyMs);

    // A malformed penalty costs that door its penalty, not its place in the
    // list.
    final parsed = DedicatedConfigs.fromJson({
      'configs': [uri],
      'paths': [
        {'door': 'ws-tls', 'uri': '$uri-cdn', 'penalty_ms': '900'},
        {'door': 'tcp-reality', 'uri': uri, 'penalty_ms': 300},
      ],
      'quota': {},
    });
    expect(parsed.paths.map((p) => p.penaltyMs), [0, 300]);
  });

  test('a door keeps its penalty, through json too', () {
    final s = Server.fromDedicatedPath(
      uri: uri,
      door: 'ws-tls',
      doorLabel: 'TLS over WebSocket',
      serverId: 8,
      penaltyMs: 1200,
    );
    expect(s.penaltyMs, 1200);
    expect(Server.fromJson(s.toJson()).penaltyMs, 1200);

    final none = Server.fromDedicatedPath(
      uri: uri,
      door: 'tcp-reality',
      doorLabel: 'Reality',
    );
    expect(none.penaltyMs, 0);
    expect(none.toJson().containsKey('penaltyMs'), isFalse);
  });

  test('the doors a refresh adopts carry their penalties', () async {
    SharedPreferences.setMockInitialValues({});
    final state = DedicatedState();
    await state.adoptForTest(
      [uri],
      const [
        DedicatedPath(
          serverId: 7,
          inboundId: 1,
          door: 'tcp-reality',
          label: 'Reality',
          uri: uri,
        ),
        DedicatedPath(
          serverId: 7,
          inboundId: 2,
          door: 'ws-tls',
          label: 'TLS over WebSocket',
          uri: '$uri-cdn',
          penaltyMs: 1200,
        ),
      ],
    );
    expect(state.paths.map((p) => p.door), ['tcp-reality', 'ws-tls']);
    expect(state.paths.map((p) => p.penaltyMs), [0, 1200]);
  });
}
