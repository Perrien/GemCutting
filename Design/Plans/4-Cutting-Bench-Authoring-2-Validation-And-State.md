# 4 · Cutting Bench Authoring — Part 2: Validation and State

Status: **APPROVED** (2026-08-26) — in execution.

## Parts

**For the owner and the next authoring session — not for the executor.** Nothing in this plan's tasks
refers to another part.

1. `4-Cutting-Bench-Authoring-1-Draft-And-Tier-Editing` — the editable draft, and every tier edit that
   needs no click in the viewport: add, delete, reorder, rename, angle, part, index stops, instructions,
   the header fields, and the three meet forms that take no picking. Every structural edit that would
   orphan a reference is refused, states its reason and is logged. **(shipped)**
2. `4-Cutting-Bench-Authoring-2-Validation-And-State` — the cheap half of validation on every committed
   edit, the expensive half cached per tier and invalidated from the first edited tier onward, and the
   `state` switch that refuses `finished` while any finding fires. ← this part
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
| U13 | 1 — **restated in 2, 3, 4 and 5**, each of which adds refusals |

**One boundary correction against part 1's copy:** U13 now reads *restated in 2* as well. Part 2 adds
two refusals of its own — a `finished` transition declined because findings fire, and one declined
because the solve stops short — so U13's rule that a refusal states its reason, names the offending
element and is logged binds this part's tasks. Part 1 remains the implementer. Nothing else moved:
every ID sits where the owner agreed.

## Context

Part 1 made the pattern editable. This part makes the editing **honest and affordable**, and it is the
part where the tool finally does what it exists for: says out loud that a pattern is finished, and
refuses to say it while anything is wrong.

Two problems, and they are the same problem seen from either end.

**The cost.** The named-point check is roughly `tiers × planes³` — **1.65 s** on a 139-plane pattern
against **0.60 s** for the whole solve — and today it runs in full on every committed edit. Six tiers
re-checked to learn the consequence of retyping one angle is six times the work the answer needs.
Tier *k*'s answer depends only on the tiers before it, so almost all of that is a recomputation of
results that cannot have changed.

**The claim.** `Pattern.state` is `in progress` or `finished`, and `finished` is an assertion about the
result. Today the app shows it and cannot change it — part 1 left the field read-only on purpose,
saying so at `CuttingBench/CuttingBench/BenchRegions.swift:555`
(`/// The header fields, in the order the format writes them. \`state\` and the gear are read-only here: a`),
because a switch is only worth having with a complete validation behind it. This part builds that.

### What part 1 and part 3 actually landed, verified in the code

More of this exists than the exploration's grounding suggests, and knowing which pieces are already
there is what keeps this part small.

- **The kernel's three-way split is public and per-tier.** `structuralFindings(_:)` at
  `Kernel/Sources/FacetKernel/Validation.swift:106` (`public func structuralFindings(_ pattern: Pattern) -> [Finding] {`),
  `namedPointFindings(inTier:of:_:)` at `:189` (`public func namedPointFindings(`), and
  `solidFindings(_:declaredFacetCount:)` at `:219`
  (`public func solidFindings(_ solution: Solution, declaredFacetCount: Int?) -> [Finding] {`).
- **The kernel already states the property this part's cache rests on, and says the cache is not its
  job.** `Validation.swift:179`–`:184` (`/// **Tier *k*'s result depends only on the tiers before *k*.**`
  … `a caller keeping a per-tier cache can rely on that; the cache itself is app state and does not belong here.`).
- **Whole-solid findings are explicitly not cacheable.** `Validation.swift:217`
  (`/// Closure and the facet count: whole-solid, cheap, and never cacheable — every tier can move them, so`).
- **The app already runs the two halves apart, off the main thread, and marks a stale result.**
  `CuttingBench/CuttingBench/BenchFindingsStore.swift:33` (`func rebuild(pattern: Pattern?, solid: BenchSolid) {`)
  runs the cheap half inline and the expensive half in a `Task.detached`, generation-guarded at `:63`
  (`private func accept(_ found: [Finding]?, generation: Int) {`). The status strip's wording is already
  built: `CuttingBench/BenchGeometry/Sources/BenchGeometry/Findings.swift:127`
  (`phrase = isChecking ? "\(countText) · stale, checking…" : countText`).
- **Cancellation already returns nothing rather than a partial list.** `Findings.swift:45`
  (`/// **Returns \`nil\` when \`isCancelled\` fired part-way.** A partial list is not a result and must never be`).
- **A refusal already has one wording and one log line.** `DraftRefusal.message` at
  `CuttingBench/BenchGeometry/Sources/BenchGeometry/PatternDraft.swift:193` (`public var message: String {`),
  presented and logged by `CuttingBench/CuttingBench/RefusalPresenter.swift:26`
  (`func present(_ refusal: DraftRefusal) {`), funnelled through
  `CuttingBench/CuttingBench/BenchWindow.swift:172`
  (`private func edit(_ actionName: String, _ change: DraftChange) -> Bool {`).
- **A draft that cannot be written already refuses and names the tiers.**
  `PatternDraft.swift:138` (`public func completePattern() -> Result<Pattern, DraftRefusal> {`).
- **The declared facet count is session state in the window, not document data.**
  `BenchWindow.swift:29` (`@State private var declaredFacets = ""`), parsed by
  `CuttingBench/BenchGeometry/Sources/BenchGeometry/MetricsReadout.swift:149`
  (`let typed = declared.trimmingCharacters(in: .whitespaces)`).

So this part is three small additions to known code — a pure cache, a delay, and a switch — and no new
architecture.

### One thing the exploration says that the code reads differently

U1 says the cheap half runs **on every keystroke**. Part 1 built every editable field as
`EditableCell`, which commits on Return or on losing focus and not before —
`BenchRegions.swift:368` (`.onSubmit { if commitsOnReturn { commitNow() } }`) and `:369`
(`.onChange(of: focused) { _, isFocused in if !isFocused { commitNow() } }`). The draft therefore does
not change between keystrokes, so there is nothing for a per-keystroke check to check. **U1's rule holds
in the form the code can deliver it: the cheap half runs inline on every committed edit, and the
expensive half is deferred.** That is what D2 says, and it is not a narrowing of the decision — it is
the same decision against a commit-on-Return field.

## Decisions (2026-08-26)

