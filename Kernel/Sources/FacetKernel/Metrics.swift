import Foundation

/// Everything about a solved stone that a sheet would state and this kernel computes instead: counts,
/// symmetry and proportions. Nothing here is read from a pattern's `notes`.
///
/// Every length is in `size` units, the same units the solver's offsets are in, and every ratio is
/// against the width. No millimetres appear anywhere.
public struct Metrics: Sendable {
  public var facetCount: Int
  /// Facets each tier contributes to the finished solid. A tier cut away entirely is present at zero.
  public var facetsPerTier: [String: Int]
  /// The largest `n` for which turning the stone by a full turn over `n` leaves it unchanged.
  public var rotationalOrder: Int
  /// The index positions the stone mirrors about, each below half a turn.
  public var mirrorAxes: [Int]
  /// The girdle outline's extent along the 90-270 degree axis.
  public var widthNormalised: Double
  /// The girdle outline's extent along the 0-180 degree axis.
  public var lengthNormalised: Double
  public var lengthOverWidth: Double
  public var totalDepthFractionOfWidth: Double
  /// Girdle bottom to culet.
  public var pavilionDepthFractionOfWidth: Double
  /// Girdle top to table.
  public var crownHeightFractionOfWidth: Double
  public var girdleThicknessNormalised: Double
  public var girdleFractionOfWidth: Double
  /// Whether the pavilion ends in a single point rather than a culet facet or a keel line.
  public var culetIsPoint: Bool

  public init(
    facetCount: Int,
    facetsPerTier: [String: Int],
    rotationalOrder: Int,
    mirrorAxes: [Int],
    widthNormalised: Double,
    lengthNormalised: Double,
    lengthOverWidth: Double,
    totalDepthFractionOfWidth: Double,
    pavilionDepthFractionOfWidth: Double,
    crownHeightFractionOfWidth: Double,
    girdleThicknessNormalised: Double,
    girdleFractionOfWidth: Double,
    culetIsPoint: Bool
  ) {
    self.facetCount = facetCount
    self.facetsPerTier = facetsPerTier
    self.rotationalOrder = rotationalOrder
    self.mirrorAxes = mirrorAxes
    self.widthNormalised = widthNormalised
    self.lengthNormalised = lengthNormalised
    self.lengthOverWidth = lengthOverWidth
    self.totalDepthFractionOfWidth = totalDepthFractionOfWidth
    self.pavilionDepthFractionOfWidth = pavilionDepthFractionOfWidth
    self.crownHeightFractionOfWidth = crownHeightFractionOfWidth
    self.girdleThicknessNormalised = girdleThicknessNormalised
    self.girdleFractionOfWidth = girdleFractionOfWidth
    self.culetIsPoint = culetIsPoint
  }
}

/// Measures a solved stone.
///
/// Every figure is derived from the solid the pattern cut. Where a sheet declares one of these it is a
/// claim to cross-check, never a value to read: Easy Octagon's sheet declares plain 4-fold where the
/// solve finds 4-fold with mirrors, which is a stronger statement than the sheet makes.
public func metrics(_ solution: Solution) -> Metrics {
  let outline = outlineExtent(of: solution)
  let band = girdleBand(of: solution)
  let heights = solution.polytope.vertices.map(\.z)
  let culet = heights.min() ?? 0
  let table = heights.max() ?? 0

  // Symmetry reads the azimuth of every facet the stone actually has, so a tier a later one cut away
  // contributes nothing. A horizontal facet is left out whatever survives: its index stop was where the
  // lap sat, and a facet with no azimuth cannot break or carry a rotation.
  let azimuthal = survivingFacets(solution).filter { abs($0.angle) > horizontalBelow }
  let wheel = commonWheel(of: solution)

  return Metrics(
    facetCount: solution.polytope.facets.count,
    facetsPerTier: facetsPerTier(solution),
    rotationalOrder: rotationalOrder(of: azimuthal, wheel: wheel),
    mirrorAxes: mirrorAxes(of: azimuthal, wheel: wheel),
    widthNormalised: outline.width,
    lengthNormalised: outline.length,
    lengthOverWidth: outline.length / outline.width,
    totalDepthFractionOfWidth: (table - culet) / outline.width,
    pavilionDepthFractionOfWidth: (band.bottom - culet) / outline.width,
    crownHeightFractionOfWidth: (table - band.top) / outline.width,
    girdleThicknessNormalised: band.top - band.bottom,
    girdleFractionOfWidth: (band.top - band.bottom) / outline.width,
    culetIsPoint: heights.filter { abs($0 - culet) <= sameHeight }.count == 1
  )
}

// MARK: - Counts

private func facetsPerTier(_ solution: Solution) -> [String: Int] {
  let surviving = survivingStops(solution)
  return Dictionary(
    uniqueKeysWithValues: solution.tiers.map { ($0.tier, surviving[$0.tier]?.count ?? 0) }
  )
}

