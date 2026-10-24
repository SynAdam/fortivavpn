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

/// Back online by itself, as soon as the internet is (2.2.0).
///
/// In the 72 hours to 2026-10-20 21:00 UTC, 248 of 493 tunnels that stopped
/// carrying data in the middle of a session did so on a phone whose own
/// internet was gone, and those phones were connected again a median of 15
/// minutes later. Three things kept them off:
///
/// - Internet that comes back on the same network brings no change of
///   network, and the waits between tries grow to 10 minutes. Now a wait
///   after no internet asks for the way back every RetrySettings.recheck and
///   tries at once when it is back.
/// - The door the tunnel was on was forgotten, though the phone's network
///   had failed and not the door, so the try once the internet was back
///   started with a whole checklist. Now the fast path's failure is written
///   down only on a phone with internet.
/// - Every try of the wait dialled that door on the fast path, bringing the
///   tunnel up only to fail. Now a try on a phone known to be without
///   internet skips the fast path; the checklist still checks the door.
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

/// The device's doors, in the backend's order.
final paths = [hel1, hel2, fsn1];

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

  const network = 'mobile:Irancell';

  late List<String> probed;
  late Set<String> openHere;
  // Whether a site abroad answers, and whether one inside the country does.
  late bool abroad;
  late bool home;
  // How many times a site abroad was asked, and an answer to hold them on.
  late int abroadAsks;
  Completer<void>? holdAbroad;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    probed = [];
    openHere = {};
    abroad = false;
    home = false;
    abroadAsks = 0;
    holdAbroad = null;
  });

  RetrySettings waits(List<int> ms, {int? longestMs, int? recheckMs}) =>
      RetrySettings(
        after: [for (final m in ms) Duration(milliseconds: m)],
        longest: longestMs == null ? null : Duration(milliseconds: longestMs),
        recheck: recheckMs == null ? null : Duration(milliseconds: recheckMs),
      );

  ConnectFlow flow(_FakeVpn vpn, {RetrySettings? retry}) {
    final f = ConnectFlow(
      vpn: vpn,
      memory: PathMemory(),
      finder: PathFinder(
        read: (p) async {
          probed.add(p.pathKey);
          return openHere.contains(p.pathKey) ? open : closed;
        },
        internet: () async {
          abroadAsks++;
          await holdAbroad?.future;
          return abroad;
        },
        home: () async => home,
        budget: const Duration(milliseconds: 300),
      ),
      reporter: VpnEventReporter(
        send: (_, _, _) async {},
        sendProbes: (_, _, _) async {},
        deviceId: () async => 'DEV-1',
        appVersion: () async => '2.2.0',
        platform: 'android',
        networkType: () async => 'mobile',
      ),
      ipv6: Ipv6Reach(route: () async => null),
      networkKey: () async => network,
      carrier: () async => 'Irancell',
      checklist: () => retry == null ? null : ChecklistSettings(retry: retry),
      random: () => 0.5,
      networkSettle: const Duration(milliseconds: 10),
      attemptTimeout: const Duration(seconds: 2),
    );
    addTearDown(f.cancel);
    return f;
  }

  int checksOf(Server door) => probed.where((k) => k == door.pathKey).length;

  group('a wait after no internet', () {
    test('asks for the way back, and tries at once once it is back', () async {
      final vpn = _FakeVpn({});
      // Only the recheck can bring a try: the wait is a minute long.
      final f = flow(
        vpn,
        retry: waits([60000], longestMs: 60000, recheckMs: 20),
      );

      await f.connect(paths);
      expect(f.waitingAfter, ConnectStage.noInternet);
      expect(checksOf(hel1), 1);

      // A few checks while the phone is still offline: no try.
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(checksOf(hel1), 1);
      expect(abroadAsks, greaterThan(1));

      abroad = true;
      openHere = {hel2.pathKey};
      vpn.works.add(hel2.pathKey);
      await until(() => f.stage == ConnectStage.done);

      expect(f.chosen, hel2);
      expect(checksOf(hel1), 2);
    });

    test('asks after a cut way abroad too', () async {
      home = true;
      final vpn = _FakeVpn({});
      final f = flow(
        vpn,
        retry: waits([60000], longestMs: 60000, recheckMs: 20),
      );

      await f.connect(paths);
      expect(f.waitingAfter, ConnectStage.cutOff);

      abroad = true;
      openHere = {fsn1.pathKey};
      vpn.works.add(fsn1.pathKey);
      await until(() => f.stage == ConnectStage.done);

      expect(f.chosen, fsn1);
    });

    test('a try that finds the doors closed starts the waits over', () async {
      final vpn = _FakeVpn({});
      final f = flow(
        vpn,
        // A long second wait: a try right after the first would show that
        // the waits were not started over.
        retry: waits([60000, 60000], longestMs: 60000, recheckMs: 20),
      );

      await f.connect(paths);
      abroad = true;
      await until(() => checksOf(hel1) == 2);
      await until(() => f.stage == ConnectStage.waiting);

      // Back online with every door closed: the wait does not ask again.
      expect(f.waitingAfter, ConnectStage.nothingOpen);
      final asks = abroadAsks;
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(abroadAsks, asks);
      expect(checksOf(hel1), 2);
    });

    test(
      'asks nothing after every door was closed on a phone with internet',
      () async {
        abroad = true;
        final f = flow(
          _FakeVpn({}),
          retry: waits([60000], longestMs: 60000, recheckMs: 20),
        );

        await f.connect(paths);
        expect(f.waitingAfter, ConnectStage.nothingOpen);
        final asks = abroadAsks;
        await Future<void>.delayed(const Duration(milliseconds: 80));

        expect(abroadAsks, asks);
      },
    );

    test('asks nothing once stopped', () async {
      final f = flow(
        _FakeVpn({}),
        retry: waits([60000], longestMs: 60000, recheckMs: 20),
      );

      await f.connect(paths);
      f.cancel();
      final asks = abroadAsks;
      await Future<void>.delayed(const Duration(milliseconds: 80));

      expect(abroadAsks, asks);
      expect(f.stage, ConnectStage.cancelled);
    });

    test('asks one question at a time', () async {
      final f = flow(
        _FakeVpn({}),
        retry: waits([60000], longestMs: 60000, recheckMs: 10),
      );

      await f.connect(paths);
      final asks = abroadAsks;
      holdAbroad = Completer<void>();
      await Future<void>.delayed(const Duration(milliseconds: 80));

      expect(abroadAsks, asks + 1);
      holdAbroad!.complete();
    });

    test('asks nothing while the backend turns it off', () async {
      final f = flow(_FakeVpn({}), retry: waits([60000], longestMs: 60000));

      await f.connect(paths);
      final asks = abroadAsks;
      await Future<void>.delayed(const Duration(milliseconds: 80));

      expect(abroadAsks, asks);
    });
  });

  group('the door that carried the tunnel before', () {
    setUp(() async => PathMemory().remember(network, hel1.pathKey));

    test('is kept when a tap finds the phone without internet', () async {
      final vpn = _FakeVpn({});
      final f = flow(vpn);

      await f.connect(paths);

      expect(vpn.dialled, [hel1.pathKey]);
      expect(f.stage, ConnectStage.noInternet);
      expect(await PathMemory().recall(network), hel1.pathKey);
      expect(await PathMemory().failedToday(network), isEmpty);
    });

    test('is still written down as failed on a phone with internet', () async {
      abroad = true;
      openHere = {hel2.pathKey};
      final vpn = _FakeVpn({hel2.pathKey});
      final f = flow(vpn);

      await f.connect(paths);

      expect(vpn.dialled, [hel1.pathKey, hel2.pathKey]);
      expect(f.stage, ConnectStage.done);
      expect(await PathMemory().recall(network), hel2.pathKey);
      expect(await PathMemory().failedToday(network), contains(hel1.pathKey));
    });

    test('the tries of the wait check it and dial nothing while the phone has '
        'no internet', () async {
      final vpn = _FakeVpn({});
      final f = flow(vpn, retry: waits([5, 5, 5]));

      await f.connect(paths);
      await until(() => checksOf(hel1) == 4);
      await until(() => f.stage == ConnectStage.noInternet);

      // Only the tap dialled it. Each try of the wait checked it with the
      // others, with no tunnel brought up.
      expect(vpn.dialled, [hel1.pathKey]);
      expect(await PathMemory().recall(network), hel1.pathKey);
    });

    test('is dialled first by the try once the way is back', () async {
      final vpn = _FakeVpn({});
      final f = flow(
        vpn,
        retry: waits([60000], longestMs: 60000, recheckMs: 20),
      );

      await f.connect(paths);
      expect(vpn.dialled, [hel1.pathKey]);

      abroad = true;
      vpn.works.add(hel1.pathKey);
      await until(() => f.stage == ConnectStage.done);

      // On the fast path, with no checklist before it.
      expect(vpn.dialled, [hel1.pathKey, hel1.pathKey]);
      expect(f.chosen, hel1);
      expect(checksOf(hel1), 1);
    });

    test('a search after a dead tunnel on a phone without internet skips the '
        'fast path', () async {
      final vpn = _FakeVpn({});
      final f = flow(vpn);

      f.noteOffline();
      await f.connect(paths, afterStall: true);

      expect(vpn.dialled, isEmpty);
      expect(checksOf(hel1), 1);
      expect(f.stage, ConnectStage.noInternet);
    });

    test('a tap dials it again whatever the last try found', () async {
      final vpn = _FakeVpn({});
      final f = flow(vpn);

      f.noteOffline();
      await f.connect(paths, afterStall: true);
      f.reset();
      await f.connect(paths);

      expect(vpn.dialled, [hel1.pathKey]);
    });

    test('another network brings the fast path back', () async {
      final changes = StreamController<String>.broadcast();
      addTearDown(changes.close);
      final vpn = _FakeVpn({});
      final f = ConnectFlow(
        vpn: vpn,
        memory: PathMemory(),
        finder: PathFinder(
          read: (p) async => openHere.contains(p.pathKey) ? open : closed,
          internet: () async => abroad,
          home: () async => home,
          budget: const Duration(milliseconds: 300),
        ),
        reporter: VpnEventReporter(
          send: (_, _, _) async {},
          sendProbes: (_, _, _) async {},
          deviceId: () async => 'DEV-1',
          appVersion: () async => '2.2.0',
          platform: 'android',
          networkType: () async => 'mobile',
        ),
        ipv6: Ipv6Reach(route: () async => null),
        networkKey: () async => network,
        carrier: () async => 'Irancell',
        checklist: () =>
            ChecklistSettings(retry: waits([60000], longestMs: 60000)),
        networkChanges: () => changes.stream,
        random: () => 0.5,
        networkSettle: const Duration(milliseconds: 10),
        attemptTimeout: const Duration(seconds: 2),
      );
      addTearDown(f.cancel);

      await f.connect(paths);
      expect(vpn.dialled, [hel1.pathKey]);

      // Off mobile data and back on: the memory of this network is the
      // same, and its door is dialled again.
      vpn.works.add(hel1.pathKey);
      abroad = true;
      changes.add('none');
      changes.add(network);
      await until(() => f.stage == ConnectStage.done);

      expect(vpn.dialled, [hel1.pathKey, hel1.pathKey]);
    });
  });
}
