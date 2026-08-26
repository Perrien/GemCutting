# 4 · Cutting Bench Authoring — 3 · Symmetry And Wheel

Status: **PART 3 COMPLETED** 2026-08-26. Archives nothing and closes no ticket — the exploration
`4-Cutting-Bench-Authoring` is still the design source for parts 4 and 5, and
`4-Cutting-Bench-Authoring-5-Fraction-Meets` archives this set.

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
   out-of-range refusal. ← this part
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
| U13 | 1 — **restated in 2, 3, 4 and 5**, each of which adds refusals |

**One boundary clarification against part 2's copy.** The rule that a tier's index gear is chosen from a
popup names only the tier table's Wheel column, but part 1 held back **both** that column and the
inspector's header Gear row, on the grounds that a gear change has to refuse the stops it would put out
of range and that the two are one topic. That topic is this part, so **the header Gear row lands here
too** — the same refusal, applied to every tier that declares no gear of its own. Nothing else moved:
every ID sits where the owner agreed.

## Context

Transcribing a printed faceting sheet means typing a tier's index stops. `Easy Octagon`'s girdle tier is
`0 12 24 36 48 60 72 84` and the round brilliant's is sixteen stops six apart — both are one seed stop
repeated around the wheel, and typing them out is the part of authoring that is pure clerical work with a
real chance of a typo in the middle of it. The owner wants to say *this stop, eight-fold, mirrored* and
have the eight numbers appear.

The wheel is the other half. A tier may be cut on its own gear rather than the design's, and lowering a
gear can put an existing stop out of range — 100 is a valid stop on 120 and rejected on 96. Today both the
Wheel column and the header Gear row are read-only text, which is the one editable-looking field in the
window that does nothing.

**What is already there.** All of it is the shipped code of parts 1 and 2:

- **The draft, and one funnel every edit goes through.** `BenchWindow.swift:176`
  (`private func edit(_ actionName: String, _ change: DraftChange) -> Bool {`) applies a change, registers
  its undo, and presents the refusal. Returning `false` is what an editable cell reverts on.
- **A refusal is a value with a sentence.** `PatternDraft.swift:179`
  (`public enum DraftRefusal: Error, Equatable, Sendable {`), each case carrying the element at fault, with
  one wording used by both the alert and the log (`RefusalPresenter.swift:26`,
  `log.notice("\(sentence, privacy: .public)")`).
- **The index-stop setter already holds both checks this part needs.** `DraftEdits.swift:125`
  (`public func setting(indices typed: String, ofTier tier: String, in draft: PatternDraft)`) refuses a
  stop outside the tier's effective gear at `:140` (`for index in indices where index < 0 || index >= stops {`)
  and refuses removing a stop a later meet names at `:146` (`let kept = Set(indices)`). The symmetry
  controls and the gear popup write a stop list too, so they need exactly these two checks and no new ones.
- **The effective gear is one function.** `PatternDraft.swift:152`
  (`public func wheel(of tier: DraftTier) -> Int {`) — the tier's own if it declares one, otherwise the
  draft's, mirroring the kernel's own rule.
- **The tier table is formatted outside the view.** `TierTable.swift:87`
  (`public func tierTableRows(`) turns the draft into rows of already-formatted strings, and every format
  is checked without a window. The Wheel cell is `:126` (`wheel: String(draft.wheel(of: spec)),`) with
  `:127` (`wheelIsInherited: spec.wheel == nil,`).
- **A popup in a table cell has an exemplar.** `BenchRegions.swift:225` (`TableColumn("Part") { row in`)
  is a `Picker` whose binding reads the draft, so a refused change needs no revert code — the next body
  pass reads the old value back. `BenchRegions.swift:351` (`private struct EditableCell: View {`) is the
  same trick for a text field, committing on Return or focus loss.
- **The per-tier findings cache already handles a gear change.** `FindingsCache.swift:22`
  (`previous.wheel == next.wheel,`) keeps nothing when the header gear moves, and a per-tier gear change
  differs at that tier's own spec, so the surviving prefix stops there. **This part adds no cache work.**

**Why this is small.** The generator is one pure function and its inverse, over integers mod the wheel; the
edits it feeds are the existing stop-list setter with a different source for the list; and the two popups
are the Part column's own idiom twice. Nothing new is stored, so there is no new state to keep consistent,
no migration, and nothing for undo to get wrong.

## Decisions (2026-08-26)

