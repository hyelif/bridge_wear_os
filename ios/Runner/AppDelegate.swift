import UIKit
import Flutter
import CoreBluetooth

@main
@objc class AppDelegate: FlutterAppDelegate {
  var bridgeManager: BridgePeripheralManager?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Initialize BLE peripheral manager
    bridgeManager = BridgePeripheralManager()

    // Set up Flutter MethodChannel
    let controller = window?.rootViewController as! FlutterViewController
    let channel = FlutterMethodChannel(
      name: "com.bridge.ble",
      binaryMessenger: controller.binaryMessenger
    )

    // Give the bridge manager a reference to the channel so it can send messages to Flutter
    bridgeManager?.flutterChannel = channel

    // Handle method calls from Flutter
    channel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
      guard let self = self else { return }

      switch call.method {
      case "sendNotification":
        guard let args = call.arguments as? [String: Any],
              let dataString = args["data"] as? String,
              let data = dataString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
          result(FlutterError(code: "INVALID_ARGS", message: "Expected {data: string} with JSON payload", details: nil))
          return
        }
        self.bridgeManager?.sendToWatch(json)
        result(true)

      case "getConnectionState":
        let isConnected = self.bridgeManager?.subscribedCentral != nil
        result(isConnected)

      default:
        result(FlutterMethodNotImplemented)
      }
    }

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}

/// BLE Peripheral Manager for iOS - advertises to Wear OS watch
class BridgePeripheralManager: NSObject, CBPeripheralManagerDelegate {
  // Service UUID - MUST match Wear OS app
  static let serviceUUID = CBUUID(string: "12345678-1234-5678-1234-56789012345a")
  // Write characteristic
  static let writeCharUUID = CBUUID(string: "12345678-1234-5678-1234-56789012345b")
  // Notify characteristic
  static let notifyCharUUID = CBUUID(string: "12345678-1234-5678-1234-56789012345c")

  private var peripheralManager: CBPeripheralManager?
  private var writeCharacteristic: CBMutableCharacteristic?
  private var notifyCharacteristic: CBMutableCharacteristic?
  fileprivate var subscribedCentral: CBCentral?
  private var isServiceReady = false

  /// Reference to the Flutter method channel for sending messages to Flutter
  var flutterChannel: FlutterMethodChannel?

  override init() {
    super.init()
    setupPeripheral()
  }

  private func setupPeripheral() {
    let queue = DispatchQueue(label: "com.bridge.peripheral")
    peripheralManager = CBPeripheralManager(delegate: self, queue: queue)
    print("[BLE] Peripheral manager created")
  }

  // MARK: - CBPeripheralManagerDelegate

  func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
    print("[BLE] State: \(peripheral.state.rawValue)")

    switch peripheral.state {
    case .poweredOn:
      print("[BLE] Powered on - setting up service")
      setupService()
    case .poweredOff:
      print("[BLE] Bluetooth off")
    case .unauthorized:
      print("[BLE] Unauthorized - check Info.plist")
    case .unsupported:
      print("[BLE] Unsupported")
    default:
      break
    }
  }

  private func setupService() {
    guard let manager = peripheralManager else { return }

    // Create write characteristic
    writeCharacteristic = CBMutableCharacteristic(
      type: BridgePeripheralManager.writeCharUUID,
      properties: [.write, .writeWithoutResponse, .read],
      value: nil,
      permissions: [.readable, .writeable]
    )

    // Create notify characteristic with descriptor
    notifyCharacteristic = CBMutableCharacteristic(
      type: BridgePeripheralManager.notifyCharUUID,
      properties: [.notify, .read],
      value: nil,
      permissions: [.readable]
    )

    // Add CCCD descriptor for notifications
    let cccd = CBMutableDescriptor(
      type: CBUUID(string: "2902"),
      value: NSNumber(value: 1)
    )
    notifyCharacteristic?.descriptors = [cccd]

    // Create service
    let service = CBMutableService(
      type: BridgePeripheralManager.serviceUUID,
      primary: true
    )

    if let writeChar = writeCharacteristic, let notifyChar = notifyCharacteristic {
      service.characteristics = [writeChar, notifyChar]
    }

    manager.add(service)
    print("[BLE] Service added")
  }

  func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
    if let error = error {
      print("[BLE] Error adding service: \(error)")
      return
    }
    print("[BLE] Service added successfully!")
    isServiceReady = true
    startAdvertising()
  }

  private func startAdvertising() {
    guard let manager = peripheralManager, !manager.isAdvertising else {
      print("[BLE] Already advertising or manager nil")
      return
    }

    let data: [String: Any] = [
      CBAdvertisementDataLocalNameKey: "Bridge-iPhone",
      CBAdvertisementDataServiceUUIDsKey: [BridgePeripheralManager.serviceUUID]
    ]

    manager.startAdvertising(data)
    print("[BLE] Advertising as 'Bridge-iPhone'")
  }

  func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
    if let error = error {
      print("[BLE] Advertising error: \(error)")
    } else {
      print("[BLE] Advertising started!")
    }
  }

  // Handle read requests from watch
  func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
    print("[BLE] Read request: \(request.characteristic.uuid)")

    // Return simple response
    let response = "Bridge-iPhone".data(using: .utf8)
    request.value = response
    peripheral.respond(to: request, withResult: .success)
  }

  // Handle write requests from watch
  func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
    for request in requests {
      print("[BLE] Write request: \(request.characteristic.uuid)")

      if let data = request.value {
        print("[BLE] Received \(data.count) bytes")
        if let text = String(data: data, encoding: .utf8) {
          print("[BLE] Data: \(text)")
        }

        // Forward the raw data to Flutter via the method channel
        if let channel = flutterChannel {
          // Try to parse as JSON for structured forwarding
          if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            channel.invokeMethod("onMessage", arguments: json)
          } else if let text = String(data: data, encoding: .utf8) {
            // Fall back to plain string
            channel.invokeMethod("onMessage", arguments: ["text": text])
          }
        }
      }

      peripheral.respond(to: request, withResult: .success)
    }
  }

  // Handle subscription to notifications
  func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
    print("[BLE] Central subscribed to \(characteristic.uuid)")
    subscribedCentral = central
  }

  // Handle unsubscription
  func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFrom characteristic: CBCharacteristic) {
    print("[BLE] Central unsubscribed from \(characteristic.uuid)")
    subscribedCentral = nil
  }

  // Send notification to watch
  func sendToWatch(_ data: [String: Any]) {
    guard let manager = peripheralManager,
          let characteristic = notifyCharacteristic,
          let jsonData = try? JSONSerialization.data(withJSONObject: data) else {
      print("[BLE] Cannot send: missing components")
      return
    }

    let success = manager.updateValue(
      jsonData,
      for: characteristic,
      onSubscribedCentrals: subscribedCentral != nil ? [subscribedCentral!] : nil
    )

    print("[BLE] Send result: \(success)")
  }

  // Send simple message
  func sendMessage(type: String, payload: [String: Any]) {
    let message: [String: Any] = [
      "type": type,
      "payload": payload,
      "timestamp": ISO8601DateFormatter().string(from: Date())
    ]
    sendToWatch(message)
  }
}
