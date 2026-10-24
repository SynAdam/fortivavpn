package com.vpn.fortivavpn.handler

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class SiteStatsTest {
    // Lines as `logcat -v time` prints the core's log. The message text is
    // what 1.6.13's core logged on the test emulator on 2026-10-07.
    private fun log(session: Long, message: String) =
        "10-07 09:16:12.345 I/GoLog   ( 4242): [Info] [$session] app/dispatcher: $message"

    private fun sniffed(session: Long, host: String) = log(session, "sniffed domain: $host")

    private fun detour(session: Long, tag: String, host: String) =
        log(session, "taking detour [$tag] for [tcp:$host:443]")

    private fun defaultRoute(session: Long, host: String) = log(session, "default route for tcp:$host:443")

    private fun tally(vararg lines: String, carried: Map<String, String> = emptyMap()) =
        SiteStats.tally(lines.asSequence(), carried)

    @Test
    fun sitesThatGoDirectAreNotCounted() {
        val found = tally(
            sniffed(1406141838, "divar.ir"),
            detour(1406141838, "direct", "divar.ir"),
            sniffed(2866404467, "eitaa.com"),
            detour(2866404467, "direct", "eitaa.com"),
            sniffed(850761132, "en.wikipedia.org"),
            defaultRoute(850761132, "en.wikipedia.org"),
        )
        assertEquals(mapOf("en.wikipedia.org" to 1), found.counts)
        assertTrue(found.waiting.isEmpty())
    }

    @Test
    fun aDetourToAProxyIsTheTunnelAndABlockIsNot() {
        val found = tally(
            sniffed(1, "youtube.com"),
            detour(1, "proxy", "youtube.com"),
            sniffed(2, "youtube.com"),
            detour(2, "proxy@1", "youtube.com"),
            sniffed(3, "quic.example.com"),
            detour(3, "block", "quic.example.com"),
        )
        assertEquals(mapOf("youtube.com" to 2), found.counts)
    }

    @Test
    fun eachRouteBelongsToItsOwnConnection() {
        val found = tally(
            sniffed(10, "divar.ir"),
            sniffed(11, "instagram.com"),
            defaultRoute(11, "instagram.com"),
            detour(10, "direct", "divar.ir"),
        )
        assertEquals(mapOf("instagram.com" to 1), found.counts)
    }

    @Test
    fun aRouteLoggedAfterTheDrainCountsInTheNextOne() {
        val first = tally(sniffed(20, "WWW.Instagram.COM."))
        assertTrue(first.counts.isEmpty())
        assertEquals(mapOf("20" to "www.instagram.com"), first.waiting)

        val second = tally(defaultRoute(20, "www.instagram.com"), carried = first.waiting)
        assertEquals(mapOf("www.instagram.com" to 1), second.counts)
        assertTrue(second.waiting.isEmpty())
    }

    @Test
    fun aConnectionWithNoRouteAfterAWholeDrainIsDropped() {
        val first = tally(sniffed(30, "divar.ir"))
        val second = tally(sniffed(31, "github.com"), carried = first.waiting)
        assertTrue(second.counts.isEmpty())
        assertEquals(mapOf("31" to "github.com"), second.waiting)
    }

    @Test
    fun aRouteWithNoSniffedLineCountsNothing() {
        val found = tally(defaultRoute(40, "1.2.3.4"), detour(41, "direct", "5.106.8.151"))
        assertTrue(found.counts.isEmpty())
    }
}
