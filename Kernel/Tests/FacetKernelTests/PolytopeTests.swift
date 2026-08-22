import Foundation
import XCTest

@testable import FacetKernel

final class PolytopeTests: XCTestCase {
  private let tol = 1e-9

  // MARK: - Plane lists, hand-built. No pattern file is read in this suite.

  /// A unit cube centred on the origin. Editing one `0.5` here is the negative check in T4's
  /// verification handle: the vertex count must stay at 8 while four of them move.
  private func unitCubePlanes() -> [Plane] {
    [
      Plane(n: (x: 1, y: 0, z: 0), d: 0.5),
      Plane(n: (x: -1, y: 0, z: 0), d: 0.5),
      Plane(n: (x: 0, y: 1, z: 0), d: 0.5),
      Plane(n: (x: 0, y: -1, z: 0), d: 0.5),
      Plane(n: (x: 0, y: 0, z: 1), d: 0.5),
      Plane(n: (x: 0, y: 0, z: -1), d: 0.5),
    ]
  }

  /// Plane 0 is a table at z = 0; planes 1 to 4 are pavilion facets at 45 degrees. Together a square
  /// pyramid with base corners at (±1, ±1, 0) and its apex at the culet, (0, 0, -1).
  private func squarePyramidPlanes() -> [Plane] {
    var planes = [Plane(n: planeNormal(angleDegrees: 0, index: 0, wheel: 96, part: .table), d: 0)]
    let offset = sin(45 * Double.pi / 180)
    for index in [0, 24, 48, 72] {
      let n = planeNormal(angleDegrees: 45, index: index, wheel: 96, part: .pav)
      planes.append(Plane(n: n, d: offset))
    }
    return planes
  }

  // MARK: - triplePoint

  func testThreeVerticalGirdlePlanesPinNothing() {
    let planes = [0, 12, 24].map { index in
      Plane(n: planeNormal(angleDegrees: 90, index: index, wheel: 96, part: .gdl), d: 1)
    }
    XCTAssertNil(triplePoint(planes[0], planes[1], planes[2]))

    // The determinant really is vanishing, rather than the triple being rejected for some other
    // reason: all three normals are vertical, so they span a plane and not a volume.
    let determinant = dot(planes[0].n, cross(planes[1].n, planes[2].n))
    XCTAssertLessThan(abs(determinant), 1e-15)
  }

  func testWellConditionedTripleReturnsItsPoint() throws {
    let point = try XCTUnwrap(
      triplePoint(
        Plane(n: (x: 1, y: 0, z: 0), d: 2),
        Plane(n: (x: 0, y: 1, z: 0), d: 3),
        Plane(n: (x: 0, y: 0, z: 1), d: 4)
      )
    )
    XCTAssertEqual(point.x, 2, accuracy: tol)
    XCTAssertEqual(point.y, 3, accuracy: tol)
    XCTAssertEqual(point.z, 4, accuracy: tol)
  }

  func testTiltedTripleAgreesWithTheSymmetryAxisSolve() throws {
    // Three pavilion facets at one angle, 120 degrees apart on a 96 wheel. Their meet must sit on
    // the axis by symmetry, which fixes z without going through Cramer's rule at all.
    let offset = 0.7
    let planes = [0, 32, 64].map { index in
      Plane(n: planeNormal(angleDegrees: 43, index: index, wheel: 96, part: .pav), d: offset)
    }
    let point = try XCTUnwrap(triplePoint(planes[0], planes[1], planes[2]))

    let expectedZ = offset / planeNormal(angleDegrees: 43, index: 0, wheel: 96, part: .pav).z
    XCTAssertEqual(point.x, 0, accuracy: 1e-12)
    XCTAssertEqual(point.y, 0, accuracy: 1e-12)
    XCTAssertEqual(point.z, expectedZ, accuracy: 1e-12)
    XCTAssertLessThan(point.z, 0, "a pavilion meet lies below the girdle plane")
  }

  // MARK: - intersectHalfSpaces

  func testUnitCubeHasEightVerticesAndSixQuadFacets() {
    let solid = intersectHalfSpaces(unitCubePlanes())
    XCTAssertEqual(solid.vertices.count, 8)
    XCTAssertEqual(solid.facets.count, 6)
    for (plane, polygon) in solid.facets {
      XCTAssertEqual(polygon.count, 4, "plane \(plane)")
      XCTAssertEqual(Set(polygon).count, 4, "plane \(plane) repeats a vertex")
    }

    let corners = Set(solid.vertices.map(key))
    var expected = Set<String>()
    for x in [-0.5, 0.5] {
      for y in [-0.5, 0.5] {
        for z in [-0.5, 0.5] {
          expected.insert(key((x: x, y: y, z: z)))
        }
      }
    }
    XCTAssertEqual(corners, expected, "the eight corners are every combination of ±0.5")
  }

