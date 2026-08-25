import FacetKernel
import Foundation
import XCTest

@testable import BenchGeometry

/// The slab test, against the bare prism and against a solved stone. `AuthoredPatterns` lives in
/// `BenchSolidTests.swift`.
final class BenchPickTests: XCTestCase {

  // MARK: - The bare prism, whose plane indices are fixed (D9)

  func testARayDownTheAxisFromAboveHitsTheCrownCap() {
    let solid = benchSolid(for: nil)
    let hit = pickFacet(solid, origin: SIMD3(0, 0, 5), direction: SIMD3(0, 0, -1))

    XCTAssertEqual(hit?.planeIndex, 0)
    XCTAssertEqual(hit?.facet, FacetOrigin.rough(.crownCap))
    XCTAssertEqual(hit.map { facetLabel($0.facet) }, "C")
  }

  func testARayUpTheAxisFromBelowHitsThePavilionCap() {
    let solid = benchSolid(for: nil)
    let hit = pickFacet(solid, origin: SIMD3(0, 0, -6), direction: SIMD3(0, 0, 1))

    XCTAssertEqual(hit?.planeIndex, 1)
    XCTAssertEqual(hit?.facet, FacetOrigin.rough(.pavilionCap))
    XCTAssertEqual(hit.map { facetLabel($0.facet) }, "P")
  }

  /// `G1`'s normal is +x (D7), so a ray coming back along it enters through that wall and no other.
  func testARayAlongMinusXFromFarOutHitsTheFirstWall() {
    let solid = benchSolid(for: nil)
    let hit = pickFacet(solid, origin: SIMD3(5, 0, 0), direction: SIMD3(-1, 0, 0))

    XCTAssertEqual(hit?.facet, FacetOrigin.rough(.wall(0)))
    XCTAssertEqual(hit.map { facetLabel($0.facet) }, "G1")
  }

  // MARK: - The misses

  /// Descending far too slowly to reach the prism before it is well past it: the last entry crossing
  /// comes after the first exit crossing.
  func testARayAimedPastTheSolidMisses() {
    let solid = benchSolid(for: nil)
    XCTAssertNil(pickFacet(solid, origin: SIMD3(0, 0, 5), direction: SIMD3(1, 0, -0.1)))
  }

  func testARayParallelToAWallAndOutsideItMisses() {
    let solid = benchSolid(for: nil)
    // Along `G1`'s plane and 5 out along its normal, so the ray is outside that slab for its whole
    // length however far it runs.
    XCTAssertNil(pickFacet(solid, origin: SIMD3(5, 0, 0), direction: SIMD3(0, 1, 0)))
  }

  // MARK: - The solved stone

  func testARayDownTheAxisNamesTheStonesTableTier() throws {
    let solid = benchSolid(for: try AuthoredPatterns.load(AuthoredPatterns.roundBrilliant))
    let hit = try XCTUnwrap(pickFacet(solid, origin: SIMD3(0, 0, 5), direction: SIMD3(0, 0, -1)))

    guard case .cut(let facet) = hit.facet else { return XCTFail("the table is not a cut facet") }
    XCTAssertEqual(facet.tier, "t")
    XCTAssertEqual(facet.index, 0)
    XCTAssertEqual(facetLabel(hit.facet), "t · 0")
  }

  /// Which pavilion tier reaches the culet is the pattern's business, not the pick's. What the pick
  /// must get right is that a ray arriving from below names a facet on the pavilion side.
  func testARayUpTheAxisNamesAPavilionFacetOfTheStone() throws {
    let solid = benchSolid(for: try AuthoredPatterns.load(AuthoredPatterns.roundBrilliant))
    let hit = try XCTUnwrap(pickFacet(solid, origin: SIMD3(0, 0, -6), direction: SIMD3(0, 0, 1)))

    guard case .cut(let facet) = hit.facet else { return XCTFail("the culet is not a cut facet") }
    XCTAssertLessThan(solid.planes[hit.planeIndex].n.z, 0)
    XCTAssertEqual(facetLabel(hit.facet), "\(facet.tier) · \(facet.index)")
  }

  // MARK: - The invariant: a pick can only name what was drawn

