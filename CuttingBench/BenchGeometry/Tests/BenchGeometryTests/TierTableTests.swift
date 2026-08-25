import FacetKernel
import Foundation
import XCTest

@testable import BenchGeometry

/// The tier table's rows, read off the corpus and off three constructed cases the corpus cannot reach.
/// `AuthoredPatterns` lives in `BenchSolidTests.swift`.
final class TierTableTests: XCTestCase {

  // MARK: - No pattern

  func testNoPatternIsNoRows() {
    XCTAssertTrue(tierTableRows(pattern: nil, solid: benchSolid(for: nil)).isEmpty)
  }

  // MARK: - The corpus, solved whole

  func testNoviceAsherReadsOffEveryColumn() throws {
    let rows = try rows(of: AuthoredPatterns.noviceAsher)

    XCTAssertEqual(rows.map(\.tier), ["G", "P1", "P2", "P3", "C1", "C2", "T"])
    for row in rows {
      XCTAssertEqual(row.state, .solved, row.tier)
      XCTAssertEqual(row.wheel, "96", row.tier)
      XCTAssertTrue(row.wheelIsInherited, row.tier)
      XCTAssertEqual(row.instructions, "", row.tier)
    }

    let girdle = try XCTUnwrap(rows.first { $0.tier == "G" })
    XCTAssertEqual(girdle.part, "gdl")
    XCTAssertEqual(girdle.angle, "90.00°")
    XCTAssertEqual(girdle.indices, "0 12 24 36 48 60 72 84")
    XCTAssertEqual(girdle.meet, "size")

    let p2 = try XCTUnwrap(rows.first { $0.tier == "P2" })
    XCTAssertEqual(p2.meet, "24.86% from G@12 · G@24 · P1@24 to tcp")

    let c2 = try XCTUnwrap(rows.first { $0.tier == "C2" })
    XCTAssertEqual(c2.meet, "24.83% from G@12 · G@24 · C1@24 to tcp")

    let table = try XCTUnwrap(rows.first { $0.tier == "T" })
    XCTAssertEqual(table.part, "table")
    XCTAssertEqual(table.angle, "0.00°")
    XCTAssertEqual(table.indices, "0")
    XCTAssertEqual(table.meet, "33.06% from C1@12 · C1@24 · C2@12 to tcp")
  }

  /// The three meet forms that are one bare word, and a vertex that is not wrapped in a fraction.
  func testEasyOctagonsMeetsReadAsTheirOwnForms() throws {
    let rows = try rows(of: AuthoredPatterns.easyOctagon)

    let p1 = try XCTUnwrap(rows.first { $0.tier == "P1" })
    XCTAssertEqual(p1.meet, "tcp")

    let c1 = try XCTUnwrap(rows.first { $0.tier == "C1" })
    XCTAssertEqual(c1.meet, "girdle")

    let p2 = try XCTUnwrap(rows.first { $0.tier == "P2" })
    XCTAssertEqual(p2.meet, "G1@0 · G1@12 · P1@0")
    XCTAssertEqual(p2.angle, "43.00°")
    XCTAssertEqual(p2.indices, "6 18 30 42 54 66 78 90")
  }

  /// A bare-number tier label is a label, not a number to sort or renumber.
  func testRandsTwelveTierLabelsAreItsOwn() throws {
    let rows = try rows(of: AuthoredPatterns.rands)

    XCTAssertEqual(
      rows.map(\.tier), ["1", "2", "3", "4", "5", "A", "B", "C", "D", "E", "F", "G"])
  }

  func testEveryAuthoredPatternGivesOneRowPerAuthoredTier() throws {
    for name in AuthoredPatterns.all {
      let pattern = try AuthoredPatterns.load(name)
      let rows = tierTableRows(pattern: pattern, solid: benchSolid(for: pattern))

      XCTAssertEqual(rows.count, pattern.tiers.count, name)
      XCTAssertEqual(rows.map(\.id), rows.map(\.tier), name)
      XCTAssertEqual(Set(rows.map(\.id)).count, rows.count, "duplicate row identity in \(name)")
    }
  }

  // MARK: - The three cases the corpus cannot reach

