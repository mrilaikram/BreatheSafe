# BreatheSafe

BreatheSafe is a comprehensive Android application designed to monitor your local air quality using a custom Bluetooth Low Energy (BLE) sensor device. Built with a Flutter frontend and a robust native Kotlin background service, BreatheSafe ensures that you are constantly protected from poor air quality, even when the app is closed or your phone is locked.

## 🚀 Key Features

*   **Real-time Air Monitoring:** Tracks Dust Density (via Sharp GP2Y1010AU0F sensor), Temperature, and Humidity (via DHT22 sensor) by connecting to a custom ESP32/BLE hardware device.
*   **Custom Health Profiles:** Automatically adjusts safety thresholds based on the user's age group and respiratory conditions (e.g., Asthma, Chronic Wheezing).
*   **Persistent Background Connection:** A native Android background service (`BreathSafeBleService`) maintains the BLE connection reliably. If the app is swiped away, the background service continues monitoring without interruption.
*   **Full-Screen Lock Screen Alarms:** When air conditions drop to dangerous levels, BreatheSafe triggers a high-priority, full-screen alert that forcefully wakes up the screen and bypasses the lock screen (`FLAG_SHOW_WHEN_LOCKED`, `FLAG_TURN_SCREEN_ON`).
*   **Continuous Siren with Audio Focus:** The alarm uses Android's `MediaPlayer` to play a continuous looping siren, requesting Audio Focus to duck other media until you explicitly snooze or dismiss the alert.
*   **Instant UI Re-sync:** Re-opening the app instantly re-syncs the UI state with the background service's connection using `SharedPreferences`, avoiding unnecessary reconnections.

## 📱 Tech Stack

*   **Frontend:** [Flutter](https://flutter.dev/) (Dart)
*   **Backend / System Services:** Native Android (Kotlin)
*   **Communication:** Flutter MethodChannels & BLE (Bluetooth Low Energy)
*   **State Management:** SharedPreferences & Native Android Intents

## 🛠️ Hardware Requirements

BreatheSafe is designed to pair with a custom BLE peripheral (like an ESP32) advertising the following specifications:
*   **Service UUID:** `4fafc201-1fb5-459e-8fcc-c5c9c331914b`
*   **Characteristic UUID:** `beb5483e-36e1-4688-b7f5-ea07361b26a8`
*   **Payload Format:** `Sharp GP2Y1010AU0F_RAW,DHT_VALID,HUMIDITY,TEMPERATURE` (e.g., `1250,1,45.5,22.3`)

## ⚙️ Installation & Setup

1.  **Clone the repository:**
    ```bash
    git clone https://github.com/mrilaikram/BreatheSafe.git
    cd BreatheSafe
    ```
2.  **Install Flutter dependencies:**
    ```bash
    flutter pub get
    ```
3.  **Build the Release APK:**
    ```bash
    flutter build apk --release
    ```
    *Note: APK size reduction (ProGuard/R8) has been manually tuned to prioritize background service stability.*

## 🔒 Permissions Required

To function properly, the app requests the following Android permissions:
*   `BLUETOOTH_SCAN` & `BLUETOOTH_CONNECT` (For discovering and connecting to the sensor)
*   `ACCESS_FINE_LOCATION` (Required by Android for BLE scanning)
*   `POST_NOTIFICATIONS` (For the ongoing background monitor and alarms)
*   `USE_FULL_SCREEN_INTENT` (To wake the screen during critical alerts)

## 👤 Author
Developed by **[mrilaikram](https://github.com/mrilaikram)**.
