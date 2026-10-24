package com.vpn.fortivavpn.handler

import com.google.gson.JsonParser
import com.vpn.fortivavpn.dto.EConfigType
import com.vpn.fortivavpn.dto.ProfileItem
import com.vpn.fortivavpn.dto.V2rayConfig.OutboundBean.StreamSettingsBean
import com.vpn.fortivavpn.fmt.VlessFmt
import com.vpn.fortivavpn.util.JsonUtil
import java.net.URI
import java.net.URLEncoder
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Test

class FinalMaskTest {
    // The values the backend sends for the "ff" spec.
    private val mask =
        """{"tcp":[{"type":"fragment","settings":{"packets":"tlshello","lengths":["0","104","1"],""" +
            """"delays":["0"],"maxSplit":"0"}},{"type":"fragment","settings":{"packets":"1-1",""" +
            """"lengths":["114","1"],"delays":["1"],"maxSplit":"11"}}]}"""
    private val suites = "TLS_AES_256_GCM_SHA384:TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256"

    private fun encoded(value: String) = URLEncoder.encode(value, "UTF-8")

    /** What the app makes of a link to our Cloudflare door with [query]. */
    private fun stream(query: String): StreamSettingsBean {
        val uri = URI("vless://00000000-0000-0000-0000-000000000000@198.51.100.215:443?$query#door")
        val item = ProfileItem.create(EConfigType.VLESS)
        item.server = uri.host
        VlessFmt.getItemFormQuery(item, VlessFmt.getQueryParam(uri), false)
        val stream = StreamSettingsBean(network = "ws")
        V2rayConfigManager.populateTlsSettings(stream, item, null)
        return stream
    }

    @Test
    fun anFfLinkGivesTheCoreItsMaskSuitesAndFingerprint() {
        val stream = stream(
            "security=tls&type=ws&sni=media.example&fp=unsafe&fragment=off" +
                "&fm=${encoded(mask)}&cs=${encoded(suites)}",
        )
        assertEquals("unsafe", stream.tlsSettings?.fingerprint)
        assertEquals(suites, stream.tlsSettings?.cipherSuites)
        // Written into the core's config as an object, not as text.
        val written = JsonParser.parseString(JsonUtil.toJsonPretty(stream)).asJsonObject
        assertEquals(JsonParser.parseString(mask), written.get("finalmask"))
    }

    @Test
    fun aLinkWithoutThemIsUnchanged() {
        val stream = stream("security=tls&type=ws&sni=media.example&fp=chrome")
        assertNull(stream.finalmask)
        assertNull(stream.tlsSettings?.cipherSuites)
        val written = JsonParser.parseString(JsonUtil.toJsonPretty(stream)).asJsonObject
        assertNull(written.get("finalmask"))
    }

    @Test
    fun onlyAJsonObjectIsAMask() {
        assertNotNull(FinalMask.parse(mask))
        // A preset name from a community link means nothing to the core.
        assertNull(FinalMask.parse("tlshello-0-len"))
        assertNull(FinalMask.parse("{not json"))
        assertNull(FinalMask.parse("[]"))
        assertNull(FinalMask.parse(""))
        assertNull(FinalMask.parse(null))
    }
}
