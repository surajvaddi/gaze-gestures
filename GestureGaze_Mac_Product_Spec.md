# GestureGaze Mac Product Specification

**Working title:** GestureGaze Mac  
**Platform:** macOS  
**Primary implementation target:** Native Swift, SwiftUI, AppKit, AVFoundation, Vision, Core Graphics, Accessibility APIs  
**Spec version:** 1.0  
**Date:** May 12, 2026  
**Product direction:** Productivity-first gesture control utility with accessibility benefits and a longer-term futuristic spatial interface vibe.

---

## Table of Contents

1. Executive Summary
2. Product Thesis
3. Goals and Non-Goals
4. Primary User Experience
5. Mode Hierarchy
6. Hotkeys and Failsafe
7. Permission Model
8. Gesture Vocabulary
9. Gesture Features
10. Temporal Gesture Classification
11. Gesture-Specific Models
12. Mode-Aware Gesture Routing
13. Cooldown System
14. Destructive Action Safety
15. Native macOS Architecture
16. Action Dispatching
17. Power and Efficiency Specification
18. Privacy and Security Specification
19. Overlay UI Specification
20. Training and Testing Protocols
21. Configuration
22. Settings UX
23. Implementation Milestones
24. Failure Handling
25. Debug HUD
26. Acceptance Criteria for MVP
27. Open Technical Risks
28. Reference Implementation Notes
29. Final Product Principle
30. Native API Reference Links

---

## 1. Executive Summary

GestureGaze Mac is a native macOS utility that lets a user control screen actions through deliberate hand gestures after pressing a keyboard chord. The Version 1 core is **hand-gesture mode**, where the user pinches their fingers to create a virtual overlay cursor. The pinched hand position is mapped from the camera frame into screen coordinates, allowing the user to move a secondary cursor, click, drag, scroll, and navigate without directly touching the trackpad or mouse.

A secondary mode, **gaze-enhanced mode**, can be toggled by flipping an open palm into the back of the palm. In this mode, the user’s eyes act as target selection and the hand gestures act as command confirmation. The eye gaze cursor is rendered as a seamless liquid-glass orb overlay that communicates confidence, action state, cooldown, and target lock through subtle light and pulse animations.

The product must feel futuristic, but it must behave conservatively. It should never feel like it is guessing. The fundamental safety rule is:

```text
Gesture mode only starts after a hotkey.
Gaze mode only starts after a palm flip.
Actions only fire after temporal confidence checks.
Destructive actions require 2 to 3 gesture-based confirmation steps.
Emergency exit always works.
Camera and vision processing are off while idle.
```

---

## 2. Product Thesis

GestureGaze is a local-first macOS gesture layer where:

```text
Keyboard = safety gate
Hands = command and cursor control
Eyes = optional target selection
Palm flip = gaze mode toggle
Cooldown = accidental repeat protection
Temporal classifier = intent recognition
Failsafe chord = trust
Overlay UI = native futuristic feedback
```

The product should feel like a spatial input layer for Mac, but the engineering philosophy should prioritize trust, battery efficiency, privacy, debuggability, and false-positive avoidance.

---

## 3. Goals and Non-Goals

### 3.1 Goals

1. Provide a reliable hand-controlled overlay cursor after a hotkey.
2. Allow users to click, drag, scroll, and navigate using deliberate gestures.
3. Provide optional gaze-enhanced targeting through a palm-flip toggle.
4. Render a native-feeling overlay UI with liquid-glass cursor orbs, soft pulses, cooldown feedback, and target lock states.
5. Use a temporal gesture classifier, not a frame-only classifier.
6. Use positive evidence and negative rejection checks for every action gesture.
7. Keep camera and vision processing off while idle.
8. Process all camera and gesture data locally by default.
9. Require 2 to 3 confirmations for destructive actions.
10. Provide a global emergency exit chord that immediately exits all gesture and gaze modes.

### 3.2 Non-Goals for Version 1

1. Do not replace the real macOS cursor continuously.
2. Do not require gaze tracking for the product to be useful.
3. Do not ship destructive actions as default one-step mappings.
4. Do not store raw video by default.
5. Do not require Screen Recording permission for the core V1.
6. Do not try to perfectly understand every UI element visually in V1.
7. Do not support every possible gesture. Use a small, reliable vocabulary first.
8. Do not run always-on camera or always-on gaze tracking.

---

## 4. Primary User Experience

### 4.1 Default Flow

```text
User presses activation chord
-> app enters hand-gesture mode
-> camera starts
-> hand tracking starts
-> pinch cursor overlay appears when user pinches
-> user moves pinched fingers to move overlay cursor
-> release pinch to click
-> pinch hold to drag
-> swipe to scroll or navigate
-> palm flip toggles gaze mode on
-> gaze orb appears
-> eyes choose target, hands choose action
-> palm flip toggles gaze mode off
-> emergency exit chord exits everything
```

### 4.2 Control Philosophy

Hand mode is practical and reliable. Gaze mode is powerful and futuristic, but it should be optional and explicitly toggled.

```text
Hand mode = reliable default control
Gaze mode = target-aware enhancement
```

### 4.3 Safety Philosophy

Missed gesture is better than accidental action.

```text
For V1, the system should prefer:
- no action when uncertain
- visible candidate feedback
- explicit confirmations
- strong cooldowns
- obvious exits
```

---

## 5. Mode Hierarchy

### 5.1 Modes

```swift
enum ControlMode: Equatable {
    case idle
    case armed
    case handGesture
    case gazeGesture
    case suspended
    case emergencyExiting
}
```

### 5.2 State Transitions

```text
IDLE
  activation chord
  -> ARMED

ARMED
  hand detected
  -> HAND_GESTURE

ARMED
  timeout with no hand detected
  -> IDLE

HAND_GESTURE
  palm flip confirmed
  -> GAZE_GESTURE

GAZE_GESTURE
  palm flip confirmed
  -> HAND_GESTURE

ANY MODE
  emergency exit chord
  -> IDLE
```

### 5.3 Mode Guarantees

| Mode | Camera | Hand Tracking | Gaze Tracking | Overlay | Actions |
|---|---:|---:|---:|---:|---:|
| Idle | Off | Off | Off | Hidden | Off |
| Armed | On | Low FPS | Off | Minimal HUD | Off until hand detected |
| Hand Gesture | On | On | Off | Pinch cursor and HUD | On |
| Gaze Gesture | On | On | On | Gaze orb and HUD | On |
| Suspended | Optional | Off | Off | Pause badge | Off |
| Emergency Exiting | Stopping | Stopping | Stopping | Hide all | Cancel all |

---

## 6. Hotkeys and Failsafe

### 6.1 Default Chords

```text
Activation chord:
Control + Option + Command + Space

Emergency exit chord:
Control + Option + Command + Escape
```

### 6.2 Emergency Exit Requirement

The emergency exit chord must not depend on camera input, gesture classification, overlay state, cooldown, or active mode.

When fired, it must:

1. Cancel current gesture.
2. Cancel active drag.
3. Hide pinch cursor.
4. Hide gaze orb.
5. Clear gesture buffers.
6. Clear cooldown state.
7. Stop camera session.
8. Stop hand and gaze pipelines.
9. Return to idle.
10. Display a brief “Gesture Mode Off” HUD pulse.

### 6.3 Hotkey Manager Interface

```swift
enum GlobalHotkey {
    case activateGestureMode
    case emergencyExit
}

protocol HotkeyManaging {
    func startListening()
    func stopListening()
    var onHotkey: ((GlobalHotkey) -> Void)? { get set }
}
```

### 6.4 Guard Logic

```swift
func handleHotkey(_ hotkey: GlobalHotkey) {
    switch hotkey {
    case .activateGestureMode:
        guard mode == .idle else { return }
        enterArmedMode()

    case .emergencyExit:
        forceExitToIdle(reason: .emergencyChord)
    }
}
```

---

## 7. Permission Model

### 7.1 Required for V1

| Permission | Required | Reason |
|---|---:|---|
| Camera | Yes | Hand and gaze tracking |
| Accessibility | Yes | Dispatch mouse and keyboard actions |
| Input Monitoring | Maybe | Depending on global hotkey implementation |
| Screen Recording | No for V1 | Avoid unless UI element recognition is added later |

### 7.2 Permission State

```swift
enum PermissionStatus: Equatable {
    case unknown
    case granted
    case denied
    case restricted
}

struct AppPermissions: Equatable {
    var camera: PermissionStatus
    var accessibility: PermissionStatus
    var inputMonitoring: PermissionStatus
    var screenRecording: PermissionStatus

    var canRunV1: Bool {
        camera == .granted && accessibility == .granted
    }
}
```

### 7.3 Permission Guards

```swift
func enterArmedMode() {
    guard permissions.camera == .granted else {
        overlay.showPermissionPrompt(.camera)
        return
    }

    guard permissions.accessibility == .granted else {
        overlay.showPermissionPrompt(.accessibility)
        return
    }

    mode = .armed
    cameraManager.startSession(profile: .armedLowPower)
}
```

---

## 8. Gesture Vocabulary

### 8.1 Gesture Types

