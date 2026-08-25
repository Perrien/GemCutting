# 3 · Cutting Bench Pattern Display — Part 2: Metrics And Facet Count

Status: **Part 2 completed 2026-08-25.** Nothing here is archived: this is one part of five, and the
exploration `3-Cutting-Bench-Pattern-Display` stays live as the design source for parts 3, 4 and 5,
which archive this plan along with their own when the last of them closes out.

## Parts

**For the owner and the next authoring session — not for the executor.** Nothing in this part's tasks
refers to another part.

1. `3-Cutting-Bench-Pattern-Display-1-Solid-And-Tier-Table` — the display solid tells the truth: the
   rough is scaffolding, dropped the moment the pattern's own planes close, and a solve that stops
   part-way names the tier that stopped it. The tier table is filled in, every column, including the
   effective wheel and each tier's instructions. (shipped)
2. `3-Cutting-Bench-Pattern-Display-2-Metrics-And-Facet-Count` — the Metrics card: facet count,
   symmetry and `L/W` always visible over the full proportion table; the declared-facet-count session
   field and its `64 + 16 girdle = 80` split reporting. ← this part
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
| S1 | 1, 2, 4, 5 — the slice's scope statement rather than a unit of work; its done-conditions land per part. Its *every metric shown agrees with `facetsolve --json`* clause is this part's. |
| S2 | 5 |
| I1 | 1 — its rule that the kernel's own rough-free solid is what `metrics` sees binds this part and is restated here as D1 |
| I2 | 1 — its partial-solve state is what D3 gates the two measured cards on |
| I3 | 4 |
| I4 | 5 — its rule that a readout resting on the pattern's own solid is withheld with its reason stated, rather than answering about a stone that does not exist, is extended to metrics here as D3 |
| I5 | 2 |
| U1 | 3 — the status strip stays part 1's `stoppedReason`-or-`"No findings"` here (D12) |
| U2 | 2 |
| U3 | 1 |
| U4 | 3 |
| U5 | 4 |
| U6 | 4 |

**No boundary has moved.** The split is the one the owner approved on 2026-08-25 and part 1 shipped
against. The exploration's non-goals bind every part unchanged — in particular **nothing in this part
edits or saves anything**.

## Context

The inspector's five cards are in place and three of them are still the word `empty`. Two of those
three are this part's: the stone's measurements, and the one check that catches a whole tier dropped in
transcription.

**The measurements exist and nothing shows them.** `Metrics.swift:8` (`public struct Metrics: Sendable`)
carries fourteen fields — the count, the per-tier split, the rotational order and its mirror axes, the
width and length, four proportions, the girdle band and whether the culet is a point — and
`Metrics.swift:72` (`public func metrics(_ solution: Solution) -> Metrics`) computes the lot from a
solved stone. The only reader today is the `facetsolve` CLI. The app solves every pattern it opens and
then throws the measurement away.

**The transcription check exists and has never had a caller.** `Validation.swift:219` (`public func
solidFindings(_ solution: Solution, declaredFacetCount: Int?) -> [Finding]`) compares the solved facet
count against a declared one and returns `Validation.swift:226`
(`findings.append(.facetCountMismatch(solved: solved, declared: declared))`). Part 1 already calls this
function — with `declaredFacetCount: nil`, for the closure test only, at `BenchSolid.swift:110` (`let
isOpen = solidFindings(partial.solution, declaredFacetCount: nil).contains { finding in`). Nothing has
ever passed a number. That check is worth having because it caught a real fault in this project's own
corpus: `design-authoring-format.md:415` records that Rand's tier **G** (25.84, `meet C-B-C`) "was
missing entirely; with it the count is exactly the declared 53" — a whole tier dropped, on a stone that
still closed because the neighbouring facets grew to fill the gap.

**What part 1 actually landed, verified in the code:**

- `BenchSolid.swift:19` (`public struct BenchSolid: Sendable`) with `BenchSolid.swift:30` (`public var
  includesRough: Bool`), `BenchSolid.swift:36` (`public var stoppedAtTier: String?`) and
  `BenchSolid.swift:37` (`public var stoppedReason: String?`). **It does not carry the solution** —
  `BenchSolid.swift:106` (`let partial = solveAsFarAsPossible(truncated)`) solves, takes
  `partial.solution.tiers` and `partial.solution.planes`, and lets the `Solution` itself fall out of
  scope. T1 is the change that keeps it.
- The pure-module shape, as `BenchGeometry/TierTable.swift` plus `BenchGeometryTests/TierTableTests.swift`
  — `TierTable.swift:64` (`public func tierTableRows(pattern: Pattern?, solid: BenchSolid) ->
  [TierTableRow]`) formats every cell as a string outside the view, and `BenchWindow.swift:43`
  (`TierTableRegion(rows: tierTableRows(pattern: document.pattern, solid: store.solid))`) calls it from
  `body`. This part's new module copies that shape exactly.
- The two placeholder cards, in the order the app shell fixed: `BenchRegions.swift:84` (`GroupBox("Metrics")
  { EmptyCard() }`) and `BenchRegions.swift:86` (`GroupBox("Facet Count") { EmptyCard() }`), inside
  `BenchRegions.swift:78` (`struct InspectorRegion: View`), which today takes no parameters at all.
- The debug tier-limit stepper, `BenchRegions.swift:137` (`private var tierLimitStepper: some View`),
  driven by `BenchWindow.swift:22` (`@State private var tierLimit: Int?`). It is what operates this
  part's negative checks.

