package com.breathesafe.breathe_safe

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCallback
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothGattDescriptor
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothProfile
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanResult
import android.bluetooth.le.ScanSettings
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.MediaPlayer
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import java.util.Locale
import java.util.UUID
import kotlin.math.roundToInt

class BreathSafeBleService : Service() {
    private val mainHandler = Handler(Looper.getMainLooper())
    private val bluetoothAdapter: BluetoothAdapter? by lazy {
        (getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager).adapter
    }
    private val notificationManager: NotificationManager by lazy {
        getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
    }

    private var bluetoothGatt: BluetoothGatt? = null
    private var isScanning = false
    private var isManualScan = false
    private var latestReading: Reading? = null
    private var mediaPlayer: MediaPlayer? = null
    private var audioManager: AudioManager? = null
    private var audioFocusRequest: AudioFocusRequest? = null

    private val scanCallback = object : ScanCallback() {
        override fun onScanResult(callbackType: Int, result: ScanResult) {
            if (!isBreathSafeResult(result)) return

            if (isManualScan) {
                val intent = Intent("com.breathesafe.ACTION_SCAN_RESULT")
                val deviceName = try {
                    if (hasBluetoothConnectPermission()) result.device.name ?: "" else ""
                } catch (e: SecurityException) { "" }
                
                intent.putExtra("name", deviceName)
                intent.putExtra("mac", result.device.address)
                intent.putExtra("rssi", result.rssi)
                sendBroadcast(intent)
            } else {
                stopBleScan()
                connectDevice(result.device)
            }
        }

        override fun onBatchScanResults(results: MutableList<ScanResult>) {
            for (result in results) {
                if (isBreathSafeResult(result)) {
                    if (isManualScan) {
                        val intent = Intent("com.breathesafe.ACTION_SCAN_RESULT")
                        val deviceName = try {
                            if (hasBluetoothConnectPermission()) result.device.name ?: "" else ""
                        } catch (e: SecurityException) { "" }
                        intent.putExtra("name", deviceName)
                        intent.putExtra("mac", result.device.address)
                        intent.putExtra("rssi", result.rssi)
                        sendBroadcast(intent)
                    } else {
                        stopBleScan()
                        connectDevice(result.device)
                        break
                    }
                }
            }
        }

        override fun onScanFailed(errorCode: Int) {
            updateStatusNotification("Scan failed. Check Bluetooth and Location.")
            scheduleScan(8_000)
        }
    }