```swift
enum GestureType: String, Codable, CaseIterable {
    case openPalm
    case openPalmHold
    case backPalm
    case palmFlip
    case fist
    case pinchStart
    case pinchTap
    case pinchHold
    case pinchMove
    case pinchRelease
    case dragStart
    case dragMove
    case dragRelease
    case swipeLeft
    case swipeRight
    case swipeUp
    case swipeDown
    case twoFingerSwipeLeft
    case twoFingerSwipeRight
    case threeFingerSwipeLeft
    case threeFingerSwipeRight
    case fourFingerSwipeLeft
    case fourFingerSwipeRight
    case twoFingerPinch
    case gazeLock
    case cancel
}
```

### 8.2 Gesture Phases

```swift
enum GesturePhase: String, Codable {
    case none
    case candidate
    case confirmed
    case fired
    case held
    case released
    case cancelled
    case rejected
}
```

### 8.3 Gesture Phase Strategy

The gesture vocabulary is intentionally larger than the initial shipping set. Gestures should be promoted through phases only after they pass replay tests, live use tests, and false-positive gates.

```text
Phase 1 gestures are core MVP.
Phase 2 gestures are usability extensions.
Phase 3 gestures are experimental spatial controls.
Phase 4 gestures are future power-user mappings.

Anything outside Phase 1 should be treated as TODO, disabled by default, and excluded from MVP acceptance criteria.
```

### 8.4 Phase 1: Core MVP Gesture Set

| Gesture | Mode | Action |
|---|---|---|
| Pinch and move | Hand | Move pinch cursor |
| Quick pinch release | Hand | Left click at pinch cursor |
| Open palm | Hand | Cancel current action |
| Open palm hold | Hand | Exit to idle |

### 8.5 Phase 2: Hand Mode Usability TODO

These gestures should be implemented after the pinch cursor and click path are reliable.

| Gesture | Mode | Planned Action | Status |
|---|---|---|---|
| Pinch hold | Hand | Prepare drag | TODO |
| Pinch hold and move | Hand | Drag | TODO |
| Release after drag | Hand | Drop | TODO |
| Swipe up | Hand | Scroll up | TODO |
| Swipe down | Hand | Scroll down | TODO |
| Swipe left | Hand | Previous tab or page | TODO |
| Swipe right | Hand | Next tab or page | TODO |
| Fist | Hand | Freeze cursor | TODO |

### 8.6 Phase 3: Experimental Gaze Mode TODO

Gaze mode is valuable, but it should not block the first usable hand-control release.

| Gesture | Mode | Planned Action | Status |
|---|---|---|---|
| Palm flip | Hand | Toggle gaze mode on | TODO |
| Palm flip | Gaze | Toggle gaze mode off | TODO |
| Pinch | Gaze | Click at gaze orb target | TODO |
| Pinch hold | Gaze | Drag from gaze target | TODO |
| Swipe up or down | Gaze | Scroll near gaze target | TODO |
| Fist | Gaze | Lock gaze orb | TODO |
| Open palm | Gaze | Cancel current action | TODO |

### 8.7 Phase 4: Future Multi-Finger Swipe TODO

Multi-finger swipes are future power-user gestures inspired by trackpad gestures, but they should not mirror trackpad behavior blindly. The camera gesture should remain deliberate, visually confirmed, and mode-aware.

| Gesture | Mode | Candidate Action Direction | Status |
|---|---|---|---|
| Two-finger swipe left | Hand | Previous item, previous tab, or horizontal navigation | TODO |
| Two-finger swipe right | Hand | Next item, next tab, or horizontal navigation | TODO |
| Three-finger swipe left | Hand | Previous desktop, previous workspace, or app-level navigation | TODO |
| Three-finger swipe right | Hand | Next desktop, next workspace, or app-level navigation | TODO |
| Four-finger swipe left | Hand | Higher-level context switch, window group navigation, or custom shortcut | TODO |
| Four-finger swipe right | Hand | Higher-level context switch, window group navigation, or custom shortcut | TODO |

Future multi-finger swipes must satisfy stricter gates than one-hand swipes:

```text
- disabled by default
- explicit user opt-in
- per-gesture calibration
- high confidence on visible extended finger count
- low pinch confidence
- low palm flip confidence
- no active drag
- longer cooldown than single-hand swipe
- visible candidate feedback before firing
```

### 8.8 Sacred Gesture Rule

```text
Palm flip is only a mode toggle.
It must never fire click, scroll, drag, navigation, or destructive action.
```

---

## 9. Gesture Features

### 9.1 Frame Observation

Each camera frame produces a normalized observation. Gesture classifiers do not read raw video. They read structured landmarks and derived features.

```swift
struct GestureFrameObservation: Codable {
    let timestamp: TimeInterval
    let frameIndex: Int
    let mode: ControlMode
    let hand: HandObservation?
    let gaze: GazeObservation?
    let system: SystemObservation
}

struct SystemObservation: Codable {
    let batteryLevel: Double?
    let isLowPowerMode: Bool
    let thermalState: ThermalState
    let activeFPS: Double
}
```

### 9.2 Hand Observation

```swift
struct HandObservation: Codable {
    let handedness: Handedness
    let confidence: Double
    let landmarks: [HandJoint: NormalizedPoint]
    let palmCenter: NormalizedPoint
    let palmNormalEstimate: Vector3D?
    let boundingBox: NormalizedRect
    let pinchDistance: Double
    let indexFingerCurl: Double
    let middleFingerCurl: Double
    let ringFingerCurl: Double
    let pinkyFingerCurl: Double
    let thumbIndexAngle: Double
    let handVelocity: Vector2D
    let handAcceleration: Vector2D
    let rotationVelocity: Double
    let visibilityScore: Double
}

enum Handedness: String, Codable {
    case left
    case right
    case unknown
}

struct NormalizedPoint: Codable {
    let x: Double
    let y: Double
    let z: Double?
}

struct Vector2D: Codable {
    let dx: Double
    let dy: Double
}

struct Vector3D: Codable {
    let x: Double
    let y: Double
    let z: Double
}

struct NormalizedRect: Codable {
    let x: Double
    let y: Double
    let width: Double
    let height: Double
}
```

### 9.3 Gaze Observation

```swift
struct GazeObservation: Codable {
    let timestamp: TimeInterval
    let faceConfidence: Double
    let eyeConfidence: Double
    let rawGazePoint: NormalizedPoint?
    let smoothedScreenPoint: ScreenPoint?
    let gazeRegion: GazeRegion
    let stabilityScore: Double
    let lockCandidateScore: Double
}

enum GazeRegion: String, Codable {
    case topLeft
    case topCenter
    case topRight
    case middleLeft
    case center
    case middleRight
    case bottomLeft
    case bottomCenter
    case bottomRight
    case unknown
}

struct ScreenPoint: Codable {
    let x: Double
    let y: Double
    let displayID: String
}
```

### 9.4 Feature Table

| Gesture | Positive Features | Negative Features |
|---|---|---|
| Pinch tap | Thumb-index distance closes quickly, close endpoint, stable for 3 to 6 frames | Hand velocity too high, fist confidence high, palm flip rotation high |
| Pinch hold | Thumb-index distance below threshold for hold duration | Release too early, hand leaves frame, low confidence |
| Drag | Pinch hold followed by movement above drag threshold | Open palm cancel, fist freeze, palm flip candidate |
| Swipe | High directional displacement, high velocity, straight path | Pinch active, palm flip rotation, slow repositioning |
| Palm flip | Stable open palm, rotation over time, back palm stable, limited translation | Lateral swipe, pinch, hand exits frame |
| Fist | Finger curl high across fingers, stable pose | Thumb-index pinch, open palm, low visibility |
| Open palm | Fingers extended, palm visible, low curl | Back palm candidate, fast motion, pinch |
| Open palm hold | Open palm stable for duration | Hand motion, palm flip, low confidence |
| Two-finger pinch | Thumb-index and thumb-middle relationship, stable pose | Fist, normal pinch, swipe |

---

## 10. Temporal Gesture Classification

### 10.1 Principle

Gesture classification must be temporal. The system should not dispatch actions from a single frame except for emergency keyboard exit.

```text
The classifier should ask:
Across the last N milliseconds, did this movement become gesture X, remain stable enough, and avoid being confused with gesture Y?
```

### 10.2 Rolling Buffer

```swift
final class GestureObservationBuffer {
    private var frames: [GestureFrameObservation] = []
    let maxDuration: TimeInterval

    init(maxDuration: TimeInterval = 1.20) {
        self.maxDuration = maxDuration
    }

    func append(_ frame: GestureFrameObservation) {
        frames.append(frame)
        prune(before: frame.timestamp - maxDuration)
    }

    func window(last duration: TimeInterval) -> [GestureFrameObservation] {
        guard let latest = frames.last?.timestamp else { return [] }
        return frames.filter { $0.timestamp >= latest - duration }
    }

    func clear() {
        frames.removeAll()
    }

    private func prune(before cutoff: TimeInterval) {
        frames.removeAll { $0.timestamp < cutoff }
    }
}
```

### 10.3 Window Durations

| Window | Use |
|---:|---|
| 100 ms | Fast candidate detection |
| 250 ms | Pinch tap, initial pose stability |
| 500 ms | Swipe, palm flip, short hold |
| 800 ms | Drag readiness, open palm hold candidate |
| 1200 ms | Exit hold, destructive confirmation sequence |

### 10.4 Gesture Score

