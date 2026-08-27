# 4 · Cutting Bench Authoring — Part 4: Meet Picking

Status: **part 4 completed** (2026-08-27). Not archived: `4-Cutting-Bench-Authoring-5-Fraction-Meets`
archives this plan, every sibling part, the exploration and the folded-in ticket.

**Archived 2026-08-27 — trust the code, not this plan's edge-click rule.** D10 below says a click on an
edge *selects it and marks its endpoints, whatever stage the pick is at*, and the *Done when* item
matching it expects `.advanced` at `.edge` from every stage. Part 5 replaced that: an edge click now
snaps to that end's corner when it lands in the outer fifth of the edge, and anchors a point part-way
along it otherwise, so **no edge click reaches the `.edge` stage at all**. That stage is still reached,
by two facet clicks sharing an edge, and everything this plan says about it from there — the third facet
through one end, the candidate rule, the rough refusals — still describes what shipped.

## Parts

**For the owner and the next authoring session — not for the executor.** Nothing in this plan's tasks
refers to another part.

1. `4-Cutting-Bench-Authoring-1-Draft-And-Tier-Editing` — the editable draft, and every tier edit that
   needs no click in the viewport: add, delete, reorder, rename, angle, part, index stops, instructions,
   the header fields, and the three meet forms that take no picking. Every structural edit that would
   orphan a reference is refused, states its reason and is logged. **(shipped)**
2. `4-Cutting-Bench-Authoring-2-Validation-And-State` — the cheap half of validation on every committed
   edit, the expensive half cached per tier and invalidated from the first edited tier onward, and the
   `state` switch that refuses `finished` while any finding fires. **(shipped)**
3. `4-Cutting-Bench-Authoring-3-Symmetry-And-Wheel` — folds, mirroring and seed stops per tier row, with
   `indices` filled in as the expansion and a raw-index escape; the index-gear popup and its
   out-of-range refusal. **(shipped)**
4. `4-Cutting-Bench-Authoring-4-Meet-Picking` — building a meet by clicking facets: the intermediate
   solid with the finished stone as a wireframe ghost, the facet-and-edge click machine, the third click
   where more than three planes pass through the point, the axial-point case, and the rough refusals.
   Ships the completion bar — `Easy Octagon` cut in the app. ← this part
5. `4-Cutting-Bench-Authoring-5-Fraction-Meets` — a point anchored part-way along an edge: the 10% end
   zones, the outer endpoint as the start of the measurement, the editable percentage, and 0 or 100
   collapsing to a plain vertex. Closes the folded-in ticket and archives the set.

| Exploration ID | Part |
|---|---|
| S1 | 4 |
| S2 | 5 |
| S3 | 1 |
| I1 | 1 — **restated in 4**, which writes a picked meet through the same funnel |
| I2 | 1 |
| I3 | 1 |
| I4 | 1 |
| I5 | 2 |
| I6 | 1 |
| U1 | 2 |
| U2 | 3 |
| U3 | 3 |
| U4 | 3 |
| U5 | 4 |
| U6 | 5 |
| U7 | 4 |
| U8 | 5 |
| U9 | 5 |
| U10 | 4 |
| U11 | 4 |
| U12 | 2 |
| U13 | 1 — **restated in 2, 3, 4 and 5**, each of which adds refusals |

**One boundary clarification against part 3's copy.** The rule that a click within the edge grab radius
takes the edge rather than the facet is part of the click machine, and it lands **here**, with part 4,
because the state machine has to have a defined answer for a click on an edge. What part 4 does with a
selected edge is mark its two endpoints and wait for a third facet; **anchoring a point part-way along
that edge, and the 10% end zones that go with it, stay in part 5**. Nothing else moved: every ID sits
where the owner agreed.

## Context

**This is the part the whole tool exists for.** Everything shipped so far edits a pattern's numbers: the
author types an angle, a list of index stops, a fold count, a gear. What is still impossible is the thing
that cannot be typed — saying *this tier is cut until it reaches that corner of the stone* by clicking the
corner. Today the only meets the app can set are the three that need no picking (`size`, `tcp`, `girdle`),
so a pattern with a `vertex` meet — which is most of them — can be opened and edited but not authored.
When this part lands, `Easy Octagon` can be cut from a new document with no text editor involved, which is
the bar this whole exploration was written against.

What already exists, verified by reading during this session:

- **The click already reaches a facet.** `BenchWindow.swift:235` (`private func pick(at point: CGPoint, in
  size: CGSize)`) unprojects the click through `benchRay` and calls `pickFacet`, and
  `BenchPick.swift:12` (`public func pickFacet(`) is an exact slab test over the half-spaces that returns
  the plane index, the `FacetOrigin` and the entry point pulled onto its plane. It refuses to name a plane
  with no `origin` entry and one the polytope dropped, so **it can never name a facet the renderer did not
  draw**.
- **A drag under 3 points is already a click and not an orbit.** `MetalViewport.swift:11`
  (`static let clickSlopPoints: CGFloat = 3`), which is what lets orbiting stay live during a pick without
  any new code.
- **The intermediate solid is already reachable without re-solving.** `Playback.swift:127`
  (`public func benchSolid(_ full: BenchSolid, at step: PlaybackStep) -> BenchSolid`) re-expands a prefix
  of the solve's own tiers through `planes(of:)`, and its doc comment states that depths do not shift
  because a meet may only name an earlier tier. So the stone as it stands before tier *k* costs one hull
  and no solve.
- **A `Meet?` can already be written into the draft.** `DraftEdits.swift:163`
  (`public func setting(meet: Meet?, ofTier tier: String, in draft: PatternDraft)`) takes a whole `Meet?`
  "so a later part can pass a picked `vertex` or `fraction` without changing this function." This part is
  that later part, and it adds no new setter.
- **Refusals already have one channel.** `RefusalPresenter.swift:24` (`func present(_ refusal: DraftRefusal)`)
  alerts and logs the same sentence at `.notice`, public and unredacted, and `BenchWindow.swift:176`
  (`private func edit(_ actionName: String, _ change: DraftChange) -> Bool`) is the funnel every edit
  passes through.
- **The corner arithmetic is the kernel's, not new.** `Polytope.swift:24` (`public func triplePoint(`)
  solves three planes to a point and returns `nil` when they are singular; `Solver.swift:269`
  (`public func axialPoint(`) gives the axial point on one side from the tiers cut so far; and
  `MeetPoints.swift:103` (`private func world(`) already resolves a stored meet's points against exactly
  the tiers cut before it — this part builds a meet with the same pieces, in the other direction.
- **The structural half of validation is already a callable function.** `BenchFindingsStore.swift:59`
  (`structural = structuralFindings(pattern)`), imported at `BenchFindingsStore.swift:11`
  (`import func FacetKernel.structuralFindings`). It contains the one-`tcp`-per-side check
  (`Validation.swift:15`, `case secondTCPOnSide`), which is how this part answers whether a picked axial
  point may be written as `tcp` without restating the rule.
- **The edge wireframe already exists as a render pass.** `BenchRenderer.swift:205`
  (`if let edgeBuffer, edgeCount > 0 {`) draws every line twice, at an alpha carried in `params.w`, and
  `Shaders.metal:82` (`return float4(u.edgeColor.rgb, u.edgeColor.a * u.params.w);`) is where that alpha
  lands. A ghost wireframe is a third pass over a second buffer — **no `.metal` change at all**.
- **Overlays over the Metal view are an established idiom, three of them.** `BenchRegions.swift:34`–`:40`
  stacks `IndexRingOverlay`, `MeetPointOverlay` and `ProbePathOverlay`, each positioned through
  `BenchCamera.swift:202` (`public func benchScreenPoint(`) so it cannot disagree with the solid, and each
  carrying `.allowsHitTesting(false)` so it does not eat the clicks meant for the facet under it.
- **The app target picks up new files by itself.** `CuttingBench.xcodeproj/project.pbxproj:30`
  (`isa = PBXFileSystemSynchronizedRootGroup;`), so a new `.swift` file in `CuttingBench/CuttingBench/`
  needs no project edit — and `project.pbxproj` is a guardrail this part never touches.

So this is wiring and one pure state machine, not new architecture. The genuinely new code is the click
machine — which of two clicked facets share an edge, which corner a third facet picks out, and which of
the two spellings (`vertex` triple or `tcp`) the picked corner is written as — and that is all pure,
testable in the `BenchGeometry` package, and where nearly all of this plan's tests go.

## Decisions (2026-08-26)

