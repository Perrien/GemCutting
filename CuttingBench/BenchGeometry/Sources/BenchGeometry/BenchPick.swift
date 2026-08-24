import FacetKernel
import Foundation

/// The facet a ray meets first, or `nil` when it misses.
///
/// A slab test over the half-spaces (D10). Exact for a convex solid, and it reads only `planes` and
/// `polytope.facets.keys` — the polygons themselves never enter it, so a pick can never name a facet
/// the renderer did not draw.
public func pickFacet(
  _ solid: BenchSolid,
  origin: SIMD3<Float>,
  direction: SIMD3<Float>,
  parallelBelow: Double = 1e-9
) -> (planeIndex: Int, facet: FacetOrigin)? {
  let o = (x: Double(origin.x), y: Double(origin.y), z: Double(origin.z))
  let dir = (x: Double(direction.x), y: Double(direction.y), z: Double(direction.z))

  var entry = -Double.greatestFiniteMagnitude
  var entryPlane: Int?
  var exit = Double.greatestFiniteMagnitude

  for (index, plane) in solid.planes.enumerated() {
    let nd = dot(plane.n, dir)
    let no = dot(plane.n, o)

    guard abs(nd) >= parallelBelow else {
      // The ray runs parallel to this plane, so it is on one side of it for its whole length. Outside
      // means it never enters the solid at all; inside means this plane cannot bound the interval.
      if no > plane.d { return nil }
      continue
    }

    let t = (plane.d - no) / nd
    if nd < 0 {
      // Running into the half-space: the last such crossing is where the solid starts.
      if t > entry {
        entry = t
        entryPlane = index
      }
    } else {
      // Running out of it: the first such crossing is where the solid ends.
      exit = min(exit, t)
    }
  }

  guard let entryPlane, entry <= exit, entry > 0 else { return nil }
  // A plane cut away by the others has no polygon and nothing to click, and a plane with no `origin`
  // entry gets no invented name (D10, D11).
  guard solid.polytope.facets[entryPlane] != nil, let facet = solid.origin[entryPlane] else {
    return nil
  }
  return (entryPlane, facet)
}

/// The label a picked facet reads as: `C`, `P`, `G1`…`G16` for rough, `"<tier> · <index>"` for a cut
/// facet — the tier table's own two columns (D11).
public func facetLabel(_ facet: FacetOrigin) -> String {
  switch facet {
  case .rough(let rough): rough.name
  case .cut(let ref): "\(ref.tier) · \(ref.index)"
  }
}

/// The kernel's own tuple `dot` is internal to the kernel, so this file declares its own rather than
/// being given access to it.
private func dot(
  _ a: (x: Double, y: Double, z: Double), _ b: (x: Double, y: Double, z: Double)
) -> Double {
  a.x * b.x + a.y * b.y + a.z * b.z
}
