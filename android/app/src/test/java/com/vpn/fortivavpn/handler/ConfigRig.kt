package com.vpn.fortivavpn.handler

import android.content.Context
import android.text.TextUtils
import android.util.Log
import com.tencent.mmkv.MMKV
import com.vpn.fortivavpn.dto.ProfileItem
import com.vpn.fortivavpn.fmt.VlessFmt
import org.mockito.MockedStatic
import org.mockito.Mockito
import org.mockito.invocation.InvocationOnMock
import java.io.File
import java.nio.file.Files
import java.security.MessageDigest

/**
 * Builds the tunnel's core configs on the JVM, the way the tunnel's process
 * builds them on the phone (V2rayConfigManager), so a test can compare them.
 *
 * MMKV is a native store, so every MMKV the app opens is a map here that
 * answers with the default the caller passes, as an empty store does. The
 * config template is the app's own (assets/v2ray_config.json), and the geo
 * databases are present, as on a phone after the first start.
 */
internal class ConfigRig : AutoCloseable {
    private val statics: List<MockedStatic<*>> = listOf(
        Mockito.mockStatic(MMKV::class.java) { inv ->
            if (inv.method.returnType == MMKV::class.java) fake(inv.arguments[0] as String)
            else Mockito.RETURNS_DEFAULTS.answer(inv)
        },
        Mockito.mockStatic(Log::class.java),
        Mockito.mockStatic(TextUtils::class.java) { inv ->
            if (inv.method.name == "isEmpty") (inv.arguments[0] as CharSequence?).isNullOrEmpty()
            else Mockito.RETURNS_DEFAULTS.answer(inv)
        },
    )

    private val assets: File = Files.createTempDirectory("geo").toFile().apply {
        File(this, "geosite.dat").writeText("geosite")
        File(this, "geoip.dat").writeText("geoip")
    }

    val context: Context = Mockito.mock(Context::class.java).also {
        Mockito.`when`(it.getExternalFilesDir(Mockito.anyString())).thenReturn(assets)
    }

    init {
        stores.values.forEach { it.clear() }
        V2rayConfigManager::class.java.getDeclaredField("initConfigCache").apply {
            isAccessible = true
            set(null, File("src/main/assets/v2ray_config.json").readText())
        }
    }

    /** Stores [link] as the door [guid], as a connect imports it. */
    fun door(guid: String, link: String): ProfileItem {
        val profile = checkNotNull(VlessFmt.parse(link)) { "the link did not parse" }
        MmkvManager.encodeServerConfig(guid, profile)
        return profile
    }

    override fun close() {
        statics.forEach { it.close() }
        assets.deleteRecursively()
    }

    companion object {
        private val stores = HashMap<String, HashMap<String, Any?>>()

        private fun fake(id: String): MMKV = Mockito.mock(MMKV::class.java) { inv ->
            answer(stores.getOrPut(id) { HashMap() }, inv)
        }

        private fun answer(store: HashMap<String, Any?>, inv: InvocationOnMock): Any? {
            val a = inv.arguments
            return when (inv.method.name) {
                "encode" -> {
                    val key = a[0] as String
                    if (a[1] == null) store.remove(key) else store[key] = a[1]
                    true
                }
                "decodeString" -> store[a[0]] as? String ?: a.getOrNull(1)
                "decodeBool" -> store[a[0]] as? Boolean ?: a.getOrNull(1) ?: false
                "decodeInt" -> store[a[0]] as? Int ?: a.getOrNull(1) ?: 0
                "decodeLong" -> store[a[0]] as? Long ?: a.getOrNull(1) ?: 0L
                "decodeStringSet" -> store[a[0]] ?: a.getOrNull(1)
                "containsKey" -> store.containsKey(a[0])
                "allKeys" -> store.keys.toTypedArray()
                "removeValueForKey" -> store.remove(a[0]).let { null }
                "clearAll" -> store.clear().let { null }
                else -> Mockito.RETURNS_DEFAULTS.answer(inv)
            }
        }

        fun sha256(text: String): String =
            MessageDigest.getInstance("SHA-256").digest(text.toByteArray())
                .joinToString("") { "%02x".format(it) }
    }
}
