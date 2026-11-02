// swift-tools-version:6.2
import PackageDescription

let package = Package(
    name: "hyprmac",
    platforms: [.macOS(.v26)],
    targets: [
        .target(name: "HyprCore"),
        .executableTarget(name: "hyprmac", dependencies: ["HyprCore"]),
        .testTarget(name: "HyprCoreTests", dependencies: ["HyprCore"]),
    ]
)