  func testEveryCubeFacetIsWoundCounterClockwiseAboutItsNormal() {
    let planes = unitCubePlanes()
    let solid = intersectHalfSpaces(planes)
    XCTAssertEqual(solid.facets.count, 6)
    for (index, polygon) in solid.facets {
      let area = signedArea(polygon, about: planes[index].n, vertices: solid.vertices)
      XCTAssertGreaterThan(area, 0, "plane \(index) is wound clockwise about its normal")
      XCTAssertEqual(area, 1, accuracy: tol, "plane \(index) is not a unit square")
    }
  }

  func testSquarePyramidHasFiveVerticesAndAnApexSharedByFourFacets() throws {
    let planes = squarePyramidPlanes()
    let solid = intersectHalfSpaces(planes)
    XCTAssertEqual(solid.vertices.count, 5)

    let apex = try XCTUnwrap(solid.vertices.firstIndex { $0.z < -0.5 })
    XCTAssertEqual(solid.vertices[apex].x, 0, accuracy: tol)
    XCTAssertEqual(solid.vertices[apex].y, 0, accuracy: tol)
    XCTAssertEqual(solid.vertices[apex].z, -1, accuracy: tol)

    let sideFacets = solid.facets.filter { $0.key != 0 }
    XCTAssertEqual(sideFacets.count, 4)
    for (plane, polygon) in sideFacets {
      XCTAssertTrue(polygon.contains(apex), "side plane \(plane) misses the apex")
      XCTAssertEqual(polygon.count, 3, "side plane \(plane) is not a triangle")
    }
    XCTAssertEqual(solid.facets[0]?.count, 4, "the table is a square")
  }

  func testAPlaneThatDoesNotTouchTheSolidIsNotAFacet() {
    var planes = unitCubePlanes()
    planes.append(Plane(n: (x: 1, y: 0, z: 0), d: 5))  // parallel to a face, far outside it
    let solid = intersectHalfSpaces(planes)

    XCTAssertEqual(solid.vertices.count, 8, "a plane that cuts nothing must not add vertices")
    XCTAssertEqual(solid.facets.count, 6)
    XCTAssertNil(solid.facets[6], "the distant plane is in the input but is not a facet")
  }

  // MARK: - Verification handle (T4, permanent)

  /// Prints the cube's vertices and facet polygons.
  ///
  /// T4's negative check: widen one plane's `d` in `unitCubePlanes()` from 0.5 to 0.75 and re-run.
  /// The vertex count stays at 8, four vertices move to that face's new offset, and no facet gains
  /// or loses a vertex — a shape change that leaves the counts identical is exactly what a wrong
  /// winding or a bad tolerance would hide.
  func testCubeDump() {
    let planes = unitCubePlanes()
    let solid = intersectHalfSpaces(planes)

    print("vertices: \(solid.vertices.count)")
    for (index, v) in solid.vertices.enumerated() {
      print(String(format: "  v%-2d %+.6f %+.6f %+.6f", index, v.x, v.y, v.z))
    }
    print("facets: \(solid.facets.count)")
    for index in solid.facets.keys.sorted() {
      let polygon = solid.facets[index] ?? []
      let n = planes[index].n
      let area = signedArea(polygon, about: n, vertices: solid.vertices)
      let normal = String(format: "(%+.1f %+.1f %+.1f)", n.x, n.y, n.z)
      let offset = String(format: "%.4f", planes[index].d)
      let signed = String(format: "%+.6f", area)
      print("  plane \(index)  n=\(normal) d=\(offset)  polygon \(polygon)  signedArea \(signed)")
    }

    XCTAssertEqual(solid.vertices.count, 8)
    XCTAssertEqual(solid.facets.count, 6)
    for polygon in solid.facets.values {
      XCTAssertEqual(polygon.count, 4)
    }
  }

  // MARK: - Helpers

  private func key(_ point: (x: Double, y: Double, z: Double)) -> String {
    String(format: "%+.6f,%+.6f,%+.6f", point.x, point.y, point.z)
  }

  /// The polygon's area, signed positive when it is wound counter-clockwise about `normal`.
  private func signedArea(
    _ polygon: [Int],
    about normal: (x: Double, y: Double, z: Double),
    vertices: [(x: Double, y: Double, z: Double)]
  ) -> Double {
    var total = (x: 0.0, y: 0.0, z: 0.0)
    for step in polygon.indices {
      let a = vertices[polygon[step]]
      let b = vertices[polygon[(step + 1) % polygon.count]]
      let c = cross(a, b)
      total = (x: total.x + c.x, y: total.y + c.y, z: total.z + c.z)
    }
    return dot(total, normal) / 2
  }
}
