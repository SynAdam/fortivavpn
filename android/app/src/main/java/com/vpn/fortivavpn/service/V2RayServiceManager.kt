package com.vpn.fortivavpn.service

import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.util.Log
import androidx.core.content.ContextCompat
import com.vpn.fortivavpn.AppConfig
import com.vpn.fortivavpn.R
import com.vpn.fortivavpn.dto.ConfigResult
import com.vpn.fortivavpn.dto.EConfigType
import com.vpn.fortivavpn.dto.ProfileItem
import com.vpn.fortivavpn.handler.MmkvManager
import com.vpn.fortivavpn.handler.SettingsManager
import com.vpn.fortivavpn.handler.SpeedtestManager
import com.vpn.fortivavpn.handler.V2rayConfigManager
import com.vpn.fortivavpn.util.MessageUtil
import com.vpn.fortivavpn.util.PluginUtil
import com.vpn.fortivavpn.util.Utils
import fortivacore.Fortivacore
import go.Seq
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import libv2ray.CoreCallbackHandler
import libv2ray.CoreController
import libv2ray.Libv2ray
import org.json.JSONArray
import org.json.JSONObject
import java.lang.ref.SoftReference

object V2RayServiceManager {

    private val coreController: CoreController = Libv2ray.newCoreController(CoreCallback())
    private val mMsgReceive = ReceiveMessageHandler()
    private var currentConfig: ProfileItem? = null

    /** How many doors the running config holds, or 0 when it holds one. */
    @Volatile
    private var autoSelectDoors = 0

    /**
     * Whether the core has ever answered a traffic query with figures.
     *
     * An empty answer means either "no counters" or "nothing moved", and the
     * two must not be confused: reporting a core that is not counting as zero
     * bytes would file every session as a stalled tunnel. Once a real answer
     * has arrived the counters exist, and an empty one after that is the
     * finding rather than a gap.
     */
    private var sawTrafficStats = false

    /**
     * The session readings (SessionMeter), while the core runs and the
     * backend asked for them. Only touched on this process's main thread,
     * where the receiver below answers the app too, so a reading and a
     * report never run at once.
     */
    private var meter: SessionMeter? = null
    private val meterHandler = Handler(Looper.getMainLooper())
    private val meterTick = Runnable { meter?.let { readMeter(it) } }

    /** A failed reading is logged once per session, not once a second. */
    private var meterFailureLogged = false

    var serviceControl: SoftReference<ServiceControl>? = null
        set(value) {
            field = value
            val service = value?.get()?.getService()
            Seq.setContext(service?.applicationContext)
            // Must run before initCoreEnv. The core reads the geo databases
            // out of userAssetPath at init; staging them afterwards is too
            // late and every geoip:/geosite: rule gets stripped instead.
            service?.let { SettingsManager.initAssets(it, it.assets) }
            Libv2ray.initCoreEnv(Utils.userAssetPath(service), Utils.getDeviceIdForXUDPBaseKey())
        }

    /**
     * Starts the V2Ray service from a toggle action.
     * @param context The context from which the service is started.
     * @return True if the service was started successfully, false otherwise.
     */
    fun startVServiceFromToggle(context: Context): Boolean {
        if (MmkvManager.getSelectServer().isNullOrEmpty()) {
           // context.toast(R.string.app_tile_first_use)
            return false
        }
        // The tile and the widget start only on a tap.
        startContextService(context, takeSlot = true)
        return true
    }

    /**
     * Starts the V2Ray service.
     * @param context The context from which the service is started.
     * @param guid The GUID of the server configuration to use (optional).
     * @param takeSlot True only when the user tapped for this start: it may
     *   then take the VPN slot from another app (VpnSlot).
     */
    fun startVService(context: Context, guid: String? = null, takeSlot: Boolean = false) {
        if (guid != null) {
            MmkvManager.setSelectServer(guid)
        }
        startContextService(context, takeSlot)
    }

    /**
     * Stops the V2Ray service.
     * @param context The context from which the service is stopped.
     */
    fun stopVService(context: Context) {
       // context.toast(R.string.toast_services_stop)
        MessageUtil.sendMsg2Service(context, AppConfig.MSG_STATE_STOP, "")
    }

