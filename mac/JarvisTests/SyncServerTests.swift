import Testing
import Foundation
@testable import Jarvis

@MainActor
struct TranscriptStoreTests {
    func makeStore() -> TranscriptStore {
        TranscriptStore(defaults: UserDefaults(suiteName: "ts-\(UUID().uuidString)")!)
    }

    @Test func recordsEntriesNewestFirst() {
        let store = makeStore()
        store.record(kind: .presence, title: "You left your desk", meta: "away watch started")
        store.record(kind: .jira, title: "MH-14 updated", meta: "Status: To Do")
        #expect(store.entries.count == 2)
        #expect(store.entries.first?.title == "MH-14 updated")
    }

    @Test func capsAtTwoHundredEntries() {
        let store = makeStore()
        for index in 0..<220 {
            store.record(kind: .voice, title: "entry \(index)", meta: "")
        }
        #expect(store.entries.count == 200)
        #expect(store.entries.first?.title == "entry 219")
    }

    @Test func persistsAcrossInstances() {
        let defaults = UserDefaults(suiteName: "ts-\(UUID().uuidString)")!
        TranscriptStore(defaults: defaults)
            .record(kind: .briefing, title: "Morning briefing", meta: "spoken 08:01")
        let reloaded = TranscriptStore(defaults: defaults)
        #expect(reloaded.entries.first?.title == "Morning briefing")
    }
}

struct SyncHTTPTests {
    @Test func parsesRouteAndToken() {
        let raw = "GET /feed HTTP/1.1\r\nHost: x\r\nX-Jarvis-Code: 482913\r\n\r\n"
        let request = SyncHTTP.parse(raw)
        #expect(request?.method == "GET")
        #expect(request?.path == "/feed")
        #expect(request?.code == "482913")
    }

    @Test func missingCodeParsesAsNil() {
        let request = SyncHTTP.parse("GET /status HTTP/1.1\r\nHost: x\r\n\r\n")
        #expect(request?.code == nil)
    }

    @Test func garbageParsesAsNil() {
        #expect(SyncHTTP.parse("") == nil)
        #expect(SyncHTTP.parse("nonsense") == nil)
    }

    @Test func responsesCarryStatusAndJSON() {
        let response = SyncHTTP.response(status: 200, json: #"{"ok":true}"#)
        let text = String(data: response, encoding: .utf8)!
        #expect(text.hasPrefix("HTTP/1.1 200"))
        #expect(text.contains("application/json"))
        #expect(text.hasSuffix(#"{"ok":true}"#))
    }

    @Test func wrongCodeIsRejectedByRouter() {
        let body = SyncRouter.route(path: "/feed", code: "000000", expectedCode: "482913",
                                    statusJSON: { "{}" }, feedJSON: { "[]" })
        #expect(body.status == 403)
    }

    @Test func statusneedsNoCode() {
        let body = SyncRouter.route(path: "/status", code: nil, expectedCode: "482913",
                                    statusJSON: { #"{"presence":"present"}"# }, feedJSON: { "[]" })
        #expect(body.status == 200)
        #expect(body.json.contains("present"))
    }

    @Test func feedWithValidCodeSucceeds() {
        let body = SyncRouter.route(path: "/feed", code: "482913", expectedCode: "482913",
                                    statusJSON: { "{}" }, feedJSON: { #"[{"title":"x"}]"# })
        #expect(body.status == 200)
        #expect(body.json.contains("title"))
    }

    @Test func unknownPathIs404() {
        let body = SyncRouter.route(path: "/nope", code: nil, expectedCode: "1",
                                    statusJSON: { "{}" }, feedJSON: { "[]" })
        #expect(body.status == 404)
    }
}
