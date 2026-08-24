# 1 · Cutting Bench Kernel Changes — Exploration

Status: **CLOSED 2026-08-23**
Started: 2026-08-22 · via /a-explore · split from `Cutting-Bench-App` on 2026-08-23
IDs: **S** = scope · **I** = implementation · **U** = UI/UX

Everything `FacetKernel` and `design-authoring-format.md` must gain before the Cutting Bench app can
open, display, author or verify a pattern. **No app code is in this slice** — it is verified entirely
by `swift test` and by running `facetsolve`, which is what makes it the one slice that can be built
and checked with no window on screen.

One of five explorations split from `Cutting-Bench-App`, one per plan. Siblings:
`2-Cutting-Bench-App-Shell`, `3-Cutting-Bench-Pattern-Display`, `4-Cutting-Bench-Authoring`,
`5-Cutting-Bench-Angle-Tuning`.

## Grounding

What exists today, anchors re-verified 2026-08-23:

- **The kernel is complete and public**: `Solver.swift:102`
  (`public func solve(_ pattern: Pattern, girdleTargetFraction: Double = 0.04) throws -> Solution`),
  `Validation.swift:61`
  (`public func validate(_ pattern: Pattern, _ solution: Solution, declaredFacetCount: Int?) -> Report`),
  `Metrics.swift:67` (`public func metrics(_ solution: Solution) -> Metrics`).
- **The kernel cannot write a pattern file.** `Pattern.swift:81`
  (`public struct Pattern: Decodable, Sendable`), `Pattern.swift:54`
  (`public struct TierSpec: Decodable, Sendable`) and `Pattern.swift:21`
  (`public indirect enum Meet: Decodable, Equatable, Sendable`) are decode-only, and no `Encodable`
  conformance or encoder exists anywhere in `Kernel/Sources`. `FacetRef`, `Part` and `PatternState`
  are already `Codable`.
- **All three decoders are hand-written**, so their encoders will be too: `Pattern.swift:187`
  (`public init(from decoder: any Decoder) throws` — `Meet`), `:233` (the same for `TierSpec`), `:283`
  (the same for the header). Each reads named keys and ignores unknown ones.
- **The solve is all-or-nothing.** `Solver.swift:199` (`for spec in pattern.tiers {`) throws out of the
  entire solve, so a single unfinished or wrong tier returns no `Solution` at all — not even the tiers
  cut before it. The partial state already exists at the moment it throws and is simply discarded.
- **The intermediate solid a scrubber needs exists but is not public**: `Validation.swift:78`
  (`func intermediateSolid(before tier: String, of solution: Solution) -> Polytope`), with
  `Validation.swift:88` (`func planes(of tier: SolvedTier) -> [Plane]`) alongside it.
- **`validate` is one entry point over three private halves**: `Validation.swift:101`
  (`private func structuralFindings`), `:172` (`private func geometricFindings`), `:213`
  (`private func closureFinding`).
- **`Meet.namedTriples` is internal**: `Validation.swift:284` (`var namedTriples: [[FacetRef]] {`).
- **`Metrics` has no `T/W`.** `Metrics.swift:8` (`public struct Metrics: Sendable`) lists thirteen
  fields and the table extent is not among them; it is derived in the CLI at `main.swift:152`
  (`func tableOverWidth(_ solution: Solution, width: Double) -> Double`).
- **Width is fixed to one axis today.** `Solver.swift:107` documents *"`width` along the 90-270 degree
  axis, `length` along 0-180"* over `Solver.swift:116` (`func girdleOutlineExtent`), and
  `Metrics.swift:196` (`private func outlineExtent(of solution: Solution)`) consumes it.
- **The girdle target is a caller's parameter, not a file field**: `Solver.swift:102` defaults it to
  `0.04`, and `main.swift:24` records *"The girdle band's thickness as a fraction of the width. Each
  source diagram measures its own"*. `Solver.swift:243` shows it multiplied by `extent.width`, so it
  sizes the band from the width.