Everything else this part needs is already public and already correct:

- **The girdle share of the count is a lookup, not a new measure.** `Metrics.swift:11` (`public var
  facetsPerTier: [String: Int]`) is keyed by tier label, and `Solver.swift:6` (`public var part: Part`)
  on `SolvedTier` gives each label its part, with `Plane.swift:23` (`case gdl`) the one that counts.
- **The app's solve and `facetsolve`'s are the same solve.** `BenchSolid.swift:106` passes no
  `girdleTargetFraction`, and `Solver.swift:166` (`let resolved = girdleTargetFraction ??
  pattern.effectiveGirdleTargetFraction`) resolves that to the pattern's own header field — which every
  authored pattern declares. `facetsolve <file> --json` with no `--girdle` flag takes the identical
  path, so the owner's cross-check is an exact comparison rather than an approximate one.
- **A partial solve is safe to measure and dishonest to show.** `metrics()` on a solution with no
  vertices divides by a zero width rather than trapping — `Metrics.swift:92` (`lengthOverWidth:
  outline.length / outline.width`) — so the risk is a plausible number, not a crash. The exploration
  measured what those numbers describe: a pattern's own planes render a floating pavilion cone until
  something caps the solid, so its crown height, `T/W` and culet are the cone's and not the stone's.
  D3 is the gate that keeps them off the screen.

## Decisions (2026-08-25)

| # | Decision |
|---|---|
| D1 | **Metrics measure the kernel's own rough-free solid, never the display solid.** That is part 1's rule and **ADR-0004** is its authority — read that ADR, cite it in code as `ADR-0004`, and never by any plan's decision number. A rough-capped solid always closes and always fills the prism, so measuring the display solid would report the preform's width on every unfinished stone. `metrics()` takes a `Solution`, and the solution `benchSolid` already computed is the one to measure. |
| D2 | **`BenchSolid` gains `solution: Solution?`** — the solve's own result, `nil` only when there is no pattern. Today `benchSolid` computes it and drops it, and re-solving to measure would pay the whole solve twice per rebuild. `Solution` is `Sendable` (`Solver.swift:25`), so `BenchSolid` stays `Sendable`. It goes last in the memberwise init with a `nil` default, so the two existing construction sites keep compiling. |
| D3 | **The Metrics card and the Facet Count card show figures only when the solve placed every tier the pattern declares.** Otherwise each reads one sentence saying why it has not, and no number. Three reasons, and they agree: `facetsolve` computes metrics only for a whole solve and emits `metrics: null` otherwise (`main.swift:245`), so a figure shown here on a partial solve has nothing to be checked against; a partial solve's own planes render a floating pavilion cone, so its crown height, `T/W` and culet describe that cone; and this is the exploration's own rule for the ray probe — withheld with the reason stated rather than answering authoritatively about a stone that does not exist. |
| D4 | **The availability predicate, verbatim:** a pattern is open, **and** `solid.stoppedAtTier == nil`, **and** `solid.solution?.tiers.count == pattern.tiers.count`. The third conjunct is not redundant — it is what makes the debug tier-limit stepper turn both cards off, because a truncated solve reaches every tier it was handed and is still measuring a preform. **One function computes it and both cards call it**, so they can never disagree about whether there is a stone to measure. |
| D5 | **The unavailable sentences, verbatim.** No pattern open: `No pattern open.` Solve stopped: `Metrics need every tier: the solve stopped at tier G1.` — the tier's own label. Placed short of the pattern's count without a stop, which is the stepper: `Metrics need every tier: 3 of 6 placed.` The executor writes no fourth sentence. |
| D6 | **One card, always-visible trio on top, proportion table below, no extra disclosure group.** Order: facets, symmetry, `L/W`; a `Divider()`; then `P/W`, `C/W`, `H/W`, `T/W`, girdle, width, length, culet. The trio is what moves while authoring and gets glanced at constantly; the table is what you read when a tier lands. **No `DisclosureGroup`**: the collapsing this rests on is the inspector's own, which already exists, and a second collapse inside a card that is already collapsible is a control the owner has to think about. |
| D7 | **Metrics stay in the Metrics card and never join the Pattern header card.** Everything in the header card is authored and editable; every metric is computed and read-only — `Metrics.swift:3` is explicit that none of it is read from a pattern's `notes` — and sharing a card would make computed values read as fields. |
| D8 | **Every format matches `facetsolve`'s own precision**, so the owner's cross-check against `facetsolve --json` is a comparison of identical figures rather than a judgement about rounding. The table is in the Approach section and is verbatim. Non-localised `String(format:)` throughout, exactly as `TierTable.swift:114` (`String(format: "%.2f", value)`) does it. |
| D9 | **The facet count is always reported split, `57 + 16 girdle = 73`, by one formatter used in both cards.** Sheets differ on whether the headline figure includes the girdle band — this project's own round brilliant declares "57 facets plus 16 on the girdle = 73" — while `Metrics.swift:86` (`facetCount: solution.polytope.facets.count`) counts every facet the solid has. A bare `73` against a sheet that prints `57` reads as a mismatch when it is agreement. The girdle share is the sum of `facetsPerTier` over the tiers of `solution.tiers` whose `part` is `.gdl` — from the solution, so the labels and the parts come from one place. **One function, so the two cards cannot format it two ways.** |
| D10 | **A knife-edge girdle collapses the expression to the bare total.** Zero girdle facets means the girdle term is omitted entirely — `73`, never `73 + 0 girdle = 73`. All four authored patterns declare a `gdl` tier, so nothing in the corpus exercises the collapse and the check is a constructed case (T2). |
| D11 | **The declared facet count is session state and persists nowhere.** A `@State private var declaredFacets = ""` on `BenchWindow`, empty on every open, never written to the document and never restored. The value exists only while transcribing from a printed sheet: a pattern invented from scratch has no declared count, and once a pattern is verified the check never fires again — a permanent header field would carry a one-time claim forever. **Negative requirement: nothing in this part writes to `PatternDocument` or to any file.** |
| D12 | **The check is the kernel's own, never a second comparison.** Call `solidFindings(solution, declaredFacetCount:)` and look for `.facetCountMismatch(solved:declared:)` (`Validation.swift:226`). This is part 1's rule for the closure test applied again: two implementations of one check can agree with a broken one. **No kernel change is needed** — the parameter has been there and unused since the kernel was written. |
| D13 | **The Facet Count card's three lines, verbatim.** Line 1, the solved count in D9's split form. Line 2, the field. Line 3, the verdict: field empty → `No count declared.`; field non-empty and not a positive integer → `Not a facet count.`; the kernel returns no `.facetCountMismatch` → `Matches the declared 73.`; it returns one → `Declared 57 · solved 57 + 16 girdle = 73.` **The mismatch line repeats the split deliberately** — that is the whole reason the split exists, and it is what lets the owner tell a girdle-inclusion difference from a dropped tier at a glance. |
| D14 | **`facetCountMismatch` does not reach the status strip in this part.** Findings presentation — a one-line strip that opens to detail and marks the offending tier row — is part 3's, and part 1 fixed the strip's leading text as `stoppedReason` when the solve stopped and the string `"No findings"` otherwise. The executor invents no other string there and does not touch `StatusStripRegion`. |
| D15 | **Both readouts come from one pure module** — `MetricsReadout.swift` in `BenchGeometry`, with a table-style test file beside it, exactly as `IndexRing.swift`/`IndexRingTests.swift` and part 1's `TierTable.swift`/`TierTableTests.swift` do it. Every string is formatted there and none in the view, so every format is checkable without a window. |
| D16 | **The readouts are called from `body`, and are not cached in `BenchSolidStore`.** `tierTableRows(pattern:solid:)` is already called that way at `BenchWindow.swift:43`, and this follows it. `metrics()` is arithmetic over facets the hull has already produced — the mirror-axis scan is about `wheel / 2 × facets` set lookups, roughly 6,700 for the round brilliant — against `intersectHalfSpaces` at roughly planes⁴, so caching it would add a second source of truth to save nothing measurable. **It must not mutate observable state:** part 1's rule that the store is driven from `.onChange` and never from `body` stands unchanged. |
| D17 | **The `#if DEBUG` tier-limit stepper stays**, untouched. Every authored pattern is `finished` and solves whole, so the stepper is the only way to reach a partial solve at all — and it is what operates D3's gate at both owner stops. Part 4's scrubber retires it. |
| D18 | **Building and running the app is the owner's action at every owner stop.** No shared `.xcscheme` exists — `xcuserdata/` is gitignored — so the executor cannot build the app target. The executor's own checks are the two package test suites and `swift-format`. |

