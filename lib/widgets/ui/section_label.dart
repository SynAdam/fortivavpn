import 'package:flutter/material.dart';

import '../../core/design_system.dart';

/// The small heading over a group of rows or cards, in sentence case.
///
/// Screen readers hear it as a heading, so a user can jump from group to
/// group. It sits at the start edge in both directions, 16 in from the
/// edge of the card under it: where the rows inside the card start their
/// icons and text, so the heading and its rows share one line.
class SectionLabel extends StatelessWidget {
  const SectionLabel(
    this.text, {
    super.key,
    this.padding = const EdgeInsetsDirectional.only(
      start: AppDesign.space16,
      bottom: AppDesign.space8,
    ),
  });

  final String text;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Semantics(
          header: true,
          child: Text(
            text,
            style: AppDesign.textTheme.labelMedium?.copyWith(
              color: AppDesign.textTertiary,
            ),
          ),
        ),
      ),
    );
  }
}
