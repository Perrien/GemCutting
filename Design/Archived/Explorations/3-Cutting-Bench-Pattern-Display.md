# 3 · Cutting Bench Pattern Display — Exploration

Status: **CLOSED 2026-08-23**
Started: 2026-08-22 · via /a-explore · split from `Cutting-Bench-App` on 2026-08-23
IDs: **S** = scope · **I** = implementation · **U** = UI/UX

The app reads a pattern and shows it: the solved stone drawn in the viewport, the tier table filled in,
the metrics, the findings, playback tier by tier and facet by facet, and the light readouts. **Nothing
is edited and nothing is written in this slice** — that is `4-Cutting-Bench-Authoring`.

One of five explorations split from `Cutting-Bench-App`, one per plan. Siblings:
`1-Cutting-Bench-Kernel-Changes`, `2-Cutting-Bench-App-Shell`, `4-Cutting-Bench-Authoring`,
`5-Cutting-Bench-Angle-Tuning`.

## Grounding

What exists today, anchors re-verified 2026-08-23:

- **Geometry a renderer can consume already exists**: `Polytope.swift:11`
  (`public var facets: [Int: [Int]]`) — one polygon per plane, vertex indices wound counter-clockwise
  about the plane normal — with `Solver.swift:29`
  (`public var planeOwner: [Int: (tier: String, index: Int)]`) mapping every plane back to the tier and
  index stop that cut it. **Facet picking and per-facet labelling need no new geometry work.**
- **`intersectHalfSpaces` is public and brute force**: `Polytope.swift:47`. It walks every triple of
  planes with a containment test per candidate, so it scales as about **planes⁴** — which is why one
  139-plane solve takes **0.60 s**. `Polytope.swift:67` (`guard onPlane.count >= 3 else { continue }`)
  drops any plane with fewer than three vertices on it.
- **Closure is a `Finding` the kernel computes**: `Validation.swift:24` (`case doesNotClose(tier:
  String?)`).
- **A tier can legitimately contribute no facets**: `Validation.swift:34`
  (`case tierContributesNoFacets`) — a tier cut only to establish an intermediate point another tier
  then cuts to.
- **`validate` already accepts a declared facet count and has never had a caller**:
  `Validation.swift:61`
  (`public func validate(_ pattern: Pattern, _ solution: Solution, declaredFacetCount: Int?) -> Report`);
  `facetsolve` passes `nil`.
- **Facet count is a plain count of the solid's facets**: `Metrics.swift:81`
  (`facetCount: solution.polytope.facets.count`), with `Metrics.facetsPerTier` giving the per-tier
  split.
- **A meet is a cutting-time claim**: `design-authoring-format.md:26`, which is why the facets a meet may
  name are those present when that tier is cut.
- **Index stops are not stored in ascending order.** `Novice Ash-er`'s read `12 24 36 48 60 72 84 0`.
  **Tier order is data and must never be normalised**: `design-authoring-format.md:451`.
- **The girdle band is sized from the width**: `Solver.swift:243`
  (`return sin(radians(spec.angle)) + normals[0].z * girdleTargetFraction * extent.width`).
- **A measured partial solve**, from running the built `facetsolve` on truncated copies of
  `Pattern-Easy-Octagon.json`: the girdle tier alone yields **0 facets**, because eight vertical planes
  are mutually parallel about the axis and no triple meets at a point; girdle plus the first pavilion
  tier yields **8 facets, all of them the pavilion's**, the girdle planes contributing none because an
  open-topped solid gives each only two vertices. **So a pattern's own planes render a floating pavilion
  cone with no girdle and no top until something caps the solid.**
- **Validation's named-point check is the expensive half**: on a generated 139-plane pattern it costs
  **1.65 s** against **0.60 s** for the whole solve.

## Inherited

From **`1-Cutting-Bench-Kernel-Changes`**, which must land first:

- The **non-throwing partial solve** — the tiers it placed plus the failure that stopped it.
- **`intermediateSolid(before:of:)` and `planes(of:)` made public**, which is how any prefix of the
  solved planes is built.
