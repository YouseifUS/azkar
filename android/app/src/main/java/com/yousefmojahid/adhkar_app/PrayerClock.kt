package com.yousefmojahid.adhkar_app

import com.batoulapps.adhan.CalculationMethod
import com.batoulapps.adhan.Coordinates
import com.batoulapps.adhan.Madhab
import com.batoulapps.adhan.PrayerTimes
import com.batoulapps.adhan.data.DateComponents
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale

data class PrayerMoments(val fajr: Date, val asr: Date)

object PrayerClock {
    fun day(now: Long, offset: Int = 0): Calendar = Calendar.getInstance().apply {
        timeInMillis = now
        add(Calendar.DAY_OF_MONTH, offset)
        set(Calendar.HOUR_OF_DAY, 0); set(Calendar.MINUTE, 0)
        set(Calendar.SECOND, 0); set(Calendar.MILLISECOND, 0)
    }
    fun prayers(day: Calendar, latitude: Double, longitude: Double): PrayerMoments {
        val params = CalculationMethod.EGYPTIAN.parameters.apply { madhab = Madhab.SHAFI }
        val times = PrayerTimes(Coordinates(latitude, longitude), DateComponents(day.get(Calendar.YEAR), day.get(Calendar.MONTH) + 1, day.get(Calendar.DAY_OF_MONTH)), params)
        // Adhan Java retains Calendar's current milliseconds; Flutter returns exact minute boundaries.
        // Normalize them so repeated calculations have an identical Fajr boundary and alarm instant.
        return PrayerMoments(Date(times.fajr.time / 1000 * 1000), Date(times.asr.time / 1000 * 1000))
    }
    fun boundary(now: Long, latitude: Double, longitude: Double): String {
        val today = day(now)
        val date = if (now < prayers(today, latitude, longitude).fajr.time) day(now, -1) else today
        return SimpleDateFormat("yyyy-MM-dd", Locale.US).format(date.time)
    }
    fun nextFajr(now: Long, latitude: Double, longitude: Double): Long {
        val today = prayers(day(now), latitude, longitude).fajr.time
        return if (today > now) today else prayers(day(now, 1), latitude, longitude).fajr.time
    }
    fun id(day: Calendar, evening: Boolean): Int =
        (day.get(Calendar.YEAR) * 10000 + (day.get(Calendar.MONTH) + 1) * 100 + day.get(Calendar.DAY_OF_MONTH)) * 2 + if (evening) 1 else 0
}
