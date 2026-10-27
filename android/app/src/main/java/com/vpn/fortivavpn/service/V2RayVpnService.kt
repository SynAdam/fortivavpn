package com.vpn.fortivavpn.service

import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.ConnectivityManager
import android.net.LocalSocket
import android.net.LocalSocketAddress
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.net.ProxyInfo
import android.net.VpnService
import android.os.Build
import android.os.ParcelFileDescriptor
import android.os.StrictMode
import android.os.SystemClock
import android.util.Log
import androidx.annotation.RequiresApi
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import com.vpn.fortivavpn.AppConfig
import com.vpn.fortivavpn.AppConfig.LOOPBACK
import com.vpn.fortivavpn.BuildConfig
import com.vpn.fortivavpn.R
import com.vpn.fortivavpn.handler.MmkvManager
import com.vpn.fortivavpn.handler.SettingsManager
import com.vpn.fortivavpn.util.MessageUtil
import com.vpn.fortivavpn.util.MyContextWrapper
import com.vpn.fortivavpn.util.Utils
import java.io.File
import java.lang.ref.SoftReference
import java.util.concurrent.atomic.AtomicInteger

class V2RayVpnService : VpnService(), ServiceControl {
    companion object {
        private const val VPN_MTU = 1500
        private const val TUN2SOCKS = "libtun2socks.so"

        /**
         * Why a tunnel that was up is not any more, as the app reports it.
         *
         * A `dropped` event on its own says "was connected, is not any more",
         * which is the least useful half of the story: it cannot tell a phone
         * that killed us for battery from a network that cut us, and those
         * have opposite fixes. Android knows the difference and nothing was
         * asking it.
         */
        // Android took the slot: the user turned the VPN off in system
        // settings, or another VPN app took it. The app tells the two apart
        // afterwards and files the second as "replaced" (VpnService.dart).
        const val REASON_REVOKED = "revoked"
        const val REASON_REPLACED = "replaced"    // another VPN app took the slot
        const val REASON_KILLED = "killed"        // the service died while it still meant to run
        const val REASON_NETWORK_LOST = "network_lost"  // the network underneath went away

        /**
         * How long after the underlying network goes away its loss still
         * explains a tunnel dying. A wifi-to-mobile handoff also loses a
         * network, but a replacement arrives within a second or two and
         * clears the mark; a gap this long with nothing to replace it is the
         * network genuinely being gone.
         */
        private const val NETWORK_LOSS_WINDOW_MS = 30_000L

        /**
         * Numbers the starts. The start runs on a worker thread, and the
         * app's button stops a tunnel that is still starting, so a stop can
         * land between its steps, and the next start can arrive before the
         * stopped one has noticed. A shared "stopped" flag was cleared by
         * that next start, and the stopped one then carried on beside it.
         *
         * Kept here and not on the instance: a stop can end the service,
         * and the next start then runs on a new instance while the stopped
         * one is still running on the old.
         */
        private val startGen = AtomicInteger()

        /** The newest start a stop has ended. Starts up to it are stopped. */
        @Volatile
        private var stoppedGen = 0

        /**
         * One start at a time. A start that was stopped or replaced takes
         * down what it brought up before the next start touches the core,
         * the VPN interface or tun2socks.
         */
        private val startLock = Mutex()

        /** The most an abandoned start waits for its core to stop. */
        private const val CORE_STOP_WAIT_MS = 2_000L
    }

    private lateinit var mInterface: ParcelFileDescriptor
    private var isRunning = false
    private lateinit var process: Process

    /** Set when the platform told us why, before the teardown that follows. */
    private var stopReason: String? = null

    /** When the default network was last lost with nothing taking its place. */
    private var networkLostAt = 0L

    /**
     * The network under the tunnel that the backup network last heard of.
     * See PsiphonNetwork.moved.
     */
    private var psiphonNetwork: Network? = null

    /**destroy
     * Unfortunately registerDefaultNetworkCallback is going to return our VPN interface: https://android.googlesource.com/platform/frameworks/base/+/dda156ab0c5d66ad82bdcf76cda07cbc0a9c8a2e
     *
     * This makes doing a requestNetwork with REQUEST necessary so that we don't get ALL possible networks that
     * satisfies default network capabilities but only THE default network. Unfortunately we need to have
     * android.permission.CHANGE_NETWORK_STATE to be able to call requestNetwork.
     *
     * Source: https://android.googlesource.com/platform/frameworks/base/+/2df4c7d/services/core/java/com/android/server/ConnectivityService.java#887
     */
    @delegate:RequiresApi(Build.VERSION_CODES.P)
    private val defaultNetworkRequest by lazy {
        NetworkRequest.Builder()
            .addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
            .addCapability(NetworkCapabilities.NET_CAPABILITY_NOT_RESTRICTED)
            .build()
    }

