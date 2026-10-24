package com.vpn.fortivavpn.handler

import com.google.gson.JsonArray
import com.google.gson.JsonObject
import com.google.gson.JsonParser
import com.vpn.fortivavpn.AppConfig
import com.vpn.fortivavpn.dto.ConfigResult
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Before
import org.junit.Test
import java.io.File

/**
 * The tunnel's configs, built by V2rayConfigManager as the tunnel's process
 * builds them, for one door and for a group of doors that stand by.
 *
 * Doors that carry no backend outbound get the configs origin/main builds,
 * byte for byte. door_configs_main.txt holds the SHA-256 of each config
 * below as the code on 2e18706 built it: the base of this branch, before
 * the backend's door outbounds (variant loop contract v2, section 2) were
 * added. Main still has that native code. To make the file again, copy
 * ConfigRig.kt and this test onto origin/main, delete the file, and run the
 * test twice.
 *
 * A door that carries one is dialled with the backend's JSON as it came,
 * and the rest of the config stays what main builds.
 */
class DoorConfigsTest {
    private lateinit var rig: ConfigRig

    @Before
    fun setUp() {
        rig = ConfigRig()
    }

    @After
    fun tearDown() {
        rig.close()
    }

    private fun fresh() {
        rig.close()
        rig = ConfigRig()
    }

    private fun obj(json: String): JsonObject = JsonParser.parseString(json).asJsonObject

    /** The config for one door of [link], with [entry] as what the connect sent for it. */
    private fun one(link: String, entry: String? = null, doorOutbounds: Boolean = true): ConfigResult {
        fresh()
        rig.door("door-0", link)
        if (entry != null) store(mapOf("door-0" to entry))
        return V2rayConfigManager.getV2rayConfig(rig.context, "door-0", doorOutbounds)
    }

    /** The config for [group], with [entries] by door position. */
    private fun group(group: Group, entries: Map<Int, String> = emptyMap(), doorOutbounds: Boolean = true): ConfigResult {
        fresh()
        group.links.forEachIndexed { i, link -> if (link != null) rig.door("door-$i", link) }
        val guids = group.links.mapIndexed { i, link -> if (link == null) "" else "door-$i" }
        if (entries.isNotEmpty()) store(entries.mapKeys { "door-${it.key}" })
        return V2rayConfigManager.getV2rayAutoSelectConfig(
            rig.context,
            guids,
            group.exits,
            group.penalties,
            doorOutbounds,
        )
    }

    /** What the connect keeps for the tunnel's process (MainActivity.writeDoorOutbounds). */
    private fun store(entries: Map<String, String>) {
        val guids = entries.keys.toList()
        MmkvManager.encodeSettings(AppConfig.PREF_DOOR_OUTBOUNDS, DoorOutbounds.encode(guids, guids.map { entries.getValue(it) }))
    }

    /** Every config below, by name, each door with [entry] of its link when it gives one. */
    private fun build(entry: (String) -> String? = { null }, doorOutbounds: Boolean = true): Map<String, String> {
        val out = linkedMapOf<String, String>()
        for ((name, link) in DOORS) {
            val result = one(link, entry(link), doorOutbounds)
            assertTrue(name, result.status)
            out["one $name"] = result.content
        }
        for ((name, g) in GROUPS) {
            val entries = g.links.withIndex().mapNotNull { (i, link) -> link?.let(entry)?.let { i to it } }.toMap()
            val result = group(g, entries, doorOutbounds)
            assertTrue(name, result.status)
            out["group $name"] = result.content
        }
        return out
    }

    private fun main(): Map<String, String> {
        val file = File(GOLDEN)
        if (!file.exists()) {
            val built = build().mapValues { ConfigRig.sha256(it.value) }
            file.parentFile?.mkdirs()
            file.writeText(built.entries.joinToString("\n", postfix = "\n") { "${it.value} ${it.key}" })
            fail("wrote $GOLDEN; run the test again")
        }
        return file.readLines().filter { it.isNotBlank() }.associate {
            it.substringAfter(' ') to it.substringBefore(' ')
        }
    }

    @Test
    fun aDoorWithNoBackendOutboundGetsTheConfigMainBuilds() {
        assertEquals(main(), build().mapValues { ConfigRig.sha256(it.value) })
    }

    @Test
    fun theConfigBuiltFromTheLinksAloneIsMainsEvenWhenTheDoorsHaveOutbounds() {
        // What the tunnel falls back to when the core will not start with
        // the backend's outbounds (V2RayServiceManager.startCoreLoop).
        val built = build(entry = { ENTRY }, doorOutbounds = false)
        assertEquals(main(), built.mapValues { ConfigRig.sha256(it.value) })
        assertFalse(built.values.any { it.contains("heartbeatPeriod") })
    }

