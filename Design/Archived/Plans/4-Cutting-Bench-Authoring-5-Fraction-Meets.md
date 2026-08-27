# 4 · Cutting Bench Authoring — Part 5: Fraction Meets

Status: **APPROVED** (2026-08-27). **Completed and archived 2026-08-27** — every task owner-verified.

## Parts

**For the owner and the next authoring session — not for the executor.** Nothing in this plan's tasks
refers to another part.

1. `4-Cutting-Bench-Authoring-1-Draft-And-Tier-Editing` — the editable draft, and every tier edit that
   needs no click in the viewport: add, delete, reorder, rename, angle, part, index stops, instructions,
   the header fields, and the three meet forms that take no picking. **(shipped)**
2. `4-Cutting-Bench-Authoring-2-Validation-And-State` — the cheap half of validation on every committed
   edit, the expensive half cached per tier and invalidated from the first edited tier onward, and the
   `state` switch that refuses `finished` while any finding fires. **(shipped)**
3. `4-Cutting-Bench-Authoring-3-Symmetry-And-Wheel` — folds, mirroring and seed stops per tier row, with
   `indices` filled in as the expansion and a raw-index escape; the index-gear popup and its
   out-of-range refusal. **(shipped)**
4. `4-Cutting-Bench-Authoring-4-Meet-Picking` — building a meet by clicking facets: the intermediate
   solid with the finished stone as a wireframe ghost, the facet-and-edge click machine, the third click
   where more than three planes pass through the point, the axial-point case, and the rough refusals.
   Shipped the completion bar — `Easy Octagon` cut in the app. **(shipped)**
5. `4-Cutting-Bench-Authoring-5-Fraction-Meets` — a point anchored part-way along an edge: the 20% end
   zones, the outer endpoint as the start of the measurement, the editable percentage, and 0 or 100
   collapsing to a plain vertex. Closes the folded-in ticket and archives the set. ← this part

| Exploration ID | Part |
|---|---|
| S1 | 4 |
| S2 | 5 |
| S3 | 1 |
| I1 | 1 — **restated in 4 and 5**, each of which writes a picked meet through the same funnel |
| I2 | 1 |
| I3 | 1 |
| I4 | 1 |
| I5 | 2 |
| I6 | 1 |
| U1 | 2 |
| U2 | 3 |
| U3 | 3 |
| U4 | 3 |
| U5 | 4 — **restated in 5**, which anchors against the same intermediate solid |
| U6 | 5 |
| U7 | 4 — **restated in 5**, which implements the one bullet part 4 left: a click along a selected edge |
| U8 | 5 |
| U9 | 5 |
| U10 | 4 — **restated in 5**, whose fraction endpoints obey the same never-name-an-unclicked-facet rule |
| U11 | 4 |
| U12 | 2 |
| U13 | 1 — **restated in 2, 3, 4 and 5**, each of which adds refusals |

**No boundary moved.** Every ID sits where the owner agreed when the split was proposed, and part 4's
copy of this table said the same. Part 4's own record notes that its completion bar was accepted with
the decoded-equality half not demonstrated; that is part 4's business and changes nothing here.

## Context

**One meet form is still unauthorable, and it is the one the corpus leans on hardest.** Part 4 shipped
picking a corner: three facets clicked, one `vertex` meet written, and `Easy Octagon` cut in the app end
to end. What still cannot be said is *this tier is cut a quarter of the way down from that corner toward
the culet* — a `fraction`. `Novice Ash-er` is four of them out of eight tiers, so the pattern can be
opened, solved and displayed but not authored; and `Kiev Triangle`, which is what the finished tool is
meant to be used on, is the same shape of design at 139 facets. When this part lands, every one of the
five meet forms can be authored by clicking.

What already exists, verified by reading during this session:

- **A click already resolves to an edge, and knows which one.** `MeetPickHit.swift:43`
  (`public func meetPickHit(`) returns `.edge(planes:corners:)` for a click within 8 screen points of a
  visible edge, and `MeetPickHit.swift:65` (`if let nearest = within.min(by:`) is where that edge is
  chosen. **What it does not report is where along the edge the click fell** — that is this part's first
  addition.
- **The edge enumeration is already single and already shared with the wireframe.**
  `SolidEdges.swift:27` (`public func solidEdges(_ solid: BenchSolid) -> [SolidEdge]`), whose `SolidEdge`
  carries `a`, `b` and the two `planes` sharing it.
- **A selected edge is already a stage of the pick, with both corners in hand.** `MeetPick.swift:11`
  (`case edge(planes: [Int], corners: [Int])`), reached at `MeetPick.swift:92`
  (`return advanced(state, .edge(planes: [first, plane], corners: [shared.a, shared.b]))`). Part 4 waits
  there for a third facet; **this part adds the other thing the author may do — click along it.**
- **The corner-completion path is already one function, with the candidate rule, the rough refusal and
  the `tcp` question inside it.** `MeetPick.swift:125` (`private func resolving(`) and
  `MeetPick.swift:184` (`public func meetPicked(`). A click that snaps into an end zone is a plain vertex
  at that corner, so **it completes through this same path rather than a second copy of it.**
- **The kernel resolves a fraction by interpolating between two named points**, so the number the author
  sets is the number the solve uses: `Solver.swift:375` (`case .fraction(let from, let percent, let to):`)
  computes `start + t * (end - start)`. The format's own statement of the same arithmetic is at
  `design-authoring-format.md:269`.
- **The kernel requires each endpoint to be a `vertex` or a `tcp`**, and says so by name:
  `Pattern.swift:143` (`case fractionEndpointNotVertexOrTCP(tier: String, endpoint: String, kind: String)`),
  enforced at `Pattern.swift:249` (`case .fraction(let from, let percent, let to):`). This is why an
  anchored point needs each of its two ends spelled, and it is the whole shape of this part's new work.
- **Every fraction in the corpus spells its inner end `tcp`.** All four of `Novice Ash-er`'s read
  `"to": {"kind": "tcp"}` with `from` a three-facet triple — checked by decoding the file this session.
  So the common case needs **one** end named by candidates, not two.
- **The axial point is the kernel's to answer, and part 4 already asks it that way.**
  `Solver.swift:269` (`public func axialPoint(`) returns `(x: 0, y: 0, z: crossing)` for one side, and
  `MeetPick.swift:233` (`guard let axial = axialPoint(onTheSideOf: part, cutBy: solid.tiers)`) is the
  existing call. The axis is `z`: crown and table positive, pavilion and girdle negative
  (`Plane.swift:44`–`:47`, `zsign = 1` / `zsign = -1`), so the girdle plane is `z = 0`.
- **A stored fraction already draws and already reads.** `MeetPoints.swift:75`
  (`case .fraction(let from, let percent, let to):`) returns three dots — **A**, the percentage, **B** —
  and `TierTable.swift:44` (`public var meetPoints: [MeetPointDot]`) carries them into the row, which
  `BenchRegions.swift:366` (`ForEach(row.meetPoints) { dot in`) already renders as chips. **So the
  finished meet needs no new display**; only the pick in progress and the editable percentage do.
- **`meetText` already recurses through a fraction**: `TierTable.swift:166`
  (`public func meetText(_ meet: Meet) -> String`).
- **A whole `Meet?` already goes into the draft through one funnel.** `DraftEdits.swift:163`
  (`public func setting(meet: Meet?, ofTier tier: String, in draft: PatternDraft)`), whose own doc comment
  says the parameter is a whole `Meet?` "so a later part can pass a picked `vertex` or `fraction`". **This
  part is that later part for `fraction`, and it adds no new meet setter.**
- **A committing text cell is an established control, used nine times.** `BenchRegions.swift:424`
  (`let stored: String`) is `EditableCell`, with `commit: (String) -> Bool`; the angle cell at
  `BenchRegions.swift:261` is the closest model for a numeric one.
- **Refusals already have one channel and one enum.** `PatternDraft.swift:179`
  (`public enum DraftRefusal: Error, Equatable, Sendable`) with its `message` at `PatternDraft.swift:205`,
  alerted and logged by `RefusalPresenter.swift:24` (`func present(_ refusal: DraftRefusal)`).
