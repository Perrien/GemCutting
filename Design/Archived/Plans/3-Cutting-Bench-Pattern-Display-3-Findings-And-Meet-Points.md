# 3 · Cutting Bench Pattern Display — Part 3: Findings And Meet Points

Status: **Part 3 completed 2026-08-25.** Nothing here is archived: this is one part of five, and the
exploration `3-Cutting-Bench-Pattern-Display` stays live as the design source for parts 4 and 5, which
archive this plan along with their own when the last of them closes out.

**Archived 2026-08-25 — trust the code, not the two claims below.** `doesNotClose` **names no tier.** Its
sentence in the shipped code is `The solid does not close: some facets are incomplete, with an edge no
other facet shares.`, and `findingTier` returns `nil` for it. The Approach's finding-text table still
gives the tier-naming sentence for a non-`nil` tier, and the line under it still says `findingTier`
returns that tier. T7's material alteration, owner-directed, is what changed both: the tier the kernel
reports is where the open edge was found, not what left it open, and on a part-cut stone that is a tier
which is complete.

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
   a lettered, coloured dot in both the viewport and the meet cell. ← this part
4. `3-Cutting-Bench-Pattern-Display-4-Playback` — the scrubber at tier and facet granularity, prefix
   intersection, one honest wait on entering playback with progress shown, and the intermediate-solid
   display mode. Retires the debug tier-limit stepper.
5. `3-Cutting-Bench-Pattern-Display-5-Light` — the critical-angle marking on pavilion tier rows, and
   the clickable single-ray probe with its per-bounce incidence readout, offered only when the
   pattern's own solid closes. Closes the exploration out and runs the archive routine.

| Exploration ID | Part |
|---|---|
| S1 | 1, 2, 4, 5 — the slice's scope statement rather than a unit of work; its done-conditions land per part. |
| S2 | 5 |
| I1 | 1 — its rule that the kernel's own rough-free solid is what `metrics` and `validate` see binds this part and is restated here as D22 |
| I2 | 1 — its partial-solve state is what D12 and D13 report on here |
| I3 | 4 |
| I4 | 5 |
| I5 | 2 |
| U1 | 3 |
| U2 | 2 |
| U3 | 1 |
| U4 | 3 |
| U5 | 4 |
| U6 | 4 |

**No boundary has moved.** The split is the one the owner approved on 2026-08-25, and parts 1 and 2
shipped against it. The exploration's non-goals bind every part unchanged — in particular **nothing in
this part edits or saves anything**, and nothing here animates a facet's arrival.

**One thing this part adds that the map does not predict.** U4's dots cannot be drawn for Novice
Ash-er without the solver's axial point, which is private to the solve today, so this part extracts it
into the kernel as a shared function (T1, T2). That is a prefactor, not a boundary move: no exploration
ID changes hands.

## Context

The app draws the right stone and measures it, and says nothing about whether the pattern is any good.
The kernel has computed that answer since the first plan and nothing has ever displayed it. This part
displays it, and draws the points a pattern's meets actually name.

**Two things the owner wants, and they are the same thing twice.** A finding names a tier; a meet names
a point. Both are useless as a list in a panel and useful the moment the row is marked in the table and
the geometry is visible in the viewport. That pairing is why the two land together.

**The findings the kernel already computes, none of them displayed.** Validation is split three ways and
every piece is public:

- `Validation.swift:106` (`public func structuralFindings(_ pattern: Pattern) -> [Finding]`) — readable
  from the pattern alone, no solve needed. The cheap half.
- `Validation.swift:189` (`public func namedPointFindings(`) — one tier at a time, and
  `Validation.swift:179` records that tier *k*'s result depends only on the tiers before *k*. The
  expensive half: **1.65 s on a 139-plane pattern**, against 0.60 s for the whole solve.
- `Validation.swift:219` (`public func solidFindings(_ solution: Solution, declaredFacetCount: Int?) ->
  [Finding]`) — closure and the facet count. Whole-solid and cheap.

`Validation.swift:61` (`public func validate(`) is the kernel's own composition of the three, and
`Validation.swift:63` (`guard structural.isEmpty else { return Report(findings: structural,
observations: []) }`) is the rule this part has to honour: when the pattern's own structure is wrong the
geometric checks do not run, because no solid corresponds to the pattern as written. **The app calls the
three pieces rather than `validate`**, because it needs the cheap half now and the expensive half later,
which is exactly what the split exists for.

**`Finding` has no display form.** `Validation.swift:4` (`public enum Finding: Sendable, Equatable`) is
nine cases and no `CustomStringConvertible`; `facetsolve/main.swift:87` (`func printed(_ finding:
Finding) -> String`) prints `"\(finding)"` — the raw enum reflection, deliberately, so the CLI output
and the source share one vocabulary. That is not a sentence for a window, so this part writes the nine
sentences (D20) and **leaves the CLI's wording alone**.

**The meet points are one function short of drawable.** `Polytope.swift:24` (`public func triplePoint(`)
gives the point three named planes meet at; `Validation.swift:91` (`public func planes(of tier:
SolvedTier) -> [Plane]`) gives a solved tier's half-spaces; part 2 left the solve itself on the solid at
`BenchSolid.swift:35` (`public var solution: Solution?`). What is missing is the **axial point** a `tcp`
resolves to. `Solver.swift:275` (`private var axial: [Side: Double] = [:]`) holds it inside the solve,
`Solver.swift:449` (`let crossing = d / z`) computes it, and `Solver.swift:385` (`guard let z =
axial[Side(spec.part)] else {`) reads it. Nothing outside the solve can.

That matters because **four of Novice Ash-er's seven tiers are a `fraction` running `to: tcp`** — P2,
P3, C2 and T. Their **B** dot *is* the axial point. Re-deriving the rule in the app is the one thing
this codebase refuses on principle, and the rule carries a documented trap:
`Solver.swift:444` warns that letting a 90° tier register a phantom axial point "is a live trap", which
is why `Solver.swift:448` (`guard abs(z) >= 1e-9 else { return }`) exists at all. So the rule is
extracted and shared (D1).

**Where the display goes, all of it already built by parts 1 and 2:**

- The status strip's leading text is a placeholder: `BenchRegions.swift:191`
  (`Text(solid.stoppedReason ?? "No findings")`). This part replaces it (D12).
- The tier table is a `Table` with seven columns and no selection: `BenchRegions.swift:49`
  (`Table(rows) {`), its per-row styling in one helper at `BenchRegions.swift:71` (`private func
  cell(_ text: String, _ row: TierTableRow, dimmed: Bool = false) -> some View`), and its rows built
  purely at `TierTable.swift:64` (`public func tierTableRows(pattern: Pattern?, solid: BenchSolid) ->
  [TierTableRow]`). The stopped tier is already marked by a symbol rather than by colour alone, at
  `BenchRegions.swift:52` (`if row.state == .stopped { Image(systemName: "exclamationmark.triangle") }`).
- **A 3D point already draws as SwiftUI text over the Metal view**, and that is the whole mechanism the
  dots need: `IndexRingOverlay.swift:17` (`if let point = benchScreenPoint(label.anchor, aspect: aspect,
  camera: camera) {`) over `BenchCamera.swift:202` (`public func benchScreenPoint(`), which returns the
  viewport fraction with `(0, 0)` top-left. `BenchRegions.swift:28`
  (`.overlay { IndexRingOverlay(labels: ringLabels, camera: camera) }`) is where a second overlay joins
  it. **No renderer change and no shader change** (D18).
- The window owns the state and drives the store from one place: `BenchWindow.swift:95`
  (`.onChange(of: document.pattern, initial: true) { rebuild() }`) and `BenchWindow.swift:101`
  (`private func rebuild() {`).
- The debug tier-limit stepper at `BenchRegions.swift:212` (`Stepper("tiers \(tiersShown)/\(tierTotal)")`)
  is the only way to reach a part-cut stone, since all four authored patterns are `finished` and
  correct. **It is this part's verification handle**: every authored pattern comes back with no findings,
  so a fault has to be manufactured, and truncating the tiers manufactures one the kernel really reports.
  Part 4 retires the stepper.

**Nothing here is new architecture.** Two pure modules in `BenchGeometry` beside the two part 2 added, one
`@Observable` store beside `BenchSolidStore`, one SwiftUI overlay beside `IndexRingOverlay`, and one
kernel function lifted out of a private field.

## Decisions (2026-08-25)

