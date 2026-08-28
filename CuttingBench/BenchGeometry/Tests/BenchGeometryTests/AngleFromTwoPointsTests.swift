import FacetKernel
import Foundation
import XCTest
import simd

@testable import BenchGeometry

/// A tier's angle from its aimed facet and two picked points, and the three ways it cannot work.
/// Every case here is arithmetic over points given directly, so none of them needs a solid or a solve.
final class AngleFromTwoPointsTests: XCTestCase {

  // MARK: - The azimuth a point is measured along

  func testAPointsRadiusIsMeasuredAlongTheAimedFacetsOwnAzimuth() {
    let onY = SIMD3<Double>(0, 1, 0)
    XCTAssertEqual(azimuthRadius(of: onY, atStop: 24, wheel: 96), 1, accuracy: 1e-12)
    XCTAssertEqual(azimuthRadius(of: onY, atStop: 0, wheel: 96), 0, accuracy: 1e-12)
  }

  // MARK: - The angle itself

  func testACrownTierTakesFortyFiveFromTwoPointsOnItsOwnAzimuth() {
    XCTAssertEqual(
      try angle(part: .crown, stops: [0], at(1, 0, 0), at(0.5, 0, 0.5)), 45.00)
  }

  func testThoseSamePointsFaceTheWrongWayForAPavilionTier() {
    let result = derivedAngle(
      ofTier: "P1", aimedStop: 0, wheel: 96, part: .pav, stops: [0],
      first: end(at(1, 0, 0)), second: end(at(0.5, 0, 0.5)))
    guard case .failure(.derivedAngleContradictsPart(let tier, let part, let reported, _)) = result
    else { return XCTFail("a pavilion tier accepted an upward-facing plane — \(result)") }
    XCTAssertEqual(tier, "P1")
    XCTAssertEqual(part, .pav)
    XCTAssertEqual(reported, -45.00, accuracy: 1e-9)
  }

  func testAPavilionTierTakesFortyFiveFromPointsItCouldReach() {
    XCTAssertEqual(
      try angle(part: .pav, stops: [0], at(1, 0, 0), at(0.5, 0, -0.5)), 45.00)
  }

  func testTwoPointsAtOneHeightAreATableAndNotAContradiction() {
    XCTAssertEqual(
      try angle(part: .table, stops: [0], at(0.8, 0, 0.5), at(-0.3, 0.4, 0.5)), 0.00)
  }

  func testTwoPointsAtOneRadiusAreAVerticalFacetAndNotAFailure() {
    XCTAssertEqual(
      try angle(part: .crown, stops: [0], at(0.7, 0, 0), at(0.7, 0, 0.5)), 90.00)
  }

  // MARK: - Coincident points

  func testTwoPointsAtOnePlaceOnTheAzimuthNameNoTilt() {
    let result = derivedAngle(
      ofTier: "C1", aimedStop: 0, wheel: 96, part: .crown, stops: [0],
      first: end(at(0.7, 0.3, 0.4)), second: end(at(0.7, -0.3, 0.4)))
    guard case .failure(.derivationPointsCoincide(let tier, let numbers)) = result else {
      return XCTFail("two coincident points were accepted — \(result)")
    }
    XCTAssertEqual(tier, "C1")
    XCTAssertEqual(numbers.stop, 0)
    XCTAssertEqual(numbers.r1, 0.7, accuracy: 1e-12)
    XCTAssertEqual(numbers.r2, 0.7, accuracy: 1e-12)
    XCTAssertEqual(numbers.z1, 0.4, accuracy: 1e-12)
    XCTAssertEqual(numbers.z2, 0.4, accuracy: 1e-12)
  }

  // MARK: - A sibling facet arriving first

  func testASiblingFacetTakingTheDepthIsRefusedAndNamesTheStopThatArrives() {
    let result = derivedAngle(
      ofTier: "C1", aimedStop: 0, wheel: 96, part: .crown, stops: [0, 12],
      first: end(at(0.70710678, 0.70710678, 0)),
      second: end(at(0.35355339, 0.35355339, 0.5)))
    guard
      case .failure(
        .siblingFacetTakesTheDepth(
          let tier, let aimed, let arrives, let written, let aimedDot, let arrivingDot)) = result
    else { return XCTFail("a sibling taking the depth was accepted — \(result)") }
    XCTAssertEqual(tier, "C1")
    XCTAssertEqual(aimed, 0)
    XCTAssertEqual(arrives, 12)
    XCTAssertEqual(written, 54.74)
    XCTAssertGreaterThan(arrivingDot, aimedDot)
    XCTAssertEqual(arrivingDot, 0.8165, accuracy: 2e-3)
    XCTAssertEqual(aimedDot, 0.5775, accuracy: 2e-3)
  }

