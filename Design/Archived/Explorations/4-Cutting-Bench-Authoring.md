# 4 · Cutting Bench Authoring — Exploration

Status: **CLOSED 2026-08-23**
Started: 2026-08-22 · via /a-explore · split from `Cutting-Bench-App` on 2026-08-23
IDs: **S** = scope · **I** = implementation · **U** = UI/UX

Cutting a pattern in the app instead of hand-writing its JSON: the editable draft, tiers added, deleted
and reordered, symmetry generated from seed stops, meets built by clicking facets and edges in the
render, and the file written by the kernel. **This is the slice the whole tool exists for** — its bar is
reproducing an authored pattern with no text editor involved.

One of five explorations split from `Cutting-Bench-App`, one per plan. Siblings:
`1-Cutting-Bench-Kernel-Changes`, `2-Cutting-Bench-App-Shell`, `3-Cutting-Bench-Pattern-Display`,
`5-Cutting-Bench-Angle-Tuning`.

## Grounding

What exists today, anchors re-verified 2026-08-23:

- **A tier whose meet is not yet chosen cannot be represented.** `Pattern.swift:21`
  (`public indirect enum Meet: Decodable, Equatable, Sendable`) is exactly five complete forms; there is
  no "undecided".
- **Decoding enforces the format's rules**, so the writer inherits a real validator:
  `Pattern.swift:283` onward, with `PatternError` covering duplicate tier labels, out-of-range and
  non-integer index stops, unknown meet kinds, and a vertex that does not name exactly three facets.
  Index range is checked at `Pattern.swift:301`
  (`for index in tier.indices where index < 0 || index >= stops {`).
- **`Meet.namedTriples` is how a meet's referenced facets are enumerated**: `Validation.swift:284`
  (`var namedTriples: [[FacetRef]] {`) — internal today, made public by
  `1-Cutting-Bench-Kernel-Changes`.
- **The kernel already reports dangling references rather than preventing them**:
  `Validation.swift:10` (`case unknownFacet(tier: String, named: FacetRef)`).
- **A second `tcp` on one side is already a finding**: `Validation.swift:15`
  (`case secondTCPOnSide`).
- **The named-point check tests that the named point is a corner of the intermediate solid**:
  `Validation.swift:20` (`case vertexNotOnIntermediateSolid`), using
  `Validation.swift:311` (`private let onSolidTolerance = 1e-7`).
- **Three meet forms need no picking at all**: `Solver.swift:226` (`return 1` — `size`, because the
  tier's offset *is* the unit), `Solver.swift:235` (`return sin(radians(spec.angle))` — `tcp`, the tier
  cut until it reaches the girdle outline along its own azimuth, which the normalisation puts at radius
  1), and `Solver.swift:243` (the `girdle` band, sized from `extent.width`).
- **A `fraction` resolves by linear interpolation along the segment between its two named endpoints**:
  `Solver.swift:248` (`case .fraction(let from, let percent, let to):`), implementing
  `design-authoring-format.md:269` (`Interpolate the *point* — P = from + percent/100 × (to −`).
- **A plain vertex is the same thing with no percentage**: `design-authoring-format.md:266`.
- **`tcp` means the axial point on the tier's own side**: `design-authoring-format.md:274`.
- **A tool must never pick a meet's endpoints itself**: `design-authoring-format.md:279`–`:281`
  (`Author the endpoints first, then the percentage.` … `and back-solve a percentage from an achieved
  depth.`).
- **The percentage is a coordinate, not a design quantity**: `design-authoring-format.md:283`.
- **Which facet of a new tier arrives at the point is determined, not chosen**:
  `design-authoring-format.md:234`.
- **The wider list of facets through a solved point is derived by the kernel, not authored**:
  `design-authoring-format.md:217`.
- **Symmetry is not stored at all, not even as a generator**: `design-authoring-format.md:91`. What lands
  in the file is the full index list.
- **Tier order is data, not presentation, and must never be normalised**:
  `design-authoring-format.md:451`, which also says that when references do point forward the fix is to
  establish the true cutting order.