| # | Decision |
|---|---|
| D1 | **The per-tier half of validation is cached, and the cache is invalidated from the first edited tier onward** (exploration **I5**). Tier *k*'s named-point result depends only on the tiers before *k*, so editing tier *j* invalidates *j* onward and appending a tier checks exactly one tier instead of all of them. That is what turns `tiers × planes³` into `planes³` per tier added. |
| D2 | **The cheap half runs inline on every committed edit; the expensive half runs after a quiet period, cancellable, off the main thread** (exploration **U1**). Structural faults — a forward reference, a facet that does not exist, three planes that pin nothing — are the transcription mistakes, and they surface at once. |
| D3 | **While a deferred check is in flight the previous result stays visible and is marked stale, and a stale result is never presented as current** (exploration **U1**). Already built at `Findings.swift:127`; this part must not weaken it. |
| D4 | **The quiet period is 250 ms, one build constant, not a preference.** Long enough that committing an angle and tabbing straight to the next field costs one pass rather than two; short enough that a single edit's result feels immediate. A hidden setting that changes when a check runs is worse than editing a number — the same stance the exploration takes on its other two constants. |
| D5 | **The cache unit is the tier, never the side** (exploration **I5**). Pavilion and crown tiers usually group in file order but nothing guarantees it, and tier order must never be normalised, so a side-based cache would rest on an accident of the four patterns to hand. |
| D6 | **The cache survives a change to any field that cannot move geometry, and is dropped whole by one that can.** Verified in the code: neither `ri` nor `state` is read by `Solver.swift`, `Validation.swift` or `Metrics.swift`, and `name`, `designer`, `notes` and `formatVersion` reach nothing geometric either. The gear and the girdle target do — `Solver.swift:166` (`let resolved = girdleTargetFraction ?? pattern.effectiveGirdleTargetFraction`) — so a change to either keeps nothing. |
| D7 | **A cancelled expensive pass discards the tiers it had already computed.** The cache's win is across pattern edits, not within one interrupted run, and keeping partial work would mean threading the run's own pattern back to compare against. Cancellation almost always lands inside the quiet period, before any tier has run. Mirrors `Findings.swift:45`, which already discards a partial list. |
| D8 | **`state` is a two-way switch in the inspector's Pattern card, and `finished` is refused while any finding fires** (exploration **U12**). **This is the one place in the app where a check blocks rather than reports**: everywhere else the author is mid-work, here they are making an assertion about the result. Consistent with `facetsolve`, which exits non-zero only when a *finished* pattern has findings — `Kernel/Sources/facetsolve/main.swift:345`. |
| D9 | **The transition forces a complete synchronous validation — its own solve and all three checks — rather than trusting the deferred pass or a cache that may be stale** (exploration **U12**). |
| D10 | **A declined transition lists what fired** (exploration **U12**), and, being a refusal, states its reason, names the offending element and is written to the unified log (exploration **U13**). It goes through `RefusalPresenter`, so the alert and the log line cannot disagree. |
| D11 | **A pattern whose solve stops short is refused too, naming the tier and the reason.** A stopped solve is not a finding, so "no findings fire" would let `finished` be claimed on a pattern with a tier that will not place — exactly the silent escape the `state` field exists to prevent. |
| D12 | **The declared facet count stays optional: with nothing typed, that check does not run rather than blocking the transition** (exploration **U12**). A half-typed value that is not a positive whole number likewise does not block — the same reading `facetCountCheck` already gives the field. |
| D13 | **`finished` back to `in progress` is always allowed and is never checked.** Going that way claims nothing. |
| D14 | **The draft is converted to a `Pattern` before the finish check runs, and a tier with no meet refuses the transition** (**ADR-0003**: the kernel owns the file, the app owns the draft). `displayPattern` silently drops a meetless tier, so validating it would validate something other than what the author wrote. |
| D15 | **Nothing in this part reorders, groups or sorts tiers** — not the cache, not the finish check (exploration **I3**). Tier order is data, and normalising it for tidiness can turn a cuttable pattern into one that cannot be cut at all. Carried here because the cache indexes tiers by position and a sort would silently invalidate every entry while looking like a tidy-up. |

## Tickets closed by this plan

**None — closed in the final part.** `Chore-Validation-Rebuilds-The-Solid-Once-Per-Tier` is the ticket
D1 answers, and it stays open in `Design/Tickets/` until
`4-Cutting-Bench-Authoring-5-Fraction-Meets` closes and archives it with the rest of the set. This part
archives nothing and does not archive itself.

## Prefactoring

**One prefactor task, T1.** `facetCountCheck` parses the typed declared count inline at
`MetricsReadout.swift:149`–`:155`; the finish check in T6 needs the same number by the same rule, and two
parsers for one field is how the card and the transition come to disagree about whether `5x` is a count.
T1 extracts it and changes nothing else.

Its check is inverted, as a prefactor's is: **the existing facet-count tests pass unchanged.** They
already cover empty, non-numeric and matching values — `MetricsReadoutTests.swift` — so no
characterization test needs writing first.

Nothing else needs prefactoring. The per-tier entry point D1's cache is built on is already public and
already documented as prefix-dependent (`Validation.swift:189`, `:179`), and
`geometricFindings(pattern:solution:isCancelled:)` at `Findings.swift:50` is deliberately **left exactly
as it is** so it can serve as the uncached oracle the cache is tested against.

## Approach

Three additions, in dependency order: a pure cache in `BenchGeometry`, a driver change in the app's
findings store, and a pure finish verdict plus the control that calls it. Everything with a rule in it
goes in `BenchGeometry`, where it has tests; the app files stay thin, because the executor cannot build
or run the app.

### 1. `CuttingBench/BenchGeometry/Sources/BenchGeometry/MetricsReadout.swift` — T1, prefactor

Extract the typed-count parse. Today it is inline in `facetCountCheck` at `:149`
(`let typed = declared.trimmingCharacters(in: .whitespaces)`) through `:155`.

Add, `internal` — nothing outside the module needs it, and `FinishCheck.swift` is in the module:

```swift
/// The declared facet count as a number, or `nil` for a field that is not making a claim — empty,
/// or holding something that is not a positive whole number.
///
/// **One rule, in one place.** The Facet Count card and the `finished` transition both read this field,
/// and two parsers would let them disagree about whether `5x` is a count.
func declaredCount(_ typed: String) -> Int? {
  let trimmed = typed.trimmingCharacters(in: .whitespaces)
  guard let count = Int(trimmed), count > 0 else { return nil }
  return count
}
```

Then rewrite `facetCountCheck`'s three branches against it, **keeping all three verdict strings
byte-identical** — `"No count declared."`, `"Not a facet count."`, and the two at `:168`–`:169`. The
distinction between empty and unparseable is the card's and stays there:

```swift
  let trimmed = declaredFacets.trimmingCharacters(in: .whitespaces)
  guard !trimmed.isEmpty else {
    return FacetCountCheck(solved: split, verdict: "No count declared.")
  }
  guard let count = declaredCount(trimmed) else {
    return FacetCountCheck(solved: split, verdict: "Not a facet count.")
  }
```

**No behaviour changes.** `declaredCount` trims again on an already-trimmed string, which is free and
keeps the function correct for its second caller.

### 2. New: `CuttingBench/BenchGeometry/Sources/BenchGeometry/FindingsCache.swift` (pure — no framework, no I/O)

The whole of D1, D4, D5, D6 and D7. `import FacetKernel` and nothing else.

```swift
/// How long a committed edit has to stand still before the expensive half of validation runs (D4).
///
/// **One build constant, not a preference.** A hidden setting that changes when a check runs is worse
/// than editing a number here.
public let geometricQuietPeriod: Duration = .milliseconds(250)

/// How many leading tiers of `previous` a move to `next` leaves untouched — the count of cached
/// per-tier results that survive the edit.
///
/// **Tier *k*'s named-point result depends on the specs of tiers 0…*k* and on nothing after them**, so
/// the answer is the first position at which the two tier lists differ. The solve has the same prefix
/// property: it places tiers in file order and stops at the first failure, so nothing later can change
/// whether an earlier tier placed.
///
/// A header field that can move geometry keeps nothing: the gear enters every plane normal and the
/// girdle target enters every girdle meet's depth. `ri`, `state`, `name`, `designer`, `notes` and
/// `formatVersion` reach neither the solve nor validation, so they keep everything.
public func survivingTierPrefix(from previous: Pattern?, to next: Pattern) -> Int {
  guard let previous,
    previous.wheel == next.wheel,
    previous.girdleTargetFraction == next.girdleTargetFraction
  else { return 0 }

  var n = 0
  while n < previous.tiers.count, n < next.tiers.count, previous.tiers[n] == next.tiers[n] { n += 1 }
  return n
}

/// The expensive half of validation, kept per tier between rebuilds (D1).
///
/// **Not `Equatable`**: it is a scratch pad whose contents are derived, and nothing compares two of them.
public struct TierFindingsCache: Sendable {
  /// The pattern the kept entries were computed for, or `nil` before the first `retain`.
  public private(set) var pattern: Pattern?
  /// Tier label to that tier's named-point findings. Only tiers actually checked appear.
  public private(set) var perTier: [String: [Finding]] = [:]

  public init() {}

  /// Drops every entry the move to `next` could have changed, and returns the tiers still needing a
  /// check, **in cutting order**.
  ///
  /// Entries for labels outside the surviving prefix go, which is also what handles a rename: the
  /// renamed tier differs at its own position, so it and everything after it are dropped along with the
  /// stale entry under the old label.
  public mutating func retain(_ next: Pattern) -> [String] {
    let kept = survivingTierPrefix(from: pattern, to: next)
    let survivors = Set(next.tiers.prefix(kept).map(\.tier))
    perTier = perTier.filter { survivors.contains($0.key) }
    pattern = next
    return next.tiers.dropFirst(kept).map(\.tier)
  }

  public mutating func record(_ findings: [Finding], forTier tier: String) {
    perTier[tier] = findings
  }

  /// Every kept per-tier finding in cutting order, or `nil` while any tier of the held pattern has no
  /// entry. **A short cache is not a result**: reporting one would undercount.
  public var complete: [Finding]? {
    guard let pattern else { return nil }
    var all: [Finding] = []
    for spec in pattern.tiers {
      guard let found = perTier[spec.tier] else { return nil }
      all.append(contentsOf: found)
    }
    return all
  }
}

/// The named-point check over just the tiers that need it, off the main thread.
///
/// **Returns `nil` when `isCancelled` fired part-way** (D7), discarding the tiers already done — the
/// same rule `geometricFindings` follows, and cancellation almost always lands inside the quiet period
/// before any tier has run.
///
/// A label the solution does not carry yields `[]`, which `namedPointFindings` already does for an
/// unsolved tier: a tier the solve never reached has no intermediate solid to be a corner of.
public func runTierChecks(
  tiers: [String],
  pattern: Pattern,
  solution: Solution,
  isCancelled: () -> Bool = { false }
) -> [String: [Finding]]? {
  var computed: [String: [Finding]] = [:]
  for tier in tiers {
    if isCancelled() { return nil }
    computed[tier] = namedPointFindings(inTier: tier, of: pattern, solution)
  }
  return computed
}
```

**Why the concatenation order is safe.** `complete` walks `pattern.tiers`; `geometricFindings` walks
`solution.tiers` and then appends `solidFindings`. For every tier the solve reached, the two orders are
the same file order; a tier it did not reach contributes `[]` either way. So `complete + solidFindings(…)`
equals `geometricFindings(…)` element for element, which is what T2's oracle test asserts.

### 3. `CuttingBench/CuttingBench/BenchFindingsStore.swift` — T3 and T4

The whole file is 71 lines and this rewrites the second half of it. The cheap half at `:46`
(`structural = structuralFindings(pattern)`) and the structural short-circuit at `:49`–`:53` are
**unchanged**: that is D2's inline half and D3's "the geometric checks did not run" path.

Add the import for the new symbols — `geometricFindings` and `solidFindings` already resolve through
`import BenchGeometry`, and `solidFindings` needs one new scoped kernel import:

```swift
import func FacetKernel.solidFindings
```

New stored properties, beside `generation` and `running`:

```swift
  /// The per-tier half, kept between rebuilds (D1). Reset with the document, never pruned by hand.
  private var cache = TierFindingsCache()

  /// `#if DEBUG` readouts only, so the owner can watch the cache and the quiet period work. Cumulative
  /// since this store was made, and never reset: a rising number is easier to read than a ratio.
  private(set) var tierChecksRun = 0
  private(set) var geometricPassesRun = 0
  /// True from the moment an edit arms a deferred pass until that pass starts running or is replaced.
  private(set) var isArmed = false
```

`rebuild`'s no-pattern branch at `:39`–`:44` also clears the cache and the armed flag:

```swift
    guard let pattern, let solution = solid.solution else {
      structural = []
      geometric = []
      isChecking = false
      isArmed = false
      cache = TierFindingsCache()
      return
    }
```

and so does the structural short-circuit at `:49`, which must additionally **leave the cache alone**: a
pattern whose structure is wrong will be repaired, and the per-tier results for the tiers before the
fault are still correct.

```swift
    guard structural.isEmpty else {
      geometric = nil
      isChecking = false
      isArmed = false
      return
    }
