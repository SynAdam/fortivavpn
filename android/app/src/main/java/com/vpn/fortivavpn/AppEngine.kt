// Copyright (C) 2026 NimusAI. GPL-3.0-or-later, with the additional terms
// under section 7 in LICENSING.md.

package com.vpn.fortivavpn

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import com.vpn.fortivavpn.handler.TunnelProbe
import com.vpn.fortivavpn.service.StatsPayload
import com.vpn.fortivavpn.service.V2RayServiceManager
import com.vpn.fortivavpn.service.VpnSlot
import com.vpn.fortivavpn.util.MessageUtil
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/**
 * The app's Flutter engine, kept for as long as the main process lives, and
 * the part of the tunnel channel that has to last as long as the engine.
 *
 * Up to 2.2.0 every MainActivity started an engine and ended it in
 * onDestroy. The tunnel's process holds a foreground notification, so when
 * the user swipes the app out of recents Android keeps the main process and
 * only the activity goes. Opening the app again was then a warm start that
 * built a new engine and ran main() before anything was drawn, because
 * FlutterActivity holds the first draw for Flutter's first frame. In the 18
 * days to 2026-10-19 Google Play counted 12.6% of warm starts as slow (2 s
 * or more) against 2.9% of cold starts (5 s or more), and 27.7% of warm
 * starts on phones with 4 GB of memory. Now each activity takes this engine
 * and the Dart app carries on where the last activity left it, as it does
 * after Back (MainActivity.popSystemNavigator).
 *
 * The status stream and the traffic answers are here, not in the activity,
 * because Dart listens to the stream once per engine. A receiver that an
 * activity registered stopped with that activity and was never registered
 * again.
 *
 * Without an activity the engine leaves the tunnel to the keeper, as when
 * it ended with the activity: see [shown].
 *
 * Main thread only.
 */
object AppEngine {
    private const val TAG = "FortivaVPN"
    private const val EVENT_CHANNEL = "com.vpn.fortivavpn/tunnel/status"

    // A cross-process broadcast round trip takes milliseconds. Anything
    // beyond this is the service being gone, and the caller skips a beat
    // rather than waiting on it.
    private const val STATS_TIMEOUT_MS = 3000L

    private var engine: FlutterEngine? = null
    private var app: Context? = null

    /**
     * Whether an activity shows the engine. MainActivity sets it in
     * configureFlutterEngine and clears it in cleanUpFlutterEngine.
     *
     * Without an activity, [tunnelStats] answers null without asking the
     * tunnel, and the Dart side's heartbeat and dead tunnel check skip a
     * null reading. The tunnel's process then hears nothing from the app
     * and starts the keeper (KeeperJobService), which does both, as it did
     * when the engine ended with the activity. The engine cannot do them
     * itself: Android freezes a process that has no activity and no
     * foreground service of its own. On an Android 14 emulator on
     * 2026-10-26 the engine sent no heartbeat in 13 minutes after the app
     * was swiped out of recents, and the keeper never ran, because the
     * engine's reads in the short thaws for the notice checks kept the
     * tunnel's process from seeing the app as gone.
     */
    @Volatile
    var shown = false

    /**
     * Whether the Dart app's pages can go back, as Flutter last told an
     * activity (FlutterActivity.setFrameworkHandlesBack). Flutter says it
     * only when it changes, so MainActivity gives the last answer to the
     * next activity that takes the engine. Without it, Back on Android 16
     * left the app from a page an activity reopened over.
     */
    var frameworkHandlesBack = false

    private var eventSink: EventChannel.EventSink? = null
    private var receiverRegistered = false

    // A traffic query in flight. The counters live in the daemon process, so
    // the answer arrives as a broadcast rather than as a return value, and
    // the Flutter result waits here until it does or until it times out.
    private var pendingStats: MethodChannel.Result? = null
    private val main = Handler(Looper.getMainLooper())
    private val statsTimedOut = Runnable {
        pendingStats?.success(null)
        pendingStats = null
    }

