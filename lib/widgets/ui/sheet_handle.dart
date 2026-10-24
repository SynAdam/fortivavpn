import 'package:flutter/material.dart';

import '../../core/design_system.dart';

/// The drag handle at the top of a sheet that draws its own content, the
/// same size and color as the theme's handle (BottomSheetThemeData).
///
/// It is decoration: the sheet drags from anywhere, so it takes no focus
/// and says nothing to a screen reader.
class SheetHandle extends StatelessWidget {
  const SheetHandle({
    super.key,
    this.padding = const EdgeInsets.only(top: 12, bottom: 8),
  });

  static const double width = 36;
  static const double height = 4;

  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Padding(
        padding: padding,
        child: Center(
          child: Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              color: AppDesign.steelDark,
              borderRadius: BorderRadius.circular(height / 2),
            ),
          ),
        ),
      ),
    );
  }
}
