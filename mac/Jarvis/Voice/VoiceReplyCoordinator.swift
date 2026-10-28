import Foundation
import AppKit

// One voice round after each spoken moment: chime → listen → transcribe →
// quick-match or hand the question to the agent and speak its answer.
@MainActor
final class VoiceReplyCoordinator {
    private let voice: SpeechSynthesizing
    private let recorder = MicRecorder()
    private let transcriber = TranscribeClient()

    init(voice: SpeechSynthesizing) {
        self.voice = voice
    }

    func listenAndHandle() async {
        NSSound(named: "Pop")?.play()
        guard let wav = await recorder.record() else { return }
        guard let transcript = try? await transcriber.transcribe(wav: wav),
              !transcript.isEmpty else { return }
        presenceLog.info("voice heard: \(transcript)")

        switch PhraseMatcher.match(transcript) {
        case .dismiss:
            return
        case .sendIt, .hold, .blockIt:
            // Draft/block actions land with MH-18; acknowledge honestly.
            try? await voice.speak("Noted. That action unlocks with the next build.")
        case .other(let question):
            guard let agent = JarvisAgent.make() else { return }
            let reply = (try? await agent.run(question))
                ?? "I couldn't reach my brain for that one."
            try? await voice.speak(reply)
        }
    }
}
