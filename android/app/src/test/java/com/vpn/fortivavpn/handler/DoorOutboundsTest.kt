package com.vpn.fortivavpn.handler

import android.util.Log
import com.google.gson.JsonObject
import com.google.gson.JsonParser
import com.vpn.fortivavpn.dto.ConfigResult
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Before
import org.junit.Test
import org.mockito.MockedStatic
import org.mockito.Mockito

/**
 * The backend's door outbounds (variant loop contract v2, section 2) and
 * the variant tests' own configs (section 1), as the native side reads them.
 */
class DoorOutboundsTest {
    private lateinit var log: MockedStatic<Log>

    @Before
    fun setUp() {
        log = Mockito.mockStatic(Log::class.java)
    }

    @After
    fun tearDown() {
        log.close()
    }

    private fun obj(json: String): JsonObject = JsonParser.parseString(json).asJsonObject

    @Test
    fun aDoorOutboundIsReadWithItsHelpers() {
        val door = DoorOutbounds.parse(ENTRY)!!
        assertEquals(obj(OUTBOUND), door.outbound)
        assertEquals(listOf(obj(HELPER)), door.helpers)
        // No helpers is a door outbound too.
        assertEquals(emptyList<JsonObject>(), DoorOutbounds.parse("""{"outbound": $OUTBOUND}""")!!.helpers)
        assertNotNull(DoorOutbounds.parse("""{"outbound": $OUTBOUND, "helper_outbounds": null}"""))
    }

    @Test
    fun anOutboundTheAppCannotUseIsNone() {
        val bad = listOf(
            null,
            "",
            "not json {",
            "[]",
            """"text"""",
            """{}""",
            """{"outbound": "vless://x"}""",
            """{"outbound": {"protocol": "vless"}}""",
            """{"outbound": {"tag": "proxy"}}""",
            """{"outbound": {"tag": " ", "protocol": "vless"}}""",
            """{"outbound": {"tag": "proxy", "protocol": 7}}""",
            """{"outbound": $OUTBOUND, "helper_outbounds": {"tag": "fragment"}}""",
            """{"outbound": $OUTBOUND, "helper_outbounds": [{"tag": "fragment"}]}""",
            """{"outbound": $OUTBOUND, "helper_outbounds": ["fragment"]}""",
            """{"outbound": $OUTBOUND, "helper_outbounds": [$HELPER, $HELPER]}""",
        )
        for (json in bad) assertNull(json, DoorOutbounds.parse(json))
    }

    @Test
    fun aHelperMayNotTakeOneOfTheAppsOwnTags() {
        for (tag in listOf("proxy", "proxy@0", "proxy@3", "direct", "block", "dns-out")) {
            val entry = """{"outbound": $OUTBOUND, "helper_outbounds": [{"tag": "$tag", "protocol": "freedom"}]}"""
            assertNull(tag, DoorOutbounds.parse(entry))
        }
        assertNotNull(
            DoorOutbounds.parse("""{"outbound": $OUTBOUND, "helper_outbounds": [{"tag": "proxy-chain", "protocol": "freedom"}]}"""),
        )
    }

    @Test
    fun theConnectKeepsEachDoorsOutboundUnderItsGuid() {
        val stored = DoorOutbounds.encode(listOf("g0", "g1", "", "g3"), listOf(ENTRY, "", ENTRY, "{}"))
        assertEquals(obj(OUTBOUND), DoorOutbounds.of(stored, "g0")!!.outbound)
        assertNull(DoorOutbounds.of(stored, "g1"))
        // A door that did not import has no guid, and its outbound goes
        // nowhere.
        assertNull(DoorOutbounds.of(stored, ""))
        // One the app cannot use is not kept.
        assertNull(DoorOutbounds.of(stored, "g3"))
        assertEquals(setOf("g0"), obj(stored).keySet())
    }

    @Test
    fun aConnectWithNoOutboundKeepsNothing() {
        assertEquals("", DoorOutbounds.encode(listOf("g0", "g1"), emptyList()))
        assertEquals("", DoorOutbounds.encode(listOf("g0"), listOf("")))
        assertEquals("", DoorOutbounds.encode(emptyList(), listOf(ENTRY)))
        assertNull(DoorOutbounds.of(null, "g0"))
        assertNull(DoorOutbounds.of("", "g0"))
        assertNull(DoorOutbounds.of("not json", "g0"))
        assertNull(DoorOutbounds.of("""{"g0": 7}""", "g0"))
    }

