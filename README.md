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

#### Phase 11 Gaze Detection Specification

Phase 11 adds gaze as an experimental target-selection layer. It must not replace
the hand cursor or become a direct mouse pointer in its first release. Gaze selects
a coarse target or region; deliberate hand gestures confirm actions.

##### Product Rules

- gaze mode is disabled by default
- gaze mode requires an explicit experimental setting
- gaze mode requires camera and Accessibility permissions
- gaze mode requires successful gaze calibration before actions are enabled
- gaze tracking runs only while the app is active and in `gazeGesture`
- gaze actions require hand confirmation
- gaze must be disabled automatically in low-battery or constrained-performance states
- emergency exit stops gaze tracking, hides the gaze orb, clears gaze buffers, and returns to `Idle`

##### Non-Goals

- do not treat webcam gaze as pixel-perfect mouse control
- do not dispatch actions from gaze alone
- do not run always-on face or gaze tracking
- do not store raw camera frames by default
- do not enable destructive actions through a single gaze-confirmed gesture

##### Core Types

Planned domain types:

```swift
enum GazeDetectionState: Equatable {
    case idle
    case calibrationRequired
    case calibrating
    case looking
    case tracking
    case lowConfidence
    case locked
    case failed(String)
}

struct GazeObservation: Equatable {
    var faceConfidence: Double
    var eyeConfidence: Double
    var headPoseConfidence: Double
    var rawCameraPoint: UnitPoint?
    var rawScreenPoint: CGPoint?
    var calibratedScreenPoint: CGPoint?
    var smoothedScreenPoint: CGPoint?
    var coarseRegion: GazeRegion
    var stabilityScore: Double
    var dwellDuration: TimeInterval
    var timestamp: TimeInterval
}

enum GazeRegion: Equatable {
    case unknown
    case topLeft
    case topCenter
    case topRight
    case centerLeft
    case center
    case centerRight
    case bottomLeft
    case bottomCenter
    case bottomRight
}

struct GazeCalibrationProfile: Equatable, Codable {
    var screenID: String
    var createdAt: Date
    var points: [GazeCalibrationPoint]
    var qualityScore: Double
    var mappingVersion: Int
}
```

##### Protocol Boundaries

Planned protocols:

```swift
protocol GazeDetecting: AnyObject {
    var onObservation: ((GazeObservation) -> Void)? { get set }

    func startDetection(profile: GazeCalibrationProfile?)
    func stopDetection()
    func process(_ frame: CameraFrame)
}

protocol GazeCalibrating: AnyObject {
    var onProgress: ((GazeCalibrationProgress) -> Void)? { get set }

    func beginCalibration(screenFrame: CGRect)
    func recordSample(for target: GazeCalibrationTarget, frame: CameraFrame)
    func finishCalibration() -> Result<GazeCalibrationProfile, GazeCalibrationError>
    func resetCalibration()
}

protocol GazeSmoothing {
    func smooth(_ observation: GazeObservation) -> GazeObservation
    func reset()
}
```

##### Detection Pipeline

1. Activation hotkey enters `Armed`.
2. Stable hand presence enters `handGesture`.
3. Palm flip toggles experimental gaze mode only when enabled in Settings.
4. Coordinator verifies calibration exists and power policy allows gaze tracking.
5. Camera frames are routed to the gaze detector.
6. Vision face/eye landmarks produce raw face, eye, and head-pose signals.
7. Raw signals map to a coarse gaze region first.
8. If calibration exists, raw gaze maps to a calibrated screen point.
9. Smoothing converts raw/calibrated points into a stable target.
10. Target snapping may bias the gaze orb toward nearby interactable UI targets.
11. Hand gestures confirm actions at the current gaze target.

##### Calibration Flow

Calibration is mandatory before gaze actions are enabled.

```text
1. Show calibration overlay.
2. Ask the user to look at 9 screen targets.
3. Collect multiple face/eye samples per target.
4. Reject samples with low face or eye confidence.
5. Compute coarse-region and screen-point mapping.
6. Save calibration profile locally.
7. Require recalibration when screen layout or camera position changes significantly.
```

Calibration quality gates:

- minimum 9 targets completed
- minimum 5 accepted samples per target
- face confidence must be at least 0.70
- eye confidence must be at least 0.65
- calibration quality score must be at least 0.75
- failed calibration leaves gaze mode disabled and shows a reset/retry path

##### Confidence And Safety Gates

Gaze observations are actionable only when:

- mode is `gazeGesture`
- experimental gaze setting is enabled
- calibration profile is valid
- power policy allows gaze tracking
- face confidence is at least 0.70
- eye confidence is at least 0.65
- stability score is at least 0.70
- no emergency exit is active
- action is confirmed by a hand gesture
- cooldown allows the action

Low-confidence behavior:

- fade the gaze orb
- keep the last stable target briefly
- block new actions
- return to `looking` if confidence remains low
- exit gaze mode after sustained tracking loss

##### Gaze Orb UI States

Planned overlay states:

```swift
enum GazeOrbState: Equatable {
    case hidden
    case calibrationRequired
    case searching
    case tracking(confidence: Double)
    case lowConfidence
    case locked
    case confirming
    case cooldown
    case failed(String)
}
```

Display rules:

- hidden outside `gazeGesture`
- searching while face or eyes are not stable
- tracking when a smoothed target exists
- low confidence when signals drop below thresholds
- locked when fist lock is active
- confirming when a hand gesture is being used to act on the target
- cooldown after a dispatched action

##### Actions

Gaze mode actions are target selection plus hand confirmation:

| Input | Gaze Mode Meaning |
|---|---|
| Palm flip | Exit gaze mode |
| Pinch tap | Click at gaze target |
| Pinch hold | Prepare drag from gaze target |
| Pinch hold and move | Drag from locked gaze target |
| Swipe up or down | Scroll near gaze target |
| Fist | Lock or unlock gaze target |
| Open palm | Cancel current gaze action |

All actions must pass the existing gesture-router safety rules, cooldowns, and
destructive-confirmation requirements.

##### Settings

Planned Settings entries:

- Enable experimental gaze mode
- Require calibration
- Start gaze calibration
- Reset gaze calibration
- Gaze smoothing: Conservative, Normal, Responsive
- Gaze orb size: Small, Medium, Large
- Disable gaze on low battery
- Show gaze confidence indicator

##### Tests Required Before Enabling Phase 11

- gaze mode cannot start when the experimental setting is off
- gaze mode cannot start without calibration
- failed calibration keeps gaze actions disabled
- low face confidence produces `lowConfidence`
- low eye confidence produces `lowConfidence`
- valid calibrated observation produces a smoothed target
- sustained tracking loss exits gaze mode
- emergency exit stops gaze detection and hides the orb
- gaze alone cannot dispatch actions
- hand-confirmed pinch can dispatch only when gaze confidence and cooldown gates pass
- destructive actions still require multi-step confirmation
- low-battery policy disables gaze tracking
- calibration profile persists and can be reset

##### Acceptance Criteria

Phase 11 is complete only when:

- gaze mode is opt-in and off by default
- calibration is required and locally persisted
- camera frames can drive face/eye landmark observations
- gaze maps to coarse regions before precise target snapping
- gaze orb communicates searching, tracking, low-confidence, locked, and cooldown states
- hand-confirmed click at gaze target works in a guarded test path
- no action fires from gaze alone
- emergency exit reliably stops gaze, hand detection, camera, and overlay state
- `swift test` covers the pipeline, gates, calibration, and failure paths

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
