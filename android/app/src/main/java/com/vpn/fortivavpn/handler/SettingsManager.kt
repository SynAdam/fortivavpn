package com.vpn.fortivavpn.handler

import android.content.Context
import android.content.res.AssetManager
import android.text.TextUtils
import android.util.Log
import androidx.appcompat.app.AppCompatDelegate
import com.vpn.fortivavpn.AppConfig
import com.vpn.fortivavpn.AppConfig.ANG_PACKAGE
import com.vpn.fortivavpn.AppConfig.GEOIP_PRIVATE
import com.vpn.fortivavpn.AppConfig.GEOSITE_PRIVATE
import com.vpn.fortivavpn.AppConfig.TAG_DIRECT
import com.vpn.fortivavpn.dto.EConfigType
import com.vpn.fortivavpn.dto.Language
import com.vpn.fortivavpn.dto.ProfileItem
import com.vpn.fortivavpn.dto.RoutingType
import com.vpn.fortivavpn.dto.RulesetItem
import com.vpn.fortivavpn.dto.V2rayConfig
import com.vpn.fortivavpn.dto.VpnInterfaceAddressConfig
import com.vpn.fortivavpn.handler.MmkvManager.decodeServerConfig
import com.vpn.fortivavpn.handler.MmkvManager.decodeServerList
import com.vpn.fortivavpn.util.JsonUtil
import com.vpn.fortivavpn.util.Utils
import java.io.File
import java.io.FileOutputStream
import java.util.Collections
import java.util.Locale

object SettingsManager {

    /** Bumped when the shipped default ruleset changes, to re-seed installs. */
    private const val ROUTING_PRESET_STAMP = "pref_routing_preset_applied"
    private const val ROUTING_PRESET_VERSION = "white-iran-v1"

    /**
     * Seed the routing rules: Iranian traffic direct, everything else
     * through the tunnel.
     *
     * The history, because the stamp above has now moved twice. The
     * original default was [RoutingType.WHITE], which routes `geoip:cn`
     * and `geosite:cn` direct, and that was harmless only because the geo
     * databases were never staged: both rules were stripped on every
     * connect and every install behaved like [RoutingType.GLOBAL].
     * Staging the databases (#39) made country rules real, so the default
     * moved to GLOBAL, which is what users were already getting.
     *
     * It is now [RoutingType.WHITE_IRAN], decided in #40. An Iranian user
     * loading an Iranian site was sending that traffic to Helsinki and
     * back: slower than a direct connection, and spending the daily
     * allowance on traffic that never needed the tunnel.
     *
     * What that costs, stated plainly because it is a real cost: traffic
     * routed direct is traffic the local ISP can see. A user who connects
     * to a VPN and then visits an Iranian site may expect that visit to be
     * inside the tunnel, and after this it is not. #40 records the
     * decision and the argument on both sides.
     *
     * Re-seeding on a new stamp is what carries existing installs over
     * deliberately rather than by accident. It is safe only because
     * nothing in the app can edit routing: there is no picker, so the
     * stored rules are always a pristine preset. Give users a routing
     * screen and this has to respect their choice instead.
     */
    fun initRoutingRulesets(context: Context) {
        val exist = MmkvManager.decodeRoutingRulesets()
        val applied = MmkvManager.decodeSettingsString(ROUTING_PRESET_STAMP)

        if (exist.isNullOrEmpty() || applied != ROUTING_PRESET_VERSION) {
            val rulesetList = getPresetRoutingRulesets(context) ?: return
            MmkvManager.encodeRoutingRulesets(rulesetList)
            MmkvManager.encodeSettings(ROUTING_PRESET_STAMP, ROUTING_PRESET_VERSION)
        }
    }

    /**
     * Get preset routing rulesets.
     * @param context The application context.
     * @param index The index of the routing type.
     * @return A mutable list of RulesetItem.
     */
    private fun getPresetRoutingRulesets(
        context: Context,
        index: Int = RoutingType.WHITE_IRAN.ordinal,
    ): MutableList<RulesetItem>? {
        val fileName = RoutingType.fromIndex(index).fileName
        val assets = Utils.readTextFromAssets(context, fileName)
        if (TextUtils.isEmpty(assets)) {
            return null
        }

        return JsonUtil.fromJson(assets, Array<RulesetItem>::class.java).toMutableList()
    }

    /**
     * Reset routing rulesets from presets.
     * @param context The application context.
     * @param index The index of the routing type.
     */
    fun resetRoutingRulesetsFromPresets(context: Context, index: Int) {
        val rulesetList = getPresetRoutingRulesets(context, index) ?: return
        resetRoutingRulesetsCommon(rulesetList)
    }

