# 4 · Cutting Bench Authoring — Part 1: Draft and Tier Editing

Status: **APPROVED** (2026-08-26) — in execution.

## Parts

**For the owner and the next authoring session — not for the executor.** Nothing in this plan's tasks
refers to another part.

1. `4-Cutting-Bench-Authoring-1-Draft-And-Tier-Editing` — the editable draft, and every tier edit that
   needs no click in the viewport: add, delete, reorder, rename, angle, part, index stops, instructions,
   the header fields, and the three meet forms that take no picking. Every structural edit that would
   orphan a reference is refused, states its reason and is logged. ← this part
2. `4-Cutting-Bench-Authoring-2-Validation-And-State` — the cheap half of validation on every committed
   edit, the expensive half cached per tier and invalidated from the first edited tier onward, and the
   `state` switch that refuses `finished` while any finding fires.
3. `4-Cutting-Bench-Authoring-3-Symmetry-And-Wheel` — folds, mirroring and seed stops per tier row, with
   `indices` filled in as the expansion and a raw-index escape; the index-gear popup and its
   out-of-range refusal.
4. `4-Cutting-Bench-Authoring-4-Meet-Picking` — building a meet by clicking facets: the intermediate
   solid with the finished stone as a wireframe ghost, the facet-and-edge click machine, the third click
   where more than three planes pass through the point, the axial-point case, and the rough refusals.
   Ships the completion bar — `Easy Octagon` cut in the app.
5. `4-Cutting-Bench-Authoring-5-Fraction-Meets` — a point anchored part-way along an edge: the 10% end
   zones, the outer endpoint as the start of the measurement, the editable percentage, and 0 or 100
   collapsing to a plain vertex. Closes the folded-in ticket and archives the set.

| Exploration ID | Part |
|---|---|
| S1 | 4 |
| S2 | 5 |
| S3 | 1 |
| I1 | 1 |
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
| U13 | 1 — restated in 3, 4 and 5, each of which adds refusals |

## Context

The app displays a pattern and cannot change one. Every one of the four authored patterns was written by
hand-editing JSON and checked with `facetsolve`, and the whole point of this tool is to stop doing that.
This part makes the document editable: the owner opens a pattern, or starts a new one, and changes the
tiers — their angles, their index stops, which part of the stone they belong to, their order, their
labels, the prose beside them, and the three meet forms that need no facets picked. Nothing here needs a
click in the viewport.

**The feasibility scout. This is a small change to known code.**

- **The document already writes through the kernel and nothing else.** `PatternDocument.swift:34`
  (`return FileWrapper(regularFileWithContents: try FacetKernel.encoded(snapshot))`), and
  `Pattern.swift:275` (`public func encoded(_ pattern: Pattern) throws -> Data`) validates the format's
  rules before encoding. So a saved file is already impossible to make invalid; what is new is a draft
  that has to be *converted* before it can be handed over.
- **A tier with no meet chosen cannot be represented in the kernel.** `Pattern.swift:21`
  (`public indirect enum Meet: Codable, Equatable, Sendable`) is exactly five complete forms with no
  "undecided", which is why the draft is the app's own type.
- **The whole display path already takes `Pattern?` and handles a half-solving pattern.**
  `BenchSolid.swift:108` (`public func benchSolid(for pattern: Pattern?, tierLimit: Int? = nil)`) builds
  the bare prism for `nil`; `Solver.swift:156` (`public func solveAsFarAsPossible(`) is non-throwing and
  reports what stopped it; `BenchSolid.swift:41` (`public var stoppedAtTier: String?`) carries it to the
  status strip. Nothing downstream needs to learn about the draft.
- **The tier table already renders a tier the solve never reached.** `TierTable.swift:79`
  (`public func tierTableRows(`) builds one row per *authored* tier, and `TierTable.swift:10`
  (`case notReached`) is the state it reads in. A tier whose meet is not chosen yet is exactly that row.
- **`Meet.namedTriples` is public**, at `Validation.swift:320` (`public var namedTriples: [[FacetRef]] {`).
  That is how the app answers "which tiers name a facet of this one" without restating how a meet names
  facets.
- **The kernel's own edit-adjacent rules are already written down and can be mirrored rather than
  invented:** `Pattern.swift:219` (`guard !tier.tier.isEmpty else { throw PatternError.emptyTierLabel }`),
  `Pattern.swift:228` (`throw PatternError.duplicateTierLabel(tier.tier)`), `Pattern.swift:234`
  (`throw PatternError.indexOutOfRange(tier: tier.tier, index: index, wheel: stops)`),
  `Pattern.swift:215` (`throw PatternError.invalidGirdleTarget(fraction: declared)`) and
  `Pattern.swift:350` (`throw PatternError.nonIntegerIndex(tier: label, value: value)`).
- **Three meet forms need nothing beyond choosing them.** `Solver.swift:353` (`return 1`) — `size`, the
  tier's own offset being the unit; `Solver.swift:362` (`return sin(radians(spec.angle))`) — `tcp`;
  and `Solver.swift:364` (`case .girdle:`), sized from the header's own target. So a tier can be
  authored end to end in this part.
- **The two inspector cards this part fills are placeholders today.** `BenchRegions.swift:246`
  (`GroupBox("Pattern") { EmptyCard() }`) and the `Notes` box on the line below it.
- **What does not exist yet:** any editing at all, any undo registration (`grep -rn "undo" ` over
  `CuttingBench/CuttingBench/` finds nothing), and any logging (no `import OSLog` anywhere in the
  repository). All three are new here.

## Decisions (2026-08-26)

| # | Decision |
|---|---|
| D1 | **The half-authored pattern is the app's, never the kernel's.** The draft lives in `BenchGeometry` and the kernel's types are untouched, because a tier with an angle and stops but no meet yet cannot be represented by `Pattern.swift:21`'s five complete forms, and which fields may be absent is UI policy rather than geometry. Recorded as **ADR-0003**. |
| D2 | **Two conversions from one draft, never one.** `displayPattern` takes the tiers that *have* a meet, in file order, and is `nil` when that leaves none. `completePattern()` refuses unless every tier has one. The stone must stay visible while a tier is half-authored, and the file has no "undecided" meet, so saving cannot dodge the choice. |
| D3 | **A tier with no meet yet keeps its row in the tier table, reading as `notReached`.** `TierTable.swift:75` already holds that a tier the solve never reached is still a row the author wrote; dropping the row would hide the work instead of showing it. |
| D4 | **A new document is an empty draft:** `formatVersion` 1, empty name, `state` in progress, `wheel` **96**, `ri` **1.54**, no girdle target, empty designer and notes, no tiers. `displayPattern` is therefore `nil` and a new window draws the bare prism exactly as it does today. 96 is the common gear and 1.54 is quartz, `Easy Octagon`'s own value; both are visible and editable in the Pattern card, so a default that does not suit costs one edit. |
| D5 | **Every edit goes through one document method that snapshots the whole previous draft for undo.** A draft is a few dozen value-typed tiers, so a whole-value snapshot per edit costs nothing and cannot get its inverse wrong; per-field inverse operations would be a second implementation of every edit. Redo comes free because the undo closure registers its own undo. |
| D6 | **Every editable field is a local buffer committed on Return or on losing focus, and a refused commit puts the buffer back to the stored value.** A refusal needs a whole value to judge — a half-typed index list means nothing — so the commit boundary is what makes the refusal rules possible at all. The commit function returns whether it was accepted, which is what the cell reverts on; a refusal leaves the draft untouched, so there is no change for the cell to observe. |
| D7 | **The line is remove versus move.** Deleting a tier, or removing an index stop, that a later tier's meet names is **refused**, naming the dependents. Changing a tier's **angle** or its **part** is **always allowed**: it moves a named facet rather than removing it, so every reference still resolves, just to a different point. |
| D8 | **A rename propagates into every meet that names the tier**, and is refused only for an empty or duplicate label — mirroring `Pattern.swift:219` and `Pattern.swift:228`. A rename is the one structural repair that guesses nothing, because the mapping from old label to new is exact. |
| D9 | **A move is refused when it would make any meet name a tier cut later** — the same test as a delete, applied to a move. **Negative requirement: the app never reorders tiers on its own** — not on load, not on save, not to group by `part`, not to sort by angle. Tier order is data, and normalising it for tidiness can turn a cuttable pattern into one that cannot be cut at all. |
| D10 | **Index stops are refused when out of range for the tier's effective gear** (mirroring `Pattern.swift:234`) **and when they are not whole numbers** (mirroring `Pattern.swift:350`). Everything else is passed through and reported by the solve rather than blocked — an angle past 90, an empty stop list — because structural edits are refused and geometric consequences are reported. |
| D11 | **The Meet cell offers exactly four choices: not chosen yet, `size`, `tcp`, `girdle`.** None of the three forms takes any input beyond being chosen. A tier whose meet is a `vertex` or a `fraction` shows that meet as the menu's own label and cannot have one picked here; choosing *not chosen yet* clears it, which ⌘Z undoes. |
| D12 | **Every refusal states its reason, names the offending element, and is written to the unified log through one `Logger`** with subsystem `DigitalEnki.CuttingBench` and category `refusals`. One wording for the alert and the log line, so the two can never disagree. A refusal dismissed once still has to be traceable afterwards. |
| D13 | **Add appends a tier at the end** labelled with the first of `N1`, `N2`, `N3`… not already used, `part` `pav`, `angle` `0.00`, **no index stops** and **no meet**. Appending can never create a forward reference, and inserting mid-pattern is reachable by appending and moving, which D9 already guards. Nothing is guessed about the design: the tier has no meet, so D2 drops it from the display and none of those four values reaches the stone until the author has set them. |
| D14 | **The Wheel column and the header gear stay read-only in this part.** A gear change has to refuse the stops it would put out of range *and* it changes which fold counts are reachable, and those two are one topic — splitting them across sessions would mean writing the same constraint twice. |
| D15 | **The findings store stops keying its kept geometric result on the pattern's name.** The name becomes editable here, and a rename is an edit like any other: a result that survives every other edit must survive this one. |
| D16 | **The girdle target field is the fraction the file stores, shown to four decimal places** — `0.0337`, not `3.37%`. The format's field is a fraction, and a second unit in the UI is a second place the number can be wrong. An empty field means absent, which is the documented default rather than zero. |

