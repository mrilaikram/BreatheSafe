package com.breathesafe.breathe_safe

import android.content.Intent
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "breathe_safe/background_alerts"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "configure" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: true
                    val snoozeMinutes = call.argument<Int>("snoozeMinutes") ?: 15
                    val ageGroup = call.argument<String>("ageGroup") ?: "adult"
                    val conditions = call.argument<List<String>>("conditions") ?: emptyList()

                    getSharedPreferences(BreathSafeBleService.PREFS_NAME, MODE_PRIVATE)
                        .edit()
                        .putBoolean(BreathSafeBleService.PREF_ENABLED, enabled)
                        .putInt(BreathSafeBleService.PREF_SNOOZE_MINUTES, snoozeMinutes)
                        .putString(BreathSafeBleService.PREF_AGE_GROUP, ageGroup)
                        .putStringSet(BreathSafeBleService.PREF_CONDITIONS, conditions.toHashSet())
                        .apply()

                    if (enabled) {
                        startMonitorService(BreathSafeBleService.ACTION_START)
                    } else {
                        startMonitorService(BreathSafeBleService.ACTION_STOP)
                    }

                    result.success(true)
                }
                "start" -> {
                    startMonitorService(BreathSafeBleService.ACTION_START)
                    result.success(true)
                }
                "stop" -> {
                    startMonitorService(BreathSafeBleService.ACTION_STOP)
                    result.success(true)
                }
                "snoozeNow" -> {
                    startMonitorService(BreathSafeBleService.ACTION_SNOOZE)
                    result.success(true)
                }
                "getLastConnectedMac" -> {
                    val mac = getSharedPreferences(BreathSafeBleService.PREFS_NAME, MODE_PRIVATE)
                        .getString(BreathSafeBleService.PREF_LAST_CONNECTED_MAC, null)
                    result.success(mac)
                }
                "getConnectionStatus" -> {
                    val status = getSharedPreferences(BreathSafeBleService.PREFS_NAME, MODE_PRIVATE)
                        .getBoolean(BreathSafeBleService.PREF_IS_CONNECTED, false)
                    result.success(status)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun startMonitorService(action: String) {
        val intent = Intent(this, BreathSafeBleService::class.java).setAction(action)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && action != BreathSafeBleService.ACTION_STOP) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }
}
