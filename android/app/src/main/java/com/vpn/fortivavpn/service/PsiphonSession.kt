package com.vpn.fortivavpn.service

import com.vpn.fortivavpn.AppConfig
import com.vpn.fortivavpn.dto.EConfigType
import com.vpn.fortivavpn.dto.ProfileItem
import com.vpn.fortivavpn.handler.MmkvManager
import com.vpn.fortivavpn.util.Utils
import org.json.JSONObject
import java.io.File

/**
 * A backup network session (the app's connectPsiphon call), as the tunnel's
 * process reads it on every start.
 *
 * The app writes it in its own process and the tunnel service runs in
 * another, so it lives in MMKV next to the selected profile. Android, the
 * tile, the widget, always-on and the notification's restart all start the
 * service from MMKV alone, and each of them has to bring the backup network
 * back up, not just a core pointed at a port nobody listens on.
 *
 * [guid] is the profile that points the core at the backup network's local
 * SOCKS proxy on [port]. The session counts only while that profile is the
 * selected one ([active]), so a normal connect that selected another
 * profile leaves it behind even before it is cleared.
 *
 * A start of the session that fails ends it ([forget]), and so does the
 * app's forgetPsiphon call ([forgetAll]). Either way nothing is left for
 * a later start of the service to bring back without the app's checks.
 *
 * [config] is the network config the app sent, as JSON. It is never logged.
 *
 * [entriesFile] is the absolute path of the network's server list that the
 * app keeps (PsiphonEntries on the Flutter side), or empty when the app
 * sent none. The library is handed it only when it can be read when the
 * library starts ([embeddedList]). Its contents are never read here.
 */
