import SwiftUI

@main
struct JarvisApp: App {
    @State private var engine: PresenceEngine
    @State private var scanner: PresenceScanner
    @State private var performer: BriefingPerformer

    init() {
        let engine = PresenceEngine()
        _engine = State(initialValue: engine)
        let scanner = PresenceScanner(engine: engine)
        _scanner = State(initialValue: scanner)
        let performer = BriefingPerformer(
            music: ThemeMusicPlayer(),
            voice: ElevenLabsSynthesizer(fallback: SystemSynthesizer()))
        _performer = State(initialValue: performer)

        // Placeholder arrival moment until the agent (MH-5/7) writes real
        // briefings: first arrival of the session gets the full performance.
        var greeted = false
        engine.onEvent = { event in
            guard event == .arrived, !greeted else { return }
            greeted = true
            Task { @MainActor in
                await performer.perform(script: Self.placeholderScript)
            }
        }
        scanner.start()
    }

    var body: some Scene {
        MenuBarExtra("Jarvis", systemImage: symbol) {
            Text(headline)
            Divider()
            Button("Test briefing") {
                Task { await performer.perform(script: Self.placeholderScript) }
            }
            Button("Quit Jarvis") { NSApplication.shared.terminate(nil) }
        }
    }

    private static let placeholderScript =
        "Good morning, Marin. Systems are online. Your calendar, your tickets, " +
        "and the news will join me here shortly. For now — enjoy the music."

    private var symbol: String {
        switch engine.state {
        case .unknown: "antenna.radiowaves.left.and.right"
        case .present: "person.fill.checkmark"
        case .away: "moon.zzz"
        }
    }

    private var headline: String {
        switch engine.state {
        case .unknown: "Waiting for your iPhone…"
        case .present: "You're at your desk"
        case .away: "Away — watching your world"
        }
    }
}
