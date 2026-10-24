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
import 'package:shared_preferences/shared_preferences.dart';

/// The control fetch beside the door checks, since 1.7.1.
///
/// Until then a tap made the control fetch (plain HTTP to Google and
/// Cloudflare) before any door check, and a failed fetch ended the tap at
/// "no internet" with no door checked. In the 24 hours to 01:00 Tehran on
/// 2026-10-12 that was 30 first taps a day. The fetch fails on phones that
/// have internet: 19 of their 30 traces reached the backend within 2
/// minutes, and Android called the network validated in 25 of 34 of their
/// diagnoses.
///
/// The fetch now runs beside the checks, and a door found open is dialled.
/// When none is, the shared links are checked, and the tap ends at "no
/// internet" only when none of them is open either. The rows of a check
/// that found nothing open are not sent from a tap whose fetch failed, the
/// rule DoorSweep.run follows, nothing is learnt about IPv6 from it, and
/// no link it found closed is written down. The rows of a check that found
/// a door or link open go out at once, whatever the fetch says: no phone
/// without internet finds one open, and since 2026-10-12 they no longer
/// wait for the fetch, so they are queued before the tunnel is up.
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

/// Dialled at an IPv6 address. On a phone with no network at all, or on a
/// network with no IPv6, its check says "tcp unreachable".
final v6 = own('[2001:db8:f20::1]', 'xhttp-reality-v6', 13);
final fsn1 = own('203.0.113.227', 'tcp-reality', 14);

/// The device's doors, in the backend's order.
final paths = [hel1, hel2, v6, fsn1];

/// A link from a public channel, for the fallback.
final community = Server.fromConnectionUri(
  'vless://u@h1.example:443?type=tcp&security=reality'
  '&sni=www.samsung.com&pbk=key#Link1',
);

const open = DoorOutcome(ms: 120, tcpMs: 40, phase: 'ok');

/// A tunnel that comes up through the links in [works], and fails through
/// everything else.
class _FakeVpn extends VpnService {
  _FakeVpn(this.works)
    : super(events: VpnEventReporter(send: (_, _, _) async {}));

  final Set<String> works;
  final dialled = <String>[];
  Server? active;
  VpnStatus _fakeStatus = VpnStatus.disconnected;

