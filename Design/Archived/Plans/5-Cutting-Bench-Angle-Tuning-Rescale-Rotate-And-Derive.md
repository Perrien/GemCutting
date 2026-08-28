# 5 · Cutting Bench Angle Tuning — Rescale, Rotate and Derive

Status: **DRAFT** — not yet approved.

**One plan, not a split.** All three operations the exploration `5-Cutting-Bench-Angle-Tuning` settles are
built here: the tangent-ratio rescale of a side, the quarter turn, and a tier's angle derived from two
picked points. Nine tasks, three owner stops before the close-out. This is the whole slice — there is no
sibling plan and no part 2.

## Context

Faceting has two phases, and the app only serves the first one today. A pattern is authored for facet
placement and size, with angles entered as rough approximations off a sheet; then the author sits with the
finished pattern and revisits the angles for light performance. That second phase is what this plan
builds. **No meet is touched, no facet moves in plan view, and the stone's x/y size is unchanged** — only
heights move. Alongside it, two smaller operations that also rewrite angles or orientation without
touching a meet: turning a pattern a quarter turn so a design authored across the wheel reads the right way
round, and deriving a tier's angle from its aimed facet plus two clicked points, which is how a printed
sheet actually specifies many tiers.

**Nothing in the kernel changes and nothing new goes in the file format.** All three operations rewrite
values a pattern already stores, and the ordinary solve reproduces the result.

What this builds on, every anchor read in this session:

- **The solver takes the angle as input and derives every depth from the meets.** One tier's normals come
  from its angle and its stops and its depth from its meet — `Solver.swift:334`
  (`private mutating func cut(_ spec: TierSpec) throws(SolverError)`), with the depth switch at
  `Solver.swift:346` (`private func depth(of spec: TierSpec, normals: [Vector]) throws(SolverError)`). So
  rewriting angles and re-solving is the whole of the rescale.
- **A tier is cut to one depth, and which of its facets arrives at the point is computed, never
  authored** — `Solver.swift:394` (`private func reach(_ normals: [Vector], to target: Vector) -> Double`),
  which is `max` of the dot products. That single line is what the third of the two-point refusals checks
  against.
- **A facet's normal comes from its angle, its stop and its gear, with the part fixing the `z` sign** —
  `Geometry/Plane.swift:34` (`public func planeNormal(`). Public, so the app computes normals without a
  kernel change.
- **Width is the smaller of the two axis extents and length the larger** — `Solver.swift:225`
  (`func labelledBySize(`), whose doc comment states outright that labelling by size is what makes the
  girdle band invariant under a quarter turn. The girdle band is sized from the width at
  `Solver.swift:370` (`return sin(radians(spec.angle)) + normals[0].z * girdleTargetFraction *
  extent.width`).
- **Every edit is a pure function from draft to draft, returning a refusal instead of throwing** —
  `DraftEdits.swift:106` (`public func setting(angle typed: String, ofTier tier: String, in draft:
  PatternDraft)`), whose doc comment already states the line this plan inherits: an angle is never refused
  for its value, because a geometric consequence is reported and not blocked.
- **One edit is one undo entry, and the inverse is the whole previous draft** —
  `PatternDocument.swift:56` (`func apply(_ change: DraftChange, undoManager: UndoManager?, actionName:
  String)`). A rescale that rewrites nine tiers is one call, so it undoes in one step with nothing new
  needed.
- **Every refused edit is shown and logged from one sentence** — `RefusalPresenter.swift:24`
  (`func present(_ refusal: DraftRefusal)`), reached through the window's own funnel at
  `BenchWindow.swift:215` (`private func edit(_ actionName: String, _ change: DraftChange) -> Bool`).
- **The picking state machine is complete and reusable** — `MeetPick.swift:64` (`public func advancing(`)
  and `MeetPick.swift:430` (`public func meetPicked(`), with the intermediate stone the clicks are tested
  against built by `MeetPick.swift:650` (`public func intermediateBenchSolid(`). Starting a pick is not an
  edit and registers no undo — `BenchWindow.swift:272` (`private func startPick(_ tier: String)`).
- **The viewport already draws a solid that is not the document's**, which is how a preview costs no new
  machinery — `BenchWindow.swift:171` (`private var drawnSolid: BenchSolid { pick?.frame.solid ??
  store.solid }`).
- **The per-tier validation cache invalidates itself correctly with no work here** —
  `FindingsCache.swift:22` (`public func survivingTierPrefix(from previous: Pattern?, to next: Pattern)
  -> Int`) keeps the leading tiers that are unchanged in anything the solve reads, so a rescale drops the
  affected side onward by construction.
- **The measurements that must and must not move are already on screen.** `Metrics.swift:95`
  (`crownHeightFractionOfWidth: (table - band.top) / outline.width`) is girdle-top-to-table, which is the
  figure the exploration proved scales by exactly the tangent ratio, and the table fraction, `L/W`, width
  and girdle rows sit beside it in the same card — `MetricsReadout.swift:24`
  (`public var lengthOverWidth: String`).
- **The app target picks up new files by itself.** `CuttingBench.xcodeproj/project.pbxproj:30`
  (`isa = PBXFileSystemSynchronizedRootGroup;`), so adding a Swift file to `CuttingBench/CuttingBench/`
  needs no project edit — which the guardrails forbid anyway.
- **`Easy Octagon` is the pattern every check below uses**, and its authored values are: `G1 gdl 90.00` on
  `0 12 24 36 48 60 72 84`, `P1 pav 47.60` (`tcp`), `P2 pav 43.00`, `C1 crown 42.00` (`girdle`),
  `C2 crown 29.00` on `18 42 66 90`, `T table 0.00` on `0` whose meet is the three-facet vertex
  `C1@0 · C1@12 · C2@18`. Gear 96, `ri` 1.54, girdle target 0.0337.

Two places where the exploration and the code disagree, and **the code wins**:

- The exploration says the picker's end-snap zones are 10% of an edge. They are **20%** —
  `MeetPickHit.swift:19` (`public static let endZoneFraction: Double = 0.20`), raised by a shipped part
  because a tenth of a short edge was a matter of luck. Nothing in this plan restates the number; the
  two-point derivation reuses the picker as it stands, so whatever that constant says is what it gets.
- The exploration says every permitted index gear divides by 4. **The kernel accepts any positive gear** —
  `Pattern.swift:211` (`guard pattern.wheel > 0 else`) and `Pattern.swift:220`
  (`if let declaredWheel = tier.wheel, declaredWheel <= 0`) — so a decoded file can carry a gear of 90,
  where a quarter turn is 22.5 stops. The eight gears the app *offers* do all divide by 4
  (`TierSymmetry.swift:13`, `public let indexGears = [32, 64, 72, 80, 84, 88, 96, 120]`), which is what the
  exploration was looking at. D17 below closes the gap.

## Decisions (2026-08-27)

