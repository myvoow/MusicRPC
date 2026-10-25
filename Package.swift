// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "MusicRPC",
    platforms: [.macOS("26.0")],
    targets: [
        .executableTarget(name: "MusicRPC", path: "Sources"),
        .testTarget(name: "MusicRPCTests", dependencies: ["MusicRPC"], path: "Tests"),
    ],
    swiftLanguageModes: [.v5]
)
