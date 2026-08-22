# Facet Kernel

Status: **APPROVED 2026-08-21**

## Context

This is the first of two plans from the exploration `Cutting-Bench`. **This plan builds only the
kernel — the depth solver, polytope construction, pattern I/O and validation, plus a diagnostic CLI
to drive them.** The Mac GUI (the 3D viewport, facet-clicking, the tier table, playback) is the
second plan and nothing here anticipates it.

The kernel exists for two reasons the exploration names. It is the **authoring workhorse**, so
producing a trustworthy pattern becomes *cut it and export it* rather than *write the meet specs by
hand and hope they close*. And it is the **de-risking exercise** for the two pieces the game's
critical path depends on and which do not exist anywhere yet.

What exists to build on:

- **Plane derivation from angle + index works and is proven.** `Design/Prototypes/render-proof/`
  `Sources/GemSpike/Geometry.swift:35` (`var planes: [Plane] {`) turns a tier into a half-space list;
  the wheel convention is one line, `:42` (`let theta = 2 * Float.pi * Float(idx) / Float(wheel)`).
  About seventeen lines. This is the only code carried over.
- **Depth solving does not exist.** `Geometry.swift:118` (`/// rather than solved from meetpoints —
  meetpoint solving is the geometry`) — the spike set depths from standard proportions by eye.
- **Vertices, facet polygons and meetpoints do not exist.** `Geometry.swift:3` (`// A cut gem as an
  intersection of half-spaces. No mesh, no BVH, no convex-hull`). Verified by search: nothing in
  `Sources/` constructs a vertex. Half-space → polytope is entirely new work, and it is what any meet
  check needs.
- **Three patterns are already authored and verified**, in `Design/Patterns/`:
  `Pattern-Easy-Octagon.json` (37 facets), `Pattern-Novice-Ash-er.json` (49),
  `Pattern-Rands-Cut-Corner-Rectangle.json` (53). Each declares its source sheet's facet count in
  `notes`, which is external ground truth. Between them they exercise all five meet forms.
- **The format is fully specified** in `design-authoring-format.md`, including the JSON schema. That
  document is the format's authority; every rule this plan enforces is restated here so the executor
  never opens it.
- **No production source tree exists.** This package is the project's first real code.

## Decisions (2026-08-21)

| # | Decision |
|---|---|
| D1 | **`Kernel/` is a SwiftPM package at the repo root**, library target `FacetKernel`, test target `FacetKernelTests`, plus one executable target `facetsolve`. No UI, no rendering, no Metal — the game later depends on this same package, which is why it carries tests from the first commit (ADR-0001). |
| D2 | **All kernel geometry is `Double`, never `Float`.** The spike is entirely `Float` (30 occurrences in `Geometry.swift`, zero `Double`), which is fine for a renderer and wrong here: detecting a singular plane triple needs a determinant threshold near `1e-10`, and `Float` epsilon is about `1e-7`. Reference solves land at `1e-16` residuals in `Double`. |
| D3 | **`facetsolve` exists so a headless kernel can be verified.** A library has nothing the owner can look at, and every owner stop in this plan needs a handle. It loads a pattern, solves, and prints. It is a permanent diagnostic, not the GUI, and it is what regenerates fixtures. |
| D4 | **A tier's depth is solved in dependency order, not by simulating the cut.** Three named planes fix a point by algebra alone, so no solid is needed to compute a depth. The whole pattern re-solves at once, tiers ordered by dependency. Never a per-tier sequential solve and never an incremental update — editing an early tier changes every later depth, so there is nothing to update incrementally. |
| D5 | **A tier's depth is `d = max over that tier's facets of (facet normal · target point)`.** A tier shares one depth, so the solid requires `n · p ≤ d` for every facet of the tier with equality on whichever one reaches the point. Nothing in the file says which facet arrives; it is computed. Needs no special case for a `0.00` table, and a tie means the point sits on an edge between two facets of that tier — `d` is still unique. |
| D6 | **Validation resolves named vertices against the *intermediate* solid**, built tier by tier, never the finished one. A point can exist at one tier and be gone by the next: in `Easy Octagon`, P1's axial point forms at 1.0951 half-widths and P2 cuts it away. Checking against the finished polytope both passes patterns by luck and rejects correct ones. |
| D7 | **`tcp` pins a depth on exactly one tier per side — the first that sets a depth.** On any later tier it is satisfied at *every* depth and constrains nothing, so a second `tcp` on the same side is an error, not a constraint. A 90° girdle tier does not count as depth-setting. |
| D8 | **A `fraction` interpolates the point, then applies D5.** `P = from + percent/100 × (to − from)`, then `d = max(n · P)`. Not the plane offset: interpolating offsets requires picking one facet and the answer would depend on which. A `tcp` endpoint means the axial point **on the same side as the tier's `part`**, since once both crown and pavilion are cut there are two. |
| D9 | **The solver normalises so the `size` tier's plane offset is exactly 1.0.** `size` is a normalisation, not a constraint — it is the unit, which is why it works on a rectangle where "diameter" does not. No millimetres appear anywhere in the kernel. |
| D10 | **Width and length are the girdle outline's extent along fixed axes: width along the 90°–270° axis, length along 0°–180°** (index 24–72 and 0–48 on a 96 wheel; index 30–90 and 0–60 on a 120 wheel). Whether that axis crosses a girdle flat or a girdle corner is a property of the design, not something to decide: it hits flats on `Easy Octagon`, `Novice Ash-er` and `Rand's`, and a corner on the round brilliant, whose 16 girdle facets are chords of an intended circle. One rule reproduces every external figure we have — `Rand's` 1.464102 minor axis, and the brilliant's published `L/W = 1.000` and 2% girdle. Rejected: twice the minimum girdle-plane offset, which gets `Rand's` right and misses all four of the brilliant's published ratios by ~2%. |
| D11 | **Nothing may assume a flat girdle**, in the solver, the validation or the derived metrics. About 99% of patterns have one; it is not a rule, and non-flat girdles are expressible in these same meet forms. |
| D11a | **Crown height is measured from the girdle top, pavilion depth from the girdle bottom, and the girdle band is its own share of total height.** Settled by the round brilliant's source twice over: its stated identity `H/W = (P+C)/W + 0.02`, and its profile diagram bracketing `C` from the girdle top. This is a real fork — measuring crown height from the girdle mid-plane instead changes it by half the girdle thickness, which is 2.2 points of `C/W` on that stone. |
| D19a | **This is an orientation convention, not a geometric invariant.** A pattern authored rotated 90° would report its length as its width. Every design in the corpus is drawn with its long axis on 0–48, so the convention holds; a pattern that breaks it is mis-authored, not a solver problem. |
| D12 | **Tier order is data and is never normalised.** Where a later tier's meet only exists once an earlier one is cut, reversing them yields a pattern that cannot be cut. A forward reference is an error to report, never something to fix by reordering. |
| D13 | **Symmetry, facet count, L/W, girdle thickness and difficulty are computed, never read from the file.** Where a sheet declares one it lives in `notes` as free text and is a cross-check only. `Easy Octagon`'s sheet declares 4-fold where the solve gives 4-fold mirror — declared metadata is a claim, not a fact. |
| D14 | **Index positions are whole numbers.** No cheaters: a cheater is a cutting-time correction, and a published pattern sits on exact stops. |
| D15 | **No third-party dependencies.** Swift and the standard library only. `Foundation` for `JSONDecoder`; no `simd` requirement in the kernel, since `Double` geometry is three scalars. |
| D16 | **The scale check uses a generated fixture, not `Kiev Triangle`.** No `Kiev Triangle` pattern is authored and the exploration puts its meets outside the bar. A programmatically generated 139-plane pattern tests the solver's scaling, which is the only thing that check was for. |
| D17 | **Validation returns two channels: `findings` (errors) and `observations` (informational).** A tier can legitimately be cut away entirely by a later one — used to establish an intermediate point that a later tier then cuts to. The sheet never counted that tier's facets and neither does the solve, so the counts agree and it is not an error. But it is also exactly what a mis-authored depth looks like, so it is reported, and kept out of the exit code. `duplicatePlanes` moves here too: the exploration calls it a warning, not a silent fix. |
| D18 | **Symmetry is computed from the facets that survive on the solid, not from the authored index sets.** A tier cut away entirely contributes no facets, so counting its indices would report the symmetry of a shape the stone does not have. |
| D19 | **Girdle thickness is a rigid translation of the crown, and the kernel asserts it.** No meet can cross the girdle band — a crown facet and a pavilion facet never share a vertex, because the band sits between them — so every crown meet chains back to the girdle-top corner or to another crown facet. Changing the girdle target therefore slides the crown as one body and cannot alter facet count, culet depth or table size. Verified across 2%–8%: all three invariant, only total depth moves. This makes facet count safe as a fixture, and the invariance is worth a test because a violation means the girdle value has leaked into a pavilion depth. |

