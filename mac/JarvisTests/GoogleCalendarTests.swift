import Testing
import Foundation
@testable import Jarvis

struct GoogleCalendarTests {
    // MARK: OAuth helpers

    @Test func authorizationURLCarriesRequiredParameters() throws {
        let url = GoogleOAuth.authorizationURL(
            clientID: "client-123", redirectURI: "http://127.0.0.1:7777")
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        #expect(components.host == "accounts.google.com")
        let params = Dictionary(uniqueKeysWithValues:
            (components.queryItems ?? []).map { ($0.name, $0.value ?? "") })
        #expect(params["client_id"] == "client-123")
        #expect(params["redirect_uri"] == "http://127.0.0.1:7777")
        #expect(params["response_type"] == "code")
        #expect(params["access_type"] == "offline")
        #expect(params["prompt"] == "consent")
        #expect(params["scope"]?.contains("calendar.events") == true)
    }

    @Test func extractsCodeFromLoopbackRequestLine() {
        let line = "GET /?code=4%2Fabc-DEF_123&scope=https://x HTTP/1.1"
        #expect(GoogleOAuth.authCode(fromRequestLine: line) == "4/abc-DEF_123")
    }

    @Test func requestLineWithoutCodeYieldsNil() {
        #expect(GoogleOAuth.authCode(fromRequestLine: "GET /favicon.ico HTTP/1.1") == nil)
        #expect(GoogleOAuth.authCode(fromRequestLine: "GET /?error=access_denied HTTP/1.1") == nil)
    }

    // MARK: Event formatting

    let fixture = """
    {"items":[
      {"summary":"Stand-up","start":{"dateTime":"2026-10-27T09:30:00+01:00"}},
      {"summary":"Lunch with Ana","start":{"dateTime":"2026-10-27T13:00:00+01:00"}},
      {"summary":"Croatia Holiday","start":{"date":"2026-10-27"}}
    ]}
    """

    @Test func formatsTimedAndAllDayEvents() throws {
        let text = try CalendarTool.format(eventsResponse: Data(fixture.utf8),
                                           timeZone: TimeZone(identifier: "Europe/Zagreb")!)
        #expect(text == """
        09:30 Stand-up
        13:00 Lunch with Ana
        All day: Croatia Holiday
        """)
    }

    @Test func emptyCalendarSaysSo() throws {
        let text = try CalendarTool.format(eventsResponse: Data(#"{"items":[]}"#.utf8),
                                           timeZone: .current)
        #expect(text == "Nothing on the calendar today.")
    }
}
