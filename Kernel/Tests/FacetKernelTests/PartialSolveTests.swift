import Foundation
import XCTest

@testable import FacetKernel

/// A pattern that half-solves is the normal state of authoring, not an edge case — it is what every
/// pattern is while it is being written. `solveAsFarAsPossible` is what makes that state something the app
/// can draw instead of a cliff.
///
/// What the prefixes of Easy Octagon actually look like, measured, because it is what the display slice
/// will be drawing: `G1` alone yields **0 facets** — eight mutually parallel vertical planes, no triple
/// meeting at a point, so nothing bounds a solid. `G1 P1` yields **8**, all of them the pavilion's: an
/// open-topped solid leaves each girdle plane only two vertices, and `Polytope.swift:67`
/// (`guard onPlane.count >= 3 else { continue }`) drops it. So a pattern's own planes render a floating
/// pavilion cone with no girdle and no top until something caps the solid — and nothing here caps it,
/// because a capped solid always closes and would defeat the closure check the tool exists to run.
final class PartialSolveTests: XCTestCase {
  private let girdle = 0.033700

  // MARK: - Where it stops

  /// Easy Octagon with `C2` aimed at a tier that does not exist. `C3` is never cut, so `C2` cannot be
  /// placed — and the four tiers before it are unaffected, because a depth is computed from the planes
  /// already placed and nothing later can reach back.
  func testAStoppedSolveKeepsWhatItPlaced() throws {
    let pattern = try Self.easyOctagonWithC2Adrift()

    XCTAssertThrowsError(try solve(pattern)) { error in
      XCTAssertEqual(
        error as? SolverError,
        .unknownFacet(tier: "C2", named: FacetRef(tier: "C3", index: 0))
      )
    }

    let partial = solveAsFarAsPossible(pattern, girdleTargetFraction: girdle)

    XCTAssertEqual(partial.solution.tiers.map(\.tier), ["G1", "P1", "P2", "C1"])
    XCTAssertEqual(partial.solution.planes.count, 32)
    XCTAssertEqual(partial.solution.planeOwner.count, 32)
    XCTAssertEqual(partial.solution.polytope.facets.count, 32)
    XCTAssertEqual(partial.failure?.tier, "C2")
    XCTAssertEqual(
      partial.failure,
      .unknownFacet(tier: "C2", named: FacetRef(tier: "C3", index: 0)),
      "the same failure the throw carried"
    )
  }

  /// The assertion that catches a partial solve leaving stale state behind: what it placed is what solving
  /// the same pattern truncated to those tiers gives, to the last bit.
  func testThePartialResultEqualsTheTruncatedPatternsFullResult() throws {
    let partial = solveAsFarAsPossible(
      try Self.easyOctagonWithC2Adrift(), girdleTargetFraction: girdle)

    var truncated = try AuthoredPatterns.load(AuthoredPatterns.easyOctagon)
    truncated.tiers = Array(truncated.tiers.prefix(4))
    truncated.state = .inProgress
    let whole = try solve(truncated, girdleTargetFraction: girdle)

    XCTAssertEqual(partial.solution.planes.count, whole.planes.count)
    XCTAssertEqual(partial.solution.polytope.facets.count, whole.polytope.facets.count)
    XCTAssertEqual(partial.solution.tiers.count, whole.tiers.count)
    for (placed, expected) in zip(partial.solution.tiers, whole.tiers) {
      XCTAssertEqual(placed.tier, expected.tier)
      XCTAssertEqual(placed.d, expected.d, accuracy: 1e-12, placed.tier)
    }
  }

  /// Stopping on the very first tier is handled, and it is not a special case in the code: a `girdle` meet
  /// needs the outline's width, and before any vertical plane is placed the outline is not bounded.
  func testAPatternThatStopsOnItsFirstTier() {
    let pattern = FacetKernel.Pattern(
      formatVersion: 1,
      name: "girdle first",
      state: .inProgress,
      wheel: 96,
      ri: 1.54,
      designer: "",
      notes: "",
      tiers: [
        TierSpec(
          tier: "C1", part: .crown, angle: 42, indices: Self.octagon, meet: .girdle)
      ]
    )

    let partial = solveAsFarAsPossible(pattern)

    XCTAssertTrue(partial.solution.tiers.isEmpty)
    XCTAssertTrue(partial.solution.planes.isEmpty)
    XCTAssertEqual(partial.solution.polytope.facets.count, 0)
    XCTAssertEqual(partial.failure?.tier, "C1")
    XCTAssertEqual(partial.failure, .girdleOutlineUndetermined(tier: "C1"))
  }