## Tickets closed by this plan

- `Chore-Complete-Execution-Protocol` — asks for the four `⟦FILL IN⟧` declaration blocks in
  `Design/Execution-Protocol.md`. Settled by T1, which fills all four from the exploration's S7–S10
  with the toolchain re-verified on this machine. Archived at close-out.

## Prefactoring

**None needed, because this plan creates a new package and edits no existing code.** The one piece
carried over from `Design/Prototypes/render-proof/` is copied, not moved — that directory is read-only
(see *Explicitly not doing*), so there is no shared code to make safe first and nothing whose behaviour
could regress.

## Approach

A single SwiftPM package. Pure value types and free functions; no classes, no framework, no I/O outside
the CLI target. Built in dependency order: planes, then the polytope, then the solver that needs both,
then validation that needs all three.

### 1. New: `Kernel/Package.swift`

`swift-tools-version:6.0`, `platforms: [.macOS(.v15)]`. Three targets: library `FacetKernel`, test
`FacetKernelTests`, executable `facetsolve` depending on `FacetKernel`. No `swiftLanguageMode(.v5)`
escape hatch — unlike the spike (`Design/Prototypes/render-proof/Package.swift:13`), this is production
code and runs in Swift 6 language mode.

### 2. New: `Kernel/Sources/FacetKernel/Geometry/Plane.swift` (pure)

```swift
public struct Plane: Equatable, Sendable {
    public var n: (x: Double, y: Double, z: Double)   // unit normal
    public var d: Double                              // offset: the solid is n · p <= d
}
public enum Part: String, Codable, Sendable { case pav, gdl, crown, table }
public func planeNormal(angleDegrees: Double, index: Int, wheel: Int, part: Part) -> (x: Double, y: Double, z: Double)
```

`planeNormal` is the carried-over derivation, retyped to `Double` and given a four-way `Part` in place
of the spike's `crown: Bool`:

`theta = 2 * .pi * Double(index) / Double(wheel)`, `a = angleDegrees * .pi / 180`, and the normal is
`(sin(a) * cos(theta), sin(a) * sin(theta), zsign * cos(a))` where `zsign` is `+1` for `.crown` and
`.table`, `-1` for `.pav` and `.gdl`.

### 3. New: `Kernel/Sources/FacetKernel/Pattern.swift` (pure, `Codable`)

The on-disk schema, decoded directly. `Meet` is an enum with associated values, decoded on the `kind`
discriminator:

```swift
public struct Pattern: Codable, Sendable {
    public var formatVersion: Int
    public var name: String
    public var state: PatternState        // .inProgress = "in progress", .finished = "finished"
    public var wheel: Int
    public var ri: Double
    public var designer: String
    public var notes: String
    public var tiers: [TierSpec]
}
public struct TierSpec: Codable, Sendable {
    public var tier: String
    public var part: Part
    public var angle: Double
    public var indices: [Int]
    public var wheel: Int?               // absent = inherit Pattern.wheel
    public var meet: Meet
}
public struct FacetRef: Codable, Equatable, Sendable { public var tier: String; public var index: Int }
public indirect enum Meet: Codable, Sendable {
    case size
    case tcp
    case girdle
    case vertex(facets: [FacetRef])                        // exactly 3
    case fraction(from: Meet, percent: Double, to: Meet)    // endpoints: .vertex or .tcp only
}
```