  /// Told the moment a tunnel is up, when its "connected" event would be
  /// recorded.
  void Function()? onUp;

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
    active = server;
    _fakeStatus = VpnStatus.connecting;
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 5));
    _fakeStatus = works.contains(server.pathKey)
        ? VpnStatus.connected
        : VpnStatus.error;
    if (_fakeStatus == VpnStatus.connected) onUp?.call();
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

  const network = 'mobile';

  late List<String> probed;
  late Map<String, DoorOutcome> outcomes;

  /// The door rows the reporter sent, in the pieces it cut them into.
  late List<List<Map<String, dynamic>>> reported;
  late _Kept communityReports;
  late int fetches;
  late Future<bool> Function() answer;
  late Duration probeTime;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    probed = [];
    outcomes = {
      v6.pathKey: const DoorOutcome(
        ms: -1,
        error: 'tcp unreachable',
        phase: 'tcp',
      ),
    };
    reported = [];
    communityReports = _Kept();
    fetches = 0;
    answer = () async => false;
    probeTime = Duration.zero;
  });

  ConnectFlow flow(_FakeVpn vpn, {ChecklistSettings? checklist}) => ConnectFlow(
    vpn: vpn,
    memory: PathMemory(),
    finder: PathFinder(
      read: (p) async {
        probed.add(p.pathKey);
        if (probeTime > Duration.zero) await Future.delayed(probeTime);
        return outcomes[p.pathKey] ??
            const DoorOutcome(
              ms: -1,
              error: 'tcp timeout; no answer in 3000 ms',
              phase: 'tcp',
            );
      },
      internet: () {
        fetches++;
        return answer();
      },
      budget: const Duration(seconds: 1),
    ),
    reporter: VpnEventReporter(
      send: (_, _, _) async {},
      sendProbes: (_, probes, _) async => reported.add(probes),
      deviceId: () async => 'DEV-1',
      appVersion: () async => '1.7.1',
      platform: 'android',
      networkType: () async => 'mobile',
    ),
    ipv6: Ipv6Reach(route: () async => null),
    networkKey: () async => network,
    carrier: () async => null,
    communityChecks: communityReports,
    checklist: () => checklist,
    attemptTimeout: const Duration(seconds: 2),
  );

  /// The door rows sent, whatever pieces they went in.
  List<Map<String, dynamic>> rows() => [for (final b in reported) ...b];

  List<String> keys(Iterable<Server> servers) => [
    for (final s in servers) s.pathKey,
  ];

  /// What the door checks taught about IPv6 on [network], with no answer
  /// from the platform.
  Future<bool> ipv6Usable() =>
      Ipv6Reach(route: () async => null).usable(network);

  group('every door closed', () {
    test('beside a failed fetch it ends at no internet: no dial, no row '
        'sent, nothing learnt about IPv6', () async {
      final vpn = _FakeVpn({});
      final f = flow(vpn);

      await f.connect(paths);
      await pumpEventQueue();

      expect(f.stage, ConnectStage.noInternet);
      expect(probed, keys(paths));
      expect(fetches, 1);
      expect(vpn.dialled, isEmpty);
      expect(reported, isEmpty);
      // Untouched: with nothing learnt, the answer is yes.
      expect(await ipv6Usable(), isTrue);
    });

    test('with the fetch passing the same rows go out, and the IPv6 row '
        'says the network has none', () async {
      answer = () async => true;
      final vpn = _FakeVpn({});
      final f = flow(vpn);

      await f.connect(paths);
      await pumpEventQueue();

      expect(f.stage, ConnectStage.nothingOpen);
      expect(probed, keys(paths));
      expect(rows(), hasLength(paths.length));
      expect(await ipv6Usable(), isFalse);
    });
  });

  test('a door open beside a failed fetch is dialled and connects, and its '
      'rows go out: the phone has internet', () async {
    outcomes[hel2.pathKey] = open;
    final vpn = _FakeVpn({hel2.pathKey});
    final f = flow(vpn);

    await f.connect(paths);
    await pumpEventQueue();

    expect(f.stage, ConnectStage.done);
    expect(f.chosen, hel2);
    expect(probed, keys([hel1, hel2]));
    expect(vpn.dialled, [hel2.pathKey]);
    expect(rows().map((r) => r['ok']), [false, true]);
  });

  // Found 2026-10-12 in review: the rows of a tap with a door open waited
  // for the fetch, which can run about 10 seconds where the control sites
  // are slow. They could then be queued after the tunnel's "connected"
  // event, and the backend held the tap's closed pieces dated after the
  // connect, which the stuck rules count as a phone still stuck.
  test('a door open while the fetch runs is dialled without waiting for it, '
      'and its rows are out before the tunnel is up', () async {
    final fetch = Completer<bool>();
    answer = () => fetch.future;
    outcomes[hel2.pathKey] = open;
    final vpn = _FakeVpn({hel2.pathKey});
    List<Object?>? atConnect;
    vpn.onUp = () => atConnect = [for (final r in rows()) r['ok']];
    final f = flow(vpn);

    await f.connect(paths);
    await pumpEventQueue();

    expect(fetch.isCompleted, isFalse);
    expect(f.stage, ConnectStage.done);
    expect(vpn.dialled, [hel2.pathKey]);
    expect(atConnect, [false, true]);

    fetch.complete(false);
    await pumpEventQueue();

    // Once, whatever the fetch then says.
    expect(rows(), hasLength(2));
  });

  group('after a failed fetch the own doors get FallbackSettings.after', () {
    final checklist = ChecklistSettings(
      fallback: FallbackSettings(
        links: 4,
        parallel: 2,
        after: const Duration(milliseconds: 30),
      ),
    );

    setUp(() => probeTime = const Duration(milliseconds: 20));

    test('then the tap ends at no internet', () async {
      final vpn = _FakeVpn({});
      final f = flow(vpn, checklist: checklist);

      // No shared links, so the search's own budget is the finder's 1 s.
      await f.connect(paths);
      await pumpEventQueue();

      expect(probed.length, lessThan(paths.length));
      expect(f.stage, ConnectStage.noInternet);
      expect(vpn.dialled, isEmpty);
      expect(reported, isEmpty);
    });

    test('with the fetch passing every door is checked', () async {
      answer = () async => true;
      final vpn = _FakeVpn({});
      final f = flow(vpn, checklist: checklist);

      await f.connect(paths);
      await pumpEventQueue();

      expect(probed, keys(paths));
      expect(f.stage, ConnectStage.nothingOpen);
      expect(rows(), hasLength(paths.length));
    });
  });

  group('every own door closed beside a failed fetch: the shared links are '
      'checked before no internet', () {
    // Until 2026-10-12 the tap ended at no internet here with no shared link
    // checked, and no later try helps a tap that ends there.
    final checklist = ChecklistSettings(
      fallback: FallbackSettings(links: 4, parallel: 2),
    );

    test('an open one connects, and its row goes out; the door rows of the '
        'search beside the failed fetch do not, and nothing is learnt about '
        'IPv6', () async {
      outcomes[community.pathKey] = open;
      final vpn = _FakeVpn({community.pathKey});
      final f = flow(vpn, checklist: checklist);

      await f.connect(paths, shared: () async => [community]);
      await pumpEventQueue();

      expect(f.stage, ConnectStage.done);
      expect(f.chosen, community);
      expect(probed, [...keys(paths), community.pathKey]);
      expect(vpn.dialled, [community.pathKey]);
      expect(reported, isEmpty);
      expect(communityReports.kept.map((c) => c.ok), [true]);
      expect(await ipv6Usable(), isTrue);
    });

    test('with no checklist block too', () async {
      outcomes[community.pathKey] = open;
      final vpn = _FakeVpn({community.pathKey});
      final f = flow(vpn);

      await f.connect(paths, shared: () async => [community]);
      await pumpEventQueue();

      expect(f.stage, ConnectStage.done);
      expect(vpn.dialled, [community.pathKey]);
    });

    test('with FallbackSettings.after too', () async {
      probeTime = const Duration(milliseconds: 20);
      outcomes[community.pathKey] = open;
      final vpn = _FakeVpn({community.pathKey});
      final f = flow(
        vpn,
        checklist: ChecklistSettings(
          fallback: FallbackSettings(
            links: 4,
            parallel: 2,
            after: const Duration(milliseconds: 30),
          ),
        ),
      );

      await f.connect(paths, shared: () async => [community]);
      await pumpEventQueue();

      expect(f.stage, ConnectStage.done);
      expect(f.chosen, community);
      expect(reported, isEmpty);
      expect(communityReports.kept.map((c) => c.ok), [true]);
    });

    test('an open one whose tunnel fails ends the tap at failed: the phone '
        'has internet', () async {
      outcomes[community.pathKey] = open;
      final vpn = _FakeVpn({});
      final f = flow(vpn, checklist: checklist);

      await f.connect(paths, shared: () async => [community]);
      await pumpEventQueue();

      expect(f.stage, ConnectStage.failed);
      expect(f.chosen, community);
      expect(vpn.dialled, [community.pathKey]);
    });

    test('none open: the tap ends at no internet, and the memory keeps the '
        'link that last worked here', () async {
      await PathMemory().rememberShared(network, community.pathKey);
      final vpn = _FakeVpn({});
      final f = flow(vpn, checklist: checklist);

      await f.connect(paths, shared: () async => [community]);
      await pumpEventQueue();

      expect(f.stage, ConnectStage.noInternet);
      expect(probed, [...keys(paths), community.pathKey]);
      expect(vpn.dialled, isEmpty);
      expect(communityReports.kept, isEmpty);
      // On an offline phone every link fails its check. Written down, that
      // would put each one at the back for the day on this network.
      expect(await PathMemory().recallShared(network), community.pathKey);
      expect(await PathMemory().failedToday(network), isEmpty);
    });
  });

  group('the community fallback after an own door whose tunnel failed', () {
    final checklist = ChecklistSettings(
      fallback: FallbackSettings(links: 4, parallel: 2),
    );

    setUp(() {
      outcomes[hel1.pathKey] = open;
      outcomes[community.pathKey] = open;
    });

    test('after a failed fetch the open door and the open link are both '
        'reported: each check found one open', () async {
      final vpn = _FakeVpn({community.pathKey});
      final f = flow(vpn, checklist: checklist);

      await f.connect(paths, shared: () async => [community]);
      await pumpEventQueue();

      expect(f.stage, ConnectStage.done);
      expect(f.chosen, community);
      expect(vpn.dialled, [hel1.pathKey, community.pathKey]);
      expect(communityReports.kept.map((c) => c.ok), [true]);
      expect(rows().map((r) => r['ok']), [true]);
    });

    test('a community link found closed after a failed fetch is neither '
        'reported nor written to the memory', () async {
      outcomes.remove(community.pathKey);
      final vpn = _FakeVpn({});
      final f = flow(vpn, checklist: checklist);

      await f.connect(paths, shared: () async => [community]);
      await pumpEventQueue();

      expect(f.stage, ConnectStage.failed);
      expect(probed, contains(community.pathKey));
      expect(communityReports.kept, isEmpty);
      final failed = await PathMemory().failedToday(network);
      // The own door's tunnel did fail, and that is kept.
      expect(failed, contains(hel1.pathKey));
      expect(failed, isNot(contains(community.pathKey)));
    });

    test('with the fetch passing both are reported', () async {
      answer = () async => true;
      final vpn = _FakeVpn({community.pathKey});
      final f = flow(vpn, checklist: checklist);

      await f.connect(paths, shared: () async => [community]);
      await pumpEventQueue();

      expect(f.stage, ConnectStage.done);
      expect(f.chosen, community);
      expect(communityReports.kept, hasLength(1));
      expect(communityReports.kept.single.ok, isTrue);
      expect(rows(), hasLength(1));
      expect(rows().single['ok'], isTrue);
    });
  });

  // The tap after a fallback chose a community link checks some of the
  // device's own doors beside it first (FallbackSettings.ownFirst). Until
  // 2026-10-12 that check ran no control fetch and sent its rows at once.
  // On a phone with no internet they were all closed, and they reached the
  // backend once the phone was back online, where an attempt whose rows
  // are all closed counts as one that found every door closed.
  group('the own doors checked beside a fallback\'s pick', () {
    final checklist = ChecklistSettings(
      fallback: FallbackSettings(links: 4, parallel: 2, ownFirst: 1),
    );

    Future<void> tap(ConnectFlow f) => f.connect(
      paths,
      picked: community,
      ownFirst: true,
      shared: () async => [community],
    );

    test('beside a failed fetch, with nothing open, send no door row and no '
        'community row', () async {
      final vpn = _FakeVpn({});
      final f = flow(vpn, checklist: checklist);

      await tap(f);
      await pumpEventQueue();

      expect(f.stage, ConnectStage.noInternet);
      expect(probed.take(2), [hel1.pathKey, community.pathKey]);
      expect(vpn.dialled, isEmpty);
      expect(reported, isEmpty);
      expect(communityReports.kept, isEmpty);
    });

    test('with the fetch passing, both go out', () async {
      answer = () async => true;
      final vpn = _FakeVpn({});
      final f = flow(vpn, checklist: checklist);

      await tap(f);
      await pumpEventQueue();

      expect(f.stage, ConnectStage.nothingOpen);
      expect(communityReports.kept.map((c) => c.ok), [false]);
      // The own-first row, then the diagnosis, which checks that door
      // again after the others.
      expect(rows().map((r) => r['door']), [
        hel1.door,
        hel2.door,
        v6.door,
        fsn1.door,
        hel1.door,
      ]);
    });

    test('an own door found open: both rows go out before the fetch answers, '
        'and before the tunnel is up', () async {
      final fetch = Completer<bool>();
      answer = () => fetch.future;
      outcomes[hel1.pathKey] = open;
      final vpn = _FakeVpn({hel1.pathKey});
      List<Object?>? atConnect;
      vpn.onUp = () => atConnect = [for (final r in rows()) r['ok']];
      final f = flow(vpn, checklist: checklist);

      await tap(f);
      await pumpEventQueue();

      expect(f.stage, ConnectStage.done);
      expect(vpn.dialled, [hel1.pathKey]);
      expect(atConnect, [true]);
      expect(communityReports.kept.map((c) => c.ok), [false]);
      fetch.complete(false);
      await pumpEventQueue();
      expect(rows(), hasLength(1));
    });

    test('the pick found open: the own door found closed beside it goes out '
        'too, before the fetch answers', () async {
      final fetch = Completer<bool>();
      answer = () => fetch.future;
      outcomes[community.pathKey] = open;
      final vpn = _FakeVpn({community.pathKey});
      List<Object?>? atConnect;
      vpn.onUp = () => atConnect = [for (final r in rows()) r['ok']];
      final f = flow(vpn, checklist: checklist);

      await tap(f);
      await pumpEventQueue();

      expect(f.stage, ConnectStage.done);
      expect(vpn.dialled, [community.pathKey]);
      expect(atConnect, [false]);
      expect(communityReports.kept.map((c) => c.ok), [true]);
      fetch.complete(false);
      await pumpEventQueue();
    });
  });
}
