import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/core/state/connect_flow.dart';
import 'package:fortiva_vpn/data/models/checklist_settings.dart';
import 'package:fortiva_vpn/data/models/server.dart';
import 'package:fortiva_vpn/services/connect_trace.dart';
import 'package:fortiva_vpn/services/ipv6_reach.dart';
import 'package:fortiva_vpn/services/path_finder.dart';
import 'package:fortiva_vpn/services/path_memory.dart';
import 'package:fortiva_vpn/services/vpn_event_reporter.dart';
import 'package:fortiva_vpn/services/vpn_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// No timed tries while the phone has no network at all.
///
/// A tap that ends without a tunnel tries again by itself after each of
/// the backend's waits (RetrySettings). With no Wi-Fi and no mobile data
/// every route fails at once, and each of those tries leaves a trace that
/// says no internet. On the four Tehran days to 2026-10-23, 1,409 taps that
/// came within 12 minutes of a failed one started with no network: 1,350
/// ended at no internet and 31 connected.
///
/// Now a try the wait's timer starts is skipped while the phone has no
/// network, unless the longest wait (RetrySettings.longest, the backend's
/// retry_longest_seconds) has passed since the last try began. The network
/// is still watched, so one that comes back tries at once. A tap on the
/// button is never skipped: 58 of 374 first taps with no network connected.
Server own(String host, String door, int row) => Server.fromDedicatedPath(
  uri:
      'vless://u@$host:8443?type=tcp&security=reality'
      '&sni=www.samsung.com&pbk=key#Row$row',
  door: door,
  doorLabel: door,
  serverId: row,
);

final hel1 = own('203.0.113.226', 'tcp-reality', 13);
final fsn1 = own('203.0.113.227', 'tcp-reality', 14);
final paths = [hel1, fsn1];

const open = DoorOutcome(ms: 120, tcpMs: 40, phase: 'ok');
const closed = DoorOutcome(ms: -1, error: 'tcp unreachable', phase: 'tcp');

/// A tunnel that comes up through the doors in [works], and fails through
/// everything else.
class _FakeVpn extends VpnService {
  _FakeVpn(this.works)
    : super(events: VpnEventReporter(send: (_, _, _) async {}));

  final Set<String> works;
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

/// Counts the tries: each one starts a trace.
class _Tries extends ConnectTraces {
  _Tries() : super(enabled: () => true);

  final at = <DateTime>[];

  @override
  ConnectTrace? start(String attemptId) {
    at.add(DateTime.now());
    return ConnectTrace(attemptId: attemptId, startedAt: DateTime.now());
  }

  @override
  Future<void> send(ConnectTrace trace) async {}
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