## Tickets closed by this plan

None — closed in the final part. The exploration folded no tickets in, so the final part archives the
exploration and this plan's siblings and nothing else.

## Prefactoring

**Two tasks, and both are additive rather than moves, so neither needs a characterization test written
for it.**

- **T1 is the prefactor** — `BenchSolid` carrying the solution is a pure widening of a value type with
  nothing reading the new field yet, so its check is the inverted one: **every existing test in both
  suites passes unchanged.** The behaviour already under test is pinned from both sides by
  `BenchSolidTests.swift:107` (`func testAClosedPatternsSolidIsTheSolvesOwnPolytope()`) for a closed
  solid and `BenchSolidTests.swift:118` (`func testAnOpenPatternKeepsTheRoughAsScaffolding()`) for an
  open one, and T1 must move neither.
- **Nothing else is being moved.** Both cards read `empty` today — `BenchRegions.swift:84` and
  `BenchRegions.swift:86` — so their contents are new code, not relocated code, and there is no
  behaviour to preserve. `InspectorRegion` gaining parameters is a signature it does not have yet
  rather than one being changed.

## Approach

Four files. The solve's own `Solution` stops being thrown away; a new pure module turns it into strings;
the two placeholder cards render those strings; the window passes the pattern, the solid and one session
field into the inspector.

### 1. `CuttingBench/BenchGeometry/Sources/BenchGeometry/BenchSolid.swift` (edit)

One stored property and one assignment. Nothing else in this file changes — not the scaffolding rule,
not the plane-index base, not the polytope reuse.

Add to the struct, directly after `BenchSolid.swift:30` (`public var includesRough: Bool`):

```swift
  /// The solve's own result, as `metrics` and `validate` see it: **the pattern's own planes, rough-free,
  /// whatever `includesRough` says about what is drawn** (ADR-0004). `nil` only when there is no pattern,
  /// because then there was no solve. Kept rather than recomputed — a second solve per rebuild would pay
  /// for the one expensive step twice.
  public var solution: Solution?
```

Add the parameter to the memberwise init **last, with a `nil` default**, and assign it. Last and
defaulted so that `BenchSolid.swift:145` (`return BenchSolid(`), the bare-prism path, needs no argument
at all.

At `BenchSolid.swift:126` (`return BenchSolid(`), the pattern path, pass `solution: partial.solution`.
That is the same value the two lines above it already read `tiers` and `polytope` out of, so there is
nothing new to compute and no second solve.

