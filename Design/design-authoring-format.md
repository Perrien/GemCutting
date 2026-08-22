# Design Authoring Format

How to write a faceting design so the engine can solve, draw, cut and grade it. Written for the
faceter doing the authoring, not for the parser.

Decided in [Design Data Model](../../.scratch/faceting-game/issues/03-design-data-model.md);
rationale in [ADR-0002](../adr/0002-meet-constraints-not-depths.md).

## The one idea behind the format

**You do not write down depths. You write down what each tier meets.**

A mast angle plus an index position fixes a facet's *tilt and rotation* but not *how deep it is
cut* — which is why a printed cutting table alone is not enough to draw a stone. The meetpoint is
what supplies that last number. So meetpoints here are not instructions sitting alongside the
data; they **are** the data.

**One meet per tier is all that's needed.** A tier is one mast-angle setting whose facets you
index around and cut to the same dial reading, so they all share one depth. Give the meet for a
single facet and the whole tier is placed. You never have to write out the other facets' meets —
the engine works those out from the index positions when it needs to show them to the player.

**A meet describes the stone at the moment that tier is cut — not the finished stone.** This is
why references point backwards only: the thing you aim at has to exist *then*. It does not have to
survive to the end, and usually it won't. Points in particular are routinely cut away by later
tiers; facets usually survive, though they can be removed entirely. Reading a meet as a claim about
the finished solid rejects most real cutting sequences.

Two consequences run through everything below. **Solve in dependency order; validate against the
intermediate solid.** Computing a tier's depth needs only the plane offsets of the tiers its meet
names — three planes fix a point by algebra alone — so no solid is involved and the whole design can
be re-solved at once, tiers ordered by dependency. What *does* need the intermediate solid is
checking that a named point is a real vertex rather than a phantom plane intersection, since a point
can exist at one tier and be gone by the next. And **a design's tier order is data, not
presentation** — see the rule at the end.

## The file

**A design is one JSON file.** Two parts: a header, then an array of tiers. There is exactly one
representation — the tool's save format, the game's load format and the thing verified on screen are
all this file, so they cannot disagree.

JSON rather than a table because the tool reads *and* writes it (`Cutting-Bench` **I16** puts format
I/O in the kernel), and because most of the rules below stop being rules and become shapes: `part`
and a meet's `kind` are enums, a vertex's three facets are a three-element array of typed pairs, and
an optional per-tier wheel is an absent field rather than a mostly-blank column.

```json
{
  "formatVersion": 1,
  "name": "Easy Octagon",
  "state": "finished",
  "wheel": 96,
  "ri": 1.54,
  "designer": "USFG Competitions. No individual designer named on the source sheet.",
  "notes": "…",
  "tiers": [
    { "tier": "G1", "part": "gdl", "angle": 90.00, "indices": [0, 12, 24, 36, 48, 60, 72, 84],
      "meet": { "kind": "size" } }
  ]
}
```

### Header

| field | notes |
| --- | --- |
| `formatVersion` | integer, currently `1` |
| `name` | the design's published name |
| `state` | `"in progress"` or `"finished"` — see below |
| `wheel` | the design's **default** index wheel: 96, 120, 64 or 80. Any tier may override it |
| `ri` | the refractive index the design was drawn for |
| `designer` | attribution — name, publication, competition, year |
| `notes` | free text: material spec, size and girdle tolerances, anything the sheet says |

`wheel` was called `index` while this was a table, which read confusingly against a tier's
`indices`. Same field, clearer name.

**`state` exists because a design can always be saved.** A half-authored design is normally invalid —
nothing closes until the last tier — so validity cannot gate ordinary work, but an invalid design
escaping silently would destroy the trust the format exists to create. Only a `finished` design must
be fully valid; the rules at the end are enforced against it. An `in progress` design has its
failures *reported*, not refused.

**Do not author these — they are computed:** facet count, symmetry order and whether it's
mirrored, L/W ratio, girdle thickness target, difficulty. If a printed sheet declares one, put it
in `notes` and it becomes a cross-check rather than the source of truth. (Worth knowing why:
`Apex Pinwheel` declares *8-fold mirror symmetry* but is a pinwheel, so rotational-only. Declared
metadata is a claim, not a fact.)

Symmetry is not stored at all, not even as a generator. A tool may expand a seed set plus a symmetry
setting into `indices`, but what lands in the file is the full index list.

