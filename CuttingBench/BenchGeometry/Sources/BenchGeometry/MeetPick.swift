import FacetKernel
import Foundation
import simd

/// One end of an anchored point: the meet that names it, or the corner still awaiting a click.
///
/// `named` is a `vertex` triple, or `tcp` for an end standing at the side's axial point. `awaiting`
/// carries the cut planes still available to be its third name, which is what the overlay marks and
/// what the next click is matched against.
public enum MeetPickEnd: Equatable, Sendable {
  case named(Meet)
  case awaiting(corner: Int, candidates: [Int])
}

/// How far the clicks have got. **The corner is a polytope vertex index, never a re-derived
/// position.**
public enum MeetPickStage: Equatable, Sendable {
  case empty
  case oneFacet(plane: Int)
  /// Two facets sharing an edge, and the edge's two corners.
  case edge(planes: [Int], corners: [Int])
  /// A corner, the facets naming it so far, and the cut planes still through it awaiting a third
  /// click.
  case point(planes: [Int], candidates: [Int], corner: Int)
  /// A point anchored part-way along an edge: the edge's two facets, its two corners and its two ends
  /// **both already ordered `from` then `to`**, and the percentage measured from `from`.
  ///
  /// The ordering is settled here, once, so no later step re-derives which end is `from`. `corners` is
  /// in that same order — **not the edge's own ascending order** — so the anchored point is
  /// `corners[0] + percent/100 × (corners[1] - corners[0])`, which is the arithmetic the solver
  /// performs on the finished meet.
  case anchored(planes: [Int], corners: [Int], ends: [MeetPickEnd], percent: Double)
}

/// A meet being built by clicking. `tier` is the row the Meet menu started it from.
public struct MeetPickState: Equatable, Sendable {
  public var tier: String
  public var stage: MeetPickStage

  /// A fresh pick, nothing clicked.
  public init(tier: String) {
    self.tier = tier
    self.stage = .empty
  }
}

/// What one click did to a pick.
public enum MeetPickOutcome: Equatable, Sendable {
  /// The clicks so far, with nothing decided yet.
  case advanced(MeetPickState)
  /// The meet to write into the draft. The window hands this to `setting(meet:ofTier:in:)` and ends
  /// the pick.
  ///
  /// `at` is where the completed pick landed in model space, carried for a caller deriving an angle
  /// from it and ignored by a caller writing a meet.
  case complete(Meet, at: SIMD3<Double>)
  /// This click is refused; the pick is left exactly as it was.
  case refused(DraftRefusal)
  /// The click missed the solid, and the pick is over.
  case cleared
}

/// One click against a pick.
///
/// `solid` is the **intermediate** solid the click was tested against, and `draft` is the whole draft —
/// needed only to ask whether the picked corner may be written as `tcp`.
public func advancing(
  _ state: MeetPickState,
  hit: MeetPickHit?,
  solid: BenchSolid,
  draft: PatternDraft
) -> MeetPickOutcome {
  guard let hit else { return .cleared }

  switch hit {
  case .edge(let planes, let corners, let along):
    // A rough plane can never be one of the three names, and selecting an edge commits two of them at
    // once, so the refusal is the same one a click on that facet would state.
    for plane in planes {
      if let name = roughName(solid, plane: plane) {
        return .refused(.roughFacetNotNameable(name: name))
      }
    }
    // An edge with anything other than two corners is not one `meetPickHit` reports; selecting it is
    // still the honest answer, and it is the answer part 4 gave every edge click.
    guard corners.count == 2 else {
      return advanced(state, .edge(planes: planes, corners: corners))
    }
    // **A click in an end zone is a plain vertex at that corner**, completed through part 4's own
    // corner path, so the candidate rule, the rough refusal and the `tcp` question have one
    // implementation. What snapping changes is which corner, never how a corner is spelled.
    if along < MeetPickTuning.endZoneFraction {
      return resolving(state, planes: planes, atCorner: corners[0], solid: solid, draft: draft)
    }
    if along > 1 - MeetPickTuning.endZoneFraction {
      return resolving(state, planes: planes, atCorner: corners[1], solid: solid, draft: draft)
    }
    return anchoring(
      state, planes: planes, corners: corners, along: along, solid: solid, draft: draft)

  case .facet(let plane):
    if let name = roughName(solid, plane: plane) {
      return .refused(.roughFacetNotNameable(name: name))
    }
    return advancing(state, clickedFacet: plane, solid: solid, draft: draft)
  }
}

