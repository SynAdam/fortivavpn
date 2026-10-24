import 'dart:async';

import 'package:flutter/material.dart';

import '../core/design_system.dart';
import '../core/state/connect_flow.dart';
import '../l10n/generated/app_localizations.dart';
import '../services/path_finder.dart';
import '../utils/number_localizer.dart';
import 'server_title.dart';

/// The search, as the user watches it (clients #342).
///
/// A tap tries three kinds of route in turn, and the list shows each as a
/// stage: this device's own servers, then the community servers, then the
/// backup network ([RouteKind]). A line over the list says which stage of
/// how many runs now, or, while the app waits to try again, when the next
/// try starts and with which stage. The internet check comes first.
///
/// Each stage is pending, running, connected, failed or skipped, as the
/// flow says ([ConnectFlow.stageState]). Only the running stage shows its
/// rows. A finished one is one line, such as "6 paths tried, blocked here",
/// so the list stays short on a phone. Nothing here says the user is
/// protected before the tunnel is verified: a stage reads connected only
/// once it is.
///
/// Rows are named by place and number rather than by protocol, because
/// "Helsinki, path 3" tells a user what is happening and "Reality over
/// XHTTP" does not; the protocol still travels to the backend.
class PathChecklist extends StatelessWidget {
  const PathChecklist({
    super.key,
    required this.flow,
    this.clock,
    this.gettingServers = false,
  });

  final ConnectFlow flow;

  /// The time the countdown to the next try reads. Tests pass their own.
  final DateTime Function()? clock;

