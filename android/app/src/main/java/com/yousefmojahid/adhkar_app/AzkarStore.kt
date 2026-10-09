package com.yousefmojahid.adhkar_app

import android.content.Context
import org.json.JSONObject

/** Reuse Flutter's existing preferences and keys, so updates preserve data and rollback can read it. */
class AzkarStore(context: Context) {
    private val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
    private fun key(name: String) = "flutter.$name"
    fun counts(period: String): JSONObject = try {JSONObject(prefs.getString(key("${period}_counts"), "{}") ?: "{}")} catch (_: Exception) {JSONObject()}
    fun light() = prefs.getBoolean(key("light_theme_enabled"), false)
    fun coordinates(): Pair<Double, Double>? {
        fun number(name: String) = prefs.all[key(name)]?.toString()?.toDoubleOrNull()
        val lat = number("location_latitude") ?: return null
        val lon = number("location_longitude") ?: return null
        return if (lat.isFinite() && lon.isFinite() && lat in -90.0..90.0 && lon in -180.0..180.0) lat to lon else null
    }
    fun saveCoordinates(latitude: Double, longitude: Double) {
        check(prefs.edit().putString(key("location_latitude"), latitude.toString()).putString(key("location_longitude"), longitude.toString()).putString(key("timezone_id"), java.util.TimeZone.getDefault().id).commit())
    }
    fun setLight(light: Boolean) {check(prefs.edit().putBoolean(key("light_theme_enabled"), light).commit())}
    fun reset() {check(prefs.edit().remove(key("morning_counts")).remove(key("evening_counts")).commit())}
    fun increment(period: String, order: Int, target: Int) {
        require(period == "morning" || period == "evening")
        val values = counts(period)
        val value = values.optInt(order.toString(), 0).coerceIn(0, target)
        if (value < target) {
            values.put(order.toString(), value + 1)
            check(prefs.edit().putString(key("${period}_counts"), values.toString()).commit())
        }
    }
    fun applyFajr(now: Long) {
        val (lat, lon) = coordinates() ?: return
        val boundary = PrayerClock.boundary(now, lat, lon)
        if (prefs.getString(key("last_fajr_reset"), null) != boundary) {
            check(prefs.edit().remove(key("morning_counts")).remove(key("evening_counts")).putString(key("last_fajr_reset"), boundary).commit())
        }
    }
    fun snapshot(now: Long = System.currentTimeMillis()): JSONObject {
        applyFajr(now)
        val coords = coordinates()
        return JSONObject().put("morning", counts("morning")).put("evening", counts("evening")).put("light", light())
            .put("nextFajr", if (coords == null) JSONObject.NULL else PrayerClock.nextFajr(now, coords.first, coords.second))
    }
    companion object {val lock = Any()}
}