**Do not** give the bare-prism path an empty `Solution`. `nil` is *there was no solve*, and an empty
solution measures to a zero width and a `NaN` `L/W` — a value that looks like an answer.

### 2. New: `CuttingBench/BenchGeometry/Sources/BenchGeometry/MetricsReadout.swift` (pure — no SwiftUI, no I/O)

`import FacetKernel` and `import Foundation`, nothing more. The full contents, in order:

```swift
/// One label-and-value row of the proportion table.
public struct MetricsRow: Identifiable, Equatable, Sendable {
  public var label: String
  public var value: String

  /// The label is unique within the table, which is what lets a `ForEach` keep its identity across a
  /// rebuild without a fresh `UUID` per pass.
  public var id: String { label }

  public init(label: String, value: String)
}

/// The Metrics card's contents, every value already a string.
public struct MetricsSummary: Equatable, Sendable {
  /// The count in the split form, `57 + 16 girdle = 73`.
  public var facets: String
  public var symmetry: String
  public var lengthOverWidth: String
  /// `P/W`, `C/W`, `H/W`, `T/W`, girdle, width, length, culet — in that order, which is the order they
  /// are read in.
  public var proportions: [MetricsRow]

  public init(facets: String, symmetry: String, lengthOverWidth: String, proportions: [MetricsRow])
}

/// Whether there is a measured stone to report, or the sentence saying why there is not.
public enum MetricsReadout: Equatable, Sendable {
  case unavailable(String)
  case measured(MetricsSummary)
}

/// The Facet Count card's contents.
public struct FacetCountCheck: Equatable, Sendable {
  /// The solved count in the split form, or `nil` when there is nothing measurable to count — then
  /// `verdict` is the reason.
  public var solved: String?
  public var verdict: String

  public init(solved: String?, verdict: String)
}

/// Why neither measured card has figures to show, or `nil` when the solve placed every tier the pattern
/// declares.
///
/// **One predicate for both cards**, so they can never disagree about whether there is a stone to
/// measure. A partial solve is a normal authoring state and its measurements are the floating pavilion
/// cone's rather than the stone's, so the honest answer is the reason and no number.
public func unmeasurableReason(pattern: Pattern?, solid: BenchSolid) -> String?

/// The facet count in the split form a printed sheet uses.
///
/// Sheets differ on whether the headline figure counts the girdle band, so a bare total reads as a
/// mismatch against a sheet that prints only the crown-and-pavilion figure. The girdle share is the
/// facets belonging to tiers whose `part` is `.gdl`. **A knife-edge girdle has no girdle facets, so the
/// term is omitted rather than shown as zero.**
public func splitFacetCount(_ measured: Metrics, tiers: [SolvedTier]) -> String

public func metricsReadout(pattern: Pattern?, solid: BenchSolid) -> MetricsReadout

/// `declared` is the field's raw text, so parsing it is this function's job and not the view's.
public func facetCountCheck(pattern: Pattern?, solid: BenchSolid, declared: String) -> FacetCountCheck
```

**`unmeasurableReason` — the rules, in this order:**

1. `pattern == nil` or `solid.solution == nil` → `"No pattern open."`
2. `solid.stoppedAtTier` is some `label` → `"Metrics need every tier: the solve stopped at tier \(label)."`
3. `solution.tiers.count != pattern.tiers.count` →
   `"Metrics need every tier: \(solution.tiers.count) of \(pattern.tiers.count) placed."`
4. Otherwise `nil`.

Rule 2 before rule 3: a stopped solve also fails rule 3, and the tier's label is the more useful of the
two sentences.

**`splitFacetCount` — the rule:**

```swift
let girdle = tiers
  .filter { $0.part == .gdl }
  .reduce(0) { $0 + (measured.facetsPerTier[$1.tier] ?? 0) }
guard girdle > 0 else { return String(measured.facetCount) }
return "\(measured.facetCount - girdle) + \(girdle) girdle = \(measured.facetCount)"
```

`tiers` is `solution.tiers`, never `pattern.tiers` — `facetsPerTier` is keyed by the solution's own tier
labels, so taking the parts from the same place is what stops the two ever falling out of step. A tier
cut entirely away is present in `facetsPerTier` at zero and contributes nothing, which is correct.

**`metricsReadout` — the rule:** `unmeasurableReason` first, and return `.unavailable(reason)` on any
reason. Otherwise `metrics(solution)` once, and build a `MetricsSummary` with these formats. **The
formats are verbatim, and every one matches `facetsolve`'s own so the owner's cross-check compares
identical figures:**

| Field | Expression | Example |
|---|---|---|
| `facets` | `splitFacetCount(measured, tiers: solution.tiers)` | `57 + 16 girdle = 73` |
| `symmetry` | `"\(measured.rotationalOrder)-fold"` then, if `mirrorAxes` is empty, `", no mirror axis"`, else `", mirrors at "` + the axes as decimals joined by one space | `4-fold, mirrors at 6 18 30 42` |
| `lengthOverWidth` | `String(format: "%.5f", measured.lengthOverWidth)` | `1.00000` |
| `P/W` | `String(format: "%.3f", measured.pavilionDepthFractionOfWidth)` | `0.466` |
| `C/W` | `String(format: "%.3f", measured.crownHeightFractionOfWidth)` | `0.162` |
| `H/W` | `String(format: "%.3f", measured.totalDepthFractionOfWidth)` | `0.648` |
| `T/W` | `String(format: "%.3f", measured.tableFractionOfWidth)` | `0.516` |
| `Girdle` | `String(format: "%.6f (%.3f%% of width)", measured.girdleThicknessNormalised, measured.girdleFractionOfWidth * 100)` | `0.067400 (3.370% of width)` |
| `Width` | `String(format: "%.6f", measured.widthNormalised)` | `2.000000` |
| `Length` | `String(format: "%.6f", measured.lengthNormalised)` | `2.000000` |
| `Culet` | `measured.culetIsPoint ? "point" : "facet"` | `point` |

