import Foundation
import AVFoundation

// Plays the bundled intro theme ("intro-theme.wav", a synthesized placeholder
// generated for this project — swap the file to change the theme). Volume
// moves with short ramps so ducking feels mixed, not chopped.
@MainActor
final class ThemeMusicPlayer: MusicPlaying {
    private var player: AVAudioPlayer?
    private var fadeTask: Task<Void, Never>?

    private let fullVolume: Float = 0.9
    private let duckedVolume: Float = 0.25

    func start() {
        guard let url = Bundle.main.url(forResource: "intro-theme", withExtension: "wav") else {
            NSLog("ThemeMusicPlayer: intro-theme.wav missing from bundle")
            return
        }
        player = try? AVAudioPlayer(contentsOf: url)
        player?.volume = 0
        player?.play()
        ramp(to: fullVolume, over: 0.8)
    }

    func duck() { ramp(to: duckedVolume, over: 0.6) }
    func unduck() { ramp(to: fullVolume, over: 0.6) }

    func fadeOut() {
        ramp(to: 0, over: 2.5) { [weak self] in
            self?.player?.stop()
            self?.player = nil
        }
    }

    private func ramp(to target: Float, over duration: TimeInterval,
                      then completion: (() -> Void)? = nil) {
        fadeTask?.cancel()
        guard let player else { return }
        let start = player.volume
        let steps = max(1, Int(duration / 0.05))
        fadeTask = Task { [weak self] in
            for step in 1...steps {
                guard !Task.isCancelled else { return }
                try? await Task.sleep(for: .milliseconds(50))
                self?.player?.volume = start + (target - start) * Float(step) / Float(steps)
            }
            completion?()
        }
    }
}
