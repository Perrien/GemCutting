# Bootstrap From An Exploration — Exploration

Status: **IN PROGRESS**
Started: 2026-08-26 · via /a-explore
IDs: **S** = scope · **I** = implementation · **U** = UI/UX

Subject: the `a-*` skill chain itself, not GemCutting. GemCutting is the evidence corpus and, for now,
the host for this file.

## Grounding

What exists today, on 2026-08-26:

- **`a-explore`** is a serial, one-question-at-a-time interview producing a closed notes file and
  nothing else — `a-explore/SKILL.md:13` (`It does not produce an` implementation plan).
- **`a-map`** is a *breadth-first* five-area interview over vision, users, features, tech stack and
  architecture — `a-map/SKILL.md:103` (`Fan out across all five before going deep on any one`) — and it
  never closes (`:14`, `there is no closing`). The owner disliked the breadth-first questioning and went
  back to `a-explore`.
- **`a-create-plan` already contains a splitter**: thresholds at `a-create-plan/SKILL.md:123`
  (`- more than **8 tasks**`), an owner approval stop at `:157` (`Put the split to the owner before
  writing anything.`), and one part per session at `:166` (`On approval, write part 1 in this session,
  then stop.`).
- **The current path demonstrably broke.** `Design/Explorations/Cutting-Bench-App.md:7`
  (`**This file was 1085 lines and 48 decisions`) — hand-split into five sibling explorations with a
  decision-mapping table and per-file *Inherited* sections, because `a-create-plan` could not complete
  against it.
- **Then it split again.** Those five produced ten plans of 600–1274 lines in
  `Design/Archived/Plans/`, every one past `a-create-plan`'s own ~500-line ceiling (`:508`).
- **A route already exists but is recorded nowhere.** The `1-`…`5-` prefixes on the Cutting Bench
  explorations are the only trace of the intended order.
- **The executor's contract is two documents.** `Design/Execution-Protocol.md:22`
  (`**You read exactly two documents:**`) — the plan and the protocol. A map must not become a third.
- **A feature catalog was already tried and replaced.** `Design/Execution-Protocol.md:336` — version 1.1
  names `Design/Tickets/` as the backlog, `replacing Design/feature-catalog.md`.
- **Skill size ceiling from the owner's guide**: SKILL.md under 5,000 words, detail moved to
  `references/`. `a-create-plan/SKILL.md` is 6,331 words; `a-explore` 3,489; `a-map` 3,044.
- **No scaffolded home for skill work exists.** `~/.claude/skills/` is not a repo; `CCode/MapSkill/` is
  empty.

## Tickets folded in

None. The five tickets in `Design/Tickets/` are all `Chore-` items about the faceting kernel and the
authoring format; none touches skill authoring. One is `untriaged`.

## Scope & purpose

- **S1** — **The division of work is decided in exactly one place.** Today it is decided twice: by hand
  when an exploration is cut into sibling explorations, and again by `a-create-plan`'s own threshold
  splitter. Two splitters produced three tiers of document for one feature (one exploration → five
  explorations → ten plans), and no single file shows the route. The new skill owns the division;
  `a-create-plan` stops deciding boundaries.

- **S2** — **Nothing beyond the first build is pre-sequenced.** A day-one ordered route is worthless by
  day ten, because building never follows the plan exactly and the two diverge. So the output is not a
  roadmap of ordered stages. Only the first build is planned up front; every later piece of work is
  picked on the day it is done and planned against the code **as it actually is**, not against what a
  route predicted it would be. This is what makes the divergence problem disappear rather than be
  managed.

- **S3** — **The first build is a bare-minimum framework app — call it V0.1 — bounded at one day's
  work.** It deliberately lacks most features. Its purpose is to be scaffolding that later work expands,
  so the value being maximised is *something running to build on*, not *features shipped*. The one-day
  bound is a hard constraint on the carve, not an estimate.

- **S4** — **Everything not in V0.1 is recorded as a tree, held in a small number of files grouped by
  relatedness — one file per branch, not one per feature.** Three levels, and the words are used
  literally throughout:
  - **Trunk** — the V0.1 framework app of **S3**. Exactly one. For GemCutting it is roughly *an app
    that views a gem cut, and nothing else*.
  - **Branch** — a group of related features, and the unit a file corresponds to. For GemCutting:
    authoring a new pattern; cutting an existing pattern; the game aspect and how a player progresses
    and is rewarded.
  - **Leaf** — one feature, carrying the prerequisites that must exist before it can be built.

  A per-feature file was rejected: forty leaves means forty files, which is the flat backlog dump the
  grouping exists to avoid.

- **S5** — **A leaf's prerequisites are a partial order, not a schedule.** They say what must exist
  first, never when anything is done. That is what keeps the tree compatible with **S2**: on any given
  day the owner picks any leaf whose prerequisites are already built, and the tree constrains that
  choice without ever having made it. A roadmap is a total order chosen on day one, which is the thing
  that diverges; a prerequisite is a fact about the feature, which does not.

### Non-goals

- **Not a roadmap.** No ordered list of stages beyond the trunk, because that is precisely the artifact
  that goes stale (**S2**, **S5**).
- **Not a document the coding agent reads.** `Design/Execution-Protocol.md:22` fixes the executor at two
  documents; this must not become a third.
- **Not a second splitter.** If `a-create-plan` keeps its own threshold split, **S1** has failed.

## Implementation

Not yet started — the Open queue's scope items come first.

## UI / UX

Not yet reached. Likely N/A in the screen sense; the surface is the document layout and the invocation.

## ADR candidates

None yet.

## Open — queued, in ask order

1. Does a leaf feed `a-create-plan` directly, or does it feed `a-explore` first? This decides how much
   detail a leaf must carry, and therefore whether the branch files hold plan-grade closed decisions or
   only seeds.
2. What happens to the source exploration once the bootstrap has run — archived, or kept live as the
   decision store for the leaves not yet built?
3. Does use case two — an app already running, one new feature — change at all, or does it stay
   exactly `a-explore` → `a-create-plan` → execute?
4. Where does the trunk/branch/leaf vocabulary get recorded? It is not GemCutting domain language, so
   `Design/Glossary.md` is the wrong home while this file lives in this repo.
5. Is deciding the trunk an interview, or a conversion of an already-closed exploration? [implementation]
6. Does this replace `a-map`, extend it, or become a new skill beside it? [implementation]
7. What replaces `a-create-plan`'s splitting section, and does the section get deleted? [implementation]
8. How does a day-ten plan ground itself in the shipped code rather than in the branch file?
   [implementation]
9. How is the one-day bound on the trunk expressed and enforced, and by whom? [implementation]
10. Are branches themselves fixed at bootstrap time, or can a new branch be added later? [implementation]

## Notes

- The owner's preference is `a-explore`'s serial depth interview over `a-map`'s breadth-first sketching
  pass. Any interview this design introduces should follow the former.
- Use case two already works and is not the problem being solved. Use case one — an app not built at
  all — is the target.
