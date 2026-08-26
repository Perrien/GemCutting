import BenchGeometry
import Observation

// Scoped, not a whole-module import: `FacetKernel` exports a public enum named `Observation`, and a
// type in scope shadows the module of the same name — which is the module `@Observable` expands its
// references against.
import enum FacetKernel.Finding
import struct FacetKernel.Pattern
import struct FacetKernel.Solution
import func FacetKernel.structuralFindings

/// Owns the findings. The cheap half of validation runs here and now; the expensive half runs off the
/// main thread and lands through `accept`.
///
/// **While the expensive half is in flight the previous result stays and the line marks it stale.** The
/// kept result survives every edit to the open document, a rename included, and is cleared only when the
/// document has no pattern to check at all.
@Observable @MainActor final class BenchFindingsStore {
  private(set) var structural: [Finding] = []
  /// `nil` means no geometric result for this solid: still running, or never going to run.
  private(set) var geometric: [Finding]?
  private(set) var isChecking = false

  /// Bumped per rebuild. A task that finishes after a newer one started is discarded rather than racing.
  private var generation = 0
  private var running: Task<Void, Never>?

  /// `nonisolated`, so a `View`'s `@State` default value can construct it: a `View` struct's own
  /// initialization is not main-actor isolated even though its `body` is. Safe because every stored
  /// property has its own default and every one of their types is `Sendable`.
  nonisolated init() {}

  func rebuild(pattern: Pattern?, solid: BenchSolid) {
    running?.cancel()
    running = nil
    generation += 1
    let generation = self.generation

    guard let pattern, let solution = solid.solution else {
      structural = []
      geometric = []
      isChecking = false
      return
    }

    structural = structuralFindings(pattern)
    // The kernel's own rule: a pattern whose structure is wrong has no solid to measure geometry
    // against, so the expensive half never starts and the detail says so.
    guard structural.isEmpty else {
      geometric = nil
      isChecking = false
      return
    }

    isChecking = true
    running = Task.detached(priority: .userInitiated) { [weak self] in
      let found = geometricFindings(
        pattern: pattern, solution: solution, isCancelled: { Task.isCancelled })
      await self?.accept(found, generation: generation)
    }
  }

  private func accept(_ found: [Finding]?, generation: Int) {
    guard generation == self.generation else { return }
    isChecking = false
    // A cancelled run reports nothing rather than a partial list, and leaves the previous result
    // standing.
    guard let found else { return }
    geometric = found
  }
}