## Tickets closed by this plan

**None — closed in the final part.** `Chore-Validation-Rebuilds-The-Solid-Once-Per-Tier` is answered by
the per-tier cache and the split between the cheap and expensive halves of validation, neither of which
is built here.

## Prefactoring

**One task, T1**, and it is the only behaviour-preserving change in the plan.

`BenchFindingsStore.swift:41` (`if pattern?.name != checkedName {`) clears the kept geometric result
whenever the pattern's name differs from the one it last checked. That is correct today, because nothing
can change a name. From T8 on, editing the name in the Pattern card would throw away a perfectly good
findings result and blank the status strip — the one thing `BenchFindingsStore.swift:15`'s own comment
says must not happen. Removing the name key is invisible today and prevents that.

**Its check is inverted: nothing should change.** `BenchFindingsStore` lives in the app target, which has
no test target in this project — `CuttingBench/BenchGeometry` is the only package with tests, and the
store is not in it. So there is no characterization test to write, and saying so is more honest than
writing one somewhere it does not belong: the check is the type-check, plus the owner confirming at T3's
stop that a pattern still opens with its findings line reading as it did before.

## Approach

Three new pure files in `BenchGeometry` hold the draft, the reference graph and every edit rule, each edit
a function from a draft to either a new draft or a refusal. The document swaps its stored `Pattern?` for a
draft and derives the pattern from it, so nothing downstream of the document changes shape. The window
gains one funnel that applies an edit, registers its undo, and hands a refusal to a presenter that shows
an alert and writes a log line. The tier table's cells and the two placeholder inspector cards become
editable through that funnel.

### 1. New: `CuttingBench/BenchGeometry/Sources/BenchGeometry/PatternDraft.swift` (pure — no framework, no I/O)

```swift
/// One tier as it stands while being authored: everything `TierSpec` carries, with the meet optional.
public struct DraftTier: Identifiable, Equatable, Sendable {
  public var tier: String
  public var part: Part
  public var angle: Double
  public var indices: [Int]
  public var wheel: Int?
  /// `nil` is a tier whose depth has not been decided yet — the normal condition of authoring, and the
  /// one thing `TierSpec` cannot hold (D1).
  public var meet: Meet?
  public var instructions: String?

  public var id: String { tier }

  public init(
    tier: String, part: Part, angle: Double, indices: [Int], wheel: Int? = nil,
    meet: Meet? = nil, instructions: String? = nil)
  public init(_ spec: TierSpec)

  /// `nil` when no meet has been chosen.
  public var spec: TierSpec? { get }
}

public struct PatternDraft: Equatable, Sendable {
  public var formatVersion: Int
  public var name: String
  public var state: PatternState
  public var wheel: Int
  public var ri: Double
  public var girdleTargetFraction: Double?
  public var designer: String
  public var notes: String
  public var tiers: [DraftTier]

  /// A new document (D4).
  public static let empty: PatternDraft

  public init(
    formatVersion: Int, name: String, state: PatternState, wheel: Int, ri: Double,
    girdleTargetFraction: Double?, designer: String, notes: String, tiers: [DraftTier])
  public init(_ pattern: Pattern)

  /// The pattern the display solves: the tiers that have a meet, in file order, and `nil` when that
  /// leaves none (D2).
  public var displayPattern: Pattern? { get }

  /// The pattern the file is written from. Refuses rather than dropping anything (D2).
  public func completePattern() -> Result<Pattern, DraftRefusal>

  /// Where a label sits, or `nil` for a label the draft does not carry.
  public func position(ofTier tier: String) -> Int?

  /// The gear a tier is cut on: its own if it declares one, otherwise the draft's. The same rule as
  /// `Pattern.wheel(of:)` at `Pattern.swift:130`.
  public func wheel(of tier: DraftTier) -> Int
}

/// One edit, as the change itself. Every editable cell hands one of these up to the window's funnel.
public typealias DraftChange = (PatternDraft) -> Result<PatternDraft, DraftRefusal>

/// An edit the app will not complete, and why. Every case names the element at fault (D12). It lives here
/// rather than beside the edit functions because `completePattern()` is its first user and an enum's cases
/// cannot be added to from a second file.
public enum DraftRefusal: Error, Equatable, Sendable {
  case tierReferenced(tier: String, by: [String])
  case stopReferenced(tier: String, index: Int, by: [String])
  case moveWouldPointForward(tier: String, named: String)
  case duplicateTierLabel(String)
  case emptyTierLabel
  case indexOutOfRange(tier: String, index: Int, wheel: Int)
  case indicesNotWholeNumbers(typed: String)
  case notANumber(field: String, typed: String)
  case girdleTargetNotPositive(typed: String)
  case tiersWithoutMeet([String])
  case noTiers

  /// The sentence the alert shows and the log line records. One wording, so the two cannot disagree.
  public var message: String { get }
}

/// The `#if DEBUG` status-strip segment. Here rather than in the view so its wording is checkable
/// without a window.
public func draftSummary(_ draft: PatternDraft) -> String
```

Rules these enforce, and they are the whole of it:

- **`displayPattern`** builds a `Pattern` from the header fields and `tiers.compactMap(\.spec)`, and
  returns `nil` when that array is empty. It **never sorts and never regroups** (D9).
- **`completePattern()`** returns `.failure(.noTiers)` for an empty draft, `.failure(.tiersWithoutMeet)`
  listing the labels in file order when any tier lacks a meet, and otherwise the same `Pattern`
  `displayPattern` gives.
- **`draftSummary`** returns exactly one of: `"draft 0 tiers · no tiers yet"`,
  `"draft 6 tiers · complete"`, `"draft 7 tiers · no meet yet: P4"` — labels comma-separated in file
  order where there is more than one.

### 2. New: `CuttingBench/BenchGeometry/Sources/BenchGeometry/DraftReferences.swift` (pure)

```swift
/// Every tier whose meet names a facet of `tier`, in file order. Built from `Meet.namedTriples`
/// (`Validation.swift:320`), so the app never restates how a meet names facets (D1).
public func tiersNaming(tier: String, in draft: PatternDraft) -> [String]

/// Every tier whose meet names `tier` at exactly this index stop, in file order.
public func tiersNaming(tier: String, index: Int, in draft: PatternDraft) -> [String]

/// The labels a tier's own meet names, deduplicated, in the order they are first named.
public func tiersNamed(by tier: DraftTier) -> [String]
```

A tier's own meet naming its own label is not filtered out here — the kernel already reports that as
`namesOwnFacet` and this file's job is the graph, not the judgement.

### 3. New: `CuttingBench/BenchGeometry/Sources/BenchGeometry/DraftEdits.swift` (pure)

```swift
/// An edit the app will not complete, and why. Declared in `PatternDraft.swift` — see there.
public enum DraftRefusal: Error, Equatable, Sendable { … }

public func deleting(tier: String, from draft: PatternDraft) -> Result<PatternDraft, DraftRefusal>
public func moving(tier: String, by offset: Int, in draft: PatternDraft)
  -> Result<PatternDraft, DraftRefusal>
public func renaming(tier: String, to label: String, in draft: PatternDraft)
  -> Result<PatternDraft, DraftRefusal>
public func setting(angle typed: String, ofTier: String, in draft: PatternDraft)
  -> Result<PatternDraft, DraftRefusal>
public func setting(indices typed: String, ofTier: String, in draft: PatternDraft)
  -> Result<PatternDraft, DraftRefusal>
public func setting(part: Part, ofTier: String, in draft: PatternDraft)
  -> Result<PatternDraft, DraftRefusal>
public func setting(instructions: String, ofTier: String, in draft: PatternDraft)
  -> Result<PatternDraft, DraftRefusal>
public func setting(meet: Meet?, ofTier: String, in draft: PatternDraft)
  -> Result<PatternDraft, DraftRefusal>
public func appendingTier(to draft: PatternDraft) -> Result<PatternDraft, DraftRefusal>

public func setting(name: String, in draft: PatternDraft) -> Result<PatternDraft, DraftRefusal>
public func setting(designer: String, in draft: PatternDraft) -> Result<PatternDraft, DraftRefusal>
public func setting(notes: String, in draft: PatternDraft) -> Result<PatternDraft, DraftRefusal>
public func setting(ri typed: String, in draft: PatternDraft) -> Result<PatternDraft, DraftRefusal>
public func setting(girdleTarget typed: String, in draft: PatternDraft)
  -> Result<PatternDraft, DraftRefusal>
