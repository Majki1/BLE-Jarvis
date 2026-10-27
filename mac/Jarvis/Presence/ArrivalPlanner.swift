import Foundation

// Decides what an arrival means: the first arrival of the day inside waking
// hours gets the full morning briefing (music and all); every other arrival
// gets the shorter return recap. A 3 AM stumble to the desk never burns the
// day's one cinematic moment.
@MainActor
final class ArrivalPlanner {
    enum Moment: Equatable {
        case morningBriefing
        case returnRecap
    }

    private let defaults: UserDefaults
    private let wakeHour: Int
    private let now: () -> Date
    private static let lastMorningKey = "lastMorningBriefingDay"

    init(defaults: UserDefaults = .standard, wakeHour: Int = 5,
         now: @escaping () -> Date = Date.init) {
        self.defaults = defaults
        self.wakeHour = wakeHour
        self.now = now
    }

    func momentForArrival() -> Moment {
        let date = now()
        let calendar = Calendar.current
        let day = ISO8601DateFormatter.dayOnly.string(from: date)
        let pastWakeHour = calendar.component(.hour, from: date) >= wakeHour
        let alreadyGreeted = defaults.string(forKey: Self.lastMorningKey) == day

        guard pastWakeHour, !alreadyGreeted else { return .returnRecap }
        defaults.set(day, forKey: Self.lastMorningKey)
        return .morningBriefing
    }
}
