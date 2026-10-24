package com.vpn.fortivavpn.handler

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.After
import org.junit.Test
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicInteger

class DoorChecksTest {

    @After
    fun forget() = DoorChecks.forgetForTests()

    @Test
    fun `the name lookup and the TLS handshake come through when the core sends them`() {
        val m = DoorChecks.readingOf(
            """{"ms":520,"boot_ms":40,"dns_ms":35,"dial_ms":95,"first_byte_ms":181,"tls_ms":260,""" +
                """"reply_ms":402,"bytes_out":2210,"bytes_in":6150,"dials":1,"dial_fails":0,"phase":"ok"}"""
        )!!
        assertEquals(35L, m["dnsMs"])
        assertEquals(260L, m["tlsMs"])
        val plain = DoorChecks.readingOf("""{"ms":300,"boot_ms":40,"dial_ms":90,"phase":"ok"}""")!!
        assertNull(plain["dnsMs"])
        assertNull(plain["tlsMs"])
    }

    @Test
    fun `a late swap waits for the check that is dialling and holds back new ones`() {
        val swaps = AtomicInteger()
        val swapped = CountDownLatch(1)
        DoorChecks.swapDialer = {
            swaps.incrementAndGet()
            swapped.countDown()
        }
        val inCheck = CountDownLatch(1)
        val release = CountDownLatch(1)
        val check = Thread {
            DoorChecks.usingCore {
                inCheck.countDown()
                release.await(5, TimeUnit.SECONDS)
            }
        }
        check.start()
        assertTrue(inCheck.await(2, TimeUnit.SECONDS))

        DoorChecks.prepareLater()
        // Not while a check is dialling.
        assertFalse(swapped.await(300, TimeUnit.MILLISECONDS))
        assertFalse(DoorChecks.timed)

        release.countDown()
        assertTrue(swapped.await(2, TimeUnit.SECONDS))
        check.join(2000)
        // A check after the swap runs with the timed check on.
        val sawTimed = DoorChecks.usingCore { DoorChecks.timed }
        assertTrue(sawTimed)

        // Asked again in the same run: nothing more happens.
        DoorChecks.prepareLater()
        Thread.sleep(100)
        assertEquals(1, swaps.get())
    }

    @Test
    fun `a swap that fails leaves the plain check in place`() {
        val tried = CountDownLatch(1)
        DoorChecks.swapDialer = {
            tried.countDown()
            throw IllegalStateException("no core")
        }
        DoorChecks.prepareLater()
        assertTrue(tried.await(2, TimeUnit.SECONDS))
        Thread.sleep(50)
        assertFalse(DoorChecks.timed)
        // The lock is free again: a core call still runs.
        assertEquals(7, DoorChecks.usingCore { 7 })
    }

    @Test
    fun `only a saved block that says so turns the timed check on`() {
        assertTrue(DoorChecks.savedSettingWantsTimed("""{"timed_checks":true,"network_keys":true}"""))
        assertFalse(DoorChecks.savedSettingWantsTimed("""{"network_keys":true}"""))
        assertFalse(DoorChecks.savedSettingWantsTimed("""{"timed_checks":"yes"}"""))
        assertFalse(DoorChecks.savedSettingWantsTimed("not json"))
        assertFalse(DoorChecks.savedSettingWantsTimed(null))
        assertFalse(DoorChecks.savedSettingWantsTimed(""))
    }

    @Test
    fun `an open door's timeline comes through under the keys Flutter reads`() {
        val m = DoorChecks.readingOf(
            """{"ms":412,"boot_ms":38,"cold_ms":690,"dial_ms":95,"first_byte_ms":181,""" +
                """"reply_ms":402,"bytes_out":2210,"bytes_in":6150,"dials":1,"dial_fails":0,"phase":"ok"}"""
        )!!
        assertEquals(true, m["timed"])
        assertEquals(412L, m["ms"])
        assertEquals(95L, m["dialMs"])
        assertEquals(181L, m["firstByteMs"])
        assertEquals(402L, m["replyMs"])
        assertEquals(6150L, m["bytesIn"])
        assertEquals(0L, m["dialFails"])
        assertEquals("ok", m["phase"])
        assertNull(m["error"])
    }

    @Test
    fun `a failed check keeps its phase and the end of its error`() {
        val long = "x".repeat(300) + " REALITY: processed invalid connection"
        val m = DoorChecks.readingOf(
            """{"ms":-1,"boot_ms":40,"dial_ms":120,"bytes_out":517,"bytes_in":0,"dials":1,""" +
                """"dial_fails":0,"phase":"tls","error":"$long"}"""
        )!!
        assertEquals(-1L, m["ms"])
        assertEquals("tls", m["phase"])
        val error = m["error"] as String
        assertTrue(error.length <= DoorCheck.MAX_ERROR)
        assertTrue(error.endsWith("processed invalid connection"))
        assertFalse(m.containsKey("firstByteMs"))
        assertFalse(m.containsKey("replyMs"))
    }

    @Test
    fun `an answer the core does not write is no reading`() {
        assertNull(DoorChecks.readingOf(null))
        assertNull(DoorChecks.readingOf(""))
        assertNull(DoorChecks.readingOf("{}"))
        assertNull(DoorChecks.readingOf("panic"))
    }

    @Test
    fun `a timed check with no answer in time reads closed in the app's words`() {
        val m = DoorChecks.noAnswer(3000L)
        assertEquals(true, m["timed"])
        assertEquals(-1L, m["ms"])
        assertEquals("no answer in 3000 ms", m["error"])
    }

    @Test
    fun `the core's no answer is said with the caller's whole wait`() {
        // The core was given 2600 ms, what was left of a 3000 ms wait.
        val json = """{"ms":-1,"dials":1,"dial_fails":1,"phase":"tcp","error":"no answer in 2600 ms"}"""
        val m = DoorChecks.readingOf(DoorChecks.inTheCallersWords(json, 3000L))!!
        assertEquals("no answer in 3000 ms", m["error"])
        assertEquals("tcp", m["phase"])
        assertEquals(1L, m["dialFails"])
        // Any other answer is left as it is.
        val open = """{"ms":420,"phase":"ok"}"""
        assertEquals(open, DoorChecks.inTheCallersWords(open, 3000L))
        assertNull(DoorChecks.inTheCallersWords(null, 3000L))
        assertEquals("panic", DoorChecks.inTheCallersWords("panic", 3000L))
    }

    @Test
    fun `waiting for a preparation that never started returns at once`() {
        val began = System.nanoTime()
        DoorChecks.awaitReady()
        assertTrue(System.nanoTime() - began < 1_000_000_000L)
    }
}
