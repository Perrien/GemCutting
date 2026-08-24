# Cutting Bench Kernel Changes

Status: **APPROVED 2026-08-24** — in execution

## Context

From the exploration `1-Cutting-Bench-Kernel-Changes`, the first of five slices split from
`Cutting-Bench-App`. **This plan builds everything `FacetKernel` and `design-authoring-format.md` must
gain before the bench app can open, display, author or verify a pattern — and no app code at all.**
There is no window, no renderer and no Xcode project in this plan. Everything is verified by
`swift test` and by running `facetsolve`, which is what makes this the one slice that can be built
with nothing on screen.

Three of the four sibling slices consume what this one produces; none of them is required to land
first. `2-Cutting-Bench-App-Shell` does not depend on this slice at all.

What exists to build on — every anchor below was re-verified on 2026-08-23 against the working tree:

- **The kernel is complete, tested and public.** `Kernel/` is a SwiftPM package with library
  `FacetKernel` (6 sources, 1,422 lines), executable `facetsolve` (351 lines) and 11 test files
  (2,010 lines). `swift test --package-path Kernel --disable-sandbox` is green today.
- **`solve` is `Solver.swift:102`** (`public func solve(_ pattern: Pattern, girdleTargetFraction:
  Double = 0.04) throws -> Solution`); **`validate` is `Validation.swift:61`**
  (`public func validate(_ pattern: Pattern, _ solution: Solution, declaredFacetCount: Int?) ->
  Report`); **`metrics` is `Metrics.swift:67`** (`public func metrics(_ solution: Solution) ->
  Metrics`).
- **The kernel cannot write a pattern file.** `Pattern.swift:81` (`public struct Pattern: Decodable,
  Sendable`), `:54` (`public struct TierSpec: Decodable, Sendable`) and `:21` (`public indirect enum
  Meet: Decodable, Equatable, Sendable`) are decode-only. `FacetRef`, `Part` and `PatternState` are
  already `Codable`. There is no `Encodable` conformance and no encoder anywhere in `Kernel/Sources`.
- **All three decoders are hand-written and read named keys, ignoring unknown ones**:
  `Pattern.swift:187` (`Meet`), `:233` (`TierSpec`), `:283` (the header). **Measured, not assumed:** a
  copy of `Pattern-Easy-Octagon.json` carrying both new fields (`girdleTargetFraction` in the header,
  `instructions` on a tier) runs on today's binary and its `--json` output is **byte-identical** to
  `Kernel/Tests/FacetKernelTests/Fixtures/easy-octagon.json`. This is why no `formatVersion` bump is
  needed.
- **The solve is all-or-nothing.** `Solver.swift:199` (`for spec in pattern.tiers {`) throws out of the
  whole solve, discarding the tiers already placed. The partial state exists at the moment it throws:
  `Solve` accumulates `tiers`, `planes` and `owner` as it goes (`Solver.swift:184`–`:186`).
- **The intermediate solid a scrubber needs exists but is internal**: `Validation.swift:78`
  (`func intermediateSolid(before tier: String, of solution: Solution) -> Polytope`) with
  `Validation.swift:88` (`func planes(of tier: SolvedTier) -> [Plane]`) beside it.
  `Meet.namedTriples` is internal too, at `Validation.swift:284`.
- **`validate` is one entry point over three private halves**: `Validation.swift:101`
  (`private func structuralFindings`), `:172` (`private func geometricFindings`), `:213`
  (`private func closureFinding`).
- **`Metrics` has no `T/W`.** `Metrics.swift:8` lists thirteen fields and the table extent is not among
  them; it is derived in the CLI at `main.swift:152` (`func tableOverWidth(_ solution: Solution,
  width: Double) -> Double`) and printed at `main.swift:335`.
- **Width is fixed to one axis.** `Solver.swift:107` documents *"`width` along the 90-270 degree axis,
  `length` along 0-180"*; `girdleOutlineExtent` (`Solver.swift:116`) returns
  `(width: Double, length: Double)?` and has **exactly two callers**, `Solver.swift:240` (the `girdle`
  meet, which sizes the band from `extent.width`) and `Metrics.swift:197`. No test calls it.
- **The girdle target is a caller's parameter, not a file field**: `Solver.swift:102` defaults it to
  `0.04`; `main.swift:24` records *"Each source diagram measures its own"*.
- **The kernel already accepts any positive wheel**: `Pattern.swift:290` guards `wheel > 0` and the
  per-tier override at `:249` rejects only `<= 0`, so the enumerated gear set is advice, not
  validation. The stale list is in the format document at `design-authoring-format.md:71`.
- **Four patterns are authored** in `Design/Patterns/`: `Pattern-Easy-Octagon.json` (37 facets),
  `Pattern-Novice-Ash-er.json` (49), `Pattern-Rands-Cut-Corner-Rectangle.json` (53),
  `Pattern-Standard-Round-Brilliant.json` (73). Three golden `--json` fixtures sit in
  `Kernel/Tests/FacetKernelTests/Fixtures/`.
- **Measured on the working binary, 2026-08-23** — the numbers several tasks below assert:
  - All four patterns report their **width ≤ their length** today (Rand's 1.464102 against 2.000000,
    the other three square or round), so relabelling by size leaves all four unchanged.
  - **Rand's rotated a quarter turn is a different stone today.** Shifting every index and every
    `FacetRef` by 24 stops gives width 2.000000, length 1.464102, `L/W 0.73205`, girdle 0.080986,
    `P/W 0.453  C/W 0.162  H/W 0.655  T/W 0.594` — against the unrotated 1.464102 / 2.000000 /
    1.36603 / 0.059286 / 0.619 / 0.221 / 0.880 / 0.395.
  - **Easy Octagon's prefixes**, solved as truncated patterns: `G1` alone 0 facets; `G1 P1` 8;
    `G1 P1 P2` 16; `G1 P1 P2 C1` **32**; five tiers 36; all six 37.

## Decisions (2026-08-23)

