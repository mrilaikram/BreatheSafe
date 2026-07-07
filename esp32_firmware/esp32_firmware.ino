#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>
#include <DHT.h>

// --- PIN CONFIGURATION ---
#define DHTPIN 4       // Digital pin connected to the DHT sensor
#define DHTTYPE DHT22  // DHT 22 (AM2302)
#define MEASURE_PIN 34 // Analog pin connected to Sharp GP2Y1010AU0F
#define LED_POWER_PIN 2 // Digital pin to control Sharp GP2Y1010AU0F LED

// --- BLE UUIDS ---
// Custom Service UUID
#define SERVICE_UUID        "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
// Custom Characteristic UUID for Notifications
#define CHARACTERISTIC_UUID "beb5483e-36e1-4688-b7f5-ea07361b26a8"

// --- SENSORS & BLE COMPONENTS ---
DHT dht(DHTPIN, DHTTYPE);
BLEServer* pServer = NULL;
BLECharacteristic* pCharacteristic = NULL;
bool deviceConnected = false;
bool oldDeviceConnected = false;

// Variables to hold sensor readings
float temperature = 0.0;
float humidity = 0.0;
float dustDensity = 0.0;
bool dhtValid = false;

// --- BLE SERVER CALLBACKS ---
class MyServerCallbacks: public BLEServerCallbacks {
    void onConnect(BLEServer* pServer) {
      deviceConnected = true;
      Serial.println("Device connected!");
    };

    void onDisconnect(BLEServer* pServer) {
      deviceConnected = false;
      Serial.println("Device disconnected!");
    }
};

void setup() {
  Serial.begin(115200);
  Serial.println("Starting BreatheSafe ESP32 Node...");

  // Initialize Sensors
  dht.begin();
  pinMode(LED_POWER_PIN, OUTPUT);
  pinMode(MEASURE_PIN, INPUT);

  // Initialize BLE
  BLEDevice::init("BreatheSafe_Device");
  pServer = BLEDevice::createServer();
  pServer->setCallbacks(new MyServerCallbacks());

  // Create the BLE Service
  BLEService *pService = pServer->createService(SERVICE_UUID);

  // Create a BLE Characteristic
  pCharacteristic = pService->createCharacteristic(
                      CHARACTERISTIC_UUID,
                      BLECharacteristic::PROPERTY_READ   |
                      BLECharacteristic::PROPERTY_NOTIFY
                    );

  // Add a CCCD descriptor to allow client to enable notifications
  pCharacteristic->addDescriptor(new BLE2902());

  // Start the service
  pService->start();

  // Start advertising
  BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->addServiceUUID(SERVICE_UUID);
  pAdvertising->setScanResponse(true);
  pAdvertising->setMinPreferred(0x06);
  pAdvertising->setMinPreferred(0x12);
  BLEDevice::startAdvertising();
  Serial.println("BLE Advertising started. Waiting for a client connection to notify...");
}

void loop() {
  // Read Sensors
  // 1. DHT22
  float h = dht.readHumidity();
  float t = dht.readTemperature(); // Celsius
  
  dhtValid = !isnan(h) && !isnan(t);
  if (dhtValid) {
    humidity = h;
    temperature = t;
  }

  // 2. Sharp GP2Y1010AU0F (Dust / Air Quality)
  digitalWrite(LED_POWER_PIN, LOW); // Power on the LED
  delayMicroseconds(280);
  int voMeasured = analogRead(MEASURE_PIN); // Read the dust value (0-4095)
  delayMicroseconds(40);
  digitalWrite(LED_POWER_PIN, HIGH); // Turn the LED off
  delayMicroseconds(9680);

  // Convert raw 12-bit ADC to Voltage (ESP32 operates at 3.3V)
  float calcVoltage = voMeasured * (3.3 / 4095.0);

  // Linear equation to calculate dust density (mg/m3) -> convert to ug/m3
  // mg/m3 = 0.17 * calcVoltage - 0.1
  float dust_mg = (0.17 * calcVoltage) - 0.1;
  dustDensity = dust_mg * 1000.0;
  
  if (dustDensity < 0.0) dustDensity = 0.0; // clamp to 0

  // Print to Serial for debugging
  Serial.print("Raw Dust ADC: "); Serial.print(voMeasured);
  Serial.print(" | Voltage: "); Serial.print(calcVoltage);
  Serial.print(" | Dust Density: "); Serial.print(dustDensity);
  Serial.print(" ug/m3 | Hum: "); Serial.print(humidity);
  Serial.print("% | Temp: "); Serial.print(temperature);
  Serial.println(" C");

  // If connected, notify the client
  if (deviceConnected) {
    // Format: "dustDensity,humidity,temperature,dhtValid"
    char payload[64];
    snprintf(payload, sizeof(payload), "%.1f,%.1f,%.1f,%d", dustDensity, humidity, temperature, dhtValid ? 1 : 0);
    
    pCharacteristic->setValue((uint8_t*)payload, strlen(payload));
    pCharacteristic->notify();
    Serial.print("Notified: ");
    Serial.println(payload);
  }

  // Handle disconnection & reconnection
  if (!deviceConnected && oldDeviceConnected) {
      delay(500); // give the bluetooth stack the chance to get things ready
      pServer->startAdvertising(); // restart advertising
      Serial.println("Restarted advertising");
      oldDeviceConnected = deviceConnected;
  }
  
  if (deviceConnected && !oldDeviceConnected) {
      oldDeviceConnected = deviceConnected;
  }

  // Wait 1 second before next reading
  delay(1000);
}
