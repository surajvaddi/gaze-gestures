# Gaze Gestures

Native macOS gesture-control utility, built in small testable slices.

## Development Step 1: App Skeleton

This step creates a minimal menu bar app with:

- a native macOS process lifecycle
- a menu bar status item
- a Settings window
- shared app state for future modes

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
        │   └── main.swift
        ├── MenuBar/
        │   └── MenuBarController.swift
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
