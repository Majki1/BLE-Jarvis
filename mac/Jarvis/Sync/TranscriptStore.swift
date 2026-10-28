import Foundation
import Observation

struct TranscriptEntry: Codable, Equatable, Identifiable {
    enum Kind: String, Codable {
        case presence, briefing, recap, voice, jira, calendar, life
    }
    var id = UUID()
    let at: Date
    let kind: Kind
    let title: String
    let meta: String
}

// Everything Jarvis does, newest first — the phone's Log tab reads this.
// Persisted as JSON in defaults, capped so it never grows unbounded.
@MainActor @Observable
final class TranscriptStore {
    private static let key = "transcriptEntries"
    private static let cap = 200

    private(set) var entries: [TranscriptEntry] = []
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.key),
           let saved = try? JSONDecoder().decode([TranscriptEntry].self, from: data) {
            entries = saved
        }
    }

    func record(kind: TranscriptEntry.Kind, title: String, meta: String) {
        entries.insert(TranscriptEntry(at: Date(), kind: kind, title: title, meta: meta),
                       at: 0)
        if entries.count > Self.cap {
            entries = Array(entries.prefix(Self.cap))
        }
        if let data = try? JSONEncoder().encode(entries) {
            defaults.set(data, forKey: Self.key)
        }
    }

    func feedJSON() -> String {
        let clock = DateFormatter()
        clock.dateFormat = "HH:mm"
        let items = entries.prefix(50).map { entry in
            ["t": clock.string(from: entry.at),
             "kind": entry.kind.rawValue,
             "title": entry.title,
             "meta": entry.meta]
        }
        let data = (try? JSONSerialization.data(withJSONObject: items)) ?? Data("[]".utf8)
        return String(data: data, encoding: .utf8) ?? "[]"
    }
}
