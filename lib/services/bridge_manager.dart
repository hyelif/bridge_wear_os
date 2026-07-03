// Bridge Manager coordinates communication between devices.
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:bridge_wear_os/models/bridge_message.dart';
import 'package:bridge_wear_os/services/bluetooth_service.dart';

class BridgeManager extends ChangeNotifier {
  final BluetoothService bluetoothService;

  // Message handling
  final Map<String, Completer<void>> _pendingAcknowledgments = {};
  final List<BridgeMessage> _messageHistory = [];
  final StreamController<BridgeMessage> _messageStream =
      StreamController<BridgeMessage>.broadcast();

  late StreamSubscription _bluetoothSubscription;
  Stream<BridgeMessage> get messages => _messageStream.stream;
  List<BridgeMessage> get messageHistory => List.unmodifiable(_messageHistory);
  bool get isConnected => bluetoothService.isConnected;

  BridgeManager(this.bluetoothService) {
    _initialize();
  }

  /// Initialize the bridge manager
  void _initialize() {
    // Listen to incoming messages from Bluetooth
    _bluetoothSubscription = bluetoothService.messageReceived.listen((data) {
      _handleIncomingData(data);
    });
  }

  /// Handle incoming data from Bluetooth
  void _handleIncomingData(Uint8List data) {
    try {
      String jsonStr = utf8.decode(data);
      BridgeMessage message = BridgeMessage.fromJson(jsonStr);

      debugPrint('Message received: $message');

      // Add to history
      _messageHistory.add(message);
      if (_messageHistory.length > 100) {
        _messageHistory.removeAt(0); // Keep only last 100 messages
      }

      // Emit message
      _messageStream.add(message);

      // Send acknowledgment if required
      if (message.requiresAck) {
        _sendAcknowledgment(message.id);
      }

      if (message.type == MessageType.acknowledgment) {
        final acknowledgedId = message.payload['messageId'] as String?;
        final completer = _pendingAcknowledgments.remove(acknowledgedId);
        if (completer != null && !completer.isCompleted) {
          completer.complete();
        }
      }
    } catch (e) {
      debugPrint('Error handling incoming data: $e');
    }
  }

  /// Send a message with acknowledgment handling
  Future<bool> sendMessage(
    MessageType type,
    Map<String, dynamic> payload, {
    bool requiresAck = true,
  }) async {
    if (!bluetoothService.isConnected) {
      debugPrint('Not connected to device');
      return false;
    }

    try {
      String messageId = const Uuid().v4();
      BridgeMessage message = BridgeMessage(
        id: messageId,
        type: type,
        payload: payload,
        requiresAck: requiresAck,
      );

      // If ack is required, set up a completer for the acknowledgment
      if (requiresAck) {
        _pendingAcknowledgments[messageId] = Completer<void>();
      }

      // Convert to bytes and send
      Uint8List data = utf8.encode(message.toJson());
      bool sent = await bluetoothService.sendMessage(data);

      if (!sent) {
        _pendingAcknowledgments.remove(messageId);
        return false;
      }

      // Wait for acknowledgment if required
      if (requiresAck) {
        try {
          await _pendingAcknowledgments[messageId]!.future.timeout(
            const Duration(seconds: 5),
          );
        } on TimeoutException {
          debugPrint('Acknowledgment timeout for message: $messageId');
          _pendingAcknowledgments.remove(messageId);
          return false;
        }
      }

      return true;
    } catch (e) {
      debugPrint('Error sending message: $e');
      return false;
    }
  }

  /// Send acknowledgment for a received message
  Future<void> _sendAcknowledgment(String messageId) async {
    try {
      BridgeMessage ackMessage = BridgeMessage(
        id: const Uuid().v4(),
        type: MessageType.acknowledgment,
        payload: {'messageId': messageId},
        requiresAck: false,
      );

      Uint8List data = utf8.encode(ackMessage.toJson());
      await bluetoothService.sendMessage(data);
    } catch (e) {
      debugPrint('Error sending acknowledgment: $e');
    }
  }

  /// Send notification message
  Future<bool> sendNotification({
    required String title,
    required String body,
    String? appName,
  }) async {
    return sendMessage(MessageType.notification, {
      'title': title,
      'body': body,
      'appName': appName,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// Send health data
  Future<bool> sendHealthData({
    required int? steps,
    required int? heartRate,
    required double? calories,
    required Map<String, dynamic>? sleepData,
  }) async {
    return sendMessage(MessageType.health, {
      'steps': steps,
      'heartRate': heartRate,
      'calories': calories,
      'sleepData': sleepData,
    });
  }

  /// Send media control command
  Future<bool> sendMediaControl({required String action, dynamic value}) async {
    return sendMessage(MessageType.mediaControl, {
      'action': action,
      'value': value,
    });
  }

  /// Send ping to check connection
  Future<bool> sendPing() async {
    return sendMessage(MessageType.ping, {
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// Clear message history
  void clearHistory() {
    _messageHistory.clear();
    notifyListeners();
  }

  /// Cleanup resources
  @override
  void dispose() {
    _bluetoothSubscription.cancel();
    _messageStream.close();
    for (var completer in _pendingAcknowledgments.values) {
      if (!completer.isCompleted) {
        completer.completeError('Bridge manager disposed');
      }
    }
    super.dispose();
  }
}