### Tiers

| field | notes |
| --- | --- |
| `tier` | your label — `"P1"`, `"G1"`, `"C1"`, `"T"`, or `"1"`/`"A"`, whatever the design uses |
| `part` | `"pav"`, `"gdl"`, `"crown"` or `"table"` |
| `angle` | mast angle, a number. Write it to 2 decimal places; `90.00` and `90` are the same value |
| `indices` | array of integer index positions. Whole numbers only — no cheaters |
| `wheel` | **optional.** Overrides the design default for this tier only |
| `meet` | the meet — see the five forms below |

`part` matters and can't be guessed: crown and pavilion angle ranges genuinely overlap. `Easy
Does It` has pavilion tiers at 43.60 and 41.00 and crown tiers at 42.00, 41.50 and 39.40. Since
you're authoring, just say which.

**`wheel` per tier is a gear change mid-cut** — a real operation on a real machine. Tiers before it
are untouched; it only changes the number used to compute that tier's planes, `theta = 2π · index /
wheel`. It also dissolves an edge case rather than adding one: a 96-wheel `24` is not a 120-wheel
`24`, so changing a design-wide wheel after tiers exist would silently corrupt indices. Per tier,
changing the default simply applies to tiers added afterwards.

### The `meet` object

One of five shapes, tagged by `kind`:

```json
{ "kind": "tcp" }
{ "kind": "size" }
{ "kind": "girdle" }
{ "kind": "vertex",   "facets": [ {"tier":"G1","index":0},
                                  {"tier":"G1","index":12},
                                  {"tier":"P1","index":0} ] }
{ "kind": "fraction", "from": { "kind": "vertex", "facets": [ … ] },
                      "percent": 40,
                      "to":   { "kind": "tcp" } }
```

`percent` and the two endpoints only exist on a `fraction`, so there are no blank fields to
interpret. A `fraction`'s `from` and `to` must each be a `vertex` or a `tcp` — not `size`, `girdle`,
or a nested `fraction`.

## The five meet forms

### 1. `TCP` — converge on the axis

The tier's facets all meet at a point on the stone's axis.

Cost-free by construction: every facet in a tier has the same tilt from the axis, so cutting them
to one depth *automatically* puts them through one axial point, whatever the index positions.

- **`tcp` pins a depth on exactly one tier per side — the first one that sets a depth.** There it is
  the free datum, deciding where the culet sits, which is arbitrary. A 90° girdle tier does not
  count: it fixes the outline and no depth at all, so a `tcp` after one is still free.
- **On any later tier `tcp` is true but says nothing.** Every facet in a tier shares a tilt, so
  cutting to *any* depth puts them through some axial point — the condition is satisfied everywhere
  and constrains nothing. A second `tcp` on the same side is therefore an error, not a constraint,
  and the tier needs form 5 instead. `Novice Ash-er` is the case: its three pavilion steps sit at
  1.19175, 1.07438 and 1.00717, each superseding the last, so all three are honestly "to TCP" — yet
  only P1's carries information.
- **A later axial point does supersede the one before it.** You cut until the tier's facets
  converge, which necessarily happens *above* the existing culet, so the new point replaces the old
  and the stone gets shallower. In `Easy Octagon`, P1's point forms at 1.0951 half-widths and P2 cuts
  it away, leaving P1's facets ending 0.3673 out from the axis and the culet at 1.0093. The tier
  keeps its facets; only its axial point is consumed.
- **So a printed `to TCP` is not always a complete specification.** `Tumbuka Fulu` runs three in a
  row (`P1 to TCP`, `P2 to TCP`, `P3 to TCP`) and its own sheet confirms none of them last — the
  final culet arrives ten steps later at `P13 to barion, establish final culet`. Transcribing those
  literally would leave two of the three depths undetermined; they have to be read off the diagram
  and written as fractions.

Do not read `TCP` as "these facets touch the axis in the finished stone." It means "cut this tier
until its facets converge on the axis," which is a statement about the cut, not the result.

### 2. `SIZE` — cut to the target dimension

The stone's size. **This is not part of the design** — it comes from what the player is trying to
cut: a commission for an 8mm stone, or a yield run where you take the minimum that still forms a
girdle.

There is **exactly one** `SIZE` row, even for elongated and rectangular outlines. Width follows
from the meets, not from a second free choice. (`Rand's Cut Corner Rectangle #1` has `set stone
length` on one 90° tier and `meet 1-1-2-3` on the other.)

**Which dimension it sets is not ambiguous, because it isn't a dimension — it's the unit.** The
`SIZE` tier's plane offset *is* 1.0 by definition, and every other depth is solved relative to it. So
`SIZE` is a normalization rather than a constraint, and it works where "diameter" doesn't: in
`Rand's`, the `SIZE` row is a 90° girdle tier on `8 40 48 56 88 0`, so *those* planes' offset is the
unit and the rectangle's other dimension falls out of the meets. A design is scale-invariant — every
meet is an angle or a proportion — so no millimetres appear in the file. An absolute spec from a
printed sheet stays in `notes` as a cross-check performed by scaling the normalized solve, never as a
solve input.