/// The stages, for a click that resolved to a cut facet.
private func advancing(
  _ state: MeetPickState,
  clickedFacet plane: Int,
  solid: BenchSolid,
  draft: PatternDraft
) -> MeetPickOutcome {
  switch state.stage {
  case .empty:
    return advanced(state, .oneFacet(plane: plane))

  case .oneFacet(let first):
    // The same facet again clears it, so an unwanted first click costs one click to undo.
    if plane == first { return advanced(state, .empty) }

    if let shared = sharedEdge(solid, first, plane) {
      // **Click order, not the edge's own order**: these two are the first two of the three names the
      // author is writing down.
      return advanced(state, .edge(planes: [first, plane], corners: [shared.a, shared.b]))
    }
    if let corner = soleSharedCorner(solid, first, plane) {
      return resolving(state, planes: [first, plane], atCorner: corner, solid: solid, draft: draft)
    }
    // Sharing nothing: the first is dropped and the second highlighted, so a mis-click costs one click
    // and never a reset.
    return advanced(state, .oneFacet(plane: plane))

  case .edge(let planes, let corners):
    let through = corners.filter { carries(solid, plane: plane, corner: $0) }
    if through.count == 1 {
      // Three names are in hand, so this click completes rather than waiting for candidates.
      return completing(
        state, planes: planes + [plane], atCorner: through[0], solid: solid, draft: draft)
    }
    // Through neither end — and through both, which on a convex solid means one of the two facets
    // sharing the edge, since an edge belongs to no others. Either way the edge is dropped and this
    // facet highlighted.
    return advanced(state, .oneFacet(plane: plane))

  case .point(let planes, let candidates, let corner):
    if candidates.contains(plane) {
      return completing(
        state, planes: planes + [plane], atCorner: corner, solid: solid, draft: draft)
    }
    // Anything else drops the point and highlights that facet.
    return advanced(state, .oneFacet(plane: plane))

  case .anchored(let planes, let corners, let ends, let percent):
    // Only the end being named is live: `from` first, then `to`.
    if let k = ends.firstIndex(where: isAwaiting),
      case .awaiting(let corner, let candidates) = ends[k],
      candidates.contains(plane)
    {
      return naming(
        state, planes: planes, corners: corners, ends: ends, at: k, corner: corner, plane: plane,
        percent: percent, solid: solid, draft: draft)
    }
    // Anything else drops the anchor and highlights that facet, the same answer every other stage gives
    // a click that means nothing to it.
    return advanced(state, .oneFacet(plane: plane))
  }
}

/// A corner two clicks have resolved: the third name is filled in when exactly one candidate exists,
/// waited for when several do, and refused when none does.
private func resolving(
  _ state: MeetPickState,
  planes: [Int],
  atCorner corner: Int,
  solid: BenchSolid,
  draft: PatternDraft
) -> MeetPickOutcome {
  let candidates = candidatePlanes(atCorner: corner, named: planes, solid: solid)
  switch candidates.count {
  case 0:
    // The corner cannot be spelled without naming the rough.
    return .refused(.roughDerivedPoint(tier: state.tier))
  case 1:
    // Not a choice, so it is not a click.
    return completing(
      state, planes: planes + candidates, atCorner: corner, solid: solid, draft: draft)
  default:
    return advanced(state, .point(planes: planes, candidates: candidates, corner: corner))
  }
}

