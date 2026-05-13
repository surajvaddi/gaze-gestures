# Gaze Gestures

Native macOS gesture-control utility, built in small testable slices.

## Development Step 1: App Skeleton

This step creates a minimal menu bar app with:

- a native macOS process lifecycle
- a menu bar status item
- a Settings window
- shared app state for future modes

## Development Step 2: Hotkeys and Sticky Status Bar

This step adds:

- global activation hotkey: `Control + Option + Command + Space`
- global emergency exit hotkey: `Control + Option + Command + Escape`
- a top-center sticky liquid-glass status bar
- draggable status bar positioning
- visible mode and event feedback

The overlay receives mouse input only inside the bar so the user can drag it.

## Development Step 3A: Safety State Machine

This step adds structured activation routing without invoking real permission prompts yet:

- modes: `Idle`, `Blocked`, `Armed`
- placeholder permission snapshot
- mode controller for activation and emergency-exit decisions
- permission gate feedback in Settings and the glass bar

In this step, activation intentionally routes to `Blocked` because real permission checks arrive in Step 3B.

## Directory Layout

```text
gaze-gestures/
├── Package.swift
├── README.md
└── Sources/
    └── GazeGesturesApp/
        ├── App/
        │   ├── AppState.swift
        │   ├── GazeGesturesApplication.swift
        │   ├── ModeController.swift
        │   └── main.swift
        ├── Hotkeys/
        │   └── HotkeyManager.swift
        ├── MenuBar/
        │   └── MenuBarController.swift
        ├── Overlay/
        │   ├── LiquidGlassStatusBar.swift
        │   └── OverlayWindowController.swift
        ├── Permissions/
        │   └── PermissionProvider.swift
        └── Settings/
            └── SettingsView.swift
```

Run it with:

```sh
swift run GazeGestures
```

The app appears in the menu bar as `Gaze`.

Requires a working macOS Swift toolchain with AppKit and SwiftUI support.

## Principle

Start with a visible, controllable shell before adding camera input or gesture actions. This keeps each new capability testable and prevents hidden automation from appearing before the user can inspect or exit it.
