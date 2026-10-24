package com.vpn.fortivavpn.handler

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class LinkFactsTest {
    @Test
    fun theTransportIsNamedInOrder() {
        assertEquals("wifi", LinkFacts.transport(wifi = true, cellular = false, ethernet = false))
        assertEquals("cellular", LinkFacts.transport(wifi = false, cellular = true, ethernet = false))
        assertEquals("ethernet", LinkFacts.transport(wifi = false, cellular = false, ethernet = true))
        assertEquals("other", LinkFacts.transport(wifi = false, cellular = false, ethernet = false))
        // A network that says both is read as wifi, as networkFacts does.
        assertEquals("wifi", LinkFacts.transport(wifi = true, cellular = true, ethernet = false))
    }

    @Test
    fun anMtuOfZeroIsNoMtu() {
        assertNull(LinkFacts.mtu(0))
        assertNull(LinkFacts.mtu(-1))
        assertEquals(1500, LinkFacts.mtu(1500))
        assertEquals(1280, LinkFacts.mtu(1280))
    }

    @Test
    fun thePrivateDnsModeFollowsTheLink() {
        assertEquals("strict", LinkFacts.privateDnsMode(true, "dns.example.org"))
        // A named provider that is not answering is still strict mode.
        assertEquals("strict", LinkFacts.privateDnsMode(false, "dns.example.org"))
        assertEquals("opportunistic", LinkFacts.privateDnsMode(true, null))
        assertEquals("opportunistic", LinkFacts.privateDnsMode(true, " "))
        assertEquals("off", LinkFacts.privateDnsMode(false, null))
    }
}