  /// What the platform says the phone is on, as ConnectFlow names it.
  late String network;
  late bool online;
  late StreamController<String> changes;
  late _Tries tries;
  late _FakeVpn vpn;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    network = 'none';
    online = false;
    changes = StreamController<String>.broadcast();
    tries = _Tries();
    vpn = _FakeVpn({});
  });

  tearDown(() => changes.close());

  /// The backend's waits: 10 ms, three times, then twice the one before up
  /// to [longestMs]. Null [longestMs] stops after the three, as the backend
  /// says with retry_longest_seconds 0.
  ConnectFlow flow({int? longestMs = 400}) {
    final f = ConnectFlow(
      vpn: vpn,
      memory: PathMemory(),
      finder: PathFinder(
        read: (p) async =>
            online && vpn.works.contains(p.pathKey) ? open : closed,
        internet: () async => online,
        home: () async => online,
        budget: const Duration(milliseconds: 200),
      ),
      reporter: VpnEventReporter(
        send: (_, _, _) async {},
        sendProbes: (_, _, _) async {},
        deviceId: () async => 'DEV-1',
        appVersion: () async => '2.2.0',
        platform: 'android',
        networkType: () async => network == 'none' ? null : network,
        queues: const [],
      ),
      ipv6: Ipv6Reach(route: () async => null),
      networkKey: () async => network,
      carrier: () async => null,
      checklist: () => ChecklistSettings(
        retry: RetrySettings(
          after: const [
            Duration(milliseconds: 10),
            Duration(milliseconds: 10),
            Duration(milliseconds: 10),
          ],
          longest: longestMs == null ? null : Duration(milliseconds: longestMs),
        ),
      ),
      traces: tries,
      networkChanges: () => changes.stream,
      random: () => 0.5,
      networkSettle: const Duration(milliseconds: 10),
      attemptTimeout: const Duration(seconds: 2),
    );
    addTearDown(f.cancel);
    return f;
  }

  test('with no network, the tap on the button tries, and the timed tries '
      'wait for the longest wait to pass since it', () async {
    // Long enough that it does not pass before the checks below, even when
    // the test stalls for a few hundred ms.
    final f = flow(longestMs: 800);

    await f.connect(paths);
    expect(tries.at, hasLength(1));
    expect(f.stage, ConnectStage.waiting);
    expect(f.waitingAfter, ConnectStage.noInternet);

    // The backend's waits would have made six tries by now.
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(tries.at, hasLength(1));
    // Still waiting, and the screen still says why.
    expect(f.stage, ConnectStage.waiting);
    expect(f.waitingAfter, ConnectStage.noInternet);

    await until(() => tries.at.length == 2);
    final gap = tries.at[1].difference(tries.at[0]);
    expect(gap, greaterThanOrEqualTo(const Duration(milliseconds: 790)));
    // A skipped try waits no longer than the rest of the longest wait. One
    // that waited its whole next wait would try at 1,290 ms or later.
    expect(gap, lessThan(const Duration(milliseconds: 1200)));
  });

  test('then one try for each longest wait, for as long as there is no '
      'network', () async {
    final f = flow(longestMs: 150);

    await f.connect(paths);
    await until(() => tries.at.length == 4, within: const Duration(seconds: 2));

    for (var i = 1; i < tries.at.length; i++) {
      expect(
        tries.at[i].difference(tries.at[i - 1]),
        greaterThanOrEqualTo(const Duration(milliseconds: 140)),
      );
    }
    expect(f.stage, ConnectStage.waiting);
  });

  test(
    'a network that comes back tries at once, and the waits start over',
    () async {
      final f = flow(longestMs: 5000);

      await f.connect(paths);
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(tries.at, hasLength(1));

      // Mobile data comes back, and with it the internet and a door.
      final back = DateTime.now();
      network = 'mobile';
      online = true;
      vpn.works.add(hel1.pathKey);
      changes.add('mobile');
      await until(() => f.stage == ConnectStage.done);

      expect(tries.at, hasLength(2));
      expect(
        tries.at[1].difference(back),
        lessThan(const Duration(milliseconds: 500)),
      );
    },
  );

  test('with a network, the timed tries run as before, even with no '
      'internet', () async {
    network = 'mobile';
    final f = flow();

    await f.connect(paths);
    // The tap and its three tries after 10 ms each, at least.
    await until(() => tries.at.length >= 4, within: const Duration(seconds: 2));
    expect(
      tries.at[3].difference(tries.at[0]),
      lessThan(const Duration(milliseconds: 300)),
    );
    expect(f.waitingAfter, ConnectStage.noInternet);
  });

  test(
    'a network that goes away while it waits stops the timed tries',
    () async {
      network = 'mobile';
      final f = flow();

      await f.connect(paths);
      await until(() => tries.at.length >= 2);
      network = 'none';
      changes.add('none');
      final seen = tries.at.length;
      await Future<void>.delayed(const Duration(milliseconds: 200));

      // At most the try that had started when the network went.
      expect(tries.at.length, lessThanOrEqualTo(seen + 1));
      expect(f.stage, ConnectStage.waiting);
    },
  );

  test('with no longest wait the waits end after the backend\'s list, and '
      'none is skipped', () async {
    final f = flow(longestMs: null);

    await f.connect(paths);
    await until(() => tries.at.length == 4);
    await Future<void>.delayed(const Duration(milliseconds: 100));

    expect(tries.at, hasLength(4));
    expect(f.stage, ConnectStage.noInternet);
  });

  test('a stop while a timed try is skipped ends the wait for good', () async {
    final f = flow(longestMs: 150);

    await f.connect(paths);
    // A skipped try moves the countdown on screen. The stop comes in the
    // first one.
    var at = f.retryAt;
    int? seen;
    void stopInSkip() {
      final next = f.retryAt;
      final skipped = at != null && next != null && next != at;
      at = next;
      if (!skipped || seen != null) return;
      seen = tries.at.length;
      f.cancel();
    }

    f.addListener(stopInSkip);
    await until(() => seen != null);
    f.removeListener(stopInSkip);
    // Past the longest wait, when the skipped try would have started.
    await Future<void>.delayed(const Duration(milliseconds: 300));

    // No try after the stop.
    expect(tries.at, hasLength(seen!));
    expect(f.stage, ConnectStage.cancelled);
  });
}
