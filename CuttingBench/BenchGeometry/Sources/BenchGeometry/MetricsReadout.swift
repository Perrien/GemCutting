import FacetKernel
import Foundation

/// One label-and-value row of the proportion table.
public struct MetricsRow: Identifiable, Equatable, Sendable {
  public var label: String
  public var value: String

  /// The label is unique within the table, which is what lets a `ForEach` keep its identity across a
  /// rebuild without a fresh `UUID` per pass.
  public var id: String { label }

  public init(label: String, value: String) {
    self.label = label
    self.value = value
  }
}

/// The Metrics card's contents, every value already a string.
public struct MetricsSummary: Equatable, Sendable {
  /// The count in the split form, `57 + 16 girdle = 73`.
  public var facets: String
  public var symmetry: String
  public var lengthOverWidth: String
  /// `P/W`, `C/W`, `H/W`, `T/W`, girdle, width, length, culet — in that order, which is the order they
  /// are read in.
  public var proportions: [MetricsRow]

  public init(
    facets: String, symmetry: String, lengthOverWidth: String, proportions: [MetricsRow]
  ) {
    self.facets = facets
    self.symmetry = symmetry
    self.lengthOverWidth = lengthOverWidth
    self.proportions = proportions
  }
}

/// Whether there is a measured stone to report, or the sentence saying why there is not.
public enum MetricsReadout: Equatable, Sendable {
  case unavailable(String)
  case measured(MetricsSummary)
}

/// The Facet Count card's contents.
public struct FacetCountCheck: Equatable, Sendable {
  /// The solved count in the split form, or `nil` when there is nothing measurable to count — then
  /// `verdict` is the reason.
  public var solved: String?
  public var verdict: String

  public init(solved: String?, verdict: String) {
    self.solved = solved
    self.verdict = verdict
  }
}

/// There is no stone at all, as against a stone only part cut. One constant, because two functions say
/// it and a card's sentence must not depend on which one answered.
let noPatternOpen = "No pattern open."

/// Why neither measured card has figures to show, or `nil` when the solve placed every tier the pattern
/// declares.
///
/// **One predicate for both cards**, so they can never disagree about whether there is a stone to
/// measure. A partial solve is a normal authoring state and its measurements are the floating pavilion
/// cone's rather than the stone's, so the honest answer is the reason and no number.
public func unmeasurableReason(pattern: Pattern?, solid: BenchSolid) -> String? {
  guard let pattern, let solution = solid.solution else { return noPatternOpen }
  // Before the count, because a stopped solve fails the count too and its own tier label is the more
  // useful of the two sentences.
  if let stopped = solid.stoppedAtTier {
    return "Metrics need every tier: the solve stopped at tier \(stopped)."
  }
  if solution.tiers.count != pattern.tiers.count {
    return "Metrics need every tier: \(solution.tiers.count) of \(pattern.tiers.count) placed."
  }
  return nil
}

/// The facet count in the split form a printed sheet uses.
///
/// Sheets differ on whether the headline figure counts the girdle band, so a bare total reads as a
/// mismatch against a sheet that prints only the crown-and-pavilion figure. The girdle share is the
/// facets belonging to tiers whose `part` is `.gdl`. **A knife-edge girdle has no girdle facets, so the
/// term is omitted rather than shown as zero.**
public func splitFacetCount(_ measured: Metrics, tiers: [SolvedTier]) -> String {
  // `tiers` is the solution's own, never the pattern's: `facetsPerTier` is keyed by the solution's tier
  // labels, so taking the parts from the same place is what stops the two falling out of step.
  let girdle =
    tiers
    .filter { $0.part == .gdl }
    .reduce(0) { $0 + (measured.facetsPerTier[$1.tier] ?? 0) }
  guard girdle > 0 else { return String(measured.facetCount) }
  return "\(measured.facetCount - girdle) + \(girdle) girdle = \(measured.facetCount)"
}

