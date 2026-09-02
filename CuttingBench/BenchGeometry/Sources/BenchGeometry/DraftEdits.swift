import FacetKernel
import Foundation

/// Every edit the app can make to a draft, each one a function from a draft to either a new draft or a
/// refusal. `DraftRefusal` is declared in `PatternDraft.swift` — see there for why.
///
/// **Every one of them returns `Result` even where it can never fail**, so the window's funnel has one
/// signature to call and a later part can make a rule stricter without changing a call site.
///
/// **A label the draft does not carry is `.success(draft)` — the draft unchanged.** Not a refusal: a stale
/// label in the table's selection is inert rather than wrong, which is the rule the tier selection already
/// states.
///
/// The line through all of it is **remove versus move**. Removing a tier, or an index stop, that a later
/// meet names is refused and names the dependents. Moving a named facet — a new angle, a new part — is
/// always allowed, because every reference still resolves, just to a different point.

// MARK: - Structure

/// Refused when any tier's meet names a facet of this one. Nothing is repaired and nothing cascades:
/// re-aiming a meet means choosing which facets it should point at instead, which the format forbids a
/// tool from doing.
public func deleting(tier: String, from draft: PatternDraft) -> Result<PatternDraft, DraftRefusal> {
  guard let position = draft.position(ofTier: tier) else { return .success(draft) }

  let dependents = tiersNaming(tier: tier, in: draft)
  guard dependents.isEmpty else {
    return .failure(.tierReferenced(tier: tier, by: dependents))
  }

  var edited = draft
  edited.tiers.remove(at: position)
  return .success(edited)
}

/// Refused when the reordering would make any meet name a tier cut later — the same test as a delete,
/// applied to a move.
///
/// The reordered array is built first and then walked, because whether a move is legal is a fact about the
/// order it produces and not about the tier that moved: the violation the walk finds may well belong to a
/// tier that stayed still and got overtaken.
///
/// `offset` is `-1` or `+1`; a move off either end is the draft unchanged.
public func moving(tier: String, by offset: Int, in draft: PatternDraft)
  -> Result<PatternDraft, DraftRefusal>
{
  guard let position = draft.position(ofTier: tier) else { return .success(draft) }
  let destination = position + offset
  guard draft.tiers.indices.contains(destination) else { return .success(draft) }

  var edited = draft
  let moved = edited.tiers.remove(at: position)
  edited.tiers.insert(moved, at: destination)

  if let violation = firstForwardReference(in: edited) {
    return .failure(violation)
  }
  return .success(edited)
}

/// Appends a tier with nothing guessed about the design: no meet, so the display drops it and none of
/// these values reaches the stone until the author has set them.
///
/// **The part carries over from the tier before it**, pavilion for the first tier of an empty pattern. A
/// pattern is cut part by part — a run of pavilion tiers, then the girdle, then a run of crown tiers — so
/// the tier just added is nearly always the same part as the one before, and the old fixed pavilion was
/// wrong for every tier after the girdle. The angle follows the part exactly as choosing the part in the
/// table does: 0 for a table, 90 for a girdle, and 0 for crown and pavilion, whose angle is the author's.
///
/// Appending can never create a forward reference, and inserting mid-pattern is reachable by appending and
/// then moving, which `moving` already guards.
public func appendingTier(to draft: PatternDraft) -> Result<PatternDraft, DraftRefusal> {
  let used = Set(draft.tiers.map(\.tier))
  var n = 1
  while used.contains("N\(n)") { n += 1 }

  let part = draft.tiers.last?.part ?? .pav
  var edited = draft
  edited.tiers.append(
    DraftTier(
      tier: "N\(n)", part: part, angle: definingAngle(of: part) ?? 0, indices: [], meet: nil,
      instructions: nil))
  return .success(edited)
}

