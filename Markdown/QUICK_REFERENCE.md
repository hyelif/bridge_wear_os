# Quick Reference

## Commands

```bash
flutter pub get
flutter analyze
flutter test
flutter devices
flutter run -d <device-id>
```

## Files

| Area | File |
|---|---|
| App entry | `lib/main.dart` |
| Message model | `lib/models/bridge_message.dart` |
| BLE client | `lib/services/bluetooth_service.dart` |
| Protocol manager | `lib/services/bridge_manager.dart` |
| Discovery UI | `lib/screens/device_discovery_screen.dart` |
| Bridge UI | `lib/screens/bridge_screen.dart` |
| Android BLE server prototype | `android/app/src/main/kotlin/com/example/bridge_wear_os/BridgeBluetoothService.kt` |
| iOS BLE peripheral prototype | `ios/Runner/BridgeBluetoothManager.swift` |

## BLE UUIDs

```text
Service: 12345678-1234-5678-1234-56789012345a
Write:   12345678-1234-5678-1234-56789012345b
Notify:  12345678-1234-5678-1234-56789012345c
```

## Send Examples

```dart
await bridgeManager.sendPing();

await bridgeManager.sendNotification(
  title: 'Hello',
  body: 'Message body',
  appName: 'Bridge App',
);

await bridgeManager.sendMessage(
  MessageType.notification,
  {'custom': 'data'},
);
```

## Listen

```dart
bridgeManager.messages.listen((message) {
  print(message.type);
  print(message.payload);
});
```

## Current Truth

Prototype works at Flutter protocol level. Real end-to-end BLE needs:
- native channel wiring
- chunking/reassembly
- pairing/authentication
- encryption
- reconnect/background behavior
- physical-device testing

## Source Of Truth

Read first:
- `README.md`
- `Markdown/WEAR_IOS_BLE_REVIEW.md`
- `Markdown/BRIDGE_ARCHITECTURE.md`