| # | Decision |
|---|---|
| D1 | **Tuning rescales a whole side by tangent ratio.** The author gives one tier a new angle; from that one tier, `k = tan(new) / tan(old)`, and every other rescalable tier on the same side becomes `atan(k · tan(angle))`. That transform preserves the plan view exactly and changes only height — verified on `Easy Octagon`, where the table meet's x and y are identical to sixteen digits and the height above the girdle top scales by exactly `k`. A single-tier angle change is a different operation: moving `C1` alone from 42° to 46° grows the table radius from `0.682923` to `0.771228`, 13%, which destroys the placement tuning exists to hold. |
| D2 | **Crown and pavilion rescale independently**, grouped the way the solver already groups sides: the crown side is every `crown` and `table` tier, the pavilion side every `pav` and `gdl` tier. Changing a pavilion tier touches no crown tier and the reverse. `Rand's` 65° `pav` tier therefore rescales with the rest of its pavilion, which is correct — it is a pavilion facet below the girdle. |
| D3 | **A `gdl` tier is never rescaled, excluded by its declared `part` and not by its angle**, so the outline stays whatever the author called the outline. **A tier at exactly 90.00° is additionally never rescaled whatever its `part`** — its tangent is infinite, and the arithmetic must not depend on a row being labelled correctly. |
| D4 | **A `0.00°` table needs no special case**: `tan(0) = 0`, so `atan(k · 0) = 0` and it stays flat. It is still listed as a tier the transform wrote to, showing `0.00 → 0.00`, because the list's job is to state the blast radius and silence would read as an oversight. |
| D5 | **The handle must be a tier the transform can measure a ratio from**: refused for a `gdl` tier, for `0.00°` and for `90.00°`, each with its own sentence naming the tier. At `0.00` the ratio is undefined and at `90.00` it is infinite. |
| D6 | **The target angle must be strictly between 0 and 90**, and outside that the edit is refused rather than reported. This is the one place a value is refused for being what it is, and the reason is arithmetic rather than taste: at or past those bounds the ratio is zero, infinite or negative, and an infinite ratio against a `0.00°` table yields a not-a-number angle, which cannot be encoded to JSON at all. A stone that is merely wrong is reported; a draft that cannot be saved is refused. |
| D7 | **Every angle the rescale writes is rounded to 2 decimal places**, which is what the format writes for an angle, and **the ratio is computed from the target already rounded**, so the list on screen, the file on disk and the stone in the viewport are all the same numbers. Rounding perturbs a tilt by at most 0.005°, which moves a point at radius ≤ 1.5 by ≤ 1.3 × 10⁻⁴ — under 0.007% of width on a stone normalised to width 2, and below what the format writes. |
| D8 | **The ratio is never persisted and no depth is ever written.** The transform rewrites angles, and the ordinary solve derives every depth from the meets as it always did. An implementation that shifted heights without re-solving would be wrong even though the plan view is unchanged, because each tier's offset has to come back out of its own meet. |
| D9 | **The whole side is one undoable action.** A gesture that changed nine tiers must undo in one step. |
| D10 | **The tuning card lists every tier the transform writes, in file order, with its current and proposed angle and the ratio, and nothing is written until commit.** One gesture rewriting nine angles is the most surprising thing in this design, so the preview is a requirement rather than a nicety. |
| D11 | **The field types, a grip beside it drags.** Typing commits on Return, as every other editable cell does. The drag lives on a grip immediately right of the field rather than on the field itself, because a drag gesture on a text field fights text selection and the framework gives no way to have both — the cost of that fight is not worth a gesture that a grip serves identically. **0.05° per screen point**, so 200 points of travel sweeps 10°, and the running target is clamped to `0.10 ... 89.90` per D6 and rounded to 2 dp as it moves. |
| D12 | **The drag previews through a frame the window holds, exactly as a meet pick does** — the viewport already prefers a session's solid over the store's. Nothing enters the document, no undo entry is registered, the store is untouched and playback is left alone. On release the target commits through the ordinary edit funnel. |
| D13 | **The preview is self-throttled by what the last preview cost**: after a preview solve finishes, no further preview solve starts until at least as long as that one took has passed. The four authored patterns re-solve in a few milliseconds and preview every frame; a 139-plane pattern costs 0.6 s and previews about once a second, so the same gesture can never queue solves it will not finish. No timer, no background task, no queue. |
| D14 | **The grip is disabled while a meet pick is in progress or while playback is on**, because in both cases something else owns what the viewport is showing. The field still types in both cases: typing is an ordinary edit and needs no preview. |
| D15 | **Geometric consequences of a rescale are reported, never blocked.** An angle change can make a meet unreachable, cut a tier away or stop the solid closing, and all of that goes through validation and the findings strip. The author has to be able to pass through an invalid stone while tuning. |
| D16 | **Rotation is a quarter turn and nothing else.** It adds a quarter of the gear to every tier's stops and to every index inside every `vertex`, recursing into a `fraction`'s two endpoints, each modulo the gear of the tier that stop belongs to — which for an index inside a `vertex` is the gear of the *named* tier, not the rotating one. A quarter turn swaps the two axis extents, so the smaller is unchanged, and with width defined as the smaller the width, the `L/W` and the girdle band sized from width all survive untouched. Rotation by an arbitrary number of stops is not offered: it is a rigid rotation geometrically, but the design stops aligning with the axes width and length are measured along, so both extents grow and the girdle meet resizes the band from a changed width — the stone quietly becomes a different stone. |
| D17 | **A quarter turn is refused, as a whole, when any effective gear in the pattern does not divide by 4**, naming the offending tier and its gear — or naming the pattern's own gear when it is the header's that fails. Fractional stops are forbidden and rounding one would move a facet, so there is nothing to do but decline. The eight gears the app offers all divide by 4, so this fires only on a decoded file carrying something else. **The check runs before anything is rewritten**, so a refused turn changes nothing. |
| D18 | **Authored stop order is preserved.** A tier's stops are rewritten in place, not sorted: the format permits any order and the order is data — a sheet reads `Novice Ash-er`'s eight stops as `12 24 36 48 60 72 84 0` and a pattern transcribed that way has to stay that way. |
| D19 | **One menu command, no options, one undoable action.** There is exactly one rotation available, so there is nothing to configure and no dialog. |
| D20 | **A tier's angle can be derived from its aimed facet and two picked points, app-side, in closed form.** The aimed stop and the gear fix the facet's azimuth and its `part` fixes the normal's `z` sign, so the plane has two unknowns and two points give two equations. Projecting each point onto the facet's own azimuth as `r = x·cos θ + y·sin θ`, subtracting gives **`tan a = s · (z₂ − z₁) / (r₁ − r₂)`** with `s` the part's `z` sign. **What the file stores is the resolved angle plus the three-facet vertex as the tier's meet** — no sixth meet form, no solver change, and a pattern authored this way is indistinguishable from the four already authored, because the corpus's own sheets print resolved angles. |
| D21 | **The author names the aimed facet, not the app.** The command carries one of the tier's own index stops, chosen from a submenu of that tier's stops, because a sheet gives the index and because the whole point of the third refusal below is to tell the author that the facet they aimed is not the one that arrives. A facet chosen by best fit could never fail that check. |
| D22 | **Two points at the same radius but different heights are not a failure** — the answer is a facet at `90.00°`, which the arithmetic produces on its own: the quotient is infinite and its arc-tangent is exactly 90. No special case, and no guard that would turn a real answer into a refusal. |
| D23 | **Which point is written exactly and which may slide is settled by kind, not by order.** A corner end — spelled `vertex` or `tcp`, both being points that must be hit — outranks an end anchored part-way along an edge, because a percentage along an edge is a coordinate rather than a design quantity and a small slide there costs nothing. **Where both ends are the same kind, the first picked is written**, since either is then exact to within the same rounding. The end that is written is also the point the third refusal measures against, because it is the point the solver will reach to. |
| D24 | **The three ways a derivation fails each get their own named diagnostic carrying its own numbers, and they never collapse into one message.** Nothing is written and the tier keeps the angle it had. (1) The two points coincide on the facet's azimuth — same `r` and same `z`, so there is no line to fit; names the tier, the aimed stop and both points' `r` and `z`. (2) The implied tilt contradicts the tier's declared `part` — the tangent comes out negative, meaning a `pav` tier whose points imply an upward-facing plane or the reverse; reports the signed angle the arithmetic produced, before rejection, with the part. (3) A sibling facet of the same tier takes the depth, so the aimed facet stops short; names the aimed stop, the stop that arrives instead, the derived angle and the two dot products. A derivation that failed for an unstated reason is the failure this decision exists to prevent. |
| D25 | **The third case is refused rather than reported, and that is the one that needs justifying:** the kernel reports nothing for it. Its named-point check asks whether the *named point* is a corner of the intermediate solid — `Validation.swift:20` (`case vertexNotOnIntermediateSolid(tier: String, named: [FacetRef])`) — which it genuinely is; nothing anywhere checks that the facet the author aimed is the one that gets there, because which facet arrives is determined rather than chosen. Allowing it would store a stone the author did not click and then validate clean. |
| D26 | **A tie is not a failure.** Two facets of the tier within `1e-7` of the same dot product means the point sits on the edge between them and the depth is the same number either way. That is the tolerance the kernel already uses at this scale — `Validation.swift:353` (`private let onSolidTolerance = 1e-7`). The same tolerance decides whether two picked points coincide. |
| D27 | **The second point is not recorded anywhere and a derived tier carries no mark.** An author who wants the intent kept writes it in that tier's `instructions`, which is that field's purpose. No residual or drift readout is added, because the slide is below what the format writes (D7). |
| D28 | **A point whose defining planes include a facet of the rough is refused as the discarded second point too**, even though nothing about it would reach the file. The prism is a build constant with no design meaning, so an angle derived against it would bake an arbitrary number into the pattern while looking like a designed one, and nothing in the file would record where it came from. This needs no new code: the picker already refuses it. |
| D29 | **The picking machinery is reused exactly as it stands** — the same edge grab radius, the same end-snap zones, the same two-facet-to-edge rules, the same refusal of a rough facet. What differs is only what happens on completion: two completions instead of one, the angle computed, one end written as the meet and the other discarded. |

## Tickets closed by this plan

None. No open ticket touches this slice, and the exploration folded none in.

## Prefactoring

**One task, T1, and it is the only prefactor needed.** Everything else in this plan is new pure modules
beside the existing draft edits, plus new views and window state; nothing has to move first.

The one thing that does: **a completed pick reports the meet it wrote and throws away where it landed.**
The two-point derivation needs both — the meet for one of the two ends, and the point for the arithmetic —
so the outcome grows a payload and the two completion sites fill it in. Behaviour-preserving: the meet is
identical, and the window ignores the new payload until T8. Existing coverage is heavy enough to
characterise it already (`MeetPickTests.swift` and `MeetPickHitTests.swift`), so its check is the inverted
one — those tests pass unchanged in substance, edited only where a pattern match names the case's shape.

## Approach

Three pure modules in the `BenchGeometry` package, one new file each, in the shape every module there
already has: free functions over values, no framework, no I/O, and a table-style test file beside them —
exactly as `TierSymmetry.swift` and `TierSymmetryTests.swift` do it. Then four small additions to existing
app files: a card in the inspector, an item on the tier table's meet menu, two more sessions in the window
beside the meet pick it already holds, and one menu command.

**Nothing in `Kernel/` is touched by any task in this plan.**

### 1. New: `CuttingBench/BenchGeometry/Sources/BenchGeometry/TangentRescale.swift` (pure)

The rescale, its refusals and the drag arithmetic. Four public entry points: two that take a `Double`
target and are the real work, and two thin ones that take the field's text, mirroring how
`setting(angle typed:ofTier:in:)` already accepts a string.

