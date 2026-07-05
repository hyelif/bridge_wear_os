// Bluetooth Low Energy (BLE) service for Bridge app
// Uses simple BLE communication between Wear OS and iOS
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fbp;
import 'package:permission_handler/permission_handler.dart';

class BluetoothService extends ChangeNotifier {
  // Standard BLE UUIDs - simple and reliable
  static const String bridgeServiceUuid =
      '12345678-1234-5678-1234-56789012345a';
  static const String bridgeCharacteristicUuid =
      '12345678-1234-5678-1234-56789012345b';
  static const String notifyCharacteristicUuid =
      '12345678-1234-5678-1234-56789012345c';

  // Scan configuration
  static const Duration scanTimeout = Duration(seconds: 20);
  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration serviceDiscoveryRetryDelay = Duration(milliseconds: 500);
  static const int maxServiceDiscoveryRetries = 3;

  // Filter keywords for Bridge/iPhone devices
  static const List<String> _bridgeFilterKeywords = [
    'bridge',
    'iphone',
    'apple',
  ];

  fbp.BluetoothDevice? _connectedDevice;
  fbp.BluetoothCharacteristic? _writeCharacteristic;
  fbp.BluetoothCharacteristic? _notifyCharacteristic;
  StreamSubscription<List<fbp.ScanResult>>? _scanSubscription;
  StreamSubscription<List<int>>? _notifySubscription;
  StreamSubscription<fbp.BluetoothAdapterState>? _adapterStateSubscription;

  bool _isScanning = false;
  bool _isConnected = false;
  bool _scanAllMode = false;

  // Streams
  final _discoveredDevicesStream =
      StreamController<List<fbp.BluetoothDevice>>.broadcast();
  final _connectionStateStream = StreamController<bool>.broadcast();
  final _messageReceivedStream =
      StreamController<Map<String, dynamic>>.broadcast();
  final _scanErrorStream = StreamController<String>.broadcast();

  Stream<List<fbp.BluetoothDevice>> get discoveredDevices =>
      _discoveredDevicesStream.stream;
  Stream<bool> get connectionState => _connectionStateStream.stream;
  Stream<Map<String, dynamic>> get messageReceived =>
      _messageReceivedStream.stream;
  Stream<String> get scanErrors => _scanErrorStream.stream;

  bool get isConnected => _isConnected;
  bool get isScanning => _isScanning;
  bool get scanAllMode => _scanAllMode;
  fbp.BluetoothDevice? get connectedDevice => _connectedDevice;

  BluetoothService() {
    debugPrint('[BLE] Service created');
    _initializeBluetooth();
  }

  Future<void> _initializeBluetooth() async {
    try {
      // Request permissions
      await _requestBluetoothPermissions();

      // Listen to Bluetooth state
      _adapterStateSubscription =
          fbp.FlutterBluePlus.adapterState.listen((state) {
        debugPrint('[BLE] Adapter state: $state');
        if (state != fbp.BluetoothAdapterState.on) {
          debugPrint('[BLE] Bluetooth turned off or unavailable');
          _disconnect();
        }
      });
    } catch (e) {
      debugPrint('[BLE] Init error: $e');
      _scanErrorStream.add('Failed to initialize Bluetooth: $e');
    }
  }

  Future<void> _requestBluetoothPermissions() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        final bluetoothStatus = await Permission.bluetooth.request();
        if (!bluetoothStatus.isGranted) {
          debugPrint('[BLE] Bluetooth permission denied: $bluetoothStatus');
        }

        final scanStatus = await Permission.bluetoothScan.request();
        if (!scanStatus.isGranted) {
          debugPrint('[BLE] Bluetooth scan permission denied: $scanStatus');
        }

        final connectStatus = await Permission.bluetoothConnect.request();
        if (!connectStatus.isGranted) {
          debugPrint(
              '[BLE] Bluetooth connect permission denied: $connectStatus');
        }

