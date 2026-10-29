import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/core/state/connect_flow.dart';
import 'package:fortiva_vpn/data/models/checklist_settings.dart';
import 'package:fortiva_vpn/data/models/server.dart';
import 'package:fortiva_vpn/services/community_checks.dart';
import 'package:fortiva_vpn/services/path_finder.dart';
import 'package:fortiva_vpn/services/path_memory.dart';
import 'package:fortiva_vpn/services/vpn_event_reporter.dart';
import 'package:fortiva_vpn/services/vpn_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The connect flow checks several of the device's own doors at once
/// (DoorCheckSettings), and still dials the door a one-at-a-time search
/// would have dialled.
///
/// One at a time a closed door costs about 3 seconds. In the 24 hours to
/// 01:00 Tehran on 2026-10-12 a checklist reached 7 or 8 of a phone's 19 to
/// 22 doors: 24 of 26 taps that ended at every door closed left doors
/// unchecked, and 15 of 39 first taps the user stopped were stopped during
/// the checks, before any dial.
Server door(String host, String door) => Server(
  id: 'dedicated-$host:443',
  name: host,
  country: '',
  city: host,
  connectionUri: 'vless://u@$host:443?type=tcp#$host',
  flagEmoji: '',
  isDedicated: true,
  door: door,
  doorLabel: door,
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

class _Kept extends CommunityChecks {
  _Kept() : super(platform: 'android');

  @override
  Future<void> report(List<CommunityCheck> checks, {String? carrier}) async {}
}

/// How one door's check goes: open with [ms] or closed, after [after]. A
/// null [after] never answers.
typedef _Answer = ({int ms, Duration? after});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final hel1 = door('hel', 'tcp-reality');
  final hel2 = door('hel', 'xhttp-reality');
  final fsn1 = door('fsn', 'tcp-reality');

  late List<String> probed;
  late Map<String, _Answer> answers;
  // The doors whose checks are running now.
  late Set<String> running;
  late int mostInFlight;
  // The door rows sent, in order. The reporter sends them in batches.
  late List<Map<String, dynamic>> sent;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    probed = [];
    answers = {};
    running = {};
    mostInFlight = 0;
    sent = [];
  });

  _Answer closed(int ms) => (ms: -1, after: Duration(milliseconds: ms));
  _Answer open(int ms, {int after = 1}) =>
      (ms: ms, after: Duration(milliseconds: after));
  const _Answer never = (ms: -1, after: null);

  ConnectFlow flow(
    _FakeVpn vpn,
    ChecklistSettings? checklist, {
    Duration budget = const Duration(seconds: 20),
    Duration probeTimeout = const Duration(seconds: 4),
    void Function(Server door)? onProbe,
  }) => ConnectFlow(
    vpn: vpn,
    memory: PathMemory(),
    finder: PathFinder(
      probe: (p) async {
        probed.add(p.pathKey);
        running.add(p.pathKey);
        if (running.length > mostInFlight) mostInFlight = running.length;
        onProbe?.call(p);
        try {
          final answer = answers[p.pathKey] ?? closed(1);
          // A check that never answers outlives the finder's wait for it.
          await Future<void>.delayed(answer.after ?? probeTimeout * 2);
          return answer.ms;
        } finally {
          running.remove(p.pathKey);
        }
      },
      internet: () async => true,
      budget: budget,
      probeTimeout: probeTimeout,
    ),
    reporter: VpnEventReporter(
      send: (_, _, _) async {},
      sendProbes: (_, probes, _) async => sent.addAll(probes),
      deviceId: () async => 'DEV-1',
      appVersion: () async => '1.7.0',
      platform: 'android',
      networkType: () async => 'mobile',
    ),
    networkKey: () async => 'mobile:Irancell',
    carrier: () async => 'Irancell',
    communityChecks: _Kept(),
    checklist: () => checklist,
    attemptTimeout: const Duration(seconds: 2),
  );

  /// A reported row as "host:door ok".
  List<String> rows(List<Map<String, dynamic>> batch) => [
    for (final r in batch) '${r['server_host']}:${r['door']} ${r['ok']}',
  ];

  test('the tunnel comes up through the first open door in the backend '
      'order, not the first to answer', () async {
    answers = {
      hel1.pathKey: closed(40),
      hel2.pathKey: open(90, after: 5),
      fsn1.pathKey: open(80),
    };
    final vpn = _FakeVpn({hel2.pathKey, fsn1.pathKey});
    final f = flow(
      vpn,
      const ChecklistSettings(
        doors: DoorCheckSettings(parallel: 3, stagger: Duration.zero),
      ),
    );

    await f.connect([hel1, hel2, fsn1], preferred: hel1);
    await pumpEventQueue();

    expect(f.stage, ConnectStage.done);
    expect(vpn.dialled, [hel2.pathKey]);
    expect(mostInFlight, 3);
    // fsn1 was found open too, but one at a time it was never reached, so
    // its row does not go out.
    expect(rows(sent), ['hel:tcp-reality false', 'hel:xhttp-reality true']);
  });

  test('the top door that is open is dialled without waiting for the checks '
      'below it', () async {
    answers = {
      hel1.pathKey: open(120, after: 10),
      hel2.pathKey: never,
      fsn1.pathKey: never,
    };
    final vpn = _FakeVpn({hel1.pathKey});
    final f = flow(
      vpn,
      const ChecklistSettings(
        doors: DoorCheckSettings(parallel: 3, stagger: Duration.zero),
      ),
      probeTimeout: const Duration(milliseconds: 300),
    );

    await f
        .connect([hel1, hel2, fsn1], preferred: hel1)
        .timeout(const Duration(milliseconds: 250));
    await pumpEventQueue();

    expect(f.stage, ConnectStage.done);
    expect(vpn.dialled, [hel1.pathKey]);
    expect(probed, [hel1.pathKey, hel2.pathKey, fsn1.pathKey]);
    expect(rows(sent), ['hel:tcp-reality true']);
  });

  test('with no word from the backend a second door is checked a second '
      'into a slow first one', () async {
    // DoorCheckSettings.standard: four at once, one more each second.
    answers = {hel1.pathKey: closed(1500), hel2.pathKey: open(70, after: 10)};
    Set<String>? runningAtHel2;
    final vpn = _FakeVpn({hel2.pathKey});
    final f = flow(
      vpn,
      null,
      onProbe: (p) {
        if (p == hel2) runningAtHel2 = {...running};
      },
    );

    final started = DateTime.now();
    await f.connect([hel1, hel2, fsn1], preferred: hel1);
    await pumpEventQueue();

    expect(vpn.dialled, [hel2.pathKey]);
    expect(runningAtHel2, {hel1.pathKey, hel2.pathKey});
    // hel2's answer freed its place, so fsn1 was checked beside hel1 too.
    expect(probed, [hel1.pathKey, hel2.pathKey, fsn1.pathKey]);
    expect(mostInFlight, 2);
    // The dial waited for hel1: hel2 is open, but one at a time hel1 came
    // first. fsn1's answer goes nowhere, as one at a time it was never
    // reached.
    expect(
      DateTime.now().difference(started),
      greaterThanOrEqualTo(const Duration(milliseconds: 1500)),
    );
    expect(f.checks.map((c) => c.state), [
      PathCheckState.blocked,
      PathCheckState.open,
      PathCheckState.pending,
    ]);
    expect(rows(sent), ['hel:tcp-reality false', 'hel:xhttp-reality true']);
  });

  group('every own door closed', () {
    final twelve = [for (var i = 0; i < 12; i++) door('d$i', 'tcp-reality')];
    // Each check takes 150 ms of real time. Four at a time the last four
    // start at about 300 ms, which leaves a slow runner room inside the
    // budget. One at a time the eighth door could start only at 1050 ms,
    // after the budget on any runner.
    const budget = Duration(milliseconds: 900);

    test('every one is checked within the budget and reported', () async {
      answers = {for (final d in twelve) d.pathKey: closed(150)};
      final f = flow(
        _FakeVpn({}),
        const ChecklistSettings(
          doors: DoorCheckSettings(parallel: 4, stagger: Duration.zero),
        ),
        budget: budget,
      );

      await f.connect(twelve, preferred: twelve.first);
      await pumpEventQueue();

      expect(f.stage, ConnectStage.nothingOpen);
      expect(probed, [for (final d in twelve) d.pathKey]);
      expect(mostInFlight, 4);
      expect(sent, hasLength(12));
      expect(sent.every((r) => r['ok'] == false), isTrue);
      expect(sent.map((r) => r['attempt_id']).toSet(), hasLength(1));
    });

    test('one at a time the same budget reaches only some of them', () async {
      answers = {for (final d in twelve) d.pathKey: closed(150)};
      final f = flow(
        _FakeVpn({}),
        const ChecklistSettings(doors: DoorCheckSettings.oneAtATime),
        budget: budget,
      );

      await f.connect(twelve, preferred: twelve.first);
      await pumpEventQueue();

      expect(f.stage, ConnectStage.nothingOpen);
      expect(probed.length, inInclusiveRange(3, 7));
      expect(mostInFlight, 1);
      expect(sent, hasLength(probed.length));
    });
  });

  test('with FallbackSettings.after the own doors left after the shared '
      'links are checked several at a time too', () async {
    final own = [for (var i = 0; i < 12; i++) door('d$i', 'tcp-reality')];
    final shared = [
      for (var i = 0; i < 4; i++)
        Server.fromConnectionUri(
          'vless://u@h$i.example:443?type=tcp&security=reality'
          '&sni=www.samsung.com&pbk=key#Link$i',
          index: i,
        ),
    ];
    answers = {
      for (final d in own) d.pathKey: closed(30),
      for (final s in shared) s.pathKey: closed(5),
    };
    final ownKeys = {for (final d in own) d.pathKey};
    var sharedChecked = false;
    var mostOwnAfter = 0;
    final f = flow(
      _FakeVpn({}),
      const ChecklistSettings(
        fallback: FallbackSettings(
          links: 4,
          parallel: 4,
          after: Duration(milliseconds: 50),
        ),
        doors: DoorCheckSettings(parallel: 3, stagger: Duration.zero),
      ),
      onProbe: (p) {
        if (!ownKeys.contains(p.pathKey)) {
          sharedChecked = true;
          return;
        }
        final ownRunning = running.where(ownKeys.contains).length;
        if (sharedChecked && ownRunning > mostOwnAfter) {
          mostOwnAfter = ownRunning;
        }
      },
    );

    await f.connect(own, preferred: own.first, shared: () async => shared);
    await pumpEventQueue();

    expect(f.stage, ConnectStage.nothingOpen);
    final firstShared = probed.indexOf(shared.first.pathKey);
    expect(firstShared, greaterThan(0));
    expect(firstShared, lessThan(own.length));
    expect(mostOwnAfter, 3);
    // Every own door has a result, each checked once, and all of them go
    // out together as one search that found every door closed.
    expect(
      f.checks
          .where((c) => ownKeys.contains(c.path.pathKey))
          .every((c) => c.state == PathCheckState.blocked),
      isTrue,
    );
    expect(probed.where(ownKeys.contains), [for (final d in own) d.pathKey]);
    expect(sent, hasLength(12));
    expect(sent.map((r) => r['server_host']), [for (final d in own) d.name]);
  });

  test('door_parallel 1 is the one-at-a-time search of 1.7.0', () async {
    answers = {
      hel1.pathKey: closed(20),
      hel2.pathKey: open(90),
      fsn1.pathKey: open(80),
    };
    final vpn = _FakeVpn({hel2.pathKey});
    final f = flow(
      vpn,
      ChecklistSettings.fromJson({'door_parallel': 1, 'door_stagger_ms': 0}),
    );

    await f.connect([hel1, hel2, fsn1], preferred: hel1);
    await pumpEventQueue();

    expect(mostInFlight, 1);
    expect(probed, [hel1.pathKey, hel2.pathKey]);
    expect(vpn.dialled, [hel2.pathKey]);
    expect(rows(sent), ['hel:tcp-reality false', 'hel:xhttp-reality true']);
  });
}
