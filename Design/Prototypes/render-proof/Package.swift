// swift-tools-version:6.0
// PROTOTYPE — throwaway. See README.md.
import PackageDescription

let package = Package(
    name: "GemSpike",
    platforms: [.macOS(.v15)],
    targets: [
        .executableTarget(
            name: "GemSpike",
            path: "Sources/GemSpike",
            resources: [.copy("shaders.metal")],
            swiftSettings: [.swiftLanguageMode(.v5)]   // prototype: no concurrency ceremony
        )
    ]
)
