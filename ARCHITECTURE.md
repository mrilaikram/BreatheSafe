# 🏛️ BreathSafe Architecture

Technical documentation of the BreathSafe system design, components, and data flow.

## 📐 System Overview

BreathSafe is a client-server architecture where:
- **Client**: Flutter app (mobile/desktop) handles UI, state management, and user interactions
- **Server**: ESP32 microcontroller broadcasts sensor data via Bluetooth Low Energy (BLE)
- **Communication**: Asynchronous BLE notifications with comma-separated payload
- **Storage**: Local persistence via shared_preferences (SQLite on mobile)

```
┌──────────────────────────────────────┐
│     FLUTTER APP (Client)             │
├──────────────────────────────────────┤
│ Presentation Layer                   │
│ ├─ screens/ (UI screens)             │
│ ├─ widgets/ (reusable components)    │
│ └─ theme/ (Material Design)          │
├──────────────────────────────────────┤
│ Service Layer                        │
│ ├─ BleSensorService                  │
│ ├─ ProfileService                    │
│ └─ BackgroundAlertService            │
├──────────────────────────────────────┤
│ Data Layer                           │
│ ├─ shared_preferences (local storage)│
│ └─ in-memory streams & models        │
└──────────────────────────────────────┘
            ↕ BLE (Bluetooth LE)
┌──────────────────────────────────────┐
│     ESP32 (Hardware Server)          │
├──────────────────────────────────────┤
│ Sensor Layer                         │
│ ├─ DHT22 (GPIO 4)                    │
│ └─ MQ135 (GPIO 34 ADC)               │
├──────────────────────────────────────┤
│ Communication Layer                  │
│ └─ BLE Server (Gatt Notifications)   │
└──────────────────────────────────────┘
```

## 🎯 Key Components

### 1. BleSensorService

**File**: [lib/services/ble_sensor_service.dart](lib/services/ble_sensor_service.dart)

**Responsibility**: Manage all BLE communication with ESP32 sensor node.

**Key Methods**:
- `scanForDevices()` — Scan for nearby BLE devices
- `connectToDevice(device)` — Establish BLE connection
- `disconnectDevice()` — Close BLE connection
- `startListening()` — Subscribe to sensor notifications
- `stopListening()` — Unsubscribe from notifications

**Streams** (Observable Data):
```dart
// Emits SensorData every time notification arrives from ESP32
Stream<SensorData> sensorStream

// Emits true when connected, false when disconnected
Stream<bool> connectionStateStream

// Emits list of discovered devices during scan
Stream<List<BleScanDevice>> scanDevicesStream

// Emits true while scanning, false when complete
Stream<bool> scanStateStream
```

**Data Models**:
```dart
class SensorData {
  final double airPurity;          // 0-100%
  final double humidity;           // 0-100%
  final double temperature;        // -40 to 125°C
  final double pm25;               // Estimated µg/m³
  final double co2;                // Estimated ppm
  final double voc;                // Estimated ppb
  final DateTime timestamp;        // When data was received
  final bool isSimulated;          // True in demo mode
  final int? mq135Raw;             // Raw ADC 0-4095
  final bool dhtValid;             // DHT checksum valid
}

class BleScanDevice {
  final BluetoothDevice device;    // FlutterBluePlus device object
  final String name;               // Device name/SSID
  final String remoteId;           // MAC address
  final int rssi;                  // Signal strength (dBm)
  final bool isBreatheSafe;        // Is "BreatheSafe_Device"?
}
```

**Payload Parsing Logic**:
```
Incoming BLE notification: "75,55.2,23.5,1250,1"
                            │   │     │    │    └─ dhtValid (1=true)
                            │   │     │    └─ mq135Raw (0-4095)
                            │   │     └─ temperature (°C)
                            │   └─ humidity (%)
                            └─ airPurity (%)

Processing:
1. Split by comma → [75, 55.2, 23.5, 1250, 1]
2. Parse to doubles & ints
3. Calculate estimated PM2.5, CO2, VOC from airPurity
4. Create SensorData object
5. Emit to sensorStream
6. Check BackgroundAlertService thresholds
```

**Demo Mode** (Linux):
When on Linux without BLE hardware, BleSensorService:
- Generates random sensor data every 2 seconds
- Simulates gradual air quality changes
- Allows testing UI without ESP32

### 2. ProfileService

**File**: [lib/services/profile_service.dart](lib/services/profile_service.dart)

**Responsibility**: Manage user profile data and preferences persistence.

**Key Methods**:
- `loadProfile()` — Load user data from local storage
- `saveProfile(profile)` — Persist profile changes
- `updateThreshold(threshold)` — Update alert threshold
- `getAlertThreshold()` — Retrieve current threshold

