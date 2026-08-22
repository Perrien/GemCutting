import Foundation
import XCTest

@testable import FacetKernel

/// Changing the girdle target slides the crown and changes nothing else.
///
/// No meet can cross the girdle band: the band sits between the crown and the pavilion, so a crown facet
/// and a pavilion facet never share a vertex, and every crown meet chains back to the girdle-top corner or
/// to another crown facet. Making the band thicker therefore moves the crown as one body — it cannot alter
/// the facet count, the culet, the table, or any crown proportion measured from the girdle top.
///
/// This is worth a test because the failure it catches is specific: a violation means the girdle value has
/// leaked into a pavilion depth, or a crown meet has resolved against a pavilion facet.
final class GirdleInvarianceTests: XCTestCase {
  private static let thin = 0.02
  private static let thick = 0.08

  private static let patterns = [
    AuthoredPatterns.easyOctagon,
    AuthoredPatterns.noviceAsher,
    AuthoredPatterns.rands,
  ]

  func testTheCrownSlidesAndNothingElseMoves() throws {
    for file in Self.patterns {
      let pattern = try AuthoredPatterns.load(file)
      let thin = try solve(pattern, girdleTargetFraction: Self.thin)
      let thick = try solve(pattern, girdleTargetFraction: Self.thick)
      let (lean, full) = (metrics(thin), metrics(thick))

      XCTAssertEqual(lean.facetCount, full.facetCount, file)
      XCTAssertEqual(lean.facetsPerTier, full.facetsPerTier, file)
      XCTAssertEqual(culetZ(of: thin), culetZ(of: thick), accuracy: 1e-9, "\(file) culet")
      XCTAssertEqual(
        tableRadius(of: thin), tableRadius(of: thick), accuracy: 1e-9, "\(file) table radius")
      XCTAssertEqual(
        crownHeight(lean), crownHeight(full), accuracy: 1e-9, "\(file) crown height")
      XCTAssertEqual(lean.lengthOverWidth, full.lengthOverWidth, accuracy: 1e-9, "\(file) L/W")
      XCTAssertEqual(
        lean.widthNormalised, full.widthNormalised, accuracy: 1e-9, "\(file) width")

      // And the one thing that must move, by exactly the band's difference: an implementation that
      // ignored the parameter altogether would pass every assertion above.
      XCTAssertEqual(
        totalDepth(full) - totalDepth(lean),
        (Self.thick - Self.thin) * lean.widthNormalised,
        accuracy: 1e-9,
        "\(file) total depth"
      )
    }
  }

  /// The same invariance in absolute figures, so a regression that moved everything together would still
  /// be caught.
  func testEasyOctagonsFiguresAreTheSameAtBothSettings() throws {
    let pattern = try AuthoredPatterns.load(AuthoredPatterns.easyOctagon)

    for fraction in [Self.thin, Self.thick] {
      let solution = try solve(pattern, girdleTargetFraction: fraction)
      let measured = metrics(solution)

      XCTAssertEqual(measured.facetCount, 37, "at \(fraction)")
      XCTAssertEqual(culetZ(of: solution), -1.00935, accuracy: 1e-5, "at \(fraction)")
      XCTAssertEqual(tableRadius(of: solution), 0.68292, accuracy: 1e-5, "at \(fraction)")
      XCTAssertEqual(crownHeight(measured), 0.33230, accuracy: 1e-5, "at \(fraction)")
    }
  }

  // MARK: - Measures this file needs and `Metrics` does not carry

  /// The deepest point of the stone, which for all three patterns is a point culet.
  private func culetZ(of solution: Solution) -> Double {
    solution.polytope.vertices.map(\.z).min() ?? 0
  }

  /// How far the table reaches from the axis, at its corners. A rigid translation of the crown cannot
  /// change it.
  private func tableRadius(of solution: Solution) -> Double {
    var radius = 0.0
    for (plane, polygon) in solution.polytope.facets {
      let normal = solution.planes[plane].n
      guard abs(normal.x) < 1e-9, abs(normal.y) < 1e-9, normal.z > 0 else { continue }
      for vertex in polygon.map({ solution.polytope.vertices[$0] }) {
        radius = Swift.max(radius, (vertex.x * vertex.x + vertex.y * vertex.y).squareRoot())
      }
    }
    return radius
  }

  /// Girdle top to table, in `size` units rather than as a fraction of the width.
  private func crownHeight(_ measured: Metrics) -> Double {
    measured.crownHeightFractionOfWidth * measured.widthNormalised
  }

  private func totalDepth(_ measured: Metrics) -> Double {
    measured.totalDepthFractionOfWidth * measured.widthNormalised
  }
}
