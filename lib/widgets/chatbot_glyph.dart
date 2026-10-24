import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/design_system.dart';

/// The chatbot mark: a rounded chat bubble with a short tail, a bot face
/// with two eyes and a smile, and an antenna on top.
///
/// Drawn from paths on a 24 by 24 grid, the way Material icons are, so it
/// is sharp at every size. The face is a hole in the bubble rather than
/// paint on it, so it shows whatever lies under the mark: the steel of the
/// chat's avatar, the tonal disc of the home screen's chat button, or the
/// dark of the page.
///
/// It is a logo, so it is not mirrored in right-to-left layouts. It is
/// decoration and says nothing to a screen reader; the button or the header
/// it sits in carries the label.
class ChatbotGlyph extends StatelessWidget {
  const ChatbotGlyph({
    super.key,
    this.size = 24,
    this.color = AppDesign.textPrimary,
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: ChatbotGlyphPainter(color)),
    );
  }
}

class ChatbotGlyphPainter extends CustomPainter {
  const ChatbotGlyphPainter(this.color);

  final Color color;

  /// The grid the mark is drawn on.
  static const double grid = 24;

  /// The smile: an arc around this centre, as wide as a stroke of
  /// [_smileStroke].
  static const Offset _smileCentre = Offset(12, 12.2);
  static const double _smileRadius = 3.6;
  static const double _smileStroke = 1.5;
  static const double _smileFrom = math.pi * 0.27;
  static const double _smileSweep = math.pi * 0.46;

  /// The bubble with the eyes and the smile as holes in it. The holes come
  /// from the even-odd rule, not from clearing pixels, so the mark needs no
  /// layer of its own: a layer is an offscreen pass on every frame the home
  /// screen draws, and that adds up on a low-end phone.
  static Path _face() {
    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRRect(RRect.fromLTRBR(2, 5.6, 22, 18.6, const Radius.circular(5.6)))
      ..addRRect(
        RRect.fromLTRBR(7.3, 9.2, 9.9, 13.0, const Radius.circular(1.3)),
      )
      ..addRRect(
        RRect.fromLTRBR(14.1, 9.2, 16.7, 13.0, const Radius.circular(1.3)),
      );

    // The outline of a stroked arc with round caps, as one closed shape.
    const half = _smileStroke / 2;
    const to = _smileFrom + _smileSweep;
    Offset at(double radius, double angle) =>
        _smileCentre +
        Offset(math.cos(angle) * radius, math.sin(angle) * radius);
    final start = at(_smileRadius + half, _smileFrom);
    final smile = Path()
      ..moveTo(start.dx, start.dy)
      ..arcTo(
        Rect.fromCircle(center: _smileCentre, radius: _smileRadius + half),
        _smileFrom,
        _smileSweep,
        false,
      )
      ..arcTo(
        Rect.fromCircle(center: at(_smileRadius, to), radius: half),
        to,
        math.pi,
        false,
      )
      ..arcTo(
        Rect.fromCircle(center: _smileCentre, radius: _smileRadius - half),
        to,
        -_smileSweep,
        false,
      )
      ..arcTo(
        Rect.fromCircle(center: at(_smileRadius, _smileFrom), radius: half),
        _smileFrom + math.pi,
        math.pi,
        false,
      )
      ..close();
    return path..addPath(smile, Offset.zero);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final unit = size.shortestSide / grid;
    if (unit <= 0) return;
    canvas.save();
    canvas.translate(
      (size.width - unit * grid) / 2,
      (size.height - unit * grid) / 2,
    );
    canvas.scale(unit);

    final fill = Paint()
      ..color = color
      ..isAntiAlias = true;

    // The antenna: a ball on a short stem.
    canvas.drawCircle(const Offset(12, 2.7), 1.8, fill);
    canvas.drawRRect(
      RRect.fromLTRBR(11.2, 3.6, 12.8, 6.6, const Radius.circular(0.8)),
      fill,
    );

    // The bubble with its face. Its own path, because the tail overlaps
    // the bubble, and under the even-odd rule the overlap would be a hole.
    canvas.drawPath(_face(), fill);

    // The tail at the bottom left. It stays clear of the smile.
    final tail = Path()
      ..moveTo(5.4, 16.4)
      ..quadraticBezierTo(5.6, 20.2, 3.6, 22.2)
      ..quadraticBezierTo(8.8, 21.8, 11.8, 18.2)
      ..close();
    canvas.drawPath(tail, fill);

    canvas.restore();
  }

  @override
  bool shouldRepaint(ChatbotGlyphPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// The chatbot mark on a steel disc: the face of the assistant in the chat
/// header, beside its answers and on the empty chat.
///
/// Steel like the shield, with no colored glow, so it never reads as a
/// connection state. A faint light edge lifts it off the dark page.
class ChatbotAvatar extends StatelessWidget {
  const ChatbotAvatar({super.key, this.size = 28});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: steelDisc,
      child: ChatbotGlyph(size: size * 0.62, color: AppDesign.onChatbot),
    );
  }

  /// The disc the assistant and our team are drawn on. The home screen's
  /// chat button takes its shape with a darker tonal fill, so it stays
  /// quieter than the connect button.
  static final BoxDecoration steelDisc = BoxDecoration(
    shape: BoxShape.circle,
    gradient: AppDesign.chatbotGradient,
    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
  );
}