```swift
/// The 2-decimal-place value an angle is written at, and the one place that rounding lives (D7).
public func roundedAngle(_ degrees: Double) -> Double        // (degrees * 100).rounded() / 100

/// Degrees of target angle per screen point of drag, and the range a ratio exists in (D6, D11).
/// Build constants with no UI and no preference, tuned by editing the numbers.
public let tuningDegreesPerDragPoint: Double = 0.05
public let tuningTargetRange: ClosedRange<Double> = 0.10...89.90

/// Where a drag that started at `base` has got to: rounded to 2 dp and clamped into `tuningTargetRange`.
public func draggedTuningTarget(from base: Double, byPoints points: Double) -> Double

/// One tier the rescale writes to, formatted for the card. `id` is the label, which is unique.
public struct RescaledTier: Identifiable, Equatable, Sendable {
  public var tier: String
  public var current: String        // "42.00"
  public var proposed: String       // "46.00"
  public var proposedAngle: Double  // already rounded
  public var id: String { tier }
}

/// What a rescale would do, before anything is written.
public struct TangentRescale: Equatable, Sendable {
  public var handle: String
  public var target: Double         // rounded
  public var ratio: Double
  public var ratioText: String      // String(format: "%.4f", ratio)
  public var rows: [RescaledTier]   // every tier the transform writes, in file order, handle included
}

/// What the card lists and what the commit applies, from one function so the two cannot disagree.
public func tangentRescale(handle tier: String, toAngle target: Double, in draft: PatternDraft)
  -> Result<TangentRescale, DraftRefusal>
public func tangentRescale(handle tier: String, toTyped typed: String, in draft: PatternDraft)
  -> Result<TangentRescale, DraftRefusal>

/// The edit: the planner's rows, written into the draft. One `DraftChange`, so one undo entry (D9).
public func rescaling(handle tier: String, toAngle target: Double, in draft: PatternDraft)
  -> Result<PatternDraft, DraftRefusal>
public func rescaling(handle tier: String, toTyped typed: String, in draft: PatternDraft)
  -> Result<PatternDraft, DraftRefusal>
```

The planner, in this order:

1. **A label the draft does not carry is a no-op**, not a refusal: `.success` with a `TangentRescale`
   whose `rows` are empty and whose `ratio` is 1. Every edit in `DraftEdits.swift` already treats an
   unknown label that way — a stale selection is inert rather than wrong.
2. **The handle's own eligibility** (D5): `part == .gdl` → `.tuningHandleIsTheGirdle`; a stored angle of
   `0.00` or `90.00` after rounding → `.tuningHandleHasNoTangent`.
3. **The target** (D6): rounded, then `tuningTargetRange.contains` → `.tuningTargetOutOfRange` when it
   does not.
4. **`ratio = tan(target°) / tan(handleAngle°)`**, both in radians at the call.
5. **The side**: `.crown` and `.table` are one side, `.pav` and `.gdl` the other; the handle's own `part`
   picks which (D2). Then **the rows are every tier on that side whose `part` is not `.gdl` and whose
   rounded angle is not `90.00`** (D3), in file order, the handle among them.
6. **Each row's proposed angle**: the handle takes the rounded target exactly; every other row takes
   `roundedAngle(atan(ratio * tan(angle°)) in degrees)`. A `0.00°` tier comes out `0.00` by arithmetic
   alone (D4).
7. `current` and `proposed` are `String(format: "%.2f", …)`, matching the tier table's own angle cell.

`rescaling(handle:toAngle:in:)` calls the planner and, on success, writes each row's `proposedAngle` into
its tier and nothing else. **No depth, no meet and no ratio is written** (D8).

### 2. New: `CuttingBench/BenchGeometry/Sources/BenchGeometry/QuarterTurn.swift` (pure)

```swift
/// A quarter of a gear, in stops, or `nil` for a gear a quarter turn cannot be expressed on (D17).
func quarterTurnStops(onWheel wheel: Int) -> Int?      // wheel % 4 == 0 ? wheel / 4 : nil

/// The gear that stops this pattern turning, as the refusal names it, or `nil` when every gear divides
/// by 4. Checked over the header's gear and every tier's effective gear, in file order.
public func quarterTurnRefusal(in draft: PatternDraft) -> DraftRefusal?

/// The whole pattern, turned a quarter turn counter-clockwise — the direction the index advances in.
/// **Refuses as a whole or not at all** (D17).
public func turningAQuarter(_ draft: PatternDraft) -> Result<PatternDraft, DraftRefusal>

/// Every index inside a meet, advanced a quarter turn on the gear of the tier that index *names* —
/// which is not the gear of the tier carrying the meet. Recurses into a `fraction`'s two endpoints.
/// An index naming a tier the draft does not carry is left exactly as it is: a dangling reference is a
/// fault the findings already report, and inventing a gear for it would turn one fault into two.
func turned(_ meet: Meet, gearOfTier: (String) -> Int?) -> Meet
```

`turningAQuarter` runs `quarterTurnRefusal` first and returns it if there is one, so nothing is half
rewritten. Then, for each tier: **its stops rewritten in place** as `(stop + quarter) % gear` with `gear`
the tier's own effective gear and the authored order preserved (D18), and **its meet run through
`turned`**. `size`, `tcp` and `girdle` carry no index and come back unchanged. The header gear, the `ri`,
the girdle target, the angles, the parts and the tier order are all untouched.

### 3. New: `CuttingBench/BenchGeometry/Sources/BenchGeometry/AngleFromTwoPoints.swift` (pure)

```swift
/// One end of a two-point derivation: what the picker spelled it as, and where it is in model space.
public struct DerivationEnd: Equatable, Sendable {
  public var meet: Meet
  public var point: SIMD3<Double>
}

/// What the derivation writes: the angle, and the end that becomes the tier's meet (D20, D23).
public struct DerivedTierAngle: Equatable, Sendable {
  public var angle: Double
  public var meet: Meet
}

/// A point's distance along a facet's own azimuth: `r = x·cos θ + y·sin θ`, with
/// `θ = 2π · stop / wheel` — the same wheel convention `planeNormal` uses.
public func azimuthRadius(of point: SIMD3<Double>, atStop stop: Int, wheel: Int) -> Double

/// Whether this end is a point that must be hit rather than one that may slide: `vertex` and `tcp` yes,
/// `fraction` no (D23). `size` and `girdle` cannot come out of a pick and answer `false`.
public func isCornerEnd(_ meet: Meet) -> Bool

/// Which of the two ends is written as the meet — `0` or `1`. The corner end wins; where both are the
/// same kind the first picked wins (D23).
public func anchorEnd(first: DerivationEnd, second: DerivationEnd) -> Int

/// The angle the aimed facet must be cut at to arrive at both points, with the meet to write beside it —
/// or which of the three ways it failed (D24). `wheel` is the tier's **effective** gear and `stops` its
/// own index stops, both as the draft gives them.
public func derivedAngle(
  ofTier tier: String,
  aimedStop: Int,
  wheel: Int,
  part: Part,
  stops: [Int],
  first: DerivationEnd,
  second: DerivationEnd
) -> Result<DerivedTierAngle, DraftRefusal>
```

`derivedAngle`, in this order:

1. `r₁`, `r₂` from `azimuthRadius` at the aimed stop; `z₁`, `z₂` straight off the points; `s` is `+1` for
   `.crown` and `.table`, `-1` for `.pav` and `.gdl` — the same signs `planeNormal` applies.
2. **Coincident** (D24 case 1, D26): `abs(r₁ - r₂) <= 1e-7 && abs(z₁ - z₂) <= 1e-7` →
   `.derivationPointsCoincide(tier:stop:r1:z1:r2:z2)`.
3. `let tangent = s * (z₂ - z₁) / (r₁ - r₂)`, then `let angle = atan(tangent) * 180 / .pi`. **A zero
   denominator is not guarded**: the quotient is infinite, its arc-tangent is exactly ±90, and a facet at
   `90.00°` is the honest answer to two points at one radius (D22). `guard angle.isFinite` is still
   written, and a not-a-number falls to case 1's refusal, because a not-a-number angle must never reach
   the draft.
4. **Contradicts the part** (D24 case 2): `angle < 0` → `.derivedAngleContradictsPart(tier:part:angle:)`,
   carrying the signed angle as computed. **Exactly zero is allowed** — that is a table, and it is the
   answer for two points at one height.
5. `let written = roundedAngle(angle)` — from `TangentRescale.swift`, one rounding for the whole plan.
6. **The anchor**: `anchorEnd(first:second:)` picks the end whose meet is written and whose point the next
   step measures against (D23).
7. **The sibling check** (D24 case 3, D25, D26), against the **rounded** angle because that is what will
   be stored: `aimedDot` is `planeNormal(angleDegrees: written, index: aimedStop, wheel: wheel, part:
   part)` dotted with the anchor point; the same for every stop in `stops`. If any stop's dot exceeds
   `aimedDot + 1e-7`, the largest such stop is the one that arrives →
   `.siblingFacetTakesTheDepth(tier:aimed:arrives:angle:aimedDot:arrivingDot:)`. Within `1e-7` is a tie
   and passes.
8. `.success(DerivedTierAngle(angle: written, meet: <anchor end's meet>))`.

The numbers the two refusals report travel as one value, declared in this file:

```swift
/// What a refused derivation reports: the aimed stop, and both points as the arithmetic saw them.
public struct DerivationNumbers: Equatable, Sendable {
  public var stop: Int
  public var r1: Double
  public var z1: Double
  public var r2: Double
  public var z2: Double
}
```

### 4. `CuttingBench/BenchGeometry/Sources/BenchGeometry/PatternDraft.swift`

Seven cases onto `DraftRefusal` at `:179` (`public enum DraftRefusal: Error, Equatable, Sendable {`), each
with its sentence in `message` at `:207` (`public var message: String {`). Appended after
`.percentNotInRange` in both places, so the case order and the sentence order stay the same list.
Every sentence below is **verbatim**; coordinates are `String(format: "%.6f", …)` and angles
`String(format: "%.2f", …)`.

```swift
case tuningHandleIsTheGirdle(tier: String)
case tuningHandleHasNoTangent(tier: String, angle: Double)
case tuningTargetOutOfRange(tier: String, target: Double)
case quarterTurnGearNotDivisible(tier: String?, wheel: Int)
case derivationPointsCoincide(tier: String, numbers: DerivationNumbers)
case derivedAngleContradictsPart(tier: String, part: Part, angle: Double, numbers: DerivationNumbers)
case siblingFacetTakesTheDepth(
  tier: String, aimed: Int, arrives: Int, angle: Double, aimedDot: Double, arrivingDot: Double)
```

- `tuningHandleIsTheGirdle` — `"\(tier) is a girdle tier: its facets set the outline, and rescaling a side
  never moves the outline. Tune from a crown or pavilion tier instead."`