    /**
     * Checks if the V2Ray service is running.
     * @return True if the service is running, false otherwise.
     */
    fun isRunning() = coreController.isRunning

    /**
     * Starts the context service for V2Ray.
     * Chooses between VPN service or Proxy-only service based on user settings.
     * @param context The context from which the service is started.
     * @param takeSlot See [startVService].
     */
    private fun startContextService(context: Context, takeSlot: Boolean) {
        val guid = MmkvManager.getSelectServer() ?: return
        val config = MmkvManager.decodeServerConfig(guid) ?: return
        if (config.configType != EConfigType.CUSTOM
            && !Utils.isValidUrl(config.server)
            && !Utils.isPureIpAddress(config.server.orEmpty())
        ) return

        // Always stop the old service before starting a new one.
        // NOTE: coreController.isRunning does NOT work here because V2Ray core
        // runs in the daemon process (:RunSoLibV2RayDaemon), not this process.
        // Without this, a failed connection leaves the daemon in a bad state
        // and ALL subsequent connections fail.

        stopVService(context)
        Thread.sleep(500L)  // Wait for cleanup

        if (MmkvManager.decodeSettingsBool(AppConfig.PREF_PROXY_SHARING) == true) {
            //context.toast(R.string.toast_warning_pref_proxysharing_short)
        } else {
           // context.toast(R.string.toast_services_start)
        }
        val intent = if ((MmkvManager.decodeSettingsString(AppConfig.PREF_MODE) ?: AppConfig.VPN) == AppConfig.VPN) {
            Intent(context.applicationContext, V2RayVpnService::class.java)
        } else {
            Intent(context.applicationContext, V2RayProxyOnlyService::class.java)
        }
        intent.putExtra(VpnSlot.EXTRA_TAKE_SLOT, takeSlot)
        if (Build.VERSION.SDK_INT > Build.VERSION_CODES.N_MR1) {
            context.startForegroundService(intent)
        } else {
            context.startService(intent)
        }
    }

    /**
     * Refer to the official documentation for [registerReceiver](https://developer.android.com/reference/androidx/core/content/ContextCompat#registerReceiver(android.content.Context,android.content.BroadcastReceiver,android.content.IntentFilter,int):
     * `registerReceiver(Context, BroadcastReceiver, IntentFilter, int)`.
     * Starts the V2Ray core service.
     */
    fun startCoreLoop(): Boolean = startCore() == null

