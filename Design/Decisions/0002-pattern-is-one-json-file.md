# ADR-0002 — A pattern is one JSON file, with a design state and a per-tier index wheel

Date: 2026-08-21
Status: accepted

The authoring format is JSON: a header plus an array of tiers, each tier carrying a `meet` object
tagged by `kind` (`size`, `tcp`, `girdle`, `vertex`, `fraction`). The header gains `state`
(`"in progress"` / `"finished"`, since only a finished pattern must be fully valid) and `wheel` as a
design default that any tier may override for a mid-cut gear change. There is exactly one
representation on disk — the tool's save format, the game's load format and the artifact verified on
screen are the same file, so they cannot silently disagree.

This replaces a tabular format that both `design-authoring-format.md` and the map's **T3** described
as hand-authored in a text editor or spreadsheet. The change is what makes the format's rules
structural instead of prose: `part` and `kind` become enums, a vertex's three facets become a
three-element array of typed pairs, and an optional per-tier wheel becomes an absent field rather than
a mostly-blank column. It also removed a small grammar — an `@` separator that collided with
bare-numeric tier labels — that existed only because a table cell can hold nothing but a string.

The trade-off is real: hand-writing a pattern from a printed sheet is worse in JSON, and the ability to
load the half-finished tables sitting inside the format document is lost. Both were accepted because
authoring moves into the tool, where the file is machine-written and machine-read from then on.
