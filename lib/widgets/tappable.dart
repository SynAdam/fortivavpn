import 'package:flutter/material.dart';

/// A [GestureDetector] tap that a TV remote can reach too.
///
/// A plain GestureDetector answers only touch: a remote can neither move to
/// it nor press it. This adds focus and the activate action the remote's
/// centre button sends, and changes nothing a finger sees. Where the focus
/// is shows through [FocusRing].
class Tappable extends StatelessWidget {
  const Tappable({
    super.key,
    required this.onTap,
    required this.child,
    this.behavior,
  });

  /// Null leaves the control untappable and out of the remote's way.
  final VoidCallback? onTap;
  final HitTestBehavior? behavior;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final onTap = this.onTap;
    return FocusableActionDetector(
      enabled: onTap != null,
      actions: {
        if (onTap != null)
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              onTap();
              return null;
            },
          ),
      },
      child: GestureDetector(onTap: onTap, behavior: behavior, child: child),
    );
  }
}
