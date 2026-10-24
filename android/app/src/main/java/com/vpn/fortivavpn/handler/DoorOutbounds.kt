package com.vpn.fortivavpn.handler

import android.util.Log
import com.google.gson.GsonBuilder
import com.google.gson.JsonArray
import com.google.gson.JsonElement
import com.google.gson.JsonObject
import com.google.gson.JsonParser
import com.vpn.fortivavpn.AppConfig
import com.vpn.fortivavpn.dto.ConfigResult
import com.vpn.fortivavpn.dto.V2rayConfig.OutboundBean
import com.vpn.fortivavpn.util.JsonUtil

/**
 * A door's outbound as the backend wrote it: the `outbound` of a door entry
 * in the /configs/dedicated answer and its `helper_outbounds`, such as the
 * splitter tagged `fragment` it dials through.
 */
class DoorOutbound(val outbound: JsonObject, val helpers: List<JsonObject>)

/**
 * The backend's outbounds for the phone's doors (variant loop contract v2,
 * section 2). With one, the backend can serve any protocol and setting the
 * core supports without an app release.
 *
 * A door that has one is dialled with it wherever the app builds an
 * outbound from that door's link: the tunnel's config, the doors that stand
 * by in it, and door checks. The backend's JSON goes to the core as it
 * came, so a setting the app's own types do not know is kept. Its helpers
 * take the place of the split the link asks for. The rest of the config is
 * the app's, built as before.
 *
 * A door without one is dialled from its link, exactly as before: nothing
 * here runs. An outbound the app cannot use (not an object, no tag or no
 * protocol, a helper that takes one of the app's own tags) is logged and
 * the link is dialled. A config the outbounds cannot be put into is built
 * again from the links ([finish]). A config the core will not start with
 * the backend's outbounds is started again from the links (CoreStart), and
 * a door check whose core never started the outbound checks the link
 * ([notStarted], MainActivity).
 *
 * The app hands the outbounds over with the connect, as JSON text, one per
 * door ([encode]). The tunnel's process reads them back by the door's guid
 * ([forGuid]).
 */
object DoorOutbounds {
    private const val TAG = AppConfig.TAG

    private val GSON = GsonBuilder().setPrettyPrinting().disableHtmlEscaping().create()

    /**
     * The door outbound in [json], the app's
     * `{"outbound": {...}, "helper_outbounds": [...]}` for one door, or null
     * when there is none or it cannot be used.
     */
    fun parse(json: String?): DoorOutbound? {
        if (json.isNullOrBlank()) return null
        val root = try {
            JsonParser.parseString(json)
        } catch (e: Exception) {
            return unusable("it is not JSON")
        }
        if (!root.isJsonObject) return unusable("it is not an object")
        val outbound = root.asJsonObject.get("outbound")
        if (outbound == null || !outbound.isJsonObject) return unusable("it has no outbound object")
        if (!named(outbound.asJsonObject)) return unusable("the outbound has no tag or protocol")
        val helpers = mutableListOf<JsonObject>()
        val list = root.asJsonObject.get("helper_outbounds")
        if (list != null && !list.isJsonNull) {
            if (!list.isJsonArray) return unusable("helper_outbounds is not a list")
            for (helper in list.asJsonArray) {
                if (!helper.isJsonObject || !named(helper.asJsonObject)) {
                    return unusable("a helper has no tag or protocol")
                }
                // The app's own tags. A helper under one would stand in for
                // a door, or for the app's direct, block or DNS outbound.
                if (reserved(tagOf(helper)!!)) return unusable("a helper takes one of the app's tags")
                if (helpers.any { tagOf(it) == tagOf(helper) }) return unusable("two helpers share a tag")
                helpers.add(helper.asJsonObject)
            }
        }
        return DoorOutbound(outbound.asJsonObject, helpers)
    }

    private fun unusable(why: String): DoorOutbound? {
        Log.w(TAG, "[doors] the backend's door outbound cannot be used ($why); the link is dialled")
        return null
    }

