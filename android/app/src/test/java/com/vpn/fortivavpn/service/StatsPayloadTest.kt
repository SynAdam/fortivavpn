package com.vpn.fortivavpn.service

import com.google.gson.JsonParser
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * The traffic answer between the tunnel's process and the app: the old
 * comma-separated text without the session readings, one JSON object with
 * them. Both ends ship in the same APK, so the reader takes either.
 */
class StatsPayloadTest {
    @Test
    fun theOldTextStillReads() {
        assertEquals(mapOf("bytes_up" to 12L, "bytes_down" to 34L), StatsPayload.parse("12,34"))
    }

    @Test
    fun theOldTextKeepsTheDoorJsonWhole() {
        val status = """{"state":"ok","doors":[{"index":0},{"index":1}]}"""
        val stats = StatsPayload.parse("1,2,3,$status")!!

        assertEquals(1L, stats["bytes_up"])
        assertEquals(2L, stats["bytes_down"])
        assertEquals(3, stats["door_index"])
        assertEquals(status, stats["door_status"])
    }

    @Test
    fun aMissingOrBrokenAnswerIsNoReadingNotZeroBytes() {
        assertNull(StatsPayload.parse(null))
        assertNull(StatsPayload.parse(""))
        assertNull(StatsPayload.parse("x,1"))
        assertNull(StatsPayload.parse("5"))
        assertNull(StatsPayload.parse("{"))
        assertNull(StatsPayload.parse("""{"down":1}"""))
        assertNull(StatsPayload.parse("""{"up":"1","down":2}"""))
        assertNull(StatsPayload.parse("[1,2]"))
    }

    @Test
    fun theJsonAnswerReadsBackAsTheAppWantsIt() {
        var clock = 0L
        val meter = SessionMeter(SessionSettings.of(1000L, 3000L, 0L)!!) { clock }
        clock = 1000L
        meter.take(mapOf(0 to SessionMeter.Bytes(100L, 0L), 1 to SessionMeter.Bytes(5L, 50L)))
        val status = """{"state":"degraded","switch_count":2}"""

        val payload = StatsPayload.encode(meter.report(beat = true), 1, status)
        val stats = StatsPayload.parse(payload)!!

        assertTrue(payload.startsWith("{"))
        assertEquals(105L, stats["bytes_up"])
        assertEquals(50L, stats["bytes_down"])
        assertEquals(1, stats["door_index"])
        assertEquals(status, stats["door_status"])
        @Suppress("UNCHECKED_CAST")
        val session = stats["session"] as Map<String, Any?>
        assertEquals(1000L, session["interval_ms"])
        assertEquals(105L, session["up_total"])
        assertEquals(1L, session["busy_samples"])
        assertEquals(0L, session["tput_med_kbps"])
        assertEquals(1000L, session["first_down_ms"])
        assertEquals(listOf(listOf(0L, 100L, 0L), listOf(1L, 5L, 50L)), session["doors"])
        assertTrue(session.containsKey("tput_p90_kbps"))
    }

    @Test
    fun aReadThatIsNotAHeartbeatCarriesNoSessionBlock() {
        var clock = 0L
        val meter = SessionMeter(SessionSettings.of(1000L, 3000L, 0L)!!) { clock }
        clock = 1000L
        meter.take(mapOf(0 to SessionMeter.Bytes(7L, 9L)))

        val payload = StatsPayload.encode(meter.report(beat = false), null, null)
        val stats = StatsPayload.parse(payload)!!

        assertEquals(mapOf("bytes_up" to 7L, "bytes_down" to 9L), stats)
        val raw = JsonParser.parseString(payload).asJsonObject
        assertEquals(setOf("up", "down", "door_index", "door_status", "session"), raw.keySet())
        assertTrue(raw.get("session").isJsonNull)
        assertTrue(raw.get("door_index").isJsonNull)
    }

