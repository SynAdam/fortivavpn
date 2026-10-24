import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/models/server.dart';
import '../utils/link_id.dart';
import '../utils/standby_doors.dart';
import '../utils/vless_link.dart';
import 'delivery_log.dart';
import 'link_facts.dart';
import 'path_finder.dart';
import 'report_queue.dart';
import 'vpn_event_reporter.dart';

/// Which part of a tap a step of the trace belongs to.
enum TraceStage {
  /// A door the background sweep found open recently, which put it first
  /// in the last pass. Not a check this tap ran.
  sweepHint('sweep_hint'),

  /// The checklist's checks of the own doors, and the shared-link fallback
  /// that carries on in the same list.
  checklist('checklist'),

  /// The last pass of a checklist that found no door open.
  lastPass('last_pass'),

  /// A tunnel attempt through one door.
  dial('dial'),

  /// The tap stopped looking for doors and links because it had run the
  /// backend's PsiphonSettings.startAfter without a tunnel. One step, for
  /// the backup network, with [TraceResult.cut], just before the backup
  /// network's dial. Its ms is how long the tap had run when the search
  /// stopped.
  cut('cut');

  const TraceStage(this.wire);
  final String wire;
}

/// What one step found.
enum TraceResult {
  ok('ok'),
  fail('fail'),

  /// Not tried. The step's reason says why.
  skipped('skipped'),

  /// The search was stopped at the backend's time ([TraceStage.cut]).
  cut('cut');

  const TraceResult(this.wire);
  final String wire;
}

/// Why a step failed, or why a door was not tried.
enum TraceReason {
  /// The checklist's time ran out before it reached this door, or the
  /// last pass already had as many doors as the backend allows.
  budget('budget'),

  /// The door failed on this network often enough to be skipped
  /// (PathMemory.skippable).
  skippedToday('skipped_today'),

  /// The door is dialled at an IPv6 address and this network has none, so
  /// the last pass left it out.
  noIpv6('no_ipv6'),

  /// The user stopped the tap first.
  stopped('stopped'),

  /// The backend said this device's allowance is spent.
  allowance('allowance'),
  timeout('timeout'),

  /// The door's address took no TCP connection.
  tcp('tcp'),

  /// The core said the TLS handshake failed.
  tls('tls'),
  refused('refused'),
  other('other');

  const TraceReason(this.wire);
  final String wire;
}

/// How a tap ended.
enum TraceOutcome {
  connected('connected'),
  allClosed('all_closed'),
  stopped('stopped'),

  /// A door was open on the check and the tunnel still failed through it.
  failed('failed'),
  noInternet('no_internet'),

  /// No site abroad answered and one inside the country did, and nothing
  /// was open (ConnectStage.cutOff). A backend that does not know the word
  /// yet stores the outcome as unknown and keeps the rest of the trace.
  cutOff('cut_off'),
  allowance('allowance'),

  /// The VPN permission was refused, or another app holds it.
  permission('permission'),

  /// Nothing else connected, and the backup network did
  /// (Server.psiphon).
  psiphon('psiphon');

  const TraceOutcome(this.wire);
  final String wire;
}

/// One door the connect flow considered, and what came of it.
@immutable
class TraceStep {
  const TraceStep({
    required this.door,
    required this.kind,
    required this.stage,
    required this.result,
    this.reason,
    this.ms,
    this.at,
  });

  /// See [ConnectTrace.doorKey].
  final String door;

  /// See [ConnectTrace.kindOf].
  final String kind;
  final TraceStage stage;
  final TraceResult result;
  final TraceReason? reason;

  /// How long the check or the dial took. Null for a door not tried.
  final int? ms;

  /// When the check or the dial started, in milliseconds after the tap
  /// began ([ConnectTrace.startedAt]). Null for a door not tried, and for a
  /// step that is not a check this tap ran, such as the sweep's hint.
  ///
  /// With [ms] it puts a tap's steps on one clock: which checks ran side by
  /// side, and how long the tap had run before each one began. Until this,
  /// the backend could only add the steps' times up, and checks that run
  /// several at once made that sum longer than the tap.
  final int? at;

