package com.vpn.fortivavpn.handler

import com.google.gson.JsonObject
import com.google.gson.JsonParseException
import com.google.gson.JsonParser

/**
 * A link's `fm` parameter: a finalmask object that tells the core how to cut
 * up what it sends, for example the TLS hello into TLS records of chosen
 * lengths.
 *
 * Public channels in Iran reported that this, with fingerprint "unsafe" and
 * a chosen list of cipher suites (the link's `cs`), can get through to
 * Cloudflare where splitting the hello does not.
 *
 * A finalmask cuts the hello itself, so a link that carries one is never
 * also split by [TlsFragment]: the two would act on the same bytes.
 */
object FinalMask {
    /**
     * The object in [value], or null when there is none. Text that is not a
     * JSON object, such as a preset name, is null too: the core would not
     * read it, and a mask it does not understand must not be passed on.
     */
    fun parse(value: String?): JsonObject? {
        if (value.isNullOrBlank()) return null
        return try {
            JsonParser.parseString(value).takeIf { it.isJsonObject }?.asJsonObject
        } catch (e: JsonParseException) {
            null
        }
    }
}
