import Foundation

/// One straight run of the ray inside the stone: where it started, the surface it reached, and how
/// steeply it arrived there.
public struct RaySegment: Sendable {
  public var from: (x: Double, y: Double, z: Double)
  public var to: (x: Double, y: Double, z: Double)
  /// The plane this segment ends on, as an index into the planes the trace was given.
  public var plane: Int
  /// The angle between the ray and that plane's normal at `to`, in degrees.
  public var incidenceDegrees: Double

  public init(
    from: (x: Double, y: Double, z: Double),
    to: (x: Double, y: Double, z: Double),
    plane: Int,
    incidenceDegrees: Double
  ) {
    self.from = from
    self.to = to
    self.plane = plane
    self.incidenceDegrees = incidenceDegrees
  }
}

/// How a traced path finished.
public enum RayEnding: String, Sendable {
  /// Fell below the critical angle and left the stone.
  case left
  /// Still bouncing when the cap was reached. The path is truncated, not finished.
  case cappedAtBounceLimit
  /// The entry point is not on the solid, or the direction points away from it.
  case noEntry
}

/// One ray's path through a stone: where it entered, every surface it touched, and how it ended.
public struct RayTrace: Sendable {
  public var criticalAngleDegrees: Double
  /// The plane the ray entered through, as an index into the planes the trace was given.
  public var entryPlane: Int?
  /// The angle between the incoming ray and the entry plane's normal, in degrees, before refraction.
  public var entryIncidenceDegrees: Double?
  public var segments: [RaySegment]
  public var ending: RayEnding
  /// Where the ray went after leaving, or `nil` unless `ending == .left`.
  public var exitDirection: (x: Double, y: Double, z: Double)?

  public init(
    criticalAngleDegrees: Double,
    entryPlane: Int? = nil,
    entryIncidenceDegrees: Double? = nil,
    segments: [RaySegment] = [],
    ending: RayEnding,
    exitDirection: (x: Double, y: Double, z: Double)? = nil
  ) {
    self.criticalAngleDegrees = criticalAngleDegrees
    self.entryPlane = entryPlane
    self.entryIncidenceDegrees = entryIncidenceDegrees
    self.segments = segments
    self.ending = ending
    self.exitDirection = exitDirection
  }
}

/// The angle beyond which light inside a material of this refractive index cannot get out: `asin(1 / ri)`
/// in degrees.
///
/// `90` for `ri <= 1`, because nothing is trapped in a medium no denser than air — there is no angle past
/// which a ray reflects rather than leaving.
public func criticalAngleDegrees(ri: Double) -> Double {
  guard ri > 1 else { return 90 }
  return asin(1 / ri) * 180 / Double.pi
}

/// Traces one ray from a point on the stone's surface: refracts it in, reflects it while it stays above
/// the critical angle, and lets it out where it does not.
///
/// This is the probe behind "why is this stone dark here". A pavilion cut too shallow leaks — the ray
/// meets the pavilion below the critical angle and passes straight out of the back — and one traced path
/// says so where a whole-stone brightness figure would only say the stone is worse.
///
/// Takes `[Plane]` rather than a `Polytope` because the nearest-forward-hit rule needs plane equations
/// and a polytope carries polygons and vertices instead. Pass `solution.planes`.
///
/// One ray, one wavelength, one path: no Fresnel splitting, which doubles the rays at every bounce and
/// draws an unreadable picture, and no dispersion, because a pattern carries one `ri`.
///
/// `direction` need not be unit; it is normalised here. `bounceLimit` counts reflections, not segments.
public func traceRay(
  in planes: [Plane],
  ri: Double,
  from entry: (x: Double, y: Double, z: Double),
  direction: (x: Double, y: Double, z: Double),
  bounceLimit: Int = 32
) -> RayTrace {
  let critical = criticalAngleDegrees(ri: ri)
  let incoming = normalized(direction)

  // 1. Entry. The ray has to start on a face of the solid, heading into it.
  let candidates = planes.indices.filter {
    abs(dot(planes[$0].n, entry) - planes[$0].d) <= onSurfaceTolerance
      && dot(planes[$0].n, incoming) < 0
  }
  guard let entryPlane = candidates.first else {
    return RayTrace(criticalAngleDegrees: critical, ending: .noEntry)
  }

  let entryNormal = planes[entryPlane].n
  let entryCosine = -dot(incoming, entryNormal)
  let entryIncidence = degrees(acos: entryCosine)

  // 2. Refract inward. At normal incidence this is exactly `-n`, and the result is unit for any `ri >= 1`.
  var direction = refracted(incoming, into: entryNormal, cosine: entryCosine, ri: ri)
  var point = entry

  var segments: [RaySegment] = []
  var bounces = 0

  while true {
    // 3. The next surface. Valid in one pass because the solid is convex by construction, being an
    // intersection of half-spaces — so a bounce costs O(planes) and the whole probe is trivial beside a
    // solve.
    guard let hit = nextSurface(from: point, along: direction, in: planes) else {
      // A ray that reaches no surface has escaped the half-spaces, which a convex solid does not allow.
      return RayTrace(
        criticalAngleDegrees: critical,
        entryPlane: entryPlane,
        entryIncidenceDegrees: entryIncidence,
        segments: segments,
        ending: .noEntry
      )
    }

    // 4. Reflect or leave.
    let normal = planes[hit.plane].n
    let cosine = dot(direction, normal)
    let incidence = degrees(acos: cosine)
    segments.append(
      RaySegment(from: point, to: hit.point, plane: hit.plane, incidenceDegrees: incidence))
    point = hit.point

    if incidence <= critical {
      return RayTrace(
        criticalAngleDegrees: critical,
        entryPlane: entryPlane,
        entryIncidenceDegrees: entryIncidence,
        segments: segments,
        ending: .left,
        exitDirection: exiting(direction, through: normal, cosine: cosine, ri: ri)
      )
    }

    direction = reflected(direction, off: normal, cosine: cosine)
    bounces += 1

    // 5. The cap. The path is truncated rather than finished, which the case name has to say.
    if bounces >= bounceLimit {
      return RayTrace(
        criticalAngleDegrees: critical,
        entryPlane: entryPlane,
        entryIncidenceDegrees: entryIncidence,
        segments: segments,
        ending: .cappedAtBounceLimit
      )
    }
  }
}

