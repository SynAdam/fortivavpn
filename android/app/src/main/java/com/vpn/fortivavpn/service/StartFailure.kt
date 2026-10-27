package com.vpn.fortivavpn.service

/**
 * Why a tunnel start failed: the message V2RayVpnService sends with
 * MSG_STATE_START_FAILURE, as "<step>:<reason>".
 *
 * The app gets it as "failed:<step>:<reason>" (MainActivity.withReason) and
 * files the two words in the connect_failed row's diag as native_step and
 * native_reason. The error text of the row does not change. Up to 2.3.0
 * every failed start but one sent an empty message, so all of them reached
 * the backend as "The tunnel did not start" and the cause stayed in the
 * phone's log: in the week to 2026-10-27 that was about 1,168 taps through
 * the backup network and 45 taps on our doors.
 *
 * Only the fixed words below are ever sent. Never an error's text, an
 * address, a host name or a port: a core error is turned into one word by
 * [coreError] first.
 *
 * A start that found another VPN app holding the slot still sends
 * VpnSlot.SLOT_TAKEN alone, because the app ends its search on that word.
 */
object StartFailure {
    // The step of V2RayVpnService.start that failed, in the order they run.

    /** onStartCommand: a tap's start found the VPN consent gone. */
    const val STEP_CONSENT = "consent"

    /** The backup network's profile and session, before the core. */
    const val STEP_SESSION = "session"

    /** The core (V2RayServiceManager.startCore). */
    const val STEP_CORE = "core"

    /** The backup network's own start and its wait for a tunnel. */
    const val STEP_PSIPHON = "psiphon"

    /** The VPN interface (establish). */
    const val STEP_INTERFACE = "interface"

    /** tun2socks and the hand-over of the interface to it. */
    const val STEP_TUN2SOCKS = "tun2socks"

    /** After tun2socks: the backup network ended before the start finished. */
    const val STEP_FINISH = "finish"

    // Reasons. The backup network steps send PsiphonFailure.word as theirs.

    /** prepare() asked for consent in the service. */
    const val NOT_PREPARED = "not_prepared"

    /** A backup network profile is selected but its session is gone. */
    const val ORPHAN_PROFILE = "orphan_profile"

    /** The backup network session could not be prepared. */
    const val SESSION_ERROR = "session_error"

    /** The core was still running from an earlier start. */
    const val ALREADY_RUNNING = "already_running"

    /** No service to start the core in. */
    const val NO_SERVICE = "no_service"

    /** No door selected. */
    const val NO_SERVER = "no_server"

    /** The selected door's stored profile could not be read. */
    const val BAD_PROFILE = "bad_profile"

    /** No config could be built from the door. */
    const val BUILD_FAILED = "build_failed"

    /** The receiver that hears a stop could not be registered. */
    const val RECEIVER = "receiver"

    /** libv2ray "config error:". */
    const val CONFIG_ERROR = "config_error"

    /** libv2ray "core init failed:". */
    const val INIT_FAILED = "init_failed"

    /** libv2ray "startup failed:", other than a port in use. */
    const val STARTUP_FAILED = "startup_failed"

    /** A local port the core listens on is held by another app. */
    const val PORT_IN_USE = "port_in_use"

    /** The core's start returned, but the core is not running. */
    const val NOT_RUNNING = "not_running"

    /** Any other error from the core's start. */
    const val START_ERROR = "start_error"

    /** The notification or the plugin failed after the core started. */
    const val POST_START = "post_start"

    /** establish() threw. */
    const val ESTABLISH_ERROR = "establish_error"

    /** The tun2socks process did not start. */
    const val PROCESS_ERROR = "process_error"

    /** The interface could not be handed to tun2socks. */
    const val FD_NOT_SENT = "fd_not_sent"

    /** The message for a start that failed at [step] for [reason]. */
    fun message(step: String, reason: String): String = "$step:$reason"

    /**
     * One word for an error the core's start threw, by libv2ray's own
     * prefixes (libv2ray_main.go: "config error:", "core init failed:",
     * "startup failed:"). A port held by another app is a "startup failed"
     * that ends in "address already in use". It is told apart because it
     * fails every start on the phone, door after door, until that app lets
     * go of the port. Anything else is [START_ERROR].
     */
    fun coreError(message: String?): String {
        val text = message.orEmpty().lowercase()
        return when {
            "address already in use" in text -> PORT_IN_USE
            text.contains("config error:") -> CONFIG_ERROR
            text.contains("core init failed:") -> INIT_FAILED
            text.contains("startup failed:") -> STARTUP_FAILED
            else -> START_ERROR
        }
    }
}