| # | Decision |
|---|---|
| D1 | **A picked meet is written into the draft through the funnel every other edit uses** — `setting(meet:ofTier:in:)`, unchanged. The draft is the app's and the file is the kernel's (**ADR-0003**), and a picked `vertex` is an ordinary edit: one undo entry, one refusal channel. **No new setter, and the app never serialises anything.** |
| D2 | **While a meet is being picked the viewport draws the intermediate solid — the stone as it stands before the picking tier — and the click hits that solid**, not the finished one. A meet is a cutting-time claim, so the facets that may be named are the ones present when that tier is cut; showing exactly those makes an invalid meet unclickable by construction. |
| D3 | **The intermediate solid is built by re-expanding a prefix of the existing solve, never by solving again.** The prefix length is *the number of draft tiers before the picking tier that carry a meet* — because `displayPattern` drops meet-less tiers in file order, that count is exactly the tier's position in the solution. |
| D4 | **A pick for the first tier of a pattern is impossible, and that is correct, not a defect.** The intermediate solid before it is the bare prism, every facet of which is rough, so every click is refused with its reason. The three forms that need no picking are in the Meet menu part 1 shipped, and `Easy Octagon`'s `G1` is `size`. |
| D5 | **The finished stone is drawn over the intermediate solid in edges only** — a third edge pass in the renderer, over a second buffer, depth testing off, at alpha **0.35**. `edge_fragment` already multiplies its colour's alpha by `params.w`, so this needs **no `.metal` change**. 0.35 is a build constant and not a preference. |
| D6 | **The edge grab radius is 8 points, measured in screen space, and it is one build constant.** A click within 8 points of a visible edge resolves as that edge; anything else resolves as the front-most facet. Tuned during testing by editing the number, exactly as the rough's dimensions are. |
| D7 | **Only a *visible* edge can take a click: one whose two facets include at least one facing the camera.** The drawn solid is convex, so that test is exact — a silhouette edge has one front facet and qualifies, an edge wholly round the back has none and does not. Without it a click aimed at a facet would be stolen by an edge hidden behind the stone. |
| D8 | **Opacity changes what you can see, never what you can click.** The hit test reads the planes and the polytope only; the opacity slider never enters it. |
| D9 | **The click machine, in full.** Stage `empty`: a facet click highlights it. Stage `one facet`: the same facet again clears it; a facet sharing an edge selects that edge and marks its two endpoints; a facet sharing exactly one corner and no edge resolves that corner; a facet sharing nothing **drops the first and highlights the second**, so a mis-click costs one click and never a reset. Stage `edge`: a third facet through exactly one endpoint completes the pick at that endpoint; a third facet through neither drops the edge and highlights that facet. Stage `point`: a click on one of the waiting candidates completes the pick; a click on anything else drops the point and highlights that facet. A click that misses the solid **clears the pick**. |
| D10 | **A click on an edge selects it and marks its endpoints, whatever stage the pick is at, and clears any highlight.** Anchoring a point part-way along the selected edge is part 5's work and is not in this part. |
| D11 | **Two facets can share at most one edge, and cannot share two corners without sharing the edge between them**, because the drawn solid is an intersection of half-spaces and therefore convex. So "their common edge" is never ambiguous and needs no tie-break. |
| D12 | **The resolved point is always a corner of the drawn solid, held as a polytope vertex index** — never a re-derived world position. Every path into it (two facets sharing one corner; an edge plus a third facet through one end) lands on a corner by construction, which is exactly what a `vertex` meet is. |
| D13 | **The third name is filled in without a click only when exactly one candidate exists.** Candidates are the planes passing through the resolved corner, minus the two already named, minus every rough plane. **None** → the pick is refused, because the corner cannot be spelled without naming the rough. **One** → filled in, which is not a choice. **More than one** → the pick waits for a third click and the candidates are marked. The app never names a facet the author did not click. |
| D14 | **A click on a rough facet is refused, stating the reason** — rough names are for display only and a saved meet may never reference one. A tier that needs a rough reference is unexpressible rather than writable. |
| D15 | **The test for a rough-derived point is on the three names, not on every plane through the corner.** A corner three cut facets do name is written even if a rough plane also passes through it: the stored meet resolves to those three planes' own intersection and the rough never enters the arithmetic. A corner that *cannot* be named by three cut facets is refused (D13). |
| D16 | **A picked corner is written as `tcp` when it is the axial point on the tier's own side and a top-level `tcp` there fires no `secondTCPOnSide`; otherwise as the `vertex` triple the author clicked.** Whether it is the axial point is asked of the kernel's own `axialPoint(onTheSideOf:cutBy:)` and never re-derived. Whether the datum is free is asked of `structuralFindings`, which already contains the check — **the app does not restate that rule**. |
| D17 | **The datum-already-taken case needs no message and no extra click.** Every completion path has three clicked names in hand by construction, so when `tcp` is unavailable the vertex triple the author clicked is written instead — which is what "asks for three facets" amounts to once they have already been given. |
| D18 | **Three named planes that do not meet at a point refuse the pick, naming the tier.** Unreachable through a corner of a real solid; written anyway, because writing a meet that pins nothing is worse than a refusal the author can see. |
| D19 | **What the pick has clicked is shown as a SwiftUI overlay of chips and dots, not as a second fill colour.** The renderer highlights exactly one plane index (`params.z`), and widening that means a shader change for capped gain; a chip also *names* the facet, which is what the author needs to choose a third. The renderer's orange highlight stays on the most recently clicked facet. |
| D20 | **No occlusion test on those markers**, the same rule `MeetPointOverlay` already states: a facet facing away is reached by orbiting, and a marker the author cannot see is worse than one behind the stone. The opacity slider is how they look inside. |
| D21 | **Anything that changes the drawn solid cancels the pick** — an edit, an undo, a scrub, a granularity change. A plane index means nothing across a rebuild, which is the same reason `selectedPlaneIndex` is already cleared there. |
| D22 | **The pick is started from a new *Pick in viewport…* item in the Meet menu, and cancelled by a Cancel button beside the prompt in the status strip.** Not the Escape key: routing a keystroke out of an `MTKView` inside SwiftUI is engineering around a framework limit for one keystroke, and the button is beside the readout the author is already reading. |
| D23 | **While a pick is in progress the Probe does not trace.** The click belongs to the pick, and a path traced through the intermediate solid while the mode is on would be a picture of a stone the readouts are not describing. The Probe mode itself stays on: the owner turned it on and a pick is not them turning it off. |
| D24 | **Orbiting stays live during a pick and does not cancel it.** No new code: `clickSlopPoints = 3` already separates a drag from a click, and the face-up and face-down toolbar buttons stay live throughout — which is how a facet facing away from the camera is reached. |
| D25 | **Every refusal in this part goes through `DraftRefusal` and the window's one `RefusalPresenter`**, so each is alerted and written to the unified log by `os_log` with no second channel, and each names the offending element. New cases are added to `DraftRefusal` in `PatternDraft.swift`, where the enum is declared, because an enum's cases cannot be added from a second file. |
| D26 | **The completion bar is `Easy Octagon`, cut in the app from a new document and saved, equal to `Design/Patterns/Pattern-Easy-Octagon.json` after decode — every field equal and the tiers in the same order — with identical solved geometry.** Not byte-identical: the format leaves formatting loose on purpose, so matching bytes would constrain the writer for no gain. |

## Tickets closed by this plan

None — closed in the final part.

## Prefactoring

**One task, T1.** `solidMesh` already enumerates the drawn solid's undirected edges, keyed `(min, max)` on
the polytope's vertex indices, at `SolidMesh.swift:85`–`:94`. The hit test needs the same enumeration plus
the two plane indices each edge is shared by, and building a second enumeration beside the first is how the
wireframe and the click come to disagree about what an edge is. T1 extracts it, behaviour-preserving, and
`SolidMeshTests` — which pins the bare prism's 96 edge vertices and Euler's formula over every authored
pattern — is the inverted check: nothing about the mesh may change.

No other prefactor is needed. The pick writes through `setting(meet:ofTier:in:)`, which part 1 already
shaped to take a whole `Meet?` for this purpose; the intermediate solid comes from `benchSolid(_:at:)`,
which part 3's playback already made public; and the refusal channel is already single.

## Approach

Three pure files carry all the thinking: what an edge is, what a click hit, and what the clicks so far
mean. The app then draws the intermediate solid instead of the finished one while a pick runs, stacks one
more overlay, adds one menu item and one strip segment, and hands each completed meet to the funnel it
already has.

### 1. New: `CuttingBench/BenchGeometry/Sources/BenchGeometry/SolidEdges.swift` (pure — no framework, no I/O)

The prefactor's home. One edge of the drawn solid, and the enumeration `solidMesh` currently performs
inline.

```swift
/// One undirected edge of the drawn solid: its two corners, and the two facets that share it.
public struct SolidEdge: Equatable, Sendable {
  /// Indices into `polytope.vertices`, `a < b`. The key `solidMesh` already dedupes on.
  public var a: Int
  public var b: Int
  /// The plane indices whose polygon rings both corners sit on, ascending. **Two on a closed convex
  /// solid**; an edge found on only one ring is still reported, so a caller can see it rather than
  /// having it silently dropped.
  public var planes: [Int]
}

/// Every undirected edge of the drawn solid, in ascending `(a, b)` order.
///
/// Walks each facet's ring in ascending plane-index order and keys each consecutive pair — the closing
/// pair included — as `(min, max)`, so the pair two facets share is emitted once and carries both of
/// their plane indices. **The same enumeration the wireframe draws**, which is what stops a click and a
/// drawn line disagreeing about where an edge is.
public func solidEdges(_ solid: BenchSolid) -> [SolidEdge]
```

`SolidMesh.swift` then loses its own `seenEdges` set and its inline pair loop, and emits its edge vertices
by walking `solidEdges(solid)` instead. **Nothing about the output may change**: the same lines, and the
same order — `solidEdges` returns edges sorted by `(a, b)`, so `SolidMeshTests`'
`testTwoCallsOnOneSolidAgree` and the exact counts at `SolidMeshTests.swift:46`
(`XCTAssertEqual(mesh.edgeVertices.count, 96)`) still hold. If the order does change the test that catches
it is `testEulerHoldsForThePrismAndEveryAuthoredPattern`; treat a failure there as a defect in the
extraction, never as a test to update.

