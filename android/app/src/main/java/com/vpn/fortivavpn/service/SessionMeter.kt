package com.vpn.fortivavpn.service

import com.google.gson.JsonArray
import com.google.gson.JsonNull
import com.google.gson.JsonObject
import com.vpn.fortivavpn.AppConfig
import com.vpn.fortivavpn.handler.MmkvManager

/**
 * What the backend asks the tunnel's process to measure about a session
 * (backend issue #365): how often to read the core's byte counters, how
 * long data sent with nothing coming back counts as a stall, and how many
 * bytes down in one reading make it a busy one.
 *
 * The app writes them on every connect (AppConfig.PREF_SESSION_*), zero
 * when the backend sent none, and the core reads them when it starts.
 */
data class SessionSettings(val sampleMs: Long, val stallMs: Long, val busyBytes: Long) {
    companion object {
        /**
         * Never faster than once a second. The door group reads the same
         * counters every 500 ms to see which door still brings bytes back,
         * and every reading here resets them. A burst that lands just
         * before a reset is gone before the group sees it, about one burst
         * in four at one reading a second and one in twenty at five.
         */
        const val MIN_SAMPLE_MS = 1000L
        const val MAX_SAMPLE_MS = 60_000L

        /**
         * The settings, or null when the readings are off: no period or no
         * stall length. A period outside [MIN_SAMPLE_MS, MAX_SAMPLE_MS] is
         * brought inside it.
         */
        fun of(sampleMs: Long?, stallMs: Long?, busyBytes: Long?): SessionSettings? {
            val sample = sampleMs ?: 0L
            val stall = stallMs ?: 0L
            if (sample <= 0L || stall <= 0L) return null
            return SessionSettings(
                sample.coerceIn(MIN_SAMPLE_MS, MAX_SAMPLE_MS),
                stall,
                (busyBytes ?: 0L).coerceAtLeast(0L),
            )
        }

        /** What the last connect wrote, read in the tunnel's process. */
        fun read(): SessionSettings? = of(
            MmkvManager.decodeSettingsString(AppConfig.PREF_SESSION_SAMPLE_MS)?.trim()?.toLongOrNull(),
            MmkvManager.decodeSettingsString(AppConfig.PREF_SESSION_STALL_MS)?.trim()?.toLongOrNull(),
            MmkvManager.decodeSettingsString(AppConfig.PREF_SESSION_BUSY_BYTES)?.trim()?.toLongOrNull(),
        )

        /**
         * Written on every connect, in the app's process. Zero for a value
         * the app did not send, so one from an earlier connect never
         * lingers.
         */
        fun write(sampleMs: Long?, stallMs: Long?, busyBytes: Long?) {
            fun whole(value: Long?) = (value ?: 0L).coerceAtLeast(0L).toString()
            MmkvManager.encodeSettings(AppConfig.PREF_SESSION_SAMPLE_MS, whole(sampleMs))
            MmkvManager.encodeSettings(AppConfig.PREF_SESSION_STALL_MS, whole(stallMs))
            MmkvManager.encodeSettings(AppConfig.PREF_SESSION_BUSY_BYTES, whole(busyBytes))
        }
    }
}

/**
 * How good the tunnel's session is, read off the core's byte counters once
 * every [SessionSettings.sampleMs] while the core runs.
 *
 * The tunnel's process feeds it one reading at a time ([take]) and asks it
 * for a report when the app asks for the bytes ([report]). It keeps three
 * spans:
 *
 * - The session, since the core started: bytes each way, and how long the
 *   first byte down took to arrive.
 * - Since the last report of any kind: bytes each way. That is what the app
 *   has always been handed, so a heartbeat's bytes mean what they did.
 * - Since the last heartbeat's report (the interval): how many readings,
 *   how many were busy and how fast those were, the stalls, and the bytes
 *   of each door.
 *
 * Counters and times only: no address, app or destination. Pure logic with
 * the clock passed in ([now], in milliseconds that never go back), so a
 * test can drive it. Not thread safe: the tunnel's process uses it from its
 * main thread only.
 */
