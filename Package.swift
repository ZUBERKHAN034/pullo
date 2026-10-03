// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "DevNotch",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "DevNotch", path: "Sources/DevNotch"),
        .testTarget(name: "DevNotchTests", dependencies: ["DevNotch"], path: "Tests/DevNotchTests"),
    ]
)