### 3. `GIRDLE` — cut to the girdle thickness target

Where a tier's depth is set by how thick the girdle should be rather than by a vertex — the corpus
writes `set girdle thickness`, typically on the first crown tier, since the top of the girdle band
is where the crown begins.

Not a free choice: the target is 3–5% of width, so it follows once size is set. A design may
override it in `notes` with an explicit spec and tolerance, and competition designs do — `SUPERPEAR
96` asks for 0.3±0.1mm on a 12–13mm stone, i.e. 1.6–3.2%, thinner than the rule of thumb.

Being a ratio, it needs no special handling on a non-round outline — but **"width" is twice the
*minimum* girdle-plane offset computed from the solved outline, never assumed.** Minimum, not
maximum: on an elongated stone the maximum offset is the half-*length*. `Rand's Cut Corner
Rectangle #1` carries its girdle at 4.05% of width, comfortably inside the target, which the maximum
offset reports as 2.96% and would wrongly flag as too thin. Nothing in the solver, the validation or
the display may assume a flat girdle either: roughly 99% of designs have one, but non-flat girdles
exist and are expressible in these same meet forms.

### 4. A vertex — name the facets that meet there

Name the facets whose common point this tier has to reach. A facet is a **tier and an index**:

```json
{ "kind": "vertex", "facets": [ {"tier":"G1","index":0},
                                {"tier":"G1","index":12},
                                {"tier":"P1","index":0} ] }
```

**Three, and exactly three.** Three independent planes pin a point, so three is both the minimum
and all you should write. Extra names only restate something the solver can already work out — it
finds every facet through the solved point by itself, so the true order of the vertex is derived
data, and putting it in the file makes it a rival source of truth. Same reason facet count and
symmetry aren't authored.

Two rules the schema can't express for you:

- **The list never includes the facet being cut.** Only the facets already on the stone that the new
  one has to arrive at.
- **Only name tiers already cut.** A reference to a later tier is an error, and the engine will tell
  you — which is how it validates that your cutting order is right.

A facet must be a tier *and* an index, never a tier alone: a bare tier name doesn't say which facet,
and in `Easy Octagon` two different P1 facets both pass through P2's vertex. Naming a tier alone
forces the solver to guess, and any guessing rule breaks on a design that doesn't match its
assumptions. (The corpus writes this as `meet 1-1-2-3`, `meet C-A-D`, `meet E-D-D-E` — tiers only, so
none of it transfers mechanically; the indices have to come off the diagram. A flat string form was
considered and dropped, since tier labels may be bare numbers and `1-1-2-3` is then unparseable.)

**You do not have to say which facet of the new tier arrives at the point.** That is determined
rather than chosen, so there is no convention to remember here. A tier shares one depth `d`, so the
solid requires `n · p ≤ d` for *every* facet of the tier, with equality on whichever one actually
reaches the point — which makes `d` the largest of those dot products:

    d = max over the tier's facets of (facet normal · named point)

One dot product per facet, take the largest. It needs no special case for a `0.00` table (one facet,
max of one), and if two facets tie, the point simply lies on the edge between them and `d` is still
unique.

It is also indifferent to the outline's shape, because a tier is *by definition* one depth and so can
never hold facets at mixed distances from the axis. Where an outline demands different distances, the
design has already split them into separate tiers: `DPC Ash-er`'s cut-corner square needs `G1 90.00`
on `24 48 72 0` and `G2 90.00` on `12 36 60 84`, where the regular-octagon `Novice Ash-er` gets by
with a single `G 90.00` on all eight.

