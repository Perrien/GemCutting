import FacetKernel
import Foundation
import XCTest

@testable import BenchGeometry

/// The authored patterns, read from `Design/Patterns/` rather than copied into the package — one corpus,
/// so a pattern edit cannot pass here and fail in the app. Mirrors
/// `Kernel/Tests/FacetKernelTests/PatternDecodingTests.swift`.
enum AuthoredPatterns {
  static let directory: URL =
    URL(fileURLWithPath: #filePath)  // .../CuttingBench/BenchGeometry/Tests/BenchGeometryTests/…
    .deletingLastPathComponent()  // BenchGeometryTests
    .deletingLastPathComponent()  // Tests
    .deletingLastPathComponent()  // BenchGeometry
    .deletingLastPathComponent()  // CuttingBench
    .deletingLastPathComponent()  // repository root
    .appendingPathComponent("Design")
    .appendingPathComponent("Patterns")

  static let easyOctagon = "Pattern-Easy-Octagon"
  static let noviceAsher = "Pattern-Novice-Ash-er"
  static let rands = "Pattern-Rands-Cut-Corner-Rectangle"
  static let roundBrilliant = "Pattern-Standard-Round-Brilliant"

  static let all = [easyOctagon, noviceAsher, rands, roundBrilliant]

  static func url(_ name: String) -> URL {
    directory.appendingPathComponent(name).appendingPathExtension("json")
  }

  // `Pattern` is qualified throughout this target: XCTest pulls in ApplicationServices, whose
  // Quickdraw.h declares a `Pattern` struct, and the bare name is ambiguous in a test file.
  static func load(_ name: String) throws -> FacetKernel.Pattern {
    try JSONDecoder().decode(FacetKernel.Pattern.self, from: Data(contentsOf: url(name)))
  }
}

final class BenchSolidTests: XCTestCase {
  private let tol = 1e-9

  // MARK: - No pattern

  func testWithNoPatternTheSolidIsTheBarePrism() {
    let solid = benchSolid(for: nil)
    XCTAssertEqual(solid.planes.count, 18)
    XCTAssertEqual(solid.origin.count, 18)
    XCTAssertEqual(solid.polytope.facets.count, 18)
    XCTAssertEqual(solid.polytope.vertices.count, 32)
    XCTAssertEqual(solid.origin[0], .rough(.crownCap))

    for index in 0..<18 {
      guard case .rough = solid.origin[index] else {
        return XCTFail("plane \(index) is not rough")
      }
    }
  }

  // MARK: - D1's promise: rough adds nothing to a finished stone

  func testAFinishedPatternAddsNothingToTheKernelsOwnSolid() throws {
    for name in AuthoredPatterns.all {
      let pattern = try AuthoredPatterns.load(name)
      let kernel = try solve(pattern).polytope
      let bench = benchSolid(for: pattern)

      XCTAssertEqual(bench.polytope.facets.count, kernel.facets.count, name)
      XCTAssertEqual(bench.polytope.vertices.count, kernel.vertices.count, name)
      XCTAssertTrue(bench.roughFacetIndices.isEmpty, name)
      XCTAssertEqual(bench.cutFacetIndices.count, bench.polytope.facets.count, name)
    }
  }

  // MARK: - The plane indices

  func testAClosedPatternsPlanesStartAtZeroAndCarryTheirOwners() throws {
    let pattern = try AuthoredPatterns.load(AuthoredPatterns.easyOctagon)
    let solution = try solve(pattern)
    let bench = benchSolid(for: pattern)

    XCTAssertFalse(bench.includesRough)
    XCTAssertEqual(bench.planes.count, solution.planes.count)

    for (k, owner) in solution.planeOwner {
      XCTAssertEqual(
        bench.origin[k],
        .cut(FacetRef(tier: owner.tier, index: owner.index)),
        "solved plane \(k)")
    }
  }

  // MARK: - The scaffolding rule: the rough leaves when the pattern stands up on its own

  func testAClosedPatternDropsTheRoughEntirely() throws {
    for name in AuthoredPatterns.all {
      let pattern = try AuthoredPatterns.load(name)
      let solved = try solve(pattern)
      let bench = benchSolid(for: pattern)

      XCTAssertFalse(bench.includesRough, name)
      XCTAssertEqual(bench.planes.count, solved.planes.count, name)
    }
  }

