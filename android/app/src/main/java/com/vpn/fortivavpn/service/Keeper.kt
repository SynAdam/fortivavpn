package com.vpn.fortivavpn.service

import android.app.job.JobInfo
import android.app.job.JobScheduler
import android.content.ComponentName
import android.content.Context
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.util.Log
import java.util.concurrent.TimeUnit

/**
 * Keeps the heartbeat and the dead tunnel check going while the app's own
 * engine is gone and the tunnel runs on.
 *
 * Both live in the app's Flutter engine, in the main process, and Android
 * can end that process while the tunnel keeps running in its own: low
 * memory, a swipe out of recents, a phone maker's battery saver. Then
 * nothing sent heartbeats and nothing noticed a tunnel that carried
 * nothing, sometimes for hours.
 *
 * The app's engine asks the tunnel for its counters at least every five
 * minutes while it runs (the heartbeat; the dead tunnel check asks every
 * minute). So the tunnel's process, which this runs in, notes when the app
 * last asked. When the app has been silent for [APP_SILENT_MS], it starts
 * the keeper (KeeperJobService) in the main process: a Flutter engine with
 * no screen that sends one heartbeat and runs one dead tunnel check with
 * the app's own Dart code, then stops. It asks again every [TICK_MS] while
 * the app stays silent.
 */
object Keeper {
    private const val TAG = "FortivaKeeper"

    /** The job id, apart from NoticeJobs' ids. */
    const val JOB_ID = 4730

    /** How often the tunnel's process looks. */
    private val TICK_MS = TimeUnit.MINUTES.toMillis(5)

    /**
     * How long the app may go without asking for the counters before the
     * keeper takes over: longer than the heartbeat's five minutes, so an app
     * whose dead tunnel check is off is not taken for gone.
     */
    val APP_SILENT_MS = TimeUnit.MINUTES.toMillis(7)

    private val SOON_DELAY_MS = TimeUnit.SECONDS.toMillis(1)

    /**
     * How long a keeper job may wait without starting before it is asked for
     * again. On an Android 14 emulator on 2026-10-16 one job stayed ready
     * and was never started for over ten minutes, and while it waited every
     * later tick saw it there and asked for nothing.
     */
    val STUCK_MS = TICK_MS - TimeUnit.SECONDS.toMillis(30)

    @Volatile
    private var lastAppAskAt = 0L

    /** When this process last asked for a keeper job. */
    @Volatile
    private var scheduledAt = 0L

    /** When a keeper run last asked for the counters. */
    @Volatile
    private var lastKeeperAskAt = 0L

    private val ticker by lazy { Handler(Looper.getMainLooper()) }
    private var tickContext: Context? = null
    private val tick = object : Runnable {
        override fun run() {
            tickContext?.let { context ->
                if (appSilent(SystemClock.elapsedRealtime(), lastAppAskAt, APP_SILENT_MS)) {
                    runSoon(context)
                }
            }
            ticker.postDelayed(this, TICK_MS)
        }
    }

    /** The app's engine asked for the counters just now. */
    fun noteAppAsked() {
        lastAppAskAt = SystemClock.elapsedRealtime()
    }

    /** A keeper run asked for the counters just now: its job has started. */
    fun noteKeeperAsked() {
        lastKeeperAskAt = SystemClock.elapsedRealtime()
    }

    /**
     * Whether the job asked for at [scheduledAt] is still waiting at [now]
     * without having started: no run asked for the counters since, and it
     * has waited [stuckMs]. Asking again replaces it. A job that has started
     * is left alone, because asking again would stop it.
     */
    fun jobStuck(now: Long, scheduledAt: Long, keeperAskedAt: Long, stuckMs: Long): Boolean =
        scheduledAt > 0 && keeperAskedAt < scheduledAt && now - scheduledAt >= stuckMs

    /**
     * Whether the app has not asked for [silentMs] by [now]. Both times are
     * on the clock that counts from boot.
     */
    fun appSilent(now: Long, lastAsk: Long, silentMs: Long): Boolean = now - lastAsk >= silentMs

    /**
     * Start looking while the tunnel is up. Called by the tunnel's service
     * when the core starts. A new tunnel starts the count again: the app
     * that started it is there.
     */
    fun start(context: Context) {
        val app = context.applicationContext
        noteAppAsked()
        // A job left waiting from an earlier tunnel counts as asked for now,
        // so it too is asked for again if it never starts.
        scheduledAt = SystemClock.elapsedRealtime()
        ticker.post {
            tickContext = app
            ticker.removeCallbacks(tick)
            ticker.postDelayed(tick, TICK_MS)
        }
    }

    /** Stop looking. The tunnel is down. */
    fun stop() {
        ticker.post {
            ticker.removeCallbacks(tick)
            tickContext = null
        }
    }

    /**
     * Ask for one keeper run now, unless one waits or runs. A job that has
     * waited too long without starting is asked for again ([jobStuck]). No network
     * constraint, for the reason in NoticeJobs.runSoon: with this app's own
     * tunnel up, the job scheduler never counts its network as there.
     */
    private fun runSoon(context: Context) {
        val scheduler = try {
            context.getSystemService(Context.JOB_SCHEDULER_SERVICE) as? JobScheduler
        } catch (e: Exception) {
            null
        } ?: return
        try {
            val waiting = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                scheduler.getPendingJob(JOB_ID)
            } else {
                scheduler.allPendingJobs.firstOrNull { it.id == JOB_ID }
            }
            val now = SystemClock.elapsedRealtime()
            if (waiting != null) {
                if (!jobStuck(now, scheduledAt, lastKeeperAskAt, STUCK_MS)) return
                Log.w(TAG, "the keeper's job never started; asking again")
            }
            val job = JobInfo.Builder(JOB_ID, ComponentName(context, KeeperJobService::class.java))
                .setMinimumLatency(SOON_DELAY_MS)
                .build()
            if (scheduler.schedule(job) == JobScheduler.RESULT_SUCCESS) {
                scheduledAt = now
            } else {
                Log.w(TAG, "the keeper was not scheduled")
            }
        } catch (e: Exception) {
            Log.e(TAG, "could not schedule the keeper", e)
        }
    }
}
