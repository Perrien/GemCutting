# GemSpike — render proof (PROTOTYPE, throwaway)

Answers `.scratch/faceting-game/issues/01-render-proof.md`: *can a finished faceted
stone be rendered convincingly enough to carry the game's payoff?*

**This is a spike, not an engine.** No tests, no error handling, no abstractions.
Delete it once the decision is folded into the real code.

## Run

```
swift build -c release --disable-sandbox     # SwiftPM's manifest sandbox conflicts with the agent sandbox
./.build/release/GemSpike window             # interactive: orbit, switch material/env/design live
./.build/release/GemSpike sheet              # the full variant sheet -> renders/
./.build/release/GemSpike fire               # colourless RI ladder (isolates RI from body colour)
./.build/release/GemSpike quad               # 4 quick looks, for iterating
./.build/release/GemSpike bench              # frame-rate and convergence numbers
./.build/release/GemSpike still              # one 1024spp still
```

In `window`: drag to orbit, scroll to zoom, `m` material, `e` environment,
`w` wavelength bins, `d` design, `b` bounce cap, `[` `]` exposure, `+`/`-`
samples per frame, `s` save PNG, `r` reset, `q` quit. The HUD prints the full
state every frame.

## What's in here

- `Geometry.swift` — a design is angle/index tiers on a 96-tooth wheel; a gem is
  the **intersection of half-spaces** those tiers define. Standard round brilliant
  and an emerald cut. Materials carry RI, dispersion (fitted to Cauchy) and a
  three-band absorption spectrum.
- `shaders.metal` — spectral path tracer. Ray/solid intersection is **slab
  clipping** over the plane list; no mesh, no BVH, no convex-hull construction.
  Per-sample wavelength, per-wavelength RI, Beer–Lambert absorption, Fresnel with
  Russian-roulette reflect/refract, CIE fit to XYZ, ACES tonemap.
- `Renderer.swift` — Metal setup, progressive accumulation, PNG out.
- `Window.swift` — MTKView harness so the stone can be judged in motion.

## Deliberate non-goals

Meetpoint solving (that's ticket 02 — depths here are set from standard
proportions and eyeballed), surface finish / polish state, the stone on the dop
under wax (ticket 08), inclusions, iPad measurement (no device on this machine).