  /// The solve has already turned these planes into a solid, and with the scaffolding gone they are the
  /// same planes in the same order — so the app hands back that polytope rather than building it twice.
  func testAClosedPatternsSolidIsTheSolvesOwnPolytope() throws {
    for name in AuthoredPatterns.all {
      let pattern = try AuthoredPatterns.load(name)
      let solved = try solve(pattern)
      let bench = benchSolid(for: pattern)

      XCTAssertEqual(Set(bench.polytope.facets.keys), Set(solved.polytope.facets.keys), name)
      XCTAssertEqual(bench.polytope.vertices.count, solved.polytope.vertices.count, name)
    }
  }

  func testAnOpenPatternKeepsTheRoughAsScaffolding() throws {
    let pattern = try AuthoredPatterns.load(AuthoredPatterns.noviceAsher)
    let solid = benchSolid(for: pattern, tierLimit: 2)

    XCTAssertTrue(solid.includesRough)

    let cut = solid.origin.values.filter { origin in
      guard case .cut = origin else { return false }
      return true
    }
    XCTAssertEqual(solid.planes.count, roughPlaneCount + cut.count)

    // This solid is the app's own intersection rather than the solve's: it carries facets below the
    // pattern's base, which the solve's rough-free polytope cannot have.
    XCTAssertTrue(solid.polytope.facets.keys.contains { $0 < roughPlaneCount })
  }

  func testWithNoPatternTheRoughIsAllThereIs() {
    let solid = benchSolid(for: nil)

    XCTAssertTrue(solid.includesRough)
    XCTAssertEqual(solid.planes.count, 18)
  }

  // MARK: - The part-cut state, which no authored pattern can show

  func testAHalfCutStoneKeepsRoughAndCut() throws {
    let pattern = try AuthoredPatterns.load(AuthoredPatterns.noviceAsher)
    let solid = benchSolid(for: pattern, tierLimit: 2)

    XCTAssertFalse(solid.roughFacetIndices.isEmpty)
    XCTAssertFalse(solid.cutFacetIndices.isEmpty)
  }

  /// D5: the prism clears the deepest *intermediate* axial point, not just the final culet.
  /// `Novice Ash-er`'s `P1` point forms at −1.19175 before `P2` and `P3` cut it back.
  func testTheRoughIsDeepEnoughForAnIntermediatePoint() throws {
    let pattern = try AuthoredPatterns.load(AuthoredPatterns.noviceAsher)
    let solid = benchSolid(for: pattern, tierLimit: 2)

    let lowest = try XCTUnwrap(solid.polytope.vertices.map(\.z).min())
    XCTAssertLessThan(lowest, -1.19)
    XCTAssertGreaterThan(lowest, -1.20)

    // The bottom cap is not a facet of the solid, so the temporary point sits inside the rough rather
    // than being clipped by it.
    XCTAssertNil(solid.polytope.facets[1])
  }

  func testTruncationDoesNotDisturbAnEarlierTiersDepth() throws {
    let pattern = try AuthoredPatterns.load(AuthoredPatterns.noviceAsher)

    let truncated = depths(of: "P1", in: benchSolid(for: pattern, tierLimit: 2))
    let whole = depths(of: "P1", in: benchSolid(for: pattern, tierLimit: nil))

    XCTAssertFalse(truncated.isEmpty)
    XCTAssertEqual(truncated.count, whole.count)
    for (a, b) in zip(truncated, whole) {
      XCTAssertEqual(a, b, accuracy: tol)
    }
  }

  func testATierLimitOfZeroIsTheBarePrism() throws {
    let pattern = try AuthoredPatterns.load(AuthoredPatterns.noviceAsher)
    let solid = benchSolid(for: pattern, tierLimit: 0)
    let bare = benchSolid(for: nil)

    XCTAssertEqual(solid.polytope.facets.count, bare.polytope.facets.count)
    XCTAssertEqual(solid.polytope.vertices.count, bare.polytope.vertices.count)
  }

  // MARK: - Helpers

  /// The solved plane offsets belonging to one tier, in plane order.
  private func depths(of tier: String, in solid: BenchSolid) -> [Double] {
    solid.planes.indices.compactMap { index in
      guard case .cut(let facet) = solid.origin[index], facet.tier == tier else { return nil }
      return solid.planes[index].d
    }
  }
}
