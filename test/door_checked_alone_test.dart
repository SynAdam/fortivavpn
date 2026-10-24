import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/core/state/connect_flow.dart';
import 'package:fortiva_vpn/data/models/checklist_settings.dart';
import 'package:fortiva_vpn/data/models/server.dart';
import 'package:fortiva_vpn/services/community_checks.dart';
import 'package:fortiva_vpn/services/connect_trace.dart';
import 'package:fortiva_vpn/services/path_finder.dart';
import 'package:fortiva_vpn/services/path_memory.dart';
import 'package:fortiva_vpn/services/vpn_event_reporter.dart';
import 'package:fortiva_vpn/services/vpn_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// An own door read closed while other checks ran beside it is checked
/// again alone (ConnectFlow._checkAlone).
///
/// Since 1.7.1 several own doors are checked at once (DoorCheckSettings).
/// The native check gives up after 3 seconds and cannot stop the core,
/// which goes on moving data after that. On a slow line the checks started
/// beside the top door share the line with it, and an open door can read
/// "tcp ok; no answer in 3000 ms", where 1.7.0 checked it alone, found it
/// open and dialled it. Read from production on 2026-10-12: of 1500 doors
/// a one-at-a-time diagnosis found open in 7 days, the sweep (12 checks at
/// once) found 67 to 70% of the slower ones open, and nearly every check it
/// missed said "no answer".
///
/// Here a door in `slowOpen` is open when no other check runs while it is
/// checked, and reads "tcp ok; no answer" otherwise.
Server door(String host, String door, {int? row}) => Server(
  id: 'dedicated-$host:443',
  name: host,
  country: '',
  city: host,
  connectionUri: 'vless://u@$host:443?type=tcp#$host',
  flagEmoji: '',
  isDedicated: true,
  door: door,
  doorLabel: door,
  serverId: row,
);

/// A tunnel that comes up, verified, through the doors in [works], and
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

/// A memory that calls [onFail] once, after the first failure it writes.
class _StopOnFail extends PathMemory {
  void Function()? onFail;

  @override
  Future<void> markFailed(String network, String pathKey) async {
    await super.markFailed(network, pathKey);
    final stop = onFail;
    onFail = null;
    stop?.call();
  }
}

class _Kept extends CommunityChecks {
  _Kept() : super(platform: 'android');

  @override
  Future<void> report(List<CommunityCheck> checks, {String? carrier}) async {}
}

/// Keeps the trace of the last tap here instead of sending it.
class _KeptTraces extends ConnectTraces {
  _KeptTraces()
    : super(
        enabled: () => true,
        networkType: () async => 'mobile',
        linkFacts: () async => const {},
      );

  ConnectTrace? last;

  @override
  ConnectTrace? start(String attemptId) => last = super.start(attemptId);

  @override
  Future<void> send(ConnectTrace trace) async {}
}

/// One check on the line: whether another check ran while it did.
class _OnLine {
  bool crowded = false;
}

/// What the native check says of an open door that shared a slow line.
const noAnswer = DoorOutcome(
  ms: -1,
  error: 'tcp ok 40ms; no answer in 3000 ms',
  tcpMs: 40,
);

const openAlone = DoorOutcome(ms: 2400, tcpMs: 40, phase: 'ok');

