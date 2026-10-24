package com.vpn.fortivavpn.handler

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class NetworkKeyTest {
    private val salt = ByteArray(32) { it.toByte() }
    private val otherSalt = ByteArray(32) { (it + 1).toByte() }
    private val home = NetworkKey.canonical(
        dns = listOf("192.168.1.1"),
        gateways = listOf("192.168.1.1", "fe80::1a2b:3cff:fe4d:5e6f"),
        dhcp = "192.168.1.1",
        mtu = 1500,
        domains = "lan",
        security = 2,
    )!!

    @Test
    fun `the order Android lists things in does not change the key`() {
        val a = NetworkKey.canonical(listOf("8.8.8.8", "1.1.1.1"), listOf("10.0.0.1"), null, 0, null, null)
        val b = NetworkKey.canonical(listOf("1.1.1.1", "8.8.8.8"), listOf("10.0.0.1"), null, 0, null, null)
        assertEquals(a, b)
    }

    @Test
    fun `a network with no gateway and no DNS server has no key`() {
        assertNull(NetworkKey.canonical(emptyList(), emptyList(), "10.0.0.1", 1500, "lan", 2))
    }

    @Test
    fun `two routers that differ only in their IPv6 link-local address get two keys`() {
        val other = NetworkKey.canonical(
            listOf("192.168.1.1"),
            listOf("192.168.1.1", "fe80::aa:bbff:fecc:ddee"),
            "192.168.1.1",
            1500,
            "lan",
            2,
        )!!
        assertNotEquals(
            NetworkKey.keysFor(home, salt, 0, 0).local,
            NetworkKey.keysFor(other, salt, 0, 0).local,
        )
    }

    @Test
    fun `the same network gives another key on another install`() {
        assertNotEquals(
            NetworkKey.keysFor(home, salt, 0, 0).local,
            NetworkKey.keysFor(home, otherSalt, 0, 0).local,
        )
    }

    @Test
    fun `a key is 64 bits of hex and holds nothing of what it was made from`() {
        val keys = NetworkKey.keysFor(home, salt, 7 * 86_400L, 1_791_525_600L)
        for (key in listOf(keys.local, keys.shared!!)) {
            assertEquals(16, key.length)
            assertTrue(key.all { it in "0123456789abcdef" })
            assertFalse(home.contains(key))
        }
        assertNotEquals(keys.local, keys.shared)
    }

    @Test
    fun `no period sends no shared key, and the local key never changes`() {
        val a = NetworkKey.keysFor(home, salt, 0, 1_000L)
        val b = NetworkKey.keysFor(home, salt, 0, 9_000_000L)
        assertNull(a.shared)
        assertEquals(a.local, b.local)
    }

    @Test
    fun `the shared key holds for one period and then changes`() {
        val week = 7 * 86_400L
        val start = 1_791_525_600L
        val seen = (0 until 21).map { day -> NetworkKey.keysFor(home, salt, week, start + day * 86_400L).shared!! }
        // Three weeks of days: three keys, each for seven days in a row
        // (cut at this install's own offset, so the first and last runs can
        // be shorter).
        val runs = seen.zipWithNext().count { (a, b) -> a != b } + 1
        assertTrue(runs in 3..4)
        assertEquals(3, seen.toSet().size.coerceAtMost(3))
    }

    @Test
    fun `the hmac is the standard one`() {
        // RFC 4231 test case 2.
        assertEquals(
            "5bdcc146bf60754e6a042426089575c75a003f089d2739839dec58b964ec3843",
            NetworkKey.hmac("Jefe".toByteArray(), "what do ya want for nothing?"),
        )
    }
}
