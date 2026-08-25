# 3 · Cutting Bench Pattern Display — Part 1: Solid And Tier Table

Status: **DRAFT** — not yet approved.

## Parts

**For the owner and the next authoring session — not for the executor.** Nothing in this part's tasks
refers to another part.

1. `3-Cutting-Bench-Pattern-Display-1-Solid-And-Tier-Table` — the display solid tells the truth: the
   rough is scaffolding, dropped the moment the pattern's own planes close, and a solve that stops
   part-way names the tier that stopped it. The tier table is filled in, every column, including the
   effective wheel and each tier's instructions. ← this part
2. `3-Cutting-Bench-Pattern-Display-2-Metrics-And-Facet-Count` — the Metrics card: facet count,
   symmetry and `L/W` always visible over the full proportion table; the declared-facet-count session
   field and its `64 + 16 girdle = 80` split reporting.
3. `3-Cutting-Bench-Pattern-Display-3-Findings-And-Meet-Points` — structural findings at once,
   geometric ones deferred off the main thread and marked stale in flight; the status-strip line opens
   to detail, marks the offending tier row and highlights its geometry. Every named meet point becomes
   a lettered, coloured dot in both the viewport and the meet cell.
4. `3-Cutting-Bench-Pattern-Display-4-Playback` — the scrubber at tier and facet granularity, prefix
   intersection, one honest wait on entering playback with progress shown, and the intermediate-solid
   display mode. Retires the debug tier-limit stepper.
5. `3-Cutting-Bench-Pattern-Display-5-Light` — the critical-angle marking on pavilion tier rows, and
   the clickable single-ray probe with its per-bounce incidence readout, offered only when the
   pattern's own solid closes. Closes the exploration out and runs the archive routine.

| Exploration ID | Part |
|---|---|
| S1 | 1, 2, 4, 5 — the slice's scope statement rather than a unit of work; its done-conditions land per part. Its *shows each tier's `instructions`* clause is part 1's. |
| S2 | 5 |
| I1 | 1 |
| I2 | 1 |
| I3 | 4 — its negative requirement (**never sort `indices`**) binds part 1 and is restated here as D14 |
| I4 | 5 |
| I5 | 2 |
| U1 | 3 — its status-strip surface is introduced in part 1 for the solve failure (D8) and taken over by part 3 |
| U2 | 2 |
| U3 | 1 |
| U4 | 3 |
| U5 | 4 |
| U6 | 4 |

**No boundary has moved** — this is the first part, and the split above is the one the owner approved
on 2026-08-25. The exploration's non-goals bind every part unchanged.

## Context

The app already opens a pattern, solves it and draws it, but two things about what it draws are not yet
true, and the tier table is still seven headers over zero rows.

**The rough is always in the picture.** `BenchSolid.swift:71` (`public func benchSolid(for pattern:
Pattern?, tierLimit: Int? = nil) -> BenchSolid`) unconditionally prepends the rough prism's eighteen
half-spaces to the pattern's solved planes. Today that is harmless — every authored pattern is
`finished` and cuts the whole prism away — but the moment a pavilion is deepened the prism's `P` cap
would clip the culet of a stone that is no longer being cut from a preform. The rough has to be
scaffolding that leaves when the stone stands up on its own.

**A solve that stops part-way says nothing about why.** `BenchSolid.swift:86` (`let partial =
solveAsFarAsPossible(truncated)`) keeps `partial.solution` and drops `partial.failure` on the floor. The
tiers that placed are drawn, which is right, and the tier that stopped the solve is invisible, which is
not. Nothing new has to be computed: `Solver.swift:93` (`public var tier: String`) already gives the
tier off any `SolverError`, and `Solver.swift:66` (`public var description: String`) already gives the
sentence, each one leading with `tier <label>:`.

**The tier table is a placeholder.** `BenchRegions.swift:59` (`private let rows: [TierRow] = []`) with
`BenchRegions.swift:45` (`struct TierRow: Identifiable`), whose every field is an empty string. The
column order — Tier, Part, Angle, Indices, Meet, Wheel, Instructions — landed in part 2 of the app
shell and is not this part's to change.

Everything this part needs already exists and is public:

- **Closure is a kernel finding.** `Validation.swift:219` (`public func solidFindings(_ solution:
  Solution, declaredFacetCount: Int?) -> [Finding]`) returns `Validation.swift:24` (`case
  doesNotClose(tier: String?)`) when the facet polygons do not form a closed surface. So the
  scaffolding rule's predicate is a call, not a new algorithm, and the app can never disagree with
  `facetsolve` about whether a pattern closes.
