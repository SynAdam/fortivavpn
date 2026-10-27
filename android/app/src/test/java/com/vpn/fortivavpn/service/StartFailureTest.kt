package com.vpn.fortivavpn.service

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * The words a failed start sends (StartFailure). The app files them in the
 * connect_failed row, and keeps only short lower-case words
 * (nativeStartFailure in lib/services/vpn_service.dart), so a word outside
 * that shape would be dropped on the way and the cause lost again.
 */
class StartFailureTest {
    private val word = Regex("^[a-z][a-z0-9_]{0,31}$")

    @Test
    fun theMessageIsTheStepAndTheReason() {
        assertEquals(
            "core:port_in_use",
            StartFailure.message(StartFailure.STEP_CORE, StartFailure.PORT_IN_USE),
        )
        assertEquals(
            "psiphon:establish_timeout",
            StartFailure.message(StartFailure.STEP_PSIPHON, PsiphonFailure.ESTABLISH_TIMEOUT.word),
        )
    }

    @Test
    fun aCoreErrorIsOneWordByLibv2raysPrefix() {
        // libv2ray_main.go wraps every start error in one of three prefixes.
        assertEquals(StartFailure.CONFIG_ERROR, StartFailure.coreError("config error: unknown field"))
        assertEquals(StartFailure.INIT_FAILED, StartFailure.coreError("core init failed: bad outbound"))
        assertEquals(StartFailure.STARTUP_FAILED, StartFailure.coreError("startup failed: something else"))
        assertEquals(StartFailure.START_ERROR, StartFailure.coreError("go panic in a goroutine"))
        assertEquals(StartFailure.START_ERROR, StartFailure.coreError(null))
    }

    @Test
    fun aPortAnotherAppHoldsIsToldApart() {
        // Fails every start on the phone until that app lets go of the port.
        assertEquals(
            StartFailure.PORT_IN_USE,
            StartFailure.coreError("startup failed: failed to listen TCP: bind: address already in use"),
        )
    }

    @Test
    fun theErrorTextIsNeverSent() {
        // An error can hold an address; only the fixed word leaves the phone.
        val reason = StartFailure.coreError("startup failed: dial tcp 192.0.2.10:443: refused")
        assertEquals(StartFailure.STARTUP_FAILED, reason)
        assertTrue(word.matches(reason))
    }

    @Test
    fun everyWordHasTheShapeTheAppKeeps() {
        val words = listOf(
            StartFailure.STEP_CONSENT,
            StartFailure.STEP_SESSION,
            StartFailure.STEP_CORE,
            StartFailure.STEP_PSIPHON,
            StartFailure.STEP_INTERFACE,
            StartFailure.STEP_TUN2SOCKS,
            StartFailure.STEP_FINISH,
            StartFailure.NOT_PREPARED,
            StartFailure.ORPHAN_PROFILE,
            StartFailure.SESSION_ERROR,
            StartFailure.ALREADY_RUNNING,
            StartFailure.NO_SERVICE,
            StartFailure.NO_SERVER,
            StartFailure.BAD_PROFILE,
            StartFailure.BUILD_FAILED,
            StartFailure.RECEIVER,
            StartFailure.CONFIG_ERROR,
            StartFailure.INIT_FAILED,
            StartFailure.STARTUP_FAILED,
            StartFailure.PORT_IN_USE,
            StartFailure.NOT_RUNNING,
            StartFailure.START_ERROR,
            StartFailure.POST_START,
            StartFailure.ESTABLISH_ERROR,
            StartFailure.PROCESS_ERROR,
            StartFailure.FD_NOT_SENT,
        ) + PsiphonFailure.entries.map { it.word }
        for (w in words) assertTrue("'$w' would be dropped by the app", word.matches(w))
        // The one word the app ends its search on must stay a word of its own.
        assertTrue(VpnSlot.SLOT_TAKEN !in words)
    }
}
