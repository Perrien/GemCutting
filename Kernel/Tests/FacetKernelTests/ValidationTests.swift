import Foundation
import XCTest

@testable import FacetKernel

final class ValidationTests: XCTestCase {
  /// Each authored pattern with the girdle fraction its source diagram measures, and the facet count its
  /// sheet declares. The count is external ground truth, so validation must agree with it rather than
  /// with itself.
  private struct Sheet {
    let file: String
    let girdle: Double
    let facets: Int
  }

  private static let sheets: [Sheet] = [
    Sheet(file: AuthoredPatterns.easyOctagon, girdle: 0.033700, facets: 37),
    Sheet(file: AuthoredPatterns.noviceAsher, girdle: 0.032260, facets: 49),
    Sheet(file: AuthoredPatterns.rands, girdle: 0.040493, facets: 53),
  ]

  // MARK: - The authored patterns

  func testTheThreeAuthoredPatternsValidateClean() throws {
    for sheet in Self.sheets {
      let pattern = try AuthoredPatterns.load(sheet.file)
      let solution = try solve(pattern, girdleTargetFraction: sheet.girdle)
      let report = validate(pattern, solution, declaredFacetCount: sheet.facets)

      XCTAssertEqual(report.findings, [], pattern.name)
      XCTAssertEqual(report.observations, [], pattern.name)
    }
  }

  // MARK: - Findings the pattern alone carries

  func testForwardReferenceIsReportedNotReordered() throws {
    let report = try structuralReport {
      $0.tiers[2].meet = .vertex(facets: [
        FacetRef(tier: "G1", index: 0),
        FacetRef(tier: "G1", index: 12),
        FacetRef(tier: "C1", index: 0),
      ])
    }
    XCTAssertEqual(report.findings, [.forwardReference(tier: "P2", named: "C1")])
  }

  func testNamesOwnFacet() throws {
    let report = try structuralReport {
      $0.tiers[4].meet = .vertex(facets: [
        FacetRef(tier: "C2", index: 18),
        FacetRef(tier: "G1", index: 24),
        FacetRef(tier: "C1", index: 12),
      ])
    }
    XCTAssertEqual(report.findings, [.namesOwnFacet(tier: "C2")])
  }

  func testUnknownTierIsAnUnknownFacet() throws {
    let report = try structuralReport {
      $0.tiers[2].meet = .vertex(facets: [
        FacetRef(tier: "G1", index: 0),
        FacetRef(tier: "G1", index: 12),
        FacetRef(tier: "P9", index: 0),
      ])
    }
    XCTAssertEqual(
      report.findings, [.unknownFacet(tier: "P2", named: FacetRef(tier: "P9", index: 0))])
  }

  /// A tier the pattern does cut, at an index stop it does not.
  func testUncutIndexStopIsAnUnknownFacet() throws {
    let report = try structuralReport {
      $0.tiers[2].meet = .vertex(facets: [
        FacetRef(tier: "G1", index: 0),
        FacetRef(tier: "G1", index: 1),
        FacetRef(tier: "P1", index: 0),
      ])
    }
    XCTAssertEqual(
      report.findings, [.unknownFacet(tier: "P2", named: FacetRef(tier: "G1", index: 1))])
  }

  /// Three girdle facets are all vertical, so they share a direction and pin nothing.
  func testSingularTriple() throws {
    let report = try structuralReport {
      $0.tiers[2].meet = .vertex(facets: [
        FacetRef(tier: "G1", index: 0),
        FacetRef(tier: "G1", index: 12),
        FacetRef(tier: "G1", index: 24),
      ])
    }
    XCTAssertEqual(report.findings, [.singularTriple(tier: "P2")])
  }

  /// P1 has already taken the pavilion's free datum, so P2 asking for it constrains nothing.
  func testSecondTCPOnSide() throws {
    let report = try structuralReport { $0.tiers[2].meet = .tcp }
    XCTAssertEqual(report.findings, [.secondTCPOnSide(tier: "P2", part: .pav)])
  }

  /// The unit every other depth is expressed in, carried twice. Nothing stops the pattern solving — both
  /// tiers simply sit at offset 1.0 — so validation is the only thing that catches it.
  func testTwoSizeRows() throws {
    let report = try solvedReport { $0.tiers[1].meet = .size }
    XCTAssertEqual(report.findings, [.notExactlyOneSizeRow(count: 2)])
  }

