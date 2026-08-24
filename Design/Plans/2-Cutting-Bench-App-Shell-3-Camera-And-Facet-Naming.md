# 2 · Cutting Bench App Shell — 3 · Camera And Facet Naming

Status: **APPROVED 2026-08-24** — in execution.

## Parts

**For the owner and the next authoring session — not for the executor.** Nothing in this part's tasks
refers to another part.

1. `2-Cutting-Bench-App-Shell-1-Window-And-Document` — the app exists, opens a pattern file through
   the Open dialog, and shows the five layout regions present and empty. (shipped 2026-08-24)
2. `2-Cutting-Bench-App-Shell-2-Rough-In-The-Viewport` — the rough prism intersected with the
   pattern's own planes, drawn in Metal with flat per-facet fill and always-drawn edges, on a fixed
   three-quarter camera. (shipped 2026-08-24)
3. `2-Cutting-Bench-App-Shell-3-Camera-And-Facet-Naming` — free orbit, face-up and face-down snaps,
   the opacity control, click-a-facet-get-its-name, and the index-stop ring with its fade. Closes the
   exploration out and runs the archive routine. ← this part, and the last

| Exploration ID | Part |
|---|---|
| S1 | 1 |
| S2 | 2 |
| S3 | 2 |
| I1 | 2 — its planning consequences (owner-run `project.pbxproj`, deployment target) bound part 1 and are restated here |
| I2 | 2 |
| I3 | 3 — declared in part 2, consumed here by picking |
| I4 | 2 |
| I5 | 1 |
| U1 | 1 |
| U2 | 1 — restated in part 2 and here; this part introduces no bespoke palette |
| U3 | 3 |
| U4 | 3 |

**No boundary moved.** Two things part 2's copy did not name, both inside this part's own scope rather
than taken from a sibling: the picked facet is **highlighted** in the fill as well as named, because a
click with no visible answer cannot be told from a hardcoded readout (D12); and the opacity slider and
snap buttons live in the **toolbar**, which leaves all five of U1's regions untouched (D6).

Every exploration ID now has a part. This is the last part: it closes the exploration out and runs the
archive routine for itself, both siblings, and the exploration (T8).

## Context

The app draws the right solid and the owner cannot turn it round. Part 2 landed the rough intersected
with the pattern's planes, flat-shaded per facet with its edges drawn, on **one fixed three-quarter
camera** — every constant of it in `BenchCamera` (`BenchCamera.swift:8`, `public static let
azimuthDegrees: Float = 45`). This part makes that view operable: drag to orbit, snap to face-up and
face-down, fade the solid to see the pavilion through the crown, click a facet and be told its name,
and read the index stops off a ring around the rim. After it the shell is done and the exploration
closes.

Everything here is a small change to code that already exists, and the seam it uses is the one part 2
built: **pure geometry in the `BenchGeometry` package, the app wires it to AppKit and SwiftUI.**

- **The camera is already three pure functions over constants**, so parameterising it is a rename plus
  an argument: `BenchCamera.swift:19` (`public func benchCameraPosition() -> SIMD3<Float>`),
  `:27` (`public func benchViewMatrix() -> simd_float4x4`), `:43`
  (`public func benchProjectionMatrix(aspect: Float) -> simd_float4x4`). The view matrix is a
  right-handed look-at with world +z up, built from `:30`
  (`let xAxis = normalize(cross(SIMD3<Float>(0, 0, 1), zAxis))`) — **that cross product is zero when
  the camera looks straight down the axis, which is exactly what a face-up snap is**, and its
  normalised value turns out not to depend on the elevation at all, so one closed form replaces it
  outright (D3).
- **The renderer already resolves every colour per draw from named system colours**, so two more roles
  cost two more lines: `BenchRenderer.swift:175` (`private func rgba(_ color: NSColor, in appearance:
  NSAppearance) -> SIMD4<Float>`), called at `:131` (`cutColor: rgba(.controlAccentColor, in:
  appearance)`). U2's no-bespoke-palette rule is already how this file works (D18).
- **The half-spaces picking needs are already on the solid**: `BenchSolid.swift:19` (`public var
  planes: [Plane]`) with `Plane` as `n · p <= d` (`Kernel/Sources/FacetKernel/Geometry/Plane.swift:4`,
  `public struct Plane: Equatable, Sendable`), and the plane-to-name map is already there too —
  `BenchSolid.swift:21` (`public var origin: [Int: FacetOrigin]`), with `FacetOrigin` at `:10`
  distinguishing `.rough(RoughFacet)` from `.cut(FacetRef)`. **That is I3, already built.** So picking
  is one pure function over data that exists, and no new geometry.
- **Nothing in the kernel changes.** `intersectHalfSpaces` and the solve are untouched; this part reads
  what part 2 already asked them for.
- **The mesh is the only place a new per-vertex field is needed**, for the highlight:
  `SolidMesh.swift:7` (`public struct MeshVertex: Equatable, Sendable`), whose layout the renderer
  reads through `MemoryLayout` rather than hand-counted bytes (`BenchRenderer.swift:79`,
  `descriptor.attributes[0].offset = MemoryLayout<MeshVertex>.offset(of: \.px)!`) and whose three
  numbers are pinned by `SolidMeshTests.swift:13` (`XCTAssertEqual(MemoryLayout<MeshVertex>.stride,
  28)`).
- **The fill and edge pipelines already share one descriptor and one depth state**, differing only in
  their functions: `BenchRenderer.swift:56` (`fillPipeline = try!
  device.makeRenderPipelineState(descriptor: descriptor)`) and `:60` (`edgePipeline = …`), with
  `:144` (`encoder.setCullMode(.none)`) recording part 2's decision to cull nothing. Translucency is
  added without disturbing that (D7).
- **New `.swift` files need no `project.pbxproj` edit.** The app target uses a synchronised group —
  `CuttingBench.xcodeproj/project.pbxproj:30` (`isa = PBXFileSystemSynchronizedRootGroup;`), and
  `BenchRenderer.swift` appears nowhere in that file as an individual reference — so a file on disk is
  a target member automatically (D19). `project.pbxproj` is owner-run under the protocol's guardrails
  and this plan never touches it.
- **There is no shared Xcode scheme** — `xcuserdata/` is gitignored and no `.xcscheme` exists on disk
  — so the agent cannot build or run the app. Building it is the owner's action at each stop (D20).

## Decisions (2026-08-24)

