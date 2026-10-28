import Foundation
import Observation

struct CalEvent: Equatable, Identifiable {
    let id: String
    let summary: String
    let start: Date
    let end: Date
    var minutes: Int { Int(end.timeIntervalSince(start) / 60) }
}

// What disappeared from the calendar while you were away — future slots only.
enum CalendarDiff {
    static func freedSlots(snapshot: [CalEvent], current: [CalEvent], now: Date) -> [CalEvent] {
        let currentIDs = Set(current.map(\.id))
        return snapshot.filter { $0.start > now && !currentIDs.contains($0.id) }
    }
}

// A handful of wellbeing goals plus a keep/skip record that tilts future
// suggestions toward what the user actually accepts.
@MainActor
final class WellbeingProfile {
    private let defaults: UserDefaults
    let goals: [String]
    let favoritePlaces: [String]

    init(defaults: UserDefaults = .standard,
         goals: [String]? = nil,
         favoritePlaces: [String]? = nil) {
        self.defaults = defaults
        self.goals = goals
            ?? defaults.stringArray(forKey: "wellbeingGoals")
            ?? ["move more", "eat healthier"]
        self.favoritePlaces = favoritePlaces
            ?? defaults.stringArray(forKey: "favoritePlaces")
            ?? []
    }

    var preferredGoal: String {
        goals.max { score(for: $0) < score(for: $1) } ?? "move more"
    }

    func recordKept(goal: String) { bump(goal, key: "kept") }
    func recordSkipped(goal: String) { bump(goal, key: "skipped") }

    private func score(for goal: String) -> Int {
        defaults.integer(forKey: "wb.\(goal).kept") - defaults.integer(forKey: "wb.\(goal).skipped")
    }

    private func bump(_ goal: String, key: String) {
        let k = "wb.\(goal).\(key)"
        defaults.set(defaults.integer(forKey: k) + 1, forKey: k)
    }
}

struct Suggestion: Equatable {
    let slot: CalEvent
    let goal: String
    let text: String
    let blockTitle: String
}

// One suggestion per return, slots ≥ 45 minutes only. Rest counts as a goal.
@MainActor
enum SuggestionComposer {
    static func compose(freedSlots: [CalEvent], profile: WellbeingProfile) -> Suggestion? {
        guard let slot = freedSlots.first(where: { $0.minutes >= 45 }) else { return nil }
        let goal = profile.preferredGoal
        let clock = DateFormatter()
        clock.dateFormat = "HH:mm"
        let when = clock.string(from: slot.start)

        let hour = Calendar.current.component(.hour, from: slot.start)
        let isLunchtime = (11...14).contains(hour)

        if goal == "eat healthier" && isLunchtime {
            let place = profile.favoritePlaces.first.map { " — \($0)?" } ?? "."
            return Suggestion(
                slot: slot, goal: goal,
                text: "Your \(when) freed up — exactly lunch-sized. How about a real, healthy lunch\(place)",
                blockTitle: "Lunch break")
        }
        if goal == "eat healthier" {
            return Suggestion(
                slot: slot, goal: goal,
                text: "Your \(when) freed up. A \(slot.minutes)-minute break for something properly healthy?",
                blockTitle: "Food break")
        }
        return Suggestion(
            slot: slot, goal: goal,
            text: "Your \(when) freed up — \(slot.minutes) minutes. A walk would do you good.",
            blockTitle: "Walk")
    }
}