```

Every one of them returns `Result` even where it can never fail, so the window's funnel has one signature
to call and a later part can make a rule stricter without changing a call site.

**A label the draft does not carry is `.success(draft)` — the draft unchanged.** Not a refusal: a stale
label in the table's selection is inert rather than wrong, which is the rule `BenchWindow.swift:164`
already states for the tier selection.

The rules, exactly:

- **`deleting`** — `.failure(.tierReferenced(tier:by:))` when `tiersNaming(tier:in:)` is non-empty;
  otherwise the tier is removed and nothing else moves (D7).
- **`moving`** — builds the reordered array first, then walks it and returns
  `.failure(.moveWouldPointForward(tier:named:))` for the **first** tier whose meet names a label at or
  after its own new position. `offset` is `-1` or `+1`; a move off either end is `.success(draft)`,
  unchanged (D9).
- **`renaming`** — trims whitespace; `.failure(.emptyTierLabel)` when empty,
  `.failure(.duplicateTierLabel)` when another tier already has it, `.success(draft)` when the label is
  unchanged. Otherwise the tier's label is rewritten **and so is every `FacetRef` naming it**, in every
  tier's meet, through a private recursive `renamed(_ meet: Meet, from: String, to: String) -> Meet` that
  walks `.vertex` and both endpoints of `.fraction` (D8).
- **`setting(angle:)`** — `Double(typed.trimmed)` or `.failure(.notANumber(field: "angle", typed:))`.
  Never refused for its value (D7, D10).
- **`setting(indices:)`** — splits on whitespace and commas; each piece must parse as `Int` or the whole
  edit is `.failure(.indicesNotWholeNumbers(typed:))`; each must satisfy `0 ..< wheel(of:)` or
  `.failure(.indexOutOfRange(tier:index:wheel:))` naming the **first** offender. Then, for each stop in
  the old list and not the new, `.failure(.stopReferenced(tier:index:by:))` for the **first** one
  `tiersNaming(tier:index:in:)` finds a namer for. **Order within the list is preserved as typed and
  duplicates are preserved as typed** — the format permits any order and the order is data
  (`TierTable.swift:106`). An empty list is accepted (D10).
- **`setting(part:)`** — always accepted (D7).
- **`setting(instructions:)`** — always accepted; an empty string is stored as an empty string and never
  as `nil`, because absent means the author wrote nothing and empty means they wrote nothing *here*
  (`Pattern.swift:62`).
- **`setting(meet:)`** — always accepted, including `nil`. The Meet cell only ever passes `.size`,
  `.tcp`, `.girdle` or `nil` (D11); the parameter is a whole `Meet?` so a later part can pass a picked
  one without changing this function.
- **`appendingTier`** — appends a `DraftTier` per D13: label the first unused of `N1`, `N2`, …, `part`
  `.pav`, `angle` `0`, `indices` `[]`, `meet` `nil`, `instructions` `nil`.
- **`setting(name:)`, `setting(designer:)`, `setting(notes:)`** — always accepted, stored verbatim
  including whitespace.
- **`setting(ri:)`** — `Double` or `.failure(.notANumber(field: "refractive index", typed:))`.
- **`setting(girdleTarget:)`** — an empty or whitespace-only string sets `nil`, which is absent and means
  the documented default (`Pattern.swift:100`). Otherwise `Double` or
  `.failure(.notANumber(field: "girdle target", typed:))`, then `> 0` or
  `.failure(.girdleTargetNotPositive(typed:))`, mirroring `Pattern.swift:215` (D16).

**The messages, verbatim.** `by:` lists join with `", "` in file order.

| Case | `message` |
|---|---|
| `tierReferenced` | `G1 cannot be deleted: its facets are named by P2, C1. Re-aim or remove those meets first.` |
| `stopReferenced` | `Index stop 12 cannot be removed from G1: it is named by C2, T. Re-aim or remove those meets first.` |
| `moveWouldPointForward` | `P2 cannot move there: P2's meet names G1, and a meet may only name a tier cut earlier.` |
| `duplicateTierLabel` | `There is already a tier called P2.` |
| `emptyTierLabel` | `A tier needs a label.` |
| `indexOutOfRange` | `Index stop 100 is outside 0...95 on G1's gear of 96.` |
| `indicesNotWholeNumbers` | `"0 12 24.5" is not a list of whole index stops.` |
| `notANumber` | `"forty" is not a number for angle.` |
| `girdleTargetNotPositive` | `A girdle target has to be greater than zero. Leave the field empty for the default of 0.04.` |
| `tiersWithoutMeet` | `This pattern cannot be saved yet: P4, C3 have no meet. Choose one for each, or delete the tier.` |
| `noTiers` | `This pattern has no tiers yet.` |

### 4. `CuttingBench/BenchGeometry/Sources/BenchGeometry/TierTable.swift` — rows for a draft

`tierTableRows` builds one row per tier of the `Pattern` it is given, so as written it would silently have
no row at all for a tier whose meet is not chosen yet — which is the opposite of D3. **Its first parameter
changes from `pattern: Pattern?` to `draft: PatternDraft`:**

```swift
public func tierTableRows(draft: PatternDraft, solid: BenchSolid, light: LightReadout) -> [TierTableRow]
```

Four changes inside it, one addition to `TierTableRow`, and nothing else:

- `TierTableRow` gains `public var angleValue: String` — the angle **without** the degree sign,
  `String(format: "%.2f", spec.angle)`. **Required, not defaulted:** `TierTable.swift:102`
  (`return TierTableRow(`) is the only construction of one in the repository, so nothing else has to
  change and a forgotten argument is a compile error rather than an empty cell. The Angle cell edits this
  and displays `angle`; without it a cell would have to reach back into the draft by label and
  force-unwrap a lookup that cannot fail.
- The `guard let pattern else { return [] }` at `:82` goes; an empty draft has no tiers and so yields no
  rows by itself.
- It maps over `draft.tiers` rather than `pattern.tiers`, and `pattern.wheel(of: spec)` at `:112` becomes
  `draft.wheel(of: spec)`.
- `meet:` is `spec.meet.map(meetText) ?? "—"`. **`—` is the cell for a tier with no meet yet** (D11), and
  it is also what the Meet menu's label reads.
- `meetPoints:` and the doc comment above the function keep their behaviour by being handed
  `draft.displayPattern`: `meetPointDots(ofTier: spec.tier, pattern: draft.displayPattern, solid: solid)`.
  A meet-less label is absent from that pattern, so it yields no dots — which is right, since a meet that
  has not been chosen names no point to draw.

**`state` needs no change and lands on `.notReached` for a meet-less tier by construction**: the tier is
absent from `solid.tiers` and is not `solid.stoppedAtTier`, so the existing `else` branch at `:93` catches
it. That is D3 with no new code.

The existing `TierTableTests.swift` changes one argument per call — `pattern: X` becomes
`draft: PatternDraft(X)`, and the no-pattern case becomes `draft: .empty`. **No assertion in it changes**,
which is the check that this is a re-parameterisation and not a behaviour change.

### 5. New tests: two files beside the existing ones in `CuttingBench/BenchGeometry/Tests/BenchGeometryTests/`

`PatternDraftTests.swift` and `DraftEditsTests.swift`, table-style over the corpus and over constructed
cases, exactly as `TierTableTests.swift` does it: `import FacetKernel`, `@testable import BenchGeometry`,
`XCTest`, and `AuthoredPatterns` — which lives in `BenchSolidTests.swift:10` (`enum AuthoredPatterns {`)
and loads from `Design/Patterns/` by a path relative to `#filePath`.

**`Pattern` is qualified as `FacetKernel.Pattern` throughout both files.** XCTest pulls in
ApplicationServices, whose `Quickdraw.h` declares a `Pattern` struct, so the bare name is ambiguous in a
test file in this target — the reason is written at `BenchSolidTests.swift:32`.

### 6. `CuttingBench/CuttingBench/BenchFindingsStore.swift` — the prefactor

Delete the name key. Three edits, nothing else:

- `:28` (`private var checkedName: String?`) — remove the property and its comment above it.
- `:41`–`:44` (`if pattern?.name != checkedName {`) — remove the whole `if` block.
- `:16`–`:17` — extend the existing comment to say the kept result now survives every edit to the open
  document, including a rename, and is cleared only when the document has no pattern to check.

The `guard let pattern, let solution = solid.solution else { … geometric = [] … }` path at `:46` is
untouched and remains the only place `geometric` is emptied.

### 7. `CuttingBench/CuttingBench/PatternDocument.swift`

The stored value becomes the draft; the pattern becomes derived.

```swift
final class PatternDocument: ReferenceFileDocument {
  typealias Snapshot = PatternDraft

  @Published var draft: PatternDraft = .empty

  /// What everything downstream solves and displays. Computed and never stored: one draft, one derived
  /// pattern, so no readout can disagree with the draft (D2).
  var pattern: FacetKernel.Pattern? { draft.displayPattern }

  init() { draft = .empty }

  init(configuration: ReadConfiguration) throws        // decode a Pattern, then PatternDraft(pattern)
  func snapshot(contentType: UTType) throws -> PatternDraft { draft }
  func fileWrapper(snapshot: PatternDraft, configuration: WriteConfiguration) throws -> FileWrapper

  /// One edit, one undo entry (D5). Returns the refusal for the caller to present, or `nil` when the
  /// edit landed.
  @discardableResult
  func apply(_ change: DraftChange, undoManager: UndoManager?, actionName: String) -> DraftRefusal?
}
```

