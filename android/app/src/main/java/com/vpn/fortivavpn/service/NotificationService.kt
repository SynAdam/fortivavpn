package com.vpn.fortivavpn.service

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.pm.ServiceInfo
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.os.Build
import android.util.Log
import androidx.annotation.RequiresApi
import androidx.annotation.StringRes
import androidx.core.app.NotificationCompat
import com.vpn.fortivavpn.AppConfig
import com.vpn.fortivavpn.AppConfig.ANG_PACKAGE
import com.vpn.fortivavpn.R
import com.vpn.fortivavpn.dto.ProfileItem
import com.vpn.fortivavpn.MainActivity

object NotificationService {
    private const val NOTIFICATION_ID = 1
    private const val NOTIFICATION_PENDING_INTENT_CONTENT = 0
    private const val NOTIFICATION_PENDING_INTENT_STOP_V2RAY = 1
    private const val NOTIFICATION_PENDING_INTENT_RESTART_V2RAY = 2

    /** The file of the two texts Flutter saves in the app's language, and
     * their keys (NotificationTexts in Dart). */
    private const val TEXTS_FILE = "notification_texts"
    private const val CONNECTING_KEY = "connecting"
    private const val STOP_KEY = "stop"

    private var mBuilder: NotificationCompat.Builder? = null
    private var mNotificationManager: NotificationManager? = null

    /**
     * Shows a minimal "starting/connecting" notification ASAP.
     *
     * This is important because Android requires that a service started with
     * Context.startForegroundService() calls Service.startForeground() quickly.
     */
    fun showStartingNotification(service: Service) {
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }

        val startMainIntent = Intent(service, MainActivity::class.java)
        val contentPendingIntent =
            PendingIntent.getActivity(service, NOTIFICATION_PENDING_INTENT_CONTENT, startMainIntent, flags)

