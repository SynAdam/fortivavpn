package com.vpn.fortivavpn.service

import android.util.Log
import com.vpn.fortivavpn.AppConfig
import com.vpn.fortivavpn.dto.ConfigResult

/**
 * The configs the tunnel starts its core with, in this order
 * (V2RayServiceManager.startCoreLoop):
 *
 * 1. The config as built: the door group when the app sent standby doors,
 *    the one door otherwise, each door with the backend's outbound when the
 *    last connect gave it one (handler/DoorOutbounds.kt).
 * 2. When the core will not start with it and it dials a door with the
 *    backend's outbound: the same doors built again from their links.
 * 3. When a door group still does not start: the one door, from its link.
 *
 * The backend's outbounds and the door group are both newer than the one
 * door's link, so neither may cost the user the connection the link gives.
 */
object CoreStart {
    /** The config the core started with, and whether it is the door group. */
    class Started(val result: ConfigResult, val grouped: Boolean)

    /**
     * The first config [run] starts, in the order above, or null when none
     * does. [first] is the config as built, and [grouped] whether it is the
     * door group. [fromLinks] builds the doors from their links alone: the
     * group when given true, the one door when given false.
     */
    fun firstThatStarts(
        first: ConfigResult,
        grouped: Boolean,
        run: (String) -> Boolean,
        fromLinks: (grouped: Boolean) -> ConfigResult,
    ): Started? {
        var result = first
        var group = grouped
        var started = run(result.content)
        if (!started && result.doorOutbounds) {
            Log.w(AppConfig.TAG, "[core] the backend's door outbounds did not start; connecting through the links")
            result = fromLinks(group)
            started = result.status && run(result.content)
        }
        if (!started && group) {
            // A group that did not start with the backend's outbounds was
            // tried without them above, so the one door goes from its link.
            Log.w(AppConfig.TAG, "[core] the door group did not start; connecting through one door")
            group = false
            result = fromLinks(false)
            started = result.status && run(result.content)
        }
        return if (started) Started(result, group) else null
    }
}
