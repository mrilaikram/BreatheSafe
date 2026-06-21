import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'background_alert_service.dart';

class SensorData {
  final double airPurity;
  final double humidity;
  final double temperature;
  final double pm25;
  final double co2;
  final double voc;
  final DateTime timestamp;
  final bool isSimulated;
  final bool hasEstimatedComposition;
  final int? mq135Raw;
  final bool dhtValid;

  const SensorData({
    required this.airPurity,
    required this.humidity,
    required this.temperature,
    required this.pm25,
    required this.co2,
    required this.voc,
    required this.timestamp,
    this.isSimulated = false,
    this.hasEstimatedComposition = true,
    this.mq135Raw,
    this.dhtValid = true,
  });
}

class BleScanDevice {
  final BluetoothDevice device;
  final String name;
  final String remoteId;
  final int rssi;
  final bool isBreatheSafe;

  const BleScanDevice({
    required this.device,
    required this.name,
    required this.remoteId,
    required this.rssi,
    required this.isBreatheSafe,
  });

  String get displayName => name.isNotEmpty ? name : 'Unknown BLE device';
}

class BleSensorService {
  static const String deviceName = "BreatheSafe_Device";
  static const String serviceId = "4fafc201-1fb5-459e-8fcc-c5c9c331914b";
  static const String characteristicId = "beb5483e-36e1-4688-b7f5-ea07361b26a8";

  final _sensorController = StreamController<SensorData>.broadcast();
  final _connectionStateController = StreamController<bool>.broadcast();
  final _scanDevicesController =
      StreamController<List<BleScanDevice>>.broadcast();
  final _scanStateController = StreamController<bool>.broadcast();
  final _scanMessageController = StreamController<String?>.broadcast();
  final List<double> _purityHistory = [];
  final List<BleScanDevice> _scanDevices = [];

  BluetoothDevice? _connectedDevice;
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  StreamSubscription<BluetoothConnectionState>? _connectionSubscription;
  StreamSubscription<List<int>>? _valueSubscription;

  bool _isScanning = false;
  bool _isConnected = false;
  bool _scanStopped = false;

  Stream<SensorData> get sensorStream => _sensorController.stream;
  Stream<bool> get connectionStateStream => _connectionStateController.stream;
  Stream<List<BleScanDevice>> get scanDevicesStream =>
      _scanDevicesController.stream;
  Stream<bool> get scanStateStream => _scanStateController.stream;
  Stream<String?> get scanMessageStream => _scanMessageController.stream;
  List<double> get purityHistory => List.unmodifiable(_purityHistory);
  List<BleScanDevice> get scanDevices => List.unmodifiable(_scanDevices);
  bool get isConnected => _isConnected;
  bool get isScanning => _isScanning;
  BluetoothDevice? get connectedDevice => _connectedDevice;

  BleSensorService();

  Future<void> tryReconnectFromBackground() async {
    if (_isConnected) return;

    final mac = await BackgroundAlertService.getLastConnectedMac();
    if (mac != null && mac.isNotEmpty) {
      debugPrint('Found background MAC: $mac, attempting direct connect');
      try {
        final device = BluetoothDevice.fromId(mac);
        await connectToScannedDevice(
          BleScanDevice(
            device: device,
            name: deviceName,
            remoteId: mac,
            rssi: -50,
            isBreatheSafe: true,
          ),
        );
      } catch (e) {
        debugPrint('Direct connect failed: $e');
      }
    }
  }

  Future<bool> requestPermissions() async {
    if (defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      return true;
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      final bluetoothStatus = await <Permission>[
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
      ].request();

      if (!bluetoothStatus.values.every((s) => s.isGranted || s.isLimited)) {
        _setScanMessage('Allow Bluetooth permission, then tap Search again.');
        return false;
      }

      final locationStatus = await Permission.locationWhenInUse.request();
      if (!locationStatus.isGranted && !locationStatus.isLimited) {
        _setScanMessage('Allow Location permission, then tap Search again.');
        return false;
      }

      final locationService = await Permission.locationWhenInUse.serviceStatus;
      if (locationService.isDisabled) {
        _setScanMessage('Turn on Location, then tap Search again.');
        return false;
      }

      return true;
    }

    final status = await Permission.bluetooth.request();
    final granted = status.isGranted || status.isLimited;
    if (!granted) {
      _setScanMessage('Allow Bluetooth permission, then tap Search again.');
    }
    return granted;
  }

