import FacetKernel
import Foundation
import XCTest
import simd

@testable import BenchGeometry

/// What one click resolved to: the edge inside the grab radius, or the facet under the pointer.
/// `AuthoredPatterns` lives in `BenchSolidTests.swift`.
final class MeetPickHitTests: XCTestCase {
  private let size = (width: 900.0, height: 600.0)
  private let camera = BenchCameraState.threeQuarter

  private var aspect: Float { Float(size.width / size.height) }
  private var eye: SIMD3<Float> { benchCameraPosition(camera, aspect: aspect) }

  // MARK: - The facet branch is `pickFacet`

  func testAClickOnAFacetsCentreTakesThatFacet() throws {
    let solid = benchSolid(for: nil)
    // The crown cap: +z outward, so it faces a camera at +25° elevation, and its centre is far from
    // every one of its own edges.
    let cap = 0
    let centre = try XCTUnwrap(facetCentroid(solid, plane: cap))
    let click = try XCTUnwrap(viewPoint(centre))

    XCTAssertEqual(
      meetPickHit(solid, click: click, size: size, camera: camera), .facet(plane: cap))

    // The same index the slab test returns for the same ray, which is the whole of the facet branch.
    let ray = benchRay(
      ndcX: Float(2 * click.x / size.width - 1),
      ndcY: Float(2 * click.y / size.height - 1),
      aspect: aspect,
      camera: camera)
    XCTAssertEqual(pickFacet(solid, origin: ray.origin, direction: ray.direction)?.planeIndex, cap)
  }

  // MARK: - The grab radius, from both sides of it

  func testAClickOnASilhouetteEdgesMidpointTakesTheEdge() throws {
    let solid = benchSolid(for: nil)
    let target = try wellSeparatedSilhouetteEdge(solid)

    XCTAssertEqual(
      meetPickHit(solid, click: target.midpoint, size: size, camera: camera),
      .edge(planes: target.edge.planes, corners: [target.edge.a, target.edge.b]))
  }

  func testTwentyPointsOffTheEdgeTakesTheFacetAndFourPointsStillTakesTheEdge() throws {
    let solid = benchSolid(for: nil)
    let target = try wellSeparatedSilhouetteEdge(solid)

    let far = offset(target.midpoint, target.inward, 20)
    switch meetPickHit(solid, click: far, size: size, camera: camera) {
    case .facet: break
    case let other: XCTFail("20 points off the edge resolved as \(String(describing: other))")
    }

    XCTAssertEqual(
      meetPickHit(
        solid,
        click: offset(target.midpoint, target.inward, 4),
        size: size,
        camera: camera),
      .edge(planes: target.edge.planes, corners: [target.edge.a, target.edge.b]))
  }

  // MARK: - A facet thinner than the grab radius still takes its own clicks

  /// **The case that made `Easy Octagon` unauthorable.** A girdle 3.4% of the width is about 8 points tall
  /// on screen at the default camera, so the 8-point grab reaches in from the band's top *and* bottom
  /// edges and no click could ever land on the girdle facet itself — which both `P2` and `C2` name.
  func testEveryGirdleFacetOfEasyOctagonTakesAClickAtItsOwnCentre() throws {
    let pattern = try AuthoredPatterns.load(AuthoredPatterns.easyOctagon)
    let solid = benchSolid(for: pattern)

    var tested = 0
    for plane in solid.cutFacetIndices {
      guard case .cut(let ref) = solid.origin[plane], ref.tier == "G1" else { continue }
      let centre = try XCTUnwrap(facetCentroid(solid, plane: plane))
      guard facesCamera(solid, plane: plane), let click = viewPoint(centre) else { continue }

      XCTAssertEqual(
        meetPickHit(solid, click: click, size: size, camera: camera),
        .facet(plane: plane),
        "the girdle facet \(ref.tier)@\(ref.index) did not take a click at its own centre")
      tested += 1
    }
    XCTAssertGreaterThan(tested, 0, "no girdle facet of Easy Octagon faces the default camera")
  }

