import FacetKernel
import Foundation

/// How many half-spaces the rough contributes, and nothing more than that: the pattern's own planes
/// start at this index only while `BenchSolid.includesRough` is true, and at `0` once the scaffolding
/// has come away. Fixed for every pattern and for no pattern at all, which is what makes the rough
/// plane indices and their names testable.
let roughPlaneCount = 2 + Rough.wallCount

/// What a plane of the drawn solid belongs to. Two cases, so a rough wall named `G1` and a tier named
/// `G1` are never the same value.
public enum FacetOrigin: Equatable, Sendable {
  case rough(RoughFacet)
  case cut(FacetRef)
}

/// The solid the viewport draws: the pattern's own planes, and the rough's as well for as long as the
/// pattern still needs the scaffolding.
public struct BenchSolid: Sendable {
  /// The rough's planes first and then the pattern's solved planes while the rough is included; the
  /// pattern's alone once it is not. `includesRough` says which.
  public var planes: [Plane]
  /// An entry for every index in `planes`.
  public var origin: [Int: FacetOrigin]
  public var polytope: Polytope
  /// The tiers that actually placed, as the index ring's source. Empty for no pattern.
  public var tiers: [SolvedTier]
  /// Whether the rough's half-spaces are in `planes` — and so whether the pattern's own planes start at
  /// `roughPlaneCount` or at `0`. Nothing should have to infer which base it is looking at.
  public var includesRough: Bool
  /// The solve's own result, as `metrics` and `validate` see it: **the pattern's own planes, rough-free,
  /// whatever `includesRough` says about what is drawn** (ADR-0004). `nil` only when there is no pattern,
  /// because then there was no solve. Kept rather than recomputed — a second solve per rebuild would pay
  /// for the one expensive step twice.
  public var solution: Solution?
  /// The tier the partial solve stopped on, and the kernel's own sentence saying why — its wording
  /// verbatim, so no display code has to invent one. Both `nil` when every tier placed.
  ///
  /// Two plain strings rather than the `SolverError` itself, which keeps this `Sendable` value free of a
  /// kernel error type.
  public var stoppedAtTier: String?
  public var stoppedReason: String?

  public init(
    planes: [Plane],
    origin: [Int: FacetOrigin],
    polytope: Polytope,
    tiers: [SolvedTier] = [],
    includesRough: Bool = true,
    stoppedAtTier: String? = nil,
    stoppedReason: String? = nil,
    solution: Solution? = nil
  ) {
    self.planes = planes
    self.origin = origin
    self.polytope = polytope
    self.tiers = tiers
    self.includesRough = includesRough
    self.stoppedAtTier = stoppedAtTier
    self.stoppedReason = stoppedReason
    self.solution = solution
  }

  /// The plane indices that survived as facets, split by origin. Both read `polytope.facets.keys`, so
  /// neither can disagree with what is drawn.
  public var roughFacetIndices: [Int] {
    survivingFacetIndices { origin in
      guard case .rough = origin else { return false }
      return true
    }
  }

  public var cutFacetIndices: [Int] {
    survivingFacetIndices { origin in
      guard case .cut = origin else { return false }
      return true
    }
  }

  private func survivingFacetIndices(where matches: (FacetOrigin) -> Bool) -> [Int] {
    polytope.facets.keys.sorted().filter { index in
      guard let origin = origin[index] else { return false }
      return matches(origin)
    }
  }
}