// MARK: - The steps

/// The nearest plane ahead of `point` along `direction`, and where the ray meets it.
private func nextSurface(
  from point: (x: Double, y: Double, z: Double),
  along direction: (x: Double, y: Double, z: Double),
  in planes: [Plane]
) -> (plane: Int, point: (x: Double, y: Double, z: Double))? {
  var nearest: (plane: Int, distance: Double)?
  for index in planes.indices {
    let approach = dot(planes[index].n, direction)
    guard approach > towardTolerance else { continue }
    let travel = (planes[index].d - dot(planes[index].n, point)) / approach
    guard travel > forwardTolerance else { continue }
    if nearest == nil || travel < nearest!.distance {
      nearest = (plane: index, distance: travel)
    }
  }

  guard let nearest else { return nil }
  return (
    plane: nearest.plane,
    point: (
      x: point.x + direction.x * nearest.distance,
      y: point.y + direction.y * nearest.distance,
      z: point.z + direction.z * nearest.distance
    )
  )
}

/// Snell's law on the way in, with `cosine` the cosine of the incidence angle and `n` the outward normal:
/// `(d + c n) / ri - n sqrt(1 - (1 - c²) / ri²)`.
private func refracted(
  _ direction: (x: Double, y: Double, z: Double),
  into normal: (x: Double, y: Double, z: Double),
  cosine: Double,
  ri: Double
) -> (x: Double, y: Double, z: Double) {
  let tangential = (
    x: direction.x + cosine * normal.x,
    y: direction.y + cosine * normal.y,
    z: direction.z + cosine * normal.z
  )
  let along = (1 - (1 - cosine * cosine) / (ri * ri)).clampedToNonNegative.squareRoot()
  return (
    x: tangential.x / ri - normal.x * along,
    y: tangential.y / ri - normal.y * along,
    z: tangential.z / ri - normal.z * along
  )
}

/// Snell's law on the way out, with `cosine` the cosine of the incidence angle inside the stone:
/// `ri (d - c n) + n sqrt(1 - ri² (1 - c²))`. Only reached at or below the critical angle, where that
/// square root is real.
private func exiting(
  _ direction: (x: Double, y: Double, z: Double),
  through normal: (x: Double, y: Double, z: Double),
  cosine: Double,
  ri: Double
) -> (x: Double, y: Double, z: Double) {
  let tangential = (
    x: direction.x - cosine * normal.x,
    y: direction.y - cosine * normal.y,
    z: direction.z - cosine * normal.z
  )
  let along = (1 - ri * ri * (1 - cosine * cosine)).clampedToNonNegative.squareRoot()
  return (
    x: ri * tangential.x + normal.x * along,
    y: ri * tangential.y + normal.y * along,
    z: ri * tangential.z + normal.z * along
  )
}

/// A mirror bounce off the inside of a facet: `d - 2 c n`.
private func reflected(
  _ direction: (x: Double, y: Double, z: Double),
  off normal: (x: Double, y: Double, z: Double),
  cosine: Double
) -> (x: Double, y: Double, z: Double) {
  (
    x: direction.x - 2 * cosine * normal.x,
    y: direction.y - 2 * cosine * normal.y,
    z: direction.z - 2 * cosine * normal.z
  )
}

/// `acos` in degrees, with the argument clamped: a dot product of two unit vectors can land a hair outside
/// `-1...1`, where `acos` is not a number.
private func degrees(acos cosine: Double) -> Double {
  Foundation.acos(Swift.min(1, Swift.max(-1, cosine))) * 180 / Double.pi
}

extension Double {
  /// Rounding can put a square root's argument a hair below zero at exactly the critical angle.
  fileprivate var clampedToNonNegative: Double { self < 0 ? 0 : self }
}

/// A point this close to a plane is on it.
private let onSurfaceTolerance = 1e-7
/// A plane the ray is heading towards steeply enough to be worth intersecting. Below this the ray runs
/// parallel to it.
private let towardTolerance = 1e-12
/// How far ahead a surface has to be to count as ahead, so the facet just left is not hit again.
private let forwardTolerance = 1e-9
