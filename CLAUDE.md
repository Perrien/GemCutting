# GemCutting

A Mac and iPad app, built in Xcode, where the user facets gemstones in a simulator based on actual
faceting patterns.

---

## Document map — who wins on what

Per topic, not a ranking. A document can be the authority on one thing and irrelevant to another.

| Topic                       | Authority                                                                                               |
| --------------------------- | ------------------------------------------------------------------------------------------------------- |
| What the code actually does | **The code**, over every document. An archived document that contradicts it carries a banner saying so. |
| Terminology                 | **`Design/Glossary.md`** is the arbiter. Nothing overrides it.                                          |
| What to build next          | **`Design/Tickets/`** — sole authority; nothing else claims this.                                       |
| A feature's design          | **The exploration** beats the ticket that fed it.                                                       |
| Task order and content      | **The active plan** beats its exploration.                                                              |
| Architectural rationale     | **An ADR** in `Design/Decisions/` beats any plan or exploration, which are transient by design.         |
| Anything archived           | **Never wins.** Reference only.                                                                         |

**Two conflicts resolve to a stop, not a winner:**

- **A plan versus `Design/Execution-Protocol.md`** — stop and report it. Never pick silently.
- **A plan versus an ADR** — stop. The correct resolution is to write a superseding ADR and mark the
  old one `superseded by ADR-NNNN`. Letting a plan quietly override a recorded decision is how the
  reasoning gets lost.

*Exploration beats ticket* holds only because an exploration that folds a ticket in must **answer**
the question that ticket poses. A ticket whose question was left unanswered is still the live
authority.

---

## File naming

Explorations, plans and tickets are all **title case, hyphenated**: `Shot-History-Panel.md`.

**Tickets carry a type prefix, and there are exactly four types:**

| Prefix | What it is |
|---|---|
| `Bug-` | The code does something other than what it's meant to. |
| `Feature-` | Something the project doesn't do yet and should. |
| `Decision-` | A question with no answer yet that must be answered before something can be built. |
| `Chore-` | Work with no user-visible change — maintenance, cleanup, filling in blanks. |

So: `Bug-Scope-Drift-On-Reload.md`, `Feature-Shot-History-Panel.md`,
`Decision-Metric-Or-Imperial-First.md`, `Chore-Complete-Execution-Protocol.md`.

**"Observation" is not a type — it is a status.** An untriaged observation is still a Bug or a Feature.

**Names are unique across the whole project, and are never changed.** Not when the item is archived,
not ever. The name is the only handle anything has on it.

### The ticket shape

The whole of it. A ticket is not a spec — the moment one needs depth, it gets picked up by an
exploration, which is what explorations are for.

```md
# <Title>

Status: open | untriaged
Filed: <yyyy-mm-dd>
Picked up by: <Exploration-Name>        ← added when an exploration folds it in

One to three sentences. What the problem or the wanted thing is.
```

`open` means a human has assessed it and it's waiting to be picked up. `untriaged` means an agent
filed it on its own initiative and nobody has looked yet. **Only the owner promotes `untriaged` to
`open`.**

A ticket is a **file** by default and a **folder** when it has supporting documents or data — a
screenshot, a log, a dataset. In folder form the body file is named after the folder:
`Bug-Scope-Drift-On-Reload/Bug-Scope-Drift-On-Reload.md`. A file can be promoted to a folder later.

---

## Reference design documents by name, never by path

**Tickets, explorations and plans are referred to by name.** Write *"the ticket
`Bug-Scope-Drift-On-Reload`"* — never `Design/Tickets/Bug-Scope-Drift-On-Reload.md`.

To find one, **glob the name**: `**/Bug-Scope-Drift-On-Reload*`. One call, and it either finds the
item where it currently lives or tells you it's genuinely gone.

This is why a ticket can be promoted from file to folder, and why anything can be archived, without
breaking a single reference. A stored path fails the other way: it rots silently, pointing at nothing
while still looking valid. Loud failure over quiet failure is the entire reason for the rule.

**Code is the opposite** — cite it by `path:line` *with the fragment it points at*, e.g.
`ScopeView.tsx:339` (`const holdingRef = useRef(false)`), so a stale anchor announces itself. Two
different rules for two different things; both are hard.

---

## Never cite a decision by its plan's number

**A plan's decision numbers — `D1`, `D7` — are local to that plan and mean nothing outside it.** Every
plan starts again at `D1`, and plans get archived, so a bare `Dn` in code is a pointer to a document
that will one day both be gone *and* have a namesake meaning something else. One rule, one decision,
and four different names for it is how the reasoning gets lost.

- **In code, cite only ADRs, as `ADR-0004`.** That number is unique, permanent and never archived.
- **A decision with no ADR gets its reason written into the comment, in words.** If it isn't worth an
  ADR it is worth a sentence, and the sentence is what a future reader actually needed.
- **In a plan or an exploration, `Dn` is correct** — that's where the numbers are defined and where
  cross-references to them resolve.
- **When a plan restates a decision another document already settled, that's the signal to write the
  ADR** and cite it from both, rather than making a third copy.

**Talking to the owner, name the thing in words, never by code.** Not *"D5 versus the app shell's D1"* —
say *"the rule that the rough is added by the app, not the solver."* The codes are internal bookkeeping;
they carry no information for a reader who isn't holding the document open.

---

## Where the durable records live

Both are created **lazily** — only when there is something real to put in them. Neither is
pre-created empty.

- **`Design/Decisions/`** — ADRs, sequentially numbered `0001-slug.md`. An ADR records that a
  decision *was made*, and why, in as little as one paragraph. Written only when a decision is hard
  to reverse, surprising without context, **and** the result of a real trade-off.
- **`Design/Glossary.md`** — the project's canonical vocabulary. Domain terms only, one or two
  sentences each, totally devoid of implementation details. Written the moment a term is resolved.

---

## `LocalOnly/` — project files that never leave this machine

A root-level folder, beside `Design/` and the source tree. It is **excluded from the repository**, and
it exists for anything that genuinely belongs to this project but must not be published: private
notes, credentials and keys, client or licensed material, raw captures, personal scratch data,
screenshots that show more than they should.

**Nothing tracked may depend on it.** No source file, test, fixture, plan or task may read a path
inside `LocalOnly/`. It does not exist in any other clone or on any other machine, so anything that
reaches into it works here and breaks everywhere else — and breaks silently, because the folder's
absence looks like a missing file rather than a design error. If the build needs a file, that file
does not belong in `LocalOnly/`.

**It is not part of the design structure.** Nothing in it is archived, catalogued, referenced by name,
or picked up by an exploration. Explorations, plans and tickets are tracked documents and stay in
`Design/`; `LocalOnly/` is a drawer, not a document store.

**Don't file things there on your own initiative.** Read from it or write to it when asked — otherwise
leave it alone. If something you're about to write looks too sensitive to commit, say so and ask,
rather than quietly routing it out of the repository.

---

## Execution-time rules live elsewhere

Gates, guardrails, environment, pause points, statuses, git discipline and the archive routine are in
**`Design/Execution-Protocol.md`**. Read it before executing a plan, and before archiving anything.
