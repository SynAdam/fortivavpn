package com.vpn.fortivavpn.service

import com.vpn.fortivavpn.handler.LogPrivacy
import org.json.JSONObject

/** The notices of the backup network's library that the tunnel acts on. */
sealed interface PsiphonNotice {
    /** How many tunnels are up. One or more means connected. */
    data class Tunnels(val count: Int) : PsiphonNotice

    /** The port the local SOCKS proxy listens on. */
    data class ListeningSocksPort(val port: Int) : PsiphonNotice

    /** The SOCKS port the config named is taken. */
    data object SocksPortInUse : PsiphonNotice

    /** No tunnel came up within the library's own wait. */
    data object EstablishTimeout : PsiphonNotice

    /** The library stopped. */
    data object Exiting : PsiphonNotice

    /** The country of the server the tunnel goes through, two capital letters. */
    data class ServerRegion(val region: String) : PsiphonNotice

    /**
     * The network has a newer client version than the one this app says it
     * is ([version], a whole number). The library is built into the app, so
     * only a release brings a newer one.
     */
    data class UpgradeAvailable(val version: String) : PsiphonNotice
}

/** Why a backup network start failed, in the words of the tunnel's log. */
enum class PsiphonFailure(val word: String) {
    CONFIG("config"),
    START("start_error"),
    TIMEOUT("timeout"),
    ESTABLISH_TIMEOUT("establish_timeout"),
    EXITING("exiting"),
    PORT_IN_USE("port_in_use"),
}

/** How the wait for the first tunnel ended. */
sealed interface PsiphonWait {
    data object Connected : PsiphonWait
    data object Cancelled : PsiphonWait
    data object TimedOut : PsiphonWait
    data class Failed(val failure: PsiphonFailure) : PsiphonWait
}

/**
 * Reads the library's notices. Each is one JSON object,
 * `{"data":{...},"noticeType":"...","timestamp":"..."}`.
 *
 * Every call the library makes into the app, these included, waits on one
 * lock in the library. A slow notice holds up its name lookups and network
 * checks too, so a notice is read as cheaply as it can be: the type is found
 * by a scan of the text, and only the few notices acted on are parsed.
 *
 * ClientAddress (the user's public address) and ClientRegion (the
 * server's guess at the user's country) are never parsed and never logged.
 * Nor is any notice that quotes the server list ([debugLine]).
 *
 * Kept apart from the Android calls so it can be tested without a device.
 */
object PsiphonNotices {
    private const val TYPE_FIELD = "\"noticeType\":\""

    /** Notices whose text may never reach a log, even a debug one. */
    val NEVER_LOGGED = setOf("ClientAddress", "ClientRegion")

    private val REGION = Regex("^[A-Z]{2}$")

    /**
     * A client version as the network names one. Its server compares
     * versions as whole numbers, so anything else is not one.
     */
    val VERSION = Regex("^[0-9]{1,12}$")

    /**
     * Text of the notices about server entries, the app's server list
     * among them. A notice that holds it is logged by its type alone,
     * because an error reading the list can quote a piece of it.
     */
    private const val SERVER_ENTRY = "server entr"

    /** The notice's type, or null when [raw] is not a notice. */
    fun typeOf(raw: String): String? {
        val at = raw.indexOf(TYPE_FIELD)
        if (at >= 0) {
            val start = at + TYPE_FIELD.length
            val end = raw.indexOf('"', start)
            if (end > start) return raw.substring(start, end)
        }
        // Not the library's own compact form. Rare, so a full parse is fine.
        return try {
            JSONObject(raw).optString("noticeType").takeIf { it.isNotEmpty() }
        } catch (e: Exception) {
            null
        }
    }

    /** The notice the tunnel acts on, or null for any other notice. */
    fun parse(raw: String): PsiphonNotice? = when (typeOf(raw)) {
        "Tunnels" -> data(raw)?.optInt("count", -1)?.takeIf { it >= 0 }?.let { PsiphonNotice.Tunnels(it) }
        "ListeningSocksProxyPort" ->
            data(raw)?.optInt("port", 0)?.takeIf { it in 1..65535 }?.let { PsiphonNotice.ListeningSocksPort(it) }
        "SocksProxyPortInUse" -> PsiphonNotice.SocksPortInUse
        "EstablishTunnelTimeout" -> PsiphonNotice.EstablishTimeout
        "Exiting" -> PsiphonNotice.Exiting
        "ConnectedServerRegion" ->
            data(raw)?.optString("serverRegion")?.takeIf { REGION.matches(it) }?.let { PsiphonNotice.ServerRegion(it) }
        "ClientUpgradeAvailable" ->
            (data(raw)?.opt("version") as? String)?.takeIf { VERSION.matches(it) }?.let { PsiphonNotice.UpgradeAvailable(it) }
        else -> null
    }

    private fun data(raw: String): JSONObject? = try {
        JSONObject(raw).optJSONObject("data")
    } catch (e: Exception) {
        null
    }

    /**
     * The log line for [raw] in a debug build, or null when nothing may be
     * logged. A notice whose text names a site or an address (LogPrivacy),
     * or is about server entries, is logged by its type alone. Release
     * builds log no notices at all.
     */
    fun debugLine(raw: String): String? {
        val type = typeOf(raw) ?: return null
        if (type in NEVER_LOGGED) return null
        val typeOnly = raw.contains(SERVER_ENTRY, ignoreCase = true) || LogPrivacy.namesDestination(raw)
        return if (typeOnly) "[psiphon] $type" else "[psiphon] $raw"
    }

    /**
     * One look at the wait for the first tunnel: how it ended, or null to
     * keep waiting. A stop or a newer start wins over everything, then a
     * failure the library reported, then a tunnel, then the deadline.
     */
    fun waitStep(
        cancelled: Boolean,
        failure: PsiphonFailure?,
        tunnels: Int,
        now: Long,
        until: Long,
    ): PsiphonWait? = when {
        cancelled -> PsiphonWait.Cancelled
        failure != null -> PsiphonWait.Failed(failure)
        tunnels >= 1 -> PsiphonWait.Connected
        now >= until -> PsiphonWait.TimedOut
        else -> null
    }
}
