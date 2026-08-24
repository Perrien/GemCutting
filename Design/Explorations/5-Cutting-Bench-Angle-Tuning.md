# 5 · Cutting Bench Angle Tuning — Exploration

Status: **CLOSED 2026-08-23**
Started: 2026-08-22 · via /a-explore · split from `Cutting-Bench-App` on 2026-08-23
IDs: **S** = scope · **I** = implementation · **U** = UI/UX

The three operations that rewrite a pattern's angles or orientation without touching a single meet:
tangent-ratio tuning of a whole side, rotation by a quarter turn, and deriving a tier's angle from its
index plus two picked points. All of them arrive after a pattern is authored, and none of them needs a
solver change.

One of five explorations split from `Cutting-Bench-App`, one per plan. Siblings:
`1-Cutting-Bench-Kernel-Changes`, `2-Cutting-Bench-App-Shell`, `3-Cutting-Bench-Pattern-Display`,
`4-Cutting-Bench-Authoring`.

## Grounding

What exists today, anchors re-verified 2026-08-23:

- **The solver derives every depth from the meets, taking the angle as input**: `Solver.swift:102`
  (`public func solve(_ pattern: Pattern, girdleTargetFraction: Double = 0.04) throws -> Solution`),
  with `Solver.swift:235` (`return sin(radians(spec.angle))`) showing a `tcp` depth resolved from the
  angle alone. **So rewriting angles and re-solving reproduces the result; nothing new is stored.**
- **The solver groups parts into sides the same way this slice does**: `Solver.swift:169`.
- **A facet's normal comes from its angle and its index stop, with the part fixing the `z` sign**:
  `Plane.swift:34` (`public func planeNormal(`).
- **The girdle band is sized from the width**: `Solver.swift:243`
  (`return sin(radians(spec.angle)) + normals[0].z * girdleTargetFraction * extent.width`), so anything
  that changes the width changes the band.
- **A `fraction` resolves by interpolation along the segment between its named endpoints**:
  `Solver.swift:248` (`case .fraction(let from, let percent, let to):`), per
  `design-authoring-format.md:269`.
- **A tool must never pick a meet's endpoints itself and back-solve a percentage from an achieved
  depth**: `design-authoring-format.md:279`–`:281`.
- **The percentage is a coordinate, not a design quantity**: `design-authoring-format.md:283`.
- **Which facet of a tier arrives at the point is determined, not chosen**:
  `design-authoring-format.md:234`.
- **The named-point check tests the named point is a corner of the intermediate solid, not that the
  aimed facet is the one that gets there**: `Validation.swift:20`
  (`case vertexNotOnIntermediateSolid`), with `Validation.swift:311`
  (`private let onSolidTolerance = 1e-7`).
- **Angles are written to 2 decimal places**: `design-authoring-format.md:100`
  (`Write it to 2 decimal places; 90.00 and 90 are the same value`).
- **Every permitted index gear divides by 4** — 32, 64, 72, 80, 84, 88, 96, 120 — which is what makes a
  quarter turn a whole number of stops.
- **`Rand's Cut Corner Rectangle #1` has a 65° `pav` tier**, which is a pavilion facet below the girdle
  and rescales with the rest of its pavilion.
- **`Tangent ratio` is the project's agreed term** and is recorded in `Design/Glossary.md`.
- **One 139-plane solve costs 0.60 s**; the four authored patterns at 37–73 facets re-solve in a few
  milliseconds.

## Inherited

From **`1-Cutting-Bench-Kernel-Changes`**: **width and length assigned by size**, so `L/W` ≥ 1 and width is
the smaller extent — the property **I3** depends on entirely. Also the **girdle target as a header
field** and the **validation split**.

From **`2-Cutting-Bench-App-Shell`**: the document app and its undo manager, the Metal viewport, the window
layout, and stock native macOS as the visual answer.

