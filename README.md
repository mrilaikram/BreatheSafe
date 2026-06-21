# 🌬️ BreathSafe

**BreatheSafe** is a cross-platform Flutter mobile app paired with an ESP32 IoT device that monitors real-time air quality, humidity, and temperature. Get instant alerts when air quality drops below safe thresholds.

![Flutter](https://img.shields.io/badge/Flutter-3.10+-blue?logo=flutter)
![Dart](https://img.shields.io/badge/Dart-3.10+-blue?logo=dart)
![ESP32](https://img.shields.io/badge/ESP32-BLE-green)
![License](https://img.shields.io/badge/License-MIT-green)
![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS%20%7C%20Linux%20%7C%20macOS-blue)

## ✨ Features

- 🔵 **Real-Time BLE Monitoring** — Live air quality metrics from ESP32 sensor node
- 🌡️ **Environmental Tracking** — Temperature & humidity readings via DHT22 sensor
- 💨 **Air Quality Metrics** — Air purity, PM2.5, CO2, and VOC estimates
- 🔔 **Smart Alerts** — Background notifications when air quality drops
- 👤 **User Profiles** — Personalized settings and preferences
- 📊 **Data Visualization** — Sparkline charts and air purity rings for easy interpretation
- 🖥️ **Cross-Platform** — Native support for Android, iOS, Linux, and macOS
- 🎮 **Demo Mode** — Built-in simulator for UI testing without ESP32 hardware
- ⚙️ **Settings Management** — Scan for devices, configure thresholds, manage preferences

## 🏗️ System Architecture

```
┌─────────────────────────────────────────┐
│        Flutter App (Mobile/Desktop)     │
│  ┌─────────────────────────────────┐    │
│  │  Home Screen                    │    │
│  │  - Air Quality Dashboard        │    │
│  │  - Real-time metrics & charts   │    │
│  └─────────────────────────────────┘    │
│  ┌─────────────────────────────────┐    │
│  │  Settings Screen                │    │
│  │  - Device scan & connection     │    │
│  │  - Threshold configuration      │    │
│  └─────────────────────────────────┘    │
│  ┌─────────────────────────────────┐    │
│  │  Services Layer                 │    │
│  │  - BleSensorService (BLE)       │    │
│  │  - ProfileService (user data)   │    │
│  │  - BackgroundAlertService       │    │
│  └─────────────────────────────────┘    │
└─────────────────────────────────────────┘
              ↕ (BLE)
┌─────────────────────────────────────────┐
│         ESP32 Sensor Node               │
│  ┌─────────────────────────────────┐    │
│  │  Sensor Inputs                  │    │
│  │  - DHT22 (Temp/Humidity)        │    │
│  │  - MQ135 (Air Quality)          │    │
│  └─────────────────────────────────┘    │
│  ┌─────────────────────────────────┐    │
│  │  BLE Server                     │    │
│  │  - Broadcasts data every 2s     │    │
│  └─────────────────────────────────┘    │
└─────────────────────────────────────────┘
```

## 📦 Requirements

### Mobile/Desktop App
- **Flutter**: 3.10.3 or higher
- **Dart**: 3.10+ SDK
- **BLE Capable Device** (Bluetooth 4.0+)

### ESP32 Hardware
- **Microcontroller**: ESP32 (BLE support)
- **Temperature/Humidity**: DHT22 (AM2302)
- **Air Quality**: MQ135 sensor

## 🚀 Quick Start

### Mobile Device (Android/iOS)

1. **Clone & Setup**
   ```bash
   git clone https://github.com/ilaikram/Breathsafe.git
   cd Breathsafe
   flutter pub get
   ```

2. **Flash ESP32 Firmware**
   - Open `esp32_firmware/esp32_firmware.ino` in Arduino IDE
   - Install DHT library: Sketch → Include Library → Manage Libraries → Search "DHT sensor library"
   - Select Tools → Board: "ESP32 Dev Module"
   - Upload to your ESP32

3. **Run App**
   ```bash
   flutter run
   ```

4. **Connect Device**
   - Settings → Scan for Devices → Select "BreatheSafe_Device"
   - Return to Home to view live data

### Linux Desktop (Demo Mode)

```bash
flutter run -d linux
```

No ESP32 required — uses simulated data to test UI.

## 📡 BLE Communication

**Payload Format**:
```
airPurity,humidity,temperature,mq135Raw,dhtValid
Example: 75,55.2,23.5,1250,1
```

**Service UUID**: `4fafc201-1fb5-459e-8fcc-c5c9c331914b`  
**Characteristic UUID**: `beb5483e-36e1-4688-b7f5-ea07361b26a8`

## 📚 Documentation

- **[INSTALLATION.md](INSTALLATION.md)** — Detailed setup for all platforms
- **[ARCHITECTURE.md](ARCHITECTURE.md)** — Technical system design
- **[CONTRIBUTING.md](CONTRIBUTING.md)** — How to contribute

## 🧪 Testing & Validation

```bash
# Analyze code
flutter analyze

# Run tests
flutter test

# Build release APK
flutter build apk --release
```

## 🐛 Troubleshooting

| Issue | Solution |
|-------|----------|
| Android: Bluetooth not working | Grant runtime permissions in app settings |
| iOS: Permission Handler error | Update iOS deployment target to 13.0+ |
| ESP32: Not in device list | Ensure powered on, correct firmware flashed, location permission granted on Android |
| MQ135 reads high | Wait 20+ minutes for sensor warm-up |

See [INSTALLATION.md](INSTALLATION.md) for detailed troubleshooting.

## 📄 License

MIT License — see [LICENSE.md](LICENSE.md)

## 🤝 Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on:
- Code style
- Development setup
- Pull request process
- Testing requirements

---

**Built with ❤️ using Flutter & ESP32** 🌬️✨
