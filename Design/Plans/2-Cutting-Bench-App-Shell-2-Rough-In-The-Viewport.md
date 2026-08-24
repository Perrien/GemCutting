# 2 · Cutting Bench App Shell — 2 · Rough In The Viewport

Status: **COMPLETED 2026-08-24**

## Parts

**For the owner and the next authoring session — not for the executor.** Nothing in this part's tasks
refers to another part.

1. `2-Cutting-Bench-App-Shell-1-Window-And-Document` — the app exists, opens a pattern file through
   the Open dialog, and shows the five layout regions present and empty. (shipped 2026-08-24)
2. `2-Cutting-Bench-App-Shell-2-Rough-In-The-Viewport` — the rough prism intersected with the
   pattern's own planes, drawn in Metal with flat per-facet fill and always-drawn edges, on a fixed
   three-quarter camera. ← this part
3. `2-Cutting-Bench-App-Shell-3-Camera-And-Facet-Naming` — free orbit, face-up and face-down snaps,
   the opacity control, click-a-facet-get-its-name, and the index-stop ring with its fade. Closes the
   exploration out and runs the archive routine.

| Exploration ID | Part |
|---|---|
| S1 | 1 |
| S2 | 2 |
| S3 | 2 |
| I1 | 2 — its planning consequences (owner-run `project.pbxproj`, deployment target) bound part 1 and are restated here |
| I2 | 2 |
| I3 | 2 — consumed by part 3's picking |
| I4 | 2 |
| I5 | 1 |
| U1 | 1 |
| U2 | 1 — restated here and in part 3, which must not introduce a bespoke palette |
| U3 | 3 |
| U4 | 3 |

**No boundary moved.** One thing part 1's copy did not anticipate: this part adds a local SwiftPM
package, `CuttingBench/BenchGeometry/`, because the pure geometry needs a test home and the app target
has none (D3 below). That is additive and changes no part's scope.

Ticket closure and the archive routine run once, in part 3.

## Context

Part 1 delivered a window with five empty regions. The owner can open a pattern and read its name off
a debug strip, and that is all — the viewport is a grey rectangle with the word `Viewport` in it. This
part puts a stone in it: the rough prism, cut by whatever tiers of the open pattern have been placed,
flat-shaded with its edges drawn, seen from one fixed three-quarter angle.

**Every kernel call this needs is already public and needs no change.**

- `Kernel/Sources/FacetKernel/Geometry/Polytope.swift:47`
  (`public func intersectHalfSpaces(_ planes: [Plane], tolerance: Double = 1e-7) -> Polytope`) is the
  whole of the solid-building work, and
  `Kernel/Sources/FacetKernel/Geometry/Polytope.swift:11` (`public var facets: [Int: [Int]]`) hands
  back one polygon per plane, its vertex indices already wound counter-clockwise about the plane
  normal — so nothing here has to wind, order or triangulate from scratch.
- `Kernel/Sources/FacetKernel/Solver.swift:156` (`public func solveAsFarAsPossible(`) returns a
  `PartialSolution`, and `Solver.swift:113` (`public struct PartialSolution: Sendable`) documents
  exactly why it exists: *"A half-solving pattern is the normal state of authoring rather than an edge
  case."*
- `Kernel/Sources/FacetKernel/Solver.swift:29`
  (`public var planeOwner: [Int: (tier: String, index: Int)]`) says which facet each of the pattern's
  planes belongs to — the model this part copies for the rough's own eighteen.
- `Kernel/Sources/FacetKernel/Geometry/Plane.swift:4` (`public struct Plane: Equatable, Sendable`)
  with `public var n` and `public var d`, and the half-space convention stated on
  `Plane.swift:3`: *"The solid is every point `p` satisfying `n · p <= d`."*
- `Kernel/Sources/FacetKernel/Pattern.swift:97` (`public var tiers: [TierSpec]`) is a `var` on a
  `struct`, which is what makes the tier-limit diagnostic in T2 a two-line change.

**What part 1 left to build on.** `CuttingBench/CuttingBench/BenchRegions.swift:7`
(`struct ViewportRegion: View`) is one `Color` with one label and carries the comment
*"**One replaceable subview** (D2): part 2 swaps this body for an `NSViewRepresentable`-wrapped
`MTKView`"*. That is this part. It is reached from
`CuttingBench/CuttingBench/BenchWindow.swift:16` (`ViewportRegion()`), which takes no arguments today.
The debug readout this part extends is `BenchRegions.swift:108`
(`private var documentSummary: String`), inside `StatusStripRegion`.

**The project is set up so no task here needs Xcode, except one.**
`CuttingBench/CuttingBench.xcodeproj/project.pbxproj:29` (`isa = PBXFileSystemSynchronizedRootGroup;`)
with `path = CuttingBench` means the target's sources *are* the contents of
`CuttingBench/CuttingBench/`, so adding a `.swift` file needs no project edit. Adding a **package
dependency** does, and that is T1's owner step. The project also already carries Metal build settings
— `project.pbxproj:206` (`MTL_FAST_MATH = YES;`) — from Xcode's own App template.

**Two facts about the app target, so nothing is fought that needn't be.**
`project.pbxproj:300` (`SWIFT_VERSION = 5.0;`) — the app compiles in Swift 5 language mode, so strict
concurrency checking is off; do not add `@preconcurrency`, `nonisolated` or `Sendable` conformances to
quiet warnings that will not appear. And `project.pbxproj:279` (`ENABLE_APP_SANDBOX = YES;`) — the
sandbox is on and generated from build settings, with no entitlements file in the source tree. Nothing
in this part goes near either.

So this is a self-contained lump of new geometry code with tests, plus a Metal renderer, against a
kernel that already does the hard part.

## Decisions (2026-08-24)

**These D-numbers are this part's own.** Part 1's numbering is not referenced here; everything the
executor needs is in this table.

