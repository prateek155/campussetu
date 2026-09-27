package com.campussetu.campussetu

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import org.json.JSONArray
import org.json.JSONObject
import java.util.Calendar

internal object AlarmScheduler {
    private const val PREFS = "campussetu_device_alarms"
    private const val ALARMS = "alarms_json"

    fun save(context: Context, raw: String): Boolean {
        val updated = parse(raw)
        val exactAccess = hasExactAccess(context)
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val old = parse(prefs.getString(ALARMS, "[]"))
        old.forEach { cancel(context, it.optInt("id")) }
        prefs.edit().putString(ALARMS, raw).apply()
        updated.forEach { alarm ->
            if (exactAccess && alarm.optBoolean("enabled", true)) scheduleAll(context, alarm)
        }
        return exactAccess || updated.none { it.optBoolean("enabled", true) }
    }

    fun read(context: Context): String =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString(ALARMS, "[]") ?: "[]"

    fun alarm(context: Context, id: Int): JSONObject? =
        parse(read(context)).firstOrNull { it.optInt("id") == id }

    fun onTriggered(context: Context, id: Int, weekday: Int, snooze: Boolean) {
        val alarm = alarm(context, id) ?: return
        if (!alarm.optBoolean("enabled", true) && !snooze) return
        if (!snooze) {
            val days = alarm.optJSONArray("days") ?: JSONArray()
            if (days.length() == 0) {
                alarm.put("enabled", false)
                val all = parse(read(context))
                val index = all.indexOfFirst { it.optInt("id") == id }
                if (index >= 0) all[index] = alarm
                context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
                    .putString(ALARMS, JSONArray(all).toString()).apply()
            } else if (weekday in 1..7 && (0 until days.length()).any { days.optInt(it) == weekday }) {
                schedule(context, alarm, weekday, nextTime(alarm, weekday))
            }
        }
        val start = Intent(context, AlarmRingService::class.java).apply {
            action = AlarmRingService.ACTION_RING
            putExtra(AlarmRingService.EXTRA_ALARM_ID, id)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) context.startForegroundService(start)
        else context.startService(start)
    }

    fun scheduleSnooze(context: Context, id: Int, minutes: Int) {
        val alarm = alarm(context, id) ?: return
        val safeMinutes = minutes.coerceIn(1, 30)
        val at = System.currentTimeMillis() + safeMinutes * 60_000L
        schedule(context, alarm, -1, at, snooze = true)
    }

    fun stop(context: Context, id: Int) {
        context.stopService(Intent(context, AlarmRingService::class.java))
    }

    fun hasExactAccess(context: Context): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.S ||
            ((context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager)?.canScheduleExactAlarms() == true)

    fun rescheduleAll(context: Context) {
        val alarms = parse(read(context))
        alarms.forEach { cancel(context, it.optInt("id")) }
        alarms.forEach { alarm ->
            if (alarm.optBoolean("enabled", true)) scheduleAll(context, alarm)
        }
    }

    private fun scheduleAll(context: Context, alarm: JSONObject) {
        val days = alarm.optJSONArray("days") ?: JSONArray()
        if (days.length() == 0) {
            schedule(context, alarm, 0, nextTime(alarm, 0))
        } else {
            for (i in 0 until days.length()) {
                val weekday = days.optInt(i)
                if (weekday in 1..7) schedule(context, alarm, weekday, nextTime(alarm, weekday))
            }
        }
    }

    private fun nextTime(alarm: JSONObject, weekday: Int): Long {
        val now = Calendar.getInstance()
        val target = (now.clone() as Calendar).apply {
            set(Calendar.HOUR_OF_DAY, alarm.optInt("hour").coerceIn(0, 23))
            set(Calendar.MINUTE, alarm.optInt("minute").coerceIn(0, 59))
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
        if (weekday == 0) {
            if (!target.after(now)) target.add(Calendar.DAY_OF_YEAR, 1)
        } else {
            val calendarDay = if (weekday == 7) Calendar.SUNDAY else weekday + 1
            var offset = (calendarDay - now.get(Calendar.DAY_OF_WEEK) + 7) % 7
            if (offset == 0 && !target.after(now)) offset = 7
            target.add(Calendar.DAY_OF_YEAR, offset)
        }
        return target.timeInMillis
    }

    private fun schedule(context: Context, alarm: JSONObject, weekday: Int, at: Long, snooze: Boolean = false) {
        if (!hasExactAccess(context)) return
        val id = alarm.optInt("id")
        val requestCode = requestCode(id, weekday, snooze)
        val intent = Intent(context, AlarmReceiver::class.java).apply {
            action = if (snooze) AlarmReceiver.ACTION_SNOOZE_FIRE else AlarmReceiver.ACTION_FIRE
            putExtra(AlarmReceiver.EXTRA_ALARM_ID, id)
            putExtra(AlarmReceiver.EXTRA_WEEKDAY, weekday)
            putExtra(AlarmReceiver.EXTRA_IS_SNOOZE, snooze)
        }
        val pending = PendingIntent.getBroadcast(
            context, requestCode, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val manager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
        val showIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val showPending = PendingIntent.getActivity(
            context, id * 16 + 14, showIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        manager.setAlarmClock(AlarmManager.AlarmClockInfo(at, showPending), pending)
    }

    private fun cancel(context: Context, id: Int) {
        val manager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
        // Cancel all weekday slots as well, including ones that may have belonged to an older repeat pattern.
        for (day in -1..7) {
            val intent = Intent(context, AlarmReceiver::class.java).apply {
                action = if (day == -1) AlarmReceiver.ACTION_SNOOZE_FIRE else AlarmReceiver.ACTION_FIRE
            }
            val pending = PendingIntent.getBroadcast(
                context, requestCode(id, day, day == -1), intent,
                PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE,
            )
            if (pending != null) {
                manager.cancel(pending)
                pending.cancel()
            }
        }
    }

    private fun requestCode(id: Int, weekday: Int, snooze: Boolean): Int = id * 16 + when {
        snooze -> 10
        weekday == 0 -> 0
        else -> weekday
    }

    private fun parse(raw: String?): MutableList<JSONObject> {
        return try {
            val array = JSONArray(raw ?: "[]")
            MutableList(array.length()) { array.getJSONObject(it) }
        } catch (_: Exception) {
            mutableListOf()
        }
    }
}
