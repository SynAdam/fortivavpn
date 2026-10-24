package com.vpn.fortivavpn.handler

import android.content.Context
import android.os.SystemClock
import android.util.Log
import com.vpn.fortivavpn.AppConfig
import fortivacore.Fortivacore
import org.json.JSONObject
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.locks.ReentrantReadWriteLock

/**
 * The core's timed door check (Fortivacore.checkDoorTimed, backend issue
 * #365, item 1): the check measureOutboundDelay makes, with how far it got
 * on the sockets it opened to the door.
 *
 * The core sees those sockets through a system dialer it swaps in once, and
 * that swap is not safe while another check is dialling. So it is done on
 * a background thread when the activity starts, before Flutter can ask for
 * any check, and every core call in this process waits for it
 * ([awaitReady]). It is done only when the backend's last connection data
 * settings, saved by the Flutter side, turned timed checks on: otherwise the
 * core is not loaded early and every check runs as before.
 *
 * A run that started with no such setting, as a fresh install's first run
 * does, turns the timed check on as soon as Flutter adopts settings that ask
 * for it ([prepareLater]). Every core call holds [gate] for reading
 * ([usingCore]) and the late swap holds it for writing, so it waits for the
 * checks already dialling and holds back new ones until it is done.
 *
 * Nothing here runs in the tunnel's process.
 */
object DoorChecks {
    private const val TAG = AppConfig.TAG

    /** Where Flutter's SharedPreferences keeps its values, and the key of
     * the saved `connection_data` block (AppConfigState.connectionDataKey). */
    private const val FLUTTER_PREFS = "FlutterSharedPreferences"
    private const val SETTINGS_KEY = "flutter.remote_connection_data"

    /** The longest a core call waits for the preparation. It takes well
     * under a second; this only keeps a stuck one from holding checks. */
    private const val READY_WAIT_MS = 5_000L

    @Volatile private var started = false
    private val ready = CountDownLatch(1)

    /** Whether the timed check can run in this process. */
    @Volatile var timed = false
        private set

    /** Held for reading by every core call in this process, for writing by
     * the late swap. Fair, so new checks do not pass a waiting swap. */
    private val gate = ReentrantReadWriteLock(true)

    /** Whether a late swap was asked for in this run. */
    @Volatile private var later = false

    /** The swap itself. Tests put something else here. */
    internal var swapDialer: () -> Unit = { Fortivacore.prepareDoorChecks() }

    /** Starts the preparation when the saved settings ask for timed checks.
     * Call from the activity's onCreate. Later calls do nothing. The saved
     * settings are read on the preparation's own thread: the first read of
     * Flutter's preferences file parses all of it, and the main thread must
     * not wait for that. */
    @Synchronized
    fun prepare(context: Context) {
        if (started) return
        started = true
        val app = context.applicationContext
        Thread({
            try {
                val wanted = savedSettingWantsTimed(
                    app.getSharedPreferences(FLUTTER_PREFS, Context.MODE_PRIVATE)
                        .getString(SETTINGS_KEY, null)
                )
                if (wanted) {
                    Fortivacore.prepareDoorChecks()
                    timed = true
                }
            } catch (t: Throwable) {
                Log.w(TAG, "[doors] the timed check could not be prepared", t)
            } finally {
                ready.countDown()
            }
        }, "door-checks-prepare").start()
    }

    /**
     * Turn the timed check on now, in a run that started without it. Flutter
     * calls this when it adopts the backend's connection data settings with
     * timed checks on (prepareTimedChecks). The swap waits on its own thread
     * for the checks already dialling and holds back new ones while it runs,
     * so no check dials while the dialer changes. Asked once per run; a run
     * that has the timed check already does nothing.
     */
    @Synchronized
    fun prepareLater() {
        if (timed || later) return
        later = true
        Thread({
            gate.writeLock().lock()
            try {
                swapDialer()
                timed = true
            } catch (t: Throwable) {
                Log.w(TAG, "[doors] the timed check could not be prepared later", t)
            } finally {
                gate.writeLock().unlock()
            }
        }, "door-checks-prepare-later").start()
    }

    /** Run [block], a call into the core, once the preparation is done and
     * never while the dialer is being swapped. */
    fun <T> usingCore(block: () -> T): T {
        awaitReady()
        gate.readLock().lock()
        try {
            return block()
        } finally {
            gate.readLock().unlock()
        }
    }