- **`init(configuration:)`** keeps its existing `guard let` and its `PatternReadError` wrapping verbatim,
  and only its last line changes: `draft = PatternDraft(try JSONDecoder().decode(…))`.
- **`fileWrapper`** switches on `snapshot.completePattern()`: `.success` goes to
  `FileWrapper(regularFileWithContents: try FacetKernel.encoded(pattern))` exactly as `:34` does today,
  and `.failure(refusal)` throws a new `DraftSaveError(refusal:)` — a `LocalizedError` beside
  `PatternReadError` at `:40`, with `errorDescription` `"This pattern cannot be saved yet."` and
  `failureReason` the refusal's own `message` (D2, D12).
- **`apply`** runs the change, returns the refusal on `.failure`, returns `nil` unchanged on a
  `.success` equal to the current draft, and otherwise assigns the new draft and registers an undo that
  applies the *previous whole draft* through this same method — which is what makes redo work without a
  second code path. It sets the undo action name from `actionName`.

### 8. New: `CuttingBench/CuttingBench/RefusalPresenter.swift`

```swift
import BenchGeometry
import OSLog
import Observation
import SwiftUI

/// Where a refused edit goes: an alert now and a log line forever (D12).
@Observable @MainActor final class RefusalPresenter {
  /// The sentence the alert shows, or `nil` for no alert.
  private(set) var message: String?

  /// `@ObservationIgnored` because it is not state anything observes, and `Logger` is not `Equatable`.
  @ObservationIgnored private let log = Logger(
    subsystem: "DigitalEnki.CuttingBench", category: "refusals")

  /// `nonisolated`, so a `View`'s `@State` default value can construct it — the same reason
  /// `BenchSolidStore.swift:55` and `BenchFindingsStore.swift:33` are.
  nonisolated init() {}

  func present(_ refusal: DraftRefusal)
  func dismiss()

  /// The alert's binding. **Built here rather than in the view**: its two closures read and write
  /// main-actor state, and inside a `@MainActor` type they inherit that isolation instead of needing it
  /// asserted at the call site. `SwiftUI` is imported for this one property and nothing else.
  var isPresented: Binding<Bool> { get }
}
```

`present` logs at `.notice` with `privacy: .public` — a refusal names a tier label and an index stop from
the owner's own pattern, and a redacted log line would be useless for the one thing this exists for. Then
it sets `message`.

### 9. `CuttingBench/CuttingBench/BenchWindow.swift`

- **Two new members**, beside the existing `@State` stores at `:12`–`:13`:
  `@State private var refusals = RefusalPresenter()` and `@Environment(\.undoManager) private var
  undoManager`.
- **One funnel**, beside `rebuild()` at `:149`:

  ```swift
  /// Every edit in the window goes through here: apply it, register its undo, and present the refusal if
  /// there is one. Returns whether the edit was accepted, which is what an editable cell reverts on (D6).
  @discardableResult
  private func edit(_ actionName: String, _ change: DraftChange) -> Bool {
    guard let refusal = document.apply(change, undoManager: undoManager, actionName: actionName) else {
      return true
    }
    refusals.present(refusal)
    return false
  }
  ```

- **`.onChange(of: document.pattern, initial: true) { rebuild() }` at `:120` is unchanged.** `pattern` is
  now computed from the draft, so an edit that changes no solved geometry — the notes, the designer, a
  tier's instructions, a meet cleared on a tier the display already dropped — does not re-solve. That is
  a consequence of D2 and not a separate mechanism.
- **The alert**, on the root `VStack` beside `.frame(minWidth:)` at `:87`:

  ```swift
  .alert("Edit refused", isPresented: refusals.isPresented) {
    Button("OK") { refusals.dismiss() }
  } message: {
    Text(refusals.message ?? "")
  }
  ```

- **`TierTableRegion` gains `draft: document.draft` and `edit: edit`** at the call site on `:63`.
- **`InspectorRegion` gains `draft: document.draft` and `edit: edit`** at `:89`.
- **`StatusStripRegion`'s `#if DEBUG` call at `:72` gains `draftLine: draftSummary(document.draft)`.**

### 10. `CuttingBench/CuttingBench/BenchRegions.swift`

Four changes, in the order the tasks land them.

**a. `StatusStripRegion` — one more DEBUG field.** Add `let draftLine: String` inside the existing
`#if DEBUG` block at `:424`–`:429`, and append `" · \(draftLine)"` to the end of `documentSummary`'s
returned string at `:472`. Nothing else in that region changes.

**b. One editable cell, used by every text field in the file.** A new `private struct` beside
`MeetDotChip` at `:215`:

```swift
/// A cell that commits on Return or on losing focus, and snaps back to the stored value when the edit is
/// refused (D6). `stored` is what the draft holds; the buffer is local and never the source of truth.
private struct EditableCell: View {
  let stored: String
  /// Returns whether the edit was accepted.
  let commit: (String) -> Bool

  @State private var typed = ""
  @FocusState private var focused: Bool

  var body: some View {
    TextField("", text: $typed)
      .textFieldStyle(.plain)
      .focused($focused)
      .onSubmit { commitNow() }
      .onChange(of: focused) { _, isFocused in if !isFocused { commitNow() } }
      // The buffer follows the draft, so an accepted edit, an undo and a rename all correct it.
      .onChange(of: stored, initial: true) { typed = stored }
  }

  /// On a refusal the draft is untouched, so `stored` is still the old value and assigning it is the
  /// revert. On acceptance `stored` changes and the observer above does it instead.
  private func commitNow() { if !commit(typed) { typed = stored } }
}
```

**c. `TierTableRegion` — editable cells, and a row of buttons over the table.**

Two new members beside `rows` at `:142`:

```swift
/// The raw values the cells edit, and the labels the buttons act on. The formatted `rows` stay the
/// display: a cell shows `47.60°` and edits `47.60`.
let draft: PatternDraft
let edit: (String, DraftChange) -> Bool
```

The `body` becomes a `VStack(spacing: 0)` of a button row, a `Divider()`, and the existing `Table`. The
button row is `HStack` of four `Button`s and a `Spacer`, `.padding(.horizontal, 10)` and
`.frame(height: 28)`:

| Button | Label | Enabled when | Action |
|---|---|---|---|
| Add | `Add Tier`, `plus` | always | `edit("Add Tier") { appendingTier(to: $0) }` |
| Delete | `Delete Tier`, `minus` | a row is selected | `edit("Delete Tier") { deleting(tier: sel, from: $0) }` |
| Up | `Move Up`, `chevron.up` | a row is selected and is not the first | `edit("Move Tier") { moving(tier: sel, by: -1, in: $0) }` |
| Down | `Move Down`, `chevron.down` | a row is selected and is not the last | `edit("Move Tier") { moving(tier: sel, by: 1, in: $0) }` |

`sel` is `selection`, which the region already holds as a `@Binding` at `:145` — and whose doc comment
there (*"nothing is edited through it"*) must be rewritten, because tiers are now added, deleted and
moved through it.

The columns change as follows. Every one keeps the `cell(_:_:dimmed:)` styling helper at `:207` for its
non-editing appearance, and a cell for a tier the draft does not carry is unreachable because `rows` and
`draft.tiers` are built from the same array.

- **Tier** — the existing `HStack` keeps its stopped-tier and findings markers, and `cell(row.tier, row)`
  becomes an `EditableCell`. Every editable cell in the table has this shape, with the label captured
  from `row` and the typed text threaded through:

  ```swift
  EditableCell(stored: row.tier) { typed in
    edit("Rename Tier") { renaming(tier: row.tier, to: typed, in: $0) }
  }
  ```
- **Part** — `cell(row.part, row)` becomes a `Picker` over a **file-private list of the four cases in the
  kernel's own declaration order** — `private let partCases: [Part] = [.pav, .gdl, .crown, .table]`,
  matching `Plane.swift:21` onward. **`Part` gains no `CaseIterable` conformance**, in the kernel or
  retroactively: `allCases` is only synthesised at the point of declaration, so a retroactive conformance
  would mean hand-writing the same list behind a protocol that buys nothing. `.labelsHidden()`,
  `.pickerStyle(.menu)`, and its selection change calls
  `edit("Change Part") { setting(part: …, ofTier: row.tier, in: $0) }`.
- **Angle** — the `HStack` keeps its light-leak label, and `cell(row.angle, row)` becomes an
  `EditableCell(stored: row.angleValue)` committing through `setting(angle:ofTier:in:)`. `angleValue` is
  the new row field from section 4 — the same number without the degree sign — so the cell needs no lookup
  back into the draft, and the `°` becomes a `Text("°")` beside the field. What the author edits is what
  they typed.
- **Indices** — `EditableCell(stored: row.indices)` committing through `setting(indices:ofTier:in:)`.
  `row.indices` is already the space-joined list in authored order (`TierTable.swift:109`), which is
  exactly the text to edit.