| # | Decision |
|---|---|
| D1 | **The app builds what it draws by calling `intersectHalfSpaces` itself, and the kernel learns nothing about rough at all.** The rough planes are appended to the pattern's own solved planes and the whole list is intersected in the app. The kernel's `Solution.polytope` stays rough-free, which is what keeps it honest: `design-authoring-format.md:466` (`**The solid has to close.** A design that doesn't bound a solid is an error.`) is enforced by requiring every edge to belong to exactly two facets, and a rough-capped solid *always* closes — feeding rough into the solve would make that check pass for every pattern including the ones it exists to catch. Facet count fails the same way, since `Kernel/Sources/FacetKernel/Metrics.swift:86` (`facetCount: solution.polytope.facets.count`) counts the kernel's own polytope directly. |
| D2 | **Also rejected: drawing the prism as its own separate solid with no intersection against the pattern.** It is cheaper, but nothing gets cut, so it shows a prism with a cone floating inside it rather than a stone with material removed — and part 3's facet picking would then be wrong everywhere a cut facet should have clipped a rough wall. |
| D3 | **The pure geometry lives in a new local SwiftPM package, `CuttingBench/BenchGeometry/`, library `BenchGeometry`, depending on `Kernel/`.** The app target has no test home: part 1 deliberately shipped without an Xcode test target, and a unit-test bundle for a Mac *app* target must launch the app as its test host, which cannot be relied on from a headless agent run. A package gets tested by `swift test --package-path …`, which is exactly how `Kernel/` is already tested and is proven in this repository. It lives under `CuttingBench/` because it is app code, not kernel code — and it sits *beside* the synchronized folder `CuttingBench/CuttingBench/`, never inside it, so its sources are never also compiled into the app target. |
| D4 | **The rough is a 16-sided prism on the axis, spanning radius 1.5 and `z` from −2.0 to +1.0**, and those three numbers are build constants with no UI and no preference. The radius has a hard floor at the outline's corner radius — below it the girdle planes never reach the walls, rough survives at the girdle, and the stone cannot reach its own size. For a round stone that floor is ≈ 1.09. But **nothing in the format says which axis carries the `size` row** — only that there is exactly one of them and that width follows from the meets, `design-authoring-format.md:191` (`There is **exactly one** `SIZE` row, even for elongated and rectangular outlines.`) — so a design normalised on its *short* axis puts its ends out at `L/W`; a barion at `L/W = 1.436` needs radius ≈ 1.45. A snug radius would be betting on a convention the format does not enforce. |
| D5 | **The depth clears both deep pavilions and the deepest *intermediate* axial point.** Barions run to `P/W = 0.608`, which on a short-axis normalisation puts the culet at −1.216. And intermediate points go deeper than final culets: `Novice Ash-er`'s three pavilion steps sit at 1.19175, 1.07438 and 1.00717 (`design-authoring-format.md:169`), so its `P1` point forms at −1.19175 before `P2` and `P3` cut it back. Clipping either would misrepresent a real cutting sequence. Rejected: a snug preform-like prism at radius 1.15 spanning −1.15 to +0.6, which clips `Novice Ash-er` mid-authoring. Also rejected: auto-sizing, which buys nothing once tuning is excluded and makes named click targets move under the pointer. |
| D6 | **The prism never needs headroom for tuning**, because a tangent-ratio rescale only ever applies to a pattern that already closes, and a closed pattern's rough is dropped by a later slice's scaffolding rule. So the constants above are final, not provisional. |
| D7 | **Every rough facet carries a name at all times: `C` for the top cap, `P` for the bottom cap, `G1`…`G16` for the walls.** This is the reason the rough exists — a cut is always specifiable as index, angle and three named facets, with no moment where there is nothing to click. **`Gn`'s outward normal sits on stop `n − 1` of a 16-stop wheel**, θ = 2π(n−1)/16, matching the kernel's own convention at `Kernel/Sources/FacetKernel/Geometry/Plane.swift:31` (*"index 0 lies on the +x axis and the index advances counter-clockwise"*). So `G1` points along +x and `G5` along +y. |
| D8 | **Rough names and tier names can collide, and they are kept apart structurally rather than by renaming.** `Pattern-Easy-Octagon.json` has a tier literally named `G1`. In code a facet's origin is one enum with two cases — `.rough(RoughFacet)` and `.cut(FacetRef)` — so a rough `G1` and a tier named `G1` are never the same value. How part 3 renders the two in one readout is part 3's decision, not this one's. |
| D9 | **The rough planes come first in the plane list, at fixed indices 0…17: `C`, `P`, then `G1`…`G16`.** The pattern's plane at solved index `k` therefore lands at `18 + k`. Fixing the rough at the front means the rough plane indices and their names are the same for every pattern and for no pattern at all, which is what makes them testable and what part 3's picking can rely on. |
| D10 | **The walls are built as exact vertical planes, `n = (cos θ, sin θ, 0)`, not by calling `planeNormal(angleDegrees: 90, …)`.** That call returns `z = -cos(π/2)` = −6.1e-17 rather than 0, and the walls must be exactly vertical — a wall that is a hair off vertical is a wall whose edge-on fade and hit test in part 3 are a hair wrong. The θ convention is `planeNormal`'s, per D7. |
| D11 | **The solve is `solveAsFarAsPossible`, never `solve`, and its `failure` is ignored for drawing.** A half-authored pattern is the normal state, and throwing the whole solve away on a late-tier failure would blank the viewport for exactly the patterns this tool exists to author. The tiers that placed are drawn; the failure is not reported anywhere in this part, because the findings line belongs to a later slice. |
| D12 | **No `girdleTargetFraction` argument is passed**, so `solveAsFarAsPossible` uses the pattern's own declared target — which, per `Kernel/Sources/FacetKernel/Solver.swift:142` (*"a pattern opened with no argument reproduces its own diagram"*), is what makes a pattern reproduce its own diagram. Passing anything else would draw a stone the pattern does not describe. |
| D13 | **The solid and its mesh are built once per (pattern, tier-limit) change and never in a draw call.** `intersectHalfSpaces` is O(n³) over plane triples; the round brilliant has 73 facets, so with the rough that is 91 planes and ~121,000 triples. That is fine once when a document opens and ruinous at 60 Hz. The `MTKView` is therefore configured `isPaused = true` with `enableSetNeedsDisplay = true` and redrawn on demand: nothing in this part animates. |
| D14 | **One solid, built in one place, read by both the viewport and the debug readout.** A `BenchSolidStore` owned by `BenchWindow` holds it; the readout displays counts taken off that same value. A readout that recomputed the counts independently would be a second implementation, and it could agree with a broken one. |
| D15 | **Metal directly, in an `MTKView` wrapped by `NSViewRepresentable`.** Three of this design's requirements are shading requirements — flat per-facet fill so every facet reads as its own plane and is a credible click target, edges that stay drawn while the fill later fades to wireframe, and uncut rough visually distinct from cut facets — and a later slice draws a ray path *inside* a semi-transparent solid, which is a depth-sorting problem worth controlling. Rejected: SceneKit, whose real saving is camera orbit and hit-testing (the easy parts) while flat per-facet shading plus always-drawn edges plus partial opacity land in the awkward corner of its material model, and which is in maintenance rather than active development. Also rejected: RealityKit, built around AR scene semantics and heavier than a Mac window needs. |
| D16 | **The shader is a real `Shaders.metal` file in the target, compiled by the build — not a string compiled at runtime with `makeLibrary(source:)`.** A runtime-compiled shader turns a typo into a launch-time crash that the build gate cannot see; a compiled file turns it into a build failure, which is what the executor checks against. T4 carries the one bounded fallback if the synchronized folder does not pick the file up. |
| D17 | **Flat per-facet fill means one constant tone per facet, from a fixed view-space headlight on the facet's own plane normal** — `shade = 0.25 + 0.75 · max(0, n · L)` with `L` fixed in view space. Not raw unlit colour: a solid where every cut facet is the same flat tone reads as a silhouette, and the whole point is that each facet reads as its own plane. The normal is the plane's own outward normal from `Plane.n`, never a normal computed from the triangle, so the tone is exact per facet and free. |
| D18 | **Nothing is culled: `setCullMode(.none)`.** The bench solid is always closed — the rough bounds it in every direction whatever the pattern does — so with depth testing, culling is a pure optimisation worth nothing at 60 triangles, and skipping it removes the front-facing-winding question entirely. Metal's window coordinates are y-down, which inverts the apparent winding of an outward-wound polygon; getting that wrong renders the stone inside-out. Do not "optimise" this back to `.back`. |
| D19 | **Edges win the depth test by a fixed clip-space epsilon applied in their own vertex function** — `position.z -= 2e-4 * position.w` — not by `setDepthBias`, whose sign and scale semantics vary by depth format. An edge lies exactly on the facet it bounds, so without this it z-fights. |
| D20 | **No up-front visual specification. The app is built to stock native macOS, and the look is adjusted in the running app at each owner stop.** The camera constants, the ambient/diffuse split and the colour roles are the tuning points, and they are named as such. **Colour is never load-bearing alone** anywhere in this app, so a plain palette costs correctness nothing. No bespoke palette, no type scale, no spacing scale, no mockups, no Settings pane, no colour picker. |
| D21 | **Four colour roles, all resolved from named system colours at runtime, through the view's `effectiveAppearance`:** cut facet `NSColor.controlAccentColor`, uncut rough `NSColor.systemGray`, edges `NSColor.labelColor`, viewport background `NSColor.underPageBackgroundColor`. Rough must read as *not yet cut* and grey is the system's neutral; the accent is the user's own highlight and is what the stone is made of. Resolving at draw time rather than baking sRGB values is what makes the solid track light and dark appearance with everything else. |
| D22 | **`project.pbxproj` is owner-run.** `Design/Execution-Protocol.md:87` treats hand-editing it as a corruption risk producing unreviewable diffs, and forbids touching signing, capabilities, entitlements or the bundle identifier. **The Xcode step in T1 is therefore the owner's**, and the agent writes no file inside `CuttingBench.xcodeproj` in any task of this plan. If a task appears to need an entitlement or a signing change, it stops. |
| D23 | **No pattern geometry beyond the solid itself.** No camera control, no orbit, no snap views, no opacity, no facet picking, no index-stop ring, no tier table contents, no findings, no scrubber behaviour — all of those belong to later slices, and the *Explicitly not doing* section names each with what rules it out here. |
| D24 | **No yield or rough-retention readout, and no volume code.** Rough retention is the game's number, not this tool's: what this tool could compute is a property of the pattern — the best it could ever do in a fixed rough — while the game's payout needs what the cutter actually achieved, which takes a target size and an achieved girdle placement, both per-job state this tool has no concept of. The second is not a retrofit of the first, so building the first here would produce a number that looks like the game's and isn't. **Nothing is at risk in deferring it**: what the game will eventually need is the volume of a polytope, whose inputs are already in `Polytope.vertices` and `Polytope.facets`. |

## Tickets closed by this plan

None — closed in the final part.

The three tickets standing in `Design/Tickets/` today — `Chore-Incremental-Half-Space-Clipper`,
`Chore-Stale-Links-In-The-Format-Document` and `Chore-Validation-Rebuilds-The-Solid-Once-Per-Tier` —
are none of them this plan's, and the exploration folded in no ticket at all. In particular
`Chore-Incremental-Half-Space-Clipper` is adjacent to D13 and is **not** to be picked up here: this
part calls `intersectHalfSpaces` as it stands.

## Prefactoring

**None needed, because part 1 already left the seam.**
`CuttingBench/CuttingBench/BenchRegions.swift:7` (`struct ViewportRegion: View`) is one replaceable
subview by construction and by comment, and the only edit to it is the replacement this part exists to
make — a behaviour change, not a prefactor. Everything else this part adds is new: a new package, four
new source files in it, and three new files in the app target. Nothing under `Kernel/` is touched, so
there is no existing behaviour to preserve and no characterization test to write.

