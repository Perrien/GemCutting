# ADR-0004 — The rough is intersected in the app; the solver never sees it

Date: 2026-08-25
Status: accepted

The rough prism's half-spaces are appended to a pattern's solved planes and intersected in the app
(`CuttingBench/BenchGeometry/Sources/BenchGeometry/BenchSolid.swift:71` — `public func benchSolid(for
pattern: Pattern?, tierLimit: Int? = nil) -> BenchSolid`). The kernel's own `Solution.polytope` stays
rough-free, and no kernel type knows that rough exists.

The reason is that two checks are what make this tool worth trusting over the author's own reading of a
printed faceting sheet: that the design bounds a closed solid, and that it cuts the number of facets it
claims. A rough-capped solid *always* closes, because the prism bounds it in every direction whatever
the design does — so feeding rough into the solve would make the closure check at
`Kernel/Sources/FacetKernel/Validation.swift:219` (`public func solidFindings(_ solution: Solution,
declaredFacetCount: Int?) -> [Finding]`) pass for every pattern, including exactly the ones it exists to
catch. Facet count fails the same way, since `Kernel/Sources/FacetKernel/Metrics.swift:85`
(`facetCount: solution.polytope.facets.count`) counts the kernel's polytope directly and would count
surviving rough walls as facets of the design.

Rejected: drawing the prism as its own separate solid with no intersection against the pattern. It is
cheaper, but nothing gets cut, so it shows a prism with a cone floating inside it rather than a stone
with material removed — and facet picking is then wrong everywhere a cut facet should have clipped a
rough wall.

The consequence reaches past this tool. ADR-0001 has the game depending on this same kernel, and the
game's rough is an economic object the player buys, where *whether a design fits the stone in hand* is a
real question with money on it. Keeping rough out of the solve is what keeps that question separate from
*whether the design closes*, which is a property of the design alone — so the game can tell a player
that their design is sound and their stone too small, rather than conflating the two into one failure. If
such a fit check is wanted later it belongs in the kernel as its own function over rough planes and a
solution, never folded into solving.

First settled in the plan `2-Cutting-Bench-App-Shell-2-Rough-In-The-Viewport` and restated in
`3-Cutting-Bench-Pattern-Display-1-Solid-And-Tier-Table`. Written up here because a third copy was about
to be made, and copies are how the reasoning gets lost.
