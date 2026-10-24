package com.vpn.fortivavpn.handler

import com.google.gson.Gson
import com.google.gson.JsonParser
import com.vpn.fortivavpn.dto.V2rayConfig
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * DNS in a backup network session, whose SOCKS proxy accepts CONNECT only:
 * the phone's UDP queries go to the core's own resolver, which asks over
 * TCP. Built on the app's own config template.
 */
class PsiphonDnsTest {
    private fun template(): V2rayConfig {
        val text = File("src/main/assets/v2ray_config.json").readText()
        val config = Gson().fromJson(text, V2rayConfig::class.java)
        // What getDns and the Iran preset put in, in the order they do.
        config.dns = V2rayConfig.DnsBean(
            servers = arrayListOf(
                "1.1.1.1",
                V2rayConfig.DnsBean.ServersBean(
                    address = "1.1.1.1",
                    domains = listOf("domain:ir", "geosite:category-ir"),
                    skipFallback = true,
                ),
                "https://dns.example.invalid/dns-query",
                "2606:4700:4700::1111",
            ),
            hosts = mapOf("dns.google" to listOf("8.8.8.8")),
        )
        config.routing.rules.add(
            V2rayConfig.RoutingBean.RulesBean(network = "udp", port = "443", outboundTag = "block"),
        )
        config.routing.rules.add(
            V2rayConfig.RoutingBean.RulesBean(ip = arrayListOf("geoip:ir"), outboundTag = "direct"),
        )
        config.routing.rules.add(
            0,
            V2rayConfig.RoutingBean.RulesBean(port = "53", ip = arrayListOf("1.1.1.1"), outboundTag = "proxy"),
        )
        return config
    }

    @Test
    fun udpDnsGoesToTheCoresResolverFirst() {
        val config = template()
        val before = config.routing.rules.toList()

        V2rayConfigManager.psiphonDns(config)

        val first = config.routing.rules[0]
        assertEquals("udp", first.network)
        assertEquals("53", first.port)
        assertEquals("dns-out", first.outboundTag)
        // Every other rule is still there, in its order: the resolver's own
        // queries to 1.1.1.1:53 still go to the proxy, the UDP/443 block
        // and the Iran-direct rule stay.
        assertEquals(before, config.routing.rules.drop(1))
    }

    @Test
    fun theDnsOutboundIsAddedOnce() {
        val config = template()

        V2rayConfigManager.psiphonDns(config)
        V2rayConfigManager.psiphonDns(config)

        val dnsOut = config.outbounds.filter { it.tag == "dns-out" }
        assertEquals(1, dnsOut.size)
        assertEquals("dns", dnsOut[0].protocol)
        // The first outbound is still the proxy.
        assertEquals("proxy", config.outbounds[0].tag)
    }

    @Test
    fun bareResolversAreAskedOverTcp() {
        val config = template()

        V2rayConfigManager.psiphonDns(config)

        val servers = config.dns!!.servers!!
        assertEquals("tcp://1.1.1.1", servers[0])
        val domestic = servers[1] as V2rayConfig.DnsBean.ServersBean
        assertEquals("tcp://1.1.1.1", domestic.address)
        assertEquals(listOf("domain:ir", "geosite:category-ir"), domestic.domains)
        assertEquals("https://dns.example.invalid/dns-query", servers[2])
        assertEquals("tcp://[2606:4700:4700::1111]", servers[3])
    }

    @Test
    fun theResolverAddressForms() {
        assertEquals("tcp://9.9.9.9", V2rayConfigManager.tcpResolver("9.9.9.9"))
        assertEquals("tcp://[2001:db8::53]", V2rayConfigManager.tcpResolver("2001:db8::53"))
        assertEquals("tcp://[2001:db8::53]", V2rayConfigManager.tcpResolver("[2001:db8::53]"))
        assertEquals("tcp://1.1.1.1", V2rayConfigManager.tcpResolver("tcp://1.1.1.1"))
        assertEquals("localhost", V2rayConfigManager.tcpResolver("localhost"))
    }

    @Test
    fun theCoreGetsTheRuleAsItReadsIt() {
        val config = template()
        V2rayConfigManager.psiphonDns(config)

        val json = JsonParser.parseString(Gson().toJson(config)).asJsonObject
        val rule = json.getAsJsonObject("routing").getAsJsonArray("rules")[0].asJsonObject
        assertEquals("udp", rule.get("network").asString)
        assertEquals("53", rule.get("port").asString)
        assertEquals("dns-out", rule.get("outboundTag").asString)
        assertEquals("field", rule.get("type").asString)
        assertTrue(json.getAsJsonArray("outbounds").any { it.asJsonObject.get("tag").asString == "dns-out" })
    }
}
