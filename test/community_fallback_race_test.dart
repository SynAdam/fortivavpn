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

/// The fallback through community links, checked several at a time.
///
/// On 2026-10-10 the connect traces showed the fallback starting about 21
/// seconds after the tap and a tap that found nothing ending at about 39
/// seconds: six community links, one at a time, about 3 seconds each.
/// Users stopped a tap after 12 seconds (the median). With the backend's
/// fallback settings the links are checked several at once, and the
/// tunnel comes up through the first of them, in the backend's order, that
/// let data through.
final ours = Server.fromDedicatedPath(
  uri:
      'vless://u@198.51.100.204:8443?type=xhttp&security=reality'
      '&sni=www.samsung.com&pbk=key#Row13',
  door: 'xhttp-reality',
  doorLabel: 'xhttp-reality',
  serverId: 13,
);

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
  late int running;
  late int most;
  late Set<String> openHere;

  /// Closed links whose check waits its whole time, as one with no answer
  /// does on a phone.
  late Set<String> slowHere;
  late _Kept reports;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    probed = [];
    running = 0;
    most = 0;
    openHere = {};
    slowHere = {};
    reports = _Kept();
  });

  ConnectFlow flow(_FakeVpn vpn, {ChecklistSettings? checklist}) => ConnectFlow(
    vpn: vpn,
    memory: PathMemory(),
    finder: PathFinder(
      probe: (p) async {
        probed.add(p.pathKey);
        running++;
        if (running > most) most = running;
        // An open link answers sooner than a closed one waits out its
        // time, as on a phone.
        final open = openHere.contains(p.pathKey);
        final wait = open ? 1 : (slowHere.contains(p.pathKey) ? 300 : 5);
        await Future.delayed(Duration(milliseconds: wait));
        running--;
        return open ? 120 : -1;
      },
      internet: () async => true,
    ),
    reporter: VpnEventReporter(
      send: (_, _, _) async {},
      sendProbes: (_, _, _) async {},
      deviceId: () async => 'DEV-1',
      appVersion: () async => '1.6.21',
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

  ChecklistSettings fallback({int links = 8, int parallel = 4}) =>
      ChecklistSettings(
        fallback: FallbackSettings(links: links, parallel: parallel),
      );

  List<String> keys(Iterable<Server> servers) => [
    for (final s in servers) s.pathKey,
  ];

  test('with the backend\'s settings, links are checked several at once, up '
      'to its number of them', () async {
    final f = flow(_FakeVpn({}), checklist: fallback(links: 8, parallel: 4));

    await f.connect([ours], preferred: ours, shared: () async => community);
    await pumpEventQueue();

    expect(f.stage, ConnectStage.nothingOpen);
    expect(most, 4);
    expect(probed, [ours.pathKey, ...keys(community.take(8))]);
    expect(reports.kept, hasLength(8));
    expect(reports.kept.every((c) => !c.ok), isTrue);
    expect(reports.kept.first.kind, CommunityCheckKind.fallback);
  });

  test('the tunnel comes up through the first link in the backend\'s order '
      'that let data through, not the first to answer, and without waiting '
      'for the checks below it', () async {
    openHere = {community[2].pathKey, community[1].pathKey};
    slowHere = {community[3].pathKey};
    final vpn = _FakeVpn({community[1].pathKey, community[2].pathKey});
    final shared = <Server>[];
    final f = flow(vpn, checklist: fallback(links: 8, parallel: 4));
    final started = DateTime.now();

    await f.connect(
      [ours],
      preferred: ours,
      shared: () async => community,
      onShared: shared.add,
    );
    await pumpEventQueue();

    expect(f.stage, ConnectStage.done);
    expect(f.chosen, community[1]);
    expect(vpn.dialled, [community[1].pathKey]);
    expect(shared.single, community[1]);
    expect(
      DateTime.now().difference(started),
      lessThan(const Duration(milliseconds: 300)),
    );
    // Four checks started. The race returned once link 0 was closed and
    // link 1 open, without waiting for link 3, which still ran: on Tehran
    // day 2026-10-23 that wait cost about 3.1 seconds a race. Every check
    // that answered by then is reported. Link 3's row is back to pending,
    // and the core holds it as a spare.
    expect(probed.skip(1).toList(), keys(community.take(4)));
    expect(reports.kept.map((c) => c.ok), [false, true, true]);
    expect(f.checks.last.state, PathCheckState.pending);
  });

  test('without them, at most six links, one at a time, as before', () async {
    final f = flow(_FakeVpn({}));

    await f.connect([ours], preferred: ours, shared: () async => community);
    await pumpEventQueue();

    expect(f.stage, ConnectStage.nothingOpen);
    expect(most, 1);
    expect(probed.skip(1).toList(), keys(community.take(6)));
  });

  test('without them, the search still stops at the first open link', () async {
    openHere = {community[1].pathKey};
    final vpn = _FakeVpn({community[1].pathKey});
    final f = flow(vpn);

    await f.connect([ours], preferred: ours, shared: () async => community);
    await pumpEventQueue();

    expect(f.stage, ConnectStage.done);
    expect(f.chosen, community[1]);
    expect(probed.skip(1).toList(), keys(community.take(2)));
  });
}
