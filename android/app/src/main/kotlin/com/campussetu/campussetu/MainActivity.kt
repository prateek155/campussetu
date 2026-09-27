package com.campussetu.campussetu

import android.app.AlarmManager
import android.content.Intent
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.util.TimeZone

class MainActivity : FlutterActivity() {
    private var exactPermissionResult: MethodChannel.Result? = null
    private var ringtoneResult: MethodChannel.Result? = null
    private var alarmEventSink: EventChannel.EventSink? = null
    private var motionSink: EventChannel.EventSink? = null
    private lateinit var sensorManager: SensorManager
    private var accelerometerListener: SensorEventListener? = null

    override fun getInitialRoute(): String {
        val id = intent?.getIntExtra(AlarmRingService.EXTRA_ALARM_ID, -1) ?: -1
        return if (id > 0) "/alarm/ring?alarmId=$id" else super.getInitialRoute() ?: "/"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        sensorManager = getSystemService(SENSOR_SERVICE) as SensorManager

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.campussetu/alarm")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "saveAlarms" -> {
                        val raw = call.arguments as? String
                        if (raw == null) result.error("invalid_alarms", "Alarm data is missing", null)
                        else {
                            try {
                                result.success(AlarmScheduler.save(this, raw))
                            } catch (error: SecurityException) {
                                result.error("alarm_permission", "Android alarm access was revoked. Re-enable it in Settings.", null)
                            }
                        }
                    }
                    "getAlarms" -> result.success(AlarmScheduler.read(this))
                    "hasExactAlarmAccess" -> result.success(AlarmScheduler.hasExactAccess(this))
                    "requestExactAlarmAccess" -> requestExactAlarmAccess(result)
                    "pickAlarmSound" -> pickAlarmSound(call.arguments as? String ?: "", result)
                    "stopAlarm" -> {
                        val id = (call.arguments as? Number)?.toInt() ?: -1
                        if (id > 0) AlarmScheduler.stop(this, id)
                        result.success(null)
                    }
                    "snoozeAlarm" -> {
                        val args = call.arguments as? Map<*, *>
                        val id = (args?.get("id") as? Number)?.toInt() ?: -1
                        val minutes = (args?.get("minutes") as? Number)?.toInt() ?: 5
                        if (id > 0) {
                            AlarmScheduler.scheduleSnooze(this, id, minutes)
                            AlarmScheduler.stop(this, id)
                        }
                        result.success(null)
                    }
                    "getLaunchAlarmId" -> {
                        val id = intent?.getIntExtra(AlarmRingService.EXTRA_ALARM_ID, -1) ?: -1
                        result.success(if (id > 0) id else null)
                    }
                    "getLocalTimezone" -> result.success(TimeZone.getDefault().id)
                    else -> result.notImplemented()
                }
            }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "com.campussetu/alarm_events")
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    alarmEventSink = events
                }
                override fun onCancel(arguments: Any?) {
                    alarmEventSink = null
                }
            })

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "com.campussetu/alarm_motion")
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    motionSink = events
                    val sensor = sensorManager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER) ?: return
                    accelerometerListener = object : SensorEventListener {
                        override fun onSensorChanged(event: SensorEvent) {
                            motionSink?.success(listOf(event.values[0].toDouble(), event.values[1].toDouble(), event.values[2].toDouble()))
                        }
                        override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) = Unit
                    }.also { sensorManager.registerListener(it, sensor, SensorManager.SENSOR_DELAY_GAME) }
                }
                override fun onCancel(arguments: Any?) {
                    accelerometerListener?.let(sensorManager::unregisterListener)
                    accelerometerListener = null
                    motionSink = null
                }
            })

        val launchId = intent?.getIntExtra(AlarmRingService.EXTRA_ALARM_ID, -1) ?: -1
        if (launchId > 0) alarmEventSink?.success(mapOf("type" to "ring", "id" to launchId))
    }

    private fun requestExactAlarmAccess(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S || AlarmScheduler.hasExactAccess(this)) {
            result.success(true)
            return
        }
        exactPermissionResult = result
        val request = Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM, Uri.parse("package:$packageName"))
        startActivityForResult(request, REQUEST_EXACT_ALARM)
    }

    private fun pickAlarmSound(currentUri: String, result: MethodChannel.Result) {
        ringtoneResult = result
        val current = currentUri.takeIf { it.isNotBlank() }?.let(Uri::parse)
            ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
        val picker = Intent(RingtoneManager.ACTION_RINGTONE_PICKER).apply {
            putExtra(RingtoneManager.EXTRA_RINGTONE_TYPE, RingtoneManager.TYPE_ALARM)
            putExtra(RingtoneManager.EXTRA_RINGTONE_TITLE, "Choose alarm sound")
            putExtra(RingtoneManager.EXTRA_RINGTONE_SHOW_SILENT, false)
            putExtra(RingtoneManager.EXTRA_RINGTONE_SHOW_DEFAULT, true)
            putExtra(RingtoneManager.EXTRA_RINGTONE_DEFAULT_URI, RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM))
            putExtra(RingtoneManager.EXTRA_RINGTONE_EXISTING_URI, current)
        }
        startActivityForResult(picker, REQUEST_RINGTONE)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQUEST_EXACT_ALARM) {
            exactPermissionResult?.success(AlarmScheduler.hasExactAccess(this))
            exactPermissionResult = null
        } else if (requestCode == REQUEST_RINGTONE) {
            val selected = if (resultCode == RESULT_OK) data?.getParcelableExtra<Uri>(RingtoneManager.EXTRA_RINGTONE_PICKED_URI) else null
            val title = selected?.let { RingtoneManager.getRingtone(this, it)?.getTitle(this) } ?: "Default alarm"
            ringtoneResult?.success(if (selected == null) null else mapOf("uri" to selected.toString(), "name" to title))
            ringtoneResult = null
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val id = intent.getIntExtra(AlarmRingService.EXTRA_ALARM_ID, -1)
        if (id > 0) alarmEventSink?.success(mapOf("type" to "ring", "id" to id))
    }

    companion object {
        private const val REQUEST_EXACT_ALARM = 6201
        private const val REQUEST_RINGTONE = 6202
    }
}