**Data Persistence**:
```dart
// SharedPreferences key-value storage
User Profile Keys:
├─ user_name: String (e.g., "John Doe")
├─ device_id: String (ESP32 MAC address)
├─ alert_threshold: int (0-100)
├─ last_connected: DateTime
├─ notification_enabled: bool
└─ theme_preference: String (light/dark)
```

**User Profile Model**:
```dart
class UserProfile {
  final String name;
  final String deviceId;
  final int alertThreshold;        // Below this %, trigger alert
  final bool notificationsEnabled;
  final DateTime lastConnected;
}
```

### 3. BackgroundAlertService

**File**: [lib/services/background_alert_service.dart](lib/services/background_alert_service.dart)

**Responsibility**: Monitor sensor data and trigger local notifications when thresholds exceeded.

**Key Methods**:
- `checkAlertThreshold(sensorData)` — Compare against user threshold
- `sendNotification(title, body)` — Trigger local notification
- `setAlertThreshold(value)` — Update threshold

**Alert Logic**:
```
if (sensorData.airPurity < UserProfile.alertThreshold) {
    if (lastAlertTime < now - 5 minutes) {  // Prevent spam
        sendNotification(
            title: "🚨 Air Quality Alert",
            body: "Air purity dropped to ${sensorData.airPurity}%"
        )
        lastAlertTime = now
    }
}
```

### 4. Screens

#### HomeScreen
- **Purpose**: Display real-time sensor data
- **Components**:
  - `AirPurityRing` — Circular progress indicator (0-100%)
  - `SparklineChart` — Mini trend graph (last 60 readings)
  - `MiniTelemetryRing` — Secondary metrics display
  - Connection status indicator
- **Data Flow**: Listens to `BleSensorService.sensorStream`

#### SettingsScreen
- **Purpose**: Device management and preferences
- **Features**:
  - BLE device scanner
  - Connection status
  - Threshold configuration
  - Profile editing
- **Data Flow**: Uses `BleSensorService` for scan/connect, `ProfileService` for persistence

#### SplashScreen
- **Purpose**: Initial app launch
- **Logic**:
  1. Check if user profile exists
  2. Load saved preferences
  3. Check if last connected device is available
  4. Route to Onboarding (new) or Home (returning)

#### OnboardingScreen
- **Purpose**: First-time user setup
- **Steps**:
  1. Welcome message
  2. Permissions request (Bluetooth, Location)
  3. Device scan & connection
  4. Threshold configuration
  5. Route to Home

## 🔄 Data Flow

### Sequence: User Launches App

```
1. main() 
   └─ BreatheSafeApp.build()
      └─ SplashScreen (check profile)
         ├─ ProfileService.loadProfile()
         ├─ If new user → OnboardingScreen
         └─ If returning → HomeScreen

2. HomeScreen.build()
   ├─ BleSensorService.sensorStream
   │  └─ Listen for updates
   ├─ BleSensorService.connectionStateStream
   │  └─ Show connection indicator
   └─ Render UI with latest SensorData
```

### Sequence: Connect to Device

```
1. SettingsScreen → Tap "Scan Devices"
   └─ BleSensorService.scanForDevices()
      ├─ Request Bluetooth permission
      ├─ Start BLE scan (30 seconds)
      ├─ Emit BleScanDevices to scanDevicesStream
      └─ User sees list of devices

2. User taps "BreatheSafe_Device"
   └─ BleSensorService.connectToDevice(device)
      ├─ Connect via GATT
      ├─ Discover services & characteristics
      ├─ Subscribe to notifications
      ├─ Emit true to connectionStateStream
      ├─ ProfileService.saveProfile() (save device_id)
      └─ HomeScreen shows "Connected" badge

3. BleSensorService receives notification
   └─ Parse payload
      ├─ Split "75,55.2,23.5,1250,1"
      ├─ Create SensorData object
      ├─ Emit to sensorStream
      └─ HomeScreen rebuilds with new data

4. BackgroundAlertService checks threshold
   └─ if (airPurity < threshold)
      └─ sendNotification() (local push)
```

### Sequence: User Disconnects Device

```
1. App goes to background
   └─ BleSensorService.stopListening()
      ├─ Unsubscribe from notifications
      ├─ Close BLE connection
      └─ Emit false to connectionStateStream

2. App returns to foreground
   └─ BleSensorService.startListening()
      ├─ Reconnect to last known device
      ├─ Re-subscribe to notifications
      └─ Resume receiving SensorData
```

## 📊 State Management Pattern

BreathSafe uses **Stream-based Reactive Programming** (not GetX, Provider, or Riverpod):

```dart
// Service exposes streams
Stream<SensorData> get sensorStream => _sensorController.stream;

// Widget listens to stream
StreamBuilder<SensorData>(
  stream: bleSensorService.sensorStream,
  builder: (context, snapshot) {
    if (snapshot.hasData) {
      return DisplayData(snapshot.data!);
    }
    return LoadingIndicator();
  },
)
```

