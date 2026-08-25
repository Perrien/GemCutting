# 3 · Cutting Bench Pattern Display — Part 4: Playback

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
   display mode. Retires the debug tier-limit stepper. ← this part
5. `3-Cutting-Bench-Pattern-Display-5-Light` — the critical-angle marking on pavilion tier rows, and
   the clickable single-ray probe with its per-bounce incidence readout, offered only when the
   pattern's own solid closes. Closes the exploration out and runs the archive routine.

| Exploration ID | Part |
|---|---|
| S1 | 1, 2, 4, 5 — the slice's scope statement rather than a unit of work; its done-conditions land per part. |
| S2 | 5 |
| I1 | 1 — its scaffolding rule binds this part per step and is restated here as D8; its rule that the kernel's own rough-free solid is what `metrics` and `validate` see is restated as D19 |
| I2 | 1 — its partial-solve state is what D9 reports on here |
| I3 | 4 |
| I4 | 5 |
| I5 | 2 |
| U1 | 3 — its trigger clause, "opening or scrubbing a pattern", is what D1 satisfies here |
| U2 | 2 |
| U3 | 1 |
| U4 | 3 |
| U5 | 4 |
| U6 | 4 |

**No boundary has moved.** The split is the one the owner approved on 2026-08-25, and parts 1, 2 and 3
shipped against it. The exploration's non-goals bind every part unchanged — in particular **nothing in
this part edits or saves anything**, and nothing here animates a facet's arrival.

**One correction inherited from part 1, and it binds this part's central mechanism.** The exploration's
grounding says `Novice Ash-er` stores its stops as `12 24 36 48 60 72 84 0`. Part 1 found that all four
authored patterns as they stand today store their stops **ascending**, so nothing in the corpus
exercises ascending-order playback. Part 1 recorded that the requirement belongs here; this part
implements it and exercises it with a constructed tier (D4, T2).

## Context

**Why the owner wants this.** A faceting pattern is a sequence of operations at a lap, and reading one
off a sheet means holding in your head what the stone looked like three tiers ago. The app already
draws the finished stone and fills the tier table in; what it cannot do is show the stone *becoming*
that. Playback is the readout that makes a pattern legible as instructions rather than as a table:
scrub back and you see the preform, scrub forward and you watch each tier — or each facet — take
material away.

There is a second, sharper reason. Today the only way to see a part-cut stone at all is a `#if DEBUG`
stepper in the status strip, kept alive by parts 1 and 2 explicitly because it is the only thing that
operates their checks. Every authored pattern is `finished` and cuts the whole prism away, so without
it the rough scaffolding, the partial-solve state and the "Metrics need every tier" sentence are all
unreachable. This part replaces that stepper with the real surface, and the stepper goes.

**What already exists that this builds on.**

- **The whole-stone builder, and the tier truncation it already supports.**
  `CuttingBench/BenchGeometry/Sources/BenchGeometry/BenchSolid.swift:104`
  (`public func benchSolid(for pattern: Pattern?, tierLimit: Int? = nil) -> BenchSolid`). It solves with
  `solveAsFarAsPossible`, asks the kernel's own closure check whether the scaffolding is still needed at
  `:117` (`let isOpen = solidFindings(partial.solution, declaredFacetCount: nil).contains { finding in`),
  merges the rough's planes at `:122` (`var (planes, origin) = roughScaffolding(included: isOpen)`), and
  builds the origin map from `planeOwner` at `:128`. **The part of that function after the solve is
  exactly what a step needs**, which is why it is lifted into its own function first (T1).
- **`tierLimit` re-solves a truncated pattern**, at `:107`
  (`truncated.tiers = Array(truncated.tiers.prefix(tierLimit))`). That is the thing this part must not do
  per step — and it is exactly what makes it a good independent oracle for the prefix path (D16, T3).
- **A tier's half-spaces can be re-expanded from its solved depth, by a public kernel function.**
  `Kernel/Sources/FacetKernel/Validation.swift:91` (`public func planes(of tier: SolvedTier) -> [Plane]`)
  maps each index stop to `Plane(n: planeNormal(angleDegrees: tier.angle, index: $0, wheel: tier.wheel,
  part: tier.part), d: tier.d)`. That is the identical expansion the solver itself performs at
  `Kernel/Sources/FacetKernel/Solver.swift:453` (`planes.append(Plane(n: normal, d: d))`) inside `place`,
  so re-expanding a solved tier reproduces the solver's own planes bit for bit — **no re-solve, and no
  second implementation of a depth**. `Validation.swift:81`
  (`public func intermediateSolid(before tier: String, of solution: Solution) -> Polytope`) already
  relies on that equality.
- **The solver appends planes tier by tier, and within a tier in file order.**
  `Solver.swift:450` (`for (stop, normal) in zip(spec.indices, normals) {`) with
  `:452` (`owner[planes.count] = (tier: spec.tier, index: stop)`). So a *tier* prefix is a plane prefix,
  but a *facet* step in ascending index order is not — which is why a step is a set of tiers plus a set
  of stops rather than a plane count (D3).
- **A tier's depth is fixed by the tiers before it, never by the ones after.** A meet naming a later
  tier is `Solver.swift:49` (`case forwardReference(tier: String, named: String)`), a reported failure
  and never something the solver resolves. That is what makes a prefix's depths identical to the whole
  solve's.
- **Everything downstream of the solid already handles a part-cut stone**, because parts 1–3 built it
  against the tier-limit stepper: `TierTable.swift:71` (`let placed = Set(solid.tiers.map(\.tier))`)
  drives the `.notReached` state, `IndexRing.swift:41` (`for tier in solid.tiers {`) drives the ring, and
  `MetricsReadout.swift:75` (`if solution.tiers.count != pattern.tiers.count {`) drives the "Metrics need
  every tier" sentence. **This part changes what the solid is, and those three follow with no edit.**
- **The scrubber's place in the layout is already there and empty.**
  `CuttingBench/CuttingBench/BenchRegions.swift:40` (`struct ScrubberRegion: View {`) renders the word
  "Scrubber", placed by `CuttingBench/CuttingBench/BenchWindow.swift:51` (`ScrubberRegion()`) directly
  under the viewport inside the split.
- **The off-main-thread idiom, with a generation guard and cancellation, is shipped.**
  `CuttingBench/CuttingBench/BenchFindingsStore.swift:63`
  (`running = Task.detached(priority: .userInitiated) { [weak self] in`) with the discard at `:71`
  (`guard generation == self.generation else { return }`). The precompute copies that shape, and every
  value it moves across is `Sendable` — `Plane`, `Polytope`, `Solution`, `BenchSolid` and `SolidMesh` all
  declare it.
- **The store that owns the drawn solid.** `CuttingBench/CuttingBench/BenchSolidStore.swift:29`
  (`func rebuildIfNeeded(pattern: Pattern?, tierLimit: Int?) {`) with its memo at `:30`
  (`guard builtPattern != .some(pattern) || builtTierLimit != tierLimit else { return }`). Playback goes
  here rather than into a second store (D11).