/// The one structural repair that guesses nothing: the mapping from the old label to the new is exact, so
/// every `FacetRef` naming the tier is rewritten with it.
///
/// Refused only for an empty or a duplicate label, mirroring the two rules decoding enforces.
public func renaming(tier: String, to label: String, in draft: PatternDraft)
  -> Result<PatternDraft, DraftRefusal>
{
  guard let position = draft.position(ofTier: tier) else { return .success(draft) }

  let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
  guard !trimmed.isEmpty else { return .failure(.emptyTierLabel) }
  guard trimmed != tier else { return .success(draft) }
  guard !draft.tiers.contains(where: { $0.tier == trimmed }) else {
    return .failure(.duplicateTierLabel(trimmed))
  }

  var edited = draft
  edited.tiers[position].tier = trimmed
  for k in edited.tiers.indices {
    guard let meet = edited.tiers[k].meet else { continue }
    edited.tiers[k].meet = renamed(meet, from: tier, to: trimmed)
  }
  return .success(edited)
}

// MARK: - A tier's own values

/// Never refused for its value. An angle past 90 is a geometric consequence and is reported by the solve,
/// which is the line: structural edits are refused, geometric ones are reported.
public func setting(angle typed: String, ofTier tier: String, in draft: PatternDraft)
  -> Result<PatternDraft, DraftRefusal>
{
  guard let position = draft.position(ofTier: tier) else { return .success(draft) }
  guard let angle = Double(typed.trimmingCharacters(in: .whitespacesAndNewlines)) else {
    return .failure(.notANumber(field: "angle", typed: typed))
  }

  var edited = draft
  edited.tiers[position].angle = angle
  return .success(edited)
}

/// The two-point derivation's one write: the angle and the meet together, so undo puts both back in one
/// step. Never refused — every way the derivation can fail was answered before this is called.
public func setting(derived: DerivedTierAngle, ofTier tier: String, in draft: PatternDraft)
  -> Result<PatternDraft, DraftRefusal>
{
  guard let position = draft.position(ofTier: tier) else { return .success(draft) }
  var edited = draft
  edited.tiers[position].angle = derived.angle
  edited.tiers[position].meet = derived.meet
  return .success(edited)
}

/// The whole list at once, which is why the commit boundary exists: a half-typed list means nothing to
/// judge.
///
/// Refused for a stop that is not a whole number, for one outside the tier's effective gear, and for
/// **removing** a stop a later meet names. Order and duplicates are preserved exactly as typed — the
/// format permits any order and the order is data.
public func setting(indices typed: String, ofTier tier: String, in draft: PatternDraft)
  -> Result<PatternDraft, DraftRefusal>
{
  guard let position = draft.position(ofTier: tier) else { return .success(draft) }
  guard let indices = parsedStops(typed) else {
    return .failure(.indicesNotWholeNumbers(typed: typed))
  }
  return settingStops(indices, atPosition: position, in: draft)
}

/// Always accepted: a new part moves a named facet rather than removing it, so every reference still
/// resolves.
///
/// **Choosing girdle or table sets the angle with it — 90 and 0.** Those two parts are cut at one angle by
/// definition: the mast angle is measured from the table plane, so a table stands at 0 and a girdle at 90,
/// and every girdle and table tier in all four authored patterns is cut that way. Crown and pavilion are
/// left alone, because their ranges genuinely overlap and there is nothing to guess from the part.
///
/// **It overwrites an angle already typed rather than filling in only a blank one.** A tier the author has
/// just declared a girdle is a girdle; filling only where the angle still reads 0 would leave a 43°
/// pavilion switched to girdle sitting silently at 43°, which is the confusion this exists to remove. One
/// named edit covers both fields, so undo puts the part and the angle back together.
public func setting(part: Part, ofTier tier: String, in draft: PatternDraft)
  -> Result<PatternDraft, DraftRefusal>
{
  guard let position = draft.position(ofTier: tier) else { return .success(draft) }

  var edited = draft
  edited.tiers[position].part = part
  if let angle = definingAngle(of: part) {
    edited.tiers[position].angle = angle
  }
  return .success(edited)
}

/// The single angle a part is cut at, or `nil` where the angle is the author's to choose.
///
/// Girdle and table have one each and crown and pavilion have none — a crown tier and a pavilion tier can
/// sit at the same angle, which is exactly why a pattern has to state the part rather than infer it.
public func definingAngle(of part: Part) -> Double? {
  switch part {
  case .table: 0
  case .gdl: 90
  case .crown, .pav: nil
  }
}

/// Always accepted. **An empty string is stored as an empty string and never as `nil`**, because absent
/// means the author wrote nothing and empty means they wrote nothing *here*.
public func setting(instructions: String, ofTier tier: String, in draft: PatternDraft)
  -> Result<PatternDraft, DraftRefusal>
{
  guard let position = draft.position(ofTier: tier) else { return .success(draft) }

  var edited = draft
  edited.tiers[position].instructions = instructions
  return .success(edited)
}

