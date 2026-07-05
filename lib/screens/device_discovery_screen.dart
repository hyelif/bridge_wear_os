// Device Discovery Screen - Shows all discovered BLE devices with RSSI,
// toggleable filtering, detailed connection status, and auto-rescan.
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fbp;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bridge_wear_os/screens/bridge_screen.dart';
import 'package:bridge_wear_os/utils/responsive_utils.dart';
import 'package:bridge_wear_os/providers/bluetooth_provider.dart';

class DeviceDiscoveryScreen extends ConsumerStatefulWidget {
  const DeviceDiscoveryScreen({super.key});

  @override
  ConsumerState<DeviceDiscoveryScreen> createState() => _DeviceDiscoveryScreenState();
}

class _DeviceDiscoveryScreenState extends ConsumerState<DeviceDiscoveryScreen> {
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
        _startScanning();
      }
    });
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

    // Listen to raw scan results for RSSI data (broadcast stream, safe to
    // subscribe alongside the service's own listener).
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
      // Devices found -- cancel any pending auto-rescan and reset the counter.
      _cancelAutoRescan();
      _autoRescanCount = 0;
    });

    // Schedule auto-rescan if no devices appear within 10 seconds.
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
      // Brief pause so the user sees "Connected!" before navigating.
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
      body: SafeArea(
        child: Column(
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

  // ---------------------------------------------------------------------------
  // Header
  // ---------------------------------------------------------------------------

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
          // Toggle: show all devices vs. filtered only
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

  // ---------------------------------------------------------------------------
  // Bluetooth / connection status bar
  // ---------------------------------------------------------------------------

  Widget _buildStatus() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: context.padding(12)),
      child: Container(
        padding: EdgeInsets.all(context.padding(10)),
        decoration: BoxDecoration(
          color: _bluetoothOn ? Colors.green[900] : Colors.red[900],
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
              child: Text(
                _buildStatusText(),
                style: TextStyle(fontSize: context.fontSize(11)),
              ),
            ),
            if (_isConnecting)
              SizedBox(
                width: context.iconSize(14),
                height: context.iconSize(14),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
      ),
    );
  }

  String _buildStatusText() {
    if (!_bluetoothOn) return 'Bluetooth OFF';
    if (_isConnecting) return _connectionStatus ?? 'Connecting...';
    if (_discoveredDevices.isEmpty) {
      return _showAllDevices ? 'Scanning for devices...' : 'Scanning for iPhone...';
    }
    return '${_discoveredDevices.length} device${_discoveredDevices.length == 1 ? '' : 's'} found';
  }

  // ---------------------------------------------------------------------------
  // Instructions
  // ---------------------------------------------------------------------------

  Widget _buildInstructions() {
    return Padding(
      padding: EdgeInsets.all(context.padding(12)),
      child: Container(
        padding: EdgeInsets.all(context.padding(8)),
        decoration: BoxDecoration(
          color: Colors.blue[900],
          borderRadius: BorderRadius.circular(context.padding(6)),
        ),
        child: Text(
          _showAllDevices
              ? 'Select any nearby device to connect'
              : 'On iPhone: Open Bridge app and keep it open',
          style: TextStyle(fontSize: context.fontSize(10)),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Error message
  // ---------------------------------------------------------------------------

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

  // ---------------------------------------------------------------------------
  // RSSI signal-strength indicator (5-bar style)
  // ---------------------------------------------------------------------------

  Widget _buildRssiIndicator(int rssi) {
    // Map RSSI (dBm) to 0-5 bars.
    //   >= -50  -> 5 bars (excellent)
    //   >= -60  -> 4 bars (good)
    //   >= -70  -> 3 bars (fair)
    //   >= -80  -> 2 bars (weak)
    //   >= -90  -> 1 bar  (very weak)
    //   <  -90  -> 0 bars (no signal)
    int bars;
    if (rssi >= -50) {
      bars = 5;
    } else if (rssi >= -60) {
      bars = 4;
    } else if (rssi >= -70) {
      bars = 3;
    } else if (rssi >= -80) {
      bars = 2;
    } else if (rssi >= -90) {
      bars = 1;
    } else {
      bars = 0;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final filled = index < bars;
        return Container(
          width: 3,
          height: 4.0 + (index * 3.0),
          margin: const EdgeInsets.only(right: 1.5),
          decoration: BoxDecoration(
            color: filled
                ? (bars <= 2 ? Colors.orange : Colors.green)
                : Colors.grey[700],
            borderRadius: BorderRadius.circular(1),
          ),
        );
      }),
    );
  }

  // ---------------------------------------------------------------------------
  // Device list
  // ---------------------------------------------------------------------------

  Widget _buildDeviceList() {
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
                _connectionStatus ??
                    'Connecting to ${_selectedDevice?.platformName}...',
                style: TextStyle(fontSize: context.fontSize(12)),
                textAlign: TextAlign.center,
              ),
            ] else ...[
              Icon(
                Icons.search,
                size: context.iconSize(32),
                color: Colors.white38,
              ),
              SizedBox(height: context.padding(8)),
              Text(
                _showAllDevices
                    ? 'Searching for devices...'
                    : 'Searching for iPhone...',
                style: TextStyle(
                  fontSize: context.fontSize(12),
                  color: Colors.white70,
                ),
              ),
              SizedBox(height: context.padding(16)),
              OutlinedButton(
                onPressed: _startScanning,
                child: const Text('Scan'),
              ),
            ],
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(context.padding(8)),
      itemCount: _discoveredDevices.length,
      itemBuilder: (context, index) {
        final device = _discoveredDevices[index];
        final name =
            device.platformName.isNotEmpty ? device.platformName : 'Unknown';
        final rssi = _deviceRssi[device.remoteId.str] ?? -100;

        return Card(
          child: ListTile(
            leading: Icon(
              _showAllDevices ? Icons.devices : Icons.phone_iphone,
              size: context.iconSize(20),
              color: Colors.green,
            ),
            title: Text(name, style: TextStyle(fontSize: context.fontSize(13))),
            subtitle: Row(
              children: [
                Flexible(
                  child: Text(
                    device.remoteId.str,
                    style: TextStyle(fontSize: context.fontSize(9)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Spacer(),
                _buildRssiIndicator(rssi),
                SizedBox(width: context.padding(4)),
                Text(
                  '$rssi dBm',
                  style: TextStyle(
                    fontSize: context.fontSize(8),
                    color: Colors.white54,
                  ),
                ),
              ],
            ),
            trailing: _isConnecting && _selectedDevice == device
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.chevron_right),
            onTap: _isConnecting ? null : () => _connectToDevice(device),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  @override
  void dispose() {
    _discoverySubscription?.cancel();
    _adapterSubscription?.cancel();
    _scanResultsSubscription?.cancel();
    _autoRescanTimer?.cancel();
    super.dispose();
  }
}
