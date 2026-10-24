package com.vpn.fortivavpn.service

import com.google.gson.JsonObject
import com.google.gson.JsonParser
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * The session readings in the tunnel's process (backend #365): what a
 * heartbeat learns about how good the session was, not only that it was up.
 */
class SessionMeterTest {
    private var clock = 0L

    private fun meter(sampleMs: Long = 1000L, stallMs: Long = 3000L, busyBytes: Long = 0L) =
        SessionMeter(SessionSettings.of(sampleMs, stallMs, busyBytes)!!) { clock }

    /** Bytes moved by each door since the last reading: index to (up, down). */
    private fun reading(vararg doors: Pair<Int, Pair<Long, Long>>): Map<Int, SessionMeter.Bytes> =
        doors.associate { (index, bytes) -> index to SessionMeter.Bytes(bytes.first, bytes.second) }

    /** One reading of the one door, [ms] after the last. */
    private fun SessionMeter.step(up: Long, down: Long, ms: Long = settings.sampleMs) {
        clock += ms
        take(reading(0 to (up to down)))
    }

    private fun SessionMeter.beat(): JsonObject = report(beat = true).session!!

    private fun JsonObject.long(name: String): Long = get(name).asLong

    @Test
    fun theReadingsAreOffWithoutAPeriodOrAStallLength() {
        assertNull(SessionSettings.of(null, 8000L, 0L))
        assertNull(SessionSettings.of(1000L, null, 0L))
        assertNull(SessionSettings.of(0L, 8000L, 0L))
        assertNull(SessionSettings.of(1000L, 0L, 0L))
        assertNull(SessionSettings.of(-5L, 8000L, 0L))
        assertEquals(0L, SessionSettings.of(1000L, 8000L, null)!!.busyBytes)
        assertEquals(0L, SessionSettings.of(1000L, 8000L, -1L)!!.busyBytes)
    }

    @Test
    fun thePeriodIsNeverUnderASecondNorOverAMinute() {
        // The door group samples the same counters every 500 ms.
        assertEquals(1000L, SessionSettings.of(200L, 8000L, 0L)!!.sampleMs)
        assertEquals(60_000L, SessionSettings.of(500_000L, 8000L, 0L)!!.sampleMs)
        assertEquals(5000L, SessionSettings.of(5000L, 8000L, 0L)!!.sampleMs)
    }

    @Test
    fun aReadingIsBusyWhenItBroughtDownTheBackendsBusyBytes() {
        val m = meter(busyBytes = 10_000L)
        m.step(10L, 20_000L)
        m.step(10L, 5_000L)
        m.step(10L, 10_000L)
        m.step(0L, 0L)

        val s = m.beat()
        assertEquals(4L, s.long("samples"))
        assertEquals(2L, s.long("busy_samples"))
    }

    @Test
    fun withNoBusyBytesAnyByteDownIsBusy() {
        val m = meter(busyBytes = 0L)
        m.step(0L, 1L)
        m.step(5L, 0L)
        m.step(0L, 0L)

        assertEquals(1L, m.beat().long("busy_samples"))
    }

    @Test
    fun aShortReadingIsHeldToTheSameRate() {
        // Half a period with half the busy bytes is as busy as a full one.
        val m = meter(sampleMs = 2000L, busyBytes = 10_000L)
        m.step(0L, 5_000L, ms = 1000L)
        m.step(0L, 4_000L, ms = 1000L)

        assertEquals(1L, m.beat().long("busy_samples"))
    }

    @Test
    fun theSpeedIsTheMedianAndNinetiethPercentileOfTheBusyReadings() {
        val m = meter()
        // 125 bytes in a second is one kilobit per second.
        for (kbps in listOf(700L, 100L, 1000L, 300L, 200L, 900L, 500L, 400L, 800L, 600L)) {
            m.step(10L, kbps * 125L)
        }
        m.step(10L, 0L)

        val s = m.beat()
        assertEquals(500L, s.long("tput_med_kbps"))
        assertEquals(900L, s.long("tput_p90_kbps"))
    }

