import FacetKernel
import Foundation

/// The 2-decimal-place value an angle is written at, and the one place that rounding lives (D7).
///
/// Everything a rescale or a derivation writes passes through here, so the list on screen, the file on
/// disk and the stone in the viewport are all the same numbers.
public func roundedAngle(_ degrees: Double) -> Double {
  (degrees * 100).rounded() / 100
}

/// Degrees of target angle per screen point of drag: 200 points of travel sweeps 10°.
///
/// A build constant with no UI and no preference, tuned by editing the number.
public let tuningDegreesPerDragPoint: Double = 0.05

/// The range a ratio exists in. At or past these bounds the ratio is zero, infinite or negative, and an
/// infinite ratio against a `0.00°` table yields a not-a-number angle, which cannot be encoded to JSON
/// at all — so a target outside them is refused rather than reported.
///
/// A build constant with no UI and no preference, tuned by editing the numbers.
public let tuningTargetRange: ClosedRange<Double> = 0.10...89.90

/// An angle as the tier table's own cell writes it, and as every sentence about one reads it.
func angleText(_ degrees: Double) -> String {
  String(format: "%.2f", degrees)
}

/// Where a drag that started at `base` has got to: rounded to 2 dp and clamped into
/// `tuningTargetRange`.
public func draggedTuningTarget(from base: Double, byPoints points: Double) -> Double {
  let reached = roundedAngle(base + points * tuningDegreesPerDragPoint)
  return Swift.min(Swift.max(reached, tuningTargetRange.lowerBound), tuningTargetRange.upperBound)
}

/// One tier the rescale writes to, formatted for the card. `id` is the label, which is unique.
public struct RescaledTier: Identifiable, Equatable, Sendable {
  public var tier: String
  public var current: String
  public var proposed: String
  /// Already rounded, and the value the commit writes.
  public var proposedAngle: Double
  public var id: String { tier }

  public init(tier: String, current: String, proposed: String, proposedAngle: Double) {
    self.tier = tier
    self.current = current
    self.proposed = proposed
    self.proposedAngle = proposedAngle
  }
}

/// What a rescale would do, before anything is written.
public struct TangentRescale: Equatable, Sendable {
  public var handle: String
  /// Already rounded, and what the ratio was computed from (D7).
  public var target: Double
  public var ratio: Double
  public var ratioText: String
  /// Every tier the transform writes, in file order, the handle among them.
  public var rows: [RescaledTier]

  public init(handle: String, target: Double, ratio: Double, rows: [RescaledTier]) {
    self.handle = handle
    self.target = target
    self.ratio = ratio
    self.ratioText = String(format: "%.4f", ratio)
    self.rows = rows
  }
}

/// What the card lists and what the commit applies, from one function so the two cannot disagree.
///
/// **A label the draft does not carry is a no-op, not a refusal**: `.success` with no rows and a ratio
/// of 1, the way every edit in `DraftEdits.swift` treats a stale selection.
public func tangentRescale(handle tier: String, toAngle target: Double, in draft: PatternDraft)
  -> Result<TangentRescale, DraftRefusal>
{
  guard let handle = draft.tiers.first(where: { $0.tier == tier }) else {
    return .success(TangentRescale(handle: tier, target: target, ratio: 1, rows: []))
  }

  // The handle has to be a tier a ratio can be measured from (D5). The girdle is excluded by its
  // declared `part` so the outline stays whatever the author called the outline; `0.00` and `90.00` are
  // excluded by arithmetic, whatever the part, because the tangent is zero or infinite there.
  guard handle.part != .gdl else {
    return .failure(.tuningHandleIsTheGirdle(tier: tier))
  }
  let handleAngle = roundedAngle(handle.angle)
  guard handleAngle != 0, handleAngle != 90 else {
    return .failure(.tuningHandleHasNoTangent(tier: tier, angle: handleAngle))
  }

  // The ratio is computed from the target already rounded, so the file and the card agree (D7).
  let rounded = roundedAngle(target)
  guard tuningTargetRange.contains(rounded) else {
    return .failure(.tuningTargetOutOfRange(tier: tier, target: rounded))
  }
  let ratio = tan(radians(rounded)) / tan(radians(handleAngle))

  // Crown and pavilion rescale independently, grouped the way the solver already groups sides (D2).
  let rows = draft.tiers
    .filter { onTheSameSide($0.part, as: handle.part) && $0.part != .gdl }
    .filter { roundedAngle($0.angle) != 90 }
    .map { row -> RescaledTier in
      // The handle takes the target exactly; every other row takes the transform. A `0.00°` table comes
      // out `0.00` by arithmetic alone, and is still listed, because the list's job is to state the
      // blast radius (D4).
      let angle = roundedAngle(row.angle)
      let proposed =
        row.tier == tier ? rounded : roundedAngle(degrees(atan(ratio * tan(radians(angle)))))
      return RescaledTier(
        tier: row.tier,
        current: angleText(angle),
        proposed: angleText(proposed),
        proposedAngle: proposed)
    }

  return .success(TangentRescale(handle: tier, target: rounded, ratio: ratio, rows: rows))
}

/// The planner over the field's own text, mirroring how `setting(angle typed:ofTier:in:)` accepts one.
public func tangentRescale(handle tier: String, toTyped typed: String, in draft: PatternDraft)
  -> Result<TangentRescale, DraftRefusal>
{
  guard let target = Double(typed.trimmingCharacters(in: .whitespaces)) else {
    return .failure(.notANumber(field: "\(tier)'s target angle", typed: typed))
  }
  return tangentRescale(handle: tier, toAngle: target, in: draft)
}

/// The edit: the planner's rows, written into the draft and nothing else.
///
/// **No depth, no meet and no ratio is written** (D8) — the ordinary solve derives every depth from the
/// meets as it always did. One `PatternDraft` out, so the whole side is one undo entry (D9).
public func rescaling(handle tier: String, toAngle target: Double, in draft: PatternDraft)
  -> Result<PatternDraft, DraftRefusal>
{
  tangentRescale(handle: tier, toAngle: target, in: draft).map { plan in
    let proposed = Dictionary(
      plan.rows.map { ($0.tier, $0.proposedAngle) }, uniquingKeysWith: { first, _ in first })
    var edited = draft
    for position in edited.tiers.indices {
      if let angle = proposed[edited.tiers[position].tier] {
        edited.tiers[position].angle = angle
      }
    }
    return edited
  }
}

/// The edit over the field's own text.
public func rescaling(handle tier: String, toTyped typed: String, in draft: PatternDraft)
  -> Result<PatternDraft, DraftRefusal>
{
  guard let target = Double(typed.trimmingCharacters(in: .whitespaces)) else {
    return .failure(.notANumber(field: "\(tier)'s target angle", typed: typed))
  }
  return rescaling(handle: tier, toAngle: target, in: draft)
}

/// The two sides the solver already groups by: crown and table are one, pavilion and girdle the other.
private func onTheSameSide(_ part: Part, as other: Part) -> Bool {
  isCrownSide(part) == isCrownSide(other)
}

private func isCrownSide(_ part: Part) -> Bool {
  switch part {
  case .crown, .table: true
  case .pav, .gdl: false
  }
}

private func radians(_ degrees: Double) -> Double { degrees * .pi / 180 }
private func degrees(_ radians: Double) -> Double { radians * 180 / .pi }
