package com.campussetu.campussetu

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class AlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val id = intent.getIntExtra(EXTRA_ALARM_ID, -1)
        if (id <= 0) return
        when (intent.action) {
            ACTION_DISMISS -> AlarmScheduler.stop(context, id)
            ACTION_SNOOZE -> {
                val alarm = AlarmScheduler.alarm(context, id)
                if (alarm != null) AlarmScheduler.scheduleSnooze(context, id, alarm.optInt("snoozeMinutes", 5))
                context.stopService(Intent(context, AlarmRingService::class.java))
            }
            ACTION_FIRE, ACTION_SNOOZE_FIRE -> AlarmScheduler.onTriggered(
                context,
                id,
                intent.getIntExtra(EXTRA_WEEKDAY, 0),
                intent.getBooleanExtra(EXTRA_IS_SNOOZE, false),
            )
        }
    }

    companion object {
        const val ACTION_FIRE = "com.campussetu.alarm.FIRE"
        const val ACTION_SNOOZE_FIRE = "com.campussetu.alarm.SNOOZE_FIRE"
        const val ACTION_DISMISS = "com.campussetu.alarm.DISMISS"
        const val ACTION_SNOOZE = "com.campussetu.alarm.SNOOZE"
        const val EXTRA_ALARM_ID = "alarm_id"
        const val EXTRA_WEEKDAY = "weekday"
        const val EXTRA_IS_SNOOZE = "is_snooze"
    }
}
