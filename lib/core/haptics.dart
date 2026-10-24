import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'form_factor.dart';

/// The app's haptic feedback, one name per kind of moment.
///
/// It goes through the view's own haptic feedback, which needs no VIBRATE
/// permission. A TV has no motor and a remote in the hand, so every call is
/// a no-op there. A call never throws: a phone that cannot vibrate, or a
/// platform that answers with an error, only loses the buzz.
abstract final class AppHaptics {
  /// A press on a main control, such as the power button.
  static void tap() => _play(HapticFeedback.mediumImpact);

  /// A finished moment the user waited for, such as a working connection.
  static void success() => _play(HapticFeedback.heavyImpact);

  /// A choice in a list or a switch changing.
  static void selection() => _play(HapticFeedback.selectionClick);

  /// A small acknowledgment, lighter than [tap].
  static void light() => _play(HapticFeedback.lightImpact);

  static void _play(Future<void> Function() feedback) {
    if (FormFactor.isTv) return;
    unawaited(_run(feedback));
  }

  static Future<void> _run(Future<void> Function() feedback) async {
    try {
      await feedback();
    } catch (e) {
      debugPrint('AppHaptics: no feedback ($e)');
    }
  }
}
