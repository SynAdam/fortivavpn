package com.vpn.fortivavpn.service

import android.content.Context
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.util.Log
import com.vpn.fortivavpn.AppConfig
import com.vpn.fortivavpn.BuildConfig
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.delay
import kotlinx.coroutines.withTimeoutOrNull
import fortivacore.Fortivacore
import psi.Psi
import psi.PsiphonProvider
import java.io.File
import java.net.Inet6Address
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicInteger

/**
 * The backup network: Psiphon's tunnel core, run in the tunnel's process
 * for a backup network session (PsiphonSession).
 *
 * The library listens as a SOCKS proxy on 127.0.0.1 and the core's `proxy`
 * outbound points at it, so tun2socks, the routing rules, the counters and
 * port 10808 work as they do for any door. See V2RayVpnService.start for
 * the order of the steps.
 *
 * This is the host the library calls back into (psi.PsiphonProvider),
 * written here instead of using Psiphon's PsiphonTunnel.java: that class
 * wants ACCESS_WIFI_STATE and calls a hidden Android API. Sockets are not
 * bound to the network (useDeviceBinder false): this app is left out of its
 * own VPN, so its sockets never enter the tunnel.
 *
 * Psi.start and Psi.stop block. Both run on one thread of their own, in the
 * order they were asked for, so a stop asked for before a start always ends
 * first, and neither ever runs on the main thread.
 *
 * A start handed the server list while the library's store has no servers
 * (its first start on the phone) returns only once every entry of the list
 * is stored, and Psi.stop cannot cut that short: it waits for Psi.start.
 * The stored entries stay, so after a start that was given up on during
 * the read, the next start returns at once.
 */
object PsiphonCore {
    private const val TAG = AppConfig.TAG

    /**
     * How often the wait for the start and the wait for the first tunnel
     * look again.
     */
    private const val POLL_MS = 250L

    private val worker = Executors.newSingleThreadExecutor { r -> Thread(r, "psiphon").apply { isDaemon = true } }
    private val main = Handler(Looper.getMainLooper())

    /**
     * Numbers the runs. A notice from a host of an earlier run is dropped,
     * so nothing an old run said can land on the new one.
     */
    private val run = AtomicInteger()

    /** Whether the library is started. Changed on [worker] only. */
    @Volatile
    private var running = false

    /** Set from the moment a stop is asked for, until the next start. */
    @Volatile
    private var stopping = false

    @Volatile
    private var tunnels = 0

    @Volatile
    private var connectedOnce = false

    @Volatile
    private var failure: PsiphonFailure? = null

    @Volatile
    private var region: String? = null

    @Volatile
    private var upgrade: String? = null

    /**
     * The country of the server the tunnel goes through, two capital
     * letters, once the library has said. Null otherwise.
     */
    fun region(): String? = if (running && !stopping) region else null

    /**
     * The newest client version the network has named in this run
     * (PsiphonNotice.UpgradeAvailable), once it has named one. Null
     * otherwise.
     */
    fun upgrade(): String? = if (running && !stopping) upgrade else null

    /**
     * Starts the library for [session], handing it [entries] as its server
     * list (PsiphonSession.embeddedList, empty for none). True once it
     * runs; it then looks for a tunnel, which [awaitTunnel] waits for.
     * False when it could not start, with the reason kept in [failure] for
     * the log, and false too once [cancelled] says the start was stopped
     * or replaced.
     *
     * Gives up after PsiphonSession.startWaitMs, and looks every 250 ms
     * whether [cancelled]. A start that has not begun by then never
     * begins, and one that is still inside Psi.start stops the library
     * again as soon as it returns.
     */
    suspend fun start(
        context: Context,
        session: PsiphonSession,
        entries: String,
        cancelled: () -> Boolean,
    ): Boolean {
        val waitMs = PsiphonSession.startWaitMs(entries.isNotEmpty(), session.timeoutMs)
        val done = CompletableDeferred<Boolean>()
        worker.execute {
            // Given up on before it began.
            if (done.isCompleted) return@execute
            val started = startNow(context, session, entries)
            // Given up on while it ran: take down what it brought up.
            if (!done.complete(started) && started) stopNow()
        }
        val until = SystemClock.elapsedRealtime() + waitMs
        while (true) {
            val left = until - SystemClock.elapsedRealtime()
            val started = withTimeoutOrNull(left.coerceIn(1L, POLL_MS)) { done.await() }
            if (started != null) return started
            val stopped = cancelled()
            if (!stopped && SystemClock.elapsedRealtime() < until) continue
            // It finished as the wait ended: its answer stands.
            if (!done.complete(false)) return done.await()
            // The caller takes down what the stopped start brought up.
            if (stopped) return false
            Log.e(TAG, "[psiphon] gave up on the start after $waitMs ms")
            fail(PsiphonFailure.START)
            return false
        }
    }

