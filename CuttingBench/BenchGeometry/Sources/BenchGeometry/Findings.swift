import FacetKernel
import Foundation

/// One line of the findings detail.
public struct FindingsRow: Identifiable, Equatable, Sendable {
  /// The tier this row is about, or `nil` for one about the pattern as a whole.
  public var tier: String?
  public var text: String
  /// Whether the line's count includes this row. The solver's own stop sentence and the note saying the
  /// geometric checks did not run are both shown and neither is counted: neither is a `Finding`.
  public var isFinding: Bool
  /// Position-prefixed, because two rows can legitimately read alike.
  public var id: String

  public init(tier: String?, text: String, isFinding: Bool, id: String) {
    self.tier = tier
    self.text = text
    self.isFinding = isFinding
    self.id = id
  }
}

/// Everything the three surfaces read: the strip's line, the popover's rows, the tier table's marker
/// counts, and the tiers whose dots draw as a warning.
public struct FindingsReadout: Equatable, Sendable {
  public var line: String
  public var rows: [FindingsRow]
  /// Tier label to how many findings name it. A tier with none is absent.
  public var perTier: [String: Int]
  /// The tiers carrying a `vertexNotOnIntermediateSolid` finding — the one finding with geometry to show.
  public var warningTiers: Set<String>

  public init(
    line: String, rows: [FindingsRow], perTier: [String: Int], warningTiers: Set<String>
  ) {
    self.line = line
    self.rows = rows
    self.perTier = perTier
    self.warningTiers = warningTiers
  }
}

/// The expensive half of validation, run tier by tier so it can be abandoned between tiers.
///
/// **Returns `nil` when `isCancelled` fired part-way.** A partial list is not a result and must never be
/// shown as one.
///
/// `declaredFacetCount` is deliberately `nil`: the declared count is the Facet Count card's business, and
/// counting it here would report one fault twice and restart this check on every keystroke in that field.
public func geometricFindings(
  pattern: Pattern,
  solution: Solution,
  isCancelled: () -> Bool = { false }
) -> [Finding]? {
  var findings: [Finding] = []
  for solved in solution.tiers {
    if isCancelled() { return nil }
    findings.append(contentsOf: namedPointFindings(inTier: solved.tier, of: pattern, solution))
  }
  if isCancelled() { return nil }
  findings.append(contentsOf: solidFindings(solution, declaredFacetCount: nil))
  return findings
}

/// The readout, from the pieces the store holds.
///
/// `geometric` is `nil` when the expensive half has produced no result for this solid — either because it
/// is still running, or because structural findings mean it will never run.
public func findingsReadout(
  pattern: Pattern?,
  solid: BenchSolid,
  structural: [Finding],
  geometric: [Finding]?,
  isChecking: Bool
) -> FindingsReadout {
  // Restated rather than shared with the Metrics card's own copy: a constant private to that file is not
  // this file's to reach into.
  guard pattern != nil else {
    return FindingsReadout(
      line: "No pattern open.", rows: [], perTier: [:], warningTiers: [])
  }

  let all = structural + (geometric ?? [])

  var rows: [FindingsRow] = []
  // The stop row first, because it is why there are no findings for the tiers after it.
  if let tier = solid.stoppedAtTier, let reason = solid.stoppedReason {
    rows.append(FindingsRow(tier: tier, text: reason, isFinding: false, id: "stop"))
  }
  for (i, finding) in all.enumerated() {
    rows.append(
      FindingsRow(
        tier: findingTier(finding), text: findingText(finding), isFinding: true,
        id: "finding-\(i)"))
  }
  if geometric == nil, !structural.isEmpty {
    rows.append(
      FindingsRow(
        tier: nil,
        text: "The geometric checks did not run: a pattern whose structure is wrong has no solid "
          + "to measure them against.",
        isFinding: false,
        id: "notRun"))
  }

  var perTier: [String: Int] = [:]
  var warningTiers: Set<String> = []
  for finding in all {
    if let tier = findingTier(finding) { perTier[tier, default: 0] += 1 }
    if case .vertexNotOnIntermediateSolid(let tier, _) = finding { warningTiers.insert(tier) }
  }

  let prefix = solid.stoppedAtTier.map { "Stopped at tier \($0) · " } ?? ""
  let count = all.count
  let countText =
    switch count {
    case 0: "No findings"
    case 1: "1 finding"
    default: "\(count) findings"
    }

  // This order is what stops the line ever saying `No findings` about a check that has not run: a count
  // is only reported once there is a geometric result to count, or once structural findings mean there
  // never will be one.
  let phrase: String
  if geometric != nil {
    phrase = isChecking ? "\(countText) · stale, checking…" : countText
  } else if !structural.isEmpty {
    phrase = countText
  } else {
    phrase = "checking…"
  }

  return FindingsReadout(
    line: prefix + phrase, rows: rows, perTier: perTier, warningTiers: warningTiers)
}

