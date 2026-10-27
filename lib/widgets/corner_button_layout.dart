import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// The middle of the home screen: a centred column (the power button and
/// its status) and a round button in the bottom end corner, laid out so
/// the button never covers the column.
///
/// It goes inside the scroll view that holds the column, with the height
/// of that view as its minimum height. Three cases, in order:
///
/// 1. The column is narrow enough for the button to fit beside it. The
///    column is centred as before and the button sits in the corner.
/// 2. The column is wider, so it moves up to clear the button: centred in
///    the room above the button while there is room for that, else just
///    above it.
/// 3. The column and the button do not both fit. The column starts at the
///    top and the button sits under it, at the end of what scrolls.
///
/// The button sits [bottom] above the bottom of the view, which is the top
/// of whatever the screen puts under the view. When that grows, the view
/// shrinks and the button moves up with it.
///
/// Its distance from the side is [minEdge] at least, so it lines up with
/// the server card under it. On a narrow screen that can leave no room
/// beside the column, and on a short one the column cannot move up enough
/// either, which would put the button under the column, out of view. Only
/// then it moves closer to the side, down to [leastEdge], to sit beside
/// the column in view.
///
/// A button that draws nothing (the chatbot button while the chat is off)
/// takes no room, and the column is centred exactly as it was without it.
///
/// A centred column keeps at least [topRoom] above it while the view has
/// that much to spare, so what it draws past its top edge (the power
/// button's glow) is not cut by the view. With less to spare it moves down
/// by what there is, and it never moves out of the view.
class CornerButtonLayout extends MultiChildRenderObjectWidget {
  CornerButtonLayout({
    super.key,
    required Widget content,
    required Widget button,
    required this.besideWidth,
    this.bottom = 14,
    this.clearance = 8,
    this.minEdge = 20,
    this.maxEdge = 20,
    this.leastEdge = 12,
    this.topRoom = 0,
  }) : super(children: [content, button]);

  /// The width the column takes in its usual state. The button's distance
  /// from the side of the screen is chosen so it fits beside that width.
  final double besideWidth;

  /// From the bottom of the view to the bottom of the button.
  final double bottom;

  /// Between the column and the top of the button, when the column has to
  /// move up for it.
  final double clearance;

  /// The least and the most distance from the side of the screen to the
  /// button. The least is the side margin of the server card under it, so
  /// the two line up on every width.
  final double minEdge;
  final double maxEdge;

  /// The least distance from the side, used only when the button would
  /// otherwise be out of view.
  final double leastEdge;

  /// The room kept above a centred column when the view has it to spare.
  final double topRoom;

  @override
  RenderCornerButtonLayout createRenderObject(BuildContext context) =>
      RenderCornerButtonLayout(
        textDirection: Directionality.of(context),
        besideWidth: besideWidth,
        bottom: bottom,
        clearance: clearance,
        minEdge: minEdge,
        maxEdge: maxEdge,
        leastEdge: leastEdge,
        topRoom: topRoom,
      );

  @override
  void updateRenderObject(
    BuildContext context,
    RenderCornerButtonLayout renderObject,
  ) {
    renderObject
      ..textDirection = Directionality.of(context)
      ..besideWidth = besideWidth
      ..bottom = bottom
      ..clearance = clearance
      ..minEdge = minEdge
      ..maxEdge = maxEdge
      ..leastEdge = leastEdge
      ..topRoom = topRoom;
  }
}

class CornerButtonParentData extends ContainerBoxParentData<RenderBox> {}

class RenderCornerButtonLayout extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, CornerButtonParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, CornerButtonParentData> {
  RenderCornerButtonLayout({
    required TextDirection textDirection,
    required double besideWidth,
    required double bottom,
    required double clearance,
    required double minEdge,
    required double maxEdge,
    required double leastEdge,
    double topRoom = 0,
  }) : _textDirection = textDirection,
       _besideWidth = besideWidth,
       _bottom = bottom,
       _clearance = clearance,
       _minEdge = minEdge,
       _maxEdge = maxEdge,
       _leastEdge = leastEdge,
       _topRoom = topRoom;

  TextDirection _textDirection;
  set textDirection(TextDirection value) {
    if (value == _textDirection) return;
    _textDirection = value;
    markNeedsLayout();
  }

  double _besideWidth;
  set besideWidth(double value) {
    if (value == _besideWidth) return;
    _besideWidth = value;
    markNeedsLayout();
  }

  double _bottom;
  set bottom(double value) {
    if (value == _bottom) return;
    _bottom = value;
    markNeedsLayout();
  }

  double _clearance;
  set clearance(double value) {
    if (value == _clearance) return;
    _clearance = value;
    markNeedsLayout();
  }

  double _minEdge;
  set minEdge(double value) {
    if (value == _minEdge) return;
    _minEdge = value;
    markNeedsLayout();
  }

  double _maxEdge;
  set maxEdge(double value) {
    if (value == _maxEdge) return;
    _maxEdge = value;
    markNeedsLayout();
  }