    @Test
    fun aDoorCheckDialsTheBackendsOutboundAsItCame() {
        val config = obj(DoorOutbounds.testConfig(DoorOutbounds.parse(ENTRY)!!, SPLIT))
        val outbounds = config.getAsJsonArray("outbounds")
        val proxy = outbounds[0].asJsonObject
        // As the backend wrote it, a setting the app's own types do not
        // know included, under the tag a test dials and without mux.
        val expected = obj(OUTBOUND).apply { remove("mux") }
        assertEquals(expected, proxy)
        assertEquals("443", proxy.getAsJsonObject("settings").getAsJsonArray("vnext")[0].asJsonObject["port"].toString())
        // Its helper, and no second splitter: the helper is tagged fragment.
        assertEquals(obj(HELPER), outbounds[1].asJsonObject)
        assertEquals(2, outbounds.size())
        assertEquals("none", config.getAsJsonObject("log")["loglevel"].asString)
    }

    @Test
    fun aDoorCheckWithoutAHelperSplitterCarriesTheAppsOne() {
        val door = DoorOutbounds.parse("""{"outbound": $OUTBOUND}""")!!
        val outbounds = obj(DoorOutbounds.testConfig(door, SPLIT)).getAsJsonArray("outbounds")
        assertEquals(2, outbounds.size())
        val splitter = outbounds[1].asJsonObject
        assertEquals("fragment", splitter["tag"].asString)
        assertEquals("10-20", splitter.getAsJsonObject("settings").getAsJsonObject("fragment")["length"].asString)
        // Nothing dials through it.
        assertFalse(outbounds[0].toString().contains("dialerProxy"))
        // With no split the app sends none.
        assertEquals(1, obj(DoorOutbounds.testConfig(door, null)).getAsJsonArray("outbounds").size())
    }

    @Test
    fun theOutboundAlwaysTakesTheTagATestDials() {
        val door = DoorOutbounds.parse("""{"outbound": ${OUTBOUND.replace("\"proxy\"", "\"door-13\"")}}""")!!
        val proxy = obj(DoorOutbounds.testConfig(door, null)).getAsJsonArray("outbounds")[0].asJsonObject
        assertEquals("proxy", proxy["tag"].asString)
    }

    @Test
    fun aVariantConfigIsRunAsTheBackendWroteIt() {
        val config = """{"outbounds": [$OUTBOUND, $HELPER], "log": {"loglevel": "warning"}}"""
        assertEquals(obj(config), obj(DoorOutbounds.checkConfig(config, SPLIT)!!))
    }

    @Test
    fun aVariantConfigWithoutASplitterOrALogGetsTheTestDefaults() {
        val config = """{"outbounds": [$OUTBOUND]}"""
        val ready = obj(DoorOutbounds.checkConfig(config, SPLIT)!!)
        val outbounds = ready.getAsJsonArray("outbounds")
        assertEquals(obj(OUTBOUND), outbounds[0].asJsonObject)
        assertEquals("fragment", outbounds[1].asJsonObject["tag"].asString)
        assertEquals("none", ready.getAsJsonObject("log")["loglevel"].asString)
        // Without the app's split, nothing is added but the log.
        assertEquals(1, obj(DoorOutbounds.checkConfig(config, null)!!).getAsJsonArray("outbounds").size())
    }

    @Test
    fun aVariantConfigThatDialsThroughAMissingSplitterIsNotGivenTheApps() {
        val dials = OUTBOUND.replace("\"network\": \"ws\"", "\"network\": \"ws\", \"sockopt\": {\"dialerProxy\": \"fragment\"}")
        assertTrue(dials.contains("dialerProxy"))
        val ready = obj(DoorOutbounds.checkConfig("""{"outbounds": [$dials]}""", SPLIT)!!)
        assertEquals(1, ready.getAsJsonArray("outbounds").size())
    }

    @Test
    fun aVariantConfigTheCheckCannotRunIsRefused() {
        val bad = listOf(
            null,
            "",
            "not json {",
            "[]",
            """{}""",
            """{"outbounds": []}""",
            """{"outbounds": {"tag": "proxy"}}""",
            """{"outbounds": ["proxy"]}""",
            // The check dials the first outbound, so it must be the one
            // tagged proxy.
            """{"outbounds": [$HELPER, $OUTBOUND]}""",
            """{"outbounds": [{"tag": "proxy"}]}""",
        )
        for (json in bad) assertNull(json, DoorOutbounds.checkConfig(json, SPLIT))
    }

