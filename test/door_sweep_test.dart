import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/data/models/server.dart';
import 'package:fortiva_vpn/services/door_sweep.dart';
import 'package:fortiva_vpn/services/network_keys.dart';
import 'package:fortiva_vpn/services/vpn_event_reporter.dart';
import 'package:shared_preferences/shared_preferences.dart';

Server _path(String door, {String host = 'a.example.com'}) => Server(
  id: door,
  name: door,
  country: 'DE',
  city: 'Nuremberg',
  flagEmoji: '🇩🇪',
  connectionUri: 'vless://uuid@$host:443?type=ws&security=tls#Fortiva',
  door: door,
);

class _Recorder extends VpnEventReporter {
  _Recorder() : super(send: (_, _, _) async {}, sendProbes: (_, _, _) async {});

  final batches = <List<ProbeResult>>[];
  final sources = <ProbeSource>[];
  final networks = <String?>[];

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
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(NetworkKeys.resetForTest);

  DoorSweep sweep({
    required Future<int> Function(Server) probe,
    required _Recorder recorder,
    Future<bool> Function()? internet,
    DateTime Function()? now,
  }) => DoorSweep(
    probe: probe,
    internet: internet ?? () async => true,
    reporter: recorder,
    now: now,
    // Android excludes the app from the TUN, so a probe there measures the
    // carrier even while connected. That is the case under test.
    appBypassesTunnel: true,
  );

