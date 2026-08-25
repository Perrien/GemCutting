import FacetKernel
import Foundation
import XCTest

@testable import BenchGeometry

/// The two measured cards' strings, read off the corpus and off the cases the corpus cannot reach.
/// `AuthoredPatterns` lives in `BenchSolidTests.swift`.
final class MetricsReadoutTests: XCTestCase {

  // MARK: - Is there a stone to measure

  func testEveryAuthoredPatternSolvesWholeAndIsMeasurable() throws {
    for name in AuthoredPatterns.all {
      let pattern = try AuthoredPatterns.load(name)
      XCTAssertNil(
        unmeasurableReason(pattern: pattern, solid: benchSolid(for: pattern)), name)
    }
  }

  func testNoPatternIsNoStone() {
    XCTAssertEqual(
      unmeasurableReason(pattern: nil, solid: benchSolid(for: nil)), "No pattern open.")
  }

  /// A stopped solve names the tier that stopped it, which is the more useful of the two sentences — and
  /// is why the stop is tested before the count.
  func testAStoppedSolveNamesTheTierThatStoppedIt() throws {
    let pattern = try brokenOctagon()
    XCTAssertEqual(
      unmeasurableReason(pattern: pattern, solid: benchSolid(for: pattern)),
      "Metrics need every tier: the solve stopped at tier P2.")
  }

  /// The tier limit is the case the third conjunct exists for: every tier the solve was handed placed, so
  /// nothing stopped, and the stone is still a preform.
  func testATierLimitCountsPlacedAgainstDeclared() throws {
    let pattern = try AuthoredPatterns.load(AuthoredPatterns.roundBrilliant)
    XCTAssertEqual(
      unmeasurableReason(pattern: pattern, solid: benchSolid(for: pattern, tierLimit: 3)),
      "Metrics need every tier: 3 of 7 placed.")
  }

  // MARK: - The split count

  func testTheSplitCountIsTheFormAPrintedSheetUses() throws {
    XCTAssertEqual(try split(of: AuthoredPatterns.roundBrilliant), "57 + 16 girdle = 73")
    XCTAssertEqual(try split(of: AuthoredPatterns.easyOctagon), "29 + 8 girdle = 37")
  }

  /// A knife-edge girdle has no girdle facets, so the term is omitted rather than shown as zero. No
  /// authored pattern is knife-edged, so both halves of the rule are constructed.
  func testAKnifeEdgeGirdleCollapsesToTheBareTotal() throws {
    let solution = try solve(AuthoredPatterns.load(AuthoredPatterns.easyOctagon))
    let measured = metrics(solution)

    // No tier is a girdle tier: nothing to sum.
    let noGirdleTier = solution.tiers.filter { $0.part != .gdl }
    XCTAssertEqual(splitFacetCount(measured, tiers: noGirdleTier), "37")

    // The girdle tier is there and contributes no facets, which is the same statement from the other
    // side.
    var noGirdleFacets = measured
    noGirdleFacets.facetsPerTier["G1"] = 0
    XCTAssertEqual(splitFacetCount(noGirdleFacets, tiers: solution.tiers), "37")
  }

  // MARK: - The measured card

  func testEasyOctagonReadsOffEveryFigure() throws {
    let pattern = try AuthoredPatterns.load(AuthoredPatterns.easyOctagon)
    let summary = try measured(pattern: pattern, solid: benchSolid(for: pattern))

    XCTAssertEqual(summary.facets, "29 + 8 girdle = 37")
    XCTAssertEqual(summary.symmetry, "4-fold, mirrors at 6 18 30 42")
    XCTAssertEqual(summary.lengthOverWidth, "1.00000")

    XCTAssertEqual(try value(of: "Girdle", in: summary), "0.067400 (3.370% of width)")
    XCTAssertEqual(try value(of: "Width", in: summary), "2.000000")
    XCTAssertEqual(try value(of: "Length", in: summary), "2.000000")
  }

  func testTheProportionTableIsEightRowsInOneOrder() throws {
    for name in AuthoredPatterns.all {
      let pattern = try AuthoredPatterns.load(name)
      let summary = try measured(pattern: pattern, solid: benchSolid(for: pattern))

      XCTAssertEqual(
        summary.proportions.map(\.label),
        ["P/W", "C/W", "H/W", "T/W", "Girdle", "Width", "Length", "Culet"],
        name)
      XCTAssertEqual(summary.proportions.map(\.id), summary.proportions.map(\.label), name)
    }
  }

  // MARK: - The unavailable card carries no figures at all

  func testNoPatternGivesTheSentenceAndNoSummary() {
    XCTAssertEqual(
      metricsReadout(pattern: nil, solid: benchSolid(for: nil)), .unavailable("No pattern open."))
  }

  func testATruncatedSolveGivesTheSentenceAndNoSummary() throws {
    let pattern = try AuthoredPatterns.load(AuthoredPatterns.easyOctagon)
    let readout = metricsReadout(pattern: pattern, solid: benchSolid(for: pattern, tierLimit: 3))

    XCTAssertEqual(readout, .unavailable("Metrics need every tier: 3 of 6 placed."))
  }

