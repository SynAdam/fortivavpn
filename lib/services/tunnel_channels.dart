import 'dart:io';

import 'package:flutter/services.dart';

import 'windows_tunnel.dart';

/// The channels the app reaches the native tunnel through.
///
/// On Android and iOS these are the platform channels the native code
/// registers. On Windows they are [WindowsTunnel]'s, which answer the same
/// calls by asking the tunnel service. Everything that talks to the tunnel
/// takes its channel from here, so it never has to ask which platform it is
/// on, and tests that mock the platform channel keep working.
abstract final class TunnelChannels {
  static const _methodName = 'com.vpn.fortivavpn/tunnel';
  static const _statusName = 'com.vpn.fortivavpn/tunnel/status';

  static MethodChannel get method => Platform.isWindows
      ? WindowsTunnel.instance.method
      : const MethodChannel(_methodName);

  static EventChannel get status => Platform.isWindows
      ? WindowsTunnel.instance.status
      : const EventChannel(_statusName);
}