From **`3-Cutting-Bench-Pattern-Display`**: the solve-and-redraw loop, the metrics readouts that move as a
side is rescaled, the findings status strip, and the critical-angle marking on pavilion tier rows — which
is the readout a pavilion rescale most needs, since scaling a pavilion shallower is exactly how mains
cross the leakage threshold.

From **`4-Cutting-Bench-Authoring`**: the editable draft, the picking state machine and its two-facet and
edge rules — reused verbatim by **I4** for its two points — the per-tier validation cache, which a
rescale invalidates from the first affected tier onward, and the refusal idiom of stating the reason and
naming the offending element while also logging it.

## Tickets folded in

None. No open ticket touches this slice.

## Scope & purpose

- **S1** — **Adjusting angles is a first-class activity after authoring, not only during it.** The real
  workflow has two phases: a pattern is authored for good facet placement and size, with angles as vague
  approximations; then the author revisits the angles for light performance. **Every meet and every
  construction rule is unchanged by this, and so is the plan view** — the facet layout and the stone's x/y
  size stay exactly as authored, and only heights move. So it is not a re-authoring pass, it never touches
  the meets, and the app has to make it comfortable to sit and tune a finished pattern.
  **Done means:** a finished pattern's crown or pavilion rescaled by giving one tier a new angle, with the
  plan view provably unchanged and the height scaled by the ratio; a pattern rotated a quarter turn with
  its width, `L/W` and girdle band unchanged; and a tier's angle derived from two clicked points, written
  as the resolved angle plus a three-facet vertex meet.

### Non-goals

- **No solver change and nothing new in the format.** All three operations rewrite values the file
  already stores.
- **No free rotation.** Only a quarter turn (**I3**).
- **No sixth meet form** carrying two points with the angle absent (**I4**).
- **No residual or drift readout** for the two-point derivation, because the drift is below what the
  format writes (**I4**).
- **No yield readout, no volume code, no pattern browser, no printing, no GemCad interop, no
  photorealistic render, nothing for iPad.** Carried forward unchanged.

## Implementation

- **I1** — **Angle tuning is a side-wide tangent-ratio rescale, not a single-tier edit — and the solver
  needs no change to support it.** The author picks any tier on one side except the girdle and gives it a
  new angle. From that, **`k = tan(new) / tan(old)`** for the tier they touched, and **every other tier on
  the same side is rewritten as `atan(k · tan(angle))`**. **The plan view is preserved exactly and the
  stone only changes height.**
  **Crown and pavilion are rescaled independently — changing `P2` touches no crown tier, and changing a
  crown tier touches no pavilion tier.** A side is defined the way the solver already groups parts
  (`Solver.swift:169`): the crown side is every `crown` and `table` tier, the pavilion side every `pav`
  tier. So `Rand's` 65° `pav` tier rescales with the rest of its pavilion, which is right — it is a
  pavilion facet below the girdle.
  **The girdle is excluded, by its declared `part` rather than by its angle**, so the outline is whatever
  the author called the outline. **A tier at exactly `90.00°` is additionally never rescaled whatever its
  `part`**, since its tangent is infinite and the arithmetic must not depend on a row being labelled
  correctly. Rejected: excluding by angle alone, which would rescale a non-flat girdle tier and silently
  move the outline.
  **A table tier at `0.00°` needs no special case** — `tan(0) = 0`, so `atan(k · 0) = 0` and it stays
  flat. **A tier at `0.00°` cannot be the handle**, since `k` would be undefined.
  **No solver change.** The transform rewrites the angles in the pattern and the ordinary solve reproduces
  the result, because the solver already derives every depth from the meets and the meets are untouched.
  Angles are what the file stores, so the rescaled pattern is an ordinary pattern; **the ratio itself is
  never persisted.**
  **Verified numerically by replicating the kernel's plane math on `Easy Octagon`**, whose table meet
  `vertex(C1@0, C1@12, C2@18)` is its only meet pinned by three tilted facets and therefore the only one
  that could drift. The replication first reproduces the shipped expected table radius of `0.68292` at
  `C1 = 42.00°`, so it is faithful. Then, rescaling the crown from `C1 = 42.00°`:

  | handle | k | `C2` becomes | table meet x, y | x/y drift | height above girdle top |
  |---|---|---|---|---|---|
  | 46.00° | 1.150073 | 32.5173° | +0.630938907, +0.261343452 | 2.5e-16 | ×1.150073 |
  | 38.00° | 0.867706 | 25.6865° | +0.630938907, +0.261343452 | 8.3e-16 | ×0.867706 |
  | 50.00° | 1.323576 | 36.2664° | +0.630938907, +0.261343452 | 6.5e-16 | ×1.323576 |

  X and Y are identical to every digit; the height ratio is `k` exactly, **measured from the girdle top
  rather than from the origin**, because the `girdle` meet form pins the band to an absolute thickness
  that does not scale.
  **This is why a single-tier angle change is not the tuning operation.** Measured the same way, moving
  `C1` alone from 42° to 46° with the other crown tiers untouched grows the table's radius from `0.682923`
  to `0.771228` — **13%** — which destroys exactly the facet placement the rescale exists to hold. A
  single-tier angle edit remains available while *authoring*, where angles are being entered from a sheet
  and no plan view is being preserved yet; it is not what tuning does.
  **Negative requirement: never update heights only.** Even though the rescale changes nothing in the plan
  view, an implementation that shifted depths without re-solving would be wrong, because each tier's
  offset has to come back out of its own meet.