    private val connectivity by lazy { getSystemService(CONNECTIVITY_SERVICE) as ConnectivityManager }

    @delegate:RequiresApi(Build.VERSION_CODES.P)
    private val defaultNetworkCallback by lazy {
        object : ConnectivityManager.NetworkCallback() {
            override fun onAvailable(network: Network) {
                networkLostAt = 0L
                setUnderlyingNetworks(arrayOf(network))
                V2RayServiceManager.networkChanged()
                // The backup network drops its tunnel and builds a new one
                // on every change it is told of. The first network heard of
                // here is the one it just connected on, so only a move to
                // another network is passed on.
                if (PsiphonNetwork.moved(psiphonNetwork, network)) PsiphonCore.networkChanged()
                psiphonNetwork = network
            }

            override fun onCapabilitiesChanged(network: Network, networkCapabilities: NetworkCapabilities) {
                // it's a good idea to refresh capabilities
                setUnderlyingNetworks(arrayOf(network))
            }

            override fun onLost(network: Network) {
                networkLostAt = SystemClock.elapsedRealtime()
                setUnderlyingNetworks(null)
            }
        }
    }

    override fun onCreate() {
        super.onCreate()
        val policy = StrictMode.ThreadPolicy.Builder().permitAll().build()
        StrictMode.setThreadPolicy(policy)
        V2RayServiceManager.serviceControl = SoftReference(this)
    }

    override fun onRevoke() {
        // Android calls this both when the user turns our VPN off from system
        // settings and when another VPN app takes the slot. Up to 2.2.0 this
        // called prepare() to tell the two apart. That call is no question:
        // our consent survives both, so it made us the VPN again and tore
        // down the app that had just taken the slot, 1 to 7 ms after it got
        // it, and then we stopped too, leaving no VPN at all (VpnSlot). The
        // app now tells them apart by whether another VPN comes up.
        stopReason = REASON_REVOKED
        stoppedGen = startGen.get()
        stopV2Ray()
    }

    /**
     * The reason to file this teardown under, best first.
     *
     * A revocation is the platform saying so outright, so it wins. Failing
     * that, a network that went away and never came back explains it. Failing
     * both, we do not know, and saying so is better than guessing.
     */
    private fun teardownReason(): String {
        stopReason?.let { return it }
        val lostAgo = SystemClock.elapsedRealtime() - networkLostAt
        if (networkLostAt != 0L && lostAgo <= NETWORK_LOSS_WINDOW_MS) return REASON_NETWORK_LOST
        return ""
    }

//    override fun onLowMemory() {
//        stopV2Ray()
//        super.onLowMemory()
//    }

    override fun onDestroy() {
        // Reaching here with isRunning still set means nothing in this class
        // asked for the teardown: stopV2Ray clears the flag before it does
        // anything else. That is Android taking the service away under us,
        // for memory, for a battery restriction, or because the user swiped
        // the task off the recents screen. Best effort by nature: a process
        // killed outright never runs this at all.
        if (isRunning) {
            isRunning = false
            MessageUtil.sendMsg2UI(this, AppConfig.MSG_STATE_STOP_SUCCESS, REASON_KILLED)
        }
        // No tunnel, so no backup network either. Android makes the next
        // instance only after this one is gone, so this stop is queued
        // ahead of any start the next one makes (PsiphonCore).
        PsiphonCore.stop()
        // No tunnel, so no checks for messages through it.
        NoticeJobs.stopTicking()
        // Nor a dead one for the keeper's notification to be about: a
        // service Android takes away never reaches stopCoreLoop.
        NoticeNotifier.clearStalled(this)
        super.onDestroy()
        NotificationService.cancelNotification(this)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(AppConfig.TAG, "[VpnService] onStartCommand called")
        // Must call startForeground() quickly after startForegroundService().
        NotificationService.showStartingNotification(this)

        // Only a start the user tapped for may take the slot, because
        // prepare() takes it from any other VPN app (VpnSlot). A restart by
        // Android (a null intent), always-on and the app's own retries leave
        // it to establish(), which fails while another app holds the slot.
        val takeSlot = intent?.getBooleanExtra(VpnSlot.EXTRA_TAKE_SLOT, false) == true
        // If VPN permission is not granted, we cannot proceed from a Service context.
        if (takeSlot && prepare(this) != null) {
            Log.e(AppConfig.TAG, "[VpnService] ABORT: VPN permission not granted")
            MessageUtil.sendMsg2UI(
                this,
                AppConfig.MSG_STATE_START_FAILURE,
                StartFailure.message(StartFailure.STEP_CONSENT, StartFailure.NOT_PREPARED),
            )
            stopSelf()
            return START_NOT_STICKY
        }
        Log.d(AppConfig.TAG, "[VpnService] VPN permission OK (tap: $takeSlot)")

        val gen = startGen.incrementAndGet()
        CoroutineScope(Dispatchers.Default).launch {
            startLock.withLock { start(gen, startId) }
        }
        return START_STICKY
    }