    private fun named(o: JsonObject): Boolean = text(o, "tag") != null && text(o, "protocol") != null

    private fun text(o: JsonObject?, key: String): String? =
        o?.get(key)?.takeIf { it.isJsonPrimitive && it.asJsonPrimitive.isString }?.asString?.takeIf { it.isNotBlank() }

    private fun tagOf(e: JsonElement?): String? = if (e != null && e.isJsonObject) text(e.asJsonObject, "tag") else null

    private fun reserved(tag: String): Boolean =
        tag == AppConfig.TAG_PROXY ||
            tag.startsWith("${AppConfig.TAG_PROXY}@") ||
            tag == AppConfig.TAG_DIRECT ||
            tag == AppConfig.TAG_BLOCKED ||
            tag == V2rayConfigManager.TAG_DNS_OUT

    /**
     * What PREF_DOOR_OUTBOUNDS holds for a connect whose doors are [guids],
     * in the order the app sent them, with [entries] what the app sent for
     * each in the same order ("" for none). Empty when no door has one it
     * can use.
     */
    fun encode(guids: List<String>, entries: List<String>): String {
        val out = JsonObject()
        guids.forEachIndexed { i, guid ->
            val entry = entries.getOrNull(i)
            if (guid.isNotBlank() && !entry.isNullOrBlank() && parse(entry) != null) out.addProperty(guid, entry)
        }
        return if (out.size() == 0) "" else out.toString()
    }

    /** The outbound [stored] (PREF_DOOR_OUTBOUNDS) holds for [guid], or null. */
    fun of(stored: String?, guid: String): DoorOutbound? {
        if (stored.isNullOrBlank() || guid.isBlank()) return null
        val entry = try {
            JsonParser.parseString(stored).asJsonObject.get(guid)
        } catch (e: Exception) {
            null
        }
        if (entry == null || !entry.isJsonPrimitive) return null
        return parse(entry.asString)
    }

    /** The outbound the last connect gave the door [guid], or null. */
    fun forGuid(guid: String): DoorOutbound? =
        of(MmkvManager.decodeSettingsString(AppConfig.PREF_DOOR_OUTBOUNDS), guid)

    /**
     * Puts [door] in the place of the outbound tagged [tag], which the app
     * built from the door's link: records it in [swaps] under that tag, and
     * holds a place in [outbounds] for each of its helpers whose tag the
     * config does not have yet. [swap] puts the backend's JSON in those
     * places once the config is written.
     *
     * A helper whose tag is there already is left out. The doors of a group
     * share one splitter, as they do for the split their links ask for, so
     * the first door that brings one decides it.
     */
    fun stage(
        door: DoorOutbound,
        tag: String,
        outbounds: MutableList<OutboundBean>,
        swaps: MutableMap<String, JsonObject>,
    ) {
        swaps[tag] = door.outbound
        for (helper in door.helpers) {
            val name = tagOf(helper) ?: continue
            if (swaps.containsKey(name) || outbounds.any { it.tag == name }) continue
            outbounds.add(OutboundBean(tag = name, protocol = AppConfig.PROTOCOL_FREEDOM, mux = null))
            swaps[name] = helper
        }
    }

    /**
     * [built], a config the app built with [swaps] staged in it ([stage]),
     * with the backend's JSON put in those places ([swap]) and marked as
     * dialling it. When it cannot be put in, the config [fromLinks] builds
     * from the links alone is returned in its place. Without swaps, [built]
     * is returned as it is.
     */
    fun finish(built: ConfigResult, swaps: Map<String, JsonObject>, fromLinks: () -> ConfigResult): ConfigResult {
        if (swaps.isEmpty()) return built
        val content = swap(built.content, swaps)
        if (content == null) {
            Log.w(TAG, "[doors] the backend's door outbounds could not be put in the config; built from the links")
            return fromLinks()
        }
        built.content = content
        built.doorOutbounds = true
        return built
    }

