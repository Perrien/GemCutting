import FacetKernel
import Foundation
import XCTest

@testable import BenchGeometry

/// The findings the three surfaces read: the strip's line, the popover's rows, the marker counts and the
/// warning tiers. `AuthoredPatterns` lives in `BenchSolidTests.swift`.
final class FindingsTests: XCTestCase {

  // MARK: - The baseline

  /// The corpus is clean on both halves, which is what every other case here is read against. A fault has
  /// to be manufactured because all four authored patterns are correct.
  func testEveryAuthoredPatternComesBackWithNoFindings() throws {
    for name in AuthoredPatterns.all {
      let pattern = try AuthoredPatterns.load(name)
      let solution = try XCTUnwrap(benchSolid(for: pattern).solution, name)

      XCTAssertEqual(structuralFindings(pattern).count, 0, name)
      let geometric = try XCTUnwrap(
        geometricFindings(pattern: pattern, solution: solution), "\(name) reported cancelled")
      XCTAssertTrue(geometric.isEmpty, "\(name): \(geometric)")
    }
  }

  /// A partial list is not a result and must never be shown as one.
  func testCancellationReportsNothingRatherThanAPartialList() throws {
    let pattern = try AuthoredPatterns.load(AuthoredPatterns.roundBrilliant)
    let solution = try XCTUnwrap(benchSolid(for: pattern).solution)

    XCTAssertNil(
      geometricFindings(pattern: pattern, solution: solution, isCancelled: { true }))
  }

  // MARK: - No pattern

  func testNoPatternSaysSo() {
    let readout = findingsReadout(
      pattern: nil, solid: benchSolid(for: nil), structural: [], geometric: nil, isChecking: false)

    XCTAssertEqual(readout.line, "No pattern open.")
    XCTAssertTrue(readout.rows.isEmpty)
    XCTAssertTrue(readout.perTier.isEmpty)
    XCTAssertTrue(readout.warningTiers.isEmpty)
  }

  // MARK: - A fault the kernel really reports

  func testATruncatedSolidDoesNotClose() throws {
    let pattern = try AuthoredPatterns.load(AuthoredPatterns.easyOctagon)
    let solid = benchSolid(for: pattern, tierLimit: 2)
    let solution = try XCTUnwrap(solid.solution)

    let geometric = try XCTUnwrap(geometricFindings(pattern: pattern, solution: solution))
    XCTAssertEqual(geometric.count, 1)
    guard case .doesNotClose = try XCTUnwrap(geometric.first) else {
      return XCTFail("expected a closure finding, got \(geometric)")
    }

    let readout = findingsReadout(
      pattern: pattern, solid: solid, structural: [], geometric: geometric, isChecking: false)
    XCTAssertEqual(readout.line, "1 finding")
    XCTAssertEqual(readout.rows.count, 1)
    XCTAssertTrue(try XCTUnwrap(readout.rows.first).isFinding)
    XCTAssertTrue(try XCTUnwrap(readout.rows.first).text.hasPrefix("The solid does not close"))
    // No tier is marked. The kernel names the tier it found the open edge on — P1, whose facets are
    // complete — because the incomplete girdle walls have no height yet and so are not facets of this
    // solid at all. Marking P1 would send the owner to the wrong row.
    XCTAssertNil(try XCTUnwrap(readout.rows.first).tier)
    XCTAssertTrue(readout.perTier.isEmpty)
  }

