import Testing
import Foundation
@testable import Jarvis

struct JiraToolTests {
    let fixture = """
    {"issues":[
      {"key":"MH-6","fields":{"summary":"Live data tools","status":{"name":"In Progress"}}},
      {"key":"MH-13","fields":{"summary":"QA walk test","status":{"name":"To Do"}}},
      {"key":"LOC-4","fields":{"summary":"QA purchase flow","status":{"name":"To Do"}}}
    ]}
    """

    @Test func formatsIssuesAsBriefingLines() throws {
        let text = try JiraTool.format(searchResponse: Data(fixture.utf8))
        #expect(text == """
        MH-6 (In Progress): Live data tools
        MH-13 (To Do): QA walk test
        LOC-4 (To Do): QA purchase flow
        """)
    }

    @Test func emptyResultsSaySo() throws {
        let text = try JiraTool.format(searchResponse: Data(#"{"issues":[]}"#.utf8))
        #expect(text == "No open tickets assigned to you.")
    }

    @Test func malformedJSONThrows() {
        #expect(throws: (any Error).self) {
            _ = try JiraTool.format(searchResponse: Data("nope".utf8))
        }
    }
}