- **Validation split three ways** — structural / per-tier cacheable / whole-solid — with tier *k*'s
  per-tier result proven to depend only on the tiers before *k*.
- **`T/W` in `Metrics`**, the **girdle target as a header field** (absent meaning `0.04`), **per-tier
  `instructions`**, **width and length assigned by size** so `L/W` ≥ 1, and the **ray-trace entry point**
  taking a solid, an `ri`, a point and a direction.

From **`2-Cutting-Bench-App-Shell`**:

- The **document app**, the **Metal viewport** with flat per-facet shading and always-drawn edges, **free
  orbit with face-up and face-down snaps**, the **opacity control**, the **rim index ring**, the **window
  layout** with tier table, inspector, scrubber and status strip in place, and **stock native macOS as
  the visual answer** with no up-front specification.
- The **rough prism** — eighteen half-spaces at radius 1.5 and `z` from −2.0 to +1.0, named `P`, `C` and
  `G1`…`G16`, with the app owning that plane-to-name map.

## Tickets folded in

None. `Chore-Validation-Rebuilds-The-Solid-Once-Per-Tier` is answered by the caching in
`4-Cutting-Bench-Authoring` and closed there; this slice consumes the three-way split without needing the
cache, because nothing here edits.

## Scope & purpose

- **S1** — **The app opens and steps through existing patterns, finished or in progress.** It reads the
  four already authored and anything authored later. **Playback runs tier by tier and facet by facet.**
  **Viewing a pattern shows each tier's `instructions`**, which is what makes the field worth having
  rather than merely storable.
  **Done means:** all four authored patterns open and draw correctly; every metric shown agrees with
  `facetsolve --json` on the same file; playback steps through a pattern at both granularities; a ray
  probe traces and reports.

- **S2** — **Light feedback is two things: a critical-angle check on every pavilion tier, and a clickable
  single-ray probe.** Both exist because tangent ratio is an operation whose whole purpose is refractive
  index (see `Design/Glossary.md`), and `ri` is authored in every pattern yet does nothing anywhere in
  this tool today — so an author tuning angles is doing in their head the one calculation the tool holds
  all the inputs for.
  **The critical-angle check** is `asin(1/ri)` compared against each pavilion tier's angle, marking any
  tier shallow enough to leak. It is arithmetic, not rendering, so the no-render non-goal does not bar
  it, and it is the thing a pavilion rescale most easily gets wrong. **Honest about its limit: it says
  when light definitely leaks, never that performance is good.**
  **The ray probe**: click anywhere on the crown or table and a single ray is traced entering vertically
  at that point, refracting in, reflecting off the pavilion — ideally twice — and leaving through the
  crown again. Sampling a few points per facet type is how windowing is found and then tuned out.
  Rejected: a ray-traced brilliance or light-return metric over the whole stone, which needs refraction
  machinery the non-goals exclude. The probe gets the diagnostic value out of a fraction of the work.
  **Entry is vertical, downward** — that is how windowing is judged, looking straight down at a face-up
  stone. A table tier at `0.00°` therefore takes a ray at zero incidence which passes straight in
  undeviated, the classic table test; a crown facet refracts the ray toward its normal on entry, which is
  expected rather than a special case.

### Non-goals

- **No editing of any kind, and no saving.** No tier added, deleted, reordered or altered; no meet built
  by clicking; no `state` switch. All of that is `4-Cutting-Bench-Authoring`.
- **No animated facet arrival** (**U5**) — deferred to the ticket
  `Chore-Incremental-Half-Space-Clipper`, which is the ticket that makes it affordable.
- **No angle tuning and no rotation** — `5-Cutting-Bench-Angle-Tuning`.
- **No yield or rough-retention readout, no volume code, no pattern browser, no thumbnails, no printing,
  no GemCad interop, no photorealistic render, nothing for iPad.** Carried forward unchanged.

## Implementation

