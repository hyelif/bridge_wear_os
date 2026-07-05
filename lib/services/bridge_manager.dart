// Bridge Manager - coordinates communication between devices
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:bridge_wear_os/models/bridge_message.dart';
import 'package:bridge_wear_os/services/bluetooth_service.dart';

class BridgeManager extends ChangeNotifier {
  final BluetoothService bluetoothService;

  final List<BridgeMessage> _messageHistory = [];
  final StreamController<BridgeMessage> _messageStream =
      StreamController<BridgeMessage>.broadcast();

  StreamSubscription? _bluetoothSubscription;
  Stream<BridgeMessage> get messages => _messageStream.stream;
  List<BridgeMessage> get messageHistory => List.unmodifiable(_messageHistory);
  bool get isConnected => bluetoothService.isConnected;

  BridgeManager(this.bluetoothService) {
    _initialize();
  }

  void _initialize() {
    // Listen to incoming messages
    _bluetoothSubscription = bluetoothService.messageReceived.listen((data) {
      _handleIncomingData(data);
    });
  }

  void _handleIncomingData(Map<String, dynamic> data) {
    try {
      final typeStr = data['type'] as String? ?? 'ping';
      final payload = data['payload'] as Map<String, dynamic>? ?? {};

      final message = BridgeMessage(
        id: const Uuid().v4(),
        type: MessageType.values.firstWhere(
          (e) => e.toString().split('.').last == typeStr,
          orElse: () => MessageType.ping,
        ),
        payload: payload,
        requiresAck: false,
      );

      debugPrint('[Bridge] Received: ${message.type}');

      _messageHistory.add(message);
      if (_messageHistory.length > 20) {
        _messageHistory.removeAt(0);
      }

      _messageStream.add(message);
    } catch (e) {
      debugPrint('[Bridge] Handle error: $e');
    }
  }

  /// Send message to connected device
  Future<bool> sendMessage(MessageType type, Map<String, dynamic> payload) async {
    if (!bluetoothService.isConnected) {
      debugPrint('[Bridge] Not connected');
      return false;
    }

    try {
      return await bluetoothService.sendMessage(type.toString().split('.').last, payload);
    } catch (e) {
      debugPrint('[Bridge] Send error: $e');
      return false;
    }
  }

  /// Send notification
  Future<bool> sendNotification({
    required String title,
    required String body,
    String? appName,
  }) async {
    return sendMessage(MessageType.notification, {
      'title': title,
      'body': body,
      'appName': appName ?? 'Bridge',
    });
  }

  /// Send health data
  Future<bool> sendHealthData({
    required int steps,
    required int heartRate,
    required double calories,
    required Map<String, dynamic> sleepData,
  }) async {
    return sendMessage(MessageType.health, {
      'steps': steps,
      'heartRate': heartRate,
      'calories': calories,
      'sleepData': sleepData,
    });
  }

  /// Send ping
  Future<bool> sendPing() async {
    return sendMessage(MessageType.ping, {'time': DateTime.now().toIso8601String()});
  }

  @override
  void dispose() {
    _bluetoothSubscription?.cancel();
    _messageStream.close();
    super.dispose();
  }
}