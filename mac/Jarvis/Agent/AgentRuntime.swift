import Foundation

struct ChatMessage: Equatable {
    enum Role: String { case system, user, assistant, tool }
    let role: Role
    let content: String
    var toolCalls: [ToolCall] = []
    var toolCallID: String?
}

struct ToolSpec: Equatable {
    let name: String
    let description: String
    let parametersJSON: String
}

struct ToolCall: Equatable {
    let id: String
    let name: String
    let argumentsJSON: String
}

enum BrainReply: Equatable {
    case text(String)
    case toolCalls([ToolCall])
}

@MainActor
protocol AgentBrain {
    func complete(messages: [ChatMessage], tools: [ToolSpec]) async throws -> BrainReply
}

@MainActor
protocol AgentTool {
    var spec: ToolSpec { get }
    func invoke(argumentsJSON: String) async -> Result<String, Error>
}

// The agent loop: brain decides, tools execute, results feed back, until the
// brain answers in text. Reasoning traces (<think>…</think>) from open-weights
// models are stripped from the final reply.
@MainActor
final class AgentRuntime {
    struct TurnLimitExceeded: Error {}

    private let brain: AgentBrain
    private let tools: [String: AgentTool]
    private let systemPrompt: String
    private let maxTurns: Int

    init(brain: AgentBrain, tools: [AgentTool], systemPrompt: String, maxTurns: Int = 6) {
        self.brain = brain
        self.tools = Dictionary(uniqueKeysWithValues: tools.map { ($0.spec.name, $0) })
        self.systemPrompt = systemPrompt
        self.maxTurns = maxTurns
    }

    func run(_ userMessage: String, history: [ChatMessage] = []) async throws -> String {
        var messages: [ChatMessage] =
            [ChatMessage(role: .system, content: systemPrompt)]
            + history
            + [ChatMessage(role: .user, content: userMessage)]

        for _ in 0..<maxTurns {
            switch try await brain.complete(messages: messages, tools: Array(toolSpecs)) {
            case .text(let text):
                return Self.stripReasoning(text)
            case .toolCalls(let calls):
                messages.append(ChatMessage(role: .assistant, content: "", toolCalls: calls))
                for call in calls {
                    let result = await execute(call)
                    messages.append(ChatMessage(role: .tool, content: result,
                                                toolCallID: call.id))
                }
            }
        }
        throw TurnLimitExceeded()
    }

    private var toolSpecs: [ToolSpec] { tools.values.map(\.spec) }

    private func execute(_ call: ToolCall) async -> String {
        guard let tool = tools[call.name] else {
            return "error: unknown tool '\(call.name)'"
        }
        switch await tool.invoke(argumentsJSON: call.argumentsJSON) {
        case .success(let output): return output
        case .failure(let error): return "error: \(error.localizedDescription)"
        }
    }

    static func stripReasoning(_ text: String) -> String {
        guard let open = text.range(of: "<think>"),
              let close = text.range(of: "</think>") else {
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        var cleaned = text
        cleaned.removeSubrange(open.lowerBound..<close.upperBound)
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