### 2. New: `CuttingBench/BenchGeometry/Sources/BenchGeometry/MeetPickHit.swift` (pure)

What one click resolved to, and the two constants the resolution needs.

```swift
/// The tuning this part's picking runs on. Build constants with no UI and no preference (D6, D5's
/// sibling), tuned by editing the numbers.
public enum MeetPickTuning {
  /// How close, in screen points, a click has to fall to a visible edge for the edge to take it
  /// instead of the facet under the pointer (D6).
  public static let edgeGrabRadiusPoints: Double = 8
  /// How near the picked corner has to be to the side's axial point to be written as `tcp` (D16).
  /// Model-space distance on a solid normalised to a half-width of 1.
  public static let axialTolerance: Double = 1e-6
  /// How near the three named planes' own intersection has to be to the clicked corner (D18).
  public static let triplePointTolerance: Double = 1e-6
}

/// What a click in the viewport resolved to. `nil` from `meetPickHit` is a click that missed the solid.
public enum MeetPickHit: Equatable, Sendable {
  case facet(plane: Int)
  /// A visible edge within the grab radius: the two facets sharing it, and its two corners.
  case edge(planes: [Int], corners: [Int])
}

/// An edge when the click falls within `grabRadiusPoints` of a **visible** one, otherwise the front-most
/// facet, and `nil` for a click that hit neither (D6, D7, D8).
///
/// `click` and `size` are both in view points with **y up** — the coordinates `MTKView` hands
/// `onPick`, which need no flip to reach Metal's NDC. `benchScreenPoint` reports y **down**, so a
/// projected corner is converted back with `(x: sx * width, y: (1 - sy) * height)`; that conversion
/// lives here and nowhere else.
///
/// Edges are considered before facets, and the nearest qualifying edge wins. An edge with either corner
/// behind the camera is skipped — `benchScreenPoint` gives it no screen position, and a segment with one
/// end at infinity has no honest screen distance.
public func meetPickHit(
  _ solid: BenchSolid,
  click: (x: Double, y: Double),
  size: (width: Double, height: Double),
  camera: BenchCameraState,
  grabRadiusPoints: Double = MeetPickTuning.edgeGrabRadiusPoints
) -> MeetPickHit?

/// Whether this edge can be clicked at all: at least one of its facets faces the camera. Exact for the
/// drawn solid, which is an intersection of half-spaces and so convex (D7).
///
/// A facet faces the camera when `dot(plane.n, eye) > plane.d` — the eye is outside that half-space.
public func isVisible(_ edge: SolidEdge, in solid: BenchSolid, eye: SIMD3<Float>) -> Bool

/// A facet's centroid in world space, for placing its marker. `nil` for a plane that is not a facet of
/// this solid — the mean of its ring's corners, so it always lies on the facet.
public func facetCentroid(_ solid: BenchSolid, plane: Int) -> SIMD3<Float>?
```

The facet branch is `pickFacet` unchanged — this function calls it rather than reimplementing the slab
test, so a pick can still never name a facet the renderer did not draw. The eye position comes from
`benchCameraPosition(camera, aspect:)` with `aspect` computed from `size`.

Distance from the click to a segment is the ordinary clamped projection: `t = clamp(dot(click - p0, p1 -
p0) / dot(p1 - p0, p1 - p0), 0, 1)`, then the distance to `p0 + t·(p1 - p0)`. A degenerate segment — both
corners projecting to the same point, which an edge seen exactly end-on does — falls out as the distance
to `p0`, which is right and needs no special case.

### 3. New: `CuttingBench/BenchGeometry/Sources/BenchGeometry/MeetPick.swift` (pure)

The state machine, the meet it produces, and the two derived displays the window reads.

```swift
/// How far the clicks have got. **The corner is a polytope vertex index, never a re-derived
/// position** (D12).
public enum MeetPickStage: Equatable, Sendable {
  case empty
  case oneFacet(plane: Int)
  /// Two facets sharing an edge, and the edge's two corners.
  case edge(planes: [Int], corners: [Int])
  /// A corner, the facets naming it so far, and the cut planes still through it awaiting a third
  /// click (D13).
  case point(planes: [Int], candidates: [Int], corner: Int)
}

/// A meet being built by clicking. `tier` is the row the Meet menu started it from.
public struct MeetPickState: Equatable, Sendable {
  public var tier: String
  public var stage: MeetPickStage

  /// A fresh pick, nothing clicked.
  public init(tier: String)
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
  /// The click missed the solid, and the pick is over (D9).
  case cleared
}

/// One click against a pick (D9, D10, D13, D14).
///
/// `solid` is the **intermediate** solid the click was tested against, and `draft` is the whole draft —
/// needed only to ask whether the picked corner may be written as `tcp` (D16).
public func advancing(
  _ state: MeetPickState,
  hit: MeetPickHit?,
  solid: BenchSolid,
  draft: PatternDraft
) -> MeetPickOutcome

/// The cut planes still available to name a corner: every plane whose polygon ring carries that corner,
/// minus the ones already named, minus every rough plane, ascending (D13, D15).
///
/// **A separate function because it is the whole of D13's rule**, and the auto-filled third name and the
/// rough-derived refusal are both read straight off its count.
public func candidatePlanes(atCorner corner: Int, named: [Int], solid: BenchSolid) -> [Int]

/// The meet three named planes and the corner they meet at write down, or the refusal that stops
/// them (D13, D15, D16, D18).
///
/// In this order: every plane must be a cut facet, or `.roughDerivedPoint`; the three planes' own
/// intersection must exist and sit within `triplePointTolerance` of the corner, or `.pickedFacetsDoNotMeet`;
/// then `tcp` if the corner is the axial point on this tier's own side **and** a top-level `tcp` fires no
/// `secondTCPOnSide`; otherwise the `vertex` triple **in click order**, which is the author's own
/// statement about the stone and is not sorted.
public func meetPicked(
  planes: [Int],
  atCorner corner: Int,
  ofTier tier: String,
  solid: BenchSolid,
  draft: PatternDraft
) -> Result<Meet, DraftRefusal>

/// The stone as it stands before `tier` is cut — the solid a meet for that tier may name facets on, and
/// the solid its clicks are tested against (D2, D3).
///
/// The prefix is the number of draft tiers **before** this one that carry a meet, because
/// `displayPattern` drops the rest in file order. Delegates to `benchSolid(_:at:)`, so **nothing
/// re-solves**. A label the draft does not carry, and a first tier, both give the prefix `0` — the bare
/// prism (D4).
public func intermediateBenchSolid(
  before tier: String,
  draft: PatternDraft,
  full: BenchSolid
) -> BenchSolid

/// What the status strip says while a pick is in progress — the next click, in words (D22's readout).
/// Never `nil`: a pick always has a next step.
public func meetPickPrompt(_ state: MeetPickState, solid: BenchSolid) -> String

/// The chips and dots the overlay draws (D19, D20). Empty for a stage with nothing marked.
public func meetPickMarkers(_ state: MeetPickState, solid: BenchSolid) -> [MeetPickMarker]

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
}
```

**`axialPoint(onTheSideOf:cutBy:)` is asked with `solid.tiers`** — the intermediate solid's own tiers *are*
the tiers cut before the picking tier, by construction, so there is no second prefix to compute and no
chance of the two disagreeing.

**The `tcp` question is asked of the structural half, never restated.** `meetPicked` builds the candidate
draft — this tier's meet set to `.tcp` — takes its `displayPattern`, and calls `structuralFindings` on it,
looking only for `.secondTCPOnSide(tier: thisTier, _)`. Any other finding in that list belongs to some
other fault the author is already being shown and is not this function's business. A `nil`
`displayPattern` — a draft where no tier has a meet at all — means no `tcp` and falls through to the
`vertex` triple.

**The prompt's four sentences, verbatim**, with `<tier>` the picking tier and each facet named by
`facetLabel`:

- `empty` — `Picking <tier>'s meet · click a facet, or an edge`
- `oneFacet` — `Picking <tier>'s meet · <name> · click a second facet`
- `edge` — `Picking <tier>'s meet · edge <nameA> – <nameB> · click a third facet through one of its ends`
- `point` — `Picking <tier>'s meet · <nameA> · <nameB> · click one of <n> facets through the point`

### 4. `CuttingBench/BenchGeometry/Sources/BenchGeometry/PatternDraft.swift` (edit)

Three cases onto `DraftRefusal`, after `case finishedWithSolveStoppedShort` at `:196`, and three arms onto
`message` at `:199` (`public var message: String {`). Nothing else in the file changes.

```swift
/// A click on a facet of the rough, which a meet may never name (D14).
case roughFacetNotNameable(name: String)
/// A corner no three cut facets name — every candidate through it is a facet of the rough (D13, D15).
case roughDerivedPoint(tier: String)
/// Three named planes that pin no point (D18).
case pickedFacetsDoNotMeet(tier: String)
```

Their sentences, verbatim — each names the offending element, as every case in this enum does:

- `roughFacetNotNameable` — `"\(name) is part of the rough, not the stone. A meet may only name facets
  the pattern cuts."`
- `roughDerivedPoint` — `"\(tier)'s meet cannot be aimed at that point: naming it would need a facet of
  the rough, which is a build constant with no design meaning."`
- `pickedFacetsDoNotMeet` — `"\(tier)'s three named facets do not meet at a point."`

### 5. `CuttingBench/CuttingBench/BenchRenderer.swift` (edit)

The ghost pass (D5). One constant, one setter, one stored buffer pair, one loop.