```swift
struct GestureScore: Codable {
    let gesture: GestureType
    let phase: GesturePhase
    let activation: Double
    let rejection: Double
    let confidence: Double
    let reasonCodes: [GestureReasonCode]

    var isActionable: Bool {
        confidence >= 0.80 && phase == .confirmed
    }
}

enum GestureReasonCode: String, Codable {
    case sufficientPinchClosure
    case stablePose
    case velocityBelowSwipeThreshold
    case velocityAboveSwipeThreshold
    case palmRotationDetected
    case lateralMotionTooHigh
    case fistConflict
    case pinchConflict
    case palmFlipConflict
    case lowVisibility
    case lowLandmarkConfidence
    case cooldownActive
    case modeMismatch
    case destructiveActionRequiresConfirmation
}
```

### 10.5 Scoring Rule

```text
confidence = clamp(activation - rejection, 0.0, 1.0)
```

Each gesture scorer must produce both activation and rejection.

```swift
protocol GestureScoring {
    var gesture: GestureType { get }
    func score(buffer: GestureObservationBuffer, context: GestureContext) -> GestureScore
}
```

### 10.6 Classifier Protocol

```swift
protocol GestureClassifying {
    func update(with observation: GestureFrameObservation) -> GestureEvent?
    func reset()
}

struct GestureContext {
    let mode: ControlMode
    let activeGesture: GestureEvent?
    let cooldowns: GestureCooldownManager
    let safetyPolicy: SafetyPolicy
    let timestamp: TimeInterval
}

struct GestureEvent: Codable {
    let id: UUID
    let type: GestureType
    let phase: GesturePhase
    let timestamp: TimeInterval
    let confidence: Double
    let screenPoint: ScreenPoint?
    let source: GestureSource
    let reasonCodes: [GestureReasonCode]
}

enum GestureSource: String, Codable {
    case hand
    case gaze
    case hotkey
    case system
}
```

### 10.7 Priority Resolution

```swift
enum GesturePriority: Int {
    case emergencyExit = 0
    case cancel = 1
    case modeToggle = 2
    case activeDrag = 3
    case clickOrRelease = 4
    case navigation = 5
    case passiveMovement = 6
}
```

Priority order:

```text
0. Emergency exit chord
1. Open palm cancel
2. Palm flip mode toggle
3. Active drag or held gesture
4. Click, right click, release
5. Swipe navigation
6. Passive cursor movement
```

### 10.8 Conflict Resolution

```swift
func resolveGesture(_ scores: [GestureScore], context: GestureContext) -> GestureScore? {
    let eligible = scores
        .filter { $0.confidence >= threshold(for: $0.gesture, mode: context.mode) }
        .filter { !context.cooldowns.isCoolingDown($0.gesture, now: context.timestamp) }
        .filter { !isContradicted($0, by: scores) }

    return eligible.sorted { lhs, rhs in
        priority(of: lhs.gesture).rawValue < priority(of: rhs.gesture).rawValue
    }.first
}
```

### 10.9 Guard Statements for Dispatch

```swift
func dispatch(_ event: GestureEvent) {
    guard mode != .idle else { return }
    guard event.confidence >= policy.minConfidence(for: event.type) else { return }
    guard !cooldowns.isCoolingDown(event.type, now: event.timestamp) else { return }
    guard !policy.isBlocked(event.type, in: mode) else { return }

    if actionRegistry.action(for: event, mode: mode).isDestructive {
        guard confirmationManager.hasValidConfirmation(for: event) else {
            confirmationManager.beginConfirmation(for: event)
            overlay.showDestructiveConfirmation(event)
            return
        }
    }

    actionDispatcher.perform(event)
    cooldowns.markFired(event.type, now: event.timestamp)
    overlay.showActionPulse(for: event)
}
```

---

## 11. Gesture-Specific Models

### 11.1 Pinch Cursor Model

#### Purpose

Pinched fingers create and move a virtual cursor by mapping the midpoint between thumb tip and index tip from camera coordinates to screen coordinates.

#### Features

```text
pinchDistance
pinchDistanceVelocity
thumbTip position
indexTip position
pinchMidpoint
handVelocity
visibilityScore
fingerCurl scores
handedness
```

#### Pinch Point

```swift
func pinchMidpoint(thumb: NormalizedPoint, index: NormalizedPoint) -> NormalizedPoint {
    NormalizedPoint(
        x: (thumb.x + index.x) / 2.0,
        y: (thumb.y + index.y) / 2.0,
        z: zipAverage(thumb.z, index.z)
    )
}

func zipAverage(_ a: Double?, _ b: Double?) -> Double? {
    guard let a, let b else { return nil }
    return (a + b) / 2.0
}
```

#### Mapping to Screen

```swift
struct CameraControlBox: Codable {
    let minX: Double
    let maxX: Double
    let minY: Double
    let maxY: Double
    let mirrorX: Bool
}

func mapCameraPointToScreen(
    _ point: NormalizedPoint,
    controlBox: CameraControlBox,
    display: DisplayGeometry
) -> ScreenPoint {
    let clampedX = min(max(point.x, controlBox.minX), controlBox.maxX)
    let clampedY = min(max(point.y, controlBox.minY), controlBox.maxY)

    var normalizedX = (clampedX - controlBox.minX) / (controlBox.maxX - controlBox.minX)
    let normalizedY = (clampedY - controlBox.minY) / (controlBox.maxY - controlBox.minY)

    if controlBox.mirrorX {
        normalizedX = 1.0 - normalizedX
    }

    return ScreenPoint(
        x: display.originX + normalizedX * display.width,
        y: display.originY + normalizedY * display.height,
        displayID: display.id
    )
}

struct DisplayGeometry: Codable {
    let id: String
    let originX: Double
    let originY: Double
    let width: Double
    let height: Double
}
```

#### Smoothing

```swift
struct CursorSmoother {
    var alpha: Double = 0.25
    var deadzonePixels: Double = 4.0
    private var last: ScreenPoint?

    mutating func smooth(_ next: ScreenPoint) -> ScreenPoint {
        guard let last else {
            self.last = next
            return next
        }

        let dx = next.x - last.x
        let dy = next.y - last.y
        let distance = sqrt(dx * dx + dy * dy)

        if distance < deadzonePixels {
            return last
        }

        let smoothed = ScreenPoint(
            x: alpha * next.x + (1.0 - alpha) * last.x,
            y: alpha * next.y + (1.0 - alpha) * last.y,
            displayID: next.displayID
        )

        self.last = smoothed
        return smoothed
    }

    mutating func reset() {
        last = nil
    }
}
```

#### Pinch Gesture States

```text
NONE
  pinch begins
  -> PINCH_CANDIDATE

PINCH_CANDIDATE
  stable pinch
  -> PINCH_CURSOR_ACTIVE

PINCH_CURSOR_ACTIVE
  movement while pinched
  -> PINCH_MOVE

PINCH_CURSOR_ACTIVE
  release before hold threshold
  -> CLICK

PINCH_CURSOR_ACTIVE
  hold beyond threshold
  -> DRAG_READY

DRAG_READY
  movement beyond drag threshold
  -> DRAGGING

DRAGGING
  release
  -> DROP

ANY
  open palm
  -> CANCELLED
```

#### Guard Rules

```swift
func scorePinchTap(buffer: GestureObservationBuffer) -> GestureScore {
    let window = buffer.window(last: 0.30)

    let activation = activationFromPinchClosure(window)
    var rejection = 0.0

    if hasHighSwipeVelocity(window) { rejection += 0.45 }
    if hasFistPose(window) { rejection += 0.35 }
    if hasPalmFlipRotation(window) { rejection += 0.50 }
    if hasLowVisibility(window) { rejection += 0.40 }

    let confidence = max(0.0, min(1.0, activation - rejection))

    return GestureScore(
        gesture: .pinchTap,
        phase: confidence > 0.80 ? .confirmed : .candidate,
        activation: activation,
        rejection: rejection,
        confidence: confidence,
        reasonCodes: reasonCodesForPinch(window)
    )
}
```

---

### 11.2 Swipe Model

#### Purpose

Swipes provide navigation and scrolling when not pinching.

#### Features

```text
hand displacement over 150 to 700 ms
average velocity
peak velocity
path straightness
vertical drift
horizontal drift
pinch confidence during motion
palm rotation during motion
visibility across frames
```

#### Rule

```text
Swipe right fires if:
- x displacement > 20 percent of control box width
- duration between 150 ms and 700 ms
- average x velocity exceeds threshold
- y drift is below threshold
- hand remains visible for most frames
- pinch confidence stays low
- palm flip confidence stays low
```

#### Pseudocode

```swift
func scoreSwipeRight(buffer: GestureObservationBuffer) -> GestureScore {
    let window = buffer.window(last: 0.70)

    let displacement = horizontalDisplacement(window)
    let velocity = averageHorizontalVelocity(window)
    let straightness = pathStraightness(window)

    var activation = 0.0
    activation += normalized(displacement, min: 0.15, max: 0.35) * 0.40
    activation += normalized(velocity, min: 0.40, max: 1.20) * 0.35
    activation += straightness * 0.25

    var rejection = 0.0
    if verticalDrift(window) > 0.12 { rejection += 0.25 }
    if pinchConfidence(window) > 0.35 { rejection += 0.45 }
    if palmFlipConfidence(window) > 0.35 { rejection += 0.50 }
    if visibilityRatio(window) < 0.85 { rejection += 0.30 }

    let confidence = clamp(activation - rejection)

    return GestureScore(
        gesture: .swipeRight,
        phase: confidence > 0.82 ? .confirmed : .candidate,
        activation: activation,
        rejection: rejection,
        confidence: confidence,
        reasonCodes: []
    )
}
```