    /**
     * The steps of start [gen]. After each step, and after each failure, it
     * checks whether it was stopped or replaced. A failure the stop caused
     * is not a failure: the stop has already told the app, and a "failed"
     * from here would land on the attempt the user makes next.
     */
    private suspend fun start(gen: Int, startId: Int) {
        // Stopped or replaced while it waited for the start before it. It
        // has brought nothing up, so there is nothing to take down.
        if (stoppedOrReplaced(gen)) return

        // A backup network proxy whose session is gone: a normal connect
        // cleared it and has not selected its own profile yet, or the
        // stored session no longer reads. Nothing would listen on its port,
        // so it is not started, and it is removed so no later start tries
        // again.
        PsiphonSession.orphan()?.let { orphan ->
            Log.e(AppConfig.TAG, "[VpnService] ABORT: the backup network profile has no session")
            PsiphonSession.forgetOrphan(orphan)
            if (stoppedOrReplaced(gen)) return
            failed(StartFailure.STEP_SESSION, StartFailure.ORPHAN_PROFILE)
            stopSelf()
            return
        }

        // A backup network session (PsiphonSession), when the selected
        // profile is its proxy. Read before the core starts, because its
        // port can move and the core's config is built from the profile.
        val active = PsiphonSession.active()
        val psiphon = if (active == null) {
            null
        } else {
            val prepared = try {
                PsiphonSession.prepare()
            } catch (e: Exception) {
                Log.e(AppConfig.TAG, "[VpnService] backup network session could not be prepared", e)
                null
            }
            if (prepared == null) {
                if (stoppedOrReplaced(gen)) return
                PsiphonSession.forget(active.guid)
                failed(StartFailure.STEP_SESSION, StartFailure.SESSION_ERROR)
                stopSelf()
                return
            }
            prepared
        }

        Log.d(AppConfig.TAG, "[VpnService] Step 1: Starting core loop...")
        val coreFailure = V2RayServiceManager.startCore()
        if (coreFailure != null) {
            Log.e(AppConfig.TAG, "[VpnService] FAILED at Step 1: the core did not start ($coreFailure)")
            // Nothing to take down: the core did not start.
            if (stoppedOrReplaced(gen)) return
            psiphon?.let { PsiphonSession.forget(it.guid) }
            failed(StartFailure.STEP_CORE, coreFailure)
            stopSelf()
            return
        }
        Log.d(AppConfig.TAG, "[VpnService] Step 1 OK: core started")
        if (abandoned(gen, startId)) return

        // After the core, so the receiver that handles a stop is already
        // registered while the backup network looks for a tunnel, which can
        // take a minute. Before the VPN interface, so the phone's traffic
        // is not sent into a proxy that has no tunnel yet.
        if (psiphon != null) {
            Log.d(AppConfig.TAG, "[VpnService] Step 1b: Starting the backup network...")
            if (!startPsiphon(psiphon, gen, startId)) return
            Log.d(AppConfig.TAG, "[VpnService] Step 1b OK: backup network tunnel up")
        }

        Log.d(AppConfig.TAG, "[VpnService] Step 2: Setting up VPN...")
        val setup = setupVpnService()
        if (setup == Setup.SLOT_TAKEN) {
            // Another app has the slot, and nobody tapped to take it back.
            // Not a failure of the door: the app ends its search there.
            Log.w(AppConfig.TAG, "[VpnService] Step 2: another VPN app holds the slot; leaving it")
            if (abandoned(gen, startId)) return
            psiphon?.let { PsiphonSession.forget(it.guid) }
            MessageUtil.sendMsg2UI(this@V2RayVpnService, AppConfig.MSG_STATE_START_FAILURE, VpnSlot.SLOT_TAKEN)
            stopV2Ray(true)
            return
        }
        if (setup != Setup.OK) {
            Log.e(AppConfig.TAG, "[VpnService] FAILED at Step 2: setupVpnService returned false")
            if (abandoned(gen, startId)) return
            psiphon?.let { PsiphonSession.forget(it.guid) }
            failed(StartFailure.STEP_INTERFACE, StartFailure.ESTABLISH_ERROR)
            stopV2Ray(true)
            return
        }
        Log.d(AppConfig.TAG, "[VpnService] Step 2 OK: VPN interface established")
        if (abandoned(gen, startId)) return

        Log.d(AppConfig.TAG, "[VpnService] Step 3: Starting tun2socks...")
        val tunFailure = startTun2socks()
        if (tunFailure != null) {
            Log.e(AppConfig.TAG, "[VpnService] FAILED at Step 3: tun2socks did not start ($tunFailure)")
            if (abandoned(gen, startId)) return
            psiphon?.let { PsiphonSession.forget(it.guid) }
            failed(StartFailure.STEP_TUN2SOCKS, tunFailure)
            stopV2Ray(true)
            return
        }
        Log.d(AppConfig.TAG, "[VpnService] Step 3 OK: tun2socks running")
        if (abandoned(gen, startId)) return

        // The backup network can end between its tunnel and this point.
        if (psiphon != null) {
            PsiphonCore.failure()?.let { failure ->
                psiphonFailed(psiphon, failure.word, StartFailure.STEP_FINISH)
                return
            }
        }

        Log.d(AppConfig.TAG, "[VpnService] SUCCESS: sending MSG_STATE_START_SUCCESS")
        MessageUtil.sendMsg2UI(this@V2RayVpnService, AppConfig.MSG_STATE_START_SUCCESS, "")
    }

