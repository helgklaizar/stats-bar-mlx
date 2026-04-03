// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AntigravityBar",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "AntigravityBar",
            path: "Sources/AntigravityBar",
            exclude: ["Resources"]
        ),
        .testTarget(
            name: "AntigravityBarTests",
            dependencies: ["AntigravityBar"],
            path: "Tests/AntigravityBarTests"
        )
    ]
)
