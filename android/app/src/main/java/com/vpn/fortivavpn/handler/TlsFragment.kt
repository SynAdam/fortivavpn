package com.vpn.fortivavpn.handler

import com.vpn.fortivavpn.AppConfig
import com.vpn.fortivavpn.dto.V2rayConfig.OutboundBean
import com.vpn.fortivavpn.dto.V2rayConfig.OutboundBean.StreamSettingsBean

/**
 * Sends the TLS hello in small, spaced-out TCP segments, so a filter that
 * reads the server name out of one packet does not find it whole.
 *
 * A filter can reset the TLS handshake on our CDN links while TCP still
 * connects.
 *
 * A link asks for it with a `fragment` parameter, which the app adds to
 * TLS links when the backend's remote config says so. The value is
 * "tlshello,<lengths>,<gaps>", for example "tlshello,10-20,10-20": which
 * packets to split, the segment sizes in bytes and the gaps in ms. Only a
 * TLS outbound is split. A Reality handshake is a borrowed site's, and it
 * works as it is.
 */
object TlsFragment {
    data class Spec(val length: String, val interval: String)

    private val RANGE = Regex("^\\d{1,4}(-\\d{1,4})?$")

    /** The spec in [value], or null when it is missing or malformed. */
    fun parse(value: String?): Spec? {
        val parts = value?.split(",")?.map { it.trim() } ?: return null
        if (parts.size != 3 || parts[0] != "tlshello") return null
        if (!RANGE.matches(parts[1]) || !RANGE.matches(parts[2])) return null
        // The core refuses a length range that reaches 0 ("LengthMin can't
        // be 0" in infra/conf/freedom.go, after it puts the two ends in
        // order), and then fails the whole config. Every door test's core
        // carries the app's splitter (TestLink.config), so one such value
        // from the backend failed every test, Reality doors and shared links
        // included: on 2026-10-12, with the pinned core, a Reality test
        // failed at config load with "tlshello,0-20,1-2" or "tlshello,0,0".
        // Both ends are checked because "20-0" and "0000" fail the same way.
        // With no spec, a TLS link sends its hello whole in the test and the
        // tunnel alike. The app's TlsFragment.usable applies the same rule.
        if (parts[1].split("-").any { it.toInt() == 0 }) return null
        return Spec(parts[1], parts[2])
    }

    /**
     * Dials the first outbound in [outbounds] through a fragmenting freedom
     * outbound added after it. Returns whether it did: only a TLS outbound
     * is changed, and only once.
     */
    fun apply(outbounds: MutableList<OutboundBean>, spec: Spec): Boolean {
        val proxy = outbounds.firstOrNull() ?: return false
        if (outbounds.any { it.tag == AppConfig.TAG_FRAGMENT }) return false
        return applyTo(proxy, outbounds, spec)
    }

    /**
     * Dials [proxy] through the fragmenting freedom outbound in [outbounds],
     * adding that outbound when it is not there yet ([addSplitter]).
     * Returns whether it did: only a TLS outbound is changed.
     *
     * For a config that holds several doors. They share one splitter, so the
     * first door that asks for one decides its sizes and gaps.
     */
    fun applyTo(proxy: OutboundBean, outbounds: MutableList<OutboundBean>, spec: Spec): Boolean {
        val stream = proxy.streamSettings ?: return false
        if (stream.security != AppConfig.TLS) return false
        addSplitter(outbounds, spec)
        stream.sockopt = StreamSettingsBean.SockoptBean(dialerProxy = AppConfig.TAG_FRAGMENT)
        return true
    }

    /**
     * Adds the fragmenting freedom outbound to [outbounds] when none is there
     * yet, and points no outbound at it. Returns whether it added one.
     *
     * Only an outbound whose sockopt names it as its dialerProxy dials
     * through it, which [applyTo] sets on a TLS outbound only. A door test
     * adds it to every config, Reality ones included, for the reason given
     * at TestLink.config.
     */
    fun addSplitter(outbounds: MutableList<OutboundBean>, spec: Spec): Boolean {
        if (outbounds.any { it.tag == AppConfig.TAG_FRAGMENT }) return false
        val splitter = OutboundBean(
            protocol = AppConfig.PROTOCOL_FREEDOM,
            tag = AppConfig.TAG_FRAGMENT,
            mux = null,
        )
        splitter.settings = OutboundBean.OutSettingsBean(
            fragment = OutboundBean.OutSettingsBean.FragmentBean(
                packets = "tlshello",
                length = spec.length,
                interval = spec.interval,
            ),
        )
        splitter.streamSettings = StreamSettingsBean(
            sockopt = StreamSettingsBean.SockoptBean(TcpNoDelay = true, mark = 255),
        )
        outbounds.add(splitter)
        return true
    }
}