- Beside `highlightedPlaneIndex` at `:33` (`var highlightedPlaneIndex: Int?`), add:
  `/// How strongly the finished stone's wireframe shows while a meet is being picked (D5).`
  `static let ghostEdgeAlpha: Float = 0.35`
- Beside `edgeBuffer`/`edgeCount` at `:44`–`:45`, add `ghostEdgeBuffer: MTLBuffer?` and
  `ghostEdgeCount = 0`.
- Beside `setMesh` at `:136` (`func setMesh(_ mesh: SolidMesh) {`), add
  `func setGhostMesh(_ mesh: SolidMesh?)`, which fills those two from `mesh?.edgeVertices` through the
  same `makeBuffer` and clears them for `nil`. **Only the edges** — the ghost is never filled.
- After the existing edge block ends at `:221`, add a third block: if `ghostEdgeBuffer` and
  `ghostEdgeCount > 0`, set the edge pipeline and that buffer, `uniforms.params.w =
  BenchRenderer.ghostEdgeAlpha`, `depthAlways`, one `drawPrimitives(type: .line, …)`.

**Last of the three, and depth-always**, so the ghost shows through the intermediate solid rather than
being hidden inside it — which is the whole point of drawing it. It reuses `edgeColor`, so it tracks light
and dark appearance with everything else and needs no new colour.

### 6. `CuttingBench/CuttingBench/MetalViewport.swift` (edit)

`BenchMetalView` is untouched — the mouse handling already does what a pick needs (D24).

`MetalViewport` gains two properties beside `mesh` and `generation` at `:56`–`:58`:

```swift
/// The finished stone's mesh, drawn in edges only while a meet is being picked, or `nil` for none.
let ghostMesh: SolidMesh?
/// Bumped whenever `ghostMesh` changes, including to and from `nil`.
let ghostGeneration: Int
```

`Coordinator` gains `var uploadedGhost: Int?`, and `updateNSView` uploads the ghost on the same
generation-comparison rule the mesh already uses at `:93` (`if context.coordinator.uploaded !=
generation {`) — a second `if`, calling `renderer.setGhostMesh(ghostMesh)`. Two counters rather than one:
the two meshes change on different events and comparing arrays of vertices is what the counters exist to
avoid.

### 7. `CuttingBench/CuttingBench/BenchSolidStore.swift` (edit)

Two additions, no behaviour change.

- Beside `generation` at `:29`, add
  `/// Bumped when the whole stone is rebuilt, which is the only thing the ghost mesh follows.`
  `private(set) var fullGeneration = 0`, and `fullGeneration += 1` inside `setPattern` where `fullFrame`
  is assigned at `:75`.
- A read-only accessor `var fullMesh: SolidMesh { fullFrame.mesh }`, so the window can hand the finished
  stone's edges to the viewport without `fullFrame` stopping being private.

`fullGeneration` is deliberately **not** bumped by a scrub: the ghost is the finished stone, and scrubbing
does not change it.

### 8. New: `CuttingBench/CuttingBench/MeetPickOverlay.swift`

The fourth overlay (D19, D20). Modelled on `MeetPointOverlay` — same `GeometryReader`, same
`benchScreenPoint` call, same `.allowsHitTesting(false)`, which is load-bearing: without it the chips eat
the clicks meant for the facet under them.

```swift
/// A pick marker's colour. **Never the only distinction** — every marker carries its label too.
///
/// Neither the accent colour, nor orange, nor any of the four meet-dot colours: those are the cut
/// facets', the highlighted facet's, and a stored meet's points'.
func meetPickMarkerColor(_ kind: MeetPickMarker.Kind) -> Color

struct MeetPickOverlay: View {
  let markers: [MeetPickMarker]
  let camera: BenchCameraState
}
```

- `.named(n)` — a filled chip reading `n · <name>`, in `.blue`.
- `.candidate` — a hollow chip reading `<name>`, in `.blue`, at half opacity, so the set awaiting a click
  reads as offered rather than chosen.
- `.corner` — a small ring, in `.blue`, marking one end of the selected edge. **No text beside it**: the
  ring's shape is what distinguishes it from a chip, and the word `end` twice on one edge says nothing.

The chip is `MeetDotChip`'s look and not a second one, so the viewport and the tier table keep reading as
one thing; `MeetDotChip` is `private` to `BenchRegions.swift` at `:448`, so **the executor makes it
non-private** — no other change to it — rather than writing a second capsule.

It stacks **after** `MeetPointOverlay` and **before** `ProbePathOverlay` in `ViewportRegion` at
`BenchRegions.swift:37`: a pick marker is what the author is doing now and a stored meet's dots are
standing context, while the probe path stays on top for the same reason it already is.

### 9. `CuttingBench/CuttingBench/BenchRegions.swift` (edit)

Four edits, each small.

**`ViewportRegion` at `:8`** gains `let ghostMesh: SolidMesh?`, `let ghostGeneration: Int` and
`let pickMarkers: [MeetPickMarker]`, passes the first two into `MetalViewport` and stacks
`MeetPickOverlay(markers: pickMarkers, camera: camera)` where §8 says.

**`meetMenu` at `:370`** gains one item, below the divider and above `size`, with a divider of its own
under it:

```swift
Button("Pick in viewport…") { startPick(row.tier) }
```

`startPick` is a new `let startPick: (String) -> Void` on `TierTableRegion`, threaded from the window
beside `edit`. **Not `edit`**: starting a pick changes no draft, so it is not a `DraftChange` and must not
register an undo entry.

**`MeetDotChip` at `:448`** loses `private` (§8). Nothing else about it changes.

**`StatusStripRegion` at `:767`** gains two, neither behind `#if DEBUG` — a pick is a normal working state,
not a diagnostic:

```swift
/// What the pick in progress is waiting for, or `nil` when none is running.
let pickPrompt: String?
let cancelPick: () -> Void
```

In `body`, immediately before the `Text(selectedFacet.map …)` line at `:807`: when `pickPrompt` is
non-`nil`, `Text(pickPrompt!)` styled `.primary` — it is the one thing on the strip the author is acting
on — followed by `Button("Cancel", action: cancelPick).buttonStyle(.link)`. The facet text stays exactly as
it is; the two read together, because during a pick the highlighted facet *is* the last thing clicked.

### 10. `CuttingBench/CuttingBench/BenchWindow.swift` (edit)

The window owns the pick, as it owns every other piece of session state.

```swift
/// The meet being built by clicking, or `nil` for no pick in progress. The solid and mesh are held
/// with it: they are the intermediate solid before the picking tier, built once when the pick starts,
/// and every click is tested against that same solid (D2, D21).
@State private var pick: MeetPickSession?
/// Bumped whenever what the viewport draws changes — the store's own rebuilds and the pick's arrival
/// and departure alike. **One counter with one owner**, because `MetalViewport` compares a single `Int`
/// and two independent sources would collide.
@State private var drawGeneration = 0

/// A pick and the stone it is being picked against.
struct MeetPickSession {
  var state: MeetPickState
  var frame: PlaybackFrame
}
```

- Two computed properties: `drawnSolid` is `pick?.frame.solid ?? store.solid`, `drawnMesh` is
  `pick?.frame.mesh ?? store.mesh`. `ViewportRegion` takes those, plus
  `ghostMesh: pick == nil ? nil : store.fullMesh`, `ghostGeneration: store.fullGeneration`,
  `pickMarkers: pick.map { meetPickMarkers($0.state, solid: $0.frame.solid) } ?? []`, and
  `generation: drawGeneration`.
- `.onChange(of: store.generation) { drawGeneration += 1 }` beside the existing
  `.onChange(of: document.pattern, initial: true)` at `:139`, and `drawGeneration += 1` at each of the
  three places `pick` is assigned. Nothing else may bump it.
- `startPick(_ tier: String)` — builds the session:
  `MeetPickSession(state: MeetPickState(tier: tier), frame: playbackFrameForPick)` where the solid is
  `intermediateBenchSolid(before: tier, draft: document.draft, full: store.full)` and the mesh is
  `solidMesh` of it. Also clears `selectedPlaneIndex`, `selectedFacetLabel` and `probe`, because they
  describe the solid that was on screen a moment ago.
- `endPick()` — `pick = nil`, and the same three clears, for the same reason.
- `pick(at:in:)` at `:235` grows one branch at the top, before the existing ray and slab test:

```swift
if let session = pick {
  let hit = meetPickHit(
    session.frame.solid,
    click: (x: Double(point.x), y: Double(point.y)),
    size: (width: Double(size.width), height: Double(size.height)),
    camera: camera)
  switch advancing(session.state, hit: hit, solid: session.frame.solid, draft: document.draft) {
  case .advanced(let next):
    pick?.state = next
    // The highlight follows the last facet clicked, in the solid on screen — which is the pick's.
    selectedPlaneIndex = highlightedPlane(of: next)
    selectedFacetLabel = selectedPlaneIndex.flatMap { session.frame.solid.origin[$0] }.map(facetLabel)
  case .complete(let meet):
    _ = edit("Change Meet") { setting(meet: meet, ofTier: session.state.tier, in: $0) }
    endPick()
  case .refused(let refusal):
    refusals.present(refusal)
  case .cleared:
    endPick()
  }
  return
}
```

  `highlightedPlane(of:)` is a small private helper: the `oneFacet` plane, the last of `planes` for the
  other two stages, and `nil` for `empty`. **The `return` is load-bearing** — while a pick is in progress
  the existing facet-selection and probe path below do not run (D23).