### 5. A fraction between two vertices

For steps and any place there's no convergence to aim at: name two vertices and how far between
them to stop.

```json
{ "kind": "fraction",
  "from": { "kind": "vertex", "facets": [ {"tier":"P1","index":0},
                                          {"tier":"P2","index":6},
                                          {"tier":"G1","index":0} ] },
  "percent": 40,
  "to":   { "kind": "tcp" } }
```

Both endpoints follow form 4's rules, and each must be a `vertex` or a `tcp`. Naming both ends fixes
the direction too, so there's no convention to remember. A plain vertex is just this with no
`percent`.

**How it resolves.** Interpolate the *point* — `P = from + percent/100 × (to − from)` — then apply
form 4's max rule to `P`. Not the plane offset: interpolating offsets requires picking one facet of
the tier, and the answer would depend on which. Interpolating the point and taking the max is the
same operation form 4 already uses.

**A `tcp` endpoint means the axial point on the same side as the tier being cut**, decided by its
`part`. Once both crown and pavilion are cut there are two axial points — a culet and a crown apex —
and a bare `tcp` would otherwise be ambiguous. In `Novice Ash-er`, P3's `tcp` is the pavilion's
current point at 1.07438 while T's is the crown's at 0.55840.

**Author the endpoints first, then the percentage.** Which two vertices a depth is expressed against
is a judgement about the design, not something to infer — a tool must never pick the endpoints itself
and back-solve a percentage from an achieved depth.

**The percentage is a coordinate, not a design quantity.** It falls out of whichever two vertices you
named, so it rarely lands on a number the designer would recognise. `Novice Ash-er`'s crown and
pavilion band boundaries sit at the *same radius* — the steps line up in plan view, which is plainly
deliberate — but the rows that place them read 24.862% and 24.832%. The stone is right and the intent
is lost. That is the outcome-condition gap below, met in practice rather than in theory.

## Worked examples

### `Easy Octagon` — fully resolved, no open cells

The reference example: every meet verified against the design's own solved geometry, so it shows
what a finished authoring looks like rather than what one looks like mid-transcription.

```json
{
  "formatVersion": 1,
  "name": "Easy Octagon",
  "state": "finished",
  "wheel": 96,
  "ri": 1.54,
  "designer": "USFG Competitions. No individual designer named on the source sheet.",
  "notes": "Declared on the sheet, as cross-checks not source of truth: 37 facets, 4-fold symmetry.",
  "tiers": [
    { "tier": "G1", "part": "gdl",   "angle": 90.00, "indices": [0,12,24,36,48,60,72,84],
      "meet": { "kind": "size" } },
    { "tier": "P1", "part": "pav",   "angle": 47.60, "indices": [0,12,24,36,48,60,72,84],
      "meet": { "kind": "tcp" } },
    { "tier": "P2", "part": "pav",   "angle": 43.00, "indices": [6,18,30,42,54,66,78,90],
      "meet": { "kind": "vertex", "facets": [ {"tier":"G1","index":0},
                                              {"tier":"G1","index":12},
                                              {"tier":"P1","index":0} ] } },
    { "tier": "C1", "part": "crown", "angle": 42.00, "indices": [0,12,24,36,48,60,72,84],
      "meet": { "kind": "girdle" } },
    { "tier": "C2", "part": "crown", "angle": 29.00, "indices": [18,42,66,90],
      "meet": { "kind": "vertex", "facets": [ {"tier":"G1","index":12},
                                              {"tier":"G1","index":24},
                                              {"tier":"C1","index":12} ] } },
    { "tier": "T",  "part": "table", "angle":  0.00, "indices": [0],
      "meet": { "kind": "vertex", "facets": [ {"tier":"C1","index":0},
                                              {"tier":"C1","index":12},
                                              {"tier":"C2","index":18} ] } }
  ]
}
```

Three things it demonstrates. `tcp` on P1 is a temporary point that P2 removes. Every vertex names
exactly three facets, and nothing anywhere designates which facet of the new tier arrives there,
because that is computed. And none of the derived quantities — 37 facets, 4-fold mirror symmetry,
table size, culet depth — appear in the file at all; they fall out of the solve.

Authored as `Design/Patterns/Pattern-Easy-Octagon.json`.

