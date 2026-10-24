import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/design_system.dart';
import '../l10n/generated/app_localizations.dart';

/// The assistant's side of the chat while a question waits for its answer:
/// three dots in a soft wave and a line that says how far along it is.
///
/// Replies come by fetching, after the backend's checks, so there is no
/// partial answer to show. This is what the wait looks like instead. The
/// line changes with the time since the question was asked: reading it,
/// then looking for the answer, then writing it, then a thank you for
/// waiting when it takes unusually long.
///
/// It animates only while it is on screen, and a timer wakes it only when
/// the line is due to change. With less motion asked for, the dots and the
/// line keep still.
class ThinkingBubble extends StatefulWidget {
  const ThinkingBubble({super.key, required this.since, required this.now});

  /// When the question was asked, on the server's clock.
  final DateTime since;

  /// The server's clock.
  final DateTime Function() now;

  /// When the line moves on, counted from [since].
  static const searchingAfter = Duration(seconds: 3);
  static const writingAfter = Duration(seconds: 10);
  static const stillAfter = Duration(seconds: 45);

  /// The line for a question asked [elapsed] ago.
  static String line(S l10n, Duration elapsed) {
    if (elapsed >= stillAfter) return l10n.supportThinkingStill;
    if (elapsed >= writingAfter) return l10n.supportThinkingWriting;
    if (elapsed >= searchingAfter) return l10n.supportThinkingSearching;
    return l10n.supportThinkingReading;
  }

  @override
  State<ThinkingBubble> createState() => _ThinkingBubbleState();
}

class _ThinkingBubbleState extends State<ThinkingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _wave = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  /// Wakes the bubble when its line is due to change.
  Timer? _next;

  @override
  void initState() {
    super.initState();
    _schedule();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _wave.stop();
      _wave.value = 0.5;
    } else if (!_wave.isAnimating) {
      unawaited(_wave.repeat());
    }
  }

  @override
  void didUpdateWidget(ThinkingBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.since != widget.since) _schedule();
  }

  Duration _elapsed() {
    final elapsed = widget.now().difference(widget.since);
    return elapsed.isNegative ? Duration.zero : elapsed;
  }

  void _schedule() {
    _next?.cancel();
    _next = null;
    final elapsed = _elapsed();
    for (final at in const [
      ThinkingBubble.searchingAfter,
      ThinkingBubble.writingAfter,
      ThinkingBubble.stillAfter,
    ]) {
      if (elapsed < at) {
        _next = Timer(at - elapsed, () {
          if (!mounted) return;
          setState(() {});
          _schedule();
        });
        return;
      }
    }
  }

  @override
  void dispose() {
    _next?.cancel();
    _wave.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context)!;
    final line = ThinkingBubble.line(l10n, _elapsed());
    final still = MediaQuery.disableAnimationsOf(context);
    final style = Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: AppDesign.textSecondary,
      letterSpacing: AppDesign.ls(0),
    );
    final switcher = AnimatedSwitcher(
      duration: AppMotion.medium,
      // Both lines at the start while one fades into the other, so neither
      // moves sideways as the width changes.
      layoutBuilder: (current, previous) => Stack(
        alignment: AlignmentDirectional.centerStart,
        children: [...previous, ?current],
      ),
      child: Semantics(
        key: ValueKey(line),
        liveRegion: true,
        child: still
            ? Text(line, style: style)
            : _Shimmer(
                wave: _wave,
                child: Text(line, style: style),
              ),
      ),
    );
    return Container(
      key: const ValueKey('support-thinking'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      // The same fill as the assistant's replies, with no edge, so the
      // answer takes its place without a change of look.
      decoration: const BoxDecoration(
        color: AppDesign.surfaceLow,
        // The small corner points up at the assistant's face, as on its
        // replies.
        borderRadius: BorderRadiusDirectional.only(
          topStart: Radius.circular(4),
          topEnd: Radius.circular(14),
          bottomStart: Radius.circular(14),
          bottomEnd: Radius.circular(14),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Dots(wave: _wave),
          const SizedBox(width: AppDesign.space8),
          Flexible(
            child: still
                ? switcher
                // The lines differ in length, so the bubble eases to the
                // width of the next one rather than snapping to it.
                : AnimatedSize(
                    duration: AppMotion.medium,
                    curve: AppMotion.emphasizedDecelerate,
                    alignment: AlignmentDirectional.centerStart,
                    child: switcher,
                  ),
          ),
        ],
      ),
    );
  }
}

/// Three dots that rise and brighten one after another.
class _Dots extends StatelessWidget {
  const _Dots({required this.wave});

  final Animation<double> wave;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: wave,
        builder: (context, _) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 3; i++) ...[
              if (i > 0) const SizedBox(width: 4),
              _dot(_lift(wave.value - i * 0.16)),
            ],
          ],
        ),
      ),
    );
  }

  /// The width of one dot.
  static const double _size = 7;

  /// 0 at rest, 1 at the top of the wave.
  static double _lift(double t) {
    final phase = t - t.floorToDouble();
    return 0.5 - 0.5 * math.cos(phase * 2 * math.pi);
  }

  Widget _dot(double lift) => Transform.translate(
    offset: Offset(0, -3 * lift),
    child: Container(
      width: _size,
      height: _size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        // Steel, as the assistant's face: green here would read as the
        // connection's state.
        color: AppDesign.steelLight.withValues(alpha: 0.45 + 0.55 * lift),
      ),
    ),
  );
}

/// A light that sweeps across its child, start to end.
class _Shimmer extends StatelessWidget {
  const _Shimmer({required this.wave, required this.child});

  final Animation<double> wave;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return AnimatedBuilder(
      animation: wave,
      child: child,
      builder: (context, child) {
        final t = rtl ? 1 - wave.value : wave.value;
        final center = -0.3 + 1.6 * t;
        return ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) => LinearGradient(
            colors: const [
              AppDesign.textSecondary,
              AppDesign.textPrimary,
              AppDesign.textSecondary,
            ],
            stops: [
              (center - 0.25).clamp(0.0, 1.0),
              center.clamp(0.0, 1.0),
              (center + 0.25).clamp(0.0, 1.0),
            ],
          ).createShader(bounds),
          child: child,
        );
      },
    );
  }
}
