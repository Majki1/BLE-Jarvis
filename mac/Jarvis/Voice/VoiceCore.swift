import Foundation

enum VoiceCommand: Equatable {
    case sendIt
    case hold
    case blockIt
    case dismiss
    case other(String)
}

// Fast local matching for the short confirmations — no LLM round-trip for
// "send it". Anything unrecognized rides to the agent as a question.
enum PhraseMatcher {
    static func match(_ transcript: String) -> VoiceCommand {
        let cleaned = transcript.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.union(.whitespaces).inverted)
            .joined()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return .dismiss }
        // Whole words only — "blocking" must not match the "block" command.
        let words = Set(cleaned.split(separator: " ").map(String.init))
        let dismissPhrases = ["thanks", "thank you", "thats all", "never mind"]
        if dismissPhrases.contains(where: cleaned.contains)
            || !words.isDisjoint(with: ["nothing", "no"]) {
            return .dismiss
        }
        if words.contains("send") { return .sendIt }
        if words.contains("hold") { return .hold }
        if words.contains("block") { return .blockIt }
        return .other(transcript)
    }
}

// Decides when a listening session ends, from a stream of RMS levels.
struct ListeningWindow {
    enum Verdict: Equatable {
        case keepListening
        case finished
        case timedOutEmpty
    }

    private let speechThreshold: Float
    private let trailingSilence: TimeInterval
    private let maxDuration: TimeInterval
    private let noSpeechTimeout: TimeInterval

    // `time` values are seconds since the window opened.
    private var speechHeard = false
    private var lastSpeechAt: TimeInterval?

    init(speechThreshold: Float = 0.02, trailingSilence: TimeInterval = 1.2,
         maxDuration: TimeInterval = 8, noSpeechTimeout: TimeInterval = 4) {
        self.speechThreshold = speechThreshold
        self.trailingSilence = trailingSilence
        self.maxDuration = maxDuration
        self.noSpeechTimeout = noSpeechTimeout
    }

    mutating func process(rms: Float, at time: TimeInterval) -> Verdict {
        let elapsed = time

        if rms >= speechThreshold {
            speechHeard = true
            lastSpeechAt = time
        }

        if speechHeard {
            if elapsed >= maxDuration { return .finished }
            if let last = lastSpeechAt, time - last >= trailingSilence { return .finished }
            return .keepListening
        }
        return elapsed >= noSpeechTimeout ? .timedOutEmpty : .keepListening
    }
}

// Minimal 16-bit mono PCM → WAV container.
enum WAVEncoder {
    static func encode(samples: [Int16], sampleRate: Int) -> Data {
        let dataSize = samples.count * 2
        var data = Data(capacity: 44 + dataSize)

        func append(_ string: String) { data.append(Data(string.utf8)) }
        func append32(_ value: UInt32) { withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) } }
        func append16(_ value: UInt16) { withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) } }

        append("RIFF"); append32(UInt32(36 + dataSize)); append("WAVE")
        append("fmt "); append32(16); append16(1); append16(1)
        append32(UInt32(sampleRate)); append32(UInt32(sampleRate * 2))
        append16(2); append16(16)
        append("data"); append32(UInt32(dataSize))
        samples.withUnsafeBytes { data.append(contentsOf: $0) }
        return data
    }
}
