package com.vpn.fortivavpn.dto

data class ConfigResult(
    var status: Boolean,
    var guid: String? = null,
    var content: String = "",
    var socksPort: Int? = null,
    // Whether the content dials a door with the backend's outbound
    // (handler/DoorOutbounds.kt).
    var doorOutbounds: Boolean = false,
)

