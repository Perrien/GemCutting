# 3 · Cutting Bench Pattern Display — Part 5: Light

Status: **DRAFT** — not yet approved.

## Parts

**For the owner and the next authoring session — not for the executor.** Nothing in this part's tasks
refers to another part.

1. `3-Cutting-Bench-Pattern-Display-1-Solid-And-Tier-Table` — the display solid tells the truth: the
   rough is scaffolding, dropped the moment the pattern's own planes close, and a solve that stops
   part-way names the tier that stopped it. The tier table is filled in, every column, including the
   effective wheel and each tier's instructions. (shipped)
2. `3-Cutting-Bench-Pattern-Display-2-Metrics-And-Facet-Count` — the Metrics card: facet count,
   symmetry and `L/W` always visible over the full proportion table; the declared-facet-count session
   field and its `64 + 16 girdle = 80` split reporting. (shipped)
3. `3-Cutting-Bench-Pattern-Display-3-Findings-And-Meet-Points` — structural findings at once,
   geometric ones deferred off the main thread and marked stale in flight; the status-strip line opens
   to detail, marks the offending tier row and highlights its geometry. Every named meet point becomes
   a lettered, coloured dot in both the viewport and the meet cell. (shipped)
4. `3-Cutting-Bench-Pattern-Display-4-Playback` — the scrubber at tier and facet granularity, prefix
   intersection, one honest wait on entering playback with progress shown, and the intermediate-solid
   display mode. Retires the debug tier-limit stepper. (shipped)
5. `3-Cutting-Bench-Pattern-Display-5-Light` — the critical-angle marking on pavilion tier rows, and
   the clickable single-ray probe with its per-bounce incidence readout, offered only when the
   pattern's own solid closes. Closes the exploration out and runs the archive routine. ← this part

| Exploration ID | Part |
|---|---|
| S1 | 1, 2, 4, 5 — the slice's scope statement rather than a unit of work; its done-conditions land per part. This part settles the last of them, "a ray probe traces and reports." |
| S2 | 5 |
| I1 | 1 — its rule that the kernel's own rough-free solid is what `metrics` and `validate` see is `ADR-0004`, and it binds this part's probe: restated as D9 |
| I2 | 1 |
| I3 | 4 |
| I4 | 5 |
| I5 | 2 |
| U1 | 3 |
| U2 | 2 — its clause that the critical-angle marking goes on the tier rows and the probe's incidence readout with the probe is what D4 and D18 satisfy here |
| U3 | 1 |
| U4 | 3 |
| U5 | 4 |
| U6 | 4 |

**No boundary has moved.** The split is the one the owner approved on 2026-08-25, and parts 1 to 4
shipped against it. The exploration's non-goals bind this part unchanged — in particular **nothing here
edits or saves anything**, and nothing here renders light beyond one traced path.

**Two notes on the state of the set, neither of which this part depends on.** Part 4 was amended after
completion, owner-directed, so that changing playback granularity carries the position into the new list
instead of returning the stone to its finished self; that amendment is recorded in part 4's own file and
nothing in this part reads playback position. Part 4's task table still shows its close-out row as
`awaiting owner` while its `Status:` line says the part completed — the `Status:` line and the commit
`562d612` are the authority, and the stale row is cosmetic.

## Context

**Every authored pattern declares a refractive index, and today it does nothing anywhere in this tool.**
All four carry `ri` 1.54. An author tuning a pavilion angle is doing in their head the one calculation
the app holds every input for — and getting it wrong is exactly what a pavilion rescale does first.

Two readouts close that, and both are arithmetic rather than rendering, so the slice's no-render non-goal
does not bar them:

- **A critical-angle check on every pavilion tier.** `asin(1 / ri)` against each pavilion tier's authored
  angle, marking any tier shallow enough to leak. **Honest about its limit: it says when light definitely
  leaks, never that a stone performs well.**
- **A clickable single-ray probe.** Click the crown or the table and one ray is traced in, reflected off
  the pavilion — ideally twice — and out again, with the incidence at every bounce reported. Sampling a
  few points per facet type is how windowing is found and then tuned out.

### What already exists

This is a small change to known code. Every anchor below was read on 2026-08-25.

- **The whole optical kernel is already written and tested.** `Kernel/Sources/FacetKernel/Ray.swift:70`
  (`public func criticalAngleDegrees(ri: Double) -> Double`) and `:89`
  (`public func traceRay(in planes: [Plane], ri: Double, from entry:, direction:, bounceLimit: Int = 32)`)
  ship with `RayTrace`, `RaySegment` and `RayEnding`, including Snell's law both ways, the
  nearest-forward-hit rule and the bounce cap. **This part writes no optics.** It converts what the
  kernel returns into strings and screen positions.
- **The click already becomes a world ray and a named facet.** `BenchWindow.swift:169`
  (`private func pick(at point: CGPoint, in size: CGSize)`) unprojects with `BenchCamera.swift:186`
  (`public func benchRay(`) and puts it to `BenchPick.swift:9` (`public func pickFacet(`). The pick
  returns the plane index and the facet's origin — **but not the point it hit**, which is the one thing
  the probe needs and the only reason this part carries a prefactor.
- **Closure is already a flag on the drawn solid.** `BenchSolid.swift:138`
  (`let isOpen = solidFindings(solution, declaredFacetCount: nil).contains { finding in`) asks the
  kernel's own closure check once, and `BenchSolid.swift:163` (`includesRough: isOpen`) records the
  answer. The probe's precondition is therefore free, and needs no second closure test.
- **When the pattern closes, the drawn solid *is* the pattern's own solid.** `BenchSolid.swift:144`
  (`let base = isOpen ? roughPlaneCount : 0`) — with the scaffolding gone, `solid.planes` is
  `solution.planes` in its own order and `solid.origin` is keyed from `0`. `BenchSolidTests.swift:69`
  (`XCTAssertTrue(bench.roughFacetIndices.isEmpty, name)`) runs that over all four authored patterns, so
  all four are traceable.
- **A SwiftUI overlay over the Metal view, projecting world points with the renderer's own matrices, is
  an established pattern with two instances.** `MeetPointOverlay.swift:39`
  (`let point = benchScreenPoint(world, aspect: aspect, camera: camera)`) and `IndexRingOverlay.swift`,
  both composed at `BenchRegions.swift:32`–`:35`. The probe's path is a third one. **The renderer is not
  touched.**
- **The inspector already has an empty card waiting.** `BenchRegions.swift:231`
  (`GroupBox("Light") { EmptyCard() }`), placed by the app shell for exactly this.
- **A card whose input is free text the readout parses is an established pattern.**
  `BenchRegions.swift:303` (`TextField("Declared", text: $declaredFacets)`) over
  `MetricsReadout.swift:135` (`public func facetCountCheck(`), so a half-typed number says it is not a
  number rather than silently becoming one.
- **The angle a tier declares is measured from the axis.** `Plane.swift:40`–`:49`
  (`let theta = 2 * Double.pi * Double(index) / Double(wheel)` … `zsign * cos(a)`) — `0°` is the
  table direction and `90°` the girdle, so a facet's outward normal sits at exactly the tier's angle from
  the axis. That is why a vertical ray's incidence on a pavilion facet **is** that tier's angle, and why
  the check needs no geometry at all.

### What does not exist, and is the honest cost

**No authored pattern leaks.** All four declare `ri` 1.54, whose critical angle is `40.49°`, and the
shallowest pavilion tier in the corpus is `Rand's` tier `5` at `41.20°`. So the marking has a negative
half on real data and no positive half, and the four fixtures may never be edited to produce one — they
are external ground truth under the protocol's guardrails. This part therefore ships **one temporary
`#if DEBUG` control**, a refractive-index override, purely so the leaking state can be reached and
looked at. It is deleted by the close-out task.

## Decisions (2026-08-25)

