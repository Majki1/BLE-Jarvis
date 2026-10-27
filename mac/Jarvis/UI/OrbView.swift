import SwiftUI

// The Jarvis orb (design 2a): two counter-rotating blurred conic layers over
// a white core, breathing slowly, ringed by faint static circles.
struct OrbView: View {
    var body: some View {
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let breathe = 1 + 0.04 * sin(t * 2 * .pi / 3.2)

            ZStack {
                Circle()
                    .stroke(Theme.cyan.opacity(0.12), lineWidth: 1)
                    .padding(-26)
                Circle()
                    .stroke(Theme.cyan.opacity(0.05), lineWidth: 1)
                    .padding(-52)

                ZStack {
                    AngularGradient(
                        colors: [Theme.cyan, Color(hex: 0x1E5BFF), Color(hex: 0x7DE9FF),
                                 Color(hex: 0x0A3B52), Theme.cyan],
                        center: .center)
                        .clipShape(Circle())
                        .blur(radius: 20)
                        .opacity(0.85)
                        .rotationEffect(.radians(t * 2 * .pi / 9))

                    AngularGradient(
                        colors: [Color(hex: 0xC9F4FF), Theme.cyan, Color(hex: 0x123D5A),
                                 Theme.cyanBright, Color(hex: 0xC9F4FF)],
                        center: .center)
                        .clipShape(Circle())
                        .blur(radius: 9)
                        .opacity(0.7)
                        .padding(22)
                        .rotationEffect(.radians(-t * 2 * .pi / 6))

                    RadialGradient(
                        colors: [.white, Color(hex: 0xBFF0FF), Theme.cyan.opacity(0)],
                        center: .center, startRadius: 0, endRadius: 33)
                        .clipShape(Circle())
                        .padding(52)
                }
                .scaleEffect(breathe)
            }
        }
        .frame(width: 170, height: 170)
    }
}
