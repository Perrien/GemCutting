# GemCutting — Map

Last touched: 2026-08-20 (session 1)
Areas: Vision Sketched · Users Sketched · Features Sketched · Tech Stack Sketched · Architecture Sketched
IDs: **V** = vision · **U** = users · **F** = features · **T** = tech stack · **A** = architecture

## Vision & Problem
- **V1** — A Mac/iPad app: a gemstone-faceting simulator/game where the player cuts a stone by
  following the real faceting process (angle and depth per facet, on an indexing wheel), and the
  payout scales with the design's complexity and the precision of the cut. Given directly as the
  project's seed idea.

## Users & Use Cases
- **U1** — Built for both: real faceters, who get a practice/planning tool, and players with no
  faceting background, who get a satisfying cut-and-payout loop. Neither audience is picked over
  the other; the design has to serve both rather than pick a winner.

## Feature Catalog
### Core Loop
- **F8** — The cutting mechanic. Within one tier ("round"), angle and mast height are set once and
  held fixed; the player only changes index, cutting each facet in that tier to the needle
  (indicator at zero) before advancing to the next index — matching how a tier shares one depth
  (T3/`design-authoring-format.md`). Pressure is controlled via a vertical slider: more pressure
  cuts faster but risks overcutting past the target. The needle/dial indicator shows the live
  deviation between the *actual* contact angle and the target angle — because the stone rests on
  the lap while cutting, the true contact angle keeps changing as material is removed; it reads
  shallow before the target, zero at it, and an overcut amount past it. Mast height is nudged
  between passes (not an absolute dial) until the target angle and the meet point (A5) are reached
  together — the owner's "challenge for the user." **Confirmed as the real, non-simplified
  mechanic** for actual play; an automated/skip mode exists only for testing purposes, not the
  shipped player experience. Multi-grit finishing (A7) is treated the same way — inferred, not
  explicitly re-confirmed, that it isn't simplified away for MVP either, since "each facet is
  manual" was stated without carving out an exception for grit stage. Tier: **MVP**. The gap
  between the player's actually-achieved facet and A5's solved target is exactly what F5's
  precision scoring measures.