    /** On [worker] only. */
    private fun startNow(context: Context, session: PsiphonSession, entries: String): Boolean {
        if (running) stopNow()
        val id = run.incrementAndGet()
        stopping = false
        tunnels = 0
        connectedOnce = false
        failure = null
        region = null
        upgrade = null

        val dataRoot = File(context.filesDir, "psiphon")
        if (!dataRoot.isDirectory && !dataRoot.mkdirs()) {
            Log.e(TAG, "[psiphon] could not create its data folder")
            failure = PsiphonFailure.CONFIG
            return false
        }
        val config = PsiphonConfig.merge(
            session.config,
            PsiphonConfig.Device(
                dataRoot = dataRoot.absolutePath,
                socksPort = session.port,
                timeoutSeconds = PsiphonConfig.timeoutSeconds(session.timeoutMs),
                clientPlatform = PsiphonConfig.clientPlatform(Build.VERSION.RELEASE, context.packageName),
                clientVersion = BuildConfig.VERSION_CODE.toString(),
            ),
        )
        if (config == null) {
            Log.e(TAG, "[psiphon] the network config is not a JSON object")
            failure = PsiphonFailure.CONFIG
            return false
        }
        // The app's server list, by its path. The library reads it itself;
        // nothing here reads or logs what it holds.
        return try {
            Psi.start(config, "", entries, Host(context.applicationContext, id, session.port), false, false, true)
            running = true
            Log.i(TAG, "[psiphon] started" + (if (entries.isEmpty()) "" else " with the server list") + "; waiting for a tunnel")
            true
        } catch (e: Exception) {
            // The library's message can quote the config, so only debug
            // builds log it.
            Log.e(TAG, "[psiphon] could not start: ${e.javaClass.simpleName}" + if (BuildConfig.DEBUG) " ${e.message}" else "")
            failure = PsiphonFailure.START
            // Psi.start can change the Go runtime before it fails.
            restoreRuntime()
            false
        }
    }

    /**
     * Waits for the first tunnel, up to [timeoutMs], and looks every
     * 250 ms whether [cancelled] says the start was stopped or replaced.
     */
    suspend fun awaitTunnel(timeoutMs: Long, cancelled: () -> Boolean): PsiphonWait {
        val until = SystemClock.elapsedRealtime() + timeoutMs
        while (true) {
            PsiphonNotices.waitStep(cancelled(), failure, tunnels, SystemClock.elapsedRealtime(), until)
                ?.let { return it }
            delay(POLL_MS)
        }
    }

    /** What went wrong with the current run, or null. */
    fun failure(): PsiphonFailure? = failure

    /**
     * Stops the library. Returns at once; the stop runs on the library's
     * own thread. Safe to call when it never started.
     */
    fun stop() {
        stopping = true
        worker.execute { stopNow() }
    }

    /** Tells the library the network under the tunnel changed. */
    fun networkChanged() {
        if (!running) return
        worker.execute {
            if (!running || stopping) return@execute
            try {
                Psi.networkChanged()
            } catch (e: Exception) {
                Log.w(TAG, "[psiphon] could not pass on a network change: ${e.javaClass.simpleName}")
            }
        }
    }

    /**
     * Puts back the Go runtime settings Psiphon changes for the whole
     * process: Psi.start sets the garbage collector to 5 percent, and
     * Psi.stop does not undo it. The Xray core runs in the same process.
     */
    private fun restoreRuntime() {
        try {
            Fortivacore.restoreRuntime()
        } catch (e: Exception) {
            Log.w(TAG, "[psiphon] could not restore the Go runtime: ${e.javaClass.simpleName}")
        }
    }

    /** On [worker] only. */
    private fun stopNow() {
        stopping = true
        if (running) {
            try {
                Psi.stop()
            } catch (e: Exception) {
                Log.w(TAG, "[psiphon] stop failed: ${e.javaClass.simpleName}")
            }
            running = false
            restoreRuntime()
            Log.i(TAG, "[psiphon] stopped")
        }
        tunnels = 0
        region = null
        upgrade = null
    }

