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

## Development Step 4: Phase 1A Safety Shell Hardening

This step tightens the existing shell before camera or gesture pipelines are added:

- permission bootstrap state renamed from placeholder to unknown
- development mode picker is compiled only in debug builds
- global hotkey registration now reports install or registration failures
- first Swift test target covers permission summaries, activation routing, emergency exit routing, and hotkey failure messages

Test result:

- `swift test` passes with 7 tests

## Development Step 5: Phase 2 App Bundle and Permission Identity

This step adds a repeatable local app-bundle flow for permission testing:

- `Scripts/build-app.sh` builds the Swift executable
- creates `dist/GestureGaze.app`
- embeds the GestureGaze `Info.plist`
- signs the app locally with ad-hoc signing
- verifies the app signature

Run the bundled app with:

```sh
Scripts/build-app.sh
open dist/GestureGaze.app
```

Use the bundled app for Camera and Accessibility permission testing. This gives
macOS a GestureGaze app identity instead of routing privacy prompts through
Terminal or `swift run`.

## Development Step 6: Phase 3 Coordinator Boundary

This step keeps app lifecycle wiring separate from control logic:

- `GazeGesturesApplication` owns AppKit windows, menu bar wiring, and app lifecycle
- `AppCoordinator` owns permission refresh, permission requests, hotkey routing, and mode transitions
- settings actions now route through the coordinator
- future camera, Vision, and action dispatch services can attach to the coordinator without bloating the application delegate

## Development Step 7: Phase 4 Overlay and Settings Resilience

This step prepares the UI shell for upcoming active modes:

- added future mode cases for hand gesture, gaze gesture, suspended, and emergency-exiting states
- centralized mode labels, permission labels, help text, and semantic tints in `AppPresentation`
- overlay status text and compact badges now truncate instead of expanding unpredictably
- settings permission coloring now uses the shared presentation mapping
- presentation tests cover current and future mode display behavior

## Development Step 8: Phase 5 Camera Session Foundation

This step adds camera lifecycle plumbing without Vision or gesture detection:

- added `CameraSessionManaging` and a real AVFoundation-backed `CameraSessionManager`
- app state now tracks camera session state separately from control mode
- coordinator starts the camera only after permission-gated activation succeeds
- blocked activation does not start the camera
- emergency exit and coordinator shutdown stop the camera
- camera failures return the app to idle and surface the failure message
- overlay and Settings show camera session state
- tests cover camera start, stop, blocked activation, state updates, and failure handling

## Planned Development Phases

### Phase 0: Baseline and Repo Hygiene

- preserve the current Step 3B shell as the baseline
- keep `.swiftpm/` out of source control
- keep README focused on implemented behavior
- keep the product spec as the forward-looking planning source
- verify `swift build`

### Phase 1: Safety Shell Hardening

- keep the single-instance guard active for both `swift run` and future bundled launches
- align the app mode model with the product spec before adding camera or gesture pipelines
- treat permission failure as activation status, not a long-term control mode
- make development-only controls debug-only
- handle hotkey registration failures explicitly
- add focused tests for permission and mode routing

### Phase 2: App Bundle and Permission Identity

- add a repeatable local `.app` packaging flow
- embed the GestureGaze `Info.plist` in the bundle
- sign the app for local development
- launch the bundled app for permission testing instead of relying on `swift run`
- acceptance target: Camera and Accessibility privacy entries appear for GestureGaze, not Terminal or the launching development tool

### Phase 3: Coordinator Boundary

- keep `GazeGesturesApplication` focused on AppKit lifecycle and window wiring
- introduce a coordinator for mode transitions, permissions, hotkeys, future camera lifecycle, and emergency exit cleanup
- define protocol boundaries for camera, Vision, and action dispatch services before implementing them

### Phase 4: Overlay and Settings Resilience

- centralize mode and permission display strings
- make overlay sizing resilient to longer status text
- add UI states for future hand, gaze, suspended, and emergency-exit modes

### Phase 5: Camera Session Foundation

- add camera lifecycle management
- start camera only after activation and granted permissions
- stop camera on idle, emergency exit, app termination, or failure
- preserve the rule that the camera is off while idle

### Phase 6: Vision Hand Presence

- add low-FPS Vision hand presence detection in armed mode
- transition from armed to hand mode only after stable hand presence
- return to idle after a no-hand timeout

### Phase 7: Pinch Cursor Without Actions

- extract thumb and index landmarks
- smooth and map pinch position to screen coordinates
- render a virtual cursor
- keep click, drag, scroll, and OS event dispatch disabled

### Phase 8: Temporal Classifier and Cooldowns

- add rolling observation buffers
- implement conservative pinch-state classification
- add cooldown and rejection reasons
- clear classifier state on cancel and emergency exit

### Phase 9: Safe Click Dispatch

- add guarded Accessibility or CGEvent dispatch
- enable only pinch-release left click
- require confidence, correct mode, stable cursor, and inactive cooldown

### Phase 10: Hand Mode Usability

- add drag, scroll, freeze, cancel, calibration, and replay fixtures
- expand settings only after the basic click path is trustworthy

### Phase 11: Experimental Gaze Mode

- keep gaze mode behind an explicit experimental setting
- add palm-flip toggle, coarse gaze target, gaze orb, and hand-confirmed gaze actions
- keep gaze disabled by default under low battery or constrained performance

## Directory Layout

```text
gaze-gestures/
├── Package.swift
├── README.md
├── Scripts/
│   └── build-app.sh
├── Tests/
│   └── GazeGesturesAppTests/
└── Sources/
    └── GazeGesturesApp/
        ├── App/
        │   ├── AppCoordinator.swift
        │   ├── AppPresentation.swift
        │   ├── AppState.swift
        │   ├── GazeGesturesApplication.swift
        │   ├── ModeController.swift
        │   ├── SingleInstanceLock.swift
        │   └── main.swift
        ├── Camera/
        │   └── CameraSessionManager.swift
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