---

### 11.3 Palm Flip Model

#### Purpose

Palm flip toggles gaze mode on and off.

#### Features

```text
open palm stability
palm orientation estimate
wrist to finger geometry
thumb side relation to hand direction
rotation velocity
back-palm confidence
hand translation during flip
pinch confidence during flip
```

#### Rule

```text
Palm flip fires if:
- open palm stable for at least 250 ms
- rotation begins after open palm
- orientation changes continuously toward back palm
- back palm stable for at least 150 ms
- hand remains in roughly same screen region
- no pinch occurs during transition
- no swipe-like lateral translation occurs
- palm flip cooldown is inactive
```

#### State Machine

```swift
enum PalmFlipState {
    case none
    case openPalmStable(start: TimeInterval)
    case rotationCandidate(start: TimeInterval)
    case backPalmStable(start: TimeInterval)
    case confirmed
    case rejected
}
```

#### Guard Rules

```swift
func shouldToggleGaze(from score: GestureScore, context: GestureContext) -> Bool {
    guard score.gesture == .palmFlip else { return false }
    guard score.confidence >= 0.85 else { return false }
    guard !context.cooldowns.isCoolingDown(.palmFlip, now: context.timestamp) else { return false }
    guard context.mode == .handGesture || context.mode == .gazeGesture else { return false }
    return true
}
```

---

### 11.4 Open Palm Cancel Model

#### Purpose

Open palm cancels the current gesture or exits after a hold.

#### Rules

```text
Open palm immediate:
- cancel current action
- remain in current mode

Open palm hold for 1.5 seconds:
- exit to idle
```

#### Guard

```swift
func handleOpenPalm(_ event: GestureEvent) {
    guard event.confidence >= 0.80 else { return }

    if event.type == .openPalmHold {
        forceExitToIdle(reason: .openPalmHold)
    } else {
        cancelCurrentAction()
        overlay.showCancelPulse()
    }
}
```

---

### 11.5 Gaze Cursor Model

#### Purpose

Gaze mode provides target selection. The gaze cursor should not be treated as a precise mouse replacement in V1. It should be a target-aware orb that can snap, lock, fade, and pulse based on confidence.

#### Features

```text
face confidence
eye landmark confidence
head orientation estimate
eye center positions
gaze region
raw gaze point
smoothed gaze point
gaze stability
gaze dwell duration
target lock confidence
```

#### Model Stages

```text
Stage 1: coarse regions
Stage 2: calibrated screen point
Stage 3: target snapping
Stage 4: gaze lock and confirm
```

#### Guard Rules

```swift
func updateGazeOrb(_ observation: GazeObservation) {
    guard mode == .gazeGesture else {
        overlay.hideGazeOrb()
        return
    }

    guard observation.faceConfidence >= 0.70,
          observation.eyeConfidence >= 0.65 else {
        overlay.setGazeOrbState(.lowConfidence)
        return
    }

    guard let point = observation.smoothedScreenPoint else {
        overlay.setGazeOrbState(.searching)
        return
    }

    gazeCursor.move(to: point)
    overlay.setGazeOrbState(.tracking(confidence: observation.stabilityScore))
}
```

---

## 12. Mode-Aware Gesture Routing

### 12.1 Router

```swift
final class GestureRouter {
    private var mode: ControlMode
    private let actionDispatcher: MacActionDispatching
    private let overlay: OverlayRendering
    private let confirmationManager: DestructiveConfirmationManaging
    private var cooldowns: GestureCooldownManager

    init(
        mode: ControlMode,
        actionDispatcher: MacActionDispatching,
        overlay: OverlayRendering,
        confirmationManager: DestructiveConfirmationManaging,
        cooldowns: GestureCooldownManager
    ) {
        self.mode = mode
        self.actionDispatcher = actionDispatcher
        self.overlay = overlay
        self.confirmationManager = confirmationManager
        self.cooldowns = cooldowns
    }

    func handle(_ event: GestureEvent) {
        switch mode {
        case .idle:
            return
        case .armed:
            handleArmed(event)
        case .handGesture:
            handleHandGesture(event)
        case .gazeGesture:
            handleGazeGesture(event)
        case .suspended:
            return
        case .emergencyExiting:
            return
        }
    }
}
```

### 12.2 Hand Mode Routing

```swift
func handleHandGesture(_ event: GestureEvent) {
    switch event.type {
    case .palmFlip:
        enterGazeGestureMode()

    case .pinchMove:
        guard let point = event.screenPoint else { return }
        overlay.movePinchCursor(to: point)

    case .pinchTap:
        performSafeAction(.leftClick(point: event.screenPoint), from: event)

    case .pinchHold:
        overlay.setPinchCursorState(.dragReady)

    case .dragStart, .dragMove, .dragRelease:
        handleDrag(event)

    case .swipeLeft:
        performSafeAction(.previousTab, from: event)

    case .swipeRight:
        performSafeAction(.nextTab, from: event)

    case .swipeUp:
        performSafeAction(.scrollUp(point: event.screenPoint), from: event)

    case .swipeDown:
        performSafeAction(.scrollDown(point: event.screenPoint), from: event)

    case .openPalm, .cancel:
        cancelCurrentAction()

    case .openPalmHold:
        forceExitToIdle(reason: .openPalmHold)

    default:
        break
    }
}
```

### 12.3 Gaze Mode Routing

```swift
func handleGazeGesture(_ event: GestureEvent) {
    switch event.type {
    case .palmFlip:
        exitGazeGestureMode()

    case .pinchTap:
        performSafeAction(.leftClick(point: gazeCursor.currentPoint), from: event)

    case .pinchHold:
        overlay.setGazeOrbState(.dragReady)

    case .dragStart, .dragMove, .dragRelease:
        handleGazeDrag(event)

    case .swipeUp:
        performSafeAction(.scrollUp(point: gazeCursor.currentPoint), from: event)

    case .swipeDown:
        performSafeAction(.scrollDown(point: gazeCursor.currentPoint), from: event)

    case .fist:
        gazeCursor.lock()
        overlay.setGazeOrbState(.locked)

    case .openPalm, .cancel:
        cancelCurrentAction()

    case .openPalmHold:
        forceExitToIdle(reason: .openPalmHold)

    default:
        break
    }
}
```

---

## 13. Cooldown System

### 13.1 Principle

Cooldown blocks repeated action firing, not cursor movement.

During cooldown:

```text
- overlay cursor still moves
- gaze orb still moves
- UI feedback still updates
- same action gesture cannot fire again
- emergency exit still fires instantly
```

### 13.2 Defaults

| Gesture | Cooldown |
|---|---:|
| Pinch click | 300 ms |
| Two-finger right click | 400 ms |
| Swipe left/right | 650 ms |
| Swipe up/down | 500 ms |
| Palm flip | 850 ms |
| Open palm cancel | 500 ms |
| Destructive confirmation step | 1000 ms |
| Emergency exit | 0 ms |

### 13.3 Model

```swift
struct GestureCooldownManager: Codable {
    private var lastFired: [GestureType: TimeInterval] = [:]
    private var cooldowns: [GestureType: TimeInterval] = [
        .pinchTap: 0.30,
        .twoFingerPinch: 0.40,
        .swipeLeft: 0.65,
        .swipeRight: 0.65,
        .swipeUp: 0.50,
        .swipeDown: 0.50,
        .palmFlip: 0.85,
        .openPalm: 0.50
    ]

    func isCoolingDown(_ gesture: GestureType, now: TimeInterval) -> Bool {
        let cooldown = cooldowns[gesture] ?? 0.50
        let last = lastFired[gesture] ?? -.infinity
        return now - last < cooldown
    }

    mutating func markFired(_ gesture: GestureType, now: TimeInterval) {
        lastFired[gesture] = now
    }

    mutating func clear() {
        lastFired.removeAll()
    }
}
```

---

## 14. Destructive Action Safety

### 14.1 Destructive Actions

Examples:

```text
close tab
close app
quit app
delete file
submit form
send message
purchase
empty trash
move file
run shell command
```

### 14.2 Policy

```text
Destructive actions must never be one-step gestures.
They require 2 to 3 deliberate confirmation steps.
The confirmation gesture must differ from the initiating gesture.
```

### 14.3 Confirmation Pattern

```text
Step 1: User performs initiating gesture
Step 2: Visual confirmation overlay appears
Step 3: User performs distinct confirmation gesture
Optional Step 4: For high-risk actions, user holds confirmation for duration
```

### 14.4 Confirmation Model

```swift
enum DestructiveRiskLevel: String, Codable {
    case low
    case medium
    case high
}

struct DestructiveActionPolicy: Codable {
    let riskLevel: DestructiveRiskLevel
    let requiredSteps: Int
    let confirmGesture: GestureType
    let minimumHoldDuration: TimeInterval?
    let timeout: TimeInterval
}

struct PendingDestructiveAction: Codable {
    let id: UUID
    let action: MacAction
    let initiatedBy: GestureEvent
    let startedAt: TimeInterval
    let requiredGesture: GestureType
    let requiredStepsRemaining: Int
}
```

### 14.5 Example Policies

