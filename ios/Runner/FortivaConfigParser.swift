//
//  FortivaConfigParser.swift
//  Runner
//
//  FortivaVPN — Protocol Configuration Parser
//

import Foundation

/// Parsed protocol configuration from a share link
struct FortivaProtocolConfig: Equatable {
    let uuid: String
    let address: String
    let port: Int
    let type: String         // tcp, ws, grpc, http
    let encryption: String   // none
    let security: String     // none, tls, reality
    let headerType: String?  // http, none
    let path: String?
    let host: String?
    let sni: String?
    let fingerprint: String?
    let name: String?
    // XTLS Flow (e.g. xtls-rprx-vision)
    let flow: String?
    // Reality protocol fields
    let publicKey: String?   // pbk
    let shortId: String?     // sid
    let spiderX: String?     // spx
    
    /// Generate Xray-core JSON configuration
    func toXrayConfig(socksPort: Int = 10808, httpPort: Int = 10809) -> String {
        let socksInbound = """
        {
            "tag": "socks-in",
            "port": \(socksPort),
            "listen": "127.0.0.1",
            "protocol": "socks",
            "settings": {
                "udp": true
            }
        }
        """
        
        let httpInbound = """
        {
            "tag": "http-in",
            "port": \(httpPort),
            "listen": "127.0.0.1",
            "protocol": "http",
            "settings": {}
        }
        """
        
        var streamSettings: [String: Any] = [
            "network": type
        ]
        
        // Configure transport settings based on type
        switch type {
        case "tcp":
            if headerType == "http" {
                streamSettings["tcpSettings"] = [
                    "header": [
                        "type": "http",
                        "request": [
                            "path": [path ?? "/"]
                        ]
                    ]
                ]
            }
        case "ws":
            streamSettings["wsSettings"] = [
                "path": path ?? "/",
                "headers": host != nil ? ["Host": host!] : [:]
            ]
        case "grpc":
            streamSettings["grpcSettings"] = [
                "serviceName": path ?? ""
            ]
        default:
            break
        }
        
        // Configure security
        if security == "reality" {
            streamSettings["security"] = "reality"
            var realitySettings: [String: Any] = [:]
            if let sni = sni {
                realitySettings["serverName"] = sni
            }
            if let fp = fingerprint {
                realitySettings["fingerprint"] = fp
            } else {
                // Default fingerprint for Reality
                realitySettings["fingerprint"] = "chrome"
            }
            if let pbk = publicKey {
                realitySettings["publicKey"] = pbk
            }
            if let sid = shortId {
                realitySettings["shortId"] = sid
            }
            if let spx = spiderX {
                realitySettings["spiderX"] = spx
            }
            streamSettings["realitySettings"] = realitySettings
        } else if security == "tls" {
            streamSettings["security"] = "tls"
            var tlsSettings: [String: Any] = [:]
            if let sni = sni {
                tlsSettings["serverName"] = sni
            }
            if let fp = fingerprint {
                tlsSettings["fingerprint"] = fp
            }
            streamSettings["tlsSettings"] = tlsSettings
        } else {
            streamSettings["security"] = "none"
        }
        
        // Convert stream settings to JSON string
        let streamSettingsData = try? JSONSerialization.data(withJSONObject: streamSettings, options: [])
        let streamSettingsJson = streamSettingsData.flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
        
        // Build user object with optional flow
        var userFields = """
            "id": "\(uuid)",
            "encryption": "\(encryption)",
            "level": 0
        """
        if let flow = flow, !flow.isEmpty {
            userFields += """
            ,
            "flow": "\(flow)"
            """
        }
        
        let proxyOutbound = """
        {
            "tag": "proxy",
            "protocol": "vless",
            "settings": {
                "vnext": [{
                    "address": "\(address)",
                    "port": \(port),
                    "users": [{
                        \(userFields)
                    }]
                }]
            },
            "streamSettings": \(streamSettingsJson)
        }
        """
        
        let directOutbound = """
        {
            "tag": "direct",
            "protocol": "freedom",
            "settings": {}
        }
        """
        
        return """
        {
            "log": {
                "loglevel": "debug"
            },
            "inbounds": [\(socksInbound), \(httpInbound)],
            "outbounds": [\(proxyOutbound), \(directOutbound)],
            "routing": {
                "domainStrategy": "AsIs",
                "rules": []
            }
        }
        """
    }

}