public func metricsReadout(pattern: Pattern?, solid: BenchSolid) -> MetricsReadout {
  if let reason = unmeasurableReason(pattern: pattern, solid: solid) {
    return .unavailable(reason)
  }
  // `unmeasurableReason` returning `nil` is what guarantees the solution is there; the sentence is the
  // shared constant so the unreachable branch cannot say something the predicate would not.
  guard let solution = solid.solution else { return .unavailable(noPatternOpen) }

  let measured = metrics(solution)

  return .measured(
    MetricsSummary(
      facets: splitFacetCount(measured, tiers: solution.tiers),
      symmetry: symmetryText(measured),
      // Every format here matches `facetsolve`'s own precision, so the owner's cross-check against
      // `facetsolve --json` compares identical figures rather than judging a rounding difference.
      lengthOverWidth: String(format: "%.5f", measured.lengthOverWidth),
      proportions: [
        MetricsRow(
          label: "P/W", value: String(format: "%.3f", measured.pavilionDepthFractionOfWidth)),
        MetricsRow(
          label: "C/W", value: String(format: "%.3f", measured.crownHeightFractionOfWidth)),
        MetricsRow(label: "H/W", value: String(format: "%.3f", measured.totalDepthFractionOfWidth)),
        MetricsRow(label: "T/W", value: String(format: "%.3f", measured.tableFractionOfWidth)),
        MetricsRow(
          label: "Girdle",
          value: String(
            format: "%.6f (%.3f%% of width)",
            measured.girdleThicknessNormalised,
            measured.girdleFractionOfWidth * 100)),
        MetricsRow(label: "Width", value: String(format: "%.6f", measured.widthNormalised)),
        MetricsRow(label: "Length", value: String(format: "%.6f", measured.lengthNormalised)),
        MetricsRow(label: "Culet", value: measured.culetIsPoint ? "point" : "facet"),
      ]))
}

/// The declared facet count as a number, or `nil` for a field that is not making a claim — empty,
/// or holding something that is not a positive whole number.
///
/// **One rule, in one place.** The Facet Count card and the `finished` transition both read this field,
/// and two parsers would let them disagree about whether `5x` is a count.
func declaredCount(_ typed: String) -> Int? {
  let trimmed = typed.trimmingCharacters(in: .whitespaces)
  guard let count = Int(trimmed), count > 0 else { return nil }
  return count
}

/// `declared` is the field's raw text, so parsing it is this function's job and not the view's.
public func facetCountCheck(
  pattern: Pattern?, solid: BenchSolid, declared: String
) -> FacetCountCheck {
  if let reason = unmeasurableReason(pattern: pattern, solid: solid) {
    return FacetCountCheck(solved: nil, verdict: reason)
  }
  guard let solution = solid.solution else {
    return FacetCountCheck(solved: nil, verdict: noPatternOpen)
  }

  // The same string whatever the field says: what the solve measured does not depend on what the sheet
  // claims.
  let split = splitFacetCount(metrics(solution), tiers: solution.tiers)

  let trimmed = declared.trimmingCharacters(in: .whitespaces)
  guard !trimmed.isEmpty else {
    return FacetCountCheck(solved: split, verdict: "No count declared.")
  }
  guard let count = declaredCount(trimmed) else {
    return FacetCountCheck(solved: split, verdict: "Not a facet count.")
  }

  // The kernel's own comparison, never a second one here: two implementations of one check can agree
  // with a broken one. `solidFindings` also reports closure, which is part 1's business and part 3's, so
  // every case but this one is ignored.
  let mismatched = solidFindings(solution, declaredFacetCount: count).contains { finding in
    guard case .facetCountMismatch = finding else { return false }
    return true
  }

  return FacetCountCheck(
    solved: split,
    verdict: mismatched
      ? "Declared \(count) · solved \(split)."
      : "Matches the declared \(count).")
}

/// The rotational order and the mirror axes as one line. A stone with no mirror axis says so, rather
/// than trailing off after the order.
private func symmetryText(_ measured: Metrics) -> String {
  let order = "\(measured.rotationalOrder)-fold"
  guard !measured.mirrorAxes.isEmpty else { return order + ", no mirror axis" }
  return order + ", mirrors at " + measured.mirrorAxes.map(String.init).joined(separator: " ")
}