/// One finding as a sentence for a window. The CLI prints the enum's own reflection instead, on purpose,
/// so these words live here and not in the kernel.
public func findingText(_ finding: Finding) -> String {
  switch finding {
  case .forwardReference(let tier, let named):
    "Tier \(tier)'s meet names tier \(named), which this pattern cuts later."
  case .namesOwnFacet(let tier):
    "Tier \(tier)'s meet names a facet of \(tier) itself, which cannot fix its own depth."
  case .unknownFacet(let tier, let named):
    "Tier \(tier)'s meet names \(named.tier)@\(named.index), which this pattern does not cut."
  case .singularTriple(let tier):
    "Tier \(tier)'s three named facets do not meet at a point."
  case .secondTCPOnSide(let tier, let part):
    "Tier \(tier) is a second tcp on the \(part.rawValue) side, where the axial point is already fixed."
  case .notExactlyOneSizeRow(let count):
    "\(count) tiers carry the size meet; exactly one must."
  case .vertexNotOnIntermediateSolid(let tier, let named):
    "Tier \(tier)'s named point \(meetText(.vertex(facets: named))) is not a corner of the stone as it "
      + "stands when \(tier) is cut."
  case .doesNotClose(let tier):
    // **The tier is deliberately not named.** The kernel names the tier owning the first facet it found
    // an unshared edge on, which is where the surface is open and not what is wrong: on a part-cut stone
    // the incomplete facets are the girdle's, and they are absent from the polytope precisely because
    // they have no height yet, so the first facet found belongs to the tier below them. Naming it reads
    // as blame on a tier that is complete.
    if tier != nil {
      "The solid does not close: some facets are incomplete, with an edge no other facet shares."
    } else {
      "The solid does not close: it is too small to have a surface at all."
    }
  // Unreachable from this slice, because `geometricFindings` passes no declared count. Written anyway:
  // the switch has to be total, and a `default:` here would silently swallow a case the kernel adds later.
  case .facetCountMismatch(let solved, let declared):
    "The solve counts \(solved) facets; \(declared) declared."
  }
}

/// The tier a finding names, or `nil` for the three that are about the pattern as a whole.
///
/// `doesNotClose` is one of the three. Closure is a property of the whole solid, and the tier the kernel
/// reports is where the open edge was found rather than what left it open — marking that tier's row would
/// send the reader to a facet that is complete.
public func findingTier(_ finding: Finding) -> String? {
  switch finding {
  case .forwardReference(let tier, _): tier
  case .namesOwnFacet(let tier): tier
  case .unknownFacet(let tier, _): tier
  case .singularTriple(let tier): tier
  case .secondTCPOnSide(let tier, _): tier
  case .vertexNotOnIntermediateSolid(let tier, _): tier
  case .doesNotClose, .notExactlyOneSizeRow, .facetCountMismatch: nil
  }
}