  /// Whether the tap waits for this device's own servers before its first
  /// try: on a phone that has none yet, for up to a few seconds
  /// (connectFromButton). The first stage runs then, with one row that says
  /// so, rather than a bare "Connecting".
  final bool gettingServers;

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context)!;
    if (gettingServers) return _gettingServers(context, l10n);
    final stage = flow.stage;
    final chosen = flow.chosen;
    // The finder keeps the last try's rows until this try checks its first
    // door: on the fast path they are not shown.
    final fresh = flow.checksAreThisTry;
    final checks = fresh ? flow.checks : const <PathCheck>[];

    // Number the doors per place, so the third door on Helsinki is
    // "Helsinki, path 3" whatever position it holds in the whole list.
    // Keyed by the name the row shows, not the door's id: every door has
    // its own id, so on 2026-10-05 three doors read "Nuremberg, path 1",
    // and two servers in one city would still share a label by server.
    final perServer = <String, int>{};
    final rows = {for (final k in RouteKind.values) k: <_Entry>[]};
    final tried = {for (final k in RouteKind.values) k: <PathCheck>[]};

    // The fast path's dial, from its first second: the door that last
    // worked on this network, or a shared link the user picked.
    final fast = flow.fastPathDoor;
    if (fast != null) {
      final title = serverTitle(context, fast);
      rows[RouteKind.of(fast)]!.add((
        row: _Row(
          key: const ValueKey('fast'),
          label: fast.isDedicated
              ? l10n.stageLastWorked(title)
              : l10n.diagConnectingThrough(title),
          state: _Step.running,
        ),
        check: null,
      ));
    }

    for (final c in checks) {
      final title = serverTitle(context, c.path);
      final n = (perServer[title] ?? 0) + 1;
      perServer[title] = n;
      final kind = RouteKind.of(c.path);
      if (c.reportable) tried[kind]!.add(c);
      rows[kind]!.add((
        check: c.state,
        row: _Row(
          key: ValueKey('path $title $n'),
          // Localised digits: "مسیر ۳", not "مسیر 3".
          label: NumberLocalizer.localize(l10n.diagPathRow(title, n), context),
          state: switch (c.state) {
            PathCheckState.pending => _Step.pending,
            PathCheckState.running => _Step.running,
            PathCheckState.open => _Step.done,
            PathCheckState.blocked => _Step.failed,
            PathCheckState.skipped => _Step.skipped,
          },
          detail: switch (c.state) {
            PathCheckState.open when c.ms != null =>
              '${l10n.diagOpen} · ${NumberLocalizer.localize('${c.ms} ms', context)}',
            PathCheckState.open => l10n.diagOpen,
            PathCheckState.blocked => l10n.diagBlocked,
            PathCheckState.skipped => l10n.diagSkipped,
            _ => null,
          },
        ),
      ));
    }
    if (chosen != null &&
        (stage == ConnectStage.connecting ||
            stage == ConnectStage.done ||
            stage == ConnectStage.failed)) {
      rows[RouteKind.of(chosen)]!.add((
        row: _Row(
          key: const ValueKey('through'),
          label: l10n.diagConnectingThrough(serverTitle(context, chosen)),
          state: switch (stage) {
            ConnectStage.connecting => _Step.running,
            ConnectStage.done => _Step.done,
            _ => _Step.failed,
          },
        ),
        check: null,
      ));
    }

    final progress = flow.stageProgress;
    final next = flow.nextTryFrom;
    final retryAt = flow.retryAt;
    final Widget? caption = progress != null
        ? _Caption(
            NumberLocalizer.localize(
              l10n.stageProgress(progress.number, progress.count),
              context,
            ),
          )
        // The wait is over, and the next try is being made ready.
        : next != null && flow.nextTryStarting
        ? _Caption(
            l10n.stageNextTryStarting(stageName(l10n, next)),
            key: const ValueKey('next try starting'),
          )
        : next != null && retryAt != null
        ? _Countdown(
            key: const ValueKey('next try'),
            until: retryAt,
            stage: stageName(l10n, next),
            clock: clock ?? DateTime.now,
          )
        : null;

    return _frame([
      ?caption,
      // Running until the control fetch answers or a check finds a
      // door open (PathFinder.internet). With no site abroad reached
      // and one inside the country reached, it says the way abroad is
      // cut, which is why every door below reads blocked. Not on the
      // fast path, which makes no such check.
      if (fresh)
        _Row(
          key: const ValueKey('internet'),
          label: flow.internet == false && flow.cut == true
              ? l10n.diagInternationalCut
              : l10n.diagCheckingInternet,
          state: switch (flow.internet) {
            null => _Step.running,
            true => _Step.done,
            false => _Step.failed,
          },
        ),
      for (final kind in RouteKind.values)
        if (flow.stageAvailable(kind))
          _StageGroup(
            key: ValueKey('stage ${kind.name}'),
            name: stageName(l10n, kind),
            state: flow.stageState(kind),
            summary: _summary(context, flow.stageState(kind), tried[kind]!),
            rows: _fold(context, rows[kind]!),
          ),
    ]);
  }

  /// The list's frame around [children].
  static Widget _frame(List<Widget> children) => Padding(
    padding: const EdgeInsetsDirectional.fromSTEB(32, 16, 32, 0),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    ),
  );

  /// The stages while the tap waits for this device's own servers
  /// ([gettingServers]): the first one runs, with a row that says it gets
  /// them, and the others are still to come. None of the last try's state
  /// shows: this try has not started.
  Widget _gettingServers(BuildContext context, S l10n) {
    final shown = [
      RouteKind.own,
      RouteKind.community,
      if (flow.backupMayRun) RouteKind.backup,
    ];
    return _frame([
      _Caption(
        NumberLocalizer.localize(l10n.stageProgress(1, shown.length), context),
      ),
      for (final kind in shown)
        _StageGroup(
          key: ValueKey('stage ${kind.name}'),
          name: stageName(l10n, kind),
          state: kind == RouteKind.own
              ? StageState.running
              : StageState.pending,
          rows: [
            if (kind == RouteKind.own)
              _Row(
                key: const ValueKey('getting servers'),
                label: l10n.stageGettingServers,
                state: _Step.running,
              ),
          ],
        ),
    ]);
  }

  /// The most lines the running stage shows. Its paths that read blocked
  /// fold into one line, and paths still to check past the room into
  /// another, so the stages after it stay on a phone's screen. On
  /// 2026-10-23 a tap that found every own door blocked drew nine rows,
  /// and the list ran under the server card.
  static const int maxRows = 4;

  /// The rows of a stage ([entries], in order) as the screen shows them,
  /// at most [maxRows] lines when they do not all fit. Paths that read
  /// blocked become one line, "8 paths tried, blocked here". Then the dial
  /// in flight and the paths being checked or found open, every one of
  /// them, and paths still to check while there is room. The ones left
  /// over become one line, "3 more paths to check".
  static List<Widget> _fold(BuildContext context, List<_Entry> entries) {
    if (entries.length <= maxRows) return [for (final e in entries) e.row];
    final l10n = S.of(context)!;
    bool blocked(_Entry e) => e.check == PathCheckState.blocked;
    bool waiting(_Entry e) =>
        e.check == PathCheckState.pending || e.check == PathCheckState.skipped;
    final closed = entries.where(blocked).length;
    final rest = [
      for (final e in entries)
        if (!blocked(e)) e,
    ];
    final shown = <Widget>[
      if (closed > 0)
        _Row(
          key: const ValueKey('blocked'),
          label: NumberLocalizer.localize(
            l10n.stageTriedBlocked(closed),
            context,
          ),
          state: _Step.failed,
        ),
    ];
    if (shown.length + rest.length <= maxRows) {
      return [...shown, for (final e in rest) e.row];
    }
    // One line is kept for the paths left over.
    final active = rest.where((e) => !waiting(e)).length;
    var room = maxRows - shown.length - 1 - active;
    var left = 0;
    for (final e in rest) {
      if (!waiting(e)) {
        shown.add(e.row);
      } else if (room > 0) {
        room--;
        shown.add(e.row);
      } else {
        left++;
      }
    }
    if (left > 0) {
      shown.add(
        _Row(
          key: const ValueKey('more'),
          label: NumberLocalizer.localize(l10n.stageMoreToCheck(left), context),
          state: _Step.pending,
        ),
      );
    }
    return shown;
  }

  /// What a stage is called on screen.
  static String stageName(S l10n, RouteKind kind) => switch (kind) {
    RouteKind.own => l10n.stageOwn,
    RouteKind.community => l10n.stageCommunity,
    RouteKind.backup => l10n.backupNetworkTitle,
  };

  /// The one line a stage that is not running shows under its name, from
  /// its rows that have a result ([tried]). Null for a stage still to come
  /// and for the running one, whose rows say more.
  static String? _summary(
    BuildContext context,
    StageState state,
    List<PathCheck> tried,
  ) {
    final l10n = S.of(context)!;
    switch (state) {
      case StageState.pending || StageState.running:
        return null;
      case StageState.connected:
        return l10n.stageConnected;
      case StageState.skipped:
        return l10n.stageSkipped;
      case StageState.failed:
        if (tried.isEmpty) return l10n.stageNotConnected;
        final blocked = tried.every((c) => c.state == PathCheckState.blocked);
        final line = blocked
            ? l10n.stageTriedBlocked(tried.length)
            : l10n.stageTriedFailed(tried.length);
        return NumberLocalizer.localize(line, context);
    }
  }
}

