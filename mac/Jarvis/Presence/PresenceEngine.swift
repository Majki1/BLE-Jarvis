import Foundation
import Observation
import os

let presenceLog = Logger(subsystem: "com.msoft.blejarvis", category: "presence")

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

    // Hysteresis: arrival needs a desk-strength signal; once present, a much
    // weaker signal keeps you present. Prevents both far-away greetings and
    // twitchy departures when you lean back.
    private var arriveThreshold: Int
    private var holdThreshold: Int
    private let graceInterval: TimeInterval
    private var lastQualifyingSighting: Date?

    // Raw feed for calibration UIs; called for every sighting pre-threshold.
    var onRawSighting: ((Int) -> Void)?

    init(arriveThreshold: Int = -60, holdThreshold: Int = -80,
         graceInterval: TimeInterval = 45) {
        self.arriveThreshold = arriveThreshold
        self.holdThreshold = holdThreshold
        self.graceInterval = graceInterval
    }

    func updateThresholds(arrive: Int? = nil, hold: Int? = nil) {
        if let arrive { arriveThreshold = arrive }
        if let hold { holdThreshold = hold }
        presenceLog.info("thresholds retuned: arrive=\(self.arriveThreshold) hold=\(self.holdThreshold)")
    }

    func recordSighting(rssi: Int, at date: Date) {
        onRawSighting?(rssi)
        presenceLog.debug("sighting rssi=\(rssi) arrive>=\(self.arriveThreshold) hold>=\(self.holdThreshold)")
        if state == .present {
            if rssi >= holdThreshold { lastQualifyingSighting = date }
            return
        }
        guard rssi >= arriveThreshold else { return }
        lastQualifyingSighting = date
        presenceLog.info("ARRIVED (rssi \(rssi))")
        state = .present
        onEvent?(.arrived)
    }

    func tick(at date: Date) {
        guard state == .present, let lastSeen = lastQualifyingSighting else { return }
        let silence = date.timeIntervalSince(lastSeen)
        presenceLog.debug("tick: \(Int(silence))s since last qualifying sighting")
        if silence > graceInterval {
            presenceLog.info("DEPARTED after \(Int(silence))s of silence")
            state = .away
            onEvent?(.departed)
        }
    }
}