  /// The other half of the same rule: two edges that share a corner are the ordinary situation at the end
  /// of any edge, and the nearer of them still takes the click — which is what a deliberate grab near an
  /// edge's own end depends on.
  func testAGrabNearAnEdgesEndStillTakesThatEdge() throws {
    let solid = benchSolid(for: nil)
    let target = try wellSeparatedSilhouetteEdge(solid)
    let a = try XCTUnwrap(viewPoint(world(solid, target.edge.a)))
    let b = try XCTUnwrap(viewPoint(world(solid, target.edge.b)))

    // A tenth of the way along, which is inside the end zone part 5 will measure from.
    let near = (x: a.x + (b.x - a.x) / 10, y: a.y + (b.y - a.y) / 10)
    XCTAssertEqual(
      meetPickHit(solid, click: near, size: size, camera: camera),
      .edge(planes: target.edge.planes, corners: [target.edge.a, target.edge.b]))
  }

  // MARK: - Only a visible edge can take a click

  func testAnEdgeRoundTheBackIsNeverReturnedEvenWhenClickedExactlyOnIt() throws {
    let solid = benchSolid(for: nil)
    let hidden = try XCTUnwrap(
      solidEdges(solid).first { edge in
        edge.planes.allSatisfy { !facesCamera(solid, plane: $0) }
      })
    XCTAssertFalse(isVisible(hidden, in: solid, eye: eye))

    let click = try XCTUnwrap(midpoint(solid, hidden))
    if case .edge(let planes, _) = meetPickHit(solid, click: click, size: size, camera: camera) {
      XCTAssertNotEqual(planes, hidden.planes)
    }
  }

  func testASilhouetteEdgeIsVisible() throws {
    let solid = benchSolid(for: nil)
    let silhouette = try wellSeparatedSilhouetteEdge(solid)
    XCTAssertTrue(isVisible(silhouette.edge, in: solid, eye: eye))
  }

  // MARK: - A click on nothing

  func testAClickOutsideTheSilhouetteIsNothing() {
    let solid = benchSolid(for: nil)
    XCTAssertNil(meetPickHit(solid, click: (x: 4, y: 4), size: size, camera: camera))
    XCTAssertNil(
      meetPickHit(
        solid, click: (x: size.width - 4, y: size.height - 4), size: size, camera: camera))
  }

  // MARK: - Centroids

  func testEveryCentroidOfTheBarePrismLiesOnItsOwnPlane() throws {
    let solid = benchSolid(for: nil)
    for plane in solid.polytope.facets.keys.sorted() {
      let centre = try XCTUnwrap(facetCentroid(solid, plane: plane))
      let p = solid.planes[plane]
      let signed =
        p.n.x * Double(centre.x) + p.n.y * Double(centre.y) + p.n.z * Double(centre.z) - p.d
      XCTAssertEqual(signed, 0, accuracy: 1e-6, "centroid of plane \(plane) is off its plane")
    }
  }

  func testACentroidOfAPlaneWithNoRingIsNothing() {
    let solid = benchSolid(for: nil)
    XCTAssertNil(facetCentroid(solid, plane: solid.planes.count + 5))
  }

  // MARK: - Helpers

  /// A facet the eye is outside the half-space of.
  private func facesCamera(_ solid: BenchSolid, plane: Int) -> Bool {
    let p = solid.planes[plane]
    let e = eye
    return p.n.x * Double(e.x) + p.n.y * Double(e.y) + p.n.z * Double(e.z) > p.d
  }

  /// One world point in view points, y up — the convention `meetPickHit` takes.
  private func viewPoint(_ world: SIMD3<Float>) -> (x: Double, y: Double)? {
    guard let fraction = benchScreenPoint(world, aspect: aspect, camera: camera) else { return nil }
    return (x: fraction.x * size.width, y: (1 - fraction.y) * size.height)
  }

  private func world(_ solid: BenchSolid, _ index: Int) -> SIMD3<Float> {
    let corner = solid.polytope.vertices[index]
    return SIMD3<Float>(Float(corner.x), Float(corner.y), Float(corner.z))
  }

