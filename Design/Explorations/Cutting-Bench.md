# Cutting Bench — Exploration

Status: **CLOSED 2026-08-20**
Started: 2026-08-20 · via /a-explore
IDs: **S** = scope · **I** = implementation · **U** = UI/UX

A Mac-only application where a stone is cut virtually by entering angle, symmetry, index and a
three-facet meet point. Solid rendering only. Exports the cut in the format specified by
`Design/design-authoring-format.md`. The free-cutting phase of GemCutting, extracted — no final
render, no game mechanics.

## Grounding

What exists today, on 2026-08-20:

- **No production source tree exists.** The repo is `Design/` + `LocalOnly/` only —
  `Execution-Protocol.md:57` (`| Deliverable / source tree | **⟦FILL IN⟧**`). This app would be the
  project's first real code.
- **Facet placement from angle + index exists and works** in the throwaway render-proof spike:
  `render-proof/Sources/GemSpike/Geometry.swift:35` (`var planes: [Plane]`) builds a half-space list
  from `Tier(angle:indices:crown:depth:)` on a 96-tooth wheel.
- **Depth solving does not exist.** `Geometry.swift:120`
  (`rather than solved from meetpoints — meetpoint solving is the geometry kernel's job`) — the spike
  set depths from standard proportions and eyeballed them. This is the map's **A5**, unbuilt.
- **Vertices, facet polygons and meetpoints do not exist.** `Geometry.swift:3`
  (`No mesh, no BVH, no convex-hull construction`) — the map's **A10** names half-space → polytope
  construction as separate, unbuilt work, and it is what any meet check needs.
- **The authoring format is fully specified**: header plus one row per tier, five meet forms —
  `TCP`, `SIZE`, `GIRDLE`, a named vertex, a fraction between two vertices
  (`design-authoring-format.md:59`).
- The format says **symmetry order is computed, not authored**
  (`design-authoring-format.md:37` — `Do not author these — they are computed`), while the ask names
  symmetry as an input. Not yet resolved.