- **I1** — **Two intersections: one for the eye, one for the truth — and the rough is scaffolding, not a
  bounding box.** The app builds what it draws by calling `intersectHalfSpaces` itself
  (`Polytope.swift:47`); the kernel's own `Solution.polytope` stays rough-free and remains what
  `validate` and `metrics` see.
  **The rough's eighteen half-spaces are included only while the pattern's own planes fail to bound a
  solid, and are dropped the moment it closes.** Otherwise the prism would clip the stone, and a
  tangent-ratio rescale that deepens a pavilion would have its culet cut off by a preform that is no
  longer there. Once a pattern closes, no rough survives anyway, so the rough contributes nothing and
  removing it changes nothing — **the transition is invisible**, because at closure the stone is well
  inside the prism and the intersection already equals the pattern's own solid. If a later edit re-opens
  the solid, the rough returns. **The test is one the kernel already computes**: `Validation.swift:24`
  (`case doesNotClose(tier: String?)`).
  **Clipping by the rough before closure is correct, not an error.** A pavilion tier cut steeper than the
  prism is deep genuinely cannot be cut from that rough, so seeing the prism's `P` cap flatten the culet
  is the truth rather than an artifact, and nothing needs reporting.
  **The scaffolding rule removes the cost that including the rough would otherwise add**: a closed
  139-plane pattern drops the eighteen, so the display pass and the kernel's own hull see the same plane
  count, and the eighteen are only present while a pattern is incomplete and therefore small.
  Rejected: keeping the rough always, which clips tuned stones; and drawing the prism as a separate solid
  with no boolean, which shows a cone floating inside a prism rather than material removed.

- **I2** — **The app renders as far as the partial solve got, and marks the tier that stopped it.** A
  half-solving pattern is a normal state, not an error screen. **The app truncates at the first tier
  lacking a resolvable meet rather than skipping it** — a later tier's depth genuinely depends on the
  earlier ones, so omitting a middle tier would make every tier after it fail on references to facets
  that were never placed.
  Rejected: retrying successively shorter prefixes until one solves — up to one solve per tier, each
  cubic in plane count, against a whole solve already costing 0.60 s at 139 planes, so it is the one
  option a 139-facet pattern breaks. Also rejected: showing only the rough and an error until the pattern
  solves whole, which blinds the author exactly when the rough exists to prevent that.

- **I3** — **The scrubber intersects a prefix of the already-solved planes; step geometry is precomputed
  lazily when playback is entered, cached, and never recomputed per edit.** No re-solve is needed for a
  prefix, because each tier's depth depends only on the tiers before it — so a prefix solve and the full
  solve produce identical depths, and stepping is purely a matter of which half-spaces are intersected.
  **The scaffolding rule applies per step:** the rough is included while that step's planes fail to bound
  a solid, and drops out once they do.
  **Facet-by-facet playback steps in ascending index order, which is not file order.** `Novice Ash-er`'s
  stops read `12 24 36 48 60 72 84 0`. Order does not affect geometry — every facet of a tier shares one
  depth — so this is display only. **Negative requirement: the app never sorts `indices` in the file.**
  Doing so would rewrite `Novice Ash-er`.
  **The cost, measured from the shipped solve:** `intersectHalfSpaces` scales as about planes⁴. Summed
  over every facet-granularity step that is roughly **17 s** of hull work for a 139-facet pattern, while
  the four authored patterns at 37–73 facets come in well under a second. So this bites only at
  139-facet scale, and the answer is **one honest wait on entering playback with progress shown**, not a
  slower editor.
  Rejected: computing steps on demand and caching as visited, which makes the first pass through a large
  pattern lumpy; and precomputing on every solve, which would pay the whole cost per keystroke.
  **The proper fix is deferred to a ticket, not built here:** `Chore-Incremental-Half-Space-Clipper`,
  which would clip the previous step's polytope by one plane and make each step roughly linear.

