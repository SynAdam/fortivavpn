package com.vpn.fortivavpn.service

import com.google.gson.JsonParser
import com.vpn.fortivavpn.AppConfig
import com.vpn.fortivavpn.dto.ConfigResult
import com.vpn.fortivavpn.handler.ConfigRig
import com.vpn.fortivavpn.handler.DoorConfigsTest
import com.vpn.fortivavpn.handler.DoorOutbounds
import com.vpn.fortivavpn.handler.MmkvManager
import com.vpn.fortivavpn.handler.V2rayConfigManager
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import java.io.File

/**
 * The order the tunnel starts its core in (CoreStart), with the configs
 * V2rayConfigManager builds as the tunnel's process builds them, and a core
 * that refuses some of them.
 *
 * A config the core refuses must never cost the user the connection the
 * first door's link gives. Each config that starts from the links is the
 * one main builds (door_configs_main.txt, see DoorConfigsTest).
 */
class CoreStartTest {
    private lateinit var rig: ConfigRig

    @Before
    fun setUp() {
        rig = ConfigRig()
    }

    @After
    fun tearDown() {
        rig.close()
    }

    /** A core that will not start what [refuses] picks, and keeps every config it was given. */
    private class Core(val refuses: (String) -> Boolean) {
        val given = mutableListOf<String>()

        fun run(config: String): Boolean {
            given.add(config)
            return !refuses(config)
        }
    }

    /** The backend's outbound of DoorConfigsTest, which has a setting no link gives. */
    private val backends: (String) -> Boolean = { it.contains("heartbeatPeriod") }

    /** A door group: its first outbound is the core's group of doors. */
    private val groups: (String) -> Boolean = {
        JsonParser.parseString(it).asJsonObject.getAsJsonArray("outbounds")[0].asJsonObject["protocol"].asString ==
            AppConfig.PROTOCOL_AUTOSELECT
    }

    private val main: Map<String, String> by lazy {
        File(DoorConfigsTest.GOLDEN).readLines().filter { it.isNotBlank() }.associate {
            it.substringAfter(' ') to it.substringBefore(' ')
        }
    }

    private val four = DoorConfigsTest.GROUPS.getValue("four doors")
    private val guids = four.links.indices.map { "door-$it" }

    /** Stores the four doors, with the backend's outbound for those in [withOutbound]. */
    private fun doors(withOutbound: Set<Int>) {
        four.links.forEachIndexed { i, link -> rig.door("door-$i", link!!) }
        val entries = guids.indices.map { if (it in withOutbound) DoorConfigsTest.ENTRY else "" }
        MmkvManager.encodeSettings(AppConfig.PREF_DOOR_OUTBOUNDS, DoorOutbounds.encode(guids, entries))
    }

    private fun oneDoor(doorOutbounds: Boolean = true): ConfigResult =
        V2rayConfigManager.getV2rayConfig(rig.context, "door-0", doorOutbounds)

    private fun group(doorOutbounds: Boolean = true): ConfigResult =
        V2rayConfigManager.getV2rayAutoSelectConfig(rig.context, guids, four.exits, four.penalties, doorOutbounds)

    /** What V2RayServiceManager.startCoreLoop builds when the first config does not start. */
    private val fromLinks: (Boolean) -> ConfigResult = { grouped ->
        if (grouped) group(doorOutbounds = false) else oneDoor(doorOutbounds = false)
    }

    @Test
    fun aDoorWhoseOutboundTheCoreRefusesStartsFromItsLink() {
        doors(withOutbound = setOf(0))
        val first = oneDoor()
        assertTrue(first.doorOutbounds)
        val core = Core(backends)
        val started = checkNotNull(CoreStart.firstThatStarts(first, false, core::run, fromLinks))
        assertFalse(started.grouped)
        assertEquals(main["one xhttp-reality"], ConfigRig.sha256(started.result.content))
        assertEquals(2, core.given.size)
    }

    @Test
    fun aGroupWhoseOutboundsTheCoreRefusesStartsFromTheLinksAndStaysAGroup() {
        doors(withOutbound = setOf(0, 2))
        val first = group()
        assertTrue(first.doorOutbounds)
        val core = Core(backends)
        val started = checkNotNull(CoreStart.firstThatStarts(first, true, core::run, fromLinks))
        assertTrue(started.grouped)
        assertEquals(main["group four doors"], ConfigRig.sha256(started.result.content))
        assertEquals(2, core.given.size)
    }

    @Test
    fun aGroupTheCoreRefusesFromTheLinksTooStartsThroughTheFirstDoorsLink() {
        doors(withOutbound = setOf(0, 2))
        val core = Core { backends(it) || groups(it) }
        val started = checkNotNull(CoreStart.firstThatStarts(group(), true, core::run, fromLinks))
        assertFalse(started.grouped)
        assertEquals(main["one xhttp-reality"], ConfigRig.sha256(started.result.content))
        assertEquals(3, core.given.size)
    }

    @Test
    fun aGroupWithoutOutboundsGoesStraightToTheFirstDoorsLink() {
        doors(withOutbound = emptySet())
        val first = group()
        assertFalse(first.doorOutbounds)
        val core = Core(groups)
        val started = checkNotNull(CoreStart.firstThatStarts(first, true, core::run, fromLinks))
        assertFalse(started.grouped)
        assertEquals(main["one xhttp-reality"], ConfigRig.sha256(started.result.content))
        assertEquals(listOf(first.content), core.given.take(1))
        assertEquals(2, core.given.size)
    }

    @Test
    fun aConfigTheCoreStartsIsTheOneKept() {
        doors(withOutbound = setOf(0))
        for (grouped in listOf(true, false)) {
            val first = if (grouped) group() else oneDoor()
            val core = Core { false }
            val started = checkNotNull(CoreStart.firstThatStarts(first, grouped, core::run, fromLinks))
            assertTrue(started.result === first)
            assertEquals(grouped, started.grouped)
            assertEquals(1, core.given.size)
        }
    }

    @Test
    fun nothingStartsWhenTheCoreRefusesEveryConfig() {
        doors(withOutbound = setOf(0))
        val core = Core { true }
        assertNull(CoreStart.firstThatStarts(group(), true, core::run, fromLinks))
        assertEquals(3, core.given.size)
        val alone = Core { true }
        assertNull(CoreStart.firstThatStarts(oneDoor(), false, alone::run, fromLinks))
        assertEquals(2, alone.given.size)
        // A door without the backend's outbound is not built again.
        doors(withOutbound = emptySet())
        val plain = Core { true }
        assertNull(CoreStart.firstThatStarts(oneDoor(), false, plain::run, fromLinks))
        assertEquals(1, plain.given.size)
    }
}
