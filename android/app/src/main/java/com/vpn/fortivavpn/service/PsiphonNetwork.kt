package com.vpn.fortivavpn.service

import java.net.Inet6Address
import java.net.InetAddress

/**
 * What the backup network's library is told about the phone's network.
 * Kept apart from the Android calls so it can be tested without a device.
 */
object PsiphonNetwork {
    const val WIFI = "WIFI"
    const val MOBILE = "MOBILE"
    const val WIRED = "WIRED"
    const val UNKNOWN = "UNKNOWN"

    /**
     * The network's kind, and nothing more. The library sends the part
     * before the first "-" to its servers and keys its memory of what
     * worked by the whole value. Psiphon's own Android library adds the
     * Wi-Fi BSSID or the mobile operator's code after a "-". Neither is
     * added here: the first needs a permission this app does not hold, and
     * neither is something this app sends anywhere.
     *
     * Wi-Fi first, as LinkFacts.transport orders it.
     */
    fun idWord(wifi: Boolean, cellular: Boolean, ethernet: Boolean): String = when {
        wifi -> WIFI
        cellular -> MOBILE
        ethernet -> WIRED
        else -> UNKNOWN
    }

    /**
     * [servers] as the library wants them: comma-separated, without
     * wildcard, multicast and IPv4 link-local addresses, an IPv6 link-local
     * address with its interface after a "%", and each one once. An IPv6
     * link-local address with no interface to name is left out. Empty when
     * none is left, which the library allows: it then uses resolvers from
     * its own config.
     */
    fun dnsServers(servers: List<InetAddress>, interfaceName: String?): String {
        val out = LinkedHashSet<String>()
        for (server in servers) {
            if (server.isAnyLocalAddress || server.isMulticastAddress) continue
            var text = server.hostAddress ?: continue
            if (server.isLinkLocalAddress) {
                if (server !is Inet6Address) continue
                if (!text.contains('%')) {
                    if (interfaceName.isNullOrBlank()) continue
                    text = "$text%$interfaceName"
                }
            }
            out.add(text)
        }
        return out.joinToString(",")
    }

    /** Whether [address] is a global IPv6 address (2000::/3). */
    fun isGlobalIpv6(address: InetAddress): Boolean =
        address is Inet6Address && (address.address[0].toInt() and 0xE0) == 0x20

    /**
     * Whether the network under the tunnel moved from [previous] to
     * [current]. The first network the service hears of is where the
     * library already connected, so that one is no move.
     */
    fun moved(previous: Any?, current: Any): Boolean = previous != null && previous != current
}