    private val gattCallback = object : BluetoothGattCallback() {
        override fun onConnectionStateChange(gatt: BluetoothGatt, status: Int, newState: Int) {
            if (newState == BluetoothProfile.STATE_CONNECTED) {
                prefs().edit()
                    .putBoolean(PREF_IS_CONNECTED, true)
                    .putString(PREF_LAST_CONNECTED_MAC, gatt.device.address)
                prefs().edit().putString(PREF_LAST_CONNECTED_MAC, gatt.device.address).apply()
                if (hasBluetoothConnectPermission()) {
                    gatt.discoverServices()
                }
            } else if (newState == BluetoothProfile.STATE_DISCONNECTED) {
                closeGatt()
                updateStatusNotification("Disconnected. Searching for BreatheSafe...")
                scheduleScan(4_000)
            }
        }

        private fun onConnectionStateChange(isConnected: Boolean) {
            val prefs = prefs()
            prefs.edit().putBoolean(PREF_IS_CONNECTED, isConnected).apply()

            // Broadcast connection state to Flutter EventChannel
            sendBroadcast(Intent("com.breathesafe.ACTION_CONNECTION_STATE").putExtra("connected", isConnected))

            if (isConnected) {
                updateStatusNotification("Connected. Monitoring air quality...")
            }
        }

        override fun onServicesDiscovered(gatt: BluetoothGatt, status: Int) {
            val characteristic = gatt.getService(SERVICE_UUID)
                ?.getCharacteristic(CHARACTERISTIC_UUID)

            if (characteristic == null) {
                updateStatusNotification("BreatheSafe service not found. Reconnecting...")
                closeGatt()
                scheduleScan(4_000)
                return
            }

            enableNotifications(gatt, characteristic)
        }

        override fun onCharacteristicChanged(
            gatt: BluetoothGatt,
            characteristic: BluetoothGattCharacteristic,
            value: ByteArray,
        ) {
            handlePayload(value.toString(Charsets.UTF_8))
        }

        @Deprecated("Deprecated in Android 13")
        override fun onCharacteristicChanged(
            gatt: BluetoothGatt,
            characteristic: BluetoothGattCharacteristic,
        ) {
            handlePayload(characteristic.value.toString(Charsets.UTF_8))
        }
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannels()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action ?: ACTION_START) {
            ACTION_STOP -> {
                stopSelfCleanly()
                return START_NOT_STICKY
            }
            ACTION_SNOOZE -> {
                snoozeAlerts()
                return START_STICKY
            }
            ACTION_MANUAL_START_SCAN -> {
                isManualScan = true
                startBleScan()
                return START_STICKY
            }
            ACTION_MANUAL_STOP_SCAN -> {
                stopBleScan()
                isManualScan = false
                return START_STICKY
            }
            ACTION_MANUAL_CONNECT -> {
                val mac = intent?.getStringExtra("mac")
                if (mac != null) {
                    stopBleScan()
                    isManualScan = false
                    val device = bluetoothAdapter?.getRemoteDevice(mac)
                    if (device != null) {
                        connectDevice(device)
                    }
                }
                return START_STICKY
            }
            ACTION_MANUAL_DISCONNECT -> {
                closeGatt()
                return START_STICKY
            }
            else -> {
                isManualScan = false
                startMonitoring()
            }
        }

        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        stopBleScan()
        closeGatt()
        super.onDestroy()
    }

    private fun startMonitoring() {
        if (!prefs().getBoolean(PREF_ENABLED, true)) {
            stopSelfCleanly()
            return
        }

        val notification = buildStatusNotification("Searching for BreatheSafe...")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                STATUS_NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_CONNECTED_DEVICE,
            )
        } else {
            startForeground(STATUS_NOTIFICATION_ID, notification)
        }

        if (!hasBlePermissions()) {
            updateStatusNotification("Allow Bluetooth and Location permissions.")
            return
        }

        if (bluetoothAdapter?.isEnabled != true) {
            updateStatusNotification("Turn on Bluetooth to monitor BreatheSafe.")
            scheduleScan(10_000)
            return
        }

        scheduleScan(500)
    }

    private fun startBleScan() {
        if (isScanning || bluetoothGatt != null) return

        if (!hasBlePermissions() || bluetoothAdapter?.isEnabled != true) {
            updateStatusNotification("Turn on Bluetooth and Location.")
            scheduleScan(10_000)
            return
        }

        val scanner = bluetoothAdapter?.bluetoothLeScanner
        if (scanner == null) {
            updateStatusNotification("BLE scanner unavailable.")
            scheduleScan(10_000)
            return
        }

        val settings = ScanSettings.Builder()
            .setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY)
            .build()

        isScanning = true
        updateStatusNotification("Searching for BreatheSafe...")

        try {
            scanner.startScan(null, settings, scanCallback)
            mainHandler.postDelayed({
                if (isScanning) {
                    stopBleScan()
                    if (isManualScan) {
                        isManualScan = false
                    } else {
                        updateStatusNotification("Still searching for BreatheSafe...")
                        scheduleScan(6_000)
                    }
                }
            }, 12_000)
        } catch (error: SecurityException) {
            isScanning = false
            updateStatusNotification("Bluetooth permission blocked scanning.")
        }
    }

    private fun stopBleScan() {
        if (!isScanning) return

        try {
            bluetoothAdapter?.bluetoothLeScanner?.stopScan(scanCallback)
        } catch (_: Exception) {
        }

        isScanning = false
    }

    private fun scheduleScan(delayMs: Long) {
        mainHandler.postDelayed({ startBleScan() }, delayMs)
    }

    private fun connectDevice(device: BluetoothDevice) {
        if (!hasBluetoothConnectPermission()) {
            updateStatusNotification("Allow Bluetooth permission to connect.")
            return
        }

        updateStatusNotification("Connecting to BreatheSafe...")

        try {
            bluetoothGatt = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                device.connectGatt(this, false, gattCallback, BluetoothDevice.TRANSPORT_LE)
            } else {
                device.connectGatt(this, false, gattCallback)
            }
        } catch (error: SecurityException) {
            updateStatusNotification("Bluetooth permission blocked connection.")
        }
    }

    private fun enableNotifications(
        gatt: BluetoothGatt,
        characteristic: BluetoothGattCharacteristic,
    ) {
        if (!hasBluetoothConnectPermission()) return

        try {
            gatt.setCharacteristicNotification(characteristic, true)
            val descriptor = characteristic.getDescriptor(CCCD_UUID) ?: return

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                gatt.writeDescriptor(
                    descriptor,
                    BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE,
                )
            } else {
                @Suppress("DEPRECATION")
                descriptor.value = BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE
                @Suppress("DEPRECATION")
                gatt.writeDescriptor(descriptor)
            }

            updateStatusNotification("Connected. Monitoring air quality...")
        } catch (error: SecurityException) {
            updateStatusNotification("Bluetooth permission blocked notifications.")
        }
    }

    private fun handlePayload(payload: String) {
        val parts = payload.trim().split(",")
        if (parts.size < 3) return

        val reading = Reading(
            dustDensity = parts[0].toDoubleOrNull() ?: return,
            humidity = parts[1].toDoubleOrNull() ?: return,
            temperature = parts[2].toDoubleOrNull() ?: return,
            dhtValid = parts.getOrNull(3)?.trim() != "0",
        )

        // Broadcast raw payload to Flutter EventChannel via MainActivity receiver
        sendBroadcast(Intent("com.breathesafe.ACTION_SENSOR_DATA").putExtra("data", payload.trim()))

        latestReading = reading
        persistLatestReading(reading)
        updateStatusNotification(statusText(reading))
        maybeAlert(reading)
    }

    private fun maybeAlert(reading: Reading) {
        val prefs = prefs()
        val now = System.currentTimeMillis()
        if (now < prefs.getLong(PREF_SNOOZE_UNTIL, 0L)) return
        if (now - prefs.getLong(PREF_LAST_ALERT_AT, 0L) < 60_000L) return

        val alert = evaluateAlert(reading) ?: return
        prefs.edit().putLong(PREF_LAST_ALERT_AT, now).apply()
        notificationManager.notify(ALERT_NOTIFICATION_ID, buildAlertNotification(alert, reading))
        playLoopingAlarm()
    }

    private fun evaluateAlert(reading: Reading): Alert? {
        val prefs = prefs()
        val ageGroup = prefs.getString(PREF_AGE_GROUP, "adult")
        val conditions = prefs.getStringSet(PREF_CONDITIONS, emptySet()) ?: emptySet()
        val hasRespiratoryCondition = conditions.any {
            it == "asthma" || it == "chronicWheezing" || it == "dustAllergy"
        }
        val sensitiveAge = ageGroup == "child" || ageGroup == "senior"

        val warning = when {
            hasRespiratoryCondition ->
                reading.dustDensity > 35.0 || reading.humidity > 65.0 || reading.humidity < 35.0
            sensitiveAge ->
                reading.dustDensity > 35.0 || reading.humidity > 70.0 || reading.humidity < 30.0
            else -> reading.dustDensity > 55.0
        }

        if (!warning) return null

        val title = if (reading.dustDensity > 150.0) {
            "Poor air quality"
        } else {
            "Warning condition"
        }

        val message = when {
            reading.humidity > 70.0 -> "Humidity is high. Use ventilation or a dehumidifier."
            reading.humidity < 30.0 -> "Humidity is low. Dry air may irritate breathing."
            reading.dustDensity > 150.0 -> "Limit activity, close windows, and move to cleaner air."
            else -> "Air quality is dropping. Reduce exposure until it improves."
        }

        return Alert(title, message)
    }

    private fun buildStatusNotification(text: String): Notification {
        val contentIntent = PendingIntent.getActivity(
            this,
            1,
            Intent(this, MainActivity::class.java),
            pendingIntentFlags(),
        )

        return NotificationCompat.Builder(this, STATUS_CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle("BreatheSafe monitoring")
            .setContentText(text)
            .setStyle(NotificationCompat.BigTextStyle().bigText(text))
            .setContentIntent(contentIntent)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }

    private fun buildAlertNotification(alert: Alert, reading: Reading): Notification {
        val alertIntent = Intent(this, AlertActivity::class.java).apply {
            putExtra(EXTRA_ALERT_TITLE, alert.title)
            putExtra(EXTRA_ALERT_MESSAGE, alert.message)
            putExtra(EXTRA_READING_TEXT, statusText(reading))
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
        }
        val alertPendingIntent = PendingIntent.getActivity(
            this,
            2,
            alertIntent,
            pendingIntentFlags(),
        )
        val snoozeIntent = Intent(this, BreathSafeBleService::class.java)
            .setAction(ACTION_SNOOZE)
        val snoozePendingIntent = PendingIntent.getService(
            this,
            3,
            snoozeIntent,
            pendingIntentFlags(),
        )
        val body = "${alert.message} ${statusText(reading)}"

        return NotificationCompat.Builder(this, ALERT_CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(alert.title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setContentIntent(alertPendingIntent)
            .setFullScreenIntent(alertPendingIntent, true)
            .addAction(
                R.drawable.ic_notification,
                "Snooze ${prefs().getInt(PREF_SNOOZE_MINUTES, 15)} min",
                snoozePendingIntent,
            )
            .setAutoCancel(true)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .build()
    }

    private fun updateStatusNotification(text: String) {
        notificationManager.notify(STATUS_NOTIFICATION_ID, buildStatusNotification(text))
    }

    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return

        val statusChannel = NotificationChannel(
            STATUS_CHANNEL_ID,
            "BreatheSafe monitor",
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = "Shows live background air readings."
        }

        val soundUri = Uri.parse("android.resource://$packageName/${R.raw.breathsafe_alert}")
        val audioAttributes = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_ALARM)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()
        val alertChannel = NotificationChannel(
            ALERT_CHANNEL_ID,
            "BreatheSafe alerts",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "Warns when air conditions are unsafe."
            setSound(soundUri, audioAttributes)
            enableVibration(true)
        }

        notificationManager.createNotificationChannel(statusChannel)
        notificationManager.createNotificationChannel(alertChannel)
    }

    private fun snoozeAlerts() {
        stopLoopingAlarm()
        val minutes = prefs().getInt(PREF_SNOOZE_MINUTES, 15)
        val until = System.currentTimeMillis() + minutes * 60_000L
        prefs().edit().putLong(PREF_SNOOZE_UNTIL, until).apply()
        notificationManager.cancel(ALERT_NOTIFICATION_ID)
        updateStatusNotification("Alerts snoozed for $minutes minutes.")
    }

    private fun stopSelfCleanly() {
        stopLoopingAlarm()
        stopBleScan()
        closeGatt()
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    private fun closeGatt() {
            // Tell flutter we are disconnected
            sendBroadcast(Intent("com.breathesafe.ACTION_CONNECTION_STATE").putExtra("connected", false))
        try {
            bluetoothGatt?.close()
        } catch (_: Exception) {
        }
        bluetoothGatt = null
    }

    private fun playLoopingAlarm() {
        if (mediaPlayer?.isPlaying == true) return

        try {
            audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
            val audioAttributes = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_ALARM)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build()

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                audioFocusRequest = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK)
                    .setAudioAttributes(audioAttributes)
                    .build()
                audioManager?.requestAudioFocus(audioFocusRequest!!)
            } else {
                @Suppress("DEPRECATION")
                audioManager?.requestAudioFocus(
                    null,
                    AudioManager.STREAM_ALARM,
                    AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK
                )
            }

            mediaPlayer = MediaPlayer.create(this, R.raw.breathsafe_alert).apply {
                setAudioAttributes(audioAttributes)
                isLooping = true
                start()
            }

            // Auto-stop alarm after 2 minutes
            mainHandler.postDelayed({
                stopLoopingAlarm()
            }, 120_000)

        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun stopLoopingAlarm() {
        try {
            mediaPlayer?.stop()
            mediaPlayer?.release()
            mediaPlayer = null

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                audioFocusRequest?.let { audioManager?.abandonAudioFocusRequest(it) }
            } else {
                @Suppress("DEPRECATION")
                audioManager?.abandonAudioFocus(null)
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun statusText(reading: Reading): String {
        return String.format(
            Locale.US,
            "Dust: %.1f ug/m3 | %.1f%% RH | %.1f°C",
            reading.dustDensity,
            reading.humidity,
            reading.temperature,
        )
    }

    private fun getPersistedReading(): Reading? {
        return with(prefs()) {
            val oldDust = getFloat(PREF_LAST_DUST_DENSITY, -1f).toDouble()
            val oldHum = getFloat(PREF_LAST_HUMIDITY, -1f).toDouble()
            val oldTemp = getFloat(PREF_LAST_TEMPERATURE, -1f).toDouble()
            val oldValid = getBoolean(PREF_LAST_DHT_VALID, false)

            if (oldDust >= 0) {
                Reading(oldDust, oldHum, oldTemp, oldValid)
            } else {
                null
            }
        }
    }

    private fun persistLatestReading(reading: Reading) {
        prefs().edit()
            .putFloat(PREF_LAST_DUST_DENSITY, reading.dustDensity.toFloat())
            .putFloat(PREF_LAST_HUMIDITY, reading.humidity.toFloat())
            .putFloat(PREF_LAST_TEMPERATURE, reading.temperature.toFloat())
            .putBoolean(PREF_LAST_DHT_VALID, reading.dhtValid)
            .apply()
    }

    private fun isBreathSafeResult(result: ScanResult): Boolean {
        val record = result.scanRecord
        val hasService = record?.serviceUuids?.any { it.uuid == SERVICE_UUID } == true
        val advertisedName = record?.deviceName.orEmpty()
        val deviceName = try {
            if (hasBluetoothConnectPermission()) result.device.name.orEmpty() else ""
        } catch (_: SecurityException) {
            ""
        }

        return hasService || advertisedName == DEVICE_NAME || deviceName == DEVICE_NAME
    }

    private fun hasBlePermissions(): Boolean {
        val hasLocation = ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.ACCESS_FINE_LOCATION,
        ) == PackageManager.PERMISSION_GRANTED

        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
            return hasLocation
        }

        return hasLocation &&
            ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.BLUETOOTH_SCAN,
            ) == PackageManager.PERMISSION_GRANTED &&
            hasBluetoothConnectPermission()
    }

    private fun hasBluetoothConnectPermission(): Boolean {
        return Build.VERSION.SDK_INT < Build.VERSION_CODES.S ||
            ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.BLUETOOTH_CONNECT,
            ) == PackageManager.PERMISSION_GRANTED
    }

    private fun pendingIntentFlags(): Int {
        return PendingIntent.FLAG_UPDATE_CURRENT or
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_IMMUTABLE
            } else {
                0
            }
    }

    private fun prefs() = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    private data class Reading(
        val dustDensity: Double,
        val humidity: Double,
        val temperature: Double,
        val dhtValid: Boolean,
    )

    private data class Alert(
        val title: String,
        val message: String,
    )

    companion object {
        const val PREFS_NAME = "breathsafe_background"
        const val PREF_ENABLED = "enabled"
        const val PREF_SNOOZE_MINUTES = "snooze_minutes"
        const val PREF_AGE_GROUP = "age_group"
        const val PREF_CONDITIONS = "conditions"
        const val PREF_SNOOZE_UNTIL = "snooze_until"
        const val PREF_LAST_ALERT_AT = "last_alert_at"
        const val PREF_LAST_DUST_DENSITY = "last_dust_density"
        const val PREF_LAST_TEMPERATURE = "last_temperature"
        const val PREF_LAST_HUMIDITY = "last_humidity"
        const val PREF_LAST_DHT_VALID = "last_dht_valid"
        const val PREF_IS_CONNECTED = "is_connected"
        const val PREF_LAST_CONNECTED_MAC = "last_connected_mac"

        const val ACTION_START = "com.breathesafe.breathe_safe.START_MONITOR"
        const val ACTION_STOP = "com.breathesafe.breathe_safe.STOP_MONITOR"
        const val ACTION_SNOOZE = "com.breathesafe.breathe_safe.SNOOZE_ALERTS"
        
        const val ACTION_MANUAL_START_SCAN = "com.breathesafe.breathe_safe.MANUAL_START_SCAN"
        const val ACTION_MANUAL_STOP_SCAN = "com.breathesafe.breathe_safe.MANUAL_STOP_SCAN"
        const val ACTION_MANUAL_CONNECT = "com.breathesafe.breathe_safe.MANUAL_CONNECT"
        const val ACTION_MANUAL_DISCONNECT = "com.breathesafe.breathe_safe.MANUAL_DISCONNECT"

        const val EXTRA_ALERT_TITLE = "alert_title"
        const val EXTRA_ALERT_MESSAGE = "alert_message"
        const val EXTRA_READING_TEXT = "reading_text"

        private const val DEVICE_NAME = "BreatheSafe_Device"
        private const val STATUS_CHANNEL_ID = "breathsafe_monitor"
        private const val ALERT_CHANNEL_ID = "breathsafe_alerts"
        private const val STATUS_NOTIFICATION_ID = 1001
        private const val ALERT_NOTIFICATION_ID = 1002

        private val SERVICE_UUID: UUID =
            UUID.fromString("4fafc201-1fb5-459e-8fcc-c5c9c331914b")
        private val CHARACTERISTIC_UUID: UUID =
            UUID.fromString("beb5483e-36e1-4688-b7f5-ea07361b26a8")
        private val CCCD_UUID: UUID =
            UUID.fromString("00002902-0000-1000-8000-00805f9b34fb")
    }
}
