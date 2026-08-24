# 2 · Cutting Bench App Shell — Exploration

Status: **CLOSED 2026-08-23**
Started: 2026-08-22 · via /a-explore · split from `Cutting-Bench-App` on 2026-08-23
IDs: **S** = scope · **I** = implementation · **U** = UI/UX

The `CuttingBench/` Mac app existing at all: a document-based app, a Metal viewport, the rough stone
drawn in it with every surface named, and the window layout the four sibling slices fill in. **No
pattern geometry is drawn in this slice** — the stone comes next, in
`3-Cutting-Bench-Pattern-Display`.

One of five explorations split from `Cutting-Bench-App`, one per plan. Siblings:
`1-Cutting-Bench-Kernel-Changes`, `3-Cutting-Bench-Pattern-Display`, `4-Cutting-Bench-Authoring`,
`5-Cutting-Bench-Angle-Tuning`.

## Grounding

What exists today, anchors re-verified 2026-08-23:

- **No app target exists yet.** `Execution-Protocol.md:58` names the deliverable as
  `Kernel/` — SwiftPM package, library `FacetKernel`, with *"`CuttingBench/` joins it in the second
  plan"*.
- **`project.pbxproj` is owner-run.** `Execution-Protocol.md:87` treats hand-editing it as a corruption
  risk producing unreviewable diffs, and forbids touching signing, capabilities, entitlements or the
  bundle identifier.
- **The half-space intersection this slice needs is already public**: `Polytope.swift:47`
  (`public func intersectHalfSpaces(_ planes: [Plane], tolerance: Double = 1e-7) -> Polytope`), with
  `Polytope.swift:11` (`public var facets: [Int: [Int]]`) giving one polygon per plane, vertex indices
  wound counter-clockwise about the plane normal. **So no new geometry work is needed to draw a solid
  or to hit-test it.**
- **Plane construction is public**: `Plane.swift:34` (`public func planeNormal(`).
- **The pattern-side plane-to-owner map already exists**, and is the model for the app's own:
  `Solver.swift:29` (`public var planeOwner: [Int: (tier: String, index: Int)]`).
- **Closure is a `Finding` the kernel already computes**: `Validation.swift:24`
  (`case doesNotClose(tier: String?)`).
- **Decoding a pattern works against today's kernel** — `Pattern.swift:81`
  (`public struct Pattern: Decodable, Sendable`) — so opening a file needs nothing from
  `1-Cutting-Bench-Kernel-Changes`.
- **Four patterns are authored** in `Design/Patterns/`: `Pattern-Easy-Octagon.json`,
  `Pattern-Novice-Ash-er.json`, `Pattern-Rands-Cut-Corner-Rectangle.json`,
  `Pattern-Standard-Round-Brilliant.json`. Their filenames are named as external ground truth by the
  guardrails, via `RegressionTests.swift:22` and `PatternDecodingTests.swift`.
- **A temporary point can go deeper than the final culet**, which sizes the rough: `Novice Ash-er`'s
  `P1` is `pav 50.00` on `tcp`, so its point forms at `tan(50°) = 1.19175` before `P2` and `P3` cut it
  back to `1.00717` — the same figure is stated independently at `design-authoring-format.md:150`.
- **`Design/Prototypes/render-proof/` is read-only** (`Execution-Protocol.md` guardrails). It is the
  record of the render decision; the one thing it had to give — the plane derivation — already shipped
  as `Plane.swift:34`.
- **No third-party dependencies** — Swift and the standard library only.
- **The owner's layout sketch exists**: `Design/Explorations/CB UI.png`, exported from
  `Design/Patterns/Cutting Bench UI.key`.

## Inherited

- **Nothing from `1-Cutting-Bench-Kernel-Changes`.** Everything this slice needs is public today. The
  shell can therefore be built before, after or alongside the kernel work.
- **This slice owns the viewport, the camera and the rough**, and the three later slices draw into it.
  What they add is listed in each of them, not here.

## Tickets folded in

None. No open ticket touches this slice.

## Scope & purpose

- **S1** — **A standard Mac document app.** Document-based is taken for the file handling rather than
  for windows: Open, Save, Save As, revert, recent files, the dirty indicator and a per-document undo
  manager all come from the framework, and the app needs every one of them. **Multiple open documents
  therefore fall out for free** rather than being scope — per-document state is what a document *is*.
  Rejected: a single-window app, where Save, Open and undo are hand-rolled and multiple documents later
  is a rework.
  **Done means:** the app launches, opens a pattern file through the Open dialog, shows the rough prism
  in a draggable 3D viewport with the window layout in place, and a click on a rough facet reports that
  facet's name.