- **The kernel accepts any positive wheel**: `Pattern.swift:290` and `Pattern.swift:249`.
- **`facetsolve` exits non-zero only when a *finished* pattern has findings**: `main.swift:345`
  (`exit(findings.isEmpty || pattern.state == .inProgress ? 0 : 1)`).
- **The named-point check is the expensive half of validation**: roughly `tiers × planes³`, **1.65 s** on
  a 139-plane pattern against **0.60 s** for the whole solve.
- **Four patterns are authored**, and `Design/Patterns/Pattern-Easy-Octagon.json` is the reproduction
  target. The format leaves formatting loose on purpose: `design-authoring-format.md:100`
  (`Write it to 2 decimal places; 90.00 and 90 are the same value`).

## Inherited

From **`1-Cutting-Bench-Kernel-Changes`**:

- **`Pattern`, `TierSpec` and `Meet` are `Codable`**, so the kernel writes the file and the app never
  does. Recorded as **ADR-0003**.
- **`Meet.namedTriples` is public**, which is how this slice answers "which tiers reference this facet".
- **Validation is split three ways**, with tier *k*'s per-tier result proven to depend only on the tiers
  before *k* — the property the cache in **I5** rests on.
- **Per-tier `instructions`** and the **header girdle target** exist as fields to edit; the **eight index
  gears** are settled as the set the picker offers.
- The **non-throwing partial solve**.

From **`2-Cutting-Bench-App-Shell`**: the document app and its undo manager, the Metal viewport, the rough
prism and its `P`/`C`/`G1`…`G16` names, the window layout, and stock native macOS as the visual answer.

From **`3-Cutting-Bench-Pattern-Display`**: the display solid with the rough scaffolding rule, the
intermediate-solid display mode, the tier table with its wheel column, the meet dots **A**/**B**/anchored,
the metrics, the findings status strip, and the declared facet count field.

## Tickets folded in

- **`Chore-Validation-Rebuilds-The-Solid-Once-Per-Tier`** — the named-point check costs roughly
  `tiers × planes³`, 1.65 s on a 139-plane pattern, and says "an authoring UI that validates after every
  edit will feel it." **Answered by I5 and U1**: the per-tier half is cached and invalidated from the
  first edited tier onward, and the cheap structural half runs on every keystroke. **This plan closes
  it** — the three-way split it depends on lands in `1-Cutting-Bench-Kernel-Changes`, but the cache that
  makes an editing UI not feel the cost is here.

## Scope & purpose

- **S1** — **The completion bar is reproducing `Easy Octagon` by cutting it in the app.** What is
  genuinely impossible today is seeing the stone while cutting it and clicking facets rather than typing
  tier-and-index pairs — `facetsolve` already validates and reports, which is how the four existing
  patterns were authored by hand-writing JSON.
  **Done means:** a new document, `Easy Octagon` cut tier by tier in the app with no text editor
  involved, saved, and the result equal to `Design/Patterns/Pattern-Easy-Octagon.json` **after decode —
  every field equal and the tiers in the same order — with identical solved geometry.** Not
  byte-identical: the format leaves formatting loose on purpose (`design-authoring-format.md:100`), so
  matching bytes would constrain the writer for no gain. **Chosen as the bar because it is the only
  version an agent can verify without the owner's eye on a diagram.**
  Rejected: a view-only build that never writes a pattern — it defers every hard question and tells the
  owner little that `facetsolve --json` does not.

- **S2** — **`Kiev Triangle` — 139 facets, 3-fold mirror, RI 2.160 — is named as the first thing the
  finished tool is used for**, not as a completion criterion: it can only be verified by the owner
  reading its diagrams, and no PDF page renderer exists on this machine
  (`Execution-Protocol.md:113`). **Naming it now means the 139-facet case and odd-order symmetry shape
  the design rather than surprise it** — the reference set is two regular octagons and a 2-fold
  rectangle, so nothing in it has odd-order symmetry.

- **S3** — **Editing an existing pattern includes deleting a tier and changing a tier's angle or index
  stops**, not only appending new tiers to the end. The app opens and edits existing patterns — finished
  or in progress — not just new ones.

### Non-goals