- `afterSolidChanged()` at `:215` gains `pick = nil` and `drawGeneration += 1`, with the reason in one
  clause: a plane index means nothing across a rebuild, so a pick held across one would be clicking a
  solid that no longer exists (D21). It sits with the two lines already there for that reason.
- `TierTableRegion` gains `startPick: startPick(_:)`; `StatusStripRegion` gains
  `pickPrompt: pick.map { meetPickPrompt($0.state, solid: $0.frame.solid) }` and
  `cancelPick: endPick`, in **both** arms of the `#if DEBUG` at `:78`–`:96`.

## Explicitly not doing

- **No anchored point along an edge, no percentage, no `fraction` meet.** Selecting an edge in this part
  marks its two corners and waits for a third facet, and that is all. The 10% end zones, the outer
  endpoint as the start of the measurement, the editable percentage and 0-or-100 collapsing to a plain
  vertex are `4-Cutting-Bench-Authoring-5-Fraction-Meets`.
- **No corner-first picking.** One click on a corner would make the app choose which three of the planes
  there to name whenever more than three meet; clicking the facets says which three explicitly (D13).
- **No greying-out of unavailable facets on the finished solid.** It cannot express a tier whose facets are
  cut away entirely by later tiers — legitimate, and `Observation.tierContributesNoFacets` exists for it —
  so that meet would be unauthorable. The intermediate solid is the answer (D2).
- **No refusal after the click as a teaching device.** An invalid pick is unclickable by construction; the
  refusals in this part are for the rough and for a corner that cannot be spelled, not for a facet that
  simply is not there yet.
- **No second fill colour in the renderer, and no `.metal` change of any kind.** The markers are an
  overlay (D19) and the ghost is a third pass over the existing edge pipeline (D5).
- **No Escape-key handling, and no keyboard shortcut for the pick.** The Cancel button is beside the
  prompt (D22).
- **No generation of a tier's `instructions` from its picked meet.** The field stays a plain stored string
  and absent keeps meaning the author wrote nothing — deliberately, so a generator can be added later
  without being a breaking change.
- **No angle tuning, no tangent-ratio rescale, no rotation, no two-point angle derivation.** All four are
  `5-Cutting-Bench-Angle-Tuning`.
- **No cache, quiet-period or findings work.** A picked meet is an ordinary committed edit and rides the
  machinery part 2 shipped.
- **No reordering or sorting of anything.** The `vertex` triple is stored in click order (§3), tier order
  is never touched, and a typed stop list is never sorted.

## Checks

The protocol's gates apply as written. Three notes on which of them fire here:

- **Gate 1, tests** — `swift test --package-path Kernel --disable-sandbox` is unconditional, and **no task
  in this part touches `Kernel/`**, so it is only ever confirming that nothing broke. The new tests live in
  the `BenchGeometry` package and are run by
  `swift test --package-path CuttingBench/BenchGeometry --disable-sandbox`, which every task below names in
  its own *Done when*.
- **Gate 3, the release build** — conditional on `Kernel/` having been touched, so it never fires.
- **Format, gate 2**, covers `Kernel/` only as written. **Also run
  `xcrun swift-format lint --recursive --strict CuttingBench/BenchGeometry/Sources
  CuttingBench/BenchGeometry/Tests CuttingBench/CuttingBench` and take it clean**, which is what parts 1,
  2 and 3 did with the same files.

**The executor cannot build or run the app**: there is no shared `.xcscheme`. Where a task changes app
code, "it compiles" is the owner's ⌘R at the owner stop, and a compile error found there is a normal
continuation of that task, not a blocker. **Type-checking is available and catches most of it**, so every
task touching `CuttingBench/CuttingBench/` runs this as a *Done when* item:

```
swift build --package-path CuttingBench/BenchGeometry --disable-sandbox
xcrun swiftc -typecheck -disable-sandbox -DDEBUG \
  -I CuttingBench/BenchGeometry/.build/arm64-apple-macosx/debug/Modules \
  CuttingBench/CuttingBench/*.swift
```

then a second time **without `-DDEBUG`**, to cover the `#if DEBUG` alternative branches.
`-disable-sandbox` is required, or the `@Observable` macro plugin fails with `sandbox_apply: Operation not
permitted` and floods the output. It compiles no `.metal` and no resources, so it replaces neither the
owner's build nor an owner-stop verification. If the `-I` path does not exist, the `swift build` line above
creates it.

## Tasks

| # | Task | Status | Then | Commit | Note |
|---|---|---|---|---|---|
| T1 | Prefactor: one enumeration of the solid's edges | completed | continue | — | |
| T2 | Pure: what a click hit — the edge, or the facet | completed | checkpoint | commit | |
| T3 | Pure: the click machine, and the refusals it states | completed | continue | — | material alteration ↓ |
| T4 | Pure: the corner, the third name, and the meet it writes | completed | checkpoint | commit | material alteration ↓ |
| T5 | Picking in the window, against the intermediate solid | completed | **owner stop** | commit | |
| T6 | The ghost, and the markers on what has been clicked | completed | **owner stop** | commit + push | material alteration ↓ |
| T7 | `Easy Octagon`, cut in the app | completed | **owner stop** | commit + push | material alteration ↓ |
| T8 | Close out | awaiting owner | **owner stop** | commit + push | |

**T1 — Prefactor: one enumeration of the solid's edges**

Behaviour-preserving. `solidEdges` is extracted from `solidMesh`'s inline pair loop; `solidMesh` then walks
its result. Nothing about the mesh may change.

- **Files:** `CuttingBench/BenchGeometry/Sources/BenchGeometry/SolidEdges.swift` (new),
  `CuttingBench/BenchGeometry/Sources/BenchGeometry/SolidMesh.swift` (edit),
  `CuttingBench/BenchGeometry/Tests/BenchGeometryTests/SolidEdgesTests.swift` (new)
- **Done when:**
  - `SolidEdge` and `solidEdges` exist with the signatures and doc comments in §1.
  - `SolidMesh.swift` no longer declares `seenEdges` and no longer computes a `(min, max)` key; its edge
    vertices come from walking `solidEdges(solid)`.
  - `swift test --package-path CuttingBench/BenchGeometry --disable-sandbox` passes, **with
    `SolidMeshTests.swift` unedited** — in particular `testTheBarePrismsCountsAreExact`,
    `testEulerHoldsForThePrismAndEveryAuthoredPattern` and `testTwoCallsOnOneSolidAgree`.
  - `SolidEdgesTests.swift` covers: the bare prism has **48** edges (96 edge vertices ÷ 2, the number
    `SolidMeshTests.swift:46` already pins); every edge of the prism and of each of the four patterns in
    `Design/Patterns/` reports exactly two planes; every edge's `a < b`; and the list is sorted by
    `(a, b)`.
  - `swift test --package-path Kernel --disable-sandbox` passes.
  - `xcrun swift-format lint --recursive --strict CuttingBench/BenchGeometry/Sources
    CuttingBench/BenchGeometry/Tests CuttingBench/CuttingBench` is clean.
- **Do not:** change any test in `SolidMeshTests.swift`; change the order or content of
  `SolidMesh.swift`'s triangle output; touch `Kernel/`.

**T2 — Pure: what a click hit — the edge, or the facet**

`MeetPickHit.swift` in full: the tuning constants, the visibility test, the centroid, and the hit test.

- **Files:** `CuttingBench/BenchGeometry/Sources/BenchGeometry/MeetPickHit.swift` (new),
  `CuttingBench/BenchGeometry/Tests/BenchGeometryTests/MeetPickHitTests.swift` (new)
- **Done when:**
  - `MeetPickTuning`, `MeetPickHit`, `meetPickHit`, `isVisible` and `facetCentroid` exist exactly as §2
    gives them, including the y-convention comment.
  - The facet branch calls `pickFacet` and does not reimplement a slab test.
  - `swift test --package-path CuttingBench/BenchGeometry --disable-sandbox` passes, including these cases:
    - A click at the exact centre of a facet of the bare prism, from the default three-quarter camera in a
      900×600 viewport, returns `.facet` with that facet's plane index — the same index `pickFacet` returns
      for the same ray.
    - A click placed on the projection of a **silhouette** edge's midpoint returns `.edge` with that edge's
      two planes and two corners.
    - The same click moved **20 points** perpendicular to that edge returns `.facet`, and moved **4
      points** still returns `.edge` — the 8-point radius, from both sides of it.
    - An edge whose two facets both face away from the camera is never returned, even when the click lands
      exactly on its projection: `isVisible` is `false` for it and `true` for a silhouette edge.
    - A click outside the solid's silhouette returns `nil`.
    - `facetCentroid` of every facet of the bare prism satisfies that plane's equation to `1e-6`, and
      returns `nil` for a plane index the polytope has no ring for.
  - `swift test --package-path Kernel --disable-sandbox` passes.
  - `xcrun swift-format lint --recursive --strict CuttingBench/BenchGeometry/Sources
    CuttingBench/BenchGeometry/Tests CuttingBench/CuttingBench` is clean.
- **Do not:** add an occlusion test to the facet branch — `pickFacet` already returns the front-most facet;
  read the opacity anywhere in this file (D8); touch any app file.

**T3 — Pure: the click machine, and the refusals it states**

