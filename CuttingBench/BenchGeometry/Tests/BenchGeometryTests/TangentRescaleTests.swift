import FacetKernel
import Foundation
import XCTest

@testable import BenchGeometry

/// A side rescaled by tangent ratio: the rows it writes, the refusals it states, and the proof that the
/// plan view does not move. `AuthoredPatterns` lives in `BenchSolidTests.swift`.
final class TangentRescaleTests: XCTestCase {

  // MARK: - The rows the transform writes

  func testEasyOctagonsCrownRescalesFrom42To46() throws {
    let draft = try easyOctagon()
    guard case .success(let plan) = tangentRescale(handle: "C1", toAngle: 46, in: draft) else {
      return XCTFail("C1 at 46 was refused")
    }

    XCTAssertEqual(plan.handle, "C1")
    XCTAssertEqual(plan.target, 46)
    XCTAssertEqual(plan.ratio, 1.150073, accuracy: 1e-6)
    XCTAssertEqual(plan.ratioText, "1.1501")

    // In file order, the handle among them, and the flat table listed rather than silently skipped.
    XCTAssertEqual(plan.rows.map(\.tier), ["C1", "C2", "T"])
    XCTAssertEqual(plan.rows.map(\.current), ["42.00", "29.00", "0.00"])
    XCTAssertEqual(plan.rows.map(\.proposed), ["46.00", "32.52", "0.00"])
    XCTAssertEqual(plan.rows.map(\.proposedAngle), [46.00, 32.52, 0.00])
  }

  func testTheRescaleWritesAnglesAndNothingElse() throws {
    let draft = try easyOctagon()
    guard case .success(let edited) = rescaling(handle: "C1", toAngle: 46, in: draft) else {
      return XCTFail("C1 at 46 was refused")
    }

    XCTAssertEqual(
      angles(edited),
      ["G1": 90.00, "P1": 47.60, "P2": 43.00, "C1": 46.00, "C2": 32.52, "T": 0.00])

    // Everything the transform must not touch, compared as the whole draft with the angles put back.
    var restored = edited
    for position in restored.tiers.indices {
      restored.tiers[position].angle = draft.tiers[position].angle
    }
    XCTAssertEqual(restored, draft, "the rescale wrote something other than an angle")
  }

  func testRandsPavilionRescalesItsThreePavTiersAndNothingElse() throws {
    let draft = try load(AuthoredPatterns.rands)
    guard case .success(let plan) = tangentRescale(handle: "1", toAngle: 45, in: draft) else {
      return XCTFail("Rand's tier 1 at 45 was refused")
    }
    // The 65° tier rescales with the rest of its pavilion; the two girdle tiers and the whole crown
    // side are absent.
    XCTAssertEqual(plan.rows.map(\.tier), ["1", "4", "5"])
  }

  // MARK: - The plan view does not move

  func testRescalingEasyOctagonsCrownMovesHeightsAndNothingElse() throws {
    let draft = try easyOctagon()
    guard case .success(let edited) = rescaling(handle: "C1", toAngle: 46, in: draft) else {
      return XCTFail("C1 at 46 was refused")
    }
    let before = try metrics(solve(XCTUnwrap(draft.displayPattern)))
    let after = try metrics(solve(XCTUnwrap(edited.displayPattern)))

    XCTAssertEqual(after.facetCount, before.facetCount)
    XCTAssertEqual(after.widthNormalised, before.widthNormalised, accuracy: 1e-9)
    XCTAssertEqual(after.lengthNormalised, before.lengthNormalised, accuracy: 1e-9)
    XCTAssertEqual(after.lengthOverWidth, before.lengthOverWidth, accuracy: 1e-9)
    XCTAssertEqual(
      after.girdleThicknessNormalised, before.girdleThicknessNormalised, accuracy: 1e-9)
    XCTAssertEqual(
      after.pavilionDepthFractionOfWidth, before.pavilionDepthFractionOfWidth, accuracy: 1e-9)

    // The table's own radius holds to the 2 dp the format writes, and the crown's height scales by
    // exactly the ratio.
    XCTAssertEqual(after.tableFractionOfWidth, before.tableFractionOfWidth, accuracy: 2e-4)
    XCTAssertEqual(
      after.crownHeightFractionOfWidth, before.crownHeightFractionOfWidth * 1.150073,
      accuracy: 2e-4)
  }

