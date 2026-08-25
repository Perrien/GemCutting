import FacetKernel
import Foundation
import XCTest

@testable import BenchGeometry

/// The tier table's rows, read off the corpus and off three constructed cases the corpus cannot reach.
/// `AuthoredPatterns` lives in `BenchSolidTests.swift`.
final class TierTableTests: XCTestCase {

  // MARK: - No pattern

  func testNoPatternIsNoRows() {
    let solid = benchSolid(for: nil)

    XCTAssertTrue(
      tierTableRows(
        pattern: nil, solid: solid,
        light: lightReadout(pattern: nil, solid: solid, riOverride: "")
      ).isEmpty)
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
      let solid = benchSolid(for: pattern)
      let rows = tierTableRows(
        pattern: pattern, solid: solid,
        light: lightReadout(pattern: pattern, solid: solid, riOverride: ""))

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

    let solid = benchSolid(for: pattern)
    let rows = tierTableRows(
      pattern: pattern, solid: solid,
      light: lightReadout(pattern: pattern, solid: solid, riOverride: ""))
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

    let solid = benchSolid(for: pattern)
    let rows = tierTableRows(
      pattern: pattern, solid: solid,
      light: lightReadout(pattern: pattern, solid: solid, riOverride: ""))

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

    let solid = benchSolid(for: pattern)
    let rows = tierTableRows(
      pattern: pattern, solid: solid,
      light: lightReadout(pattern: pattern, solid: solid, riOverride: ""))
    let row = try XCTUnwrap(rows.first { $0.tier == "P1" })

    XCTAssertEqual(row.instructions, "cut to the culet, then check the point")
  }

  // MARK: - The three states

  func testATierLimitLeavesTheTiersPastItNotReachedAndNoneStopped() throws {
    let pattern = try AuthoredPatterns.load(AuthoredPatterns.noviceAsher)
    let solid = benchSolid(for: pattern, tierLimit: 2)
    let rows = tierTableRows(
      pattern: pattern, solid: solid,
      light: lightReadout(pattern: pattern, solid: solid, riOverride: ""))

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

    let solid = benchSolid(for: pattern)
    let rows = tierTableRows(
      pattern: pattern, solid: solid,
      light: lightReadout(pattern: pattern, solid: solid, riOverride: ""))

    XCTAssertEqual(
      states(of: rows),
      [
        "G": .solved, "P1": .solved,
        "P2": .stopped,
        "P3": .notReached, "C1": .notReached, "C2": .notReached, "T": .notReached,
      ])
  }

  // MARK: - The row carries its meet's named points

  /// The chips and the one-line `meet` are both on the row: the cell prefers the chips when there are
  /// any, and the text is unchanged for the rows that have none.
  func testTheRowCarriesItsMeetPointsWithoutChangingItsMeetText() throws {
    let rows = try rows(of: AuthoredPatterns.noviceAsher)

    let p2 = try XCTUnwrap(rows.first { $0.tier == "P2" })
    XCTAssertEqual(p2.meetPoints.count, 3)
    XCTAssertEqual(p2.meet, "24.86% from G@12 · G@24 · P1@24 to tcp")

    let girdle = try XCTUnwrap(rows.first { $0.tier == "G" })
    XCTAssertEqual(girdle.meetPoints.count, 0)
    XCTAssertEqual(girdle.meet, "size")
  }

  // MARK: - The leak mark

  /// No authored pattern leaks at its own refractive index, so the whole table is bare — which is the
  /// state the owner sees every day, and the one a false positive would show up against.
  func testNoRowOfTheRoundBrilliantMarksAtItsOwnRefractiveIndex() throws {
    let rows = try rows(of: AuthoredPatterns.roundBrilliant)

    XCTAssertEqual(rows.filter(\.leaksLight).map(\.tier), [])
    XCTAssertEqual(rows.filter { !$0.leakShortfall.isEmpty }.map(\.tier), [])
  }

  /// The override drops the critical angle to `50.28°`, which is below both pavilion tiers. The cell
  /// carries the bare figure; the word `shallow` is the card's, and the orange symbol says which way it
  /// falls.
  func testAtOneThirtyExactlyThePavilionRowsMarkWithTheirShortfall() throws {
    let rows = try rows(of: AuthoredPatterns.roundBrilliant, riOverride: "1.30")

    XCTAssertEqual(rows.filter(\.leaksLight).map(\.tier), ["pb", "pm"])

    let pb = try XCTUnwrap(rows.first { $0.tier == "pb" })
    XCTAssertEqual(pb.angle, "45.00°")
    XCTAssertEqual(pb.leakShortfall, "5.28°")

    let pm = try XCTUnwrap(rows.first { $0.tier == "pm" })
    XCTAssertEqual(pm.angle, "43.00°")
    XCTAssertEqual(pm.leakShortfall, "7.28°")
  }

  /// The check asks whether a vertical ray reflects off the pavilion, and that ray lands nowhere else —
  /// so a crown tier shallower than the same critical angle stays bare, and so do the girdle and the
  /// table.
  func testACrownTierBelowTheCriticalAngleStaysUnmarked() throws {
    let rows = try rows(of: AuthoredPatterns.roundBrilliant, riOverride: "1.30")

    let cm = try XCTUnwrap(rows.first { $0.tier == "cm" })
    XCTAssertEqual(cm.angle, "42.00°")
    XCTAssertFalse(cm.leaksLight)
    XCTAssertEqual(cm.leakShortfall, "")

    let girdle = try XCTUnwrap(rows.first { $0.tier == "g" })
    XCTAssertEqual(girdle.angle, "90.00°")
    XCTAssertFalse(girdle.leaksLight)

    let table = try XCTUnwrap(rows.first { $0.tier == "t" })
    XCTAssertEqual(table.angle, "0.00°")
    XCTAssertFalse(table.leaksLight)
  }

  // MARK: - Helpers

  private func rows(of name: String, riOverride: String = "") throws -> [TierTableRow] {
    let pattern = try AuthoredPatterns.load(name)
    let solid = benchSolid(for: pattern)
    return tierTableRows(
      pattern: pattern, solid: solid,
      light: lightReadout(pattern: pattern, solid: solid, riOverride: riOverride))
  }

  private func states(of rows: [TierTableRow]) -> [String: TierRowState] {
    Dictionary(uniqueKeysWithValues: rows.map { ($0.tier, $0.state) })
  }
}