/// Three names and the corner they meet at, as the meet they write down or the refusal that stops them.
private func completing(
  _ state: MeetPickState,
  planes: [Int],
  atCorner corner: Int,
  solid: BenchSolid,
  draft: PatternDraft
) -> MeetPickOutcome {
  switch meetPicked(
    planes: planes, atCorner: corner, ofTier: state.tier, solid: solid, draft: draft)
  {
  case .success(let meet):
    guard solid.polytope.vertices.indices.contains(corner) else {
      return .refused(.pickedFacetsDoNotMeet(tier: state.tier))
    }
    return .complete(meet, at: modelPoint(solid.polytope.vertices[corner]))
  case .failure(let refusal): return .refused(refusal)
  }
}

// MARK: - A point anchored part-way along an edge

/// The edge's two corners ordered **`from` then `to`**: the one further from the axis first.
///
/// Distance from the axis is `sqrt(x² + y²)`, the axis being `z`. **Ties go to the endpoint nearer the
/// girdle plane** — the smaller `abs(z)` — and a remaining tie to the corner whose cut planes, as
/// ascending `(tier, index)` pairs, sort first. That last rule is unreachable on any solid in
/// `Design/Patterns/` and exists so the answer is total and stable rather than dependent on vertex order.
///
/// The percentage then reads outside-in, the way the corpus phrases it, and grows monotonically as the
/// point slides, so nothing flips under the pointer.
public func fractionEndOrder(corners: [Int], solid: BenchSolid) -> [Int] {
  corners.sorted { first, second in
    let a = axisPosition(solid, first)
    let b = axisPosition(solid, second)
    if a.radius != b.radius { return a.radius > b.radius }
    if a.height != b.height { return a.height < b.height }
    return cornerSpelling(solid, first).lexicographicallyPrecedes(cornerSpelling(solid, second)) {
      ($0.tier, $0.index) < ($1.tier, $1.index)
    }
  }
}

/// One end of an anchored point, as the meet that names it or the corner still awaiting a click.
///
/// `tcp` when the corner stands at the axial point on this tier's own side, asked of
/// `axialPoint(onTheSideOf:cutBy:)` over the intermediate solid's own tiers and accepted within
/// `MeetPickTuning.axialTolerance`. **The one-`tcp`-per-side rule is deliberately not asked** — that rule
/// governs a top-level datum claim, and a `tcp` standing as a fraction endpoint is not one, which is why
/// every fraction in the corpus reads `to: tcp`.
///
/// Otherwise the cut planes through the corner, minus the two the edge already names, decide it:
/// **none** → `.roughDerivedPoint`, **one** → `.named` with that triple filled in, **more** →
/// `.awaiting` with all of them.
public func fractionEnd(
  atCorner corner: Int,
  named planes: [Int],
  ofTier tier: String,
  solid: BenchSolid,
  draft: PatternDraft
) -> Result<MeetPickEnd, DraftRefusal> {
  guard solid.polytope.vertices.indices.contains(corner) else {
    return .failure(.pickedFacetsDoNotMeet(tier: tier))
  }
  let point = solid.polytope.vertices[corner]
  if let part = draft.tiers.first(where: { $0.tier == tier })?.part,
    let axial = axialPoint(onTheSideOf: part, cutBy: solid.tiers),
    distance(axial, point) <= MeetPickTuning.axialTolerance
  {
    return .success(.named(.tcp))
  }

  let candidates = candidatePlanes(atCorner: corner, named: planes, solid: solid)
  switch candidates.count {
  case 0:
    // The end cannot be spelled without naming the rough.
    return .failure(.roughDerivedPoint(tier: tier))
  case 1:
    // Not a choice, so it is not a click.
    return spelling(solid, planes: planes, third: candidates[0], ofTier: tier)
      .map(MeetPickEnd.named)
  default:
    return .success(.awaiting(corner: corner, candidates: candidates))
  }
}

