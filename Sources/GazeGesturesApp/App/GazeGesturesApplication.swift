import AppKit
import SwiftUI

final class GazeGesturesApplication: NSObject, NSApplicationDelegate {
    private let singleInstanceLock: SingleInstanceLock
    private let coordinator = AppCoordinator(
        permissionProvider: SystemPermissionProvider(),
        hotkeyManager: HotkeyManager(),
        cameraSessionManager: CameraSessionManager(),
        handPresenceDetector: VisionHandPresenceDetector()
    )
    private lazy var overlayWindowController = OverlayWindowController(
        appState: coordinator.appState,
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
        coordinator.start()

        menuBarController = MenuBarController(
            appState: coordinator.appState,
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
        coordinator.stop()
        singleInstanceLock.release()
    }

    private func openSettings() {
        if let settingsWindowController {
            settingsWindowController.showWindow(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let hostingController = NSHostingController(
            rootView: SettingsView(
                appState: coordinator.appState,
                permissionActions: PermissionActions(
                    refresh: { [coordinator] in
                        coordinator.refreshPermissions()
                    },
                    requestCamera: { [coordinator] in
                        coordinator.requestCameraAccess()
                    },
                    requestAccessibility: { [coordinator] in
                        coordinator.requestAccessibilityTrust()
                    },
                    openCameraSettings: { [coordinator] in
                        coordinator.openSystemSettings(for: .camera)
                    },
                    openAccessibilitySettings: { [coordinator] in
                        coordinator.openSystemSettings(for: .accessibility)
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
}