**Why this is a small change to known code.** No new geometry, no new kernel work, no new rendering.
The step list is arithmetic over `solid.tiers`; a step's solid is the existing scaffolding-and-merge
code over a re-expanded plane set; and the surfaces that read a solid already read a part-cut one. The
only genuinely new machinery is the frame cache and its progress readout, and that is one `Task.detached`
in the shape part 3 already shipped.

**The one honest cost.** `intersectHalfSpaces` at `Polytope.swift:47` is brute force over every triple
of planes, so it scales as about planes⁴. Summed over every facet-granularity step of the round
brilliant's 73 stops that is a real wait — the exploration measured the whole-corpus figure and put the
proper fix in the ticket `Chore-Incremental-Half-Space-Clipper`, which is not built here. **What this
part does instead is pay the cost once, on entering playback, with a determinate progress bar, and never
again while scrubbing** (D13). Two hulls are needed per open step, not one: the rough-free hull decides
closure and the rough-included hull is what is drawn — the same two the shipped builder already computes
at `BenchSolid.swift:138` (`polytope: isOpen ? intersectHalfSpaces(planes) : partial.solution.polytope`).
The executor is not asked to hit a number.

## Decisions (2026-08-25)

| # | Decision |
|---|---|
| D1 | **The scrubber drives the whole document's displayed solid**, exactly as the debug tier-limit stepper does today: viewport, index ring, tier-table row states, both measured cards and the findings all read the step's solid. One owner of the displayed solid, because a second would be a readout able to agree with a broken one. This is also what makes the exploration's "the trigger is opening or scrubbing a pattern" true. |
| D2 | **No re-solve per step.** A step re-expands the already-solved tiers' half-spaces from their solved depths with the kernel's public `planes(of:)`, which is the identical expansion the solver's own `place` performs. A tier's depth depends only on the tiers before it, so a prefix and the whole solve give identical depths. |
| D3 | **A step is a count of complete tiers plus the index stops of the tier being cut.** Not a plane count: the solver appends a tier's planes in file order and facet playback runs in ascending index order, so a step is a set, not a prefix length. |
| D4 | **Facet playback steps in ascending index-stop order, and nothing sorts the file.** A step's part-cut `SolvedTier.indices` is a sorted prefix — a derived value inside a step's solid. The tier table's Indices cell reads `pattern.tiers` (`TierTable.swift:92`), so the file's own order still prints. All four authored patterns store their stops ascending today, so the sort is exercised by a constructed `SolvedTier` and not by the corpus. |
| D5 | **Step 0 is the bare rough with nothing cut** — the preform. That is the first position of the intermediate-solid mode, and a list starting at one tier would have no way to show it. |
| D6 | **The granularity control has three positions — Off, Tier, Facet — and Off is what a document opens at.** A pattern opens as its finished self, never mid-playback. |
| D7 | **Entering playback selects the last step**, so the picture does not jump: the last step's solid is the whole stone, which is already on screen. |
| D8 | **The scaffolding rule applies per step**: the rough's eighteen half-spaces are in a step's intersection while that step's own planes fail to close, and out the moment they do. Part 1's rule, per step — otherwise a step showing a floating pavilion cone would be a step showing nothing recognisable. |
| D9 | **`stoppedAtTier` and `stoppedReason` are carried only at the last step.** Mid-scrub the tier that stopped the solve has not been reached, and marking it stopped would claim a failure at a point playback has not got to. Earlier steps therefore read `MetricsReadout.swift:76`'s "Metrics need every tier: n of m placed." rather than the stopped-tier sentence. |
| D10 | **Findings and metrics see the step's own prefix solution, part-cut tier and all.** No spurious finding follows: the part-cut tier is always the *last* in the prefix, so no meet can name a stop that is not there, and its own meet names only complete earlier tiers. A part-cut stone reporting `doesNotClose` is the truth about that step, not noise. |
| D11 | **`BenchSolidStore` gains playback; there is no second store.** Two stores each holding a solid is the same hazard D1 names, and the store already owns the memo that decides when a rebuild happens. |
| D12 | **`ScrubberRegion` stays a values-and-closures view**, like `ViewportRegion` and `TierTableRegion`. The window mutates the store and then rebuilds the findings, so a pattern change and a scrub go down one path instead of two. |
| D13 | **The frame cache is built eagerly on entering playback, off the main thread, with a determinate progress readout, and the slider is disabled until it finishes.** Computing on demand and caching as visited was rejected: it makes the first pass through a large pattern lumpy. **Choosing Off cancels the precompute** — there is no separate Cancel button, because the control that started the wait is the one to hand. |
| D14 | **No cap on the number of cached frames.** The round brilliant's 73 stops is 74 frames of triangles and edges — tens of megabytes at worst — and a cap would mean a threshold in the app that has to be explained. |
| D15 | **No auto-play and no timer.** Nothing in the exploration asks for one, and a stone building itself up on a clock is the animated arrival the exploration deferred to `Chore-Incremental-Half-Space-Clipper`. Playback is scrubbed and stepped, by hand. |
| D16 | **The `#if DEBUG` tier-limit stepper is deleted; `benchSolid(for:tierLimit:)` stays.** Parts 1 and 2 kept the stepper on the stated condition that this part's scrubber retires it. The *parameter* keeps earning its place for a different reason: it truncates the pattern and re-solves, which makes it the independent oracle proving the no-re-solve prefix path produces the same geometry (T3). It drives no UI after this part. |
| D17 | **A part-cut tier gets no new `TierRowState`.** Playback position is the scrubber's own readout; a fourth row state would make a transient scrub position look like a property of the pattern. A part-cut tier reads `.solved`, because it is in `solid.tiers`. |
| D18 | **Every scrub clears the facet selection and keeps the tier selection.** A plane index means nothing across a rebuild — the rough's eighteen come and go and the cut planes are re-expanded — so a kept index would leave the highlight on an unrelated facet. A tier *label* survives, and keeping it is what lets the owner scrub and watch one tier's meet dots arrive. This is `BenchWindow.swift:139`'s existing rule, unchanged. |
| D19 | **The prefix `Solution` is built rough-free, and the rough is merged only into what is drawn** (ADR-0004). `metrics` and `validate` must never see a rough-capped solid: a rough-capped solid always closes, so the closure check would pass for every pattern including the ones it exists to catch. |

## Tickets closed by this plan

None — closed in the final part. The exploration `3-Cutting-Bench-Pattern-Display` folded no tickets in,
and `Chore-Incremental-Half-Space-Clipper` is the ticket this part **defers to** rather than closes: it
is what would make each step roughly linear instead of planes⁴, and it is not built here.

## Prefactoring

**One prefactor, T1.** `benchSolid(for:tierLimit:)` at `BenchSolid.swift:104` does two things in one
body: it solves, and then it turns a rough-free `Solution` into the drawn solid — the closure test, the
rough merge, the origin map, the polytope choice. A step needs the second half over a `Solution` it built
itself, with no solve at all. T1 lifts that second half into its own function and leaves
`benchSolid(for:tierLimit:)` calling it.

It is behaviour-preserving, so its check is inverted: **nothing about the shipped builder may change, and
the existing tests pass unchanged.** No characterization task is needed, because `BenchSolidTests.swift`
already pins the behaviour being moved from four directions —
`testWithNoPatternTheSolidIsTheBarePrism` at `:44`, `testAFinishedPatternAddsNothingToTheKernelsOwnSolid`
at `:61` (all four authored patterns, facet and vertex counts against `solve(pattern).polytope`),
`testATierLimitOfZeroIsTheBarePrism` at `:180`, and `testTheStopIsTheTierAndTheKernelsOwnSentence` at
`:191`.

