import Foundation
import XCTest

@testable import FacetKernel

final class SolverTests: XCTestCase {
  /// The three authored patterns, each with the girdle fraction its source diagram measures and the
  /// offsets it must then solve to.
  ///
  /// Six decimal places on the fraction is not decoration: at fewer digits Rand's crown offsets shift
  /// by about 4e-6, past the tolerance below. The 0.04 default is deliberately not used here — passing
  /// it instead moves Easy Octagon's C1 by 0.0094 and Novice Ash-er's C1 by 0.0134, because a crown
  /// tier's offset depends on the girdle band's thickness.
  private struct Diagram {
    let file: String
    let girdle: Double
    let offsets: [String: Double]
  }

  private static let diagrams: [Diagram] = [
    Diagram(
      file: AuthoredPatterns.easyOctagon,
      girdle: 0.033700,
      offsets: [
        "G1": 1.000000,
        "P1": 0.738455,
        "P2": 0.738190,
        "C1": 0.719219,
        "C2": 0.583704,
        "T": 0.399704,
      ]
    ),
    Diagram(
      file: AuthoredPatterns.noviceAsher,
      girdle: 0.032260,
      offsets: [
        "G": 1.000000,
        "P1": 0.766044,
        "P2": 0.746320,
        "P3": 0.748472,
        "C1": 0.555876,
        "C2": 0.506084,
        "T": 0.323778,
      ]
    ),
    Diagram(
      file: AuthoredPatterns.rands,
      girdle: 0.040493,
      offsets: [
        "1": 0.681998,
        "2": 1.000000,
        "3": 0.732051,
        "4": 0.663463,
        "5": 0.681926,
        "A": 0.804153,
        "B": 0.598892,
        "C": 0.506432,
        "D": 0.642374,
        "E": 0.512068,
        "F": 0.382686,
        "G": 0.470588,
      ]
    ),
  ]

  private let tol = 1e-6

  // MARK: - The authored patterns

  func testTheThreeAuthoredPatternsSolveToTheirDiagramOffsets() throws {
    for diagram in Self.diagrams {
      let pattern = try AuthoredPatterns.load(diagram.file)
      let solution = try solve(pattern, girdleTargetFraction: diagram.girdle)

      XCTAssertEqual(solution.tiers.count, pattern.tiers.count, pattern.name)
      XCTAssertEqual(
        solution.planes.count,
        pattern.tiers.reduce(0) { $0 + $1.indices.count },
        "\(pattern.name): every index stop of every tier is a plane"
      )
      for tier in solution.tiers {
        let expected = try XCTUnwrap(
          diagram.offsets[tier.tier],
          "\(pattern.name): tier \(tier.tier) is not in the expected offsets"
        )
        XCTAssertEqual(tier.d, expected, accuracy: tol, "\(pattern.name) tier \(tier.tier)")
      }
    }
  }

  func testEveryPlaneKnowsWhichFacetOwnsIt() throws {
    let pattern = try AuthoredPatterns.load(AuthoredPatterns.easyOctagon)
    let solution = try solve(pattern, girdleTargetFraction: 0.033700)

    XCTAssertEqual(solution.planeOwner.count, solution.planes.count)
    for (index, plane) in solution.planes.enumerated() {
      let owner = try XCTUnwrap(solution.planeOwner[index])
      let tier = try XCTUnwrap(solution.tiers.first { $0.tier == owner.tier })
      XCTAssertTrue(tier.indices.contains(owner.index))
      XCTAssertEqual(plane.d, tier.d, accuracy: tol, "plane \(index) is off its tier's depth")
    }
  }

  // MARK: - The max rule

  /// A tier shares one depth, and which of its facets arrives at the named point is computed, never
  /// read from the pattern.
  ///
  /// Easy Octagon's P2 is cut to the girdle corner between G1@0 and G1@12, which sits at 22.5 degrees
  /// on the wheel — the azimuth of P2@6, not of P2@18. Dotting the point with P2@18's normal gives
  /// 0.52198, a depth at which P2 would never touch it.
  func testMaxRuleChoosesTheFacetThatArrives() throws {
    let pattern = try AuthoredPatterns.load(AuthoredPatterns.easyOctagon)
    let solution = try solve(pattern, girdleTargetFraction: 0.033700)

    let corner = try XCTUnwrap(
      triplePoint(
        try plane(of: solution, "G1", 0),
        try plane(of: solution, "G1", 12),
        try plane(of: solution, "P1", 0)
      )
    )
    let acrossTheGap = dot(
      planeNormal(angleDegrees: 43, index: 18, wheel: 96, part: .pav),
      corner
    )
    XCTAssertEqual(acrossTheGap, 0.52198, accuracy: 1e-5)

    let p2 = try XCTUnwrap(solution.tiers.first { $0.tier == "P2" })
    XCTAssertEqual(p2.d, 0.738190, accuracy: tol)
    XCTAssertEqual(
      dot(planeNormal(angleDegrees: 43, index: 6, wheel: 96, part: .pav), corner),
      p2.d,
      accuracy: tol,
      "the arriving facet is the one whose plane passes through the point"
    )
  }