| # | Decision |
|---|---|
| D1 | **All format-document edits land in one task (T1)**, because `Design/Execution-Protocol.md:90` permits changes to `design-authoring-format.md` only via a task that names it. Six edits: per-tier `instructions`, the header girdle target, the "do not author these" list, the width definition at `:196`, the gear list at `:71`, and one stale citation. |
| D2 | **`instructions` is `String?`, on `TierSpec` only.** Absent means the author wrote nothing; empty means they wrote nothing *there* — the two stay distinguishable, so a future generator can offer text without overwriting prose. The header keeps `notes`; a second header field would only raise the question of which one to write in. Nothing in `Solver`, `Validation` or `Metrics` reads it, and **carrying it is not optional**: a `TierSpec` that drops it deletes the author's prose on save. |
| D3 | **The header field is named `girdleTargetFraction`** — the same name as `solve`'s parameter and the CLI's `--girdle` value. One name for one number across the file, the API and the flag. |
| D4 | **Precedence: an explicit argument always wins, then the file, then `0.04`.** So `solve` takes `girdleTargetFraction: Double? = nil` and resolves `argument ?? pattern.girdleTargetFraction ?? 0.04`. This is **source-compatible with every existing call site** — a `Double` literal converts to `Double?`, and `solve(pattern)` still compiles — which is what keeps the exploration's non-goal (`facetsolve` and the existing test files untouched by the partial-solve work) true. Argument-wins is required, not preferred: `GirdleInvarianceTests` solves the same pattern at 0.02 and 0.08, and a file-wins rule would break it. |
| D5 | **The four authored patterns declare their own diagram-measured target** — Easy Octagon `0.033700`, Novice Ash-er `0.032260`, Rand's `0.040493`, the round brilliant `0.020000`. Owner decision, 2026-08-23. The alternative — leaving them alone — means the bench opens Easy Octagon at 4% instead of its sheet's 3.37%, which is the exact silent disagreement the field exists to prevent. **The golden fixtures do not move**, verified in *Context*: the field carries the value the fixtures were generated at. |
| D6 | **Width is the smaller of the two axis extents and length the larger, so `L/W` ≥ 1.** A tie leaves width on the 90–270 axis, so a square or round stone is bit-for-bit unchanged. **Both** `girdleOutlineExtent` (which sizes the girdle band) and `Metrics` apply the rule, which is what makes width invariant under a quarter turn — the property `5-Cutting-Bench-Angle-Tuning` rests on. |
| D7 | **`T/W` measures the table along whichever axis carried the width**, so `girdleOutlineExtent` reports which axis that was. Without this, D6's quarter-turn invariance holds for width and fails for `T/W`: the rotated Rand's would report 0.594 against the original's 0.395. |
| D8 | **The new metric is named `tableFractionOfWidth`**, the key the three golden fixtures already carry (`easy-octagon.json:29`). Naming it anything else moves three fixtures that are ground truth. |
| D9 | **The partial solve is a sibling function, `solveAsFarAsPossible`, returning `PartialSolution { solution, failure }`.** `solve` keeps its throwing signature and its behaviour. Both run **one** loop: `Solve` gains a non-throwing `run()` and `solve` throws whatever it reports. Two loops would drift. |
| D10 | **`SolverError` gains `var tier: String`.** All ten cases already name a tier, so this is a switch the library owns once instead of every caller writing it to mark the tier that stopped a solve. |
| D11 | **`validate` becomes the composition of three public functions**, called in today's order — structural first with its early return, then per tier in file order, then whole-solid. Order is preserved because `ValidationTests` asserts whole `[Finding]` arrays by equality. |
| D12 | **Encoding is checked, not blind.** `Pattern.init(...)` does no validation, so an app-built pattern could otherwise write a file the kernel refuses to read. The rules decoding enforces move into one internal `checkFormatRules(_:)` that both `init(from:)` and the encoder call, and encoding throws `PatternError`. This is what "one writer beside one reader" (ADR-0003) has to mean to be worth anything. |
| D13 | **`Pattern` and `TierSpec` gain `Equatable`** so a round trip is asserted by value. **Byte order in the written file is asserted nowhere** — `JSONEncoder` emits `90` where the authored files write `90.00`, which `design-authoring-format.md:100` states is the same value. |
| D14 | **The ray probe takes the outside ray and refracts on entry.** Owner decision, 2026-08-23. Physics belongs to the module the game inherits; the app owns the click and the drawing. Both refraction formulas are written out in T9 so nothing is derived at the keyboard. |
| D15 | **The probe takes `[Plane]`, not `Polytope`.** A `Polytope` carries polygons and vertices but no plane equations (`Polytope.swift:4`), and the nearest-forward-hit rule needs the equations. This is a small divergence from `3-Cutting-Bench-Pattern-Display`'s phrasing ("taking a solid"); the app passes `solution.planes`. |
| D16 | **Two glossary terms are written in T1**: *Girdle target* and *Index gear*. Both are used across four explorations and neither is recorded. |
| D17 | **No ADR is written.** The one decision this slice would nominate — the kernel owning the file's reader *and* writer, the app owning the draft — is already recorded as `Design/Decisions/0003-kernel-owns-the-file-app-owns-the-draft.md`, accepted 2026-08-23. Do not write it again. |

## Tickets closed by this plan

- **`Chore-Kernel-Measures-Split-Between-Library-And-Callers`** — both halves. `T/W` moves into
  `Metrics` (T5), and `closureFinding` becomes reachable so `ScaleTests.swift` drops its restatement
  of the closure rule (T8). Archived at close-out.

`Chore-Validation-Rebuilds-The-Solid-Once-Per-Tier` is **not** closed here. This plan owes it three
callable pieces and the documented per-tier independence; the cache itself is app state and belongs to
`4-Cutting-Bench-Authoring`. `Chore-Incremental-Half-Space-Clipper` is untouched.

## Prefactoring

**None required, and this was checked rather than assumed.** The two changes that alter an existing
signature both have countable call sites:

- `girdleOutlineExtent` (`Solver.swift:116`) is called at `Solver.swift:240` and `Metrics.swift:197`
  and nowhere else. No test names it, so T6 can change its return type without a preparatory step.
- `solve`'s parameter becomes optional in T3, which is source-compatible (D4), so no call site moves.

Everything else is additive: new fields, new functions, and three internal symbols becoming public.

## Approach

Seven existing files change and three are new. In dependency order: the format document first
(everything else implements it), then the two new fields, then the encoder that has to round-trip
them, then the two measurement changes, then the two API additions, then the ray probe, which depends
on nothing above it.

### `Design/design-authoring-format.md` (edit — T1)

Six edits, listed verbatim in T1. The document is the format's authority; the code that follows is
written against it, not the reverse.

### `Kernel/Sources/FacetKernel/Pattern.swift` (edit — T2, T3, T4)

```swift
public struct TierSpec: Codable, Equatable, Sendable {
  // …existing fields…
  /// Free text for whoever cuts this tier. Never interpreted, never generated. Absent means the
  /// author wrote nothing; empty means they wrote nothing here.
  public var instructions: String?
}

public struct Pattern: Codable, Equatable, Sendable {
  // …existing fields…
  /// The girdle band's thickness as a fraction of the width, as this design's diagram measures it.
  /// Absent means `defaultGirdleTargetFraction`.
  public var girdleTargetFraction: Double?

  public static let defaultGirdleTargetFraction = 0.04
  /// The target this pattern asks for, with the default filled in.
  public var effectiveGirdleTargetFraction: Double {
    girdleTargetFraction ?? Self.defaultGirdleTargetFraction
  }
}

/// Every rule decoding enforces, checked against a pattern already in memory, so a file the kernel
/// writes is a file the kernel can read.
func checkFormatRules(_ pattern: Pattern) throws

/// The one writer. Runs `checkFormatRules` first.
public func encoded(_ pattern: Pattern) throws -> Data
```

`Meet`, `TierSpec` and `Pattern` each gain a hand-written `encode(to:)` mirroring their `init(from:)`,
using `encodeIfPresent` for `wheel`, `instructions` and `girdleTargetFraction` so an absent field
stays absent.

### `Kernel/Sources/FacetKernel/Solver.swift` (edit — T3, T6, T7)

```swift
public func solve(_ pattern: Pattern, girdleTargetFraction: Double? = nil) throws -> Solution

/// The tiers a solve placed before it stopped, and the failure that stopped it.
public struct PartialSolution: Sendable {
  public var solution: Solution
  /// `nil` when every tier placed, in which case this is what `solve` would have returned.
  public var failure: SolverError?
}
public func solveAsFarAsPossible(
  _ pattern: Pattern,
  girdleTargetFraction: Double? = nil
) -> PartialSolution

extension SolverError { public var tier: String { … } }

/// The girdle outline's extents along the two fixed axes, labelled by size: the longer is the length.
func girdleOutlineExtent(
  _ planes: [Plane],
  tolerance: Double = 1e-7
) -> (width: Double, length: Double, widthIsAlongY: Bool)?
```