        final locationStatus = await Permission.location.request();
        if (!locationStatus.isGranted) {
          debugPrint('[BLE] Location permission denied: $locationStatus');
        }
      } catch (e) {
        debugPrint('[BLE] Permission request error: $e');
        _scanErrorStream.add('Failed to request Bluetooth permissions: $e');
      }
    }
  }

  /// Toggle between filtered scan and scan-all mode
  void setScanAllMode(bool enabled) {
    _scanAllMode = enabled;
    debugPrint('[BLE] Scan-all mode: $enabled');
    notifyListeners();
  }

  /// Start scanning for Bridge devices (iPhone running Bridge app)
  Future<void> startScan() async {
    if (_isScanning) return;

    try {
      _isScanning = true;
      notifyListeners();
      debugPrint('[BLE] Starting scan (timeout: ${scanTimeout.inSeconds}s, '
          'scanAll: $_scanAllMode)...');

      // Check Bluetooth is on
      final adapterState = await fbp.FlutterBluePlus.adapterState.first;
      if (adapterState != fbp.BluetoothAdapterState.on) {
        final errorMsg = 'Bluetooth is not enabled (state: $adapterState). '
            'Please turn on Bluetooth and try again.';
        debugPrint('[BLE] $errorMsg');
        _scanErrorStream.add(errorMsg);
        _isScanning = false;
        notifyListeners();
        return;
      }

      // Scan WITHOUT service filter first - find all BLE devices
      await fbp.FlutterBluePlus.startScan(
        timeout: scanTimeout,
      );

      await _scanSubscription?.cancel();
      _scanSubscription = fbp.FlutterBluePlus.scanResults.listen((results) {
        debugPrint('[BLE] Found ${results.length} devices');

        if (_scanAllMode) {
          // Show ALL discovered devices (no filtering)
          final devices = results.map((r) => r.device).toList();
          debugPrint('[BLE] Scan-all: showing all ${devices.length} devices');
          _discoveredDevicesStream.add(devices);
        } else {
          // Filter to find potential Bridge/iPhone devices
          final namedDevices = results.where((r) {
            final name = r.device.platformName.toLowerCase();
            return _bridgeFilterKeywords
                .any((keyword) => name.contains(keyword));
          }).toList();

          if (namedDevices.isNotEmpty) {
            // Show filtered results
            final devices = namedDevices.map((r) => r.device).toList();
            debugPrint(
                '[BLE] Filtered to ${devices.length} Bridge/iPhone devices');
            _discoveredDevicesStream.add(devices);
          } else {
            // Fallback: no named devices found — show ALL devices so the
            // user can still pick one (some BLE devices don't broadcast a name)
            final devices = results.map((r) => r.device).toList();
            debugPrint(
                '[BLE] No named Bridge devices found — showing all '
                '${devices.length} discovered devices as fallback');
            _discoveredDevicesStream.add(devices);
          }
        }
      });

      // Auto-stop after timeout
      Future.delayed(scanTimeout, () {
        if (_isScanning) {
          stopScan();
        }
      });
    } catch (e) {
      final errorMsg = 'Scan failed: $e';
      debugPrint('[BLE] $errorMsg');
      _scanErrorStream.add(errorMsg);
      _isScanning = false;
      notifyListeners();
    }
  }

  Future<void> stopScan() async {
    try {
      await fbp.FlutterBluePlus.stopScan();
      _isScanning = false;
      notifyListeners();
      debugPrint('[BLE] Scan stopped');
    } catch (e) {
      debugPrint('[BLE] Stop scan error: $e');
    }
  }

  /// Connect to Bridge device (iPhone)
  Future<bool> connect(fbp.BluetoothDevice device) async {
    try {
      final deviceName =
          device.platformName.isNotEmpty ? device.platformName : 'Unknown';
      debugPrint('[BLE] Connecting to $deviceName (${device.remoteId})...');

      // Attempt connection
      await device.connect(timeout: connectTimeout);
      _connectedDevice = device;
      _isConnected = true;
      notifyListeners();

      debugPrint('[BLE] Connected! Discovering services...');

      // Discover services with retry logic — the iOS peripheral may not
      // have finished advertising its service list yet.
      List<fbp.BluetoothService> services = [];
      for (int attempt = 1; attempt <= maxServiceDiscoveryRetries; attempt++) {
        try {
          services = await device.discoverServices();
          debugPrint(
              '[BLE] Service discovery attempt $attempt: found ${services.length} services');

          // Check if our Bridge service is present
          final hasBridgeService = services.any((s) =>
              s.uuid.toString().toLowerCase() ==
              bridgeServiceUuid.toLowerCase());
          if (hasBridgeService) {
            debugPrint('[BLE] Bridge service found on attempt $attempt');
            break;
          }

          if (attempt < maxServiceDiscoveryRetries) {
            debugPrint(
                '[BLE] Bridge service not found yet, retrying in '
                '${serviceDiscoveryRetryDelay.inMilliseconds}ms...');
            await Future.delayed(serviceDiscoveryRetryDelay);
          }
        } catch (e) {
          debugPrint(
              '[BLE] Service discovery attempt $attempt failed: $e');
          if (attempt < maxServiceDiscoveryRetries) {
            await Future.delayed(serviceDiscoveryRetryDelay);
          } else {
            rethrow;
          }
        }
      }

      // Find our Bridge service characteristics
      for (var service in services) {
        final serviceUuid = service.uuid.toString().toLowerCase();
        debugPrint('[BLE] Service: $serviceUuid');

        if (serviceUuid == bridgeServiceUuid.toLowerCase()) {
          debugPrint('[BLE] Found Bridge service!');

          for (var char in service.characteristics) {
            final charUuid = char.uuid.toString().toLowerCase();
            debugPrint('[BLE]   Char: $charUuid');

            if (charUuid == bridgeCharacteristicUuid.toLowerCase()) {
              _writeCharacteristic = char;
              debugPrint('[BLE] Write characteristic found');
            } else if (charUuid == notifyCharacteristicUuid.toLowerCase()) {
              _notifyCharacteristic = char;
              debugPrint('[BLE] Notify characteristic found');

              // Enable notifications
              await char.setNotifyValue(true);
              debugPrint('[BLE] Notifications enabled');

              await _notifySubscription?.cancel();
              _notifySubscription = char.lastValueStream.listen((data) {
                if (data.isNotEmpty) {
                  _handleReceivedData(data);
                }
              });
            }
          }
        }
      }

      // Fallback: If no Bridge service found, try to use any writable/notify
      // characteristics so the connection is still usable.
      if (_writeCharacteristic == null) {
        debugPrint(
            '[BLE] Bridge service not found — setting up fallback connection '
            'using first available writable/notify characteristics...');
        await _setupFallbackConnection(services);
      }

      if (_writeCharacteristic == null && _notifyCharacteristic == null) {
        final errorMsg =
            'Connected to $deviceName but no suitable characteristics found. '
            'Ensure the Bridge app is running on the iPhone.';
        debugPrint('[BLE] $errorMsg');
        _scanErrorStream.add(errorMsg);
        await disconnect();
        return false;
      }

      _connectionStateStream.add(true);
      notifyListeners();
      debugPrint('[BLE] Connection ready!');
      return true;
    } catch (e) {
      final errorMsg = 'Failed to connect to ${device.platformName}: $e';
      debugPrint('[BLE] $errorMsg');
      _scanErrorStream.add(errorMsg);
      _isConnected = false;
      notifyListeners();
      return false;
    }
  }

  /// Fallback: Try to use any writable/notify characteristics
  Future<void> _setupFallbackConnection(
      List<fbp.BluetoothService> services) async {
    debugPrint('[BLE] Looking for fallback characteristics...');

    for (var service in services) {
      for (var char in service.characteristics) {
        final props = char.properties;
        debugPrint(
            '[BLE] Char ${char.uuid} props: write=${props.write}, '
            'notify=${props.notify}');

        if (_writeCharacteristic == null && props.write) {
          _writeCharacteristic = char;
          debugPrint('[BLE] Fallback write char: ${char.uuid}');
        }
        if (_notifyCharacteristic == null && props.notify) {
          _notifyCharacteristic = char;
          await char.setNotifyValue(true);
          await _notifySubscription?.cancel();
          _notifySubscription = char.lastValueStream.listen((data) {
            if (data.isNotEmpty) {
              _handleReceivedData(data);
            }
          });
          debugPrint('[BLE] Fallback notify char: ${char.uuid}');
        }
      }
    }

    debugPrint(
        '[BLE] Fallback setup complete. '
        'Write: ${_writeCharacteristic != null}, '
        'Notify: ${_notifyCharacteristic != null}');
  }

  void _handleReceivedData(List<int> data) {
    try {
      final jsonString = utf8.decode(data);
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      debugPrint('[BLE] Received: $json');
      _messageReceivedStream.add(json);
    } on FormatException catch (e) {
      debugPrint('[BLE] JSON parse error: $e, raw data: $data');
    } on TypeError catch (e) {
      debugPrint('[BLE] Data format error: $e, raw data: $data');
    } catch (e) {
      debugPrint('[BLE] Unexpected receive error: $e, data: $data');
    }
  }

  /// Send data to connected device
  Future<bool> sendData(Map<String, dynamic> data) async {
    if (_writeCharacteristic == null) {
      debugPrint('[BLE] Cannot send: no write characteristic available');
      return false;
    }

    if (!_isConnected) {
      debugPrint('[BLE] Cannot send: not connected');
      return false;
    }

    try {
      final jsonString = jsonEncode(data);
      final bytes = utf8.encode(jsonString);

      debugPrint('[BLE] Sending: $jsonString');

      await _writeCharacteristic!.write(
        Uint8List.fromList(bytes),
        withoutResponse: false,
      );
      return true;
    } catch (e) {
      debugPrint('[BLE] Send error: $e');
      return false;
    }
  }

  /// Send simple message
  Future<bool> sendMessage(String type, Map<String, dynamic> payload) async {
    return sendData({
      'type': type,
      'payload': payload,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// Disconnect from the current device
  Future<void> disconnect() async {
    await _disconnect();
  }

  Future<void> _disconnect() async {
    try {
      if (_connectedDevice != null) {
        await _connectedDevice!.disconnect();
      }
      await _notifySubscription?.cancel();
      _connectedDevice = null;
      _writeCharacteristic = null;
      _notifyCharacteristic = null;
      _isConnected = false;
      _connectionStateStream.add(false);
      notifyListeners();
      debugPrint('[BLE] Disconnected');
    } catch (e) {
      debugPrint('[BLE] Disconnect error: $e');
    }
  }

  @override
  void dispose() {
    _adapterStateSubscription?.cancel();
    _scanSubscription?.cancel();
    _notifySubscription?.cancel();
    _disconnect();
    _discoveredDevicesStream.close();
    _connectionStateStream.close();
    _messageReceivedStream.close();
    _scanErrorStream.close();
    super.dispose();
  }
}