  // MARK: - The axial point

  /// A 90-degree tier never reaches the axis, so it does not consume the free datum. Easy Octagon and
  /// Novice Ash-er both cut the girdle before their first `tcp` tier, and a solver that let a vertical
  /// plane register a phantom axial point would reject them both.
  func testNinetyDegreeGirdleTierLeavesTheAxialPointFree() throws {
    let pattern = synthetic([
      TierSpec(tier: "G", part: .gdl, angle: 90, indices: octagon, meet: .size),
      TierSpec(tier: "P", part: .pav, angle: 45, indices: octagon, meet: .tcp),
    ])
    let solution = try solve(pattern)

    let pavilion = try XCTUnwrap(solution.tiers.first { $0.tier == "P" })
    XCTAssertEqual(pavilion.d, sin(45 * Double.pi / 180), accuracy: 1e-12)
  }

  func testSecondTCPOnTheSameSideThrows() {
    let pattern = synthetic([
      TierSpec(tier: "G", part: .gdl, angle: 90, indices: octagon, meet: .size),
      TierSpec(tier: "P1", part: .pav, angle: 45, indices: octagon, meet: .tcp),
      TierSpec(tier: "P2", part: .pav, angle: 40, indices: octagon, meet: .tcp),
    ])
    XCTAssertThrowsError(try solve(pattern)) { error in
      XCTAssertEqual(error as? SolverError, .secondTCPOnSide(tier: "P2", part: .pav))
    }
  }

  /// One `tcp` per *side*, not per pattern: the crown's axial point is a separate datum from the
  /// pavilion's.
  func testOneTCPPerSideIsAccepted() throws {
    let pattern = synthetic([
      TierSpec(tier: "G", part: .gdl, angle: 90, indices: octagon, meet: .size),
      TierSpec(tier: "P1", part: .pav, angle: 45, indices: octagon, meet: .tcp),
      TierSpec(tier: "C1", part: .crown, angle: 40, indices: octagon, meet: .tcp),
    ])
    let solution = try solve(pattern)

    let crown = try XCTUnwrap(solution.tiers.first { $0.tier == "C1" })
    XCTAssertEqual(crown.d, sin(40 * Double.pi / 180), accuracy: 1e-12)
  }

  // MARK: - Verification handle (T5, permanent)

  /// Prints one line per tier for each authored pattern: label, meet form, solved offset.
  ///
  /// T5's negative check: change `Pattern-Novice-Ash-er.json`'s P2 percent from 24.862 to 30 and
  /// re-run. The P2 line moves *and* the P3 line moves with it, because P3's fraction runs to the axial
  /// point P2 established. A change that moved P2 alone would mean the endpoints are not being
  /// threaded. Restore the file afterwards.
  func testSolveDump() throws {
    for diagram in Self.diagrams {
      let pattern = try AuthoredPatterns.load(diagram.file)
      let solution = try solve(pattern, girdleTargetFraction: diagram.girdle)

      print("\(pattern.name): girdle \(String(format: "%.6f", diagram.girdle))")
      for (solved, spec) in zip(solution.tiers, pattern.tiers) {
        print("  \(solved.tier) \(spec.meet.kindName) d=\(String(format: "%.6f", solved.d))")
      }

      XCTAssertEqual(solution.tiers.count, pattern.tiers.count)
    }
  }

  // MARK: - Helpers

  /// The eight index stops of a 4-fold octagonal girdle on a 96 wheel.
  private let octagon = [0, 12, 24, 36, 48, 60, 72, 84]

  private func synthetic(_ tiers: [TierSpec]) -> FacetKernel.Pattern {
    FacetKernel.Pattern(
      formatVersion: 1,
      name: "synthetic",
      state: .inProgress,
      wheel: 96,
      ri: 1.54,
      designer: "",
      notes: "",
      tiers: tiers
    )
  }

  private func plane(of solution: Solution, _ tier: String, _ index: Int) throws -> Plane {
    let found = try XCTUnwrap(
      solution.planeOwner.first { $0.value.tier == tier && $0.value.index == index },
      "no facet \(tier)@\(index)"
    )
    return solution.planes[found.key]
  }
}