- **I2** — **The rule this establishes: structural edits are refused, geometric consequences are
  reported.** An angle change can never orphan a reference, so it is always permitted; but it can make a
  meet unreachable, cut a tier away entirely, or stop the solid closing, and those are reported through
  validation rather than blocked — **the author has to be able to pass through an invalid stone while
  tuning.**

- **I3** — **A pattern can be rotated by a quarter turn, and only by a quarter turn.** It adds `wheel/4`
  to every tier's stops and to every index inside every `vertex` reference, modulo that tier's wheel. It
  solves the real case — a design authored wide on 90–270 that should read as long on 0–180 — and **it is
  the only rotation that leaves the stone unchanged**: a quarter turn swaps the two axis extents, so the
  smaller is unchanged, and with width defined as the smaller the width, the `L/W` and the girdle band
  sized from width (`Solver.swift:243`) all survive untouched. **Every permitted wheel divides by 4** —
  32, 64, 72, 80, 84, 88, 96, 120 — so a quarter turn is always a whole number of stops, including on a
  tier carrying its own wheel.
  Rejected: rotation by an arbitrary number of stops. Geometrically it is a rigid rotation, but the design
  stops aligning with the axes width and length are measured along, so both extents grow, `L/W` becomes a
  fact about a bounding box rather than about the stone, and the `girdle` meet resizes the band from the
  changed width — **the stone quietly becomes a different stone.** It is also not always expressible: 5
  stops of 96 is 6.25 stops of 120, and fractional stops are forbidden. Free rotation, if ever wanted,
  should be a deliberate "re-author in a new orientation" operation that admits it changes the design.