## Approach

A new SwiftPM package holds four pure modules — the rough prism, the bench solid, the mesh, the camera
— each with a table-style test file, exactly as `Kernel/Sources/FacetKernel/Geometry/Polytope.swift`
and `Kernel/Tests/FacetKernelTests/PolytopeTests.swift` do it (XCTest, hand-built plane lists, a
`private let tol = 1e-9`). The app target then gains three files: a Metal shader, a renderer, and the
`NSViewRepresentable` that hosts the `MTKView`. `BenchWindow` gains the store that owns the solid, and
`BenchRegions` gains the counts readout and loses its placeholder viewport.

Every path below is relative to the repository root.

### 1. New package: `CuttingBench/BenchGeometry/Package.swift`

Mirrors `Kernel/Package.swift` — same tools version, same platform, same two-space style.

```swift
// swift-tools-version:6.0
import PackageDescription

let package = Package(
  name: "BenchGeometry",
  platforms: [.macOS(.v15)],
  products: [
    .library(name: "BenchGeometry", targets: ["BenchGeometry"])
  ],
  dependencies: [
    .package(path: "../../Kernel")
  ],
  targets: [
    .target(name: "BenchGeometry", dependencies: [.product(name: "FacetKernel", package: "FacetKernel")]),
    .testTarget(name: "BenchGeometryTests", dependencies: ["BenchGeometry"]),
  ]
)
```

The package *name* declared in `Kernel/Package.swift` is `FacetKernel`, not `Kernel`, which is why the
`package:` label reads `FacetKernel` while the path reads `../../Kernel`.

### 2. New: `Sources/BenchGeometry/RoughPrism.swift` (pure — no framework, no I/O)

The eighteen planes, their names, and the three constants (D4, D5, D7, D9, D10).

```swift
import FacetKernel

/// The rough stone's dimensions. Build constants with no UI and no preference (D4, D5, D6).
public enum Rough {
  public static let radius = 1.5
  public static let zTop = 1.0
  public static let zBottom = -2.0
  public static let wallCount = 16
}

/// One named surface of the rough. `wall`'s argument is the 16-stop index the wall's normal sits on,
/// 0 through 15, so `wall(0)` is named `G1` and points along +x (D7).
public enum RoughFacet: Equatable, Hashable, Sendable {
  case crownCap
  case pavilionCap
  case wall(Int)

  public var name: String {
    switch self {
    case .crownCap: "C"
    case .pavilionCap: "P"
    case .wall(let stop): "G\(stop + 1)"
    }
  }
}

/// The rough's eighteen half-spaces, in the fixed order `C`, `P`, `G1`…`G16` (D9). Index into this and
/// into `roughFacets` with the same integer.
public func roughPlanes() -> [Plane]

/// The name of each plane `roughPlanes()` returns, in the same order.
public func roughFacets() -> [RoughFacet]
```

`roughPlanes()` builds, in this order: `Plane(n: (0, 0, 1), d: Rough.zTop)`,
`Plane(n: (0, 0, -1), d: -Rough.zBottom)`, then for `stop` in `0..<Rough.wallCount`, with
`theta = 2 * .pi * Double(stop) / Double(Rough.wallCount)`,
`Plane(n: (cos(theta), sin(theta), 0), d: Rough.radius)`. The `z` components of the wall normals are
the literal `0`, per D10.

### 3. New: `Sources/BenchGeometry/BenchSolid.swift` (pure)

The intersection, and the plane-to-name map (D1, D9, D11, D12).

```swift
import FacetKernel

/// What a plane of the drawn solid belongs to. Two cases, so a rough wall named `G1` and a tier named
/// `G1` are never the same value (D8).
public enum FacetOrigin: Equatable, Sendable {
  case rough(RoughFacet)
  case cut(FacetRef)
}

/// The solid the viewport draws: the rough intersected with whatever tiers have been placed.
public struct BenchSolid: Sendable {
  /// Rough planes at indices 0…17, then the pattern's solved planes from 18 up (D9).
  public var planes: [Plane]
  /// An entry for every index in `planes`.
  public var origin: [Int: FacetOrigin]
  public var polytope: Polytope

  /// The plane indices that survived as facets, split by origin. Both read `polytope.facets.keys`, so
  /// neither can disagree with what is drawn.
  public var roughFacetIndices: [Int] { get }
  public var cutFacetIndices: [Int] { get }
}

/// Builds the solid. `pattern` is `nil` for a new document — then the result is the bare prism.
///
/// `tierLimit` is the diagnostic in T2: `nil` means every tier, `n` means only the first `n`. Truncating
/// is safe because a meet may only name an earlier tier — a forward reference is
/// `SolverError.forwardReference`, never something the solver resolves — so the first `n` tiers solve to
/// exactly the depths they have in the whole pattern.
public func benchSolid(for pattern: Pattern?, tierLimit: Int? = nil) -> BenchSolid
```

The body, in order:

1. `var planes = roughPlanes()`, and `origin` seeded from `roughFacets()` as
   `.rough` at indices 0…17.
2. If `pattern` is `nil`, intersect and return. Otherwise take
   `var truncated = pattern`, and when `tierLimit` is non-`nil` set
   `truncated.tiers = Array(pattern.tiers.prefix(limit))`.
3. `let partial = solveAsFarAsPossible(truncated)` — no `girdleTargetFraction` argument (D12), and
   `partial.failure` is discarded (D11).
4. For each `(k, plane)` in `partial.solution.planes.enumerated()`: append the plane, and if
   `partial.solution.planeOwner[k]` is non-`nil`, set
   `origin[18 + k] = .cut(FacetRef(tier: owner.tier, index: owner.index))`. A plane with no owner is
   impossible today; if one appears, leave it out of `origin` rather than inventing a name — an
   unnamed plane shows up as a missing entry, which a test can see.
5. `let polytope = intersectHalfSpaces(planes)` — the default tolerance, unchanged.

### 4. New: `Sources/BenchGeometry/SolidMesh.swift` (pure)

Triangles and edges, in the exact layout the vertex descriptor reads (D17, D19).

```swift
import FacetKernel
import simd

/// One mesh vertex. **Seven `Float`s, no padding: stride 28, offsets 0, 12 and 24.** The vertex
/// descriptor in the renderer reads those three numbers, and `SolidMeshTests` pins them.
public struct MeshVertex: Equatable, Sendable {
  public var px: Float
  public var py: Float
  public var pz: Float
  public var nx: Float
  public var ny: Float
  public var nz: Float
  /// 0 for a cut facet, 1 for uncut rough. The shader mixes the two colours by it (D21).
  public var role: Float
}

public struct SolidMesh: Sendable {
  /// Three per triangle, fan-triangulated from each facet's polygon.
  public var triangleVertices: [MeshVertex]
  /// Two per segment. `nx`/`ny`/`nz` and `role` are zero and unread — the edge shader uses position
  /// only, and one vertex layout serving both pipelines is worth four unused bytes.
  public var edgeVertices: [MeshVertex]
}

public func solidMesh(_ solid: BenchSolid) -> SolidMesh
```

The body walks `solid.polytope.facets` in ascending plane-index order, so the output is deterministic:

- **Triangles.** For a facet with vertex indices `v` (already wound counter-clockwise about the plane
  normal — `Polytope.swift:7`), emit `v.count - 2` triangles fanned from `v[0]`: `(v[0], v[i], v[i+1])`
  for `i` in `1..<v.count - 1`. Every vertex of the facet carries the **plane's own outward normal**,
  `solid.planes[planeIndex].n`, normalized, never a normal computed from the triangle (D17). `role` is
  `1` when `solid.origin[planeIndex]` is `.rough`, else `0`.
- **Edges.** Each undirected pair of consecutive vertex indices around each facet polygon, including
  the closing pair `(v.last!, v[0])`, keyed as `(min, max)` in a `Set<SIMD2<Int>>` so the pair shared
  by two facets is emitted once.

### 5. New: `Sources/BenchGeometry/BenchCamera.swift` (pure)

The one fixed three-quarter view, and the two matrices. **These five constants are the tuning point at
T4's owner stop** (D20) — nothing else in the render is adjusted by eye.

```swift
import simd

public enum BenchCamera {
  public static let azimuthDegrees: Float = 45
  public static let elevationDegrees: Float = 25
  public static let distance: Float = 9
  public static let fieldOfViewDegrees: Float = 30
  /// The centre of the rough, not the centre of a stone: the rough is what has to fit the frame.
  public static let target = SIMD3<Float>(0, 0, -0.5)
  public static let near: Float = 0.1
  public static let far: Float = 100
}

/// Where the camera sits, in world space.
public func benchCameraPosition() -> SIMD3<Float>

/// Right-handed look-at, world +z up. The stone's axis is +z, and the elevation keeps `up` clear of it.
public func benchViewMatrix() -> simd_float4x4

/// Perspective, Metal's NDC: z in [0, 1], y up.
public func benchProjectionMatrix(aspect: Float) -> simd_float4x4
```

