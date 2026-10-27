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

/// Each run's trace says what started it.
///
/// Every automatic try, every try after a change of network or a recheck,
/// and every search after a dead tunnel gets its own attempt id and its own
/// trace, the same as a tap on Connect. In the 7 days to 2026-10-27 the
/// Networks card counted 2,669 failed taps, and 526 to 838 of them were the
/// app's own tries by the rules a person could guess at. Nothing the app
/// sent said which, so the card's rate could not be read as what people
/// feel. Now the trace's head carries `trigger`.
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

/// A link off the public list.
final shared = Server(
  id: 'shared-1',
  name: 'Shared',
  country: '',
  city: '',
  connectionUri:
      'vless://s@198.51.100.205:443?type=tcp&security=reality'
      '&sni=www.samsung.com&pbk=key#Shared',
  flagEmoji: '',
);

const closed = DoorOutcome(ms: -1, error: 'tcp unreachable', phase: 'tcp');

/// A tunnel that never comes up.
class _FakeVpn extends VpnService {
  _FakeVpn() : super(events: VpnEventReporter(send: (_, _, _) async {}));

  VpnStatus _fakeStatus = VpnStatus.disconnected;

  @override
  VpnStatus get status => _fakeStatus;

  @override
  bool get isConnected => false;

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
    _fakeStatus = VpnStatus.error;
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

/// Keeps every trace a run started, in order.
class _Kept extends ConnectTraces {
  _Kept() : super(enabled: () => true);

  final started = <ConnectTrace>[];

  List<TraceTrigger?> get triggers => [for (final t in started) t.trigger];

  @override
  ConnectTrace? start(String attemptId) {
    final trace = ConnectTrace(attemptId: attemptId, startedAt: DateTime.now());
    started.add(trace);
    return trace;
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

  late String network;
  late bool online;
  late StreamController<String> changes;
  late _Kept kept;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    network = 'mobile';
    online = true;
    changes = StreamController<String>.broadcast();
    kept = _Kept();
  });

  tearDown(() => changes.close());

  /// Every door closed. [retry] null makes no try after the first.
  ConnectFlow flow({RetrySettings? retry}) {
    final f = ConnectFlow(
      vpn: _FakeVpn(),
      memory: PathMemory(),
      finder: PathFinder(
        read: (_) async => closed,
        internet: () async => online,
        home: () async => online,
        budget: const Duration(milliseconds: 200),
      ),
      reporter: VpnEventReporter(
        send: (_, _, _) async {},
        sendProbes: (_, _, _) async {},
        deviceId: () async => 'DEV-1',
        appVersion: () async => '2.3.0',
        platform: 'android',
        networkType: () async => network,
        queues: const [],
      ),
      ipv6: Ipv6Reach(route: () async => null),
      networkKey: () async => network,
      carrier: () async => null,
      checklist: () => ChecklistSettings(retry: retry),
      traces: kept,
      networkChanges: () => changes.stream,
      random: () => 0.5,
      networkSettle: const Duration(milliseconds: 10),
      attemptTimeout: const Duration(seconds: 2),
    );
    addTearDown(f.cancel);
    return f;
  }

  /// Two short waits, and no try after them.
  const twoTries = RetrySettings(
    after: [Duration(milliseconds: 10), Duration(milliseconds: 10)],
  );

  /// One wait long enough that its timer never runs in a test.
  const longWait = RetrySettings(after: [Duration(seconds: 30)]);

  test('a tap on Connect is a tap, and each try after a wait is a '
      'retry', () async {
    final f = flow(retry: twoTries);

    await f.connect(paths);
    await until(() => f.stage == ConnectStage.nothingOpen);

    expect(kept.triggers, [
      TraceTrigger.tap,
      TraceTrigger.retry,
      TraceTrigger.retry,
    ]);
    // One attempt id per run.
    expect({for (final t in kept.started) t.attemptId}, hasLength(3));
  });

  test('a pick is a pick, and the tries after it are retries', () async {
    final f = flow(retry: twoTries);

    await f.connect(paths, trigger: TraceTrigger.pick);
    await until(() => f.stage == ConnectStage.nothingOpen);

    expect(kept.triggers, [
      TraceTrigger.pick,
      TraceTrigger.retry,
      TraceTrigger.retry,
    ]);
  });

  test('the search after a dead tunnel is a stall, whatever the caller '
      'says, and the tries after it are retries', () async {
    final f = flow(retry: twoTries);

    await f.connect(paths, afterStall: true, trigger: TraceTrigger.pick);
    await until(() => f.stage == ConnectStage.nothingOpen);

    expect(kept.triggers, [
      TraceTrigger.stall,
      TraceTrigger.retry,
      TraceTrigger.retry,
    ]);
  });

  test('a change of network during the wait tries at once, as a network '
      'try', () async {
    final f = flow(retry: longWait);

    await f.connect(paths);
    expect(f.stage, ConnectStage.waiting);
    // The wait has read the network it started on.
    await Future<void>.delayed(const Duration(milliseconds: 20));

    network = 'wifi';
    changes.add('wifi');
    await until(() => kept.started.length == 2);

    expect(kept.triggers, [TraceTrigger.tap, TraceTrigger.network]);
  });

  test('a site abroad that answers again during the wait after no internet '
      'tries at once, as a recheck', () async {
    online = false;
    final f = flow(
      retry: const RetrySettings(
        after: [Duration(seconds: 30)],
        recheck: Duration(milliseconds: 20),
      ),
    );

    await f.connect(paths);
    expect(f.stage, ConnectStage.waiting);
    expect(f.waitingAfter, ConnectStage.noInternet);

    online = true;
    await until(() => kept.started.length == 2);

    expect(kept.triggers, [TraceTrigger.tap, TraceTrigger.recheck]);
  });

  test('a phone with no servers of its own: a tap, a pick and the search '
      'after a dead tunnel say so too', () async {
    final f = flow();
    Future<List<Server>> none() async => const [];

    await f.connectShared(shared, shared: none);
    await f.connectShared(shared, shared: none, trigger: TraceTrigger.pick);
    await f.connectShared(shared, shared: none, afterStall: true);

    expect(kept.triggers, [
      TraceTrigger.tap,
      TraceTrigger.pick,
      TraceTrigger.stall,
    ]);
  });

  test('the trigger goes in the head of the trace the backend gets', () async {
    final f = flow(retry: twoTries);

    await f.connect(paths, trigger: TraceTrigger.pick);
    await until(() => f.stage == ConnectStage.nothingOpen);

    final heads = [
      for (final t in kept.started)
        for (final item in await t.items()) item['trigger'],
    ];
    expect(heads.toSet(), {'pick', 'retry'});
    expect(heads.first, 'pick');
  });
}
