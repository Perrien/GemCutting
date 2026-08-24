import Foundation
import XCTest

@testable import FacetKernel

/// A quarter turn is not a different stone. Rotating every index stop by a quarter of the wheel gives the
/// same solid in a different orientation, so every measure of it has to come back identical — and before
/// width and length were labelled by size, they did not: the same stone read `L/W 1.36603` one way round
/// and `0.73205` the other, because width was always taken off the 90-270 axis.
///
/// `Rand's Cut Corner Rectangle #1` is the pattern that shows it. The other three authored patterns are
/// square or round, so a quarter turn maps them onto themselves and proves nothing.
final class QuarterTurnTests: XCTestCase {
  private let girdle = 0.040493
  /// A quarter of Rand's 96-stop wheel. Every one of its tiers is on 96, so one shift serves them all.
  private let quarter = 24

  func testAQuarterTurnChangesNothingMeasurable() throws {
    let original = try AuthoredPatterns.load(AuthoredPatterns.rands)
    let rotated = Self.rotated(original, by: quarter)

    let before = metrics(try solve(original, girdleTargetFraction: girdle))
    let after = metrics(try solve(rotated, girdleTargetFraction: girdle))

    XCTAssertEqual(after.facetCount, before.facetCount)
    XCTAssertEqual(after.rotationalOrder, before.rotationalOrder)
    XCTAssertEqual(after.facetsPerTier, before.facetsPerTier)
    XCTAssertEqual(
      after.mirrorAxes.count, before.mirrorAxes.count, "the axes move; how many does not")

    for (name, pair) in [
      ("widthNormalised", (after.widthNormalised, before.widthNormalised)),
      ("lengthNormalised", (after.lengthNormalised, before.lengthNormalised)),
      ("lengthOverWidth", (after.lengthOverWidth, before.lengthOverWidth)),
      (
        "girdleThicknessNormalised",
        (after.girdleThicknessNormalised, before.girdleThicknessNormalised)
      ),
      ("girdleFractionOfWidth", (after.girdleFractionOfWidth, before.girdleFractionOfWidth)),
      (
        "pavilionDepthFractionOfWidth",
        (after.pavilionDepthFractionOfWidth, before.pavilionDepthFractionOfWidth)
      ),
      (
        "crownHeightFractionOfWidth",
        (after.crownHeightFractionOfWidth, before.crownHeightFractionOfWidth)
      ),
      (
        "totalDepthFractionOfWidth",
        (after.totalDepthFractionOfWidth, before.totalDepthFractionOfWidth)
      ),
      ("tableFractionOfWidth", (after.tableFractionOfWidth, before.tableFractionOfWidth)),
    ] {
      XCTAssertEqual(pair.0, pair.1, accuracy: 1e-9, name)
    }
  }

  /// Two hard-coded anchors, so a regression that moved both stones together is still caught, and one
  /// explicit refusal of the number the shipped code used to give.
  func testTheRotatedStoneMeasuresTheSheetsOwnFigures() throws {
    let rotated = Self.rotated(try AuthoredPatterns.load(AuthoredPatterns.rands), by: quarter)
    let measured = metrics(try solve(rotated, girdleTargetFraction: girdle))

    XCTAssertEqual(measured.widthNormalised, 1.464102, accuracy: 1e-5)
    XCTAssertEqual(measured.lengthOverWidth, 1.36603, accuracy: 1e-5)
    // 0.73205 is what this pattern reported before width became the smaller extent — the reciprocal, the
    // stone read across the wrong axis. Named here so a revert fails this test instead of passing it.
    XCTAssertNotEqual(measured.lengthOverWidth, 0.73205, accuracy: 1e-5)
  }

  // MARK: - Rotating a pattern

  /// Every index stop shifted by `stops`, in the tiers and inside every meet — including the nested
  /// endpoints of a `fraction`, which is why the rewrite recurses. Nothing else about the pattern changes.
  private static func rotated(_ pattern: FacetKernel.Pattern, by stops: Int) -> FacetKernel.Pattern
  {
    var turned = pattern
    turned.tiers = pattern.tiers.map { spec in
      var tier = spec
      let wheel = pattern.wheel(of: spec)
      tier.indices = spec.indices.map { ($0 + stops) % wheel }
      tier.meet = rotated(spec.meet, by: stops, on: pattern)
      return tier
    }
    return turned
  }

  private static func rotated(_ meet: Meet, by stops: Int, on pattern: FacetKernel.Pattern) -> Meet
  {
    switch meet {
    case .size, .tcp, .girdle:
      return meet
    case .vertex(let facets):
      return .vertex(facets: facets.map { rotated($0, by: stops, on: pattern) })
    case .fraction(let from, let percent, let to):
      return .fraction(
        from: rotated(from, by: stops, on: pattern),
        percent: percent,
        to: rotated(to, by: stops, on: pattern)
      )
    }
  }

  /// A named facet moves with the tier it names, on that tier's own wheel.
  private static func rotated(
    _ facet: FacetRef,
    by stops: Int,
    on pattern: FacetKernel.Pattern
  ) -> FacetRef {
    guard let spec = pattern.tiers.first(where: { $0.tier == facet.tier }) else { return facet }
    let wheel = pattern.wheel(of: spec)
    return FacetRef(tier: facet.tier, index: (facet.index + stops) % wheel)
  }
}
