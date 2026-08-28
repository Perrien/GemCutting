import FacetKernel
import Foundation

/// One end of a two-point derivation: what the picker spelled it as, and where it is in model space.
public struct DerivationEnd: Equatable, Sendable {
  public var meet: Meet
  public var point: SIMD3<Double>

  public init(meet: Meet, point: SIMD3<Double>) {
    self.meet = meet
    self.point = point
  }
}

/// What the derivation writes: the angle, and the end that becomes the tier's meet (D20, D23).
public struct DerivedTierAngle: Equatable, Sendable {
  public var angle: Double
  public var meet: Meet

  public init(angle: Double, meet: Meet) {
    self.angle = angle
    self.meet = meet
  }
}

/// What a refused derivation reports: the aimed stop, and both points as the arithmetic saw them.
public struct DerivationNumbers: Equatable, Sendable {
  public var stop: Int
  public var r1: Double
  public var z1: Double
  public var r2: Double
  public var z2: Double

  public init(stop: Int, r1: Double, z1: Double, r2: Double, z2: Double) {
    self.stop = stop
    self.r1 = r1
    self.z1 = z1
    self.r2 = r2
    self.z2 = z2
  }

  var firstText: String { "\(coordinateText(r1)), \(coordinateText(z1))" }
  var secondText: String { "\(coordinateText(r2)), \(coordinateText(z2))" }
}

/// A coordinate as every sentence about a picked point reads it.
func coordinateText(_ value: Double) -> String {
  String(format: "%.6f", value)
}

/// The tolerance two picked points have to differ by to name a tilt, and the one two facets have to
/// differ by for one to be said to arrive first.
///
/// The kernel's own tolerance at this scale: within it, a point sits on the edge between two facets and
/// the depth is the same number either way (D26).
let derivationTolerance = 1e-7

/// A point's distance along a facet's own azimuth: `r = x·cos θ + y·sin θ`, with `θ = 2π · stop / wheel`
/// — the same wheel convention `planeNormal` uses.
public func azimuthRadius(of point: SIMD3<Double>, atStop stop: Int, wheel: Int) -> Double {
  let theta = 2 * Double.pi * Double(stop) / Double(wheel)
  return point.x * cos(theta) + point.y * sin(theta)
}

/// Whether this end is a point that must be hit rather than one that may slide: `vertex` and `tcp` yes,
/// `fraction` no (D23). `size` and `girdle` cannot come out of a pick and answer `false`.
public func isCornerEnd(_ meet: Meet) -> Bool {
  switch meet {
  case .vertex, .tcp: true
  case .fraction, .size, .girdle: false
  }
}

/// Which of the two ends is written as the meet — `0` or `1`.
///
/// **Settled by kind, not by order** (D23): a corner end outranks an end anchored part-way along an
/// edge, because a percentage along an edge is a coordinate rather than a design quantity and a small
/// slide there costs nothing. Where both ends are the same kind the first picked wins, since either is
/// then exact to within the same rounding.
public func anchorEnd(first: DerivationEnd, second: DerivationEnd) -> Int {
  isCornerEnd(first.meet) || !isCornerEnd(second.meet) ? 0 : 1
}

/// The angle the aimed facet must be cut at to arrive at both points, with the meet to write beside it —
/// or which of the three ways it failed (D24).
///
/// The aimed stop and the gear fix the facet's azimuth and the `part` fixes the normal's `z` sign, so the
/// plane has two unknowns and two points give two equations. `wheel` is the tier's **effective** gear and
/// `stops` its own index stops, both as the draft gives them.
public func derivedAngle(
  ofTier tier: String,
  aimedStop: Int,
  wheel: Int,
  part: Part,
  stops: [Int],
  first: DerivationEnd,
  second: DerivationEnd
) -> Result<DerivedTierAngle, DraftRefusal> {
  let r1 = azimuthRadius(of: first.point, atStop: aimedStop, wheel: wheel)
  let r2 = azimuthRadius(of: second.point, atStop: aimedStop, wheel: wheel)
  let z1 = first.point.z
  let z2 = second.point.z
  let numbers = DerivationNumbers(stop: aimedStop, r1: r1, z1: z1, r2: r2, z2: z2)
  let sign: Double = isUpward(part) ? 1 : -1

  // Two points at one place on the azimuth: there is no line to fit.
  guard abs(r1 - r2) > derivationTolerance || abs(z1 - z2) > derivationTolerance else {
    return .failure(.derivationPointsCoincide(tier: tier, numbers: numbers))
  }

  // **A zero denominator is not guarded**: the quotient is infinite, its arc-tangent is exactly ±90, and
  // a facet at `90.00°` is the honest answer to two points at one radius (D22). The finiteness check is
  // still written, because a not-a-number angle must never reach the draft.
  let angle = atan(sign * (z2 - z1) / (r1 - r2)) * 180 / Double.pi
  guard angle.isFinite else {
    return .failure(.derivationPointsCoincide(tier: tier, numbers: numbers))
  }

  // **Exactly zero is allowed** — that is a table, and it is the answer for two points at one height.
  guard angle >= 0 else {
    return .failure(
      .derivedAngleContradictsPart(tier: tier, part: part, angle: angle, numbers: numbers))
  }

  let written = roundedAngle(angle)
  let anchor = anchorEnd(first: first, second: second) == 0 ? first : second

  // Against the **rounded** angle, because that is what will be stored, and against the anchor point,
  // because that is the point the solver will reach to.
  let aimedDot = dot(atStop: aimedStop, angle: written, wheel: wheel, part: part, to: anchor.point)
  var arrives: (stop: Int, dot: Double)?
  for stop in stops {
    let reach = dot(atStop: stop, angle: written, wheel: wheel, part: part, to: anchor.point)
    guard reach > aimedDot + derivationTolerance else { continue }
    if arrives.map({ reach > $0.dot }) ?? true { arrives = (stop, reach) }
  }
  if let arrives {
    return .failure(
      .siblingFacetTakesTheDepth(
        tier: tier, aimed: aimedStop, arrives: arrives.stop, angle: written,
        aimedDot: aimedDot, arrivingDot: arrives.dot))
  }

  return .success(DerivedTierAngle(angle: written, meet: anchor.meet))
}

/// How far a facet cut at this angle on this stop reaches toward a point — the same `max` of dot products
/// the solver takes to decide which facet of a tier arrives.
private func dot(atStop stop: Int, angle: Double, wheel: Int, part: Part, to point: SIMD3<Double>)
  -> Double
{
  let normal = planeNormal(angleDegrees: angle, index: stop, wheel: wheel, part: part)
  return normal.x * point.x + normal.y * point.y + normal.z * point.z
}

/// The sign the part puts on the normal's `z`, as `planeNormal` applies it.
private func isUpward(_ part: Part) -> Bool {
  switch part {
  case .crown, .table: true
  case .pav, .gdl: false
  }
}
