import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'background_alert_service.dart';

class SensorData {
  final double dustDensity;
  final double humidity;
  final double temperature;
  final double pm25;
  final double co2;
  final double voc;
  final DateTime timestamp;
  final bool isSimulated;
  final bool hasEstimatedComposition;
  final bool dhtValid;

  const SensorData({
    required this.dustDensity,
    required this.humidity,
    required this.temperature,
    required this.pm25,
    required this.co2,
    required this.voc,
    required this.timestamp,
    this.isSimulated = false,
    this.hasEstimatedComposition = true,
    this.dhtValid = true,
  });
}

class BleScanDevice {
  final String name;
  final String remoteId;
  final int rssi;
  final bool isBreatheSafe;

  const BleScanDevice({
    required this.name,
    required this.remoteId,
    required this.rssi,
    required this.isBreatheSafe,
  });

  String get displayName => name.isNotEmpty ? name : 'Unknown BLE device';
}

class BleSensorService {
  static const EventChannel _eventChannel = EventChannel('breathe_safe/sensor_events');
  static const MethodChannel _commandChannel = MethodChannel('breathe_safe/ble_commands');

  final _sensorController = StreamController<SensorData>.broadcast();
  final _connectionStateController = StreamController<bool>.broadcast();
  final _scanDevicesController = StreamController<List<BleScanDevice>>.broadcast();
  final _scanStateController = StreamController<bool>.broadcast();
  
  final List<double> _dustHistory = [];
  final List<BleScanDevice> _scanDevices = [];
  
  StreamSubscription? _eventSubscription;

  bool _isConnected = false;
  bool _isScanning = false;

  Stream<SensorData> get sensorStream => _sensorController.stream;
  Stream<bool> get connectionStateStream => _connectionStateController.stream;
  Stream<List<BleScanDevice>> get scanDevicesStream => _scanDevicesController.stream;
  Stream<bool> get scanStateStream => _scanStateController.stream;
  
  List<double> get dustHistory => List.unmodifiable(_dustHistory);
  List<BleScanDevice> get scanDevices => List.unmodifiable(_scanDevices);
  bool get isConnected => _isConnected;
  bool get isScanning => _isScanning;
  
  String? connectedDeviceName;

  BleSensorService() {
    _startListening();
  }

  void _startListening() {
    _eventSubscription = _eventChannel.receiveBroadcastStream().listen((dynamic event) {
      if (event is Map) {
        final type = event['type'] as String?;
        if (type == 'connection_state') {
          final connected = event['connected'] as bool? ?? false;
          _isConnected = connected;
          _connectionStateController.add(connected);
        } else if (type == 'sensor_data') {
          final payload = event['payload'] as String?;
          if (payload != null) {
            _parseData(payload);
          }
        } else if (type == 'scan_result') {
          final name = event['name'] as String? ?? '';
          final mac = event['mac'] as String? ?? '';
          final rssi = event['rssi'] as int? ?? 0;
          
          if (mac.isNotEmpty) {
            final existingIndex = _scanDevices.indexWhere((d) => d.remoteId == mac);
            final device = BleScanDevice(
              name: name,
              remoteId: mac,
              rssi: rssi,
              isBreatheSafe: name.contains('BreatheSafe') || name.contains('Breathe'),
            );
            
            if (existingIndex >= 0) {
              _scanDevices[existingIndex] = device;
            } else {
              _scanDevices.add(device);
            }
            
            // Sort to put BreatheSafe devices first, then by RSSI
            _scanDevices.sort((a, b) {
              if (a.isBreatheSafe && !b.isBreatheSafe) return -1;
              if (!a.isBreatheSafe && b.isBreatheSafe) return 1;
              return b.rssi.compareTo(a.rssi);
            });
            
            _scanDevicesController.add(_scanDevices);
          }
        }
      }
    }, onError: (dynamic error) {
      debugPrint('EventChannel error: $error');
    });

    _checkInitialStatus();
  }

  Future<void> _checkInitialStatus() async {
    _isConnected = await BackgroundAlertService.getConnectionStatus();
    _connectionStateController.add(_isConnected);
  }

  void _parseData(String payload) {
    // Format: "dustDensity,humidity,temperature,dhtValid"
    try {
      final parts = payload.split(',');
      if (parts.length >= 3) {
        double dustDensity = double.tryParse(parts[0]) ?? 0.0;
        double humidity = double.tryParse(parts[1]) ?? 0.0;
        double temperature = double.tryParse(parts[2]) ?? 0.0;
        bool dhtValid = parts.length >= 4 ? parts[3].trim() == '1' : true;

        // Estimate components from dust (just for UI visuals)
        double pm25 = dustDensity; // Direct 1:1 mapping for GP2Y1010AU0F
        double co2 = 400.0 + (dustDensity * 2.0); // Rough estimate
        double voc = dustDensity * 0.01; // Rough estimate

        _dustHistory.add(dustDensity);
        if (_dustHistory.length > 20) {
          _dustHistory.removeAt(0);
        }

        _sensorController.add(
          SensorData(
            dustDensity: dustDensity,
            humidity: humidity,
            temperature: temperature,
            pm25: pm25,
            co2: co2,
            voc: voc,
            timestamp: DateTime.now(),
            hasEstimatedComposition: true,
            dhtValid: dhtValid,
          ),
        );
      }
    } catch (e) {
      debugPrint("Error parsing background payload: $payload -> $e");
    }
  }

  Future<void> startScan() async {
    if (_isScanning) return;
    _scanDevices.clear();
    _scanDevicesController.add(_scanDevices);
    _isScanning = true;
    _scanStateController.add(true);
    
    try {
      await _commandChannel.invokeMethod('startScan');
    } catch (e) {
      debugPrint("Error starting manual scan: $e");
    }
  }

  Future<void> stopScan() async {
    try {
      await _commandChannel.invokeMethod('stopScan');
    } catch (e) {
      debugPrint("Error stopping manual scan: $e");
    }
    _isScanning = false;
    _scanStateController.add(false);
  }

  Future<void> connectToScannedDevice(BleScanDevice device) async {
    stopScan();
    try {
      connectedDeviceName = device.name;
      await _commandChannel.invokeMethod('connect', {'mac': device.remoteId});
    } catch (e) {
      debugPrint("Error connecting manually: $e");
    }
  }

  Future<void> disconnect() async {
    try {
      await _commandChannel.invokeMethod('disconnect');
      connectedDeviceName = null;
    } catch (e) {
      debugPrint("Error disconnecting manually: $e");
    }
  }

  void dispose() {
    _eventSubscription?.cancel();
    _sensorController.close();
    _connectionStateController.close();
    _scanDevicesController.close();
    _scanStateController.close();
  }
}
