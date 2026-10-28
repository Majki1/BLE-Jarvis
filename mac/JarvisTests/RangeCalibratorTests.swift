import Testing
import Foundation
@testable import Jarvis

@MainActor
struct RangeCalibratorTests {
    @Test func recommendsHoldStrongerThanBoundaryMedian() {
        let calibrator = RangeCalibrator()
        for rssi in [-78, -76, -77, -79, -75, -77, -78] {
            calibrator.addSample(rssi)
        }
        // median -77 → anything at or weaker than the boundary must not hold
        #expect(calibrator.recommendedHoldThreshold == -72)
    }

    @Test func tooFewSamplesGiveNoRecommendation() {
        let calibrator = RangeCalibrator()
        for rssi in [-70, -71] { calibrator.addSample(rssi) }
        #expect(calibrator.recommendedHoldThreshold == nil)
    }

    @Test func resetClearsSamples() {
        let calibrator = RangeCalibrator()
        for rssi in [-70, -71, -72, -70, -71] { calibrator.addSample(rssi) }
        calibrator.reset()
        #expect(calibrator.sampleCount == 0)
        #expect(calibrator.recommendedHoldThreshold == nil)
    }

    @Test func engineThresholdsCanBeRetuned() {
        let engine = PresenceEngine(arriveThreshold: -60, holdThreshold: -80,
                                    graceInterval: 45)
        let t0 = Date(timeIntervalSince1970: 1_000_000)
        engine.recordSighting(rssi: -50, at: t0)
        engine.updateThresholds(hold: -70)
        // -75 is weaker than the new hold threshold: must no longer refresh
        engine.recordSighting(rssi: -75, at: t0.addingTimeInterval(40))
        engine.tick(at: t0.addingTimeInterval(50))
        #expect(engine.state == .away)
    }
}