- **S2** — **The rough stone is in this build, and there is no yield readout and no volume code.** The
  rough is a 16-sided prism on the axis with named facets — `P` for the bottom cap, `C` for the top,
  `G1`…`G16` for the walls — its shape and dimensions a build constant, present before the first tier.
  It is load-bearing twice: **every surface on the stone carries a name at all times**, so a cut is
  always specifiable as index, angle and three named facets with no moment where there is nothing to
  click; and a half-authored pattern's own planes usually do not bound a solid — cut the pavilion mains
  and nothing limits the stone upward — so without it there is frequently nothing to render.
  Rejected: a rough drawn only as a backdrop whose facets cannot be named, which breaks the first
  property; and no rough at all, which authors the early tiers blind.
  **With no yield, the rough is purely a naming and display device** — nothing measures it, so its
  dimensions have no consequence beyond being large enough to contain a solved pattern.

- **S3** — **Rough retention (yield) belongs to the game, not to this tool.** The two numbers are
  different and only one of them is available here. **What this tool could compute is a property of the
  pattern** — the best it could ever do in a fixed rough. **What the game's payout needs is what the
  cutter actually achieved**, where the girdle was cut smaller than it needed to be and the stone came
  out smaller than it could have: that needs a target size and an achieved girdle placement, which is
  per-job state, and this tool has no player and no job. The second is not a retrofit of the first, so
  building the first here would produce a number that looks like the game's and isn't.
  Also rejected: a size slider below the best-fit size with a yield readout tracking it, which does
  model that case and is small, but is still not the game's number and adds a size concept to a tool
  whose patterns are scale-invariant.
  **Nothing is at risk in deferring it, and this was checked rather than assumed.** What the game will
  need is a **primitive** — the volume of a polytope, and the solid scaled by some factor. It needs no
  solver change and no new solver output: the normalisation is baked into the solve rather than applied
  as a rescaling pass (`Solver.swift:226` — `return 1` for `case .size`), so there is no scale factor to
  retrieve and none to store. Its inputs are already present in `Polytope.vertices`, and a solid's
  volume is each polygon in `Polytope.facets` fan-triangulated into tetrahedra, the polygons already
  wound counter-clockwise.

### Non-goals

- **No pattern geometry drawn** — that is `3-Cutting-Bench-Pattern-Display`. This slice draws the rough.
- **No editing, no saving, no picking for meets.** Opening and displaying only.
- **No pattern browser and no thumbnails.** Four patterns through a file dialog is not a problem, and
  thumbnails would mean rendering patterns nobody has opened. **A ticket was offered for the browser and
  declined**; worth revisiting when the catalog is 53 patterns rather than four.
- **No yield or rough-retention readout, and no volume code** (**S3**).
- **No rough retention, no printing and no PDF cutting sheet.** Printing is the bench-tool direction the
  archived exploration named and declined — the moment there is printing, this is a Mac GemCad and its
  scope is set by faceters rather than by the game.
- **No GemCad interop** — no reading or writing `.gem`/`.asc`. The corpus is a 53-design PDF, not GemCad
  files.
- Carried forward from the archived exploration `Cutting-Bench`, unchanged: **no photorealistic or final
  render** (solid rendering only), **no game mechanics**, **no fractional index positions**, and
  **nothing for iPad**.

## Implementation

- **I1** — **Metal directly, in an `MTKView`.** Three of this design's decisions are shading decisions —
  flat per-facet fill so every facet reads as its own plane and is a credible click target, edges that
  stay drawn while the fill fades to wireframe, and uncut rough visually distinct from cut facets — and
  the ray probe in `3-Cutting-Bench-Pattern-Display` draws a path *inside* a semi-transparent solid, which
  is a depth-sorting problem worth controlling.
  Rejected: SceneKit, whose real saving is camera orbit and hit-testing — the easy parts — while flat
  per-facet shading plus always-drawn edges plus partial opacity land in the awkward corner of its
  material model, and it is in maintenance rather than active development. Also rejected: RealityKit,
  built around AR scene semantics, no easier on opacity-and-edges, and heavier than a Mac window needs.
  **The render-proof spike has nothing left to give.** It stays where it is — read-only under the
  guardrails, and its deletion is not this work's call — but no further code comes out of it.
  **Two planning consequences.** `project.pbxproj` is owner-run (`Execution-Protocol.md:87`), so
  **creating the `CuttingBench/` Xcode project and target is an owner step, not an agent one**, and the
  plan has to be written that way. And **the deployment target is simply what this machine runs** — the
  tool is Mac-only, personal, and never distributed, so there is no back-compatibility question.