- **Truncation is already the solver's own behaviour.** `Solver.swift:165` (`private func
  runSolve(_ pattern: Pattern, girdleTargetFraction: Double?) -> PartialSolution`) "places tiers in file
  order, stops at the first one it cannot place". Nothing has to be re-run or retried.
- **The effective gear is one call.** `Pattern.swift:130` (`public func wheel(of tier: TierSpec) -> Int`)
  is `tier.wheel ?? wheel`, and `Pattern.swift:60` (`public var wheel: Int?`) on the spec says whether
  the tier declared one.
- **A tier label is unique.** `Pattern.swift:228` (`throw PatternError.duplicateTierLabel(tier.tier)`)
  is raised at decode, so any pattern the app can hold has distinct labels — which is what lets a table
  row be identified by its label.
- **The pure-module-plus-table-test shape is established.** `IndexRing.swift` and `IndexRingTests.swift`
  in the `BenchGeometry` package are the exemplar this part's new module copies.

**No `project.pbxproj` edit is needed anywhere in this part.** The one new file lands in
`CuttingBench/BenchGeometry/Sources/BenchGeometry/`, which SwiftPM globs; nothing is added to the app
target. (The app target is a `PBXFileSystemSynchronizedRootGroup` — `project.pbxproj:30`
(`isa = PBXFileSystemSynchronizedRootGroup;`) — so even an app-side file would need no edit, but this
part adds none. **`project.pbxproj` is owner-run and a guardrail; nothing here touches it.**)

**Only one existing test's premise changes**: `BenchSolidTests.swift:76`
(`func testThePatternsPlanesStartAtEighteenAndCarryTheirOwners()`), which asserts `bench.planes.count ==
18 + solution.planes.count` for Easy Octagon — a pattern that closes, and therefore one that under the
new rule carries no rough at all. Every other check in `BenchSolidTests`, `SolidMeshTests`,
`BenchPickTests` and `IndexRingTests` reads plane indices through `solid.origin` or
`solid.polytope.facets` rather than through a hardcoded 18, and passes unchanged.

## Decisions (2026-08-25)

| # | Decision |
|---|---|
| D1 | **The rough is scaffolding, not a bounding box.** Its eighteen half-spaces enter the display intersection only while the pattern's own planes fail to bound a closed solid, and are dropped the moment they do. Otherwise a tangent-ratio rescale that deepens a pavilion would have its culet cut off by a preform that is no longer there. At closure the stone is well inside the prism and the intersection already equals the pattern's own solid, so **the transition is invisible** — nothing animates it and nothing announces it. If a later edit re-opens the solid, the rough returns. |
| D2 | **The closure test is the kernel's own**, never a second implementation: `solidFindings(partial.solution, declaredFacetCount: nil)` contains a `.doesNotClose` case. Two implementations of closure could agree with a broken one. |
| D3 | **Clipping by the rough before closure is correct, not an error, and nothing reports it.** A pavilion tier cut steeper than the prism is deep genuinely cannot be cut from that rough, so seeing the `P` cap flatten the culet is the truth rather than an artifact. |
| D4 | **`BenchSolid` gains `includesRough: Bool`,** because dropping the rough moves the pattern's plane-index base from 18 to 0 and nothing should have to infer which base it is looking at. `roughPlaneCount` stays as the count; the base is `includesRough ? roughPlaneCount : 0`. |
| D5 | **The kernel's own polytope stays rough-free** — recorded as **ADR-0004**, which is the authority and is not restated here. This part rewrites the function that holds it, so the executor reads that ADR before touching `benchSolid`, and cites it in code as `ADR-0004` rather than by any plan's decision number. |
| D6 | **The app truncates at the first tier lacking a resolvable meet rather than skipping it** — a later tier's depth genuinely depends on the earlier ones, so omitting a middle tier would make every tier after it fail on references to facets that were never placed. `solveAsFarAsPossible` already stops there; the change is that its `failure` is kept rather than discarded. **Never retry successively shorter prefixes**: that is up to one solve per tier against a hull costing roughly planes⁴. |
| D7 | **The stop is carried as two plain strings — `stoppedAtTier` and `stoppedReason` — not as a `SolverError`.** `stoppedReason` is `SolverError.description` verbatim, the kernel's own wording, so no display code invents a sentence; two strings keep `BenchSolid: Sendable` free of a kernel error type. |
| D8 | **The status strip's leading text reads `stoppedReason` when the solve stopped, and the existing `"No findings"` otherwise.** Real findings are part 3's and the executor invents no other string here. |
| D9 | **The tier table's rows come from a pure module** — `TierTable.swift` in `BenchGeometry`, with a table-style test file beside it, exactly as `IndexRing.swift` and `IndexRingTests.swift` do it. Every cell is formatted there and none in the view, so every format is testable without a window. |
| D10 | **Rows come from `pattern.tiers`, every authored tier, never from `solid.tiers`.** A tier the solve never reached is still a row the author wrote, and hiding it would hide the mistake. |
| D11 | **A row is identified by its tier label**, which decoding guarantees unique (`PatternError.duplicateTierLabel`). No `UUID`: a fresh identity per rebuild makes SwiftUI discard the table's state on every keystroke in a later part. |
| D12 | **Three row states: `solved`, `stopped`, `notReached`**, decided in that precedence. A tier the solve stopped on is by construction absent from `solid.tiers`, so the order is belt and braces rather than a real ambiguity. |
| D13 | **Cell formats, verbatim.** Part: `part.rawValue` (`pav`, `gdl`, `crown`, `table`). Angle: two decimals and a degree sign — `50.00°`. Indices: space-joined in file order. Wheel: the effective integer, bare — `96`. Instructions: the string, or empty when absent. |
| D14 | **Negative requirement: the app never sorts `indices`.** The format permits any order and the order is data: a printed sheet reads `Novice Ash-er`'s eight stops as `12 24 36 48 60 72 84 0`, and a pattern transcribed that way has to render that way. **Correction to the exploration's grounding:** all four authored patterns as they stand today store their indices *ascending*, so nothing in the corpus exercises this — the check is a constructed case (T3). The requirement belongs to part 4's decisions and binds this part's Indices cell. |
| D15 | **Meet cell text.** `size`, `tcp` and `girdle` are the bare word. A `vertex` is its three facets in the order the file lists them, joined by ` · `, each in the kernel's own notation — `G@12 · G@24 · P1@24`. A `fraction` is `24.86% from <from> to <to>`, each endpoint rendered by these same rules recursively. Percent to two decimals. The dots and letters replace this text in part 3; until then the triple must be readable as text. |
| D16 | **The Wheel column shows the *effective* gear, `.secondary` when inherited from the header and `.primary` when the tier overrides it.** A stop number is meaningless without its gear, so the wheel is what makes the Indices column legible and belongs beside it. **Never a blank cell** when inherited: that saves ink at the cost of the one piece of context the neighbouring column needs. |
| D17 | **The table is not sortable — no `TableColumn` gets a sort key.** Tier order is data, and a sortable header invites reordering the one thing that must never be normalised. |
| D18 | **The stopped row carries an `exclamationmark.triangle` before its label and rows after it read `.secondary`.** The symbol, not colour alone: the same rule that governs the meet dots in part 3, so the marking survives a screenshot and a colour-blind reader. |
| D19 | **The `#if DEBUG` tier-limit stepper stays.** Every authored pattern is `finished` and cuts the whole prism away, so the stepper is the only way to reach a rough-and-pattern solid at all — and it is what operates D1's check. Part 4's scrubber retires it. |
| D20 | **Building and running the app is the owner's action at every owner stop.** No shared `.xcscheme` exists — `xcuserdata/` is gitignored — so the executor cannot build the app target. The executor's own checks are the two package test suites and `swift-format`. |
| D21 | **Once the rough is dropped the display solid *is* the kernel's polytope** — `partial.solution.polytope`, reused rather than recomputed. Turning planes into a solid is the one expensive step in a rebuild (`intersectHalfSpaces` is roughly planes⁴, and the round brilliant has 73 of them), and with the scaffolding gone the app would be handing that function exactly the planes, in exactly the order, that the solve just handed it. So a finished pattern — every authored pattern, and the normal case — drops from two hulls per rebuild to one. The app still intersects for itself whenever the rough is in, because then the plane list is genuinely different. **The cost, stated:** `testAFinishedPatternAddsNothingToTheKernelsOwnSolid`'s two count assertions become identities and stop being evidence. Its other two — that no rough facet survives and that every surviving facet is a cut one — still bite, and T1's new `planes.count` check is real, so the test is kept rather than thinned. |

