import Testing
import Foundation
@testable import Jarvis

struct CalendarDiffTests {
    func event(_ id: String, _ title: String, startHour: Int, endHour: Int) -> CalEvent {
        var components = DateComponents()
        components.year = 2026; components.month = 10; components.day = 28
        components.hour = startHour
        let start = Calendar.current.date(from: components)!
        return CalEvent(id: id, summary: title, start: start,
                        end: start.addingTimeInterval(TimeInterval((endHour - startHour) * 3600)))
    }

    var noon: Date {
        var components = DateComponents()
        components.year = 2026; components.month = 10; components.day = 28; components.hour = 12
        return Calendar.current.date(from: components)!
    }

    @Test func detectsCancelledFutureEvent() {
        let snapshot = [event("a", "Design review", startHour: 14, endHour: 15),
                        event("b", "Standup", startHour: 16, endHour: 17)]
        let current = [event("b", "Standup", startHour: 16, endHour: 17)]
        let freed = CalendarDiff.freedSlots(snapshot: snapshot, current: current, now: noon)
        #expect(freed.map(\.id) == ["a"])
    }

    @Test func pastEventsAreNotFreedSlots() {
        let snapshot = [event("a", "Morning sync", startHour: 9, endHour: 10)]
        let freed = CalendarDiff.freedSlots(snapshot: snapshot, current: [], now: noon)
        #expect(freed.isEmpty)
    }

    @Test func unchangedCalendarFreesNothing() {
        let snapshot = [event("a", "Review", startHour: 14, endHour: 15)]
        let freed = CalendarDiff.freedSlots(snapshot: snapshot, current: snapshot, now: noon)
        #expect(freed.isEmpty)
    }
}

@MainActor
struct WellbeingProfileTests {
    func makeProfile() -> WellbeingProfile {
        WellbeingProfile(defaults: UserDefaults(suiteName: "wb-\(UUID().uuidString)")!,
                         goals: ["move more", "eat healthier"])
    }

    @Test func prefersGoalWithBestKeptRecord() {
        let profile = makeProfile()
        profile.recordKept(goal: "eat healthier")
        profile.recordKept(goal: "eat healthier")
        profile.recordSkipped(goal: "move more")
        #expect(profile.preferredGoal == "eat healthier")
    }

    @Test func defaultsToFirstGoalWithoutHistory() {
        #expect(makeProfile().preferredGoal == "move more")
    }
}

@MainActor
struct SuggestionComposerTests {
    func slot(_ title: String, hour: Int, minutes: Int) -> CalEvent {
        var components = DateComponents()
        components.year = 2026; components.month = 10; components.day = 28
        components.hour = hour
        let start = Calendar.current.date(from: components)!
        return CalEvent(id: title, summary: title, start: start,
                        end: start.addingTimeInterval(TimeInterval(minutes * 60)))
    }

    func profile(goals: [String], places: [String] = []) -> WellbeingProfile {
        WellbeingProfile(defaults: UserDefaults(suiteName: "wb-\(UUID().uuidString)")!,
                         goals: goals, favoritePlaces: places)
    }

    @Test func lunchtimeSlotWithEatGoalSuggestsLunch() {
        let suggestion = SuggestionComposer.compose(
            freedSlots: [slot("2pm sync", hour: 13, minutes: 60)],
            profile: profile(goals: ["eat healthier"], places: ["Zrno"]))
        #expect(suggestion != nil)
        #expect(suggestion!.text.contains("lunch"))
        #expect(suggestion!.text.contains("Zrno"))
        #expect(suggestion!.blockTitle == "Lunch break")
    }

    @Test func afternoonSlotWithMoveGoalSuggestsWalk() {
        let suggestion = SuggestionComposer.compose(
            freedSlots: [slot("retro", hour: 16, minutes: 60)],
            profile: profile(goals: ["move more"]))
        #expect(suggestion?.text.contains("walk") == true)
        #expect(suggestion?.blockTitle == "Walk")
    }

    @Test func shortSlotsAreIgnored() {
        let suggestion = SuggestionComposer.compose(
            freedSlots: [slot("quick sync", hour: 15, minutes: 30)],
            profile: profile(goals: ["move more"]))
        #expect(suggestion == nil)
    }

    @Test func atMostOneSuggestion() {
        let suggestion = SuggestionComposer.compose(
            freedSlots: [slot("a", hour: 13, minutes: 60), slot("b", hour: 15, minutes: 60)],
            profile: profile(goals: ["move more"]))
        #expect(suggestion?.slot.id == "a")
    }
}
