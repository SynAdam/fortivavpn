//
//  FortivaConnectionEngine.swift
//  Runner
//
//  FortivaVPN — Secure Connection Manager
//

import NetworkExtension
import Foundation

/// Manager for secure protocol connections using Xray-core
final class FortivaConnectionEngine {
    
    // Status enum compatible with Flutter (String based for MethodChannel)
    enum FortivaConnectionStatus: String {
        case connected
        case connecting
        case disconnected
        case refrying
        
        init(from status: NEVPNStatus) {
            switch status {
            case .connected: self = .connected
            case .connecting: self = .connecting
            case .disconnected, .invalid: self = .disconnected
            case .reasserting: self = .refrying
            case .disconnecting: self = .disconnected
            @unknown default: self = .disconnected
            }
        }
    }
    
    static let shared = FortivaConnectionEngine()
    
    private(set) var status: FortivaConnectionStatus = .disconnected
    private var statusPollTimer: Timer?
    private var manager: NETunnelProviderManager?
    
    /// Bundle identifier for the secure network extension
    private let extensionBundleId = "com.vpn.fortivavpn.tunnel-ext"
    
    // Callback for status updates
    var onStatusChanged: ((FortivaConnectionStatus) -> Void)?
    
    private init() {}
    
    private func errorDetails(_ error: Error) -> String {
        let nsError = error as NSError
        return "[\(nsError.domain)] code=\(nsError.code) - \(nsError.localizedDescription)"
    }
    
    /// Sanitize protocol link — fix HTML-encoded ampersands from API
    private func sanitizeProtocolLink(_ link: String) -> String {
        var sanitized = link
        sanitized = sanitized.replacingOccurrences(of: "&amp;", with: "&")
        while sanitized.hasSuffix("&") {
            sanitized = String(sanitized.dropLast())
        }
        return sanitized
    }
    