    @Test
    fun withoutABackupNetworkRegionThePlainAnswerIsTheOldText() {
        assertEquals("12,34", StatsPayload.encodePlain(12L, 34L, null, null, null))
        assertEquals("1,2,3,{}", StatsPayload.encodePlain(1L, 2L, 3, "{}", null))
        // A value that is not a region is no region.
        assertEquals("12,34", StatsPayload.encodePlain(12L, 34L, null, null, "de"))
    }

    @Test
    fun theBackupNetworkRegionRidesAlongAsJson() {
        val payload = StatsPayload.encodePlain(12L, 34L, null, null, "DE")
        val stats = StatsPayload.parse(payload)!!

        assertTrue(payload.startsWith("{"))
        assertEquals(mapOf("bytes_up" to 12L, "bytes_down" to 34L, "psiphon_region" to "DE"), stats)
    }

    @Test
    fun theBackupNetworkRegionRidesAlongWithTheSessionReadings() {
        var clock = 0L
        val meter = SessionMeter(SessionSettings.of(1000L, 3000L, 0L)!!) { clock }
        clock = 1000L
        meter.take(mapOf(0 to SessionMeter.Bytes(7L, 9L)))

        val stats = StatsPayload.parse(StatsPayload.encode(meter.report(beat = true), null, null, "NL"))!!

        assertEquals("NL", stats["psiphon_region"])
        assertTrue(stats.containsKey("session"))
    }

    @Test
    fun aBadRegionInTheAnswerIsLeftOut() {
        for (bad in listOf("\"de\"", "\"DEU\"", "1", "null", "{}")) {
            val stats = StatsPayload.parse("""{"up":1,"down":2,"psiphon_region":$bad}""")!!
            assertFalse(bad, stats.containsKey("psiphon_region"))
        }
    }

    @Test
    fun aNewerBackupNetworkVersionRidesAlongAsJson() {
        val payload = StatsPayload.encodePlain(12L, 34L, null, null, null, "412")
        assertTrue(payload.startsWith("{"))
        assertEquals(
            mapOf("bytes_up" to 12L, "bytes_down" to 34L, "psiphon_upgrade" to "412"),
            StatsPayload.parse(payload),
        )

        val both = StatsPayload.parse(StatsPayload.encodePlain(1L, 2L, null, null, "DE", "412"))!!
        assertEquals("DE", both["psiphon_region"])
        assertEquals("412", both["psiphon_upgrade"])
    }

    @Test
    fun aNewerBackupNetworkVersionRidesAlongWithTheSessionReadings() {
        var clock = 0L
        val meter = SessionMeter(SessionSettings.of(1000L, 3000L, 0L)!!) { clock }
        clock = 1000L
        meter.take(mapOf(0 to SessionMeter.Bytes(7L, 9L)))

        val stats = StatsPayload.parse(StatsPayload.encode(meter.report(beat = true), null, null, null, "9"))!!

        assertEquals("9", stats["psiphon_upgrade"])
        assertFalse(stats.containsKey("psiphon_region"))
        assertTrue(stats.containsKey("session"))
    }

    @Test
    fun aValueThatIsNotAVersionIsLeftOut() {
        // Not sent: the plain answer stays the old text.
        assertEquals("12,34", StatsPayload.encodePlain(12L, 34L, null, null, null, "1.2"))
        assertEquals("12,34", StatsPayload.encodePlain(12L, 34L, null, null, null, ""))
        for (bad in listOf("\"1.2\"", "\"\"", "412", "null", "{}", "\"198.51.100.4\"")) {
            val stats = StatsPayload.parse("""{"up":1,"down":2,"psiphon_upgrade":$bad}""")!!
            assertFalse(bad, stats.containsKey("psiphon_upgrade"))
        }
    }

    @Test
    fun aDoorStatusWithoutADoorIsDropped() {
        // As in the text form: the status means nothing without the door.
        val stats = StatsPayload.parse("""{"up":1,"down":2,"door_index":null,"door_status":"{}"}""")!!
        assertFalse(stats.containsKey("door_status"))
        assertFalse(stats.containsKey("door_index"))
    }
}
