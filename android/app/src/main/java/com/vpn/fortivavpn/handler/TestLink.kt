package com.vpn.fortivavpn.handler

import com.vpn.fortivavpn.dto.EConfigType
import com.vpn.fortivavpn.dto.ProfileItem
import com.vpn.fortivavpn.dto.V2rayConfig.OutboundBean
import com.vpn.fortivavpn.fmt.ShadowsocksFmt
import com.vpn.fortivavpn.fmt.TrojanFmt
import com.vpn.fortivavpn.fmt.VlessFmt
import com.vpn.fortivavpn.fmt.VmessFmt
import com.vpn.fortivavpn.util.JsonUtil

/**
 * The links a delay test (realPing, realPingDetail) can dial, read the way
 * the tunnel reads them.
 *
 * The test used to read vless links only. A vmess, trojan or ss link from
 * the public list failed every test, showed as a timeout after "Test all"
 * and counted as closed in the fallback, although the tunnel dials all of
 * them (AngConfigManager.importBatchConfig). These are the same parsers it
 * uses. hysteria2 is left out because the build does not ship the program
 * that carries it, and the other kinds are not on the public list.
 */
object TestLink {

    /** How long a test waits for data when the app names no time. */
    const val DEFAULT_TIMEOUT_MS = 3000L

    /** The shortest wait the app may ask for. */
    const val MIN_TIMEOUT_MS = 1000L

    /** The longest wait the app may ask for. */
    const val MAX_TIMEOUT_MS = 20_000L

    /**
     * The wait the app asked for in [requested] milliseconds, kept between
     * [MIN_TIMEOUT_MS] and [MAX_TIMEOUT_MS]; [DEFAULT_TIMEOUT_MS] when it
     * asked for none. The app waits a little longer than this for the
     * answer, so the test gives up first and says why.
     */
    fun timeoutMs(requested: Number?): Long {
        val ms = requested?.toLong() ?: return DEFAULT_TIMEOUT_MS
        return ms.coerceIn(MIN_TIMEOUT_MS, MAX_TIMEOUT_MS)
    }

    /**
     * [requested] milliseconds when [timeoutMs] would keep it as it is, and
     * null when it is missing or outside [MIN_TIMEOUT_MS] to
     * [MAX_TIMEOUT_MS]. For a wait the backend sets (a variant test's): one
     * the app would change is not run at all, so a result never reports a
     * wait other than the backend's.
     */
    fun timeoutMsAsSent(requested: Number?): Long? {
        val ms = requested?.toLong() ?: return null
        return ms.takeIf { it in MIN_TIMEOUT_MS..MAX_TIMEOUT_MS }
    }

    /** The kind of [link], when it is one a test can dial. */
    fun typeOf(link: String): EConfigType? {
        val trimmed = link.trim()
        return listOf(
            EConfigType.VLESS,
            EConfigType.VMESS,
            EConfigType.TROJAN,
            EConfigType.SHADOWSOCKS,
        ).firstOrNull { trimmed.startsWith(it.protocolScheme) }
    }

    /**
     * [link] as a profile and the core outbound a test dials. Null when it
     * is not a kind a test can dial or cannot be read.
     */
    fun read(link: String): Pair<ProfileItem, OutboundBean>? {
        val profile = when (typeOf(link)) {
            EConfigType.VLESS -> VlessFmt.parse(link)
            EConfigType.VMESS -> VmessFmt.parse(link)
            EConfigType.TROJAN -> TrojanFmt.parse(link)
            EConfigType.SHADOWSOCKS -> ShadowsocksFmt.parse(link)
            else -> null
        } ?: return null
        val outbound = when (profile.configType) {
            EConfigType.VLESS -> VlessFmt.toOutbound(profile)
            EConfigType.VMESS -> VmessFmt.toOutbound(profile)
            EConfigType.TROJAN -> TrojanFmt.toOutbound(profile)
            EConfigType.SHADOWSOCKS -> ShadowsocksFmt.toOutbound(profile)
            else -> null
        } ?: return null
        return profile to outbound
    }