    /**
     * [startCoreLoop], with the reason when it fails: null once the core
     * runs, else one of StartFailure's core reasons. V2RayVpnService sends
     * the reason with its failed start, so the app can file it.
     */
    fun startCore(): String? {

        if (coreController.isRunning) {
            Log.w(AppConfig.TAG, "[core] already running")
            return StartFailure.ALREADY_RUNNING
        }

        val service = getService()
        if (service == null) {
            Log.e(AppConfig.TAG, "[core] no service bound")
            return StartFailure.NO_SERVICE
        }
        val guid = MmkvManager.getSelectServer()
        if (guid == null) {
            Log.e(AppConfig.TAG, "[core] no server selected")
            return StartFailure.NO_SERVER
        }
        val config = MmkvManager.decodeServerConfig(guid)
        if (config == null) {
            Log.e(AppConfig.TAG, "[core] stored config for $guid could not be decoded")
            return StartFailure.BAD_PROFILE
        }

        // Several doors at once when the app sent standby doors with this
        // one, and the one door otherwise or when the group cannot be built.
        val doors = standbyDoors(guid)
        var result = if (doors.size > 1) {
            V2rayConfigManager.getV2rayAutoSelectConfig(service, doors, doorExits(), doorPenalties())
        } else {
            ConfigResult(false)
        }
        val grouped = result.status
        if (!grouped) result = V2rayConfigManager.getV2rayConfig(service, guid)
        if (!result.status) {
            Log.e(AppConfig.TAG, "[core] could not build a v2ray config from $guid")
            return StartFailure.BUILD_FAILED
        }

        try {
            val mFilter = IntentFilter(AppConfig.BROADCAST_ACTION_SERVICE)
            mFilter.addAction(Intent.ACTION_SCREEN_ON)
            mFilter.addAction(Intent.ACTION_SCREEN_OFF)
            mFilter.addAction(Intent.ACTION_USER_PRESENT)
            ContextCompat.registerReceiver(service, mMsgReceive, mFilter, Utils.receiverFlags())

        } catch (e: Exception) {
            Log.e(AppConfig.TAG, "[core] could not register the service receiver", e)
            return StartFailure.RECEIVER
        }

        currentConfig = config
        sawTrafficStats = false

        autoSelectDoors = 0
        lastCoreError = null
        // The group and the backend's door outbounds are new. A core that
        // will not start with them must not cost the user the connection
        // the one door's link would have given (CoreStart).
        val started = CoreStart.firstThatStarts(result, grouped, ::runCore) { group ->
            if (group) {
                V2rayConfigManager.getV2rayAutoSelectConfig(
                    service,
                    doors,
                    doorExits(),
                    doorPenalties(),
                    doorOutbounds = false,
                )
            } else {
                V2rayConfigManager.getV2rayConfig(service, guid, doorOutbounds = false)
            }
        }
        if (started == null) {
            NotificationService.cancelNotification(service)
            // The last try's error: each try ends with its own, and the
            // last is the one-door config, the plainest.
            return lastCoreError ?: StartFailure.START_ERROR
        }
        result = started.result
        if (started.grouped) autoSelectDoors = doors.size

        try {
            NotificationService.showNotification(service, currentConfig)
            PluginUtil.runPlugin(service, config, result.socksPort)

        } catch (e: Exception) {
            Log.e(AppConfig.TAG, "[core] notification or plugin startup failed", e)
            return StartFailure.POST_START
        }

        // Messages from the Fortiva team arrive within minutes while the
        // tunnel runs, through it when the phone's own network cuts us off.
        NoticeJobs.startTicking(service)
        // The heartbeat and the dead tunnel check, while the app's engine is
        // gone and this tunnel runs on.
        Keeper.start(service)
        startMeter()

        return null
    }

    /**
     * Stops the V2Ray core service.
     * Unregisters broadcast receivers, stops notifications, and shuts down plugins.
     * @return True if the core was stopped successfully, false otherwise.
     */
    fun stopCoreLoop(reason: String = ""): Boolean {
        autoSelectDoors = 0
        stopMeter()
        // Every stop of the core also stops the backup network, when it
        // runs. Returns at once; see PsiphonCore.
        PsiphonCore.stop()
        val service = getService() ?: return false

        if (coreController.isRunning) {
            CoroutineScope(Dispatchers.IO).launch {
                try {
                    coreController.stopLoop()
                } catch (e: Exception) {
                    Log.e(AppConfig.TAG, "Failed to stop V2Ray loop", e)
                }
            }
        }

        MessageUtil.sendMsg2UI(service, AppConfig.MSG_STATE_STOP_SUCCESS, reason)
        NotificationService.cancelNotification(service)
        NoticeJobs.stopTicking()
        Keeper.stop()
        // With the tunnel down, the alarm and the periodic job are what is
        // left. Set them in case a force stop took them.
        NoticeJobs.ensureScheduled(service)

        try {
            service.unregisterReceiver(mMsgReceive)
        } catch (e: Exception) {
            Log.e(AppConfig.TAG, "Failed to unregister broadcast receiver", e)
        }
        PluginUtil.stopPlugin()

        return true
    }

