// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "gaze-gestures",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "GazeGestures",
            targets: ["GazeGesturesApp"]
        )
    ],
    targets: [
        .executableTarget(
            name: "GazeGesturesApp"
        )
    ]
)
