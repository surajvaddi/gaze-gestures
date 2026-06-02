import AppKit

struct AppKitScreenBoundsProvider: ScreenBoundsProviding {
    func currentScreenBounds() -> ScreenBounds? {
        guard let frame = NSScreen.main?.frame else {
            return nil
        }

        return ScreenBounds(
            origin: ScreenPoint(
                x: Double(frame.origin.x),
                y: Double(frame.origin.y)
            ),
            width: Double(frame.width),
            height: Double(frame.height)
        )
    }
}
