import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/core/state/connect_flow.dart';
import 'package:fortiva_vpn/data/models/checklist_settings.dart';
import 'package:fortiva_vpn/data/models/server.dart';
import 'package:fortiva_vpn/services/connect_trace.dart';
import 'package:fortiva_vpn/services/ipv6_reach.dart';
import 'package:fortiva_vpn/services/path_finder.dart';
import 'package:fortiva_vpn/services/path_memory.dart';
import 'package:fortiva_vpn/services/recent_taps.dart';
import 'package:fortiva_vpn/services/vpn_event_reporter.dart';
import 'package:fortiva_vpn/services/vpn_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// How the latest taps ended, for the support chat (clients C4 of the plan
/// of 2026-10-23).
///
/// The chat's facts counted only the taps whose traces had reached the
/// backend, and a stuck phone sends those late. The app keeps its own
/// record of each run's outcome, the trace's word for it, whether or not
/// the backend has the trace on, and sends it with a message.
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

const _closed = DoorOutcome(
  ms: -1,
  error: 'tcp timeout; no answer in 3000 ms',
  phase: 'tcp',
);
const _open = DoorOutcome(ms: 120, tcpMs: 40, phase: 'ok');

/// A tunnel that comes up through the doors in [works].
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

  group('the record', () {
    late DateTime now;
    late RecentTaps taps;

    setUp(() {
      now = DateTime.utc(2026, 10, 24, 8);
      taps = RecentTaps(clock: () => now);
    });

    test('gives each tap its age, how long it ran and how it ended, newest '
        'first, and no outcome for one still running', () {
      final first = taps.began();
      now = now.add(const Duration(seconds: 25));
      taps.ended(first, TraceOutcome.allClosed);
      now = now.add(const Duration(seconds: 35));
      final second = taps.began();
      now = now.add(const Duration(seconds: 12));
      taps.ended(second, TraceOutcome.stopped);
      // A later end changes nothing.
      now = now.add(const Duration(seconds: 3));
      taps.ended(second, TraceOutcome.connected);
      taps.began();
      now = now.add(const Duration(seconds: 5));

      expect(taps.toContext(), [
        {'ago_s': 5, 'took_s': 5},
        {'ago_s': 20, 'took_s': 12, 'outcome': 'stopped'},
        {'ago_s': 80, 'took_s': 25, 'outcome': 'all_closed'},
      ]);
    });

    test('keeps the 20 newest taps, of any age: the backend decides which '
        'are recent', () {
      for (var i = 0; i < 30; i++) {
        taps.ended(taps.began(), TraceOutcome.noInternet);
        now = now.add(const Duration(minutes: 1));
      }
      final kept = taps.toContext();
      expect(kept, hasLength(RecentTaps.keep));
      expect(RecentTaps.keep, 20);
      expect(kept.first['ago_s'], 60);
      expect(kept.last['ago_s'], 20 * 60);

      now = now.add(const Duration(days: 2));
      expect(taps.toContext(), hasLength(20));
    });

    test('leaves out a tap that began after now, as when the network '
        'moved the phone clock back', () {
      taps.ended(taps.began(), TraceOutcome.allClosed);
      now = now.add(const Duration(minutes: 10));
      taps.ended(taps.began(), TraceOutcome.noInternet);
      // The network corrects a clock that ran 30 minutes fast.
      now = now.subtract(const Duration(minutes: 30));
      taps.ended(taps.began(), TraceOutcome.stopped);
      now = now.add(const Duration(seconds: 40));

      expect(taps.toContext(), [
        {'ago_s': 40, 'took_s': 0, 'outcome': 'stopped'},
      ]);
    });

    test('holds numbers and trace words only', () {
      taps.ended(taps.began(), TraceOutcome.psiphon);
      for (final tap in taps.toContext()) {
        expect(
          tap.keys.toSet().difference({'ago_s', 'took_s', 'outcome'}),
          isEmpty,
        );
        expect(tap['ago_s'], isA<int>());
        expect(tap['took_s'], isA<int>());
      }
      expect(taps.toContext().single['outcome'], 'psiphon');
    });
  });

  group('the connect flow', () {
    late Map<String, DoorOutcome> outcomes;
    late Future<bool> Function() internet;
    late Completer<void>? hold;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      outcomes = {};
      internet = () async => false;
      hold = null;
    });

    ConnectFlow flow(
      _FakeVpn vpn, {
      ConnectTraces? traces,
      ChecklistSettings? checklist,
    }) => ConnectFlow(
      vpn: vpn,
      memory: PathMemory(),
      finder: PathFinder(
        read: (p) async {
          await hold?.future;
          return outcomes[p.pathKey] ?? _closed;
        },
        internet: () => internet(),
        budget: const Duration(seconds: 1),
      ),
      reporter: VpnEventReporter(send: (_, _, _) async {}),
      ipv6: Ipv6Reach(route: () async => null),
      networkKey: () async => 'mobile',
      carrier: () async => null,
      checklist: () => checklist,
      traces: traces,
      attemptTimeout: const Duration(seconds: 2),
      answeredSince: (_) => false,
    );

    List<Object?> ended(ConnectFlow f) => [
      for (final t in f.recentTaps.toContext()) t['outcome'],
    ];

    test(
      'records each run with its trace word while the trace is off',
      () async {
        expect(ConnectTraces.enabled, isFalse);
        final f = flow(_FakeVpn({}));

        await f.connect(paths);
        expect(f.stage, ConnectStage.noInternet);
        expect(ended(f), ['no_internet']);

        internet = () async => true;
        await f.connect(paths);
        expect(f.stage, ConnectStage.nothingOpen);
        expect(ended(f), ['all_closed', 'no_internet']);

        outcomes[fsn1.pathKey] = _open;
        final up = flow(_FakeVpn({fsn1.pathKey}));
        await up.connect(paths);
        expect(up.stage, ConnectStage.done);
        expect(ended(up), ['connected']);
      },
    );

    test('a tap the user stopped is stopped', () async {
      final f = flow(_FakeVpn({}));
      hold = Completer<void>();

      final tap = f.connect(paths);
      await pumpEventQueue();
      expect(f.recentTaps.toContext().single.containsKey('outcome'), isFalse);
      expect(f.searching, isTrue);
      f.cancel();
      hold!.complete();
      await tap;
      await pumpEventQueue();

      expect(ended(f), ['stopped']);
      expect(f.searching, isFalse);
    });

    test('with the trace on, the record and the trace agree', () async {
      final queued = <ConnectTrace>[];
      final f = flow(_FakeVpn({}), traces: _Kept(queued));
      internet = () async => true;

      await f.connect(paths);
      await pumpEventQueue();

      expect(queued.single.outcome, TraceOutcome.allClosed);
      expect(ended(f), [queued.single.outcome!.wire]);
      // The trace that went out keeps its steps; the record has none.
      expect(queued.single.steps, isNotEmpty);
    });

    // The record still has the tap: the flow keeps a trace of the outcome
    // only, for itself. That trace is not one the backend asked for, so it
    // is never handed on to be sent.
    test('with the trace off, a tap sends no trace', () async {
      final handed = <ConnectTrace>[];
      internet = () async => true;
      final f = flow(_FakeVpn({}), traces: _Off(handed));

      await f.connect(paths);
      expect(f.stage, ConnectStage.nothingOpen);

      outcomes[fsn1.pathKey] = _open;
      final up = flow(_FakeVpn({fsn1.pathKey}), traces: _Off(handed));
      await up.connect(paths);
      expect(up.stage, ConnectStage.done);
      await pumpEventQueue();

      expect(ended(f), ['all_closed']);
      expect(ended(up), ['connected']);
      expect(handed, isEmpty);
    });

    test('is searching while it checks doors, and not once it ended', () async {
      final f = flow(_FakeVpn({}));
      expect(f.searching, isFalse);
      hold = Completer<void>();

      final tap = f.connect(paths);
      await pumpEventQueue();
      expect(f.stage, ConnectStage.diagnosing);
      expect(f.searching, isTrue);
      hold!.complete();
      await tap;

      expect(f.stage, ConnectStage.noInternet);
      expect(f.searching, isFalse);
    });

    // The chat reads a tap that waits to try again as still searching:
    // the user has not given up, and the app will try again by itself.
    test('is searching while it waits to try again, and not once no try '
        'is left', () async {
      internet = () async => true;
      final f = flow(
        _FakeVpn({}),
        checklist: const ChecklistSettings(
          retry: RetrySettings(after: [Duration(milliseconds: 50)]),
        ),
      );
      addTearDown(f.cancel);

      await f.connect(paths);
      expect(f.stage, ConnectStage.waiting);
      expect(f.waitingAfter, ConnectStage.nothingOpen);
      expect(f.searching, isTrue);

      // The one wait ends, the try finds every door closed again, and no
      // wait is left.
      await until(() => f.stage == ConnectStage.nothingOpen);
      expect(f.searching, isFalse);
    });

    test('is not searching once the user stops a tap that waits to try '
        'again', () async {
      internet = () async => true;
      final f = flow(
        _FakeVpn({}),
        checklist: const ChecklistSettings(
          retry: RetrySettings(after: [Duration(minutes: 1)]),
        ),
      );
      addTearDown(f.cancel);

      await f.connect(paths);
      expect(f.stage, ConnectStage.waiting);
      expect(f.searching, isTrue);

      f.cancel();
      expect(f.stage, ConnectStage.cancelled);
      expect(f.searching, isFalse);
    });
  });

  test('a trace that keeps only the outcome keeps no step', () {
    final trace = ConnectTrace.outcomeOnly(
      attemptId: 'a' * 32,
      startedAt: DateTime.utc(2026, 10, 24),
    );
    trace.add(hel1, TraceStage.checklist, TraceResult.fail, ms: 3000);
    trace.end(TraceOutcome.allClosed);
    expect(trace.steps, isEmpty);
    expect(trace.outcome, TraceOutcome.allClosed);
  });
}

/// A trace queue that is on and keeps what it is given.
class _Kept extends ConnectTraces {
  _Kept(this.kept) : super(enabled: () => true);

  final List<ConnectTrace> kept;

  @override
  Future<void> send(ConnectTrace trace) async => kept.add(trace);
}

/// A trace queue that is off and keeps what it is handed all the same.
class _Off extends ConnectTraces {
  _Off(this.handed) : super(enabled: () => false);

  final List<ConnectTrace> handed;

  @override
  Future<void> send(ConnectTrace trace) async => handed.add(trace);
}