## Tickets closed by this plan

None — closed in the final part. The exploration folded no tickets in
(`Chore-Validation-Rebuilds-The-Solid-Once-Per-Tier` is answered and closed by
`4-Cutting-Bench-Authoring`, not here), so the final part archives the exploration and this plan's
siblings and nothing else.

## Prefactoring

**None needed, because both changes are additive rather than moves.** The tier table has no rows today —
`BenchRegions.swift:59` (`private let rows: [TierRow] = []`) — so its row model is new code, not code
being relocated, and there is no behaviour to preserve. And `benchSolid`'s plane-index base is a
one-expression change inside the task that changes the behaviour, with the existing `BenchSolidTests`
already pinning the current rough-and-cut arrangement from both sides: `BenchSolidTests.swift:93`
(`func testAHalfCutStoneKeepsRoughAndCut()`) for an open solid and `BenchSolidTests.swift:61`
(`func testAFinishedPatternAddsNothingToTheKernelsOwnSolid()`) for a closed one. Characterization tests
would be those two.

## Approach

Two independent changes, in two files each. `benchSolid` learns to drop the rough and to keep the
failure; a new pure module turns a `Pattern` and a `BenchSolid` into formatted table rows; the two app
views read them. **The display pass gets cheaper, not dearer.** The closure test costs no hull — it reads
`partial.solution.polytope`, which the solve already built — and once the scaffolding is gone there is no
second intersection left for the app to do, so a finished pattern goes from two hulls per rebuild to one
(D21).

### 1. `CuttingBench/BenchGeometry/Sources/BenchGeometry/BenchSolid.swift` (edit)

Three stored properties onto `BenchSolid`, after `tiers` at `:23` (`public var tiers: [SolvedTier]`),
each with a default in the memberwise `init` so the one construction site at `:100` (`return
BenchSolid(`) is the only caller that has to change:

```swift
/// Whether the rough's eighteen half-spaces are in `planes` — and so whether the pattern's own planes
/// start at `roughPlaneCount` or at `0` (D1, D4).
public var includesRough: Bool
/// The tier the partial solve stopped on, and the kernel's own sentence saying why. Both `nil` when
/// every tier placed (D6, D7).
public var stoppedAtTier: String?
public var stoppedReason: String?
```

`init` gains `includesRough: Bool = true`, `stoppedAtTier: String? = nil`, `stoppedReason: String? =
nil`, in that order and last.

`benchSolid(for:tierLimit:)` at `:71` is restructured. Its no-pattern case leaves through an early
return, and its pattern case decides the rough before it builds anything:

```swift
public func benchSolid(for pattern: Pattern?, tierLimit: Int? = nil) -> BenchSolid {
  guard var truncated = pattern else { return roughOnly() }
  if let tierLimit {
    truncated.tiers = Array(truncated.tiers.prefix(tierLimit))
  }

  let partial = solveAsFarAsPossible(truncated)

  // D1, D2: the rough is scaffolding. The kernel's own closure check decides — nothing here computes
  // closure a second time, because a second implementation could agree with a broken one.
  let isOpen = solidFindings(partial.solution, declaredFacetCount: nil).contains { finding in
    guard case .doesNotClose = finding else { return false }
    return true
  }

  var (planes, origin) = roughScaffolding(included: isOpen)
  let base = isOpen ? roughPlaneCount : 0
  for (k, plane) in partial.solution.planes.enumerated() {
    planes.append(plane)
    // A plane with no owner is impossible today. If one appears, it is left out of `origin` rather
    // than given an invented name — a missing entry is something a test can see.
    if let owner = partial.solution.planeOwner[k] {
      origin[base + k] = .cut(FacetRef(tier: owner.tier, index: owner.index))
    }
  }

  return BenchSolid(
    planes: planes,
    origin: origin,
    // D21: with the scaffolding gone, `planes` *is* `partial.solution.planes` in its own order, so the
    // kernel's polytope is already the answer and intersecting it again would be the same work twice.
    polytope: isOpen ? intersectHalfSpaces(planes) : partial.solution.polytope,
    tiers: partial.solution.tiers,
    includesRough: isOpen,
    stoppedAtTier: partial.failure?.tier,
    stoppedReason: partial.failure?.description)
}

/// The bare prism: a window has a solid before any pattern is open, and that solid is the rough alone.
private func roughOnly() -> BenchSolid {
  let (planes, origin) = roughScaffolding(included: true)
  return BenchSolid(
    planes: planes, origin: origin, polytope: intersectHalfSpaces(planes), includesRough: true)
}

/// The rough's planes and their names, or two empties once the pattern's own planes bound a solid and
/// the scaffolding has come away (D1).
private func roughScaffolding(
  included: Bool
) -> (planes: [Plane], origin: [Int: FacetOrigin]) {
  guard included else { return ([], [:]) }
  var origin: [Int: FacetOrigin] = [:]
  for (index, facet) in roughFacets().enumerated() {
    origin[index] = .rough(facet)
  }
  return (roughPlanes(), origin)
}
```

`roughPlaneCount` at `:6` keeps its current definition and its doc comment gains the base-index
caveat: it is the count, and the pattern's base only equals it while `includesRough` is true. The
`planes` property's own doc at `:17` (`Rough planes at indices 0…17, then the pattern's solved planes
from 18 up`) asserts the old base as unconditional fact and is rewritten to the conditional one.

Two behaviours to preserve exactly, both already covered by tests: a `tierLimit` of `0` leaves
`partial.solution.planes` empty, whose polytope has no vertices, so `.doesNotClose(tier: nil)` fires and
the result is the bare prism; and truncating never disturbs an earlier tier's depth, because a meet may
only name an earlier tier.

### 2. New: `CuttingBench/BenchGeometry/Sources/BenchGeometry/TierTable.swift` (pure — no SwiftUI, no I/O)

Every cell formatted here and none in the view (D9), so every format is checkable without a window.

```swift
import FacetKernel
import Foundation

/// Where a tier stands in the solve (D12).
public enum TierRowState: Equatable, Sendable {
  case solved
  /// The tier the partial solve stopped on.
  case stopped
  /// Never attempted: it sits after the stopped tier, or past the debug tier limit.
  case notReached
}

/// One row of the tier table, every cell already a string (D9, D13).
public struct TierTableRow: Identifiable, Equatable, Sendable {
  public var tier: String
  public var part: String
  public var angle: String
  public var indices: String
  public var meet: String
  public var wheel: String
  /// True when the tier declares no wheel of its own and the header's gear applies (D16).
  public var wheelIsInherited: Bool
  public var instructions: String
  public var state: TierRowState

  /// The tier label. Decoding rejects a duplicate, so it is unique across a pattern (D11).
  public var id: String { tier }

  public init(
    tier: String,
    part: String,
    angle: String,
    indices: String,
    meet: String,
    wheel: String,
    wheelIsInherited: Bool,
    instructions: String,
    state: TierRowState
  )
}

/// One row per authored tier, in file order — including the tiers the solve never reached (D10).
///
/// Empty for no pattern, which leaves the table showing its seven headers over nothing.
public func tierTableRows(pattern: Pattern?, solid: BenchSolid) -> [TierTableRow]

/// A meet as one line of text (D15). Recurses through a `fraction`'s two endpoints.
public func meetText(_ meet: Meet) -> String
```

The rules, exactly:

- **`tierTableRows`** maps `pattern.tiers` in order. `part` is `spec.part.rawValue`; `angle` is
  `String(format: "%.2f°", spec.angle)`; `indices` is `spec.indices.map(String.init).joined(separator:
  " ")` — **the file's own order, never sorted** (D14); `meet` is `meetText(spec.meet)`; `wheel` is
  `String(pattern.wheel(of: spec))`; `wheelIsInherited` is `spec.wheel == nil`; `instructions` is
  `spec.instructions ?? ""`.
- **The state**, in this precedence (D12): `.stopped` when `spec.tier == solid.stoppedAtTier`, else
  `.solved` when a `Set` of `solid.tiers.map(\.tier)` contains it, else `.notReached`.
- **`meetText`** returns `meet.kindName` for `.size`, `.tcp` and `.girdle`; for `.vertex(let facets)`,
  `facets.map { "\($0.tier)@\($0.index)" }.joined(separator: " · ")` in the file's order; for
  `.fraction(let from, let percent, let to)`, `"\(percentText(percent))% from \(meetText(from)) to
  \(meetText(to))"`.
- **`percentText`** is a `private func` using `String(format: "%.2f", value)` — non-localised, which is
  what `String(format:)` without a locale gives.

### 3. `CuttingBench/BenchGeometry/Tests/BenchGeometryTests/BenchSolidTests.swift` (edit)

One existing check's premise changes, and it is corrected rather than deleted:
`BenchSolidTests.swift:76` (`func testThePatternsPlanesStartAtEighteenAndCarryTheirOwners()`) runs on
Easy Octagon, which closes. Rename it `testAClosedPatternsPlanesStartAtZeroAndCarryTheirOwners`, drop
the `18 +` from both the count assertion and the `origin[18 + k]` lookup, and add
`XCTAssertFalse(bench.includesRough)`. **The test is corrected, never loosened** — it still pins one
`origin` entry per solved plane.