**Advantages**:
- Simple, no additional packages needed
- Decoupled services from UI
- Easy to test (mock streams)
- Minimal overhead

## 🔌 BLE Protocol Details

### Service UUID
```
4fafc201-1fb5-459e-8fcc-c5c9c331914b
```

### Characteristic UUID
```
beb5483e-36e1-4688-b7f5-ea07361b26a8
(Notification enabled)
```

### Notification Format

**New Format (5 fields)** — Recommended
```
airPurity,humidity,temperature,mq135Raw,dhtValid
Example: 75,55.2,23.5,1250,1
```

**Legacy Format (3 fields)** — Still supported
```
airPurity,humidity,temperature
Example: 75,55.2,23.5
```

### Notification Frequency
- ESP32 sends every 2 seconds (2000 ms interval)
- App receives notification when BLE stack delivers (usually same 2s interval)
- HomeScreen rebuilds at most once per notification

## 🛠️ Platform-Specific Implementation

### Android BLE
- Uses `FlutterBluePlus` package
- Handles permission requests automatically
- Background connections supported via `BLE_CONNECT` permission (API 31+)

**Manifest Permissions** (`AndroidManifest.xml`):
```xml
<uses-permission android:name="android.permission.BLUETOOTH" />
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN" />
<uses-permission android:name="android.permission.BLUETOOTH_SCAN" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
```

### iOS BLE
- Uses `CoreBluetooth` framework via FlutterBluePlus
- Requires `NSBluetoothPeripheralUsageDescription` in `Info.plist`
- Background mode: `App communicates with a device that requires a connection to function`

### Linux Desktop
- No native BLE support; uses simulated data
- `BleSensorService` detects platform & generates mock data
- Perfect for UI development & testing without hardware

## 💾 Local Storage

**SharedPreferences** (key-value store):
```
user_profile: JSON string
device_connections: JSON array of past device IDs
settings: JSON object (theme, notifications, etc.)
last_sensor_data: JSON string (for display on cold start)
```

**Example stored profile**:
```json
{
  "name": "John",
  "deviceId": "AA:BB:CC:DD:EE:FF",
  "alertThreshold": 50,
  "notificationsEnabled": true,
  "lastConnected": "2026-06-21T14:30:00Z"
}
```

## 🔐 Security Considerations

1. **No Encryption**: BLE payload is unencrypted (not sensitive data)
2. **Device Pairing**: Not required; any BreatheSafe_Device is trusted
3. **Permissions**: Request Bluetooth + Location (Android requires location for BLE scanning)
4. **Local Storage**: Profile data stored in device's secure shared_preferences

**Future Improvements**:
- Add BLE pairing requirement
- Encrypt stored credentials
- Add SSL/TLS for any cloud sync

## 🧪 Testing Architecture

### Unit Tests
```dart
// Mock BleSensorService
class MockBleSensorService {
  final _sensorController = StreamController<SensorData>.broadcast();
  Stream<SensorData> get sensorStream => _sensorController.stream;
  
  void emitTestData(SensorData data) => _sensorController.add(data);
}

// Test HomeScreen with mock data
testWidgets('HomeScreen displays sensor data', (tester) async {
  final mockService = MockBleSensorService();
  await tester.pumpWidget(
    MockApp(child: HomeScreen(bleSensorService: mockService))
  );
  
  mockService.emitTestData(testSensorData);
  await tester.pumpAndSettle();
  
  expect(find.text('75'), findsOneWidget); // Air purity
});
```

### Integration Tests
- Test real BLE connection (requires ESP32 device)
- Test end-to-end: device scan → connect → receive data
- Test background alerts triggering

## 📈 Performance Optimization

1. **BLE Subscription**: Only subscribe when app is active
2. **UI Rebuilds**: HomeScreen uses StreamBuilder (not full rebuild)
3. **Memory**: Limit sensor history to last 100 readings
4. **Battery**: Stop scanning immediately after finding device
5. **Animations**: Smooth transitions (300ms) on metric updates

## 🔄 Extension Points

### Add New Sensors
1. Extend ESP32 payload (add new field)
2. Update `SensorData` model in `ble_sensor_service.dart`
3. Update parsing logic
4. Add widget to display new metric

### Add Cloud Sync
1. Create `CloudService` with upload method
2. Trigger upload after profile save
3. Implement conflict resolution

### Add Data History
1. Extend `ProfileService` to use SQLite instead of shared_preferences
2. Store timestamped readings
3. Add analytics screen with charts

---

**Next Steps**: See [INSTALLATION.md](INSTALLATION.md) for setup or [README.md](README.md) for usage.