    /**
     * Starts the backup network for [session] and waits for its first
     * tunnel, up to the session's wait. True once a tunnel is up. When the
     * library is handed the server list, the start's own time counts
     * toward that wait (PsiphonSession.tunnelWaitMs).
     *
     * False when start [gen] was stopped or replaced meanwhile, and then
     * what it brought up is taken down ([abandoned]). False too when the
     * library did not start, reported a failure (no tunnel within its own
     * wait, the SOCKS port taken, the library exiting) or the wait ran out.
     * That is reported as a failed start, the way a failed step of a normal
     * connect is, and the core and the library are stopped.
     */
    private suspend fun startPsiphon(session: PsiphonSession, gen: Int, startId: Int): Boolean {
        // Decided once, so the start and the waits agree on it.
        val entries = PsiphonSession.embeddedList(session.entriesFile)
        val askedAt = SystemClock.elapsedRealtime()
        val started = PsiphonCore.start(applicationContext, session, entries) { stoppedOrReplaced(gen) }
        if (abandoned(gen, startId)) return false
        val outcome = if (started) {
            val waitMs = PsiphonSession.tunnelWaitMs(
                entries.isNotEmpty(),
                session.timeoutMs,
                SystemClock.elapsedRealtime() - askedAt,
            )
            PsiphonCore.awaitTunnel(waitMs) { stoppedOrReplaced(gen) }
        } else {
            PsiphonWait.Failed(PsiphonCore.failure() ?: PsiphonFailure.START)
        }
        if (abandoned(gen, startId)) return false
        when (outcome) {
            PsiphonWait.Connected -> return true
            PsiphonWait.TimedOut -> psiphonFailed(session, PsiphonFailure.TIMEOUT.word)
            is PsiphonWait.Failed -> psiphonFailed(session, outcome.failure.word)
            // Covered by abandoned() above.
            PsiphonWait.Cancelled -> Unit
        }
        return false
    }

    /**
     * A backup network start that failed, reported like any failed start.
     * The session ends with it, so the tile, the widget or always-on cannot
     * start it again later without the app's checks.
     *
     * [why] is the PsiphonFailure word, sent as the reason at [step].
     */
    private fun psiphonFailed(
        session: PsiphonSession,
        why: String,
        step: String = StartFailure.STEP_PSIPHON,
    ) {
        Log.e(AppConfig.TAG, "[VpnService] FAILED: the backup network did not connect ($why)")
        PsiphonSession.forget(session.guid)
        failed(step, why)
        stopV2Ray(true)
    }