    /** For tests: back to a run that has not prepared anything. */
    internal fun forgetForTests() {
        timed = false
        later = false
        swapDialer = { Fortivacore.prepareDoorChecks() }
    }

    /** The reading of a timed check that gave no answer within the wait:
     * closed, in the words the app uses for its own wait. */
    fun noAnswer(timeoutMs: Long): Map<String, Any?> =
        mapOf("timed" to true, "ms" to -1L, "error" to "no answer in $timeoutMs ms")

    /** Waits until the preparation is done, when one was started. Every
     * core call in this process goes through here first. */
    fun awaitReady() {
        if (!started) return
        try {
            ready.await(READY_WAIT_MS, TimeUnit.MILLISECONDS)
        } catch (e: InterruptedException) {
            Thread.currentThread().interrupt()
        }
    }

    /**
     * The timed check's JSON for [config], or null when it cannot run.
     *
     * [deadline] is when the caller's wait of [timeoutMs] ends, on
     * SystemClock.elapsedRealtime(). The core is given what is left of it,
     * so time spent queued or waiting for the preparation counts, as it does
     * for the plain check. With nothing left the check does not start and
     * reads as no answer.
     */
    fun check(config: String, url: String, timeoutMs: Long, deadline: Long): String? {
        awaitReady()
        if (!timed) return null
        val left = deadline - SystemClock.elapsedRealtime()
        if (left <= 0) return noAnswerJson(timeoutMs)
        return try {
            inTheCallersWords(usingCore { Fortivacore.checkDoorTimed(config, url, left) }, timeoutMs)
        } catch (t: Throwable) {
            Log.w(TAG, "[doors] the timed check failed to run", t)
            null
        }
    }

    private const val NO_ANSWER = "no answer in "

    private fun noAnswerJson(timeoutMs: Long): String =
        JSONObject().put("ms", -1L).put("error", "$NO_ANSWER$timeoutMs ms").toString()

    /** [json] with the core's "no answer in N ms", where N is what was left
     * of the wait, said with the caller's whole wait, as the plain check
     * says it. Anything else is returned as it is. */
    fun inTheCallersWords(json: String?, timeoutMs: Long): String? {
        if (json.isNullOrBlank()) return json
        return try {
            val o = JSONObject(json)
            if (!o.optString("error", "").startsWith(NO_ANSWER)) return json
            o.put("error", "$NO_ANSWER$timeoutMs ms").toString()
        } catch (e: Exception) {
            json
        }
    }

    /** Whether the saved `connection_data` JSON turns timed checks on. */
    fun savedSettingWantsTimed(saved: String?): Boolean {
        if (saved.isNullOrBlank()) return false
        return try {
            JSONObject(saved).optBoolean("timed_checks", false)
        } catch (e: Exception) {
            false
        }
    }

    /**
     * The keys realPingDetail adds to its map from a timed check's [json]:
     * `ms`, `error` (shortened) and the timeline, with `timed` true. Null
     * when [json] is not a result the core writes, so the caller falls back
     * to the plain check's words.
     */
    fun readingOf(json: String?): Map<String, Any?>? {
        if (json.isNullOrBlank()) return null
        val o = try {
            JSONObject(json)
        } catch (e: Exception) {
            return null
        }
        if (!o.has("ms")) return null
        val out = mutableMapOf<String, Any?>("timed" to true, "ms" to o.optLong("ms", -1L))
        for ((key, name) in TIMELINE_KEYS) {
            if (o.has(key) && !o.isNull(key)) out[name] = o.optLong(key)
        }
        val phase = o.optString("phase", "")
        if (phase.isNotEmpty()) out["phase"] = phase
        val error = o.optString("error", "")
        if (error.isNotEmpty()) out["error"] = DoorCheck.shorten(error)
        return out
    }

    /** The core's JSON keys and the map keys the Flutter side reads. */
    private val TIMELINE_KEYS = listOf(
        "boot_ms" to "bootMs",
        "cold_ms" to "coldMs",
        "dns_ms" to "dnsMs",
        "dial_ms" to "dialMs",
        "first_byte_ms" to "firstByteMs",
        "tls_ms" to "tlsMs",
        "reply_ms" to "replyMs",
        "bytes_out" to "bytesOut",
        "bytes_in" to "bytesIn",
        "dials" to "dials",
        "dial_fails" to "dialFails",
    )
}
