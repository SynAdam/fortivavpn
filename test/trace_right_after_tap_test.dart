import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/api/api_client.dart';
import 'package:fortiva_vpn/core/state/connect_flow.dart';
import 'package:fortiva_vpn/data/models/checklist_settings.dart';
import 'package:fortiva_vpn/data/models/server.dart';
import 'package:fortiva_vpn/services/connect_trace.dart';
import 'package:fortiva_vpn/services/ipv6_reach.dart';
import 'package:fortiva_vpn/services/path_finder.dart';
import 'package:fortiva_vpn/services/path_memory.dart';
import 'package:fortiva_vpn/services/report_queue.dart';
import 'package:fortiva_vpn/services/vpn_event_reporter.dart';
import 'package:fortiva_vpn/services/vpn_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The trace of a tap goes the moment the tap ends, and each step says
/// when it began.
///
/// On the Tehran day of 2026-10-23 the traces of taps that found every door
/// closed reached the backend a median of 160 s after the tap began. Of the
/// 111 such taps whose phone asked for its config again within 2 hours, 94
/// traces had not arrived when that request was answered. A trace went into
/// the queue behind every trace still waiting, and a flush already running
/// on a lossy line made it wait for that flush. On one phone a tap's trace
/// arrived 804 s after the tap.
///
/// Now the tap's parts are sent at once, in uploads of their own, ahead of
/// the waiting traces and beside a flush that hangs. Parts no route carried
/// wait for the queue's next flush, and no part is in two uploads.
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
final paths = [hel1, hel2, fsn1];

const open = DoorOutcome(ms: 120, tcpMs: 40, phase: 'ok');
const closed = DoorOutcome(
  ms: -1,
  error: 'tcp timeout; no answer in 3000 ms',
  phase: 'tcp',
);

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

