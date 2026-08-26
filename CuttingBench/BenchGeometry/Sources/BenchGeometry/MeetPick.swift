import FacetKernel
import Foundation
import simd

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
  case complete(Meet)
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
  case .edge(let planes, let corners):
    // A rough plane can never be one of the three names, and selecting an edge commits two of them at
    // once, so the refusal is the same one a click on that facet would state.
    for plane in planes {
      if let name = roughName(solid, plane: plane) {
        return .refused(.roughFacetNotNameable(name: name))
      }
    }
    // Whatever stage the pick was at, and any highlight gone.
    return advanced(state, .edge(planes: planes, corners: corners))

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
  case .success(let meet): return .complete(meet)
  case .failure(let refusal): return .refused(refusal)
  }
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
      + " · click one of \(candidates.count) facets through the point"
  }
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

  switch state.stage {
  case .empty:
    break
  case .oneFacet(let plane):
    named([plane])
  case .edge(let planes, let corners):
    named(planes)
    for corner in corners where solid.polytope.vertices.indices.contains(corner) {
      let point = solid.polytope.vertices[corner]
      markers.append(
        MeetPickMarker(
          kind: .corner,
          label: "end",
          world: SIMD3<Float>(Float(point.x), Float(point.y), Float(point.z)),
          id: "corner-\(corner)"))
    }
  case .point(let planes, let candidates, _):
    named(planes)
    for plane in candidates {
      guard let world = facetCentroid(solid, plane: plane) else { continue }
      markers.append(
        MeetPickMarker(
          kind: .candidate, label: name(solid, plane), world: world, id: "candidate-\(plane)"))
    }
  }

  return markers
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
