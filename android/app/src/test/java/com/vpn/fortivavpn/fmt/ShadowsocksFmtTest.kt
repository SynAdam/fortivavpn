package com.vpn.fortivavpn.fmt

import android.util.Base64
import com.google.gson.JsonParser
import com.vpn.fortivavpn.dto.EConfigType
import com.vpn.fortivavpn.dto.V2rayConfig.OutboundBean
import com.vpn.fortivavpn.handler.ConfigRig
import com.vpn.fortivavpn.handler.MmkvManager
import com.vpn.fortivavpn.handler.TestLink
import com.vpn.fortivavpn.handler.V2rayConfigManager
import java.net.URLEncoder
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Before
import org.junit.Test
import org.mockito.MockedStatic
import org.mockito.Mockito

/**
 * Shadowsocks links with a transport, as the backend serves the lab's best
 * combinations, and the plain SIP002 links that must read as before.
 */
class ShadowsocksFmtTest {
    private lateinit var rig: ConfigRig
    private lateinit var base64: MockedStatic<Base64>

    // A 2022 key is base64, so it carries the characters a URI must escape.
    private val key = "q3/W+Jq8oV2ezq0UQZfh7yK1Hc4aN7nFv5Bf0kJx4dE="
    private val chacha = "2022-blake3-chacha20-poly1305"

    @Before
    fun setUp() {
        rig = ConfigRig()
        // android.util.Base64 is a stub on the JVM; answer as the phone does.
        base64 = Mockito.mockStatic(Base64::class.java) { inv ->
            when (inv.method.name) {
                "decode" -> {
                    val flags = inv.arguments[1] as Int
                    val text = inv.arguments[0] as String
                    if (flags and Base64.URL_SAFE != 0) java.util.Base64.getUrlDecoder().decode(text)
                    else java.util.Base64.getDecoder().decode(text)
                }
                "encodeToString" -> java.util.Base64.getEncoder().encodeToString(inv.arguments[0] as ByteArray)
                else -> Mockito.RETURNS_DEFAULTS.answer(inv)
            }
        }
    }

    @After
    fun tearDown() {
        base64.close()
        rig.close()
    }

    private fun enc(value: String) = URLEncoder.encode(value, "UTF-8").replace("+", "%20")

    /** A link to [host]:[port] with the 2022 chacha key and [query]. */
    private fun link(query: String, method: String = chacha, port: Int = 8443, host: String = "203.0.113.10") =
        "ss://${enc(method)}:${enc(key)}@$host:$port?$query#door"

    private fun outbound(link: String): OutboundBean {
        val profile = checkNotNull(ShadowsocksFmt.parse(link)) { "the link did not parse" }
        return checkNotNull(ShadowsocksFmt.toOutbound(profile)) { "no outbound" }
    }

    @Test
    fun shadowsocks2022OverXhttpWithoutTlsReadsItsTransport() {
        val profile = ShadowsocksFmt.parse(link("type=xhttp&path=%2Fa1b2&host=cdn.example&mode=packet-up"))!!
        assertEquals(EConfigType.SHADOWSOCKS, profile.configType)
        assertEquals(chacha, profile.method)
        assertEquals(key, profile.password)
        assertEquals("xhttp", profile.network)
        assertEquals("/a1b2", profile.path)
        assertEquals("cdn.example", profile.host)
        assertEquals("packet-up", profile.xhttpMode)
        assertNull(profile.security)

        val out = outbound(link("type=xhttp&path=%2Fa1b2&host=cdn.example&mode=packet-up&security=none"))
        val server = out.settings!!.servers!!.first()
        assertEquals("203.0.113.10", server.address)
        assertEquals(8443, server.port)
        assertEquals(chacha, server.method)
        assertEquals(key, server.password)
        val stream = out.streamSettings!!
        assertEquals("xhttp", stream.network)
        assertEquals("/a1b2", stream.xhttpSettings?.path)
        assertEquals("cdn.example", stream.xhttpSettings?.host)
        assertEquals("packet-up", stream.xhttpSettings?.mode)
        assertNull(stream.security)
    }

    @Test
    fun xhttpWithRealityGetsTheRealitySettings() {
        val stream = outbound(
            link("type=xhttp&path=%2Fx&mode=auto&security=reality&sni=www.samsung.com&fp=chrome&pbk=PUBKEY&sid=ab12"),
        ).streamSettings!!
        assertEquals("xhttp", stream.network)
        assertEquals("reality", stream.security)
        val reality = stream.realitySettings!!
        assertEquals("www.samsung.com", reality.serverName)
        assertEquals("chrome", reality.fingerprint)
        assertEquals("PUBKEY", reality.publicKey)
        assertEquals("ab12", reality.shortId)
    }

