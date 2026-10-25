import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/api/config_service.dart';
import 'package:fortiva_vpn/core/state/dedicated_state.dart';
import 'package:fortiva_vpn/data/models/server.dart';
import 'package:fortiva_vpn/services/door_sweep.dart';
import 'package:fortiva_vpn/services/test_point.dart';
import 'package:fortiva_vpn/services/vpn_event_reporter.dart';
import 'package:fortiva_vpn/utils/tls_fragment.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A spare phone inside Iran, marked by the backend as a test point, checks
/// every door and every split on a timer.
Server door(String id, String door, String uri) => Server(
  id: id,
  name: 'Nuremberg',
  country: 'Germany',
  city: 'Nuremberg',
  connectionUri: uri,
  flagEmoji: '',
  isDedicated: true,
  door: door,
  serverId: 10,
);

final direct = door(
  'd',
  'xhttp-reality',
  'vless://u@198.51.100.210:8443?security=reality&type=xhttp#DE',
);
final cdn = door(
  'c',
  'ws-tls',
  'vless://u@198.51.100.215:443?security=tls&type=ws&sni=m.example#DE',
);

class _Dedicated extends DedicatedState {
  TestPointConfig? config = const TestPointConfig(
    interval: Duration(minutes: 10),
    specs: ['tlshello,100-200,1-2', 'off'],
  );
  int refreshes = 0;
  List<Server> extra = const [];

  @override
  TestPointConfig? get testPoint => config;

  @override
  List<Server> get paths => [direct, cdn, ...extra];

  @override
  Future<void> refresh({bool? viaTunnel}) async {
    refreshes++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('the backend config is read, and a bad one is ignored', () {
    final cfg = TestPointConfig.fromJson({
      'interval_seconds': 600,
      'specs': ['off', '', 3],
    })!;
    expect(cfg.interval, const Duration(minutes: 10));
    expect(cfg.specs, ['off']);
    expect(TestPointConfig.fromJson(null), isNull);
    expect(TestPointConfig.fromJson({'interval_seconds': 5}), isNull);
  });

  test('a split is written into a link, replacing the one it had', () {
    final once = TlsFragment.withSpec(cdn.connectionUri, 'off');
    expect(once, endsWith('&fragment=off#DE'));
    final twice = TlsFragment.withSpec(once, 'tlshello,1-2,3-4');
    expect(twice, isNot(contains('fragment=off')));
    expect(twice, endsWith('&fragment=tlshello,1-2,3-4#DE'));
  });

  test(
    'a round checks every door, then every split on the TLS doors',
    () async {
      final batches = <(String, List<Map<String, dynamic>>)>[];
      final reporter = VpnEventReporter(
        send: (_, _, _) async {},
        sendProbes: (_, probes, _) async {
          batches.add((probes.first['source'] as String, probes));
        },
        deviceId: () async => 'DEV-TP',
        appVersion: () async => '1.6.9',
        platform: 'android',
        networkType: () async => 'mobile',
      );
      // The direct door is blocked; the CDN door passes only whole or in
      // large pieces.
      final sweep = DoorSweep(
        probe: (p) async {
          final uri = p.connectionUri;
          if (p.door == 'xhttp-reality') return -1;
          return uri.contains('fragment=') ? 300 : -1;
        },
        reporter: reporter,
      );
      final dedicated = _Dedicated();
      final runner = TestPointRunner(
        dedicated,
        sweep: sweep,
        reporter: reporter,
        internet: () async => true,
        carrier: () async => 'IR-MCI',
        android: true,
      );
      await pumpEventQueue();

      expect(runner.active, isTrue);
      expect(dedicated.refreshes, 1);
      expect(batches.map((b) => b.$1), ['testpoint', 'experiment']);
      final defaults = batches[0].$2;
      expect(defaults.map((p) => p['door']), ['xhttp-reality', 'ws-tls']);
      final splits = batches[1].$2;
      expect(splits, hasLength(2)); // only the TLS door, once per split
      expect(splits.map((p) => p['strategy']['fragment']), [
        'tlshello,100-200,1-2',
        'off',
      ]);
      expect(splits.every((p) => p['ok'] == true), isTrue);
      expect(splits.first['carrier'], 'IR-MCI');
      expect(runner.totalDoors, 2);
      expect(runner.lastCheck, isNotNull);

      // The backend stops sending a config: the phone stops being one.
      dedicated.config = null;
      dedicated.notifyListeners();
      expect(runner.active, isFalse);
      runner.dispose();
    },
  );

  test('a copy of the direct door at another address gets no splits', () async {
    // The splits are for TLS doors, and the "-b" copy of the direct door is
    // a Reality door like the first one. Read from the link, not the id.
    final second = door(
      'b',
      'xhttp-reality-b',
      'vless://u@198.51.100.211:8443?security=reality&type=xhttp#DE',
    );
    final batches = <(String, List<Map<String, dynamic>>)>[];
    final reporter = VpnEventReporter(
      send: (_, _, _) async {},
      sendProbes: (_, probes, _) async {
        batches.add((probes.first['source'] as String, probes));
      },
      deviceId: () async => 'DEV-TP',
      appVersion: () async => '1.6.9',
      platform: 'android',
      networkType: () async => 'mobile',
    );
    final dedicated = _Dedicated()..extra = [second];
    final runner = TestPointRunner(
      dedicated,
      sweep: DoorSweep(probe: (_) async => 100, reporter: reporter),
      reporter: reporter,
      internet: () async => true,
      carrier: () async => 'IR-TCI',
      android: true,
    );
    await pumpEventQueue();

    // A test point row keeps every setting it dialled with, so its checks
    // may go in more than one upload. Read the doors of each kind from
    // every upload that carried them.
    List<Object?> doorsOf(String source) => [
      for (final (s, probes) in batches)
        if (s == source) ...probes.map((p) => p['door']),
    ];
    final sources = batches.map((b) => b.$1).toList();
    expect(sources.first, 'testpoint');
    expect(
      sources.lastIndexOf('testpoint'),
      lessThan(sources.indexOf('experiment')),
    );
    expect(doorsOf('testpoint'), [
      'xhttp-reality',
      'ws-tls',
      'xhttp-reality-b',
    ]);
    expect(doorsOf('experiment').toSet(), {'ws-tls'});
    runner.dispose();
  });

  test('nothing is checked while another app\'s VPN carries the phone\'s '
      'traffic', () async {
    // The checks would measure that app's route, filed under the carrier.
    final batches = <String>[];
    final reporter = VpnEventReporter(
      send: (_, _, _) async {},
      sendProbes: (_, probes, _) async =>
          batches.add(probes.first['source'] as String),
      deviceId: () async => 'DEV-TP',
      appVersion: () async => '2.1.4',
      platform: 'android',
      networkType: () async => 'mobile',
    );
    var other = true;
    final runner = TestPointRunner(
      _Dedicated(),
      sweep: DoorSweep(probe: (_) async => 100, reporter: reporter),
      reporter: reporter,
      internet: () async => true,
      carrier: () async => 'IR-MCI',
      android: true,
      otherVpnUp: () async => other,
    );
    await pumpEventQueue();
    expect(batches, isEmpty);

    other = false;
    await runner.runOnce();
    expect(batches, contains('testpoint'));
    runner.dispose();
  });

  test('nothing runs on a phone that is not a test point', () async {
    final dedicated = _Dedicated()..config = null;
    final runner = TestPointRunner(
      dedicated,
      internet: () async => true,
      android: true,
    );
    await pumpEventQueue();
    expect(runner.active, isFalse);
    expect(dedicated.refreshes, 0);
    runner.dispose();
  });
}