  func testATieBetweenTwoFacetsPassesBecauseTheDepthIsTheSameEitherWay() throws {
    // Both points sit on the bisector between stops 0 and 12 — azimuth 22.5° — so the two facets
    // project the anchor to the same radius and neither arrives first.
    let derived = try angle(
      part: .crown, stops: [0, 12],
      at(0.92387953, 0.38268343, 0), at(0.46193977, 0.19134172, 0.5))
    XCTAssertGreaterThan(derived, 47.2)
    XCTAssertLessThan(derived, 47.3)
  }

  // MARK: - Which end is written

  func testAPointThatMustBeHitOutranksOneThatMaySlide() {
    XCTAssertTrue(isCornerEnd(.vertex(facets: [])))
    XCTAssertTrue(isCornerEnd(.tcp))
    XCTAssertFalse(isCornerEnd(.fraction(from: .tcp, percent: 50, to: .tcp)))
    XCTAssertFalse(isCornerEnd(.size))
    XCTAssertFalse(isCornerEnd(.girdle))

    let vertex = end(at(1, 0, 0), meet: .vertex(facets: []))
    let slide = end(at(1, 0, 0), meet: .fraction(from: .tcp, percent: 50, to: .tcp))
    let axial = end(at(1, 0, 0), meet: .tcp)

    XCTAssertEqual(anchorEnd(first: vertex, second: slide), 0)
    XCTAssertEqual(anchorEnd(first: slide, second: vertex), 1)
    XCTAssertEqual(anchorEnd(first: vertex, second: vertex), 0)
    XCTAssertEqual(anchorEnd(first: axial, second: slide), 0)
    XCTAssertEqual(anchorEnd(first: slide, second: slide), 0)
  }

  func testTheAnchorEndIsTheMeetThatGetsWritten() throws {
    let slide = DerivationEnd(
      meet: .fraction(from: .tcp, percent: 50, to: .tcp), point: at(1, 0, 0))
    let corner = DerivationEnd(
      meet: .vertex(facets: [FacetRef(tier: "G1", index: 0)]), point: at(0.5, 0, 0.5))
    guard
      case .success(let derived) = derivedAngle(
        ofTier: "C1", aimedStop: 0, wheel: 96, part: .crown, stops: [0],
        first: slide, second: corner)
    else { return XCTFail("the derivation was refused") }
    XCTAssertEqual(derived.meet, corner.meet, "the end that may slide was written")
  }

  // MARK: - The prompt

  func testTheDerivationPromptReadsTheAimedFacetThenTheStage() {
    XCTAssertEqual(
      angleDerivationPrompt(
        tier: "C2", aimedStop: 18, pointsTaken: 0, stage: .empty,
        solid: benchSolid(for: nil)),
      "Deriving C2@18's angle · point 1 of 2 · click a facet, or an edge")
  }

  // MARK: - Helpers

  private func at(_ x: Double, _ y: Double, _ z: Double) -> SIMD3<Double> {
    SIMD3<Double>(x, y, z)
  }

  private func end(_ point: SIMD3<Double>, meet: Meet = .vertex(facets: [])) -> DerivationEnd {
    DerivationEnd(meet: meet, point: point)
  }

  private func angle(
    part: Part, stops: [Int], _ first: SIMD3<Double>, _ second: SIMD3<Double>
  ) throws -> Double {
    switch derivedAngle(
      ofTier: "X", aimedStop: 0, wheel: 96, part: part, stops: stops,
      first: end(first), second: end(second))
    {
    case .success(let derived): return derived.angle
    case .failure(let refusal): throw RefusedDerivation(refusal: refusal)
    }
  }
}

private struct RefusedDerivation: Error {
  let refusal: DraftRefusal
}
