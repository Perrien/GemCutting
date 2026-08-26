import FacetKernel

/// Whether the pattern may be marked `finished`, and why not when it may not (D8, D9).
///
/// **Solves and validates from scratch, synchronously.** The deferred pass may be mid-flight and the
/// per-tier cache may hold nothing for the tiers just edited, so the one place in the app where a check
/// blocks is also the one place that trusts neither.
///
/// Three refusals, in the order they can be answered: a draft with no file form at all, a solve that does
/// not reach the end, and a validation that finds something. `nil` is the transition allowed.
///
/// `declaredFacets` is the Facet Count card's field as typed. With nothing making a claim there, that one
/// check does not run rather than blocking the transition (D12).
public func finishRefusal(draft: PatternDraft, declaredFacets: String) -> DraftRefusal? {
  // The draft, not `displayPattern`: that one silently drops a tier with no meet, and validating it would
  // validate something other than what the author wrote (D14, ADR-0003).
  let pattern: Pattern
  switch draft.completePattern() {
  case .failure(let refusal): return refusal
  case .success(let complete): pattern = complete
  }

  // `solveAsFarAsPossible`, matching what the display solves, so the verdict is about the same geometry
  // the owner is looking at. A failure here is not a finding and would otherwise pass unremarked (D11).
  let partial = solveAsFarAsPossible(pattern)
  if let failure = partial.failure {
    return .finishedWithSolveStoppedShort(tier: failure.tier, reason: failure.description)
  }

  // The kernel's own composite, never a second assembly of the three halves here: `validate` already
  // orders them and already declines to report geometry for a pattern whose structure is wrong.
  let report = validate(
    pattern, partial.solution, declaredFacetCount: declaredCount(declaredFacets))
  guard !report.findings.isEmpty else { return nil }
  return .finishedWithFindings(report.findings.map(findingText))
}