| # | Decision |
|---|---|
| D1 | **Camera state is a value — azimuth and elevation in degrees — and the three matrix functions take it.** `distance` and `fieldOfViewDegrees` stay build constants: **there is no zoom**, because U3 asked for orbit, snaps and opacity and nothing else, and a fixed distance is what keeps the framing test a real check. |
| D2 | **Elevation clamps to −90…+90; azimuth wraps modulo 360.** A turntable never rolls, so there is no gimbal flip to reason about. Clamping at exactly ±90, not clamping short of it (D3). |
| D3 | **The screen-right axis is computed from the azimuth alone and there is no up reference**: `xAxis = SIMD3(-sin(az), cos(az), 0)`. `normalize(cross(SIMD3<Float>(0, 0, 1), zAxis))` gives `(-cos(el)·sin(az), cos(el)·cos(az), 0)` before normalising, and the `cos(el)` divides out — so the closed form **equals today's value at every elevation**, not just near the poles, and it stays defined at ±90° where the cross product is the zero vector and `normalize` of it is NaN. No threshold, no branch, no fallback up vector, and therefore nothing that can lurch mid-drag: a fallback taken *near* the pole rather than *at* it would roll the image by about 135° at azimuth 45 partway through an upward drag. **Face-up must be exactly face-up** — the symmetry of the projected outline is the whole reason a faceter looks at a plan view — so stopping the orbit short of 90° is also wrong. The snaps therefore sit at **azimuth 270**, where looking down puts +x at screen right and +y at screen up, so index 0 sits right of centre and the indices advance counter-clockwise: the conventional plan view. |
| D4 | **Orbit is 0.5° per point of drag on both axes**, one build constant, and the drag is **direct manipulation**: the stone follows the pointer, so the camera moves the opposite way on both axes — dragging right turns the near side of the stone right and lowers the azimuth, dragging down tips the crown toward the viewer and raises the elevation. *(Corrected at T2's owner stop, 2026-08-24: this decision originally read "dragging up raises elevation and dragging right increases azimuth", which is the camera's direction rather than the stone's, and read as reversed on both axes in the app. The negation lives at the call site in `BenchWindow.orbit(dx:dy:)`; `BenchCameraState.orbit` still takes camera degrees.)* |
| D5 | **Snaps are instant, not animated.** Nothing in this render animates — the view is `isPaused = true` and redraws on demand (`MetalViewport.swift:34`) — and animating the camera means driving a run loop for the one thing that would use it. |
| D6 | **The opacity slider and the two snap buttons live in the toolbar**, beside the existing inspector toggle (`BenchWindow.swift:41`, `.toolbar {`). That leaves all five of U1's regions exactly as U1 fixed them, and the scrubber strip belongs to a later slice. Opacity is a `Double` in `0…1`, default `1`. |
| D7 | **Translucency is two fill passes selected by the facet's own plane facing, never by cull mode.** For a plane with outward normal `n` and offset `d`, every point `p` on that facet satisfies `n · p = d`, so `facing = dot(n, eye) − dot(n, p)` is **constant across the whole facet** and its sign says whether the facet points at the camera. Computing it in the vertex shader from data already in the vertex leaves part 2's `encoder.setCullMode(.none)` (`BenchRenderer.swift:144`) standing, so the winding question — which Metal's y-down window coordinates invert — never has to be answered. |
| D8 | **Draw order is far facets, then near facets, then edges.** The solid is convex, so exactly one far and one near fragment cover each pixel and that order is exact back-to-front. Blending is `sourceAlpha` / `oneMinusSourceAlpha` on both passes. **Only the near pass writes depth**, which leaves the depth buffer holding the visible surface for the edge pass to test against. |
| D9 | **Edges depth-test when the solid is opaque and do not when it is translucent**, switching at the build constant `opaqueAbove = 0.999`. At full opacity hidden edges stay hidden, exactly as part 2 shipped; the moment the solid is translucent the entire wireframe shows, which is what checking a pavilion facet against a crown facet actually requires. **Crossing the threshold pops, and that is accepted rather than smoothed** — a depth rejection is binary, so fading it would mean reading the depth buffer to dim far edges, which is a real renderer feature bought for a cosmetic. *(Corrected at T3's owner stop, 2026-08-24: the pop was rejected in the app, and the threshold is gone with it. The edges now draw **twice** over the same line buffer — every edge at alpha `1 − opacity` with the depth test off, then the visible ones at full alpha with it on — so the hidden half of the wireframe fades in with the fill and no depth buffer is read back. The alpha rides in `params.w`, which this plan had left unused, and `opaqueAbove` no longer exists. The same stop found a second thing this plan did not foresee: part 2's headlight is fixed in **view** space, so every far facet clamps to `kAmbient` and the pavilion reads as one flat mass behind a translucent crown rather than as facets, which is what this part's own verification handle promises. `fill_vertex` therefore shades a far facet by its flipped normal, selected on the `facing` it already computes. Near facets are untouched, so the opaque image is still part 2's.)* |
| D10 | **Picking is a slab test over the half-spaces, pure, in `BenchGeometry`.** The entry parameter is the `max` of `(d − n·o) / (n·dir)` over planes the ray runs into (`n·dir < 0`), the exit is the `min` over planes it runs out of (`n·dir > 0`); a hit needs `entry <= exit` and `entry > 0`, and the facet is the plane that produced the entry. **A plane absent from `polytope.facets` returns no hit** — a plane cut away by the others, or grazing one edge, has no polygon to click and must never be named. |
| D11 | **A pick returns `FacetOrigin?`.** The displayed name is `RoughFacet.name` for rough — `C`, `P`, `G1`…`G16` (`RoughPrism.swift:24`) — and `"<tier> · <index>"` for a cut facet, those being the same two values the tier table's Tier and Indices columns carry (`BenchRegions.swift:47`). Nothing invents a name for a plane with no `origin` entry; it reads as no selection. |
| D12 | **The picked facet is highlighted in the fill**, which needs the plane index per vertex: `MeshVertex` gains `planeIndex: Float`, taking stride 28 → **32** and offsets to **0, 12, 24, 28**. Without the highlight a click has no visible answer, so a name in the readout cannot be distinguished from a hardcoded string — the highlight is what makes the check in T5 mean anything. |
| D13 | **The click becomes a world ray by inverting `projection * view`** and unprojecting the NDC point at `z = 0` and at `z = 1`; the ray runs from the first toward the second. **NDC is `(2x/width − 1, 2y/height − 1)` from the point returned by `convert(event.locationInWindow, from: nil)`, with no y-flip**, because an `NSView` is y-up unless `isFlipped` says otherwise and `MTKView` does not. T5's negative check is what catches a flip: clicking the top of the stone must name a crown or table facet, never `P`. |
| D14 | **The ring carries one label per distinct `(wheel, index)` pair** across the solved tiers, deduplicated, sorted by azimuth then wheel then index. **Text is the index alone while every label shares one wheel** — true of all four authored patterns, each `"wheel": 96` with no tier override — and `index/wheel` as soon as two wheels appear, which is U4's "reads in its own gear". Each anchor sits at azimuth `2π · index / wheel`, radius **1.6** and `z = 0`, just outside the rough's radius of 1.5 (`RoughPrism.swift:10`). |
| D15 | **The ring's alpha is `min(abs(elevation) / 12, 1)`** — one build constant, `ringFadeDegrees`, so the ring is gone edge-on where the rim projects to a line and full from 12° up. Tuned by eye at T7's owner stop; **not a preference** (U4). |
| D16 | **The ring is SwiftUI `Text` in an overlay over the Metal view**, positioned by projecting each anchor through the same `benchProjectionMatrix(aspect:) * benchViewMatrix(camera)` the renderer uses. Text in Metal means a glyph atlas for a dozen numerals; the overlay reuses the pure matrices, so it cannot disagree with the solid about where the rim is. |
| D17 | **`BenchSolid` gains `tiers: [SolvedTier]`, empty for no pattern**, as the ring's source. It comes from the solve, never from the raw `Pattern`: a tier the solver could not place has no depth and no facets, so it contributes no index stops. With no pattern there are no tiers and therefore no ring, which is U4's last line, falling out rather than being special-cased. |
| D18 | **No bespoke palette (U2).** The highlight resolves `NSColor.selectedContentBackgroundColor` and the ring labels use `.secondaryLabelColor`, both through the existing per-draw path (`BenchRenderer.swift:175`) or SwiftUI's own semantic styles. **No hardcoded sRGB anywhere**, so the solid and the ring track light and dark appearance with the rest of the window. |
| D19 | **Nothing in this plan edits `project.pbxproj`.** The target's synchronised group (`project.pbxproj:30`, `isa = PBXFileSystemSynchronizedRootGroup;`) makes a new `.swift` file in `CuttingBench/CuttingBench/` a member automatically. Hand-editing that file is a protocol guardrail violation and a stop, never a step. |
| D20 | **Building and running the app is the owner's action at every owner stop.** No shared `.xcscheme` exists — `xcuserdata/` is gitignored — so the agent has no way to build the app target. The agent's own checks are the `BenchGeometry` tests and `swift-format`, named per task. |

## Tickets closed by this plan

None. The exploration `2-Cutting-Bench-App-Shell` folded no ticket in — no open ticket touched this
slice — so there is nothing to close. **T8 still runs the archive routine** for this plan, both sibling
parts and the exploration, which is this part's job as the last one.

## Prefactoring

**One task, T1.** The camera is three functions closed over static constants (`BenchCamera.swift:19`,
`:27`, `:43`). Every task after this one needs a camera that varies, and changing those functions while
adding orbit would mix a mechanical parameterisation into a behaviour change and leave nothing able to
say which broke the framing.

T1 threads a `BenchCameraState` argument through with a default equal to today's constants, so
**`BenchCameraTests` passes unchanged, unedited** — that is the whole check. The new orientations get
their own new assertions in the same task, which is where the existing framing test stops being a
statement about one camera and becomes one about every camera the orbit can reach.

## Approach

Four things, each a pure function in `BenchGeometry` plus a thin wiring in the app: a camera that
varies, a ray-to-facet pick, a translucent fill, and a ring of numbers. The seam is part 2's — the
package holds the maths and its tests, the app holds AppKit and Metal.

**`FacetKernel`'s `dot`, `cross` and `distance` on the `(x:y:z:)` tuple are internal**, not public
(`Kernel/Sources/FacetKernel/Geometry/Polytope.swift:124`, `func dot(`). `BenchGeometry` cannot call
them and must not be given access to them; where this plan needs a tuple dot product it declares a
`private` one in the file that needs it. Do not add `@testable` or make anything in the kernel public.

### 1. `CuttingBench/BenchGeometry/Sources/BenchGeometry/BenchCamera.swift` (edit)

`BenchCamera`'s existing seven constants stay exactly as they are (`:8`–`:15`). Add one:

```swift
public static let orbitDegreesPerPoint: Float = 0.5
```

New, above the functions:

```swift
/// Where the camera is, as a value. `distance` and the field of view are not in here: there is no
/// zoom (D1).
public struct BenchCameraState: Equatable, Sendable {
  public var azimuthDegrees: Float
  public var elevationDegrees: Float

  public init(azimuthDegrees: Float, elevationDegrees: Float) { … }

  /// The three-quarter view part 2 shipped, and the app's starting camera.
  public static let threeQuarter = BenchCameraState(
    azimuthDegrees: BenchCamera.azimuthDegrees,
    elevationDegrees: BenchCamera.elevationDegrees)
  /// Straight down at the crown, and straight up at the pavilion. Exactly ±90, at the azimuth that
  /// puts +x at screen right (D3).
  public static let faceUp = BenchCameraState(azimuthDegrees: 270, elevationDegrees: 90)
  public static let faceDown = BenchCameraState(azimuthDegrees: 270, elevationDegrees: -90)

  /// One drag. Azimuth wraps, elevation clamps at the poles (D2, D4).
  public mutating func orbit(dxPoints: Float, dyPoints: Float) {
    azimuthDegrees =
      (azimuthDegrees + dxPoints * BenchCamera.orbitDegreesPerPoint)
      .truncatingRemainder(dividingBy: 360)
    elevationDegrees = min(
      90, max(-90, elevationDegrees + dyPoints * BenchCamera.orbitDegreesPerPoint))
  }
}
```

`benchCameraPosition` (`:19`) and `benchViewMatrix` (`:27`) each take
`_ camera: BenchCameraState = .threeQuarter` and read `camera.azimuthDegrees` /
`camera.elevationDegrees` in place of the statics. **The default is what keeps `BenchCameraTests`
passing unedited** (T1). `benchProjectionMatrix(aspect:)` (`:43`) is untouched — no zoom.

Inside `benchViewMatrix`, `:30` (`let xAxis = normalize(cross(SIMD3<Float>(0, 0, 1), zAxis))`) becomes:

```swift
// The +z up reference is parallel to the view direction at the poles, where the cross product is zero
// and its normalize is NaN. Normalising it elsewhere divides out the cos(elevation), leaving a value
// that depends on the azimuth alone — so this is the same axis at every elevation and defined at ±90
// as well (D3).
let az = camera.azimuthDegrees * .pi / 180
let xAxis = SIMD3<Float>(-sin(az), cos(az), 0)
```

`yAxis` (`:31`, `let yAxis = cross(zAxis, xAxis)`) is unchanged and stays the derived one, so the basis
is orthonormal and right-handed by construction at every camera the orbit can reach.

Two new functions at the end of the file, the camera's forward and inverse for the app:

```swift
/// The world ray under a point in Metal's NDC, `x` and `y` each in `-1...1` (D13). `direction` is not
/// unit. Inverts `projection * view` and takes the near point and the far point.
public func benchRay(
  ndcX: Float,
  ndcY: Float,
  aspect: Float,
  camera: BenchCameraState = .threeQuarter
) -> (origin: SIMD3<Float>, direction: SIMD3<Float>)

/// Where a world point lands in the viewport, as a fraction of its size with `(0, 0)` **top-left** —
/// SwiftUI's own convention, so the overlay multiplies by its size and nothing else (D16). `nil` when
/// the point is behind the camera (`clip.w <= 0`).
public func benchScreenPoint(
  _ world: SIMD3<Float>,
  aspect: Float,
  camera: BenchCameraState = .threeQuarter
) -> (x: Double, y: Double)?
```

`benchRay` divides each unprojected point by its own `w` before subtracting. `benchScreenPoint`
returns `x = (ndc.x + 1) / 2` and `y = (1 - ndc.y) / 2` — **the y flip lives here and nowhere else.**

### 2. New: `CuttingBench/BenchGeometry/Sources/BenchGeometry/BenchPick.swift` (pure)

```swift
/// The facet a ray meets first, or `nil` when it misses.
///
/// A slab test over the half-spaces (D10). Exact for a convex solid, and it reads only `planes` and
/// `polytope.facets.keys` — the polygons themselves never enter it, so a pick can never name a facet
/// the renderer did not draw.
public func pickFacet(
  _ solid: BenchSolid,
  origin: SIMD3<Float>,
  direction: SIMD3<Float>,
  parallelBelow: Double = 1e-9
) -> (planeIndex: Int, facet: FacetOrigin)?

/// The label a picked facet reads as: `C`, `P`, `G1`…`G16` for rough, `"<tier> · <index>"` for a cut
/// facet — the tier table's own two columns (D11).
public func facetLabel(_ facet: FacetOrigin) -> String
```

`pickFacet`'s body, exactly:

- Convert `origin` and `direction` to `Double` triples once.
- `var entry = -Double.greatestFiniteMagnitude`, `var entryPlane: Int?`,
  `var exit = Double.greatestFiniteMagnitude`.
- For each `(index, plane)` in `solid.planes.enumerated()`: let `nd = dot(plane.n, dir)` and
  `no = dot(plane.n, o)`.
  - `abs(nd) < parallelBelow` — the ray runs parallel to this plane. If `no > plane.d` the ray is
    outside that slab for its whole length and **misses the solid: return `nil`.** Otherwise skip it.
  - `t = (plane.d - no) / nd`. If `nd < 0` the ray runs *into* the half-space, so
    `if t > entry { entry = t; entryPlane = index }`. If `nd > 0` it runs *out*, so
    `exit = min(exit, t)`.
- `guard let entryPlane, entry <= exit, entry > 0 else { return nil }`.
- `guard solid.polytope.facets[entryPlane] != nil, let facet = solid.origin[entryPlane]
  else { return nil }` — a plane with no polygon was cut away and has nothing to click, and a plane
  with no `origin` entry gets no invented name (D10, D11).
- `return (entryPlane, facet)`.

`dot` here is a `private func dot(_ a: (x: Double, y: Double, z: Double), _ b: …) -> Double` in this
file, because the kernel's is internal to the kernel.

### 3. New: `CuttingBench/BenchGeometry/Sources/BenchGeometry/IndexRing.swift` (pure)

```swift
/// The ring's build constants. No UI and no preference (D15, U4).
public enum IndexRing {
  /// Just outside the rough's radius of 1.5, so nothing on the stone occludes a number.
  public static let radius = 1.6
  /// The girdle plane. Every authored pattern's girdle sits about here.
  public static let z = 0.0
  /// Full alpha from this elevation up, zero at edge-on. **One constant**, tuned at T7's owner stop.
  public static let fadeDegrees: Float = 12
}

/// One number around the rim: what it reads and where in the world it sits.
public struct IndexRingLabel: Equatable, Sendable {
  public var wheel: Int
  public var index: Int
  public var text: String
  public var anchor: SIMD3<Float>
}

/// The index stops the pattern actually uses (D14, D17).
///
/// One label per distinct `(wheel, index)` across `solid.tiers`, ordered by azimuth, then wheel, then
/// index. `text` is the index alone while every label shares one wheel, and `"\(index)/\(wheel)"` as
/// soon as two wheels appear, so a tier cut in its own gear reads in it. Empty for no pattern, which
/// is what leaves a bare prism with no ring.
public func indexRingLabels(_ solid: BenchSolid) -> [IndexRingLabel]

/// The ring's alpha at this camera: `min(abs(elevation) / IndexRing.fadeDegrees, 1)` (D15).
public func indexRingAlpha(_ camera: BenchCameraState) -> Double
```

`indexRingLabels` walks `solid.tiers`, taking `(tier.wheel, index)` for each `index` in `tier.indices`
into a `Set<SIMD2<Int>>` for the dedupe. The azimuth is `2 * .pi * Double(index) / Double(wheel)` and
the anchor is `SIMD3(Float(cos(theta) * IndexRing.radius), Float(sin(theta) * IndexRing.radius),
Float(IndexRing.z))` — the same convention as the rough's walls (`RoughPrism.swift:44`) and as
`planeNormal`, index 0 on +x and advancing counter-clockwise. The single-wheel test is
`Set(labels.map(\.wheel)).count == 1`, decided **after** the dedupe and applied to every label, so the
whole ring reads in one style rather than switching per label.

### 4. `CuttingBench/BenchGeometry/Sources/BenchGeometry/BenchSolid.swift` (edit)

`BenchSolid` gains a fourth stored property after `polytope` (`:22`, `public var polytope: Polytope`):

```swift
/// The tiers that actually placed, as the index ring's source. Empty for no pattern (D17).
public var tiers: [SolvedTier]
```

`init` gains `tiers: [SolvedTier] = []` **as its last parameter with that default**, so every existing
construction in `BenchSolidTests` and `BenchCameraTests` still compiles unchanged.

In `benchSolid(for:tierLimit:)` (`:63`), collect `partial.solution.tiers` into a local declared
alongside `planes` and `origin`, and pass it at `:88`
(`return BenchSolid(planes: planes, origin: origin, polytope: intersectHalfSpaces(planes))`). It comes
from the **solution**, never from `truncated.tiers` — a tier the solver could not place has no depth,
no planes and therefore no index stops (D17).

### 5. `CuttingBench/BenchGeometry/Sources/BenchGeometry/SolidMesh.swift` (edit)

`MeshVertex` gains an eighth `Float` after `role` (`:15`, `public var role: Float`):

```swift
/// The plane this vertex's facet belongs to, so the shader can highlight one facet (D12). `-1` on an
/// edge vertex, which is shared by two facets and belongs to neither.
public var planeIndex: Float
```

Add it to `init` as the last parameter, no default. **Eight `Float`s, no padding: stride 32, offsets 0,
12, 24 and 28** — update the doc comment at `:5` that states the old three numbers, and see §11 for the
test that pins them.

`private func meshVertex` (`:88`) gains a `planeIndex: Float` parameter and passes it through. Its
three call sites: the triangle append at `:68` passes `Float(planeIndex)` from the loop variable; the
two edge appends at `:80` and `:81` pass `-1`. The `role: 0` on the edge vertices stays as it is.

Nothing else in this file changes — the winding, the fan, the plane-normal rule and the edge dedupe are
all part 2's and correct.

### 6. `CuttingBench/CuttingBench/Shaders.metal` (edit)

`Uniforms` (`:4`) gains three `float4`s at the end. **`Uniforms` in `BenchRenderer.swift:9` is
field-for-field identical and both carry a comment saying so — change one and change the other.**

```metal
  float4 highlightColor;
  /// xyz: the camera position in world space. w unused.
  float4 eye;
  /// x: opacity. y: this pass's facing sign, +1 near or -1 far. z: the highlighted plane index, or -1.
  /// w unused.
  float4 params;
```

`VertexIn` (`:12`) gains `float planeIndex [[attribute(3)]];`. `FillOut` (`:18`) gains `float facing;`.

`fill_vertex` (`:31`) keeps its shade and `mix` exactly as they are, and adds two things:

```swift
  // Constant across a facet: every point on it satisfies dot(n, p) == d, so this is n·eye − d and its
  // sign says whether the facet points at the camera (D7).
  out.facing = dot(in.normal, u.eye.xyz) - dot(in.normal, in.position);
  …
  // Exact for small integers held in a float; the tolerance is belt and braces.
  if (abs(in.planeIndex - u.params.z) < 0.5) { base = u.highlightColor; }
  out.color = float4(base.rgb * shade, base.a * u.params.x);
```

`fill_fragment` (`:41`) takes the uniforms and gains the pass test:

```metal
fragment float4 fill_fragment(FillOut in [[stage_in]], constant Uniforms &u [[buffer(1)]]) {
  // One pass draws the facets pointing away and the next those pointing at the camera, so the pair
  // blends back to front with no cull mode and no winding convention (D7, D8).
  if (in.facing * u.params.y < 0.0) { discard_fragment(); }
  return in.color;
}
```

`edge_vertex` and `edge_fragment` (`:47`, `:54`) are **unchanged**, including the depth epsilon.
Edges keep full alpha at every opacity — that is what "fades to wireframe" means, and at opacity 0 it
leaves a clean wireframe.

### 7. `CuttingBench/CuttingBench/BenchRenderer.swift` (edit)

The Swift `Uniforms` (`:9`) gains the same three fields in the same order:
`highlightColor`, `eye`, `params`, each `SIMD4<Float>`.

**One new constant** on the type: `static let opaqueAbove = 0.999` (D9).

**Three settable properties**, replacing nothing — the view sets them before asking for a redraw:

```swift
var camera: BenchCameraState = .threeQuarter
var opacity: Double = 1
/// The picked facet's plane index, or `nil` for no selection (D12).
var highlightedPlaneIndex: Int?
```

**Blending on the shared descriptor**, added before either pipeline is built (so above `:54`). The edge
pipeline inherits it harmlessly: `.labelColor` is opaque, and blending an opaque source is a no-op.

```swift
descriptor.colorAttachments[0].isBlendingEnabled = true
descriptor.colorAttachments[0].rgbBlendOperation = .add
descriptor.colorAttachments[0].alphaBlendOperation = .add
descriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
descriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
descriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
descriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
```

**Three depth states in place of the one at `:65`–`:68`** (`let depth = MTLDepthStencilDescriptor()`),
built by a small `private static func depthState(_ device:, compare:, write:)` so the three read as
three lines rather than fifteen:

| Property | Compare | Write | Used by |
|---|---|---|---|
| `depthTestNoWrite` | `.less` | off | the far fill pass, and the edges while opaque |
| `depthTestWrite` | `.less` | on | the near fill pass |
| `depthAlways` | `.always` | off | the edges while translucent |

**`draw(in:)`** (`:118`). The clear colour and `rgba` calls stay. The matrix block at `:127`–`:133`
becomes:

```swift
let viewMatrix = benchViewMatrix(camera)
let eye = benchCameraPosition(camera)
var uniforms = Uniforms(
  viewProjection: benchProjectionMatrix(aspect: aspect(of: view)) * viewMatrix,
  view: viewMatrix,
  cutColor: rgba(.controlAccentColor, in: appearance),
  roughColor: rgba(.systemGray, in: appearance),
  edgeColor: rgba(.labelColor, in: appearance),
  highlightColor: rgba(.selectedContentBackgroundColor, in: appearance),
  eye: SIMD4(eye, 0),
  params: SIMD4(Float(opacity), -1, Float(highlightedPlaneIndex ?? -1), 0))
```

`encoder.setCullMode(.none)` at `:144` **stays** — that is the point of D7. The two
`setDepthStencilState` / `setVertexBytes` / `setFragmentBytes` calls at `:146`–`:147` move **inside**
the draws, because each pass now sets its own:

```swift
if let triangleBuffer, triangleCount > 0 {
  encoder.setRenderPipelineState(fillPipeline)
  encoder.setVertexBuffer(triangleBuffer, offset: 0, index: 0)
  // Far facets first writing no depth, then the near ones, which do. Exact back-to-front for a convex
  // solid, and it leaves the depth buffer holding the visible surface for the edges (D8).
  for (facingSign, depthState) in [(Float(-1), depthTestNoWrite), (Float(1), depthTestWrite)] {
    uniforms.params.y = facingSign
    encoder.setDepthStencilState(depthState)
    encoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 1)
    encoder.setFragmentBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 1)
    encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: triangleCount)
  }
}

if let edgeBuffer, edgeCount > 0 {
  encoder.setDepthStencilState(
    opacity > BenchRenderer.opaqueAbove ? depthTestNoWrite : depthAlways)
  encoder.setRenderPipelineState(edgePipeline)
  encoder.setVertexBuffer(edgeBuffer, offset: 0, index: 0)
  encoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 1)
  encoder.setFragmentBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 1)
  encoder.drawPrimitives(type: .line, vertexStart: 0, vertexCount: edgeCount)
}
```

`setVertexBytes` copies at the call, so mutating `uniforms.params.y` between the two iterations is safe
and is why one `var` serves both passes.

**`vertexDescriptor()`** (`:75`) gains a fourth attribute, offset read from `MemoryLayout` like the
other three and never hand-counted:

```swift
descriptor.attributes[3].format = .float
descriptor.attributes[3].offset = MemoryLayout<MeshVertex>.offset(of: \.planeIndex)!
descriptor.attributes[3].bufferIndex = 0
```

### 8. `CuttingBench/CuttingBench/MetalViewport.swift` (edit)

`BenchMetalView` keeps `viewDidChangeEffectiveAppearance` (`:8`) exactly as it is and gains the mouse
handling. **The drag delta comes from successive `locationInWindow` conversions, never from
`NSEvent.deltaY`** — an `NSView`'s coordinates are unambiguously y-up, so dragging up is a positive
`dy` and raises the elevation, while `deltaY`'s sign convention is precisely the thing that would
otherwise have to be guessed at.

```swift
  /// A drag this short is a click, not an orbit.
  static let clickSlopPoints: CGFloat = 3

  var onOrbit: ((CGFloat, CGFloat) -> Void)?
  var onPick: ((CGPoint, CGSize) -> Void)?
  private var lastPoint: CGPoint?
  private var dragDistance: CGFloat = 0

  override func mouseDown(with event: NSEvent) {
    lastPoint = convert(event.locationInWindow, from: nil)
    dragDistance = 0
  }

  override func mouseDragged(with event: NSEvent) {
    let point = convert(event.locationInWindow, from: nil)
    guard let previous = lastPoint else { return }
    lastPoint = point
    dragDistance += abs(point.x - previous.x) + abs(point.y - previous.y)
    // Under the slop this is still a click, so the camera must not move — otherwise every click on a
    // facet nudges the view by up to 1.5°.
    guard dragDistance > BenchMetalView.clickSlopPoints else { return }
    onOrbit?(point.x - previous.x, point.y - previous.y)
  }

  override func mouseUp(with event: NSEvent) {
    guard dragDistance <= BenchMetalView.clickSlopPoints else { return }
    onPick?(convert(event.locationInWindow, from: nil), bounds.size)
  }
```

`MetalViewport` gains five stored properties after `generation` (`:19`): `camera: BenchCameraState`,
`opacity: Double`, `highlightedPlaneIndex: Int?`, `onOrbit: (CGFloat, CGFloat) -> Void` and
`onPick: (CGPoint, CGSize) -> Void`. `makeNSView` (`:28`) is unchanged. `updateNSView` (`:43`) becomes:

```swift
  func updateNSView(_ view: BenchMetalView, context: Context) {
    view.onOrbit = onOrbit
    view.onPick = onPick
    guard let renderer = context.coordinator.renderer else { return }
    // The mesh is still uploaded only when it actually changed; the camera and the display state are
    // pushed every update, which SwiftUI runs only when one of them did change.
    if context.coordinator.uploaded != generation {
      renderer.setMesh(mesh)
      context.coordinator.uploaded = generation
    }
    renderer.camera = camera
    renderer.opacity = opacity
    renderer.highlightedPlaneIndex = highlightedPlaneIndex
    view.needsDisplay = true
  }
```

### 9. New: `CuttingBench/CuttingBench/IndexRingOverlay.swift`

```swift
/// The index stops around the rim, as SwiftUI text over the Metal view (D16, U4). Positioned through
/// the same pure matrices the renderer uses, so it cannot disagree with the solid about where the rim
/// is. `.allowsHitTesting(false)` is load-bearing: without it the numbers eat the clicks meant for the
/// facet under them.
struct IndexRingOverlay: View {
  let labels: [IndexRingLabel]
  let camera: BenchCameraState

  var body: some View {
    GeometryReader { proxy in
      let size = proxy.size
      let aspect = size.height > 0 ? Float(size.width / size.height) : 1
      ForEach(labels) { label in
        if let point = benchScreenPoint(label.anchor, aspect: aspect, camera: camera) {
          Text(label.text)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .position(x: CGFloat(point.x) * size.width, y: CGFloat(point.y) * size.height)
        }
      }
    }
    .allowsHitTesting(false)
    .opacity(indexRingAlpha(camera))
  }
}
```

`ForEach(labels)` needs identity, so `IndexRingLabel` conforms to `Identifiable` in §3 with
`public var id: SIMD2<Int> { SIMD2(wheel, index) }` — the same pair the dedupe keys on. `.secondary`
is the semantic style, not a colour value (D18).

### 10. `CuttingBench/CuttingBench/BenchRegions.swift` (edit)

`ViewportRegion` (`:7`) takes the new state through and hosts the overlay:

```swift
struct ViewportRegion: View {
  let mesh: SolidMesh
  let generation: Int
  let camera: BenchCameraState
  let opacity: Double
  let highlightedPlaneIndex: Int?
  let ringLabels: [IndexRingLabel]
  let onOrbit: (CGFloat, CGFloat) -> Void
  let onPick: (CGPoint, CGSize) -> Void

  var body: some View {
    MetalViewport(…)
      .overlay { IndexRingOverlay(labels: ringLabels, camera: camera) }
  }
}
```

**Update this type's doc comment.** It currently reads *"**One replaceable subview** (D2), and nothing
else may draw here"* (`:6`). That was part 2's own boundary; U4 puts the index ring over the viewport,
which is this part's job, so the comment now reads: one Metal subview plus the index-ring overlay, and
nothing else may draw here. **This is not a plan-versus-code conflict and is not a stop** — the comment
is being corrected by the part that owns U4.

`StatusStripRegion` (`:88`) gains one stored property and one readout. Not behind `#if DEBUG` — being
told the facet's name is what this part delivers, not a diagnostic:

```swift
  /// The picked facet's label, or `nil` for no selection (D11).
  let selectedFacet: String?
```

In the `HStack` (`:96`), directly after `Spacer(minLength: 8)` (`:98`) and **before** the `#if DEBUG`
block, so it is present in a release build:

```swift
      Text(selectedFacet.map { "Facet \($0)" } ?? "No facet selected")
```

The leading `Text("No findings")` stays exactly where it is: U1 fixes the strip's leading content as
the findings line, and this readout is trailing. `ScrubberRegion`, `TierRow`, `TierTableRegion`,
`InspectorRegion` and `EmptyCard` are **untouched**.

### 11. `CuttingBench/CuttingBench/BenchWindow.swift` (edit)

Three new pieces of `@State` beside the existing ones (`:10`–`:15`). Two separate optionals rather than
one tuple, because a tuple is not `Equatable` and `@State` reads better without it:

```swift
  @State private var camera = BenchCameraState.threeQuarter
  @State private var solidOpacity = 1.0
  @State private var selectedPlaneIndex: Int?
  @State private var selectedFacetLabel: String?
```

`ViewportRegion` at `:21` gets the new arguments, with `ringLabels: indexRingLabels(store.solid)` —
derived in `body` from the one solid the renderer draws, so the ring cannot describe a different stone
(32 labels for the round brilliant; recomputing it per update is nothing).

`StatusStripRegion` at `:31` and `:33` both gain `selectedFacet: selectedFacetLabel`.

The `.toolbar` block (`:41`) gains the two snap buttons and the opacity slider **before** the existing
inspector button, so the inspector toggle stays where the owner already knows it is:

```swift
      Button { camera = .faceUp } label: {
        Label("Face Up", systemImage: "arrow.down.to.line")
      }
      Button { camera = .faceDown } label: {
        Label("Face Down", systemImage: "arrow.up.to.line")
      }
      Slider(value: $solidOpacity, in: 0...1) { Text("Opacity") }
        .frame(width: 140)
```

Two new private methods. **`pick` applies no y flip** — an `NSView` is y-up and Metal's NDC y is up, so
the two agree and inserting a flip is the bug T5's negative check catches (D13):

```swift
  private func orbit(dx: CGFloat, dy: CGFloat) {
    camera.orbit(dxPoints: Float(dx), dyPoints: Float(dy))
  }

  private func pick(at point: CGPoint, in size: CGSize) {
    guard size.width > 0, size.height > 0 else { return }
    let ray = benchRay(
      ndcX: Float(2 * point.x / size.width - 1),
      ndcY: Float(2 * point.y / size.height - 1),
      aspect: Float(size.width / size.height),
      camera: camera)
    let hit = pickFacet(store.solid, origin: ray.origin, direction: ray.direction)
    selectedPlaneIndex = hit?.planeIndex
    selectedFacetLabel = hit.map { facetLabel($0.facet) }
  }
```

A click that misses the solid clears both, which is the negative half of T5's check.

**`rebuild()` clears the selection too**, as its first two lines:

```swift
    selectedPlaneIndex = nil
    selectedFacetLabel = nil
```

A plane index means nothing across a rebuild. The tier limit decides how many solved planes are
appended after the rough's eighteen (`BenchSolid.swift:83`), so stepping the tier count with a facet
picked would leave the highlight on an unrelated plane and the strip reading the old name. Opening a
different pattern is the same case. The `.onChange` handlers that call `rebuild()` and the `tierLimit`
diagnostic itself are **untouched** — the tier-limit stepper is still how a rough-and-pattern solid is
reached at all, and a later slice's scrubber supersedes it, not this part.

### 12. Tests, in `CuttingBench/BenchGeometry/Tests/BenchGeometryTests/`

- **`BenchCameraTests.swift`** (edit) — the four existing tests are **not edited**; they keep calling
  the defaulted functions and passing is T1's whole check. Add: `orbit` wraps azimuth past 360 and
  clamps elevation at ±90 from beyond it; `benchViewMatrix(.faceUp)` and `(.faceDown)` produce finite,
  orthonormal bases (no NaN — the pole case, D3); face-up puts world `+x` at positive view-space `x`
  and `+y` at positive view-space `y`, which is what pins the snaps' azimuth of 270; **the basis is
  continuous through the pole** — the upper-left 3×3 of `benchViewMatrix` at elevation `89.9` and at
  `90`, both at azimuth `45`, agree to `5e-3` in every component, which is the assertion an up
  reference swapped *near* the pole rather than *at* it would fail; `benchRay` down the exact centre
  (`ndcX: 0, ndcY: 0`) returns a
  direction parallel to `BenchCamera.target - benchCameraPosition(camera)`; `benchScreenPoint` of
  `BenchCamera.target` is `(0.5, 0.5)`; and `benchScreenPoint` of a point above the target has
  **`y < 0.5`**, which pins the one y flip in the codebase. Widen
  `testTheFramingConstantsFitTheWholeRough` (`:45`) to loop the same assertions over
  `elevationDegrees` in `[-90, -25, 0, 25, 90]` × `azimuthDegrees` in `[0, 22.5, 45, 270]` — 270 being
  the snaps' own azimuth — × the two aspects it already uses, and to include **32 points evenly spaced
  around the circle of radius
  `IndexRing.radius` at `z = IndexRing.z`** alongside every rough vertex (T1 writes those as the
  literals `1.6` and `0.0`, because `IndexRing` does not exist until T6). Every ring anchor any pattern
  can produce lies on that circle, so the circle is the framing constraint and no pattern needs
  loading. **If it fails, raise `BenchCamera.distance` by 0.5 until it passes and record it as a
  material alteration** — `distance` is the tuning constant, and nothing else moves.

- **New `BenchPickTests.swift`** — against the bare prism and against the round brilliant: a ray down
  the axis from above hits `C` on the prism and the table tier on the stone; a ray up the axis from
  below hits `P`; a ray along `-x` from far out on `+x` hits `G1`; a ray aimed past the solid returns
  `nil`; a ray parallel to a wall and outside it returns `nil`; the returned `planeIndex` is always a
  key of `solid.polytope.facets`; and `facetLabel` gives `C`, `P`, `G1`, `G16` and `"P1 · 3"` shapes.
- **New `IndexRingTests.swift`** — the round brilliant yields one label per distinct `(wheel, index)`
  with no duplicates, every `text` the bare index because that pattern is single-wheel, anchors at
  radius `1.6` and `z == 0`, azimuth matching `2π·index/wheel`, and ascending azimuth order; a
  two-wheel `Pattern` built in the test switches every label to `index/wheel`; `benchSolid(for: nil)`
  yields **no labels**; and `indexRingAlpha` is `0` at elevation `0`, `1` at `12` and at `90`, and
  `0.5` at `6`.
- **`SolidMeshTests.swift`** (edit) — `testTheVertexLayoutIsSevenFloatsWithNoPadding` (`:12`) is
  renamed to `testTheVertexLayoutIsEightFloatsWithNoPadding` and its four assertions become stride
  `32` and offsets `0`, `12`, `24`, `28` (`:13`–`:16`). Add: every triangle vertex's `planeIndex`
  equals the plane it came from, and every edge vertex's is `-1`.

## Explicitly not doing

- **No zoom, and no pan.** U3 asked for orbit, snaps and opacity. `distance` and `target` stay build
  constants, which is also what keeps the framing test a real check (D1).
- **No animated camera transitions.** The snaps jump (D5).
- **No pattern geometry beyond what part 2 already draws.** The tier table, the inspector cards, the
  scrubber and the findings line stay empty or unconditional — each belongs to a later slice, and the
  `#if DEBUG` tier-limit stepper remains the only way to reach a rough-and-pattern solid.
- **No two-facet picking, no picking for meets, no ray probe.** This part names one facet at a time.
  Selecting *edges* and anchoring points are later slices; `U2` lists their colour roles only so the
  palette stays open to them.
- **No 2D plan view and no crown/pavilion switch** (U4). The face-up snap is the plan view.
- **No yield, no volume, no rough-retention readout** (S3). No `Polytope` volume code of any kind.
- **No preference, no Settings, no persistence of camera or opacity.** U4 fixes the fade threshold as a
  build constant, and a document reopens at the three-quarter view.
- **No bespoke palette, no type scale, no spacing scale** (U2, D18). Two more named system colours and
  `.caption2`.
- **No `project.pbxproj` edit** (D19), and **nothing in the kernel changes** — no new public symbol, no
  `@testable` import of `FacetKernel`.
- **No occlusion of individual ring labels.** The ring is outside the stone and fades as a whole; hiding
  the numbers on the far side is not asked for and would need per-label depth.

## Tasks

**Every task runs these before it is done, in this order**, in place of the protocol's `Kernel`-only
gates 1 and 2 — gate 1 still applies unconditionally, and gate 3 never fires because no task here
touches `Kernel/`:

1. `swift test --package-path Kernel --disable-sandbox` — green. (Protocol gate 1.)
2. `swift test --package-path CuttingBench/BenchGeometry --disable-sandbox` — green.
3. `xcrun swift-format lint --recursive --strict Kernel/Sources Kernel/Tests
   CuttingBench/BenchGeometry/Sources CuttingBench/BenchGeometry/Tests CuttingBench/CuttingBench` —
   clean.
4. The task's own *Done when* items, verbatim.

**The agent cannot build or run the app** (D20): there is no shared scheme. Where a task changes app
code, "it compiles" is the owner's ⌘R at the owner stop, and a compile error found there is a normal
continuation of that task, not a blocker.

| # | Task | Status | Then | Commit | Note |
|---|---|---|---|---|---|
| T1 | Prefactor: the camera becomes a value | completed | checkpoint | commit | |
| T2 | Free orbit and the two snap views | completed | **owner stop** | commit | material alteration: D4's drag direction was reversed on both axes at the owner stop — see D4 |
| T3 | The opacity control | completed | **owner stop** | commit | material alteration: D9's edge pop replaced by a two-pass edge fade, and a far facet is now shaded by its flipped normal — see D9 |
| T4 | Pure: `pickFacet` and `facetLabel` | completed | continue | — | |
| T5 | Click a facet, highlight it, name it | awaiting owner | **owner stop** | commit | |
| T6 | Pure: the index ring's labels and its fade | not started | continue | — | |
| T7 | The index ring over the viewport | not started | **owner stop** | commit | |
| T8 | Close out | not started | **owner stop** | commit + push | |

Five owner stops in eight tasks, because **T2, T3, T5 and T7 each change what the owner can see and
operate** and the protocol puts a stop after every one of those; T8 is plan completion, which always
carries one. T4 and T6 are pure and testable, so they share the following task's commit rather than
manufacturing one of their own.

**T1 — Prefactor: the camera becomes a value**

Behaviour-preserving. Nothing on screen changes, and that is the check.

- **Files:** `CuttingBench/BenchGeometry/Sources/BenchGeometry/BenchCamera.swift` (edit),
  `CuttingBench/BenchGeometry/Tests/BenchGeometryTests/BenchCameraTests.swift` (edit)
- **Done when:**
  - `BenchCameraState`, `benchRay` and `benchScreenPoint` exist with the signatures in §1.
  - `benchCameraPosition` and `benchViewMatrix` take `_ camera: BenchCameraState = .threeQuarter`.
  - **The four existing tests in `BenchCameraTests` are unedited except for
    `testTheFramingConstantsFitTheWholeRough`**, and all four pass. `git diff` on that file shows
    additions and the framing test's widened loops, and no other change to an existing assertion.
  - `benchViewMatrix(.faceUp)` and `benchViewMatrix(.faceDown)` contain no NaN, the basis is continuous
    through the pole per §12, and the new assertions in §12 for `orbit`, the pole bases, `benchRay` and
    `benchScreenPoint` all pass.
  - The widened framing test covers the five elevations, four azimuths and two aspects in §12, plus the
    32 points on the ring circle. If it fails, `BenchCamera.distance` rose in 0.5 steps until it passed
    and that is recorded as a material alteration.
- **Do not:** add zoom, pan, a `distance` or `fieldOfViewDegrees` parameter, or a `target` parameter.
  Do not touch `benchProjectionMatrix`'s body. Do not keep an up reference or a pole threshold constant
  — `xAxis` is the azimuth-only closed form at every elevation, with no branch (D3). Do not touch any
  app file — no `BenchRenderer`, no
  `MetalViewport`, no `BenchWindow`. **Do not create `IndexRing.swift`** — that is T6. The framing test
  writes the ring circle's radius and height as the literals `1.6` and `0.0`, with a one-line comment
  saying T6 replaces them with `IndexRing.radius` and `IndexRing.z`.


```
2-cutting-bench-app-shell-3 T1: make the camera a value

- BenchCameraState carries azimuth and elevation; the matrix functions take it,
  defaulted to the three-quarter view so the existing tests are untouched
- the look-at drops its up reference for the azimuth-only closed form the cross
  product already produced, which stays defined at the poles
- benchRay and benchScreenPoint added as the camera's inverse and forward
```

**T2 — Free orbit and the two snap views**

- **Files:** `CuttingBench/CuttingBench/MetalViewport.swift` (edit),
  `CuttingBench/CuttingBench/BenchRenderer.swift` (edit),
  `CuttingBench/CuttingBench/BenchRegions.swift` (edit),
  `CuttingBench/CuttingBench/BenchWindow.swift` (edit)
- **Done when:**
  - `BenchMetalView` handles `mouseDown`, `mouseDragged` and `mouseUp` per §8, with `onOrbit` wired and
    **`onPick` present but passed an empty closure from `BenchWindow`** — T5 fills it in.
  - `BenchRenderer` has a settable `camera` and `draw(in:)` builds its matrices from it.
  - `MetalViewport` forwards `camera`, `onOrbit` and `onPick`; `ViewportRegion` and `BenchWindow` thread
    them; the two snap buttons are in the toolbar before the inspector button.
  - The drag delta comes from successive `convert(event.locationInWindow, from: nil)` values, and
    `onOrbit` does not fire until the drag passes `clickSlopPoints`, so a click leaves the camera alone.
    **`NSEvent.deltaX` and `deltaY` appear nowhere in the diff.**
  - Owner confirms the handle below.
- **Do not:** add the opacity slider, the picking logic, the highlight, the ring, or `planeIndex` on
  `MeshVertex` — those are T3, T5 and T7. Do not add `opacity` or `highlightedPlaneIndex` to
  `BenchRenderer` yet. Do not touch `Shaders.metal`. Do not add scroll-wheel or magnify handling. Do
  not change `StatusStripRegion`.
- **Verification handle** — `permanent`:
  - **Where:** the viewport, and the two new toolbar buttons **Face Up** and **Face Down**. Open
    `Design/Patterns/Pattern-Standard-Round-Brilliant.json`, then set the `#if DEBUG` tier stepper in
    the status strip to **3** tiers, so rough walls and cut facets are both on screen.
  - **Positive:** drag downward across about half the viewport's height → the view tips toward looking
    down on the crown and the flat top facet grows: the stone follows the pointer (D4). Click **Face Up**
    → the outline is a symmetric polygon centred in the frame, seen straight down the axis, with none of
    the pavilion showing below it.
  - **Negative:** click **Face Down** → the culet is centred and the flat top facet is **not** visible.
    Then click **Face Up** twice in a row → the second click changes nothing at all, and **the stone is
    still drawn** — a NaN camera at the pole renders an empty background, so a stone still being there
    after a snap is the pole check (D3). Drag slowly down through the last degree before Face Up: the
    stone must **not** spin in place at any point on the way, which is the continuity half of D3.
    Dragging further down once already at Face Up also leaves the image unchanged: elevation clamps at 90
    rather than tipping past it.
  - **Reads:** `benchViewMatrix(_:)` and `BenchCameraState.orbit(dxPoints:dyPoints:)` in
    `BenchGeometry/BenchCamera.swift`, through `BenchRenderer.camera`.

```
2-cutting-bench-app-shell-3 T2: orbit the viewport, and snap face up and down

- drag in the viewport orbits the camera; azimuth wraps, elevation clamps at the
  poles
- the stone follows the pointer, so the camera moves the opposite way on both
  axes
- Face Up and Face Down land exactly on the axis, where the basis stays defined
- the drag delta comes from locationInWindow, not NSEvent.deltaY, whose sign
  convention would have to be guessed at
```

**T3 — The opacity control**

- **Files:** `CuttingBench/CuttingBench/Shaders.metal` (edit),
  `CuttingBench/CuttingBench/BenchRenderer.swift` (edit),
  `CuttingBench/CuttingBench/MetalViewport.swift` (edit),
  `CuttingBench/CuttingBench/BenchRegions.swift` (edit),
  `CuttingBench/CuttingBench/BenchWindow.swift` (edit)
- **Done when:**
  - Both `Uniforms` carry `highlightColor`, `eye` and `params` in the same order, and both still carry
    the comment saying they are field-for-field identical.
  - `fill_vertex` writes `out.facing` and multiplies the base alpha by `u.params.x`; `fill_fragment`
    discards on `in.facing * u.params.y < 0.0`.
  - The fill draws in two passes, far then near, with the three depth states in §7, and blending
    enabled on the shared descriptor. `encoder.setCullMode(.none)` is **still there**.
  - The edge pass selects its depth state on `opacity > BenchRenderer.opaqueAbove`.
  - `highlightColor` is populated from `NSColor.selectedContentBackgroundColor` even though nothing
    highlights yet — the field lands with the struct, and T5 sets the index that uses it.
  - The opacity slider is in the toolbar between the snap buttons and the inspector button.
  - Owner confirms the handle below.
- **Do not:** add `planeIndex` to `MeshVertex` or `attributes[3]` to the vertex descriptor — that is
  T5, and adding the attribute before the field exists will not compile. Do not set
  `highlightedPlaneIndex` from anything. Do not enable culling. Do not touch `edge_vertex`,
  `edge_fragment` or `kEdgeDepthEpsilon`. Do not sort facets on the CPU or rebuild the mesh in the draw
  path — part 2's D13 stands.
- **Verification handle** — `permanent`:
  - **Where:** the **Opacity** slider in the toolbar, with
    `Pattern-Standard-Round-Brilliant.json` open, all tiers, at **Face Up**.
  - **Positive:** at the slider's maximum the stone is opaque and only the crown facets are visible.
    Drag it to roughly the middle → the pavilion facets and their edges become visible **through** the
    crown, the crown facets still readable over them. Drag it to the minimum → the fill is gone
    entirely and a clean wireframe remains, every edge drawn at full strength.
  - **Negative:** drag the slider back to its maximum → **no pavilion edge is visible through the crown
    any more**, and no facet shows the window background through it. At the maximum the image is
    indistinguishable from what T2 left.
  - **Reads:** `params.x` and `fill_fragment`'s facing discard in `Shaders.metal`, and
    `BenchRenderer.opaqueAbove` selecting the edge pass's depth state.

```
2-cutting-bench-app-shell-3 T3: fade the solid, keeping the edges drawn

- one slider drives an opacity uniform; the fill draws far facets then near ones,
  selected by each facet's own plane facing rather than by a cull mode
- edges depth-test while the solid is opaque and stop when it is not, so a
  translucent stone shows its whole wireframe
```

**T4 — Pure: `pickFacet` and `facetLabel`**

No app change, no visible change. The slab test either names the right facet or it does not, and the
tests are what say which.

- **Files:** `CuttingBench/BenchGeometry/Sources/BenchGeometry/BenchPick.swift` (new),
  `CuttingBench/BenchGeometry/Tests/BenchGeometryTests/BenchPickTests.swift` (new)
- **Done when:**
  - `pickFacet` and `facetLabel` exist with the signatures in §2, and `pickFacet`'s body is the sequence
    in §2 including the parallel-ray early `nil` and the two `guard`s on `facets` and `origin`.
  - Every case listed for `BenchPickTests` in §12 passes.
  - `pickFacet` reads `solid.planes`, `solid.polytope.facets` and `solid.origin` and **nothing else** —
    in particular it never reads `polytope.vertices`.
  - The file declares its own `private func dot` for the tuple type and does not reach into the kernel's.
- **Do not:** touch any app file, `BenchSolid.swift`, `SolidMesh.swift` or `BenchCamera.swift`. Do not
  add a highlight, a selection type, or anything about screen coordinates — the ray arrives already
  built. Do not make anything in `FacetKernel` public and do not add `@testable import FacetKernel`.

**T5 — Click a facet, highlight it, name it**

- **Files:** `CuttingBench/BenchGeometry/Sources/BenchGeometry/SolidMesh.swift` (edit),
  `CuttingBench/BenchGeometry/Tests/BenchGeometryTests/SolidMeshTests.swift` (edit),
  `CuttingBench/CuttingBench/Shaders.metal` (edit),
  `CuttingBench/CuttingBench/BenchRenderer.swift` (edit),
  `CuttingBench/CuttingBench/MetalViewport.swift` (edit),
  `CuttingBench/CuttingBench/BenchRegions.swift` (edit),
  `CuttingBench/CuttingBench/BenchWindow.swift` (edit)
- **Done when:**
  - `MeshVertex` carries `planeIndex`, stride is 32 and offsets are 0, 12, 24, 28, with
    `SolidMeshTests` renamed and updated to match and its two new assertions passing.
  - `VertexIn` has `attribute(3)`, the vertex descriptor has `attributes[3]`, and `fill_vertex`
    substitutes `u.highlightColor` when `abs(in.planeIndex - u.params.z) < 0.5`.
  - `BenchRenderer.highlightedPlaneIndex` feeds `params.z`, `-1` when it is `nil`.
  - `BenchWindow.pick(at:in:)` is wired to `onPick` and sets both `@State` optionals; a miss clears
    them, and so does `rebuild()`. **There is no y flip in it** — `ndcY` is `2 * point.y / size.height - 1`.
  - `StatusStripRegion` shows the label at its trailing end, outside `#if DEBUG`, with the findings
    line still leading.
  - Owner confirms the handle below.
- **Do not:** add edge selection, multi-facet selection, or anything that writes to the pattern — this
  reads and reports only. Do not move or reword the strip's leading `Text("No findings")`. Do not put
  the readout behind `#if DEBUG`. Do not add the ring.
- **Verification handle** — `permanent`:
  - **Where:** the trailing end of the status strip, which reads `No facet selected` at launch, plus the
    fill colour in the viewport. Open `Pattern-Standard-Round-Brilliant.json`.
  - **Positive:** at all tiers and the default three-quarter view, click the large flat facet at the top
    of the stone → the strip reads `Facet <tier> · <index>` naming the table tier, and **that facet alone
    changes to the selection colour**. Now set the tier stepper to **3** and click a vertical rough wall
    → the strip reads `Facet G<n>` with `n` in 1…16, and that wall alone highlights.
  - **Negative:** click the background well clear of the stone → the strip returns to
    `No facet selected` and **no facet is highlighted**. Then click the **bottom** of the stone: it must
    read `P` or a pavilion tier, and must **never** read `C` or the table tier — a y-flip in the
    unprojection is exactly what that catches (D13). Finally, with a facet picked, step the tier
    stepper down one → the strip reads `No facet selected` and nothing is highlighted, rather than the
    highlight moving to some other facet.
  - **Reads:** `pickFacet` and `facetLabel` in `BenchGeometry/BenchPick.swift`, and
    `BenchRenderer.highlightedPlaneIndex` reaching `params.z` in `Shaders.metal`.

```
2-cutting-bench-app-shell-3 T5: name and highlight the facet under the pointer

- a click unprojects to a world ray, the slab test names the facet it enters, and
  the status strip reads that name
- MeshVertex carries its plane index so the shader can tint the one facet picked
- a click that misses the solid clears the selection, and so does a rebuild: a
  plane index means nothing once the solid is rebuilt
```

**T6 — Pure: the index ring's labels and its fade**

- **Files:** `CuttingBench/BenchGeometry/Sources/BenchGeometry/IndexRing.swift` (new),
  `CuttingBench/BenchGeometry/Sources/BenchGeometry/BenchSolid.swift` (edit),
  `CuttingBench/BenchGeometry/Tests/BenchGeometryTests/IndexRingTests.swift` (new),
  `CuttingBench/BenchGeometry/Tests/BenchGeometryTests/BenchCameraTests.swift` (edit — the two literals
  only)
- **Done when:**
  - `BenchSolid` carries `tiers: [SolvedTier]`, its `init` takes it last with the default `[]`, and
    `benchSolid(for:tierLimit:)` fills it from `partial.solution.tiers`. **`BenchSolidTests` compiles
    and passes unedited.**
  - `IndexRing`, `IndexRingLabel` (`Identifiable`, `Equatable`, `Sendable`), `indexRingLabels` and
    `indexRingAlpha` exist per §3, and every case listed for `IndexRingTests` in §12 passes.
  - The single-versus-multi-wheel text style is decided once, after the dedupe, from
    `Set(labels.map(\.wheel)).count == 1`, and applies to every label uniformly.
  - `BenchCameraTests`' framing test now reads `IndexRing.radius` and `IndexRing.z` in place of T1's
    `1.6` and `0.0` literals, and T1's placeholder comment is gone.

- **Do not:** touch any app file, `SolidMesh.swift`, `BenchPick.swift` or the shaders. Do not read
  `Pattern.tiers` — the labels come from the **solved** tiers (D17). Do not add occlusion, per-label
  alpha, or screen-space collision handling.

**T7 — The index ring over the viewport**

- **Files:** `CuttingBench/CuttingBench/IndexRingOverlay.swift` (new),
  `CuttingBench/CuttingBench/BenchRegions.swift` (edit),
  `CuttingBench/CuttingBench/BenchWindow.swift` (edit)
- **Done when:**
  - `IndexRingOverlay` exists per §9, including `.allowsHitTesting(false)` and
    `.opacity(indexRingAlpha(camera))`.
  - `ViewportRegion` hosts it as an `.overlay` and takes `ringLabels`; its doc comment now names the
    Metal subview **and** the ring overlay, per §10.
  - `BenchWindow` passes `ringLabels: indexRingLabels(store.solid)`.
  - Owner confirms the handle below, and `IndexRing.fadeDegrees` is whatever value the owner settled on
    at that stop.
- **Do not:** draw text in Metal, add a glyph atlas, or add a second projection path — the overlay uses
  `benchScreenPoint` and nothing else. Do not draw a ring when there is no pattern; that must fall out
  of the labels being empty, not out of a special case. Do not add tick marks, a ring outline, or labels
  at stops the pattern does not use.
- **Verification handle** — `permanent`:
  - **Where:** the numbers around the stone's rim in the viewport. Open
    `Pattern-Standard-Round-Brilliant.json`, all tiers, then click **Face Up**.
  - **Positive:** numbers appear in a ring outside the stone — 32 of them for this pattern, including
    `0`, `3`, `6` and `12`, index `0` to the right of centre and rising counter-clockwise. Drag down
    toward edge-on → they fade smoothly and are **gone** by the time the rim is a line, then come back
    on the way up.
  - **Negative:** with **no pattern open** (File ▸ New) there are **no numbers at any camera angle**,
    including Face Up. And at Face Up, click directly on one of the numbers → the status strip names
    **the facet underneath it**, not `No facet selected`: the overlay must not intercept the click.
  - **Reads:** `indexRingLabels` and `indexRingAlpha` in `BenchGeometry/IndexRing.swift`, and
    `benchScreenPoint` in `BenchGeometry/BenchCamera.swift`.

```
2-cutting-bench-app-shell-3 T7: ring the rim with the index stops in use

- a SwiftUI overlay places one number per distinct wheel-and-index the solved
  tiers use, projected through the renderer's own matrices
- the ring fades to nothing as the camera reaches edge-on, where the rim would
  project to a line
- no pattern means no solved tiers and so no ring, with no special case
```

**T8 — Close out**

- **No temporary handles to delete.** Every handle in this plan is `permanent`. The `#if DEBUG`
  tier-limit stepper in `StatusStripRegion` is **part 2's** and a later slice's scrubber supersedes it —
  it stays.
- Confirm each item in this plan's **Deferred** section has a ticket in `Design/Tickets/` with
  `Status: untriaged`. The executor filed each as it found it, per the protocol; this is the check.
- Report the untriaged ticket count in `Design/Tickets/` as one line. (It was **0** of four tickets when
  this plan was written — all four `Chore-` items are triaged.)
- `commit + push` with the message below.
- **Archive per the routine in `Design/Execution-Protocol.md` §11.** This is the last part, so it
  archives the whole set, each by name: this plan
  `2-Cutting-Bench-App-Shell-3-Camera-And-Facet-Naming`, its siblings
  `2-Cutting-Bench-App-Shell-1-Window-And-Document` and
  `2-Cutting-Bench-App-Shell-2-Rough-In-The-Viewport`, and the exploration
  `2-Cutting-Bench-App-Shell`. **No tickets** — this plan closes none, because the exploration folded
  none in.
- The routine's banner question is asked of each of the four documents individually: part 2's `Parts`
  section is superseded by this part's copy, which is a normal handover between parts and **not** a
  contradiction with shipped code. Judge each on the routine's own terms; do not assume the answer is
  `no` for all four.
- Do **not** archive `Design/Explorations/CB UI.png`, the four sibling explorations
  (`1-Cutting-Bench-Kernel-Changes`, `3-Cutting-Bench-Pattern-Display`, `4-Cutting-Bench-Authoring`,
  `5-Cutting-Bench-Angle-Tuning`), or anything in `Design/Prototypes/`.

```
2-cutting-bench-app-shell-3 T8: close out the cutting bench app shell

- the shell is done: a document app with an orbitable Metal viewport, the rough
  intersected with the pattern, a fadeable solid, named facets and the index ring
- archives all three parts and the exploration 2-Cutting-Bench-App-Shell
```

## Deferred

Empty at authoring. The executor appends adjacent problems it found and must not fix — and files each as
a ticket in `Design/Tickets/` immediately with `Status: untriaged`, per the protocol.