Decoding rejects, with a typed error naming the tier: a `kind` outside the five; a `vertex` whose
`facets` count is not 3; a `fraction` endpoint that is not `.vertex` or `.tcp`; a `percent` outside
0…100; a non-integer or out-of-range index; duplicate tier labels; a `formatVersion` other than 1.

### 4. New: `Kernel/Sources/FacetKernel/Geometry/Polytope.swift` (pure)

Half-space intersection → vertices and per-facet polygons. This is A10 and it is entirely new.

```swift
public struct Polytope: Sendable {
    public var vertices: [(x: Double, y: Double, z: Double)]
    public var facets: [Int: [Int]]      // plane index -> its polygon's vertex indices, wound CCW about the normal
}
public func intersectHalfSpaces(_ planes: [Plane], tolerance: Double = 1e-7) -> Polytope
public func triplePoint(_ a: Plane, _ b: Plane, _ c: Plane, singularBelow: Double = 1e-10) -> (x: Double, y: Double, z: Double)?
```

`triplePoint` solves the 3×3 by Cramer's rule and returns `nil` when `|det|` is below
`singularBelow` — three planes only meet at a point when they are independent, and faceting produces
the degenerate case readily (three girdle facets are all vertical and pin nothing; determinant
`~2.5e-17`). `intersectHalfSpaces` takes every triple, keeps points satisfying `n · p ≤ d + tolerance`
for all planes, deduplicates, and assigns each to every plane it lies on. A plane with fewer than three
distinct vertices is not a facet of the solid and is omitted from `facets`.

### 5. New: `Kernel/Sources/FacetKernel/Solver.swift` (pure)

```swift
public struct SolvedTier: Sendable { public var tier: String; public var part: Part; public var angle: Double; public var wheel: Int; public var indices: [Int]; public var d: Double }
public struct Solution: Sendable { public var tiers: [SolvedTier]; public var planes: [Plane]; public var planeOwner: [Int: (tier: String, index: Int)]; public var polytope: Polytope }
public func solve(_ pattern: Pattern) throws -> Solution
```

Walks tiers in file order, resolving each depth from already-placed planes only (D4), then normalises
so the `size` tier's offset is 1.0 (D9) and builds the polytope once at the end. Per form:

- `.size` → `d = 1.0`.
- `.tcp` → the free datum. `d = sin(angle) × 1.0`, i.e. the tier reaches the girdle outline along its
  first index's azimuth. Errors if this side already has an axial point (D7).
- `.girdle` → `d = sin(angle) + normal.z × girdleThickness`, where `girdleThickness` is
  `girdleTargetFraction × width` with `width` per D10 — the girdle outline's extent along the 90°–270°
  axis — and `girdleTargetFraction` defaults to `0.04`. Exposed as a parameter on `solve`, not
  hardcoded at the call site. **No circularity:** the girdle outline is fixed by the 90° tiers and the
  `size` normalisation, so `width` is known before any girdle thickness is needed.
- `.vertex(facets:)` → `triplePoint` of the three, then D5's max rule.
- `.fraction(from:percent:to:)` → resolve both endpoints to points, interpolate, then D5 (D8).

Axial point per side is tracked as the smallest-magnitude `d / cos(angle)` seen so far on that side,
skipping any tier whose `|cos(angle)|` is below `1e-9` — a 90° tier never reaches the axis, and letting
it register a phantom axial point is a live trap.

### 6. New: `Kernel/Sources/FacetKernel/Validation.swift` (pure)

```swift
public enum Finding: Sendable, Equatable {
    case forwardReference(tier: String, named: String)
    case namesOwnFacet(tier: String)
    case unknownFacet(tier: String, named: FacetRef)
    case singularTriple(tier: String)
    case secondTCPOnSide(tier: String, part: Part)
    case notExactlyOneSizeRow(count: Int)
    case vertexNotOnIntermediateSolid(tier: String, named: [FacetRef])
    case doesNotClose(tier: String?)
    case facetCountMismatch(solved: Int, declared: Int)
}
public enum Observation: Sendable, Equatable {
    case tierContributesNoFacets(tier: String)
    case duplicatePlanes(tier: String, indices: [Int])
}
public struct Report: Sendable { public var findings: [Finding]; public var observations: [Observation] }
public func validate(_ pattern: Pattern, _ solution: Solution, declaredFacetCount: Int?) -> Report
```

`vertexNotOnIntermediateSolid` is the one that needs the incremental build (D6): for each tier with a
vertex or fraction meet, construct the polytope of the tiers *before* it and confirm the named point is
a vertex of that solid within `1e-7`.

**`findings` are errors; `observations` are not** (D17). A tier that contributes no facets to the
finished solid is legitimate — a tier cut only to establish an intermediate point another tier then cuts
to, whose own facets a later tier removes. The declared facet count still agrees, because the sheet
never counted them either. It is reported because it is also what a mis-authored depth looks like, and
in this plan only the owner reading the output can tell which.

`validate` reports; it never throws and never mutates. A pattern whose `state` is `.inProgress` may
carry findings — only `.finished` must come back with `findings` empty, which the CLI enforces and the
library does not. `observations` never gate anything.

### 7. New: `Kernel/Sources/FacetKernel/Metrics.swift` (pure)

```swift
public struct Metrics: Sendable {
    public var facetCount: Int
    public var facetsPerTier: [String: Int]
    public var rotationalOrder: Int
    public var mirrorAxes: [Int]
    public var widthNormalised: Double          // girdle extent along 90-270 deg (D10)
    public var lengthNormalised: Double         // girdle extent along 0-180 deg (D10)
    public var lengthOverWidth: Double
    public var totalDepthFractionOfWidth: Double
    public var pavilionDepthFractionOfWidth: Double     // girdle bottom to culet (D11a)
    public var crownHeightFractionOfWidth: Double       // girdle top to table (D11a)
    public var girdleThicknessNormalised: Double
    public var girdleFractionOfWidth: Double
    public var culetIsPoint: Bool
}
public func metrics(_ solution: Solution) -> Metrics
```

