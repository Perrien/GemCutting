import BenchGeometry
import Observation

// Scoped, not a whole-module import: `FacetKernel` exports a public enum named `Observation`, and a
// type in scope shadows the module of the same name — which is the module `@Observable` expands its
// references against. Importing only `Pattern` leaves `Observation` meaning the framework.
import struct FacetKernel.Pattern

/// Owns the drawn solid. One build per (pattern, tier limit) change — never in a draw call (D13) — and
/// one value read by both the viewport and the debug readout, so a readout cannot agree with a broken
/// solid (D14).
@Observable final class BenchSolidStore {
  private(set) var solid: BenchSolid
  private(set) var mesh: SolidMesh
  /// Bumped on every rebuild. Comparing this beats comparing two arrays of vertices.
  private(set) var generation = 0

  /// Double optional on purpose: `nil` is *never built*, `.some(nil)` is *built for no pattern*.
  private var builtPattern: Pattern??
  private var builtTierLimit: Int?

  /// A window has a solid before its first layout.
  init() {
    let solid = benchSolid(for: nil)
    self.solid = solid
    mesh = solidMesh(solid)
  }

  func rebuildIfNeeded(pattern: Pattern?, tierLimit: Int?) {
    guard builtPattern != .some(pattern) || builtTierLimit != tierLimit else { return }
    let solid = benchSolid(for: pattern, tierLimit: tierLimit)
    self.solid = solid
    mesh = solidMesh(solid)
    generation += 1
    builtPattern = .some(pattern)
    builtTierLimit = tierLimit
  }
}
