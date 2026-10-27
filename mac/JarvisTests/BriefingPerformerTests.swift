import Testing
import Foundation
@testable import Jarvis

@MainActor
struct BriefingPerformerTests {
    final class Log {
        var calls: [String] = []
        var sleeps: [TimeInterval] = []
    }

    final class FakeMusic: MusicPlaying {
        let log: Log
        init(log: Log) { self.log = log }
        func start() { log.calls.append("music.start") }
        func duck() { log.calls.append("music.duck") }
        func unduck() { log.calls.append("music.unduck") }
        func fadeOut() { log.calls.append("music.fadeOut") }
    }

    final class FakeVoice: SpeechSynthesizing {
        let log: Log
        var error: Error?
        init(log: Log) { self.log = log }
        func speak(_ text: String) async throws {
            log.calls.append("voice.speak(\(text))")
            if let error { throw error }
        }
    }

    func makePerformer(leadIn: TimeInterval = 8) -> (BriefingPerformer, Log, FakeVoice) {
        let log = Log()
        let voice = FakeVoice(log: log)
        let performer = BriefingPerformer(
            music: FakeMusic(log: log),
            voice: voice,
            leadIn: leadIn,
            sleep: { log.sleeps.append($0) })
        return (performer, log, voice)
    }

    @Test func performsMusicDuckSpeakResolveInOrder() async {
        let (performer, log, _) = makePerformer()
        await performer.perform(script: "Good morning")
        #expect(log.calls == [
            "music.start",
            "music.duck",
            "voice.speak(Good morning)",
            "music.unduck",
            "music.fadeOut",
        ])
    }

    @Test func waitsLeadInBeforeSpeaking() async {
        let (performer, log, _) = makePerformer(leadIn: 10)
        await performer.perform(script: "Hi")
        #expect(log.sleeps.first == 10)
    }

    @Test func voiceFailureStillResolvesMusic() async {
        let (performer, log, voice) = makePerformer()
        voice.error = URLError(.notConnectedToInternet)
        await performer.perform(script: "Hi")
        #expect(log.calls.last == "music.fadeOut")
    }

    @Test func musiclessPerformSpeaksImmediately() async {
        let (performer, log, _) = makePerformer()
        await performer.perform(script: "Quick note", withMusic: false)
        #expect(log.calls == ["voice.speak(Quick note)"])
        #expect(log.sleeps.isEmpty)
    }
}
