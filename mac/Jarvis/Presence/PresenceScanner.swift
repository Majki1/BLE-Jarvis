import Foundation
import CoreBluetooth

enum JarvisBLE {
    // Must match the mobile app's advertised service UUID.
    static let serviceUUID = CBUUID(string: "7E1C6B4A-9B3F-4C7D-8A2E-D4F5B6C7A8E9")
}

// Thin CoreBluetooth shell: scans for the Jarvis service UUID and feeds
// sightings into the PresenceEngine; a ticker drives departure detection.
// Deliberately no logic here — the engine owns all decisions and is the
// unit-tested part.
@MainActor
final class PresenceScanner: NSObject {
    private let engine: PresenceEngine
    private var central: CBCentralManager?
    private var ticker: Task<Void, Never>?

    init(engine: PresenceEngine) {
        self.engine = engine
        super.init()
    }

    func start() {
        central = CBCentralManager(delegate: self, queue: .main)
        ticker = Task { [engine] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(5))
                engine.tick(at: Date())
            }
        }
    }

    func stop() {
        ticker?.cancel()
        ticker = nil
        central?.stopScan()
        central = nil
    }

    private func beginScan() {
        central?.scanForPeripherals(
            withServices: [JarvisBLE.serviceUUID],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])
    }
}

extension PresenceScanner: CBCentralManagerDelegate {
    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        let state = central.state
        Task { @MainActor in
            presenceLog.info("bluetooth state=\(state.rawValue) (5=poweredOn)")
            if state == .poweredOn {
                presenceLog.info("scanning for \(JarvisBLE.serviceUUID)")
                self.beginScan()
            }
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager,
                                    didDiscover peripheral: CBPeripheral,
                                    advertisementData: [String: Any],
                                    rssi RSSI: NSNumber) {
        let rssi = RSSI.intValue
        // 127 is CoreBluetooth's "RSSI unavailable" sentinel.
        guard rssi != 127 else { return }
        Task { @MainActor in
            self.engine.recordSighting(rssi: rssi, at: Date())
        }
    }
}