New checks in the same file:

- A closed pattern drops the rough: for each of the four authored patterns, `includesRough == false`
  and `planes.count == solve(pattern).planes.count`.
- An open one keeps it: `benchSolid(for: noviceAsher, tierLimit: 2).includesRough == true` with
  `planes.count == 18 + <its solved plane count>`, and `benchSolid(for: nil).includesRough == true`.
- The stop: a Novice Ash-er copy whose `P2` meet names a facet of a tier that does not exist gives
  `stoppedAtTier == "P2"` and `stoppedReason == "tier P2: there is no facet P9@24"`, with `tiers` holding
  only `G` and `P1`. Build it by finding `P2` with `firstIndex(where:)` — never by a hardcoded `2` — and
  assigning the same shape its file carries with one facet changed:

  ```swift
  pattern.tiers[index].meet = .fraction(
    from: .vertex(facets: [
      FacetRef(tier: "G", index: 12),
      FacetRef(tier: "G", index: 24),
      FacetRef(tier: "P9", index: 24),
    ]),
    percent: 24.862,
    to: .tcp)
  ```

  The named facets resolve in order (`Solver.swift:402` — `for facet in facets`), so the first unknown
  one wins and the sentence is deterministic.
- A whole solve leaves both stop fields `nil`, for all four patterns and for no pattern.

### 4. New: `CuttingBench/BenchGeometry/Tests/BenchGeometryTests/TierTableTests.swift`

Table-style, in the shape of `IndexRingTests.swift`, reading the corpus through the existing
`AuthoredPatterns` helper in `BenchSolidTests.swift:10` (`enum AuthoredPatterns`) — same target, so it
needs no copy. The exact expected values are in T3's *Done when*.

### 5. `CuttingBench/CuttingBench/BenchRegions.swift` (edit)

**Delete `TierRow` at `:45`** (`struct TierRow: Identifiable`) — it is a placeholder whose every field
is `""`, and `TierTableRow` replaces it.

`TierTableRegion` at `:58` takes `let rows: [TierTableRow]` instead of holding
`private let rows: [TierRow] = []`, and its seven columns become view builders in the **same order**
(D17: no column gets a sort key). A `Table` has no row-level modifier, so the two styling rules are
applied by one cell helper rather than per column:

```swift
/// Every cell reads `.secondary` on a tier the solve never reached, and the Wheel cell reads
/// `.secondary` when the gear is inherited as well (D16, D18).
private func cell(_ text: String, _ row: TierTableRow, dimmed: Bool = false) -> some View {
  Text(text).foregroundStyle(dimmed || row.state == .notReached ? .secondary : .primary)
}

Table(rows) {
  TableColumn("Tier") { row in
    HStack(spacing: 4) {
      if row.state == .stopped { Image(systemName: "exclamationmark.triangle") }
      cell(row.tier, row)
    }
  }
  TableColumn("Part") { row in cell(row.part, row) }
  TableColumn("Angle") { row in cell(row.angle, row) }
  TableColumn("Indices") { row in cell(row.indices, row) }
  TableColumn("Meet") { row in cell(row.meet, row) }
  TableColumn("Wheel") { row in cell(row.wheel, row, dimmed: row.wheelIsInherited) }
  TableColumn("Instructions") { row in cell(row.instructions, row) }
}
```

`.primary` and `.secondary` are both `HierarchicalShapeStyle`, so the ternary needs no erasure.

`StatusStripRegion` at `:104` gains nothing new to read: it already takes `solid: BenchSolid`. Its
leading `Text("No findings")` at `:115` becomes `Text(solid.stoppedReason ?? "No findings")` (D8). Inside
the existing `#if DEBUG` block, `documentSummary` at `:150` appends the two new facts, so the readout
cannot agree with a broken solid:

```swift
let rough = solid.includesRough ? "rough scaffolding" : "rough dropped"
let stopped = solid.stoppedAtTier.map { " · stopped at \($0)" } ?? ""
return "\(document) · \(counts) · \(rough)\(stopped)"
```

### 6. `CuttingBench/CuttingBench/BenchWindow.swift` (edit)

`TierTableRegion()` at `:43` becomes
`TierTableRegion(rows: tierTableRows(pattern: document.pattern, solid: store.solid))`. Computed in
`body`, not stored: it is a pure function of two values the view already holds, and both the pattern and
the solid change together through `rebuild()` at `:93`. Nothing else in this file changes.

## Explicitly not doing

- **No selection link between the table and the viewport.** Clicking a facet does not select its tier
  row and selecting a row does not highlight anything. Marking a row and highlighting its geometry
  together is U1's and U4's rule, which part 3 implements; doing half of it here would ship a pairing
  that only works in one direction.
- **No findings, no observations, no validation call.** The status strip shows the *solve* failure, which
  is a `SolverError` the app already has in hand. `validate`, `structuralFindings`, the debounce and the
  stale marking are part 3's.
- **No metrics.** The Metrics, Light and Facet Count inspector cards keep their `EmptyCard()` — part 2
  and part 5.
- **No scrubber.** `ScrubberRegion` keeps its placeholder text, and the `#if DEBUG` tier-limit stepper
  stays exactly as it is (D19). Part 4 replaces both.
- **No animation of the rough coming away.** D1's transition is invisible by construction; animating it
  would draw attention to a moment when nothing about the stone changed.
- **No sortable or reorderable table** (D17), and **no editing of any cell** — the whole of authoring is
  `4-Cutting-Bench-Authoring`.
