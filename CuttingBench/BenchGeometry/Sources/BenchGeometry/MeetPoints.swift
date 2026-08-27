import FacetKernel
import Foundation

/// Which point of a meet a dot is, and so what colour it draws in.
public enum MeetPointRole: Equatable, Sendable {
  case endpointA
  case endpointB
  case anchored
  case vertex
}

/// One named point of one tier's meet: what it reads, where it sits, and the facets it names.
public struct MeetPointDot: Identifiable, Equatable, Sendable {
  /// `A`, `B`, `M`, or the anchored point's percentage as `24.86%`.
  public var label: String
  public var role: MeetPointRole
  /// The facets this point names, in `meetText`'s own notation — `G@12 · G@24 · P1@24`, or `tcp`.
  /// Empty for the anchored point, which names none.
  public var facets: String
  /// `nil` when the point cannot be resolved: a named facet was never placed, or the three planes pin
  /// no point. The chip still shows; the viewport draws nothing.
  public var world: SIMD3<Float>?
  /// The anchored point's percentage as a number, and `nil` for every other role. The label carries it
  /// formatted for reading; this carries it for editing, so the cell never parses its own display text.
  public var percent: Double?
  /// Stable across a rebuild, so a `ForEach` keeps its identity: the tier label and the role.
  public var id: String

  public init(
    label: String, role: MeetPointRole, facets: String, world: SIMD3<Float>?,
    percent: Double? = nil, id: String
  ) {
    self.label = label
    self.role = role
    self.facets = facets
    self.world = world
    self.percent = percent
    self.id = id
  }
}

/// The dots for one tier's meet, in reading order.
///
/// A `fraction` gives three — **A**, the anchored point, **B** — a plain `vertex` gives one, and `size`,
/// `tcp` and `girdle` give none: they name no facet triple.
///
/// Resolved against the tiers cut *before* this one, taken as the solution's own tiers truncated to this
/// tier's position in `pattern.tiers`. A meet is a claim about the stone as it stands when that tier is
/// cut, so the finished solid is the wrong solid to measure it against.
///
/// Empty for no pattern, and for a tier label the pattern does not carry.
public func meetPointDots(ofTier tier: String, pattern: Pattern?, solid: BenchSolid)
  -> [MeetPointDot]
{
  guard let pattern, let k = pattern.tiers.firstIndex(where: { $0.tier == tier }) else { return [] }
  let spec = pattern.tiers[k]

  // One rule with no special case: for a solved tier this is every earlier solved tier, and for the tier
  // that stopped the solve it is every solved tier — which is right, because a stopped tier's meet still
  // names only earlier facets.
  let before = Array((solid.solution?.tiers ?? []).prefix(k))
  let placed = placedPlanes(of: before)

  switch spec.meet {
  case .size, .tcp, .girdle:
    // Three forms that name no facet triple, and so name no point to draw.
    return []

  case .vertex(let facets):
    let meet = Meet.vertex(facets: facets)
    return [
      MeetPointDot(
        label: "M",
        role: .vertex,
        facets: meetText(meet),
        world: world(of: meet, part: spec.part, placed: placed, before: before),
        id: "\(tier)-M")
    ]

  case .fraction(let from, let percent, let to):
    let start = world(of: from, part: spec.part, placed: placed, before: before)
    let end = world(of: to, part: spec.part, placed: placed, before: before)
    // The anchored point exists only when both its endpoints do: an interpolation from a point that was
    // never resolved is not a point.
    var anchored: SIMD3<Float>?
    if let start, let end {
      anchored = start + Float(percent / 100) * (end - start)
    }

    // **A**, the anchored point, **B** — the anchored point sits between its endpoints and reads that
    // way in the cell.
    return [
      MeetPointDot(
        label: "A", role: .endpointA, facets: meetText(from), world: start, id: "\(tier)-A"),
      MeetPointDot(
        label: "\(percentText(percent))%",
        role: .anchored,
        // It names no facets, so it carries its percentage instead.
        facets: "",
        world: anchored,
        percent: percent,
        id: "\(tier)-anchored"),
      MeetPointDot(label: "B", role: .endpointB, facets: meetText(to), world: end, id: "\(tier)-B"),
    ]
  }
}

/// Where one endpoint of a meet sits, or `nil` when the tiers cut so far do not pin it.
private func world(
  of endpoint: Meet,
  part: Part,
  placed: [String: [Int: Plane]],
  before: [SolvedTier]
) -> SIMD3<Float>? {
  switch endpoint {
  case .tcp:
    // The kernel's own rule, never a second copy of it: the side comes from the tier's own part, and a
    // 90-degree tier registers no crossing.
    return axialPoint(onTheSideOf: part, cutBy: before).map(simd)

  case .vertex(let refs):
    let named = refs.compactMap { placed[$0.tier]?[$0.index] }
    guard named.count == 3 else { return nil }
    return triplePoint(named[0], named[1], named[2]).map(simd)

  case .size, .girdle, .fraction:
    // The format rejects these as a fraction's endpoints, so decoding never produces one. The branch
    // exists because the switch has to be total, and inventing a point would be worse than showing none.
    return nil
  }
}

/// Tier label to index stop to plane, for the tiers cut before the one being read. The kernel's own
/// version of this shape is private to it, so it is rebuilt here rather than reached into.
private func placedPlanes(of tiers: [SolvedTier]) -> [String: [Int: Plane]] {
  var placed: [String: [Int: Plane]] = [:]
  for solved in tiers {
    for (stop, plane) in zip(solved.indices, planes(of: solved)) {
      placed[solved.tier, default: [:]][stop] = plane
    }
  }
  return placed
}

private func simd(_ point: (x: Double, y: Double, z: Double)) -> SIMD3<Float> {
  SIMD3<Float>(Float(point.x), Float(point.y), Float(point.z))
}