| # | Decision |
|---|---|
| D1 | **The axial-point rule is extracted into the kernel and shared, never re-derived in the app.** Four of Novice Ash-er's seven tiers run a `fraction` to `tcp`, so their **B** dot is the axial point; and the rule carries a trap the solver's own comment calls live — a 90° tier must not register a phantom crossing. A second implementation of a rule with a trap in it is how a display comes to disagree with the solve. |
| D2 | **The extracted signature, verbatim:** `public func axialPoint(onTheSideOf part: Part, cutBy tiers: [SolvedTier]) -> (x: Double, y: Double, z: Double)?`. `nil` means nothing has reached the axis on that side yet. It takes a `Part` and derives crown-or-pavilion internally, matching `Solver.swift:253` (`init(_ part: Part)`), because `Side` is private and stays private. |
| D3 | **`axialPoint` recomputes from the solved tiers rather than being handed the solve's running dictionary.** A `SolvedTier` carries `angle`, `wheel`, `part`, `indices` and `d`, which is everything `planeNormal` needs, and `Solver.swift:344` states every facet of a tier shares one `z` — so the first index stop answers for the tier. Recomputing is O(tiers) per call against a solve that is already quartic in plane count. |
| D4 | **Dots are drawn for one tier at a time — the tier selected in the tier table. No selection, no dots.** A `fraction`'s endpoints are lettered **A** and **B**, so drawing every tier's points at once would put four A's and four B's on Novice Ash-er and the letters would stop identifying anything. Selection is also what makes "viewport and table are read together" literal: you click the row and the points appear. |
| D5 | **The dot set per meet form.** A `fraction` shows three, in the order **A**, anchored, **B** — the anchored point sits between its endpoints and reads that way in the cell. A plain `vertex` shows one, lettered **M**. `size`, `tcp` and `girdle` name no facet triple and show none; that is the negative half of T4's handle. |
| D6 | **Every dot carries its label, so colour is never the only distinction** — the correspondence has to hold for a colour-blind reader and in a screenshot. **A** and **B** carry their letter and their facet triple; the anchored dot carries the percentage to two decimals (`24.86%`) and no facet text, because it names no facets; **M** carries its letter and its triple. |
| D7 | **Role to colour, fixed:** A → `.teal`, B → `.purple`, anchored and M → `.yellow`, a warning dot → `.red`. **Not the accent colour**, which is the cut facets' at `BenchRenderer.swift:173` (`cutColor: rgba(.controlAccentColor, in: appearance)`), and **not orange**, which is the picked facet's at `BenchRenderer.swift:176` (`highlightColor: rgba(.systemOrange, in: appearance)`). The pure module returns a role; the view maps role to colour, as the renderer already resolves its own colours per appearance. |
| D8 | **A point resolves against the tiers cut before it, taken as `solid.solution.tiers.prefix(k)` where `k` is the tier's own position in `pattern.tiers`.** One rule with no special case: for a solved tier that is every earlier solved tier; for the tier that stopped the solve it is every solved tier, which is exactly right, because a stopped tier's meet still names only earlier facets. |
| D9 | **No occlusion test — every dot of the selected tier draws, on the visible surface or not.** A meet is a cutting-time claim, so a named point is routinely inside the finished stone, cut away by a later tier, or off the solid altogether — and that last case is the fault `vertexNotOnIntermediateSolid` exists to report. Hiding the points behind the surface would hide precisely the ones worth looking at. The opacity slider already in the toolbar is how the owner looks in. |
| D10 | **An unresolvable point still gets its chip in the table and no dot in the viewport.** `world` is `nil` when a named facet was never placed or the three planes pin no point. The cell is read off the pattern and must not go blank because the solve fell short. |
| D11 | **The findings pipeline passes `declaredFacetCount: nil`.** The declared count is the Facet Count card's business and part 2 already reports it at `MetricsReadout.swift:160` (`let mismatched = solidFindings(solution, declaredFacetCount: count).contains { finding in`). Counting it here would report one fault twice **and** restart the 1.65 s geometric check on every keystroke in that field, in a slice whose trigger is opening a pattern rather than typing. |
| D12 | **The strip's leading text becomes the findings line, replacing part 1's `stoppedReason ?? "No findings"` placeholder.** Nothing is lost: the stopped tier is named in the line's own prefix, and the kernel's verbatim sentence becomes the first row of the detail popover, where it can be marked against its tier like any other row. |
| D13 | **The line's grammar, verbatim.** No pattern open → `No pattern open.` Otherwise a prefix of `Stopped at tier <T> · ` when the solve stopped, then one count phrase: `No findings`, `1 finding`, or `<n> findings`. |
| D14 | **Stale and in-flight are one phrase, appended to the count:** `3 findings · stale, checking…`. With no previous result at all, the whole count phrase is `checking…`. The exploration requires both that the previous result stay visible and that it never read as current, and one phrase carrying both is what stops the line saying `3 findings` while a fourth is being counted. |
| D15 | **When `structuralFindings` is non-empty the geometric half never starts**, matching `Validation.swift:63`, and the popover's last row says so in words: `The geometric checks did not run: a pattern whose structure is wrong has no solid to measure them against.` |
| D16 | **Cancellation is per tier.** `geometricFindings` takes an `isCancelled: () -> Bool`, checks it between tiers, and returns `nil` when it fires; the store passes `{ Task.isCancelled }`. That is what the kernel's per-tier split buys — a 139-plane pattern abandons after the current tier rather than after 1.65 s. A monotonic generation counter guards the assignment, so a task that finishes after a newer one started is discarded rather than racing it. |
| D17 | **The geometric half runs in `Task.detached(priority: .userInitiated)`; the store is `@MainActor`.** `Pattern`, `Solution` and `Finding` are all `Sendable`, so the values cross with no wrapping. |
| D18 | **A finding's geometry is highlighted by recolouring its tier's dots, and no shader changes.** The renderer's highlight is one plane index in a uniform float — `BenchRenderer.swift:178` (`params: SIMD4(Float(opacity), -1, Float(highlightedPlaneIndex ?? -1), 0))`) — so a set of planes would need a new vertex attribute and a `.metal` edit. Only one finding has geometry to show anyway: `vertexNotOnIntermediateSolid`, whose named point resolves to a dot that visibly floats off the stone. That is the whole highlight, and it is free once U4's dots exist. |
| D19 | **The warning colour keys on the tier, not on the triple.** The finding carries its triple, but a tier's dots are read as one meet, and threading a dot identity through a kernel finding is not possible. Every dot of a tier carrying a `vertexNotOnIntermediateSolid` finding draws red. |
| D20 | **Every tier with a finding is marked in the table unconditionally, not on selection.** The table is then the map of where the faults are, which is what tells the owner which row to click; a marker that only appears once you have found the row is no help finding it. The marker is `exclamationmark.circle`, distinct from the stopped tier's `exclamationmark.triangle`, and it carries the count. **The marker is overlaid by the view from the findings readout, and `tierTableRows` gains no findings parameter** — the rows stay a pure function of pattern and solid, so an arriving geometric result does not rebuild every row. |
| D21 | **`meetText` and `TierTableRow.meet` are unchanged, and the cell prefers the chips when there are any.** Part 1's `TierTableTests` pin `meet` for all four patterns — `"24.86% from G@12 · G@24 · P1@24 to tcp"` at `TierTableTests.swift:37` — and changing that string to make room for chips would break passing tests to no purpose. `meet` is still the cell's text for `size`, `tcp` and `girdle`. |
| D22 | **The kernel's own solid stays rough-free and is what every check here sees** (ADR-0004, part 1). Findings are computed from `solid.solution`, never from `solid.polytope`, which carries the rough's eighteen half-spaces while the pattern is open. Feeding a rough-capped solid to `solidFindings` would make the closure check pass for every pattern including the ones it exists to catch. |
| D23 | **Building and running the app is the owner's action at every owner stop.** No shared `.xcscheme` exists — `xcuserdata/` is gitignored — so the executor cannot build the app target. The executor's own checks are the two package test suites and `swift-format`. New files under `CuttingBench/CuttingBench/` need no project edit: the target is a `PBXFileSystemSynchronizedRootGroup`, and `project.pbxproj` is never hand-edited. |
| D24 | **Nothing in this part edits or saves anything.** No tier changed, no meet built by clicking, no percentage edited, no `state` switch. Table selection is a view state and is not persisted. |

## Tickets closed by this plan

None — closed in the final part.

## Prefactoring

**Two tasks, T1 and T2, and they are the whole of it.**

The axial-point rule has to be readable from outside the solve (D1). Its behaviour is already pinned by
`RegressionTests.swift:31` (`func testEachPatternStillSolvesToItsFixture() throws`) over all four
patterns — Novice Ash-er's four fraction-to-`tcp` depths among them — and by three named tests in
`SolverTests.swift`: `:168` (`func testNinetyDegreeGirdleTierLeavesTheAxialPointFree() throws`), `:179`
(`func testSecondTCPOnTheSameSideThrows()`) and `:192` (`func testOneTCPPerSideIsAccepted() throws`).

**One branch of the rule the corpus does not reach**, and it is the branch most easily got wrong:
`Solver.swift:451` (`if axial[side].map({ abs(crossing) < abs($0) }) ?? true {`) — a later tier crossing
the axis nearer the girdle *replaces* the earlier crossing. **T1 writes the characterization test for it
before T2 touches anything**, because a refactor that silently drops that comparison would pass every
existing test.

T2's own check is inverted, as a prefactor's always is: **nothing changes.** Every existing test passes
unchanged, including the one T1 just added.

## Approach

Two pure modules carry all the logic — one for the dots, one for the findings — and each is a table-style
test file's worth of strings and points, exactly as `MetricsReadout.swift` and `MetricsReadoutTests.swift`
do it. The app layer adds one overlay, one store, and edits to the two views that already exist. The
kernel gains one function and loses a private field.

### 1. `Kernel/Sources/FacetKernel/Solver.swift` — lift the axial point out

Add one public free function, at file scope, directly after the private `Side` enum at
`Solver.swift:249` (`private enum Side: Hashable {`) so it sits beside the type it uses. `Side` stays
private; the function's parameter is a `Part` (D2).

