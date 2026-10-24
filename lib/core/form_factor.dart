import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../services/tunnel_channels.dart';

/// Whether the app is running on a TV, where a remote is all the user has.
///
/// One app serves phones and TVs. On a TV it does not lock itself to
/// portrait, a remote's focus is always drawn, and links it cannot open
/// there (Telegram, a website) are shown as a QR code for a phone instead.
/// The layout does not ask this: it follows the screen's shape, see
/// [isWide], so a box that does not say it is a TV still gets the TV
/// layout.
abstract final class FormFactor {
  static bool _tv = false;

  static bool get isTv => _tv;

  @visibleForTesting
  static set isTvForTest(bool value) => _tv = value;

  /// `--dart-define=FORTIVA_TV=true` makes any Android device a TV, for
  /// trying the TV app on a tablet or a phone emulator without a TV.
  static const bool _forced = bool.fromEnvironment('FORTIVA_TV');

  /// Ask the platform, once, before the first frame. Never throws: anything
  /// that goes wrong leaves the app a phone app, as it was before TVs.
  static Future<void> read() async {
    if (!Platform.isAndroid) return;
    if (_forced) {
      _tv = true;
      return;
    }
    try {
      _tv =
          await TunnelChannels.method.invokeMethod<bool>('isTelevision') ??
          false;
    } catch (e) {
      debugPrint('FormFactor: could not tell whether this is a TV ($e)');
    }
  }

  /// The narrowest screen laid out side by side instead of as one column.
  /// A TV is 960 wide in logical pixels, some boxes 1280.
  static const double wideFrom = 720;

  /// Whether [size] is a screen to lay out side by side: a TV, a tablet on
  /// its side, a wide window. A phone held upright never is.
  static bool isWide(Size size) =>
      size.width >= wideFrom && size.width > size.height;
}
