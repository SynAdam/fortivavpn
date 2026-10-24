import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/core/state/connect_flow.dart';
import 'package:fortiva_vpn/data/models/checklist_settings.dart';
import 'package:fortiva_vpn/data/models/server.dart';
import 'package:fortiva_vpn/services/failure_verdict.dart';
import 'package:fortiva_vpn/services/path_finder.dart';
import 'package:fortiva_vpn/services/path_memory.dart';
import 'package:fortiva_vpn/services/vpn_event_reporter.dart';
import 'package:fortiva_vpn/services/vpn_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The connect button end to end: fast path, diagnosis, memory, reports.
///
/// The tunnel is a fake that succeeds or fails per path, the door probe is
/// a map, and the network is a fixed string, so every branch of the flow
/// can be walked in milliseconds.
Server door(String host, String door, {int? serverId}) => Server(
  id: 'dedicated-$host:443',
  name: host,
  country: '',
  city: host,
  connectionUri: 'vless://u@$host:443?type=tcp#$host',
  flagEmoji: '🌍',
  isDedicated: true,
  door: door,
  doorLabel: door,
  serverId: serverId,
);

/// A tunnel that comes up, verified, through the paths in [works], and
/// fails through everything else.
class _FakeVpn extends VpnService {
  _FakeVpn(this.works, {VpnEventReporter? events})
    : super(events: events ?? VpnEventReporter(send: (_, _, _) async {}));

  final Set<String> works;
  final dialled = <String>[];
  VpnStatus _fakeStatus = VpnStatus.disconnected;

  @override
  VpnStatus get status => _fakeStatus;

  @override
  bool get isConnected => _fakeStatus == VpnStatus.connected;

  @override
  bool get isConnecting => _fakeStatus == VpnStatus.connecting;

  @override
  bool get isVerifying => false;

  /// The attempt id each dial carried, in order.
  final List<String?> dialledAttemptIds = [];

  /// Paths whose tunnel comes up and then carries nothing: the check
  /// through it fails ([failedAfterUp]), rather than the tunnel never
  /// starting.
  final Set<String> starve = {};

  /// What the diagnosis of every failure finds ([failureSettled]).
  FailureVerdict? verdict;

  /// The door the core is on when a dial fails, when it left the dialled
  /// one for a standby door.
  Server? leftOnDoor;

  bool _starved = false;

  @override
  bool get failedAfterUp => _starved;

  @override
  Future<FailureVerdict?> failureSettled({
    Duration wait = const Duration(seconds: 12),
  }) async => verdict;

  @override
  Server? get activeDoor =>
      _fakeStatus == VpnStatus.error ? leftOnDoor : super.activeDoor;

