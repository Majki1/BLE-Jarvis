import SwiftUI

@main
struct JarvisApp: App {
    @State private var engine: PresenceEngine
    @State private var scanner: PresenceScanner
    @State private var performer: BriefingPerformer
    private let recapWindow = RecapWindowController()

    init() {
        let engine = PresenceEngine()
        _engine = State(initialValue: engine)
        let scanner = PresenceScanner(engine: engine)
        _scanner = State(initialValue: scanner)
        let performer = BriefingPerformer(
            music: ThemeMusicPlayer(),
            voice: ElevenLabsSynthesizer(fallback: SystemSynthesizer()))
        _performer = State(initialValue: performer)

        // Placeholder arrival moment until the agent (MH-7/8) supplies real
        // briefings and recap sessions.
        var greeted = false
        let recapWindow = recapWindow
        engine.onEvent = { event in
            guard event == .arrived, !greeted else { return }
            greeted = true
            Task { @MainActor in
                recapWindow.show(session: .sample)
                await performer.perform(script: Self.placeholderScript)
            }
        }
        scanner.start()
        recapWindow.snapshotIfRequested()
    }

    var body: some Scene {
        MenuBarExtra("Jarvis", systemImage: symbol) {
            Text(headline)
            Divider()
            Button("Show recap window") { recapWindow.show(session: .sample) }
            Button("Test briefing") {
                Task { await performer.perform(script: Self.placeholderScript) }
            }
            Divider()
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