    @Test
    fun withNoBusyReadingThereIsNoSpeed() {
        val m = meter()
        m.step(10L, 0L)

        val s = m.beat()
        assertTrue(s.get("tput_med_kbps").isJsonNull)
        assertTrue(s.get("tput_p90_kbps").isJsonNull)
    }

    @Test
    fun aLongIntervalKeepsItsSpeedsBoundedFromEndToEnd() {
        val m = meter()
        for (kbps in 1L..1500L) m.step(0L, kbps * 125L)

        val s = m.beat()
        assertEquals(1500L, s.long("busy_samples"))
        // Every other value, then every fourth, from the first reading to
        // the last: the middle of the interval is still its middle.
        assertTrue(s.long("tput_med_kbps") in 740L..760L)
        assertTrue(s.long("tput_p90_kbps") in 1340L..1360L)
    }

    @Test
    fun aRunOfSilentReadingsIsOneStallOnceItReachesTheStallLength() {
        val m = meter(stallMs = 3000L)
        repeat(5) { m.step(100L, 0L) }
        m.step(100L, 50L)
        // Two seconds: under the stall length.
        repeat(2) { m.step(100L, 0L) }
        m.step(0L, 50L)
        repeat(3) { m.step(100L, 0L) }

        val s = m.beat()
        assertEquals(2L, s.long("stalls"))
        // The whole first run, five seconds, and the second's three.
        assertEquals(8000L, s.long("stall_ms"))
    }

    @Test
    fun theStallLengthComesFromTheSettings() {
        val m = meter(stallMs = 8000L)
        repeat(5) { m.step(100L, 0L) }

        val s = m.beat()
        assertEquals(0L, s.long("stalls"))
        assertEquals(0L, s.long("stall_ms"))
    }

    @Test
    fun aReadingThatSentNothingEndsTheRun() {
        val m = meter(stallMs = 3000L)
        m.step(100L, 0L)
        m.step(100L, 0L)
        m.step(0L, 0L)
        m.step(100L, 0L)
        m.step(100L, 0L)

        assertEquals(0L, m.beat().long("stalls"))
    }

    @Test
    fun aStallThatGoesOnPastAHeartbeatIsCountedOnce() {
        val m = meter(stallMs = 3000L)
        repeat(4) { m.step(100L, 0L) }
        val first = m.beat()
        repeat(2) { m.step(100L, 0L) }
        val second = m.beat()

        assertEquals(1L, first.long("stalls"))
        assertEquals(4000L, first.long("stall_ms"))
        assertEquals(0L, second.long("stalls"))
        assertEquals(2000L, second.long("stall_ms"))
    }

    @Test
    fun theFirstByteDownIsTimedFromTheStartOnce() {
        val m = meter()
        m.step(100L, 0L)
        assertTrue(m.beat().get("first_down_ms").isJsonNull)
        m.step(100L, 0L)
        m.step(100L, 10L)
        m.step(100L, 10L)

        assertEquals(3000L, m.beat().long("first_down_ms"))
        m.step(0L, 99L)
        assertEquals(3000L, m.beat().long("first_down_ms"))
    }

    @Test
    fun eachDoorKeepsItsOwnBytesForTheInterval() {
        val m = meter()
        clock += 1000L
        m.take(reading(0 to (10L to 100L), 2 to (5L to 50L), 1 to (0L to 0L)))
        clock += 1000L
        m.take(reading(2 to (1L to 1L)))

        val doors = m.beat().getAsJsonArray("doors")
        assertEquals("[[0,10,100],[2,6,51]]", doors.toString())
        assertEquals("[]", m.beat().getAsJsonArray("doors").toString())
    }