All derived (D13). **Symmetry is computed from the facets that survive on the solid, not from the
authored index sets** (D18) — a tier cut away entirely contributes nothing, and counting its indices
would describe a shape the stone doesn't have. Tiers whose angle is `0.00` are excluded regardless,
because a horizontal facet's index carries no azimuth. Width is D10's minimum-offset definition.

### 8. New: `Kernel/Sources/facetsolve/main.swift`

`facetsolve <pattern.json> [--json] [--girdle <fraction>]`. Loads, solves, validates, prints.
Human-readable by default; `--json` emits the metrics, findings and observations as JSON so a test can
diff it. `--girdle` overrides `girdleTargetFraction`, defaulting to `0.04` — needed because a crown
tier's offset depends on it, and each authored pattern has its own diagram-measured value. Exit code 0
when `findings` is empty, 1 otherwise; `observations` never affect it.

## Explicitly not doing

- **No GUI, no 3D view, no rendering, no Metal, no AppKit or SwiftUI.** That is the second plan. The
  kernel has no opinion about how anything looks (D1).
- **No pattern *writing*.** The kernel decodes; it does not encode. Saving is driven by the authoring
  UI, which does not exist yet, and an encoder written now would be written against a guess.
- **No symmetry generator.** Expanding a seed set plus a symmetry setting into `indices` is an
  authoring-UI convenience; what lands in a file is always the full index list, so the kernel never
  needs the generator.
- **No rough solid, no yield, no rough facet names.** The 16-sided prism, its `P`/`C`/`G1`…`G16`
  labels and rough-retention are all display and authoring concerns tied to the viewport.
- **No `.gem` import.** Feasibility is recorded as unverified and it is not on this path.
- **No editing `Design/Prototypes/render-proof/`.** It is the record of the render decision. Code is
  copied out; nothing in it is changed.
- **No new meet form.** The outcome-condition meet ("cut so these edges are equal length") and the
  dial-gauge depth reading are known format gaps. If a pattern needs one, that is a `Deferred` item
  and a ticket, never an invention here.
- **No cheaters** (D14).

## Tasks

| # | Task | Status | Then | Commit | Note |
|---|---|---|---|---|---|
| T1 | Fill the Execution Protocol's four declaration blocks | awaiting owner | **owner stop** | commit | |
| T2 | Package skeleton + `Plane`/`planeNormal` with tests | not started | continue | — | |
| T3 | `Pattern` decoding with schema rejection tests | not started | checkpoint | commit | |
| T4 | `triplePoint` + `intersectHalfSpaces` | not started | **owner stop** | commit | |
| T5 | `solve` — the five meet forms, dependency order, normalisation | not started | **owner stop** | commit + push | |
| T6 | `validate` — nine findings, two observations, incremental vertex check | not started | continue | — | |
| T7 | `metrics` — counts, symmetry, proportions | not started | **owner stop** | commit | |
| T8 | `facetsolve` CLI | not started | **owner stop** | commit + push | |
| T9 | Regression fixtures: the three authored patterns | not started | continue | — | |
| T10 | Round-brilliant absolute anchor | not started | **owner stop** | commit | |
| T11 | 139-plane scale check and girdle invariance | not started | continue | — | |
| T12 | Close out | not started | **owner stop** | commit + push | |

---

**T1 — Fill the Execution Protocol's four declaration blocks**

- **Files:** `Design/Execution-Protocol.md` (edit)
- **Done when:**
  - The `Paths` block's `Deliverable / source tree` row reads `Kernel/` (SwiftPM package, library
    `FacetKernel`) — and notes that `CuttingBench/` joins it in the second plan.
  - The `Gates` block reads, in this order and with these exact commands:
    1. `swift test --package-path Kernel --disable-sandbox` — green. **Unconditional.**
    2. `xcrun swift-format lint --recursive --strict Kernel/Sources Kernel/Tests` — clean.
       **Unconditional.**
    3. `swift build -c release --package-path Kernel --disable-sandbox` — succeeds. **Conditional** on
       `Kernel/` having been touched, which in this plan is every task.
    4. The task's own *Done when* items, verbatim.
  - The `Guardrails` block carries all six: `Design/Prototypes/render-proof/` is read-only; no
    third-party dependencies; never touch signing, capabilities, entitlements or the bundle identifier
    and treat `project.pbxproj` as owner-run; `design-authoring-format.md` changes only via a task that
    names it; the round-brilliant expected values and the three patterns' fixtures may never be edited
    or have tolerances loosened to make a check pass; nothing tracked may read a path inside
    `LocalOnly/`.
  - The `Environment & toolchain` block carries all three: pass `--disable-sandbox` to `swift build`
    and `swift test`, because SwiftPM's manifest sandbox conflicts with the agent sandbox; the network
    is restricted, so a blocked network step means `blocked` plus an exact install request, never a
    workaround; no PDF page renderer and no physical device, so a task needing to *see* a diagram is
    blocked on the owner.
  - Each filled block keeps a visible marker that it is a project declaration, per the file's own
    header note.
  - The `Gates` block states that **gates 1–3 do not apply to a task that touches no Swift source** —
    the protocol's own rule is that a gate which doesn't apply simply doesn't run, and this task is the
    case: `Kernel/` does not exist yet, so all three would fail for the wrong reason. This task's only
    check is its own *Done when* items.
  - The three `⟦FILL IN⟧` markers are gone and no other line of the file changed.
- **Do not:** touch the portable body (§1, §3–§11) or the Changelog. Do not add a gate the exploration
  didn't declare. Do not create `Kernel/` yet.
- **Verification handle** — `permanent`:
  - **Where:** `Design/Execution-Protocol.md`, §2.
  - **Positive:** search the file for `⟦FILL IN⟧` → zero matches; the `Gates` block lists four numbered
    items with gate 3 marked conditional.
  - **Negative:** the Changelog's last entry still reads `1.1 (2026-08-12)` and §11's archive routine is
    byte-identical to before.
  - **Reads:** the file itself — this task's product *is* the document.

```
facet-kernel T1: fill the execution protocol's declaration blocks

- Paths names Kernel/ as the deliverable; gates, guardrails and
  environment filled from the Cutting-Bench exploration
- Closes Chore-Complete-Execution-Protocol
```

---

