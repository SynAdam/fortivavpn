import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/core/state/connect_flow.dart';
import 'package:fortiva_vpn/data/models/checklist_settings.dart';
import 'package:fortiva_vpn/data/models/server.dart';
import 'package:fortiva_vpn/services/community_checks.dart';
import 'package:fortiva_vpn/services/ipv6_reach.dart';
import 'package:fortiva_vpn/services/path_finder.dart';
import 'package:fortiva_vpn/services/path_memory.dart';
import 'package:fortiva_vpn/services/vpn_event_reporter.dart';
import 'package:fortiva_vpn/services/vpn_service.dart';
import 'package:fortiva_vpn/utils/standby_doors.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Four changes to the fallback through community links, from the
/// research of 2026-10-10:
///
/// 1. The shared links are checked once the own doors have had a head
///    start, not after all of them (FallbackSettings.after).
/// 2. The core holds spare community links next to the one it dials
///    (FallbackSettings.standby).
/// 3. The tap after a fallback looks at our own doors beside the link the
///    fallback chose (FallbackSettings.ownFirst).
/// 4. A tap that found nothing open tries again by itself (RetrySettings).
///
/// Each is off without its number from the backend.
Server own(int i) => Server.fromDedicatedPath(
  uri:
      'vless://u@192.0.2.$i:8443?type=xhttp&security=reality'
      '&sni=www.samsung.com&pbk=key#Row13',
  door: 'door-$i',
  doorLabel: 'door-$i',
  serverId: 13,
);

/// Ten doors of the device's own server, in the backend's order.
final doors = [for (var i = 0; i < 10; i++) own(i)];

/// Ten community links, in the order the backend sent them.
final community = [
  for (var i = 0; i < 10; i++)
    Server.fromConnectionUri(
      'vless://u@h$i.example:443?type=tcp&security=reality'
      '&sni=www.samsung.com&pbk=key#Link$i',
      index: i,
    ),
];

/// A tunnel that comes up through the links in [works], and fails through
/// everything else. [active] stands in for the door the core is on.
class _FakeVpn extends VpnService {
  _FakeVpn(this.works)
    : super(events: VpnEventReporter(send: (_, _, _) async {}));

  final Set<String> works;
  final dialled = <String>[];
  final standbys = <List<Server>>[];
  Server? active;
  VpnStatus _fakeStatus = VpnStatus.disconnected;

  @override
  VpnStatus get status => _fakeStatus;

  @override
  bool get isConnected => _fakeStatus == VpnStatus.connected;

  @override
  bool get isConnecting => _fakeStatus == VpnStatus.connecting;

  @override
  bool get isVerifying => false;

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
    standbys.add(standby);
    active = server;
    _fakeStatus = VpnStatus.connecting;
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 5));
    _fakeStatus = works.contains(server.pathKey)
        ? VpnStatus.connected
        : VpnStatus.error;
    notifyListeners();
  }

  /// The core moving to [door] in the middle of a session.
  void moveTo(Server door) {
    active = door;
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
}

class _Kept extends CommunityChecks {
  _Kept() : super(platform: 'android');

  final kept = <CommunityCheck>[];