    /**
     * Reset routing rulesets.
     * @param content The content of the rulesets.
     * @return True if successful, false otherwise.
     */
    fun resetRoutingRulesets(content: String?): Boolean {
        if (content.isNullOrEmpty()) {
            return false
        }

        try {
            val rulesetList = JsonUtil.fromJson(content, Array<RulesetItem>::class.java).toMutableList()
            if (rulesetList.isNullOrEmpty()) {
                return false
            }

            resetRoutingRulesetsCommon(rulesetList)
            return true
        } catch (e: Exception) {
            Log.e(ANG_PACKAGE, "Failed to reset routing rulesets", e)
            return false
        }
    }

    /**
     * Common method to reset routing rulesets.
     * @param rulesetList The list of rulesets.
     */
    private fun resetRoutingRulesetsCommon(rulesetList: MutableList<RulesetItem>) {
        val rulesetNew: MutableList<RulesetItem> = mutableListOf()
        MmkvManager.decodeRoutingRulesets()?.forEach { key ->
            if (key.locked == true) {
                rulesetNew.add(key)
            }
        }

        rulesetNew.addAll(rulesetList)
        MmkvManager.encodeRoutingRulesets(rulesetNew)
    }

    /**
     * Get a routing ruleset by index.
     * @param index The index of the ruleset.
     * @return The RulesetItem.
     */
    fun getRoutingRuleset(index: Int): RulesetItem? {
        if (index < 0) return null

        val rulesetList = MmkvManager.decodeRoutingRulesets()
        if (rulesetList.isNullOrEmpty()) return null

        return rulesetList[index]
    }

    /**
     * Save a routing ruleset.
     * @param index The index of the ruleset.
     * @param ruleset The RulesetItem to save.
     */
    fun saveRoutingRuleset(index: Int, ruleset: RulesetItem?) {
        if (ruleset == null) return

        var rulesetList = MmkvManager.decodeRoutingRulesets()
        if (rulesetList.isNullOrEmpty()) {
            rulesetList = mutableListOf()
        }

        if (index < 0 || index >= rulesetList.count()) {
            rulesetList.add(0, ruleset)
        } else {
            rulesetList[index] = ruleset
        }
        MmkvManager.encodeRoutingRulesets(rulesetList)
    }

    /**
     * Remove a routing ruleset by index.
     * @param index The index of the ruleset.
     */
    fun removeRoutingRuleset(index: Int) {
        if (index < 0) return

        val rulesetList = MmkvManager.decodeRoutingRulesets()
        if (rulesetList.isNullOrEmpty()) return

        rulesetList.removeAt(index)
        MmkvManager.encodeRoutingRulesets(rulesetList)
    }

    /**
     * Check if routing rulesets bypass LAN.
     * @return True if bypassing LAN, false otherwise.
     */
    fun routingRulesetsBypassLan(): Boolean {
        val vpnBypassLan = MmkvManager.decodeSettingsString(AppConfig.PREF_VPN_BYPASS_LAN) ?: "2"
        if (vpnBypassLan == "1") {
            return true
        } else if (vpnBypassLan == "2") {
            return false
        }

        val guid = MmkvManager.getSelectServer() ?: return false
        val config = decodeServerConfig(guid) ?: return false
        if (config.configType == EConfigType.CUSTOM) {
            val raw = MmkvManager.decodeServerRaw(guid) ?: return false
            val v2rayConfig = JsonUtil.fromJson(raw, V2rayConfig::class.java)
            val exist = v2rayConfig.routing.rules.filter { it.outboundTag == TAG_DIRECT }.any {
                it.domain?.contains(GEOSITE_PRIVATE) == true || it.ip?.contains(GEOIP_PRIVATE) == true
            }
            return exist == true
        }

        val rulesetItems = MmkvManager.decodeRoutingRulesets()
        val exist = rulesetItems?.filter { it.enabled && it.outboundTag == TAG_DIRECT }?.any {
            it.domain?.contains(GEOSITE_PRIVATE) == true || it.ip?.contains(GEOIP_PRIVATE) == true
        }
        return exist == true
    }

    /**
     * Swap routing rulesets.
     * @param fromPosition The position to swap from.
     * @param toPosition The position to swap to.
     */
    fun swapRoutingRuleset(fromPosition: Int, toPosition: Int) {
        val rulesetList = MmkvManager.decodeRoutingRulesets()
        if (rulesetList.isNullOrEmpty()) return

        Collections.swap(rulesetList, fromPosition, toPosition)
        MmkvManager.encodeRoutingRulesets(rulesetList)
    }

