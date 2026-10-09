package com.yousefmojahid.adhkar_app

import android.app.Application
import android.app.AlarmManager
import android.app.NotificationManager
import android.content.Context
import androidx.work.Configuration
import androidx.work.WorkManager
import org.junit.*
import org.junit.Assert.*
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import java.util.Calendar
import java.util.TimeZone

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28], application = Application::class)
class AzkarRegressionTest {
    private lateinit var context: Context
    private lateinit var store: AzkarStore
    @Before fun setup() {
        TimeZone.setDefault(TimeZone.getTimeZone("Africa/Cairo"))
        context = RuntimeEnvironment.getApplication()
        context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE).edit().clear().commit()
        store = AzkarStore(context)
    }
    private fun date(hour: Int): Long = Calendar.getInstance().apply {set(2026,9,9,hour,0,0);set(Calendar.MILLISECOND,0)}.timeInMillis
    @Test fun existingFlutterDataAndDefaultDarkTheme() {
        assertFalse(store.light())
        val boundary = PrayerClock.boundary(date(12),30.0444,31.2357)
        context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE).edit()
            .putString("flutter.morning_counts", "{\"1\":1,\"22\":9}")
            .putString("flutter.evening_counts", "{\"1\":1}")
            .putBoolean("flutter.light_theme_enabled", true)
            .putString("flutter.location_latitude", "30.0444")
            .putString("flutter.location_longitude", "31.2357")
            .putString("flutter.last_fajr_reset", boundary).commit()
        val state = store.snapshot(date(12))
        assertTrue(state.getBoolean("light"))
        assertEquals(9,state.getJSONObject("morning").getInt("22"))
        assertEquals(1,state.getJSONObject("evening").getInt("1"))
        store.increment("morning",22,100)
        assertEquals(10,AzkarStore(context).counts("morning").getInt("22"))
        assertEquals(1,store.counts("evening").getInt("1"))
    }
    @Test fun prayerTimesMatchFlutterFixturesAcrossLocationsAndCalendarBoundaries() {
        Calendar.getInstance().apply {set(2026,9,9,12,0,0)}.let {day ->
            val prayers = PrayerClock.prayers(day,30.0444,31.2357)
            assertEquals(1791512820000L,prayers.fajr.time)
            assertEquals(1791550860000L,prayers.asr.time)
        }
        Calendar.getInstance().apply {set(2026,11,31,12,0,0)}.let {day ->
            val prayers = PrayerClock.prayers(day,30.0444,31.2357)
            assertEquals(1798687080000L,prayers.fajr.time)
            assertEquals(1798721220000L,prayers.asr.time)
        }
        Calendar.getInstance().apply {set(2027,0,1,12,0,0)}.let {day ->
            val prayers = PrayerClock.prayers(day,30.0444,31.2357)
            assertEquals(1798773480000L,prayers.fajr.time)
            assertEquals(1798807680000L,prayers.asr.time)
        }
        Calendar.getInstance().apply {set(2028,1,29,12,0,0)}.let {day ->
            val prayers = PrayerClock.prayers(day,30.0444,31.2357)
            assertEquals(1835405700000L,prayers.fajr.time)
            assertEquals(1835443560000L,prayers.asr.time)
        }
        Calendar.getInstance().apply {set(2026,3,24,12,0,0)}.let {day ->
            val prayers = PrayerClock.prayers(day,30.0444,31.2357)
            assertEquals(1776995160000L,prayers.fajr.time)
            assertEquals(1777037400000L,prayers.asr.time)
        }
        Calendar.getInstance().apply {set(2026,9,30,12,0,0)}.let {day ->
            val prayers = PrayerClock.prayers(day,30.0444,31.2357)
            assertEquals(1793328000000L,prayers.fajr.time)
            assertEquals(1793364360000L,prayers.asr.time)
        }
        Calendar.getInstance().apply {set(2026,9,9,12,0,0)}.let {day ->
            val prayers = PrayerClock.prayers(day,51.5074,-0.1278)
            assertEquals(1791519180000L,prayers.fajr.time)
            assertEquals(1791556920000L,prayers.asr.time)
        }
    }
    @Test fun capsCounterAndManualResetPreservesAppearance() {
        store.setLight(true)
        repeat(5) {store.increment("morning",1,1)}
        assertEquals(1,store.counts("morning").getInt("1"))
        store.reset();assertEquals(0,store.counts("morning").length());assertTrue(store.light())
    }
    @Test fun fajrBoundaryOnceBeforeAndAfterFajr() {
        store.saveCoordinates(30.0444,31.2357)
        val fajr = PrayerClock.prayers(PrayerClock.day(date(12)),30.0444,31.2357).fajr.time
        assertEquals("2026-10-08",PrayerClock.boundary(fajr-1,30.0444,31.2357))
        assertEquals("2026-10-09",PrayerClock.boundary(fajr,30.0444,31.2357))
        store.applyFajr(fajr-1);store.increment("morning",1,1);store.increment("evening",1,1)
        store.applyFajr(fajr);assertEquals(0,store.counts("morning").length());assertEquals(0,store.counts("evening").length())
        store.increment("morning",1,1);store.applyFajr(fajr+1000);assertEquals(1,store.counts("morning").getInt("1"))
        assertEquals(fajr,PrayerClock.nextFajr(fajr-1,30.0444,31.2357))
        assertTrue(PrayerClock.nextFajr(fajr,30.0444,31.2357)>fajr)
    }
    @Test fun schedulesFourteenDaysAfterFajrAndAsrAndIsIdempotent() {
        store.saveCoordinates(30.0444,31.2357)
        Reminders.refresh(context,date(0))
        val alarms = shadowOf(context.getSystemService(AlarmManager::class.java))
        assertEquals(28,alarms.scheduledAlarms.size)
        val prayer = PrayerClock.prayers(PrayerClock.day(date(0)),30.0444,31.2357)
        assertTrue(alarms.scheduledAlarms.any {it.triggerAtTime == prayer.fajr.time+1800000})
        assertTrue(alarms.scheduledAlarms.any {it.triggerAtTime == prayer.asr.time+1800000})
        Reminders.refresh(context,date(0));assertEquals(28,alarms.scheduledAlarms.size)
        assertEquals(NotificationManager.IMPORTANCE_HIGH,context.getSystemService(NotificationManager::class.java).getNotificationChannel(Reminders.CHANNEL).importance)
    }
    @Test @Config(sdk = [24]) fun androidSevenSupportsRemindersWithoutNotificationChannels() {
        store.saveCoordinates(30.0444,31.2357)
        Reminders.refresh(context,date(0))
        assertEquals(28,shadowOf(context.getSystemService(AlarmManager::class.java)).scheduledAlarms.size)
    }
    @Test fun noLocationDoesNotPreventReadingOrScheduleAlarms() {
        store.increment("morning",1,1)
        Reminders.refresh(context,date(12))
        assertEquals(1,store.snapshot(date(12)).getJSONObject("morning").getInt("1"))
        assertEquals(0,shadowOf(context.getSystemService(AlarmManager::class.java)).scheduledAlarms.size)
    }
}
