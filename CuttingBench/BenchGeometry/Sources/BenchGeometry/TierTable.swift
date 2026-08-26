import FacetKernel
import Foundation

/// Where a tier stands in the solve.
public enum TierRowState: Equatable, Sendable {
  case solved
  /// The tier the partial solve stopped on.
  case stopped
  /// Never attempted: it sits after the stopped tier, or past the playback step the scrubber is at.
  case notReached
}

/// One row of the tier table, every cell already a string.
///
/// Formatted here rather than in the view, so every format is checkable without a window.
public struct TierTableRow: Identifiable, Equatable, Sendable {
  public var tier: String
  public var part: String
  public var angle: String
  /// The same angle without the degree sign, which is what the Angle cell edits while `angle` is what it
  /// displays. Carried on the row so a cell never has to reach back into the draft by label and force-
  /// unwrap a lookup that cannot fail.
  public var angleValue: String
  public var indices: String
  public var meet: String
  public var wheel: String
  /// Whether the tier declares no wheel of its own, so the header's gear is what applies. The cell shows
  /// the effective gear either way — a stop number means nothing without one — and this is only how it
  /// is drawn.
  public var wheelIsInherited: Bool
  /// The named points of this tier's meet, in reading order. Empty for the three meet forms that name
  /// no facet triple. The cell shows these when there are any and `meet` when there are not.
  public var meetPoints: [MeetPointDot]
  public var instructions: String
  public var state: TierRowState
  /// Whether a vertical ray leaks straight out of this tier — a pavilion tier at or below the critical
  /// angle. **Not a finding**: a shallow pavilion may be what the author chose, and a finding must never
  /// blame a complete tier. Always `false` for a tier that is not pavilion.
  public var leaksLight: Bool
  /// How far below the critical angle it sits, as `5.28°`. Empty unless `leaksLight`.
  public var leakShortfall: String

  /// The tier's own label. Decoding rejects a duplicate, so it is unique across a pattern, and an
  /// identity that survives a rebuild is what stops a table from throwing its own state away every time
  /// the pattern is touched.
  public var id: String { tier }

  public init(
    tier: String,
    part: String,
    angle: String,
    angleValue: String,
    indices: String,
    meet: String,
    wheel: String,
    wheelIsInherited: Bool,
    instructions: String,
    state: TierRowState,
    meetPoints: [MeetPointDot] = [],
    leaksLight: Bool = false,
    leakShortfall: String = ""
  ) {
    self.tier = tier
    self.part = part
    self.angle = angle
    self.angleValue = angleValue
    self.indices = indices
    self.meet = meet
    self.wheel = wheel
    self.wheelIsInherited = wheelIsInherited
    self.instructions = instructions
    self.state = state
    self.meetPoints = meetPoints
    self.leaksLight = leaksLight
    self.leakShortfall = leakShortfall
  }
}

/// One row per authored tier, in file order.
///
/// From `draft.tiers` and never from `solid.tiers`: **a tier the solve never reached is still a row the
/// author wrote**, and dropping it would hide the mistake rather than show it. **A tier whose meet is not
/// chosen yet is exactly that row** — it lands on `.notReached` by construction, being absent from the
/// solid's own tiers and not the tier that stopped the solve.
///
/// Empty for a draft with no tiers, which leaves the table showing its headers over nothing.
public func tierTableRows(
  draft: PatternDraft, solid: BenchSolid, light: LightReadout
) -> [TierTableRow] {
  let placed = Set(solid.tiers.map(\.tier))
  // Derived once rather than per row: it is the same pattern for every row, and it is what the meet dots
  // are read against. A meet-less label is absent from it, so it yields no dots — right, because a meet
  // nobody has chosen names no point to draw.
  let displayed = draft.displayPattern

  return draft.tiers.map { spec in
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

    // Read from the Light readout and never worked out again here: a second comparison of the same two
    // angles could disagree with the card about the same tier, and the card and the table marking
    // different rows is worse than either marking the wrong one.
    let leaking = light.leakingRow(spec.tier)

    return TierTableRow(
      tier: spec.tier,
      part: spec.part.rawValue,
      angle: String(format: "%.2f°", spec.angle),
      angleValue: String(format: "%.2f", spec.angle),
      // **Never sorted.** The format permits any order and the order is data: a printed sheet reads
      // `Novice Ash-er`'s eight stops as `12 24 36 48 60 72 84 0`, and a pattern transcribed that way
      // has to render that way.
      indices: spec.indices.map(String.init).joined(separator: " "),
      // `—` is the cell for a tier whose depth has not been decided yet, and it is also what the Meet
      // menu's own label reads.
      meet: spec.meet.map(meetText) ?? "—",
      // The effective gear, which is what makes the neighbouring index stops legible.
      wheel: String(draft.wheel(of: spec)),
      wheelIsInherited: spec.wheel == nil,
      instructions: spec.instructions ?? "",
      state: state,
      meetPoints: meetPointDots(ofTier: spec.tier, pattern: displayed, solid: solid),
      leaksLight: leaking != nil,
      // The card's margin reads `5.28° shallow`; the cell has no room for the word, and the orange symbol
      // beside the figure already says which way it falls. Taken from that one string so the two readings
      // are the same number by construction.
      leakShortfall: leaking?.margin.split(separator: " ").first.map(String.init) ?? "")
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
func percentText(_ value: Double) -> String {
  String(format: "%.2f", value)
}