| # | Decision |
|---|---|
| D1 | **The check is `angle <= criticalAngleDegrees(ri:)` on tiers whose `part` is `.pav`, and on nothing else.** It calls the kernel's function (`Ray.swift:70`) and never recomputes `asin(1 / ri)`, because a second implementation can agree with a broken one. Girdle, crown and table tiers are never marked: the check asks whether a vertical ray reflects off the pavilion, and the pavilion is the only place that ray lands. |
| D2 | **`<=`, not `<`.** `Ray.swift:142` (`if incidence <= critical`) lets the ray out at exactly the critical angle, so a tier sitting exactly there must mark — otherwise the table and a traced path would disagree on the one case that is hardest to explain. |
| D3 | **The comparison is exact for the case it claims, and the card says so in one line, verbatim: `A marked tier leaks a vertical ray. Nothing here says a stone performs well.`** A ray entering through a `0.00°` table is undeviated, so its incidence on a pavilion facet is exactly that tier's authored angle. The sentence is a constant in the pure module, not a string in the view, so no later edit can soften it. |
| D4 | **A leaking tier is not a finding, and never enters the findings count.** Findings are faults; a shallow pavilion may be what the author chose, and a finding must never blame a tier that is complete and correct. `FindingsReadout` is not touched, and the mark is a separate cell decoration. |
| D5 | **The critical-angle readout needs no solve, so it shows whenever a pattern is open** — including a part-cut stone, where the Metrics card can only show a reason. It is arithmetic over the authored angles and the authored `ri`. The probe, which does need a solid, carries its own precondition inside the same card. |
| D6 | **The mark goes in the Angle column, in orange, as the SF Symbol `sun.max` plus the shortfall in degrees.** The Angle column because the mark is a statement about that angle; the Tier column already carries the stopped-solve triangle and the findings circle, and a third mark there would blur all three. **Orange and not red**, because red is the findings colour and this is not a fault. Never colour alone — the symbol and the number each carry it. `sun.max` because it has shipped since the first SF Symbols release. |
| D7 | **One effective refractive index, computed in one function, read by both the card and the probe.** `effectiveRefractiveIndex(pattern:override:)`. Two readouts deriving it separately could disagree about which stone the owner is looking at. |
| D8 | **The override is `#if DEBUG`, free text, session state, and temporary.** Free text parsed by the readout, exactly as the Declared field is (`BenchRegions.swift:303`), so a half-typed `1.` says it is not a refractive index rather than becoming a number the owner did not mean. Empty means the pattern's own `ri`. **Never written to the document** — editing the header is `4-Cutting-Bench-Authoring`'s work. It exists because no authored pattern leaks and the fixtures may not be edited, and it is deleted at close-out. |
| D9 | **The probe traces `solid.planes`, and is offered exactly when `solid.includesRough == false`.** With the scaffolding gone the drawn solid *is* the pattern's own rough-free solid (`BenchSolid.swift:144`, `ADR-0004`), so passing the drawn planes makes "trace the pattern's own solid, never the rough-capped one" true by construction rather than by argument — and makes every `RaySegment.plane` a valid key into `solid.origin` for its facet name. The precondition is what keeps that true. Tracing a rough-capped solid would report on a stone that does not exist while looking authoritative. |
| D10 | **When the probe is unavailable the card states why, rather than showing an inert control.** Two sentences: `No pattern open.` for no pattern, and `The probe needs a closed stone: the pattern's own planes do not bound one yet.` for an open solid. |
| D11 | **Entry is the clicked point, and the direction is exactly `(0, 0, -1)`.** Vertical and downward is how windowing is judged — looking straight down at a face-up stone. The clicked point rather than a point derived from above the stone, so the owner controls exactly where the ray goes in. |
| D12 | **The picked point is snapped onto its own plane before it is traced: `p - (n · p - d) n`, with `n` the unit outward normal.** The click ray is unprojected in `Float` and `traceRay`'s entry test is `abs(n · p - d) <= 1e-7` in `Double` (`Ray.swift:101` with `Ray.swift:267`), so an unsnapped point can land outside that tolerance and the probe would answer "no entry" for a facet the owner plainly clicked. |
| D13 | **A click that the vertical ray cannot enter through gets a sentence, not a trace, and the kernel decides which.** A pavilion facet faces down, a girdle facet is parallel to the ray, a rough wall is neither — and `traceRay` already answers `.noEntry` for all three. The app tests no `part` of its own; it translates the kernel's answer into `A vertical ray does not enter through this facet.` |
| D14 | **`bounceLimit: 8`, not the kernel's default of 32.** A path with more than eight legs is not a picture anyone reads, and `RayEnding.cappedAtBounceLimit` already says the path was truncated rather than finished, so the card can say so honestly. |
| D15 | **The probe is a mode, off by default, and it does not replace the facet pick.** A click always picks its facet exactly as it does today; with the mode on, the same click *additionally* traces. The mode is what gives the path a way to be off; leaving the pick alone means one gesture keeps doing the thing it already did. |
| D16 | **The path is SwiftUI over Metal — a third overlay on `ViewportRegion`, using `benchScreenPoint` and the same camera the renderer has.** A segment then cannot disagree with the solid about where it runs, and the renderer is not touched. **No occlusion test**, for the same reason the meet dots have none (`MeetPointOverlay.swift:21`): the path runs inside the stone by definition, and the opacity slider is how the owner looks in. |
| D17 | **Solid green inside the stone; green dashed for a `0.5`-unit stub above the entry point; a `0.5`-unit stub past the exit when the ray left — red dashed when it left through a downward-facing facet, green dashed when it returned through the crown or the table.** Amended owner-directed on 2026-08-25: as first written this was red for any exit, but on all four authored patterns at their own `ri` the ray goes in through the table, twice off the pavilion above the critical angle, and back out the table — light return, which is the stone working. One colour for that and for a ray lost out of the back would paint every correct stone as a leak. Green and red are free: the renderer uses the accent colour and orange, the meet dots teal, purple and yellow. `0.5` world units against a stone whose girdle radius is about `1`, so a stub reads as a direction without dominating the picture. |
| D18 | **Every leg carries its own label in both places — `E` at the entry point, `1`, `2`, … at each surface — as a chip in the viewport and the same label in the card's list.** The same table-and-viewport pairing the meet dots and the findings marking use, and it is what keeps an incidence figure attached to the right leg of the path. |
| D19 | **The probe result is cleared whenever the solid changes** — a new document, a scrub, a granularity change. A path is a claim about one solid, and kept across a rebuild it would draw through a stone that is no longer there. It is cleared in `afterSolidChanged()` (`BenchWindow.swift:152`), beside the facet selection, which goes for the same reason. |
| D20 | **New comments state their reason in words, or cite `ADR-0004`. No new `Dn` citation goes into any source or test file.** A plan's decision numbers are local to it and the plan is archived at close-out, so a `D9` in a source file points at a document that will be gone and have a namesake. The existing files that already do this are a live ticket and are not this plan's business. |

## Tickets closed by this plan

None — the exploration folded none in. `Chore-Incremental-Half-Space-Clipper`,
`Chore-Validation-Rebuilds-The-Solid-Once-Per-Tier` and `Chore-Decision-Numbers-Cited-In-Code` all stay
open: the first is what the deferred facet-arrival animation waits on, the second is answered by
`4-Cutting-Bench-Authoring`, and the third is about files this plan does not touch.

**This is the last part, so the close-out task archives the whole set** — this plan, parts 1 to 4 by name,
and the exploration.

## Prefactoring

**One task, T1.** `pickFacet` computes where the click ray enters the solid and then throws the point away,
returning only the plane index and the facet name. The probe needs that point, and recomputing it in a
second place would be a second slab test that could disagree with the first about which facet was hit. So
the point comes back with the hit, snapped onto its plane (D12), **before** anything uses it.

Behaviour-preserving, and its check is inverted: **every existing test in `BenchPickTests.swift` passes
unchanged**, because both existing return members keep their names and meanings. The coverage is already
there — `BenchPickTests.swift:81` (`func testEveryHitNamesAPlaneThatIsActuallyAFacet`) sweeps a grid of
directions over both the bare prism and a solved stone — so no characterization test is needed first.

## Approach

Two pure modules in `BenchGeometry` turn the kernel's optics into strings and world points; three view
files show them. **Nothing here computes an angle of refraction, a critical angle or a closure test** —
each of those already exists in exactly one place and is called.

Dependency order: the pick's point (§1), the critical-angle readout (§2), the probe trace (§3), then the
card (§4), the tier table (§5), the overlay (§6) and the window that wires them (§7).

### 1. `CuttingBench/BenchGeometry/Sources/BenchGeometry/BenchPick.swift`

`pickFacet` gains a third return member and nothing else changes. Its whole doc comment stays, with one
sentence added about the snap.