| # | Decision |
|---|---|
| D1 | **The draft is the app's and the kernel writes the file** (**ADR-0003**). Everything this part adds is a draft edit or a derived display; nothing reaches `FacetKernel`. |
| D2 | **Nothing symmetry-shaped is stored anywhere** — not in the file, not in the draft, not in session state. `design-authoring-format.md:105` (`Symmetry is not stored at all, not even as a generator. A tool may expand a seed set plus a symmetry`) is explicit, and what lands in the file is the full index list. **So folds, mirroring and the seed set are all derived from the tier's own stop list, every time.** The consequence is that there is no generator mode to keep in sync, nothing for undo to restore beyond the stops themselves, and no way for the controls to disagree with the tier. |
| D3 | **Folds is the largest divisor `n` of the tier's effective gear such that rotating the stop set by `gear / n` maps it onto itself.** Mirroring is whether reflecting every stop `i` to `(gear − i) mod gear` maps the set onto itself. **The two are determined independently** — each is a property of the set, and neither is chosen in preference to the other. |
| D4 | **An empty stop list reads 1 fold, mirroring off, no seeds**, by special case: every rotation maps the empty set onto itself, so D3's rule would read the whole gear as the fold count. A tier appended by the Add Tier button has no stops (`DraftEdits.swift:73`), so this is the state of every new tier. |
| D5 | **The seeds are the smallest member of each orbit of the stop set**, in ascending order, under the group generated by whichever of the two generators D3 found. Computed by reusing the expansion itself: a stop's orbit is what that stop alone expands to. So the seeds shown always regenerate exactly the stops the tier has. |
| D6 | **A generated stop list is written ascending.** Verified against every authored pattern: `Pattern-Easy-Octagon.json:15` (`"indices": [0, 12, 24, 36, 48, 60, 72, 84],`), and the other three the same. The rotated orders quoted in the corpus discussion — `8 40 48 56 88 0` — are a printed sheet's reading order, not what any file holds. **Part 1's rule that a *typed* list keeps the order it was typed in is untouched**: this governs only a list the generator produced. |
| D7 | **"Raw mode, generator off" is not a flag.** A stop set that no rotation and no reflection maps onto itself derives as 1 fold, mirroring off, and seeds equal to the stops — so the expansion is the identity and the generator is transparently off. Editing `indices` directly, which part 1 already allows, re-derives all three controls from the new set. **A tier whose stops are not symmetric therefore reads honestly as 1-fold** rather than as a broken generator. |
| D8 | **The folds control is a text field, and a value that does not divide the tier's effective gear is refused**, naming the gear and listing the fold counts that gear does reach. Generating an `n`-fold set means stepping by `gear / n`, so a count that does not divide would land between stops. **7-fold is reachable on 84 and impossible on 96.** The constraint is per tier, because a tier may override the gear. |
| D9 | **The seed field is refused for a piece that is not a whole number and for a seed outside the tier's gear**, with the wordings the Indices cell already uses — seeds *are* index stops, and a second sentence for the same fault is a second sentence that can drift. |
| D10 | **Every generator edit writes its expansion through the same code the Indices cell writes through**, so a regeneration that would remove a stop a later meet names is refused with the same sentence, naming the same dependents. Nothing is repaired and nothing is guessed: re-aiming those meets is the author's move. |
| D11 | **Column order is Seeds, Folds, Mirror, Indices**, inserted between Angle and Indices, so the row reads left to right as the generation itself — these seeds, expanded this many folds, optionally mirrored, giving these stops. |
| D12 | **The Wheel column becomes a menu popup of `inherit` plus the eight gears — 32, 64, 72, 80, 84, 88, 96, 120** (`design-authoring-format.md:72`, which also records that every one of them divides by 4). **Tagged by `String`, exactly as the Part column tags by `rawValue`** (`BenchRegions.swift:231`): the value is an `Int?` and an optional tag is the case that idiom exists to avoid. |
| D13 | **The `inherit` item's label carries the effective gear — `inherit (96)`.** The cell showed the effective gear before this part and a stop number means nothing without one, so the popup has to keep saying it. The tag stays the bare word, so the label can change without the selection moving. |
| D14 | **The popup also offers a gear the document already carries that is not one of the eight.** The kernel accepts any positive wheel (`Pattern.swift:249`), so a decoded file can hold 100, and a `Picker` whose selection matches no tag renders blank. The extra item is added for that document only and is never one of the eight. |
| D15 | **A gear change is refused when it would put any affected tier's existing stop out of range**, naming the offending stop with the existing out-of-range wording and the gear being moved to. A per-tier change affects that tier; **a header change affects every tier that declares no gear of its own**, and the first offending stop in file order is the one named. |
| D16 | **A gear change that leaves every stop in range is accepted, and never rewrites a single stop.** Every plane on the affected tiers moves — a 96-wheel `24` is not a 120-wheel `24` — and that is a geometric consequence, reported by the solve and the findings strip. Structural edits are refused; geometric ones are reported. `design-authoring-format.md:127` (`**\`wheel\` per tier is a gear change mid-cut**`) treats it as a real operation on a real machine. |
| D17 | **The header Gear popup offers no `inherit`.** The header gear is the design's default and has nothing above it to inherit from. |
| D18 | **Folds and mirroring are never refused for making a set less symmetric.** They only ever write a stop list, and nothing records what generated it, so there is no state that could become inconsistent. |
| D19 | **The findings cache and the quiet period need no work in this part.** `FindingsCache.swift:22` already keeps nothing across a header gear change, and a per-tier gear or stop change differs at that tier's spec so the surviving prefix stops there. Every edit here is an ordinary committed draft edit and rides the machinery part 2 shipped. |
| D20 | **Every refusal in this part states its reason, names the offending element, and goes through `RefusalPresenter`**, which is what puts it in the unified log at `.notice` — a case that came up once and was dismissed is still traceable afterwards. |
| D21 | **The Mirror cell is a `Toggle` whose binding reads the row, and the Seeds and Folds cells are `EditableCell`s.** A refused toggle needs no revert code for the same reason the Part popup needs none: the getter reads the draft, so an untouched draft springs the control back. A half-typed seed list means nothing to judge, which is why those two commit on Return or focus loss rather than per keystroke. |

## Tickets closed by this plan

None — closed in the final part. `Chore-Validation-Rebuilds-The-Solid-Once-Per-Tier` stays live until
part 5, and the exploration `4-Cutting-Bench-Authoring` stays live because it is the design source for
parts 4 and 5.

## Prefactoring

**One task, T1.** `setting(indices:)` at `DraftEdits.swift:125` holds the range check and the
reference check inside the function that parses a typed string. Four editors need those two checks
against a list they produced rather than parsed — seeds, folds, mirroring, and a gear change — so the
checks move to a private helper that takes a finished `[Int]` and the parsing stays where it is.

Behaviour-preserving, so its check is inverted: **nothing changes.** The existing coverage is already
tight enough to pin it, so no characterization tests are needed first —
`DraftEditsTests.swift:226` (`func testIndexStopsSplitOnWhitespaceAndCommasAlike() throws {`), `:235`
(order preserved), `:242` (not whole numbers, out of range), `:258` (an empty list accepted) and `:266`
(removing a named stop refused, an unnamed one not) cover every branch the helper takes over.

## Approach

One new pure file holds the gear arithmetic and the generator and its inverse. `DraftEdits.swift` gains
five setters that all funnel into the stop-list helper T1 extracts. `TierTable.swift` gains three derived
strings on the row. `BenchRegions.swift` gains three columns, turns the Wheel cell into a popup, and turns
the header Gear row into a popup. Nothing else in the app is touched.

### 1. New: `CuttingBench/BenchGeometry/Sources/BenchGeometry/TierSymmetry.swift` (pure — no framework, no I/O)

Integers modulo the wheel and nothing else. No `FacetKernel` import is needed; `import Foundation` is not
needed either.

```swift
// MARK: - The gears

/// The eight index gears, ascending (`design-authoring-format.md:72`). 96 and 120 are the common ones; 84
/// is what makes 7-fold possible and 72 what makes 9-fold possible, and every one of the eight divides by
/// 4, so a quarter turn is a whole number of stops on all of them.
public let indexGears = [32, 64, 72, 80, 84, 88, 96, 120]

/// The gears a popup offers: the eight, plus `current` if it is not one of them, ascending.
///
/// **The kernel accepts any positive wheel** (`Pattern.swift:249`), so a decoded file can carry 100, and a
/// `Picker` whose selection matches no tag renders blank rather than complaining. `nil` — a tier declaring
/// no gear of its own — adds nothing.
public func gearsOffered(including current: Int?) -> [Int]

/// The fold counts reachable on a gear: every divisor of `wheel`, ascending, `1` first.
///
/// Generating an n-fold set means stepping by `wheel / n`, so a count that does not divide the gear would
/// land between stops. Empty for a gear that is not positive.
public func foldCounts(onWheel wheel: Int) -> [Int]

// MARK: - The generator, and its inverse

/// What a tier's stop list says about its own symmetry. **Never stored** — derived from the stops every
/// time (D2), because the file holds no generator and neither does the draft.
public struct TierSymmetry: Equatable, Sendable {
  /// The smallest member of each orbit, ascending. Empty only for a tier with no stops.
  public var seeds: [Int]
  /// At least 1. `1` means no rotation maps the set onto itself, which is the generator being off.
  public var folds: Int
  /// Whether reflecting about index 0 maps the set onto itself.
  public var mirror: Bool

  public init(seeds: [Int], folds: Int, mirror: Bool)
}

/// The stop list a seed set generates: **ascending and without duplicates** (D6).
///
/// Mirroring is applied first and the rotation second, which generates the whole dihedral closure — every
/// element of the group is a rotation or a rotation of the reflection, so one pass of each is complete.
///
/// Empty for a gear that is not positive or a fold count below 1. Callers pass a fold count that divides
/// the gear; `setting(folds:ofTier:in:)` refuses one that does not (D8).
public func expandedStops(seeds: [Int], folds: Int, mirror: Bool, wheel: Int) -> [Int]

/// What a stop list's own symmetry is (D3, D4, D5).
///
/// **An empty list is 1 fold, not mirrored, no seeds** — every rotation maps the empty set onto itself, so
/// the general rule would read the whole gear as the fold count.
public func derivedSymmetry(stops: [Int], wheel: Int) -> TierSymmetry
```

