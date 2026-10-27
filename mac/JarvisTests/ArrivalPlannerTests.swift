import Testing
import Foundation
@testable import Jarvis

@MainActor
struct ArrivalPlannerTests {
    func makePlanner(hour: Int, minute: Int = 0, day: Int = 15,
                     defaults: UserDefaults? = nil) -> ArrivalPlanner {
        let defaults = defaults ?? UserDefaults(suiteName: "planner-\(UUID().uuidString)")!
        var components = DateComponents()
        components.year = 2026; components.month = 10; components.day = day
        components.hour = hour; components.minute = minute
        let date = Calendar.current.date(from: components)!
        return ArrivalPlanner(defaults: defaults, wakeHour: 5, now: { date })
    }

    @Test func firstArrivalAfterWakeHourIsMorningBriefing() {
        let planner = makePlanner(hour: 8)
        #expect(planner.momentForArrival() == .morningBriefing)
    }

    @Test func secondArrivalSameDayIsRecap() {
        let defaults = UserDefaults(suiteName: "planner-\(UUID().uuidString)")!
        let first = makePlanner(hour: 8, defaults: defaults)
        _ = first.momentForArrival()
        let second = makePlanner(hour: 13, defaults: defaults)
        #expect(second.momentForArrival() == .returnRecap)
    }

    @Test func arrivalBeforeWakeHourIsRecapNotMorning() {
        let planner = makePlanner(hour: 3)
        #expect(planner.momentForArrival() == .returnRecap)
    }

    @Test func morningMomentIsPreservedForLaterThatDay() {
        let defaults = UserDefaults(suiteName: "planner-\(UUID().uuidString)")!
        let night = makePlanner(hour: 3, defaults: defaults)
        _ = night.momentForArrival()
        let morning = makePlanner(hour: 9, defaults: defaults)
        #expect(morning.momentForArrival() == .morningBriefing)
    }

    @Test func nextDayGetsMorningAgain() {
        let defaults = UserDefaults(suiteName: "planner-\(UUID().uuidString)")!
        _ = makePlanner(hour: 8, day: 15, defaults: defaults).momentForArrival()
        let tomorrow = makePlanner(hour: 8, day: 16, defaults: defaults)
        #expect(tomorrow.momentForArrival() == .morningBriefing)
    }
}