- **I2** — **The app builds what it draws by calling `intersectHalfSpaces` itself**
  (`Polytope.swift:47`, already public), and **the kernel learns nothing about rough at all.** The
  kernel's own `Solution.polytope` stays rough-free and remains what `validate` and `metrics` see.
  Rejected: feeding the rough into the kernel's solve and having everything downstream ignore rough
  planes. It breaks the check that makes this tool a verifier — `design-authoring-format.md:437`
  (`The solid has to close.`) is enforced by requiring every edge to belong to exactly two facets, and a
  rough-capped solid *always* closes, so the check would silently pass for every pattern including the
  ones it exists to catch. Facet count fails the same way, since `Metrics.swift:81` counts
  `solution.polytope.facets` directly.
  Also rejected: drawing the prism as its own solid with no boolean against the pattern — cheapest, but
  nothing gets cut, so it shows a prism with a cone floating inside it rather than a stone with material
  removed, and facet picking is wrong wherever a cut facet should have clipped a rough wall.

- **I3** — **The app owns the plane-to-name mapping for its own eighteen planes**, the way
  `Solution.planeOwner` (`Solver.swift:29`) does for the pattern's. That is what lets a click on rough
  return `P`, `C` or `G1`…`G16`, and what lets uncut rough be shaded differently from cut facets.

- **I4** — **The prism spans radius 1.5 and `z` from −2.0 to +1.0.** It only ever has to contain a stone
  *as authored*, never a tuned one, but "as authored" is wider than the four existing patterns suggest.
  Those measure radius ≤ 1.082, culet ≈ −1.01, table ≈ +0.49 — and they are all either round or
  normalised on their long axis.
  **The radius has a hard floor at the outline's corner radius**, below which the girdle planes never
  reach the walls, so rough survives at the girdle and the stone cannot reach its own size. For a round
  stone that floor is about 1.09. **But nothing in the format says which axis carries the `size` row** —
  only that there is exactly one and that width follows from the meets
  (`design-authoring-format.md:174`). `Rand's Cut Corner Rectangle #1` puts it on the ends, so its
  half-length is 1.0; a design normalised on its *short* axis instead puts its ends out at `L/W`. For a
  barion at `L/W = 1.436` that is radius ≈ 1.45. A snug radius would be betting on a convention the
  format does not enforce.
  **The depth has to clear both deep pavilions and the deepest *intermediate* axial point.** Barions run
  to `P/W = 0.608`, which on a short-axis normalisation puts the culet at −1.216. And intermediates go
  deeper than final culets: `Novice Ash-er`'s `P1` is `pav 50.00` on `tcp`, so its temporary point forms
  at `tan(50°) = 1.19175` before `P2` and `P3` cut it back to `1.00717`
  (`design-authoring-format.md:150`). Clipping either would misrepresent a real cutting sequence.
  Rejected: a snug preform-like prism at radius 1.15 spanning −1.15 to +0.6. It looks more like what a
  preform actually is, and that is the only argument for it; it clips `Novice Ash-er` mid-authoring and
  any elongated design normalised on its short axis. Also rejected: auto-sizing, which buys nothing once
  tuning is excluded and makes named click targets move under the pointer.
  **The prism never needs headroom for tuning**, because the scaffolding rule in
  `3-Cutting-Bench-Pattern-Display` drops the rough the moment a pattern closes, and a tangent-ratio
  rescale only ever applies to a closed pattern.

- **I5** — **Patterns stay `.json`, declared with handler rank `Alternate`, and there is no double-click
  routing.** macOS routes documents by extension and UTI and never by looking inside a file, so nothing
  can distinguish a pattern from any other JSON: double-clicking one opens whatever owns `.json`, and
  the only override is per-file Open With or a Change All that would capture every JSON on the machine.
  **Patterns are opened from inside the app, with the Open dialog defaulting to `Design/Patterns/`** and
  recent files covering the rest.
  Rejected: claiming `public.json` as owner, which sends every JSON file on the machine to this app.
  Also rejected for now: a distinct extension, which is the only thing that *would* give double-click
  routing and would make a pattern self-describing — it means renaming the four authored patterns and
  updating `RegressionTests.swift:22` and `PatternDecodingTests.swift` plus the format document. No
  fixture value would change, but those files are named as external ground truth in the guardrails, so
  the rename is a deliberate decision for later rather than a side effect of this build.

## UI / UX

- **U1** — **The viewport and the tier table are the only permanent pair; everything else lives in one
  collapsible inspector, with the scrubber under the viewport.** Those two are what the author works in
  simultaneously — clicking facets in one, reading and editing meets in the other — so neither can be on
  demand. The inspector carries the pattern header (`name`, `state`, default wheel, `ri`, `designer`,
  `notes`, girdle target), the metrics, the light readouts and the declared-facet-count field, in
  sections.
  **Validation earns prominence without floor space.** A one-line status strip says "no findings" or "3
  findings" and opens the detail; individual findings mark the offending tier row and highlight the
  geometry involved — never a separate Xcode-style problems list.
  Rejected: a permanent validation panel, which is a blank panel holding space most of the time, since
  findings are usually empty; and a single inspector with a segmented picker showing one section at a
  time, which buys viewport area by hiding the tier table — the one surface that cannot be on demand.
  **The starting arrangement is the owner's sketch** (`Design/Explorations/CB UI.png`): viewport
  top-left, the inspector as a right-hand column of stacked cards with the pattern header card first and
  `notes` below it, and the tier table full-width across the bottom with its columns ordered tier, part,
  angle, indices, meet, wheel, instructions. **Where the sketch is silent it is incomplete rather than
  contradicting** — it predates the scrubber and the status strip and shows neither, and both stay
  exactly as fixed here.
  **This slice builds the layout with the tier table, inspector, scrubber and status strip present but
  empty**; what fills each is owned by the later slices.

