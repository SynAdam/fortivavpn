import 'package:flutter/material.dart';

import '../core/design_system.dart';
import 'power_face.dart';

/// A soft light behind the home screen's hero area, tinted by the power
/// button's [face]: a faint mint when protected, faint amber or red when
/// something is wrong, faint steel otherwise.
///
/// It is one static radial gradient, centred on the button ([alignment]),
/// painted under [child] and cut at [child]'s edges, so give it a box that
/// runs to the sides of the screen. A change of face crossfades the tint
/// over 450ms; at rest it schedules no frames. It never changes the size of
/// [child].
class StateWash extends StatelessWidget {
  const StateWash({
    super.key,
    required this.face,
    required this.child,
    this.alignment = center,
  });

  final PowerFace face;
  final Widget child;

  /// Where the light is centred in the box: on the button. The box decides
  /// where that is, so a layout that puts the button elsewhere in its box
  /// passes its own.
  final Alignment alignment;

  /// Where the light is centred in the phone's hero area: on the button,
  /// which sits above the status line there.
  static const Alignment center = Alignment(0, -0.35);

  /// The light's reach, as a share of the box's shorter side.
  static const double reach = 0.85;

  /// The tint at the centre of the light for [face]. Fully transparent for
  /// none, in the steel hue, so a fade to none never passes through grey.
  static Color tintFor(PowerFace face) => switch (face) {
    PowerFace.off => AppDesign.steelMid.withValues(alpha: 0.05),
    PowerFace.connecting ||
    PowerFace.verifying => AppDesign.steelLight.withValues(alpha: 0.06),
    PowerFace.connected => AppDesign.protected.withValues(alpha: 0.11),
    PowerFace.stalled => AppDesign.warning.withValues(alpha: 0.07),
    PowerFace.failed => AppDesign.error.withValues(alpha: 0.07),
    PowerFace.spent => AppDesign.steelMid.withValues(alpha: 0),
    PowerFace.disconnecting => AppDesign.steelMid.withValues(alpha: 0.05),
  };

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<Color?>(
      tween: ColorTween(end: tintFor(face)),
      duration: AppMotion.reduced(context)
          ? Duration.zero
          : AppMotion.emphasized,
      curve: AppMotion.emphasizedDecelerate,
      // Its own layer, so the tint's crossfade repaints the light alone and
      // not the hero drawn over it.
      child: RepaintBoundary(child: child),
      builder: (context, tint, child) => CustomPaint(
        painter: _WashPainter(tint ?? tintFor(face), alignment),
        child: child,
      ),
    );
  }
}

class _WashPainter extends CustomPainter {
  _WashPainter(this.tint, this.alignment);

  final Color tint;
  final Alignment alignment;

  /// How the light falls off from the centre, as shares of the tint's
  /// strength: quickly at first, then a long soft tail, so where the box
  /// cuts it the step is faint.
  static const List<double> _falloff = [1, 0.55, 0.2, 0.05, 0];
  static const List<double> _stops = [0, 0.25, 0.5, 0.75, 1];

  @override
  void paint(Canvas canvas, Size size) {
    if (tint.a == 0 || size.isEmpty) return;
    final rect = Offset.zero & size;
    final gradient = RadialGradient(
      center: alignment,
      radius: StateWash.reach,
      colors: [for (final f in _falloff) tint.withValues(alpha: tint.a * f)],
      stops: _stops,
    );
    canvas.drawRect(rect, Paint()..shader = gradient.createShader(rect));
  }

  @override
  bool shouldRepaint(_WashPainter old) =>
      old.tint != tint || old.alignment != alignment;
}
