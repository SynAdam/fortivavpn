package com.vpn.fortivavpn.service

import android.app.AlarmManager
import android.app.PendingIntent
import android.app.job.JobInfo
import android.app.job.JobScheduler
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.PersistableBundle
import android.os.SystemClock
import android.util.Log
import com.tencent.mmkv.MMKV
import com.vpn.fortivavpn.receiver.NoticeWakeReceiver
import java.util.concurrent.TimeUnit

/**
 * When the phone checks for messages from the Fortiva team while the app is
 * not on screen. Each check is one run of [NoticeJobService].
 *
 * Three triggers, besides the app's own check on launch and resume:
 *
 * - A wake-up alarm about every [ALARM_MS] ([armAlarm]), on Android 12 and
 *   later, while notifications are allowed. It is the one that still fires
 *   while the phone sleeps: Android holds jobs in Doze for windows that
 *   start an hour apart and grow to six, but lets an allow-while-idle alarm
 *   through, a few times an hour. The alarm starts an expedited job
 *   ([runFromAlarm]), which runs in Doze. Before Android 12 there is no
 *   expedited job, so the alarm would wake the phone for nothing.
 * - A periodic job, every 15 minutes at best, the shortest period Android
 *   allows. It covers phones whose alarms Android limits.
 * - While the tunnel is up, the tunnel's process asks for a check a minute
 *   after it comes up and every [TICK_MS] after that ([startTicking]).
 *
 * None of them survives a reboot or a force stop: that would need
 * RECEIVE_BOOT_COMPLETED, which the app does not ask for. [ensureScheduled]
 * puts them back from every place the app starts: the app's own process,
 * the tunnel, the widget and the quick settings tile, and an app update.
 */
object NoticeJobs {
    private const val TAG = "FortivaNotices"

    /** Ids within this app's uid. Kept apart from anything else it schedules. */
    const val PERIODIC_ID = 26_401
    const val SOON_ID = 26_402
    const val ALARM_ID = 26_403

    /**
     * Bumped whenever the periodic job's definition changes, so phones that
     * update the app schedule the new one instead of keeping the old.
     */
    private const val SPEC = 2
    private const val SPEC_KEY = "spec"

    private val PERIOD_MS = TimeUnit.MINUTES.toMillis(15)
    private val FLEX_MS = TimeUnit.MINUTES.toMillis(5)

    /** How often the wake-up alarm fires. Android allows a few an hour in Doze. */
    private val ALARM_MS = TimeUnit.MINUTES.toMillis(10)

    /** How often the tunnel's process asks for a check while it is up. */
    private val TICK_MS = TimeUnit.MINUTES.toMillis(5)

    /** The first check after the tunnel comes up. */
    private val FIRST_TICK_MS = TimeUnit.MINUTES.toMillis(1)

    private val SOON_DELAY_MS = TimeUnit.SECONDS.toMillis(1)

    /**
     * The periodic job and, while notifications can show, the alarm, unless
     * they are already set. The periodic job runs either way: it keeps the
     * Messages screen current.
     */
    fun ensureScheduled(context: Context) {
        schedulePeriodic(context)
        if (NoticeNotifier.allowed(context)) armAlarm(context, replace = false)
    }