- **No angle tuning, no tangent-ratio rescale, no rotation, and no two-point angle derivation.** All four
  are `5-Cutting-Bench-Angle-Tuning`. A single-tier angle edit *is* available here, because that is what
  transcribing a sheet does.
- **No animated facet arrival**; deferred to `Chore-Incremental-Half-Space-Clipper`.
- **No yield readout, no volume code, no pattern browser, no thumbnails, no printing, no GemCad interop,
  no photorealistic render, nothing for iPad.** Carried forward unchanged.

## Implementation

- **I1** — **The half-authored pattern is the app's, never the kernel's.** A tier with an angle and index
  stops but no meet chosen yet is the normal condition of authoring, and it cannot be represented in the
  kernel's types: `Pattern.swift:21` is five complete forms with no "undecided". **The app keeps its own
  editable model with an optional meet per tier and converts to a `Pattern` to solve, validate and
  save.**
  **This survives the fact that the finished game will offer authoring too.** A draft is a mutable UI
  buffer with optional fields, and two different authoring surfaces — this Mac bench tool and whatever
  the game puts on an iPad — would reasonably shape one differently. **What must be identical between
  them is the *file*, not the buffer.**
  Rejected: a draft type inside `FacetKernel`. It would put a type the game's own authoring UI would
  likely bypass into the module the game inherits, and its rules — which fields may be absent, and when —
  are UI policy rather than geometry. Recorded as **ADR-0003**.

- **I2** — **An edit that would orphan a reference is refused, not reported.** Deleting `P2` while `P3`'s
  meet names one of its facets is blocked; so is removing an index stop that something later names. To
  delete a tier the author first re-aims or removes its dependents. **This is deliberately stricter than
  the format requires** — the format's stance is that a pattern can always be saved and validity is
  reported rather than enforced — and the reason is that this build is a test bed and an authoring tool,
  where a pattern that has quietly gone inconsistent is worse than an edit that will not complete.
  **The line is remove versus move.** Changing a tier's **angle** is always allowed: it moves a named
  facet rather than removing it, so every reference still resolves, just to a different point. Changing
  its **index stops** is refused only for stops something later names. **Renaming a tier propagates** — a
  rename is the one structural edit where repair is unambiguous, since the mapping from old label to new
  is exact, so references are rewritten rather than refused. **Nothing is ever guessed**: repairing a
  deletion would mean choosing which facets a meet should aim at instead, which
  `design-authoring-format.md:279` forbids.
  Rejected: leaving references dangling and reporting them, which the kernel already supports
  (`Validation.swift:10`); cascading the delete through every dependent tier, which discards work the
  author wants to re-aim; and auto-repair, ruled out above.
  **This needs `Meet.namedTriples` public**, which is how the app answers "which tiers reference this
  facet". Reimplementing it app-side would put knowledge of how a meet names facets outside the module
  that owns the format.

- **I3** — **Tiers can be reordered, and a move that would make any meet reference a tier cut later is
  refused.** The same test as **I2**, applied to a move instead of a delete, so the rule stays one rule.
  This makes the case the format explicitly anticipates possible — `design-authoring-format.md:451` says
  that when references do point forward the fix is to establish the true cutting order, which is exactly
  a reorder, and transcribing a sheet whose steps are listed out of order is a case the format expects.
  **Negative requirement: the app never reorders tiers on its own** — not on load, not on save, not to
  group by `part`, not to sort by angle. Tier order is data and normalising it for tidiness can turn a
  cuttable pattern into one that cannot be cut at all.
  Rejected: forbidding reordering entirely, which would forbid harmless moves too — `Easy Octagon`'s two
  pavilion tiers each reach the girdle independently, so swapping them changes nothing; and allowing any
  move and reporting forward references afterwards, which contradicts **I2** for no gain.

- **I4** — **Three of the five meet forms take no input beyond choosing the form; only `vertex` and
  `fraction` need facets picked.** `size` takes nothing at all — `Solver.swift:226` returns `1`, because
  the tier's offset *is* the unit — so there is no "cut it so it all fits" decision and nothing about the
  rough enters into it. `tcp` takes only the tier's angle: `Solver.swift:235` returns
  `sin(radians(spec.angle))`. `girdle` likewise takes no picking, though it needs the girdle target
  fraction, which now comes from the header field.
  So **the author sets an angle and index stops, chooses the form, and the depth and the culet's position
  both follow.**
  **Consequence: the stone's size never depends on the rough, and the author has no control over the
  ratio between them** — consistent with nothing about size-relative-to-rough being stored.

