// Data model for bridge messages between Wear OS and iOS.
import 'dart:convert';

enum MessageType {
  notification,
  health,
  mediaControl,
  contactSync,
  cameraControl,
  deviceInfo,
  ping,
  acknowledgment,
}

class BridgeMessage {
  final String id;
  final MessageType type;
  final Map<String, dynamic> payload;
  final DateTime timestamp;
  final bool requiresAck;

  BridgeMessage({
    required this.id,
    required this.type,
    required this.payload,
    DateTime? timestamp,
    this.requiresAck = true,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Convert message to JSON for transmission
  String toJson() {
    return jsonEncode({
      'id': id,
      'type': type.toString().split('.').last,
      'payload': payload,
      'timestamp': timestamp.toIso8601String(),
      'requiresAck': requiresAck,
    });
  }

  /// Parse JSON to create message
  factory BridgeMessage.fromJson(String jsonStr) {
    final json = jsonDecode(jsonStr) as Map<String, dynamic>;
    return BridgeMessage(
      id: json['id'] as String,
      type: MessageType.values.firstWhere(
        (e) => e.toString().split('.').last == json['type'],
        orElse: () => MessageType.ping,
      ),
      payload: json['payload'] as Map<String, dynamic>? ?? {},
      timestamp: DateTime.parse(json['timestamp'] as String),
      requiresAck: json['requiresAck'] as bool? ?? true,
    );
  }

  @override
  String toString() =>
      'BridgeMessage(id: $id, type: $type, timestamp: $timestamp)';
}