- **U2** — **There is no up-front visual specification. The app is built to stock native macOS, and the
  look is adjusted in the running app at each plan's owner stop.** System semantic colours, the standard
  inspector-and-table idiom, system type sizes and standard spacing — no bespoke palette, no type scale,
  no spacing scale, no mockups, and no design brief handed to anyone. Chosen because briefing for a
  visual specification was tried and produced nothing usable, and because it was the prerequisite
  blocking this slice and the next.
  **This is safe rather than a shrug, and that is the whole argument for it.** The layout is fixed
  (**U1**), every interaction rule is settled in the sibling slices, and **colour is never load-bearing
  alone** — every colour-coded thing carries a letter or a label as well, so a plain palette costs
  correctness nothing. What was missing was concrete values, and those are exactly what a running app
  supplies for free and a description of one does not.
  **The Metal shader resolves its colours from named system colours at runtime** rather than carrying
  hardcoded sRGB values, so the solid tracks light and dark appearance with everything else. **The roles
  it must keep distinct**, gathered from all five slices: uncut rough against cut facet (**I2**, **I3**),
  a highlighted facet and a selected edge, the **A**, **B** and anchored-point dots, the critical-angle
  mark on a tier row, the stale-findings state, and inherited versus overridden index wheel. Each
  already carries a letter, mark or label, so any set of distinguishable system colours serves.
  **The owner's layout sketch is input, not specification** — it settles the arrangement questions that
  were genuinely open and asserts nothing about colour, type or spacing, which it has none of.
  Rejected: re-briefing harder with a demand for concrete sRGB values, which keeps two plans blocked
  while finding out whether a second pass lands any better; the owner finishing the sketch into a
  written specification, which puts owner time on the critical path; and keeping a specification step
  but moving it after all five plans, which is what adjusting at owner stops already is, with a ceremony
  attached.

- **U3** — **The viewport is 3D and freely draggable, with face-up and face-down snap views alongside
  free orbit, and an opacity control for the solid.** Semi-transparency exists for two unrelated
  reasons: checking that pavilion facets line up with crown facets, and making a traced ray visible
  inside the stone.

- **U4** — **The index stop numbers are drawn around the stone's rim whenever the viewing angle allows,
  so the author can get their bearings.** No 2D plan view and no crown/pavilion switch: the 3D solid is
  what the ray probe, the rough display and two-facet picking all need.
  **The ring fades out as the camera approaches edge-on**, where the rim projects to a line and the
  labels would pile onto each other. It is not restricted to the snap views — those remain the fastest
  way to reach it, not the only one. **The fade threshold is one build constant, tuned during testing
  and not a preference.**
  **The numbers are drawn at the stops the pattern actually uses, labelled with the tier's own wheel**,
  so a tier overriding the wheel reads in its own gear rather than the header's. With no pattern open
  there is no ring.

## ADR candidates

None. The Metal choice (**I1**) was weighed against SceneKit and RealityKit, but it is neither hard to
reverse — the renderer is one view behind a solid-and-planes interface — nor surprising once the shading
requirements are stated, so it fails two of the three tests.

## Open — queued, in ask order

Empty. Nothing in this slice is unresolved.

## Notes

- **The stone drawing in the owner's layout sketch is stock art and specifies nothing about the
  render.** `Design/Patterns/Cutting Bench UI.key` embeds it as
  `Data/round-shapes-gemstone-wireframe-16667118.jpg`, 210×215 px and carrying no index numbers, so the
  ring of stops around it in the exported PNG is the owner's own addition and is the whole of what that
  panel asserts (**U4**). Recorded so nobody re-opens the 3D viewport question on the strength of a
  placeholder a second time.
- **This build is stricter than the game should be, on purpose**, and that starts here: the rough exists
  so every surface has a name, which is a verifier's concern. The game may want to be more forgiving.
- The archived exploration `Cutting-Bench` carries a banner listing four of its own claims that shipped
  code contradicts. Its `U1`–`U10` are reference material, not settled decisions — they were written
  before the kernel existed and before the format became JSON with a tagged-union `meet`.
