package com.vpn.fortivavpn.util

import android.os.Build
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.concurrent.TimeUnit

/**
 * Process.running() on the path Android 7 takes (#444). Build.VERSION.SDK_INT
 * is 0 in a local unit test, so these run the exitValue() fallback, not
 * Process.isAlive().
 */
class ProcessCompatTest {
    @Test
    fun theseTestsTakeTheAndroid7Path() {
        assertTrue(Build.VERSION.SDK_INT < Build.VERSION_CODES.O)
    }

    @Test
    fun aProcessThatHasNotExitedIsRunning() {
        val process = ProcessBuilder("sleep", "30").start()
        try {
            assertTrue(process.running())
        } finally {
            process.destroy()
            process.waitFor(5, TimeUnit.SECONDS)
        }
    }

    @Test
    fun aProcessThatExitedIsNotRunning() {
        val process = ProcessBuilder("true").start()
        assertTrue(process.waitFor(5, TimeUnit.SECONDS))
        assertFalse(process.running())
    }

    @Test
    fun aDestroyedProcessIsNotRunning() {
        val process = ProcessBuilder("sleep", "30").start()
        process.destroy()
        assertTrue(process.waitFor(5, TimeUnit.SECONDS))
        assertFalse(process.running())
    }
}
