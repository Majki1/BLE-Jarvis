import Foundation
import AVFoundation

// ElevenLabs is the demo voice; the system synthesizer keeps the app working
// with no API key (and is the fallback if ElevenLabs is unreachable).
@MainActor
final class ElevenLabsSynthesizer: SpeechSynthesizing {
    struct MissingAPIKey: Error {}

    private let voiceID: String
    private let fallback: SpeechSynthesizing

    init(voiceID: String = "pNInz6obpgDQGcFmaJgB",
         fallback: SpeechSynthesizing) {
        self.voiceID = voiceID
        self.fallback = fallback
    }

    static var apiKey: String? {
        ProcessInfo.processInfo.environment["ELEVENLABS_API_KEY"]
            ?? UserDefaults.standard.string(forKey: "elevenLabsAPIKey")
    }

    func speak(_ text: String) async throws {
        do {
            guard let key = Self.apiKey else { throw MissingAPIKey() }
            let data = try await synthesize(text: text, key: key)
            try await AudioClipPlayer.shared.play(data: data)
        } catch {
            NSLog("ElevenLabs unavailable (\(error)) — falling back to system voice")
            try await fallback.speak(text)
        }
    }

    private func synthesize(text: String, key: String) async throws -> Data {
        var request = URLRequest(
            url: URL(string: "https://api.elevenlabs.io/v1/text-to-speech/\(voiceID)")!)
        request.httpMethod = "POST"
        request.setValue(key, forHTTPHeaderField: "xi-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("audio/mpeg", forHTTPHeaderField: "Accept")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "text": text,
            "model_id": "eleven_turbo_v2_5",
        ])
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return data
    }
}

// Plays one audio clip and completes when playback ends.
@MainActor
final class AudioClipPlayer: NSObject, AVAudioPlayerDelegate {
    static let shared = AudioClipPlayer()

    private var player: AVAudioPlayer?
    private var continuation: CheckedContinuation<Void, Error>?

    func play(data: Data) async throws {
        player?.stop()
        let player = try AVAudioPlayer(data: data)
        self.player = player
        player.delegate = self
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            player.play()
        }
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.continuation?.resume()
            self.continuation = nil
        }
    }
}

@MainActor
final class SystemSynthesizer: NSObject, SpeechSynthesizing, AVSpeechSynthesizerDelegate {
    private let synthesizer = AVSpeechSynthesizer()
    private var continuation: CheckedContinuation<Void, Never>?

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func speak(_ text: String) async throws {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-GB")
        utterance.rate = 0.48
        await withCheckedContinuation { continuation in
            self.continuation = continuation
            synthesizer.speak(utterance)
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                                       didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.continuation?.resume()
            self.continuation = nil
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                                       didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.continuation?.resume()
            self.continuation = nil
        }
    }
}
