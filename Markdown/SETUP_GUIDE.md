# Setup Guide

## Requirements

- Flutter SDK with Dart 3.12 compatible toolchain.
- Android Studio + Android SDK for Wear OS builds.
- Xcode + Apple signing for iOS builds, or remote macOS CI signing.
- Physical Wear OS watch for BLE server/peripheral testing.
- Physical iPhone for Core Bluetooth testing.

Simulators/emulators are not enough for final BLE validation.

## Project Setup

```bash
cd /home/alif/Documents/bridge_wear_os
flutter pub get
flutter analyze
flutter test
```

## Android / Wear OS

Check SDK:

```bash
echo "$ANDROID_HOME"
flutter doctor -v
```

Run:

```bash
flutter devices
flutter run -d <wear-device-id>
```

Debug logs:

```bash
adb logcat | grep -i bridge
adb logcat | grep -i bluetooth
```

Current native file:

```text
android/app/src/main/kotlin/com/example/bridge_wear_os/BridgeBluetoothService.kt
```

Needed next:
- Foreground service for long-lived advertising.
- Runtime permission flow for Bluetooth advertise/connect/scan.
- Channel events from native write requests into Flutter.

## iOS

Normal local path:

```bash
open ios/Runner.xcworkspace
```

In Xcode:
- Set bundle id.
- Set signing team.
- Use physical iPhone.
- Enable required Bluetooth background modes only when implemented and tested.

Run:

```bash
flutter devices
flutter run -d <ios-device-id>
```

Current native file:

```text
ios/Runner/BridgeBluetoothManager.swift
```

Needed next:
- Platform channel from Swift to Flutter for incoming BLE writes.
- Platform channel from Flutter to Swift for outgoing notify.
- Real signing/export setup for IPA.

Linux-to-iPhone notes live in `IOS_App_Installation_Guide.md`.

## Development Order

1. Verify app opens on both devices.
2. Wire native BLE writes into Flutter.
3. Wire Flutter send into native notify.
4. Build ping/pong.
5. Add chunking/reassembly.
6. Add pairing/authentication.
7. Add encryption.
8. Add reconnect/background logic.
9. Add feature modules.

## Adding Message Types

Edit `lib/models/bridge_message.dart`:

```dart
enum MessageType {
  notification,
  health,
  mediaControl,
  contactSync,
  cameraControl,
  deviceInfo,
  ping,
  acknowledgment,
  yourNewType,
}
```

Add helper in `lib/services/bridge_manager.dart`:

```dart
Future<bool> sendYourNewMessage({required String data}) {
  return sendMessage(
    MessageType.yourNewType,
    {
      'data': data,
      'timestamp': DateTime.now().toIso8601String(),
    },
  );
}
```

Update UI display in `lib/screens/bridge_screen.dart`.

## Common Issues

Devices not found:
- Bluetooth off.
- Missing runtime permission.
- Wrong BLE role.
- Advertisement not running.
- UUID mismatch.

Message send times out:
- Native write never reached Flutter.
- Ack not sent.
- Payload too large for MTU.
- Notify subscription missing.

iOS install fails:
- IPA not signed.
- Provisioning profile does not include device UDID.
- Bundle id mismatch.
- Developer Mode off.

Android build fails:
- `ANDROID_HOME` missing.
- SDK not installed.
- Watch target not connected.
