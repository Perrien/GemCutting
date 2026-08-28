import FacetKernel
import Foundation

/// One tier as it stands while being authored: everything `TierSpec` carries, with the meet optional.
public struct DraftTier: Identifiable, Equatable, Sendable {
  public var tier: String
  public var part: Part
  public var angle: Double
  public var indices: [Int]
  public var wheel: Int?
  /// `nil` is a tier whose depth has not been decided yet — the normal condition of authoring, and the
  /// one thing `TierSpec` cannot hold, because the format's meet is exactly five complete forms with no
  /// "undecided" among them (ADR-0003).
  public var meet: Meet?
  public var instructions: String?

  /// The tier's own label, as `TierTableRow`'s is. Unique across a draft because a rename that would
  /// duplicate one is refused.
  public var id: String { tier }

  public init(
    tier: String,
    part: Part,
    angle: Double,
    indices: [Int],
    wheel: Int? = nil,
    meet: Meet? = nil,
    instructions: String? = nil
  ) {
    self.tier = tier
    self.part = part
    self.angle = angle
    self.indices = indices
    self.wheel = wheel
    self.meet = meet
    self.instructions = instructions
  }

  public init(_ spec: TierSpec) {
    self.init(
      tier: spec.tier,
      part: spec.part,
      angle: spec.angle,
      indices: spec.indices,
      wheel: spec.wheel,
      meet: spec.meet,
      instructions: spec.instructions)
  }

  /// `nil` when no meet has been chosen.
  public var spec: TierSpec? {
    guard let meet else { return nil }
    return TierSpec(
      tier: tier,
      part: part,
      angle: angle,
      indices: indices,
      wheel: wheel,
      meet: meet,
      instructions: instructions)
  }
}

/// A pattern part-way through being authored. The app's own type and never the kernel's: which fields may
/// be absent is UI policy rather than geometry (ADR-0003).
public struct PatternDraft: Equatable, Sendable {
  public var formatVersion: Int
  public var name: String
  public var state: PatternState
  public var wheel: Int
  public var ri: Double
  public var girdleTargetFraction: Double?
  public var designer: String
  public var notes: String
  public var tiers: [DraftTier]

  /// A new document. 96 is the common index gear and 1.54 is quartz; both are visible and editable in the
  /// Pattern card, so a default that does not suit costs one edit.
  public static let empty = PatternDraft(
    formatVersion: 1,
    name: "",
    state: .inProgress,
    wheel: 96,
    ri: 1.54,
    girdleTargetFraction: nil,
    designer: "",
    notes: "",
    tiers: [])

  public init(
    formatVersion: Int,
    name: String,
    state: PatternState,
    wheel: Int,
    ri: Double,
    girdleTargetFraction: Double?,
    designer: String,
    notes: String,
    tiers: [DraftTier]
  ) {
    self.formatVersion = formatVersion
    self.name = name
    self.state = state
    self.wheel = wheel
    self.ri = ri
    self.girdleTargetFraction = girdleTargetFraction
    self.designer = designer
    self.notes = notes
    self.tiers = tiers
  }

  public init(_ pattern: Pattern) {
    self.init(
      formatVersion: pattern.formatVersion,
      name: pattern.name,
      state: pattern.state,
      wheel: pattern.wheel,
      ri: pattern.ri,
      girdleTargetFraction: pattern.girdleTargetFraction,
      designer: pattern.designer,
      notes: pattern.notes,
      tiers: pattern.tiers.map(DraftTier.init))
  }

  /// The pattern the display solves: the tiers that have a meet, in file order, and `nil` when that leaves
  /// none.
  ///
  /// **Never sorted, never regrouped.** Tier order is data, and normalising it for tidiness can turn a
  /// cuttable pattern into one that cannot be cut at all.
  public var displayPattern: Pattern? {
    let specs = tiers.compactMap(\.spec)
    guard !specs.isEmpty else { return nil }
    return pattern(with: specs)
  }

  /// The pattern the file is written from. Refuses rather than dropping anything: the format has no
  /// "undecided" meet, so saving cannot dodge the choice.
  public func completePattern() -> Result<Pattern, DraftRefusal> {
    guard !tiers.isEmpty else { return .failure(.noTiers) }
    let missing = tiers.filter { $0.meet == nil }.map(\.tier)
    guard missing.isEmpty else { return .failure(.tiersWithoutMeet(missing)) }
    return .success(pattern(with: tiers.compactMap(\.spec)))
  }

  /// Where a label sits, or `nil` for a label the draft does not carry.
  public func position(ofTier tier: String) -> Int? {
    tiers.firstIndex { $0.tier == tier }
  }

  /// The gear a tier is cut on: its own if it declares one, otherwise the draft's. The same rule as
  /// `Pattern.wheel(of:)`.
  public func wheel(of tier: DraftTier) -> Int {
    tier.wheel ?? wheel
  }

  /// The header fields around a set of specs. One place, so the two conversions cannot differ about
  /// anything but which tiers they carry.
  private func pattern(with specs: [TierSpec]) -> Pattern {
    Pattern(
      formatVersion: formatVersion,
      name: name,
      state: state,
      wheel: wheel,
      ri: ri,
      girdleTargetFraction: girdleTargetFraction,
      designer: designer,
      notes: notes,
      tiers: specs)
  }
}

