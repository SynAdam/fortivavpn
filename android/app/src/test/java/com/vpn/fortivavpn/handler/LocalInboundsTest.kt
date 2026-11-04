package com.vpn.fortivavpn.handler

import com.google.gson.JsonObject
import com.google.gson.JsonParser
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

/**
 * The core's local inbounds: one SOCKS port on loopback, asking for the
 * credentials of this start when there are any (LocalSocks), and no HTTP
 * port, in every config the tunnel's process builds.
 */
class LocalInboundsTest {
    private lateinit var rig: ConfigRig

    @Before
    fun setUp() {
        rig = ConfigRig()
        LocalSocks.clear()
    }

    @After
    fun tearDown() {
        LocalSocks.clear()
        rig.close()
    }

    private fun inbounds(content: String) =
        JsonParser.parseString(content).asJsonObject.getAsJsonArray("inbounds").map { it.asJsonObject }

    private fun configs(): List<String> {
        rig.door("door-0", DoorConfigsTest.XHTTP_REALITY)
        rig.door("door-1", DoorConfigsTest.TCP_REALITY)
        val one = V2rayConfigManager.getV2rayConfig(rig.context, "door-0")
        val group = V2rayConfigManager.getV2rayAutoSelectConfig(rig.context, listOf("door-0", "door-1"))
        assertTrue(one.status)
        assertTrue(group.status)
        return listOf(one.content, group.content)
    }

    @Test
    fun withCredentialsTheSocksPortAsksForThem() {
        val auth = LocalSocks.renew()
        for (content in configs()) {
            val all = inbounds(content)
            assertEquals(1, all.size)
            val socks = all.single()
            assertEquals("socks", socks.get("protocol").asString)
            assertEquals("127.0.0.1", socks.get("listen").asString)
            val settings = socks.getAsJsonObject("settings")
            assertEquals("password", settings.get("auth").asString)
            assertTrue(settings.get("udp").asBoolean)
            val accounts = settings.getAsJsonArray("accounts")
            assertEquals(1, accounts.size())
            val account: JsonObject = accounts[0].asJsonObject
            assertEquals(auth.user, account.get("user").asString)
            assertEquals(auth.pass, account.get("pass").asString)
        }
    }

    @Test
    fun withoutCredentialsTheSocksPortStaysAsItWas() {
        for (content in configs()) {
            val socks = inbounds(content).single()
            assertEquals("noauth", socks.getAsJsonObject("settings").get("auth").asString)
        }
    }

    @Test
    fun noConfigHasAnHttpPort() {
        LocalSocks.renew()
        for (content in configs()) {
            assertTrue(inbounds(content).none { it.get("protocol").asString == "http" })
        }
    }
}
