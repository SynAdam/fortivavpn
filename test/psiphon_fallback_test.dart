import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/api/config_service.dart';
import 'package:fortiva_vpn/core/state/connect_flow.dart';
import 'package:fortiva_vpn/data/models/checklist_settings.dart';
import 'package:fortiva_vpn/data/models/psiphon_settings.dart';
import 'package:fortiva_vpn/data/models/server.dart';
import 'package:fortiva_vpn/services/connect_trace.dart';
import 'package:fortiva_vpn/services/ipv6_reach.dart';
import 'package:fortiva_vpn/services/path_finder.dart';
import 'package:fortiva_vpn/services/path_memory.dart';
import 'package:fortiva_vpn/services/vpn_event_reporter.dart';
import 'package:fortiva_vpn/services/vpn_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The backup network as the last resort of a tap (clients #299).
///
/// The tap checks our own doors and the community links exactly as before.
/// Only when that try ends without a tunnel does the app dial the backup
/// network by itself, and only when every gate the backend and the phone
/// set is open. Every value of the network's settings here is made up.
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
final fsn1 = own('203.0.113.227', 'tcp-reality', 14);
final paths = [hel1, hel2, fsn1];

final picked = Server.fromConnectionUri(
  'vless://u@h1.example:443?type=tcp&security=reality'
  '&sni=www.samsung.com&pbk=key#Link1',
);
final other = Server.fromConnectionUri(
  'vless://u@h2.example:443?type=tcp&security=reality'
  '&sni=www.samsung.com&pbk=key#Link2',
  index: 1,
);

const open = DoorOutcome(ms: 120, tcpMs: 40, phase: 'ok');
const closed = DoorOutcome(
  ms: -1,
  error: 'tcp timeout; no answer in 3000 ms',
  phase: 'tcp',
);

final backupKey = Server.psiphon.pathKey;

/// A tunnel that comes up through the links in [works] and fails through
/// everything else. The backup network takes [backupTakes], or never
/// settles with [hangBackup].
class _FakeVpn extends VpnService {
  _FakeVpn(this.works)
    : super(
        events: VpnEventReporter(send: (_, _, _) async {}, queues: const []),
      );

  final Set<String> works;
  final dialled = <String>[];
  final sources = <LinkSource?>[];
  final standbys = <List<Server>>[];

  /// Links whose dial fails because the VPN permission was refused.
  Set<String> refuse = {};
  bool hangBackup = false;
  Duration backupTakes = const Duration(milliseconds: 2);

  /// Completes when the backup network's first dial starts.
  final backupStarted = Completer<void>();

  /// Called when each dial of the backup network starts.
  void Function()? onBackup;

  VpnStatus _fakeStatus = VpnStatus.disconnected;
  bool _refused = false;
  Server? active;

  /// Whether the tunnel that is up has been found dead. A new dial clears
  /// it, as the service's own watch does.
  bool stall = false;

  /// How many times a tunnel was taken down.
  int downs = 0;

  @override
  VpnStatus get status => _fakeStatus;

  @override
  bool get stalled => stall && isConnected;

  /// A tunnel that comes up after its attempt was given up on.
  void comeUpLate(Server server) {
    active = server;
    _fakeStatus = VpnStatus.connected;
    notifyListeners();
  }

  @override
  bool get isConnected => _fakeStatus == VpnStatus.connected;

  @override
  bool get isConnecting => _fakeStatus == VpnStatus.connecting;

  @override
  bool get isVerifying => false;

  @override
  bool get failedOnPermission => _refused;

  @override
  Server? get activeDoor => active;

