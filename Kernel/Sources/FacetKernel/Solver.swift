import Foundation

/// A tier once its depth is known. Every facet of a tier is cut to one depth.
public struct SolvedTier: Sendable {
  public var tier: String
  public var part: Part
  public var angle: Double
  public var wheel: Int
  public var indices: [Int]
  /// The plane offset every facet of this tier is cut to, in `size` units.
  public var d: Double

  public init(tier: String, part: Part, angle: Double, wheel: Int, indices: [Int], d: Double) {
    self.tier = tier
    self.part = part
    self.angle = angle
    self.wheel = wheel
    self.indices = indices
    self.d = d
  }
}

/// A solved pattern: each tier's depth, the half-spaces those depths expand to, the facet each plane
/// belongs to, and the solid they intersect into.
public struct Solution: Sendable {
  public var tiers: [SolvedTier]
  public var planes: [Plane]
  /// Plane index to the facet that owns it.
  public var planeOwner: [Int: (tier: String, index: Int)]
  public var polytope: Polytope

  public init(
    tiers: [SolvedTier],
    planes: [Plane],
    planeOwner: [Int: (tier: String, index: Int)],
    polytope: Polytope
  ) {
    self.tiers = tiers
    self.planes = planes
    self.planeOwner = planeOwner
    self.polytope = polytope
  }
}

/// Everything the solve refuses to guess at. Each case names the tier being solved.
public enum SolverError: Error, Equatable, CustomStringConvertible {
  /// A meet names a tier that this pattern cuts later. Reversing the two would yield a pattern that
  /// cannot be cut, so this is reported, never fixed by reordering.
  case forwardReference(tier: String, named: String)
  case namesOwnFacet(tier: String)
  case unknownFacet(tier: String, named: FacetRef)
  /// The three named planes do not meet at a point — they are parallel, or share an axis.
  case singularTriple(tier: String)
  /// A second `tcp` on one side. The first tier to set a depth there consumed the free datum; on any
  /// later tier the same condition holds at every depth and constrains nothing.
  case secondTCPOnSide(tier: String, part: Part)
  /// A `fraction` endpoint asks for the axial point on a side where nothing has reached the axis yet.
  case noAxialPointOnSide(tier: String, part: Part)
  /// A girdle meet needs the outline's width, and the vertical planes placed so far do not enclose a
  /// bounded outline.
  case girdleOutlineUndetermined(tier: String)
  case vertexNeedsThreeFacets(tier: String, count: Int)
  case fractionEndpointNotVertexOrTCP(tier: String, kind: String)
  case tierHasNoIndices(tier: String)

  public var description: String {
    switch self {
    case .forwardReference(let tier, let named):
      "tier \(tier): names tier \(named), which this pattern cuts later"
    case .namesOwnFacet(let tier):
      "tier \(tier): a meet cannot name a facet of the tier being cut"
    case .unknownFacet(let tier, let named):
      "tier \(tier): there is no facet \(named.tier)@\(named.index)"
    case .singularTriple(let tier):
      "tier \(tier): the three named facets do not meet at a point"
    case .secondTCPOnSide(let tier, let part):
      "tier \(tier): the \(part.rawValue) side already has an axial point; tcp constrains nothing here"
    case .noAxialPointOnSide(let tier, let part):
      "tier \(tier): nothing has reached the axis on the \(part.rawValue) side yet"
    case .girdleOutlineUndetermined(let tier):
      "tier \(tier): the girdle outline is not bounded by the vertical planes placed so far"
    case .vertexNeedsThreeFacets(let tier, let count):
      "tier \(tier): a vertex meet names exactly 3 facets, not \(count)"
    case .fractionEndpointNotVertexOrTCP(let tier, let kind):
      "tier \(tier): a fraction's endpoint is a vertex or a tcp, not a \(kind)"
    case .tierHasNoIndices(let tier):
      "tier \(tier): a tier with no index stops cuts no facets"
    }
  }
}

/// Solves every tier's depth, then intersects the resulting half-spaces into the finished solid.
///
/// Tiers resolve in file order, each from the planes already placed: three named planes fix a point by
/// algebra alone, so no solid is needed to compute a depth and nothing is simulated tier by tier.
/// Editing an early tier moves every later depth, which is why the whole pattern re-solves at once and
/// there is nothing to update incrementally.
///
/// `girdleTargetFraction` is the girdle band's thickness as a fraction of the outline's width. It is a
/// parameter because a crown tier's offset depends on it and each authored pattern has its own
/// diagram-measured value.
public func solve(_ pattern: Pattern, girdleTargetFraction: Double = 0.04) throws -> Solution {
  var run = Solve(pattern: pattern, girdleTargetFraction: girdleTargetFraction)
  return try run.solve()
}