    /**
     * Answers MSG_MEASURE_TRAFFIC with the bytes the tunnel has carried.
     *
     * The core keeps its counters in this process, and the app's Flutter side
     * runs in another, so the answer goes back over the same broadcast
     * channel the status messages use. Nothing is sent when the figures
     * cannot be had: the caller would rather skip a beat than record a
     * healthy tunnel as one carrying nothing.
     */
    private fun reportTraffic(beat: Boolean) {
        val service = getService() ?: return
        if (!coreController.isRunning) return
        meter?.let {
            reportFromMeter(service, it, beat)
            return
        }
        val (up, down) = proxyTraffic() ?: return
        // When the core holds several doors, the one in use rides along as a
        // third field, so the app can say which one carried these bytes, and
        // what the group knows about all of them as a fourth. The fourth is
        // JSON and holds commas of its own, so it goes last.
        val doors = doorStatus()
        val payload = StatsPayload.encodePlain(
            up,
            down,
            doors?.first,
            doors?.second,
            PsiphonCore.region(),
            PsiphonCore.upgrade(),
        )
        MessageUtil.sendMsg2UI(service, AppConfig.MSG_STATS_UPDATE, payload)
    }

    /**
     * [reportTraffic] while the session readings run. The meter is then the
     * only reader of the counters, so the answer comes from what it has
     * counted, after a fresh reading unless the last one was under a
     * second ago (see SessionSettings.MIN_SAMPLE_MS). One JSON object goes
     * back instead of the comma-separated text (StatsPayload).
     */
    private fun reportFromMeter(service: Service, meter: SessionMeter, beat: Boolean) {
        if (meter.readingDue()) readMeter(meter)
        // As in proxyTraffic: before the core has counted anything, an empty
        // answer cannot be told from a core that is not counting.
        if (!sawTrafficStats) return
        val doors = doorStatus()
        val payload = StatsPayload.encode(
            meter.report(beat),
            doors?.first,
            doors?.second,
            PsiphonCore.region(),
            PsiphonCore.upgrade(),
        )
        MessageUtil.sendMsg2UI(service, AppConfig.MSG_STATS_UPDATE, payload)
    }

    /**
     * Starts the session readings when the last connect carried the
     * backend's settings for them. Nothing runs otherwise, and the traffic
     * answer stays what it was before there were readings.
     *
     * The readings run on a handler on the main thread, whose clock is
     * uptime: they pause while the phone is in deep sleep and wake nothing.
     * No wake lock. Each one is a call into the core that visits a few
     * counters, with no network.
     */
    private fun startMeter() {
        val settings = try {
            SessionSettings.read()
        } catch (e: Exception) {
            Log.w(AppConfig.TAG, "[session] could not read the session settings", e)
            null
        }
        meterHandler.post {
            meterHandler.removeCallbacks(meterTick)
            meterFailureLogged = false
            meter = settings?.let { SessionMeter(it) { SystemClock.elapsedRealtime() } }
            if (settings != null) meterHandler.postDelayed(meterTick, settings.sampleMs)
        }
    }

    private fun stopMeter() {
        meterHandler.post {
            meterHandler.removeCallbacks(meterTick)
            meter = null
        }
    }

    /**
     * One reading for [meter], and the next one a period from now, so two
     * readings are never closer than a period unless a report asked.
     * Never throws.
     */
    private fun readMeter(meter: SessionMeter) {
        try {
            val reading = readDoors(logFailure = !meterFailureLogged)
            if (reading == null) meterFailureLogged = true
            meter.take(reading)
        } catch (e: Exception) {
            Log.w(AppConfig.TAG, "[session] a reading failed", e)
        }
        meterHandler.removeCallbacks(meterTick)
        if (this.meter === meter) meterHandler.postDelayed(meterTick, meter.settings.sampleMs)
    }

    /**
     * Starts the core with [config]. True when it is running afterwards.
     *
     * tunFd 0 tells the core not to open its own TUN device. Routing stays
     * with tun2socks over the SOCKS inbound, which is what V2RayVpnService
     * builds; letting the core take the fd instead would bypass that path
     * entirely.
     */
    private fun runCore(config: String): Boolean {
        try {
            coreController.startLoop(config, 0)
        } catch (e: Exception) {
            Log.e(AppConfig.TAG, "[core] startLoop threw", e)
            lastCoreError = StartFailure.coreError(e.message)
            return false
        }
        if (coreController.isRunning == false) {
            Log.e(AppConfig.TAG, "[core] startLoop returned but the core is not running")
            lastCoreError = StartFailure.NOT_RUNNING
            return false
        }
        return true
    }

