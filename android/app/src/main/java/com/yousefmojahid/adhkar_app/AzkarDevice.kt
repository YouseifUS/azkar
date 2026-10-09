package com.yousefmojahid.adhkar_app

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Bundle
import android.os.Build
import android.graphics.Color
import androidx.core.view.WindowInsetsControllerCompat
import android.os.Handler
import android.os.Looper
import androidx.core.content.ContextCompat
import com.facebook.react.ReactPackage
import com.facebook.react.bridge.*
import com.facebook.react.uimanager.ViewManager
import org.json.JSONObject
import java.util.concurrent.Executors

class AzkarDevice(private val context: ReactApplicationContext) : ReactContextBaseJavaModule(context) {
    private val executor = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    override fun getName() = "AzkarDevice"
    private fun state(promise: Promise, action: () -> Unit = {}) {
        executor.execute {
            try {
                synchronized(AzkarStore.lock) {
                    action()
                    val snapshot = AzkarStore(context).snapshot()
                    main.post {
                        context.currentActivity?.window?.let {window ->
                            @Suppress("DEPRECATION")
                            window.navigationBarColor = Color.parseColor(if (snapshot.getBoolean("light")) "#EDE5D3" else "#040810")
                            WindowInsetsControllerCompat(window,window.decorView).isAppearanceLightNavigationBars = snapshot.getBoolean("light")
                        }
                    }
                    promise.resolve(Arguments.makeNativeMap(jsonMap(snapshot)))
                }
            } catch (e: Exception) {promise.reject("AZKAR_STORAGE", "Unable to read or save local data", e)}
        }
    }
    private fun jsonMap(json: JSONObject): Map<String, Any?> = json.keys().asSequence().associateWith {key ->
        when (val value = json.get(key)) {
            JSONObject.NULL -> null
            is JSONObject -> jsonMap(value)
            is Number -> value.toDouble()
            else -> value
        }
    }
    private fun locationAllowed() = ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED || ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED
    @ReactMethod fun load(promise: Promise) {state(promise) {
        Reminders.initialize(context);Reminders.retireFlutter(context);Reminders.register(context)
    }}
    @ReactMethod fun permissions(promise: Promise) {
        Reminders.initialize(context)
        promise.resolve(Arguments.createMap().apply {putBoolean("location", locationAllowed());putBoolean("notifications", Reminders.allowed(context))})
    }
    @ReactMethod fun increment(period: String, order: Double, promise: Promise) {state(promise) {
        require(period == "morning" || period == "evening")
        val list = JSONObject(context.assets.open("adhkar_morning_evening.json").bufferedReader().use {it.readText()}).getJSONArray(period)
        val integer = order.toInt()
        require(integer.toDouble() == order && integer in 1..list.length())
        val target = list.getJSONObject(integer - 1).getInt("repetition")
        val store = AzkarStore(context)
        store.applyFajr(System.currentTimeMillis());store.increment(period, integer, target)
    }}
    @ReactMethod fun reset(promise: Promise) {state(promise) {AzkarStore(context).reset()}}
    @ReactMethod fun setLight(light: Boolean, promise: Promise) {state(promise) {AzkarStore(context).setLight(light)}}
    private fun finishActivation(promise: Promise, location: Location?) {state(promise) {
        if (location != null) AzkarStore(context).saveCoordinates(location.latitude, location.longitude)
        Reminders.refresh(context);Reminders.register(context)
    }}
    @ReactMethod fun activate(promise: Promise) {
        main.post {
            if (!locationAllowed()) {finishActivation(promise, null);return@post}
            val manager = context.getSystemService(Context.LOCATION_SERVICE) as LocationManager
            try {
                val providers = manager.getProviders(true).filter {it == LocationManager.NETWORK_PROVIDER || it == LocationManager.GPS_PROVIDER}
                val last = providers.mapNotNull {manager.getLastKnownLocation(it)}.maxByOrNull {it.time}
                if (providers.isEmpty()) {finishActivation(promise, last);return@post}
                var completed = false
                lateinit var listener: LocationListener
                lateinit var timeout: Runnable
                fun finish(location: Location?) {
                    if (completed) return
                    completed = true
                    main.removeCallbacks(timeout)
                    manager.removeUpdates(listener)
                    finishActivation(promise, location ?: last)
                }
                listener = object : LocationListener {
                    override fun onLocationChanged(location: Location) {finish(location)}
                    override fun onProviderEnabled(provider: String) {}
                    override fun onProviderDisabled(provider: String) {}
                    @Deprecated("Legacy callback") override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) {}
                }
                timeout = Runnable {finish(last)}
                main.postDelayed(timeout, 15000)
                try {for (provider in providers) manager.requestLocationUpdates(provider, 0L, 0f, listener, Looper.getMainLooper())}
                catch (_: SecurityException) {finish(last)}
            } catch (_: Exception) {finishActivation(promise, null)}
        }
    }
    override fun invalidate() {executor.shutdown();super.invalidate()}
}
class AzkarPackage : ReactPackage {
    override fun createNativeModules(context: ReactApplicationContext): List<NativeModule> = listOf(AzkarDevice(context))
    override fun createViewManagers(context: ReactApplicationContext): List<ViewManager<*, *>> = emptyList()
}
