// swift-tools-version:6.0
import PackageDescription

let package = Package(
  name: "FacetKernel",
  platforms: [.macOS(.v15)],
  products: [
    .library(name: "FacetKernel", targets: ["FacetKernel"])
  ],
  targets: [
    .target(name: "FacetKernel"),
    .testTarget(name: "FacetKernelTests", dependencies: ["FacetKernel"]),
  ]
)
