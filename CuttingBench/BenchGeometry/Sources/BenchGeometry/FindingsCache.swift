import FacetKernel

/// How long a committed edit has to stand still before the expensive half of validation runs (D4).
///
/// **One build constant, not a preference.** A hidden setting that changes when a check runs is worse
/// than editing a number here.
public let geometricQuietPeriod: Duration = .milliseconds(250)

/// How many leading tiers of `previous` a move to `next` leaves untouched — the count of cached
/// per-tier results that survive the edit.
///
/// **Tier *k*'s named-point result depends on the specs of tiers 0…*k* and on nothing after them**, so
/// the answer is the first position at which the two tier lists differ. The solve has the same prefix
/// property: it places tiers in file order and stops at the first failure, so nothing later can change
/// whether an earlier tier placed.
///
/// A header field that can move geometry keeps nothing: the gear enters every plane normal and the
/// girdle target enters every girdle meet's depth. `ri`, `state`, `name`, `designer`, `notes` and
/// `formatVersion` reach neither the solve nor validation, so they keep everything.
public func survivingTierPrefix(from previous: Pattern?, to next: Pattern) -> Int {
  guard let previous,
    previous.wheel == next.wheel,
    previous.girdleTargetFraction == next.girdleTargetFraction
  else { return 0 }

  var n = 0
  while n < previous.tiers.count, n < next.tiers.count, previous.tiers[n] == next.tiers[n] {
    n += 1
  }
  return n
}

/// The expensive half of validation, kept per tier between rebuilds (D1).
///
/// **Not `Equatable`**: it is a scratch pad whose contents are derived, and nothing compares two of them.
public struct TierFindingsCache: Sendable {
  /// The pattern the kept entries were computed for, or `nil` before the first `retain`.
  public private(set) var pattern: Pattern?
  /// Tier label to that tier's named-point findings. Only tiers actually checked appear.
  public private(set) var perTier: [String: [Finding]] = [:]

  public init() {}

  /// Drops every entry the move to `next` could have changed, and returns the tiers still needing a
  /// check, **in cutting order**.
  ///
  /// Entries for labels outside the surviving prefix go, which is also what handles a rename: the
  /// renamed tier differs at its own position, so it and everything after it are dropped along with the
  /// stale entry under the old label.
  public mutating func retain(_ next: Pattern) -> [String] {
    let kept = survivingTierPrefix(from: pattern, to: next)
    let survivors = Set(next.tiers.prefix(kept).map(\.tier))
    perTier = perTier.filter { survivors.contains($0.key) }
    pattern = next
    return next.tiers.dropFirst(kept).map(\.tier)
  }

  public mutating func record(_ findings: [Finding], forTier tier: String) {
    perTier[tier] = findings
  }

  /// Every kept per-tier finding in cutting order, or `nil` while any tier of the held pattern has no
  /// entry. **A short cache is not a result**: reporting one would undercount.
  public var complete: [Finding]? {
    guard let pattern else { return nil }
    var all: [Finding] = []
    for spec in pattern.tiers {
      guard let found = perTier[spec.tier] else { return nil }
      all.append(contentsOf: found)
    }
    return all
  }
}

/// The named-point check over just the tiers that need it, off the main thread.
///
/// **Returns `nil` when `isCancelled` fired part-way** (D7), discarding the tiers already done — the
/// same rule `geometricFindings` follows, and cancellation almost always lands inside the quiet period
/// before any tier has run.
///
/// A label the solution does not carry yields `[]`, which `namedPointFindings` already does for an
/// unsolved tier: a tier the solve never reached has no intermediate solid to be a corner of.
public func runTierChecks(
  tiers: [String],
  pattern: Pattern,
  solution: Solution,
  isCancelled: () -> Bool = { false }
) -> [String: [Finding]]? {
  var computed: [String: [Finding]] = [:]
  for tier in tiers {
    if isCancelled() { return nil }
    computed[tier] = namedPointFindings(inTier: tier, of: pattern, solution)
  }
  return computed
}