| Action | Risk | Required Flow |
|---|---|---|
| Close tab | Medium | Swipe close -> overlay -> pinch hold confirm |
| Delete file | High | Select -> delete gesture -> overlay -> open palm hold confirm |
| Send message | High | Submit gesture -> overlay -> two-finger pinch confirm |
| Quit app | High | Quit gesture -> overlay -> fist hold -> pinch confirm |

### 14.6 Guard

```swift
func performSafeAction(_ action: MacAction, from event: GestureEvent) {
    if action.isDestructive {
        guard confirmationManager.isConfirmed(action, by: event) else {
            confirmationManager.begin(action, initiatedBy: event)
            overlay.showDestructiveActionPrompt(action)
            return
        }
    }

    actionDispatcher.perform(action)
    overlay.showActionPulse(for: action)
}
```

---

## 15. Native macOS Architecture

### 15.1 Frameworks

| Layer | Native Framework |
|---|---|
| Menu bar app | SwiftUI, AppKit |
| Camera frames | AVFoundation |
| Hand tracking | Vision |
| Face and gaze landmarks | Vision |
| Overlay windows | AppKit, SwiftUI |
| Input dispatch | Core Graphics, Accessibility |
| Hotkeys | AppKit event monitoring or lower-level event tap |
| Settings | SwiftUI, UserDefaults, Codable config |

### 15.2 Modules

```text
GestureGazeMac/
├── App/
│   ├── GestureGazeApp.swift
│   ├── AppCoordinator.swift
│   ├── MenuBarController.swift
│   └── SettingsWindow.swift
│
├── Permissions/
│   ├── PermissionManager.swift
│   └── PermissionOnboardingView.swift
│
├── Input/
│   ├── HotkeyManager.swift
│   ├── CameraSessionManager.swift
│   └── DisplayManager.swift
│
├── VisionPipeline/
│   ├── HandPoseTracker.swift
│   ├── FaceLandmarkTracker.swift
│   ├── GazeEstimator.swift
│   └── VisionFrameScheduler.swift
│
├── Gestures/
│   ├── GestureTypes.swift
│   ├── GestureObservation.swift
│   ├── GestureObservationBuffer.swift
│   ├── TemporalGestureClassifier.swift
│   ├── GestureCooldownManager.swift
│   ├── GestureRouter.swift
│   └── GestureScorers/
│       ├── PinchScorer.swift
│       ├── SwipeScorer.swift
│       ├── PalmFlipScorer.swift
│       ├── OpenPalmScorer.swift
│       └── FistScorer.swift
│
├── Cursor/
│   ├── PinchCursorController.swift
│   ├── GazeCursorController.swift
│   ├── CursorSmoother.swift
│   └── CameraToScreenMapper.swift
│
├── Overlay/
│   ├── OverlayWindowController.swift
│   ├── LiquidGlassHUD.swift
│   ├── PinchCursorView.swift
│   ├── GazeOrbView.swift
│   ├── GesturePulseView.swift
│   └── ConfirmationOverlayView.swift
│
├── Actions/
│   ├── MacAction.swift
│   ├── MacActionDispatcher.swift
│   ├── MouseController.swift
│   ├── KeyboardShortcutController.swift
│   └── DestructiveConfirmationManager.swift
│
├── Power/
│   ├── PowerGovernor.swift
│   ├── ThermalMonitor.swift
│   └── FrameRatePolicy.swift
│
├── Privacy/
│   ├── PrivacyPolicy.swift
│   ├── DebugTraceRecorder.swift
│   └── Redaction.swift
│
└── Config/
    ├── GestureMappings.json
    ├── PowerProfiles.json
    └── OverlayTheme.json
```

### 15.3 App Coordinator

```swift
final class AppCoordinator {
    private var mode: ControlMode = .idle
    private let hotkeyManager: HotkeyManaging
    private let cameraManager: CameraSessionManaging
    private let visionPipeline: VisionPipeline
    private let classifier: GestureClassifying
    private let router: GestureRouter
    private let overlay: OverlayRendering
    private let powerGovernor: PowerGoverning

    func start() {
        hotkeyManager.onHotkey = { [weak self] hotkey in
            self?.handleHotkey(hotkey)
        }
        hotkeyManager.startListening()
        overlay.prepareHiddenWindows()
    }

    func enterArmedMode() {
        guard mode == .idle else { return }
        guard permissions.canRunV1 else {
            overlay.showPermissionOnboarding()
            return
        }

        mode = .armed
        powerGovernor.apply(.armedLowPower)
        cameraManager.startSession(profile: .armedLowPower)
        visionPipeline.start(handTracking: true, gazeTracking: false)
        overlay.showModeBadge(.armed)
    }

    func forceExitToIdle(reason: ExitReason) {
        mode = .emergencyExiting
        router.cancelAllActions()
        classifier.reset()
        visionPipeline.stop()
        cameraManager.stopSession()
        powerGovernor.apply(.idle)
        overlay.hideAll(reason: reason)
        mode = .idle
    }
}
```

---

## 16. Action Dispatching

### 16.1 Mac Actions

```swift
enum MacAction: Codable, Equatable {
    case leftClick(point: ScreenPoint?)
    case rightClick(point: ScreenPoint?)
    case mouseDown(point: ScreenPoint?)
    case mouseDrag(point: ScreenPoint?)
    case mouseUp(point: ScreenPoint?)
    case scrollUp(point: ScreenPoint?)
    case scrollDown(point: ScreenPoint?)
    case previousTab
    case nextTab
    case previousDesktop
    case nextDesktop
    case cancel
    case closeTab
    case quitApp
    case deleteSelection
    case customShortcut(keys: [KeyEquivalent])

    var isDestructive: Bool {
        switch self {
        case .closeTab, .quitApp, .deleteSelection:
            return true
        default:
            return false
        }
    }
}
```

### 16.2 Dispatcher Protocol

```swift
protocol MacActionDispatching {
    func perform(_ action: MacAction)
    func cancelActiveAction()
}
```

### 16.3 Dispatch Guard

```swift
func perform(_ action: MacAction) {
    guard permissions.accessibility == .granted else {
        overlay.showPermissionPrompt(.accessibility)
        return
    }

    guard mode == .handGesture || mode == .gazeGesture else {
        return
    }

    switch action {
    case .leftClick(let point):
        mouseController.leftClick(at: point)

    case .rightClick(let point):
        mouseController.rightClick(at: point)

    case .scrollUp(let point):
        mouseController.scroll(deltaY: 5, around: point)

    case .scrollDown(let point):
        mouseController.scroll(deltaY: -5, around: point)

    case .previousTab:
        keyboardController.sendShortcut([.command, .shift, .leftBracket])

    case .nextTab:
        keyboardController.sendShortcut([.command, .shift, .rightBracket])

    default:
        break
    }
}
```

---

## 17. Power and Efficiency Specification

### 17.1 Core Principle

```text
Always-on hotkey listener.
Never always-on vision.
```

### 17.2 Power States

```swift
enum PowerProfile: String, Codable {
    case idle
    case armedLowPower
    case handBalanced
    case handHighResponsiveness
    case gazeBalanced
    case lowBattery
    case thermalRestricted
}

struct PowerPolicy: Codable {
    let cameraEnabled: Bool
    let handTrackingEnabled: Bool
    let gazeTrackingEnabled: Bool
    let targetFPS: Double
    let frameSkipInterval: Int
    let useRegionOfInterest: Bool
    let timeoutSeconds: Double
    let allowDebugRecording: Bool
}
```

### 17.3 Default Profiles

| Profile | Camera | Hand | Gaze | FPS | Timeout |
|---|---:|---:|---:|---:|---:|
| Idle | Off | Off | Off | 0 | None |
| Armed Low Power | On | On | Off | 10 to 15 | 3 sec |
| Hand Balanced | On | On | Off | 24 to 30 | 5 sec |
| Hand High Responsiveness | On | On | Off | 30 | 8 sec |
| Gaze Balanced | On | On | On | 20 to 30 | 5 sec |
| Low Battery | On | On | Off by default | 10 to 15 | 3 sec |
| Thermal Restricted | On | Reduced | Off | 8 to 12 | 2 sec |

### 17.4 Efficiency Pipeline

```text
Idle:
  hotkey listener only
  camera off
  vision off

Activation:
  start camera at low FPS
  run hand presence detector
  if no hand after timeout, return to idle

Hand Mode:
  run hand landmarks
  compute features
  update cursor at target FPS
  run full temporal classifier only when candidate motion appears

Gaze Mode:
  run hand landmarks
  run face landmarks
  update gaze orb
  run gaze smoothing
  run classifier for hand command confirmation

Cooldown:
  continue lightweight cursor updates
  block action firing
  optionally lower classifier frequency

Inactivity:
  reduce FPS
  fade overlay
  stop gaze first
  stop camera last
```

### 17.5 Staged Detection

```swift
struct VisionFrameScheduler {
    let profile: PowerProfile

    func shouldRunHandPose(frameIndex: Int) -> Bool {
        switch profile {
        case .idle:
            return false
        case .armedLowPower:
            return frameIndex % 3 == 0
        case .handBalanced, .gazeBalanced:
            return true
        case .lowBattery:
            return frameIndex % 2 == 0
        case .thermalRestricted:
            return frameIndex % 4 == 0
        case .handHighResponsiveness:
            return true
        }
    }

    func shouldRunGaze(frameIndex: Int, mode: ControlMode) -> Bool {
        guard mode == .gazeGesture else { return false }
        switch profile {
        case .gazeBalanced:
            return frameIndex % 2 == 0
        case .handHighResponsiveness:
            return true
        case .lowBattery, .thermalRestricted:
            return false
        default:
            return false
        }
    }
}
```