/// One edit, as the change itself. Every editable cell hands one of these up to the window's funnel.
public typealias DraftChange = (PatternDraft) -> Result<PatternDraft, DraftRefusal>

/// An edit the app will not complete, and why. Every case names the element at fault.
///
/// It lives here rather than beside the edit functions because `completePattern()` is its first user and
/// an enum's cases cannot be added to from a second file.
public enum DraftRefusal: Error, Equatable, Sendable {
  case tierReferenced(tier: String, by: [String])
  case stopReferenced(tier: String, index: Int, by: [String])
  case moveWouldPointForward(tier: String, named: String)
  case duplicateTierLabel(String)
  case emptyTierLabel
  case indexOutOfRange(tier: String, index: Int, wheel: Int)
  case indicesNotWholeNumbers(typed: String)
  /// A fold count that does not divide the tier's effective gear, with the counts that gear does reach.
  case foldsNotADivisor(tier: String, folds: Int, wheel: Int)
  case notANumber(field: String, typed: String)
  case girdleTargetNotPositive(typed: String)
  case tiersWithoutMeet([String])
  case noTiers
  /// The `finished` transition declined, with each finding as its own sentence (D10).
  case finishedWithFindings([String])
  /// The `finished` transition declined because the solve does not reach the end of the pattern (D11).
  case finishedWithSolveStoppedShort(tier: String, reason: String)
  /// A click on a facet of the rough, which a meet may never name.
  case roughFacetNotNameable(name: String)
  /// A corner no three cut facets name — every candidate through it is a facet of the rough.
  case roughDerivedPoint(tier: String)
  /// Three named planes that pin no point.
  case pickedFacetsDoNotMeet(tier: String)
  /// A typed percentage outside 0...100, which the file format rejects at decode.
  case percentNotInRange(tier: String, typed: String)
  /// A girdle tier offered as the tier a rescale measures its ratio from. The outline never moves (D3).
  case tuningHandleIsTheGirdle(tier: String)
  /// A handle at `0.00°` or `90.00°`, where the ratio is undefined or infinite (D5).
  case tuningHandleHasNoTangent(tier: String, angle: Double)
  /// A target at or past the bounds a ratio exists in. **The one value refused for being what it is**,
  /// because outside them the arithmetic yields a not-a-number angle, which cannot be encoded (D6).
  case tuningTargetOutOfRange(tier: String, target: Double)
  /// A gear a quarter turn cannot be expressed on, naming the tier that carries it — or `nil` for the
  /// pattern's own gear. Fractional stops are forbidden and rounding one would move a facet (D17).
  case quarterTurnGearNotDivisible(tier: String?, wheel: Int)
  /// Two picked points at the same place on the aimed facet's azimuth, so they name no tilt (D24).
  case derivationPointsCoincide(tier: String, numbers: DerivationNumbers)
  /// Two picked points implying a plane that faces the wrong way for the tier's declared part, carrying
  /// the signed angle the arithmetic produced before rejection (D24).
  case derivedAngleContradictsPart(tier: String, part: Part, angle: Double, numbers: DerivationNumbers)
  /// A sibling facet of the same tier takes the depth, so the facet the author aimed stops short. **The
  /// one derivation failure refused rather than reported** (D25): the kernel reports nothing for it,
  /// because which facet arrives is determined rather than chosen.
  case siblingFacetTakesTheDepth(
    tier: String, aimed: Int, arrives: Int, angle: Double, aimedDot: Double, arrivingDot: Double)

