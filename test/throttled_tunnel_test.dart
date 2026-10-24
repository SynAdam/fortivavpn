import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/core/state/connect_flow.dart';
import 'package:fortiva_vpn/core/state/stall_recovery.dart';
import 'package:fortiva_vpn/data/models/server.dart';
import 'package:fortiva_vpn/data/models/stall_watch_settings.dart';
import 'package:fortiva_vpn/services/connect_diagnostics.dart';
import 'package:fortiva_vpn/services/door_sweep.dart';
import 'package:fortiva_vpn/services/ipv6_reach.dart';
import 'package:fortiva_vpn/services/path_finder.dart';
import 'package:fortiva_vpn/services/path_memory.dart';
import 'package:fortiva_vpn/services/stall_watch.dart';
import 'package:fortiva_vpn/services/vpn_event_reporter.dart';
import 'package:fortiva_vpn/services/vpn_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A tunnel the stall watch finds throttled rather than dead (clients C7
/// of the plan of 2026-10-23).
///
/// On 10-23 the throttle trigger ended 106 sessions on 72 phones, and the
/// next session carried about half as much whether it moved to another
/// door or not. The heartbeats before those drops were mostly as large as
/// the session's own normal. Now the finding is reported and the tunnel is
/// left alone while a check finds its door open: its door is not marked
/// failed and no search runs, unless a check of the connect's doors finds
/// one faster. A door in use that is not shown open is left, and the
/// search runs in full, as builds up to 2.2.0 do.
Server own(String host, String door, int row) => Server.fromDedicatedPath(
  uri:
      'vless://u@$host:8443?type=tcp&security=reality'
      '&sni=www.samsung.com&pbk=key#Row$row',
  door: door,
  doorLabel: door,
  serverId: row,
);

final hel1 = own('203.0.113.226', 'tcp-reality', 13);
final hel2 = own('203.0.113.226', 'xhttp-reality', 13);
final fsn = own('203.0.113.227', 'tcp-reality', 14);
final paths = [hel1, hel2, fsn];

const throttle = StallFinding(
  trigger: StallWatch.triggerThrottle,
  probes: 3,
  quietFor: Duration.zero,
  up: 20000,
  down: 20000,
);

const _open = DoorOutcome(ms: 300, tcpMs: 40, phase: 'ok');
const _closed = DoorOutcome(ms: -1, error: 'tcp timeout', phase: 'tcp');

class _Row {
  _Row(this.type, this.error, this.diag, this.down);
  final VpnEventType type;
  final String? error;
  final Map<String, dynamic>? diag;
  final int? down;
}

class _Reporter extends VpnEventReporter {
  _Reporter() : super(send: (_, _, _) async {});

  final rows = <_Row>[];

  @override
  Future<void> record(
    VpnEventType type, {
    String? serverHost,
    String? door,
    String? attemptId,
    Map<String, dynamic>? strategy,
    Duration? duration,
    String? error,
    Map<String, dynamic>? diag,
    int? bytesUp,
    int? bytesDown,
    DateTime? at,
  }) async {
    rows.add(_Row(type, error, diag, bytesDown));
  }
}

class _NoDiagnostics extends ConnectDiagnostics {
  @override
  Future<Map<String, dynamic>> collect({
    String? host,
    int port = 443,
    String? sni,
  }) async => const {'tcp': 'ok'};

  @override
  Future<Map<String, dynamic>> platformReport() async => const {};
}

/// A tunnel that comes up through any door, and records what the recovery
/// asks of it.
class _Vpn extends VpnService {
  _Vpn() : super(events: VpnEventReporter(send: (_, _, _) async {}));

  VpnStatus _fakeStatus = VpnStatus.disconnected;
  Server? active;
  bool dead = false;
  final left = <StallFinding>[];
  int drops = 0;

  @override
  VpnStatus get status => _fakeStatus;

  @override
  bool get isConnected => _fakeStatus == VpnStatus.connected;

  @override
  bool get isConnecting => _fakeStatus == VpnStatus.connecting;

  @override
  bool get isVerifying => false;

  @override
  bool get stalled => dead && isConnected;

