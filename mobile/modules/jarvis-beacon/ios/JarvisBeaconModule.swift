import ExpoModulesCore
import CoreBluetooth

// Advertises the Jarvis service UUID so the Mac's scanner can sense presence.
// Must stay in sync with mac/Jarvis/Presence/PresenceScanner.swift.
let jarvisServiceUUID = CBUUID(string: "7E1C6B4A-9B3F-4C7D-8A2E-D4F5B6C7A8E9")

public class JarvisBeaconModule: Module {
  private var beacon: BeaconManager?

  public func definition() -> ModuleDefinition {
    Name("JarvisBeacon")

    Events("onStateChange")

    AsyncFunction("startAdvertising") {
      if self.beacon == nil {
        self.beacon = BeaconManager { [weak self] state in
          self?.sendEvent("onStateChange", state)
        }
      }
      self.beacon?.start()
    }

    AsyncFunction("stopAdvertising") {
      self.beacon?.stop()
    }

    Function("getState") { () -> [String: Any] in
      self.beacon?.statePayload ?? ["advertising": false, "bluetooth": "unknown"]
    }
  }
}

private final class BeaconManager: NSObject, CBPeripheralManagerDelegate {
  private var manager: CBPeripheralManager?
  private var wantsAdvertising = false
  private let onState: ([String: Any]) -> Void

  init(onState: @escaping ([String: Any]) -> Void) {
    self.onState = onState
    super.init()
  }

  var statePayload: [String: Any] {
    [
      "advertising": manager?.isAdvertising ?? false,
      "bluetooth": stateName(manager?.state ?? .unknown),
    ]
  }

  func start() {
    wantsAdvertising = true
    if manager == nil {
      manager = CBPeripheralManager(delegate: self, queue: .main)
    } else {
      beginAdvertisingIfReady()
    }
  }

  func stop() {
    wantsAdvertising = false
    manager?.stopAdvertising()
    emit()
  }

  private func beginAdvertisingIfReady() {
    guard wantsAdvertising, let manager, manager.state == .poweredOn,
          !manager.isAdvertising else {
      emit()
      return
    }
    manager.startAdvertising([
      CBAdvertisementDataServiceUUIDsKey: [jarvisServiceUUID],
      CBAdvertisementDataLocalNameKey: "JarvisBeacon",
    ])
  }

  func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
    beginAdvertisingIfReady()
  }

  func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
    emit(error: error?.localizedDescription)
  }

  private func emit(error: String? = nil) {
    var payload = statePayload
    if let error { payload["error"] = error }
    onState(payload)
  }

  private func stateName(_ state: CBManagerState) -> String {
    switch state {
    case .poweredOn: "poweredOn"
    case .poweredOff: "poweredOff"
    case .unauthorized: "unauthorized"
    case .unsupported: "unsupported"
    case .resetting: "resetting"
    default: "unknown"
    }
  }
}
