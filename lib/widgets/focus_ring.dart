import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../core/form_factor.dart';

/// A ring around whatever a TV remote or a keyboard has focused.
///
/// Flutter draws a control's focus inside the control, and most of this
/// app's cards paint an opaque box over it, so on a TV nothing showed where
/// the remote was. One ring drawn over the whole app reaches every control,
/// the ones built before TVs mattered included.
///
/// On a TV only, where focus is always in keyboard mode (see main). A phone
/// never shows it, even after a key press: a hardware keyboard (or an
/// emulator typing from the computer's) puts a phone in keyboard mode, and
/// the ring then drew a second white border inside a focused text field's
/// own, such as the "Enter a code" box. Phone controls show their own
/// focus.
///
/// On a TV it also gives focus to the first control of a screen that opens
/// with nothing focused, so the remote always has somewhere to start, and
/// scrolls a control that gets focus off screen into view: the remote's
/// arrows do that themselves, but focus given by the app does not.
class FocusRing extends StatefulWidget {
  const FocusRing({super.key, required this.child});

  final Widget child;

  /// The colour of the ring. White reads on every surface in the app,
  /// the green halo of a connected power button included.
  static const Color color = Color(0xFFFFFFFF);

  @override
  State<FocusRing> createState() => _FocusRingState();
}

/// Draws the [FocusRing] of the control inside as a circle instead of a
/// rounded rectangle. Only around a single control: every control inside
/// gets a circle.
class FocusRingCircle extends StatelessWidget {
  const FocusRingCircle({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}

/// Where the ring goes, in the [FocusRing]'s own coordinates, and whether
/// it is a circle.
typedef _Ring = ({Rect rect, bool circle});

class _FocusRingState extends State<FocusRing> {
  final _ring = ValueNotifier<_Ring?>(null);
  bool _focusFirstQueued = false;

  FocusNode? _shapeOf;
  bool _circle = false;

  /// The control last scrolled into view, so it is done once per focus.
  FocusNode? _scrolledTo;

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addListener(_changed);
    FocusManager.instance.addHighlightModeListener(_modeChanged);
    SchedulerBinding.instance.addPostFrameCallback(_afterFrame);
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_changed);
    FocusManager.instance.removeHighlightModeListener(_modeChanged);
    _ring.dispose();
    super.dispose();
  }

  void _changed() => SchedulerBinding.instance.ensureVisualUpdate();

  void _modeChanged(FocusHighlightMode _) => _changed();

  bool get _shown =>
      FormFactor.isTv &&
      defaultTargetPlatform == TargetPlatform.android &&
      FocusManager.instance.highlightMode == FocusHighlightMode.traditional;

  /// After every frame, so the ring follows its control through scrolling
  /// and page transitions. A frame's layout is final only once it has run,
  /// and the ring is drawn on the next one. Schedules no frame of its own:
  /// on a still screen nothing runs.
  void _afterFrame(Duration _) {
    if (!mounted) return;
    SchedulerBinding.instance.addPostFrameCallback(_afterFrame);
    final focus = FocusManager.instance.primaryFocus;
    final ring = _shown ? _ringFor(focus) : null;
    if (ring != _ring.value) _ring.value = ring;
    if (FormFactor.isTv) {
      _focusFirstIfNone(focus);
      _scrollIntoView(focus);
    }
  }

  /// Scroll [node] into view if it is a control that has just been given
  /// focus. Does nothing to a control already in view, so the remote's own
  /// moves, which scroll as they go, are left as they are.
  void _scrollIntoView(FocusNode? node) {
    if (node == null || node is FocusScopeNode || node == _scrolledTo) return;
    _scrolledTo = node;
    final context = node.context;
    if (context == null || Scrollable.maybeOf(context) == null) return;
    const duration = Duration(milliseconds: 150);
    // Only one of these moves anything: past the bottom of the view, the
    // first; above the top, the second.
    Scrollable.ensureVisible(
      context,
      duration: duration,
      alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
    );
    Scrollable.ensureVisible(
      context,
      duration: duration,
      alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtStart,
    );
  }

  _Ring? _ringFor(FocusNode? node) {
    // A scope is focused when no control is. Nothing to draw around.
    if (node == null || node is FocusScopeNode) return null;
    try {
      final context = node.context;
      if (context == null || !context.mounted) return null;
      final object = context.findRenderObject();
      final own = this.context.findRenderObject();
      if (object is! RenderBox || !object.attached || !object.hasSize) {
        return null;
      }
      if (own is! RenderBox || own == object) return null;
      final rect = MatrixUtils.transformRect(
        object.getTransformTo(own),
        Offset.zero & object.size,
      );
      if (rect.isEmpty || _outOfView(context, rect, own)) return null;
      if (_shapeOf != node) {
        _shapeOf = node;
        _circle =
            context.findAncestorWidgetOfExactType<FocusRingCircle>() != null;
      }
      return (rect: rect, circle: _circle);
    } catch (e) {
      debugPrint('FocusRing: no ring for $node ($e)');
      return null;
    }
  }

  /// Whether [rect] lies wholly outside the list [context] scrolls in. A
  /// ring there would be drawn over whatever is beside the list.
  bool _outOfView(BuildContext context, Rect rect, RenderBox own) {
    final scrollable = Scrollable.maybeOf(context);
    final view = scrollable?.context.findRenderObject();
    if (view is! RenderBox || !view.attached || !view.hasSize) return false;
    final viewRect = MatrixUtils.transformRect(
      view.getTransformTo(own),
      Offset.zero & view.size,
    );
    return !viewRect.overlaps(rect);
  }

  /// Focus the first control when a screen has opened with none focused.
  /// Run after the frame's own focus requests, autofocus among them, have
  /// landed, so it never takes focus from a control that asked for it.
  void _focusFirstIfNone(FocusNode? focus) {
    if (_focusFirstQueued || focus is! FocusScopeNode) return;
    if (focus.focusedChild != null || focus.traversalDescendants.isEmpty) {
      return;
    }
    _focusFirstQueued = true;
    Timer.run(() {
      _focusFirstQueued = false;
      if (!mounted) return;
      final now = FocusManager.instance.primaryFocus;
      if (now is FocusScopeNode &&
          now.focusedChild == null &&
          now.traversalDescendants.isNotEmpty) {
        now.nextFocus();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        IgnorePointer(child: CustomPaint(painter: _RingPainter(_ring))),
      ],
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.ring) : super(repaint: ring);

  final ValueListenable<_Ring?> ring;

  /// Space between the control and the ring, so the ring never covers the
  /// control's own border.
  static const double gap = 3;
  static const double width = 3;
  static const Radius corner = Radius.circular(16);

  @override
  void paint(Canvas canvas, Size size) {
    final r = ring.value;
    if (r == null) return;
    // A wide faint stroke under the ring stands in for a glow. A blurred
    // stroke costs a blur pass on every frame the ring moves, which the
    // low-end TV boxes this runs on cannot spare.
    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width * 3
      ..color = FocusRing.color.withValues(alpha: 0.12);
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..color = FocusRing.color;
    if (r.circle) {
      final radius = r.rect.shortestSide / 2 + gap;
      canvas.drawCircle(r.rect.center, radius, glow);
      canvas.drawCircle(r.rect.center, radius, line);
    } else {
      final shape = RRect.fromRectAndRadius(r.rect.inflate(gap), corner);
      canvas.drawRRect(shape, glow);
      canvas.drawRRect(shape, line);
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.ring != ring;
}