  /// When set, the next read of [activeDoor] throws, so the check of the
  /// doors fails before it starts.
  bool failNextDoorRead = false;

  @override
  Server? get activeDoor {
    if (failNextDoorRead) {
      failNextDoorRead = false;
      throw StateError('no door');
    }
    return active;
  }

  @override
  String? get activeDoorKey => active?.pathKey;

  @override
  Future<void> connect(
    Server server, {
    String? attemptId,
    List<Server> standby = const [],
    LinkSource? source,
  }) async {
    active = server;
    dead = false;
    _fakeStatus = VpnStatus.connecting;
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 5));
    _fakeStatus = VpnStatus.connected;
    notifyListeners();
  }

  @override
  void leaveThrottled(StallFinding finding) {
    left.add(finding);
    dead = true;
    onStall?.call();
  }

  @override
  Future<void> dropStalled() async {
    drops++;
    _fakeStatus = VpnStatus.disconnected;
    notifyListeners();
  }
}

/// A sweep whose check of the doors fails as a whole: [probeAll] throws,
/// or gives no result. DoorSweep's own never does either.
class _BrokenSweep extends DoorSweep {
  _BrokenSweep({required this.throws}) : super(appBypassesTunnel: true);

  final bool throws;

  @override
  Future<List<ProbeResult>> probeAll(List<Server> paths) async {
    if (throws) throw StateError('the checks did not run');
    return const [];
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the watch', () {
    late List<TunnelCounts?> readings;
    late List<StallFinding> dead;
    late List<StallFinding> throttled;
    late int probes;
    late bool Function() passes;
    final now = DateTime.utc(2026, 10, 24, 5);

    const settings = StallWatchSettings(
      throttle: true,
      throttleRatio: 0.05,
      throttleReadings: 10,
      throttleMinNormal: 65536,
      throttleCooldown: Duration(minutes: 5),
    );

    setUp(() {
      readings = [];
      dead = [];
      throttled = [];
      probes = 0;
      passes = () => false;
    });

    StallWatch watch(FakeAsync async, {bool reports = true}) => StallWatch(
      read: () async => readings.isEmpty ? null : readings.removeAt(0),
      probe: () async {
        probes++;
        return passes();
      },
      onStall: dead.add,
      onThrottle: reports ? throttled.add : null,
      settings: () => settings,
      now: () => now.add(async.elapsed),
    );

    // Five minutes of a session that brings 500 KB a minute back, then a
    // minute that brought back 20 KB.
    List<TunnelCounts> slowMinute() => [
      ...List.filled(5, (up: 20000, down: 500000)),
      (up: 20000, down: 20000),
    ];

    test('a throttle finding is reported, and the watch goes on', () {
      fakeAsync((async) {
        final w = watch(async)..start();
        readings = slowMinute();
        async.elapse(const Duration(minutes: 6, seconds: 25));

        expect(probes, 3);
        expect(throttled.single.trigger, StallWatch.triggerThrottle);
        expect(dead, isEmpty);
        expect(w.fired, isFalse);
        expect(w.active, isTrue);
        expect(w.doubting, isFalse);
        w.stop();
      });
    });

    test('after it the throttle trigger rests, and a tunnel that dies is '
        'still found', () {
      fakeAsync((async) {
        final w = watch(async)..start();
        readings = [
          ...slowMinute(),
          // Throttled again within the cooldown: not checked.
          (up: 20000, down: 20000),
          (up: 20000, down: 20000),
          // Then nothing comes back at all.
          (up: 5000, down: 0),
        ];
        async.elapse(const Duration(minutes: 9, seconds: 30));

        expect(throttled, hasLength(1));
        expect(probes, 6);
        expect(dead.single.trigger, StallWatch.triggerCounters);
        expect(w.fired, isTrue);
        w.stop();
      });
    });

    test('without a listener for it, a throttle finding ends the tunnel, '
        'as builds up to 2.2.0 do', () {
      fakeAsync((async) {
        final w = watch(async, reports: false)..start();
        readings = slowMinute();
        async.elapse(const Duration(minutes: 6, seconds: 25));

        expect(dead.single.trigger, StallWatch.triggerThrottle);
        expect(w.fired, isTrue);
        w.stop();
      });
    });
  });

  group('the service', () {
    const tunnel = MethodChannel('com.vpn.fortivavpn/tunnel');
    const statusChannel = EventChannel('com.vpn.fortivavpn/tunnel/status');
    late _Reporter reporter;
    late VpnService service;
    late int stalls;
    late List<StallFinding> told;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        tunnel,
        (call) async => call.method == 'getStatus' ? 'disconnected' : null,
      );
      messenger.setMockStreamHandler(
        statusChannel,
        MockStreamHandler.inline(onListen: (_, _) {}),
      );
      StallWatch.androidOverride = true;
      reporter = _Reporter();
      service = VpnService(events: reporter, diagnostics: _NoDiagnostics());
      service.debugDoors = [hel1, fsn];
      stalls = 0;
      told = [];
      service.onStall = () => stalls++;
      service.onThrottle = told.add;
      service.applyNativeStatus('connected');
    });

    tearDown(() {
      service.dispose();
      StallWatch.androidOverride = null;
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(tunnel, null);
      messenger.setMockStreamHandler(statusChannel, null);
    });

    test('reports a throttle finding on a heartbeat and keeps the '
        'session', () async {
      service.debugThrottle(throttle);
      await pumpEventQueue();

      final beat = reporter.rows.single;
      expect(beat.type, VpnEventType.heartbeat);
      expect(beat.diag, containsPair('stall_trigger', 'throttle'));
      expect(beat.diag, containsPair('stall_probes', 3));
      expect(beat.diag, containsPair('stall_down_bytes', 20000));
      expect(
        reporter.rows.where((r) => r.type == VpnEventType.dropped),
        isEmpty,
      );
      expect(service.stalled, isFalse);
      expect(service.stallWatch.active, isTrue);
      expect(told, [throttle]);
      expect(stalls, 0);
    });

    test('leaving a throttled tunnel files the drop a dead one gets', () async {
      service.leaveThrottled(throttle);
      await pumpEventQueue();

      final drop = reporter.rows.single;
      expect(drop.type, VpnEventType.dropped);
      expect(drop.error, dropReasonStalled);
      expect(drop.diag, containsPair('stall_trigger', 'throttle'));
      expect(service.stalled, isTrue);
      expect(stalls, 1);
    });

    test('nothing for a tunnel already found dead', () async {
      service.debugStall(
        const StallFinding(
          trigger: StallWatch.triggerCounters,
          probes: 3,
          quietFor: Duration(minutes: 2),
        ),
      );
      service.debugThrottle(throttle);
      await pumpEventQueue();

      expect(reporter.rows.map((r) => r.type), [VpnEventType.dropped]);
      expect(told, isEmpty);
    });
  });

  group('the recovery', () {
    late _Vpn vpn;
    late PathMemory memory;
    late Map<String, DoorOutcome> checks;
    late List<List<String>> checked;
    late int redials;
    late bool bypasses;
    late bool readThrows;
    // When set, the door checks wait for it.
    Completer<void>? gate;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      vpn = _Vpn();
      memory = PathMemory();
      checks = {};
      checked = [];
      redials = 0;
      bypasses = true;
      readThrows = false;
      gate = null;
    });

    ConnectFlow build({DoorSweep? sweep}) => ConnectFlow(
      vpn: vpn,
      memory: memory,
      finder: PathFinder(read: (_) async => _open, internet: () async => true),
      sweep:
          sweep ??
          DoorSweep(
            read: (p) async {
              checked.last.add(p.pathKey);
              await gate?.future;
              if (readThrows) throw StateError('the check did not run');
              return checks[p.pathKey] ?? _closed;
            },
            appBypassesTunnel: bypasses,
          ),
      reporter: VpnEventReporter(send: (_, _, _) async {}),
      ipv6: Ipv6Reach(route: () async => null),
      networkKey: () async => 'wifi:home',
      carrier: () async => null,
      checklist: () => null,
      attemptTimeout: const Duration(seconds: 2),
      answeredSince: (_) => false,
    );

    Future<ConnectFlow> connected({
      Server? preferred,
      List<Server>? doors,
      DoorSweep? sweep,
    }) async {
      final flow = build(sweep: sweep);
      await flow.connect(doors ?? paths, preferred: preferred);
      expect(flow.stage, ConnectStage.done);
      checked.add([]);
      return flow;
    }

    StallRecovery recovery(ConnectFlow flow, {List<Server>? doors}) =>
        StallRecovery(
          vpn: vpn,
          flow: flow,
          watchApp: false,
          redial: () async {
            redials++;
            await flow.connect(doors ?? paths);
          },
        );

    test(
      'with no faster door, the tunnel and its door are left alone',
      () async {
        final flow = await connected();
        expect(vpn.active, hel1);
        checks = {
          hel1.pathKey: const DoorOutcome(ms: 400, phase: 'ok'),
          // Faster, but not by enough: a door check is a small page, not a
          // download.
          hel2.pathKey: const DoorOutcome(ms: 250, phase: 'ok'),
        };

        await recovery(flow).moveIfFaster(throttle);

        expect(checked.single, [hel1.pathKey, hel2.pathKey, fsn.pathKey]);
        expect(vpn.left, isEmpty);
        expect(redials, 0);
        expect(vpn.active, hel1);
        expect(await memory.recall('wifi:home'), hel1.pathKey);
        expect(await memory.failedToday('wifi:home'), isEmpty);
      },
    );

    test('a door at most half as slow is faster: the tunnel moves there, '
        'and the door left counts one failure', () async {
      final flow = await connected();
      checks = {
        hel1.pathKey: const DoorOutcome(ms: 900, phase: 'ok'),
        hel2.pathKey: const DoorOutcome(ms: 600, phase: 'ok'),
        fsn.pathKey: const DoorOutcome(ms: 300, phase: 'ok'),
      };
      final r = recovery(flow);

      await r.moveIfFaster(throttle);
      await pumpEventQueue();

      expect(vpn.left, [throttle]);
      expect(redials, 1);
      // The fast path dialled the faster door first.
      expect(vpn.active, fsn);
      expect(await memory.recall('wifi:home'), fsn.pathKey);
      expect(await memory.failedToday('wifi:home'), contains(hel1.pathKey));
      expect(vpn.drops, 0);
    });

    test('a door open while the one in use is closed is faster', () async {
      final flow = await connected();
      checks = {hel2.pathKey: const DoorOutcome(ms: 2500, phase: 'ok')};

      expect(await flow.checkThrottled(), (
        step: ThrottleStep.move,
        door: hel2,
      ));
    });

    test('a picked server keeps the move on its own doors', () async {
      final flow = await connected(preferred: hel1);
      checks = {
        hel1.pathKey: const DoorOutcome(ms: 900, phase: 'ok'),
        fsn.pathKey: const DoorOutcome(ms: 100, phase: 'ok'),
      };

      expect(await flow.checkThrottled(), (
        step: ThrottleStep.stay,
        door: null,
      ));
      expect(checked.single, [hel1.pathKey, hel2.pathKey]);
    });

    test('where a check would go through the tunnel, the tunnel is left '
        'without one', () async {
      bypasses = false;
      final flow = await connected();
      checks = {fsn.pathKey: const DoorOutcome(ms: 100, phase: 'ok')};

      expect(await flow.checkThrottled(), (
        step: ThrottleStep.leave,
        door: null,
      ));
      expect(checked.single, isEmpty);
    });

    // Every door closed to a new connection, as when a carrier blocks all
    // our addresses: the tunnel cannot open a new connection either, while
    // its old ones keep it above the dead tunnel's line. Builds up to 2.2.0
    // left it and searched in full, shared links and the backup network
    // included.
    test('a door in use closed to a new connection, with no door open, is '
        'left as a dead one is, and the search runs', () async {
      final flow = await connected();
      // Read when the search starts: a search that connects through the
      // door again clears its failure.
      Set<String>? failed;
      final r = StallRecovery(
        vpn: vpn,
        flow: flow,
        watchApp: false,
        redial: () async {
          redials++;
          failed = await memory.failedToday('wifi:home');
        },
      );

      await r.moveIfFaster(throttle);
      await pumpEventQueue();

      expect(checked.first, [hel1.pathKey, hel2.pathKey, fsn.pathKey]);
      expect(vpn.left, [throttle]);
      expect(redials, 1);
      expect(failed, contains(hel1.pathKey));
    });

    test('with no other door, the door in use is still checked: closed, '
        'the tunnel is left', () async {
      final flow = await connected(doors: [hel1]);
      final r = recovery(flow, doors: [hel1]);

      await r.moveIfFaster(throttle);
      await pumpEventQueue();

      expect(checked.first, [hel1.pathKey]);
      expect(vpn.left, [throttle]);
      expect(redials, 1);
    });

    test('with no other door, the door in use is still checked: open, the '
        'tunnel stays', () async {
      final flow = await connected(doors: [hel1]);
      checks = {hel1.pathKey: _open};

      await recovery(flow, doors: [hel1]).moveIfFaster(throttle);
      await pumpEventQueue();

      expect(checked.single, [hel1.pathKey]);
      expect(vpn.left, isEmpty);
      expect(redials, 0);
    });

    test('a tunnel this flow did not connect is left as before, without a '
        'check', () async {
      final flow = build();
      checked.add([]);
      await vpn.connect(hel1);
      expect(flow.stage, ConnectStage.idle);
      checks = {hel1.pathKey: _open};

      await recovery(flow).moveIfFaster(throttle);
      await pumpEventQueue();

      expect(checked.first, isEmpty);
      expect(vpn.left, [throttle]);
      expect(redials, 1);
    });

    test(
      'a tunnel found dead while the doors were checked is recovered',
      () async {
        final flow = await connected();
        checks = {hel1.pathKey: _open};
        final open = gate = Completer<void>();
        final r = recovery(flow);

        final move = r.moveIfFaster(throttle);
        await pumpEventQueue();
        expect(checked.single, isNotEmpty);
        // The watch calls the tunnel dead while the checks run: the recovery
        // is busy, and the watch tells once.
        vpn.dead = true;
        vpn.onStall!();
        open.complete();
        await move;
        await pumpEventQueue();

        expect(vpn.left, isEmpty);
        expect(redials, 1);
      },
    );

    test(
      'no move once the core moved to another door during the checks',
      () async {
        final flow = await connected();
        checks = {fsn.pathKey: const DoorOutcome(ms: 100, phase: 'ok')};
        final r = recovery(flow);
        // The core leaves the door while its check runs.
        final move = r.moveIfFaster(throttle);
        vpn.active = hel2;
        await move;

        expect(vpn.left, isEmpty);
        expect(redials, 0);
      },
    );

    test('is what the service tells about a throttled tunnel, and lets go '
        'of it when disposed', () async {
      final flow = await connected();
      final r = recovery(flow);
      expect(vpn.onThrottle, isNotNull);
      vpn.onThrottle!(throttle);
      await pumpEventQueue();
      expect(checked.single, isNotEmpty);

      r.dispose();
      expect(vpn.onThrottle, isNull);
    });

    // A door in use that is not shown open is left, as builds up to 2.2.0
    // do, also when the check itself fails. Each of these is close to
    // unreachable: DoorSweep catches every error of a read, and gives one
    // result per door.
    group('a check that fails leaves the tunnel', () {
      Future<void> leaves(ConnectFlow flow) async {
        await recovery(flow).moveIfFaster(throttle);
        await pumpEventQueue();

        expect(vpn.left, [throttle]);
        expect(redials, 1);
      }

      test('when the read throws for every door', () async {
        final flow = await connected();
        readThrows = true;
        // Open, had the reads answered.
        checks = {hel1.pathKey: _open};

        await leaves(flow);
        expect(checked.single, [hel1.pathKey, hel2.pathKey, fsn.pathKey]);
      });

      test('when the sweep throws', () async {
        await leaves(await connected(sweep: _BrokenSweep(throws: true)));
      });

      test('when the sweep gives no result', () async {
        await leaves(await connected(sweep: _BrokenSweep(throws: false)));
      });

      test('when the check throws before it starts', () async {
        final flow = await connected();
        checks = {hel1.pathKey: _open};
        vpn.failNextDoorRead = true;

        await leaves(flow);
        expect(checked.single, isEmpty);
      });
    });
  });
}
