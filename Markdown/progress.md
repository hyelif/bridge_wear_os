# Bridge Wear OS — Project Progress

## Overview

BLE bridge app connecting Wear OS watch (Samsung SM300/Watch 7) to iPhone. Watch acts as BLE central (scanner/connector), iPhone acts as BLE peripheral (advertiser). Bidirectional JSON message communication.

---

## Architecture

### BLE Topology
- **Wear OS (watch)** = BLE Central — scans, connects, reads/writes characteristics via `flutter_blue_plus`
- **iOS (iPhone)** = BLE Peripheral — advertises service, responds to read/write, sends notifications via `CBPeripheralManager`
- **UUIDs:** service=`12345678-1234-5678-1234-56789012345a`, write char=`...b`, notify char=`...c`
- **iOS advertises as:** "Bridge-iPhone"

### State Management
- **Riverpod** (`flutter_riverpod: ^2.6.1`) — `ChangeNotifierProvider<BluetoothService>`, derived providers for connection/scanning state
- **BridgeManager** — message protocol layer, listens to BLE stream, creates `BridgeMessage` objects

### Native ↔ Flutter Bridge
- **iOS:** `FlutterMethodChannel("com.bridge.ble")` — native BLE events forwarded to Dart
- **Android:** `MethodChannel("com.bridge.wear_os/platform")` — SDK version query only

---

## Files & Implementation Status

### Core Services

| File | Status | Description |
|------|--------|-------------|
| `lib/services/bluetooth_service.dart` | ✅ Complete | BLE central service: duty-cycled scan (5s on/10s off ×3), connect with retry (3×500ms), service discovery, send/receive JSON, platform-specific permissions. Auto-reconnect: saves device ID to SharedPreferences, auto-connects on app start via `BluetoothDevice.fromId()`, listens to connectionState for disconnects, auto-reconnects with `autoConnect: true` |
| `lib/services/bridge_manager.dart` | ✅ Complete | Message protocol: listens to BLE stream, creates BridgeMessage objects, sendNotification/sendHealthData/sendPing helpers, 20-message history buffer |
| `lib/services/health_service.dart` | ✅ Complete | Health Connect integration: reads real steps, heart rate, sleep, calories via `health_connector` package. Permission request, data fetch, getHealthDataMap() for BLE transmission |
| `lib/services/notification_service.dart` | ✅ Complete | Notification forwarding receiver: listens to BLE messageReceived stream for `type: notification`, checks per-app allowlist, shows Wear OS notifications via `flutter_local_notifications`, maintains 50-entry history |
| `lib/models/bridge_message.dart` | ✅ Complete | Data model: MessageType enum (notification, health, mediaControl, contactSync, cameraControl, deviceInfo, ping, acknowledgment), JSON serialization |

### State Management (Riverpod)

| File | Status | Description |
|------|--------|-------------|
| `lib/providers/bluetooth_provider.dart` | ✅ Complete | `bluetoothServiceProvider` (ChangeNotifierProvider), `bluetoothConnectionProvider` (derived bool), `bluetoothScanningProvider` (derived bool), `autoReconnectProvider` (derived AutoReconnectState), `healthServiceProvider` (ChangeNotifierProvider) |

### Screens

| File | Status | Description |
|------|--------|-------------|
| `lib/screens/device_discovery_screen.dart` | ✅ Complete | Full-bleed black bg, pulsing Bluetooth icon, device cards with RSSI bars + BRIDGE badge, auto-rescan (3 retries ×10s), WearChip scan button, animated status transitions, auto-connect UI |
| `lib/screens/bridge_screen.dart` | ✅ Complete | Connection bar with ConnectionDot, action chips (Ping/Health/Send/Notif), expandable input section, message bubbles (incoming/outgoing), empty state with icon, health status bar, real health data sync |
| `lib/screens/notification_settings_screen.dart` | ✅ Complete | Per-app notification control UI: Allow All toggle, 18 iPhone app list with enable/disable, visual feedback (green highlight + check icon), Sync Settings to iPhone button |