  private func midpoint(_ solid: BenchSolid, _ edge: SolidEdge) -> (x: Double, y: Double)? {
    guard let a = viewPoint(world(solid, edge.a)), let b = viewPoint(world(solid, edge.b)) else {
      return nil
    }
    return (x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
  }

  private func offset(
    _ point: (x: Double, y: Double), _ direction: (x: Double, y: Double), _ points: Double
  ) -> (x: Double, y: Double) {
    (x: point.x + direction.x * points, y: point.y + direction.y * points)
  }

  /// A silhouette edge — one facet facing the camera, one facing away — whose projected midpoint is
  /// clear of every other visible edge, together with the perpendicular that leads *into* the
  /// silhouette. Chosen by measurement rather than named, so the case makes no claim about which edge
  /// of the prism happens to be on the outline at this camera.
  private func wellSeparatedSilhouetteEdge(
    _ solid: BenchSolid
  ) throws -> (edge: SolidEdge, midpoint: (x: Double, y: Double), inward: (x: Double, y: Double)) {
    let edges = solidEdges(solid)
    let visible = edges.filter { isVisible($0, in: solid, eye: eye) }

    // The solid's own projected centre, which is what "inward" is measured towards.
    var sum = (x: 0.0, y: 0.0)
    var count = 0.0
    for index in solid.polytope.vertices.indices {
      guard let projected = viewPoint(world(solid, index)) else { continue }
      sum = (x: sum.x + projected.x, y: sum.y + projected.y)
      count += 1
    }
    let centre = (x: sum.x / count, y: sum.y / count)

    for edge in visible {
      guard
        edge.planes.contains(where: { facesCamera(solid, plane: $0) }),
        edge.planes.contains(where: { !facesCamera(solid, plane: $0) }),
        let mid = midpoint(solid, edge),
        let a = viewPoint(world(solid, edge.a)),
        let b = viewPoint(world(solid, edge.b))
      else { continue }

      let length = ((b.x - a.x) * (b.x - a.x) + (b.y - a.y) * (b.y - a.y)).squareRoot()
      guard length > 1 else { continue }
      var inward = (x: -(b.y - a.y) / length, y: (b.x - a.x) / length)
      if inward.x * (centre.x - mid.x) + inward.y * (centre.y - mid.y) < 0 {
        inward = (x: -inward.x, y: -inward.y)
      }

      // Clear of every other visible edge, both at the midpoint and 20 points inside it, so the two
      // radius cases measure the radius rather than a neighbouring edge.
      let others = visible.filter { $0 != edge }
      let clearance = { (point: (x: Double, y: Double)) -> Double in
        others.compactMap { other -> Double? in
          guard let p = self.viewPoint(self.world(solid, other.a)),
            let q = self.viewPoint(self.world(solid, other.b))
          else { return nil }
          return segmentDistance(point, p, q)
        }
        .min() ?? .greatestFiniteMagnitude
      }
      guard clearance(mid) > 25, clearance(offset(mid, inward, 20)) > 10 else { continue }
      return (edge, mid, inward)
    }

    throw NoWellSeparatedSilhouetteEdge()
  }
}

/// A prism with no clickable outline edge would be a defect, not a case to skip.
private struct NoWellSeparatedSilhouetteEdge: Error {}

/// The test's own distance-to-segment, so the clearance measurement does not read the one under test.
private func segmentDistance(
  _ point: (x: Double, y: Double),
  _ from: (x: Double, y: Double),
  _ to: (x: Double, y: Double)
) -> Double {
  let dx = to.x - from.x
  let dy = to.y - from.y
  let lengthSquared = dx * dx + dy * dy
  var t = 0.0
  if lengthSquared > 0 {
    t = min(1, max(0, ((point.x - from.x) * dx + (point.y - from.y) * dy) / lengthSquared))
  }
  let nx = from.x + t * dx - point.x
  let ny = from.y + t * dy - point.y
  return (nx * nx + ny * ny).squareRoot()
}