- **No new pattern file in `Design/Patterns/`.** That folder is the corpus and the guardrail forbids
  editing the three authored fixtures; the broken pattern this part's checks need is built in memory in
  a test, and the owner's copy of it at T2 lives in `/tmp`.

## Tasks

**Every task runs these before it is done, in this order**, in place of the protocol's `Kernel`-only
gates 1 and 2 — gate 1 still applies unconditionally, and gate 3 never fires because no task here
touches `Kernel/`:

1. `swift test --package-path Kernel --disable-sandbox` — green. (Protocol gate 1.)
2. `swift test --package-path CuttingBench/BenchGeometry --disable-sandbox` — green.
3. `xcrun swift-format lint --recursive --strict Kernel/Sources Kernel/Tests
   CuttingBench/BenchGeometry/Sources CuttingBench/BenchGeometry/Tests CuttingBench/CuttingBench` —
   clean.
4. The task's own *Done when* items, verbatim.

**The executor cannot build or run the app** (D20): there is no shared scheme. Where a task changes app
code, "it compiles" is the owner's ⌘R at the owner stop, and a compile error found there is a normal
continuation of that task, not a blocker.

| # | Task | Status | Then | Commit | Note |
|---|---|---|---|---|---|
| T1 | The rough is scaffolding, and drops at closure | completed | **owner stop** | commit | |
| T2 | The tier the solve stopped on | awaiting owner | **owner stop** | commit | |
| T3 | Pure: the tier table's rows | not started | continue | — | |
| T4 | The tier table draws | not started | **owner stop** | commit | |
| T5 | Close out | not started | **owner stop** | commit + push | |

**T1 — The rough is scaffolding, and drops at closure**

- **Files:** `CuttingBench/BenchGeometry/Sources/BenchGeometry/BenchSolid.swift` (edit),
  `CuttingBench/BenchGeometry/Tests/BenchGeometryTests/BenchSolidTests.swift` (edit),
  `CuttingBench/CuttingBench/BenchRegions.swift` (edit — the `#if DEBUG` summary only)
- **Done when:**
  - `BenchSolid` carries `includesRough`, and `benchSolid` includes the rough's eighteen half-spaces only
    when `solidFindings(partial.solution, declaredFacetCount: nil)` reports `.doesNotClose`
    (Approach §1).
  - `testThePatternsPlanesStartAtEighteenAndCarryTheirOwners` is renamed
    `testAClosedPatternsPlanesStartAtZeroAndCarryTheirOwners` and asserts `origin[k]`, not
    `origin[18 + k]`, plus `XCTAssertFalse(bench.includesRough)`.
  - New: for each of the four authored patterns, `includesRough == false` and `planes.count` equals
    `try solve(pattern).planes.count`.
  - New: `benchSolid(for: noviceAsher, tierLimit: 2).includesRough == true` and its `planes.count` is
    exactly `18` more than the same call's cut-plane count; `benchSolid(for: nil).includesRough == true`
    with `planes.count == 18`.
  - New: for each of the four authored patterns the solid's `polytope` is the solve's own — same facet
    keys and the same vertex count as `try solve(pattern).polytope`, reused rather than rebuilt (D21).
    With `tierLimit: 2` the app intersects for itself, and that solid's facet keys include rough ones.
  - The four existing checks named in *Prefactoring* and in *Context* — `testAHalfCutStoneKeepsRoughAndCut`,
    `testAFinishedPatternAddsNothingToTheKernelsOwnSolid`, `testATierLimitOfZeroIsTheBarePrism`,
    `testTheRoughIsDeepEnoughForAnIntermediatePoint` — pass **unchanged**, source untouched.
  - `documentSummary` in `BenchRegions.swift` appends `· rough scaffolding` or `· rough dropped`.
  - **Every bare decision-number citation in `BenchSolid.swift` is gone**, because the file otherwise
    carries the app shell's `D1` and `D9` while this plan means different things by both. The
    rough-stays-out-of-the-solver comment at `:65` cites `ADR-0004`; the other seven — `:5`, `:9`, `:17`,
    `:22`, `:84`, `:85`, `:88` — already state their reason in prose, so the trailing `(Dn)` is simply
    dropped. No new bare `Dn` is added anywhere in the file. Scoped to this one file: the same citations
    in the rest of `CuttingBench/` are the filed chore `Chore-Decision-Numbers-Cited-In-Code`, not this
    task's.