```

Then the deferred pass replaces `:55`–`:60`:

```swift
    let needed = cache.retain(pattern)

    isChecking = true
    isArmed = true
    running = Task.detached(priority: .userInitiated) { [weak self] in
      // The quiet period (D4). A burst of committed edits leaves one pass standing: every earlier task
      // is cancelled here, before it has done any work at all.
      do { try await Task.sleep(for: geometricQuietPeriod) } catch { return }
      await self?.startedRunning(generation: generation)

      let computed = runTierChecks(
        tiers: needed, pattern: pattern, solution: solution, isCancelled: { Task.isCancelled })
      // Whole-solid and never cacheable, so it is recomputed every pass — and skipped on a cancelled
      // one, which has nothing to report it beside.
      let whole = computed == nil ? [] : solidFindings(solution, declaredFacetCount: nil)
      await self?.accept(computed, whole: whole, generation: generation)
    }
```

Two main-actor methods. `startedRunning` exists only to clear the armed flag, which is what makes the
`#if DEBUG` readout distinguish waiting from working:

```swift
  private func startedRunning(generation: Int) {
    guard generation == self.generation else { return }
    isArmed = false
  }

  /// A run from a superseded generation lands nowhere. `nil` is a cancelled run: it reports nothing
  /// rather than a partial list, and leaves the previous result standing and still marked stale.
  ///
  /// **`declaredFacetCount` is deliberately absent**, as it is in `geometricFindings`: the declared count
  /// is the Facet Count card's business, and counting it here would report one fault twice.
  private func accept(_ computed: [String: [Finding]]?, whole: [Finding], generation: Int) {
    guard generation == self.generation else { return }
    isChecking = false
    isArmed = false
    guard let computed else { return }

    for (tier, findings) in computed { cache.record(findings, forTier: tier) }
    tierChecksRun += computed.count
    geometricPassesRun += 1

    // Fail closed. The run computed exactly the tiers `retain` asked for, so the cache is complete here;
    // if it somehow is not, `nil` reads as "no result yet" rather than as a count that is too low.
    guard let kept = cache.complete else {
      geometric = nil
      return
    }
    geometric = kept + whole
  }
```

**What the counters make observable.** `tierChecksRun` rises by the number of tiers a pass actually
checked, which is what the cache exists to hold down; `geometricPassesRun` rises once per pass that
reached the readout, which is what the quiet period exists to hold down. Both are the verification
handles for T3 and T4.

**Note the cost this leaves in place.** `store.setPattern` at `BenchWindow.swift:165` still re-solves the
whole pattern on the main thread on every committed edit, and this part does not change that — see
*Explicitly not doing*.

### 4. `CuttingBench/BenchGeometry/Sources/BenchGeometry/PatternDraft.swift` — T5

**Two new `DraftRefusal` cases**, appended after `.noTiers` at `:190`:

```swift
  /// The `finished` transition declined, with each finding as its own sentence (D10).
  case finishedWithFindings([String])
  /// The `finished` transition declined because the solve does not reach the end of the pattern (D11).
  case finishedWithSolveStoppedShort(tier: String, reason: String)
```

**Their messages**, appended to the `switch` in `message` before its closing brace:

```swift
    case .finishedWithFindings(let sentences):
      // A bulleted list rather than `list(_:)`'s commas: these are whole sentences, and comma-joining
      // sentences is unreadable at four of them.
      "This pattern cannot be marked finished yet — "
        + "\(sentences.count) \(sentences.count == 1 ? "finding" : "findings") fired:\n"
        + sentences.map { "• \($0)" }.joined(separator: "\n")
    case .finishedWithSolveStoppedShort(let tier, let reason):
      "This pattern cannot be marked finished: the solve stops at \(tier) — \(reason). "
        + "A tier that will not place has no facets on the stone."
```

**One wording change**, at `:220`. Drop the leading `"This pattern cannot be saved yet: "` from
`.tiersWithoutMeet`, so the sentence reads from its subject:

```swift
    case .tiersWithoutMeet(let tiers):
      // No "cannot be saved" prefix: this case now answers a `finished` transition as well as a save, and
      // `DraftSaveError.errorDescription` already says "This pattern cannot be saved yet." above it.
      "\(list(tiers)) \(tiers.count == 1 ? "has" : "have") no meet. "
        + "Choose one for each, or delete the tier."
```

This is a visible string change and it fixes a doubling in the save sheet, where
`CuttingBench/CuttingBench/PatternDocument.swift:90`
(`var errorDescription: String? { "This pattern cannot be saved yet." }`) already carries the same
clause. **Two existing assertions must be updated to match**:
`CuttingBench/BenchGeometry/Tests/BenchGeometryTests/PatternDraftTests.swift:154` and `:164`.

### 5. `CuttingBench/BenchGeometry/Sources/BenchGeometry/DraftEdits.swift` — T5

One setter, added beside the other header edits after `setting(name:in:)` at `:200`. It never refuses:
`state` is one of two values and neither can orphan anything. The **check** that guards the transition
lives in `FinishCheck.swift`, not here, because it needs a solve and this file is edits on a draft.

```swift
/// **Never refused here.** Whether `finished` may be claimed is `finishRefusal`'s question, asked by the
/// window before this is applied; going back to `in progress` claims nothing and is always allowed (D13).
public func setting(state: PatternState, in draft: PatternDraft)
  -> Result<PatternDraft, DraftRefusal>
{
  var edited = draft
  edited.state = state
  return .success(edited)
}
```

### 6. New: `CuttingBench/BenchGeometry/Sources/BenchGeometry/FinishCheck.swift` (pure — no framework, no I/O)

D9, D11, D12 and D14. `import FacetKernel` and nothing else.

```swift
/// Whether the pattern may be marked `finished`, and why not when it may not (D8, D9).
///
/// **Solves and validates from scratch, synchronously.** The deferred pass may be mid-flight and the
/// per-tier cache may hold nothing for the tiers just edited, so the one place in the app where a check
/// blocks is also the one place that trusts neither.
///
/// Three refusals, in the order they can be answered: a draft with no file form at all, a solve that does
/// not reach the end, and a validation that finds something. `nil` is the transition allowed.
///
/// `declaredFacets` is the Facet Count card's field as typed. With nothing making a claim there, that one
/// check does not run rather than blocking the transition (D12).
public func finishRefusal(draft: PatternDraft, declaredFacets: String) -> DraftRefusal? {
  // The draft, not `displayPattern`: that one silently drops a tier with no meet, and validating it would
  // validate something other than what the author wrote (D14, ADR-0003).
  let pattern: Pattern
  switch draft.completePattern() {
  case .failure(let refusal): return refusal
  case .success(let complete): pattern = complete
  }

  // `solveAsFarAsPossible`, matching what the display solves, so the verdict is about the same geometry
  // the owner is looking at. A failure here is not a finding and would otherwise pass unremarked (D11).
  let partial = solveAsFarAsPossible(pattern)
  if let failure = partial.failure {
    return .finishedWithSolveStoppedShort(tier: failure.tier, reason: failure.description)
  }

  // The kernel's own composite, never a second assembly of the three halves here: `validate` already
  // orders them and already declines to report geometry for a pattern whose structure is wrong.
  let report = validate(
    pattern, partial.solution, declaredFacetCount: declaredCount(declaredFacets))
  guard !report.findings.isEmpty else { return nil }
  return .finishedWithFindings(report.findings.map(findingText))
}
```

