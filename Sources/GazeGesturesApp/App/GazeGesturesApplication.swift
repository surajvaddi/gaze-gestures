import AppKit
import SwiftUI

final class GazeGesturesApplication: NSObject, NSApplicationDelegate {
    private let singleInstanceLock: SingleInstanceLock
    private let appState = AppState()
    private let hotkeyManager: HotkeyManaging = HotkeyManager()
    private let permissionProvider: PermissionProviding = SystemPermissionProvider()
    private lazy var modeController = ModeController(
        appState: appState,
        permissionProvider: permissionProvider
    )
    private lazy var overlayWindowController = OverlayWindowController(
        appState: appState,
        onOpenSettings: { [weak self] in
            self?.openSettings()
        }
    )

    private var menuBarController: MenuBarController?
    private var settingsWindowController: NSWindowController?

    init(singleInstanceLock: SingleInstanceLock) {
        self.singleInstanceLock = singleInstanceLock
        super.init()
    }

    static func main() {
        let app = NSApplication.shared
        let lockIdentifier = Bundle.main.bundleIdentifier ?? "local.gazegestures.app"
        let singleInstanceLock = SingleInstanceLock(identifier: lockIdentifier)

        guard singleInstanceLock.acquire() else {
            return
        }

        let delegate = GazeGesturesApplication(singleInstanceLock: singleInstanceLock)

        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        modeController.refreshPermissions()

        hotkeyManager.onHotkey = { [weak self] hotkey in
            self?.handleHotkey(hotkey)
        }
        switch hotkeyManager.startListening() {
        case .success:
            break
        case .failure(let failure):
            appState.lastEventDescription = failure.userMessage
        }

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
        singleInstanceLock.release()
    }

    private func handleHotkey(_ hotkey: GlobalHotkey) {
        switch hotkey {
        case .activateGestureMode:
            modeController.activateGestureMode()
        case .emergencyExit:
            modeController.emergencyExit()
        }
    }

    private func openSettings() {
        if let settingsWindowController {
            settingsWindowController.showWindow(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let hostingController = NSHostingController(
            rootView: SettingsView(
                appState: appState,
                permissionActions: PermissionActions(
                    refresh: { [weak self] in
                        self?.refreshPermissions()
                    },
                    requestCamera: { [weak self] in
                        self?.requestCameraAccess()
                    },
                    requestAccessibility: { [weak self] in
                        self?.requestAccessibilityTrust()
                    },
                    openCameraSettings: { [weak self] in
                        self?.permissionProvider.openSystemSettings(for: .camera)
                    },
                    openAccessibilitySettings: { [weak self] in
                        self?.permissionProvider.openSystemSettings(for: .accessibility)
                    }
                )
            )
        )
        let window = NSWindow(contentViewController: hostingController)

        window.title = "Gaze Gestures Settings"
        window.setContentSize(NSSize(width: 560, height: 460))
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.center()
        window.isReleasedWhenClosed = false

        let controller = NSWindowController(window: window)
        settingsWindowController = controller
        controller.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func refreshPermissions() {
        modeController.refreshPermissions()
        appState.lastEventDescription = appState.permissions.summary
    }

    private func requestCameraAccess() {
        appState.lastEventDescription = "Requesting Camera permission"

        permissionProvider.requestCameraAccess { [weak self] snapshot in
            self?.appState.permissions = snapshot
            self?.appState.lastEventDescription = snapshot.summary
        }
    }

    private func requestAccessibilityTrust() {
        appState.permissions = permissionProvider.requestAccessibilityTrust()
        appState.lastEventDescription = appState.permissions.summary
    }
}