- `tuningHandleHasNoTangent` — `"\(tier) cannot be the tier you tune from: at \(angle)° there is no ratio
  to measure. Tune from a tier between 0.10° and 89.90°."`
- `tuningTargetOutOfRange` — `"\(target)° is outside 0.10° to 89.90°, which is the range \(tier)'s side can
  be rescaled through."`
- `quarterTurnGearNotDivisible` — `"This pattern cannot be turned a quarter turn: "` then, for a named
  tier, `"\(tier)'s gear of \(wheel) does not divide by 4, so a quarter turn would land between stops."`
  and, for `nil`, `"the pattern's gear of \(wheel) does not divide by 4, so a quarter turn would land
  between stops."`
- `derivationPointsCoincide` — `"\(tier)@\(numbers.stop) cannot take its angle from those two points: both
  sit at the same place on that facet's azimuth — \(r1), \(z1) and \(r2), \(z2) — so they name no tilt.
  Pick a second point at a different height or distance."`
- `derivedAngleContradictsPart` — `"Those two points put \(tier)@\(numbers.stop) at \(angle)°, which faces
  the wrong way for a \(part.rawValue) tier — \(r1), \(z1) and \(r2), \(z2). Pick points a
  \(part.rawValue) facet could reach."`
- `siblingFacetTakesTheDepth` — `"\(tier) cut at \(angle)° does not arrive at that point on stop \(aimed):
  stop \(arrives) gets there first, reaching \(arrivingDot) against \(aimedDot). Aim the stop that
  arrives, or pick points on the facet you aimed."`

### 5. `CuttingBench/BenchGeometry/Sources/BenchGeometry/MeetPick.swift` — T1's prefactor, and one extraction

**The prefactor (T1).** `MeetPickOutcome.complete` at `:53` (`case complete(Meet)`) becomes
`case complete(Meet, at: SIMD3<Double>)`, with its doc comment gaining a sentence saying the point is
where the completed pick landed in model space, carried for a caller deriving an angle from it and ignored
by a caller writing a meet. Both construction sites fill it in:

- `:203` (`case .success(let meet): return .complete(meet)`) inside `completing(` at `:193` — the corner's
  own position, `solid.polytope.vertices[corner]` as a `SIMD3<Double>`. Guard the index and fall to
  `.refused(.pickedFacetsDoNotMeet(tier: state.tier))` if it is out of range, which is what `meetPicked`
  already answers for that case.
- `:359` (`case .success(let meet): return .complete(meet)`) inside `anchored(` at `:350`. That function
  has no `solid`, so it takes the point as a parameter and its two callers — `:342` and the tail of
  `anchoring(` — compute it with a new helper:

```swift
/// Where an anchored point sits: `corners[0] + percent/100 × (corners[1] - corners[0])`, which is the
/// arithmetic the solver performs on the finished meet and the reason `corners` is stored `from` then
/// `to`. `nil` for a pair of corner indices the polytope does not carry.
func anchoredPoint(corners: [Int], percent: Double, solid: BenchSolid) -> SIMD3<Double>?
```

`meetPickMarkers` at `:571` computes that same position inline for its `.anchor` marker at `:620`–`:628`;
**it calls the helper instead**, converting with `SIMD3<Float>(Float(p.x), Float(p.y), Float(p.z))`, so
there is one copy of the arithmetic rather than two. A `nil` from the helper at the completion sites is
`.refused(.pickedFacetsDoNotMeet(tier:))`.

**The extraction (T7).** `meetPickPrompt` at `:499` is `opening + <the stage, in words>`. The stage half
moves into `func stageSentence(_ stage: MeetPickStage, solid: BenchSolid) -> String` and
`meetPickPrompt` becomes its opening plus that call — no wording changes, so its existing tests hold. The
derivation's own prompt then reuses it:

```swift
/// What the status strip says while an angle is being derived. The aimed facet, which of the two points
/// is being picked, then the same stage words a meet pick shows.
public func angleDerivationPrompt(
  tier: String, aimedStop: Int, pointsTaken: Int, stage: MeetPickStage, solid: BenchSolid
) -> String
```

reading `"Deriving \(tier)@\(aimedStop)'s angle · point \(pointsTaken + 1) of 2 · "` then
`stageSentence(stage, solid: solid)`.

### 6. `CuttingBench/BenchGeometry/Sources/BenchGeometry/DraftEdits.swift`

One function, appended to the *A tier's own values* section after `setting(angle typed:ofTier:in:)` at
`:106`:

```swift
/// The two-point derivation's one write: the angle and the meet together, so undo puts both back in one
/// step. Never refused — every way the derivation can fail was answered before this is called.
public func setting(derived: DerivedTierAngle, ofTier tier: String, in draft: PatternDraft)
  -> Result<PatternDraft, DraftRefusal>
```

An unknown label is `.success(draft)`, as everywhere else in the file.

### 7. `CuttingBench/CuttingBench/BenchRegions.swift`

**One new card, one new menu item, and two closures threaded in.**

`TierTableRegion` at `:151` gains one stored property beside `startPick` at `:163`:

```swift
/// Starts an angle derivation on one tier, aimed at one of its own index stops. **Not `edit`**, for the
/// same reason `startPick` is not: aiming changes no draft and must register no undo entry.
let startDerivation: (String, Int) -> Void
```

`meetMenu(_ row:)` at `:402` gains a submenu directly under the `Pick in viewport…` button at `:408`,
before the `Divider()` at `:409`. It belongs on the Meet menu and not on the Angle cell because the
command writes the meet as well as the angle:

```swift
Menu("Derive angle from two points…") {
  ForEach(Array(stops(row).enumerated()), id: \.offset) { _, stop in
    Button("aim \(row.tier)@\(stop)") { startDerivation(row.tier, stop) }
  }
}
```

`stops(_ row:)` reads `draft.tiers.first(where: { $0.tier == row.tier })?.indices ?? []`, the way the Wheel
cell at `:336` already reads the draft for `gearsOffered`. **Enumerated and keyed by position**, because the
format permits a repeated stop and two identical `id`s in one `ForEach` is a bug.

`InspectorRegion` at `:501` gains six stored properties and one card. The card sits **directly after
`Notes` and before `Metrics`** in `body` at `:520`, because the author tunes and then reads the
measurements that moved:

```swift
/// The tier the table has selected, which is the tier a rescale is measured from. `nil` for none.
let selectedTier: String?
/// The target the tuning drag has reached, or `nil` when no drag is running.
let tuningTarget: Double?
/// Whether the tuning grip can run — false while a meet pick or playback owns the viewport (D14).
let tuningDragEnabled: Bool
/// Returns whether the rescale was accepted, so the field can snap back on a refusal.
let commitTuning: (String) -> Bool
let tuningDragChanged: (Double) -> Void
let tuningDragEnded: () -> Void
```

```swift
GroupBox("Tuning") {
  TuningCard(
    draft: draft, selectedTier: selectedTier, liveTarget: tuningTarget,
    dragEnabled: tuningDragEnabled, commit: commitTuning,
    dragChanged: tuningDragChanged, dragEnded: tuningDragEnded)
}
```

The card itself, `private struct TuningCard: View`, placed after `NotesCard` in the file:

- **State:** `@State private var typed = ""` and `@State private var dragBase: Double?`.
  **It does not use `EditableCell`**, deliberately: that cell's buffer follows the stored value, and here
  the list of proposed angles has to follow the *buffer* so the author sees what a commit would do before
  committing (D10).
- **The stored angle** is `String(format: "%.2f", angle)` of the selected tier, and `nil` for no selection
  or a label the draft does not carry.
- **What the card is showing** is `liveTarget.map { String(format: "%.2f", $0) } ?? typed`.
- **Seeding and reverting:** `.onChange(of: storedAngle, initial: true) { typed = storedAngle ?? "" }`,
  and `.onChange(of: liveTarget) { _, value in if let value { typed = String(format: "%.2f", value) } }`.
  **Return commits** — `.onSubmit { if !commit(typed) { typed = storedAngle ?? "" } }` — and losing focus
  reverts the buffer rather than committing, unlike every table cell, because a side-wide rescale must not
  fire from a stray click somewhere else in the window.
- **No selection** shows one sentence and nothing else: `"Select a tier in the table to tune its side."`
- **Otherwise** it switches on `tangentRescale(handle: tier, toTyped: shown, in: draft)`:
  - `.failure(let refusal)` — the field row, then `Text(refusal.message)` in `.secondary`. That is how a
    girdle row, a `0.00°` row and an out-of-range target all explain themselves, in the same words the
    alert would use.
  - `.success(let plan)` — the field row, then `Text("Ratio \(plan.ratioText)")`, then one line per
    `plan.rows` entry: the tier label, a spacer, `row.current`, `"→"`, `row.proposed`. `ForEach` over
    `plan.rows` directly, which are `Identifiable` by label.
- **The field row** is the `TextField` bound to `$typed`, a `Text("°")`, then the grip:
  `Image(systemName: "arrow.left.and.right")` carrying
  `.gesture(DragGesture().onChanged { … }.onEnded { … })` and `.disabled(!dragEnabled)`.
  `onChanged` sets `dragBase = dragBase ?? storedAngleValue` — `DragGesture` has no start callback, so the
  first change is the start — then calls
  `dragChanged(draggedTuningTarget(from: base, byPoints: g.translation.width))`. `onEnded` calls
  `dragEnded()` and sets `dragBase = nil`. **Horizontal travel only**, right for a larger angle.

### 8. `CuttingBench/CuttingBench/BenchWindow.swift`

Two more sessions beside the meet pick, in the shape that file already uses for one.