    /**
     * Swap subscriptions.
     * @param fromPosition The position to swap from.
     * @param toPosition The position to swap to.
     */
    fun swapSubscriptions(fromPosition: Int, toPosition: Int) {
        val subsList = MmkvManager.decodeSubsList()
        if (subsList.isNullOrEmpty()) return

        Collections.swap(subsList, fromPosition, toPosition)
        MmkvManager.encodeSubsList(subsList)
    }

    /**
     * Get server via remarks.
     * @param remarks The remarks of the server.
     * @return The ProfileItem.
     */
    fun getServerViaRemarks(remarks: String?): ProfileItem? {
        if (remarks.isNullOrEmpty()) {
            return null
        }
        val serverList = decodeServerList()
        for (guid in serverList) {
            val profile = decodeServerConfig(guid)
            if (profile != null && profile.remarks == remarks) {
                return profile
            }
        }
        return null
    }

    /**
     * Get the SOCKS port.
     * @return The SOCKS port.
     */
    fun getSocksPort(): Int {
        return Utils.parseInt(MmkvManager.decodeSettingsString(AppConfig.PREF_SOCKS_PORT), AppConfig.PORT_SOCKS.toInt())
    }

    /**
     * Get the HTTP port.
     * @return The HTTP port.
     */
    fun getHttpPort(): Int {
        return getSocksPort() + if (Utils.isXray()) 0 else 1
    }

    /** The geo databases the core resolves `geoip:` and `geosite:` tokens from. */
    private val GEO_ASSETS = arrayOf("geosite.dat", "geoip.dat")

    /** Records which build staged the current copies, so an update refreshes them. */
    private const val GEO_STAMP = "geo.version"

    /**
     * Copies the bundled geo databases to the folder the core reads.
     *
     * `Libv2ray.initCoreEnv` already points the core at
     * [Utils.userAssetPath], but the .dat files ship inside the APK and
     * nothing else puts them there. Without this the core resolves no
     * `geoip:` or `geosite:` token, so the Iran bypass preset sends domestic
     * traffic through the tunnel and spends the daily allowance on local
     * sites.
     *
     * Copies through a temp file and renames, because a process killed
     * mid-copy would otherwise leave a truncated database that the core
     * reads as valid. The stamp file records the build that staged the
     * copies, so a geo database refreshed in the .aar reaches installs that
     * already have an older one.
     *
     * Safe to call repeatedly and from more than one thread. After the first
     * run it reads one small file and returns.
     */
    @Synchronized
    fun initAssets(context: Context, assets: AssetManager) {
        val extFolder = Utils.userAssetPath(context)
        if (extFolder.isEmpty()) {
            Log.e(AppConfig.TAG, "no asset folder available, geo rules will be stripped")
            return
        }

        val build = try {
            context.packageManager.getPackageInfo(context.packageName, 0).versionName ?: "?"
        } catch (e: Exception) {
            "?"
        }

        val stamp = File(extFolder, GEO_STAMP)
        val staged = runCatching { stamp.readText() }.getOrNull()
        if (staged == build && GEO_ASSETS.all { File(extFolder, it).length() > 0 }) return

        var copied = 0
        for (name in GEO_ASSETS) {
            try {
                val target = File(extFolder, name)
                val temp = File(extFolder, "$name.tmp")
                assets.open(name).use { input ->
                    FileOutputStream(temp).use { output -> input.copyTo(output) }
                }
                if (!temp.renameTo(target)) {
                    temp.delete()
                    Log.e(AppConfig.TAG, "could not move $name into $extFolder")
                    continue
                }
                copied++
                Log.i(AppConfig.TAG, "geo asset $name staged, ${target.length()} bytes")
            } catch (e: Exception) {
                Log.e(ANG_PACKAGE, "could not stage geo asset $name", e)
            }
        }

        // Only stamp a complete set. A partial copy must be retried next
        // launch rather than remembered as done.
        if (copied == GEO_ASSETS.size) {
            runCatching { stamp.writeText(build) }
        }
    }

    /**
     * Whether both geo databases are present and non-empty.
     *
     * The routing builder asks before deciding whether `geoip:` and
     * `geosite:` tokens can be left in the config. One token the core cannot
     * resolve makes it reject the whole config, and the tunnel then never
     * starts, so a missing database has to mean "strip" and never "try
     * anyway".
     */
    fun geoAssetsAvailable(context: Context): Boolean {
        val extFolder = Utils.userAssetPath(context)
        if (extFolder.isEmpty()) return false
        return GEO_ASSETS.all { File(extFolder, it).length() > 0 }
    }