- **F9** — Overcut recovery. If a facet is overcut, the player either accepts the resulting
  meetpoint error on that facet (worse F5 score) or recuts the rest of that facet group (e.g., the
  whole crown) to the new, deeper reference depth the overcut established. Mistakes cascade rather
  than staying isolated to one facet. Outright ruining the stone (failing the Contract Job because
  there's no longer enough material to hit the size spec) is possible but unlikely — it takes a
  massive overcut. The ordinary consequence is a size/weight score penalty (F5), not job failure.

### Economy
- **F10** — The player earns money (payout, F1/F2/F5) and spends it on rough stones for Free-Cut
  (F2): higher-quality rough costs more upfront but pays out more once successfully cut — an
  investment/risk choice, not just a cosmetic pick.
- **F12** — Insurance on Contract Jobs (F1). A customer with a valuable rough stone may want it
  insured: the customer pays a premium, raising that job's payout, but if the player ruins or
  heavily damages the stone (F9's rare failure case), they have to reimburse the customer for the
  loss. Gives F9's rare "ruin" outcome a real economic consequence rather than just a bad score.
  Resolved: no player-facing negotiation UI. Insurance presence is decided when the job is
  generated, weighted probabilistically — more likely on higher-paying jobs, and some customers
  demand it while others don't (a per-customer trait, not purely a function of job value). Exact
  weights are a later balancing task, not a design decision needed now.
- **F13** — Job board: a limited number of Contract Jobs (F1) are available at once; unclaimed
  jobs can expire, and the board refreshes over time. Tier: **MVP** — F1 needs a source of jobs to
  function at all.

### Modes
- **F1** — Contract Jobs: the player is supplied a rough stone, a design, and exact size
  requirements; payout is scored against how precisely those requirements are hit. Pays more
  overall than Free-Cut, with a steeper payout curve — precision moves the payout more sharply.
  Tier: **MVP** — ships first, validates the payout/precision loop.
  Serves: the precision-driven / real-faceter side of U1.
- **F2** — Free-Cut: the player cuts whatever they want, to whatever size or design — no imposed
  requirements. Absorbs what was sketched as "Zen Mode" (F3, now merged in — the owner judged the
  two "basically the same," and prefers the term Free-Cut). Pays less overall than Contract Jobs,
  with a flatter payout curve — precision moves the payout less. The rough being cut is bought by
  the player (see F10), not supplied — unlike Contract Jobs, where the customer supplies it. Tier:
  **Later** — not v0.1, but the owner was explicit this is important and must stay in the plan, not
  slip to Deferred. Serves: the casual/creative side of U1.

### Progression
- **F4** — Advanced techniques unlock over time as the player progresses; "cheater" use (see
  Glossary) was named as the first example. A second: choosing the right polishing compound for
  the stone's hardness — cerium oxide for softer stones, ~50k diamond grit for harder stones.
  Owner had nothing further in mind at the moment; the list isn't necessarily exhaustive. Tier:
  Later (owner said "after a while"). Serves: the real-faceter side of U1 wanting depth. Gated by
  reputation (F14), not a raw job counter.
- **F14** — Reputation: a persistent progression stat, separate from money (F10), earned by
  completing jobs. Gates unlocks — the design series in F11, and advanced techniques (F4).
  Resolved: a ruined or poorly-scored job (F9) costs reputation the same way F12 costs money, and
  reputation also gates which jobs appear on the board (F13) — higher reputation opens up
  higher-value/higher-trust jobs, giving the board a different feel at high reputation than at
  zero.

### Scoring
- **F5** — Contract Job (F1) precision scoring is a weighted combination: primarily meetpoint
  cleanliness (how well facets meet at a clean point, not left open or overlapping), plus
  continuous points lost for how far off the stone's final size and weight are from the job's
  requirement — not a pass/fail gate. Facet angle/index deviation isn't scored on its own — it
  matters only through its effect on meetpoint cleanliness.

### Content
- **F6** — The 53 GemCad designs in `LocalOnly/` are a starter set, not the final catalog: some
  are preforms (see Glossary) rather than finished cut designs, and some are duplicates/variations
  of the same shape tuned for different refractive indices. Tier: MVP takes a curated subset;
  Later — the shipped game wants a fuller catalog, grown over time past that starter set.
- **F11** — Design acquisition has two tracks: some designs unlock as a series through play
  progression, gated by reputation (F14), others (individually or in packs) are directly
  purchasable with in-game money (F10) — not real money (Non-goals).
- **F7** — Player design authoring: at some point, players get an in-app tool to design and author
  their own cuts and save them. Tier: Later ("at some point"). Serves: the creative side of U1,
  and is the in-app counterpart to the owner's own text/spreadsheet authoring workflow (T3).

## Tech Stack
- **T1** — Native Swift on Apple platforms (Mac + iPad). Confirmed workable for rendering by the
  `render-proof` spike (`Design/Prototypes/render-proof/`): a SwiftPM executable, Metal spectral
  path tracer, tested on macOS 15. Resolved: the production engine evolves the spike's proven core
  (spectral rendering, half-space geometry, dispersion) rather than re-deriving it from scratch;
  the surrounding structure (tests, abstractions, error handling) gets rebuilt around it. The
  spike's scope is narrower than the whole engine, though — see T2. Still open: iPad/iOS target
  specifics.
- **T6** — UI framework: SwiftUI for the app's chrome (job board, economy, settings — the
  surrounding interface, not the core content), with bespoke UIKit/AppKit/Metal views for the
  cutting screen's viewport and controls, where precision matters. Resolved on the owner's
  confirmation, without a strong prior opinion on the SwiftUI/UIKit/AppKit distinction itself —
  worth revisiting once real screens are being built, if the split doesn't hold up in practice.
- **T2** — The spike is a proof of concept for the *final* render only, not the primary in-progress
  view. The primary view while actively cutting will very likely be a solid or simplified render
  (for frame rate); the full spectral path tracer is reserved for the exact/final render. Two
  rendering tiers, not one.
- **T3** — Design authoring format is already decided and written up in full at
  `Design/design-authoring-format.md`: a tabular format (a header, then one row per tier — part,
  angle, index positions, and a meet specification), hand-authored in a text editor or a
  spreadsheet and imported. It encodes what each tier's facets *meet* (`TCP`, `SIZE`, `GIRDLE`, a
  named vertex, or a fraction between two vertices) rather than depths — depths are derived, not
  authored (forces A5). The **internal runtime representation is decoupled from this** and can be
  whatever's easiest to work with in code — the owner's call, not fixed by the authoring format.
- **T4** — Save data (progress, economy, player-authored designs) is local/on-device only for now.
  iCloud/CloudKit sync is wanted, but deferred — the owner currently has only a free Apple
  Developer account, and CloudKit needs a paid one. Sync becomes live once that's upgraded; no
  target date.
- **T5** — `.gem` import feasibility (research dispatched from F6/A4). **Unverified** — this
  session's research agent was blocked by the sandbox's network allowlist, so nothing below is
  confirmed against a real file or authoritative source; treat as a placeholder, not a scoping
  input, until a real `.gem` file and a real source get inspected. From training knowledge only:
  LIKELY a plain-text format, one line per facet (angle, index, a length/depth value), no stored
  meetpoint coordinates and no explicit crown/pavilion tag — consistent with A4's suspicion that
  `.gem` doesn't reliably carry that data. LIKELY no confirmed open-source parser exists. Verdict:
  parsing the raw per-facet records looks like a tractable near-term task; reconstructing full
  geometry/meetpoints to GemCad's own standard would be a substantial project on its own.