```swift
/// A tangent-ratio drag in flight, and the stone it is previewing. **Nothing here reaches the document**
/// (D12): the viewport prefers a session's solid over the store's, so a preview needs no new machinery.
@State private var tuning: TuningPreview?
/// An angle being derived from two clicks, or `nil` for none.
@State private var derive: AngleDerivation?

/// A rescale being previewed. `lastSolve` and `lastFinished` are the whole of the throttle (D13).
struct TuningPreview {
  var handle: String
  var target: Double
  var frame: PlaybackFrame
  var lastSolve: Duration?
  var lastFinished: ContinuousClock.Instant?
}

/// A two-point derivation and the stone its clicks are tested against, which is the intermediate solid
/// before the aimed tier — the same solid a meet pick on that tier would use.
struct AngleDerivation {
  var tier: String
  var aimedStop: Int
  var frame: PlaybackFrame
  var state: MeetPickState
  /// The first of the two ends, once it is taken.
  var first: DerivationEnd?
}
```

The edits, each at its own anchor:

- `:171` (`private var drawnSolid: BenchSolid { pick?.frame.solid ?? store.solid }`) and `:172` — both
  become `pick?.frame.X ?? derive?.frame.X ?? tuning?.frame.X ?? store.X`. **A pick and a derivation
  cannot both be live** (each start clears the other), and the grip is disabled during a pick (D14), so
  the order only fixes what is already exclusive.
- `:175` (`private var ghostMesh: SolidMesh? { pick == nil ? nil : store.fullMesh }`) — a derivation shows
  the same ghost, so the test becomes `pick == nil && derive == nil`. `:179`'s `ghostGeneration` takes the
  same condition for its low bit. **The tuning preview shows no ghost**: it is the whole stone already.
- `:69` (`pickMarkers: pick.map { meetPickMarkers($0.state, solid: $0.frame.solid) } ?? []`) — falls
  through to `derive.map { meetPickMarkers($0.state, solid: $0.frame.solid) } ?? []`.
- `:105` and `:119` (`pickPrompt: pick.map { meetPickPrompt($0.state, solid: $0.frame.solid) }`) — fall
  through to
  `derive.map { angleDerivationPrompt(tier: $0.tier, aimedStop: $0.aimedStop, pointsTaken: $0.first == nil ? 0 : 1, stage: $0.state.stage, solid: $0.frame.solid) }`.
  Both call sites, `#if DEBUG` and not.
- `:106` and `:120` (`cancelPick: endPick`) — `endPick` clears `derive` as well as `pick`, so Cancel ends
  whichever is running. Its doc comment gains that sentence; no new button.
- `:262` (`pick = nil` inside `afterSolidChanged()`) — clears `derive` and `tuning` too, for the reason
  already written there: a plane index means nothing across a rebuild. **This is also what tidies up after
  a committed drag**, because the commit changes `document.pattern`, which runs `rebuild()`.
- `:85`–`:95` (the `TierTableRegion(` call) — passes `startDerivation: startDerivation(_:aimedStop:)`.
- `:130`–`:139` (the `InspectorRegion(` call) — passes `selectedTier: selectedTier`,
  `tuningTarget: tuning?.target`, `tuningDragEnabled: pick == nil && store.granularity == nil`,
  and the three closures below.
- `.focusedSceneValue(\.turnAQuarter, turnAQuarter)` on the root `VStack`, beside the modifiers at
  `:161`–`:167`.

New private methods:

```swift
/// The Tuning card's field. One `DraftChange` for the whole side, so it undoes in one step (D9).
private func commitTuning(_ typed: String) -> Bool

/// One step of a tuning drag: hold the target, then preview if the throttle allows it (D13).
private func tuningDragChanged(_ target: Double)

/// The drag released: commit the target it reached, then drop the preview.
private func tuningDragEnded()

/// The preview solve, or nothing when the last one has not yet earned another (D13).
private func previewTuning()

/// **Aim a tier at one of its stops.** Not an edit: aiming changes no draft, so it registers no undo
/// entry and passes through no funnel — the same rule `startPick` states.
private func startDerivation(_ tier: String, aimedStop: Int)
```

- `commitTuning` — `guard let selectedTier else { return false }`, then
  `edit("Tune Side") { rescaling(handle: selectedTier, toTyped: typed, in: $0) }`, whose `Bool` it returns.
- `tuningDragChanged` — `guard let handle = selectedTier else { return }`. If `tuning == nil`, start one
  whose `frame` is `PlaybackFrame(solid: store.solid, mesh: store.mesh)`, so the viewport does not blink.
  Set `target`, then `previewTuning()`.
- `previewTuning` — `guard let session = tuning`. If `session.lastFinished` and `session.lastSolve` are
  both set and `ContinuousClock.now - lastFinished < lastSolve`, return and draw nothing new. Otherwise:
  ask the planner for the target through `rescaling(handle: session.handle, toAngle: session.target, in:
  document.draft)`; on `.failure` return and leave the frame as it is — a refused target previews nothing
  and the card is already showing the sentence; on `.success(let previewDraft)`, take
  `previewDraft.displayPattern`, and around `benchSolid(for:)` plus `solidMesh(_:)` measure with
  `ContinuousClock().measure { … }`. Store the new frame, `lastSolve` and `lastFinished`, and bump
  `drawGeneration`.
- `tuningDragEnded` — `commitTuning(String(format: "%.2f", tuning?.target ?? 0))` when a `tuning` exists,
  then `tuning = nil` and `drawGeneration += 1`. A drag that ended where it started commits a draft equal
  to the current one, which registers no undo entry — that is `apply`'s existing rule at
  `PatternDocument.swift:66` (`guard edited != previous else { return nil }`), not a new one.
- `startDerivation` — `frame` from `intermediateBenchSolid(before: tier, draft: document.draft, full:
  store.full)`, exactly as `startPick` at `:272` does it; then `pick = nil`, `tuning = nil`,
  `drawGeneration += 1`, and the same three clears `startPick` performs.

`pick(at:in:)` at `:314` gains a branch **before** the existing `if let session = pick`, because a
derivation and a pick are exclusive and the derivation is the newer state:

```swift
if let session = derive {
  let solid = drawnSolid
  let hit = meetPickHit(solid, click: …, size: …, camera: camera)   // the same call the pick branch makes
  switch advancing(session.state, hit: hit, solid: solid, draft: document.draft) {
  case .advanced(let next): derive?.state = next; <highlight, as the pick branch does>
  case .complete(let meet, let point): <below>
  case .refused(let refusal): refusals.present(refusal)
  case .cleared: endPick()
  }
  return
}
```

On `.complete`, with `end = DerivationEnd(meet: meet, point: point)`:

- **No first end yet** — store it and reset the stage for the second point:
  `derive?.first = end` and `derive?.state = MeetPickState(tier: session.tier)`.
- **The first end is in hand** — call
  `derivedAngle(ofTier: session.tier, aimedStop: session.aimedStop, wheel: document.draft.wheel(of: <the
  tier's DraftTier>), part: <its part>, stops: <its indices>, first: first, second: end)`. On `.success`,
  `edit("Derive Angle") { setting(derived: derived, ofTier: session.tier, in: $0) }` and `endPick()`. On
  `.failure`, present the refusal and **keep the first end**, resetting only the stage — one more click
  retries the second point, which is the same kindness the picker's own mis-click rule gives, and Cancel
  ends it.
- A tier the draft no longer carries: `endPick()` and nothing written.

### 9. New: `CuttingBench/CuttingBench/PatternCommands.swift`, and one line in `CuttingBenchApp.swift`

The menu bar cannot reach the focused document, and the quarter turn needs the window's undo manager as
well as its draft — so the window publishes the action itself and the command calls it.

```swift
/// The focused window's quarter-turn action. **A closure rather than the document**: the turn is an edit,
/// and edits go through the window's own funnel, which owns the undo manager and the refusal presenter.
private struct TurnAQuarterKey: FocusedValueKey { typealias Value = () -> Void }

extension FocusedValues {
  var turnAQuarter: (() -> Void)? {
    get { self[TurnAQuarterKey.self] }
    set { self[TurnAQuarterKey.self] = newValue }
  }
}

/// The Pattern menu: operations over the whole pattern rather than one tier. One item so far (D19).
struct PatternCommands: Commands {
  @FocusedValue(\.turnAQuarter) private var turnAQuarter

  var body: some Commands {
    CommandMenu("Pattern") {
      Button("Turn a Quarter Turn") { turnAQuarter?() }
        .disabled(turnAQuarter == nil)
    }
  }
}
```

**The item is not disabled for a pattern that cannot be turned** (D17): a greyed-out item explains
nothing, while the refusal names the tier and the gear that stopped it.

`CuttingBenchApp.swift:9`–`:14` (the `.commands {` block) gains `PatternCommands()` beside the existing
`CommandGroup(after: .newItem)`. The window's own action is
`private func turnAQuarter() { edit("Turn a Quarter Turn") { turningAQuarter($0) } }`.

## Checks

The protocol's gates apply as written. Three notes on which of them fire here:

- **Gate 1, tests** — `swift test --package-path Kernel --disable-sandbox` is unconditional, and **no task
  in this plan touches `Kernel/`**, so it is only ever confirming that nothing broke. Every new test lives
  in the `BenchGeometry` package and runs with
  `swift test --package-path CuttingBench/BenchGeometry --disable-sandbox`, which every task below names in
  its own *Done when*.
- **Gate 3, the release build** — conditional on `Kernel/` having been touched, so it never fires.
- **Format, gate 2**, covers `Kernel/` only as written. **Also run
  `xcrun swift-format lint --recursive --strict CuttingBench/BenchGeometry/Sources
  CuttingBench/BenchGeometry/Tests CuttingBench/CuttingBench` and take it clean**, which is what every
  part of the four plans before this one did with the same files.

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

## Explicitly not doing

- **No solver change and nothing new in the file format.** All three operations rewrite values a pattern
  already stores (D1, D16, D20).
