import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/api/config_service.dart';
import 'package:fortiva_vpn/core/state/connect_flow.dart';
import 'package:fortiva_vpn/data/models/checklist_settings.dart';
import 'package:fortiva_vpn/data/models/psiphon_settings.dart';
import 'package:fortiva_vpn/data/models/server.dart';
import 'package:fortiva_vpn/services/ipv6_reach.dart';
import 'package:fortiva_vpn/services/path_finder.dart';
import 'package:fortiva_vpn/services/path_memory.dart';
import 'package:fortiva_vpn/services/vpn_event_reporter.dart';
import 'package:fortiva_vpn/services/vpn_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The stages of the search, as the flow reports them (clients #342).
///
/// A tap tries this device's own servers, then the shared links, then the
/// backup network. The screen draws each as a stage, so the flow says which
/// one it is on and how each stood. It says so itself, rather than the
/// screen guessing from the door it last dialled. Every address and
/// setting here is made up.
Server own(String host, String door, int row) => Server.fromDedicatedPath(
  uri:
      'vless://u@$host:8443?type=tcp&security=reality'
      '&sni=www.example.com&pbk=key#Row$row',
  door: door,
  doorLabel: door,
  serverId: row,
);

final hel1 = own('203.0.113.226', 'tcp-reality', 13);
final hel2 = own('203.0.113.226', 'xhttp-reality', 13);
final fsn1 = own('203.0.113.227', 'tcp-reality', 14);
final paths = [hel1, hel2, fsn1];

