import Foundation

// Turns an away session into the recap window's content and a spoken line.
// Deterministic by design: recaps happen many times a day and must not cost
// LLM credits. (An agent-polished variant can layer on top for the demo.)
enum RecapComposer {
    static func compose(userName: String, departedAt: Date, returnedAt: Date,
                        items: [AwayItem]) -> RecapSession {
        let clock = DateFormatter()
        clock.dateFormat = "HH:mm"
        let away = Self.duration(departedAt, returnedAt)
        let summary = "Away \(away) · \(clock.string(from: departedAt)) → \(clock.string(from: returnedAt))"

        let cards: [RecapCard]
        if items.isEmpty {
            cards = [RecapCard(kind: .news, label: "QUIET", time: clock.string(from: returnedAt),
                               title: "All quiet while you were out",
                               meta: "No new activity on your boards.")]
        } else {
            cards = items.map { item in
                RecapCard(kind: kind(for: item), label: label(for: item),
                          time: clock.string(from: item.at),
                          title: item.title, meta: item.detail)
            }
        }

        return RecapSession(
            userName: userName,
            awaySummary: summary,
            caption: spokenScript(for: RecapSession(
                userName: userName, awaySummary: summary, caption: "",
                handled: items.count, drafts: 0, needsYou: 0, cards: cards)),
            handled: items.count, drafts: 0, needsYou: 0,
            cards: cards)
    }

    static func spokenScript(for session: RecapSession) -> String {
        guard session.handled > 0 else {
            return "Welcome back. All quiet — nothing happened while you were out."
        }
        let first = session.cards.first?.title ?? "something new"
        if session.handled == 1 {
            return "Welcome back. One thing while you were out: \(first)."
        }
        return "Welcome back. \(session.handled) things while you were out — most recently: \(first). It's all on screen."
    }

    private static func duration(_ from: Date, _ to: Date) -> String {
        let minutes = max(1, Int(to.timeIntervalSince(from)) / 60)
        if minutes < 60 { return "\(minutes)m" }
        return "\(minutes / 60)h \(minutes % 60)m"
    }

    private static func kind(for item: AwayItem) -> RecapCard.Kind {
        switch item.kind {
        case .jira: .jira
        case .calendar: .calendar
        case .mail: .mail
        }
    }

    private static func label(for item: AwayItem) -> String {
        switch item.kind {
        case .jira: "JIRA"
        case .calendar: "CAL"
        case .mail: "MAIL"
        }
    }
}
