// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Pullo",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.10.0"),
    ],
    targets: [
        .executableTarget(
            name: "Pullo",
            dependencies: [.product(name: "Sparkle", package: "Sparkle")],
            path: "Sources/Pullo",
            exclude: ["Resources/Localizable.xcstrings", "Resources/InfoPlist.xcstrings"]
        ),
        .testTarget(name: "PulloTests", dependencies: ["Pullo"], path: "Tests/PulloTests"),
    ]
)