/// A door whose address took no TCP connection: it is not checked again.
const tcpTimeout = DoorOutcome(ms: -1, error: 'tcp timeout', phase: 'tcp');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final hel1 = door('hel', 'tcp-reality');
  final hel2 = door('hel', 'xhttp-reality');
  final fsn1 = door('fsn', 'tcp-reality');
  final fsn2 = door('fsn', 'xhttp-reality');
  final four = [hel1, hel2, fsn1, fsn2];

  final community = Server.fromConnectionUri(
    'vless://u@h1.example:443?type=tcp&security=reality'
    '&sni=www.samsung.com&pbk=key#Link1',
  );

  late List<String> probed;
  late Set<String> slowOpen;
  // Doors whose check says this whatever runs beside it.
  late Map<String, DoorOutcome> fixed;
  late Set<_OnLine> onLine;
  late Duration checkTime;
  late List<Map<String, dynamic>> sent;
  void Function()? onProbe;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    probed = [];
    slowOpen = {};
    fixed = {};
    onLine = {};
    checkTime = const Duration(milliseconds: 20);
    sent = [];
    onProbe = null;
  });

  Future<DoorOutcome> read(Server p) async {
    probed.add(p.pathKey);
    onProbe?.call();
    final me = _OnLine();
    if (onLine.isNotEmpty) {
      me.crowded = true;
      for (final other in onLine) {
        other.crowded = true;
      }
    }
    onLine.add(me);
    try {
      await Future<void>.delayed(checkTime);
    } finally {
      onLine.remove(me);
    }
    final outcome = fixed[p.pathKey];
    if (outcome != null) return outcome;
    if (slowOpen.contains(p.pathKey) && !me.crowded) return openAlone;
    return noAnswer;
  }

  ConnectFlow flow(
    _FakeVpn vpn,
    ChecklistSettings? checklist, {
    Duration budget = const Duration(seconds: 1),
    ConnectTraces? traces,
    bool online = true,
    PathMemory? memory,
  }) => ConnectFlow(
    vpn: vpn,
    memory: memory ?? PathMemory(),
    finder: PathFinder(
      read: read,
      internet: () async => online,
      budget: budget,
      probeTimeout: const Duration(seconds: 1),
    ),
    reporter: VpnEventReporter(
      send: (_, _, _) async {},
      sendProbes: (_, probes, _) async => sent.addAll(probes),
      deviceId: () async => 'DEV-1',
      appVersion: () async => '1.7.1',
      platform: 'android',
      networkType: () async => 'mobile',
    ),
    networkKey: () async => 'mobile:Irancell',
    carrier: () async => 'Irancell',
    communityChecks: _Kept(),
    checklist: () => checklist,
    traces: traces,
    attemptTimeout: const Duration(seconds: 2),
  );

  const fourAtOnce = ChecklistSettings(
    doors: DoorCheckSettings(parallel: 4, stagger: Duration.zero),
  );

  List<String> keys(Iterable<Server> servers) => [
    for (final s in servers) s.pathKey,
  ];

  /// A reported row as "host:door ok".
  List<String> rows() => [
    for (final r in sent) '${r['server_host']}:${r['door']} ${r['ok']}',
  ];

  test('the top door, read closed beside the checks below it, is checked '
      'again alone and dialled', () async {
    slowOpen = {hel1.pathKey};
    final vpn = _FakeVpn({hel1.pathKey});
    final f = flow(vpn, fourAtOnce);

    await f.connect(four, preferred: hel1);
    await pumpEventQueue();

    expect(f.stage, ConnectStage.done);
    expect(vpn.dialled, [hel1.pathKey]);
    expect(probed, [...keys(four), hel1.pathKey]);
    // One at a time the rows below it were never reached, so they go back
    // to pending and are not sent.
    expect(f.checks.map((c) => c.state), [
      PathCheckState.open,
      PathCheckState.pending,
      PathCheckState.pending,
      PathCheckState.pending,
    ]);
    expect(rows(), ['hel:tcp-reality true']);
  });

  test('within the budget the next such row is checked too, and the first '
      'one open alone is dialled', () async {
    fixed = {hel1.pathKey: noAnswer};
    slowOpen = {hel2.pathKey};
    final vpn = _FakeVpn({hel2.pathKey});
    final f = flow(vpn, fourAtOnce);

    await f.connect(four, preferred: hel1);
    await pumpEventQueue();

    expect(f.stage, ConnectStage.done);
    expect(vpn.dialled, [hel2.pathKey]);
    expect(probed, [...keys(four), hel1.pathKey, hel2.pathKey]);
    expect(rows(), ['hel:tcp-reality false', 'hel:xhttp-reality true']);
  });

  test('every door closed alone too: each row goes out once, with the '
      'result of its check alone', () async {
    final f = flow(_FakeVpn({}), fourAtOnce);

    await f.connect(four, preferred: hel1);
    await pumpEventQueue();

    expect(f.stage, ConnectStage.nothingOpen);
    expect(probed, [...keys(four), ...keys(four)]);
    expect(sent, hasLength(4));
    expect(sent.every((r) => r['ok'] == false), isTrue);
  });

  test('past the budget only the first such row is checked again', () async {
    // The four checks at once take longer than the whole budget.
    fixed = {hel1.pathKey: noAnswer};
    slowOpen = {hel2.pathKey};
    final vpn = _FakeVpn({hel2.pathKey});
    final f = flow(vpn, fourAtOnce, budget: const Duration(milliseconds: 5));

    await f.connect(four, preferred: hel1);
    await pumpEventQueue();

    expect(probed, [...keys(four), hel1.pathKey]);
    expect(f.stage, ConnectStage.nothingOpen);
    expect(vpn.dialled, isEmpty);
    expect(sent, hasLength(4));
  });

  test('a door that failed at TCP, or with the core\'s own words, is not '
      'checked again', () async {
    fixed = {
      hel1.pathKey: const DoorOutcome(
        ms: -1,
        error: 'tcp timeout; no answer in 3000 ms',
        phase: 'tcp',
      ),
      hel2.pathKey: const DoorOutcome(
        ms: -1,
        error: 'tcp ok 40ms; EOF',
        tcpMs: 40,
      ),
      fsn1.pathKey: const DoorOutcome(
        ms: -1,
        error: 'tcp ok 40ms; connection reset by peer',
        tcpMs: 40,
      ),
      fsn2.pathKey: const DoorOutcome(
        ms: -1,
        error: 'tcp refused',
        phase: 'tcp',
      ),
    };
    final f = flow(_FakeVpn({}), fourAtOnce);

    await f.connect(four, preferred: hel1);
    await pumpEventQueue();

    expect(f.stage, ConnectStage.nothingOpen);
    expect(probed, keys(four));
    expect(sent, hasLength(4));
  });

  test(
    'door_parallel 1 is the search of 1.7.0: no door is checked twice',
    () async {
      final f = flow(
        _FakeVpn({}),
        const ChecklistSettings(doors: DoorCheckSettings.oneAtATime),
      );

      await f.connect(four, preferred: hel1);
      await pumpEventQueue();

      expect(f.stage, ConnectStage.nothingOpen);
      expect(probed, keys(four));
    },
  );

  test(
    'a stop during the check alone dials nothing and sends no row',
    () async {
      slowOpen = {hel1.pathKey};
      final vpn = _FakeVpn({hel1.pathKey});
      final f = flow(vpn, fourAtOnce);
      onProbe = () {
        if (probed.length == 5) f.cancel();
      };

      await f.connect(four, preferred: hel1);
      await pumpEventQueue();

      expect(probed, [...keys(four), hel1.pathKey]);
      expect(f.stage, ConnectStage.cancelled);
      expect(vpn.dialled, isEmpty);
      expect(sent, isEmpty);
    },
  );

  group('with the shared links after FallbackSettings.after', () {
    final twelve = [
      for (var i = 0; i < 12; i++) door('d$i', 'tcp-reality', row: i),
    ];
    const checklist = ChecklistSettings(
      fallback: FallbackSettings(
        links: 1,
        parallel: 1,
        after: Duration(milliseconds: 50),
      ),
      doors: DoorCheckSettings(parallel: 4, stagger: Duration.zero),
    );

    // Two rounds of four fit in the 50 ms, so four doors are left for
    // after the shared links.
    setUp(() => checkTime = const Duration(milliseconds: 30));

    test('the top door is checked alone before them, and dialled', () async {
      slowOpen = {twelve.first.pathKey};
      fixed = {community.pathKey: openAlone};
      final vpn = _FakeVpn({twelve.first.pathKey, community.pathKey});
      final f = flow(vpn, checklist);

      await f.connect(
        twelve,
        preferred: twelve.first,
        shared: () async => [community],
      );
      await pumpEventQueue();

      expect(f.stage, ConnectStage.done);
      expect(vpn.dialled, [twelve.first.pathKey]);
      expect(probed, isNot(contains(community.pathKey)));
      expect(probed.last, twelve.first.pathKey);
      expect(rows(), ['d0:tcp-reality true']);
    });

    test('the first such door is checked alone before them, a lower one '
        'after them, and both before any row is sent', () async {
      // d0 is closed alone too, and its check alone comes first. d1 is open
      // alone. The other doors fail with the core's own words, so they are
      // not checked again.
      fixed = {
        community.pathKey: const DoorOutcome(
          ms: -1,
          error: 'tcp timeout',
          phase: 'tcp',
        ),
        twelve[0].pathKey: noAnswer,
        for (final d in twelve.skip(2))
          d.pathKey: const DoorOutcome(
            ms: -1,
            error: 'tcp ok 40ms; EOF',
            tcpMs: 40,
          ),
      };
      slowOpen = {twelve[1].pathKey};
      final vpn = _FakeVpn({twelve[1].pathKey});
      final traces = _KeptTraces();
      final f = flow(vpn, checklist, traces: traces);

      await f.connect(
        twelve,
        preferred: twelve.first,
        shared: () async => [community],
      );
      await pumpEventQueue();

      expect(f.stage, ConnectStage.done);
      expect(vpn.dialled, [twelve[1].pathKey]);
      final atShared = probed.indexOf(community.pathKey);
      expect(atShared, greaterThan(0));
      // d0 was checked again before the shared links, d1 after them.
      expect(probed.take(atShared).last, twelve[0].pathKey);
      expect(probed.last, twelve[1].pathKey);
      expect(probed.where((k) => k == twelve[1].pathKey), hasLength(2));
      expect(rows(), ['d0:tcp-reality false', 'd1:tcp-reality true']);
      // d1's row was in the trace before the shared links, with the result
      // of its check beside the others. Its check alone is a step too.
      final d1 = [
        for (final s in traces.last!.steps)
          if (s.door == '1:tcp-reality') (s.stage, s.result),
      ];
      expect(d1, [
        (TraceStage.checklist, TraceResult.fail),
        (TraceStage.checklist, TraceResult.ok),
        (TraceStage.dial, TraceResult.ok),
      ]);
    });
  });

  // Found 2026-10-12 in review: a stop during the checks alone that run
  // after the shared links sent no row at all, while a stop during the
  // last pass sends the search's rows.
  test('a stop during the checks alone after the shared links still sends '
      "the whole search's rows", () async {
    final twelve = [
      for (var i = 0; i < 12; i++) door('d$i', 'tcp-reality', row: i),
    ];
    const checklist = ChecklistSettings(
      fallback: FallbackSettings(
        links: 1,
        parallel: 1,
        after: Duration(milliseconds: 50),
      ),
      doors: DoorCheckSettings(parallel: 4, stagger: Duration.zero),
    );
    checkTime = const Duration(milliseconds: 30);
    fixed = {
      community.pathKey: const DoorOutcome(
        ms: -1,
        error: 'tcp timeout',
        phase: 'tcp',
      ),
    };
    final vpn = _FakeVpn({});
    late ConnectFlow f;
    var afterShared = 0;
    onProbe = () {
      if (!probed.contains(community.pathKey)) return;
      if (probed.last == community.pathKey) return;
      afterShared++;
      // The rest of the search checks d8 to d11. The fifth check after the
      // shared links is the first check alone.
      if (afterShared == 5) f.cancel();
    };
    f = flow(vpn, checklist);

    await f.connect(
      twelve,
      preferred: twelve.first,
      shared: () async => [community],
    );
    await pumpEventQueue();

    expect(afterShared, greaterThanOrEqualTo(5));
    expect(vpn.dialled, isEmpty);
    expect(sent, hasLength(12));
    expect(sent.every((r) => r['ok'] == false), isTrue);
  });

  /// [n] doors, each of its own server, in the backend's order.
  List<Server> rowsOf(int n) => [
    for (var i = 0; i < n; i++) door('d$i', 'tcp-reality', row: i),
  ];

  const atOnce = DoorCheckSettings(parallel: 4, stagger: Duration.zero);
  const searches = [
    ('four at once', atOnce),
    ('one at a time', DoorCheckSettings.oneAtATime),
  ];

  // Found 2026-10-12 in review. The checks alone had only what was left of
  // the search's budget, which the search beside them had nearly used up.
  // In every test here one door at a time, the search of 1.7.0, connects,
  // and four at once ended at "All routes are blocked" before the fix.
  group('the checks alone have time of their own', () {
    test(
      'with no shared links, a slow open door at d6 of 12 is dialled',
      () async {
        // Each check takes 50 ms and the search 400 ms. One at a time
        // reaches d0 to d8. Four at once check all twelve in 150 ms, and the
        // checks alone used to stop before d6.
        checkTime = const Duration(milliseconds: 50);
        final twelve = rowsOf(12);
        final slow = twelve[6];
        for (final (name, doors) in searches) {
          SharedPreferences.setMockInitialValues({});
          probed = [];
          fixed = {
            for (final d in twelve)
              if (d != slow) d.pathKey: noAnswer,
          };
          slowOpen = {slow.pathKey};
          final vpn = _FakeVpn({slow.pathKey});
          final f = flow(
            vpn,
            ChecklistSettings(doors: doors),
            budget: const Duration(milliseconds: 400),
          );

          await f.connect(twelve);
          await pumpEventQueue();

          expect(f.stage, ConnectStage.done, reason: name);
          expect(vpn.dialled, [slow.pathKey], reason: name);
        }
      },
    );

    test('with the shared links after FallbackSettings.after, a slow open '
        'door at d4 of 20 is dialled after them', () async {
      // Each check takes 30 ms, the own doors have 80 ms before the shared
      // link and the search 200 ms. Four at once check d0 to d11 before the
      // link and d12 to d19 after it. The checks alone after those used to
      // stop before d4.
      checkTime = const Duration(milliseconds: 30);
      final twenty = rowsOf(20);
      final slow = twenty[4];
      for (final (name, doors) in searches) {
        SharedPreferences.setMockInitialValues({});
        probed = [];
        fixed = {
          community.pathKey: tcpTimeout,
          for (final d in twenty)
            if (d != slow) d.pathKey: noAnswer,
        };
        slowOpen = {slow.pathKey};
        final vpn = _FakeVpn({slow.pathKey});
        final f = flow(
          vpn,
          ChecklistSettings(
            fallback: const FallbackSettings(
              links: 1,
              parallel: 1,
              after: Duration(milliseconds: 80),
            ),
            doors: doors,
          ),
          budget: const Duration(milliseconds: 200),
        );

        await f.connect(twenty, shared: () async => [community]);
        await pumpEventQueue();

        expect(f.stage, ConnectStage.done, reason: name);
        expect(vpn.dialled, [slow.pathKey], reason: name);
        expect(
          probed.indexOf(community.pathKey),
          lessThan(probed.lastIndexOf(slow.pathKey)),
          reason: name,
        );
      }
    });

    test('with every own door checked before the shared links, a slow open '
        'door below a dead top door is checked alone after them', () async {
      // Eight doors, all checked in the 80 ms before the shared link. d0 is
      // dead and reads "no answer" alone too. Its check alone took the
      // first round's time, and d1 was never checked alone.
      checkTime = const Duration(milliseconds: 30);
      final eight = rowsOf(8);
      final slow = eight[1];
      final traces = _KeptTraces();
      fixed = {
        community.pathKey: tcpTimeout,
        for (final d in eight)
          if (d != slow) d.pathKey: noAnswer,
      };
      slowOpen = {slow.pathKey};
      final vpn = _FakeVpn({slow.pathKey});
      final f = flow(
        vpn,
        const ChecklistSettings(
          fallback: FallbackSettings(
            links: 1,
            parallel: 1,
            after: Duration(milliseconds: 80),
          ),
          doors: atOnce,
        ),
        budget: const Duration(milliseconds: 200),
        traces: traces,
      );
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

      await f.connect(eight, shared: () async => [community]);
      await pumpEventQueue();

      expect(f.stage, ConnectStage.done);
      expect(vpn.dialled, [slow.pathKey]);
      expect(routes, [RouteKind.own, RouteKind.community, RouteKind.own]);
      expect(checkingOwnAfterLinks, {RouteKind.own});
      expect(ownWhileLinks, {StageState.pending});
      expect(reached, [1, 2]);
      expect(f.stageState(RouteKind.own), StageState.connected);
      expect(f.stageState(RouteKind.community), StageState.failed);
      // The shared link is checked once, before d1's check alone.
      expect(probed.where((k) => k == community.pathKey), hasLength(1));
      expect(
        probed.indexOf(community.pathKey),
        lessThan(probed.lastIndexOf(slow.pathKey)),
      );
      // The rows went out before the shared link was checked, as they did
      // before this round existed: one per door, d1 with the result it had
      // beside the other checks.
      expect(rows(), [for (final d in eight) '${d.name}:tcp-reality false']);
      final d1 = [
        for (final s in traces.last!.steps)
          if (s.door == '1:tcp-reality') (s.stage, s.result),
      ];
      expect(d1, [
        (TraceStage.checklist, TraceResult.fail),
        (TraceStage.checklist, TraceResult.ok),
        (TraceStage.dial, TraceResult.ok),
      ]);
    });
  });

  // Found 2026-10-12 in review. A failed control fetch skipped the checks
  // alone, and a door found open alone still ended the tap at "No
  // internet". door_parallel 1 connected through the same door.
  group('after a failed control fetch', () {
    test('the top door, read "no answer" beside the others, is checked '
        'alone and dialled, and its row goes out at once', () async {
      for (final links in [
        <Server>[community],
        <Server>[],
      ]) {
        SharedPreferences.setMockInitialValues({});
        probed = [];
        sent = [];
        fixed = {community.pathKey: tcpTimeout};
        slowOpen = {hel1.pathKey};
        final vpn = _FakeVpn({hel1.pathKey});
        final f = flow(vpn, fourAtOnce, online: false);

        await f.connect(four, shared: () async => links);
        await pumpEventQueue();

        expect(f.stage, ConnectStage.done, reason: '${links.length} links');
        expect(vpn.dialled, [hel1.pathKey]);
        expect(rows(), ['hel:tcp-reality true']);
      }
    });

    test('a door below the first is checked alone once the shared links '
        'found nothing open, within the time a failed fetch leaves', () async {
      // The own doors have 70 ms. Four at once check all twelve in 60 ms,
      // so the first round checks only d0, which is dead.
      final twelve = rowsOf(12);
      final slow = twelve[1];
      fixed = {
        community.pathKey: tcpTimeout,
        for (final d in twelve)
          if (d != slow) d.pathKey: noAnswer,
      };
      slowOpen = {slow.pathKey};
      final vpn = _FakeVpn({slow.pathKey});
      final f = flow(
        vpn,
        const ChecklistSettings(
          fallback: FallbackSettings(
            links: 1,
            parallel: 1,
            after: Duration(milliseconds: 70),
          ),
          doors: atOnce,
        ),
        online: false,
      );
      // How our servers read while the link is checked: still to come, as
      // their checks alone come after it (clients #342).
      final ownWhileLinks = <StageState>{};
      f.addListener(() {
        if (f.route == RouteKind.community) {
          ownWhileLinks.add(f.stageState(RouteKind.own));
        }
      });

      await f.connect(twelve, shared: () async => [community]);
      await pumpEventQueue();

      expect(f.stage, ConnectStage.done);
      expect(vpn.dialled, [slow.pathKey]);
      expect(ownWhileLinks, {StageState.pending});
      expect(
        probed.indexOf(community.pathKey),
        lessThan(probed.lastIndexOf(slow.pathKey)),
      );
      // Held back while the fetch said no internet, sent once a door was
      // found open, without the rows below it.
      expect(rows(), ['d0:tcp-reality false', 'd1:tcp-reality true']);
    });

    test('an offline phone, whose checks fail at TCP, checks nothing alone '
        'and sends nothing', () async {
      fixed = {
        for (final d in [...four, community]) d.pathKey: tcpTimeout,
      };
      final vpn = _FakeVpn({});
      final f = flow(vpn, fourAtOnce, online: false);

      await f.connect(four, shared: () async => [community]);
      await pumpEventQueue();

      expect(f.stage, ConnectStage.noInternet);
      expect(probed, [...keys(four), community.pathKey]);
      expect(vpn.dialled, isEmpty);
      expect(sent, isEmpty);
    });

    test('doors that take TCP and never answer, as behind a captive portal, '
        'end at no internet with nothing sent', () async {
      fixed = {
        community.pathKey: tcpTimeout,
        for (final d in four) d.pathKey: noAnswer,
      };
      final vpn = _FakeVpn({});
      final f = flow(
        vpn,
        const ChecklistSettings(
          fallback: FallbackSettings(
            links: 1,
            parallel: 1,
            after: Duration(milliseconds: 50),
          ),
          doors: atOnce,
        ),
        online: false,
      );

      await f.connect(four, shared: () async => [community]);
      await pumpEventQueue();

      expect(f.stage, ConnectStage.noInternet);
      expect(vpn.dialled, isEmpty);
      expect(sent, isEmpty);
      // No door is checked alone twice.
      for (final d in four) {
        expect(probed.where((k) => k == d.pathKey).length, lessThan(3));
      }
    });
  });

  group('our own doors first, after a fallback chose the link', () {
    const ownFirstOne = FallbackSettings(links: 1, parallel: 1, ownFirst: 1);

    test('the door that last worked here, read "no answer" beside the link, '
        'keeps its place in the diagnosis', () async {
      // Found 2026-10-12 in review: it went after every other own door, past
      // the search's budget, with door_parallel 4 and with door_parallel 1.
      // 1.7.0 checked it alone at its place and connected.
      checkTime = const Duration(milliseconds: 30);
      final twelve = rowsOf(12);
      final remembered = twelve[1];
      for (final (name, doors) in searches) {
        SharedPreferences.setMockInitialValues({});
        probed = [];
        await PathMemory().remember('mobile:Irancell', remembered.pathKey);
        fixed = {
          community.pathKey: tcpTimeout,
          for (final d in twelve)
            if (d != remembered) d.pathKey: noAnswer,
        };
        slowOpen = {remembered.pathKey};
        final vpn = _FakeVpn({remembered.pathKey});
        final f = flow(
          vpn,
          ChecklistSettings(fallback: ownFirstOne, doors: doors),
          budget: const Duration(milliseconds: 200),
        );

        await f.connect(twelve, picked: community, ownFirst: true);
        await pumpEventQueue();

        expect(f.stage, ConnectStage.done, reason: name);
        // Not on the fast path: it read closed seconds ago.
        expect(vpn.dialled, [remembered.pathKey], reason: name);
        expect(probed.take(2), keys([remembered, community]), reason: name);
      }
    });

    test('a stop while the failure of the door dialled there is written '
        'leaves the tap stopped, not busy', () async {
      // Found 2026-10-12 in review; 1.7.0 had the same gap. The stage stayed
      // at fastPath and the next tap on the button only stopped it.
      await PathMemory().remember('mobile:Irancell', hel1.pathKey);
      fixed = {hel1.pathKey: openAlone, community.pathKey: openAlone};
      final vpn = _FakeVpn({});
      final memory = _StopOnFail();
      final f = flow(
        vpn,
        const ChecklistSettings(fallback: ownFirstOne, doors: atOnce),
        memory: memory,
      );
      memory.onFail = f.cancel;

      await f.connect(four, picked: community, ownFirst: true);
      await pumpEventQueue();

      expect(vpn.dialled, [hel1.pathKey]);
      expect(f.stage, ConnectStage.cancelled);
      expect(f.isBusy, isFalse);
    });
  });
}