The row labels are exactly the left column above — `P/W`, `C/W`, `H/W`, `T/W`, `Girdle`, `Width`,
`Length`, `Culet` — and in that order. The `C/W` and `H/W` examples are illustrative of the format only;
the ones with a source behind them are Easy Octagon's girdle, width, length and `L/W`
(`MetricsTests.swift:35` (`girdleThickness: 0.067400,`) and its neighbours) and the round brilliant's
`P/W 0.466` and `T/W 0.516` (`RoundBrilliantTests.swift:143`).

**`facetCountCheck` — the rule:**

1. `unmeasurableReason` first → `FacetCountCheck(solved: nil, verdict: reason)`.
2. Otherwise `let split = splitFacetCount(measured, tiers: solution.tiers)`, and `solved` is always
   `split` from here on. The verdict:
   - `declared` trimmed of whitespace is empty → `"No count declared."`
   - it does not parse as an `Int`, or parses to zero or less → `"Not a facet count."`
   - it parses to `n`, and `solidFindings(solution, declaredFacetCount: n)` contains no
     `.facetCountMismatch` → `"Matches the declared \(n)."`
   - it contains one → `"Declared \(n) · solved \(split)."`

**`solidFindings` also returns `.doesNotClose`, and this function ignores every case but
`.facetCountMismatch`.** Closure is part 1's business and part 3's; matching on the one case is what
keeps it that way.

**Do not** compare `n` against `measured.facetCount` directly. The kernel's comparison is the check
(D12), and a second one here could agree with a broken one.

### 3. New: `CuttingBench/BenchGeometry/Tests/BenchGeometryTests/MetricsReadoutTests.swift`

`XCTest`, `@testable import BenchGeometry`, and the file-scope `AuthoredPatterns` helper that
`BenchSolidTests.swift:10` (`enum AuthoredPatterns`) already declares for this target — it reads
`Design/Patterns/` directly, so there is one corpus and no copy to drift. Qualify `FacetKernel.Pattern`
throughout, for the reason `BenchSolidTests.swift:32` gives: XCTest pulls in ApplicationServices, whose
`Quickdraw.h` declares its own `Pattern`.

Table-style, exactly as `TierTableTests.swift` is. The cases are enumerated in T2 and T3.

### 4. `CuttingBench/CuttingBench/BenchRegions.swift` (edit)

`InspectorRegion` gains three parameters and two of its five cards gain contents. **The five cards keep
their order** — `Pattern`, `Notes`, `Metrics`, `Light`, `Facet Count` — which the app shell fixed and is
not this part's to change.

Replace `BenchRegions.swift:78` (`struct InspectorRegion: View`) through its closing brace with a version
taking:

```swift
  let pattern: FacetKernel.Pattern?
  let solid: BenchSolid
  /// The declared facet count as typed, session-only: it is never read from or written to the document
  /// (D11).
  @Binding var declaredFacets: String
```

`GroupBox("Metrics")` gets a new `MetricsCard(readout:)` subview; `GroupBox("Facet Count")` gets a new
`FacetCountCard(check:declaredFacets:)`. `GroupBox("Pattern")`, `GroupBox("Notes")` and
`GroupBox("Light")` keep `EmptyCard()`, and `EmptyCard` itself is not touched.

**`MetricsCard`** — one `VStack(alignment: .leading, spacing: 6)`:

- `.unavailable(let reason)` → `Text(reason).font(.callout).foregroundStyle(.secondary)`, and nothing
  else. **No stale numbers behind it and no dimmed table**: an unavailable card shows no figures at all.
- `.measured(let summary)` → three `LabeledContent` rows in D6's order (`Facets`, `Symmetry`, `L/W`),
  then `Divider()`, then `ForEach(summary.proportions) { LabeledContent($0.label, value: $0.value) }`.

Use `LabeledContent(_:value:)` for every row, in both halves of the card and in the Facet Count card, so
the label-and-value alignment is the platform's and not hand-built. Values are `.monospacedDigit()` so a
figure changing width does not shift the column.

**`FacetCountCard`** — one `VStack(alignment: .leading, spacing: 6)`, three lines in D13's order:

- `check.solved` is some `split` → `LabeledContent("Solved", value: split).monospacedDigit()`. `nil` →
  this line is omitted.
- `TextField("Declared", text: $declaredFacets)` with `.textFieldStyle(.roundedBorder)`.
- `Text(check.verdict).font(.callout).foregroundStyle(.secondary)`.

**Do not** add a Settings toggle, a stepper, a formatter or a numeric `TextField` binding. The field is
free text and `facetCountCheck` parses it — that is what lets a half-typed `5` say `Not a facet count.`
rather than silently becoming a number the owner did not mean.

**Do not** touch `StatusStripRegion`, `TierTableRegion`, `ViewportRegion` or `ScrubberRegion` in this
file. In particular the strip's `Text(solid.stoppedReason ?? "No findings")` at
`BenchRegions.swift:117` stays exactly as it is (D14).