    /**
     * Schedule the periodic check, unless the same one is already scheduled.
     * One scheduled by an older build is replaced.
     */
    fun schedulePeriodic(context: Context) {
        val scheduler = scheduler(context) ?: return
        val existing = pending(scheduler, PERIODIC_ID)
        if (existing != null && existing.extras.getInt(SPEC_KEY, 0) == SPEC) return
        val builder = JobInfo.Builder(PERIODIC_ID, component(context))
            .setExtras(PersistableBundle().apply { putInt(SPEC_KEY, SPEC) })
        requireAnyInternet(builder)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            builder.setPeriodic(PERIOD_MS, FLEX_MS)
        } else {
            builder.setPeriodic(PERIOD_MS)
        }
        schedule(scheduler, builder.build())
    }

    /**
     * Any network that says it has internet, checked or not. The plain
     * NETWORK_TYPE_ANY also requires the network to have passed Google's
     * connectivity check, which fails on networks that block Google while
     * our relays and the public file still answer.
     */
    private fun requireAnyInternet(builder: JobInfo.Builder) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            builder.setRequiredNetwork(
                NetworkRequest.Builder()
                    .addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
                    .removeCapability(NetworkCapabilities.NET_CAPABILITY_NOT_VPN)
                    .build(),
            )
        } else {
            builder.setRequiredNetworkType(JobInfo.NETWORK_TYPE_ANY)
        }
    }

    /**
     * Ask for one check now. Nothing happens while one is waiting or
     * running: scheduling a job under the id of a running one would stop it.
     *
     * The tunnel's process asks for this while the tunnel is up, and so does
     * the alarm then, so the job asks for no network. With one, it would
     * never run: the job scheduler judges an app's network by the VPN's,
     * and this app is left out of its own VPN, so the network never counts
     * as there (seen on Android 16, 2026-10-12). A short delay is the job's
     * one constraint, because Android refuses a job with none.
     */
    fun runSoon(context: Context) {
        val scheduler = scheduler(context) ?: return
        if (pending(scheduler, SOON_ID) != null) return
        val job = JobInfo.Builder(SOON_ID, component(context))
            .setMinimumLatency(SOON_DELAY_MS)
            .build()
        schedule(scheduler, job)
    }

    /**
     * The check the wake-up alarm starts: an expedited job, which Android
     * lets run while the phone sleeps. It asks for any network with
     * internet, which keeps its network through Doze. With this app's own
     * tunnel up, that network would never count as there (see [runSoon]), so
     * it asks for none; the tunnel's foreground service keeps the app's
     * network then. Another app's VPN carries this app, so it is treated as
     * any network.
     */
    fun runFromAlarm(context: Context) {
        val ownTunnel = ownTunnelUp(context)
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
            if (ownTunnel) runSoon(context) else runRegular(context)
            return
        }
        val scheduler = scheduler(context) ?: return
        if (pending(scheduler, ALARM_ID) != null) return
        val expedited = JobInfo.Builder(ALARM_ID, component(context)).setExpedited(true)
        if (!ownTunnel) requireAnyInternet(expedited)
        try {
            if (scheduler.schedule(expedited.build()) == JobScheduler.RESULT_SUCCESS) return
        } catch (e: Exception) {
            // Out of expedited quota, or refused for another reason.
            Log.w(TAG, "expedited check refused", e)
        }
        if (ownTunnel) runSoon(context) else runRegular(context)
    }

    /** A plain one-off check that waits for any network with internet. */
    private fun runRegular(context: Context) {
        val scheduler = scheduler(context) ?: return
        if (pending(scheduler, ALARM_ID) != null) return
        val regular = JobInfo.Builder(ALARM_ID, component(context))
        requireAnyInternet(regular)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            regular.setPriority(JobInfo.PRIORITY_HIGH)
        }
        schedule(scheduler, regular.build())
    }

    /**
     * Set the next wake-up alarm, [ALARM_MS] from now. With [replace] false,
     * an alarm already set is kept, so starting the app often does not keep
     * pushing it later.
     */
    fun armAlarm(context: Context, replace: Boolean = true) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return
        try {
            val alarms = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
            val intent = alarmIntent(context)
            // A force stop clears the alarm but, before Android 15, can leave
            // its PendingIntent behind, so the saved due time decides too.
            if (!replace &&
                PendingIntent.getBroadcast(context, ALARM_ID, intent, PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE) != null &&
                alarmDue() > System.currentTimeMillis() - ALARM_MS
            ) {
                return
            }
            val operation = PendingIntent.getBroadcast(
                context,
                ALARM_ID,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            // Inexact: no exact-alarm permission, and Android may move it a
            // little to batch it with others.
            alarms.setAndAllowWhileIdle(
                AlarmManager.ELAPSED_REALTIME_WAKEUP,
                SystemClock.elapsedRealtime() + ALARM_MS,
                operation,
            )
            store()?.encode(ALARM_DUE_KEY, System.currentTimeMillis() + ALARM_MS)
        } catch (e: Exception) {
            Log.e(TAG, "could not set the wake-up alarm", e)
        }
    }

    /**
     * Stop the alarm, for a phone where notifications cannot show: it would
     * wake the phone for a check whose notification nobody sees. The
     * periodic job stays. [ensureScheduled] sets the alarm again once they
     * are allowed.
     */
    fun cancelAlarm(context: Context) {
        try {
            val intent = alarmIntent(context)
            val existing = PendingIntent.getBroadcast(
                context,
                ALARM_ID,
                intent,
                PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE,
            ) ?: return
            (context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager)?.cancel(existing)
            existing.cancel()
            store()?.removeValueForKey(ALARM_DUE_KEY)
        } catch (e: Exception) {
            Log.e(TAG, "could not cancel the wake-up alarm", e)
        }
    }

    private fun alarmIntent(context: Context) =
        Intent(context, NoticeWakeReceiver::class.java).setAction(NoticeWakeReceiver.ACTION_ALARM)

    private const val ALARM_DUE_KEY = "alarm_due"

    /** Shared by the app's process and the tunnel's, which both set the alarm. */
    private fun store(): MMKV? =
        try {
            MMKV.mmkvWithID("notice_jobs", MMKV.MULTI_PROCESS_MODE)
        } catch (e: Exception) {
            null
        }

    private fun alarmDue(): Long = store()?.decodeLong(ALARM_DUE_KEY, 0L) ?: 0L

    /**
     * Whether this app's own tunnel is up. Android names a VPN's owner only
     * to the app that owns it, so the owner check is true for ours alone.
     * Before Android 10 there is no owner to read, and any VPN counts.
     */
    private fun ownTunnelUp(context: Context): Boolean =
        try {
            val cm = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
            @Suppress("DEPRECATION")
            cm.allNetworks.any {
                val caps = cm.getNetworkCapabilities(it)
                caps?.hasTransport(NetworkCapabilities.TRANSPORT_VPN) == true &&
                    (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q || caps.ownerUid == android.os.Process.myUid())
            }
        } catch (_: Exception) {
            false
        }

    private val ticker = Handler(Looper.getMainLooper())
    private var tickContext: Context? = null
    private val tick = object : Runnable {
        override fun run() {
            // No check whose notification nobody would see; the app checks
            // for itself when it is opened.
            tickContext?.let { if (NoticeNotifier.allowed(it)) runSoon(it) }
            ticker.postDelayed(this, TICK_MS)
        }
    }

    /**
     * Start asking for checks while the tunnel is up. Called by the tunnel's
     * service in its own process when the core starts. A second call starts
     * the count again rather than adding a second ticker.
     */
    fun startTicking(context: Context) {
        val app = context.applicationContext
        ticker.post {
            tickContext = app
            ticker.removeCallbacks(tick)
            ticker.postDelayed(tick, FIRST_TICK_MS)
        }
        ensureScheduled(app)
    }

    /** Stop the checks [startTicking] started. The periodic job and the alarm stay. */
    fun stopTicking() {
        ticker.post {
            ticker.removeCallbacks(tick)
            tickContext = null
        }
    }

    private fun scheduler(context: Context): JobScheduler? =
        try {
            context.getSystemService(Context.JOB_SCHEDULER_SERVICE) as? JobScheduler
        } catch (e: Exception) {
            Log.e(TAG, "no job scheduler", e)
            null
        }

    private fun component(context: Context) = ComponentName(context, NoticeJobService::class.java)

    /** Job [id] while it is waiting or running, else null. */
    private fun pending(scheduler: JobScheduler, id: Int): JobInfo? =
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                scheduler.getPendingJob(id)
            } else {
                scheduler.allPendingJobs.firstOrNull { it.id == id }
            }
        } catch (e: Exception) {
            Log.e(TAG, "could not read the scheduled jobs", e)
            null
        }

    private fun schedule(scheduler: JobScheduler, job: JobInfo) {
        try {
            if (scheduler.schedule(job) != JobScheduler.RESULT_SUCCESS) {
                Log.w(TAG, "job ${job.id} was not scheduled")
            }
        } catch (e: Exception) {
            // Too many jobs, or a system that refuses them. The app's own
            // check on launch and resume still runs.
            Log.e(TAG, "could not schedule job ${job.id}", e)
        }
    }
}