**How each is built.**

- `gearsOffered(including:)` — `indexGears`, plus `current` when it is non-`nil` and not already among
  them, sorted ascending.
- `foldCounts(onWheel:)` — `wheel > 0` guarded, then `(1...wheel).filter { wheel % $0 == 0 }`. The
  largest gear is 120, so the linear scan is 120 steps at worst and nothing cleverer is warranted.
- `expandedStops` — guard `wheel > 0` and `folds >= 1`, else `[]`. Reduce each seed into `0..<wheel`.
  Mirror step: for each `s`, add `(wheel - s) % wheel` when `mirror`. Rotation step: `let step = wheel /
  folds`, and for each member add `(s + k * step) % wheel` for `k` in `0..<folds`. Collect in a `Set` and
  return it `.sorted()`.
- `derivedSymmetry` — guard `wheel > 0`, else the empty answer. Reduce every stop into `0..<wheel` as
  `((s % wheel) + wheel) % wheel` and take the `Set`; that reduction is a no-op for every list the app can
  hold, because decoding (`Pattern.swift:233`) and the stop setter both keep stops in range, and it makes
  the function total for any input. Empty set → `TierSymmetry(seeds: [], folds: 1, mirror: false)`.
  Otherwise:
  - `folds` — the **largest** count in `foldCounts(onWheel: wheel)` whose rotation maps the set onto
    itself: `Set(set.map { ($0 + wheel / n) % wheel }) == set`. `foldCounts` is ascending, so this is its
    last match, and `1` always matches, so there is always an answer.
  - `mirror` — `Set(set.map { (wheel - $0) % wheel }) == set`.
  - `seeds` — walk the stops ascending, keeping a covered set. A stop not yet covered becomes a seed, and
    its orbit is added to covered as `expandedStops(seeds: [that stop], folds: folds, mirror: mirror,
    wheel: wheel)`. **Reusing the expansion is what guarantees the round trip**: the seeds shown expand
    back to exactly the stops the tier has, so nothing the author reads is a set they cannot regenerate.

### 2. `CuttingBench/BenchGeometry/Sources/BenchGeometry/DraftEdits.swift`

**The prefactor (T1).** `setting(indices:)` at `:125` keeps its parsing and hands the finished list to a new
private helper. Move `:139`–`:152` — the `let stops = draft.wheel(of: draft.tiers[position])` range check
and the `let kept = Set(indices)` reference check — plus the assignment at `:154`–`:156`, into:

```swift
/// The one place a tier's stop list is written: the range check, the reference check, and the assignment.
///
/// **Every editor that produces a stop list goes through here** — the Indices cell, the three symmetry
/// controls and neither gear popup — so a generated list is refused for exactly what a typed one is, in
/// exactly the same words (D10).
private func settingStops(_ stops: [Int], atPosition position: Int, in draft: PatternDraft)
  -> Result<PatternDraft, DraftRefusal>
```

It reads the tier label from `draft.tiers[position].tier` for its messages, so no second parameter carries
the same fact. `setting(indices:)` becomes: look up the position, parse the pieces, and
`return settingStops(indices, atPosition: position, in: draft)`. **Its doc comment stays as it is** — every
sentence in it is still true.

Also extract the parse, because the seed field splits a list the same way:

```swift
/// A typed stop list, split on whitespace and commas alike. `nil` for a piece that is not a whole number.
/// **Order and duplicates are preserved exactly as typed**, which is what the Indices cell needs; the
/// generator sorts its own output instead (D6).
private func parsedStops(_ typed: String) -> [Int]?
```

**The three symmetry setters.** Each reads the tier's current symmetry, replaces the one thing the author
changed, expands, and writes through `settingStops`. So each is five lines, and none of them repeats a
check.

```swift
// MARK: - Symmetry, which is generated and never stored

/// The stop list the typed seeds generate, at the folds and mirroring the tier's **current** stops derive.
///
/// Refused for a piece that is not a whole number, for a seed outside the tier's gear, and — through
/// `settingStops` — for a regeneration that would remove a stop a later meet names (D9, D10).
public func setting(seeds typed: String, ofTier tier: String, in draft: PatternDraft)
  -> Result<PatternDraft, DraftRefusal>

/// Refused for a value that is not a whole number, and for one that does not divide the tier's effective
/// gear — 7-fold is reachable on 84 and impossible on 96 (D8).
public func setting(folds typed: String, ofTier tier: String, in draft: PatternDraft)
  -> Result<PatternDraft, DraftRefusal>

/// Never refused for its own value: it only ever writes a stop list, and nothing records what generated
/// one (D18).
public func setting(mirror: Bool, ofTier tier: String, in draft: PatternDraft)
  -> Result<PatternDraft, DraftRefusal>
```

Each opens with `guard let position = draft.position(ofTier: tier) else { return .success(draft) }`, which
is what every setter in this file already does for a label the draft does not carry. Then:

- **`setting(seeds:)`** — `parsedStops(typed)`, `nil` giving `.failure(.indicesNotWholeNumbers(typed:
  typed))`. Let `gear = draft.wheel(of: draft.tiers[position])`. Any seed outside `0..<gear` gives
  `.failure(.indexOutOfRange(tier: tier, index: thatSeed, wheel: gear))`. Then
  `let current = derivedSymmetry(stops: draft.tiers[position].indices, wheel: gear)` and
  `settingStops(expandedStops(seeds: parsed, folds: current.folds, mirror: current.mirror, wheel: gear),
  atPosition: position, in: draft)`.
