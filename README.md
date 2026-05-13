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

## Development Step 3B: Real Permission Checks

This step replaces placeholder permission state with real macOS checks:

- camera authorization status via AVFoundation
- Accessibility trust status via ApplicationServices
- Settings controls to request Camera access, request Accessibility trust, open Privacy panes, and refresh state
- activation guard that enters `Armed` only when Camera and Accessibility are both granted
- single-instance guard so duplicate launches exit immediately

Test result:

- missing permissions route activation to `Blocked`
- the glass bar and Settings window show the specific missing permission statuses
- granted Camera and Accessibility permissions allow activation to enter `Armed`
- the emergency exit hotkey still returns immediately to `Idle`
- a second launch exits instead of creating another menu bar app instance

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

For Step 3B permission testing, rebuild before running so the executable includes
the embedded camera usage description:

```sh
swift build
swift run GazeGestures
```

Camera can be requested from Settings. Accessibility is granted in macOS System
Settings after pressing `Request Trust` or `Open Settings`.

During development, launching through `swift run` can make macOS privacy panes
show the launching tool or Terminal instead of a standalone GestureGaze entry.
For permissions to belong directly to GestureGaze, run it as a signed `.app`
bundle with the GestureGaze bundle identifier and embedded `Info.plist`.

## Principle

Start with a visible, controllable shell before adding camera input or gesture actions. This keeps each new capability testable and prevents hidden automation from appearing before the user can inspect or exit it.
