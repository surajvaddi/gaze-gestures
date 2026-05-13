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
            name: "GazeGesturesApp",
            exclude: ["Resources/Info.plist"],
            linkerSettings: [
                .unsafeFlags(
                    [
                        "-Xlinker", "-sectcreate",
                        "-Xlinker", "__TEXT",
                        "-Xlinker", "__info_plist",
                        "-Xlinker", "Sources/GazeGesturesApp/Resources/Info.plist"
                    ],
                    .when(platforms: [.macOS])
                )
            ]
        ),
        .testTarget(
            name: "GazeGesturesAppTests",
            dependencies: ["GazeGesturesApp"]
        )
    ]
)
