import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:bridge_wear_os/services/bluetooth_service.dart';
import 'package:bridge_wear_os/services/health_service.dart';
import 'package:bridge_wear_os/services/notification_service.dart';

// Keep BluetoothService as ChangeNotifier, wrap with Riverpod
final bluetoothServiceProvider = ChangeNotifierProvider<BluetoothService>((ref) {
  return BluetoothService();
});

// Health Service provider
final healthServiceProvider = ChangeNotifierProvider<HealthService>((ref) {
  return HealthService();
});

// Notification Service provider
final notificationServiceProvider = ChangeNotifierProvider<NotificationService>((ref) {
  final bluetoothService = ref.watch(bluetoothServiceProvider);
  return NotificationService(bluetoothService);
});

// Derived state providers for convenience
final bluetoothConnectionProvider = Provider<bool>((ref) {
  final service = ref.watch(bluetoothServiceProvider);
  return service.isConnected;
});

final bluetoothScanningProvider = Provider<bool>((ref) {
  final service = ref.watch(bluetoothServiceProvider);
  return service.isScanning;
});

/// Exposes whether a saved device exists and auto-reconnect is pending.
final autoReconnectProvider = Provider<AutoReconnectState>((ref) {
  final service = ref.watch(bluetoothServiceProvider);
  return AutoReconnectState(
    hasSavedDevice: service.savedDeviceId != null,
    isAutoReconnecting: service.isAutoReconnecting,
  );
});

class AutoReconnectState {
  final bool hasSavedDevice;
  final bool isAutoReconnecting;

  const AutoReconnectState({
    required this.hasSavedDevice,
    required this.isAutoReconnecting,
  });

  bool get isPending => hasSavedDevice && isAutoReconnecting;
}
