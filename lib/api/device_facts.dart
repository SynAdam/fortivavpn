import 'dart:async';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

/// What Android says about the phone itself, as the platform reports it.
typedef AndroidBuild = ({
  String? manufacturer,
  String? model,
  String? release,
  int? sdk,
});

/// The phone's model and Android version, for register's `device_model`
/// and `os_version`.
///
/// The backend has kept both columns since the first release, and no build
/// filled them: on 2026-10-09 they were empty on every device looked at.
/// Without them a failure that only one phone model or Android version
/// has, such as a vendor's own VPN or DNS handling, cannot be told from a
/// carrier's block. Register replaces both columns every time it runs, so
/// they are sent every time.
///
/// Android only, where the app is released. Other platforms send neither,
/// as before.
class DeviceFacts {
  DeviceFacts({Future<AndroidBuild> Function()? android, bool? isAndroid})
    : _android = android ?? _readAndroid,
      _isAndroid = isAndroid ?? Platform.isAndroid;

  static const timeout = Duration(seconds: 1);

  final Future<AndroidBuild> Function() _android;
  final bool _isAndroid;
  Future<({String? model, String? osVersion})>? _answer;

  static Future<AndroidBuild> _readAndroid() async {
    final info = await DeviceInfoPlugin().androidInfo;
    return (
      manufacturer: info.manufacturer,
      model: info.model,
      release: info.version.release,
      sdk: info.version.sdkInt,
    );
  }

  /// "samsung SM-A515F" and "Android 13 (API 33)", or null for what the
  /// platform did not say. Read once and remembered, so only the first
  /// register waits on the platform. Never throws.
  Future<({String? model, String? osVersion})> read() => _answer ??= _ask();

  Future<({String? model, String? osVersion})> _ask() async {
    if (!_isAndroid) return (model: null, osVersion: null);
    try {
      final build = await _android().timeout(timeout);
      return (model: modelOf(build), osVersion: osVersionOf(build));
    } on TimeoutException {
      // No answer is not an answer. The next register asks again.
      _answer = null;
      return (model: null, osVersion: null);
    } catch (e) {
      debugPrint('DeviceFacts: could not read the phone ($e)');
      return (model: null, osVersion: null);
    }
  }

  /// The maker and the model, as the failure diagnosis already names a
  /// phone ("samsung SM-A515F"). At most 255 characters, the column's size.
  @visibleForTesting
  static String? modelOf(AndroidBuild build) {
    final name = [
      build.manufacturer?.trim() ?? '',
      build.model?.trim() ?? '',
    ].where((part) => part.isNotEmpty).join(' ');
    if (name.isEmpty) return null;
    return name.length > 255 ? name.substring(0, 255) : name;
  }

  /// "Android 13 (API 33)". At most 50 characters, the column's size: the
  /// backend stores the value as it comes, and a longer one would fail the
  /// whole register.
  @visibleForTesting
  static String? osVersionOf(AndroidBuild build) {
    final release = build.release?.trim() ?? '';
    final sdk = build.sdk;
    if (release.isEmpty && sdk == null) return null;
    final text = [
      if (release.isNotEmpty) 'Android $release',
      if (sdk != null) '(API $sdk)',
    ].join(' ');
    return text.length > 50 ? text.substring(0, 50) : text;
  }
}