```swift
/// Where the stone's surface crosses the axis on the same side as `part`, given the tiers cut so far —
/// or `nil` when nothing has reached the axis there yet.
///
/// The surface at the axis is whichever plane crosses it closest to the girdle, since anything beyond
/// that has already been cut away. A 90-degree tier never reaches the axis, and letting one register a
/// phantom axial point is a live trap.
///
/// Every facet of a tier shares one `z`, so the tier's first index stop answers for the tier.
public func axialPoint(
  onTheSideOf part: Part,
  cutBy tiers: [SolvedTier]
) -> (x: Double, y: Double, z: Double)? {
  let side = Side(part)
  var nearest: Double?
  for tier in tiers where Side(tier.part) == side {
    guard let stop = tier.indices.first else { continue }
    let z = planeNormal(angleDegrees: tier.angle, index: stop, wheel: tier.wheel, part: tier.part).z
    guard abs(z) >= 1e-9 else { continue }
    let crossing = tier.d / z
    if nearest.map({ abs(crossing) < abs($0) }) ?? true { nearest = crossing }
  }
  return nearest.map { (x: 0, y: 0, z: $0) }
}
```

The `1e-9` is the literal already at `Solver.swift:448` (`guard abs(z) >= 1e-9 else { return }`), carried
across unchanged rather than renamed — the value is the behaviour being preserved.

Then three edits inside `Solve`, and nothing else:

- **Delete `Solver.swift:275`** (`private var axial: [Side: Double] = [:]`) and its doc comment.
- **Delete the axial block at the end of `place`**, `Solver.swift:444`–`Solver.swift:453`, from the
  comment beginning "Where this tier's planes cross the axis" through the closing brace of the
  `if nearest.map` equivalent. `place` then ends after appending to `tiers`. Its comment moves into
  `axialPoint`'s doc comment above.
- **Rewrite the two readers** to call the function against `tiers`, which at the moment either one runs
  holds exactly the tiers placed before the one being cut:
  - `Solver.swift:337` (`guard axial[Side(spec.part)] == nil else {`) becomes
    `guard axialPoint(onTheSideOf: spec.part, cutBy: tiers) == nil else {`.
  - `Solver.swift:385` (`guard let z = axial[Side(spec.part)] else {`) becomes
    `guard let point = axialPoint(onTheSideOf: spec.part, cutBy: tiers) else {`, and the line after it —
    `Solver.swift:388` (`return (x: 0, y: 0, z: z)`) — becomes `return point`.

**Do not change any thrown error, any message, or the order of the guards.**
`SolverError.secondTCPOnSide` and `.noAxialPointOnSide` are the two errors these guards raise;
`PartialSolveTests.swift:121` (`.noAxialPointOnSide(tier: "A", part: .crown),`) pins one of them and the
CLI prints both.

### 2. New: `CuttingBench/BenchGeometry/Sources/BenchGeometry/MeetPoints.swift` (pure — no framework, no I/O)

Everything the dots need, for one tier, as values a test can read. No SwiftUI: the role is returned and
the view maps it to a colour (D7).

```swift
/// Which point of a meet a dot is, and so what colour it draws in.
public enum MeetPointRole: Equatable, Sendable {
  case endpointA
  case endpointB
  case anchored
  case vertex
}

/// One named point of one tier's meet: what it reads, where it sits, and the facets it names.
public struct MeetPointDot: Identifiable, Equatable, Sendable {
  /// `A`, `B`, `M`, or the anchored point's percentage as `24.86%`.
  public var label: String
  public var role: MeetPointRole
  /// The facets this point names, in `meetText`'s own notation — `G@12 · G@24 · P1@24`, or `tcp`.
  /// Empty for the anchored point, which names none.
  public var facets: String
  /// `nil` when the point cannot be resolved: a named facet was never placed, or the three planes pin
  /// no point. The chip still shows; the viewport draws nothing.
  public var world: SIMD3<Float>?
  /// Stable across a rebuild, so a `ForEach` keeps its identity: the tier label and the role.
  public var id: String

  public init(
    label: String, role: MeetPointRole, facets: String, world: SIMD3<Float>?, id: String)
}

/// The dots for one tier's meet, in reading order.
///
/// A `fraction` gives three — **A**, the anchored point, **B** — a plain `vertex` gives one, and `size`,
/// `tcp` and `girdle` give none: they name no facet triple.
///
/// Resolved against the tiers cut *before* this one, taken as the solution's own tiers truncated to this
/// tier's position in `pattern.tiers`. A meet is a claim about the stone as it stands when that tier is
/// cut, so the finished solid is the wrong solid to measure it against.
///
/// Empty for no pattern, and for a tier label the pattern does not carry.
public func meetPointDots(ofTier tier: String, pattern: Pattern?, solid: BenchSolid) -> [MeetPointDot]
```

Rules the executor implements, in order:

1. `guard let pattern`, `guard let k = pattern.tiers.firstIndex(where: { $0.tier == tier })`, and let
   `spec = pattern.tiers[k]`. Otherwise `[]`.
2. `let before = Array((solid.solution?.tiers ?? []).prefix(k))` (D8). Build
   `placed: [String: [Int: Plane]]` from `before` by zipping each tier's `indices` with `planes(of:)` —
   the same shape as `Validation.swift:234` (`private func placedPlanes(before tier: String, of solution:
   Solution) -> [String: [Int: Plane]]`), which is private to the kernel and so is rebuilt here.
3. Switch `spec.meet`:
   - `.size`, `.tcp`, `.girdle` → `[]`.
   - `.vertex(let facets)` → one dot: `label: "M"`, `role: .vertex`,
     `facets: meetText(.vertex(facets: facets))`, `world:` the triple point, `id: "\(tier)-M"`.
   - `.fraction(let from, let percent, let to)` → three dots, in the order **A**, anchored, **B**:
     - **A**: `label: "A"`, `role: .endpointA`, `facets: meetText(from)`, `world:` resolved from `from`,
       `id: "\(tier)-A"`.
     - anchored: `label: "\(percentText(percent))%"`, `role: .anchored`, `facets: ""`,
       `world:` `a + t * (b - a)` with `t = Float(percent / 100)` and `nil` when either endpoint is
       `nil`, `id: "\(tier)-anchored"`.
     - **B**: `label: "B"`, `role: .endpointB`, `facets: meetText(to)`, `world:` resolved from `to`,
       `id: "\(tier)-B"`.
4. Resolving one endpoint's `world`:
   - `.tcp` → `axialPoint(onTheSideOf: spec.part, cutBy: before)`, mapped to `SIMD3<Float>`.
   - `.vertex(let refs)` → the three planes looked up in `placed`; `nil` unless all three are found,
     then `triplePoint` of them, which is itself `nil` for a singular triple.
   - `.size`, `.girdle`, `.fraction` → `nil`, and `facets` is `meetText` of that form. The format rejects
     these as endpoints at `Pattern.swift:45` (`var isFractionEndpoint: Bool`), so decoding never
     produces one; the branch exists because the switch has to be total and inventing a point would be
     worse than showing none.
5. **`facets` is always `meetText` of that endpoint's own meet form.** One rule, so a chip and the
   one-line `meet` cell can never spell the same triple two ways.

**One edit outside this file:** drop `private` from `TierTable.swift:113` (`private func percentText(_
value: Double) -> String`) so the anchored dot's percentage uses the same non-localised two-decimal
format the meet cell already uses. Nothing else in `TierTable.swift` changes in this task.

### 3. `CuttingBench/BenchGeometry/Sources/BenchGeometry/TierTable.swift` — the row carries its dots

One new stored property on `TierTableRow`, and one line in `tierTableRows`.

- Add after `TierTable.swift:24` (`public var wheelIsInherited: Bool`)'s group, keeping the declaration
  order the init mirrors:

  ```swift
  /// The named points of this tier's meet, in reading order. Empty for the three meet forms that name
  /// no facet triple. The cell shows these when there are any and `meet` when there are not.
  public var meetPoints: [MeetPointDot]
  ```

- Add `meetPoints: [MeetPointDot] = []` as the **last** parameter of the memberwise init at
  `TierTable.swift:35` (`public init(`), with that default, so nothing that constructs a row positionally
  has to change.
- In `tierTableRows`, after `TierTable.swift:92` (`instructions: spec.instructions ?? "",`), pass
  `meetPoints: meetPointDots(ofTier: spec.tier, pattern: pattern, solid: solid),`.

**Do not touch** `meetText`, the `meet` value, the `indices` ordering, or `TierRowState` (D21).

### 4. New: `CuttingBench/CuttingBench/MeetPointOverlay.swift`

The dots over the Metal view, and the one place a role becomes a colour.

```swift
import BenchGeometry
import SwiftUI

/// A meet point's colour. **Never the only distinction** — every dot carries its label too, so the
/// correspondence between viewport and table survives a screenshot and a colour-blind reader.
///
/// Neither the accent colour nor orange: those are the cut facets' and the picked facet's in the
/// renderer, and a meet point is neither.
func meetDotColor(_ role: MeetPointRole, warning: Bool) -> Color {
  guard !warning else { return .red }
  switch role {
  case .endpointA: return .teal
  case .endpointB: return .purple
  case .anchored, .vertex: return .yellow
  }
}

/// The selected tier's named points, as SwiftUI over the Metal view — the same mechanism and the same
/// matrices as the index ring, so a dot cannot disagree with the solid about where a point is.
///
/// **No occlusion test.** A meet is a claim about the stone as it stood when that tier was cut, so a
/// named point is routinely inside the finished solid, cut away by a later tier, or off the solid
/// altogether — and that last case is the fault worth seeing. The opacity slider is how the owner looks
/// inside.
///
/// `.allowsHitTesting(false)`, for the same reason the ring has it: the dots must not eat clicks meant
/// for the facet under them.
struct MeetPointOverlay: View {
  let dots: [MeetPointDot]
  let camera: BenchCameraState
  let warning: Bool

  var body: some View {
    GeometryReader { proxy in
      let size = proxy.size
      let aspect = size.height > 0 ? Float(size.width / size.height) : 1
      ForEach(dots) { dot in
        if let world = dot.world,
          let point = benchScreenPoint(world, aspect: aspect, camera: camera)
        {
          HStack(spacing: 3) {
            Circle()
              .fill(meetDotColor(dot.role, warning: warning))
              .frame(width: 9, height: 9)
            Text(dot.label)
              .font(.caption2.weight(.semibold))
          }
          .position(x: CGFloat(point.x) * size.width, y: CGFloat(point.y) * size.height)
        }
      }
    }
    .allowsHitTesting(false)
  }
}
```

