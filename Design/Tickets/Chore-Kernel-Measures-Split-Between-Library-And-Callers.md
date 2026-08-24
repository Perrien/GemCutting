# Kernel measures split between the library and its callers

Status: open
Filed: 2026-08-22
Picked up by: 1-Cutting-Bench-Kernel-Changes

Two measures the kernel computes live outside `FacetKernel`: the table's extent over the width (`T/W`)
is derived in `facetsolve`'s `main.swift`, and the closure rule validation applies is re-stated in
`ScaleTests.swift` because `closureFinding` is file-private. Each is one definition kept in two places,
and the GUI will want the table size as a metric rather than as CLI output.
