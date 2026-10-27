import Foundation

// STUBS — replaced by live Google Calendar / Jira integrations in MH-6.
// Canned data keeps agent development free and deterministic.

@MainActor
final class StubCalendarTool: AgentTool {
    let spec = ToolSpec(
        name: "get_calendar",
        description: "Get today's calendar events for the user.",
        parametersJSON: #"{"type":"object","properties":{},"required":[]}"#)

    func invoke(argumentsJSON: String) async -> Result<String, Error> {
        .success("""
        09:30 Stand-up with the LockZone board
        13:00 Lunch with Ana
        15:00 Deep work block: hackathon demo video outline
        """)
    }
}

@MainActor
final class StubJiraTool: AgentTool {
    let spec = ToolSpec(
        name: "get_jira",
        description: "Get the user's open Jira tickets and recent activity.",
        parametersJSON: #"{"type":"object","properties":{},"required":[]}"#)

    func invoke(argumentsJSON: String) async -> Result<String, Error> {
        .success("""
        MH-6 (In Progress): Live data tools — Calendar, Jira, news
        MH-13 (To Do): QA walk test for BLE presence
        New comment on MH-14 from QA: "background advertising needs a device test"
        """)
    }
}
