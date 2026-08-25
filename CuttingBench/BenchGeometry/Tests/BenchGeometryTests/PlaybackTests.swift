import FacetKernel
import Foundation
import XCTest

@testable import BenchGeometry

/// The playback step list, read off the corpus and off one constructed tier the corpus cannot reach.
/// `AuthoredPatterns` lives in `BenchSolidTests.swift`.
final class PlaybackTests: XCTestCase {

  // MARK: - No pattern is no sequence

  func testNoPatternIsNoSequence() {
    let bare = benchSolid(for: nil)

    XCTAssertTrue(playbackSteps(bare, granularity: .tier).isEmpty)
    XCTAssertTrue(playbackSteps(bare, granularity: .facet).isEmpty)
  }

  // MARK: - Step 0 is the preform, at both granularities

  func testStepZeroIsTheRoughWithNothingCut() throws {
    let solid = try solid(of: AuthoredPatterns.easyOctagon)

    for granularity in PlaybackGranularity.allCases {
      let step = try XCTUnwrap(playbackSteps(solid, granularity: granularity).first)

      XCTAssertEqual(step.completeTiers, 0, granularity.rawValue)
      XCTAssertNil(step.partialTier, granularity.rawValue)
      XCTAssertEqual(step.partialStops, [], granularity.rawValue)
      XCTAssertEqual(step.id, 0, granularity.rawValue)
      XCTAssertEqual(step.label, "rough · nothing cut", granularity.rawValue)
    }
  }

  // MARK: - Tier granularity counts the placed tiers

  func testTierGranularityIsOneStepPerPlacedTierPlusThePreform() throws {
    let solid = try solid(of: AuthoredPatterns.easyOctagon)
    let steps = playbackSteps(solid, granularity: .tier)

    XCTAssertEqual(solid.tiers.count, 6)
    XCTAssertEqual(steps.count, 7)

    let last = try XCTUnwrap(steps.last)
    XCTAssertEqual(last.completeTiers, 6)
    XCTAssertNil(last.partialTier)

    XCTAssertEqual(steps[1].label, "G1 · tier 1/6")
    XCTAssertEqual(steps.map(\.id), Array(0...6))
  }

  // MARK: - Facet granularity counts every stop

  func testFacetGranularityIsOneStepPerStopPlusThePreform() throws {
    let expected = [
      AuthoredPatterns.easyOctagon: 37,
      AuthoredPatterns.roundBrilliant: 73,
      AuthoredPatterns.rands: 53,
    ]

    for (name, stops) in expected {
      let solid = try solid(of: name)
      let steps = playbackSteps(solid, granularity: .facet)

      XCTAssertEqual(solid.tiers.reduce(0) { $0 + $1.indices.count }, stops, name)
      XCTAssertEqual(steps.count, stops + 1, name)
      XCTAssertEqual(steps.map(\.id), Array(0...stops), name)
    }

    XCTAssertEqual(try solid(of: AuthoredPatterns.rands).tiers.count, 12)
  }

  func testAFacetStepReadsItsTierItsOwnCountAndTheWholePattern() throws {
    let steps = playbackSteps(try solid(of: AuthoredPatterns.easyOctagon), granularity: .facet)

    XCTAssertEqual(steps[1].label, "G1 · facet 1/8 · 1/37")
    XCTAssertEqual(steps[8].label, "G1 · facet 8/8 · 8/37")
  }

  // MARK: - The two lists are two views of one sequence

  /// A tier's last facet step is that tier's tier step: same complete-tier count, no partial tier.
  func testATiersLastFacetStepIsThatTiersTierStep() throws {
    for name in AuthoredPatterns.all {
      let solid = try solid(of: name)
      let tierSteps = playbackSteps(solid, granularity: .tier)
      let boundaries = playbackSteps(solid, granularity: .facet)
        .filter { $0.partialTier == nil && $0.id > 0 }

      XCTAssertEqual(
        boundaries.map(\.completeTiers),
        Array(1...solid.tiers.count),
        name)
      XCTAssertEqual(
        boundaries.map(\.completeTiers),
        tierSteps.filter { $0.id > 0 }.map(\.completeTiers),
        name)
      for step in boundaries {
        XCTAssertEqual(step.partialStops, [], "\(name) step \(step.id)")
      }
    }
  }

  // MARK: - The case the corpus does not cover: a tier whose stops are not ascending