    // Broadcast receiver for service status updates
    private val receiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            val code = intent?.getIntExtra("key", 0)
            when (code) {
                AppConfig.MSG_STATE_RUNNING -> eventSink?.success("connected")
                AppConfig.MSG_STATE_NOT_RUNNING -> eventSink?.success("disconnected")
                AppConfig.MSG_STATE_START -> eventSink?.success("connecting")
                AppConfig.MSG_STATE_STOP -> eventSink?.success("disconnected")
                AppConfig.MSG_STATE_START_SUCCESS -> eventSink?.success("connected")
                // "failed:slot_taken" when another VPN app holds the slot
                // (VpnSlot.SLOT_TAKEN); any other failure says where and why
                // ("failed:core:port_in_use", see StartFailure).
                AppConfig.MSG_STATE_START_FAILURE -> eventSink?.success(withReason("failed", intent))
                AppConfig.MSG_STATE_STOP_SUCCESS -> eventSink?.success(withReason("disconnected", intent))
                AppConfig.MSG_STATS_UPDATE -> deliverStats(intent.getStringExtra("content"))
            }
        }
    }

    private val statusStream = object : EventChannel.StreamHandler {
        override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
            val context = app ?: return
            eventSink = events
            // Use ConnectivityManager to detect VPN: survives app death
            events?.success(if (vpnActive(context)) "connected" else "disconnected")
            register(context)
        }

        override fun onCancel(arguments: Any?) {
            eventSink = null
            unregister()
        }
    }

    /**
     * The engine, made the first time an activity asks for it. Plugins
     * register in the engine's constructor, and FlutterActivity runs main()
     * on it the first time it is shown.
     */
    fun get(context: Context): FlutterEngine {
        engine?.let { return it }
        val appContext = context.applicationContext
        app = appContext
        val started = FlutterEngine(appContext)
        started.addEngineLifecycleListener(object : FlutterEngine.EngineLifecycleListener {
            override fun onPreEngineRestart() = Unit

            override fun onEngineWillDestroy() = ended()
        })
        EventChannel(started.dartExecutor.binaryMessenger, EVENT_CHANNEL).setStreamHandler(statusStream)
        engine = started
        return started
    }

    /** A status only the activity knows, such as "awaiting_permission". */
    fun status(status: String) {
        eventSink?.success(status)
    }

    /** Whether this app's tunnel is up. */
    fun vpnActive(context: Context): Boolean {
        // Check static flag (works when service is in same process)
        if (V2RayServiceManager.isRunning()) return true

        // This app's own VPN network (survives app death if service runs in
        // separate process). Up to 2.2.0 any VPN counted, so the app opened
        // while Psiphon was up showed Connected, and its check of that
        // "tunnel" then searched for a door without a tap.
        return VpnSlot.ownUp(context)
    }

    /**
     * Bytes the tunnel has carried since this was last asked.
     *
     * The core's counters are in the daemon process, so this broadcasts the
     * question and parks the Flutter result until MSG_STATS_UPDATE comes back
     * (see deliverStats). The counters reset on every read, which is exactly
     * what a heartbeat wants and why nothing else may ask. [beat] says the
     * heartbeat asks: while the session readings run, only its answer
     * carries the session block.
     *
     * Answers null when there is no tunnel, when the service does not reply,
     * when the core is not counting, or when no activity shows the engine
     * ([shown]). Null means "no reading", never "no bytes": the difference is
     * the whole point of the call.
     */
    fun tunnelStats(context: Context, result: MethodChannel.Result, beat: Boolean) {
        if (!shown || !vpnActive(context)) {
            result.success(null)
            return
        }
        // An earlier question that was never answered. Complete it so its
        // Dart future resolves instead of hanging on a reply meant for this
        // one; its counters were never read, so nothing was lost with it.
        pendingStats?.success(null)
        pendingStats = result
        main.removeCallbacks(statsTimedOut)
        main.postDelayed(statsTimedOut, STATS_TIMEOUT_MS)
        MessageUtil.sendMsg2Service(context, AppConfig.MSG_MEASURE_TRAFFIC, if (beat) AppConfig.TRAFFIC_BEAT else "")
    }

    /**
     * "disconnected", or "disconnected:killed" when the service said why,
     * "failed:slot_taken" for a start another VPN app's slot stopped, and
     * "failed:<step>:<reason>" for any other failed start.
     *
     * The status stream has always been a bare word, and the app on the other
     * end still reads one when there is no reason to add. See the REASON_
     * constants on V2RayVpnService, VpnSlot.SLOT_TAKEN and StartFailure for
     * what the second half can be.
     */
    private fun withReason(status: String, intent: Intent?): String {
        val reason = intent?.getStringExtra("content")?.takeIf { it.isNotBlank() }
        return if (reason == null) status else "$status:$reason"
    }

    /**
     * Hands a traffic answer from the daemon process to the waiting caller,
     * with the two facts only this process can read cheaply attached. See
     * StatsPayload for what the answer holds.
     *
     * A malformed or missing payload resolves to null rather than to zero
     * bytes: a beat that reports zero says the tunnel carried nothing, which
     * is a finding, and it must never be manufactured out of a lost message.
     */
    private fun deliverStats(payload: String?) {
        main.removeCallbacks(statsTimedOut)
        val result = pendingStats ?: return
        pendingStats = null
        val stats = StatsPayload.parse(payload)
        val context = app
        if (stats == null || context == null) {
            result.success(null)
            return
        }
        result.success(stats + TunnelProbe.networkFacts(context))
    }

    private fun register(context: Context) {
        if (receiverRegistered) return
        val filter = IntentFilter(AppConfig.BROADCAST_ACTION_ACTIVITY)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            context.registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            context.registerReceiver(receiver, filter)
        }
        receiverRegistered = true
    }

    private fun unregister() {
        if (!receiverRegistered) return
        try {
            app?.unregisterReceiver(receiver)
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error unregistering receiver: ${e.message}")
        }
        receiverRegistered = false
    }

    private fun ended() {
        main.removeCallbacks(statsTimedOut)
        pendingStats?.success(null)
        pendingStats = null
        eventSink = null
        unregister()
        engine = null
        shown = false
        frameworkHandlesBack = false
    }
}