- **Meet** — the existing two-branch content becomes the label of a `Menu` (D11):

  ```swift
  Menu {
    Button("Not chosen yet") { edit("Change Meet") { setting(meet: nil, ofTier: row.tier, in: $0) } }
    Divider()
    Button("size")   { edit("Change Meet") { setting(meet: .size,   ofTier: row.tier, in: $0) } }
    Button("tcp")    { edit("Change Meet") { setting(meet: .tcp,    ofTier: row.tier, in: $0) } }
    Button("girdle") { edit("Change Meet") { setting(meet: .girdle, ofTier: row.tier, in: $0) } }
  } label: {
    // The existing content, unchanged: the dots when there are any, `row.meet` when there are not.
  }
  .menuStyle(.borderlessButton)
  ```

  A tier with no meet has no `meetPoints`, and section 4 already puts `—` in its `meet` string, so the
  label reads `—` with nothing extra here.
- **Wheel** — unchanged, read-only (D14).
- **Instructions** — `EditableCell(stored: row.instructions)` committing through
  `setting(instructions:ofTier:in:)`.

**`draft` is read by the buttons and by nothing else.** Every cell works from `row` and hands `row.tier`
to the funnel, which is why `angleValue` exists: a cell reaching into `draft.tiers` by label would need a
force unwrap for a case that cannot happen.

**d. `InspectorRegion` — the Pattern and Notes cards.** Two new members beside `pattern` at `:232`:
`let draft: PatternDraft` and `let edit: (String, DraftChange) -> Bool`. The two `EmptyCard()`
placeholders at `:246`–`:247` become `PatternCard(draft:edit:)` and `NotesCard(draft:edit:)`, two new
`private struct`s beside `MetricsCard` at `:276`. `EmptyCard` at `:380` stays — it is still what a card
with nothing to show uses.

`PatternCard` is a `VStack(alignment: .leading, spacing: 6)` of labelled rows, in this order and no other:

| Row | Control | Commits through |
|---|---|---|
| Name | `EditableCell` | `setting(name:in:)` |
| State | `Text(draft.state.rawValue)`, read-only | — |
| Gear | `Text(String(draft.wheel))`, read-only (D14) | — |
| RI | `EditableCell`, `String(format: "%.3f", draft.ri)` | `setting(ri:in:)` |
| Girdle target | `EditableCell`, `String(format: "%.4f", …)` or `""` when absent (D16) | `setting(girdleTarget:in:)` |
| Designer | `EditableCell` | `setting(designer:in:)` |

**RI is shown to three decimals and the girdle target to four, because an editable field has to be able to
round-trip its own value.** Two decimals would render corundum's `1.762` as `1.76`, and committing that
would silently change the pattern. A field is only ever committed by an explicit edit, so a value with more
precision than the field shows is safe until the author touches it — and none of the four authored patterns
carries one.

**Never save over `Design/Patterns/`.** Those four files are external ground truth and the protocol forbids
editing them. Every save this plan asks anyone to perform is a **Save As** to a scratch path.

`NotesCard` is one multi-line field: a `TextField("", text:, axis: .vertical)` with
`.lineLimit(3...10)`, committing through `setting(notes:in:)`. **It commits on losing focus only, not on
Return**, because Return inserts a line break in a vertical `TextField` and notes are prose that wants
line breaks. So `EditableCell` takes two more parameters — `axis: Axis = .horizontal` and
`commitsOnReturn: Bool = true` — which it passes to `TextField` and uses to skip the `.onSubmit`; nothing
else about it changes, and every other field in the plan takes the defaults.

## Explicitly not doing

- **No meet that needs a facet picked.** `vertex` and `fraction` meets are read, displayed, renamed
  through and saved, but not created or re-aimed. D11: the three forms available here take no input
  beyond being chosen, and picking is a viewport interaction with its own rules.
- **No index-gear editing, per tier or in the header** (D14). The Wheel column and the header Gear row are
  read-only text.
- **No `state` editing.** The Pattern card shows it as read-only text. Turning it into a claim means
  refusing the transition on a complete synchronous validation of all three pieces, which is not built
  here — and a switch that flips without that check makes the field a label rather than a claim.
- **No symmetry controls, no seed stops, no folds field.** `indices` is edited as the literal list.
- **No validation caching and no change to when validation runs.** `BenchFindingsStore` keeps its current
  behaviour apart from the prefactor. Every committed edit re-solves and re-validates the whole pattern,
  which is what happens today on open; at 37–73 facets that is imperceptible, and making it cheap is a
  recompute-scheduling problem rather than an editing one.
- **No automatic repair of anything.** A refused edit is refused; the app never re-aims a meet, never
  cascades a delete through dependents, and never leaves a reference dangling. Repairing a deletion would
  mean choosing which facets a meet should aim at instead, which the format forbids a tool from doing.
- **No change to `Kernel/`.** Everything this part needs from the kernel is already public. If a task
  appears to need a kernel change, that is a stop rule, not a scope decision.
- **No change to `design-authoring-format.md`.** No task here names it, and the protocol permits edits to
  it only through a task that does.

## Tasks

Every task runs the protocol's gates first, in its order, which here means:

1. `swift test --package-path Kernel --disable-sandbox` — green. (Protocol gate 1.)
2. `swift test --package-path CuttingBench/BenchGeometry --disable-sandbox` — green.
3. `xcrun swift-format lint --recursive --strict Kernel/Sources Kernel/Tests
   CuttingBench/BenchGeometry/Sources CuttingBench/BenchGeometry/Tests CuttingBench/CuttingBench` —
   clean.
4. `swift build -c release --package-path Kernel --disable-sandbox` — succeeds. (Protocol gate 3.)
   **No task in this part touches `Kernel/`, so this gate never fires.**
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
here because the draft summary lives only in the debug branch. `-disable-sandbox` is required, or the
`@Observable` macro plugin fails with `sandbox_apply: Operation not permitted` and floods the output. It
compiles no `.metal` and no resources, so it replaces neither the owner's build nor an owner-stop
verification. If the `-I` path does not exist, the `swift build` line above creates it.

| # | Task | Status | Then | Commit | Note |
|---|---|---|---|---|---|
| T1 | Prefactor: the findings store stops keying on the pattern's name | completed | continue | — | |
| T2 | Pure: the draft and its two conversions | completed | continue | — | |
| T3 | The document holds the draft, with undo | completed | **owner stop** | commit | |
| T4 | Pure: the reference graph, and the delete and move refusals | completed | continue | — | |
| T5 | Pure: the value edits, the header edits, and the refusal messages | completed | checkpoint | commit | material alteration ↓ |
| T6 | Editable tier-table cells, and refusals the owner can see | completed | **owner stop** | commit | two material alterations ↓ |
| T7 | Add, delete and move a tier | awaiting owner | **owner stop** | commit | |
| T8 | The Pattern and Notes cards | not started | **owner stop** | commit | |
| T9 | Close out | not started | **owner stop** | commit + push | |

**T1 — Prefactor: the findings store stops keying on the pattern's name**

- **Files:** `CuttingBench/CuttingBench/BenchFindingsStore.swift` (edit)
- **Done when:**
  - `checkedName` and its doc comment are gone, and the `if pattern?.name != checkedName` block at
    `:41`–`:44` is gone with them.
  - The comment at `:16`–`:17` says the kept geometric result now survives every edit to the open
    document and is cleared only when there is no pattern to check.
  - `grep -n "checkedName" CuttingBench/CuttingBench/BenchFindingsStore.swift` finds nothing.
  - Both `swiftc -typecheck` runs above are clean, `-DDEBUG` and without.
- **Do not:** touch the `generation` counter, the `running` task, `accept`, or the `guard let pattern, let
  solution` path at `:46`. Only the name key goes. In particular do not start caching anything per tier —
  this is a deletion.

**T2 — Pure: the draft and its two conversions**

First because everything else rests on it, and because the one thing that could invalidate the rest is
whether a draft round-trips a real authored pattern without changing what the display solves.

- **Files:** `CuttingBench/BenchGeometry/Sources/BenchGeometry/PatternDraft.swift` (new),
  `CuttingBench/BenchGeometry/Tests/BenchGeometryTests/PatternDraftTests.swift` (new)
- **Done when:**
  - `swift test --package-path CuttingBench/BenchGeometry --disable-sandbox` passes, including these
    cases:
    - For each of the four names in `AuthoredPatterns.all`: `PatternDraft(pattern).displayPattern` equals
      the loaded pattern, and `completePattern()` is `.success` with the same value. **Equality is
      `Pattern`'s own `Equatable`**, which compares the tiers as an ordered array, so this is the
      every-field-and-same-order check.
    - `PatternDraft.empty.displayPattern` is `nil`; `PatternDraft.empty.completePattern()` is
      `.failure(.noTiers)`.
    - A draft built from `Easy Octagon` with `tiers[3].meet` set to `nil` — `C1` — has a
      `displayPattern` whose `tiers.map(\.tier)` is `["G1", "P1", "P2", "C2", "T"]`, and a
      `completePattern()` of `.failure(.tiersWithoutMeet(["C1"]))`.
    - A draft with **two** meets cleared reports both labels **in file order** in that one failure.
    - `position(ofTier:)` finds every label of `Novice Ash-er` at its file position and is `nil` for
      `"nope"`.
    - `wheel(of:)` returns the draft's gear for a tier declaring none and the tier's own where it does.
    - `draftSummary` returns exactly `"draft 0 tiers · no tiers yet"` for `.empty`,
      `"draft 6 tiers · complete"` for `Easy Octagon`, and `"draft 6 tiers · no meet yet: P2, C1"` for a
      draft with those two cleared.
    - **All eleven `DraftRefusal.message` strings** match the table in the Approach section, character
      for character, with the example values that table uses.
  - `xcrun swift-format lint --recursive --strict …` is clean over the paths in the gate list.
