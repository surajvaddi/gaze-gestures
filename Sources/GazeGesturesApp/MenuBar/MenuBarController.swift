import AppKit
import Combine

final class MenuBarController {
    private let statusItem: NSStatusItem
    private let appState: AppState
    private let onOpenSettings: () -> Void
    private let onQuit: () -> Void
    private var cancellables: Set<AnyCancellable> = []

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
        observeState()
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

    private func observeState() {
        appState.$mode
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.rebuildMenu()
            }
            .store(in: &cancellables)
    }

    @objc private func openSettings() {
        onOpenSettings()
    }

    @objc private func quit() {
        onQuit()
    }
}