- **Do not:** touch `stoppedAtTier`/`stoppedReason` (T2's), the tier table, `RoughPrism.swift`,
  `SolidMesh.swift`, `BenchPick.swift`, or the non-debug half of the status strip. Do not add a Settings
  toggle or a debug switch for the rule — the closure test *is* the switch, and a manual override would
  let the app draw a solid the kernel disagrees with.
- **Verification handle** — `permanent`:
  - **Where:** the status strip's trailing `#if DEBUG` text (`documentSummary`), with the tier-limit
    stepper immediately to its left.
  - **Positive:** open `Design/Patterns/Pattern-Novice-Ash-er.json`. At `tiers 7/7` the line ends
    `· rough dropped` and reads `0 rough`. Click the stepper down to `tiers 2/7`: it ends
    `· rough scaffolding`, the rough count in the same line becomes non-zero, and the prism appears
    around the two cut tiers.
  - **Negative:** step back to `tiers 7/7`. The facet count in that line must read exactly what
    `swift run --package-path Kernel --disable-sandbox facetsolve
    Design/Patterns/Pattern-Novice-Ash-er.json` prints on its `facets` row, with `0 rough`, and the
    stone must look as it did before this task — dropping eighteen planes that contributed nothing has
    to change nothing (D1).
  - **Reads:** `includesRough` in `BenchSolid.swift`, through `documentSummary` in `BenchRegions.swift`.

```
3-cutting-bench-pattern-display-1 T1: drop the rough once the pattern closes

- The rough's eighteen half-spaces enter the display intersection only while the
  pattern's own planes fail to bound a closed solid, so a deepened pavilion is no
  longer clipped by a preform that is no longer there.
- The closure test is the kernel's own `solidFindings`, never a second implementation.
```

**T2 — The tier the solve stopped on**

- **Files:** `CuttingBench/BenchGeometry/Sources/BenchGeometry/BenchSolid.swift` (edit),
  `CuttingBench/BenchGeometry/Tests/BenchGeometryTests/BenchSolidTests.swift` (edit),
  `CuttingBench/CuttingBench/BenchRegions.swift` (edit)
- **Done when:**
  - `BenchSolid` carries `stoppedAtTier` and `stoppedReason`, set from `partial.failure?.tier` and
    `partial.failure?.description` and from nothing else (D7).
  - A Novice Ash-er copy whose `P2` meet names `P9@24`, built as in Approach §3, gives
    `stoppedAtTier == "P2"`, `stoppedReason == "tier P2: there is no facet P9@24"`, and `tiers.map(\.tier)
    == ["G", "P1"]`.
  - That same solid has `includesRough == true` — two tiers do not bound a solid — which is the two
    changes meeting.
  - All four authored patterns and `benchSolid(for: nil)` leave both fields `nil`.
  - The status strip's leading text is `solid.stoppedReason ?? "No findings"`, and `documentSummary`
    appends `· stopped at <tier>` when there is one.
- **Do not:** call `validate`, `structuralFindings` or `namedPointFindings` — findings are part 3's and a
  solve failure is not a finding. Do not reword the kernel's sentence, do not prefix it, and do not add a
  disclosure control or a detail popover to the strip. Do not add a broken pattern to
  `Design/Patterns/`.
- **Verification handle** — `permanent`:
  - **Where:** the status strip's leading text, at the bottom-left of the main area.
  - **Positive:** `cp Design/Patterns/Pattern-Novice-Ash-er.json /tmp/Broken-Ash-er.json`, then in the
    copy change tier `P2`'s `meet.from.facets[2].tier` from `"P1"` to `"P9"`. Open
    `/tmp/Broken-Ash-er.json` with File ▸ Open. The strip reads
    `tier P2: there is no facet P9@24`, the `#if DEBUG` text ends `· stopped at P2`, and the viewport
    shows two tiers cut into the prism.
  - **Negative:** open `Design/Patterns/Pattern-Novice-Ash-er.json` itself. The strip reads
    `No findings` and the `#if DEBUG` text carries no `stopped at` clause at all.
  - **Reads:** `stoppedReason` and `stoppedAtTier` in `BenchSolid.swift`.

```
3-cutting-bench-pattern-display-1 T2: name the tier that stopped the solve

- `benchSolid` keeps `solveAsFarAsPossible`'s failure instead of discarding it, as
  the tier label and the kernel's own sentence.
- The status strip reads that sentence, so a half-solving pattern says why rather
  than silently drawing less.
```

**T3 — Pure: the tier table's rows**

- **Files:** `CuttingBench/BenchGeometry/Sources/BenchGeometry/TierTable.swift` (new),
  `CuttingBench/BenchGeometry/Tests/BenchGeometryTests/TierTableTests.swift` (new)
- **Done when:**
  - `TierTableRow`, `TierRowState`, `tierTableRows(pattern:solid:)` and `meetText(_:)` exist with the
    signatures and rules in Approach §2.
  - `tierTableRows(pattern: nil, solid: benchSolid(for: nil))` is empty.
  - **Novice Ash-er**, solved whole: seven rows, `map(\.tier) == ["G", "P1", "P2", "P3", "C1", "C2", "T"]`,
    every one `.solved`, every one `wheel == "96"` with `wheelIsInherited == true`, every one
    `instructions == ""`. Row `G`: `part == "gdl"`, `angle == "90.00°"`,
    `indices == "0 12 24 36 48 60 72 84"`, `meet == "size"`. Row `P2`:
    `meet == "24.86% from G@12 · G@24 · P1@24 to tcp"`. Row `C2`:
    `meet == "24.83% from G@12 · G@24 · C1@24 to tcp"`. Row `T`: `part == "table"`,
    `angle == "0.00°"`, `indices == "0"`, `meet == "33.06% from C1@12 · C1@24 · C2@12 to tcp"`.
  - **Easy Octagon**: row `P2` has `indices == "6 18 30 42 54 66 78 90"`, `angle == "43.00°"` and
    `meet == "G1@0 · G1@12 · P1@0"`; row `C1` has `meet == "girdle"`; row `P1` has `meet == "tcp"`.
  - **Rand's**: twelve rows, `map(\.tier) == ["1", "2", "3", "4", "5", "A", "B", "C", "D", "E", "F", "G"]`
    — a bare-number tier label is a label, not a number to sort.
  - **D14's constructed case:** decode Novice Ash-er, set tier `G`'s `indices` to
    `[12, 24, 36, 48, 60, 72, 84, 0]`, and the row's cell reads exactly
    `"12 24 36 48 60 72 84 0"`. Index order does not affect geometry — every facet of a tier shares one
    depth — so the same pattern still solves whole and every row is still `.solved`.
  - **D16's constructed case:** set tier `C1`'s `wheel` to `64` and that row alone has
    `wheelIsInherited == false` and `wheel == "64"`, with every other row still `96`/inherited.
  - **Instructions:** set tier `P1`'s `instructions` to `"cut to the culet, then check the point"` and
    that row's cell reads it back verbatim.
  - **The states:** `benchSolid(for: noviceAsher, tierLimit: 2)` gives `G` and `P1` `.solved` and the
    other five `.notReached`, with no row `.stopped`. The T2 broken copy gives `G` and `P1` `.solved`,
    `P2` `.stopped`, and `P3`…`T` `.notReached`.
- **Do not:** touch any file under `CuttingBench/CuttingBench/` — this task is pure and ships no UI. Do
  not import SwiftUI, AppKit or Metal into `TierTable.swift`. Do not add a column the seven headers do
  not already have, do not sort or filter the rows, and do not compute critical angles, findings or
  metrics into a row — those are parts 2, 3 and 5.

**T4 — The tier table draws**

- **Files:** `CuttingBench/CuttingBench/BenchRegions.swift` (edit),
  `CuttingBench/CuttingBench/BenchWindow.swift` (edit)
- **Done when:**
  - `TierRow` at `BenchRegions.swift:45` is deleted and `TierTableRegion` takes `rows: [TierTableRow]`,
    rendering the seven columns in their existing order through the `cell` helper in Approach §5.
  - No `TableColumn` carries a sort key or a `value:` key path (D17).
  - `BenchWindow` passes `tierTableRows(pattern: document.pattern, solid: store.solid)`, computed in
    `body`.
  - `xcrun swift-format lint --recursive --strict … CuttingBench/CuttingBench` is clean.
- **Do not:** add row selection, a context menu, drag-to-reorder, an editable cell, or a column the
  headers do not already have. Do not change the `VSplitView` layout, the `minHeight: 140` on the table,
  the inspector cards, or the scrubber placeholder. Do not touch the `#if DEBUG` stepper (D19).
- **Verification handle** — `permanent`:
  - **Where:** the tier table across the bottom of the main area.
  - **Positive:** open `Design/Patterns/Pattern-Novice-Ash-er.json`. Seven rows read `G P1 P2 P3 C1 C2 T`
    in that order; row `P2`'s Meet cell reads `24.86% from G@12 · G@24 · P1@24 to tcp`; row `T`'s Angle
    reads `0.00°` and its Indices reads `0`; every Wheel cell reads a greyed `96`. Then open
    `/tmp/Broken-Ash-er.json` from T2: row `P2` carries the warning triangle and rows `P3` through `T`
    are dimmed.
  - **Negative:** clicking each of the seven column headers must **not** reorder the rows — `G` stays
    first and `T` stays last on every click (D17). And with `Design/Patterns/Pattern-Novice-Ash-er.json`
    open, no row carries a warning triangle and no row is dimmed.
  - **Reads:** `tierTableRows` and `TierTableRow.state` in `TierTable.swift`.

```
3-cutting-bench-pattern-display-1 T3-T4: fill the tier table in

- New pure module `TierTable.swift` formats every cell from a pattern and a solid,
  with the corpus and three constructed cases pinned in `TierTableTests.swift`.
- Seven view-builder columns over those rows: the effective wheel greyed when
  inherited from the header, the stopped tier marked, the tiers past it dimmed.
- No sort keys: tier order is data, and a sortable header invites normalising it.
```

**T5 — Close out**

- **Delete the temporary handles:** none. Both handles in this part are `permanent` — the `#if DEBUG`
  document summary's `rough scaffolding`/`rough dropped` and `stopped at <tier>` clauses stay, and the
  status strip's stop sentence is shipping behaviour rather than instrumentation. The `#if DEBUG`
  tier-limit stepper stays too, by D19; part 4 retires it.
- Confirm each item in this plan's **Deferred** section has a ticket in `Design/Tickets/` with
  `Status: untriaged`.
- Report the untriaged ticket count in `Design/Tickets/`, one line. (It was **0** of four tickets when
  this plan was written — all four `Chore-` items are `open`.)
- `commit + push` with the message below.
- **Archive nothing, and close no ticket.** This is part 1 of five: the exploration
  `3-Cutting-Bench-Pattern-Display` is the design source for every part after this one and stays live,
  and this plan is archived by part 5 along with every sibling. Do not append to
  `Design/Archived/ArchivedCatalog.md`.
- Set this plan's `Status:` line to say part 1 completed, with the date. That is the only document edit
  in this task.
- **Verification handle** — `permanent`:
  - **Where:** the tier table and the status strip, over all four files in `Design/Patterns/`.
  - **Positive:** each of the four opens, draws, and fills its table — Easy Octagon 6 rows, Novice Ash-er
    7, Rand's 12, Standard Round Brilliant 7 — with the strip reading `No findings` and no row marked or
    dimmed on any of them.
  - **Negative:** `/tmp/Broken-Ash-er.json` still stops at `P2`, with the triangle on that row and the
    rows after it dimmed. A close-out that had broken the stop path would show a clean strip here.
  - **Reads:** `tierTableRows` in `TierTable.swift` and `stoppedReason` in `BenchSolid.swift`.

```
3-cutting-bench-pattern-display-1 T5: close out part 1

- The display solid drops the rough at closure and names the tier that stopped the
  solve; the tier table is filled in, every column.
- Part 1 of five: the exploration and this plan stay live for parts 2 to 5.
```

## Deferred

Empty at authoring. The executor appends adjacent problems it found and must not fix — and files each as
a ticket in `Design/Tickets/` immediately with `Status: untriaged`, per the protocol.