- **I4** — **The probe traces the pattern's own solid, and is offered only when that solid closes.** A ray
  bounces off whatever surfaces are actually there, so tracing the display solid — which carries the
  rough's eighteen half-spaces (**I1**) — would report on a stone that does not exist while looking
  authoritative. Being unavailable for most of authoring is not a cost: tuning is a finished-stone
  activity by definition, and closure is already a `Finding` the kernel computes, so the precondition is
  free. **When it is unavailable the reason is stated** rather than the control silently doing nothing.
  Rejected: tracing the display solid, the same failure **I1** rejected — a meaningless answer that looks
  like a real one; and switching between the two depending on closure, which makes the author work out
  which mode they are in.

- **I5** — **The declared facet count is typed in at transcription time and persists nowhere, and the
  count is always reported split as `64 + 16 girdle = 80`.** The check is not testing the solver — the
  solver is right — it tests the *transcription*, and it works because a sheet's printed headline count
  is independent data from its printed tier table, so the two are two readings of one document
  triangulated. **It has caught exactly that here:** `design-authoring-format.md:386` records that
  `Rand's` tier **G** (25.84, `meet C-B-C`) "was missing entirely; with it the count is exactly the
  declared 53" — a whole tier dropped, two facets of 53, on a stone that still closed because the
  neighbouring facets grew to fill the gap.
  **It is session state, not document data**, because the value only exists while transcribing from a
  printed sheet: a pattern invented from scratch has no declared count, and once a pattern is verified
  the check never fires again. A permanent header field would carry a one-time claim forever. **Needs no
  format change and no kernel change** — `validate` already takes `declaredFacetCount: Int?`.
  **The split reporting is the point, not a nicety.** Sheets differ on whether the headline figure
  includes the girdle band — the barion example declares "64 facets + 16 facets on girdle = 80" — while
  `Metrics.swift:81` counts every facet the solid has. Reporting a bare `80` against a sheet that says
  `64` reads as a mismatch when it is agreement. The girdle share is the facets belonging to tiers whose
  `part` is `gdl`, available from `Metrics.facetsPerTier`. **A knife-edge girdle has no girdle facets, so
  the girdle term is omitted rather than shown as zero.**

## UI / UX

- **U1** — **Structural findings appear as you type; geometric ones arrive after a pause and say when
  they are in flight.** The cheap half of validation runs immediately, so transcription mistakes — a
  forward reference, a facet that doesn't exist, three planes that pin nothing — surface at once. The
  expensive half runs after a short quiet period, cancellable, off the main thread, with the status strip
  saying a check is running.
  **While a deferred check is in flight the previous result stays visible and is marked stale, and stale
  findings are never presented as current.**
  **Presentation is a one-line status strip** — "no findings" or "3 findings" — which opens to detail,
  **the offending tier row marked, and the geometry involved highlighted in 3D**. Never a separate
  Xcode-style problems list.
  Rejected: running everything on every change, fine at 37–73 facets and unusable at 139; and a Validate
  button, which makes the tool's whole purpose an opt-in step.
  **In this slice the trigger is opening or scrubbing a pattern rather than typing**, since nothing is
  edited yet; the keystroke-driven timing and the per-tier cache belong to `4-Cutting-Bench-Authoring`.

- **U2** — **Metrics are split by when they are needed, inside the one inspector section.** Always
  visible: the facet count in the split form `64 + 16 girdle = 80` (**I5**), the symmetry, and `L/W` —
  the three that move as you author and that get glanced at constantly. Below them, the full proportion
  table: `P/W`, `C/W`, `H/W`, `T/W`, girdle thickness and its percentage of width, width, length, and
  whether the culet is a point. Those are what you read when a tier lands or after tuning, and the
  inspector is already collapsible.
  Rejected: one flat list of everything, most of which is looked at once per pattern; and grouping by what
  a sheet declares versus what only the solve knows, which sounds tidy but moves the same number between
  groups depending on what a given sheet happens to print.
  **Metrics stay in their own card and never join the pattern-header card**, which the owner's sketch has
  them doing. Everything in the header card is authored and editable; every metric is computed and
  read-only, and `Metrics.swift:3` is explicit that none of it is read from a pattern's `notes`. Sharing
  a card would make computed values read as fields. **The sketch's four-proportion selection is not the
  always-visible set** either: facet count and symmetry move constantly while authoring and are absent
  from it.
  **Two readouts live elsewhere, deliberately.** The **critical-angle marking** goes on the tier rows,
  because it is per tier and about one tier being too shallow. The **ray probe's per-bounce incidence
  readout** belongs with the probe, because it is transient and tied to one traced path rather than to the
  stone.

