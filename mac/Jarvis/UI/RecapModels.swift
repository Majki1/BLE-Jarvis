import SwiftUI

struct RecapCard: Identifiable {
    enum Kind: String {
        case calendar = "C"
        case jira = "J"
        case mail = "M"
        case news = "N"
        case build = "B"
    }

    let id = UUID()
    let kind: Kind
    let label: String
    let time: String
    let title: String
    let meta: String
    var needsYou = false
    var actions: (primary: String, secondary: String)?

    var accent: Color {
        switch kind {
        case .calendar: Theme.cyan
        case .jira: Color(hex: 0x7DE9FF)
        case .mail: Color(hex: 0xC9A2FF)
        case .news: Theme.textMeta
        case .build: Color(hex: 0x7BE87B)
        }
    }
}

struct RecapSession {
    var userName: String
    var awaySummary: String
    var caption: String
    var handled: Int
    var drafts: Int
    var needsYou: Int
    var cards: [RecapCard]

    // Placeholder recap until MH-8's away-mode triage produces real sessions.
    static let sample = RecapSession(
        userName: "MARIN",
        awaySummary: "Away 1h 42m · 10:18 → 12:00",
        caption: "Priya replied about the launch slot. I drafted a yes for Thursday at 3",
        handled: 14, drafts: 2, needsYou: 1,
        cards: [
            RecapCard(kind: .mail, label: "MAIL", time: "11:02",
                      title: "Priya · launch slot",
                      meta: "Asked to move the launch review. Draft reply proposes Thursday 3pm.",
                      needsYou: true,
                      actions: ("Move to Thu 3pm", "Keep")),
            RecapCard(kind: .jira, label: "JIRA", time: "10:44",
                      title: "MH-14 · new QA comment",
                      meta: "\"Background advertising needs a device test\" — reply drafted."),
            RecapCard(kind: .build, label: "BUILD", time: "10:31",
                      title: "CI green on main",
                      meta: "31 tests passed · 4m 12s."),
            RecapCard(kind: .calendar, label: "CAL", time: "now",
                      title: "Next: lunch with Ana, 1pm",
                      meta: "No conflicts this afternoon."),
            RecapCard(kind: .news, label: "NEWS", time: "12:00",
                      title: "Three headlines while you were out",
                      meta: "Tap any card to hear more, or just ask."),
        ])
}