  TraceStep withReason(TraceReason reason) => TraceStep(
    door: door,
    kind: kind,
    stage: stage,
    result: result,
    reason: reason,
    ms: ms,
    at: at,
  );

  /// Every key is sent, null ones included, except [at]: a step without a
  /// start leaves it out, because each upload holds at most 1 KB and the
  /// backend reads a missing key as none.
  Map<String, dynamic> toJson() => {
    'door': door,
    'kind': kind,
    'stage': stage.wire,
    'result': result.wire,
    'reason': reason?.wire,
    'ms': ms,
    'at': ?at,
  };
}

/// What one connect tap did, step by step, for
/// POST /api/v1/devices/{id}/connect-traces.
///
/// One phone ended three checklists in a row at "all doors closed" without
/// trying the one address that was open: the 20 second budget ran out on
/// its first server's doors, and later the skip-for-the-day rule hid the
/// second server's. The door checks it sent named only the doors it
/// checked, so nothing in our data said that the open doors were never
/// tried, or why. The trace names every door the flow considered, in
/// order, with the stage, the result and the reason, the doors it passed
/// over included, and how the tap ended.
///
/// A door is named by its key ([doorKey]), never by an address, and a
/// failure by its kind ([reasonOf]), never by the core's error text, which
/// can name the address it dialled. Nothing about the phone's own address
/// is read or kept.
///
/// The steps are added as the flow runs. [items] cuts them into parts that
/// each fit an upload of at most [VpnEventReporter.probeUploadBytes]: one
/// tap's trace can need several, and they share the tap's attempt id.
class ConnectTrace {
  ConnectTrace({
    required this.attemptId,
    required this.startedAt,
    DateTime? stepsFrom,
    Future<String?>? networkType,
    Future<String?>? transport,
  }) : _stepsFrom = stepsFrom ?? startedAt,
       _networkType = networkType ?? Future.value(),
       _transport = transport ?? Future.value(),
       _keepsSteps = true;

  /// A trace that keeps only how the tap ended, for a tap the backend does
  /// not trace: the connect flow's record of its recent taps (RecentTaps)
  /// reads the outcome whether or not the trace is on. It keeps no step,
  /// reads nothing about the network and is never sent.
  ConnectTrace.outcomeOnly({required this.attemptId, required this.startedAt})
    : _stepsFrom = startedAt,
      _networkType = Future.value(),
      _transport = Future.value(),
      _keepsSteps = false;

  /// False for [ConnectTrace.outcomeOnly].
  final bool _keepsSteps;

  /// The tap's attempt id, the one its door checks and tunnel events carry.
  final String attemptId;

  /// When the tap started, on the phone's clock.
  final DateTime startedAt;

  /// The moment each step's start ([TraceStep.at]) is counted from, on the
  /// clock the checks and the dials read (DateTime.now). [startedAt] unless
  /// given: ConnectTraces gives it, because its own clock can be another.
  final DateTime _stepsFrom;

  /// Read when the tap started, and waited for only when the trace is
  /// queued, so a connect never waits on them.
  final Future<String?> _networkType;
  final Future<String?> _transport;

  final List<TraceStep> _steps = [];
  TraceOutcome? _outcome;
  String? _chosen;

  List<TraceStep> get steps => List.unmodifiable(_steps);

  /// How the tap ended, or null while it runs.
  TraceOutcome? get outcome => _outcome;

  /// The key of the door the tap ended on, when it ended on one.
  String? get chosen => _chosen;

  /// One step for [door]. [began] is when its check or its dial started.
  void add(
    Server door,
    TraceStage stage,
    TraceResult result, {
    TraceReason? reason,
    int? ms,
    DateTime? began,
  }) {
    if (!_keepsSteps) return;
    _steps.add(
      TraceStep(
        door: doorKey(door),
        kind: kindOf(door),
        stage: stage,
        result: result,
        reason: reason,
        ms: ms,
        at: atOf(began),
      ),
    );
  }

  /// [began] in milliseconds after the tap began, or null. Null too for a
  /// time before the tap: a row whose check another tap ran.
  @visibleForTesting
  int? atOf(DateTime? began) {
    if (began == null) return null;
    final at = began.difference(_stepsFrom).inMilliseconds;
    return at < 0 ? null : at;
  }

