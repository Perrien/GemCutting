import BenchGeometry
import Observation

// Scoped, not a whole-module import: `FacetKernel` exports a public enum named `Observation`, and a
// type in scope shadows the module of the same name — which is the module `@Observable` expands its
// references against. Importing only `Pattern` leaves `Observation` meaning the framework.
import struct FacetKernel.Pattern

/// The bare prism and its mesh, built once for the whole process: every window starts here, before any
/// document is open. A `let` of a `Sendable` type, so a `nonisolated init` can read it.
private let barePrismFrame: PlaybackFrame = {
  let solid = benchSolid(for: nil)
  return PlaybackFrame(solid: solid, mesh: solidMesh(solid))
}()

/// Owns the drawn solid, and playback with it. One solve per pattern — never in a draw call — and one
/// value read by the viewport, the tier table, both measured cards and the findings, so no readout can
/// agree with a broken solid.
///
/// **Playback lives here rather than in a second store.** Two stores each holding a solid is two owners
/// of the displayed stone, and the memo that decides when a rebuild happens is already here.
@Observable @MainActor final class BenchSolidStore {
  /// The whole stone: one solve per pattern, and playback never re-solves.
  private(set) var full: BenchSolid = barePrismFrame.solid
  /// What the viewport draws: the current step's solid, or `full` when playback is off.
  private(set) var solid: BenchSolid = barePrismFrame.solid
  private(set) var mesh: SolidMesh = barePrismFrame.mesh
  /// Bumped on every change to `solid`. Comparing this beats comparing two arrays of vertices.
  private(set) var generation = 0
  /// Bumped when the whole stone is rebuilt, which is the only thing the ghost mesh follows.
  ///
  /// Deliberately **not** bumped by a scrub: the ghost is the finished stone, and scrubbing does not
  /// change it.
  private(set) var fullGeneration = 0

  /// The finished stone's mesh, so a caller can draw its edges without `fullFrame` stopping being
  /// private.
  var fullMesh: SolidMesh { fullFrame.mesh }

  /// `nil` is playback off, which is what a document opens at.
  private(set) var granularity: PlaybackGranularity?
  private(set) var steps: [PlaybackStep] = []
  private(set) var stepIndex = 0
  /// How far the precompute has got, or `nil` when none is running.
  private(set) var progress: PlaybackProgress?
  /// A `#if DEBUG` readout only, so the owner can watch the cache fill.
  var cachedFrameCount: Int { frames.count }

  /// Keyed by `PlaybackStep.id`. The last step is served from `fullFrame` and is never stored here.
  private var frames: [Int: PlaybackFrame] = [:]
  private var fullFrame: PlaybackFrame = barePrismFrame
  /// Double optional on purpose: `nil` is *never built*, `.some(nil)` is *built for no pattern*.
  private var builtPattern: Pattern??
  private var precomputing: Task<Void, Never>?
  /// Bumped per precompute. A frame arriving from a run that has been superseded is discarded.
  private var precomputeGeneration = 0
  /// Frames the current run has delivered. Its own count, not the cache's.
  private var precomputeDone = 0

  /// `nonisolated`, so a `View`'s `@State` default value can construct it: a `View` struct's own
  /// initialization is not main-actor isolated even though its `body` is. Safe because every stored
  /// property has its own default — a window has a solid before its first layout, and that solid is the
  /// bare prism — and every one of their types is `Sendable`.
  nonisolated init() {}

  /// A new document: one solve, and playback back to off.
  ///
  /// **Playback resets on every document change.** A step index means nothing across two patterns, and a
  /// cache built for one is not a stale answer about the other — it is an answer to a different
  /// question.
  func setPattern(_ pattern: Pattern?) {
    guard builtPattern != .some(pattern) else { return }

    cancelPrecompute()
    frames = [:]
    granularity = nil
    steps = []
    stepIndex = 0

    // The whole pattern, always: a part-cut stone is a playback step now, not a truncated solve.
    let solid = benchSolid(for: pattern)
    let frame = PlaybackFrame(solid: solid, mesh: solidMesh(solid))
    full = solid
    fullFrame = frame
    fullGeneration += 1
    show(frame)
    builtPattern = .some(pattern)
  }