**One thing T1 must not do.** The shipped builder reuses the solver's own polytope when the solid closes
— `BenchSolid.swift:138` (`polytope: isOpen ? intersectHalfSpaces(planes) : partial.solution.polytope`) —
which is what keeps a finished 139-plane pattern from paying for a second hull on every document open.
The lifted function takes the `Solution` and must make the same choice from it. Re-intersecting
unconditionally would be a silent performance regression that no test catches.

## Approach

Five files. One existing function is split in two so a step can use its second half; one new pure file
holds the step list and the step solid; the store learns playback and owns the frame cache; the scrubber
region becomes real; and the window wires the two together and deletes the debug stepper.

### 1. `CuttingBench/BenchGeometry/Sources/BenchGeometry/BenchSolid.swift` — split the builder (T1)

`benchSolid(for:tierLimit:)` at `:104` (`public func benchSolid(for pattern: Pattern?, tierLimit: Int? =
nil) -> BenchSolid {`) keeps its signature, its whole doc comment and its no-pattern early return at
`:105` (`guard var truncated = pattern else { return roughOnly() }`). Everything from `:115`'s comment
through the `return BenchSolid(...)` at `:147` moves into a new internal function, verbatim apart from
the substitutions named below:

```swift
/// The drawn solid over a rough-free solution: the scaffolding decision, the rough merge, the origin
/// map and the polytope. **Nothing here solves** — the solution is already the answer for the cut
/// planes, whether it came from `solveAsFarAsPossible` or from re-expanding a prefix of solved tiers
/// (D2).
///
/// `solution` must be rough-free (ADR-0004): a rough-capped solid always closes, so the closure test
/// below would pass for every pattern including the ones it exists to catch.
func benchSolid(
  over solution: Solution,
  stoppedAtTier: String? = nil,
  stoppedReason: String? = nil
) -> BenchSolid
```

Three substitutions and nothing else:

- `partial.solution` becomes `solution`, at the closure test (`:117`), the plane loop (`:124`), the
  `planeOwner` lookup (`:128`), the polytope choice (`:138`) and the `tiers:` argument (`:141`).
- `partial.failure?.tier` (`:145`) and `partial.failure?.description` (`:146`) become the two parameters.
- `for (k, plane) in solution.planes.enumerated()` keeps `base + k` as its `origin` key, unchanged.

**`:138`'s conditional stays exactly as it is** — `polytope: isOpen ? intersectHalfSpaces(planes) :
solution.polytope`. Reusing the solution's own polytope when the solid closes is what keeps a finished
139-plane pattern from paying a second hull on every document open, and its comment at `:136` says so.

The caller becomes four lines:

```swift
  let partial = solveAsFarAsPossible(truncated)
  return benchSolid(
    over: partial.solution,
    stoppedAtTier: partial.failure?.tier,
    stoppedReason: partial.failure?.description)
```

Two doc-comment edits in the same file, and no other change:

- The `tierLimit` paragraph at `:100`–`:103` gains a sentence: it drives no UI after this part and stays
  as the independent oracle for the prefix path, because it truncates the *pattern* and re-solves (D16).
- `roughOnly()` at `:151` and `roughScaffolding(included:)` at `:159` are untouched.

### 2. New: `CuttingBench/BenchGeometry/Sources/BenchGeometry/Playback.swift` (pure — no framework, no I/O)

Four types and three functions. All of it is arithmetic over `solid.tiers` plus one call to the existing
builder, so all of it is checkable without a window.

```swift
/// The two granularities playback runs at (U5). No third: an animated facet arrival is deferred to the
/// ticket `Chore-Incremental-Half-Space-Clipper`, and there is no auto-play (D15).
public enum PlaybackGranularity: String, CaseIterable, Hashable, Sendable {
  case tier
  case facet
}

/// One position in the sequence: what has been cut at this point.
///
/// **A count of complete tiers plus the stops of the tier being cut, never a plane count** (D3): the
/// solver appends a tier's planes in the file's own stop order and facet playback runs in ascending
/// stop order, so a step is a set rather than a prefix.
public struct PlaybackStep: Equatable, Sendable, Identifiable {
  /// Solved tiers complete at this step. `0` is the bare preform (D5).
  public var completeTiers: Int
  /// The tier part-way cut, or `nil` at a tier boundary.
  public var partialTier: String?
  /// `partialTier`'s stops cut so far, **ascending**. Empty when `partialTier` is `nil`.
  public var partialStops: [Int]
  /// What the scrubber reads. Formatted here so the format is checkable without a window.
  public var label: String
  /// Position in the list, from `0`.
  public var id: Int

  public init(
    completeTiers: Int,
    partialTier: String? = nil,
    partialStops: [Int] = [],
    label: String,
    id: Int)
}

/// How far a precompute has got (D13).
public struct PlaybackProgress: Equatable, Sendable {
  public var done: Int
  public var total: Int

  public init(done: Int, total: Int)
}

/// One cached step: the solid and the mesh drawn for it.
public struct PlaybackFrame: Sendable {
  public var solid: BenchSolid
  public var mesh: SolidMesh

