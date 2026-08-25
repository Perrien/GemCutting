import FacetKernel
import Foundation

/// Where a tier stands in the solve.
public enum TierRowState: Equatable, Sendable {
  case solved
  /// The tier the partial solve stopped on.
  case stopped
  /// Never attempted: it sits after the stopped tier, or past the debug tier limit.
  case notReached
}

/// One row of the tier table, every cell already a string.
///
/// Formatted here rather than in the view, so every format is checkable without a window.
public struct TierTableRow: Identifiable, Equatable, Sendable {
  public var tier: String
  public var part: String
  public var angle: String
  public var indices: String
  public var meet: String
  public var wheel: String
  /// Whether the tier declares no wheel of its own, so the header's gear is what applies. The cell shows
  /// the effective gear either way — a stop number means nothing without one — and this is only how it
  /// is drawn.
  public var wheelIsInherited: Bool
  public var instructions: String
  public var state: TierRowState

  /// The tier's own label. Decoding rejects a duplicate, so it is unique across a pattern, and an
  /// identity that survives a rebuild is what stops a table from throwing its own state away every time
  /// the pattern is touched.
  public var id: String { tier }

  public init(
    tier: String,
    part: String,
    angle: String,
    indices: String,
    meet: String,
    wheel: String,
    wheelIsInherited: Bool,
    instructions: String,
    state: TierRowState
  ) {
    self.tier = tier
    self.part = part
    self.angle = angle
    self.indices = indices
    self.meet = meet
    self.wheel = wheel
    self.wheelIsInherited = wheelIsInherited
    self.instructions = instructions
    self.state = state
  }
}

/// One row per authored tier, in file order.
///
/// From `pattern.tiers` and never from `solid.tiers`: **a tier the solve never reached is still a row
/// the author wrote**, and dropping it would hide the mistake rather than show it.
///
/// Empty for no pattern, which leaves the table showing its headers over nothing.
public func tierTableRows(pattern: Pattern?, solid: BenchSolid) -> [TierTableRow] {
  guard let pattern else { return [] }
  let placed = Set(solid.tiers.map(\.tier))

  return pattern.tiers.map { spec in
    // The tier that stopped the solve is by construction absent from the solid's own tiers, so testing
    // for it first is belt and braces rather than a real ambiguity.
    let state: TierRowState =
      if spec.tier == solid.stoppedAtTier {
        .stopped
      } else if placed.contains(spec.tier) {
        .solved
      } else {
        .notReached
      }

    return TierTableRow(
      tier: spec.tier,
      part: spec.part.rawValue,
      angle: String(format: "%.2f°", spec.angle),
      // **Never sorted.** The format permits any order and the order is data: a printed sheet reads
      // `Novice Ash-er`'s eight stops as `12 24 36 48 60 72 84 0`, and a pattern transcribed that way
      // has to render that way.
      indices: spec.indices.map(String.init).joined(separator: " "),
      meet: meetText(spec.meet),
      // The effective gear, which is what makes the neighbouring index stops legible.
      wheel: String(pattern.wheel(of: spec)),
      wheelIsInherited: spec.wheel == nil,
      instructions: spec.instructions ?? "",
      state: state)
  }
}

/// A meet as one line of text, in the kernel's own notation for a facet. Recurses through a
/// `fraction`'s two endpoints, either of which is a vertex or a `tcp`.
public func meetText(_ meet: Meet) -> String {
  switch meet {
  case .size, .tcp, .girdle:
    meet.kindName
  case .vertex(let facets):
    // In the file's own order. Which facets a meet names, and in what order, is the author's statement
    // about the stone and not something to normalise.
    facets.map { "\($0.tier)@\($0.index)" }.joined(separator: " · ")
  case .fraction(let from, let percent, let to):
    "\(percentText(percent))% from \(meetText(from)) to \(meetText(to))"
  }
}

/// Non-localised, which is what `String(format:)` without a locale gives.
private func percentText(_ value: Double) -> String {
  String(format: "%.2f", value)
}
