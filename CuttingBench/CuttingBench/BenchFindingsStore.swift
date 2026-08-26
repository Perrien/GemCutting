import BenchGeometry
import Observation

// Scoped, not a whole-module import: `FacetKernel` exports a public enum named `Observation`, and a
// type in scope shadows the module of the same name — which is the module `@Observable` expands its
// references against.
import enum FacetKernel.Finding
import struct FacetKernel.Pattern
import struct FacetKernel.Solution
import func FacetKernel.solidFindings
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

  /// The per-tier half, kept between rebuilds (D1). Reset with the document, never pruned by hand.
  private var cache = TierFindingsCache()

  /// `#if DEBUG` readouts only, so the owner can watch the cache and the quiet period work. Cumulative
  /// since this store was made, and never reset: a rising number is easier to read than a ratio.
  private(set) var tierChecksRun = 0
  private(set) var geometricPassesRun = 0
  /// True from the moment an edit arms a deferred pass until that pass starts running or is replaced.
  private(set) var isArmed = false

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
      isArmed = false
      cache = TierFindingsCache()
      return
    }

    structural = structuralFindings(pattern)
    // The kernel's own rule: a pattern whose structure is wrong has no solid to measure geometry
    // against, so the expensive half never starts and the detail says so. The cache is deliberately left
    // alone: a pattern whose structure is wrong will be repaired, and the per-tier results for the tiers
    // before the fault are still correct.
    guard structural.isEmpty else {
      geometric = nil
      isChecking = false
      isArmed = false
      return
    }

    let needed = cache.retain(pattern)

    isChecking = true
    isArmed = true
    running = Task.detached(priority: .userInitiated) { [weak self] in
      await self?.startedRunning(generation: generation)

      let computed = runTierChecks(
        tiers: needed, pattern: pattern, solution: solution, isCancelled: { Task.isCancelled })
      // Whole-solid and never cacheable, so it is recomputed every pass — and skipped on a cancelled
      // one, which has nothing to report it beside.
      let whole = computed == nil ? [] : solidFindings(solution, declaredFacetCount: nil)
      await self?.accept(computed, whole: whole, generation: generation)
    }
  }

  private func startedRunning(generation: Int) {
    guard generation == self.generation else { return }
    isArmed = false
  }

  /// A run from a superseded generation lands nowhere. `nil` is a cancelled run: it reports nothing
  /// rather than a partial list, and leaves the previous result standing and still marked stale.
  ///
  /// **`declaredFacetCount` is deliberately absent**, as it is in `geometricFindings`: the declared count
  /// is the Facet Count card's business, and counting it here would report one fault twice.
  private func accept(_ computed: [String: [Finding]]?, whole: [Finding], generation: Int) {
    guard generation == self.generation else { return }
    isChecking = false
    isArmed = false
    guard let computed else { return }

    for (tier, findings) in computed { cache.record(findings, forTier: tier) }
    tierChecksRun += computed.count
    geometricPassesRun += 1

    // Fail closed. The run computed exactly the tiers `retain` asked for, so the cache is complete here;
    // if it somehow is not, `nil` reads as "no result yet" rather than as a count that is too low.
    guard let kept = cache.complete else {
      geometric = nil
      return
    }
    geometric = kept + whole
  }
}
