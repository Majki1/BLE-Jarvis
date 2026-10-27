import SwiftUI

@main
struct JarvisApp: App {
    @State private var status = JarvisStatus()

    var body: some Scene {
        MenuBarExtra("Jarvis", systemImage: status.symbol) {
            Text(status.headline)
            Divider()
            Button("Quit Jarvis") { NSApplication.shared.terminate(nil) }
        }
    }
}

// Placeholder session state — replaced by the presence engine (MH-3).
@MainActor @Observable
final class JarvisStatus {
    enum Presence { case unknown, present, away }
    var presence: Presence = .unknown

    var symbol: String {
        switch presence {
        case .unknown: "antenna.radiowaves.left.and.right"
        case .present: "person.fill.checkmark"
        case .away: "moon.zzz"
        }
    }

    var headline: String {
        switch presence {
        case .unknown: "Waiting for your iPhone…"
        case .present: "You're at your desk"
        case .away: "Away — watching your world"
        }
    }
}
