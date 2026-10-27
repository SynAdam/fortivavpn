package com.vpn.fortivavpn.handler

import android.content.Context
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.os.Build
import android.telephony.TelephonyManager
import android.util.Log
import com.vpn.fortivavpn.AppConfig
import java.net.HttpURLConnection
import java.net.InetSocketAddress
import java.net.Proxy
import java.net.URL

/**
 * What the app's main process can learn about the tunnel and the phone's
 * network, shared by the app's engine (MainActivity) and the keeper's
 * (KeeperJobService), which runs when the app's engine is gone.
 */
object TunnelProbe {
    private const val TAG = AppConfig.TAG

    /** The check page the tunnel must carry. A 204, or a 200 from a proxy. */
    private const val CHECK_URL = "http://connectivitycheck.gstatic.com/generate_204"
    private const val CHECK_TIMEOUT_MS = 5000

    /**
     * The carrier and transport, as the two system services report them,
     * and whether the user pays by the megabyte.
     */
    fun networkFacts(context: Context): Map<String, Any?> {
        val out = HashMap<String, Any?>()
        try {
            val tm = context.getSystemService(Context.TELEPHONY_SERVICE) as TelephonyManager
            out["carrier"] = tm.networkOperatorName?.takeIf { it.isNotBlank() }
        } catch (_: Exception) {}
        try {
            val cm = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
            val caps = cm.activeNetwork?.let { cm.getNetworkCapabilities(it) }
            out["network"] = when {
                caps == null -> "none"
                caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) -> "wifi"
                caps.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) -> "mobile"
                caps.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET) -> "ethernet"
                else -> "other"
            }
            out["metered"] = cm.isActiveNetworkMetered
        } catch (_: Exception) {}
        return out
    }

    /**
     * Whether a request through the tunnel's SOCKS port gets an answer.
     * Blocking: call off the main thread.
     */
    fun tunnelCarries(): Boolean =
        try {
            val socksPort = SettingsManager.getSocksPort()
            val proxy = Proxy(Proxy.Type.SOCKS, InetSocketAddress("127.0.0.1", socksPort))
            val conn = URL(CHECK_URL).openConnection(proxy) as HttpURLConnection
            conn.connectTimeout = CHECK_TIMEOUT_MS
            conn.readTimeout = CHECK_TIMEOUT_MS
            conn.instanceFollowRedirects = false
            conn.useCaches = false
            val code = conn.responseCode
            conn.disconnect()
            Log.d(TAG, "SOCKS test result: HTTP $code (via port $socksPort)")
            code == 204 || code == 200
        } catch (e: Exception) {
            Log.e(TAG, "SOCKS test failed: ${e.message}")
            false
        }

    /**
     * The VPN network up on this phone, as text, or null. Android makes a
     * new network for each start of a tunnel, so this tells one start from
     * the next, which the app's attempt cannot: a tunnel started again from
     * the quick settings tile keeps it. The keeper marks a dead tunnel with
     * it (lib/services/keeper.dart).
     */
    fun vpnId(context: Context): String? =
        try {
            val cm = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
            cm.allNetworks.firstOrNull { network ->
                cm.getNetworkCapabilities(network)?.hasTransport(NetworkCapabilities.TRANSPORT_VPN) == true
            }?.let { network ->
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    network.networkHandle.toString()
                } else {
                    network.toString()
                }
            }
        } catch (_: Exception) {
            null
        }

    /** Whether a VPN is up on this phone, seen from any process. */
    fun vpnUp(context: Context): Boolean =
        try {
            val cm = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
            cm.allNetworks.any { network ->
                cm.getNetworkCapabilities(network)?.hasTransport(NetworkCapabilities.TRANSPORT_VPN) == true
            }
        } catch (_: Exception) {
            false
        }
}
