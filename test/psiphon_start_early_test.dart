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

/// The backup network, started earlier in a tap (clients #299, round 2).
///
/// With the backend's start_after_ms, a tap that has looked that long for
/// one of our doors or a community link without a tunnel stops looking at
/// its next safe point, ends at nothing open, and the backup network step
/// runs at once with all its gates. Without it every tap runs as before.
/// Every value of the network's settings here is made up.
Server own(int row) => Server.fromDedicatedPath(
  uri:
      'vless://u@192.0.2.$row:8443?type=tcp&security=reality'
      '&sni=www.samsung.com&pbk=key#Row$row',
  door: 'tcp-reality',
  doorLabel: 'tcp-reality',
  serverId: row,
);

/// Ten doors on ten servers, in the backend's order. One at a time, at
/// [probeTime] each, the search takes about 800 ms.
final doors = [for (var row = 1; row <= 10; row++) own(row)];

Server link(int i) => Server.fromConnectionUri(
  'vless://u@h$i.example:443?type=tcp&security=reality'
  '&sni=www.samsung.com&pbk=key#Link$i',
  index: i,
);

final links = [for (var i = 1; i <= 6; i++) link(i)];

const open = DoorOutcome(ms: 120, tcpMs: 40, phase: 'ok');
const closed = DoorOutcome(
  ms: -1,
  error: 'tcp timeout; no answer in 3000 ms',
  phase: 'tcp',
);

/// How long one door check takes here.
const probeTime = Duration(milliseconds: 80);

/// The backend's start_after_ms in these tests: about the third check.
const startAfter = Duration(milliseconds: 200);

final backupKey = Server.psiphon.pathKey;

const network = 'mobile';

const networkSettings = {
  'PropagationChannelId': '0123456789ABCDEF',
  'SponsorId': '0123456789ABCDEF',
};

/// The own doors one at a time, so a search's time is easy to count.
const oneAtATime = ChecklistSettings(doors: DoorCheckSettings.oneAtATime);

PsiphonSettings backup({
  Duration? after = startAfter,
  Set<String> stages = PsiphonSettings.defaultStages,
  int afterRounds = 0,
  bool tv = false,
}) => PsiphonSettings(
  network: networkSettings,
  enabled: true,
  startAfter: after,
  stages: stages,
  afterRounds: afterRounds,
  tv: tv,
  establishTimeout: const Duration(seconds: 1),
);

const fresh = QuotaStatus(
  unlimited: false,
  limitBytes: 100,
  usedBytes: 10,
  remainingBytes: 90,
  blocked: false,
);

const spent = QuotaStatus(
  unlimited: false,
  limitBytes: 100,
  usedBytes: 100,
  remainingBytes: 0,
  blocked: true,
);

/// A tunnel that comes up through the links in [works] and fails through
/// everything else, after [takes] for that link or 2 ms.
class _FakeVpn extends VpnService {
  _FakeVpn(this.works)
    : super(
        events: VpnEventReporter(send: (_, _, _) async {}, queues: const []),
      );

  final Set<String> works;
  final dialled = <String>[];
  final takes = <String, Duration>{};

  /// Links whose tunnel comes up and is then checked for this long before
  /// it carries or fails, as a real dial's traffic check is.
  final verifies = <String, Duration>{};
  bool _verifying = false;

  /// Links whose dial fails because the VPN permission was refused.
  Set<String> refuse = {};
  bool _refused = false;

  /// When each dial of the backup network started.
  final backupAt = <DateTime>[];

  /// Called when each dial of the backup network starts.
  void Function()? onBackup;

  VpnStatus _fakeStatus = VpnStatus.disconnected;
  Server? active;

  @override
  VpnStatus get status => _fakeStatus;

  @override
  bool get isConnected => _fakeStatus == VpnStatus.connected;

  @override
  bool get isConnecting => _fakeStatus == VpnStatus.connecting;

  @override
  bool get isVerifying => _verifying;

  @override
  Server? get activeDoor => active;

  @override
  bool get failedOnPermission => _refused;

  @override
  Future<void> connect(
    Server server, {
    String? attemptId,
    List<Server> standby = const [],
    LinkSource? source,
  }) async {
    dialled.add(server.pathKey);
    if (server.isPsiphon) {
      backupAt.add(DateTime.now());
      onBackup?.call();
    }
    active = server;
    _refused = false;
    _fakeStatus = VpnStatus.connecting;
    notifyListeners();
    await Future<void>.delayed(
      takes[server.pathKey] ?? const Duration(milliseconds: 2),
    );
    final checked = verifies[server.pathKey];
    if (checked != null) {
      _fakeStatus = VpnStatus.connected;
      _verifying = true;
      notifyListeners();
      await Future<void>.delayed(checked);
      _verifying = false;
    }
    _refused = refuse.contains(server.pathKey);
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

  @override
  void clearError() {
    if (_fakeStatus == VpnStatus.error) _fakeStatus = VpnStatus.disconnected;
    notifyListeners();
  }

  int get backupDials => backupAt.length;
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
  Duration within = const Duration(seconds: 5),
}) async {
  final end = DateTime.now().add(within);
  while (!ok()) {
    if (DateTime.now().isAfter(end)) fail('still waiting after $within');
    await Future<void>.delayed(const Duration(milliseconds: 2));
  }
}

