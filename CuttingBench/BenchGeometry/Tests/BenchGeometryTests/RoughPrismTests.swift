import FacetKernel
import Foundation
import XCTest

@testable import BenchGeometry

final class RoughPrismTests: XCTestCase {
  private let tol = 1e-12

  // MARK: - The fixed order, and the names

  func testTheRoughIsEighteenNamedPlanes() {
    XCTAssertEqual(roughPlanes().count, 18)
    XCTAssertEqual(roughFacets().count, 18)
  }

  func testTheOrderIsCapsThenWallsFromStopZero() {
    let facets = roughFacets()
    XCTAssertEqual(facets[0], .crownCap)
    XCTAssertEqual(facets[1], .pavilionCap)
    XCTAssertEqual(facets[2], .wall(0))
    XCTAssertEqual(facets[17], .wall(15))
  }

  func testWallNamesAreOneBasedWhileStopsAreZeroBased() {
    XCTAssertEqual(RoughFacet.crownCap.name, "C")
    XCTAssertEqual(RoughFacet.pavilionCap.name, "P")
    XCTAssertEqual(RoughFacet.wall(0).name, "G1")
    XCTAssertEqual(RoughFacet.wall(15).name, "G16")
  }

  // MARK: - The planes themselves

  func testTheCapsAreTheDeclaredConstants() {
    let planes = roughPlanes()

    XCTAssertEqual(planes[0].n.x, 0)
    XCTAssertEqual(planes[0].n.y, 0)
    XCTAssertEqual(planes[0].n.z, 1)
    XCTAssertEqual(planes[0].d, 1.0)

    XCTAssertEqual(planes[1].n.x, 0)
    XCTAssertEqual(planes[1].n.y, 0)
    XCTAssertEqual(planes[1].n.z, -1)
    XCTAssertEqual(planes[1].d, 2.0)
  }

  func testWallOneLiesOnPlusXAndWallFiveOnPlusY() {
    let planes = roughPlanes()

    XCTAssertEqual(planes[2].n.x, 1, accuracy: tol)
    XCTAssertEqual(planes[2].n.y, 0, accuracy: tol)
    XCTAssertEqual(planes[2].d, 1.5)

    XCTAssertEqual(planes[6].n.x, 0, accuracy: tol)
    XCTAssertEqual(planes[6].n.y, 1, accuracy: tol)
  }

  /// The check D10 exists for: no tolerance. `planeNormal(angleDegrees: 90, …)` would fail this.
  func testEveryWallNormalIsExactlyVertical() {
    for (index, plane) in roughPlanes().enumerated().dropFirst(2) {
      XCTAssertEqual(plane.n.z, 0, "wall at plane index \(index)")
      XCTAssertEqual(plane.d, Rough.radius, "wall at plane index \(index)")
    }
  }

  // MARK: - The solid the eighteen make

  func testTheEighteenIntersectToASixteenGonPrism() {
    let prism = intersectHalfSpaces(roughPlanes())
    XCTAssertEqual(prism.vertices.count, 32)
    XCTAssertEqual(prism.facets.count, 18)
  }
}
