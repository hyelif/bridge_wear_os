// Device Discovery Screen - modern Wear OS UI
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fbp;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bridge_wear_os/screens/bridge_screen.dart';
import 'package:bridge_wear_os/utils/responsive_utils.dart';
import 'package:bridge_wear_os/providers/bluetooth_provider.dart';
import 'package:bridge_wear_os/widgets/device_card.dart';
import 'package:bridge_wear_os/widgets/wear_chip.dart';
import 'package:bridge_wear_os/widgets/animated_status.dart';
import 'package:bridge_wear_os/widgets/round_clipper.dart';

class DeviceDiscoveryScreen extends ConsumerStatefulWidget {
  const DeviceDiscoveryScreen({super.key});

  @override
  ConsumerState<DeviceDiscoveryScreen> createState() =>
      _DeviceDiscoveryScreenState();
}

class _DeviceDiscoveryScreenState
    extends ConsumerState<DeviceDiscoveryScreen> {
  List<fbp.BluetoothDevice> _discoveredDevices = [];
  final Map<String, int> _deviceRssi = {};
  bool _isConnecting = false;
  fbp.BluetoothDevice? _selectedDevice;
  String? _connectionStatus;
  StreamSubscription? _discoverySubscription;
  StreamSubscription? _adapterSubscription;
  StreamSubscription<List<fbp.ScanResult>>? _scanResultsSubscription;
  String? _errorMessage;
  bool _bluetoothOn = true;
  bool _showAllDevices = false;
  Timer? _autoRescanTimer;
  int _autoRescanCount = 0;
  static const int _maxAutoRescans = 3;

  @override
  void initState() {
    super.initState();
    _initBluetooth();
  }

  void _initBluetooth() {
    _adapterSubscription = fbp.FlutterBluePlus.adapterState.listen((state) {
      if (!mounted) return;
      setState(() {
        _bluetoothOn = state == fbp.BluetoothAdapterState.on;
      });
      if (_bluetoothOn) {
        _checkAutoReconnect();
      }
    });
  }

  /// Check if there's a saved device to auto-connect to.
  /// If so, show "Auto-connecting..." and attempt connection.
  /// If not, start scanning immediately.
  void _checkAutoReconnect() {
    final service = ref.read(bluetoothServiceProvider);
    if (service.savedDeviceId != null && service.isAutoReconnecting) {
      setState(() {
        _connectionStatus = 'Auto-connecting...';
        _isConnecting = true;
      });

      // Listen for connection state changes to know when auto-connect completes
      _discoverySubscription?.cancel();
      _discoverySubscription = service.connectionState.listen((connected) {
        if (!mounted) return;
        if (connected) {
          setState(() => _connectionStatus = 'Connected!');
          service.stopScan();
          Future.delayed(const Duration(milliseconds: 500), () {
            if (!mounted) return;
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const BridgeScreen()),
            );
          });
        }
      });

      // Also listen for auto-reconnect state changes
      ref.listen(autoReconnectProvider, (prev, next) {
        if (!mounted) return;
        if (!next.isAutoReconnecting && !service.isConnected) {
          // Auto-reconnect failed — fall back to normal scan
          setState(() {
            _isConnecting = false;
            _connectionStatus = null;
            _errorMessage = 'Could not auto-connect. Scanning for devices...';
          });
          _startScanning();
        }
      });
    } else {
      _startScanning();
    }
  }

  void _startScanning() {
    if (!_bluetoothOn) {
      setState(() => _errorMessage = 'Turn on Bluetooth');
      return;
    }

    final service = ref.read(bluetoothServiceProvider);

    setState(() {
      _discoveredDevices = [];
      _deviceRssi.clear();
      _errorMessage = null;
      _connectionStatus = null;
    });

    // Listen to raw scan results for RSSI data
    _scanResultsSubscription?.cancel();
    _scanResultsSubscription =
        fbp.FlutterBluePlus.scanResults.listen((results) {
      if (!mounted) return;
      setState(() {
        for (final result in results) {
          _deviceRssi[result.device.remoteId.str] = result.rssi;
        }
      });
    });

    service.startScan();

    _discoverySubscription?.cancel();
    _discoverySubscription = service.discoveredDevices.listen((devices) {
      if (!mounted) return;
      setState(() => _discoveredDevices = devices);
      _cancelAutoRescan();
      _autoRescanCount = 0;
    });

    _startAutoRescanTimer();
  }

  void _startAutoRescanTimer() {
    _autoRescanTimer?.cancel();
    if (_autoRescanCount >= _maxAutoRescans) return;

    _autoRescanTimer = Timer(const Duration(seconds: 10), () {
      if (!mounted) return;
      if (_discoveredDevices.isNotEmpty || _isConnecting) return;

      _autoRescanCount++;
      setState(() {
        _errorMessage =
            'No devices found. Rescanning... ($_autoRescanCount/$_maxAutoRescans)';
      });
      _startScanning();
    });
  }

  void _cancelAutoRescan() {
    _autoRescanTimer?.cancel();
    _autoRescanTimer = null;
  }

  void _toggleShowAllDevices() {
    final service = ref.read(bluetoothServiceProvider);
    setState(() {
      _showAllDevices = !_showAllDevices;
    });
    service.setScanAllMode(_showAllDevices);
    _startScanning();
  }

  Future<void> _connectToDevice(fbp.BluetoothDevice device) async {
    setState(() {
      _isConnecting = true;
      _selectedDevice = device;
      _errorMessage = null;
      _connectionStatus = 'Connecting...';
    });

    final service = ref.read(bluetoothServiceProvider);

    setState(() {
      _connectionStatus = 'Connecting to ${device.platformName}...';
    });

    bool connected = await service.connect(device);

    if (!mounted) return;

    if (connected) {
      setState(() => _connectionStatus = 'Connected!');
      await service.stopScan();
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const BridgeScreen()),
      );
    } else {
      setState(() {
        _isConnecting = false;
        _selectedDevice = null;
        _connectionStatus = null;
        _errorMessage = 'Connection failed. Make sure iPhone app is open.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: SafeArea(
        child: context.isRound
            ? RoundClip(
                child: Column(
                  children: [
                    _buildHeader(),
                    _buildStatus(),
                    _buildInstructions(),
                    if (_errorMessage != null) _buildError(),
                    Expanded(child: _buildDeviceList()),
                  ],
                ),
              )
            : Column(
                children: [
                  _buildHeader(),
                  _buildStatus(),
                  _buildInstructions(),
                  if (_errorMessage != null) _buildError(),
                  Expanded(child: _buildDeviceList()),
                ],
              ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: EdgeInsets.all(context.padding(12)),
      child: Row(
        children: [
          Icon(Icons.watch, size: context.iconSize(24), color: Colors.blue),
          SizedBox(width: context.padding(8)),
          Text(
            'Bridge',
            style: TextStyle(
              fontSize: context.fontSize(16),
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: Icon(
              _showAllDevices ? Icons.filter_list_off : Icons.filter_list,
              size: context.iconSize(18),
              color: _showAllDevices ? Colors.amber : Colors.white70,
            ),
            tooltip: _showAllDevices
                ? 'Show filtered devices'
                : 'Show all devices',
            onPressed: _isConnecting ? null : _toggleShowAllDevices,
          ),
          IconButton(
            icon: Icon(Icons.refresh, size: context.iconSize(18)),
            onPressed: _isConnecting ? null : _startScanning,
          ),
        ],
      ),
    );
  }

  Widget _buildStatus() {
    final isAutoConnecting = _connectionStatus == 'Auto-connecting...';
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: context.padding(12)),
      child: Container(
        padding: EdgeInsets.all(context.padding(10)),
        decoration: BoxDecoration(
          color: _bluetoothOn
              ? (isAutoConnecting ? Colors.blue[900] : Colors.green[900])
              : Colors.red[900],
          borderRadius: BorderRadius.circular(context.padding(8)),
        ),
        child: Row(
          children: [
            Icon(
              _bluetoothOn ? Icons.bluetooth : Icons.bluetooth_disabled,
              size: context.iconSize(18),
              color: _bluetoothOn ? Colors.green : Colors.red,
            ),
            SizedBox(width: context.padding(8)),
            Expanded(
              child: AnimatedStatus(
                text: _bluetoothOn
                    ? (_isConnecting
                        ? _connectionStatus ?? 'Scanning...'
                        : 'Scanning for devices...')
                    : 'Bluetooth OFF',
                icon: _bluetoothOn
                    ? (isAutoConnecting
                        ? Icons.sync
                        : (_isConnecting
                            ? Icons.sync
                            : Icons.bluetooth_searching))
                    : Icons.bluetooth_disabled,
                color: _bluetoothOn
                    ? (isAutoConnecting ? Colors.blue : Colors.green)
                    : Colors.red,
              ),
            ),
            if (_bluetoothOn && !_isConnecting)
              SizedBox(
                width: context.iconSize(14),
                height: context.iconSize(14),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.green,
                ),
              ),
            if (_isConnecting)
              SizedBox(
                width: context.iconSize(14),
                height: context.iconSize(14),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: isAutoConnecting ? Colors.blue : Colors.blue,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructions() {
    final isAutoConnecting = _connectionStatus == 'Auto-connecting...';
    if (isAutoConnecting) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.all(context.padding(12)),
      child: Container(
        padding: EdgeInsets.all(context.padding(8)),
        decoration: BoxDecoration(
          color: Colors.blue[900],
          borderRadius: BorderRadius.circular(context.padding(6)),
        ),
        child: Text(
          'On iPhone: Open Bridge app and keep it open',
          style: TextStyle(fontSize: context.fontSize(10)),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildError() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: context.padding(12)),
      child: Container(
        padding: EdgeInsets.all(context.padding(8)),
        decoration: BoxDecoration(
          color: Colors.red[900],
          borderRadius: BorderRadius.circular(context.padding(6)),
        ),
        child: Row(
          children: [
            Icon(Icons.error, size: context.iconSize(14), color: Colors.red),
            SizedBox(width: context.padding(6)),
            Expanded(
              child: Text(
                _errorMessage!,
                style: TextStyle(
                  fontSize: context.fontSize(10),
                  color: Colors.red,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceList() {
    final isAutoConnecting = _connectionStatus == 'Auto-connecting...';

    if (_discoveredDevices.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isConnecting) ...[
              SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
              SizedBox(height: context.padding(12)),
              Text(
                isAutoConnecting
                    ? 'Auto-connecting to saved device...'
                    : 'Connecting to ${_selectedDevice?.platformName}...',
                style: TextStyle(fontSize: context.fontSize(12)),
              ),
              if (isAutoConnecting) ...[
                SizedBox(height: context.padding(8)),
                Text(
                  'Make sure the iPhone is nearby with Bridge open',
                  style: TextStyle(
                    fontSize: context.fontSize(9),
                    color: Colors.white54,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ] else ...[
              Icon(
                Icons.bluetooth_searching,
                size: context.iconSize(32),
                color: Colors.white38,
              ),
              SizedBox(height: context.padding(8)),
              Text(
                'Searching for iPhone...',
                style: TextStyle(
                  fontSize: context.fontSize(12),
                  color: Colors.white70,
                ),
              ),
              SizedBox(height: context.padding(16)),
              WearChip(
                icon: Icons.refresh,
                label: 'Scan',
                onPressed: _startScanning,
              ),
            ],
          ],
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.all(context.padding(8)),
            itemCount: _discoveredDevices.length,
            itemBuilder: (context, index) {
              final device = _discoveredDevices[index];
              return DeviceCard(
                device: device,
                rssi: _deviceRssi[device.remoteId.str],
                isConnecting: _isConnecting && _selectedDevice == device,
                isSelected: _selectedDevice == device,
                onTap: () => _connectToDevice(device),
              );
            },
          ),
        ),
        Padding(
          padding: EdgeInsets.all(context.padding(8)),
          child: WearChip(
            icon: Icons.refresh,
            label: 'Scan Again',
            onPressed: _isConnecting ? null : _startScanning,
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _discoverySubscription?.cancel();
    _adapterSubscription?.cancel();
    _scanResultsSubscription?.cancel();
    _autoRescanTimer?.cancel();
    super.dispose();
  }
}