/// Tier label to the index stops that still carry a facet of the finished solid.
private func survivingStops(_ solution: Solution) -> [String: Set<Int>] {
  var stops: [String: Set<Int>] = [:]
  for plane in solution.polytope.facets.keys {
    guard let owner = solution.planeOwner[plane] else { continue }
    stops[owner.tier, default: []].insert(owner.index)
  }
  return stops
}

// MARK: - Symmetry

/// A surviving facet reduced to what symmetry can see: which side of the stone it is cut on, at what
/// angle, and where it sits on the wheel.
struct FacetAzimuth: Hashable {
  let part: Part
  let angle: Double
  /// The index stop, on the least wheel every tier's stops land on.
  let position: Int
}

/// Every facet the finished solid has, including the horizontal ones a symmetry measure leaves out.
func survivingFacets(_ solution: Solution) -> [FacetAzimuth] {
  let wheel = commonWheel(of: solution)
  let surviving = survivingStops(solution)
  return solution.tiers.flatMap { tier in
    (surviving[tier.tier] ?? []).sorted().map {
      FacetAzimuth(part: tier.part, angle: tier.angle, position: $0 * (wheel / tier.wheel))
    }
  }
}

/// The least wheel every tier's index stops land on, so stops from tiers cut on different wheels can be
/// compared as one set of azimuths.
func commonWheel(of solution: Solution) -> Int {
  solution.tiers.reduce(1) { leastCommonMultiple($0, $1.wheel) }
}

/// The largest `n` for which turning the stone by `wheel / n` stops maps every facet onto a facet.
func rotationalOrder(of facets: [FacetAzimuth], wheel: Int) -> Int {
  let all = Set(facets)
  guard !all.isEmpty else { return 1 }

  for order in stride(from: wheel, through: 2, by: -1) where wheel % order == 0 {
    let step = wheel / order
    let turns = all.allSatisfy {
      all.contains(
        FacetAzimuth(part: $0.part, angle: $0.angle, position: ($0.position + step) % wheel))
    }
    if turns { return order }
  }
  return 1
}

/// Every index position the stone mirrors about, below half a turn — beyond that each axis repeats.
///
/// An axis falling halfway between two index stops is not an index position and is not reported.
func mirrorAxes(of facets: [FacetAzimuth], wheel: Int) -> [Int] {
  let all = Set(facets)
  guard !all.isEmpty else { return [] }

  return (0..<(wheel / 2)).filter { axis in
    all.allSatisfy {
      all.contains(
        FacetAzimuth(
          part: $0.part,
          angle: $0.angle,
          position: ((2 * axis - $0.position) % wheel + wheel) % wheel
        ))
    }
  }
}

private func leastCommonMultiple(_ a: Int, _ b: Int) -> Int {
  a / greatestCommonDivisor(a, b) * b
}

private func greatestCommonDivisor(_ a: Int, _ b: Int) -> Int {
  b == 0 ? a : greatestCommonDivisor(b, a % b)
}

// MARK: - Proportions

/// The girdle outline's extent along the two fixed axes: width along the 90-270 degree axis, length
/// along 0-180. Whether such an axis crosses a girdle flat or a girdle corner is a property of the
/// design, not something to decide.
///
/// Measured from the vertical planes, the same way the solver measures it to size the girdle band. A
/// design with no vertical plane has a knife-edge girdle rather than a flat one, and its outline is the
/// widest silhouette the solid has — which for a convex solid is reached at a vertex.
private func outlineExtent(of solution: Solution) -> (width: Double, length: Double) {
  if let outline = girdleOutlineExtent(solution.planes) { return outline }

  let xs = solution.polytope.vertices.map(\.x)
  let ys = solution.polytope.vertices.map(\.y)
  return (
    width: (ys.max() ?? 0) - (ys.min() ?? 0),
    length: (xs.max() ?? 0) - (xs.min() ?? 0)
  )
}

/// Where the girdle band starts and ends. Crown height is measured from its top and pavilion depth from
/// its bottom, so the band is its own share of the stone's height and never half-counted into either.
///
/// The band is the height its own facets span. A knife-edge girdle has no facets to span it, so the band
/// is the widest ring of the solid and has zero thickness.
private func girdleBand(of solution: Solution) -> (bottom: Double, top: Double) {
  var heights: [Double] = []
  for (plane, polygon) in solution.polytope.facets where abs(solution.planes[plane].n.z) < 1e-9 {
    heights.append(contentsOf: polygon.map { solution.polytope.vertices[$0].z })
  }

  if heights.isEmpty {
    let radius = solution.polytope.vertices.map { ($0.x * $0.x + $0.y * $0.y).squareRoot() }
    let widest = radius.max() ?? 0
    heights = solution.polytope.vertices.indices
      .filter { widest - radius[$0] <= sameHeight }
      .map { solution.polytope.vertices[$0].z }
  }

  return (bottom: heights.min() ?? 0, top: heights.max() ?? 0)
}

/// A facet at or below this angle is horizontal: its index stop carries no azimuth.
private let horizontalBelow = 1e-9
/// Two vertices are at the same height, or the same distance from the axis, within this.
private let sameHeight = 1e-7