```swift
public func pickFacet(
  _ solid: BenchSolid,
  origin: SIMD3<Float>,
  direction: SIMD3<Float>,
  parallelBelow: Double = 1e-9
) -> (planeIndex: Int, facet: FacetOrigin, point: (x: Double, y: Double, z: Double))?
```

The body already has everything it needs. At `:46` (`guard let entryPlane, entry <= exit, entry > 0 else`)
the entry distance and its plane are both in hand, so after the two guards at `:49`
(`guard solid.polytope.facets[entryPlane] != nil, let facet = solid.origin[entryPlane] else`), build the
point from the `Double` copies `o` and `dir` that `:15`–`:16` already made:

```swift
let hit = (x: o.x + dir.x * entry, y: o.y + dir.y * entry, z: o.z + dir.z * entry)
return (entryPlane, facet, onPlane(hit, solid.planes[entryPlane]))
```

and a new file-private helper:

```swift
/// A point pulled exactly onto its plane. The click ray is unprojected in `Float` and a ray trace tests
/// whether its entry point is on a face to within `1e-7` in `Double`, so the conversion's own error is
/// enough to make a plainly-clicked facet answer "no entry". `n` is a unit normal, so the signed distance
/// is `n · p - d` and subtracting it along `n` lands on the plane.
private func onPlane(
  _ point: (x: Double, y: Double, z: Double), _ plane: Plane
) -> (x: Double, y: Double, z: Double) {
  let signed = dot(plane.n, point) - plane.d
  return (
    x: point.x - signed * plane.n.x,
    y: point.y - signed * plane.n.y,
    z: point.z - signed * plane.n.z
  )
}
```

`dot` is the file's own private helper at `:66`. **Do not touch `facetLabel`** at `:57`.

### 2. New: `CuttingBench/BenchGeometry/Sources/BenchGeometry/LightReadout.swift` (pure — no SwiftUI)

The Light card's contents, every value already a string, in the shape `MetricsReadout.swift` uses so the
two cards are read and tested the same way.

```swift
/// One pavilion tier's angle against the critical angle.
public struct PavilionAngleRow: Identifiable, Equatable, Sendable {
  public var tier: String
  /// `47.60°`.
  public var angle: String
  /// `7.11° clear`, or `5.28° shallow` when it leaks.
  public var margin: String
  public var leaks: Bool
  /// The tier's own label, unique across a pattern by decoding, so a `ForEach` keeps identity.
  public var id: String { tier }
  public init(tier: String, angle: String, margin: String, leaks: Bool)
}

/// Whether a ray can be traced, or the sentence saying why not.
public enum ProbeAvailability: Equatable, Sendable {
  case available
  case unavailable(String)
}

/// The Light card's contents.
public struct LightSummary: Equatable, Sendable {
  /// `40.49°`.
  public var criticalAngle: String
  /// `1.54`, or `1.30 (override)` while the debug field holds a number.
  public var refractiveIndex: String
  /// Every tier whose `part` is `.pav`, in file order — never sorted by angle, because tier order is data.
  public var pavilionTiers: [PavilionAngleRow]
  /// The labels of the tiers that leak, for the tier table's Angle column. A set, because the table looks
  /// each row up rather than walking the list.
  public var leakingTiers: Set<String>
  public var probe: ProbeAvailability
  public init(
    criticalAngle: String, refractiveIndex: String, pavilionTiers: [PavilionAngleRow],
    leakingTiers: Set<String>, probe: ProbeAvailability)
}

public enum LightReadout: Equatable, Sendable {
  case unavailable(String)
  case measured(LightSummary)
}

/// The limit of the check, in one place so no view can soften it. A shallow pavilion definitely leaks; a
/// pavilion that clears the critical angle has been told nothing about how it performs.
public let lightCaveat = "A marked tier leaks a vertical ray. Nothing here says a stone performs well."

/// The refractive index both readouts use: the debug override's number when it parses, the pattern's own
/// otherwise, `nil` with no pattern. **One function, because a card and a traced ray disagreeing about
/// which stone is on screen is worse than either being wrong.**
public func effectiveRefractiveIndex(pattern: Pattern?, override: String) -> Double?

/// The card's contents. **No solve is needed and none is done**: this is arithmetic over the authored
/// angles and the authored refractive index, which is why it reports for a part-cut stone where the
/// Metrics card can only give a reason.
public func lightReadout(
  pattern: Pattern?, solid: BenchSolid, riOverride: String
) -> LightReadout
```

Rules the bodies enforce:

- `effectiveRefractiveIndex` trims whitespace, then `Double(trimmed)`; a value that is not a number, or is
  `<= 0`, falls back to `pattern.ri`. **An empty field is the normal case, not an error.**
- `lightReadout` returns `.unavailable(noPatternOpen)` only when `pattern` is `nil`. Change
  `MetricsReadout.swift:60` (`private let noPatternOpen = "No pattern open."`) from `private` to internal
  — one word — so both readouts say the identical sentence, which is what its own doc comment already
  asks for.
- `criticalAngle` and every `angle` are `String(format: "%.2f°", …)`. `margin` is
  `String(format: "%.2f° clear", angle - critical)` when it clears and
  `String(format: "%.2f° shallow", critical - angle)` when it does not, so neither ever carries a minus
  sign.
- `refractiveIndex` is `String(format: "%.2f", ri)`, with ` (override)` appended when the field's number
  is what was used.
- `leaks` is `spec.angle <= critical` (D1, D2). `pavilionTiers` is `pattern.tiers.filter { $0.part == .pav }`
  in file order. `leakingTiers` is built from the same pass, so the set and the rows can never disagree.
- `probe` is `.available` when `solid.includesRough == false`, and otherwise
  `.unavailable("The probe needs a closed stone: the pattern's own planes do not bound one yet.")`.

### 3. New: `CuttingBench/BenchGeometry/Sources/BenchGeometry/ProbeReadout.swift` (pure — no SwiftUI)

One traced ray, turned into labelled legs the card lists and the overlay draws.

```swift
/// One leg of a traced path: where it ends, the facet it ended on, and how steeply it arrived.
public struct ProbeLeg: Identifiable, Equatable, Sendable {
  /// `E` for the entry, then `1`, `2`, … one per surface the ray reached. The viewport draws this chip and
  /// the card lists the same label, so an incidence figure stays attached to the right leg.
  public var label: String
  /// The facet's own name, from the drawn solid's origin map — `pb`, `t · 24`, never invented here.
  public var facet: String
  /// `45.00°`. The entry leg's is the incidence *before* refraction.
  public var incidence: String
  public var world: SIMD3<Float>
  public var id: String { label }
  public init(label: String, facet: String, incidence: String, world: SIMD3<Float>)
}

/// One probe: its path, how it finished, and the two stubs that show where the ray came from and went.
public struct ProbeReadout: Equatable, Sendable {
  /// The entry leg first, then one per surface. Empty when the ray never entered.
  public var legs: [ProbeLeg]
  /// A whole sentence, ready to show.
  public var ending: String
  /// Whether the ray left the stone. Drives the exit stub's colour and nothing else.
  public var leaked: Bool
  /// `0.5` world units straight up from the entry point. `nil` when there was no entry.
  public var entryStub: SIMD3<Float>?
  /// `0.5` world units along the exit direction from the last leg. `nil` unless the ray left.
  public var exitStub: SIMD3<Float>?
  public init(
    legs: [ProbeLeg], ending: String, leaked: Bool,
    entryStub: SIMD3<Float>?, exitStub: SIMD3<Float>?)
}

/// Traces one ray straight down into the stone from a point on its surface.
///
/// **Traces the drawn solid's own planes, and only when the scaffolding has come away.** With the rough
/// gone the drawn solid *is* the pattern's own rough-free solid (`ADR-0004`), so this cannot report on a
/// rough-capped stone that does not exist — and every plane index the trace hands back is a valid key
/// into the solid's origin map, which is what lets a bounce carry a facet name.
///
/// `point` must already lie on the solid: `pickFacet` snaps it onto its plane, and a point a hair off is
/// enough to answer "no entry".
public func probeTrace(
  _ solid: BenchSolid,
  ri: Double,
  from point: (x: Double, y: Double, z: Double)
) -> ProbeReadout
```

The body, in order:

1. **Guard the scaffolding.** `guard !solid.includesRough else { return … }` with `legs` empty, no stubs,
   and `ending` the same sentence `lightReadout` gives for an open solid. Belt and braces: the toggle is
   already unavailable there, so a wiring mistake is what this catches rather than a normal state.
2. `let trace = traceRay(in: solid.planes, ri: ri, from: point, direction: (x: 0, y: 0, z: -1), bounceLimit: 8)`
   — the direction and the limit are D11 and D14, written as literals here and nowhere else.
3. **The entry leg**, when `trace.entryPlane` and `trace.entryIncidenceDegrees` are both there: label `E`,
   facet from `solid.origin[plane]` through `facetLabel`, `world` the entry point.
4. **One leg per `trace.segments` element**, labelled `1` upward, facet from `solid.origin[segment.plane]`,
   incidence `segment.incidenceDegrees`, `world` `segment.to`.
5. **A facet with no entry in the origin map reads `—`**, never a made-up name. Impossible today; a
   missing entry is something a test can see.
6. `entryStub` is the entry point plus `(0, 0, +0.5)`. `exitStub` is the last segment's `to` plus `0.5`
   times the **normalised** `trace.exitDirection` — normalised because Snell's law on the way out returns a
   unit vector only for a unit input, and a stub of the wrong length is a wrong picture.
7. **The four endings, one sentence each:**
   - `.left` — `String(format: "Left through %@ at %.2f° — at or below the critical angle %.2f°.", facet, incidence, trace.criticalAngleDegrees)`, using the last leg's facet and incidence. `leaked = true`.
   - `.cappedAtBounceLimit` — `"Still bouncing after 8 reflections — the path is truncated, not finished."`
   - `.noEntry` with no segments — `"A vertical ray does not enter through this facet."` (D13.)
   - `.noEntry` with segments — `"The trace found no next surface after \(n) legs, which a convex solid should not allow."`

Nothing else is derived. `leaked` is whether the ray left **through a downward-facing facet** — the exit
facet's own outward normal has a negative `z` for every pavilion and girdle facet, so it needs no tier and
tests no `part`. Not simply `trace.ending == .left`: a ray returning through the table has left too, and
that is the stone working rather than the window the probe exists to find. `exitStub` is set for either
exit; `leaked` is what says which of the two it is.

### 4. `CuttingBench/CuttingBench/BenchRegions.swift`

Three edits. **The card order does not change** and `EmptyCard` stays for the two cards still empty.

**§4a — `InspectorRegion` takes three more values** and fills the Light card. At `:214`
(`struct InspectorRegion: View {`) add, after `declaredFacets`:

```swift
  /// The debug refractive-index override as typed. Session state only, `#if DEBUG` in the card, and never
  /// read from or written to the document — a pattern's `ri` is authored, and editing it is another slice.
  @Binding var riOverride: String
  /// Whether a viewport click also traces a ray. Off by default: the path is a mode, not a side effect of
  /// picking a facet.
  @Binding var probeOn: Bool
  /// The last traced path, or `nil` for none. Cleared whenever the solid changes.
  let probe: ProbeReadout?
```

At `:231` (`GroupBox("Light") { EmptyCard() }`) replace `EmptyCard()` with:

```swift
LightCard(
  readout: lightReadout(pattern: pattern, solid: solid, riOverride: riOverride),
  riOverride: $riOverride,
  probeOn: $probeOn,
  probe: probe)
```

**§4b — a new `private struct LightCard: View`**, placed directly after `MetricsCard` at `:275`, built from
`LabeledContent` rows and `.monospacedDigit()` exactly as `MetricsCard` is. Its layout, top to bottom:

- `.unavailable(let reason)` — the reason at `.callout`/`.secondary`, and nothing else. Same shape as
  `MetricsCard`'s unavailable branch.
- `.measured(let summary)`:
  - `LabeledContent("Critical angle", value: summary.criticalAngle)`
  - `LabeledContent("Refractive index", value: summary.refractiveIndex)`
  - `#if DEBUG` — `TextField("RI override", text: $riOverride).textFieldStyle(.roundedBorder)`. **Only
    here**; the release build has no override and reads the pattern's `ri`.
  - `Divider()`
  - one row per `summary.pavilionTiers`:
    `LabeledContent(row.tier) { … }` whose value is an `HStack` of the angle and, when `row.leaks`, an
    orange `Label(row.margin, systemImage: "sun.max")`, and when it does not, the margin as plain
    `.secondary` text. **The orange is on the margin, not on the tier label**, so the row still reads
    normally.
  - `Text(lightCaveat).font(.callout).foregroundStyle(.secondary)`
  - `Divider()`
  - the probe: `case .unavailable(let reason)` shows the reason at `.callout`/`.secondary` and **no
    toggle**; `case .available` shows `Toggle("Probe", isOn: $probeOn)` and, when `probe != nil`, the
    legs as one `LabeledContent(leg.label, value: "\(leg.facet) · \(leg.incidence)")` each, then
    `Text(readout.ending)` at `.callout`/`.secondary`.
- Held at `.frame(maxWidth: .infinity, alignment: .leading)`, as `MetricsCard` is, so a changing figure
  does not resize the card.

**§4c — `TierTableRegion`'s Angle column carries the mark.** At `:162`
(`TableColumn("Angle") { row in cell(row.angle, row) }`), replace with an `HStack(spacing: 4)` of
`cell(row.angle, row)` and, when `row.leaksLight`, `Label(row.leakShortfall, systemImage: "sun.max")`
with `.labelStyle(.titleAndIcon)` and `.foregroundStyle(.orange)` — the same construction the Tier
column's findings badge uses at `:154`, in a different colour and a different symbol so the two never
read as one thing. **The Tier column is not touched.**

### 5. `CuttingBench/BenchGeometry/Sources/BenchGeometry/TierTable.swift`

`TierTableRow` gains two members, both defaulted so no existing construction site breaks:

```swift
  /// Whether a vertical ray leaks straight out of this tier — a pavilion tier at or below the critical
  /// angle. **Not a finding**: a shallow pavilion may be what the author chose, and a finding must never
  /// blame a complete tier. Always `false` for a tier that is not pavilion.
  public var leaksLight: Bool
  /// How far below the critical angle it sits, as `5.28°`. Empty unless `leaksLight`.
  public var leakShortfall: String
```

added to the initialiser after `meetPoints`, both defaulting (`false`, `""`).

`tierTableRows` gains one parameter and one lookup:

```swift
public func tierTableRows(
  pattern: Pattern?, solid: BenchSolid, light: LightReadout
) -> [TierTableRow]
```

Inside the `map`, read the leak from the readout rather than recomputing it — **the card and the table must
mark the same tiers, and one comparison is how that is guaranteed**:

```swift
    // From the Light readout and never recomputed here: a second `angle <= critical` test could disagree
    // with the card about the same tier.
    let leaking = light.leakingRow(spec.tier)
```

so `LightReadout` also carries, in `LightReadout.swift`:

```swift
extension LightReadout {
  /// The pavilion row for a tier, or `nil` when that tier does not leak. The tier table's one way in.
  public func leakingRow(_ tier: String) -> PavilionAngleRow? {
    guard case .measured(let summary) = self, summary.leakingTiers.contains(tier) else { return nil }
    return summary.pavilionTiers.first { $0.tier == tier }
  }
}
```

**Nothing else in `tierTableRows` changes** — not the state rules at `:76`, not `indices` at `:92`, which is
never sorted.

### 6. New: `CuttingBench/CuttingBench/ProbePathOverlay.swift`

The traced path as SwiftUI over the Metal view — the same mechanism and the same matrices as
`MeetPointOverlay`, so a segment cannot disagree with the solid about where it runs.

```swift
import BenchGeometry
import SwiftUI

/// The probe's path over the viewport. **No occlusion test**, for the reason the meet dots have none: the
/// path runs inside the stone by definition, and the opacity slider is how the owner looks in.
///
/// `.allowsHitTesting(false)`, like the other two overlays: the path must not eat the clicks that drive it.
struct ProbePathOverlay: View {
  let probe: ProbeReadout?
  let camera: BenchCameraState

  var body: some View { … }
}
```

Its body:

- `GeometryReader { proxy in … }`, `aspect` from the proxy exactly as `MeetPointOverlay.swift:36` does.
- One local helper turning a world point into a `CGPoint` in the proxy's own space, via `benchScreenPoint`.
  **A point behind the camera returns `nil` and its leg is dropped** — the projection already answers that
  and this file must not second-guess it.