    /**
     * [config], the JSON the app built, with the outbound under each tag in
     * [swaps] replaced by the backend's JSON for it, under that tag. Null
     * when the config cannot be read or a tag is not there exactly once:
     * the caller then builds the config from the links alone.
     */
    fun swap(config: String, swaps: Map<String, JsonObject>): String? {
        if (swaps.isEmpty()) return config
        return try {
            val root = JsonParser.parseString(config).asJsonObject
            val outbounds = root.getAsJsonArray("outbounds")
            for ((tag, raw) in swaps) {
                val at = (0 until outbounds.size()).filter { tagOf(outbounds[it]) == tag }
                if (at.size != 1) return null
                val built = outbounds[at[0]].asJsonObject
                val backend = raw.deepCopy()
                backend.addProperty("tag", tag)
                keepResolution(built, backend)
                outbounds.set(at[0], backend)
            }
            GSON.toJson(root)
        } catch (e: Exception) {
            Log.w(TAG, "[doors] the backend's door outbounds could not be put in the config", e)
            null
        }
    }

    /**
     * The app looks up a door's host before the core starts
     * (resolveOutboundDomainsToHosts in V2rayConfigManager): the answer goes
     * into the config's DNS hosts, and the door's outbound gets a
     * domainStrategy that makes the core use it. The backend's outbound for
     * the same address keeps that, unless it names a domainStrategy itself.
     */
    private fun keepResolution(built: JsonObject, backend: JsonObject) {
        val strategy = obj(obj(built, "streamSettings"), "sockopt")?.get("domainStrategy") ?: return
        val address = endpoint(built)?.first ?: return
        if (endpoint(backend)?.first != address) return
        if (backend.has("streamSettings") && obj(backend, "streamSettings") == null) return
        val stream = obj(backend, "streamSettings") ?: JsonObject().also { backend.add("streamSettings", it) }
        if (stream.has("sockopt") && obj(stream, "sockopt") == null) return
        val sockopt = obj(stream, "sockopt") ?: JsonObject().also { stream.add("sockopt", it) }
        if (!sockopt.has("domainStrategy")) sockopt.add("domainStrategy", strategy.deepCopy())
    }

    /** The object under [key] in [o], or null when there is none. */
    private fun obj(o: JsonObject?, key: String): JsonObject? =
        o?.get(key)?.takeIf { it.isJsonObject }?.asJsonObject

    /**
     * The address and port [outbound] dials, when it names them the way
     * VLESS, VMess, Trojan and Shadowsocks outbounds do (`vnext` or
     * `servers`), or null. A door check opens a plain TCP connection to
     * them beside the check (DoorCheck).
     */
    fun endpoint(outbound: JsonObject): Pair<String, Int>? {
        val settings = obj(outbound, "settings") ?: return null
        for (key in listOf("vnext", "servers")) {
            val first = settings.get(key)?.takeIf { it.isJsonArray }?.asJsonArray?.firstOrNull()
            if (first == null || !first.isJsonObject) continue
            val address = text(first.asJsonObject, "address") ?: return null
            val port = first.asJsonObject.get("port")?.takeIf { it.isJsonPrimitive }?.asJsonPrimitive
                ?.takeIf { it.isNumber }?.asInt ?: return null
            return address to port
        }
        return null
    }

    /**
     * The config a door check of [door] runs with: the backend's outbound
     * as "proxy", without mux, then its helpers, as TestLink.config builds
     * one from a link. The splitter the app sends with every test is added
     * when no outbound is tagged fragment, for the reason TestLink.config
     * gives.
     */
    fun testConfig(door: DoorOutbound, splitter: TlsFragment.Spec?): String {
        val outbounds = JsonArray()
        outbounds.add(
            door.outbound.deepCopy().apply {
                addProperty("tag", AppConfig.TAG_PROXY)
                remove("mux")
            },
        )
        door.helpers.forEach { outbounds.add(it.deepCopy()) }
        addSplitter(outbounds, splitter)
        val root = JsonObject()
        root.add("outbounds", outbounds)
        root.add("log", JsonObject().apply { addProperty("loglevel", "none") })
        return GSON.toJson(root)
    }

