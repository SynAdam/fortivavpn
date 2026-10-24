package com.vpn.fortivavpn.handler

import android.content.Context
import android.text.TextUtils
import android.util.Log
import com.google.gson.JsonObject
import com.vpn.fortivavpn.AppConfig
import com.vpn.fortivavpn.R
import com.vpn.fortivavpn.dto.ConfigResult
import com.vpn.fortivavpn.dto.EConfigType
import com.vpn.fortivavpn.dto.NetworkType
import com.vpn.fortivavpn.dto.ProfileItem
import com.vpn.fortivavpn.dto.RulesetItem
import com.vpn.fortivavpn.dto.V2rayConfig
import com.vpn.fortivavpn.dto.V2rayConfig.OutboundBean
import com.vpn.fortivavpn.dto.V2rayConfig.OutboundBean.OutSettingsBean
import com.vpn.fortivavpn.dto.V2rayConfig.OutboundBean.StreamSettingsBean
import com.vpn.fortivavpn.dto.V2rayConfig.RoutingBean.RulesBean
import com.vpn.fortivavpn.extension.isNotNullEmpty
import com.vpn.fortivavpn.fmt.HttpFmt
import com.vpn.fortivavpn.fmt.ShadowsocksFmt
import com.vpn.fortivavpn.fmt.SocksFmt
import com.vpn.fortivavpn.fmt.TrojanFmt
import com.vpn.fortivavpn.fmt.VlessFmt
import com.vpn.fortivavpn.fmt.VmessFmt
import com.vpn.fortivavpn.fmt.WireguardFmt
import com.vpn.fortivavpn.service.PsiphonSession
import com.vpn.fortivavpn.util.HttpUtil
import com.vpn.fortivavpn.util.JsonUtil
import com.vpn.fortivavpn.util.Utils

object V2rayConfigManager {
    private var initConfigCache: String? = null

    //region get config function

    /**
     * Retrieves the V2ray configuration for the given GUID.
     *
     * @param context The context of the caller.
     * @param guid The unique identifier for the V2ray configuration.
     * @param doorOutbounds Whether the door is dialled with the backend's
     *   outbound when the last connect gave it one (DoorOutbounds). False
     *   builds it from its link alone.
     * @return A ConfigResult object containing the configuration details or indicating failure.
     */
    fun getV2rayConfig(context: Context, guid: String, doorOutbounds: Boolean = true): ConfigResult {
        try {
            val config = MmkvManager.decodeServerConfig(guid) ?: return ConfigResult(false)
            return if (config.configType == EConfigType.CUSTOM) {
                getV2rayCustomConfig(guid, config)
            } else {
                getV2rayNormalConfig(context, guid, config, if (doorOutbounds) DoorOutbounds.forGuid(guid) else null)
            }
        } catch (e: Exception) {
            Log.e(AppConfig.TAG, "Failed to get V2ray config", e)
            return ConfigResult(false)
        }
    }

    /**
     * Generates a V2ray configuration from multiple server profiles.
     *
     * @param context The context of the caller.
     * @param guidList A list of server GUIDs to be included in the generated configuration.
     *                 Each GUID represents a unique server profile stored in the system.
     * @return A V2rayConfig object containing the combined configuration of all specified servers,
     *         or null if the operation fails (e.g., no valid configurations found, parsing errors)
     */
    fun genV2rayConfig(context: Context, guidList: List<String>): V2rayConfig? {
        try {
            val configList = guidList.mapNotNull { guid ->
                MmkvManager.decodeServerConfig(guid)
            }
            return genV2rayMultipleConfig(context, configList)
        } catch (e: Exception) {
            Log.e(AppConfig.TAG, "Failed to generate V2ray config", e)
            return null
        }
    }

    /**
     * Retrieves the speedtest V2ray configuration for the given GUID.
     *
     * @param context The context of the caller.
     * @param guid The unique identifier for the V2ray configuration.
     * @return A ConfigResult object containing the configuration details or indicating failure.
     */
    fun getV2rayConfig4Speedtest(context: Context, guid: String): ConfigResult {
        try {
            val config = MmkvManager.decodeServerConfig(guid) ?: return ConfigResult(false)
            return if (config.configType == EConfigType.CUSTOM) {
                getV2rayCustomConfig(guid, config)
            } else {
                getV2rayNormalConfig4Speedtest(context, guid, config)
            }
        } catch (e: Exception) {
            Log.e(AppConfig.TAG, "Failed to get V2ray config for speedtest", e)
            return ConfigResult(false)
        }
    }

    /**
     * Retrieves the custom V2ray configuration.
     *
     * @param guid The unique identifier for the V2ray configuration.
     * @param config The profile item containing the configuration details.
     * @return A ConfigResult object containing the result of the configuration retrieval.
     */
    private fun getV2rayCustomConfig(guid: String, config: ProfileItem): ConfigResult {
        val raw = MmkvManager.decodeServerRaw(guid) ?: return ConfigResult(false)
        return ConfigResult(true, guid, raw)
    }

    /**
     * Retrieves the normal V2ray configuration.
     *
     * @param context The context in which the function is called.
     * @param guid The unique identifier for the V2ray configuration.
     * @param config The profile item containing the configuration details.
     * @param door The backend's outbound for this door, or null to build it
     *   from its link (DoorOutbounds).
     * @return A ConfigResult object containing the result of the configuration retrieval.
     */
    private fun getV2rayNormalConfig(
        context: Context,
        guid: String,
        config: ProfileItem,
        door: DoorOutbound? = null,
    ): ConfigResult {
        val result = ConfigResult(false)
        // Not with the global split setting on, which rewrites the first
        // outbound itself.
        val backend = door?.takeIf { MmkvManager.decodeSettingsBool(AppConfig.PREF_FRAGMENT_ENABLED, false) != true }
        val swaps = mutableMapOf<String, JsonObject>()

        val address = config.server ?: return result
        if (!Utils.isPureIpAddress(address)) {
            if (!Utils.isValidUrl(address)) {
                Log.w(AppConfig.TAG, "$address is an invalid ip or domain")
                return result
            }
        }

        val v2rayConfig = initV2rayConfig(context) ?: return result
        v2rayConfig.log.loglevel = MmkvManager.decodeSettingsString(AppConfig.PREF_LOGLEVEL) ?: "debug"
        v2rayConfig.remarks = config.remarks
        enableSiteStatsLog(v2rayConfig)

        getInbounds(v2rayConfig)

        if (config.configType == EConfigType.HYSTERIA2) {
            result.socksPort = getPlusOutbounds(v2rayConfig, config) ?: return result
        } else {
            getOutbounds(v2rayConfig, config, backend, swaps) ?: return result
            getMoreOutbounds(v2rayConfig, config.subscriptionId)
        }

        getRouting(v2rayConfig)

        getFakeDns(v2rayConfig)

        getDns(v2rayConfig)

        if (MmkvManager.decodeSettingsBool(AppConfig.PREF_LOCAL_DNS_ENABLED) == true) {
            getCustomLocalDns(v2rayConfig)
        }
        // The backup network's proxy takes TCP only. Must come after every
        // other DNS rule, because its rule has to be the first one.
        if (PsiphonSession.active()?.guid == guid) {
            psiphonDns(v2rayConfig)
        }
        enableOutboundCounters(v2rayConfig)

        //Resolve and add to DNS Hosts
        if (MmkvManager.decodeSettingsString(AppConfig.PREF_OUTBOUND_DOMAIN_RESOLVE_METHOD, "1") == "1") {
            resolveOutboundDomainsToHosts(v2rayConfig)
        }

        stripGeoAssetRules(context, v2rayConfig)

        result.status = true
        result.content = JsonUtil.toJsonPretty(v2rayConfig) ?: ""
        result.guid = guid
        return DoorOutbounds.finish(result, swaps) { getV2rayNormalConfig(context, guid, config) }
    }

    /** The tag of the outbound that answers DNS queries from the core's own resolver. */
    const val TAG_DNS_OUT = "dns-out"

