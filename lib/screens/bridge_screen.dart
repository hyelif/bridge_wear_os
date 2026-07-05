// Main Bridge Screen - modern Wear OS UI
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bridge_wear_os/models/bridge_message.dart';
import 'package:bridge_wear_os/services/bridge_manager.dart';
import 'package:bridge_wear_os/screens/device_discovery_screen.dart';
import 'package:bridge_wear_os/screens/notification_settings_screen.dart';
import 'package:bridge_wear_os/utils/responsive_utils.dart';
import 'package:bridge_wear_os/providers/bluetooth_provider.dart';
import 'package:bridge_wear_os/services/health_service.dart';
import 'package:bridge_wear_os/widgets/message_bubble.dart';
import 'package:bridge_wear_os/widgets/wear_chip.dart';
import 'package:bridge_wear_os/widgets/connection_dot.dart';
import 'package:bridge_wear_os/widgets/round_clipper.dart';

class BridgeScreen extends ConsumerStatefulWidget {
  const BridgeScreen({super.key});

  @override
  ConsumerState<BridgeScreen> createState() => _BridgeScreenState();
}

class _BridgeScreenState extends ConsumerState<BridgeScreen> {
  late BridgeManager _bridgeManager;
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  final List<BridgeMessage> _messages = [];
  StreamSubscription<BridgeMessage>? _messageSubscription;
  bool _isInputExpanded = false;
  bool _isHealthInitialized = false;
  bool _isSyncingHealth = false;

  @override
  void initState() {
    super.initState();
    _initializeBridge();
    _initializeHealth();
  }

  void _initializeBridge() {
    final bluetoothService = ref.read(bluetoothServiceProvider);
    _bridgeManager = BridgeManager(bluetoothService);

    _messageSubscription = _bridgeManager.messages.listen((message) {
      if (!mounted) return;
      setState(() {
        _messages.add(message);
        if (_messages.length > 20) {
          _messages.removeAt(0);
        }
      });
    });
  }

  Future<void> _initializeHealth() async {
    final healthService = ref.read(healthServiceProvider);
    await healthService.initialize();
    if (healthService.isAvailable) {
      final granted = await healthService.requestPermissions();
      if (granted) {
        await healthService.fetchAllData();
      }
    }
    if (mounted) {
      setState(() => _isHealthInitialized = true);
    }
  }

