import SwiftUI
import AppKit

// Boundary calibration flow: claims the engine's raw sighting feed while
// open, shows live samples, applies the recommended hold threshold.
@MainActor
final class CalibrationWindowController {
    private var window: NSWindow?
    private let calibrator = RangeCalibrator()

    func show(engine: PresenceEngine) {
        calibrator.reset()
        engine.onRawSighting = { [calibrator] rssi in
            calibrator.addSample(rssi)
        }
        let view = CalibrationView(
            calibrator: calibrator,
            onApply: { [weak self] hold in
                UserDefaults.standard.set(hold, forKey: "holdRSSI")
                engine.updateThresholds(hold: hold)
                self?.close(engine: engine)
            },
            onReset: {
                UserDefaults.standard.removeObject(forKey: "holdRSSI")
                UserDefaults.standard.removeObject(forKey: "arriveRSSI")
                engine.updateThresholds(arrive: -60, hold: -80)
            },
            onClose: { [weak self] in self?.close(engine: engine) })

        let window = self.window ?? makeWindow()
        window.contentViewController = NSHostingController(rootView: view)
        window.setContentSize(NSSize(width: 460, height: 420))
        window.center()
        self.window = window
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    private func close(engine: PresenceEngine) {
        engine.onRawSighting = nil
        window?.orderOut(nil)
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 420),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered, defer: false)
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.backgroundColor = NSColor(Theme.bgDeep)
        return window
    }
}

struct CalibrationView: View {
    let calibrator: RangeCalibrator
    let onApply: (Int) -> Void
    let onReset: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Text("CALIBRATE AWAY BOUNDARY")
                .font(Theme.display(14))
                .kerning(2.8)
                .foregroundStyle(Theme.cyan)

            Text("Take your phone to where \u{201C}away\u{201D} should begin — the door, the hallway — and stand there while Jarvis listens to the signal.")
                .font(Theme.body(13))
                .foregroundStyle(Theme.textMeta)
                .multilineTextAlignment(.center)

            VStack(spacing: 6) {
                Text(calibrator.samples.last.map { "\($0) dBm" } ?? "—")
                    .font(Theme.mono(34, weight: .medium))
                    .foregroundStyle(Theme.text)
                    .contentTransition(.numericText())
                Text("\(calibrator.sampleCount) samples")
                    .font(Theme.mono(11))
                    .foregroundStyle(Theme.textDim)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))

            if let hold = calibrator.recommendedHoldThreshold {
                VStack(spacing: 4) {
                    Text("Recommended boundary: hold presence above \(hold) dBm")
                        .font(Theme.body(13, weight: .medium))
                        .foregroundStyle(Theme.text)
                    Text("Signals at your current spot will count as away.")
                        .font(Theme.body(12))
                        .foregroundStyle(Theme.textDim)
                }
                Button {
                    onApply(hold)
                } label: {
                    Text("Apply boundary")
                        .font(Theme.body(14, weight: .semibold))
                        .foregroundStyle(Color(hex: 0x06222C))
                        .padding(.vertical, 10).padding(.horizontal, 22)
                        .background(Theme.cyan, in: RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            } else {
                Text("Listening\u{2026} stay at the boundary for a few seconds.")
                    .font(Theme.body(12))
                    .foregroundStyle(Theme.textDim)
            }

            Spacer(minLength: 0)

            HStack {
                Button("Reset to defaults") { onReset() }
                    .buttonStyle(.plain)
                    .font(Theme.body(12))
                    .foregroundStyle(Theme.textDim)
                Spacer()
                Button("Close") { onClose() }
                    .buttonStyle(.plain)
                    .font(Theme.body(12, weight: .medium))
                    .foregroundStyle(Theme.text)
            }
        }
        .padding(28)
        .frame(minWidth: 460, minHeight: 420)
        .background(
            RadialGradient(colors: [Theme.bgGlow, Theme.bgDeep],
                           center: .init(x: 0.5, y: 0.2),
                           startRadius: 0, endRadius: 500))
    }
}
