import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/api/config_service.dart';
import 'package:fortiva_vpn/data/models/server.dart';
import 'package:fortiva_vpn/services/door_pair.dart';
import 'package:fortiva_vpn/services/network_keys.dart';
import 'package:fortiva_vpn/services/door_sweep.dart';
import 'package:fortiva_vpn/services/path_finder.dart';
import 'package:fortiva_vpn/services/vpn_event_reporter.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _link = 'vless://uuid@a.example.com:443?type=ws&security=tls#Fortiva';
const _testLink =
    'vless://uuid@a.example.com:443?type=ws&security=tls&fragment=off#Fortiva';

Server _door(String door, {int serverId = 10, String uri = _link}) => Server(
  id: '$serverId-$door',
  name: door,
  country: 'DE',
  city: 'Nuremberg',
  flagEmoji: '🇩🇪',
  connectionUri: uri,
  door: door,
  serverId: serverId,
);

DoorPairCheck _pair({int serverId = 10, String door = 'ws-tls'}) =>
    DoorPairCheck.fromJson({
      'experiment_id': 30,
      'server_id': serverId,
      'door': door,
      'test_uri': _testLink,
      'interval_seconds': 1800,
      'gap_ms': 2000,
      'timeout_ms': 6000,
    })!;

class _Recorder extends VpnEventReporter {
  _Recorder() : super(send: (_, _, _) async {}, sendProbes: (_, _, _) async {});

  final batches = <List<ProbeResult>>[];
  final sources = <ProbeSource>[];
  final networks = <String?>[];
  final attempts = <String?>[];

  @override
  Future<void> recordProbes(
    List<ProbeResult> results, {
    String? carrier,
    String? attemptId,
    ProbeSource source = ProbeSource.diagnosis,
    String? network,
  }) async {
    networks.add(network);
    batches.add(results);
    sources.add(source);
    attempts.add(attemptId);
  }
}

/// A Random whose nextBool is fixed, so the order of a round is known.
class _Coin implements Random {
  _Coin(this.heads);
  final bool heads;
  @override
  bool nextBool() => heads;
  @override
  int nextInt(int max) => 0;
  @override
  double nextDouble() => 0;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  late List<String> dialled;
  late int running;
  late int mostAtOnce;
  late List<Duration> waits;
  var clock = DateTime.utc(2026, 10, 16, 9);

  DoorPairRunner runner(
    _Recorder recorder, {
    bool heads = true,
    bool Function(Server)? opens,
  }) {
    final sweep = DoorSweep(
      read: (Server p) async {
        running++;
        mostAtOnce = max(mostAtOnce, running);
        dialled.add(p.connectionUri);
        await Future<void>.delayed(const Duration(milliseconds: 5));
        running--;
        final open = opens?.call(p) ?? true;
        return DoorOutcome(ms: open ? 120 : -1, error: open ? null : 'no');
      },
      internet: () async => true,
      reporter: recorder,
      appBypassesTunnel: true,
    );
    return DoorPairRunner(
      sweep: sweep,
      reporter: recorder,
      random: _Coin(heads),
      now: () => clock,
      wait: (d) async => waits.add(d),
      newId: () => 'abc',
    );
  }

  setUp(() {
    dialled = [];
    running = 0;
    mostAtOnce = 0;
    waits = [];
    clock = DateTime.utc(2026, 10, 16, 9);
  });

  test(
    'checks the door as it is and with the test setting, one at a time',
    () async {
      final r = _Recorder();
      final results =
          await runner(r, opens: (p) => p.connectionUri == _testLink).run(
            _pair(),
            [_door('xhttp-reality', serverId: 11), _door('ws-tls')],
            network: 'mobile:MCI',
            carrier: 'MCI',
          );

      expect(dialled, [_link, _testLink]);
      expect(mostAtOnce, 1); // never side by side
      expect(waits, [const Duration(seconds: 2)]); // the gap between them
      expect(results.map((r) => r.ok), [false, true]);
      expect(r.batches.single, results); // reported together, in run order
      expect(r.sources.single, ProbeSource.experiment);
      expect(r.attempts.single, 'pair-abc');
      // An experiment's rows carry no network facts: one setting is not
      // the phone's own, so its result says nothing of the network.
      expect(r.networks.single, isNull);
    },
  );