  /// A step for each of [rows], in the order given, as each stands now.
  ///
  /// A row with a result is an ok or a fail step. A row the checklist
  /// skipped for the day is a skipped step with [TraceReason.skippedToday].
  /// A row that was not reached is a skipped step with [unreached], or no
  /// step when [unreached] is null. With [stopAtOpen], no row after the
  /// first open one gets a step: the search stopped there.
  void checks(
    Iterable<PathCheck> rows,
    TraceStage stage, {
    TraceReason? unreached,
    bool stopAtOpen = false,
  }) {
    for (final c in rows) {
      switch (c.state) {
        case PathCheckState.open:
          add(c.path, stage, TraceResult.ok, ms: c.ms, began: c.startedAt);
          if (stopAtOpen) return;
        case PathCheckState.blocked:
          add(
            c.path,
            stage,
            TraceResult.fail,
            reason: reasonOf(c),
            ms: c.ms,
            began: c.startedAt,
          );
        case PathCheckState.skipped when stage == TraceStage.checklist:
          add(
            c.path,
            stage,
            TraceResult.skipped,
            reason: TraceReason.skippedToday,
          );
        case PathCheckState.skipped:
        case PathCheckState.pending:
        case PathCheckState.running:
          if (unreached != null) {
            add(c.path, stage, TraceResult.skipped, reason: unreached);
          }
      }
    }
  }

  /// A skipped step with [reason] for each of [rows], in the order given.
  void skipped(Iterable<PathCheck> rows, TraceStage stage, TraceReason reason) {
    for (final c in rows) {
      add(c.path, stage, TraceResult.skipped, reason: reason);
    }
  }

  /// Give the last step, when it is a failed dial, [reason] instead.
  void dialEndedBy(TraceReason reason) {
    if (_steps.isEmpty) return;
    final last = _steps.last;
    if (last.stage != TraceStage.dial || last.result != TraceResult.fail) {
      return;
    }
    _steps[_steps.length - 1] = last.withReason(reason);
  }

  /// The tap ended with [outcome], on [chosen] when it ended on a door.
  void end(TraceOutcome outcome, {Server? chosen}) {
    _outcome = outcome;
    _chosen = chosen == null ? null : doorKey(chosen);
  }

  /// The tap that already ended ended with [outcome] after all, on the
  /// door it ended on before. For a step after the end that changes why it
  /// ended, such as a refused VPN permission.
  void reword(TraceOutcome outcome) => _outcome = outcome;

  /// The trace as the items of the upload, in parts. A trace that did not
  /// record an end is a tap that was stopped.
  Future<List<Map<String, dynamic>>> items() async {
    return parts(
      {
        'attempt_id': attemptId,
        'client_ts': startedAt.toUtc().toIso8601String(),
        'network_type': await _networkType,
        'transport': await _transport,
        'outcome': (_outcome ?? TraceOutcome.stopped).wire,
        'chosen': _chosen,
      },
      [for (final s in _steps) s.toJson()],
    );
  }

  /// [steps] cut into items that each fit an upload of at most
  /// [VpnEventReporter.probeUploadBytes] on their own, numbered from 0 in
  /// `part`, each carrying [head]. A trace with no steps is one item. A
  /// step that does not fit beside [head] on its own goes alone.
  @visibleForTesting
  static List<Map<String, dynamic>> parts(
    Map<String, dynamic> head,
    List<Map<String, dynamic>> steps,
  ) {
    Map<String, dynamic> item(int part, List<Map<String, dynamic>> s) => {
      'attempt_id': head['attempt_id'],
      'part': part,
      'client_ts': head['client_ts'],
      'network_type': head['network_type'],
      'transport': head['transport'],
      'outcome': head['outcome'],
      'chosen': head['chosen'],
      'steps': s,
    };

    final out = <Map<String, dynamic>>[];
    var piece = <Map<String, dynamic>>[];
    for (final step in steps) {
      if (piece.isNotEmpty &&
          ReportQueue.uploadBytes([
                item(out.length, [...piece, step]),
              ]) >
              VpnEventReporter.probeUploadBytes) {
        out.add(item(out.length, piece));
        piece = [];
      }
      piece.add(step);
    }
    out.add(item(out.length, piece));
    return out;
  }