Write them out, so nothing is derived at execution time. With
`az = azimuthDegrees * .pi / 180` and `el = elevationDegrees * .pi / 180`:

- `benchCameraPosition()` = `target + distance * SIMD3(cos(el) * cos(az), cos(el) * sin(az), sin(el))`.
- `benchViewMatrix()`: `let eye = benchCameraPosition()`, `let zAxis = normalize(eye - target)`,
  `let xAxis = normalize(cross(SIMD3<Float>(0, 0, 1), zAxis))`, `let yAxis = cross(zAxis, xAxis)`, then
  the columns
  `(xAxis.x, yAxis.x, zAxis.x, 0)`, `(xAxis.y, yAxis.y, zAxis.y, 0)`, `(xAxis.z, yAxis.z, zAxis.z, 0)`,
  `(-dot(xAxis, eye), -dot(yAxis, eye), -dot(zAxis, eye), 1)`.
- `benchProjectionMatrix(aspect:)`: `let f = 1 / tan(fieldOfViewDegrees * .pi / 360)`,
  `let a = far / (near - far)`, `let b = far * near / (near - far)`, then the columns
  `(f / aspect, 0, 0, 0)`, `(0, f, 0, 0)`, `(0, 0, a, -1)`, `(0, 0, b, 0)`.

### 6. New: `CuttingBench/CuttingBench/Shaders.metal`

Two vertex functions and two fragment functions. `Uniforms` here and `Uniforms` in
`BenchRenderer.swift` must stay field-for-field identical; the Swift side is the one with the comment
saying so.

```metal
#include <metal_stdlib>
using namespace metal;

struct Uniforms {
  float4x4 viewProjection;
  float4x4 view;
  float4 cutColor;
  float4 roughColor;
  float4 edgeColor;
};

struct VertexIn {
  float3 position [[attribute(0)]];
  float3 normal   [[attribute(1)]];
  float  role     [[attribute(2)]];
};

struct FillOut {
  float4 position [[position]];
  float4 color;
};

// A headlight fixed in view space, so a facet's tone depends only on its own plane (D17). Written out
// rather than normalize()d here, because a `constant` initialiser must be constant-evaluable.
constant float3 kLight = float3(0.268328, 0.357771, 0.894427);
constant float kAmbient = 0.25;
constant float kDiffuse = 0.75;
// Pulls an edge toward the camera so it wins the depth test against the facet it lies on (D19).
constant float kEdgeDepthEpsilon = 2e-4;

vertex FillOut fill_vertex(VertexIn in [[stage_in]], constant Uniforms &u [[buffer(1)]]) {
  FillOut out;
  out.position = u.viewProjection * float4(in.position, 1.0);
  float3 n = normalize((u.view * float4(in.normal, 0.0)).xyz);
  float shade = kAmbient + kDiffuse * saturate(dot(n, kLight));
  float4 base = mix(u.cutColor, u.roughColor, in.role);
  out.color = float4(base.rgb * shade, base.a);
  return out;
}

fragment float4 fill_fragment(FillOut in [[stage_in]]) { return in.color; }

struct EdgeOut {
  float4 position [[position]];
};

vertex EdgeOut edge_vertex(VertexIn in [[stage_in]], constant Uniforms &u [[buffer(1)]]) {
  EdgeOut out;
  out.position = u.viewProjection * float4(in.position, 1.0);
  out.position.z -= kEdgeDepthEpsilon * out.position.w;
  return out;
}

fragment float4 edge_fragment(constant Uniforms &u [[buffer(1)]]) { return u.edgeColor; }
```

### 7. New: `CuttingBench/CuttingBench/BenchRenderer.swift`

The `MTKViewDelegate`. It owns the device, the two pipeline states, the depth state, the two vertex
buffers, and the colour resolution.

- `struct Uniforms` — `viewProjection: simd_float4x4`, `view: simd_float4x4`, then
  `cutColor`, `roughColor`, `edgeColor` as `SIMD4<Float>`, in that order, matching `Shaders.metal`.
- `init(view: MTKView)`:
  `guard let device = MTLCreateSystemDefaultDevice() else { fatalError(…) }` — a Mac that cannot run
  Metal cannot run macOS 26, so this is unreachable and does not get a UI fallback. Then
  `guard let library = device.makeDefaultLibrary() else { fatalError("Shaders.metal is not compiled into the CuttingBench target") }`
  — that message is the one the T4 fallback keys off.
- The vertex descriptor, written from `MemoryLayout` rather than by hand:
  attribute 0 `.float3` at offset 0, attribute 1 `.float3` at offset 12, attribute 2 `.float` at
  offset 24, all `bufferIndex = 0`, and `layouts[0].stride = MemoryLayout<MeshVertex>.stride`.
- Two `MTLRenderPipelineState`s off one descriptor, differing only in their functions:
  `fill_vertex`/`fill_fragment` and `edge_vertex`/`edge_fragment`. Both take
  `colorAttachments[0].pixelFormat = view.colorPixelFormat` and
  `depthAttachmentPixelFormat = view.depthStencilPixelFormat`.
- One `MTLDepthStencilState`: `depthCompareFunction = .less`, `isDepthWriteEnabled = true`, shared by
  both pipelines.
- `func setMesh(_ mesh: SolidMesh)` — makes the two `MTLBuffer`s with
  `device.makeBuffer(bytes:length:options:)` and stores the vertex counts. An empty array makes no
  buffer; the draw skips it.
- `func draw(in view: MTKView)` — resolves the colours from `view.effectiveAppearance` (below), sets
  `view.clearColor` from `NSColor.underPageBackgroundColor`, builds
  `uniforms.viewProjection = benchProjectionMatrix(aspect:) * benchViewMatrix()` with
  `aspect = Float(view.drawableSize.width / view.drawableSize.height)`, passes the struct with
  `setVertexBytes(…, index: 1)` and `setFragmentBytes(…, index: 1)`, sets
  `encoder.setCullMode(.none)` (D18) and the depth state, then draws the fill as `.triangle` and the
  edges as `.line`.
- Colour resolution, once per draw — three `NSColor`s is cheap and the view redraws only on demand:

  ```swift
  private func rgba(_ color: NSColor, in appearance: NSAppearance) -> SIMD4<Float> {
    var out = SIMD4<Float>(0, 0, 0, 1)
    appearance.performAsCurrentDrawingAppearance {
      if let resolved = color.usingColorSpace(.sRGB) {
        out = SIMD4(
          Float(resolved.redComponent), Float(resolved.greenComponent),
          Float(resolved.blueComponent), Float(resolved.alphaComponent))
      }
    }
    return out
  }
  ```

### 8. New: `CuttingBench/CuttingBench/MetalViewport.swift`

The bridge, plus the three-line `MTKView` subclass that makes appearance changes redraw.

```swift
/// `MTKView` does not redraw on an appearance change by itself, and every colour is resolved per draw
/// (D21), so without this the solid keeps yesterday's colours until something else invalidates it.
final class BenchMetalView: MTKView {
  override func viewDidChangeEffectiveAppearance() {
    super.viewDidChangeEffectiveAppearance()
    needsDisplay = true
  }
}

struct MetalViewport: NSViewRepresentable {
  let mesh: SolidMesh
  /// Bumped by the store on every rebuild. Comparing this beats comparing two arrays of vertices.
  let generation: Int

  final class Coordinator {
    var renderer: BenchRenderer?
    var uploaded: Int?
  }
}
```

`makeNSView` builds a `BenchMetalView`, sets `device`, `colorPixelFormat = .bgra8Unorm`,
`depthStencilPixelFormat = .depth32Float`, `clearDepth = 1.0`, `enableSetNeedsDisplay = true` and
`isPaused = true` (D13), makes the renderer, assigns it as `delegate`, stores it on the coordinator,
and returns the view. `updateNSView` returns immediately when `coordinator.uploaded == generation`;
otherwise it calls `setMesh`, records the generation, and sets `needsDisplay = true`.

### 9. New: `CuttingBench/CuttingBench/BenchSolidStore.swift`

The one place the solid is built (D13, D14).

```swift
/// Owns the drawn solid. One build per (pattern, tier limit) change — never in a draw call (D13) — and
/// one value read by both the viewport and the debug readout (D14).
@Observable final class BenchSolidStore {
  private(set) var solid: BenchSolid
  private(set) var mesh: SolidMesh
  private(set) var generation = 0
  private var builtPattern: FacetKernel.Pattern??
  private var builtTierLimit: Int?

  init()
  func rebuildIfNeeded(pattern: FacetKernel.Pattern?, tierLimit: Int?)
}
```