  /// Every authored pattern stores its stops ascending, so only a constructed tier exercises the sort.
  func testFacetStepsWalkTheStopsAscendingWhateverOrderTheTierWroteThem() {
    let solid = descendingTierSolid()
    let steps = playbackSteps(solid, granularity: .facet)

    XCTAssertEqual(steps.count, 9)
    XCTAssertEqual(steps[1].partialStops, [0])
    XCTAssertEqual(steps[2].partialStops, [0, 12])
    XCTAssertEqual(steps[3].partialStops, [0, 12, 24])
    XCTAssertEqual(steps[1].partialTier, "T")
    XCTAssertEqual(steps[1].label, "T · facet 1/8 · 1/8")
  }

  /// The sort is a derived value inside a step and never written back: the tier table's Indices cell
  /// reads the pattern's own order, and that order is data.
  func testTheTiersOwnIndicesAreNotReordered() throws {
    let solid = descendingTierSolid()
    _ = playbackSteps(solid, granularity: .facet)
    _ = playbackSteps(solid, granularity: .tier)

    let tier = try XCTUnwrap(solid.tiers.first)
    XCTAssertEqual(tier.indices, [84, 72, 60, 48, 36, 24, 12, 0])
  }

  // MARK: - The step's solid, with no re-solve

  /// The end of the sequence is the stone the document already shows, so entering playback cannot make
  /// the picture jump.
  func testTheLastStepIsTheWholeStone() throws {
    for name in AuthoredPatterns.all {
      let full = try solid(of: name)

      for granularity in PlaybackGranularity.allCases {
        let steps = playbackSteps(full, granularity: granularity)
        let last = benchSolid(full, at: try XCTUnwrap(steps.last))
        let context = "\(name) \(granularity.rawValue)"

        XCTAssertEqual(last.polytope.facets.count, full.polytope.facets.count, context)
        XCTAssertEqual(last.polytope.vertices.count, full.polytope.vertices.count, context)
        XCTAssertEqual(last.includesRough, full.includesRough, context)
        XCTAssertEqual(last.cutFacetIndices.count, full.cutFacetIndices.count, context)
        XCTAssertEqual(last.roughFacetIndices.count, full.roughFacetIndices.count, context)
        XCTAssertEqual(last.solution?.tiers.count, full.solution?.tiers.count, context)
      }
    }
  }

  /// The test that proves the prefix path: re-expanding the whole solve's own tiers gives what
  /// truncating the *pattern* and solving it again gives. Two independent routes to one geometry — the
  /// tier-limit parameter earns its keep as the oracle.
  func testAPrefixOfTheSolveMatchesTruncatingThePatternAndSolvingAgain() throws {
    for (name, tiers) in [(AuthoredPatterns.easyOctagon, 6), (AuthoredPatterns.rands, 12)] {
      let pattern = try AuthoredPatterns.load(name)
      let full = benchSolid(for: pattern)
      let steps = playbackSteps(full, granularity: .tier)

      XCTAssertEqual(steps.count, tiers + 1, name)

      for n in 0...tiers {
        let prefix = benchSolid(full, at: steps[n])
        let resolved = benchSolid(for: pattern, tierLimit: n)
        let context = "\(name) at \(n) tiers"

        XCTAssertEqual(prefix.polytope.facets.count, resolved.polytope.facets.count, context)
        XCTAssertEqual(prefix.polytope.vertices.count, resolved.polytope.vertices.count, context)
        XCTAssertEqual(prefix.includesRough, resolved.includesRough, context)
        XCTAssertEqual(
          prefix.solution?.tiers.map(\.tier), resolved.solution?.tiers.map(\.tier), context)
      }
    }
  }

  func testStepZeroIsTheBarePrism() throws {
    let full = try solid(of: AuthoredPatterns.easyOctagon)
    let steps = playbackSteps(full, granularity: .facet)
    let preform = benchSolid(full, at: steps[0])
    let bare = benchSolid(for: nil)

    XCTAssertEqual(preform.polytope.facets.count, bare.polytope.facets.count)
    XCTAssertEqual(preform.polytope.vertices.count, bare.polytope.vertices.count)
    XCTAssertEqual(preform.polytope.facets.count, 18)
    XCTAssertEqual(preform.polytope.vertices.count, 32)

    for (index, origin) in preform.origin {
      guard case .rough = origin else {
        return XCTFail("plane \(index) of the preform is not rough")
      }
    }
  }