  Future<void> _sendNotification() async {
    if (_titleController.text.isEmpty || _messageController.text.isEmpty) {
      _showSnackBar('Fill in all fields');
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
      setState(() => _isInputExpanded = false);
      _showSnackBar('Sent!');
    } else {
      _showSnackBar('Failed to send');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle(fontSize: context.fontSize(11))),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _sendPing() async {
    bool success = await _bridgeManager.sendPing();
    if (!mounted) return;
    _showSnackBar(success ? 'Ping sent!' : 'Failed');
  }

  Future<void> _syncAndSendHealthData() async {
    final healthService = ref.read(healthServiceProvider);

    if (!healthService.isAvailable) {
      _showSnackBar('Health Connect not available');
      return;
    }

    if (!healthService.hasPermissions) {
      final granted = await healthService.requestPermissions();
      if (!granted) {
        _showSnackBar('Health permissions not granted');
        return;
      }
    }

    setState(() => _isSyncingHealth = true);

    await healthService.fetchAllData();

    if (!mounted) return;

    final data = healthService.getHealthDataMap();
    bool success = await _bridgeManager.sendHealthData(
      steps: data['steps'] as int,
      heartRate: data['heartRate'] as int,
      calories: data['calories'] as double,
      sleepData: data['sleepData'] as Map<String, dynamic>,
    );

    setState(() => _isSyncingHealth = false);

    if (!mounted) return;
    _showSnackBar(success ? 'Health data sent!' : 'Failed to send');
  }

  Future<void> _disconnect() async {
    final bluetoothService = ref.read(bluetoothServiceProvider);
    _bridgeManager.dispose();
    await bluetoothService.disconnect();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const DeviceDiscoveryScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = context.screenWidth;
    final isSmall = screenWidth < 200;

    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: SafeArea(
        child: context.isRound
            ? RoundClip(
                child: Column(
                  children: [
                    _buildHeader(),
                    _buildConnectionBar(),
                    SizedBox(height: context.padding(6)),
                    _buildActionChips(isSmall),
                    SizedBox(height: context.padding(6)),
                    _buildInputSection(isSmall),
                    SizedBox(height: context.padding(4)),
                    Expanded(child: _buildMessageList(isSmall)),
                  ],
                ),
              )
            : Column(
                children: [
                  _buildHeader(),
                  _buildConnectionBar(),
                  SizedBox(height: context.padding(6)),
                  _buildActionChips(isSmall),
                  SizedBox(height: context.padding(6)),
                  _buildInputSection(isSmall),
                  SizedBox(height: context.padding(4)),
                  Expanded(child: _buildMessageList(isSmall)),
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
          Icon(Icons.connected_tv,
              size: context.iconSize(18), color: Colors.green),
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
            icon: Icon(Icons.close, size: context.iconSize(16)),
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

  Widget _buildConnectionBar() {
    return Consumer(
      builder: (context, ref, child) {
        final service = ref.watch(bluetoothServiceProvider);
        return StreamBuilder<bool>(
          stream: service.connectionState,
          builder: (context, snapshot) {
            final isConnected = snapshot.data ?? false;
            final deviceName =
                service.connectedDevice?.platformName ?? 'Unknown';

            return Padding(
              padding: EdgeInsets.symmetric(horizontal: context.padding(10)),
              child: Container(
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
                    ConnectionDot(
                      isConnected: isConnected,
                      size: context.iconSize(8),
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
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildActionChips(bool isSmall) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: context.padding(10)),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: WearChip(
                  icon: Icons.speed,
                  label: 'Ping',
                  onPressed: _sendPing,
                  color: Colors.blue,
                ),
              ),
              SizedBox(width: context.padding(6)),
              Expanded(
                child: WearChip(
                  icon: Icons.favorite,
                  label: 'Health',
                  onPressed: _syncAndSendHealthData,
                  color: Colors.pink,
                ),
              ),
              SizedBox(width: context.padding(6)),
              Expanded(
                child: WearChip(
                  icon: Icons.send,
                  label: 'Send',
                  onPressed: () =>
                      setState(() => _isInputExpanded = !_isInputExpanded),
                  color: Colors.amber,
                ),
              ),
            ],
          ),
          SizedBox(height: context.padding(4)),
          Row(
            children: [
              Expanded(
                child: WearChip(
                  icon: Icons.notifications,
                  label: 'Notif',
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const NotificationSettingsScreen()),
                    );
                  },
                  color: Colors.purple,
                ),
              ),
              SizedBox(width: context.padding(6)),
              // Spacer to keep Notif chip left-aligned
              const Spacer(),
            ],
          ),
          SizedBox(height: context.padding(4)),
          Consumer(
            builder: (context, ref, child) {
              final healthService = ref.watch(healthServiceProvider);
              return _buildHealthStatusBar(healthService);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHealthStatusBar(HealthService healthService) {
    if (!_isHealthInitialized) {
      return const SizedBox.shrink();
    }

    if (!healthService.isAvailable) {
      return Container(
        padding: EdgeInsets.symmetric(
          horizontal: context.padding(8),
          vertical: context.padding(4),
        ),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(context.padding(6)),
          border: Border.all(color: Colors.orange, width: 0.5),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline,
                size: context.iconSize(10), color: Colors.orange),
            SizedBox(width: context.padding(4)),
            Expanded(
              child: Text(
                'Health Connect not available',
                style: TextStyle(
                  fontSize: context.fontSize(9),
                  color: Colors.orange,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_isSyncingHealth) {
      return Container(
        padding: EdgeInsets.symmetric(
          horizontal: context.padding(8),
          vertical: context.padding(4),
        ),
        child: Row(
          children: [
            SizedBox(
              width: context.iconSize(10),
              height: context.iconSize(10),
              child: const CircularProgressIndicator(strokeWidth: 1.5),
            ),
            SizedBox(width: context.padding(4)),
            Text(
              'Syncing health data...',
              style: TextStyle(
                fontSize: context.fontSize(9),
                color: Colors.white70,
              ),
            ),
          ],
        ),
      );
    }

    if (!healthService.hasPermissions) {
      return Container(
        padding: EdgeInsets.symmetric(
          horizontal: context.padding(8),
          vertical: context.padding(4),
        ),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(context.padding(6)),
          border: Border.all(color: Colors.orange, width: 0.5),
        ),
        child: Row(
          children: [
            Icon(Icons.shield_outlined,
                size: context.iconSize(10), color: Colors.orange),
            SizedBox(width: context.padding(4)),
            Expanded(
              child: Text(
                'Health permissions needed',
                style: TextStyle(
                  fontSize: context.fontSize(9),
                  color: Colors.orange,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Show current health data summary
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.padding(8),
        vertical: context.padding(4),
      ),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(context.padding(6)),
        border: Border.all(color: Colors.green, width: 0.5),
      ),
      child: Row(
        children: [
          Icon(Icons.favorite,
              size: context.iconSize(10), color: Colors.green),
          SizedBox(width: context.padding(4)),
          Flexible(
            child: Text(
              'Steps: ${healthService.steps}',
              style: TextStyle(
                fontSize: context.fontSize(9),
                color: Colors.white70,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(width: context.padding(4)),
          Flexible(
            child: Text(
              'HR: ${healthService.heartRate}',
              style: TextStyle(
                fontSize: context.fontSize(9),
                color: Colors.white70,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(width: context.padding(4)),
          Flexible(
            child: Text(
              'Cal: ${healthService.calories.toStringAsFixed(0)}',
              style: TextStyle(
                fontSize: context.fontSize(9),
                color: Colors.white70,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputSection(bool isSmall) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      height: _isInputExpanded ? (isSmall ? 100 : 120) : 0,
      child: _isInputExpanded
          ? Padding(
              padding: EdgeInsets.symmetric(horizontal: context.padding(10)),
              child: Card(
                color: Colors.white.withValues(alpha: 0.05),
                child: Padding(
                  padding: EdgeInsets.all(context.padding(8)),
                  child: Column(
                    children: [
                      TextField(
                        controller: _titleController,
                        style: TextStyle(fontSize: context.fontSize(11)),
                        decoration: InputDecoration(
                          hintText: 'Title',
                          hintStyle: TextStyle(fontSize: context.fontSize(10)),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: context.padding(8),
                            vertical: context.padding(4),
                          ),
                          isDense: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                      SizedBox(height: context.padding(4)),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _messageController,
                              style: TextStyle(fontSize: context.fontSize(11)),
                              decoration: InputDecoration(
                                hintText: 'Message',
                                hintStyle:
                                    TextStyle(fontSize: context.fontSize(10)),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: context.padding(8),
                                  vertical: context.padding(4),
                                ),
                                isDense: true,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: context.padding(4)),
                          SizedBox(
                            height: context.buttonHeight(32),
                            child: ElevatedButton(
                              onPressed: _sendNotification,
                              style: ElevatedButton.styleFrom(
                                padding: EdgeInsets.symmetric(
                                  horizontal: context.padding(8),
                                ),
                              ),
                              child: Icon(Icons.send,
                                  size: context.iconSize(14)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            )
          : const SizedBox.shrink(),
    );
  }

  Widget _buildMessageList(bool isSmall) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: context.padding(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.message,
                  size: context.iconSize(12), color: Colors.white70),
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
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline,
                            size: context.iconSize(24), color: Colors.white24),
                        SizedBox(height: context.padding(8)),
                        Text(
                          'No messages yet',
                          style: TextStyle(
                            fontSize: context.fontSize(11),
                            color: Colors.white38,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    reverse: true,
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message =
                          _messages[_messages.length - 1 - index];
                      return MessageBubble(
                        message: message,
                        isOutgoing: message.type == MessageType.notification ||
                            message.type == MessageType.health ||
                            message.type == MessageType.ping,
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
    _messageController.dispose();
    _titleController.dispose();
    _messageSubscription?.cancel();
    _bridgeManager.dispose();
    super.dispose();
  }
}
