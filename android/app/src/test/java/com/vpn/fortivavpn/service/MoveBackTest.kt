package com.vpn.fortivavpn.service

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * The move back to our doors from a community link (MoveBack): which moves
 * it counts, when it holds off, and when it asks the core to check again.
 * Door 0 is the community link, doors 2 and 3 are ours.
 */
class MoveBackTest {
    private val own = setOf(2, 3)
    private val every = 60_000L

    private fun move(from: Int?, to: Int, reason: String, at: Long) = MoveBack.Move(from, to, reason, at)

    @Test
    fun aMoveFromTheLinkToOneOfOursCountsOnce() {
        val moves = listOf(move(null, 0, "startup", 1), move(0, 2, "faster", 5))
        val once = MoveBack.observe(MoveBack.State(), moves, own, every, 10)
        assertEquals(1, once.moveBacks)
        assertEquals(5, once.seenUntil)
        // The core lists the same moves again on the next read.
        val again = MoveBack.observe(once, moves, own, every, 20)
        assertEquals(1, again.moveBacks)
    }

    @Test
    fun theStartAndMovesAmongOursAreNotMovesBack() {
        val moves = listOf(move(null, 2, "startup", 1), move(2, 3, "failover", 2), move(0, 1, "failover", 3))
        assertEquals(0, MoveBack.observe(MoveBack.State(), moves, own, every, 10).moveBacks)
    }

    @Test
    fun aFailoverFromOursHoldsOffAndTheHoldDoubles() {
        val first = MoveBack.observe(MoveBack.State(), listOf(move(2, 0, "failover", 1)), own, every, 1_000)
        assertEquals(every, first.holdMs)
        assertEquals(1_000 + every, first.holdUntil)
        val second = MoveBack.observe(first, listOf(move(2, 0, "failover", 2)), own, every, 2_000)
        assertEquals(2 * every, second.holdMs)
        var state = second
        for (i in 3..12) state = MoveBack.observe(state, listOf(move(3, 0, "failover", i.toLong())), own, every, 3_000)
        assertEquals(MoveBack.MAX_HOLD_MS, state.holdMs)
    }

    @Test
    fun withNoIntervalThereIsNoHold() {
        val state = MoveBack.observe(MoveBack.State(), listOf(move(2, 0, "failover", 1)), own, 0, 1_000)
        assertEquals(0, state.holdUntil)
    }

    @Test
    fun movesAcrossTheCoresListOfSixteenAreCountedByTime() {
        val first = (1..16).map { move(if (it % 2 == 0) 0 else 2, if (it % 2 == 0) 2 else 0, "faster", it.toLong()) }
        val state = MoveBack.observe(MoveBack.State(), first, own, 0, 100)
        assertEquals(8, state.moveBacks)
        // The list dropped its oldest moves and gained two new ones.
        val later = first.drop(2) + listOf(move(1, 3, "faster", 17), move(0, 2, "faster", 18))
        assertEquals(10, MoveBack.observe(state, later, own, 0, 200).moveBacks)
    }

    @Test
    fun itAsksForACheckOnlyOffOurDoorsWhileBusyAndNotHeld() {
        val free = MoveBack.State()
        assertTrue(MoveBack.decide(free, 0, "ok", own, 10))
        assertTrue(MoveBack.decide(free, 1, "degraded", own, 10))
        assertFalse(MoveBack.decide(free, 2, "ok", own, 10))
        assertFalse(MoveBack.decide(free, 0, "idle", own, 10))
        assertFalse(MoveBack.decide(free, 0, "ok", emptySet(), 10))
        val held = MoveBack.State(holdUntil = 100, holdMs = 60)
        assertFalse(MoveBack.decide(held, 0, "ok", own, 99))
        assertTrue(MoveBack.decide(held, 0, "ok", own, 100))
    }

    @Test
    fun afterACheckItWaitsUntilTheCoreCouldHaveCalledTheGroupIdle() {
        val checked = MoveBack.State(lastCheckAt = 1_000)
        val wait = MoveBack.CORE_IDLE_AFTER_MS + MoveBack.IDLE_MARGIN_MS
        assertFalse(MoveBack.decide(checked, 0, "ok", own, 1_000 + 60_000))
        assertFalse(MoveBack.decide(checked, 0, "ok", own, 1_000 + wait - 1))
        assertTrue(MoveBack.decide(checked, 0, "ok", own, 1_000 + wait))
    }

    /**
     * The core's group as the move back sees it: idle once it has gone
     * [MoveBack.CORE_IDLE_AFTER_MS] with no new connection, and a check
     * counts as one (Group.Kick sets lastTraffic). Ticks every [everyMs] for
     * [forMs] with new connections at [traffic], and returns the times of
     * the checks.
     */
    private fun run(everyMs: Long, forMs: Long, traffic: List<Long>): List<Long> {
        var state = MoveBack.State()
        var lastTraffic = 0L
        val checks = mutableListOf<Long>()
        var now = 0L
        while (now < forMs) {
            now += everyMs
            traffic.filter { it in (now - everyMs + 1)..now }.maxOrNull()?.let { lastTraffic = maxOf(lastTraffic, it) }
            val groupState = if (now - lastTraffic >= MoveBack.CORE_IDLE_AFTER_MS) "idle" else "ok"
            if (MoveBack.decide(state, 0, groupState, own, now)) {
                state = state.copy(lastCheckAt = now)
                lastTraffic = now
                checks += now
            }
        }
        return checks
    }

    @Test
    fun aPhoneNobodyUsesStopsCheckingSoonAfterItsLastConnection() {
        val hour = 60 * 60 * 1000L
        // The user stops at 30 s. Before this rule a 60 s interval checked
        // every door at every tick for as long as the phone was awake.
        assertEquals(listOf(60_000L), run(every, hour, listOf(30_000L)))
        assertEquals(listOf(30_000L), run(30_000L, hour, listOf(30_000L)))
    }

    @Test
    fun aPhoneInUseIsStillChecked() {
        val hour = 60 * 60 * 1000L
        // A new connection every 20 s for the whole hour.
        val busy = (1..180).map { it * 20_000L }
        val checks = run(every, hour, busy)
        assertTrue(checks.size >= 14)
        val gaps = checks.zipWithNext { a, b -> b - a }
        assertTrue(gaps.all { it >= MoveBack.CORE_IDLE_AFTER_MS })
        // Above the core's idle time the backend's interval is kept.
        val slow = run(5 * 60_000L, hour, busy)
        assertEquals(12, slow.size)
    }
}