- **The entry stub**: a `Path` from the projected `entryStub` to the first leg's point,
  `.stroke(.green, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))`.
- **The path inside the stone**: one `Path` through every leg's projected point in order,
  `.stroke(.green, lineWidth: 2)`.
- **The exit stub**, whenever `exitStub` is there: from the last leg's point to the projected stub, dashed
  as `StrokeStyle(lineWidth: 1.5, dash: [4, 3])`, **red when `probe.leaked` and green when it is not**.
  Red is the ray lost out of the back, which is the window the probe exists to find; green is a ray
  returning through the crown or the table, which is the stone working (D17).
- **A chip per leg**, carrying `leg.label`, positioned with `.position` — the same construction as
  `MeetPointOverlay.swift:45`, a `Circle().fill(.green).frame(width: 9, height: 9)` with the label in a
  `.overlay(alignment: .leading)` offset by `12`, because `.position` centres the view it is applied to.
- `.allowsHitTesting(false)` on the whole thing.

`probe == nil` draws nothing at all — no empty path, no chip.

### 7. `CuttingBench/CuttingBench/BenchWindow.swift`

The wiring, and the only file that holds the new state.

**§7a — three new `@State` properties**, after `selectedTier` at `:27`:

```swift
  /// The debug refractive-index override as typed. Session state, never persisted and never written to the
  /// document: a pattern's `ri` is authored, and editing the header is another slice's work.
  @State private var riOverride = ""
  /// Whether a viewport click also traces a ray. A mode rather than a side effect of picking, so the path
  /// has a way to be off.
  @State private var probeOn = false
  /// The last traced path. Cleared with the solid, because a path is a claim about one solid and drawing it
  /// over the next one would be a picture of a stone that is not there.
  @State private var probe: ProbeReadout?
```

**§7b — one computed property**, beside `readout` at `:116`, so the card, the table and the trace all read
one value:

```swift
  /// Recomputed per body pass like `readout`, and for the same reason: it is string formatting over a
  /// handful of tiers, and a cache would be a second place the critical angle could be wrong.
  private var light: LightReadout {
    lightReadout(pattern: document.pattern, solid: store.solid, riOverride: riOverride)
  }
```

**§7c — the three call sites.**

- `ViewportRegion` at `:33` gains `probe: probe`. `ViewportRegion` itself (`BenchRegions.swift:8`) gains
  the matching `let probe: ProbeReadout?` and a third `.overlay { ProbePathOverlay(probe: probe, camera:
  camera) }` **after** the meet-point overlay at `:35`, so the path draws over a dot rather than under it:
  the path is what the owner just asked for and the dots are standing context. Its doc comment's "One Metal
  subview plus the index-ring and meet-point overlays" becomes "plus the index-ring, meet-point and
  probe-path overlays".
- `tierTableRows(pattern:solid:)` at `:57` becomes `tierTableRows(pattern: document.pattern, solid:
  store.solid, light: light)`.
- `InspectorRegion` at `:82` gains `riOverride: $riOverride`, `probeOn: $probeOn` and `probe: probe`.

**§7d — `afterSolidChanged()` at `:152` clears the path**, beside the facet selection:

```swift
    // The path goes with the solid it was traced through. The Probe *mode* stays on: the owner turned it
    // on and a rebuild is not them turning it off.
    probe = nil
```

**§7e — `pick(at:in:)` at `:169` traces after it picks.** Everything down to `:178` is unchanged; the trace
is appended:

```swift
    let hit = pickFacet(store.solid, origin: ray.origin, direction: ray.direction)
    selectedPlaneIndex = hit?.planeIndex
    selectedFacetLabel = hit.map { facetLabel($0.facet) }

    // The pick is unchanged and always happens; the trace is the mode on top of it. Straight down from the
    // point that was clicked, which is how windowing is judged — looking at a face-up stone from above.
    guard probeOn, let hit, let ri = effectiveRefractiveIndex(pattern: document.pattern, override: riOverride)
    else {
      probe = nil
      return
    }
    probe = probeTrace(store.solid, ri: ri, from: hit.point)
```

**A click that misses the solid clears the path**, which the `guard let hit` gives for free and is right: the
owner clicked away from the stone.

## Explicitly not doing

- **No editing and no saving of anything.** The refractive-index override is `#if DEBUG` session state and
  is never written to the document; no angle, no `ri`, no tier is altered. Editing the pattern header is
  `4-Cutting-Bench-Authoring`.
- **No whole-stone brilliance, light-return or windowing metric.** It needs refraction machinery over every
  facet, which the slice's non-goals exclude; the probe gets the diagnostic value out of a fraction of the
  work.
- **No Fresnel splitting and no dispersion.** `Ray.swift:85` traces one ray at one wavelength by design —
  splitting doubles the rays at every bounce and draws an unreadable picture, and a pattern carries one
  `ri`.
- **No renderer or shader change.** The path is a SwiftUI overlay (D16); `BenchRenderer.swift`,
  `MetalViewport.swift`, `SolidMesh.swift` and the `.metal` source are not opened. The Metal Toolchain is
  therefore not needed by any task here.
- **No new finding, and no change to `FindingsReadout` or `Findings.swift`.** A leaking tier is not a fault
  (D4).
- **No fifth pattern in `Design/Patterns/`, and no edit to the four authored ones.** They are external
  ground truth under the protocol's guardrails; the debug override is how a leaking state is reached.
- **No `Dn` sweep of the existing files.** `Chore-Decision-Numbers-Cited-In-Code` is live and its files stay
  as they are; this plan's own new comments simply do not add to the pile (D20).
- **No animated facet arrival and no incremental clipper.** Deferred to
  `Chore-Incremental-Half-Space-Clipper`, which is the ticket that makes it affordable.
- **No kernel change.** `Ray.swift` already ships everything the optics needs. If a task appears to need
  one, that is a stop rule, not a scope decision.

## Tasks

Every task runs the protocol's gates first, in its order, which here means:

1. `swift test --package-path Kernel --disable-sandbox` — green. (Protocol gate 1.)
2. `swift test --package-path CuttingBench/BenchGeometry --disable-sandbox` — green.
3. `xcrun swift-format lint --recursive --strict Kernel/Sources Kernel/Tests
   CuttingBench/BenchGeometry/Sources CuttingBench/BenchGeometry/Tests CuttingBench/CuttingBench` —
   clean.
4. `swift build -c release --package-path Kernel --disable-sandbox` — succeeds. (Protocol gate 3.)
   **No task in this part touches `Kernel/`, so this gate never fires.** If a task appears to need a
   kernel change, that is a stop rule, not a scope decision.
5. The task's own *Done when* items, verbatim.

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

then a second time **without `-DDEBUG`**, to cover the `#if DEBUG` alternative branches — which matters
more in this part than in any before it, since the refractive-index override lives only in the debug
branch. `-disable-sandbox` is required, or the `@Observable` macro plugin fails with
`sandbox_apply: Operation not permitted` and floods the output. It compiles no `.metal` and no resources,
so it replaces neither the owner's build nor an owner-stop verification. If the `-I` path does not exist,
the `swift build` line above creates it.

| # | Task | Status | Then | Commit | Note |
|---|---|---|---|---|---|
| T1 | Prefactor: the pick hands back its point, snapped to its plane | completed | continue | commit | |
| T2 | Pure: the critical-angle readout | completed | continue | — | Material alteration: the *Done when* item requiring `"1."` to fall back could not hold — Swift's `Double("1.")` is `1.0`, and no value-based rule satisfies both it and the item requiring `"0.9"` to pass through. Owner chose to pass it through and correct the check; the item now asserts `1.0` and the reason is in the plan beside it. |
| T5 | Pure: one traced ray, as labelled legs | completed | checkpoint | commit | **Runs here, before T3** — owner-directed on 2026-08-25. As tabled, T3 could not typecheck: Approach §4a gives `InspectorRegion` a `let probe: ProbeReadout?` and that type is created by this task. The Approach's own dependency order already puts the probe trace (§3) before the card (§4). Nothing else moved. Material alteration: `leaked` is the ray leaving through a downward-facing facet, not `trace.ending == .left` — every authored pattern at `1.54` returns through the table, so the first reading would have called all four a leak. Owner-directed; D17, Approach §3 and two of this task's *Done when* items are corrected in place. |
| T3 | The Light card, and the debug refractive-index override | completed | **owner stop** | commit + push | |
| T4 | The leak mark on the Angle column | completed | **owner stop** | commit | Material alteration: the *Done when* item requiring a grep for `critical` to find nothing could not hold — the two doc comments Approach §5 dictates carry the phrase verbatim. Owner chose to keep the comments and correct the check; the item now asserts no comparison and no `asin`, and the reason is in the plan beside it. |
| T6 | The probe: the toggle, the click and the path | completed | **owner stop** | commit + push | |
| T7 | Close out — the plan, the parts and the exploration | awaiting owner | **owner stop** | commit + push | |