`findingText` is this module's own — `Findings.swift:140` — so the alert's sentences are the same ones the
findings popover shows, and the log line records them verbatim (D10).

### 7. `CuttingBench/CuttingBench/BenchRegions.swift` — T3, T4 and T6

**T6, the State row.** `PatternCard` at `:563` gains a closure and its `row("State")` at `:574` becomes a
control:

```swift
private struct PatternCard: View {
  let draft: PatternDraft
  let edit: (String, DraftChange) -> Bool
  /// Applied only once the transition has been allowed. The window owns the check, because the check
  /// needs the declared facet count, which is the window's session state.
  let setState: (PatternState) -> Void
```

```swift
      row("State") {
        // A segmented `Picker` rather than a `Toggle`: the two values have names — `in progress` and
        // `finished` — and a switch would show only one of them.
        //
        // **The binding's getter is the draft**, so a refused transition needs no revert code: the draft
        // is untouched, the next body pass reads the old value back, and the control springs back. The
        // same mechanism `EditableCell` uses.
        Picker("", selection: Binding(get: { draft.state }, set: { setState($0) })) {
          Text(PatternState.inProgress.rawValue).tag(PatternState.inProgress)
          Text(PatternState.finished.rawValue).tag(PatternState.finished)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
      }
```

**Rewrite the doc comment at `:555`.** It currently says both `state` and the gear are read-only and that
neither's machinery is built. Now only the gear is: keep the gear clause and its reason, drop the `state`
clause, and say that the `state` switch's check lives in `finishRefusal`.

**T3 and T4, the debug segment.** `StatusStripRegion`'s `#if DEBUG` block at `:670`–`:680` gains three
values, and `documentSummary` at `:723` gains one clause at the end:

```swift
    /// What the deferred half of validation has actually done, so the per-tier cache and the quiet
    /// period are both watchable.
    let tierChecks: Int
    let geometricPasses: Int
    let isArmed: Bool
```

```swift
      let checks = "checks \(geometricPasses) · tiers \(tierChecks)\(isArmed ? " · armed" : "")"
      return "\(document) · \(counts) · \(rough)\(stopped) · frames \(cachedFrames)/\(stepTotal)"
        + " · \(draftLine) · \(checks)"
```

### 8. `CuttingBench/CuttingBench/BenchWindow.swift` — T3, T4 and T6

The `#if DEBUG` `StatusStripRegion` call at `:79`–`:86` passes the three new values from
`findingsStore`. The `#else` call at `:88`–`:92` is unchanged.

`InspectorRegion` at `:102` gains `setState: setState(_:)`, and `InspectorRegion` itself (`:403`, in
`BenchRegions.swift`) gains the parameter and forwards it to `PatternCard` at `:422`.

The window's own method — the only place D8, D10 and D13 meet:

```swift
  /// The `state` switch. **The one check in this app that blocks rather than reports** (D8): everywhere
  /// else the author is mid-work, here they are asserting something about the result.
  ///
  /// Going back to `in progress` claims nothing, so it is applied without a check (D13). The refusal goes
  /// through the same presenter every other refused edit does, which is what puts it in the unified log.
  private func setState(_ state: PatternState) {
    if state == .finished,
      let refusal = finishRefusal(draft: document.draft, declaredFacets: declaredFacets)
    {
      refusals.present(refusal)
      return
    }
    edit("Change State", { setting(state: state, in: $0) })
  }
```

## Explicitly not doing

- **No caching or deferral of the solve.** `store.setPattern` re-solves the whole pattern on the main
  thread on every committed edit — `BenchWindow.swift:165` (`store.setPattern(document.pattern)`) — and
  that stays. The folded-in ticket is about the named-point check specifically, which is **1.65 s** on a
  139-plane pattern against **0.60 s** for the solve, and the solver's own comment says editing an early
  tier moves every later depth so there is nothing to update incrementally. Making the solve incremental
  is a different piece of work with a different answer.
- **No progress indicator, and no async path, for the `finished` transition.** It solves and validates on
  the main actor, which on `Kiev Triangle` is around two seconds of unresponsive window. Accepted: it is a
  deliberate one-off action, `Easy Octagon` — the completion bar — is 37 facets where it is imperceptible,
  and an async transition would be a second validation lifecycle beside the deferred one, with its own
  in-flight state for the switch to show.
- **No warning-and-allow, and no silent allow, on the `finished` transition.** Either would make `state` a
  label rather than a claim, which is the escape the field was introduced to prevent.
- **No change to `geometricFindings(pattern:solution:isCancelled:)`.** It stays as the uncached oracle the
  cache is tested against. If it looks like dead code after T3, it is not: `FindingsTests.swift` and
  `FindingsCacheTests.swift` are its callers.
- **No `Settings` toggle for the quiet period, and no way to turn the deferral off.** D4: one build
  constant. A setting that changes when a check runs is worse than editing the number.
- **No symmetry controls, no gear popup, no meet picking.** Parts 3, 4 and 5. The gear stays read-only in
  the Pattern card, and the reason stays in its doc comment.
- **No new `Finding` case and no change to `findingText`.** The two new refusals are `DraftRefusal` cases,
  which is where a refused *edit* lives; a `Finding` is something validation reports about a pattern.
- **No change to `Kernel/`.** Everything this part needs from the kernel is already public. If a task
  appears to need a kernel change, that is a stop rule, not a scope decision.
- **No change to `design-authoring-format.md`.** No task here names it, and the protocol permits edits to
  it only through a task that does.
- **No reordering, grouping or sorting of tiers anywhere** (D15). Tier order is data.

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
here because the new counters are read only in the debug branch. `-disable-sandbox` is required, or the
`@Observable` macro plugin fails with `sandbox_apply: Operation not permitted` and floods the output. It
compiles no `.metal` and no resources, so it replaces neither the owner's build nor an owner-stop
verification. If the `-I` path does not exist, the `swift build` line above creates it.