`init()` builds for `nil`, so a window has a solid before its first layout. `rebuildIfNeeded` returns
early when `builtPattern` is `.some(pattern)` **and** `builtTierLimit == tierLimit`; otherwise it sets
`solid`, `mesh`, `generation += 1` and both stored keys. The double optional on `builtPattern` is what
distinguishes *never built* from *built for no pattern*.

### 10. `CuttingBench/CuttingBench/BenchWindow.swift` (edit)

Three changes to the existing file, whose current viewport line is `:16` (`ViewportRegion()`).

- Add `@State private var store = BenchSolidStore()`, and behind `#if DEBUG` a
  `@State private var tierLimit: Int?` starting at `nil`.
- Replace `ViewportRegion()` with `ViewportRegion(mesh: store.mesh, generation: store.generation)`,
  and `StatusStripRegion(pattern: document.pattern)` at `:25` with
  `StatusStripRegion(pattern: document.pattern, solid: store.solid, tierLimit: $tierLimit)` — with the
  binding argument, and only that argument, behind `#if DEBUG`.
- Drive the store from the `VStack`, not from `body`'s own evaluation, so nothing mutates observable
  state during a view update:
  `.onChange(of: document.pattern, initial: true) { store.rebuildIfNeeded(pattern: document.pattern, tierLimit: tierLimit) }`,
  plus the same call in a second `.onChange(of: tierLimit)` behind `#if DEBUG`.

Nothing else in the file moves: the `VSplitView`, the `.inspector`, the toolbar toggle and
`.navigationTitle` stay exactly as they are.

### 11. `CuttingBench/CuttingBench/BenchRegions.swift` (edit)

- **`ViewportRegion`** — its body becomes `MetalViewport(mesh: mesh, generation: generation)`. It gains
  `let mesh: SolidMesh` and `let generation: Int` and loses the `Color` and the `Text("Viewport")`. It
  is still one replaceable subview and nothing else may draw into it.
- **`StatusStripRegion`** — gains `let solid: BenchSolid` and, behind `#if DEBUG`,
  `@Binding var tierLimit: Int?`. `documentSummary` at `:108` gains the facet counts, and the debug
  half of the strip gains the stepper. Both are specified in T2.
- **`ScrubberRegion`, `TierTableRegion`, `TierRow`, `InspectorRegion`, `EmptyCard`** — untouched.

## Explicitly not doing

- **No camera control of any kind** — no orbit, no drag, no scroll-to-zoom, no face-up or face-down
  snap views, no keyboard nudge. One fixed three-quarter view, from the constants in `BenchCamera`
  (D23). A later slice owns the camera.
- **No opacity and no transparency.** The solid is opaque, `blendingEnabled` stays off, and there is no
  opacity slider. Semi-transparency exists for two reasons — checking pavilion against crown alignment,
  and making a traced ray visible inside the stone — and both belong to later slices (D23).
- **No facet picking, no hit test, no click handling, no hover, no highlight.** `MetalViewport` installs
  no gesture recognizer and no `NSResponder` override. The plane-to-name map this part builds is what
  part 3's picking consumes; building the map is not building the pick (D23).
- **No index-stop ring and no stop labels.** No text is drawn in the viewport at all (D23).
- **No tier table contents, no inspector contents, no scrubber behaviour, no findings count.** Those
  regions stay exactly as part 1 left them, and the status strip's leading text stays the unconditional
  `No findings` (D23).
- **No editing, no saving, no draft type, no mutation of `PatternDocument.pattern`.** The tier-limit
  diagnostic truncates a *copy* and never writes back.
- **No yield, no rough-retention readout, no volume function, no `size` slider** (D24).
- **No change to `Kernel/`.** Everything needed is already public. A task that seems to need a kernel
  change is a stop, and `git status --short Kernel` reporting anything is a failed *Done when*.
- **No touching `Chore-Incremental-Half-Space-Clipper`'s subject.** `intersectHalfSpaces` is called as
  it stands; no caching layer, no incremental clipper, no tolerance change from its 1e-7 default.
- **No edit to `project.pbxproj`, the entitlements, the signing settings or the bundle identifier by
  the agent** (D22). The one project change this part needs is T1's owner step.
- **No Xcode unit-test target.** The tests live in the new package (D3), and the app target keeps none.
- **No third-party dependencies** — Swift, the standard library and the system frameworks (`Metal`,
  `MetalKit`, `simd`, `AppKit`, `SwiftUI`) only, per the protocol's guardrail. `MetalKit` and `simd`
  auto-link; neither needs a project edit.
- **No bespoke palette, type scale or spacing scale, no Settings pane, no colour picker, no mockups**
  (D20).
- **No runtime shader compilation** (D16), and no second renderer, offscreen render target,
  screenshot path or image export.

## Tasks

| # | Task | Status | Then | Commit | Note |
|---|---|---|---|---|---|
| T1 | The `BenchGeometry` package with the rough prism, linked into the app — **owner step in Xcode** | completed | **owner stop** | commit | The agent writes no file inside `CuttingBench.xcodeproj`. **Material alteration:** `Package.swift` reads `.product(name: "FacetKernel", package: "Kernel")` — SwiftPM takes a path dependency's identity from its directory name, so the plan's `package: "FacetKernel"` does not resolve. |
| T2 | The bench solid: rough intersected with the pattern's placed tiers, named plane by plane | completed | **owner stop** | commit | **Material alteration:** `BenchSolidStore.swift` imports `struct FacetKernel.Pattern` rather than the whole module — `FacetKernel` exports a public enum `Observation`, which shadows the module `@Observable` expands its references against. **Material alteration:** Swift cannot put a single call argument behind `#if DEBUG`, so `BenchWindow` conditionalises the whole `StatusStripRegion(…)` call and routes both `.onChange` bodies through one `rebuild()` whose tier-limit argument is the conditional part. |
| T3 | The triangulated mesh, the edge list and the camera matrices | completed | checkpoint | — | |
| T4 | Metal draws the solid — flat per-facet fill, rough against cut, fixed three-quarter camera | completed | **owner stop** | commit | **Material alteration:** none to the code. Xcode 26.6 ships the Metal compiler as a separately downloaded component; the owner installed it with `xcodebuild -downloadComponent MetalToolchain`. The plan's synchronized-folder question is settled: `.metal` in `CuttingBench/CuttingBench/` is compiled with no Xcode step. |
| T5 | The edges, always drawn | completed | **owner stop** | commit | |
| T6 | Close out | awaiting owner | **owner stop** | commit + push | Archives nothing — part 3 does that |

**Gates, for every task in this plan.** The protocol's gates 1 and 2 are unconditional and will pass
untouched, because no task here adds Swift under `Kernel/`; gate 3 does not apply for the same reason.
**The protocol's gates therefore say nothing about whether the app builds or whether the new package's
tests pass**, so every task carries these four as *Done when* items in its own right:

- `swift test --package-path CuttingBench/BenchGeometry --disable-sandbox` — green. (From T1 on; the
  package does not exist before it.)
- `git status --short Kernel` — reports nothing. This part changes no kernel code.
- `xcodebuild -project CuttingBench/CuttingBench.xcodeproj -scheme CuttingBench -destination 'platform=macOS' build`
  — succeeds, no warnings in the `CuttingBench` target.
- `xcrun swift-format lint --recursive --strict CuttingBench/CuttingBench CuttingBench/BenchGeometry`
  — clean. Fix with
  `xcrun swift-format format --in-place --recursive CuttingBench/CuttingBench CuttingBench/BenchGeometry`,
  which matches `Kernel/`'s own two-space, hundred-column default. It visits `.swift` files only, so
  `Shaders.metal` is neither linted nor formatted — match the surrounding Swift style there by hand.

---

**T1 — The `BenchGeometry` package with the rough prism, linked into the app**

**This task is part agent, part owner.** The agent writes the package and the temporary readout and
runs the package tests, then presents the checklist below and waits; the owner links the package in
Xcode; the agent then runs the build and the handle. **The agent never edits any file inside
`CuttingBench.xcodeproj`** (D22).

It is first because it is the task that would invalidate every other one: if a local package cannot be
linked into this target, the whole shape in D3 is wrong and the plan has to change before any geometry
is written against it.

- **Files:** `CuttingBench/BenchGeometry/Package.swift` (new),
  `CuttingBench/BenchGeometry/Sources/BenchGeometry/RoughPrism.swift` (new),
  `CuttingBench/BenchGeometry/Tests/BenchGeometryTests/RoughPrismTests.swift` (new),
  `CuttingBench/CuttingBench/BenchRegions.swift` (edit — the temporary readout only)
