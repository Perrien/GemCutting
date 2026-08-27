import FacetKernel
import Foundation
import simd

/// The tuning this part's picking runs on. Build constants with no UI and no preference, tuned by
/// editing the numbers — exactly as the rough's dimensions are.
public enum MeetPickTuning {
  /// How close, in screen points, a click has to fall to a visible edge for the edge to take it
  /// instead of the facet under the pointer.
  public static let edgeGrabRadiusPoints: Double = 8
  /// How much of an edge's own length, at each end, snaps a click to that end's corner instead of
  /// anchoring a point part-way along it. A build constant with no UI and no preference, tuned by
  /// editing the number.
  public static let endZoneFraction: Double = 0.10
  /// How near the picked corner has to be to the side's axial point to be written as `tcp`.
  /// Model-space distance on a solid normalised to a half-width of 1.
  public static let axialTolerance: Double = 1e-6
  /// How near the three named planes' own intersection has to be to the clicked corner.
  public static let triplePointTolerance: Double = 1e-6
}

/// What a click in the viewport resolved to. `nil` from `meetPickHit` is a click that missed the solid.
public enum MeetPickHit: Equatable, Sendable {
  case facet(plane: Int)
  /// A visible edge within the grab radius: the two facets sharing it, its two corners, and **where
  /// along it the click fell** — the parameter of the closest point on the model-space segment
  /// `corners[0] → corners[1]`, in `0...1`.
  ///
  /// **Model space, not screen space**, because the end zones are a fraction of the edge's own length:
  /// a screen-space parameter would make them grow and shrink with foreshortening.
  case edge(planes: [Int], corners: [Int], along: Double)
}

/// An edge when the click falls within `grabRadiusPoints` of a **visible** one, otherwise the front-most
/// facet, and `nil` for a click that hit neither.
///
/// `click` and `size` are both in view points with **y up** — the coordinates `MTKView` hands
/// `onPick`, which need no flip to reach Metal's NDC. `benchScreenPoint` reports y **down**, so a
/// projected corner is converted back with `(x: sx * width, y: (1 - sy) * height)`; that conversion
/// lives here and nowhere else.
///
/// Edges are considered before facets, and the nearest qualifying edge wins. An edge with either corner
/// behind the camera is skipped — `benchScreenPoint` gives it no screen position, and a segment with one
/// end at infinity has no honest screen distance.
///
/// **An edge loses the click when a second visible edge sharing none of its corners is also within the
/// radius.** That is the exact statement of "the facet under the pointer is thinner than the grab", and
/// without it a thin band is unclickable: a girdle 3.4% of the width is about 8 points tall on screen at
/// the default camera, so the grab reaches in from both of its edges and swallows the facet whole. Two
/// edges that *do* share a corner are the ordinary situation near a corner of any facet, and that still
/// grabs the nearer one — which is what an edge's own ends have to keep answering to.
public func meetPickHit(
  _ solid: BenchSolid,
  click: (x: Double, y: Double),
  size: (width: Double, height: Double),
  camera: BenchCameraState,
  grabRadiusPoints: Double = MeetPickTuning.edgeGrabRadiusPoints
) -> MeetPickHit? {
  guard size.width > 0, size.height > 0 else { return nil }
  let aspect = Float(size.width / size.height)
  let eye = benchCameraPosition(camera, aspect: aspect)
  // Built once: the edge branch measures where along the edge the ray passes closest, and the facet
  // branch casts the same ray at the slabs.
  let ray = benchRay(
    ndcX: Float(2 * click.x / size.width - 1),
    ndcY: Float(2 * click.y / size.height - 1),
    aspect: aspect,
    camera: camera)

  var within: [(distance: Double, edge: SolidEdge)] = []
  for edge in solidEdges(solid) {
    guard isVisible(edge, in: solid, eye: eye) else { continue }
    guard let from = screenPoint(solid.polytope.vertices[edge.a], aspect, camera, size),
      let to = screenPoint(solid.polytope.vertices[edge.b], aspect, camera, size)
    else { continue }
    let distance = distanceToSegment(click, from, to)
    guard distance <= grabRadiusPoints else { continue }
    within.append((distance, edge))
  }

  if let nearest = within.min(by: { $0.distance < $1.distance }) {
    let ambiguous = within.contains { other in
      other.edge != nearest.edge && !shareACorner(other.edge, nearest.edge)
    }
    if !ambiguous {
      return .edge(
        planes: nearest.edge.planes,
        corners: [nearest.edge.a, nearest.edge.b],
        along: alongSegment(
          ray: ray,
          from: solid.polytope.vertices[nearest.edge.a],
          to: solid.polytope.vertices[nearest.edge.b]))
    }
  }

  // The facet branch is `pickFacet` unchanged, so a pick can still never name a facet the renderer did
  // not draw.
  guard let hit = pickFacet(solid, origin: ray.origin, direction: ray.direction) else { return nil }
  return .facet(plane: hit.planeIndex)
}

