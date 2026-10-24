import 'package:flutter/material.dart';

import '../../core/design_system.dart';

/// A tappable card or row: a filled, rounded surface with the ripple drawn
/// on top of the fill.
///
/// A Container with a color under an InkWell hides the ripple, because the
/// ink paints on the nearest Material below the color. Here the fill is the
/// Material itself, so the ripple shows. It is an InkWell, so a TV remote
/// can focus it and FocusRing draws around it.
class Pressable extends StatelessWidget {
  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.color = AppDesign.surfaceLow,
    this.borderRadius = const BorderRadius.all(
      Radius.circular(AppDesign.radiusMedium),
    ),
    this.border = BorderSide.none,
    this.padding = EdgeInsets.zero,
    this.semanticsLabel,
    this.focusNode,
    this.autofocus = false,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// The fill.
  final Color color;

  /// Directional radii resolve with the text direction.
  final BorderRadiusGeometry borderRadius;

  /// An edge drawn inside the shape. None by default: a raised surface is
  /// told apart by its tone.
  final BorderSide border;

  /// Space between the edge and [child], inside the tap area.
  final EdgeInsetsGeometry padding;

  /// A label for screen readers, read before the child's own text.
  final String? semanticsLabel;
  final FocusNode? focusNode;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius.resolve(Directionality.maybeOf(context));
    return Semantics(
      button: onTap != null,
      label: semanticsLabel,
      child: Material(
        color: color,
        shape: RoundedRectangleBorder(borderRadius: radius, side: border),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          focusNode: focusNode,
          autofocus: autofocus,
          borderRadius: radius,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