### `Kernel/Sources/FacetKernel/Metrics.swift` (edit — T5, T6)

`Metrics` gains `public var tableFractionOfWidth: Double`, measured along the axis the width was
measured on. `outlineExtent` applies D6's labelling to its knife-edge fallback as well.

### `Kernel/Sources/FacetKernel/Validation.swift` (edit — T8)

```swift
/// Everything readable from the pattern alone. Needs no solid and no solve.
public func structuralFindings(_ pattern: Pattern) -> [Finding]
/// The named-point check for one tier. Depends only on the tiers before it — see the doc comment.
public func namedPointFindings(inTier tier: String, of pattern: Pattern, _ solution: Solution) -> [Finding]
/// Closure and the facet count: whole-solid, cheap, never cacheable.
public func solidFindings(_ solution: Solution, declaredFacetCount: Int?) -> [Finding]
```

`validate` becomes their composition. `intermediateSolid(before:of:)`, `planes(of:)` and
`Meet.namedTriples` become `public`, with no behaviour change.

### `Kernel/Sources/FacetKernel/Ray.swift` (new — T9)

```swift
public struct RaySegment: Sendable {
  public var from: (x: Double, y: Double, z: Double)
  public var to: (x: Double, y: Double, z: Double)
  /// The plane this segment ends on, as an index into the planes the trace was given.
  public var plane: Int
  /// The angle between the ray and that plane's normal at `to`, in degrees.
  public var incidenceDegrees: Double
}

public enum RayEnding: String, Sendable {
  /// Fell below the critical angle and left the stone.
  case left
  /// Still bouncing when the cap was reached. The path is truncated, not finished.
  case cappedAtBounceLimit
  /// The entry point is not on the solid, or the direction points away from it.
  case noEntry
}

public struct RayTrace: Sendable {
  public var criticalAngleDegrees: Double
  public var entryPlane: Int?
  public var entryIncidenceDegrees: Double?
  public var segments: [RaySegment]
  public var ending: RayEnding
  /// Where the ray went after leaving, or `nil` unless `ending == .left`.
  public var exitDirection: (x: Double, y: Double, z: Double)?
}

public func criticalAngleDegrees(ri: Double) -> Double
public func traceRay(
  in planes: [Plane],
  ri: Double,
  from entry: (x: Double, y: Double, z: Double),
  direction: (x: Double, y: Double, z: Double),
  bounceLimit: Int = 32
) -> RayTrace
```

### `Kernel/Sources/facetsolve/main.swift` (edit — T3, T5)

`--girdle` becomes an override (`Double?`), the header line prints the **resolved** target, and
`tableOverWidth` is deleted in favour of the metric. No new flags.

## Explicitly not doing

- **No app code, no window, no renderer, no Xcode project.** Those are the four sibling slices.
- **No rough stone and no draft type in the kernel.** A rough-capped solid always closes, so feeding
  rough into the solve would silently defeat the closure check the tool exists to run; and a
  half-authored tier's rules are UI policy, not geometry. Both belong to the app (ADR-0003).
- **No volume code and no rough-retention metric.** What the game will need is a primitive — the
  volume of a polytope — not this tool's metric. When it needs it, polytope volume goes in
  `FacetKernel` and anything about rough stays out.
- **No `formatVersion` bump.** Both new fields are optional and additive, and *Context* records the
  measurement proving a file carrying them decodes on today's kernel.
- **No per-tier validation cache.** T8 owes `4-Cutting-Bench-Authoring` three callable pieces and the
  documented independence property. The cache is app state.
- **No `Observation` split.** I8 splits findings only; `validate` remains the way to get observations.
- **No generated `instructions`.** The field is a stored string and never a derived value, and absent
  means the author wrote nothing — never "generate one".
- **No new meet form, no fractional index positions, no cheaters, no GemCad interop, no printing, no
  game mechanics, nothing for iPad.** Carried forward unchanged.
- **No Fresnel splitting, no dispersion, no whole-stone light metric.** One ray, one wavelength, one
  path (D14).
- **No third-party dependencies.** Swift and the standard library only.
- **No edit to any golden fixture, any authored pattern's geometry, or any published tolerance.** T3
  adds one header field to four files and nothing else in them changes.

## Tasks

| # | Task | Status | Then | Commit | Note |
|---|---|---|---|---|---|
| T1 | Format document and glossary | completed | **owner stop** | commit | |
| T2 | Per-tier `instructions` | completed | continue | — | |
| T3 | The girdle target as a header field | completed | **owner stop** | commit | |
| T4 | The encoder: `Pattern` becomes `Codable` | awaiting owner | checkpoint | commit | material alteration |
| T5 | `T/W` moves into `Metrics` | awaiting owner | continue | — | |
| T6 | Width and length assigned by size | awaiting owner | **owner stop** | commit + push | |
| T7 | The non-throwing partial solve | not started | checkpoint | commit | |
| T8 | Validation splits three ways | not started | checkpoint | commit | |
| T9 | The ray probe | not started | **owner stop** | commit | |
| T10 | Close out | not started | **owner stop** | commit + push | |

---

**T1 — Format document and glossary**

The guardrail is that `design-authoring-format.md` changes only via a task that names it. This is that
task, and it is the only one in this plan that touches the document. It touches no Swift source, so
gates 1–3 do not apply (`Execution-Protocol.md` §2).

- **Files:** `Design/design-authoring-format.md` (edit), `Design/Glossary.md` (edit)
- **Done when:**
  - **Edit 1 — the gear list.** `:71` reads `96, 120, 64 or 80` today. It now names all eight gears —
    **32, 64, 72, 80, 84, 88, 96 and 120** — says 96 and 120 are the common ones, and records that
    **84 is what makes 7-fold possible and 72 is what makes 9-fold possible**, neither being a divisor
    of 96 or 120. It also records that **every one of the eight divides by 4**, so a quarter turn is
    always a whole number of stops.
  - **Edit 2 — the header gains `girdleTargetFraction`.** A row in the header table reading
    **optional**, *the girdle band's thickness as a fraction of the width, as the design's diagram
    measures it; absent means 0.04*. A short paragraph under the table says why it is a file field and
    not a preference: the value changes the stone, so a pattern reopened at a different target does not
    reproduce its own verified geometry. Real patterns differ — Rand's measures 4.05% of width and
    `SUPERPEAR 96` asks for 1.6–3.2%. The JSON example near `:52` gains the field.
  - **Edit 3 — the "do not author these" list at `:86` stops listing the girdle target.** It reads
    `girdle thickness target` today, which now contradicts edit 2. The corrected text distinguishes
    the two: the **target** is authored and optional, the **achieved thickness** is computed and stays
    on the do-not-author list.
  - **Edit 4 — the tier table gains `instructions`.** A row reading **optional**, *free text for
    whoever cuts this tier; never interpreted by the engine and never generated*. One sentence
    afterwards records that it is addressed to someone about to cut, where the header's `notes` is
    addressed to someone checking a claim.
  - **Edit 5 — the width definition at `:196`–`:200` is corrected.** It states today that width is
    *"twice the **minimum** girdle-plane offset computed from the solved outline"*. Nothing implements
    that, and the published diamond proportions contradict it: `RoundBrilliantTests.swift:28` pins
    `(pavilion: 0.466, crown: 0.218, height: 0.704, table: 0.516)` at `tolerance = 0.001` against a
    width of 2.03918, giving `P/W` 0.4663, where the minimum-offset rule would give width 2.0 and
    `P/W` 0.4754 — **nine times the tolerance out**. The replacement: **width and length are the
    girdle outline's extents along the two fixed axes, labelled by size — the longer is the length, so
    `L/W` is always ≥ 1.** It records that a faceter measures a rectangle along its length, so the rule
    is not maximum breadth in any direction; that Rand's 4.05% of width still reads correctly under it
    while the maximum-offset reading gives 2.96%; and, as a known limitation, that a design whose own
    axes are not 0–180 and 90–270 is measured against axes that are not its own.
  - **Edit 6 — one stale citation.** The paragraph near `:43` justifies JSON by citing
    ``Cutting-Bench` **I16**`, an archived exploration. It now cites **ADR-0003**, which is where that
    decision is recorded. This is the only incidental edit in this task, and it is here because the
    document may not be edited outside it.
  - **`Design/Glossary.md` gains exactly two terms**, in the existing shape (term, one or two
    sentences, `_Avoid_:` line), domain only and free of implementation detail:
    - **Girdle target** — the girdle band's intended thickness, as a fraction of the stone's width,
      taken from the design's own diagram where it gives one. `_Avoid_:` girdle thickness, which is
      the achieved measurement rather than the intent.
    - **Index gear** — the toothed wheel that divides a full turn into a fixed number of stops: 32,
      64, 72, 80, 84, 88, 96 or 120. A pattern names one as its default and any tier may be cut on
      another. `_Avoid_:` index on its own, since a tier's index stop is a position on the gear rather
      than the gear itself.
  - Neither document loses a line that is still true. The corpus table near `:401`, the enforced-rules
    list near `:437` and every meet-form section other than §3's width paragraph are byte-identical.
