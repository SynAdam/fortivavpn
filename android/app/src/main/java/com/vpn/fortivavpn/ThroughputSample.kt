package com.vpn.fortivavpn

import java.io.InputStream

/**
 * The timing of one throughput sample (MainActivity.throughputSample), apart
 * from the connection it reads, so it can be checked without a tunnel.
 *
 * The clock starts once the response headers have arrived: `ms` is the time
 * the bytes took, not the setup of the connection through the tunnel (SOCKS,
 * TLS and the first round trip). The connection and the wait for the headers
 * keep their own limits, set on the connection. Until 2.2.0 the setup
 * counted against the bytes' time, so the stall watch's download check failed
 * on a tunnel with a slow first round trip that then carried at full speed.
 * On 2026-10-23 its throttle trigger made 106 drops on 72 phones, and the
 * heartbeats before them were mostly as large as the session's own normal.
 */
internal object ThroughputSample {
    /**
     * [respond] connects, waits for the headers and gives the status, with
     * the body for a 200. The body is read until it ends or [capMs] have
     * passed since the headers, and whatever arrived by then is the reading.
     *
     * Returns {bytes, ms} for a body that brought bytes, {bytes: 0, ms,
     * status} for any other status, where ms is the wait for the headers,
     * and null for a 200 that brought nothing. [now] is a clock in
     * milliseconds.
     */
    fun take(
        capMs: Int,
        now: () -> Long,
        respond: () -> Pair<Int, InputStream?>,
    ): HashMap<String, Any>? {
        val asked = now()
        val (code, body) = respond()
        // The headers are in. From here on, only the bytes.
        val start = now()
        if (code != 200 || body == null) {
            return hashMapOf("bytes" to 0L, "ms" to (start - asked), "status" to code)
        }
        var read = 0L
        body.use { input ->
            val buffer = ByteArray(16 * 1024)
            while (true) {
                val n = input.read(buffer)
                if (n < 0) break
                read += n
                if (now() - start >= capMs) break
            }
        }
        if (read <= 0L) return null
        // A body that was already in when the headers were read takes no
        // time on a millisecond clock. It still counts as one.
        val ms = (now() - start).coerceAtLeast(1L)
        return hashMapOf("bytes" to read, "ms" to ms)
    }
}