The overlay is unconditional — with no selected tier `dots` is empty and it draws nothing, which is
cheaper to reason about than a conditional overlay and matches how the ring behaves for a bare prism.

### 5. New: `CuttingBench/BenchGeometry/Sources/BenchGeometry/Findings.swift` (pure — no framework, no I/O)

The three findings surfaces read one value, so they cannot disagree about how many findings there are.

```swift
/// One line of the findings detail.
public struct FindingsRow: Identifiable, Equatable, Sendable {
  /// The tier this row is about, or `nil` for one about the pattern as a whole.
  public var tier: String?
  public var text: String
  /// Whether the line's count includes this row. The solver's own stop sentence and the note saying the
  /// geometric checks did not run are both shown and neither is counted: neither is a `Finding`.
  public var isFinding: Bool
  /// Position-prefixed, because two rows can legitimately read alike.
  public var id: String

  public init(tier: String?, text: String, isFinding: Bool, id: String)
}

/// Everything the three surfaces read: the strip's line, the popover's rows, the tier table's marker
/// counts, and the tiers whose dots draw as a warning.
public struct FindingsReadout: Equatable, Sendable {
  public var line: String
  public var rows: [FindingsRow]
  /// Tier label to how many findings name it. A tier with none is absent.
  public var perTier: [String: Int]
  /// The tiers carrying a `vertexNotOnIntermediateSolid` finding — the one finding with geometry to show.
  public var warningTiers: Set<String>

  public init(line: String, rows: [FindingsRow], perTier: [String: Int], warningTiers: Set<String>)
}

/// The expensive half of validation, run tier by tier so it can be abandoned between tiers.
///
/// **Returns `nil` when `isCancelled` fired part-way.** A partial list is not a result and must never be
/// shown as one.
///
/// `declaredFacetCount` is deliberately `nil`: the declared count is the Facet Count card's business, and
/// counting it here would report one fault twice and restart this check on every keystroke in that field.
public func geometricFindings(
  pattern: Pattern,
  solution: Solution,
  isCancelled: () -> Bool = { false }
) -> [Finding]? {
  var findings: [Finding] = []
  for solved in solution.tiers {
    if isCancelled() { return nil }
    findings.append(contentsOf: namedPointFindings(inTier: solved.tier, of: pattern, solution))
  }
  if isCancelled() { return nil }
  findings.append(contentsOf: solidFindings(solution, declaredFacetCount: nil))
  return findings
}

/// The readout, from the pieces the store holds.
///
/// `geometric` is `nil` when the expensive half has produced no result for this solid — either because it
/// is still running, or because structural findings mean it will never run.
public func findingsReadout(
  pattern: Pattern?,
  solid: BenchSolid,
  structural: [Finding],
  geometric: [Finding]?,
  isChecking: Bool
) -> FindingsReadout

/// One finding as a sentence for a window. The CLI prints the enum's own reflection instead, on purpose,
/// so these words live here and not in the kernel.
public func findingText(_ finding: Finding) -> String

/// The tier a finding names, or `nil` for the two that are about the pattern as a whole.
public func findingTier(_ finding: Finding) -> String?
```

`findingsReadout`, in order:

1. `guard pattern != nil` else return
   `FindingsReadout(line: "No pattern open.", rows: [], perTier: [:], warningTiers: [])` — the same
   sentence `MetricsReadout.swift:60` (`private let noPatternOpen = "No pattern open."`) uses, restated
   rather than shared, because a constant private to that file is not this file's to reach into.
2. `let all = structural + (geometric ?? [])`.
3. Rows, in this order:
   - **The stop row first**, when both `solid.stoppedAtTier` and `solid.stoppedReason` are non-`nil`:
     `FindingsRow(tier: solid.stoppedAtTier, text: reason, isFinding: false, id: "stop")`. It comes first
     because it is why there are no findings for the tiers after it.
   - One row per finding in `all`, in order:
     `FindingsRow(tier: findingTier(f), text: findingText(f), isFinding: true, id: "finding-\(i)")`.
   - **The did-not-run note last**, when `geometric == nil` and `!structural.isEmpty`:
     `FindingsRow(tier: nil, text: "The geometric checks did not run: a pattern whose structure is wrong
     has no solid to measure them against.", isFinding: false, id: "notRun")`.
4. `perTier` — counts over `all` keyed by `findingTier`, skipping the `nil` keys.
5. `warningTiers` — the tiers of every `.vertexNotOnIntermediateSolid` in `all`.
6. The line, as `prefix + phrase`:
   - `prefix` is `"Stopped at tier \(tier) · "` when `solid.stoppedAtTier` is non-`nil`, else `""`.
   - `count` is `all.count`; `countText` is `"No findings"` at 0, `"1 finding"` at 1, `"\(count) findings"`
     above.
   - `phrase`, in exactly this order, which is what stops the line ever saying `No findings` about a check
     that has not run:

     ```swift
     let phrase: String
     if geometric != nil {
       phrase = isChecking ? "\(countText) · stale, checking…" : countText
     } else if !structural.isEmpty {
       phrase = countText
     } else {
       phrase = "checking…"
     }
     ```

`findingText`, all nine cases, **verbatim**:

| Case | Sentence |
|---|---|
| `.forwardReference(tier, named)` | `Tier \(tier)'s meet names tier \(named), which this pattern cuts later.` |
| `.namesOwnFacet(tier)` | `Tier \(tier)'s meet names a facet of \(tier) itself, which cannot fix its own depth.` |
| `.unknownFacet(tier, named)` | `Tier \(tier)'s meet names \(named.tier)@\(named.index), which this pattern does not cut.` |
| `.singularTriple(tier)` | `Tier \(tier)'s three named facets do not meet at a point.` |
| `.secondTCPOnSide(tier, part)` | `Tier \(tier) is a second tcp on the \(part.rawValue) side, where the axial point is already fixed.` |
| `.notExactlyOneSizeRow(count)` | `\(count) tiers carry the size meet; exactly one must.` |
| `.vertexNotOnIntermediateSolid(tier, named)` | `Tier \(tier)'s named point \(meetText(.vertex(facets: named))) is not a corner of the stone as it stands when \(tier) is cut.` |
| `.doesNotClose(tier)` — non-`nil` | `The solid does not close: tier \(tier)'s facets have an edge no other facet shares.` |
| `.doesNotClose(nil)` | `The solid does not close: it is too small to have a surface at all.` |
| `.facetCountMismatch(solved, declared)` | `The solve counts \(solved) facets; \(declared) declared.` |

The last one is unreachable from this part, because `geometricFindings` passes `declaredFacetCount: nil`.
It is written anyway: the switch has to be total, and a `default:` here would silently swallow a case the
kernel adds later.

`findingTier` returns the bound `tier` for the six that carry a `String`, the optional `tier` for
`.doesNotClose`, and `nil` for `.notExactlyOneSizeRow` and `.facetCountMismatch`.

### 6. New: `CuttingBench/CuttingBench/BenchFindingsStore.swift`

The only stateful piece. Structural findings land synchronously; the geometric half runs detached and
lands through one guarded assignment.

**The imports are scoped, and getting them wrong is a compile error the executor cannot see** — copy them
exactly. `FacetKernel` exports a public enum named `Observation`, and a type in scope shadows the module
`@Observable` expands against, which is why `BenchSolidStore.swift:7` (`import struct
FacetKernel.Pattern`) is written the way it is:

```swift
import BenchGeometry
import Observation

import enum FacetKernel.Finding
import struct FacetKernel.Pattern
import struct FacetKernel.Solution
```

```swift
/// Owns the findings. The cheap half of validation runs here and now; the expensive half runs off the
/// main thread and lands through `accept`.
///
/// **While the expensive half is in flight the previous result stays and the line marks it stale.** It is
/// cleared only when a different document is opened, because another pattern's count is not a stale
/// answer to this question — it is an answer to a different one.
@Observable @MainActor final class BenchFindingsStore {
  private(set) var structural: [Finding] = []
  /// `nil` means no geometric result for this solid: still running, or never going to run.
  private(set) var geometric: [Finding]?
  private(set) var isChecking = false

  /// Bumped per rebuild. A task that finishes after a newer one started is discarded rather than racing.
  private var generation = 0
  private var running: Task<Void, Never>?
  /// The document the current `geometric` belongs to.
  private var checkedName: String?

  /// `nonisolated`, so a `View`'s `@State` default value can construct it: a `View` struct's own
  /// initialization is not main-actor isolated even though its `body` is. Safe because every stored
  /// property has its own default and every one of their types is `Sendable`.
  nonisolated init() {}

  func rebuild(pattern: Pattern?, solid: BenchSolid) {
    running?.cancel()
    running = nil
    generation += 1
    let generation = self.generation

    if pattern?.name != checkedName {
      geometric = nil
      checkedName = pattern?.name
    }

    guard let pattern, let solution = solid.solution else {
      structural = []
      geometric = []
      isChecking = false
      return
    }

    structural = structuralFindings(pattern)
    // The kernel's own rule: a pattern whose structure is wrong has no solid to measure geometry
    // against, so the expensive half never starts and the detail says so.
    guard structural.isEmpty else {
      geometric = nil
      isChecking = false
      return
    }

    isChecking = true
    running = Task.detached(priority: .userInitiated) { [weak self] in
      let found = geometricFindings(
        pattern: pattern, solution: solution, isCancelled: { Task.isCancelled })
      await self?.accept(found, generation: generation)
    }
  }

  private func accept(_ found: [Finding]?, generation: Int) {
    guard generation == self.generation else { return }
    isChecking = false
    // A cancelled run reports nothing rather than a partial list, and leaves the previous result standing.
    guard let found else { return }
    geometric = found
  }
}
```

