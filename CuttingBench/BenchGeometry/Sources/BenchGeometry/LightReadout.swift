import FacetKernel
import Foundation

/// One pavilion tier's authored angle against the critical angle.
public struct PavilionAngleRow: Identifiable, Equatable, Sendable {
  public var tier: String
  /// `47.60°`.
  public var angle: String
  /// `7.11° clear`, or `5.28° shallow` when it leaks.
  public var margin: String
  public var leaks: Bool

  /// The tier's own label, unique across a pattern by decoding, so a `ForEach` keeps identity.
  public var id: String { tier }

  public init(tier: String, angle: String, margin: String, leaks: Bool) {
    self.tier = tier
    self.angle = angle
    self.margin = margin
    self.leaks = leaks
  }
}

/// Whether a ray can be traced, or the sentence saying why not.
public enum ProbeAvailability: Equatable, Sendable {
  case available
  case unavailable(String)
}

/// The Light card's contents.
public struct LightSummary: Equatable, Sendable {
  /// `40.49°`.
  public var criticalAngle: String
  /// `1.54`, or `1.30 (override)` while the debug field holds a number.
  public var refractiveIndex: String
  /// Every tier whose `part` is `.pav`, in file order — never sorted by angle, because tier order is
  /// data.
  public var pavilionTiers: [PavilionAngleRow]
  /// The labels of the tiers that leak, for the tier table's Angle column. A set, because the table looks
  /// each row up rather than walking the list.
  public var leakingTiers: Set<String>
  public var probe: ProbeAvailability

  public init(
    criticalAngle: String,
    refractiveIndex: String,
    pavilionTiers: [PavilionAngleRow],
    leakingTiers: Set<String>,
    probe: ProbeAvailability
  ) {
    self.criticalAngle = criticalAngle
    self.refractiveIndex = refractiveIndex
    self.pavilionTiers = pavilionTiers
    self.leakingTiers = leakingTiers
    self.probe = probe
  }
}

/// Whether there is a pattern whose light behaviour can be reported, or the sentence saying why not.
public enum LightReadout: Equatable, Sendable {
  case unavailable(String)
  case measured(LightSummary)
}

extension LightReadout {
  /// The pavilion row for a tier, or `nil` when that tier does not leak. The tier table's one way in.
  public func leakingRow(_ tier: String) -> PavilionAngleRow? {
    guard case .measured(let summary) = self, summary.leakingTiers.contains(tier) else {
      return nil
    }
    return summary.pavilionTiers.first { $0.tier == tier }
  }
}

/// The limit of the check, in one place so no view can soften it. A shallow pavilion definitely leaks; a
/// pavilion that clears the critical angle has been told nothing about how it performs.
public let lightCaveat =
  "A marked tier leaks a vertical ray. Nothing here says a stone performs well."

/// Why a ray cannot be traced through a solid the pattern's own planes do not bound. One constant,
/// because the card says it where the toggle would be and a trace says it if one is asked for anyway,
/// and the sentence must not depend on which of the two answered.
let probeNeedsClosedStone =
  "The probe needs a closed stone: the pattern's own planes do not bound one yet."

/// The override's own number, or `nil` when the field does not hold one. One parse rule, read both for
/// the index itself and for the `(override)` suffix, so the figure and the label saying where it came
/// from can never disagree.
///
/// An empty field is the normal case, not an error: it means the pattern's own declared index.
func overrideRefractiveIndex(_ text: String) -> Double? {
  let typed = text.trimmingCharacters(in: .whitespaces)
  guard let parsed = Double(typed), parsed > 0 else { return nil }
  return parsed
}

/// The refractive index both readouts use: the debug override's number when it parses, the pattern's own
/// otherwise, `nil` with no pattern.
///
/// **One function, because a card and a traced ray disagreeing about which stone is on screen is worse
/// than either being wrong.**
///
/// A number at or below `1` is passed through rather than rejected: `criticalAngleDegrees(ri:)` answers
/// that case honestly with `90°`, so every pavilion tier marking is the right answer for a medium no
/// denser than air.
public func effectiveRefractiveIndex(pattern: Pattern?, override: String) -> Double? {
  guard let pattern else { return nil }
  return overrideRefractiveIndex(override) ?? pattern.ri
}

/// The Light card's contents.
///
/// **No solve is needed and none is done**: this is arithmetic over the authored angles and the authored
/// refractive index, which is why it reports for a part-cut stone where the Metrics card can only give a
/// reason. The probe, which does need a solid, carries its own precondition inside the same card.
public func lightReadout(
  pattern: Pattern?, solid: BenchSolid, riOverride: String
) -> LightReadout {
  guard let pattern,
    let ri = effectiveRefractiveIndex(pattern: pattern, override: riOverride)
  else {
    return .unavailable(noPatternOpen)
  }

  // The kernel's own function, never a second `asin(1 / ri)` here: a second implementation of one check
  // can agree with a broken one.
  let critical = criticalAngleDegrees(ri: ri)

  var rows: [PavilionAngleRow] = []
  var leaking: Set<String> = []
  // Only pavilion tiers. The check asks whether a vertical ray reflects off the pavilion, and the
  // pavilion is the only place that ray lands — a shallow crown or girdle tier is not a leak.
  for spec in pattern.tiers where spec.part == .pav {
    // At or below, not below: the kernel lets a ray out at exactly the critical angle, so a tier sitting
    // exactly there must mark, or the table and a traced path would disagree on the hardest case to
    // explain.
    let leaks = spec.angle <= critical
    rows.append(
      PavilionAngleRow(
        tier: spec.tier,
        angle: String(format: "%.2f°", spec.angle),
        // Neither form ever carries a minus sign: the word says which side of the angle it is on.
        margin: leaks
          ? String(format: "%.2f° shallow", critical - spec.angle)
          : String(format: "%.2f° clear", spec.angle - critical),
        leaks: leaks))
    // Built in the same pass as the rows, so the set and the list can never disagree.
    if leaks { leaking.insert(spec.tier) }
  }

  let usedOverride = overrideRefractiveIndex(riOverride) != nil

  return .measured(
    LightSummary(
      criticalAngle: String(format: "%.2f°", critical),
      refractiveIndex: String(format: "%.2f", ri) + (usedOverride ? " (override)" : ""),
      pavilionTiers: rows,
      leakingTiers: leaking,
      // The drawn solid already carries the answer, asked once when it was built, so this is free and
      // needs no second closure test (ADR-0004).
      probe: solid.includesRough ? .unavailable(probeNeedsClosedStone) : .available))
}
