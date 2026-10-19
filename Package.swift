// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "DevNotch",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.10.0"),
    ],
    targets: [
        .executableTarget(
            name: "DevNotch",
            dependencies: [.product(name: "Sparkle", package: "Sparkle")],
            path: "Sources/DevNotch"
        ),
        .testTarget(name: "DevNotchTests", dependencies: ["DevNotch"], path: "Tests/DevNotchTests"),
    ]
)
