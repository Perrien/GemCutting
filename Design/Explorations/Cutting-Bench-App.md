# Cutting Bench App — Exploration

Status: **SPLIT 2026-08-23** — this file holds no decisions. See the five explorations below.
Started: 2026-08-22 · via /a-explore
IDs: **S** = scope · **I** = implementation · **U** = UI/UX

**This file was 1085 lines and 48 decisions, which produced roughly sixty tasks — too large for
`/a-create-plan` to complete against.** It was split on 2026-08-23 into five explorations, one per plan,
each a standalone `/a-create-plan` input. **Every decision now lives in exactly one of them; nothing is
duplicated and nothing was dropped.**

| Exploration | Feeds the plan | What it covers |
|---|---|---|
| `1-Cutting-Bench-Kernel-Changes` | `Bench-Kernel` | `FacetKernel` and `design-authoring-format.md`: the encoder, the partial solve, the validation split, `T/W`, width-by-size, the girdle-target and `instructions` fields, the eight gears, the ray trace |
| `2-Cutting-Bench-App-Shell` | `Bench-Shell-And-Rough` | The document app, the Metal viewport, the rough prism and its names, the window layout, stock-native as the visual answer |
| `3-Cutting-Bench-Pattern-Display` | `Bench-Reads-A-Pattern` | Drawing a solved pattern, the scaffolding rule, the tier table, metrics, findings, playback, the light readouts |
| `4-Cutting-Bench-Authoring` | `Bench-Authors-A-Pattern` | The draft, tier edits and their refusals, symmetry generation, meet picking, the validation cache, writing the file |
| `5-Cutting-Bench-Angle-Tuning` | `Bench-Tuning-And-Transforms` | Tangent-ratio rescale, the quarter turn, and deriving an angle from two picked points |

The split axis is **the plan slice, never the area** — files divided into scope, implementation and UI
would each be unable to produce a plan, since a plan needs all three for its own slice.

**Chosen over** keeping one file with a plan-sequence section and teaching `/a-create-plan` to author one
slice: that needs an edit to a skill shared with other projects, and it leaves the slicing a convention
someone has to honour rather than something the file layout enforces.

## Where each old decision went

The five files renumber from `S1`/`I1`/`U1`, so an old identifier does not survive as an identifier. This
maps them for anyone holding an old reference.

| Old | Now in |
|---|---|
| `S1` `S4`(edit) | `4-Cutting-Bench-Authoring` |
| `S2` `S3` `S7` | `2-Cutting-Bench-App-Shell` |
| `S4`(read) `S6` | `3-Cutting-Bench-Pattern-Display` |
| `S5` | `5-Cutting-Bench-Angle-Tuning` |
| `I2` `I3` `I4`(kernel) `I8`(trace) `I13` `I17` `I19`(format) `I20`(split) `I21` | `1-Cutting-Bench-Kernel-Changes` |
| `I5`(names) `I12` `I16` | `2-Cutting-Bench-App-Shell` |
| `I4`(display) `I5`(scaffolding) `I8`(click) `I9` `I14` `I15` | `3-Cutting-Bench-Pattern-Display` |
| `I1` `I6` `I10` `I11` `I19`(picker) `I20`(cache) | `4-Cutting-Bench-Authoring` |
| `I7` `I18` `I22` `I23` | `5-Cutting-Bench-Angle-Tuning` |
| `U1`(layout) `U10` `U18` `U19` | `2-Cutting-Bench-App-Shell` |
| `U1`(status strip) `U5`(display) `U6`(intermediate) `U8` `U14`(display) `U17` | `3-Cutting-Bench-Pattern-Display` |
| `U2` `U3` `U5`(popup) `U6`(picking) `U7` `U9` `U11` `U12` `U13` `U14`(interactive) `U15` `U16` | `4-Cutting-Bench-Authoring` |
| `U4` | `5-Cutting-Bench-Angle-Tuning` |

Ten decisions straddled a boundary and were **cut into halves rather than duplicated** — shown above with
the half in brackets. Each file's **Inherited** section names, by sibling exploration, the decisions it
leans on but does not own, so the halves can be read together without either file restating the other.

## Tickets

- **`Chore-Kernel-Measures-Split-Between-Library-And-Callers`** — now folded into
  `1-Cutting-Bench-Kernel-Changes`, which closes it.
- **`Chore-Validation-Rebuilds-The-Solid-Once-Per-Tier`** — now folded into `4-Cutting-Bench-Authoring`,
  which closes it. The three-way validation split it depends on lands in
  `1-Cutting-Bench-Kernel-Changes`, but the cache that makes an editing UI not feel the cost is in the
  authoring slice, so that is where the ticket is answered.
- **`Chore-Incremental-Half-Space-Clipper`** — closed by no plan. `3-Cutting-Bench-Pattern-Display` defers
  the facet-granularity precompute cost and the animated facet arrival to it by name.

## ADRs

**`Design/Decisions/0003-kernel-owns-the-file-app-owns-the-draft.md`** was written on 2026-08-23 and
covers the only decision this exploration nominated. Its two halves are carried by
`1-Cutting-Bench-Kernel-Changes` (the writer) and `4-Cutting-Bench-Authoring` (the draft). **No plan writes
it again.**

## Design

**There is no visual specification and no design brief.** Briefing for one was tried and produced nothing
usable, so the app is built to stock native macOS and the look is adjusted in the running app at each
plan's owner stop. That decision, and the reasoning that makes it safe, is in
`2-Cutting-Bench-App-Shell`. The owner's layout sketch — `Design/Explorations/CB UI.png`, exported from
`Design/Patterns/Cutting Bench UI.key` — is input rather than specification: it settles arrangement and
asserts nothing about colour, type or spacing.

## This file's own end

It holds no decisions and exists so the name `Cutting-Bench-App` still resolves. **Archive it per
`Design/Execution-Protocol.md` §11 once nothing points at it**, as
`superseded by 1-Cutting-Bench-Kernel-Changes and its four siblings — split for size`. It was not archived
at split time because no plan had yet been written from any of the five.