### 5. `CuttingBench/CuttingBench/BenchWindow.swift` (edit)

Two changes, both small.

Add beside the other session state, after `BenchWindow.swift:19` (`@State private var selectedFacetLabel:
String?`):

```swift
  /// The count a printed sheet declares, typed at transcription time. Session state, never persisted: a
  /// pattern invented from scratch has no declared count, and a permanent header field would carry a
  /// one-time claim forever (D11).
  @State private var declaredFacets = ""
```

At `BenchWindow.swift:62` (`InspectorRegion()`), pass the three arguments:

```swift
      InspectorRegion(
        pattern: document.pattern,
        solid: store.solid,
        declaredFacets: $declaredFacets)
        .inspectorColumnWidth(min: 260, ideal: 300, max: 420)
```

**Do not** clear `declaredFacets` in `rebuild()`. The selection is cleared there because a plane index
means nothing across a rebuild; a declared count is the owner's typing about the sheet in front of them
and survives every stepper nudge, which is exactly what makes the stepper a usable negative check.

**Do not** compute `metricsReadout` or `facetCountCheck` here. They are called inside `InspectorRegion`'s
`body`, from the parameters it was handed — the same shape as `tierTableRows` at `BenchWindow.swift:43`,
and it keeps the window free of readout logic.

## Explicitly not doing

- **No findings in the status strip, and no findings list.** The strip's one line, opening to detail with
  the offending tier row marked, is part 3's (D14). The mismatch this part computes lives in its own card.
- **No editing, no saving, no `Settings` and no persistence of any kind.** The declared count is session
  state by decision (D11) and the exploration's non-goal on editing binds every part.
- **No critical-angle marking and no ray probe.** Both are light readouts and both are part 5's; the
  `Light` card stays `EmptyCard()`.
- **No meet dots and no highlighting.** Part 3's.
- **No change to `Metrics` or to `Validation` in `Kernel/`.** Every field this part shows and the check it
  runs are already there; `declaredFacetCount` has simply never had a caller. A task that finds itself
  wanting a kernel change has hit a stop rule.
- **No yield or rough-retention readout, no volume, no millimetres.** Carried forward from the
  exploration's non-goals unchanged. Every length here is in `size` units and every ratio is against the
  width, as `Metrics.swift:7` states.

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

**The executor cannot build or run the app** (D18): there is no shared scheme. Where a task changes app
code, "it compiles" is the owner's ⌘R at the owner stop, and a compile error found there is a normal
continuation of that task, not a blocker.

| # | Task | Status | Then | Commit | Note |
|---|---|---|---|---|---|
| T1 | `BenchSolid` keeps the solve's own solution | completed | continue | — | |
| T2 | Pure: the split count and the metrics readout | completed | continue | — | |
| T3 | Pure: the declared-count check | completed | checkpoint | commit | |
| T4 | The Metrics card draws | completed | **owner stop** | commit | Material alteration: the new doc comments state each reason in words rather than carrying the plan's `(D11)`-style tag, which `CLAUDE.md` forbids in code. `Chore-Decision-Numbers-Cited-In-Code` already covers the pre-existing ones. |
| T5 | The Facet Count card draws | completed | **owner stop** | commit | |
| T6 | Close out | awaiting owner | **owner stop** | commit + push | |

**T1 — `BenchSolid` keeps the solve's own solution**

The prefactor. Behaviour-preserving by construction: a new stored property that nothing reads yet.

- **Files:** `CuttingBench/BenchGeometry/Sources/BenchGeometry/BenchSolid.swift` (edit),
  `CuttingBench/BenchGeometry/Tests/BenchGeometryTests/BenchSolidTests.swift` (edit)
- **Done when:**
  - `BenchSolid` has `public var solution: Solution?`, and the memberwise init takes it last with a
    default of `nil`.
  - The pattern path at `BenchSolid.swift:126` (`return BenchSolid(`) passes
    `solution: partial.solution`; the bare-prism path at `BenchSolid.swift:145` passes no `solution`
    argument at all.
  - A new test asserts that for `Pattern-Standard-Round-Brilliant` the solid's `solution` is non-`nil`
    and its `polytope.facets.count` is `73`, and that `solution?.tiers.count` is `7`.
  - A new test asserts that `benchSolid(for: nil).solution` is `nil`.
  - A new test asserts that with `tierLimit: 3` on `Pattern-Standard-Round-Brilliant` the solid's
    `solution?.tiers.count` is `3` while the pattern's own `tiers.count` is `7` — which is the state D4's
    third conjunct exists to catch.
  - **Every pre-existing test in both suites passes unchanged**, `BenchSolidTests.swift:107` and
    `BenchSolidTests.swift:118` in particular. This is the inverted check: nothing should have moved.
- **Do not:** change the scaffolding predicate, the plane-index base, `includesRough`, the polytope reuse
  at `BenchSolid.swift:131`, or any existing assertion. Do not give the bare-prism path a synthesised
  empty `Solution`.

**T2 — Pure: the split count and the metrics readout**

- **Files:** `CuttingBench/BenchGeometry/Sources/BenchGeometry/MetricsReadout.swift` (new),
  `CuttingBench/BenchGeometry/Tests/BenchGeometryTests/MetricsReadoutTests.swift` (new)
