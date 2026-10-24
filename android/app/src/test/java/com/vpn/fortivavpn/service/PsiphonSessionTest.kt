package com.vpn.fortivavpn.service

import com.vpn.fortivavpn.dto.EConfigType
import com.vpn.fortivavpn.dto.ProfileItem
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import java.io.File

class PsiphonSessionTest {
    private val config = """{"PropagationChannelId":"0123456789ABCDEF","SponsorId":"0123456789ABCDEF"}"""

    @get:Rule
    val folder = TemporaryFolder()

    @Test
    fun aSessionReadsBackAsItWasWritten() {
        val session = PsiphonSession("guid-1", 40123, config, 45_000L)
        assertEquals(session, PsiphonSession.fromJson(session.toJson()))
    }

    @Test
    fun theServerListPathIsKeptWithTheSession() {
        val path = File(folder.root, "psiphon/server_entries").absolutePath
        val session = PsiphonSession("guid-1", 40123, config, 45_000L, path)
        val read = PsiphonSession.fromJson(session.toJson())!!
        assertEquals(path, read.entriesFile)
        assertEquals(session, read)
        // A moved port keeps it.
        assertEquals(path, read.copy(port = 40124).entriesFile)
    }

    @Test
    fun aSessionWithoutAServerListHasAnEmptyPath() {
        assertEquals("", PsiphonSession("g", 40123, config, 1L).entriesFile)
        // As a build before the list wrote it, with no such field.
        val older = """{"guid":"g","port":40123,"config":${org.json.JSONObject.quote(config)},"timeout_ms":60000}"""
        assertEquals("", PsiphonSession.fromJson(older)!!.entriesFile)
    }

    @Test
    fun onlyAnAbsolutePathIsKeptAsTheServerList() {
        assertEquals("/data/user/0/app/files/psiphon/server_entries", PsiphonSession.entriesFileOf("/data/user/0/app/files/psiphon/server_entries"))
        assertEquals("", PsiphonSession.entriesFileOf(null))
        assertEquals("", PsiphonSession.entriesFileOf(""))
        assertEquals("", PsiphonSession.entriesFileOf("   "))
        assertEquals("", PsiphonSession.entriesFileOf("psiphon/server_entries"))
        // A stored session goes through the same check.
        val stored = PsiphonSession("g", 40123, config, 1L, "server_entries").toJson()
        assertEquals("", PsiphonSession.fromJson(stored)!!.entriesFile)
    }

    @Test
    fun theLibraryGetsTheServerListOnlyWhenItCanBeRead() {
        val list = folder.newFile("server_entries").apply { writeText("0123abcd\n") }
        assertEquals(list.absolutePath, PsiphonSession.embeddedList(list.absolutePath))

        // None sent, or one deleted since the session was written.
        assertEquals("", PsiphonSession.embeddedList(""))
        assertEquals("", PsiphonSession.embeddedList(File(folder.root, "gone").absolutePath))
        // A folder is not a list.
        assertEquals("", PsiphonSession.embeddedList(folder.newFolder("psiphon").absolutePath))
        // Nor is a relative path, even to a file that is there.
        assertEquals("", PsiphonSession.embeddedList("server_entries"))
    }

    @Test
    fun anUnreadableServerListIsLeftOut() {
        val list = folder.newFile("locked").apply { writeText("0123abcd\n") }
        // A process that may read anything (root) cannot test this.
        org.junit.Assume.assumeTrue(list.setReadable(false, false) && !list.canRead())
        assertEquals("", PsiphonSession.embeddedList(list.absolutePath))
        list.setReadable(true, false)
    }

    @Test
    fun withoutAServerListTheWaitsAreAsBefore() {
        assertEquals(PsiphonSession.START_WAIT_MS, PsiphonSession.startWaitMs(false, 60_000L))
        assertEquals(PsiphonSession.START_WAIT_MS, PsiphonSession.startWaitMs(false, 5_000L))
        // The start's time does not come off the wait for a tunnel.
        assertEquals(60_000L, PsiphonSession.tunnelWaitMs(false, 60_000L, 0L))
        assertEquals(60_000L, PsiphonSession.tunnelWaitMs(false, 60_000L, 19_000L))
    }

    @Test
    fun withAServerListTheStartMayTakeTheSessionsWholeWait() {
        // Reading the list into an empty store can take longer than a plain start.
        assertEquals(60_000L, PsiphonSession.startWaitMs(true, 60_000L))
        assertEquals(600_000L, PsiphonSession.startWaitMs(true, 600_000L))
        // Never less than a start without one gets.
        assertEquals(PsiphonSession.START_WAIT_MS, PsiphonSession.startWaitMs(true, 5_000L))
    }

