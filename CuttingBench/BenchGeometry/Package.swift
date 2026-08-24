// swift-tools-version:6.0
import PackageDescription

let package = Package(
  name: "BenchGeometry",
  platforms: [.macOS(.v15)],
  products: [
    .library(name: "BenchGeometry", targets: ["BenchGeometry"])
  ],
  dependencies: [
    .package(path: "../../Kernel")
  ],
  targets: [
    // A path dependency's identity is its directory name, so the `package:` label is `Kernel` even
    // though the manifest there declares the name `FacetKernel`.
    .target(
      name: "BenchGeometry", dependencies: [.product(name: "FacetKernel", package: "Kernel")]),
    .testTarget(name: "BenchGeometryTests", dependencies: ["BenchGeometry"]),
  ]
)
