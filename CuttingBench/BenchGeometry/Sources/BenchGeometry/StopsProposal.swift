/// What a typed seed set, fold count and mirror flag would generate, before anything is written.
///
/// **The generator is a proposal, not an edit.** Seeds, folds and mirroring are derived from a tier's stop
/// list rather than stored, so a control that applied one the moment it was typed had to regenerate the
/// whole list to do it — which silently re-sorted stops the author had transcribed in a printed sheet's
/// own order. Here the three are held as typed text, this says what they come to, and writing it to the
/// tier is a separate, deliberate act.
///
/// Pure and window-free, so every refusal and every generated list is checkable without a view.

/// The stop list the typed generator produces, or why it produces none.
///
/// **The failure is a `DraftRefusal` rather than a wording of its own**, so the sentence the pane shows for
/// a bad seed or an impossible fold count is by construction the same sentence the Indices cell shows for
/// the same fault. A second wording is how the two come to disagree.
///
/// Refused for a seed list that is not whole numbers, for a seed outside the tier's gear, for a fold count
/// that is not a number, and for one that does not divide the gear — 7-fold is reachable on 84 and
/// impossible on 96.
///
/// **An empty seed list is not a refusal**: it generates no stops, which is an honest answer and what a
/// half-typed field passes through on its way to a real one.
public func proposedStops(
  seeds typedSeeds: String,
  folds typedFolds: String,
  mirror: Bool,
  ofTier tier: String,
  wheel: Int
) -> Result<[Int], DraftRefusal> {
  guard let seeds = parsedStops(typedSeeds) else {
    return .failure(.indicesNotWholeNumbers(typed: typedSeeds))
  }
  // Seeds *are* index stops, so a bad one reuses the Indices cell's own sentence rather than getting a
  // second wording for the same fault — the rule `setting(seeds:ofTier:in:)` already follows.
  for seed in seeds where seed < 0 || seed >= wheel {
    return .failure(.indexOutOfRange(tier: tier, index: seed, wheel: wheel))
  }

  guard let folds = Int(typedFolds.trimmingCharacters(in: .whitespacesAndNewlines)) else {
    return .failure(.notANumber(field: "folds", typed: typedFolds))
  }
  guard foldCounts(onWheel: wheel).contains(folds) else {
    return .failure(.foldsNotADivisor(tier: tier, folds: folds, wheel: wheel))
  }

  return .success(expandedStops(seeds: seeds, folds: folds, mirror: mirror, wheel: wheel))
}

/// A stop list as the Indices cell writes it: space-separated, in the order given. The one place the two
/// surfaces agree on the spelling, so what the proposal shows is exactly what a copy puts in the cell.
public func stopsText(_ stops: [Int]) -> String {
  stops.map(String.init).joined(separator: " ")
}

/// Where a tier's generator fields start: its own stops' symmetry, and for a tier that has no stops yet,
/// the folds and mirroring of the nearest tier cut before it that has any.
///
/// **The seeds are never carried** — which stops a tier is cut at is the design and the author's to state.
/// Folds and mirroring are not: a pattern is nearly always cut at one symmetry throughout, so an appended
/// tier starting at 1 fold and unmirrored meant retyping the same two answers for every tier of the
/// pattern. Nothing is written by this; the fields it fills still generate nothing until a seed is typed.
///
/// **The carried fold count has to divide this tier's own gear**, since a tier may be cut on a gear of its
/// own — 7-fold is reachable on 84 and impossible on 96 — so a count that cannot be generated here falls
/// back to the honest 1 rather than filling the field with a value the generator would refuse.
public func startingGenerator(ofTier tier: String, in draft: PatternDraft) -> TierSymmetry {
  let nothing = TierSymmetry(seeds: [], folds: 1, mirror: false)
  guard let position = draft.position(ofTier: tier) else { return nothing }

  let gear = draft.wheel(of: draft.tiers[position])
  let own = derivedSymmetry(stops: draft.tiers[position].indices, wheel: gear)
  guard own.seeds.isEmpty else { return own }

  // Only the nearest one back, not the best match further up: the tier before is what the author was just
  // working on, and searching past it for a fold count that fits would answer with a tier they may not
  // even have in view.
  guard let earlier = draft.tiers[..<position].last(where: { !$0.indices.isEmpty }) else {
    return nothing
  }
  let neighbour = derivedSymmetry(stops: earlier.indices, wheel: draft.wheel(of: earlier))
  guard foldCounts(onWheel: gear).contains(neighbour.folds) else { return nothing }
  return TierSymmetry(seeds: [], folds: neighbour.folds, mirror: neighbour.mirror)
}