Three patterns are now authored and verified against their own solved geometry, and between them they
exercise all five forms: `Easy Octagon` (`size` `tcp` `girdle` vertex), `Novice Ash-er` (adds
`fraction`), `Rand's Cut Corner Rectangle #1` (the elongated case). The one example still in the old
tabular shorthand is `Easy Does it Modified`, below, which needs re-authoring to JSON — that means
resolving its `?` cells first, kept because the *reasoning* about which cells are hard is still the
point.

### `Rand's Cut Corner Rectangle #1` — the elongated case

53 facets, 2-fold mirror, cut-corner rectangle. Fully resolved; authored as
`Design/Patterns/Pattern-Rands-Cut-Corner-Rectangle.json`. Meets in shorthand:

| tier | part | angle | indices | meet |
| --- | --- | --- | --- | --- |
| 1 | pav | 43.00 | 0 8 16 24 32 40 48 56 64 72 80 88 | `tcp` — the free datum |
| 2 | gdl | 90.00 | 0 8 40 48 56 88 | `size` — both ends and all four cut corners |
| 3 | gdl | 90.00 | 24 72 | vertex `1@8 1@16 2@8` |
| 4 | pav | 65.00 | 24 72 | vertex `1@8 1@16 2@8` |
| 5 | pav | 41.20 | 4 12 36 44 52 60 84 92 | vertex `2@0 2@8 1@0` |
| A | crown | 50.00 | 0 8 40 48 56 88 | `girdle` |
| B | crown | 50.00 | 24 72 | vertex `2@8 3@24 A@8` |
| C | crown | 32.00 | 21 27 69 75 | vertex `2@8 3@24 A@8` |
| D | crown | 35.00 | 4 44 52 92 | vertex `2@0 2@8 A@0` |
| E | crown | 22.00 | 12 36 60 84 | vertex `C@21 A@8 D@4` |
| F | table | 0.00 | 0 | vertex `D@4 D@92 E@12` |
| G | crown | 25.84 | 24 72 | vertex `C@21 C@27 B@24` |

Five things it settles.

**`meet 1-1-2-3` does include the facet being cut.** Tier 3 names itself, and dropping the
self-reference leaves exactly the three that pin the point. The doc used to leave this open; it's
closed.

**`level girdle` is a plain vertex, not a fraction.** Tiers 4 and B each meet the girdle corner their
predecessor already established — the same vertex tier 3 and tier C use. Simpler than expected: no
percentage, no new form.

**The design needs no `fraction` at all.** Every tier is `size`, `tcp`, `girdle` or a vertex. Form 5's
only worked example remains `Novice Ash-er`.

**Width really does follow from the meets.** The half-width solves to exactly √3 − 1, so L/W is
(√3 + 1)/2 = 1.36603 — forced by the 30°/60° index positions, not a second free choice. Tier 1's free
datum is what sets it.

**Facet identity cannot be read off the diagram by position.** C and E come out swapped if you match
polygons to azimuths: their top-view centroids sit 29° and 19° away from their facet azimuths. The
sheet's own `meet C-A-D`, `meet C-B-C` and `meet E-D-D-E` are what disambiguate them, each naming a
vertex only one assignment can satisfy. Where a sheet gives meet text, trust it over the picture.

One correction to the sheet's own listing as reproduced in earlier drafts of this document: tier 4 at
65.00 is `pav`, not `gdl` — it sits below the girdle, and `gdl` is for the 90° band itself. And tier
**G** (25.84, `meet C-B-C`) was missing entirely; with it the count is exactly the declared 53.

### `Easy Does it Modified` — descoped, but its instruction vocabulary is worth keeping

Not authored, and deliberately so: it was in the success set as "the vague-printed-instructions case,"
which is a *transcription* difficulty rather than a solver one. Once a design is authored by cutting it
in a tool, nothing ever reads `Girdle meet point` again.

Its half-guessed table has been removed rather than left in place — it had P1 and P2 both on `TCP`,
which one-per-side now forbids, and two rows on `Establish size` where there is exactly one `size`.
Following it would have taught the wrong thing.

What survives is useful: the corpus's phrasing, and what each phrase turned out to mean once resolved
in a design we did author.

