// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AntigravityStats",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "AntigravityStats",
            path: "Sources/AntigravityStats",
            exclude: ["Resources"]
        )
    ]
)