  @override
  Future<void> connect(
    Server server, {
    String? attemptId,
    List<Server> standby = const [],
    LinkSource? source,
  }) async {
    dialled.add(server.pathKey);
    dialledAttemptIds.add(attemptId);
    _starved = false;
    _fakeStatus = VpnStatus.connecting;
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 5));
    _starved = starve.contains(server.pathKey);
    _fakeStatus = works.contains(server.pathKey)
        ? VpnStatus.connected
        : VpnStatus.error;
    notifyListeners();
  }

  @override
  Future<void> disconnect() async {
    _fakeStatus = VpnStatus.disconnected;
    notifyListeners();
  }

  /// How many times the flow cleared the service's error.
  int clears = 0;

  @override
  void clearError() {
    clears++;
    if (_fakeStatus == VpnStatus.error) _fakeStatus = VpnStatus.disconnected;
    notifyListeners();
  }

  /// Every failed connect is the user refusing the VPN permission.
  bool refusePermission = false;

  @override
  bool get failedOnPermission => refusePermission;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final hel1 = door('hel', 'tcp-reality', serverId: 7);
  final hel2 = door('hel', 'xhttp-reality', serverId: 7);
  final fsn1 = door('fsn', 'tcp-reality', serverId: 8);
  final paths = [hel1, hel2, fsn1];

  late List<List<Map<String, dynamic>>> reported;
  late List<String> probed;
  late Map<String, int> probeResults;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    reported = [];
    probed = [];
    probeResults = {};
  });

  ConnectFlow flow(_FakeVpn vpn, {bool internet = true}) => ConnectFlow(
    vpn: vpn,
    memory: PathMemory(),
    finder: PathFinder(
      probe: (p) async {
        probed.add(p.pathKey);
        return probeResults[p.pathKey] ?? -1;
      },
      internet: () async => internet,
    ),
    reporter: VpnEventReporter(
      send: (_, _, _) async {},
      sendProbes: (_, probes, _) async => reported.add(probes),
      deviceId: () async => 'DEV-1',
      appVersion: () async => '1.5.0',
      platform: 'android',
      networkType: () async => 'mobile',
    ),
    networkKey: () async => 'mobile:Irancell',
    carrier: () async => 'Irancell',
    attemptTimeout: const Duration(seconds: 2),
  );

  test(
    'with no memory the checklist runs and the open door connects',
    () async {
      final vpn = _FakeVpn({hel2.pathKey});
      probeResults = {hel2.pathKey: 180};
      final f = flow(vpn);

      await f.connect(paths, preferred: hel1);

      expect(f.stage, ConnectStage.done);
      expect(f.chosen, hel2);
      expect(probed, [hel1.pathKey, hel2.pathKey]);
      expect(vpn.dialled, [hel2.pathKey]);
      // And it was remembered, so the next tap is the fast path.
      expect(await PathMemory().recall('mobile:Irancell'), hel2.pathKey);
    },
  );

  test('the fast path dials the remembered door with no checks', () async {
    await PathMemory().remember('mobile:Irancell', hel2.pathKey);
    final vpn = _FakeVpn({hel2.pathKey});
    final f = flow(vpn);

    await f.connect(paths, preferred: hel1);

    expect(f.stage, ConnectStage.done);
    expect(probed, isEmpty);
    expect(vpn.dialled, [hel2.pathKey]);
    expect(reported, isEmpty);
  });

  test(
    'a remembered door that fails leads to a diagnosis, tried last',
    () async {
      await PathMemory().remember('mobile:Irancell', hel1.pathKey);
      final vpn = _FakeVpn({fsn1.pathKey});
      probeResults = {fsn1.pathKey: 90};
      var switched = <Server>[];
      final f = flow(vpn);

      await f.connect(
        paths,
        preferred: hel1,
        onSwitchedServer: (s) => switched.add(s),
      );

      expect(vpn.dialled.first, hel1.pathKey);
      // hel1 already failed just now, so the checklist starts elsewhere.
      expect(probed, [hel2.pathKey, fsn1.pathKey]);
      expect(f.stage, ConnectStage.done);
      expect(f.chosen, fsn1);
      expect(switched, [fsn1]);
      expect(await PathMemory().recall('mobile:Irancell'), fsn1.pathKey);
    },
  );

  test(
    'the remembered door is ignored when it is not the chosen server',
    () async {
      await PathMemory().remember('mobile:Irancell', fsn1.pathKey);
      final vpn = _FakeVpn({hel1.pathKey});
      probeResults = {hel1.pathKey: 100};
      final f = flow(vpn);

      await f.connect(paths, preferred: hel1);

      expect(vpn.dialled, [hel1.pathKey]);
      expect(probed, [hel1.pathKey]);
    },
  );

  // The selection names a server only because an earlier tap landed there,
  // so the tap has no preferred server. Up to 1.7.0 its doors went first
  // anyway, and some taps that started there failed.
  group('a server nobody picked', () {
    Server? selected;
    late List<Server> switched;

    setUp(() {
      selected = hel1;
      switched = [];
    });

    test('keeps the backend\'s door order, and the selection follows the '
        'door that opens', () async {
      final vpn = _FakeVpn({fsn1.pathKey});
      probeResults = {fsn1.pathKey: 90};
      final f = flow(vpn);

      await f.connect(
        [fsn1, hel1, hel2],
        selection: () => selected,
        onSwitchedServer: (s) => switched.add(selected = s),
      );

      expect(probed, [fsn1.pathKey]);
      expect(vpn.dialled, [fsn1.pathKey]);
      expect(switched, [fsn1]);
    });

    test('the remembered door is dialled whatever server it is on', () async {
      await PathMemory().remember('mobile:Irancell', fsn1.pathKey);
      final vpn = _FakeVpn({fsn1.pathKey});
      final f = flow(vpn);

      await f.connect(
        paths,
        selection: () => selected,
        onSwitchedServer: (s) => switched.add(selected = s),
      );

      expect(probed, isEmpty);
      expect(vpn.dialled, [fsn1.pathKey]);
      expect(f.stage, ConnectStage.done);
      expect(switched, [fsn1]);
    });

    test('a door of the selected server moves nothing', () async {
      final vpn = _FakeVpn({hel2.pathKey});
      probeResults = {hel2.pathKey: 90};
      final f = flow(vpn);

      await f.connect(
        [hel2, fsn1, hel1],
        selection: () => selected,
        onSwitchedServer: (s) => switched.add(selected = s),
      );

      expect(vpn.dialled, [hel2.pathKey]);
      expect(switched, isEmpty);
    });
  });

  test('no internet: the doors are checked beside the control fetch, and '
      'none is dialled or reported', () async {
    final vpn = _FakeVpn({});
    final f = flow(vpn, internet: false);
    await f.connect(paths, preferred: hel1);
    await Future.delayed(Duration.zero);
    expect(f.stage, ConnectStage.noInternet);
    expect(probed, [hel1.pathKey, hel2.pathKey, fsn1.pathKey]);
    expect(vpn.dialled, isEmpty);
    expect(reported, isEmpty);
  });

  test('every door blocked is reported and told plainly', () async {
    final vpn = _FakeVpn({});
    final f = flow(vpn);
    await f.connect(paths, preferred: hel1);
    await Future.delayed(Duration.zero);

    expect(f.stage, ConnectStage.nothingOpen);
    expect(f.showChecklist, isTrue);
    expect(vpn.dialled, isEmpty);
    expect(reported, hasLength(1));
    final probes = reported.single;
    expect(probes, hasLength(3));
    expect(probes.every((p) => p['ok'] == false), isTrue);
    expect(probes.first['door'], 'tcp-reality');
    expect(probes.first['server_host'], 'hel');
    expect(probes.first['carrier'], 'Irancell');
    // The door fixes the transport, so the row does not repeat it.
    expect(probes.first.containsKey('strategy'), isFalse);
  });

  // ConnectFlow used to build a reporter of its own that never flushed, so
  // door checks it could not send waited for VpnService's flush.
  test('door checks go out through the service\'s own reporter', () async {
    final viaService = <List<Map<String, dynamic>>>[];
    final vpn = _FakeVpn(
      {},
      events: VpnEventReporter(
        send: (_, _, _) async {},
        sendProbes: (_, probes, _) async => viaService.add(probes),
        deviceId: () async => 'DEV-1',
        appVersion: () async => '1.6.13',
        platform: 'android',
        networkType: () async => 'wifi',
      ),
    );
    final f = ConnectFlow(
      vpn: vpn,
      memory: PathMemory(),
      finder: PathFinder(probe: (p) async => -1, internet: () async => true),
      networkKey: () async => 'wifi',
      carrier: () async => null,
      attemptTimeout: const Duration(seconds: 2),
    );
    await f.connect(paths, preferred: hel1);
    await Future.delayed(Duration.zero);
    expect(f.stage, ConnectStage.nothingOpen);
    expect(viaService.expand((b) => b).map((p) => p['door']), [
      'tcp-reality',
      'xhttp-reality',
      'tcp-reality',
    ]);
  });

  test(
    'a door open on the check but dead on connect is a failure, remembered as one',
    () async {
      final vpn = _FakeVpn({});
      probeResults = {hel1.pathKey: 50};
      final f = flow(vpn);
      await f.connect(paths, preferred: hel1);

      expect(f.stage, ConnectStage.failed);
      expect(vpn.dialled, [hel1.pathKey]);
      expect(await PathMemory().recall('mobile:Irancell'), isNull);
    },
  );

  test('doors that failed three times today are skipped', () async {
    final m = PathMemory();
    for (var i = 0; i < 3; i++) {
      await m.markFailed('mobile:Irancell', hel1.pathKey);
    }
    final vpn = _FakeVpn({hel2.pathKey});
    probeResults = {hel2.pathKey: 70};
    final f = flow(vpn);
    await f.connect(paths, preferred: hel1);

    expect(probed, [hel2.pathKey]);
    expect(f.checks.first.state, PathCheckState.skipped);
    expect(f.stage, ConnectStage.done);
  });

  group('a shared link the user picked', () {
    // The official Cloudflare link, which failed 50 times out of 55 from
    // Iran on 2026-09-27 while these phones had working doors of their own.
    const official = Server(
      id: 'official-9',
      name: 'Fortiva DE Nuremberg (CDN)',
      country: 'Germany',
      city: 'Nuremberg',
      connectionUri: 'vless://s@198.51.100.215:443?type=ws&security=tls#cdn',
      flagEmoji: '🇩🇪',
    );

    test(
      'is checked on its own, dialled first, and kept when it works',
      () async {
        final vpn = _FakeVpn({official.pathKey});
        probeResults = {official.pathKey: 90};
        final f = flow(vpn);

        await f.connect(paths, preferred: hel1, picked: official);

        expect(f.stage, ConnectStage.done);
        expect(f.chosen, official);
        expect(vpn.dialled, [official.pathKey]);
        // Only the pick: none of the own doors.
        expect(probed, [official.pathKey]);
        // A shared link reaches no scoreboard of our doors.
        expect(reported, isEmpty);
      },
    );

    // On Tehran day 2026-10-23, 165 picked links were dialled with no
    // check, 71% of them dead, at about 21 seconds a dead dial.
    test(
      'found closed is not dialled, and the own doors follow at once',
      () async {
        final vpn = _FakeVpn({official.pathKey, hel2.pathKey});
        probeResults = {hel2.pathKey: 180};
        final f = flow(vpn);

        await f.connect(paths, preferred: hel1, picked: official);

        // Its tunnel would have come up, but its check found it closed.
        expect(vpn.dialled, [hel2.pathKey]);
        expect(probed, [official.pathKey, hel1.pathKey, hel2.pathKey]);
        expect(f.stage, ConnectStage.done);
        expect(f.chosen, hel2);
        // Found closed is not a failure: it goes to the back of the next
        // fallback and is never skipped for it.
        final memory = PathMemory();
        expect(
          await memory.failedToday('mobile:Irancell'),
          contains(official.pathKey),
        );
        expect(await memory.skippable('mobile:Irancell'), isEmpty);
      },
    );

    test('that fails does not end the tap: the own doors follow', () async {
      final vpn = _FakeVpn({hel2.pathKey});
      probeResults = {official.pathKey: 90, hel2.pathKey: 180};
      final switched = <Server>[];
      final f = flow(vpn);

      await f.connect(
        paths,
        preferred: hel1,
        picked: official,
        onSwitchedServer: switched.add,
      );

      expect(vpn.dialled, [official.pathKey, hel2.pathKey]);
      expect(probed, [official.pathKey, hel1.pathKey, hel2.pathKey]);
      expect(f.stage, ConnectStage.done);
      expect(f.chosen, hel2);
      // hel2 is a door of the preferred server, so the selection stays.
      expect(switched, isEmpty);
      expect(await PathMemory().recall('mobile:Irancell'), hel2.pathKey);
    });

    test('that fails is followed by the remembered door', () async {
      await PathMemory().remember('mobile:Irancell', hel2.pathKey);
      final vpn = _FakeVpn({hel2.pathKey});
      probeResults = {official.pathKey: 90};
      final f = flow(vpn);

      await f.connect(paths, preferred: hel1, picked: official);

      expect(vpn.dialled, [official.pathKey, hel2.pathKey]);
      expect(probed, [official.pathKey]);
      expect(f.stage, ConnectStage.done);
    });

    test('shares the attempt id with the doors that follow it', () async {
      final vpn = _FakeVpn({hel1.pathKey});
      probeResults = {official.pathKey: 90, hel1.pathKey: 50};
      final f = flow(vpn);

      await f.connect(paths, preferred: hel1, picked: official);

      expect(vpn.dialledAttemptIds, hasLength(2));
      expect(vpn.dialledAttemptIds.toSet(), hasLength(1));
    });
  });

  group('when no own door carries a tunnel, shared links', () {
    // 2026-10-05, a phone on home wifi: every door of its own blocked,
    // France and Spain picked and dead, Estonia connected a minute before.
    Server shared(String name, String host) => Server(
      id: 'telegram-$name',
      name: name,
      country: name,
      city: '',
      connectionUri: 'vless://s@$host:443?type=tcp&security=reality#$name',
      flagEmoji: '🌍',
    );
    final estonia = shared('Estonia', 'ee.example');
    final france = shared('France', 'fr.example');
    final spain = shared('Spain', 'es.example');

    test(
      'are checked after the own doors, and the open one connects',
      () async {
        final vpn = _FakeVpn({spain.pathKey});
        probeResults = {spain.pathKey: 240};
        final onShared = <Server>[];
        final f = flow(vpn);

        await f.connect(
          paths,
          preferred: hel1,
          shared: () async => [france, spain, estonia],
          onShared: onShared.add,
        );
        await Future.delayed(Duration.zero);

        expect(probed, [
          hel1.pathKey,
          hel2.pathKey,
          fsn1.pathKey,
          france.pathKey,
          spain.pathKey,
        ]);
        expect(f.stage, ConnectStage.done);
        expect(f.chosen, spain);
        expect(onShared, [spain]);
        // One checklist: the own rows stay on screen above the shared ones,
        // and the search stopped at the open one.
        expect(f.checks.map((c) => c.path), [
          hel1,
          hel2,
          fsn1,
          france,
          spain,
          estonia,
        ]);
        expect(f.checks.last.state, PathCheckState.pending);
        // Only the own doors reach the scoreboard.
        expect(reported.single.map((p) => p['server_host']), [
          'hel',
          'hel',
          'fsn',
        ]);
        expect(
          await PathMemory().recallShared('mobile:Irancell'),
          spain.pathKey,
        );
        // The own door memory is untouched by a shared link.
        expect(await PathMemory().recall('mobile:Irancell'), isNull);
      },
    );

    test('start with the one that last worked on this network', () async {
      await PathMemory().rememberShared('mobile:Irancell', estonia.pathKey);
      final vpn = _FakeVpn({estonia.pathKey});
      probeResults = {estonia.pathKey: 300};
      final f = flow(vpn);

      await f.connect(
        paths,
        preferred: hel1,
        shared: () async => [france, estonia],
      );

      expect(probed.skip(3), [estonia.pathKey]);
      expect(f.chosen, estonia);
    });

    test('never include the pick that just failed', () async {
      // France probes open, so it would be dialled a second time if it
      // were among the candidates.
      final vpn = _FakeVpn({spain.pathKey});
      probeResults = {france.pathKey: 90, spain.pathKey: 150};
      final f = flow(vpn);

      await f.connect(
        paths,
        preferred: hel1,
        picked: france,
        shared: () async => [france, spain, estonia],
      );

      expect(vpn.dialled, [france.pathKey, spain.pathKey]);
      // France's own check before its dial, then the own doors, then the
      // fallback, which leaves France out.
      expect(probed.first, france.pathKey);
      expect(probed.skip(4), [spain.pathKey]);
      expect(f.stage, ConnectStage.done);
    });

    test('one open whose tunnel fails ends the run on that link', () async {
      final vpn = _FakeVpn({});
      probeResults = {spain.pathKey: 200};
      final f = flow(vpn);

      await f.connect(paths, preferred: hel1, shared: () async => [spain]);

      expect(vpn.dialled, [spain.pathKey]);
      expect(f.stage, ConnectStage.failed);
      expect(f.chosen, spain);
    });

    test('none open leaves the own door\'s error on screen', () async {
      final vpn = _FakeVpn({});
      probeResults = {hel1.pathKey: 50};
      final f = flow(vpn);

      await f.connect(paths, preferred: hel1, shared: () async => [spain]);

      expect(probed, [hel1.pathKey, spain.pathKey]);
      expect(f.stage, ConnectStage.failed);
      expect(f.chosen, hel1);
      expect(vpn.clears, 0);
      expect(vpn.status, VpnStatus.error);
    });

    test('are not tried after the VPN permission was refused', () async {
      final vpn = _FakeVpn({spain.pathKey})..refusePermission = true;
      probeResults = {hel1.pathKey: 50, spain.pathKey: 200};
      final f = flow(vpn);

      await f.connect(paths, preferred: hel1, shared: () async => [spain]);

      expect(probed, [hel1.pathKey]);
      expect(vpn.dialled, [hel1.pathKey]);
      expect(f.stage, ConnectStage.failed);
    });

    test('skip links that failed three times today on this network', () async {
      final m = PathMemory();
      for (var i = 0; i < 3; i++) {
        await m.markFailed('mobile:Irancell', france.pathKey);
      }
      final vpn = _FakeVpn({spain.pathKey});
      probeResults = {spain.pathKey: 150};
      final f = flow(vpn);

      await f.connect(
        paths,
        preferred: hel1,
        shared: () async => [france, spain],
      );

      expect(probed.skip(3), [spain.pathKey]);
      expect(f.chosen, spain);
    });

    test('follow an own door that was open but failed to connect', () async {
      final vpn = _FakeVpn({spain.pathKey});
      probeResults = {hel1.pathKey: 50, spain.pathKey: 200};
      final f = flow(vpn);

      await f.connect(paths, preferred: hel1, shared: () async => [spain]);

      expect(vpn.dialled, [hel1.pathKey, spain.pathKey]);
      expect(f.stage, ConnectStage.done);
      expect(f.chosen, spain);
    });

    test('that are all closed end at nothing open, as before', () async {
      final vpn = _FakeVpn({});
      final f = flow(vpn);

      await f.connect(
        paths,
        preferred: hel1,
        shared: () async => [france, spain],
      );

      expect(probed.skip(3), [france.pathKey, spain.pathKey]);
      expect(f.stage, ConnectStage.nothingOpen);
      expect(vpn.dialled, isEmpty);
    });

    test('are not tried once the allowance is spent', () async {
      final vpn = _FakeVpn({spain.pathKey});
      probeResults = {spain.pathKey: 200};
      final f = flow(vpn);

      await f.connect(
        paths,
        preferred: hel1,
        shared: () async => [spain],
        allowanceSpent: () async => true,
      );

      expect(probed, [hel1.pathKey, hel2.pathKey, fsn1.pathKey]);
      expect(f.stage, ConnectStage.idle);
      expect(vpn.dialled, isEmpty);
    });

    test('are asked for only once every own door has failed', () async {
      var asked = 0;
      final probedWhenAsked = <int>[];
      Future<List<Server>> counted() async {
        asked++;
        probedWhenAsked.add(probed.length);
        return [spain];
      }

      // An own door carries the tunnel: the shared links are not needed.
      probeResults = {hel1.pathKey: 50};
      await flow(
        _FakeVpn({hel1.pathKey}),
      ).connect(paths, preferred: hel1, shared: counted);
      expect(asked, 0);

      // Every own door closed: asked once, after the last of them.
      probed.clear();
      probeResults = {};
      await flow(_FakeVpn({})).connect(paths, preferred: hel1, shared: counted);
      expect(asked, 1);
      expect(probedWhenAsked, [paths.length]);
    });

    test('that cannot be given count as none', () async {
      final vpn = _FakeVpn({});
      final f = flow(vpn);

      await f.connect(
        paths,
        preferred: hel1,
        shared: () async => throw StateError('no list'),
      );

      expect(f.stage, ConnectStage.nothingOpen);
      expect(probed, [hel1.pathKey, hel2.pathKey, fsn1.pathKey]);
    });

    // 2026-10-07: every tap checked the same few links at the top of a
    // list of 156 and ended at "All routes are blocked".
    test('found closed on one tap go to the back on the next', () async {
      final links = [for (var i = 0; i < 8; i++) shared('L$i', 'l$i.example')];
      final keys = [for (final l in links) l.pathKey];
      final vpn = _FakeVpn({});

      await flow(
        vpn,
      ).connect(paths, preferred: hel1, shared: () async => links);
      expect(probed.skip(3), keys.take(ConnectFlow.sharedFallbackLimit));

      probed.clear();
      await flow(
        vpn,
      ).connect(paths, preferred: hel1, shared: () async => links);
      expect(probed.skip(3), [
        keys[6],
        keys[7],
        ...keys.take(ConnectFlow.sharedFallbackLimit - 2),
      ]);
    });

    // A closed check only reorders. A short list is checked on every tap,
    // so a link that opens later in the day still connects.
    test('found closed are still checked when nothing else is left', () async {
      final vpn = _FakeVpn({});
      for (var tap = 0; tap < 4; tap++) {
        probed.clear();
        await flow(
          vpn,
        ).connect(paths, preferred: hel1, shared: () async => [france, spain]);
        expect(probed.skip(3), [france.pathKey, spain.pathKey]);
      }

      vpn.works.add(spain.pathKey);
      probeResults = {spain.pathKey: 200};
      final f = flow(vpn);
      await f.connect(
        paths,
        preferred: hel1,
        shared: () async => [france, spain],
      );
      expect(f.stage, ConnectStage.done);
      expect(f.chosen, spain);
    });

    // A carrier once closed every link for a while, and the links that
    // worked the rest of the day stayed behind the others until it ended.
    // The backend's closed period sends them back to their place.
    test('found closed come back to their place after the backend\'s '
        'closed period', () async {
      var clock = DateTime.utc(2026, 10, 22, 12);
      final links = [for (var i = 0; i < 8; i++) shared('L$i', 'l$i.example')];
      final keys = [for (final l in links) l.pathKey];
      final vpn = _FakeVpn({});
      ConnectFlow timed() => ConnectFlow(
        vpn: vpn,
        memory: PathMemory(now: () => clock),
        finder: PathFinder(
          probe: (p) async {
            probed.add(p.pathKey);
            return probeResults[p.pathKey] ?? -1;
          },
          internet: () async => true,
        ),
        reporter: VpnEventReporter(
          send: (_, _, _) async {},
          sendProbes: (_, probes, _) async => reported.add(probes),
          deviceId: () async => 'DEV-1',
          appVersion: () async => '1.5.0',
          platform: 'android',
          networkType: () async => 'mobile',
        ),
        networkKey: () async => 'mobile:Irancell',
        carrier: () async => 'Irancell',
        checklist: () => const ChecklistSettings(
          fallback: FallbackSettings(
            links: 6,
            parallel: 1,
            closedFor: Duration(minutes: 30),
          ),
        ),
        attemptTimeout: const Duration(seconds: 2),
      );

      await timed().connect(paths, preferred: hel1, shared: () async => links);
      expect(probed.skip(3), keys.take(6));

      // Inside the period: the ones found closed wait behind the others.
      probed.clear();
      clock = clock.add(const Duration(minutes: 10));
      await timed().connect(paths, preferred: hel1, shared: () async => links);
      expect(probed.skip(3), [keys[6], keys[7], ...keys.take(4)]);

      // After it, the backend's order again, with the ones the last tap
      // found closed at the back.
      probed.clear();
      clock = clock.add(const Duration(minutes: 25));
      await timed().connect(paths, preferred: hel1, shared: () async => links);
      expect(probed.skip(3), [
        keys[4],
        keys[5],
        keys[0],
        keys[1],
        keys[2],
        keys[3],
      ]);

      // A tap long after both: the backend's order as given.
      probed.clear();
      clock = clock.add(const Duration(hours: 1));
      vpn.works.add(keys[0]);
      probeResults = {keys[0]: 200};
      final f = timed();
      await f.connect(paths, preferred: hel1, shared: () async => links);
      expect(probed.skip(3).first, keys[0]);
      expect(f.chosen, links[0]);
    });

    // Our own shared link on a server reaches it under the same name as
    // that server's Cloudflare door. A carrier that filters the name
    // closes both.
    test('under the name of an own door found closed go after the '
        'others', () async {
      final cdnDoor = Server(
        id: 'dedicated-cdn.example:443',
        name: 'cdn',
        country: '',
        city: '',
        connectionUri:
            'vless://u@198.51.100.215:443?type=ws&security=tls'
            '&sni=cdn.example#cdn',
        flagEmoji: '🌍',
        isDedicated: true,
        door: 'ws-tls',
        serverId: 7,
      );
      final official = Server(
        id: 'official-7',
        name: 'Official',
        country: '',
        city: '',
        connectionUri:
            'vless://o@198.51.100.215:443?type=ws&security=tls'
            '&sni=cdn.example&host=cdn.example#official',
        flagEmoji: '🌍',
      );
      final vpn = _FakeVpn({spain.pathKey});
      probeResults = {spain.pathKey: 200};
      final f = flow(vpn);

      await f.connect(
        [hel1, cdnDoor],
        preferred: hel1,
        shared: () async => [official, spain],
      );

      expect(probed, [hel1.pathKey, cdnDoor.pathKey, spain.pathKey]);
      expect(f.chosen, spain);
    });

    test('a pick that connects is remembered for the next fallback', () async {
      final vpn = _FakeVpn({estonia.pathKey});
      probeResults = {estonia.pathKey: 120};
      final f = flow(vpn);

      await f.connect(paths, preferred: hel1, picked: estonia);

      expect(f.stage, ConnectStage.done);
      expect(
        await PathMemory().recallShared('mobile:Irancell'),
        estonia.pathKey,
      );
    });
  });

  test('the chosen server goes first, then the rest', () async {
    final vpn = _FakeVpn({fsn1.pathKey});
    probeResults = {fsn1.pathKey: 60};
    final f = flow(vpn);
    await f.connect(paths, preferred: fsn1);
    expect(probed, [fsn1.pathKey]);
  });

  test('a tap during the checklist cancels it', () async {
    final vpn = _FakeVpn({});
    late ConnectFlow f;
    f = ConnectFlow(
      vpn: vpn,
      memory: PathMemory(),
      finder: PathFinder(
        probe: (p) async {
          f.cancel();
          return -1;
        },
        internet: () async => true,
      ),
      reporter: VpnEventReporter(
        send: (_, _, _) async {},
        sendProbes: (_, _, _) async {},
        deviceId: () async => 'DEV-1',
        appVersion: () async => '1.5.0',
        platform: 'android',
        networkType: () async => 'mobile',
      ),
      networkKey: () async => 'wifi',
      carrier: () async => null,
    );
    await f.connect(paths, preferred: hel1);
    expect(f.stage, ConnectStage.cancelled);
    expect(vpn.dialled, isEmpty);
  });

  test('a second tap while busy is ignored', () async {
    final vpn = _FakeVpn({hel1.pathKey});
    probeResults = {hel1.pathKey: 40};
    final f = flow(vpn);
    final first = f.connect(paths, preferred: hel1);
    await f.connect(paths, preferred: hel1);
    await first;
    expect(vpn.dialled, [hel1.pathKey]);
  });

  test(
    'the door checks and the dial that follows share one attempt id',
    () async {
      // The probes are written before the tunnel events and land in a
      // different table. Without a shared id the order a phone tried its
      // doors in cannot be read back, and the attempt is the unit anything
      // learns over.
      final vpn = _FakeVpn({hel2.pathKey});
      probeResults = {hel2.pathKey: 180};
      final f = flow(vpn);

      await f.connect(paths, preferred: hel1);

      expect(vpn.dialledAttemptIds, hasLength(1));
      final id = vpn.dialledAttemptIds.single;
      expect(id, isNotNull);
      expect(id, hasLength(32));
      expect(reported, hasLength(1));
      for (final probe in reported.single) {
        expect(probe['attempt_id'], id);
      }
      // And the checks are numbered, so a door that wins first can be told
      // apart from one that wins sixth.
      expect(reported.single.map((p) => p['position']), [1, 2]);
    },
  );

  group('a device that has used up its allowance', () {
    // The backend turns the device's servers off, and from the phone that
    // looks like every one of them being dead.

    test(
      'a remembered door that fails ends the tap, with no checklist',
      () async {
        await PathMemory().remember('mobile:Irancell', hel2.pathKey);
        final vpn = _FakeVpn({});
        final f = flow(vpn);
        var asked = 0;

        await f.connect(
          paths,
          preferred: hel1,
          allowanceSpent: () async {
            asked++;
            return true;
          },
        );

        expect(asked, 1);
        expect(f.stage, ConnectStage.idle);
        expect(vpn.dialled, [hel2.pathKey]);
        expect(probed, isEmpty);
        expect(reported, isEmpty);
        // The door was turned off for this device. It did not stop working
        // on this network, and it is dialled first again once the allowance
        // refills.
        expect(await PathMemory().recall('mobile:Irancell'), hel2.pathKey);
      },
    );

    test('every door closed is not reported as a block', () async {
      final vpn = _FakeVpn({});
      final f = flow(vpn);

      await f.connect(paths, preferred: hel1, allowanceSpent: () async => true);

      expect(f.stage, ConnectStage.idle);
      expect(probed, hasLength(3));
      expect(reported, isEmpty);
      expect(vpn.dialled, isEmpty);
    });

    test(
      'an open door that fails on connect is not remembered as failed',
      () async {
        final vpn = _FakeVpn({});
        probeResults = {hel1.pathKey: 120};
        final f = flow(vpn);

        await f.connect(
          paths,
          preferred: hel1,
          allowanceSpent: () async => true,
        );

        expect(f.stage, ConnectStage.idle);
        expect(vpn.dialled, [hel1.pathKey]);
        expect(await PathMemory().skippable('mobile:Irancell'), isEmpty);
      },
    );

    test('with allowance left the flow goes on as before', () async {
      await PathMemory().remember('mobile:Irancell', hel2.pathKey);
      final vpn = _FakeVpn({fsn1.pathKey});
      probeResults = {fsn1.pathKey: 200};
      final f = flow(vpn);

      await f.connect(
        paths,
        preferred: hel1,
        allowanceSpent: () async => false,
      );

      expect(f.stage, ConnectStage.done);
      expect(f.chosen, fsn1);
      expect(reported, hasLength(1));
    });

    test('a backend that cannot be asked does not hold the flow up', () async {
      await PathMemory().remember('mobile:Irancell', hel2.pathKey);
      final vpn = _FakeVpn({fsn1.pathKey});
      probeResults = {fsn1.pathKey: 200};
      final f = flow(vpn);

      await f.connect(
        paths,
        preferred: hel1,
        allowanceSpent: () async {
          if (vpn.dialled.isNotEmpty) throw Exception('no route');
          return false;
        },
      );

      expect(f.stage, ConnectStage.done);
      expect(f.chosen, fsn1);
    });

    test('a failed shared link does not ask: nothing meters it', () async {
      final shared = Server(
        id: 'official-1',
        name: 'shared',
        country: '',
        city: 'shared',
        connectionUri: 'vless://u@shared:443?type=tcp#shared',
        flagEmoji: '🌍',
      );
      final vpn = _FakeVpn({hel1.pathKey});
      // The pick's check passes, and its tunnel fails.
      probeResults = {shared.pathKey: 80, hel1.pathKey: 120};
      final f = flow(vpn);
      var asked = 0;

      await f.connect(
        paths,
        preferred: hel1,
        picked: shared,
        allowanceSpent: () async {
          asked++;
          return true;
        },
      );

      // Not asked: the pick's failure is a shared link's, and no own door
      // failed.
      expect(asked, 0);
      expect(vpn.dialled, [shared.pathKey, hel1.pathKey]);
      expect(f.stage, ConnectStage.done);
      expect(f.chosen, hel1);
    });
  });

  // On 2026-10-20, 12 taps in 24 hours had a tunnel that came up on a phone
  // with internet and carried nothing, and the tap ended there; 6 of those
  // phones connected through another door within 2 minutes, on a later tap.
  // And 28 such taps came from phones the diagnosis found offline, while
  // the line under the button said the path was open.
  group('a tunnel that came up and carried nothing', () {
    test('the next own door is checked and dialled in the same tap', () async {
      final vpn = _FakeVpn({hel2.pathKey})..starve.add(hel1.pathKey);
      probeResults = {hel1.pathKey: 100, hel2.pathKey: 120};
      final f = flow(vpn);

      await f.connect(paths, preferred: hel1);

      expect(vpn.dialled, [hel1.pathKey, hel2.pathKey]);
      // Several checks at once by default, so fsn1 may be checked beside
      // hel2; the first open one in the checklist's order is dialled.
      expect(probed.take(2), [hel1.pathKey, hel2.pathKey]);
      expect(f.stage, ConnectStage.done);
      expect(f.chosen, hel2);
      // One tap: both dials carry its attempt id.
      expect(vpn.dialledAttemptIds.toSet(), hasLength(1));
      expect(await PathMemory().recall('mobile:Irancell'), hel2.pathKey);
      expect(
        await PathMemory().failedToday('mobile:Irancell'),
        contains(hel1.pathKey),
      );
      // The rows checked after the dial go to the backend too.
      expect([
        for (final batch in reported)
          for (final row in batch) row['door'],
      ], contains('xhttp-reality'));
    });

    test('a tunnel that never came up goes on as before, with no more own '
        'doors', () async {
      final vpn = _FakeVpn({hel2.pathKey});
      probeResults = {hel1.pathKey: 100, hel2.pathKey: 120};
      final f = flow(vpn);

      await f.connect(paths, preferred: hel1);

      expect(vpn.dialled, [hel1.pathKey]);
      expect(probed, [hel1.pathKey]);
      expect(f.stage, ConnectStage.failed);
    });

    test('only one more door: a second starved tunnel ends the tap', () async {
      final vpn = _FakeVpn({})
        ..starve.addAll([hel1.pathKey, hel2.pathKey, fsn1.pathKey]);
      probeResults = {hel1.pathKey: 100, hel2.pathKey: 120, fsn1.pathKey: 90};
      final f = flow(vpn);

      await f.connect(paths, preferred: hel1);

      expect(vpn.dialled, [hel1.pathKey, hel2.pathKey]);
      expect(f.stage, ConnectStage.failed);
      final failed = await PathMemory().failedToday('mobile:Irancell');
      expect(failed, containsAll([hel1.pathKey, hel2.pathKey]));
    });

    test('the door the core had moved to is not dialled again', () async {
      final vpn = _FakeVpn({fsn1.pathKey})
        ..starve.add(hel1.pathKey)
        ..leftOnDoor = hel2;
      probeResults = {hel1.pathKey: 100, hel2.pathKey: 120, fsn1.pathKey: 90};
      final f = flow(vpn);

      await f.connect(paths, preferred: hel1);

      expect(vpn.dialled, [hel1.pathKey, fsn1.pathKey]);
      expect(probed, [hel1.pathKey, fsn1.pathKey]);
      expect(f.stage, ConnectStage.done);
    });

    test('a door skipped for the day is not taken', () async {
      final memory = PathMemory();
      final vpn = _FakeVpn({hel2.pathKey})..starve.add(hel1.pathKey);
      // hel2 failed often enough today on this network to be skipped.
      for (var i = 0; i < 5; i++) {
        await memory.markFailed('mobile:Irancell', hel2.pathKey);
      }
      final skipped = await memory.skippable(
        'mobile:Irancell',
        holding: [for (final p in paths) p.pathKey],
      );
      probeResults = {hel1.pathKey: 100, hel2.pathKey: 120};
      final f = flow(vpn);

      await f.connect(paths, preferred: hel1);

      expect(skipped, contains(hel2.pathKey));
      expect(vpn.dialled, isNot(contains(hel2.pathKey)));
      expect(vpn.dialled.first, hel1.pathKey);
    });

    test(
      'with the phone offline it ends at no internet and keeps the door',
      () async {
        final vpn = _FakeVpn({})
          ..starve.add(hel1.pathKey)
          ..verdict = FailureVerdict.noInternet;
        probeResults = {hel1.pathKey: 100};
        final f = flow(vpn);

        await f.connect(paths, preferred: hel1);

        expect(vpn.dialled, [hel1.pathKey]);
        expect(f.stage, ConnectStage.noInternet);
        expect(
          await PathMemory().failedToday('mobile:Irancell'),
          isNot(contains(hel1.pathKey)),
        );
      },
    );

    test('with only the way abroad cut it ends at the cut', () async {
      final vpn = _FakeVpn({})
        ..starve.add(hel1.pathKey)
        ..verdict = FailureVerdict.cutOff;
      probeResults = {hel1.pathKey: 100};
      final f = flow(vpn);

      await f.connect(paths, preferred: hel1);

      expect(f.stage, ConnectStage.cutOff);
      expect(
        await PathMemory().failedToday('mobile:Irancell'),
        isNot(contains(hel1.pathKey)),
      );
    });

    test('a door found open after an offline verdict says the phone is '
        'online', () async {
      final vpn = _FakeVpn({hel2.pathKey})
        ..starve.add(hel1.pathKey)
        ..verdict = FailureVerdict.noInternet;
      probeResults = {hel1.pathKey: 100, hel2.pathKey: 120};
      final f = flow(vpn);

      await f.connect(paths, preferred: hel1);

      expect(vpn.dialled, [hel1.pathKey, hel2.pathKey]);
      expect(f.stage, ConnectStage.done);
      expect(
        await PathMemory().failedToday('mobile:Irancell'),
        contains(hel1.pathKey),
      );
    });

    test('a tunnel that never came up on an offline phone ends at no '
        'internet too', () async {
      final vpn = _FakeVpn({})..verdict = FailureVerdict.noInternet;
      probeResults = {hel1.pathKey: 100};
      final f = flow(vpn);

      await f.connect(paths, preferred: hel1);

      expect(vpn.dialled, [hel1.pathKey]);
      expect(f.stage, ConnectStage.noInternet);
    });

    test(
      'a door that failed with a verdict about the server ends at failed',
      () async {
        final vpn = _FakeVpn({})
          ..starve.add(hel1.pathKey)
          ..verdict = FailureVerdict.throttled;
        probeResults = {hel1.pathKey: 100};
        final f = flow(vpn);

        await f.connect(paths, preferred: hel1);

        expect(f.stage, ConnectStage.failed);
        expect(
          await PathMemory().failedToday('mobile:Irancell'),
          contains(hel1.pathKey),
        );
      },
    );
  });
}
