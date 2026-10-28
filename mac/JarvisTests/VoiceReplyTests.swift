import Testing
import Foundation
@testable import Jarvis

struct PhraseMatcherTests {
    @Test func matchesSendVariants() {
        #expect(PhraseMatcher.match("Send it") == .sendIt)
        #expect(PhraseMatcher.match("send") == .sendIt)          // ASR clips short
        #expect(PhraseMatcher.match("yeah, send it.") == .sendIt)
    }

    @Test func matchesHoldAndBlock() {
        #expect(PhraseMatcher.match("hold") == .hold)
        #expect(PhraseMatcher.match("Hold that") == .hold)
        #expect(PhraseMatcher.match("Block it!") == .blockIt)
    }

    @Test func matchesDismissals() {
        #expect(PhraseMatcher.match("thanks") == .dismiss)
        #expect(PhraseMatcher.match("That's all") == .dismiss)
        #expect(PhraseMatcher.match("") == .dismiss)
    }

    @Test func unknownPhrasesPassThroughForTheAgent() {
        #expect(PhraseMatcher.match("what's blocking MH-8?")
                == .other("what's blocking MH-8?"))
    }
}

struct ListeningWindowTests {
    func makeWindow() -> ListeningWindow {
        ListeningWindow(speechThreshold: 0.02, trailingSilence: 1.2,
                        maxDuration: 8, noSpeechTimeout: 4)
    }

    @Test func finishesAfterTrailingSilence() {
        var window = makeWindow()
        #expect(window.process(rms: 0.10, at: 0.5) == .keepListening)   // speech
        #expect(window.process(rms: 0.08, at: 1.0) == .keepListening)
        #expect(window.process(rms: 0.001, at: 1.5) == .keepListening)  // silence begins
        #expect(window.process(rms: 0.001, at: 2.8) == .finished)       // >1.2s silent
    }

    @Test func leadingSilenceIsNotTrailingSilence() {
        var window = makeWindow()
        #expect(window.process(rms: 0.001, at: 1.0) == .keepListening)
        #expect(window.process(rms: 0.001, at: 3.0) == .keepListening)  // still waiting
        #expect(window.process(rms: 0.10, at: 3.5) == .keepListening)   // speech starts late
        #expect(window.process(rms: 0.001, at: 5.0) == .finished)
    }

    @Test func timesOutWhenNobodySpeaks() {
        var window = makeWindow()
        #expect(window.process(rms: 0.001, at: 1.0) == .keepListening)
        #expect(window.process(rms: 0.001, at: 4.2) == .timedOutEmpty)
    }

    @Test func hardCapsLongSpeech() {
        var window = makeWindow()
        #expect(window.process(rms: 0.1, at: 0.2) == .keepListening)
        #expect(window.process(rms: 0.1, at: 8.3) == .finished)
    }
}

struct WAVEncoderTests {
    @Test func producesValidRIFFHeader() {
        let samples: [Int16] = Array(repeating: 1000, count: 1600)
        let data = WAVEncoder.encode(samples: samples, sampleRate: 16000)
        #expect(String(data: data.prefix(4), encoding: .ascii) == "RIFF")
        #expect(String(data: data.subdata(in: 8..<12), encoding: .ascii) == "WAVE")
        #expect(data.count == 44 + samples.count * 2)
    }
}
