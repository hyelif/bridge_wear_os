// Main Bridge Screen - communicate with connected device.
// Responsive design for different Wear OS screen sizes.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:bridge_wear_os/models/bridge_message.dart';
import 'package:bridge_wear_os/services/bluetooth_service.dart';
import 'package:bridge_wear_os/services/bridge_manager.dart';
import 'package:bridge_wear_os/screens/device_discovery_screen.dart';
import 'package:bridge_wear_os/utils/responsive_utils.dart';

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
        // Keep only last 20 messages to save space
        if (_messages.length > 20) {
          _messages.removeAt(0);
        }
      });
    });
  }

  Future<void> _sendNotification() async {
    if (_titleController.text.isEmpty || _messageController.text.isEmpty) {
      _showSnackBar('Please fill in all fields');
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
      _showSnackBar('Notification sent!');
    } else {
      _showSnackBar('Failed to send notification');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(fontSize: context.fontSize(11)),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _sendPing() async {
    bool success = await _bridgeManager.sendPing();
    if (!mounted) return;
    if (success) {
      _showSnackBar('Ping sent!');
    } else {
      _showSnackBar('Failed to send ping');
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
      _showSnackBar('Health data sent!');
    } else {
      _showSnackBar('Failed to send health data');
    }
  }

  Future<void> _disconnect() async {
    final bluetoothService = Provider.of<BluetoothService>(
      context,
      listen: false,
    );
    _bridgeManager.dispose();
    await bluetoothService.disconnect();

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const DeviceDiscoveryScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = context.screenWidth;
    final isSmall = screenWidth < 200;
    final isMedium = screenWidth < 280;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(),

            // Connection Status
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: context.padding(10),
              ),
              child: _buildConnectionStatus(),
            ),

            SizedBox(height: context.padding(6)),

            // Quick Actions
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: context.padding(10),
              ),
              child: _buildQuickActions(isSmall),
            ),

            SizedBox(height: context.padding(6)),

            // Input Section
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: context.padding(10),
              ),
              child: _buildInputSection(isSmall, isMedium),
            ),

            SizedBox(height: context.padding(4)),

            // Message History
            Expanded(
              child: _buildMessageHistory(isSmall),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.padding(10),
        vertical: context.padding(6),
      ),
      child: Row(
        children: [
          Icon(
            Icons.connected_tv,
            size: context.iconSize(18),
            color: Colors.green,
          ),
          SizedBox(width: context.padding(6)),
          Expanded(
            child: Text(
              'Bridge',
              style: TextStyle(
                fontSize: context.fontSize(14),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.close,
              size: context.iconSize(16),
            ),
            onPressed: _disconnect,
            tooltip: 'Disconnect',
            padding: EdgeInsets.zero,
            constraints: BoxConstraints(
              minWidth: context.iconSize(24),
              minHeight: context.iconSize(24),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionStatus() {
    return Consumer<BluetoothService>(
      builder: (context, bluetoothService, child) {
        return StreamBuilder<bool>(
          stream: bluetoothService.connectionState,
          builder: (context, snapshot) {
            final isConnected = snapshot.data ?? false;
            final deviceName = bluetoothService.connectedDevice?.platformName ?? 'Unknown';

            return Container(
              padding: EdgeInsets.all(context.padding(8)),
              decoration: BoxDecoration(
                color: isConnected
                    ? Colors.green.withValues(alpha: 0.15)
                    : Colors.red.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(context.padding(6)),
                border: Border.all(
                  color: isConnected ? Colors.green : Colors.red,
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isConnected ? Icons.check_circle : Icons.error_outline,
                    size: context.iconSize(14),
                    color: isConnected ? Colors.green : Colors.red,
                  ),
                  SizedBox(width: context.padding(6)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isConnected ? 'Connected' : 'Disconnected',
                          style: TextStyle(
                            fontSize: context.fontSize(10),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (isConnected)
                          Text(
                            deviceName,
                            style: TextStyle(
                              fontSize: context.fontSize(9),
                              color: Colors.white70,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildQuickActions(bool isSmall) {
    return Row(
      children: [
        Expanded(
          child: _QuickActionButton(
            icon: Icons.speed,
            label: 'Ping',
            onPressed: _sendPing,
            isSmall: isSmall,
            context: context,
          ),
        ),
        SizedBox(width: context.padding(6)),
        Expanded(
          child: _QuickActionButton(
            icon: Icons.favorite,
            label: 'Health',
            onPressed: _sendHealthData,
            isSmall: isSmall,
            context: context,
          ),
        ),
      ],
    );
  }

  Widget _buildInputSection(bool isSmall, bool isMedium) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(context.padding(8)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Send to iPhone',
              style: TextStyle(
                fontSize: context.fontSize(10),
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: context.padding(6)),
            TextField(
              controller: _titleController,
              style: TextStyle(fontSize: context.fontSize(11)),
              decoration: InputDecoration(
                hintText: 'Title',
                hintStyle: TextStyle(fontSize: context.fontSize(10)),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: context.padding(8),
                  vertical: context.padding(6),
                ),
                isDense: true,
              ),
            ),
            SizedBox(height: context.padding(4)),
            TextField(
              controller: _messageController,
              style: TextStyle(fontSize: context.fontSize(11)),
              maxLines: isSmall ? 1 : 2,
              decoration: InputDecoration(
                hintText: 'Message',
                hintStyle: TextStyle(fontSize: context.fontSize(10)),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: context.padding(8),
                  vertical: context.padding(6),
                ),
                isDense: true,
              ),
            ),
            SizedBox(height: context.padding(6)),
            SizedBox(
              width: double.infinity,
              height: context.buttonHeight(32),
              child: ElevatedButton.icon(
                onPressed: _sendNotification,
                icon: Icon(Icons.send, size: context.iconSize(14)),
                label: Text(
                  'Send',
                  style: TextStyle(fontSize: context.fontSize(11)),
                ),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: context.padding(4)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageHistory(bool isSmall) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: context.padding(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.message,
                size: context.iconSize(12),
                color: Colors.white70,
              ),
              SizedBox(width: context.padding(4)),
              Text(
                'Messages (${_messages.length})',
                style: TextStyle(
                  fontSize: context.fontSize(10),
                  fontWeight: FontWeight.bold,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
          SizedBox(height: context.padding(4)),
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Text(
                      'No messages yet',
                      style: TextStyle(
                        fontSize: context.fontSize(11),
                        color: Colors.white38,
                      ),
                    ),
                  )
                : ListView.builder(
                    reverse: true,
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[_messages.length - 1 - index];
                      return _MessageCard(message: message, isSmall: isSmall, context: context);
                    },
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

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool isSmall;
  final BuildContext context;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    required this.isSmall,
    required this.context,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: context.iconSize(14)),
      label: Text(
        label,
        style: TextStyle(fontSize: context.fontSize(isSmall ? 10 : 11)),
      ),
      style: OutlinedButton.styleFrom(
        padding: EdgeInsets.symmetric(
          vertical: context.padding(4),
        ),
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  final BridgeMessage message;
  final bool isSmall;
  final BuildContext context;

  const _MessageCard({
    required this.message,
    required this.isSmall,
    required this.context,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.symmetric(vertical: context.padding(2)),
      child: Padding(
        padding: EdgeInsets.all(context.padding(6)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: context.padding(4),
                    vertical: context.padding(1),
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(context.padding(2)),
                  ),
                  child: Text(
                    message.type.toString().split('.').last,
                    style: TextStyle(
                      fontSize: context.fontSize(8),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  '${message.timestamp.hour}:${message.timestamp.minute.toString().padLeft(2, '0')}',
                  style: TextStyle(
                    fontSize: context.fontSize(8),
                    color: Colors.white54,
                  ),
                ),
              ],
            ),
            SizedBox(height: context.padding(2)),
            Text(
              _getMessagePreview(),
              style: TextStyle(fontSize: context.fontSize(9)),
              maxLines: isSmall ? 1 : 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  String _getMessagePreview() {
    final payload = message.payload;
    if (payload.containsKey('title') && payload.containsKey('body')) {
      return '${payload['title']}: ${payload['body']}';
    }
    return payload.toString();
  }
}