| # | Task | Status | Then | Commit | Note |
|---|---|---|---|---|---|
| T1 | Prefactor: one rule for parsing the declared facet count | completed | continue | — | |
| T2 | Pure: the surviving prefix, the per-tier cache, and the oracle test | completed | checkpoint | commit | material alteration ↓ |
| T3 | The store validates from the cache | awaiting owner | **owner stop** | commit | |
| T4 | The quiet period before the expensive half | not started | **owner stop** | commit | |
| T5 | Pure: the finish verdict and its refusals | not started | checkpoint | commit | |
| T6 | The state switch in the inspector | not started | **owner stop** | commit | |
| T7 | Close out | not started | **owner stop** | commit + push | |

**T1 — Prefactor: one rule for parsing the declared facet count**

- **Files:** `CuttingBench/BenchGeometry/Sources/BenchGeometry/MetricsReadout.swift` (edit)
- **Done when:**
  - `declaredCount(_:)` exists as written in Approach §1, `internal`, with its doc comment.
  - `facetCountCheck` calls it, and its four verdict strings are unchanged character for character:
    `"No count declared."`, `"Not a facet count."`, `"Declared \(count) · solved \(split)."`,
    `"Matches the declared \(count)."`.
  - `swift test --package-path CuttingBench/BenchGeometry --disable-sandbox` passes with **every existing
    assertion unedited** — this is behaviour-preserving, so a test that needs changing means the
    extraction changed something and is a stop rule.
- **Do not:** change `FacetCountCheck`, `unmeasurableReason`, `splitFacetCount`, or the card that reads
  them. Do not make `declaredCount` `public` — `FinishCheck.swift` is in the same module. Do not fold the
  empty-versus-unparseable distinction into it: the two produce different verdicts and that difference is
  the card's.

**T2 — Pure: the surviving prefix, the per-tier cache, and the oracle test**

The risk-first task among the behaviour changes: if the prefix property does not hold in practice, T3 and
T4 are built on sand, and the oracle test is what proves it does.

- **Files:** `CuttingBench/BenchGeometry/Sources/BenchGeometry/FindingsCache.swift` (new),
  `CuttingBench/BenchGeometry/Tests/BenchGeometryTests/FindingsCacheTests.swift` (new)
- **Done when:**
  - `FindingsCache.swift` holds `geometricQuietPeriod`, `survivingTierPrefix(from:to:)`,
    `TierFindingsCache` and `runTierChecks(tiers:pattern:solution:isCancelled:)` exactly as Approach §2
    gives them, doc comments included.
  - `FindingsCacheTests.swift` is a table-style `XCTestCase` in the same shape as
    `FindingsTests.swift` — `import FacetKernel`, `@testable import BenchGeometry`, the
    `AuthoredPatterns` loader from `BenchSolidTests.swift`, and a private `synthetic(_:)` helper if a
    manufactured pattern is needed. It covers, at minimum:
    - **The oracle.** For each of `AuthoredPatterns.all`: cache a whole pattern from cold, and assert
      `cache.complete! + solidFindings(solution, declaredFacetCount: nil)` equals
      `geometricFindings(pattern: pattern, solution: solution)!` — element for element, in order.
    - **The oracle after an edit.** Take `AuthoredPatterns.easyOctagon`, cache it cold, then change the
      last tier's `instructions` and re-`retain`; assert the returned list is exactly `["T"]`, run the
      checks, and assert the concatenation still equals the uncached `geometricFindings` for the edited
      pattern.
    - **The prefix rule, per field.** `survivingTierPrefix` returns the full tier count when only `name`,
      `designer`, `notes`, `ri`, `state` or `formatVersion` differ; `0` when `wheel` differs; `0` when
      `girdleTargetFraction` differs; `0` when `previous` is `nil`; and the index of the first differing
      tier when one tier's `angle`, `indices`, `part`, `wheel`, `meet`, `instructions` or `tier` label
      differs.
    - **Append checks one tier.** Appending a tier to `easyOctagon` returns a one-element list.
    - **Delete and reorder.** Deleting the third tier returns the tiers from position 2 onward; swapping
      two adjacent tiers returns from the earlier of the two onward.
    - **A rename drops the stale entry.** After renaming `P2`, `cache.perTier` holds no key `"P2"`, and
      `retain` returns `P2`'s new label and every tier after it.
    - **A short cache is not a result.** `complete` is `nil` before every tier has an entry, and non-`nil`
      immediately after the last one is recorded.
    - **Cancellation reports nothing.** `runTierChecks(…, isCancelled: { true })` returns `nil`.
    - **The constant.** `geometricQuietPeriod == .milliseconds(250)`.
  - `swift test --package-path CuttingBench/BenchGeometry --disable-sandbox` passes, including these
    new cases, and **every existing assertion is unedited**.
- **Do not:** touch `Findings.swift` — `geometricFindings` is the oracle and changing it would let a
  broken cache agree with a broken oracle. Do not add a `declaredFacetCount` parameter anywhere in this
  file. Do not make `TierFindingsCache` `Equatable`. Do not sort, group or normalise tiers (D15).
- **Material alteration.** `survivingTierPrefix`'s `while` line as the Approach writes it is 101
  characters, one over the formatter's limit, so the unconditional lint gate fails on the plan's own
  snippet. The body is now the same condition with `n += 1` on its own line, which is what
  `swift-format` produces from it. No other line of the Approach's code changed.

**T2 commit point:**

```
4-cutting-bench-authoring-2 T1-T2: cache the expensive half per tier

- One rule for parsing the declared facet count, extracted ahead of its second caller
- The surviving-tier-prefix rule, the per-tier cache, and the run that fills it
- Proven against the uncached whole-pattern check on all four authored patterns
```

**T3 — The store validates from the cache**

- **Files:** `CuttingBench/CuttingBench/BenchFindingsStore.swift` (edit),
  `CuttingBench/CuttingBench/BenchRegions.swift` (edit), `CuttingBench/CuttingBench/BenchWindow.swift` (edit)