/// Parser for protocol share links
final class FortivaConfigParser {
    
    enum ParseError: Error, LocalizedError {
        case invalidScheme
        case invalidFormat
        case missingUUID
        case missingHost
        case invalidPort
        
        var errorDescription: String? {
            switch self {
            case .invalidScheme: return "Invalid protocol link scheme"
            case .invalidFormat: return "Invalid protocol link format"
            case .missingUUID: return "Missing UUID"
            case .missingHost: return "Missing host"
            case .invalidPort: return "Invalid port"
            }
        }
    }
    
    static func parse(_ link: String) throws -> FortivaProtocolConfig {
        guard link.lowercased().hasPrefix("vless://") else { throw ParseError.invalidScheme }
        
        let withoutScheme = String(link.dropFirst("vless://".count))
        let fragmentParts = withoutScheme.split(separator: "#", maxSplits: 1)
        let mainPart = String(fragmentParts[0])
        let name = fragmentParts.count > 1 ? String(fragmentParts[1]).removingPercentEncoding : nil
        
        let queryParts = mainPart.split(separator: "?", maxSplits: 1)
        let userHostPort = String(queryParts[0])
        let queryString = queryParts.count > 1 ? String(queryParts[1]) : ""
        
        var params: [String: String] = [:]
        if !queryString.isEmpty {
            let pairs = queryString.split(separator: "&")
            for pair in pairs {
                let keyValue = pair.split(separator: "=", maxSplits: 1)
                if keyValue.count == 2 {
                    let key = String(keyValue[0])
                    let value = String(keyValue[1]).removingPercentEncoding ?? String(keyValue[1])
                    params[key] = value
                }
            }
        }
        
        guard let atIndex = userHostPort.firstIndex(of: "@") else { throw ParseError.invalidFormat }
        
        let uuid = String(userHostPort[..<atIndex])
        guard !uuid.isEmpty else { throw ParseError.missingUUID }
        
        let hostPort = String(userHostPort[userHostPort.index(after: atIndex)...])
        
        let address: String
        let port: Int
        
        if hostPort.hasPrefix("[") {
            guard let closeBracket = hostPort.firstIndex(of: "]") else { throw ParseError.invalidFormat }
            address = String(hostPort[hostPort.index(after: hostPort.startIndex)..<closeBracket])
            let afterBracket = hostPort[hostPort.index(after: closeBracket)...]
            guard afterBracket.hasPrefix(":"), let portValue = Int(afterBracket.dropFirst()) else { throw ParseError.invalidPort }
            port = portValue
        } else {
            let parts = hostPort.split(separator: ":", maxSplits: 1)
            guard parts.count == 2 else { throw ParseError.invalidFormat }
            address = String(parts[0])
            guard !address.isEmpty else { throw ParseError.missingHost }
            guard let portValue = Int(parts[1]) else { throw ParseError.invalidPort }
            port = portValue
        }
        
        return FortivaProtocolConfig(
            uuid: uuid,
            address: address,
            port: port,
            type: params["type"] ?? "tcp",
            encryption: params["encryption"] ?? "none",
            security: params["security"] ?? "none",
            headerType: params["headerType"],
            path: params["path"],
            host: params["host"],
            sni: params["sni"],
            fingerprint: params["fp"],
            name: name,
            flow: params["flow"],
            publicKey: params["pbk"],
            shortId: params["sid"],
            spiderX: params["spx"]
        )
    }
}
