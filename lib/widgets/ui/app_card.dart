import 'package:flutter/material.dart';

import '../../core/design_system.dart';

/// A card: the low surface, the large radius and 16 inside, the look the
/// blocks of a screen share. It takes no taps; a tappable card is a
/// Pressable.
///
/// No edge by default: the card is a step lighter than the canvas under
/// it, and an edge is only for two equal surfaces. Pass [border] where the
/// card sits on a surface of its own tone.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppDesign.space16),
    this.border = BorderSide.none,
  });

  final Widget child;

  /// Space between the edge and [child].
  final EdgeInsetsGeometry padding;

  /// An edge drawn inside the card. None by default.
  final BorderSide border;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppDesign.surfaceLow,
        borderRadius: AppDesign.borderRadiusLarge,
        border: border == BorderSide.none
            ? null
            : Border.fromBorderSide(border),
      ),
      child: child,
    );
  }
}
