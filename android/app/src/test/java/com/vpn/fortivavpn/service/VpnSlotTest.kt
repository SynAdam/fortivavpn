package com.vpn.fortivavpn.service

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class VpnSlotTest {
    private val me = 10213
    private val unknown = VpnSlot.OWNER_UNKNOWN

    // Android 11 and later name a VPN's owner to that owner only; every
    // other app reads -1.
    private val hidden = -1

    @Test
    fun noVpnIsNotOurs() {
        assertFalse(VpnSlot.ownUp(activeIsVpn = false, owners = emptyList(), myUid = me))
    }

    @Test
    fun ourVpnIsOursOnceAndroidNamesItsOwner() {
        // The app leaves itself out of its own tunnel, so its default
        // network is not the VPN.
        assertTrue(VpnSlot.ownUp(activeIsVpn = false, owners = listOf(me), myUid = me))
    }

    @Test
    fun anotherAppsVpnIsNeverOurs() {
        // It carries this app's traffic too.
        assertFalse(VpnSlot.ownUp(activeIsVpn = true, owners = listOf(hidden), myUid = me))
        // It leaves this app out, or it runs in a work profile: only its
        // owner, which is not us, gives it away.
        assertFalse(VpnSlot.ownUp(activeIsVpn = false, owners = listOf(hidden), myUid = me))
    }

    @Test
    fun beforeAndroid11TheDefaultNetworkTellsThemApart() {
        // Ours: our own traffic does not go through it.
        assertTrue(VpnSlot.ownUp(activeIsVpn = false, owners = listOf(unknown), myUid = me))
        // Another app's, carrying us: up to 2.2.0 the app showed this as its
        // own tunnel, Connected.
        assertFalse(VpnSlot.ownUp(activeIsVpn = true, owners = listOf(unknown), myUid = me))
    }
}