/// Always accepted, `nil` included — clearing a meet is an edit like any other and one ⌘Z undoes it.
///
/// The parameter is a whole `Meet?` rather than a choice among the three forms that need no picking, so a
/// later part can pass a picked `vertex` or `fraction` without changing this function.
public func setting(meet: Meet?, ofTier tier: String, in draft: PatternDraft)
  -> Result<PatternDraft, DraftRefusal>
{
  guard let position = draft.position(ofTier: tier) else { return .success(draft) }

  var edited = draft
  edited.tiers[position].meet = meet
  return .success(edited)
}

/// The anchored percentage of a tier whose meet is a `fraction`, typed by the author.
///
/// **`0` or `100` collapses the meet to a plain `vertex`** at the endpoint the percentage names — `from`
/// at 0, `to` at 100 — so the meet form follows from the value rather than from how it was entered,
/// exactly as snapping into an end zone does. An endpoint that is `tcp` collapses to `tcp`.
///
/// Refused for text that is not a number (`notANumber`), and for a number outside `0...100`
/// (`percentNotInRange`). A tier whose meet is not a `fraction` is returned unchanged rather than
/// refused: nothing in the UI offers the field there, so it is unreachable rather than wrong.
public func setting(percent typed: String, ofTier tier: String, in draft: PatternDraft)
  -> Result<PatternDraft, DraftRefusal>
{
  guard let position = draft.position(ofTier: tier) else { return .success(draft) }
  guard case .fraction(let from, _, let to) = draft.tiers[position].meet else {
    return .success(draft)
  }
  guard let percent = Double(typed.trimmingCharacters(in: .whitespacesAndNewlines)) else {
    return .failure(.notANumber(field: "percentage", typed: typed))
  }
  guard percent >= 0, percent <= 100 else {
    return .failure(.percentNotInRange(tier: tier, typed: typed))
  }

  var edited = draft
  // The same field every other setter writes, so a percentage edit is one undo entry and rides part 2's
  // validation exactly as an angle edit does.
  switch percent {
  case 0: edited.tiers[position].meet = from
  case 100: edited.tiers[position].meet = to
  default: edited.tiers[position].meet = .fraction(from: from, percent: percent, to: to)
  }
  return .success(edited)
}

// MARK: - Symmetry, which is generated and never stored

/// The stop list the typed seeds generate, at the folds and mirroring the tier's **current** stops derive.
///
/// Refused for a piece that is not a whole number, for a seed outside the tier's gear, and — through
/// `settingStops` — for a regeneration that would remove a stop a later meet names.
public func setting(seeds typed: String, ofTier tier: String, in draft: PatternDraft)
  -> Result<PatternDraft, DraftRefusal>
{
  guard let position = draft.position(ofTier: tier) else { return .success(draft) }
  guard let seeds = parsedStops(typed) else {
    return .failure(.indicesNotWholeNumbers(typed: typed))
  }

  // Seeds *are* index stops, so a bad one reuses the Indices cell's own two sentences rather than getting
  // a second wording for the same fault.
  let gear = draft.wheel(of: draft.tiers[position])
  for seed in seeds where seed < 0 || seed >= gear {
    return .failure(.indexOutOfRange(tier: tier, index: seed, wheel: gear))
  }

  let current = derivedSymmetry(stops: draft.tiers[position].indices, wheel: gear)
  return settingStops(
    expandedStops(seeds: seeds, folds: current.folds, mirror: current.mirror, wheel: gear),
    atPosition: position,
    in: draft)
}

/// Refused for a value that is not a whole number, and for one that does not divide the tier's effective
/// gear — 7-fold is reachable on 84 and impossible on 96.
public func setting(folds typed: String, ofTier tier: String, in draft: PatternDraft)
  -> Result<PatternDraft, DraftRefusal>
{
  guard let position = draft.position(ofTier: tier) else { return .success(draft) }
  guard let folds = Int(typed.trimmingCharacters(in: .whitespacesAndNewlines)) else {
    return .failure(.notANumber(field: "folds", typed: typed))
  }

  let gear = draft.wheel(of: draft.tiers[position])
  guard foldCounts(onWheel: gear).contains(folds) else {
    return .failure(.foldsNotADivisor(tier: tier, folds: folds, wheel: gear))
  }

  let current = derivedSymmetry(stops: draft.tiers[position].indices, wheel: gear)
  return settingStops(
    expandedStops(seeds: current.seeds, folds: folds, mirror: current.mirror, wheel: gear),
    atPosition: position,
    in: draft)
}