**T2 — Package skeleton + `Plane`/`planeNormal` with tests**

- **Files:** `Kernel/Package.swift` (new), `Kernel/Sources/FacetKernel/Geometry/Plane.swift` (new),
  `Kernel/Tests/FacetKernelTests/PlaneTests.swift` (new)
- **Done when:**
  - `swift build --package-path Kernel --disable-sandbox` succeeds.
  - `planeNormal` is `Double` throughout; the file contains no `Float`.
  - Tests assert, to `1e-12`: index 0 on a 96 wheel gives azimuth 0; index 24 gives azimuth π/2;
    a `.gdl` tier at 90° gives `z == 0`; a `.table` tier at 0° gives `(0, 0, 1)`; `.pav` and `.crown`
    at the same angle and index differ only in the sign of `z`; every returned normal has length 1.
  - A test asserts index 24 on a **120** wheel is *not* the same normal as index 24 on a 96 wheel.
- **Do not:** add the polytope, the solver, or `Pattern`. Do not import `simd`. Do not edit anything
  under `Design/Prototypes/`.

---

**T3 — `Pattern` decoding with schema rejection tests**

- **Files:** `Kernel/Sources/FacetKernel/Pattern.swift` (new),
  `Kernel/Tests/FacetKernelTests/PatternDecodingTests.swift` (new)
- **Done when:**
  - All three files in `Design/Patterns/` decode without error, and the decoded tier counts are 6, 7
    and 12 respectively.
  - `Pattern-Easy-Octagon.json` decodes with `state == .finished`, `wheel == 96`, and its P2 tier's
    meet equal to `.vertex` with facets `G1@0`, `G1@12`, `P1@0` in that order.
  - `Pattern-Novice-Ash-er.json`'s P2 tier decodes as `.fraction` with `percent == 24.862` and
    `to == .tcp`.
  - Each of these is rejected with an error naming the offending tier: a `vertex` with 2 facets; a
    `vertex` with 4; a `fraction` whose `to` is `.girdle`; a `percent` of `-1`; a `percent` of `101`;
    a `kind` of `"culet"`; two tiers both labelled `P1`; `formatVersion: 2`.
- **Do not:** write an encoder. Do not validate geometry here — decoding checks shape only. Do not
  copy the pattern files into the package; tests read them from `Design/Patterns/` via a path relative
  to `#filePath`.

- **Checkpoint:** run the gates.

```
facet-kernel T2-T3: plane derivation and pattern decoding

- planeNormal carried over from the render-proof spike, retyped to Double
- Codable Pattern with a tagged Meet enum; the three authored patterns decode
```

---

**T4 — `triplePoint` + `intersectHalfSpaces`**

- **Files:** `Kernel/Sources/FacetKernel/Geometry/Polytope.swift` (new),
  `Kernel/Tests/FacetKernelTests/PolytopeTests.swift` (new)
- **Done when:**
  - `triplePoint` returns `nil` for three 90° girdle planes at indices 0, 12 and 24 on a 96 wheel
    (all vertical, determinant `~2.5e-17`), and returns the expected point for a well-conditioned
    triple.
  - A unit cube built from six planes yields exactly 8 vertices and 6 facets of 4 vertices each.
  - A square pyramid — four `.pav` planes at 45° plus one `.table` — yields 5 vertices and an apex
    shared by all four side facets.
  - Each facet's polygon is wound counter-clockwise about its plane normal, asserted by the signed
    area being positive for all facets of the cube.
  - A plane that does not touch the solid appears in the input and is absent from `facets`.
- **Do not:** solve depths. Do not use the pattern files here — this task is geometry only, with
  hand-built plane lists.
- **Verification handle** — `permanent`:
  - **Where:** a test-only dump. `swift test --package-path Kernel --disable-sandbox --filter
    PolytopeTests/testCubeDump` prints the 8 vertices and 6 facet polygons.
  - **Positive:** the cube's 8 vertices print as all combinations of `±0.5`, and every facet lists 4
    vertex indices.
  - **Negative:** widen one plane's `d` from `0.5` to `0.75` and re-run → the printed vertex list still
    has 8 entries but four of them move to `x = 0.75`, and no facet gains or loses a vertex. A shape
    change that leaves the count identical is what a wrong winding or a bad tolerance would hide.
  - **Reads:** `intersectHalfSpaces` in `Kernel/Sources/FacetKernel/Geometry/Polytope.swift`.

```
facet-kernel T4: half-space intersection to vertices and facet polygons

- Cramer's rule with singular-triple rejection below 1e-10
- Per-facet polygons wound CCW about the plane normal
```

---

**T5 — `solve` — the five meet forms, dependency order, normalisation**

- **Files:** `Kernel/Sources/FacetKernel/Solver.swift` (new),
  `Kernel/Tests/FacetKernelTests/SolverTests.swift` (new)
- **Done when:**
  - All three authored patterns solve without throwing.
  - **Each is solved at its own `girdleTargetFraction`**, to six decimal places, because a crown tier's
    offset depends on it and these are the values that reproduce the source diagrams' measured girdle:
    `Easy Octagon` `0.033700` (thickness 0.067400), `Novice Ash-er` `0.032260` (0.064520), `Rand's`
    `0.040493` (0.059286). Fewer digits shifts `Rand's` crown offsets by ~4e-6, which exceeds the
    tolerance below. The `0.04` default is not used in this task's tests; passing it instead moves
    `Easy Octagon`'s C1 by 0.0094 and `Novice Ash-er`'s C1 by 0.0134.
  - `Pattern-Easy-Octagon.json` solves to these offsets, to `1e-6`: `G1` 1.000000, `P1` 0.738455,
    `P2` 0.738190, `C1` 0.719219, `C2` 0.583704, `T` 0.399704.
  - `Pattern-Novice-Ash-er.json` solves to: `G` 1.000000, `P1` 0.766044, `P2` 0.746320, `P3` 0.748472,
    `C1` 0.555876, `C2` 0.506084, `T` 0.323778.
  - `Pattern-Rands-Cut-Corner-Rectangle.json` solves to: `1` 0.681998, `2` 1.000000, `3` 0.732051,
    `4` 0.663463, `5` 0.681926, `A` 0.804153, `B` 0.598892, `C` 0.506432, `D` 0.642374, `E` 0.512068,
    `F` 0.382686, `G` 0.470588.
  - A test asserts the max rule is doing work: for `Easy Octagon`'s P2, dotting the named vertex with
    `P2@18`'s normal instead of the argmax gives 0.52198, and the solver returns 0.738190.
  - A test asserts a 90° tier registers no axial point: a pattern whose girdle precedes its first
    `tcp` tier still accepts that `tcp`.
  - `solve` throws a typed error, not a wrong answer, on a second `tcp` on the same side.