- **Done when:**
  - `BenchFindingsStore` holds `cache`, `tierChecksRun`, `geometricPassesRun` and `isArmed`, and its
    deferred pass is Approach §3's — **without the `Task.sleep`, which is T4.** Everything else in §3
    lands here: `retain`, `runTierChecks`, `solidFindings`, `startedRunning`, and the rewritten `accept`.
  - The cheap half and the structural short-circuit are unchanged except for the two added lines
    (`isArmed = false`, and the cache reset in the no-pattern branch only).
  - `StatusStripRegion`'s `#if DEBUG` block takes `tierChecks`, `geometricPasses` and `isArmed`, and
    `documentSummary` ends with `· checks P · tiers T` and `· armed` when armed.
  - `BenchWindow`'s `#if DEBUG` `StatusStripRegion` call passes the three from `findingsStore`; the
    `#else` call is untouched.
  - Both `swiftc -typecheck` runs are clean, `-DDEBUG` and without.
  - `swift test --package-path CuttingBench/BenchGeometry --disable-sandbox` passes with **every existing
    assertion unedited**.
- **Do not:** add the quiet period (T4). Do not clear the cache in the structural short-circuit — the
  entries before the fault are still correct. Do not pass a `declaredFacetCount` to `solidFindings` here.
  Do not touch `findingsReadout`, the strip's findings line, or the `#else` strip.
- **Verification handle** — `permanent`:
  - **Where:** the `#if DEBUG` status strip at the bottom of the window, right-hand end. It now ends
    `… · checks P · tiers T`. Open `Design/Patterns/Pattern-Easy-Octagon.json`, which has six tiers —
    `G1 P1 P2 C1 C2 T`. Note both numbers once the window settles.
  - **Positive:** click tier **T**'s **Instructions** cell in the tier table, type `level table`, press
    Return → `tiers` rises by **exactly 1**, and `checks` rises by 1. Only the last tier was re-checked.
  - **Negative:** click the inspector's **Designer** field, type a character, press Return → `tiers` does
    **not change at all** while `checks` rises by 1. A pass ran and found nothing to recompute.
  - **Reads:** `tierChecksRun` in `BenchFindingsStore.swift`, fed by `runTierChecks` and
    `TierFindingsCache.retain` in `FindingsCache.swift`. Delete the cache and the negative case raises
    `tiers` by 6 instead of 0, and the positive by 6 instead of 1.

**T3 commit point:**

```
4-cutting-bench-authoring-2 T3: the findings store checks only what moved

- The per-tier cache drives the deferred pass; an edit re-checks from that tier on
- A DEBUG strip segment counts the passes run and the tiers actually checked
```

**T4 — The quiet period before the expensive half**

- **Files:** `CuttingBench/CuttingBench/BenchFindingsStore.swift` (edit)
- **Done when:**
  - The deferred task begins `do { try await Task.sleep(for: geometricQuietPeriod) } catch { return }`,
    followed by `await self?.startedRunning(generation: generation)`, exactly as Approach §3 gives it.
  - `isArmed` is `true` from `rebuild` until `startedRunning` or the next `rebuild`, and `false`
    afterwards — including on every early-return path in `rebuild`.
  - A cancelled sleep returns without calling `accept`, so a superseded pass costs nothing.
  - Both `swiftc -typecheck` runs are clean, `-DDEBUG` and without.
  - `swift test --package-path CuttingBench/BenchGeometry --disable-sandbox` passes with **every existing
    assertion unedited**.
- **Do not:** make the quiet period conditional on how many tiers need checking — one rule, always (D4).
  Do not add a `Settings` entry, a launch argument, or any other way to change or disable it. Do not
  change `isChecking`'s meaning or the strip's `stale, checking…` wording (D3).
- **Verification handle** — `permanent`:
  - **Where:** the same `#if DEBUG` strip segment, which now also shows `· armed` while a pass is waiting
    out its quiet period. Open `Pattern-Easy-Octagon.json`.
  - **Positive:** watch the strip and press Return in tier **T**'s Instructions cell → `· armed` appears
    immediately, disappears about a quarter second later, and then `checks` rises by **exactly 1**. To see
    the coalescing: make six angle edits first, then hold **⌘Z** down for two seconds — key repeat is far
    faster than the quiet period, so `· armed` stays lit for the whole hold and `checks` rises by **1 or
    2 in total**, not once per undo.
  - **Negative:** orbit the stone by dragging in the viewport, then move the playback slider → `· armed`
    **never appears** and `checks` does **not change**. Neither is an edit.
  - **Reads:** `isArmed` and `geometricPassesRun` in `BenchFindingsStore.swift`, and
    `geometricQuietPeriod` in `FindingsCache.swift`. Delete the sleep and `· armed` never becomes visible
    and the held-⌘Z case raises `checks` by dozens.

**T4 commit point:**

```
4-cutting-bench-authoring-2 T4: a quiet period before the expensive half

- A burst of committed edits leaves one deferred pass standing, cancelled before any work
- 250 ms, one build constant and not a preference
```

**T5 — Pure: the finish verdict and its refusals**

- **Files:** `CuttingBench/BenchGeometry/Sources/BenchGeometry/FinishCheck.swift` (new),
  `CuttingBench/BenchGeometry/Sources/BenchGeometry/PatternDraft.swift` (edit),
  `CuttingBench/BenchGeometry/Sources/BenchGeometry/DraftEdits.swift` (edit),
  `CuttingBench/BenchGeometry/Tests/BenchGeometryTests/FinishCheckTests.swift` (new),
  `CuttingBench/BenchGeometry/Tests/BenchGeometryTests/PatternDraftTests.swift` (edit)
- **Done when:**
  - `DraftRefusal` carries `finishedWithFindings([String])` and
    `finishedWithSolveStoppedShort(tier:reason:)`, with the messages Approach §4 gives verbatim.
  - `.tiersWithoutMeet`'s message has lost its `"This pattern cannot be saved yet: "` prefix, and the two
    assertions at `PatternDraftTests.swift:154` and `:164` are updated to the new sentences. **Those are
    the only two existing assertions this task may edit.**
  - `setting(state:in:)` exists in `DraftEdits.swift` as Approach §5 gives it.
  - `finishRefusal(draft:declaredFacets:)` exists in `FinishCheck.swift` as Approach §6 gives it.
  - `FinishCheckTests.swift` is a table-style `XCTestCase` in `FindingsTests.swift`'s shape, covering:
    - **All four authored patterns are allowed.** For each of `AuthoredPatterns.all`, built as a
      `PatternDraft`, `finishRefusal(draft:declaredFacets: "")` returns `nil`.
    - **A tier with no meet refuses, and names it.** Append a tier to `easyOctagon`'s draft →
      `.tiersWithoutMeet(["N1"])`, whose message names `N1` and does not begin `"This pattern"`.
    - **An empty draft refuses** with `.noTiers`.
    - **A structural fault refuses and lists it.** Change `easyOctagon`'s `G1` meet from `size` to `tcp`,
      leaving no size row → `.finishedWithFindings`, whose array holds exactly one sentence and that
      sentence is `findingText(.notExactlyOneSizeRow(count: 0))`.
    - **A stopped solve refuses by itself.** A synthetic two-tier pattern that cuts a crown tier with a
      `girdle` meet before the girdle — the same one `FindingsTests.swift:78` builds — returns
      `.finishedWithSolveStoppedShort(tier: "C1", …)`, and the reason is `SolverError.description`
      verbatim. Assert the case, not the wording of the reason.
    - **The declared count is optional and does not block.** On a clean `easyOctagon` draft:
      `declaredFacets: ""` → `nil`; `declaredFacets: "  "` → `nil`; `declaredFacets: "5x"` → `nil`;
      `declaredFacets: "0"` → `nil`. Its solved count → `nil`. A wrong positive count, e.g. `"99"`, →
      `.finishedWithFindings` holding one `facetCountMismatch` sentence.
    - **`in progress` is never checked.** `setting(state: .inProgress, in:)` succeeds on a draft that
      `finishRefusal` refuses, and on an empty draft.
    - **The message lists every finding, one bulleted line each.** For a two-finding case, the message
      contains two `"• "` lines and the word `findings`; for a one-finding case, `finding`.
  - `swift test --package-path CuttingBench/BenchGeometry --disable-sandbox` passes.
