import AppKit
import SwiftUI

final class GazeGesturesApplication: NSObject, NSApplicationDelegate {
    private let appState = AppState()
    private let hotkeyManager: HotkeyManaging = HotkeyManager()
    private lazy var overlayWindowController = OverlayWindowController(appState: appState)

    private var menuBarController: MenuBarController?
    private var settingsWindowController: NSWindowController?

    static func main() {
        let app = NSApplication.shared
        let delegate = GazeGesturesApplication()

        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        hotkeyManager.onHotkey = { [weak self] hotkey in
            self?.handleHotkey(hotkey)
        }
        hotkeyManager.startListening()

        menuBarController = MenuBarController(
            appState: appState,
            onOpenSettings: { [weak self] in
                self?.openSettings()
            },
            onQuit: {
                NSApp.terminate(nil)
            }
        )

        overlayWindowController.show()
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotkeyManager.stopListening()
    }

    private func handleHotkey(_ hotkey: GlobalHotkey) {
        switch hotkey {
        case .activateGestureMode:
            appState.activateGestureMode()
        case .emergencyExit:
            appState.emergencyExit()
        }
    }

    private func openSettings() {
        if let settingsWindowController {
            settingsWindowController.showWindow(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let hostingController = NSHostingController(rootView: SettingsView(appState: appState))
        let window = NSWindow(contentViewController: hostingController)

        window.title = "Gaze Gestures Settings"
        window.setContentSize(NSSize(width: 520, height: 360))
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.center()
        window.isReleasedWhenClosed = false

        let controller = NSWindowController(window: window)
        settingsWindowController = controller
        controller.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
