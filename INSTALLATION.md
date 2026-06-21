# 📥 BreathSafe Installation Guide

Complete step-by-step instructions to get BreathSafe up and running on your device and ESP32 sensor node.

## 🖥️ Flutter Development Environment Setup

### Step 1: Install Flutter

#### macOS
```bash
# Download Flutter SDK
cd ~/Development
git clone https://github.com/flutter/flutter.git -b stable

# Add Flutter to PATH
export PATH="$PATH:`pwd`/flutter/bin"

# Verify installation
flutter doctor
```

#### Windows
1. Download Flutter SDK from [flutter.dev/docs/development/tools/sdk/windows](https://flutter.dev/docs/development/tools/sdk/windows)
2. Extract to `C:\src\flutter`
3. Add `C:\src\flutter\bin` to PATH environment variable
4. Run Command Prompt as Admin:
```bash
flutter doctor
```

#### Linux (Ubuntu/Debian)
```bash
sudo apt update
sudo apt install -y clang cmake git ninja-build pkg-config libgtk-3-dev

# Download Flutter SDK
cd ~/Development
git clone https://github.com/flutter/flutter.git -b stable
export PATH="$PATH:$HOME/Development/flutter/bin"

# Make permanent (add to ~/.bashrc or ~/.zshrc)
echo 'export PATH="$PATH:$HOME/Development/flutter/bin"' >> ~/.bashrc
source ~/.bashrc

# Verify installation
flutter doctor
```

### Step 2: Install Platform-Specific Tools

#### For Android Development
```bash
# Set up Android Studio / Android SDK
flutter config --android-sdk /path/to/android/sdk
flutter config --android-studio-path /path/to/android-studio

# Check status
flutter doctor -v
```

**Requirements**:
- Android SDK API 21 or higher
- Android Build Tools 31+

#### For iOS Development (macOS only)
```bash
# Install Xcode Command Line Tools
xcode-select --install

# Install CocoaPods
sudo gem install cocoapods

# Verify
flutter doctor -v
```

**Requirements**:
- Xcode 12+
- iOS 13.0+ deployment target

#### For Linux Desktop
```bash
# Ubuntu/Debian
sudo apt install -y libgtk-3-dev pkg-config cmake ninja-build

# Fedora/RHEL
sudo dnf install -y gcc cmake ninja-build gtk3-devel

# Arch
sudo pacman -S gcc cmake ninja gtk3

flutter config --enable-linux-desktop
flutter doctor
```

#### For Web
```bash
flutter config --enable-web
flutter doctor
```

### Step 3: Create Device/Emulator

#### Android Emulator
```bash
flutter emulators
flutter emulators create --name "Pixel_5"
flutter emulators launch Pixel_5
```

#### iOS Simulator (macOS)
```bash
open -a Simulator
flutter run
```

#### Physical Device
- **Android**: Enable Developer Mode (tap Build Number 7x in Settings) → Enable USB Debugging
- **iOS**: Connect via USB → Trust computer when prompted

## 📱 BreathSafe App Installation

### Step 1: Clone Repository

```bash
cd ~/Development
git clone https://github.com/ilaikram/Breathsafe.git
cd Breathsafe
```

### Step 2: Install Dependencies

```bash
# Get all Dart dependencies
flutter pub get

# Check project health
flutter doctor
```

### Step 3: Run on Target Device/Emulator

#### Android
```bash
# List available Android devices
flutter devices

# Run on specific device
flutter run -d <device-id>

# Or let Flutter choose
flutter run
```

#### iOS (macOS)
```bash
# Pod dependencies (one-time)
cd ios
pod install
cd ..

# Run on simulator
flutter run -d "iPhone 15"

# Or on physical device
flutter run
```

#### Linux Desktop
```bash
flutter run -d linux
# Note: Runs in demo mode with simulated sensor data
```

#### Web (Chrome)
```bash
flutter run -d chrome
```

### Step 4: App Permissions (Mobile)

**Android**:
1. Open app → Settings → Phone Settings → Apps → BreathSafe
2. Grant: Location, Bluetooth
3. Restart app

**iOS**:
1. Open app → Settings → Privacy
2. Grant Bluetooth access (Bluetooth Sharing)
3. Return to app

## 🔧 ESP32 Firmware Installation

### Prerequisites

- **Hardware**:
  - ESP32 development board (ESP32-WROOM recommended)
  - Micro-USB cable for programming
  - DHT22 sensor with 10kΩ pull-up resistor
  - MQ135 air quality sensor
  - Breadboard and jumper wires

- **Software**:
  - Arduino IDE 2.0+ or PlatformIO
  - CH340G USB driver (if using some ESP32 boards)

### Step 1: Install Arduino IDE & ESP32 Support

#### Arduino IDE
1. Download from [arduino.cc](https://www.arduino.cc/en/software)
2. Install on your system

#### Add ESP32 Board Support
1. File → Preferences
2. Paste into "Additional Boards Manager URLs":
   ```
   https://raw.githubusercontent.com/espressif/arduino-esp32/gh-pages/package_esp32_index.json
   ```
3. Tools → Board Manager → Search "esp32" → Install by Espressif Systems
4. Tools → Board → Select "ESP32 Dev Module" (or your variant)

### Step 2: Install Required Libraries

**In Arduino IDE**:
1. Sketch → Include Library → Manage Libraries
2. Search & install:
   - `DHT sensor library` by Adafruit (v1.4.4+)
   - `Arduino BLE` (built-in for ESP32)
   - `BLE for ESP32` (optional, if using BLEDevice)

**Via Terminal** (PlatformIO):
```bash
pio pkg install --library "adafruit/DHT sensor library"
```

### Step 3: Hardware Wiring

Connect components to ESP32 following this diagram:

```
ESP32 PINOUT (Pin names on development board)
┌─────────────────────────────────────────┐
│ ESP32 Dev Module                        │
│                                         │
│  GND ─────────────────────────── GND    │  (Connect MQ135 GND & DHT22 GND)
│  3V3 ─────────────────────────── 3V3    │  (Connect DHT22 VCC)
│  5V  ─────────────────────────── 5V     │  (Connect MQ135 VCC)
│  D4  ──→ (GPIO 4)  DHT22 DATA LINE      │
│  D34 ──→ (GPIO 34) MQ135 ANALOG OUTPUT   │
│                                         │
└─────────────────────────────────────────┘

DHT22 WIRING:
├─ Pin 1 (VCC)  → ESP32 3V3
├─ Pin 2 (DATA) → ESP32 GPIO 4 + 10kΩ resistor to 3V3
├─ Pin 3 (NC)   → Not connected
└─ Pin 4 (GND)  → ESP32 GND

MQ135 WIRING:
├─ VCC → ESP32 5V
├─ GND → ESP32 GND
├─ A0  → ESP32 GPIO 34 (ADC)
└─ D0  → Not used (Digital output)

RESISTOR:
└─ 10kΩ pull-up resistor: Connect between DHT22 DATA (GPIO 4) and 3V3
   (Some DHT22 modules have this built-in; verify before adding)
```

### Step 4: Upload Firmware

1. **Connect ESP32** to computer via Micro-USB cable
2. **Open Arduino IDE** → File → Open
3. **Navigate to** `esp32_firmware/esp32_firmware.ino` and open
4. **Select Port**:
   - Tools → Port → Select your ESP32 port (e.g., `/dev/ttyUSB0` or `COM3`)
5. **Verify & Upload**:
   ```
   Tools → Upload (or Ctrl+U)
   ```
6. Wait for upload to complete. You should see:
   ```
   Leaving... Hard resetting via RTS pin...
   ```

### Step 5: Verify ESP32 Communication

**Monitor BLE Broadcasts**:
1. Install nRF Connect app (Android/iOS)
2. Open app → Scan
3. Look for device named "BreatheSafe_Device"
4. Tap to connect → Expand "Unknown Service" (UUID: 4fafc201-1fb5-459e...)
5. You should see notifications coming in every 2 seconds

**Serial Monitor** (Debug Output):
1. Tools → Serial Monitor (Ctrl+Shift+M)
2. Baud rate: 115200
3. You should see:
   ```
   [BLE] Server created
   [BLE] Service created
   [BLE] Characteristic created
   [BLE] Start advertising
   [DHT] Temperature: 23.5°C, Humidity: 55%
   [MQ135] Purity: 75%
   ```

## 🌍 Platform-Specific Notes

### Android
- **Minimum API**: 21 (Android 5.0)
- **Bluetooth Permissions**:
  - `android.permission.BLUETOOTH`
  - `android.permission.BLUETOOTH_ADMIN`
  - `android.permission.BLUETOOTH_SCAN` (Android 12+)
  - `android.permission.BLUETOOTH_CONNECT` (Android 12+)
  - `android.permission.ACCESS_FINE_LOCATION` (for BLE scanning)
- **File**: `android/app/src/main/AndroidManifest.xml`

### iOS
- **Minimum Deployment Target**: 13.0
- **Bluetooth Capability**: Handled by permission_handler package
- **App Transport Security**: Allow local network access in `ios/Runner/Info.plist`
- **Background Modes** (optional): Add `Background fetch`, `Remote notifications` for alerts

### Linux
- **Bluetooth Support**: Requires `bluez` and `bluez-tools`
  ```bash
  # Ubuntu/Debian
  sudo apt install -y bluez bluez-tools

  # Fedora
  sudo dnf install -y bluez
  ```
- **Demo Mode**: Enabled by default, no BLE hardware required

### macOS
- **Minimum Version**: 10.14
- **Bluetooth**: Automatic via permission_handler
- **Code Signing**: May be required for release builds

## 🧪 Testing Your Installation

### Test Flutter App
```bash
# Run tests
flutter test

# Check code quality
flutter analyze

# Run on device
flutter run --verbose
```

### Test ESP32
```bash
# Monitor serial output
screen /dev/ttyUSB0 115200
# Press Ctrl+A then Ctrl+\ to exit

# Or use Arduino IDE's Serial Monitor
# Tools → Serial Monitor → Baud 115200
```

### Integration Test
1. Start Flutter app
2. Navigate to Settings
3. Tap "Scan for Devices"
4. Verify "BreatheSafe_Device" appears in list
5. Tap to connect
6. Return to Home Screen
7. Verify live sensor readings display & update every 2 seconds

## ⚠️ Common Issues & Solutions

### "dart: Error: Could not find the inclusive start line for patch in ...,dart"
**Solution**: 
```bash
flutter clean
flutter pub get
flutter run
```

### Android: "Target Java compilation version not found"
**Solution**: Update `android/app/build.gradle.kts` to use Java 17+
```kotlin
compileOptions {
    sourceCompatibility = JavaVersion.VERSION_17
    targetCompatibility = JavaVersion.VERSION_17
}
```

### iOS: "Pod install failed"
**Solution**:
```bash
cd ios
rm Podfile.lock
pod repo update
pod install
cd ..
flutter run
```

### iOS: "permission_handler" requires minimum iOS 13
**Solution**: Open `ios/Podfile`, change `platform :ios` to:
```ruby
platform :ios, '13.0'
```

### ESP32: "pyserial not installed" when uploading
**Solution**:
```bash
pip install pyserial
```

### ESP32: "Unknown USB Serial Chip" on Windows
**Solution**: Install CH340G drivers from [wch.cn](http://wch.cn/downloads)

### ESP32: DHT22 reads are null/invalid
1. Verify 10kΩ pull-up resistor is connected to DATA line + 3V3
2. Try a different GPIO pin (e.g., GPIO 5)
3. Update esp32_firmware.ino: `#define DHTPIN 5`
4. Re-upload firmware

### ESP32: MQ135 always reads high
1. Wait 20+ minutes after power-on for sensor warm-up
2. Verify analog pin is GPIO 34, not GPIO 35 or 32
3. Check for proper grounding

### BLE Disconnects Frequently
**Mobile App**:
- Disable battery saver / power management for app
- Keep phone close to ESP32 (< 10 meters)
- Restart both app and ESP32

**ESP32**:
- Increase advertising interval in esp32_firmware.ino if needed
- Ensure power supply is stable (use USB power, not battery)

## 📦 Building for Release

### Android APK
```bash
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
```

### Android App Bundle (Google Play)
```bash
flutter build appbundle --release
# Output: build/app/outputs/bundle/release/app-release.aab
```

### iOS
```bash
flutter build ios --release
# Output: build/ios/iphoneos/
```

### Linux
```bash
flutter build linux --release
# Output: build/linux/x64/release/bundle/
```

## ✅ Verification Checklist

- [ ] Flutter environment installed (`flutter doctor` shows no errors)
- [ ] Dart SDK 3.10+ installed
- [ ] Android SDK/iOS deployment target configured
- [ ] All dependencies installed (`flutter pub get`)
- [ ] App runs on target device without crashes
- [ ] Bluetooth permissions granted on mobile
- [ ] ESP32 flashed with latest firmware
- [ ] ESP32 powered on & advertising "BreatheSafe_Device"
- [ ] App successfully connects to ESP32
- [ ] Sensor readings display in real-time
- [ ] Background alerts trigger when thresholds reached
- [ ] Settings & profile persistence works
- [ ] `flutter analyze` passes with no warnings

---

**Installation complete!** Proceed to [ARCHITECTURE.md](ARCHITECTURE.md) for technical details or [README.md](README.md) for usage instructions.