    /**
     * Why the last [runCore] failed, as one StartFailure word, or null.
     * The tunnel's starts run one at a time (V2RayVpnService's start
     * lock), so one field is enough. Only [startCore] reads it.
     */
    @Volatile
    private var lastCoreError: String? = null

    /**
     * The doors of the last connect when [selected] is the first of them,
     * or an empty list. Anything else that starts the service, such as the
     * tile after another server was picked, connects through one door.
     */
    private fun standbyDoors(selected: String): List<String> {
        val doors = MmkvManager.decodeSettingsString(AppConfig.PREF_AUTOSELECT_GUIDS)
            .orEmpty().split(",")
        return if (doors.size > 1 && doors.first() == selected) doors else emptyList()
    }

    /**
     * The server each door of the last connect leaves from, by position, as
     * PREF_AUTOSELECT_EXITS holds it. Empty entries are doors with none.
     */
    private fun doorExits(): List<String> =
        MmkvManager.decodeSettingsString(AppConfig.PREF_AUTOSELECT_EXITS).orEmpty().split(",")

    /**
     * The backend's penalty for each door of the last connect, by position,
     * as PREF_AUTOSELECT_PENALTIES holds it. A door with no entry has none.
     */
    private fun doorPenalties(): List<Int> =
        MmkvManager.decodeSettingsString(AppConfig.PREF_AUTOSELECT_PENALTIES).orEmpty().split(",")
            .map { it.trim().toIntOrNull() ?: 0 }

    /**
     * The position of the door new connections go through, in the order the
     * app sent them, and what the group knows about every door. Null when
     * the core holds one door.
     */
    private fun doorStatus(): Pair<Int, String>? {
        if (autoSelectDoors == 0) return null
        return try {
            val groups = JSONArray(Fortivacore.autoSelectStatus())
            for (i in 0 until groups.length()) {
                val group = groups.getJSONObject(i)
                if (group.optString("tag") != AppConfig.TAG_PROXY) continue
                val selected = V2rayConfigManager.autoSelectMemberIndex(group.optString("selected"))
                    ?: return null
                return selected to doorReport(group).toString()
            }
            null
        } catch (e: Exception) {
            Log.w(AppConfig.TAG, "[core] could not read which door is in use", e)
            null
        }
    }

    /**
     * The group's status as the app reports it: the core's recent moves
     * between doors, each with the reason the core gave and when, and each
     * door's measurements at this moment. Doors are named by position, so
     * the app never needs to know how the core spells their tags.
     *
     * The core keeps its last 16 moves, so a move made between two reads is
     * still in the list. switch_count is every move since the core started,
     * which says when more happened than the list could hold.
     */
    private fun doorReport(group: JSONObject): JSONObject {
        fun position(tag: String): Any = V2rayConfigManager.autoSelectMemberIndex(tag) ?: JSONObject.NULL
        val moves = JSONArray()
        val events = group.optJSONArray("events") ?: JSONArray()
        for (i in 0 until events.length()) {
            val e = events.getJSONObject(i)
            moves.put(
                JSONObject()
                    .put("from", position(e.optString("from")))
                    .put("to", position(e.optString("to")))
                    .put("reason", e.optString("reason"))
                    .put("at", e.optLong("atMs")),
            )
        }
        val doors = JSONArray()
        val members = group.optJSONArray("members") ?: JSONArray()
        for (i in 0 until members.length()) {
            val m = members.getJSONObject(i)
            val index = V2rayConfigManager.autoSelectMemberIndex(m.optString("tag")) ?: continue
            val door = JSONObject()
                .put("index", index)
                .put("state", m.optString("state"))
                .put("delay_ms", m.optLong("delayMs", -1))
                .put("jitter_ms", m.optLong("jitterMs", -1))
                .put("fail_ratio", m.optDouble("failRatio", 0.0))
                .put("score", m.optDouble("score", -1.0))
                .put("penalty_ms", m.optLong("penaltyMs", 0))
                .put("connections", m.optInt("connections"))
            m.optString("lastError").takeIf { it.isNotBlank() }?.let { door.put("last_error", it) }
            doors.put(door)
        }
        return JSONObject()
            .put("state", group.optString("state"))
            .put("switch_count", group.optInt("switches"))
            .put("switches", moves)
            .put("doors", doors)
    }