- **Do not:** add any edit function or any reference-graph query — those are T4 and T5. Do not touch
  `Kernel/`, and do not add a `CaseIterable` conformance to `Part`. Do not make `displayPattern` sort,
  filter or regroup anything but the meet-less tiers.

**T3 — The document holds the draft, with undo**

The thinnest end-to-end path: the draft becomes the document's stored state and everything on screen keeps
reading exactly what it read before, through `displayPattern`.

- **Files:** `CuttingBench/CuttingBench/PatternDocument.swift` (edit),
  `CuttingBench/CuttingBench/BenchWindow.swift` (edit),
  `CuttingBench/CuttingBench/BenchRegions.swift` (edit — `StatusStripRegion` only)
- **Done when:**
  - `PatternDocument` stores `@Published var draft: PatternDraft` and exposes `pattern` as a computed
    `draft.displayPattern`, with `Snapshot` now `PatternDraft`.
  - `fileWrapper` switches on `completePattern()` and throws `DraftSaveError` on `.failure`, whose
    `failureReason` is the refusal's `message`.
  - `apply(_:undoManager:actionName:)` exists as described in the Approach. **It has no caller yet** —
    T6 is the first — and that is expected rather than dead code to remove.
  - `StatusStripRegion` takes `draftLine` inside `#if DEBUG` and appends it to `documentSummary`;
    `BenchWindow` passes `draftSummary(document.draft)`.
  - Both `swiftc -typecheck` runs are clean, `-DDEBUG` and without.
  - `grep -n "document.pattern" CuttingBench/CuttingBench/BenchWindow.swift` still finds every call site
    it finds today — the regions are not rewired to the draft in this task.
- **Do not:** add the refusal presenter, the alert, the edit funnel, or any editable control. Do not
  change `TierTableRegion` or `InspectorRegion`. Do not change `benchSolid`, `tierTableRows`,
  `findingsReadout` or any other pure function's signature — the whole point of the computed `pattern` is
  that they do not need to know.
- **Verification handle** — `permanent`:
  - **Where:** the status strip at the bottom of the window, `#if DEBUG` only, at the right-hand end of
    the existing summary that reads `Easy Octagon · finished · 6 tiers · 37 facets …`. The new segment is
    the last thing on that line.
  - **Positive:** open `Design/Patterns/Pattern-Easy-Octagon.json` → the line ends
    `· draft 6 tiers · complete`, and the stone, the tier table, the metrics and the findings line all
    read exactly as they did before this task. File ▸ New → the line ends `· draft 0 tiers · no tiers
    yet` and the window shows the bare prism.
  - **Negative:** with `Easy Octagon` open, enter playback and scrub to the first step → the drawn stone
    changes but the segment **stays** at `draft 6 tiers · complete`, because playback is a display state
    and not a draft edit. Orbiting and the opacity slider leave it unchanged too.
  - **Reads:** `draftSummary` and `PatternDraft.completePattern()` in
    `CuttingBench/BenchGeometry/Sources/BenchGeometry/PatternDraft.swift`, through
    `PatternDocument.draft`.

**T4 — Pure: the reference graph, and the delete and move refusals**

- **Files:** `CuttingBench/BenchGeometry/Sources/BenchGeometry/DraftReferences.swift` (new),
  `CuttingBench/BenchGeometry/Sources/BenchGeometry/DraftEdits.swift` (new),
  `CuttingBench/BenchGeometry/Tests/BenchGeometryTests/DraftEditsTests.swift` (new)
- **Done when:**
  - `DraftEdits.swift` holds `deleting(tier:from:)` and `moving(tier:by:in:)` and nothing else yet.
  - `swift test --package-path CuttingBench/BenchGeometry --disable-sandbox` passes, including these
    cases over a draft of `Easy Octagon`:
    - `tiersNaming(tier: "G1", in:)` is `["P2", "C2"]` — in file order, and **not** `C1` or `T`, neither of
      which names a `G1` facet.
    - `tiersNaming(tier: "G1", index: 12, in:)` is `["P2", "C2"]`; `index: 0` is `["P2"]`; `index: 24` is
      `["C2"]`; `index: 36` is `[]`.
    - `tiersNamed(by:)` for `C2` is `["G1", "C1"]`, deduplicated and in first-named order.
    - `deleting(tier: "G1", from:)` is `.failure(.tierReferenced(tier: "G1", by: ["P2", "C2"]))`.
    - `deleting(tier: "T", from:)` is `.success`, and the result's `tiers.map(\.tier)` is
      `["G1", "P1", "P2", "C1", "C2"]` with every other tier untouched.
    - `deleting(tier: "nope", from:)` is `.success` with the draft unchanged.
    - `moving(tier: "P2", by: -1, in:)` is `.failure(.moveWouldPointForward(tier: "P2", named: "P1"))` —
      `P2`'s meet names `P1@0` as well as two `G1` facets, and `P1` is the tier it would move ahead of.
    - `moving(tier: "C2", by: 1, in:)` is `.failure(.moveWouldPointForward(tier: "T", named: "C2"))`.
      Swapping `C2` and `T` leaves `T` naming `C2@18` while `C2` is now cut later, so the first violation
      the walk finds belongs to `T` rather than to the tier that moved.
    - `moving(tier: "C1", by: -1, in:)` is `.success`, and the result's `tiers.map(\.tier)` is
      `["G1", "P1", "C1", "P2", "C2", "T"]`. A harmless move: `C1`'s meet is `girdle` and names nothing,
      and every meet that names `C1` — `C2` and `T` — still sits after it.
    - `moving(tier: "G1", by: -1, in:)` and `moving(tier: "T", by: 1, in:)` are both `.success` with the
      draft unchanged — a move off either end.
  - `xcrun swift-format lint --recursive --strict …` is clean over the paths in the gate list.
- **Do not:** add any other edit function, and do not touch `PatternDraft.swift`, the app target or
  `Kernel/`. Do not filter a tier's own label out of `tiersNamed(by:)` — the kernel already reports
  `namesOwnFacet` and this file's job is the graph, not the judgement.

**T5 — Pure: the value edits, the header edits, and the rename rewrite**

- **Files:** `CuttingBench/BenchGeometry/Sources/BenchGeometry/DraftEdits.swift` (edit),
  `CuttingBench/BenchGeometry/Tests/BenchGeometryTests/DraftEditsTests.swift` (edit)
- **Done when:**
  - Every remaining function in the Approach's list exists, with exactly the rules written there.
  - `swift test --package-path CuttingBench/BenchGeometry --disable-sandbox` passes, including these
    cases over a draft of `Easy Octagon` unless stated otherwise:
    - **Rename propagates.** `renaming(tier: "G1", to: "GDL", in:)` is `.success`; the result's first
      tier is labelled `GDL`, `P2`'s meet is `.vertex(facets: [GDL@0, GDL@12, P1@0])` and `C2`'s is
      `.vertex(facets: [GDL@12, GDL@24, C1@12])`, with the facet **order inside each triple unchanged**.
    - `renaming(tier: "G1", to: "  P1 ", in:)` is `.failure(.duplicateTierLabel("P1"))` — the label is
      trimmed before it is compared. `renaming(tier: "G1", to: "   ", in:)` is
      `.failure(.emptyTierLabel)`. `renaming(tier: "G1", to: "G1", in:)` is `.success` with the draft
      unchanged.
    - A rename on a draft of `Novice Ash-er`, whose meets are `fraction`s, rewrites the labels **inside
      both endpoints** — build it, rename `G` to `GG`, and assert `P2`'s meet is
      `.fraction(from: .vertex([GG@12, GG@24, P1@24]), percent: …, to: .tcp)` with the percentage
      unchanged.
    - **Angle.** `setting(angle: "43.5", ofTier: "P2", in:)` is `.success` with `angle == 43.5`;
      `"forty"` is `.failure(.notANumber(field: "angle", typed: "forty"))`; `" 12 "` is `.success`;
      `"120"` is **`.success`** — an angle past 90 is a geometric consequence and is reported by the
      solve, not refused here (D10).
    - **Indices.** `setting(indices: "0, 12,24", ofTier: "C2", in:)` is `.success` with `[0, 12, 24]`.
      `"12 0 84"` is `.success` and stores that **order verbatim**. `"0 12.5"` is
      `.failure(.indicesNotWholeNumbers(typed: "0 12.5"))`. `"0 96"` is
      `.failure(.indexOutOfRange(tier: "C2", index: 96, wheel: 96))`. `"0 -1"` is the same case with
      `index: -1`. `""` is `.success` with `[]`.
    - **A removed stop that is named is refused.** `setting(indices: "0 24 36 48 60 72 84", ofTier: "G1",
      in:)` — dropping stop 12 — is `.failure(.stopReferenced(tier: "G1", index: 12, by: ["P2", "C2"]))`.
      Dropping stop 36 instead is `.success`, because nothing names it.
    - **Part.** `setting(part: .crown, ofTier: "P2", in:)` is `.success` — always allowed even though
      `P2`'s facets are named by nothing and it names three (D7).
    - **Instructions.** `setting(instructions: "", ofTier: "G1", in:)` stores `""` and **not** `nil`;
      `setting(instructions: "level girdle", …)` stores that string.
    - **Meet.** `setting(meet: nil, ofTier: "P2", in:)` is `.success` and the resulting draft's
      `displayPattern` has five tiers; `setting(meet: .girdle, ofTier: "P2", in:)` replaces the vertex.
    - **Append.** `appendingTier(to:)` on `Easy Octagon` gives a seventh tier `N1`, `.pav`, `0`, `[]`,
      `nil` meet, `nil` instructions; applied twice more the labels are `N2` and `N3`; on a draft that
      already has an `N1` the next is `N2`.
    - **Header.** `setting(ri: "2.16", in:)` is `.success`; `"quartz"` is
      `.failure(.notANumber(field: "refractive index", typed: "quartz"))`.
      `setting(girdleTarget: "", in:)` sets `nil`; `"  "` sets `nil`; `"0.05"` sets `0.05`; `"0"` is
      `.failure(.girdleTargetNotPositive(typed: "0"))`; `"-0.01"` is the same case;
      `"thick"` is `.failure(.notANumber(field: "girdle target", typed: "thick"))`.
      `setting(name:)`, `setting(designer:)` and `setting(notes:)` store their string verbatim, including
      leading and trailing whitespace.
    - **Nothing reorders.** For every function above, on every `.success`, `result.tiers.map(\.tier)` is
      the same sequence as the input's except where `moving` or `deleting` or `appendingTier` was the
      edit (D9).
  - `xcrun swift-format lint --recursive --strict …` is clean over the paths in the gate list.