/// Each item of an upload as "attempt id/part".
List<String> partsIn(Map<String, dynamic> body) => [
  for (final item in body['items'] as List)
    '${(item as Map)['attempt_id']}/${item['part']}',
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Every upload tried, and every upload that arrived, in order.
  late List<Map<String, dynamic>> tried;
  late List<Map<String, dynamic>> arrived;

  /// Runs in each upload before it arrives. It can hang, as an upload
  /// waits out its timeout on a lossy line, or throw, as one that no route
  /// carried.
  late Future<void> Function(Map<String, dynamic> body)? line;
  late ReportQueue queue;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ReportQueue.resetForTest();
    tried = [];
    arrived = [];
    line = null;
    queue = ReportQueue.connectTraces(
      post: (path, body) async {
        final copy = (jsonDecode(jsonEncode(body)) as Map)
            .cast<String, dynamic>();
        tried.add(copy);
        await line?.call(copy);
        arrived.add(copy);
      },
      deviceId: () async => 'DEV-1',
      register: () async {},
    );
  });

  ConnectTraces traces() => ConnectTraces(
    queue: queue,
    enabled: () => true,
    networkType: () async => 'mobile',
    linkFacts: () async => const {'transport': 'cellular'},
  );

  /// A tap that found every door closed, as one part.
  ConnectTrace closedTap(String id) =>
      ConnectTrace(attemptId: id, startedAt: DateTime.now())
        ..add(hel1, TraceStage.checklist, TraceResult.fail, ms: 3004)
        ..end(TraceOutcome.allClosed);

  /// Traces of earlier taps, waiting in the queue.
  Future<void> waiting(List<String> ids) async {
    for (final id in ids) {
      await queue.add(await closedTap(id).items());
    }
  }

  Future<List<String>> pending() async => [
    for (final item in await queue.pending())
      '${item['attempt_id']}/${item['part']}',
  ];

  List<String> sent(List<Map<String, dynamic>> uploads) => [
    for (final body in uploads) ...partsIn(body),
  ];

  group('the trace goes as soon as the tap ends', () {
    test('while a flush of the traces that waited hangs on a lossy line, '
        'the new trace still goes at once', () async {
      await waiting(['old1', 'old2']);
      final timeout = Completer<void>();
      line = (body) async {
        if (partsIn(body).any((p) => p.startsWith('old'))) {
          await timeout.future;
        }
      };
      // The report timer's try: its upload of the old traces hangs.
      final flushing = queue.flush();
      await until(() => tried.isNotEmpty);

      final sending = traces().send(closedTap('new'));
      await until(() => arrived.isNotEmpty);

      expect(sent(arrived), ['new/0']);
      expect(timeout.isCompleted, isFalse);

      timeout.complete();
      await flushing;
      await sending;
      // Each part arrived once.
      expect(sent(arrived)..sort(), ['new/0', 'old1/0', 'old2/0']);
      expect(await pending(), isEmpty);
    });

    test(
      'it goes ahead of the traces that wait, and they go after it',
      () async {
        await waiting(['old1', 'old2', 'old3']);

        await traces().send(closedTap('new'));

        expect(partsIn(arrived.first), ['new/0']);
        expect(sent(arrived), ['new/0', 'old1/0', 'old2/0', 'old3/0']);
        expect(await pending(), isEmpty);
      },
    );

    test('a trace no route carried waits for the queue\'s next flush, which '
        'sends it ahead of the traces that waited longer; those are not '
        'tried again at once', () async {
      await waiting(['old1']);
      line = (_) async =>
          throw ApiException(statusCode: 0, message: 'No internet connection');

      await traces().send(closedTap('new'));

      // One try, of the new trace alone. The line just failed it on every
      // route, so the old one is not tried beside it.
      expect(sent(tried), ['new/0']);
      expect(arrived, isEmpty);
      expect(await pending(), ['old1/0', 'new/0']);

      // The report timer, on a line that carries it.
      line = null;
      tried.clear();
      await queue.flush();

      expect(
        [for (final body in arrived) partsIn(body)],
        [
          ['new/0'],
          ['old1/0'],
        ],
      );
      expect(await pending(), isEmpty);
      arrived.clear();
      await queue.flush();
      expect(arrived, isEmpty);
    });

    test('traces no route carried go newest first, and a flush stops at the '
        'first of them that fails again', () async {
      await waiting(['old1']);
      line = (_) async =>
          throw ApiException(statusCode: 0, message: 'No internet connection');
      await traces().send(closedTap('new1'));
      await traces().send(closedTap('new2'));

      // Still no route: one try, of the newest, and nothing after it.
      tried.clear();
      await queue.flush();
      expect(sent(tried), ['new2/0']);

      line = null;
      tried.clear();
      await queue.flush();
      expect(sent(tried), ['new2/0', 'new1/0', 'old1/0']);
      expect(await pending(), isEmpty);
    });

    test(
      'a flush running when the new trace went through goes round again '
      'when its own upload fails, so the traces that waited go too',
      () async {
        await waiting(['old1', 'old2']);
        final timeout = Completer<void>();
        line = (body) async {
          if (partsIn(body).any((p) => p.startsWith('old'))) {
            await timeout.future;
            throw ApiException(statusCode: 0, message: 'timeout');
          }
        };
        final flushing = queue.flush();
        await until(() => tried.isNotEmpty);

        final sending = traces().send(closedTap('new'));
        await until(() => arrived.isNotEmpty);
        expect(sent(arrived), ['new/0']);

        // The line carries again, and the running flush's upload now fails.
        line = null;
        timeout.complete();
        await flushing;
        await sending;

        expect(sent(arrived)..sort(), ['new/0', 'old1/0', 'old2/0']);
        expect(await pending(), isEmpty);
      },
    );

    test('a trace no route carried is in one upload at a time, while the '
        'next try sends it and a flush runs beside it', () async {
      line = (_) async => throw ApiException(statusCode: 0, message: 'reset');
      await traces().send(closedTap('new'));

      final slow = Completer<void>();
      line = (body) async {
        if (partsIn(body).contains('new/0')) await slow.future;
      };
      tried.clear();
      final first = traces().sendWaiting();
      await until(() => tried.isNotEmpty);
      // The report timer fires meanwhile.
      await queue.flush();
      expect(sent(tried), ['new/0']);

      slow.complete();
      await first;
      expect(sent(arrived), ['new/0']);
      expect(await pending(), isEmpty);
    });

    test('a trace waiting to go first is never in a flush\'s upload, so the '
        'next try and a flush do not both send it', () async {
      final oldHeld = Completer<void>();
      final newHeld = Completer<void>();
      var newTries = 0;
      line = (body) async {
        final parts = partsIn(body);
        if (parts.contains('old1/0')) await oldHeld.future;
        if (parts.contains('new/0')) {
          newTries++;
          if (newTries == 1) {
            throw ApiException(statusCode: 0, message: 'reset');
          }
          if (newTries == 2) await newHeld.future;
        }
      };
      await waiting(['old1']);
      final flushing = queue.flush();
      await until(() => tried.isNotEmpty);
      // The tap's own send fails while the flush waits on its upload.
      await traces().send(closedTap('new'));

      oldHeld.complete();
      await until(() => sent(arrived).contains('old1/0'));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      // The next try sends it. A flush that had taken it would have it in
      // an upload now.
      final next = traces().sendWaiting();
      await until(() => newTries >= 2);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(newTries, 2);

      newHeld.complete();
      await next;
      await flushing;
      expect(sent(arrived).where((p) => p == 'new/0'), hasLength(1));
      expect(await pending(), isEmpty);
    });

    test('a trace that waited longer than the queue keeps rows is not sent '
        'first: the flush drops it', () async {
      var now = DateTime.now();
      final kept = ReportQueue.connectTraces(
        post: (path, body) async {
          final copy = (jsonDecode(jsonEncode(body)) as Map)
              .cast<String, dynamic>();
          tried.add(copy);
          await line?.call(copy);
          arrived.add(copy);
        },
        deviceId: () async => 'DEV-1',
        register: () async {},
        clock: () => now,
      );
      final mine = ConnectTraces(
        queue: kept,
        enabled: () => true,
        networkType: () async => 'mobile',
        linkFacts: () async => const {'transport': 'cellular'},
      );
      line = (_) async => throw ApiException(statusCode: 0, message: 'reset');
      await mine.send(closedTap('new'));

      now = now.add(
        VpnEventReporter.closedProbesKeptFor + const Duration(minutes: 1),
      );
      line = null;
      tried.clear();
      await mine.sendWaiting();
      await kept.flush();

      expect(tried, isEmpty);
      expect(await kept.pending(), isEmpty);
    });

    test(
      'the parts are stored before they are sent, and a flush while they '
      'are being sent leaves them alone: no part is in two uploads',
      () async {
        final slow = Completer<void>();
        var held = false;
        line = (body) async {
          if (!held && partsIn(body).contains('new/0')) {
            held = true;
            await slow.future;
          }
        };

        final sending = traces().send(closedTap('new'));
        await until(() => tried.isNotEmpty);

        // An app closed now keeps the trace for its next run.
        expect(await pending(), ['new/0']);
        // The report timer fires meanwhile.
        await queue.flush();
        expect(sent(tried), ['new/0']);

        slow.complete();
        await sending;
        expect(sent(arrived), ['new/0']);
        expect(await pending(), isEmpty);
      },
    );

    test('a part sent again after its answer was lost is the same part, so '
        'the backend stores it once', () async {
      // The upload reached the backend and its answer did not come back.
      line = (_) async => throw ApiException(statusCode: 0, message: 'reset');

      await traces().send(closedTap('new'));
      final first = tried.single;

      line = null;
      tried.clear();
      await queue.flush();

      expect(partsIn(tried.single), partsIn(first));
      expect(tried.single['items'], first['items']);
    });

    test('a tap that found every door closed has sent its trace when it '
        'starts to wait for its next try, beside a flush that hangs', () async {
      await waiting(['old1']);
      final timeout = Completer<void>();
      line = (body) async {
        if (partsIn(body).contains('old1/0')) await timeout.future;
      };
      final flushing = queue.flush();
      await until(() => tried.isNotEmpty);

      final f = ConnectFlow(
        vpn: _FakeVpn({}),
        memory: PathMemory(),
        finder: PathFinder(
          read: (_) async => closed,
          internet: () async => true,
          budget: const Duration(milliseconds: 300),
        ),
        reporter: VpnEventReporter(
          send: (_, _, _) async {},
          sendProbes: (_, _, _) async {},
          deviceId: () async => 'DEV-1',
          appVersion: () async => '2.2.0',
          platform: 'android',
          networkType: () async => 'mobile',
          queues: const [],
        ),
        ipv6: Ipv6Reach(route: () async => null),
        networkKey: () async => 'mobile',
        carrier: () async => null,
        checklist: () => const ChecklistSettings(
          retry: RetrySettings(after: [Duration(seconds: 30)]),
        ),
        traces: traces(),
        random: () => 0.5,
        attemptTimeout: const Duration(seconds: 2),
      );
      addTearDown(f.cancel);

      await f.connect(paths);
      expect(f.stage, ConnectStage.waiting);
      await until(() => arrived.isNotEmpty);

      final [body] = arrived;
      expect((body['items'] as List).single['outcome'], 'all_closed');
      expect(partsIn(body).single, isNot('old1/0'));

      f.cancel();
      timeout.complete();
      await flushing;
      expect(await pending(), isEmpty);
    });
  });

  group('a try after a wait sends the trace of the tap before it first', () {
    /// A flow whose every door is closed, with one wait of 50 ms before
    /// its next try. [atConfig] gets, for each config request before a
    /// try, the parts that had reached the backend by then, and the flow
    /// is stopped there.
    Future<ConnectFlow> tapAndWait(List<List<String>> atConfig) async {
      late final ConnectFlow f;
      f = ConnectFlow(
        vpn: _FakeVpn({}),
        memory: PathMemory(),
        finder: PathFinder(
          read: (_) async => closed,
          internet: () async => true,
          budget: const Duration(milliseconds: 300),
        ),
        reporter: VpnEventReporter(
          send: (_, _, _) async {},
          sendProbes: (_, _, _) async {},
          deviceId: () async => 'DEV-1',
          appVersion: () async => '2.2.0',
          platform: 'android',
          networkType: () async => 'mobile',
          queues: const [],
        ),
        ipv6: Ipv6Reach(route: () async => null),
        networkKey: () async => 'mobile',
        carrier: () async => null,
        checklist: () => const ChecklistSettings(
          retry: RetrySettings(after: [Duration(milliseconds: 50)]),
        ),
        traces: traces(),
        random: () => 0.5,
        attemptTimeout: const Duration(seconds: 2),
      );
      addTearDown(f.cancel);
      await f.connect(
        paths,
        beforeRetry: () async {
          atConfig.add(sent(arrived));
          f.cancel();
        },
      );
      expect(f.stage, ConnectStage.waiting);
      return f;
    }

    test('a trace no route carried when its tap ended goes before the next '
        'try asks for its config', () async {
      var cut = true;
      line = (_) async {
        if (cut) {
          throw ApiException(statusCode: 0, message: 'No internet connection');
        }
      };
      final atConfig = <List<String>>[];
      await tapAndWait(atConfig);
      await until(() => tried.isNotEmpty);
      expect(arrived, isEmpty);

      // The line carries again before the next try.
      cut = false;
      await until(() => atConfig.isNotEmpty);

      expect(atConfig.single, hasLength(1));
      expect(await pending(), isEmpty);
    });

    test('a send still on its way when the wait ends is waited for before '
        'the config request', () async {
      final slow = Completer<void>();
      line = (_) => slow.future;
      final atConfig = <List<String>>[];
      await tapAndWait(atConfig);
      await until(() => tried.isNotEmpty);

      // The wait is over, and the try waits for the upload.
      await Future<void>.delayed(const Duration(milliseconds: 250));
      expect(atConfig, isEmpty);

      slow.complete();
      await until(() => atConfig.isNotEmpty);
      expect(atConfig.single, hasLength(1));
    });

    test(
      'an upload that never answers holds the next try for 4 s at most',
      () async {
        line = (_) => Completer<void>().future;
        final atConfig = <List<String>>[];
        await tapAndWait(atConfig);
        final waiting = Stopwatch()..start();

        await until(
          () => atConfig.isNotEmpty,
          within: const Duration(seconds: 8),
        );

        expect(
          waiting.elapsed,
          greaterThanOrEqualTo(const Duration(seconds: 4)),
        );
        expect(waiting.elapsed, lessThan(const Duration(seconds: 6)));
        expect(atConfig.single, isEmpty);
      },
    );
  });

  group('each step says when it began', () {
    final t0 = DateTime.utc(2026, 10, 23, 9, 41, 7);

    test('in ms after the tap began, for the checks and dials the tap ran; '
        'a door it left and the sweep\'s hint have none', () {
      final trace = ConnectTrace(attemptId: 'a' * 32, startedAt: t0)
        ..add(hel1, TraceStage.sweepHint, TraceResult.ok)
        ..add(
          hel1,
          TraceStage.checklist,
          TraceResult.fail,
          reason: TraceReason.tcp,
          ms: 3004,
          began: t0.add(const Duration(milliseconds: 12)),
        )
        ..add(
          hel2,
          TraceStage.checklist,
          TraceResult.skipped,
          reason: TraceReason.budget,
        )
        ..add(
          fsn1,
          TraceStage.dial,
          TraceResult.ok,
          ms: 812,
          began: t0.add(const Duration(milliseconds: 21870)),
        );

      expect([for (final s in trace.steps) s.at], [null, 12, null, 21870]);
      expect(trace.steps[1].toJson()['at'], 12);
      // A step with no start leaves the key out, so it costs no bytes.
      expect(trace.steps[2].toJson().containsKey('at'), isFalse);
      expect(trace.steps[0].toJson().containsKey('at'), isFalse);
      // The other keys are sent as before, null ones included.
      expect(trace.steps[2].toJson().keys, [
        'door',
        'kind',
        'stage',
        'result',
        'reason',
        'ms',
      ]);
      // A new reason keeps the start.
      expect(trace.steps[1].withReason(TraceReason.stopped).at, 12);
    });

    test('a start before the tap is none: that row\'s check was another '
        'tap\'s', () {
      final trace = ConnectTrace(attemptId: 'a' * 32, startedAt: t0);
      expect(trace.atOf(t0.subtract(const Duration(seconds: 4))), isNull);
      expect(trace.atOf(t0), 0);
      expect(trace.atOf(null), isNull);
    });

    // A check a stop cut short, or a row checked again, goes back to
    // pending. Its old start is not its next check's.
    test('a row put back to pending keeps no start', () {
      final row = PathCheck(hel1, state: PathCheckState.blocked, ms: 3004)
        ..error = 'tcp timeout; no answer in 3000 ms'
        ..startedAt = t0.add(const Duration(milliseconds: 12));

      row.forget();

      expect(row.state, PathCheckState.pending);
      expect(row.ms, isNull);
      expect(row.startedAt, isNull);
    });

    test('the parts of a long tap with start times still fit 1 KB each, and '
        'every step keeps its start', () async {
      final trace = ConnectTrace(attemptId: 'a' * 32, startedAt: t0);
      for (var i = 0; i < 48; i++) {
        trace.add(
          paths[i % paths.length],
          TraceStage.checklist,
          TraceResult.fail,
          reason: TraceReason.timeout,
          ms: 3012,
          began: t0.add(Duration(milliseconds: 250 * i + 999000)),
        );
      }
      trace.end(TraceOutcome.allClosed);

      await traces().send(trace);

      expect(arrived.length, greaterThan(4));
      for (final body in arrived) {
        expect(
          utf8.encode(jsonEncode(body)).length,
          lessThanOrEqualTo(VpnEventReporter.probeUploadBytes),
        );
      }
      final steps = [
        for (final body in arrived)
          for (final item in body['items'] as List) ...item['steps'] as List,
      ];
      expect(steps, hasLength(48));
      expect(
        [for (final s in steps) s['at']],
        [for (var i = 0; i < 48; i++) 250 * i + 999000],
      );
    });

    group('in a tap', () {
      /// A flow whose every check takes [checkTime], with [doors] for the
      /// checklist, and a trace whose own clock is a week behind.
      Future<List<TraceStep>> tap({
        required DoorCheckSettings doors,
        Duration checkTime = const Duration(milliseconds: 40),
        Set<String> openHere = const {},
      }) async {
        final kept = <ConnectTrace>[];
        final f = ConnectFlow(
          vpn: _FakeVpn(openHere),
          memory: PathMemory(),
          finder: PathFinder(
            read: (p) async {
              await Future.delayed(checkTime);
              return openHere.contains(p.pathKey) ? open : closed;
            },
            internet: () async => true,
            budget: const Duration(seconds: 2),
          ),
          reporter: VpnEventReporter(
            send: (_, _, _) async {},
            sendProbes: (_, _, _) async {},
            deviceId: () async => 'DEV-1',
            appVersion: () async => '2.2.0',
            platform: 'android',
            networkType: () async => 'mobile',
            queues: const [],
          ),
          ipv6: Ipv6Reach(route: () async => null),
          networkKey: () async => 'mobile',
          carrier: () async => null,
          checklist: () => ChecklistSettings(doors: doors),
          traces: _Kept(
            kept,
            queue: queue,
            clock: () => DateTime.now().subtract(const Duration(days: 7)),
          ),
          attemptTimeout: const Duration(seconds: 2),
        );
        addTearDown(f.cancel);
        await f.connect(paths);
        return kept.single.steps;
      }

      test('checks run side by side start together', () async {
        final steps = await tap(
          doors: const DoorCheckSettings(parallel: 3, stagger: Duration.zero),
        );
        final checks = [
          for (final s in steps)
            if (s.stage == TraceStage.checklist) s,
        ];
        expect(checks, hasLength(3));
        final starts = [for (final s in checks) s.at!];
        // All three began before the first of them could have ended.
        for (final at in starts) {
          expect(at, lessThan(starts.first + 30));
        }
      });

      test('checks run one at a time each start after the one before has '
          'ended, and the dial starts after the open one', () async {
        final steps = await tap(
          doors: const DoorCheckSettings(parallel: 1, stagger: Duration.zero),
          openHere: {fsn1.pathKey},
        );
        final checks = [
          for (final s in steps)
            if (s.stage == TraceStage.checklist) s,
        ];
        expect(checks, hasLength(3));
        for (var i = 1; i < checks.length; i++) {
          expect(checks[i].at, greaterThanOrEqualTo(checks[i - 1].at! + 35));
        }
        final dial = steps.lastWhere((s) => s.stage == TraceStage.dial);
        expect(dial.at, greaterThanOrEqualTo(checks.last.at! + 35));
        // Counted from the tap on the clock the checks read, not from the
        // clock that stamps the trace, which is a week behind here.
        expect(dial.at, lessThan(5000));
      });
    });
  });
}

/// Keeps every trace the flow starts, as ConnectTraces makes them, and
/// sends none.
class _Kept extends ConnectTraces {
  _Kept(this.kept, {super.queue, super.clock}) : super(enabled: () => true);

  final List<ConnectTrace> kept;

  @override
  ConnectTrace? start(String attemptId) {
    final trace = super.start(attemptId);
    if (trace != null) kept.add(trace);
    return trace;
  }

  @override
  Future<void> send(ConnectTrace trace) async {}
}