- **Do not:** change any rule the code enforces. Do not touch the dead `../../.scratch/…` links —
  they are wrong but they are not this plan's business. Do not add a `formatVersion` bump. Do not
  write any Swift in this task. Do not add a third glossary term on your own initiative.
- **Verification handle** — `permanent`:
  - **Where:** `Design/design-authoring-format.md` and `Design/Glossary.md`.
  - **Positive:** searching the format document for `64 or 80` and for `*minimum*` returns zero
    matches; searching for `girdleTargetFraction` and `instructions` returns both, each in a table row
    marked optional. The glossary carries **Girdle target** and **Index gear**.
  - **Negative:** searching for `minimum girdle-plane offset` returns zero matches **and** the
    document still says the girdle target is 3–5% of width — the correction replaces one definition,
    not the whole section.
  - **Reads:** nothing. These documents are this task's product.

```
cutting-bench-kernel T1: format document gains two fields and a corrected width

- Per-tier instructions and a header girdleTargetFraction, both optional
- Width and length are the axis extents labelled by size, so L/W >= 1
- Eight index gears named; Girdle target and Index gear enter the glossary
```

---

**T2 — Per-tier `instructions`**

- **Files:** `Kernel/Sources/FacetKernel/Pattern.swift` (edit),
  `Kernel/Tests/FacetKernelTests/PatternDecodingTests.swift` (edit)
- **Done when:**
  - `TierSpec` carries `public var instructions: String?`, declared last, and its memberwise
    initialiser takes `instructions: String? = nil` **last**, so every existing call site compiles
    unchanged.
  - `TierSpec.CodingKeys` gains `instructions` and `init(from:)` reads it with
    `decodeIfPresent`.
  - A tier with no `instructions` key decodes to `nil`; a tier with `"instructions": ""` decodes to
    `""`. **Both assertions in one test** — absent and empty are different states and a test that
    checks only one of them passes on an implementation that conflates them.
  - A tier with `"instructions": "Cut to the girdle, then check the meets."` decodes to exactly that
    string, newlines and all — a second case with an embedded `\n` asserts nothing mangles it.
  - All four authored patterns still decode, with every tier's `instructions` `nil` — none of them
    carries the field yet.
  - `grep -rn instructions Kernel/Sources/FacetKernel/Solver.swift
    Kernel/Sources/FacetKernel/Validation.swift Kernel/Sources/FacetKernel/Metrics.swift` returns
    nothing. The field is carried and never read.
- **Do not:** add a header-level equivalent. Do not derive or default the text from the meet. Do not
  make it non-optional with `""` as the default — that erases the distinction the format now
  documents. Do not write the encoder here; T4 owns it.

---

**T3 — The girdle target as a header field**

- **Files:** `Kernel/Sources/FacetKernel/Pattern.swift` (edit),
  `Kernel/Sources/FacetKernel/Solver.swift` (edit), `Kernel/Sources/facetsolve/main.swift` (edit),
  `Design/Patterns/Pattern-Easy-Octagon.json` (edit),
  `Design/Patterns/Pattern-Novice-Ash-er.json` (edit),
  `Design/Patterns/Pattern-Rands-Cut-Corner-Rectangle.json` (edit),
  `Design/Patterns/Pattern-Standard-Round-Brilliant.json` (edit),
  `Kernel/Tests/FacetKernelTests/PatternDecodingTests.swift` (edit),
  `Kernel/Tests/FacetKernelTests/SolverTests.swift` (edit),
  `Kernel/Tests/FacetKernelTests/CLITests.swift` (edit),
  `Kernel/Tests/FacetKernelTests/RegressionTests.swift` (edit)
- **Done when:**
  - `Pattern` carries `public var girdleTargetFraction: Double?`, decoded with `decodeIfPresent`,
    plus `public static let defaultGirdleTargetFraction = 0.04` and
    `public var effectiveGirdleTargetFraction: Double`.
  - A negative or zero declared target is rejected at decode with a `PatternError` case that names the
    value. Add the case rather than reusing an unrelated one, and give it a `description` in the same
    voice as its neighbours. A target of `0.04` decodes; `-0.01` and `0` do not.
  - `solve`'s signature is `solve(_ pattern: Pattern, girdleTargetFraction: Double? = nil) throws ->
    Solution`, resolving `girdleTargetFraction ?? pattern.effectiveGirdleTargetFraction` **once**, at
    the top, and passing the resolved `Double` into `Solve` as today.
  - Each of the four authored patterns gains exactly one header line — `girdleTargetFraction` set to
    `0.033700`, `0.032260`, `0.040493` and `0.020000` respectively, placed after `ri`. **Nothing else
    in those four files changes**: no tier, no angle, no index, no `notes`.
  - `facetsolve`'s `--girdle` is an override: `Options.girdle` is `Double?` and is `nil` unless the
    flag is given. The header line prints the **resolved** target, so
    `facetsolve Design/Patterns/Pattern-Easy-Octagon.json` prints `girdle target 3.370% of width`.
  - **Three call paths are pinned by test, in one test:** `solve(easyOctagon)` gives `C1 d =
    0.719219`; `solve(easyOctagon, girdleTargetFraction: 0.04)` gives `0.728582`; a copy of the
    pattern with the field removed and no argument gives `0.728582`. Each to `1e-6`.
  - `CLITests.testGirdleFlagMovesTheCrown` is updated to the same three paths through the CLI — no
    flag, `--girdle 0.0337`, `--girdle 0.04` — and its comment records that the flag overrides the
    file rather than supplying a missing value.
  - `RegressionTests` stops passing `--girdle`: each fixture's command is now
    `facetsolve Design/Patterns/<name>.json --json`, and **all three fixtures still match byte for
    byte**. `Fixture.regenerate` is updated to the command actually used.
  - `RegressionTests.testTheGirdleFractionIsPartOfTheFixture` keeps its purpose by re-pointing at
    `--girdle 0.04`: overriding the file's target still produces output that differs from the fixture.
  - Every other existing test passes untouched, because each one passes its fraction explicitly.
- **Do not:** make the file's value win over an explicit argument (D4). Do not write the default into
  a file — absent must stay absent, or every file the app touches silently gains a field its author
  did not write. Do not touch the fixtures in `Kernel/Tests/FacetKernelTests/Fixtures/`; if one stops
  matching, that is a stop (§8), not an edit. Do not change any tier of any authored pattern.
- **Verification handle** — `permanent`:
  - **Where:** `swift run --package-path Kernel --disable-sandbox facetsolve
    Design/Patterns/Pattern-Easy-Octagon.json`
  - **Positive:** the header line reads `girdle target 3.370% of width`, the `C1` line reads
    `d = 0.719219`, and the metrics block reads `girdle 0.067400 (3.370% of width)` — the pattern now
    reproduces its own diagram with no flag.
  - **Negative:** the same command with `--girdle 0.04` prints `4.000% of width` and `C1
    d = 0.728582`. The flag still wins, which is what `GirdleInvarianceTests` depends on.
  - **Reads:** `solve` and the resolution rule, via `facetsolve`.

```
cutting-bench-kernel T2-T3: two new format fields

