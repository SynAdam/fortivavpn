import 'package:flutter/material.dart';

import '../../core/design_system.dart';
import '../../utils/number_localizer.dart';

/// Three rounded bars of rising height, the way phones show signal. [level]
/// of them (0 to 3) are lit in [color], the rest in steel.
class SignalBars extends StatelessWidget {
  const SignalBars({
    super.key,
    required this.level,
    required this.color,
    this.size = 14,
  });

  /// How many bars are lit, clamped to 0..3.
  final int level;
  final Color color;

  /// The width and height of the square the bars stand in.
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: SignalBarsPainter(level: level.clamp(0, 3), color: color),
      ),
    );
  }
}

/// Paints [SignalBars]. Public so tests can read what it draws.
class SignalBarsPainter extends CustomPainter {
  SignalBarsPainter({required this.level, required this.color});

  final int level;
  final Color color;

  /// The bars' heights as a share of the box, shortest first.
  static const List<double> heights = [0.45, 0.72, 1.0];

  @override
  void paint(Canvas canvas, Size size) {
    // Three bars and two gaps, each gap half a bar wide.
    final bar = size.width / 4;
    final gap = bar / 2;
    for (var i = 0; i < 3; i++) {
      final h = size.height * heights[i];
      final left = i * (bar + gap);
      final rect = Rect.fromLTWH(left, size.height - h, bar, h);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(bar / 2)),
        Paint()..color = i < level ? color : AppDesign.steelDark,
      );
    }
  }

  @override
  bool shouldRepaint(SignalBarsPainter old) =>
      old.level != level || old.color != color;
}

/// A reply time: signal bars in the color of that time
/// ([AppDesign.latencyColor]) and "{n} ms" in a quiet text color. A
/// negative [ms] means no reply, and shows [timeoutLabel], the call site's
/// own localized string, in the error color.
///
/// Only the bars carry the color. Most replies from Iran take 150 to 300
/// ms, so a number drawn in the warning gold showed up on nearly every
/// visit, beside the mint of a working tunnel, and read as a problem.
///
/// The text is its own Text, so a test that finds "191 ms" still finds it.
class LatencyChip extends StatelessWidget {
  const LatencyChip({super.key, required this.ms, this.timeoutLabel});

  final int ms;
  final String? timeoutLabel;

  @override
  Widget build(BuildContext context) {
    final color = AppDesign.latencyColor(ms);
    final label = ms < 0
        ? (timeoutLabel ?? '')
        : NumberLocalizer.localize('$ms ms', context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SignalBars(level: AppDesign.latencyLevel(ms), color: color),
        const SizedBox(width: AppDesign.space6),
        Text(
          label,
          maxLines: 1,
          // The number and its unit read left to right in every language:
          // in a right to left line "۴۲ ms" came out as "ms ۴۲". The
          // timeout words keep the line's own direction.
          textDirection: ms < 0 ? null : TextDirection.ltr,
          style: AppDesign.textTheme.labelMedium?.copyWith(
            color: ms < 0 ? AppDesign.error : AppDesign.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            fontFeatures: AppDesign.numberFeatures,
          ),
        ),
      ],
    );
  }
}
