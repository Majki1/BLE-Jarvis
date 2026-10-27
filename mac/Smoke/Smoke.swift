import Foundation

// One-shot agent smoke run for MH-5 acceptance. Spends real LLM credits —
// run deliberately, never in CI. Guarded by BudgetedBrain's daily cap.
@main @MainActor
struct Smoke {
    static func main() async {
        guard let agent = JarvisAgent.make() else {
            print("No API key configured (set JARVIS_LLM_API_KEY or META_API_KEY)")
            exit(1)
        }
        let start = Date()
        do {
            let reply = try await agent.run("Good morning — compose my morning briefing.")
            let elapsed = String(format: "%.1f", Date().timeIntervalSince(start))
            print("=== BRIEFING (\(elapsed)s) ===")
            print(reply)
        } catch {
            print("agent error: \(error)")
            exit(1)
        }
    }
}