- **The kernel already accepts any positive wheel**: `Pattern.swift:290`
  (`guard wheel > 0 else { throw PatternError.invalidWheel(tier: nil, wheel...`), and the per-tier
  override at `Pattern.swift:249` (`if let declaredWheel, declaredWheel <= 0 {`) only rejects `<= 0`.
  Index range is checked at `Pattern.swift:301`
  (`for index in tier.indices where index < 0 || index >= stops {`).
- **The meet forms the solver resolves**: `Solver.swift:226` (`return 1` — `size`), `:235`
  (`return sin(radians(spec.angle))` — `tcp`), `:243` (the `girdle` band), `:248`
  (`case .fraction(let from, let percent, let to):`).
- **`facetsolve` is the existing diagnostic**, permanent and explicitly not the app: `main.swift:8`
  (*"this is how a headless kernel gets verified. It is a permanent"* / diagnostic and not the app). It
  exits non-zero only when a *finished* pattern has findings — `main.swift:345`
  (`exit(findings.isEmpty || pattern.state == .inProgress ? 0 : 1)`).
- **Geometry a renderer can consume already exists**: `Polytope.swift:11`
  (`public var facets: [Int: [Int]]`), with `Solver.swift:29`
  (`public var planeOwner: [Int: (tier: String, index: Int)]`) mapping every plane back to the tier and
  index stop that cut it. `Polytope.swift:47` (`public func intersectHalfSpaces`) is already public.
- **Four patterns are authored**: `Design/Patterns/Pattern-Easy-Octagon.json`,
  `Pattern-Novice-Ash-er.json`, `Pattern-Rands-Cut-Corner-Rectangle.json`,
  `Pattern-Standard-Round-Brilliant.json`.
- **Constraints already declared** in `Design/Execution-Protocol.md`: no third-party dependencies;
  `design-authoring-format.md` changes only via a task that names it (`:90`); the four patterns'
  fixtures and the round-brilliant expected values are external ground truth and may never be edited
  nor their tolerances loosened.

## Inherited

Nothing. This slice is the base and depends on no sibling. Each decision below names the consumer that
wants it, so a reader can see why a kernel change exists without opening the sibling that uses it.

**Sequencing note: `2-Cutting-Bench-App-Shell` does not depend on this slice.** Opening a window,
rendering the rough prism and decoding a pattern all work against today's kernel, so the shell can be
built before or alongside this. The first slice that genuinely needs these changes is
`3-Cutting-Bench-Pattern-Display`.

## Tickets folded in

- **`Chore-Kernel-Measures-Split-Between-Library-And-Callers`** — asks whether `T/W` and the closure
  rule should move into `FacetKernel`, and says outright that "the GUI will want the table size as a
  metric rather than as CLI output." **Answered by I9** for `T/W` and by **I8** for the closure rule,
  whose third piece makes `closureFinding` reachable so `ScaleTests.swift` need not restate it. **This
  plan closes it.**

## Scope & purpose

- **S1** — **This slice ships the kernel and format changes the bench app needs, and nothing else.**
  Done means: `swift test --package-path Kernel --disable-sandbox` green, `xcrun swift-format lint
  --recursive --strict Kernel/Sources Kernel/Tests` clean, `facetsolve` still solving all four authored
  patterns to the same figures, and the new encoder round-tripping every one of them to a file that
  decodes back equal.
- **S2** — **The kernel learns nothing about rough stone, and nothing about drafts.** Both belong to the
  app. A rough-capped solid always closes, so feeding rough into the solve would silently defeat the
  closure check the tool exists to run (`design-authoring-format.md:437` — `The solid has to close.`);
  and a half-authored tier's rules are UI policy, not geometry.
- **S3** — **No volume code and no rough-retention metric.** What the game will eventually need is a
  primitive — the volume of a polytope — not this tool's metric, and its inputs already sit in
  `Polytope.vertices`. When the game needs it, polytope volume goes in `FacetKernel` and anything about
  rough stays out.