  public init(solid: BenchSolid, mesh: SolidMesh)
}
```

**`playbackSteps(_:granularity:)`** — the list, from the solid's own solved tiers:

```swift
/// Every position playback can be scrubbed to, in cutting order, step `0` first.
///
/// **Empty when the solve placed no tiers**, which is what leaves the granularity control disabled:
/// there is no sequence to step through.
public func playbackSteps(
  _ solid: BenchSolid,
  granularity: PlaybackGranularity
) -> [PlaybackStep]
```

Rules, exactly:

- `guard !solid.tiers.isEmpty else { return [] }`.
- `total` is `solid.tiers.reduce(0) { $0 + $1.indices.count }` — every stop of every placed tier.
- **Step 0** is `PlaybackStep(completeTiers: 0, label: "rough · nothing cut", id: 0)`, at both
  granularities.
- **Tier granularity**, for `n` in `1...solid.tiers.count`: `completeTiers: n`, no partial tier, label
  `"\(solid.tiers[n - 1].tier) · tier \(n)/\(solid.tiers.count)"`, `id: n`.
- **Facet granularity**, walking `solid.tiers` in order and, within each, its stops **sorted
  ascending** (D4): for the `j`-th stop of a tier of `m` stops, with `c` stops cut across the whole
  pattern so far, the step is
  - `completeTiers: j == m ? k + 1 : k`, where `k` is that tier's 0-based position,
  - `partialTier: j == m ? nil : tier.tier`,
  - `partialStops: j == m ? [] : Array(sorted.prefix(j))`,
  - `label: "\(tier.tier) · facet \(j)/\(m) · \(c)/\(total)"`,
  - `id`: its position in the list.

  **The last facet step of a tier is therefore identical to that tier's tier-granularity step** apart
  from its label — which is the invariant that makes the two lists two views of one sequence, and it is
  pinned by a test.

**`benchSolid(_:at:)`** — the step's solid, with no solve:

```swift
/// The solid at one playback step, re-expanded from the whole solve's own tiers.
///
/// **Nothing is solved here** (D2). Each tier's depth is already in `SolvedTier.d`, and `planes(of:)`
/// is the identical expansion the solver's own `place` performs, so a prefix's planes are the whole
/// solve's planes for those tiers. Depths do not shift, because a meet may only name an earlier tier —
/// a forward reference is a reported failure, never something the solver resolves.
///
/// Returns `full` unchanged when there is no solution to prefix, which is the no-pattern case.
public func benchSolid(_ full: BenchSolid, at step: PlaybackStep) -> BenchSolid {
  guard let solution = full.solution else { return full }

  // The part-cut tier is the last of the prefix, and its `indices` is the ascending prefix of its own
  // stops. **A derived value, never written back**: the tier table's Indices cell reads
  // `pattern.tiers`, so the file's own stop order still prints (D4).
  var tiers = Array(solution.tiers.prefix(step.completeTiers))
  if let partialTier = step.partialTier,
    var cutting = solution.tiers.first(where: { $0.tier == partialTier })
  {
    cutting.indices = step.partialStops
    tiers.append(cutting)
  }

  // Named `cutPlanes`, not `planes`: a local named `planes` would shadow the kernel's `planes(of:)` and
  // the call below would not compile.
  var cutPlanes: [Plane] = []
  var owner: [Int: (tier: String, index: Int)] = [:]
  for tier in tiers {
    for (stop, plane) in zip(tier.indices, planes(of: tier)) {
      owner[cutPlanes.count] = (tier: tier.tier, index: stop)
      cutPlanes.append(plane)
    }
  }

  // The stop belongs to the last step alone (D9): earlier in the sequence the tier that stopped the
  // solve has not been reached, and marking it stopped would claim a failure playback has not got to.
  let isLast = step.partialTier == nil && step.completeTiers == solution.tiers.count

  return benchSolid(
    over: Solution(
      tiers: tiers,
      planes: cutPlanes,
      planeOwner: owner,
      // Rough-free (ADR-0004, D19). The rough is merged into what is drawn by `benchSolid(over:)`, and
      // only while these planes fail to close (D8).
      polytope: intersectHalfSpaces(cutPlanes)),
    stoppedAtTier: isLast ? full.stoppedAtTier : nil,
    stoppedReason: isLast ? full.stoppedReason : nil)
}
```

**`playbackFrame(_:at:)`** — the solid and its mesh together, so the whole per-step cost sits in one
pure call the precompute's detached task can make:

```swift
/// One step's solid and its mesh. The precompute calls this off the main thread; every value it
/// touches is `Sendable`.
public func playbackFrame(_ full: BenchSolid, at step: PlaybackStep) -> PlaybackFrame {
  let solid = benchSolid(full, at: step)
  return PlaybackFrame(solid: solid, mesh: solidMesh(solid))
}
```

### 3. `CuttingBench/CuttingBench/BenchSolidStore.swift` — playback and the frame cache

**This section describes the end state, and it lands in two goes.** T4 writes everything here except the
precompute: the cache fills lazily, on the main thread, as `setStepIndex` reaches a step it does not have.
T5 adds `progress`, `precomputing`, `precomputeGeneration`, `startPrecompute()` and `accept(...)`, and
`setGranularity` starts the precompute — which is what turns the lazy fill eager and makes the wait one
honest wait rather than a stutter per step (D13). Nothing T4 writes is rewritten by T5.

The store becomes `@Observable @MainActor` and gains playback (D11). **`nonisolated init()` is required**,exactly as `BenchFindingsStore.swift:33` documents it: a `View` struct's own initialisation is not
main-actor isolated even though its `body` is, so `@State private var store = BenchSolidStore()` will not
compile without it. Every stored property has its own default and every one of their types is `Sendable`.

**Imports.** `BenchGeometry` and `Observation` whole, and `import struct FacetKernel.Pattern` scoped, all
three unchanged — the scoped form is there because `FacetKernel` exports an enum named `Observation` that
shadows the module `@Observable` expands against. **No new `FacetKernel` import is needed**, because
`playbackSteps`, `benchSolid(_:at:)` and `playbackFrame` all take and return `BenchGeometry` types.

Stored state:

```swift
  /// The whole stone: one solve per pattern, and playback never re-solves (D2).
  private(set) var full: BenchSolid
  /// What the viewport draws: the current step's solid, or `full` when playback is off.
  private(set) var solid: BenchSolid
  private(set) var mesh: SolidMesh
  /// Bumped on every change to `solid`. Comparing this beats comparing two arrays of vertices.
  private(set) var generation = 0

  /// `nil` is playback off, which is what a document opens at (D6).
  private(set) var granularity: PlaybackGranularity?
  private(set) var steps: [PlaybackStep] = []
  private(set) var stepIndex = 0
  /// How far the precompute has got, or `nil` when none is running (D13).
  private(set) var progress: PlaybackProgress?
  /// A `#if DEBUG` readout only, so the owner can watch the cache fill.
  var cachedFrameCount: Int { frames.count }

  /// Keyed by `PlaybackStep.id`. The last step is served from `fullFrame` and is never stored here.
  private var frames: [Int: PlaybackFrame] = [:]
  private var fullFrame: PlaybackFrame
  /// Double optional on purpose: `nil` is *never built*, `.some(nil)` is *built for no pattern*.
  private var builtPattern: Pattern??
  private var precomputing: Task<Void, Never>?
  /// Bumped per precompute. A frame arriving from a run that has been superseded is discarded.
  private var precomputeGeneration = 0
```

Three methods, and they are the only way the state moves:

- **`setPattern(_ pattern: Pattern?)`** — keeps the shipped memo, `guard builtPattern != .some(pattern)
  else { return }`, then: cancel any precompute and bump `precomputeGeneration`; clear `frames`,
  `granularity`, `steps`, `progress`, and `stepIndex` to `0`; build `full` with
  `benchSolid(for: pattern)` — **no `tierLimit` argument ever again** (D16); set `fullFrame`,
  `solid` and `mesh` from it; bump `generation`; record `builtPattern`.

  **Playback resets to off on every document change** (D6). A step index means nothing across two
  patterns, and a cache built for one is not a stale answer about the other — it is an answer to a
  different question.

- **`setGranularity(_ granularity: PlaybackGranularity?)`** — cancel and bump `precomputeGeneration`;
  clear `frames` and `progress`. Then:
  - `nil`: `granularity = nil`, `steps = []`, `stepIndex = 0`, and show `fullFrame`. **This is also the
    cancel** for a precompute in flight (D13).
  - otherwise: `steps = playbackSteps(full, granularity: granularity)`. If that is empty, leave playback
    off and return — there is no sequence. Otherwise store the granularity, set
    `stepIndex = steps.count - 1` (D7), show `fullFrame`, and start the precompute.

  Either way, bump `generation` when `solid` changed.

- **`setStepIndex(_ index: Int)`** — clamp to `steps.indices` and return early if `steps` is empty.
  Show the last step from `fullFrame`; any other step from `frames[index]`. **If a frame is missing,
  build it synchronously with `playbackFrame(full, at: steps[index])`** — the slider is disabled until
  the bar has gone, so this should not be reachable, and a blocking hull is a better answer than drawing
  the wrong stone. Bump `generation`.

The precompute, in the shape `BenchFindingsStore.swift:63` already ships:

```swift
  private func startPrecompute() {
    // The last step is the whole stone, already in `fullFrame`, so it is not built again — and it is the
    // most expensive hull in the list.
    let steps = self.steps.dropLast()
    let full = self.full
    let generation = precomputeGeneration
    progress = PlaybackProgress(done: 0, total: steps.count)
    precomputing = Task.detached(priority: .userInitiated) { [weak self] in
      for step in steps {
        if Task.isCancelled { return }
        let frame = playbackFrame(full, at: step)
        await self?.accept(frame, at: step.id, total: steps.count, generation: generation)
      }
    }
  }

  /// A frame from a superseded run is discarded rather than racing. `progress` goes to `nil` on the
  /// last frame, which is what puts the slider live.
  private func accept(_ frame: PlaybackFrame, at id: Int, total: Int, generation: Int) {
    guard generation == precomputeGeneration else { return }
    frames[id] = frame
    progress = frames.count == total ? nil : PlaybackProgress(done: frames.count, total: total)
  }