- **T7** — The interactive-view render technique (T2) is still open. Options: **A.** rasterized
  solid/wireframe with plain alpha-blended transparency — cheapest and safest for frame rate, but
  flat/fake-looking, no refraction or fire. **B.** rasterized with real-time environment-map
  refraction (bend the view ray once via Snell's law against the surface, sample a cubemap) — the
  standard real-time gem/glass technique, much closer to the real look, but needs the actual
  polytope surface (A10) as real mesh geometry to rasterize, and has no spectral dispersion unless
  faked. **C. Rejected, confirmed by hands-on testing:** the owner tried render-proof's existing
  path tracer during actual cutting-phase play — the final render was fine, but took a few seconds
  to fully converge, and rough/unpolished states (more diffuse scatter paths, per `shaders.metal`)
  took even longer to converge without visible noise. Not viable for the interactive tier at any
  sample count that still looks acceptable. Needs A or B, evaluated by a new prototype — see Notes
  and Open Questions.

## Architecture
- **A1** — Gem geometry modelled as the intersection of half-spaces (facet planes), each placed by
  angle and index on a 96-tooth indexing wheel — no mesh, no BVH construction. Validated by the
  render-proof spike's `Geometry.swift`; not yet decided whether this representation carries into
  the production engine or was spike-only.
- **A2** — Cheater use (see Glossary) means a facet can be nudged off the wheel's fixed stops to
  fix a meet-point, so the geometry model can't rely on angle/index being locked to A1's fixed-96
  positions alone. Revises A1. Resolved: modelled as a per-facet correction offset layered on top
  of the fixed 96-position grid — matches how the real machine works (nudging away from a stop,
  not switching to a different stop) and is the cheapest revision to A1's existing placement.
- **A3** — Two render pipelines (see T2): a fast solid/simplified pipeline for the interactive
  cutting view, and the spectral path tracer for the exact final render. Resolved: both — an
  on-demand preview the player can trigger any time mid-cut, and a mandatory full render at job
  completion, since the payout reveal is judged against that render.
- **A4** — Designs need a standardized internal format. GemCad's native `.gem` files (source for
  F6) don't reliably record which facets are crown vs. pavilion, or where the meetpoints are — so
  a design can't go straight from `.gem` into the game without added annotation, most likely
  hand-authored rather than auto-imported. Resolved by T3: the authoring format is decided; the
  internal runtime format is a separate, later, code-side decision.
- **A5** — The engine needs a meetpoint/depth solver. T3's authoring format specifies what a tier's
  facets *meet* (a constraint), never a depth directly — the engine has to derive each facet's
  actual depth by solving that constraint. This is new work: the render-proof spike explicitly
  skipped it ("depths here are set from standard proportions and eyeballed," per its README). The
  solver also has to enforce, per `design-authoring-format.md`'s own rules: references point
  backwards only (can't meet a facet not yet cut), the resulting solid must close, the computed
  facet count must match the design's declared count, and every named vertex must be a real point
  the facet passes through.
- **A6** — The cutting mechanic (F8) needs a live physical model, not just A5's static solved
  target: actual contact angle as a function of mast height and cumulative material removed (which
  is *why* the angle indicator drifts toward the target during a cut, rather than reading the set
  angle immediately), meetpoint proximity tracked concurrently with angle, and a pressure-driven
  cut rate with overcut risk. A5 computes the target a tier should reach; A6 is the moment-to-moment
  simulation of the player's actual approach to that target, and the gap between the two is F5's
  scoring input.
- **A7** — Facet finish state (rough/pre-polish/polish grit stage, per F8) is real gameplay state
  the engine has to track, not just a cosmetic render detail — reopens a concern the render-proof
  spike explicitly deferred ("surface finish / polish state," per its README). Each grit stage
  needs its own mast-height convergence pass, though later stages need only small corrections
  since the facet's depth was already established by the first (roughest) grit.
- **A8** — The engine has to support F9's recut path: recomputing a tier group's meetpoint targets
  against a revised (deeper) reference depth after an overcut, and detecting when an overcut is
  severe enough to have invalidated downstream meets in the first place.
- **A9** — Materials need a hardness property, beyond the RI/dispersion/absorption the render-proof
  spike already models, so F4's polishing-compound choice (cerium oxide vs. ~50k diamond grit) has
  something to be right or wrong against. Resolved: no mechanical effect yet — picking the wrong
  compound is real-world flavor/education for now; a real penalty (damage, a worse polish) is a
  Later refinement once the core loop (F8) is proven, not something the MVP needs.
- **A10** — Two distinct geometry representations are needed, not one. The plane list (A1) drives
  the renderer directly — ray/plane slab clipping needs no vertices, and per `Geometry.swift`'s
  and `shaders.metal`'s own code comments, the spike deliberately has "no mesh, no BVH, no
  convex-hull construction." Cost scales with plane count only linearly and cheaply (a handful of
  dot products per plane, per ray) — bounces × samples × resolution dominate render cost, not
  facet count, so this comfortably covers designs well past ~150 facets. But nothing here computes
  actual vertices, facet polygons, or meetpoints — that's a separate half-space-intersection →
  polytope construction step the spike never does, and it's exactly what A5's solver and F5's
  scoring need (a vertex to check "did this meet cleanly"), and what a wireframe view needs too.