    @Test
    fun theTcpCheckGoesToTheAddressTheOutboundNames() {
        assertEquals("203.0.113.7" to 443, DoorOutbounds.endpoint(obj(OUTBOUND)))
        assertEquals(
            "203.0.113.9" to 8388,
            DoorOutbounds.endpoint(obj("""{"protocol": "shadowsocks", "settings": {"servers": [{"address": "203.0.113.9", "port": 8388}]}}""")),
        )
        // A protocol that names its server another way gets no TCP check.
        assertNull(DoorOutbounds.endpoint(obj("""{"protocol": "hysteria", "settings": {"address": "203.0.113.9", "port": 443}}""")))
        assertNull(DoorOutbounds.endpoint(obj("""{"protocol": "vless", "settings": "x"}""")))
        assertNull(DoorOutbounds.endpoint(obj("""{"protocol": "vless"}""")))
    }

    @Test
    fun aSwapReplacesOnlyTheTaggedOutbound() {
        val built = """{"outbounds": [{"tag": "proxy", "protocol": "vless"}, {"tag": "direct", "protocol": "freedom"}], "dns": {"servers": ["1.1.1.1"]}}"""
        val swapped = obj(DoorOutbounds.swap(built, mapOf("proxy" to obj(OUTBOUND)))!!)
        assertEquals(obj(OUTBOUND), swapped.getAsJsonArray("outbounds")[0].asJsonObject)
        assertEquals(obj(built).getAsJsonArray("outbounds")[1], swapped.getAsJsonArray("outbounds")[1])
        assertEquals(obj(built)["dns"], swapped["dns"])
    }

    @Test
    fun noSwapIsTheConfigAsBuilt() {
        val built = """{"outbounds": [{"tag": "proxy"}]}"""
        assertTrue(built === DoorOutbounds.swap(built, emptyMap()))
    }

    @Test
    fun aSwapWithATagThatIsNotThereExactlyOnceFails() {
        val missing = """{"outbounds": [{"tag": "direct", "protocol": "freedom"}]}"""
        assertNull(DoorOutbounds.swap(missing, mapOf("proxy" to obj(OUTBOUND))))
        val twice = """{"outbounds": [{"tag": "proxy", "protocol": "vless"}, {"tag": "proxy", "protocol": "vless"}]}"""
        assertNull(DoorOutbounds.swap(twice, mapOf("proxy" to obj(OUTBOUND))))
        assertNull(DoorOutbounds.swap("not json", mapOf("proxy" to obj(OUTBOUND))))
    }

    @Test
    fun theAppsOwnLookupOfTheDoorsHostIsKept() {
        val host = "cdn.example.site"
        val built = """{"outbounds": [{"tag": "proxy", "protocol": "vless",
            "settings": {"vnext": [{"address": "$host", "port": 443}]},
            "streamSettings": {"sockopt": {"domainStrategy": "UseIPv4v6"}}}]}"""
        val backend = obj(OUTBOUND.replace("203.0.113.7", host))
        val swapped = obj(DoorOutbounds.swap(built, mapOf("proxy" to backend))!!)
        val proxy = swapped.getAsJsonArray("outbounds")[0].asJsonObject
        assertEquals("UseIPv4v6", proxy.getAsJsonObject("streamSettings").getAsJsonObject("sockopt")["domainStrategy"].asString)

        // Not for another address, and not over the backend's own choice.
        val elsewhere = obj(DoorOutbounds.swap(built, mapOf("proxy" to obj(OUTBOUND)))!!)
        assertFalse(elsewhere.toString().contains("UseIPv4v6"))
        val own = obj(
            OUTBOUND.replace("203.0.113.7", host)
                .replace("\"network\": \"ws\"", "\"network\": \"ws\", \"sockopt\": {\"domainStrategy\": \"UseIPv6\"}"),
        )
        val kept = obj(DoorOutbounds.swap(built, mapOf("proxy" to own))!!)
        assertTrue(kept.toString().contains("\"UseIPv6\""))
        assertFalse(kept.toString().contains("UseIPv4v6"))
    }

    @Test
    fun aDoorCheckWhoseCoreNeverStartedTheOutboundSaysSo() {
        // What CheckDoorTimed answers when startCheckCore fails, with the
        // core's own words (TestAConfigTheCoreRefusesSaysItNeverStarted in
        // android/core/fortivacore).
        for (error in listOf(
            "config load error: infra/conf/serial: failed to read config file at line 1 char 243 > json: " +
                "cannot unmarshal number into Go struct field SplitHTTPConfig.outbounds.streamSettings.xhttpSettings.mode of type string",
            "instance creation failed: unknown outbound",
            "startup failed: closed",
            "panic: runtime error: invalid memory address",
        )) {
            val timed = """{"ms": -1, "boot_ms": 2, "bytes_out": 0, "bytes_in": 0, "dials": 0, "dial_fails": 0, "error": "$error"}"""
            assertTrue(error, DoorOutbounds.notStartedTimed(timed))
            assertTrue(error, DoorOutbounds.notStarted(error))
        }
        assertTrue(DoorOutbounds.notStartedTimed("""{"ms": -1, "error": "config load error: x"}"""))
        // The plain check's own words, from libv2ray's MeasureOutboundDelay.
        assertTrue(DoorOutbounds.notStarted(" config load error: x"))
    }

