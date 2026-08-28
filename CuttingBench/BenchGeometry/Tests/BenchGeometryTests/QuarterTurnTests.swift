import FacetKernel
import Foundation
import XCTest

@testable import BenchGeometry

/// A pattern turned a quarter turn: every stop and every named index advanced a quarter of its own gear,
/// refused whole on a gear that does not divide by 4. `AuthoredPatterns` lives in `BenchSolidTests.swift`.
final class QuarterTurnTests: XCTestCase {

  // MARK: - What one turn writes

  func testEasyOctagonsStopsAdvanceByTwentyFourInTheAuthoredOrder() throws {
    let turned = try turn(easyOctagon())
    XCTAssertEqual(indices(turned, "G1"), [24, 36, 48, 60, 72, 84, 0, 12])
    XCTAssertEqual(indices(turned, "C2"), [42, 66, 90, 18])
  }

  func testEveryNamedIndexAdvancesOnTheGearOfTheTierItNames() throws {
    let turned = try turn(easyOctagon())
    XCTAssertEqual(
      meet(turned, "P2"),
      .vertex(facets: [ref("G1", 24), ref("G1", 36), ref("P1", 24)]))
    XCTAssertEqual(
      meet(turned, "C2"),
      .vertex(facets: [ref("G1", 36), ref("G1", 48), ref("C1", 36)]))
    XCTAssertEqual(
      meet(turned, "T"),
      .vertex(facets: [ref("C1", 24), ref("C1", 36), ref("C2", 42)]))
  }

  func testTheFormsThatCarryNoIndexComeBackUnchanged() throws {
    let turned = try turn(easyOctagon())
    XCTAssertEqual(meet(turned, "G1"), .size)
    XCTAssertEqual(meet(turned, "P1"), .tcp)
    XCTAssertEqual(meet(turned, "C1"), .girdle)
  }

  func testTheTurnWritesStopsAndMeetsAndNothingElse() throws {
    let draft = try easyOctagon()
    let turned = try turn(draft)

    XCTAssertEqual(turned.wheel, draft.wheel)
    XCTAssertEqual(turned.ri, draft.ri)
    XCTAssertEqual(turned.girdleTargetFraction, draft.girdleTargetFraction)
    XCTAssertEqual(turned.tiers.map(\.tier), draft.tiers.map(\.tier))
    XCTAssertEqual(turned.tiers.map(\.angle), draft.tiers.map(\.angle))
    XCTAssertEqual(turned.tiers.map(\.part), draft.tiers.map(\.part))
  }

  // MARK: - The stone is the same stone

  func testTurningMovesNoMeasurementOfTheStone() throws {
    for name in [AuthoredPatterns.easyOctagon, AuthoredPatterns.rands] {
      let draft = try load(name)
      let before = try metrics(solve(XCTUnwrap(draft.displayPattern)))
      let after = try metrics(solve(XCTUnwrap(turn(draft).displayPattern)))

      XCTAssertEqual(after.facetCount, before.facetCount, name)
      XCTAssertEqual(after.rotationalOrder, before.rotationalOrder, name)
      XCTAssertEqual(after.widthNormalised, before.widthNormalised, accuracy: 1e-9, name)
      XCTAssertEqual(after.lengthNormalised, before.lengthNormalised, accuracy: 1e-9, name)
      XCTAssertEqual(after.lengthOverWidth, before.lengthOverWidth, accuracy: 1e-9, name)
      XCTAssertEqual(
        after.girdleThicknessNormalised, before.girdleThicknessNormalised, accuracy: 1e-9, name)
      XCTAssertEqual(
        after.girdleFractionOfWidth, before.girdleFractionOfWidth, accuracy: 1e-9, name)
      XCTAssertEqual(
        after.crownHeightFractionOfWidth, before.crownHeightFractionOfWidth, accuracy: 1e-9, name)
      XCTAssertEqual(
        after.pavilionDepthFractionOfWidth, before.pavilionDepthFractionOfWidth, accuracy: 1e-9,
        name)
      XCTAssertEqual(
        after.totalDepthFractionOfWidth, before.totalDepthFractionOfWidth, accuracy: 1e-9, name)
      XCTAssertEqual(
        after.tableFractionOfWidth, before.tableFractionOfWidth, accuracy: 1e-9, name)

      // `mirrorAxes` is deliberately absent: those are index positions on the stone, and turning the
      // stone moves them. That is the operation working, not a fault.
    }
  }

  func testFourTurnsAreTheIdentity() throws {
    for name in [AuthoredPatterns.easyOctagon, AuthoredPatterns.rands] {
      let draft = try load(name)
      XCTAssertEqual(try turn(turn(turn(turn(draft)))), draft, name)
    }
  }

  // MARK: - The refusal, which changes nothing

  func testAHeaderGearThatDoesNotDivideByFourIsNamedAsThePatterns() throws {
    var draft = try easyOctagon()
    draft.wheel = 90
    XCTAssertEqual(
      turningAQuarter(draft), .failure(.quarterTurnGearNotDivisible(tier: nil, wheel: 90)))
  }

  func testATiersOwnGearThatDoesNotDivideByFourIsNamedWithItsTier() throws {
    var draft = try easyOctagon()
    draft.tiers[3].wheel = 90
    XCTAssertEqual(
      turningAQuarter(draft),
      .failure(.quarterTurnGearNotDivisible(tier: draft.tiers[3].tier, wheel: 90)))
  }

  func testARefusedTurnRewritesNothing() throws {
    var draft = try easyOctagon()
    draft.wheel = 90
    let untouched = draft
    _ = turningAQuarter(draft)
    XCTAssertEqual(draft, untouched)

    draft = try easyOctagon()
    draft.tiers[3].wheel = 90
    let alsoUntouched = draft
    _ = turningAQuarter(draft)
    XCTAssertEqual(draft, alsoUntouched)
  }

  func testTheHeaderGearIsCheckedEvenWhenNoTierInheritsIt() throws {
    var draft = try easyOctagon()
    draft.wheel = 90
    for position in draft.tiers.indices { draft.tiers[position].wheel = 96 }
    XCTAssertEqual(
      turningAQuarter(draft), .failure(.quarterTurnGearNotDivisible(tier: nil, wheel: 90)))
  }

  // MARK: - Helpers

  private func load(_ name: String) throws -> PatternDraft {
    PatternDraft(try AuthoredPatterns.load(name))
  }

  private func easyOctagon() throws -> PatternDraft {
    try load(AuthoredPatterns.easyOctagon)
  }

  private func turn(_ draft: PatternDraft) throws -> PatternDraft {
    switch turningAQuarter(draft) {
    case .success(let turned): return turned
    case .failure(let refusal): throw RefusedTurn(refusal: refusal)
    }
  }

  private func indices(_ draft: PatternDraft, _ tier: String) -> [Int]? {
    draft.tiers.first { $0.tier == tier }?.indices
  }

  private func meet(_ draft: PatternDraft, _ tier: String) -> Meet? {
    draft.tiers.first { $0.tier == tier }?.meet
  }

  private func ref(_ tier: String, _ index: Int) -> FacetRef {
    FacetRef(tier: tier, index: index)
  }
}

private struct RefusedTurn: Error {
  let refusal: DraftRefusal
}