    @Test
    fun anOutboundTheTunnelCannotUseLeavesTheConfigMains() {
        fresh()
        rig.door("door-0", XHTTP_REALITY)
        // Written past the connect's own check, as an older or broken writer could.
        MmkvManager.encodeSettings(
            AppConfig.PREF_DOOR_OUTBOUNDS,
            JsonObject().apply { addProperty("door-0", """{"outbound": {"tag": "proxy"}}""") }.toString(),
        )
        val result = V2rayConfigManager.getV2rayConfig(rig.context, "door-0")
        assertEquals(main()["one xhttp-reality"], ConfigRig.sha256(result.content))
        assertFalse(result.doorOutbounds)
    }

    @Test
    fun oneDoorIsDialledWithTheBackendsOutboundAndItsHelpers() {
        for ((name, link) in DOORS) {
            val main = obj(one(link).content)
            val result = one(link, ENTRY)
            assertTrue(name, result.doorOutbounds)
            val built = obj(result.content)
            // Everything but the outbounds is what main builds.
            assertEquals(name, main.deepCopy().apply { remove("outbounds") }, built.deepCopy().apply { remove("outbounds") })
            // The backend's outbound in the door's place, and its helper in
            // place of the split the link asks for.
            val expected = JsonArray()
            expected.add(obj(OUTBOUND))
            for (o in main.getAsJsonArray("outbounds").drop(1)) {
                if (o.asJsonObject["tag"].asString != AppConfig.TAG_FRAGMENT) expected.add(o)
            }
            expected.add(obj(HELPER))
            assertEquals(name, expected, built.getAsJsonArray("outbounds"))
        }
    }

    @Test
    fun aDoorOutboundWithoutHelpersLeavesOutTheSplitItsLinkAsksFor() {
        val main = obj(one(WS_TLS).content)
        val built = obj(one(WS_TLS, """{"outbound": $HYSTERIA}""").content)
        val expected = JsonArray()
        expected.add(obj(HYSTERIA))
        for (o in main.getAsJsonArray("outbounds").drop(1)) {
            if (o.asJsonObject["tag"].asString != AppConfig.TAG_FRAGMENT) expected.add(o)
        }
        assertEquals(expected, built.getAsJsonArray("outbounds"))
    }

    @Test
    fun aProtocolTheAppCannotReadFromALinkGoesToTheCoreAsItCame() {
        val result = one(XHTTP_REALITY, """{"outbound": $HYSTERIA}""")
        val proxy = obj(result.content).getAsJsonArray("outbounds")[0].asJsonObject
        assertEquals(obj(HYSTERIA), proxy)
        // Numbers stay whole, as the core needs them.
        assertTrue(result.content.contains("\"version\": 2,"))
        assertFalse(result.content.contains("2.0"))
    }

    @Test
    fun theDoorTheGroupDialsWithTheBackendsOutboundKeepsItsPlaceExitAndPenalty() {
        val four = GROUPS.getValue("four doors")
        val main = obj(group(four).content)
        val result = group(four, mapOf(0 to ENTRY, 2 to """{"outbound": $HYSTERIA}"""))
        assertTrue(result.doorOutbounds)
        val built = obj(result.content)
        assertEquals(main.deepCopy().apply { remove("outbounds") }, built.deepCopy().apply { remove("outbounds") })
        val mainOut = main.getAsJsonArray("outbounds")
        val out = built.getAsJsonArray("outbounds")
        // The group itself, with its members, exits and penalties, is main's.
        assertEquals(mainOut[0], out[0])
        assertEquals(obj(OUTBOUND).apply { addProperty("tag", "proxy@0") }, out[1])
        assertEquals(mainOut[2], out[2])
        assertEquals(obj(HYSTERIA).apply { addProperty("tag", "proxy@2") }, out[3])
        assertEquals(mainOut[4], out[4])
        // The first door brought its splitter, so the TLS door behind it
        // dials through that one, as it would through the first link's.
        assertEquals(obj(HELPER), out[5])
        assertEquals(1, out.count { it.asJsonObject["tag"].asString == AppConfig.TAG_FRAGMENT })
        assertEquals(mainOut.drop(6), out.drop(6))
    }

    @Test
    fun aHelperWhoseTagIsTakenAlreadyIsLeftOut() {
        // The TLS door's link brought the splitter first.
        val tlsFirst = GROUPS.getValue("tls first")
        val main = obj(group(tlsFirst).content)
        val built = obj(group(tlsFirst, mapOf(1 to ENTRY)).content)
        val mainOut = main.getAsJsonArray("outbounds")
        val out = built.getAsJsonArray("outbounds")
        assertEquals(mainOut.size(), out.size())
        assertEquals(obj(OUTBOUND).apply { addProperty("tag", "proxy@1") }, out[2])
        for (i in 0 until out.size()) if (i != 2) assertEquals("$i", mainOut[i], out[i])
    }

