import AppKit
import SwiftUI

@main
final class GazeGesturesApplication: NSObject, NSApplicationDelegate {
    private let appState = AppState()
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
        menuBarController = MenuBarController(
            appState: appState,
            onOpenSettings: { [weak self] in
                self?.openSettings()
            },
            onQuit: {
                NSApp.terminate(nil)
            }
        )
    }

    private func openSettings() {
        if let settingsWindowController {
            settingsWindowController.showWindow(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let settingsView = SettingsView(appState: appState)
        let hostingController = NSHostingController(rootView: settingsView)
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

@MainActor
final class AppState: ObservableObject {
    @Published var mode: AppMode = .idle
}

enum AppMode: String, CaseIterable, Identifiable {
    case idle = "Idle"
    case armed = "Armed"

    var id: String { rawValue }
}

final class MenuBarController {
    private let statusItem: NSStatusItem
    private let appState: AppState
    private let onOpenSettings: () -> Void
    private let onQuit: () -> Void

    init(
        appState: AppState,
        onOpenSettings: @escaping () -> Void,
        onQuit: @escaping () -> Void
    ) {
        self.appState = appState
        self.onOpenSettings = onOpenSettings
        self.onQuit = onQuit
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        configureStatusItem()
        rebuildMenu()
    }

    private func configureStatusItem() {
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "eye", accessibilityDescription: "Gaze Gestures")
            button.imagePosition = .imageLeading
            button.title = "Gaze"
        }
    }

    private func rebuildMenu() {
        let menu = NSMenu()

        let title = NSMenuItem(title: "Gaze Gestures", action: nil, keyEquivalent: "")
        title.isEnabled = false
        menu.addItem(title)

        let mode = NSMenuItem(title: "Mode: \(appState.mode.rawValue)", action: nil, keyEquivalent: "")
        mode.isEnabled = false
        menu.addItem(mode)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(
            title: "Settings...",
            action: #selector(openSettings),
            keyEquivalent: ","
        ))

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(
            title: "Quit Gaze Gestures",
            action: #selector(quit),
            keyEquivalent: "q"
        ))

        menu.items.forEach { $0.target = self }
        statusItem.menu = menu
    }

    @objc private func openSettings() {
        onOpenSettings()
    }

    @objc private func quit() {
        onQuit()
    }
}

struct SettingsView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Gaze Gestures")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Step 1: native menu bar app skeleton")
                    .foregroundStyle(.secondary)
            }

            Divider()

            LabeledContent("Current mode", value: appState.mode.rawValue)

            Picker("Development mode", selection: $appState.mode) {
                ForEach(AppMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            Text("This first slice proves the app lifecycle, menu bar controller, and settings window before camera, overlay, or gesture recognition are added.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
        }
        .padding(24)
        .frame(minWidth: 520, minHeight: 360)
    }
}
