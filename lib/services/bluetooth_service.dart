// Bluetooth Low Energy (BLE) service for cross-platform communication.
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fbp;
import 'package:permission_handler/permission_handler.dart';

class BluetoothService extends ChangeNotifier {
  // BLE UUIDs for Bridge communication
  static const String bridgeServiceUuid =
      '12345678-1234-5678-1234-56789012345a';
  static const String bridgeCharacteristicUuid =
      '12345678-1234-5678-1234-56789012345b';
  static const String notifyCharacteristicUuid =
      '12345678-1234-5678-1234-56789012345c';

  fbp.BluetoothDevice? _connectedDevice;
  fbp.BluetoothCharacteristic? _writeCharacteristic;
  fbp.BluetoothCharacteristic? _notifyCharacteristic;
  StreamSubscription<List<fbp.ScanResult>>? _scanSubscription;
  StreamSubscription<List<int>>? _notifySubscription;
  StreamSubscription<fbp.BluetoothAdapterState>? _adapterStateSubscription;

  bool _isScanning = false;
  bool _isConnected = false;
  bool _isDisposed = false;

  // Streams
  final _connectedDevicesStream =
      StreamController<List<fbp.BluetoothDevice>>.broadcast();
  final _discoveredDevicesStream =
      StreamController<List<fbp.BluetoothDevice>>.broadcast();
  final _connectionStateStream = StreamController<bool>.broadcast();
  final _messageReceivedStream = StreamController<Uint8List>.broadcast();

  Stream<List<fbp.BluetoothDevice>> get connectedDevices =>
      _connectedDevicesStream.stream;
  Stream<List<fbp.BluetoothDevice>> get discoveredDevices =>
      _discoveredDevicesStream.stream;
  Stream<bool> get connectionState => _connectionStateStream.stream;
  Stream<Uint8List> get messageReceived => _messageReceivedStream.stream;

  bool get isConnected => _isConnected;
  bool get isScanning => _isScanning;
  fbp.BluetoothDevice? get connectedDevice => _connectedDevice;

  BluetoothService() {
    _initializeBluetooth();
  }

  /// Initialize Bluetooth
  Future<void> _initializeBluetooth() async {
    try {
      // Request permissions
      await _requestBluetoothPermissions();

      // Listen to Bluetooth state changes
      _adapterStateSubscription = fbp.FlutterBluePlus.adapterState.listen((
        state,
      ) {
        if (state != fbp.BluetoothAdapterState.on) _disconnect();
      });

      notifyListeners();
    } catch (e) {
      if (e is UnsupportedError) return;
      debugPrint('Error initializing Bluetooth: $e');
    }
  }

  /// Request necessary Bluetooth permissions
  Future<void> _requestBluetoothPermissions() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      await Permission.bluetooth.request();
      await Permission.bluetoothScan.request();
      await Permission.bluetoothConnect.request();
      await Permission.location.request();
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      await Permission.bluetooth.request();
    }
  }

  /// Start scanning for Bridge devices
  Future<void> startScan() async {
    if (_isScanning) return;

    try {
      _isScanning = true;
      notifyListeners();

      // Scan with the Bridge service UUID filter
      // This finds devices advertising the Bridge service
      await fbp.FlutterBluePlus.startScan(
        withServices: [fbp.Guid(bridgeServiceUuid)],
        timeout: const Duration(seconds: 30), // Extended timeout to 30 seconds
      );

      debugPrint('Started scanning for Bridge devices...');

      // Listen for scan results
      await _scanSubscription?.cancel();
      _scanSubscription = fbp.FlutterBluePlus.scanResults.listen((results) {
        debugPrint('Found ${results.length} devices');
        final devices = results
            .map((r) => r.device)
            .toSet()
            .toList(); // Remove duplicates

        // Log discovered devices
        for (var device in devices) {
          debugPrint('  - ${device.platformName} (${device.remoteId.str})');
        }

        _discoveredDevicesStream.add(devices);
      });

      // Stop scanning after timeout
      await Future.delayed(const Duration(seconds: 30));
      await stopScan();
    } catch (e) {
      _isScanning = false;
      notifyListeners();
      if (e is UnsupportedError) return;
      debugPrint('Error starting scan: $e');
    }
  }

  /// Stop scanning
  Future<void> stopScan() async {
    try {
      await fbp.FlutterBluePlus.stopScan();
      await _scanSubscription?.cancel();
      _scanSubscription = null;
      _isScanning = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Error stopping scan: $e');
    }
  }

  /// Connect to a device
  Future<bool> connect(fbp.BluetoothDevice device) async {
    try {
      await device.connect(timeout: const Duration(seconds: 15));
      _connectedDevice = device;
      _isConnected = true;

      // Discover services
      final services = await device.discoverServices();

      // Find Bridge service and characteristics
      for (var service in services) {
        if (service.uuid.toString().toLowerCase() ==
            bridgeServiceUuid.toLowerCase()) {
          for (var characteristic in service.characteristics) {
            if (characteristic.uuid.toString().toLowerCase() ==
                bridgeCharacteristicUuid.toLowerCase()) {
              _writeCharacteristic = characteristic;
            } else if (characteristic.uuid.toString().toLowerCase() ==
                notifyCharacteristicUuid.toLowerCase()) {
              _notifyCharacteristic = characteristic;
              // Subscribe to notifications
              await _notifyCharacteristic!.setNotifyValue(true);
              await _notifySubscription?.cancel();
              _notifySubscription = _notifyCharacteristic!.lastValueStream
                  .listen((data) {
                    if (data.isNotEmpty) {
                      _messageReceivedStream.add(Uint8List.fromList(data));
                    }
                  });
            }
          }
        }
      }

      if (!_isDisposed) {
        _connectionStateStream.add(true);
        notifyListeners();
      }
      return true;
    } catch (e) {
      debugPrint('Error connecting to device: $e');
      _isConnected = false;
      notifyListeners();
      return false;
    }
  }

  /// Disconnect from device
  Future<void> _disconnect() async {
    try {
      if (_connectedDevice != null) {
        await _connectedDevice!.disconnect();
      }
      await _notifySubscription?.cancel();
      _notifySubscription = null;
      _connectedDevice = null;
      _writeCharacteristic = null;
      _notifyCharacteristic = null;
      _isConnected = false;
      if (!_isDisposed) {
        _connectionStateStream.add(false);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error disconnecting: $e');
    }
  }

  /// Send data to connected device
  Future<bool> sendMessage(Uint8List data) async {
    if (_writeCharacteristic == null) {
      debugPrint('Write characteristic not found');
      return false;
    }

    try {
      await _writeCharacteristic!.write(data, withoutResponse: false);
      return true;
    } catch (e) {
      debugPrint('Error sending message: $e');
      return false;
    }
  }

  /// Cleanup resources
  @override
  void dispose() {
    _isDisposed = true;
    _adapterStateSubscription?.cancel();
    _scanSubscription?.cancel();
    _notifySubscription?.cancel();
    _disconnect();
    _connectedDevicesStream.close();
    _discoveredDevicesStream.close();
    _connectionStateStream.close();
    _messageReceivedStream.close();
    super.dispose();
  }
}
