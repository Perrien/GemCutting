import FacetKernel
import Foundation

/// The two granularities playback runs at (U5). No third: an animated facet arrival is deferred to the
/// ticket `Chore-Incremental-Half-Space-Clipper`, and there is no auto-play (D15).
public enum PlaybackGranularity: String, CaseIterable, Hashable, Sendable {
  case tier
  case facet
}

/// One position in the sequence: what has been cut at this point.
///
/// **A count of complete tiers plus the stops of the tier being cut, never a plane count** (D3): the
/// solver appends a tier's planes in the file's own stop order and facet playback runs in ascending
/// stop order, so a step is a set rather than a prefix.
public struct PlaybackStep: Equatable, Sendable, Identifiable {
  /// Solved tiers complete at this step. `0` is the bare preform (D5).
  public var completeTiers: Int
  /// The tier part-way cut, or `nil` at a tier boundary.
  public var partialTier: String?
  /// `partialTier`'s stops cut so far, **ascending**. Empty when `partialTier` is `nil`.
  public var partialStops: [Int]
  /// What the scrubber reads. Formatted here so the format is checkable without a window.
  public var label: String
  /// Position in the list, from `0`.
  public var id: Int

  public init(
    completeTiers: Int,
    partialTier: String? = nil,
    partialStops: [Int] = [],
    label: String,
    id: Int
  ) {
    self.completeTiers = completeTiers
    self.partialTier = partialTier
    self.partialStops = partialStops
    self.label = label
    self.id = id
  }
}

/// How far a precompute has got (D13).
public struct PlaybackProgress: Equatable, Sendable {
  public var done: Int
  public var total: Int

  public init(done: Int, total: Int) {
    self.done = done
    self.total = total
  }
}

/// One cached step: the solid and the mesh drawn for it.
public struct PlaybackFrame: Sendable {
  public var solid: BenchSolid
  public var mesh: SolidMesh

  public init(solid: BenchSolid, mesh: SolidMesh) {
    self.solid = solid
    self.mesh = mesh
  }
}

/// Every position playback can be scrubbed to, in cutting order, step `0` first.
///
/// **Empty when the solve placed no tiers**, which is what leaves the granularity control disabled:
/// there is no sequence to step through.
public func playbackSteps(
  _ solid: BenchSolid,
  granularity: PlaybackGranularity
) -> [PlaybackStep] {
  guard !solid.tiers.isEmpty else { return [] }

  // Every stop of every placed tier, which is what a facet step counts against.
  let total = solid.tiers.reduce(0) { $0 + $1.indices.count }

  // The preform, at both granularities. A list starting at one tier would have no way to show it (D5).
  var steps = [PlaybackStep(completeTiers: 0, label: "rough · nothing cut", id: 0)]

  switch granularity {
  case .tier:
    for n in 1...solid.tiers.count {
      steps.append(
        PlaybackStep(
          completeTiers: n,
          label: "\(solid.tiers[n - 1].tier) · tier \(n)/\(solid.tiers.count)",
          id: n))
    }

  case .facet:
    var cut = 0
    for (k, tier) in solid.tiers.enumerated() {
      // **Ascending, whatever order the file wrote them in** (D4). A derived value inside a step: the
      // tier table's Indices cell reads `pattern.tiers`, so the file's own order still prints.
      let sorted = tier.indices.sorted()
      // A tier with no stops has no facet to step to. It cannot come out of a solve today; skipping it
      // is what keeps the range below well formed rather than a crash if one ever does.
      guard !sorted.isEmpty else { continue }
      for j in 1...sorted.count {
        cut += 1
        // The last stop of a tier completes it, and that step is that tier's tier-granularity step
        // apart from its label — which is what makes the two lists two views of one sequence.
        let completesTier = j == sorted.count
        steps.append(
          PlaybackStep(
            completeTiers: completesTier ? k + 1 : k,
            partialTier: completesTier ? nil : tier.tier,
            partialStops: completesTier ? [] : Array(sorted.prefix(j)),
            label: "\(tier.tier) · facet \(j)/\(sorted.count) · \(cut)/\(total)",
            id: steps.count))
      }
    }
  }

  return steps
}

/// The solid at one playback step, re-expanded from the whole solve's own tiers.
///
/// **Nothing is solved here** (D2). Each tier's depth is already in `SolvedTier.d`, and `planes(of:)`
/// is the identical expansion the solver's own `place` performs, so a prefix's planes are the whole
/// solve's planes for those tiers. Depths do not shift, because a meet may only name an earlier tier —
/// a forward reference is a reported failure, never something the solver resolves.
///
/// Returns `full` unchanged when there is no solution to prefix, which is the no-pattern case.
public func benchSolid(_ full: BenchSolid, at step: PlaybackStep) -> BenchSolid {
  guard let solution = full.solution else { return full }

  // The part-cut tier is the last of the prefix, and its `indices` is the ascending prefix of its own
  // stops. **A derived value, never written back**: the tier table's Indices cell reads
  // `pattern.tiers`, so the file's own stop order still prints (D4).
  var tiers = Array(solution.tiers.prefix(step.completeTiers))
  if let partialTier = step.partialTier,
    var cutting = solution.tiers.first(where: { $0.tier == partialTier })
  {
    cutting.indices = step.partialStops
    tiers.append(cutting)
  }

  // Named `cutPlanes`, not `planes`: a local named `planes` would shadow the kernel's `planes(of:)` and
  // the call below would not compile.
  var cutPlanes: [Plane] = []
  var owner: [Int: (tier: String, index: Int)] = [:]
  for tier in tiers {
    for (stop, plane) in zip(tier.indices, planes(of: tier)) {
      owner[cutPlanes.count] = (tier: tier.tier, index: stop)
      cutPlanes.append(plane)
    }
  }

  // The stop belongs to the last step alone (D9): earlier in the sequence the tier that stopped the
  // solve has not been reached, and marking it stopped would claim a failure playback has not got to.
  let isLast = step.partialTier == nil && step.completeTiers == solution.tiers.count

  return benchSolid(
    over: Solution(
      tiers: tiers,
      planes: cutPlanes,
      planeOwner: owner,
      // Rough-free (ADR-0004). The rough is merged into what is drawn by `benchSolid(over:)`, and only
      // while these planes fail to close.
      polytope: intersectHalfSpaces(cutPlanes)),
    stoppedAtTier: isLast ? full.stoppedAtTier : nil,
    stoppedReason: isLast ? full.stoppedReason : nil)
}

/// One step's solid and its mesh. The precompute calls this off the main thread; every value it
/// touches is `Sendable`.
public func playbackFrame(_ full: BenchSolid, at step: PlaybackStep) -> PlaybackFrame {
  let solid = benchSolid(full, at: step)
  return PlaybackFrame(solid: solid, mesh: solidMesh(solid))
}