- **Odd-order symmetry already works, so `S2` needs no build.** `TierSymmetry.swift:29`
  (`public func foldCounts(onWheel wheel: Int) -> [Int]`) offers the wheel's divisors, and 3 divides 96;
  `TierSymmetry.swift:61` (`public func expandedStops(seeds:folds:mirror:wheel:)`) steps by `wheel / folds`.
- **The app target picks up new files by itself** — `project.pbxproj:30`
  (`isa = PBXFileSystemSynchronizedRootGroup;`) — and this part adds no new file anyway.

So the genuinely new code is small and nearly all pure: where along an edge a click fell, which end is
`from`, and how each end gets spelled. The app gains one editable cell and one overlay marker.

## Decisions (2026-08-27)

| # | Decision |
|---|---|
| D1 | **A picked `fraction` is written into the draft through the funnel every other edit uses** — `setting(meet:ofTier:in:)`, unchanged. The draft is the app's and the file is the kernel's (**ADR-0003**), so a picked fraction is an ordinary edit: one undo entry, one refusal channel. **No new meet setter, and the app never serialises anything.** |
| D2 | **The pick still runs against the intermediate solid — the stone as it stands before the picking tier — and the click still hits that solid.** Unchanged from part 4: a meet is a cutting-time claim, so the facets and edges that may be named are the ones present when that tier is cut. |
| D3 | **Where along an edge a click fell is measured in model space, not on the screen.** The parameter is that of the point on the model-space segment `a → b` closest to the click's unprojected ray, clamped to `0...1`. The end zone is a fraction of the edge's **own length**, so a screen-space parameter would make the zone grow and shrink with foreshortening and stop being the stated fraction. |
| D4 | **The end zones are a fraction of the edge's own length at each end, one build constant, and not a preference** — `endZoneFraction`, tuned by editing the number exactly as the grab radius is. A hidden setting that changes what a click means is worse than editing a number. **The number is 20%, raised from 10% by the owner on 2026-08-27 after the first run**: a pavilion edge on `Novice Ash-er` is 139 to 290 screen points long at the default camera, so a tenth of it was 14 to 29 points and aiming for a corner was luck. Every fraction in the corpus sits between 24.8% and 33.9%, so a fifth at each end still leaves all of them authorable — 24.8% by under five points, which is the margin this number cannot exceed. |
| D5 | **A click in an end zone produces a plain `vertex` at that corner, never a `fraction` at 0 or 100.** A percentage that happens to be zero is a coordinate stating what the vertex form states directly (`design-authoring-format.md:266`). |
| D6 | **An end-zone click completes through part 4's existing corner path**, `resolving(_:planes:atCorner:solid:draft:)`, so the candidate rule, the rough-derived refusal and the `tcp` question have one implementation and not two. What snapping changes is *which corner*, never how a corner is spelled. |
| D7 | **`from` is the endpoint further from the axis.** Distance from the axis is `sqrt(x² + y²)`, the axis being `z` (`Plane.swift:44`–`:47`). **Ties go to the endpoint nearer the girdle plane, `z = 0`** — the smaller `abs(z)` — and a remaining tie to the endpoint whose resolved triple sorts first by tier label then index. The percentage then reads outside-in, the way the corpus phrases it, and grows monotonically as the point slides, so nothing flips under the pointer. |
| D8 | **The ordering is decided once, at the moment the point is anchored, and stored.** The stage carries its two ends already ordered, so no later step re-derives which is `from` and no two steps can disagree. |
| D9 | **The percentage is distance along the straight segment between the two named endpoints, measured from `from`** — never a distance from the girdle, never a radial or vertical distance, never a screen distance. It is the arithmetic the solver already performs (`Solver.swift:375`), so the number the author sees, the number stored, and the number the solve resolves are one number. Where the model-space parameter runs `a → b` and `from` is the `b` end, the stored percentage is `100 × (1 − t)`. |
| D10 | **An endpoint standing at the side's axial point is spelled `tcp`, and the one-`tcp`-per-side question is not asked of it.** A `tcp` as a *fraction endpoint* is unaffected by that rule — it is not a top-level datum claim — which is why all four of `Novice Ash-er`'s fractions read `to: tcp`. The axial point itself is still the kernel's answer, from `axialPoint(onTheSideOf:cutBy:)` over the intermediate solid's own tiers. **This is the one place part 5 asks less of the kernel than part 4 does, and the reason is that the two questions are different questions.** |
| D11 | **Any other endpoint is a `vertex` triple: the edge's two planes plus one more.** The third name comes from `candidatePlanes(atCorner:named:solid:)` — **none** → the pick is refused with `roughDerivedPoint`, because the end cannot be spelled without naming the rough; **one** → filled in, which is not a choice; **more than one** → the pick waits for a click and that end's candidates are marked. The app never names a facet the author did not click. **A point has more than one legal spelling, and this rule picks one of them** — the corpus spells the same corners with the two facets *above* the clicked edge instead, and both triples resolve to the identical point. Reproducing the corpus's choice would mean naming two facets the author never clicked, so the tool's spelling is the one it writes (D21). |
| D12 | **`from` is named before `to`, and only the end being named has its candidates marked.** The prompt says which end it is asking about. The exploration fixes the order (`from` is the outer end) and the per-end rule (fill in one candidate, wait for several) but never composes them for two ambiguous ends; this is that composition, agreed with the owner on 2026-08-27, and it adds no new concept — it is the existing candidate marking, one end at a time. |
| D13 | **The fraction completes on the click that resolves its last end.** **In the corpus that is a second click, not the anchoring one**: measured on all four of `Novice Ash-er`'s fractions, the outer corner has four cut facets through it, two of which are the clicked edge's, so the outer end always offers **two** candidates and waits. The inner end is the axial point and resolves without a click. An outer end with one candidate completes on the anchoring click, and that case exists — it is simply not the corpus's. |
| D14 | **The percentage is editable in the tier table's meet cell, and typing `0` or `100` collapses the meet to a plain `vertex`** — exactly as snapping into an end zone does, so the meet form follows from the value rather than from how the value was entered. Typing commits and the point moves with the next rebuild. |
| D15 | **A stored fraction needs no new display.** `meetPointDots` already returns **A**, the percentage and **B** for one, and the tier row and the viewport overlay already draw all three. Only the pick *in progress* gets a new marker: the anchored point, carrying its live percentage. |
| D16 | **A typed percentage outside `0...100` is refused, naming the tier and what was typed.** The kernel rejects it at decode (`Pattern.swift`'s `percentOutOfRange`), and a draft that cannot be saved is worse than an edit that will not commit. A piece that is not a number at all is the existing `notANumber` case. |
| D17 | **Every refusal in this part goes through `DraftRefusal` and the window's one `RefusalPresenter`**, so each is alerted and written to the unified log with no second channel, and each names the offending element. The one new case is added to `DraftRefusal` in `PatternDraft.swift`, where the enum is declared. |
| D18 | **`S2` — `Kiev Triangle` — is discharged by confirmation, not by a build.** It was named so that odd-order symmetry and the 139-facet cost shaped the design rather than surprising it, and both are already answered in shipped code: `foldCounts(onWheel:)` offers the wheel's divisors so 3-fold works on 96, and part 2's per-tier cache is what keeps an editing UI off the `tiers × planes³` path. The task checks those two facts in the running app and writes no code. |
| D19 | **The percentage is never back-solved from an achieved depth.** `design-authoring-format.md:279`–`:281` forbids a tool picking a meet's endpoints or back-solving its percentage: the author names the endpoints, then sets the number. |
| D20 | **Anything that changes the drawn solid still cancels the pick** — an edit, an undo, a scrub, a granularity change — because a plane index and a vertex index both mean nothing across a rebuild. Unchanged from part 4, and `afterSolidChanged()` already does it. |
| D21 | **A picked fraction is checked against the corpus by where its endpoints *are*, not by how they are spelled** — agreed with the owner on 2026-08-27, after the round-trip as first written turned out to be unachievable. The percentage matches to `0.001` and `to` matches exactly; `from` must **resolve to the same point** as the file's `from`, to `1e-6`. A point has more than one legal `vertex` triple, the kernel resolves every one of them to the same place, and the format's own authority is the geometry rather than the wording — so equality of spelling was never the property worth asserting. **The corpus files are not re-spelled**: they are external ground truth, and editing them to suit the tool is exactly what the guardrail against touching authored fixtures forbids. |

## Tickets closed by this plan

- `Chore-Validation-Rebuilds-The-Solid-Once-Per-Tier` — the named-point check costs roughly
  `tiers × planes³`, 1.65 s on a 139-plane pattern against 0.60 s for the whole solve, and asks what an
  authoring UI that validates after every edit does about it. **Answered by the per-tier cache and the
  split-validation scheme that parts 1 and 2 shipped**: the cheap structural half runs on every committed
  edit, and the expensive per-tier half is cached and invalidated from the first edited tier onward, which
  turns `tiers × planes³` into `planes³` per tier added. Nothing in this part re-opens it; this is the part
  that closes it, because it is the last part of the set. Archived at close-out.

## Prefactoring

**One task, T1.** `meetPickHit` already chooses the edge a click resolved to but reports nothing about
where along it the click fell, and every decision in this part is a question about that position. T1 adds
it — the `.edge` case carries the model-space parameter, computed once where the edge is already being
chosen — and **nothing reads it yet**, so no behaviour changes. The inverted check is that every existing
case in `MeetPickHitTests.swift` still asserts the same planes and the same corners; the only permitted
edit to that file is widening a pattern match to accept the new associated value, never changing an
expectation.

No other prefactor is needed. The corner-completion path, the candidate rule, the refusal channel and the
fraction's display all exist and are called rather than reshaped.

## Approach

Two pure files carry all the thinking: where along an edge the click fell, and what an anchored point
means. The app then gains one editable cell for the percentage and one overlay marker for the point being
placed. **The window's pick machinery is not touched at all** — `meetPickHit` and `advancing` keep their
signatures, so the existing pick branch drives the new stages unchanged, and the window's whole diff is one
argument threading the percentage edit into the tier table.

### 1. `CuttingBench/BenchGeometry/Sources/BenchGeometry/MeetPickHit.swift` (edit — pure)

The parameter along the edge, and the constant the end zones are measured with.

Onto `MeetPickTuning` at `:7` (`public enum MeetPickTuning {`), after
`edgeGrabRadiusPoints` at `:10`:

```swift
/// How much of an edge's own length, at each end, snaps a click to that end's corner instead of
/// anchoring a point part-way along it. A build constant with no UI and no preference, tuned by
/// editing the number.
public static let endZoneFraction: Double = 0.10
```

The `.edge` case at `:22` (`case edge(planes: [Int], corners: [Int])`) gains the position:

```swift
/// A visible edge within the grab radius: the two facets sharing it, its two corners, and **where
/// along it the click fell** — the parameter of the closest point on the model-space segment
/// `corners[0] → corners[1]`, in `0...1`.
///
/// **Model space, not screen space**, because the end zones are a fraction of the edge's own length:
/// a screen-space parameter would make them grow and shrink with foreshortening.
case edge(planes: [Int], corners: [Int], along: Double)
```

At `:70` (`return .edge(planes: nearest.edge.planes, corners: [nearest.edge.a, nearest.edge.b])`), the
value is filled in from a new private function. The ray is the same one the facet branch already builds at
`:76` (`let ray = benchRay(`) — **hoist that construction above the edge loop** rather than building it
twice, and pass it to both.

```swift
/// Where along a model-space segment a click ray passes closest, as a parameter in `0...1`.
///
/// The standard closest-point-between-two-lines solve, clamped to the segment. **Clamped and never
/// rejected**: a ray that passes closest beyond an end still answers with that end, which is the same
/// end the click was within the grab radius of.
///
/// A degenerate segment — both corners at one point — and a ray parallel to the segment both fall out
/// as `0`, which names a real corner and so is always safe to return.
private func alongSegment(
  ray: (origin: SIMD3<Float>, direction: SIMD3<Float>),
  from: (x: Double, y: Double, z: Double),
  to: (x: Double, y: Double, z: Double)
) -> Double
```

**Nothing in this file reads `along`.** The facet branch, `isVisible`, `facetCentroid`,
`shareACorner`, `screenPoint` and `distanceToSegment` are all untouched, and the edge-versus-facet
decision — including the second-visible-edge clause part 4 added — is unchanged.

### 2. `CuttingBench/BenchGeometry/Sources/BenchGeometry/MeetPick.swift` (edit — pure): the stage

One new stage and one new type. **`MeetPickStage`, `MeetPickState` and `MeetPickOutcome` keep their
existing cases** — `empty`, `oneFacet`, `edge` and `point` all behave exactly as part 4 shipped them.

```swift
/// One end of an anchored point: the meet that names it, or the corner still awaiting a click.
///
/// `named` is a `vertex` triple, or `tcp` for an end standing at the side's axial point. `awaiting`
/// carries the cut planes still available to be its third name, which is what the overlay marks and
/// what the next click is matched against.
public enum MeetPickEnd: Equatable, Sendable {
  case named(Meet)
  case awaiting(corner: Int, candidates: [Int])
}
```

Onto `MeetPickStage` at `:14`, after `case point(planes:candidates:corner:)`:

```swift
/// A point anchored part-way along an edge: the edge's two facets, its two ends **already ordered
/// `from` then `to`**, and the percentage measured from `from`.
///
/// The ordering is settled here, once, so no later step re-derives which end is `from`.
case anchored(planes: [Int], ends: [MeetPickEnd], percent: Double)
```

**`advancing`'s `.edge` arm at `:55`** (`case .edge(let planes, let corners):`) keeps its rough check at
`:58`–`:62` exactly as it is, then branches on the new parameter instead of always selecting the edge:

- `along < MeetPickTuning.endZoneFraction` → `resolving(state, planes: planes, atCorner: corners[0], …)`
- `along > 1 - MeetPickTuning.endZoneFraction` → the same at `corners[1]`
- otherwise → `anchoring(state, planes: planes, corners: corners, along: along, …)`

**An end-zone click therefore reaches the corner through part 4's own path** (D6), which is why neither
`resolving` nor `meetPicked` changes at all. The two planes go in **the edge's own ascending order**, not a
click order — an edge click commits both names in one gesture, so there is no order to preserve, and
`solidEdges` reports them ascending (`SolidEdges.swift:9`–`:12`).

**The line part 4's stage `.edge` still holds:** a third *facet* through one end still completes as a plain
vertex, at `MeetPick.swift:101`–`:111`, untouched. What this part adds is the other half of that same
exploration bullet — clicking *along* the edge instead of a third facet.

**`advancing`'s `.facet` arm gains one stage** in the private stage switch at `:81`
(`switch state.stage {`):

```swift
case .anchored(let planes, let ends, let percent):
  // Only the end being named is live: `from` first, then `to` (D12).
  if let k = ends.firstIndex(where: { if case .awaiting = $0 { return true }; return false }),
    case .awaiting(let corner, let candidates) = ends[k],
    candidates.contains(plane)
  {
    return naming(state, planes: planes, ends: ends, at: k, corner: corner, plane: plane,
      percent: percent, solid: solid, draft: draft)
  }
  // Anything else drops the anchor and highlights that facet, the same answer every other stage gives
  // a click that means nothing to it.
  return advanced(state, .oneFacet(plane: plane))
```

A click that misses the solid still clears the pick, and a click on an edge still re-anchors — both are
handled above the stage switch and need no arm here.

### 3. `CuttingBench/BenchGeometry/Sources/BenchGeometry/MeetPick.swift` (edit — pure): the anchored point

Which end is `from`, how each end is spelled, and the meet the pair writes.

```swift
/// The edge's two corners ordered **`from` then `to`**: the one further from the axis first (D7).
///
/// Distance from the axis is `sqrt(x² + y²)`, the axis being `z`. **Ties go to the endpoint nearer the
/// girdle plane** — the smaller `abs(z)` — and a remaining tie to the corner whose cut planes, as
/// ascending `(tier, index)` pairs, sort first. That last rule is unreachable on any solid in
/// `Design/Patterns/` and exists so the answer is total and stable rather than dependent on vertex order.
public func fractionEndOrder(corners: [Int], solid: BenchSolid) -> [Int]

/// One end of an anchored point, as the meet that names it or the corner still awaiting a click
/// (D10, D11).
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
) -> Result<MeetPickEnd, DraftRefusal>

/// The meet an anchored point writes, once both its ends are named (D9, D13).
///
/// `.fraction(from: ends[0], percent: percent, to: ends[1])`, with the ends in the order
/// `fractionEndOrder` fixed and the percentage already measured from `from`. Returns
/// `.pickedFacetsDoNotMeet` for a pair either of whose ends is still `.awaiting`, which the stage machine
/// never produces and which is still better refused than written as a meet that pins nothing.
public func meetFractionPicked(
  ends: [MeetPickEnd],
  percent: Double,
  ofTier tier: String
) -> Result<Meet, DraftRefusal>
```

Two private functions carry the transitions:

```swift
/// A click that landed part-way along an edge: order the ends, spell each one, and either complete or
/// wait. **The percentage is measured from `from`** — `100 × along` when `from` is `corners[0]` and
/// `100 × (1 - along)` when it is `corners[1]` (D9).
private func anchoring(
  _ state: MeetPickState,
  planes: [Int],
  corners: [Int],
  along: Double,
  solid: BenchSolid,
  draft: PatternDraft
) -> MeetPickOutcome

/// A click on one of the awaiting end's candidates: that end becomes `.named` with the edge's two planes
/// plus the clicked one, **in that order** — the two the author expressed as an edge, then the one they
/// clicked. Completes when no end is left awaiting.
private func naming(
  _ state: MeetPickState,
  planes: [Int],
  ends: [MeetPickEnd],
  at k: Int,
  corner: Int,
  plane: Int,
  percent: Double,
  solid: BenchSolid,
  draft: PatternDraft
) -> MeetPickOutcome
```

**`anchoring` refuses as a whole or not at all.** If either end comes back `.roughDerivedPoint` the pick is
left exactly as it was and the refusal is stated once — an anchored point whose outer end cannot be spelled
is not half-placeable, and a partially-built fraction is not a state the author can act on.

**The three planes of a named end are the edge's two plus that end's third**, so the `from` and `to`
triples share two names and differ in one. **The corpus spells the same corners the other way round** — its
`P3` reads `P1@12 · P1@24 · P2@12`, which is the two facets *above* the clicked edge plus one of the edge's,
where the pick writes `P2@12 · P2@24 · P1@12`. Both name the identical point; only one of them can be
reached without naming a facet the author never clicked (D11, D21).

### 4. `CuttingBench/BenchGeometry/Sources/BenchGeometry/MeetPick.swift` (edit — pure): what the author sees

`meetPickPrompt` at `:253` gains one arm, and `MeetPickMarker.Kind` at `:273` gains one case.

**The prompt's two new sentences, verbatim**, with `<tier>` the picking tier, each facet named by
`facetLabel`, and the percentage to two decimal places as `percentText` gives it:

- `anchored`, an end still awaiting — `Picking <tier>'s meet · <pct>% along <nameA> – <nameB> · click one
  of <n> facets through the <from|to> end`
- `anchored`, neither awaiting — unreachable, because a pick with both ends named has already completed;
  the arm returns the same sentence with `· complete` in place of the trailing clause rather than
  crashing on an index.

```swift
/// The point being placed, and the percentage it currently reads.
case anchor(Double)
```

`meetPickMarkers` at `:297` gains its `.anchored` arm: a `.named` marker on each of the edge's two facets
as every other stage already does, a `.corner` ring at each of the edge's two corners, an `.anchor` marker
carrying the percentage at the interpolated point — `corners[0] + along × (corners[1] - corners[0])` in
world space — and a `.candidate` marker on each candidate of **the end being named only**, never both ends
at once (D12).

**A stored fraction gets no marker from this function** (D15): once the meet is written the pick is over,
and `meetPointDots` is what draws it.

### 5. `CuttingBench/BenchGeometry/Sources/BenchGeometry/PatternDraft.swift` (edit)

One case onto `DraftRefusal`, after `case pickedFacetsDoNotMeet(tier:)` at `:201`, and one arm onto
`message` at `:205`. Nothing else in the file changes.

```swift
/// A typed percentage outside 0...100, which the file format rejects at decode (D16).
case percentNotInRange(tier: String, typed: String)
```

Its sentence, verbatim — naming the offending element, as every case in this enum does:

- `"\"\(typed)\" is not a percentage between 0 and 100 for \(tier)'s meet."`

### 6. `CuttingBench/BenchGeometry/Sources/BenchGeometry/MeetPoints.swift` (edit)

One field, so the tier table can edit the number rather than re-parse the label.

Onto `MeetPointDot` beside `label` at `:15`:

```swift
/// The anchored point's percentage as a number, and `nil` for every other role. The label carries it
/// formatted for reading; this carries it for editing, so the cell never parses its own display text.
public var percent: Double?
```

Set on the anchored dot built at `:90`–`:96` and left `nil` on the other three roles. `init` gains the
parameter with a default of `nil`, so the two existing call sites in this file and the one in
`TierTable.swift:155` need no change beyond the anchored one.

### 7. `CuttingBench/BenchGeometry/Sources/BenchGeometry/DraftEdits.swift` (edit)

One setter, beside `setting(meet:ofTier:in:)` at `:163`.

```swift
/// The anchored percentage of a tier whose meet is a `fraction`, typed by the author (D14, D16).
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
```

**It writes through the same field every other setter does** — `edited.tiers[position].meet` — so a
percentage edit is one undo entry and rides part 2's validation exactly as an angle edit does.

### 8. `CuttingBench/CuttingBench/BenchRegions.swift` (edit)

Two edits, both inside `meetContent` at `:360` (`private func meetContent(_ row: TierTableRow) -> some
View {`) and its region's property list.

- **`TierTableRegion` gains `let commitPercent: (String, String) -> Bool`** — the tier label and the typed
  text — threaded from the window beside `edit`, which is where every other cell's commit already comes
  from.
- **In the `ForEach(row.meetPoints)` at `:366`**, a dot whose `percent` is non-`nil` draws an
  `EditableCell` in place of its `MeetDotChip`, with `stored: String(format: "%.3f", percent)` and
  `commit: { commitPercent(row.tier, $0) }`. Every other dot draws exactly as it does today.

**Three decimals because that is the corpus's own precision** — `Novice Ash-er` stores `24.862` — and the
field shows what it will store, so committing the text as shown changes nothing. A stored value carrying
more than three decimals is rounded when the author commits the field, and not by being displayed.

**A `vertex` row is untouched:** its single **M** dot has no percentage, so it keeps its chip and its
facet text, and there is no way to type a percentage onto a meet that has none.

### 9. `CuttingBench/CuttingBench/MeetPickOverlay.swift` (edit)

One arm and one colour, both small.

- `meetPickMarkerColor` at `:10` gains `.anchor` to its existing `case .named, .candidate, .corner:` line
  — one blue for all four, because they are all one thing the author is doing now.
- `content(_:)` at `:46` gains `case .anchor(let percent): MeetDotChip(label: "\(percentText(percent))%",
  colour: colour)` — the same chip as a clicked facet's, carrying the number instead of a name, so the
  point being placed reads in the same language as everything else on the viewport.

`.allowsHitTesting(false)` at `:40` stays, and stays load-bearing: a chip that ate the click would eat the
one that anchors the point.

### 10. `CuttingBench/CuttingBench/BenchWindow.swift` (edit — one argument)

**The pick machinery is untouched.** `meetPickHit` and `advancing` keep their signatures, so the pick
branch at `BenchWindow.swift:313` (`if let session = pick {`) drives the new stages with no change,
`.complete` still hands the meet to `setting(meet:ofTier:in:)` at `:328`, and `afterSolidChanged()` at
`:251` still cancels a pick across a rebuild. That the window needs no new state for an anchored point is
the sign the seam was drawn in the right place.

The whole of this file's diff is one argument to the `TierTableRegion` built at `:85`
(`TierTableRegion(`), beside the `edit:` and `startPick:` already there:

```swift
commitPercent: { tier, typed in
  edit("Change Meet") { setting(percent: typed, ofTier: tier, in: $0) }
}
```

**One construction site, not two:** `TierTableRegion` is built once, outside the `#if DEBUG` at `:95`; it is
`StatusStripRegion` that appears in both arms, and this part does not touch it.

## Explicitly not doing

- **No back-solving a percentage from an achieved depth, and no tool-chosen endpoints.**
  `design-authoring-format.md:279`–`:281` forbids both: the author names the endpoints, then sets the
  number (D19).
- **No author-designated `from`.** Which end starts the measurement is decided by the geometry (D7), not by
  an extra click — designating it would give one point two spellings.
- **No second way to reach a fraction.** It is a click along an edge, and nothing else: no menu item, no
  typed facet triple, no dialog. A `vertex` is not typeable either, for the same reason.
- **No angle tuning, no tangent-ratio rescale, no rotation, no two-point angle derivation.** All four are
  `5-Cutting-Bench-Angle-Tuning`, which inherits part 2's cache.
- **No new overlay and no `.metal` change.** The anchored point is one more marker kind on the overlay part
  4 shipped, and the ghost pass is unchanged.
- **No occlusion test on any marker**, the same rule the three existing overlays state: a facet facing away
  is reached by orbiting, and a marker the author cannot see is worse than one behind the stone.
- **No change to the `edge` stage's third-facet route.** A third facet through one end still completes as a
  plain vertex; this part adds the click-along-the-edge route beside it, and neither reshapes the other.
- **No generation of a tier's `instructions` from its picked meet.** The field stays a plain stored string
  and absent keeps meaning the author wrote nothing, so a generator can be added later without being a
  breaking change.
- **No cache, quiet-period or findings work.** A picked fraction and a typed percentage are ordinary
  committed edits and ride the machinery part 2 shipped — which is exactly why this part can close the
  folded-in ticket without touching validation.
- **No reordering or sorting of anything.** Tier order is never touched, a typed stop list is never sorted,
  and a `vertex` triple keeps the order its clicks gave it.
- **Nothing for `Kiev Triangle` beyond confirming it (D18).** No new symmetry code, no performance work, and
  no attempt to author it — the owner reading its diagrams is what authoring it needs, and no PDF page
  renderer exists on this machine.

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
  CuttingBench/BenchGeometry/Tests CuttingBench/CuttingBench` and take it clean**, which is what parts 1
  through 4 did with the same files.

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
| T1 | Prefactor: where along the edge the click fell | completed | continue | — | material alteration ↓ |
| T2 | Pure: the anchored point, its two ends, and the meet they write | completed | continue | — | material alteration ↓ |
| T3 | Pure: the prompt, the markers, and the typed percentage | completed | checkpoint | commit | material alteration ↓ |
| T4 | Anchoring a point in the viewport | completed | **owner stop** | commit | material alteration ↓ |
| T5 | The percentage, editable in the meet cell | completed | **owner stop** | commit + push | |
| T6 | `Kiev Triangle`, confirmed | completed | **owner stop** | commit | |
| T7 | Close out | completed | **owner stop** | commit + push | material alteration ↓ |

**T1 — Prefactor: where along the edge the click fell**

Behaviour-preserving. `meetPickHit` reports the position along the edge it already chose; **nothing reads
it**.

- **Files:** `CuttingBench/BenchGeometry/Sources/BenchGeometry/MeetPickHit.swift` (edit),
  `CuttingBench/BenchGeometry/Tests/BenchGeometryTests/MeetPickHitTests.swift` (edit)
- **Done when:**
  - `MeetPickTuning.endZoneFraction` is `0.10`, with the doc comment §1 gives it.
  - `MeetPickHit.edge` carries `along: Double` and `alongSegment(ray:from:to:)` exists, both with §1's doc
    comments; the ray is built **once** and passed to the edge loop and the facet branch alike.
  - `swift test --package-path CuttingBench/BenchGeometry --disable-sandbox` passes, with **every existing
    case in `MeetPickHitTests.swift` still asserting the same planes and the same corners** — the only
    permitted edit there is widening a pattern match to accept the new value.
  - New cases: a click on a silhouette edge's **midpoint** returns `along` within `0.02` of `0.5`; clicks at
    **10%** and **90%** of the way along that edge's model-space segment return `along` within `0.02` of
    `0.1` and `0.9`; and `along` is within `0...1` for every edge of the bare prism hit at its midpoint.
    Compute the expected click position by projecting the model-space point with `benchScreenPoint` and
    converting with the same `(x: sx * width, y: (1 - sy) * height)` rule the file already uses.
  - `swift test --package-path Kernel --disable-sandbox` passes.
  - `xcrun swift-format lint --recursive --strict CuttingBench/BenchGeometry/Sources
    CuttingBench/BenchGeometry/Tests CuttingBench/CuttingBench` is clean.
- **Do not:** change the edge-versus-facet decision, including part 4's second-visible-edge clause; change
  any existing expectation in `MeetPickHitTests.swift`; read `along` anywhere; touch `MeetPick.swift` or any
  app file.
- **Material alteration.** **Adding an associated value to `MeetPickHit.edge` breaks every construction and
  match site of that case, so two files outside the task's *Files* list had to be widened to compile.** The
  edits are mechanical and read nothing: `MeetPick.swift`'s hit switch became
  `case .edge(let planes, let corners, _):`, and the two `hit: .edge(…)` constructions in
  `MeetPickTests.swift` pass `along: 0.5`. No app file was touched — `BenchWindow.swift:295` matches
  `MeetPickStage.edge`, which is a different type and unchanged.
  **`MeetPickHitTests.swift`'s three whole-value `XCTAssertEqual`s against `.edge(planes:corners:)` could
  not stay whole-value** — the case now has a third member — so they became one `assertEdge` helper that
  pattern-matches and asserts the same planes and the same corners, returning `along` rather than asserting
  it. That is the plan's "widening a pattern match", applied to an equality that had to become one; no
  expectation changed.

**T2 — Pure: the anchored point, its two ends, and the meet they write**

The whole of the new geometry and the new stage: which end is `from`, how each end is spelled, and the
`fraction` the pair writes.

- **Files:** `CuttingBench/BenchGeometry/Sources/BenchGeometry/MeetPick.swift` (edit),
  `CuttingBench/BenchGeometry/Tests/BenchGeometryTests/MeetPickTests.swift` (edit)
- **Done when:**
  - `MeetPickEnd`, `MeetPickStage.anchored`, `fractionEndOrder`, `fractionEnd`, `meetFractionPicked`,
    `anchoring` and `naming` exist as §2 and §3 give them.
  - `advancing`'s `.edge` arm branches on `along` per §2, and its rough check at `:58`–`:62` is unchanged.
  - **`resolving` and `meetPicked` are not edited**, and an end-zone click reaches the corner through them.
  - `swift test --package-path CuttingBench/BenchGeometry --disable-sandbox` passes, including these cases:
    - **The corpus round-trip, which is this task's real check.** For every pattern in
      `AuthoredPatterns.all` — `BenchSolidTests.swift:26`
      (`static let all = [easyOctagon, noviceAsher, rands, roundBrilliant]`) — and every tier whose meet is a
      `fraction`: build `intermediateBenchSolid(before:draft:full:)` for that tier, **find the edge running
      from the point the file's `from` resolves to down to the side's axial point**, and drive `advancing`
      with an `.edge` hit at the stored percentage, followed by a click on one of the awaiting end's
      candidates. The pick must reach `.complete` with a `fraction` whose **percentage matches to `0.001`**,
      whose **`to` equals the file's `to` exactly**, and whose **`from` resolves to the same point as the
      file's `from`, to `1e-6`** — geometric equality of the endpoint, not equality of its spelling (D21).
      Assert the case is not vacuous by counting the tiers exercised: `Novice Ash-er` alone contributes four
      (`P2`, `P3`, `C2`, `T`), and they are the only fractions in the corpus.
    - `fractionEndOrder` puts the corner further from the axis first, on an edge of `Novice Ash-er`'s
      pavilion whose two ends differ in radius; and on a constructed pair at equal radius it puts the one
      with the smaller `abs(z)` first.
    - An `.edge` hit with `along` at `0.05` and at `0.95` **completes as a plain `vertex`** at the near and
      far corner respectively — never a `fraction`, and never a percentage of 0 or 100.
    - An `.edge` hit at `0.5` on an edge whose inner end is the side's axial point spells its inner end
      `to: .tcp`, **and no `secondTCPOnSide` question is asked of it** — check by running the same case on a
      draft whose side already carries a top-level `tcp`, where the result is unchanged. On a corpus edge
      the outer end still awaits a click at that point, so the assertion is on the stage's ends and not on
      a completion (D13).
    - An end with **exactly one** candidate is filled in without a click; an end with **none** returns
      `.refused(.roughDerivedPoint(tier:))` and leaves the state untouched; an end with **more than one**
      leaves the pick at `.anchored` with that end `.awaiting` and the other already `.named`.
    - From `.anchored`, a click on one of the awaiting end's candidates resolves it and completes; a click
      on any other facet returns `.advanced` at `.oneFacet` with that facet; `hit: nil` returns `.cleared`.
    - With **both** ends awaiting, the first click names `from` and the second names `to` — and after the
      first, only `from`'s end is `.named`.
    - `meetFractionPicked` with an end still `.awaiting` returns `.refused(.pickedFacetsDoNotMeet(tier:))`.
  - `swift test --package-path Kernel --disable-sandbox` passes.
  - `xcrun swift-format lint --recursive --strict CuttingBench/BenchGeometry/Sources
    CuttingBench/BenchGeometry/Tests CuttingBench/CuttingBench` is clean.
- **Do not:** ask `structuralFindings` anything about a fraction endpoint (D10); edit `resolving`,
  `meetPicked` or `candidatePlanes`; change the `edge` stage's third-facet route; sort a `vertex` triple;
  touch any app file.
- **Material alteration.** **The corpus round-trip as first written was unachievable, and the owner settled
  it on 2026-08-27 as geometric equality (D21).** Three of the plan's statements were wrong about the
  geometry, measured on all four of `Novice Ash-er`'s fractions — the only fractions in
  `AuthoredPatterns.all`:
  - **The recipe could not be executed.** *"Find the edge whose two planes are the two shared by the meet's
    `from` and `to` spellings"* — every corpus fraction reads `to: tcp`, which names no planes, so there is
    no shared pair. The edge that has to be clicked is **the one running from the point `from` resolves to
    down to the axial point**, and its two facets belong to the picking tier's immediate predecessor.
  - **D11 cannot produce the file's triple.** On `P2` the edge is `P1@12 – P1@24`, whose outer corner has
    four cut facets through it: `G@12`, `G@24`, `P1@12`, `P1@24`. D11 spells it with the edge's two planes
    plus one more, so the pick writes `P1@12 · P1@24 · G@12` where the file writes `G@12 · G@24 · P1@24`.
    Both name the identical point to `1e-6`; neither click order reaches the file's, because the two girdle
    facets are not the clicked edge's. `P3`, `C2` and `T` are the same shape.
  - **D13's "common case" does not occur in the corpus.** The outer corner offers **two** candidates in all
    four fractions, so each takes a second click to name `from`. D13 and §3's `P3` example are corrected
    above.

  The round-trip now asserts the percentage to `0.001`, `to` exactly, and `from` resolving to the same point
  to `1e-6`. **The corpus files were not touched.** One shipped case,
  `testAnEdgeClickSelectsItFromEveryStageAndClearsAnyHighlight`, asserted that an edge *hit* selects the
  `.edge` stage; an edge hit now anchors or snaps, so that case was rewritten against the two facet clicks
  that still reach the `.edge` stage — the stage itself is unchanged, and part 4's third-facet route through
  it is untouched.

**T3 — Pure: the prompt, the markers, and the typed percentage**

The last of the pure work: what the strip says and the overlay draws at the new stage, and the setter that
commits a typed percentage.

- **Files:** `CuttingBench/BenchGeometry/Sources/BenchGeometry/MeetPick.swift` (edit),
  `CuttingBench/BenchGeometry/Sources/BenchGeometry/MeetPoints.swift` (edit),
  `CuttingBench/BenchGeometry/Sources/BenchGeometry/PatternDraft.swift` (edit),
  `CuttingBench/BenchGeometry/Sources/BenchGeometry/DraftEdits.swift` (edit),
  `CuttingBench/BenchGeometry/Tests/BenchGeometryTests/MeetPickTests.swift` (edit),
  `CuttingBench/BenchGeometry/Tests/BenchGeometryTests/DraftEditsTests.swift` (edit)
- **Done when:**
  - `meetPickPrompt` returns §4's sentence for `.anchored`, verbatim, with the tier, both facet names, the
    percentage and the candidate count substituted, and the `from`/`to` word naming the end being asked
    about.
  - `MeetPickMarker.Kind.anchor(Double)` exists, and `meetPickMarkers` returns for `.anchored`: one `.named`
    per edge facet numbered from 1, two `.corner` rings, one `.anchor` carrying the percentage at the
    interpolated point, and `.candidate` markers for **the awaiting end only**. Every `world` is on the
    solid to `1e-6`.
  - `MeetPointDot.percent` exists, is set on the anchored dot only, and defaults to `nil` so no existing
    call site changes.
  - `DraftRefusal.percentNotInRange(tier:typed:)` exists with §5's sentence verbatim.
  - `setting(percent:ofTier:in:)` exists as §7 gives it, and: `0` collapses the meet to `from`'s own meet,
    `100` collapses it to `to`'s, a value between rewrites the percentage and leaves both endpoints
    untouched, `"abc"` returns `.notANumber`, `-1` and `101` return `.percentNotInRange`, and a tier whose
    meet is not a `fraction` is returned unchanged.
  - `swift test --package-path CuttingBench/BenchGeometry --disable-sandbox` passes, including a case that
    round-trips `Novice Ash-er`'s `P2`: setting its percentage to `0` gives exactly the `vertex` meet its
    `from` spells, and setting it back to `24.862` gives exactly the meet the file stores.
  - `swift test --package-path Kernel --disable-sandbox` passes.
  - `xcrun swift-format lint --recursive --strict CuttingBench/BenchGeometry/Sources
    CuttingBench/BenchGeometry/Tests CuttingBench/CuttingBench` is clean.
- **Do not:** add a refusal case beyond the one named; edit any other case's sentence; make `percentText`
  public — `MeetPick.swift` is in the same module and reaches it as it stands; give the anchored marker its
  own colour; touch any app file.
- **Material alteration.** **The prompt arm and the marker arm were written in T2 rather than T3**, because
  `meetPickPrompt` and `meetPickMarkers` switch over `MeetPickStage` and adding `.anchored` to it makes both
  non-exhaustive — the package would not compile without them. T3 wrote their tests. Both live in
  `MeetPick.swift`, which is in either task's *Files* list, and the commit is shared, so nothing about the
  diff differs from the plan's.
  **The marker arm needed the edge's two corners, which §2's stage shape does not carry.** §4 spells the
  anchored point as `corners[0] + along × (corners[1] - corners[0])` and so assumes both are available,
  while §2 gives the stage only `planes`, `ends` and `percent` — a `.named` end carries no corner index, so
  the two sections contradict each other. The stage now carries `corners` as well, **in `from`-then-`to`
  order**, and the point is `corners[0] + percent/100 × (corners[1] - corners[0])` — the same position §4
  asks for, and the arithmetic the solver performs on the finished meet (D9) rather than a second form of
  it.

**T4 — Anchoring a point in the viewport**

The working slice: clicking along an edge places a point, the strip says what is left to click, and a
completed fraction lands in the draft through the existing funnel.

- **Files:** `CuttingBench/CuttingBench/MeetPickOverlay.swift` (edit)
- **Done when:**
  - `meetPickMarkerColor` covers `.anchor` on its existing one-blue line, and `content(_:)` draws it as a
    `MeetDotChip` reading the percentage, per §9.
  - `.allowsHitTesting(false)` is still on the overlay.
  - `swift build --package-path CuttingBench/BenchGeometry --disable-sandbox` succeeds, and both
    `swiftc -typecheck` runs from **Checks** are clean, `-DDEBUG` and without.
  - `swift test --package-path CuttingBench/BenchGeometry --disable-sandbox` and
    `swift test --package-path Kernel --disable-sandbox` pass.
  - `xcrun swift-format lint --recursive --strict CuttingBench/BenchGeometry/Sources
    CuttingBench/BenchGeometry/Tests CuttingBench/CuttingBench` is clean.
- **Do not:** touch `BenchWindow.swift` or `BenchRegions.swift` — T5; add an occlusion test; give the
  anchored chip a second look.
- **Material alteration.** Two small departures, both forced and neither changing what is drawn.
  - **`BenchWindow.swift` had to be touched, which this task's *Files* list excludes and T5 owns.**
    `highlightedPlane(of:)` switches over `MeetPickStage`, so the new case made it non-exhaustive and
    **neither `swiftc -typecheck` run — both of which this task's *Done when* requires — could pass without
    it.** The edit is one line, `case .anchored(let planes, _, _, _): planes.last`, which is exactly what
    the `.edge` and `.point` arms beside it already do.
  - **The chip reads the marker's own label rather than calling `percentText`.** §9 writes
    `MeetDotChip(label: "\(percentText(percent))%", …)`, but `percentText` is internal to `BenchGeometry`
    and T3's *Do not* forbids making it public — so the app cannot call it. `meetPickMarkers` already
    formats the label with that same function, so the chip shows the identical string and the formatting
    still lives in one place.
  - **The negative half of the handle predicted the wrong number of clicks, and has been corrected above.**
    An end-zone click reaches part 4's corner path as D6 requires, and that path waits when the corner has
    more than one candidate — which `Novice Ash-er`'s outer corner always does. No code changed: the
    behaviour is D6 and D11 exactly as written, and the handle's prediction came from the same mistaken
    geometry D13 did.
  - **The end zone was raised from 10% to 20% at the owner's instruction after the first run** (D4). Driving
    the sequence in screen coordinates showed the transitions were sound — every visible pavilion edge of
    `Novice Ash-er` clicked at 5% along snaps to the girdle corner, offers `G@n` and `G@m`, and completes as
    `P1@n · P1@m · G@n` when either candidate's chip is clicked — but the edges are only 139 to 290 points
    long, so a tenth of one was not reliably clickable. The constant, D4, and the three cases that name a
    boundary moved together; nothing else did.
- **Verification handle** — `permanent`:
  - **Where:** the viewport and the status strip's middle segment. Open
    `Design/Patterns/Pattern-Novice-Ash-er.json`, select row `P2`, and start **Pick in viewport…** from its
    Meet menu.
  - **Positive:** click the middle of a pavilion edge running from the girdle down toward the culet — one of
    the lines between two `P1` facets. A blue chip appears at the click carrying a percentage near `50%`,
    two blue rings appear at the edge's two ends, and the strip reads
    `Picking P2's meet · <pct>% along <nameA> – <nameB> · …`. Slide the click a third of the way down and
    the percentage falls; the number rises as you click nearer the girdle end, because the measurement
    starts at the outer end. Complete the pick and `P2`'s Meet cell reads three chips — `A`, a percentage,
    `B` — with `B` reading `tcp`. ⌘Z restores the cell.
  - **Negative:** start the pick again and click within the **first tenth** of that same edge, right up by
    the girdle. **No percentage chip appears at all** — the click snaps to that end's corner and the pick
    becomes an ordinary corner pick, so the strip reads `· click one of 2 facets through the point`. Click
    one of them: the Meet cell reads a single `M` chip with three facet names — **not** a percentage of `0`.
    (Two candidates, not one, so this takes a further click; see D13.) Then start once more and click a
    **rough** prism wall: an alert names it, and the strip's prompt is unchanged.
  - **Not a fault:** the stone does not re-cut while a pick is running. The viewport shows the solid as it
    stands *before* the picking tier, with the finished stone as the ghost (D2), and the tier is re-cut when
    the meet lands.
  - **Reads:** `meetPickMarkers` and `meetPickPrompt` in
    `CuttingBench/BenchGeometry/Sources/BenchGeometry/MeetPick.swift`, and `anchoring` for the percentage
    itself.

**T5 — The percentage, editable in the meet cell**

The last of U9: the number the pick placed can be typed over, and 0 or 100 collapses the meet.

- **Files:** `CuttingBench/CuttingBench/BenchRegions.swift` (edit),
  `CuttingBench/CuttingBench/BenchWindow.swift` (edit)
- **Done when:**
  - `TierTableRegion` carries `commitPercent: (String, String) -> Bool`, and `meetContent` draws an
    `EditableCell` in place of the chip for a dot whose `percent` is non-`nil`, per §8.
  - `BenchWindow` passes `commitPercent` through the `edit` funnel, exactly as §10 gives it, at the single
    `TierTableRegion` construction site.
  - `swift build --package-path CuttingBench/BenchGeometry --disable-sandbox` succeeds, and both
    `swiftc -typecheck` runs from **Checks** are clean, `-DDEBUG` and without.
  - `swift test --package-path CuttingBench/BenchGeometry --disable-sandbox` and
    `swift test --package-path Kernel --disable-sandbox` pass.
  - `xcrun swift-format lint --recursive --strict CuttingBench/BenchGeometry/Sources
    CuttingBench/BenchGeometry/Tests CuttingBench/CuttingBench` is clean.
- **Do not:** let a percentage edit bypass `edit` (it is an ordinary undoable change); offer the field on a
  `vertex` row, or on any dot whose `percent` is `nil`; parse the percentage back out of a dot's label;
  reformat the other three dots.
- **Verification handle** — `permanent`:
  - **Where:** the tier table's Meet cell, row `P2` of `Pattern-Novice-Ash-er.json` — the middle of its three
    chips, which is a text field rather than a chip.
  - **Positive:** the field reads `24.862`. Type `40` and press Return: the cell keeps its three chips, the
    number reads `40.000`, and the pavilion visibly moves — `P2`'s facets sit further from the girdle than
    they did. ⌘Z puts both the number and the stone back. Then type `0` and Return: the three chips collapse
    to a single `M` chip reading `G@12 · G@24 · P1@24`, which is `from`'s own triple.
  - **Negative:** type `140` and press Return. An alert reads
    `"140" is not a percentage between 0 and 100 for P2's meet.`, and the field goes back to reading what it
    read before — the meet is unchanged and the stone does not move. Type `abc` and it is refused the same
    way, with the existing not-a-number sentence. And on row `P1`, whose meet is `tcp`, there is **no** field
    in the Meet cell at all.
  - **Reads:** `setting(percent:ofTier:in:)` in
    `CuttingBench/BenchGeometry/Sources/BenchGeometry/DraftEdits.swift`, and `MeetPointDot.percent` for
    whether the field appears.

**T6 — `Kiev Triangle`, confirmed**

**No code is written in this task** unless a confirmation fails. `S2` named `Kiev Triangle` so that
odd-order symmetry and the 139-facet cost shaped the design rather than surprising it, and both are already
answered in shipped code (D18). This task checks the two facts in the running app and reports them.

The pattern itself is not authored here: it can only be verified by the owner reading its diagrams, and no
PDF page renderer exists on this machine. What is checked is the two properties it stands for, on a tier the
executor can describe and the owner can make in a few seconds.

- **Files:** none — unless a confirmation fails, in which case only the file that carries it.
- **Done when:**
  - The owner reports both halves of the handle below observed.
  - `swift test --package-path CuttingBench/BenchGeometry --disable-sandbox` and
    `swift test --package-path Kernel --disable-sandbox` pass.
- **Do not:** add symmetry code, performance work or a fixture for `Kiev Triangle`; author the pattern;
  change `foldCounts(onWheel:)` or the cache; treat a failure here as a reason to edit a test.
- **Verification handle** — `permanent`:
  - **Where:** a tier row's Folds field and its Indices cell, plus the status strip's debug segment.
  - **Positive, odd-order symmetry:** in a new document on gear `96`, add a tier and type `0` into Seeds and
    `3` into Folds. The Indices cell fills in as `0 32 64` — three stops, `96 / 3` apart — and turning
    Mirror on leaves it `0 32 64`, because that set is already its own reflection. Then type `7` into Folds:
    it is **refused**, with the alert naming the fold counts gear 96 does reach.
  - **Positive, the 139-facet cost:** with `Pattern-Standard-Round-Brilliant.json` open, note the strip's
    tier-checks count, then change one tier's angle. **The count rises by the number of tiers from the
    edited one to the end, not by the whole pattern's tier count** — editing the last tier raises it by one.
    That per-tier figure is the property the folded-in ticket asked for, and it is what makes an editing UI
    not feel `tiers × planes³`.
  - **Negative:** editing a header field that changes no tier — the pattern's `notes` — leaves the
    tier-checks count **unchanged**. A count that rose there would mean the cache was being rebuilt for an
    edit no tier's result depends on.
  - **Reads:** `foldCounts(onWheel:)` and `expandedStops(seeds:folds:mirror:wheel:)` in
    `CuttingBench/BenchGeometry/Sources/BenchGeometry/TierSymmetry.swift` for the first half, and
    `BenchFindingsStore.swift:34` (`private(set) var tierChecksRun = 0`), incremented at
    `BenchFindingsStore.swift:107` (`tierChecksRun += computed.count`) from the per-tier cache in
    `CuttingBench/BenchGeometry/Sources/BenchGeometry/FindingsCache.swift`, for the second.

**T7 — Close out**

**This is the last part of the set, so this task closes the ticket and archives everything.**

- No temporary handles to delete: every handle in this plan and in parts 1 through 4 is `permanent`.
- Confirm each item in this plan's **Deferred** section has a ticket in `Design/Tickets/` with
  `Status: untriaged`.
- Report the untriaged ticket count in `Design/Tickets/`, one line.
- `commit + push` with the message below.
- **Archive per `Design/Execution-Protocol.md`'s routine** — each of these by name, one catalog line each,
  and the routine's banner judgment made for each:
  - this plan, `4-Cutting-Bench-Authoring-5-Fraction-Meets`
  - `4-Cutting-Bench-Authoring-1-Draft-And-Tier-Editing`
  - `4-Cutting-Bench-Authoring-2-Validation-And-State`
  - `4-Cutting-Bench-Authoring-3-Symmetry-And-Wheel`
  - `4-Cutting-Bench-Authoring-4-Meet-Picking`
  - the exploration `4-Cutting-Bench-Authoring`
  - the ticket `Chore-Validation-Rebuilds-The-Solid-Once-Per-Tier`, whose catalog line names this plan as
    where the work happened
- **Every catalog line is `executed`, and no document takes a banner.** The one place that needs saying:
  part 4's plan records that its `tcp` arm cannot fire on any real draft, and that reads like a
  contradiction — it is not one. The code implements that decision exactly as written and asks both
  questions of the kernel; the plan's own material-alteration note already says the arm is unreachable, and
  the ticket `Decision-A-Picked-Corner-Can-Never-Be-Written-As-TCP` carries it forward. Nothing in any of
  the five plans asserts behaviour the code does not have.
- **Material alteration — that last claim is wrong for part 4, and the owner settled it on 2026-08-27.**
  Part 4's D10 says *a click on an edge selects it and marks its endpoints, whatever stage the pick is at*,
  with a *Done when* item expecting `.advanced` at `.edge` from every stage. **This part replaced that
  rule**: an edge click now snaps to a corner or anchors a point, and no edge click reaches the `.edge`
  stage. That is exactly the contradiction the archive routine's third step is for, so **part 4 takes a
  banner naming the rule and its catalog line reads `superseded by` this plan**, in the same form the
  catalog already uses for `3-Cutting-Bench-Pattern-Display-1-Solid-And-Tier-Table`. The other six lines
  are `executed` as written above, and parts 1, 2 and 3 were each checked against the code rather than
  assumed: part 1 declares `EditableCell`'s two later members itself, and neither part 2 nor part 3 says
  anything this part changed.
- **Do not archive the exploration `5-Cutting-Bench-Angle-Tuning`** — it is a sibling exploration and the
  source for a plan not yet written. And do not archive
  `Decision-A-Picked-Corner-Can-Never-Be-Written-As-TCP` or
  `Bug-Mirror-Reads-As-An-Editable-Checkbox-But-Is-Derived`: they are untriaged tickets this set filed, not
  tickets it closed, and only the owner promotes an untriaged ticket.

## Commit points

Four, in task order. **T1, T2 and T3 share the commit that follows them** — all three are pure and
unreachable from the UI until T4 wires them, and none is worth a commit of its own.

**After T3** — `commit`

```
4-cutting-bench-authoring-5 T1-T3: a point anchored along an edge

- meetPickHit reports where along the edge the click fell, in model space, so
  the 20% end zones are a fraction of the edge's own length
- the anchored stage: the outer end is `from`, each end is a vertex triple or
  tcp, and an end-zone click is a plain vertex through part 4's own path
- a typed percentage commits through the draft funnel, with 0 and 100
  collapsing the meet to the endpoint they name
```

**After T4** — `commit`

```
4-cutting-bench-authoring-5 T4: anchoring a point in the viewport

- a click along an edge places the point, with a chip carrying its live
  percentage and rings on the edge's two ends
```

**After T5** — `commit + push`

```
4-cutting-bench-authoring-5 T5: the percentage, editable in the meet cell

- the anchored dot is a text field rather than a chip, so the number the pick
  placed can be typed over; 0 or 100 collapses the meet to a plain vertex
```

**After T6** — `commit`

```
4-cutting-bench-authoring-5 T6: Kiev Triangle, confirmed

- odd-order symmetry and the per-tier check count observed in the app; no code,
  because both were already answered by shipped work
```

**After T7** — `commit + push`

```
4-cutting-bench-authoring-5 T7: close out the authoring set

- all five parts, the exploration and the validation-cost ticket archived; every
  meet form can now be authored by clicking
```

## Deferred

Empty at authoring. The executor appends adjacent problems it found and must not fix — and files each as a
ticket in `Design/Tickets/` immediately with `Status: untriaged`, per the protocol.

- `Bug-The-Awaiting-Facets-Prompt-Does-Not-Name-Them` — the `.point` stage's prompt reads *click one of 2
  facets through the point* without saying which two, so they can only be found by spotting the candidate
  chips — which sit at facet centroids and so can be far from the clicked corner or off-screen. On
  `Novice Ash-er`'s `P2` the two are the girdle facets above the corner, whose centres are near or past the
  top edge of the frame at the default camera. Found at T4's owner stop, where it stopped the negative half
  of the check being completed twice over. **Shipped part 4 behaviour and no part of this plan's scope**, so
  filed rather than fixed.
- `Chore-Instructions-Edit-Invalidates-A-Tiers-Cached-Check` — `survivingTierPrefix` compares whole
  `TierSpec` values, so editing a tier's `instructions` drops that tier's cached result and every later one,
  even though the string reaches neither the solve nor validation. Found at T6's owner stop, where an
  instructions edit was taken for the header-field check and the count rose by one exactly as a per-tier
  spec edit should. **Shipped part 2 behaviour**, so filed rather than fixed.