/// The meet an anchored point writes, once both its ends are named.
///
/// `.fraction(from: ends[0], percent: percent, to: ends[1])`, with the ends in the order
/// `fractionEndOrder` fixed and the percentage already measured from `from`. Returns
/// `.pickedFacetsDoNotMeet` for a pair either of whose ends is still `.awaiting`, which the stage machine
/// never produces and which is still better refused than written as a meet that pins nothing.
public func meetFractionPicked(
  ends: [MeetPickEnd],
  percent: Double,
  ofTier tier: String
) -> Result<Meet, DraftRefusal> {
  guard ends.count == 2, case .named(let from) = ends[0], case .named(let to) = ends[1] else {
    return .failure(.pickedFacetsDoNotMeet(tier: tier))
  }
  return .success(.fraction(from: from, percent: percent, to: to))
}

/// A click that landed part-way along an edge: order the ends, spell each one, and either complete or
/// wait. **The percentage is measured from `from`** — `100 × along` when `from` is `corners[0]` and
/// `100 × (1 - along)` when it is `corners[1]`.
///
/// **Refuses as a whole or not at all.** If either end cannot be spelled the pick is left exactly as it
/// was and the refusal is stated once: an anchored point whose outer end cannot be spelled is not
/// half-placeable, and a partially-built fraction is not a state the author can act on.
private func anchoring(
  _ state: MeetPickState,
  planes: [Int],
  corners: [Int],
  along: Double,
  solid: BenchSolid,
  draft: PatternDraft
) -> MeetPickOutcome {
  let ordered = fractionEndOrder(corners: corners, solid: solid)
  let percent = 100 * (ordered[0] == corners[0] ? along : 1 - along)

  var ends: [MeetPickEnd] = []
  for corner in ordered {
    switch fractionEnd(
      atCorner: corner, named: planes, ofTier: state.tier, solid: solid, draft: draft)
    {
    case .success(let end): ends.append(end)
    case .failure(let refusal): return .refused(refusal)
    }
  }
  return anchored(
    state, planes: planes, corners: ordered, ends: ends, percent: percent,
    at: anchoredPoint(corners: ordered, percent: percent, solid: solid))
}

/// A click on one of the awaiting end's candidates: that end becomes `.named` with the edge's two planes
/// plus the clicked one, **in that order** — the two the author expressed as an edge, then the one they
/// clicked. Completes when no end is left awaiting.
private func naming(
  _ state: MeetPickState,
  planes: [Int],
  corners: [Int],
  ends: [MeetPickEnd],
  at k: Int,
  corner: Int,
  plane: Int,
  percent: Double,
  solid: BenchSolid,
  draft: PatternDraft
) -> MeetPickOutcome {
  switch spelling(solid, planes: planes, third: plane, ofTier: state.tier) {
  case .failure(let refusal):
    return .refused(refusal)
  case .success(let meet):
    var next = ends
    next[k] = .named(meet)
    return anchored(
      state, planes: planes, corners: corners, ends: next, percent: percent,
      at: anchoredPoint(corners: corners, percent: percent, solid: solid))
  }
}

/// The anchored stage, or the meet it writes once no end is left awaiting. **The fraction completes on
/// the click that resolves its last end**, which in the common case is the same click that anchored the
/// point: the outer end has one candidate and the inner end is the axial point, so both resolve without a
/// further click.
private func anchored(
  _ state: MeetPickState,
  planes: [Int],
  corners: [Int],
  ends: [MeetPickEnd],
  percent: Double,
  at point: SIMD3<Double>?
) -> MeetPickOutcome {
  guard ends.contains(where: isAwaiting) else {
    guard let point else { return .refused(.pickedFacetsDoNotMeet(tier: state.tier)) }
    switch meetFractionPicked(ends: ends, percent: percent, ofTier: state.tier) {
    case .success(let meet): return .complete(meet, at: point)
    case .failure(let refusal): return .refused(refusal)
    }
  }
  return advanced(state, .anchored(planes: planes, corners: corners, ends: ends, percent: percent))
}

