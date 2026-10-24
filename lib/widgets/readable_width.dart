import 'package:flutter/material.dart';

import '../core/design_system.dart';
import '../core/form_factor.dart';

/// Keeps a screen made for a phone to a column on a wide screen.
///
/// Every screen but home is a list built for a phone held upright. Across
/// a TV its lines run too long to read, and the remote's focus crosses the
/// whole width to reach a switch. On a wide screen this centres the page
/// at [maxWidth] and tells it the screen is that wide, so what it sizes
/// from the screen (chat bubbles, say) fits the column. Anywhere else it
/// is the page as it was.
class ReadableWidth extends StatelessWidget {
  const ReadableWidth({super.key, required this.child});

  final Widget child;

  static const double maxWidth = 720;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    if (!FormFactor.isWide(media.size) || media.size.width <= maxWidth) {
      return child;
    }
    return ColoredBox(
      color: AppDesign.canvas,
      child: Center(
        child: SizedBox(
          width: maxWidth,
          height: double.infinity,
          child: MediaQuery(
            data: media.copyWith(size: Size(maxWidth, media.size.height)),
            child: child,
          ),
        ),
      ),
    );
  }
}