- **`setting(folds:)`** — `Int(typed.trimmingCharacters(in: .whitespacesAndNewlines))`, `nil` giving
  `.failure(.notANumber(field: "folds", typed: typed))`. Then, with `gear` as above, a value not in
  `foldCounts(onWheel: gear)` gives `.failure(.foldsNotADivisor(tier: tier, folds: value, wheel: gear))`.
  Then expand `current.seeds` at the new fold count and `current.mirror`.
- **`setting(mirror:)`** — expand `current.seeds` at `current.folds` and the new flag.

**An empty seed field expands to nothing**, so `indices` becomes empty — accepted, exactly as typing an
empty Indices cell already is (`DraftEditsTests.swift:258`), unless a later meet names one of the stops
that would go, which `settingStops` refuses.

**The two gear setters.** Neither ever rewrites a stop: a gear change moves planes, it does not renumber
anything (D16).

```swift
// MARK: - The index gear

/// A tier's own gear, or `nil` to inherit the design's.
///
/// Refused when the new effective gear would put one of this tier's existing stops out of range — 100 is a
/// valid stop on 120 and rejected on 96 — naming the first such stop in the order the author wrote them
/// (D15). Accepted otherwise, and **no stop is ever rewritten**: every plane on the tier moves, which the
/// solve reports (D16).
public func setting(wheel: Int?, ofTier tier: String, in draft: PatternDraft)
  -> Result<PatternDraft, DraftRefusal>

/// The design's default gear, which applies to every tier declaring none of its own.
///
/// Refused when it would put any inheriting tier's existing stop out of range, naming the first such stop
/// in file order. A tier with its own gear is untouched and is not checked.
public func setting(wheel: Int, in draft: PatternDraft) -> Result<PatternDraft, DraftRefusal>
```

- **Per tier** — position guard, then `let gear = wheel ?? draft.wheel`, then
  `for index in draft.tiers[position].indices where index >= gear { return
  .failure(.indexOutOfRange(tier: tier, index: index, wheel: gear)) }`. A negative stop cannot be present,
  because nothing can put one there. Then `edited.tiers[position].wheel = wheel`.
- **Header** — for each tier in file order where `$0.wheel == nil`, the same per-stop check against the new
  gear, naming that tier. Then `edited.wheel = wheel`.

### 3. `CuttingBench/BenchGeometry/Sources/BenchGeometry/PatternDraft.swift`

**One new case, and one new sentence.** Add to `DraftRefusal` at `:179`, after
`case indicesNotWholeNumbers(typed: String)` at `:186`:

```swift
  /// A fold count that does not divide the tier's effective gear, with the counts that gear does reach
  /// (D8).
  case foldsNotADivisor(tier: String, folds: Int, wheel: Int)
```

and to `message` at `:197`, after the `.indicesNotWholeNumbers` arm at `:214`:

```swift
    case .foldsNotADivisor(let tier, let folds, let wheel):
      // The reachable counts are computed rather than spelled, so the sentence cannot drift from what
      // `setting(folds:ofTier:in:)` actually accepts.
      "\(folds)-fold does not divide \(tier)'s gear of \(wheel). "
        + "On \(wheel) the fold counts are \(foldCounts(onWheel: wheel).map(String.init).joined(separator: ", "))."
```

**No other case is added.** A bad seed reuses `.indexOutOfRange` and `.indicesNotWholeNumbers`, a
non-numeric fold count reuses `.notANumber`, and a gear change reuses `.indexOutOfRange` — whose sentence,
`Index stop 100 is outside 0...95 on G1's gear of 96.` (`:213`), already reads correctly for a gear that is
being moved to rather than one already in force.

### 4. `CuttingBench/BenchGeometry/Sources/BenchGeometry/TierTable.swift`

**Three fields on `TierTableRow`**, declared straight after `public var indices: String` at `:24`, so the
declaration order matches the column order:

```swift
  /// The seed stops this tier's own stop list derives, space-separated as `indices` is. Empty for a tier
  /// with no stops.
  ///
  /// **Derived, never stored** (D2): the file holds no generator, so what the seeds are is a question about
  /// the stops and is asked again every time the row is built.
  public var seeds: String
  /// The fold count the stops derive, as a plain number. `1` for a set no rotation maps onto itself, which
  /// is the generator honestly reading as off (D7).
  public var folds: String
  /// Whether reflecting the stops about index 0 maps the set onto itself.
  public var mirror: Bool
```

Add the three to the memberwise `init` at `:48` in the same position — **required, not defaulted**: there
is exactly one construction site, at `:113`, so a default would only hide a missing value.

**In `tierTableRows` at `:96`**, inside the `map`, before the `return TierTableRow(`:

```swift
    // The effective gear is what the symmetry is read against: a tier may override it, and the fold counts
    // a set can have are the divisors of the gear it is cut on.
    let symmetry = derivedSymmetry(stops: spec.indices, wheel: draft.wheel(of: spec))
```

and in the initialiser call, straight after the `indices:` argument at `:121`:

```swift
      seeds: symmetry.seeds.map(String.init).joined(separator: " "),
      folds: String(symmetry.folds),
      mirror: symmetry.mirror,
```

Space-separated to match `indices` at `:121`, so the two read as one statement across the row.

### 5. `CuttingBench/CuttingBench/BenchRegions.swift`

**Two module constants**, beside `private let partCases` at `:382`:

```swift
/// The Wheel popup's tag for a tier declaring no gear of its own. A `String` tag rather than an `Int?`,
/// for the reason `partCases` is matched by `rawValue`: an optional tag is the case that idiom avoids
/// (D12).
private let inheritTag = "inherit"
```

`indexGears` and `gearsOffered(including:)` come from `BenchGeometry` and are not restated here.

**Three new columns in `table` at `:206`**, inserted between the Angle column, which ends at `:262`, and
`TableColumn("Indices") { row in` at `:263`:

```swift
      // Seeds, Folds and Mirror sit before Indices so the row reads left to right as the generation
      // itself: these seeds, expanded this many folds, optionally mirrored, giving these stops (D11).
      // All three are derived from the stops every time the table is built — nothing symmetry-shaped is
      // stored, in the file or in the draft (D2) — so editing Indices directly re-derives them and a tier
      // whose stops are not symmetric honestly reads as 1-fold.
      TableColumn("Seeds") { row in
        EditableCell(stored: row.seeds) { typed in
          edit("Change Seed Stops") { setting(seeds: typed, ofTier: row.tier, in: $0) }
        }
      }
      TableColumn("Folds") { row in
        EditableCell(stored: row.folds) { typed in
          edit("Change Symmetry Folds") { setting(folds: typed, ofTier: row.tier, in: $0) }
        }
      }
      TableColumn("Mirror") { row in
        // Discarded rather than reverted, as the Part popup's result is: the binding's getter reads the
        // row, which is rebuilt from the draft, so a refused change leaves the toggle showing the stored
        // value with no revert code (D21).
        Toggle(
          "",
          isOn: Binding(
            get: { row.mirror },
            set: { on in
              _ = edit("Change Mirroring") { setting(mirror: on, ofTier: row.tier, in: $0) }
            })
        )
        .labelsHidden()
      }
```