  /// A girdle tier at 90 degrees never reaches the axis, so turning the `size` row into a `tcp` leaves
  /// the pavilion's free datum free — the only fault is that nothing now carries the unit.
  func testNoSizeRow() throws {
    let report = try solvedReport { $0.tiers[0].meet = .tcp }
    XCTAssertEqual(report.findings, [.notExactlyOneSizeRow(count: 0)])
  }

  // MARK: - Findings that need the solid

  /// Girdle facets at index 0 and 24 are 90 degrees apart, so their planes cross well outside the
  /// octagon. The triple still fixes a point, and that point is nowhere on the stone.
  func testVertexNotOnIntermediateSolid() throws {
    var pattern = try AuthoredPatterns.load(AuthoredPatterns.easyOctagon)
    let named = [
      FacetRef(tier: "G1", index: 0),
      FacetRef(tier: "G1", index: 24),
      FacetRef(tier: "C1", index: 0),
    ]
    pattern.tiers[4].meet = .vertex(facets: named)
    let solution = try solve(pattern, girdleTargetFraction: Self.easyOctagonGirdle)

    let report = validate(pattern, solution, declaredFacetCount: nil)
    XCTAssertEqual(report.findings, [.vertexNotOnIntermediateSolid(tier: "C2", named: named)])
    XCTAssertEqual(report.observations, [])
  }

  /// The check is against the solid as it stands when the tier is cut, not the finished one. Easy
  /// Octagon's P1 reaches the axis at 1.0951 half-widths and P2 then cuts that point away, so a
  /// finished-polytope implementation fails the first assertion and passes the second.
  func testTheVertexCheckIsIncremental() throws {
    let pattern = try AuthoredPatterns.load(AuthoredPatterns.easyOctagon)
    let solution = try solve(pattern, girdleTargetFraction: Self.easyOctagonGirdle)

    let p1 = try XCTUnwrap(solution.tiers.first { $0.tier == "P1" })
    let axial = (x: 0.0, y: 0.0, z: p1.d / -cos(p1.angle * Double.pi / 180))
    XCTAssertEqual(axial.z, -1.0951, accuracy: 1e-4)

    let beforeP2 = intermediateSolid(before: "P2", of: solution)
    XCTAssertTrue(
      beforeP2.vertices.contains { distance($0, axial) <= 1e-9 },
      "P1's axial point is a corner of the stone before P2 is cut"
    )
    XCTAssertFalse(
      solution.polytope.vertices.contains { distance($0, axial) <= 1e-9 },
      "and is gone from the finished stone, which P2 cuts to 1.00935"
    )
  }

  /// Without a pavilion the girdle facets have a top edge and nothing below it, so the surface is open.
  /// The finding names the first tier owning a facet with an unshared edge — the crown facets whose
  /// lower edges the missing girdle facets would have met.
  func testDoesNotCloseNamesTheOpenTier() throws {
    var pattern = try AuthoredPatterns.load(AuthoredPatterns.easyOctagon)
    pattern.tiers.removeAll { $0.tier == "P1" || $0.tier == "P2" }
    let solution = try solve(pattern, girdleTargetFraction: Self.easyOctagonGirdle)

    let report = validate(pattern, solution, declaredFacetCount: nil)
    XCTAssertEqual(report.findings, [.doesNotClose(tier: "C1")])
    XCTAssertEqual(report.observations, [.tierContributesNoFacets(tier: "G1")])
  }

  /// A girdle on its own is an unbounded prism: no triple of vertical planes meets at a point, so there
  /// is no surface to attribute the fault to.
  func testDoesNotCloseWithNothingToName() throws {
    var pattern = try AuthoredPatterns.load(AuthoredPatterns.easyOctagon)
    pattern.tiers = [pattern.tiers[0]]
    let solution = try solve(pattern, girdleTargetFraction: Self.easyOctagonGirdle)

    let report = validate(pattern, solution, declaredFacetCount: nil)
    XCTAssertEqual(report.findings, [.doesNotClose(tier: nil)])
  }

  func testFacetCountMismatch() throws {
    let pattern = try AuthoredPatterns.load(AuthoredPatterns.easyOctagon)
    let solution = try solve(pattern, girdleTargetFraction: Self.easyOctagonGirdle)

    let report = validate(pattern, solution, declaredFacetCount: 36)
    XCTAssertEqual(report.findings, [.facetCountMismatch(solved: 37, declared: 36)])
  }