  test('after an account deletion an old Wi-Fi key is not marked', () async {
    addTearDown(NetworkKeys.resetForTest);
    NetworkKeys.close();
    NetworkKeys.reopen();
    final pairs = runner(_Recorder());
    await pairs.run(_pair(), [
      _door('ws-tls'),
    ], network: 'wifi:0123456789abcdef');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList(DoorPairRunner.storageKey), isNull);
    await pairs.run(_pair(), [_door('ws-tls')], network: 'mobile:MCI');
    expect(prefs.getStringList(DoorPairRunner.storageKey), hasLength(1));
  });

  test('the coin decides which check goes first', () async {
    await runner(
      _Recorder(),
      heads: false,
    ).run(_pair(), [_door('ws-tls')], network: 'wifi');
    expect(dialled, [_testLink, _link]);
  });

  test('at most one round per network in the interval', () async {
    final r = _Recorder();
    final pairs = runner(r);
    final paths = [_door('ws-tls')];
    await pairs.run(_pair(), paths, network: 'mobile:MCI');
    await pairs.run(_pair(), paths, network: 'mobile:MCI');
    expect(r.batches, hasLength(1));

    await pairs.run(_pair(), paths, network: 'wifi'); // another network
    expect(r.batches, hasLength(2));

    clock = clock.add(const Duration(minutes: 31));
    await pairs.run(_pair(), paths, network: 'mobile:MCI');
    expect(r.batches, hasLength(3));
  });

  test('nothing runs when the phone does not have the door', () async {
    final r = _Recorder();
    final pairs = runner(r);
    expect(
      await pairs.run(_pair(serverId: 99), [_door('ws-tls')], network: 'w'),
      isEmpty,
    );
    expect(
      await pairs.run(_pair(), [_door('ws-tls', uri: _testLink)], network: 'w'),
      isEmpty, // the phone already has the test's setting
    );
    expect(r.batches, isEmpty);
    expect(dialled, isEmpty);
  });

  test('an unusable pair from the backend is ignored', () {
    final good = {
      'experiment_id': 30,
      'server_id': 10,
      'door': 'ws-tls',
      'test_uri': _testLink,
      'interval_seconds': 1800,
      'gap_ms': 2000,
      'timeout_ms': 6000,
    };
    final pair = DoorPairCheck.fromJson(good)!;
    expect(pair.interval, const Duration(minutes: 30));
    expect(pair.gap, const Duration(seconds: 2));
    expect(pair.timeout, const Duration(seconds: 6));
    expect(DoorPairCheck.fromJson(null), isNull);
    for (final bad in [
      {...good, 'test_uri': ''},
      {...good, 'door': ''},
      {...good, 'interval_seconds': 5},
      {...good, 'timeout_ms': 0},
      {...good, 'server_id': null},
    ]) {
      expect(DoorPairCheck.fromJson(bad), isNull, reason: '$bad');
    }
  });

  test('the backend answer carries the pair, and an old one none', () {
    final base = <String, dynamic>{'configs': <String>[], 'quota': {}};
    expect(DedicatedConfigs.fromJson(base).doorPair, isNull);
    final withPair = DedicatedConfigs.fromJson({
      ...base,
      'door_pair': {
        'experiment_id': 30,
        'server_id': 10,
        'door': 'ws-tls',
        'test_uri': _testLink,
        'interval_seconds': 1800,
        'gap_ms': 2000,
        'timeout_ms': 6000,
      },
    });
    expect(withPair.doorPair?.experimentId, 30);
  });
}