### 7. `CuttingBench/CuttingBench/BenchRegions.swift` — the three surfaces

Three of the five region views change. **`InspectorRegion`, `MetricsCard`, `FacetCountCard`, `EmptyCard`
and `ScrubberRegion` are not touched.**

**`ViewportRegion`** — two new lets, `meetDots: [MeetPointDot]` and `meetWarning: Bool`, and a second
overlay chained after the existing one at `BenchRegions.swift:28`
(`.overlay { IndexRingOverlay(labels: ringLabels, camera: camera) }`):

```swift
.overlay { MeetPointOverlay(dots: meetDots, camera: camera, warning: meetWarning) }
```

The meet dots go **after** the ring, so a dot near the rim draws over a number rather than under it: the
dot is about the tier you selected and the number is standing context.

**`TierTableRegion`** — two new members and three column changes:

```swift
let rows: [TierTableRow]
@Binding var selection: String?
/// The one findings value all three surfaces read, so none of them can disagree about the count.
let findings: FindingsReadout
```

- `BenchRegions.swift:49` (`Table(rows) {`) becomes `Table(rows, selection: $selection) {`. **No column
  gains a sort key** — tier order is data, and a sortable header invites reordering the one thing that
  must never be normalised. That rule is part 1's and it still holds.
- The `Tier` column gains the findings marker, after the stopped-tier symbol and before the label:

  ```swift
  if let count = findings.perTier[row.tier], count > 0 {
    Label("\(count)", systemImage: "exclamationmark.circle")
      .labelStyle(.titleAndIcon)
      .foregroundStyle(.red)
  }
  ```

  A symbol and a number, so the marking is not colour alone; and `exclamationmark.circle` rather than the
  stopped tier's `exclamationmark.triangle`, so the two states stay distinguishable on one row.
- The `Meet` column shows the chips when the row has any, and its existing text when it has none:

  ```swift
  TableColumn("Meet") { row in
    if row.meetPoints.isEmpty {
      cell(row.meet, row)
    } else {
      let warning = findings.warningTiers.contains(row.tier)
      HStack(spacing: 8) {
        ForEach(row.meetPoints) { dot in
          HStack(spacing: 3) {
            MeetDotChip(label: dot.label, colour: meetDotColor(dot.role, warning: warning))
            if !dot.facets.isEmpty { cell(dot.facets, row) }
          }
        }
      }
    }
  }
  ```

- One new private view in this file:

  ```swift
  /// A meet point's dot as it appears in the table: the same label and the same colour as the viewport's,
  /// so the two are read as one thing. Tinted fill under a solid border rather than coloured text, which
  /// keeps the label at `.primary` and readable in both appearances against every one of the four colours.
  private struct MeetDotChip: View {
    let label: String
    let colour: Color

    var body: some View {
      Text(label)
        .font(.caption2.weight(.semibold))
        .padding(.horizontal, 4)
        .padding(.vertical, 1)
        .background(Capsule().fill(colour.opacity(0.25)))
        .overlay(Capsule().strokeBorder(colour))
    }
  }
  ```

**`StatusStripRegion`** — the placeholder becomes the findings line, and the line opens the detail. Add
`let findings: FindingsReadout` and `@State private var detailShown = false`, and replace
`BenchRegions.swift:191` (`Text(solid.stoppedReason ?? "No findings")`) with:

```swift
Button {
  detailShown.toggle()
} label: {
  Text(findings.line)
}
.buttonStyle(.plain)
.disabled(findings.rows.isEmpty)
.popover(isPresented: $detailShown, arrowEdge: .top) {
  FindingsDetail(rows: findings.rows)
}
```

`arrowEdge: .top` puts the popover above the strip, which sits at the bottom of the window. `.disabled`
when there is nothing to show, so the line is inert rather than opening an empty popover.

- One more new private view in this file:

  ```swift
  /// The findings, one line each, over the strip. **Never a separate Xcode-style problems list**: it is a
  /// popover that closes when you look away, because a findings list is something you consult about the
  /// row you are on, not a panel you work from.
  ///
  /// The rows that are not findings — the solver's stop sentence, the note saying the geometric checks did
  /// not run — read secondary, so the line's count and the list agree about what was counted.
  private struct FindingsDetail: View {
    let rows: [FindingsRow]

    var body: some View {
      VStack(alignment: .leading, spacing: 6) {
        ForEach(rows) { row in
          HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(row.tier ?? "—")
              .font(.caption.weight(.semibold))
              .monospaced()
              .frame(minWidth: 28, alignment: .leading)
            Text(row.text)
              .foregroundStyle(row.isFinding ? .primary : .secondary)
          }
        }
      }
      .font(.callout)
      .padding(12)
      .frame(width: 380, alignment: .leading)
    }
  }
  ```

`solid` stays a member of `StatusStripRegion`: the `#if DEBUG` `documentSummary` at
`BenchRegions.swift:226` still reads it, and the tier-limit stepper still needs `pattern`.

### 8. `CuttingBench/CuttingBench/BenchWindow.swift` — wire it up

Two new pieces of state, one computed readout, and four call sites.

```swift
@State private var findingsStore = BenchFindingsStore()
/// The tier whose meet points are drawn, as the table's own selection. A view state and nothing more: it
/// is not persisted and nothing is edited through it.
@State private var selectedTier: String?
```

```swift
/// Recomputed per body pass rather than cached: it is string formatting over at most a few dozen findings,
/// and a cache would be a second place the count could be wrong.
private var readout: FindingsReadout {
  findingsReadout(
    pattern: document.pattern,
    solid: store.solid,
    structural: findingsStore.structural,
    geometric: findingsStore.geometric,
    isChecking: findingsStore.isChecking)
}

/// The selected tier's named points, or none when nothing is selected.
private var meetDots: [MeetPointDot] {
  guard let selectedTier else { return [] }
  return meetPointDots(ofTier: selectedTier, pattern: document.pattern, solid: store.solid)
}
```

- `ViewportRegion` at `BenchWindow.swift:33` gains
  `meetDots: meetDots,` and
  `meetWarning: selectedTier.map { readout.warningTiers.contains($0) } ?? false,`.
- `TierTableRegion` at `BenchWindow.swift:47` gains `selection: $selectedTier,` and
  `findings: readout`.
- Both `StatusStripRegion` calls — the `#if DEBUG` one at `BenchWindow.swift:52` and the release one at
  `BenchWindow.swift:58` — gain `findings: readout`.
- `rebuild()` gains one line, **after** the solid store's rebuild at `BenchWindow.swift:108`, because it
  reads the solid that call produces:

  ```swift
  findingsStore.rebuild(pattern: document.pattern, solid: store.solid)
  ```

**`selectedTier` is deliberately not cleared in `rebuild()`**, unlike the facet selection above it. A
plane index means nothing across a rebuild, which is why part 1 clears it; a tier label survives one, and
keeping it is what lets the owner step the tier limit and watch the same tier's dots move. A label the new
pattern does not carry yields no dots, because `meetPointDots` returns `[]` for an unknown tier — so a
stale selection is inert rather than wrong.

## Explicitly not doing

- **No shader change and no new vertex attribute.** Highlighting a *set* of planes in 3D would need both.
  The one finding with geometry to show resolves to a point, and a point is a SwiftUI dot (D18).
- **No editing.** No meet built by clicking a dot, no percentage typed into the anchored chip, no tier
  reordered, no `state` switched, nothing written to the document. All of that is
  `4-Cutting-Bench-Authoring` (D24).
- **No keystroke-driven timing and no per-tier cache.** Nothing is edited in this slice, so the trigger is
  opening a pattern or stepping the debug tier limit. The debounce and the cache belong to
  `4-Cutting-Bench-Authoring`, which is also where the ticket
  `Chore-Validation-Rebuilds-The-Solid-Once-Per-Tier` is closed.
- **No `Observation` channel.** `Validation.swift:29` (`public enum Observation: Sendable, Equatable`) is
  the kernel's informational channel and this part displays none of it. The exploration's U1 is about
  findings; observations gate nothing and adding them would double the strip's count with things that are
  not faults.
- **No occlusion test on the dots** (D9), and no per-triple warning colouring (D19).
- **No scrubber, no playback, no intermediate-solid display mode.** Part 4.
- **No critical-angle marking on the tier rows and no ray probe.** Part 5. The Light card stays the word
  `empty`.
- **No `swift-format` or lint configuration change**, and no edit to `design-authoring-format.md`,
  `project.pbxproj`, `Design/Prototypes/render-proof/`, or any authored pattern in `Design/Patterns/`.

## Tasks

**Every task runs these before it is done, in this order**, in place of the protocol's `Kernel`-only
gates 1 and 2:

1. `swift test --package-path Kernel --disable-sandbox` — green. (Protocol gate 1.)
2. `swift test --package-path CuttingBench/BenchGeometry --disable-sandbox` — green.
3. `xcrun swift-format lint --recursive --strict Kernel/Sources Kernel/Tests
   CuttingBench/BenchGeometry/Sources CuttingBench/BenchGeometry/Tests CuttingBench/CuttingBench` —
   clean.
4. `swift build -c release --package-path Kernel --disable-sandbox` — succeeds. (Protocol gate 3.) **Only
   T1 and T2 touch `Kernel/`; for every other task this gate does not fire.**
5. The task's own *Done when* items, verbatim.

**The executor cannot build or run the app** (D23): there is no shared scheme. Where a task changes app
code, "it compiles" is the owner's ⌘R at the owner stop, and a compile error found there is a normal
continuation of that task, not a blocker.

| # | Task | Status | Then | Commit | Note |
|---|---|---|---|---|---|
| T1 | Characterize the axial point's replacement branch | completed | continue | commit | |
| T2 | Prefactor: lift `axialPoint` out of the solve | completed | checkpoint | commit | |
| T3 | Pure: the meet-point dots | completed | continue | — | |
| T4 | The dots draw, in the table and in the viewport | completed | **owner stop** | commit + push | Material alteration: `.position` centres the view it is applied to, so the plan's `HStack` of circle-and-label put the dot half the label's width left of its point. The circle is now the positioned view and the label rides in a `.leading` overlay, outside the circle's layout. |
| T5 | Pure: the findings readout | completed | continue | — | |
| T6 | The findings line, computed off the main thread | completed | **owner stop** | commit + push | Material alteration: the plan's scoped import list for `BenchFindingsStore` omits `structuralFindings`, which is a `FacetKernel` symbol and not re-exported by `BenchGeometry`. Added `import func FacetKernel.structuralFindings` in the same scoped form. |
| T7 | The detail popover, the row marker, the warning dots | completed | **owner stop** | commit + push | Material alteration, owner-directed at the stop: `doesNotClose` now names no tier. Its pinned sentence blamed the tier the kernel found the open edge on, which on a part-cut stone is the complete tier below the incomplete girdle walls — the walls have no height yet and so are not facets of that solid at all. Both `findingText` and `findingTier` changed in `Findings.swift`, against this task's *Do not*, and T5's assertions with them. |
| T8 | Close out | completed | **owner stop** | commit + push | |

**T1 — Characterize the axial point's replacement branch**

Written before T2 touches anything. The branch at `Solver.swift:451`
(`if axial[side].map({ abs(crossing) < abs($0) }) ?? true {`) — a later tier crossing the axis nearer the
girdle replaces the earlier crossing — is not reached by any of the four authored patterns, so a refactor
that dropped the comparison would pass every existing test.

- **Files:** `Kernel/Tests/FacetKernelTests/SolverTests.swift` (edit)
- **Done when:**
  - A new test sits in the `// MARK: - The axial point` section at `SolverTests.swift:163`, after
    `testOneTCPPerSideIsAccepted`, reading exactly this:

    ```swift
    /// A later tier crossing the axis *nearer the girdle* replaces the earlier crossing. The corpus never
    /// reaches this branch, and a refactor that dropped the comparison would pass every other test.
    ///
    /// The 50% point between the girdle corner and a 45° `tcp` tier's culet lies on that tier's own plane,
    /// so with P1 alone the fraction resolves to exactly `sin(45°)`. A shallow 20° tier reaching the same
    /// girdle corner moves the pavilion's axial point up toward the girdle, and the same fraction then
    /// resolves shallower. Keeping the first crossing would give `sin(45°)` both times.
    func testANearerAxisCrossingReplacesTheEarlierOne() throws {
      let corner: Meet = .vertex(facets: [
        FacetRef(tier: "G", index: 0),
        FacetRef(tier: "G", index: 12),
        FacetRef(tier: "P1", index: 0),
      ])
      let base = [
        TierSpec(tier: "G", part: .gdl, angle: 90, indices: octagon, meet: .size),
        TierSpec(tier: "P1", part: .pav, angle: 45, indices: octagon, meet: .tcp),
      ]
      let toTheAxis = TierSpec(
        tier: "P4", part: .pav, angle: 45, indices: octagon,
        meet: .fraction(from: corner, percent: 50, to: .tcp))
      let shallow = TierSpec(tier: "P3", part: .pav, angle: 20, indices: octagon, meet: corner)

      let withoutShallow = try solve(synthetic(base + [toTheAxis]))
      let alone = try XCTUnwrap(withoutShallow.tiers.first { $0.tier == "P4" })
      XCTAssertEqual(alone.d, sin(45 * Double.pi / 180), accuracy: 1e-12)

      let withShallow = try solve(synthetic(base + [shallow, toTheAxis]))
      let replaced = try XCTUnwrap(withShallow.tiers.first { $0.tier == "P4" })
      XCTAssertLessThan(replaced.d, alone.d - 1e-6)

      // The shallow tier really does cross nearer the girdle than P1 does, which is what makes it
      // replace P1's crossing: `d / cos(angle)` is the crossing's distance from the girdle plane.
      let crossing = try XCTUnwrap(withShallow.tiers.first { $0.tier == "P3" })
      XCTAssertLessThan(crossing.d / cos(20 * Double.pi / 180), 1.0)
    }
    ```
  - `swift test --package-path Kernel --disable-sandbox` is green with it, **against the code as it stands
    today.** If it fails, stop: either the arithmetic in the doc comment is wrong or the rule is not what
    the code does, and both are the owner's call, not something to adjust the numbers around.
- **Do not:** change any source file. Do not change or delete any existing test. Do not add a helper —
  `octagon`, `synthetic` and `solve` are all already there.

**T2 — Prefactor: lift `axialPoint` out of the solve**

Behaviour-preserving. Approach §1 gives the function body and the three edits verbatim.

- **Files:** `Kernel/Sources/FacetKernel/Solver.swift` (edit),
  `Kernel/Tests/FacetKernelTests/SolverTests.swift` (edit)
- **Done when:**
  - `axialPoint(onTheSideOf:cutBy:)` exists in `Solver.swift` with the signature in D2, at file scope,
    directly after the `Side` enum.
  - `grep -c 'axial\[' Kernel/Sources/FacetKernel/Solver.swift` returns `0` — the dictionary and both of
    its readers are gone.
  - `Side` is still `private`, still named `Side`, and still has its `init(_ part: Part)`.
  - **Every existing test passes unchanged, including T1's**, and no test file line is deleted or edited.
    That is this task's real check: a prefactor that changed behaviour would show here.
  - New direct tests on the function, appended to the same `// MARK: - The axial point` section:
    - `axialPoint(onTheSideOf: .pav, cutBy: [])` is `nil`.
    - For the `G` + `P1` solve of `testNinetyDegreeGirdleTierLeavesTheAxialPointFree`,
      `axialPoint(onTheSideOf: .pav, cutBy: solution.tiers)` is `(0, 0, -1)` to `1e-12`, and
      `axialPoint(onTheSideOf: .crown, cutBy: solution.tiers)` is `nil` — the girdle tier's 90° never
      reaches the axis and the crown is untouched.
    - `.gdl` answers with the pavilion's value and `.table` with the crown's, matching `Side(_:)`.
    - For the three-tier solve in T1's test, `axialPoint(onTheSideOf: .pav, cutBy: solution.tiers)` has
      `z` of `-0.363970` to `1e-6`.
  - `swift build -c release --package-path Kernel --disable-sandbox` succeeds. (Protocol gate 3 — this
    task touches `Kernel/`.)
- **Do not:** change any `SolverError` case, its message, or the order of the two guards. Do not make
  `Side` public or rename it. Do not touch `Validation.swift`, `Metrics.swift`, `Polytope.swift`, or the
  CLI. Do not introduce a named constant for the `1e-9`: the literal is the behaviour being preserved.
  Do not add anything to `BenchGeometry` in this task.

**T3 — Pure: the meet-point dots**

All of Approach §2 and §3. No view code.

- **Files:** `CuttingBench/BenchGeometry/Sources/BenchGeometry/MeetPoints.swift` (new),
  `CuttingBench/BenchGeometry/Sources/BenchGeometry/TierTable.swift` (edit),
  `CuttingBench/BenchGeometry/Tests/BenchGeometryTests/MeetPointsTests.swift` (new),
  `CuttingBench/BenchGeometry/Tests/BenchGeometryTests/TierTableTests.swift` (edit)
