// Copyright (C) 2026 NimusAI. GPL-3.0-or-later, with the additional terms
// under section 7 in LICENSING.md.

package com.vpn.fortivavpn

import android.content.ActivityNotFoundException
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.Signature
import android.content.res.Configuration
import android.app.UiModeManager
import android.net.ConnectivityManager
import android.net.Uri
import android.net.NetworkCapabilities
import android.net.VpnService
import android.os.Build
import android.os.Bundle
import android.os.SystemClock
import android.provider.Settings
import android.util.Log
import android.telephony.TelephonyManager
import android.os.PowerManager
import android.app.ActivityManager
import androidx.annotation.NonNull
import com.google.android.play.core.review.ReviewException
import com.google.android.play.core.review.ReviewManagerFactory
import com.google.gson.JsonParser
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import com.vpn.fortivavpn.handler.AngConfigManager
import com.vpn.fortivavpn.handler.DoorCheck
import com.vpn.fortivavpn.handler.DoorChecks
import com.vpn.fortivavpn.handler.DoorOutbound
import com.vpn.fortivavpn.handler.DoorOutbounds
import com.vpn.fortivavpn.handler.LinkFacts
import com.vpn.fortivavpn.handler.LogPrivacy
import com.vpn.fortivavpn.handler.MmkvManager
import com.vpn.fortivavpn.handler.NetworkKey
import com.vpn.fortivavpn.handler.PeerHandoff
import com.vpn.fortivavpn.handler.SettingsManager
import com.vpn.fortivavpn.handler.SpeedtestManager
import com.vpn.fortivavpn.handler.TestLink
import com.vpn.fortivavpn.handler.TlsFragment
import com.vpn.fortivavpn.handler.TunnelProbe
import com.vpn.fortivavpn.handler.V2rayConfigManager
import com.vpn.fortivavpn.service.NoticeJobService
import com.vpn.fortivavpn.service.NoticeJobs
import com.vpn.fortivavpn.service.NoticeNotifier
import com.vpn.fortivavpn.service.PsiphonSession
import com.vpn.fortivavpn.service.SessionSettings
import com.vpn.fortivavpn.service.V2RayServiceManager
import com.vpn.fortivavpn.service.VpnSlot
import com.vpn.fortivavpn.util.MessageUtil
import com.vpn.fortivavpn.util.Utils
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Deferred
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.async
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withTimeoutOrNull
import java.net.HttpURLConnection
import java.net.Inet6Address
import java.net.InetSocketAddress
import java.net.Proxy
import java.net.Socket
import java.net.URL
import java.security.MessageDigest

class MainActivity : FlutterActivity() {
    private val TAG = "FortivaVPN"
    private val CHANNEL = "com.vpn.fortivavpn/tunnel"

    // Pending connection state for permission flow
    private var pendingConnectLink: String? = null

    /**
     * The standby doors that came with [pendingConnectLink]. Not saved across
     * a recreated activity: a connect that loses them goes through the one
     * door, which is what it did before there were any.
     */
    private var pendingConnectAlternates: List<String> = emptyList()
    private var pendingConnectExits: List<String> = emptyList()
    private var pendingConnectPenalties: List<Int> = emptyList()
    private var pendingConnectOutbounds: List<String> = emptyList()

    /**
     * A backup network start (connectPsiphon) waiting on the consent
     * dialog, instead of [pendingConnectLink]. At most one of the two is
     * set. Not saved across a recreated activity: its config can be large,
     * and a start that loses it answers PERMISSION_GRANTED_NO_LINK, as a
     * connect that lost its link does.
     */
    private var pendingPsiphon: PsiphonStart? = null

    /** What connectPsiphon asked for. See PsiphonSession. */
    private class PsiphonStart(val config: String, val timeoutMs: Long, val entriesFile: String)

    // When the consent dialog was launched, to tell a real refusal apart
    // from a dialog that closed itself before the user ever saw it.
    private var prepareRequestedAt = 0L

    /**
     * Whether the consent dialog now open is the second showing for its
     * request, after the first closed itself (ConsentAgain). A second one
     * that closes itself ends the request with PERMISSION_BLOCKED.
     */
    private var pendingShownAgain = false

    private val peerHandoff = PeerHandoff(this)

    companion object {
        // Must be unique within the activity: request code 0 collides with
        // whatever a Flutter plugin happens to use.
        private const val REQUEST_CODE_VPN_PREPARE = 1101
        private const val KEY_PENDING_LINK = "pending_connect_link"

        /** The most doors held next to the one being dialled. */
        private const val MAX_STANDBY_DOORS = 4
        // No one dismisses a dialog this fast; below it the system closed
        // the dialog itself and the user had nothing to answer.
        private const val SILENT_CANCEL_MS = 800L

        /**
         * How long a tap that took the VPN slot from another app waits for
         * that app's network to go, before its door checks start anyway.
         */
        private const val SLOT_TAKE_WAIT_MS = 2_000L
        private const val SETTING_ALWAYS_ON_VPN = "always_on_vpn_app"
        // How much longer than its own wait a timed door check is given to
        // answer. It ends itself at the wait, so this is only for the answer
        // to come back (DoorChecks).
        private const val TIMED_CHECK_GRACE_MS = 1000L
        // What the timed check's job gives when the check could not run, so
        // that a null from its timeout can only mean no answer in time.
        private const val TIMED_CHECK_NOT_RUN = ""
        private const val REQUEST_CODE_NOTIFICATIONS = 1102

        /**
         * Whether the app is on screen. The background check for messages
         * (NoticeJobService) runs in this process and skips its turn while
         * this is true, because the app checks for itself then.
         */
        @Volatile
        var inFront = false
            private set

        /**
         * Whether an activity shows the app's Flutter engine (AppEngine). The
         * keeper (KeeperJobService) runs in this process and stays out of
         * the way while one does: the app sends its own heartbeats then.
         * The engine outlives the activity, but without one it leaves the
         * heartbeat and the dead tunnel check to the keeper (AppEngine.shown).
         */
        val engineAlive: Boolean
            get() = AppEngine.shown

        /**
         * The connect waiting on the consent dialog. Here and not on the
         * activity, because the Dart side that asked is the engine's, and
         * the engine outlives the activity (AppEngine): an activity Android
         * rebuilt under the dialog answers it.
         */
        private var pendingResult: MethodChannel.Result? = null

        /** The app's question about notifications, waiting for the user's answer. */
        private var pendingNotificationAnswer: MethodChannel.Result? = null
    }

    /** The message a tapped notification asked to open, until the app reads it. */
    private var openedNotice: Int? = null

    /**
     * Back on the home screen sends the app to the background instead of
     * closing it, as Android itself does from Android 12 on for an app that
     * leaves Back to the system (and does for this app on Android 16).
     * Flutter otherwise finishes the activity, which ended the Dart engine
     * until AppEngine kept it: the heartbeat, the dead tunnel watch and any
     * report still on its way stopped, while the tunnel ran on in its own
     * process. The user sees the same thing either way; the app is just
     * still running.
     */
    override fun popSystemNavigator(): Boolean {
        moveTaskToBack(true)
        return true
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        // Before Flutter can ask for a door check: see DoorChecks.
        DoorChecks.prepare(applicationContext)
        // Read before super.onCreate, which can set it from a saved state
        // that never holds it, and which can evict an older activity.
        val handlesBack = AppEngine.frameworkHandlesBack
        super.onCreate(savedInstanceState)
        if (handlesBack) setFrameworkHandlesBack(true)
        // The consent dialog can outlive this activity (low memory, OEM task
        // killers). Keep the link so a granted permission still connects.
        if (pendingConnectLink == null) {
            pendingConnectLink = savedInstanceState?.getString(KEY_PENDING_LINK)
        }
        // Not when the system brings the activity back from its saved state:
        // the notification was tapped before, and its message was opened then.
        if (savedInstanceState == null) noteOpenedNotice(intent)
        // The background checks for messages. A reboot drops them, and the
        // next start of any part of the app puts them back.
        NoticeJobs.ensureScheduled(this)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        noteOpenedNotice(intent)
    }

    override fun onResume() {
        super.onResume()
        inFront = true
        // Notifications may have been turned on in the system settings, which
        // brings back the wake-up alarm. Cheap when nothing changed.
        NoticeJobs.ensureScheduled(this)
        // The keeper's dead tunnel notification brought the user here or is
        // no longer needed: the app shows the tunnel's state and checks it
        // again itself (StallRecovery).
        NoticeNotifier.clearStalled(this)
    }

    override fun onPause() {
        inFront = false
        super.onPause()
    }

    private fun noteOpenedNotice(intent: Intent?) {
        // Opened from the recent apps, the activity gets the intent it was
        // first started with, which can still be the notification's.
        val fromRecents = ((intent?.flags ?: 0) and Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY) != 0
        val id = intent?.getIntExtra(NoticeNotifier.EXTRA_NOTICE_ID, 0) ?: 0
        if (id > 0 && !fromRecents) openedNotice = id
        // Read once. A later recreation of the activity with the same intent
        // must not open the message again.
        intent?.removeExtra(NoticeNotifier.EXTRA_NOTICE_ID)
    }

    override fun onSaveInstanceState(outState: Bundle) {
        super.onSaveInstanceState(outState)
        pendingConnectLink?.let { outState.putString(KEY_PENDING_LINK, it) }
    }

    override fun onDestroy() {
        // The engine runs on (AppEngine), so a question this activity was
        // asking the user for it would wait forever. A swipe out of recents
        // ends the dialog with the activity: answer it as the user closing
        // it. An activity Android rebuilds leaves it to the next one.
        if (isFinishing) {
            pendingResult?.error("PERMISSION_DENIED", "The app was closed during the VPN permission request", null)
            pendingResult = null
            pendingNotificationAnswer?.success(notificationPermission())
            pendingNotificationAnswer = null
            peerHandoff.release()
        }
        super.onDestroy()
    }

    /**
     * The app's one engine, which outlives this activity, so the next
     * activity shows the Dart app as it is instead of starting it again.
     * See AppEngine.
     */
    override fun provideFlutterEngine(context: Context): FlutterEngine = AppEngine.get(context)

    /**
     * The engine keeps the app's state itself. Flutter's restoration data
     * from an older activity would only overwrite it.
     */
    override fun shouldRestoreAndSaveState(): Boolean = false

