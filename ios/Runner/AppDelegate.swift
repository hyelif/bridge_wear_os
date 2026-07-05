import UIKit
import Flutter
import CoreBluetooth
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {
  var bridgeManager: BridgePeripheralManager?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // Setup notification delegate and request authorization
    UNUserNotificationCenter.current().delegate = self
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
      if let error = error {
        print("[NOTIF] Authorization error: \(error.localizedDescription)")
      } else {
        print("[NOTIF] Authorization granted: \(granted)")
        if granted {
          DispatchQueue.main.async {
            application.registerForRemoteNotifications()
          }
        }
      }
    }

    // Defer BLE setup to avoid crash on iOS 13+ with SceneDelegate
    // The window may not be ready yet during didFinishLaunching
    DispatchQueue.main.async { [weak self] in
      self?.setupBluetooth()
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func setupBluetooth() {
    guard let controller = window?.rootViewController as? FlutterViewController else {
      print("[BLE] FlutterViewController not ready yet, will retry...")
      // Retry after a short delay
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
        self?.setupBluetooth()
      }
      return
    }

    bridgeManager = BridgePeripheralManager()

    let channel = FlutterMethodChannel(
      name: "com.bridge.ble",
      binaryMessenger: controller.binaryMessenger
    )

    bridgeManager?.flutterChannel = channel

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

      case "getAllowedApps":
        let allowed = UserDefaults.standard.stringArray(forKey: self.allowedAppsKey) ?? []
        result(allowed)

      case "setAllowedApps":
        guard let args = call.arguments as? [String: Any],
              let apps = args["apps"] as? [String] else {
          result(FlutterError(code: "INVALID_ARGS", message: "Expected {apps: [String]}", details: nil))
          return
        }
        UserDefaults.standard.set(apps, forKey: self.allowedAppsKey)
        result(true)

      case "getInstalledApps":
        let commonApps: [[String: String]] = [
          ["bundleId": "com.apple.MobileSMS", "name": "Messages"],
          ["bundleId": "com.apple.mobilemail", "name": "Mail"],
          ["bundleId": "com.apple.mobilephone", "name": "Phone"],
          ["bundleId": "com.apple.mobilesafari", "name": "Safari"],
          ["bundleId": "com.apple.mobilecal", "name": "Calendar"],
          ["bundleId": "com.apple.reminders", "name": "Reminders"],
          ["bundleId": "com.apple.mobilenotes", "name": "Notes"],
          ["bundleId": "com.apple.Preferences", "name": "Settings"],
          ["bundleId": "com.apple.camera", "name": "Camera"],
          ["bundleId": "com.apple.photos", "name": "Photos"],
          ["bundleId": "com.apple.mobiletimer", "name": "Clock"],
          ["bundleId": "com.apple.weather", "name": "Weather"],
          ["bundleId": "com.apple.mobilestocks", "name": "Stocks"],
          ["bundleId": "com.apple.mobilemaps", "name": "Maps"],
          ["bundleId": "com.apple.mobilemusic", "name": "Music"],
          ["bundleId": "com.apple.Podcasts", "name": "Podcasts"],
          ["bundleId": "com.apple.news", "name": "News"],
          ["bundleId": "com.apple.Health", "name": "Health"],
          ["bundleId": "com.apple.mobileme", "name": "Find My"],
          ["bundleId": "com.apple.mobilehome", "name": "Home"],
        ]
        result(commonApps)

      case "dismissNotification":
        guard let args = call.arguments as? [String: Any],
              let bundleId = args["appBundleId"] as? String else {
          result(FlutterError(code: "INVALID_ARGS", message: "Expected {appBundleId: String}", details: nil))
          return
        }
        UNUserNotificationCenter.current().getDeliveredNotifications { notifications in
          let identifiers = notifications
            .filter { notif in
              let source = notif.request.content.userInfo["sourceApp"] as? String
                ?? notif.request.content.userInfo["appBundleId"] as? String
                ?? notif.request.content.categoryIdentifier
              return source == bundleId
            }
            .map { $0.request.identifier }
          UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: identifiers)
        }
        result(true)

      default:
        result(FlutterMethodNotImplemented)
      }
    }

    print("[BLE] Bridge initialized successfully")
  }

  // MARK: - UNUserNotificationCenterDelegate

  override func userNotificationCenter(_ center: UNUserNotificationCenter,
                              willPresent notification: UNNotification,
                              withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
    let content = notification.request.content
    print("[NOTIF] Received: \(content.title) from \(content.userInfo)")

    // Forward to watch via BLE
    forwardNotificationToWatch(content)

    // Show notification on iPhone too
    completionHandler([.banner, .sound])
  }

  override func userNotificationCenter(_ center: UNUserNotificationCenter,
                              didReceive response: UNNotificationResponse,
                              withCompletionHandler completionHandler: @escaping () -> Void) {
    completionHandler()
  }

  // MARK: - Notification Forwarding

  private let allowedAppsKey = "allowed_notification_apps"

  private func forwardNotificationToWatch(_ content: UNNotificationContent) {
    // Extract bundle ID from notification request — use categoryIdentifier as fallback
    let bundleId = content.userInfo["sourceApp"] as? String
      ?? content.userInfo["appBundleId"] as? String
      ?? content.categoryIdentifier

    let appName = content.userInfo["appName"] as? String ?? bundleId

    let payload: [String: Any] = [
      "title": content.title,
      "body": content.body,
      "appName": appName,
      "appBundleId": bundleId,
      "timestamp": ISO8601DateFormatter().string(from: Date()),
    ]

    // Check per-app allowlist before forwarding
    guard isAppAllowed(bundleId) else {
      print("[NOTIF] App not in allowlist, skipping: \(bundleId)")
      return
    }

    bridgeManager?.sendToWatch([
      "type": "notification",
      "payload": payload
    ])
  }

  private func isAppAllowed(_ bundleId: String) -> Bool {
    let allowed = UserDefaults.standard.stringArray(forKey: allowedAppsKey) ?? []
    // If allowlist is empty, allow all
    return allowed.isEmpty || allowed.contains(bundleId)
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

  // Advertising power management
  private enum AdvertiseMode {
    case lowPower    // Minimal advertisement data, no local name
    case lowLatency  // Full advertisement data with local name
  }

  private var peripheralManager: CBPeripheralManager?
  private var writeCharacteristic: CBMutableCharacteristic?
  private var notifyCharacteristic: CBMutableCharacteristic?
  fileprivate var subscribedCentral: CBCentral?
  private var isServiceReady = false
  private var advertiseMode: AdvertiseMode = .lowPower

  // Advertising timeout: stop after 60s if no central connects
  private var advertisingTimeoutTimer: Timer?
  private static let advertisingTimeout: TimeInterval = 60

  // Retry: restart advertising after 30s pause if no connection
  private var retryTimer: Timer?
  private static let retryPause: TimeInterval = 30

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
      print("[BLE] Bluetooth off — enable Bluetooth to use Bridge")
      cancelAllTimers()
    case .unauthorized:
      let msg: String
      if #available(iOS 13.0, *) {
        switch CBManager.authorization {
        case .restricted:
          msg = "Bluetooth restricted (parental controls)"
        case .denied:
          msg = "Bluetooth denied — enable in Settings > Privacy > Bluetooth"
        case .allowedAlways:
          msg = "Bluetooth authorized"
        @unknown default:
          msg = "Unknown authorization state"
        }
      } else {
        msg = "Unauthorized — check Info.plist"
      }
      print("[BLE] \(msg)")
    case .unsupported:
      print("[BLE] Bluetooth LE not supported on this device")
    case .resetting:
      print("[BLE] Bluetooth resetting — will retry")
    @unknown default:
      print("[BLE] Unknown state: \(peripheral.state.rawValue)")
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
    startAdvertising(mode: .lowPower)
  }

  private func startAdvertising(mode: AdvertiseMode) {
    guard let manager = peripheralManager, !manager.isAdvertising else {
      print("[BLE] Already advertising or manager nil")
      return
    }

    advertiseMode = mode

    var data: [String: Any] = [
      CBAdvertisementDataServiceUUIDsKey: [BridgePeripheralManager.serviceUUID]
    ]

    switch mode {
    case .lowPower:
      // LOW_POWER: advertise only service UUIDs — no local name.
      // Smaller advertisement packets use less radio time and save battery.
      print("[BLE] Advertising in LOW_POWER mode (service UUIDs only)")
    case .lowLatency:
      // LOW_LATENCY: include local name for faster discovery by the watch.
      data[CBAdvertisementDataLocalNameKey] = "Bridge-iPhone"
      print("[BLE] Advertising in LOW_LATENCY mode (with local name)")
    }

    manager.startAdvertising(data)
  }

  func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
    if let error = error {
      print("[BLE] Advertising error: \(error)")
      return
    }
    print("[BLE] Advertising started!")

    // Start the 60-second advertising timeout.
    // If no central subscribes before this fires, we stop advertising
    // and schedule a retry after 30s.
    DispatchQueue.main.async { [weak self] in
      guard let self = self else { return }
      self.advertisingTimeoutTimer?.invalidate()
      self.advertisingTimeoutTimer = Timer.scheduledTimer(
        timeInterval: BridgePeripheralManager.advertisingTimeout,
        repeats: false
      ) { [weak self] _ in
        self?.advertisingTimedOut()
      }
    }
  }

  private func advertisingTimedOut() {
    print("[BLE] Advertising timed out (60s) — no central connected")

    guard let manager = peripheralManager else { return }

    // Stop advertising
    if manager.isAdvertising {
      manager.stopAdvertising()
      print("[BLE] Advertising stopped due to timeout")
    }

    // Schedule retry after 30s pause
    DispatchQueue.main.async { [weak self] in
      guard let self = self else { return }
      self.retryTimer?.invalidate()
      self.retryTimer = Timer.scheduledTimer(
        timeInterval: BridgePeripheralManager.retryPause,
        repeats: false
      ) { [weak self] _ in
        self?.retryAdvertising()
      }
    }
    print("[BLE] Retry scheduled in \(BridgePeripheralManager.retryPause)s")
  }

  private func retryAdvertising() {
    guard isServiceReady else {
      print("[BLE] Cannot retry: service not ready")
      return
    }
    print("[BLE] Retrying advertising in LOW_POWER mode")
    startAdvertising(mode: .lowPower)
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
      guard let data = request.value else {
        print("[BLE] Write request with no data")
        peripheral.respond(to: request, withResult: .invalidAttributeValueLength)
        continue
      }

      print("[BLE] Received \(data.count) bytes on \(request.characteristic.uuid)")

      // Forward the raw data to Flutter via the method channel
      if let channel = flutterChannel {
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
          channel.invokeMethod("onMessage", arguments: json)
        } else if let text = String(data: data, encoding: .utf8) {
          channel.invokeMethod("onMessage", arguments: ["text": text])
        } else {
          print("[BLE] Unrecognized data format")
        }
      }

      peripheral.respond(to: request, withResult: .success)
    }
  }

  // Handle subscription to notifications
  func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
    print("[BLE] Central subscribed to \(characteristic.uuid)")
    subscribedCentral = central

    // Cancel the advertising timeout — a central is connected
    cancelAdvertisingTimeout()

    // Switch to LOW_LATENCY advertising for faster reconnection
    // if the central disconnects briefly.
    if advertiseMode == .lowPower {
      print("[BLE] Switching to LOW_LATENCY advertising mode")
      if peripheralManager?.isAdvertising == true {
        peripheralManager?.stopAdvertising()
      }
      startAdvertising(mode: .lowLatency)
    }
  }

  // Handle unsubscription
  func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFrom characteristic: CBCharacteristic) {
    print("[BLE] Central unsubscribed from \(characteristic.uuid)")
    subscribedCentral = nil

    // Switch back to LOW_POWER advertising to save battery
    if advertiseMode == .lowLatency {
      print("[BLE] Switching back to LOW_POWER advertising mode")
      if peripheralManager?.isAdvertising == true {
        peripheralManager?.stopAdvertising()
      }
      startAdvertising(mode: .lowPower)
    }

    // Restart the advertising timeout since no central is connected
    cancelAdvertisingTimeout()
    DispatchQueue.main.async { [weak self] in
      guard let self = self else { return }
      self.advertisingTimeoutTimer = Timer.scheduledTimer(
        timeInterval: BridgePeripheralManager.advertisingTimeout,
        target: self,
        selector: #selector(self.advertisingTimedOut),
        userInfo: nil,
        repeats: false
      )
    }
  }

  // Send notification to watch
  func sendToWatch(_ data: [String: Any]) {
    guard let manager = peripheralManager,
          let characteristic = notifyCharacteristic,
          let jsonData = try? JSONSerialization.data(withJSONObject: data) else {
      print("[BLE] Cannot send: missing components")
      return
    }

    let centrals: [CBCentral]? = subscribedCentral.map { [$0] }
    let success = manager.updateValue(
      jsonData,
      for: characteristic,
      onSubscribedCentrals: centrals
    )

    if !success {
      print("[BLE] Send failed — characteristic update queue full")
    } else {
      print("[BLE] Sent \(jsonData.count) bytes to watch")
    }
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

  // MARK: - Timer Management

  private func cancelAdvertisingTimeout() {
    DispatchQueue.main.async { [weak self] in
      self?.advertisingTimeoutTimer?.invalidate()
      self?.advertisingTimeoutTimer = nil
    }
  }

  private func cancelRetryTimer() {
    DispatchQueue.main.async { [weak self] in
      self?.retryTimer?.invalidate()
      self?.retryTimer = nil
    }
  }

  private func cancelAllTimers() {
    cancelAdvertisingTimeout()
    cancelRetryTimer()
  }

  deinit {
    cancelAllTimers()
  }
}
