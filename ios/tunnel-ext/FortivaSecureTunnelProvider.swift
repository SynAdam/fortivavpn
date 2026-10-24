//
//  FortivaSecureTunnelProvider.swift
//  tunnel-ext
//
//  FortivaVPN — Secure Network Extension
//  Full traffic routing using FortivaNetBridge (hev-socks5-tunnel)
//

import NetworkExtension
import os.log
import FortivaNetBridge

class FortivaSecureTunnelProvider: NEPacketTunnelProvider {
    
    private let log = OSLog(subsystem: "com.vpn.fortivavpn.tunnel-ext", category: "FortivaSecureTunnel")
    private let socksPort: Int = 10808
    
    // TUN interface configuration  
    private let tunIPAddress = "10.255.0.2"
    private let tunSubnetMask = "255.255.255.0"
    private let tunGateway = "10.255.0.1"
    
    // Resolved server IP — excluded from tunnel routes to prevent loops
    private var resolvedServerIP: String?
    
    // Debug log path in shared container
    private var debugLogPath: String {
        if let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.vpn.fortivavpn") {
            return container.appendingPathComponent("tunnel_debug.log").path
        }
        return (NSTemporaryDirectory() as NSString).appendingPathComponent("tunnel_debug.log")
    }
    
    /// Write debug info to a file in the shared container (readable from Flutter)
    private func debugLog(_ message: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let line = "[\(timestamp)] \(message)\n"
        os_log("%{public}@", log: log, type: .info, message)
        
        if FileManager.default.fileExists(atPath: debugLogPath) {
            if let handle = FileHandle(forWritingAtPath: debugLogPath) {
                handle.seekToEndOfFile()
                handle.write(line.data(using: .utf8)!)
                handle.closeFile()
            }
        } else {
            try? line.write(toFile: debugLogPath, atomically: true, encoding: .utf8)
        }
    }
    
    override func startTunnel(options: [String: NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        // Clear previous debug log
        try? FileManager.default.removeItem(atPath: debugLogPath)
        
        debugLog("🚀 TUNNEL: Starting...")
        
        guard let protocolConfig = self.protocolConfiguration as? NETunnelProviderProtocol,
              let providerConfig = protocolConfig.providerConfiguration else {
            debugLog("❌ TUNNEL: No providerConfiguration!")
            completionHandler(NSError(domain: "FortivaError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing config"]))
            return
        }
        
        guard let vlessLink = providerConfig["vlessLink"] as? String else {
            debugLog("❌ TUNNEL: Missing 'vlessLink' key!")
            completionHandler(NSError(domain: "FortivaError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing VLESS link"]))
            return
        }
        
        let resolvedIP = providerConfig["resolvedIP"] as? String
        let serverHost = providerConfig["serverHost"] as? String
        self.resolvedServerIP = resolvedIP
        
        debugLog("📋 vlessLink = \(vlessLink)")
        debugLog("📋 serverHost = \(serverHost ?? "nil"), resolvedIP = \(resolvedIP ?? "nil")")
        
        // STEP 1: Use LibXray's built-in parser to get the outbound config
        debugLog("🔄 STEP1: Converting VLESS link via LibXray...")
        
        let base64Link = Data(vlessLink.utf8).base64EncodedString()
        let rawResult = LibXrayConvertShareLinksToXrayJson(base64Link)
        
        // Decode the base64 result
        guard let resultData = Data(base64Encoded: rawResult),
              let resultJson = try? JSONSerialization.jsonObject(with: resultData) as? [String: Any] else {
            debugLog("❌ STEP1: Failed to decode LibXray result")
            completionHandler(NSError(domain: "FortivaError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to decode LibXray result"]))
            return
        }
        
        let success = resultJson["success"] as? Bool ?? false
        if !success {
            let errorMsg = resultJson["data"] as? String ?? "Unknown error"
            debugLog("❌ STEP1: LibXray conversion FAILED: \(errorMsg)")
            completionHandler(NSError(domain: "FortivaError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Config conversion failed: \(errorMsg)"]))
            return
        }
        
        // Extract the config from LibXray's result
        var libXrayConfig: [String: Any]?
        if let configDict = resultJson["data"] as? [String: Any] {
            libXrayConfig = configDict
        } else if let configString = resultJson["data"] as? String,
                  let configData = configString.data(using: .utf8),
                  let parsed = try? JSONSerialization.jsonObject(with: configData) as? [String: Any] {
            libXrayConfig = parsed
        }
        
        guard let rawConfig = libXrayConfig else {
            debugLog("❌ STEP1: Could not extract config from LibXray result")
            completionHandler(NSError(domain: "FortivaError", code: 1, userInfo: [NSLocalizedDescriptionKey: "No valid config from LibXray"]))
            return
        }
        
        debugLog("✅ STEP1: LibXray returned config OK")
        
        // STEP 2: Extract outbound info from LibXray's config and build a clean Xray config
        // LibXray returns a Go struct with ALL fields (including null/empty), which Xray can't parse.
        // We need to extract just the useful fields and build a proper config.
        
        guard let outbounds = rawConfig["outbounds"] as? [[String: Any]],
              let outbound = outbounds.first else {
            debugLog("❌ STEP2: No outbounds in LibXray config")
            completionHandler(NSError(domain: "FortivaError", code: 1, userInfo: [NSLocalizedDescriptionKey: "No outbounds in config"]))
            return
        }
        
        let protocol_ = outbound["protocol"] as? String ?? "vless"
        let settings = outbound["settings"] as? [String: Any] ?? [:]
        let streamSettings = outbound["streamSettings"] as? [String: Any] ?? [:]
        
        // Extract user info from the flat Go struct settings
        let uuid = settings["id"] as? String ?? ""
        let encryption = settings["encryption"] as? String ?? "none"
        let flow = settings["flow"] as? String ?? ""
        let address = settings["address"] as? String ?? ""
        let port = settings["port"] as? Int ?? 443
        
        // Extract stream settings
        let security = streamSettings["security"] as? String ?? "none"
        let network = streamSettings["network"] as? String ?? "tcp"
        
        debugLog("📋 STEP2: protocol=\(protocol_), address=\(address):\(port), security=\(security), network=\(network), flow=\(flow)")
        
        // Determine the actual server address (use resolved IP if available)
        let serverAddr: String
        if let ip = resolvedIP, !ip.isEmpty {
            serverAddr = ip
        } else {
            serverAddr = address
        }
        
        // Build user object
        var userObj: [String: Any] = [
            "id": uuid,
            "encryption": encryption,
            "level": 0
        ]
        if !flow.isEmpty {
            userObj["flow"] = flow
        }
        
        // Build clean outbound
        var cleanOutbound: [String: Any] = [
            "tag": "proxy",
            "protocol": protocol_,
            "settings": [
                "vnext": [
                    [
                        "address": serverAddr,
                        "port": port,
                        "users": [userObj]
                    ]
                ]
            ]
        ]
        
        // Build clean stream settings
        var cleanStream: [String: Any] = [
            "network": network == "raw" ? "tcp" : network  // "raw" = tcp in newer Xray versions  
        ]
        
        // Handle security (reality, tls, none)
        if security == "reality" {
            cleanStream["security"] = "reality"
            let realitySettings = streamSettings["realitySettings"] as? [String: Any] ?? [:]
            var cleanReality: [String: Any] = [:]
            
            // Only include non-empty values
            if let sni = realitySettings["serverName"] as? String, !sni.isEmpty {
                cleanReality["serverName"] = sni
            }
            if let fp = realitySettings["fingerprint"] as? String, !fp.isEmpty {
                cleanReality["fingerprint"] = fp
            } else {
                cleanReality["fingerprint"] = "chrome"
            }
            if let pbk = realitySettings["publicKey"] as? String, !pbk.isEmpty {
                cleanReality["publicKey"] = pbk
            }
            if let sid = realitySettings["shortId"] as? String, !sid.isEmpty {
                cleanReality["shortId"] = sid
            }
            if let spx = realitySettings["spiderX"] as? String, !spx.isEmpty {
                cleanReality["spiderX"] = spx
            }
            
            cleanStream["realitySettings"] = cleanReality
        } else if security == "tls" {
            cleanStream["security"] = "tls"
            let tlsSettings = streamSettings["tlsSettings"] as? [String: Any] ?? [:]
            var cleanTls: [String: Any] = [:]
            
            if let sni = tlsSettings["serverName"] as? String, !sni.isEmpty {
                cleanTls["serverName"] = sni
            }
            if let fp = tlsSettings["fingerprint"] as? String, !fp.isEmpty {
                cleanTls["fingerprint"] = fp
            }
            if let alpn = tlsSettings["alpn"] as? [String], !alpn.isEmpty {
                cleanTls["alpn"] = alpn
            }
            cleanTls["allowInsecure"] = false
            
            cleanStream["tlsSettings"] = cleanTls
        } else {
            cleanStream["security"] = "none"
        }
        
        // Handle transport-specific settings
        if network == "ws" {
            let wsSettings = streamSettings["wsSettings"] as? [String: Any] ?? [:]
            var cleanWs: [String: Any] = [:]
            if let path = wsSettings["path"] as? String, !path.isEmpty {
                cleanWs["path"] = path
            }
            if let headers = wsSettings["headers"] as? [String: Any] {
                cleanWs["headers"] = headers
            }
            cleanStream["wsSettings"] = cleanWs
        } else if network == "grpc" {
            let grpcSettings = streamSettings["grpcSettings"] as? [String: Any] ?? [:]
            var cleanGrpc: [String: Any] = [:]
            if let serviceName = grpcSettings["serviceName"] as? String, !serviceName.isEmpty {
                cleanGrpc["serviceName"] = serviceName
            }
            cleanStream["grpcSettings"] = cleanGrpc
        } else if network == "httpupgrade" {
            let httpupgradeSettings = streamSettings["httpupgradeSettings"] as? [String: Any] ?? [:]
            var cleanHttp: [String: Any] = [:]
            if let path = httpupgradeSettings["path"] as? String, !path.isEmpty {
                cleanHttp["path"] = path
            }
            if let host = httpupgradeSettings["host"] as? String, !host.isEmpty {
                cleanHttp["host"] = host
            }
            cleanStream["httpupgradeSettings"] = cleanHttp
        }
        // For "tcp" / "raw", no extra settings needed
        
        cleanOutbound["streamSettings"] = cleanStream
        
        let dnsString = providerConfig["dns"] as? String
        var dnsServers = ["8.8.8.8", "1.1.1.1"] // Default
        if let dnsString = dnsString, !dnsString.isEmpty {
            dnsServers = dnsString.components(separatedBy: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            debugLog("🛡️ Using custom DNS: \(dnsServers)")
        } else {
             debugLog("🛡️ Using default DNS: \(dnsServers)")
        }

        // ... (rest of startTunnel logic) ...

        // Build the complete Xray config
        let xrayLogPath = getAssetDirectory() + "/xray.log"
        let xrayConfig: [String: Any] = [
            "log": [
                "loglevel": "debug",
                "access": xrayLogPath,
                "error": xrayLogPath
            ],
            "dns": [
                "servers": dnsServers
            ],
            "inbounds": [
                [
                    "tag": "socks-in",
                    "port": socksPort,
                    "listen": "127.0.0.1",
                    "protocol": "socks",
                    "settings": ["udp": true]
                ]
            ],
            "outbounds": [
                cleanOutbound,
                [
                    "tag": "direct",
                    "protocol": "freedom"
                ]
            ]
        ]
        
        // Serialize
        guard let configData = try? JSONSerialization.data(withJSONObject: xrayConfig, options: [.prettyPrinted]),
              let xrayConfigJSON = String(data: configData, encoding: .utf8) else {
            debugLog("❌ STEP2: Failed to serialize config!")
            completionHandler(NSError(domain: "FortivaError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to serialize config"]))
            return
        }
        
        debugLog("📋 STEP2: Final config = \(xrayConfigJSON)")
        
        let datDir = getAssetDirectory()
        
        // STEP 3: Stop any existing Xray instance
        _ = LibXrayStopXray()
        Thread.sleep(forTimeInterval: 0.3)
        
        // STEP 4: Start LibXray
        debugLog("🔄 STEP4: Starting Xray...")
        var xrayError: NSError?
        let runRequest = LibXrayNewXrayRunFromJSONRequest(datDir, datDir, xrayConfigJSON, &xrayError)
        
        if let xrayError = xrayError {
            debugLog("❌ STEP4: Xray request creation failed: \(xrayError.localizedDescription)")
            completionHandler(xrayError)
            return
        }
        
        let result = LibXrayRunXrayFromJSON(runRequest)
        debugLog("📋 STEP4: RunXrayFromJSON result = \(result)")
        
        // Decode the result to check for errors
        if let resultData = Data(base64Encoded: result),
           let resultStr = String(data: resultData, encoding: .utf8) {
            debugLog("📋 STEP4: Decoded result = \(resultStr)")
        }
        
        Thread.sleep(forTimeInterval: 0.5)
        
        let xrayState = LibXrayGetXrayState()
        debugLog("📊 STEP4: Xray state = \(xrayState ? "RUNNING ✅" : "STOPPED ❌")")
        
        if !xrayState {
            debugLog("❌ STEP4: Xray failed to start!")
            completionHandler(NSError(domain: "FortivaError", code: 2, userInfo: [NSLocalizedDescriptionKey: "Xray failed to start"]))
            return
        }
        
        debugLog("✅ STEP4: Xray running on SOCKS5 port \(socksPort)")

        // STEP 5: Configure tunnel
        configureTunnelNetworkSettings(dnsServers: dnsServers, completionHandler: completionHandler)
    }
    
    private func configureTunnelNetworkSettings(dnsServers: [String], completionHandler: @escaping (Error?) -> Void) {
        let tunnelNetworkSettings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: tunGateway)
        
        let ipv4Settings = NEIPv4Settings(addresses: [tunIPAddress], subnetMasks: [tunSubnetMask])
        ipv4Settings.includedRoutes = [NEIPv4Route.default()]
        
        var excludedRoutes = [
            NEIPv4Route(destinationAddress: "10.0.0.0", subnetMask: "255.0.0.0"),
            NEIPv4Route(destinationAddress: "172.16.0.0", subnetMask: "255.240.0.0"),
            NEIPv4Route(destinationAddress: "192.168.0.0", subnetMask: "255.255.0.0"),
            NEIPv4Route(destinationAddress: "127.0.0.0", subnetMask: "255.0.0.0"),
        ]
        
        if let serverIP = resolvedServerIP {
            excludedRoutes.append(NEIPv4Route(destinationAddress: serverIP, subnetMask: "255.255.255.255"))
            debugLog("🛡️ Excluding server IP \(serverIP) from routes")
        }
        
        ipv4Settings.excludedRoutes = excludedRoutes
        tunnelNetworkSettings.ipv4Settings = ipv4Settings
        tunnelNetworkSettings.dnsSettings = NEDNSSettings(servers: dnsServers)
        tunnelNetworkSettings.mtu = 9000
        
        setTunnelNetworkSettings(tunnelNetworkSettings) { [weak self] error in
            guard let self = self else { return }
            
            if let error = error {
                self.debugLog("❌ setTunnelNetworkSettings failed: \(error.localizedDescription)")
                _ = LibXrayStopXray()
                completionHandler(error)
                return
            }
            
            self.debugLog("✅ Network settings applied")
            self.startFortivaRouting(completionHandler: completionHandler)
        }
    }
    
    private func startFortivaRouting(completionHandler: @escaping (Error?) -> Void) {
        guard let tunFd = self.getTunnelFileDescriptor() else {
            debugLog("❌ Failed to get TUN fd")
            completionHandler(NSError(domain: "FortivaError", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to get TUN FD"]))
            return
        }
        
        debugLog("✅ Got TUN fd = \(tunFd)")
        
        guard let configPath = writeRoutingConfig() else {
            completionHandler(NSError(domain: "FortivaError", code: 4, userInfo: [NSLocalizedDescriptionKey: "Failed to write config"]))
            return
        }
        
        DispatchQueue.global(qos: .userInteractive).async { [weak self] in
            guard let self = self else { return }
            let code = Socks5Tunnel.run(withFileDescriptor: tunFd, configFilePath: configPath)
            self.debugLog("📊 FortivaRouting exited with code: \(code)")
        }
        
        Thread.sleep(forTimeInterval: 0.2)
        
        debugLog("🎉 TUNNEL STARTED! FortivaRouting → SOCKS5 127.0.0.1:\(socksPort)")
        completionHandler(nil)
    }
    
    private func getTunnelFileDescriptor() -> Int32? {
        var buf = [CChar](repeating: 0, count: Int(IFNAMSIZ))
        
        for fd: Int32 in 0...1024 {
            var len = socklen_t(buf.count)
            if getsockopt(fd, 2, 2, &buf, &len) == 0 {
                let name = String(cString: buf)
                if name.hasPrefix("utun") { return fd }
            }
        }
        
        if let fd = (self.packetFlow.value(forKeyPath: "socket.fileDescriptor") as? Int32) {
            return fd
        }
        return nil
    }
    
    private func writeRoutingConfig() -> String? {
        let config = """
        tunnel:
          mtu: 9000
        
        socks5:
          port: \(socksPort)
          address: 127.0.0.1
          udp: 'udp'
        
        misc:
          task-stack-size: 20480
          connect-timeout: 5000
          read-write-timeout: 60000
          log-level: info
        """
        
        let configPath = (NSTemporaryDirectory() as NSString).appendingPathComponent("fortiva_routing.yml")
        do {
            try config.write(toFile: configPath, atomically: true, encoding: .utf8)
            return configPath
        } catch {
            debugLog("❌ Write routing config failed: \(error.localizedDescription)")
            return nil
        }
    }
    
    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        debugLog("🛑 TUNNEL: Stopping, reason=\(reason.rawValue)")
        Socks5Tunnel.quit()
        _ = LibXrayStopXray()
        completionHandler()
    }
    
    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
        completionHandler?(nil)
    }
    
    override func sleep(completionHandler: @escaping () -> Void) { completionHandler() }
    override func wake() {}
    
    private func getAssetDirectory() -> String {
        if let containerUrl = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.vpn.fortivavpn") {
            return containerUrl.path
        }
        return NSTemporaryDirectory()
    }
}