- Per-tier instructions, carried and never interpreted
- Header girdleTargetFraction; an explicit argument still overrides it
- The four authored patterns now declare their diagram-measured target
```

---

**T4 — The encoder: `Pattern` becomes `Codable`**

The kernel becomes the one writer beside the one reader (ADR-0003). `Meet` decodes through a
hand-written initialiser, so its encoder is hand-written too, which is why the round-trip test is not
optional.

- **Files:** `Kernel/Sources/FacetKernel/Pattern.swift` (edit),
  `Kernel/Tests/FacetKernelTests/PatternEncodingTests.swift` (new)
- **Done when:**
  - `Meet`, `TierSpec` and `Pattern` are `Codable`, each with a hand-written `encode(to:)` mirroring
    its `init(from:)` and writing the same key names. `Pattern` and `TierSpec` are `Equatable`.
  - `wheel`, `instructions` and `girdleTargetFraction` are written with `encodeIfPresent`, so a tier
    that inherits the pattern's wheel is **not** written with an explicit one.
  - `checkFormatRules(_ pattern: Pattern) throws` is internal and holds the whole-pattern rules:
    `formatVersion == 1`, `wheel > 0`, non-empty tier labels, per-tier `wheel > 0`, no duplicate tier
    labels, every index in `0..<` that tier's wheel, a `vertex` naming exactly three facets, a
    `fraction`'s endpoints being `vertex` or `tcp`, `percent` in `0...100`, and a non-negative girdle
    target. `Pattern.init(from:)` calls it, and **the `formatVersion` guard stays where it is today —
    inline, before the tiers are decoded** — so a file that is both `formatVersion: 2` and otherwise
    malformed still reports `unsupportedFormatVersion`, asserted by test. The JSON-only check (a
    non-integer index) stays in `TierSpec.init(from:)`.
  - `public func encoded(_ pattern: Pattern) throws -> Data` runs `checkFormatRules` first, then
    encodes with `.prettyPrinted` and `.withoutEscapingSlashes`.
  - **Round trip, all four authored patterns:** decode from `Design/Patterns/`, `encoded(…)`, decode
    the result, and assert the two `Pattern` values are equal. Not a byte comparison — `90.00` and
    `90` are the same value (D13).
  - **Round trip, all five meet forms**, including a `fraction` whose `from` is a `vertex` and whose
    `to` is a `tcp`, and a tier carrying `instructions` and an overriding `wheel`.
  - **Absent stays absent, and empty stays empty:** a pattern with no `girdleTargetFraction` encodes
    to JSON with no such key; a tier with `instructions: ""` encodes to a key holding `""`; a tier
    with `instructions: nil` encodes to no key at all. Asserted against the emitted JSON, parsed with
    `JSONSerialization`, not against the `Pattern`.
  - **Encoding refuses what decoding refuses**, each with the error naming the tier: two tiers
    labelled `P1`; an empty tier label; index `96` on a 96 wheel; a `vertex` naming two facets; a
    `fraction` at `percent` 101; `formatVersion` 2; `wheel` 0; a per-tier `wheel` of `-1`; a girdle
    target of `-0.01`. Each built in memory through `Pattern.init`, which performs no checks — that is
    exactly why this matters.
  - A pattern the app could plausibly build — one tier, `state: .inProgress`, `instructions` set —
    encodes, is written to a temporary file, and is read back by `facetsolve` without error.
- **Do not:** make `Pattern.init` throwing; the existing test files construct patterns through it. Do
  not add a decode helper — `JSONDecoder().decode` is already the one reader. Do not assert key order
  or byte equality anywhere. Do not use `.sortedKeys`, which would alphabetise a tier into
  `angle, indices, meet, part, tier` and make an authored file unreadable to the human who opens it.
- **Verification handle** — `permanent`:
  - **Where:** `swift test --package-path Kernel --disable-sandbox --filter
    PatternEncodingTests/testDump` prints the re-encoded `Pattern-Easy-Octagon.json`.
  - **Positive:** the printed JSON has the header fields, `girdleTargetFraction` at `0.0337`, and six
    tiers whose meets carry `kind` discriminators. Feeding it to `facetsolve` gives 37 facets and
    `no findings`.
  - **Negative:** the printed JSON contains no `"wheel"` key inside any tier — all six inherit 96, and
    an encoder that wrote the resolved value instead of the declared one would show six of them.
  - **Reads:** `encoded` and the three `encode(to:)` implementations.
- **Checkpoint:** run the gates.

**Note — material alteration (2026-08-24).** This task's *Do not* forbids `.sortedKeys` on the grounds
that it would alphabetise a tier into `angle, indices, meet, part, tier`. That reasoning assumed
`JSONEncoder` writes keys in the order `encode(to:)` writes them; it does not. A keyed container
serialises through an unordered dictionary and Foundation seeds string hashing per process, so **the same
pattern encoded in two processes produced two different files** — measured, three runs of
`PatternEncodingTests/testDump` gave three different header orders. The choice was therefore not
authored-order against alphabetical but alphabetical against no order at all, and every save would have
been a diff.

**Owner decision, 2026-08-24: use `.sortedKeys`; the UI can set display order.** So `encoded` writes
`[.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]`, this task's *Do not* on `.sortedKeys` is
reversed, and the file now reads `designer, formatVersion, girdleTargetFraction, name, notes, ri, state,
tiers, wheel`. One test was added beyond the *Done when* list to hold the ruling in place —
`testTheSaveIsDeterministic` asserts two encodings of one pattern are the same bytes and that the header
keys ascend. That is a byte comparison, which this task's *Do not* also forbids; it forbids it against an
authored file, where `90.00` against `90` would fail on a non-difference, and this compares one encoding
against another.

```
cutting-bench-kernel T4: the kernel writes pattern files

