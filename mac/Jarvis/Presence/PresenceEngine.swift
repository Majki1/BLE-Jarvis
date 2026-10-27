import Foundation
import Observation

enum PresenceEvent: Equatable {
    case arrived
    case departed
}

// Scanning-based presence: BLE sightings above an RSSI threshold mean the
// phone is near; absence of qualifying sightings for `graceInterval` means
// departure. Time is passed in explicitly so the state machine is fully
// deterministic under test; production feeds it from the scanner + a ticker.
@MainActor @Observable
final class PresenceEngine {
    enum State: Equatable {
        case unknown
        case present
        case away
    }

    private(set) var state: State = .unknown
    var onEvent: ((PresenceEvent) -> Void)?

    private let rssiThreshold: Int
    private let graceInterval: TimeInterval
    private var lastQualifyingSighting: Date?

    init(rssiThreshold: Int = -75, graceInterval: TimeInterval = 45) {
        self.rssiThreshold = rssiThreshold
        self.graceInterval = graceInterval
    }

    func recordSighting(rssi: Int, at date: Date) {
        guard rssi >= rssiThreshold else { return }
        lastQualifyingSighting = date
        if state != .present {
            state = .present
            onEvent?(.arrived)
        }
    }

    func tick(at date: Date) {
        guard state == .present, let lastSeen = lastQualifyingSighting else { return }
        if date.timeIntervalSince(lastSeen) > graceInterval {
            state = .away
            onEvent?(.departed)
        }
    }
}