**The Wheel column** at `:274` — currently
`TableColumn("Wheel") { row in cell(row.wheel, row, dimmed: row.wheelIsInherited) }` — becomes a popup:

```swift
      TableColumn("Wheel") { row in
        // The `inherit` item carries the effective gear in its label, because that is what the cell showed
        // before it was a popup and a stop number means nothing without one (D13). The tag stays the bare
        // word, so the label can change without moving the selection. `gearsOffered` adds a gear the
        // document already carries that is not one of the eight, or the popup would render blank (D14).
        Picker(
          "Wheel",
          selection: Binding(
            get: { row.wheelIsInherited ? inheritTag : row.wheel },
            set: { chosen in
              if chosen == inheritTag {
                _ = edit("Change Index Gear") { setting(wheel: nil, ofTier: row.tier, in: $0) }
              } else if let gear = gearsOffered(including: draft.wheel)
                .first(where: { String($0) == chosen })
              {
                _ = edit("Change Index Gear") { setting(wheel: gear, ofTier: row.tier, in: $0) }
              }
            })
        ) {
          Text("\(inheritTag) (\(draft.wheel))").tag(inheritTag)
          ForEach(gearsOffered(including: row.wheelIsInherited ? nil : Int(row.wheel)), id: \.self) {
            gear in
            Text(String(gear)).tag(String(gear))
          }
        }
        .labelsHidden()
        .pickerStyle(.menu)
      }
```

The `dimmed:` argument goes with the old cell; `wheelIsInherited` stays on the row because the popup's
selection reads it, and the word `inherit` says what the dimming used to. **`cell(_:_:dimmed:)` at `:341`
keeps its `dimmed` parameter** — the meet-point facet cells still call it, and its default is `false`.

**The header Gear row** at `:595` — currently
`row("Gear") { Text(String(draft.wheel)).foregroundStyle(.secondary) }` — becomes the same popup with no
`inherit` item, because the design's default has nothing above it to inherit from (D17):

```swift
      row("Gear") {
        Picker(
          "",
          selection: Binding(
            get: { String(draft.wheel) },
            set: { chosen in
              guard
                let gear = gearsOffered(including: draft.wheel).first(where: { String($0) == chosen })
              else { return }
              _ = edit("Change Index Gear") { setting(wheel: gear, in: $0) }
            })
        ) {
          ForEach(gearsOffered(including: draft.wheel), id: \.self) { gear in
            Text(String(gear)).tag(String(gear))
          }
        }
        .labelsHidden()
        .pickerStyle(.menu)
      }
```

**Rewrite the doc comment at `:558`.** It currently says the gear is read-only here because a gear change
has to refuse the stops it would put out of range and that is not built yet. It is built now: replace those
two sentences with one saying the gear is a popup of the eight gears, that a change is refused when it
would put an inheriting tier's stop out of range, and that it never renumbers a stop. Leave the `state`
sentence and the whole RI-and-girdle-target paragraph exactly as they are.

## Explicitly not doing

- **No symmetry field in the file, in `DraftTier` or in session state** (D2). `design-authoring-format.md:105`
  says symmetry is not stored at all, not even as a generator, and the derivation makes storage unnecessary.
- **No mirror-axis control.** Mirroring is about index 0, because the index origin is the author's own
  convention and they place 0 on the design's mirror plane. A set mirrored about some other stop is reached
  by typing the stops into the Indices cell, which part 1 already allows — a mirror-axis field is a field
  every other tier would ignore.
- **No popup of fold counts in place of the folds field.** The control is one field for a number; the
  refusal is what names the counts the gear reaches (D8).
- **No new finding, and no marking, for a tier whose stops are asymmetric.** Symmetry is not a property the
  file records, so there is nothing for validation to be checking against (D18). A 1-fold reading is not a
  fault.
- **No cache, quiet-period or findings work** (D19). Every edit here rides the machinery part 2 shipped.
- **No sorting of a typed stop list, and no reordering of tiers, ever** — only a list the generator produced
  is sorted (D6).
- **No angle tuning, no tangent-ratio rescale, no rotation, no two-point angle derivation.** All four are
  `5-Cutting-Bench-Angle-Tuning`.
- **No meet picking in the viewport** — that is part 4 — and **no fraction meets** — part 5. The Meet column
  keeps exactly the menu part 1 gave it.
- **No generation of a tier's `instructions` from its meet.** The field stays a plain stored string, and
  absent keeps meaning the author wrote nothing.

## Checks

The protocol's gates apply as written. Two notes on which of them fire here:

- **Gate 1, tests** — `swift test --package-path Kernel --disable-sandbox` is unconditional, and **no task
  in this part touches `Kernel/`**, so it is only ever confirming that nothing broke. The new tests in this
  part live in the `BenchGeometry` package and are run by
  `swift test --package-path CuttingBench/BenchGeometry --disable-sandbox`, which every task below names in
  its own *Done when*.
- **Gate 3, the release build** — conditional on `Kernel/` having been touched, so it never fires.

**The executor cannot build or run the app**: there is no shared `.xcscheme`. Where a task changes app code,
"it compiles" is the owner's ⌘R at the owner stop, and a compile error found there is a normal continuation
of that task, not a blocker. **Type-checking is available and catches most of it**, so every task touching
`CuttingBench/CuttingBench/` runs this as a *Done when* item:

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

Format, gate 2, covers `Kernel/` only as written. **Also run
`xcrun swift-format lint --recursive --strict CuttingBench/BenchGeometry/Sources
CuttingBench/BenchGeometry/Tests CuttingBench/CuttingBench` and take it clean**, which is what parts 1 and
2 did with the same files.

## Tasks

| # | Task | Status | Then | Commit | Note |
|---|---|---|---|---|---|
| T1 | Prefactor: one place a tier's stop list is written | completed | continue | — | |
| T2 | Pure: the gears, the generator, and its inverse | completed | checkpoint | commit | |
| T3 | The three symmetry setters, and the folds refusal | completed | continue | — | material alteration ↓ |
| T4 | Seeds, Folds and Mirror, on the row and in the table | completed | **owner stop** | commit | |
| T5 | The two gear setters | completed | continue | — | |
| T6 | The Wheel popup, and the header Gear popup | completed | **owner stop** | commit + push | |
| T7 | Close out | awaiting owner | **owner stop** | commit + push | |

**T1 — Prefactor: one place a tier's stop list is written**

Behaviour-preserving. `setting(indices:)` keeps its parsing and its doc comment; the range check, the
reference check and the assignment move to `settingStops(_:atPosition:in:)`, and the split moves to
`parsedStops(_:)`. Both new functions are `private`.