    /**
     * DNS for a backup network session (PsiphonSession), whose SOCKS proxy
     * accepts CONNECT only. Every UDP flow sent to `proxy` fails there,
     * plain DNS to 1.1.1.1:53 included, and the phone then resolves no name
     * at all. So:
     * - a first rule sends UDP to port 53 to the `dns-out` outbound, which
     *   answers A and AAAA queries from the core's own resolver and gives
     *   other types an empty answer;
     * - every resolver given as a bare address is asked over TCP instead
     *   (`tcp://1.1.1.1`). The rule that sends port 53 at that address to
     *   `proxy` then carries the core's own queries through the proxy.
     *
     * The Iran-direct rules, the UDP/443 block, sniffing and the counters
     * are left as they are. Other UDP is lost through this proxy, and that
     * is accepted.
     */
    fun psiphonDns(v2rayConfig: V2rayConfig) {
        v2rayConfig.dns?.servers?.let { servers ->
            for (i in servers.indices) {
                when (val server = servers[i]) {
                    is String -> servers[i] = tcpResolver(server)
                    is V2rayConfig.DnsBean.ServersBean -> server.address = tcpResolver(server.address)
                }
            }
        }
        if (v2rayConfig.outbounds.none { it.protocol == "dns" && it.tag == TAG_DNS_OUT }) {
            v2rayConfig.outbounds.add(
                OutboundBean(
                    protocol = "dns",
                    tag = TAG_DNS_OUT,
                    settings = null,
                    streamSettings = null,
                    mux = null,
                ),
            )
        }
        v2rayConfig.routing.rules.add(
            0,
            RulesBean(
                network = "udp",
                port = "53",
                outboundTag = TAG_DNS_OUT,
            ),
        )
    }

    /**
     * `tcp://<address>` for a bare IP address, with an IPv6 address in
     * brackets, and [address] unchanged otherwise (a DoH URL, `tcp://...`,
     * `localhost`).
     */
    fun tcpResolver(address: String): String {
        if (!Utils.isPureIpAddress(address)) return address
        if (!address.contains(':')) return "tcp://$address"
        return "tcp://[${address.removePrefix("[").removeSuffix("]")}]"
    }

    /**
     * How long the group keeps a working door before it moves new
     * connections to one that measured faster. A door the core finds
     * failing (two hard failures in 30 seconds, or dead) is not held by it:
     * a dead one is left at once, and a failing one as soon as another door
     * is calmer (android/core/patches/xray-failover-calm.patch). So is the
     * first pick in the 20 seconds after start.
     *
     * The core's default is a minute. On Iranian mobile networks the
     * Cloudflare door and the direct door take turns being faster, and on
     * 2026-10-02 phones moved between them every few minutes. The two can
     * be different servers, so each move changed the user's exit address.
     */
    private const val AUTOSELECT_MIN_DWELL = "10m"

    /** The tag of the door at [index] in a config that holds several. */
    fun autoSelectMemberTag(index: Int): String = "${AppConfig.TAG_PROXY}@$index"

    /** The index in [tag], or null when it is not a door's tag. */
    fun autoSelectMemberIndex(tag: String?): Int? =
        tag?.removePrefix("${AppConfig.TAG_PROXY}@")?.takeIf { it != tag }?.toIntOrNull()

    /**
     * The group's penalties setting: for each door in [tags] that has one,
     * the penalty at the door's position in [penalties], under its tag. A
     * penalty of 0 or less is none, and with none at all the setting is
     * left out (null).
     */
    fun autoSelectPenalties(tags: List<String>, penalties: List<Int>): Map<String, Int>? =
        tags.mapNotNull { tag ->
            val ms = autoSelectMemberIndex(tag)?.let { penalties.getOrNull(it) } ?: 0
            if (ms > 0) tag to ms else null
        }.toMap().ifEmpty { null }

    /**
     * A config that holds every door in [guids] at once.
     *
     * The first guid is the door the app chose, and the core starts on it.
     * The rest stand by. The autoselect outbound (android/core/patches) moves
     * a failed connection to the next door and sends new ones through
     * whichever door is healthy, so a door that gets blocked in the middle of
     * a session does not end the tunnel.
     *
     * The group takes the tag every routing rule already points at, so
     * nothing else in the config knows there is more than one door. A door's
     * own tag carries its position in [guids], which is how the app is told
     * which one is in use. A blank or unusable guid is skipped and keeps its
     * position.
     *
     * [exits] names the server each door sends traffic out from, by its
     * position in [guids]. A failover in the core prefers a door with the
     * exit of the one it leaves, so the address the user's traffic leaves
     * from only changes when it has to. A blank exit is no exit.
     *
     * [penalties] is the backend's penalty for each door in milliseconds, by
     * its position in [guids]. The core adds it to the door's score
     * (android/core/patches/xray-stability-penalty.patch), so a door that
     * answers its probes fast and then fails in the middle of sessions
     * stops winning on its probes alone. See [autoSelectPenalties].
     *
     * A door the last connect gave the backend's outbound is dialled with
     * it, unless [doorOutbounds] is false (DoorOutbounds).
     *
     * Returns a failed result when it cannot build a group of at least two
     * doors that starts with the first guid. The caller then connects through
     * that one door as before.
     */
    fun getV2rayAutoSelectConfig(
        context: Context,
        guids: List<String>,
        exits: List<String> = emptyList(),
        penalties: List<Int> = emptyList(),
        doorOutbounds: Boolean = true,
    ): ConfigResult {
        val result = ConfigResult(false)
        try {
            // The global fragment setting rewrites the first outbound, which
            // here is the group. A link's own fragment still applies.
            if (MmkvManager.decodeSettingsBool(AppConfig.PREF_FRAGMENT_ENABLED, false) == true) {
                return result
            }

            val doors = mutableListOf<OutboundBean>()
            val extras = mutableListOf<OutboundBean>()
            val stored = if (doorOutbounds) MmkvManager.decodeSettingsString(AppConfig.PREF_DOOR_OUTBOUNDS) else null
            val swaps = mutableMapOf<String, JsonObject>()
            guids.forEachIndexed { index, guid ->
                val profile = MmkvManager.decodeServerConfig(guid) ?: return@forEachIndexed
                if (profile.configType == EConfigType.CUSTOM || profile.configType == EConfigType.HYSTERIA2) {
                    return@forEachIndexed
                }
                val address = profile.server ?: return@forEachIndexed
                if (!Utils.isPureIpAddress(address) && !Utils.isValidUrl(address)) return@forEachIndexed
                val outbound = convertProfile2Outbound(profile) ?: return@forEachIndexed
                if (!updateOutboundWithGlobalSettings(outbound)) return@forEachIndexed
                outbound.tag = autoSelectMemberTag(index)
                val door = DoorOutbounds.of(stored, guid)
                if (door != null) {
                    // The backend's outbound stands in for this one, and its
                    // helpers for the split the link asks for.
                    DoorOutbounds.stage(door, outbound.tag, extras, swaps)
                } else if (outbound.streamSettings?.finalmask == null) {
                    TlsFragment.parse(profile.fragment)?.let { TlsFragment.applyTo(outbound, extras, it) }
                }
                doors.add(outbound)
            }
            if (doors.size < 2 || doors.first().tag != autoSelectMemberTag(0)) return result

            val first = MmkvManager.decodeServerConfig(guids.first()) ?: return result
            val v2rayConfig = initV2rayConfig(context) ?: return result
            v2rayConfig.log.loglevel = MmkvManager.decodeSettingsString(AppConfig.PREF_LOGLEVEL) ?: "debug"
            v2rayConfig.remarks = first.remarks

            getInbounds(v2rayConfig)

            val group = OutboundBean(
                tag = AppConfig.TAG_PROXY,
                protocol = AppConfig.PROTOCOL_AUTOSELECT,
                mux = null,
            )
            group.settings = OutboundBean.OutSettingsBean(
                outbounds = doors.map { it.tag },
                probeURL = SettingsManager.getDelayTestUrl(),
                fallbackProbeURL = SettingsManager.getDelayTestUrl(true),
                initial = doors.first().tag,
                minDwell = AUTOSELECT_MIN_DWELL,
                exits = doors.mapNotNull { door ->
                    val exit = autoSelectMemberIndex(door.tag)?.let { exits.getOrNull(it) }
                    if (exit.isNullOrBlank()) null else door.tag to exit
                }.toMap().ifEmpty { null },
                penalties = autoSelectPenalties(doors.map { it.tag }, penalties),
            )
            // The template's first outbound is the placeholder for the one
            // proxy; the group and its doors take its place.
            val others = v2rayConfig.outbounds.drop(1)
            v2rayConfig.outbounds = ArrayList(listOf(group) + doors + extras + others)

            getRouting(v2rayConfig)

            getFakeDns(v2rayConfig)

            getDns(v2rayConfig)

            if (MmkvManager.decodeSettingsBool(AppConfig.PREF_LOCAL_DNS_ENABLED) == true) {
                getCustomLocalDns(v2rayConfig)
            }
            enableOutboundCounters(v2rayConfig)

            //Resolve and add to DNS Hosts
            if (MmkvManager.decodeSettingsString(AppConfig.PREF_OUTBOUND_DOMAIN_RESOLVE_METHOD, "1") == "1") {
                resolveOutboundDomainsToHosts(v2rayConfig)
            }

            stripGeoAssetRules(context, v2rayConfig)

            result.status = true
            result.content = JsonUtil.toJsonPretty(v2rayConfig) ?: ""
            result.guid = guids.first()
            return DoorOutbounds.finish(result, swaps) {
                getV2rayAutoSelectConfig(context, guids, exits, penalties, doorOutbounds = false)
            }
        } catch (e: Exception) {
            Log.e(AppConfig.TAG, "Failed to build a config that holds several doors", e)
            return ConfigResult(false)
        }
    }