### Non-goals

- **No app code, no window, no renderer.** Those are the four sibling slices.
- **No change to `solve`'s existing throwing signature** (**I3**), so `facetsolve` and the twelve
  existing test files are untouched.
- **No `formatVersion` bump** (**I1**, **I5**) — both new fields are optional and additive.
- **No GemCad interop**, no printing, no game mechanics, no fractional index positions, nothing for
  iPad. Carried forward unchanged from the archived exploration `Cutting-Bench`.

## Implementation

- **I1** — **Tier rows gain `instructions`, an optional free-text field aimed at the next human**, and
  the kernel carries it without ever interpreting it. Tiers only — the header keeps its existing `notes`
  for design-level prose, and a second header field would mainly raise the question of which one to
  write in. The name is `instructions` rather than `notes` because it is addressed to someone about to
  cut rather than to someone checking a claim: the header's `notes` is scoped by
  `design-authoring-format.md:74` to `material spec, size and girdle tolerances, anything the sheet
  says`. `C2@14`-style machine reference is unaffected and stays exactly as it is.
  **The content is user-entered prose, and nothing generates it.**
  **Carry is not the same as ignore.** `TierSpec` must hold the field and round-trip it, or saving
  silently deletes the author's prose. Nothing in `Solver`, `Validation` or `Metrics` reads it.
  **No `formatVersion` bump is needed, and this was checked.** A file carrying it decodes on today's
  kernel because the hand-written `TierSpec` initialiser (`Pattern.swift:233`) reads named keys and
  ignores unknown ones, and a file without it decodes on the new kernel as absent. **Absent and empty
  stay distinguishable.**
  **This is a change to `design-authoring-format.md`**, which changes only via a task that names it
  (`Execution-Protocol.md:90`), so one task covers both the format document and `TierSpec`.
  Consumed by `3-Cutting-Bench-Pattern-Display` (shown when viewing a tier) and
  `4-Cutting-Bench-Authoring` (edited).

- **I2** — **`FacetKernel` owns writing complete pattern files.** `Pattern`, `TierSpec` and `Meet`
  become `Codable`; the app converts its own draft into a `Pattern` and hands it over. The reason is not
  that authoring belongs to the kernel but that **the file is the one artifact that must be identical
  everywhere, and it already has exactly one reader here** — and that reader is not a thin parser:
  `Pattern.swift:283` onward enforces the format's rules on the way in, with `PatternError` covering
  duplicate tier labels, out-of-range and non-integer index stops, unknown meet kinds, and a vertex that
  does not name exactly three facets. One writer beside that one reader is what keeps round-tripping
  honest, and the game's own authoring inherits it rather than growing a second writer that can quietly
  disagree.
  Cost, accepted: `Meet` decodes through a hand-written initialiser (`Pattern.swift:187`), so its
  encoder is hand-written too and **needs a round-trip test**. A stock `JSONEncoder` emits `90` where the
  authored files write `90.00`, which `design-authoring-format.md:100` states is the same value
  (`Write it to 2 decimal places; 90.00 and 90 are the same value`), so nothing is owed there.
  Recorded as **ADR-0003**; see *ADR candidates*.

- **I3** — **The kernel gains a non-throwing partial solve: the tiers it placed, plus the failure that
  stopped it.** A half-solving pattern is the normal state of authoring, not an edge case, and today it
  is a cliff — `Solver.swift:199` throws out of the whole solve. The partial state already exists at the
  moment it throws (`Solve` accumulates `tiers`, `planes` and `owner` as it goes) and is discarded.
  **`solve`'s existing throwing signature is kept and the partial form is a sibling**, so `facetsolve`
  — a permanent diagnostic (`main.swift:8`) — and the twelve existing test files are untouched.
  **What a partial solve actually looks like, measured rather than assumed** — running the built
  `facetsolve` on truncated copies of `Pattern-Easy-Octagon.json`: the girdle tier alone yields **0
  facets**, because eight vertical planes are mutually parallel about the axis and no triple of them
  meets at a point; girdle plus the first pavilion tier yields **8 facets, all of them the pavilion's**,
  the girdle planes still contributing none because an open-topped solid gives each of them only two
  vertices and `Polytope.swift:67` (`guard onPlane.count >= 3 else { continue }`) drops a plane below
  three. So a pattern's own planes render a floating pavilion cone with no girdle and no top until
  something caps the solid.
  Consumed by `3-Cutting-Bench-Pattern-Display`, which renders as far as the solve got and marks the tier
  that stopped it.

