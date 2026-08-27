/// A tier's index stops as arithmetic modulo its gear: which gears exist, which fold counts a gear can
/// reach, what a seed set expands to, and what an expanded set says about its own symmetry.
///
/// **Integers only** — no framework, no I/O, and nothing about the stone. The file format stores no
/// generator, so folds, mirroring and the seed set are questions asked of a stop list rather than fields
/// read off one.

// MARK: - The gears

/// The eight index gears, ascending. 96 and 120 are the common ones; 84 is what makes 7-fold possible and
/// 72 what makes 9-fold possible, and every one of the eight divides by 4, so a quarter turn is a whole
/// number of stops on all of them.
public let indexGears = [32, 64, 72, 80, 84, 88, 96, 120]

/// The gears a popup offers: the eight, plus `current` if it is not one of them, ascending.
///
/// **The kernel accepts any positive wheel**, so a decoded file can carry 100, and a `Picker` whose
/// selection matches no tag renders blank rather than complaining. `nil` — a tier declaring no gear of its
/// own — adds nothing.
public func gearsOffered(including current: Int?) -> [Int] {
  guard let current, !indexGears.contains(current) else { return indexGears }
  return (indexGears + [current]).sorted()
}

/// The fold counts reachable on a gear: every divisor of `wheel`, ascending, `1` first.
///
/// Generating an n-fold set means stepping by `wheel / n`, so a count that does not divide the gear would
/// land between stops. Empty for a gear that is not positive.
public func foldCounts(onWheel wheel: Int) -> [Int] {
  guard wheel > 0 else { return [] }
  // The largest gear is 120, so the linear scan is 120 steps at worst and nothing cleverer is warranted.
  return (1...wheel).filter { wheel % $0 == 0 }
}

// MARK: - The generator, and its inverse

/// What a tier's stop list says about its own symmetry. **Never stored** — derived from the stops every
/// time, because the file holds no generator and neither does the draft.
public struct TierSymmetry: Equatable, Sendable {
  /// The smallest member of each orbit, ascending. Empty only for a tier with no stops.
  public var seeds: [Int]
  /// At least 1. `1` means no rotation maps the set onto itself, which is the generator being off.
  public var folds: Int
  /// Whether reflecting about index 0 maps the set onto itself.
  public var mirror: Bool

  public init(seeds: [Int], folds: Int, mirror: Bool) {
    self.seeds = seeds
    self.folds = folds
    self.mirror = mirror
  }
}

/// The stop list a seed set generates: **ascending and without duplicates**.
///
/// Mirroring is applied first and the rotation second, which generates the whole dihedral closure — every
/// element of the group is a rotation or a rotation of the reflection, so one pass of each is complete.
///
/// Empty for a gear that is not positive or a fold count below 1. Callers pass a fold count that divides
/// the gear; `setting(folds:ofTier:in:)` refuses one that does not.
public func expandedStops(seeds: [Int], folds: Int, mirror: Bool, wheel: Int) -> [Int] {
  guard wheel > 0, folds >= 1 else { return [] }

  var reflected = seeds.map { reduced($0, wheel: wheel) }
  if mirror {
    reflected += reflected.map { (wheel - $0) % wheel }
  }

  let step = wheel / folds
  var generated: Set<Int> = []
  for stop in reflected {
    for turn in 0..<folds {
      generated.insert((stop + turn * step) % wheel)
    }
  }
  return generated.sorted()
}

/// What a stop list's own symmetry is.
///
/// **An empty list is 1 fold, not mirrored, no seeds** — every rotation maps the empty set onto itself, so
/// the general rule would read the whole gear as the fold count.
public func derivedSymmetry(stops: [Int], wheel: Int) -> TierSymmetry {
  let nothing = TierSymmetry(seeds: [], folds: 1, mirror: false)
  guard wheel > 0 else { return nothing }

  // The reduction is a no-op for every list the app can hold — decoding and the stop setter both keep
  // stops in range — and it is what makes the function total for any input.
  let set = Set(stops.map { reduced($0, wheel: wheel) })
  guard !set.isEmpty else { return nothing }

  // `foldCounts` is ascending and 1 always maps the set onto itself, so the last match is the largest and
  // there is always one.
  let folds =
    foldCounts(onWheel: wheel).last { count in
      Set(set.map { ($0 + wheel / count) % wheel }) == set
    } ?? 1
  let mirror = Set(set.map { (wheel - $0) % wheel }) == set

  // Reusing the expansion is what guarantees the round trip: the seeds shown expand back to exactly the
  // stops the tier has, so nothing the author reads is a set they cannot regenerate.
  var seeds: [Int] = []
  var covered: Set<Int> = []
  for stop in set.sorted() where !covered.contains(stop) {
    seeds.append(stop)
    covered.formUnion(expandedStops(seeds: [stop], folds: folds, mirror: mirror, wheel: wheel))
  }
  return TierSymmetry(seeds: seeds, folds: folds, mirror: mirror)
}

/// A stop brought into `0..<wheel`, negatives included. `wheel` is positive at every call site.
private func reduced(_ stop: Int, wheel: Int) -> Int {
  ((stop % wheel) + wheel) % wheel
}

/// Whether flipping a tier's mirroring would change its stops at all — that is, whether the Mirror
/// control has anything to do.
///
/// **Mirroring is a question asked of the stop list, not a stored field**, so unchecking it regenerates
/// the tier from its own seeds without the reflection. On a set that is already mirror-symmetric by
/// rotation alone — every 8-fold tier seeded at 0, which is most of them — that regenerates the very same
/// stops, the derived answer comes back `true`, and the control springs straight back looking broken.
/// There is nothing the author can do with it, so it is offered disabled instead of as an edit that
/// undoes itself.
///
/// Both directions are asked the one question rather than special-cased, which is also what makes the
/// empty tier fall out correctly: no seeds generate nothing whichever way the flag is set, so the control
/// is inert there too.
///
/// **Takes the derived symmetry rather than the stops**, so a caller that has already derived it — the
/// tier table's row build, the only caller — does not pay for a second derivation. The stops themselves
/// are not needed: `derivedSymmetry` guarantees the seeds expand back to exactly the list they came from.
public func mirrorIsEditable(_ symmetry: TierSymmetry, wheel: Int) -> Bool {
  guard wheel > 0, !symmetry.seeds.isEmpty else { return false }
  let asIs = expandedStops(
    seeds: symmetry.seeds, folds: symmetry.folds, mirror: symmetry.mirror, wheel: wheel)
  let flipped = expandedStops(
    seeds: symmetry.seeds, folds: symmetry.folds, mirror: !symmetry.mirror, wheel: wheel)
  return asIs != flipped
}
