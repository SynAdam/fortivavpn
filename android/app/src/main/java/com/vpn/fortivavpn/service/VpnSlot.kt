package com.vpn.fortivavpn.service

import android.app.AppOpsManager
import android.content.Context
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.os.Build
import android.os.Process

/**
 * The phone's one VPN slot, and who may take it.
 *
 * Android runs one VPN at a time. VpnService.prepare() reads like a
 * permission check, but for an app the user has approved once it is not a
 * question: Android makes that app the VPN again on the spot and tears down
 * the VPN of whichever app had the slot (AOSP Vpn.prepare, which calls
 * prepareInternal). Up to 2.2.0 the app called it with nobody asking: in
 * onRevoke, for the vpn_permission field of every report, and on every
 * start, retries and Android's own restarts included. A user who turned on
 * Psiphon or NPV Tunnel had it torn down within seconds, with Fortiva off
 * (reproduced on Android 14 and 16 on 2026-10-21). Fortiva users on Samsung
 * reported it the same day.
 *
 * Now only a start the user asked for with a tap calls prepare(): the
 * connect button, a pick, the quick settings tile and the widget send
 * [EXTRA_TAKE_SLOT]. Every other start lets Builder.establish() decide. It
 * gives an interface while no other app has taken the slot since this one
 * last held it, and otherwise returns null and changes nothing
 * ([SLOT_TAKEN]). So the app's own restarts and retries still work when no
 * other VPN is involved, and a user's switch to another VPN app stands.
 */
object VpnSlot {
    /**
     * Intent extra, true when a tap started this start, which may then take
     * the slot from another app. Absent on Android's own starts: a restart
     * after the tunnel's process was killed (a null intent) and always-on.
     */
    const val EXTRA_TAKE_SLOT = "take_slot"

    /**
     * Why a start failed, as the app hears it ("failed:slot_taken"):
     * another app holds the slot and nobody tapped. Not a failure of the
     * door, and nothing to try again.
     */
    const val SLOT_TAKEN = "slot_taken"

    /** The app op Android records the user's VPN consent under. */
    private const val OP_ACTIVATE_VPN = "android:activate_vpn"

    /**
     * Owner uid of a VPN network whose owner Android does not name: every
     * VPN before Android 11, where NetworkCapabilities has no owner to read.
     */
    const val OWNER_UNKNOWN = Int.MIN_VALUE

    /**
     * Whether this app's own VPN is up, from [activeIsVpn] (the default
     * network this app's own traffic takes is a VPN) and [owners] (the
     * owner uid of each VPN network, [OWNER_UNKNOWN] where unknown).
     *
     * From Android 11 Android names a VPN's owner only to that owner, and
     * every other app reads -1, so the owner says it. Before Android 11 no
     * owner is named, and a VPN that this app's own traffic does not go
     * through is taken for its own: this app always leaves itself out of its
     * own tunnel, and another app's VPN carries it unless it leaves it out.
     */
    fun ownUp(activeIsVpn: Boolean, owners: List<Int>, myUid: Int): Boolean =
        owners.any { it == myUid } || (owners.any { it == OWNER_UNKNOWN } && !activeIsVpn)

    /**
     * Whether another app's VPN is up in this Android user: one carries this
     * app's own traffic, and this app always leaves itself out of its own
     * tunnel. False when the platform will not say.
     *
     * Not the VPN owners: a VPN in a work profile, Secure Folder or Private
     * Space also lists with an owner that is not this app's, and it holds
     * that user's slot, not this one. Counted, it ended every wait to try
     * again on such a phone. A VPN that leaves this app out is not seen
     * either; a start without a tap still gets no tunnel past it.
     */
    fun otherUp(context: Context): Boolean = read(context)?.first ?: false

    /**
     * How many VPN networks are not this app's: a VPN that leaves this app
     * out, and one in another Android user, count too, which [otherUp]
     * cannot see. Before Android 11 no owner is named and every VPN counts,
     * this app's own included. Null when the platform will not say.
     *
     * For the one question [otherUp] cannot answer: whether a VPN came up
     * since the user tapped, so the tap's take of the slot is no longer
     * the user's wish (ConnectFlow._tapMayTakeSlot).
     */
    fun othersCount(context: Context): Int? =
        read(context)?.second?.count { it != Process.myUid() }

    /** [ownUp] on this phone, now. False when the platform will not say. */
    fun ownUp(context: Context): Boolean =
        read(context)?.let { (active, owners) -> ownUp(active, owners, Process.myUid()) } ?: false

    /**
     * Whether the user's VPN consent for this app is on record, read from
     * the app op Android keeps it in rather than with prepare(), which
     * would take the slot. Null when the platform will not say.
     */
    fun consentOnRecord(context: Context): Boolean? =
        try {
            val ops = context.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
            val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                ops.unsafeCheckOpNoThrow(OP_ACTIVATE_VPN, Process.myUid(), context.packageName)
            } else {
                @Suppress("DEPRECATION")
                ops.checkOpNoThrow(OP_ACTIVATE_VPN, Process.myUid(), context.packageName)
            }
            mode == AppOpsManager.MODE_ALLOWED
        } catch (_: Throwable) {
            // An unknown op name throws IllegalArgumentException, and a
            // method an old Android lacks throws an Error, not an Exception.
            null
        }

    /** Whether the default network is a VPN, and the owner of each VPN network. */
    private fun read(context: Context): Pair<Boolean, List<Int>>? =
        try {
            val cm = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
            val active = cm.activeNetwork?.let { cm.getNetworkCapabilities(it) }
                ?.hasTransport(NetworkCapabilities.TRANSPORT_VPN) == true
            @Suppress("DEPRECATION")
            val owners = cm.allNetworks.mapNotNull { network ->
                val caps = cm.getNetworkCapabilities(network) ?: return@mapNotNull null
                if (!caps.hasTransport(NetworkCapabilities.TRANSPORT_VPN)) return@mapNotNull null
                // getOwnerUid() is Android 11's (API 30). On Android 10 the
                // call throws NoSuchMethodError.
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) caps.ownerUid else OWNER_UNKNOWN
            }
            active to owners
        } catch (_: Throwable) {
            null
        }
}