  /// The sentence the alert shows and the log line records. One wording, so the two cannot disagree.
  public var message: String {
    switch self {
    case .tierReferenced(let tier, let by):
      "\(tier) cannot be deleted: its facets are named by \(list(by)). "
        + "Re-aim or remove those meets first."
    case .stopReferenced(let tier, let index, let by):
      "Index stop \(index) cannot be removed from \(tier): it is named by \(list(by)). "
        + "Re-aim or remove those meets first."
    case .moveWouldPointForward(let tier, let named):
      "\(tier) cannot move there: \(tier)'s meet names \(named), "
        + "and a meet may only name a tier cut earlier."
    case .duplicateTierLabel(let label):
      "There is already a tier called \(label)."
    case .emptyTierLabel:
      "A tier needs a label."
    case .indexOutOfRange(let tier, let index, let wheel):
      "Index stop \(index) is outside 0...\(wheel - 1) on \(tier)'s gear of \(wheel)."
    case .indicesNotWholeNumbers(let typed):
      "\"\(typed)\" is not a list of whole index stops."
    case .foldsNotADivisor(let tier, let folds, let wheel):
      // The reachable counts are computed rather than spelled, so the sentence cannot drift from what
      // `setting(folds:ofTier:in:)` actually accepts.
      "\(folds)-fold does not divide \(tier)'s gear of \(wheel). "
        + "On \(wheel) the fold counts are "
        + "\(foldCounts(onWheel: wheel).map(String.init).joined(separator: ", "))."
    case .notANumber(let field, let typed):
      "\"\(typed)\" is not a number for \(field)."
    case .girdleTargetNotPositive:
      // The default is read from the kernel rather than spelled here, so the sentence cannot drift from
      // the number the file actually falls back to.
      "A girdle target has to be greater than zero. "
        + "Leave the field empty for the default of \(Pattern.defaultGirdleTargetFraction)."
    case .tiersWithoutMeet(let tiers):
      // No "cannot be saved" prefix: this case now answers a `finished` transition as well as a save, and
      // `DraftSaveError.errorDescription` already says "This pattern cannot be saved yet." above it.
      "\(list(tiers)) \(tiers.count == 1 ? "has" : "have") no meet. "
        + "Choose one for each, or delete the tier."
    case .noTiers:
      "This pattern has no tiers yet."
    case .finishedWithFindings(let sentences):
      // A bulleted list rather than `list(_:)`'s commas: these are whole sentences, and comma-joining
      // sentences is unreadable at four of them.
      "This pattern cannot be marked finished yet — "
        + "\(sentences.count) \(sentences.count == 1 ? "finding" : "findings") fired:\n"
        + sentences.map { "• \($0)" }.joined(separator: "\n")
    case .finishedWithSolveStoppedShort(let tier, let reason):
      "This pattern cannot be marked finished: the solve stops at \(tier) — \(reason). "
        + "A tier that will not place has no facets on the stone."
    case .roughFacetNotNameable(let name):
      "\(name) is part of the rough, not the stone. "
        + "A meet may only name facets the pattern cuts."
    case .roughDerivedPoint(let tier):
      "\(tier)'s meet cannot be aimed at that point: naming it would need a facet of the rough, "
        + "which is a build constant with no design meaning."
    case .pickedFacetsDoNotMeet(let tier):
      "\(tier)'s three named facets do not meet at a point."
    case .percentNotInRange(let tier, let typed):
      "\"\(typed)\" is not a percentage between 0 and 100 for \(tier)'s meet."
    case .tuningHandleIsTheGirdle(let tier):
      "\(tier) is a girdle tier: its facets set the outline, and rescaling a side never moves the "
        + "outline. Tune from a crown or pavilion tier instead."
    case .tuningHandleHasNoTangent(let tier, let angle):
      // The bounds are read from the range the planner actually enforces, so the sentence cannot drift
      // from the targets it accepts.
      "\(tier) cannot be the tier you tune from: at \(angleText(angle))° there is no ratio to "
        + "measure. Tune from a tier between \(angleText(tuningTargetRange.lowerBound))° and "
        + "\(angleText(tuningTargetRange.upperBound))°."
    case .tuningTargetOutOfRange(let tier, let target):
      "\(angleText(target))° is outside \(angleText(tuningTargetRange.lowerBound))° to "
        + "\(angleText(tuningTargetRange.upperBound))°, which is the range \(tier)'s side can be "
        + "rescaled through."
    case .quarterTurnGearNotDivisible(let tier, let wheel):
      "This pattern cannot be turned a quarter turn: "
        + (tier.map { "\($0)'s gear of \(wheel)" } ?? "the pattern's gear of \(wheel)")
        + " does not divide by 4, so a quarter turn would land between stops."
    case .derivationPointsCoincide(let tier, let numbers):
      "\(tier)@\(numbers.stop) cannot take its angle from those two points: both sit at the same "
        + "place on that facet's azimuth — \(numbers.firstText) and \(numbers.secondText) — so they "
        + "name no tilt. Pick a second point at a different height or distance."
    case .derivedAngleContradictsPart(let tier, let part, let angle, let numbers):
      "Those two points put \(tier)@\(numbers.stop) at \(angleText(angle))°, which faces the wrong "
        + "way for a \(part.rawValue) tier — \(numbers.firstText) and \(numbers.secondText). "
        + "Pick points a \(part.rawValue) facet could reach."
    case .siblingFacetTakesTheDepth(
      let tier, let aimed, let arrives, let angle, let aimedDot, let arrivingDot):
      "\(tier) cut at \(angleText(angle))° does not arrive at that point on stop \(aimed): "
        + "stop \(arrives) gets there first, reaching \(coordinateText(arrivingDot)) against "
        + "\(coordinateText(aimedDot)). Aim the stop that arrives, or pick points on the facet you "
        + "aimed."
    }
  }

  /// Labels as the sentence reads them, in the order they were found — which is file order everywhere one
  /// of these lists is built.
  private func list(_ labels: [String]) -> String {
    labels.joined(separator: ", ")
  }
}

/// The `#if DEBUG` status-strip segment. Here rather than in the view so its wording is checkable without
/// a window.
public func draftSummary(_ draft: PatternDraft) -> String {
  let count = "draft \(draft.tiers.count) tiers"
  guard !draft.tiers.isEmpty else { return "\(count) · no tiers yet" }
  let missing = draft.tiers.filter { $0.meet == nil }.map(\.tier)
  guard !missing.isEmpty else { return "\(count) · complete" }
  return "\(count) · no meet yet: \(missing.joined(separator: ", "))"
}