  /// What a step calls [door]: the server's row on the backend and the
  /// door's name, such as "13:xhttp-reality-b", the way the backend's
  /// scoreboard names a door. A link that has neither, a shared or a
  /// community link, goes by its lid ([LinkId]), "lid:" and twelve hex
  /// characters of a hash of the link. Never the address a link dials.
  /// The backup network is "psiphon".
  static String doorKey(Server door) {
    if (door.isPsiphon) return Server.psiphonId;
    final row = door.serverId;
    final name = door.door;
    if (door.isDedicated && name != null && name.isNotEmpty) {
      return row == null ? name : '$row:$name';
    }
    return 'lid:${LinkId.of(door.connectionUri)}';
  }

  /// What kind of door [door] is: "v6" for one dialled at an IPv6
  /// address, "b" for the copy at a server's second IPv4 address, "cdn"
  /// for one behind Cloudflare, "a" for any other door of this device's
  /// own, and "shared" or "community" for a link that is not. The backup
  /// network is "psiphon".
  static String kindOf(Server door) {
    if (door.isPsiphon) return 'psiphon';
    if (door.isCommunity) return 'community';
    if (!door.isDedicated) return 'shared';
    final name = door.door ?? '';
    if (name.endsWith('-v6') || StandbyDoors.dialsIpv6(door)) return 'v6';
    if (name.endsWith('-b')) return 'b';
    if (VlessLink.security(door.connectionUri) == 'tls') return 'cdn';
    return 'a';
  }

  /// Why the check of [check] failed, as a kind. The error text stays on
  /// the phone: the core's words can name the address it dialled.
  static TraceReason reasonOf(PathCheck check) {
    final error = (check.error ?? '').toLowerCase();
    if (error.contains('refused')) return TraceReason.refused;
    if (check.phase == 'tcp') return TraceReason.tcp;
    if (check.phase == 'tls') return TraceReason.tls;
    if (error.contains('timeout') ||
        error.contains('timed out') ||
        error.contains('no answer in') ||
        error.contains('deadline')) {
      return TraceReason.timeout;
    }
    return TraceReason.other;
  }
}

/// Records each connect tap as a [ConnectTrace] and sends it to
/// POST /api/v1/devices/{id}/connect-traces as soon as the tap ends.
///
/// Only while the backend turns it on: the app config's `connect_trace`
/// block, `{"enabled": true}`, which AppConfigState puts in [enabled]. A
/// missing block is off. Each trace goes at once ([send]). The parts no
/// route carried wait in a [ReportQueue] like the size probe readings:
/// under 1 KB per upload, kept on the phone up to
/// [VpnEventReporter.closedProbesKeptFor], sent with the other reports,
/// and dropped when the user turns sharing off.
class ConnectTraces {
  ConnectTraces({
    ReportQueue? queue,
    bool Function()? enabled,
    NetworkTypeProbe? networkType,
    Future<Map<String, Object>> Function()? linkFacts,
    DateTime Function()? clock,
  }) : _queue = queue ?? ReportQueue.connectTraces(),
       _enabled = enabled ?? (() => ConnectTraces.enabled),
       _networkType = networkType ?? VpnEventReporter.currentNetworkType,
       _linkFacts = linkFacts ?? LinkFacts().read,
       _clock = clock ?? DateTime.now;

  /// From the app config's `connect_trace.enabled`. Off until the backend
  /// says otherwise.
  static bool enabled = false;

  final ReportQueue _queue;
  final bool Function() _enabled;
  final NetworkTypeProbe _networkType;
  final Future<Map<String, Object>> Function() _linkFacts;
  final DateTime Function() _clock;

