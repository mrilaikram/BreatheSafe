package com.breathesafe.breathe_safe

import android.content.Intent
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "breathe_safe/background_alerts"

    private var eventSink: io.flutter.plugin.common.EventChannel.EventSink? = null
    private val receiver = object : android.content.BroadcastReceiver() {
        override fun onReceive(context: android.content.Context?, intent: Intent?) {
            when (intent?.action) {
                "com.breathesafe.ACTION_SENSOR_DATA" -> {
                    val data = intent.getStringExtra("data")
                    eventSink?.success(mapOf("type" to "sensor_data", "payload" to data))
                }
                "com.breathesafe.ACTION_CONNECTION_STATE" -> {
                    val connected = intent.getBooleanExtra("connected", false)
                    eventSink?.success(mapOf("type" to "connection_state", "connected" to connected))
                }
                "com.breathesafe.ACTION_SCAN_RESULT" -> {
                    val deviceName = intent.getStringExtra("name")
                    val mac = intent.getStringExtra("mac")
                    val rssi = intent.getIntExtra("rssi", 0)
                    if (deviceName != null && mac != null) {
                        eventSink?.success(mapOf(
                            "type" to "scan_result",
                            "name" to deviceName,
                            "mac" to mac,
                            "rssi" to rssi
                        ))
                    }
                }
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        io.flutter.plugin.common.EventChannel(flutterEngine.dartExecutor.binaryMessenger, "breathe_safe/sensor_events")
            .setStreamHandler(object : io.flutter.plugin.common.EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: io.flutter.plugin.common.EventChannel.EventSink?) {
                    eventSink = events
                    val filter = android.content.IntentFilter().apply {
                        addAction("com.breathesafe.ACTION_SENSOR_DATA")
                        addAction("com.breathesafe.ACTION_CONNECTION_STATE")
                        addAction("com.breathesafe.ACTION_SCAN_RESULT")
                    }
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        registerReceiver(receiver, filter, RECEIVER_NOT_EXPORTED)
                    } else {
                        registerReceiver(receiver, filter)
                    }
                }
                override fun onCancel(arguments: Any?) {
                    eventSink = null
                    try {
                        unregisterReceiver(receiver)
                    } catch (e: Exception) {}
                }
            })

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "breathe_safe/ble_commands").setMethodCallHandler { call, result ->
            when (call.method) {
                "startScan" -> {
                    startMonitorService("com.breathesafe.breathe_safe.MANUAL_START_SCAN")
                    result.success(true)
                }
                "stopScan" -> {
                    startMonitorService("com.breathesafe.breathe_safe.MANUAL_STOP_SCAN")
                    result.success(true)
                }
                "connect" -> {
                    val mac = call.argument<String>("mac")
                    if (mac != null) {
                        val intent = Intent(this, BreathSafeBleService::class.java).apply {
                            action = "com.breathesafe.breathe_safe.MANUAL_CONNECT"
                            putExtra("mac", mac)
                        }
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            startForegroundService(intent)
                        } else {
                            startService(intent)
                        }
                    }
                    result.success(true)
                }
                "disconnect" -> {
                    startMonitorService("com.breathesafe.breathe_safe.MANUAL_DISCONNECT")
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

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