- **Do not:** build the polytope more than once per solve. Do not simulate the cut tier by tier — the
  depth of a tier comes from plane algebra over already-placed planes (D4).
- **Verification handle** — `permanent`:
  - **Where:** `swift test --package-path Kernel --disable-sandbox --filter SolverTests/testSolveDump`
    prints one line per tier: label, form, solved `d`.
  - **Positive:** for `Pattern-Novice-Ash-er.json` the `P2` line reads `P2 fraction d=0.746320`.
  - **Negative:** change that pattern's `P2` `percent` from `24.862` to `30` and re-run → the `P2` line
    moves to a different `d` **and** the `P3` line changes too, because P3's fraction endpoint is the
    axial point P2 established. A change that moved P2 alone would mean the endpoints aren't being
    threaded. Restore the file afterwards.
  - **Reads:** `solve` in `Kernel/Sources/FacetKernel/Solver.swift`.

```
facet-kernel T5: depth solver for all five meet forms

- Dependency-order solve; d = max(n . p) over the tier's facets
- size normalises to 1.0; tcp is the free datum, once per side
```

---

**T6 — `validate` — the ten findings, incremental vertex check**

- **Files:** `Kernel/Sources/FacetKernel/Validation.swift` (new),
  `Kernel/Tests/FacetKernelTests/ValidationTests.swift` (new)
- **Done when:**
  - All three authored patterns validate to an empty `findings` array **and** an empty `observations`
    array.
  - Each `Finding` case has a test that provokes exactly it, using a copy of a real pattern mutated
    in memory — not a file on disk.
  - `vertexNotOnIntermediateSolid` is provoked by pointing `Easy Octagon`'s C2 meet at
    `C1@0 C1@12 C2@18`-style facets that do intersect at a point but whose point is not on the solid at
    that tier.
  - A test asserts the check is genuinely incremental: `Easy Octagon`'s P1 axial point is a vertex of
    the solid before P2 is cut, and is **not** a vertex of the finished solid. Both assertions in one
    test, so a finished-polytope implementation fails it.
  - `tierContributesNoFacets` is provoked by a mutated pattern in which a later tier's depth is deepened
    until an earlier tier's facets are entirely removed, and the test asserts it lands in
    `observations`, that `findings` stays **empty**, and that the solved facet count drops by exactly
    that tier's index count. A tier consumed this way is legitimate (D17), so a test that expects a
    `Finding` here is wrong.
  - A `.inProgress` pattern with findings does not throw; a `.finished` one with findings still returns
    them rather than throwing — enforcement is the CLI's job.
- **Do not:** make `validate` throw or mutate. Do not skip the intermediate build by reusing the final
  polytope. Do not put `tierContributesNoFacets` or `duplicatePlanes` in `findings`.

---

**T7 — `metrics` — counts, symmetry, proportions**

- **Files:** `Kernel/Sources/FacetKernel/Metrics.swift` (new),
  `Kernel/Tests/FacetKernelTests/MetricsTests.swift` (new)
- **Done when:**
  - Facet counts are 37, 49 and 53 — each matching the count its own `notes` field declares.
  - `Easy Octagon`: rotational order 4, mirror axes `[6, 18, 30, 42]`, L/W 1.0000. A comment in the
    test records that its sheet declares plain 4-fold, so the solve is *stronger* than the claim.
  - `Novice Ash-er`: rotational order 8, L/W 1.0000.
  - `Rand's`: rotational order 2, L/W 1.36603 to `1e-5`, and half-width equal to `sqrt(3) - 1` to
    `1e-5`.
  - Girdle fraction of width: `Easy Octagon` 3.370%, `Novice Ash-er` 3.226%, `Rand's` 4.049%, each to
    `0.001`, when solved at the fractions T5 names.
  - **The D10 width and length are checked directly, not through the percentage.** `widthNormalised`
    is 2.000000 for both octagons and **1.464102** for `Rand's`; `lengthNormalised` is 2.000000 for all
    three — so `Rand's` L/W is 1.36603 while the octagons are 1.000. Each to `1e-5`. This is the
    non-circular half: it pins the axis convention rather than echoing the requested fraction, and the
    round brilliant in T10 is where that convention meets a *published* width.
  - `girdleThicknessNormalised` is 0.067400, 0.064520 and 0.059286 respectively, to `1e-5` — the
    diagram-measured values, which is what makes this an external check rather than an echo of the
    input.
  - Symmetry excludes `0.00` tiers: a test asserts including the table drops `Easy Octagon`'s
    rotational order to 1, and that the shipped code reports 4.
  - **Symmetry comes from surviving facets, not authored indices** (D18). A test mutates a pattern so
    that a tier of different rotational order is entirely consumed by a later tier, and asserts the
    reported order describes the *solid* — computing from the authored index sets gives a different
    answer, and the test asserts the shipped code does not give it.
- **Do not:** read any declared value out of `notes` and return it. Every number here is computed. Do
  not compute symmetry from `TierSpec.indices`.
- **Verification handle** — `permanent`:
  - **Where:** `swift test --package-path Kernel --disable-sandbox --filter MetricsTests/testDump`
    prints a metrics table for all three patterns.
  - **Positive:** the `Rand's` row reads `facets 53  rot 2  L/W 1.36603  girdle 4.05%`.
  - **Negative:** the `Easy Octagon` row reads `rot 4`, *not* `rot 8` — the crown's four 29.00 facets
    break 8-fold, so an implementation that ignored a tier's index set would read 8 here.
  - **Reads:** `metrics` in `Kernel/Sources/FacetKernel/Metrics.swift`.