    /**
     * Tells the app this start failed at [step] for [reason] (StartFailure).
     * The caller takes down what the start brought up.
     */
    private fun failed(step: String, reason: String) {
        MessageUtil.sendMsg2UI(
            this@V2RayVpnService,
            AppConfig.MSG_STATE_START_FAILURE,
            StartFailure.message(step, reason),
        )
    }

    /**
     * Whether start [gen] was stopped, or replaced by a newer start. Either
     * way it reports nothing: the app has already shown the user the stop,
     * and a newer start reports for itself.
     */
    private fun stoppedOrReplaced(gen: Int): Boolean =
        stoppedGen >= gen || startGen.get() != gen

    /**
     * [stoppedOrReplaced], and if so, what start [gen] brought up is taken
     * down. The teardown stops the service only while [startId] is its
     * newest start, so it cannot end the start that replaced this one. It
     * leaves [stoppedGen] alone for the same reason.
     */
    private suspend fun abandoned(gen: Int, startId: Int): Boolean {
        if (!stoppedOrReplaced(gen)) return false
        Log.i(AppConfig.TAG, "[VpnService] start $gen stopped or replaced; taking down what it brought up")
        stopV2Ray(true, startId)
        // The core stops on another thread. The next start finds it still
        // running and fails unless this waits for it.
        val until = SystemClock.elapsedRealtime() + CORE_STOP_WAIT_MS
        while (V2RayServiceManager.isRunning() && SystemClock.elapsedRealtime() < until) {
            delay(50)
        }
        return true
    }

    override fun getService(): Service {
        return this
    }

    override fun startService() {
        setup()
    }

    override fun stopService() {
        stoppedGen = startGen.get()
        stopV2Ray(true)
    }

    /**
     * The core's shutdown callback. It is not a stop of its own: the core
     * reports a shutdown only from its stop call, and here that call only
     * runs inside [stopV2Ray], so the teardown is already done.
     *
     * It used to run [stopService] again. That marked every start counted
     * so far as stopped, and stopped the service. When a stopped start
     * took its core down after the next start had arrived, the next start
     * was ended before it began. The user's connect then showed
     * "Connecting" for 20 seconds and failed with a wrong diagnosis. Seen
     * on 2026-10-07 on an emulator with this process slowed down.
     */
    override fun coreStopped() {
        Log.d(AppConfig.TAG, "[VpnService] core stopped")
    }

    override fun vpnProtect(socket: Int): Boolean {
        return protect(socket)
    }

    @RequiresApi(Build.VERSION_CODES.N)
    override fun attachBaseContext(newBase: Context?) {
        val context = newBase?.let {
            MyContextWrapper.wrap(newBase, SettingsManager.getLocale())
        }
        super.attachBaseContext(context)
    }

    /**
     * Sets up the VPN service.
     * Prepares the VPN and configures it if preparation is successful.
     */
    private fun setup() {
        // Kept for compatibility with the ServiceControl interface.
        // Main entrypoint is onStartCommand().
        if (setupVpnService() == Setup.OK) {
            runTun2socks()
        }
    }

    /** How [setupVpnService] went. */
    private enum class Setup {
        OK,
        FAILED,

        /** establish() gave no interface: this app does not hold the slot. */
        SLOT_TAKEN,
    }