- **Files:** `CuttingBench/BenchGeometry/Sources/BenchGeometry/DraftEdits.swift` (edit)
- **Done when:**
  - `swift test --package-path CuttingBench/BenchGeometry --disable-sandbox` passes, **with no test file
    edited and no test added** — this task changes no behaviour, so a test that had to change means it
    changed some.
  - `swift test --package-path Kernel --disable-sandbox` passes.
  - `xcrun swift-format lint --recursive --strict CuttingBench/BenchGeometry/Sources
    CuttingBench/BenchGeometry/Tests CuttingBench/CuttingBench` is clean.
  - `setting(indices:ofTier:in:)`'s body is: the position guard, `parsedStops`, and one call to
    `settingStops`. Nothing else remains in it.
  - `settingStops` takes the tier label from `draft.tiers[position].tier` and takes no `tier:` parameter.
- **Do not:** add any new public API, change any message wording, change `setting(indices:)`'s doc comment,
  or touch any other setter in the file. Do not make either new function `public` — nothing outside this
  file calls them, in this task or any later one.

**T2 — Pure: the gears, the generator, and its inverse**

The whole of `TierSymmetry.swift`, with tests over the corpus. **This is the task that would invalidate the
rest**: if the derivation does not reproduce the authored patterns' own stop lists, the controls would show
the author a set they cannot regenerate, and everything after this builds on it.

- **Files:** `CuttingBench/BenchGeometry/Sources/BenchGeometry/TierSymmetry.swift` (new),
  `CuttingBench/BenchGeometry/Tests/BenchGeometryTests/TierSymmetryTests.swift` (new)
- **Done when:**
  - `swift test --package-path CuttingBench/BenchGeometry --disable-sandbox` passes, including the new
    cases below. Written as `XCTestCase` methods with the corpus loaded through `AuthoredPatterns.load`,
    exactly as `CuttingBench/BenchGeometry/Tests/BenchGeometryTests/DraftEditsTests.swift:11` does it —
    `AuthoredPatterns` itself lives in `BenchSolidTests.swift:10`.
  - **The round trip, over every tier of all four authored patterns**: for each tier, `expandedStops` of
    `derivedSymmetry`'s own seeds, folds and mirroring, at that tier's effective gear, equals that tier's
    `indices` **sorted ascending**. This is the case that matters most, and it covers 32 tiers.
  - **Every authored `indices` list is already ascending**, asserted directly, which is what makes the
    sorted comparison above the right one. (`Pattern-Easy-Octagon.json:15` and the other three.)
  - **The corpus's own readings**, asserted as exact values: `Easy Octagon`'s `G1` `[0, 12, …, 84]` on 96
    gives seeds `[0]`, 8 folds, mirrored; its `C2` `[18, 42, 66, 90]` gives seeds `[18]`, 4 folds, **not**
    mirrored, because 78 is not in the set; its `T` `[0]` gives seeds `[0]`, 1 fold, mirrored;
    `Rand's` girdle tier `2`, `[0, 8, 40, 48, 56, 88]`, gives seeds `[0, 8]`, 2 folds, mirrored; and the
    round brilliant's `[3, 9, …, 93]` gives seeds `[3]`, 16 folds, mirrored.
  - **The empty list** on any gear gives seeds `[]`, 1 fold, not mirrored (D4).
  - **An asymmetric set reads as raw**: `[0, 1, 5]` on 96 gives 1 fold, not mirrored, and seeds equal to
    the stops, so its expansion is the identity (D7).
  - **`foldCounts(onWheel: 84)` contains 7 and `foldCounts(onWheel: 96)` does not**, and both start at 1
    and end at the gear.
  - **`gearsOffered(including: nil)` is exactly the eight**; `gearsOffered(including: 96)` is also exactly
    the eight; `gearsOffered(including: 100)` is the eight plus 100, ascending, with 100 between 96 and
    120.
  - `xcrun swift-format lint --recursive --strict CuttingBench/BenchGeometry/Sources
    CuttingBench/BenchGeometry/Tests CuttingBench/CuttingBench` is clean.
- **Do not:** import `FacetKernel` or `Foundation` in `TierSymmetry.swift` — it is integer arithmetic and
  needs neither. Do not call any of it from `DraftEdits.swift`, `TierTable.swift` or the app yet; that is
  T3 onward. Do not add a stored symmetry field anywhere.

**Commit point** — after T2:

```
4-cutting-bench-authoring-3 T1-T2: the symmetry generator, and its inverse

- One private helper is now the only place a tier's stop list is written, so a
  generated list is refused for exactly what a typed one is
- Folds, mirroring and seeds are derived from a tier's stops and stored nowhere;
  the derivation round-trips every tier of all four authored patterns
```

**T3 — The three symmetry setters, and the folds refusal**

`setting(seeds:)`, `setting(folds:)` and `setting(mirror:)`, plus the one new `DraftRefusal` case and its
sentence. All three go through `settingStops`, so none of them repeats a check.

- **Files:** `CuttingBench/BenchGeometry/Sources/BenchGeometry/DraftEdits.swift` (edit),
  `CuttingBench/BenchGeometry/Sources/BenchGeometry/PatternDraft.swift` (edit),
  `CuttingBench/BenchGeometry/Tests/BenchGeometryTests/DraftEditsTests.swift` (edit)
- **Done when:**
  - `swift test --package-path CuttingBench/BenchGeometry --disable-sandbox` passes, including these cases
    added to `DraftEditsTests.swift` under a new `// MARK: - Symmetry` heading:
    - On a draft of `Easy Octagon`, setting `C2`'s folds to `8` gives `indices` `[6, 18, 30, 42, 54, 66,
      78, 90]` — seed 18 stepped by 12 and wrapped — and leaves every other tier's stops untouched.
    - On the same draft, setting `G1`'s folds to `7` is refused as `.foldsNotADivisor(tier: "G1", folds: 7,
      wheel: 96)`, and the draft is returned unchanged.
    - Setting a tier's folds to `7` **is accepted** on a tier whose own `wheel` is 84, which is the same
      refusal's other side and the case the two common gears cannot reach.
    - Setting `G1`'s seeds to `6` gives `[6, 18, 30, 42, 54, 66, 78, 90]`, because `G1` derives 8 folds and
      mirroring from its own stops and the new seed rides them.
    - Setting seeds to `0, 8` splits on the comma as the Indices cell does, and setting them to `96` on a
      96 gear is refused as `.indexOutOfRange(tier:index:wheel:)` naming 96 and 96.
    - Setting seeds to `nine` is refused as `.indicesNotWholeNumbers(typed: "nine")`, and setting folds to
      `nine` as `.notANumber(field: "folds", typed: "nine")`.
    - **Turning mirroring off on `Easy Octagon`'s `G1` is accepted and leaves `indices` identical**, because
      seed 0 at 8 folds generates the same set with or without the reflection.
    - **Turning mirroring off where it does drop stops is refused when one of them is named.** On a draft of
      `Rand's`, tier `2` derives seeds `[0, 8]`, 2 folds and mirroring, and dropping the reflection expands
      to `[0, 8, 48, 56]` — losing 40 and 88. Point a later tier's meet at tier `2` index 40 first, as
      `DraftEditsTests.swift:266` constructs its own case, then assert `.stopReferenced(tier: "2", index:
      40, by:)` naming that tier. Without the constructed reference the same edit is accepted and the two
      stops go.
    - An empty seed field on a tier nothing names leaves `indices` empty and is accepted.
    - `.foldsNotADivisor(tier: "G1", folds: 7, wheel: 96)`'s `message` names 7, `G1`, 96, and lists the
      twelve fold counts 96 reaches, starting `1, 2, 3, 4`.
  - `xcrun swift-format lint --recursive --strict CuttingBench/BenchGeometry/Sources
    CuttingBench/BenchGeometry/Tests CuttingBench/CuttingBench` is clean.
