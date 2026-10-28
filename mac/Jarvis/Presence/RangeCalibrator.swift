import Foundation
import Observation

// Boundary calibration: user stands where "away" should begin, we sample the
// phone's RSSI there, and the hold threshold is set 5 dB stronger than the
// boundary median — signals at or beyond the boundary stop holding presence.
@MainActor @Observable
final class RangeCalibrator {
    static let minimumSamples = 5
    static let margin = 5

    private(set) var samples: [Int] = []

    var sampleCount: Int { samples.count }

    var recommendedHoldThreshold: Int? {
        guard samples.count >= Self.minimumSamples else { return nil }
        let sorted = samples.sorted()
        return sorted[sorted.count / 2] + Self.margin
    }

    func addSample(_ rssi: Int) {
        samples.append(rssi)
    }

    func reset() {
        samples = []
    }
}