- **No free rotation and no rotation by an arbitrary number of stops** (D16). If it is ever wanted it is a
  deliberate "re-author in a new orientation" operation that admits it changes the design.
- **No sixth meet form carrying two points with the angle absent** (D20). It would preserve the second
  constraint through a later rescale, and the rescale does preserve it — but it makes the solver solve tilt
  and offset simultaneously instead of normals then depth, and it is a third format change on top of the
  two already made.
- **No residual or drift readout for the derivation, and no mark on a derived tier** (D27). The slide is
  below what the format writes.
- **No marker for the first of the two picked points.** The prompt says which point is being taken and the
  clicked facets are already chipped; a second overlay kind for a point that has been taken is convenience
  only.
- **No preview while typing in the tuning field beyond the list of proposed angles.** The stone follows the
  grip, not the keyboard: a re-solve per keystroke is the queue D13 exists to prevent.
- **Nothing for the one known non-flat-girdle design.** A `gdl` tier is never rescaled (D3), so a non-flat
  girdle stays rigid while the rest of its side stretches, which will look wrong rather than silently move
  the outline. The owner has not yet looked the pattern up, and the behaviour is defined either way. **No
  ticket** — there is nothing actionable until the pattern is found.
- **No new setting, no preference and no toggle.** The three build constants — degrees per drag point, the
  target range, and the tolerance — are numbers in the source with their reasons beside them.
- **No yield readout, no volume code, no pattern browser, no printing, no GemCad interop, no
  photorealistic render, nothing for iPad.** Carried forward unchanged.

## Tasks

| # | Task | Status | Then | Commit | Note |
|---|---|---|---|---|---|
| T1 | Prefactor: a completed pick reports where it landed | completed | continue | — | |
| T2 | Pure: the tangent-ratio rescale and its refusals | completed | checkpoint | commit | |
| T3 | The Tuning card: the field, the list and the ratio | completed | continue | — | |
| T4 | Dragging the grip, previewed and self-throttled | completed | **owner stop** | commit + push | |
| T5 | Pure: the quarter turn | completed | continue | — | |
| T6 | The Pattern menu's one command | completed | **owner stop** | commit | |
| T7 | Pure: the angle from two points, and its three refusals | completed | continue | — | |
| T8 | Deriving an angle in the viewport | completed | **owner stop** | commit + push | Material alteration: §6's `setting(derived:ofTier:in:)` is required by this task's *Done when* and its verification handle, but `DraftEdits.swift` appears in no task's *Files* list. Built here. |
| T9 | Close out | awaiting owner | **owner stop** | commit + push | |

**Three owner stops before the close-out, and T3 is deliberately not one of them.** T3 puts a card on screen
but leaves it typed-only, which is half of one operation rather than a thing to sign off; the field and the
grip are verified together at T4. Run T3 and T4 back to back without pausing.

**T1 — Prefactor: a completed pick reports where it landed**

Behaviour-preserving. The meet every pick writes is unchanged; the outcome simply also carries the point,
and nothing reads it yet.

- **Files:** `CuttingBench/BenchGeometry/Sources/BenchGeometry/MeetPick.swift` (edit),
  `CuttingBench/BenchGeometry/Tests/BenchGeometryTests/MeetPickTests.swift` (edit),
  `CuttingBench/CuttingBench/BenchWindow.swift` (edit — one pattern match)
- **Done when:**
  - `MeetPickOutcome.complete` is `case complete(Meet, at: SIMD3<Double>)`, with the doc sentence §5 gives
    it.
  - `anchoredPoint(corners:percent:solid:)` exists with §5's doc comment, and `meetPickMarkers`' `.anchor`
    marker is computed through it rather than inline.
  - Both completion sites fill the point in: the corner's own polytope vertex, and the anchored point from
    the helper. A corner index the polytope does not carry, and a `nil` from the helper, are each
    `.refused(.pickedFacetsDoNotMeet(tier:))`.
  - `BenchWindow.swift:331` reads `case .complete(let meet, _):` and the window's behaviour is otherwise
    untouched.
  - **Every existing test in the `BenchGeometry` package passes with no expectation altered** — the only
    edits to `MeetPickTests.swift` are pattern matches naming the case's new shape.
  - Two new cases on `Easy Octagon`: a corner completion whose reported point equals
    `solid.polytope.vertices[corner]` exactly, and an anchored completion whose reported point equals
    `from + percent/100 × (to − from)` over the stage's two corners within `1e-12`.
  - `swift test --package-path CuttingBench/BenchGeometry --disable-sandbox` and
    `swift test --package-path Kernel --disable-sandbox` pass.
  - Both `swiftc -typecheck` runs from **Checks** are clean, `-DDEBUG` and without.
  - `xcrun swift-format lint --recursive --strict CuttingBench/BenchGeometry/Sources
    CuttingBench/BenchGeometry/Tests CuttingBench/CuttingBench` is clean.
- **Do not:** change which meet any pick writes, change any prompt wording, add a marker kind, or touch
  anything else in `BenchWindow.swift`.

**T2 — Pure: the tangent-ratio rescale and its refusals**

- **Files:** `CuttingBench/BenchGeometry/Sources/BenchGeometry/TangentRescale.swift` (new),
  `CuttingBench/BenchGeometry/Sources/BenchGeometry/PatternDraft.swift` (edit — three refusal cases and
  their three sentences),
  `CuttingBench/BenchGeometry/Tests/BenchGeometryTests/TangentRescaleTests.swift` (new)
- **Done when:**
  - Every signature, constant and doc comment in §1 exists as written, and the planner runs its seven steps
    in that order.
  - `.tuningHandleIsTheGirdle`, `.tuningHandleHasNoTangent` and `.tuningTargetOutOfRange` are on
    `DraftRefusal` with §4's three sentences verbatim.
  - **`Easy Octagon`, handle `C1`, target `46`:** `ratio` is `1.150073` ± `1e-6`, `ratioText` is `1.1501`,
    and `rows` is exactly three entries in file order — `C1 42.00 → 46.00`, `C2 29.00 → 32.52`,
    `T 0.00 → 0.00`.
  - **The same rescale applied:** `P1` is still `47.60`, `P2` still `43.00`, `G1` still `90.00`, and every
    meet, every stop list, the gear, the `ri` and the girdle target are unchanged.
  - **The plan view is preserved.** With `before = metrics(try solve(pattern))` and
    `after = metrics(try solve(rescaled))`: `widthNormalised`, `lengthNormalised`, `lengthOverWidth`,
    `girdleThicknessNormalised`, `pavilionDepthFractionOfWidth` and `facetCount` are equal within `1e-9`;
    `tableFractionOfWidth` is equal within `2e-4`; and `after.crownHeightFractionOfWidth` equals
    `before.crownHeightFractionOfWidth * 1.150073` within `2e-4`.
  - **A second case proves the transform itself is exact**, not just close: build the same rescale by hand
    without the 2 dp rounding — `atan(ratio * tan(angle))` per crown tier — and take
    `tableFractionOfWidth` unchanged within `1e-12`. The `2e-4` above is the rounding the format asks for
    and nothing else.
  - **`Rand's Cut Corner Rectangle`, handle `1` (a `pav` tier at 43.00), target `45`:** the rows are its
    three `pav` tiers only, in file order — `1`, `4`, `5` — so the 65° tier `4` is rescaled with the rest of
    its pavilion, and the two `gdl` tiers and every `crown` and `table` tier are absent.
  - **The three handle refusals fire:** handle `G1` on `Easy Octagon` → `.tuningHandleIsTheGirdle`; handle
    `T` (at `0.00`) → `.tuningHandleHasNoTangent`; handle `C1` with target `90` and with target `0` →
    `.tuningTargetOutOfRange` both times. A handle label the draft does not carry returns `.success` with
    no rows.
  - `draggedTuningTarget(from: 42, byPoints: 80)` is `46.00`; `from: 42, byPoints: -840` clamps to `0.10`;
    `from: 42, byPoints: 4000` clamps to `89.90`.
  - `swift test --package-path CuttingBench/BenchGeometry --disable-sandbox` and
    `swift test --package-path Kernel --disable-sandbox` pass.
  - `xcrun swift-format lint --recursive --strict CuttingBench/BenchGeometry/Sources
    CuttingBench/BenchGeometry/Tests CuttingBench/CuttingBench` is clean.
- **Do not:** touch any view, any window state, `DraftEdits.swift` or `MeetPick.swift`; add a
  quarter-turn or derivation refusal case here; write anything to a tier other than its `angle`.

**Commit point, after T2:**

```
5-cutting-bench-angle-tuning T1-T2: the tangent-ratio rescale, pure

- A completed pick now reports the point it landed on, ready for the two-point derivation
- New: a side rescaled by tangent ratio, its three refusals, and the plan-view proof on Easy Octagon
```

**T3 — The Tuning card: the field, the list and the ratio**

The typed half of the rescale, end to end: select a tier, type an angle, see every angle the commit would
rewrite, commit it as one undoable step. No drag and no preview solid yet.

- **Files:** `CuttingBench/CuttingBench/BenchRegions.swift` (edit),
  `CuttingBench/CuttingBench/BenchWindow.swift` (edit)
