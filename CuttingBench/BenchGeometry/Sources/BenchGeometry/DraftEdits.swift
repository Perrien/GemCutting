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
/// Appending can never create a forward reference, and inserting mid-pattern is reachable by appending and
/// then moving, which `moving` already guards.
public func appendingTier(to draft: PatternDraft) -> Result<PatternDraft, DraftRefusal> {
  let used = Set(draft.tiers.map(\.tier))
  var n = 1
  while used.contains("N\(n)") { n += 1 }

  var edited = draft
  edited.tiers.append(
    DraftTier(tier: "N\(n)", part: .pav, angle: 0, indices: [], meet: nil, instructions: nil))
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

  let pieces = typed.split(whereSeparator: { $0 == "," || $0.isWhitespace })
  var indices: [Int] = []
  for piece in pieces {
    guard let index = Int(piece) else {
      return .failure(.indicesNotWholeNumbers(typed: typed))
    }
    indices.append(index)
  }

  let stops = draft.wheel(of: draft.tiers[position])
  for index in indices where index < 0 || index >= stops {
    return .failure(.indexOutOfRange(tier: tier, index: index, wheel: stops))
  }

  // Only the stops that would go, and in the order the author wrote them: a stop still in the list is
  // still there to be named, however the list was rearranged around it.
  let kept = Set(indices)
  for index in draft.tiers[position].indices where !kept.contains(index) {
    let dependents = tiersNaming(tier: tier, index: index, in: draft)
    guard dependents.isEmpty else {
      return .failure(.stopReferenced(tier: tier, index: index, by: dependents))
    }
  }

  var edited = draft
  edited.tiers[position].indices = indices
  return .success(edited)
}

/// Always accepted: a new part moves a named facet rather than removing it, so every reference still
/// resolves.
public func setting(part: Part, ofTier tier: String, in draft: PatternDraft)
  -> Result<PatternDraft, DraftRefusal>
{
  guard let position = draft.position(ofTier: tier) else { return .success(draft) }

  var edited = draft
  edited.tiers[position].part = part
  return .success(edited)
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

// MARK: - The header

/// Stored verbatim, whitespace included. A name is the author's and not the tool's to tidy.
public func setting(name: String, in draft: PatternDraft) -> Result<PatternDraft, DraftRefusal> {
  var edited = draft
  edited.name = name
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