class SessionMeter(
    val settings: SessionSettings,
    private val now: () -> Long,
) {
    /** Bytes up and down one door moved. */
    class Bytes(var up: Long = 0L, var down: Long = 0L)

    private val startedAt = now()
    private var lastReadingAt = startedAt

    private var upTotal = 0L
    private var downTotal = 0L
    private var firstDownMs: Long? = null

    private var sinceReportUp = 0L
    private var sinceReportDown = 0L

    private var intervalStartedAt = startedAt
    private var samples = 0L
    private var busySamples = 0L
    private var stalls = 0L
    private var stalledMs = 0L
    private val doors = sortedMapOf<Int, Bytes>()

    /**
     * The speed of the interval's busy readings, in kbps. Bounded: past
     * [MAX_SPEEDS] it keeps every other value and from then on takes every
     * second busy reading, then every fourth, and so on, so a long interval
     * (the app closed for hours) is still sampled from end to end.
     */
    private val speeds = ArrayList<Long>()
    private var speedStride = 1L
    private var busySeen = 0L

    /** The run of readings that sent data and got nothing back, so far. */
    private var runMs = 0L
    private var runCounted = false

    /**
     * Whether a reading now would come at least [SessionSettings.MIN_SAMPLE_MS]
     * after the last one. A report takes a fresh reading only then.
     */
    fun readingDue(): Boolean = now() - lastReadingAt >= SessionSettings.MIN_SAMPLE_MS

    /**
     * One reading of the counters: the bytes each door moved since the
     * previous one, keyed by the door's position. Null is a reading that
     * failed. It is skipped, so the next one covers both periods.
     */
    fun take(reading: Map<Int, Bytes>?) {
        if (reading == null) return
        val at = now()
        val elapsed = at - lastReadingAt
        lastReadingAt = at

        var up = 0L
        var down = 0L
        for ((index, bytes) in reading) {
            if (bytes.up <= 0L && bytes.down <= 0L) continue
            up += bytes.up
            down += bytes.down
            val door = doors.getOrPut(index) { Bytes() }
            door.up += bytes.up
            door.down += bytes.down
        }
        upTotal += up
        downTotal += down
        sinceReportUp += up
        sinceReportDown += down
        if (firstDownMs == null && down > 0L) firstDownMs = at - startedAt

        // A reading long after the one before it spans a time the phone
        // slept: the reading period runs on uptime, which stops in deep
        // sleep. Its bytes count, but its speed and its silence say nothing
        // about the tunnel.
        if (elapsed <= 0L || elapsed > settings.sampleMs * GAP_PERIODS) {
            endRun()
            return
        }
        samples++
        if (busy(down, elapsed)) {
            busySamples++
            keepSpeed(down * 8L / elapsed)
        }
        if (up > 0L && down == 0L) stalled(elapsed, at) else endRun()
    }

    /**
     * Whether [down] bytes in [elapsed] ms make a busy reading: at least
     * the backend's busy bytes per period, or any byte down when it set
     * none. Measured as a rate, so a short reading (one a report took) is
     * held to the same bar as a full one.
     */
    private fun busy(down: Long, elapsed: Long): Boolean =
        if (settings.busyBytes <= 0L) {
            down > 0L
        } else {
            down > 0L && down * settings.sampleMs >= settings.busyBytes * elapsed
        }

    private fun keepSpeed(kbps: Long) {
        if (busySeen++ % speedStride != 0L) return
        speeds.add(kbps)
        if (speeds.size < MAX_SPEEDS) return
        val kept = speeds.filterIndexed { i, _ -> i % 2 == 0 }
        speeds.clear()
        speeds.addAll(kept)
        speedStride *= 2
    }

    /**
     * A reading that sent data and got none back. A run of them is one
     * stall once it lasts the backend's stall length; from then on its
     * time counts as stalled, the part before the threshold included.
     */
    private fun stalled(elapsed: Long, at: Long) {
        runMs += elapsed
        if (runCounted) {
            stalledMs += elapsed
            return
        }
        if (runMs < settings.stallMs) return
        runCounted = true
        stalls++
        // The part of the run inside this interval. A run that began before
        // the last heartbeat's report is counted where it reached the
        // threshold, and its earlier part stays out.
        stalledMs += minOf(runMs, at - intervalStartedAt)
    }

    private fun endRun() {
        runMs = 0L
        runCounted = false
    }

    /** What one report hands the app. */
    class Report(val up: Long, val down: Long, val session: JsonObject?)

    /**
     * The bytes since the last report, which starts their count again.
     * When [beat] (the app's heartbeat asked), also the session block,
     * which closes the interval:
     *
     * - `interval_ms`: since the previous heartbeat's report, or since the
     *   core started
     * - `up_total`, `down_total`: bytes since the core started
     * - `samples`, `busy_samples`: readings in the interval, and those that
     *   brought down at least the busy bytes
     * - `tput_med_kbps`, `tput_p90_kbps`: the median and 90th percentile
     *   (nearest rank) speed down of the busy readings, null with none
     * - `stalls`, `stall_ms`: runs of readings that sent data and got none
     *   back for at least the stall length, and their time
     * - `first_down_ms`: from the core's start to the first reading with a
     *   byte down, null until there is one. Only as sharp as the period.
     * - `doors`: `[index, up, down]` for each door that moved bytes in the
     *   interval
     *
     * There is no reconnect count. The app does not reconnect by itself:
     * a new connect is a new session, and the backend can tell those apart
     * from the events.
     */
    fun report(beat: Boolean): Report {
        val up = sinceReportUp
        val down = sinceReportDown
        sinceReportUp = 0L
        sinceReportDown = 0L
        if (!beat) return Report(up, down, null)

        val at = now()
        val sorted = speeds.sorted()
        val session = JsonObject().apply {
            addProperty("interval_ms", at - intervalStartedAt)
            addProperty("up_total", upTotal)
            addProperty("down_total", downTotal)
            addProperty("samples", samples)
            addProperty("busy_samples", busySamples)
            addNullable("tput_med_kbps", rank(sorted, 0.5))
            addNullable("tput_p90_kbps", rank(sorted, 0.9))
            addProperty("stalls", stalls)
            addProperty("stall_ms", stalledMs)
            addNullable("first_down_ms", firstDownMs)
            add(
                "doors",
                JsonArray().apply {
                    for ((index, bytes) in doors) {
                        add(
                            JsonArray().apply {
                                add(index)
                                add(bytes.up)
                                add(bytes.down)
                            },
                        )
                    }
                },
            )
        }

        intervalStartedAt = at
        samples = 0L
        busySamples = 0L
        stalls = 0L
        stalledMs = 0L
        doors.clear()
        speeds.clear()
        speedStride = 1L
        busySeen = 0L
        return Report(up, down, session)
    }

    private fun JsonObject.addNullable(name: String, value: Long?) {
        if (value == null) add(name, JsonNull.INSTANCE) else addProperty(name, value)
    }

    companion object {
        /** The most busy-reading speeds one interval keeps. */
        const val MAX_SPEEDS = 600

        /** A reading more than this many periods after the last spans a sleep. */
        const val GAP_PERIODS = 3L

        /** The value at [fraction] of [sorted] by nearest rank, or null when empty. */
        fun rank(sorted: List<Long>, fraction: Double): Long? {
            if (sorted.isEmpty()) return null
            val at = Math.ceil(fraction * sorted.size).toInt().coerceIn(1, sorted.size)
            return sorted[at - 1]
        }

        /**
         * The core's traffic answer, `tag,direction,value;` repeated, as the
         * bytes of each door. Only the proxy outbounds are the tunnel:
         * `direct` is what the routing rules kept off it and `block` never
         * left. A door's tag is `proxy@N` when the core holds several
         * (V2rayConfigManager.autoSelectMemberTag), and the one door's is
         * `proxy`, which is position 0.
         */
        fun parseTraffic(raw: String): Map<Int, Bytes> {
            val out = sortedMapOf<Int, Bytes>()
            for (entry in raw.split(";")) {
                val parts = entry.split(",")
                if (parts.size < 3) continue
                val tag = parts[0].trim()
                if (!tag.startsWith(AppConfig.TAG_PROXY)) continue
                val value = parts[2].trim().toLongOrNull() ?: continue
                val direction = parts[1].trim()
                val bytes = out.getOrPut(doorIndex(tag)) { Bytes() }
                when {
                    direction.startsWith("down") -> bytes.down += value
                    direction.startsWith("up") -> bytes.up += value
                }
            }
            return out
        }

        private fun doorIndex(tag: String): Int =
            tag.removePrefix("${AppConfig.TAG_PROXY}@").takeIf { it != tag }?.toIntOrNull() ?: 0
    }
}