```
facet-kernel T6-T7: validation findings and derived metrics

- Named vertices checked against the intermediate solid, not the finished one
- Facet count, symmetry, L/W and proportions all computed, never authored
```

---

**T8 — `facetsolve` CLI**

- **Files:** `Kernel/Sources/facetsolve/main.swift` (new), `Kernel/Package.swift` (edit — add the
  executable target)
- **Done when:**
  - `swift run --package-path Kernel --disable-sandbox facetsolve Design/Patterns/Pattern-Easy-Octagon.json`
    prints the pattern name, one line per tier with its form and solved `d`, the metrics table, and
    `no findings`; exit code 0.
  - The same command on a pattern with a findings-producing edit exits 1 and prints each finding.
  - **Observations print under their own heading and never affect the exit code** (D17). A pattern with
    a consumed tier and no findings prints `1 observation: tier P1 contributes no facets` and still
    exits 0.
  - `--json` emits a single JSON object with `metrics`, `findings` and `observations` keys and nothing
    else on stdout, so it can be piped to a differ.
  - `--girdle <fraction>` overrides the `0.04` default; omitting it uses `0.04`. A test asserts
    `--girdle 0.0337` on `Pattern-Easy-Octagon.json` reports `C1 d = 0.719219` while the default
    reports `0.728582`.
  - A `.finished` pattern with findings exits 1; an `.inProgress` pattern with the same findings exits
    0 and prints them as informational.
- **Do not:** add flags beyond `--json` and `--girdle`. No pattern writing, no interactive mode, no
  colour codes. Do not let an observation set the exit code.
- **Verification handle** — `permanent`:
  - **Where:** the `facetsolve` command line, above.
  - **Positive:** run it on each of the three patterns in `Design/Patterns/` with that pattern's girdle
    fraction from T5 → each prints `no findings`, `no observations`, and a facet count of 37, 49 and 53
    respectively.
  - **Negative:** copy `Pattern-Easy-Octagon.json` to `/tmp`, change its `C2` meet's first facet from
    `G1@12` to `C2@18` (a self-reference), and run on the copy → exits 1 and prints
    `namesOwnFacet(tier: "C2")`. The original in `Design/Patterns/` still prints `no findings`.
  - **Reads:** `solve` and `validate`, via `main.swift`.

```
facet-kernel T8: facetsolve diagnostic CLI

- Loads, solves, validates and prints; --json for machine diffing
- Exit 1 on findings for a finished pattern
```

---

**T9 — Regression fixtures: the three authored patterns**

- **Files:** `Kernel/Tests/FacetKernelTests/Fixtures/easy-octagon.json` (new),
  `Kernel/Tests/FacetKernelTests/Fixtures/novice-asher.json` (new),
  `Kernel/Tests/FacetKernelTests/Fixtures/rands-cut-corner-rectangle.json` (new),
  `Kernel/Tests/FacetKernelTests/RegressionTests.swift` (new)
- **Done when:**
  - Each fixture is the `--json` output of T8 for its pattern, **generated at that pattern's girdle
    fraction from T5**, committed as a golden file. The three commands, verbatim:
    - `facetsolve Design/Patterns/Pattern-Easy-Octagon.json --girdle 0.033700 --json`
    - `facetsolve Design/Patterns/Pattern-Novice-Ash-er.json --girdle 0.032260 --json`
    - `facetsolve Design/Patterns/Pattern-Rands-Cut-Corner-Rectangle.json --girdle 0.040493 --json`
  - `RegressionTests` re-runs each pattern at the same fraction and asserts the `--json` output equals
    its fixture exactly.
  - A comment at the top of each fixture names the command above that regenerates it, including the
    `--girdle` value — a fixture regenerated at the default would differ and the difference would look
    like a solver regression.
- **Do not:** edit a fixture to make a test pass — that is a guardrail (T1). If a fixture and the code
  disagree, the code is wrong or a real discrepancy has been found; either way it is a stop.

---

**T10 — Round-brilliant absolute anchor**

The properties in T5–T7 can all pass on a solver that is self-consistently wrong. This is the check
that catches that. Its source is a published quartz standard round brilliant — *Standard Round
Brilliant "Classic"*, GemCad-derived renderings by Bob Keller, angles for RI 1.54 — which ships four
**proportion ratios computed independently of this kernel**. Three of them depend on several tiers and
their meets at once, so they cannot be satisfied by accident.

- **Files:** `Kernel/Tests/FacetKernelTests/RoundBrilliantTests.swift` (new)
- **Done when:**
  - `Design/Patterns/Pattern-Standard-Round-Brilliant.json` **already exists and is not edited by this
    task.** It was authored and verified when this plan was written. Its tiers are, on wheel 96,
    `state` `finished`, `ri` `1.54`:

    | tier | part | angle | indices | meet |
    |---|---|---|---|---|
    | pb | pav | 45.00 | 3 9 15 21 27 33 39 45 51 57 63 69 75 81 87 93 | `tcp` |
    | g | gdl | 90.00 | 3 9 15 21 27 33 39 45 51 57 63 69 75 81 87 93 | `size` |
    | pm | pav | 43.00 | 0 12 24 36 48 60 72 84 | vertex `g@93 g@3 pb@3` |
    | cb | crown | 47.00 | 3 9 15 21 27 33 39 45 51 57 63 69 75 81 87 93 | `girdle` |
    | cm | crown | 42.00 | 0 12 24 36 48 60 72 84 | vertex `g@93 g@3 cb@3` |
    | s | crown | 27.00 | 6 18 30 42 54 66 78 90 | vertex `cm@0 cm@12 cb@3` |
    | t | table | 0.00 | 0 | vertex `s@6 s@90 cm@0` |

  - `notes` records the source and attribution, the sheet's verbatim meet text, and its published
    ratios as cross-checks. Read it rather than restating it — it is already in the file.
  - Solved at `girdleTargetFraction` `0.020000` — the sheet's own girdle, from its
    `H/W = (P+C)/W + 0.02` identity.
  - **The four published ratios are asserted, each to ±0.001:** `P/W` **0.4663** (sheet 0.466),
    `C/W` **0.2177** (0.218), `H/W` **0.7040** (0.704), `T/W` **0.5164** (0.516). `T/W` is the one that
    earns its place — the table's size emerges from the star and crown-main angles through three
    chained vertex meets.
  - Also asserted: **73 facets** (16 pb + 16 g + 8 pm + 16 cb + 8 cm + 8 s + 1 t), matching the
    declared count; `L/W` **1.000** to ±0.001; rotational order 8; `widthNormalised` **2.03918** to
    `1e-5`, which is where index 24 crosses a girdle *corner* rather than a flat.
  - A comment records that the `s` and `t` meets are insensitive to which valid triple is named — six
    combinations of the sheet's `meet cm,cb` and `meet s,cm` were checked and all give identical
    geometry — so a reader who picks a different triple has not broken anything.
