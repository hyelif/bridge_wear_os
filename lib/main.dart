import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bridge_wear_os/screens/device_discovery_screen.dart';
import 'package:bridge_wear_os/utils/responsive_theme.dart';

void main() {
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ResponsiveTheme.getTheme(context);
    return MaterialApp(
      title: 'Bridge - Wear OS',
      debugShowCheckedModeBanner: false,
      theme: theme,
      home: const DeviceDiscoveryScreen(),
    );
  }
}