/// Where an anchored point sits: `corners[0] + percent/100 × (corners[1] - corners[0])`, which is the
/// arithmetic the solver performs on the finished meet and the reason `corners` is stored `from` then
/// `to`. `nil` for a pair of corner indices the polytope does not carry.
func anchoredPoint(corners: [Int], percent: Double, solid: BenchSolid) -> SIMD3<Double>? {
  guard corners.count == 2, corners.allSatisfy(solid.polytope.vertices.indices.contains) else {
    return nil
  }
  let from = modelPoint(solid.polytope.vertices[corners[0]])
  let to = modelPoint(solid.polytope.vertices[corners[1]])
  return from + (percent / 100) * (to - from)
}

/// A fraction endpoint's own `vertex` triple: the two planes the edge already names, then the third.
/// Every one of the three must be a cut facet, or the point cannot be spelled without the rough.
private func spelling(
  _ solid: BenchSolid, planes: [Int], third: Int, ofTier tier: String
) -> Result<Meet, DraftRefusal> {
  var refs: [FacetRef] = []
  for plane in planes + [third] {
    guard case .cut(let ref) = solid.origin[plane] else {
      return .failure(.roughDerivedPoint(tier: tier))
    }
    refs.append(ref)
  }
  return .success(.vertex(facets: refs))
}

/// Whether an end is still waiting for the click that names it.
private func isAwaiting(_ end: MeetPickEnd) -> Bool {
  if case .awaiting = end { return true }
  return false
}

/// How far a corner stands from the axis, and how far from the girdle plane — the two measurements
/// `fractionEndOrder` reads, in that order.
private func axisPosition(_ solid: BenchSolid, _ corner: Int) -> (radius: Double, height: Double) {
  guard solid.polytope.vertices.indices.contains(corner) else { return (0, 0) }
  let point = solid.polytope.vertices[corner]
  return ((point.x * point.x + point.y * point.y).squareRoot(), abs(point.z))
}

/// Every cut facet through a corner as an ascending `(tier, index)` pair — the last tie-break in
/// `fractionEndOrder`, and never a position.
private func cornerSpelling(
  _ solid: BenchSolid, _ corner: Int
) -> [(tier: String, index: Int)] {
  candidatePlanes(atCorner: corner, named: [], solid: solid)
    .compactMap { plane -> (tier: String, index: Int)? in
      guard case .cut(let ref) = solid.origin[plane] else { return nil }
      return (ref.tier, ref.index)
    }
    .sorted { ($0.tier, $0.index) < ($1.tier, $1.index) }
}

/// The cut planes still available to name a corner: every plane whose polygon ring carries that corner,
/// minus the ones already named, minus every rough plane, ascending.
///
/// **A separate function because it is the whole of the rule**, and the auto-filled third name and the
/// rough-derived refusal are both read straight off its count.
public func candidatePlanes(atCorner corner: Int, named: [Int], solid: BenchSolid) -> [Int] {
  solid.polytope.facets.keys.sorted().filter { plane in
    guard carries(solid, plane: plane, corner: corner) else { return false }
    guard !named.contains(plane) else { return false }
    guard case .cut = solid.origin[plane] else { return false }
    return true
  }
}

