import CFNetwork
import CoreTelephony
import Flutter
import Network
import NetworkExtension
import UIKit
import os.log


/// Diagnostics that survive the trip to a real device.
///
/// `NSLog("... %@", value)` redacts every argument to `<private>` in the
/// unified log on device, so the ping failures this file records were
/// invisible exactly where they mattered. os_log with a `%{public}@`
/// format is not redacted.
private let fortivaLog = OSLog(subsystem: "com.vpn.fortivavpn", category: "app")

func fortivaLogPublic(_ message: String) {
    os_log("%{public}@", log: fortivaLog, type: .default, message)
}

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterStreamHandler {
    
    private var eventSink: FlutterEventSink?

    /// Started once at launch, because `currentPath` on a monitor created
    /// per call is unsatisfied until its first update lands, which reads
    /// as "no internet" on a working phone.
    private let pathMonitor = NWPathMonitor()
    private let pathQueue = DispatchQueue(label: "com.vpn.fortivavpn.path")
    
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        
        let controller : FlutterViewController = window?.rootViewController as! FlutterViewController
        let tunnelChannel = FlutterMethodChannel(name: "com.vpn.fortivavpn/tunnel",
                                                 binaryMessenger: controller.binaryMessenger)
        
        tunnelChannel.setMethodCallHandler({
            [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
            guard let self = self else { return }
            self.handleMethodCall(call, result: result)
        })
        
        let statusChannel = FlutterEventChannel(name: "com.vpn.fortivavpn/tunnel/status",
                                                binaryMessenger: controller.binaryMessenger)
        statusChannel.setStreamHandler(self)
        
        // Setup status listener
        FortivaConnectionEngine.shared.onStatusChanged = { [weak self] status in
            self?.eventSink?(status.rawValue)
        }
        
        pathMonitor.start(queue: pathQueue)

        GeneratedPluginRegistrant.register(with: self)
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    
    private func handleMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "connect":
            guard let args = call.arguments as? [String: Any],
                  let link = args["link"] as? String else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing link", details: nil))
                return
            }
            let dns = args["dns"] as? String
            FortivaConnectionEngine.shared.connect(vlessLink: link, dns: dns) { errorMessage in
                if let errorMessage = errorMessage {
                    result(FlutterError(code: "CONNECT_FAILED", message: errorMessage, details: nil))
                } else {
                    result(nil)
                }
            }
            
        case "disconnect":
            FortivaConnectionEngine.shared.disconnect()
            result(nil)
            
        case "getStatus":
            result(FortivaConnectionEngine.shared.status.rawValue)
            
        case "realPing":
            guard let args = call.arguments as? [String: Any],
                  let link = args["link"] as? String else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing link", details: nil))
                return
            }
            realPing(link: link, result: result)

        case "diagnostics":
            collectDiagnostics(result: result)

        case "place":
            result(placeFacts())

        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    // MARK: - Diagnostics

    /// Everything the platform knows that explains a failed connection.
    ///
    /// The same keys Android sends, so the backend reads one shape and its
    /// verdict rules do not need a per-platform branch. What iOS cannot
    /// answer is left out rather than filled with a placeholder: a missing
    /// key means "not known here", and a wrong value would be counted.
    private func collectDiagnostics(result: @escaping FlutterResult) {
        var out: [String: Any] = [:]

        let path = pathMonitor.currentPath
        out["network"] = Self.networkName(for: path)
        out["validated"] = path.status == .satisfied
        // isExpensive is cellular or a personal hotspot, which is the same
        // question Android's isActiveNetworkMetered answers.
        out["metered"] = path.isExpensive
        // Low Data Mode. Not the same switch as Android's Data Saver, but
        // the same thing the user asked for, so it travels under one key.
        out["data_saver"] = path.isConstrained
        out["power_save"] = ProcessInfo.processInfo.isLowPowerModeEnabled
        out["device"] = Self.deviceModel()
        if let carrier = Self.carrierName() { out["carrier"] = carrier }
        if let radio = Self.radioAccess() { out["radio"] = radio }
        if let tail = Self.tunnelLogTail() { out["core_log"] = tail }

        // Last, because it is the only part that has to go to the system
        // and come back. A failure here still returns everything above.
        NETunnelProviderManager.loadAllFromPreferences { managers, _ in
            let ours = managers?.first
            // The iOS reading of "may this app run a VPN": a configuration
            // the user installed and has not switched off. Android reads
            // the consent dialog's answer, which is the same permission.
            out["vpn_permission"] = ours?.isEnabled ?? false
            out["through_vpn"] = ours?.connection.status == .connected
            DispatchQueue.main.async { result(out) }
        }
    }

    /// Where the phone is, as the phone knows it rather than as its address
    /// says. Same keys as Android's placeFacts.
    ///
    /// iOS has told apps no cell or SIM country since iOS 16, so this is the
    /// time zone id and whether another VPN is up. The VPN question is only
    /// asked while our own tunnel is down, because ours looks the same from
    /// here; while it is up the answer is left out, which means "not known".
    private func placeFacts() -> [String: Any] {
        var out: [String: Any] = [:]
        out["time_zone"] = TimeZone.current.identifier
        if FortivaConnectionEngine.shared.status == .disconnected,
           let other = Self.vpnInterfaceIsUp() {
            out["other_vpn"] = other
        }
        return out
    }

    /// Whether a VPN interface (utun, ipsec, ppp, tap) has its own proxy
    /// scope, which is how a running VPN shows up to an app. Nil when the
    /// system does not say.
    private static func vpnInterfaceIsUp() -> Bool? {
        guard let settings = CFNetworkCopySystemProxySettings()?.takeRetainedValue() as? [String: Any],
              let scoped = settings["__SCOPED__"] as? [String: Any] else {
            return nil
        }
        return scoped.keys.contains { name in
            ["tun", "tap", "ppp", "ipsec"].contains { name.contains($0) }
        }
    }

    /// wifi, mobile, ethernet, other or none, in Android's own vocabulary.
    private static func networkName(for path: Network.NWPath) -> String {
        if path.status != .satisfied { return "none" }
        if path.usesInterfaceType(.wifi) { return "wifi" }
        if path.usesInterfaceType(.cellular) { return "mobile" }
        if path.usesInterfaceType(.wiredEthernet) { return "ethernet" }
        return "other"
    }

    /// The SIM's operator name, where iOS still tells anyone.
    ///
    /// Deprecated since iOS 16, where it answers "--" for every carrier on
    /// earth. Reported only below 16, and only when it is a real name, so
    /// a per-carrier failure rate is never grouped under a placeholder.
    @available(iOS, deprecated: 16.0)
    private static func carrierName() -> String? {
        if #available(iOS 16.0, *) { return nil }
        guard let providers = CTTelephonyNetworkInfo().serviceSubscriberCellularProviders else {
            return nil
        }
        for (_, carrier) in providers {
            guard let name = carrier.carrierName, !name.isEmpty, name != "--" else { continue }
            return name
        }
        return nil
    }

    /// The radio the phone is actually on: lte, nr, wcdma and so on.
    ///
    /// No Android counterpart. It is here because a carrier that blocks on
    /// 4G and not on 5G is a distinction the transport alone cannot make,
    /// and an extra key costs the backend nothing.
    private static func radioAccess() -> String? {
        guard let radios = CTTelephonyNetworkInfo().serviceCurrentRadioAccessTechnology else {
            return nil
        }
        for (_, value) in radios {
            let name = value
                .replacingOccurrences(of: "CTRadioAccessTechnology", with: "")
                .lowercased()
            if !name.isEmpty { return name }
        }
        return nil
    }

    /// "Apple iPhone15,2", to match the "MANUFACTURER MODEL" Android sends.
    ///
    /// The machine identifier rather than `UIDevice.model`, which answers
    /// "iPhone" for every iPhone ever made.
    private static func deviceModel() -> String {
        var info = utsname()
        uname(&info)
        let identifier = withUnsafePointer(to: &info.machine) { pointer in
            pointer.withMemoryRebound(to: CChar.self, capacity: 1) { String(cString: $0) }
        }
        return identifier.isEmpty ? "Apple" : "Apple \(identifier)"
    }

    /// The last lines the packet tunnel wrote.
    ///
    /// iOS has no logcat, so the extension's own file in the shared
    /// container stands in for Android's core log. It is written by
    /// `FortivaSecureTunnelProvider.debugLog` and cleared on every start,
    /// so what is here belongs to the session that failed.
    private static func tunnelLogTail(maxChars: Int = 6000) -> String? {
        guard let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.vpn.fortivavpn"
        ) else { return nil }
        let path = container.appendingPathComponent("tunnel_debug.log")
        guard let text = try? String(contentsOf: path, encoding: .utf8), !text.isEmpty else {
            return nil
        }
        return text.count <= maxChars ? text : String(text.suffix(maxChars))
    }

    // MARK: - Real Ping

    /// Host and remark for a share link, with the credential removed.
    ///
    /// The link carries the device's UUID, which is the whole credential.
    /// The device log is readable by anyone who plugs the phone in and by
    /// a sysdiagnose, so the link itself must never be written there. Host
    /// and remark are enough to tell which server failed.
    static func serverLabel(for link: String) -> String {
        guard let url = URLComponents(string: link), let host = url.host else {
            return "unparseable link"
        }
        let remark = url.fragment?.removingPercentEncoding ?? ""
        let port = url.port.map { ":\($0)" } ?? ""
        return remark.isEmpty ? "\(host)\(port)" : "\(remark) [\(host)\(port)]"
    }

    /// Perform a real proxy ping using LibXray — starts a temp Xray instance,
    /// routes an HTTP request through the proxy outbound, and returns latency in ms.
    /// Returns -1 for timeout/failure (e.g. a disabled link).
    ///
    /// Key fix: We strip `routing` and `dns` keys from the converted Xray config
    /// because they reference geoip.dat/geosite.dat which are NOT bundled with the
    /// iOS app. Without stripping, LibXrayPing fails instantly trying to load those
    /// files. For ping, only the outbound config is needed — same as Android.
    private func realPing(link: String, result: @escaping FlutterResult) {
        DispatchQueue.global(qos: .userInitiated).async {
            // Step 1: Convert VLESS link to Xray JSON config
            let base64Link = Data(link.utf8).base64EncodedString()
            let rawResult = LibXrayConvertShareLinksToXrayJson(base64Link)
            
            guard let resultData = Data(base64Encoded: rawResult),
                  let resultJson = try? JSONSerialization.jsonObject(with: resultData) as? [String: Any],
                  let success = resultJson["success"] as? Bool, success else {
                DispatchQueue.main.async { result(-1) }
                return
            }
            
            // Step 2: Extract config dict
            var configDict: [String: Any]
            if let dict = resultJson["data"] as? [String: Any] {
                configDict = dict
            } else if let str = resultJson["data"] as? String,
                      let data = str.data(using: .utf8),
                      let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                configDict = dict
            } else {
                DispatchQueue.main.async { result(-1) }
                return
            }
            
            // Step 3: Get a free port for the SOCKS inbound
            let freePortResult = LibXrayGetFreePorts(1)
            guard let freePortData = Data(base64Encoded: freePortResult),
                  let freePortJson = try? JSONSerialization.jsonObject(with: freePortData) as? [String: Any],
                  let freePortSuccess = freePortJson["success"] as? Bool, freePortSuccess else {
                DispatchQueue.main.async { result(-1) }
                return
            }
            
            // Parse port — LibXrayGetFreePorts returns {"data": {"ports": [N]}}
            var socksPort: Int = 0
            if let portDict = freePortJson["data"] as? [String: Any],
               let ports = portDict["ports"] as? [Int], let p = ports.first {
                socksPort = p
            } else if let ports = freePortJson["data"] as? [Int], let p = ports.first {
                socksPort = p
            } else if let port = freePortJson["data"] as? Int {
                socksPort = port
            }
            guard socksPort > 0 else {
                DispatchQueue.main.async { result(-1) }
                return
            }
            
            // Step 4: Clean outbounds — strip sendThrough/mux, add tag, remove NSNull
            var cleanOutbounds: [[String: Any]] = []
            if var outbounds = configDict["outbounds"] as? [[String: Any]] {
                for i in 0..<outbounds.count {
                    outbounds[i].removeValue(forKey: "sendThrough")
                    outbounds[i].removeValue(forKey: "mux")
                    outbounds[i]["tag"] = "proxy"
                    outbounds[i] = self.removeNullValues(outbounds[i])
                }
                cleanOutbounds = outbounds
            }
            
            // Step 5: Build minimal config with SOCKS inbound + routing
            let minimalConfig: [String: Any] = [
                "log": ["loglevel": "none"],
                "inbounds": [
                    [
                        "tag": "socks-in",
                        "port": socksPort,
                        "listen": "127.0.0.1",
                        "protocol": "socks",
                        "settings": ["udp": false]
                    ]
                ],
                "outbounds": cleanOutbounds,
                "routing": [
                    "domainStrategy": "AsIs",
                    "rules": [
                        [
                            "type": "field",
                            "inboundTag": ["socks-in"],
                            "outboundTag": "proxy"
                        ]
                    ]
                ]
            ]
            
            guard let configData = try? JSONSerialization.data(withJSONObject: minimalConfig),
                  let xrayConfig = String(data: configData, encoding: .utf8) else {
                DispatchQueue.main.async { result(-1) }
                return
            }

            
            // Step 6: Write config to temp file
            let configPath = NSTemporaryDirectory() + "ping_config_\(ProcessInfo.processInfo.globallyUniqueString).json"
            do {
                try xrayConfig.write(toFile: configPath, atomically: true, encoding: .utf8)
            } catch {
                DispatchQueue.main.async { result(-1) }
                return
            }
            defer { try? FileManager.default.removeItem(atPath: configPath) }
            
            // Step 7: Build ping request — proxy routes through SOCKS inbound
            let pingRequest: [String: Any] = [
                "datDir": NSTemporaryDirectory(),
                "configPath": configPath,
                "timeout": 8,
                "url": "https://www.gstatic.com/generate_204",
                "proxy": "socks5://127.0.0.1:\(socksPort)",
                "count": 1
            ]
            
            guard let pingData = try? JSONSerialization.data(withJSONObject: pingRequest),
                  let pingJson = String(data: pingData, encoding: .utf8) else {
                DispatchQueue.main.async { result(-1) }
                return
            }
            
            // Step 8: Call LibXrayPing
            let base64Ping = Data(pingJson.utf8).base64EncodedString()
            let pingResult = LibXrayPing(base64Ping)
            
            // Step 9: Parse result
            guard let pingResultData = Data(base64Encoded: pingResult),
                  let pingResultJson = try? JSONSerialization.jsonObject(with: pingResultData) as? [String: Any],
                  let pingSuccess = pingResultJson["success"] as? Bool, pingSuccess else {
                // The reason was being discarded here, which left the UI
                // showing "timeout" for everything from a malformed config
                // to an unreachable server. Log it: it is the only account
                // of why a server the user can see is refusing to answer.
                let raw = Data(base64Encoded: pingResult)
                    .flatMap { String(data: $0, encoding: .utf8) } ?? pingResult
                fortivaLogPublic("❌ FortivaPing: failed for \(Self.serverLabel(for: link)) — \(raw)")
                DispatchQueue.main.async { result(-1) }
                return
            }
            
            if let delay = pingResultJson["data"] as? Int {
                DispatchQueue.main.async { result(delay) }
            } else if let delayStr = pingResultJson["data"] as? String, let delay = Int(delayStr) {
                DispatchQueue.main.async { result(delay) }
            } else {
                DispatchQueue.main.async { result(-1) }
            }
        }
    }
    
    /// Get the asset directory for LibXray geo files
    private func getAssetDirectory() -> String {
        if let containerUrl = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.vpn.fortivavpn") {
            return containerUrl.path
        }
        return NSTemporaryDirectory()
    }
    
    /// Recursively remove NSNull values from a dictionary
    /// NSNull values from LibXrayConvertShareLinksToXrayJson crash Go's json.Unmarshal
    private func removeNullValues(_ dict: [String: Any]) -> [String: Any] {
        var clean = [String: Any]()
        for (key, value) in dict {
            if value is NSNull {
                continue
            } else if let nestedDict = value as? [String: Any] {
                clean[key] = removeNullValues(nestedDict)
            } else if let nestedArray = value as? [Any] {
                clean[key] = removeNullValuesFromArray(nestedArray)
            } else {
                clean[key] = value
            }
        }
        return clean
    }
    
    private func removeNullValuesFromArray(_ array: [Any]) -> [Any] {
        return array.compactMap { element in
            if element is NSNull {
                return nil
            } else if let dict = element as? [String: Any] {
                return removeNullValues(dict)
            } else if let arr = element as? [Any] {
                return removeNullValuesFromArray(arr)
            } else {
                return element
            }
        }
    }
    
    // MARK: - FlutterStreamHandler
    
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        // Send initial status
        events(FortivaConnectionEngine.shared.status.rawValue)
        return nil
    }
    
    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        return nil
    }
}