  @override
  Future<void> connect(
    Server server, {
    String? attemptId,
    List<Server> standby = const [],
    LinkSource? source,
  }) async {
    dialled.add(server.pathKey);
    sources.add(source);
    standbys.add(standby);
    // The service takes the tunnel that is up down before it dials.
    if (_fakeStatus == VpnStatus.connected) downs++;
    active = server;
    _refused = false;
    stall = false;
    _fakeStatus = VpnStatus.connecting;
    notifyListeners();
    if (server.isPsiphon) {
      if (!backupStarted.isCompleted) backupStarted.complete();
      onBackup?.call();
      if (hangBackup) return;
      await Future.delayed(backupTakes);
    } else {
      await Future.delayed(const Duration(milliseconds: 2));
    }
    _refused = refuse.contains(server.pathKey);
    _fakeStatus = works.contains(server.pathKey)
        ? VpnStatus.connected
        : VpnStatus.error;
    notifyListeners();
  }

  @override
  Future<void> disconnect() async {
    if (_fakeStatus == VpnStatus.connected) downs++;
    _fakeStatus = VpnStatus.disconnected;
    notifyListeners();
  }

  @override
  void clearError() {
    if (_fakeStatus == VpnStatus.error) _fakeStatus = VpnStatus.disconnected;
    notifyListeners();
  }