- **I5** — **The per-tier half of validation is cached, invalidated from the first edited tier onward.**
  This is the answer to the folded-in ticket. Tier *k*'s result depends only on the tiers before *k*, so
  **editing tier *j* invalidates *j* onward and leaves everything before it untouched**, and appending a
  tier validates exactly one tier instead of re-validating all of them. That is what turns
  `tiers × planes³` into `planes³` per tier added.
  **The cache unit is the tier, not the side.** Pavilion and crown tiers usually group in file order but
  nothing guarantees it, and tier order must never be normalised (**I3**), so a side-based cache would be
  resting on an accident of the four patterns to hand.
  **A tangent-ratio rescale invalidates a whole side onward**, since it rewrites every angle on it —
  expected, not a flaw in the scheme. That operation lives in `5-Cutting-Bench-Angle-Tuning`, which
  inherits this cache.

- **I6** — **The app converts its draft to a `Pattern` and hands it to the kernel to write.** The app
  never serialises JSON itself. A draft with any tier lacking a meet cannot be converted, so **saving an
  incomplete pattern requires a decision the draft cannot dodge**: the file format has no "undecided"
  meet, so a tier without one cannot be written. The author either completes it or removes it.

## UI / UX

- **U1** — **Structural findings appear as you type; geometric ones arrive after a pause and say when
  they are in flight.** The cheap half of validation runs on **every keystroke**, so the transcription
  mistakes — a forward reference, a facet that doesn't exist, three planes that pin nothing — surface
  immediately. The expensive half runs after a short quiet period, cancellable, off the main thread, with
  the status strip saying a check is running.
  **While a deferred check is in flight the previous result stays visible and is marked stale, and stale
  findings are never presented as current.**
  Rejected: running everything on every edit, which is fine at 37–73 facets and unusable at 139; and a
  Validate button, which makes the tool's whole purpose an opt-in step.

- **U2** — **Symmetry is a per-tier control with quick access: one field for the number of folds and a
  checkbox for mirroring.** It changes tier to tier, so it sits with the tier row rather than in the
  inspector. **Nothing symmetry-shaped is persisted** — `design-authoring-format.md:91` is explicit that
  symmetry is not stored at all, not even as a generator, and what lands in the file is the full index
  list — so these two controls are generator inputs and a derived display, never document data.

