import Foundation
import Observation

struct AwayItem: Equatable, Identifiable {
    enum Kind { case jira, calendar, mail }
    let id: String
    let kind: Kind
    let title: String
    let detail: String
    let at: Date
}

@MainActor
protocol AwayChangeSource {
    func changes(since: Date) async -> [AwayItem]
}

// Runs while you're away: polls sources on a timer (plain REST — no LLM
// spend), accumulating deduplicated items for the return recap.
@MainActor @Observable
final class AwayWatcher {
    private(set) var items: [AwayItem] = []
    private(set) var departedAt: Date?

    private let sources: [AwayChangeSource]
    private let sleep: () async -> Void
    private var loop: Task<Void, Never>?
    private var running = false

    init(sources: [AwayChangeSource],
         pollInterval: TimeInterval = 60,
         sleep: (() async -> Void)? = nil) {
        self.sources = sources
        self.sleep = sleep ?? {
            try? await Task.sleep(for: .seconds(pollInterval))
        }
    }

    func start(departedAt: Date) {
        stop()
        items = []
        self.departedAt = departedAt
        running = true
        presenceLog.info("away watch started")
        loop = Task { [weak self] in
            while let self, self.running {
                await self.sleep()
                guard self.running, let since = self.departedAt else { break }
                for source in self.sources {
                    let fresh = await source.changes(since: since)
                    self.merge(fresh)
                }
            }
        }
    }

    func stop() {
        running = false
        loop?.cancel()
        loop = nil
    }

    func waitUntilStopped() async {
        await loop?.value
    }

    private func merge(_ fresh: [AwayItem]) {
        let known = Set(items.map(\.id))
        let additions = fresh.filter { !known.contains($0.id) }
        if !additions.isEmpty {
            items += additions
            presenceLog.info("away watch: \(additions.count) new item(s), \(self.items.count) total")
        }
    }
}
