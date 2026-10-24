package com.vpn.fortivavpn.handler

import android.util.Log
import com.vpn.fortivavpn.AppConfig

/**
 * Collects the domains the VPN core sniffed from the user's own traffic, for
 * the aggregate operator Sites view.
 *
 * libv2ray writes the core's log to Android's logcat (tag "GoLog"), not to a
 * file, at Android priority Info whatever the core's own level is. The config
 * builders leave that level at info or debug, and both emit the core's one
 * "sniffed domain: <host>" line per connection. [drain] reads the app's own
 * logcat for those lines since the last drain, counts each host, and advances
 * a cursor so a line is not counted twice. Only the counts leave the phone
 * (see the Dart side); the log never does. Reading one's own logcat needs no
 * permission on a non-rooted device, and the VPN core shares this app's uid,
 * so its lines are visible here.
 *
 * Only connections that went through the tunnel are counted. The core sniffs
 * a connection before it picks the route, so the sniffed line alone does not
 * say whether the site went through Fortiva: Iranian sites go direct (the
 * white_iran routing preset), and 1.6.13 and older counted them anyway. On
 * 2026-10-07 eitaa.com, rubika.ir and divar.ir were in the Sites view's top
 * ten. Right after the sniffed line the core logs its route under the same
 * session id, "taking detour [<tag>]" or "default route", and a host is
 * counted only when that route is not direct or block. Matching the route
 * rather than the domain lists also covers sites that go direct because of
 * their Iranian IP address, which no name list can show.
 *
 * The cursor is persisted. The tunnel runs in its own process and keeps
 * logging while Android is free to kill this one, so a cursor held only in
 * memory would come back empty mid-session and the next drain would re-read
 * the whole buffer, counting again every domain the backend already has and
 * inflating the numbers this feeds.
 */
object SiteStats {
    private val SNIFFED = Regex("""\[(\d+)] app/dispatcher: sniffed domain: (\S+)""")
    private val ROUTED = Regex("""\[(\d+)] app/dispatcher: (?:taking detour \[([^\]]*)]|default route for)""")
    private val TIMESTAMP = Regex("""^(\d\d-\d\d \d\d:\d\d:\d\d\.\d\d\d)""")

    /** Routes whose traffic never enters the tunnel. */
    private val OUTSIDE_TUNNEL = setOf(AppConfig.TAG_DIRECT, AppConfig.TAG_BLOCKED)

    /** The most sniffed connections kept for a route line in the next drain. */
    private const val MAX_WAITING = 1000

    // The logcat timestamp of the last line read, so the next drain starts
    // after it rather than re-reading the whole buffer. Null here means "not
    // loaded from storage yet", which is not the same as "no cursor".
    @Volatile
    private var cursor: String? = null

    // Connections the last drain saw sniffed but not yet routed, by session
    // id: a drain can read the log between the two lines. Kept in memory
    // only; losing them to a restart loses a few counts, never adds one.
    private var waiting: Map<String, String> = emptyMap()

    /** Where the next drain starts, surviving a restart of this process. */
    private fun mark(): String? {
        cursor?.let { return it }
        val stored = MmkvManager.decodeSettingsString(AppConfig.PREF_SITE_STATS_CURSOR)
        cursor = stored
        return stored
    }

    private fun advance(to: String) {
        cursor = to
        MmkvManager.encodeSettings(AppConfig.PREF_SITE_STATS_CURSOR, to)
    }

    /**
     * What one drain found: visits per host that went through the tunnel, and
     * the connections sniffed in it whose route was not logged yet.
     */
    internal class Tally(val counts: Map<String, Int>, val waiting: Map<String, String>)

    /**
     * Counts the hosts in [lines] whose connection went through the tunnel.
     * [carried] is the last drain's [Tally.waiting]. A carried connection
     * whose route is still missing is dropped: which way it went is unknown,
     * and the view counts only tunnel traffic.
     */
    internal fun tally(lines: Sequence<String>, carried: Map<String, String>): Tally {
        val counts = HashMap<String, Int>()
        val sniffed = LinkedHashMap(carried)
        val fresh = HashSet<String>()
        for (line in lines) {
            val site = SNIFFED.find(line)
            if (site != null) {
                val host = site.groupValues[2].lowercase().trimEnd('.')
                if (host.isNotEmpty()) {
                    sniffed[site.groupValues[1]] = host
                    fresh.add(site.groupValues[1])
                }
                continue
            }
            val route = ROUTED.find(line) ?: continue
            val host = sniffed.remove(route.groupValues[1]) ?: continue
            // "default route" leaves the tag group empty, and that route is
            // the tunnel.
            if (route.groupValues[2] in OUTSIDE_TUNNEL) continue
            counts[host] = (counts[host] ?: 0) + 1
        }
        val waiting = sniffed.entries
            .filter { it.key in fresh }
            .takeLast(MAX_WAITING)
            .associate { it.key to it.value }
        return Tally(counts, waiting)
    }

    @Synchronized
    fun drain(): Map<String, Int> {
        try {
            // Only the GoLog tag, so the dump is bounded by the core's log, not
            // the whole device buffer. "-t N" cannot be used to bound it: it
            // tails the raw buffer before the tag filter and would return
            // almost nothing. The first drain (no cursor) reads all GoLog in
            // the buffer, which is only this session's; later drains read from
            // the cursor with "-T".
            val cmd = mutableListOf("logcat", "-d", "-v", "time", "-b", "main")
            val mark = mark()
            if (mark != null) {
                cmd.add("-T")
                cmd.add(mark)
            }
            cmd.add("GoLog:I")
            cmd.add("*:S")
            val process = ProcessBuilder(cmd).redirectErrorStream(true).start()
            var last: String? = null
            val found = process.inputStream.bufferedReader().useLines { all ->
                val read = all.filter { line ->
                    val ts = TIMESTAMP.find(line)?.groupValues?.get(1) ?: return@filter true
                    // "-T <ts>" is inclusive, so the one line at the cursor is
                    // seen again; skip it rather than count it twice.
                    if (mark != null && ts == mark) return@filter false
                    last = ts
                    true
                }
                tally(read, waiting)
            }
            process.waitFor()
            waiting = found.waiting
            last?.let { advance(it) }
            return found.counts
        } catch (e: Exception) {
            Log.w(AppConfig.TAG, "SiteStats: could not read the sniffed-domain log", e)
            return emptyMap()
        }
    }
}