  /// Entering playback, leaving it, or changing granularity. `nil` is off — **and choosing Off is also
  /// the cancel** for a precompute in flight, which is why there is no separate Cancel button: the
  /// control that started the wait is the one to hand.
  ///
  /// **Changing granularity keeps the stone where it is**, rounded forward to the nearest whole state of
  /// the new list: a position the two lists share is the same picture, and a part-cut tier finishes
  /// being cut. Off is the only position that puts the whole stone back.
  func setGranularity(_ granularity: PlaybackGranularity?) {
    guard granularity != self.granularity else { return }

    // Read before the list is replaced, because it is a position in the old one.
    let anchor = steps.indices.contains(stepIndex) ? steps[stepIndex] : nil
    cancelPrecompute()
    frames = [:]

    guard let granularity else {
      self.granularity = nil
      steps = []
      stepIndex = 0
      show(fullFrame)
      return
    }

    let steps = playbackSteps(full, granularity: granularity)
    // No sequence to step through, so playback stays off rather than becoming an empty slider.
    guard !steps.isEmpty else {
      self.granularity = nil
      self.steps = []
      stepIndex = 0
      show(fullFrame)
      return
    }

    self.granularity = granularity
    self.steps = steps
    // Entering from off has no position to carry, and the last step's solid is the whole stone, which is
    // already on screen — so the picture does not jump.
    stepIndex = anchor.flatMap { index(carrying: $0, into: steps) } ?? steps.count - 1
    showCurrentStep()
    startPrecompute()
  }

  /// Where a position in one granularity lands in the other. The same state when both lists hold it —
  /// which every tier boundary is — and otherwise the step that completes the tier being cut.
  ///
  /// **Forward, never back**: a granularity change that undid cuts would lose the facets the owner had
  /// just watched arrive, and rounding down from the first facet of a tier would drop the whole tier.
  private func index(carrying anchor: PlaybackStep, into steps: [PlaybackStep]) -> Int? {
    let wanted = anchor.partialTier == nil ? anchor.completeTiers : anchor.completeTiers + 1
    return steps.firstIndex { $0.partialTier == nil && $0.completeTiers == wanted }
  }

  /// A scrub or a chevron. Out-of-range indices clamp rather than trap: the two buttons ask for
  /// `stepIndex ± 1` and the ends of the list are where they stop.
  func setStepIndex(_ index: Int) {
    guard !steps.isEmpty else { return }
    stepIndex = min(max(index, 0), steps.count - 1)
    showCurrentStep()
  }

  /// Draws whatever `stepIndex` points at: the whole stone at the end of the list, the cached frame
  /// where there is one, and otherwise a frame built here and now.
  private func showCurrentStep() {
    guard steps.indices.contains(stepIndex), stepIndex < steps.count - 1 else {
      return show(fullFrame)
    }
    let step = steps[stepIndex]
    if let frame = frames[step.id] {
      return show(frame)
    }

    // **Belt and braces while a precompute is running**: the slider and the chevrons are inert until the
    // bar has gone, so a missing frame should be unreachable there — and a blocking hull is a better
    // answer than drawing the wrong stone. Carrying a position across a granularity change reaches this
    // on purpose, with the cache just cleared and one hull to pay for.
    let frame = playbackFrame(full, at: step)
    frames[step.id] = frame
    show(frame)
  }

  /// The one honest wait: every frame but the last, built off the main thread with the bar up and the
  /// slider inert, so scrubbing afterwards never pays for a hull.
  ///
  /// **Steps are built in order, `0` first**, so the bar advances in cutting order and the preform is the
  /// first thing cached. The main-actor hop per frame is deliberate: it is what makes the bar move rather
  /// than jump from empty to full.
  private func startPrecompute() {
    // The last step is the whole stone, already in `fullFrame`, so it is not built again — and it is the
    // most expensive hull in the list.
    let steps = self.steps.dropLast()
    let full = self.full
    let generation = precomputeGeneration
    // Nothing left to build means nothing to wait for. Unreachable while a placed tier gives at least a
    // preform and one step, and it is what stops the bar from standing at `0/0` with the slider inert.
    guard !steps.isEmpty else {
      progress = nil
      return
    }
    precomputeDone = 0
    progress = PlaybackProgress(done: 0, total: steps.count)
    precomputing = Task.detached(priority: .userInitiated) { [weak self] in
      for step in steps {
        if Task.isCancelled { return }
        let frame = playbackFrame(full, at: step)
        await self?.accept(frame, at: step.id, total: steps.count, generation: generation)
      }
    }
  }

  /// A frame from a superseded run is discarded rather than racing. `progress` goes to `nil` on the last
  /// frame, which is what puts the slider live.
  ///
  /// The run counts its own frames rather than reading `frames.count`: carrying a position across a
  /// granularity change puts one frame in the cache before the run starts, and counting the cache would
  /// then clear the bar a frame early and leave the last one unbuilt.
  private func accept(_ frame: PlaybackFrame, at id: Int, total: Int, generation: Int) {
    guard generation == precomputeGeneration else { return }
    frames[id] = frame
    precomputeDone += 1
    progress = precomputeDone == total ? nil : PlaybackProgress(done: precomputeDone, total: total)
  }

  /// Bumping the generation is what makes an in-flight frame land nowhere: cancellation is checked
  /// between hulls, so a run can still return one after being told to stop.
  private func cancelPrecompute() {
    precomputing?.cancel()
    precomputing = nil
    precomputeGeneration += 1
    progress = nil
  }

  private func show(_ frame: PlaybackFrame) {
    solid = frame.solid
    mesh = frame.mesh
    generation += 1
  }
}