    /**
     * What the core's error starts with when it never started a check's
     * config: it could not load it, build a core from it or start that core
     * (startCheckCore in android/core/fortivacore, MeasureOutboundDelay in
     * libv2ray), or the timed check panicked (CheckDoorTimed). The Go test
     * TestAConfigTheCoreRefusesSaysItNeverStarted holds the core to them.
     */
    private val NOT_STARTED = listOf("config load error:", "instance creation failed:", "startup failed:", "panic:")

    /**
     * Whether the plain door check never started the core with its config,
     * from [error], what the core said, before DoorCheck.shorten cuts its
     * start off. A door check of the backend's outbound is then made again
     * from the door's link, as the tunnel then starts from it (contract v2,
     * section 2).
     */
    fun notStarted(error: String?): Boolean {
        val text = error?.trimStart() ?: return false
        return NOT_STARTED.any { text.startsWith(it) }
    }

    /**
     * [notStarted] for the timed check's [json] (DoorChecks.check): closed,
     * no phase, nothing dialled, and one of those errors. CheckDoorTimed
     * answers so when startCheckCore fails.
     */
    fun notStartedTimed(json: String?): Boolean {
        if (json.isNullOrBlank()) return false
        val o = try {
            JsonParser.parseString(json).takeIf { it.isJsonObject }?.asJsonObject
        } catch (e: Exception) {
            null
        } ?: return false
        val ms = number(o, "ms") ?: return false
        if (ms >= 0 || text(o, "phase") != null || o.has("dial_ms")) return false
        if (o.has("dials") && number(o, "dials") != 0L) return false
        return notStarted(text(o, "error"))
    }

    private fun number(o: JsonObject, key: String): Long? =
        o.get(key)?.takeIf { it.isJsonPrimitive && it.asJsonPrimitive.isNumber }?.asLong

    /**
     * A variant test's [config] as the door check runs it (contract v2,
     * section 1), or null when it is not one the check can run: a JSON
     * object whose first outbound is tagged proxy and names a protocol.
     *
     * The check dials it as the backend wrote it. Two things are added when
     * the config leaves them out, and the outbound tagged proxy dials
     * through neither: the splitter the app sends with every test, when no
     * outbound is tagged fragment or dials through one (TestLink.config says
     * why every test's core carries it), and a log level of none, as every
     * other test's config has.
     */
    fun checkConfig(config: String?, splitter: TlsFragment.Spec?): String? {
        if (config.isNullOrBlank()) return null
        val root = try {
            JsonParser.parseString(config)
        } catch (e: Exception) {
            return null
        }
        if (!root.isJsonObject) return null
        val copy = root.asJsonObject.deepCopy()
        val outbounds = copy.get("outbounds")?.takeIf { it.isJsonArray }?.asJsonArray ?: return null
        val first = outbounds.firstOrNull()?.takeIf { it.isJsonObject }?.asJsonObject ?: return null
        if (text(first, "tag") != AppConfig.TAG_PROXY || text(first, "protocol") == null) return null
        val dialsThroughOne = outbounds.any { o ->
            o.isJsonObject &&
                text(obj(obj(o.asJsonObject, "streamSettings"), "sockopt"), "dialerProxy") == AppConfig.TAG_FRAGMENT
        }
        if (!dialsThroughOne) addSplitter(outbounds, splitter)
        if (!copy.has("log")) copy.add("log", JsonObject().apply { addProperty("loglevel", "none") })
        return GSON.toJson(copy)
    }

    /**
     * Adds the splitter of [spec] to [outbounds] when there is one and no
     * outbound is tagged fragment, built as TlsFragment.addSplitter builds
     * it for a link's test.
     */
    private fun addSplitter(outbounds: JsonArray, spec: TlsFragment.Spec?) {
        if (spec == null || outbounds.any { tagOf(it) == AppConfig.TAG_FRAGMENT }) return
        val built = mutableListOf<OutboundBean>()
        TlsFragment.addSplitter(built, spec)
        outbounds.add(JsonParser.parseString(JsonUtil.toJsonPretty(built.single()) ?: return))
    }
}