  // MARK: - The declared count

  /// One table over the field's every meaningful state, on the pattern whose own sheet declares
  /// "57 facets plus 16 on the girdle = 73" — the case the split form exists for.
  func testTheVerdictReadsOffTheFieldsText() throws {
    let pattern = try AuthoredPatterns.load(AuthoredPatterns.roundBrilliant)
    let solid = benchSolid(for: pattern)

    let cases: [(declared: String, verdict: String)] = [
      ("", "No count declared."),
      ("   ", "No count declared."),
      ("73", "Matches the declared 73."),
      (" 73 ", "Matches the declared 73."),
      ("57", "Declared 57 · solved 57 + 16 girdle = 73."),
      ("72", "Declared 72 · solved 57 + 16 girdle = 73."),
      ("abc", "Not a facet count."),
      ("0", "Not a facet count."),
      ("-3", "Not a facet count."),
      ("5.5", "Not a facet count."),
    ]

    for (declared, verdict) in cases {
      let check = facetCountCheck(pattern: pattern, solid: solid, declared: declared)

      XCTAssertEqual(check.verdict, verdict, "declared \"\(declared)\"")
      // The solve does not move when the claim does.
      XCTAssertEqual(check.solved, "57 + 16 girdle = 73", "declared \"\(declared)\"")
    }
  }

  func testWithNoPatternThereIsNothingToCount() {
    let check = facetCountCheck(pattern: nil, solid: benchSolid(for: nil), declared: "73")

    XCTAssertNil(check.solved)
    XCTAssertEqual(check.verdict, "No pattern open.")
  }

  /// A truncated solve has no count to check a sheet against, so a declared count that would match the
  /// finished stone still gets the reason rather than a verdict.
  func testATruncatedSolveHasNoCountToCheck() throws {
    let pattern = try AuthoredPatterns.load(AuthoredPatterns.easyOctagon)
    let check = facetCountCheck(
      pattern: pattern, solid: benchSolid(for: pattern, tierLimit: 3), declared: "37")

    XCTAssertNil(check.solved)
    XCTAssertEqual(check.verdict, "Metrics need every tier: 3 of 6 placed.")
  }

  /// That truncated solid is also an open one, and closure is not this card's business: the finding the
  /// kernel returns alongside the count is ignored here rather than reworded into a verdict.
  func testAnOpenSolidNeverBecomesAFacetCountVerdict() throws {
    let pattern = try AuthoredPatterns.load(AuthoredPatterns.easyOctagon)
    let solid = benchSolid(for: pattern, tierLimit: 3)

    XCTAssertTrue(solid.includesRough, "tierLimit 3 is meant to leave the solid open")
    let open = solidFindings(try XCTUnwrap(solid.solution), declaredFacetCount: nil).contains {
      guard case .doesNotClose = $0 else { return false }
      return true
    }
    XCTAssertTrue(open)

    let check = facetCountCheck(pattern: pattern, solid: solid, declared: "")
    XCTAssertEqual(check.verdict, "Metrics need every tier: 3 of 6 placed.")
    XCTAssertFalse(check.verdict.lowercased().contains("close"))
  }

  // MARK: - Helpers

  /// `Easy Octagon` with `P2`'s meet naming a facet of a tier that does not exist, so the solve stops on
  /// `P2`. Built in memory: the corpus is ground truth and is never edited to feed a check.
  private func brokenOctagon() throws -> FacetKernel.Pattern {
    var pattern = try AuthoredPatterns.load(AuthoredPatterns.easyOctagon)
    let index = try XCTUnwrap(pattern.tiers.firstIndex { $0.tier == "P2" })

    pattern.tiers[index].meet = .vertex(facets: [
      FacetRef(tier: "G1", index: 0),
      FacetRef(tier: "G1", index: 12),
      FacetRef(tier: "P9", index: 0),
    ])
    return pattern
  }

  private func split(of name: String) throws -> String {
    let solution = try solve(AuthoredPatterns.load(name))
    return splitFacetCount(metrics(solution), tiers: solution.tiers)
  }

  private func measured(pattern: FacetKernel.Pattern, solid: BenchSolid) throws -> MetricsSummary {
    let readout = metricsReadout(pattern: pattern, solid: solid)
    guard case .measured(let summary) = readout else {
      throw NotMeasured(readout: readout)
    }
    return summary
  }

  /// Thrown rather than asserted, so a helper's failure names the readout it got instead of reporting a
  /// second, emptier failure further down the test.
  private struct NotMeasured: Error, CustomStringConvertible {
    let readout: MetricsReadout
    var description: String { "expected a measured readout, got \(readout)" }
  }

  private func value(of label: String, in summary: MetricsSummary) throws -> String {
    try XCTUnwrap(summary.proportions.first { $0.label == label }).value
  }
}
