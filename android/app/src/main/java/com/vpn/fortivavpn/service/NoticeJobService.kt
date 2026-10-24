package com.vpn.fortivavpn.service

import android.app.job.JobParameters
import android.app.job.JobService
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import com.vpn.fortivavpn.MainActivity
import com.vpn.fortivavpn.handler.SettingsManager
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.net.InetSocketAddress
import java.net.Socket
import java.util.concurrent.TimeUnit

/**
 * One check for messages from the Fortiva team, with the app off screen.
 *
 * The check itself is Dart (noticePullMain in
 * lib/services/notice_pull.dart), because everything it needs is already
 * there: the routes to the backend through the tunnel and the relays, the
 * public file and its signature check, the device id and the receipts.
 * This starts a Flutter engine with no screen, runs that entrypoint, and
 * stops the engine when it says it is done or after [BUDGET_MS].
 *
 * Runs in the app's main process, never in the tunnel's, so the engine
 * never takes memory from the tunnel. Skipped while the app is on screen,
 * because the app checks for itself then.
 */
class NoticeJobService : JobService() {
    private val main = Handler(Looper.getMainLooper())
    private var engine: FlutterEngine? = null
    private var params: JobParameters? = null
    private val overBudget = Runnable {
        Log.w(TAG, "the check ran out of time")
        finish()
    }

    override fun onStartJob(params: JobParameters): Boolean {
        if (MainActivity.inFront || engine != null || this.params != null) return false
        // The alarm, the periodic job and the tunnel's tick can land close
        // together. One check covers them all.
        val prefs = getSharedPreferences(PREFS, MODE_PRIVATE)
        val now = System.currentTimeMillis()
        val last = prefs.getLong(LAST_START_KEY, 0L)
        if (last in (now - MIN_GAP_MS)..now) return false
        prefs.edit().putLong(LAST_START_KEY, now).apply()
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
        // A job stopped and another started while Flutter was loading: both
        // callbacks land here, and only the first may start an engine.
        if (params == null || engine != null) return
        try {
            val started = FlutterEngine(applicationContext)
            engine = started
            MethodChannel(started.dartExecutor.binaryMessenger, CHANNEL)
                .setMethodCallHandler(::handle)
            started.dartExecutor.executeDartEntrypoint(
                DartExecutor.DartEntrypoint(bundlePath, ENTRY_LIBRARY, ENTRY_FUNCTION),
            )
        } catch (e: Exception) {
            Log.e(TAG, "could not start the check", e)
            finish()
        }
    }

    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "socksPort" -> {
                // The tunnel runs in another process, so whether it is up is
                // read by knocking on its SOCKS port. Off the main thread.
                Thread {
                    val port = listeningSocksPort()
                    main.post { result.success(port) }
                }.start()
            }
            "country" -> result.success(NoticeNotifier.country(applicationContext))
            "show" -> {
                val id = call.argument<Int>("id")
                val body = call.argument<String>("body")
                if (id == null || body.isNullOrBlank()) {
                    result.success(false)
                    return
                }
                result.success(
                    NoticeNotifier.show(
                        applicationContext,
                        id,
                        call.argument<String>("title").orEmpty(),
                        body,
                        call.argument<String>("channelName").orEmpty(),
                        call.argument<String>("channelDescription").orEmpty(),
                    ),
                )
            }
            "done" -> {
                result.success(null)
                main.post { finish() }
            }
            else -> result.notImplemented()
        }
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

    private fun finish() {
        main.removeCallbacks(overBudget)
        try {
            engine?.destroy()
        } catch (e: Exception) {
            Log.e(TAG, "could not stop the engine", e)
        }
        engine = null
        val done = params ?: return
        params = null
        // Never rescheduled from here: a failed check waits for the next
        // period or tick, which keeps a phone with no way out from trying
        // over and over.
        jobFinished(done, false)
    }

    override fun onStopJob(params: JobParameters): Boolean {
        main.removeCallbacks(overBudget)
        try {
            engine?.destroy()
        } catch (_: Exception) {
        }
        engine = null
        this.params = null
        // A check cut off because the phone went back to sleep, lost its
        // network or had to make room is tried again in the next window,
        // rather than a whole period later. One that ran out of time or
        // quota is not.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            // Let the next try start at once.
            getSharedPreferences(PREFS, MODE_PRIVATE).edit().remove(LAST_START_KEY).apply()
            return when (params.stopReason) {
                JobParameters.STOP_REASON_PREEMPT,
                JobParameters.STOP_REASON_DEVICE_STATE,
                JobParameters.STOP_REASON_CONSTRAINT_CONNECTIVITY,
                JobParameters.STOP_REASON_CONSTRAINT_DEVICE_IDLE,
                -> true
                else -> false
            }
        }
        return false
    }

    override fun onDestroy() {
        main.removeCallbacks(overBudget)
        try {
            engine?.destroy()
        } catch (_: Exception) {
        }
        engine = null
        params = null
        super.onDestroy()
    }

    companion object {
        private const val TAG = "FortivaNotices"

        /** Shared with lib/services/notice_channel.dart. */
        const val CHANNEL = "com.vpn.fortivavpn/notices"

        const val ENTRY_LIBRARY = "package:fortiva_vpn/services/notice_pull.dart"
        const val ENTRY_FUNCTION = "noticePullMain"

        /**
         * The longest one check may take. The Dart side gives up on its own
         * after 60 s; this is the backstop for an engine that hangs.
         */
        private val BUDGET_MS = TimeUnit.SECONDS.toMillis(90)

        private const val KNOCK_MS = 300

        private const val PREFS = "fortiva_notice_jobs"
        private const val LAST_START_KEY = "last_start"

        /** No second check within this long of one that started. */
        private val MIN_GAP_MS = TimeUnit.MINUTES.toMillis(4)
    }
}
