import 'dart:io';

import 'package:flutter/foundation.dart';

/// Whether the app's tunnel is the desktop core (windows/core), which the
/// Windows and macOS apps both drive through [DesktopTunnel]. It holds a
/// door group as Android's does and reads VLESS links alone.
///
/// `flutter test` runs on Linux in CI and on the team's Macs by hand, and
/// a test must behave the same on both. So under test macOS counts as
/// neither desktop client unless a test says otherwise ([macOSForTest]),
/// as Linux is neither.
abstract final class DesktopCore {
  /// Stands in for the macOS check in tests.
  @visibleForTesting
  static bool? macOSForTest;

  /// flutter test sets FLUTTER_TEST in the environment of every test.
  static final bool _underTest = Platform.environment.containsKey(
    'FLUTTER_TEST',
  );

  /// The macOS client.
  static bool get isMacOS => macOSForTest ?? (Platform.isMacOS && !_underTest);

  /// Windows or the macOS client.
  static bool get active => Platform.isWindows || isMacOS;
}