### 17.6 Power Governor

```swift
protocol PowerGoverning {
    func apply(_ profile: PowerProfile)
    func updateFromSystemState(_ state: SystemPowerState)
}

struct SystemPowerState: Codable {
    let batteryLevel: Double?
    let isCharging: Bool
    let isLowPowerMode: Bool
    let thermalState: ThermalState
    let userSelectedPerformanceMode: UserPerformanceMode
}

enum ThermalState: String, Codable {
    case nominal
    case fair
    case serious
    case critical
}

enum UserPerformanceMode: String, Codable {
    case bestBattery
    case balanced
    case highResponsiveness
}
```

### 17.7 Power Guards

```swift
func updatePowerPolicy(_ state: SystemPowerState) {
    if state.thermalState == .critical || state.thermalState == .serious {
        apply(.thermalRestricted)
        overlay.showPowerBadge(.thermalRestricted)
        return
    }

    if state.isLowPowerMode || (state.batteryLevel ?? 1.0) < 0.20 {
        apply(.lowBattery)
        overlay.showPowerBadge(.lowBattery)
        return
    }

    switch mode {
    case .idle:
        apply(.idle)
    case .armed:
        apply(.armedLowPower)
    case .handGesture:
        apply(state.userSelectedPerformanceMode == .highResponsiveness ? .handHighResponsiveness : .handBalanced)
    case .gazeGesture:
        apply(.gazeBalanced)
    default:
        apply(.idle)
    }
}
```

---

## 18. Privacy and Security Specification

### 18.1 Privacy Defaults

```text
All processing local by default.
No raw video saved by default.
No cloud inference by default.
No screenshots by default.
No debug clips by default.
Logs contain gesture events, timestamps, confidence scores, and system state only.
```

### 18.2 Debug Data Options

| Data Type | Default | Allowed With Opt-In |
|---|---:|---:|
| Raw video | Off | Yes, explicit dev mode only |
| Landmark traces | Off | Yes |
| Gesture scores | On locally | Yes |
| Action logs | On locally | Yes |
| Screenshots | Off | Future only, explicit opt-in |

### 18.3 Debug Trace Model

```swift
struct GestureDebugTrace: Codable {
    let sessionID: UUID
    let startedAt: TimeInterval
    let endedAt: TimeInterval
    let modeTransitions: [ModeTransition]
    let gestureEvents: [GestureEvent]
    let scoreSnapshots: [GestureScore]
    let powerSnapshots: [SystemPowerState]
    let containsRawVideo: Bool
    let containsScreenPixels: Bool
}

struct ModeTransition: Codable {
    let timestamp: TimeInterval
    let from: ControlMode
    let to: ControlMode
    let reason: String
}
```

### 18.4 Security Guards

```swift
func maybeRecordDebugTrace(_ trace: GestureDebugTrace) {
    guard settings.developerModeEnabled else { return }
    guard settings.debugTraceRecordingEnabled else { return }
    guard !trace.containsRawVideo || settings.rawVideoDebugOptIn else { return }
    debugTraceStore.write(trace)
}
```

### 18.5 Threat Model

| Risk | Mitigation |
|---|---|
| Camera privacy concern | Camera off in idle, visible active camera indicator |
| Accidental clicks | Temporal classifier, cooldown, overlay cursor first |
| Destructive action | Multi-step confirmation |
| Permission abuse | Minimal permissions for V1, explicit onboarding |
| Data leakage | Local-only by default, no raw video storage |
| Input hijack fear | Emergency chord and menu bar kill switch |
| Classifier false positive | Negative examples, conservative thresholds, rejection scoring |

---

## 19. Overlay UI Specification

### 19.1 UI Direction

The overlay should feel native, sleek, liquid, and spatial. It should be minimal enough for daily use but futuristic enough to make the product feel like a new interaction layer.

Visual language:

```text
liquid glass orb
soft blur
subtle refraction feel
thin glowing rim
color pulses for state
transparent HUD chips
micro animations
low visual noise
```

### 19.2 Overlay Elements

| Element | Purpose |
|---|---|
| Mode badge | Shows armed, hand, gaze, cooldown, or off |
| Pinch cursor | Virtual cursor controlled by pinched fingers |
| Gaze orb | Liquid-glass gaze cursor |
| Gesture trail | Optional faint trail for movement |
| Action pulse | Confirms action fired |
| Cooldown pulse | Shows temporary action block |
| Destructive confirmation card | Requires explicit gesture confirmation |
| Low-confidence fade | Communicates tracking uncertainty |

### 19.3 Overlay Window

```swift
final class OverlayWindow: NSWindow {
    init(screenFrame: CGRect) {
        super.init(
            contentRect: screenFrame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        isOpaque = false
        backgroundColor = .clear
        ignoresMouseEvents = true
        level = .floating
        collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .stationary
        ]
    }
}
```

### 19.4 Overlay Renderer Protocol

```swift
protocol OverlayRendering {
    func prepareHiddenWindows()
    func showModeBadge(_ mode: ControlMode)
    func hideAll(reason: ExitReason)

    func showPinchCursor(at point: ScreenPoint)
    func movePinchCursor(to point: ScreenPoint)
    func setPinchCursorState(_ state: PinchCursorVisualState)
    func hidePinchCursor()

    func showGazeOrb(at point: ScreenPoint?)
    func moveGazeOrb(to point: ScreenPoint)
    func setGazeOrbState(_ state: GazeOrbVisualState)
    func hideGazeOrb()

    func showActionPulse(for event: GestureEvent)
    func showActionPulse(for action: MacAction)
    func showCancelPulse()
    func showCooldownPulse(for gesture: GestureType)
    func showDestructiveActionPrompt(_ action: MacAction)
    func showPermissionPrompt(_ permission: PermissionKind)
    func showPowerBadge(_ profile: PowerProfile)
}
```

### 19.5 Visual States

```swift
enum PinchCursorVisualState: Codable {
    case hidden
    case searching
    case tracking
    case dragReady
    case dragging
    case cooldown
    case lowConfidence
    case actionFired
}

enum GazeOrbVisualState: Codable {
    case hidden
    case searching
    case tracking(confidence: Double)
    case targetCandidate
    case locked
    case dragReady
    case cooldown
    case lowConfidence
    case actionFired
}
```

### 19.6 Liquid Glass Gaze Orb Behavior

The gaze cursor should look like a small glass bubble or orb, not a standard mouse pointer.

| State | Orb Behavior |
|---|---|
| Searching | Faint orb, slow breathing pulse |
| Tracking | Smooth movement, rim light follows direction |
| Target candidate | Orb gently snaps, halo narrows |
| Locked | Inner dot appears, rim becomes stable |
| Action fired | Quick outward pulse, small light ripple |
| Cooldown | Orb dims, outer ring rotates or drains |
| Low confidence | Orb becomes translucent and dashed |
| Exit | Orb collapses inward and fades |

### 19.7 Suggested Color Semantics

| State | Color Direction |
|---|---|
| Hand mode | Cool blue-white |
| Gaze mode | Violet-blue glass |
| Action fired | Short green pulse |
| Cooldown | Dim amber ring |
| Cancel | Soft red fade |
| Destructive confirmation | Red-orange card with explicit text |
| Low confidence | Gray translucent |

### 19.8 SwiftUI Gaze Orb Prototype

```swift
import SwiftUI

struct GazeOrbView: View {
    let state: GazeOrbVisualState
    let confidence: Double

    @State private var pulse = false

    var body: some View {
        ZStack {
            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: orbSize, height: orbSize)
                .overlay(
                    Circle()
                        .strokeBorder(rimGradient, lineWidth: rimWidth)
                )
                .shadow(color: glowColor.opacity(glowOpacity), radius: glowRadius)
                .scaleEffect(pulseScale)
                .opacity(orbOpacity)

            if showsInnerLockDot {
                Circle()
                    .fill(Color.white.opacity(0.88))
                    .frame(width: 7, height: 7)
                    .shadow(color: Color.white.opacity(0.70), radius: 8)
            }

            if showsCooldownRing {
                Circle()
                    .trim(from: 0, to: cooldownProgress)
                    .stroke(Color.orange.opacity(0.75), lineWidth: 2)
                    .rotationEffect(.degrees(-90))
                    .frame(width: orbSize + 12, height: orbSize + 12)
            }
        }
        .animation(.spring(response: 0.18, dampingFraction: 0.78), value: stateIdentity)
        .onAppear {
            pulse = true
        }
    }

    private var orbSize: CGFloat {
        switch state {
        case .locked:
            return 38
        case .actionFired:
            return 44
        default:
            return 34
        }
    }

    private var rimWidth: CGFloat {
        state == .locked ? 2.4 : 1.4
    }

    private var rimGradient: LinearGradient {
        LinearGradient(
            colors: [Color.white.opacity(0.75), accentColor.opacity(0.85), Color.white.opacity(0.25)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var accentColor: Color {
        switch state {
        case .cooldown:
            return .orange
        case .lowConfidence:
            return .gray
        case .actionFired:
            return .green
        case .locked:
            return .cyan
        default:
            return .blue
        }
    }

    private var glowColor: Color { accentColor }

    private var glowOpacity: Double {
        switch state {
        case .lowConfidence:
            return 0.10
        case .cooldown:
            return 0.20
        case .actionFired:
            return 0.50
        default:
            return 0.30
        }
    }

    private var glowRadius: CGFloat {
        state == .actionFired ? 18 : 10
    }

    private var pulseScale: CGFloat {
        switch state {
        case .searching:
            return pulse ? 1.05 : 0.98
        case .actionFired:
            return 1.18
        default:
            return 1.0
        }
    }

    private var orbOpacity: Double {
        switch state {
        case .hidden:
            return 0.0
        case .lowConfidence:
            return 0.35
        default:
            return 0.92
        }
    }

    private var showsInnerLockDot: Bool {
        switch state {
        case .locked, .targetCandidate:
            return true
        default:
            return false
        }
    }

    private var showsCooldownRing: Bool {
        if case .cooldown = state { return true }
        return false
    }

    private var cooldownProgress: CGFloat { 0.65 }

    private var stateIdentity: String {
        String(describing: state)
    }
}
```

