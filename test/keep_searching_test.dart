import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/core/state/connect_flow.dart';
import 'package:fortiva_vpn/data/models/checklist_settings.dart';
import 'package:fortiva_vpn/data/models/server.dart';
import 'package:fortiva_vpn/services/ipv6_reach.dart';
import 'package:fortiva_vpn/services/path_finder.dart';
import 'package:fortiva_vpn/services/path_memory.dart';
import 'package:fortiva_vpn/services/vpn_event_reporter.dart';
import 'package:fortiva_vpn/services/vpn_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Keep searching when only the way abroad is cut (clients #269, part of
/// the blackout epic #267).
///
/// Until 1.9.0 the app read "no internet" from two control sites abroad,
/// Google's and Cloudflare's. In a cut like Iran's of June 2025, where the
/// national network stayed up and the way abroad was cut at the gateway,
/// both fail on a phone whose network works. The tap then stopped door
/// checks 8 seconds in, ended at "no internet", and never tried again.
///
/// Now a site inside the country is asked once the sites abroad failed.
/// When it answers, every door gets its whole search, the tap ends at "cut
/// off", and it keeps trying until data flows: past the backend's waits,
/// each wait twice the one before, up to RetrySettings.longest. Rows still
/// go nowhere and nothing is written down: with the way abroad cut every
/// door fails, which says nothing about any one of them.
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

/// Where the backend moved [fsn1]'s server once its address was blocked.
final fsnMoved = own('203.0.113.228', 'tcp-reality', 14);

/// The device's doors, in the backend's order.
final paths = [hel1, hel2, fsn1];

/// Links from public channels, for a phone with no servers of its own.
final picked = Server.fromConnectionUri(
  'vless://u@h1.example:443?type=tcp&security=reality'
  '&sni=www.samsung.com&pbk=key#Link1',
);
final other = Server.fromConnectionUri(
  'vless://u@h2.example:443?type=tcp&security=reality'
  '&sni=www.samsung.com&pbk=key#Link2',
);

const open = DoorOutcome(ms: 120, tcpMs: 40, phase: 'ok');
const closed = DoorOutcome(
  ms: -1,
  error: 'tcp timeout; no answer in 3000 ms',
  phase: 'tcp',
);

/// A tunnel that comes up through the links in [works], and fails through
/// everything else.
class _FakeVpn extends VpnService {
  _FakeVpn(this.works)
    : super(events: VpnEventReporter(send: (_, _, _) async {}));

