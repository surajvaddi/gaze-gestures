import AppKit
import SwiftUI

final class OverlayWindowController {
    private let appState: AppState
    private var window: NSWindow?

    init(appState: AppState) {
        self.appState = appState
    }

    func show() {
        if let window {
            window.orderFrontRegardless()
            return
        }

        let hostingController = NSHostingController(rootView: LiquidGlassStatusBar(appState: appState))
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 54),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        window.contentViewController = hostingController
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = false
        window.isMovableByWindowBackground = true
        window.level = .floating
        window.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .stationary
        ]

        self.window = window
        position(window)
        window.orderFrontRegardless()
    }

    private func position(_ window: NSWindow) {
        guard let screen = NSScreen.main else { return }

        let frame = screen.visibleFrame
        let size = window.frame.size
        let x = frame.midX - size.width / 2
        let y = frame.maxY - size.height - 12

        window.setFrameOrigin(NSPoint(x: x, y: y))
    }
}