- **I4** — **Three internal symbols become public, for the app to build display geometry and answer
  reference questions.** No behaviour changes.
  1. `intermediateSolid(before:of:)` (`Validation.swift:78`) and `planes(of:)` (`Validation.swift:88`)
     — how the app builds any prefix of the solved planes, for the scrubber and for the
     while-picking display. Wanted by `3-Cutting-Bench-Pattern-Display`.
  2. `Meet.namedTriples` (`Validation.swift:284`) — how the app answers "which tiers reference this
     facet". Reimplementing it app-side would put knowledge of how a meet names facets outside the
     module that owns the format. Wanted by `4-Cutting-Bench-Authoring`.

- **I5** — **The girdle target goes into the format as an optional header field, a fraction of width,
  absent meaning `0.04`.** It is the one input a `girdle` meet needs that choosing the form does not
  supply, it is not in the file today, and `Solver.swift:102` takes it as a parameter defaulting to
  `0.04` while `main.swift:24` records that each source diagram measures its own. The deciding argument
  is the format's own test: **it changes the stone.** `girdleFractionOfWidth` comes out of `metrics`, so
  a pattern reopened at a different girdle target does not reproduce its own verified geometry —
  precisely the silent disagreement the one-representation rule exists to prevent. Real patterns differ:
  `Rand's` measures 4.05% of width from its diagram, and `SUPERPEAR 96` asks for 1.6–3.2%.
  **The four authored patterns are unchanged by this, and that was checked** — `facetsolve` solves all
  four at the `0.04` default today and each reports its girdle at exactly 4.000% of width, so
  absent-means-`0.04` reproduces them bit for bit. **No `formatVersion` bump**, for the same reason as
  `instructions`: the field is optional and additive, and the hand-written header initialiser
  (`Pattern.swift:283`) reads named keys and ignores unknown ones.
  Rejected: an app-wide preference, wrong for any pattern whose sheet specifies otherwise; per-document
  app state not saved to the file, which loses the value on reopen and so changes the stone between
  sessions; and leaving it in `notes` as free text for the author to retype, which puts machine-relevant
  data in a human field.