  /// A part-cut tier is the last of the prefix and the tiers below it are whole — the step is a stone
  /// mid-cut, not a stone missing its base.
  func testAPartCutTierKeepsTheTiersBelowItWhole() throws {
    let full = try solid(of: AuthoredPatterns.easyOctagon)
    let steps = playbackSteps(full, granularity: .facet)
    let step = try XCTUnwrap(steps.first { $0.label == "P1 · facet 3/8 · 11/37" })
    let solid = benchSolid(full, at: step)

    let tiers = try XCTUnwrap(solid.solution?.tiers)
    XCTAssertEqual(tiers.map(\.tier), ["G1", "P1"])
    XCTAssertEqual(tiers.last?.indices, [0, 12, 24])
    XCTAssertTrue(solid.includesRough)
  }

  /// Mid-scrub the tier that stopped the solve has not been reached, so no step but the last claims it.
  func testTheStopBelongsToTheLastStepAlone() throws {
    let full = benchSolid(for: try brokenAsher())
    let steps = playbackSteps(full, granularity: .tier)

    XCTAssertEqual(full.solution?.tiers.map(\.tier), ["G", "P1"])
    XCTAssertEqual(steps.count, 3)

    let last = benchSolid(full, at: steps[2])
    XCTAssertEqual(last.stoppedAtTier, "P2")
    XCTAssertEqual(last.stoppedReason, "tier P2: there is no facet P9@24")

    for id in 0...1 {
      let earlier = benchSolid(full, at: steps[id])
      XCTAssertNil(earlier.stoppedAtTier, "step \(id)")
      XCTAssertNil(earlier.stoppedReason, "step \(id)")
    }
  }

  /// Every step reads the same whole solve, so building one may not disturb the next.
  func testTheWholeSolveIsNotMutatedByBuildingItsSteps() throws {
    let full = try solid(of: AuthoredPatterns.easyOctagon)
    let before = full.solution?.tiers.map(\.indices)

    for step in playbackSteps(full, granularity: .facet) {
      _ = benchSolid(full, at: step)
    }

    XCTAssertEqual(full.solution?.tiers.map(\.indices), before)
  }

  // MARK: - A frame is a step's solid and its mesh

  func testAFrameCarriesTheStepsSolidAndThatSolidsMesh() throws {
    let full = try solid(of: AuthoredPatterns.easyOctagon)
    let steps = playbackSteps(full, granularity: .tier)
    let step = steps[3]

    let solid = benchSolid(full, at: step)
    let frame = playbackFrame(full, at: step)

    XCTAssertEqual(frame.solid.polytope.facets.count, solid.polytope.facets.count)
    XCTAssertEqual(frame.mesh.triangleVertices.count, solidMesh(solid).triangleVertices.count)
    XCTAssertFalse(frame.mesh.triangleVertices.isEmpty)
  }

  // MARK: - Helpers

  private func solid(of name: String) throws -> BenchSolid {
    benchSolid(for: try AuthoredPatterns.load(name))
  }

  /// `Novice Ash-er` with `P2`'s meet naming a facet of a tier that does not exist — the solve then
  /// places `G` and `P1` and stops. `BenchSolidTests` has the same builder as its own file-private
  /// helper; duplicating twelve lines is cheaper than making it shared.
  private func brokenAsher() throws -> FacetKernel.Pattern {
    var pattern = try AuthoredPatterns.load(AuthoredPatterns.noviceAsher)
    let index = try XCTUnwrap(pattern.tiers.firstIndex { $0.tier == "P2" })

    pattern.tiers[index].meet = .fraction(
      from: .vertex(facets: [
        FacetRef(tier: "G", index: 12),
        FacetRef(tier: "G", index: 24),
        FacetRef(tier: "P9", index: 24),
      ]),
      percent: 24.862,
      to: .tcp)
    return pattern
  }
  /// One tier whose stops descend, with no polytope worth building: `playbackSteps` reads `tiers` and
  /// nothing else.
  private func descendingTierSolid() -> BenchSolid {
    BenchSolid(
      planes: [],
      origin: [:],
      polytope: Polytope(vertices: [], facets: [:]),
      tiers: [
        SolvedTier(
          tier: "T", part: .pav, angle: 45, wheel: 96,
          indices: [84, 72, 60, 48, 36, 24, 12, 0], d: 1)
      ])
  }
}