/// The small line over the list: the stage that runs now, or when the next
/// try starts.
class _Caption extends StatelessWidget {
  const _Caption(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppDesign.space8),
    child: Text(
      text,
      style: AppDesign.textTheme.labelMedium?.copyWith(
        color: AppDesign.textTertiary,
        fontFeatures: AppDesign.numberFeatures,
      ),
    ),
  );
}

/// While the app waits to try again: which stage the next try starts with,
/// and a countdown to it, a second at a time.
class _Countdown extends StatefulWidget {
  const _Countdown({
    super.key,
    required this.until,
    required this.stage,
    required this.clock,
  });

  final DateTime until;
  final String stage;
  final DateTime Function() clock;

  @override
  State<_Countdown> createState() => _CountdownState();
}

class _CountdownState extends State<_Countdown> {
  late final Timer _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick.cancel();
    super.dispose();
  }

  /// [left] as minutes and seconds, "0:42", with hours in front past an
  /// hour. A second that has started counts as a whole one.
  static String clockText(Duration left) {
    final seconds = left.isNegative ? 0 : (left.inMilliseconds + 999) ~/ 1000;
    final h = seconds ~/ 3600;
    final m = seconds ~/ 60 % 60;
    final s = (seconds % 60).toString().padLeft(2, '0');
    return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context)!;
    final left = widget.until.difference(widget.clock());
    return _Caption(
      NumberLocalizer.localize(
        l10n.stageNextTry(widget.stage, clockText(left)),
        context,
      ),
    );
  }
}

