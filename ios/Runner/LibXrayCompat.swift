import Foundation

// Compatibility layer over upstream libXray's single entry point.
//
// The vendored framework used to be a Fortiva fork that exported seven flat
// functions. Upstream replaced all of them with one dispatcher:
//
//     NSString *LibXrayInvoke(NSString *requestJSON)
//
// taking {"apiVersion":1,"method":"...","payload":{...}} and returning
// {"success":bool,"data":any,"error":string}.
//
// Rather than rewrite the three call sites, this file re-implements the old
// names with the old signatures on top of Invoke. The old functions took and
// returned base64-wrapped JSON, which was the fork's convention rather than
// anything Xray requires, so that shape is preserved here and the callers are
// untouched. Delete this file once the call sites speak Invoke directly.
//
// See issue #30.

/// Send one request to the core and decode its envelope.
private func invoke(_ method: String, _ payload: [String: Any]? = nil) -> [String: Any] {
    var request: [String: Any] = ["apiVersion": 1, "method": method]
    if let payload, !payload.isEmpty {
        request["payload"] = payload
    }

    guard let requestData = try? JSONSerialization.data(withJSONObject: request),
          let requestJSON = String(data: requestData, encoding: .utf8) else {
        return ["success": false, "error": "could not encode \(method) request"]
    }

    let raw = LibXrayInvoke(requestJSON)

    guard let rawData = raw.data(using: .utf8),
          let decoded = try? JSONSerialization.jsonObject(with: rawData) as? [String: Any] else {
        return ["success": false, "error": "could not decode \(method) response"]
    }
    return decoded
}

/// Re-wrap a decoded envelope the way the old fork handed it back.
private func base64Envelope(_ response: [String: Any]) -> String {
    guard let data = try? JSONSerialization.data(withJSONObject: response) else { return "" }
    return data.base64EncodedString()
}

private func decodeBase64JSON(_ base64: String) -> [String: Any]? {
    guard let data = Data(base64Encoded: base64) else { return nil }
    return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
}

// MARK: - The old API

/// Convert a share link to an Xray JSON config.
///
/// Takes a base64-encoded link, returns a base64-encoded envelope.
func LibXrayConvertShareLinksToXrayJson(_ base64Link: String) -> String {
    guard let linkData = Data(base64Encoded: base64Link),
          let link = String(data: linkData, encoding: .utf8) else {
        return base64Envelope(["success": false, "error": "link was not valid base64"])
    }
    return base64Envelope(invoke("convertShareLinksToXrayJson", ["text": link]))
}

/// Ask the core for free local ports.
///
/// The envelope keeps upstream's `{"ports":[N]}` shape under `data`, which is
/// the first branch the existing parser in AppDelegate already tries.
func LibXrayGetFreePorts(_ count: Int) -> String {
    return base64Envelope(invoke("getFreePorts", ["count": count]))
}

/// Measure delay through a config.
///
/// The old request carried `datDir` and `count`, which upstream's PingRequest
/// does not have. `datDir` is applied as the asset location instead, since
/// that is what it was really for, and `count` is dropped.
///
/// Upstream answers `{"delay": N}`. The old function put the integer directly
/// in `data`, and AppDelegate reads it that way, so it is flattened here.
func LibXrayPing(_ base64Request: String) -> String {
    guard let request = decodeBase64JSON(base64Request) else {
        return base64Envelope(["success": false, "error": "ping request was not valid base64 JSON"])
    }

    if let datDir = request["datDir"] as? String, !datDir.isEmpty {
        setXrayAssetLocation(datDir)
    }

    var payload: [String: Any] = [:]
    for key in ["configPath", "url", "proxy"] {
        if let value = request[key] as? String, !value.isEmpty { payload[key] = value }
    }
    if let timeout = request["timeout"] as? Int { payload["timeout"] = timeout }

    var response = invoke("ping", payload)
    if let data = response["data"] as? [String: Any], let delay = data["delay"] {
        response["data"] = delay
    }
    return base64Envelope(response)
}

/// Build a run request.
///
/// The fork returned an opaque object that `LibXrayRunXrayFromJSON` consumed.
/// Upstream takes the config JSON directly, so the config is passed straight
/// through and the two directory arguments are applied as the asset location.
///
/// Both directories were always the same value at every call site. The second
/// is accepted and ignored so the callers do not have to change.
func LibXrayNewXrayRunFromJSONRequest(
    _ datDir: String,
    _ unusedSecondDir: String,
    _ configJSON: String,
    _ error: inout NSError?
) -> String {
    _ = unusedSecondDir
    if !datDir.isEmpty {
        setXrayAssetLocation(datDir)
    }
    if configJSON.isEmpty {
        error = NSError(
            domain: "LibXrayCompat",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "empty Xray config"]
        )
        return ""
    }
    error = nil
    return configJSON
}

/// Start the core from a JSON config.
func LibXrayRunXrayFromJSON(_ configJSON: String) -> String {
    return base64Envelope(invoke("runXrayFromJson", ["configJSON": configJSON]))
}

/// Stop the core. Safe to call when nothing is running.
@discardableResult
func LibXrayStopXray() -> String {
    return base64Envelope(invoke("stopXray"))
}

/// Whether the core is currently running.
func LibXrayGetXrayState() -> Bool {
    let response = invoke("getXrayState")
    guard response["success"] as? Bool == true else { return false }
    if let data = response["data"] as? [String: Any], let running = data["running"] as? Bool {
        return running
    }
    return false
}

// MARK: - Asset location

/// Point the core at the directory holding geoip.dat and geosite.dat.
///
/// The fork took a directory argument and set this internally. Upstream's run
/// and ping paths do not, so it has to be set here or every `geoip:`/`geosite:`
/// token fails to resolve and the core rejects the whole config.
///
/// The iOS app bundles neither database today, which is why AppDelegate strips
/// routing and dns from ping configs. Setting the variable anyway costs
/// nothing and means shipping the databases is the only remaining step.
private func setXrayAssetLocation(_ directory: String) {
    setenv("XRAY_LOCATION_ASSET", directory, 1)
}