  /// A girdle meet needs the vertical planes that bound the outline, so a pattern that cuts the crown
  /// before the girdle stops on its first tier — and the stop leads the rows, because it is why there are
  /// no findings for the tiers after it.
  func testAStoppedSolvePrefixesTheLineAndLeadsTheRows() throws {
    let pattern = synthetic([
      TierSpec(tier: "C1", part: .crown, angle: 40, indices: octagon, meet: .girdle),
      TierSpec(tier: "G", part: .gdl, angle: 90, indices: octagon, meet: .size),
    ])
    let solid = benchSolid(for: pattern)
    let solution = try XCTUnwrap(solid.solution)

    XCTAssertTrue(structuralFindings(pattern).isEmpty)
    let geometric = try XCTUnwrap(geometricFindings(pattern: pattern, solution: solution))
    XCTAssertEqual(geometric, [.doesNotClose(tier: nil)])

    let readout = findingsReadout(
      pattern: pattern, solid: solid, structural: [], geometric: geometric, isChecking: false)

    XCTAssertEqual(readout.line, "Stopped at tier C1 · 1 finding")
    XCTAssertEqual(readout.rows.count, 2)
    XCTAssertEqual(readout.rows[0].tier, "C1")
    XCTAssertFalse(readout.rows[0].isFinding)
    XCTAssertEqual(
      readout.rows[0].text,
      "tier C1: the girdle outline is not bounded by the vertical planes placed so far")
    XCTAssertNil(readout.rows[1].tier)
    XCTAssertTrue(readout.rows[1].isFinding)
    XCTAssertEqual(
      readout.rows[1].text, "The solid does not close: it is too small to have a surface at all.")
    XCTAssertTrue(readout.perTier.isEmpty)
  }

  // MARK: - The line's grammar

  func testTheLineNeverReportsACountForACheckThatHasNotRun() throws {
    let pattern = try AuthoredPatterns.load(AuthoredPatterns.easyOctagon)
    let solid = benchSolid(for: pattern)
    XCTAssertNil(solid.stoppedAtTier)

    let one: [Finding] = [.doesNotClose(tier: "P2")]
    let two: [Finding] = [.doesNotClose(tier: "P2"), .singularTriple(tier: "C2")]

    XCTAssertEqual(
      line(pattern, solid, structural: [], geometric: nil, checking: true),
      "checking…")
    XCTAssertEqual(
      line(pattern, solid, structural: [], geometric: [], checking: true),
      "No findings · stale, checking…")
    XCTAssertEqual(
      line(pattern, solid, structural: [], geometric: one, checking: true),
      "1 finding · stale, checking…")
    XCTAssertEqual(
      line(pattern, solid, structural: [], geometric: [], checking: false),
      "No findings")
    XCTAssertEqual(
      line(pattern, solid, structural: [], geometric: two, checking: false),
      "2 findings")
    XCTAssertEqual(
      line(pattern, solid, structural: one, geometric: nil, checking: false),
      "1 finding")
  }

  /// When the structure is wrong the geometric half never starts, and the detail says so in words rather
  /// than leaving the reader to infer it from a short list.
  func testTheDidNotRunNoteIsTheLastRow() throws {
    let pattern = try AuthoredPatterns.load(AuthoredPatterns.easyOctagon)
    let readout = findingsReadout(
      pattern: pattern,
      solid: benchSolid(for: pattern),
      structural: [.notExactlyOneSizeRow(count: 2)],
      geometric: nil,
      isChecking: false)

    let last = try XCTUnwrap(readout.rows.last)
    XCTAssertFalse(last.isFinding)
    XCTAssertNil(last.tier)
    XCTAssertEqual(
      last.text,
      "The geometric checks did not run: a pattern whose structure is wrong has no solid to measure "
        + "them against.")
  }

  // MARK: - The one finding with geometry to show

  func testWarningTiersPicksOutTheNamedPointThatIsNotACorner() throws {
    let pattern = try AuthoredPatterns.load(AuthoredPatterns.easyOctagon)
    let named = [
      FacetRef(tier: "G1", index: 0),
      FacetRef(tier: "G1", index: 24),
      FacetRef(tier: "P1", index: 0),
    ]
    let readout = findingsReadout(
      pattern: pattern,
      solid: benchSolid(for: pattern),
      structural: [],
      geometric: [.vertexNotOnIntermediateSolid(tier: "P2", named: named)],
      isChecking: false)

    XCTAssertEqual(readout.warningTiers, ["P2"])
    XCTAssertEqual(readout.perTier["P2"], 1)
    XCTAssertEqual(
      try XCTUnwrap(readout.rows.first).text,
      "Tier P2's named point G1@0 · G1@24 · P1@0 is not a corner of the stone as it stands when P2 is "
        + "cut.")
  }

