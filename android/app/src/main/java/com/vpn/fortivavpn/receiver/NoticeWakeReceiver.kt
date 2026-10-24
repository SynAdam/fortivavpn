package com.vpn.fortivavpn.receiver

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import com.vpn.fortivavpn.service.NoticeJobs
import com.vpn.fortivavpn.service.NoticeNotifier

/**
 * Starts the checks for messages from the Fortiva team (NoticeJobs).
 *
 * - [ACTION_ALARM]: the wake-up alarm fired. Set the next one and start a
 *   check, while notifications can show.
 * - MY_PACKAGE_REPLACED: the app was updated. Android keeps scheduled jobs
 *   across an update but not always the alarm, and the jobs may be an older
 *   build's, so both are set again. Needs no permission: Android sends it
 *   to the updated app only.
 */
class NoticeWakeReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            ACTION_ALARM -> {
                // Notifications turned off since: stop waking the phone.
                if (!NoticeNotifier.allowed(context)) {
                    NoticeJobs.cancelAlarm(context)
                    return
                }
                NoticeJobs.armAlarm(context)
                NoticeJobs.runFromAlarm(context)
            }
            Intent.ACTION_MY_PACKAGE_REPLACED -> {
                NoticeJobs.schedulePeriodic(context)
                if (NoticeNotifier.allowed(context)) NoticeJobs.armAlarm(context)
            }
        }
    }

    companion object {
        const val ACTION_ALARM = "com.vpn.fortivavpn.action.NOTICE_ALARM"
    }
}