  // MARK: - Observations

  /// A tier cut away entirely is legitimate, so it lands in `observations` and `findings` stays empty.
  ///
  /// Novice Ash-er is a step cut: pulling C2's fraction back to 0% cuts it to the girdle-top corner ring
  /// that C1 stands on, which removes every C1 facet and leaves the girdle untouched. The sheet would
  /// not have counted those facets either, which is why the count agreeing is part of the check.
  func testTierContributesNoFacetsIsAnObservation() throws {
    var pattern = try AuthoredPatterns.load(AuthoredPatterns.noviceAsher)
    let girdle = 0.032260
    let baseline = try solve(pattern, girdleTargetFraction: girdle)

    guard case .fraction(let from, _, let to) = pattern.tiers[5].meet else {
      return XCTFail("Novice Ash-er's C2 is authored as a fraction")
    }
    pattern.tiers[5].meet = .fraction(from: from, percent: 0, to: to)
    let deepened = try solve(pattern, girdleTargetFraction: girdle)

    let report = validate(pattern, deepened, declaredFacetCount: nil)
    XCTAssertEqual(report.findings, [])
    XCTAssertEqual(report.observations, [.tierContributesNoFacets(tier: "C1")])

    let c1 = try XCTUnwrap(pattern.tiers.first { $0.tier == "C1" })
    XCTAssertEqual(
      baseline.polytope.facets.count - deepened.polytope.facets.count,
      c1.indices.count,
      "the solid loses exactly C1's facets and nothing else"
    )
  }

  /// One index stop cut twice: the two planes coincide, so the second facet is the first one again.
  func testDuplicatePlanesIsAnObservation() throws {
    var pattern = try AuthoredPatterns.load(AuthoredPatterns.easyOctagon)
    pattern.tiers[2].indices = [6, 6, 18, 30, 42, 54, 66, 78, 90]
    let solution = try solve(pattern, girdleTargetFraction: Self.easyOctagonGirdle)

    let report = validate(pattern, solution, declaredFacetCount: nil)
    XCTAssertEqual(report.findings, [])
    XCTAssertEqual(report.observations, [.duplicatePlanes(tier: "P2", indices: [6])])
  }

  // MARK: - Reporting, not enforcing

  /// Whether findings are fatal is the caller's rule. Validation returns the same report either way: a
  /// pattern still being authored may carry findings, and a finished one carrying them is not something
  /// this function throws over.
  func testStateDoesNotChangeTheReport() throws {
    var inProgress = try AuthoredPatterns.load(AuthoredPatterns.easyOctagon)
    inProgress.state = .inProgress
    inProgress.tiers[2].meet = .tcp
    var finished = inProgress
    finished.state = .finished

    let solution = try solve(
      try AuthoredPatterns.load(AuthoredPatterns.easyOctagon),
      girdleTargetFraction: Self.easyOctagonGirdle
    )
    let expected: [Finding] = [.secondTCPOnSide(tier: "P2", part: .pav)]
    XCTAssertEqual(validate(inProgress, solution, declaredFacetCount: nil).findings, expected)
    XCTAssertEqual(validate(finished, solution, declaredFacetCount: nil).findings, expected)
  }

  // MARK: - The three pieces on their own

  /// `structuralFindings` needs no solid and no solve — this calls it with neither, which is the half an
  /// authoring UI runs on every keystroke while the pattern is still half-written.
  func testStructuralFindingsNeedsNoSolutionAtAll() throws {
    var pattern = try AuthoredPatterns.load(AuthoredPatterns.easyOctagon)
    pattern.tiers[1].meet = .size

    XCTAssertEqual(structuralFindings(pattern), [.notExactlyOneSizeRow(count: 2)])
    XCTAssertEqual(structuralFindings(try AuthoredPatterns.load(AuthoredPatterns.easyOctagon)), [])
  }

  /// The per-tier piece, asked about one tier at a time. `C2` is the tier whose meet was mutated to name a
  /// point off the stone; `P2`'s meet is untouched and comes back clean, from the same solution.
  func testNamedPointFindingsAnswersForOneTier() throws {
    var pattern = try AuthoredPatterns.load(AuthoredPatterns.easyOctagon)
    let named = [
      FacetRef(tier: "G1", index: 0),
      FacetRef(tier: "G1", index: 24),
      FacetRef(tier: "C1", index: 0),
    ]
    pattern.tiers[4].meet = .vertex(facets: named)
    let solution = try solve(pattern, girdleTargetFraction: Self.easyOctagonGirdle)

    XCTAssertEqual(
      namedPointFindings(inTier: "C2", of: pattern, solution),
      [.vertexNotOnIntermediateSolid(tier: "C2", named: named)]
    )
    XCTAssertEqual(namedPointFindings(inTier: "P2", of: pattern, solution), [])
    XCTAssertEqual(
      namedPointFindings(inTier: "nonesuch", of: pattern, solution), [],
      "a tier the pattern does not carry"
    )
  }