  final Set<String> works;
  final dialled = <String>[];
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
    active = server;
    _fakeStatus = VpnStatus.connecting;
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 2));
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const network = 'mobile';

  late List<String> probed;
  late Set<String> openHere;
  late bool abroad;
  late bool? home;
  late int homeAsks;
  late Duration probeTime;
  late List<List<Map<String, dynamic>>> reported;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    probed = [];
    openHere = {};
    abroad = false;
    home = true;
    homeAsks = 0;
    probeTime = Duration.zero;
    reported = [];
  });

  ConnectFlow flow(
    _FakeVpn vpn, {
    ChecklistSettings? checklist,
    Stream<String> Function()? networkChanges,
  }) {
    final f = ConnectFlow(
      vpn: vpn,
      memory: PathMemory(),
      finder: PathFinder(
        read: (p) async {
          probed.add(p.pathKey);
          if (probeTime > Duration.zero) await Future.delayed(probeTime);
          return openHere.contains(p.pathKey) ? open : closed;
        },
        internet: () async => abroad,
        home: home == null
            ? null
            : () async {
                homeAsks++;
                return home!;
              },
        budget: const Duration(milliseconds: 300),
      ),
      reporter: VpnEventReporter(
        send: (_, _, _) async {},
        sendProbes: (_, probes, _) async => reported.add(probes),
        deviceId: () async => 'DEV-1',
        appVersion: () async => '1.9.0',
        platform: 'android',
        networkType: () async => 'mobile',
      ),
      ipv6: Ipv6Reach(route: () async => null),
      networkKey: () async => network,
      carrier: () async => null,
      checklist: () => checklist,
      networkChanges: networkChanges,
      // The long waits keep their length, so the tests can count tries.
      random: () => 0.5,
      networkSettle: const Duration(milliseconds: 10),
      attemptTimeout: const Duration(seconds: 2),
    );
    addTearDown(f.cancel);
    return f;
  }

  List<String> keys(Iterable<Server> servers) => [
    for (final s in servers) s.pathKey,
  ];

  int triesOf(Server door) => probed.where((k) => k == door.pathKey).length;

  group('a cut way abroad', () {
    test('every door is checked, nothing is sent or written down, and the '
        'tap ends at cut off', () async {
      final vpn = _FakeVpn({});
      final f = flow(vpn);

      await f.connect(paths);
      await pumpEventQueue();

      expect(f.stage, ConnectStage.cutOff);
      expect(f.internet, isFalse);
      expect(f.cut, isTrue);
      expect(probed, keys(paths));
      expect(vpn.dialled, isEmpty);
      expect(reported, isEmpty);
      expect(await PathMemory().failedToday(network), isEmpty);
    });

    test('the site inside the country is asked only once the sites abroad '
        'failed', () async {
      abroad = true;
      final f = flow(_FakeVpn({}));

      await f.connect(paths);
      await pumpEventQueue();

      expect(homeAsks, 0);
      expect(f.stage, ConnectStage.nothingOpen);
      expect(f.cut, isNull);
    });

    test('nothing inside the country either: no internet, as before', () async {
      home = false;
      final f = flow(_FakeVpn({}));

      await f.connect(paths);
      await pumpEventQueue();

      expect(homeAsks, 1);
      expect(f.stage, ConnectStage.noInternet);
      expect(f.cut, isFalse);
    });

    test('a door that is open carries the tunnel, and its rows go out: the '
        'phone has internet after all', () async {
      openHere = {fsn1.pathKey};
      final vpn = _FakeVpn({fsn1.pathKey});
      final f = flow(vpn);

      await f.connect(paths);
      await pumpEventQueue();

      expect(f.stage, ConnectStage.done);
      expect(f.chosen, fsn1);
      expect([for (final b in reported) ...b].map((r) => r['ok']), [
        false,
        false,
        true,
      ]);
    });

    group('with FallbackSettings.after', () {
      final checklist = ChecklistSettings(
        fallback: FallbackSettings(
          links: 4,
          parallel: 2,
          after: const Duration(milliseconds: 30),
        ),
      );

      setUp(() => probeTime = const Duration(milliseconds: 20));

      test('no internet stops the doors after it', () async {
        home = false;
        final f = flow(_FakeVpn({}), checklist: checklist);

        await f.connect(paths);
        await pumpEventQueue();

        expect(probed.length, lessThan(paths.length));
        expect(f.stage, ConnectStage.noInternet);
      });

      test('a cut way abroad leaves every door its check, and the last one '
          'carries the tunnel', () async {
        openHere = {fsn1.pathKey};
        final vpn = _FakeVpn({fsn1.pathKey});
        final f = flow(vpn, checklist: checklist);

        await f.connect(paths, shared: () async => const []);
        await pumpEventQueue();

        expect(probed, keys(paths));
        expect(f.stage, ConnectStage.done);
        expect(f.chosen, fsn1);
      });
    });

    test('a phone with no servers of its own ends at cut off once the pick '
        'and the shared links failed', () async {
      final vpn = _FakeVpn({});
      final f = flow(vpn);

      await f.connectShared(picked, shared: () async => [other]);
      await pumpEventQueue();

      // The pick is checked, found closed and not dialled.
      expect(vpn.dialled, isEmpty);
      expect(probed, [picked.pathKey, other.pathKey]);
      expect(f.stage, ConnectStage.cutOff);
    });
  });

  group('keep searching', () {
    RetrySettings waits(List<int> ms, {int? longestMs}) => RetrySettings(
      after: [for (final m in ms) Duration(milliseconds: m)],
      longest: longestMs == null ? null : Duration(milliseconds: longestMs),
    );

    test('after a cut it waits, and the screen can say why', () async {
      final f = flow(
        _FakeVpn({}),
        checklist: ChecklistSettings(retry: waits([5000])),
      );

      await f.connect(paths);

      expect(f.stage, ConnectStage.waiting);
      expect(f.waitingAfter, ConnectStage.cutOff);
      expect(f.isBusy, isTrue);
    });

    test('after no internet it tries again too', () async {
      home = false;
      final f = flow(
        _FakeVpn({}),
        checklist: ChecklistSettings(retry: waits([10])),
      );

      await f.connect(paths);
      expect(f.waitingAfter, ConnectStage.noInternet);
      await until(() => f.stage == ConnectStage.noInternet);

      expect(triesOf(hel1), 2);
    });

    test('past the backend\'s waits it goes on trying, and connects with no '
        'tap once a way opens', () async {
      final vpn = _FakeVpn({});
      final f = flow(
        vpn,
        checklist: ChecklistSettings(retry: waits([5], longestMs: 20)),
      );

      await f.connect(paths);
      // Four tries past the one wait the backend gave.
      await until(() => triesOf(hel1) >= 5);
      expect(f.isBusy, isTrue);

      // The way through opens.
      openHere = {hel2.pathKey};
      vpn.works.add(hel2.pathKey);
      await until(() => f.stage == ConnectStage.done);

      expect(f.chosen, hel2);
      final tries = triesOf(hel1);
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(triesOf(hel1), tries, reason: 'connected, so no more tries');
    });

    test('without a longest wait it stops after the backend\'s waits, as '
        'before', () async {
      final f = flow(
        _FakeVpn({}),
        checklist: ChecklistSettings(retry: waits([5, 5])),
      );

      await f.connect(paths);
      await until(() => f.stage == ConnectStage.cutOff);
      await Future<void>.delayed(const Duration(milliseconds: 40));

      expect(f.stage, ConnectStage.cutOff);
      expect(triesOf(hel1), 3);
    });

    test('each try dials the doors as they stand then', () async {
      var current = paths;
      openHere = {fsnMoved.pathKey};
      final vpn = _FakeVpn({fsnMoved.pathKey});
      final f = flow(vpn, checklist: ChecklistSettings(retry: waits([5])));

      await f.connect(
        paths,
        latest: () => current,
        // The backend moved [fsn1]'s server while the tap waited.
        beforeRetry: () async => current = [hel1, hel2, fsnMoved],
      );
      await until(() => f.stage == ConnectStage.done);

      expect(f.chosen, fsnMoved);
      expect(vpn.dialled, [fsnMoved.pathKey]);
    });

    test('a stop while it waits ends it, and the network is no longer '
        'watched', () async {
      final changes = StreamController<String>.broadcast();
      addTearDown(changes.close);
      final f = flow(
        _FakeVpn({}),
        checklist: ChecklistSettings(retry: waits([20], longestMs: 20)),
        networkChanges: () => changes.stream,
      );

      await f.connect(paths);
      expect(changes.hasListener, isTrue);
      f.cancel();
      final before = probed.length;
      await Future<void>.delayed(const Duration(milliseconds: 60));

      expect(f.stage, ConnectStage.cancelled);
      expect(probed, hasLength(before));
      expect(changes.hasListener, isFalse);
    });

    test('a move to another network tries at once, and the waits start '
        'over', () async {
      final changes = StreamController<String>.broadcast();
      addTearDown(changes.close);
      final f = flow(
        _FakeVpn({}),
        // The first wait is long enough that only a change of network brings
        // a try. The second is short: a try after the change that did not
        // start the waits over would come at once.
        checklist: ChecklistSettings(
          retry: waits([60000, 5], longestMs: 60000),
        ),
        networkChanges: () => changes.stream,
      );

      await f.connect(paths);
      expect(triesOf(hel1), 1);

      // The network the phone is on, and a lost one: no try.
      changes.add(network);
      changes.add('none');
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(triesOf(hel1), 1);

      // Back on mobile data after none, then on wifi: a try each time.
      changes.add(network);
      await until(() => triesOf(hel1) == 2);
      await until(() => f.stage == ConnectStage.waiting);
      // The first wait again, not the short second one.
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(triesOf(hel1), 2);
      changes.add('wifi');
      await until(() => triesOf(hel1) == 3);
      await until(() => f.stage == ConnectStage.waiting);
      expect(f.waitingAfter, ConnectStage.cutOff);
    });
  });

  group('RetrySettings', () {
    test('past its list each wait is twice the one before, up to the '
        'longest', () {
      const r = RetrySettings(
        after: [Duration(seconds: 5), Duration(seconds: 30)],
        longest: Duration(minutes: 3),
      );
      expect(
        [for (var i = 0; i < 7; i++) r.waitBefore(i)?.inSeconds],
        [5, 30, 60, 120, 180, 180, 180],
      );
    });

    test('without a longest wait there is no try past the list', () {
      const r = RetrySettings(after: [Duration(seconds: 5)]);
      expect(r.waitBefore(0), const Duration(seconds: 5));
      expect(r.waitBefore(1), isNull);
    });

    test('the built-in waits are the backend\'s default, then up to ten '
        'minutes', () {
      const r = RetrySettings.standard;
      expect(
        [for (var i = 0; i < 10; i++) r.waitBefore(i)?.inSeconds],
        [5, 10, 20, 30, 60, 120, 240, 480, 600, 600],
      );
    });
  });
}