    @Test
    fun aDoorCheckThatRanIsNotReadAsNeverStarted() {
        for (json in listOf(
            null,
            "",
            "not json",
            "[]",
            // Open.
            """{"ms": 120, "phase": "ok", "dials": 1, "dial_ms": 30}""",
            // Closed after dialling, or at a phase.
            """{"ms": -1, "phase": "tcp", "dials": 2, "dial_fails": 2, "error": "dial tcp: i/o timeout"}""",
            """{"ms": -1, "dials": 1, "error": "config load error: x"}""",
            """{"ms": -1, "dial_ms": 20, "error": "config load error: x"}""",
            """{"ms": -1, "phase": "tls", "error": "config load error: x"}""",
            // The wait ran out, or the core's error is another one.
            """{"ms": -1, "dials": 0, "error": "no answer in 3000 ms"}""",
            """{"ms": -1, "dials": 0, "error": "EOF; failed to dial: config load error: x"}""",
            """{"ms": -1, "dials": 0}""",
            """{"dials": 0, "error": "config load error: x"}""",
            """{"ms": 5, "dials": 0, "error": "config load error: x"}""",
        )) {
            assertFalse(json, DoorOutbounds.notStartedTimed(json))
        }
        for (error in listOf(null, "", "no answer in 3000 ms", "io: read/write on closed pipe", "EOF; config load error: x")) {
            assertFalse(error, DoorOutbounds.notStarted(error))
        }
    }

    @Test
    fun aConfigTheOutboundsCannotBePutIntoIsBuiltFromTheLinks() {
        val fromLinks = ConfigResult(true, "links", """{"outbounds": [{"tag": "proxy", "protocol": "vless"}]}""")
        var built = 0
        val staged = ConfigResult(true, "door", """{"outbounds": [{"tag": "direct", "protocol": "freedom"}]}""")
        val result = DoorOutbounds.finish(staged, mapOf("proxy" to obj(OUTBOUND))) { built++; fromLinks }
        assertTrue(result === fromLinks)
        assertEquals(1, built)
        assertFalse(result.doorOutbounds)
    }

    @Test
    fun aConfigTheOutboundsArePutIntoDialsThem() {
        val staged = ConfigResult(true, "door", """{"outbounds": [{"tag": "proxy", "protocol": "vless"}]}""")
        val result = DoorOutbounds.finish(staged, mapOf("proxy" to obj(OUTBOUND))) { fail("built again"); staged }
        assertTrue(result.doorOutbounds)
        assertEquals(obj(OUTBOUND), obj(result.content).getAsJsonArray("outbounds")[0].asJsonObject)
    }

    @Test
    fun aConfigWithNoOutboundsToPutInIsLeftAsBuilt() {
        val content = """{"outbounds": [{"tag": "proxy", "protocol": "vless"}]}"""
        val built = ConfigResult(true, "door", content)
        val result = DoorOutbounds.finish(built, emptyMap()) { fail("built again"); built }
        assertTrue(result === built)
        assertTrue(result.content === content)
        assertFalse(result.doorOutbounds)
    }

    companion object {
        val SPLIT = TlsFragment.Spec("10-20", "1-2")

        /** A door's outbound as the backend writes it, with a setting the app's types do not have. */
        const val OUTBOUND = """{
            "tag": "proxy", "protocol": "vless",
            "settings": {"vnext": [{"address": "203.0.113.7", "port": 443,
                "users": [{"id": "b831381d-6324-4d53-ad4f-8cda48b30811", "encryption": "none", "level": 8}]}]},
            "streamSettings": {"network": "ws", "security": "tls",
                "tlsSettings": {"serverName": "cdn.example.site", "fingerprint": "chrome", "pinnedPeerCertSha256": "abc"},
                "wsSettings": {"path": "/ws", "heartbeatPeriod": 30}},
            "mux": {"enabled": false, "concurrency": -1}
        }"""

        const val HELPER = """{"tag": "fragment", "protocol": "freedom",
            "settings": {"fragment": {"packets": "tlshello", "length": "100-200", "interval": "10-20"}}}"""

        const val ENTRY = """{"outbound": $OUTBOUND, "helper_outbounds": [$HELPER]}"""
    }
}
