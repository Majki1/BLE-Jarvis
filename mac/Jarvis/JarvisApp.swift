import SwiftUI

@main
struct JarvisApp: App {
    @State private var engine: PresenceEngine
    @State private var scanner: PresenceScanner
    @State private var performer: BriefingPerformer
    private let recapWindow = RecapWindowController()
    private let calibrationWindow = CalibrationWindowController()

    init() {
        // Tunables overridable per-machine without rebuilds:
        //   defaults write com.msoft.blejarvis.Jarvis graceSeconds -int 15
        let defaults = UserDefaults.standard
        let engine = PresenceEngine(
            arriveThreshold: defaults.object(forKey: "arriveRSSI") as? Int ?? -60,
            holdThreshold: defaults.object(forKey: "holdRSSI") as? Int ?? -80,
            graceInterval: defaults.object(forKey: "graceSeconds") as? TimeInterval ?? 45)
        _engine = State(initialValue: engine)
        let scanner = PresenceScanner(engine: engine)
        _scanner = State(initialValue: scanner)
        let performer = BriefingPerformer(
            music: ThemeMusicPlayer(),
            voice: ElevenLabsSynthesizer(fallback: SystemSynthesizer()))
        _performer = State(initialValue: performer)

        // Arrival pipeline (MH-7): first arrival of the day gets the full
        // music-backed briefing composed live by the agent; later arrivals
        // get the recap window and a short line. Recap *content* is sample
        // data until MH-8's away-mode triage lands.
        let recapWindow = recapWindow
        let planner = ArrivalPlanner()
        engine.onEvent = { event in
            if event == .departed {
                // Visible departure: the recap window leaves with you.
                Task { @MainActor in recapWindow.hide() }
                return
            }
            Task { @MainActor in
                switch planner.momentForArrival() {
                case .morningBriefing:
                    recapWindow.show(session: .sample)
                    await performer.perform(withMusic: true) {
                        guard let agent = JarvisAgent.make() else {
                            return Self.placeholderScript
                        }
                        return try await agent.run(
                            "I just arrived at my desk this morning. Compose my morning briefing.")
                    }
                case .returnRecap:
                    recapWindow.show(session: .sample)
                    await performer.perform(script: "Welcome back.", withMusic: false)
                }
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
            if !GoogleOAuth.isConnected {
                Button("Connect Google Calendar…") {
                    Task { try? await GoogleOAuth().connect() }
                }
            }
            Button("Calibrate away boundary…") {
                calibrationWindow.show(engine: engine)
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