    /**
     * Configures the VPN service.
     * @return [Setup.OK] once the interface is up.
     */
    private fun setupVpnService(): Setup {
        // If the old interface has exactly the same parameters, use it!
        // Configure a builder while parsing the parameters.
        val builder = Builder()
        val vpnConfig = SettingsManager.getCurrentVpnInterfaceAddressConfig()
        //val enableLocalDns = defaultDPreference.getPrefBoolean(AppConfig.PREF_LOCAL_DNS_ENABLED, false)

        builder.setMtu(VPN_MTU)
        builder.addAddress(vpnConfig.ipv4Client, 30)
        //builder.addDnsServer(PRIVATE_VLAN4_ROUTER)
        val bypassLan = SettingsManager.routingRulesetsBypassLan()
        if (bypassLan) {
            AppConfig.ROUTED_IP_LIST.forEach {
                val addr = it.split('/')
                builder.addRoute(addr[0], addr[1].toInt())
            }
        } else {
            builder.addRoute("0.0.0.0", 0)
        }

        if (MmkvManager.decodeSettingsBool(AppConfig.PREF_PREFER_IPV6) == true) {
            builder.addAddress(vpnConfig.ipv6Client, 126)
            if (bypassLan) {
                builder.addRoute("2000::", 3) //currently only 1/8 of total ipV6 is in use
                builder.addRoute("fc00::", 18) //Xray-core default FakeIPv6 Pool
            } else {
                builder.addRoute("::", 0)
            }
        }

//        if (MmkvManager.decodeSettingsBool(AppConfig.PREF_LOCAL_DNS_ENABLED) == true) {
//            builder.addDnsServer(PRIVATE_VLAN4_ROUTER)
//        } else {
        SettingsManager.getVpnDnsServers()
            .forEach {
                if (Utils.isPureIpAddress(it)) {
                    builder.addDnsServer(it)
                }
            }
//        }

        // Shown in Android's own VPN dialogs; the app's name, not the
        // label of whoever posted a community link.
        builder.setSession(getString(R.string.app_name))

        configurePerAppProxy(builder)

        // Close the old interface since the parameters have been changed.
        if (::mInterface.isInitialized) {
            try {
                mInterface.close()
            } catch (ignored: Exception) {
                // ignored
            }
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            psiphonNetwork = null
            try {
                connectivity.requestNetwork(defaultNetworkRequest, defaultNetworkCallback)
            } catch (e: Exception) {
                Log.e(AppConfig.TAG, "Failed to request default network", e)
            }
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            builder.setMetered(false)
            if (MmkvManager.decodeSettingsBool(AppConfig.PREF_APPEND_HTTP_PROXY)) {
                builder.setHttpProxy(ProxyInfo.buildDirectProxy(LOOPBACK, SettingsManager.getHttpPort()))
            }
        }

        // Create a new interface using the builder and save the parameters.
        val established = try {
            builder.establish()
        } catch (e: Exception) {
            Log.e(AppConfig.TAG, "Failed to establish VPN interface", e)
            stopV2Ray()
            return Setup.FAILED
        }
        // Null when this app is not the one Android has prepared: another app
        // took the slot since this one last held it, the user turned the VPN
        // off in system settings, or the consent is gone. Nearly always a
        // start without a tap: a start with one took the slot moments ago.
        if (established == null) return Setup.SLOT_TAKEN
        mInterface = established
        isRunning = true
        return Setup.OK
    }

    /**
     * Configures per-app proxy rules for the VPN builder.
     *
     * - If per-app proxy is not enabled, disallow the VPN service's own package.
     * - If no apps are selected, disallow the VPN service's own package.
     * - If bypass mode is enabled, disallow all selected apps (including self).
     * - If proxy mode is enabled, only allow the selected apps (excluding self).
     *
     * @param builder The VPN Builder to configure.
     */
    private fun configurePerAppProxy(builder: Builder) {
        val selfPackageName = BuildConfig.APPLICATION_ID

        // CRITICAL: The app MUST be excluded from the VPN tunnel.
        // libv2ray's CoreCallbackHandler has no protect(fd) callback, so V2Ray
        // cannot protect its outbound sockets. Without this exclusion, outbound
        // connections loop back through TUN → SOCKS → outbound → TUN (infinite loop).
        // Traffic verification uses the native SOCKS proxy instead of TUN.
        if (MmkvManager.decodeSettingsBool(AppConfig.PREF_PER_APP_PROXY) == false) {
            builder.addDisallowedApplication(selfPackageName)
            return
        }

        // If no apps are selected, allow all (default behavior)
        val apps = MmkvManager.decodeSettingsStringSet(AppConfig.PREF_PER_APP_PROXY_SET)
        if (apps.isNullOrEmpty()) {
            builder.addDisallowedApplication(selfPackageName)
            return
        }

        val bypassApps = MmkvManager.decodeSettingsBool(AppConfig.PREF_BYPASS_APPS)
        // Handle the VPN service's own package according to the mode
        if (bypassApps) apps.add(selfPackageName) else apps.remove(selfPackageName)

        apps.forEach {
            try {
                if (bypassApps) {
                    // In bypass mode, disallow the selected apps
                    builder.addDisallowedApplication(it)
                } else {
                    // In proxy mode, only allow the selected apps
                    builder.addAllowedApplication(it)
                }
            } catch (_: PackageManager.NameNotFoundException) {
                // The exception names the app, and this log is sent with
                // connection reports, so neither goes into the line.
                Log.e(AppConfig.TAG, "An app chosen for per-app routing is not installed; skipped")
            }
        }
    }

