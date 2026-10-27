import Testing
import Foundation
@testable import Jarvis

@MainActor
struct BudgetedBrainTests {
    final class CountingBrain: AgentBrain {
        private(set) var calls = 0
        func complete(messages: [ChatMessage], tools: [ToolSpec]) async throws -> BrainReply {
            calls += 1
            return .text("ok")
        }
    }

    func makeGuard(maxPerDay: Int, day: String = "2026-10-27")
        -> (BudgetedBrain, CountingBrain, UserDefaults) {
        let defaults = UserDefaults(suiteName: "budget-tests-\(UUID().uuidString)")!
        let inner = CountingBrain()
        let brain = BudgetedBrain(wrapping: inner, maxCallsPerDay: maxPerDay,
                                  defaults: defaults, today: { day })
        return (brain, inner, defaults)
    }

    @Test func passesThroughUnderLimit() async throws {
        let (brain, inner, _) = makeGuard(maxPerDay: 2)
        let reply = try await brain.complete(messages: [], tools: [])
        #expect(reply == .text("ok"))
        #expect(inner.calls == 1)
    }

    @Test func refusesBeyondDailyLimit() async throws {
        let (brain, inner, _) = makeGuard(maxPerDay: 2)
        _ = try await brain.complete(messages: [], tools: [])
        _ = try await brain.complete(messages: [], tools: [])
        await #expect(throws: BudgetedBrain.BudgetExceeded.self) {
            _ = try await brain.complete(messages: [], tools: [])
        }
        #expect(inner.calls == 2)
    }

    @Test func budgetPersistsAcrossInstances() async throws {
        let defaults = UserDefaults(suiteName: "budget-tests-\(UUID().uuidString)")!
        let inner = CountingBrain()
        _ = try await BudgetedBrain(wrapping: inner, maxCallsPerDay: 1,
                                    defaults: defaults, today: { "d1" })
            .complete(messages: [], tools: [])
        await #expect(throws: BudgetedBrain.BudgetExceeded.self) {
            _ = try await BudgetedBrain(wrapping: inner, maxCallsPerDay: 1,
                                        defaults: defaults, today: { "d1" })
                .complete(messages: [], tools: [])
        }
    }

    @Test func freshDayResetsBudget() async throws {
        let defaults = UserDefaults(suiteName: "budget-tests-\(UUID().uuidString)")!
        let inner = CountingBrain()
        _ = try await BudgetedBrain(wrapping: inner, maxCallsPerDay: 1,
                                    defaults: defaults, today: { "d1" })
            .complete(messages: [], tools: [])
        let nextDay = BudgetedBrain(wrapping: inner, maxCallsPerDay: 1,
                                    defaults: defaults, today: { "d2" })
        _ = try await nextDay.complete(messages: [], tools: [])
        #expect(inner.calls == 2)
    }
}
