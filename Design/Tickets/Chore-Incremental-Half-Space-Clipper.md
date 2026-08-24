# Incremental half-space clipper

Status: open
Filed: 2026-08-22

`intersectHalfSpaces` rebuilds a polytope from scratch over every triple of planes, which costs roughly
planes⁴, so anything that walks a growing prefix of planes pays that cost per step — about 17 s of hull
work to step a 139-facet pattern facet by facet. Clipping the previous polytope by one new plane instead
would make each step roughly linear, and the same primitive is what the game's cutting animation needs.
It would also supply the fix for `Chore-Validation-Rebuilds-The-Solid-Once-Per-Tier`, which is this cost
showing up in validation.
