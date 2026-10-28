import Foundation
import AVFoundation

// Records one listening window from the default mic: 16 kHz mono PCM,
// stopping on trailing silence per ListeningWindow. Returns WAV data, or
// nil when nobody spoke.
@MainActor
final class MicRecorder {
    func record() async -> Data? {
        let engine = AVAudioEngine()
        let input = engine.inputNode
        let inputFormat = input.outputFormat(forBus: 0)
        let targetFormat = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 16000,
                                         channels: 1, interleaved: true)!
        guard let converter = AVAudioConverter(from: inputFormat, to: targetFormat) else {
            return nil
        }

        final class Capture: @unchecked Sendable {
            var samples: [Int16] = []
            var window = ListeningWindow()
            var verdict: ListeningWindow.Verdict = .keepListening
            let start = Date()
        }
        let capture = Capture() // touched only on the tap queue + awaited after stop

        input.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { buffer, _ in
            guard capture.verdict == .keepListening else { return }
            let frames = AVAudioFrameCount(
                Double(buffer.frameLength) * targetFormat.sampleRate / inputFormat.sampleRate)
            guard let converted = AVAudioPCMBuffer(pcmFormat: targetFormat,
                                                   frameCapacity: max(frames, 1)) else { return }
            var error: NSError?
            var fed = false
            converter.convert(to: converted, error: &error) { _, outStatus in
                if fed { outStatus.pointee = .noDataNow; return nil }
                fed = true
                outStatus.pointee = .haveData
                return buffer
            }
            guard error == nil, let channel = converted.int16ChannelData else { return }
            let count = Int(converted.frameLength)
            let chunk = Array(UnsafeBufferPointer(start: channel[0], count: count))
            capture.samples.append(contentsOf: chunk)

            let rms = sqrt(chunk.reduce(Float(0)) {
                let sample = Float($1) / 32768
                return $0 + sample * sample
            } / Float(max(count, 1)))
            capture.verdict = capture.window.process(
                rms: rms, at: Date().timeIntervalSince(capture.start))
        }

        do {
            try engine.start()
        } catch {
            presenceLog.info("mic start failed: \(error.localizedDescription)")
            return nil
        }
        while capture.verdict == .keepListening {
            try? await Task.sleep(for: .milliseconds(100))
        }
        input.removeTap(onBus: 0)
        engine.stop()

        guard capture.verdict == .finished, !capture.samples.isEmpty else { return nil }
        return WAVEncoder.encode(samples: capture.samples, sampleRate: 16000)
    }
}
