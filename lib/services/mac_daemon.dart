import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Where the tunnel's launchd daemon is, as SMAppService says.
enum MacDaemonState {
  /// Added and allowed: launchd runs it.
  enabled,

  /// Added, and waiting for the person to allow it in System Settings.
  requiresApproval,

  /// Not added yet.
  notRegistered,

  /// macOS has no record of it. That is what a daemon that was never
  /// added answers, not [notRegistered] (macOS 26, 2026-11-16), and also
  /// what a build without the tunnel in it answers (macos/embed_tunnel.sh
  /// did not run); adding it tells the two apart.
  notFound,

  /// An answer this build does not know.
  unknown,
}

/// The tunnel's launchd daemon on macOS, through the app's native code
/// (macos/Runner/TunnelDaemon.swift).
///
/// The tunnel is the core the daemon runs as root; the app talks to it
/// over its socket like the Windows app talks to its service
/// ([DesktopTunnel]). What Dart cannot do is add the daemon, which only the
/// app itself may ask macOS for, and open the settings where the person
/// allows it. macOS asks once, the first time.
class MacDaemon {
  const MacDaemon([
    this._channel = const MethodChannel('com.vpn.fortivavpn/daemon'),
  ]);

  final MethodChannel _channel;

  Future<MacDaemonState> status() async =>
      _state(await _channel.invokeMethod<String>('status'));

  /// Adds the daemon. macOS then shows that Fortiva added a background
  /// item, and the person allows it in System Settings.
  Future<MacDaemonState> register() async =>
      _state(await _channel.invokeMethod<String>('register'));

  /// Opens System Settings at Login Items & Extensions.
  Future<void> openSettings() => _channel.invokeMethod<void>('openSettings');

  /// The daemon's state, added first when it is not yet.
  Future<MacDaemonState> ensure() async {
    final now = await status();
    if (now != MacDaemonState.notRegistered && now != MacDaemonState.notFound) {
      return now;
    }
    return register();
  }

  @visibleForTesting
  static MacDaemonState stateOf(String? name) => _state(name);

  static MacDaemonState _state(String? name) => switch (name) {
    'enabled' => MacDaemonState.enabled,
    'requiresApproval' => MacDaemonState.requiresApproval,
    'notRegistered' => MacDaemonState.notRegistered,
    'notFound' => MacDaemonState.notFound,
    _ => MacDaemonState.unknown,
  };
}
