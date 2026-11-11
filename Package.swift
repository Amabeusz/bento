// swift-tools-version:6.2
import PackageDescription

let package = Package(
    name: "bento",
    platforms: [.macOS(.v26)],
    targets: [
        .target(name: "BentoCore"),
        .executableTarget(
            name: "bento", dependencies: ["BentoCore"],
            linkerSettings: [.unsafeFlags(["-F/System/Library/PrivateFrameworks", "-framework", "SkyLight"])]),
        .testTarget(name: "BentoCoreTests", dependencies: ["BentoCore"]),
    ]
)