    private fun fail(reason: PsiphonFailure) {
        if (failure == null) failure = reason
    }

    /**
     * The library ended by itself after it had connected. The tunnel then
     * carries nothing, so it is taken down, which the app sees as a drop.
     */
    private fun lost() {
        Log.w(TAG, "[psiphon] stopped by itself during a session")
        main.post { V2RayServiceManager.psiphonLost() }
    }

    /**
     * What the library calls. Every call must return quickly; see
     * PsiphonNotices.
     *
     * These are the methods of psi.PsiphonProvider at the pinned release
     * (android/core/checksums.txt). Psiphon's master adds onAccessToken, so
     * a change of the pin to a later commit adds that override here too.
     */
    private class Host(context: Context, private val id: Int, private val port: Int) : PsiphonProvider {
        private val connectivity = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager

        override fun notice(noticeJSON: String) {
            if (id != run.get()) return
            if (BuildConfig.DEBUG) PsiphonNotices.debugLine(noticeJSON)?.let { Log.d(TAG, it) }
            when (val notice = PsiphonNotices.parse(noticeJSON) ?: return) {
                is PsiphonNotice.Tunnels -> {
                    tunnels = notice.count
                    if (notice.count >= 1 && !connectedOnce) {
                        connectedOnce = true
                        Log.i(TAG, "[psiphon] tunnel up")
                    }
                }
                // The core's outbound points at [port]. A proxy anywhere
                // else is one nothing reaches.
                is PsiphonNotice.ListeningSocksPort -> if (notice.port != port) {
                    Log.w(TAG, "[psiphon] its proxy listens on ${notice.port}, not on $port")
                    fail(PsiphonFailure.PORT_IN_USE)
                }
                PsiphonNotice.SocksPortInUse -> fail(PsiphonFailure.PORT_IN_USE)
                PsiphonNotice.EstablishTimeout -> fail(PsiphonFailure.ESTABLISH_TIMEOUT)
                PsiphonNotice.Exiting -> if (!stopping) {
                    fail(PsiphonFailure.EXITING)
                    if (connectedOnce) lost()
                }
                is PsiphonNotice.ServerRegion -> region = notice.region
                is PsiphonNotice.UpgradeAvailable -> upgrade = notice.version
            }
        }

        /** Never called: the library is started with useDeviceBinder false. */
        override fun bindToDevice(fileDescriptor: Long): String = ""

        override fun getDNSServersAsString(): String = try {
            val network = connectivity.activeNetwork
            val props = network?.let { connectivity.getLinkProperties(it) }
            if (props == null) "" else PsiphonNetwork.dnsServers(props.dnsServers, props.interfaceName)
        } catch (e: Exception) {
            ""
        }

        override fun getNetworkID(): String = try {
            val caps = connectivity.activeNetwork?.let { connectivity.getNetworkCapabilities(it) }
            if (caps == null) {
                PsiphonNetwork.UNKNOWN
            } else {
                PsiphonNetwork.idWord(
                    wifi = caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI),
                    cellular = caps.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR),
                    ethernet = caps.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET),
                )
            }
        } catch (e: Exception) {
            PsiphonNetwork.UNKNOWN
        }

        /**
         * 1 while the phone has a network that offers the internet. Not
         * "validated": in Iran Android's own check often fails on a network
         * that works, and a 0 here makes the library wait.
         */
        override fun hasNetworkConnectivity(): Long = try {
            val caps = connectivity.activeNetwork?.let { connectivity.getNetworkCapabilities(it) }
            if (caps?.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET) == true) 1L else 0L
        } catch (e: Exception) {
            1L
        }

        /**
         * 1 when the network has a global IPv6 address and an IPv6 default
         * route, read from its LinkProperties as MainActivity.ipv6Route
         * reads them. This app is left out of its own VPN, so this is the
         * network under the tunnel.
         */
        override fun hasIPv6Route(): Long = try {
            val props = connectivity.activeNetwork?.let { connectivity.getLinkProperties(it) }
            val address = props?.linkAddresses?.any { PsiphonNetwork.isGlobalIpv6(it.address) } == true
            val route = props?.routes?.any { it.isDefaultRoute && it.destination.address is Inet6Address } == true
            if (address && route) 1L else 0L
        } catch (e: Exception) {
            0L
        }

        override fun iPv6Synthesize(IPv4Addr: String): String = IPv4Addr
    }
}
