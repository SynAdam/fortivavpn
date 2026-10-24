package com.vpn.fortivavpn.handler

import android.net.ConnectivityManager
import android.net.LinkProperties
import android.net.NetworkCapabilities
import android.net.wifi.WifiInfo
import android.os.Build
import java.net.Inet4Address
import java.net.Inet6Address
import java.net.InetAddress
import javax.crypto.Mac
import javax.crypto.spec.SecretKeySpec

/**
 * A key for the Wi-Fi network the phone is on, made on the phone from what
 * Android gives without the location permission (backend issue #365,
 * items 3, 4 and 9).
 *
 * Android shows an app the Wi-Fi's name and access point only with the
 * location permission, which the app does not have and does not ask for.
 * Without it, the network's link properties still tell one network from
 * another: the DNS servers it hands out, its gateways (the router's private
 * IPv4 address and its IPv6 link-local address), the DHCP server, the MTU,
 * the search domains, and from Android 12 the security type. The Wi-Fi
 * standard is left out: it is the radio link's, so one dual-band router would
 * give two keys. They are read from the phone's own network: the app is left
 * out of its own tunnel, so the active network is the Wi-Fi even while the
 * VPN is up.
 *
 * None of that leaves the phone. It is put in one canonical string and
 * hashed with HMAC-SHA256 under a random salt the app keeps per install, so
 * the same network gives a different key on another phone, and no key can
 * be turned back into an address. Two keys are made:
 *
 * - [Keys.local], for the phone's own memory: the same for as long as the
 *   salt is kept.
 * - [Keys.shared], to send to the backend: it changes every period the
 *   backend sets, at a moment of the period that differs per install, so
 *   the backend can tell networks apart within one period only.
 *
 * The phone's own addresses on the network (LinkProperties.linkAddresses,
 * which hold the user's IPv6 prefix) are never read. Many home routers
 * share the same defaults, so two homes can give one key; that is the price
 * of not asking for location.
 */
object NetworkKey {

    /** A version word in the hashed string, so a change of inputs is a new
     * key rather than a key that silently means something else. */
    private const val VERSION = "v2"

    /** Hex characters of a key: 64 bits. */
    private const val KEY_CHARS = 16

    data class Keys(val local: String, val shared: String?)

    /** The keys for the active network when it is a Wi-Fi network, or null
     * (another transport, a VPN of another app, or nothing to tell it by). */
    fun keysOf(cm: ConnectivityManager, salt: ByteArray, periodSeconds: Long, nowSeconds: Long): Keys? {
        val inputs = wifiInputs(cm) ?: return null
        return keysFor(inputs, salt, periodSeconds, nowSeconds)
    }

    /** The keys for a canonical [inputs] string: see the class comment. */
    fun keysFor(inputs: String, salt: ByteArray, periodSeconds: Long, nowSeconds: Long): Keys {
        val local = hmac(salt, "local|$inputs").take(KEY_CHARS)
        if (periodSeconds <= 0) return Keys(local, null)
        // Each install starts its periods at its own offset, so not every
        // phone's key changes at the same moment.
        val offset = java.lang.Long.parseUnsignedLong(hmac(salt, "offset").take(12), 16) % periodSeconds
        val period = Math.floorDiv(nowSeconds + offset, periodSeconds)
        val shared = hmac(salt, "shared|$period|$inputs").take(KEY_CHARS)
        return Keys(local, shared)
    }

    /** The active Wi-Fi network's inputs as one canonical string, or null. */
    fun wifiInputs(cm: ConnectivityManager): String? {
        val network = cm.activeNetwork ?: return null
        val caps = cm.getNetworkCapabilities(network) ?: return null
        if (caps.hasTransport(NetworkCapabilities.TRANSPORT_VPN)) return null
        if (!caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI)) return null
        val lp = cm.getLinkProperties(network) ?: return null
        var security: Int? = null
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            security = (caps.transportInfo as? WifiInfo)?.currentSecurityType
        }
        return canonical(
            dns = lp.dnsServers.mapNotNull { hostOf(it) },
            gateways = gatewaysOf(lp),
            dhcp = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                lp.dhcpServerAddress?.let { hostOf(it) }
            } else {
                null
            },
            mtu = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) lp.mtu else 0,
            domains = lp.domains,
            security = security,
        )
    }

    /**
     * The inputs in one fixed order and form, or null when there is too
     * little to tell a network by (no gateway and no DNS server). Lists are
     * sorted, so the order Android lists them in does not change the key.
     */
    fun canonical(
        dns: List<String>,
        gateways: List<String>,
        dhcp: String?,
        mtu: Int,
        domains: String?,
        security: Int?,
    ): String? {
        val dnsSorted = dns.filter { it.isNotBlank() }.map { it.lowercase() }.toSortedSet()
        val gwSorted = gateways.filter { it.isNotBlank() }.map { it.lowercase() }.toSortedSet()
        if (dnsSorted.isEmpty() && gwSorted.isEmpty()) return null
        val domainList = domains.orEmpty().split(' ', ',').map { it.trim().lowercase() }
            .filter { it.isNotEmpty() }.toSortedSet()
        return listOf(
            VERSION,
            "dns=" + dnsSorted.joinToString(","),
            "gw=" + gwSorted.joinToString(","),
            "dhcp=" + (dhcp?.lowercase() ?: ""),
            "mtu=" + (if (mtu > 0) mtu.toString() else ""),
            "dom=" + domainList.joinToString(","),
            "sec=" + (security?.toString() ?: ""),
        ).joinToString("|")
    }

    /** The gateways of the default routes, IPv4 and IPv6. */
    private fun gatewaysOf(lp: LinkProperties): List<String> =
        lp.routes.filter { it.isDefaultRoute }.mapNotNull { route ->
            val gw = route.gateway ?: return@mapNotNull null
            if (gw.isAnyLocalAddress) null else hostOf(gw)
        }

    /** An address as text without the IPv6 scope ("%wlan0"), which names the
     * phone's interface rather than the network. */
    private fun hostOf(address: InetAddress): String? = when (address) {
        is Inet4Address -> address.hostAddress
        is Inet6Address -> address.hostAddress?.substringBefore('%')
        else -> null
    }

    fun hmac(key: ByteArray, message: String): String {
        val mac = Mac.getInstance("HmacSHA256")
        mac.init(SecretKeySpec(key, "HmacSHA256"))
        return mac.doFinal(message.toByteArray(Charsets.UTF_8)).joinToString("") {
            "%02x".format(it)
        }
    }
}
