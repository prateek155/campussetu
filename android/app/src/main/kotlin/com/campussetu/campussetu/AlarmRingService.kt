package com.campussetu.campussetu

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.content.Context
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.media.Ringtone
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager

class AlarmRingService : Service() {
    private var ringtone: Ringtone? = null
    private var customPlayer: MediaPlayer? = null
    private var vibrator: Vibrator? = null
    private val handler = Handler(Looper.getMainLooper())
    private var alarmId = -1

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            stopRinging()
            return START_NOT_STICKY
        }
        alarmId = intent?.getIntExtra(EXTRA_ALARM_ID, -1) ?: -1
        if (alarmId <= 0) {
            stopSelf()
            return START_NOT_STICKY
        }
        ensureChannel()
        startForeground(NOTIFICATION_ID_BASE + alarmId, buildNotification(alarmId))
        startRingtone(alarmId)
        return START_REDELIVER_INTENT
    }

    private fun buildNotification(id: Int): Notification {
        val alarm = AlarmScheduler.alarm(this, id)
        val title = alarm?.optString("label")?.takeIf { it.isNotBlank() } ?: "CampusSetu alarm"
        val open = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra(EXTRA_ALARM_ID, id)
        }
        val openPi = PendingIntent.getActivity(this, id, open, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val snoozePi = receiverPending(id, AlarmReceiver.ACTION_SNOOZE, id * 16 + 13)
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) Notification.Builder(this, CHANNEL_ID) else Notification.Builder(this)
        builder
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setContentTitle(title)
            .setContentText("Wake up and complete your mission")
            .setCategory(Notification.CATEGORY_ALARM)
            .setVisibility(Notification.VISIBILITY_PRIVATE)
            .setOngoing(true)
            .setAutoCancel(false)
            .setContentIntent(openPi)
        if ((alarm?.optInt("snoozeMinutes", 5) ?: 5) > 0) {
            builder.addAction(android.R.drawable.ic_lock_idle_alarm, "Snooze", snoozePi)
        }
        return builder.build()
    }

    private fun receiverPending(id: Int, action: String, requestCode: Int): PendingIntent {
        val intent = Intent(this, AlarmReceiver::class.java).apply {
            this.action = action
            putExtra(AlarmReceiver.EXTRA_ALARM_ID, id)
        }
        return PendingIntent.getBroadcast(this, requestCode, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    }

    private fun ensureChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = getSystemService(NotificationManager::class.java)
            if (manager.getNotificationChannel(CHANNEL_ID) == null) {
                manager.createNotificationChannel(NotificationChannel(CHANNEL_ID, "Alarms", NotificationManager.IMPORTANCE_HIGH).apply {
                    description = "Scheduled CampusSetu wake-up alarms"
                    setSound(null, null)
                    lockscreenVisibility = Notification.VISIBILITY_PRIVATE
                })
            }
        }
    }

    private fun startRingtone(id: Int) {
        val alarm = AlarmScheduler.alarm(this, id)
        val volume = (alarm?.optDouble("volume", 1.0) ?: 1.0).toFloat().coerceIn(0.2f, 1f)
        val customPath = alarm?.optString("customSoundPath").orEmpty()
        ringtone?.stop()
        ringtone = null
        customPlayer?.release()
        customPlayer = null

        if (customPath.isNotBlank()) {
            val player = MediaPlayer()
            customPlayer = player
            try {
                player.setAudioAttributes(AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_ALARM)
                    .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                    .build())
                player.setDataSource(customPath)
                player.isLooping = true
                player.setVolume(volume, volume)
                player.setOnPreparedListener { prepared ->
                    if (customPlayer === prepared) prepared.start()
                }
                player.setOnErrorListener { failed, _, _ ->
                    if (customPlayer === failed) {
                        failed.release()
                        customPlayer = null
                        startDefaultRingtone(volume)
                    }
                    true
                }
                player.prepareAsync()
            } catch (_: Exception) {
                player.release()
                customPlayer = null
                startDefaultRingtone(volume)
            }
        } else {
            val configured = alarm?.optString("soundUri").orEmpty()
            val uri = configured.takeIf { it.isNotBlank() }?.let(Uri::parse)
                ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
            startSystemRingtone(uri, volume)
        }
        if (alarm?.optBoolean("vibration", true) != false) startVibration()
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.P) {
            handler.postDelayed(object : Runnable {
                override fun run() {
                    if (ringtone?.isPlaying == false) ringtone?.play()
                    if (customPlayer?.isPlaying == false) customPlayer?.start()
                    if (ringtone != null || customPlayer != null) handler.postDelayed(this, 20_000L)
                }
            }, 20_000L)
        }
    }

    private fun startDefaultRingtone(volume: Float) {
        startSystemRingtone(RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM), volume)
    }

    private fun startSystemRingtone(uri: Uri, volume: Float) {
        ringtone = RingtoneManager.getRingtone(this, uri)
            ?: RingtoneManager.getRingtone(this, RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM))
        ringtone?.audioAttributes = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_ALARM)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) ringtone?.isLooping = true
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) ringtone?.volume = volume
        ringtone?.play()
    }

    private fun startVibration() {
        vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            getSystemService(VibratorManager::class.java)?.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
        }
        if (vibrator?.hasVibrator() != true) return
        val pattern = longArrayOf(0, 650, 350, 650, 600)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            vibrator?.vibrate(VibrationEffect.createWaveform(pattern, 0))
        } else {
            @Suppress("DEPRECATION")
            vibrator?.vibrate(pattern, 0)
        }
    }

    private fun stopRinging() {
        handler.removeCallbacksAndMessages(null)
        ringtone?.stop()
        ringtone = null
        customPlayer?.stopSafely()
        customPlayer = null
        vibrator?.cancel()
        vibrator = null
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    override fun onDestroy() {
        handler.removeCallbacksAndMessages(null)
        ringtone?.stop()
        ringtone = null
        customPlayer?.stopSafely()
        customPlayer = null
        vibrator?.cancel()
        vibrator = null
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    companion object {
        const val ACTION_RING = "com.campussetu.alarm.RING"
        const val ACTION_STOP = "com.campussetu.alarm.STOP"
        const val EXTRA_ALARM_ID = "alarm_id"
        const val CHANNEL_ID = "campussetu_alarms_v1"
        const val NOTIFICATION_ID_BASE = 41000
    }

    private fun MediaPlayer.stopSafely() {
        try {
            if (isPlaying) stop()
        } catch (_: IllegalStateException) {
            // Player may still be preparing when the alarm is dismissed.
        } finally {
            release()
        }
    }
}