/// Never refused for its own value: it only ever writes a stop list, and nothing records what generated
/// one. Making a set *less* symmetric is an ordinary edit, refused only if it drops a named stop.
public func setting(mirror: Bool, ofTier tier: String, in draft: PatternDraft)
  -> Result<PatternDraft, DraftRefusal>
{
  guard let position = draft.position(ofTier: tier) else { return .success(draft) }

  let gear = draft.wheel(of: draft.tiers[position])
  let current = derivedSymmetry(stops: draft.tiers[position].indices, wheel: gear)
  return settingStops(
    expandedStops(seeds: current.seeds, folds: current.folds, mirror: mirror, wheel: gear),
    atPosition: position,
    in: draft)
}

// MARK: - The index gear

/// A tier's own gear, or `nil` to inherit the design's.
///
/// Refused when the new effective gear would put one of this tier's existing stops out of range — 100 is a
/// valid stop on 120 and rejected on 96 — naming the first such stop in the order the author wrote them.
/// Accepted otherwise, and **no stop is ever rewritten**: every plane on the tier moves, which the solve
/// reports.
public func setting(wheel: Int?, ofTier tier: String, in draft: PatternDraft)
  -> Result<PatternDraft, DraftRefusal>
{
  guard let position = draft.position(ofTier: tier) else { return .success(draft) }

  // A negative stop cannot be present, because nothing can put one there.
  let gear = wheel ?? draft.wheel
  for index in draft.tiers[position].indices where index >= gear {
    return .failure(.indexOutOfRange(tier: tier, index: index, wheel: gear))
  }

  var edited = draft
  edited.tiers[position].wheel = wheel
  return .success(edited)
}

/// The design's default gear, which applies to every tier declaring none of its own.
///
/// Refused when it would put any inheriting tier's existing stop out of range, naming the first such stop
/// in file order. A tier with its own gear is untouched and is not checked.
public func setting(wheel: Int, in draft: PatternDraft) -> Result<PatternDraft, DraftRefusal> {
  for spec in draft.tiers where spec.wheel == nil {
    for index in spec.indices where index >= wheel {
      return .failure(.indexOutOfRange(tier: spec.tier, index: index, wheel: wheel))
    }
  }

  var edited = draft
  edited.wheel = wheel
  return .success(edited)
}

// MARK: - The header

/// Stored verbatim, whitespace included. A name is the author's and not the tool's to tidy.
public func setting(name: String, in draft: PatternDraft) -> Result<PatternDraft, DraftRefusal> {
  var edited = draft
  edited.name = name
  return .success(edited)
}

/// **Never refused here.** Whether `finished` may be claimed is `finishRefusal`'s question, asked by the
/// window before this is applied; going back to `in progress` claims nothing and is always allowed (D13).
public func setting(state: PatternState, in draft: PatternDraft)
  -> Result<PatternDraft, DraftRefusal>
{
  var edited = draft
  edited.state = state
  return .success(edited)
}

public func setting(designer: String, in draft: PatternDraft)
  -> Result<PatternDraft, DraftRefusal>
{
  var edited = draft
  edited.designer = designer
  return .success(edited)
}

public func setting(notes: String, in draft: PatternDraft) -> Result<PatternDraft, DraftRefusal> {
  var edited = draft
  edited.notes = notes
  return .success(edited)
}

/// Not range-checked. A refractive index the solve cannot use shows up as a critical angle the Light card
/// reports, which is the reporting half of the same line the angle sits on.
public func setting(ri typed: String, in draft: PatternDraft)
  -> Result<PatternDraft, DraftRefusal>
{
  guard let ri = Double(typed.trimmingCharacters(in: .whitespacesAndNewlines)) else {
    return .failure(.notANumber(field: "refractive index", typed: typed))
  }

  var edited = draft
  edited.ri = ri
  return .success(edited)
}