  double _leastEdge;
  set leastEdge(double value) {
    if (value == _leastEdge) return;
    _leastEdge = value;
    markNeedsLayout();
  }

  double _topRoom;
  set topRoom(double value) {
    if (value == _topRoom) return;
    _topRoom = value;
    markNeedsLayout();
  }

  /// Between the power button and the chatbot button side by side.
  static const double _gap = 2;

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! CornerButtonParentData) {
      child.parentData = CornerButtonParentData();
    }
  }

  @override
  void performLayout() {
    final content = firstChild!;
    final button = childAfter(content)!;
    final width = constraints.maxWidth.isFinite
        ? constraints.maxWidth
        : constraints.minWidth;
    content.layout(BoxConstraints(maxWidth: width), parentUsesSize: true);
    button.layout(BoxConstraints(maxWidth: width), parentUsesSize: true);
    final view = constraints.minHeight;
    final (:top, :height, :edge, :beside) = _place(
      width,
      view,
      content.size,
      button.size,
    );
    size = constraints.constrain(Size(width, height));

    (content.parentData! as CornerButtonParentData).offset = Offset(
      (size.width - content.size.width) / 2,
      top,
    );
    // Beside a column taller than the view, the button stays in the
    // corner of the part on screen before any scrolling.
    final floor = beside ? math.min(view, size.height) : size.height;
    final x = _textDirection == TextDirection.ltr
        ? size.width - edge - button.size.width
        : edge;
    (button.parentData! as CornerButtonParentData).offset = Offset(
      x,
      floor - _bottom - button.size.height,
    );
  }

  /// Where the column goes in a view [view] tall, for a column of size
  /// [content] and a button of size [button]: the column's top, the
  /// layout's height, the button's distance from the side, and whether the
  /// button sits beside the column. See the cases in [CornerButtonLayout].
  ({double top, double height, double edge, bool beside}) _place(
    double width,
    double view,
    Size content,
    Size button,
  ) {
    final h = content.height;
    final hasButton = !button.isEmpty;

    // As far from the side as fits beside the usual width, within the
    // margins.
    final fits = (width - _besideWidth) / 2 - button.width - _gap;
    var edge = fits.clamp(_minEdge, math.max(_minEdge, _maxEdge)).toDouble();
    // The gap is kept from the usual width only: a status line a little
    // wider than the power button may come up to the button, never under.
    bool besideAt(double edge) =>
        content.width <= width - 2 * (edge + button.width);
    var beside = besideAt(edge);
    final reserve = button.height + _bottom + _clearance;
    // Under the column, the button would be out of view until the user
    // scrolls. Closer to the side, beside the column, it is in view.
    if (hasButton &&
        !beside &&
        h + reserve > view &&
        fits >= _leastEdge &&
        besideAt(fits)) {
      edge = fits;
      beside = true;
    }

    // Centred in [room] above the column's top, but at least [topRoom]
    // down while there is that much room.
    double centred(double room) =>
        math.max(room / 2, math.min(_topRoom, room)).toDouble();

    double top;
    double height;
    if (!hasButton || beside) {
      height = math.max(view, h);
      top = centred(height - h);
    } else if (h + 2 * reserve <= view) {
      height = view;
      // Never down into the room the button keeps under the column.
      top = math.min(centred(view - h), view - reserve - h);
    } else if (h + reserve <= view) {
      height = view;
      top = view - reserve - h;
    } else {
      height = h + reserve;
      top = 0;
    }
    return (top: top, height: height, edge: edge, beside: beside);
  }

  /// Whether the column would be wholly in view, before any scrolling, in
  /// a view [viewChange] taller than this one, or shorter when it is
  /// negative. With [through], a part of the column, only the column down
  /// to the bottom of that part counts. It goes by the children as they are
  /// laid out now and moves nothing, so a screen can ask it before it puts
  /// something under the view (or takes something away), to tell whether
  /// the column would stay in sight without a frame drawn to find out. True
  /// when it cannot be told: nothing laid out yet, or [through] not in the
  /// column.
  bool fitsWith(double viewChange, {RenderBox? through}) {
    final content = firstChild;
    final button = content == null ? null : childAfter(content);
    if (!hasSize || content == null || button == null) return true;
    if (!content.hasSize || !button.hasSize) return true;
    var bottom = content.size.height;
    if (through != null) {
      if (!through.attached || !through.hasSize) return true;
      RenderObject? up = through;
      while (up != null && up != content) {
        up = up.parent;
      }
      if (up == null) return true;
      bottom = through
          .localToGlobal(Offset(0, through.size.height), ancestor: content)
          .dy;
    }
    final view = constraints.minHeight + viewChange;
    final top = _place(size.width, view, content.size, button.size).top;
    return top >= -0.5 && top + bottom <= view + 0.5;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    defaultPaint(context, offset);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    return defaultHitTestChildren(result, position: position);
  }
}