- **Done when**, every case read off the corpus through `AuthoredPatterns` in `BenchSolidTests.swift`:
  - **No pattern, unknown tier:** `meetPointDots(ofTier: "P1", pattern: nil, solid: benchSolid(for: nil))`
    is empty, and so is a call naming a tier `Pattern-Easy-Octagon` does not carry.
  - **The three formless meets give nothing.** For `Pattern-Novice-Ash-er`, tiers `G` (`size`), `P1`
    (`tcp`) and `C1` (`girdle`) each give `[]`.
  - **A plain vertex gives one dot.** For `Pattern-Easy-Octagon`, tier `P2` gives one dot with
    `label == "M"`, `role == .vertex`, `facets == "G1@0 · G1@12 · P1@0"`, `id == "P2-M"`, and a non-`nil`
    `world`.
  - **That dot is the point the kernel measures.** `intermediateSolid(before: "P2", of: solution).vertices`
    contains a vertex within `1e-7` of that dot's `world`, where `solution` is the solid's own. This is the
    check that the dot is not a second, independently-derived point.
  - **A fraction gives three, in order.** For `Pattern-Novice-Ash-er`, tier `P2` gives exactly three dots
    with `label` `["A", "24.86%", "B"]`, `role` `[.endpointA, .anchored, .endpointB]`, `facets`
    `["G@12 · G@24 · P1@24", "", "tcp"]`, `id` `["P2-A", "P2-anchored", "P2-B"]`, and all three `world`
    non-`nil`.
  - **The B dot is the axial point, and it is on the right side.** For that same `P2`, `world.x` and
    `world.y` are `0` exactly and `world.z` is negative — a pavilion tier's axis point is below the girdle.
    For tier `T`, whose `part` is `table`, the **B** dot's `world.z` is **positive**: the crown has its own
    axial point and the side comes from the tier's own part.
  - **The anchored dot lies between its endpoints.** For that same `P2`, the anchored `world.z` is strictly
    between the **A** and **B** values, and its `world.x` is strictly between **B**'s `0` and **A**'s.
  - **An unresolvable point keeps its chip and loses its dot.** With
    `benchSolid(for: easyOctagon, tierLimit: 2)` and the **full** pattern, tier `C2` gives one dot whose
    `facets` is `"G1@12 · G1@24 · C1@12"` and whose `world` is `nil` — `C1` was never placed.
  - **The row carries them.** `tierTableRows` for `Pattern-Novice-Ash-er` gives `P2` a `meetPoints` of
    count 3 and `G` a `meetPoints` of count 0, **and `P2.meet` is still exactly
    `"24.86% from G@12 · G@24 · P1@24 to tcp"`** and `G.meet` still `"size"`. No existing assertion in
    `TierTableTests.swift` is changed.
- **Do not:** import SwiftUI, AppKit or Metal into `MeetPoints.swift` — it stays pure, and the colour for a
  role is the view's job. Do not change `meetText`, `TierTableRow.meet`, `TierRowState`, or the `indices`
  ordering. Do not touch any file in `CuttingBench/CuttingBench/`. Do not sort or normalise the facets a
  meet names.

**T4 — The dots draw, in the table and in the viewport**

Approach §4, §7's `ViewportRegion` and `TierTableRegion` changes, and §8's `selectedTier`, `meetDots` and
the two call sites those feed. **The status strip, the findings store and the findings readout are not in
this task.**

`TierTableRegion` needs the findings only from T7 on, so it takes **`warningTiers: Set<String>` and
`findingCounts: [String: Int]` in this task**, and T7 replaces both with the single `findings:
FindingsReadout` member Approach §7 describes. `BenchWindow` passes `warningTiers: []`,
`findingCounts: [:]` and `meetWarning: false` here — the readout does not exist until T6. Three throwaway
arguments for two tasks is the price of not making T4 wait on T5.

- **Files:** `CuttingBench/CuttingBench/MeetPointOverlay.swift` (new),
  `CuttingBench/CuttingBench/BenchRegions.swift` (edit),
  `CuttingBench/CuttingBench/BenchWindow.swift` (edit)
- **Done when:**
  - `MeetPointOverlay.swift` holds `meetDotColor(_:warning:)` and `MeetPointOverlay`, as Approach §4 gives
    them.
  - `ViewportRegion` takes `meetDots` and `meetWarning` and chains the meet overlay **after** the index-ring
    overlay.
  - `TierTableRegion` takes `@Binding var selection: String?`, `warningTiers` and `findingCounts`; its
    `Table` is `Table(rows, selection: $selection)`; its `Meet` column shows `MeetDotChip`s when
    `row.meetPoints` is non-empty and `cell(row.meet, row)` when it is not. **No column has a sort key.**
  - `BenchWindow` holds `@State private var selectedTier: String?`, the `meetDots` computed property, and
    passes all of it through. `rebuild()` does **not** clear `selectedTier`.
  - The gate commands are green and lint is clean.
- **Do not:** add the findings marker to the `Tier` column yet — that is T7. Do not touch
  `StatusStripRegion`, `InspectorRegion`, `MetricsCard`, `FacetCountCard` or `ScrubberRegion`. Do not touch
  `BenchRenderer.swift`, `Shaders.metal`, `MetalViewport.swift` or `BenchSolidStore.swift`. Do not add an
  occlusion test. Do not make a dot clickable.
- **Verification handle** — `permanent`:
  - **Where:** the tier table's **Meet** column, and the viewport above it. Open
    `Design/Patterns/Pattern-Novice-Ash-er.json`.
  - **Positive:** click the **P2** row. The Meet cell reads a teal **A** chip beside
    `G@12 · G@24 · P1@24`, then a yellow **24.86%** chip, then a purple **B** chip beside `tcp`. Three dots
    appear in the viewport carrying the same three labels in the same three colours, and the purple **B**
    sits on the stone's vertical axis below the girdle. Pull the toolbar's **Opacity** slider down to see
    the dots that are inside the stone.
  - **Negative:** click the **G** row, whose meet is `size`. The Meet cell reads the plain word `size` with
    no chip, and **every dot disappears from the viewport.** The same holds for **P1** (`tcp`) and **C1**
    (`girdle`) — three tiers that name no facet triple and so have no points.
  - **Reads:** `meetPointDots` in `MeetPoints.swift`, and through it `axialPoint` in `Solver.swift`. Delete
    `axialPoint` and the **B** dot has no position and does not draw.

**T5 — Pure: the findings readout**

All of Approach §5. No view code and no store.

- **Files:** `CuttingBench/BenchGeometry/Sources/BenchGeometry/Findings.swift` (new),
  `CuttingBench/BenchGeometry/Tests/BenchGeometryTests/FindingsTests.swift` (new)
- **Done when:**
  - **The corpus is clean.** For all four patterns in `AuthoredPatterns.all`,
    `geometricFindings(pattern: pattern, solution: solution)` returns a non-`nil`, **empty** array, where
    `solution` is `benchSolid(for: pattern).solution`. And `structuralFindings(pattern)` is empty for all
    four. This is the baseline every other case is read against.
  - **Cancellation returns `nil`, never a partial list.**
    `geometricFindings(pattern:solution:isCancelled: { true })` is `nil` for
    `Pattern-Standard-Round-Brilliant`.
  - **No pattern:** `findingsReadout(pattern: nil, solid: benchSolid(for: nil), structural: [], geometric:
    nil, isChecking: false)` gives `line == "No pattern open."` with `rows`, `perTier` and `warningTiers` all
    empty.
  - **A truncated solid does not close.** With `benchSolid(for: easyOctagon, tierLimit: 2)`,
    `geometricFindings` returns exactly one finding, a `.doesNotClose`; the readout's `line` is
    `"1 finding"`; `rows` has one entry with `isFinding == true` and `text` beginning `"The solid does not
    close"`; and `perTier` has exactly one entry, with value `1`.
  - **A stopped solve prefixes the line and leads the rows.** For the synthetic pattern
    `[TierSpec(tier: "C1", part: .crown, angle: 40, indices: [0, 12, 24, 36, 48, 60, 72, 84], meet:
    .girdle), TierSpec(tier: "G", part: .gdl, angle: 90, indices: [0, 12, 24, 36, 48, 60, 72, 84], meet:
    .size)]` — the girdle meet comes before any vertical plane, so the solve stops on the first tier:
    - `structuralFindings` is empty, and `geometricFindings` returns exactly one `.doesNotClose(tier: nil)`.
    - `line` is `"Stopped at tier C1 · 1 finding"`.
    - `rows[0]` has `tier == "C1"`, `isFinding == false`, and `text ==
      "tier C1: the girdle outline is not bounded by the vertical planes placed so far"` — the kernel's own
      sentence, verbatim.
    - `rows[1]` has `tier == nil`, `isFinding == true`, and `text == "The solid does not close: it is too
      small to have a surface at all."`
    - `perTier` is empty: neither row's finding names a tier.
  - **The grammar, each case pinned against a constructed input.** With any open pattern and
    `solid.stoppedAtTier == nil`:

    | `structural` | `geometric` | `isChecking` | `line` |
    |---|---|---|---|
    | `[]` | `nil` | `true` | `checking…` |
    | `[]` | `[]` | `true` | `No findings · stale, checking…` |
    | `[]` | one finding | `true` | `1 finding · stale, checking…` |
    | `[]` | `[]` | `false` | `No findings` |
    | `[]` | two findings | `false` | `2 findings` |
    | one finding | `nil` | `false` | `1 finding` |

  - **The did-not-run note.** In that last row's case, the readout's last row has `isFinding == false`,
    `tier == nil`, and `text == "The geometric checks did not run: a pattern whose structure is wrong has no
    solid to measure them against."`
  - **`warningTiers` picks out the one finding with geometry.** Given
    `geometric: [.vertexNotOnIntermediateSolid(tier: "P2", named: [FacetRef(tier: "G1", index: 0),
    FacetRef(tier: "G1", index: 24), FacetRef(tier: "P1", index: 0)])]`, `warningTiers == ["P2"]`,
    `perTier["P2"] == 1`, and the row's `text` is
    `"Tier P2's named point G1@0 · G1@24 · P1@0 is not a corner of the stone as it stands when P2 is cut."`
  - **`findingText` and `findingTier` are total.** One assertion per case of `Finding` — nine sentences
    against the table in Approach §5, and `findingTier` `nil` for exactly `.notExactlyOneSizeRow` and
    `.facetCountMismatch`.
