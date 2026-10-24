package com.vpn.fortivavpn.service

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class KeeperTest {
    private val silent = Keeper.APP_SILENT_MS

    @Test
    fun `an app that asked within the window is there`() {
        assertFalse(Keeper.appSilent(now = 10_000_000L, lastAsk = 10_000_000L - silent + 1, silentMs = silent))
    }

    @Test
    fun `an app silent for the whole window is taken for gone`() {
        assertTrue(Keeper.appSilent(now = 10_000_000L, lastAsk = 10_000_000L - silent, silentMs = silent))
    }

    @Test
    fun `the window is longer than the app's five minute heartbeat`() {
        assertTrue(silent > 5 * 60_000L)
    }

    private val stuck = Keeper.STUCK_MS
    private val asked = 50_000_000L

    @Test
    fun `a job that never started is asked for again after the wait`() {
        assertTrue(Keeper.jobStuck(now = asked + stuck, scheduledAt = asked, keeperAskedAt = asked - 1, stuckMs = stuck))
        assertFalse(Keeper.jobStuck(now = asked + stuck - 1, scheduledAt = asked, keeperAskedAt = 0L, stuckMs = stuck))
    }

    @Test
    fun `a job whose run has started is left alone`() {
        assertFalse(Keeper.jobStuck(now = asked + 2 * stuck, scheduledAt = asked, keeperAskedAt = asked + 1, stuckMs = stuck))
    }

    @Test
    fun `a job this process did not ask for is left alone`() {
        assertFalse(Keeper.jobStuck(now = asked, scheduledAt = 0L, keeperAskedAt = 0L, stuckMs = stuck))
    }
}
