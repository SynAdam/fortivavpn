import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController

    // The app's layout is a phone's; the window is the Windows client's
    // size (windows/runner/main.cpp), and may grow but not shrink below it.
    self.title = "Fortiva VPN"
    self.setContentSize(NSSize(width: 420, height: 720))
    self.contentMinSize = NSSize(width: 360, height: 600)
    self.center()

    RegisterGeneratedPlugins(registry: flutterViewController)
    TunnelDaemon.attach(to: flutterViewController.engine.binaryMessenger)

    super.awakeFromNib()
  }
}
