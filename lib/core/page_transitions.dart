import 'package:flutter/material.dart';

import '../widgets/readable_width.dart';
import 'design_system.dart';

/// Slide-up + fade transition for modal-style screens.
///
/// A short rise with Material's emphasized curves: the page arrives fast
/// and settles, and leaves faster than it came. Only the incoming page
/// fades, over the first 60 percent of the rise, so the page under it never
/// flickers.
class SlideUpFadeTransition extends PageRouteBuilder {
  final Widget page;

  SlideUpFadeTransition({required this.page})
    : super(
        pageBuilder: (context, animation, secondaryAnimation) =>
            ReadableWidth(child: page),
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: const Duration(milliseconds: 220),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final slide = CurvedAnimation(
            parent: animation,
            curve: AppMotion.emphasizedDecelerate,
            reverseCurve: AppMotion.emphasizedAccelerate,
          );
          final fade = CurvedAnimation(
            parent: animation,
            curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
          );

          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.06),
              end: Offset.zero,
            ).animate(slide),
            child: FadeTransition(opacity: fade, child: child),
          );
        },
      );
}

/// Scale + fade transition for detail screens
class ScaleFadeTransition extends PageRouteBuilder {
  final Widget page;

  ScaleFadeTransition({required this.page})
    : super(
        pageBuilder: (context, animation, secondaryAnimation) =>
            ReadableWidth(child: page),
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: const Duration(milliseconds: 200),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curve = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );

          return ScaleTransition(
            scale: Tween<double>(begin: 0.92, end: 1.0).animate(curve),
            child: FadeTransition(
              opacity: Tween<double>(begin: 0.0, end: 1.0).animate(curve),
              child: child,
            ),
          );
        },
      );
}