/// The meet three named planes and the corner they meet at write down, or the refusal that stops
/// them.
///
/// In this order: every plane must be a cut facet, or `.roughDerivedPoint`; the three planes' own
/// intersection must exist and sit within `triplePointTolerance` of the corner, or
/// `.pickedFacetsDoNotMeet`; then `tcp` if the corner is the axial point on this tier's own side **and** a
/// top-level `tcp` there fires no `secondTCPOnSide`; otherwise the `vertex` triple **in click order**,
/// which is the author's own statement about the stone and is not sorted.
public func meetPicked(
  planes: [Int],
  atCorner corner: Int,
  ofTier tier: String,
  solid: BenchSolid,
  draft: PatternDraft
) -> Result<Meet, DraftRefusal> {
  var refs: [FacetRef] = []
  for plane in planes {
    guard case .cut(let ref) = solid.origin[plane] else {
      return .failure(.roughDerivedPoint(tier: tier))
    }
    refs.append(ref)
  }
  guard planes.count == 3, solid.polytope.vertices.indices.contains(corner) else {
    return .failure(.pickedFacetsDoNotMeet(tier: tier))
  }

  // The kernel's own three-plane solve, never a second copy of it.
  guard
    let meeting = triplePoint(
      solid.planes[planes[0]], solid.planes[planes[1]], solid.planes[planes[2]])
  else {
    return .failure(.pickedFacetsDoNotMeet(tier: tier))
  }
  let point = solid.polytope.vertices[corner]
  guard distance(meeting, point) <= MeetPickTuning.triplePointTolerance else {
    return .failure(.pickedFacetsDoNotMeet(tier: tier))
  }

  if isTCPAvailable(atCorner: point, ofTier: tier, solid: solid, draft: draft) {
    return .success(.tcp)
  }
  return .success(.vertex(facets: refs))
}

/// Whether this corner is the free datum on this tier's own side.
///
/// Both halves are asked of the kernel: **where the axis is crossed** comes from
/// `axialPoint(onTheSideOf:cutBy:)` over the intermediate solid's own tiers — which are the tiers cut
/// before the picking tier by construction — and **whether the datum is still free** comes from
/// `structuralFindings`, which already carries the one-`tcp`-per-side rule. Nothing here restates either.
private func isTCPAvailable(
  atCorner point: (x: Double, y: Double, z: Double),
  ofTier tier: String,
  solid: BenchSolid,
  draft: PatternDraft
) -> Bool {
  guard let part = draft.tiers.first(where: { $0.tier == tier })?.part else { return false }
  guard let axial = axialPoint(onTheSideOf: part, cutBy: solid.tiers) else { return false }
  guard distance(axial, point) <= MeetPickTuning.axialTolerance else { return false }

  // The draft this tier's meet would be `tcp` in. A draft no tier of which has a meet has no pattern to
  // check, and so no `tcp`.
  var candidate = draft
  guard let k = candidate.position(ofTier: tier) else { return false }
  candidate.tiers[k].meet = .tcp
  guard let pattern = candidate.displayPattern else { return false }

  // Only this tier's own second-`tcp` finding: any other finding in that list belongs to a fault the
  // author is already being shown.
  return !structuralFindings(pattern).contains { finding in
    guard case .secondTCPOnSide(let named, _) = finding, named == tier else { return false }
    return true
  }
}

/// What the status strip says while a pick is in progress — the next click, in words. Never `nil`: a
/// pick always has a next step.
public func meetPickPrompt(_ state: MeetPickState, solid: BenchSolid) -> String {
  let opening = "Picking \(state.tier)'s meet · "
  switch state.stage {
  case .empty:
    return opening + "click a facet, or an edge"
  case .oneFacet(let plane):
    return opening + "\(name(solid, plane)) · click a second facet"
  case .edge(let planes, _):
    return opening
      + "edge \(name(solid, planes[0])) – \(name(solid, planes[1])) · "
      + "click a third facet through one of its ends"
  case .point(let planes, let candidates, _):
    return opening
      + planes.map { name(solid, $0) }.joined(separator: " · ")
      + " · click a third facet through the point — \(offered(solid, candidates))"
  case .anchored(let planes, _, let ends, let percent):
    let along =
      "\(percentText(percent))% along \(name(solid, planes[0])) – \(name(solid, planes[1]))"
    // A pick with both ends named has already completed, so the `complete` clause is unreachable — and
    // saying so is better than indexing into a list with nothing awaiting in it.
    guard let k = ends.firstIndex(where: isAwaiting),
      case .awaiting(_, let candidates) = ends[k]
    else {
      return opening + along + " · complete"
    }
    return opening + along
      + " · click a facet through the \(k == 0 ? "from" : "to") end"
      + " — \(offered(solid, candidates))"
  }
}

