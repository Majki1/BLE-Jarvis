import Foundation

// Chat-completions client for any OpenAI-compatible endpoint. Default config
// targets Baseten serving Muse Spark Open (the hackathon's open-weights
// model); base URL / model / key are overridable so the Meta Model API or a
// local server slot in without code changes.
//   JARVIS_LLM_BASE_URL  (default https://inference.baseten.co/v1)
//   JARVIS_LLM_MODEL     (default meta-models/muse-spark-open-1026)
//   JARVIS_LLM_API_KEY
@MainActor
final class OpenAICompatibleBrain: AgentBrain {
    struct MissingAPIKey: Error {}
    struct BadResponse: Error { let detail: String }

    private let baseURL: URL
    private let model: String
    private let apiKey: String?

    init(baseURL: URL? = nil, model: String? = nil, apiKey: String? = nil) {
        let env = ProcessInfo.processInfo.environment
        let defaults = UserDefaults.standard
        self.baseURL = baseURL
            ?? (env["JARVIS_LLM_BASE_URL"] ?? defaults.string(forKey: "llmBaseURL"))
                .flatMap(URL.init(string:))
            ?? URL(string: "https://inference.baseten.co/v1")!
        self.model = model
            ?? env["JARVIS_LLM_MODEL"]
            ?? defaults.string(forKey: "llmModel")
            ?? "meta-models/muse-spark-open-1026"
        self.apiKey = apiKey
            ?? env["JARVIS_LLM_API_KEY"]
            ?? defaults.string(forKey: "llmAPIKey")
    }

    func complete(messages: [ChatMessage], tools: [ToolSpec]) async throws -> BrainReply {
        guard let apiKey else { throw MissingAPIKey() }
        var request = URLRequest(url: baseURL.appending(path: "chat/completions"))
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30
        request.httpBody = try JSONEncoder().encode(Payload(
            model: model,
            messages: messages.map(WireMessage.init),
            tools: tools.isEmpty ? nil : tools.map(WireTool.init),
            max_tokens: 1500))

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw BadResponse(detail: String(body.prefix(500)))
        }
        let decoded = try JSONDecoder().decode(WireResponse.self, from: data)
        guard let choice = decoded.choices.first else {
            throw BadResponse(detail: "no choices in response")
        }
        if let calls = choice.message.tool_calls, !calls.isEmpty {
            return .toolCalls(calls.map {
                ToolCall(id: $0.id, name: $0.function.name,
                         argumentsJSON: $0.function.arguments)
            })
        }
        return .text(choice.message.content ?? "")
    }
}

// MARK: - Wire format

private struct Payload: Encodable {
    let model: String
    let messages: [WireMessage]
    let tools: [WireTool]?
    let max_tokens: Int
}

private struct WireMessage: Encodable {
    let role: String
    let content: String?
    let tool_calls: [WireToolCallOut]?
    let tool_call_id: String?

    init(_ message: ChatMessage) {
        role = message.role.rawValue
        content = message.content.isEmpty && !message.toolCalls.isEmpty ? nil : message.content
        tool_calls = message.toolCalls.isEmpty ? nil : message.toolCalls.map {
            WireToolCallOut(id: $0.id,
                            function: .init(name: $0.name, arguments: $0.argumentsJSON))
        }
        tool_call_id = message.toolCallID
    }
}

private struct WireToolCallOut: Encodable {
    let id: String
    var type = "function"
    let function: Function
    struct Function: Encodable {
        let name: String
        let arguments: String
    }
}

private struct WireTool: Encodable {
    var type = "function"
    let function: Function
    struct Function: Encodable {
        let name: String
        let description: String
        let parameters: RawJSON
    }

    init(_ spec: ToolSpec) {
        function = Function(name: spec.name, description: spec.description,
                            parameters: RawJSON(spec.parametersJSON))
    }
}

// Encodes a pre-built JSON string verbatim.
private struct RawJSON: Encodable {
    let json: String
    init(_ json: String) { self.json = json }

    func encode(to encoder: Encoder) throws {
        let value = try JSONSerialization.jsonObject(with: Data(json.utf8))
        var container = encoder.singleValueContainer()
        try container.encode(AnyCodable(value))
    }
}

private struct AnyCodable: Encodable {
    let value: Any
    init(_ value: Any) { self.value = value }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case let v as Bool: try container.encode(v)
        case let v as Int: try container.encode(v)
        case let v as Double: try container.encode(v)
        case let v as String: try container.encode(v)
        case let v as [Any]: try container.encode(v.map(AnyCodable.init))
        case let v as [String: Any]: try container.encode(v.mapValues(AnyCodable.init))
        case is NSNull: try container.encodeNil()
        default: try container.encodeNil()
        }
    }
}

private struct WireResponse: Decodable {
    let choices: [Choice]
    struct Choice: Decodable {
        let message: Message
        struct Message: Decodable {
            let content: String?
            let tool_calls: [WireToolCallIn]?
        }
    }
}

private struct WireToolCallIn: Decodable {
    let id: String
    let function: Function
    struct Function: Decodable {
        let name: String
        let arguments: String
    }
}
