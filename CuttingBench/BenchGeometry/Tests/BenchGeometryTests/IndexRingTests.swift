import FacetKernel
import Foundation
import XCTest

@testable import BenchGeometry

/// The ring's labels and its fade. `AuthoredPatterns` lives in `BenchSolidTests.swift`.
final class IndexRingTests: XCTestCase {

  // MARK: - One label per distinct stop

  func testTheRoundBrilliantsRingIsOneLabelPerDistinctStop() throws {
    let solid = benchSolid(for: try AuthoredPatterns.load(AuthoredPatterns.roundBrilliant))
    let labels = indexRingLabels(solid)

    var stops: Set<SIMD2<Int>> = []
    for tier in solid.tiers {
      for index in tier.indices { stops.insert(SIMD2(tier.wheel, index)) }
    }

    XCTAssertEqual(labels.count, 32)
    XCTAssertEqual(labels.count, stops.count)
    XCTAssertEqual(Set(labels.map(\.id)), stops)
    XCTAssertEqual(Set(labels.map(\.id)).count, labels.count)
  }

  // MARK: - The text

  func testASingleWheelPatternReadsAsTheBareIndex() throws {
    let solid = benchSolid(for: try AuthoredPatterns.load(AuthoredPatterns.roundBrilliant))
    let labels = indexRingLabels(solid)

    XCTAssertEqual(Set(labels.map(\.wheel)), [96])
    for label in labels {
      XCTAssertEqual(label.text, "\(label.index)")
    }
  }

  func testTwoWheelsSwitchEveryLabelToIndexOverWheel() throws {
    var pattern = try AuthoredPatterns.load(AuthoredPatterns.roundBrilliant)
    // The table lies on the axis at angle 0, so its plane is the same on every wheel, and no other
    // tier's meet names it — declaring it on a second gear changes no geometry at all, which is what
    // makes it the honest way to reach the two-wheel case from an authored pattern.
    let table = try XCTUnwrap(pattern.tiers.firstIndex { $0.tier == "t" })
    pattern.tiers[table].wheel = 192

    let labels = indexRingLabels(benchSolid(for: pattern))

    XCTAssertTrue(labels.contains { $0.wheel == 96 })
    XCTAssertTrue(labels.contains { $0.wheel == 192 })
    for label in labels {
      XCTAssertEqual(label.text, "\(label.index)/\(label.wheel)")
    }
  }

  // MARK: - Where the anchors sit

  func testEveryAnchorSitsOnTheRingCircleAtItsOwnAzimuth() throws {
    let labels = indexRingLabels(
      benchSolid(for: try AuthoredPatterns.load(AuthoredPatterns.roundBrilliant)))
    XCTAssertFalse(labels.isEmpty)

    for label in labels {
      let theta = 2 * Double.pi * Double(label.index) / Double(label.wheel)
      XCTAssertEqual(label.anchor.x, Float(cos(theta) * IndexRing.radius), accuracy: 1e-5)
      XCTAssertEqual(label.anchor.y, Float(sin(theta) * IndexRing.radius), accuracy: 1e-5)
      XCTAssertEqual(Double(label.anchor.z), IndexRing.z, accuracy: 1e-9)
      XCTAssertEqual(
        Double(hypot(label.anchor.x, label.anchor.y)), IndexRing.radius, accuracy: 1e-5)
    }

    // Index 0 to the right of centre, and the index rising counter-clockwise from it (D3, D14).
    let first = try XCTUnwrap(labels.first)
    XCTAssertEqual(first.index, 0)
    XCTAssertEqual(Double(first.anchor.x), IndexRing.radius, accuracy: 1e-6)
    XCTAssertEqual(first.anchor.y, 0, accuracy: 1e-6)
    let stopThree = try XCTUnwrap(labels.first { $0.index == 3 })
    XCTAssertGreaterThan(stopThree.anchor.y, 0)
  }

  func testTheLabelsAreInAscendingAzimuthOrder() throws {
    let labels = indexRingLabels(
      benchSolid(for: try AuthoredPatterns.load(AuthoredPatterns.roundBrilliant)))

    let azimuths = labels.map { Double($0.index) / Double($0.wheel) }
    XCTAssertEqual(azimuths, azimuths.sorted())
  }

  // MARK: - No pattern, no ring (D17)

  func testWithNoPatternThereAreNoLabels() {
    XCTAssertTrue(indexRingLabels(benchSolid(for: nil)).isEmpty)
    XCTAssertTrue(benchSolid(for: nil).tiers.isEmpty)
  }

  // MARK: - The fade

  func testTheRingIsGoneEdgeOnAndFullFromTheFadeAngleUp() {
    XCTAssertEqual(indexRingAlpha(camera(at: 0)), 0, accuracy: 1e-9)
    XCTAssertEqual(indexRingAlpha(camera(at: 6)), 0.5, accuracy: 1e-6)
    XCTAssertEqual(indexRingAlpha(camera(at: -6)), 0.5, accuracy: 1e-6)
    XCTAssertEqual(indexRingAlpha(camera(at: 12)), 1, accuracy: 1e-9)
    XCTAssertEqual(indexRingAlpha(camera(at: 90)), 1, accuracy: 1e-9)
    XCTAssertEqual(indexRingAlpha(.faceUp), 1, accuracy: 1e-9)
    XCTAssertEqual(indexRingAlpha(.faceDown), 1, accuracy: 1e-9)
  }

  // MARK: - Helpers

  private func camera(at elevation: Float) -> BenchCameraState {
    BenchCameraState(azimuthDegrees: 45, elevationDegrees: elevation)
  }
}