    private fun genV2rayMultipleConfig(context: Context, configList: List<ProfileItem>): V2rayConfig? {
        val validConfigs = configList.asSequence().filter { it.server.isNotNullEmpty() }
            .filter { !Utils.isPureIpAddress(it.server!!) || Utils.isValidUrl(it.server!!) }
            .filter { it.configType != EConfigType.CUSTOM }
            .filter { it.configType != EConfigType.HYSTERIA2 }
            .filter { config ->
                if (config.subscriptionId.isEmpty()) {
                    return@filter true
                }
                val subItem = MmkvManager.decodeSubscription(config.subscriptionId)
                if (subItem?.intelligentSelectionFilter.isNullOrEmpty() || config.remarks.isEmpty()) {
                    return@filter true
                }
                Regex(pattern = subItem?.intelligentSelectionFilter!!).containsMatchIn(input = config.remarks)
            }.toList()

        if (validConfigs.isEmpty()) {
            Log.w(AppConfig.TAG, "All configs are invalid")
            return null
        }

        val v2rayConfig = initV2rayConfig(context) ?: return null
        v2rayConfig.log.loglevel = MmkvManager.decodeSettingsString(AppConfig.PREF_LOGLEVEL) ?: "warning"
        enableSiteStatsLog(v2rayConfig)

        val subIds = configList.map { it.subscriptionId }.toHashSet()
        val remarks = if (subIds.size == 1 && subIds.first().isNotEmpty()) {
            val sub = MmkvManager.decodeSubscription(subIds.first())
            (sub?.remarks ?: "") + context.getString(R.string.intelligent_selection)
        } else {
            context.getString(R.string.intelligent_selection)
        }

        v2rayConfig.remarks = remarks

        getInbounds(v2rayConfig)

        v2rayConfig.outbounds.removeAt(0)
        val outboundsList = mutableListOf<V2rayConfig.OutboundBean>()
        var index = 0
        for (config in validConfigs) {
            index++
            val outbound = convertProfile2Outbound(config) ?: continue
            val ret = updateOutboundWithGlobalSettings(outbound)
            if (!ret) continue
            outbound.tag = "proxy-$index"
            outboundsList.add(outbound)
        }
        outboundsList.addAll(v2rayConfig.outbounds)
        v2rayConfig.outbounds = ArrayList(outboundsList)

        getRouting(v2rayConfig)

        getFakeDns(v2rayConfig)

        getDns(v2rayConfig)

        getBalance(v2rayConfig)

        if (MmkvManager.decodeSettingsBool(AppConfig.PREF_LOCAL_DNS_ENABLED) == true) {
            getCustomLocalDns(v2rayConfig)
        }
        enableOutboundCounters(v2rayConfig)

        //Resolve and add to DNS Hosts
        if (MmkvManager.decodeSettingsString(AppConfig.PREF_OUTBOUND_DOMAIN_RESOLVE_METHOD, "1") == "1") {
            resolveOutboundDomainsToHosts(v2rayConfig)
        }

        return v2rayConfig
    }

    /**
     * Retrieves the normal V2ray configuration for speedtest.
     *
     * @param context The context in which the function is called.
     * @param guid The unique identifier for the V2ray configuration.
     * @param config The profile item containing the configuration details.
     * @return A ConfigResult object containing the result of the configuration retrieval.
     */
    private fun getV2rayNormalConfig4Speedtest(context: Context, guid: String, config: ProfileItem): ConfigResult {
        val result = ConfigResult(false)

        val address = config.server ?: return result
        if (!Utils.isPureIpAddress(address)) {
            if (!Utils.isValidUrl(address)) {
                Log.w(AppConfig.TAG, "$address is an invalid ip or domain")
                return result
            }
        }

        val v2rayConfig = initV2rayConfig(context) ?: return result

        if (config.configType == EConfigType.HYSTERIA2) {
            result.socksPort = getPlusOutbounds(v2rayConfig, config) ?: return result
        } else {
            getOutbounds(v2rayConfig, config) ?: return result
            getMoreOutbounds(v2rayConfig, config.subscriptionId)
        }

        v2rayConfig.log.loglevel = MmkvManager.decodeSettingsString(AppConfig.PREF_LOGLEVEL) ?: "warning"
        v2rayConfig.inbounds.clear()
        v2rayConfig.routing.rules.clear()
        v2rayConfig.dns = null
        v2rayConfig.fakedns = null
        v2rayConfig.stats = null
        v2rayConfig.policy = null

        v2rayConfig.outbounds.forEach { key ->
            key.mux = null
        }

        stripGeoAssetRules(context, v2rayConfig)

        result.status = true
        result.content = JsonUtil.toJsonPretty(v2rayConfig) ?: ""
        result.guid = guid
        return result
    }

    /**
     * Keeps the core's outbound byte counters on, and nothing else.
     *
     * The session heartbeat reads them every five minutes to tell a tunnel
     * that is carrying traffic from one that is up and passing nothing; that
     * question cannot be answered from outside the tunnel, because the app is
     * excluded from it and its own requests never touch the proxy.
     *
     * The asset template ships these counters behind the speed-display
     * preference, together with a level 8 policy that the socks inbound does
     * use. Only the counters are wanted here, so the policy is replaced
     * rather than left as it came: two counters per outbound cost nothing,
     * and a change to the handshake and half-close timeouts is not something
     * to turn on as a side effect of telemetry.
     */
    private fun enableOutboundCounters(v2rayConfig: V2rayConfig) {
        v2rayConfig.stats = emptyMap<String, Any>()
        v2rayConfig.policy = V2rayConfig.PolicyBean(
            levels = emptyMap(),
            system = mapOf(
                "statsOutboundUplink" to true,
                "statsOutboundDownlink" to true,
            ),
        )
    }

    /**
     * Initializes V2ray configuration.
     *
     * This function loads the V2ray configuration from assets or from a cached value.
     * It first attempts to use the cached configuration if available, otherwise reads
     * the configuration from the "v2ray_config.json" asset file.
     *
     * @param context Android context used to access application assets
     * @return V2rayConfig object parsed from the JSON configuration, or null if the configuration is empty
     */
    private fun initV2rayConfig(context: Context): V2rayConfig? {
        val assets = initConfigCache ?: Utils.readTextFromAssets(context, "v2ray_config.json")
        if (TextUtils.isEmpty(assets)) {
            return null
        }
        initConfigCache = assets
        val config = JsonUtil.fromJson(assets, V2rayConfig::class.java)
        return config
    }


    //endregion


    //region some sub function

    /**
     * Configures the inbound settings for V2ray.
     *
     * This function sets up the listening ports, sniffing options, and other inbound-related configurations.
     *
     * @param v2rayConfig The V2ray configuration object to be modified
     * @return true if inbound configuration was successful, false otherwise
     */
    private fun getInbounds(v2rayConfig: V2rayConfig): Boolean {
        try {
            val socksPort = SettingsManager.getSocksPort()

            v2rayConfig.inbounds.forEach { curInbound ->
                if (MmkvManager.decodeSettingsBool(AppConfig.PREF_PROXY_SHARING) != true) {
                    //bind all inbounds to localhost if the user requests
                    curInbound.listen = AppConfig.LOOPBACK
                }
            }
            v2rayConfig.inbounds[0].port = socksPort
            val fakedns = MmkvManager.decodeSettingsBool(AppConfig.PREF_FAKE_DNS_ENABLED) == true
            val sniffAllTlsAndHttp =
                MmkvManager.decodeSettingsBool(AppConfig.PREF_SNIFFING_ENABLED, true) != false
            v2rayConfig.inbounds[0].sniffing?.enabled = fakedns || sniffAllTlsAndHttp
            v2rayConfig.inbounds[0].sniffing?.routeOnly =
                MmkvManager.decodeSettingsBool(AppConfig.PREF_ROUTE_ONLY_ENABLED, true)
            if (!sniffAllTlsAndHttp) {
                v2rayConfig.inbounds[0].sniffing?.destOverride?.clear()
            }
            if (fakedns) {
                v2rayConfig.inbounds[0].sniffing?.destOverride?.add("fakedns")
            }

            if (Utils.isXray()) {
                v2rayConfig.inbounds.removeAt(1)
            } else {
                val httpPort = SettingsManager.getHttpPort()
                v2rayConfig.inbounds[1].port = httpPort
            }

        } catch (e: Exception) {
            Log.e(AppConfig.TAG, "Failed to configure inbounds", e)
            return false
        }
        return true
    }

