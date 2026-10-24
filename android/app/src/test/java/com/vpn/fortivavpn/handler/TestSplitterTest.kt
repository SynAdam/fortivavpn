package com.vpn.fortivavpn.handler

import com.google.gson.JsonArray
import com.google.gson.JsonObject
import com.google.gson.JsonParser
import com.vpn.fortivavpn.AppConfig
import com.vpn.fortivavpn.dto.V2rayConfig.OutboundBean
import com.vpn.fortivavpn.dto.V2rayConfig.OutboundBean.StreamSettingsBean
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Every door test's core carries the app's "fragment" splitter, and only a
 * TLS outbound dials through it. The cores of tests that run side by side
 * share one outbound manager, and a TLS test looks its splitter up in the
 * newest core's, so a core without one failed the TLS tests beside it. See
 * TestLink.config.
 */
class TestSplitterTest {
    private val app = TlsFragment.Spec("10-20", "1-2")
    private val own = TlsFragment.Spec("100-200", "10-20")

    private fun door(security: String) = OutboundBean(
        protocol = "vless",
        streamSettings = StreamSettingsBean(network = "tcp", security = security),
    )

    private fun outbounds(config: String): JsonArray =
        JsonParser.parseString(config).asJsonObject.getAsJsonArray("outbounds")

    private fun tagged(config: String, tag: String): List<JsonObject> =
        outbounds(config).map { it.asJsonObject }.filter { it.get("tag")?.asString == tag }

    private fun dialerProxy(outbound: JsonObject): String? =
        outbound.getAsJsonObject("streamSettings")
            ?.getAsJsonObject("sockopt")
            ?.get("dialerProxy")
            ?.asString

    private fun lengthOf(splitter: JsonObject): String =
        splitter.getAsJsonObject("settings").getAsJsonObject("fragment").get("length").asString

    @Test
    fun aRealityTestCarriesTheSplitterAndDoesNotDialThroughIt() {
        val config = TestLink.config(door(AppConfig.REALITY), null, app)
        val proxy = tagged(config, "proxy").single()
        val splitter = tagged(config, AppConfig.TAG_FRAGMENT).single()
        assertNull(dialerProxy(proxy))
        assertEquals(AppConfig.PROTOCOL_FREEDOM, splitter.get("protocol").asString)
        assertEquals("tlshello", splitter.getAsJsonObject("settings").getAsJsonObject("fragment").get("packets").asString)
        assertEquals("10-20", lengthOf(splitter))
        assertEquals(2, outbounds(config).size())
        // The door stays first, so the delay test dials it and not the splitter.
        assertEquals("proxy", outbounds(config)[0].asJsonObject.get("tag").asString)
    }

    @Test
    fun aTlsTestDialsThroughItsOwnSplitWhenItsLinkNamesOne() {
        val config = TestLink.config(door(AppConfig.TLS), own, app)
        val proxy = tagged(config, "proxy").single()
        val splitter = tagged(config, AppConfig.TAG_FRAGMENT).single()
        assertEquals(AppConfig.TAG_FRAGMENT, dialerProxy(proxy))
        assertEquals("100-200", lengthOf(splitter))
    }

    @Test
    fun aTlsTestWhoseLinkTurnsTheSplitOffStillCarriesTheSplitter() {
        // A test point's "off", "ech" and "ff" variants: fragment=off.
        val config = TestLink.config(door(AppConfig.TLS), TlsFragment.parse("off"), app)
        assertNull(dialerProxy(tagged(config, "proxy").single()))
        assertEquals("10-20", lengthOf(tagged(config, AppConfig.TAG_FRAGMENT).single()))
    }

    @Test
    fun withTheAppsSplitOffNothingIsAdded() {
        val reality = TestLink.config(door(AppConfig.REALITY), null, TlsFragment.parse(""))
        assertEquals(1, outbounds(reality).size())
        val tls = TestLink.config(door(AppConfig.TLS), null, null)
        assertEquals(1, outbounds(tls).size())
        assertNull(dialerProxy(tagged(tls, "proxy").single()))
    }

    @Test
    fun aSplitWhoseLengthReachesZeroAddsNothing() {
        // The core refuses these ("LengthMin can't be 0") and then fails the
        // whole config, so a Reality test with one in its core failed too.
        for (value in listOf("tlshello,0-20,1-2", "tlshello,20-0,1-2")) {
            val config = TestLink.config(door(AppConfig.REALITY), null, TlsFragment.parse(value))
            assertEquals(value, 1, outbounds(config).size())
        }
        for (value in listOf("tlshello,0,0", "tlshello,0000,1-2", "tlshello,0-0,5")) {
            assertNull(value, TlsFragment.parse(value))
        }
        // A TLS link that names one dials with its hello whole.
        val tls = TestLink.config(door(AppConfig.TLS), TlsFragment.parse("tlshello,0-20,1-2"), null)
        assertEquals(1, outbounds(tls).size())
        assertNull(dialerProxy(tagged(tls, "proxy").single()))
    }

    @Test
    fun aGapOfZeroAndAnyOtherLengthStillParse() {
        // Only the length is refused at 0; the core accepts a gap of 0.
        assertEquals(TlsFragment.Spec("1-20", "0"), TlsFragment.parse("tlshello,1-20,0"))
        assertEquals(TlsFragment.Spec("10-20", "1-2"), TlsFragment.parse("tlshello,10-20,1-2"))
        assertEquals(TlsFragment.Spec("100", "0-5"), TlsFragment.parse("tlshello,100,0-5"))
    }

    @Test
    fun addSplitterAddsOneAndPointsNothingAtIt() {
        val proxy = door(AppConfig.REALITY)
        val list = mutableListOf(proxy)
        assertTrue(TlsFragment.addSplitter(list, app))
        assertFalse(TlsFragment.addSplitter(list, own))
        assertEquals(2, list.size)
        assertEquals(AppConfig.TAG_FRAGMENT, list[1].tag)
        assertEquals("10-20", list[1].settings?.fragment?.length)
        assertNull(proxy.streamSettings?.sockopt?.dialerProxy)
    }

    @Test
    fun applyToStillSplitsOnlyTls() {
        val reality = door(AppConfig.REALITY)
        val list = mutableListOf(reality)
        assertFalse(TlsFragment.applyTo(reality, list, app))
        assertEquals(1, list.size)

        val tls = door(AppConfig.TLS)
        val doors = mutableListOf(tls)
        assertTrue(TlsFragment.applyTo(tls, doors, app))
        assertEquals(AppConfig.TAG_FRAGMENT, tls.streamSettings?.sockopt?.dialerProxy)
        assertEquals(2, doors.size)
        // A second door shares the splitter already there.
        val second = door(AppConfig.TLS)
        assertTrue(TlsFragment.applyTo(second, doors, own))
        assertEquals(2, doors.size)
        assertEquals("10-20", doors[1].settings?.fragment?.length)
    }
}
