# Bridge Wear OS

Flutter prototype for Bluetooth Low Energy communication between a Wear OS watch and an iPhone.

## Status

Not production-ready. Dart layer builds/analyzes, but end-to-end Wear OS to iOS bridge still needs native platform-channel work.

Working now:
- Flutter dependencies resolve with `flutter pub get`.
- Dart BLE central/client code scans for Bridge service UUID through `flutter_blue_plus`.
- Bridge messages serialize as JSON.
- Acknowledgments match by `payload.messageId`.
- Android native GATT server prototype exists.
- iOS native Core Bluetooth peripheral prototype exists.

Missing before real use:
- Native BLE events bridged into Flutter with `EventChannel`.
- Flutter commands bridged to native BLE server/peripheral APIs with `MethodChannel`.
- BLE chunking/reassembly above negotiated MTU.
- Pairing/authentication.
- App-level encryption for sensitive payloads.
- Reconnect and background behavior tested on physical devices.
- Real HealthKit, Android health, notification, and media integrations.

## Docs

- [Architecture](Markdown/BRIDGE_ARCHITECTURE.md)
- [Setup Guide](Markdown/SETUP_GUIDE.md)
- [Quick Reference](Markdown/QUICK_REFERENCE.md)
- [Implementation Summary](Markdown/IMPLEMENTATION_SUMMARY.md)
- [BLE Review and Roadmap](Markdown/WEAR_IOS_BLE_REVIEW.md)
- [iOS Linux Install Notes](Markdown/IOS_App_Installation_Guide.md)

## Commands

```bash
flutter pub get
flutter analyze
flutter test
flutter run -d <device-id>
```

Android builds need Android SDK and `ANDROID_HOME`. iOS builds need Xcode or a working remote macOS build/signing flow. BLE testing needs physical devices.
