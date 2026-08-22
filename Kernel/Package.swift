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
    .executableTarget(name: "facetsolve", dependencies: ["FacetKernel"]),
    // The CLI is a dependency of the tests so `swift test` builds it: the checks that cover it run it as
    // a subprocess, the way the owner does.
    .testTarget(name: "FacetKernelTests", dependencies: ["FacetKernel", "facetsolve"]),
  ]
)