/// One stage of the search: its name and mark, then its rows while it runs,
/// or one line that sums it up once it has run.
class _StageGroup extends StatelessWidget {
  const _StageGroup({
    super.key,
    required this.name,
    required this.state,
    required this.rows,
    this.summary,
  });

  final String name;
  final StageState state;
  final List<Widget> rows;
  final String? summary;

  /// How far a stage's rows are set in, so their marks line up under the
  /// stage's name.
  static const double indent = _Row.iconSize + AppDesign.space12;

  @override
  Widget build(BuildContext context) {
    final running = state == StageState.running;
    final text = AppDesign.textTheme.bodyMedium;
    final header = Padding(
      padding: const EdgeInsets.only(top: AppDesign.space8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: AppDesign.space2),
            child: _StageMark(state),
          ),
          const SizedBox(width: AppDesign.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  style: text?.copyWith(
                    color: switch (state) {
                      // The stage being tried now stands out; stages still
                      // to come and stages passed over step back.
                      StageState.running => AppDesign.textPrimary,
                      StageState.pending ||
                      StageState.skipped => AppDesign.textTertiary,
                      _ => AppDesign.textSecondary,
                    },
                    fontWeight: running ? FontWeight.w600 : null,
                  ),
                ),
                if (summary != null)
                  Text(
                    summary!,
                    style: AppDesign.textTheme.bodySmall?.copyWith(
                      color: AppDesign.textTertiary,
                      fontFeatures: AppDesign.numberFeatures,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
    if (!running || rows.isEmpty) return header;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        Padding(
          padding: const EdgeInsetsDirectional.only(start: indent),
          child: Column(mainAxisSize: MainAxisSize.min, children: rows),
        ),
      ],
    );
  }
}

/// A stage's mark. Still, never a spinner: the row being worked on has the
/// one spinner, so the eye goes to it.
class _StageMark extends StatelessWidget {
  const _StageMark(this.state);

  final StageState state;

  @override
  Widget build(BuildContext context) {
    const size = _Row.iconSize;
    return switch (state) {
      StageState.pending => const Icon(
        Icons.circle_outlined,
        size: size,
        color: AppDesign.textTertiary,
      ),
      StageState.running => const Icon(
        Icons.radio_button_checked,
        size: size,
        color: AppDesign.steelLight,
      ),
      StageState.connected => const Icon(
        Icons.check_circle_rounded,
        size: size,
        color: AppDesign.protected,
      ),
      StageState.failed => const Icon(
        Icons.cancel_rounded,
        size: size,
        color: AppDesign.error,
      ),
      StageState.skipped => const Icon(
        Icons.remove_circle_outline,
        size: size,
        color: AppDesign.textTertiary,
      ),
    };
  }
}

enum _Step { pending, running, done, failed, skipped }

/// One line of a stage before [PathChecklist._fold]: the [row] it draws,
/// and the state of the path it checks. [check] is null for the dial in
/// flight, which always shows.
typedef _Entry = ({_Row row, PathCheckState? check});

