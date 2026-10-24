package com.vpn.fortivavpn

import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.vpn.fortivavpn.handler.TestLink
import com.vpn.fortivavpn.handler.SettingsManager
import com.vpn.fortivavpn.util.Utils
import go.Seq
import libv2ray.Libv2ray
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Assume.assumeTrue
import org.junit.Test
import org.junit.runner.RunWith

/**
 * A Shadowsocks link with a transport, dialled by the phone's own core the
 * way a door check dials it (TestLink, MainActivity.realPing): read the
 * link, build its outbound, and fetch a page through it.
 *
 * It needs a server, so it runs only when one is named:
 *
 *     ./gradlew :app:connectedDebugAndroidTest \
 *       -Pandroid.testInstrumentationRunnerArguments.class=com.vpn.fortivavpn.ShadowsocksTransportDeviceTest \
 *       -Pandroid.testInstrumentationRunnerArguments.ssLink='ss://...?type=xhttp&path=...#test'
 *
 * `ssUrl` names the page to fetch (https://www.gstatic.com/generate_204
 * when it is not given). From an emulator, a server on the computer it runs
 * on is at 10.0.2.2.
 */
@RunWith(AndroidJUnit4::class)
class ShadowsocksTransportDeviceTest {

    @Test
    fun aShadowsocksLinkWithATransportCarriesTraffic() {
        val args = InstrumentationRegistry.getArguments()
        val link = args.getString("ssLink").orEmpty()
        assumeTrue("no ssLink argument: there is no server to dial", link.isNotEmpty())
        val url = args.getString("ssUrl") ?: "https://www.gstatic.com/generate_204"
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        // As V2RayTestService sets the core up.
        Seq.setContext(context)
        SettingsManager.initAssets(context, context.assets)
        Libv2ray.initCoreEnv(Utils.userAssetPath(context), Utils.getDeviceIdForXUDPBaseKey())

        val (_, outbound) = checkNotNull(TestLink.read(link)) { "the link did not read" }
        assertEquals("shadowsocks", outbound.protocol)
        val network = outbound.streamSettings?.network
        assertTrue("the link's transport was dropped: $network", network != null && network != "tcp")
        val delay = Libv2ray.measureOutboundDelay(TestLink.config(outbound, null, null), url)
        assertTrue("no answer through the link", delay > 0)

        // The same server read as plain Shadowsocks over TCP, as builds
        // before 2.2.0 read the link, gets no answer.
        val plain = link.substringBefore('?') + "#plain"
        val (_, tcp) = checkNotNull(TestLink.read(plain))
        assertEquals("tcp", tcp.streamSettings?.network)
        val refused = runCatching { Libv2ray.measureOutboundDelay(TestLink.config(tcp, null, null), url) }
        assertTrue("plain Shadowsocks got through an XHTTP door", refused.isFailure || refused.getOrNull()!! <= 0)
    }
}