    /**
     * The core config a test of [outbound] runs with: the outbound alone as
     * "proxy", without mux. That is all measureOutboundDelay needs.
     *
     * [fragment] is the split the test's own link asks for. A test dials the
     * way the connection will, split included, or it measures a different
     * path from the one the user gets.
     *
     * [splitter] is the split the app sends with every test: the app's own,
     * or the one its own TLS doors carry (see below). Its "fragment"
     * outbound goes into every config, including Reality configs and
     * others that never split. Nothing in this config dials
     * through it. It is there for the TLS tests running beside this one:
     *
     * - The core keeps one outbound manager per process. core.New calls
     *   internet.InitSystemDialer, which replaces it with the manager of
     *   the core created last.
     * - A TLS test dials through the "fragment" outbound (its dialerProxy).
     *   The core looks that tag up in the process-wide manager on every
     *   dial, retries included, so it finds the newest test's splitter and
     *   not its own.
     * - Before 2026-10-12 a Reality test's core had no splitter. A TLS test
     *   that dialled after one was created failed with "io: read/write on
     *   closed pipe", which the app read as a closed door, usually "no
     *   answer in 3000 ms".
     * - Tests run side by side: the sweep checks up to 12 doors at once, and
     *   the checklist and the shared fallback check several at once.
     *
     * On 2026-10-12, with the pinned core (xray-core 5ca6f4b7d4dc), a TLS
     * test whose first two hellos were reset passed alone. It failed in 4 of
     * 4 runs when a Reality test without a splitter started 100 ms after it,
     * and passed in 4 of 4 runs when that Reality test's config had this
     * splitter.
     *
     * On a phone whose own TLS doors carry a split of their own (a door
     * experiment's test arm, or a promoted split), the app sends that split
     * as [splitter] in place of its own (TlsFragment.doorSpec in the app).
     * Before, every core beside such a door's test held the app's split, and
     * the door's retries dialled with it. On 2026-10-12, with a filter that
     * reset any first segment over 100 bytes, a door whose own split was
     * 200-400 read open in 5 of 5 runs beside a Reality test carrying the
     * app's 10-20 split. Its tunnel dials with 200-400 and was reset. Beside
     * a Reality test carrying the door's own split it read closed in 5 of 5,
     * as it did alone.
     *
     * Two cases are still open. A link whose split differs from [splitter]
     * puts its split into its own core's splitter, so a TLS test beside it
     * can dial with that split instead of its own. Such links are a test
     * point's variants, and, on a phone whose doors carry their own split,
     * a shared TLS link, which is given the app's split. With the app's
     * split off and no split in the phone's own doors, only links that name
     * a split get a splitter, so one of them can still fail beside a
     * Reality test.
     */
    fun config(
        outbound: OutboundBean,
        fragment: TlsFragment.Spec?,
        splitter: TlsFragment.Spec?,
    ): String {
        outbound.tag = "proxy"
        outbound.mux = null
        val outbounds = mutableListOf(outbound)
        // The link's own split first, so a test that runs alone dials with
        // it; then the app's, which adds nothing when the link's is there.
        fragment?.let { TlsFragment.apply(outbounds, it) }
        splitter?.let { TlsFragment.addSplitter(outbounds, it) }
        val config = mapOf(
            "outbounds" to outbounds,
            "log" to mapOf("loglevel" to "none"),
        )
        return JsonUtil.toJsonPretty(config) ?: "{}"
    }

    /**
     * [link] without its credential, for the log.
     *
     * A vless, trojan or ss link carries the credential before the '@', and
     * what is after it (host, port, transport) is what a reader of the log
     * needs. Release builds keep debug lines, and the tail of the log goes
     * up with every failure report, so a link written whole puts the
     * credential in both. Until 2026-10-02 two lines did that. A link with
     * no '@', such as vmess, has its credential inside the encoded body, so
     * none of the body is written.
     */
    fun redact(link: String): String {
        val body = link.substringBefore('#')
        val scheme = body.indexOf("://")
        val head = if (scheme >= 0) body.substring(0, scheme + 3) else ""
        val at = body.indexOf('@')
        if (at < 0) return head + "***"
        return head + "***@" + body.substring(at + 1).take(120)
    }
}