- **Do not:** import SwiftUI, AppKit or Metal. Do not call `validate` — the three pieces are called
  separately on purpose. Do not pass a non-`nil` `declaredFacetCount` anywhere (D10). Do not display or
  count `Observation` values. Do not touch `MetricsReadout.swift`, `MeetPoints.swift` or any file in
  `CuttingBench/CuttingBench/`. Do not change the CLI's `printed(_:)`.

**T6 — The findings line, computed off the main thread**

Approach §6, the `StatusStripRegion` line from §7 **without the popover**, and §8's `findings` store,
`readout` property and the `rebuild()` line.

The popover, the `Tier` column marker and the warning colouring are T7. Here the line is plain `Text`, so
this task's diff is the pipeline and nothing else.

- **Files:** `CuttingBench/CuttingBench/BenchFindingsStore.swift` (new),
  `CuttingBench/CuttingBench/BenchRegions.swift` (edit),
  `CuttingBench/CuttingBench/BenchWindow.swift` (edit)
- **Done when:**
  - `BenchFindingsStore.swift` is exactly as Approach §6 gives it, imports included.
  - `StatusStripRegion` takes `let findings: FindingsReadout`, and `BenchRegions.swift:191`
    (`Text(solid.stoppedReason ?? "No findings")`) reads `Text(findings.line)`. **`solid` stays a member:**
    the `#if DEBUG` `documentSummary` still reads it.
  - `BenchWindow` holds `@State private var findingsStore = BenchFindingsStore()` and the `readout` computed
    property, passes `findings: readout` to **both** `StatusStripRegion` call sites, and calls
    `findingsStore.rebuild(pattern: document.pattern, solid: store.solid)` as the **last** line of `rebuild()`.
  - The gate commands are green and lint is clean.
- **Do not:** add the popover, the button, the `Tier` column marker, or the warning colouring — all T7. Do
  not change `TierTableRegion`'s members in this task. Do not call `validate`. Do not run the geometric half
  on the main thread, and do not `await` it inside `rebuild()`. Do not clear `geometric` when the same
  document is re-solved.
- **Verification handle** — `permanent`:
  - **Where:** the leading text of the status strip, at the bottom-left of the window, with the `#if DEBUG`
    **tiers n/m** stepper at the far right of the same strip.
  - **Positive:** open `Design/Patterns/Pattern-Easy-Octagon.json`. The strip reads **`No findings`**. Step
    the stepper down to **`tiers 2/6`**. The strip reads **`1 finding`** — the girdle and one pavilion tier
    do not bound a closed solid, which is a fault the kernel really reports. Step back to **`tiers 6/6`**
    and it returns to **`No findings`**.
  - **Negative:** with the pattern whole, type `40` into the Facet Count card's **Declared** field. That
    card reports the mismatch, and **the strip stays at `No findings`** and does not flicker through
    `checking…`. The declared count is not a finding and typing it does not restart the geometric check.
  - **Reads:** `findingsReadout` and `geometricFindings` in `Findings.swift`, driven by
    `BenchFindingsStore.rebuild`. Delete the `rebuild` call in `BenchWindow.rebuild()` and the line freezes
    at `checking…`.

**T7 — The detail popover, the row marker, the warning dots**

The rest of Approach §7 and §8. Nothing new is computed here: all three surfaces read the readout T5 and T6
already produce.

- **Files:** `CuttingBench/CuttingBench/BenchRegions.swift` (edit),
  `CuttingBench/CuttingBench/BenchWindow.swift` (edit)
- **Done when:**
  - `TierTableRegion`'s `warningTiers` and `findingCounts` members are **replaced** by the single
    `let findings: FindingsReadout`, and its two uses read `findings.warningTiers` and `findings.perTier`.
    Neither throwaway member remains anywhere.
  - The `Tier` column carries the findings marker exactly as Approach §7 gives it — after the stopped-tier
    symbol, before the label, `exclamationmark.circle` with the count.
  - `StatusStripRegion`'s `Text(findings.line)` becomes the `Button` with the `.popover` and the `.disabled`
    from Approach §7, and `FindingsDetail` exists as a private view in the same file.
  - `BenchWindow` passes `findings: readout` to `TierTableRegion`, and `meetWarning:
    selectedTier.map { readout.warningTiers.contains($0) } ?? false` to `ViewportRegion`.
  - The gate commands are green and lint is clean.
- **Do not:** touch `Findings.swift`, `MeetPoints.swift`, `BenchFindingsStore.swift`,
  `MeetPointOverlay.swift`, `BenchRenderer.swift` or `Shaders.metal`. Do not add a second selection or make
  a popover row selectable — the row marker and the tier-table selection are the only two ways in. Do not
  colour a dot per triple (D19). Do not edit any file in `Design/Patterns/`.
- **Verification handle** — `permanent`:
  - **Where:** the status-strip line, which is now a button; the tier table's **Tier** column; and the
    viewport.
  - **Positive, part one — the popover and the marker:** open
    `Design/Patterns/Pattern-Easy-Octagon.json` and step the debug stepper to **`tiers 2/6`**. The strip
    reads **`1 finding`**; click it and a popover opens above the strip with one line beginning **`The solid
    does not close`**; the tier that line names carries **`exclamationmark.circle 1`** in the Tier column.
  - **Positive, part two — the warning dot:** duplicate `Pattern-Easy-Octagon.json` **outside**
    `Design/Patterns/` (the authored file is never edited), and in the copy change tier `P2`'s meet facets
    from `G1@0, G1@12, P1@0` to **`G1@0, G1@24, P1@0`** — a triple that meets at a real point which is not a
    corner of the octagon. Open the copy with ⌘O. The strip reads at least **`1 finding`**; the popover
    contains **`Tier P2's named point G1@0 · G1@24 · P1@0 is not a corner of the stone as it stands when P2
    is cut.`**; the **P2** row carries the marker; and clicking the **P2** row draws its single **M** dot
    **red**, sitting outside the girdle outline instead of on a corner of it.
  - **Negative:** open the untouched `Design/Patterns/Pattern-Easy-Octagon.json`. The strip reads **`No
    findings`** and clicking it does nothing — the button is disabled with no rows to show. **No row carries
    `exclamationmark.circle`.** Clicking **P2** draws its **M** dot **yellow**, on a corner of the girdle
    outline. Delete the copy afterwards.
  - **Reads:** `findingsReadout`'s `rows`, `perTier` and `warningTiers` in `Findings.swift`, and
    `meetDotColor(_:warning:)` in `MeetPointOverlay.swift`. Make `warningTiers` always empty and the red dot
    goes yellow while the popover still lists the fault.

**T8 — Close out**

- **Delete the temporary handles: none.** Every handle in this plan is `permanent` — a findings line, a
  marked row, a coloured dot and a chip are all real state the app now shows. Part 1's `#if DEBUG`
  tier-limit stepper stays; part 4 retires it.
- Confirm each item in this plan's **Deferred** section has a ticket in `Design/Tickets/` with
  `Status: untriaged`, filed as it was found per the protocol. This is the check, not the filing.
- Report the untriaged ticket count in `Design/Tickets/`, one line.
- Update this plan's own `Status:` line to say **part 3 completed**, with today's date, and that nothing is
  archived: this is one part of five and the exploration `3-Cutting-Bench-Pattern-Display` stays live as the
  design source for parts 4 and 5. Mirror part 2's wording.
- `commit + push` with the message below.
- **This part archives nothing and closes no ticket.** Not this plan, not its siblings, not the exploration.
  Part 5 runs the archive routine for the whole set.

## Commit messages

Verbatim, at the commit points the task table marks. Where the work drifted from what this plan predicted,
the message given in-session wins; these are forecasts.

**After T1** — `commit`:

```
3-cutting-bench-pattern-display-3 T1: pin the nearer axis crossing

- A synthetic pattern whose shallow tier crosses the axis nearer the girdle
  than the tcp tier does, so a later fraction-to-tcp resolves against the
  replacement rather than the first crossing.
- The corpus never reaches that branch, so a refactor could drop it green.
```

**After T2** — `commit`:

```
3-cutting-bench-pattern-display-3 T2: share the axial point

- `axialPoint(onTheSideOf:cutBy:)` replaces the solve's private `axial`
  dictionary, so the solver and the display read one rule rather than two.
- Behaviour-preserving: no existing test changed.
```

**After T4** — `commit + push`:

```
3-cutting-bench-pattern-display-3 T3-T4: draw the meet points

- A tier's named points as lettered, coloured dots in the viewport and as
  chips in the meet cell, driven by the tier table's selection.
- No occlusion test: a meet is a cutting-time claim, so the points worth
  seeing are often inside the finished stone or off it altogether.
```

**After T6** — `commit + push`:

```
3-cutting-bench-pattern-display-3 T5-T6: report the findings

- The structural half runs on open; the geometric half runs detached and
  abandons between tiers, with the previous count marked stale in flight.
- The declared facet count stays the Facet Count card's, so typing there
  never restarts the expensive check.
```

**After T7** — `commit + push`:

```
3-cutting-bench-pattern-display-3 T7: open the findings to detail

- The strip line opens a popover, every tier carrying a finding is marked in
  the table, and a named point that is not a corner draws red.
```

**After T8** — `commit + push`:

```
3-cutting-bench-pattern-display-3 T8: close out part 3

- Part 3 of five. Nothing archived and no ticket closed: the exploration
  stays the design source for parts 4 and 5.
```

## Deferred

Empty at authoring. The executor appends adjacent problems it found and must not fix — and files each as a
ticket in `Design/Tickets/` immediately with `Status: untriaged`, per the protocol.