    /**
     * The phone moved to another network. What the core measured about each
     * door on the previous one no longer applies, so it measures them again
     * now. Nothing to do when the core holds one door.
     */
    fun networkChanged() {
        if (autoSelectDoors == 0 || !coreController.isRunning) return
        try {
            Fortivacore.autoSelectNetworkChanged()
        } catch (e: Exception) {
            Log.w(AppConfig.TAG, "[core] could not tell the door group the network changed", e)
        }
    }

    /**
     * The backup network ended by itself after it had connected
     * (PsiphonCore). The core still points at its port, so the tunnel
     * carries nothing; it is taken down, and the app sees a drop and looks
     * for another way. Nothing to do when the core is not running or the
     * session has changed since.
     */
    fun psiphonLost() {
        if (!coreController.isRunning || PsiphonSession.active() == null) return
        Log.w(AppConfig.TAG, "[psiphon] taking the tunnel down: the backup network stopped")
        serviceControl?.get()?.stopService()
    }

    /**
     * Bytes up and down through the proxy outbound since this was last asked,
     * or null when the core is not counting.
     *
     * queryAllOutboundTrafficStats resets every counter it reports, so each
     * answer is exactly the delta since the previous one, which is what a
     * heartbeat wants and why nothing else may call it. While the session
     * readings run, the meter is the one that calls it (reportFromMeter).
     * The wire format is `tag,direction,value;` repeated
     * (SessionMeter.parseTraffic).
     */
    private fun proxyTraffic(): Pair<Long, Long>? {
        val doors = readDoors() ?: return null
        if (!sawTrafficStats) return null
        return doors.values.sumOf { it.up } to doors.values.sumOf { it.down }
    }

    /**
     * Bytes each door moved since the counters were last read, by the
     * door's position, or null when the query failed. An empty answer is
     * an empty map; [sawTrafficStats] says whether that can be trusted.
     * Resets the counters, like everything that reads them (see
     * [proxyTraffic]).
     */
    private fun readDoors(logFailure: Boolean = true): Map<Int, SessionMeter.Bytes>? {
        val raw = try {
            coreController.queryAllOutboundTrafficStats()
        } catch (e: Exception) {
            if (logFailure) Log.w(AppConfig.TAG, "[stats] traffic query failed", e)
            return null
        }
        if (raw.isNullOrBlank()) return emptyMap()
        sawTrafficStats = true
        return SessionMeter.parseTraffic(raw)
    }

    /**
     * Measures the connection delay for the current V2Ray configuration.
     * Tests with primary URL first, then falls back to alternative URL if needed.
     * Also fetches remote IP information if the delay test was successful.
     */
    private fun measureV2rayDelay() {
        if (coreController.isRunning == false) {
            return
        }

        CoroutineScope(Dispatchers.IO).launch {
            val service = getService() ?: return@launch
            var time = -1L
            var errorStr = ""

            try {
                time = coreController.measureDelay(SettingsManager.getDelayTestUrl())
            } catch (e: Exception) {
                Log.e(AppConfig.TAG, "Failed to measure delay with primary URL", e)
                errorStr = e.message?.substringAfter("\":") ?: "empty message"
            }
            if (time == -1L) {
                try {
                    time = coreController.measureDelay(SettingsManager.getDelayTestUrl(true))
                } catch (e: Exception) {
                    Log.e(AppConfig.TAG, "Failed to measure delay with alternative URL", e)
                    errorStr = e.message?.substringAfter("\":") ?: "empty message"
                }
            }

            val result = if (time >= 0) {
                service.getString(R.string.connection_test_available, time)
            } else {
                service.getString(R.string.connection_test_error, errorStr)
            }
            MessageUtil.sendMsg2UI(service, AppConfig.MSG_MEASURE_DELAY_SUCCESS, result)

            // Only fetch IP info if the delay test was successful
            if (time >= 0) {
                SpeedtestManager.getRemoteIPInfo()?.let { ip ->
                    MessageUtil.sendMsg2UI(service, AppConfig.MSG_MEASURE_DELAY_SUCCESS, "$result\n$ip")
                }
            }
        }
    }