- **Do not:** touch `TierTable.swift` or anything in `CuttingBench/CuttingBench/` — the row and the columns
  are T4. Do not add a refusal case for a bad seed or for a gear change; those reuse existing cases (D9,
  D15). Do not store the folds or the mirror flag on `DraftTier`.
- **Material alteration.** The seed-acceptance case reads `P2` and not `G1`. As written it was
  unsatisfiable: `G1`'s stops 0, 12 and 24 are named by `P2`'s and `C2`'s meets, so re-seeding `G1` to 6
  removes three named stops and D10 refuses it — the existing coverage already states this at
  `DraftEditsTests.swift:222` (`// These three read `P2`, the one tier of `Easy Octagon` whose stops nothing
  names`). `P2` derives the same eight folds and mirroring and nothing names it, so seed `0` gives
  `[0, 12, 24, 36, 48, 60, 72, 84]` — the same shape of check, and the same list the case named, with seed
  and result swapped. The comma-splitting, out-of-range, not-a-whole-number and empty-field cases moved to
  `P2` with it for the same reason. **No other case changed**, and the refusal side of D10 is still covered
  by the `Rand's` mirroring case the plan asked for.

**T4 — Seeds, Folds and Mirror, on the row and in the table**

The three derived strings on `TierTableRow`, and the three columns that show and edit them. First task the
owner can see.

- **Files:** `CuttingBench/BenchGeometry/Sources/BenchGeometry/TierTable.swift` (edit),
  `CuttingBench/BenchGeometry/Tests/BenchGeometryTests/TierTableTests.swift` (edit),
  `CuttingBench/CuttingBench/BenchRegions.swift` (edit)
- **Done when:**
  - `swift test --package-path CuttingBench/BenchGeometry --disable-sandbox` passes, including these cases
    added to `TierTableTests.swift`:
    - `Easy Octagon`'s rows read `G1` as seeds `0`, folds `8`, mirror `true`; `C2` as seeds `18`, folds
      `4`, mirror `false`; `T` as seeds `0`, folds `1`, mirror `true`.
    - A tier with no stops — the draft with a tier's `indices` cleared, built as
      `TierTableTests.swift:315` builds its own half-authored draft — reads seeds `""`, folds `1`, mirror
      `false`.
    - The seed string is space-separated, matching the `indices` cell's own separator: `Rand's` tier `2`
      reads seeds `0 8`.
    - A tier on its own gear derives against **that** gear and not the header's, checked on the tier
      `TierTableTests.swift:116` already uses for the inherited-wheel case.
  - Both `swiftc -typecheck` runs from **Checks** are clean, `-DDEBUG` and without.
  - `xcrun swift-format lint --recursive --strict CuttingBench/BenchGeometry/Sources
    CuttingBench/BenchGeometry/Tests CuttingBench/CuttingBench` is clean.
  - The three columns sit between Angle and Indices, in the order Seeds, Folds, Mirror.
- **Do not:** touch the Wheel column or the header Gear row — both are T6. Do not add column widths or
  otherwise restyle the table; the existing columns set none. Do not give the three new `TierTableRow`
  fields default values in the initialiser.
- **Verification handle** — `permanent`:
  - **Where:** the tier table, with `Design/Patterns/Pattern-Easy-Octagon.json` open. The `C2` and `G1`
    rows, and the four cells Seeds, Folds, Mirror and Indices on each.
  - **Positive:** on the `C2` row, type `8` into Folds and press Return. Indices changes from
    `18 42 66 90` to `6 18 30 42 54 66 78 90`, Seeds changes from `18` to `6`, and Mirror becomes ticked —
    all four cells move together, because all three are re-derived from the stops the edit wrote.
  - **Negative:** on the `G1` row, type `7` into Folds and press Return. An alert reads
    *"7-fold does not divide G1's gear of 96. On 96 the fold counts are 1, 2, 3, 4, 6, 8, 12, 16, 24, 32,
    48, 96."*, and the row is unchanged — Seeds `0`, Folds `8`, Mirror ticked, Indices
    `0 12 24 36 48 60 72 84`.
  - **Reads:** `derivedSymmetry` in `TierSymmetry.swift` and `setting(folds:ofTier:in:)` in
    `DraftEdits.swift`. Delete either and the four cells stop moving together.

**Commit point** — after T4:

```
4-cutting-bench-authoring-3 T3-T4: seeds, folds and mirroring in the tier row

- Three tier-table columns generate a tier's index stops from a seed set, and are
  themselves derived from those stops, so nothing symmetry-shaped is stored
- A fold count that does not divide the tier's gear is refused and names the ones
  that do
```

**T5 — The two gear setters**

`setting(wheel:ofTier:in:)` and `setting(wheel:in:)`. Neither ever rewrites a stop.

- **Files:** `CuttingBench/BenchGeometry/Sources/BenchGeometry/DraftEdits.swift` (edit),
  `CuttingBench/BenchGeometry/Tests/BenchGeometryTests/DraftEditsTests.swift` (edit)
- **Done when:**
  - `swift test --package-path CuttingBench/BenchGeometry --disable-sandbox` passes, including these cases
    added to `DraftEditsTests.swift` under a new `// MARK: - The index gear` heading:
    - Setting `Easy Octagon`'s `C2` to its own gear of 120 is accepted, leaves its stops
      `[18, 42, 66, 90]` **byte-for-byte unchanged**, and leaves every other tier inheriting 96.
    - Setting `C2` to 32 is refused as `.indexOutOfRange(tier: "C2", index: 42, wheel: 32)` — the **first**
      offending stop in the order the author wrote them, not the largest — and the draft is unchanged.
    - Setting a tier back to `nil` restores inheritance, and is refused when the header's own gear would put
      one of that tier's stops out of range: give the tier a gear of 120 and a stop of 100 first, then a
      header gear of 96 makes `nil` illegal.
    - Setting the header gear to 120 on `Easy Octagon` is accepted and **rewrites no tier's stops**; every
      tier still reads `wheel == nil` and `draft.wheel(of:)` now answers 120 for all of them.
    - Setting the header gear to 32 is refused naming `G1`'s stop 36 — the first tier in file order and the
      first of its stops that is out of range.
    - A tier that declares its own gear is **not** checked by a header change: give `C2` a gear of 120 and a
      stop of 100, then setting the header to 96 is accepted and `C2` keeps 100.
  - `swift test --package-path Kernel --disable-sandbox` passes.
  - `xcrun swift-format lint --recursive --strict CuttingBench/BenchGeometry/Sources
    CuttingBench/BenchGeometry/Tests CuttingBench/CuttingBench` is clean.