- **U3** — **The symmetry controls sit on a seed set, not on the `indices` field.** The author types one
  or more seed stops beside the folds field and the mirror checkbox, and `indices` fills in as the
  expansion. **`indices` stays hand-editable, and editing it directly drops that tier to raw mode with
  the generator off** — a generator that cannot be bypassed would make some design unauthorable in the
  tool built to author it.
  **Mirroring is about index 0.** The index origin is the author's own convention and they place 0 on the
  design's mirror plane: `Rand's` girdle tier `8 40 48 56 88 0` is exactly that, 2-fold mirrored from
  seeds `{0, 8}`, with 88↔8, 56↔40 and 48 fixed. A set mirrored about some other stop genuinely cannot
  be generated this way, and the raw-index escape hatch covers it. Rejected: a mirror-axis field, which
  every other tier would ignore.
  **On opening a pattern the folds and mirror controls are derived from the stops** — the largest fold
  count that maps the stop set onto itself — so they show what the tier actually has rather than sitting
  blank, and a tier whose stops are not symmetric honestly reads as 1-fold. Rejected: the controls
  expanding `indices` in place, which leaves the author guessing whether the field currently holds seeds
  or an expansion.
  **The folds field accepts only divisors of that tier's own wheel.** Generating an n-fold set means
  stepping by `wheel/n`, so a fold count that does not divide the wheel would land between stops —
  **7-fold is reachable on 84 and impossible on 96**. The constraint is per tier, since a tier may
  override the wheel.

- **U4** — **The tier table's wheel column gains a popup offering the eight gears plus "inherit".**
  **Two behaviours follow.** Lowering a tier's gear can put an existing stop out of range — index 100 is
  valid on 120 and rejected on 96 (`Pattern.swift:301`) — so **that change is refused, naming the
  offending stop**, consistent with **I2**. And changing a gear changes which fold counts are available,
  since folds must divide the wheel; nothing is stored, so the symmetry display simply recomputes.

- **U5** — **While a meet is being picked, the viewport shows the intermediate solid — the stone as it
  stands before the tier being authored — with the finished stone drawn over it in edges only.** A meet
  is a cutting-time claim (`design-authoring-format.md:26`), so the facets that may be named are those
  present when that tier is cut; **showing exactly those makes an invalid meet unclickable by
  construction.** The prefix machinery already exists in `3-Cutting-Bench-Pattern-Display`, so this costs
  nothing new. It is not a bowl: before a pattern closes the rough is in the display, so the intermediate
  is the preform with the tiers so far cut into it. The **wireframe ghost of the finished stone** answers
  the one disorienting case — re-aiming an early tier's meet on a finished pattern — and is the existing
  mechanism at a different setting, since edges are always drawn and the fill already fades
  independently. Appending tiers in order, the common case, shows no change at all, because the
  intermediate before a new last tier *is* the stone so far.
  Rejected: showing the finished solid with unavailable facets greyed out. **It cannot express a real
  class of meet** — a tier's facets can be cut away entirely by later tiers, which the kernel treats as
  legitimate (`Validation.swift:34`, `case tierContributesNoFacets`, a tier cut only to establish an
  intermediate point another tier then cuts to). Those facets are absent from the finished solid rather
  than greyable, so the meet that names them would be unauthorable. Also rejected: refusing illegal picks
  after the click, which teaches the rule by rejection.
  **Three rules on picking.** Clicking a **rough** facet is refused with its reason — rough names are for
  display only and a saved meet may never reference one, so a tier needing a rough reference is
  unexpressible rather than writable. **Opacity changes what you can see, never what you can click**: the
  front-most facet always takes the click, with an edge inside the grab radius taking it ahead of any
  facet (**U7**). And **orbiting stays live during a pick and does not cancel it**, with the face-up and
  face-down snap views and typing the tier and stop both available throughout — which is how a facet
  facing away from the camera is reached.

- **U6** — **A point on an edge is the click projected onto that edge, with a snap zone of 10% of the
  edge's own length in model space at each end.** A click landing in the first 10% of the edge gives the
  near endpoint, the last 10% gives the far one, and anything between gives the clicked position as the
  percentage. **Snapping to an end produces a plain `vertex` meet, not a `fraction` at 0 or 100** — a
  percentage that happens to be zero is a coordinate stating something the vertex form states directly
  (`design-authoring-format.md:266`).
  **The zone is measured as a fraction of the edge rather than in screen distance because it is then the
  same unit the author corrects afterwards** — the percentage readout and the snap threshold are one
  number — and it does not change with camera distance or viewing angle. **It is one build constant,
  tuned during testing, and not a preference**: a hidden setting that changes what a click means is worse
  than editing a number.
  Accepted cost: on an edge seen nearly end-on the two zones swallow most of the screen distance the edge
  occupies, so the middle is hard to hit by clicking. Nothing is foreclosed, because the percentage is
  editable and a 3% fraction is reached by typing.
  Rejected: a fixed screen distance from each endpoint, which gains fine control near the ends by zooming
  but is no longer the stated 10%, changes with zoom and foreshortening, and never says how large it
  currently is; and the smaller of the two, which needs two constants and changes character as the camera
  moves.

- **U7** — **Picking stays facet-based and everything happens in the viewport with no mode switch. One
  click resolves as an edge when the pointer is within the edge grab radius, otherwise as the front-most
  facet.** The grab radius is screen-space and a build constant **starting at 8 points**, tuned alongside
  **U6**'s 10%; the two do not conflict, since this one decides *what* was clicked and **U6** decides
  *where along* an edge.
  **The state machine, in full:**
  - **Click an edge** — the point is anchored along it per **U6**. This works whether or not a facet is
    highlighted, and it clears any highlight.
  - **Click a facet** — it highlights. **Clicking the highlighted facet again clears it.**
  - **Click a second facet** — if the two share an edge, **that edge is selected and its two endpoints
    are marked**; the author then clicks along it to anchor a point, or clicks a **third facet** to take
    whichever endpoint that facet passes through. If the two share exactly one point and no edge, **that
    point is selected** and the pick is complete. If they share nothing, **the first is dropped and the
    second is highlighted** — so a mis-click costs one click, never a reset.
  **Two facets can share at most one edge, and cannot share two vertices without sharing the edge between
  them.** The display solid is an intersection of half-spaces and therefore convex
  (`Polytope.swift:47`), so two facet planes meet in one line: any two shared vertices span a segment
  lying in both planes, which is that common edge. So "their common edge" is never ambiguous and needs no
  tie-break.
  **Why not corner-first picking, where one click on a corner gives the whole vertex:** it reads as fewer
  clicks but it makes the app choose which three of the planes at that corner to name whenever more than
  three meet, and clicking the facets says which three explicitly. The two-facet middle ground recovers
  most of the brevity — two clicks reach an edge, three reach a corner — without the app ever choosing a
  name the author did not.

- **U8** — **`from` is the endpoint further from the axis, and the percentage is distance along the edge
  itself.** Ties go to the endpoint nearer the girdle plane, then to whichever vertex sorts first by tier
  and index. The percentage therefore reads outside-in, the way the corpus phrases it, and grows
  monotonically as the point slides, so nothing flips under the pointer.
  Rejected: making the endpoint nearer the click `from`, which keeps the number at 50 or less but swaps
  the named vertices as the click crosses the midpoint, giving one point two spellings; and having the
  author designate `from` with an extra click, which adds a second way to express the same point.
  **Negative requirement: the percentage is measured along the straight segment between the two named
  endpoints — never as a distance from the girdle, never a radial or vertical distance, and never a
  screen distance.** This is not a UI convention but the arithmetic the solver already performs:
  `P = from + percent/100 × (to − from)` (`design-authoring-format.md:269`, implemented at
  `Solver.swift:248`), which is linear interpolation along that segment. So the number the author sees,
  the number stored, and the number the solve resolves are one number.

- **U9** — **The anchored point's percentage is editable in the tier table's meet cell and in a small
  readout at the point in the viewport** — typing commits and the point slides live. **Typing 0 or 100
  collapses the meet to a plain `vertex`**, exactly as snapping into an end zone does (**U6**), so the
  meet form follows from the value rather than from how the value was entered.

- **U10** — **The app never names a facet the author did not click.** Where more than three planes pass
  through the picked point, the remaining candidates are highlighted and the pick waits for a third
  click. **The third name is filled in without a click only when exactly one candidate exists**, which is
  not a choice. The reason is legibility rather than geometry — any three non-singular planes through the
  point resolve to the same point, and the format treats the wider list as derived
  (`design-authoring-format.md:217`) — but the triple the author picked is the one that reads correctly to
  the next human. Rejected: the app choosing the most independent triple and letting the author swap it,
  which saves a click at every four-plane meet and names facets nobody said.
  **The axial point is written as `tcp` when it is on the tier's own side and the side's free datum is
  still free.** `tcp` pins it exactly with nothing to choose, and it means the axial point on the
  *tier's* side (`design-authoring-format.md:274`), so a crown tier naming the culet cannot use it.
  **When the datum is already spoken for — which any earlier non-vertical tier on that side does — the
  app says so and asks for three facets instead**, since a top-level `tcp` there would fire
  `secondTCPOnSide` (`Validation.swift:15`) while a vertex triple through the same point is legitimate.
  **The app does not restate that rule: it asks the structural half of validation**, which already
  contains the check. A `tcp` standing as a *fraction endpoint* is unaffected, which is the common case —
  `Novice Ash-er`'s `P3` is exactly that.

- **U11** — **A point whose defining planes include a rough plane is refused.** `U5` bars a rough facet
  from a meet reference, so a corner or edge involving one of the prism's eighteen planes cannot be
  written down. The prism is a build constant with no design meaning — purely a naming and display device,
  sized for headroom rather than realism — so a point derived against it would bake an arbitrary number
  into the pattern while looking like a designed one, and nothing in the file would record where it came
  from.
  Accepted cost: while a pattern is still open the rough is in the display, so several visible edges take
  no click, which is most noticeable on the earliest tiers. **The refusal states the reason** rather than
  the click doing nothing: rough names exist so that every surface has a name, not so that anything can
  be aimed at one.

- **U12** — **`state` is a two-way switch in the inspector's header section, and marking a pattern
  `finished` is refused while any finding fires.** **This is the one place in the app where a check blocks
  rather than reports**: everywhere else the author is mid-work, here they are making an assertion about
  the result. It is also the moment the tool does what it exists for.
  **The transition forces a complete synchronous validation**, all three pieces, rather than trusting the
  deferred geometric pass or a cache that may be stale; and it lists what fired when it declines.
  **The declared facet count stays optional** — if none has been typed, that check does not run rather
  than blocking the transition.
  Going the other way is free: `finished` back to `in progress` is always allowed, since that claims
  nothing.
  Rejected: allowing the transition with a warning, which is exactly the silent escape the `state` field
  was introduced to prevent; and allowing it silently, which makes the field a label rather than a claim.
  Consistent with `facetsolve`, which already exits non-zero only when a *finished* pattern has findings
  (`main.swift:345`).

- **U13** — **Every refused edit states its reason and names the offending element**, and refusals are
  also **written to the unified log via `os_log`**, so a case that came up once and was dismissed can
  still be traced afterwards. This covers **I2**'s orphan refusals, **I3**'s reorder refusals, **U4**'s
  out-of-range stop, **U5**'s rough-facet click and **U11**'s rough-derived point.

## ADR candidates

**None to write.** The draft-belongs-to-the-app half of **I1** is **already recorded** at
`Design/Decisions/0003-kernel-owns-the-file-app-owns-the-draft.md`, accepted 2026-08-23. Carry it into
the plan's Decisions table; do not write it again.

The refuse-rather-than-report rule (**I2**, **I3**) was considered and dropped: it is a real trade-off and
genuinely surprising, but it is cheap to reverse — the refusals are guards at a handful of edit sites, and
the kernel already reports the same conditions if they are removed.

## Open — queued, in ask order

Empty. Nothing in this slice is unresolved.

## Notes

- **The rule this slice and `5-Cutting-Bench-Angle-Tuning` share: structural edits are refused, geometric
  consequences are reported.** An angle change can never orphan a reference, so it is always permitted;
  but it can make a meet unreachable, cut a tier away entirely, or stop the solid closing, and those are
  reported through validation rather than blocked — the author has to be able to pass through an invalid
  stone while working.
- **This build is stricter than the game should be, on purpose.** Refusing an edit that would orphan a
  reference (**I2**) is the right trade for a test bed and authoring tool; the game may want to be more
  forgiving, and that is a decision for the game rather than a rule inherited from here.
- **Generating a tier's `instructions` from its meet may be worth doing later, and this build
  deliberately does not.** The corpus table at `design-authoring-format.md:401` is close to a generation
  rule read backwards. Two consequences for how the field is built now, so automation is an addition
  rather than a breaking change: the field is a plain stored string and never a derived value, and
  **absent means the author wrote nothing, not "generate one"**. **A generator would read the meet's
  named facets, which is the second reason U10 never picks a facet the author didn't click** — prose built
  from the author's own names reads to the next human the way the sheet did.
- **The `instructions` field recovers intent the format currently loses.** A printed sheet's instruction
  column is exactly this text — `design-authoring-format.md:401` tabulates the corpus's phrasing
  (`Cut to centerpoint`, `level girdle`, `set girdle thickness`, `should cut the same depth`) against the
  machine form each resolves to. Keeping the phrase verbatim beside the resolved meet is what a later
  reader needs when the resolved form cannot express the reason: the unresolved outcome-condition case —
  a reader seeing `47.3% between X and Y` who cannot tell the design demanded equal edge lengths — is
  partly answered by the author being able to write that down.