    @Test
    fun theGlobalSplitSettingKeepsTheLink() {
        fresh()
        MmkvManager.encodeSettings(AppConfig.PREF_FRAGMENT_ENABLED, true)
        rig.door("door-0", WS_TLS)
        val plain = V2rayConfigManager.getV2rayConfig(rig.context, "door-0").content
        store(mapOf("door-0" to ENTRY))
        val result = V2rayConfigManager.getV2rayConfig(rig.context, "door-0")
        assertEquals(plain, result.content)
        assertFalse(result.doorOutbounds)
    }

    class Group(val links: List<String?>, val exits: List<String>, val penalties: List<Int>)

    companion object {
        const val GOLDEN = "src/test/resources/door_configs_main.txt"

        const val UUID = "b831381d-6324-4d53-ad4f-8cda48b30811"

        const val XHTTP_REALITY = "vless://$UUID@203.0.113.7:8443?type=xhttp&security=reality" +
            "&sni=www.samsung.com&pbk=bG9uZ3B1YmxpY2tleQ&sid=ab12&fp=chrome&mode=packet-up&path=%2Fx#Row13"
        const val TCP_REALITY = "vless://$UUID@203.0.113.8:443?type=tcp&security=reality" +
            "&sni=www.speedtest.net&pbk=bG9uZ3B1YmxpY2tleQ&sid=cd34&fp=chrome&flow=xtls-rprx-vision#Row13"
        const val WS_TLS = "vless://$UUID@198.51.100.215:443?type=ws&security=tls" +
            "&sni=cdn.example.site&host=cdn.example.site&path=%2Fws&fp=chrome&alpn=h2,http/1.1" +
            "&fragment=tlshello,10-20,1-2#Row13"
        const val XHTTP_REALITY_V6 = "vless://$UUID@[2001:db8::7]:8443?type=xhttp&security=reality" +
            "&sni=www.samsung.com&pbk=bG9uZ3B1YmxpY2tleQ&fp=chrome&mode=auto#Row13"
        const val GRPC_TLS = "vless://$UUID@203.0.113.9:443?type=grpc&security=tls" +
            "&sni=grpc.example.site&serviceName=svc&fp=chrome#Row14"
        const val WS_TLS_ECH = "vless://$UUID@198.51.100.215:443?type=ws&security=tls" +
            "&sni=cdn.example.site&host=cdn.example.site&path=%2Fws" +
            "&ech=cloudflare-ech.com%2Budp%3A%2F%2F1.1.1.1&fragment=off#Row13"

        val DOORS = linkedMapOf(
            "xhttp-reality" to XHTTP_REALITY,
            "tcp-reality" to TCP_REALITY,
            "ws-tls" to WS_TLS,
            "xhttp-reality-v6" to XHTTP_REALITY_V6,
            "grpc-tls" to GRPC_TLS,
            "ws-tls-ech" to WS_TLS_ECH,
        )

        val GROUPS = linkedMapOf(
            "four doors" to Group(
                listOf(XHTTP_REALITY, WS_TLS, XHTTP_REALITY_V6, TCP_REALITY),
                listOf("13", "", "13", "14"),
                listOf(0, 1500, 0, 700),
            ),
            "tls first" to Group(listOf(WS_TLS, XHTTP_REALITY), listOf("", "13"), emptyList()),
            "a door that did not import" to Group(
                listOf(XHTTP_REALITY, null, GRPC_TLS),
                listOf("13", "13", "14"),
                emptyList(),
            ),
        )

        /** A door's outbound from the backend, with settings the app's own types do not have. */
        const val OUTBOUND = """{
            "tag": "proxy", "protocol": "vless",
            "settings": {"vnext": [{"address": "203.0.113.7", "port": 443,
                "users": [{"id": "$UUID", "encryption": "none", "level": 8}]}]},
            "streamSettings": {"network": "ws", "security": "tls",
                "tlsSettings": {"serverName": "cdn.example.site", "fingerprint": "chrome"},
                "wsSettings": {"path": "/ws", "heartbeatPeriod": 30},
                "sockopt": {"dialerProxy": "fragment"}},
            "mux": {"enabled": false, "concurrency": -1}
        }"""

        const val HELPER = """{"tag": "fragment", "protocol": "freedom",
            "settings": {"fragment": {"packets": "tlshello", "length": "100-200", "interval": "10-20"}}}"""

        const val ENTRY = """{"outbound": $OUTBOUND, "helper_outbounds": [$HELPER]}"""

        /** An outbound of a protocol no link the app reads can name. */
        const val HYSTERIA = """{"tag": "proxy", "protocol": "hysteria",
            "settings": {"version": 2, "address": "203.0.113.7", "port": 443},
            "streamSettings": {"network": "hysteria", "hysteriaSettings": {"version": 2, "auth": "secret"}}}"""
    }
}