**T1 — Prefactor: the pick hands back its point, snapped to its plane**

- **Files:** `CuttingBench/BenchGeometry/Sources/BenchGeometry/BenchPick.swift` (edit),
  `CuttingBench/BenchGeometry/Tests/BenchGeometryTests/BenchPickTests.swift` (edit)
- Make exactly the change in Approach §1: the third return member, the `onPlane` helper, the one added
  doc sentence.
- **Done when:**
  - `pickFacet` returns `(planeIndex: Int, facet: FacetOrigin, point: (x: Double, y: Double, z: Double))?`
    and the first two members keep their names and their meanings.
  - **Every existing test in `BenchPickTests.swift` passes with no edit to its assertions.** This is a
    prefactor; nothing should change. If an existing test fails to compile, the only permitted fix is
    naming the new member — never altering what an assertion checks.
  - Two new tests:
    - the point a hit reports lies on the plane it names, to within `1e-12` — `abs(dot(n, p) - d)`, swept
      over the same grid of directions `testEveryHitNamesAPlaneThatIsActuallyAFacet` at `:81` already
      uses, against both the bare prism and a solved stone;
    - a ray straight down the axis at the round brilliant reports the point `(0, 0, d)` to within
      `1e-12`, where `d` is the offset of the plane the hit names — the table's own plane has normal
      `(0, 0, 1)`, so that is the exact answer and it proves the snap has not slid the point along the
      ray.
  - `swift test --package-path CuttingBench/BenchGeometry --disable-sandbox` passes.
- **Do not:** touch `facetLabel` at `:57`, the private `dot` at `:66`, the slab loop's tolerances or the
  two guards at `:46` and `:49`. Do not make the helper `public`, and do not add a `Dn` citation to any
  comment (D20).

**T2 — Pure: the critical-angle readout**

- **Files:** `CuttingBench/BenchGeometry/Sources/BenchGeometry/LightReadout.swift` (new),
  `CuttingBench/BenchGeometry/Sources/BenchGeometry/MetricsReadout.swift` (edit — one word),
  `CuttingBench/BenchGeometry/Tests/BenchGeometryTests/LightReadoutTests.swift` (new)
- Write the module in Approach §2 exactly, including the `leakingRow(_:)` extension from Approach §5. The
  one edit to `MetricsReadout.swift` is dropping `private` from `noPatternOpen` at `:60`, so both cards
  say one sentence.
- Test it as `MetricsReadoutTests.swift` tests its own module — the authored patterns loaded through
  `AuthoredPatterns` in `BenchSolidTests.swift`, and table-style cases for the formatting.
- **Done when:**
  - With `Pattern-Standard-Round-Brilliant` and an empty override: `criticalAngle` is `"40.49°"`,
    `refractiveIndex` is `"1.54"`, `pavilionTiers` is exactly two rows — `pb` at `"45.00°"` reading
    `"4.51° clear"`, then `pm` at `"43.00°"` reading `"2.51° clear"`, in that order — and `leakingTiers`
    is empty.
  - With the same pattern and the override `"1.30"`: `criticalAngle` is `"50.28°"`, `refractiveIndex` is
    `"1.30 (override)"`, `pb` reads `"5.28° shallow"` and `pm` reads `"7.28° shallow"`, and
    `leakingTiers` is exactly `["pb", "pm"]`.
  - **No margin string ever contains a minus sign**, over all four authored patterns and over the
    overrides `"1.30"` and `"1.54"`.
  - `leakingTiers` never contains a tier whose `part` is not `.pav`, over all four authored patterns at
    override `"1.30"` — which is the check that a `42.00°` crown tier and a `90.00°` girdle tier stay
    unmarked while a shallower pavilion tier marks.
  - A tier sitting exactly at the critical angle leaks (D2). Assert it with a constructed
    `TierSpec(part: .pav, angle: criticalAngleDegrees(ri: 1.54), …)`, not by editing a fixture.
  - `"" `, `"  "`, `"abc"`, `"0"` and `"-2"` in the override all fall back to the pattern's own
    `ri`; `effectiveRefractiveIndex(pattern: nil, override: "1.30")` is `nil`. **A number above `0` but at
    or below `1` is passed through, not rejected**: `criticalAngleDegrees(ri:)` already answers that case
    honestly with `90°`, so every pavilion tier marking is the right answer for a medium no denser than
    air. Assert `effectiveRefractiveIndex(pattern: roundBrilliant, override: "0.9") == 0.9`.
    **`"1."` is passed through as `1.0`, not a fall-back** — owner-directed on 2026-08-25, correcting this
    item. Swift's `Double("1.")` is `1.0`, so only a syntax rule could reject it, and a bare `"1"` on the
    way to `"1.54"` reaches the same `90°` critical angle anyway. Assert
    `effectiveRefractiveIndex(pattern: roundBrilliant, override: "1.") == 1.0`.
  - `lightReadout(pattern: nil, …)` is `.unavailable("No pattern open.")`, and the identical string comes
    out of `unmeasurableReason(pattern: nil, solid:)`.
  - `probe` is `.available` for all four authored patterns, and `.unavailable` with the closed-stone
    sentence for `benchSolid(for: nil)`.
  - `lightReadout` reports pavilion rows for a **part-cut** stone (D5): take `Pattern-Easy-Octagon`,
    truncate it with `benchSolid(for: pattern, tierLimit: 2)`, and assert `.measured` with both pavilion
    tiers present.
  - `lightCaveat` reads exactly
    `"A marked tier leaks a vertical ray. Nothing here says a stone performs well."`
  - `swift test --package-path CuttingBench/BenchGeometry --disable-sandbox` passes.
- **Do not:** compute `asin(1 / ri)` anywhere — call `criticalAngleDegrees(ri:)` (D1). Do not sort
  `pavilionTiers` by angle. Do not touch `metricsReadout`, `facetCountCheck`, `unmeasurableReason` or
  `splitFacetCount` beyond the one `private` keyword. Do not add anything to `TierTable.swift` yet — that
  is T4.

**T3 — The Light card, and the debug refractive-index override**

- **Files:** `CuttingBench/CuttingBench/BenchRegions.swift` (edit),
  `CuttingBench/CuttingBench/BenchWindow.swift` (edit)
- Approach §4a and §4b, plus only the parts of §7 the card needs: the `riOverride` and `probeOn` state, the
  `light` computed property, and `InspectorRegion`'s three new arguments. `probe` is passed as `nil` for
  now — **declare the `@State private var probe: ProbeReadout?` here so the card's probe section is wired
  once**, and leave it never assigned until T6.
- The Toggle appears when the probe is available, as §4b specifies. It does nothing yet, which is fine: T6
  gives the click its meaning.
- **Done when:**
  - Both `swiftc -typecheck` runs above are clean, `-DDEBUG` and without.
  - `xcrun swift-format lint --recursive --strict …` is clean over the paths in the gate list.
  - The Light card is the only card that changed: `GroupBox("Pattern")`, `GroupBox("Notes")`,
    `GroupBox("Metrics")` and `GroupBox("Facet Count")` are byte-identical, and the card order at `:224`
    to `:236` is unchanged.
  - The `TextField("RI override", …)` sits inside `#if DEBUG` and nowhere else.
- **Do not:** touch `MetricsCard`, `FacetCountCard`, `EmptyCard`, `StatusStripRegion` or
  `TierTableRegion` in this task. Do not add a Clear button beside the override field — the field is free
  text and emptying it *is* the clear (D8). Do not persist `riOverride` or `probeOn` anywhere.
