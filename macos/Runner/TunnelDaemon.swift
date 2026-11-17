import FlutterMacOS
import ServiceManagement

/// The tunnel's launchd daemon (LaunchDaemons/com.vpn.fortivavpn.tunnel.plist),
/// as the app sees it through SMAppService. The tunnel itself is the core the
/// daemon runs; the app talks to it over its socket from Dart
/// (lib/services/desktop_tunnel.dart). This is only the part Dart cannot do:
/// adding the daemon and sending the person to where macOS lets them allow it.
///
/// Channel com.vpn.fortivavpn/daemon:
///
///   status        "enabled", "requiresApproval", "notRegistered" or "notFound"
///   register      adds the daemon and answers the status after; macOS then
///                 asks the person to allow it in System Settings
///   openSettings  opens System Settings at Login Items & Extensions, where
///                 the daemon is allowed
enum TunnelDaemon {
  static let channelName = "com.vpn.fortivavpn/daemon"
  static let plistName = "com.vpn.fortivavpn.tunnel.plist"

  private static var service: SMAppService { SMAppService.daemon(plistName: plistName) }

  static func attach(to messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "status":
        result(name(service.status))
      case "register":
        do {
          try service.register()
          result(name(service.status))
        } catch {
          // A daemon the person has not allowed yet is registered all the
          // same: register() throws "requires approval" and the status says
          // so. Only a status short of that is a failure.
          let status = service.status
          if status == .requiresApproval || status == .enabled {
            result(name(status))
          } else {
            result(FlutterError(
              code: "DAEMON_REGISTER",
              message: error.localizedDescription,
              details: name(status)))
          }
        }
      case "openSettings":
        SMAppService.openSystemSettingsLoginItems()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private static func name(_ status: SMAppService.Status) -> String {
    switch status {
    case .enabled: return "enabled"
    case .requiresApproval: return "requiresApproval"
    case .notRegistered: return "notRegistered"
    case .notFound: return "notFound"
    @unknown default: return "unknown"
    }
  }
}