/// Where along a model-space segment a click ray passes closest, as a parameter in `0...1`.
///
/// The standard closest-point-between-two-lines solve, clamped to the segment. **Clamped and never
/// rejected**: a ray that passes closest beyond an end still answers with that end, which is the same
/// end the click was within the grab radius of.
///
/// A degenerate segment — both corners at one point — and a ray parallel to the segment both fall out
/// as `0`, which names a real corner and so is always safe to return.
private func alongSegment(
  ray: (origin: SIMD3<Float>, direction: SIMD3<Float>),
  from: (x: Double, y: Double, z: Double),
  to: (x: Double, y: Double, z: Double)
) -> Double {
  let a = SIMD3<Double>(from.x, from.y, from.z)
  let b = SIMD3<Double>(to.x, to.y, to.z)
  let segment = b - a
  let origin = SIMD3<Double>(Double(ray.origin.x), Double(ray.origin.y), Double(ray.origin.z))
  let direction = SIMD3<Double>(
    Double(ray.direction.x), Double(ray.direction.y), Double(ray.direction.z))

  let ss = simd_dot(segment, segment)
  let dd = simd_dot(direction, direction)
  let sd = simd_dot(segment, direction)
  let denominator = ss * dd - sd * sd
  guard ss > 0, dd > 0, denominator != 0 else { return 0 }

  let w = a - origin
  let t = (sd * simd_dot(w, direction) - dd * simd_dot(w, segment)) / denominator
  return min(1, max(0, t))
}

/// Whether this edge can be clicked at all: at least one of its facets faces the camera. Exact for the
/// drawn solid, which is an intersection of half-spaces and so convex.
///
/// A facet faces the camera when `dot(plane.n, eye) > plane.d` — the eye is outside that half-space.
public func isVisible(_ edge: SolidEdge, in solid: BenchSolid, eye: SIMD3<Float>) -> Bool {
  edge.planes.contains { index in
    guard solid.planes.indices.contains(index) else { return false }
    let plane = solid.planes[index]
    let e = (x: Double(eye.x), y: Double(eye.y), z: Double(eye.z))
    return plane.n.x * e.x + plane.n.y * e.y + plane.n.z * e.z > plane.d
  }
}

/// A facet's centroid in world space, for placing its marker. `nil` for a plane that is not a facet of
/// this solid — the mean of its ring's corners, so it always lies on the facet.
public func facetCentroid(_ solid: BenchSolid, plane: Int) -> SIMD3<Float>? {
  guard let ring = solid.polytope.facets[plane], !ring.isEmpty else { return nil }
  var sum = SIMD3<Double>.zero
  for vertexIndex in ring {
    let corner = solid.polytope.vertices[vertexIndex]
    sum += SIMD3<Double>(corner.x, corner.y, corner.z)
  }
  let mean = sum / Double(ring.count)
  return SIMD3<Float>(Float(mean.x), Float(mean.y), Float(mean.z))
}

/// Whether two edges meet at a corner. Two that do are neighbours around one facet; two that do not, both
/// within the grab radius of one click, mean the facet between them is thinner than the grab.
private func shareACorner(_ first: SolidEdge, _ second: SolidEdge) -> Bool {
  first.a == second.a || first.a == second.b || first.b == second.a || first.b == second.b
}

/// One corner in view points with **y up**, or `nil` when it is behind the camera.
private func screenPoint(
  _ corner: (x: Double, y: Double, z: Double),
  _ aspect: Float,
  _ camera: BenchCameraState,
  _ size: (width: Double, height: Double)
) -> (x: Double, y: Double)? {
  let world = SIMD3<Float>(Float(corner.x), Float(corner.y), Float(corner.z))
  guard let fraction = benchScreenPoint(world, aspect: aspect, camera: camera) else { return nil }
  return (x: fraction.x * size.width, y: (1 - fraction.y) * size.height)
}

/// The ordinary clamped projection. A degenerate segment — both corners projecting to the same point,
/// which an edge seen exactly end-on does — falls out as the distance to `from`, which is right and
/// needs no special case.
private func distanceToSegment(
  _ point: (x: Double, y: Double),
  _ from: (x: Double, y: Double),
  _ to: (x: Double, y: Double)
) -> Double {
  let dx = to.x - from.x
  let dy = to.y - from.y
  let lengthSquared = dx * dx + dy * dy
  var t = 0.0
  if lengthSquared > 0 {
    t = ((point.x - from.x) * dx + (point.y - from.y) * dy) / lengthSquared
    t = min(1, max(0, t))
  }
  let nx = from.x + t * dx - point.x
  let ny = from.y + t * dy - point.y
  return (nx * nx + ny * ny).squareRoot()
}