```

**Steps are built in order, `0` first**, so the bar advances in cutting order and the preform is the
first thing cached. The main-actor hop per frame is deliberate: it is what makes the bar move rather
than jump from empty to full.

### 4. `CuttingBench/CuttingBench/BenchRegions.swift` — the scrubber, and the stepper's deletion

**`ScrubberRegion` at `:40`** replaces its `Text("Scrubber")` body. It stays a values-and-closures view
with no state of its own (D12), so its whole contents are checkable by inspection and the store remains
the only owner of playback:

```swift
/// The strip directly under the viewport: the granularity control, the scrubber and the step readout
/// (U5, U6).
///
/// **No state of its own** (D12). The window mutates the store and rebuilds the findings after, so a
/// pattern change and a scrub go down one path.
struct ScrubberRegion: View {
  /// Every position playback can reach. Empty when there is nothing to play.
  let steps: [PlaybackStep]
  let stepIndex: Int
  /// `nil` is playback off (D6).
  let granularity: PlaybackGranularity?
  /// Non-`nil` while the frames are being built, which is when the slider is disabled (D13).
  let progress: PlaybackProgress?
  /// Whether the solve placed any tier at all. `false` disables the whole strip.
  let canPlay: Bool
  let onGranularity: (PlaybackGranularity?) -> Void
  let onStep: (Int) -> Void
```

Its contents, one `HStack` at `height: 32` to keep the layout it already has:

- **A segmented `Picker`** with three tags — `nil`, `.tier`, `.facet` — labelled `"Off"`, `"Tier"` and
  `"Facet"`, bound through `Binding(get:set:)` onto `granularity`/`onGranularity` because there is no
  stored property to bind to. `.pickerStyle(.segmented)`, `.frame(width: 180)`, `.disabled(!canPlay)`.
  **It stays enabled while a precompute runs**, because choosing Off is the cancel (D13).

  **The tags must be spelled as optionals**, or the picker silently never matches its selection: the
  binding's value is `PlaybackGranularity?`, so each row carries
  `.tag(Optional<PlaybackGranularity>.none)`, `.tag(Optional(PlaybackGranularity.tier))` and
  `.tag(Optional(PlaybackGranularity.facet))`. A bare `.tag(PlaybackGranularity.tier)` is a different
  type from the selection's and the row is simply never selected.
- **A `Slider`** over `0...Double(max(steps.count - 1, 1))` with `step: 1`, calling `onStep` with the
  rounded value. `.disabled(granularity == nil || progress != nil || steps.count < 2)`.
- **A step-back and a step-forward `Button`**, `chevron.left` and `chevron.right`, calling
  `onStep(stepIndex - 1)` and `onStep(stepIndex + 1)`, each disabled at its end of the list and under the
  same conditions as the slider. **A slider alone cannot reliably hit one step of seventy-four**, which is
  the whole reason they are there.
- **The step readout**: `Text(steps.indices.contains(stepIndex) ? steps[stepIndex].label : "—")`,
  `.monospaced()`, `.font(.callout)`, `.foregroundStyle(.secondary)`, `.frame(width: 220, alignment:
  .trailing)`. A fixed width, so the strip does not reflow as the numbers change.
- **The progress bar**, shown only while `progress != nil`, in place of the slider:
  `ProgressView(value: Double(progress.done), total: Double(progress.total))` with a
  `Text("building \(progress.done)/\(progress.total)")` beside it. Determinate, because the count is
  known before the work starts and an indeterminate spinner would say nothing about how long the honest
  wait is.

**`StatusStripRegion` at `:231`** loses the stepper (D16). Delete `@Binding var tierLimit: Int?` at
`:239`, the `tierLimitStepper` call at `:262`, and the four `#if DEBUG` members at `:273`–`:290`:
`tierTotal`, `tiersShown`, `tierLimitStepper` and `setTierLimit(_:)`. `documentSummary` at `:293` stays
and gains the cache readout as its own trailing clause, from two new `#if DEBUG` lets:

```swift
  #if DEBUG
    /// How many step frames are cached, and how many the list has. The owner's window onto the
    /// precompute.
    let cachedFrames: Int
    let stepTotal: Int
  #endif
```

appended to `documentSummary`'s return as `" · frames \(cachedFrames)/\(stepTotal)"`.

**`FindingsDetail` at `:313`, `TierTableRegion` at `:52`, `InspectorRegion` at `:130`, `MetricsCard` at
`:165`, `FacetCountCard` at `:209` and `ViewportRegion` at `:8` are not touched.**

### 5. `CuttingBench/CuttingBench/BenchWindow.swift` — the wiring

Delete the `#if DEBUG` `tierLimit` state at `:28`–`:31` and its `.onChange(of: tierLimit)` at
`:108`–`:110`. Every other `@State` stays as it is, including `selectedTier` at `:27`.

`ScrubberRegion()` at `:51` becomes:

```swift
          ScrubberRegion(
            steps: store.steps,
            stepIndex: store.stepIndex,
            granularity: store.granularity,
            progress: store.progress,
            canPlay: !store.full.tiers.isEmpty,
            onGranularity: setGranularity(_:),
            onStep: setStep(_:))
```

The two `StatusStripRegion` call sites at `:61`–`:74` keep their `#if DEBUG` / `#else` shape; the DEBUG
branch drops `tierLimit: $tierLimit` and gains `cachedFrames: store.cachedFrameCount, stepTotal:
store.steps.count`.

`rebuild()` at `:130` splits into three, so the store's mutation and the findings rebuild happen in that
order for a pattern change and a scrub alike:

```swift
  /// A new document: one solve, and playback back to off (D6).
  private func rebuild() {
    store.setPattern(document.pattern)
    afterSolidChanged()
  }

  private func setGranularity(_ granularity: PlaybackGranularity?) {
    store.setGranularity(granularity)
    afterSolidChanged()
  }

  private func setStep(_ index: Int) {
    store.setStepIndex(index)
    afterSolidChanged()
  }

  /// The facet selection goes, the tier selection stays (D18). A plane index means nothing across a
  /// rebuild — the rough's eighteen come and go and the cut planes are re-expanded — so a kept index
  /// would leave the highlight on an unrelated facet and the strip reading the old name. A tier *label*
  /// survives, and keeping it is what lets the owner scrub and watch one tier's meet dots arrive.
  private func afterSolidChanged() {
    selectedPlaneIndex = nil
    selectedFacetLabel = nil
    // Last, because it reads the solid the store has just produced.
    findingsStore.rebuild(pattern: document.pattern, solid: store.solid)
  }
```

The existing comment at `:131`–`:138` moves onto `afterSolidChanged` as above. `.onChange(of:
document.pattern, initial: true) { rebuild() }` at `:107` is unchanged, and it stays the only `onChange`
on the view.

### 6. `CuttingBench/BenchGeometry/Sources/BenchGeometry/TierTable.swift` — one comment

`TierRowState.notReached` at `:9` reads "it sits after the stopped tier, or past the debug tier limit."
The debug tier limit is gone: it becomes "or past the playback step the scrubber is at." **No code in this
file changes** — `tierTableRows` already derives the state from `solid.tiers` and needs no knowledge of
playback (D17).

## Explicitly not doing

- **No auto-play, no timer, no play button** (D15). Nothing in the exploration asks for one, and a stone
  building itself up on a clock is the animated arrival deferred to
  `Chore-Incremental-Half-Space-Clipper`.
- **No incremental clipper.** Each step is a fresh `intersectHalfSpaces`, which is why entering playback
  waits at all. Clipping the previous step's polytope by one plane is that ticket's work, not this
  part's.
- **No wireframe ghost of the finished stone over the intermediate solid.** The exploration assigns the
  ghost and the picking rules to `4-Cutting-Bench-Authoring`; this part builds the display mode it
  reuses, and nothing more.
- **No fourth tier-table row state for a part-cut tier** (D17), and no new column.
- **No editing, no saving, no `state` switch, no tier reordered or altered.** The whole slice's non-goal.
- **No critical-angle marking and no ray probe.** Those are part 5.
- **Nothing persisted.** Granularity and step index are session state, like the opacity and the declared
  facet count before them: a document reopens as its finished self at playback off.
- **No frame cap and no size threshold** (D14). Where a wait is long, the bar says so.

## Tasks

**Every task runs these before it is done, in this order**, in place of the protocol's `Kernel`-only
gates 1 and 2:

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

then a second time **without `-DDEBUG`**, to cover the `#if DEBUG` alternative branches. `-disable-sandbox`
is required, or the `@Observable` macro plugin fails with `sandbox_apply: Operation not permitted` and
floods the output. It compiles no `.metal` and no resources, so it replaces neither the owner's build nor
an owner-stop verification. If the `-I` path does not exist, the `swift build` line above creates it.

| # | Task | Status | Then | Commit | Note |
|---|---|---|---|---|---|
| T1 | Prefactor: split the drawn solid off the solve | completed | continue | commit | |
| T2 | Pure: the step list | completed | continue | — | |
| T3 | Pure: the step's solid, with no re-solve | completed | checkpoint | commit | |
| T4 | The scrubber scrubs; the debug stepper goes | completed | **owner stop** | commit + push | Material alteration: `BenchSolidStore`'s `nonisolated init()` cannot assign a main-actor property, so `full`, `solid`, `mesh` and `fullFrame` take their defaults from one file-private `barePrismFrame` built once, and the init is empty as `BenchFindingsStore`'s is. |
| T5 | One honest wait: the eager precompute and its bar | awaiting owner | **owner stop** | commit + push | |
| T6 | Close out | not started | **owner stop** | commit + push | |

**T1 — Prefactor: split the drawn solid off the solve**

- **Files:** `CuttingBench/BenchGeometry/Sources/BenchGeometry/BenchSolid.swift` (edit)
- Lift `benchSolid(for:tierLimit:)`'s body from `:115` to `:147` into
  `benchSolid(over:stoppedAtTier:stoppedReason:)` exactly as Approach §1 specifies, and leave the caller
  calling it.
- **Done when:**
  - `benchSolid(over:stoppedAtTier:stoppedReason:)` exists with the signature and doc comment in
    Approach §1, and is internal — not `public`.
  - `benchSolid(for:tierLimit:)` keeps its signature, its `public`, its whole doc comment plus the
    `tierLimit` sentence from Approach §1, and its `roughOnly()` early return.
  - The polytope choice still reads `isOpen ? intersectHalfSpaces(planes) : solution.polytope`. **Not an
    unconditional intersect** — that is a hull per document open that no test catches.
  - `swift test --package-path CuttingBench/BenchGeometry --disable-sandbox` passes **with no test file
    edited**, including `testWithNoPatternTheSolidIsTheBarePrism`,
    `testAFinishedPatternAddsNothingToTheKernelsOwnSolid`, `testATierLimitOfZeroIsTheBarePrism` and
    `testTheStopIsTheTierAndTheKernelsOwnSentence`.
  - `git diff --stat` shows one file changed.
- **Do not:** add a test, change any behaviour, touch `roughOnly()`, `roughScaffolding(included:)`,
  `roughPlaneCount`, `BenchSolid`'s stored properties, or any other file. A behaviour-preserving move
  whose diff reaches a second file is not behaviour-preserving.

**T2 — Pure: the step list**

- **Files:** `CuttingBench/BenchGeometry/Sources/BenchGeometry/Playback.swift` (new),
  `CuttingBench/BenchGeometry/Tests/BenchGeometryTests/PlaybackTests.swift` (new)
- Write `PlaybackGranularity`, `PlaybackStep`, `PlaybackProgress`, `PlaybackFrame` and
  `playbackSteps(_:granularity:)` per Approach §2. `benchSolid(_:at:)` and `playbackFrame(_:at:)` are
  T3's; leave them out.
- **Done when:**
  - `swift test --package-path CuttingBench/BenchGeometry --disable-sandbox` passes, including these
    cases in `PlaybackTests.swift`, in a table-style file like `TierTableTests.swift`:
    - **No pattern is no sequence.** `playbackSteps(benchSolid(for: nil), granularity: .tier)` and
      `.facet` are both `[]`.
    - **Step 0 at both granularities** is `completeTiers: 0`, `partialTier: nil`, `partialStops: []`,
      `id: 0`, `label: "rough · nothing cut"`.
    - **Tier granularity counts the placed tiers.** `Pattern-Easy-Octagon` has 6 tiers, so the list is
      7 long; the last step is `completeTiers: 6`, `partialTier: nil`; and step 1's label is
      `"G1 · tier 1/6"`.
    - **Facet granularity counts every stop.** `Pattern-Easy-Octagon` has 37 stops across its 6 tiers,
      so the list is 38 long. `Pattern-Standard-Round-Brilliant` has 73, so 74.
      `Pattern-Rands-Cut-Corner-Rectangle` has 53 across 12 tiers, so 54.
    - **A facet label.** For `Pattern-Easy-Octagon`, step 1 reads `"G1 · facet 1/8 · 1/37"` and step 8
      reads `"G1 · facet 8/8 · 8/37"`.
    - **A tier's last facet step is that tier's tier step.** For every authored pattern, filter the
      facet list to the steps with `partialTier == nil` and `id > 0`; their `completeTiers` sequence
      equals the tier list's, `1...n`.
    - **Ascending stop order, on a constructed tier.** Build a `BenchSolid` by hand with one
      `SolvedTier(tier: "T", part: .pav, angle: 45, wheel: 96, indices: [84, 72, 60, 48, 36, 24, 12, 0],
      d: 1)` and assert the facet steps' `partialStops` grow `[0]`, `[0, 12]`, `[0, 12, 24]` — **ascending,
      not the tier's own order.** This is the case the corpus does not cover.
    - **The constructed tier's own `indices` is unchanged** by the call: still
      `[84, 72, 60, 48, 36, 24, 12, 0]` after `playbackSteps` returns.
- **Do not:** write `benchSolid(_:at:)` or `playbackFrame(_:at:)`, touch `BenchSolid.swift`,
  `TierTable.swift`, or anything in `CuttingBench/CuttingBench/`. Do not sort, filter or reorder anything
  reachable from a `Pattern`.

**T3 — Pure: the step's solid, with no re-solve**

- **Files:** `CuttingBench/BenchGeometry/Sources/BenchGeometry/Playback.swift` (edit),
  `CuttingBench/BenchGeometry/Tests/BenchGeometryTests/PlaybackTests.swift` (edit)
- Add `benchSolid(_:at:)` and `playbackFrame(_:at:)` per Approach §2, calling T1's
  `benchSolid(over:stoppedAtTier:stoppedReason:)`.
- **Done when:**
  - `swift test --package-path CuttingBench/BenchGeometry --disable-sandbox` passes, including these
    cases:
    - **The last step is the whole stone.** For each of the four authored patterns and both
      granularities, `benchSolid(full, at: steps.last!)` matches `full` on
      `polytope.facets.count`, `polytope.vertices.count`, `includesRough`, `cutFacetIndices.count`,
      `roughFacetIndices.count` and `solution!.tiers.count`.
    - **The prefix path agrees with the re-solve oracle** — the test that proves D2. For
      `Pattern-Easy-Octagon` and for every `n` in `0...6`, `benchSolid(full, at: tierSteps[n])` matches
      `benchSolid(for: pattern, tierLimit: n)` on `polytope.facets.count`, `polytope.vertices.count`,
      `includesRough` and `solution!.tiers.map(\.tier)`. Repeat for
      `Pattern-Rands-Cut-Corner-Rectangle` over `0...12`.
    - **Step 0 is the bare prism.** Its `polytope.facets.count` and `polytope.vertices.count` equal
      `benchSolid(for: nil)`'s — 18 and 32 — and every one of its origins is `.rough`.
    - **A part-cut tier does not lose the tiers below it.** For `Pattern-Easy-Octagon` at the facet step
      labelled `"P1 · facet 3/8 · 11/37"`, the step's `solution!.tiers.map(\.tier)` is `["G1", "P1"]`, the
      last of those has `indices == [0, 12, 24]`, and `includesRough` is `true`.
    - **The stop belongs to the last step alone** (D9). Build a broken `Pattern-Novice-Ash-er` in this
      file — load it, find the tier `P2`, and set its `meet` to
      `.fraction(from: .vertex(facets: [FacetRef(tier: "G", index: 12), FacetRef(tier: "G", index: 24),
      FacetRef(tier: "P9", index: 24)]), percent: 24.862, to: .tcp)`, which is a reference to a facet that
      does not exist. `BenchSolidTests` has the same builder as a file-private helper; duplicating twelve
      lines is cheaper than making it shared. The solve then places `["G", "P1"]` and stops at `P2`, so the
      tier list is 3 steps: assert the last step's `stoppedAtTier` is `"P2"` and its `stoppedReason` is
      `"tier P2: there is no facet P9@24"`, and that steps `0` and `1` carry `nil` for both.
    - **`full` is not mutated** by any of the above: after the whole test method,
      `full.solution!.tiers.map(\.indices)` still equals what it did before the first call.
    - **`playbackFrame`** returns a frame whose `solid` matches `benchSolid(full, at: step)` on
      `polytope.facets.count`, and whose `mesh.triangleVertices.count` equals
      `solidMesh(that solid).triangleVertices.count`.
- **Do not:** touch `BenchSolid.swift`, `SolidMesh.swift`, `TierTable.swift`, `MetricsReadout.swift`,
  `Findings.swift` or anything in `CuttingBench/CuttingBench/`. Do not add a cache, a store or a
  granularity default — those are T4's.

**T4 — The scrubber scrubs; the debug stepper goes**

- **Files:** `CuttingBench/CuttingBench/BenchSolidStore.swift` (edit),
  `CuttingBench/CuttingBench/BenchRegions.swift` (edit), `CuttingBench/CuttingBench/BenchWindow.swift`
  (edit), `CuttingBench/BenchGeometry/Sources/BenchGeometry/TierTable.swift` (edit — one doc comment)
- The store per Approach §3 **minus the precompute**: `full`, `granularity`, `steps`, `stepIndex`,
  `frames`, `fullFrame`, `cachedFrameCount`, and the three setters. `setStepIndex` fills `frames`
  **lazily, on the main thread**, by calling `playbackFrame` for a step it does not have. No `progress`,
  no `precomputing`, no `precomputeGeneration` — T5 adds those and turns the fill eager.
- `ScrubberRegion` and `StatusStripRegion` per Approach §4, with `progress: nil` passed for now, the
  progress bar branch present but never taken, and the tier-limit stepper and its four `#if DEBUG`
  members deleted. `BenchWindow` per Approach §5. `TierRowState.notReached`'s comment per Approach §6.
- **Done when:**
  - Both `swiftc -typecheck` runs above are clean, `-DDEBUG` and without.
  - `swift test --package-path CuttingBench/BenchGeometry --disable-sandbox` passes with **no test file
    edited** — nothing in this task changes a `BenchGeometry` behaviour.
  - `grep -rn "tierLimit" CuttingBench/CuttingBench/` finds nothing.
  - `grep -rn "tierLimit" CuttingBench/BenchGeometry/Sources/` finds it only in `BenchSolid.swift`.
  - `grep -rn "rebuildIfNeeded" CuttingBench/` finds nothing: `setPattern(_:)` replaces it, carrying the
    same `builtPattern` memo.
  - The owner's verification below passes.
- **Do not:** touch `Kernel/`, `MetalViewport.swift`, `BenchRenderer.swift`, `Shaders.metal`,
  `IndexRingOverlay.swift`, `MeetPointOverlay.swift`, `BenchFindingsStore.swift`, `PatternDocument.swift`,
  `Playback.swift` or any authored pattern. Do not add a play button, a timer, a fourth `TierRowState`, or
  a persisted preference. Do not change `tierTableRows`, `indexRingLabels`, `metricsReadout` or
  `findingsReadout` — they follow the solid and need no edit; if one appears to need one, that is a stop.
- **Verification handle** — `permanent`:
  - **Where:** the strip directly under the viewport — the granularity picker, the slider, the two
    chevrons and the step readout. Plus two surfaces that already exist: the `#if DEBUG` text at the right
    of the status strip along the window's bottom edge, and the Metrics card in the inspector.
  - **Positive:** open `Design/Patterns/Pattern-Easy-Octagon.json`. Set the picker to **Tier**, then click
    the back chevron four times. The readout reads `"P1 · tier 2/6"`; the viewport shows the prism with
    the girdle walls and the first pavilion tier cut into it, not a floating cone; the tier table's rows
    `P2`, `C1`, `C2` and `T` are secondary; the Metrics card reads
    `"Metrics need every tier: 2 of 6 placed."`; and the debug text ends `rough scaffolding`. Now set the
    picker to **Facet** and click the back chevron twice: the readout reads `"C2 · facet 3/4 · 35/37"`,
    the table `T` is not cut so the rough's own flat cap stands in for it, and one of `C2`'s four facets is
    missing.
  - **Negative:** set the picker to **Off** — the slider and both chevrons go inert, the readout reads
    `"—"`, and the whole stone comes back. Then set it to **Facet** and drag the slider fully to the
    right: the debug text's facet counts and its `rough dropped` clause read **exactly** what **Off**
    reads for this pattern, which is the prefix path and the whole-solve path agreeing. If the last step
    showed a different count from Off, the prefix path is wrong.
  - **Reads:** `playbackSteps` and `benchSolid(_:at:)` in `Playback.swift`, through
    `BenchSolidStore.setStepIndex`. Delete either and the scrubber cannot move.

**T5 — One honest wait: the eager precompute and its bar**

- **Files:** `CuttingBench/CuttingBench/BenchSolidStore.swift` (edit),
  `CuttingBench/CuttingBench/BenchWindow.swift` (edit)
- Add `progress`, `precomputing`, `precomputeGeneration`, `startPrecompute()` and `accept(_:at:total:
  generation:)` per Approach §3. `setGranularity` starts the precompute on entering playback and cancels
  it on leaving; `setPattern` cancels it too. Pass `progress: store.progress` from `BenchWindow` in place
  of the `nil` T4 left there.
- `setStepIndex`'s synchronous fallback stays as the belt-and-braces path: with the slider disabled while
  the bar is up, a missing frame should be unreachable, and a blocking hull is a better answer than the
  wrong stone.
- **Done when:**
  - Both `swiftc -typecheck` runs above are clean, `-DDEBUG` and without.
  - `swift test --package-path Kernel --disable-sandbox` and
    `swift test --package-path CuttingBench/BenchGeometry --disable-sandbox` are green with **no test file
    edited**.
  - `startPrecompute` skips the last step — `self.steps.dropLast()` — so `progress.total` is one less than
    `steps.count`, and the whole stone is served from `fullFrame` rather than built twice.
  - The owner's verification below passes.
- **Do not:** add a Cancel button (the picker is the cancel), a background priority other than
  `.userInitiated`, a frame cap, or a size threshold that changes behaviour for a big pattern. Do not
  make `playbackFrame` or `benchSolid(_:at:)` `async` — they are pure and the detached task calls them as
  they are. Do not touch `Playback.swift`, `BenchRegions.swift`, `BenchFindingsStore.swift`, `Kernel/`, or
  any authored pattern.
- **Verification handle** — `permanent`:
  - **Where:** the progress bar and its `building n/m` text in the scrubber strip, where the slider sits
    when playback is idle. Plus the `frames n/m` clause at the right of the `#if DEBUG` status strip along
    the window's bottom edge.
  - **Positive:** open `Design/Patterns/Pattern-Standard-Round-Brilliant.json` and set the picker to
    **Facet**. A determinate bar replaces the slider, its text climbing from `building 1/73` toward
    `building 72/73`; the bar then disappears, the slider goes live at the end of its travel, and the
    debug strip reads `frames 73/74`. Now drag the slider from one end to the other: the stone rebuilds
    facet by facet with no pause at any position.
  - **Negative:** set the picker to **Off**, then to **Facet** again, and while the bar is still climbing
    set it to **Off** once more. The bar disappears at once, the whole stone comes back, and the debug
    strip's frame clause drops to `frames 0/0` — **it must not keep climbing.** A count still rising after
    Off means the superseded run is writing into the cache, which is the exact failure the generation
    guard exists to stop.
  - **Reads:** `startPrecompute`, `accept(_:at:total:generation:)` and `cachedFrameCount` in
    `BenchSolidStore.swift`, and `playbackFrame` in `Playback.swift`. Delete the precompute and the bar
    never appears.

**T6 — Close out**

- **Delete the temporary handles: none.** Both handles in this part are `permanent` — a scrubber and a
  progress bar are the feature, and the `#if DEBUG` frame count is a diagnostic worth leaving behind a
  dev flag.
- Confirm each item in this plan's **Deferred** section has a ticket in `Design/Tickets/` with
  `Status: untriaged`. The executor files each as it finds it, per the protocol; this is the check, not
  the filing.
- Report the untriaged ticket count in `Design/Tickets/` as one line.
- Update this plan's `Status:` line to say part 4 completed, with the date, and that nothing is archived
  because this is one part of five.
- `commit + push` with the message below.
- **Archive nothing and close no ticket.** This is part 4 of five: the exploration
  `3-Cutting-Bench-Pattern-Display` is still the design source for part 5, and the archive routine in
  `Design/Execution-Protocol.md` §11 runs once, in part 5, over the exploration, every part of this plan
  by name, and every ticket the plan closes.
- **Do not** promote any `untriaged` ticket to `open` — that is the owner's call.
- **Verification handle** — `permanent`: the whole part, end to end, on the pattern the earlier stops did
  not use.
  - **Where:** the scrubber strip and the tier table, with `Design/Patterns/Pattern-Novice-Ash-er.json`
    open.
  - **Positive:** set the picker to **Tier** and walk the back chevron from the end to step 0. This
    pattern's seven tiers are `G`, `P1`, `P2`, `P3`, `C1`, `C2`, `T`, so the readout counts down
    `"C2 · tier 6/7"`, `"C1 · tier 5/7"`, `"P3 · tier 4/7"`, `"P2 · tier 3/7"`, `"P1 · tier 2/7"`,
    `"G · tier 1/7"`; each click removes one tier from the stone, and at step 0 the readout reads
    `"rough · nothing cut"` and the viewport shows the bare eighteen-sided prism with no facet on it. The
    tier table's rows go secondary from the bottom up as you go.
  - **Negative:** at step 0 the inspector's Metrics card reads
    `"Metrics need every tier: 0 of 7 placed."` and **not** a set of proportions — a preform has no
    measurements. Closing the document and reopening it brings the picker back to **Off** with the whole
    stone drawn, so nothing about playback persisted.
  - **Reads:** `playbackSteps` and `benchSolid(_:at:)` in `Playback.swift`.

```
3-cutting-bench-pattern-display-4 T6: close out part 4

- Playback: the scrubber at tier and facet granularity, over a prefix of the
  already-solved half-spaces — no re-solve per step.
- Frames precomputed off the main thread on entering playback, with a
  determinate bar; choosing Off cancels.
- The #if DEBUG tier-limit stepper is retired, as parts 1 and 2 said it would be.
```

## Deferred

Empty at authoring. The executor appends adjacent problems it found and must not fix — and files each as
a ticket in `Design/Tickets/` immediately with `Status: untriaged`, per the protocol.
