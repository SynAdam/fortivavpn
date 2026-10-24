package com.vpn.fortivavpn.handler

import android.os.SystemClock
import java.net.InetSocketAddress
import java.net.Socket
import java.net.SocketTimeoutException
import java.net.UnknownHostException

/**
 * Why a door check failed, in words the backend can sort.
 *
 * The core's delay test only says that no data came back, usually as "EOF"
 * or a timeout, because the core's own log is off for a check. So next to
 * the check the phone opens a plain TCP connection to the address the door
 * dials. When that fails too, the address is blocked on this network. When
 * it connects and the check still fails, the address is open and what was
 * cut is the handshake after it, or our server did not answer. On
 * 2026-10-05 that was the question about Hamrah Aval and our Cloudflare
 * door, and no failed check could answer it.
 */
object DoorCheck {

    /** How long the TCP connection gets. Under the check's own 3 s. */
    const val TCP_TIMEOUT_MS = 2500

    /** The longest error kept, from its end, where the core puts the cause. */
    const val MAX_ERROR = 120

    /**
     * Opens a TCP connection to [host]:[port] and closes it at once.
     * Returns the outcome (see [tcpOutcome]) and how long it took.
     */
    fun tcpReach(host: String, port: Int, timeoutMs: Int = TCP_TIMEOUT_MS): Pair<String, Long> {
        val started = SystemClock.elapsedRealtime()
        val outcome = try {
            Socket().use { it.connect(InetSocketAddress(host, port), timeoutMs) }
            "ok"
        } catch (e: Exception) {
            tcpOutcome(e)
        }
        return outcome to (SystemClock.elapsedRealtime() - started)
    }

    /**
     * One word for a failed TCP connect: timeout (nothing came back, which
     * is what a dropped address looks like), refused, reset, unreachable,
     * dns, or error.
     */
    fun tcpOutcome(e: Throwable): String {
        if (e is SocketTimeoutException) return "timeout"
        if (e is UnknownHostException) return "dns"
        val message = e.message.orEmpty()
        return when {
            "ECONNREFUSED" in message -> "refused"
            "ECONNRESET" in message -> "reset"
            "ENETUNREACH" in message || "EHOSTUNREACH" in message -> "unreachable"
            "ETIMEDOUT" in message || "timed out" in message -> "timeout"
            else -> "error"
        }
    }

    /**
     * The core's error on one line, cut to its last [max] characters. The
     * core nests its errors with the most specific cause last.
     */
    fun shorten(message: String?, max: Int = MAX_ERROR): String? {
        val flat = message?.replace(Regex("\\s+"), " ")?.trim()
        if (flat.isNullOrEmpty()) return null
        return if (flat.length <= max) flat else "..." + flat.takeLast(max - 3)
    }
}