data class PsiphonSession(
    val guid: String,
    val port: Int,
    val config: String,
    val timeoutMs: Long,
    val entriesFile: String = "",
) {
    fun toJson(): String = JSONObject()
        .put(KEY_GUID, guid)
        .put(KEY_PORT, port)
        .put(KEY_CONFIG, config)
        .put(KEY_TIMEOUT_MS, timeoutMs)
        .put(KEY_ENTRIES_FILE, entriesFile)
        .toString()

    companion object {
        /** How long to wait for a tunnel when the app sent no wait. */
        const val DEFAULT_TIMEOUT_MS = 60_000L
        const val MIN_TIMEOUT_MS = 5_000L
        const val MAX_TIMEOUT_MS = 600_000L

        /**
         * The most a start without a server list waits for the library's
         * thread and for Psi.start (PsiphonCore.start). The thread can
         * still be stopping the last run, which takes seconds. A start
         * holds the tunnel service's start lock, so a library that never
         * returns must not hold every later connect with it.
         */
        const val START_WAIT_MS = 20_000L

        /** What the profile is called. The app never shows it. */
        const val REMARKS = "backup"

        private const val KEY_GUID = "guid"
        private const val KEY_PORT = "port"
        private const val KEY_CONFIG = "config"
        private const val KEY_TIMEOUT_MS = "timeout_ms"
        private const val KEY_ENTRIES_FILE = "entries_file"

        /**
         * The wait for a tunnel: [DEFAULT_TIMEOUT_MS] when the app sent none
         * or a wait of zero or less, and otherwise [ms] brought inside
         * [MIN_TIMEOUT_MS] and [MAX_TIMEOUT_MS].
         */
        fun timeoutOf(ms: Long?): Long =
            if (ms == null || ms <= 0L) DEFAULT_TIMEOUT_MS else ms.coerceIn(MIN_TIMEOUT_MS, MAX_TIMEOUT_MS)

        /** Whether [text] is a JSON object, which is what a network config must be. */
        fun isConfig(text: String?): Boolean {
            if (text.isNullOrBlank()) return false
            return try {
                JSONObject(text)
                true
            } catch (e: Exception) {
                false
            }
        }

        /** The session [toJson] wrote, or null for anything else. */
        fun fromJson(text: String?): PsiphonSession? {
            if (text.isNullOrBlank()) return null
            return try {
                val json = JSONObject(text)
                val guid = json.optString(KEY_GUID).takeIf { it.isNotBlank() } ?: return null
                val port = json.optInt(KEY_PORT, 0).takeIf { it in 1..65535 } ?: return null
                val config = json.optString(KEY_CONFIG).takeIf { isConfig(it) } ?: return null
                PsiphonSession(
                    guid,
                    port,
                    config,
                    timeoutOf(json.optLong(KEY_TIMEOUT_MS, 0L)),
                    entriesFileOf(json.optString(KEY_ENTRIES_FILE, "")),
                )
            } catch (e: Exception) {
                null
            }
        }

        /**
         * The server list path the app sent, as the session keeps it: an
         * absolute path, or empty for none or anything else.
         */
        fun entriesFileOf(path: String?): String =
            path?.takeIf { it.isNotBlank() && File(it).isAbsolute } ?: ""

        /**
         * What Psi.start is given as the server list's file name: [path]
         * when it names a file that can be read now, and otherwise empty,
         * which starts the library without a list, as before there was
         * one. A list the app deleted since the session was written is
         * then simply left out.
         */
        fun embeddedList(path: String): String {
            if (path.isEmpty()) return ""
            return try {
                val file = File(path)
                if (file.isAbsolute && file.isFile && file.canRead()) path else ""
            } catch (e: Exception) {
                ""
            }
        }

        /**
         * How long a start waits for Psi.start (PsiphonCore.start). [listed]
         * is whether the library is handed the server list
         * ([embeddedList]), and [timeoutMs] is the session's wait for a
         * tunnel.
         *
         * Without a list: [START_WAIT_MS], as before there was one. With a
         * list: the session's whole wait, and at least [START_WAIT_MS].
         * When the library's store has no servers yet, which is its first
         * start on the phone, Psi.start reads every entry of the list into
         * the store before it returns, one disk write per entry, and how
         * long that takes on a slow phone is not measured yet. The longer
         * wait does not hold a later connect: the start also ends as soon
         * as it is stopped or replaced.
         */
        fun startWaitMs(listed: Boolean, timeoutMs: Long): Long =
            if (listed) maxOf(START_WAIT_MS, timeoutMs) else START_WAIT_MS

        /**
         * The wait for the first tunnel after a start that took [startMs].
         *
         * Without a list: the session's [timeoutMs], as before there was
         * one. With a list, the start's time comes off it, so reading the
         * list and finding a tunnel together take no longer than
         * [timeoutMs], and the app's deadline for the whole start (the same
         * timeout plus VpnService.psiphonStartSlack on the Flutter side)
         * still holds. The library's own timeout
         * (EstablishTunnelTimeoutSeconds) starts only once the list is
         * read, so this wait can end first; that is a timeout like any
         * other.
         */
        fun tunnelWaitMs(listed: Boolean, timeoutMs: Long, startMs: Long): Long =
            if (listed) (timeoutMs - startMs.coerceAtLeast(0L)).coerceAtLeast(0L) else timeoutMs

        /**
         * The profile a backup network session selects: a SOCKS proxy at
         * 127.0.0.1:[port], which the config builder turns into the
         * outbound tagged `proxy` like any other door.
         */
        fun profile(port: Int): ProfileItem = ProfileItem.create(EConfigType.SOCKS).apply {
            remarks = REMARKS
            server = AppConfig.LOOPBACK
            serverPort = port.toString()
        }

        fun read(): PsiphonSession? = fromJson(MmkvManager.decodeSettingsString(AppConfig.PREF_PSIPHON_SESSION))

        fun write(session: PsiphonSession) {
            MmkvManager.encodeSettings(AppConfig.PREF_PSIPHON_SESSION, session.toJson())
        }

        /** Called on every normal connect. An empty value reads as no session. */
        fun clear() {
            MmkvManager.encodeSettings(AppConfig.PREF_PSIPHON_SESSION, "")
        }

        /**
         * Whether [profile] has the shape [profile] builds: a SOCKS proxy
         * on loopback named [REMARKS]. Selected with no session behind it,
         * such a profile points the core at a port nobody listens on.
         */
        fun isBackupProfile(profile: ProfileItem?): Boolean =
            profile != null &&
                profile.configType == EConfigType.SOCKS &&
                profile.server == AppConfig.LOOPBACK &&
                profile.remarks == REMARKS

        /**
         * The profiles [forgetAll] removes: the stored session's profile
         * ([storedGuid]), and the selected profile ([selected]) when it has
         * the backup shape.
         */
        fun forgetTargets(storedGuid: String?, selected: String?, selectedIsBackup: Boolean): List<String> =
            listOfNotNull(
                storedGuid?.takeIf { it.isNotBlank() },
                selected?.takeIf { selectedIsBackup && it.isNotBlank() },
            ).distinct()

        /**
         * Ends the backup network session, so that no later start of the
         * service (the tile, the widget, always-on, Android's restart)
         * brings it back. The app calls this when its decision no longer
         * allows the backup network.
         *
         * The profiles go first. Removing the selected profile also clears
         * the selection, so a start that reads between the two steps finds
         * no selected profile instead of a proxy with nothing behind it.
         *
         * Returns whether the selected profile was removed. The service may
         * then be running the session, and the caller stops it.
         */
        fun forgetAll(): Boolean {
            val selected = MmkvManager.getSelectServer()
            val selectedIsBackup = isBackupProfile(selected?.let { MmkvManager.decodeServerConfig(it) })
            val targets = forgetTargets(read()?.guid, selected, selectedIsBackup)
            targets.forEach { MmkvManager.removeServer(it) }
            clear()
            return selected != null && selected in targets
        }

        /**
         * [forgetAll] for a start of the session with profile [guid] that
         * failed. Does nothing when the stored session is another one, so
         * a failed start cannot end a session the app has written since.
         */
        fun forget(guid: String) {
            if (read()?.guid != guid) return
            MmkvManager.removeServer(guid)
            clear()
        }

        /**
         * The guid of the selected profile when it is a backup network
         * proxy whose session is gone (see [isBackupProfile]). Null
         * otherwise.
         */
        fun orphan(): String? {
            if (active() != null) return null
            val selected = MmkvManager.getSelectServer() ?: return null
            return selected.takeIf { isBackupProfile(MmkvManager.decodeServerConfig(it)) }
        }

        /**
         * Removes the profile [orphan] found, unless the app has written a
         * session for it since.
         */
        fun forgetOrphan(guid: String) {
            if (read()?.guid == guid) return
            MmkvManager.removeServer(guid)
        }

        /** The session, while its profile is the selected one. Null otherwise. */
        fun active(): PsiphonSession? {
            val session = read() ?: return null
            return if (session.guid == MmkvManager.getSelectServer()) session else null
        }

        /**
         * [active], with its port moved when something else listens on it
         * now. A restart can come long after the app picked the port, and
         * the old run may still hold it for a moment while it stops. The
         * profile is rewritten with the new port before the core's config
         * is built from it. Null when there is no session or its profile is
         * gone.
         */
        fun prepare(): PsiphonSession? {
            val session = active() ?: return null
            val port = Utils.findFreePort(listOf(session.port, 0))
            if (port == session.port) return session
            val profile = MmkvManager.decodeServerConfig(session.guid) ?: return null
            profile.serverPort = port.toString()
            MmkvManager.encodeServerConfig(session.guid, profile)
            val moved = session.copy(port = port)
            write(moved)
            return moved
        }
    }
}
