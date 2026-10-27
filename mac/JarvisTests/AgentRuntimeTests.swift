import Testing
import Foundation
@testable import Jarvis

@MainActor
struct AgentRuntimeTests {
    final class FakeBrain: AgentBrain {
        var script: [BrainReply]
        private(set) var receivedMessages: [[ChatMessage]] = []
        init(script: [BrainReply]) { self.script = script }

        func complete(messages: [ChatMessage], tools: [ToolSpec]) async throws -> BrainReply {
            receivedMessages.append(messages)
            guard !script.isEmpty else { throw URLError(.badServerResponse) }
            return script.removeFirst()
        }
    }

    final class EchoTool: AgentTool {
        private(set) var invocations: [String] = []
        var result: Result<String, Error> = .success("tool-ok")
        let spec = ToolSpec(name: "echo", description: "echoes", parametersJSON: "{}")

        func invoke(argumentsJSON: String) async -> Result<String, Error> {
            invocations.append(argumentsJSON)
            return result
        }
    }

    func makeRuntime(script: [BrainReply], tool: EchoTool? = nil, maxTurns: Int = 6)
        -> (AgentRuntime, FakeBrain, EchoTool) {
        let tool = tool ?? EchoTool()
        let brain = FakeBrain(script: script)
        let runtime = AgentRuntime(brain: brain, tools: [tool],
                                   systemPrompt: "You are Jarvis.", maxTurns: maxTurns)
        return (runtime, brain, tool)
    }

    @Test func returnsPlainTextReply() async throws {
        let (runtime, brain, _) = makeRuntime(script: [.text("Good morning.")])
        let reply = try await runtime.run("brief me")
        #expect(reply == "Good morning.")
        #expect(brain.receivedMessages.count == 1)
        #expect(brain.receivedMessages[0].first?.role == .system)
    }

    @Test func executesToolCallAndFeedsResultBack() async throws {
        let call = ToolCall(id: "1", name: "echo", argumentsJSON: #"{"q":"cal"}"#)
        let (runtime, brain, tool) = makeRuntime(script: [.toolCalls([call]), .text("Done.")])
        let reply = try await runtime.run("brief me")
        #expect(reply == "Done.")
        #expect(tool.invocations == [#"{"q":"cal"}"#])
        let second = brain.receivedMessages[1]
        #expect(second.last?.role == .tool)
        #expect(second.last?.content == "tool-ok")
        #expect(second.last?.toolCallID == "1")
    }

    @Test func unknownToolFeedsErrorBack() async throws {
        let call = ToolCall(id: "9", name: "nope", argumentsJSON: "{}")
        let (runtime, brain, _) = makeRuntime(script: [.toolCalls([call]), .text("ok")])
        _ = try await runtime.run("hi")
        let toolResult = brain.receivedMessages[1].last
        #expect(toolResult?.content.contains("unknown tool") == true)
    }

    @Test func toolFailureFeedsErrorBack() async throws {
        let tool = EchoTool()
        tool.result = .failure(URLError(.timedOut))
        let call = ToolCall(id: "2", name: "echo", argumentsJSON: "{}")
        let (runtime, brain, _) = makeRuntime(script: [.toolCalls([call]), .text("ok")], tool: tool)
        _ = try await runtime.run("hi")
        #expect(brain.receivedMessages[1].last?.content.contains("error") == true)
    }

    @Test func maxTurnsStopsRunawayLoop() async throws {
        let call = ToolCall(id: "3", name: "echo", argumentsJSON: "{}")
        let (runtime, _, _) = makeRuntime(
            script: Array(repeating: BrainReply.toolCalls([call]), count: 10),
            maxTurns: 3)
        await #expect(throws: AgentRuntime.TurnLimitExceeded.self) {
            _ = try await runtime.run("hi")
        }
    }

    @Test func reasoningTagsAreStrippedFromReply() async throws {
        let (runtime, _, _) = makeRuntime(
            script: [.text("<think>internal chain</think>Good morning.")])
        let reply = try await runtime.run("hi")
        #expect(reply == "Good morning.")
    }
}
