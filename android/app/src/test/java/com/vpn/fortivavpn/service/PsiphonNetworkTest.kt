package com.vpn.fortivavpn.service

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.net.InetAddress

class PsiphonNetworkTest {
    private fun ip(literal: String): InetAddress = InetAddress.getByName(literal)

    @Test
    fun theNetworkIdIsOneWordWithNothingAfterIt() {
        assertEquals("WIFI", PsiphonNetwork.idWord(wifi = true, cellular = false, ethernet = false))
        assertEquals("MOBILE", PsiphonNetwork.idWord(wifi = false, cellular = true, ethernet = false))
        assertEquals("WIRED", PsiphonNetwork.idWord(wifi = false, cellular = false, ethernet = true))
        assertEquals("UNKNOWN", PsiphonNetwork.idWord(wifi = false, cellular = false, ethernet = false))
        // A network that says several is read as Wi-Fi, as LinkFacts does.
        assertEquals("WIFI", PsiphonNetwork.idWord(wifi = true, cellular = true, ethernet = true))
        for (word in listOf("WIFI", "MOBILE", "WIRED", "UNKNOWN")) assertFalse(word.contains('-'))
    }

    @Test
    fun theResolversAreCommaSeparatedAndEachOnce() {
        val servers = listOf(ip("192.0.2.53"), ip("2001:db8::53"), ip("192.0.2.53"))
        assertEquals("192.0.2.53,2001:db8:0:0:0:0:0:53", PsiphonNetwork.dnsServers(servers, "wlan0"))
    }

    @Test
    fun unusableResolversAreLeftOut() {
        val servers = listOf(ip("0.0.0.0"), ip("224.0.0.251"), ip("169.254.1.1"), ip("192.0.2.1"))
        assertEquals("192.0.2.1", PsiphonNetwork.dnsServers(servers, "wlan0"))
    }

    @Test
    fun anIpv6LinkLocalResolverNamesItsInterface() {
        assertEquals("fe80:0:0:0:0:0:0:1%wlan0", PsiphonNetwork.dnsServers(listOf(ip("fe80::1")), "wlan0"))
        // With no interface to name, it cannot be reached and is left out.
        assertEquals("", PsiphonNetwork.dnsServers(listOf(ip("fe80::1")), null))
    }

    @Test
    fun noResolverIsAnEmptyString() {
        assertEquals("", PsiphonNetwork.dnsServers(emptyList(), "rmnet0"))
    }

    @Test
    fun onlyGlobalIpv6Counts() {
        assertTrue(PsiphonNetwork.isGlobalIpv6(ip("2001:db8::1")))
        assertTrue(PsiphonNetwork.isGlobalIpv6(ip("2001:db8:f20::1")))
        assertFalse(PsiphonNetwork.isGlobalIpv6(ip("fe80::1")))
        assertFalse(PsiphonNetwork.isGlobalIpv6(ip("fd00::1")))
        assertFalse(PsiphonNetwork.isGlobalIpv6(ip("::1")))
        assertFalse(PsiphonNetwork.isGlobalIpv6(ip("192.0.2.1")))
    }

    @Test
    fun theFirstNetworkHeardOfIsNoMove() {
        assertFalse(PsiphonNetwork.moved(null, "wifi"))
        assertFalse(PsiphonNetwork.moved("wifi", "wifi"))
        assertTrue(PsiphonNetwork.moved("wifi", "mobile"))
    }
}
