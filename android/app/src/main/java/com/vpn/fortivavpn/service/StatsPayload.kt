package com.vpn.fortivavpn.service

import com.google.gson.JsonElement
import com.google.gson.JsonObject
import com.google.gson.JsonParser

/**
 * The traffic answer the tunnel's process sends the app (MSG_STATS_UPDATE),
 * and how the app reads it back. Both ends ship in the same APK.
 *
 * Without the session readings it is the text it has always been:
 * `up,down`, or `up,down,door_index,<door status JSON>` when the core holds
 * several doors. The JSON goes last because it holds commas of its own.
 *
 * With them it is one JSON object, which starts with `{`:
 * `{"up":..,"down":..,"door_index":..|null,"door_status":"<the same JSON
 * text>"|null,"session":{..}|null}`. See SessionMeter.report for the
 * session block.
 *
 * During a backup network session (PsiphonSession), once the library has
 * said which country its server is in, the object also carries
 * `"psiphon_region":"<two capital letters>"`, and once it has said it has a
 * newer client version, `"psiphon_upgrade":"<a whole number>"`. The answer
 * is then JSON even without the session readings, because the text form
 * has no place for either.
 */
object StatsPayload {
    fun encode(
        report: SessionMeter.Report,
        doorIndex: Int?,
        doorStatus: String?,
        psiphonRegion: String? = null,
        psiphonUpgrade: String? = null,
    ): String = json(report.up, report.down, doorIndex, doorStatus, report.session, psiphonRegion, psiphonUpgrade)

    /**
     * The answer without the session readings: the text form, or JSON when
     * there is a backup network region or upgrade to carry.
     */
    fun encodePlain(
        up: Long,
        down: Long,
        doorIndex: Int?,
        doorStatus: String?,
        psiphonRegion: String? = null,
        psiphonUpgrade: String? = null,
    ): String {
        if (region(psiphonRegion) != null || upgrade(psiphonUpgrade) != null) {
            return json(up, down, doorIndex, doorStatus, null, psiphonRegion, psiphonUpgrade)
        }
        return if (doorIndex == null || doorStatus == null) "$up,$down" else "$up,$down,$doorIndex,$doorStatus"
    }

    private fun json(
        up: Long,
        down: Long,
        doorIndex: Int?,
        doorStatus: String?,
        session: JsonObject?,
        psiphonRegion: String?,
        psiphonUpgrade: String?,
    ): String = JsonObject().apply {
        addProperty("up", up)
        addProperty("down", down)
        addProperty("door_index", doorIndex)
        addProperty("door_status", doorStatus)
        add("session", session)
        region(psiphonRegion)?.let { addProperty(PSIPHON_REGION, it) }
        upgrade(psiphonUpgrade)?.let { addProperty(PSIPHON_UPGRADE, it) }
    }.toString()

    private const val PSIPHON_REGION = "psiphon_region"
    private const val PSIPHON_UPGRADE = "psiphon_upgrade"
    private val REGION = Regex("^[A-Z]{2}$")

    /** [value] when it is two capital letters, as a region must be. */
    private fun region(value: String?): String? = value?.takeIf { REGION.matches(it) }

    /** [value] when it is a client version (PsiphonNotices.VERSION). */
    private fun upgrade(value: String?): String? = value?.takeIf { PsiphonNotices.VERSION.matches(it) }

    /**
     * What the app's Flutter side is handed: `bytes_up`, `bytes_down`, and
     * when the core holds several doors the position of the one in use in
     * the order the app sent them (`door_index`) and what the group knows
     * about every door (`door_status`, JSON for the app to read), the
     * session block (`session`) when the heartbeat asked for one, and the
     * backup network server's country (`psiphon_region`) and the newer
     * client version it named (`psiphon_upgrade`) when there are any.
     *
     * Null for a missing or malformed payload rather than zero bytes: a beat
     * that reports zero says the tunnel carried nothing, which is a finding,
     * and it must never be made out of a lost message.
     */
    fun parse(payload: String?): Map<String, Any?>? {
        val text = payload ?: return null
        return if (text.trimStart().startsWith("{")) parseJson(text) else parseText(text)
    }

    private fun parseText(text: String): Map<String, Any?>? {
        val parts = text.split(",", limit = 4)
        val up = parts.getOrNull(0)?.trim()?.toLongOrNull() ?: return null
        val down = parts.getOrNull(1)?.trim()?.toLongOrNull() ?: return null
        val door = parts.getOrNull(2)?.trim()?.toIntOrNull()
        val status = parts.getOrNull(3)?.takeIf { it.isNotBlank() }
        return answer(up, down, door, status, null, null, null)
    }

    private fun parseJson(text: String): Map<String, Any?>? {
        val root = try {
            JsonParser.parseString(text)
        } catch (e: Exception) {
            return null
        }
        if (!root.isJsonObject) return null
        val obj = root.asJsonObject
        val up = whole(obj.get("up")) ?: return null
        val down = whole(obj.get("down")) ?: return null
        val door = whole(obj.get("door_index"))?.toInt()
        val status = obj.get("door_status")
            ?.takeIf { it.isJsonPrimitive && it.asJsonPrimitive.isString }
            ?.asString
            ?.takeIf { it.isNotBlank() }
        val session = obj.get("session")?.takeIf { it.isJsonObject }?.let { plain(it) }
        val region = obj.get(PSIPHON_REGION)
            ?.takeIf { it.isJsonPrimitive && it.asJsonPrimitive.isString }
            ?.let { region(it.asString) }
        val upgrade = obj.get(PSIPHON_UPGRADE)
            ?.takeIf { it.isJsonPrimitive && it.asJsonPrimitive.isString }
            ?.let { upgrade(it.asString) }
        return answer(up, down, door, status, session, region, upgrade)
    }

    private fun answer(
        up: Long,
        down: Long,
        door: Int?,
        status: String?,
        session: Any?,
        psiphonRegion: String?,
        psiphonUpgrade: String?,
    ): Map<String, Any?> =
        buildMap {
            put("bytes_up", up)
            put("bytes_down", down)
            if (door != null) put("door_index", door)
            if (door != null && status != null) put("door_status", status)
            if (session != null) put("session", session)
            if (psiphonRegion != null) put(PSIPHON_REGION, psiphonRegion)
            if (psiphonUpgrade != null) put(PSIPHON_UPGRADE, psiphonUpgrade)
        }

    private fun whole(element: JsonElement?): Long? {
        if (element == null || !element.isJsonPrimitive) return null
        val primitive = element.asJsonPrimitive
        if (!primitive.isNumber) return null
        return primitive.asString.toLongOrNull()
    }

    /**
     * [element] as the maps, lists, numbers and text the method channel
     * carries. Whole numbers become Long, others Double.
     */
    private fun plain(element: JsonElement): Any? = when {
        element.isJsonNull -> null
        element.isJsonObject -> element.asJsonObject.entrySet().associate { (k, v) -> k to plain(v) }
        element.isJsonArray -> element.asJsonArray.map { plain(it) }
        else -> {
            val primitive = element.asJsonPrimitive
            when {
                primitive.isBoolean -> primitive.asBoolean
                primitive.isNumber -> primitive.asString.let { it.toLongOrNull() ?: it.toDoubleOrNull() }
                else -> primitive.asString
            }
        }
    }
}
