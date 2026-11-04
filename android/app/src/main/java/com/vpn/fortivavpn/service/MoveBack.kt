package com.vpn.fortivavpn.service

import android.util.Log
import com.vpn.fortivavpn.AppConfig
import com.vpn.fortivavpn.handler.V2rayConfigManager
import fortivacore.Fortivacore
import org.json.JSONArray
import org.json.JSONObject
import java.util.concurrent.Executors
import java.util.concurrent.ScheduledExecutorService
import java.util.concurrent.TimeUnit

/**
 * The move back to our servers, in the tunnel's process, while the tunnel
 * runs on a community link with some of our own doors held behind it (the
 * app's StandbyDoors.ownBehind).
 *
 * The core ranks every other door behind ours (V2rayConfigManager,
 * OWN_FIRST_PENALTY_MS), so it moves new connections to one of our doors
 * as soon as that door answers its probes, with no drop: connections
 * already open stay where they are until they close. On its own the core
 * measures a dead door again only after minutes. With the backend's
 * interval, this asks it to measure them all again now
 * (Fortivacore.autoSelectNetworkChanged), every interval but never sooner
 * than the core's idle time after the last ask (see below). That also
 * lets it move at once rather than after its usual wait between moves.
 *
 * It counts the moves back ([moveBacks]), which the stats reply carries to
 * the app and the app to the backend in its heartbeat, so the ones made
 * while the app was away are counted too.
 *
 * After a move from one of our doors back to a community link because ours
 * failed, it holds off for a while before the next check: a door that
 * answers probes and then fails real traffic would otherwise move the
 * phone to and fro. The hold starts at one interval and doubles after each
 * such move, up to the core's own longest wait for a dead door.
 *
 * A check marks the group busy, as a new connection does, so the core
 * cannot call the group idle for [CORE_IDLE_AFTER_MS] after it. Within
 * that time a busy group says nothing about whether the phone is in use,
 * so the next check waits until that time has passed. On a phone nobody
 * uses, the group then goes idle and the checks stop until it carries
 * traffic again.
 */
object MoveBack {
    private const val TAG = AppConfig.TAG

    /** The longest hold: the core's own longest wait for a dead door. */
    const val MAX_HOLD_MS = 10 * 60 * 1000L

    /**
     * How long the core's group goes without a new connection before it
     * counts as idle: the core's default (defaultIdleAfter in
     * android/core/patches/xray-autoselect.patch), which the app does not
     * change (V2rayConfigManager sets no idleAfter). The core sets the idle
     * flag on its own tick, every half second, hence [IDLE_MARGIN_MS].
     */
    const val CORE_IDLE_AFTER_MS = 3 * 60 * 1000L
    const val IDLE_MARGIN_MS = 5_000L

    /** One move of the core's group, by door position. */
    data class Move(val from: Int?, val to: Int?, val reason: String, val atMs: Long)

    /** What the move back has seen. */
    data class State(
        val seenUntil: Long = 0L,
        val moveBacks: Int = 0,
        val holdUntil: Long = 0L,
        val holdMs: Long = 0L,
        /** When this last asked the core to check, or 0. */
        val lastCheckAt: Long = 0L,
    )

    @Volatile
    private var own: Set<Int> = emptySet()

    @Volatile
    private var everyMs: Long = 0L

    private var state = State()
    private var executor: ScheduledExecutorService? = null

    /** Moves back to one of our doors since the core started. */
    val moveBacks: Int
        @Synchronized get() = state.moveBacks

    /** Whether our doors are held behind a community link in this core. */
    val active: Boolean get() = own.isNotEmpty()

    /**
     * Starts for a core that holds our doors at the positions in [doors],
     * behind a community link, as a group ([grouped]). Ticks every [everyS]
     * seconds when that is at least 30; otherwise only counts the moves.
     */
    @Synchronized
    fun start(doors: Set<Int>, everyS: Int?, grouped: Boolean) {
        stopLocked()
        if (!grouped || doors.isEmpty()) return
        own = doors
        everyMs = if (everyS != null && everyS >= 30) everyS * 1000L else 0L
        state = State()
        if (everyMs == 0L) return
        val ticker = Executors.newSingleThreadScheduledExecutor { r ->
            Thread(r, "move-back").apply { isDaemon = true }
        }
        executor = ticker
        ticker.scheduleWithFixedDelay(::tick, everyMs, everyMs, TimeUnit.MILLISECONDS)
    }

