import Foundation

@MainActor
protocol MusicPlaying {
    func start()
    func duck()
    func unduck()
    func fadeOut()
}

@MainActor
protocol SpeechSynthesizing {
    func speak(_ text: String) async throws
}

// Orchestrates the cinematic moment: theme starts immediately (covering API
// latency upstream), voice enters after the lead-in over ducked music, music
// resolves at the end. Voice failures never leave the music hanging.
@MainActor
final class BriefingPerformer {
    private let music: MusicPlaying
    private let voice: SpeechSynthesizing
    private let leadIn: TimeInterval
    private let sleep: (TimeInterval) async -> Void

    init(music: MusicPlaying,
         voice: SpeechSynthesizing,
         leadIn: TimeInterval = 8,
         sleep: @escaping (TimeInterval) async -> Void = { seconds in
             try? await Task.sleep(for: .seconds(seconds))
         }) {
        self.music = music
        self.voice = voice
        self.leadIn = leadIn
        self.sleep = sleep
    }

    static let fallbackScript =
        "I couldn't assemble your briefing just now — my sources are out of " +
        "reach. The music was nice, though."

    func perform(script: String, withMusic: Bool = true) async {
        await perform(withMusic: withMusic) { script }
    }

    // Music starts instantly; the script (usually an LLM round-trip) is
    // produced under the lead-in so latency hides inside the intro bars.
    func perform(withMusic: Bool, scriptProvider: @escaping () async throws -> String) async {
        guard withMusic else {
            let script = (try? await scriptProvider()) ?? Self.fallbackScript
            try? await voice.speak(script)
            return
        }
        music.start()
        async let produced = Result { try await scriptProvider() }
        await sleep(leadIn)
        let script = (try? await produced.get()) ?? Self.fallbackScript
        music.duck()
        try? await voice.speak(script)
        music.unduck()
        music.fadeOut()
    }
}

private extension Result where Failure == Error {
    init(catching body: () async throws -> Success) async {
        do { self = .success(try await body()) }
        catch { self = .failure(error) }
    }
}
