package com.vpn.fortivavpn

/**
 * Whether MainActivity shows the VPN consent dialog once more, after it
 * closed itself.
 *
 * A dialog answered within [silentCancelMs] was never on screen: the
 * system closed it before the user could see it. Up to 2.3.0 that ended
 * the tap with PERMISSION_BLOCKED, and the tap was not tried again. In the
 * week to 2026-10-27 that was 7 taps on 3 phones, and 4 of them connected
 * on the user's next tap within 2 minutes, which showed the dialog again.
 * So the app now asks once more by itself, at most once for each connect
 * request. A tap sends one request that may open the dialog (take_slot),
 * so that is at most once for each tap.
 *
 * Not again when another app holds the always-on VPN slot: the system
 * closes the dialog on sight while it does, so a second showing would
 * close the same way.
 */
object ConsentAgain {
    /**
     * True to ask once more. [elapsedMs] is how long the dialog was open,
     * [shownAgain] whether this was already the second showing for its
     * request, [alwaysOnOwner] the app that holds the always-on slot, if
     * another one does, and [hasStart] whether the request's link or
     * backup network start is still at hand.
     */
    fun shouldAsk(
        elapsedMs: Long,
        silentCancelMs: Long,
        shownAgain: Boolean,
        alwaysOnOwner: String?,
        hasStart: Boolean,
    ): Boolean =
        elapsedMs in 0 until silentCancelMs &&
            !shownAgain &&
            alwaysOnOwner == null &&
            hasStart
}