- **Do not:** loosen any of the four ratio tolerances, or adjust an angle, to make it pass — guardrail
  (T1). Do not change `girdleTargetFraction`'s default to suit this pattern; pass `0.020000` per-solve.
  Do not edit `Pattern-Standard-Round-Brilliant.json` — it is a fixture under the same guardrail. Do not
  read the source sheet from `LocalOnly/`; the pattern file carries everything needed.
- **Verification handle** — `permanent`:
  - **Where:** `swift run --package-path Kernel --disable-sandbox facetsolve Design/Patterns/Pattern-Standard-Round-Brilliant.json --girdle 0.020000`
  - **Positive:** prints `no findings`, 73 facets, and `P/W 0.466  C/W 0.218  H/W 0.704  T/W 0.516`.
  - **Negative:** change `s`'s angle from `27.00` to `22.00` in a `/tmp` copy and run on it → `T/W`
    moves off 0.516 by more than 0.01 while `P/W` stays at 0.466. That asymmetry is the point: the
    table is downstream of the star, the pavilion isn't, so a solver that mis-chains vertex meets
    breaks one and not the other.
  - **Reads:** `solve` and `metrics`, via `facetsolve`.

```
facet-kernel T10: round-brilliant absolute anchor

- Pattern authored from Keller's published quartz SRB cutting instructions
- All four published ratios pinned: P/W, C/W, H/W and T/W
```

---

**T11 — 139-plane scale check and girdle invariance**

- **Files:** `Kernel/Tests/FacetKernelTests/ScaleTests.swift` (new),
  `Kernel/Tests/FacetKernelTests/GirdleInvarianceTests.swift` (new)
- **Done when:**
  - The scale test generates a pattern with 139 planes programmatically — enough tiers on a 96 wheel to
    reach 139 — solves it, builds the polytope, and asserts the solve completes and the solid closes.
  - The scale test asserts a wall-clock ceiling of 5 seconds for one full solve on this machine, so a
    cubic-in-planes regression is visible rather than silent.
  - A comment records that `Kiev Triangle` (139 facets, 3-fold mirror, RI 2.160) is the real design
    this stands in for, that no pattern file for it is authored, and that this check is about scaling
    only.
  - **The invariance test solves all three authored patterns at `girdleTargetFraction` of `0.02` and
    `0.08` and asserts these are identical between the two: facet count, culet z, table radius, crown
    height, L/W, and every tier's facet count.** It also asserts that total depth *does* change, by
    exactly the girdle difference — an implementation that ignored the parameter entirely would
    otherwise pass.
  - For `Easy Octagon` the expected values at both settings are: 37 facets, culet z −1.00935, table
    radius 0.68292, crown height 0.33230.
  - A comment states why this must hold (D19): no meet can cross the girdle band, so the crown
    translates rigidly. A failure means the girdle value has leaked into a pavilion depth or a crown
    meet has resolved against a pavilion facet.
- **Do not:** author a `Kiev Triangle` pattern. Do not treat the 5-second ceiling as a performance
  target to optimise toward; it is a regression tripwire. Do not weaken the invariance assertions to
  tolerances looser than `1e-9` — the quantities are exactly equal, not approximately.

---

**T12 — Close out**

- **Files:** `Design/Plans/Facet-Kernel.md` (edit),
  `Design/Explorations/Cutting-Bench.md` (edit), `Design/Tickets/Chore-Complete-Execution-Protocol.md`
  (move), `Design/Archived/ArchivedCatalog.md` (new)
- **Done when:**
  - No temporary verification handles to delete — every handle in this plan is marked `permanent`.
  - Every item in this plan's **Deferred** section has a ticket in `Design/Tickets/` with
    `Status: untriaged`.
  - The untriaged ticket count in `Design/Tickets/` is reported as one line.
  - Archive per `Design/Execution-Protocol.md` §11: this plan `Facet-Kernel`, the exploration
    `Cutting-Bench`, and the ticket `Chore-Complete-Execution-Protocol`.
  - **`Cutting-Bench` gets the §11 banner judgment answered explicitly.** It contains claims this plan
    contradicts: **S3**'s success set was amended after closing and `Easy Does it Modified` was
    descoped; **S4**'s note that the format document's own half-finished tables can be loaded is void
    under JSON; **S9**'s guardrail 4 permits format edits only via the I19 and I20 tasks, which the
    format has moved well past; and **I6**'s "never a sequential per-tier solve" is right for the depth
    solve but the *validation* is deliberately incremental (D6). Banner it and catalog it as
    `superseded by Facet-Kernel`, with the contradiction as the why-clause.
  - `Facet-Kernel` and `Chore-Complete-Execution-Protocol` are catalogued `executed`; the ticket's line
    names this plan as provenance.
- **Do not:** archive the three pattern files or the two ADRs — nothing in `Design/` root, `Patterns/`
  or `Decisions/` is archivable. Do not delete `Design/Prototypes/render-proof/`; its removal is not
  this plan's call.

```
facet-kernel T12: close out

- Archive Facet-Kernel, Cutting-Bench and Chore-Complete-Execution-Protocol
- Cutting-Bench banners its superseded S3, S4, S9 and I6 claims
```

## Deferred

Empty at authoring. The executor appends adjacent problems it found and must not fix — and files each
as a ticket in `Design/Tickets/` immediately with `Status: untriaged`, per the protocol.