## Non-goals
- No multiplayer or social features.
- No real-money purchases (no IAP/microtransaction economy).
- Procedurally-generated designs — the owner considers this not viable, but flagged it as open to
  discuss rather than settled for good. Revisit allowed, per this section's own rule.

## Open Questions
<!-- one queue across all areas, in ask order; each entry tagged with its area -->
<!-- empty in the map-question sense — T7 needs a new prototype (implementation, outside this
     skill's scope) rather than another live question here; see Notes. -->

## Notes
- `LocalOnly/` holds three reference sources, not tracked in git: two faceting textbooks
  ("Faceting for Amateurs", "Faceting Made Easy" by Trevor Hannam) and "GemCad Diagrams - 53
  designs.pdf" — the starter design set (F6).
- A prior throwaway spike (`Design/Prototypes/render-proof/`) already answered "can a finished
  faceted stone render convincingly" — yes, via a spectral path tracer. Its own README lists
  deferred concerns worth revisiting for the real game: meetpoint solving (now underway as A5),
  surface finish/polish state, the stone mounted on a dop under wax, inclusions, and iPad
  measurement (untested — no device on this machine).
- `Design/design-authoring-format.md` already exists, fully written, and is more mature than the
  rest of this map — it was clearly produced in a prior, more developed pass at this project.
  It references files that don't exist on this machine: `.scratch/faceting-game/issues/` (tickets
  03, 18) and `../adr/0002-meet-constraints-not-depths.md`. Same pattern as render-proof's dangling
  `.scratch` references — provenance only, not a live backlog or a real ADR to read.
- `design-authoring-format.md` itself flags two cases its format doesn't yet handle: an
  outcome-condition meet ("cut so these edges are equal length", no position to write down) and a
  dial-gauge depth reading that may not equal a plane-offset depth. Not yet designed; the document
  says as much and defers them rather than working around them.
- **Research returned, unverified:** feasibility of importing `.gem` files directly — see T5. The
  research agent hit a sandboxed-network block and could not reach any primary source this
  session; the finding is from training knowledge only and is explicitly flagged as unconfirmed.
  Re-run with real sources (a real `.gem` file, GemCad's own docs, community parsers) before
  treating T5 as a scoping input.
- **Next prototype needed (T7):** a second throwaway spike, same pattern as render-proof, to
  evaluate T7's options A and B for the interactive tier — this is implementation work, outside
  `a-map`'s scope (no production code), so it wasn't built this session. The owner proposed the
  "Kiev Triangle" cut (page 15 of the 53-design PDF) as the stress-test case — reportedly the most
  complex of the 53, a good upper bound. Confirmed via `pdfminer` (no PDF-image renderer available
  in this environment — no `poppler`, no PyMuPDF/`pdf2image`, and `sips` doesn't support PDF page
  selection): **139 facets**, 96-index wheel, 3-fold mirror symmetry, RI 2.160, cut from CZ — a
  genuinely serious upper bound, close to the ~150-facet ceiling discussed under A10. The page's
  text layer gives the full angle/index cutting sequence, but not the meetpoint relationships —
  those live in the page's crown/pavilion/profile diagrams, which no available tool could render
  as an image this session (likely vector art, not text or an embedded raster). Authoring this
  design's full tier table (with `from`/`%`/`to` meets, per `design-authoring-format.md`) needs
  either a working page-image renderer or the owner reading the diagram directly — deferred to
  when the actual prototype gets built, since that's implementation, not a map decision. The owner
  then shared a screenshot of the actual crown/pavilion/profile diagrams: confirms a rounded
  triangular (trilliant-style) outline, 3-fold symmetric, densely faceted on both crown and
  pavilion consistent with 139 facets. Reading exact facet-to-index correspondence and meetpoints
  off that image reliably is not something to attempt by eye — left for the owner's own expert
  reading or a real vector/high-res source when the prototype is actually built.
