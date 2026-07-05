import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:bridge_wear_os/services/bluetooth_service.dart';

class NotificationService extends ChangeNotifier {
  final BluetoothService _bluetoothService;
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  // Per-app allowlist (bundle IDs allowed to send notifications)
  List<String> _allowedApps = [];
  bool _allowAll = true; // When true, all apps allowed

  // Notification history
  final List<Map<String, dynamic>> _notificationHistory = [];

  StreamSubscription? _messageSubscription;

  List<String> get allowedApps => List.unmodifiable(_allowedApps);
  bool get allowAll => _allowAll;
  List<Map<String, dynamic>> get notificationHistory => List.unmodifiable(_notificationHistory);

  NotificationService(this._bluetoothService) {
    _initialize();
  }

  Future<void> _initialize() async {
    // Initialize flutter_local_notifications
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    await _plugin.initialize(initSettings);

    // Listen for notification messages from BLE
    _messageSubscription = _bluetoothService.messageReceived.listen((data) {
      _handleIncomingNotification(data);
    });

    debugPrint('[Notif] Service initialized');
  }

  void _handleIncomingNotification(Map<String, dynamic> data) {
    final type = data['type'] as String?;
    if (type != 'notification') return;

    final payload = data['payload'] as Map<String, dynamic>? ?? {};
    final appBundleId = payload['appBundleId'] as String? ?? 'unknown';
    final appName = payload['appName'] as String? ?? 'Unknown';
    final title = payload['title'] as String? ?? '';
    final body = payload['body'] as String? ?? '';

    // Check if this app is allowed
    if (!_allowAll && !_allowedApps.contains(appBundleId)) {
      debugPrint('[Notif] Blocked notification from $appBundleId');
      return;
    }

    // Add to history
    _notificationHistory.add({
      'appBundleId': appBundleId,
      'appName': appName,
      'title': title,
      'body': body,
      'timestamp': DateTime.now().toIso8601String(),
    });
    if (_notificationHistory.length > 50) {
      _notificationHistory.removeAt(0);
    }

    // Show as Wear OS notification
    _showLocalNotification(appName, title, body, appBundleId);

    notifyListeners();
  }

  Future<void> _showLocalNotification(String appName, String title, String body, String bundleId) async {
    try {
      const androidDetails = AndroidNotificationDetails(
        'bridge_notifications',
        'Bridge Notifications',
        channelDescription: 'Notifications forwarded from iPhone',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        autoCancel: true,
        fullScreenIntent: false,
      );

      const details = NotificationDetails(android: androidDetails);

      await _plugin.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000, // unique ID
        title.isNotEmpty ? title : appName,
        body,
        details,
        payload: bundleId, // pass bundle ID for dismiss handling
      );
    } catch (e) {
      debugPrint('[Notif] Show error: $e');
    }
  }

  /// Update the per-app allowlist
  void updateAllowedApps(List<String> apps) {
    _allowedApps = List.from(apps);
    _allowAll = apps.isEmpty;
    notifyListeners();
    debugPrint('[Notif] Allowlist updated: ${apps.length} apps');
  }

  /// Enable/disable a specific app
  void toggleApp(String bundleId) {
    if (_allowedApps.contains(bundleId)) {
      _allowedApps.remove(bundleId);
    } else {
      _allowedApps.add(bundleId);
    }
    _allowAll = _allowedApps.isEmpty;
    notifyListeners();
  }

  /// Check if a specific app is allowed
  bool isAppAllowed(String bundleId) {
    return _allowAll || _allowedApps.contains(bundleId);
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    super.dispose();
  }
}