        val channelId =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                createNotificationChannel(service)
            } else {
                ""
            }

        mBuilder = NotificationCompat.Builder(service, channelId)
            .setSmallIcon(R.drawable.fortiva)
            .setContentTitle(service.getString(R.string.app_name))
            .setContentText(textInAppLanguage(service, CONNECTING_KEY, R.string.status_connecting))
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .setShowWhen(false)
            .setOnlyAlertOnce(true)
            .setContentIntent(contentPendingIntent)

        startForegroundCompat(service, mBuilder?.build())
    }

    /**
     * Shows the notification.
     * @param currentConfig The current profile configuration.
     */
    fun showNotification(service: Service, currentConfig: ProfileItem?) {
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }

        val startMainIntent = Intent(service, MainActivity::class.java)
        val contentPendingIntent = PendingIntent.getActivity(service, NOTIFICATION_PENDING_INTENT_CONTENT, startMainIntent, flags)

        val stopV2RayIntent = Intent(AppConfig.BROADCAST_ACTION_SERVICE)
        stopV2RayIntent.`package` = ANG_PACKAGE
        stopV2RayIntent.putExtra("key", AppConfig.MSG_STATE_STOP)
        val stopV2RayPendingIntent = PendingIntent.getBroadcast(service, NOTIFICATION_PENDING_INTENT_STOP_V2RAY, stopV2RayIntent, flags)

        val restartV2RayIntent = Intent(AppConfig.BROADCAST_ACTION_SERVICE)
        restartV2RayIntent.`package` = ANG_PACKAGE
        restartV2RayIntent.putExtra("key", AppConfig.MSG_STATE_RESTART)
        val restartV2RayPendingIntent = PendingIntent.getBroadcast(service, NOTIFICATION_PENDING_INTENT_RESTART_V2RAY, restartV2RayIntent, flags)

        val channelId =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                createNotificationChannel(service)
            } else {
                // If earlier version channel ID is not used
                // https://developer.android.com/reference/android/support/v4/app/NotificationCompat.Builder.html#NotificationCompat.Builder(android.content.Context)
                ""
            }

        mBuilder = NotificationCompat.Builder(service, channelId)
            .setSmallIcon(R.drawable.fortiva)
            // The app's name, never the link's label: for a community link
            // the label is whatever its poster wrote, and the shade is public.
            .setContentTitle(service.getString(R.string.app_name))
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .setShowWhen(false)
            .setOnlyAlertOnce(true)
            .setContentIntent(contentPendingIntent)
            .addAction(
                R.drawable.fortiva,
                textInAppLanguage(service, STOP_KEY, R.string.notification_action_stop_v2ray),
                stopV2RayPendingIntent
            )

        //mBuilder?.setDefaults(NotificationCompat.FLAG_ONLY_ALERT_ONCE)

        startForegroundCompat(service, mBuilder?.build())
    }

    /**
     * A text in the language the person chose in the app, as Flutter saved it
     * in [key], or the English one in res/values when nothing is saved.
     *
     * Android's resources cannot give this. The services run with the phone's
     * language, and a Play install holds only the phone's language splits.
     *
     * The services run in the tunnel's process and Flutter saves in the main
     * process. A plain read would keep what this process read first, so a
     * language changed later would never show. MODE_MULTI_PROCESS reads the
     * file again when it has changed.
     *
     * The texts have a small file of their own, and this process must never
     * open FlutterSharedPreferences. Opening a preferences file puts its backup
     * back over the file when a backup exists, and one exists while the main
     * process is saving, so that open would undo the save. Here the worst case
     * is these two texts in the language before, until the app's next start.
     *
     * Never throws: the foreground service has to start, whatever the file holds.
     */
    @Suppress("DEPRECATION")
    private fun textInAppLanguage(service: Service, key: String, @StringRes fallback: Int): String {
        val saved = try {
            service.getSharedPreferences(TEXTS_FILE, Context.MODE_MULTI_PROCESS).getString(key, null)
        } catch (t: Throwable) {
            Log.w(AppConfig.TAG, "[notification] the saved text could not be read", t)
            null
        }
        return if (saved.isNullOrBlank()) service.getString(fallback) else saved
    }

    /**
     * Backwards-compatible foreground start helper.
     *
     * On newer Android versions, specifying the service type improves compliance
     * with foreground service requirements (VPN is specialUse subtype "vpn").
     */
    private fun startForegroundCompat(service: Service, notification: Notification?) {
        if (notification == null) return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            service.startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        } else {
            service.startForeground(NOTIFICATION_ID, notification)
        }
    }

    /**
     * Cancels the notification.
     */
    fun cancelNotification(service: Service) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            service.stopForeground(Service.STOP_FOREGROUND_REMOVE)
        } else {
            service.stopForeground(true)
        }

        mBuilder = null
        mNotificationManager = null
    }

    /**
     * Creates a notification channel for Android O and above.
     * @return The channel ID.
     */
    @RequiresApi(Build.VERSION_CODES.O)
    private fun createNotificationChannel(service: Service): String {
        val channelId = AppConfig.RAY_NG_CHANNEL_ID
        val channelName = AppConfig.RAY_NG_CHANNEL_NAME
        val chan = NotificationChannel(
            channelId,
            channelName,
            NotificationManager.IMPORTANCE_LOW
        )
        chan.lightColor = Color.DKGRAY
        chan.lockscreenVisibility = Notification.VISIBILITY_PRIVATE
        getNotificationManager(service)?.createNotificationChannel(chan)
        return channelId
    }

    /**
     * Gets the notification manager.
     * @return The notification manager.
     */
    private fun getNotificationManager(service: Service): NotificationManager? {
        if (mNotificationManager == null) {
            mNotificationManager = service.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        }
        return mNotificationManager
    }

    /**
     * Gets the service instance.
     * @return The service instance.
     */
    private fun getService(): Service? {
        return V2RayServiceManager.serviceControl?.get()?.getService()
    }
}