/// The facets on offer, named, as `A`, `A or B`, `A, B or C`.
///
/// **Naming them is the whole message.** The overlay marks each candidate at its facet's centroid, which
/// can sit far from the clicked corner or outside the frame altogether, so a count alone leaves the
/// author hunting for markers they may not be able to see. The list is not truncated: a corner offers
/// only the cut facets passing through it, minus those already clicked, and a label is short.
private func offered(_ solid: BenchSolid, _ candidates: [Int]) -> String {
  let names = candidates.map { name(solid, $0) }
  guard let last = names.last else { return "no facet" }
  guard names.count > 1 else { return last }
  return names.dropLast().joined(separator: ", ") + " or " + last
}

/// One thing the overlay draws over the viewport.
public struct MeetPickMarker: Identifiable, Equatable, Sendable {
  public enum Kind: Equatable, Sendable {
    /// A facet the author clicked, and its position in click order, from 1.
    case named(Int)
    /// A facet still awaiting a third click.
    case candidate
    /// One end of the selected edge.
    case corner
    /// The point being placed, and the percentage it currently reads.
    case anchor(Double)
  }
  public var kind: Kind
  /// The facet's name as `facetLabel` gives it, or `end` for a corner.
  public var label: String
  public var world: SIMD3<Float>
  /// Stable across a rebuild, so a `ForEach` keeps its identity.
  public var id: String

  public init(kind: Kind, label: String, world: SIMD3<Float>, id: String) {
    self.kind = kind
    self.label = label
    self.world = world
    self.id = id
  }
}

/// The chips and dots the overlay draws. Empty for a stage with nothing marked.
public func meetPickMarkers(_ state: MeetPickState, solid: BenchSolid) -> [MeetPickMarker] {
  var markers: [MeetPickMarker] = []

  func named(_ planes: [Int]) {
    for (k, plane) in planes.enumerated() {
      guard let world = facetCentroid(solid, plane: plane) else { continue }
      markers.append(
        MeetPickMarker(
          kind: .named(k + 1), label: name(solid, plane), world: world, id: "named-\(plane)"))
    }
  }

  func rings(_ corners: [Int]) {
    for corner in corners where solid.polytope.vertices.indices.contains(corner) {
      let point = solid.polytope.vertices[corner]
      markers.append(
        MeetPickMarker(
          kind: .corner,
          label: "end",
          world: SIMD3<Float>(Float(point.x), Float(point.y), Float(point.z)),
          id: "corner-\(corner)"))
    }
  }

  func candidates(_ planes: [Int]) {
    for plane in planes {
      guard let world = facetCentroid(solid, plane: plane) else { continue }
      markers.append(
        MeetPickMarker(
          kind: .candidate, label: name(solid, plane), world: world, id: "candidate-\(plane)"))
    }
  }

  switch state.stage {
  case .empty:
    break
  case .oneFacet(let plane):
    named([plane])
  case .edge(let planes, let corners):
    named(planes)
    rings(corners)
  case .point(let planes, let waiting, _):
    named(planes)
    candidates(waiting)
  case .anchored(let planes, let corners, let ends, let percent):
    named(planes)
    rings(corners)
    // The point itself, at the percentage's own position between the two ends — the arithmetic the
    // solver performs on the finished meet, and the reason `corners` is stored `from` then `to`.
    if let point = anchoredPoint(corners: corners, percent: percent, solid: solid) {
      markers.append(
        MeetPickMarker(
          kind: .anchor(percent),
          label: "\(percentText(percent))%",
          world: SIMD3<Float>(Float(point.x), Float(point.y), Float(point.z)),
          id: "anchor"))
    }
    // **Only the end being named**, never both at once: the prompt is asking about one of them.
    if let k = ends.firstIndex(where: isAwaiting), case .awaiting(_, let waiting) = ends[k] {
      candidates(waiting)
    }
  }

  return markers
}