- **Do not:** touch the app target, `PatternDraft.swift`, `DraftReferences.swift` or `Kernel/`. Do not add
  a validity rule the Approach does not name — in particular do not clamp or range-check an angle, an
  `ri`, or the size of an index list.
- **Material alteration.** Three of this task's index-stop cases name `C2` as the tier whose list is
  retyped — `"0, 12,24"`, `"12 0 84"` and `""`, each expected to succeed. They cannot: `T`'s meet names
  `C2@18`, so retyping `C2`'s list at all drops stop 18 and the stop-reference rule this same task
  specifies refuses it. The three were written to check the parsing — comma and whitespace splitting, order
  preserved, an empty list accepted — so they now read `P2`, the one tier of `Easy Octagon` whose stops
  nothing names. Every rule, every other case and the dedicated stop-reference case are unchanged, and the
  out-of-range and non-whole-number cases still read `C2` as written, because both are refused before the
  stop-reference check runs.

**T6 — Editable tier-table cells, and refusals the owner can see**
- **Files:** `CuttingBench/CuttingBench/RefusalPresenter.swift` (new),
  `CuttingBench/BenchGeometry/Sources/BenchGeometry/TierTable.swift` (edit),
  `CuttingBench/BenchGeometry/Tests/BenchGeometryTests/TierTableTests.swift` (edit),
  `CuttingBench/CuttingBench/BenchWindow.swift` (edit),
  `CuttingBench/CuttingBench/BenchRegions.swift` (edit)
- **Done when:**
  - `tierTableRows` takes `draft: PatternDraft` in place of `pattern: Pattern?`, exactly as the Approach
    describes, and a tier with no meet gets a row whose `meet` is `"—"`, whose `meetPoints` is empty and
    whose `state` is `.notReached`.
  - `swift test --package-path CuttingBench/BenchGeometry --disable-sandbox` passes with **every existing
    assertion in `TierTableTests.swift` unchanged** — only the `pattern:` argument becomes `draft:`. Add
    one case: a draft of `Easy Octagon` with `C1`'s meet cleared gives six rows, `C1`'s reading `—` with
    `state == .notReached`, and every other row still `.solved`.
  - `RefusalPresenter` exists as described, logging at `.notice` with `privacy: .public` to subsystem
    `DigitalEnki.CuttingBench`, category `refusals`, and exposing `isPresented` as a `Binding<Bool>`.
  - `BenchWindow` holds the presenter and the undo manager, has the `edit(_:_:)` funnel, carries the
    `.alert` on its root `VStack`, and passes `draft:` to both `tierTableRows` and `TierTableRegion`.
  - `TierTableRegion` takes `draft` and `edit`, and the Tier, Part, Angle, Indices, Meet and Instructions
    columns are editable exactly as the Approach describes. The Wheel column is still read-only text.
  - The `selection` binding's doc comment at `:145` no longer claims nothing is edited through it.
  - Both `swiftc -typecheck` runs are clean, `-DDEBUG` and without.
- **Do not:** add the Add, Delete, Move Up or Move Down buttons — that is T7. Do not touch
  `InspectorRegion`. Do not make the Wheel column editable. Do not add a Validate button, a save
  prompt, or any second place a refusal is shown. Do not change `meetPointDots`, `findingsReadout`,
  `lightReadout` or `benchSolid` — they keep taking a `Pattern?`, and the window keeps handing them
  `document.pattern`.
- **Material alteration.** The added case names `C1` as the tier whose meet is cleared and expects every
  other row to stay `.solved`. It cannot: `C2` and `T` both name `C1`, so dropping `C1` from the display
  pattern stops the solve at `C2`, leaving `C2` `.stopped` and `T` `.notReached`. The case is now two.
  `P2` — the one tier nothing names — carries the shape as written, six rows with `P2` reading `—` and
  `.notReached` and every other row `.solved`. A second case keeps `C1` and asserts what actually happens,
  because a cleared meet cascading into the tier that names it is worth pinning rather than losing.
- **Material alteration.** The Approach makes the Meet cell's `Menu` label the existing dots-and-facets
  content. SwiftUI renders only the first element of a composed `Menu` label, so the cell read `M` with
  `G1@0 · G1@12 · P1@0` nowhere on screen — the column stopped saying what a meet is, and positive check ②
  could not be performed. **The meet content is now an ordinary cell again, rendering exactly as it did
  before this task, and the four-way menu is a chevron button beside it** with the style's own indicator
  hidden. Approved by the owner. Every rule about which four forms are offered is unchanged; only where the
  control sits moved.
- **Verification handle** — `permanent`:
  - **Where:** the tier table, with `Design/Patterns/Pattern-Easy-Octagon.json` open. Every cell of the
    Tier, Part, Angle, Indices, Meet and Instructions columns is now a field, a menu or a popup, edited in
    place; a refusal arrives as a modal alert titled **Edit refused**, and the same sentence is in
    `log stream --predicate 'subsystem == "DigitalEnki.CuttingBench"'` in Terminal.
  - **Positive, three of them.** ① Click `P2`'s Angle cell, type `40`, press Return → the cell reads
    `40.00`, the drawn stone changes, and **`P2`'s row gains the orange light-leak mark reading `0.49°`**,
    because 40.00° now sits below quartz's critical angle of 40.49° — the Light card lists `P2` with it.
    ⌘Z → `43.00`, the mark gone, and the stone back. ② Click `G1`'s Tier cell, type `GDL`, Return → the
    label changes **and `P2`'s and `C2`'s Meet cells now read `GDL@0 · GDL@12 · P1@0` and
    `GDL@12 · GDL@24 · C1@12`** beside their `M` chips; the stone does not change. ③ Click `G1`'s Indices
    cell, delete the `12`, Return → the alert reads *"Index stop 12 cannot be removed from G1: it is named
    by P2, C2. Re-aim or remove those meets first."*, the cell **snaps back to the full list**, and the log
    carries that sentence.
  - **Negative:** with the alert dismissed, type `level girdle` into `G1`'s Instructions cell and press
    Return → the cell shows it, and the stone, the Metrics card and the findings line are all
    **unchanged** from before the edit. Then open `P1`'s Meet menu and choose `tcp`, which it already is →
    nothing changes anywhere, and ⌘Z has nothing new to undo, because an edit equal to the current draft
    registers none.
  - **Reads:** `renaming(tier:to:in:)` and `setting(indices:ofTier:in:)` in
    `CuttingBench/BenchGeometry/Sources/BenchGeometry/DraftEdits.swift`, and `DraftRefusal.message` in
    `PatternDraft.swift`, through `PatternDocument.apply` and `RefusalPresenter.present`.

**T7 — Add, delete and move a tier**

- **Files:** `CuttingBench/CuttingBench/BenchRegions.swift` (edit — `TierTableRegion` only),
  `CuttingBench/CuttingBench/BenchWindow.swift` (edit — one line)
- **Done when:**
  - `TierTableRegion`'s `body` becomes the `VStack(spacing: 0)` of button row, `Divider()` and the existing
    `Table`, described in the Approach. T6 left the `Table` as the whole body; this is where it gains a
    sibling.
  - The four buttons exist above the table, with the labels, symbols, enablement rules and actions in the
    Approach's table.
  - Delete, Move Up and Move Down are disabled with no selection; Move Up is disabled on the first row and
    Move Down on the last, worked out through `draft.position(ofTier:)` and `draft.tiers.count`.
  - `BenchWindow.swift:68` (`.frame(minHeight: 140)`) becomes `.frame(minHeight: 180)`, so the button row
    does not eat the rows the table had.
  - Both `swiftc -typecheck` runs are clean, `-DDEBUG` and without.