- **Verification handle** — `temporary` (the RI override field only; the card itself is `permanent`):
  - **Where:** open `Design/Patterns/Pattern-Standard-Round-Brilliant.json`, inspector open, the **Light**
    card between Metrics and Facet Count.
  - **Positive:** type `1.30` into **RI override**. `Critical angle` changes from `40.49°` to `50.28°`,
    `Refractive index` from `1.54` to `1.30 (override)`, and both pavilion rows flip from `pb 45.00° ·
    4.51° clear` / `pm 43.00° · 2.51° clear` to `pb 45.00° · 5.28° shallow` / `pm 43.00° · 7.28° shallow`,
    each shallow margin orange with a `sun.max` symbol.
  - **Negative:** clear the field. Every one of those five values returns to exactly its first reading, and
    both margins go back to plain grey text with no symbol. Then type `abc`: **nothing moves at all** — the
    card stays on `1.54` and `40.49°`, because text that is not a number is not a refractive index.
  - **Reads:** `lightReadout` and `effectiveRefractiveIndex` in
    `CuttingBench/BenchGeometry/Sources/BenchGeometry/LightReadout.swift`.
  - Also check, in the same pass: `⌘N` for an empty document leaves the Light card reading
    `No pattern open.` and showing no field and no toggle; and with the round brilliant open the card shows
    a **Probe** toggle above the sentence `A marked tier leaks a vertical ray. Nothing here says a stone
    performs well.` The toggle does nothing yet.

```
3-cutting-bench-pattern-display-5 T1-T3: the critical angle, in a card

- The pick hands back the point it hit, snapped onto the plane it names, so a
  traced ray can start there.
- A pure Light readout: the critical angle from the pattern's own refractive
  index, and every pavilion tier's margin against it. No solve needed, so it
  reports for a part-cut stone too.
- The Light card fills in, with a DEBUG refractive-index override — no authored
  pattern leaks at 1.54, so the leaking state has no other way to be seen.
```

**T4 — The leak mark on the Angle column**

- **Files:** `CuttingBench/BenchGeometry/Sources/BenchGeometry/TierTable.swift` (edit),
  `CuttingBench/BenchGeometry/Tests/BenchGeometryTests/TierTableTests.swift` (edit),
  `CuttingBench/CuttingBench/BenchRegions.swift` (edit — `TierTableRegion` only),
  `CuttingBench/CuttingBench/BenchWindow.swift` (edit — the `tierTableRows` call only)
- Approach §5 and §4c, plus the one call-site change in §7c.
- **Done when:**
  - `TierTableRow` carries `leaksLight` and `leakShortfall`, both defaulted in the initialiser, and
    `tierTableRows` takes `light:`.
  - The leak comes from `light.leakingRow(_:)` and **`TierTable.swift` contains no comparison against a
    critical angle, and no `asin`** — `leaking` is read from the readout and worked out nowhere else.
    **The grep for the word `critical` is not part of this item** — owner-directed on 2026-08-25,
    correcting it. As written the item also required that word to be absent, which Approach §5's own two
    doc comments on `leaksLight` and `leakShortfall` carry verbatim; those two comments are its only
    occurrences in the file.
  - New tests: for `Pattern-Standard-Round-Brilliant` at override `""`, no row has `leaksLight`; at
    override `"1.30"`, exactly the rows `pb` and `pm` have it, with `leakShortfall` `"5.28°"` and
    `"7.28°"`; the crown row `cm` at `42.00°` has `leaksLight == false` **even though 42 is below that
    override's 50.28° critical angle**, and so does the girdle row `g`.
  - Every existing test in `TierTableTests.swift` passes with no change beyond adding the new `light:`
    argument at its call sites.
  - `swift test --package-path CuttingBench/BenchGeometry --disable-sandbox` passes, and both
    `swiftc -typecheck` runs are clean.
- **Do not:** touch the Tier column at `:146`–`:160`, the `cell` helper at `:190`, the row-state rules at
  `TierTable.swift:76`, or `indices` at `:92`. Do not add a sort key to any column. Do not let a leak
  reach `FindingsReadout`, `findingsReadout` or the status strip's count (D4).
- **Verification handle** — `permanent`:
  - **Where:** the tier table across the bottom of the window, **Angle** column, with
    `Pattern-Standard-Round-Brilliant` open.
  - **Positive:** type `1.30` into the Light card's RI override. The `pb` row's Angle cell becomes
    `45.00°` followed by an orange `sun.max` and `5.28°`, and `pm`'s becomes `43.00°` with `7.28°`.
  - **Negative:** in that same screen, with the override still at `1.30`, the crown row `cm` reads a bare
    `42.00°` with no mark — shallower than the `50.28°` critical angle and still unmarked, because it is a
    crown tier and the ray does not land there. The girdle row `g` at `90.00°` and the table row `t` at
    `0.00°` are likewise bare. Then clear the override and **every** mark disappears.
  - **Reads:** `leakingRow` in `LightReadout.swift` through `tierTableRows` in `TierTable.swift`.
  - Also check: the status strip's findings count is the same number before and after the override
    changes — a leak is not a finding.

```
3-cutting-bench-pattern-display-5 T4: the leak mark, beside the angle

- A pavilion tier at or below the critical angle marks its Angle cell, orange,
  with the symbol and the shortfall so it is never colour alone.
- Read from the Light readout, never recomputed, so the card and the table can
  only ever mark the same tiers.
- Not a finding: a shallow pavilion may be what the author chose, and the
  findings count does not move.
```

**T5 — Pure: one traced ray, as labelled legs**

- **Files:** `CuttingBench/BenchGeometry/Sources/BenchGeometry/ProbeReadout.swift` (new),
  `CuttingBench/BenchGeometry/Tests/BenchGeometryTests/ProbeReadoutTests.swift` (new)
- Write Approach §3 exactly: the two types, the guard, the one `traceRay` call with its literal direction
  and bounce limit, the leg labelling, the two stubs and the four ending sentences.
- Every test point comes from `pickFacet`, so a test can never start a ray off the surface — which is the
  same path the app takes.
- **Done when, all against `Pattern-Standard-Round-Brilliant` unless stated:**
  - Take the table point `pickFacet(solid, origin: SIMD3(0.1, 0.05, 5), direction: SIMD3(0, 0, -1))`. At
    `ri` 1.54: `legs[0].label == "E"`, `legs[0].facet` begins `"t · "`, and
    `legs[0].incidence == "0.00°"` — a vertical ray onto a `0.00°` table arrives at zero incidence, which
    is the classic table test.
  - **The first bounce's incidence equals the authored angle of the tier it landed on**, formatted the same
    way — look the tier up through `solid.origin` and `pattern.tiers`. This is the claim the whole
    critical-angle check rests on, and it is the one test that proves it rather than asserting it.
  - Same point, `ri` 1.54: `legs.count >= 3` and `leaked == false` on the first bounce — a pavilion facet at
    `45.00°` or `43.00°` is above the `40.49°` critical angle, so the ray must reflect and must therefore
    reach a further surface.
  - Same point, `ri` 1.30: `legs.count == 2`, `leaked == true`, and `ending` begins `"Left through "` and
    contains `"50.28°"`. The first pavilion facet is now at or below the critical angle, so the ray leaves
    on its first bounce.
  - `entryStub` is `legs[0].world + SIMD3(0, 0, 0.5)` to within `1e-6`. At `ri` 1.30 the distance from the
    last leg's `world` to `exitStub` is `0.5` to within `1e-6` — the exit direction is normalised before it
    is scaled. **At `ri` 1.54 the stub is there and `leaked` is `false`** — owner-directed on 2026-08-25,
    correcting this item, which read "with no leak, `exitStub` is `nil`". The ray does leave: on all four
    authored patterns it returns through the table at about `8°` after two pavilion reflections. Assert
    over all four that at `1.54` `exitStub` is non-`nil` with `leaked == false`, and at `1.30` non-`nil`
    with `leaked == true`.
  - A pavilion point — `pickFacet(solid, origin: SIMD3(0, 0, -6), direction: SIMD3(0, 0, 1))`, the same ray
    `BenchPickTests.swift:70` uses — gives `legs` empty, both stubs `nil`, `leaked == false`, and `ending`
    exactly `"A vertical ray does not enter through this facet."`
  - `probeTrace(benchSolid(for: nil), ri: 1.54, from: (0, 0, 1))` gives `legs` empty and `ending` the same
    closed-stone sentence `lightReadout` produces, character for character.
  - Every leg's `facet` is non-empty, and none is `"—"`, over a sweep of table points on all four authored
    patterns at `ri` 1.54. A `"—"` here would mean a plane the trace hit has no entry in the origin map.
  - `swift test --package-path CuttingBench/BenchGeometry --disable-sandbox` passes.