- Meet, TierSpec and Pattern become Codable with hand-written encoders
- encoded() runs the decoder's own rules first, so a written file reads back
- All four authored patterns round-trip to an equal value (ADR-0003)
```

---

**T5 — `T/W` moves into `Metrics`**

Half of `Chore-Kernel-Measures-Split-Between-Library-And-Callers`. A pure move: no number changes, and
the three golden fixtures are the proof.

- **Files:** `Kernel/Sources/FacetKernel/Metrics.swift` (edit),
  `Kernel/Sources/facetsolve/main.swift` (edit),
  `Kernel/Tests/FacetKernelTests/MetricsTests.swift` (edit),
  `Kernel/Tests/FacetKernelTests/RoundBrilliantTests.swift` (edit)
- **Done when:**
  - `Metrics` carries `public var tableFractionOfWidth: Double`, computed by the body of
    `main.swift:152`'s `tableOverWidth` moved into `Metrics.swift` — the widest horizontal
    upward-facing facet's extent along the width axis, over the width, and `0` when there is no table
    facet. Its doc comment records why it belongs here now: the app needs it too, so leaving it in the
    CLI would put one definition in three places.
  - `main.swift` no longer defines `tableOverWidth`; `JSONMetrics.init` takes only a `Metrics`, and
    the `T/W` row and the `tableFractionOfWidth` JSON key both read the metric.
  - **The three golden fixtures still match byte for byte** — `RegressionTests` passes untouched. The
    JSON key keeps its name (D8) and its nine-place rounding.
  - `MetricsTests` asserts `tableFractionOfWidth` for all three sheet patterns to `1e-6`:
    **0.630939**, **0.503152**, **0.395415** — the values the fixtures carry.
  - `MetricsTests.testAKnifeEdgeGirdleStillMeasures` asserts the knife-edge pattern reports
    `tableFractionOfWidth == 0`: it has no table facet, and a stone with no table simply has none.
  - `RoundBrilliantTests` keeps its published `T/W` assertion of 0.516 ± 0.001 and gains **one line**:
    the metric and the number `facetsolve --json` reports are equal to `1e-9`. That single assertion is
    what makes "one definition" a checked claim rather than a hope.
- **Do not:** rename the JSON key. Do not change the rounding in `place`. Do not alter the published
  0.516 or its tolerance. Do not change how the table facet is identified — this task moves code, it
  does not improve it.

---

**T6 — Width and length assigned by size**

The one task in this plan that changes a number the kernel already reports. It is also what makes
width invariant under a quarter turn, which `5-Cutting-Bench-Angle-Tuning` depends on entirely.

- **Files:** `Kernel/Sources/FacetKernel/Solver.swift` (edit),
  `Kernel/Sources/FacetKernel/Metrics.swift` (edit),
  `Kernel/Tests/FacetKernelTests/MetricsTests.swift` (edit),
  `Kernel/Tests/FacetKernelTests/QuarterTurnTests.swift` (new)
- **Done when:**
  - `girdleOutlineExtent` returns `(width: Double, length: Double, widthIsAlongY: Bool)?`. It computes
    both axis extents as today, then labels them: the **smaller is the width**, the larger the length.
    A tie leaves the width on the 90–270 (`y`) axis, so a square or round outline is unchanged. Its
    doc comment replaces the fixed-axis sentence at `Solver.swift:107` and records that the `girdle`
    meet sizes the band from the width, so this rule is what makes the band invariant under a quarter
    turn.
  - `Metrics.outlineExtent` applies the same labelling to its knife-edge fallback, which measures from
    the polytope's vertices.
  - `Metrics.tableFractionOfWidth` measures the table's extent along **whichever axis carried the
    width** (D7) — `y` when `widthIsAlongY`, otherwise `x`.
  - A unit test on `girdleOutlineExtent` with four hand-built vertical planes — `±x` at offset 0.5 and
    `±y` at offset 1.0 — returns width **1.0**, length **2.0**, `widthIsAlongY == false`. This is the
    case the old rule got backwards, and it needs no pattern.
  - **`QuarterTurnTests` is the end-to-end check, on a real authored pattern.** It loads
    `Pattern-Rands-Cut-Corner-Rectangle.json`, builds a rotated copy in memory by adding 24 stops
    (`wheel / 4`, and every tier of this pattern is on 96) to every tier's index and to every
    `FacetRef` inside every meet — including the nested ones inside a `fraction`, which needs a
    recursive rewrite — and asserts that the rotated pattern's metrics equal the original's to `1e-9`
    for: `facetCount`, `facetsPerTier`, `widthNormalised`, `lengthNormalised`, `lengthOverWidth`,
    `girdleThicknessNormalised`, `girdleFractionOfWidth`, `pavilionDepthFractionOfWidth`,
    `crownHeightFractionOfWidth`, `totalDepthFractionOfWidth`, `tableFractionOfWidth`,
    `rotationalOrder` and `mirrorAxes`. A quarter turn changes nothing measurable.
  - The same test hard-codes two anchors so a regression that moved both stones together is still
    caught: the rotated pattern reports `widthNormalised` **1.464102** and `lengthOverWidth`
    **1.36603**, each to `1e-5`. It asserts explicitly that the rotated `lengthOverWidth` is **not**
    0.73205, with a comment recording that 0.73205 is what the shipped code gave before this task, so
    the test fails on a revert rather than passing vacuously.
  - `MetricsTests.testWidthAndLengthAlongTheFixedAxes` keeps its three expected rows unchanged —
    2.000000 / 2.000000, 2.000000 / 2.000000 and 1.464102 / 2.000000 — and its comment is corrected:
    the rule is now smaller-is-width, and Rand's already satisfied it.
  - **All four authored patterns are unchanged.** The three golden fixtures match byte for byte,
    `RoundBrilliantTests` passes with `widthNormalised` 2.03918 and all four published ratios, and
    `GirdleInvarianceTests` passes untouched.
- **Do not:** measure the maximum breadth in any direction. For the cut-corner example that reads
  2.07308 corner-to-corner, which would report a rectangle as longer than it is; a faceter measures a
  rectangle along its length. Do not attempt to find a design's own mirror axes and measure against
  those — `Metrics.mirrorAxes` exists and the limitation is recorded in T1's edit 5 rather than
  solved. Do not adjust any published tolerance to make the round brilliant pass; if it fails, that is
  a stop (§8).
- **Verification handle** — `permanent`:
  - **Where:** `swift test --package-path Kernel --disable-sandbox --filter QuarterTurnTests`
  - **Positive:** green, and `MetricsTests/testDump` still prints the Rand's row as
    `facets 53  rot 2  L/W 1.36603  girdle 4.05%`.
  - **Negative:** in `QuarterTurnTests`, change the shift from 24 stops to 12 — an eighth turn — and
    re-run. It fails on `widthNormalised`, because an eighth turn genuinely is a different stone under
    axis-aligned measurement. A test that passed at 12 stops would be measuring nothing. Restore the
    24 afterwards.
  - **Reads:** `girdleOutlineExtent` and `Metrics.outlineExtent`.

```
cutting-bench-kernel T5-T6: T/W is a metric, and width is the smaller extent