    @Synchronized
    fun stop() = stopLocked()

    private fun stopLocked() {
        executor?.shutdownNow()
        executor = null
        own = emptySet()
        everyMs = 0L
        state = State()
    }

    /** One tick: read the group, note its moves, and ask for a check when due. */
    private fun tick() {
        try {
            if (!V2RayServiceManager.isRunning()) return
            val group = proxyGroup(Fortivacore.autoSelectStatus()) ?: return
            val kick = synchronized(this) {
                val now = System.currentTimeMillis()
                state = observe(state, moves(group), own, everyMs, now)
                val due = decide(state, selected(group), group.optString("state"), own, now)
                if (due) state = state.copy(lastCheckAt = now)
                due
            }
            if (kick) {
                Log.d(TAG, "[move-back] asking the core to check our doors again")
                V2RayServiceManager.networkChanged()
            }
        } catch (e: Exception) {
            Log.w(TAG, "[move-back] a check failed", e)
        }
    }

    /** Notes the moves of [group], from a status read made elsewhere. */
    @Synchronized
    fun observe(group: JSONObject) {
        if (own.isEmpty()) return
        state = observe(state, moves(group), own, everyMs, System.currentTimeMillis())
    }

    /**
     * [state] after [moves], the group's recent moves, oldest first: each
     * move from a door not in [own] to one in it counts once, and a move
     * from one of ours to another door because ours failed starts or
     * doubles the hold. The core's first pick, which left no door, is not
     * a move. Moves at or before [State.seenUntil] were seen already.
     */
    fun observe(state: State, moves: List<Move>, own: Set<Int>, everyMs: Long, nowMs: Long): State {
        var next = state
        for (move in moves) {
            if (move.atMs <= next.seenUntil) continue
            next = next.copy(seenUntil = move.atMs)
            val from = move.from ?: continue
            val to = move.to ?: continue
            val fromOwn = from in own
            val toOwn = to in own
            if (!fromOwn && toOwn) {
                next = next.copy(moveBacks = next.moveBacks + 1)
            } else if (fromOwn && !toOwn && move.reason != "faster" && everyMs > 0) {
                val hold = if (next.holdMs == 0L) everyMs else minOf(next.holdMs * 2, MAX_HOLD_MS)
                next = next.copy(holdMs = hold, holdUntil = nowMs + hold)
            }
        }
        return next
    }

    /**
     * Whether to ask the core to check its doors again now: the door in use
     * is not one of ours, the group is carrying traffic (an idle group is
     * left alone, so a phone that is not used wakes nothing), no hold is in
     * force, and the last check was long enough ago that the core could
     * have called the group idle since ([CORE_IDLE_AFTER_MS]). Without that
     * last rule each check would keep the group busy for the next one, and
     * a phone nobody uses would check every door all night.
     */
    fun decide(state: State, selected: Int?, groupState: String, own: Set<Int>, nowMs: Long): Boolean {
        if (own.isEmpty()) return false
        if (selected != null && selected in own) return false
        if (groupState == "idle") return false
        if (state.lastCheckAt > 0 && nowMs - state.lastCheckAt < CORE_IDLE_AFTER_MS + IDLE_MARGIN_MS) {
            return false
        }
        return nowMs >= state.holdUntil
    }

    private fun proxyGroup(raw: String): JSONObject? {
        val groups = JSONArray(raw)
        for (i in 0 until groups.length()) {
            val group = groups.getJSONObject(i)
            if (group.optString("tag") == AppConfig.TAG_PROXY) return group
        }
        return null
    }

    private fun selected(group: JSONObject): Int? =
        V2rayConfigManager.autoSelectMemberIndex(group.optString("selected"))

    /** The group's moves, by door position, as the core lists them. */
    fun moves(group: JSONObject): List<Move> {
        val events = group.optJSONArray("events") ?: return emptyList()
        return (0 until events.length()).map { i ->
            val e = events.getJSONObject(i)
            Move(
                from = V2rayConfigManager.autoSelectMemberIndex(e.optString("from")),
                to = V2rayConfigManager.autoSelectMemberIndex(e.optString("to")),
                reason = e.optString("reason"),
                atMs = e.optLong("atMs"),
            )
        }.sortedBy { it.atMs }
    }
}