- **I6** — **Width and length are the outline's extents along the two fixed axes, with the labels
  assigned by size: the longer is length, the shorter is width.** So `L/W` is always ≥ 1, which is the
  convention published sheets follow even though authors differ on which axis they draw the long
  dimension along.
  **This is a change from the shipped code**, which fixes width to the 90–270 extent and length to
  0–180 (`Solver.swift:107`). A 2:1 stone drawn long on 90–270 therefore reports `L/W = 0.5` today —
  measured, with cut corners at `12 36 60 84` and the short axis at 0.5: x-extent 1.00000, y-extent
  2.00000, so today's rule gives width 2.0 and length 1.0. Assigning by size gives width 1.0, length
  2.0, `L/W = 2.0`. The cut corners do not disturb it at corner offsets of either 0.90 or 1.00, because
  the axis extremes survive.
  **All four authored patterns are unchanged, so the round-brilliant anchor stays green** — Easy Octagon
  and Novice Ash-er are 2.0 by 2.0, the round brilliant 2.03918 both ways, and `Rand's` already reads
  width 1.464102 against length 2.0, which is the smaller-is-width order.
  **Measuring along the axes rather than corner-to-corner is deliberate.** The maximum caliper across
  any direction for that cut-corner example is 2.07308, reached between two opposite corner-cut
  vertices — so a maximum-breadth rule would report a cut-corner rectangle as longer than it is. A
  faceter measures a rectangle along its length.
  **This also corrects `design-authoring-format.md:196`, which states that width is "twice the
  *minimum* girdle-plane offset computed from the solved outline".** Nothing implements that and the
  published diamond proportions contradict it: `RoundBrilliantTests.swift:28` pins
  `(pavilion: 0.466, crown: 0.218, height: 0.704, table: 0.516)` at `tolerance = 0.001` against
  `widthNormalised == 2.03918`, giving P/W 0.4663; the minimum-offset rule would make width 2.0 and
  P/W 0.4754, **nine times the tolerance out**. A round brilliant's width is the girdle diameter its
  facets are chords of, not the inscribed radius of its flats.
  **Consequence: width becomes invariant under a quarter turn**, since swapping the two extents leaves
  the smaller unchanged — which matters because the `girdle` meet sizes the band from width
  (`Solver.swift:243`, `* extent.width`), and because `5-Cutting-Bench-Angle-Tuning` rotates patterns by
  exactly a quarter turn.
  **Known limitation, recorded rather than solved:** a design whose own axes are not 0–180 and 90–270 is
  measured against axes that are not its own. `Metrics.mirrorAxes` already computes a stone's actual
  mirror axes if that ever needs addressing.

- **I7** — **There are eight index gears: 32, 64, 72, 80, 84, 88, 96 and 120.** 96 and 120 are the
  common ones; the others exist for symmetries the common two cannot reach — **84 is what makes 7-fold
  possible and 72 is what makes 9-fold possible**, neither being a divisor of 96 or 120.
  **No kernel change: it already accepts any positive wheel.** `Pattern.swift:290` guards only
  `wheel > 0` and the per-tier override at `Pattern.swift:249` only rejects `<= 0`, so the enumerated
  set is advice rather than validation. **The stale list is in the format document** —
  `design-authoring-format.md:71` says `96, 120, 64 or 80` — and correcting it joins the same task as
  the other format edits. The picker that offers these eight belongs to `4-Cutting-Bench-Authoring`.
  **Every permitted wheel divides by 4**, which is what makes a quarter turn always a whole number of
  stops in `5-Cutting-Bench-Angle-Tuning`.

- **I8** — **Validation splits three ways, as a decomposition rather than an optimisation.** `validate`
  is one entry point today (`Validation.swift:61`) and becomes three separately callable pieces.
  1. **Structural, pattern-wide and free** — forward references, a meet naming its own tier's facet,
     unknown facets, singular triples, a second `tcp` on a side, the exactly-one-`size` rule. Needs no
     solid at all, because whether three planes meet at a point depends on their normals, and a normal
     comes from an angle and an index stop. `structuralFindings` is private today
     (`Validation.swift:101`).
  2. **Per tier, cacheable** — the named-point check against the intermediate solid. **Tier *k*'s
     result depends only on the tiers before *k***, which is provable from the code rather than
     assumed: `intermediateSolid` (`Validation.swift:78`) walks tiers and breaks at the named one, so
     nothing added later can change an earlier tier's result. **Editing tier *j* therefore invalidates
     *j* onward and leaves everything before it untouched**, and appending a tier validates exactly one
     tier instead of re-validating all of them. This is what turns `tiers × planes³` into `planes³` per
     tier added.
  3. **Whole-solid, never cacheable** — closure, facet count. These change whenever any tier changes,
     and are cheap given a solve that has already built the polytope. **Making `closureFinding`
     (`Validation.swift:213`) reachable lets `ScaleTests.swift` drop its restatement of the closure
     rule**, which is the second half of the folded-in ticket.
  **The cache itself is not in this slice** — it is app state, and it belongs to
  `4-Cutting-Bench-Authoring`, which is where edits happen and where the ticket
  `Chore-Validation-Rebuilds-The-Solid-Once-Per-Tier` is closed. What this slice owes that slice is
  three callable pieces and the documented per-tier independence above.

