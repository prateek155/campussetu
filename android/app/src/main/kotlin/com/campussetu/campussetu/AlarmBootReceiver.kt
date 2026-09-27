package com.campussetu.campussetu

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.app.AlarmManager

class AlarmBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED ||
            intent.action == Intent.ACTION_TIME_CHANGED ||
            intent.action == Intent.ACTION_TIMEZONE_CHANGED ||
            intent.action == AlarmManager.ACTION_SCHEDULE_EXACT_ALARM_PERMISSION_STATE_CHANGED
        ) {
            AlarmScheduler.rescheduleAll(context)
        }
    }
}