  func testEveryHitNamesAPlaneThatIsActuallyAFacet() throws {
    let prism = benchSolid(for: nil)
    let stone = benchSolid(for: try AuthoredPatterns.load(AuthoredPatterns.roundBrilliant))

    for azimuth in stride(from: 0.0, to: 360.0, by: 30.0) {
      for elevation in [-80.0, -40.0, 0.0, 40.0, 80.0] {
        let az = Float(azimuth * .pi / 180)
        let el = Float(elevation * .pi / 180)
        let unit = SIMD3<Float>(cos(el) * cos(az), cos(el) * sin(az), sin(el))
        let eye = unit * 6
        let context = "azimuth \(azimuth), elevation \(elevation)"

        // Every one of these is aimed at the origin, which is inside the prism, so every one hits.
        let prismHit = try XCTUnwrap(pickFacet(prism, origin: eye, direction: -unit), context)
        XCTAssertNotNil(prism.polytope.facets[prismHit.planeIndex], context)
        XCTAssertNotNil(prism.origin[prismHit.planeIndex], context)

        if let stoneHit = pickFacet(stone, origin: eye, direction: -unit) {
          XCTAssertNotNil(stone.polytope.facets[stoneHit.planeIndex], context)
          XCTAssertNotNil(stone.origin[stoneHit.planeIndex], context)
        }
      }
    }
  }

  // MARK: - The point a hit reports

  /// The point comes back snapped onto the plane the hit names, because a ray trace tests whether its
  /// entry point is on a face to within `1e-7` and the unprojection that feeds a click is `Float`.
  func testEveryHitsPointLiesOnThePlaneItNames() throws {
    let prism = benchSolid(for: nil)
    let stone = benchSolid(for: try AuthoredPatterns.load(AuthoredPatterns.roundBrilliant))

    for azimuth in stride(from: 0.0, to: 360.0, by: 30.0) {
      for elevation in [-80.0, -40.0, 0.0, 40.0, 80.0] {
        let az = Float(azimuth * .pi / 180)
        let el = Float(elevation * .pi / 180)
        let unit = SIMD3<Float>(cos(el) * cos(az), cos(el) * sin(az), sin(el))
        let eye = unit * 6
        let context = "azimuth \(azimuth), elevation \(elevation)"

        let prismHit = try XCTUnwrap(pickFacet(prism, origin: eye, direction: -unit), context)
        XCTAssertEqual(
          offPlane(prismHit.point, prism.planes[prismHit.planeIndex]), 0, accuracy: 1e-12, context)

        if let stoneHit = pickFacet(stone, origin: eye, direction: -unit) {
          XCTAssertEqual(
            offPlane(stoneHit.point, stone.planes[stoneHit.planeIndex]), 0, accuracy: 1e-12,
            context)
        }
      }
    }
  }

  /// The table's own normal is `(0, 0, 1)`, so a ray down the axis meets it at exactly `(0, 0, d)`. That
  /// is the one case with a closed-form answer, and it is what shows the snap has not slid the point
  /// along the ray.
  func testARayDownTheAxisReportsTheExactPointOnTheTable() throws {
    let solid = benchSolid(for: try AuthoredPatterns.load(AuthoredPatterns.roundBrilliant))
    let hit = try XCTUnwrap(pickFacet(solid, origin: SIMD3(0, 0, 5), direction: SIMD3(0, 0, -1)))
    let plane = solid.planes[hit.planeIndex]

    XCTAssertEqual(plane.n.x, 0, accuracy: 1e-12)
    XCTAssertEqual(plane.n.y, 0, accuracy: 1e-12)
    XCTAssertEqual(plane.n.z, 1, accuracy: 1e-12)
    XCTAssertEqual(hit.point.x, 0, accuracy: 1e-12)
    XCTAssertEqual(hit.point.y, 0, accuracy: 1e-12)
    XCTAssertEqual(hit.point.z, plane.d, accuracy: 1e-12)
  }

  // MARK: - The labels

  func testTheLabelsAreTheRoughsNamesAndTheTierTablesTwoColumns() {
    XCTAssertEqual(facetLabel(.rough(.crownCap)), "C")
    XCTAssertEqual(facetLabel(.rough(.pavilionCap)), "P")
    XCTAssertEqual(facetLabel(.rough(.wall(0))), "G1")
    XCTAssertEqual(facetLabel(.rough(.wall(15))), "G16")
    XCTAssertEqual(facetLabel(.cut(FacetRef(tier: "P1", index: 3))), "P1 · 3")
  }
}

/// How far a point sits off a plane. The pick's own `dot` is private to its file, so this test declares
/// its own rather than being given access to it.
private func offPlane(_ point: (x: Double, y: Double, z: Double), _ plane: Plane) -> Double {
  abs(plane.n.x * point.x + plane.n.y * point.y + plane.n.z * point.z - plane.d)
}