/// The girdle outline's extent along the two fixed axes: `width` along the 90-270 degree axis,
/// `length` along 0-180. Returns `nil` when the vertical planes do not enclose a bounded outline.
///
/// Whether such an axis crosses a girdle flat or a girdle corner is a property of the design, not
/// something to decide — the round brilliant's sixteen girdle facets are chords of an intended circle
/// and index 24 falls on a corner, which this handles without a special case.
///
/// The outline is fixed by the 90-degree tiers and the `size` normalisation alone, which is why a
/// girdle meet can ask for the width before any girdle thickness exists.
func girdleOutlineExtent(
  _ planes: [Plane],
  tolerance: Double = 1e-7
) -> (width: Double, length: Double)? {
  let vertical = planes.filter { abs($0.n.z) < 1e-9 }
  guard vertical.count >= 3, enclosesTheAxis(vertical) else { return nil }

  var corners: [(x: Double, y: Double)] = []
  for i in vertical.indices {
    for j in vertical.indices where j > i {
      let a = vertical[i]
      let b = vertical[j]
      let determinant = a.n.x * b.n.y - a.n.y * b.n.x
      guard abs(determinant) >= 1e-9 else { continue }
      let corner = (
        x: (a.d * b.n.y - a.n.y * b.d) / determinant,
        y: (a.n.x * b.d - a.d * b.n.x) / determinant
      )
      let inside = vertical.allSatisfy {
        $0.n.x * corner.x + $0.n.y * corner.y <= $0.d + tolerance
      }
      guard inside else { continue }
      corners.append(corner)
    }
  }

  let xs = corners.map(\.x)
  let ys = corners.map(\.y)
  guard let minX = xs.min(), let maxX = xs.max(), let minY = ys.min(), let maxY = ys.max() else {
    return nil
  }
  return (width: maxY - minY, length: maxX - minX)
}

/// Whether these vertical planes bound the outline in every direction: sorted by azimuth, no gap
/// between neighbours reaches 180 degrees.
///
/// Counting corners is not enough. Three planes at 0, 30 and 60 degrees give three corners and an
/// outline open to the far side, whose extent along either axis is infinite.
private func enclosesTheAxis(_ vertical: [Plane]) -> Bool {
  let azimuths = vertical.map { atan2($0.n.y, $0.n.x) }.sorted()
  guard let first = azimuths.first, let last = azimuths.last else { return false }
  var gaps = zip(azimuths.dropFirst(), azimuths).map { $0 - $1 }
  gaps.append(first + 2 * Double.pi - last)
  return gaps.allSatisfy { $0 < Double.pi - 1e-9 }
}

/// Which end of the stone a tier is cut on. Crown and pavilion each have their own axial point once
/// both are cut, so a meet that names the axis has to say which one it means.
private enum Side: Hashable {
  case crown
  case pavilion

  init(_ part: Part) {
    switch part {
    case .crown, .table: self = .crown
    case .pav, .gdl: self = .pavilion
    }
  }
}

private typealias Vector = (x: Double, y: Double, z: Double)

/// The solve in progress: the planes placed so far and what they let a later tier resolve against.
private struct Solve {
  let pattern: Pattern
  let girdleTargetFraction: Double

  private var tiers: [SolvedTier] = []
  private var planes: [Plane] = []
  private var owner: [Int: (tier: String, index: Int)] = [:]
  /// Tier label to index stop to plane index — the placed facets, and so also the only references a
  /// meet may name.
  private var placed: [String: [Int: Int]] = [:]
  /// Where the stone's surface currently crosses the axis, per side.
  private var axial: [Side: Double] = [:]

  init(pattern: Pattern, girdleTargetFraction: Double) {
    self.pattern = pattern
    self.girdleTargetFraction = girdleTargetFraction
  }

  mutating func solve() throws -> Solution {
    for spec in pattern.tiers {
      guard !spec.indices.isEmpty else { throw SolverError.tierHasNoIndices(tier: spec.tier) }
      let wheel = pattern.wheel(of: spec)
      let normals = spec.indices.map {
        planeNormal(angleDegrees: spec.angle, index: $0, wheel: wheel, part: spec.part)
      }
      let d = try depth(of: spec, normals: normals)
      place(spec, wheel: wheel, normals: normals, d: d)
    }

    return Solution(
      tiers: tiers,
      planes: planes,
      planeOwner: owner,
      polytope: intersectHalfSpaces(planes)
    )
  }

  // MARK: - The five meet forms