### UI/Utilities

| File | Status | Description |
|------|--------|-------------|
| `lib/utils/responsive_theme.dart` | ✅ Complete | True black OLED (#000000), blue-cyan accent, pill-shaped chips (16px radius), 4 size tiers (small/medium/large/xlarge), dark glass card aesthetic |
| `lib/utils/responsive_utils.dart` | ✅ Complete | Screen size detection, font/padding/icon size multipliers, round screen detection, signal bars calculation, ambient mode helpers |

### Widgets

| File | Status | Description |
|------|--------|-------------|
| `lib/widgets/wear_chip.dart` | ✅ Complete | Pill-shaped action chip with icon + label, loading state, press animation |
| `lib/widgets/signal_bars.dart` | ✅ Complete | RSSI signal visualization (1-5 bars, color-coded red/amber/green) |
| `lib/widgets/connection_dot.dart` | ✅ Complete | Animated pulsing green/red dot with glow effect |
| `lib/widgets/device_card.dart` | ✅ Complete | Device list item with icon, name, BRIDGE badge, RSSI bars, connection indicator |
| `lib/widgets/message_bubble.dart` | ✅ Complete | Chat bubble (incoming left/outgoing right) with timestamp |
| `lib/widgets/round_clipper.dart` | ✅ Complete | Round screen clipping via CustomClipper<Path> |
| `lib/widgets/animated_status.dart` | ✅ Complete | Fade + slide status text with AnimatedSwitcher |

### iOS Native

| File | Status | Description |
|------|--------|-------------|
| `ios/Runner/AppDelegate.swift` | ✅ Complete | BridgePeripheralManager: CBPeripheralManagerDelegate, advertises as "Bridge-iPhone", handles read/write/subscribe, Flutter MethodChannel bridge, advertising power management (LOW_POWER/LOW_LATENCY), 60s timeout + 30s retry, deferred BLE setup for iOS 13+. **Notification forwarding:** UNUserNotificationCenterDelegate, per-app allowlist, BLE forward, dismiss handler |
| `ios/Runner/BridgeBluetoothManager.swift` | 🗑️ Deprecated | Dead code — comment header points to AppDelegate.swift |
| `ios/Runner/Info.plist` | ✅ Complete | NSBluetoothAlwaysUsageDescription, NSBluetoothPeripheralUsageDescription, NSBluetoothCentralUsageDescription, UIBackgroundModes (bluetooth-central, bluetooth-peripheral) |
| `ios/Runner/SceneDelegate.swift` | ✅ Complete | Empty FlutterSceneDelegate |
| `ios/Podfile` | ✅ Complete | Standard Flutter iOS Podfile, **platform :ios, '15.0'** (bumped from 13.0 for health-connector-hk-ios) |

### Android Native

| File | Status | Description |
|------|--------|-------------|
| `android/app/src/main/AndroidManifest.xml` | ✅ Complete | BLUETOOTH, BLUETOOTH_SCAN (neverForLocation), BLUETOOTH_CONNECT permissions. Wear OS feature flags. BridgeBluetoothService placeholder |
| `android/app/src/main/kotlin/.../MainActivity.kt` | ✅ Complete | No auto-start service. MethodChannel for SDK version query |
| `android/app/src/main/kotlin/.../BridgeBluetoothService.kt` | ⚠️ Placeholder | No GATT server — most Wear OS devices don't support peripheral mode |
| `android/app/build.gradle.kts` | ✅ Complete | minSdk=23, compileSdk=flutter.compileSdkVersion, Java 17 |

### CI/CD

| File | Status | Description |
|------|--------|-------------|
| `.github/workflows/ios-build.yml` | ✅ Complete | macOS runner, Flutter stable, pod install, flutter build ios --release --no-codesign, package IPA, upload as bridge-app-unsigned artifact |

### Entry Point

| File | Status | Description |
|------|--------|-------------|
| `lib/main.dart` | ✅ Complete | ProviderScope wrapping MyApp (ConsumerWidget), ResponsiveTheme.getTheme(context), home: DeviceDiscoveryScreen |

---

## Key Features Implemented

### BLE Communication
- [x] Watch scans for iPhone using duty-cycled scanning (5s scan + 10s pause × 3 cycles)
- [x] iPhone advertises as BLE peripheral with "Bridge-iPhone" name
- [x] Bidirectional JSON message exchange via BLE characteristics
- [x] Service discovery with retry logic (3 attempts × 500ms)
- [x] Fallback connection when Bridge service not found
- [x] Notification subscription for real-time data from iPhone
- [x] **Auto-Reconnect:** saves device ID to SharedPreferences, auto-connects on app start via `BluetoothDevice.fromId()`, listens to connectionState for disconnects, auto-reconnects with `autoConnect: true`, falls back to scan on timeout

### Battery Optimization
- [x] Duty-cycled BLE scanning (~60% less radio time vs continuous scan)
- [x] Advertising power management: LOW_POWER (idle) / LOW_LATENCY (when connected)
- [x] 60s advertising timeout + 30s retry pause on iOS
- [x] Auto-rescan with max 3 retries on Wear OS

### Permissions
- [x] Android: BLUETOOTH_SCAN (neverForLocation) + BLUETOOTH_CONNECT (API 31+)
- [x] Android: Legacy BLUETOOTH permission for API < 31
- [x] iOS: NSBluetoothAlwaysUsageDescription + NSBluetoothPeripheralUsageDescription + NSBluetoothCentralUsageDescription
- [x] iOS: Permission.bluetooth.request() via permission_handler
- [x] Proper denial handling with user-facing messages

### UI/UX (Wear OS)
- [x] True black OLED background (#000000)
- [x] 4 screen size tiers (small <200px → xlarge 360px+)
- [x] Round screen detection and clipping
- [x] Animated connection status dot (pulsing green/red)
- [x] RSSI signal strength bars (1-5 bars, color-coded)
- [x] Device cards with BRIDGE badge
- [x] Wear OS pill-shaped action chips
- [x] Message bubbles (incoming/outgoing) with timestamps
- [x] Fade + slide transitions for status text
- [x] Expandable input section with animation
- [x] Empty states with icons

### Health Data (Real Sensors)
- [x] Health Connect integration via `health_connector` package
- [x] Reads real steps, heart rate, sleep, calories from watch sensors
- [x] Permission request flow for Health Connect data types
- [x] Health data sent over BLE to iPhone
- [x] Health status bar showing live data summary
- [x] Graceful fallback when Health Connect unavailable

### Notification Forwarding
- [x] iOS: UNUserNotificationCenterDelegate captures incoming notifications
- [x] iOS: Forwards notifications over BLE to watch (title, body, appName, appBundleId)
- [x] iOS: Per-app allowlist stored in UserDefaults (empty = allow all)
- [x] iOS: MethodChannel handlers for getAllowedApps, setAllowedApps, getInstalledApps, dismissNotification
- [x] Watch: NotificationService receives BLE data, checks allowlist, shows Wear OS notification
- [x] Watch: NotificationSettingsScreen with Allow All toggle + 18 iPhone app list
- [x] Watch: Sync Settings to iPhone button sends config over BLE
- [x] Watch: 50-entry notification history in memory

### CI/CD
- [x] GitHub Actions workflow for unsigned iOS build
- [x] IPA packaging for SideStore installation
- [x] Build verification steps

---

## Dependencies (pubspec.yaml)

| Package | Version | Purpose |
|---------|---------|---------|
| flutter_blue_plus | ^1.31.8 | BLE central communication |
| permission_handler | ^12.0.3 | Runtime permission requests |
| uuid | ^4.0.0 | Message ID generation |
| flutter_riverpod | ^2.6.1 | State management |
| shared_preferences | ^2.3.0 | Persistent storage for saved device ID |
| health_connector | ^3.9.3 | Health Connect API for real sensor data |
| flutter_local_notifications | ^18.0.0 | Display forwarded notifications on Wear OS |
| flutter_lints | ^6.0.0 | Lint rules (dev) |

---

## Known Limitations

1. **BridgeBluetoothService.kt** — placeholder only. Most Wear OS devices don't support BLE peripheral mode (GATT server). Watch acts as central only.
2. **No encryption** — BLE communication is not encrypted. Data sent in plain JSON.
3. **iOS background mode** — BLE peripheral advertising continues in background, but iOS may suspend the app under memory pressure.
4. **No persistent pairing** — BLE bonding not implemented. Devices must re-discover each scan.
5. **Health Connect requires API 26+** — minSdk raised to 26. Older watches (pre-Android 8) won't support health data.
6. **Health Connect app required** — watch must have Health Connect installed (Samsung Health syncs to it).
7. **No real-time HR streaming** — health data reads from Health Connect (historical), not live sensor streaming. Real-time HR requires active workout session.
8. **iOS 15.0 minimum** — `health-connector-hk-ios` requires iOS 15+. iPhone 6s and older not supported.
9. **health_connector_hc_android KGP warning** — plugin applies Kotlin Gradle Plugin directly. Future Flutter versions may break. Monitor for updates.

---

## Build & Deploy

### Wear OS
```bash
flutter build apk --debug
# or
flutter build apk --release
```

### iOS (via GitHub Actions)
Push to `main` branch → GitHub Actions builds unsigned IPA → download from Actions artifacts → install via SideStore.

### Local iOS Build
```bash
flutter build ios --release --no-codesign
cd ios
mkdir -p Payload && cp -r ../build/ios/Release-iphoneos/Runner.app Payload/
zip -r ../build/ios/Runner.ipa Payload/
```

---

## Comparison: Bridge Wear Sync (Orienlabs) vs Our App

### BLE Topology — SAME

Both apps use **iPhone = BLE Peripheral, Watch = BLE Central**. This is correct because iOS restricts background BLE central mode — if iPhone were central, scanning would stop when app backgrounds.

| Aspect | Both Apps |
|--------|-----------|
| iPhone role | BLE Peripheral (advertises, waits) |
| Watch role | BLE Central (scans, connects) |
| Transport | Direct BLE, no cloud |
| Data format | JSON over BLE characteristics |

### Feature Gap Analysis

| Feature | Bridge Wear Sync | Our App | What's Needed |
|---------|-----------------|---------|---------------|
| **Notification Forwarding** | iOS captures real notifications → forwards to watch | Manual typed messages only | iOS `UNUserNotificationCenterDelegate` + BLE forward |
| **Per-app Notification Control** | Enable/disable which iPhone apps send to watch | None | Config UI + filter list synced to iOS |
| **Health Data from Watch Sensors** | Reads actual steps, HR, sleep from watch sensors | Hardcoded fake data | Wear OS Health Connect / SensorManager APIs |
| **Apple Health Sync** | Writes to Apple Health via HealthKit | None | HealthKit integration on iOS side |
| **Auto-Reconnect** | Auto-connects when devices in range | Manual scan + tap to connect | Background BLE reconnection logic |
| **Notification History** | Persistent history across sessions | In-memory only, lost on close | Local storage (SQLite/Hive) |
| **Media Controls** | Control iPhone music from watch | None | iOS MediaPlayer API + BLE commands |
| **Camera Remote** | Watch as iPhone shutter | None | iOS AVFoundation + BLE trigger |
| **Find Device** | Ring phone from watch, vice versa | None | BLE ping + audio playback |
| **End-to-End Encryption** | Encrypted BLE data | Plain JSON | AES/ChaCha20 encryption layer |
| **Background Service** | Persistent BLE in background | Basic background mode | iOS background tasks + watchdog |
| **File Manager** | Browse/transfer files between devices | None | BLE + WiFi direct for large files |

### How Notification Forwarding Works (Bridge Wear Sync)

```
iPhone receives notification (any app)
       ↓
iOS Notification Center captures it
       ↓
Bridge iOS app reads via UNUserNotificationCenter
       ↓
App checks: is this app allowed in user's per-app settings?
       ↓
If allowed → packages as JSON (title, body, app icon, timestamp)
       ↓
Sends over BLE notify characteristic → watch
       ↓
Watch app receives → displays as Wear OS notification
       ↓
User dismisses on watch → sends BLE message back → iOS dismisses too
```

**Key iOS APIs needed:**
- `UNUserNotificationCenter.current().getDeliveredNotifications()` — read active notifications
- `UNUserNotificationCenterDelegate` — intercept incoming notifications in real-time
- `Notification Service Extension` — capture notifications even when app is backgrounded

**Per-app control** is a list of bundle IDs stored locally on iPhone, synced to watch as config message.

### How Health Data Sync Works (Bridge Wear Sync)

```
Watch sensors collect: steps, heart rate, sleep
       ↓
Wear OS app reads via Health Connect / Sensor APIs
       ↓
Buffers data locally (every 1-15 min depending on type)
       ↓
Sends batch over BLE → iPhone
       ↓
iOS app receives → writes to Apple Health via HealthKit
```

**Key Android APIs needed:**
- `Health Connect` — read steps, heart rate, sleep (modern, recommended)
- `SensorManager` — direct sensor access for real-time HR
- `PackageManager` + `Intent` — launch Health Connect for permissions

**Key iOS APIs needed:**
- `HealthKit` (`HKHealthStore`) — write steps, HR, sleep to Apple Health
- `HKQuantityType` — define which data types to sync

### Sync Frequency (Bridge Wear Sync Defaults)

| Data Type | Interval |
|-----------|----------|
| Real-time HR (during exercise) | Every 1-2 minutes |
| Activity data (steps, calories) | Every 15 minutes |
| Comprehensive sync | Every hour |
| Background sync | Every 3 hours |
| Manual sync | On-demand |

---

## Roadmap: What We Need to Build

### Phase 1 — Notification Forwarding (Highest Value)
- [x] iOS: Add `UNUserNotificationCenterDelegate` to capture notifications
- [x] iOS: Add per-app enable/disable list (stored in UserDefaults)
- [x] iOS: Forward captured notifications over existing BLE channel
- [x] Watch: Display incoming notifications as Wear OS notifications via `flutter_local_notifications`
- [ ] Watch: Send dismiss action back to iOS
- [x] Both: Config UI for per-app notification control (NotificationSettingsScreen)
- [x] iOS: MethodChannel handlers for getAllowedApps, setAllowedApps, getInstalledApps, dismissNotification

### Phase 2 — Health Data from Watch Sensors
- [x] Watch: Integrate Health Connect to read real steps, HR, sleep
- [x] Watch: Send real health data over BLE to iPhone
- [ ] iOS: Add HealthKit to write received data to Apple Health
- [ ] Both: Config UI for sync frequency and data types

### Phase 3 — Auto-Reconnect & Persistence
- [x] iOS: Keep advertising in background (already done)
- [x] Watch: Store last connected device ID in SharedPreferences
- [x] Watch: Auto-connect on app start via `BluetoothDevice.fromId()`
- [x] Watch: Auto-reconnect on BLE disconnect with `autoConnect: true`
- [ ] Both: Add local storage (Hive/SQLite) for message history

### Phase 4 — Polish Features
- [ ] Media controls (iOS MediaPlayer → BLE → watch UI)
- [ ] Camera remote (iOS AVFoundation → BLE → watch shutter button)
- [ ] Find device (BLE ping + audio on both sides)
- [ ] Encryption layer on BLE data (AES/ChaCha20)

---

## What Stays the Same (Already Working)

- ✅ iPhone as BLE peripheral advertising service UUID
- ✅ Watch as BLE central scanning and connecting
- ✅ Bidirectional JSON message exchange
- ✅ Notify characteristic for iPhone→watch data
- ✅ Write characteristic for watch→iPhone data
- ✅ Background BLE modes configured
- ✅ Battery-optimized scanning (duty-cycled)
- ✅ Riverpod state management
- ✅ Responsive Wear OS UI
- ✅ GitHub Actions iOS build pipeline
