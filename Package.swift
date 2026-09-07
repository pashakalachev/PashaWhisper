// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PashaWhisper",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "PashaWhisper", targets: ["PashaWhisper"])],
    targets: [
        .target(name: "WhisperCore"),
        .executableTarget(name: "PashaWhisper", dependencies: ["WhisperCore"], resources: [.copy("Resources/cat-emblem.png")]),
        .testTarget(name: "WhisperCoreTests", dependencies: ["WhisperCore", "PashaWhisper"])
    ]
)