    /**
     * Always enable info-level logging so the core emits "sniffed domain:"
     * lines to logcat. libv2ray sends those to logcat (tag GoLog), and
     * SiteStats reads them for the aggregate Sites view. Sniffing is already
     * on for routing; this only raises the log level. The lines stay on the
     * phone: LogPrivacy leaves them out of the log sent with connection
     * reports.
     */
    private fun enableSiteStatsLog(v2rayConfig: V2rayConfig) {
        v2rayConfig.log.loglevel = "info"
    }

    /**
     * Configures the fake DNS settings if enabled.
     *
     * Adds FakeDNS configuration to v2rayConfig if both local DNS and fake DNS are enabled.
     *
     * @param v2rayConfig The V2ray configuration object to be modified
     */
    private fun getFakeDns(v2rayConfig: V2rayConfig) {
        if (MmkvManager.decodeSettingsBool(AppConfig.PREF_LOCAL_DNS_ENABLED) == true
            && MmkvManager.decodeSettingsBool(AppConfig.PREF_FAKE_DNS_ENABLED) == true
        ) {
            v2rayConfig.fakedns = listOf(V2rayConfig.FakednsBean())
        }
    }

    /**
     * Configures routing settings for V2ray.
     *
     * Sets up the domain strategy and adds routing rules from saved rulesets.
     *
     * @param v2rayConfig The V2ray configuration object to be modified
     * @return true if routing configuration was successful, false otherwise
     */
    private fun getRouting(v2rayConfig: V2rayConfig): Boolean {
        try {

            v2rayConfig.routing.domainStrategy =
                MmkvManager.decodeSettingsString(AppConfig.PREF_ROUTING_DOMAIN_STRATEGY)
                    ?: "AsIs"

            val rulesetItems = MmkvManager.decodeRoutingRulesets()
            rulesetItems?.forEach { key ->
                getRoutingUserRule(key, v2rayConfig)
            }
        } catch (e: Exception) {
            Log.e(AppConfig.TAG, "Failed to configure routing", e)
            return false
        }
        return true
    }

    // Fallback for when the geo databases are missing.
    //
    // Xray resolves geoip:/geosite: tokens out of geoip.dat and geosite.dat,
    // and one token it cannot resolve makes it reject the whole config, so
    // the tunnel never starts at all. SettingsManager.initAssets stages both
    // databases before the core is initialised, and when they are in place
    // the tokens are left alone for the core to resolve.
    //
    // If staging failed, these literals stand in for the private-network
    // token, which is the one geo rule that needs no database because those
    // ranges are fixed. Every other token is dropped, which costs the Iran
    // bypass preset but keeps the tunnel starting.
    private val PRIVATE_IP_RANGES = arrayListOf(
        "0.0.0.0/8", "10.0.0.0/8", "100.64.0.0/10", "127.0.0.0/8",
        "169.254.0.0/16", "172.16.0.0/12", "192.0.0.0/24", "192.168.0.0/16",
        "198.18.0.0/15", "224.0.0.0/4", "255.255.255.255/32",
        "::1/128", "fc00::/7", "fe80::/10",
    )
    private val PRIVATE_DOMAINS = arrayListOf("full:localhost", "domain:local", "domain:localdomain")

    /**
     * Removes every rule the core would need a geo database to understand,
     * but only when the databases are actually missing.
     *
     * @param v2rayConfig The configuration to sanitize in place, immediately
     * before it is serialized for the core.
     */
    private fun stripGeoAssetRules(context: Context, v2rayConfig: V2rayConfig) {
        if (SettingsManager.geoAssetsAvailable(context)) {
            // The core can resolve every token itself. Leaving them intact is
            // the whole point of shipping the databases: geoip:ir and
            // geosite:category-ir are what keep Iranian traffic off the
            // tunnel and out of the user's daily allowance.
            return
        }
        Log.w(AppConfig.TAG, "geo databases unavailable, stripping geo routing rules")

        val kept = ArrayList<V2rayConfig.RoutingBean.RulesBean>(v2rayConfig.routing.rules.size)
        for (rule in v2rayConfig.routing.rules) {
            val wasConstrained = !rule.ip.isNullOrEmpty() || !rule.domain.isNullOrEmpty()
            rule.ip = rule.ip
                ?.let { resolveGeoTokens(it, AppConfig.GEOIP_PRIVATE, PRIVATE_IP_RANGES, "geoip:") }
                ?.takeIf { it.isNotEmpty() }
            rule.domain = rule.domain
                ?.let { resolveGeoTokens(it, AppConfig.GEOSITE_PRIVATE, PRIVATE_DOMAINS, "geosite:") }
                ?.takeIf { it.isNotEmpty() }
            // A rule that only ever matched on geo data now matches nothing in
            // particular. Keeping it would hand its outbound every connection.
            if (wasConstrained && rule.ip.isNullOrEmpty() && rule.domain.isNullOrEmpty()) continue
            kept.add(rule)
        }
        v2rayConfig.routing.rules = kept

        val servers = v2rayConfig.dns?.servers ?: return
        val keptServers = ArrayList<Any>(servers.size)
        for (server in servers) {
            if (server !is V2rayConfig.DnsBean.ServersBean) {
                keptServers.add(server)
                continue
            }
            val wasConstrained = !server.domains.isNullOrEmpty()
            server.domains = server.domains?.filterNot { it.startsWith("geosite:") }?.takeIf { it.isNotEmpty() }
            server.expectIPs = server.expectIPs?.filterNot { it.startsWith("geoip:") }?.takeIf { it.isNotEmpty() }
            // Same reasoning: a server scoped only to a geosite list would
            // otherwise widen into a catch-all resolver.
            if (wasConstrained && server.domains.isNullOrEmpty()) continue
            keptServers.add(server)
        }
        v2rayConfig.dns?.servers = keptServers
    }

    /**
     * Replaces the private-network token with literal ranges and drops any
     * other geo token.
     */
    private fun resolveGeoTokens(
        values: ArrayList<String>,
        privateToken: String,
        privateReplacement: List<String>,
        geoPrefix: String,
    ): ArrayList<String> {
        val out = ArrayList<String>(values.size)
        for (value in values) {
            when {
                value == privateToken -> out.addAll(privateReplacement)
                value.startsWith(geoPrefix) ->
                    Log.i(AppConfig.TAG, "Dropping rule entry $value: no geo database is bundled")
                else -> out.add(value)
            }
        }
        return out
    }

    /**
     * Adds a specific ruleset item to the routing configuration.
     *
     * @param item The ruleset item to add
     * @param v2rayConfig The V2ray configuration object to be modified
     */
    private fun getRoutingUserRule(item: RulesetItem?, v2rayConfig: V2rayConfig) {
        try {
            if (item == null || !item.enabled) {
                return
            }

            val rule = JsonUtil.fromJson(JsonUtil.toJson(item), RulesBean::class.java) ?: return

            v2rayConfig.routing.rules.add(rule)

        } catch (e: Exception) {
            Log.e(AppConfig.TAG, "Failed to apply routing user rule", e)
        }
    }

    /**
     * Retrieves domain rules for a specific outbound tag.
     *
     * Searches through all rulesets to find domains targeting the specified tag.
     *
     * @param tag The outbound tag to search for
     * @return ArrayList of domain rules matching the tag
     */
    private fun getUserRule2Domain(tag: String): ArrayList<String> {
        val domain = ArrayList<String>()

        val rulesetItems = MmkvManager.decodeRoutingRulesets()
        rulesetItems?.forEach { key ->
            if (key.enabled && key.outboundTag == tag && !key.domain.isNullOrEmpty()) {
                key.domain?.forEach {
                    if (it != AppConfig.GEOSITE_PRIVATE
                        && (it.startsWith("geosite:") || it.startsWith("domain:"))
                    ) {
                        domain.add(it)
                    }
                }
            }
        }

        return domain
    }

