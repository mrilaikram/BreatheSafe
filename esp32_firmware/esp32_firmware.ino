#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>
#include <DHT.h>

// --- PIN CONFIGURATION ---
#define DHTPIN 4       // Digital pin connected to the DHT sensor
#define DHTTYPE DHT22  // DHT 22 (AM2302)
#define MQ135_PIN 34   // Analog pin connected to MQ135

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
float airPurity = 0.0;
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
  pinMode(MQ135_PIN, INPUT);

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
  pAdvertising->setMinPreferred(0x06);  // functions that help with iPhone connections issue
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

  // 2. MQ135 (Air Quality)
  // The ESP32 ADC is 12-bit (0-4095). 
  // For MQ135: Lower analog reading = clean air. Higher reading = more gas/smoke.
  int mq135Raw = analogRead(MQ135_PIN);
  
  // Map the raw value to a percentage. 
  // Assuming 0 is perfect air (100% purity) and 4095 is worst air (0% purity).
  // Note: Calibration depends on the specific MQ135 environment and pre-heating.
  airPurity = 100.0 - ((mq135Raw / 4095.0) * 100.0);
  
  // Clamp value between 0 and 100
  if (airPurity > 100.0) airPurity = 100.0;
  if (airPurity < 0.0) airPurity = 0.0;

  // Print to Serial for debugging
  Serial.print("Raw MQ135: "); Serial.print(mq135Raw);
  Serial.print(" | Purity: "); Serial.print(airPurity);
  Serial.print("% | Hum: "); Serial.print(humidity);
  Serial.print("% | Temp: "); Serial.print(temperature);
  Serial.println(" C");

  // If connected, notify the client
  if (deviceConnected) {
    // Format: "air_purity,humidity,temperature,mq135_raw,dht_valid"
    char payload[64];
    snprintf(payload, sizeof(payload), "%.1f,%.1f,%.1f,%d,%d", airPurity, humidity, temperature, mq135Raw, dhtValid ? 1 : 0);
    
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
      // do stuff here on connecting
      oldDeviceConnected = deviceConnected;
  }

  // Wait 1 second before next reading
  delay(1000);
}