  test('after an account deletion an old Wi-Fi key is not marked', () async {
    NetworkKeys.close();
    NetworkKeys.reopen();
    final s = sweep(probe: (p) async => 90, recorder: _Recorder());
    await s.run(
      [_path('ws-tls')],
      network: 'wifi:0123456789abcdef',
      connected: true,
    );
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList(DoorSweep.storageKey), isNull);
    await s.run([_path('ws-tls')], network: 'mobile:Irancell', connected: true);
    expect(prefs.getStringList(DoorSweep.storageKey), hasLength(1));
  });

  test('checks every door, not just until one opens', () async {
    // The whole reason this exists. A diagnosis stops at the first open
    // door, so the ones ranked below it are never measured.
    final tried = <String>[];
    final r = _Recorder();
    await sweep(
      probe: (p) async {
        tried.add(p.door!);
        return 100; // every one of them opens
      },
      recorder: r,
    ).run(
      [_path('ws-tls'), _path('xhttp-reality'), _path('grpc-tls')],
      network: 'mobile:Irancell',
      connected: true,
    );

    expect(tried, ['ws-tls', 'xhttp-reality', 'grpc-tls']);
    expect(r.batches.single.length, 3);
    expect(r.sources.single, ProbeSource.sweep);
    // Sent with the sweep's network, so the rows carry what the phone saw
    // of it, and each door with its own key for that history.
    expect(r.networks.single, 'mobile:Irancell');
    expect(r.batches.single.map((p) => p.doorKey), everyElement(isNotNull));
  });

  test('reports a blocked door rather than dropping it', () async {
    final r = _Recorder();
    await sweep(
      probe: (p) async => p.door == 'ws-tls' ? 120 : -1,
      recorder: r,
    ).run(
      [_path('ws-tls'), _path('grpc-tls')],
      network: 'wifi',
      connected: true,
    );

    final byDoor = {for (final p in r.batches.single) p.door: p.ok};
    expect(byDoor, {'ws-tls': true, 'grpc-tls': false});
  });

  test('returns what it measured, and nothing when it did not run', () async {
    // The flow reads these for what they say about IPv6 on this network.
    final r = _Recorder();
    final s = sweep(probe: (p) async => 90, recorder: r);
    final first = await s.run(
      [_path('ws-tls')],
      network: 'wifi',
      connected: true,
    );
    expect(first.map((p) => p.door), ['ws-tls']);
    expect(first.single.ok, isTrue);

    final again = await s.run(
      [_path('ws-tls')],
      network: 'wifi',
      connected: true,
    );
    expect(again, isEmpty);
  });

  test('records nothing when the phone has no internet', () async {
    // Otherwise a phone that simply dropped off the network reports every
    // door as blocked, which reads exactly like a carrier that started
    // filtering all of them.
    final r = _Recorder();
    await sweep(
      probe: (_) async => -1,
      recorder: r,
      internet: () async => false,
    ).run([_path('ws-tls')], network: 'wifi', connected: true);

    expect(r.batches, isEmpty);
  });

  test('sweeps a network once per interval, then again after it', () async {
    var clock = DateTime.utc(2026, 9, 7, 8);
    final r = _Recorder();
    final s = sweep(probe: (_) async => 100, recorder: r, now: () => clock);

    await s.run([_path('ws-tls')], network: 'wifi', connected: true);
    await s.run([_path('ws-tls')], network: 'wifi', connected: true);
    expect(r.batches.length, 1, reason: 'the second call is not due yet');

    clock = clock.add(const Duration(hours: 7));
    await s.run([_path('ws-tls')], network: 'wifi', connected: true);
    expect(r.batches.length, 2);
  });

  test(
    'a different network is due even when this one was just swept',
    () async {
      // Doors fail per network, so a phone that moves from wifi to mobile
      // has learned nothing about the network it is on now.
      final r = _Recorder();
      final s = sweep(probe: (_) async => 100, recorder: r);

      await s.run([_path('ws-tls')], network: 'wifi', connected: true);
      await s.run(
        [_path('ws-tls')],
        network: 'mobile:Irancell',
        connected: true,
      );
      expect(r.batches.length, 2);
    },
  );

  test('force ignores the interval', () async {
    final r = _Recorder();
    final s = sweep(probe: (_) async => 100, recorder: r);
    await s.run([_path('ws-tls')], network: 'wifi', connected: true);
    await s.run(
      [_path('ws-tls')],
      network: 'wifi',
      connected: true,
      force: true,
    );
    expect(r.batches.length, 2);
  });

  test('a probe that throws is a blocked door, not a lost sweep', () async {
    final r = _Recorder();
    await sweep(
      probe: (p) async {
        if (p.door == 'grpc-tls') throw StateError('core said no');
        return 90;
      },
      recorder: r,
    ).run(
      [_path('ws-tls'), _path('grpc-tls')],
      network: 'wifi',
      connected: true,
    );

    expect(r.batches.single.length, 2);
    final grpc = r.batches.single.firstWhere((p) => p.door == 'grpc-tls');
    expect(grpc.ok, isFalse);
    expect(grpc.error, isNotNull);
  });

  test('caps one sweep so a long path list cannot become a burst', () async {
    final r = _Recorder();
    await sweep(probe: (_) async => 100, recorder: r).run(
      [for (var i = 0; i < 30; i++) _path('door-$i')],
      network: 'wifi',
      connected: true,
    );
    expect(r.batches.single.length, DoorSweep.maxDoors);
  });

  test(
    'waits for the tunnel to be down where the app is not excluded',
    () async {
      // iOS has no addDisallowedApplication, so a probe taken while
      // connected may travel through our own tunnel. That reading would
      // call every door open and would be worse than no reading.
      final r = _Recorder();
      final s = DoorSweep(
        probe: (_) async => 100,
        internet: () async => true,
        reporter: r,
        appBypassesTunnel: false,
      );

      await s.run([_path('ws-tls')], network: 'wifi', connected: true);
      expect(
        r.batches,
        isEmpty,
        reason: 'connected, so the reading is suspect',
      );

      await s.run([_path('ws-tls')], network: 'wifi', connected: false);
      expect(
        r.batches.length,
        1,
        reason: 'tunnel down, so the reading is real',
      );
    },
  );

  test('does nothing at all when there are no paths', () async {
    final r = _Recorder();
    await sweep(
      probe: (_) async => 100,
      recorder: r,
    ).run(const [], network: 'wifi', connected: true);
    expect(r.batches, isEmpty);
  });
}
