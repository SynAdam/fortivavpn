package com.vpn.fortivavpn.handler

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/**
 * The backend's penalty for each door reaches the core's door group under
 * the door's tag (android/core/patches/xray-stability-penalty.patch).
 */
class AutoSelectPenaltiesTest {
    @Test
    fun eachDoorTakesThePenaltyAtItsPosition() {
        // The third door did not import, so the group holds no proxy@2 and
        // its penalty goes nowhere. The others keep their positions.
        val tags = listOf("proxy@0", "proxy@1", "proxy@3")
        assertEquals(
            mapOf("proxy@1" to 1500, "proxy@3" to 900),
            V2rayConfigManager.autoSelectPenalties(tags, listOf(0, 1500, 700, 900)),
        )
    }

    @Test
    fun withNoPenaltyTheSettingIsLeftOut() {
        val tags = listOf("proxy@0", "proxy@1")
        assertNull(V2rayConfigManager.autoSelectPenalties(tags, emptyList()))
        assertNull(V2rayConfigManager.autoSelectPenalties(tags, listOf(0, 0)))
    }

    @Test
    fun aPenaltyBelowOneIsNone() {
        val tags = listOf("proxy@0", "proxy@1")
        assertEquals(
            mapOf("proxy@1" to 1),
            V2rayConfigManager.autoSelectPenalties(tags, listOf(-200, 1)),
        )
    }
}
