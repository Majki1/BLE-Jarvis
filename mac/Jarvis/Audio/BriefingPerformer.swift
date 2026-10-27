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

    func perform(script: String, withMusic: Bool = true) async {
        guard withMusic else {
            try? await voice.speak(script)
            return
        }
        music.start()
        await sleep(leadIn)
        music.duck()
        try? await voice.speak(script)
        music.unduck()
        music.fadeOut()
    }
}
