# ADR-0003 — The kernel owns the pattern file's reader *and* writer; the app owns the half-authored draft

Date: 2026-08-23
Status: accepted

`Pattern`, `TierSpec` and `Meet` become `Codable` in `FacetKernel`, so the module that reads a pattern
file is the only module that writes one. The Mac app keeps its own editable draft — a tier with an
angle and index stops but no meet chosen yet — and converts that draft into a `Pattern` to solve,
validate and save. No draft type enters the kernel.

The natural reading of "the kernel solves geometry and validates" excludes writing, and the reason it
does not is that the finished game will offer authoring too. The file is the one artifact that must be
identical everywhere, and it already has exactly one reader here which is not a thin parser: decoding
enforces the format's rules and rejects duplicate tier labels, out-of-range and non-integer index
stops, unknown meet kinds and a vertex that does not name exactly three facets. One writer beside that
one reader is what keeps round-tripping honest; the alternative is the game growing a second writer
that can quietly disagree.

The draft stays out because its rules — which fields may be absent, and when — are UI policy rather
than geometry, and because two authoring surfaces (this Mac bench tool and whatever the game puts on
an iPad) would reasonably shape a buffer differently. What must match between them is the file, not
the buffer.

The trade-off is real: format knowledge concentrates in production code the game inherits, and `Meet`
decodes through a hand-written initialiser so its encoder is hand-written too and needs a round-trip
test. Bought in exchange: the app is free to shape its own editable model, and there is exactly one
place a format change lands.

Refines rather than supersedes ADR-0001, which put the kernel in its own tested module, and ADR-0002,
which made the file JSON.
