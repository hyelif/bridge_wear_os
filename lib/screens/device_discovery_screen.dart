// Device Discovery Screen - scan and connect to Bridge devices.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fbp;
import 'package:provider/provider.dart';
import 'package:bridge_wear_os/services/bluetooth_service.dart';
import 'package:bridge_wear_os/screens/bridge_screen.dart';

class DeviceDiscoveryScreen extends StatefulWidget {
  const DeviceDiscoveryScreen({super.key});

  @override
  State<DeviceDiscoveryScreen> createState() => _DeviceDiscoveryScreenState();
}

class _DeviceDiscoveryScreenState extends State<DeviceDiscoveryScreen> {
  List<fbp.BluetoothDevice> _discoveredDevices = [];
  bool _isConnecting = false;
  fbp.BluetoothDevice? _selectedDevice;
  StreamSubscription<List<fbp.BluetoothDevice>>? _discoverySubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _startScanning();
    });
  }

  void _startScanning() {
    final bluetoothService = Provider.of<BluetoothService>(
      context,
      listen: false,
    );
    bluetoothService.startScan();

    _discoverySubscription = bluetoothService.discoveredDevices.listen((
      devices,
    ) {
      if (!mounted) return;
      setState(() {
        _discoveredDevices = devices;
      });
    });
  }

  Future<void> _connectToDevice(fbp.BluetoothDevice device) async {
    setState(() {
      _isConnecting = true;
      _selectedDevice = device;
    });

    final bluetoothService = Provider.of<BluetoothService>(
      context,
      listen: false,
    );

    bool connected = await bluetoothService.connect(device);

    if (!mounted) return;

    if (connected) {
      await bluetoothService.stopScan();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const BridgeScreen()),
      );
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to connect to device'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _isConnecting = false;
          _selectedDevice = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Discover Bridge Devices'),
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Icon(Icons.bluetooth, size: 40, color: Colors.blue),
                    const SizedBox(height: 8),
                    const Text(
                      'Scanning for devices...',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 16),
                    StreamBuilder<bool>(
                      stream: Provider.of<BluetoothService>(
                        context,
                      ).connectionState,
                      builder: (context, snapshot) {
                        return Text(
                          snapshot.data == true ? 'Connected' : 'Not connected',
                          style: TextStyle(
                            fontSize: 14,
                            color: snapshot.data == true
                                ? Colors.green
                                : Colors.grey,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: _discoveredDevices.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Searching for devices...'),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _discoveredDevices.length,
                    itemBuilder: (context, index) {
                      final device = _discoveredDevices[index];
                      final isSelectedDevice = _selectedDevice == device;
                      final deviceName = device.platformName.isNotEmpty
                          ? device.platformName
                          : 'Unknown Device';

                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 8.0,
                          vertical: 4.0,
                        ),
                        child: ListTile(
                          leading: const Icon(Icons.devices),
                          title: Text(deviceName),
                          subtitle: Text(device.remoteId.str),
                          trailing: _isConnecting && isSelectedDevice
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : null,
                          enabled: !_isConnecting,
                          onTap: () {
                            if (!_isConnecting) {
                              _connectToDevice(device);
                            }
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _discoverySubscription?.cancel();
    super.dispose();
  }
}
