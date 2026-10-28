import Foundation
import AppKit

// One voice round after each spoken moment: chime → listen → transcribe →
// quick-match or hand the question to the agent and speak its answer.
@MainActor
final class VoiceReplyCoordinator {
    private let voice: SpeechSynthesizing
    private let recorder = MicRecorder()
    private let transcriber = TranscribeClient()
    private let profile = WellbeingProfile()

    // Set by the recap flow when a life-defense suggestion is on screen.
    var pendingSuggestion: Suggestion?
    var transcript: TranscriptStore?

    init(voice: SpeechSynthesizing) {
        self.voice = voice
    }

    func listenAndHandle() async {
        NSSound(named: "Pop")?.play()
        guard let wav = await recorder.record() else { return }
        guard let transcript = try? await transcriber.transcribe(wav: wav),
              !transcript.isEmpty else { return }
        presenceLog.info("voice heard: \(transcript)")
        self.transcript?.record(kind: .voice, title: "You said: \(transcript)", meta: "")

        switch PhraseMatcher.match(transcript) {
        case .dismiss:
            if let suggestion = pendingSuggestion {
                profile.recordSkipped(goal: suggestion.goal)
                pendingSuggestion = nil
            }
            return
        case .blockIt:
            guard let suggestion = pendingSuggestion else {
                try? await voice.speak("Nothing on the table to block right now.")
                return
            }
            let blocked = await GoogleCalendarAPI.insertEvent(
                title: suggestion.blockTitle,
                start: suggestion.slot.start, end: suggestion.slot.end)
            if blocked {
                profile.recordKept(goal: suggestion.goal)
                pendingSuggestion = nil
                self.transcript?.record(kind: .life, title: "Blocked: \(suggestion.blockTitle)",
                                        meta: "written to your calendar")
                try? await voice.speak("Done — \(suggestion.blockTitle) is on your calendar. Defend it.")
            } else {
                try? await voice.speak("I couldn't reach your calendar — try me again in a minute.")
            }
        case .sendIt, .hold:
            // Draft actions arrive with the draft system; acknowledge honestly.
            try? await voice.speak("Noted. That action unlocks with the next build.")
        case .other(let question):
            guard let agent = JarvisAgent.make() else { return }
            let reply = (try? await agent.run(question))
                ?? "I couldn't reach my brain for that one."
            self.transcript?.record(kind: .voice, title: "Jarvis: \(String(reply.prefix(80)))",
                                    meta: "")
            try? await voice.speak(reply)
        }
    }
}
