import SwiftUI

// Main window, design 2a: orb speaks on the left; each recap card lands on
// the right as it's mentioned.
struct JarvisMainView: View {
    let session: RecapSession
    @State private var revealedCards = 0
    @State private var typedCaption = ""

    var body: some View {
        HStack(spacing: 0) {
            leftColumn
                .frame(width: 360)
                .overlay(alignment: .trailing) {
                    Rectangle().fill(Theme.hairline).frame(width: 1)
                }
            rightColumn
        }
        .frame(minWidth: 960, minHeight: 600)
        .background(
            RadialGradient(colors: [Theme.bgGlow, Theme.bgDeep],
                           center: .init(x: 0.2, y: 0.45),
                           startRadius: 0, endRadius: 700))
        .task { await revealSequence() }
    }

    // MARK: Left — orb, caption, voice pill

    private var leftColumn: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Text("WELCOME BACK, \(session.userName)")
                    .font(Theme.display(15))
                    .kerning(3.3)
                    .foregroundStyle(Theme.cyan)
                Text(session.awaySummary)
                    .font(Theme.mono(11))
                    .foregroundStyle(Theme.textDim)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            OrbView()
                .padding(.top, 62)

            WaveformView()
                .padding(.top, 72)

            (Text(typedCaption) + Text("▍").foregroundStyle(Theme.cyan))
                .font(Theme.body(18))
                .lineSpacing(5)
                .foregroundStyle(Theme.text)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.top, 22)

            Spacer(minLength: 16)

            HStack(spacing: 10) {
                PulsingDot()
                Text("Say \u{201C}send it\u{201D} or \u{201C}hold\u{201D}")
                    .font(Theme.body(13, weight: .medium))
                    .foregroundStyle(Theme.text)
            }
            .padding(.vertical, 9)
            .padding(.leading, 10)
            .padding(.trailing, 14)
            .background(Theme.cyan.opacity(0.1), in: Capsule())
            .overlay(Capsule().stroke(Theme.cyan.opacity(0.3), lineWidth: 1))
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 28)
    }

    // MARK: Right — stats + card grid

    private var rightColumn: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                HStack(spacing: 18) {
                    stat(session.handled, "handled", Theme.text)
                    stat(session.drafts, "drafts", Theme.text)
                    stat(session.needsYou, "needs you", Theme.amber)
                }
                Spacer()
                HStack(spacing: 7) {
                    Circle().fill(Theme.cyan).frame(width: 6, height: 6)
                    Text(brainBadge)
                        .font(Theme.mono(11))
                        .foregroundStyle(Color(hex: 0xAAB2BC))
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 10)
                .background(Color.white.opacity(0.05), in: Capsule())
                .overlay(Capsule().stroke(Color.white.opacity(0.07), lineWidth: 1))
            }

            // Cards with inline actions span the full row (mockup's
            // grid-column span); the rest flow in two columns.
            let wide = session.cards.filter { $0.actions != nil }
            let narrow = session.cards.filter { $0.actions == nil }
            ForEach(Array(wide.enumerated()), id: \.element.id) { index, card in
                RecapCardView(card: card)
                    .opacity(index < revealedCards ? 1 : 0)
                    .offset(y: index < revealedCards ? 0 : 14)
            }
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible())],
                      alignment: .leading, spacing: 12) {
                ForEach(Array(narrow.enumerated()), id: \.element.id) { index, card in
                    RecapCardView(card: card)
                        .opacity(index + wide.count < revealedCards ? 1 : 0)
                        .offset(y: index + wide.count < revealedCards ? 0 : 14)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 28)
    }

    private var brainBadge: String {
        ProcessInfo.processInfo.environment["JARVIS_LLM_API_KEY"] != nil
            ? "Spark Open · Baseten" : "Muse Spark · Meta API"
    }

    private func stat(_ value: Int, _ label: String, _ color: Color) -> some View {
        HStack(spacing: 4) {
            Text("\(value)").foregroundStyle(color)
            Text(label).foregroundStyle(Theme.textDim)
        }
        .font(Theme.mono(12))
    }

    private func revealSequence() async {
        for character in session.caption {
            typedCaption.append(character)
            try? await Task.sleep(for: .milliseconds(28))
        }
        for i in 1...session.cards.count {
            withAnimation(.smooth(duration: 0.5)) { revealedCards = i }
            try? await Task.sleep(for: .milliseconds(450))
        }
    }
}

struct RecapCardView: View {
    let card: RecapCard

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 10) {
                Text(card.kind.rawValue)
                    .font(Theme.mono(10.5, weight: .medium))
                    .foregroundStyle(card.accent)
                    .frame(width: 24, height: 24)
                    .background(Color.white.opacity(0.06),
                                in: RoundedRectangle(cornerRadius: 7))
                Text(card.label)
                    .font(Theme.mono(11, weight: .medium))
                    .kerning(1.1)
                    .foregroundStyle(Theme.textDim)
                Spacer()
                Text(card.time)
                    .font(Theme.mono(11))
                    .foregroundStyle(Theme.textFaint)
            }
            Text(card.title)
                .font(Theme.body(16, weight: .medium))
                .foregroundStyle(Theme.text)
            Text(card.meta)
                .font(Theme.body(13))
                .lineSpacing(3)
                .foregroundStyle(Theme.textMeta)
            if let actions = card.actions {
                HStack(spacing: 8) {
                    Text(actions.primary)
                        .font(Theme.body(13, weight: .semibold))
                        .foregroundStyle(Color(hex: 0x06222C))
                        .fixedSize()
                        .padding(.vertical, 8).padding(.horizontal, 14)
                        .background(Theme.cyan, in: RoundedRectangle(cornerRadius: 8))
                    Text(actions.secondary)
                        .font(Theme.body(13, weight: .medium))
                        .foregroundStyle(Theme.text)
                        .fixedSize()
                        .padding(.vertical, 8).padding(.horizontal, 14)
                        .background(Color.white.opacity(0.06),
                                    in: RoundedRectangle(cornerRadius: 8))
                    Text("or just say it")
                        .font(Theme.mono(12))
                        .foregroundStyle(Theme.textDim)
                        .fixedSize()
                        .padding(.leading, 2)
                }
                .padding(.top, 2)
            }
        }
        .padding(16)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(card.needsYou ? Theme.amber.opacity(0.5) : Color.white.opacity(0.07),
                        lineWidth: 1))
    }
}

private struct PulsingDot: View {
    var body: some View {
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let pulse = 0.5 + 0.5 * sin(t * 2 * .pi / 1.4)
            Circle()
                .stroke(Theme.cyan, lineWidth: 2)
                .frame(width: 18, height: 18)
                .opacity(0.5 + 0.5 * pulse)
        }
    }
}
