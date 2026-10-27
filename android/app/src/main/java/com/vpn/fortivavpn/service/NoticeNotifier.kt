package com.vpn.fortivavpn.service

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.telephony.TelephonyManager
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import com.vpn.fortivavpn.MainActivity
import com.vpn.fortivavpn.R

/**
 * Messages from the Fortiva team as notifications in the shade.
 *
 * They go on their own channel, apart from the tunnel's, so a user who
 * turns these off in the system settings keeps the tunnel's notification,
 * and the other way round. Tapping one opens the app on that message (see
 * [EXTRA_NOTICE_ID] in MainActivity). The Dart side decides what to show
 * and when (lib/services/notice_pull.dart); this only draws it.
 */
object NoticeNotifier {
    private const val TAG = "FortivaNotices"

    const val CHANNEL_ID = "fortiva_messages"

    /** The message id a tapped notification carries to MainActivity. */
    const val EXTRA_NOTICE_ID = "fortiva_notice_id"

    /** Every message notification carries this tag and its message id. */
    private const val NOTIFY_TAG = "fortiva_message"

    /**
     * Whether a notification posted now would be seen: the user allowed
     * notifications for the app (on Android 13 and later that is the
     * POST_NOTIFICATIONS permission) and did not turn this channel off.
     */
    fun allowed(context: Context): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            return false
        }
        val manager = NotificationManagerCompat.from(context)
        if (!manager.areNotificationsEnabled()) return false
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = manager.getNotificationChannel(CHANNEL_ID)
            if (channel != null && channel.importance == NotificationManager.IMPORTANCE_NONE) return false
        }
        return true
    }

    /**
     * Post message [id]. Returns whether it was posted. A second post for the
     * same id replaces the first rather than adding one.
     *
     * The channel's name and description come from the app's translations,
     * in the language the user chose in the app, and are set again on every
     * post so a change of language reaches the system settings.
     */
    fun show(
        context: Context,
        id: Int,
        title: String,
        body: String,
        channelName: String,
        channelDescription: String,
    ): Boolean {
        return try {
            ensureChannel(context, channelName, channelDescription)
            if (!allowed(context)) return false
            val open = Intent(context, MainActivity::class.java).apply {
                putExtra(EXTRA_NOTICE_ID, id)
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
            }
            val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
            } else {
                PendingIntent.FLAG_UPDATE_CURRENT
            }
            // The message id as the request code, so each notification keeps
            // its own extra rather than sharing the newest one.
            val tap = PendingIntent.getActivity(context, id, open, flags)
            val notification = NotificationCompat.Builder(context, CHANNEL_ID)
                .setSmallIcon(R.drawable.fortiva)
                .setContentTitle(title)
                .setContentText(body)
                .setStyle(NotificationCompat.BigTextStyle().bigText(body))
                .setPriority(NotificationCompat.PRIORITY_DEFAULT)
                .setAutoCancel(true)
                .setContentIntent(tap)
                .build()
            NotificationManagerCompat.from(context).notify(NOTIFY_TAG, id, notification)
            true
        } catch (e: SecurityException) {
            // The permission was taken back between the check and the post.
            Log.w(TAG, "notification not allowed", e)
            false
        } catch (e: Exception) {
            Log.e(TAG, "could not post a message notification", e)
            false
        }
    }

    /**
     * Tell the user the tunnel is up but carries nothing, found by the keeper
     * while the app was not running (KeeperJobService). A tap opens the app,
     * which checks again and moves to another path. One notification at a
     * time: a second replaces the first.
     */
    fun showStalled(
        context: Context,
        title: String,
        body: String,
        channelName: String,
        channelDescription: String,
    ): Boolean {
        return try {
            ensureChannel(context, channelName, channelDescription)
            if (!allowed(context)) return false
            val open = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
            }
            val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
            } else {
                PendingIntent.FLAG_UPDATE_CURRENT
            }
            val tap = PendingIntent.getActivity(context, STALLED_ID, open, flags)
            val notification = NotificationCompat.Builder(context, CHANNEL_ID)
                .setSmallIcon(R.drawable.fortiva)
                .setContentTitle(title)
                .setContentText(body)
                .setStyle(NotificationCompat.BigTextStyle().bigText(body))
                .setPriority(NotificationCompat.PRIORITY_DEFAULT)
                // A second post while one is shown makes no sound.
                .setOnlyAlertOnce(true)
                .setAutoCancel(true)
                .setContentIntent(tap)
                .build()
            NotificationManagerCompat.from(context).notify(STALLED_TAG, STALLED_ID, notification)
            true
        } catch (e: SecurityException) {
            Log.w(TAG, "notification not allowed", e)
            false
        } catch (e: Exception) {
            Log.e(TAG, "could not post the stalled notification", e)
            false
        }
    }

    /**
     * Take the [showStalled] notification away once it is no longer true:
     * the tunnel carries data again, the app is on screen and shows the
     * tunnel's state itself, or the tunnel stopped. Nothing happens when
     * none is shown. Safe from the tunnel's process too.
     */
    fun clearStalled(context: Context) {
        try {
            NotificationManagerCompat.from(context).cancel(STALLED_TAG, STALLED_ID)
        } catch (e: Exception) {
            Log.w(TAG, "could not clear the stalled notification", e)
        }
    }

    private const val STALLED_TAG = "fortiva_stalled"
    private const val STALLED_ID = 1

    private fun ensureChannel(context: Context, name: String, description: String) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        // Creating a channel that exists only renames it: the user's own
        // choices for it (sound, importance, off) stay as they set them.
        val channel = NotificationChannel(
            CHANNEL_ID,
            name.ifBlank { context.getString(R.string.app_name) },
            NotificationManager.IMPORTANCE_DEFAULT,
        )
        channel.description = description
        manager.createNotificationChannel(channel)
    }

    /**
     * The phone's country as two upper-case letters, or null. Used only on
     * the phone, to skip a message from the public file that is aimed at
     * other countries; it is never sent anywhere.
     *
     * The mobile network's country first, then the SIM's, then the region
     * of the phone's time zone, which is all a phone on wifi with no SIM
     * has. The backend places a phone the same way before it looks at the
     * address.
     */
    fun country(context: Context): String? {
        try {
            val tm = context.getSystemService(Context.TELEPHONY_SERVICE) as? TelephonyManager
            val fromNetwork = tm?.networkCountryIso?.trim()
            if (fromNetwork != null && fromNetwork.length == 2) return fromNetwork.uppercase()
            val fromSim = tm?.simCountryIso?.trim()
            if (fromSim != null && fromSim.length == 2) return fromSim.uppercase()
        } catch (_: Exception) {
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            try {
                val zone = java.util.TimeZone.getDefault().id
                val region = android.icu.util.TimeZone.getRegion(zone)
                // "001" and other numbers are regions of the world, not countries.
                if (region.length == 2 && region.all { it.isLetter() }) return region.uppercase()
            } catch (_: Exception) {
            }
        }
        return null
    }
}
