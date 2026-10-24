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

/// A phone with no servers of its own: its own servers did not load,
/// usually because its network cuts our calls, and all it has are shared
/// links, from the public list or from the fallback file.
///
/// Until 2026-10-11 a tap dialled the one link on the card and stopped at
/// an error when that link was blocked. Now it is the pick first and then
/// the other links, checked as the fallback checks them. Since 2.2.0 the
/// pick is checked on its own before it is dialled, and a closed one is
/// not dialled.

/// Ten community links, in the order the backend sent them.
final community = [
  for (var i = 0; i < 10; i++)
    Server.fromConnectionUri(
      'vless://u@h$i.example:443?type=tcp&security=reality'
      '&sni=www.samsung.com&pbk=key#Link$i',
      index: i,
    ),
];

/// A tunnel that comes up, verified, through the links in [works], and
/// fails through everything else.
class _FakeVpn extends VpnService {
  _FakeVpn(this.works)
    : super(events: VpnEventReporter(send: (_, _, _) async {}));

  final Set<String> works;
  final dialled = <String>[];
  VpnStatus _fakeStatus = VpnStatus.disconnected;

  /// Every dial fails the way a refused VPN permission does.
  bool refusePermission = false;

  /// Only dials of these fail that way.
  Set<String> refuseFor = {};
  bool _refusedLast = false;
  int clearedErrors = 0;

  @override
  bool get failedOnPermission => refusePermission || _refusedLast;

  @override
  VpnStatus get status => _fakeStatus;

  @override
  bool get isConnected => _fakeStatus == VpnStatus.connected;

  @override
  bool get isConnecting => _fakeStatus == VpnStatus.connecting;

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
    _refusedLast = refuseFor.contains(server.pathKey);
    _fakeStatus = VpnStatus.connecting;
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 5));
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
    clearedErrors++;
    if (_fakeStatus == VpnStatus.error) _fakeStatus = VpnStatus.disconnected;
    notifyListeners();
  }
}

