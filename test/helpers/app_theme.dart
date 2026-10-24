import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/core/design_system.dart';

/// The app's theme for [locale], with [AppDesign.activeLocale] set to the
/// same language until the test ends, as the app root does in main.dart.
///
/// A test that pumps a plain MaterialApp draws Material's default theme, so
/// it cannot see a change to the app theme's button, dialog or text sizes.
/// Call this only from inside a test, because it registers a tear down.
ThemeData appThemeFor(Locale? locale) {
  final shown = locale ?? const Locale('en');
  AppDesign.activeLocale = shown;
  addTearDown(() => AppDesign.activeLocale = const Locale('en'));
  return AppDesign.darkThemeForLocale(shown);
}