    /**
     * Runs the tun2socks process.
     * Starts the tun2socks process with the appropriate parameters.
     */
    private fun runTun2socks(): Boolean = startTun2socks() == null

    /**
     * [runTun2socks], with the reason when it fails: null once the
     * interface is handed to tun2socks, else StartFailure.PROCESS_ERROR or
     * StartFailure.FD_NOT_SENT. The output monitor's restart calls
     * [runTun2socks] as before.
     */
    private fun startTun2socks(): String? {
        Log.i(AppConfig.TAG, "🚀 ========== STARTING TUN2SOCKS ==========")
        val socksPort = SettingsManager.getSocksPort()
        val vpnConfig = SettingsManager.getCurrentVpnInterfaceAddressConfig()
        val sockPath = File(applicationContext.filesDir, "sock_path").absolutePath

        Log.i(AppConfig.TAG, "🔧 TUN2SOCKS Config:")
        Log.i(AppConfig.TAG, "   - SOCKS Port: $socksPort")
        Log.i(AppConfig.TAG, "   - IPv4 Router: ${vpnConfig.ipv4Router}")
        Log.i(AppConfig.TAG, "   - Socket Path: $sockPath")
        Log.i(AppConfig.TAG, "   - UDP Relay: ENABLED")

        // On fast reconnects, a stale unix socket file can remain and break the next startup.
        try {
            File(sockPath).delete()
            Log.d(AppConfig.TAG, "🗑️ Deleted stale socket file")
        } catch (ignored: Exception) {
            // ignored
        }

        val cmd = arrayListOf(
            File(applicationContext.applicationInfo.nativeLibraryDir, TUN2SOCKS).absolutePath,
            "--netif-ipaddr", vpnConfig.ipv4Router,
            "--netif-netmask", "255.255.255.252",
            "--socks-server-addr", "$LOOPBACK:${socksPort}",
            "--tunmtu", VPN_MTU.toString(),
            "--sock-path", sockPath,
            // UDP as SOCKS5 UDP ASSOCIATE, which the core's SOCKS inbound
            // accepts. In this build --enable-udprelay means the udpgw
            // protocol aimed at 0.0.0.0:0, which the core does not speak, so
            // every UDP packet was dropped: DNS over UDP, voice calls, games.
            // DNS still worked only because Android upgrades its own lookups
            // to DNS over TLS when it can. With Private DNS set to a
            // provider it cannot, and on 2026-10-02 a phone in Iran
            // connected but could not resolve a single new name.
            "--socks5-udp",
            "--loglevel", "debug"  // Changed from "notice" to "debug" for verbose UDP logs
        )

        if (MmkvManager.decodeSettingsBool(AppConfig.PREF_PREFER_IPV6)) {
            cmd.add("--netif-ip6addr")
            cmd.add(vpnConfig.ipv6Router)
            Log.i(AppConfig.TAG, "   - IPv6 Router: ${vpnConfig.ipv6Router}")
        }
        if (MmkvManager.decodeSettingsBool(AppConfig.PREF_LOCAL_DNS_ENABLED)) {
            val localDnsPort = Utils.parseInt(MmkvManager.decodeSettingsString(AppConfig.PREF_LOCAL_DNS_PORT), AppConfig.PORT_LOCAL_DNS.toInt())
            cmd.add("--dnsgw")
            cmd.add("$LOOPBACK:${localDnsPort}")
            Log.i(AppConfig.TAG, "   - DNS Gateway: $LOOPBACK:$localDnsPort")
        }
        
        Log.i(AppConfig.TAG, "📋 TUN2SOCKS Command: ${cmd.joinToString(" ")}")

        try {
            val proBuilder = ProcessBuilder(cmd)
            proBuilder.redirectErrorStream(true)
            process = proBuilder
                .directory(applicationContext.filesDir)
                .start()
            
            // Log tun2socks output in a separate thread
            Thread {
                Log.i(AppConfig.TAG, "📡 TUN2SOCKS output monitor started")
                try {
                    process.inputStream.bufferedReader().useLines { lines ->
                        lines.forEach { line ->
                            // Log all tun2socks output with UDP marker if relevant
                            if (line.contains("udp", ignoreCase = true)) {
                                Log.i(AppConfig.TAG, "🔵 TUN2SOCKS UDP: $line")
                            } else {
                                Log.d(AppConfig.TAG, "📡 TUN2SOCKS: $line")
                            }
                        }
                    }
                } catch (e: Exception) {
                    Log.e(AppConfig.TAG, "TUN2SOCKS output read error: ${e.message}")
                }
                
                process.waitFor()
                val exitCode = process.exitValue()
                Log.i(AppConfig.TAG, "🛑 TUN2SOCKS exited with code: $exitCode")
                
                if (isRunning) {
                    Log.i(AppConfig.TAG, "🔄 TUN2SOCKS restart triggered")
                    runTun2socks()
                }
            }.start()
            
            Log.i(AppConfig.TAG, "✅ TUN2SOCKS process started: ${process.toString()}")

            val fdSent = sendFd(sockPath)
            if (fdSent) {
                Log.i(AppConfig.TAG, "✅ TUN FD sent successfully - VPN is fully active!")
                Log.i(AppConfig.TAG, "🎉 UDP traffic should now be forwarded via SOCKS5")
            } else {
                Log.e(AppConfig.TAG, "❌ Failed to send TUN FD to tun2socks")
            }
            return if (fdSent) null else StartFailure.FD_NOT_SENT
        } catch (e: Exception) {
            Log.e(AppConfig.TAG, "❌ Failed to start $TUN2SOCKS process", e)
        }
        return StartFailure.PROCESS_ERROR
    }

