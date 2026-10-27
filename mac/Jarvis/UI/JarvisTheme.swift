import SwiftUI

// Palette and type ramp from design 2a (Jarvis BLE Mockups).
enum Theme {
    static let bgDeep = Color(hex: 0x07090C)
    static let bgGlow = Color(hex: 0x0D1A20)
    static let cyan = Color(hex: 0x4FD1FF)
    static let cyanBright = Color(hex: 0x9BE6FF)
    static let text = Color(hex: 0xECEFF2)
    static let textDim = Color(hex: 0x8E96A1)
    static let textMeta = Color(hex: 0x9AA2AD)
    static let textFaint = Color(hex: 0x6F7782)
    static let amber = Color(hex: 0xF2B84B)
    static let card = Color(red: 17 / 255, green: 21 / 255, blue: 26 / 255).opacity(0.9)
    static let hairline = Color.white.opacity(0.06)

    // Design uses Barlow Condensed / Hanken Grotesk / JetBrains Mono; until the
    // fonts are bundled we use the closest system faces.
    static func display(_ size: CGFloat) -> Font {
        .system(size: size, weight: .semibold, design: .default)
    }
    static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
    static func body(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }
}