- **U3** — **The tier table carries a wheel column showing the *effective* gear — greyed when inherited
  from the header, solid when overridden.** A stop number is meaningless without its gear, so the wheel
  is what makes the `indices` column legible and belongs beside it.
  Rejected: a blank cell when inherited, mirroring the file where the field is genuinely absent — it saves
  ink at the cost of the one piece of context the neighbouring column needs; and putting the gear in a
  per-tier inspector, which separates it from the stops it governs.
  **The popup that changes a gear belongs to `4-Cutting-Bench-Authoring`**; this slice displays the
  effective value only.

- **U4** — **Every point a meet names is drawn as a lettered, coloured dot, and the tier table shows the
  same dots beside the same points, so viewport and table are read together.** A `fraction` shows three:
  **A** at `from`, **B** at `to`, and the anchored point between them in its own colour; a plain `vertex`
  shows one. The tier table's meet cell lists each named point as its dot plus the facet triple, and the
  anchored point's dot carries the percentage.
  **Colour is never the only distinction: each dot carries its letter as well**, so the correspondence
  holds for a colour-blind reader and in a screenshot. This is the same table-and-viewport pairing the
  status strip uses for findings — mark the row and highlight the geometry.
  **Editing the percentage belongs to `4-Cutting-Bench-Authoring`**; here the dots and the number are
  read-only.

- **U5** — **Playback has two granularities, tier and facet, and no animated arrival.** A facet sweeping
  in to its meet needs a solid per frame where facet-granularity needs one, against a hull that costs
  roughly planes⁴ (**I3**), so it is impractical until the ticket
  `Chore-Incremental-Half-Space-Clipper` lands — which is the animation that ticket was filed for. **It
  is deferred to that ticket rather than left as an open question here**, and nothing about authoring or
  verifying wants it: the sweep says nothing about the pattern that the arrived facet does not.
  Rejected: enabling it only for small patterns, which puts a threshold in the app that has to be
  explained; and animating the moving plane's cross-section against a fixed solid, which is nearly free
  and reads as the lap approaching rather than as material being removed — honest, but not the animation
  the game wants and not worth its own mechanism here.

- **U6** — **The intermediate solid — the stone as it stands before a given tier — is a display mode this
  slice builds, because the scrubber already needs it.** **I3** establishes that any prefix can be built
  from the solved planes, so it costs nothing new. It is not a bowl: before a pattern closes the rough is
  in the display (**I1**), so the intermediate is the preform with the tiers so far cut into it.
  **`4-Cutting-Bench-Authoring` reuses this exact mode while a meet is being picked**, with a wireframe
  ghost of the finished stone over it; that ghost and the picking rules are its decisions, not this
  slice's.

## ADR candidates

None. The scaffolding rule (**I1**) is the closest candidate — a real trade-off, and surprising — but it
is cheap to reverse, being one predicate over which planes enter a display-only intersection, so it fails
the hard-to-reverse test.

## Open — queued, in ask order

Empty. Nothing in this slice is unresolved.

## Notes

- **The rough is not optional for display, and the reason is measured rather than argued.** A pattern's
  own planes render a floating pavilion cone with no girdle and no top until something caps the solid —
  0 facets for a girdle tier alone, 8 for girdle plus first pavilion tier, all of them the pavilion's.
- **The 17 s figure is what the deferred clipper ticket is worth.** It is the whole cost of
  facet-granularity precompute at 139 facets, and it is the only place in this slice where a real pattern
  makes the user wait.