- tableFractionOfWidth moves from facetsolve into Metrics, closing half a ticket
- Width and length are the axis extents labelled by size, so L/W >= 1
- Rand's rotated a quarter turn now measures identically; all four patterns unchanged
```

---

**T7 — The non-throwing partial solve**

A half-solving pattern is the normal state of authoring, not an edge case, and today it is a cliff.

- **Files:** `Kernel/Sources/FacetKernel/Solver.swift` (edit),
  `Kernel/Tests/FacetKernelTests/PartialSolveTests.swift` (new)
- **Done when:**
  - `PartialSolution` and `solveAsFarAsPossible` exist as in *Approach*, and `SolverError` has
    `public var tier: String` covering all ten cases.
  - **One loop serves both entry points.** `Solve` gains a non-throwing `run()` that stops at the
    first tier it cannot place and reports `(Solution, SolverError?)`; `solve` throws the error when
    there is one and is otherwise unchanged; `solveAsFarAsPossible` returns both. The `Solution` a
    partial solve returns carries the tiers placed, their planes, their `planeOwner` entries, and the
    polytope of exactly those planes.
  - `solve`'s signature, behaviour and every one of its existing tests are untouched.
  - **The stopping case is pinned with measured numbers.** Easy Octagon with `C2`'s meet pointing at a
    tier that does not exist — `FacetRef(tier: "C3", index: 0)` — gives: `solve` throws
    `unknownFacet(tier: "C2", …)`; `solveAsFarAsPossible` returns four solved tiers (`G1`, `P1`, `P2`,
    `C1`), **32 planes**, a polytope with **32 facets**, `failure?.tier == "C2"`, and the same
    `failure` case the throw carried.
  - **The partial result equals the truncated pattern's full result.** Solving the same pattern cut
    down to its first four tiers gives the same plane count, the same facet count and the same `d` for
    each of the four tiers, to `1e-12`. This is the assertion that catches a partial solve that leaves
    stale state behind.
  - **A pattern that stops on its first tier is handled**: a one-tier pattern whose only tier has a
    `girdle` meet returns zero solved tiers, an empty plane list, a polytope with no facets, and
    `failure?.tier` naming that tier — the girdle outline is not bounded when no vertical plane has
    been placed.
  - **A clean pattern comes back with `failure == nil`** and a solution equal to `try solve(…)`'s: same
    plane count, same facet count, same per-tier `d`.
  - A comment records the measured prefix shapes, because they are what the display slice will draw:
    Easy Octagon's girdle tier alone yields **0 facets** — eight mutually parallel vertical planes, no
    triple meeting at a point — and girdle plus first pavilion tier yields **8**, all of them the
    pavilion's, because an open-topped solid leaves each girdle plane only two vertices and
    `Polytope.swift:67` (`guard onPlane.count >= 3 else { continue }`) drops it. **A pattern's own
    planes render a floating pavilion cone with no girdle and no top until something caps the solid.**
- **Do not:** make `solve` non-throwing, or route it through a second loop. Do not cap the solid with
  anything — no rough, no bounding box, no synthetic table. The kernel learns nothing about rough
  (ADR-0003), and a capped solid always closes, which would defeat the closure check. Do not validate
  inside the partial solve; validation is a separate call.
- **Checkpoint:** run the gates.

```
cutting-bench-kernel T7: a solve that stops reports what it placed

- solveAsFarAsPossible returns the tiers placed plus the failure that stopped it
- One loop behind both entry points; solve's throwing signature is unchanged
```

---

**T8 — Validation splits three ways**

A decomposition, not an optimisation: the same work, callable in three pieces, so the authoring slice
can cache the middle one. This closes the second half of
`Chore-Kernel-Measures-Split-Between-Library-And-Callers`.

- **Files:** `Kernel/Sources/FacetKernel/Validation.swift` (edit),
  `Kernel/Tests/FacetKernelTests/ValidationTests.swift` (edit),
  `Kernel/Tests/FacetKernelTests/ScaleTests.swift` (edit)
- **Done when:**
  - The three public functions of *Approach* exist, and `validate` is their composition: structural
    first, returning early with no observations when it finds anything, then `namedPointFindings` for
    each tier **in file order**, then `solidFindings`, then observations. Every existing
    `ValidationTests` array-equality assertion passes untouched.
  - `namedPointFindings` needs only the tier label, the pattern and the solution. It builds the
    placed-plane map from the tiers **before** the named one, calls `intermediateSolid(before:of:)`,
    and returns `[]` for a label the pattern does not carry.
  - Its doc comment records the independence property this slice owes `4-Cutting-Bench-Authoring`,
    with the reason: `intermediateSolid` walks tiers and breaks at the named one, so **tier *k*'s
    result depends only on the tiers before *k*** — editing tier *j* invalidates *j* onward and leaves
    everything before it untouched, and appending a tier validates exactly one tier.
  - **That property is tested, not just asserted in prose.** Solve Easy Octagon, record
    `namedPointFindings` for each of its six tiers; then remove the last tier, solve again, and record
    them for the remaining five. The five results are identical. A later tier cannot change an earlier
    tier's answer.
  - `structuralFindings` is called in a test **with no solution at all** and returns the expected
    finding — that is what "needs no solid" means, and it is the half the authoring UI runs on every
    keystroke.
  - `namedPointFindings(inTier: "C2", …)` on the mutated Easy Octagon of
    `testVertexNotOnIntermediateSolid` returns exactly `[.vertexNotOnIntermediateSolid(tier: "C2",
    named: …)]`, and the same call for `"P2"` returns `[]`.
  - `solidFindings` on the pavilion-less Easy Octagon returns `[.doesNotClose(tier: "C1")]`, and on a
    clean solve with `declaredFacetCount: 36` returns `[.facetCountMismatch(solved: 37, declared:
    36)]`.
  - `intermediateSolid(before:of:)`, `planes(of:)` and `Meet.namedTriples` are `public`, with no
    behaviour change. `Meet.isSize` and `Meet.isTCP` stay internal.
  - **`ScaleTests` drops its own closure rule.** Its `openEdge` and `edges` helpers are deleted and the
    closure assertion becomes `XCTAssertEqual(solidFindings(solution, declaredFacetCount: nil), [],
    "the solid closes")`. Its comment is corrected: the reason it did not call `validate` was the
    per-tier pass, and the whole-solid piece is now callable on its own. The five-second timing
    assertion still measures `solve` alone and its ceiling is unchanged.
- **Do not:** change any `Finding` case, or the order findings come back in. Do not make observations
  public or split them — `validate` stays the way to get them. Do not build the cache; it is app state
  and belongs to `4-Cutting-Bench-Authoring`. Do not make `namedPointFindings` take an index instead
  of a label; the label is what `intermediateSolid` already speaks.

```
cutting-bench-kernel T8: validation splits into three callable pieces

