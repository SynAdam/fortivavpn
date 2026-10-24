import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

import 'tunnel_channels.dart';

/// Whether this phone is one of Google's test devices (Firebase Test Lab).
///
/// Google Play runs every build we upload on its pre-launch test devices,
/// and those runs report to the backend like any other phone. On 2026-10-09
/// one of them, whose carrier changed every few minutes across 19 carriers,
/// made 12 of the 15 "every door closed" taps on our dashboard and
/// showed an outage that did not happen.
///
/// Register sends `test_lab: true` from such a device, and the backend
/// leaves it out of our dashboard and alerts. Nothing else changes on the
/// phone: it connects and reports as before, because the backend does the
/// filtering.
class TestLab {
  TestLab({MethodChannel? channel, bool? android})
    : _channel = channel ?? TunnelChannels.method,
      _android = android ?? Platform.isAndroid;

  static const timeout = Duration(seconds: 1);

  final MethodChannel _channel;
  final bool _android;
  Future<bool>? _answer;

  /// True only when Android says this is a Test Lab device. Asked once and
  /// remembered, so only the first register waits on the platform. Never
  /// throws: anything that goes wrong is false.
  Future<bool> read() => _answer ??= _ask();

  Future<bool> _ask() async {
    // The setting exists only on Android. iOS and Windows have no
    // pre-launch devices of this kind.
    if (!_android) return false;
    try {
      final answer = await _channel
          .invokeMethod<bool>('isTestLab')
          .timeout(timeout);
      return answer == true;
    } on TimeoutException {
      // No answer is not a "no". The next register asks again.
      _answer = null;
      return false;
    } catch (_) {
      // MissingPluginException (no native side: tests, an old engine) or a
      // PlatformException. Neither is worth failing a register for.
      return false;
    }
  }
}
