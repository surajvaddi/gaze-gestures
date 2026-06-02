import SwiftUI

struct PinchCursorOverlayLayout: Equatable {
    var screenBounds: ScreenBounds

    func localPoint(for point: ScreenPoint) -> ScreenPoint {
        ScreenPoint(
            x: point.x - screenBounds.origin.x,
            y: screenBounds.height - (point.y - screenBounds.origin.y)
        )
    }
}

struct PinchCursorOverlayView: View {
    @ObservedObject var appState: AppState
    let screenBounds: ScreenBounds

    var body: some View {
        GeometryReader { _ in
            ZStack {
                if case .visible(let point) = appState.virtualCursorState {
                    let localPoint = PinchCursorOverlayLayout(
                        screenBounds: screenBounds
                    ).localPoint(for: point)

                    Circle()
                        .fill(.green.opacity(0.85))
                        .overlay {
                            Circle()
                                .strokeBorder(.white.opacity(0.80), lineWidth: 2)
                        }
                        .shadow(color: .green.opacity(0.45), radius: 10)
                        .frame(width: 18, height: 18)
                        .position(x: localPoint.x, y: localPoint.y)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .allowsHitTesting(false)
        .background(Color.clear)
    }
}