- **Do not:** call `finishRefusal` from anywhere yet — T6 wires it. Do not add a `Finding` case, and do not
  touch `findingText`, `findingTier`, `Findings.swift` or `Validation.swift`. Do not reassemble the three
  validation halves by hand: call the kernel's `validate`. Do not use `draft.displayPattern` (D14). Do not
  make `finishRefusal` `async`, and do not add a progress or in-flight state.

**T5 commit point:**

```
4-cutting-bench-authoring-2 T5: the verdict behind a finished claim

- Solves and validates from scratch, trusting neither the deferred pass nor the cache
- Refuses a tier with no meet, a solve that stops short, and any finding, listing each
- The declared facet count blocks nothing when the field makes no claim
```

**T6 — The state switch in the inspector**

- **Files:** `CuttingBench/CuttingBench/BenchRegions.swift` (edit),
  `CuttingBench/CuttingBench/BenchWindow.swift` (edit)
- **Done when:**
  - `PatternCard` takes `setState: (PatternState) -> Void` and its `State` row is the segmented `Picker`
    Approach §7 gives, bound through a getter on `draft.state`.
  - `InspectorRegion` takes `setState` and forwards it; `BenchWindow` passes `setState(_:)` and holds the
    method Approach §8 gives.
  - The doc comment at `BenchRegions.swift:555` is rewritten: the gear stays read-only with its reason,
    the `state` clause is gone, and it says the switch's check is `finishRefusal`.
  - A refused transition presents through `refusals` and therefore reaches the unified log at `.notice`
    and `.public`, with no second wording anywhere (D10, U13).
  - Both `swiftc -typecheck` runs are clean, `-DDEBUG` and without.
  - `swift test --package-path CuttingBench/BenchGeometry --disable-sandbox` passes with **every existing
    assertion unedited**.
- **Do not:** make the gear editable — that is part 3. Do not add revert code to the `Picker`: the draft
  getter is the revert. Do not present the refusal any way other than through `refusals.present`. Do not
  check anything on the way back to `in progress` (D13). Do not read or write `declaredFacets` anywhere but
  as the argument to `finishRefusal`.
- **Verification handle** — `permanent`:
  - **Where:** the inspector's **Pattern** card, the **State** row, now a two-segment control reading
    `in progress` / `finished`; and the `#if DEBUG` strip, whose first segment reads
    `Easy Octagon · <state> · 6 tiers`. Open `Design/Patterns/Pattern-Easy-Octagon.json`, which is
    authored as `finished`, so the control starts on `finished`.
  - **Positive:** click **in progress** → it moves there with no alert, and the strip reads
    `Easy Octagon · in progress · 6 tiers`. Click **finished** again → it moves back, no alert, and the
    strip reads `· finished ·`. The pattern is clean, so the assertion is allowed.
  - **Negative:** with the pattern back on `in progress`, add a tier (the tier table's add control) — a row
    `N1` appears with no meet. Now click **finished** → an *Edit refused* alert appears reading
    `N1 has no meet. Choose one for each, or delete the tier.`, the control **springs back to
    `in progress`**, and the strip still reads `· in progress ·`. Dismiss it and check
    `log show --predicate 'subsystem == "DigitalEnki.CuttingBench"' --last 5m` — the same sentence is
    there.
  - **Reads:** `finishRefusal` in `FinishCheck.swift` and `setting(state:in:)` in `DraftEdits.swift`, via
    `setState(_:)` in `BenchWindow.swift`. Delete `finishRefusal`'s body and the negative case is allowed
    silently.

**T6 commit point:**

```
4-cutting-bench-authoring-2 T6: claim a pattern finished, or be told why not

- The state row is a two-way switch; finished is refused while anything fires, and lists it
- Going back to in progress claims nothing and is never checked
```

**T7 — Close out**

- **Files:** this plan (edit), `Design/Tickets/` (new tickets only, if the Deferred section names any)
- **No temporary handles to delete.** All three handles in this part are `permanent`: two `#if DEBUG`
  strip segments displaying real store state, and the State control itself. Nothing was scaffolded.
- Confirm every item in this plan's **Deferred** section has a ticket in `Design/Tickets/` with
  `Status: untriaged`, filed per the protocol as each was found. This is the check, not the filing.
- Report the untriaged ticket count in `Design/Tickets/`, one line.
- Set this plan's `Status:` line to `**PART 2 COMPLETED** (<date>)`, with the same note part 1 carries:
  not archived, because the final part archives the whole set.
- `commit + push` with the message below.
- **Archive nothing, and close no ticket.** This is part 2 of five. The exploration
  `4-Cutting-Bench-Authoring` is still the design source for parts 3, 4 and 5;
  `Chore-Validation-Rebuilds-The-Solid-Once-Per-Tier` stays open until
  `4-Cutting-Bench-Authoring-5-Fraction-Meets` closes it; and this plan is archived by that part, not by
  itself. **Do not invoke the protocol's archive routine in this task.**

```
4-cutting-bench-authoring-2 T7: close out the validation slice

- Per-tier caching, the quiet period, and the state switch, all verified in the app
- Part 2 of five: nothing archived and no ticket closed, per the plan's own close-out
```

## Deferred

Empty at authoring. The executor appends adjacent problems it found and must not fix — and files each as
a ticket in `Design/Tickets/` immediately with `Status: untriaged`, per the protocol.