The three refusal cases, the state, and `advancing` — every transition in D9 and D10 **except** the three
that resolve a corner, which are T4. Where a transition would resolve one, this task returns `.advanced`
with the stage it reached and leaves a `// T4` marker; T4 replaces those three call sites: a facet sharing
exactly one corner with the highlighted one, a third facet through one end of the selected edge, and a
click on a waiting candidate. Nothing else is stubbed.

- **Files:** `CuttingBench/BenchGeometry/Sources/BenchGeometry/PatternDraft.swift` (edit),
  `CuttingBench/BenchGeometry/Sources/BenchGeometry/MeetPick.swift` (new),
  `CuttingBench/BenchGeometry/Tests/BenchGeometryTests/MeetPickTests.swift` (new)
- **Done when:**
  - `DraftRefusal` carries the three new cases and the three sentences, verbatim as §4 gives them.
  - `MeetPickStage`, `MeetPickState`, `MeetPickOutcome`, `advancing` and
    `intermediateBenchSolid(before:draft:full:)` exist as §3 gives them.
  - `swift test --package-path CuttingBench/BenchGeometry --disable-sandbox` passes, including these cases
    against a solid built from `Design/Patterns/Pattern-Easy-Octagon.json`:
    - `hit: nil` from any stage returns `.cleared`.
    - A rough facet returns `.refused(.roughFacetNotNameable(name:))` with the rough's own name (`C`, `P`,
      `G1`…`G16`), and leaves the state untouched — check the returned outcome carries no state.
    - `empty` + a cut facet → `.advanced` at `.oneFacet` with that plane.
    - `.oneFacet(p)` + the same `p` → `.advanced` at `.empty`.
    - `.oneFacet` + a facet sharing an edge → `.advanced` at `.edge`, with both planes and both corners.
      **Take the pair from `solidEdges`** — any edge's own two planes — rather than naming two facets, so
      the case needs no claim about which facets of a pattern are adjacent.
    - `.oneFacet` + a facet sharing neither an edge nor a corner → `.advanced` at `.oneFacet` with the
      **second** plane. Find the pair by searching for two cut facets whose polygon rings share no vertex
      index.
    - `.edge` + a facet through neither corner → `.advanced` at `.oneFacet` with that facet.
    - A click on an edge from every one of the four stages → `.advanced` at `.edge`, with any highlight
      gone.
    - `intermediateBenchSolid` before `Easy Octagon`'s `P2` has exactly the planes of `G1` and `P1` and no
      others; before `G1` it is the bare prism, every facet of it rough; and for a label the draft does not
      carry it is the bare prism too.
  - `swift test --package-path Kernel --disable-sandbox` passes.
  - `xcrun swift-format lint --recursive --strict CuttingBench/BenchGeometry/Sources
    CuttingBench/BenchGeometry/Tests CuttingBench/CuttingBench` is clean.
- **Do not:** implement `meetPicked`, the `tcp` rule, the candidate set or the prompt — all T4; add a
  refusal case beyond the three named; edit any other case's sentence; touch any app file.
- **Material alteration.** D9 and D10 leave two clicks undefined, and a state machine must answer every
  click, so both were settled the conservative way and are stated here for the owner to overrule:
  **an edge one of whose two facets is part of the rough is refused with `roughFacetNotNameable`, naming
  that rough facet**, rather than selected — selecting an edge commits two of the three names at once, so a
  rough one there is the same refusal a click on that facet states, and no completion could ever follow it;
  and **a third facet through *both* ends of the selected edge** — which on a convex solid can only be one
  of the two facets already sharing it, since an edge belongs to no others — **falls to D9's "through
  neither" arm**, dropping the edge and highlighting that facet. Nothing else in D9 or D10 was interpreted.

**T4 — Pure: the corner, the third name, and the meet it writes**

The completion half: the candidate set, the auto-filled third name, `meetPicked` with the `tcp` rule, and
the two derived displays the window reads. The two `// T4` markers from T3 become `.complete` or
`.refused`.

- **Files:** `CuttingBench/BenchGeometry/Sources/BenchGeometry/MeetPick.swift` (edit),
  `CuttingBench/BenchGeometry/Tests/BenchGeometryTests/MeetPickTests.swift` (edit)
- **Done when:**
  - `candidatePlanes`, `meetPicked`, `meetPickPrompt`, `meetPickMarkers` and `MeetPickMarker` exist as §3
    gives them, and the prompt's four sentences read exactly as §3 spells them.
  - `swift test --package-path CuttingBench/BenchGeometry --disable-sandbox` passes, including these cases:
    - **The corpus round-trip, which is this task's real check.** For every pattern in
      `AuthoredPatterns.all` and every tier in it whose meet is a `vertex`: build
      `intermediateBenchSolid(before:draft:full:)` for that tier, find each named facet's plane index in
      that solid's `origin`, and drive `advancing` with `.facet` hits for the three **in the file's own
      order**. The last click must return `.complete` with **exactly the meet the file stores**, facets and
      order included. This needs no claim about which pair shares an edge: all three facets carry the
      corner, so the first two share either an edge or that corner alone, and both routes are covered by
      the same assertion. Assert the case is not vacuous by counting the tiers exercised — `Easy Octagon`
      alone contributes three (`P2`, `C2`, `T`).
    - The same three facets of `Easy Octagon`'s `P2` clicked in a **different** order complete to a `Meet`
      whose facets are in *that* order and which is therefore **not** equal to the file's — proving the
      triple is never sorted.
    - A click on a facet that carries neither the highlighted facet's corner nor the selected edge returns
      `.advanced` at `.oneFacet` with that facet, never a completion.
    - `candidatePlanes`, over `BenchSolid` values built directly through its public initialiser from four
      planes meeting at one point: **three cut and one rough** gives exactly one candidate beyond two named
      cut planes, and `advancing` reaching that corner therefore completes **without a third click** naming
      that candidate; **two cut and two rough** gives none, and `advancing` returns
      `.refused(.roughDerivedPoint(tier:))`; **five cut** gives three, and `advancing` stays at `.point`
      awaiting a click.
    - **The `tcp` rule, both ways.** On a draft whose pavilion carries no `tcp` at all, a pick whose corner
      is the pavilion axial point of the intermediate solid completes to `.tcp`; on `Easy Octagon` as
      authored — where `P1` is already `tcp` — the same corner completes to the `vertex` triple instead, and
      **no refusal is produced** (D17).
    - A crown tier whose corner is the *pavilion* axial point never completes to `.tcp`, because `axialPoint`
      is asked for the tier's own side.
    - `meetPicked` with three planes whose normals are dependent returns
      `.refused(.pickedFacetsDoNotMeet(tier:))` — constructed directly, since a corner of a real solid never
      produces it.
    - `meetPickPrompt` returns each of the four sentences for its stage, with the tier's label and the
      facets' names substituted, and the candidate count in the `point` case.
    - `meetPickMarkers` returns one `.named` marker per clicked facet numbered from 1, one `.candidate` per
      waiting candidate, and two `.corner` markers at `.edge`; every `world` is on the solid to `1e-6`; and
      it is empty at `.empty`.
  - `swift test --package-path Kernel --disable-sandbox` passes.
  - `xcrun swift-format lint --recursive --strict CuttingBench/BenchGeometry/Sources
    CuttingBench/BenchGeometry/Tests CuttingBench/CuttingBench` is clean.
- **Do not:** re-derive the axial point or the second-`tcp` rule — call `axialPoint(onTheSideOf:cutBy:)` and
  `structuralFindings` (D16); sort the `vertex` triple; look at any structural finding other than
  `secondTCPOnSide`; touch any app file.
- **Material alteration.** **D16's `tcp` arm cannot fire on any real draft, and the *Done when* case that
  asked for it was unsatisfiable as written.** The kernel reports an axial point on a side only once an
  earlier tier there has crossed the axis (`axialPoint(onTheSideOf:cutBy:)` skips a 90° tier), and crossing
  the axis is exactly what claims that side's free datum (`structuralFindings` marks the side spoken for
  from the tier's angle, not from its meet form) — so wherever a picked corner *is* the axial point,
  `secondTCPOnSide` fires and the `vertex` triple is written. There is no draft in which one holds and the
  other does not, so the plan's "pavilion carrying no `tcp` at all" fixture cannot be built: the tier that
  puts the corner on the axis is itself what claims the datum. D16 is implemented exactly as written and
  asks both questions of the kernel; **the arm is covered by a directly-constructed pair** — the authored
  intermediate solid with a draft whose pavilion has not reached the axis, which is legitimate because the
  solid and the draft are independent arguments — and a second case,
  `testTheAxialPointExistsOnlyOnceThatSidesDatumIsSpokenFor`, states the mutual exclusion against the real
  corpus so it cannot be rediscovered by accident. What ships is exactly D17's behaviour, on every path.
  Filed as `Decision-A-Picked-Corner-Can-Never-Be-Written-As-TCP`.

**T5 — Picking in the window, against the intermediate solid**

The whole working slice: the menu item starts a pick, the viewport swaps to the intermediate solid, clicks
build the meet, the strip says what to click next and offers Cancel, and a completed meet lands in the draft
through the existing funnel. **No ghost and no markers yet** — those are T6.

- **Files:** `CuttingBench/CuttingBench/BenchSolidStore.swift` (edit),
  `CuttingBench/CuttingBench/BenchWindow.swift` (edit),
  `CuttingBench/CuttingBench/BenchRegions.swift` (edit)
