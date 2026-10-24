package com.vpn.fortivavpn.service

import org.json.JSONObject

/**
 * The config the backup network's library (Psiphon's tunnel core) starts
 * with: the network keys the app sent, which come from the backend, plus
 * the keys this device owns.
 *
 * The backend already leaves the device's keys out. They are set here on
 * every start anyway, over anything the network config carries, because a
 * wrong value in one of them breaks the tunnel or exposes it: the core's
 * outbound points at [Device.socksPort], and nothing else may decide where
 * the proxy listens.
 *
 * Kept apart from the Android calls so it can be tested without a device.
 */
object PsiphonConfig {

    /**
     * Keys that are removed and not replaced. Each changes how or where
     * the local proxy listens, or hands the library a file descriptor of
     * this process:
     * - LocalHttpProxyPort: the HTTP proxy is off ([DISABLE_HTTP_PROXY]).
     * - ListenInterface: the proxy listens on 127.0.0.1 only, the default.
     * - DisableLocalSocksProxy and UseUnixDomainSockets: the core needs the
     *   SOCKS proxy on a TCP port.
     * - PacketTunnelTunFileDescriptor: the tun belongs to tun2socks.
     */
    val REMOVED_KEYS = listOf(
        "LocalHttpProxyPort",
        "ListenInterface",
        "DisableLocalSocksProxy",
        "UseUnixDomainSockets",
        "PacketTunnelTunFileDescriptor",
    )

    const val DATA_ROOT = "DataRootDirectory"
    const val SOCKS_PORT = "LocalSocksProxyPort"
    const val DISABLE_HTTP_PROXY = "DisableLocalHTTPProxy"
    const val ESTABLISH_TIMEOUT = "EstablishTunnelTimeoutSeconds"
    const val CLIENT_PLATFORM = "ClientPlatform"
    const val CLIENT_VERSION = "ClientVersion"
    const val DIAGNOSTIC_NOTICES = "EmitDiagnosticNotices"
    const val LIMIT_CPU_THREADS = "LimitCPUThreads"

    /** What this device sets on every start. */
    data class Device(
        val dataRoot: String,
        val socksPort: Int,
        val timeoutSeconds: Int,
        val clientPlatform: String,
        val clientVersion: String,
    )

    /**
     * [network] with [device]'s keys set and [REMOVED_KEYS] taken out, as
     * JSON. Null when [network] is not a JSON object.
     */
    fun merge(network: String, device: Device): String? {
        val json = try {
            JSONObject(network)
        } catch (e: Exception) {
            return null
        }
        REMOVED_KEYS.forEach { json.remove(it) }
        json.put(DATA_ROOT, device.dataRoot)
        json.put(SOCKS_PORT, device.socksPort)
        json.put(DISABLE_HTTP_PROXY, true)
        json.put(ESTABLISH_TIMEOUT, device.timeoutSeconds)
        json.put(CLIENT_PLATFORM, device.clientPlatform)
        json.put(CLIENT_VERSION, device.clientVersion)
        // Diagnostic notices can hold addresses and other details of the
        // session. Nothing here needs them.
        json.put(DIAGNOSTIC_NOTICES, false)
        // When true, Psiphon sets GOMAXPROCS to 1 for the whole process, and
        // the Xray core shares that process.
        json.put(LIMIT_CPU_THREADS, false)
        return json.toString()
    }

    /**
     * `Android_<release>_<package>`, the form Psiphon's own Android library
     * sends, with anything other than letters, digits, `_`, `-` and `.`
     * written as `_`.
     */
    fun clientPlatform(release: String?, packageName: String): String =
        "Android_${release.orEmpty()}_$packageName".replace(Regex("[^A-Za-z0-9_.\\-]"), "_")

    /** The library's own wait for a first tunnel, in whole seconds, at least one. */
    fun timeoutSeconds(timeoutMs: Long): Int =
        ((timeoutMs.coerceAtLeast(1L) + 999L) / 1000L).coerceAtMost(Int.MAX_VALUE.toLong()).toInt()
}
