import Foundation

// Assembles the production agent: persona prompt, tools, and a brain picked
// from available credentials — Baseten-served Muse Spark Open first (open
// weights, bonus-prize eligible), Meta Model API (muse-spark-1.3) as
// fallback. Every brain is wrapped in the daily budget guard.
enum JarvisAgent {
    static let systemPrompt = """
    You are Jarvis, a presence-aware desk assistant speaking aloud to Marin \
    at his desk. Your replies are spoken by text-to-speech: plain prose, no \
    markdown, no lists, no emojis. You are calm, precise, lightly dry-witted \
    — one quip maximum. Use your tools to gather real data before answering. \
    A morning briefing covers: greeting, today's calendar, notable Jira \
    activity, and two or three news headlines, in under 150 words.
    """

    @MainActor
    static func make() -> AgentRuntime? {
        let env = ProcessInfo.processInfo.environment
        let brain: AgentBrain
        if env["JARVIS_LLM_API_KEY"] != nil
            || UserDefaults.standard.string(forKey: "llmAPIKey") != nil {
            brain = OpenAICompatibleBrain()
        } else if let metaKey = env["META_API_KEY"]
            ?? UserDefaults.standard.string(forKey: "metaAPIKey") {
            brain = OpenAICompatibleBrain(
                baseURL: URL(string: "https://api.meta.ai/v1")!,
                model: "muse-spark-1.3",
                apiKey: metaKey)
        } else {
            return nil
        }
        let jira: AgentTool = JiraTool.credentials != nil ? JiraTool() : StubJiraTool()
        let calendar: AgentTool = GoogleOAuth.isConnected ? CalendarTool() : StubCalendarTool()
        return AgentRuntime(
            brain: BudgetedBrain(wrapping: brain),
            tools: [calendar, jira, NewsTool()],
            systemPrompt: systemPrompt)
    }
}