| printed on the sheet | resolved form | settled by |
| --- | --- | --- |
| `Cut to centerpoint`, `Cut to TCP` | `tcp` — but only the first per side; later ones pin nothing | `Novice Ash-er`, `Tumbuka Fulu` |
| `new PCP` | a vertex; the axial point it makes supersedes the previous culet | `Rand's` tier 5 |
| `set stone length`, `Establish size` | `size` — and only one row may have it | `Rand's` tiers 2 / 3 |
| `set girdle thickness`, `Establish girdle` | `girdle` | `Rand's` tier A |
| `level girdle` | a plain vertex — the girdle corner the previous tier established | `Rand's` tiers 4 / B |
| `girdle meetpoint`, `Girdle meet point` | a vertex on the girdle plane; which facets comes off the diagram | `Rand's` tiers 5 / C / D |
| `meet A-B-C` | a vertex, dropping any self-reference | `Rand's` tiers E / F / G |
| `should cut the same depth` | unresolved — a dial-gauge reading, see below | — |
| *(blank)* | nothing; derive it from the diagram | — |

Two phrases stayed genuinely ambiguous even after resolving three designs: a bare `Girdle meet point`
never says *which* facets, and `Continue girdle` says nothing at all. Both need the diagram, which is
the honest limit of working from printed sheets.

**One coverage gap left by descoping it:** nothing in the reference set has odd-order symmetry — two
regular octagons and a 2-fold rectangle. `Kiev Triangle` is 3-fold mirror and is already the planned
scale check, so that is the cheaper place to get it than re-authoring this one.

### `Novice Ash-er` — the step cut

`P1 50.00`, `P2 46.00`, `P3 42.00`, all on the same eight index positions `12 24 36 48 60 72 84
0`. Concentric bands. Consecutive same-side steps have nothing to converge on, so each one's
depth is a judgement call — this is where form 5 earns its place, and where a percentage between
the culet and the girdle is probably what you want.

Step cuts are a family, not a curiosity: `Premaster Ash-er` puts **eight tiers on one index set**.
Worth authoring one early to find out whether fractions express them comfortably.

## Rules the engine enforces

You'll get told if any of these break, which makes them useful rather than annoying:

- **References point backwards only.** You can't meet a facet you haven't cut. This is how the
  cutting order gets checked — one corpus design lists its steps out of order.
- **The solid has to close.** A design that doesn't bound a solid is an error.
- **Facet count has to match.** If the sheet says 52 facets and the solve yields a different
  number of faces, something's wrong.
- **Named vertices have to be real — at cutting time.** Every facet you name must pass through the
  point *on the intermediate solid, as it stands when that tier is cut*. Not on the finished stone:
  the point is often gone by then, and checking against the final polytope both passes designs by
  luck and rejects correct ones.
- **The three named planes have to be independent.** Three planes only meet at a point if the 3×3
  system is non-singular, and faceting produces the degenerate case easily — three girdle facets are
  all vertical and pin nothing. Reject a singular triple rather than asking the author for a fourth
  name.
- **At most one `tcp` per side.** It is the free datum; a second one on the same side pins nothing and
  leaves the design not determining its own geometry. This is a silent failure without the check — the
  file parses, the solve runs, and the stone comes out wrong.
- **Tier order is data, not presentation, and must never be normalised.** Two same-side tiers can
  sometimes be swapped without harm — in `Easy Octagon` both pavilion tiers reach the girdle, so
  each is pinned independently of the other. That is a property of that design, not a general one.
  Where the later tier's meet only exists once the earlier one has been cut, reversing them yields a
  pattern that cannot be cut at all. So when references do point forward, the fix is to establish
  the true cutting order, never to reorder for tidiness.

## When the format won't stretch

Two cases are known not to fit. Don't work around them — flag them, and they get designed
properly:

- **A condition on the result rather than a position** — "cut so these edges are equal length."
  Solvable, but there's no position to write down.
  See [ticket 18](../../.scratch/faceting-game/issues/18-outcome-condition-meets.md), which is
  parked waiting on exactly this example.
- **A fraction with an endpoint you can't name** as either a three-facet vertex or the TCP.

And one open question that may affect how you write things: `should cut the same depth`
(`Tumbuka Fulu`, P8) is a *dial gauge* statement, and a gauge reading isn't the same as a plane
offset — two tiers at different mast angles reading the same on the dial sit at different
distances from centre. If you mean the gauge, say so, because it may need its own form.