- Structural, per-tier and whole-solid, with validate composing them in order
- Tier k's per-tier result proven independent of the tiers after it, by test
- ScaleTests drops its restatement of the closure rule; closes the measures ticket
```

---

**T9 — The ray probe**

Geometry and physics in the module the game inherits; picking and pixels in the app. "Light
performance" is a game concern before it is an authoring one.

- **Files:** `Kernel/Sources/FacetKernel/Ray.swift` (new),
  `Kernel/Tests/FacetKernelTests/RayTests.swift` (new)
- **Done when:**
  - The types and two functions of *Approach* exist. `criticalAngleDegrees(ri:)` returns
    `asin(1 / ri)` in degrees, and **90 for `ri <= 1`**, documented: nothing is trapped in a medium no
    denser than air, so there is no angle beyond which a ray reflects.
  - **The trace, step by step.** All vectors unit; `n` is a plane's outward normal, so the solid is
    `n · p <= d`:
    1. **Entry.** Find the planes the entry point lies on within `1e-7` whose `n · direction < 0`.
       None means `ending = .noEntry`, no segments. Otherwise take the first; record `entryPlane` and
       `entryIncidenceDegrees = acos(-(direction · n))` in degrees.
    2. **Refract inward**, with `c = -(direction · n)` and `t = direction + c * n`:
       `inside = t / ri - n * sqrt(1 - (1 - c * c) / (ri * ri))`. At normal incidence this is
       `-n`, and the result is a unit vector for any `ri >= 1`.
    3. **Next surface.** Over every plane with `n · dir > 1e-12`, take the smallest
       `s = (d - n · p) / (n · dir)` with `s > 1e-9`. Valid in one pass because the solid is convex by
       construction, being an intersection of half-spaces — so a bounce costs O(planes) and the whole
       probe is trivial beside a solve.
    4. **At that surface**, with `c = dir · n` (positive, the ray is leaving):
       `incidence = acos(c)` in degrees. Append the segment. If `incidence > criticalAngleDegrees`,
       **reflect** — `dir - 2 * c * n` — count a bounce and go to 3. Otherwise the ray leaves:
       `ending = .left` and
       `exitDirection = ri * (dir - c * n) + n * sqrt(1 - ri * ri * (1 - c * c))`.
    5. **Cap.** After `bounceLimit` bounces, `ending = .cappedAtBounceLimit` — the path is truncated
       rather than finished, which the case name has to say.
  - `criticalAngleDegrees(ri: 1.54)` is **40.49266** to `1e-5`, and `criticalAngleDegrees(ri: 2.16)`
    is **27.57847** to `1e-5`.
  - **A vertical ray's incidence is the facet's own mast angle**, which is the cleanest possible check
    on step 4. Trace the round brilliant (solved at its own 0.02) from the centroid of the `t` facet's
    polygon, offset off the axis, in direction `(0, 0, -1)`: the first segment's
    `incidenceDegrees` is 43 or 45 — the two pavilion tiers — to `1e-9`, it exceeds the critical
    angle, and the ray does not leave on the first surface. Take the entry point from
    `solution.planeOwner` and the polytope's polygons rather than hard-coding coordinates.
  - **Snell holds on entry**, traced from the centroid of the round brilliant's `cb@3` facet in
    direction `(0, 0, -1)`: `entryIncidenceDegrees` is **47.0** to `1e-9` (the facet's mast angle),
    and the angle between the first segment's direction and that facet's normal is **28.35316** to
    `1e-4`. Also assert the law itself rather than the arithmetic: `sin(47°) == 1.54 * sin(inside)` to
    `1e-12`.
  - **A shallow pavilion leaks, and the trace says so.** Build this pattern in memory — wheel 96,
    `ri` 1.54, `state: .inProgress`, `G` (`gdl`, 90.00, `0 12 24 36 48 60 72 84`, `size`), `P` (`pav`,
    **35.00**, same stops, `tcp`), `T` (`table`, 0.00, `[0]`, `girdle`) — which solves clean at the
    0.04 default to 17 facets, `d` of 1.000000 / 0.573576 / 0.080000, and a table plane at `z = 0.08`.
    Trace from `(0.2, 0.05, 0.08)` in direction `(0, 0, -1)`: entry incidence 0 (no bend at normal
    incidence, asserted by the first segment's direction being `(0, 0, -1)` to `1e-12`), one segment,
    first incidence **35.0** to `1e-9`, which is below the critical 40.49 — so `ending == .left` and
    `exitDirection` is non-`nil`.
  - **The cap is reachable and deterministic**: the round-brilliant table trace with
    `bounceLimit: 1` ends `.cappedAtBounceLimit` with one segment, and `exitDirection` is `nil`.
  - **`.noEntry` covers both ways of missing**: a point well outside the solid, and a point on the
    table with direction `(0, 0, +1)` — pointing away from the stone. Neither produces a segment.
  - Every returned `RaySegment` has `to` on the solid within `1e-7` (`n · to == d` for its plane) and
    each `incidenceDegrees` in `0..<90`.
- **Do not:** split a ray at any surface. Fresnel splitting doubles the rays at every bounce and
  produces an unreadable picture, and the format carries one `ri`, so there is no dispersion to model.
  Do not build a `Polytope` inside the trace, or use one as input (D15). Do not compute a
  whole-stone brilliance or light-return figure. Do not draw anything, and do not decide where the
  probe's readout appears — that belongs to `3-Cutting-Bench-Pattern-Display`.
- **Verification handle** — `permanent`:
  - **Where:** `swift test --package-path Kernel --disable-sandbox --filter RayTests/testDump` prints
    the traced path for the round brilliant — the critical angle, then one line per bounce with the
    plane's owning tier and index, the incidence, and whether it reflected.
  - **Positive:** every printed incidence before the last is greater than `40.49`, and the tiers named
    are pavilion and crown tiers of that stone.
  - **Negative:** the same dump for the 35° shallow pattern prints a single bounce at `35.00` and
    `left` — one number below the critical angle is all it takes, and a probe that reported total
    internal reflection there would be reporting a stone that leaks as a stone that does not.
  - **Reads:** `traceRay` in `Kernel/Sources/FacetKernel/Ray.swift`.

```
cutting-bench-kernel T9: single-ray probe with critical-angle readout

- Refracts in, reflects while above the critical angle, refracts out where it leaks
- Per-bounce incidence against asin(1/ri); one path, one wavelength, capped bounces
```

---

**T10 — Close out**

- **Files:** `Design/Plans/Cutting-Bench-Kernel-Changes.md` (edit),
  `Design/Explorations/1-Cutting-Bench-Kernel-Changes.md` (move),
  `Design/Tickets/Chore-Kernel-Measures-Split-Between-Library-And-Callers.md` (move),
  `Design/Archived/ArchivedCatalog.md` (edit)
- **Done when:**
  - No temporary verification handles to delete — every handle in this plan is marked `permanent`.
  - Every item in this plan's **Deferred** section has a ticket in `Design/Tickets/` with
    `Status: untriaged`, named per `CLAUDE.md`. The untriaged ticket count in `Design/Tickets/` is
    reported as one line.
  - Archive per `Execution-Protocol.md` §11: this plan, the exploration
    `1-Cutting-Bench-Kernel-Changes`, and the ticket
    `Chore-Kernel-Measures-Split-Between-Library-And-Callers`.
  - **The banner judgment for the exploration is answered explicitly, and the answer is yes.** Its
    *Grounding* section states four things this plan makes false: the kernel cannot write a pattern
    file; `validate` is one entry point over three private halves; `Metrics` has no `T/W`; and width is
    fixed to the 90–270 axis. Banner it naming those four claims and telling the reader to trust the
    code, and catalog it as `superseded by Cutting-Bench-Kernel-Changes` with the contradiction as the
    why-clause.
  - The plan and the ticket are catalogued `executed`, and the ticket's line names this plan as
    provenance.
- **Do not:** archive `Cutting-Bench-App` or the sibling explorations `2-` through `5-` — four plans
  still come out of them. Do not archive `Chore-Validation-Rebuilds-The-Solid-Once-Per-Tier`, which
  `4-Cutting-Bench-Authoring` closes, or `Chore-Incremental-Half-Space-Clipper`, which nothing here
  touches. Do not archive anything in `Design/` root, `Patterns/` or `Decisions/`. Do not write an ADR
  (D17).

```
cutting-bench-kernel T10: close out

- Archive Cutting-Bench-Kernel-Changes, its exploration and the measures ticket
- The exploration banners the four Grounding claims this plan inverted
```

## Deferred

Empty at authoring. The executor appends adjacent problems it found and must not fix — and files each
as a ticket in `Design/Tickets/` immediately with `Status: untriaged`, per the protocol.