  /// **Tier *k*'s answer does not depend on the tiers after it.** Recorded for all six tiers, then again
  /// for the five that remain once the last is removed: the five agree. This is the property
  /// `4-Cutting-Bench-Authoring` caches against — editing tier *j* invalidates *j* onward and nothing
  /// before it — and prose alone would not have caught an implementation that measured against the
  /// finished solid.
  func testATiersResultDoesNotDependOnTheTiersAfterIt() throws {
    let pattern = try AuthoredPatterns.load(AuthoredPatterns.easyOctagon)
    let solution = try solve(pattern, girdleTargetFraction: Self.easyOctagonGirdle)
    let sixTiers = pattern.tiers.map { namedPointFindings(inTier: $0.tier, of: pattern, solution) }
    XCTAssertEqual(sixTiers.count, 6)

    var shortened = pattern
    shortened.tiers.removeLast()
    shortened.state = .inProgress
    let reSolved = try solve(shortened, girdleTargetFraction: Self.easyOctagonGirdle)
    let fiveTiers = shortened.tiers.map {
      namedPointFindings(inTier: $0.tier, of: shortened, reSolved)
    }

    XCTAssertEqual(fiveTiers, Array(sixTiers.prefix(5)))
  }

  /// The whole-solid piece on its own, both findings it can produce.
  func testSolidFindingsOnItsOwn() throws {
    var pavilionless = try AuthoredPatterns.load(AuthoredPatterns.easyOctagon)
    pavilionless.tiers.removeAll { $0.tier == "P1" || $0.tier == "P2" }
    let open = try solve(pavilionless, girdleTargetFraction: Self.easyOctagonGirdle)
    XCTAssertEqual(solidFindings(open, declaredFacetCount: nil), [.doesNotClose(tier: "C1")])

    let clean = try solve(
      try AuthoredPatterns.load(AuthoredPatterns.easyOctagon),
      girdleTargetFraction: Self.easyOctagonGirdle
    )
    XCTAssertEqual(solidFindings(clean, declaredFacetCount: nil), [])
    XCTAssertEqual(
      solidFindings(clean, declaredFacetCount: 36),
      [.facetCountMismatch(solved: 37, declared: 36)]
    )
  }

  // MARK: - Helpers

  private static let easyOctagonGirdle = 0.033700

  /// Validates a mutated copy of Easy Octagon whose meets name the wrong facets, against the pristine
  /// solution, having first asserted that the solver refuses the mutation outright.
  ///
  /// A pattern that names its facets wrongly has no solid of its own, which is what the first assertion
  /// records. The pristine solution is passed only because `validate` takes one; the geometric checks it
  /// would feed never run.
  private func structuralReport(
    _ mutate: (inout FacetKernel.Pattern) -> Void
  ) throws -> Report {
    let pristine = try AuthoredPatterns.load(AuthoredPatterns.easyOctagon)
    var mutated = pristine
    mutate(&mutated)
    XCTAssertThrowsError(
      try solve(mutated, girdleTargetFraction: Self.easyOctagonGirdle),
      "a meet that names the wrong facet is a fault the solver refuses outright"
    )

    let solution = try solve(pristine, girdleTargetFraction: Self.easyOctagonGirdle)
    return validate(mutated, solution, declaredFacetCount: nil)
  }

  /// Validates a mutated copy of Easy Octagon against its own solution — for a fault the solver has no
  /// reason to refuse, so the pattern solves and only validation catches it.
  private func solvedReport(
    _ mutate: (inout FacetKernel.Pattern) -> Void
  ) throws -> Report {
    var mutated = try AuthoredPatterns.load(AuthoredPatterns.easyOctagon)
    mutate(&mutated)
    let solution = try solve(mutated, girdleTargetFraction: Self.easyOctagonGirdle)
    return validate(mutated, solution, declaredFacetCount: nil)
  }
}