- **I9** — **`T/W` moves into `FacetKernel`'s `Metrics`.** It is derived in `main.swift:152`
  (`func tableOverWidth`) today, on the stated grounds that the kernel's metrics are the ones the game
  needs — but the app needs it as well, so leaving it in the CLI would put one definition in three
  places. `facetsolve` then reads the metric rather than computing it.

- **I10** — **The ray probe's trace lives in `FacetKernel`.** The kernel takes a solid, an `ri`, an
  entry point and a direction, and returns the path as a list of segments plus how it ended. The app
  owns the click and the drawing. That split matches **S2**'s: geometry and physics in the module the
  game inherits, picking and pixels in the app. The game will want this — "light performance" is a game
  concern before it is an authoring one.
  **Single path, never a split.** At each internal surface the ray either exceeds the critical angle
  and reflects, or does not and leaves. Fresnel splitting would double the rays at every bounce and
  produce an unreadable picture. **One wavelength, `ri` as authored; no dispersion**, since the format
  carries a single scalar.
  **Finding the next surface is one pass over the planes**, taking the nearest forward-facing hit —
  valid because the solid is convex by construction, being an intersection of half-spaces. So a bounce
  costs O(planes) and the whole probe is trivial beside a solve. **Bounces are capped** so odd geometry
  cannot loop forever.
  **The returned readout includes the angle of incidence at each bounce against the critical angle**,
  which is what says *why* a ray leaked rather than only that it did.
  **The critical angle itself is `asin(1/ri)`** — arithmetic, not rendering. Where it is compared
  against each pavilion tier's angle and displayed belongs to `3-Cutting-Bench-Pattern-Display`.

## UI / UX

**N/A — this slice has no user-facing surface.** It is a library and a format document; the only thing
a human runs is `facetsolve`, whose output format is unchanged except that `T/W` is now read from
`Metrics` rather than computed locally (**I9**).

## ADR candidates

**None to write.** The one decision this slice would have nominated — the kernel owning the pattern
file's reader *and* writer, with the app owning the half-authored draft (**I2**) — is **already
recorded** at `Design/Decisions/0003-kernel-owns-the-file-app-owns-the-draft.md`, accepted 2026-08-23.
It refines rather than supersedes ADR-0001 and ADR-0002. Carry it into the plan's Decisions table; do
not write it again.

## Open — queued, in ask order

Empty. Nothing in this slice is unresolved.

## Notes

- **Two fields the format gains in this slice**, both in the one task that names
  `design-authoring-format.md`: per-tier `instructions` (**I1**) and the header girdle target
  (**I5**). That same task also corrects the width definition at `:196` (**I6**) and the stale gear
  list at `:71` (**I7**). Four edits, one task, because the guardrail is that the document changes only
  via a task that names it.
- **Generating a tier's `instructions` from its meet may be worth doing later, and this slice
  deliberately does not.** The corpus table at `design-authoring-format.md:401` is close to a
  generation rule read backwards — a `girdle` meet is `set girdle thickness`, a first-per-side `tcp` is
  `Cut to centerpoint`. Two consequences for how the field is built now, so automation is an addition
  rather than a breaking change: the field is a plain stored string and never a derived value, and
  **absent means the author wrote nothing, not "generate one"** — so a future generator can offer text
  without ever silently overwriting prose a human typed.
- **The declared facet count needs nothing from this slice.** `validate` already takes
  `declaredFacetCount: Int?` (`Validation.swift:61`) and `facetsolve` passes `nil`, so the check exists
  and has never had a caller. Giving it one belongs to `3-Cutting-Bench-Pattern-Display`.
- The archived exploration `Cutting-Bench` carries a banner listing four of its own claims that shipped
  code contradicts. Reference material only.