  /// A trace for the tap [attemptId], or null when the trace is off.
  ///
  /// The network type and the transport are read now, for the network the
  /// tap runs on, and not waited for here. Both reads have a time limit,
  /// because [send] waits for them inside the lock every [ReportQueue]
  /// shares: a read that never answers would stop every queue for the rest
  /// of the app run. The network type gets [DeliveryLog.networkTimeout],
  /// the same read with the same limit as the delivery log's. [LinkFacts]
  /// has its own.
  ConnectTrace? start(String attemptId) {
    if (!_enabled()) return null;
    return ConnectTrace(
      attemptId: attemptId,
      startedAt: _clock(),
      stepsFrom: DateTime.now(),
      networkType: _read(
        () => _networkType().timeout(DeliveryLog.networkTimeout),
      ),
      transport: _read(() async {
        final transport = (await _linkFacts())['transport'];
        return transport is String ? transport : null;
      }),
    );
  }

  /// Send [trace] now, the moment its tap has ended. Nothing is sent or
  /// queued once the backend has turned the trace off. Never throws.
  ///
  /// The trace's parts are stored and sent at once, in uploads of their
  /// own, ahead of the traces already waiting and without waiting for a
  /// flush of them that is running ([ReportQueue.addAndSend]). They go the
  /// way POST /configs/dedicated goes: the phone's own network first, then
  /// the tunnel when one is up, then the relays. Nothing waits for a
  /// tunnel: a tap that did not connect has none, and its trace goes on the
  /// phone's own network or through a relay.
  ///
  /// Until this, a trace went into the queue behind every trace still
  /// waiting, and a running flush made it wait for that flush. On the
  /// Tehran day of 2026-10-23 the traces of taps that found every door
  /// closed reached us a median of 160 s after the tap began. Of the 111
  /// such taps whose phone asked for its config again within 2 hours, 94
  /// traces had not arrived when that request was answered, and the rescue
  /// rule that reads them fired for 8 phones.
  ///
  /// Parts no route carried stay in the queue, ahead of the traces that
  /// waited longer ([ReportQueue.sendFirst]). They go at the next try of a
  /// tap that waits ([sendWaiting]), or at the queue's usual tries: the
  /// report timer, a change of network, the next event or the next trace.
  /// The backend stores a part once by its device, attempt id and part
  /// number, so one sent again after a lost answer is not stored twice.
  /// When every part went, the traces that were waiting go too, even when
  /// a flush of them is running and its upload then fails; when one did
  /// not, they are not tried now, since this one just failed on every
  /// route.
  Future<void> send(ConnectTrace trace) async {
    try {
      if (!_enabled()) return;
      final now = _queue.addAndSend(trace.items);
      _sending.add(now);
      final bool sent;
      try {
        sent = await now;
      } finally {
        _sending.remove(now);
      }
      if (sent) await _queue.flush(queued: true);
    } catch (e) {
      debugPrint('ConnectTraces: could not send a trace: $e');
    }
  }

  /// The sends of [send] that are running now, without the flush after
  /// them.
  final Set<Future<bool>> _sending = {};

  /// Send the traces of the taps before, before a new try of a tap that
  /// waits: a [send] that is still running is waited for, and then the
  /// parts no route carried when their tap ended go, the newest tap's
  /// first ([ReportQueue.sendFirst]). The traces that waited longer are
  /// left to the queue's flush. Never throws. The caller bounds the wait.
  ///
  /// ConnectFlow calls it before the config request of each try it makes
  /// after a wait, because the backend reads a phone's traces when it
  /// answers that request (its rescue rule). The backend's first wait was
  /// 5 s on 2026-10-23, and an upload that times out takes 10 s, so the
  /// trace sent when the tap ended can still be on its way then. In the
  /// 24 h to that evening, 148 taps that found every door closed were
  /// followed by a direct config request after the tap's estimated end,
  /// and for 61 of them the trace was stored before that request.
  Future<void> sendWaiting() async {
    try {
      if (!_enabled()) return;
      await Future.wait(_sending.toList());
      await _queue.sendFirst();
    } catch (e) {
      debugPrint('ConnectTraces: could not send the waiting traces: $e');
    }
  }

  static Future<String?> _read(Future<String?> Function() read) async {
    try {
      return await read();
    } catch (_) {
      return null;
    }
  }
}