/// The fraction the file stores, and **an empty field is absent** — which means the documented default
/// rather than zero. Zero and below are refused, mirroring the rule decoding enforces.
public func setting(girdleTarget typed: String, in draft: PatternDraft)
  -> Result<PatternDraft, DraftRefusal>
{
  let trimmed = typed.trimmingCharacters(in: .whitespacesAndNewlines)
  var edited = draft

  guard !trimmed.isEmpty else {
    edited.girdleTargetFraction = nil
    return .success(edited)
  }
  guard let fraction = Double(trimmed) else {
    return .failure(.notANumber(field: "girdle target", typed: typed))
  }
  guard fraction > 0 else {
    return .failure(.girdleTargetNotPositive(typed: typed))
  }

  edited.girdleTargetFraction = fraction
  return .success(edited)
}

// MARK: - Writing a stop list

/// The one place a tier's stop list is written: the range check, the reference check, and the assignment.
///
/// **Every editor that produces a stop list goes through here** — the Indices cell, the three symmetry
/// controls and neither gear popup — so a generated list is refused for exactly what a typed one is, in
/// exactly the same words.
private func settingStops(_ stops: [Int], atPosition position: Int, in draft: PatternDraft)
  -> Result<PatternDraft, DraftRefusal>
{
  let tier = draft.tiers[position].tier
  let gear = draft.wheel(of: draft.tiers[position])
  for index in stops where index < 0 || index >= gear {
    return .failure(.indexOutOfRange(tier: tier, index: index, wheel: gear))
  }

  // Only the stops that would go, and in the order the author wrote them: a stop still in the list is
  // still there to be named, however the list was rearranged around it.
  let kept = Set(stops)
  for index in draft.tiers[position].indices where !kept.contains(index) {
    let dependents = tiersNaming(tier: tier, index: index, in: draft)
    guard dependents.isEmpty else {
      return .failure(.stopReferenced(tier: tier, index: index, by: dependents))
    }
  }

  var edited = draft
  edited.tiers[position].indices = stops
  return .success(edited)
}

/// A typed stop list, split on whitespace and commas alike. `nil` for a piece that is not a whole number.
/// **Order and duplicates are preserved exactly as typed**, which is what the Indices cell needs; the
/// generator sorts its own output instead.
///
/// Not `private`: the detail pane's proposal parses a typed seed list the same way, and a second parser
/// is how the two come to disagree about what counts as a stop list.
func parsedStops(_ typed: String) -> [Int]? {
  let pieces = typed.split(whereSeparator: { $0 == "," || $0.isWhitespace })
  var stops: [Int] = []
  for piece in pieces {
    guard let stop = Int(piece) else { return nil }
    stops.append(stop)
  }
  return stops
}

// MARK: - Reading the order

/// The first tier whose meet names a label at or after its own position, or `nil` when every meet names
/// only tiers cut earlier.
///
/// A label the draft does not carry is skipped rather than reported: an unresolvable reference is the
/// solver's finding to make, and refusing a move for it would leave the author unable to reorder their way
/// out of a pattern they are half-way through transcribing.
private func firstForwardReference(in draft: PatternDraft) -> DraftRefusal? {
  for (position, tier) in draft.tiers.enumerated() {
    for named in tiersNamed(by: tier) {
      guard let namedPosition = draft.position(ofTier: named) else { continue }
      if namedPosition >= position {
        return .moveWouldPointForward(tier: tier.tier, named: named)
      }
    }
  }
  return nil
}

/// Every `FacetRef` in a meet, relabelled. Walks a `vertex`'s facets and both endpoints of a `fraction`;
/// the three forms that name no facet are returned as they are.
private func renamed(_ meet: Meet, from old: String, to new: String) -> Meet {
  switch meet {
  case .size, .tcp, .girdle:
    return meet
  case .vertex(let facets):
    // The order inside the triple is the author's statement about the stone, so this maps in place rather
    // than rebuilding the list.
    return .vertex(
      facets: facets.map { $0.tier == old ? FacetRef(tier: new, index: $0.index) : $0 })
  case .fraction(let from, let percent, let to):
    return .fraction(
      from: renamed(from, from: old, to: new),
      percent: percent,
      to: renamed(to, from: old, to: new))
  }
}