    /**
     * Configures custom local DNS settings.
     *
     * Sets up DNS inbound, outbound, and routing rules for local DNS resolution.
     *
     * @param v2rayConfig The V2ray configuration object to be modified
     * @return true if custom local DNS configuration was successful, false otherwise
     */
    private fun getCustomLocalDns(v2rayConfig: V2rayConfig): Boolean {
        try {
            if (MmkvManager.decodeSettingsBool(AppConfig.PREF_FAKE_DNS_ENABLED) == true) {
                val geositeCn = arrayListOf(AppConfig.GEOSITE_CN)
                val proxyDomain = getUserRule2Domain(AppConfig.TAG_PROXY)
                val directDomain = getUserRule2Domain(AppConfig.TAG_DIRECT)
                // fakedns with all domains to make it always top priority
                v2rayConfig.dns?.servers?.add(
                    0,
                    V2rayConfig.DnsBean.ServersBean(
                        address = "fakedns",
                        domains = geositeCn.plus(proxyDomain).plus(directDomain)
                    )
                )
            }

            // DNS inbound
            val remoteDns = SettingsManager.getRemoteDnsServers()
            if (v2rayConfig.inbounds.none { e -> e.protocol == "dokodemo-door" && e.tag == "dns-in" }) {
                val dnsInboundSettings = V2rayConfig.InboundBean.InSettingsBean(
                    address = if (Utils.isPureIpAddress(remoteDns.first())) remoteDns.first() else AppConfig.DNS_PROXY,
                    port = 53,
                    network = "tcp,udp"
                )

                val localDnsPort = Utils.parseInt(
                    MmkvManager.decodeSettingsString(AppConfig.PREF_LOCAL_DNS_PORT),
                    AppConfig.PORT_LOCAL_DNS.toInt()
                )
                v2rayConfig.inbounds.add(
                    V2rayConfig.InboundBean(
                        tag = "dns-in",
                        port = localDnsPort,
                        listen = AppConfig.LOOPBACK,
                        protocol = "dokodemo-door",
                        settings = dnsInboundSettings,
                        sniffing = null
                    )
                )
            }

            // DNS outbound
            if (v2rayConfig.outbounds.none { e -> e.protocol == "dns" && e.tag == "dns-out" }) {
                v2rayConfig.outbounds.add(
                    V2rayConfig.OutboundBean(
                        protocol = "dns",
                        tag = "dns-out",
                        settings = null,
                        streamSettings = null,
                        mux = null
                    )
                )
            }

            // DNS routing tag
            v2rayConfig.routing.rules.add(
                0, RulesBean(
                    inboundTag = arrayListOf("dns-in"),
                    outboundTag = "dns-out",
                    domain = null
                )
            )
        } catch (e: Exception) {
            Log.e(AppConfig.TAG, "Failed to configure custom local DNS", e)
            return false
        }
        return true
    }

    /**
     * Configures the DNS settings for V2ray.
     *
     * Sets up DNS servers, hosts, and routing rules for DNS resolution.
     *
     * @param v2rayConfig The V2ray configuration object to be modified
     * @return true if DNS configuration was successful, false otherwise
     */
    private fun getDns(v2rayConfig: V2rayConfig): Boolean {
        try {
            val hosts = mutableMapOf<String, Any>()
            val servers = ArrayList<Any>()

            //remote Dns
            val remoteDns = SettingsManager.getRemoteDnsServers()
            val proxyDomain = getUserRule2Domain(AppConfig.TAG_PROXY)
            remoteDns.forEach {
                servers.add(it)
            }
            if (proxyDomain.isNotEmpty()) {
                servers.add(
                    V2rayConfig.DnsBean.ServersBean(
                        address = remoteDns.first(),
                        domains = proxyDomain,
                    )
                )
            }

            // domestic DNS
            val domesticDns = SettingsManager.getDomesticDnsServers()
            val directDomain = getUserRule2Domain(AppConfig.TAG_DIRECT)
            val isCnRoutingMode = directDomain.contains(AppConfig.GEOSITE_CN)
            val geoipCn = arrayListOf(AppConfig.GEOIP_CN)
            if (directDomain.isNotEmpty()) {
                servers.add(
                    V2rayConfig.DnsBean.ServersBean(
                        address = domesticDns.first(),
                        domains = directDomain,
                        expectIPs = if (isCnRoutingMode) geoipCn else null,
                        skipFallback = true
                    )
                )
            }

            if (Utils.isPureIpAddress(domesticDns.first())) {
                v2rayConfig.routing.rules.add(
                    0, RulesBean(
                        outboundTag = AppConfig.TAG_DIRECT,
                        port = "53",
                        ip = arrayListOf(domesticDns.first()),
                        domain = null
                    )
                )
            }

            //block dns
            val blkDomain = getUserRule2Domain(AppConfig.TAG_BLOCKED)
            if (blkDomain.isNotEmpty()) {
                hosts.putAll(blkDomain.map { it to AppConfig.LOOPBACK })
            }

            // hardcode googleapi rule to fix play store problems
            hosts[AppConfig.GOOGLEAPIS_CN_DOMAIN] = AppConfig.GOOGLEAPIS_COM_DOMAIN

            // hardcode popular Android Private DNS rule to fix localhost DNS problem
            hosts[AppConfig.DNS_ALIDNS_DOMAIN] = AppConfig.DNS_ALIDNS_ADDRESSES
            hosts[AppConfig.DNS_CLOUDFLARE_ONE_DOMAIN] = AppConfig.DNS_CLOUDFLARE_ONE_ADDRESSES
            hosts[AppConfig.DNS_CLOUDFLARE_DNS_COM_DOMAIN] = AppConfig.DNS_CLOUDFLARE_DNS_COM_ADDRESSES
            hosts[AppConfig.DNS_CLOUDFLARE_DNS_DOMAIN] = AppConfig.DNS_CLOUDFLARE_DNS_ADDRESSES
            hosts[AppConfig.DNS_DNSPOD_DOMAIN] = AppConfig.DNS_DNSPOD_ADDRESSES
            hosts[AppConfig.DNS_GOOGLE_DOMAIN] = AppConfig.DNS_GOOGLE_ADDRESSES
            hosts[AppConfig.DNS_QUAD9_DOMAIN] = AppConfig.DNS_QUAD9_ADDRESSES
            hosts[AppConfig.DNS_YANDEX_DOMAIN] = AppConfig.DNS_YANDEX_ADDRESSES

            //User DNS hosts
            try {
                val userHosts = MmkvManager.decodeSettingsString(AppConfig.PREF_DNS_HOSTS)
                if (userHosts.isNotNullEmpty()) {
                    var userHostsMap = userHosts?.split(",")
                        ?.filter { it.isNotEmpty() }
                        ?.filter { it.contains(":") }
                        ?.associate { it.split(":").let { (k, v) -> k to v } }
                    if (userHostsMap != null) hosts.putAll(userHostsMap)
                }
            } catch (e: Exception) {
                Log.e(AppConfig.TAG, "Failed to configure user DNS hosts", e)
            }

            // DNS dns
            v2rayConfig.dns = V2rayConfig.DnsBean(
                servers = servers,
                hosts = hosts
            )

            // DNS routing
            if (Utils.isPureIpAddress(remoteDns.first())) {
                v2rayConfig.routing.rules.add(
                    0, RulesBean(
                        outboundTag = AppConfig.TAG_PROXY,
                        port = "53",
                        ip = arrayListOf(remoteDns.first()),
                        domain = null
                    )
                )
            }
        } catch (e: Exception) {
            Log.e(AppConfig.TAG, "Failed to configure DNS", e)
            return false
        }
        return true
    }


    //endregion


    //region outbound related functions

