import Foundation

// Muse Voice Transcribe (Meta Model API): POST /v1/asr/transcribe,
// multipart with a JSON `request` part and the WAV `audio` part.
@MainActor
final class TranscribeClient {
    struct NotConfigured: Error {}
    struct TranscribeFailed: Error { let detail: String }

    static var apiKey: String? {
        ProcessInfo.processInfo.environment["META_API_KEY"]
            ?? UserDefaults.standard.string(forKey: "metaAPIKey")
    }

    func transcribe(wav: Data) async throws -> String {
        guard let key = Self.apiKey else { throw NotConfigured() }
        let boundary = "jarvis-\(UUID().uuidString)"
        var request = URLRequest(url: URL(string: "https://api.meta.ai/v1/asr/transcribe")!)
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("multipart/form-data; boundary=\(boundary)",
                         forHTTPHeaderField: "Content-Type")

        var body = Data()
        func part(_ string: String) { body.append(Data(string.utf8)) }
        part("--\(boundary)\r\n")
        part("Content-Disposition: form-data; name=\"request\"\r\n")
        part("Content-Type: application/json\r\n\r\n")
        part(#"{"model":"muse-voice-transcribe-1.0","audioEncoding":"WAV","mode":"PUSH_TO_TALK"}"#)
        part("\r\n--\(boundary)\r\n")
        part("Content-Disposition: form-data; name=\"audio\"; filename=\"reply.wav\"\r\n")
        part("Content-Type: audio/wav\r\n\r\n")
        body.append(wav)
        part("\r\n--\(boundary)--\r\n")
        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw TranscribeFailed(detail: String(data: data, encoding: .utf8).map {
                String($0.prefix(300)) } ?? "transcribe failed")
        }
        struct Reply: Decodable { let transcript: String }
        return try JSONDecoder().decode(Reply.self, from: data).transcript
    }
}