    /// Resolve hostname to IPv4 — done HERE in the main app process
    /// where DNS is guaranteed to work (no VPN tunnel active yet)
    private func resolveHostToIP(_ host: String) -> String? {
        // Already an IP?
        var testAddr = in_addr()
        if inet_pton(AF_INET, host, &testAddr) == 1 {
            NSLog("🔍 FortivaEngine: '%@' is already an IP", host)
            return host
        }
        
        NSLog("🔍 FortivaEngine: Resolving '%@'...", host)
        var hints = addrinfo()
        hints.ai_family = AF_INET
        hints.ai_socktype = SOCK_STREAM
        
        var result: UnsafeMutablePointer<addrinfo>?
        let status = getaddrinfo(host, nil, &hints, &result)
        defer { freeaddrinfo(result) }
        
        guard status == 0, let addrInfo = result else {
            NSLog("❌ FortivaEngine: DNS failed for '%@', status=%d", host, status)
            return nil
        }
        
        var addr = addrInfo.pointee.ai_addr.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0.pointee }
        var ipBuf = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
        inet_ntop(AF_INET, &addr.sin_addr, &ipBuf, socklen_t(INET_ADDRSTRLEN))
        let ip = String(cString: ipBuf)
        NSLog("✅ FortivaEngine: Resolved '%@' → '%@'", host, ip)
        return ip
    }
    
    /// Extract host from a protocol link (without parsing the full config)
    private func extractHost(from link: String) -> String? {
        // vless://uuid@host:port?...
        let withoutScheme = link.replacingOccurrences(of: "vless://", with: "")
        guard let atIndex = withoutScheme.firstIndex(of: "@") else { return nil }
        let afterAt = String(withoutScheme[withoutScheme.index(after: atIndex)...])
        // Handle IPv6 [host]:port
        if afterAt.hasPrefix("[") {
            guard let closeBracket = afterAt.firstIndex(of: "]") else { return nil }
            return String(afterAt[afterAt.index(after: afterAt.startIndex)..<closeBracket])
        }
        // Regular host:port
        let parts = afterAt.split(separator: ":", maxSplits: 1)
        return parts.first.map(String.init)
    }
    
    /// Connect to a secure server using a share link
    func connect(vlessLink: String, dns: String?, completion: @escaping ((String?) -> Void)) {
        let cleanLink = sanitizeProtocolLink(vlessLink)
        NSLog("🔗 FortivaEngine: Clean link: %@", cleanLink)
        if let dns = dns {
            NSLog("🔗 FortivaEngine: Custom DNS: %@", dns)
        }
        
        // Extract host and resolve DNS in the main app (where DNS works)
        guard let host = extractHost(from: cleanLink) else {
            NSLog("❌ FortivaEngine: Could not extract host from link")
            completion("FAILED: Could not extract host from protocol link")
            return
        }
        
        let resolvedIP = resolveHostToIP(host)
        NSLog("✅ FortivaEngine: Host '%@' resolved to '%@'", host, resolvedIP ?? "FAILED")
        
        // Pass the raw protocol link + resolved IP to the Network Extension.
        // The extension uses LibXrayConvertShareLinksToXrayJson() to generate
        // the correct Xray config — this handles ALL protocol variations
        // (reality, XTLS, WebSocket, gRPC, etc.) that our custom parser misses.
        
        NETunnelProviderManager.loadAllFromPreferences { [weak self] managers, error in
            guard let self = self else { return }
            
            if let error = error {
                NSLog("❌ FortivaEngine: Load preferences failed: %@", self.errorDetails(error))
                DispatchQueue.main.async { completion("FAILED: \(self.errorDetails(error))") }
                return
            }
            
            let tunnelManager = managers?.first(where: { m in
                (m.protocolConfiguration as? NETunnelProviderProtocol)?.providerBundleIdentifier == self.extensionBundleId
            }) ?? NETunnelProviderManager()
            
            self.manager = tunnelManager
            
            let protocolConfig = NETunnelProviderProtocol()
            protocolConfig.providerBundleIdentifier = self.extensionBundleId
            protocolConfig.serverAddress = resolvedIP ?? host
            
            // Pass the raw link and resolved IP to the extension
            var providerConf: [String: Any] = [
                "vlessLink": cleanLink,
                "serverHost": host,
                "resolvedIP": resolvedIP ?? host,
            ]
            
            if let dns = dns {
                providerConf["dns"] = dns
            }
            
            protocolConfig.providerConfiguration = providerConf
            protocolConfig.disconnectOnSleep = false
            
            tunnelManager.protocolConfiguration = protocolConfig
            tunnelManager.localizedDescription = "FortivaVPN"
            tunnelManager.isEnabled = true
            
            // Save → Reload → Start
            tunnelManager.saveToPreferences { [weak self] error in
                guard let self = self else { return }
                if let error = error {
                    NSLog("❌ FortivaEngine: Save failed: %@", self.errorDetails(error))
                    DispatchQueue.main.async { completion("FAILED: \(self.errorDetails(error))") }
                    return
                }
                
                tunnelManager.loadFromPreferences { [weak self] error in
                    guard let self = self else { return }
                    if let error = error {
                        NSLog("❌ FortivaEngine: Reload failed: %@", self.errorDetails(error))
                        DispatchQueue.main.async { completion("FAILED: \(self.errorDetails(error))") }
                        return
                    }
                    
                    do {
                        guard let session = tunnelManager.connection as? NETunnelProviderSession else {
                            NSLog("❌ FortivaEngine: Invalid session")
                            DispatchQueue.main.async { completion("FAILED: Invalid session") }
                            return
                        }
                        self.startPollingStatus(session)
                        try session.startTunnel()
                        NSLog("✅ FortivaEngine: startTunnel called")
                        DispatchQueue.main.async { completion(nil) }
                    } catch {
                        NSLog("❌ FortivaEngine: startTunnel failed: %@", self.errorDetails(error))
                        DispatchQueue.main.async { completion("FAILED: \(self.errorDetails(error))") }
                    }
                }
            }
        }
    }
    
    func disconnect() {
        NSLog("🛑 FortivaEngine: Disconnecting...")
        NETunnelProviderManager.loadAllFromPreferences { [weak self] managers, error in
            guard let self = self else { return }
            if let error = error { return }
            guard let tunnelManager = managers?.first(where: { m in
                (m.protocolConfiguration as? NETunnelProviderProtocol)?.providerBundleIdentifier == self.extensionBundleId
            }) else { return }
            tunnelManager.connection.stopVPNTunnel()
            NSLog("✅ FortivaEngine: stopVPNTunnel called")
        }
    }
    
    func checkStatus() {
        NETunnelProviderManager.loadAllFromPreferences { [weak self] managers, error in
            guard let self = self else { return }
            if let _ = error { return }
            guard let tunnelManager = managers?.first(where: { m in
                (m.protocolConfiguration as? NETunnelProviderProtocol)?.providerBundleIdentifier == self.extensionBundleId
            }), let session = tunnelManager.connection as? NETunnelProviderSession else {
                self.updateStatus(.disconnected)
                return
            }
            self.startPollingStatus(session)
            self.updateStatus(FortivaConnectionStatus(from: session.status))
        }
    }
    
    private func startPollingStatus(_ session: NETunnelProviderSession) {
        statusPollTimer?.invalidate()
        statusPollTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.updateStatus(FortivaConnectionStatus(from: session.status))
        }
        RunLoop.main.add(statusPollTimer!, forMode: .common)
    }
    
    private func updateStatus(_ newStatus: FortivaConnectionStatus) {
        if self.status != newStatus {
            NSLog("📊 FortivaEngine: %@ → %@", self.status.rawValue, newStatus.rawValue)
            self.status = newStatus
            self.onStatusChanged?(newStatus)
        }
    }
    
    /// Path to Xray log file in shared App Group container
    func getXrayLogPath() -> String {
        if let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.vpn.fortivavpn") {
            return container.appendingPathComponent("xray.log").path
        }
        return (NSTemporaryDirectory() as NSString).appendingPathComponent("xray.log")
    }
    
    /// Read the last N lines from the Xray log file AND tunnel debug log
    func readXrayLogs(lastLines: Int = 100) -> String {
        var output = ""
        
        if let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.vpn.fortivavpn") {
            // Read tunnel debug log
            let debugLogPath = container.appendingPathComponent("tunnel_debug.log").path
            if let debugContent = try? String(contentsOfFile: debugLogPath, encoding: .utf8) {
                output += "=== TUNNEL DEBUG LOG ===\n"
                output += debugContent
                output += "\n"
            } else {
                output += "No tunnel_debug.log found\n"
            }
            
            // Read Xray log
            let xrayLogPath = container.appendingPathComponent("xray.log").path
            if let xrayContent = try? String(contentsOfFile: xrayLogPath, encoding: .utf8) {
                let lines = xrayContent.components(separatedBy: .newlines)
                let tail = lines.suffix(lastLines)
                output += "=== XRAY LOG ===\n"
                output += tail.joined(separator: "\n")
            } else {
                output += "No xray.log found\n"
            }
        }
        
        return output.isEmpty ? "No logs found" : output
    }
}