### 19.9 Pinch Cursor Visual

The pinch cursor should feel more mechanical and direct than the gaze orb. It can be a small glass ring with a central dot and short trail.

| State | Visual |
|---|---|
| Tracking | Glass ring with dot |
| Click fired | Fast ripple |
| Drag ready | Ring compresses slightly |
| Dragging | Ring elongates with motion trail |
| Frozen | Ring becomes square-ish or crosshair |
| Low confidence | Ring fades |

---

## 20. Training and Testing Protocols

### 20.1 Model Strategy

Version 1 should begin with a hybrid system:

```text
Landmark extraction from native Vision
Rule-based temporal gesture scorers
Recorded landmark traces for offline replay
Optional lightweight learned sequence classifier after enough data exists
```

Do not train a complex model before the rule-based system and replay harness exist. The replay harness is required to measure whether a classifier improves or worsens false positives.

### 20.2 Label Taxonomy

Positive labels:

```text
open_palm
open_palm_hold
pinch_tap
```

Phase 2 TODO positive labels:

```text
pinch_hold
pinch_move
drag_start
drag_move
drag_release
swipe_left
swipe_right
swipe_up
swipe_down
fist
```

Phase 3 TODO positive labels:

```text
back_palm
palm_flip
two_finger_pinch
gaze_lock
```

Phase 4 TODO positive labels:

```text
two_finger_swipe_left
two_finger_swipe_right
three_finger_swipe_left
three_finger_swipe_right
four_finger_swipe_left
four_finger_swipe_right
```

Confusing negative labels:

```text
not_pinch_fist
not_pinch_hand_reposition
not_swipe_reposition
not_swipe_pinch_move
not_palm_flip_wave
not_palm_flip_hand_exit
not_open_palm_back_palm_transition
not_click_face_touch
not_click_keyboard_reach
not_gesture_typing
not_gesture_background_motion
not_two_finger_swipe_reposition
not_three_finger_swipe_open_palm
not_four_finger_swipe_wave
```

### 20.3 Dataset Requirements Before Shipping

Minimum dataset for internal V1 gate:

| Category | Minimum Clips |
|---|---:|
| Pinch tap | 200 |
| Open palm cancel | 150 |
| Confusing negatives | 600 |
| Bad lighting | 150 |
| External webcam | 100 |
| Laptop webcam | 100 |
| Left hand | 200 |
| Right hand | 200 |

Future gesture release gates should add gesture-specific datasets before each phase is enabled:

| Future Category | Minimum Clips Before Enablement |
|---|---:|
| Pinch hold and drag | 200 |
| Swipe left/right/up/down | 400 total |
| Palm flip | 200 |
| Fist freeze | 150 |
| Two-finger swipe left/right | 250 total |
| Three-finger swipe left/right | 250 total |
| Four-finger swipe left/right | 250 total |
| Multi-monitor sessions | 50 |

### 20.4 Test Conditions

Test across:

```text
bright daylight
warm indoor lighting
low light
busy background
plain background
sleeves
rings
watch
left hand
right hand
external webcam
built-in laptop webcam
near camera
far from camera
standing desk
sitting desk
```

### 20.5 Evaluation Metrics

| Metric | Target |
|---|---:|
| Pinch click false positive rate | Less than 1 per 30 min active use |
| Destructive action false positive rate | 0 in test suite |
| Palm flip false positive rate | Less than 1 per 60 min active use |
| Emergency exit success rate | 100 percent |
| Hand mode active FPS | 24 to 30 in balanced mode |
| Idle CPU impact | Near zero beyond menu app and hotkey listener |
| Camera idle state | Off |
| Gaze mode confidence fallback | Low-confidence fade instead of action |

### 20.6 Replay Harness

The test harness should replay landmark traces and score outputs deterministically.

```swift
protocol GestureReplayHarness {
    func loadTrace(_ trace: GestureDebugTrace) throws
    func run(classifier: GestureClassifying) -> ReplayReport
}

struct ReplayReport: Codable {
    let totalFrames: Int
    let expectedEvents: [ExpectedGestureEvent]
    let predictedEvents: [GestureEvent]
    let falsePositives: [GestureEvent]
    let falseNegatives: [ExpectedGestureEvent]
    let latencyStats: LatencyStats
}

struct ExpectedGestureEvent: Codable {
    let type: GestureType
    let allowedTimeWindow: ClosedRange<TimeInterval>
}

struct LatencyStats: Codable {
    let p50: Double
    let p95: Double
    let p99: Double
}
```

### 20.7 Model Release Gates

Before a gesture is enabled by default:

```text
1. It must pass replay tests.
2. It must pass live user tests.
3. It must include confusing negatives.
4. It must support cooldown.
5. It must show visible overlay feedback.
6. It must be cancelable with open palm.
7. It must be interruptible with emergency exit.
```

### 20.8 Learned Model Option

After enough data exists, consider training a lightweight sequence model over landmark-derived features.

Candidate architectures:

```text
1D temporal convolutional network
small LSTM or GRU
tiny transformer encoder
hidden Markov model style rule hybrid
```

Input sequence:

```text
30 to 60 frames
normalized landmarks
pinch distance
finger curl scores
hand velocity
hand acceleration
palm orientation estimate
visibility score
```

Output:

```text
gesture class probabilities
phase probabilities
rejection class probabilities
```

Do not deploy the learned model unless it outperforms the rule-based classifier on false positive safety, not just accuracy.

---

## 21. Configuration

### 21.1 Gesture Mapping JSON

```json
{
  "activation_hotkey": "ctrl+option+cmd+space",
  "emergency_exit_hotkey": "ctrl+option+cmd+escape",
  "timeouts": {
    "armed_no_hand_seconds": 3.0,
    "active_no_hand_seconds": 5.0,
    "open_palm_exit_hold_seconds": 1.5
  },
  "cooldowns_ms": {
    "pinchTap": 300,
    "swipeLeft": 650,
    "swipeRight": 650,
    "swipeUp": 500,
    "swipeDown": 500,
    "twoFingerSwipeLeft": 850,
    "twoFingerSwipeRight": 850,
    "threeFingerSwipeLeft": 1000,
    "threeFingerSwipeRight": 1000,
    "fourFingerSwipeLeft": 1200,
    "fourFingerSwipeRight": 1200,
    "palmFlip": 850,
    "openPalm": 500
  },
  "enabled_phases": {
    "phase1CoreMVP": true,
    "phase2HandUsability": false,
    "phase3ExperimentalGaze": false,
    "phase4FuturePowerGestures": false
  },
  "hand_mode_actions": {
    "pinchTap": "leftClickAtPinchCursor",
    "openPalm": "cancel",
    "openPalmHold": "exitToIdle"
  },
  "phase2_todo_hand_mode_actions": {
    "pinchHold": "dragReady",
    "swipeLeft": "previousTab",
    "swipeRight": "nextTab",
    "swipeUp": "scrollUp",
    "swipeDown": "scrollDown",
    "fist": "freezeCursor"
  },
  "phase3_todo_gaze_mode_actions": {
    "palmFlip": "toggleGazeOnOrOff",
    "pinchTap": "leftClickAtGazeOrb",
    "pinchHold": "dragFromGazeOrb",
    "swipeUp": "scrollUpAtGazeTarget",
    "swipeDown": "scrollDownAtGazeTarget",
    "fist": "lockGazeOrb",
    "openPalm": "cancel"
  },
  "phase4_todo_power_gesture_actions": {
    "twoFingerSwipeLeft": "previousItemOrTab",
    "twoFingerSwipeRight": "nextItemOrTab",
    "threeFingerSwipeLeft": "previousWorkspaceOrAppContext",
    "threeFingerSwipeRight": "nextWorkspaceOrAppContext",
    "fourFingerSwipeLeft": "customHighLevelShortcutLeft",
    "fourFingerSwipeRight": "customHighLevelShortcutRight"
  }
}
```

### 21.2 Power Profile JSON

