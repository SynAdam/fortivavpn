package com.vpn.fortivavpn

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * When the VPN consent dialog is shown once more after it closed itself
 * (ConsentAgain). Asked once more only for a dialog the user never saw,
 * only once for each request, and never while another app's always-on VPN
 * makes the system close it on sight.
 */
class ConsentAgainTest {
    private val silent = 800L

    private fun ask(
        elapsedMs: Long = 120,
        shownAgain: Boolean = false,
        owner: String? = null,
        hasStart: Boolean = true,
    ) = ConsentAgain.shouldAsk(elapsedMs, silent, shownAgain, owner, hasStart)

    @Test
    fun aDialogThatClosedItselfIsShownOnceMore() {
        assertTrue(ask())
        assertTrue(ask(elapsedMs = 0))
        assertTrue(ask(elapsedMs = silent - 1))
    }

    @Test
    fun aSecondDialogThatClosesItselfEndsTheRequest() {
        assertFalse(ask(shownAgain = true))
    }

    @Test
    fun aRefusalTheUserMadeIsNotAskedAgain() {
        // Open for 800 ms or more: the user saw it and said no.
        assertFalse(ask(elapsedMs = silent))
        assertFalse(ask(elapsedMs = 5_000))
    }

    @Test
    fun notWhileAnotherAppHoldsAlwaysOn() {
        assertFalse(ask(owner = "Other VPN"))
    }

    @Test
    fun notWhenTheRequestLostWhatItWouldStart() {
        assertFalse(ask(hasStart = false))
    }

    @Test
    fun aTimeBelowZeroIsNoSilentClose() {
        // The same range MainActivity used before: 0 until 800 ms.
        assertFalse(ask(elapsedMs = -1))
    }
}
