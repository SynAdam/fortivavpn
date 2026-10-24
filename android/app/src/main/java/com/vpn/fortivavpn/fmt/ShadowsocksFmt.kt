package com.vpn.fortivavpn.fmt
import com.vpn.fortivavpn.AppConfig
import com.vpn.fortivavpn.dto.EConfigType
import com.vpn.fortivavpn.dto.NetworkType
import com.vpn.fortivavpn.dto.ProfileItem
import com.vpn.fortivavpn.dto.V2rayConfig.OutboundBean
import com.vpn.fortivavpn.extension.idnHost
import com.vpn.fortivavpn.handler.MmkvManager
import com.vpn.fortivavpn.handler.V2rayConfigManager
import com.vpn.fortivavpn.util.Utils
import java.net.URI

object ShadowsocksFmt : FmtBase() {
    /**
     * Parses a Shadowsocks URI string into a ProfileItem object.
     *
     * @param str the Shadowsocks URI string to parse
     * @return the parsed ProfileItem object, or null if parsing fails
     */
    fun parse(str: String): ProfileItem? {
        return parseSip002(str) ?: parseLegacy(str)
    }

    /**
     * Parses a SIP002 Shadowsocks URI string into a ProfileItem object.
     *
     * A link can also carry a transport and a security in its query, as
     * Xray's share links write them for VLESS and Trojan: `type` (xhttp, ws,
     * httpupgrade, grpc, tcp), `path`, `host`, `mode`, `serviceName`, and
     * `security` (tls or reality) with `sni`, `fp`, `alpn`, `pbk`, `sid`. The
     * lab found Shadowsocks over XHTTP the best way in for some carriers, and
     * until 2.2.0 such a link was read as plain Shadowsocks over TCP. Those
     * parameters are read the way the VLESS and Trojan parsers read them
     * ([getItemFormQuery]). A link without them reads as before.
     *
     * @param str the SIP002 Shadowsocks URI string to parse
     * @return the parsed ProfileItem object, or null if parsing fails
     */
    fun parseSip002(str: String): ProfileItem? {
        val config = ProfileItem.create(EConfigType.SHADOWSOCKS)

        val uri = URI(Utils.fixIllegalUrl(str))
        if (uri.idnHost.isEmpty()) return null
        if (uri.port <= 0) return null
        if (uri.userInfo.isNullOrEmpty()) return null

        config.remarks = Utils.urlDecode(uri.fragment.orEmpty()).let { if (it.isEmpty()) "none" else it }
        config.server = uri.idnHost
        config.serverPort = uri.port.toString()

        val result = if (uri.userInfo.contains(":")) {
            uri.userInfo.split(":", limit = 2)
        } else {
            Utils.decode(uri.userInfo).split(":", limit = 2)
        }
        if (result.count() == 2) {
            config.method = result.first()
            config.password = result.last()
        }

        if (!uri.rawQuery.isNullOrEmpty()) {
            val queryParam = getQueryParam(uri)
            if (queryParam["plugin"]?.contains("obfs=http") == true) {
                val queryPairs = HashMap<String, String>()
                for (pair in queryParam["plugin"]?.split(";") ?: listOf()) {
                    val idx = pair.split("=")
                    if (idx.count() == 2) {
                        queryPairs.put(idx.first(), idx.last())
                    }
                }
                config.network = NetworkType.TCP.type
                config.headerType = "http"
                config.host = queryPairs["obfs-host"]
                config.path = queryPairs["path"]
            } else if (hasTransport(queryParam)) {
                val allowInsecure = MmkvManager.decodeSettingsBool(AppConfig.PREF_ALLOW_INSECURE, false)
                getItemFormQuery(config, queryParam, allowInsecure)
            }
        }

        return config
    }

    /** Whether a link's query names a transport or a security. */
    private fun hasTransport(queryParam: Map<String, String>): Boolean =
        queryParam.containsKey("type") || queryParam.containsKey("security")

    /**
     * Parses a legacy Shadowsocks URI string into a ProfileItem object.
     *
     * @param str the legacy Shadowsocks URI string to parse
     * @return the parsed ProfileItem object, or null if parsing fails
     */
    fun parseLegacy(str: String): ProfileItem? {
        val config = ProfileItem.create(EConfigType.SHADOWSOCKS)
        var result = str.replace(EConfigType.SHADOWSOCKS.protocolScheme, "")
        val indexSplit = result.indexOf("#")
        if (indexSplit > 0) {
            try {
                config.remarks =
                    Utils.urlDecode(result.substring(indexSplit + 1, result.length))
            } catch (e: Exception) {
            }

            result = result.substring(0, indexSplit)
        }

        //part decode
        val indexS = result.indexOf("@")
        result = if (indexS > 0) {
            Utils.decode(result.substring(0, indexS)) + result.substring(
                indexS,
                result.length
            )
        } else {
            Utils.decode(result)
        }

        val legacyPattern = "^(.+?):(.*)@(.+?):(\\d+?)/?$".toRegex()
        val match = legacyPattern.matchEntire(result) ?: return null

        config.server = match.groupValues[3].removeSurrounding("[", "]")
        config.serverPort = match.groupValues[4]
        config.password = match.groupValues[2]
        config.method = match.groupValues[1].lowercase()

        return config
    }

    /**
     * Converts a ProfileItem object to a URI string.
     *
     * @param config the ProfileItem object to convert
     * @return the converted URI string
     */
    fun toUri(config: ProfileItem): String {
        val pw = "${config.method}:${config.password}"
        // Plain Shadowsocks stays a plain SIP002 link. One over another
        // transport, or with TLS or REALITY, says so in the query, as parse
        // reads it.
        val network = config.network?.ifEmpty { null } ?: NetworkType.TCP.type
        val query = if (network != NetworkType.TCP.type || !config.security.isNullOrEmpty()) {
            getQueryDic(config)
        } else {
            null
        }

        return toUri(config, Utils.encode(pw), query)
    }

    /**
     * Converts a ProfileItem object to an OutboundBean object.
     *
     * @param profileItem the ProfileItem object to convert
     * @return the converted OutboundBean object, or null if conversion fails
     */
    fun toOutbound(profileItem: ProfileItem): OutboundBean? {
        val outboundBean = V2rayConfigManager.createInitOutbound(EConfigType.SHADOWSOCKS)

        outboundBean?.settings?.servers?.first()?.let { server ->
            server.address = getServerAddress(profileItem)
            server.port = profileItem.serverPort.orEmpty().toInt()
            server.password = profileItem.password
            server.method = profileItem.method
        }

        val sni = outboundBean?.streamSettings?.let {
            V2rayConfigManager.populateTransportSettings(it, profileItem)
        }

        outboundBean?.streamSettings?.let {
            V2rayConfigManager.populateTlsSettings(it, profileItem, sni)
        }

        return outboundBean
    }
}