- **Done when:**
  - `InspectorRegion` carries §7's six new properties and shows `GroupBox("Tuning")` directly after `Notes`
    and before `Metrics`.
  - `TuningCard` exists as §7 describes it: its own buffer, the no-selection sentence verbatim, the
    refusal's own sentence for a handle or target the planner declines, and otherwise the ratio line plus
    one row per proposed angle.
  - Return commits and losing focus reverts the buffer.
  - The window passes `selectedTier`, `tuningTarget: nil`, `tuningDragEnabled: false` and `commitTuning`,
    with `tuningDragChanged` and `tuningDragEnded` as empty bodies this task does not call — T4 fills them
    in. **Say so in a comment naming T4**, so a reader does not take an empty body for an oversight.
  - `commitTuning` is one `edit("Tune Side")` call over `rescaling(handle:toTyped:in:)`, returning whether
    it was accepted.
  - `swift build --package-path CuttingBench/BenchGeometry --disable-sandbox` succeeds and both
    `swiftc -typecheck` runs from **Checks** are clean, `-DDEBUG` and without.
  - `swift test --package-path CuttingBench/BenchGeometry --disable-sandbox` and
    `swift test --package-path Kernel --disable-sandbox` pass.
  - `xcrun swift-format lint --recursive --strict CuttingBench/BenchGeometry/Sources
    CuttingBench/BenchGeometry/Tests CuttingBench/CuttingBench` is clean.
- **Do not:** touch the Angle column in the tier table — the single-tier angle edit stays exactly as it is,
  because it is what authoring uses; add a preview solid; add a drag; reorder the Pattern and Notes cards.

**T4 — Dragging the grip, previewed and self-throttled**

- **Files:** `CuttingBench/CuttingBench/BenchWindow.swift` (edit),
  `CuttingBench/CuttingBench/BenchRegions.swift` (edit)
- **Done when:**
  - `TuningPreview` exists as §8 declares it, and `drawnSolid`, `drawnMesh` and `afterSolidChanged` account
    for it exactly as §8 says.
  - The grip is in the card with its drag gesture, `.disabled(!dragEnabled)`, and the window passes
    `tuningDragEnabled: pick == nil && store.granularity == nil`.
  - `tuningDragChanged`, `tuningDragEnded` and `previewTuning` are written as §8 specifies, including the
    throttle test `ContinuousClock.now - lastFinished < lastSolve` and the measurement around
    `benchSolid(for:)` and `solidMesh(_:)`.
  - **No undo entry is registered by a preview**, and no preview touches `store`.
  - `swift build --package-path CuttingBench/BenchGeometry --disable-sandbox` succeeds and both
    `swiftc -typecheck` runs from **Checks** are clean, `-DDEBUG` and without.
  - `swift test --package-path CuttingBench/BenchGeometry --disable-sandbox` and
    `swift test --package-path Kernel --disable-sandbox` pass.
  - `xcrun swift-format lint --recursive --strict CuttingBench/BenchGeometry/Sources
    CuttingBench/BenchGeometry/Tests CuttingBench/CuttingBench` is clean.
- **Do not:** solve on a background task, add a timer, cache a preview frame past the gesture, or let a
  preview reach `store.setPattern`.
- **Verification handle** — `permanent`:
  - **Where:** open `Design/Patterns/Pattern-Easy-Octagon.json`, select `C1` in the tier table, and read the
    inspector's **Tuning** card together with the **Metrics** card beside it.
  - **Positive:** type `46` in the Tuning field. Before you press Return the card lists exactly
    `C1 42.00 → 46.00`, `C2 29.00 → 32.52`, `T 0.00 → 0.00` and `Ratio 1.1501`. Note the Metrics card's
    `C/W` and `T/W` figures, then press Return: the tier table's Angle column now reads `46.00`, `32.52` and
    `0.00` for those three rows, `C/W` has grown by a factor of 1.1501, and `T/W`, `L/W`, width and girdle
    read exactly what they read before. Now drag the grip right of the field: the stone stretches taller
    under the pointer while the card's numbers keep step, and releasing commits wherever you stopped.
  - **Negative:** the pavilion and girdle rows never move — `P1` stays `47.60`, `P2` stays `43.00`, `G1`
    stays `90.00` — and the stone's outline in a face-up view is unchanged throughout. One ⌘Z puts all
    three crown angles back in a single step. Select `G1` and the card refuses in words instead of listing
    anything, and its grip does nothing.
  - **Reads:** `tangentRescale(handle:toTyped:in:)` and `rescaling(handle:toAngle:in:)` in
    `TangentRescale.swift`, plus `previewTuning()` in `BenchWindow.swift`. Delete any of the three and the
    card, the commit or the live stretch visibly stops working.

**Commit point, after T4:**

```
5-cutting-bench-angle-tuning T3-T4: tuning a side by tangent ratio

- The inspector's Tuning card: type or drag a tier's angle, see every angle it would rewrite
- Dragging previews the whole side live, throttled by what the last preview solve cost
```

**T5 — Pure: the quarter turn**

- **Files:** `CuttingBench/BenchGeometry/Sources/BenchGeometry/QuarterTurn.swift` (new),
  `CuttingBench/BenchGeometry/Sources/BenchGeometry/PatternDraft.swift` (edit — one refusal case and its
  sentence),
  `CuttingBench/BenchGeometry/Tests/BenchGeometryTests/QuarterTurnTests.swift` (new)
- **Done when:**
  - Every signature and doc comment in §2 exists as written, and `.quarterTurnGearNotDivisible` is on
    `DraftRefusal` with §4's sentence verbatim, in both its named-tier and its `nil` form.
  - **`Easy Octagon` turned once** (quarter = 24 stops): `G1`'s stops are `24 36 48 60 72 84 0 12` **in that
    order**; `C2`'s are `42 66 90 18`; `P2`'s meet is `G1@24 · G1@36 · P1@24`; `C2`'s is
    `G1@36 · G1@48 · C1@36`; `T`'s is `C1@24 · C1@36 · C2@42`. `P1`'s `tcp`, `C1`'s `girdle` and `G1`'s
    `size` come back unchanged.
  - Every angle, every `part`, the tier order, the header gear, the `ri` and the girdle target are
    untouched.
  - **The stone is the same stone.** With `before = metrics(try solve(pattern))` and `after` the same over
    the turned pattern, on **both `Easy Octagon` and `Rand's Cut Corner Rectangle`**: `facetCount`,
    `rotationalOrder`, `widthNormalised`, `lengthNormalised`, `lengthOverWidth`,
    `girdleThicknessNormalised`, `girdleFractionOfWidth`, `crownHeightFractionOfWidth`,
    `pavilionDepthFractionOfWidth`, `totalDepthFractionOfWidth` and `tableFractionOfWidth` are all equal
    within `1e-9`. **`mirrorAxes` is excluded and must not be asserted equal**: those are index positions on
    the stone, and turning the stone moves them — that is the operation working, not a fault.
  - **Four turns are the identity:** turning `Easy Octagon` and then `Rand's` four times returns a
    `PatternDraft` equal to the original by `==`.
  - **The refusal fires and changes nothing:** a draft whose header gear is `90` refuses with the `nil`-tier
    form naming `90`; a draft on gear `96` one tier of which declares `90` refuses naming that tier and its
    gear; in both cases the returned failure leaves the draft the caller passed in untouched. **The header
    gear is checked whether or not any tier inherits it**, because a tier added later would.
  - `swift test --package-path CuttingBench/BenchGeometry --disable-sandbox` and
    `swift test --package-path Kernel --disable-sandbox` pass.
  - `xcrun swift-format lint --recursive --strict CuttingBench/BenchGeometry/Sources
    CuttingBench/BenchGeometry/Tests CuttingBench/CuttingBench` is clean.
- **Do not:** sort or normalise a stop list; touch an angle, a `part` or the tier order; rotate by anything
  other than a quarter; add the menu command (that is T6).

**T6 — The Pattern menu's one command**

- **Files:** `CuttingBench/CuttingBench/PatternCommands.swift` (new),
  `CuttingBench/CuttingBench/CuttingBenchApp.swift` (edit — one line in the `.commands` block),
  `CuttingBench/CuttingBench/BenchWindow.swift` (edit — the action and the focused-scene value)
- **Done when:**
  - `PatternCommands.swift` holds §9's focused-value key, its `FocusedValues` extension and the
    `PatternCommands` command struct, with the doc comments §9 gives them.
  - `CuttingBenchApp` includes `PatternCommands()` alongside its existing `CommandGroup(after: .newItem)`.
  - `BenchWindow` has `private func turnAQuarter()` as one `edit("Turn a Quarter Turn")` call over
    `turningAQuarter(_:)`, published with `.focusedSceneValue(\.turnAQuarter, turnAQuarter)`.
  - `swift build --package-path CuttingBench/BenchGeometry --disable-sandbox` succeeds and both
    `swiftc -typecheck` runs from **Checks** are clean, `-DDEBUG` and without.
  - `swift test --package-path CuttingBench/BenchGeometry --disable-sandbox` and
    `swift test --package-path Kernel --disable-sandbox` pass.
  - `xcrun swift-format lint --recursive --strict CuttingBench/BenchGeometry/Sources
    CuttingBench/BenchGeometry/Tests CuttingBench/CuttingBench` is clean.
- **Do not:** add a keyboard shortcut, a confirmation, a half-turn, or a disabled state for a pattern that
  cannot be turned.
- **Verification handle** — `permanent`:
  - **Where:** the **Pattern** menu in the menu bar, with the tier table's Indices and Meet columns and the
    inspector's Metrics card.
  - **Positive:** open `Pattern-Easy-Octagon.json` and choose **Pattern ▸ Turn a Quarter Turn**. `G1`'s
    Indices cell reads `24 36 48 60 72 84 0 12` in exactly that order, `C2`'s reads `42 66 90 18`, and
    `T`'s Meet cell reads `C1@24 · C1@36 · C2@42`. Then open
    `Pattern-Rands-Cut-Corner-Rectangle.json`, look at the stone face up, and turn it: the rectangle is
    visibly a quarter turn round.
  - **Negative:** on both patterns the Metrics card's width, length, `L/W` and girdle rows read exactly what
    they read before the turn — `Rand's` `L/W` is the same number, not its reciprocal — and one ⌘Z puts
    every stop list and every meet back in a single step. Choosing the command twice more and then once
    more returns the file to what it was.
  - **Reads:** `turningAQuarter(_:)` in `QuarterTurn.swift`. Delete it and the command cannot compile, let
    alone move a stop.

