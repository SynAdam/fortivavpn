package com.vpn.fortivavpn.handler

import com.vpn.fortivavpn.AppConfig

/**
 * Takes every line that names a site or an address out of the technical log
 * before the log leaves the phone.
 *
 * The log sent with a connection report is the last lines the VPN core and
 * this app wrote to logcat (MainActivity.coreLogTail). The core writes
 * several lines for each connection, and most of them name where the
 * connection went: "sniffed domain: <host>", the access log line ("from ...
 * accepted tcp:<host>:443"), "TCP Connect request to tcp:<ip>:443",
 * "default route for tcp:<host>:443", "tunneling request to tcp:<host>:443",
 * "dialing TCP to", "connection opened to", and the DNS lines ("returning
 * N IP(s) for domain <host>", "got answer: <host>"). The tun2socks lines this
 * app copies into its own log carry addresses too.
 *
 * The core keeps writing these lines, because SiteStats reads the sniffed
 * names on the phone for the daily site counts. So the lines are taken out
 * here, at the one place the log is read for upload. The Dart side runs the
 * same rules again before it sends (lib/services/log_privacy.dart), and both
 * read the sample lines in test/fixtures/log_privacy_lines.txt.
 *
 * A line is left out when its message has a phrase from [DESTINATION_PHRASES]
 * or holds a host name, an IPv4 address or an IPv6 address. Loopback
 * addresses and this app's own package name do not count. The rule leaves
 * out lines about our own servers too, because a line cannot say which
 * server it is about. One line at the end says how many lines were left
 * out, how many of them named Iran's 10.10.34.x sinkhole and how many used
 * port 853, so those two findings can still be read without the lines.
 */
object LogPrivacy {
    /**
     * Phrases of the lines that name a connection's destination or a DNS
     * name. A line with one of these is left out even when its host has a
     * form the address patterns below do not catch. Lower case.
     */
    private val DESTINATION_PHRASES = listOf(
        // The core's own line for each connection's site name.
        "sniffed domain",
        "fake dns",
        "fake ip",
        // Routing: "taking detour [proxy] for [tcp:<host>:443]".
        "detour",
        "default route for",
        // The access log: "from tcp:127.0.0.1:5000 accepted tcp:<host>:443".
        "accepted",
        // Inbound and outbound requests and UDP packets.
        "request to",
        "redirecting request",
        "tunneling request",
        "send packet to",
        "writing back udp response",
        "udp connection from",
        "establishing new connection for",
        "replace destination",
        // Dials, which name our servers or, on the direct route, the site.
        "dialing",
        "downloading from",
        "creating connection to",
        "failed to dial",
        "connection opened to",
        "open connection to",
        // DNS.
        "app/dns",
        "proxy/dns",
        "got answer",
        "querying",
        "for domain",
        "domain replaced",
        "resolved to",
        "resolve ip for",
        "lookup",
        "ech config",
        // This app's lines that named another app before 1.6.21. A phone
        // that updated keeps them in its log buffer for a while.
        "always-on vpn held by",
        "failed to configure app in vpn",
    )

    /** `logcat -v time`: "10-07 09:16:12.345 I/GoLog   ( 4242): message". */
    private val LOGCAT_HEADER = Regex("""^\d\d-\d\d \d\d:\d\d:\d\d\.\d+ [VDIWEFA]/[^(]*\(\s*\d+\): ?""")

    private const val LABEL = """[\p{L}\p{N}](?:[\p{L}\p{N}]|-+[\p{L}\p{N}])*"""

    /** The last label starts with a letter and has two or more characters. */
    private const val TOP_LABEL = """\p{L}(?:[\p{L}\p{N}]|-+[\p{L}\p{N}])+"""

    private val HOST_NAME = Regex("""(?:$LABEL\.)+$TOP_LABEL""")
    private val IPV4 = Regex("""\b(?:\d{1,3}\.){3}\d{1,3}\b""")

    /** Five groups or more, so a clock time such as 12:34:56 never matches. */
    private val IPV6_FULL = Regex("""(?i)(?:[0-9a-f]{1,4}:){4,7}[0-9a-f]{1,4}""")
    private val IPV6_SHORT = Regex("""(?i)(?:[0-9a-f]{1,4}(?::[0-9a-f]{1,4}){0,6})?::(?:[0-9a-f]{1,4}(?::[0-9a-f]{1,4}){0,6})?""")

    private val SINKHOLE = Regex("""(?i)\b10\.10\.34\.\d{1,3}\b|\b2001:4188:2:600:10:10:34:[0-9a-f]{1,4}\b""")
    private val PORT_853 = Regex(""":853\b""")

    /** Whether one log line names a site or an address. */
    fun namesDestination(line: String): Boolean {
        val message = LOGCAT_HEADER.find(line)?.let { line.substring(it.range.last + 1) } ?: line
        val lower = message.lowercase()
        if (DESTINATION_PHRASES.any { lower.contains(it) }) return true
        if (HOST_NAME.findAll(message).any { !isOwnName(it.value) }) return true
        if (IPV4.findAll(message).any { !it.value.startsWith("127.") }) return true
        if (IPV6_FULL.containsMatchIn(message)) return true
        return IPV6_SHORT.findAll(message).any { it.value != "::1" }
    }

    private fun isOwnName(host: String) = host.equals(AppConfig.ANG_PACKAGE, ignoreCase = true)

    /**
     * [log] without the lines that name a site or an address, and with one
     * line at the end that says how many were left out. Returns [log]
     * unchanged when no line was left out.
     */
    fun scrub(log: String): String {
        var removed = 0
        var sinkhole = 0
        var dot = 0
        val kept = mutableListOf<String>()
        for (line in log.split('\n')) {
            if (!namesDestination(line)) {
                kept.add(line)
                continue
            }
            removed++
            if (SINKHOLE.containsMatchIn(line)) sinkhole++
            if (PORT_853.containsMatchIn(line)) dot++
        }
        if (removed == 0) return log
        // logcat ends its output with a newline, which leaves an empty last
        // line. The summary goes straight after the last real line.
        while (kept.isNotEmpty() && kept.last().isBlank()) kept.removeAt(kept.size - 1)
        kept.add(summary(removed, sinkhole, dot))
        return kept.joinToString("\n")
    }

    /**
     * The line that replaces what was left out. It names no address: the
     * sinkhole is written as 10.10.34.x, which the address patterns do not
     * match, so the Dart side keeps the line, and a search of the stored
     * reports for "10.10.34." still finds the phones that met the sinkhole.
     */
    internal fun summary(removed: Int, sinkhole: Int, dot: Int): String {
        val head = if (removed == 1) {
            "[privacy] 1 line that names a site or an address was left out."
        } else {
            "[privacy] $removed lines that name a site or an address were left out."
        }
        val notes = buildList {
            if (sinkhole > 0) add("$sinkhole named a 10.10.34.x sinkhole address")
            if (dot > 0) add("$dot used port 853")
        }
        return if (notes.isEmpty()) head else "$head Of these, ${notes.joinToString(" and ")}."
    }
}