  // MARK: - Every case of Finding

  func testFindingTextIsTotal() {
    let named = [
      FacetRef(tier: "G1", index: 0),
      FacetRef(tier: "G1", index: 24),
      FacetRef(tier: "P1", index: 0),
    ]

    XCTAssertEqual(
      findingText(.forwardReference(tier: "P2", named: "P3")),
      "Tier P2's meet names tier P3, which this pattern cuts later.")
    XCTAssertEqual(
      findingText(.namesOwnFacet(tier: "P2")),
      "Tier P2's meet names a facet of P2 itself, which cannot fix its own depth.")
    XCTAssertEqual(
      findingText(.unknownFacet(tier: "P2", named: FacetRef(tier: "G1", index: 6))),
      "Tier P2's meet names G1@6, which this pattern does not cut.")
    XCTAssertEqual(
      findingText(.singularTriple(tier: "P2")),
      "Tier P2's three named facets do not meet at a point.")
    XCTAssertEqual(
      findingText(.secondTCPOnSide(tier: "P2", part: .pav)),
      "Tier P2 is a second tcp on the pav side, where the axial point is already fixed.")
    XCTAssertEqual(
      findingText(.notExactlyOneSizeRow(count: 2)),
      "2 tiers carry the size meet; exactly one must.")
    XCTAssertEqual(
      findingText(.vertexNotOnIntermediateSolid(tier: "P2", named: named)),
      "Tier P2's named point G1@0 · G1@24 · P1@0 is not a corner of the stone as it stands when P2 is "
        + "cut.")
    XCTAssertEqual(
      findingText(.doesNotClose(tier: "P2")),
      "The solid does not close: some facets are incomplete, with an edge no other facet shares.")
    XCTAssertEqual(
      findingText(.doesNotClose(tier: nil)),
      "The solid does not close: it is too small to have a surface at all.")
    XCTAssertEqual(
      findingText(.facetCountMismatch(solved: 57, declared: 58)),
      "The solve counts 57 facets; 58 declared.")
  }

  /// `doesNotClose` names no tier either way: closure is a property of the whole solid, and the tier the
  /// kernel reports is where the open edge was found rather than what left it open.
  func testFindingTierNamesATierForEveryCaseButThree() {
    XCTAssertEqual(findingTier(.forwardReference(tier: "P2", named: "P3")), "P2")
    XCTAssertEqual(findingTier(.namesOwnFacet(tier: "P2")), "P2")
    XCTAssertEqual(
      findingTier(.unknownFacet(tier: "P2", named: FacetRef(tier: "G1", index: 6))), "P2")
    XCTAssertEqual(findingTier(.singularTriple(tier: "P2")), "P2")
    XCTAssertEqual(findingTier(.secondTCPOnSide(tier: "P2", part: .pav)), "P2")
    XCTAssertEqual(
      findingTier(.vertexNotOnIntermediateSolid(tier: "P2", named: [])), "P2")
    XCTAssertNil(findingTier(.doesNotClose(tier: "P2")))
    XCTAssertNil(findingTier(.doesNotClose(tier: nil)))
    XCTAssertNil(findingTier(.notExactlyOneSizeRow(count: 2)))
    XCTAssertNil(findingTier(.facetCountMismatch(solved: 57, declared: 58)))
  }

  // MARK: - Helpers

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
      tiers: tiers)
  }

  private func line(
    _ pattern: FacetKernel.Pattern,
    _ solid: BenchSolid,
    structural: [Finding],
    geometric: [Finding]?,
    checking: Bool
  ) -> String {
    findingsReadout(
      pattern: pattern, solid: solid, structural: structural, geometric: geometric,
      isChecking: checking
    ).line
  }
}