    /**
     * Get domestic DNS servers from preference.
     * @return A list of domestic DNS servers.
     */
    fun getDomesticDnsServers(): List<String> {
        val domesticDns =
            MmkvManager.decodeSettingsString(AppConfig.PREF_DOMESTIC_DNS) ?: AppConfig.DNS_DIRECT
        val ret = domesticDns.split(",").filter { Utils.isPureIpAddress(it) || Utils.isCoreDNSAddress(it) }
        if (ret.isEmpty()) {
            return listOf(AppConfig.DNS_DIRECT)
        }
        return ret
    }

    /**
     * Get remote DNS servers from preference.
     * @return A list of remote DNS servers.
     */
    fun getRemoteDnsServers(): List<String> {
        val remoteDns =
            MmkvManager.decodeSettingsString(AppConfig.PREF_REMOTE_DNS) ?: AppConfig.DNS_PROXY
        val ret = remoteDns.split(",").filter { Utils.isPureIpAddress(it) || Utils.isCoreDNSAddress(it) }
        if (ret.isEmpty()) {
            return listOf(AppConfig.DNS_PROXY)
        }
        return ret
    }

    /**
     * Get VPN DNS servers from preference.
     * @return A list of VPN DNS servers.
     */
    fun getVpnDnsServers(): List<String> {
        val vpnDns = MmkvManager.decodeSettingsString(AppConfig.PREF_VPN_DNS) ?: AppConfig.DNS_VPN
        return vpnDns.split(",").filter { Utils.isPureIpAddress(it) }
    }

    /**
     * Get delay test URL.
     * @param second Whether to use the second URL.
     * @return The delay test URL.
     */
    fun getDelayTestUrl(second: Boolean = false): String {
        return if (second) {
            AppConfig.DELAY_TEST_URL2
        } else {
            MmkvManager.decodeSettingsString(AppConfig.PREF_DELAY_TEST_URL)
                ?: AppConfig.DELAY_TEST_URL
        }
    }

    /**
     * Get the locale.
     * @return The locale.
     */
    fun getLocale(): Locale {
        val langCode =
            MmkvManager.decodeSettingsString(AppConfig.PREF_LANGUAGE) ?: Language.AUTO.code
        val language = Language.fromCode(langCode)

        return when (language) {
            Language.AUTO -> Utils.getSysLocale()
            Language.ENGLISH -> Locale.ENGLISH
            Language.CHINA -> Locale.CHINA
            Language.TRADITIONAL_CHINESE -> Locale.TRADITIONAL_CHINESE
            Language.VIETNAMESE -> Locale("vi")
            Language.RUSSIAN -> Locale("ru")
            Language.PERSIAN -> Locale("fa")
            Language.ARABIC -> Locale("ar")
            Language.BANGLA -> Locale("bn")
            Language.BAKHTIARI -> Locale("bqi", "IR")
        }
    }

    /**
     * Set night mode.
     */
    fun setNightMode() {
        when (MmkvManager.decodeSettingsString(AppConfig.PREF_UI_MODE_NIGHT, "0")) {
            "0" -> AppCompatDelegate.setDefaultNightMode(AppCompatDelegate.MODE_NIGHT_FOLLOW_SYSTEM)
            "1" -> AppCompatDelegate.setDefaultNightMode(AppCompatDelegate.MODE_NIGHT_NO)
            "2" -> AppCompatDelegate.setDefaultNightMode(AppCompatDelegate.MODE_NIGHT_YES)
        }
    }

    /**
     * Retrieves the currently selected VPN interface address configuration.
     * This method reads the user's preference for VPN interface addressing and returns
     * the corresponding configuration containing IPv4 and IPv6 addresses.
     *
     * @return The selected VpnInterfaceAddressConfig instance, or the default configuration
     *         if no valid selection is found or if the stored index is invalid.
     */
    fun getCurrentVpnInterfaceAddressConfig(): VpnInterfaceAddressConfig {
        val selectedIndex = MmkvManager.decodeSettingsString(AppConfig.PREF_VPN_INTERFACE_ADDRESS_CONFIG_INDEX, "0")?.toInt()
        return VpnInterfaceAddressConfig.getConfigByIndex(selectedIndex ?: 0)
    }
}