- **Done when:**
  - `BenchSolidStore` carries `fullGeneration` and `fullMesh` per §7, and `fullGeneration` is bumped in
    `setPattern` only.
  - `BenchWindow` carries `pick`, `drawGeneration`, `MeetPickSession`, `drawnSolid`, `drawnMesh`,
    `startPick(_:)`, `endPick()` and `highlightedPlane(of:)`, and `pick(at:in:)`'s new branch is exactly the
    code in §10 including its `return`.
  - `afterSolidChanged()` clears `pick` and bumps `drawGeneration`.
  - `ViewportRegion` draws `drawnMesh` at `generation: drawGeneration`; `TierTableRegion`'s Meet menu carries
    **Pick in viewport…**; `StatusStripRegion` carries `pickPrompt` and Cancel, in **both** arms of its
    `#if DEBUG`.
  - `swift build --package-path CuttingBench/BenchGeometry --disable-sandbox` succeeds, and both
    `swiftc -typecheck` runs from **Checks** are clean, `-DDEBUG` and without.
  - `swift test --package-path CuttingBench/BenchGeometry --disable-sandbox` and
    `swift test --package-path Kernel --disable-sandbox` pass.
  - `xcrun swift-format lint --recursive --strict CuttingBench/BenchGeometry/Sources
    CuttingBench/BenchGeometry/Tests CuttingBench/CuttingBench` is clean.
- **Do not:** add the ghost pass, `setGhostMesh`, `MeetPickOverlay` or any marker — T6; make `MeetDotChip`
  non-private yet — T6; let a pick register an undo entry of its own (only the completed meet does, through
  `edit`); bump `drawGeneration` anywhere but the four places §10 names.
- **Verification handle** — `permanent`:
  - **Where:** the status strip, bottom of the window, its middle segment — the pick prompt, with the
    **Cancel** button beside it. Open `Design/Patterns/Pattern-Easy-Octagon.json`, click row `P2` in the
    tier table, open its Meet menu (the chevron in the Meet cell) and choose **Pick in viewport…**.
  - **Positive:** the strip reads `Picking P2's meet · click a facet, or an edge`, and the stone in the
    viewport visibly loses its crown — what is drawn is `G1` and `P1` on the preform, the stone as it stands
    before `P2` is cut. Click one girdle facet: the strip reads `Picking P2's meet · G1 · <n> · click a
    second facet` and that facet turns orange. Click the girdle facet beside it: the strip reads
    `… · edge G1 · <n> – G1 · <m> · click a third facet through one of its ends`. Click the pavilion main
    under them: the pick ends, the strip's prompt disappears, the whole stone comes back, and `P2`'s Meet
    cell now reads one yellow `M` chip beside three facet names. ⌘Z restores the cell to `—`.
  - **Negative:** start the pick again and click the **rough** — one of the grey prism walls, or the flat
    grey bottom. An alert appears reading `G<n> is part of the rough, not the stone. A meet may only name
    facets the pattern cuts.`, and the strip's prompt is **unchanged** — still asking for the same click as
    before. Then drag to orbit: the stone turns and the prompt is still unchanged, because orbiting is not a
    click. Press **Cancel**: the prompt disappears and the whole stone comes back, with `P2`'s Meet cell
    exactly as it was.
  - **Reads:** `meetPickPrompt` and `advancing` in
    `CuttingBench/BenchGeometry/Sources/BenchGeometry/MeetPick.swift`, and
    `intermediateBenchSolid(before:draft:full:)` for what the viewport draws.

**T6 — The ghost, and the markers on what has been clicked**

The two things that make a pick legible: the finished stone as a wireframe over the intermediate solid, and
a named chip on every facet the author has clicked or may click next.

- **Files:** `CuttingBench/CuttingBench/BenchRenderer.swift` (edit),
  `CuttingBench/CuttingBench/MetalViewport.swift` (edit),
  `CuttingBench/CuttingBench/MeetPickOverlay.swift` (new),
  `CuttingBench/CuttingBench/BenchRegions.swift` (edit),
  `CuttingBench/CuttingBench/BenchWindow.swift` (edit)
- **Done when:**
  - `BenchRenderer` carries `ghostEdgeAlpha`, `setGhostMesh(_:)` and the third edge pass, exactly as §5
    describes — last of the three passes, `depthAlways`, the edge pipeline, **no `.metal` edit**.
  - `MetalViewport` carries `ghostMesh`, `ghostGeneration` and `uploadedGhost`, and uploads on the same
    comparison rule the mesh uses.
  - `MeetPickOverlay.swift` exists with `meetPickMarkerColor` and `MeetPickOverlay`, has
    `.allowsHitTesting(false)`, and is stacked between `MeetPointOverlay` and `ProbePathOverlay`.
  - `MeetDotChip` is no longer `private` and is otherwise unchanged.
  - `BenchWindow` passes `ghostMesh: pick == nil ? nil : store.fullMesh`,
    `ghostGeneration: store.fullGeneration` and `pickMarkers:` per §10.
  - `swift build --package-path CuttingBench/BenchGeometry --disable-sandbox` succeeds, and both
    `swiftc -typecheck` runs from **Checks** are clean, `-DDEBUG` and without.
  - `swift test --package-path CuttingBench/BenchGeometry --disable-sandbox` and
    `swift test --package-path Kernel --disable-sandbox` pass.
  - `xcrun swift-format lint --recursive --strict CuttingBench/BenchGeometry/Sources
    CuttingBench/BenchGeometry/Tests CuttingBench/CuttingBench` is clean.
- **Do not:** edit `Shaders.metal` or the `Uniforms` struct; fill the ghost — edges only; give the ghost its
  own colour; add an occlusion test to the overlay (D20); bump `fullGeneration` on a scrub.
- **Material alteration.** **`ghostGeneration: store.fullGeneration` cannot work, and §6's own doc comment
  is what it was corrected to.** The ghost mesh changes on two events — the finished stone being rebuilt,
  and a pick starting or ending — and `fullGeneration` sees only the first, so a pick starting would leave
  `uploadedGhost` equal and the outline would never be uploaded. §6 states the contract the counter has to
  meet ("bumped whenever `ghostMesh` changes, **including to and from `nil`**"), and §10's expression
  contradicts it. The window now computes `2 * store.fullGeneration + (pick == nil ? 0 : 1)`, which changes
  on either event and cannot collide, and `fullGeneration` keeps the meaning T5 gave it — still bumped in
  `setPattern` only, and still not by a scrub.
- **Verification handle** — `permanent`:
  - **Where:** the viewport. Open `Pattern-Easy-Octagon.json`, select row `C2`, and start
    **Pick in viewport…** from its Meet menu.
  - **Positive:** the crown above `C1` is gone from the *solid*, but the finished stone's outline — the
    table and the `C2` facets — is still there as faint lines over and outside it. Click a girdle facet: a
    blue chip appears on it reading `1 · G1 · <n>`. Click the girdle facet beside it: a second chip reads
    `2 · G1 · <m>`, and two small blue rings appear at the two ends of the edge between them. Complete the
    pick on a `C1` facet and both the chips and the ghost disappear together.
  - **Negative:** with no pick running, the viewport shows **no** faint outline and **no** blue chips at all
    — only the solid, its own edges, the index ring, and the meet dots for the selected row. Drag the
    Opacity slider to 0 with no pick running and what appears is the existing hidden-edge wireframe in the
    *label* colour, not a second ghost outline. Start a pick and press Cancel: the outline and every chip go
    at once.
  - **Reads:** `meetPickMarkers` in `CuttingBench/BenchGeometry/Sources/BenchGeometry/MeetPick.swift` for
    the chips, and `BenchRenderer.setGhostMesh` for the outline.

**T7 — `Easy Octagon`, cut in the app**

The completion bar (D26). **No code is written in this task** unless the run finds a defect; it is the owner
cutting the pattern and the executor checking the result. A defect found here is a normal continuation of
this task, and a fix goes in with T7's own commit.

The executor's job is to hand the owner the sequence below, then run the two comparisons and report both
outcomes. The owner works from a **new document** — ⌘N — with `Pattern-Easy-Octagon.json` **not** open, so
nothing is copied except the two prose fields.

*Header, in the inspector's Pattern card:* Name `Easy Octagon`; Gear `96`; RI `1.54`; Girdle target
`0.0337`; State left at `in progress` until the end. **Copy `designer` and `notes` verbatim** out of
`Design/Patterns/Pattern-Easy-Octagon.json` — they are prose, and typing prose is not what this run tests.

*Tiers, added with **Add Tier** in this order and never reordered:*

| Tier | Part | Angle | Seeds · Folds · Mirror | Stops it should read | Meet, and how |
|---|---|---|---|---|---|
| `G1` | `gdl` | `90.00` | `0` · `8` · off | `0 12 24 36 48 60 72 84` | `size`, from the Meet menu |
| `P1` | `pav` | `47.60` | `0` · `8` · off | `0 12 24 36 48 60 72 84` | `tcp`, from the Meet menu |
| `P2` | `pav` | `43.00` | `6` · `8` · off | `6 18 30 42 54 66 78 90` | **picked**: `G1@0`, `G1@12`, then `P1@0` |
| `C1` | `crown` | `42.00` | `0` · `8` · off | `0 12 24 36 48 60 72 84` | `girdle`, from the Meet menu |
| `C2` | `crown` | `29.00` | `18` · `4` · off | `18 42 66 90` | **picked**: `G1@12`, `G1@24`, then `C1@12` |
| `T` | `table` | `0.00` | — · — · — | `0` | **picked**: `C1@0`, `C1@12`, then `C2@18` |