    /**
     * Sends the file descriptor to the tun2socks process.
     * Attempts to send the file descriptor multiple times if necessary.
     */
    private fun sendFd(sockPath: String): Boolean {
        if (!::mInterface.isInitialized) return false
        if (!::process.isInitialized) return false

        val fd = mInterface.fileDescriptor
        Log.i(AppConfig.TAG, "LocalSocket path : $sockPath")

        var tries = 0
        val maxTries = 12
        while (true) {
            try {
                if (!process.isAlive) {
                    Log.e(AppConfig.TAG, "$TUN2SOCKS is not alive; cannot send FD")
                    return false
                }

                // Wait a bit for tun2socks to create/bind the unix socket.
                val backoffMs = (50L shl tries).coerceAtMost(1000L)
                Thread.sleep(backoffMs)

                Log.i(AppConfig.TAG, "LocalSocket sendFd tries: $tries")
                LocalSocket().use { localSocket ->
                    localSocket.connect(LocalSocketAddress(sockPath, LocalSocketAddress.Namespace.FILESYSTEM))
                    localSocket.setFileDescriptorsForSend(arrayOf(fd))
                    localSocket.outputStream.write(42)
                }
                return true
            } catch (e: Exception) {
                Log.e(AppConfig.TAG, "Failed to send file descriptor, try: $tries", e)
                if (tries >= maxTries) return false
                tries += 1
            }
        }
    }

    /**
     * Stops the V2Ray service.
     * @param isForced Whether to force stop the service.
     * @param startId When set, the service stops only if this is still its
     *   newest start. See [abandoned].
     */
    private fun stopV2Ray(isForced: Boolean = true, startId: Int? = null) {
//        val configName = defaultDPreference.getPrefString(PREF_CURR_CONFIG_GUID, "")
//        val emptyInfo = VpnNetworkInfo()
//        val info = loadVpnNetworkInfo(configName, emptyInfo)!! + (lastNetworkInfo ?: emptyInfo)
//        saveVpnNetworkInfo(configName, info)
        isRunning = false
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            try {
                connectivity.unregisterNetworkCallback(defaultNetworkCallback)
            } catch (ignored: Exception) {
                // ignored
            }
        }

        try {
            Log.i(AppConfig.TAG, "$TUN2SOCKS destroy")
            if (::process.isInitialized) {
                process.destroy()
            }
        } catch (e: Exception) {
            Log.e(AppConfig.TAG, "Failed to destroy $TUN2SOCKS process", e)
        }

        V2RayServiceManager.stopCoreLoop(teardownReason())
        stopReason = null
        networkLostAt = 0L

        if (isForced) {
            //stopSelf has to be called ahead of mInterface.close(). otherwise v2ray core cannot be stooped
            //It's strage but true.
            //This can be verified by putting stopself() behind and call stopLoop and startLoop
            //in a row for several times. You will find that later created v2ray core report port in use
            //which means the first v2ray core somehow failed to stop and release the port.
            if (startId == null) stopSelf() else stopSelfResult(startId)

            try {
                if (::mInterface.isInitialized) {
                    mInterface.close()
                }
            } catch (e: Exception) {
                Log.e(AppConfig.TAG, "Failed to close VPN interface", e)
            }
        }
    }
}