    @Test
    fun withAServerListTheStartsTimeComesOffTheWaitForATunnel() {
        // A start that returned at once, as every start after the first does.
        assertEquals(59_800L, PsiphonSession.tunnelWaitMs(true, 60_000L, 200L))
        // A first start that read the list for 25 seconds.
        assertEquals(35_000L, PsiphonSession.tunnelWaitMs(true, 60_000L, 25_000L))
        // So start and tunnel together never take longer than the session's wait.
        for (startMs in listOf(0L, 1L, 30_000L, 59_999L, 60_000L, 90_000L)) {
            val wait = PsiphonSession.tunnelWaitMs(true, 60_000L, startMs)
            assertTrue(wait >= 0L)
            assertTrue(minOf(startMs, 60_000L) + wait <= 60_000L)
        }
        assertEquals(0L, PsiphonSession.tunnelWaitMs(true, 60_000L, 90_000L))
        // A clock reading that went backwards takes nothing off.
        assertEquals(60_000L, PsiphonSession.tunnelWaitMs(true, 60_000L, -5L))
    }

    @Test
    fun anythingElseIsNoSession() {
        assertNull(PsiphonSession.fromJson(null))
        assertNull(PsiphonSession.fromJson(""))
        assertNull(PsiphonSession.fromJson("not json"))
        assertNull(PsiphonSession.fromJson(PsiphonSession("", 40123, config, 1L).toJson()))
        assertNull(PsiphonSession.fromJson(PsiphonSession("g", 0, config, 1L).toJson()))
        assertNull(PsiphonSession.fromJson(PsiphonSession("g", 70000, config, 1L).toJson()))
        assertNull(PsiphonSession.fromJson(PsiphonSession("g", 40123, "[1]", 1L).toJson()))
    }

    @Test
    fun theWaitHasADefaultAndBounds() {
        assertEquals(60_000L, PsiphonSession.timeoutOf(null))
        assertEquals(60_000L, PsiphonSession.timeoutOf(0L))
        assertEquals(60_000L, PsiphonSession.timeoutOf(-5L))
        assertEquals(5_000L, PsiphonSession.timeoutOf(1L))
        assertEquals(90_000L, PsiphonSession.timeoutOf(90_000L))
        assertEquals(600_000L, PsiphonSession.timeoutOf(3_600_000L))
        // A stored wait goes through the same bounds.
        val stored = PsiphonSession("g", 40123, config, 1L).toJson()
        assertEquals(5_000L, PsiphonSession.fromJson(stored)!!.timeoutMs)
    }

    @Test
    fun aConfigMustBeAJsonObject() {
        assertTrue(PsiphonSession.isConfig(config))
        assertTrue(PsiphonSession.isConfig("{}"))
        assertFalse(PsiphonSession.isConfig(null))
        assertFalse(PsiphonSession.isConfig(""))
        assertFalse(PsiphonSession.isConfig("[]"))
        assertFalse(PsiphonSession.isConfig("{"))
    }

    @Test
    fun theProfileIsASocksProxyOnLoopback() {
        val profile = PsiphonSession.profile(40123)
        assertEquals(EConfigType.SOCKS, profile.configType)
        assertEquals("127.0.0.1", profile.server)
        assertEquals("40123", profile.serverPort)
        assertNull(profile.username)
        // The app never shows the library's name.
        assertFalse(profile.remarks.contains("psiphon", ignoreCase = true))
    }

    @Test
    fun onlyTheBackupProfileHasTheBackupShape() {
        assertTrue(PsiphonSession.isBackupProfile(PsiphonSession.profile(40123)))
        assertFalse(PsiphonSession.isBackupProfile(null))
        // A door, even one through a local proxy, is not the backup network.
        val door = ProfileItem.create(EConfigType.VLESS).apply {
            remarks = PsiphonSession.REMARKS
            server = "127.0.0.1"
            serverPort = "40123"
        }
        assertFalse(PsiphonSession.isBackupProfile(door))
        val otherSocks = PsiphonSession.profile(40123).apply { remarks = "door" }
        assertFalse(PsiphonSession.isBackupProfile(otherSocks))
        val remoteSocks = PsiphonSession.profile(40123).apply { server = "192.0.2.10" }
        assertFalse(PsiphonSession.isBackupProfile(remoteSocks))
    }

    @Test
    fun forgettingRemovesTheSessionsProfileAndASelectedOrphan() {
        // The stored session's profile, selected or not.
        assertEquals(listOf("g1"), PsiphonSession.forgetTargets("g1", "g1", true))
        assertEquals(listOf("g1"), PsiphonSession.forgetTargets("g1", "door", false))
        // A selected backup profile whose session is gone.
        assertEquals(listOf("g2"), PsiphonSession.forgetTargets(null, "g2", true))
        assertEquals(listOf("g1", "g2"), PsiphonSession.forgetTargets("g1", "g2", true))
        // A selected door stays, and so does nothing at all.
        assertEquals(emptyList<String>(), PsiphonSession.forgetTargets(null, "door", false))
        assertEquals(emptyList<String>(), PsiphonSession.forgetTargets(null, null, false))
        assertEquals(emptyList<String>(), PsiphonSession.forgetTargets("", "", true))
    }
}