- **Do not:** add a keyboard shortcut, a context menu, drag-to-reorder, or an insert-above command. Do not
  touch `InspectorRegion`. Do not make Delete ask for confirmation — a refused delete already explains
  itself and an accepted one is one ⌘Z away.
- **Verification handle** — `permanent`:
  - **Where:** the row of four buttons directly above the tier table, with
    `Design/Patterns/Pattern-Easy-Octagon.json` open.
  - **Positive, three of them.** ① Select `G1`, click **Delete Tier** → the alert reads *"G1 cannot be
    deleted: its facets are named by P2, C2. Re-aim or remove those meets first."* and the table still has
    six rows. Now select `P2` — the one tier of this pattern nothing names — and click Delete → five rows,
    and the **Facet Count card's `Solved` row goes from `37` to `29`**, the eight `P2` facets being what
    went. ⌘Z → six rows and `37` again. ② Click **Add Tier** → a seventh row appears at the bottom
    reading `N1`, `pav`, `0.00`, empty Indices, `—` in Meet, and greyed as not reached; the stone and the
    facet count are **unchanged**, because a tier with no meet is not part of what is solved and the
    derived pattern is therefore identical. ③ Select `C1`, click **Move Up** → the order becomes
    `G1 P1 C1 P2 C2 T` and the stone and the facet count are unchanged, since nothing that names `C1` moved
    ahead of it. Select `C2` and click **Move Down** → the alert reads *"T cannot move there: T's meet names
    C2, and a meet may only name a tier cut earlier."* and the order is untouched.
  - **Negative:** with `T` selected, **Move Down** is greyed out, and with `G1` selected **Move Up** is
    greyed out; with nothing selected all three of Delete, Move Up and Move Down are greyed and **Add
    Tier** is still live. Clicking a greyed button changes nothing and writes no log line.
  - **Reads:** `appendingTier(to:)`, `deleting(tier:from:)` and `moving(tier:by:in:)` in
    `CuttingBench/BenchGeometry/Sources/BenchGeometry/DraftEdits.swift`, and
    `PatternDraft.position(ofTier:)` for the enablement.

**T8 — The Pattern and Notes cards**

- **Files:** `CuttingBench/CuttingBench/BenchRegions.swift` (edit — `InspectorRegion`, `PatternCard`,
  `NotesCard`, `EditableCell`), `CuttingBench/CuttingBench/BenchWindow.swift` (edit — the
  `InspectorRegion` call site)
- **Done when:**
  - `InspectorRegion` takes `draft` and `edit`; the two `EmptyCard()` placeholders are replaced by
    `PatternCard` and `NotesCard`, with the six rows in the Approach's order and no others.
  - `EditableCell` gains `axis` and `commitsOnReturn`, both defaulted, and every existing use is unchanged
    by the addition.
  - The girdle-target field shows four decimal places and is empty when the value is absent; the RI field
    shows three.
  - `EmptyCard` still exists and is still used by whatever card has nothing to show.
  - Both `swiftc -typecheck` runs are clean, `-DDEBUG` and without.
- **Do not:** make `state` or the header Gear editable (D14, and the *Explicitly not doing* section). Do
  not add a `formatVersion` control. Do not move, reorder or restyle the Metrics, Light or Facet Count
  cards — `Pattern` first and `Notes` directly below it is the app shell's ordering and is not this task's
  to change.
- **Verification handle** — `permanent`:
  - **Where:** the inspector's `Pattern` and `Notes` cards down the trailing edge of the window, with
    `Design/Patterns/Pattern-Easy-Octagon.json` open. They read `Easy Octagon`, `finished`, `96`, `1.540`,
    `0.0337` and the USFG attribution.
  - **Positive, three of them.** ① Type `2.160` into RI, press Return → the **Light** card's critical angle
    changes from `40.49°` to `27.58°`, and the tier table's light-leak marks change with it. ⌘Z → back to
    `1.540` and `40.49°`. ② Clear the Girdle target field entirely, Return → it stays empty, and the
    Metrics card's girdle figures move, because absent means the default of 0.04 rather than the diagram's
    0.0337. Type `0` → the alert reads *"A girdle target has to be greater than zero. Leave the field
    empty for the default of 0.04."* and the field snaps back to empty. ③ Type into Notes and click away →
    the text stays, and the window title still reads `Easy Octagon`.
  - **Negative:** type a new name into Name and press Return → the window title follows it, and the
    **findings line at the bottom of the window does not blank or reset** — it reads exactly what it read
    before, which is the prefactor in T1 doing its job. The stone, the Metrics card and the Light card are
    unchanged by the rename, and so is the Designer field's own text.
  - **Reads:** `setting(ri:in:)`, `setting(girdleTarget:in:)`, `setting(name:in:)` and
    `setting(notes:in:)` in `CuttingBench/BenchGeometry/Sources/BenchGeometry/DraftEdits.swift`, through
    `PatternDocument.apply`.

**T9 — Close out**

- **Delete the temporary handles: none.** Every handle in this plan is `permanent`. The draft summary in
  the status strip stays behind `#if DEBUG`, where the playback frame counter beside it already lives.
- **Confirm each Deferred item has a ticket** in `Design/Tickets/`, `Status: untriaged`. The executor filed
  each as it found it, per the protocol; this is the check, not the filing.
- **Report the untriaged ticket count** in `Design/Tickets/`, one line.
- **Save a copy and reopen it. Never over an authored pattern.** The four files in `Design/Patterns/` are
  external ground truth and the protocol forbids editing them, so this uses **File ▸ Save As** to
  `~/Desktop/Octagon-Check.json` and nothing else. With `Design/Patterns/Pattern-Easy-Octagon.json` open,
  change `P2`'s angle to `43.50`, Save As to that path, close the window, open the saved file → the tier
  table reads `43.50`, the tier order is `G1 P1 P2 C1 C2 T`, and the Pattern card reads `Easy Octagon`,
  `96`, `1.540`, `0.0337` and the same designer text. Then:
  `swift run --package-path Kernel facetsolve ~/Desktop/Octagon-Check.json --json` runs and reports the
  same findings the app's own status strip shows. Delete the file afterwards.
  **The saved bytes will not match the authored file and must not be expected to** — `Pattern.swift:275`
  encodes with `.sortedKeys`, and the format leaves formatting loose on purpose. Equality after decode is
  the bar; matching bytes is not.
- **Add a tier and try to save.** Click Add Tier, then Save As → the save fails with *"This pattern cannot
  be saved yet."* and the reason *"This pattern cannot be saved yet: N1 has no meet. Choose one for each,
  or delete the tier."* Delete `N1` and confirm the save then succeeds.
- `commit + push` with the message below.
- **Archive nothing and close no ticket.** This is not the final part: the exploration
  `4-Cutting-Bench-Authoring` is the source for four more plans and stays live, and
  `Chore-Validation-Rebuilds-The-Solid-Once-Per-Tier` is closed by the last part. This plan is not
  archived either — the final part archives itself, every sibling part by name, the exploration and the
  ticket.
- **Update this plan's own `Status:` line** to say part 1 completed, with the date.

```
4-cutting-bench-authoring-1 T9: close out the draft slice

- Save-as-and-reopen round trip confirmed on a scratch copy, equal after decode
- Deferred items filed as untriaged tickets; nothing archived, this is not the last part
```

## Deferred

Empty at authoring. The executor appends adjacent problems it found and must not fix — and files each as a
ticket in `Design/Tickets/` immediately with `Status: untriaged`, per the protocol.

- **The sandbox is read-only for user-selected files, so every save panel crashes the app.**
  `ENABLE_USER_SELECTED_FILES = readonly` in both configurations. Filed as
  `Bug-Save-Panel-Crashes-On-A-Read-Only-Sandbox`. **This blocks T9**, whose whole check is a Save As to a
  scratch path and a reopen, and it blocks the save-refusal check at the end of T9 too. Fixing it is a
  capability change, which the protocol's guardrails reserve to the owner.
- **The document autosaves in place, so editing an opened pattern rewrites it.** Filed as
  `Bug-Autosave-In-Place-Rewrites-The-File-That-Was-Opened`. Every verification handle in this plan says to
  open `Design/Patterns/Pattern-Easy-Octagon.json` and edit it, which once the sandbox is read/write will
  write over external ground truth — a guardrail violation the plan's own *"never save over
  `Design/Patterns/`"* rule assumed could not happen, because it assumed saves are explicit. **Verification
  must run on a copy outside `Design/Patterns/`.**
- **The Meet column's menu label does not render the meet.** `TierTableRegion`'s Meet cell put the dots
  and their facet text inside a `Menu`'s label, per the Approach, and SwiftUI renders only the first chip —
  so `M` showed and `G1@0 · G1@12 · P1@0` did not. **Corrected in T6** with the owner's approval: the meet
  content is an ordinary cell and the menu is a button beside it. No ticket — fixed rather than deferred.