  /// Every authored pattern happens to store its stops ascending, so nothing in the corpus exercises the
  /// order being data. Index order does not affect geometry — every facet of a tier shares one depth — so
  /// the same pattern still solves whole with its stops written round the other way.
  func testIndexStopsAreNeverSorted() throws {
    var pattern = try AuthoredPatterns.load(AuthoredPatterns.noviceAsher)
    let girdle = try XCTUnwrap(pattern.tiers.firstIndex { $0.tier == "G" })
    pattern.tiers[girdle].indices = [12, 24, 36, 48, 60, 72, 84, 0]

    let rows = tierTableRows(pattern: pattern, solid: benchSolid(for: pattern))
    let row = try XCTUnwrap(rows.first { $0.tier == "G" })

    XCTAssertEqual(row.indices, "12 24 36 48 60 72 84 0")
    for row in rows {
      XCTAssertEqual(row.state, .solved, row.tier)
    }
  }

  /// A tier on its own gear shows that gear, and shows it as its own rather than as the header's.
  func testATierOnItsOwnWheelIsTheOnlyOneNotInherited() throws {
    var pattern = try AuthoredPatterns.load(AuthoredPatterns.noviceAsher)
    let c1 = try XCTUnwrap(pattern.tiers.firstIndex { $0.tier == "C1" })
    pattern.tiers[c1].wheel = 64

    let rows = tierTableRows(pattern: pattern, solid: benchSolid(for: pattern))

    for row in rows where row.tier == "C1" {
      XCTAssertEqual(row.wheel, "64")
      XCTAssertFalse(row.wheelIsInherited)
    }
    for row in rows where row.tier != "C1" {
      XCTAssertEqual(row.wheel, "96", row.tier)
      XCTAssertTrue(row.wheelIsInherited, row.tier)
    }
  }

  func testInstructionsReadBackVerbatim() throws {
    var pattern = try AuthoredPatterns.load(AuthoredPatterns.noviceAsher)
    let p1 = try XCTUnwrap(pattern.tiers.firstIndex { $0.tier == "P1" })
    pattern.tiers[p1].instructions = "cut to the culet, then check the point"

    let rows = tierTableRows(pattern: pattern, solid: benchSolid(for: pattern))
    let row = try XCTUnwrap(rows.first { $0.tier == "P1" })

    XCTAssertEqual(row.instructions, "cut to the culet, then check the point")
  }

  // MARK: - The three states

  func testATierLimitLeavesTheTiersPastItNotReachedAndNoneStopped() throws {
    let pattern = try AuthoredPatterns.load(AuthoredPatterns.noviceAsher)
    let rows = tierTableRows(pattern: pattern, solid: benchSolid(for: pattern, tierLimit: 2))

    XCTAssertEqual(
      states(of: rows),
      [
        "G": .solved, "P1": .solved,
        "P2": .notReached, "P3": .notReached, "C1": .notReached, "C2": .notReached,
        "T": .notReached,
      ])
  }

  func testAStoppedSolveMarksTheTierThatStoppedItAndNothingElse() throws {
    var pattern = try AuthoredPatterns.load(AuthoredPatterns.noviceAsher)
    let p2 = try XCTUnwrap(pattern.tiers.firstIndex { $0.tier == "P2" })
    pattern.tiers[p2].meet = .fraction(
      from: .vertex(facets: [
        FacetRef(tier: "G", index: 12),
        FacetRef(tier: "G", index: 24),
        FacetRef(tier: "P9", index: 24),
      ]),
      percent: 24.862,
      to: .tcp)

    let rows = tierTableRows(pattern: pattern, solid: benchSolid(for: pattern))

    XCTAssertEqual(
      states(of: rows),
      [
        "G": .solved, "P1": .solved,
        "P2": .stopped,
        "P3": .notReached, "C1": .notReached, "C2": .notReached, "T": .notReached,
      ])
  }

  // MARK: - Helpers

  private func rows(of name: String) throws -> [TierTableRow] {
    let pattern = try AuthoredPatterns.load(name)
    return tierTableRows(pattern: pattern, solid: benchSolid(for: pattern))
  }

  private func states(of rows: [TierTableRow]) -> [String: TierRowState] {
    Dictionary(uniqueKeysWithValues: rows.map { ($0.tier, $0.state) })
  }
}
