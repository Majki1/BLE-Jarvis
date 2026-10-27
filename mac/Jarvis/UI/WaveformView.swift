import SwiftUI

// 28 slim bars pulsing in a travelling wave while the orb "speaks".
struct WaveformView: View {
    var active = true

    var body: some View {
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            HStack(alignment: .center, spacing: 3) {
                ForEach(0..<28, id: \.self) { i in
                    let phase = t * 2 * .pi / 1.1 - Double(i) * 0.45
                    let wave = active ? (0.5 + 0.5 * sin(phase)) : 0.15
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Theme.cyan)
                        .opacity(0.35 + 0.6 * wave)
                        .frame(width: 3, height: 6 + 22 * wave)
                }
            }
        }
        .frame(height: 32)
    }
}