- **Owner checklist, in order** — presented after the package's own tests are green:
  1. **File ▸ Add Package Dependencies… ▸ Add Local…** ▸ select `CuttingBench/BenchGeometry` ▸ add the
     library product `BenchGeometry` to the `CuttingBench` target.
  2. Confirm **`FacetKernel` is still listed** under the target's Frameworks and Libraries. The new
     package depends on `Kernel/` itself, and both must resolve.
  3. ⌘B, then ⌘R.
- **The agent's edit to `BenchRegions.swift`** — one line inside the existing `#if DEBUG` block in
  `StatusStripRegion`, added to `documentSummary` at `:108` so the strip's trailing text ends with
  `· rough 18 C/P/G1`, built from
  `"rough \(roughPlanes().count) \(roughFacets()[0].name)/\(roughFacets()[1].name)/\(roughFacets()[2].name)"`
  and `import BenchGeometry` at the top of the file. **This readout is temporary** — T2 replaces it
  with the real counts.
- **Done when:**
  - `swift test --package-path CuttingBench/BenchGeometry --disable-sandbox` is green, including these
    cases in `RoughPrismTests.swift`:
    - `roughPlanes().count == 18` and `roughFacets().count == 18`.
    - `roughFacets()[0] == .crownCap`, `roughFacets()[1] == .pavilionCap`,
      `roughFacets()[2] == .wall(0)`, `roughFacets()[17] == .wall(15)`.
    - `RoughFacet.wall(0).name == "G1"` and `RoughFacet.wall(15).name == "G16"`.
    - Plane 0 is `n == (0, 0, 1)`, `d == 1.0`; plane 1 is `n == (0, 0, -1)`, `d == 2.0`.
    - Plane 2 (`G1`) has `n` within `1e-12` of `(1, 0, 0)` and `d == 1.5`; plane 6 (`G5`) has `n`
      within `1e-12` of `(0, 1, 0)`.
    - **Every wall normal has `n.z` exactly `0`** — `XCTAssertEqual(plane.n.z, 0)` with no tolerance,
      which is the check D10 exists for.
    - `intersectHalfSpaces(roughPlanes())` gives `vertices.count == 32` and `facets.count == 18` — a
      16-gon prism, every plane a facet of it.
  - `git status --short Kernel` reports nothing.
  - `xcodebuild … build` succeeds with no warnings in the `CuttingBench` target.
  - `xcrun swift-format lint --recursive --strict CuttingBench/CuttingBench CuttingBench/BenchGeometry`
    is clean.
  - The verification handle below behaves exactly as written.
- **Do not:** write the bench solid, the mesh, the camera or anything Metal — this task is the package,
  one module and the link; add a test target to the Xcode project; touch `BenchWindow.swift`; put the
  package inside `CuttingBench/CuttingBench/`, which would compile its sources into the app target as
  well (D3); use `planeNormal(angleDegrees: 90, …)` for the walls (D10); add any `Package.swift`
  dependency beyond the local `../../Kernel`.
- **Verification handle** — `temporary` (T2 replaces the readout):
  - **Where:** the document window's status strip, trailing text, on ⌘R.
  - **Positive:** ⌘⇧O → open `Design/Patterns/Pattern-Easy-Octagon.json`. The strip's trailing text
    reads `Easy Octagon · finished · 6 tiers · rough 18 C/P/G1`. The `18` and the three names are read
    live out of `BenchGeometry`, so they prove the package is linked and its code is running.
  - **Negative:** ⌘N → a new window, whose trailing text reads `no pattern · rough 18 C/P/G1`. The
    rough half is unchanged, because the rough does not depend on a pattern — while the document half
    changed. A readout where both halves change, or where the `18` disappears with the pattern, is
    wrong.
  - **Reads:** `roughPlanes()` and `RoughFacet.name` in
    `CuttingBench/BenchGeometry/Sources/BenchGeometry/RoughPrism.swift`.

Commit point:

```
2-cutting-bench-app-shell-2 T1: add the BenchGeometry package and the rough prism

- a local SwiftPM package beside the app target, so the pure geometry has a
  test home the app target cannot give it
- the rough's eighteen half-spaces: C, P and G1..G16, walls exactly vertical
- a temporary status-strip readout proving the package is linked
```

---

**T2 — The bench solid: rough intersected with the pattern's placed tiers, named plane by plane**

This is the task the part exists for (D1). Everything after it renders what it produces.

