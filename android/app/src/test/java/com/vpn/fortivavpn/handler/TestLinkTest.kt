package com.vpn.fortivavpn.handler

import com.vpn.fortivavpn.dto.EConfigType
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
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
}