    /**
     * Configures the primary outbound connection.
     *
     * Converts the profile to an outbound configuration and applies global settings.
     *
     * @param v2rayConfig The V2ray configuration object to be modified
     * @param config The profile item containing connection details
     * @return true if outbound configuration was successful, null if there was an error
     */
    private fun getOutbounds(
        v2rayConfig: V2rayConfig,
        config: ProfileItem,
        door: DoorOutbound? = null,
        swaps: MutableMap<String, JsonObject>? = null,
    ): Boolean? {
        val outbound = convertProfile2Outbound(config) ?: return null
        val ret = updateOutboundWithGlobalSettings(outbound)
        if (!ret) return null

        if (v2rayConfig.outbounds.isNotEmpty()) {
            v2rayConfig.outbounds[0] = outbound
        } else {
            v2rayConfig.outbounds.add(outbound)
        }

        updateOutboundFragment(v2rayConfig)
        // A fragment the link asked for. The global setting, when on, has
        // already added its own and wins. A link with a finalmask already
        // cuts its hello, and is not split twice. A door with the backend's
        // outbound has its helpers instead (DoorOutbounds).
        if (door != null && swaps != null) {
            DoorOutbounds.stage(door, outbound.tag, v2rayConfig.outbounds, swaps)
        } else if (MmkvManager.decodeSettingsBool(AppConfig.PREF_FRAGMENT_ENABLED, false) != true &&
            outbound.streamSettings?.finalmask == null
        ) {
            TlsFragment.parse(config.fragment)?.let { TlsFragment.apply(v2rayConfig.outbounds, it) }
        }
        return true
    }

    /**
     * Configures special outbound settings for Hysteria2 protocol.
     *
     * Creates a SOCKS outbound connection on a free port for protocols requiring special handling.
     *
     * @param v2rayConfig The V2ray configuration object to be modified
     * @param config The profile item containing connection details
     * @return The port number for the SOCKS connection, or null if there was an error
     */
    private fun getPlusOutbounds(v2rayConfig: V2rayConfig, config: ProfileItem): Int? {
        try {
            val socksPort = Utils.findFreePort(listOf(100 + SettingsManager.getSocksPort(), 0))

            val outboundNew = OutboundBean(
                mux = null,
                protocol = EConfigType.SOCKS.name.lowercase(),
                settings = OutSettingsBean(
                    servers = listOf(
                        OutSettingsBean.ServersBean(
                            address = AppConfig.LOOPBACK,
                            port = socksPort
                        )
                    )
                )
            )
            if (v2rayConfig.outbounds.isNotEmpty()) {
                v2rayConfig.outbounds[0] = outboundNew
            } else {
                v2rayConfig.outbounds.add(outboundNew)
            }

            return socksPort
        } catch (e: Exception) {
            Log.e(AppConfig.TAG, "Failed to configure plusOutbound", e)
            return null
        }
    }

    /**
     * Configures additional outbound connections for proxy chaining.
     *
     * Sets up previous and next proxies in a subscription for advanced routing capabilities.
     *
     * @param v2rayConfig The V2ray configuration object to be modified
     * @param subscriptionId The subscription ID to look up related proxies
     * @return true if additional outbounds were configured successfully, false otherwise
     */
    private fun getMoreOutbounds(v2rayConfig: V2rayConfig, subscriptionId: String): Boolean {
        //fragment proxy
        if (MmkvManager.decodeSettingsBool(AppConfig.PREF_FRAGMENT_ENABLED, false) == true) {
            return false
        }

        if (subscriptionId.isEmpty()) {
            return false
        }
        try {
            val subItem = MmkvManager.decodeSubscription(subscriptionId) ?: return false

            //current proxy
            val outbound = v2rayConfig.outbounds[0]

            //Previous proxy
            val prevNode = SettingsManager.getServerViaRemarks(subItem.prevProfile)
            if (prevNode != null) {
                val prevOutbound = convertProfile2Outbound(prevNode)
                if (prevOutbound != null) {
                    updateOutboundWithGlobalSettings(prevOutbound)
                    prevOutbound.tag = AppConfig.TAG_PROXY + "2"
                    v2rayConfig.outbounds.add(prevOutbound)
                    outbound.ensureSockopt().dialerProxy = prevOutbound.tag
                }
            }

            //Next proxy
            val nextNode = SettingsManager.getServerViaRemarks(subItem.nextProfile)
            if (nextNode != null) {
                val nextOutbound = convertProfile2Outbound(nextNode)
                if (nextOutbound != null) {
                    updateOutboundWithGlobalSettings(nextOutbound)
                    nextOutbound.tag = AppConfig.TAG_PROXY
                    v2rayConfig.outbounds.add(0, nextOutbound)
                    outbound.tag = AppConfig.TAG_PROXY + "1"
                    nextOutbound.ensureSockopt().dialerProxy = outbound.tag
                }
            }
        } catch (e: Exception) {
            Log.e(AppConfig.TAG, "Failed to configure more outbounds", e)
            return false
        }

        return true
    }

    /**
     * Updates outbound settings based on global preferences.
     *
     * Applies multiplexing and protocol-specific settings to an outbound connection.
     *
     * @param outbound The outbound connection to update
     * @return true if the update was successful, false otherwise
     */
    private fun updateOutboundWithGlobalSettings(outbound: V2rayConfig.OutboundBean): Boolean {
        try {
            var muxEnabled = MmkvManager.decodeSettingsBool(AppConfig.PREF_MUX_ENABLED, false)
            val protocol = outbound.protocol
            if (protocol.equals(EConfigType.SHADOWSOCKS.name, true)
                || protocol.equals(EConfigType.SOCKS.name, true)
                || protocol.equals(EConfigType.HTTP.name, true)
                || protocol.equals(EConfigType.TROJAN.name, true)
                || protocol.equals(EConfigType.WIREGUARD.name, true)
                || protocol.equals(EConfigType.HYSTERIA2.name, true)
            ) {
                muxEnabled = false
            } else if (outbound.streamSettings?.network == NetworkType.XHTTP.type) {
                muxEnabled = false
            }

            if (muxEnabled == true) {
                outbound.mux?.enabled = true
                outbound.mux?.concurrency = MmkvManager.decodeSettingsString(AppConfig.PREF_MUX_CONCURRENCY, "8").orEmpty().toInt()
                outbound.mux?.xudpConcurrency = MmkvManager.decodeSettingsString(AppConfig.PREF_MUX_XUDP_CONCURRENCY, "16").orEmpty().toInt()
                outbound.mux?.xudpProxyUDP443 = MmkvManager.decodeSettingsString(AppConfig.PREF_MUX_XUDP_QUIC, "reject")
                if (protocol.equals(EConfigType.VLESS.name, true) && outbound.settings?.vnext?.first()?.users?.first()?.flow?.isNotEmpty() == true) {
                    outbound.mux?.concurrency = -1
                }
            } else {
                outbound.mux?.enabled = false
                outbound.mux?.concurrency = -1
            }

            if (protocol.equals(EConfigType.WIREGUARD.name, true)) {
                var localTunAddr = if (outbound.settings?.address == null) {
                    listOf(AppConfig.WIREGUARD_LOCAL_ADDRESS_V4)
                } else {
                    outbound.settings?.address as List<*>
                }
                if (MmkvManager.decodeSettingsBool(AppConfig.PREF_PREFER_IPV6) != true) {
                    localTunAddr = listOf(localTunAddr.first())
                }
                outbound.settings?.address = localTunAddr
            }

            if (outbound.streamSettings?.network == AppConfig.DEFAULT_NETWORK
                && outbound.streamSettings?.tcpSettings?.header?.type == AppConfig.HEADER_TYPE_HTTP
            ) {
                val path = outbound.streamSettings?.tcpSettings?.header?.request?.path
                val host = outbound.streamSettings?.tcpSettings?.header?.request?.headers?.Host

                val requestString: String by lazy {
                    """{"version":"1.1","method":"GET","headers":{"User-Agent":["Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.6478.122 Mobile Safari/537.36"],"Accept-Encoding":["gzip, deflate"],"Connection":["keep-alive"],"Pragma":"no-cache"}}"""
                }
                outbound.streamSettings?.tcpSettings?.header?.request = JsonUtil.fromJson(
                    requestString,
                    StreamSettingsBean.TcpSettingsBean.HeaderBean.RequestBean::class.java
                )
                outbound.streamSettings?.tcpSettings?.header?.request?.path =
                    if (path.isNullOrEmpty()) {
                        listOf("/")
                    } else {
                        path
                    }
                outbound.streamSettings?.tcpSettings?.header?.request?.headers?.Host = host
            }


        } catch (e: Exception) {
            Log.e(AppConfig.TAG, "Failed to update outbound with global settings", e)
            return false
        }
        return true
    }