- **Do not:** rewrite, clamp, wrap or renumber any stop on a gear change — the refusal is the whole
  response, and a stop is data. Do not touch the findings cache or `FindingsCache.swift`; it already keeps
  nothing across a header gear change (D19). Do not add a refusal case; both reuse `.indexOutOfRange`.

**T6 — The Wheel popup, and the header Gear popup**

Both popups, and the rewritten doc comment on the header card.

- **Files:** `CuttingBench/CuttingBench/BenchRegions.swift` (edit)
- **Done when:**
  - Both `swiftc -typecheck` runs from **Checks** are clean, `-DDEBUG` and without.
  - `swift test --package-path CuttingBench/BenchGeometry --disable-sandbox` and
    `swift test --package-path Kernel --disable-sandbox` pass.
  - `xcrun swift-format lint --recursive --strict CuttingBench/BenchGeometry/Sources
    CuttingBench/BenchGeometry/Tests CuttingBench/CuttingBench` is clean.
  - The Wheel column offers `inherit (96)` plus the gears from `gearsOffered`, and the header Gear row
    offers the gears with **no** `inherit` item.
  - The doc comment at `BenchRegions.swift:558` no longer says the gear is read-only or that a gear change
    is not built.
- **Do not:** change the `state` sentence or the RI-and-girdle-target paragraph in that doc comment. Do not
  remove `cell(_:_:dimmed:)`'s `dimmed` parameter — the meet-point facet cells still pass it. Do not remove
  `wheelIsInherited` from `TierTableRow`; the popup's selection reads it. Do not add revert code to either
  `Picker`: the binding's getter reads the draft, so a refusal springs the control back on its own.
- **Verification handle** — `permanent`:
  - **Where:** the tier table's Wheel column and the inspector's Pattern card Gear row, with
    `Design/Patterns/Pattern-Easy-Octagon.json` freshly open. Every Wheel cell reads `inherit (96)` and the
    Gear row reads `96`.
  - **Positive:** on the `C2` row, open the Wheel popup and choose `120`. The cell reads `120`, and on the
    same row **Folds falls from `4` to `1` and Seeds grows from `18` to `18 42 66 90`** — because no
    rotation of a 120 wheel maps that stop set onto itself, so the tier honestly reads as raw. The stops
    themselves still read `18 42 66 90`, and the viewport's geometry moves.
  - **Negative:** with `C2` still on 120, open the inspector's Gear popup and choose `32`. An alert reads
    *"Index stop 36 is outside 0...31 on G1's gear of 32."*, and the Gear row springs back to `96` — every
    tier's Wheel cell still reads `inherit (96)` except `C2`, which still reads `120`.
  - **Reads:** `setting(wheel:ofTier:in:)` and `setting(wheel:in:)` in `DraftEdits.swift`, and
    `gearsOffered(including:)` in `TierSymmetry.swift`. Delete the setters and neither popup moves anything.

**Commit point** — after T6:

```
4-cutting-bench-authoring-3 T5-T6: the index gear, per tier and in the header

- Both the Wheel column and the header Gear row are popups of the eight gears,
  with inherit offered per tier only
- A gear change is refused when it would put an existing stop out of range, and
  never renumbers a stop: the planes move and the solve reports it
```

**T7 — Close out**

- Delete the temporary handles: **none — both handles in this plan are `permanent`.** The three symmetry
  columns and the two gear popups are the feature, not scaffolding.
- Confirm each item in this plan's **Deferred** section has a ticket in `Design/Tickets/`, `Status:
  untriaged`.
- Report the untriaged ticket count in `Design/Tickets/`, one line.
- `commit + push` with the message below.
- **Archive nothing, and close no ticket.** This is part 3 of 5: the exploration `4-Cutting-Bench-Authoring`
  is still the design source for parts 4 and 5, and `Chore-Validation-Rebuilds-The-Solid-Once-Per-Tier` is
  closed by part 5. Update this plan's own `Status:` line to say part 3 completed, with the date, and note
  that the final part archives it.
- **Verification handle** — `permanent`:
  - **Where:** a new document — ⌘N — then **Add Tier**, then the new `N1` row's Seeds, Folds, Mirror and
    Indices cells. This is the part's own bar: a tier's stop list authored without typing the stops.
  - **Positive:** type `0` into Seeds and press Return — Indices reads `0`. Then type `8` into Folds and
    press Return — **Indices reads `0 12 24 36 48 60 72 84`, which is `Easy Octagon`'s `G1` stop list
    exactly**, and Mirror shows ticked.
  - **Negative:** on the same row, type `7` into Folds and press Return. The fold-count alert appears and
    Indices stays at `0 12 24 36 48 60 72 84` — a refused generation writes nothing.
  - **Reads:** `expandedStops` in `TierSymmetry.swift`.

```
4-cutting-bench-authoring-3 T7: close out the symmetry slice

- Part 3 of 5 complete: seed stops, folds and mirroring generate a tier's index
  list, and the index gear is editable per tier and in the header
- Archives nothing and closes no ticket: the exploration is still the source for
  parts 4 and 5
```

## Deferred

The executor appends adjacent problems it found and must not fix — and files each as a ticket in
`Design/Tickets/` immediately with `Status: untriaged`, per the protocol.

- **Dragging the stone stutters since the three symmetry columns landed** —
  `Bug-Dragging-The-Stone-Stutters`. Found by the owner at T4's verification. `tierTableRows` is called
  inline in `BenchWindow`'s `body` and a drag delta mutates the camera, so every row is rebuilt per drag
  event and each rebuild now derives its tier's symmetry. Measured in debug, that derivation is 0.46 ms of
  `Rand's` 0.85 ms row build — real, but small enough that the ten-column table with a `Toggle` per row is
  the likelier dominant cost, and telling the two apart needs the running app. **Not fixed here:** the
  cheap fix is to cache or memoise the derivation, which contradicts the rule that nothing
  symmetry-shaped is stored and that this part adds no cache work, and dropping a column contradicts the
  agreed column order. Both are the owner's call.
