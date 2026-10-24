package com.vpn.fortivavpn.service

import android.app.job.JobParameters
import android.app.job.JobService
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import com.vpn.fortivavpn.AppConfig
import com.vpn.fortivavpn.MainActivity
import com.vpn.fortivavpn.handler.SettingsManager
import com.vpn.fortivavpn.handler.TunnelProbe
import com.vpn.fortivavpn.util.MessageUtil
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.net.InetSocketAddress
import java.net.Socket
import java.util.concurrent.TimeUnit

/**
 * One heartbeat and one dead tunnel check while the app's own engine is
 * gone and the tunnel runs on (see Keeper, which starts this from the
 * tunnel's process).
 *
 * The work itself is Dart (keeperMain in lib/services/keeper.dart), so the
 * heartbeat goes out the way the app's do: the same queue, routes, relays
 * and device id. This starts a Flutter engine with no screen, answers its
 * few questions about the tunnel, and stops it when it says it is done or
 * after [BUDGET_MS].
 *
 * Runs in the app's main process, never in the tunnel's, so the engine
 * never takes memory from the tunnel. Does nothing while the app's engine
 * runs: the app sends its own heartbeats then, and a job that thawed a
 * frozen app lets its timers catch up.
 */
class KeeperJobService : JobService() {
    private val main = Handler(Looper.getMainLooper())
    private var engine: FlutterEngine? = null
    private var params: JobParameters? = null
    private var pendingStats: MethodChannel.Result? = null
    private var receiverRegistered = false

    private val overBudget = Runnable {
        Log.w(TAG, "the keeper ran out of time")
        finish()
    }

    private val statsTimedOut = Runnable { answerStats(null) }

    private val replies = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.getIntExtra("key", 0) != AppConfig.MSG_STATS_UPDATE) return
            answerStats(intent.getStringExtra("content"))
        }
    }

    override fun onStartJob(params: JobParameters): Boolean {
        if (MainActivity.engineAlive || engine != null || this.params != null) return false
        this.params = params
        main.postDelayed(overBudget, BUDGET_MS)
        try {
            val loader = FlutterInjector.instance().flutterLoader()
            loader.startInitialization(applicationContext)
            loader.ensureInitializationCompleteAsync(applicationContext, null, main) {
                start(loader.findAppBundlePath())
            }
        } catch (e: Exception) {
            Log.e(TAG, "could not load Flutter", e)
            finish()
        }
        return true
    }

    private fun start(bundlePath: String) {
        if (params == null || engine != null) return
        // The app came back while Flutter was loading: it does the work.
        if (MainActivity.engineAlive) {
            finish()
            return
        }
        try {
            val started = FlutterEngine(applicationContext)
            engine = started
            MethodChannel(started.dartExecutor.binaryMessenger, CHANNEL)
                .setMethodCallHandler(::handle)
            started.dartExecutor.executeDartEntrypoint(
                DartExecutor.DartEntrypoint(bundlePath, ENTRY_LIBRARY, ENTRY_FUNCTION),
            )
        } catch (e: Exception) {
            Log.e(TAG, "could not start the keeper", e)
            finish()
        }
    }

    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "appRunning" -> result.success(MainActivity.engineAlive)
            "tunnelStats" -> askStats(result)
            "testConnection" -> Thread {
                val works = TunnelProbe.tunnelCarries()
                main.post { result.success(works) }
            }.start()
            "socksPort" -> Thread {
                val port = listeningSocksPort()
                main.post { result.success(port) }
            }.start()
            "showStalled" -> result.success(
                NoticeNotifier.showStalled(
                    applicationContext,
                    call.argument<String>("title").orEmpty(),
                    call.argument<String>("body").orEmpty(),
                    call.argument<String>("channelName").orEmpty(),
                    call.argument<String>("channelDescription").orEmpty(),
                ),
            )
            "done" -> {
                result.success(null)
                main.post { finish() }
            }
            else -> result.notImplemented()
        }
    }

    /**
     * The tunnel's counters since they were last read, as MainActivity's
     * tunnelStats gives them, or null. Asked as the keeper, which reads them
     * as a heartbeat does and does not count as the app being there.
     */
    private fun askStats(result: MethodChannel.Result) {
        if (!TunnelProbe.vpnUp(applicationContext)) {
            result.success(null)
            return
        }
        pendingStats?.success(null)
        pendingStats = result
        if (!receiverRegistered) {
            val filter = IntentFilter(AppConfig.BROADCAST_ACTION_ACTIVITY)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                registerReceiver(replies, filter, Context.RECEIVER_NOT_EXPORTED)
            } else {
                registerReceiver(replies, filter)
            }
            receiverRegistered = true
        }
        main.removeCallbacks(statsTimedOut)
        main.postDelayed(statsTimedOut, STATS_TIMEOUT_MS)
        MessageUtil.sendMsg2Service(applicationContext, AppConfig.MSG_MEASURE_TRAFFIC, AppConfig.TRAFFIC_KEEPER)
    }

    private fun answerStats(payload: String?) {
        main.removeCallbacks(statsTimedOut)
        val result = pendingStats ?: return
        pendingStats = null
        val stats = StatsPayload.parse(payload)
        result.success(stats?.plus(TunnelProbe.networkFacts(applicationContext)))
    }

    /** The core's SOCKS port when something listens on it, else null. */
    private fun listeningSocksPort(): Int? {
        val port = try {
            SettingsManager.getSocksPort()
        } catch (_: Exception) {
            return null
        }
        return try {
            Socket().use { it.connect(InetSocketAddress("127.0.0.1", port), KNOCK_MS) }
            port
        } catch (_: Exception) {
            null
        }
    }

    private fun stopEngine() {
        main.removeCallbacks(overBudget)
        main.removeCallbacks(statsTimedOut)
        pendingStats?.success(null)
        pendingStats = null
        if (receiverRegistered) {
            try {
                unregisterReceiver(replies)
            } catch (_: Exception) {
            }
            receiverRegistered = false
        }
        try {
            engine?.destroy()
        } catch (e: Exception) {
            Log.e(TAG, "could not stop the engine", e)
        }
        engine = null
    }

    private fun finish() {
        stopEngine()
        val done = params ?: return
        params = null
        // Never rescheduled from here: the tunnel's process asks again on its
        // next look while the app stays away.
        jobFinished(done, false)
    }

    override fun onStopJob(params: JobParameters): Boolean {
        stopEngine()
        this.params = null
        return false
    }

    override fun onDestroy() {
        stopEngine()
        params = null
        super.onDestroy()
    }

    companion object {
        private const val TAG = "FortivaKeeper"

        /** Shared with lib/services/keeper.dart. */
        const val CHANNEL = "com.vpn.fortivavpn/keeper"

        const val ENTRY_LIBRARY = "package:fortiva_vpn/services/keeper.dart"
        const val ENTRY_FUNCTION = "keeperMain"

        /**
         * The longest one run may take. The Dart side gives up on its own
         * after 75 s (three checks through the tunnel ten seconds apart fit
         * in that); this is the backstop for an engine that hangs.
         */
        private val BUDGET_MS = TimeUnit.SECONDS.toMillis(100)

        private const val STATS_TIMEOUT_MS = 3000L
        private const val KNOCK_MS = 300
    }
}
