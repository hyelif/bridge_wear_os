import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bridge_wear_os/services/bluetooth_service.dart';

// Keep BluetoothService as ChangeNotifier, wrap with Riverpod
final bluetoothServiceProvider = ChangeNotifierProvider<BluetoothService>((ref) {
  return BluetoothService();
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