- **Do not:** reimplement refraction, reflection, the critical angle or a nearest-surface search — call
  `traceRay` once and read what it returns. Do not pass `solution.planes` (D9). Do not raise `bounceLimit`
  above `8` or make it a parameter. Do not touch `LightReadout.swift`, `BenchPick.swift` or anything under
  `CuttingBench/CuttingBench/`.

```
3-cutting-bench-pattern-display-5 T5: one ray, as legs a card can read

- probeTrace wraps the kernel's traceRay: straight down from the clicked point,
  eight bounces at most, every leg carrying the facet it landed on and how
  steeply it arrived.
- Traces the drawn solid's own planes and only once the scaffolding has come
  away, so it can never report on a rough-capped stone.
- Pinned by the test that matters: the first bounce's incidence is exactly the
  authored angle of the pavilion tier it hit.
```

**T6 — The probe: the toggle, the click and the path**

- **Files:** `CuttingBench/CuttingBench/ProbePathOverlay.swift` (new),
  `CuttingBench/CuttingBench/BenchRegions.swift` (edit — `ViewportRegion` only),
  `CuttingBench/CuttingBench/BenchWindow.swift` (edit)
- Approach §6, plus the rest of §7: the third overlay on `ViewportRegion`, the `probe` argument, the clear
  in `afterSolidChanged()`, and the trace appended to `pick(at:in:)`.
- **Done when:**
  - Both `swiftc -typecheck` runs are clean, `-DDEBUG` and without, and the format lint is clean.
  - `pick(at:in:)`'s first four statements — the size guard, `benchRay`, `pickFacet`, and the two
    selection assignments — are unchanged. **The pick still happens on every click whether the mode is on
    or off** (D15).
  - `ProbePathOverlay` carries `.allowsHitTesting(false)`, and is the third `.overlay` on
    `MetalViewport`, after `MeetPointOverlay`.
  - `afterSolidChanged()` sets `probe = nil` and **does not** touch `probeOn`.
  - `BenchRenderer.swift`, `MetalViewport.swift`, `SolidMesh.swift` and every `.metal` file are untouched
    — `git status` names none of them.
- **Do not:** add an occlusion test, a depth test, or any read of the mesh in the overlay (D16). Do not
  clear `probeOn` on a rebuild. Do not make the probe replace the facet pick or the status strip's facet
  name. Do not add a "Clear path" button — clicking off the stone clears it.
- **Verification handle** — `permanent`:
  - **Where:** `Pattern-Standard-Round-Brilliant` open, **Face Up** from the toolbar, the Light card's
    **Probe** toggle on.
  - **Positive:** click the table a little off its centre. A green path draws from the click point — a
    dashed green stub above it, then solid green legs down into the stone — with a small numbered chip at
    each bounce, and the Light card lists `E · t · … · 0.00°` followed by at least two numbered legs whose
    facets are pavilion tiers, then a sentence saying how the path finished. The first numbered leg's
    incidence reads exactly the angle its tier shows in the tier table (`45.00°` or `43.00°`). The path
    ends with a **green** dashed stub leaving through the table at about `8°` — light return, not a leak.
  - **Negative:** turn **Probe** off and click the same point again. **No path draws and the card lists no
    legs** — while the status strip's `Facet …` readout still changes, because the pick is untouched. Turn
    it back on, click again, then drag to orbit: the path stays with the stone rather than sticking to the
    screen.
  - **Reads:** `probeTrace` in
    `CuttingBench/BenchGeometry/Sources/BenchGeometry/ProbeReadout.swift`, drawn through
    `benchScreenPoint`.
  - Also check, in the same pass: with the override at `1.30` the same click ends in **one** numbered leg
    and a **red dashed** stub leaving the stone, and the card's sentence begins `Left through`; scrubbing
    the playback slider clears the path; and clicking a pavilion facet with the opacity slider pulled down
    gives the card `A vertical ray does not enter through this facet.` and draws nothing.

```
3-cutting-bench-pattern-display-5 T6: click the crown, watch the ray

- A Probe mode in the Light card: with it on, a click also traces one ray
  straight down from the point clicked, and the card lists every leg with the
  incidence it arrived at.
- The path draws as a third SwiftUI overlay over the Metal view, green inside
  the stone and red dashed where the ray leaves — the renderer is untouched.
- The path clears with the solid it was traced through; the mode does not.
```

**T7 — Close out — the plan, the parts and the exploration**

This is the **last part of five**, so this is where the whole set retires.

- **Files:** `CuttingBench/CuttingBench/BenchRegions.swift` (edit),
  `Design/Plans/3-Cutting-Bench-Pattern-Display-5-Light.md` (edit), plus whatever the archive routine moves.
- **Delete the one temporary handle: the `#if DEBUG` RI override.** In `BenchRegions.swift`, remove the
  `TextField("RI override", …)` and its `#if DEBUG` block from `LightCard`, remove `riOverride` from
  `InspectorRegion` and `LightCard`, and in `BenchWindow.swift` remove the `@State private var riOverride`
  and pass `riOverride: ""` at the one call to `lightReadout`. **`effectiveRefractiveIndex` and its
  `override` parameter stay** — they are tested, they are how the pattern's own `ri` reaches both readouts,
  and an empty string is the ordinary case. The card then always reads the pattern's own `ri` with no
  `(override)` suffix.
  - After the deletion: both `swiftc -typecheck` runs clean, the format lint clean, every `swift test` green,
    and `grep -r "RI override" CuttingBench` finds nothing.
- **Confirm every item in this plan's Deferred section has a ticket** in `Design/Tickets/` with
  `Status: untriaged`. The executor files each as it finds it, per the protocol; this is the check, not the
  filing.
- **Report the untriaged ticket count** in `Design/Tickets/` as one line.
- `commit + push` with the message below.
- **Archive per `Design/Execution-Protocol.md` §11** — six items, each by name, each with its own catalog
  line:
  - the plan `3-Cutting-Bench-Pattern-Display-1-Solid-And-Tier-Table`
  - the plan `3-Cutting-Bench-Pattern-Display-2-Metrics-And-Facet-Count`
  - the plan `3-Cutting-Bench-Pattern-Display-3-Findings-And-Meet-Points`
  - the plan `3-Cutting-Bench-Pattern-Display-4-Playback`
  - the plan `3-Cutting-Bench-Pattern-Display-5-Light` — this file
  - the exploration `3-Cutting-Bench-Pattern-Display`
  - **No tickets are archived**: this plan closes none. `Chore-Incremental-Half-Space-Clipper`,
    `Chore-Validation-Rebuilds-The-Solid-Once-Per-Tier` and `Chore-Decision-Numbers-Cited-In-Code` all stay
    in `Design/Tickets/`.
  - The routine's third step — does the document contradict shipped code — **is a judgment per item, not a
    default**. Part 4 already carries an amendment banner and its catalog line must say `superseded by` with
    that contradiction as its clause. Make the call for each of the other five on what the code actually
    does; do not assume `executed` for all of them and do not assume the banner for any.
- **Do not:** archive the four sibling explorations `1-Cutting-Bench-Kernel-Changes`,
  `2-Cutting-Bench-App-Shell`, `4-Cutting-Bench-Authoring` or `5-Cutting-Bench-Angle-Tuning`. Only
  `3-Cutting-Bench-Pattern-Display` and its five plans retire here. Do not rename anything on the way into
  the archive, and do not re-sort `ArchivedCatalog.md`.

```
3-cutting-bench-pattern-display-5 T7: close out the display slice

- The temporary DEBUG refractive-index override goes; the card reads the
  pattern's own ri.
- Archived: all five parts of the display plan and the exploration behind them.
  No ticket closes here — the three open chores are all somebody else's work.
```

## Deferred

Empty at authoring. The executor appends adjacent problems it found and must not fix — and files each as a
ticket in `Design/Tickets/` immediately with `Status: untriaged`, per the protocol.
