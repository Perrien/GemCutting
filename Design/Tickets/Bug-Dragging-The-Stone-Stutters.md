# Bug: Dragging The Stone Stutters

Status: untriaged
Filed: 2026-08-26

Since the tier table gained the Seeds, Folds and Mirror columns, orbiting the stone by dragging
stutters visibly. Every drag delta mutates the camera, which re-evaluates the window body, which
rebuilds every tier row from scratch — and the row build now derives each tier's symmetry as well.
Measured in a debug build, `tierTableRows` for `Rand's` twelve tiers costs 0.85 ms per call of which
0.46 ms is the symmetry derivation, so the arithmetic alone is unlikely to account for the whole
drop; the ten-column table with a `Toggle` per row is the other candidate and needs the running app
to tell apart.
