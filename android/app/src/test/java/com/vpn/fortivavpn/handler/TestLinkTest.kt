package com.vpn.fortivavpn.handler

import com.google.gson.JsonParser
import com.vpn.fortivavpn.AppConfig
import com.vpn.fortivavpn.dto.EConfigType
import com.vpn.fortivavpn.fmt.VmessFmt
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class TestLinkTest {
    @Test
    fun everyKindTheTunnelDialsCanBeTested() {
        assertEquals(EConfigType.VLESS, TestLink.typeOf("vless://id@1.2.3.4:443?type=tcp#a"))
        assertEquals(EConfigType.VMESS, TestLink.typeOf("vmess://eyJhZGQiOiIxLjIuMy40In0="))
        assertEquals(EConfigType.TROJAN, TestLink.typeOf("trojan://pw@1.2.3.4:443#a"))
        assertEquals(EConfigType.SHADOWSOCKS, TestLink.typeOf("ss://YWVzLTEyOC1nY206cHc@1.2.3.4:8388#a"))
        assertEquals(EConfigType.VLESS, TestLink.typeOf("  vless://id@1.2.3.4:443\n"))
    }

    @Test
    fun aKindTheTestCannotDialIsNotRead() {
        // hysteria2 needs a program the build does not ship.
        assertNull(TestLink.typeOf("hysteria2://pw@1.2.3.4:443#a"))
        assertNull(TestLink.typeOf("hy2://pw@1.2.3.4:443#a"))
        assertNull(TestLink.typeOf("wireguard://key@1.2.3.4:51820#a"))
        assertNull(TestLink.typeOf("socks://dXNlcjpwdw@1.2.3.4:1080#a"))
        assertNull(TestLink.typeOf("http://example.com"))
        assertNull(TestLink.typeOf("not a link"))
        assertNull(TestLink.read("hy2://pw@1.2.3.4:443#a"))
        assertNull(TestLink.read(""))
    }

    @Test
    fun theWaitIsTheOneTheAppAsksFor() {
        assertEquals(TestLink.DEFAULT_TIMEOUT_MS, TestLink.timeoutMs(null))
        assertEquals(3000L, TestLink.DEFAULT_TIMEOUT_MS)
        assertEquals(8000L, TestLink.timeoutMs(8000))
        assertEquals(8000L, TestLink.timeoutMs(8000L))
        assertEquals(TestLink.MIN_TIMEOUT_MS, TestLink.timeoutMs(5))
        assertEquals(TestLink.MIN_TIMEOUT_MS, TestLink.timeoutMs(-1))
        assertEquals(TestLink.MAX_TIMEOUT_MS, TestLink.timeoutMs(600_000))
    }

    @Test
    fun aWaitTheBackendSetsIsKeptOrNotRun() {
        assertEquals(6000L, TestLink.timeoutMsAsSent(6000))
        assertEquals(6000L, TestLink.timeoutMsAsSent(6000L))
        assertEquals(TestLink.MIN_TIMEOUT_MS, TestLink.timeoutMsAsSent(TestLink.MIN_TIMEOUT_MS))
        assertEquals(TestLink.MAX_TIMEOUT_MS, TestLink.timeoutMsAsSent(TestLink.MAX_TIMEOUT_MS))
        // Missing, or a wait the door checks would change: not run.
        assertNull(TestLink.timeoutMsAsSent(null))
        assertNull(TestLink.timeoutMsAsSent(TestLink.MIN_TIMEOUT_MS - 1))
        assertNull(TestLink.timeoutMsAsSent(TestLink.MAX_TIMEOUT_MS + 1))
        assertNull(TestLink.timeoutMsAsSent(-1))
    }

    @Test
    fun theLogNeverCarriesTheCredential() {
        assertEquals(
            "vless://***@1.2.3.4:443?type=ws&security=tls",
            TestLink.redact("vless://b831381d-6324-4d53-ad4f-8cda48b30811@1.2.3.4:443?type=ws&security=tls#name"),
        )
        assertEquals("trojan://***@h.example:443", TestLink.redact("trojan://secret@h.example:443#a@b"))
        // vmess keeps the id inside its base64, so none of it is written.
        val vmess = "vmess://eyJhZGQiOiIxLjIuMy40IiwiaWQiOiJzZWNyZXQifQ=="
        assertEquals("vmess://***", TestLink.redact(vmess))
        assertEquals("vmess://***", TestLink.redact("$vmess#Telegram @channel"))
        assertFalse(TestLink.redact(vmess).contains("eyJ"))
    }

    @Test
    fun aVmessLinkInQueryFormIsReadWithItsLabelAndMode() {
        ConfigRig().use {
            val door = checkNotNull(VmessFmt.parse(VMESS_QUERY))
            assertEquals(EConfigType.VMESS, door.configType)
            assertEquals("Fortiva \uD83C\uDDEB\uD83C\uDDEE Helsinki", door.remarks)
            assertEquals("203.0.113.7", door.server)
            assertEquals("12345", door.serverPort)
            assertEquals(VMESS_ID, door.password)
            assertEquals("xhttp", door.network)
            assertEquals("/a1b2", door.path)
            assertEquals("auto", door.xhttpMode)
            // The link names no cipher, so one dialled from it uses the default.
            assertEquals("auto", door.method)
            // "none" means no TLS or REALITY layer. VMess still encrypts with its own cipher.
            assertNull(door.security)

            val other = checkNotNull(VmessFmt.parse(VMESS_QUERY_PACKET_UP))
            assertEquals("Fortiva DE Frankfurt am Main", other.remarks)
            assertEquals("packet-up", other.xhttpMode)
        }
    }

    @Test
    fun aVmessLinkInQueryFormIsDialledAsItSays() {
        ConfigRig().use {
            val (door, outbound) = checkNotNull(TestLink.read(VMESS_QUERY_PACKET_UP))
            assertEquals(EConfigType.VMESS, door.configType)
            assertEquals("vmess", outbound.protocol)
            val server = outbound.settings!!.vnext!!.single()
            assertEquals("203.0.113.7", server.address)
            assertEquals(12345, server.port)
            assertEquals(VMESS_ID, server.users.single().id)
            assertEquals("auto", server.users.single().security)
            val stream = outbound.streamSettings!!
            assertEquals("xhttp", stream.network)
            assertEquals("/a1b2", stream.xhttpSettings!!.path)
            assertEquals("packet-up", stream.xhttpSettings!!.mode)
            assertNull(stream.security)
            assertNull(stream.tlsSettings)
            assertNull(stream.realitySettings)
        }
    }

    @Test
    fun aConnectImportsAVmessLinkInQueryFormAndBuildsItsConfig() {
        ConfigRig().use { rig ->
            // As MainActivity imports the door it dials and each door beside it.
            assertEquals(1, AngConfigManager.importBatchConfig(VMESS_QUERY, "", false).first)
            val guid = MmkvManager.decodeServerList().single()
            assertEquals("Fortiva \uD83C\uDDEB\uD83C\uDDEE Helsinki", MmkvManager.decodeServerConfig(guid)!!.remarks)

            val result = V2rayConfigManager.getV2rayConfig(rig.context, guid)
            assertTrue(result.status)
            val proxy = JsonParser.parseString(result.content).asJsonObject
                .getAsJsonArray("outbounds")[0].asJsonObject
            assertEquals("vmess", proxy["protocol"].asString)
            val server = proxy.getAsJsonObject("settings").getAsJsonArray("vnext")[0].asJsonObject
            assertEquals("203.0.113.7", server["address"].asString)
            assertEquals(12345, server["port"].asInt)
            assertEquals(VMESS_ID, server.getAsJsonArray("users")[0].asJsonObject["id"].asString)
            val stream = proxy.getAsJsonObject("streamSettings")
            assertEquals("xhttp", stream["network"].asString)
            assertEquals("/a1b2", stream.getAsJsonObject("xhttpSettings")["path"].asString)
            assertEquals("auto", stream.getAsJsonObject("xhttpSettings")["mode"].asString)
            assertFalse(stream.has("tlsSettings"))
            assertFalse(stream.has("realitySettings"))
        }
    }

    @Test
    fun aVmessLinkInQueryFormStandsByInAGroup() {
        ConfigRig().use { rig ->
            rig.door("door-0", DoorConfigsTest.XHTTP_REALITY)
            MmkvManager.encodeServerConfig("door-1", checkNotNull(VmessFmt.parse(VMESS_QUERY_PACKET_UP)))
            val result = V2rayConfigManager.getV2rayAutoSelectConfig(
                rig.context,
                listOf("door-0", "door-1"),
                listOf("13", "13"),
                listOf(0, 1500),
                true,
            )
            assertTrue(result.status)
            val standby = JsonParser.parseString(result.content).asJsonObject
                .getAsJsonArray("outbounds").map { it.asJsonObject }
                .single { it["tag"].asString == "proxy@1" }
            assertEquals("vmess", standby["protocol"].asString)
            val stream = standby.getAsJsonObject("streamSettings")
            assertEquals("xhttp", stream["network"].asString)
            assertEquals("packet-up", stream.getAsJsonObject("xhttpSettings")["mode"].asString)
        }
    }

    @Test
    fun theBackendsOutboundIsDialledInPlaceOfAVmessLinkInQueryForm() {
        ConfigRig().use { rig ->
            MmkvManager.encodeServerConfig("door-0", checkNotNull(VmessFmt.parse(VMESS_QUERY)))
            MmkvManager.encodeSettings(
                AppConfig.PREF_DOOR_OUTBOUNDS,
                DoorOutbounds.encode(listOf("door-0"), listOf("""{"outbound": $VMESS_OUTBOUND}""")),
            )
            val result = V2rayConfigManager.getV2rayConfig(rig.context, "door-0")
            assertTrue(result.doorOutbounds)
            val proxy = JsonParser.parseString(result.content).asJsonObject.getAsJsonArray("outbounds")[0]
            assertEquals(JsonParser.parseString(VMESS_OUTBOUND), proxy)
        }
    }

    @Test
    fun theLogKeepsTheCredentialOfAVmessLinkInQueryFormOut() {
        val redacted = TestLink.redact(VMESS_QUERY)
        assertEquals(
            "vmess://***@203.0.113.7:12345?type=xhttp&security=none&path=%2Fa1b2&mode=auto",
            redacted,
        )
        assertFalse(redacted.contains(VMESS_ID))
    }

    private companion object {
        const val VMESS_ID = "c1d2e3f4-a5b6-4c7d-8e9f-0a1b2c3d4e5f"

        /** A VMess link in query form with no TLS. */
        const val VMESS_QUERY = "vmess://$VMESS_ID@203.0.113.7:12345" +
            "?type=xhttp&security=none&path=%2Fa1b2&mode=auto" +
            "#Fortiva%20%F0%9F%87%AB%F0%9F%87%AE%20Helsinki"

        const val VMESS_QUERY_PACKET_UP = "vmess://$VMESS_ID@203.0.113.7:12345" +
            "?type=xhttp&security=none&path=%2Fa1b2&mode=packet-up" +
            "#Fortiva%20DE%20Frankfurt%20am%20Main"

        /** An outbound for that link, with a cipher and a mode the link does not name. */
        const val VMESS_OUTBOUND = """{
            "tag": "proxy", "protocol": "vmess",
            "settings": {"vnext": [{"address": "203.0.113.7", "port": 12345,
                "users": [{"id": "$VMESS_ID", "security": "chacha20-poly1305", "level": 8}]}]},
            "streamSettings": {"network": "xhttp",
                "xhttpSettings": {"path": "/a1b2", "host": "", "mode": "packet-up"}}
        }"""
    }
}