    /**
     * Gets the current service instance.
     * @return The current service instance, or null if not available.
     */
    private fun getService(): Service? {
        return serviceControl?.get()?.getService()
    }

    /**
     * Core callback handler implementation for handling V2Ray core events.
     * Handles startup, shutdown, socket protection, and status emission.
     */
    private class CoreCallback : CoreCallbackHandler {
        /**
         * Called when V2Ray core starts up.
         * @return 0 for success, any other value for failure.
         */
        override fun startup(): Long {
            return 0
        }

        /**
         * Called when V2Ray core shuts down.
         * @return 0 for success, any other value for failure.
         */
        override fun shutdown(): Long {
            val serviceControl = serviceControl?.get() ?: return -1
            return try {
                serviceControl.coreStopped()
                0
            } catch (e: Exception) {
                Log.e(AppConfig.TAG, "Failed to stop service in callback", e)
                -1
            }
        }

        /**
         * Called when V2Ray core emits status information.
         * @param l Status code.
         * @param s Status message.
         * @return Always returns 0.
         */
        override fun onEmitStatus(l: Long, s: String?): Long {
            return 0
        }
    }

    /**
     * Broadcast receiver for handling messages sent to the service.
     * Handles registration, service control, and screen events.
     */
    private class ReceiveMessageHandler : BroadcastReceiver() {
        /**
         * Handles received broadcast messages.
         * Processes service control messages and screen state changes.
         * @param ctx The context in which the receiver is running.
         * @param intent The intent being received.
         */
        override fun onReceive(ctx: Context?, intent: Intent?) {
            val serviceControl = serviceControl?.get() ?: return
            when (intent?.getIntExtra("key", 0)) {
                AppConfig.MSG_REGISTER_CLIENT -> {
                    if (coreController.isRunning) {
                        MessageUtil.sendMsg2UI(serviceControl.getService(), AppConfig.MSG_STATE_RUNNING, "")
                    } else {
                        MessageUtil.sendMsg2UI(serviceControl.getService(), AppConfig.MSG_STATE_NOT_RUNNING, "")
                    }
                }

                AppConfig.MSG_UNREGISTER_CLIENT -> {
                    // nothing to do
                }

                AppConfig.MSG_STATE_START -> {
                    // nothing to do
                }

                AppConfig.MSG_STATE_STOP -> {
                    Log.i(AppConfig.TAG, "Stop Service")
                    serviceControl.stopService()
                }

                AppConfig.MSG_STATE_RESTART -> {
                    Log.i(AppConfig.TAG, "Restart Service")
                    serviceControl.stopService()
                    Thread.sleep(500L)
                    startVService(serviceControl.getService())
                }

                AppConfig.MSG_MEASURE_DELAY -> {
                    measureV2rayDelay()
                }

                AppConfig.MSG_MEASURE_TRAFFIC -> {
                    val content = intent?.getStringExtra("content")
                    // The keeper asks when the app's engine is gone; only
                    // the app's own asks say it is there.
                    if (content == AppConfig.TRAFFIC_KEEPER) Keeper.noteKeeperAsked() else Keeper.noteAppAsked()
                    reportTraffic(content == AppConfig.TRAFFIC_BEAT || content == AppConfig.TRAFFIC_KEEPER)
                }

                AppConfig.MSG_REPOST_NOTIFICATION -> {
                    if (coreController.isRunning) {
                        NotificationService.showNotification(serviceControl.getService(), currentConfig)
                    }
                }
            }

            when (intent?.action) {
                Intent.ACTION_SCREEN_OFF -> {
                    Log.i(AppConfig.TAG, "SCREEN_OFF")
                }

                Intent.ACTION_SCREEN_ON -> {
                    Log.i(AppConfig.TAG, "SCREEN_ON")
                }
            }
        }
    }
}