    override fun cleanUpFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        AppEngine.shown = false
        super.cleanUpFlutterEngine(flutterEngine)
    }

    /** Kept for the next activity: see AppEngine.frameworkHandlesBack. */
    override fun setFrameworkHandlesBack(frameworkHandlesBack: Boolean) {
        AppEngine.frameworkHandlesBack = frameworkHandlesBack
        super.setFrameworkHandlesBack(frameworkHandlesBack)
    }

    /**
     * A newer activity took the engine while this one was still in the
     * task, for example one a notification opened over a settings page
     * this one had opened. Flutter leaves this one without the engine, and
     * shown again it would stay blank and answer nothing, so it goes.
     */
    override fun detachFromFlutterEngine() {
        super.detachFromFlutterEngine()
        finish()
    }

    /**
     * Runs for every activity that takes the engine, so the handlers below
     * always answer through the activity on screen. After the last activity
     * goes, the engine keeps the handlers of that activity until the next.
     */
    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        AppEngine.shown = true
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "connect" -> {
                    val link = call.argument<String>("link")
                    if (link != null) {
                        // Other doors to hold next to this one. Absent on an
                        // app that does not send them, which connects through
                        // the one door.
                        val alternates = call.argument<List<String>>("alternates").orEmpty()
                        // The server each of those doors leaves from, the
                        // link's first. Absent on an app that does not send it.
                        val exits = call.argument<List<String>>("exits").orEmpty()
                        // The backend's penalty for each of those doors, in
                        // the same order. Absent when no door has one.
                        val penalties = doorPenalties(call.argument<List<Any?>>("penalties"))
                        // The backend's outbound of each of those doors, in
                        // the same order, "" for a door without one. Absent
                        // when no door has one. See DoorOutbounds.
                        val outbounds = call.argument<List<String>>("doorOutbounds").orEmpty()
                        // How the tunnel's process reads its counters this
                        // session, from the backend. Written on every
                        // connect, zero when absent, so a value from an
                        // earlier connect never lingers. See SessionSettings.
                        SessionSettings.write(
                            call.argument<Number>("session_sample_ms")?.toLong(),
                            call.argument<Number>("session_stall_ms")?.toLong(),
                            call.argument<Number>("session_busy_bytes")?.toLong(),
                        )
                        connectTunnel(link, alternates, exits, penalties, outbounds, takeSlot(call), result)
                    } else {
                        result.error("INVALID_ARGUMENT", "Link is null", null)
                    }
                }

                "connectPsiphon" -> {
                    // The backup network, which the app starts only when a
                    // whole round of doors and community links ended
                    // without a tunnel. `config` is the network's config as
                    // a JSON object; the keys this device owns are set in
                    // the tunnel's process (PsiphonConfig).
                    val config = call.argument<String>("config")
                    if (config != null && PsiphonSession.isConfig(config)) {
                        SessionSettings.write(
                            call.argument<Number>("session_sample_ms")?.toLong(),
                            call.argument<Number>("session_stall_ms")?.toLong(),
                            call.argument<Number>("session_busy_bytes")?.toLong(),
                        )
                        val timeoutMs = PsiphonSession.timeoutOf(call.argument<Number>("establish_timeout_ms")?.toLong())
                        // The network's server list the app keeps, by its
                        // path, when it has the one the backend names. The
                        // library is handed it only if it can be read when
                        // the library starts (PsiphonSession.embeddedList).
                        val entriesFile = PsiphonSession.entriesFileOf(call.argument<String>("server_entries_file"))
                        connectPsiphon(PsiphonStart(config, timeoutMs, entriesFile), takeSlot(call), result)
                    } else {
                        result.error("INVALID_ARGUMENT", "Config is not a JSON object", null)
                    }
                }

                "forgetPsiphon" -> {
                    // Ends the backup network session when the app's
                    // decision no longer allows it. The session stays in
                    // MMKV after a disconnect, and the tile, the widget,
                    // always-on and Android's restart start it again from
                    // there with none of the app's checks. True when the
                    // session's profile was the selected one: the service
                    // may be running it, so it is stopped. A backup start
                    // waiting on the consent dialog is dropped as well, and
                    // its call then answers PERMISSION_GRANTED_NO_LINK.
                    pendingPsiphon = null
                    val selected = try {
                        PsiphonSession.forgetAll()
                    } catch (e: Exception) {
                        Log.e(TAG, "Could not forget the backup network session: ${e.javaClass.simpleName}")
                        false
                    }
                    if (selected) V2RayServiceManager.stopVService(this)
                    result.success(selected)
                }

                "disconnect" -> {
                    V2RayServiceManager.stopVService(this)
                    result.success(null)
                }
                "otherVpn" -> {
                    // Whether another app's VPN is up now. Read without
                    // prepare(), which would take the slot from it (VpnSlot).
                    result.success(VpnSlot.otherUp(this))
                }
                "otherVpnCount" -> {
                    // How many VPN networks are not this app's (VpnSlot).
                    result.success(VpnSlot.othersCount(this))
                }
                "takeSlot" -> {
                    // A tap made while another app's VPN carries this app's
                    // traffic. The slot is taken before the search, so its
                    // door checks see the phone's own network and not that
                    // VPN's. Only with the consent on record: without it
                    // prepare() asks, and the tap's first dial opens the
                    // dialog as it always has.
                    if (VpnSlot.consentOnRecord(this) != true || !VpnSlot.otherUp(this)) {
                        result.success(false)
                    } else {
                        takeSlotForTap(result)
                    }
                }
                "openVpnSettings" -> {
                    openVpnSettings(result)
                }
                "privateDns" -> {
                    // A lookup can take seconds when DNS is broken, so off
                    // the main thread.
                    CoroutineScope(Dispatchers.IO).launch {
                        val host = privateDnsHostThatFails()
                        runOnUiThread { result.success(host) }
                    }
                }
                "openNetworkSettings" -> {
                    openNetworkSettings(result)
                }
                "openApnSettings" -> {
                    openApnSettings(result)
                }
                "requestReview" -> {
                    requestReview(result)
                }
                "openPlayListing" -> {
                    openPlayListing(result)
                }
                "shareInvite" -> {
                    // The invite card and the invite screen. The share sheet
                    // hides the state messengers (handler/InviteShare.kt).
                    val text = call.argument<String>("text")
                    if (text == null) {
                        result.error("INVALID_ARGUMENT", "Text is null", null)
                    } else {
                        result.success(
                            com.vpn.fortivavpn.handler.InviteShare.share(
                                this,
                                text,
                                call.argument<String>("target") ?: "sheet",
                                call.argument<List<String>>("exclude").orEmpty(),
                                call.argument<String>("title"),
                            ),
                        )
                    }
                }
                "getStatus" -> {
                     // While the consent dialog is up the attempt is waiting
                     // on the user, not stuck. The connect watchdog asks this
                     // before it calls a start failed.
                     val status = when {
                         pendingResult != null -> "awaiting_permission"
                         isVpnActive() -> "connected"
                         else -> "disconnected"
                     }
                     result.success(status)
                }
                "testConnection" -> {
                    testConnectionViaSocks(result)
                }
                "socksPort" -> {
                    // Where the core's SOCKS inbound listens while a tunnel
                    // is up. The app's own calls to the backend go through it
                    // when the phone's network drops them, because this app
                    // is left out of its own tunnel.
                    result.success(SettingsManager.getSocksPort())
                }
                "installId" -> {
                    // Scoped to this app's signing key, this user and this
                    // device. It survives a reinstall and resets on a factory
                    // reset, which is what DeviceIdentity needs and what its
                    // comment always claimed it read.
                    //
                    // Read here because device_info_plus does not expose it.
                    // What that package calls `id` is Build.ID, the ROM build
                    // label, which is the same string on every phone running
                    // that build: see issue #124.
                    //
                    // Never sent anywhere as-is. DeviceIdentity hashes it with
                    // an app salt and only the hash leaves the phone.
                    result.success(installId())
                }
                "throughputSample" -> {
                    val bytes = call.argument<Int>("bytes") ?: 1_000_000
                    val capMs = call.argument<Int>("capMs") ?: 10_000
                    throughputSample(bytes, capMs, result)
                }
                "realPing" -> {
                    val link = call.argument<String>("link")
                    // How long the core waits for data, when the app says.
                    val timeoutMs = TestLink.timeoutMs(call.argument<Number>("timeoutMs"))
                    // The app's split, sent with every test. See TestLink.config.
                    val splitter = TlsFragment.parse(call.argument<String>("splitter"))
                    // The backend's outbound for this door, when it has one.
                    // See DoorOutbounds.
                    val door = DoorOutbounds.parse(call.argument<String>("doorOutbound"))
                    if (link != null) {
                        realPing(link, timeoutMs, splitter, door, result)
                    } else {
                        result.error("INVALID_ARGUMENT", "Link is null", null)
                    }
                }
                "prepareTimedChecks" -> {
                    // The backend's settings ask for timed door checks in a
                    // run that started without them (a fresh install's first
                    // run). See DoorChecks.prepareLater.
                    DoorChecks.prepareLater()
                    result.success(null)
                }
                "realPingDetail" -> {
                    // A door check that says why it failed. See DoorCheck.
                    val link = call.argument<String>("link")
                    val timeoutMs = TestLink.timeoutMs(call.argument<Number>("timeoutMs"))
                    val splitter = TlsFragment.parse(call.argument<String>("splitter"))
                    val timed = call.argument<Boolean>("timed") == true
                    val door = DoorOutbounds.parse(call.argument<String>("doorOutbound"))
                    // What the check fetches through the door, when the app
                    // names it: a variant test's, from the backend.
                    val url = call.argument<String>("url")?.takeIf { it.isNotBlank() }
                    if (link != null) {
                        realPingDetail(link, timeoutMs, splitter, timed, door, url, result)
                    } else {
                        result.error("INVALID_ARGUMENT", "Link is null", null)
                    }
                }
                "realPingConfig" -> {
                    // realPingDetail for a variant test that comes with its
                    // own config (variant loop contract v2, section 1). The
                    // config, the address it fetches and the wait are the
                    // backend's. See DoorOutbounds.checkConfig. A wait the
                    // door checks would cut or stretch is not run, rather
                    // than run with another wait (TestLink.timeoutMsAsSent).
                    val timeoutMs = TestLink.timeoutMsAsSent(call.argument<Number>("timeoutMs"))
                    val splitter = TlsFragment.parse(call.argument<String>("splitter"))
                    val timed = call.argument<Boolean>("timed") == true
                    val config = DoorOutbounds.checkConfig(call.argument<String>("config"), splitter)
                    val url = call.argument<String>("url")?.takeIf { it.isNotBlank() }
                    if (config != null && url != null && timeoutMs != null) {
                        realPingConfig(config, timeoutMs, timed, url, result)
                    } else {
                        // Never dialled, so the app reports nothing for it.
                        val why = when {
                            config == null -> "config could not be read"
                            url == null -> "no address to fetch"
                            else -> "the wait is outside the range the app runs"
                        }
                        Log.w(TAG, "realPingConfig: not run, $why")
                        result.success(mapOf("ms" to -1L, "refused" to true, "error" to why))
                    }
                }
                "tunnelStats" -> {
                    // A heartbeat asks with beat: true, which also closes
                    // the session readings' interval in the daemon.
                    AppEngine.tunnelStats(this, result, call.argument<Boolean>("beat") == true)
                }
                "place" -> {
                    // Where the phone is, for the backend to place it in a
                    // country. System reads only, no network, so inline.
                    result.success(placeFacts())
                }
                "networkKey" -> {
                    // The Wi-Fi network's keys, made from its link properties
                    // and hashed here; nothing read leaves this call. System
                    // reads only, so inline. Null off Wi-Fi. See NetworkKey.
                    result.success(networkKey(call.argument<String>("salt"), call.argument<Number>("periodSeconds")))
                }
                "ipv6Route" -> {
                    // A system read, no network, so inline. See Ipv6Reach.
                    result.success(ipv6Route())
                }
                "networkFacts" -> {
                    // The transport and the carrier alone, for the APN
                    // guide on the home screen, without the logcat read
                    // that "diagnostics" adds. System reads, no network,
                    // so inline. See ApnGuide on the Dart side.
                    result.success(networkFacts())
                }
                "linkFacts" -> {
                    // The MTU, Private DNS mode and transport of the line
                    // under the tunnel, for the door checks. A system read,
                    // no network, so inline. See LinkFacts.
                    result.success(linkFacts())
                }
                "isTelevision" -> {
                    // Read once at launch. A system read, so inline.
                    result.success(isTelevision())
                }
                "isTestLab" -> {
                    // Read once, with the first register. A system read,
                    // so inline. See TestLab on the Dart side.
                    result.success(isTestLab())
                }
                "signingCertificates" -> {
                    // Read once, before Premium loads. A package manager
                    // read, so inline. See PlaySignature on the Dart side.
                    result.success(signingCertificates())
                }
                // The fallback file from another phone: a photo of its QR
                // codes, or a file it sent. See PeerReceiveScreen.
                "peerPhotograph" -> peerHandoff.photograph(result)
                "peerOpenFile" -> peerHandoff.openFile(result)
                // An answer that came back after Android restarted the app.
                "peerLeftover" -> PeerHandoff.takeLeftover(result)
                "qrModules" -> {
                    // A link as a QR code, for a TV to show to a phone.
                    val text = call.argument<String>("text")
                    if (text != null) {
                        result.success(com.vpn.fortivavpn.util.QRCodeDecoder.modules(text))
                    } else {
                        result.error("INVALID_ARGUMENT", "Text is null", null)
                    }
                }
                "diagnostics" -> {
                    // Everything the platform knows that explains a failed
                    // connection. Off the main thread: reading logcat blocks.
                    CoroutineScope(Dispatchers.IO).launch {
                        val diag = collectDiagnostics()
                        runOnUiThread { result.success(diag) }
                    }
                }
                else -> result.notImplemented()
            }
        }
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NoticeJobService.CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "opened" -> {
                    // The message a tapped notification is for, once.
                    result.success(openedNotice)
                    openedNotice = null
                }
                "permission" -> result.success(notificationPermission())
                "askPermission" -> askNotificationPermission(result)
                "rationale" -> result.success(
                    Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
                        shouldShowRequestPermissionRationale(android.Manifest.permission.POST_NOTIFICATIONS),
                )
                "openSettings" -> openNotificationSettings(result)
                "background" -> result.success(backgroundFacts())
                "openBackground" -> openBackgroundSettings(result)
                else -> result.notImplemented()
            }
        }

    }

    /**
     * Takes the VPN slot for a tap (the "takeSlot" call), and answers once
     * the other app's VPN no longer carries this app's traffic, or after
     * [SLOT_TAKE_WAIT_MS]. True when the slot is this app's.
     */
    private fun takeSlotForTap(result: MethodChannel.Result) {
        val asked = try { VpnService.prepare(this) } catch (e: Exception) { result.success(false); return }
        // An intent: the consent is not on record after all, and nothing was taken.
        if (asked != null) {
            result.success(false)
            return
        }
        CoroutineScope(Dispatchers.IO).launch {
            // Android takes the other app's network down a moment later.
            val until = SystemClock.elapsedRealtime() + SLOT_TAKE_WAIT_MS
            while (VpnSlot.otherUp(this@MainActivity) && SystemClock.elapsedRealtime() < until) {
                delay(50)
            }
            runOnUiThread { result.success(true) }
        }
    }

    /**
     * Whether a connect call came from the user's tap, and so may take the
     * VPN slot from another app (VpnSlot). Only the app's first dial after a
     * tap sends `take_slot`; its retries, the next doors of a search and the
     * search after a dead tunnel do not, and an absent value is false.
     */
    private fun takeSlot(call: MethodCall): Boolean = call.argument<Boolean>("take_slot") == true

    private fun connectTunnel(
        link: String,
        alternates: List<String>,
        exits: List<String>,
        penalties: List<Int>,
        outbounds: List<String>,
        takeSlot: Boolean,
        result: MethodChannel.Result?,
        shownAgain: Boolean = false,
    ) {
        withVpnConsent(result, takeSlot, shownAgain, { startConnection(link, alternates, exits, penalties, outbounds, takeSlot, result) }) {
            pendingConnectLink = link
            pendingConnectAlternates = alternates
            pendingConnectExits = exits
            pendingConnectPenalties = penalties
            pendingConnectOutbounds = outbounds
        }
    }

    /** [connectTunnel] for the backup network: the same consent steps and errors. */
    private fun connectPsiphon(
        start: PsiphonStart,
        takeSlot: Boolean,
        result: MethodChannel.Result?,
        shownAgain: Boolean = false,
    ) {
        withVpnConsent(result, takeSlot, shownAgain, { startPsiphon(start, takeSlot, result) }) {
            pendingPsiphon = start
        }
    }

    private fun clearPendingStart() {
        pendingConnectLink = null
        pendingConnectAlternates = emptyList()
        pendingConnectExits = emptyList()
        pendingConnectPenalties = emptyList()
        pendingConnectOutbounds = emptyList()
        pendingPsiphon = null
        pendingShownAgain = false
    }

    /**
     * Runs [onGranted] when the VPN consent is on record. Otherwise [park]
     * stores what to start once it is, and the consent dialog opens; or
     * [result] says why it cannot.
     *
     * Only with [takeSlot], for a tap. prepare() hands this app the VPN slot
     * and tears down any other app's VPN, so a start nobody tapped for runs
     * [onGranted] straight away and lets the service's establish() find out
     * whether the slot is still this app's. It never opens the dialog.
     *
     * [shownAgain]: this request's first dialog closed itself, and this is
     * its second and last (ConsentAgain).
     */
    private fun withVpnConsent(
        result: MethodChannel.Result?,
        takeSlot: Boolean,
        shownAgain: Boolean,
        onGranted: () -> Unit,
        park: () -> Unit,
    ) {
        // A start nobody tapped for reads as consent on record: no prepare(),
        // no dialog. The gate is on the line of the call on purpose, so the
        // app's scan of prepare() calls (test/other_vpn_app_test.dart) sees it.
        val prepareIntent = try {
            if (takeSlot) VpnService.prepare(this) else null
        } catch (e: Exception) {
            // A few ROMs throw out of the system service instead of returning
            // an intent. Nothing we can do but report it honestly.
            Log.e(TAG, "VpnService.prepare failed: ${e.message}")
            result?.error("PERMISSION_UNAVAILABLE", "Could not request VPN permission on this device", null)
            return
        }

        if (prepareIntent == null) {
            onGranted()
            return
        }

        // While another app holds the always-on VPN slot the system closes its
        // own consent dialog on sight, so the user is asked nothing and the
        // request comes back looking like a refusal. Name the real blocker.
        val alwaysOnOwner = alwaysOnVpnOwner()
        if (alwaysOnOwner != null) {
            // The log leaves out the app's name, because this log is sent
            // with connection reports. The name goes only to the screen.
            Log.w(TAG, "Always-on VPN is held by another app; consent dialog cannot open")
            result?.error("PERMISSION_BLOCKED", "Always-on VPN is held by another app", alwaysOnOwner)
            return
        }

        // An earlier request is still parked on the consent dialog. Complete it
        // so its Dart future resolves instead of hanging forever.
        pendingResult?.error("PERMISSION_SUPERSEDED", "Replaced by a newer connection request", null)

        clearPendingStart()
        park()
        pendingShownAgain = shownAgain
        pendingResult = result
        prepareRequestedAt = SystemClock.elapsedRealtime()
        // The time the user spends reading the dialog is theirs. Without this
        // the app's 20 second watchdog failed the attempt while the dialog was
        // still open, and the tunnel then came up under an error message: 18
        // times on 13 phones in the 14 days to 2026-10-02.
        AppEngine.status("awaiting_permission")
        try {
            startActivityForResult(prepareIntent, REQUEST_CODE_VPN_PREPARE)
        } catch (e: ActivityNotFoundException) {
            clearPendingStart()
            pendingResult = null
            Log.e(TAG, "No VPN consent activity on this device: ${e.message}")
            result?.error("PERMISSION_UNAVAILABLE", "This device has no VPN permission dialog", null)
        }
    }

    /**
     * Label of a *different* app occupying the system always-on VPN slot, or
     * null when the slot is free, ours, or unreadable. The setting key is not
     * public API, so anything unexpected has to read as "unknown", never as
     * "blocked" — a wrong "blocked" would refuse a connection that would work.
     */
    private fun alwaysOnVpnOwner(): String? {
        val pkg = try {
            Settings.Secure.getString(contentResolver, SETTING_ALWAYS_ON_VPN)
        } catch (e: Exception) {
            Log.w(TAG, "Could not read $SETTING_ALWAYS_ON_VPN: ${e.message}")
            null
        }
        if (pkg.isNullOrEmpty() || pkg == packageName) return null
        return try {
            packageManager.getApplicationInfo(pkg, 0).loadLabel(packageManager).toString()
        } catch (e: PackageManager.NameNotFoundException) {
            // Package visibility can hide the owner even when the slot is taken.
            pkg
        }
    }

    /**
     * The host the phone sends its DNS to when Private DNS is set to a
     * provider by name, or null when it is off or automatic.
     *
     * Android keeps using that provider while a VPN is up, so the tunnel's
     * own resolver is never asked. Many providers popular in Iran do not
     * answer for filtered sites: on 2026-10-02 a user's phone moved data
     * through the tunnel while YouTube failed with "DNS address could not
     * be found". Read from every network, because the setting shows on the
     * underlying network's LinkProperties and not always on the VPN's.
     */
    private fun privateDnsHost(): String? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.P) return null
        return try {
            val cm = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
            @Suppress("DEPRECATION")
            cm.allNetworks.firstNotNullOfOrNull { network ->
                cm.getLinkProperties(network)?.privateDnsServerName?.takeIf { it.isNotBlank() }
            }
        } catch (e: Exception) {
            Log.w(TAG, "privateDns: ${e.message}")
            null
        }
    }

    /**
     * The Private DNS host when it is set and name lookups fail, or null.
     *
     * Most providers work through the tunnel, and then there is nothing to
     * tell the user. Some providers in Iran answer only phones inside Iran,
     * and through the tunnel the phone reaches them from abroad. Only then
     * does every lookup fail, and only then is the user asked to change the
     * setting. The lookup skips the cache, so an answer from before the
     * tunnel came up cannot hide the failure.
     */
    private fun privateDnsHostThatFails(): String? {
        val host = privateDnsHost() ?: return null
        // While the tunnel is up, ask the provider the way the phone's own
        // lookups reach it: through the core. This app is excluded from its
        // own tunnel, so lookupWorks() asks over the phone's network, which
        // in Iran is the wrong answer both ways. A provider blocked there but
        // fine through the tunnel (dns.google) got a warning it did not
        // deserve.
        if (isVpnActive()) return if (privateDnsAnswersThroughTunnel(host)) null else host
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return host
        return if (lookupWorks()) null else host
    }

    /**
     * One DNS over TLS lookup of www.google.com at [host], through the core's
     * SOCKS port, within about five seconds.
     *
     * The core routes it as it routes the phone's own lookups to that
     * provider: by name, so an Iranian provider goes out direct and the rest
     * go through the tunnel. The certificate is checked against [host], as
     * Android checks it in strict Private DNS mode.
     */
    private fun privateDnsAnswersThroughTunnel(host: String): Boolean {
        return try {
            val proxy = Proxy(
                Proxy.Type.SOCKS,
                InetSocketAddress(AppConfig.LOOPBACK, SettingsManager.getSocksPort()),
            )
            Socket(proxy).use { raw ->
                raw.soTimeout = 5000
                raw.connect(InetSocketAddress.createUnresolved(host, 853), 5000)
                val factory = javax.net.ssl.SSLSocketFactory.getDefault() as javax.net.ssl.SSLSocketFactory
                (factory.createSocket(raw, host, 853, true) as javax.net.ssl.SSLSocket).use { tls ->
                    tls.sslParameters = tls.sslParameters.apply {
                        endpointIdentificationAlgorithm = "HTTPS"
                    }
                    tls.startHandshake()
                    val query = dnsQueryA("www.google.com")
                    tls.outputStream.apply {
                        write(byteArrayOf((query.size shr 8).toByte(), query.size.toByte()))
                        write(query)
                        flush()
                    }
                    val input = java.io.DataInputStream(tls.inputStream)
                    val reply = ByteArray(input.readUnsignedShort())
                    input.readFully(reply)
                    val rcode = reply[3].toInt() and 0x0F
                    val answers = ((reply[6].toInt() and 0xFF) shl 8) or (reply[7].toInt() and 0xFF)
                    rcode == 0 && answers > 0
                }
            }
        } catch (e: Exception) {
            Log.w(TAG, "privateDns through tunnel: ${e.javaClass.simpleName}: ${e.message}")
            false
        }
    }

    /** A recursive DNS query for [name], type A, class IN. */
    private fun dnsQueryA(name: String): ByteArray {
        val out = java.io.ByteArrayOutputStream()
        out.write(byteArrayOf(0x46, 0x56, 0x01, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00))
        for (label in name.split('.')) {
            val bytes = label.toByteArray(Charsets.US_ASCII)
            out.write(bytes.size)
            out.write(bytes)
        }
        out.write(byteArrayOf(0x00, 0x00, 0x01, 0x00, 0x01))
        return out.toByteArray()
    }

    /** A fresh lookup of a name that always exists, within five seconds. */
    private fun lookupWorks(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return true
        return try {
            val cm = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
            val network = cm.activeNetwork ?: return true
            val done = java.util.concurrent.CountDownLatch(1)
            var ok = false
            android.net.DnsResolver.getInstance().query(
                network,
                "www.google.com",
                android.net.DnsResolver.FLAG_NO_CACHE_LOOKUP,
                java.util.concurrent.Executors.newSingleThreadExecutor(),
                null,
                object : android.net.DnsResolver.Callback<List<java.net.InetAddress>> {
                    override fun onAnswer(answer: List<java.net.InetAddress>, rcode: Int) {
                        ok = answer.isNotEmpty()
                        done.countDown()
                    }

                    override fun onError(error: android.net.DnsResolver.DnsException) {
                        done.countDown()
                    }
                },
            )
            done.await(5, java.util.concurrent.TimeUnit.SECONDS)
            ok
        } catch (e: Exception) {
            Log.w(TAG, "lookupWorks: ${e.message}")
            true
        }
    }

    /** The system screen where Private DNS lives, or the settings home. */
    private fun openNetworkSettings(result: MethodChannel.Result) {
        for (action in listOf(Settings.ACTION_WIRELESS_SETTINGS, Settings.ACTION_SETTINGS)) {
            try {
                startActivity(Intent(action))
                result.success(true)
                return
            } catch (e: ActivityNotFoundException) {
                Log.w(TAG, "No activity for $action")
            }
        }
        result.success(false)
    }

    /**
     * The phone's list of access points (APNs) for the SIM, where the APN
     * guide on the home screen sends the user to set the APN protocol to
     * IPv4/IPv6. Some phones have no such screen for other apps to open, or
     * keep it to the system and throw SecurityException, so the wireless
     * settings come next and the settings home last. False only when none
     * of them opened.
     */
    private fun openApnSettings(result: MethodChannel.Result) {
        for (action in listOf(
            Settings.ACTION_APN_SETTINGS,
            Settings.ACTION_WIRELESS_SETTINGS,
            Settings.ACTION_SETTINGS,
        )) {
            try {
                startActivity(Intent(action).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                result.success(true)
                return
            } catch (e: ActivityNotFoundException) {
                Log.w(TAG, "No activity for $action")
            } catch (e: SecurityException) {
                Log.w(TAG, "Not allowed to open $action")
            }
        }
        result.success(false)
    }

    /**
     * Ask Play for its in-app review card and show it.
     *
     * Play never says whether the card appeared or what the user chose: a
     * spent quota, a user who has already rated and a shown card all end in
     * success. So the answer is only whether the request reached Play, and
     * the error code when it did not, for the log.
     */
    private fun requestReview(result: MethodChannel.Result) {
        try {
            val manager = ReviewManagerFactory.create(this)
            manager.requestReviewFlow().addOnCompleteListener { request ->
                if (!request.isSuccessful) {
                    val code = (request.exception as? ReviewException)?.errorCode ?: -1
                    Log.w(TAG, "Review flow not available: $code")
                    result.success(mapOf("ok" to false, "error" to code))
                    return@addOnCompleteListener
                }
                if (isFinishing || isDestroyed) {
                    result.success(mapOf("ok" to false, "error" to "activity_gone"))
                    return@addOnCompleteListener
                }
                manager.launchReviewFlow(this, request.result).addOnCompleteListener {
                    result.success(mapOf("ok" to true))
                }
            }
        } catch (e: Exception) {
            Log.w(TAG, "Review flow failed: ${e.message}")
            result.success(mapOf("ok" to false, "error" to (e.message ?: "exception")))
        }
    }

    /**
     * Open this app's page in the Play Store app, or in a browser when the
     * Play Store is missing. A Settings item uses this: Google's rules say a
     * button must open the listing, never the review card.
     */
    private fun openPlayListing(result: MethodChannel.Result) {
        val uri = Uri.parse("https://play.google.com/store/apps/details?id=$packageName")
        for (intent in listOf(
            Intent(Intent.ACTION_VIEW, uri).setPackage("com.android.vending"),
            Intent(Intent.ACTION_VIEW, uri),
        )) {
            try {
                startActivity(intent)
                result.success(true)
                return
            } catch (e: ActivityNotFoundException) {
                Log.w(TAG, "No activity for the Play listing (${intent.`package`})")
            }
        }
        result.success(false)
    }

    /** Send the user to the system VPN screen so they can free the slot. */
    private fun openVpnSettings(result: MethodChannel.Result) {
        for (action in listOf(Settings.ACTION_VPN_SETTINGS, Settings.ACTION_SETTINGS)) {
            try {
                startActivity(Intent(action))
                result.success(true)
                return
            } catch (e: ActivityNotFoundException) {
                Log.w(TAG, "No activity for $action")
            }
        }
        result.success(false)
    }
    
    private fun startConnection(
        link: String,
        alternates: List<String>,
        exits: List<String>,
        penalties: List<Int>,
        outbounds: List<String>,
        takeSlot: Boolean,
        result: MethodChannel.Result?,
    ) {
        Log.d(TAG, "Connection link: ${TestLink.redact(link)}")
        CoroutineScope(Dispatchers.IO).launch {
             try {
                 // A normal connect ends any backup network session, so
                 // no restart brings it back.
                 PsiphonSession.clear()
                 MmkvManager.removeAllServer()
                 val importResult = AngConfigManager.importBatchConfig(link, "", false)
                 
                 if (importResult.first > 0) {
                     val servers = MmkvManager.decodeServerList()
                     if (servers.isNotEmpty()) {
                         val guid = servers[0]
                         val doors = importStandbyDoors(guid, alternates)
                         MmkvManager.encodeSettings(AppConfig.PREF_AUTOSELECT_GUIDS, doors)
                         MmkvManager.encodeSettings(
                             AppConfig.PREF_AUTOSELECT_EXITS,
                             if (doors.isEmpty()) "" else exits.joinToString(",") { it.replace(",", "") },
                         )
                         MmkvManager.encodeSettings(
                             AppConfig.PREF_AUTOSELECT_PENALTIES,
                             if (doors.isEmpty()) "" else penalties.joinToString(","),
                         )
                         writeDoorOutbounds(if (doors.isEmpty()) listOf(guid) else doors.split(","), outbounds)
                         MmkvManager.setSelectServer(guid)
                         
                         // Start directly in VPN mode (no proxy-mode dance)
                         MmkvManager.encodeSettings(AppConfig.PREF_MODE, AppConfig.VPN)
                         
                         launch(Dispatchers.Main) {
                             V2RayServiceManager.startVService(this@MainActivity, takeSlot = takeSlot)
                             result?.success(null)
                         }
                     } else {
                         launch(Dispatchers.Main) {
                            result?.error("CONFIG_ERROR", "Imported config not found", null)
                         }
                     }
                 } else {
                     launch(Dispatchers.Main) {
                        result?.error("IMPORT_FAILED", "Failed to parse connection link", null)
                     }
                 }
             } catch (e: Exception) {
                 Log.e(TAG, "Connection error: ${e.message}")
                 launch(Dispatchers.Main) {
                    result?.error("EXCEPTION", e.message, null)
                 }
             }
        }
    }
    
    /**
     * [startConnection] for the backup network. The selected profile
     * becomes a SOCKS proxy at 127.0.0.1 on a free port, where the
     * tunnel's process starts the library's proxy (PsiphonCore), and the
     * session is stored for every start of the service to read
     * (PsiphonSession). No standby doors.
     */
    private fun startPsiphon(start: PsiphonStart, takeSlot: Boolean, result: MethodChannel.Result?) {
        Log.d(TAG, "Backup network connect")
        CoroutineScope(Dispatchers.IO).launch {
            try {
                val port = Utils.findFreePort(listOf(0))
                MmkvManager.removeAllServer()
                // The session is written before its profile, which the
                // store selects as soon as it is written: a service start
                // never finds the profile selected without its session.
                val guid = Utils.getUuid()
                check(guid.isNotBlank()) { "No id for the backup network profile" }
                PsiphonSession.write(PsiphonSession(guid, port, start.config, start.timeoutMs, start.entriesFile))
                MmkvManager.encodeServerConfig(guid, PsiphonSession.profile(port))
                MmkvManager.encodeSettings(AppConfig.PREF_AUTOSELECT_GUIDS, "")
                MmkvManager.encodeSettings(AppConfig.PREF_AUTOSELECT_EXITS, "")
                MmkvManager.encodeSettings(AppConfig.PREF_AUTOSELECT_PENALTIES, "")
                writeDoorOutbounds(emptyList(), emptyList())
                MmkvManager.setSelectServer(guid)
                MmkvManager.encodeSettings(AppConfig.PREF_MODE, AppConfig.VPN)
                launch(Dispatchers.Main) {
                    V2RayServiceManager.startVService(this@MainActivity, takeSlot = takeSlot)
                    result?.success(null)
                }
            } catch (e: Exception) {
                Log.e(TAG, "Backup network connect error: ${e.javaClass.simpleName}")
                launch(Dispatchers.Main) {
                    result?.error("EXCEPTION", e.message, null)
                }
            }
        }
    }

    /**
     * Keeps the backend's outbound of each door of this connect for the
     * tunnel's process, by guid (DoorOutbounds.encode). [guids] are the
     * doors in the order the app sent them, and [entries] what it sent for
     * each. Written when a door has one or an earlier connect left some, so
     * a phone that never got one stores nothing new.
     */
    private fun writeDoorOutbounds(guids: List<String>, entries: List<String>) {
        val encoded = DoorOutbounds.encode(guids, entries)
        if (encoded.isNotEmpty() || !MmkvManager.decodeSettingsString(AppConfig.PREF_DOOR_OUTBOUNDS).isNullOrEmpty()) {
            MmkvManager.encodeSettings(AppConfig.PREF_DOOR_OUTBOUNDS, encoded)
        }
    }

    /**
     * The penalties a connect call carried, in whole milliseconds. The
     * channel hands a Dart int over as an Int or a Long, by its size, and
     * anything that is not a positive number is no penalty.
     */
    private fun doorPenalties(raw: List<Any?>?): List<Int> =
        raw.orEmpty().map { (it as? Number)?.toLong()?.coerceIn(0L, Int.MAX_VALUE.toLong())?.toInt() ?: 0 }

    /**
     * Imports [alternates] next to the door already stored as [guid] and
     * returns what PREF_AUTOSELECT_GUIDS should hold: every door's guid in
     * the order the app sent them, or an empty string when there is only the
     * one. A link that does not import leaves an empty entry, so a door's
     * position here is its position in the app's list.
     */
    private fun importStandbyDoors(guid: String, alternates: List<String>): String {
        if (alternates.isEmpty()) return ""
        val doors = mutableListOf(guid)
        for (link in alternates.take(MAX_STANDBY_DOORS)) {
            val before = MmkvManager.decodeServerList().toSet()
            val imported = try {
                AngConfigManager.importBatchConfig(link, "", false).first > 0
            } catch (e: Exception) {
                Log.w(TAG, "A standby door did not import: ${e.message}")
                false
            }
            val added = if (imported) MmkvManager.decodeServerList().firstOrNull { it !in before } else null
            doors.add(added.orEmpty())
        }
        return if (doors.any { it.isNotEmpty() && it != guid }) doors.joinToString(",") else ""
    }

    /**
     * "granted" when message notifications would show. "ask" when Android 13
     * or later has not granted POST_NOTIFICATIONS: its dialog may still show,
     * or may not, because Android shows none after the user refused twice.
     * "denied" when the permission is not the problem: Android 12 or earlier,
     * or the app's or this channel's notifications are off in the system
     * settings, which only the user can change there.
     */
    private fun notificationPermission(): String {
        if (NoticeNotifier.allowed(this)) return "granted"
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return "denied"
        val granted = checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED
        // Allowed, but the app's notifications or this channel are off in the
        // system settings. Only the user can turn them back on there.
        return if (granted) "denied" else "ask"
    }

    /**
     * Show Android's dialog for POST_NOTIFICATIONS, and answer with
     * [notificationPermission] once the user has answered. The manifest
     * already declares the permission, for the tunnel's notification; only
     * the question is new.
     */
    private fun askNotificationPermission(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU || pendingNotificationAnswer != null) {
            result.success(notificationPermission())
            return
        }
        pendingNotificationAnswer = result
        try {
            requestPermissions(
                arrayOf(android.Manifest.permission.POST_NOTIFICATIONS),
                REQUEST_CODE_NOTIFICATIONS,
            )
        } catch (e: Exception) {
            Log.e(TAG, "could not ask for notifications", e)
            pendingNotificationAnswer = null
            result.success(notificationPermission())
        }
    }

    /**
     * The system page with this app's notification settings, where the user
     * can turn them on whatever they answered before. On Android 13 and
     * later, turning them on there also grants POST_NOTIFICATIONS. Falls
     * back to the app's details page.
     */
    private fun openNotificationSettings(result: MethodChannel.Result) {
        val intents = buildList {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                add(
                    Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                        .putExtra(Settings.EXTRA_APP_PACKAGE, packageName),
                )
            }
            add(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.fromParts("package", packageName, null)))
        }
        for (intent in intents) {
            try {
                startActivity(intent)
                result.success(true)
                return
            } catch (e: ActivityNotFoundException) {
                Log.w(TAG, "No activity for ${intent.action}")
            }
        }
        result.success(false)
    }

    /**
     * What on this phone may stop the background checks for messages:
     * the maker, whether battery optimization applies to the app, whether
     * the user restricted its background use, its standby bucket (45 is
     * "restricted") and whether Data Saver blocks its background data.
     * System reads only; nothing here leaves the phone.
     */
    private fun backgroundFacts(): Map<String, Any?> {
        val out = HashMap<String, Any?>()
        out["brand"] = Build.MANUFACTURER?.lowercase()
        // When the phone last started, so a gap in the checks from a phone
        // that was off, or rebooted and not opened, is not blamed on its
        // battery settings.
        out["booted_at"] = System.currentTimeMillis() - SystemClock.elapsedRealtime()
        try {
            val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
            out["optimized"] = !pm.isIgnoringBatteryOptimizations(packageName)
        } catch (_: Exception) {}
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            try {
                val am = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
                out["restricted"] = am.isBackgroundRestricted
            } catch (_: Exception) {}
            try {
                val usage = getSystemService(Context.USAGE_STATS_SERVICE) as android.app.usage.UsageStatsManager
                out["bucket"] = usage.appStandbyBucket
            } catch (_: Exception) {}
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            try {
                val cm = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
                out["data_saver"] = cm.restrictBackgroundStatus ==
                    ConnectivityManager.RESTRICT_BACKGROUND_STATUS_ENABLED
            } catch (_: Exception) {}
        }
        return out
    }

    /**
     * The system screen where the user lets the app run in the background,
     * the right one for this phone's maker where it has its own, else
     * Android's list of battery optimization, else the app's details page.
     * With Data Saver on, its page for this app comes first. Each maker's
     * page has moved between versions, so several are tried. Answers which
     * kind opened: "data", "maker", "battery", "details", or null.
     */
    private fun openBackgroundSettings(result: MethodChannel.Result) {
        val tries = ArrayList<Pair<String, Intent>>()
        val details = Intent(
            Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
            Uri.fromParts("package", packageName, null),
        )
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            try {
                val cm = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
                if (cm.restrictBackgroundStatus == ConnectivityManager.RESTRICT_BACKGROUND_STATUS_ENABLED) {
                    tries.add(
                        "data" to Intent(
                            Settings.ACTION_IGNORE_BACKGROUND_DATA_RESTRICTIONS_SETTINGS,
                            Uri.fromParts("package", packageName, null),
                        ),
                    )
                }
            } catch (_: Exception) {}
        }
        val brand = Build.MANUFACTURER?.lowercase().orEmpty()
        val maker = when {
            brand.contains("xiaomi") || brand.contains("redmi") || brand.contains("poco") -> listOf(
                "com.miui.securitycenter" to "com.miui.permcenter.autostart.AutoStartManagementActivity",
            )
            brand.contains("huawei") || brand.contains("honor") -> listOf(
                "com.huawei.systemmanager" to "com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity",
                "com.huawei.systemmanager" to "com.huawei.systemmanager.optimize.process.ProtectActivity",
            )
            brand.contains("oppo") || brand.contains("realme") || brand.contains("oneplus") -> listOf(
                "com.coloros.safecenter" to "com.coloros.safecenter.permission.startup.StartupAppListActivity",
                "com.coloros.safecenter" to "com.coloros.safecenter.startupapp.StartupAppListActivity",
                "com.oppo.safe" to "com.oppo.safe.permission.startup.StartupAppListActivity",
            )
            brand.contains("vivo") || brand.contains("iqoo") -> listOf(
                "com.vivo.permissionmanager" to "com.vivo.permissionmanager.activity.BgStartUpManagerActivity",
                "com.iqoo.secure" to "com.iqoo.secure.ui.phoneoptimize.AddWhiteListActivity",
            )
            else -> emptyList()
        }
        for ((pkg, cls) in maker) {
            tries.add("maker" to Intent().setComponent(ComponentName(pkg, cls)))
        }
        // Samsung puts apps it thinks are unused to sleep. The app's own
        // battery page, through its details, has "Unrestricted".
        if (brand.contains("samsung")) tries.add("details" to details)
        tries.add("battery" to Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))
        tries.add("details" to details)
        for ((kind, intent) in tries) {
            try {
                startActivity(intent)
                result.success(kind)
                return
            } catch (e: ActivityNotFoundException) {
                Log.w(TAG, "No activity for ${intent.component ?: intent.action}")
            } catch (e: SecurityException) {
                Log.w(TAG, "Not allowed to open ${intent.component ?: intent.action}")
            }
        }
        result.success(null)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != REQUEST_CODE_NOTIFICATIONS) return
        val state = notificationPermission()
        // A tunnel already up posted its notification while notifications
        // were not allowed, and Android keeps that one hidden.
        if (state == "granted") {
            MessageUtil.sendMsg2Service(this, AppConfig.MSG_REPOST_NOTIFICATION, "")
            NoticeJobs.ensureScheduled(this)
        }
        val answer = pendingNotificationAnswer ?: return
        pendingNotificationAnswer = null
        answer.success(state)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (peerHandoff.onActivityResult(requestCode, resultCode, data)) return
        if (requestCode != REQUEST_CODE_VPN_PREPARE) return

        val link = pendingConnectLink
        val alternates = pendingConnectAlternates
        val exits = pendingConnectExits
        val penalties = pendingConnectPenalties
        val outbounds = pendingConnectOutbounds
        val psiphon = pendingPsiphon
        val shownAgain = pendingShownAgain
        val result = pendingResult
        val elapsed = SystemClock.elapsedRealtime() - prepareRequestedAt
        clearPendingStart()
        pendingResult = null
        prepareRequestedAt = 0L

        // resultCode on its own is not trustworthy: several OEM ROMs hand back
        // RESULT_CANCELED even when the user tapped OK, and the dialog is also
        // cancelled if the activity is recreated underneath it. prepare() is the
        // ground truth — it returns null only once consent is on record.
        val granted = resultCode == RESULT_OK ||
            (try { VpnService.prepare(this) } catch (e: Exception) { null }) == null

        if (!granted) {
            // A dialog answered this quickly was never on screen: the system
            // closed it before the user could see it. Telling them to "tap OK"
            // sends them looking for a dialog that will never appear.
            if (elapsed in 0 until SILENT_CANCEL_MS) {
                val owner = alwaysOnVpnOwner()
                // Once more, the way the user's next tap would: through the
                // same consent steps, which call prepare() for a tap only.
                val again = ConsentAgain.shouldAsk(
                    elapsed,
                    SILENT_CANCEL_MS,
                    shownAgain,
                    owner,
                    hasStart = link != null || psiphon != null,
                )
                if (again && psiphon != null) {
                    Log.w(TAG, "VPN consent dialog closed itself after ${elapsed}ms; asking once more")
                    connectPsiphon(psiphon, takeSlot = true, result, shownAgain = true)
                    return
                }
                if (again && link != null) {
                    Log.w(TAG, "VPN consent dialog closed itself after ${elapsed}ms; asking once more")
                    connectTunnel(link, alternates, exits, penalties, outbounds, takeSlot = true, result, shownAgain = true)
                    return
                }
                Log.w(TAG, "VPN consent dialog closed itself after ${elapsed}ms (resultCode=$resultCode)")
                result?.error(
                    "PERMISSION_BLOCKED",
                    "The VPN permission dialog did not appear",
                    owner,
                )
                return
            }
            Log.w(TAG, "VPN consent refused after ${elapsed}ms (resultCode=$resultCode)")
            result?.error("PERMISSION_DENIED", "VPN permission was denied", null)
            return
        }

        if (psiphon != null) {
            Log.d(TAG, "VPN consent granted, starting the backup network")
            startPsiphon(psiphon, takeSlot = true, result)
            return
        }

        if (link == null) {
            // Consent granted, but the activity was rebuilt and lost the link.
            Log.w(TAG, "VPN consent granted but no pending link")
            result?.error("PERMISSION_GRANTED_NO_LINK", "VPN permission granted", null)
            return
        }

        Log.d(TAG, "VPN consent granted, starting connection")
        startConnection(link, alternates, exits, penalties, outbounds, takeSlot = true, result)
    }

    /**
     * The carrier and transport, as the two system services report them.
     *
     * Split out of collectDiagnostics because a heartbeat wants exactly this
     * and none of the rest: the log tail alone costs a logcat exec, which is
     * not something to run every five minutes for one string.
     */
    private fun networkFacts(): Map<String, Any?> = TunnelProbe.networkFacts(this)

    /**
     * The value this install is known by on this device, or null when the
     * system will not give one.
     *
     * Null is a supported answer: DeviceIdentity mints a random UUID
     * instead, which loses reinstall survival and nothing else. That is a
     * better outcome than a value shared with other devices.
     */
    private fun installId(): String? {
        return try {
            Settings.Secure.getString(contentResolver, Settings.Secure.ANDROID_ID)
                ?.takeIf { it.isNotBlank() }
        } catch (e: Exception) {
            Log.e(TAG, "install id unavailable: ${e.message}")
            null
        }
    }

    /**
     * Test VPN connectivity by making an HTTP request through V2Ray's local SOCKS proxy.
     *
     * Since the app is excluded from the VPN tunnel (to prevent routing loops),
     * we can't test by making a normal HTTP request. Instead we connect through
     * the SOCKS5 proxy that V2Ray exposes on 127.0.0.1:socksPort.
     * This verifies the entire chain: app → SOCKS → V2Ray → remote server → internet.
     */
    /**
     * Download a fixed-size object through the tunnel and say how long it
     * took. Returns {bytes, ms}, or null when nothing could be measured,
     * or {bytes: 0, ms, status} when the page answered with a status
     * other than 200, which the stall watch reads as no word on the tunnel.
     *
     * Through the core's own SOCKS proxy, for the same reason the
     * connection test goes that way: this app is excluded from its own
     * tunnel, so an ordinary request here would measure the bare carrier
     * and report it as the tunnel's speed.
     *
     * Stops at [capMs] with whatever it has rather than failing. A link
     * slow enough to miss the deadline is exactly the reading worth
     * having, and a timeout would throw it away.
     *
     * The clock starts once the response headers have arrived, so `ms` is
     * the time the bytes took and not the connection's setup through the
     * tunnel. The connection and the wait for the headers keep their own
     * [capMs] limits. See [ThroughputSample].
     */
    private fun throughputSample(bytes: Int, capMs: Int, result: MethodChannel.Result) {
        CoroutineScope(Dispatchers.IO).launch {
            var sample: HashMap<String, Any>? = null
            try {
                val socksPort = SettingsManager.getSocksPort()
                val proxy = Proxy(Proxy.Type.SOCKS, InetSocketAddress("127.0.0.1", socksPort))
                val url = URL("https://speed.cloudflare.com/__down?bytes=$bytes")
                val conn = url.openConnection(proxy) as HttpURLConnection
                conn.connectTimeout = capMs
                conn.readTimeout = capMs
                try {
                    // The page itself refusing says nothing about the
                    // tunnel: the stall watch falls back to its older check.
                    sample = ThroughputSample.take(capMs, SystemClock::elapsedRealtime) {
                        val code = conn.responseCode
                        code to (if (code == HttpURLConnection.HTTP_OK) conn.inputStream else null)
                    }
                } finally {
                    conn.disconnect()
                }
            } catch (e: Exception) {
                Log.e(TAG, "throughput sample failed: ${e.message}")
            }
            runOnUiThread { result.success(sample) }
        }
    }

    private fun testConnectionViaSocks(result: MethodChannel.Result) {
        CoroutineScope(Dispatchers.IO).launch {
            val works = TunnelProbe.tunnelCarries()
            launch(Dispatchers.Main) { result.success(works) }
        }
    }

    /**
     * Real ping: build a temporary config from a connection link and measure
     * actual outbound delay through the proxy.
     *
     * This tests the ENTIRE chain: core → TLS handshake → remote server → internet.
     * If the link is disabled or the server is broken, it correctly returns -1 (timeout).
     *
     * Builds the config in memory and does not touch MmkvManager storage, so
     * it is safe to call while the VPN is connected.
     *
     * With [door], the backend's outbound for this door, the check dials
     * that in place of the outbound read from the link (DoorOutbounds), and
     * the link when the core never starts it ([doorDelay]).
     */
    private fun realPing(
        link: String,
        timeoutMs: Long,
        splitter: TlsFragment.Spec?,
        door: DoorOutbound?,
        result: MethodChannel.Result,
    ) {
        CoroutineScope(Dispatchers.IO).launch {
            try {
                // Parse the connection link into a ProfileItem and the
                // outbound it dials (in-memory, no storage). Any kind the
                // tunnel dials, not vless only. See TestLink.
                val read = TestLink.read(link)
                if (read == null) {
                    Log.w(TAG, "realPing: failed to read connection link")
                    launch(Dispatchers.Main) { result.success(-1) }
                    return@launch
                }
                val (profile, outbound) = read

                val delay = if (door != null) {
                    doorDelay(door, splitter, timeoutMs) {
                        TestLink.config(outbound, TlsFragment.parse(profile.fragment), splitter)
                    }
                } else {
                    // The outbound alone, with no inbounds, routing or DNS,
                    // which is all measureOutboundDelay needs. See TestLink.config.
                    val minimalConfig = TestLink.config(
                        outbound,
                        TlsFragment.parse(profile.fragment),
                        splitter,
                    )

                    // Measure outbound delay within the app's wait, 3 s unless it
                    // names one (TestLink.timeoutMs). Without a limit the core's
                    // measureOutboundDelay blocks for ~10s on TLS failures,
                    // creating zombie coroutines that accumulate and slow everything down.
                    val deferred = async(Dispatchers.IO) {
                        SpeedtestManager.realPing(minimalConfig)
                    }
                    withTimeoutOrNull(timeoutMs) { deferred.await() } ?: -1L
                }

                Log.d(TAG, "realPing result: ${delay}ms for link: ${TestLink.redact(link)}")
                launch(Dispatchers.Main) {
                    result.success(delay)
                }
            } catch (e: Exception) {
                Log.e(TAG, "realPing failed: ${e.message}")
                launch(Dispatchers.Main) {
                    result.success(-1)
                }
            }
        }
    }

    /**
     * [realPing]'s delay for a door with the backend's outbound [door]. When
     * the core never started that outbound (DoorOutbounds.notStarted), the
     * door is checked again from [linkConfig], its link's test config, as
     * the tunnel then starts from the link (CoreStart). Both checks end
     * within the one wait of [timeoutMs].
     */
    private suspend fun CoroutineScope.doorDelay(
        door: DoorOutbound,
        splitter: TlsFragment.Spec?,
        timeoutMs: Long,
        linkConfig: () -> String,
    ): Long {
        val deadline = SystemClock.elapsedRealtime() + timeoutMs
        val config = DoorOutbounds.testConfig(door, splitter)
        val check = async(Dispatchers.IO) { SpeedtestManager.realPingWithError(config) }
        val (delay, error) = withTimeoutOrNull(timeoutMs) { check.await() } ?: (-1L to null)
        if (delay >= 0 || !DoorOutbounds.notStarted(error)) return delay
        Log.w(TAG, "[doors] the core did not start the backend's outbound for a door check; checking the link")
        val fromLink = linkConfig()
        val again = async(Dispatchers.IO) { SpeedtestManager.realPing(fromLink) }
        return withTimeoutOrNull(deadline - SystemClock.elapsedRealtime()) { again.await() } ?: -1L
    }

    /**
     * [realPing] for the door checks, as a map: `ms` (the delay, or -1) and
     * `elapsedMs` always; on a failure also `error` (the core's words,
     * shortened) and, when the link names an address, `tcp` and `tcpMs`: how a
     * plain TCP connection to that address went, opened at the same time as
     * the check so it costs no extra wait. See DoorCheck for why.
     *
     * With [timed], and when this process could prepare it, the check is the
     * core's timed one (DoorChecks): the same check, with `timed` true and
     * its timeline in the map, and open or closed by the same rule. When the
     * timed check cannot run, the plain one does, and the map says nothing
     * of it.
     *
     * With [door], the backend's outbound for this door, the check dials
     * that in place of the outbound read from the link, and the plain TCP
     * connection goes to the address it names (DoorOutbounds). When the core
     * never starts that outbound, the link is checked in its place, within
     * the same wait. [url] is what the check fetches through the door, the
     * app's own when null.
     */
    private fun realPingDetail(
        link: String,
        timeoutMs: Long,
        splitter: TlsFragment.Spec?,
        timed: Boolean,
        door: DoorOutbound?,
        url: String?,
        result: MethodChannel.Result,
    ) {
        CoroutineScope(Dispatchers.IO).launch {
            val out = mutableMapOf<String, Any?>("ms" to -1L)
            val started = SystemClock.elapsedRealtime()
            try {
                val read = TestLink.read(link)
                if (read == null) {
                    out["error"] = "link could not be read"
                } else {
                    val (profile, outbound) = read
                    val testUrl = url ?: SettingsManager.getDelayTestUrl()
                    // The backend's outbound first, when the door has one.
                    // When the core never starts it, the link is checked
                    // instead, as the tunnel then starts from the link
                    // (CoreStart). Both checks end within the one wait.
                    val deadline = if (door != null) SystemClock.elapsedRealtime() + timeoutMs else null
                    val checked = door != null && checkInto(
                        out,
                        DoorOutbounds.testConfig(door, splitter),
                        tcpReach(DoorOutbounds.endpoint(door.outbound)),
                        timeoutMs,
                        timed,
                        testUrl,
                        deadline,
                        refusable = true,
                    )
                    if (door != null && !checked) {
                        Log.w(TAG, "[doors] the core did not start the backend's outbound for a door check; checking the link")
                    }
                    if (!checked) {
                        val tcp = tcpReach(profile.server, profile.serverPort?.toIntOrNull())
                        val config = TestLink.config(
                            outbound,
                            TlsFragment.parse(profile.fragment),
                            splitter,
                        )
                        checkInto(out, config, tcp, timeoutMs, timed, testUrl, deadline)
                    }
                }
            } catch (e: Exception) {
                out["ms"] = -1L
                out["error"] = DoorCheck.shorten(e.message ?: e.javaClass.simpleName)
            }
            out["elapsedMs"] = SystemClock.elapsedRealtime() - started
            Log.d(TAG, "realPingDetail: ${out["ms"]}ms tcp=${out["tcp"]} for ${TestLink.redact(link)}")
            launch(Dispatchers.Main) { result.success(out) }
        }
    }

    /**
     * [realPingDetail] for a variant test's own [config], already made ready
     * by DoorOutbounds.checkConfig: the same check and the same map. The
     * plain TCP connection goes to the address its outbound tagged proxy
     * names, when it names one the usual way. [url] is the backend's.
     */
    private fun realPingConfig(
        config: String,
        timeoutMs: Long,
        timed: Boolean,
        url: String,
        result: MethodChannel.Result,
    ) {
        CoroutineScope(Dispatchers.IO).launch {
            val out = mutableMapOf<String, Any?>("ms" to -1L)
            val started = SystemClock.elapsedRealtime()
            try {
                val proxy = JsonParser.parseString(config).asJsonObject
                    .getAsJsonArray("outbounds")[0].asJsonObject
                checkInto(out, config, tcpReach(DoorOutbounds.endpoint(proxy)), timeoutMs, timed, url)
            } catch (e: Exception) {
                out["ms"] = -1L
                out["error"] = DoorCheck.shorten(e.message ?: e.javaClass.simpleName)
            }
            out["elapsedMs"] = SystemClock.elapsedRealtime() - started
            Log.d(TAG, "realPingConfig: ${out["ms"]}ms tcp=${out["tcp"]}")
            launch(Dispatchers.Main) { result.success(out) }
        }
    }

    /** A plain TCP connection to [host] and [port], opened now, or null without both. */
    private fun CoroutineScope.tcpReach(host: String?, port: Int?): Deferred<Pair<String, Long>>? =
        if (!host.isNullOrEmpty() && port != null) async(Dispatchers.IO) { DoorCheck.tcpReach(host, port) } else null

    private fun CoroutineScope.tcpReach(endpoint: Pair<String, Int>?): Deferred<Pair<String, Long>>? =
        tcpReach(endpoint?.first, endpoint?.second)

    /**
     * The check of [config] that [realPingDetail] and [realPingConfig] make,
     * through [url], with what it found put in [out]. [tcp] is the plain TCP
     * connection opened beside it, or null.
     *
     * The checks run in the caller's scope, and this returns at the wait
     * without waiting for a core call that is still blocked, as the check
     * did before it was shared. The wait of [timeoutMs] starts here, or ends
     * at [deadline] (on SystemClock.elapsedRealtime) when the caller gives
     * one.
     *
     * With [refusable], a config the core never started (the backend's
     * outbound for a door, DoorOutbounds.notStarted) leaves [out] as it was
     * and returns false, so the caller can check the door's link. Otherwise
     * this returns true.
     */
    private suspend fun CoroutineScope.checkInto(
        out: MutableMap<String, Any?>,
        config: String,
        tcp: Deferred<Pair<String, Long>>?,
        timeoutMs: Long,
        timed: Boolean,
        url: String,
        deadline: Long? = null,
        refusable: Boolean = false,
    ): Boolean {
        // What is left of the wait.
        fun left(): Long = if (deadline == null) timeoutMs else deadline - SystemClock.elapsedRealtime()
        // The timed check ends itself at the wait, so this waits a little
        // longer for its answer, which then says how far it got. The plain
        // check is waited for as realPing does. Started outside the timeout,
        // as the plain check is: a blocking core call ignores cancellation,
        // so a timeout around its start would wait for it to the end. Its
        // wait starts here too, so time spent queued counts against it as it
        // does against the plain check.
        var started = true
        val timedCheck = if (timed && DoorChecks.timed) {
            val ends = deadline ?: (SystemClock.elapsedRealtime() + timeoutMs)
            async(Dispatchers.IO) {
                DoorChecks.check(config, url, timeoutMs, ends)
                    ?: TIMED_CHECK_NOT_RUN
            }
        } else {
            null
        }
        val reading = timedCheck?.let { check ->
            val json = withTimeoutOrNull(left() + TIMED_CHECK_GRACE_MS) { check.await() }
            when {
                // No answer in time: closed, as the plain check would read it.
                json == null -> DoorChecks.noAnswer(timeoutMs)
                // It could not run: the plain check runs instead.
                json == TIMED_CHECK_NOT_RUN -> null
                else -> {
                    if (refusable && DoorOutbounds.notStartedTimed(json)) started = false
                    DoorChecks.readingOf(json) ?: DoorChecks.noAnswer(timeoutMs)
                }
            }
        }
        val (delay, error) = if (reading != null) {
            (reading["ms"] as? Long ?: -1L) to (reading["error"] as? String)
        } else {
            val probe = async(Dispatchers.IO) {
                SpeedtestManager.realPingWithError(config, url)
            }
            val answer = withTimeoutOrNull(left()) { probe.await() }
                ?: (-1L to "no answer in $timeoutMs ms")
            if (refusable && answer.first < 0 && DoorOutbounds.notStarted(answer.second)) started = false
            answer
        }
        if (!started) return false
        reading?.let { out.putAll(it) }
        out["ms"] = delay
        if (delay < 0) {
            out["error"] = DoorCheck.shorten(error)
            tcp?.await()?.let { (outcome, ms) ->
                out["tcp"] = outcome
                out["tcpMs"] = ms
            }
        } else if (tcp != null && tcp.isCompleted) {
            // On an open door, the plain connection's time too, when it is
            // already in. It started with the check and needs one round trip
            // to the check's several, so it nearly always is. It is not
            // waited for, so an open door is never reported later for it.
            tcp.await().let { (outcome, ms) ->
                out["tcp"] = outcome
                out["tcpMs"] = ms
            }
        }
        return true
    }

    /** [NetworkKey.keysOf] for the active network, as a map, or null. */
    private fun networkKey(saltHex: String?, period: Number?): Map<String, Any?>? {
        val salt = saltHex?.takeIf { it.length >= 32 && it.length % 2 == 0 }
            ?.chunked(2)?.mapNotNull { it.toIntOrNull(16)?.toByte() }?.toByteArray()
            ?: return null
        if (salt.size * 2 != saltHex.length) return null
        return try {
            val cm = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
            val keys = NetworkKey.keysOf(
                cm,
                salt,
                period?.toLong() ?: 0L,
                System.currentTimeMillis() / 1000,
            ) ?: return null
            mapOf("local" to keys.local, "shared" to keys.shared)
        } catch (e: Exception) {
            Log.w(TAG, "networkKey failed", e)
            null
        }
    }

    /**
     * Where the phone is, as the phone knows it rather than as its address
     * says. The backend decides the device's country from these before the
     * address, because the address belongs to another VPN whenever one is on.
     *
     * - network_country: the cell network the phone is registered on. No VPN
     *   changes it, and it is there on Wi-Fi too while the SIM has signal.
     * - sim_country and roaming: the SIM's home, and whether that is not
     *   where the phone is.
     * - time_zone: the IANA id, such as Asia/Tehran.
     * - other_vpn: whether a VPN carries this app's own requests. This app is
     *   always left out of its own tunnel (configurePerAppProxy), and Android
     *   runs one VPN at a time, so a VPN on this app's network is never ours.
     *
     * None of these needs a permission. Country codes and a zone id only;
     * nothing finer than a country is read.
     */
    private fun placeFacts(): Map<String, Any?> {
        val out = HashMap<String, Any?>()
        try {
            val tm = getSystemService(Context.TELEPHONY_SERVICE) as TelephonyManager
            out["network_country"] = tm.networkCountryIso?.takeIf { it.isNotBlank() }
            out["sim_country"] = tm.simCountryIso?.takeIf { it.isNotBlank() }
            out["roaming"] = tm.isNetworkRoaming
        } catch (_: Exception) {}
        out["time_zone"] = java.util.TimeZone.getDefault().id
        try {
            val cm = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
            val caps = cm.activeNetwork?.let { cm.getNetworkCapabilities(it) }
            out["other_vpn"] = caps?.hasTransport(NetworkCapabilities.TRANSPORT_VPN)
        } catch (_: Exception) {}
        return out
    }

    /**
     * Whether this is a TV, where a remote is all the user holds. Android TV
     * and Google TV say so through the UI mode and the leanback feature. Many
     * boxes sold in Iran run plain Android and say neither, but they have no
     * touchscreen either. A ChromeOS laptop has none and is not a TV.
     */
    private fun isTelevision(): Boolean {
        return try {
            val ui = getSystemService(Context.UI_MODE_SERVICE) as? UiModeManager
            if (ui?.currentModeType == Configuration.UI_MODE_TYPE_TELEVISION) return true
            val pm = packageManager
            if (pm.hasSystemFeature(PackageManager.FEATURE_LEANBACK)) return true
            if (pm.hasSystemFeature("android.hardware.type.pc")) return false
            !pm.hasSystemFeature(PackageManager.FEATURE_TOUCHSCREEN)
        } catch (_: Exception) {
            false
        }
    }

    /**
     * Whether this is one of Google's test devices. Google Play runs every
     * uploaded build on them for its pre-launch report (Firebase Test Lab),
     * and Test Lab sets this system setting to "true" on each one, as
     * Google's Test Lab docs describe. Any failure is false, because a real
     * phone must never be marked as a test device.
     */
    private fun isTestLab(): Boolean {
        return try {
            Settings.System.getString(contentResolver, "firebase.test.lab") == "true"
        } catch (_: Exception) {
            false
        }
    }

    /**
     * The SHA-256 of each certificate this copy is signed with now, in
     * lower-case hex. The Dart side offers Google Play Billing only when one
     * of them is Google Play's app signing certificate, because Play sells
     * only in the copy it signed (PlaySignature). Certificates the app
     * rotated away from are left out. Any failure is an empty list, which
     * reads as "not Google's".
     */
    private fun signingCertificates(): List<String> {
        return try {
            val signatures: Array<Signature>? =
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                    packageManager
                        .getPackageInfo(packageName, PackageManager.GET_SIGNING_CERTIFICATES)
                        .signingInfo
                        ?.apkContentsSigners
                } else {
                    @Suppress("DEPRECATION")
                    packageManager
                        .getPackageInfo(packageName, PackageManager.GET_SIGNATURES)
                        .signatures
                }
            signatures.orEmpty().map { signature ->
                MessageDigest.getInstance("SHA-256")
                    .digest(signature.toByteArray())
                    .joinToString("") { "%02x".format(it) }
            }
        } catch (e: Exception) {
            Log.w(TAG, "Could not read the signing certificates: ${e.message}")
            emptyList()
        }
    }

    /// Check if VPN is actually active
    /**
     * The platform's side of a failure report: carrier, network, what the
     * user's power and data settings are doing to us, and the tail of the
     * core's own log. Every field is best effort; a missing one is null.
     */
    private fun collectDiagnostics(): Map<String, Any?> {
        val out = HashMap<String, Any?>()
        out.putAll(networkFacts())
        try {
            val tm = getSystemService(Context.TELEPHONY_SERVICE) as TelephonyManager
            out["sim_carrier"] = tm.simOperatorName?.takeIf { it.isNotBlank() }
            out["sim_country"] = tm.simCountryIso?.takeIf { it.isNotBlank() }
            out["roaming"] = tm.isNetworkRoaming
        } catch (_: Exception) {}
        try {
            val cm = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
            val caps = cm.activeNetwork?.let { cm.getNetworkCapabilities(it) }
            out["through_vpn"] = caps?.hasTransport(NetworkCapabilities.TRANSPORT_VPN) ?: false
            out["validated"] = caps?.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED) ?: false
            out["data_saver"] =
                cm.restrictBackgroundStatus == ConnectivityManager.RESTRICT_BACKGROUND_STATUS_ENABLED
            out["down_kbps"] = caps?.linkDownstreamBandwidthKbps
        } catch (_: Exception) {}
        // From the app op, not prepare(). This report is made with no tap, on
        // every network change and while the app is off, and prepare() took
        // the VPN slot from any other app that had it (VpnSlot).
        VpnSlot.consentOnRecord(this)?.let { out["vpn_permission"] = it }
        try {
            val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
            out["power_save"] = pm.isPowerSaveMode
            out["battery_optimized"] = !pm.isIgnoringBatteryOptimizations(packageName)
        } catch (_: Exception) {}
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                val am = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
                out["background_restricted"] = am.isBackgroundRestricted
            }
        } catch (_: Exception) {}
        try {
            // The resolver the core is actually running with, read through
            // the same call the config builder uses, so this reports the
            // default when nothing is configured rather than reporting
            // nothing. DNS-level interference looks like a transport block
            // in a report that does not name the resolver.
            out["resolver"] = SettingsManager.getRemoteDnsServers().joinToString(",")
        } catch (_: Exception) {}
        // Null when off or automatic. A name here means the phone asks that
        // provider instead of the tunnel's resolver.
        out["private_dns"] = privateDnsHost()
        out["device"] = "${Build.MANUFACTURER} ${Build.MODEL}".trim()
        out["sdk_int"] = Build.VERSION.SDK_INT
        out["core_log"] = coreLogTail()
        return out
    }

    /**
     * The last lines the Xray core and this app wrote to logcat. An app may
     * read its own UID's log lines without READ_LOGS, and the daemon process
     * shares our UID, so the core's "GoLog" lines are ours to read.
     *
     * Every line that names a site or an address is left out before the
     * tail is returned, because the tail is sent with connection reports.
     * See LogPrivacy. The lines are left out before the tail is cut to
     * [maxChars], so a cut never leaves half of such a line behind.
     */
    private fun coreLogTail(maxChars: Int = 6000): String? {
        return try {
            val process = Runtime.getRuntime().exec(
                arrayOf("logcat", "-d", "-t", "150", "-v", "time", "-s", "GoLog:*", "${AppConfig.TAG}:*", "$TAG:*")
            )
            val text = process.inputStream.bufferedReader().use { it.readText() }
            process.waitFor()
            if (text.isBlank()) null else LogPrivacy.scrub(text).takeLast(maxChars)
        } catch (_: Exception) {
            null
        }
    }

    /**
     * Whether the phone's network can reach an IPv6 address: true when it
     * has a global IPv6 address and an IPv6 default route, false when it
     * lacks either, null when there is no network to read.
     *
     * Read from the network's LinkProperties, so nothing is sent. Without an
     * IPv6 route a connection to an IPv6 address fails at once with
     * ENETUNREACH, which the door checks report as "tcp unreachable". That
     * is what the IPv6 doors do on a home line with no IPv6. The app leaves
     * those doors out of the standby group then (StandbyDoors.pick).
     *
     * This app is left out of its own tunnel, so its default network is the
     * one under the tunnel. A VPN here is another app's, which our tunnel
     * replaces when it starts, so its routes do not count.
     */
    private fun ipv6Route(): Boolean? {
        return try {
            val cm = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
            val network = cm.activeNetwork ?: return null
            val caps = cm.getNetworkCapabilities(network) ?: return null
            if (caps.hasTransport(NetworkCapabilities.TRANSPORT_VPN)) return null
            val props = cm.getLinkProperties(network) ?: return null
            // 2000::/3. Link-local and unique local addresses do not reach
            // the internet.
            val address = props.linkAddresses.any { link ->
                val a = link.address
                a is Inet6Address && (a.address[0].toInt() and 0xE0) == 0x20
            }
            val route = props.routes.any { it.isDefaultRoute && it.destination.address is Inet6Address }
            address && route
        } catch (e: Exception) {
            Log.w(TAG, "ipv6Route: ${e.message}")
            null
        }
    }

    /**
     * What the network this app's own sockets use says about itself:
     * `link_mtu` (Android 10 and up), `private_dns` (Android 9 and up) and
     * `transport`. See LinkFacts for the values.
     *
     * This app is left out of its own tunnel, so its default network is the
     * one under the tunnel. A VPN here is another app's, and its MTU and DNS
     * describe that tunnel rather than the line, so nothing is read then.
     * Read from the network's own LinkProperties, so nothing is sent.
     */
    private fun linkFacts(): Map<String, Any?> {
        val out = HashMap<String, Any?>()
        try {
            val cm = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
            val network = cm.activeNetwork ?: return out
            val caps = cm.getNetworkCapabilities(network) ?: return out
            if (caps.hasTransport(NetworkCapabilities.TRANSPORT_VPN)) return out
            out["transport"] = LinkFacts.transport(
                wifi = caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI),
                cellular = caps.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR),
                ethernet = caps.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET),
            )
            val props = cm.getLinkProperties(network) ?: return out
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                out["link_mtu"] = LinkFacts.mtu(props.mtu)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                out["private_dns"] = LinkFacts.privateDnsMode(
                    props.isPrivateDnsActive,
                    props.privateDnsServerName,
                )
            }
        } catch (e: Exception) {
            Log.w(TAG, "linkFacts: ${e.message}")
        }
        return out
    }

    private fun isVpnActive(): Boolean = AppEngine.vpnActive(this)
}