  private func depth(of spec: TierSpec, normals: [Vector]) throws -> Double {
    switch spec.meet {
    case .size:
      // The normalisation rather than a constraint: this tier's offset *is* the unit, and every other
      // depth is expressed in it — a `tcp` tier reaches radius 1, a girdle thickness is a fraction of
      // a width measured the same way. So there is no separate rescaling pass. It is a normalisation
      // and not a diameter, which is why it works on a rectangle.
      return 1

    case .tcp:
      // The free datum: the tier is cut until it reaches the girdle outline along its own azimuth,
      // where the normalisation puts the outline at radius 1. Only the first tier to set a depth on a
      // side can do this.
      guard axial[Side(spec.part)] == nil else {
        throw SolverError.secondTCPOnSide(tier: spec.tier, part: spec.part)
      }
      return sin(radians(spec.angle))

    case .girdle:
      // The tier reaches the girdle outline as a `tcp` tier would, offset along the axis by the band's
      // thickness. Every facet of the tier shares one `z`, so which one is asked is immaterial.
      guard let extent = girdleOutlineExtent(planes) else {
        throw SolverError.girdleOutlineUndetermined(tier: spec.tier)
      }
      return sin(radians(spec.angle)) + normals[0].z * girdleTargetFraction * extent.width

    case .vertex(let facets):
      return reach(normals, to: try point(ofVertex: facets, for: spec))

    case .fraction(let from, let percent, let to):
      let start = try point(of: from, for: spec)
      let end = try point(of: to, for: spec)
      let t = percent / 100
      let target = (
        x: start.x + t * (end.x - start.x),
        y: start.y + t * (end.y - start.y),
        z: start.z + t * (end.z - start.z)
      )
      return reach(normals, to: target)
    }
  }

  /// The depth at which this tier's facets reach `target`.
  ///
  /// A tier shares one depth, so the solid requires `n · p <= d` for every facet of the tier, with
  /// equality on whichever one arrives at the point. Nothing in the pattern says which that is; it is
  /// computed. A tie means the point sits on an edge between two facets of the tier, and `d` is still
  /// the same number.
  private func reach(_ normals: [Vector], to target: Vector) -> Double {
    normals.reduce(-Double.infinity) { Swift.max($0, dot($1, target)) }
  }

  // MARK: - Resolving a meet's named points

  private func point(of meet: Meet, for spec: TierSpec) throws -> Vector {
    switch meet {
    case .vertex(let facets):
      return try point(ofVertex: facets, for: spec)
    case .tcp:
      // The axial point on the same side as this tier: once both crown and pavilion are cut there are
      // two of them.
      guard let z = axial[Side(spec.part)] else {
        throw SolverError.noAxialPointOnSide(tier: spec.tier, part: spec.part)
      }
      return (x: 0, y: 0, z: z)
    case .size, .girdle, .fraction:
      throw SolverError.fractionEndpointNotVertexOrTCP(tier: spec.tier, kind: meet.kindName)
    }
  }

  private func point(ofVertex facets: [FacetRef], for spec: TierSpec) throws -> Vector {
    guard facets.count == 3 else {
      throw SolverError.vertexNeedsThreeFacets(tier: spec.tier, count: facets.count)
    }
    let named = try facets.map { try plane(named: $0, for: spec) }
    guard let meetpoint = triplePoint(named[0], named[1], named[2]) else {
      throw SolverError.singularTriple(tier: spec.tier)
    }
    return meetpoint
  }

  private func plane(named ref: FacetRef, for spec: TierSpec) throws -> Plane {
    guard ref.tier != spec.tier else { throw SolverError.namesOwnFacet(tier: spec.tier) }
    guard let stops = placed[ref.tier] else {
      guard pattern.tiers.contains(where: { $0.tier == ref.tier }) else {
        throw SolverError.unknownFacet(tier: spec.tier, named: ref)
      }
      throw SolverError.forwardReference(tier: spec.tier, named: ref.tier)
    }
    guard let plane = stops[ref.index] else {
      throw SolverError.unknownFacet(tier: spec.tier, named: ref)
    }
    return planes[plane]
  }

  // MARK: - Placing a solved tier

  private mutating func place(_ spec: TierSpec, wheel: Int, normals: [Vector], d: Double) {
    for (stop, normal) in zip(spec.indices, normals) {
      placed[spec.tier, default: [:]][stop] = planes.count
      owner[planes.count] = (tier: spec.tier, index: stop)
      planes.append(Plane(n: normal, d: d))
    }
    tiers.append(
      SolvedTier(
        tier: spec.tier,
        part: spec.part,
        angle: spec.angle,
        wheel: wheel,
        indices: spec.indices,
        d: d
      )
    )

    // Where this tier's planes cross the axis, if they do. A 90-degree tier never reaches it, and
    // letting one register a phantom axial point is a live trap: the surface at the axis is whichever
    // plane crosses it closest to the girdle, since anything beyond that has already been cut away.
    let z = normals[0].z
    guard abs(z) >= 1e-9 else { return }
    let crossing = d / z
    let side = Side(spec.part)
    if axial[side].map({ abs(crossing) < abs($0) }) ?? true {
      axial[side] = crossing
    }
  }
}

private func radians(_ degrees: Double) -> Double {
  degrees * Double.pi / 180
}