  int get backupDials => dialled.where((k) => k == backupKey).length;
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

/// Waits until [ok] holds, failing the test after [within].
Future<void> until(
  bool Function() ok, {
  Duration within = const Duration(seconds: 3),
}) async {
  final end = DateTime.now().add(within);
  while (!ok()) {
    if (DateTime.now().isAfter(end)) fail('still waiting after $within');
    await Future<void>.delayed(const Duration(milliseconds: 2));
  }
}

const network = 'mobile';

const networkSettings = {
  'PropagationChannelId': '0123456789ABCDEF',
  'SponsorId': '0123456789ABCDEF',
};

PsiphonSettings backup({
  bool enabled = true,
  int afterRounds = 0,
  int everyRounds = 1,
  Set<String> stages = PsiphonSettings.defaultStages,
  bool tv = false,
  Duration establish = const Duration(seconds: 1),
}) => PsiphonSettings(
  network: networkSettings,
  enabled: enabled,
  afterRounds: afterRounds,
  everyRounds: everyRounds,
  stages: stages,
  tv: tv,
  establishTimeout: establish,
);

const fresh = QuotaStatus(
  unlimited: false,
  limitBytes: 100,
  usedBytes: 10,
  remainingBytes: 90,
  blocked: false,
);

const empty = QuotaStatus(
  unlimited: false,
  limitBytes: 100,
  usedBytes: 100,
  remainingBytes: 0,
  blocked: false,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Set<String> openHere;
  late bool abroad;
  late List<String> probed;
  late List<List<Map<String, dynamic>>> reported;
  late PsiphonSettings? settings;
  late PsiphonDevice? device;
  late bool android;
  late bool tv;
  late _Traces traces;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    openHere = {};
    abroad = true;
    probed = [];
    reported = [];
    settings = backup();
    device = const PsiphonDevice(allowed: true, quota: fresh, quotaFresh: true);
    android = true;
    tv = false;
    traces = _Traces();
  });

  ConnectFlow flow(
    _FakeVpn vpn, {
    ChecklistSettings? checklist,
    Duration attemptTimeout = const Duration(seconds: 2),
  }) {
    final f = ConnectFlow(
      vpn: vpn,
      memory: PathMemory(),
      finder: PathFinder(
        read: (p) async {
          probed.add(p.pathKey);
          return openHere.contains(p.pathKey) ? open : closed;
        },
        internet: () async => abroad,
        home: () async => true,
        budget: const Duration(milliseconds: 300),
      ),
      reporter: VpnEventReporter(
        send: (_, _, _) async {},
        sendProbes: (_, probes, _) async => reported.add(probes),
        deviceId: () async => 'DEV-1',
        appVersion: () async => '1.12.0',
        platform: 'android',
        networkType: () async => 'mobile',
        queues: const [],
      ),
      ipv6: Ipv6Reach(route: () async => null),
      networkKey: () async => network,
      carrier: () async => null,
      checklist: () => checklist,
      traces: traces,
      random: () => 0.5,
      networkSettle: const Duration(milliseconds: 10),
      attemptTimeout: attemptTimeout,
      psiphon: () => settings,
      psiphonDevice: () => device,
      android: () => android,
      tv: () => tv,
    );
    addTearDown(f.cancel);
    return f;
  }

  ConnectTrace lastTrace() => traces.started.last;

  group('dialled once nothing else connected', () {
    test('after every own door was closed, as the last thing the tap '
        'does', () async {
      final vpn = _FakeVpn({backupKey});
      final f = flow(vpn);

      await f.connect(paths);

      expect(probed, [for (final p in paths) p.pathKey]);
      expect(vpn.dialled, [backupKey]);
      expect(vpn.sources, [LinkSource.psiphon]);
      expect(vpn.standbys.single, isEmpty);
      expect(f.stage, ConnectStage.done);
      expect(f.chosen, Server.psiphon);
    });

    test('after the community links too, and only then', () async {
      final vpn = _FakeVpn({backupKey});
      final f = flow(vpn);

      await f.connect(paths, shared: () async => [picked, other]);

      expect(probed, [
        for (final p in paths) p.pathKey,
        picked.pathKey,
        other.pathKey,
      ]);
      expect(vpn.dialled, [backupKey]);
      expect(f.stage, ConnectStage.done);
    });

    test('on a phone with no servers of its own, after its pick and the '
        'shared links', () async {
      final vpn = _FakeVpn({backupKey});
      final f = flow(vpn);

      await f.connectShared(picked, shared: () async => [other]);

      // The pick's check found it closed, so it was not dialled.
      expect(probed, [picked.pathKey, other.pathKey]);
      expect(vpn.dialled, [backupKey]);
      expect(f.stage, ConnectStage.done);
      expect(f.chosen, Server.psiphon);
    });

    test('never when our own door connects', () async {
      openHere = {hel2.pathKey};
      final vpn = _FakeVpn({hel2.pathKey, backupKey});
      final f = flow(vpn);

      await f.connect(paths);

      expect(vpn.dialled, [hel2.pathKey]);
      expect(f.chosen, hel2);
    });
  });

  group('every gate on its own', () {
    Future<_FakeVpn> tap() async {
      final vpn = _FakeVpn({backupKey});
      await flow(vpn).connect(paths);
      return vpn;
    }

    test('not on a phone that is not Android', () async {
      android = false;
      expect((await tap()).backupDials, 0);
    });

    test('not on a TV, unless the backend lets TVs use it', () async {
      tv = true;
      expect((await tap()).backupDials, 0);
      settings = backup(tv: true);
      expect((await tap()).backupDials, 1);
    });

    test('not without the network\'s settings', () async {
      settings = null;
      expect((await tap()).backupDials, 0);
      // A block without a network is no block.
      settings = PsiphonSettings.fromJson({'enabled': true, 'network': null});
      expect((await tap()).backupDials, 0);
    });

    test('not when the device\'s answer says no, even with the network on '
        'for everyone', () async {
      device = const PsiphonDevice(
        allowed: false,
        quota: fresh,
        quotaFresh: true,
      );
      expect((await tap()).backupDials, 0);
    });

    test('a phone that never had the answer goes by the settings', () async {
      device = const PsiphonDevice(quota: fresh, quotaFresh: true);
      settings = backup(enabled: false);
      expect((await tap()).backupDials, 0);
      settings = backup(enabled: true);
      expect((await tap()).backupDials, 1);
    });

    test('a test device the backend let in, while the network is off for '
        'everyone', () async {
      settings = backup(enabled: false);
      device = const PsiphonDevice(
        allowed: true,
        quota: fresh,
        quotaFresh: true,
      );
      expect((await tap()).backupDials, 1);
    });

    test('not without the device\'s facts', () async {
      device = null;
      expect((await tap()).backupDials, 0);
    });

    test('not on a blocked device', () async {
      device = const PsiphonDevice(
        allowed: true,
        blocked: true,
        quota: empty,
        quotaFresh: true,
      );
      expect((await tap()).backupDials, 0);
    });

    test('not when the backend says now that the allowance is spent, and '
        'the tap ends as a spent one', () async {
      var asked = 0;
      final vpn = _FakeVpn({backupKey});
      final f = flow(
        vpn,
        checklist: ChecklistSettings(
          retry: const RetrySettings(after: [Duration(milliseconds: 5)]),
        ),
      );

      // The tap asks once when every door is closed, and the backup
      // network asks again.
      await f.connect(paths, allowanceSpent: () async => ++asked > 1);

      expect(asked, 2);
      expect(vpn.backupDials, 0);
      expect(f.stage, ConnectStage.idle);
      expect(lastTrace().outcome, TraceOutcome.allowance);
    });

    test('when the backend cannot be asked, the allowance the phone last '
        'heard decides', () async {
      Future<bool> cannotAsk() async => throw Exception('no route');

      device = const PsiphonDevice(allowed: true, quota: empty);
      var vpn = _FakeVpn({backupKey});
      final f = flow(vpn);
      await f.connect(paths, allowanceSpent: cannotAsk);
      expect(vpn.backupDials, 0);
      // The try ends as it ended before.
      expect(f.stage, ConnectStage.nothingOpen);
      expect(f.chosen, isNull);
      expect(lastTrace().outcome, TraceOutcome.allClosed);

      device = const PsiphonDevice(allowed: true, quota: fresh);
      vpn = _FakeVpn({backupKey});
      await flow(vpn).connect(paths, allowanceSpent: cannotAsk);
      expect(vpn.backupDials, 1);
    });

    test(
      'an answer that did not reach the backend counts as no answer',
      () async {
        // DedicatedState answers "not spent" from what it kept when its
        // refresh failed. The kept allowance has nothing left.
        device = const PsiphonDevice(
          allowed: true,
          quota: empty,
          quotaFresh: false,
        );
        final vpn = _FakeVpn({backupKey});
        await flow(vpn).connect(paths, allowanceSpent: () async => false);
        expect(vpn.backupDials, 0);
      },
    );

    test(
      'a fresh answer that the allowance is not spent lets it through',
      () async {
        final vpn = _FakeVpn({backupKey});
        await flow(vpn).connect(paths, allowanceSpent: () async => false);
        expect(vpn.backupDials, 1);
      },
    );

    test(
      'an answer that takes too long counts as no answer',
      () async {
        device = const PsiphonDevice(allowed: true, quota: empty);
        var asked = 0;
        final vpn = _FakeVpn({backupKey});
        await flow(vpn).connect(
          paths,
          allowanceSpent: () =>
              ++asked == 1 ? Future.value(false) : Completer<bool>().future,
        );
        expect(vpn.backupDials, 0);
      },
      timeout: const Timeout(Duration(seconds: 20)),
    );

    test('not after the VPN permission was refused on this tap', () async {
      openHere = {hel1.pathKey};
      final vpn = _FakeVpn({backupKey})..refuse = {hel1.pathKey};
      final f = flow(vpn);

      await f.connect(paths);

      expect(vpn.dialled, [hel1.pathKey]);
      expect(f.stage, ConnectStage.failed);
    });

    test('only after the endings the backend names', () async {
      settings = backup(stages: {'failed'});
      expect((await tap()).backupDials, 0);
      settings = backup(stages: {'all_closed'});
      expect((await tap()).backupDials, 1);
      settings = backup(stages: const {});
      expect((await tap()).backupDials, 0);
    });

    test('a cut way abroad and no internet are endings of their own', () async {
      abroad = false;
      settings = backup(stages: {'all_closed', 'failed'});
      var vpn = _FakeVpn({backupKey});
      var f = flow(vpn);
      await f.connect(paths);
      expect(f.stage, ConnectStage.cutOff);
      expect(vpn.backupDials, 0);

      settings = backup(stages: {'cut_off'});
      vpn = _FakeVpn({backupKey});
      f = flow(vpn);
      await f.connect(paths);
      expect(vpn.backupDials, 1);
      expect(f.stage, ConnectStage.done);
    });

    test('a door whose tunnel failed is the ending "failed"', () async {
      openHere = {hel1.pathKey};
      settings = backup(stages: {'failed'});
      final vpn = _FakeVpn({backupKey});
      final f = flow(vpn);

      await f.connect(paths);

      expect(vpn.dialled, [hel1.pathKey, backupKey]);
      expect(f.stage, ConnectStage.done);
    });

    test('the round rule: from after_rounds on, every every_rounds', () async {
      settings = backup(afterRounds: 2, everyRounds: 2);
      final rounds = <int>[];
      final vpn = _FakeVpn({});
      vpn.onBackup = () => rounds.add(probed.length ~/ paths.length - 1);
      final f = flow(
        vpn,
        checklist: ChecklistSettings(
          retry: RetrySettings(
            after: [for (var i = 0; i < 10; i++) Duration(milliseconds: 5)],
          ),
        ),
      );

      unawaited(f.connect(paths));
      await until(() => probed.length >= paths.length * 8);
      f.cancel();

      expect(rounds.take(3), [2, 4, 6]);
    });

    test('a later round on the tap itself, with after_rounds 0 and every '
        'round', () async {
      final rounds = <int>[];
      final vpn = _FakeVpn({});
      vpn.onBackup = () => rounds.add(probed.length ~/ paths.length - 1);
      final f = flow(
        vpn,
        checklist: ChecklistSettings(
          retry: RetrySettings(
            after: [for (var i = 0; i < 10; i++) Duration(milliseconds: 5)],
          ),
        ),
      );

      unawaited(f.connect(paths));
      await until(() => probed.length >= paths.length * 4);
      f.cancel();

      expect(rounds.take(3), [0, 1, 2]);
    });
  });

  group('connected through it', () {
    test('the tap ends there, and the trace says so', () async {
      final vpn = _FakeVpn({backupKey});
      final f = flow(vpn);

      await f.connect(paths);

      final trace = lastTrace();
      expect(trace.outcome, TraceOutcome.psiphon);
      expect(trace.outcome!.wire, 'psiphon');
      expect(trace.chosen, 'psiphon');
      final dial = trace.steps.last;
      expect(dial.at, isNotNull);
      expect(dial.toJson(), {
        'door': 'psiphon',
        'kind': 'psiphon',
        'stage': 'dial',
        'result': 'ok',
        'reason': null,
        'ms': dial.ms,
        'at': dial.at,
      });
    });

    test('the selection does not move to it, and the memory does not hold '
        'it', () async {
      final shared = <Server>[];
      final switched = <Server>[];
      final vpn = _FakeVpn({backupKey});
      final f = flow(vpn);

      await f.connect(
        paths,
        shared: () async => [picked],
        onShared: shared.add,
        onSwitchedServer: switched.add,
      );
      await pumpEventQueue();

      expect(f.chosen, Server.psiphon);
      expect(shared, isEmpty);
      expect(switched, isEmpty);
      final memory = PathMemory();
      expect(await memory.recall(network), isNull);
      expect(await memory.recallShared(network), isNull);
      expect(await memory.failedToday(network), isNot(contains(backupKey)));
    });

    test('no door is checked after it, and no row names it', () async {
      final vpn = _FakeVpn({backupKey});
      final f = flow(vpn);

      await f.connect(paths);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(probed, [for (final p in paths) p.pathKey]);
      for (final row in [for (final b in reported) ...b]) {
        expect('$row', isNot(contains('psiphon')));
      }
    });

    test('the retries stop there', () async {
      final vpn = _FakeVpn({backupKey});
      final f = flow(
        vpn,
        checklist: ChecklistSettings(
          retry: const RetrySettings(
            after: [Duration(milliseconds: 5), Duration(milliseconds: 5)],
          ),
        ),
      );

      await f.connect(paths);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(f.stage, ConnectStage.done);
      expect(vpn.backupDials, 1);
      expect(probed, hasLength(paths.length));
    });

    test('a dead tunnel through it is never written down as a door', () async {
      final vpn = _FakeVpn({backupKey});
      final f = flow(vpn);
      await f.connect(paths);

      await f.forgetStalledDoor(Server.psiphon);

      expect(await PathMemory().failedToday(network), isEmpty);
    });

    test('a pick while on it dials as a pick on any other link does', () async {
      final vpn = _FakeVpn({backupKey, fsn1.pathKey});
      final f = flow(vpn);
      await f.connect(paths);
      expect(f.chosen, Server.psiphon);

      openHere = {fsn1.pathKey};
      await f.connect(paths, preferred: fsn1);

      expect(vpn.dialled.last, fsn1.pathKey);
      expect(f.stage, ConnectStage.done);
      expect(f.chosen, fsn1);
    });

    // A pick on Your servers runs the flow over the live tunnel. When every
    // door of ours is closed and no community link opens, the tap ends with
    // nothing open while the backup network still carries the traffic.
    // Dialling it again would take that tunnel down first.
    test('a pick that finds nothing open while on it leaves it up', () async {
      final vpn = _FakeVpn({backupKey});
      final f = flow(vpn);
      await f.connect(paths);
      expect(f.chosen, Server.psiphon);
      expect(vpn.isConnected, isTrue);

      await f.connect(paths, preferred: fsn1);

      expect(f.stage, ConnectStage.nothingOpen);
      expect(vpn.backupDials, 1);
      expect(vpn.downs, 0);
      expect(vpn.isConnected, isTrue);
      expect(vpn.active, Server.psiphon);
      expect(lastTrace().outcome, TraceOutcome.allClosed);
    });

    test('it has its own time to come up, longer than a door\'s', () async {
      final vpn = _FakeVpn({backupKey})
        ..backupTakes = const Duration(milliseconds: 400);
      final f = flow(vpn, attemptTimeout: const Duration(milliseconds: 100));

      await f.connect(paths);

      expect(f.stage, ConnectStage.done);
      expect(f.chosen, Server.psiphon);
    });
  });

  group('a tunnel that is up', () {
    test('through one of our doors is never taken down for it', () async {
      openHere = {hel1.pathKey};
      final vpn = _FakeVpn({hel1.pathKey, backupKey});
      final f = flow(
        vpn,
        checklist: ChecklistSettings(
          retry: const RetrySettings(after: [Duration(milliseconds: 5)]),
        ),
      );
      await f.connect(paths);
      expect(f.chosen, hel1);
      final before = probed.length;

      // A pick of another server, as Your servers makes it.
      openHere = {};
      unawaited(f.connect(paths, preferred: fsn1));
      // The tap and a try after its wait.
      await until(() => probed.length >= before + paths.length * 2);
      f.cancel();

      expect(vpn.backupDials, 0);
      expect(vpn.downs, 0);
      expect(vpn.isConnected, isTrue);
      expect(vpn.active, hel1);
    });

    test('found dead is replaced by it, as a door would replace it', () async {
      openHere = {hel1.pathKey};
      final vpn = _FakeVpn({hel1.pathKey, backupKey});
      final f = flow(vpn);
      await f.connect(paths);
      expect(f.chosen, hel1);

      // As StallRecovery does it: the dead door first, then the search.
      openHere = {};
      vpn.stall = true;
      await f.forgetStalledDoor(hel1);
      await f.connect(paths, afterStall: true);

      expect(vpn.backupDials, 1);
      expect(f.stage, ConnectStage.done);
      expect(f.chosen, Server.psiphon);
      expect(vpn.active, Server.psiphon);
    });

    test('that came up late, while the allowance was asked, is left '
        'up', () async {
      final vpn = _FakeVpn({backupKey});
      final f = flow(vpn);
      var calls = 0;

      await f.connect(
        paths,
        allowanceSpent: () async {
          // The second question is the backup network's.
          if (++calls == 2) vpn.comeUpLate(hel1);
          return false;
        },
      );

      expect(calls, 2);
      expect(vpn.backupDials, 0);
      expect(vpn.downs, 0);
      expect(f.stage, ConnectStage.nothingOpen);
      expect(f.tryingBackup, isFalse);
      // Not dialled, so its stage reads skipped, not failed (clients #342).
      expect(f.stageState(RouteKind.backup), StageState.skipped);
    });
  });

  group('when it fails too', () {
    test('the tap ends as it ended before, and the error is not left on '
        'screen', () async {
      final vpn = _FakeVpn({});
      final f = flow(vpn);

      await f.connect(paths);

      expect(vpn.backupDials, 1);
      expect(f.stage, ConnectStage.nothingOpen);
      expect(f.chosen, isNull);
      expect(vpn.status, isNot(VpnStatus.error));
      final trace = lastTrace();
      expect(trace.outcome, TraceOutcome.allClosed);
      expect(trace.steps.last.door, 'psiphon');
      expect(trace.steps.last.result, TraceResult.fail);
      expect(await PathMemory().failedToday(network), isEmpty);
    });

    test(
      'after a door whose tunnel failed, the card names that door again',
      () async {
        openHere = {hel1.pathKey};
        final vpn = _FakeVpn({});
        final f = flow(vpn);

        await f.connect(paths);

        expect(vpn.dialled, [hel1.pathKey, backupKey]);
        expect(f.stage, ConnectStage.failed);
        expect(f.chosen, hel1);
        expect(lastTrace().outcome, TraceOutcome.failed);
      },
    );

    test(
      'the tap keeps searching, and tries it again on the next round',
      () async {
        final vpn = _FakeVpn({});
        final f = flow(
          vpn,
          checklist: ChecklistSettings(
            retry: const RetrySettings(after: [Duration(milliseconds: 300)]),
          ),
        );

        unawaited(f.connect(paths));
        await until(() => f.stage == ConnectStage.waiting);
        expect(f.waitingAfter, ConnectStage.nothingOpen);
        expect(vpn.backupDials, 1);

        await until(() => vpn.backupDials == 2);
        f.cancel();
        expect(probed, hasLength(paths.length * 2));
      },
    );

    test('a permission refused on it ends the search, as one refused on a '
        'door does', () async {
      final vpn = _FakeVpn({})..refuse = {backupKey};
      final f = flow(
        vpn,
        checklist: ChecklistSettings(
          retry: const RetrySettings(after: [Duration(milliseconds: 5)]),
        ),
      );

      await f.connect(paths);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(f.stage, ConnectStage.nothingOpen);
      expect(lastTrace().outcome, TraceOutcome.permission);
      expect(probed, hasLength(paths.length));
    });
  });

  group('a stop while it comes up', () {
    test('a stop while it asks about the allowance dials nothing', () async {
      final asked = Completer<bool>();
      var calls = 0;
      final vpn = _FakeVpn({backupKey});
      final f = flow(vpn);

      final tap = f.connect(
        paths,
        allowanceSpent: () => ++calls == 1 ? Future.value(false) : asked.future,
      );
      await until(() => calls == 2);
      // Busy, so a tap on the button is a stop.
      expect(f.isBusy, isTrue);
      expect(f.tryingBackup, isTrue);

      f.cancel();
      asked.complete(false);
      await tap;

      expect(vpn.backupDials, 0);
      expect(f.stage, ConnectStage.cancelled);
      expect(lastTrace().outcome, TraceOutcome.stopped);
    });

    test(
      'stops it, the tap ends on the stop, and nothing tries again',
      () async {
        final vpn = _FakeVpn({backupKey})..hangBackup = true;
        final f = flow(
          vpn,
          checklist: ChecklistSettings(
            retry: const RetrySettings(after: [Duration(milliseconds: 5)]),
          ),
        );

        final tap = f.connect(paths);
        await vpn.backupStarted.future;
        await pumpEventQueue();
        expect(f.stage, ConnectStage.connecting);
        expect(f.tryingBackup, isTrue);
        expect(f.chosen, Server.psiphon);

        f.cancel();
        await tap;
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(f.stage, ConnectStage.cancelled);
        expect(f.tryingBackup, isFalse);
        expect(lastTrace().outcome, TraceOutcome.stopped);
        expect(lastTrace().steps.last.reason, TraceReason.stopped);
        expect(vpn.backupDials, 1);
        expect(probed, hasLength(paths.length));
      },
    );
  });
}