**Commit point, after T6:**

```
5-cutting-bench-angle-tuning T5-T6: a pattern turned a quarter turn

- New: every stop and every named index advanced a quarter of its own gear, refused whole on a gear that
  does not divide by 4
- The Pattern menu, with its one command
```

**T7 — Pure: the angle from two points, and its three refusals**

Every case below is arithmetic over points given directly, so none of them needs a solid or a solve.

- **Files:** `CuttingBench/BenchGeometry/Sources/BenchGeometry/AngleFromTwoPoints.swift` (new),
  `CuttingBench/BenchGeometry/Sources/BenchGeometry/PatternDraft.swift` (edit — three refusal cases and
  their sentences),
  `CuttingBench/BenchGeometry/Sources/BenchGeometry/MeetPick.swift` (edit — the `stageSentence` extraction
  and `angleDerivationPrompt`),
  `CuttingBench/BenchGeometry/Tests/BenchGeometryTests/AngleFromTwoPointsTests.swift` (new)
- **Done when:**
  - Every signature and doc comment in §3 exists as written, `DerivationNumbers` with it, and
    `derivedAngle` runs its eight steps in that order.
  - `.derivationPointsCoincide`, `.derivedAngleContradictsPart` and `.siblingFacetTakesTheDepth` are on
    `DraftRefusal` with §4's three sentences verbatim.
  - `meetPickPrompt`'s wording is byte-identical to what it produced before the extraction, proven by its
    existing tests passing unaltered, and `angleDerivationPrompt(tier: "C2", aimedStop: 18, pointsTaken: 0,
    stage: .empty, solid:)` reads `Deriving C2@18's angle · point 1 of 2 · click a facet, or an edge`.
  - `azimuthRadius(of: SIMD3(0, 1, 0), atStop: 24, wheel: 96)` is `1` within `1e-12`, and at stop `0` it is
    `0`.
  - **A crown tier**, gear 96, stops `[0]`, aimed `0`, points `(1, 0, 0)` and `(0.5, 0, 0.5)` → `45.00`.
    **The same points for a `pav` tier** → the contradiction refusal reporting `-45.00`. **A `pav` tier**
    with `(1, 0, 0)` and `(0.5, 0, -0.5)` → `45.00`.
  - **A table tier**, aimed `0`, points `(0.8, 0, 0.5)` and `(-0.3, 0.4, 0.5)` → `0.00`, **not** a
    contradiction refusal: zero is the answer for two points at one height.
  - **Same radius, different height** — a crown tier, points `(0.7, 0, 0)` and `(0.7, 0, 0.5)` → `90.00`,
    with no refusal.
  - **Coincident** — a crown tier, points `(0.7, 0.3, 0.4)` and `(0.7, -0.3, 0.4)` → the coincident refusal
    whose `DerivationNumbers` carry `r1 == r2 == 0.7` and `z1 == z2 == 0.4`.
  - **A sibling takes the depth** — a crown tier, gear 96, stops `[0, 12]`, aimed `0`, first end a `vertex`
    at `(0.70710678, 0.70710678, 0)` and second a `vertex` at `(0.35355339, 0.35355339, 0.5)` → the sibling
    refusal naming `aimed: 0`, `arrives: 12`, `angle: 54.74`, with `arrivingDot` strictly greater than
    `aimedDot` and the two around `0.8165` and `0.5775` within `2e-3`.
  - **A tie passes.** The same tier and stops `[0, 12]`, aimed `0`, with both points on the bisector between
    those two facets — azimuth 22.5° — at `(0.92387953, 0.38268343, 0)` and
    `(0.46193977, 0.19134172, 0.5)`. Both facets project that anchor point to the same radius, so their dot
    products are equal and no sibling refusal fires: the result is a `.success` whose angle is between
    `47.2` and `47.3`.
  - `isCornerEnd` is `true` for `.vertex` and `.tcp`, `false` for `.fraction`, `.size` and `.girdle`.
    `anchorEnd` is `0` for vertex-then-fraction, `1` for fraction-then-vertex, `0` for two vertices, `0` for
    `tcp`-then-fraction and `0` for two fractions.
  - `swift test --package-path CuttingBench/BenchGeometry --disable-sandbox` and
    `swift test --package-path Kernel --disable-sandbox` pass.
  - `xcrun swift-format lint --recursive --strict CuttingBench/BenchGeometry/Sources
    CuttingBench/BenchGeometry/Tests CuttingBench/CuttingBench` is clean.
- **Do not:** change the wording of any existing prompt; guard the zero denominator into a refusal; record
  the second point anywhere in the returned value; touch the solver or the kernel; collapse two of the
  three refusals into one case.

**T8 — Deriving an angle in the viewport**

- **Files:** `CuttingBench/CuttingBench/BenchWindow.swift` (edit),
  `CuttingBench/CuttingBench/BenchRegions.swift` (edit)
- **Done when:**
  - `AngleDerivation` exists as §8 declares it; `startDerivation(_:aimedStop:)` mirrors `startPick` and
    registers no undo entry; `drawnSolid`, `drawnMesh`, `ghostMesh`, `ghostGeneration`, the pick markers,
    the prompt, Cancel and `afterSolidChanged` all account for it exactly as §8 says.
  - `pick(at:in:)` has the derivation branch before the meet-pick branch, with the two-completion behaviour
    §8 specifies: the first end stored and the stage reset, the second end deriving and writing through one
    `edit("Derive Angle")` call over `setting(derived:ofTier:in:)`, a refusal presented while the first end
    is kept, and a `.cleared` ending the session.
  - `TierTableRegion` carries `startDerivation` and the meet menu has the submenu §7 specifies, keyed by
    position and labelled `aim <tier>@<stop>`.
  - `swift build --package-path CuttingBench/BenchGeometry --disable-sandbox` succeeds and both
    `swiftc -typecheck` runs from **Checks** are clean, `-DDEBUG` and without.
  - `swift test --package-path CuttingBench/BenchGeometry --disable-sandbox` and
    `swift test --package-path Kernel --disable-sandbox` pass.
  - `xcrun swift-format lint --recursive --strict CuttingBench/BenchGeometry/Sources
    CuttingBench/BenchGeometry/Tests CuttingBench/CuttingBench` is clean.
- **Do not:** let a pick and a derivation run at once; add an overlay marker for the point already taken;
  write the second point anywhere; keep a derivation alive across a rebuild.
- **Verification handle** — `permanent`:
  - **Where:** `Pattern-Easy-Octagon.json`. On the tier `T`'s Meet cell, the menu now offers
    **Derive angle from two points… ▸ aim T@0**. The status strip under the window carries the prompt, and
    `T`'s Angle and Meet cells are what change.
  - **Positive:** choose **aim T@0**. The strip reads `Deriving T@0's angle · point 1 of 2 · click a facet,
    or an edge`. Click the facets `C1@24`, then `C1@36`, then `C2@42` — the corner where those three meet.
    The strip moves to `point 2 of 2`. Now click `C1@0`, `C1@12`, `C2@18`, which is the corner `T`'s meet
    already names. `T`'s Angle cell still reads `0.00` — both corners sit at one height, so a flat table is
    the answer — and `T`'s Meet cell now reads `C1@24 · C1@36 · C2@42`, the corner picked **first**. The
    stone does not move, which is the point: that is a second correct name for the same plane. One ⌘Z puts
    the authored meet back.
  - **Negative:** start it again and click the **same** corner for both points — `C1@0`, `C1@12`, `C2@18`,
    then `C1@0`, `C1@12`, `C2@18` again. An alert says both points sit at the same place on that facet's
    azimuth and gives the two identical figures; `T`'s Angle still reads `0.00` and its Meet cell still reads
    whatever it read before you started. Nothing is written and no undo step is added.
  - **Reads:** `derivedAngle(ofTier:aimedStop:wheel:part:stops:first:second:)` in `AngleFromTwoPoints.swift`
    and `setting(derived:ofTier:in:)` in `DraftEdits.swift`. Delete either and the second click cannot write
    an angle at all.

**Commit point, after T8:**

```
5-cutting-bench-angle-tuning T7-T8: a tier's angle from two picked points

- New: the closed-form angle from an aimed facet and two points, with a named diagnostic for each of the
  three ways it cannot work
- Aim a tier at one of its stops, click twice, and the angle and the vertex meet are written together
```

**T9 — Close out**

- **No temporary handles to delete.** All three handles are `permanent`: the Tuning card, the Pattern menu's
  command and the derivation submenu are the feature itself, not scaffolding.
- Confirm each item in this plan's **Deferred** section has a ticket in `Design/Tickets/` with
  `Status: untriaged`. The executor filed each one as it found it, per the protocol; this is the check, not
  the filing.
- Report the untriaged ticket count in `Design/Tickets/` as one line.
- `commit + push` with the message below.
- **Archive per `Design/Execution-Protocol.md` §11:** this plan
  `5-Cutting-Bench-Angle-Tuning-Rescale-Rotate-And-Derive`, and the exploration
  `5-Cutting-Bench-Angle-Tuning`. **No tickets** — this plan closes none.
- The exploration carries two claims the code contradicts, both named in this plan's Context: the 10%
  end-snap zones, which are 20%, and every permitted gear dividing by 4, which the kernel does not enforce.
  §11's banner question therefore answers **yes** for the exploration: banner it with those two claims and
  catalogue it as `superseded by` this plan. The plan itself contradicts nothing and takes a plain
  `executed` line.

```
5-cutting-bench-angle-tuning T9: close out the angle-tuning set

- Archive the plan and its exploration, the exploration bannered where it disagrees with the code
```

## Deferred

Empty at authoring. The executor appends adjacent problems it found and must not fix — and files each as a
ticket in `Design/Tickets/` immediately with `Status: untriaged`, per the protocol.
