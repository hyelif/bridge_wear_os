import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:bridge_wear_os/services/bluetooth_service.dart';
import 'package:bridge_wear_os/screens/device_discovery_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => BluetoothService())],
      child: MaterialApp(
        title: 'Bridge - Wear OS & iOS',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
        ),
        home: const DeviceDiscoveryScreen(),
      ),
    );
  }
}
