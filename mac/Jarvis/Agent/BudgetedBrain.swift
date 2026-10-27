import Foundation

// Hard daily cap on LLM calls so development or a runaway loop can never
// burn the hackathon's API credits. Count persists in UserDefaults and
// resets when the day key changes.
@MainActor
final class BudgetedBrain: AgentBrain {
    struct BudgetExceeded: Error {}

    private let inner: AgentBrain
    private let maxCallsPerDay: Int
    private let defaults: UserDefaults
    private let today: () -> String

    private static let countKey = "llmBudgetCount"
    private static let dayKey = "llmBudgetDay"

    init(wrapping inner: AgentBrain,
         maxCallsPerDay: Int = 40,
         defaults: UserDefaults = .standard,
         today: @escaping () -> String = {
             ISO8601DateFormatter.dayOnly.string(from: Date())
         }) {
        self.inner = inner
        self.maxCallsPerDay = maxCallsPerDay
        self.defaults = defaults
        self.today = today
    }

    func complete(messages: [ChatMessage], tools: [ToolSpec]) async throws -> BrainReply {
        let day = today()
        if defaults.string(forKey: Self.dayKey) != day {
            defaults.set(day, forKey: Self.dayKey)
            defaults.set(0, forKey: Self.countKey)
        }
        let used = defaults.integer(forKey: Self.countKey)
        guard used < maxCallsPerDay else { throw BudgetExceeded() }
        defaults.set(used + 1, forKey: Self.countKey)
        return try await inner.complete(messages: messages, tools: tools)
    }
}

extension ISO8601DateFormatter {
    static let dayOnly: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return formatter
    }()
}
