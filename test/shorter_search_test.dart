import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/core/state/connect_flow.dart';
import 'package:fortiva_vpn/data/models/checklist_settings.dart';
import 'package:fortiva_vpn/data/models/server.dart';
import 'package:fortiva_vpn/services/connect_trace.dart';
import 'package:fortiva_vpn/services/door_sweep.dart';
import 'package:fortiva_vpn/services/ipv6_reach.dart';
import 'package:fortiva_vpn/services/path_finder.dart';
import 'package:fortiva_vpn/services/path_memory.dart';
import 'package:fortiva_vpn/services/vpn_event_reporter.dart';
import 'package:fortiva_vpn/services/vpn_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A shorter search, from the plan of Tehran day 2026-10-23.
///
/// That day a tap that ended on a shared link took a median of 26.8
/// seconds, 113 dials of the remembered door failed at about 21 seconds
/// each before the checklist started, and 564 taps were stopped, on 159
/// phones, after 10 to 15 seconds.
///
/// - The checklist starts beside a dial of the remembered door that has not
///   verified within FastPathSettings.besideAfter.
/// - A stop after FastPathSettings.forgetAfter forgets that door for the
///   next tap, without counting a failure.
/// - So does a leave of that dial for a door found open, and a stop after
///   the dial failed by itself but before the failure was written down.
/// - The allowance question is asked once in a try, at its first failure.
Server door(String host, String door, {int? serverId}) => Server(
  id: 'dedicated-$host:443',
  name: host,
  country: '',
  city: host,
  connectionUri: 'vless://u@$host:443?type=tcp#$host',
  flagEmoji: '',
  isDedicated: true,
  door: door,
  doorLabel: door,
  serverId: serverId,
);

/// A tunnel whose dials settle as each door says: a door in [held] waits
/// on its completer, one in [checking] comes up after [takes] and is in its
/// traffic check until its completer says whether it passed, one in
/// [works] comes up after [takes], and any other fails after [takes]. A
/// dial replaced by a newer one, or by a stop, changes nothing when it
/// settles.
class _Vpn extends VpnService {
  _Vpn({Set<String>? works})
    : works = works ?? {},
      super(events: VpnEventReporter(send: (_, _, _) async {}));

  final Set<String> works;
  final held = <String, Completer<bool>>{};
  final checking = <String, Completer<bool>>{};
  Duration takes = const Duration(milliseconds: 5);
  final dialled = <String>[];

  /// Whether the VPN permission dialog is on screen.
  bool permission = false;

  VpnStatus _status = VpnStatus.disconnected;
  int _dial = 0;
  bool _verifying = false;
  int _misses = 0;

  @override
  VpnStatus get status => _status;

  @override
  bool get isConnected => _status == VpnStatus.connected;

  @override
  bool get isConnecting => _status == VpnStatus.connecting;

  @override
  bool get isVerifying => _verifying;

  @override
  int get trafficMisses => _verifying ? _misses : 0;

  @override
  bool get awaitingPermission => permission;

  /// A pass of the traffic check through the tunnel being checked fails.
  void miss() {
    _misses++;
    notifyListeners();
  }

  @override
  Future<void> connect(
    Server server, {
    String? attemptId,
    List<Server> standby = const [],
    LinkSource? source,
  }) async {
    final me = ++_dial;
    dialled.add(server.pathKey);
    _verifying = false;
    _misses = 0;
    _status = VpnStatus.connecting;
    notifyListeners();
    final check = checking[server.pathKey];
    if (check != null) {
      await Future<void>.delayed(takes);
      if (me != _dial) return;
      _status = VpnStatus.connected;
      _verifying = true;
      notifyListeners();
      final passed = await check.future;
      if (me != _dial) return;
      _verifying = false;
      if (!passed) _status = VpnStatus.error;
      notifyListeners();
      return;
    }
    final hold = held[server.pathKey];
    final bool up;
    if (hold != null) {
      up = await hold.future;
    } else {
      await Future<void>.delayed(takes);
      up = works.contains(server.pathKey);
    }
    if (me != _dial) return;
    _status = up ? VpnStatus.connected : VpnStatus.error;
    notifyListeners();
  }

  @override
  Future<void> disconnect() async {
    _dial++;
    _verifying = false;
    _status = VpnStatus.disconnected;
    notifyListeners();
  }