- The format flags **two cases it will not stretch to**: an outcome-condition meet ("cut so these
  edges are equal length") and a dial-gauge depth reading that may not equal a plane offset
  (`design-authoring-format.md:186`).
- Renderer precedent: SwiftPM executable, Metal, macOS 15, spectral path tracer
  (`render-proof/README.md:12`). The map's **T7** (interactive-view render technique) is still open.

## Tickets folded in

- **`Chore-Complete-Execution-Protocol`** — asks for the four `⟦FILL IN⟧` declaration blocks in
  `Design/Execution-Protocol.md`: the deliverable/source-tree row under `Paths`, the `Gates`, the
  `Guardrails`, and `Environment & toolchain`. Its own trigger is "the moment the project exists and has a
  stack," and this exploration is that moment; more pointedly, a plan built from this exploration cannot be
  executed under the protocol while its gates read `⟦FILL IN⟧`. Answered by **S7** through **S10** below.

## Scope & purpose

- **S1** — Two purposes, both primary and both confirmed by the owner:
  **(a) an authoring workhorse** — produce trustworthy tier tables for the design catalog, so
  authoring becomes *cut it and export it* rather than *write the meet specs in a text editor and
  hope they close*; and **(b) an engine de-risking exercise** — the depth solver (**A5**) and
  half-space → polytope construction (**A10**) are the game's critical path and are entirely unbuilt,
  so this builds them against real designs before the game depends on them.

- **S2** — "Working" is a **verifier** test, not just an editor test. The tool passes when the owner
  can take a printed GemCad sheet, reproduce the design tier by tier, and have the tool state whether
  the reading of that sheet's meets was correct: the solid closes, the computed facet count matches
  the count the sheet declares, and every facet named at a vertex genuinely passes through it — then
  export the table. The value is catching a misread of a vague instruction like `Girdle meet point`
  before it reaches the game, which is precisely the doubt recorded at
  `design-authoring-format.md:159` (`The ? cells are guesses… not verified`).
- **S3** — The success set is **three designs, each breaking a different part of the solver**:
  `Rand's Cut Corner Rectangle #1` (already half-translated in the format doc, and its `?` rows say
  `level girdle` — a levelling operation, not a depth), `Easy Does it Modified` (the vague-printed-
  instructions case), and `Novice Ash-er` (the step cut, which stresses fractional meets because
  consecutive same-side steps have nothing to converge on). Plus **`Kiev Triangle` (139 facets,
  96-index, 3-fold mirror, RI 2.160) as a separate scale check** — it must load and solve without
  dying; authoring its meets correctly is not part of the bar. Authoring the full catalog is work the
  tool *enables*, deliberately not work that defines it done — otherwise "done" depends on how many
  evenings get spent reading diagrams.

  **Amended after closing — the success set is now `Rand's Cut Corner Rectangle #1`, `Novice Ash-er`
  and `Easy Octagon`.** All three are authored and verified against their own solved geometry (37, 49
  and 53 facets, each matching its sheet's declared count), and between them they exercise all five
  meet forms — `Easy Octagon` covers `size`/`tcp`/`girdle`/vertex, `Novice Ash-er` adds `fraction`,
  `Rand's` adds the elongated outline. `Easy Does it Modified` is **descoped** on the owner's call: it
  was in the set as "the vague-printed-instructions case," which is a transcription difficulty rather
  than a solver one, and no longer arises once a pattern is authored by cutting it in the tool rather
  than transcribed from a sheet. `Easy Octagon` was not in the original set and became the simplest
  reference case. `Kiev Triangle` remains the scale check, unchanged.

  **One coverage gap this leaves:** nothing in the set has odd-order symmetry — two regular octagons
  and a 2-fold rectangle. `Kiev Triangle` is 3-fold mirror, so the scale check picks it up.
- **S4** — **The authoring format is the tool's native document: exactly one file on disk.** Save
  writes an authoring-format file, Open reads one back; there is no second representation and no
  export step, because a separate document format means the artifact verified on screen and the
  artifact handed to the game are two things that can disagree silently. A consequence worth having:
  the half-finished tables already sitting in `design-authoring-format.md:120` can be loaded and
  finished in the tool. Where the format cannot hold something, that is a finding about the format,
  not a reason to invent a second one — proving the format out is half of why this tool exists.
- **S5** — **App and UI state is not in the design file and not in a per-design sidecar** — camera
  position, window layout, which design was last open are app-level preferences, separate from the
  cut process for any given design. Nothing about "where I left off" needs storing: a half-cut stone
  is just a design with fewer tiers in it, which the format already expresses exactly.
- **S6** — **The geometry kernel is production code from the first commit; the GUI is explicitly
  disposable.** The solver (**A5**) and polytope construction (**A10**) live in their own module with
  tests from day one, and the game later depends on that same module — so the hardest,
  most correctness-critical code in the project is written once. The Mac app around it may be
  stripped and rebuilt later and is allowed to be scrappy. Rejected: a render-proof-style throwaway
  (`render-proof/README.md:6` — `This is a spike, not an engine. No tests, no error handling, no
  abstractions.`), because **S2**'s verifier bar is empty without a kernel trustworthy enough to
  believe over your own reading of a sheet. Also rejected: growing this app into the game, which
  would import the economy, jobs and scoring this exploration declares non-goals.

- **S7** — **The source tree is two root-level folders, with a third to come.**
  `Kernel/` is a SwiftPM package — library target `FacetKernel`, tests `FacetKernelTests` — containing no
  UI and no rendering. `CuttingBench/` is the Xcode project for the Mac app, which puts a UI on the kernel.
  Both sit at the repo root beside `Design/` and `LocalOnly/`. **The game later becomes a third root-level
  folder depending on the same `Kernel/`**, which is the whole point of **S6**: the solver is written once.
  `Design/Prototypes/render-proof/` stays where it is, unrelated to all three.
  The protocol's `Paths` row therefore names two deliverables rather than one — honest, because they are held
  to different standards (production kernel, disposable GUI).

- **S8** — **The gates, in order, before any task is marked done.** Toolchain verified on this machine:
  Swift 6.3.3, Xcode 26.6, macOS 26.5.2; no SwiftLint installed, and `swift-format` ships inside the Xcode
  toolchain.
  1. `swift test --package-path Kernel` — green. **Unconditional** (fast, and the kernel must not break).
  2. `xcrun swift-format lint --recursive --strict Kernel/Sources CuttingBench` — clean. **Unconditional.**
  3. `xcodebuild -project CuttingBench/CuttingBench.xcodeproj -scheme CuttingBench -configuration Release
     build` — succeeds. **Conditional** on `CuttingBench/` having been touched; it is the slow gate and it
     builds the kernel anyway.
  4. The task's own *Done when* items, verbatim.
  SwiftLint is deliberately not introduced — one formatter is enough and `swift-format` is already present.
  **Anything needing a real window, a render, or the owner's eye is not a gate** but an owner-verification
  stop (`Execution-Protocol.md:213`), and much of this tool's behaviour falls there.

- **S9** — **The guardrails** — hard constraints, never broken to make progress:
  1. **`Design/Prototypes/render-proof/` is read-only.** Code is copied *out* of it (**I18**); nothing in it
     is edited. It is the record of the render decision.
  2. **No third-party dependencies.** Swift, Metal, AppKit and the standard library only; nothing fetched at
     runtime.
  3. **Never touch signing, capabilities, entitlements or the bundle identifier**, and treat
     `project.pbxproj` as owner-run (`Execution-Protocol.md:99`).
  4. **`design-authoring-format.md` changes only via the tasks the plan names** — documenting the state field
     (**I19**) and the per-tier wheel column (**I20**). Nothing else in it moves without the owner's say.
  5. **The hand-computed brilliant's expected values may never be edited or loosened** to make a test pass
     (**I17**), nor may the success-set designs' fixtures.
  6. **Nothing tracked may read a path inside `LocalOnly/`** — a `CLAUDE.md` rule, restated because the
     53-design PDF lives there and is exactly what a task would be tempted to reach for.

- **S10** — **Environment & toolchain**, three facts that change how an agent works here:
  1. **SwiftPM's manifest sandbox conflicts with the agent sandbox.** The fix is recorded at
     `render-proof/README.md:12`: pass `--disable-sandbox` to `swift build`.
  2. **The network is restricted** — confirmed still current. No fetching; a blocked network step means
     marking the task `blocked` with an exact, copy-pasteable install request, never a workaround, a mirror,
     or a hand-written stand-in dependency.
  3. **No physical device, and no PDF page renderer.** Nothing available can render a page of the 53-design
     PDF as an image — no poppler, no PyMuPDF, and `sips` cannot select a page. A task that needs to *see* a
     design diagram is blocked on the owner, not solvable by the agent. This will come up: `Kiev Triangle`
     is the scale check (**S3**) and its meets live in its diagrams.

### Non-goals

- **Not a general-purpose faceting design tool for bench work** (a "Mac GemCad"). The owner accepts
  it may devolve into that, or spin off as a side project, but nothing in this design is shaped to
  serve it: no printing, no GemCad interop obligation, no measurement readouts on that account.
- No final/photorealistic render — solid rendering only.
- No game mechanics: no economy, no scoring, no jobs, no manual machine simulation.
- **No cheaters** (**I14**) — index positions are whole numbers only.

## Implementation

- **I1** — **Symmetry is a typing shortcut, not stored data.** It is a generator: the author gives a
  tier a **seed set** of index positions plus a symmetry setting, and the tool expands that to the
  full index list, which is what gets written to the file's `indices` column. Nothing symmetry-shaped
  is persisted — the file stays exactly the format the game reads (**S4**), and the header's symmetry
  order stays computed from geometry, a cross-check rather than a source of truth, per the format's
  own reasoning that declared metadata is a claim, not a fact
  (`design-authoring-format.md:37`). Rejected: symmetry as a stored field with indices derived at
  load, which would make the saved file no longer the format the game reads.
  **The seed set is a set, not one index** — `Rand's Cut Corner Rectangle #1`'s girdle tier
  `8 40 48 56 88 0` is 2-fold mirrored from seeds `{0, 8}` (mirror about 0 sends 88↔8 and 56↔40, 48
  fixed), and its pavilion tier `4 12 36 44 52 60 84 92` is the same symmetry from seeds `{4, 12}`.
  **A raw index list can always be typed instead**, bypassing the generator entirely — a generator
  that can't be bypassed would make some design unauthorable in the tool built to author it.
- **I2** — **The symmetry setting lives on the design, with a per-tier override including "none."**
  Design-level is the right default because it is genuinely a property of the stone —
  `Rand's Cut Corner Rectangle #1` is 2-fold mirrored in every tier with only the seed set varying,
  and a pinwheel such as `Apex Pinwheel` is rotational-only across the whole stone rather than tier by
  tier (`design-authoring-format.md:40`). The override exists for a real case in that same design: a
  table tier is one facet at `0.00°`, where the normal points straight up the axis and **index is
  meaningless** — every index yields the identical plane — so a 2-fold generator fed seed `{0}` would
  emit `0 48` where the format writes `0`. Rejected: silently deduping identical generated planes
  instead of an override, because a silent rule that happens to work here could surprise elsewhere,
  and near-coincident planes are already a known hazard in this project (`Geometry.swift:63` —
  pavilion mains and lower girdle halves smear into one surface under normal blending).
  **Duplicate generated planes are a validation warning, not a silent fix:** if a tier generates two
  identical planes, the tool says so.
- **I3** — **The solver works in normalized units: the `SIZE` tier's plane offset is 1.0 by
  definition**, and every other depth is solved relative to it. No millimetres appear in the document.
  A design is scale-invariant — every meet is an angle or a proportion — and the format itself says
  `SIZE` is not design data (`design-authoring-format.md:76` — `This is not part of the design — it
  comes from what the player is trying to cut`), so this tool, which has no player and no job, needs a
  convention rather than a number. The `SIZE`-plane offset is a well-defined anchor even for non-round
  outlines, where "diameter" is not: `Rand's Cut Corner Rectangle #1`'s `SIZE` row is a 90° girdle tier
  on `8 40 48 56 88 0`, so *those* planes' offset is the unit and the rectangle's other dimension falls
  out of the meets, exactly as the format requires (`there is exactly one SIZE row… Width follows from
  the meets`). Matches the spike in spirit — `Geometry.swift:113` (`Girdle radius is 1.0`).
  Two consequences, both closed:
  **Girdle thickness** — the `GIRDLE` form's 3–5%-of-width target is a ratio and works unchanged, with
  width taken as twice the maximum girdle-plane offset **computed from the solved outline**, never
  assumed.
  **Absolute-millimetre specs** — a design that states one (`SUPERPEAR 96`: 0.3±0.1mm girdle on a
  12–13mm stone) keeps it in `notes` as free text; it is a cross-check the tool performs by scaling the
  normalized solve at check time, not a solve input. Rejected: a real millimetre target as an authoring
  parameter — more faceter-friendly, but it starts down the bench-tool direction declared a non-goal
  and puts a number in the document the format says is not the design's. A millimetre readout, if ever
  wanted, is a display multiplier in app preferences (**S5**).
- **I4** — **The stone always starts as a real rough solid that gets cut away.** Not a rendering
  helper and not an empty viewport: a solid is present from before the first tier, and each tier
  removes material from it. **Its shape and dimensions are a built-in constant** — not authored, not
  derived from the design, not adjustable. It is a **16-sided prism on the axis**, not a cylinder:
  **I9** requires every rough surface to carry a name and a cylinder's wall is one unnameable surface.
  Sixteen reads as round enough while keeping labels legible, and the count is a build constant with no
  design consequence, so it can change without affecting any design. It plays the part of a preform
  (`Glossary.md:13` — `A rough stone shaped into an intermediate blank before faceting begins`).
  Rejected: rendering nothing until
  the design's planes bound a solid — with geometry as an intersection of half-spaces a partial design
  is usually unbounded (cut the pavilion mains and nothing limits the solid upward), so most of a stone
  would be authored blind, and watching each tier land is the tool's value.
  **Surviving rough surface is legitimate, not an error.** It is expected mid-authoring (no table cut
  yet leaves the prism's top cap), it is correct for the preforms in the starter set (**F6**), and
  the owner confirms it can survive to completion, though rarely. So rough retention says nothing
  about validity.
- **I5** — **The format's "the solid has to close" rule (`design-authoring-format.md:180`) is a real
  boundedness test on the design's own planes**, run independently of the rough. It cannot be inferred
  from whether rough surface remains, in either direction: rough survives for legitimate reasons
  (**I4**), and a design that genuinely closes can still poke through a fixed rough. A design with an
  uncut top correctly fails this test — that is an expected mid-authoring state, and only an error once
  the design is declared finished.
- **I6** — **The whole design is re-solved on every change**, tiers ordered by their dependencies —
  never a sequential per-tier solve, and never an incremental update. Two reasons. Editing an early
  tier changes every later tier's depth, so there is nothing to update incrementally. And the solve is
  inherently **two-phase**: a `TCP` meet on the first tier constrains nothing
  (`design-authoring-format.md:68` — `On the first tier it's free — it just decides where the culet
  sits, which is arbitrary`), since every facet in a tier shares a tilt and so any depth puts them
  through some axial point; and a 90° girdle plane has no vertical extent of its own in a half-space
  model, its edges coming from the crown and pavilion planes, so nothing reaches back to pin the first
  tier either. Therefore **the first free meet sets a provisional scale, and `SIZE` is a
  normalization rather than a constraint**: pin the culet arbitrarily, solve every later tier relative
  to it, then uniformly rescale the finished solid so the `SIZE` tier's plane offset is 1.0 (**I3**).
  The arbitrariness cancels. Confirmed with the format's author as the intended reading; because it is
  an inference about the format rather than something the format states, **the solver's tests cover it
  explicitly** — a design solved from two different provisional culet depths must produce identical
  normalized geometry.
  At ≤150 planes a full re-solve is cheap enough to run on every keystroke; caching is an optimization
  to reach for only if measurement says it's needed, not a decision to make now.
- **I7** — **Rough retention (yield) is a wanted metric: the volume of the rough it started from
  against the volume of the finished stone.** Nice to have in this build, explicitly not critical, and
  the owner's reason for wanting it now rather than later is that retrofitting it may be harder than
  building it in. It works because the rough is a fixed built-in solid (**I4**) and both volumes are
  measurable from the same solve. **Where the un-normalized scale is stored is still open** — see the
  Open queue; the normalization to `SIZE` = 1.0 (**I3**) discards the stone's size relative to the
  rough, which is exactly the number yield depends on.
- **I8** — **Nothing about size-relative-to-rough is stored.** Yield is computed as a property of the
  design: the largest instance of it that fits inside the built-in rough, over the rough's volume,
  recomputed on every solve. Nothing to persist and nothing lost on reopen. This works only because
  this tool has no mistakes and no material loss, so the sole thing setting stone size is where the
  girdle goes, and the sensible default is as large as the rough allows. Rejected: a new field in the
  format (a format change for a nice-to-have), and a tagged line in `notes` (machine-read data in a
  human free-text field). A yield readout at a smaller size, if wanted, is an app-level slider rather
  than document data.
- **I9** — **The rough's facets are named** (`P`, `C`, `G1`, `G2`, …), so every surface on the stone
  carries a name at all times, cut or not. Consequence: a cut is always identifiable as *index, angle,
  and three intersecting facets* — there is never a moment with nothing nameable to meet. This is the
  owner's proposal and it settles the rough's shape question left open in **I4**: a named-facet rough
  means a **prism**, not a cylinder, which is why **I4** specifies a 16-sided one. Naming: `P` for the
  bottom cap, `C` for the top cap, `G1`…`G16` for the wall facets.
- **I10** — **A tier may be given an explicit depth directly, via a slider or field, instead of a
  meet.** The owner's reasoning: the only tiers that need this are the girdle and the one that sizes the
  stone — one or two per design — and an explicit depth like `0.73` is not something that survives into
  the game. It fits the format rather than fighting it: the tiers needing it are precisely those whose
  meet form is externally supplied (`SIZE`, which the format says `comes from what the player is trying
  to cut`, and `GIRDLE`, whose target follows from size), so **the slider is this tool standing in for
  the job that doesn't exist here**. The exported row keeps the form name, not the number.
- **I11** — **Rough facet names are for authoring and display only; a saved meet never references
  one.** A design whose meets name a rough facet would only reproduce against that exact built-in
  rough, and the game's designs have to stand alone. A tier that genuinely needs a rough reference to be
  pinned is flagged as unexpressible rather than written to file.
- **I12** — **Depth-by-percentage: the author names the two endpoint vertices first, then slides the
  percentage between them.** The slider *is* the format's fifth form, live — nothing is converted on
  save and the row is a legal format row throughout. This is why the format's fifth form exists: `for
  steps and any place there's no convergence to aim at` (`design-authoring-format.md:105`), the case
  `Novice Ash-er` presents. **Available on any tier**, not restricted to `SIZE` and `GIRDLE`, though the
  owner expects those to be almost all of its use. (Per *tier*, since a tier shares one depth by
  definition.) Rejected: letting the tool pick the endpoints itself and back-solve a percentage — which
  two vertices a depth is expressed against is a judgement about the design, not an inference.
  A bare, unexpressible depth therefore only arises when neither endpoint can be named — the format's
  own known gap (`design-authoring-format.md:195`).
- **I13** — **`level girdle` is not a gap** — it collapses into **I12**: name the vertex the previous
  tier established and the tier's own edge vertex, then slide. `Rand's Cut Corner Rectangle #1`'s two
  such rows (a 90° girdle tier on `24 72` and a 65° tier on the same indices) are ordinary fifth-form
  rows, so that design stays fully authorable and **S3**'s bar for it is unchanged.
  **The format's two remaining gaps are refused loudly, with a ticket each**: the outcome-condition meet
  ("cut so these edges are equal length") and the dial-gauge depth reading (`Tumbuka Fulu` P8,
  `design-authoring-format.md:198`). Designing a new meet form is a change to the *format*, which is a
  bigger decision than this tool and does not get swallowed into it.
  **Negative requirement: nothing in the tool may assume a flat girdle.** About 99% of designs have one,
  but it is not a rule — non-flat girdles exist and are still expressible in the agreed meet forms, so a
  flat girdle must never be baked into the solver, the validation or the display.
- **I14** — **No cheater support.** A cheater (**A2**) is a cutting-time correction — you nudge off the
  stop because the stone drifted — whereas a published design sits on exact index positions, and the
  owner knows of no design that uses a fractional index. Index positions are therefore whole numbers
  throughout, matching the format's `indices` column. If a design ever needs a fractional index, that is
  a format change and gets a ticket, not a workaround.
- **I15** — **Authoring uncertainty is not stored anywhere.** A row the author is unsure about resolves
  the moment the design solves — the tool either validates it or reports why not — so there is nothing
  durable to record, and two readings of a sheet that both validate to the same geometry differ in no way
  that matters. `notes` remains available for a human remark, which the format already allows.
- **I16** — **One kernel library, one app.** In the kernel: the runtime design type, authoring-format
  read and write, the depth solver, polytope construction, and validation. Out of the kernel: rendering,
  Metal, all AppKit/SwiftUI, and anything about how it looks. Format I/O and geometry live as separate
  source directories inside the one target rather than as two libraries — splitting them buys a case
  that hasn't come up (reading a design without the solver), and a wrong split costs more to undo than a
  late one costs to add.
  **Packaged as a local SwiftPM package in the repo for the kernel, with the Mac app as an Xcode project
  depending on it.** The standard Apple shape, and it keeps `project.pbxproj` churn away from the code the
  game inherits — which matters because `Execution-Protocol.md:99` treats that file as owner-run.
  Precedent for the SwiftPM half: the render-proof spike is a plain SwiftPM executable.
- **I17** — **The solver's oracle is property-based tests plus one hand-computed design.** No external
  reference implementation is used — the owner does not have GemCad, and a test suite must not depend on
  software this machine may not have.
  **Properties (the backbone):** every named vertex lies on all the planes named at it; two different
  provisional culet depths yield identical normalized geometry (**I6**); the computed facet count matches
  the count the sheet declares; references point backwards only.
  **The absolute anchor:** a standard round brilliant's published proportions, hand-computed, checked
  against the solved vertices — this is what catches a solver that is self-consistently wrong, which the
  properties alone cannot.
- **I18** — **The only code carried over from the render-proof spike is the plane derivation** —
  `Geometry.swift:35` (`var planes: [Plane]`), about fifteen lines turning angle plus index into a plane
  on a 96-tooth wheel — copied into the kernel with tests around it. It is proven, and the wheel
  convention is exactly the thing that must not end up subtly different in two places. **Nothing else
  comes over**: not `shaders.metal`, `Renderer.swift` or `Window.swift`, and not the `Material` type with
  its Cauchy dispersion (`Geometry.swift:197`), since a solid render needs no refractive index.
  **render-proof stays where it is for now** — it still answers the final-render question this tool does
  not touch, and its deletion is not this work's call, despite its README saying to delete it once folded
  in (`render-proof/README.md:6`).
- **I19** — **A design can always be saved; validation is reported, not enforced — and the design carries
  a state.** A half-authored design is normally invalid (nothing closes until the last tier), so validity
  cannot gate ordinary work; but an invalid design escaping silently to a file would destroy the trust the
  tool exists to create. So the design distinguishes **in progress** from **finished**, and only a
  finished design must be fully valid.
  **This adds a state field to the authoring format's header** — the owner's call, as the format's author,
  on the grounds that it is "a handful more characters." Without it the distinction would live only in the
  app and the game could not tell a finished design from an abandoned one. **`design-authoring-format.md`
  must be updated to document the field** — a task for the plan, since this session does not edit it.
- **I20** — **The index wheel is a per-tier property, not just a header field.** A design declares a default
  wheel (96, 120, 64 or 80) that new tiers inherit, and **any tier may override it** — a gear change
  mid-cut, which is a real operation on a real machine. Tiers before it are untouched; the override only
  changes the number used to compute that tier's plane. Nearly free to build: the plane derivation is
  `theta = 2π · index / wheel` (`Geometry.swift:42`), so per-tier is a one-line change from the spike's
  per-design `wheel`.
  **This dissolves an edge case rather than adding one.** A 96-wheel `24` is not a 120-wheel `24`, so
  changing a design-wide wheel after tiers exist would either corrupt indices silently or have to be
  refused; with the wheel recorded per tier, changing the default simply applies to new tiers and nothing
  existing moves.
  **Symmetry (I2) is unaffected in kind:** an order like 6-fold is wheel-independent, and a tier's seed set
  is expressed in that tier's own teeth.
  **This is the second sanctioned change to the authoring format** (with **I19**'s state field): tier rows
  gain an optional wheel column. `design-authoring-format.md` must document both.

## UI / UX

- **U1** — **A meet is specified by clicking the facets in the 3D view, with typing always available as
  the alternative.** Clicking is the primary path: naming three facets by hand is exactly where a misread
  sheet becomes a wrong design, and clicking what is visibly there removes that error class rather than
  detecting it afterwards. Typing stays because it is faster once the labels are known and because it is
  what the format actually holds. Consequence: the viewport is a first-class working surface, not a
  preview, and facets facing away from the camera need a way to be reached.
- **U2** — **One large orbitable 3D view, dominant, with snap buttons for face-up, profile and face-down,
  and the tier table in a resizable side or bottom panel.** Rejected: the three fixed orthographic views
  of a GemCad sheet (crown, pavilion, profile) — familiar to a faceter, but three small views cost exactly
  the space that clicking facets (**U1**) needs, and the snap buttons give the same orientations on demand.
  Also rejected: one dominant view plus permanent thumbnails of the other two, for the same reason at
  smaller scale. Orbiting is known to read well — the spike's `Window.swift` is an MTKView harness for it.
- **U3** — **Stepping back through the cut is a dedicated scrubber, independent of tier-table selection.**
  Selecting a row in the table must *not* change what the viewport shows — clicking a row to read or edit
  its meet is a frequent action and it cannot reset the view. Rejected: row selection doubling as the
  scrubber (one fewer control, but it conflates reading a row with changing the displayed state).
  Cheap to build: the solve is global (**I6**), so showing tier N is rendering the first N tiers' planes.
- **U4** — **Playback has three granularities**, the owner's list:
  1. **Tier at a time** — the whole tier's facets appear at once, display updates immediately.
  2. **Facet at a time** — each facet within a tier is its own step, appearing immediately.
  3. **Facet at a time, progressively cut** — the facet is animated falling into place from outside the
     stone and stopping at its meet point, so the approach to the meet is visible rather than instant.
  Granularity 3 is the interesting one: it shows the meet being *arrived at*, which is the thing the game's
  cutting mechanic (**F8**) is built around — the needle reading zero as mast height converges — so this
  doubles as an early look at that idea without any game machinery.
  **All three ship in this build, with tier-at-a-time as the default** — it is the fastest way to review a
  design being authored. They are one mechanism at three settings: the progressive cut is the general case,
  disabling its animation gives granularity 2, and grouping a tier's facets gives granularity 1.
  **Facets within a tier play in ascending index order**, and a progressive cut starts with the plane just
  touching the stone and moves inward to its solved depth.
- **U5** — **A validation failure is shown in both the tier table and the viewport**: the offending row is
  marked with its reason, and the geometry involved is highlighted in 3D — the vertex that isn't really a
  vertex, the facets that miss each other. "These three facets don't meet at a point" is a spatial claim,
  and showing the gap is the difference between knowing a row is wrong and knowing why. Rejected: table-only
  marking, and an Xcode-style separate problems list. Failures to report: a forward reference, a named vertex
  the facets don't pass through, a facet count that doesn't match the sheet's declared count, a design that
  doesn't close (**I5**), duplicate planes from the symmetry generator (**I2**), and a row the format cannot
  express (**I13**).
- **U6** — **Selecting a tier in the table highlights that tier's facets in the main view** — a colour
  change **and** an outline drawn on them. This is the general link between the table and the
  viewport, not just a validation behaviour. It does not move the camera and does not change the scrubber
  (**U3**): selection highlights, it never re-stages the view.
- **U7** — **Opaque flat per-facet shading with facet edges drawn, plus an opacity slider whose far end is
  a wireframe.** Flat shading per facet is required so every facet reads as its own plane — they are click
  targets (**U1**) — and because smooth shading blurs adjacent facets at similar angles, which the spike
  already warns of (`Geometry.swift:63`: pavilion mains and lower girdle halves smear into one surface when
  normals are blended). The slider is not a toggle: the owner's use for it is **checking that pavilion
  facets line up with crown facets**, which needs intermediate opacity, and at full transparency the drawn
  edges alone leave a wireframe. Edges are therefore always drawn and only the fill fades.
  **Uncut rough is matte and desaturated; cut facets are a neutral light grey.** The two must be
  distinguishable at a glance, since rough retention is legitimate (**I4**) and so is not signalled by
  anything else.
- **U8** — **Labels appear on the selected tier and on facets being picked for a meet, with a toggle to
  show all of them.** Always-on labels are fine on a 57-facet brilliant and unreadable on the 139-facet
  `Kiev Triangle`, which is in the success set (**S3**). A label is a **tier name** (`P1`, `C1`, `G1`, `T`),
  since that is what the format names and what a meet references; rough surfaces use their **I9** names.
  **Hover shows tier name plus index**, that pair being what identifies a single facet.
- **U9** — **A new document shows the rough in the viewport, an empty tier table, and an inspector panel
  carrying the header fields** (`name`, wheel, `ri`, `designer`, `notes`). The wheel field is the design's
  default, inherited by new tiers and overridable per tier (**I20**). Default wheel is **96**.
  `ri` has no effect anywhere in this tool — nothing here refracts — and is authored solely to be carried
  to the game.
- **U10** — **Accessibility and input: pointer and keyboard on macOS, no further constraints.** The project
  states none, and this is a Mac-only tool with no touch target (**iPad is the game's concern, not this
  tool's**).

## ADR candidates

- **The geometry kernel is production code in its own module, with the GUI disposable** (**S6**) —
  hard to reverse (it sets the project's source-tree shape, test regime and module boundary before
  any game code exists), surprising without context (the project's only prior code is an explicitly
  throwaway spike, so "this one isn't" needs saying), and a real trade-off (up-front test and
  boundary cost against writing the solver once). `a-create-plan` writes it.

- **The authoring format's on-disk shape is decided: JSON, with a design state and a per-tier wheel**
  (**I19**, **I20**, plus a serialization change made after this exploration closed). Passes all three
  tests: hard to reverse once design files and the kernel's `Codable` types exist; surprising without
  context, since both this document and the map's **T3** describe a *tabular* format hand-authored in a
  text editor or spreadsheet; and a real trade-off — hand-authorability and the ability to load the
  half-finished tables in `design-authoring-format.md` are given up in exchange for typed decode, no
  bespoke parser, and optional fields instead of permanently blank columns. `a-create-plan` writes it.

  **Scope note — this candidate was widened after closing.** As written at closing it covered only the
  two new fields. `design-authoring-format.md` has since changed considerably further, with the owner's
  explicit approval each time: JSON serialization, a tagged-union `meet` object, exactly-three-facet
  vertices identified by tier *and* index, meets as cutting-time rather than finished-stone claims, the
  `d = max(n · p)` rule for a tier's depth, tier order as data that must never be normalised, and three
  previously-open items closed (`level girdle` collapses into form 5; `SIZE` is the unit rather than a
  dimension; girdle width computed from the solved outline). One ADR covering the file's shape is the
  right granularity — splitting the fields from the serialization would produce two ADRs that must be
  read together to know what a design file looks like. The semantic clarifications are corrections and
  consequences rather than trade-offs, so they belong in the format document, not in an ADR.

  **Two sections of this exploration now read stale as a result**, and the plan should not be built
  from them unamended: **S4**'s stated consequence that the format document's own half-finished tables
  can be loaded and finished in the tool is void under JSON; and **S9**'s guardrail 4, which permits
  format edits only via the **I19** and **I20** tasks, describes a constraint the format has already
  moved past. The guardrail's *intent* — that the format does not change without the owner's say —
  held throughout.

## Open — queued, in ask order

- *(empty — the interview is complete)*

**No tickets were filed for the items below.** All three were offered at closing and the owner declined:
they would rather wait until the thing is in front of them and file then. Recorded here so the record is
honest about it, not because a ticket is pending.

- **Left unresolved:** the format's **outcome-condition meet** ("cut so these edges are equal length").
  Narrower than it first appeared: in this tool the author slides until the condition is visibly satisfied
  and the row becomes an ordinary percentage between two named vertices (**I12**), so the design *is*
  authorable and the format needs no new form. What is lost is **intent** — a later reader sees
  "47.3% between X and Y" and cannot tell the design demanded equal edges rather than that number. The open
  questions are whether the format should record the condition alongside the position, and whether the tool
  should measure the edges and say when they match. Nothing is blocked either way.
- **Left unresolved:** the format's **dial-gauge depth reading** (`Tumbuka Fulu` P8,
  `design-authoring-format.md:198`) — a gauge reading is not a plane offset, since two tiers at different
  mast angles reading the same on the dial sit at different distances from centre. Refused loudly by
  **I13**, not designed.
- **Left unresolved:** **per-job rough retention in the game** — see Notes. Out of scope here, wanted later.

## Notes

- **In the game, rough retention belongs to the job, not the design file.** The owner's case: on a
  given job the player may cut away more rough than the girdle needed, leaving a stone smaller than it
  could have been, and the payout needs the exact percentage of the rough that ended up in the finished
  stone. That is per-job state, and it is a different measure from the map's **F5**, which scores
  deviation from a required size rather than material used. Out of scope here (**I8** covers this tool),
  but it should not be lost.
- The map's **T7** wants a new spike to choose the interactive render technique (rasterized
  solid/wireframe vs. real-time environment-map refraction). This app's solid-only rendering
  overlaps that question and may answer part of it as a by-product.
