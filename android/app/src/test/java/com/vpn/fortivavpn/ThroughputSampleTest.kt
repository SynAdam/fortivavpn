package com.vpn.fortivavpn

import java.io.InputStream
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class ThroughputSampleTest {
    /** A clock in milliseconds that moves only when told. */
    private var clock = 1_000L

    /**
     * A body that arrives in [chunks] of bytes, each taking [msEach] to
     * arrive. A read gives what is left of the current chunk, up to the
     * buffer's size.
     */
    private fun body(chunks: List<Int>, msEach: Long): InputStream = object : InputStream() {
        private var i = 0
        private var left = 0
        override fun read(): Int = throw UnsupportedOperationException()
        override fun read(b: ByteArray, off: Int, len: Int): Int {
            if (left == 0) {
                if (i >= chunks.size) return -1
                clock += msEach
                left = chunks[i++]
            }
            val n = left.coerceAtMost(len)
            left -= n
            return n
        }
    }

    @Test
    fun theWaitForTheHeadersIsNotCountedAgainstTheBytes() {
        val sample = ThroughputSample.take(5_000, { clock }) {
            // Three seconds to connect through the tunnel and get the headers.
            clock += 3_000
            200 to body(listOf(16_384, 16_384, 16_384, 16_384), 100)
        }
        assertEquals(65_536L, sample!!["bytes"])
        assertEquals(400L, sample["ms"])
    }

    @Test
    fun theBytesStillGetOnlyTheCapAfterTheHeaders() {
        val sample = ThroughputSample.take(5_000, { clock }) {
            clock += 4_000
            200 to body(List(100) { 1_000 }, 1_000)
        }
        // Five reads of a second each, then the cap.
        assertEquals(5_000L, sample!!["bytes"])
        assertEquals(5_000L, sample["ms"])
    }

    @Test
    fun aBodyThatWasAlreadyInTakesOneMillisecond() {
        val sample = ThroughputSample.take(5_000, { clock }) {
            clock += 800
            200 to body(listOf(65_536), 0)
        }
        assertEquals(65_536L, sample!!["bytes"])
        assertEquals(1L, sample["ms"])
    }

    @Test
    fun anotherStatusSaysHowLongTheHeadersTook() {
        val sample = ThroughputSample.take(5_000, { clock }) {
            clock += 250
            403 to null
        }
        assertEquals(setOf("bytes", "ms", "status"), sample!!.keys)
        assertEquals(0L, sample["bytes"])
        assertEquals(250L, sample["ms"])
        assertEquals(403, sample["status"])
    }

    @Test
    fun aBodyWithNothingInItIsNoReading() {
        assertNull(ThroughputSample.take(5_000, { clock }) { 200 to body(emptyList(), 0) })
    }
}