  func testWithoutTheFormatsRoundingTheTransformIsExact() throws {
    let draft = try easyOctagon()
    let ratio = tan(46 * Double.pi / 180) / tan(42 * Double.pi / 180)

    // The same rescale by hand, with no 2 dp step anywhere: the `2e-4` above is the rounding the format
    // asks for and nothing else.
    var exact = draft
    for position in exact.tiers.indices where exact.tiers[position].part != .gdl {
      guard exact.tiers[position].part == .crown || exact.tiers[position].part == .table else {
        continue
      }
      let angle = exact.tiers[position].angle
      exact.tiers[position].angle = atan(ratio * tan(angle * Double.pi / 180)) * 180 / Double.pi
    }

    let before = try metrics(solve(XCTUnwrap(draft.displayPattern)))
    let after = try metrics(solve(XCTUnwrap(exact.displayPattern)))
    XCTAssertEqual(after.tableFractionOfWidth, before.tableFractionOfWidth, accuracy: 1e-12)
    XCTAssertEqual(after.widthNormalised, before.widthNormalised, accuracy: 1e-12)
  }

  // MARK: - The refusals

  func testAGirdleHandleIsRefusedByItsPart() throws {
    XCTAssertEqual(
      tangentRescale(handle: "G1", toAngle: 46, in: try easyOctagon()),
      .failure(.tuningHandleIsTheGirdle(tier: "G1")))
  }

  func testAFlatHandleHasNoRatioToMeasure() throws {
    XCTAssertEqual(
      tangentRescale(handle: "T", toAngle: 46, in: try easyOctagon()),
      .failure(.tuningHandleHasNoTangent(tier: "T", angle: 0)))
  }

  func testATargetAtEitherBoundIsRefused() throws {
    let draft = try easyOctagon()
    XCTAssertEqual(
      tangentRescale(handle: "C1", toAngle: 90, in: draft),
      .failure(.tuningTargetOutOfRange(tier: "C1", target: 90)))
    XCTAssertEqual(
      tangentRescale(handle: "C1", toAngle: 0, in: draft),
      .failure(.tuningTargetOutOfRange(tier: "C1", target: 0)))
  }

  func testAHandleTheDraftDoesNotCarryIsInert() throws {
    guard case .success(let plan) = tangentRescale(handle: "Z9", toAngle: 46, in: try easyOctagon())
    else { return XCTFail("an unknown label was refused rather than ignored") }
    XCTAssertEqual(plan.rows, [])
    XCTAssertEqual(plan.ratio, 1)
  }

  // MARK: - The drag

  func testTheDragSweepsFiveHundredthsOfADegreePerPoint() {
    XCTAssertEqual(draggedTuningTarget(from: 42, byPoints: 80), 46.00)
    XCTAssertEqual(draggedTuningTarget(from: 42, byPoints: -840), 0.10)
    XCTAssertEqual(draggedTuningTarget(from: 42, byPoints: 4000), 89.90)
  }

  // MARK: - Helpers

  private func load(_ name: String) throws -> PatternDraft {
    PatternDraft(try AuthoredPatterns.load(name))
  }

  private func easyOctagon() throws -> PatternDraft {
    try load(AuthoredPatterns.easyOctagon)
  }

  private func angles(_ draft: PatternDraft) -> [String: Double] {
    Dictionary(uniqueKeysWithValues: draft.tiers.map { ($0.tier, $0.angle) })
  }
}