/// Builds the solid. `pattern` is `nil` for a new document — then the result is the bare prism.
///
/// The rough is intersected here, in the app, and never handed to the solver: the kernel's own polytope
/// stays rough-free, because a rough-capped solid always closes and feeding rough into the solve would
/// make the closure check pass for every pattern including the ones it exists to catch (ADR-0004).
///
/// **The rough is scaffolding rather than a bounding box.** Its half-spaces enter the intersection only
/// while the pattern's own planes fail to bound a closed solid, and come away the moment they do —
/// otherwise a rescale that deepened a pavilion would have its culet cut off by a preform that is no
/// longer there. At closure the stone stands well inside the prism, so the intersection already equals
/// the pattern's own solid and the transition is invisible.
///
/// `tierLimit` is the tier-limit diagnostic: `nil` means every tier, `n` means only the first `n`.
/// Truncating is safe because a meet may only name an earlier tier — a forward reference is
/// `SolverError.forwardReference`, never something the solver resolves — so the first `n` tiers solve to
/// exactly the depths they have in the whole pattern.
///
/// It drives no UI: the scrubber's playback steps are what a part-cut stone is displayed from. The
/// parameter stays because it truncates the *pattern* and re-solves, which makes it the independent
/// oracle proving playback's no-re-solve prefix path produces the same geometry (D16).
public func benchSolid(for pattern: Pattern?, tierLimit: Int? = nil) -> BenchSolid {
  guard var truncated = pattern else { return roughOnly() }
  if let tierLimit {
    truncated.tiers = Array(truncated.tiers.prefix(tierLimit))
  }

  // `solveAsFarAsPossible`, never `solve`: a half-authored pattern is the normal state of authoring, and
  // the tiers that placed are what there is to draw. No `girdleTargetFraction` argument, so the pattern
  // reproduces its own diagram.
  let partial = solveAsFarAsPossible(truncated)
  return benchSolid(
    over: partial.solution,
    stoppedAtTier: partial.failure?.tier,
    stoppedReason: partial.failure?.description)
}

/// The drawn solid over a rough-free solution: the scaffolding decision, the rough merge, the origin
/// map and the polytope. **Nothing here solves** — the solution is already the answer for the cut
/// planes, whether it came from `solveAsFarAsPossible` or from re-expanding a prefix of solved tiers
/// (D2).
///
/// `solution` must be rough-free (ADR-0004): a rough-capped solid always closes, so the closure test
/// below would pass for every pattern including the ones it exists to catch.
func benchSolid(
  over solution: Solution,
  stoppedAtTier: String? = nil,
  stoppedReason: String? = nil
) -> BenchSolid {
  // The kernel's own closure check decides whether the scaffolding is still needed. Nothing here
  // computes closure a second time, because a second implementation could agree with a broken one.
  let isOpen = solidFindings(solution, declaredFacetCount: nil).contains { finding in
    guard case .doesNotClose = finding else { return false }
    return true
  }

  var (planes, origin) = roughScaffolding(included: isOpen)
  let base = isOpen ? roughPlaneCount : 0
  for (k, plane) in solution.planes.enumerated() {
    planes.append(plane)
    // A plane with no owner is impossible today. If one appears, it is left out of `origin` rather
    // than given an invented name — a missing entry is something a test can see.
    if let owner = solution.planeOwner[k] {
      origin[base + k] = .cut(FacetRef(tier: owner.tier, index: owner.index))
    }
  }

  return BenchSolid(
    planes: planes,
    origin: origin,
    // With the scaffolding gone, `planes` *is* `solution.planes` in its own order, so the kernel's
    // polytope is already the answer and intersecting it again would be the same work twice.
    polytope: isOpen ? intersectHalfSpaces(planes) : solution.polytope,
    // From the **solution**, never from the pattern's own tiers: a tier the solver could not place has
    // no depth, no planes and therefore no index stops.
    tiers: solution.tiers,
    includesRough: isOpen,
    // Kept rather than discarded. The tiers that placed are what there is to draw, and the tier that
    // stopped the solve is what there is to say.
    stoppedAtTier: stoppedAtTier,
    stoppedReason: stoppedReason,
    solution: solution)
}

/// The bare prism: a window has a solid before any pattern is open, and that solid is the rough alone.
private func roughOnly() -> BenchSolid {
  let (planes, origin) = roughScaffolding(included: true)
  return BenchSolid(
    planes: planes, origin: origin, polytope: intersectHalfSpaces(planes), includesRough: true)
}

/// The rough's planes and their names, or two empties once the pattern's own planes bound a solid and
/// the scaffolding has come away.
private func roughScaffolding(
  included: Bool
) -> (planes: [Plane], origin: [Int: FacetOrigin]) {
  guard included else { return ([], [:]) }
  var origin: [Int: FacetOrigin] = [:]
  for (index, facet) in roughFacets().enumerated() {
    origin[index] = .rough(facet)
  }
  return (roughPlanes(), origin)
}
