package com.vpn.fortivavpn.handler

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.ComponentName
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ResolveInfo
import android.os.Build
import android.os.Parcelable
import android.util.Log

/**
 * Sends an invite from the invite card or the invite screen.
 *
 * Fortiva never uses a government platform (decided 2026-10-13), so the share
 * sheet hides every share activity of the packages it is given: the state
 * messengers in the backend's INVITE_SHARE_EXCLUDE_PACKAGES, or the app's
 * own copy of that list. EXTRA_EXCLUDE_COMPONENTS needs Android 7, which is
 * the app's minimum. Finding those activities needs the SEND text/plain
 * entry in the manifest's <queries>, which is not a permission. Nothing
 * about the other apps leaves the phone.
 */
object InviteShare {
    private const val TAG = "InviteShare"

    private val TELEGRAM = listOf("org.telegram.messenger", "org.telegram.messenger.web")
    private val WHATSAPP = listOf("com.whatsapp", "com.whatsapp.w4b")

    /**
     * Opens [target] ("telegram", "whatsapp" or "sheet") with [text]. A
     * messenger that is not installed falls back to the share sheet.
     * Returns "app" when a messenger opened, "sheet" when the system share
     * sheet opened, "none" otherwise.
     */
    fun share(activity: Activity, text: String, target: String, exclude: List<String>, title: String?): String {
        val direct = when (target) {
            "telegram" -> TELEGRAM
            "whatsapp" -> WHATSAPP
            else -> emptyList()
        }
        for (pkg in direct) {
            try {
                activity.startActivity(sendIntent(text).setPackage(pkg))
                return "app"
            } catch (e: ActivityNotFoundException) {
                // Not installed: the next package, then the sheet.
            } catch (e: Exception) {
                Log.w(TAG, "could not open $pkg: ${e.javaClass.simpleName}")
            }
        }
        return try {
            val send = sendIntent(text)
            val chooser = Intent.createChooser(send, title)
            val hidden = excludedNames(shareActivities(activity, send), exclude)
                .map { (pkg, cls) -> ComponentName(pkg, cls) }
            if (hidden.isNotEmpty()) {
                chooser.putExtra(Intent.EXTRA_EXCLUDE_COMPONENTS, hidden.toTypedArray<Parcelable>())
            }
            activity.startActivity(chooser)
            "sheet"
        } catch (e: Exception) {
            Log.w(TAG, "could not open the share sheet: ${e.javaClass.simpleName}")
            "none"
        }
    }

    /**
     * The (package, class) pairs among [activities] whose package is in
     * [exclude], for EXTRA_EXCLUDE_COMPONENTS. Package names are compared
     * exactly, because Android's are case sensitive (net.iGap). Pure Kotlin
     * over plain pairs, so a JVM unit test can call it: the app has no
     * Robolectric and no unitTests.isReturnDefaultValues, so ActivityInfo()
     * and ComponentName(...) throw "Method ... not mocked" in a unit test.
     */
    fun excludedNames(
        activities: List<Pair<String, String>>,
        exclude: Collection<String>,
    ): List<Pair<String, String>> {
        if (exclude.isEmpty()) return emptyList()
        val packages = exclude.toSet()
        return activities.filter { (pkg, _) -> pkg in packages }
    }

    private fun sendIntent(text: String): Intent =
        Intent(Intent.ACTION_SEND).setType("text/plain").putExtra(Intent.EXTRA_TEXT, text)

    /** Every activity that takes [send], as (package, class) pairs. */
    private fun shareActivities(activity: Activity, send: Intent): List<Pair<String, String>> {
        val pm = activity.packageManager
        val found: List<ResolveInfo> = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            pm.queryIntentActivities(send, PackageManager.ResolveInfoFlags.of(0))
        } else {
            @Suppress("DEPRECATION")
            pm.queryIntentActivities(send, 0)
        }
        return found.mapNotNull { info ->
            val a = info.activityInfo ?: return@mapNotNull null
            a.packageName to a.name
        }
    }
}
