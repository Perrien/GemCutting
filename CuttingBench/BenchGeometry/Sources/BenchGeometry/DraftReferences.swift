import FacetKernel
import Foundation

/// Which tier's meet names which tier's facets. Built from `Meet.namedTriples`, so the app never restates
/// how a meet names facets — a `fraction`'s two endpoints are that function's business and not this
/// file's (ADR-0003).
///
/// A tier's own meet naming its own label is **not** filtered out anywhere here. The kernel already
/// reports that as `namesOwnFacet`; this file's job is the graph, not the judgement.

/// Every tier whose meet names a facet of `tier`, in file order.
public func tiersNaming(tier: String, in draft: PatternDraft) -> [String] {
  draft.tiers.filter { namer in
    namer.meet?.namedTriples.contains { triple in triple.contains { $0.tier == tier } } ?? false
  }
  .map(\.tier)
}

/// Every tier whose meet names `tier` at exactly this index stop, in file order.
public func tiersNaming(tier: String, index: Int, in draft: PatternDraft) -> [String] {
  draft.tiers.filter { namer in
    namer.meet?.namedTriples.contains { triple in
      triple.contains { $0.tier == tier && $0.index == index }
    } ?? false
  }
  .map(\.tier)
}

/// The labels a tier's own meet names, deduplicated, in the order they are first named.
public func tiersNamed(by tier: DraftTier) -> [String] {
  guard let meet = tier.meet else { return [] }
  var seen = Set<String>()
  // Not a `Set` result: the order a meet names its facets in is the author's statement about the stone,
  // and a refusal that reports the first offender needs that order to mean something.
  return meet.namedTriples.flatMap { $0 }.map(\.tier).filter { seen.insert($0).inserted }
}