final link1 = Server.fromConnectionUri(
  'vless://u@h1.example:443?type=tcp&security=reality'
  '&sni=www.example.com&pbk=key#Link1',
);
final link2 = Server.fromConnectionUri(
  'vless://u@h2.example:443?type=tcp&security=reality'
  '&sni=www.example.com&pbk=key#Link2',
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
/// everything else. With [gate], every dial waits on it first.
class _FakeVpn extends VpnService {
  _FakeVpn(this.works)
    : super(
        events: VpnEventReporter(send: (_, _, _) async {}, queues: const []),
      );

  final Set<String> works;
  final dialled = <String>[];
  Completer<void>? gate;
  VpnStatus _fake = VpnStatus.disconnected;

  @override
  VpnStatus get status => _fake;

  @override
  bool get isConnected => _fake == VpnStatus.connected;

  @override
  bool get isConnecting => _fake == VpnStatus.connecting;

  @override
  bool get isVerifying => false;

  @override
  Future<void> connect(
    Server server, {
    String? attemptId,
    List<Server> standby = const [],
    LinkSource? source,
  }) async {
    dialled.add(server.pathKey);
    _fake = VpnStatus.connecting;
    notifyListeners();
    await gate?.future;
    await Future.delayed(const Duration(milliseconds: 2));
    _fake = works.contains(server.pathKey)
        ? VpnStatus.connected
        : VpnStatus.error;
    notifyListeners();
  }

  @override
  Future<void> disconnect() async {
    _fake = VpnStatus.disconnected;
    notifyListeners();
  }

  @override
  void clearError() {
    if (_fake == VpnStatus.error) _fake = VpnStatus.disconnected;
    notifyListeners();
  }
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

PsiphonSettings backup({int afterRounds = 0}) => PsiphonSettings(
  network: const {'SponsorId': '0123456789ABCDEF'},
  enabled: true,
  afterRounds: afterRounds,
  establishTimeout: const Duration(seconds: 1),
);

const fresh = QuotaStatus(
  unlimited: false,
  limitBytes: 100,
  usedBytes: 10,
  remainingBytes: 90,
  blocked: false,
);

/// A metered allowance with nothing left.
const spent = QuotaStatus(
  unlimited: false,
  limitBytes: 100,
  usedBytes: 100,
  remainingBytes: 0,
  blocked: false,
);

/// What the screen shows of a try's stages while one runs: the stage that
/// runs, how our servers and the community servers read, and the stage
/// number over the list.
typedef Shown = ({
  RouteKind route,
  StageState own,
  StageState links,
  int? reached,
});

/// One line of [Shown], for the expectations below.
Shown shown(RouteKind route, StageState own, StageState links, int reached) =>
    (route: route, own: own, links: links, reached: reached);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Set<String> openHere;
  late PsiphonSettings? settings;
  late bool android;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    openHere = {};
    settings = null;
    android = true;
  });

  /// A flow over [vpn]. Each door check takes [readDelay] when one is
  /// given, and [abroad] says whether the phone reaches a site abroad.
  ConnectFlow flow(
    _FakeVpn vpn, {
    ChecklistSettings? checklist,
    Duration? readDelay,
    Future<bool> Function()? abroad,
    PsiphonDevice device = const PsiphonDevice(
      allowed: true,
      quota: fresh,
      quotaFresh: true,
    ),
    Stream<String> Function()? networkChanges,
    Duration networkSettle = const Duration(milliseconds: 10),
    Duration budget = const Duration(milliseconds: 300),
    String Function()? networkNow,
  }) {
    final f = ConnectFlow(
      vpn: vpn,
      memory: PathMemory(),
      finder: PathFinder(
        read: (p) async {
          if (readDelay != null) await Future<void>.delayed(readDelay);
          return openHere.contains(p.pathKey) ? open : closed;
        },
        internet: abroad ?? () async => true,
        home: () async => true,
        budget: budget,
      ),
      reporter: VpnEventReporter(
        send: (_, _, _) async {},
        sendProbes: (_, _, _) async {},
        deviceId: () async => 'DEV-1',
        appVersion: () async => '2.2.0',
        platform: 'android',
        networkType: () async => 'mobile',
        queues: const [],
      ),
      ipv6: Ipv6Reach(route: () async => null),
      networkKey: () async => networkNow?.call() ?? network,
      carrier: () async => null,
      checklist: () => checklist,
      random: () => 0.5,
      networkSettle: networkSettle,
      networkChanges: networkChanges,
      attemptTimeout: const Duration(seconds: 2),
      psiphon: () => settings,
      psiphonDevice: () => device,
      android: () => android,
      tv: () => false,
    );
    addTearDown(f.cancel);
    return f;
  }

  /// Every kind of route [f] enters, in order, with a repeat only after
  /// another kind.
  List<RouteKind> watchRoutes(ConnectFlow f) {
    final seen = <RouteKind>[];
    f.addListener(() {
      final now = f.route;
      if (now != null && (seen.isEmpty || seen.last != now)) seen.add(now);
    });
    return seen;
  }

  /// What [f] shows of its stages each time that changes while it
  /// searches ([Shown]), and how many times it searched with no stage on.
  ({List<Shown> seen, int Function() bare}) watchStages(ConnectFlow f) {
    final seen = <Shown>[];
    var bare = 0;
    f.addListener(() {
      final now = f.route;
      if (now == null) {
        if (f.searchRunning) bare++;
        return;
      }
      final line = shown(
        now,
        f.stageState(RouteKind.own),
        f.stageState(RouteKind.community),
        f.stageProgress?.number ?? 0,
      );
      if (seen.isEmpty || seen.last != line) seen.add(line);
    });
    return (seen: seen, bare: () => bare);
  }

  const ours = RouteKind.own;
  const links = RouteKind.community;
  const running = StageState.running;
  const pending = StageState.pending;
  const failed = StageState.failed;

  // Found 2026-10-24 in review: the flow comes back to the own doors after
  // the shared links, and tries a pick before both. The stage number went
  // down, and the screen said our servers did not connect after one door
  // was checked, then tried them again.
  group('a stage that gets another turn', () {
    test('a shared link the user picked goes first: our servers read '
        'pending until their turn, and the number stays at the furthest '
        'stage', () async {
      openHere = {link2.pathKey};
      final vpn = _FakeVpn({link2.pathKey});
      final f = flow(vpn);
      final w = watchStages(f);

      await f.connect(paths, picked: link1, shared: () async => [link1, link2]);

      expect(f.stage, ConnectStage.done);
      expect(f.chosen, link2);
      expect(w.bare(), 0);
      expect(w.seen, [
        // The pick, with our servers still to come.
        shown(links, pending, running, 2),
        // Our servers, with the other shared links still to come.
        shown(ours, running, pending, 2),
        // The other shared links, once ours have had their turn.
        shown(links, failed, running, 2),
      ]);
    });

    test('with ownFirst, our doors and the pick are checked first, and '
        'our servers read pending while the pick is dialled', () async {
      openHere = {link1.pathKey};
      final vpn = _FakeVpn(const {});
      final f = flow(
        vpn,
        checklist: const ChecklistSettings(
          fallback: FallbackSettings(links: 2, parallel: 2, ownFirst: 1),
        ),
      );
      final w = watchStages(f);

      await f.connect(
        paths,
        picked: link1,
        ownFirst: true,
        shared: () async => [link1, link2],
      );

      expect(vpn.dialled.first, link1.pathKey);
      expect(f.stage, ConnectStage.nothingOpen);
      expect(w.bare(), 0);
      expect(w.seen, [
        shown(ours, running, pending, 1),
        shown(links, pending, running, 2),
        shown(ours, running, pending, 2),
        shown(links, failed, running, 2),
      ]);
      expect(f.stageState(RouteKind.own), StageState.failed);
      expect(f.stageState(RouteKind.community), StageState.failed);
    });

    test('with FallbackSettings.after, the own doors left after the shared '
        'links read pending while the links are checked', () async {
      final vpn = _FakeVpn(const {});
      final f = flow(
        vpn,
        readDelay: const Duration(milliseconds: 40),
        budget: const Duration(milliseconds: 600),
        checklist: const ChecklistSettings(
          fallback: FallbackSettings(
            links: 2,
            parallel: 2,
            after: Duration(milliseconds: 50),
          ),
          doors: DoorCheckSettings(parallel: 1, stagger: Duration.zero),
        ),
      );
      final w = watchStages(f);

      await f.connect([
        hel1,
        hel2,
        fsn1,
        own('203.0.113.228', 'tcp-reality', 15),
      ], shared: () async => [link1, link2]);

      expect(f.stage, ConnectStage.nothingOpen);
      expect(w.bare(), 0);
      expect(w.seen, [
        shown(ours, running, pending, 1),
        shown(links, pending, running, 2),
        shown(ours, running, failed, 2),
      ]);
    });

    test(
      'servers of its own that arrive while the pick is dialled get '
      'their turn, and the other shared links read pending meanwhile',
      () async {
        // The pick passes a check, where a check comes before its dial.
        openHere = {link1.pathKey, link2.pathKey};
        final vpn = _FakeVpn({link2.pathKey})..gate = Completer<void>();
        final f = flow(vpn);
        final w = watchStages(f);
        var arrived = false;

        final run = f.connectShared(
          link1,
          shared: () async => [link1, link2],
          own: () => arrived ? paths : const [],
        );
        await until(() => vpn.dialled.isNotEmpty);
        arrived = true;
        vpn.gate!.complete();
        await run;

        expect(f.chosen, link2);
        expect(w.bare(), 0);
        expect(w.seen, [
          shown(links, StageState.skipped, running, 2),
          shown(ours, running, pending, 2),
          shown(links, failed, running, 2),
        ]);
      },
    );

    test('the backup network is the last turn: a stage still waiting for one '
        'reads as it ended', () async {
      settings = backup();
      final vpn = _FakeVpn({backupKey});
      final f = flow(vpn);
      final linksOnBackup = <StageState>{};
      f.addListener(() {
        if (f.route == RouteKind.backup) {
          linksOnBackup.add(f.stageState(RouteKind.community));
        }
      });

      // The pick fails, our doors are closed, and no other shared link is
      // left to check.
      await f.connect(paths, picked: link1, shared: () async => [link1]);

      expect(f.chosen, Server.psiphon);
      expect(linksOnBackup, {failed});
    });

    test('a phone with no servers of its own starts on the pick, from the '
        'first notice', () async {
      final vpn = _FakeVpn(const {});
      final f = flow(vpn);
      final w = watchStages(f);

      await f.connectShared(
        link1,
        shared: () async => [link1, link2],
        own: () => const [],
      );

      expect(w.bare(), 0);
      expect(w.seen.first, shown(links, StageState.skipped, running, 2));
    });
  });

  group('the fast path', () {
    test('is the first stage of the search, from its first second, and '
        'names the door it dials', () async {
      await PathMemory().remember(network, hel2.pathKey);
      final vpn = _FakeVpn({hel2.pathKey})..gate = Completer<void>();
      final f = flow(vpn);

      final run = f.connect(paths);
      await until(() => vpn.dialled.isNotEmpty);

      expect(f.stage, ConnectStage.fastPath);
      expect(f.showStages, isTrue);
      expect(f.searchRunning, isTrue);
      expect(f.route, RouteKind.own);
      expect(f.stageState(RouteKind.own), StageState.running);
      expect(f.stageState(RouteKind.community), StageState.pending);
      expect(f.fastPathDoor, hel2);
      // No check ran on this try, so the last try's rows are not its own.
      expect(f.checksAreThisTry, isFalse);
      expect(f.searchStarted, isNotNull);
      // No backup network on this device: two stages on screen.
      expect(f.stageAvailable(RouteKind.backup), isFalse);
      expect(f.stageProgress, (number: 1, count: 2));

      vpn.gate!.complete();
      await run;

      expect(f.stage, ConnectStage.done);
      expect(f.stageState(RouteKind.own), StageState.connected);
      // Not needed, so not tried.
      expect(f.stageState(RouteKind.community), StageState.skipped);
      expect(f.fastPathDoor, isNull);
      expect(f.route, isNull);
      expect(f.searchStarted, isNull);
    });

    test(
      'its row is gone once its dial fails and the checklist starts',
      () async {
        await PathMemory().remember(network, hel1.pathKey);
        openHere = {fsn1.pathKey};
        final vpn = _FakeVpn({fsn1.pathKey});
        final f = flow(vpn);
        final whileChecked = <Server?>{};
        f.addListener(() {
          if (f.isDiagnosing) whileChecked.add(f.fastPathDoor);
        });

        await f.connect(paths);

        expect(vpn.dialled, [hel1.pathKey, fsn1.pathKey]);
        expect(whileChecked, {null});
      },
    );

    // The row names the server that worked last time. A door the checklist
    // found open is not that server, so its dial has no such row.
    test('names only its own dial: a checked door\'s dial has no fast-path '
        'door', () async {
      await PathMemory().remember(network, hel1.pathKey);
      openHere = {fsn1.pathKey};
      final vpn = _FakeVpn({fsn1.pathKey});
      final f = flow(vpn);
      final named = <ConnectStage, Set<Server?>>{};
      f.addListener(() {
        if (f.stage == ConnectStage.fastPath ||
            f.stage == ConnectStage.connecting) {
          (named[f.stage] ??= {}).add(f.fastPathDoor);
        }
      });

      await f.connect(paths);

      expect(vpn.dialled, [hel1.pathKey, fsn1.pathKey]);
      expect(f.stage, ConnectStage.done);
      expect(named[ConnectStage.fastPath], contains(hel1));
      expect(named[ConnectStage.connecting], {null});
    });

    test('a new try does not read the last try\'s closed rows as its own '
        'before its first check', () async {
      final vpn = _FakeVpn(const {});
      final f = flow(vpn);
      await f.connect(paths);
      expect(f.stage, ConnectStage.nothingOpen);
      expect(f.foundClosed(hel1), isTrue);

      await PathMemory().remember(network, hel1.pathKey);
      vpn.gate = Completer<void>();
      final run = f.connect(paths);
      await until(() => vpn.dialled.isNotEmpty);

      expect(f.stage, ConnectStage.fastPath);
      expect(f.checksAreThisTry, isFalse);
      expect(f.foundClosed(hel1), isFalse);
      expect(f.foundClosed(fsn1), isFalse);
      vpn.gate!.complete();
      await run;
    });

    test('a remembered door that fails leaves the stage running while '
        'its doors are checked', () async {
      await PathMemory().remember(network, hel1.pathKey);
      openHere = {fsn1.pathKey};
      final vpn = _FakeVpn({fsn1.pathKey});
      final f = flow(vpn);
      final routes = watchRoutes(f);

      await f.connect(paths);

      expect(vpn.dialled, [hel1.pathKey, fsn1.pathKey]);
      expect(routes, [RouteKind.own]);
      expect(f.stageState(RouteKind.own), StageState.connected);
      expect(f.checksAreThisTry, isTrue);
    });
  });

  group('the order of the stages', () {
    test('own doors closed: the community links are the second stage, and '
        'the screen can tell which servers this try found closed', () async {
      openHere = {link2.pathKey};
      final vpn = _FakeVpn({link2.pathKey});
      final f = flow(vpn);
      final routes = watchRoutes(f);
      StageState? ownWhileLinks;
      ({int number, int count})? progressWhileLinks;
      f.addListener(() {
        if (f.route == RouteKind.community) {
          ownWhileLinks = f.stageState(RouteKind.own);
          progressWhileLinks = f.stageProgress;
        }
      });

      await f.connect(paths, shared: () async => [link1, link2]);

      expect(routes, [RouteKind.own, RouteKind.community]);
      expect(ownWhileLinks, StageState.failed);
      expect(progressWhileLinks, (number: 2, count: 2));
      expect(f.stage, ConnectStage.done);
      expect(f.stageState(RouteKind.own), StageState.failed);
      expect(f.stageState(RouteKind.community), StageState.connected);
      // Every door of both servers read closed, and one link did.
      expect(f.foundClosed(hel1), isTrue);
      expect(f.foundClosed(fsn1), isTrue);
      expect(f.foundClosed(link1), isTrue);
      expect(f.foundClosed(link2), isFalse);
    });

    test('a server with one door found open is not found closed', () async {
      // Helsinki has a door open here, whose tunnel then fails.
      openHere = {hel2.pathKey};
      final vpn = _FakeVpn(const {});
      final f = flow(vpn);

      // Helsinki's open door is checked last.
      await f.connect([hel1, fsn1, hel2], shared: () async => const []);

      expect(vpn.dialled, contains(hel2.pathKey));
      expect(f.foundClosed(hel1), isFalse);
      expect(f.foundClosed(hel2), isFalse);
      expect(f.foundClosed(fsn1), isTrue);
    });

    test('the shared links are a stage while they are checked, even when '
        'none is open', () async {
      final vpn = _FakeVpn(const {});
      final f = flow(vpn);
      final routes = watchRoutes(f);
      final whileChecked = <PathCheckState>{};
      f.addListener(() {
        if (f.route != RouteKind.community) return;
        for (final c in f.checks) {
          if (!c.path.isDedicated) whileChecked.add(c.state);
        }
      });

      await f.connect(paths, shared: () async => [link1, link2]);

      expect(vpn.dialled, isEmpty);
      expect(routes, [RouteKind.own, RouteKind.community]);
      // The links' checks ran while the stage was on.
      expect(whileChecked, contains(PathCheckState.running));
      expect(f.stage, ConnectStage.nothingOpen);
      expect(f.stageState(RouteKind.community), StageState.failed);
    });

    test('the backup network is the third stage, and a stage passed over '
        'reads skipped', () async {
      settings = backup();
      final vpn = _FakeVpn({backupKey});
      final f = flow(vpn);
      final routes = watchRoutes(f);
      ({int number, int count})? progressOnBackup;
      StageState? linksOnBackup;
      bool? shownOnBackup;
      f.addListener(() {
        if (f.route == RouteKind.backup) {
          progressOnBackup = f.stageProgress;
          linksOnBackup = f.stageState(RouteKind.community);
          shownOnBackup = f.showStages;
        }
      });

      // No shared link to try.
      await f.connect(paths, shared: () async => const []);

      expect(routes, [RouteKind.own, RouteKind.backup]);
      expect(progressOnBackup, (number: 3, count: 3));
      expect(linksOnBackup, StageState.skipped);
      expect(shownOnBackup, isTrue);
      expect(f.stage, ConnectStage.done);
      expect(f.chosen, Server.psiphon);
      expect(f.stageState(RouteKind.own), StageState.failed);
      expect(f.stageState(RouteKind.community), StageState.skipped);
      expect(f.stageState(RouteKind.backup), StageState.connected);
    });

    test('the backup network is the stage on screen while the allowance is '
        'asked again, before its dial', () async {
      settings = backup();
      final vpn = _FakeVpn({backupKey})..gate = Completer<void>();
      final f = flow(vpn);
      // The search asks once when the own doors find nothing, and the
      // backup network asks again before its dial. The second answer waits.
      var asks = 0;
      final answer = Completer<bool>();
      Future<bool> ask() {
        asks++;
        return asks == 1 ? Future.value(false) : answer.future;
      }

      final run = f.connect(
        paths,
        shared: () async => const [],
        allowanceSpent: ask,
      );
      await until(() => f.tryingBackup);

      expect(f.route, RouteKind.backup);
      expect(f.stageState(RouteKind.backup), StageState.running);
      expect(f.stageState(RouteKind.own), StageState.failed);
      // Still asking: nothing dialled through it yet.
      if (asks > 1) expect(vpn.dialled, isEmpty);

      if (!answer.isCompleted) answer.complete(false);
      vpn.gate!.complete();
      await run;
      expect(f.stageState(RouteKind.backup), StageState.connected);
    });

    test('a search cut short for the backup network during the fast path '
        'keeps its stages on screen, with no rows', () async {
      settings = PsiphonSettings(
        network: const {'SponsorId': '0123456789ABCDEF'},
        enabled: true,
        startAfter: const Duration(milliseconds: 20),
        establishTimeout: const Duration(seconds: 1),
      );
      await PathMemory().remember(network, hel1.pathKey);
      final vpn = _FakeVpn({backupKey})..gate = Completer<void>();
      final f = flow(vpn);
      bool? shownOnBackup;
      bool? rowsOnBackup;
      f.addListener(() {
        if (f.route == RouteKind.backup) {
          shownOnBackup = f.showStages;
          rowsOnBackup = f.checksAreThisTry && f.checks.isNotEmpty;
        }
      });

      final run = f.connect(paths);
      await until(() => vpn.dialled.isNotEmpty);
      // Past the backend's time, with the remembered door still dialling.
      await Future<void>.delayed(const Duration(milliseconds: 60));
      vpn.gate!.complete();
      await run;

      expect(vpn.dialled, [hel1.pathKey, backupKey]);
      expect(rowsOnBackup, isFalse);
      expect(shownOnBackup, isTrue);
      expect(f.stageState(RouteKind.backup), StageState.connected);
    });

    test(
      'a backup network that fails reads failed once the try ends',
      () async {
        settings = backup();
        final vpn = _FakeVpn(const {});
        final f = flow(vpn);

        await f.connect(paths);

        expect(vpn.dialled, [backupKey]);
        expect(f.stage, ConnectStage.nothingOpen);
        expect(f.stageState(RouteKind.own), StageState.failed);
        expect(f.stageState(RouteKind.backup), StageState.failed);
        expect(f.route, isNull);
      },
    );

    test('on a round the backend leaves out, the backup network reads '
        'skipped from the start', () async {
      settings = backup(afterRounds: 1);
      final vpn = _FakeVpn(const {})..gate = Completer<void>();
      await PathMemory().remember(network, hel1.pathKey);
      final f = flow(vpn);

      final run = f.connect(paths);
      await until(() => vpn.dialled.isNotEmpty);
      expect(f.stageAvailable(RouteKind.backup), isTrue);
      expect(f.stageState(RouteKind.backup), StageState.skipped);
      expect(f.stageState(RouteKind.community), StageState.pending);
      vpn.gate!.complete();
      await run;
      expect(vpn.dialled, isNot(contains(backupKey)));
    });

    test('a backup network the try did not dial reads skipped, not '
        'failed', () async {
      settings = backup();
      final vpn = _FakeVpn(const {});
      // Nothing left on the allowance as the phone last heard it, and no
      // question to ask: the backup network is not dialled.
      final f = flow(
        vpn,
        device: const PsiphonDevice(allowed: true, quota: spent),
      );
      var entered = false;
      f.addListener(() => entered |= f.route == RouteKind.backup);

      await f.connect(paths);

      expect(entered, isTrue);
      expect(vpn.dialled, isEmpty);
      expect(f.stage, ConnectStage.nothingOpen);
      expect(f.stageState(RouteKind.backup), StageState.skipped);
      expect(f.stageState(RouteKind.own), StageState.failed);
    });

    test('a backup network whose settings came during the try is on screen '
        'while it runs', () async {
      final vpn = _FakeVpn({backupKey});
      final f = flow(vpn);
      bool? onScreen;
      ({int number, int count})? progress;
      f.addListener(() {
        if (f.route == RouteKind.backup) {
          onScreen = f.stageAvailable(RouteKind.backup);
          progress = f.stageProgress;
        }
      });

      // No settings when the try starts. They come while the shared links
      // are asked for.
      await f.connect(
        paths,
        shared: () async {
          settings = backup();
          return const [];
        },
      );

      expect(f.chosen, Server.psiphon);
      expect(onScreen, isTrue);
      expect(progress, (number: 3, count: 3));
    });

    test('where the backup network never runs, its stage is not on the '
        'screen', () async {
      settings = backup();
      android = false;
      final vpn = _FakeVpn(const {});
      final f = flow(vpn);
      ({int number, int count})? progress;
      f.addListener(() => progress ??= f.stageProgress);

      await f.connect(paths);

      expect(f.stageAvailable(RouteKind.backup), isFalse);
      expect(progress, (number: 1, count: 2));
    });

    test('a phone with no servers of its own skips the first stage and '
        'starts on the shared links', () async {
      openHere = {link2.pathKey};
      final vpn = _FakeVpn({link2.pathKey});
      final f = flow(vpn);
      final routes = watchRoutes(f);
      StageState? ownWhileLinks;
      f.addListener(() {
        if (f.route == RouteKind.community) {
          ownWhileLinks = f.stageState(RouteKind.own);
        }
      });

      await f.connectShared(
        link1,
        shared: () async => [link1, link2],
        own: () => const [],
      );

      expect(routes, [RouteKind.community]);
      expect(ownWhileLinks, StageState.skipped);
      expect(f.stageState(RouteKind.own), StageState.skipped);
      expect(f.stageState(RouteKind.community), StageState.connected);
    });
  });

  group('between tries', () {
    test(
      'the wait says which stage the next try starts with, and when',
      () async {
        final vpn = _FakeVpn(const {});
        final f = flow(
          vpn,
          checklist: const ChecklistSettings(
            retry: RetrySettings(after: [Duration(seconds: 30)]),
          ),
        );

        final before = DateTime.now();
        await f.connect(paths);

        expect(f.stage, ConnectStage.waiting);
        expect(f.searchRunning, isFalse);
        expect(f.route, isNull);
        expect(f.nextTryFrom, RouteKind.own);
        final at = f.retryAt!;
        expect(at.isAfter(before.add(const Duration(seconds: 29))), isTrue);
        expect(
          at.isBefore(DateTime.now().add(const Duration(seconds: 31))),
          isTrue,
        );
        // The last try's stages stay on screen, finished.
        expect(f.stageState(RouteKind.own), StageState.failed);
        expect(f.stageState(RouteKind.community), StageState.skipped);
        expect(f.showStages, isTrue);
      },
    );

    test('after a try of all three stages, the next starts with our servers '
        'again', () async {
      settings = backup();
      final vpn = _FakeVpn(const {});
      final f = flow(
        vpn,
        checklist: const ChecklistSettings(
          retry: RetrySettings(after: [Duration(seconds: 30)]),
        ),
      );
      final routes = watchRoutes(f);

      await f.connect(paths, shared: () async => [link1, link2]);

      expect(routes, [RouteKind.own, RouteKind.community, RouteKind.backup]);
      expect(f.stage, ConnectStage.waiting);
      expect(f.nextTryFrom, RouteKind.own);
    });

    test('after a try that started on a pick, the next starts on the pick '
        'again', () async {
      final vpn = _FakeVpn(const {});
      final f = flow(
        vpn,
        checklist: const ChecklistSettings(
          retry: RetrySettings(after: [Duration(seconds: 30)]),
        ),
      );

      await f.connect(paths, picked: link1, shared: () async => [link2]);

      expect(f.stage, ConnectStage.waiting);
      expect(f.nextTryFrom, RouteKind.community);
    });

    test('once the wait is over, the next try reads as starting while it '
        'is made ready, not as a countdown at zero', () async {
      final vpn = _FakeVpn(const {});
      final f = flow(
        vpn,
        checklist: const ChecklistSettings(
          retry: RetrySettings(after: [Duration(milliseconds: 50)]),
        ),
      );
      final ready = Completer<void>();

      await f.connect(paths, beforeRetry: () => ready.future);
      expect(f.stage, ConnectStage.waiting);
      expect(f.nextTryStarting, isFalse);
      expect(f.retryAt, isNotNull);

      await until(() => f.nextTryStarting);
      expect(f.stage, ConnectStage.waiting);
      expect(f.retryAt, isNull);
      expect(f.nextTryFrom, RouteKind.own);

      f.cancel();
      ready.complete();
      expect(f.nextTryStarting, isFalse);
    });

    test('the wait after that try counts down again', () async {
      final vpn = _FakeVpn(const {});
      final f = flow(
        vpn,
        checklist: const ChecklistSettings(
          retry: RetrySettings(
            after: [Duration(milliseconds: 30), Duration(seconds: 30)],
          ),
        ),
      );
      // Each time the flow starts to wait.
      var waits = 0;
      var last = f.stage;
      f.addListener(() {
        if (f.stage == ConnectStage.waiting && last != ConnectStage.waiting) {
          waits++;
        }
        last = f.stage;
      });

      await f.connect(paths, beforeRetry: () async {});
      await until(() => waits == 2);

      expect(f.stage, ConnectStage.waiting);
      expect(f.nextTryStarting, isFalse);
      expect(
        f.retryAt!.isAfter(DateTime.now().add(const Duration(seconds: 20))),
        isTrue,
      );
    });

    test(
      'a change of network moves the countdown to the try it brings',
      () async {
        final changes = StreamController<String>.broadcast();
        addTearDown(changes.close);
        final vpn = _FakeVpn(const {});
        final f = flow(
          vpn,
          checklist: const ChecklistSettings(
            retry: RetrySettings(after: [Duration(minutes: 1)]),
          ),
          networkChanges: () => changes.stream,
          networkSettle: const Duration(seconds: 5),
        );

        await f.connect(paths);
        expect(f.stage, ConnectStage.waiting);
        expect(
          f.retryAt!.isAfter(DateTime.now().add(const Duration(seconds: 50))),
          isTrue,
        );
        // The watch reads the network the phone is on first.
        await pumpEventQueue();
        var told = 0;
        f.addListener(() => told++);

        changes.add('wifi');
        await until(() => told > 0);

        final at = f.retryAt!;
        expect(
          at.isBefore(DateTime.now().add(const Duration(seconds: 6))),
          isTrue,
        );
        expect(
          at.isAfter(DateTime.now().add(const Duration(seconds: 4))),
          isTrue,
        );
        f.cancel();
      },
    );

    test('a timed try skipped while the phone has no network moves the '
        'countdown to the try after it', () async {
      var now = network;
      final vpn = _FakeVpn(const {});
      final f = flow(
        vpn,
        networkNow: () => now,
        checklist: const ChecklistSettings(
          retry: RetrySettings(
            after: [Duration(milliseconds: 40), Duration(seconds: 30)],
            longest: Duration(minutes: 5),
          ),
        ),
      );

      await f.connect(paths);
      expect(f.stage, ConnectStage.waiting);
      now = 'none';

      // The first wait ends with no network, so its try is skipped, and the
      // next one is the second wait away.
      await until(
        () =>
            f.retryAt?.isAfter(
              DateTime.now().add(const Duration(seconds: 20)),
            ) ??
            false,
      );
      expect(f.stage, ConnectStage.waiting);
      expect(f.nextTryStarting, isFalse);
      f.cancel();
    });

    test('a way abroad that comes back during the wait starts the next try '
        'at once, and the screen says so', () async {
      var reaches = false;
      final vpn = _FakeVpn(const {});
      final f = flow(
        vpn,
        abroad: () async => reaches,
        checklist: const ChecklistSettings(
          retry: RetrySettings(
            after: [Duration(minutes: 1)],
            recheck: Duration(milliseconds: 20),
          ),
        ),
      );
      final ready = Completer<void>();

      await f.connect(paths, beforeRetry: () => ready.future);
      expect(f.stage, ConnectStage.waiting);
      expect(f.nextTryStarting, isFalse);

      reaches = true;
      await until(() => f.nextTryStarting);
      expect(f.retryAt, isNull);

      f.cancel();
      ready.complete();
    });

    test('a stop ends the stages at once', () async {
      final gate = Completer<DoorOutcome>();
      final vpn = _FakeVpn(const {});
      final f = ConnectFlow(
        vpn: vpn,
        memory: PathMemory(),
        finder: PathFinder(
          read: (p) => gate.future,
          internet: () async => true,
          home: () async => true,
        ),
        reporter: VpnEventReporter(
          send: (_, _, _) async {},
          sendProbes: (_, _, _) async {},
          deviceId: () async => 'DEV-1',
          appVersion: () async => '2.2.0',
          platform: 'android',
          networkType: () async => 'mobile',
          queues: const [],
        ),
        networkKey: () async => network,
        carrier: () async => null,
      );

      final run = f.connect(paths);
      await until(() => f.isDiagnosing);
      expect(f.route, RouteKind.own);
      expect(f.checksAreThisTry, isTrue);

      f.cancel();
      expect(f.route, isNull);
      expect(f.searchRunning, isFalse);
      expect(f.searchStarted, isNull);
      expect(f.fastPathDoor, isNull);
      gate.complete(closed);
      await run;
      expect(f.stage, ConnectStage.cancelled);
    });
  });
}