`T`'s single stop is typed into the Indices cell; one stop has no symmetry to generate.

Then, **in this order**: with the first five tiers complete and `T`'s meet still unset, try **State →
finished** once and confirm it is refused (the negative half of the handle below); set `T`'s meet; flip
**State** to `finished`; and only then save, as `~/Desktop/Easy-Octagon-Cut-In-App.json`. **Saving last is
load-bearing** — the reference file's `state` is `finished`, so a file saved before the switch is flipped
cannot compare equal.

- **Files:** none — unless the run finds a defect, in which case only the file that carries it.
- **Done when:**
  - The owner reports the pattern cut and saved, with **no text editor involved** and no field typed except
    the header values and `T`'s single stop.
  - Decoded equality, run by the executor and reported as one line:
    ```
    python3 - <<'EOF'
    import json
    a = json.load(open('/Users/analyst/Desktop/Easy-Octagon-Cut-In-App.json'))
    b = json.load(open('Design/Patterns/Pattern-Easy-Octagon.json'))
    print('EQUAL' if a == b else 'DIFFERENT')
    if a != b:
        print([t.get('tier') for t in a.get('tiers', [])])
        print([t.get('tier') for t in b.get('tiers', [])])
        for k in sorted(set(a) | set(b)):
            if a.get(k) != b.get(k): print(k, '::', a.get(k), '!=', b.get(k))
    EOF
    ```
    prints `EQUAL`. Python's `==` on two decoded objects is field-by-field with list order preserved, which
    is exactly *every field equal and the tiers in the same order*, and it ignores formatting — which the
    format leaves loose on purpose.
  - Identical solved geometry: `swift run --package-path Kernel --disable-sandbox facetsolve
    ~/Desktop/Easy-Octagon-Cut-In-App.json --json` and the same command on
    `Design/Patterns/Pattern-Easy-Octagon.json` produce byte-identical stdout, and both exit `0`.
  - `swift test --package-path CuttingBench/BenchGeometry --disable-sandbox` and
    `swift test --package-path Kernel --disable-sandbox` pass.
- **Do not:** edit `Design/Patterns/Pattern-Easy-Octagon.json`, or loosen either comparison, for any reason
  — it is external ground truth and a disagreement is a stop, never an edit to the fixture; hand-write any
  part of the produced file; save into `Design/Patterns/`.
- **Material alteration.** The first run found **one defect that made the bar unreachable**, fixed here as
  T7's own continuation, and **one adjacent problem, ticketed rather than fixed**.
  - **The 8-point edge grab swallowed the girdle band whole, so no girdle facet could take a click** — and
    `P2`, `C2` and the file's own `T` all name one. `Easy Octagon`'s girdle is 3.37% of the width, which at
    the default camera in a 900×600 viewport is a band **8.7 points tall**, so the grab reached in from the
    band's top and bottom edges and every click in it resolved as `edge G1 · <n> – P1 · <n>`; because D10
    makes an edge click replace the selection at any stage, no pick naming a girdle facet could ever reach
    a third click. **D6's rule now carries one more clause, chosen by the owner:** an edge loses the click
    when a second visible edge *sharing none of its corners* is also within the radius, which is the exact
    statement of "the facet under the pointer is thinner than the grab" and needs no per-camera number. Two
    edges that *do* share a corner still grab the nearer one, so a deliberate grab near an edge's own end —
    which part 5's end zones depend on — is untouched. The radius stays **8 points**. Pinned by
    `testEveryGirdleFacetOfEasyOctagonTakesAClickAtItsOwnCentre`, which fails on the old rule with exactly
    the pair the owner saw, and `testAGrabNearAnEdgesEndStillTakesThatEdge`.
  - **Mirror reads `on` for the first four tiers and cannot be turned off, and that is not this part's
    defect.** Mirroring is derived from the stop list, and `0 12 … 84` on gear 96 *is* its own reflection,
    so the box is an honest readout of a set that cannot be made less symmetric by unmirroring it. **The
    stop lists this task asks for are unaffected** — leave Mirror alone and every tier generates exactly the
    list in the table. Filed as `Bug-Mirror-Reads-As-An-Editable-Checkbox-But-Is-Derived`; the *Seeds ·
    Folds · Mirror* column above should be read as `0 · 8 · leave it`.
  - **The run was accepted with D26's decoded-equality half not demonstrated** — the owner's call, recorded
    here rather than resolved. The saved file's solved geometry is **byte-identical** to the authored
    pattern's and both exit `0`, so that half of the bar is met outright. The decoded comparison printed
    `DIFFERENT` on three points, every one of them in what was entered and none in what the app wrote:
    `notes` carried four line breaks and is identical once whitespace is collapsed; `C2`'s two girdle names
    are in the reverse click order; and `T` names `C2@90` where the file names `C2@18`, which is the mirror
    corner across the `C1@0`–`C1@12` edge. The triple is stored in click order and never sorted (§3), and
    both corners are true statements about the same stone — which is why the solve agrees to the byte. The
    owner assessed the feature as working and called it verified. **Neither comparison was loosened and
    `Design/Patterns/Pattern-Easy-Octagon.json` was not touched**; what is unproven is that a run following
    the sequence above reproduces the file field-for-field.
- **Verification handle** — `permanent`:
  - **Where:** the inspector's Pattern card, its **State** switch, plus the two comparisons above.
  - **Positive:** with all six tiers complete, flipping State to `finished` is **accepted** — the switch
    moves and no alert appears — and the saved file compares `EQUAL` with identical `facetsolve --json`
    output.
  - **Negative:** *before* setting `T`'s meet, flip State to `finished`. It is **refused**, with an alert
    naming `T` as having no meet, and the switch stays at `in progress`. Set `T`'s meet, then try once more
    and it is accepted.
  - **Reads:** `meetPicked` in `CuttingBench/BenchGeometry/Sources/BenchGeometry/MeetPick.swift` — three of
    the six meets in the produced file exist only because that function wrote them, so if it were deleted
    the file could not be produced at all.

**T8 — Close out**

- No temporary handles to delete: every handle in this plan is `permanent`.
- Confirm each item in this plan's **Deferred** section has a ticket in `Design/Tickets/` with
  `Status: untriaged`.
- Report the untriaged ticket count in `Design/Tickets/`, one line.
- `commit + push` with the message below.
- **Archive nothing, and close no ticket.** This is part 4 of 5: the exploration `4-Cutting-Bench-Authoring`
  is still the design source for part 5, and the folded-in ticket
  `Chore-Validation-Rebuilds-The-Solid-Once-Per-Tier` is closed by
  `4-Cutting-Bench-Authoring-5-Fraction-Meets`, which archives this plan, every sibling part by name, the
  exploration and that ticket. Leave this plan's `Status:` line saying part 4 completed and that the final
  part archives the set.

## Commit points

Six, in task order. **T1 and T3 share the commit that follows them** — both are pure, behaviour-preserving
or unreachable from the UI, and neither is worth a commit of its own.

**After T2** — `commit`

```
4-cutting-bench-authoring-4 T1-T2: the solid's edges, and what a click hit

- solidEdges extracted from solidMesh, so the wireframe and the click read one
  enumeration; SolidMeshTests unchanged
- meetPickHit: a visible edge within 8 points takes the click, otherwise the
  front-most facet
```

**After T4** — `commit`

```
4-cutting-bench-authoring-4 T3-T4: the click machine, and the meet it writes

- the four stages, the three refusals, and the intermediate solid a pick is
  tested against
- a picked corner writes tcp when the side's datum is free and the vertex triple
  the author clicked otherwise, asked of the kernel rather than restated
```

**After T5** — `commit`

```
4-cutting-bench-authoring-4 T5: picking a meet in the viewport

- Pick in viewport… starts a pick; the viewport draws the stone as it stands
  before that tier, and every click is tested against it
- the strip says what to click next and offers Cancel; a completed meet lands
  through the same funnel and undo as every other edit
```

**After T6** — `commit + push`

```
4-cutting-bench-authoring-4 T6: the ghost, and chips on what has been clicked

- a third edge pass draws the finished stone over the intermediate solid, no
  shader change
- a named chip per clicked facet and per waiting candidate, rings on the
  selected edge's ends
```

**After T7** — `commit + push`

```
4-cutting-bench-authoring-4 T7: Easy Octagon, cut in the app

- the completion bar: cut from a new document with no text editor, equal to the
  authored file after decode with identical solved geometry
```

**After T8** — `commit + push`

```
4-cutting-bench-authoring-4 T8: close out the meet-picking slice

- part 4 complete; the exploration and the folded-in ticket stay live for part 5
```

## Deferred

Empty at authoring. The executor appends adjacent problems it found and must not fix — and files each as a
ticket in `Design/Tickets/` immediately with `Status: untriaged`, per the protocol.

- **A picked corner can never be written as `tcp`** (found in T4). The axial point on a side exists only
  once that side's datum is claimed, so D16's `tcp` arm is unreachable and every pick writes the `vertex`
  triple. Ticket: `Decision-A-Picked-Corner-Can-Never-Be-Written-As-TCP`.
- **Mirror reads as an editable checkbox but is derived from the stops** (found in T7). On a set that is
  already its own reflection the box cannot be unchecked, which reads as broken. Ticket:
  `Bug-Mirror-Reads-As-An-Editable-Checkbox-But-Is-Derived`.
