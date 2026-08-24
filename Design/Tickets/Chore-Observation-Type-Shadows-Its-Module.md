# Observation Type Shadows Its Module

Status: open
Filed: 2026-08-24

`Kernel/Sources/FacetKernel/Validation.swift:29` (`public enum Observation`) shadows the standard
`Observation` module in any file that does `import FacetKernel`, and the `@Observable` macro expands to
references qualified with `Observation.…` — so the macro fails to compile there. Worked around in
`CuttingBench/CuttingBench/BenchSolidStore.swift` with `import struct FacetKernel.Pattern`, but the next
app file to combine `@Observable` with a whole-module kernel import hits it again. Noticed while
executing `2-Cutting-Bench-App-Shell-2-Rough-In-The-Viewport` T2.
