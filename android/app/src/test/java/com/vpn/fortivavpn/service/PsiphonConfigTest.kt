package com.vpn.fortivavpn.service

import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * The backup network's config: the backend's network keys, with the keys
 * this device owns set over anything the network config carries. Every
 * value here is made up.
 */
class PsiphonConfigTest {
    private val device = PsiphonConfig.Device(
        dataRoot = "/data/user/0/app/files/psiphon",
        socksPort = 40123,
        timeoutSeconds = 60,
        clientPlatform = "Android_14_com.example.app",
        clientVersion = "1234",
    )

    @Test
    fun theNetworkKeysPassThroughUnchanged() {
        val network = """
            {"PropagationChannelId":"0123456789ABCDEF","SponsorId":"FEDCBA9876543210",
             "RemoteServerListURLs":[{"URL":"aHR0cHM6Ly9leGFtcGxlLmludmFsaWQvbGlzdA==","OnlyAfterAttempts":0}],
             "LimitTunnelProtocols":["OSSH"],"EgressRegion":"DE"}
        """.trimIndent()

        val merged = JSONObject(PsiphonConfig.merge(network, device)!!)

        assertEquals("0123456789ABCDEF", merged.getString("PropagationChannelId"))
        assertEquals("FEDCBA9876543210", merged.getString("SponsorId"))
        assertEquals("DE", merged.getString("EgressRegion"))
        assertEquals("OSSH", merged.getJSONArray("LimitTunnelProtocols").getString(0))
        val url = merged.getJSONArray("RemoteServerListURLs").getJSONObject(0)
        assertEquals("aHR0cHM6Ly9leGFtcGxlLmludmFsaWQvbGlzdA==", url.getString("URL"))
        assertEquals(0, url.getInt("OnlyAfterAttempts"))
    }

    @Test
    fun theDeviceKeysAreSetOverWhatTheNetworkCarries() {
        val network = """
            {"PropagationChannelId":"0123456789ABCDEF","SponsorId":"0123456789ABCDEF",
             "DataRootDirectory":"/sdcard/elsewhere","LocalSocksProxyPort":1080,
             "DisableLocalHTTPProxy":false,"EstablishTunnelTimeoutSeconds":0,
             "ClientPlatform":"Windows","ClientVersion":"999","EmitDiagnosticNotices":true,
             "LimitCPUThreads":true}
        """.trimIndent()

        val merged = JSONObject(PsiphonConfig.merge(network, device)!!)

        assertEquals(device.dataRoot, merged.getString("DataRootDirectory"))
        assertEquals(40123, merged.getInt("LocalSocksProxyPort"))
        assertTrue(merged.getBoolean("DisableLocalHTTPProxy"))
        assertEquals(60, merged.getInt("EstablishTunnelTimeoutSeconds"))
        assertEquals("Android_14_com.example.app", merged.getString("ClientPlatform"))
        assertEquals("1234", merged.getString("ClientVersion"))
        assertFalse(merged.getBoolean("EmitDiagnosticNotices"))
        assertFalse(merged.getBoolean("LimitCPUThreads"))
    }

    @Test
    fun theDeviceKeysAreSetWhenTheNetworkHasNone() {
        val merged = JSONObject(PsiphonConfig.merge("{}", device)!!)

        assertEquals(device.dataRoot, merged.getString("DataRootDirectory"))
        assertEquals(40123, merged.getInt("LocalSocksProxyPort"))
        assertTrue(merged.getBoolean("DisableLocalHTTPProxy"))
        assertFalse(merged.getBoolean("EmitDiagnosticNotices"))
        assertFalse(merged.getBoolean("LimitCPUThreads"))
        assertEquals(8, merged.length())
    }

    @Test
    fun keysThatMoveOrExposeTheProxyAreRemoved() {
        val network = """
            {"SponsorId":"0123456789ABCDEF","LocalHttpProxyPort":8118,"ListenInterface":"any",
             "DisableLocalSocksProxy":true,"UseUnixDomainSockets":true,"PacketTunnelTunFileDescriptor":42}
        """.trimIndent()

        val merged = JSONObject(PsiphonConfig.merge(network, device)!!)

        for (key in PsiphonConfig.REMOVED_KEYS) assertFalse(key, merged.has(key))
        assertEquals("0123456789ABCDEF", merged.getString("SponsorId"))
    }

    @Test
    fun aConfigThatIsNotAnObjectIsRefused() {
        assertNull(PsiphonConfig.merge("", device))
        assertNull(PsiphonConfig.merge("[1,2]", device))
        assertNull(PsiphonConfig.merge("not json", device))
        assertNull(PsiphonConfig.merge("\"text\"", device))
    }

    @Test
    fun theClientPlatformHasTheLibrarysForm() {
        assertEquals("Android_14_com.vpn.fortivavpn", PsiphonConfig.clientPlatform("14", "com.vpn.fortivavpn"))
        assertEquals("Android_8.1.0_com.vpn.fortivavpn", PsiphonConfig.clientPlatform("8.1.0", "com.vpn.fortivavpn"))
        // Anything but letters, digits, "_", "-" and "." becomes "_".
        assertEquals("Android_15_Beta_2_com.example", PsiphonConfig.clientPlatform("15 Beta/2", "com.example"))
        assertEquals("Android__com.example", PsiphonConfig.clientPlatform(null, "com.example"))
    }

    @Test
    fun theLibrarysWaitIsWholeSecondsRoundedUp() {
        assertEquals(60, PsiphonConfig.timeoutSeconds(60_000L))
        assertEquals(61, PsiphonConfig.timeoutSeconds(60_001L))
        assertEquals(1, PsiphonConfig.timeoutSeconds(1L))
        assertEquals(1, PsiphonConfig.timeoutSeconds(0L))
    }
}