- **Files:** `CuttingBench/BenchGeometry/Sources/BenchGeometry/BenchSolid.swift` (new),
  `CuttingBench/BenchGeometry/Tests/BenchGeometryTests/BenchSolidTests.swift` (new),
  `CuttingBench/CuttingBench/BenchSolidStore.swift` (new — `solid` and `generation` only; `mesh` is
  T3's), `CuttingBench/CuttingBench/BenchWindow.swift` (edit),
  `CuttingBench/CuttingBench/BenchRegions.swift` (edit — replace T1's temporary readout, add the
  stepper)
- **The readout and the stepper**, both inside the existing `#if DEBUG` block in `StatusStripRegion`:
  - The trailing text becomes
    `<name> · <state.rawValue> · <n> tiers · <f> facets (<c> cut, <r> rough)`, where `f` is
    `solid.polytope.facets.count`, `c` is `solid.cutFacetIndices.count` and `r` is
    `solid.roughFacetIndices.count`. With no pattern the leading part stays `no pattern` and the counts
    still show.
  - Directly before it, a `Stepper` bound to `tierLimit`, labelled `tiers \(shown)/\(total)` where
    `total` is `pattern?.tiers.count ?? 0` and `shown` is `tierLimit ?? total`. Its increment sets
    `tierLimit` to `min(shown + 1, total)` and its decrement to `max(shown - 1, 0)`; at `total` it
    stores `nil` rather than the number, so the unlimited case stays the default. It is disabled when
    `pattern == nil`.
  - **This one is `permanent`**: it displays and reaches a state the app must be able to draw — a
    part-cut stone — and it is the only way to see a rough-and-pattern solid at all, since all four
    authored patterns are `finished` and a finished pattern cuts every rough plane away. A later
    slice's scrubber supersedes it; deleting it here would leave the intersection unobservable.
- **Done when:**
  - `swift test --package-path CuttingBench/BenchGeometry --disable-sandbox` is green, including these
    cases in `BenchSolidTests.swift`. The four patterns are decoded from `Design/Patterns/` the way
    `Kernel/Tests/FacetKernelTests/PatternDecodingTests.swift:7` (`enum AuthoredPatterns {`) does it —
    a `#filePath`-derived directory, five levels up from the test file.
    - **No pattern:** `benchSolid(for: nil)` has `planes.count == 18`, `origin.count == 18`,
      `polytope.facets.count == 18`, `polytope.vertices.count == 32`, every `origin` value `.rough`,
      and `origin[0] == .rough(.crownCap)`.
    - **A finished pattern adds nothing to the kernel's own solid**, for each of the four authored
      patterns: `benchSolid(for: p).polytope.facets.count == (try solve(p)).polytope.facets.count`,
      the same for `vertices.count`, and `benchSolid(for: p).roughFacetIndices.isEmpty` — every rough
      plane cut away, every surviving facet `.cut`. This is D1's promise, stated as a check.
    - **Plane indices are offset by exactly 18:** for `Pattern-Easy-Octagon`,
      `benchSolid(for: p).planes.count == 18 + (try solve(p)).planes.count`, and for every solved
      plane index `k` with an owner, `origin[18 + k] == .cut(FacetRef(...))` carrying that owner's
      tier and index.
    - **A half-cut stone keeps rough:** `Pattern-Novice-Ash-er` at `tierLimit: 2` (its girdle `G` and
      `P1`) has a non-empty `roughFacetIndices` **and** a non-empty `cutFacetIndices`.
    - **The rough is deep enough for an intermediate point (D5):** that same 2-tier solid's minimum
      vertex `z` is below `-1.19` and above `-1.20` — `Novice Ash-er`'s `P1` point at −1.19175 — and
      **plane index 1, the bottom cap `P`, is absent from `polytope.facets`**, so the temporary point
      is inside the rough rather than clipped by it.
    - **Truncation does not disturb earlier tiers:** for `Pattern-Novice-Ash-er`, the solved `d` of
      tier `P1` is identical at `tierLimit: 2` and at `tierLimit: nil`.
    - `benchSolid(for: p, tierLimit: 0)` equals the no-pattern case in facet and vertex count.
  - `git status --short Kernel` reports nothing.
  - `xcodebuild … build` succeeds with no warnings in the `CuttingBench` target.
  - `xcrun swift-format lint --recursive --strict CuttingBench/CuttingBench CuttingBench/BenchGeometry`
    is clean.
  - No file under `CuttingBench/CuttingBench/` contains the string `rough 18` — T1's temporary readout
    is gone.
  - The verification handle below behaves exactly as written.
- **Do not:** build the mesh, the camera, the shader or the renderer; draw anything in the viewport,
  which stays part 1's placeholder until T4; call `solve` instead of `solveAsFarAsPossible`, or pass a
  `girdleTargetFraction` (D11, D12); report `partial.failure` anywhere — no alert, no findings line, no
  log; give `intersectHalfSpaces` a tolerance argument; add a real scrubber, or put the stepper
  anywhere but the status strip's `#if DEBUG` half; call `rebuildIfNeeded` from inside `body`, rather
  than from the `.onChange` modifiers; mutate `document.pattern`.
- **Verification handle** — `permanent`:
  - **Where:** the document window's status strip, trailing half — the stepper and the counts.
  - **Positive:** ⌘⇧O → `Design/Patterns/Pattern-Novice-Ash-er.json`. The strip reads
    `tiers 7/7` and `Novice Ash-er · finished · 7 tiers · N facets (N cut, 0 rough)` — **zero rough**,
    because a finished stone cuts the whole prism away. Now step the stepper down to `tiers 2/7`: the
    cut count drops, **the rough count becomes non-zero**, and the total changes. Step down to
    `tiers 0/7`: it reads `18 facets (0 cut, 18 rough)` — the bare prism.
  - **Negative:** ⌘N → a new window reading `18 facets (0 cut, 18 rough)` with **the stepper
    disabled**, and the leading text still `No findings`. Then step the *first* window back up to
    `tiers 7/7`: it returns to `(N cut, 0 rough)` with the same `N` it started at, and **the second
    window's counts do not move** — each document owns its own solid.
  - **Reads:** `benchSolid(for:tierLimit:)` and `BenchSolid.roughFacetIndices` in
    `CuttingBench/BenchGeometry/Sources/BenchGeometry/BenchSolid.swift`, through
    `BenchSolidStore.solid` in `CuttingBench/CuttingBench/BenchSolidStore.swift`.

Commit point:

```
2-cutting-bench-app-shell-2 T2: intersect the rough with the pattern's planes

- benchSolid appends the pattern's solved planes to the rough's eighteen and
  intersects the lot in the app; the kernel still knows nothing about rough
- every plane carries an origin: .rough(C/P/G1..G16) or .cut(tier, index)
- solveAsFarAsPossible, so a half-authored pattern draws what it has placed
- a debug tier limit in the status strip reaches the part-cut state, which no
  authored pattern can otherwise show
```

---

**T3 — The triangulated mesh, the edge list and the camera matrices**

Pure code with no visible effect, checkpointed rather than stopped: everything it delivers is checked
by tests over known geometry, and T4 is where it becomes visible.

- **Files:** `CuttingBench/BenchGeometry/Sources/BenchGeometry/SolidMesh.swift` (new),
  `CuttingBench/BenchGeometry/Sources/BenchGeometry/BenchCamera.swift` (new),
  `CuttingBench/BenchGeometry/Tests/BenchGeometryTests/SolidMeshTests.swift` (new),
  `CuttingBench/BenchGeometry/Tests/BenchGeometryTests/BenchCameraTests.swift` (new),
  `CuttingBench/CuttingBench/BenchSolidStore.swift` (edit — add `mesh`, built alongside `solid`)
- **Done when:**
  - `swift test --package-path CuttingBench/BenchGeometry --disable-sandbox` is green, including these
    cases.
  - In `SolidMeshTests.swift`:
    - **The layout the renderer hardcodes:** `MemoryLayout<MeshVertex>.stride == 28`,
      `MemoryLayout<MeshVertex>.offset(of: \.px) == 0`,
      `MemoryLayout<MeshVertex>.offset(of: \.nx) == 12`,
      `MemoryLayout<MeshVertex>.offset(of: \.role) == 24`.
    - **The bare prism, counted exactly:** `solidMesh(benchSolid(for: nil))` has
      `triangleVertices.count == 180` — 60 triangles, being 14 from each 16-gon cap and 2 from each of
      16 quad walls — and `edgeVertices.count == 96`, being 48 unique edges: 16 top, 16 bottom, 16
      vertical.
    - **Euler holds, which is what proves the edges were deduplicated**: for the bare prism and for
      each of the four authored patterns, `edgeVertices.count / 2 == vertices.count + facets.count - 2`.
    - **Roles:** every vertex of the bare prism's mesh has `role == 1`; every vertex of
      `Pattern-Easy-Octagon`'s mesh has `role == 0`; `Pattern-Novice-Ash-er` at `tierLimit: 2` has both
      values present.
    - **Normals are the planes' own:** for the bare prism, the triangles belonging to plane 2 (`G1`)
      all carry `(nx, ny, nz)` within `1e-6` of `(1, 0, 0)`, and every normal in the mesh has unit
      length within `1e-6`.
    - **Determinism:** two calls to `solidMesh` on the same solid produce identical arrays.
  - In `BenchCameraTests.swift`:
    - `benchViewMatrix() * SIMD4(benchCameraPosition(), 1)` is within `1e-5` of `(0, 0, 0, 1)`.
    - `benchViewMatrix() * SIMD4(BenchCamera.target, 1)` is within `1e-5` of
      `(0, 0, -BenchCamera.distance, 1)`.
    - `benchProjectionMatrix(aspect: 1)` sends view-space `(0, 0, -BenchCamera.near, 1)` to NDC
      `z == 0` and `(0, 0, -BenchCamera.far, 1)` to NDC `z == 1`, both within `1e-5`, after dividing by
      `w`.
    - **The framing constants actually fit the rough:** every one of the 32 vertices of
      `benchSolid(for: nil).polytope`, put through `benchProjectionMatrix(aspect:) * benchViewMatrix()`
      and divided by `w`, lands with `x` and `y` in `-1...1` and `z` in `0...1` — at `aspect: 0.75` and
      again at `aspect: 2.0`. This is the test that fails if the distance constant is tuned too tight
      at T4's owner stop.
  - `git status --short Kernel` reports nothing.
  - `xcodebuild … build` succeeds with no warnings in the `CuttingBench` target.
  - `xcrun swift-format lint --recursive --strict CuttingBench/CuttingBench CuttingBench/BenchGeometry`
    is clean.
- **Do not:** add anything Metal — no `import Metal`, no `MTLBuffer`, no pipeline; this task's output is
  plain arrays and matrices; compute a triangle's normal by cross product instead of taking the plane's
  own (D17); triangulate anything but a fan from `v[0]`; change the viewport, the window or the status
  strip beyond adding `mesh` to the store; add a `left`/`right`-handed variant, an orthographic
  projection or a second camera — one fixed view (D23).

---

**T4 — Metal draws the solid: flat per-facet fill, rough against cut, fixed three-quarter camera**

**First, one claim this plan could not settle by reading.** A `.metal` file added to the synchronized
folder should be compiled into the target automatically, the way a `.swift` file is. Run
`xcodebuild -project CuttingBench/CuttingBench.xcodeproj -scheme CuttingBench -destination 'platform=macOS' clean build 2>&1 | grep -c 'CompileMetalFile.*Shaders.metal'`
after writing the file. **If that count is zero**, the synchronized group did not pick it up: stop, and
ask the owner for this one step — in Xcode, select `Shaders.metal`, open the File Inspector, and tick
`CuttingBench` under Target Membership. That is the whole of the permitted fallback (D16, D22). Do not
switch to `makeLibrary(source:)`, and do not move the shader out of the synchronized folder.

- **Files:** `CuttingBench/CuttingBench/Shaders.metal` (new — the fill functions only; the edge
  functions are T5's), `CuttingBench/CuttingBench/BenchRenderer.swift` (new — the fill pipeline only),
  `CuttingBench/CuttingBench/MetalViewport.swift` (new),
  `CuttingBench/CuttingBench/BenchRegions.swift` (edit — `ViewportRegion` hosts `MetalViewport`),
  `CuttingBench/CuttingBench/BenchWindow.swift` (edit — pass `store.mesh` and `store.generation` into
  `ViewportRegion`)
- **Done when:**
  - The `clean build` grep above returns at least `1`, or the owner's one-step fallback was applied and
    it then does.
  - `xcodebuild … build` succeeds with no warnings in the `CuttingBench` target.
  - `xcrun swift-format lint --recursive --strict CuttingBench/CuttingBench CuttingBench/BenchGeometry`
    is clean.
  - `swift test --package-path CuttingBench/BenchGeometry --disable-sandbox` is green and
    `git status --short Kernel` reports nothing.
  - `grep -c 'Color(red:\|Color(\.sRGB\|NSColor(red:\|#[0-9a-fA-F]\{6\}' CuttingBench/CuttingBench/*.swift`
    returns `0` for every file, and `Shaders.metal` contains no colour literal — every colour comes
    from a named system colour through `Uniforms` (D20, D21).
  - `ViewportRegion`'s body is one `MetalViewport` and nothing else (part 1's replaceable-subview rule).
  - `BenchRenderer` calls `setCullMode(.none)` and does **not** call `setFrontFacing` (D18).
  - The verification handle below behaves exactly as written.
- **If the solid renders inside-out** — the far facets visible and the near ones missing — **the one
  permitted fix is to change `setCullMode(.none)` to `setCullMode(.front)`** and say so as a material
  alteration. Nothing else about the winding, the matrices or the triangulation is to be changed by
  experiment.
- **Tuning at the owner stop.** The only values adjustable by eye are
  `BenchCamera.azimuthDegrees`, `elevationDegrees`, `distance` and `fieldOfViewDegrees`, and the shader's
  `kAmbient`/`kDiffuse` pair, which must keep summing to `1.0`. Changing a camera constant means
  re-running T3's framing test, which is what catches a distance tuned too tight. **The colour roles in
  D21 are not tuning** — a different `NSColor` is a decision, not an adjustment, and swapping one is a
  stop.
- **Do not:** draw edges — T5 owns them, and this task's render is fill only; enable blending, set an
  opacity, or add an alpha control (D23); add a gesture recognizer, a `mouseDown` override, a
  `NSTrackingArea` or any hit test (D23); draw text, an index ring or an axis gizmo; set
  `isPaused = false` or `preferredFramesPerSecond` — the view redraws on demand (D13); call
  `benchSolid` or `solidMesh` anywhere inside `draw(in:)` (D13); compile the shader from a string (D16);
  add a second renderer or an offscreen pass; touch `ScrubberRegion`, `TierTableRegion` or
  `InspectorRegion`.
- **Verification handle** — `permanent`:
  - **Where:** the viewport, top-left of the document window, with the T2 stepper in the status strip.
  - **Positive:** ⌘N → a new window shows a **grey 16-sided prism**, seen from above and to one side:
    the top cap and about half the walls visible, each wall a flat, slightly different tone from its
    neighbours, and the whole thing fitting inside the viewport with a margin. ⌘⇧O →
    `Design/Patterns/Pattern-Standard-Round-Brilliant.json` → the prism is replaced by a **round
    brilliant in the accent colour**, table up, no grey anywhere. Now step the stepper down to
    `tiers 2/7`: **grey rough reappears** around and above a pavilion cone in the accent colour —
    that is the intersection in D1, visible. Step to `tiers 0/7` → the plain grey prism again.
  - **Negative:** with the round brilliant at `tiers 7/7`, switch System Settings ▸ Appearance to Dark:
    **the viewport background follows the rest of the window and the stone stays visible against it.**
    A viewport that stays light while the window goes dark is a hardcoded colour and a defect (D20,
    D21). And resize the window by dragging its corner: **the stone changes size on screen but does not
    stretch or shear** — the aspect ratio is read from the drawable, so a wide window shows a wider
    field, never a wider stone.
  - **Reads:** `solidMesh` and `benchViewMatrix()` in
    `CuttingBench/BenchGeometry/Sources/BenchGeometry/`, through `BenchRenderer.draw(in:)` in
    `CuttingBench/CuttingBench/BenchRenderer.swift`. If `BenchRenderer` were deleted the viewport would
    fail to build, and if `solidMesh` returned nothing the viewport would be empty.

Commit point:

```
2-cutting-bench-app-shell-2 T4: draw the solid in Metal

- an MTKView behind NSViewRepresentable fills the viewport region, redrawn on
  demand rather than at 60 Hz: nothing here animates
- flat per-facet fill from each plane's own normal, so every facet reads as its
  own plane; uncut rough grey against cut facets in the accent colour
- one fixed three-quarter camera, its constants the only thing tuned by eye
- every colour resolved from a named system colour, so dark mode tracks
```

---

**T5 — The edges, always drawn**

- **Files:** `CuttingBench/CuttingBench/Shaders.metal` (edit — add `edge_vertex` and `edge_fragment`),
  `CuttingBench/CuttingBench/BenchRenderer.swift` (edit — the second pipeline, the edge buffer, the
  second draw call)
- **Done when:**
  - `xcodebuild … build` succeeds with no warnings in the `CuttingBench` target, and the
    `clean build` grep for `CompileMetalFile.*Shaders.metal` still returns at least `1`.
  - `xcrun swift-format lint --recursive --strict CuttingBench/CuttingBench CuttingBench/BenchGeometry`
    is clean.
  - `swift test --package-path CuttingBench/BenchGeometry --disable-sandbox` is green and
    `git status --short Kernel` reports nothing.
  - `Shaders.metal` contains `out.position.z -= kEdgeDepthEpsilon * out.position.w;` and
    `BenchRenderer.swift` contains no call to `setDepthBias` (D19).
  - Both pipelines share one `MTLDepthStencilState`, and the edge draw uses `.line`.
  - The verification handle below behaves exactly as written.
- **Do not:** thicken the lines with a geometry trick, a quad expansion or a second pass — a one-pixel
  `.line` is the whole of it; draw edges for a subset of facets, or a silhouette-only outline; use
  `setDepthBias`, a polygon offset or a depth-clamp to solve z-fighting (D19); disable the depth test
  for the edge draw, which would draw the far side's edges through the stone; change the fill pipeline,
  the mesh, the camera or any colour role.
- **Verification handle** — `permanent`:
  - **Where:** the viewport, with `Design/Patterns/Pattern-Standard-Round-Brilliant.json` open.
  - **Positive:** every facet is now outlined — **the girdle band, the table's octagon-of-sixteen and
    each crown and pavilion facet read as separate outlined shapes**, with no shimmering or dashed
    dropout along a line as the window is resized. Step the stepper to `tiers 2/7`: the grey rough's
    own edges are drawn too, in the same colour, so the sixteen prism walls are individually outlined.
  - **Negative:** **no edge from the far side of the stone shows through it.** Looking at the crown, the
    pavilion's edges are hidden behind it; if the whole wireframe is visible at once, the edge draw lost
    its depth test. And in Dark appearance the edge colour follows `NSColor.labelColor` — light lines on
    a dark stone — rather than staying dark.
  - **Reads:** `SolidMesh.edgeVertices` in
    `CuttingBench/BenchGeometry/Sources/BenchGeometry/SolidMesh.swift`, drawn by the edge pipeline in
    `CuttingBench/CuttingBench/BenchRenderer.swift`.

Commit point:

```
2-cutting-bench-app-shell-2 T5: draw the facet edges

- a second pipeline over the deduplicated edge list, one line per shared pair
- edges win the depth test by a fixed clip-space epsilon in their own vertex
  function, which is stable where setDepthBias' semantics are not
```

---

**T6 — Close out**

- **Delete the temporary handles:** T1's `rough 18 C/P/G1` readout was the only one, and T2 replaced it.
  **Confirm no file under `CuttingBench/CuttingBench/` contains the string `rough 18`.** T2's counts and
  stepper, T4's viewport and T5's edges are all `permanent` and stay — the stepper included, per T2.
- **Confirm every item in this plan's Deferred section has a ticket** in `Design/Tickets/` with
  `Status: untriaged`. The tickets are filed as each item is found, per the protocol's §4 — this is the
  check, not the filing. If Deferred is empty, there is nothing to check.
- **Report the untriaged ticket count** in `Design/Tickets/` as one line.
- `commit + push` with the message below.
- **Archive nothing, and close no ticket.** This is part 2 of three. The exploration
  `2-Cutting-Bench-App-Shell` is the source for part 3 and stays live, and this plan stays in
  `Design/Plans/` alongside part 1. Part 3 runs the archive routine for the exploration, all three parts
  and every ticket. Do not touch `Design/Archived/ArchivedCatalog.md`.
- **Set this plan's `Status:` line** to `COMPLETED <yyyy-mm-dd>` once the owner signs off T5, leaving the
  file where it is.

Commit point:

```
2-cutting-bench-app-shell-2 T6: close out part 2

- the viewport draws the rough prism cut by the pattern's placed tiers, flat
  per-facet with its edges, on one fixed three-quarter camera
- nothing archived: part 3 still reads the exploration
```

## Deferred

Empty at authoring. The executor appends adjacent problems it found and must not fix — and files each
as a ticket in `Design/Tickets/` immediately with `Status: untriaged`, per the protocol's §4.

- **`FacetKernel.Observation` shadows the `Observation` module**, so `@Observable` will not compile in an
  app file that imports the whole kernel. Worked around locally with a scoped import at T2.
  → `Chore-Observation-Type-Shadows-Its-Module`
- **The Metal toolchain is a separately downloaded Xcode component** and is not named in the protocol's
  *Environment & toolchain* block, which is what T4 was blocked on.
  → `Chore-Metal-Toolchain-Not-In-The-Environment-Declarations`
