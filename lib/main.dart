import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:bridge_wear_os/services/bluetooth_service.dart';
import 'package:bridge_wear_os/screens/device_discovery_screen.dart';
import 'package:bridge_wear_os/utils/responsive_theme.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => BluetoothService())],
      child: Builder(
        builder: (context) {
          // Get responsive theme based on screen size
          final theme = ResponsiveTheme.getTheme(context);
          return MaterialApp(
            title: 'Bridge - Wear OS',
            debugShowCheckedModeBanner: false,
            theme: theme,
            home: const DeviceDiscoveryScreen(),
          );
        },
      ),
    );
  }
}