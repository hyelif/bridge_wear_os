// Main Bridge Screen - communicate with connected device.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:bridge_wear_os/models/bridge_message.dart';
import 'package:bridge_wear_os/services/bluetooth_service.dart';
import 'package:bridge_wear_os/services/bridge_manager.dart';
import 'package:bridge_wear_os/screens/device_discovery_screen.dart';

class BridgeScreen extends StatefulWidget {
  const BridgeScreen({super.key});

  @override
  State<BridgeScreen> createState() => _BridgeScreenState();
}

class _BridgeScreenState extends State<BridgeScreen> {
  late BridgeManager _bridgeManager;
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  final List<BridgeMessage> _messages = [];
  StreamSubscription<BridgeMessage>? _messageSubscription;

  @override
  void initState() {
    super.initState();
    _initializeBridge();
  }

  void _initializeBridge() {
    final bluetoothService = Provider.of<BluetoothService>(
      context,
      listen: false,
    );
    _bridgeManager = BridgeManager(bluetoothService);

    // Listen to incoming messages
    _messageSubscription = _bridgeManager.messages.listen((message) {
      if (!mounted) return;
      setState(() {
        _messages.add(message);
        // Keep only last 50 messages
        if (_messages.length > 50) {
          _messages.removeAt(0);
        }
      });
    });
  }

  Future<void> _sendNotification() async {
    if (_titleController.text.isEmpty || _messageController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    bool success = await _bridgeManager.sendNotification(
      title: _titleController.text,
      body: _messageController.text,
      appName: 'Bridge App',
    );

    if (!mounted) return;

    if (success) {
      _titleController.clear();
      _messageController.clear();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Notification sent!')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to send notification')),
      );
    }
  }

  Future<void> _sendPing() async {
    bool success = await _bridgeManager.sendPing();
    if (!mounted) return;
    if (!success) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to send ping')));
    }
  }

  Future<void> _sendHealthData() async {
    bool success = await _bridgeManager.sendHealthData(
      steps: 5000,
      heartRate: 72,
      calories: 250,
      sleepData: {'duration': 7.5, 'quality': 'good'},
    );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Health data sent!')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to send health data')),
      );
    }
  }

  Future<void> _disconnect() async {
    final bluetoothService = Provider.of<BluetoothService>(
      context,
      listen: false,
    );
    _bridgeManager.dispose();

    if (bluetoothService.connectedDevice != null) {
      await bluetoothService.connectedDevice!.disconnect();
    }

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const DeviceDiscoveryScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bridge Communication'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: _disconnect,
            tooltip: 'Disconnect',
          ),
        ],
      ),
      body: Column(
        children: [
          // Connection Status Card
          StreamBuilder<bool>(
            stream: Provider.of<BluetoothService>(context).connectionState,
            builder: (context, snapshot) {
              final isConnected = snapshot.data ?? false;
              return Card(
                margin: const EdgeInsets.all(8.0),
                color: isConnected ? Colors.green[50] : Colors.red[50],
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      Icon(
                        isConnected ? Icons.check_circle : Icons.error_outline,
                        color: isConnected ? Colors.green : Colors.red,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isConnected ? 'Connected' : 'Disconnected',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              Provider.of<BluetoothService>(
                                    context,
                                  ).connectedDevice?.platformName ??
                                  'Unknown',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          // Input Section
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Send Notification',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _titleController,
                      decoration: InputDecoration(
                        hintText: 'Notification Title',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.all(12),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: 'Notification Body',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.all(12),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _sendNotification,
                            icon: const Icon(Icons.send),
                            label: const Text('Send'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Quick Actions
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _sendPing,
                    icon: const Icon(Icons.speed),
                    label: const Text('Ping'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _sendHealthData,
                    icon: const Icon(Icons.favorite),
                    label: const Text('Health'),
                  ),
                ),
              ],
            ),
          ),

          // Message History
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 8.0, top: 8.0),
                    child: Text(
                      'Message History (${_messages.length})',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Expanded(
                    child: _messages.isEmpty
                        ? const Center(child: Text('No messages yet'))
                        : ListView.builder(
                            reverse: true,
                            itemCount: _messages.length,
                            itemBuilder: (context, index) {
                              final message =
                                  _messages[_messages.length - 1 - index];
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4.0,
                                ),
                                child: Card(
                                  child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              message.type.toString(),
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 11,
                                              ),
                                            ),
                                            Text(
                                              '${message.timestamp.hour}:${message.timestamp.minute.toString().padLeft(2, '0')}',
                                              style: const TextStyle(
                                                fontSize: 10,
                                                color: Colors.grey,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          message.payload.toString(),
                                          style: const TextStyle(fontSize: 10),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _titleController.dispose();
    _messageSubscription?.cancel();
    _bridgeManager.dispose();
    super.dispose();
  }
}