  Future<void> startScan() async {
    if (_isScanning) return;

    _setScanMessage(null);

    bool hasPermissions = await requestPermissions();
    if (!hasPermissions) {
      return;
    }

    final bluetoothReady = await _ensureBluetoothReady();
    if (!bluetoothReady) return;

    _setScanning(true);
    _scanStopped = false;
    _scanDevices.clear();
    _scanDevicesController.add(List.unmodifiable(_scanDevices));

    // Stop any existing scans
    if (FlutterBluePlus.isScanningNow) {
      try {
        await FlutterBluePlus.stopScan();
      } catch (e) {
        debugPrint("Error stopping previous scan: $e");
      }
    }

    _scanSubscription?.cancel();

    _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
      if (_scanStopped) return;

      for (ScanResult result in results) {
        _upsertScanResult(result);

        if (_isBreatheSafeDevice(result)) {
          _scanStopped = true;
          try {
            FlutterBluePlus.stopScan();
          } catch (e) {
            debugPrint("Error stopping scan after device found: $e");
          }
          connectToScannedDevice(
            BleScanDevice(
              device: result.device,
              name: _scanResultName(result),
              remoteId: result.device.remoteId.toString(),
              rssi: result.rssi,
              isBreatheSafe: true,
            ),
          );
          break;
        }
      }
    });

    const scanDuration = Duration(seconds: 15);

    try {
      await FlutterBluePlus.startScan(
        timeout: scanDuration,
        androidUsesFineLocation: true,
        androidCheckLocationServices: true,
      );

      try {
        await FlutterBluePlus.isScanning
            .where((isScanning) => !isScanning)
            .first
            .timeout(scanDuration + const Duration(seconds: 3));
      } on TimeoutException {
        await FlutterBluePlus.stopScan();
      }

      if (!_isConnected && _scanDevices.isEmpty) {
        _setScanMessage(
          'No BLE devices found. Keep Bluetooth and Location on, then try again.',
        );
      } else if (!_isConnected &&
          !_scanDevices.any((device) => device.isBreatheSafe)) {
        _setScanMessage(
          'Devices found, but BreatheSafe_Device was not advertising.',
        );
      }
    } catch (e) {
      debugPrint("Error during scan: $e");
      _setScanMessage('Scan failed: $e');
    } finally {
      _setScanning(false);
    }
  }

  Future<void> stopScan() async {
    _scanStopped = true;
    if (FlutterBluePlus.isScanningNow) {
      await FlutterBluePlus.stopScan();
    }
    _setScanning(false);
  }

  Future<void> connectToScannedDevice(BleScanDevice scanDevice) async {
    await stopScan();
    _setScanMessage('Connecting to ${scanDevice.displayName}...');

    try {
      await _connectToDevice(scanDevice.device);
      _setScanMessage(null);
    } catch (e) {
      debugPrint("Error connecting to device: $e");
      _setScanMessage('Connection failed: $e');
    }
  }

  void refreshReading() {
    // Real BLE doesn't need manual refresh
  }

  bool _isBreatheSafeDevice(ScanResult result) {
    final advertisedService = result.advertisementData.serviceUuids.any(
      (uuid) => uuid.toString().toLowerCase() == serviceId.toLowerCase(),
    );

    return advertisedService ||
        result.device.platformName == deviceName ||
        result.advertisementData.advName == deviceName;
  }

  String _scanResultName(ScanResult result) {
    if (result.advertisementData.advName.isNotEmpty) {
      return result.advertisementData.advName;
    }

    if (result.device.platformName.isNotEmpty) {
      return result.device.platformName;
    }

    return result.device.advName;
  }

  void _upsertScanResult(ScanResult result) {
    final scanDevice = BleScanDevice(
      device: result.device,
      name: _scanResultName(result),
      remoteId: result.device.remoteId.toString(),
      rssi: result.rssi,
      isBreatheSafe: _isBreatheSafeDevice(result),
    );

    final index = _scanDevices.indexWhere(
      (device) => device.remoteId == scanDevice.remoteId,
    );

    if (index >= 0) {
      _scanDevices[index] = scanDevice;
    } else {
      _scanDevices.add(scanDevice);
    }

    _scanDevices.sort((a, b) {
      if (a.isBreatheSafe != b.isBreatheSafe) {
        return a.isBreatheSafe ? -1 : 1;
      }

      return b.rssi.compareTo(a.rssi);
    });

    _scanDevicesController.add(List.unmodifiable(_scanDevices));
  }

  Future<bool> _ensureBluetoothReady() async {
    final state = await FlutterBluePlus.adapterState.first.timeout(
      const Duration(seconds: 3),
      onTimeout: () => FlutterBluePlus.adapterStateNow,
    );

    if (state == BluetoothAdapterState.on) {
      return true;
    }

    _setScanMessage('Turn on Bluetooth, then tap Search again.');

    try {
      await FlutterBluePlus.turnOn(timeout: 10);
      final newState = await FlutterBluePlus.adapterState.first.timeout(
        const Duration(seconds: 3),
        onTimeout: () => FlutterBluePlus.adapterStateNow,
      );
      return newState == BluetoothAdapterState.on;
    } catch (e) {
      debugPrint("Bluetooth turn on failed: $e");
      _setScanMessage('Turn on Bluetooth, then tap Search again.');
      return false;
    }
  }

  void _setScanning(bool isScanning) {
    _isScanning = isScanning;
    _scanStateController.add(isScanning);
  }

  void _setScanMessage(String? message) {
    _scanMessageController.add(message);
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    _connectedDevice = device;
    _connectionSubscription?.cancel();

    _connectionSubscription = device.connectionState.listen((state) {
      if (state == BluetoothConnectionState.connected) {
        _isConnected = true;
        _connectionStateController.add(true);
        _discoverServices(device);
      } else if (state == BluetoothConnectionState.disconnected) {
        _isConnected = false;
        _connectionStateController.add(false);
        _connectedDevice = null;
      }
    });

    await device.connect(autoConnect: false, license: License.nonprofit);
  }

  Future<void> _discoverServices(BluetoothDevice device) async {
    List<BluetoothService> services = await device.discoverServices();

    for (BluetoothService service in services) {
      if (service.uuid.toString().toLowerCase() == serviceId.toLowerCase()) {
        for (BluetoothCharacteristic characteristic
            in service.characteristics) {
          if (characteristic.uuid.toString().toLowerCase() ==
              characteristicId.toLowerCase()) {
            await _subscribeToCharacteristic(characteristic);
            return;
          }
        }
      }
    }
  }

  Future<void> _subscribeToCharacteristic(
    BluetoothCharacteristic characteristic,
  ) async {
    await characteristic.setNotifyValue(true);

    _valueSubscription?.cancel();
    _valueSubscription = characteristic.lastValueStream.listen((value) {
      if (value.isNotEmpty) {
        _parseData(utf8.decode(value));
      }
    });
  }

  void _parseData(String payload) {
    // Format: "airPurity,humidity,temperature,mq135Raw,dhtValid"
    try {
      final parts = payload.split(',');
      if (parts.length >= 3) {
        double purity = double.parse(parts[0]);
        double humidity = double.parse(parts[1]);
        double temperature = double.parse(parts[2]);
        int? mq135Raw = parts.length >= 4 ? int.tryParse(parts[3]) : null;
        bool dhtValid = parts.length >= 5 ? parts[4].trim() == '1' : true;

        // Synthesize missing values based on purity for the UI cards
        double pm25 = (100.0 - purity) * 0.5; // Rough estimate
        double co2 = 400.0 + ((100.0 - purity) * 10.0); // Rough estimate
        double voc = (100.0 - purity) * 0.05; // Rough estimate

        _purityHistory.add(purity);
        if (_purityHistory.length > 20) {
          _purityHistory.removeAt(0);
        }

        _sensorController.add(
          SensorData(
            airPurity: purity,
            humidity: humidity,
            temperature: temperature,
            pm25: pm25,
            co2: co2,
            voc: voc,
            timestamp: DateTime.now(),
            hasEstimatedComposition: true,
            mq135Raw: mq135Raw,
            dhtValid: dhtValid,
          ),
        );
      }
    } catch (e) {
      debugPrint("Error parsing BLE payload: $payload -> $e");
    }
  }

  Future<void> disconnect() async {
    if (_connectedDevice != null) {
      await _connectedDevice!.disconnect();
      _connectedDevice = null;
    }
  }

  void dispose() {
    disconnect();
    _scanSubscription?.cancel();
    _connectionSubscription?.cancel();
    _valueSubscription?.cancel();
    _sensorController.close();
    _connectionStateController.close();
    _scanDevicesController.close();
    _scanStateController.close();
    _scanMessageController.close();
  }
}
