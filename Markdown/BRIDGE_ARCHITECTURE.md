# Bridge Architecture

## Goal

Build a Wear OS to iOS BLE bridge. First milestone: reliable ping/pong between watch and iPhone.

Recommended first role model:
- Wear OS: GATT server/peripheral. Advertises Bridge service.
- iOS: GATT central/client. Scans, connects, writes messages, subscribes to notify characteristic.

This avoids making iOS background advertising first dependency.

## Current Architecture

```text
Flutter UI
  DeviceDiscoveryScreen
  BridgeScreen

Bridge protocol
  BridgeManager
  BridgeMessage

Flutter BLE client
  BluetoothService
  flutter_blue_plus

Native prototypes
  Android BridgeBluetoothService.kt
  iOS BridgeBluetoothManager.swift
```

Important: native Android/iOS BLE server/peripheral code is not fully wired to Flutter yet. Incoming native writes are not delivered into `BridgeManager`.

## BLE UUIDs

```text
Service UUID:          12345678-1234-5678-1234-56789012345a
Write Characteristic:  12345678-1234-5678-1234-56789012345b
Notify Characteristic: 12345678-1234-5678-1234-56789012345c
```

## Message Format

Current prototype sends JSON UTF-8:

```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "type": "ping",
  "payload": {
    "timestamp": "2026-07-03T08:30:45.123Z"
  },
  "timestamp": "2026-07-03T08:30:45.123Z",
  "requiresAck": true
}
```

Current message types:
- `notification`
- `health`
- `mediaControl`
- `contactSync`
- `cameraControl`
- `deviceInfo`
- `ping`
- `acknowledgment`

Acknowledgment payload:

```json
{
  "messageId": "original-message-id"
}
```

## Required Transport Upgrade

BLE is not a socket. Single JSON payloads can exceed negotiated MTU.

Need framing layer before feature work:
- `messageId`
- `chunkIndex`
- `chunkCount`
- `payloadLength`
- `checksum`
- retry count
- duplicate detection

`BridgeManager` should only parse complete reassembled JSON.

## Platform Reality

Supported:
- App-owned BLE messages.
- App-owned notification/demo messages.
- User-approved health data through real platform APIs.
- Media commands only after native media API integration.

Not supported by public iOS APIs:
- Reading arbitrary iPhone app notifications and mirroring them to Wear OS.
- Always-on unrestricted iOS background BLE scan/advertise.

## Next Architecture Work

1. Add platform channels.
   - Android `MethodChannel`: `startServer`, `stopServer`, `sendNotify`.
   - Android `EventChannel`: incoming writes, connection state.
   - iOS `MethodChannel`: `startPeripheral`, `stopPeripheral`, `sendNotify`.
   - iOS `EventChannel`: incoming writes, subscription state.

2. Add ping/pong integration test on physical devices.

3. Add chunked transport.

4. Add pairing and session encryption.

5. Add reconnect/background behavior.