- **Done when:**
  - `MetricsRow`, `MetricsSummary`, `MetricsReadout`, `unmeasurableReason`, `splitFacetCount` and
    `metricsReadout` exist with the signatures and doc comments in Approach §2. `FacetCountCheck` and
    `facetCountCheck` may be stubbed to compile or left to T3 — the file need not be complete until T3.
  - `unmeasurableReason` returns `nil` for each of the four authored patterns at no tier limit, and
    exactly D5's three sentences for: no pattern; a pattern whose solve stops; and
    `Pattern-Standard-Round-Brilliant` at `tierLimit: 3`, where it reads
    `Metrics need every tier: 3 of 7 placed.`
  - `splitFacetCount` gives `57 + 16 girdle = 73` for `Pattern-Standard-Round-Brilliant` and
    `29 + 8 girdle = 37` for `Pattern-Easy-Octagon`.
  - **The knife-edge case, constructed:** a pattern with no `gdl` tier — or an authored pattern with its
    `gdl` tier's `facetsPerTier` entry absent from the map handed in — yields the bare total with no
    `girdle` term and no `+`. Nothing in the corpus exercises this (D10), so the test builds its own case.
  - `metricsReadout` for `Pattern-Easy-Octagon` gives `.measured`, with `facets` `29 + 8 girdle = 37`,
    `symmetry` `4-fold, mirrors at 6 18 30 42`, `lengthOverWidth` `1.00000`, and among `proportions` a
    `Girdle` row reading `0.067400 (3.370% of width)`, a `Width` row `2.000000` and a `Length` row
    `2.000000`.
  - `metricsReadout` returns `.unavailable` with D5's sentence for a `nil` pattern and for
    `Pattern-Easy-Octagon` at `tierLimit: 3`, and in the `.unavailable` case carries no summary at all.
  - `proportions` has exactly eight rows, labelled `P/W`, `C/W`, `H/W`, `T/W`, `Girdle`, `Width`,
    `Length`, `Culet`, in that order.
- **Do not:** import SwiftUI, read a file, or format a number with a locale. Do not add a field to
  `MetricsSummary` that no card in Approach §4 draws. Do not touch `TierTable.swift`.

**T3 — Pure: the declared-count check**

- **Files:** `CuttingBench/BenchGeometry/Sources/BenchGeometry/MetricsReadout.swift` (edit),
  `CuttingBench/BenchGeometry/Tests/BenchGeometryTests/MetricsReadoutTests.swift` (edit)
- **Done when:**
  - `FacetCountCheck` and `facetCountCheck` exist with the signatures and doc comments in Approach §2, and
    the verdict follows Approach §2's four branches exactly.
  - For `Pattern-Standard-Round-Brilliant`: `declared: ""` gives `solved` `57 + 16 girdle = 73` and verdict
    `No count declared.`; `declared: "73"` gives verdict `Matches the declared 73.`; `declared: "57"` gives
    verdict `Declared 57 · solved 57 + 16 girdle = 73.`; `declared: "abc"` and `declared: "0"` both give
    `Not a facet count.`; `declared: " 73 "` gives `Matches the declared 73.`
  - **`solved` is the same string in every one of those cases** — the declared count never changes what the
    solve measured.
  - For a `nil` pattern, `solved` is `nil` and `verdict` is `No pattern open.`; for
    `Pattern-Easy-Octagon` at `tierLimit: 3`, `solved` is `nil` and `verdict` is
    `Metrics need every tier: 3 of 6 placed.` — even with `declared: "37"`, which is the point: a
    truncated solve has no count to check a sheet against.
  - A test asserts that a `.doesNotClose` finding does not become a facet-count verdict: for an authored
    pattern truncated to an open solid via `tierLimit`, the verdict is D5's sentence and never anything
    mentioning closure.
- **Do not:** compare the parsed number against `measured.facetCount` yourself; the kernel's
  `.facetCountMismatch` is the check (D12). Do not surface `.doesNotClose` anywhere. Do not add a second
  parse in the view.
- **Commit point** — one commit covering T1, T2 and T3 together. All three are pure package code with no
  visible surface, so a stop between them would show the owner nothing; the commit exists so the two new
  files and the widened value type are not at risk while the cards are built.

```
3-cutting-bench-pattern-display-2 T1-T3: measure the stone in a pure module

- BenchSolid keeps the solve's own Solution instead of dropping it
- New MetricsReadout: the split facet count, the metrics summary and the
  declared-count check, all gated on the solve having placed every tier
```

**T4 — The Metrics card draws**

- **Files:** `CuttingBench/CuttingBench/BenchRegions.swift` (edit),
  `CuttingBench/CuttingBench/BenchWindow.swift` (edit)
- **Done when:**
  - `InspectorRegion` takes `pattern`, `solid` and `@Binding var declaredFacets` per Approach §4, and
    `BenchWindow` declares `@State private var declaredFacets = ""` and passes all three per Approach §5.
  - `MetricsCard` renders both cases of `MetricsReadout` per Approach §4: the reason sentence alone, or the
    trio then a `Divider()` then the eight proportion rows.
  - `GroupBox("Facet Count")` still holds `EmptyCard()` — it is T5's.
  - `GroupBox("Pattern")`, `GroupBox("Notes")` and `GroupBox("Light")` still hold `EmptyCard()`.
  - The owner's verification below passes.
- **Do not:** touch `StatusStripRegion`, `TierTableRegion`, `ViewportRegion`, `ScrubberRegion`, `EmptyCard`,
  the card order, the toolbar, or `rebuild()`. Do not clear `declaredFacets` anywhere. Do not compute the
  readout in `BenchWindow`.