- **I4** — **A tier's angle can be derived from its index and two picked points, the derivation is
  app-side, and what the file stores is the resolved angle plus the *three-facet vertex* as the tier's
  `meet`.** This is the common authoring case rather than an occasional one — a sheet gives the index and
  says where the facet has to arrive, and the angle is whatever gets it there.
  **The arithmetic is closed form, with no iteration and no solver change.** The index and wheel fix the
  facet's azimuth and its `part` fixes the normal's `z` sign (`Plane.swift:34`), so the plane `n · p = d`
  has exactly two unknowns, the angle `a` and the offset `d`, and two points supply two equations.
  Projecting each point onto the facet's own azimuth as `r = x·cos θ + y·sin θ`, subtracting the two
  equations gives **`tan a = s · (z₂ − z₁) / (r₁ − r₂)`** with `s` the part's `z` sign, and `d` follows
  from either point. The app writes `a` to 2 decimal places like any other angle.
  **Why app-side and not a sixth meet form:** the corpus's own sheets print resolved angles, so a pattern
  authored this way is indistinguishable in the file from the four already authored, the reproduction bar
  in `4-Cutting-Bench-Authoring` is untouched, and the solver keeps taking the angle as input and deriving
  only depth. Rejected: a format-and-solver change carrying both points with the angle absent — it would
  preserve the second constraint and re-derive after a tangent-ratio rescale, and the rescale does
  preserve it (scaling every height on a side by `k` maps a two-point plane onto the `k`-scaled plane,
  which is **I1**'s result), but it makes the solver solve tilt and offset simultaneously instead of
  normals-then-depth, and it is a third format change on top of `instructions` and the girdle target.
  **Which point is written exactly, and which is allowed to slide, is settled by priority rather than by
  order: a three-facet vertex is the point that must be hit, so it is the end written as the `meet`.** A
  point 23% along an edge is a coordinate rather than a design quantity
  (`design-authoring-format.md:283`), so a small slide there costs nothing. **When both ends are the same
  kind — two vertices, or two fractions — the first picked is written**, since either is then exact to
  within the same rounding.
  **The slide is negligible, computed rather than assumed.** Rounding the angle to 2 dp perturbs the tilt
  by at most 0.005°, which moves a point at radius ≤ 1.5 by **≤ 1.3 × 10⁻⁴** — under 0.007% of width on a
  stone normalised to width 2, and below the precision the format itself writes
  (`design-authoring-format.md:100`). **So no residual readout is added and nothing is reported.**
  **The second point is not recorded anywhere**, and a tier authored this way carries no mark
  distinguishing it from one whose angle was typed. An author who wants the intent kept writes it in that
  tier's `instructions`, which is the field's purpose.
  **This does not breach the format's rule against a tool choosing a meet's endpoints**
  (`design-authoring-format.md:281`). The author picks both points by clicking, and the percentage comes
  from where they clicked, never from a depth already reached.

- **I5** — **A two-point derivation that cannot produce the clicked facet is refused at pick time, and
  each of the three ways it fails has its own named diagnostic carrying the numbers.** Nothing is written
  and the tier keeps the angle it had. The three cases:
  1. **The two points coincide on the facet's azimuth** — same `r` and same `z` after projection, so there
     is no line to fit. Names the tier, the aimed index, and both points' `r` and `z`.
  2. **The implied tilt contradicts the tier's declared `part`** — `tan a` comes out negative, meaning a
     `pav` tier whose two points imply an upward-facing plane or the reverse. Reports the signed angle the
     arithmetic produced, before rejection, plus both points and the tier's `part`.
  3. **A sibling facet of the same tier takes the depth**, so the aimed facet stops short of both points.
     Names the aimed index, the index that arrives instead, the derived angle, and the two dot products.
  **Refusing the third case is the one that needs justifying, and the reason is that the kernel reports
  nothing for it.** `vertexNotOnIntermediateSolid` (`Validation.swift:20`) checks the *named point* is a
  corner of the intermediate solid, which it genuinely is; **nothing checks that the facet the author
  aimed is the one that gets there**, because which facet arrives is determined rather than chosen
  (`design-authoring-format.md:234`). So allowing it would store a stone the author did not click and
  validate clean afterwards.
  **A tie is not a failure** — two of the tier's facets within `1e-7` of the same dot product means the
  point sits on the edge between them and the depth is the same number either way, which is the tolerance
  `Validation.swift:311` already uses at this scale.
  **Each refusal is both shown and logged**, per the refusal idiom inherited from
  `4-Cutting-Bench-Authoring`. **The requirement is that the three cases never collapse into one message:** a
  derivation that failed for an unstated reason is the failure mode this decision exists to prevent.

## UI / UX

- **U1** — **Tangent-ratio tuning is one field that both types and drags, and it never commits without
  showing every angle it is about to change.** The author works on a tier's angle: **typing a value
  commits on return, and dragging previews the whole side live** so the stone stretches under the pointer,
  which is the feedback tuning actually wants.
  **Dragging is throttled to what the current pattern can re-solve in** — a few milliseconds at 37–73
  facets, about 0.6 s at 139 — so the same gesture cannot be allowed to queue re-solves it will never
  finish.
  **The preview is mandatory, not a nicety.** One gesture rewriting nine tiers' angles is the most
  surprising thing in this design, so **the inspector's tuning section lists every affected tier with its
  current and proposed angle, and the ratio**, updating as the drag moves. Nothing is written until
  commit.
  **Commit granularity matches the gesture: the whole side is one undoable action**, not one per tier — a
  gesture that changed nine tiers must undo as one. That comes from the document's undo manager.
  Constraints carried from **I1**: the girdle never takes part, and a `0.00°` tier cannot be the handle
  since the ratio would be undefined.
  Rejected: a typed field alone, which gives no sense of sweeping through a range; drag alone, which cannot
  hit an exact target angle; and setting the ratio directly rather than a target angle — truest to the
  operation, but the author thinks in the angle the material wants, not in the ratio that gets them there.

- **U2** — **The quarter turn is a single menu command with no options**, since there is exactly one
  rotation available (**I3**) and nothing to configure. It is one undoable action.

- **U3** — **The two-point derivation reuses the picking state machine unchanged.** The author aims a
  tier, then clicks two points exactly as they would build a meet — the same edge grab radius, the same
  10% end-snap zones, the same two-facet-to-edge rules, the same refusal of anything defined by a rough
  plane. What differs is only what happens on completion: the angle is computed, the three-facet vertex is
  written as the meet, and the second point is discarded.
  **A point whose defining planes include a rough plane is refused as the discarded second point too**,
  even though nothing about it would reach the file. It is not forced — the file would come out clean —
  but the prism is a build constant with no design meaning, so an angle derived against it would bake an
  arbitrary number into the pattern while looking like a designed one, and nothing in the file would
  record where it came from.

## ADR candidates

None. The tangent-ratio rescale (**I1**) is the substantial decision here, and it is a real trade-off
verified numerically — but it is neither hard to reverse, being a pure transform over a pattern's angles
with nothing persisted, nor surprising in context, since tangent ratio is the standard operation named in
`Design/Glossary.md`.

## Open — queued, in ask order

- **Left unresolved:** **the non-flat-girdle design.** The owner knows of exactly one pattern with a
  non-flat girdle and has not looked it up yet; ignoring the case is accepted for this build. What the
  rescale does to it is defined and deliberately conservative — a `gdl` tier is never rescaled (**I1**),
  so a non-flat girdle stays rigid while the rest of its side stretches, which will look wrong rather than
  silently move the outline. The case is unresolved only in the sense that nobody has yet seen the pattern
  to know whether that is acceptable. **No ticket filed:** there is nothing actionable until the pattern
  is found, and the behaviour is defined either way.

## Notes

- **The critical-angle marking is the readout this slice most depends on**, and it is built in
  `3-Cutting-Bench-Pattern-Display`. Scaling a pavilion shallower is exactly how mains cross the leakage
  threshold, so a rescale that moves a pavilion tier past `asin(1/ri)` must show it on the tier row
  immediately.
- **Tuning invalidates a whole side onward in the per-tier validation cache**, since it rewrites every
  angle on that side. Expected, not a flaw in the caching scheme.
- **The two-point derivation is an authoring input method that landed in this slice rather than in
  `4-Cutting-Bench-Authoring`**, because it shares its arithmetic and its whole justification with the
  angle work here rather than with the meet-picking work there. The picking machinery it reuses is
  inherited, not rebuilt.