/// One line of the checklist. It fades in and rises a little when it
/// first shows, so a row that lands reads as news without anything
/// jumping; a row already on screen stays as it is while its state
/// changes.
class _Row extends StatefulWidget {
  const _Row({
    super.key,
    required this.label,
    required this.state,
    this.detail,
  });

  final String label;
  final _Step state;
  final String? detail;

  /// The size of each row's icon, and of the spinner inside its box.
  static const double iconSize = 16;
  static const double spinnerSize = 14;

  /// How far a new row rises as it fades in.
  static const double riseOffset = 6;

  @override
  State<_Row> createState() => _RowState();
}

class _RowState extends State<_Row> with SingleTickerProviderStateMixin {
  late final AnimationController _enter = AnimationController(
    vsync: this,
    duration: AppMotion.medium,
  );
  late final CurvedAnimation _curve = CurvedAnimation(
    parent: _enter,
    curve: AppMotion.emphasizedDecelerate,
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (AppMotion.reduced(context)) {
      _enter.value = 1;
    } else {
      _enter.forward();
    }
  }

  @override
  void dispose() {
    _curve.dispose();
    _enter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final muted = state == _Step.pending || state == _Step.skipped;
    final color = switch (state) {
      _Step.done => AppDesign.protected,
      _Step.failed => AppDesign.error,
      _Step.running => AppDesign.textPrimary,
      _ => AppDesign.textTertiary,
    };
    final text = AppDesign.textTheme.bodyMedium;
    const size = _Row.iconSize;
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDesign.space4),
      child: Row(
        children: [
          SizedBox.square(
            dimension: size,
            child: switch (state) {
              // Under reduced motion a still mark, not a turning one.
              _Step.running when AppMotion.reduced(context) => const Icon(
                Icons.pending_outlined,
                size: size,
                color: AppDesign.steelLight,
              ),
              _Step.running => const Center(
                child: SizedBox.square(
                  dimension: _Row.spinnerSize,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppDesign.steelLight,
                  ),
                ),
              ),
              _Step.done => Icon(
                Icons.check_circle_rounded,
                size: size,
                color: color,
              ),
              _Step.failed => Icon(
                Icons.cancel_rounded,
                size: size,
                color: color,
              ),
              _Step.skipped => Icon(
                Icons.remove_circle_outline,
                size: size,
                color: color,
              ),
              _Step.pending => Icon(
                Icons.circle_outlined,
                size: size,
                color: color,
              ),
            },
          ),
          const SizedBox(width: AppDesign.space12),
          Expanded(
            child: Text(
              widget.label,
              overflow: TextOverflow.ellipsis,
              style: text?.copyWith(
                color: switch (state) {
                  // The row being worked on now stands out; rows still to
                  // come and rows passed over step back.
                  _Step.running => AppDesign.textPrimary,
                  _ when muted => AppDesign.textTertiary,
                  _ => AppDesign.textSecondary,
                },
              ),
            ),
          ),
          if (widget.detail != null) ...[
            const SizedBox(width: AppDesign.space8),
            Text(
              widget.detail!,
              style: text?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
                // The reply time changes from door to door; the column of
                // numbers stays straight.
                fontFeatures: AppDesign.numberFeatures,
              ),
            ),
          ],
        ],
      ),
    );
    return AnimatedBuilder(
      animation: _curve,
      builder: (context, child) => Transform.translate(
        offset: Offset(0, _Row.riseOffset * (1 - _curve.value)),
        child: child,
      ),
      // A fade on one short line, for a quarter of a second: the alpha
      // layer is small and gone once the row is in.
      child: FadeTransition(opacity: _curve, child: row),
    );
  }
}

/// [_CountdownState.clockText], for tests.
@visibleForTesting
String countdownText(Duration left) => _CountdownState.clockText(left);