/// The community checks the fallback reports, kept instead of sent.
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
  late _Kept reports;
  late bool online;
  late PathMemory memory;

  /// The control fetch's answer, and how many fetches were made.
  late Future<bool> Function() answer;
  late int fetches;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    probed = [];
    openHere = {};
    reports = _Kept();
    online = true;
    memory = PathMemory();
    answer = () async => online;
    fetches = 0;
  });

  ConnectFlow flow(_FakeVpn vpn, {ChecklistSettings? checklist}) => ConnectFlow(
    vpn: vpn,
    memory: memory,
    finder: PathFinder(
      probe: (p) async {
        probed.add(p.pathKey);
        final open = openHere.contains(p.pathKey);
        await Future.delayed(Duration(milliseconds: open ? 1 : 5));
        return open ? 120 : -1;
      },
      internet: () {
        fetches++;
        return answer();
      },
    ),
    reporter: VpnEventReporter(
      send: (_, _, _) async {},
      sendProbes: (_, _, _) async {},
      deviceId: () async => 'DEV-1',
      appVersion: () async => '1.7.0',
      platform: 'android',
      networkType: () async => 'mobile',
    ),
    ipv6: Ipv6Reach(route: () async => false),
    networkKey: () async => 'mobile',
    carrier: () async => null,
    communityChecks: reports,
    checklist: () => checklist,
    attemptTimeout: const Duration(seconds: 2),
  );

  final race = ChecklistSettings(
    fallback: FallbackSettings(links: 8, parallel: 4),
  );

  test('the pick is checked and dialled first, and when it works nothing '
      'else is checked', () async {
    openHere = {community[0].pathKey};
    final vpn = _FakeVpn({community[0].pathKey});
    final f = flow(vpn, checklist: race);

    await f.connectShared(community[0], shared: () async => community);
    await pumpEventQueue();

    expect(f.stage, ConnectStage.done);
    expect(f.chosen, community[0]);
    expect(vpn.dialled, [community[0].pathKey]);
    expect(probed, [community[0].pathKey]);
  });

  // On Tehran day 2026-10-23, 165 picked links were dialled with no check,
  // 71% of them dead, at about 21 seconds a dead dial.
  test('a pick found closed is not dialled, and the other links are checked '
      'next', () async {
    openHere = {community[3].pathKey};
    final vpn = _FakeVpn({community[0].pathKey, community[3].pathKey});
    final f = flow(vpn, checklist: race);

    await f.connectShared(community[0], shared: () async => community);
    await pumpEventQueue();

    expect(f.stage, ConnectStage.done);
    expect(f.chosen, community[3]);
    // The pick's tunnel would have come up, but its check found it closed.
    expect(vpn.dialled, [community[3].pathKey]);
    expect(probed.first, community[0].pathKey);
    expect(probed.where((k) => k == community[0].pathKey), hasLength(1));
    // Its check goes out as a community check, and it goes behind the
    // other links in the next fallback, without counting as a failure.
    expect(reports.kept.where((c) => c.link == community[0].connectionUri), [
      isA<CommunityCheck>().having((c) => c.ok, 'ok', isFalse),
    ]);
    expect(await memory.failedToday('mobile'), contains(community[0].pathKey));
    expect(await memory.skippable('mobile'), isEmpty);
  });

  test('a blocked pick no longer ends the tap: the other links are checked '
      'and the tunnel comes up through one that is open', () async {
    openHere = {community[3].pathKey};
    final vpn = _FakeVpn({community[3].pathKey});
    final moved = <Server>[];
    final f = flow(vpn, checklist: race);

    await f.connectShared(
      community[0],
      shared: () async => community,
      onShared: moved.add,
    );
    await pumpEventQueue();

    expect(f.stage, ConnectStage.done);
    expect(f.chosen, community[3]);
    // The pick was checked, found closed and not dialled.
    expect(vpn.dialled, [community[3].pathKey]);
    // The pick is not checked again among the others.
    expect(probed.where((k) => k == community[0].pathKey), hasLength(1));
    expect(moved.single, community[3]);
    // What the phone found reaches the backend as community checks.
    expect(reports.kept, isNotEmpty);
  });

  test('with nothing open the tap ends saying so, as one with servers of '
      'its own does', () async {
    final f = flow(_FakeVpn({}), checklist: race);

    await f.connectShared(community[0], shared: () async => community);
    await pumpEventQueue();

    expect(f.stage, ConnectStage.nothingOpen);
    // The pick, then the eight links of the race.
    expect(probed, hasLength(9));
  });

  test('a tap while one is under way does not start a second', () async {
    openHere = {community[0].pathKey};
    final vpn = _FakeVpn({community[0].pathKey});
    final f = flow(vpn, checklist: race);

    final first = f.connectShared(community[0], shared: () async => community);
    await f.connectShared(community[1], shared: () async => community);
    await first;
    await pumpEventQueue();

    expect(vpn.dialled, [community[0].pathKey]);
  });

  // Until 2026-10-12 this path ran no control fetch. On a phone with no
  // internet every link failed its check, each one was sent as a failed
  // community check once the phone was back online, and each was put at
  // the back of the next fallback on this network for the day.
  group('the control fetch', () {
    test(
      'failed, with nothing open: the links are checked, the tap ends at '
      'no internet, and nothing is reported or written to the memory',
      () async {
        answer = () async => false;
        final f = flow(_FakeVpn({}), checklist: race);

        await f.connectShared(community[0], shared: () async => community);
        await pumpEventQueue();

        expect(f.stage, ConnectStage.noInternet);
        // One fetch for the whole tap: the one started before the dial.
        expect(fetches, 1);
        // A failed fetch does not prove the phone is offline, so the pick
        // and the links get their check before the tap says there is no
        // internet.
        expect(probed, hasLength(9));
        expect(reports.kept, isEmpty);
        // Not even the pick: on a phone with no internet every dial fails.
        expect(await PathMemory().failedToday('mobile'), isEmpty);
        final prefs = await SharedPreferences.getInstance();
        expect(
          prefs.getString(PathMemory.storageKey) ?? '',
          isNot(contains(community[0].pathKey)),
        );
      },
    );

    test('passing, with nothing open: the links are reported and written '
        'down', () async {
      final f = flow(_FakeVpn({}), checklist: race);

      await f.connectShared(community[0], shared: () async => community);
      await pumpEventQueue();

      expect(f.stage, ConnectStage.nothingOpen);
      // The pick's check and the eight of the race.
      expect(reports.kept, hasLength(9));
      expect(await PathMemory().failedToday('mobile'), hasLength(9));
    });

    test('a link found open is dialled without waiting for the fetch, and '
        'its check goes out at once', () async {
      final fetch = Completer<bool>();
      answer = () => fetch.future;
      openHere = {community[3].pathKey};
      final vpn = _FakeVpn({community[3].pathKey});
      final f = flow(vpn, checklist: race);

      unawaited(f.connectShared(community[0], shared: () async => community));
      await Future<void>.delayed(const Duration(milliseconds: 200));

      expect(fetch.isCompleted, isFalse);
      expect(f.stage, ConnectStage.done);
      expect(vpn.dialled, [community[3].pathKey]);
      expect(reports.kept.where((c) => c.ok), hasLength(1));
      fetch.complete(false);
      await pumpEventQueue();
    });

    test('is not waited for when the pick connects', () async {
      final fetch = Completer<bool>();
      answer = () => fetch.future;
      openHere = {community[0].pathKey};
      final vpn = _FakeVpn({community[0].pathKey});
      final f = flow(vpn, checklist: race);

      await f.connectShared(community[0], shared: () async => community);

      expect(f.stage, ConnectStage.done);
      expect(probed, [community[0].pathKey]);
      // The pick's open check goes out at once, as an open row does.
      await pumpEventQueue();
      expect(reports.kept.map((c) => c.ok), [isTrue]);
      fetch.complete(true);
      await pumpEventQueue();
      expect(reports.kept, hasLength(1));
    });

    test('a tap stopped while it waits on the fetch writes nothing when the '
        'fetch answers', () async {
      // Found 2026-10-12 in review. The stopped tap wrote its pick's failure
      // once its fetch answered, after the next tap had connected through
      // the same pick, and the memory forgot that pick as the shared link
      // that last worked on this network.
      final fetches = <Completer<bool>>[];
      answer = () {
        final fetch = Completer<bool>();
        fetches.add(fetch);
        return fetch.future;
      };
      final vpn = _FakeVpn({});
      final f = flow(vpn, checklist: race);
      final first = f.connectShared(
        community[0],
        shared: () async {
          await Future<void>.delayed(const Duration(milliseconds: 30));
          return community;
        },
      );
      // The pick failed and the other links are being checked.
      for (var i = 0; i < 200 && f.stage != ConnectStage.diagnosing; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 2));
      }
      expect(f.stage, ConnectStage.diagnosing);
      f.cancel();
      await vpn.disconnect();
      // The next tap, on the same pick, which works this time.
      vpn.works.add(community[0].pathKey);
      openHere.add(community[0].pathKey);
      await f.connectShared(community[0], shared: () async => community);
      await pumpEventQueue();
      expect(f.stage, ConnectStage.done);
      expect(await memory.recallShared('mobile'), community[0].pathKey);

      // The stopped tap's fetch answers now.
      for (final fetch in fetches) {
        if (!fetch.isCompleted) fetch.complete(true);
      }
      await first;
      await pumpEventQueue();

      expect(await memory.recallShared('mobile'), community[0].pathKey);
      expect(
        await memory.failedToday('mobile'),
        isNot(contains(community[0].pathKey)),
      );
    });
  });

  // Found by the review before 1.8.0: the device's own servers can land
  // after a tap has stopped waiting for them.
  final own = Server.fromDedicatedPath(
    uri:
        'vless://u@198.51.100.204:8443?type=xhttp&security=reality'
        '&sni=www.samsung.com&pbk=key#Row13',
    door: 'xhttp-reality',
    doorLabel: 'xhttp-reality',
    serverId: 13,
  );

  test('own servers that arrive while the pick is dialled take over: the '
      'run goes to them, not to the shared race', () async {
    // The pick's check passes and its tunnel fails.
    openHere = {own.pathKey, community[0].pathKey};
    final vpn = _FakeVpn({own.pathKey});
    var ownPaths = <Server>[];
    final f = flow(vpn, checklist: race);

    final tap = f.connectShared(
      community[0],
      shared: () async => community,
      own: () => ownPaths,
      preferredOwn: () => own,
    );
    // They land during the pick's dial.
    ownPaths = [own];
    await tap;
    await pumpEventQueue();

    expect(f.stage, ConnectStage.done);
    expect(f.chosen?.pathKey, own.pathKey);
    expect(vpn.dialled.first, community[0].pathKey);
    expect(vpn.dialled, contains(own.pathKey));
    // No shared link was raced: the pick's own check, then our door.
    expect(probed, [community[0].pathKey, own.pathKey]);
  });

  test('own servers already there when a try starts go first, and a link '
      'that only stood in for them is not dialled', () async {
    openHere = {own.pathKey};
    final vpn = _FakeVpn({own.pathKey});
    final f = flow(vpn, checklist: race);

    await f.connectShared(
      community[0],
      shared: () async => community,
      own: () => [own],
      preferredOwn: () => own,
    );
    await pumpEventQueue();

    expect(f.stage, ConnectStage.done);
    expect(vpn.dialled, [own.pathKey]);
  });

  test('a refused VPN permission ends the tap at once, with its error kept '
      'and no other link checked', () async {
    openHere = {community[0].pathKey};
    final vpn = _FakeVpn({})..refusePermission = true;
    final f = flow(vpn, checklist: race);

    await f.connectShared(community[0], shared: () async => community);
    await pumpEventQueue();

    expect(f.stage, ConnectStage.failed);
    expect(vpn.clearedErrors, 0);
    expect(probed, [community[0].pathKey]);
  });

  // With no internet the tap ends at no internet only after the links were
  // checked and none was open (see "the control fetch" above). A failed
  // fetch does not prove the phone is offline, so an open link still
  // carries the tap.
  test('with the control fetch failed, an open link still connects', () async {
    online = false;
    openHere = {community[3].pathKey};
    final vpn = _FakeVpn({community[3].pathKey});
    final f = flow(vpn, checklist: race);

    await f.connectShared(community[0], shared: () async => community);
    await pumpEventQueue();

    expect(f.stage, ConnectStage.done);
    expect(f.chosen, community[3]);
    expect(vpn.dialled, [community[3].pathKey]);
  });

  test('with the control fetch failed, an open link whose tunnel fails ends '
      'the tap at failed, because the phone has internet', () async {
    online = false;
    openHere = {community[3].pathKey};
    final f = flow(_FakeVpn({}), checklist: race);

    await f.connectShared(community[0], shared: () async => community);
    await pumpEventQueue();

    expect(f.stage, ConnectStage.failed);
    expect(f.chosen, community[3]);
  });

  test('a spent allowance dials nothing', () async {
    final vpn = _FakeVpn({community[0].pathKey});
    final f = flow(vpn, checklist: race);

    await f.connectShared(
      community[0],
      shared: () async => community,
      blocked: () => true,
    );
    await pumpEventQueue();

    expect(f.stage, ConnectStage.idle);
    expect(vpn.dialled, isEmpty);
  });

  test('a link that only stood in for servers not yet loaded becomes the '
      'shared server in use once it carries the tunnel; a user\'s pick is '
      'left as it was', () async {
    final recorded = <Server>[];
    openHere = {community[0].pathKey};
    final f = flow(_FakeVpn({community[0].pathKey}), checklist: race);
    await f.connectShared(
      community[0],
      shared: () async => community,
      onShared: recorded.add,
    );
    await pumpEventQueue();
    expect(recorded, [community[0]]);

    recorded.clear();
    final g = flow(_FakeVpn({community[0].pathKey}), checklist: race);
    await g.connectShared(
      community[0],
      shared: () async => community,
      pickIsChoice: true,
      onShared: recorded.add,
    );
    await pumpEventQueue();
    expect(recorded, isEmpty);
  });

  test('own servers that arrive during the shared race get their turn when '
      'the race finds nothing', () async {
    openHere = {own.pathKey};
    final vpn = _FakeVpn({own.pathKey});
    var ownPaths = <Server>[];
    final f = flow(vpn, checklist: race);

    await f.connectShared(
      community[0],
      shared: () async {
        // They land while the links are fetched and checked.
        ownPaths = [own];
        return community;
      },
      own: () => ownPaths,
      preferredOwn: () => own,
    );
    await pumpEventQueue();

    expect(f.stage, ConnectStage.done);
    expect(f.chosen?.pathKey, own.pathKey);
  });

  test('an allowance found spent during the race stops the open link being '
      'dialled', () async {
    // The pick's check passes and its tunnel fails.
    openHere = {community[0].pathKey, community[2].pathKey};
    final vpn = _FakeVpn({community[2].pathKey});
    var spent = false;
    final f = flow(vpn, checklist: race);

    await f.connectShared(
      community[0],
      shared: () async {
        spent = true;
        return community;
      },
      blocked: () => spent,
    );
    await pumpEventQueue();

    expect(vpn.dialled, [community[0].pathKey]);
    expect(f.stage, ConnectStage.idle);
  });

  test('with servers of its own, an allowance found spent while the pick is '
      'checked stops it being dialled', () async {
    // Found 2026-10-23 in review: the tap that hands over to the device's
    // own servers checked the pick and dialled it without a look at the
    // allowance, which the tap of a phone without servers takes.
    openHere = {community[0].pathKey};
    final vpn = _FakeVpn({community[0].pathKey});
    final f = flow(vpn, checklist: race);

    await f.connectShared(
      community[0],
      shared: () async => community,
      own: () => [own],
      preferredOwn: () => own,
      pickIsChoice: true,
      // Spent once the pick's check has started.
      blocked: () => probed.contains(community[0].pathKey),
    );
    await pumpEventQueue();

    expect(probed, [community[0].pathKey]);
    expect(vpn.dialled, isEmpty);
    expect(f.stage, ConnectStage.idle);
  });

  test('a pick that failed is not checked again after the handover to own '
      'servers', () async {
    openHere = {community[0].pathKey};
    final vpn = _FakeVpn({});
    var ownPaths = <Server>[];
    final f = flow(vpn, checklist: race);

    final tap = f.connectShared(
      community[0],
      shared: () async => community,
      own: () => ownPaths,
      preferredOwn: () => own,
    );
    ownPaths = [own];
    await tap;
    await pumpEventQueue();

    // Checked once, before its dial, and not again after the handover.
    expect(probed.where((k) => k == community[0].pathKey), hasLength(1));
  });

  test('own servers that arrive during the race are not dialled after the '
      'race\'s dial was refused the VPN permission', () async {
    openHere = {community[3].pathKey, own.pathKey};
    final vpn = _FakeVpn({own.pathKey})..refuseFor = {community[3].pathKey};
    var ownPaths = <Server>[];
    final f = flow(vpn, checklist: race);

    await f.connectShared(
      community[0],
      shared: () async {
        ownPaths = [own];
        return community;
      },
      own: () => ownPaths,
      preferredOwn: () => own,
    );
    await pumpEventQueue();

    expect(vpn.dialled, isNot(contains(own.pathKey)));
    expect(f.stage, ConnectStage.failed);
  });
}