    /**
     * Configures load balancing settings for the V2ray configuration.
     *
     * @param v2rayConfig The V2ray configuration object to be modified with balancing settings
     */
    private fun getBalance(v2rayConfig: V2rayConfig)
    {
        try {
            v2rayConfig.routing.rules.forEach { rule ->
                if (rule.outboundTag == "proxy") {
                    rule.outboundTag = null
                    rule.balancerTag = "proxy-round"
                }
            }

            if (MmkvManager.decodeSettingsString(AppConfig.PREF_INTELLIGENT_SELECTION_METHOD, "0") == "0") {
                val balancer = V2rayConfig.RoutingBean.BalancerBean(
                    tag = "proxy-round",
                    selector = listOf("proxy-"),
                    strategy = V2rayConfig.RoutingBean.StrategyObject(
                        type = "leastPing"
                    )
                )
                v2rayConfig.routing.balancers = listOf(balancer)
                v2rayConfig.observatory = V2rayConfig.ObservatoryObject(
                    subjectSelector = listOf("proxy-"),
                    probeUrl = MmkvManager.decodeSettingsString(AppConfig.PREF_DELAY_TEST_URL) ?: AppConfig.DELAY_TEST_URL,
                    probeInterval = "3m",
                    enableConcurrency = true
                )
            } else {
                val balancer = V2rayConfig.RoutingBean.BalancerBean(
                    tag = "proxy-round",
                    selector = listOf("proxy-"),
                    strategy = V2rayConfig.RoutingBean.StrategyObject(
                        type = "leastLoad"
                    )
                )
                v2rayConfig.routing.balancers = listOf(balancer)
                v2rayConfig.burstObservatory = V2rayConfig.BurstObservatoryObject(
                    subjectSelector = listOf("proxy-"),
                    pingConfig = V2rayConfig.BurstObservatoryObject.PingConfigObject(
                        destination = MmkvManager.decodeSettingsString(AppConfig.PREF_DELAY_TEST_URL) ?: AppConfig.DELAY_TEST_URL,
                        interval = "5m",
                        sampling = 2,
                        timeout = "30s"
                    )
                )
            }

            if (v2rayConfig.routing.domainStrategy == "IPIfNonMatch") {
                v2rayConfig.routing.rules.add(
                    RulesBean(
                        ip = arrayListOf("0.0.0.0/0", "::/0"),
                        balancerTag = "proxy-round",
                        type = "field"
                    )
                )
            } else {
                v2rayConfig.routing.rules.add(
                    RulesBean(
                        network = "tcp,udp",
                        balancerTag = "proxy-round",
                        type = "field"
                    )
                )
            }
        } catch (e: Exception) {
            Log.e(AppConfig.TAG, "Failed to configure balance", e)
        }
    }

    /**
     * Updates the outbound with fragment settings for traffic optimization.
     *
     * Configures packet fragmentation for TLS and REALITY protocols if enabled.
     *
     * @param v2rayConfig The V2ray configuration object to be modified
     * @return true if fragment configuration was successful, false otherwise
     */
    private fun updateOutboundFragment(v2rayConfig: V2rayConfig): Boolean {
        try {
            if (MmkvManager.decodeSettingsBool(AppConfig.PREF_FRAGMENT_ENABLED, false) == false) {
                return true
            }
            if (v2rayConfig.outbounds[0].streamSettings?.security != AppConfig.TLS
                && v2rayConfig.outbounds[0].streamSettings?.security != AppConfig.REALITY
            ) {
                return true
            }

            val fragmentOutbound =
                V2rayConfig.OutboundBean(
                    protocol = AppConfig.PROTOCOL_FREEDOM,
                    tag = AppConfig.TAG_FRAGMENT,
                    mux = null
                )

            var packets =
                MmkvManager.decodeSettingsString(AppConfig.PREF_FRAGMENT_PACKETS) ?: "tlshello"
            if (v2rayConfig.outbounds[0].streamSettings?.security == AppConfig.REALITY
                && packets == "tlshello"
            ) {
                packets = "1-3"
            } else if (v2rayConfig.outbounds[0].streamSettings?.security == AppConfig.TLS
                && packets != "tlshello"
            ) {
                packets = "tlshello"
            }

            fragmentOutbound.settings = OutboundBean.OutSettingsBean(
                fragment = OutboundBean.OutSettingsBean.FragmentBean(
                    packets = packets,
                    length = MmkvManager.decodeSettingsString(AppConfig.PREF_FRAGMENT_LENGTH)
                        ?: "50-100",
                    interval = MmkvManager.decodeSettingsString(AppConfig.PREF_FRAGMENT_INTERVAL)
                        ?: "10-20"
                ),
                noises = listOf(
                    OutboundBean.OutSettingsBean.NoiseBean(
                        type = "rand",
                        packet = "10-20",
                        delay = "10-16",
                    )
                ),
            )
            fragmentOutbound.streamSettings = StreamSettingsBean(
                sockopt = StreamSettingsBean.SockoptBean(
                    TcpNoDelay = true,
                    mark = 255
                )
            )
            v2rayConfig.outbounds.add(fragmentOutbound)

            //proxy chain
            v2rayConfig.outbounds[0].streamSettings?.sockopt =
                StreamSettingsBean.SockoptBean(
                    dialerProxy = AppConfig.TAG_FRAGMENT
                )
        } catch (e: Exception) {
            Log.e(AppConfig.TAG, "Failed to update outbound fragment", e)
            return false
        }
        return true
    }

    /**
     * Resolves domain names to IP addresses in outbound connections.
     *
     * Pre-resolves domains to improve connection speed and reliability.
     *
     * @param v2rayConfig The V2ray configuration object to be modified
     */
    private fun resolveOutboundDomainsToHosts(v2rayConfig: V2rayConfig) {
        val proxyOutboundList = v2rayConfig.getAllProxyOutbound()
        val dns = v2rayConfig.dns ?: return
        val newHosts = dns.hosts?.toMutableMap() ?: mutableMapOf()
        val preferIpv6 = MmkvManager.decodeSettingsBool(AppConfig.PREF_PREFER_IPV6) == true

        for (item in proxyOutboundList) {
            val domain = item.getServerAddress()
            if (domain.isNullOrEmpty()) continue

            if (newHosts.containsKey(domain)) {
                item.ensureSockopt().domainStrategy = if (preferIpv6) "UseIPv6v4" else "UseIPv4v6"
                continue
            }

            val resolvedIps = HttpUtil.resolveHostToIP(domain, preferIpv6)
            if (resolvedIps.isNullOrEmpty()) continue

            item.ensureSockopt().domainStrategy = if (preferIpv6) "UseIPv6v4" else "UseIPv4v6"
            newHosts[domain] = if (resolvedIps.size == 1) {
                resolvedIps[0]
            } else {
                resolvedIps
            }
        }

        dns.hosts = newHosts
    }

    /**
     * Converts a profile item to an outbound configuration.
     *
     * Creates appropriate outbound settings based on the protocol type.
     *
     * @param profileItem The profile item to convert
     * @return OutboundBean configuration for the profile, or null if not supported
     */
    private fun convertProfile2Outbound(profileItem: ProfileItem): V2rayConfig.OutboundBean? {
        return when (profileItem.configType) {
            EConfigType.VMESS -> VmessFmt.toOutbound(profileItem)
            EConfigType.CUSTOM -> null
            EConfigType.SHADOWSOCKS -> ShadowsocksFmt.toOutbound(profileItem)
            EConfigType.SOCKS -> SocksFmt.toOutbound(profileItem)
            EConfigType.VLESS -> VlessFmt.toOutbound(profileItem)
            EConfigType.TROJAN -> TrojanFmt.toOutbound(profileItem)
            EConfigType.WIREGUARD -> WireguardFmt.toOutbound(profileItem)
            EConfigType.HYSTERIA2 -> null
            EConfigType.HTTP -> HttpFmt.toOutbound(profileItem)
        }
    }

    /**
     * Creates an initial outbound configuration for a specific protocol type.
     *
     * Provides a template configuration for different protocol types.
     *
     * @param configType The type of configuration to create
     * @return An initial OutboundBean for the specified configuration type, or null for custom types
     */
    fun createInitOutbound(configType: EConfigType): OutboundBean? {
        return when (configType) {
            EConfigType.VMESS,
            EConfigType.VLESS ->
                return OutboundBean(
                    protocol = configType.name.lowercase(),
                    settings = OutSettingsBean(
                        vnext = listOf(
                            OutSettingsBean.VnextBean(
                                users = listOf(OutSettingsBean.VnextBean.UsersBean())
                            )
                        )
                    ),
                    streamSettings = StreamSettingsBean()
                )

            EConfigType.SHADOWSOCKS,
            EConfigType.SOCKS,
            EConfigType.HTTP,
            EConfigType.TROJAN,
            EConfigType.HYSTERIA2 ->
                return OutboundBean(
                    protocol = configType.name.lowercase(),
                    settings = OutSettingsBean(
                        servers = listOf(OutSettingsBean.ServersBean())
                    ),
                    streamSettings = StreamSettingsBean()
                )

            EConfigType.WIREGUARD ->
                return OutboundBean(
                    protocol = configType.name.lowercase(),
                    settings = OutSettingsBean(
                        secretKey = "",
                        peers = listOf(OutSettingsBean.WireGuardBean())
                    )
                )

            EConfigType.CUSTOM -> null
        }
    }