  @override
  Future<void> report(List<CommunityCheck> checks, {String? carrier}) async {
    kept.addAll(checks);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<String> probed;
  late Set<String> openHere;
  late List<Map<String, dynamic>> doorReports;
  late PathMemory memory;
  // A check of a link in here ends only once its future does, and a moment
  // after that: a test that needs one check to end before another says so.
  late Map<String, Future<void>> after;
  // Completed when the check of the link it is under ends.
  late Map<String, Completer<void>> checked;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    probed = [];
    openHere = {};
    doorReports = [];
    memory = PathMemory();
    after = {};
    checked = {};
  });

  tearDown(() {
    StandbyDoors.enabled = false;
    StandbyDoors.androidOverride = null;
  });

  ConnectFlow flow(_FakeVpn vpn, ChecklistSettings? checklist) => ConnectFlow(
    vpn: vpn,
    memory: memory,
    finder: PathFinder(
      probe: (p) async {
        probed.add(p.pathKey);
        final open = openHere.contains(p.pathKey);
        await Future.delayed(Duration(milliseconds: open ? 1 : 10));
        final wait = after[p.pathKey];
        if (wait != null) {
          await wait;
          // After the other check's result is in its row.
          await Future.delayed(const Duration(milliseconds: 1));
        }
        checked[p.pathKey]?.complete();
        return open ? 120 : -1;
      },
      internet: () async => true,
    ),
    reporter: VpnEventReporter(
      send: (_, _, _) async {},
      sendProbes: (_, probes, _) async => doorReports.addAll(probes),
      deviceId: () async => 'DEV-1',
      appVersion: () async => '1.6.22',
      platform: 'android',
      networkType: () async => 'mobile',
    ),
    ipv6: Ipv6Reach(route: () async => false),
    networkKey: () async => 'mobile',
    carrier: () async => null,
    communityChecks: _Kept(),
    checklist: () => checklist,
    attemptTimeout: const Duration(seconds: 2),
  );

  ChecklistSettings settings({
    Duration? after,
    int? standby,
    int? ownFirst,
    List<int>? retry,
  }) => ChecklistSettings(
    fallback: FallbackSettings(
      links: 8,
      parallel: 4,
      after: after,
      standby: standby,
      ownFirst: ownFirst,
    ),
    retry: retry == null
        ? null
        : RetrySettings(
            after: [for (final ms in retry) Duration(milliseconds: ms)],
          ),
  );

  List<String> keys(Iterable<Server> servers) => [
    for (final s in servers) s.pathKey,
  ];

  group('1. the shared links after a head start', () {
    test('a community link carries the tunnel before the own doors at the '
        'end of the list are checked', () async {
      openHere = {community[1].pathKey};
      final vpn = _FakeVpn({community[1].pathKey});
      final f = flow(vpn, settings(after: const Duration(milliseconds: 35)));

      await f.connect(
        doors,
        preferred: doors.first,
        shared: () async => community,
      );
      await pumpEventQueue();

      expect(f.stage, ConnectStage.done);
      expect(f.chosen, community[1]);
      final firstShared = probed.indexOf(community.first.pathKey);
      expect(firstShared, greaterThan(0));
      expect(firstShared, lessThan(doors.length));
      // The last own door was never reached.
      expect(probed, isNot(contains(doors.last.pathKey)));
      // A search cut short is not reported as one that found every door
      // closed.
      expect(doorReports, isEmpty);
    });

    test('when no shared link is open, the own doors not reached are checked '
        'after them, and one of them carries the tunnel', () async {
      openHere = {doors[9].pathKey};
      final vpn = _FakeVpn({doors[9].pathKey});
      final f = flow(vpn, settings(after: const Duration(milliseconds: 35)));
      // The stages on screen (clients #342): our servers again after the
      // shared links.
      final routes = <RouteKind>[];
      // The stage while an own door is checked after the shared links.
      final checkingOwnAfterLinks = <RouteKind?>{};
      // How our servers read while the links are checked: still to come.
      final ownWhileLinks = <StageState>{};
      // The stage number over the list, which never goes down.
      final reached = <int>[];
      f.addListener(() {
        final now = f.route;
        if (now != null && (routes.isEmpty || routes.last != now)) {
          routes.add(now);
        }
        if (now == RouteKind.community) {
          ownWhileLinks.add(f.stageState(RouteKind.own));
        }
        final n = f.stageProgress?.number;
        if (n != null && (reached.isEmpty || reached.last != n)) reached.add(n);
        final rows = f.checks;
        if (rows.any((c) => !c.path.isDedicated) &&
            rows.any(
              (c) => c.path.isDedicated && c.state == PathCheckState.running,
            )) {
          checkingOwnAfterLinks.add(now);
        }
      });

      await f.connect(
        doors,
        preferred: doors.first,
        shared: () async => community,
      );
      await pumpEventQueue();

      expect(f.stage, ConnectStage.done);
      expect(f.chosen, doors[9]);
      expect(routes, [RouteKind.own, RouteKind.community, RouteKind.own]);
      expect(checkingOwnAfterLinks, {RouteKind.own});
      expect(ownWhileLinks, {StageState.pending});
      expect(reached, [1, 2]);
      expect(f.stageState(RouteKind.own), StageState.connected);
      expect(f.stageState(RouteKind.community), StageState.failed);
      final firstShared = probed.indexOf(community.first.pathKey);
      final lastOwn = probed.indexOf(doors[9].pathKey);
      expect(firstShared, greaterThan(0));
      expect(lastOwn, greaterThan(firstShared));
      // The shared links were checked once, not again before the dial.
      expect(probed.where((k) => k == community.first.pathKey), hasLength(1));
      // The whole search is reported, every own door once.
      expect(doorReports.map((r) => r['door']).toSet(), hasLength(10));
    });

    test('nothing open anywhere ends at nothing open, with each shared link '
        'checked once', () async {
      final f = flow(
        _FakeVpn({}),
        settings(after: const Duration(milliseconds: 35)),
      );

      await f.connect(
        doors,
        preferred: doors.first,
        shared: () async => community,
      );
      await pumpEventQueue();

      expect(f.stage, ConnectStage.nothingOpen);
      for (final link in community.take(8)) {
        expect(probed.where((k) => k == link.pathKey), hasLength(1));
      }
    });

    test('without the number, every own door is checked first', () async {
      final f = flow(_FakeVpn({}), settings());

      await f.connect(
        doors,
        preferred: doors.first,
        shared: () async => community,
      );
      await pumpEventQueue();

      expect(probed.take(10).toList(), keys(doors));
    });
  });

  group('2. spare community links', () {
    setUp(() {
      StandbyDoors.enabled = true;
      StandbyDoors.androidOverride = true;
    });

    test(
      'the core holds the other open links, then the ones not reached',
      () async {
        openHere = {community[1].pathKey, community[2].pathKey};
        // The race returns once community[0] reads closed, without waiting
        // for the checks still running. community[3]'s ends first, so it
        // reads closed and is no spare. Both took 10 ms, and which ended
        // first changed from run to run.
        final third = checked[community[3].pathKey] = Completer<void>();
        after[community[0].pathKey] = third.future;
        final vpn = _FakeVpn({community[1].pathKey});
        final f = flow(vpn, settings(standby: 3));

        await f.connect([doors.first], shared: () async => community);
        await pumpEventQueue();

        expect(f.chosen, community[1]);
        expect(vpn.standbys.last, [community[2], community[4], community[5]]);
      },
    );

    test('a move to a spare moves the selection, and is remembered as a '
        'shared link, never as an own door', () async {
      openHere = {community[1].pathKey, community[2].pathKey};
      final vpn = _FakeVpn({community[1].pathKey});
      final selected = <Server>[];
      final f = flow(vpn, settings(standby: 3));
      await f.connect(
        [doors.first],
        shared: () async => community,
        onShared: selected.add,
      );
      await pumpEventQueue();

      vpn.moveTo(community[2]);
      await pumpEventQueue();

      expect(selected, [community[1], community[2]]);
      expect(f.chosen, community[2]);
      expect(await memory.recallShared('mobile'), community[2].pathKey);
      expect(await memory.recall('mobile'), isNull);
    });

    test('without the number, none', () async {
      openHere = {community[1].pathKey, community[2].pathKey};
      final vpn = _FakeVpn({community[1].pathKey});
      final f = flow(vpn, settings());

      await f.connect([doors.first], shared: () async => community);
      await pumpEventQueue();

      expect(vpn.standbys.last, isEmpty);
    });
  });

  group('3. our own doors first, after a fallback chose the link', () {
    final chosen = community[5];

    test('an own door found open is dialled instead of the link', () async {
      openHere = {doors.first.pathKey, chosen.pathKey};
      final vpn = _FakeVpn({doors.first.pathKey, chosen.pathKey});
      final f = flow(vpn, settings(ownFirst: 1));

      await f.connect(
        doors,
        picked: chosen,
        ownFirst: true,
        shared: () async => community,
      );
      await pumpEventQueue();

      expect(f.stage, ConnectStage.done);
      expect(f.chosen, doors.first);
      expect(vpn.dialled, [doors.first.pathKey]);
      // Both were checked at once.
      expect(probed, [doors.first.pathKey, chosen.pathKey]);
    });

    test('the door that last worked here is the one checked', () async {
      await memory.remember('mobile', doors[3].pathKey);
      openHere = {chosen.pathKey};
      final vpn = _FakeVpn({chosen.pathKey});
      final f = flow(vpn, settings(ownFirst: 1));

      await f.connect(
        doors,
        picked: chosen,
        ownFirst: true,
        shared: () async => community,
      );
      await pumpEventQueue();

      expect(probed, [doors[3].pathKey, chosen.pathKey]);
      expect(vpn.dialled, [chosen.pathKey]);
      expect(f.chosen, chosen);
    });

    test('with both closed, the link is not dialled and the checklist '
        'carries on', () async {
      final vpn = _FakeVpn({});
      final f = flow(vpn, settings(ownFirst: 1));

      await f.connect(
        doors,
        picked: chosen,
        ownFirst: true,
        shared: () async => community,
      );
      await pumpEventQueue();

      expect(vpn.dialled, isNot(contains(chosen.pathKey)));
      // The own door found closed is not dialled on the fast path either.
      expect(vpn.dialled, isNot(contains(doors.first.pathKey)));
      expect(f.stage, ConnectStage.nothingOpen);
    });

    test('an own door whose tunnel failed beside the link is checked again '
        'only after the other own doors', () async {
      // doors[0] passes its check and carries nothing. The link is closed,
      // so it is not dialled.
      openHere = {doors[0].pathKey, doors[2].pathKey};
      final vpn = _FakeVpn({doors[2].pathKey});
      final f = flow(vpn, settings(ownFirst: 1));

      await f.connect(
        doors,
        picked: chosen,
        ownFirst: true,
        shared: () async => community,
      );
      await pumpEventQueue();

      expect(f.stage, ConnectStage.done);
      expect(f.chosen, doors[2]);
      // Up to 1.7.0, doors[0] was checked first again, passed, and was
      // dialled a second time. The tap then ended failed, with doors[1] and
      // doors[2] never checked.
      expect(vpn.dialled, [doors[0].pathKey, doors[2].pathKey]);
      expect(probed.take(4), keys([doors[0], chosen, doors[1], doors[2]]));
      expect(probed.where((k) => k == doors[0].pathKey), hasLength(1));
    });

    test('an own door found closed beside the link is checked again only '
        'after the other own doors', () async {
      // Up to 1.7.0, doors[0] was checked a second time first.
      openHere = {doors[1].pathKey};
      final vpn = _FakeVpn({doors[1].pathKey});
      final f = flow(vpn, settings(ownFirst: 1));

      await f.connect(
        doors,
        picked: chosen,
        ownFirst: true,
        shared: () async => community,
      );
      await pumpEventQueue();

      expect(f.stage, ConnectStage.done);
      expect(f.chosen, doors[1]);
      expect(vpn.dialled, [doors[1].pathKey]);
      expect(probed, keys([doors[0], chosen, doors[1]]));
    });

    test('a link the user picked is dialled first, as before, after a check '
        'of it alone', () async {
      openHere = {doors.first.pathKey, chosen.pathKey};
      final vpn = _FakeVpn({doors.first.pathKey, chosen.pathKey});
      final f = flow(vpn, settings(ownFirst: 1));

      await f.connect(doors, picked: chosen, shared: () async => community);
      await pumpEventQueue();

      expect(vpn.dialled, [chosen.pathKey]);
      // No door of ours beside it.
      expect(probed, [chosen.pathKey]);
    });

    test('without the number, the link is checked alone and dialled '
        'first', () async {
      openHere = {chosen.pathKey};
      final vpn = _FakeVpn({chosen.pathKey});
      final f = flow(vpn, settings());

      await f.connect(
        doors,
        picked: chosen,
        ownFirst: true,
        shared: () async => community,
      );
      await pumpEventQueue();

      expect(vpn.dialled, [chosen.pathKey]);
      expect(probed, [chosen.pathKey]);
    });
  });

  group('4. trying again after nothing was open', () {
    Future<void> settle() =>
        Future<void>.delayed(const Duration(milliseconds: 400));

    test('waits, then tries again with a new list, as many times as the '
        'backend says', () async {
      var refreshes = 0;
      final f = flow(_FakeVpn({}), settings(retry: [20, 20]));

      await f.connect(
        [doors.first],
        shared: () async => community.take(2).toList(),
        beforeRetry: () async => refreshes++,
      );
      expect(f.stage, ConnectStage.waiting);
      expect(f.isBusy, isTrue);

      await settle();

      expect(refreshes, 2);
      expect(probed.where((k) => k == doors.first.pathKey), hasLength(3));
      expect(f.stage, ConnectStage.nothingOpen);
    });

    test('a try that finds a link open connects and tries no more', () async {
      final vpn = _FakeVpn({community[0].pathKey});
      final f = flow(vpn, settings(retry: [20, 20, 20]));

      await f.connect(
        [doors.first],
        shared: () async => community.take(2).toList(),
        beforeRetry: () async => openHere = {community[0].pathKey},
      );
      await settle();

      expect(f.stage, ConnectStage.done);
      expect(f.chosen, community[0]);
      expect(probed.where((k) => k == doors.first.pathKey), hasLength(2));
    });

    test('a tap on the button while it waits stops it', () async {
      final f = flow(_FakeVpn({}), settings(retry: [30, 30]));

      await f.connect([
        doors.first,
      ], shared: () async => community.take(2).toList());
      expect(f.stage, ConnectStage.waiting);
      f.cancel();
      final before = probed.length;
      await settle();

      expect(f.stage, ConnectStage.cancelled);
      expect(probed, hasLength(before));
    });

    test('without the waits, the tap ends at nothing open', () async {
      final f = flow(_FakeVpn({}), settings());

      await f.connect([
        doors.first,
      ], shared: () async => community.take(2).toList());
      await settle();

      expect(f.stage, ConnectStage.nothingOpen);
      expect(probed.where((k) => k == doors.first.pathKey), hasLength(1));
    });
  });
}
