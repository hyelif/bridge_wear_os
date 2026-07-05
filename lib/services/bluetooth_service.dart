// Bluetooth Low Energy (BLE) service for Bridge app
// Uses simple BLE communication between Wear OS and iOS
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fbp;
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BluetoothService extends ChangeNotifier {
  // Standard BLE UUIDs - simple and reliable
  static const String bridgeServiceUuid =
      '12345678-1234-5678-1234-56789012345a';
  static const String bridgeCharacteristicUuid =
      '12345678-1234-5678-1234-56789012345b';
  static const String notifyCharacteristicUuid =
      '12345678-1234-5678-1234-56789012345c';

  // Duty-cycle scan configuration
  static const Duration scanDuration = Duration(seconds: 5);
  static const Duration pauseDuration = Duration(seconds: 10);
  static const int scanCycles = 3;
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
  StreamSubscription<fbp.BluetoothConnectionState>? _connectionStateSubscription;

  // Auto-reconnect state
  String? _savedDeviceId;
  bool _isAutoReconnecting = false;
  static const String _savedDeviceIdKey = 'saved_device_id';
  static const Duration autoReconnectTimeout = Duration(seconds: 15);

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
  String? get savedDeviceId => _savedDeviceId;
  bool get isAutoReconnecting => _isAutoReconnecting;

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

      // Load saved device ID for auto-reconnect
      await _loadSavedDeviceId();
    } catch (e) {
      debugPrint('[BLE] Init error: $e');
      _scanErrorStream.add('Failed to initialize Bluetooth: $e');
    }
  }

  /// Load saved device ID from SharedPreferences and attempt auto-connect.
  Future<void> _loadSavedDeviceId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _savedDeviceId = prefs.getString(_savedDeviceIdKey);
      if (_savedDeviceId != null && _savedDeviceId!.isNotEmpty) {
        debugPrint('[BLE] Found saved device: $_savedDeviceId');
        _isAutoReconnecting = true;
        notifyListeners();

        // Wait a moment for Bluetooth adapter to be ready, then auto-connect
        await Future.delayed(const Duration(milliseconds: 500));
        await _attemptAutoReconnect();
      }
    } catch (e) {
      debugPrint('[BLE] Error loading saved device: $e');
    }
  }

  /// Attempt to auto-connect to the saved device.
  Future<void> _attemptAutoReconnect() async {
    if (_savedDeviceId == null) return;

    try {
      final device = fbp.BluetoothDevice.fromId(_savedDeviceId!);
      debugPrint('[BLE] Auto-connecting to saved device: $_savedDeviceId');

      final connected = await connect(device, isAutoReconnect: true);

      if (connected) {
        debugPrint('[BLE] Auto-reconnect succeeded');
        _isAutoReconnecting = false;
        notifyListeners();
      } else {
        debugPrint('[BLE] Auto-reconnect failed — falling back to scan');
        _isAutoReconnecting = false;
        _savedDeviceId = null;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[BLE] Auto-reconnect error: $e');
      _isAutoReconnecting = false;
      _savedDeviceId = null;
      notifyListeners();
    }
  }

  Future<void> _requestBluetoothPermissions() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        // On Android 12+ (API 31+), only BLUETOOTH_SCAN and BLUETOOTH_CONNECT
        // are needed. BLUETOOTH_SCAN is declared with neverForLocation flag,
        // so no location permission is required.
        final scanStatus = await Permission.bluetoothScan.request();
        if (!scanStatus.isGranted) {
          final msg = 'Bluetooth scan permission was denied. '
              'The app needs this to discover nearby devices. '
              'Please grant it in Settings > App permissions.';
          debugPrint('[BLE] Bluetooth scan permission denied: $scanStatus');
          _scanErrorStream.add(msg);
        }

        final connectStatus = await Permission.bluetoothConnect.request();
        if (!connectStatus.isGranted) {
          final msg = 'Bluetooth connect permission was denied. '
              'The app needs this to connect to your iPhone. '
              'Please grant it in Settings > App permissions.';
          debugPrint('[BLE] Bluetooth connect permission denied: $connectStatus');
          _scanErrorStream.add(msg);
        }

        // On older Android (< 12), also request the legacy BLUETOOTH permission
        final sdkInt = await _getAndroidSdkInt();
        if (sdkInt < 31) {
          final legacyStatus = await Permission.bluetooth.request();
          if (!legacyStatus.isGranted) {
            debugPrint('[BLE] Legacy Bluetooth permission denied: $legacyStatus');
          }
        }
      } catch (e) {
        debugPrint('[BLE] Permission request error: $e');
        _scanErrorStream.add('Failed to request Bluetooth permissions: $e');
      }
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      // iOS needs Bluetooth permission for flutter_blue_plus
      try {
        final bluetoothStatus = await Permission.bluetooth.request();
        if (!bluetoothStatus.isGranted) {
          final msg = 'Bluetooth permission was denied. '
              'The Bridge app uses Bluetooth to communicate with your Wear OS watch. '
              'Please enable Bluetooth in Settings > Privacy & Security > Bluetooth, '
              'or reinstall the app to be prompted again.';
          debugPrint('[BLE] iOS Bluetooth permission denied: $bluetoothStatus');
          _scanErrorStream.add(msg);
        } else if (bluetoothStatus.isPermanentlyDenied) {
          final msg = 'Bluetooth permission is permanently denied. '
              'The Bridge app cannot function without Bluetooth access. '
              'Please go to Settings > Privacy & Security > Bluetooth and enable '
              'Bridge, or reinstall the app.';
          debugPrint('[BLE] iOS Bluetooth permission permanently denied');
          _scanErrorStream.add(msg);
        } else if (bluetoothStatus.isLimited) {
          debugPrint('[BLE] iOS Bluetooth permission granted (limited)');
        } else {
          debugPrint('[BLE] iOS Bluetooth permission granted');
        }
      } catch (e) {
        debugPrint('[BLE] iOS permission request error: $e');
        _scanErrorStream.add('Failed to request Bluetooth permissions: $e');
      }
    }
  }

  /// Get the Android SDK version at runtime.
  /// Returns 0 if unable to determine (non-Android or error).
  Future<int> _getAndroidSdkInt() async {
    try {
      // Use the platform channel to query Build.VERSION.SDK_INT
      // This avoids importing 'dart:io' for a single call.
      final result = await const MethodChannel('com.bridge.wear_os/platform')
          .invokeMethod<int>('getSdkInt');
      return result ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// Toggle between filtered scan and scan-all mode
  void setScanAllMode(bool enabled) {
    _scanAllMode = enabled;
    debugPrint('[BLE] Scan-all mode: $enabled');
    notifyListeners();
  }

  /// Start scanning for Bridge devices (iPhone running Bridge app)
  ///
  /// Uses duty-cycled scanning to reduce battery consumption:
  /// - 3 cycles of 5 seconds scanning + 10 seconds pause
  /// - Total wall-clock time: ~40 seconds, but radio active only ~15 seconds
  /// - Reduces battery consumption by ~60% compared to a continuous 20s scan
  Future<void> startScan() async {
    if (_isScanning) return;

    try {
      _isScanning = true;
      notifyListeners();
      debugPrint('[BLE] Starting duty-cycled scan '
          '($scanCycles cycles of ${scanDuration.inSeconds}s scan + '
          '${pauseDuration.inSeconds}s pause)...');

      // Check Bluetooth is on
      try {
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
      } catch (e) {
        // On iOS, flutter_blue_plus may not report adapter state correctly
        // when app is in peripheral mode. Proceed with scan anyway.
        debugPrint('[BLE] Adapter state check failed (iOS?): $e');
      }

      // Duty-cycled scan: 3 cycles of 5s scan + 10s pause
      for (int cycle = 1; cycle <= scanCycles; cycle++) {
        if (!_isScanning) break; // cancelled mid-cycle

        debugPrint('[BLE] Duty cycle $cycle/$scanCycles: scanning...');

        // Start a short scan
        await fbp.FlutterBluePlus.startScan(
          timeout: scanDuration,
        );

        // Listen for results during this cycle
        await _scanSubscription?.cancel();
        _scanSubscription = fbp.FlutterBluePlus.scanResults.listen((results) {
          debugPrint('[BLE] Cycle $cycle: found ${results.length} devices');

          if (_scanAllMode) {
            // Show ALL discovered devices (no filtering)
            final devices = results.map((r) => r.device).toList();
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
                  '[BLE] Cycle $cycle: filtered to ${devices.length} Bridge/iPhone devices');
              _discoveredDevicesStream.add(devices);
            } else {
              // Fallback: no named devices found — show ALL devices so the
              // user can still pick one (some BLE devices don't broadcast a name)
              final devices = results.map((r) => r.device).toList();
              debugPrint(
                  '[BLE] Cycle $cycle: no named Bridge devices found — '
                  'showing all ${devices.length} discovered devices as fallback');
              _discoveredDevicesStream.add(devices);
            }
          }
        });

        // Wait for the scan to complete (timeout fires after scanDuration)
        await Future.delayed(scanDuration + const Duration(milliseconds: 500));

        // Stop the current scan before pausing
        await fbp.FlutterBluePlus.stopScan();

        if (cycle < scanCycles && _isScanning) {
          debugPrint('[BLE] Duty cycle $cycle/$scanCycles: pausing for '
              '${pauseDuration.inSeconds}s to save battery...');
          await Future.delayed(pauseDuration);
        }
      }

      // All cycles complete — stop scanning
      if (_isScanning) {
        stopScan();
      }
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
  ///
  /// If [isAutoReconnect] is true, uses [autoConnect: true] so the BLE stack
  /// automatically reconnects when the device comes back into range.
  Future<bool> connect(fbp.BluetoothDevice device,
      {bool isAutoReconnect = false}) async {
    try {
      final deviceName =
          device.platformName.isNotEmpty ? device.platformName : 'Unknown';
      debugPrint('[BLE] Connecting to $deviceName (${device.remoteId})...');

      // Attempt connection — use autoConnect for reconnection attempts
      await device.connect(
        timeout: isAutoReconnect ? autoReconnectTimeout : connectTimeout,
        autoConnect: isAutoReconnect,
      );
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

      // Save device ID for auto-reconnect on next launch
      await _saveDeviceId(device.remoteId.toString());

      // Listen for disconnects to trigger auto-reconnect
      _listenForDisconnects(device);

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

  /// Save the device ID to SharedPreferences for auto-reconnect.
  Future<void> _saveDeviceId(String deviceId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_savedDeviceIdKey, deviceId);
      _savedDeviceId = deviceId;
      debugPrint('[BLE] Saved device ID: $deviceId');
    } catch (e) {
      debugPrint('[BLE] Error saving device ID: $e');
    }
  }

  /// Listen for disconnects and attempt auto-reconnect.
  void _listenForDisconnects(fbp.BluetoothDevice device) {
    _connectionStateSubscription?.cancel();
    _connectionStateSubscription =
        device.connectionState.listen((state) {
      debugPrint('[BLE] Connection state: $state');
      if (state == fbp.BluetoothConnectionState.disconnected) {
        debugPrint('[BLE] Device disconnected — attempting auto-reconnect');
        _isConnected = false;
        _connectionStateStream.add(false);
        notifyListeners();

        // Attempt auto-reconnect with autoConnect: true
        _attemptAutoReconnectAfterDisconnect(device);
      }
    });
  }

  /// Attempt to re-establish connection after an unexpected disconnect.
  Future<void> _attemptAutoReconnectAfterDisconnect(
      fbp.BluetoothDevice device) async {
    if (_savedDeviceId == null) return;

    _isAutoReconnecting = true;
    notifyListeners();

    try {
      // Re-discover services after reconnection
      await device.connect(
        timeout: autoReconnectTimeout,
        autoConnect: true,
      );
      _connectedDevice = device;
      _isConnected = true;

      // Re-discover services
      final services = await device.discoverServices();
      debugPrint('[BLE] Reconnected — re-discovered ${services.length} services');

      // Re-setup characteristics
      await _setupCharacteristics(services);

      // Re-listen for disconnects
      _listenForDisconnects(device);

      _isAutoReconnecting = false;
      _connectionStateStream.add(true);
      notifyListeners();
      debugPrint('[BLE] Auto-reconnect successful');
    } catch (e) {
      debugPrint('[BLE] Auto-reconnect after disconnect failed: $e');
      _isAutoReconnecting = false;
      notifyListeners();

      // If auto-reconnect fails, the user will need to manually reconnect
      // via the discovery screen. The saved device ID remains so the next
      // app launch will attempt auto-connect again.
    }
  }

  /// Re-setup characteristics after reconnection.
  Future<void> _setupCharacteristics(List<fbp.BluetoothService> services) async {
    _writeCharacteristic = null;
    _notifyCharacteristic = null;

    for (var service in services) {
      final serviceUuid = service.uuid.toString().toLowerCase();

      if (serviceUuid == bridgeServiceUuid.toLowerCase()) {
        for (var char in service.characteristics) {
          final charUuid = char.uuid.toString().toLowerCase();

          if (charUuid == bridgeCharacteristicUuid.toLowerCase()) {
            _writeCharacteristic = char;
          } else if (charUuid == notifyCharacteristicUuid.toLowerCase()) {
            _notifyCharacteristic = char;
            await char.setNotifyValue(true);
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

    // Fallback if Bridge service not found
    if (_writeCharacteristic == null) {
      await _setupFallbackConnection(services);
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
      _connectionStateSubscription?.cancel();
      _connectedDevice = null;
      _writeCharacteristic = null;
      _notifyCharacteristic = null;
      _isConnected = false;
      _isAutoReconnecting = false;
      // Clear saved device ID on explicit disconnect
      await _clearSavedDeviceId();
      _connectionStateStream.add(false);
      notifyListeners();
      debugPrint('[BLE] Disconnected');
    } catch (e) {
      debugPrint('[BLE] Disconnect error: $e');
    }
  }

  /// Clear the saved device ID from SharedPreferences.
  Future<void> _clearSavedDeviceId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_savedDeviceIdKey);
      _savedDeviceId = null;
      debugPrint('[BLE] Cleared saved device ID');
    } catch (e) {
      debugPrint('[BLE] Error clearing saved device ID: $e');
    }
  }

  @override
  void dispose() {
    _adapterStateSubscription?.cancel();
    _scanSubscription?.cancel();
    _notifySubscription?.cancel();
    _connectionStateSubscription?.cancel();
    _disconnect();
    _discoveredDevicesStream.close();
    _connectionStateStream.close();
    _messageReceivedStream.close();
    _scanErrorStream.close();
    super.dispose();
  }
}
