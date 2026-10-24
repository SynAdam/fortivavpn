package com.vpn.fortivavpn

import android.app.Activity
import android.app.Application
import android.content.Context
import android.os.Bundle
import android.view.View
import android.view.ViewGroup
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsCompat
import androidx.multidex.MultiDexApplication
import com.tencent.mmkv.MMKV
import com.vpn.fortivavpn.handler.SettingsManager
import com.vpn.fortivavpn.service.NoticeJobs
import io.flutter.embedding.android.FlutterActivity
import kotlin.math.max

class AngApplication : MultiDexApplication() {
    companion object {
        lateinit var application: AngApplication

        /**
         * Whether a screen of this class needs the keyboard padding below. A
         * Flutter screen does not: Flutter reads the keyboard height from the
         * window insets itself, and a listener set on its view replaces
         * Flutter's own. With it, Flutter never learned the keyboard was
         * open, so a text field could stay under the keyboard while Android
         * slid the whole page up, top bar included.
         */
        internal fun needsImePadding(screen: Class<out Activity>): Boolean =
            !FlutterActivity::class.java.isAssignableFrom(screen)
    }

    override fun attachBaseContext(base: Context?) {
        super.attachBaseContext(base)
        application = this
    }

    override fun onCreate() {
        super.onCreate()

        MMKV.initialize(this)

        // The checks for messages from the Fortiva team, put back after a
        // reboot or a force stop the first time any part of the app starts:
        // the app, the tunnel, the widget, the quick settings tile. Cheap
        // when they are already set.
        NoticeJobs.ensureScheduled(this)

        SettingsManager.setNightMode()
        SettingsManager.initRoutingRulesets(this)

        // Stage the geo databases now so the first connect does not pay for a
        // 26 MB copy. V2RayServiceManager stages them again before the core
        // starts; initAssets is idempotent and cheap once they are in place.
        Thread { SettingsManager.initAssets(this, assets) }.start()

        es.dmoral.toasty.Toasty.Config.getInstance()
            .setGravity(android.view.Gravity.BOTTOM, 0, 200)
            .apply()

        // Global fix: ensure content is padded above the IME (keyboard) on all screens.
        // This prevents input fields/buttons from going behind the keyboard on some devices.
        registerActivityLifecycleCallbacks(ImeInsetsLifecycleCallbacks())
    }

    private class ImeInsetsLifecycleCallbacks : Application.ActivityLifecycleCallbacks {
        override fun onActivityCreated(activity: Activity, savedInstanceState: Bundle?) {
            if (!needsImePadding(activity.javaClass)) return
            // Post to ensure setContentView() has run and views exist.
            activity.window.decorView.post {
                val target = findImePaddingTarget(activity) ?: return@post
                applyImeBottomPadding(target)
            }
        }

        private fun findImePaddingTarget(activity: Activity): View? {
            // Prefer explicit scroll containers if present.
            val pkg = activity.packageName
            val res = activity.resources

            val scrollViewId = res.getIdentifier("scrollView", "id", pkg)
            if (scrollViewId != 0) {
                activity.findViewById<View>(scrollViewId)?.let { return it }
            }

            // Common nested scroll container used in some screens.
            val mainContentId = res.getIdentifier("main_content", "id", pkg)
            if (mainContentId != 0) {
                activity.findViewById<View>(mainContentId)?.let { return it }
            }

            // Fallback: the root content view.
            val content = activity.findViewById<ViewGroup>(android.R.id.content) ?: return null
            return content.getChildAt(0) ?: content
        }

        private fun applyImeBottomPadding(target: View) {
            val initialLeft = target.paddingLeft
            val initialTop = target.paddingTop
            val initialRight = target.paddingRight
            val initialBottom = target.paddingBottom

            ViewCompat.setOnApplyWindowInsetsListener(target) { v, insets ->
                val imeInsets = insets.getInsets(WindowInsetsCompat.Type.ime())
                // Only apply IME bottom insets to avoid double-padding system bars on screens that
                // already use fitsSystemWindows / padding.
                val bottom = initialBottom + max(0, imeInsets.bottom)
                v.setPadding(initialLeft, initialTop, initialRight, bottom)
                insets
            }

            ViewCompat.requestApplyInsets(target)
        }

        override fun onActivityStarted(activity: Activity) = Unit
        override fun onActivityResumed(activity: Activity) = Unit
        override fun onActivityPaused(activity: Activity) = Unit
        override fun onActivityStopped(activity: Activity) = Unit
        override fun onActivitySaveInstanceState(activity: Activity, outState: Bundle) = Unit
        override fun onActivityDestroyed(activity: Activity) = Unit
    }
}
