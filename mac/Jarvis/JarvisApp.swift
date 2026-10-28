import SwiftUI

@main
struct JarvisApp: App {
    @State private var engine: PresenceEngine
    @State private var scanner: PresenceScanner
    @State private var performer: BriefingPerformer
    @State private var voiceReplies: VoiceReplyCoordinator
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
        let voice = ElevenLabsSynthesizer(fallback: SystemSynthesizer())
        let performer = BriefingPerformer(music: ThemeMusicPlayer(), voice: voice)
        _performer = State(initialValue: performer)
        let voiceReplies = VoiceReplyCoordinator(voice: voice)
        _voiceReplies = State(initialValue: voiceReplies)

        // Arrival pipeline (MH-7/8): first arrival of the day gets the full
        // music-backed briefing composed live by the agent; later arrivals
        // get a recap of what the away-watcher collected while you were out.
        let recapWindow = recapWindow
        let planner = ArrivalPlanner()
        let calendarSource = CalendarChangeSource()
        let watcher = AwayWatcher(
            sources: [JiraChangeSource(), calendarSource],
            pollInterval: defaults.object(forKey: "awayPollSeconds") as? TimeInterval ?? 60)
        let userName = defaults.string(forKey: "userName") ?? "Marin"
        engine.onEvent = { event in
            if event == .departed {
                // Visible departure: the recap window leaves with you and the
                // watcher starts collecting.
                Task { @MainActor in
                    recapWindow.hide()
                    watcher.start(departedAt: Date())
                }
                return
            }
            Task { @MainActor in
                let departedAt = watcher.departedAt
                let items = watcher.items
                watcher.stop()
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
                    await voiceReplies.listenAndHandle()
                case .returnRecap:
                    let freed = await calendarSource.freedSlotEvents()
                    let suggestion = SuggestionComposer.compose(
                        freedSlots: freed, profile: WellbeingProfile())
                    let session = RecapComposer.compose(
                        userName: userName.uppercased(),
                        departedAt: departedAt ?? Date(),
                        returnedAt: Date(),
                        items: items,
                        suggestion: suggestion)
                    voiceReplies.pendingSuggestion = suggestion
                    recapWindow.show(session: session)
                    await performer.perform(script: session.caption, withMusic: false)
                    await voiceReplies.listenAndHandle()
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
            Button("Ask Jarvis (voice)") {
                Task { await voiceReplies.listenAndHandle() }
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