    /**
     * Configures transport settings for an outbound connection.
     *
     * Sets up protocol-specific transport options based on the profile settings.
     *
     * @param streamSettings The stream settings to configure
     * @param profileItem The profile containing transport configuration
     * @return The Server Name Indication (SNI) value to use, or null if not applicable
     */
    fun populateTransportSettings(streamSettings: StreamSettingsBean, profileItem: ProfileItem): String? {
        val transport = profileItem.network.orEmpty()
        val headerType = profileItem.headerType
        val host = profileItem.host
        val path = profileItem.path
        val seed = profileItem.seed
//        val quicSecurity = profileItem.quicSecurity
//        val key = profileItem.quicKey
        val mode = profileItem.mode
        val serviceName = profileItem.serviceName
        val authority = profileItem.authority
        val xhttpMode = profileItem.xhttpMode
        val xhttpExtra = profileItem.xhttpExtra

        var sni: String? = null
        streamSettings.network = if (transport.isEmpty()) NetworkType.TCP.type else transport
        when (streamSettings.network) {
            NetworkType.TCP.type -> {
                val tcpSetting = StreamSettingsBean.TcpSettingsBean()
                if (headerType == AppConfig.HEADER_TYPE_HTTP) {
                    tcpSetting.header.type = AppConfig.HEADER_TYPE_HTTP
                    if (!TextUtils.isEmpty(host) || !TextUtils.isEmpty(path)) {
                        val requestObj = StreamSettingsBean.TcpSettingsBean.HeaderBean.RequestBean()
                        requestObj.headers.Host = host.orEmpty().split(",").map { it.trim() }.filter { it.isNotEmpty() }
                        requestObj.path = path.orEmpty().split(",").map { it.trim() }.filter { it.isNotEmpty() }
                        tcpSetting.header.request = requestObj
                        sni = requestObj.headers.Host?.getOrNull(0)
                    }
                } else {
                    tcpSetting.header.type = "none"
                    sni = host
                }
                streamSettings.tcpSettings = tcpSetting
            }

            NetworkType.KCP.type -> {
                val kcpsetting = StreamSettingsBean.KcpSettingsBean()
                kcpsetting.header.type = headerType ?: "none"
                if (seed.isNullOrEmpty()) {
                    kcpsetting.seed = null
                } else {
                    kcpsetting.seed = seed
                }
                if (host.isNullOrEmpty()) {
                    kcpsetting.header.domain = null
                } else {
                    kcpsetting.header.domain = host
                }
                streamSettings.kcpSettings = kcpsetting
            }

            NetworkType.WS.type -> {
                val wssetting = StreamSettingsBean.WsSettingsBean()
                wssetting.headers.Host = host.orEmpty()
                sni = host
                wssetting.path = path ?: "/"
                streamSettings.wsSettings = wssetting
            }

            NetworkType.HTTP_UPGRADE.type -> {
                val httpupgradeSetting = StreamSettingsBean.HttpupgradeSettingsBean()
                httpupgradeSetting.host = host.orEmpty()
                sni = host
                httpupgradeSetting.path = path ?: "/"
                streamSettings.httpupgradeSettings = httpupgradeSetting
            }

            NetworkType.XHTTP.type -> {
                val xhttpSetting = StreamSettingsBean.XhttpSettingsBean()
                xhttpSetting.host = host.orEmpty()
                sni = host
                xhttpSetting.path = path ?: "/"
                xhttpSetting.mode = xhttpMode
                xhttpSetting.extra = JsonUtil.parseString(xhttpExtra)
                streamSettings.xhttpSettings = xhttpSetting
            }

            NetworkType.H2.type, NetworkType.HTTP.type -> {
                streamSettings.network = NetworkType.H2.type
                val h2Setting = StreamSettingsBean.HttpSettingsBean()
                h2Setting.host = host.orEmpty().split(",").map { it.trim() }.filter { it.isNotEmpty() }
                sni = h2Setting.host.getOrNull(0)
                h2Setting.path = path ?: "/"
                streamSettings.httpSettings = h2Setting
            }

//                    "quic" -> {
//                        val quicsetting = QuicSettingBean()
//                        quicsetting.security = quicSecurity ?: "none"
//                        quicsetting.key = key.orEmpty()
//                        quicsetting.header.type = headerType ?: "none"
//                        quicSettings = quicsetting
//                    }

            NetworkType.GRPC.type -> {
                val grpcSetting = StreamSettingsBean.GrpcSettingsBean()
                grpcSetting.multiMode = mode == "multi"
                grpcSetting.serviceName = serviceName.orEmpty()
                grpcSetting.authority = authority.orEmpty()
                grpcSetting.idle_timeout = 60
                grpcSetting.health_check_timeout = 20
                sni = authority
                streamSettings.grpcSettings = grpcSetting
            }
        }
        return sni
    }

    /**
     * Configures TLS or REALITY security settings for an outbound connection.
     *
     * Sets up security-related parameters like certificates, fingerprints, and SNI.
     *
     * @param streamSettings The stream settings to configure
     * @param profileItem The profile containing security configuration
     * @param sniExt An external SNI value to use if the profile doesn't specify one
     */
    fun populateTlsSettings(streamSettings: StreamSettingsBean, profileItem: ProfileItem, sniExt: String?) {
        val streamSecurity = profileItem.security.orEmpty()
        val allowInsecure = profileItem.insecure == true
        val sni = if (profileItem.sni.isNullOrEmpty()) {
            when {
                sniExt.isNotNullEmpty() && Utils.isDomainName(sniExt) -> sniExt
                profileItem.server.isNotNullEmpty() && Utils.isDomainName(profileItem.server) -> profileItem.server
                else -> sniExt
            }
        } else {
            profileItem.sni
        }
        val fingerprint = profileItem.fingerPrint
        val alpns = profileItem.alpn
        val publicKey = profileItem.publicKey
        val shortId = profileItem.shortId
        val spiderX = profileItem.spiderX

        streamSettings.security = if (streamSecurity.isEmpty()) null else streamSecurity
        if (streamSettings.security == null) return
        // For WebSocket (ws), we MUST force http/1.1 ALPN.
        // H2 negotiation breaks standard WebSocket upgrades.
        val isWebSocket = streamSettings.network == "ws"
        val effectiveAlpn = if (alpns.isNullOrEmpty()) {
            null
        } else {
            val list = alpns.split(",").map { it.trim() }.filter { it.isNotEmpty() }
            if (isWebSocket) list.filter { it != "h2" } else list
        }
        
        val tlsSetting = StreamSettingsBean.TlsSettingsBean(
            allowInsecure = allowInsecure,
            serverName = if (sni.isNullOrEmpty()) null else sni,
            fingerprint = if (fingerprint.isNullOrEmpty()) null else fingerprint,
            alpn = effectiveAlpn,
            publicKey = if (publicKey.isNullOrEmpty()) null else publicKey,
            shortId = if (shortId.isNullOrEmpty()) null else shortId,
            spiderX = if (spiderX.isNullOrEmpty()) null else spiderX,
        )
        if (streamSettings.security == AppConfig.TLS) {
            // Encrypted Client Hello hides our server name inside the hello,
            // for a filter that no longer passes split hellos.
            tlsSetting.echConfigList = profileItem.echConfigList?.takeIf { it.isNotBlank() }
            // The channels' "F&F": a finalmask that cuts the
            // hello into TLS records, with Go's own TLS (fingerprint
            // "unsafe") offering these cipher suites.
            tlsSetting.cipherSuites = profileItem.cipherSuites?.takeIf { it.isNotBlank() }
            streamSettings.finalmask = FinalMask.parse(profileItem.finalMask)
            streamSettings.tlsSettings = tlsSetting
            streamSettings.realitySettings = null
        } else if (streamSettings.security == AppConfig.REALITY) {
            streamSettings.tlsSettings = null
            streamSettings.realitySettings = tlsSetting
        }
    }

    //endregion
}