- **Verification handle** — `permanent`:
  - **Where:** the inspector's **Metrics** card, trailing edge of the window. Reach it with the toolbar's
    Inspector button if it is hidden. Open `Design/Patterns/Pattern-Easy-Octagon.json`.
  - **Positive:** the card reads `Facets 29 + 8 girdle = 37`, `Symmetry 4-fold, mirrors at 6 18 30 42`,
    `L/W 1.00000`, and below the divider `T/W 0.631`, `Girdle 0.067400 (3.370% of width)`,
    `Width 2.000000`, `Length 2.000000`, `Culet point`. Cross-check the lot against
    `facetsolve Design/Patterns/Pattern-Easy-Octagon.json --json` **with no `--girdle` flag** — the app
    takes the identical path, so every figure must agree digit for digit.
  - **Negative:** with the same pattern open, press the status strip's debug tier stepper down once, to
    `tiers 5/6`. **Every figure disappears** and the card reads the single line
    `Metrics need every tier: 5 of 6 placed.` — no dimmed numbers, no stale values behind it. Step back up
    to `6/6` and the figures return unchanged.
  - **Reads:** `metricsReadout` and `unmeasurableReason` in
    `CuttingBench/BenchGeometry/Sources/BenchGeometry/MetricsReadout.swift`, over
    `BenchSolid.solution` from T1. Delete `metricsReadout` and the card cannot render at all.

```
3-cutting-bench-pattern-display-2 T4: fill the metrics card in

- The always-visible trio over the full proportion table, formatted to
  facetsolve's own precision so the two can be compared digit for digit
- A partial solve shows the reason and no figures, never a preform's numbers
```

**T5 — The Facet Count card draws**

- **Files:** `CuttingBench/CuttingBench/BenchRegions.swift` (edit)
- **Done when:**
  - `FacetCountCard` renders D13's three lines in order per Approach §4, with the `Solved` line omitted
    when `check.solved` is `nil`.
  - The `TextField` is bound to `InspectorRegion`'s `declaredFacets` binding and nothing else reads or
    writes it.
  - `GroupBox("Pattern")`, `GroupBox("Notes")` and `GroupBox("Light")` still hold `EmptyCard()`.
  - The owner's verification below passes.
- **Do not:** persist the field, add it to `PatternDocument`, add a `Settings` entry, or clear it on
  rebuild. Do not send the mismatch to the status strip (D14). Do not add a numeric formatter to the
  `TextField` — `facetCountCheck` owns the parse.
- **Verification handle** — `permanent`:
  - **Where:** the inspector's **Facet Count** card, directly below `Light`. Open
    `Design/Patterns/Pattern-Standard-Round-Brilliant.json`. That sheet's own note declares
    "57 facets plus 16 on the girdle = 73", so it is the case the split form exists for.
  - **Positive:** the card reads `Solved 57 + 16 girdle = 73` over an empty field and
    `No count declared.` Type `73` → the verdict becomes `Matches the declared 73.` Change it to `57` →
    `Declared 57 · solved 57 + 16 girdle = 73.` Change it to `72` → the same shape with `72`. Clear the
    field → back to `No count declared.`
  - **Negative:** **through all of that the `Solved` line never moves** — it stays
    `57 + 16 girdle = 73` whatever is typed, because what the solve measured does not depend on what the
    sheet claims. And typing `abc`, or `0`, leaves the `Solved` line alone and reads
    `Not a facet count.` rather than treating the text as a number.
  - **Reads:** `facetCountCheck` in
    `CuttingBench/BenchGeometry/Sources/BenchGeometry/MetricsReadout.swift`, which reaches
    `solidFindings(_:declaredFacetCount:)` in the kernel. Delete `facetCountCheck` and the card cannot
    render.

```
3-cutting-bench-pattern-display-2 T5: fill the facet count card in

- The declared count as session state, checked by the kernel's own
  facetCountMismatch rather than by a second comparison
- The mismatch line repeats the split, so a sheet that prints 57 against a
  solve of 73 reads as agreement rather than as a fault
```

**T6 — Close out**

- Delete the temporary handles: **none.** Both handles in this part are `permanent` — each is a card
  displaying real state, and both stay.
- Confirm each item in this plan's **Deferred** section has a ticket in `Design/Tickets/` with
  `Status: untriaged`. The executor files each as it finds it, per the protocol; this is the check, not
  the filing.
- Report the untriaged ticket count in `Design/Tickets/`, one line.
- `commit + push` with the message below.
- **Archive nothing and close no ticket.** This is part 2 of five: the exploration
  `3-Cutting-Bench-Pattern-Display` stays live as the design source for parts 3, 4 and 5, and part 5
  archives it along with every part of this plan by name. Update this plan's own `Status:` line to say
  part 2 completed, with the date, and stop there.

```
3-cutting-bench-pattern-display-2 T6: close out part 2

- The Metrics and Facet Count cards are filled; nothing archived, since the
  exploration is still the source for parts 3 to 5
```

## Deferred

Empty at authoring. The executor appends adjacent problems it found and must not fix — and files each as a
ticket in `Design/Tickets/` immediately with `Status: untriaged`, per the protocol.

- **The shipped app code cites plans' decision numbers.** `BenchRegions.swift` and `BenchWindow.swift`
  carry `(D2)`, `(D9)`, `(D11)`-style tags from earlier plans, which `CLAUDE.md` bars from code. Found
  while editing both files and left alone: it predates this part and is already filed as
  `Chore-Decision-Numbers-Cited-In-Code`, `Status: untriaged`. This part's own new comments state their
  reasons in words instead.
