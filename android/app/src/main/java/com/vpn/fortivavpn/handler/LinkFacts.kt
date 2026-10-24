package com.vpn.fortivavpn.handler

/**
 * The words a door-check row uses for what the phone's network says about
 * itself (MainActivity.linkFacts). Kept apart from the Android calls so the
 * mapping can be tested without a device.
 */
object LinkFacts {

    /**
     * "wifi", "cellular", "ethernet" or "other", in that order when the
     * network says several.
     */
    fun transport(wifi: Boolean, cellular: Boolean, ethernet: Boolean): String = when {
        wifi -> "wifi"
        cellular -> "cellular"
        ethernet -> "ethernet"
        else -> "other"
    }

    /** The MTU the link reports, or null when it reports none (0). */
    fun mtu(value: Int): Int? = value.takeIf { it > 0 }

    /**
     * The Private DNS mode as the link has it: "strict" when it names a
     * provider, "opportunistic" when DNS over TLS is on without one, "off"
     * otherwise. "off" also covers the automatic setting on a network whose
     * resolver does not speak DNS over TLS: the phone's lookups then go out
     * in the clear, which is what the row is for.
     */
    fun privateDnsMode(active: Boolean, serverName: String?): String = when {
        !serverName.isNullOrBlank() -> "strict"
        active -> "opportunistic"
        else -> "off"
    }
}