  @override
  void clearError() {
    if (_status == VpnStatus.error) _status = VpnStatus.disconnected;
    notifyListeners();
  }
}

/// Keeps every trace the flow starts, and sends none.
class _Traces extends ConnectTraces {
  _Traces() : super(enabled: () => true);

  final started = <ConnectTrace>[];

  @override
  ConnectTrace? start(String attemptId) {
    final trace = ConnectTrace(attemptId: attemptId, startedAt: DateTime.now());
    started.add(trace);
    return trace;
  }

  @override
  Future<void> send(ConnectTrace trace) async {}
}

/// A memory whose forget lands only once [landed] completes.
class _SlowForget extends PathMemory {
  final landed = Completer<void>();

  @override
  Future<void> forget(String network, String pathKey) async {
    await landed.future;
    await super.forget(network, pathKey);
  }
}

/// Waits until [ok] holds, failing the test after [within].
Future<void> until(
  bool Function() ok, {
  Duration within = const Duration(seconds: 5),
}) async {
  final end = DateTime.now().add(within);
  while (!ok()) {
    if (DateTime.now().isAfter(end)) fail('still waiting after $within');
    await Future<void>.delayed(const Duration(milliseconds: 2));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const network = 'mobile:Irancell';
  final hel1 = door('hel', 'tcp-reality', serverId: 7);
  final hel2 = door('hel', 'xhttp-reality', serverId: 7);
  final fsn1 = door('fsn', 'tcp-reality', serverId: 8);
  final paths = [hel1, hel2, fsn1];

  /// Short times, so the tests run in milliseconds.
  const soon = Duration(milliseconds: 60);
  const shortPath = FastPathSettings(besideAfter: soon, forgetAfter: soon);

  late Set<String> openHere;
  late Duration probeTakes;
  late List<String> probed;
  late List<List<Map<String, dynamic>>> reported;
  late _Traces traces;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    openHere = {};
    probeTakes = const Duration(milliseconds: 10);
    probed = [];
    reported = [];
    traces = _Traces();
  });

  ConnectFlow flow(
    _Vpn vpn, {
    FastPathSettings? fastPath = shortPath,
    bool checksBesideDial = true,
    Duration attemptTimeout = const Duration(seconds: 3),
    PathMemory? memory,
    RetrySettings? retry,
    bool internet = true,
  }) {
    final reporter = VpnEventReporter(
      send: (_, _, _) async {},
      sendProbes: (_, probes, _) async => reported.add(probes),
      deviceId: () async => 'DEV-1',
      appVersion: () async => '2.2.0',
      platform: 'android',
      networkType: () async => 'mobile',
      queues: const [],
    );
    final f = ConnectFlow(
      vpn: vpn,
      memory: memory ?? PathMemory(),
      finder: PathFinder(
        read: (p) async {
          probed.add(p.pathKey);
          await Future<void>.delayed(probeTakes);
          return openHere.contains(p.pathKey)
              ? const DoorOutcome(ms: 120, tcpMs: 40, phase: 'ok')
              : const DoorOutcome(ms: -1, error: 'tcp timeout', phase: 'tcp');
        },
        internet: () async => internet,
      ),
      reporter: reporter,
      sweep: DoorSweep(appBypassesTunnel: checksBesideDial, reporter: reporter),
      ipv6: Ipv6Reach(route: () async => null),
      networkKey: () async => network,
      carrier: () async => 'Irancell',
      checklist: () => ChecklistSettings(
        doors: const DoorCheckSettings(parallel: 4, stagger: Duration.zero),
        fastPath: fastPath,
        retry: retry,
      ),
      traces: traces,
      attemptTimeout: attemptTimeout,
    );
    addTearDown(f.cancel);
    return f;
  }

  group('the checklist beside the remembered door', () {
    test('starts once the dial has not verified in time, and a door it '
        'finds open is dialled instead', () async {
      await PathMemory().remember(network, hel1.pathKey);
      openHere = {hel2.pathKey};
      final vpn = _Vpn(works: {hel2.pathKey})
        ..held[hel1.pathKey] = Completer<bool>();
      final f = flow(vpn);
      final watch = Stopwatch()..start();

      await f.connect(paths);

      expect(f.stage, ConnectStage.done);
      expect(f.chosen, hel2);
      expect(vpn.dialled, [hel1.pathKey, hel2.pathKey]);
      // The search started beside the dial, not after its whole wait.
      expect(watch.elapsed, lessThan(const Duration(seconds: 2)));
      expect(probed.first, hel2.pathKey);
      expect(await PathMemory().recall(network), hel2.pathKey);
      // The remembered door was left, not failed.
      expect(await PathMemory().failedToday(network), isEmpty);
      final dial = traces.started.single.steps.first;
      expect(dial.stage, TraceStage.dial);
      expect(dial.result, TraceResult.fail);
      expect(dial.reason, TraceReason.timeout);
    });

    test('does not start before its time', () async {
      await PathMemory().remember(network, hel1.pathKey);
      openHere = {hel2.pathKey};
      final vpn = _Vpn(works: {hel1.pathKey})
        ..takes = const Duration(milliseconds: 20);
      final f = flow(vpn);

      await f.connect(paths);

      expect(f.chosen, hel1);
      expect(probed, isEmpty);
    });

    test(
      'stops when the dial verifies first, and its rows go nowhere',
      () async {
        await PathMemory().remember(network, hel1.pathKey);
        openHere = {hel2.pathKey};
        probeTakes = const Duration(milliseconds: 400);
        final hold = Completer<bool>();
        final vpn = _Vpn()..held[hel1.pathKey] = hold;
        final f = flow(vpn);

        final tap = f.connect(paths);
        await until(() => f.stage == ConnectStage.diagnosing);
        expect(probed, isNotEmpty);
        hold.complete(true);
        await tap;
        await Future<void>.delayed(const Duration(milliseconds: 500));

        expect(f.stage, ConnectStage.done);
        expect(f.chosen, hel1);
        expect(vpn.dialled, [hel1.pathKey]);
        expect(reported, isEmpty);
        expect(await PathMemory().recall(network), hel1.pathKey);
      },
    );

    test('goes on when the dial fails by itself, and the door is marked '
        'failed then', () async {
      await PathMemory().remember(network, hel1.pathKey);
      openHere = {fsn1.pathKey};
      probeTakes = const Duration(milliseconds: 100);
      final hold = Completer<bool>();
      final vpn = _Vpn(works: {fsn1.pathKey})..held[hel1.pathKey] = hold;
      final f = flow(vpn);

      final tap = f.connect(paths);
      await until(() => f.stage == ConnectStage.diagnosing);
      hold.complete(false);
      await tap;

      expect(f.chosen, fsn1);
      expect(vpn.dialled, [hel1.pathKey, fsn1.pathKey]);
      expect(await PathMemory().failedToday(network), {hel1.pathKey});
    });

    test('finding the remembered door itself open keeps waiting on its '
        'dial', () async {
      await PathMemory().remember(network, hel1.pathKey);
      openHere = {hel1.pathKey};
      final hold = Completer<bool>();
      final vpn = _Vpn()..held[hel1.pathKey] = hold;
      final f = flow(vpn);

      final tap = f.connect(paths);
      // The others are closed and the remembered door, checked last, is
      // open.
      await until(() => probed.length == paths.length);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(vpn.dialled, [hel1.pathKey]);
      hold.complete(true);
      await tap;

      expect(f.chosen, hel1);
      expect(vpn.dialled, [hel1.pathKey]);
    });

    test('never starts where a check during a dial reads the tunnel', () async {
      await PathMemory().remember(network, hel1.pathKey);
      openHere = {hel2.pathKey};
      final hold = Completer<bool>();
      final vpn = _Vpn(works: {hel2.pathKey})..held[hel1.pathKey] = hold;
      final f = flow(vpn, checksBesideDial: false);

      final tap = f.connect(paths);
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(probed, isEmpty);
      hold.complete(false);
      await tap;

      expect(f.chosen, hel2);
    });

    test('never starts when the backend turns it off', () async {
      await PathMemory().remember(network, hel1.pathKey);
      openHere = {hel2.pathKey};
      final hold = Completer<bool>();
      final vpn = _Vpn(works: {hel2.pathKey})..held[hel1.pathKey] = hold;
      final f = flow(vpn, fastPath: const FastPathSettings(forgetAfter: soon));

      final tap = f.connect(paths);
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(probed, isEmpty);
      hold.complete(false);
      await tap;

      expect(f.chosen, hel2);
    });

    test('waits while the VPN permission dialog is on screen', () async {
      await PathMemory().remember(network, hel1.pathKey);
      openHere = {hel2.pathKey};
      final hold = Completer<bool>();
      final vpn = _Vpn(works: {hel2.pathKey})
        ..held[hel1.pathKey] = hold
        ..permission = true;
      final f = flow(vpn);

      final tap = f.connect(paths);
      await Future<void>.delayed(const Duration(milliseconds: 250));
      expect(probed, isEmpty);
      // The user answers the dialog, and the clock starts then.
      vpn.permission = false;
      await until(() => probed.isNotEmpty);
      await tap;

      expect(f.chosen, hel2);
    });

    test('does not leave the dial while the VPN permission dialog is on '
        'screen, and leaves it once the user has answered', () async {
      await PathMemory().remember(network, hel1.pathKey);
      openHere = {hel2.pathKey};
      probeTakes = const Duration(milliseconds: 100);
      final vpn = _Vpn(works: {hel2.pathKey})
        ..held[hel1.pathKey] = Completer<bool>();
      final f = flow(vpn);

      final tap = f.connect(paths);
      await until(() => f.stage == ConnectStage.diagnosing);
      // The dialog comes up while the checklist runs beside the dial.
      vpn
        ..permission = true
        ..notifyListeners();
      await until(() => probed.contains(hel2.pathKey));
      await Future<void>.delayed(const Duration(milliseconds: 250));
      expect(vpn.dialled, [hel1.pathKey]);

      vpn
        ..permission = false
        ..notifyListeners();
      await tap;

      expect(f.chosen, hel2);
      expect(vpn.dialled, [hel1.pathKey, hel2.pathKey]);
    });
  });

  group('the checklist beside a dial whose tunnel is up', () {
    // Found 2026-10-23 in review: the dial was left as soon as another door
    // was found open, also while its tunnel was up and in its traffic
    // check, which a working door passes later than 5 s now and then.

    test('does not leave it during its first traffic check, and a pass '
        'keeps the remembered door', () async {
      await PathMemory().remember(network, hel1.pathKey);
      openHere = {hel2.pathKey};
      final verify = Completer<bool>();
      final vpn = _Vpn(works: {hel2.pathKey})..checking[hel1.pathKey] = verify;
      final f = flow(vpn);

      final tap = f.connect(paths);
      // The checklist beside the dial has found the other door open.
      await until(() => probed.contains(hel2.pathKey));
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(vpn.isVerifying, isTrue);
      expect(vpn.dialled, [hel1.pathKey]);
      verify.complete(true);
      await tap;

      expect(f.stage, ConnectStage.done);
      expect(f.chosen, hel1);
      expect(vpn.dialled, [hel1.pathKey]);
      expect(await PathMemory().recall(network), hel1.pathKey);
    });

    test('leaves it once a pass of its traffic check has failed, for the '
        'door found open', () async {
      await PathMemory().remember(network, hel1.pathKey);
      openHere = {hel2.pathKey};
      final vpn = _Vpn(works: {hel2.pathKey})
        ..checking[hel1.pathKey] = Completer<bool>();
      final f = flow(vpn);

      final tap = f.connect(paths);
      await until(() => probed.contains(hel2.pathKey));
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(vpn.dialled, [hel1.pathKey]);
      vpn.miss();
      await tap;

      expect(f.chosen, hel2);
      expect(vpn.dialled, [hel1.pathKey, hel2.pathKey]);
      // Left, not failed.
      expect(await PathMemory().failedToday(network), isEmpty);
      final dial = traces.started.single.steps.first;
      expect(dial.result, TraceResult.fail);
      expect(dial.reason, TraceReason.timeout);
    });

    test('a pass that failed before the door was found open leaves it as '
        'soon as it is', () async {
      await PathMemory().remember(network, hel1.pathKey);
      openHere = {hel2.pathKey};
      probeTakes = const Duration(milliseconds: 100);
      final vpn = _Vpn(works: {hel2.pathKey})
        ..checking[hel1.pathKey] = Completer<bool>();
      final f = flow(vpn);

      final tap = f.connect(paths);
      await until(() => f.stage == ConnectStage.diagnosing);
      vpn.miss();
      await tap;

      expect(f.chosen, hel2);
      expect(vpn.dialled, [hel1.pathKey, hel2.pathKey]);
    });

    test('a check that fails by itself hands over to the door found open, '
        'and the remembered door is marked failed', () async {
      await PathMemory().remember(network, hel1.pathKey);
      openHere = {hel2.pathKey};
      final verify = Completer<bool>();
      final vpn = _Vpn(works: {hel2.pathKey})..checking[hel1.pathKey] = verify;
      final f = flow(vpn);

      final tap = f.connect(paths);
      await until(() => probed.contains(hel2.pathKey));
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(vpn.dialled, [hel1.pathKey]);
      verify.complete(false);
      await tap;

      expect(f.chosen, hel2);
      expect(vpn.dialled, [hel1.pathKey, hel2.pathKey]);
      expect(await PathMemory().failedToday(network), {hel1.pathKey});
    });
  });

  group('a stop during the remembered door\'s dial', () {
    test('after forgetAfter forgets the door, without a failure, and the '
        'next tap starts with the checklist', () async {
      await PathMemory().remember(network, hel1.pathKey);
      final vpn = _Vpn(works: {hel1.pathKey})
        ..held[hel1.pathKey] = Completer<bool>();
      final f = flow(vpn, fastPath: const FastPathSettings(forgetAfter: soon));

      final tap = f.connect(paths);
      await until(() => vpn.dialled.isNotEmpty);
      await Future<void>.delayed(soon * 2);
      f.stop();
      await tap;

      expect(f.stage, ConnectStage.cancelled);
      expect(await PathMemory().recall(network), isNull);
      expect(await PathMemory().failedToday(network), isEmpty);
      expect(await PathMemory().skippable(network), isEmpty);

      // The next tap, at once: no dial of the forgotten door first.
      vpn.held.clear();
      openHere = {hel1.pathKey};
      await f.connect(paths);
      expect(probed.first, hel1.pathKey);
      expect(vpn.dialled, [hel1.pathKey, hel1.pathKey]);
      expect(f.chosen, hel1);
    });

    test('the next tap waits for that forget before it reads the '
        'memory', () async {
      await PathMemory().remember(network, hel1.pathKey);
      final memory = _SlowForget();
      final vpn = _Vpn(works: {hel1.pathKey})
        ..held[hel1.pathKey] = Completer<bool>();
      final f = flow(
        vpn,
        memory: memory,
        fastPath: const FastPathSettings(forgetAfter: soon),
      );

      final tap = f.connect(paths);
      await until(() => vpn.dialled.isNotEmpty);
      await Future<void>.delayed(soon * 2);
      f.stop();
      await tap;

      // A tap at once, while the forget is still being written.
      vpn.held.clear();
      openHere = {hel1.pathKey};
      final next = f.connect(paths);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(vpn.dialled, [hel1.pathKey]);
      memory.landed.complete();
      await next;

      expect(probed.first, hel1.pathKey);
      expect(vpn.dialled, [hel1.pathKey, hel1.pathKey]);
      expect(f.chosen, hel1);
    });

    test('while the checklist runs beside it forgets the door too', () async {
      await PathMemory().remember(network, hel1.pathKey);
      probeTakes = const Duration(seconds: 1);
      final vpn = _Vpn()..held[hel1.pathKey] = Completer<bool>();
      final f = flow(vpn);

      final tap = f.connect(paths);
      await until(() => f.stage == ConnectStage.diagnosing);
      f.stop();
      await tap;

      expect(await PathMemory().recall(network), isNull);
      expect(await PathMemory().failedToday(network), isEmpty);
    });

    test('before forgetAfter keeps the door', () async {
      await PathMemory().remember(network, hel1.pathKey);
      final vpn = _Vpn()..held[hel1.pathKey] = Completer<bool>();
      final f = flow(
        vpn,
        fastPath: const FastPathSettings(forgetAfter: Duration(seconds: 5)),
      );

      final tap = f.connect(paths);
      await until(() => vpn.dialled.isNotEmpty);
      f.stop();
      await tap;

      expect(await PathMemory().recall(network), hel1.pathKey);
    });

    test('keeps the door when the backend turns the forget off', () async {
      await PathMemory().remember(network, hel1.pathKey);
      final vpn = _Vpn()..held[hel1.pathKey] = Completer<bool>();
      final f = flow(vpn, fastPath: const FastPathSettings());

      final tap = f.connect(paths);
      await until(() => vpn.dialled.isNotEmpty);
      await Future<void>.delayed(soon * 2);
      f.stop();
      await tap;

      expect(await PathMemory().recall(network), hel1.pathKey);
    });

    test(
      'is not a pick of another server, which only replaces the run',
      () async {
        await PathMemory().remember(network, hel1.pathKey);
        final vpn = _Vpn()..held[hel1.pathKey] = Completer<bool>();
        final f = flow(
          vpn,
          fastPath: const FastPathSettings(forgetAfter: soon),
        );

        final tap = f.connect(paths);
        await until(() => vpn.dialled.isNotEmpty);
        await Future<void>.delayed(soon * 2);
        f.cancel();
        await tap;

        expect(await PathMemory().recall(network), hel1.pathKey);
      },
    );

    // Until the review of 2026-10-24 this said the remembered door stayed
    // remembered here. The leave now forgets it, and the stop adds nothing.
    test('after the dial was left for an open door finds the door already '
        'forgotten by the leave, and counts no failure', () async {
      await PathMemory().remember(network, hel1.pathKey);
      openHere = {hel2.pathKey};
      final vpn = _Vpn()
        ..held[hel1.pathKey] = Completer<bool>()
        ..held[hel2.pathKey] = Completer<bool>();
      final f = flow(vpn);

      final tap = f.connect(paths);
      await until(() => vpn.dialled.length == 2);
      f.stop();
      await tap;

      expect(await PathMemory().recall(network), isNull);
      expect(await PathMemory().failedToday(network), isEmpty);
      expect(await PathMemory().skippable(network), isEmpty);
    });
  });

  group('a remembered door that did not carry traffic', () {
    // Found 2026-10-24 in review of 8ed5fc7: the fast path could give up on
    // the remembered door without marking or forgetting it, and every later
    // try and tap on the network dialled it first again, 5 to 10 seconds
    // before the door the checklist found open.

    test('left after a failed pass, with no door carrying traffic, is '
        'forgotten with no failure, and the retry starts with the '
        'checklist', () async {
      await PathMemory().remember(network, hel1.pathKey);
      // hel2 checks open, but its tunnel carries nothing.
      openHere = {hel2.pathKey};
      final vpn = _Vpn()..checking[hel1.pathKey] = Completer<bool>();
      final f = flow(
        vpn,
        retry: const RetrySettings(after: [Duration(milliseconds: 300)]),
      );
      // Each time hel1 is up and in its traffic check, its first pass
      // fails, as a dead door's does.
      vpn.addListener(() {
        if (vpn.isVerifying &&
            vpn.trafficMisses == 0 &&
            vpn.dialled.last == hel1.pathKey) {
          Future<void>.delayed(const Duration(milliseconds: 120), vpn.miss);
        }
      });

      await f.connect(paths);

      expect(f.stage, ConnectStage.waiting);
      expect(vpn.dialled, [hel1.pathKey, hel2.pathKey]);
      expect(await PathMemory().recall(network), isNull);
      // hel2's tunnel failed. hel1 was only left.
      expect(await PathMemory().failedToday(network), {hel2.pathKey});

      // The retry checks the doors before it dials one.
      probed.clear();
      await until(() => vpn.dialled.length == 3);
      expect(probed, isNotEmpty);
      expect(vpn.dialled[2], hel2.pathKey);
      f.cancel();
    });

    test('left before its tunnel came up is forgotten too', () async {
      await PathMemory().remember(network, hel1.pathKey);
      openHere = {hel2.pathKey};
      final vpn = _Vpn()..held[hel1.pathKey] = Completer<bool>();
      final f = flow(vpn);

      await f.connect(paths);

      expect(vpn.dialled, [hel1.pathKey, hel2.pathKey]);
      expect(await PathMemory().recall(network), isNull);
      expect(await PathMemory().failedToday(network), {hel2.pathKey});
    });

    test('whose dial failed by itself beside the search is forgotten with no '
        'failure when the user stops before the search ends, and the next '
        'tap checks it before it dials it', () async {
      await PathMemory().remember(network, hel1.pathKey);
      final hold = Completer<bool>();
      // Slow checks, so the search beside the dial is still running.
      probeTakes = const Duration(milliseconds: 400);
      final vpn = _Vpn()..held[hel1.pathKey] = hold;
      final f = flow(vpn);

      final tap = f.connect(paths);
      await until(() => f.stage == ConnectStage.diagnosing);
      hold.complete(false);
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(f.stage, ConnectStage.diagnosing);
      f.stop();
      await tap;

      expect(await PathMemory().recall(network), isNull);
      expect(await PathMemory().failedToday(network), isEmpty);

      // hel1 works now. It is checked first, as any door, dialled, and
      // remembered again once it carries traffic.
      vpn.held.clear();
      vpn.works.add(hel1.pathKey);
      openHere = {hel1.pathKey};
      probeTakes = const Duration(milliseconds: 10);
      probed.clear();
      await f.connect(paths);

      expect(probed, isNotEmpty);
      expect(vpn.dialled, [hel1.pathKey, hel1.pathKey]);
      expect(f.chosen, hel1);
      expect(await PathMemory().recall(network), hel1.pathKey);
    });

    test('the next tap after that stop waits for the forget before it reads '
        'the memory', () async {
      await PathMemory().remember(network, hel1.pathKey);
      final memory = _SlowForget();
      final hold = Completer<bool>();
      probeTakes = const Duration(milliseconds: 400);
      final vpn = _Vpn(works: {hel1.pathKey})..held[hel1.pathKey] = hold;
      final f = flow(vpn, memory: memory);

      final tap = f.connect(paths);
      await until(() => f.stage == ConnectStage.diagnosing);
      hold.complete(false);
      await Future<void>.delayed(const Duration(milliseconds: 30));
      f.stop();
      await tap;

      // A tap at once, while the forget is still being written.
      vpn.held.clear();
      openHere = {hel1.pathKey};
      probeTakes = const Duration(milliseconds: 10);
      probed.clear();
      final next = f.connect(paths);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(vpn.dialled, [hel1.pathKey]);
      memory.landed.complete();
      await next;

      expect(probed, isNotEmpty);
      expect(vpn.dialled, [hel1.pathKey, hel1.pathKey]);
    });

    test('whose dial failed by itself is forgotten with no failure when the '
        'user stops while the allowance question runs', () async {
      // Found 2026-10-24 in review of 1a49037 (probe N1): the record a stop
      // forgets was set only after this question, which waits up to 4
      // seconds.
      await PathMemory().remember(network, hel1.pathKey);
      final hold = Completer<bool>();
      probeTakes = const Duration(milliseconds: 400);
      final vpn = _Vpn()..held[hel1.pathKey] = hold;
      final f = flow(vpn);
      final answer = Completer<bool>();
      var asked = false;

      final tap = f.connect(
        paths,
        allowanceSpent: () {
          asked = true;
          return answer.future;
        },
      );
      await until(() => f.stage == ConnectStage.diagnosing);
      hold.complete(false);
      await until(() => asked);
      await Future<void>.delayed(const Duration(milliseconds: 30));
      f.stop();
      answer.complete(false);
      await tap;
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(f.stage, ConnectStage.cancelled);
      expect(await PathMemory().recall(network), isNull);
      expect(await PathMemory().failedToday(network), isEmpty);
    });

    test('whose dial failed on a spent allowance stays first, also after a '
        'stop once the tap has ended', () async {
      await PathMemory().remember(network, hel1.pathKey);
      final vpn = _Vpn();
      final f = flow(vpn);

      await f.connect(paths, allowanceSpent: () async => true);
      expect(f.stage, ConnectStage.idle);
      expect(vpn.dialled, [hel1.pathKey]);
      f.stop();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(await PathMemory().recall(network), hel1.pathKey);
      expect(await PathMemory().failedToday(network), isEmpty);
    });

    test('whose dial failed by itself is forgotten too when a pick of '
        'another server replaces the run before the search ends', () async {
      await PathMemory().remember(network, hel1.pathKey);
      final hold = Completer<bool>();
      probeTakes = const Duration(milliseconds: 400);
      final vpn = _Vpn()..held[hel1.pathKey] = hold;
      final f = flow(vpn);

      final tap = f.connect(paths);
      await until(() => f.stage == ConnectStage.diagnosing);
      hold.complete(false);
      await Future<void>.delayed(const Duration(milliseconds: 30));
      f.cancel();
      await tap;
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(await PathMemory().recall(network), isNull);
      expect(await PathMemory().failedToday(network), isEmpty);
    });

    test('whose dial failed on a phone with no internet stays first, also '
        'after a stop during the wait that follows', () async {
      await PathMemory().remember(network, hel1.pathKey);
      // Every dial fails, and every check.
      final vpn = _Vpn();
      final f = flow(
        vpn,
        internet: false,
        retry: const RetrySettings(after: [Duration(seconds: 5)]),
      );

      await f.connect(paths);
      expect(vpn.dialled, [hel1.pathKey]);
      expect(f.stage, ConnectStage.waiting);
      f.stop();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(await PathMemory().recall(network), hel1.pathKey);
      expect(await PathMemory().failedToday(network), isEmpty);
    });
  });

  group('the allowance question', () {
    test('is asked once, at the first failure, and read at every '
        'check', () async {
      await PathMemory().remember(network, hel1.pathKey);
      final vpn = _Vpn();
      final f = flow(vpn);
      final dialsWhenAsked = <int>[];

      await f.connect(
        paths,
        allowanceSpent: () async {
          dialsWhenAsked.add(vpn.dialled.length);
          return false;
        },
      );

      // Read after the remembered door failed and after every door was
      // found closed: two checks, one question, asked once the dial had
      // failed.
      expect(f.stage, ConnectStage.nothingOpen);
      expect(dialsWhenAsked, [1]);
    });

    test('is not asked by a tap in which nothing failed', () async {
      // Found 2026-10-23 in review: asked when a tap started, the request
      // reads on the backend as one made after a failed try, so a stopped
      // tap counted as a failed one in its rescue rule.
      var asked = 0;
      Future<bool> ask() async {
        asked++;
        return false;
      }

      // The remembered door connects.
      await PathMemory().remember(network, hel1.pathKey);
      final connects = flow(_Vpn(works: {hel1.pathKey}));
      await connects.connect(paths, allowanceSpent: ask);
      expect(connects.stage, ConnectStage.done);

      // The user stops the remembered door's dial while the checklist runs
      // beside it.
      probeTakes = const Duration(seconds: 1);
      final vpn = _Vpn()..held[hel1.pathKey] = Completer<bool>();
      final stopped = flow(
        vpn,
        fastPath: const FastPathSettings(besideAfter: soon),
      );
      final tap = stopped.connect(paths, allowanceSpent: ask);
      await until(() => stopped.stage == ConnectStage.diagnosing);
      stopped.stop();
      await tap;
      expect(stopped.stage, ConnectStage.cancelled);

      // No door remembered, and the checklist finds one open.
      await PathMemory().forget(network, hel1.pathKey);
      probeTakes = const Duration(milliseconds: 10);
      openHere = {hel2.pathKey};
      final found = flow(_Vpn(works: {hel2.pathKey}));
      await found.connect(paths, allowanceSpent: ask);
      expect(found.chosen, hel2);

      expect(asked, 0);
    });

    test('an answer that never comes holds the tap up once, not at every '
        'check', () async {
      await PathMemory().remember(network, hel1.pathKey);
      final vpn = _Vpn();
      final f = flow(vpn);
      final watch = Stopwatch()..start();

      await f.connect(paths, allowanceSpent: () => Completer<bool>().future);

      // Each check waited up to 4 seconds until 2.2.0, 8 in all here.
      expect(f.stage, ConnectStage.nothingOpen);
      expect(watch.elapsed, lessThan(const Duration(seconds: 6)));
    });

    test('a yes ends the tap at the first check', () async {
      await PathMemory().remember(network, hel1.pathKey);
      final vpn = _Vpn();
      final f = flow(vpn);
      var asked = 0;

      await f.connect(
        paths,
        allowanceSpent: () async {
          asked++;
          return true;
        },
      );

      expect(asked, 1);
      expect(f.stage, ConnectStage.idle);
      expect(vpn.dialled, [hel1.pathKey]);
      expect(probed, isEmpty);
      expect(traces.started.single.outcome, TraceOutcome.allowance);
    });

    test(
      'one that ended in an error is asked again at the next check',
      () async {
        await PathMemory().remember(network, hel1.pathKey);
        final vpn = _Vpn();
        final f = flow(vpn);
        var asked = 0;

        await f.connect(
          paths,
          allowanceSpent: () async {
            asked++;
            if (asked == 1) throw Exception('no route');
            return true;
          },
        );

        expect(asked, 2);
        expect(f.stage, ConnectStage.idle);
      },
    );
  });
}
