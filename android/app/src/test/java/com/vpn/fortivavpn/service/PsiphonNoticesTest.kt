package com.vpn.fortivavpn.service

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * The library's notices, in the compact form it writes them
 * (psiphon/notice.go): keys in alphabetical order, no spaces.
 */
class PsiphonNoticesTest {
    private fun notice(type: String, data: String = "{}") =
        """{"data":$data,"noticeType":"$type","timestamp":"2026-10-16T12:00:00.000Z"}"""

    @Test
    fun theTypeIsFoundWithoutAParse() {
        assertEquals("Tunnels", PsiphonNotices.typeOf(notice("Tunnels", """{"count":1}""")))
        assertEquals("Info", PsiphonNotices.typeOf(notice("Info", """{"message":"noticeType"}""")))
    }

    @Test
    fun aNoticeWithSpacesStillReads() {
        val raw = """{ "noticeType" : "Tunnels", "data" : { "count" : 2 } }"""
        assertEquals("Tunnels", PsiphonNotices.typeOf(raw))
        assertEquals(PsiphonNotice.Tunnels(2), PsiphonNotices.parse(raw))
    }

    @Test
    fun theNoticesActedOnAreRead() {
        assertEquals(PsiphonNotice.Tunnels(0), PsiphonNotices.parse(notice("Tunnels", """{"count":0}""")))
        assertEquals(PsiphonNotice.Tunnels(1), PsiphonNotices.parse(notice("Tunnels", """{"count":1}""")))
        assertEquals(
            PsiphonNotice.ListeningSocksPort(40123),
            PsiphonNotices.parse(notice("ListeningSocksProxyPort", """{"port":40123}""")),
        )
        assertEquals(PsiphonNotice.SocksPortInUse, PsiphonNotices.parse(notice("SocksProxyPortInUse", """{"port":40123}""")))
        assertEquals(PsiphonNotice.EstablishTimeout, PsiphonNotices.parse(notice("EstablishTunnelTimeout", """{"timeout":"1m0s"}""")))
        assertEquals(PsiphonNotice.Exiting, PsiphonNotices.parse(notice("Exiting")))
        assertEquals(
            PsiphonNotice.ServerRegion("DE"),
            PsiphonNotices.parse(notice("ConnectedServerRegion", """{"serverRegion":"DE"}""")),
        )
    }

    @Test
    fun aRegionIsTwoCapitalLetters() {
        for (bad in listOf("", "de", "DEU", "D1", "  ")) {
            assertNull(bad, PsiphonNotices.parse(notice("ConnectedServerRegion", """{"serverRegion":"$bad"}""")))
        }
    }

    @Test
    fun brokenNoticesAreDropped() {
        assertNull(PsiphonNotices.parse(""))
        assertNull(PsiphonNotices.parse("not json"))
        assertNull(PsiphonNotices.parse(notice("Tunnels")))
        assertNull(PsiphonNotices.parse(notice("Tunnels", """{"count":-1}""")))
        assertNull(PsiphonNotices.parse(notice("ListeningSocksProxyPort", """{"port":0}""")))
        assertNull(PsiphonNotices.parse(notice("ListeningSocksProxyPort", """{"port":70000}""")))
    }

    @Test
    fun aNewerClientVersionIsRead() {
        assertEquals(
            PsiphonNotice.UpgradeAvailable("412"),
            PsiphonNotices.parse(notice("ClientUpgradeAvailable", """{"version":"412"}""")),
        )
        // The library's own compact form, with the other notices around it.
        val raw = """{"data":{"version":"7"},"noticeType":"ClientUpgradeAvailable","showUser":false,"timestamp":"2026-10-16T12:00:00.000Z"}"""
        assertEquals(PsiphonNotice.UpgradeAvailable("7"), PsiphonNotices.parse(raw))
    }

    @Test
    fun aVersionIsAWholeNumber() {
        for (bad in listOf("", " ", "1.2", "v12", "-3", "198.51.100.4", "1234567890123")) {
            assertNull(bad, PsiphonNotices.parse(notice("ClientUpgradeAvailable", """{"version":"$bad"}""")))
        }
        assertNull(PsiphonNotices.parse(notice("ClientUpgradeAvailable")))
        assertNull(PsiphonNotices.parse(notice("ClientUpgradeAvailable", """{"version":412}""")))
        // The notice that says the client is the newest is not acted on.
        assertNull(PsiphonNotices.parse(notice("ClientIsLatestVersion", """{"availableVersion":"412"}""")))
    }

    @Test
    fun aNoticeAboutServerEntriesIsLoggedByItsTypeAlone() {
        val raw = notice(
            "Error",
            """{"message":"error importing embedded server entry list: encoding/hex: invalid byte: U+0067 'g'"}""",
        )
        assertEquals("[psiphon] Error", PsiphonNotices.debugLine(raw))
        val upper = notice("Info", """{"message":"Server Entries imported"}""")
        assertEquals("[psiphon] Info", PsiphonNotices.debugLine(upper))
    }

    @Test
    fun theUsersAddressAndRegionAreNeitherReadNorLogged() {
        val address = notice("ClientAddress", """{"address":"203.0.113.7:51234"}""")
        val region = notice("ClientRegion", """{"region":"IR"}""")

        assertNull(PsiphonNotices.parse(address))
        assertNull(PsiphonNotices.parse(region))
        assertNull(PsiphonNotices.debugLine(address))
        assertNull(PsiphonNotices.debugLine(region))
    }

    @Test
    fun aNoticeThatNamesAnAddressIsLoggedByItsTypeAlone() {
        val raw = notice("Info", """{"message":"dial 198.51.100.4:443 failed"}""")
        assertEquals("[psiphon] Info", PsiphonNotices.debugLine(raw))

        val named = notice("Info", """{"message":"fetching from example.invalid"}""")
        assertEquals("[psiphon] Info", PsiphonNotices.debugLine(named))
    }

    @Test
    fun aPlainNoticeIsLoggedWhole() {
        val raw = notice("Tunnels", """{"count":1}""")
        assertEquals("[psiphon] $raw", PsiphonNotices.debugLine(raw))
    }

    @Test
    fun theWaitEndsInOrder() {
        // A stop or a newer start wins over everything.
        assertEquals(
            PsiphonWait.Cancelled,
            PsiphonNotices.waitStep(true, PsiphonFailure.EXITING, 1, 100, 50),
        )
        // Then a failure the library reported.
        assertEquals(
            PsiphonWait.Failed(PsiphonFailure.PORT_IN_USE),
            PsiphonNotices.waitStep(false, PsiphonFailure.PORT_IN_USE, 1, 100, 50),
        )
        // Then a tunnel, even at the deadline.
        assertEquals(PsiphonWait.Connected, PsiphonNotices.waitStep(false, null, 1, 100, 100))
        assertEquals(PsiphonWait.Connected, PsiphonNotices.waitStep(false, null, 3, 0, 100))
        // Then the deadline.
        assertEquals(PsiphonWait.TimedOut, PsiphonNotices.waitStep(false, null, 0, 100, 100))
        // Otherwise it waits on.
        assertNull(PsiphonNotices.waitStep(false, null, 0, 99, 100))
    }

    @Test
    fun everyFailureHasAWord() {
        val words = PsiphonFailure.entries.map { it.word }
        assertEquals(words.size, words.toSet().size)
        assertTrue(words.all { Regex("^[a-z_]+$").matches(it) })
    }
}
