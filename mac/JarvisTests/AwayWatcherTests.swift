import Testing
import Foundation
@testable import Jarvis

@MainActor
struct AwayWatcherTests {
    final class FakeSource: AwayChangeSource {
        var batches: [[AwayItem]] = []
        private(set) var polls = 0
        func changes(since: Date) async -> [AwayItem] {
            polls += 1
            return batches.isEmpty ? [] : batches.removeFirst()
        }
    }

    func item(_ id: String, title: String = "t") -> AwayItem {
        AwayItem(id: id, kind: .jira, title: title, detail: "d",
                 at: Date(timeIntervalSince1970: 0))
    }

    @Test func collectsAndDedupsAcrossPolls() async {
        let source = FakeSource()
        source.batches = [[item("a"), item("b")], [item("b"), item("c")]]
        var watcher: AwayWatcher?
        var pollCount = 0
        watcher = AwayWatcher(sources: [source], sleep: {
            pollCount += 1
            if pollCount > 2 { watcher?.stop() }
        })
        watcher!.start(departedAt: Date(timeIntervalSince1970: 0))
        await watcher!.waitUntilStopped()
        #expect(watcher!.items.map(\.id) == ["a", "b", "c"])
    }

    @Test func startResetsPreviousSession() async {
        let source = FakeSource()
        source.batches = [[item("old")]]
        var watcher: AwayWatcher?
        var pollCount = 0
        watcher = AwayWatcher(sources: [source], sleep: {
            pollCount += 1
            if pollCount >= 1 && source.batches.isEmpty { watcher?.stop() }
        })
        watcher!.start(departedAt: .init(timeIntervalSince1970: 0))
        await watcher!.waitUntilStopped()
        #expect(watcher!.items.map(\.id) == ["old"])

        source.batches = [[item("new")]]
        pollCount = 0
        watcher!.start(departedAt: .init(timeIntervalSince1970: 100))
        await watcher!.waitUntilStopped()
        #expect(watcher!.items.map(\.id) == ["new"])
    }
}

@MainActor
struct RecapComposerTests {
    func item(_ id: String, title: String, detail: String = "d") -> AwayItem {
        AwayItem(id: id, kind: .jira, title: title, detail: detail,
                 at: Date(timeIntervalSince1970: 1000))
    }

    @Test func composesSessionFromItems() {
        let departed = Date(timeIntervalSince1970: 1_000_000)      // 10:46 UTC-ish
        let returned = departed.addingTimeInterval(6_120)          // 1h 42m
        let session = RecapComposer.compose(
            userName: "MARIN",
            departedAt: departed, returnedAt: returned,
            items: [item("MH-8", title: "MH-8 updated"),
                    item("MH-9", title: "MH-9 updated")])
        #expect(session.userName == "MARIN")
        #expect(session.awaySummary.contains("1h 42m"))
        #expect(session.handled == 2)
        #expect(session.cards.count == 2)
        #expect(session.cards[0].title == "MH-8 updated")
    }

    @Test func emptyAwayProducesQuietSessionAndScript() {
        let departed = Date(timeIntervalSince1970: 1_000_000)
        let session = RecapComposer.compose(
            userName: "M", departedAt: departed,
            returnedAt: departed.addingTimeInterval(300), items: [])
        #expect(session.handled == 0)
        #expect(session.cards.count == 1)       // "all quiet" card
        let script = RecapComposer.spokenScript(for: session)
        #expect(script.contains("quiet") || script.contains("Nothing"))
    }

    @Test func spokenScriptMentionsItemCountAndFirstTitle() {
        let departed = Date(timeIntervalSince1970: 1_000_000)
        let session = RecapComposer.compose(
            userName: "M", departedAt: departed,
            returnedAt: departed.addingTimeInterval(3600),
            items: [item("MH-8", title: "QA commented on MH-8")])
        let script = RecapComposer.spokenScript(for: session)
        #expect(script.contains("QA commented on MH-8"))
    }
}
