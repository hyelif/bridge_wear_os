import UIKit
import Flutter
import CoreBluetooth

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var bridgeBluetoothManager: AppBridgeBluetoothManager?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    bridgeBluetoothManager = AppBridgeBluetoothManager()
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}

class AppBridgeBluetoothManager: NSObject, CBPeripheralManagerDelegate {
  static let bridgeServiceUUID = CBUUID(string: "12345678-1234-5678-1234-56789012345a")
  static let bridgeCharacteristicUUID = CBUUID(string: "12345678-1234-56789012345b")
  static let notifyCharacteristicUUID = CBUUID(string: "12345678-1234-56789012345c")

  private var peripheralManager: CBPeripheralManager?
  private var bridgeCharacteristic: CBMutableCharacteristic?
  private var notifyCharacteristic: CBMutableCharacteristic?

  override init() {
    super.init()
    setupPeripheralManager()
  }

  private func setupPeripheralManager() {
    let queue = DispatchQueue(label: "com.bridge.bluetooth")
    peripheralManager = CBPeripheralManager(
      delegate: self,
      queue: queue,
      options: [CBPeripheralManagerOptionShowPowerAlertKey: true]
    )
  }

  func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
    switch peripheral.state {
    case .poweredOn:
      setupService()
      startAdvertising()
    case .poweredOff:
      peripheralManager?.stopAdvertising()
    case .resetting:
      print("Bluetooth is resetting")
    case .unauthorized:
      print("Bluetooth is unauthorized")
    case .unsupported:
      print("Bluetooth is not supported on this device")
    case .unknown:
      print("Bluetooth state is unknown")
    @unknown default:
      print("Unknown bluetooth state")
    }
  }

  private func setupService() {
    guard let peripheralManager = peripheralManager else { return }

    bridgeCharacteristic = CBMutableCharacteristic(
      type: AppBridgeBluetoothManager.bridgeCharacteristicUUID,
      properties: [.read, .write],
      value: nil,
      permissions: [.readable, .writeable]
    )

    notifyCharacteristic = CBMutableCharacteristic(
      type: AppBridgeBluetoothManager.notifyCharacteristicUUID,
      properties: [.notify],
      value: nil,
      permissions: []
    )

    let service = CBMutableService(
      type: AppBridgeBluetoothManager.bridgeServiceUUID,
      primary: true
    )

    if let bridgeChar = bridgeCharacteristic, let notifyChar = notifyCharacteristic {
      service.characteristics = [bridgeChar, notifyChar]
    }

    peripheralManager.add(service)
  }

  private func startAdvertising() {
    guard let peripheralManager = peripheralManager, peripheralManager.isAdvertising == false else {
      return
    }

    let advertisementData: [String: Any] = [
      CBAdvertisementDataLocalNameKey: "BridgeDevice",
      CBAdvertisementDataServiceUUIDsKey: [AppBridgeBluetoothManager.bridgeServiceUUID]
    ]

    peripheralManager.startAdvertising(advertisementData)
    print("Started advertising Bridge service")
  }

  func peripheralManager(
    _ peripheral: CBPeripheralManager,
    didAdd service: CBService,
    error: Error?
  ) {
    if let error = error {
      print("Error adding service: \(error.localizedDescription)")
      return
    }
    print("Service added successfully")
  }

  func peripheralManager(
    _ peripheral: CBPeripheralManager,
    didReceiveRead request: CBATTRequest
  ) {
    print("Received read request")
    request.value = "Bridge Device".data(using: .utf8)
    peripheral.respond(to: request, withResult: .success)
  }

  func peripheralManager(
    _ peripheral: CBPeripheralManager,
    didReceiveWrite requests: [CBATTRequest]
  ) {
    for request in requests {
      if let data = request.value {
        print("Received write: \(String(data: data, encoding: .utf8) ?? "unknown")")
      }
      peripheral.respond(to: request, withResult: .success)
    }
  }

  func peripheralManagerIsReady(toUpdateSubscribers peripheral: CBPeripheralManager) {
    print("Peripheral is ready to update subscribers")
  }

  func sendNotification(data: Data, for central: CBCentral? = nil) {
    guard let peripheralManager = peripheralManager,
          let characteristic = notifyCharacteristic else { return }

    if let central = central {
      peripheralManager.updateValue(data, for: characteristic, onSubscribedCentrals: [central])
    } else {
      peripheralManager.updateValue(data, for: characteristic, onSubscribedCentrals: nil)
    }
  }
}