private func worldPoint(_ point: (x: Double, y: Double, z: Double)) -> SIMD3<Float> {
  SIMD3<Float>(Float(point.x), Float(point.y), Float(point.z))
}

/// A polytope corner as a vector, at full precision. `worldPoint` narrows to `Float` for the renderer;
/// this one is what arithmetic over the picked point is done in.
private func modelPoint(_ point: (x: Double, y: Double, z: Double)) -> SIMD3<Double> {
  SIMD3<Double>(point.x, point.y, point.z)
}

/// The stone as it stands before `tier` is cut — the solid a meet for that tier may name facets on, and
/// the solid its clicks are tested against.
///
/// The prefix is the number of draft tiers **before** this one that carry a meet, because
/// `displayPattern` drops the rest in file order. Delegates to `benchSolid(_:at:)`, so **nothing
/// re-solves**. A label the draft does not carry, and a first tier, both give the prefix `0` — the bare
/// prism.
public func intermediateBenchSolid(
  before tier: String,
  draft: PatternDraft,
  full: BenchSolid
) -> BenchSolid {
  let position = draft.position(ofTier: tier) ?? 0
  let prefix = draft.tiers.prefix(position).filter { $0.meet != nil }.count
  return benchSolid(full, at: PlaybackStep(completeTiers: prefix, label: "before \(tier)", id: 0))
}

// MARK: - What the solid says about two facets

/// The same pick, one stage further on.
private func advanced(_ state: MeetPickState, _ stage: MeetPickStage) -> MeetPickOutcome {
  var next = state
  next.stage = stage
  return .advanced(next)
}

/// The rough facet's own name, or `nil` for a cut facet.
private func roughName(_ solid: BenchSolid, plane: Int) -> String? {
  guard case .rough(let rough) = solid.origin[plane] else { return nil }
  return rough.name
}

/// The edge two facets share, from the one enumeration the wireframe draws — or `nil` when they share
/// none. Never ambiguous: the drawn solid is convex, so two facets share at most one edge.
private func sharedEdge(_ solid: BenchSolid, _ first: Int, _ second: Int) -> SolidEdge? {
  solidEdges(solid).first { $0.planes.contains(first) && $0.planes.contains(second) }
}

/// The single corner two facets share, or `nil` when they share none or a whole edge of them.
private func soleSharedCorner(_ solid: BenchSolid, _ first: Int, _ second: Int) -> Int? {
  guard let a = solid.polytope.facets[first], let b = solid.polytope.facets[second] else {
    return nil
  }
  let shared = Set(a).intersection(b)
  guard shared.count == 1 else { return nil }
  return shared.first
}

/// Whether this facet's polygon carries that corner.
private func carries(_ solid: BenchSolid, plane: Int, corner: Int) -> Bool {
  solid.polytope.facets[plane]?.contains(corner) ?? false
}

/// A facet's name as the tier table and the facet readout give it, or the plane's own index for a plane
/// with no `origin` entry — which nothing can click, and which is still better said than invented.
private func name(_ solid: BenchSolid, _ plane: Int) -> String {
  solid.origin[plane].map(facetLabel) ?? "plane \(plane)"
}

private func distance(
  _ a: (x: Double, y: Double, z: Double), _ b: (x: Double, y: Double, z: Double)
) -> Double {
  let dx = a.x - b.x
  let dy = a.y - b.y
  let dz = a.z - b.z
  return (dx * dx + dy * dy + dz * dz).squareRoot()
}
