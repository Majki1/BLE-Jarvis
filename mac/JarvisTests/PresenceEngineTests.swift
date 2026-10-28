import Testing
import Foundation
@testable import Jarvis

@MainActor
struct PresenceEngineTests {
    let t0 = Date(timeIntervalSince1970: 1_000_000)

    func makeEngine() -> (PresenceEngine, Recorded) {
        let recorded = Recorded()
        let engine = PresenceEngine(arriveThreshold: -60, holdThreshold: -80,
                                    graceInterval: 45)
        engine.onEvent = { recorded.events.append($0) }
        return (engine, recorded)
    }

    final class Recorded { var events: [PresenceEvent] = [] }

    @Test func startsUnknown() {
        let (engine, _) = makeEngine()
        #expect(engine.state == .unknown)
    }

    @Test func strongSightingArrives() {
        let (engine, rec) = makeEngine()
        engine.recordSighting(rssi: -60, at: t0)
        #expect(engine.state == .present)
        #expect(rec.events == [.arrived])
    }

    @Test func weakSightingIsIgnored() {
        let (engine, rec) = makeEngine()
        engine.recordSighting(rssi: -90, at: t0)
        #expect(engine.state == .unknown)
        #expect(rec.events.isEmpty)
    }

    // Hysteresis: a signal strong enough to *hold* presence is not strong
    // enough to *trigger* arrival — you must come close to arrive, but you
    // can drift around the room without departing.
    @Test func midStrengthSightingDoesNotTriggerArrival() {
        let (engine, rec) = makeEngine()
        engine.recordSighting(rssi: -70, at: t0)
        #expect(engine.state == .unknown)
        #expect(rec.events.isEmpty)
    }

    @Test func midStrengthSightingHoldsExistingPresence() {
        let (engine, rec) = makeEngine()
        engine.recordSighting(rssi: -50, at: t0)
        engine.recordSighting(rssi: -70, at: t0.addingTimeInterval(40))
        engine.tick(at: t0.addingTimeInterval(60))
        #expect(engine.state == .present)
        #expect(rec.events == [.arrived])
    }

    @Test func belowHoldSightingDoesNotHoldPresence() {
        let (engine, rec) = makeEngine()
        engine.recordSighting(rssi: -50, at: t0)
        engine.recordSighting(rssi: -85, at: t0.addingTimeInterval(40))
        engine.tick(at: t0.addingTimeInterval(50))
        #expect(engine.state == .away)
        #expect(rec.events == [.arrived, .departed])
    }

    @Test func repeatedSightingsEmitArrivedOnce() {
        let (engine, rec) = makeEngine()
        engine.recordSighting(rssi: -60, at: t0)
        engine.recordSighting(rssi: -55, at: t0.addingTimeInterval(5))
        #expect(rec.events == [.arrived])
    }

    @Test func absenceBeyondGraceDeparts() {
        let (engine, rec) = makeEngine()
        engine.recordSighting(rssi: -60, at: t0)
        engine.tick(at: t0.addingTimeInterval(46))
        #expect(engine.state == .away)
        #expect(rec.events == [.arrived, .departed])
    }

    @Test func briefAbsenceStaysPresent() {
        let (engine, rec) = makeEngine()
        engine.recordSighting(rssi: -60, at: t0)
        engine.tick(at: t0.addingTimeInterval(30))
        #expect(engine.state == .present)
        #expect(rec.events == [.arrived])
    }

    @Test func returnAfterDepartureArrivesAgain() {
        let (engine, rec) = makeEngine()
        engine.recordSighting(rssi: -60, at: t0)
        engine.tick(at: t0.addingTimeInterval(60))
        engine.recordSighting(rssi: -55, at: t0.addingTimeInterval(120))
        #expect(engine.state == .present)
        #expect(rec.events == [.arrived, .departed, .arrived])
    }

    @Test func weakSightingDoesNotRefreshPresence() {
        let (engine, rec) = makeEngine()
        engine.recordSighting(rssi: -60, at: t0)
        engine.recordSighting(rssi: -95, at: t0.addingTimeInterval(40))
        engine.tick(at: t0.addingTimeInterval(50))
        #expect(engine.state == .away)
        #expect(rec.events == [.arrived, .departed])
    }

    @Test func tickWhileUnknownDoesNothing() {
        let (engine, rec) = makeEngine()
        engine.tick(at: t0.addingTimeInterval(500))
        #expect(engine.state == .unknown)
        #expect(rec.events.isEmpty)
    }
}