```json
{
  "default_power_mode": "balanced",
  "camera_off_while_idle": true,
  "disable_gaze_under_battery_percent": 20,
  "profiles": {
    "idle": {
      "cameraEnabled": false,
      "handTrackingEnabled": false,
      "gazeTrackingEnabled": false,
      "targetFPS": 0
    },
    "armedLowPower": {
      "cameraEnabled": true,
      "handTrackingEnabled": true,
      "gazeTrackingEnabled": false,
      "targetFPS": 12,
      "timeoutSeconds": 3
    },
    "handBalanced": {
      "cameraEnabled": true,
      "handTrackingEnabled": true,
      "gazeTrackingEnabled": false,
      "targetFPS": 24,
      "timeoutSeconds": 5
    },
    "gazeBalanced": {
      "cameraEnabled": true,
      "handTrackingEnabled": true,
      "gazeTrackingEnabled": true,
      "targetFPS": 24,
      "timeoutSeconds": 5
    }
  }
}
```

---

## 22. Settings UX

### 22.1 Main Settings

```text
General
- Activation hotkey
- Emergency exit hotkey
- Start at login
- Show menu bar icon

Gesture Mode
- Sensitivity: Conservative, Normal, Responsive
- Cooldown: Short, Normal, Long
- Handedness preference
- Camera control box calibration
- Future gesture packs disabled by default
- Multi-finger swipe opt-in and calibration

Gaze Mode
- Enable experimental gaze mode
- Gaze smoothing
- Gaze orb size
- Require calibration
- Disable on low battery

Power
- Best Battery
- Balanced
- High Responsiveness
- Auto-disable camera after inactivity

Privacy
- Local processing only
- Debug trace recording
- Raw video recording opt-in
- Clear debug logs

Safety
- Destructive actions disabled by default
- Require multi-step confirmation
- Reset all gesture mappings
```

### 22.2 Onboarding Flow

```text
1. Welcome and product explanation
2. Permission explanation
3. Camera permission
4. Accessibility permission
5. Activation hotkey test
6. Emergency exit test
7. Pinch cursor tutorial
8. Open palm cancel tutorial
9. Camera control box calibration
10. Power and privacy summary
```

---

## 23. Implementation Milestones

### Milestone 0: Skeleton App

```text
Menu bar app
Settings shell
Permission onboarding
Global activation hotkey
Emergency exit hotkey
Empty overlay window
Single-instance launch guard
Local app bundle packaging
Local development signing
GestureGaze-owned Camera and Accessibility permission entries
No Terminal-owned permission requirement for bundled-app testing
```

### Milestone 0A: Safety Shell Hardening

```text
Product-aligned mode model
Permission failure represented as activation status
Debug-only development controls
Explicit hotkey registration failure handling
Permission and mode routing tests
Coordinator boundary before camera and Vision services
```

### Milestone 1: Hand Tracking

```text
Camera session
Hand landmark extraction
Debug HUD
Landmark visualization
Frame scheduler
Power profiles
```

### Milestone 2: Phase 1 Core Pinch Cursor

```text
Pinch detection
Camera control box
Camera-to-screen mapping
Smoothing
Overlay cursor
Release-to-click
Cooldown
Open palm cancel
Open palm hold exit
```

### Milestone 3: Phase 2 Hand Mode Usability TODO

```text
Pinch hold
Drag start and release
Swipe left/right
Swipe up/down
Fist freeze
```

### Milestone 4: Temporal Classifier Hardening

```text
Rolling buffer
Gesture scorers
Rejection scoring
Priority resolution
Replay harness
Negative test traces
```

### Milestone 5: Phase 3 Experimental Gaze Mode TODO

```text
Palm flip toggle
Face landmarks
Coarse gaze regions
Gaze orb overlay
Pinch at gaze target
Gaze confidence fade
Fist gaze lock
```

### Milestone 6: Phase 4 Future Power Gestures TODO

```text
Two-finger swipe left/right
Three-finger swipe left/right
Four-finger swipe left/right
Extended finger-count confidence scoring
Multi-finger swipe calibration
Opt-in gesture mapping editor
Longer cooldown and candidate feedback
```

### Milestone 7: Safety and Privacy

```text
Destructive confirmation manager
Debug logging controls
No raw video by default
Battery mode
Thermal restrictions
Failure recovery
```

### Milestone 8: Polish

```text
Liquid glass overlay
Gesture pulses
Mode animations
Calibration UI
User mapping editor
Beta packaging
```

---

## 24. Failure Handling

### 24.1 Failure Scenarios

| Failure | Behavior |
|---|---|
| Camera permission revoked | Exit to idle, show permission prompt |
| Accessibility revoked | Keep overlay, block actions, show prompt |
| Hand leaves frame mid-drag | Freeze 300 ms, then cancel drag |
| Gaze confidence drops | Fade gaze orb, block gaze actions |
| Camera freezes | Exit active modes, show camera error |
| Thermal critical | Disable gaze, lower FPS, maybe exit active mode |
| Low battery | Disable gaze by default, lower FPS |
| Multi-gesture conflict | Use priority resolution |
| Emergency chord | Exit immediately |

### 24.2 Defensive Guards

```swift
func processFrame(_ frame: CameraFrame) {
    guard mode != .idle else { return }
    guard cameraManager.isRunning else {
        forceExitToIdle(reason: .cameraStopped)
        return
    }
    guard powerGovernor.allowsVisionProcessing else { return }

    let observation = visionPipeline.process(frame)
    guard observation.hand?.visibilityScore ?? 0.0 >= policy.minimumVisibility else {
        handleLowVisibility()
        return
    }

    if let event = classifier.update(with: observation) {
        router.handle(event)
    }
}
```

---

## 25. Debug HUD

### 25.1 Developer HUD Fields

```text
Mode: handGesture
FPS: 24
Power: balanced
Hand confidence: 0.91
Gesture candidate: pinchTap
Activation: 0.88
Rejection: 0.12
Final confidence: 0.76
Rejected by: cooldownActive
Cooldown remaining: 120 ms
Camera control box: calibrated
Gaze: off
```

### 25.2 HUD Model

```swift
struct DebugHUDState: Codable {
    let mode: ControlMode
    let fps: Double
    let powerProfile: PowerProfile
    let handConfidence: Double?
    let gazeConfidence: Double?
    let topGestureScores: [GestureScore]
    let cooldowns: [GestureType: Double]
    let activeAction: MacAction?
    let lastFailureReason: String?
}
```

---

## 26. Acceptance Criteria for MVP

MVP is acceptable when:

```text
1. User can activate hand mode with hotkey.
2. User can exit everything with emergency chord.
3. Camera is off in idle.
4. Pinch cursor appears reliably.
5. Pinch cursor maps to screen with smoothing.
6. Pinch release clicks only after confidence and cooldown checks.
7. Open palm cancels the current action.
8. Open palm hold exits to idle.
9. Phase 2, Phase 3, and Phase 4 gestures are disabled by default.
10. Destructive actions are not enabled by default.
11. All gesture data is local by default.
12. Debug HUD shows classifier decisions.
13. Power mode reduces FPS in low battery or thermal states.
```

---

## 27. Open Technical Risks

| Risk | Severity | Mitigation |
|---|---:|---|
| Palm flip detection unreliable | High | Sequence-based detection, conservative threshold, cooldown |
| Gaze precision weak on webcam | High | Coarse gaze regions first, target selection only |
| Battery drain | High | Camera off idle, adaptive FPS, gaze off by default |
| False-positive click | High | Temporal classifier, rejection scoring, overlay cursor first |
| macOS permission friction | Medium | Onboarding and minimal V1 permissions |
| Multi-monitor mapping confusion | Medium | Main display MVP, display selector later |
| User gesture fatigue | Medium | Short active sessions, efficient gestures |
| Overlay distraction | Medium | Fade, minimal HUD, confidence-aware visuals |
| Debugging classifier | High | Replay harness and developer HUD |

---

## 28. Reference Implementation Notes

The native app should rely primarily on Apple frameworks:

1. AVFoundation for capture session setup and camera frame flow.
2. Vision for hand pose and face landmark detection.
3. AppKit and SwiftUI for overlay windows and menu bar UI.
4. Core Graphics for generated mouse and keyboard events.
5. Accessibility APIs for trusted app control.

Important implementation stance:

```text
Use native frameworks first.
Use local-only processing.
Keep the real cursor stable until action dispatch.
Prefer overlay movement over continuous real pointer movement.
```

---

## 29. Final Product Principle

GestureGaze should feel like a futuristic spatial interface, but its core behavior should be conservative, safe, local, and transparent.

```text
Futuristic interface.
Conservative execution.
Local privacy.
Explicit control.
Trust before magic.
```



---

## 30. Native API Reference Links

These are useful implementation references for the native macOS direction. They are not product requirements by themselves, but they guide the technical stack.

- Vision hand pose detection: https://developer.apple.com/documentation/vision/vndetecthumanhandposerequest
- Vision face landmarks: https://developer.apple.com/documentation/vision/vndetectfacelandmarksrequest
- AVFoundation capture sessions: https://developer.apple.com/documentation/avfoundation/avcapturesession
- Core Graphics event posting: https://developer.apple.com/documentation/coregraphics/cgevent/post(tap:)
- Accessibility trust checks: https://developer.apple.com/documentation/applicationservices/1459186-axisprocesstrustedwithoptions
- Global event monitoring: https://developer.apple.com/documentation/appkit/nsevent/addglobalmonitorforevents(matching:handler:)
- NSWindow overlay behavior: https://developer.apple.com/documentation/appkit/nswindow
