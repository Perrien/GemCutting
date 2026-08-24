import FacetKernel
import Foundation

/// Where the rough's own planes stop and the pattern's begin. Fixed for every pattern and for no
/// pattern at all, which is what makes the rough plane indices and their names testable (D9).
let roughPlaneCount = 2 + Rough.wallCount

/// What a plane of the drawn solid belongs to. Two cases, so a rough wall named `G1` and a tier named
/// `G1` are never the same value (D8).
public enum FacetOrigin: Equatable, Sendable {
  case rough(RoughFacet)
  case cut(FacetRef)
}

/// The solid the viewport draws: the rough intersected with whatever tiers have been placed.
public struct BenchSolid: Sendable {
  /// Rough planes at indices 0…17, then the pattern's solved planes from 18 up (D9).
  public var planes: [Plane]
  /// An entry for every index in `planes`.
  public var origin: [Int: FacetOrigin]
  public var polytope: Polytope

  public init(planes: [Plane], origin: [Int: FacetOrigin], polytope: Polytope) {
    self.planes = planes
    self.origin = origin
    self.polytope = polytope
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
/// make the closure check pass for every pattern including the ones it exists to catch (D1).
///
/// `tierLimit` is the diagnostic in T2: `nil` means every tier, `n` means only the first `n`. Truncating
/// is safe because a meet may only name an earlier tier — a forward reference is
/// `SolverError.forwardReference`, never something the solver resolves — so the first `n` tiers solve to
/// exactly the depths they have in the whole pattern.
public func benchSolid(for pattern: Pattern?, tierLimit: Int? = nil) -> BenchSolid {
  var planes = roughPlanes()
  var origin: [Int: FacetOrigin] = [:]
  for (index, facet) in roughFacets().enumerated() {
    origin[index] = .rough(facet)
  }

  if var truncated = pattern {
    if let tierLimit {
      truncated.tiers = Array(truncated.tiers.prefix(tierLimit))
    }
    // `solveAsFarAsPossible`, never `solve`: a half-authored pattern is the normal state of authoring,
    // and its `failure` is discarded because the tiers that placed are what there is to draw (D11). No
    // `girdleTargetFraction` argument, so the pattern reproduces its own diagram (D12).
    let partial = solveAsFarAsPossible(truncated)
    for (k, plane) in partial.solution.planes.enumerated() {
      planes.append(plane)
      // A plane with no owner is impossible today. If one appears, it is left out of `origin` rather
      // than given an invented name — a missing entry is something a test can see.
      if let owner = partial.solution.planeOwner[k] {
        origin[roughPlaneCount + k] = .cut(FacetRef(tier: owner.tier, index: owner.index))
      }
    }
  }

  return BenchSolid(planes: planes, origin: origin, polytope: intersectHalfSpaces(planes))
}