  // MARK: - When nothing stops it

  func testACleanPatternComesBackWithNoFailure() throws {
    let pattern = try AuthoredPatterns.load(AuthoredPatterns.easyOctagon)
    let partial = solveAsFarAsPossible(pattern, girdleTargetFraction: girdle)
    let thrown = try solve(pattern, girdleTargetFraction: girdle)

    XCTAssertNil(partial.failure)
    XCTAssertEqual(partial.solution.planes.count, thrown.planes.count)
    XCTAssertEqual(partial.solution.polytope.facets.count, thrown.polytope.facets.count)
    XCTAssertEqual(partial.solution.tiers.count, thrown.tiers.count)
    for (fromPartial, fromThrow) in zip(partial.solution.tiers, thrown.tiers) {
      XCTAssertEqual(fromPartial.tier, fromThrow.tier)
      XCTAssertEqual(fromPartial.d, fromThrow.d, accuracy: 1e-12, fromPartial.tier)
    }
  }

  /// Every case of `SolverError` names the tier it stopped on, and `tier` is the library's one switch over
  /// that. A case added without a tier would not compile; one added and left out of `tier` would.
  func testEveryFailureNamesItsTier() {
    let cases: [SolverError] = [
      .forwardReference(tier: "A", named: "B"),
      .namesOwnFacet(tier: "A"),
      .unknownFacet(tier: "A", named: FacetRef(tier: "B", index: 0)),
      .singularTriple(tier: "A"),
      .secondTCPOnSide(tier: "A", part: .pav),
      .noAxialPointOnSide(tier: "A", part: .crown),
      .girdleOutlineUndetermined(tier: "A"),
      .vertexNeedsThreeFacets(tier: "A", count: 2),
      .fractionEndpointNotVertexOrTCP(tier: "A", kind: "girdle"),
      .tierHasNoIndices(tier: "A"),
    ]

    XCTAssertEqual(cases.count, 10)
    for failure in cases {
      XCTAssertEqual(failure.tier, "A", "\(failure)")
    }
  }

  // MARK: - The prefixes the display slice will draw

  func testTheFirstTwoPrefixesOfEasyOctagon() throws {
    let pattern = try AuthoredPatterns.load(AuthoredPatterns.easyOctagon)

    var girdleOnly = pattern
    girdleOnly.tiers = Array(pattern.tiers.prefix(1))
    girdleOnly.state = .inProgress
    let bare = solveAsFarAsPossible(girdleOnly, girdleTargetFraction: girdle)
    XCTAssertNil(bare.failure)
    XCTAssertEqual(bare.solution.planes.count, 8)
    XCTAssertEqual(bare.solution.polytope.facets.count, 0, "no triple of parallel planes meets")

    var withPavilion = pattern
    withPavilion.tiers = Array(pattern.tiers.prefix(2))
    withPavilion.state = .inProgress
    let cone = solveAsFarAsPossible(withPavilion, girdleTargetFraction: girdle)
    XCTAssertNil(cone.failure)
    XCTAssertEqual(cone.solution.planes.count, 16)
    XCTAssertEqual(
      cone.solution.polytope.facets.count, 8, "the pavilion's, and none of the girdle's")
    for plane in cone.solution.polytope.facets.keys {
      XCTAssertEqual(cone.solution.planeOwner[plane]?.tier, "P1")
    }
  }

  // MARK: - Fixtures

  private static let octagon = [0, 12, 24, 36, 48, 60, 72, 84]

  /// Easy Octagon with `C2`'s vertex aimed at `C3@0`, a tier the pattern never cuts.
  private static func easyOctagonWithC2Adrift() throws -> FacetKernel.Pattern {
    var pattern = try AuthoredPatterns.load(AuthoredPatterns.easyOctagon)
    let c2 = try XCTUnwrap(pattern.tiers.firstIndex { $0.tier == "C2" })
    pattern.tiers[c2].meet = .vertex(facets: [
      FacetRef(tier: "C3", index: 0),
      FacetRef(tier: "G1", index: 24),
      FacetRef(tier: "C1", index: 12),
    ])
    return pattern
  }
}
