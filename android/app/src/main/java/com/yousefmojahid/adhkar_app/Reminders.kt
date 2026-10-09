package com.yousefmojahid.adhkar_app

import android.Manifest
import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import androidx.work.*
import org.json.JSONArray
import java.util.concurrent.TimeUnit

object Reminders {
    const val CHANNEL = "adhkar_prayer_reminders"
    private const val REFRESH = "azkarReactNativePrayerRefresh"
    fun initialize(context: Context) {
        if (Build.VERSION.SDK_INT < 26) return
        val manager = context.getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(NotificationChannel(CHANNEL, "تذكير أذكار الصباح والمساء", NotificationManager.IMPORTANCE_HIGH).apply {
            description = "تنبيهات بعد صلاة الفجر والعصر بنصف ساعة"
        })
    }
    fun allowed(context: Context): Boolean = (Build.VERSION.SDK_INT < 33 || ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED) && NotificationManagerCompat.from(context).areNotificationsEnabled() && (Build.VERSION.SDK_INT < 26 || context.getSystemService(NotificationManager::class.java).getNotificationChannel(CHANNEL)?.importance != NotificationManager.IMPORTANCE_NONE)
    fun register(context: Context) {
        WorkManager.getInstance(context).enqueueUniquePeriodicWork(REFRESH, ExistingPeriodicWorkPolicy.UPDATE,
            PeriodicWorkRequestBuilder<PrayerRefreshWorker>(12, TimeUnit.HOURS).build())
    }
    /** Old receiver classes disappear in this update. Explicitly retire their scheduled intents. */
    fun retireFlutter(context: Context) {
        val prefs = context.getSharedPreferences("scheduled_notifications", Context.MODE_PRIVATE)
        val alarms = context.getSystemService(AlarmManager::class.java)
        val list = try {JSONArray(prefs.getString("scheduled_notifications", "[]"))} catch (_: Exception) {JSONArray()}
        for (index in 0 until list.length()) {
            val id = list.optJSONObject(index)?.optInt("id", -1) ?: continue
            if (id < 0) continue
            val intent = Intent().setComponent(ComponentName(context.packageName, "com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver"))
            PendingIntent.getBroadcast(context, id, intent, PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE)?.let {alarms.cancel(it);it.cancel()}
        }
        WorkManager.getInstance(context).cancelUniqueWork("adhkarDailyPrayerRefresh")
    }
    fun refresh(context: Context, now: Long = System.currentTimeMillis()) = synchronized(AzkarStore.lock) {
        val store = AzkarStore(context)
        store.applyFajr(now)
        val coordinates = store.coordinates() ?: return@synchronized
        initialize(context)
        if (!allowed(context)) return@synchronized
        val alarms = context.getSystemService(AlarmManager::class.java)
        for (offset in 0 until 14) {
            val day = PrayerClock.day(now, offset)
            val prayer = PrayerClock.prayers(day, coordinates.first, coordinates.second)
            for (evening in listOf(false, true)) {
                val moment = (if (evening) prayer.asr else prayer.fajr).time + TimeUnit.MINUTES.toMillis(30)
                if (moment <= now) continue
                val intent = Intent(context, ReminderReceiver::class.java).putExtra("evening", evening).putExtra("id", PrayerClock.id(day, evening))
                val pending = PendingIntent.getBroadcast(context, PrayerClock.id(day, evening), intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
                if (Build.VERSION.SDK_INT < 31 || alarms.canScheduleExactAlarms()) {
                    try {alarms.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, moment, pending)}
                    catch (_: SecurityException) {alarms.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, moment, pending)}
                } else alarms.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, moment, pending)
            }
        }
    }
}
class ReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        Reminders.initialize(context)
        if (!Reminders.allowed(context)) return
        val evening = intent.getBooleanExtra("evening", false)
        val content = PendingIntent.getActivity(context, 0, Intent(context, MainActivity::class.java), PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val notification = NotificationCompat.Builder(context, Reminders.CHANNEL).setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(if (evening) "أذكار المساء" else "أذكار الصباح")
            .setContentText(if (evening) "مرّت نصف ساعة على صلاة العصر، حان وقت أذكار المساء." else "مرّت نصف ساعة على صلاة الفجر، حان وقت أذكار الصباح.")
            .setContentIntent(content).setAutoCancel(true).setPriority(NotificationCompat.PRIORITY_HIGH).build()
        try {NotificationManagerCompat.from(context).notify(intent.getIntExtra("id", if (evening) 2 else 1), notification)} catch (_: SecurityException) { }
    }
}
class PrayerRefreshWorker(context: Context, parameters: WorkerParameters) : Worker(context, parameters) {
    override fun doWork(): Result = try {Reminders.refresh(applicationContext); Result.success()} catch (_: Exception) {Result.retry()}
}
class RefreshReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        WorkManager.getInstance(context).enqueueUniqueWork("azkarImmediatePrayerRefresh", ExistingWorkPolicy.REPLACE,
            OneTimeWorkRequestBuilder<PrayerRefreshWorker>().build())
    }
}