    @Test
    fun aHeartbeatsReportClosesTheIntervalAndKeepsTheTotals() {
        val m = meter(stallMs = 1000L)
        m.step(100L, 0L)
        m.step(200L, 1000L)
        val first = m.beat()
        clock += 500L
        val second = m.beat()

        assertEquals(2000L, first.long("interval_ms"))
        assertEquals(2L, first.long("samples"))
        assertEquals(1L, first.long("busy_samples"))
        assertEquals(1L, first.long("stalls"))
        assertEquals(500L, second.long("interval_ms"))
        assertEquals(0L, second.long("samples"))
        assertEquals(0L, second.long("busy_samples"))
        assertEquals(0L, second.long("stalls"))
        assertEquals(0L, second.long("stall_ms"))
        assertEquals(300L, second.long("up_total"))
        assertEquals(1000L, second.long("down_total"))
    }

    @Test
    fun everyReportHandsOverTheBytesSinceTheLastOneButOnlyAHeartbeatClosesTheInterval() {
        val m = meter()
        m.step(100L, 1000L)
        val read = m.report(beat = false)
        m.step(10L, 20L)
        val beat = m.report(beat = true)

        assertEquals(100L, read.up)
        assertEquals(1000L, read.down)
        assertNull(read.session)
        assertEquals(10L, beat.up)
        assertEquals(20L, beat.down)
        assertEquals(2L, beat.session!!.long("samples"))
        assertEquals(2000L, beat.session!!.long("interval_ms"))
        assertEquals(0L, m.report(beat = false).up)
    }

    @Test
    fun aReadingAcrossASleepCountsItsBytesButNotAsAReading() {
        val m = meter(stallMs = 2000L)
        m.step(100L, 0L)
        // The handler runs on uptime, which stops in deep sleep.
        m.step(100L, 0L, ms = 10_000L)
        m.step(100L, 0L)
        m.step(0L, 80_000L, ms = 10_000L)

        val s = m.beat()
        assertEquals(2L, s.long("samples"))
        assertEquals(0L, s.long("busy_samples"))
        assertEquals(0L, s.long("stalls"))
        assertEquals(80_000L, s.long("down_total"))
        assertEquals(300L, s.long("up_total"))
    }

    @Test
    fun aFailedReadingIsSkipped() {
        val m = meter()
        clock += 1000L
        m.take(null)
        m.step(10L, 10L)

        // The reading after the failure covers both periods.
        assertEquals(1L, m.beat().long("samples"))
    }

    @Test
    fun aReportReadsAgainOnlyASecondAfterTheLastReading() {
        val m = meter(sampleMs = 5000L)
        assertFalse(m.readingDue())
        clock += 999L
        assertFalse(m.readingDue())
        clock += 1L
        assertTrue(m.readingDue())
        m.step(0L, 0L, ms = 0L)
        assertFalse(m.readingDue())
    }

    @Test
    fun theSessionBlockHasTheShapeTheAppSends() {
        val m = meter()
        m.step(100L, 200L)
        val text = m.beat().toString()

        val s = JsonParser.parseString(text).asJsonObject
        assertEquals(
            setOf(
                "interval_ms", "up_total", "down_total", "samples", "busy_samples",
                "tput_med_kbps", "tput_p90_kbps", "stalls", "stall_ms", "first_down_ms", "doors",
            ),
            s.keySet(),
        )
        assertEquals(1L, s.long("tput_med_kbps"))
        assertNotNull(s.get("first_down_ms"))
        // Small: it rides inside a heartbeat's diag, which the backend caps.
        assertTrue(text.length < 400)
    }

    @Test
    fun theCoresAnswerIsSplitByDoor() {
        val one = SessionMeter.parseTraffic("proxy,uplink,100;proxy,downlink,2000;direct,downlink,5;")
        assertEquals(setOf(0), one.keys)
        assertEquals(100L, one.getValue(0).up)
        assertEquals(2000L, one.getValue(0).down)

        val group = SessionMeter.parseTraffic(
            "proxy@0,uplink,1;proxy@2,downlink,7;block,uplink,3;proxy@2,uplink,4;bad;proxy@1,downlink,x;",
        )
        assertEquals(setOf(0, 2), group.keys)
        assertEquals(1L, group.getValue(0).up)
        assertEquals(4L, group.getValue(2).up)
        assertEquals(7L, group.getValue(2).down)
        assertTrue(SessionMeter.parseTraffic("").isEmpty())
    }
}