    @Test
    fun theOtherTransportsAndTls() {
        val ws = outbound(link("type=ws&path=%2Fws&host=media.example&security=tls&sni=media.example&fp=chrome"))
            .streamSettings!!
        assertEquals("ws", ws.network)
        assertEquals("/ws", ws.wsSettings?.path)
        assertEquals("tls", ws.security)
        assertEquals("media.example", ws.tlsSettings?.serverName)

        val upgrade = outbound(link("type=httpupgrade&path=%2Fup&host=media.example&security=tls&sni=media.example"))
            .streamSettings!!
        assertEquals("httpupgrade", upgrade.network)
        assertEquals("/up", upgrade.httpupgradeSettings?.path)
        assertEquals("tls", upgrade.security)

        val grpc = outbound(link("type=grpc&serviceName=svc&mode=gun&security=tls&sni=media.example"))
            .streamSettings!!
        assertEquals("grpc", grpc.network)
        assertEquals("svc", grpc.grpcSettings?.serviceName)
        assertEquals("tls", grpc.security)

        val raw = outbound(link("type=tcp&security=reality&sni=www.microsoft.com&pbk=PUBKEY&sid=01&fp=chrome"))
            .streamSettings!!
        assertEquals("tcp", raw.network)
        assertEquals("reality", raw.security)
    }

    @Test
    fun everyCipherTheLabTestsIsKept() {
        for (method in listOf(
            "2022-blake3-chacha20-poly1305",
            "2022-blake3-aes-256-gcm",
            "2022-blake3-aes-128-gcm",
            "chacha20-poly1305",
            "xchacha20-poly1305",
            "aes-256-gcm",
            "aes-128-gcm",
        )) {
            val server = outbound(link("type=xhttp&path=%2Fp", method = method)).settings!!.servers!!.first()
            assertEquals(method, server.method)
            assertEquals(key, server.password)
        }
    }

    @Test
    fun aPlainSip002LinkReadsAsBefore() {
        val plain = "ss://aes-256-gcm:secret@198.51.100.7:8388#plain"
        val profile = ShadowsocksFmt.parse(plain)!!
        assertNull(profile.network)
        assertNull(profile.security)
        val stream = ShadowsocksFmt.toOutbound(profile)!!.streamSettings!!
        assertEquals("tcp", stream.network)
        assertNull(stream.security)

        // The base64 form of SIP002.
        val userinfo = java.util.Base64.getUrlEncoder().withoutPadding()
            .encodeToString("chacha20-ietf-poly1305:pw".toByteArray())
        val b64 = ShadowsocksFmt.parse("ss://$userinfo@198.51.100.7:8388#b64")!!
        assertEquals("chacha20-ietf-poly1305", b64.method)
        assertEquals("pw", b64.password)
        assertNull(b64.network)
    }

    @Test
    fun theObfsPluginReadsAsBefore() {
        val plugin = enc("obfs-local;obfs=http;obfs-host=example.com")
        val profile = ShadowsocksFmt.parse("ss://aes-128-gcm:pw@198.51.100.7:8388?plugin=$plugin#obfs")!!
        assertEquals("tcp", profile.network)
        assertEquals("http", profile.headerType)
        assertEquals("example.com", profile.host)
    }

    @Test
    fun aTransportLinkSurvivesARoundTrip() {
        val profile = ShadowsocksFmt.parse(
            link("type=xhttp&path=%2Fa1b2&host=cdn.example&mode=packet-up&security=reality&sni=www.samsung.com&pbk=K&sid=s"),
        )!!
        // toUri leaves the scheme to its caller (AngConfigManager.shareConfig).
        val again = ShadowsocksFmt.parse(EConfigType.SHADOWSOCKS.protocolScheme + ShadowsocksFmt.toUri(profile))!!
        assertEquals(profile.method, again.method)
        assertEquals(profile.password, again.password)
        assertEquals("xhttp", again.network)
        assertEquals("/a1b2", again.path)
        assertEquals("packet-up", again.xhttpMode)
        assertEquals("reality", again.security)
        assertEquals("www.samsung.com", again.sni)
        assertEquals("K", again.publicKey)

        // A plain one stays a plain SIP002 link, with no query.
        val plain = ShadowsocksFmt.parse("ss://aes-256-gcm:secret@198.51.100.7:8388#plain")!!
        assertEquals(false, ShadowsocksFmt.toUri(plain).contains("?"))
    }

    @Test
    fun theTunnelDialsTheTransport() {
        val profile = ShadowsocksFmt.parse(link("type=xhttp&path=%2Fa1b2&mode=packet-up&security=none"))!!
        MmkvManager.encodeServerConfig("door-0", profile)
        val config = JsonParser.parseString(V2rayConfigManager.getV2rayConfig(rig.context, "door-0").content).asJsonObject
        val proxy = config.getAsJsonArray("outbounds").map { it.asJsonObject }.first { it.get("tag").asString == "proxy" }
        assertEquals("shadowsocks", proxy.get("protocol").asString)
        val stream = proxy.getAsJsonObject("streamSettings")
        assertEquals("xhttp", stream.get("network").asString)
        assertEquals("/a1b2", stream.getAsJsonObject("xhttpSettings").get("path").asString)
        assertEquals(chacha, proxy.getAsJsonObject("settings").getAsJsonArray("servers")[0].asJsonObject.get("method").asString)
    }

    @Test
    fun aDoorCheckDialsTheTransportToo() {
        val read = TestLink.read(link("type=xhttp&path=%2Fp&mode=packet-up"))
        assertNotNull(read)
        val out = read!!.second
        assertEquals("shadowsocks", out.protocol)
        assertEquals("xhttp", out.streamSettings?.network)
    }
}