List<String> keys(Iterable<Server> servers) => [
  for (final s in servers) s.pathKey,
];

Iterable<TraceStep> cutSteps(ConnectTrace trace) =>
    trace.steps.where((s) => s.stage == TraceStage.cut);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Set<String> openHere;
  late Map<String, Duration> probeTimes;
  late List<String> probed;
  late List<List<Map<String, dynamic>>> reported;
  late PsiphonSettings? settings;
  late PsiphonDevice? device;
  late bool android;
  late bool tv;
  late _Traces traces;
  // What the control fetch reaches: a site abroad, and one inside the
  // country.
  late bool abroad;
  late bool inside;
  // How long the control fetch takes to answer.
  late Duration fetchTakes;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    openHere = {};
    probeTimes = {};
    probed = [];
    reported = [];
    settings = backup();
    device = const PsiphonDevice(allowed: true, quota: fresh, quotaFresh: true);
    android = true;
    tv = false;
    traces = _Traces();
    abroad = true;
    inside = true;
    fetchTakes = Duration.zero;
  });

  ConnectFlow flow(
    _FakeVpn vpn, {
    ChecklistSettings checklist = oneAtATime,
    Duration attemptTimeout = const Duration(seconds: 2),
  }) {
    final f = ConnectFlow(
      vpn: vpn,
      memory: PathMemory(),
      finder: PathFinder(
        read: (p) async {
          probed.add(p.pathKey);
          await Future<void>.delayed(probeTimes[p.pathKey] ?? probeTime);
          return openHere.contains(p.pathKey) ? open : closed;
        },
        internet: () async {
          await Future<void>.delayed(fetchTakes);
          return abroad;
        },
        home: () async => inside,
        budget: const Duration(seconds: 10),
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

  /// A tap over [doors], all closed, that must check every one of them and
  /// put no cut in its trace.
  Future<_FakeVpn> expectNoCut() async {
    final vpn = _FakeVpn({});
    await flow(vpn).connect(doors);
    expect(probed, keys(doors), reason: 'every door is checked');
    expect(cutSteps(lastTrace()), isEmpty);
    return vpn;
  }

  group('without start_after_ms', () {
    test(
      'every door is checked before the backup network, as before',
      () async {
        settings = backup(after: null);
        final vpn = _FakeVpn({backupKey});
        final f = flow(vpn);
        final from = DateTime.now();

        await f.connect(doors);

        expect(probed, keys(doors));
        expect(vpn.dialled, [backupKey]);
        expect(
          vpn.backupAt.single.difference(from),
          greaterThanOrEqualTo(probeTime * doors.length),
        );
        expect(cutSteps(lastTrace()), isEmpty);
        expect(f.stage, ConnectStage.done);
      },
    );

    test('the shared links are checked too, as before', () async {
      settings = backup(after: null);
      final vpn = _FakeVpn({});
      final f = flow(vpn);

      await f.connect(doors, shared: () async => links);

      expect(probed, [...keys(doors), ...keys(links)]);
      expect(vpn.dialled, [backupKey]);
      expect(f.stage, ConnectStage.nothingOpen);
    });
  });

  group('past start_after the search stops', () {
    test('at the check in flight, and the backup network is dialled at '
        'about that time', () async {
      final vpn = _FakeVpn({backupKey});
      final f = flow(vpn);
      final from = DateTime.now();

      await f.connect(doors);

      final at = vpn.backupAt.single.difference(from);
      expect(at, greaterThanOrEqualTo(startAfter));
      expect(at, lessThan(startAfter + probeTime * 4));
      // The check in flight at the deadline answered; none started after.
      expect(probed.length, lessThan(doors.length ~/ 2));
      expect(probed, keys(doors.take(probed.length)));
      expect(vpn.dialled, [backupKey]);
      expect(f.stage, ConnectStage.done);
      expect(f.chosen, Server.psiphon);
      expect(lastTrace().outcome, TraceOutcome.psiphon);
    });

    test('several checks at once stop at once, without waiting for the '
        'ones in flight', () async {
      final vpn = _FakeVpn({backupKey});
      final f = flow(
        vpn,
        checklist: const ChecklistSettings(
          doors: DoorCheckSettings(parallel: 3, stagger: Duration.zero),
        ),
      );
      for (final d in doors) {
        probeTimes[d.pathKey] = startAfter * 3;
      }
      final from = DateTime.now();

      await f.connect(doors);

      expect(vpn.backupAt.single.difference(from), lessThan(startAfter * 2));
      expect(probed, keys(doors.take(3)));
      // The checks the cut left were never answered: no row says closed.
      final steps = lastTrace().steps;
      expect(steps.where((s) => s.result == TraceResult.fail), isEmpty);
    });

    test('in a race of community links, which checks no more links', () async {
      // The own doors answer at once; the links take their time.
      for (final d in doors) {
        probeTimes[d.pathKey] = Duration.zero;
      }
      for (final l in links) {
        probeTimes[l.pathKey] = probeTime;
      }
      final vpn = _FakeVpn({});
      final shared = <Server>[];
      final f = flow(
        vpn,
        checklist: ChecklistSettings(
          doors: DoorCheckSettings.oneAtATime,
          fallback: FallbackSettings(links: links.length, parallel: 1),
        ),
      );

      await f.connect(doors, shared: () async => links, onShared: shared.add);

      final checkedLinks = probed.where(keys(links).contains).toList();
      expect(checkedLinks, isNotEmpty);
      expect(checkedLinks.length, lessThan(links.length));
      expect(vpn.dialled, [backupKey]);
      expect(shared, isEmpty);
      // The links it did not reach are not put at the back for the day.
      final failed = await PathMemory().failedToday(network);
      for (final l in links.skip(checkedLinks.length)) {
        expect(failed, isNot(contains(l.pathKey)));
      }
    });

    test('on a phone with no servers of its own, after its pick', () async {
      for (final l in links) {
        probeTimes[l.pathKey] = probeTime;
      }
      final vpn = _FakeVpn({backupKey});
      final f = flow(vpn);

      await f.connectShared(
        links.first,
        shared: () async => links.skip(1).toList(),
      );

      // The pick's check found it closed, so it was not dialled, and the
      // race after it was cut.
      expect(probed.first, links.first.pathKey);
      expect(probed.length, lessThan(links.length));
      expect(vpn.dialled, [backupKey]);
      expect(f.stage, ConnectStage.done);
      expect(f.chosen, Server.psiphon);
      expect(cutSteps(lastTrace()), hasLength(1));
    });
  });

  group('a dial in flight at the deadline', () {
    test('runs to its end, and the tap ends connected through it', () async {
      final door = doors.first;
      openHere = {door.pathKey};
      final vpn = _FakeVpn({door.pathKey, backupKey})
        ..takes[door.pathKey] = startAfter * 2;
      final f = flow(vpn);

      await f.connect(doors);

      expect(vpn.dialled, [door.pathKey]);
      expect(f.stage, ConnectStage.done);
      expect(f.chosen, door);
      expect(lastTrace().outcome, TraceOutcome.connected);
      expect(cutSteps(lastTrace()), isEmpty);
      // Remembered as any door that carried traffic is.
      expect(await PathMemory().recall(network), door.pathKey);
    });

    test('that fails is followed by the backup network, not by the shared '
        'links', () async {
      final door = doors.first;
      openHere = {door.pathKey};
      final vpn = _FakeVpn({})..takes[door.pathKey] = startAfter * 2;
      var asked = 0;
      final f = flow(vpn);

      await f.connect(
        doors,
        shared: () async {
          asked++;
          return links;
        },
      );

      expect(vpn.dialled, [door.pathKey, backupKey]);
      expect(probed, [door.pathKey]);
      expect(asked, 0, reason: 'no links asked for after the cut');
      expect(f.stage, ConnectStage.nothingOpen);
      final steps = lastTrace().steps;
      expect(steps[steps.length - 2].stage, TraceStage.cut);
      expect(steps.last.door, 'psiphon');
    });
  });

  group('a dial whose tunnel is still being checked at the deadline', () {
    test('and then fails is followed by the backup network, not by the rest '
        'of the search', () async {
      final door = doors.first;
      openHere = {door.pathKey};
      final vpn = _FakeVpn({})..verifies[door.pathKey] = startAfter * 2;
      var asked = 0;
      final f = flow(vpn);

      await f.connect(
        doors,
        shared: () async {
          asked++;
          return links;
        },
      );

      expect(vpn.dialled, [door.pathKey, backupKey]);
      expect(probed, [door.pathKey], reason: 'no door checked after the cut');
      expect(asked, 0, reason: 'no links asked for after the cut');
      expect(f.stage, ConnectStage.nothingOpen);
      final steps = lastTrace().steps;
      expect(steps[steps.length - 2].stage, TraceStage.cut);
      expect(steps.last.door, 'psiphon');
    });

    test(
      'and then carries ends the tap connected through it, with no cut',
      () async {
        final door = doors.first;
        openHere = {door.pathKey};
        final vpn = _FakeVpn({door.pathKey, backupKey})
          ..verifies[door.pathKey] = startAfter * 2;
        final f = flow(vpn);

        await f.connect(doors);

        expect(vpn.dialled, [door.pathKey]);
        expect(f.stage, ConnectStage.done);
        expect(f.chosen, door);
        expect(lastTrace().outcome, TraceOutcome.connected);
        expect(cutSteps(lastTrace()), isEmpty);
      },
    );
  });

  group('a door or link found open is still dialled after the cut', () {
    test('one at a time: the check in flight at the deadline finds a door '
        'open, and the tap connects through it', () async {
      // Door 3 is checked from about 0 ms to 400 ms, across the deadline.
      final door = doors[2];
      openHere = {door.pathKey};
      probeTimes[doors[0].pathKey] = Duration.zero;
      probeTimes[doors[1].pathKey] = Duration.zero;
      probeTimes[door.pathKey] = startAfter * 2;
      final vpn = _FakeVpn({door.pathKey, backupKey});
      final f = flow(vpn);

      await f.connect(doors);

      expect(probed, keys(doors.take(3)));
      expect(vpn.dialled, [door.pathKey]);
      expect(f.stage, ConnectStage.done);
      expect(f.chosen?.pathKey, door.pathKey);
      expect(lastTrace().outcome, TraceOutcome.connected);
      expect(cutSteps(lastTrace()), isEmpty);
      expect(await PathMemory().recall(network), door.pathKey);
    });

    test('one at a time: when that door\'s tunnel fails, the backup network '
        'follows, and no other door or link is checked', () async {
      final door = doors[2];
      openHere = {door.pathKey};
      probeTimes[doors[0].pathKey] = Duration.zero;
      probeTimes[doors[1].pathKey] = Duration.zero;
      probeTimes[door.pathKey] = startAfter * 2;
      final vpn = _FakeVpn({backupKey});
      final f = flow(vpn);

      await f.connect(doors, shared: () async => links);

      expect(probed, keys(doors.take(3)));
      expect(vpn.dialled, [door.pathKey, backupKey]);
      expect(f.chosen, Server.psiphon);
      expect(cutSteps(lastTrace()), hasLength(1));
      // Its tunnel failed, and that is written down as any failure is.
      expect(await PathMemory().failedToday(network), contains(door.pathKey));
    });

    test('several checks at once: a door found open below one whose check '
        'still runs is dialled at the cut', () async {
      probeTimes[doors[0].pathKey] = const Duration(seconds: 1);
      probeTimes[doors[1].pathKey] = const Duration(milliseconds: 20);
      probeTimes[doors[2].pathKey] = const Duration(seconds: 1);
      openHere = {doors[1].pathKey};
      final vpn = _FakeVpn({doors[1].pathKey, backupKey});
      final f = flow(
        vpn,
        checklist: const ChecklistSettings(
          doors: DoorCheckSettings(parallel: 3, stagger: Duration.zero),
        ),
      );
      final from = DateTime.now();

      await f.connect(doors);

      // Without the cut, the tap waits for the first door's check.
      expect(
        DateTime.now().difference(from),
        lessThan(const Duration(milliseconds: 800)),
      );
      // A check that ends lets the next one start, until the cut.
      expect(probed.length, lessThan(doors.length));
      expect(vpn.dialled, [doors[1].pathKey]);
      expect(f.stage, ConnectStage.done);
      expect(f.chosen?.pathKey, doors[1].pathKey);
      expect(vpn.backupDials, 0);
    });

    /// Our doors answer closed at once. The first link is open after 20
    /// ms, and the other links of the race take past the deadline.
    ChecklistSettings slowRace() {
      for (final d in doors) {
        probeTimes[d.pathKey] = Duration.zero;
      }
      openHere = {links[0].pathKey};
      probeTimes[links[0].pathKey] = const Duration(milliseconds: 20);
      for (final l in links.skip(1)) {
        probeTimes[l.pathKey] = startAfter * 2;
      }
      return ChecklistSettings(
        doors: DoorCheckSettings.oneAtATime,
        fallback: FallbackSettings(links: links.length, parallel: 3),
      );
    }

    test('a race of community links: a link found open while slower links '
        'still run is dialled, round after round', () async {
      final vpn = _FakeVpn({links[0].pathKey});
      final shared = <Server>[];
      final f = flow(vpn, checklist: slowRace());

      await f.connect(doors, shared: () async => links, onShared: shared.add);

      expect(vpn.dialled, [links[0].pathKey]);
      expect(f.stage, ConnectStage.done);
      expect(f.chosen?.pathKey, links[0].pathKey);
      expect(keys(shared), [links[0].pathKey]);
      expect(vpn.backupDials, 0);
      expect(probed.where(keys(links).contains), keys(links.take(3)));
      expect(await PathMemory().recallShared(network), links[0].pathKey);
    });

    test('a race of community links: when the found link\'s tunnel fails, '
        'the backup network follows', () async {
      final vpn = _FakeVpn({backupKey});
      final checklist = slowRace();
      // The open link is second, below one still running at the deadline.
      // The race returns at the cut with the link it found open.
      openHere = {links[1].pathKey};
      probeTimes[links[0].pathKey] = startAfter * 2;
      probeTimes[links[1].pathKey] = const Duration(milliseconds: 20);
      final f = flow(vpn, checklist: checklist);

      await f.connect(doors, shared: () async => links);

      expect(vpn.dialled, [links[1].pathKey, backupKey]);
      expect(f.chosen, Server.psiphon);
      expect(cutSteps(lastTrace()), hasLength(1));
      expect(probed.where(keys(links).contains), keys(links.take(3)));
    });

    /// The last door failed three times today, so the checklist skips it
    /// and only the last pass checks it, across the deadline. Every other
    /// door answers closed at once.
    Future<ChecklistSettings> skippedLast() async {
      final skipped = doors.last;
      for (var i = 0; i < PathMemory.maxFailsPerDay; i++) {
        await PathMemory().markFailed(network, skipped.pathKey);
      }
      for (final d in doors) {
        probeTimes[d.pathKey] = Duration.zero;
      }
      probeTimes[skipped.pathKey] = startAfter * 2;
      openHere = {skipped.pathKey};
      return const ChecklistSettings(
        doors: DoorCheckSettings.oneAtATime,
        lastPass: LastPassSettings(
          doors: 16,
          parallel: 1,
          timeout: Duration(seconds: 1),
        ),
      );
    }

    test('a door skipped for the day that the last pass finds open is '
        'dialled at once, without the shared links', () async {
      final skipped = doors.last;
      final checklist = await skippedLast();
      final vpn = _FakeVpn({skipped.pathKey, backupKey});
      final f = flow(vpn, checklist: checklist);
      var asked = 0;

      await f.connect(
        doors,
        shared: () async {
          asked++;
          return links;
        },
      );

      expect(probed, keys(doors));
      expect(asked, 0);
      expect(vpn.dialled, [skipped.pathKey]);
      expect(f.stage, ConnectStage.done);
      expect(f.chosen?.pathKey, skipped.pathKey);
    });

    test('a door skipped for the day whose tunnel then fails ends the tap at '
        'the cut, and the backup network follows', () async {
      final checklist = await skippedLast();
      final vpn = _FakeVpn({backupKey});
      final f = flow(vpn, checklist: checklist);

      await f.connect(doors, shared: () async => links);

      expect(vpn.dialled, [doors.last.pathKey, backupKey]);
      expect(f.chosen, Server.psiphon);
      expect(cutSteps(lastTrace()), hasLength(1));
    });

    test('beside our own doors, a pick found open is dialled', () async {
      // The pick answers at once; our doors take past the deadline.
      final pick = links[0];
      openHere = {pick.pathKey};
      for (final d in doors) {
        probeTimes[d.pathKey] = startAfter * 2;
      }
      probeTimes[pick.pathKey] = const Duration(milliseconds: 20);
      final vpn = _FakeVpn({pick.pathKey, backupKey});
      final f = flow(
        vpn,
        checklist: const ChecklistSettings(
          doors: DoorCheckSettings.oneAtATime,
          fallback: FallbackSettings(links: 1, parallel: 1, ownFirst: 3),
        ),
      );

      await f.connect(doors, picked: pick, ownFirst: true);

      expect(probed.toSet(), {...keys(doors.take(3)), pick.pathKey});
      expect(vpn.dialled, [pick.pathKey]);
      expect(f.stage, ConnectStage.done);
      expect(vpn.backupDials, 0);
    });
  });

  group('a tap whose control fetch failed', () {
    test('is not cut when the stages leave out no_internet, and ends at no '
        'internet as before', () async {
      abroad = false;
      inside = false;

      final vpn = await expectNoCut();

      expect(vpn.backupDials, 0);
      expect(lastTrace().outcome, TraceOutcome.noInternet);
    });

    test('is cut when the stages name no_internet, and ends there when the '
        'backup network fails', () async {
      abroad = false;
      inside = false;
      settings = backup(stages: {'all_closed', 'no_internet'});
      final vpn = _FakeVpn({});
      final f = flow(vpn);

      await f.connect(doors);

      expect(probed.length, lessThan(doors.length));
      expect(vpn.backupDials, 1);
      expect(f.stage, ConnectStage.noInternet);
      expect(lastTrace().outcome, TraceOutcome.noInternet);
      // As on a tap that ends at no internet, the trace names no door.
      expect(
        [for (final s in lastTrace().steps) s.stage],
        [TraceStage.cut, TraceStage.dial],
      );
    });

    test('with only the way abroad cut, is cut, and ends at cut off when the '
        'backup network fails', () async {
      abroad = false;
      final vpn = _FakeVpn({});
      final f = flow(vpn);

      await f.connect(doors);

      expect(probed.length, lessThan(doors.length));
      expect(vpn.backupDials, 1);
      expect(f.stage, ConnectStage.cutOff);
      expect(lastTrace().outcome, TraceOutcome.cutOff);
      expect(cutSteps(lastTrace()), hasLength(1));
    });

    test('after the deadline is not cut, and ends at no internet as '
        'before', () async {
      abroad = false;
      inside = false;
      fetchTakes = startAfter * 2;

      final vpn = await expectNoCut();

      expect(vpn.backupDials, 0);
      expect(lastTrace().outcome, TraceOutcome.noInternet);
    });

    test('control: a fetch that passes after the deadline is waited for, '
        'then the search is cut', () async {
      fetchTakes = startAfter * 2;
      final vpn = _FakeVpn({backupKey});
      final f = flow(vpn);
      final from = DateTime.now();

      await f.connect(doors);

      expect(
        vpn.backupAt.single.difference(from),
        greaterThanOrEqualTo(fetchTakes),
      );
      expect(probed.length, lessThan(doors.length));
      expect(f.chosen, Server.psiphon);
      expect(cutSteps(lastTrace()), hasLength(1));
    });
  });

  test('on a phone with no servers of its own, a pick whose dial runs past '
      'the deadline is still written down as failed', () async {
    final pick = links.first;
    // Its check passes, so it is dialled.
    openHere = {pick.pathKey};
    probeTimes[pick.pathKey] = Duration.zero;
    final vpn = _FakeVpn({backupKey})..takes[pick.pathKey] = startAfter * 2;
    final f = flow(vpn);
    var asked = 0;

    await f.connectShared(
      pick,
      shared: () async {
        asked++;
        return links.skip(1).toList();
      },
    );

    expect(vpn.dialled, [pick.pathKey, backupKey]);
    expect(asked, 0, reason: 'no links asked for after the cut');
    expect(probed, [pick.pathKey]);
    expect(cutSteps(lastTrace()), hasLength(1));
    expect(await PathMemory().failedToday(network), contains(pick.pathKey));
  });

  group('no cut while a gate is closed', () {
    test('not on a phone that is not Android', () async {
      android = false;
      await expectNoCut();
    });

    test('not on a TV, unless the backend lets TVs use it', () async {
      tv = true;
      await expectNoCut();

      probed.clear();
      settings = backup(tv: true);
      await flow(_FakeVpn({})).connect(doors);
      expect(probed.length, lessThan(doors.length));
      expect(cutSteps(lastTrace()), hasLength(1));
    });

    test('not without the network\'s settings', () async {
      settings = PsiphonSettings.fromJson({
        'enabled': true,
        'network': null,
        'start_after_ms': 5000,
      });
      expect(settings, isNull);
      await expectNoCut();
    });

    test('not when the device may not use it', () async {
      device = const PsiphonDevice(
        allowed: false,
        quota: fresh,
        quotaFresh: true,
      );
      await expectNoCut();

      probed.clear();
      device = null;
      await expectNoCut();
    });

    test('not on a blocked device', () async {
      device = const PsiphonDevice(
        allowed: true,
        blocked: true,
        quota: spent,
        quotaFresh: true,
      );
      await expectNoCut();
    });

    test('not when the endings it may follow leave out all_closed', () async {
      settings = backup(stages: {'failed', 'cut_off'});
      await expectNoCut();
    });

    test('not on a round the round rule leaves out, and on the next one '
        'it allows', () async {
      settings = backup(afterRounds: 1);
      final vpn = _FakeVpn({});
      final f = flow(
        vpn,
        checklist: const ChecklistSettings(
          doors: DoorCheckSettings.oneAtATime,
          retry: RetrySettings(after: [Duration(milliseconds: 10)]),
        ),
      );

      unawaited(f.connect(doors));
      await until(() => vpn.backupDials == 1);
      f.cancel();

      // The tap itself checked every door; the round after it was cut.
      expect(probed.take(doors.length), keys(doors));
      expect(probed.length, lessThan(doors.length * 2));
      expect(cutSteps(traces.started.first), isEmpty);
      expect(cutSteps(traces.started.last), hasLength(1));
    });

    test('not while a tunnel carries data', () async {
      final door = doors.first;
      openHere = {door.pathKey};
      final vpn = _FakeVpn({door.pathKey});
      final f = flow(vpn);
      await f.connect(doors);
      expect(f.chosen, door);

      // A pick of another server over the live tunnel, as Your servers
      // makes it, finds every door closed.
      openHere = {};
      probed.clear();
      await f.connect(doors, preferred: doors.last);

      expect(probed, hasLength(doors.length));
      expect(cutSteps(lastTrace()), isEmpty);
      expect(vpn.backupDials, 0);
      expect(vpn.active, door);
      expect(vpn.isConnected, isTrue);
    });

    test('not when a gate closes before the deadline', () async {
      Timer(startAfter ~/ 2, () {
        device = const PsiphonDevice(
          allowed: true,
          blocked: true,
          quota: spent,
          quotaFresh: true,
        );
      });
      final vpn = await expectNoCut();
      expect(vpn.backupDials, 0);
    });
  });

  group('after the cut', () {
    test('the trace has the cut, just before the backup network\'s '
        'dial', () async {
      final vpn = _FakeVpn({});
      final f = flow(vpn);

      await f.connect(doors);

      final steps = lastTrace().steps;
      expect(cutSteps(lastTrace()), hasLength(1));
      final cut = steps[steps.length - 2];
      expect(cut.toJson(), {
        'door': 'psiphon',
        'kind': 'psiphon',
        'stage': 'cut',
        'result': 'cut',
        'reason': null,
        'ms': cut.ms,
        'at': cut.at,
      });
      expect(cut.ms, greaterThanOrEqualTo(startAfter.inMilliseconds));
      // The cut starts when it is made, which is how long the tap had run.
      expect(cut.at, closeTo(cut.ms!, 50));
      expect(steps.last.toJson(), {
        'door': 'psiphon',
        'kind': 'psiphon',
        'stage': 'dial',
        'result': 'fail',
        'reason': steps.last.reason?.wire,
        'ms': steps.last.ms,
        'at': steps.last.at,
      });
      expect(steps.last.at, greaterThanOrEqualTo(cut.at!));
      // The doors checked, then the ones the cut left, for lack of time.
      final rows = steps.take(steps.length - 2).toList();
      expect(rows, hasLength(doors.length));
      expect(
        [for (final s in rows) s.door],
        [for (final d in doors) ConnectTrace.doorKey(d)],
      );
      final left = rows.where((s) => s.result == TraceResult.skipped);
      expect(left, isNotEmpty);
      expect({for (final s in left) s.reason}, {TraceReason.budget});
      expect(lastTrace().outcome, TraceOutcome.allClosed);
    });

    test('before the shared links that follow the first own doors, the '
        'doors left get their step and the ones checked go out', () async {
      // Two own doors fit in the time before the shared links. The
      // allowance question after them runs past the deadline.
      final vpn = _FakeVpn({backupKey});
      final f = flow(
        vpn,
        checklist: ChecklistSettings(
          doors: DoorCheckSettings.oneAtATime,
          fallback: FallbackSettings(
            links: links.length,
            parallel: 1,
            after: probeTime + probeTime ~/ 4,
          ),
        ),
      );
      var asked = 0;

      await f.connect(
        doors,
        shared: () async {
          asked++;
          return links;
        },
        allowanceSpent: () async {
          await Future<void>.delayed(startAfter);
          return false;
        },
      );
      await until(() => reported.isNotEmpty);

      expect(probed, keys(doors.take(2)));
      expect(asked, 0, reason: 'no links asked for after the cut');
      expect(f.chosen, Server.psiphon);
      final steps = lastTrace().steps;
      expect(
        [for (final s in steps) s.result],
        [
          TraceResult.fail,
          TraceResult.fail,
          for (var i = 2; i < doors.length; i++) TraceResult.skipped,
          TraceResult.cut,
          TraceResult.ok,
        ],
      );
      expect(
        {
          for (final s in steps)
            if (s.result == TraceResult.skipped) s.reason,
        },
        {TraceReason.budget},
      );
      expect([for (final b in reported) ...b], hasLength(2));
    });

    test('the backup network fails: the tap ends at nothing open, and keeps '
        'searching, cut again on the next round', () async {
      final vpn = _FakeVpn({});
      final f = flow(
        vpn,
        checklist: const ChecklistSettings(
          doors: DoorCheckSettings.oneAtATime,
          retry: RetrySettings(after: [Duration(milliseconds: 50)]),
        ),
      );

      unawaited(f.connect(doors));
      await until(() => f.stage == ConnectStage.waiting);
      expect(f.waitingAfter, ConnectStage.nothingOpen);
      expect(vpn.backupDials, 1);
      expect(f.chosen, isNull);

      await until(() => vpn.backupDials == 2);
      f.cancel();

      expect(traces.started, hasLength(2));
      for (final t in traces.started) {
        expect(cutSteps(t), hasLength(1));
      }
      // Two rounds, each cut, check fewer doors than one whole search.
      expect(probed.length, lessThan(doors.length));
    });

    test('the allowance is still asked first, and a spent one ends the tap '
        'on it', () async {
      var asked = 0;
      final vpn = _FakeVpn({backupKey});
      final f = flow(vpn);

      await f.connect(
        doors,
        allowanceSpent: () async {
          asked++;
          return true;
        },
      );

      expect(asked, 1);
      expect(vpn.backupDials, 0);
      expect(f.stage, ConnectStage.idle);
      expect(lastTrace().outcome, TraceOutcome.allowance);
      expect(cutSteps(lastTrace()), hasLength(1));
    });

    test('nothing is written to the door memory, and the selection does not '
        'move', () async {
      final shared = <Server>[];
      final switched = <Server>[];
      final vpn = _FakeVpn({backupKey});
      final f = flow(vpn);

      // Links that answer at once: a search that went on past the cut
      // would check them, find them closed and write them down.
      for (final l in links) {
        probeTimes[l.pathKey] = Duration.zero;
      }

      await f.connect(
        doors,
        preferred: doors[4],
        shared: () async => links,
        onShared: shared.add,
        onSwitchedServer: switched.add,
      );
      await pumpEventQueue();

      expect(cutSteps(lastTrace()), hasLength(1));
      expect(probed.where(keys(links).contains), isEmpty);
      expect(f.chosen, Server.psiphon);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(PathMemory.storageKey), isNull);
      expect(shared, isEmpty);
      expect(switched, isEmpty);
    });

    test('the doors it checked go to the backend, as a search whose time '
        'ran out sends them', () async {
      final vpn = _FakeVpn({});
      final f = flow(vpn);

      await f.connect(doors);
      await until(() => reported.isNotEmpty);
      await pumpEventQueue();

      expect(cutSteps(lastTrace()), hasLength(1));
      expect(probed.length, lessThan(doors.length));
      final rows = [for (final b in reported) ...b];
      expect(rows, hasLength(probed.length));
      expect(rows.map((r) => r['ok']).toSet(), {false});
    });
  });

  group('as before', () {
    test('a stop after the deadline, while a dial runs, ends the tap on the '
        'stop', () async {
      final door = doors.first;
      openHere = {door.pathKey};
      final vpn = _FakeVpn({})..takes[door.pathKey] = startAfter * 3;
      final f = flow(
        vpn,
        checklist: const ChecklistSettings(
          doors: DoorCheckSettings.oneAtATime,
          retry: RetrySettings(after: [Duration(milliseconds: 10)]),
        ),
      );

      final tap = f.connect(doors);
      await Future<void>.delayed(startAfter + startAfter ~/ 2);
      expect(f.stage, ConnectStage.connecting);
      f.cancel();
      await tap;
      await Future<void>.delayed(startAfter * 3);

      expect(f.stage, ConnectStage.cancelled);
      expect(vpn.backupDials, 0);
      expect(probed, [door.pathKey]);
      // No outcome is a stop, as the trace reads it.
      expect(lastTrace().outcome, isNull);
      expect(cutSteps(lastTrace()), isEmpty);
    });

    test('a stop after the deadline, while a check runs, ends the tap on the '
        'stop', () async {
      for (final d in doors) {
        probeTimes[d.pathKey] = startAfter * 0.75;
      }
      final vpn = _FakeVpn({backupKey});
      final f = flow(vpn);

      final tap = f.connect(doors);
      await Future<void>.delayed(startAfter + startAfter ~/ 4);
      f.cancel();
      await tap;
      await Future<void>.delayed(startAfter * 2);

      expect(f.stage, ConnectStage.cancelled);
      expect(vpn.backupDials, 0);
      // No outcome is a stop, as the trace reads it.
      expect(lastTrace().outcome, isNull);
      expect(cutSteps(lastTrace()), isEmpty);
    });

    test(
      'the deadline of a stopped tap does not cut the tap after it',
      () async {
        // The first tap is still waiting for its shared links at its deadline,
        // stopped, while the next tap checks its doors.
        final later = Completer<List<Server>>();
        for (final d in doors) {
          probeTimes[d.pathKey] = Duration.zero;
        }
        final vpn = _FakeVpn({backupKey});
        final f = flow(vpn);
        var asked = false;
        final first = f.connect(
          doors,
          shared: () {
            asked = true;
            return later.future;
          },
        );
        await until(() => asked);
        f.cancel();

        // The next tap's own deadline comes after its whole search.
        settings = backup(after: const Duration(seconds: 5));
        probeTimes.clear();
        probed.clear();
        await f.connect(doors);
        later.complete(const []);
        await first;

        expect(probed, keys(doors));
        expect(traces.started, hasLength(2));
        expect(cutSteps(lastTrace()), isEmpty);
        expect(f.stage, ConnectStage.done);
        expect(vpn.backupDials, 1);
      },
    );

    test('a refused VPN permission on a dial in flight ends the tap as it '
        'did before', () async {
      final door = doors.first;
      openHere = {door.pathKey};
      final vpn = _FakeVpn({})
        ..refuse = {door.pathKey}
        ..takes[door.pathKey] = startAfter * 2;
      final f = flow(vpn);

      await f.connect(doors, shared: () async => links);

      expect(vpn.dialled, [door.pathKey]);
      expect(f.stage, ConnectStage.failed);
      expect(lastTrace().outcome, TraceOutcome.permission);
      expect(cutSteps(lastTrace()), isEmpty);
    });

    test(
      'a move to another network while it waits tries again at once',
      () async {
        final changes = StreamController<String>.broadcast();
        addTearDown(changes.close);
        final vpn = _FakeVpn({});
        final f = ConnectFlow(
          vpn: vpn,
          memory: PathMemory(),
          finder: PathFinder(
            read: (p) async {
              probed.add(p.pathKey);
              await Future<void>.delayed(probeTime);
              return closed;
            },
            internet: () async => true,
            budget: const Duration(seconds: 10),
          ),
          reporter: VpnEventReporter(
            send: (_, _, _) async {},
            sendProbes: (_, _, _) async {},
            queues: const [],
          ),
          ipv6: Ipv6Reach(route: () async => null),
          networkKey: () async => network,
          carrier: () async => null,
          checklist: () => const ChecklistSettings(
            doors: DoorCheckSettings.oneAtATime,
            retry: RetrySettings(
              after: [Duration(minutes: 1)],
              longest: Duration(minutes: 1),
            ),
          ),
          traces: traces,
          networkChanges: () => changes.stream,
          random: () => 0.5,
          networkSettle: const Duration(milliseconds: 10),
          attemptTimeout: const Duration(seconds: 2),
          psiphon: () => settings,
          psiphonDevice: () => device,
          android: () => android,
          tv: () => tv,
        );
        addTearDown(f.cancel);

        unawaited(f.connect(doors));
        await until(() => f.stage == ConnectStage.waiting);
        expect(vpn.backupDials, 1);
        await pumpEventQueue();

        changes.add('wifi');
        await until(() => vpn.backupDials == 2);
        expect(cutSteps(traces.started.last), hasLength(1));
      },
    );
  });
}
