import AppKit
import SwiftUI

// Owns the main (recap) NSWindow so arrival events can summon it without
// SwiftUI scene plumbing. JARVIS_SNAPSHOT=<path> renders it once, writes a
// PNG, and exits — used for automated visual checks, never in normal runs.
@MainActor
final class RecapWindowController {
    private var window: NSWindow?

    func show(session: RecapSession) {
        let content = NSHostingController(rootView: JarvisMainView(session: session))
        let window = self.window ?? makeWindow()
        window.contentViewController = content
        window.setContentSize(NSSize(width: 960, height: 600))
        window.center()
        self.window = window
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    func hide() {
        window?.orderOut(nil)
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 960, height: 600),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered, defer: false)
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.backgroundColor = NSColor(Theme.bgDeep)
        return window
    }

    func snapshotIfRequested() {
        guard let path = ProcessInfo.processInfo.environment["JARVIS_SNAPSHOT"] else { return }
        show(session: .sample)
        Task { @MainActor in
            // Let the reveal sequence play most of the way in.
            try? await Task.sleep(for: .seconds(6))
            guard let view = window?.contentView,
                  let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else {
                exit(2)
            }
            view.cacheDisplay(in: view.bounds, to: rep)
            guard let png = rep.representation(using: .png, properties: [:]) else { exit(2) }
            try? png.write(to: URL(fileURLWithPath: path))
            exit(0)
        }
    }
}
