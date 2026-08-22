# ADR-0001 — The geometry kernel is production code in its own module; the GUI is disposable

Date: 2026-08-21
Status: accepted

The depth solver and half-space → polytope construction live in `Kernel/`, a SwiftPM package with
tests from its first commit, and the game later depends on that same package. The Mac app that puts a
UI on it is explicitly allowed to be scrappy and to be thrown away.

The alternative was another throwaway spike in the style of `Design/Prototypes/render-proof/`, whose
own README says "This is a spike, not an engine. No tests, no error handling, no abstractions."
Rejected because the tool's whole purpose is to be trusted over the author's own reading of a printed
faceting sheet, and that bar is empty without a kernel worth believing. Also rejected: growing this
app into the game, which would drag in the economy, jobs and scoring that the tool declares non-goals.

The trade-off is real — up-front test and module-boundary cost, paid before any UI exists, in exchange
for writing the hardest and most correctness-critical code in the project exactly once.
