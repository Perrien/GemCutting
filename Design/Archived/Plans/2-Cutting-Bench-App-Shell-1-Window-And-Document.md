# 2 · Cutting Bench App Shell — 1 · Window And Document

Status: **COMPLETED 2026-08-24**

## Parts

**For the owner and the next authoring session — not for the executor.** Nothing in this part's tasks
refers to another part.

1. `2-Cutting-Bench-App-Shell-1-Window-And-Document` — the app exists, opens a pattern file through
   the Open dialog, and shows the five layout regions present and empty. ← this part
2. `2-Cutting-Bench-App-Shell-2-Rough-In-The-Viewport` — the rough prism intersected with the
   pattern's own planes, drawn in Metal with flat per-facet fill and always-drawn edges, on a fixed
   three-quarter camera.
3. `2-Cutting-Bench-App-Shell-3-Camera-And-Facet-Naming` — free orbit, face-up and face-down snaps,
   the opacity control, click-a-facet-get-its-name, and the index-stop ring with its fade. Closes the
   exploration out and runs the archive routine.

| Exploration ID | Part |
|---|---|
| S1 | 1 |
| S2 | 2 |
| S3 | 2 |
| I1 | 2 — its planning consequences (owner-run `project.pbxproj`, deployment target) bind part 1 and are restated there |
| I2 | 2 |
| I3 | 2 — consumed by part 3's picking |
| I4 | 2 |
| I5 | 1 |
| U1 | 1 |
| U2 | 1 — restated in parts 2 and 3, which must not introduce a bespoke palette |
| U3 | 3 |
| U4 | 3 |

Ticket closure and the archive routine run once, in part 3.

## Context

The owner wants to stop reading printed faceting sheets and hand-writing JSON, and the first step is
an app that exists at all: a window that opens one of the four authored patterns and shows the frame
the next four slices fill in. Nothing is drawn from the pattern's geometry in this part — that is part
2 — and nothing is edited or saved.

**There is no app target today.** `Design/Execution-Protocol.md:58` names the deliverable as
`Kernel/` — a SwiftPM package producing the library `FacetKernel` — and says *"`CuttingBench/` joins
it in the second plan."* This is that plan. So this part creates a source tree that does not exist,
and its one dependency on existing code is that the kernel can already decode a pattern file.

**It can.** `Kernel/Sources/FacetKernel/Pattern.swift:86`
(`public struct Pattern: Codable, Equatable, Sendable`) is public and `Codable`, and decoding is
plain `JSONDecoder` — `Kernel/Tests/FacetKernelTests/PatternDecodingTests.swift:29`
(`try JSONDecoder().decode(FacetKernel.Pattern.self, from: Data(contentsOf: url(name)))`) is the
exact call the app makes. Writing is public too:
`Kernel/Sources/FacetKernel/Pattern.swift:275` (`public func encoded(_ pattern: Pattern) throws -> Data`),
which is the only writer per ADR-0003.

**The kernel needs no change for this part.** Everything it must expose is already public:
`Pattern`, `TierSpec` (`Pattern.swift:54`), `Meet` (`Pattern.swift:21`),
`PatternState` (`Pattern.swift:4` — `case inProgress = "in progress"`), and `encoded`. This part adds
no Swift under `Kernel/` at all.

**The package is already set up to be depended on.** `Kernel/Package.swift` declares
`swift-tools-version:6.0`, `platforms: [.macOS(.v15)]`, and
`.library(name: "FacetKernel", targets: ["FacetKernel"])`, so an Xcode target can add `Kernel/` as a
local package dependency and link `FacetKernel` with no manifest edit.

**Xcode's build artifacts are already ignored.** `.gitignore` carries `DerivedData/`, `xcuserdata/`
and `*.xcuserstate`, so no ignore work is needed when the project lands.

**The four patterns to open live in `Design/Patterns/`** — `Pattern-Easy-Octagon.json`,
`Pattern-Novice-Ash-er.json`, `Pattern-Rands-Cut-Corner-Rectangle.json`,
`Pattern-Standard-Round-Brilliant.json`. Their filenames and fixture values are external ground truth
under the protocol's guardrails: **this part reads them and never edits one.**

So this is a small amount of new code against a kernel that already does the hard part, plus one owner
step in Xcode that no agent may take.

## Decisions (2026-08-24)

| # | Decision |
|---|---|
| D1 | **A standard Mac document-based app.** Document-based is taken for the file handling, not for the windows: Open, Save, Save As, revert, recent files, the dirty indicator and a per-document undo manager all come from the framework and the app needs every one of them eventually. Multiple open documents fall out for free rather than being scope. |
| D2 | **SwiftUI, not AppKit** — `DocumentGroup` for the document handling, `.inspector` for the collapsible right-hand column, `Table` for the tier table. Chosen by the owner on 2026-08-24; the exploration named `MTKView` but never named a UI framework. The viewport region is filled by an `NSViewRepresentable`-wrapped `MTKView` in part 2, so **this part must leave the viewport region as a single replaceable subview, not a SwiftUI drawing.** |
| D3 | **The document's model is `Pattern?`, and `nil` is a real state** — a new document, or one whose file has not been read. A window with no pattern shows the layout with every region empty and nothing drawn, which is exactly the state the index ring must suppress in part 3. This also avoids inventing default values for an empty `Pattern`, which is `4-Cutting-Bench-Authoring`'s decision and not this plan's. |
| D4 | **`ReferenceFileDocument`, not `FileDocument`** — D1 names the per-document undo manager, and only a reference-type document carries one. |
| D5 | **Writing goes through `FacetKernel.encoded(_:)` and nowhere else**, per ADR-0003: the kernel owns the pattern file's reader *and* writer. The app never builds JSON itself. With `pattern == nil` there is nothing to write, so writing throws `CocoaError(.featureUnsupported)`. |
| D6 | **Patterns stay `.json` with handler rank `Alternate`, and there is no double-click routing.** macOS routes documents by extension and UTI and never by looking inside a file, so nothing distinguishes a pattern from any other JSON. Claiming `public.json` as owner would send every JSON file on this machine to this app; `Alternate` declares the app can open one without stealing the type. |
| D7 | **Patterns are opened from inside the app, and the dialog that starts in `Design/Patterns/` is the app's own `File ▸ Open Pattern…` command (⌘⇧O), alongside the framework's plain `Open…` (⌘O).** There is no public SwiftUI API for `DocumentGroup`'s open-panel start directory, and the two routes that would reach it — subclassing `NSDocumentController` and hoping the subclass wins the race to become `shared`, or seeding the undocumented `NSNavLastRootDirectory` default — are both bets on unspecified behaviour. The command runs an `NSOpenPanel` with `directoryURL` set and hands the result to `NSDocumentController.shared.openDocument(withContentsOf:display:)`, all public API. **The cost is a second Open item in the File menu, and it is accepted**: it is the "open one of my patterns" command, which is what the owner does every time. Recent files cover everything after the first time. |
| D8 | **The patterns directory is derived from `#filePath` at compile time, behind `#if DEBUG`, and it is set on the panel without an existence check.** The app is Mac-only, personal and never distributed, so baking this checkout's path into a debug build costs nothing. No existence check, because the App Sandbox stops the app statting a path outside its container, so the check would report `false` for a directory that is really there; `NSOpenPanel` already falls back to its own last-used directory when handed one that is gone. The panel runs outside the sandbox, so setting `directoryURL` needs no entitlement. **No preference, no Settings pane, no user-defined build setting** — a build setting would mean editing `project.pbxproj`, which is owner-run. |
| D9 | **The layout is the owner's sketch** (`Design/Explorations/CB UI.png`): viewport top-left, the inspector a right-hand column of stacked cards with the pattern header card first and `notes` below it, and the tier table across the bottom with its columns ordered **tier, part, angle, indices, meet, wheel, instructions**. The scrubber sits directly under the viewport and the status strip is one line at the bottom of the main area. The sketch predates both and shows neither; where it is silent it is incomplete, not contradicting. |
| D10 | **The inspector spans the trailing edge of the whole window; the tier table spans the width of the main area left of it, and the status strip is the main area's bottom row.** `.inspector` applied to the window's root content view is its documented position, and it puts the strip in the main area rather than under the inspector — the strip reports the document's findings, which is a main-area concern. |
| D11 | **The viewport, tier table, inspector cards, scrubber and status strip are all present and empty.** What fills each is owned by a later slice. The tier table shows its seven column headers over zero rows, which lands the column order now. |
| D12 | **No up-front visual specification. The app is built to stock native macOS and the look is adjusted in the running app at each owner stop.** System semantic colours, the standard inspector-and-table idiom, system type sizes, standard spacing — no bespoke palette, no type scale, no spacing scale, no mockups. This is safe rather than a shrug: the layout is fixed by D9 and **colour is never load-bearing alone** anywhere in this app, so a plain palette costs correctness nothing. |
| D13 | **`project.pbxproj` is owner-run.** `Design/Execution-Protocol.md:87` treats hand-editing it as a corruption risk producing unreviewable diffs, and forbids touching signing, capabilities, entitlements or the bundle identifier. **T1 is therefore an owner task, not an agent one** — the agent writes no file inside `CuttingBench.xcodeproj` in any task of this plan. |
| D13a | **The target uses a file-system-synchronized group, which is what makes every later task agent-runnable.** Xcode creates new projects this way, so the folder's contents *are* the target's contents and adding or deleting a `.swift` file needs no `project.pbxproj` edit. T1's checklist has the owner confirm it; if the project is not synchronized, every task after T1 would need an owner in Xcode and the plan is wrong, which is a stop. |
| D13b | **The App Sandbox stays on, at Xcode's default.** Nothing this part does needs to escape it — the document framework's open panel and D7's own panel both grant access to what the user picks. **The agent never edits the entitlements file or the signing settings**, per the protocol's guardrail; if a task appears to need that, it stops. |
| D14 | **The deployment target is macOS 26.0** — what this machine runs (`sw_vers` reports `26.5.2`). The tool is Mac-only, personal and never distributed, so there is no back-compatibility question. |
| D15 | **A file that is not a valid pattern reports why.** Decoding throws either `DecodingError` or `FacetKernel.PatternError` (`Pattern.swift:136`), neither of which is a `LocalizedError`, so the framework's alert would show a useless string. The app wraps the failure in one `LocalizedError` whose reason is the underlying error's `description`. |
| D16 | **No pattern browser and no thumbnails.** Four patterns through a file dialog is not a problem, and thumbnails would mean rendering patterns nobody has opened. Worth revisiting when the catalog is 53 designs rather than four. |
| D17 | **Nothing in this part draws pattern geometry, and there is no yield or rough-retention readout and no volume code.** Rough retention is the game's number, not this tool's — it needs a target size and an achieved girdle placement, which is per-job state this tool has no concept of. |

## Tickets closed by this plan

None — closed in the final part.

The three tickets standing in `Design/Tickets/` today —
`Chore-Incremental-Half-Space-Clipper`, `Chore-Stale-Links-In-The-Format-Document` and
`Chore-Validation-Rebuilds-The-Solid-Once-Per-Tier` — are none of them this plan's, and the exploration
folded in no ticket at all.

## Prefactoring

**None needed, because there is nothing to prefactor.** No `CuttingBench/` source tree exists, this
part adds no Swift under `Kernel/`, and every file it touches is either new or generated by Xcode's
template in T1. `.gitignore` already covers `DerivedData/`, `xcuserdata/`, `*.xcuserstate` and
`.swiftpm/`, so it needs no edit either. There is no existing behaviour to preserve and so no
characterization test to write.

## Approach

The owner creates an Xcode project and target in `CuttingBench/` and links the local `Kernel/`
package. The agent then writes five Swift files into the synchronized source folder: a document class
wrapping `Pattern?`, the app entry point, the app's own Open-Pattern command, the window layout, and
the five empty regions it is made of. Nothing under `Kernel/` is touched.

**Where the code lives.** Xcode's App template puts the target's sources in
`CuttingBench/CuttingBench/`, alongside `Assets.xcassets` and the generated entitlements file. Every
path below is relative to the repository root.

**There are no unit tests in this part.** Every file it adds is either a SwiftUI view with no logic
worth pinning or a thin wrapper over `JSONDecoder` and `FacetKernel.encoded`, and the checks that
matter are the four owner stops. Testable pure modules arrive in part 2, where the rough prism and the
half-space solid are real geometry.

### 1. Owner step: `CuttingBench/CuttingBench.xcodeproj`

Created by the owner in Xcode, not by the agent (D13). The exact settings are in T1's checklist.

### 2. New: `CuttingBench/CuttingBench/PatternDocument.swift`

The document, and the one error type the framework's alert shows.

```swift
import FacetKernel
import SwiftUI
import UniformTypeIdentifiers

/// The open pattern file. `nil` is a real state — a new document, per D3.
final class PatternDocument: ReferenceFileDocument {
  typealias Snapshot = Pattern?

  @Published var pattern: Pattern?

  static var readableContentTypes: [UTType] { [.json] }

  init() { pattern = nil }

  init(configuration: ReadConfiguration) throws {
    guard let data = configuration.file.regularFileContents else {
      throw CocoaError(.fileReadCorruptFile)
    }
    do {
      pattern = try JSONDecoder().decode(Pattern.self, from: data)
    } catch {
      throw PatternReadError(underlying: error)
    }
  }

  func snapshot(contentType: UTType) throws -> Pattern? { pattern }

  /// Writing goes through the kernel and nowhere else (D5, ADR-0003).
  func fileWrapper(snapshot: Pattern?, configuration: WriteConfiguration) throws -> FileWrapper {
    guard let snapshot else { throw CocoaError(.featureUnsupported) }
    return FileWrapper(regularFileWithContents: try encoded(snapshot))
  }
}

/// `DecodingError` and `PatternError` are neither of them `LocalizedError`, so the framework's alert
/// would show a useless string without this (D15).
struct PatternReadError: LocalizedError {
  let underlying: any Error
  var errorDescription: String? { "This file is not a valid faceting pattern." }
  var failureReason: String? { String(describing: underlying) }
}
```

Two notes for the executor. `ReferenceFileDocument` refines `ObservableObject`, so `@Published` is
available without declaring conformance. And `encoded` is a free function in `FacetKernel` — call it
unqualified, or as `FacetKernel.encoded(snapshot)` if the name collides.

### 3. New: `CuttingBench/CuttingBench/PatternsFolder.swift`

The compile-time path and the Open-Pattern command's panel (D7, D8).

```swift
import AppKit
import UniformTypeIdentifiers

/// `Design/Patterns/` in the checkout this binary was built from, or `nil` in a release build.
///
/// Derived from `#filePath` — this file sits at `<repo>/CuttingBench/CuttingBench/`, so the repository
/// root is three levels up. Never existence-checked: the App Sandbox cannot stat a path outside the
/// container, so the check would say `false` for a directory that is really there (D8).
var patternsFolder: URL? {
  #if DEBUG
    URL(filePath: #filePath)
      .deletingLastPathComponent()  // CuttingBench/CuttingBench
      .deletingLastPathComponent()  // CuttingBench
      .deletingLastPathComponent()  // repository root
      .appending(path: "Design/Patterns", directoryHint: .isDirectory)
  #else
    nil
  #endif
}

/// Runs the app's own Open dialog, started in `Design/Patterns/`, and opens what the owner picks.
@MainActor
func openPatternFromPatternsFolder() {
  let panel = NSOpenPanel()
  panel.allowedContentTypes = [.json]
  panel.allowsMultipleSelection = false
  panel.canChooseDirectories = false
  panel.message = "Choose a faceting pattern."
  if let patternsFolder { panel.directoryURL = patternsFolder }
  guard panel.runModal() == .OK, let url = panel.url else { return }
  NSDocumentController.shared.openDocument(withContentsOf: url, display: true) { _, _, _ in }
}
```

### 4. New: `CuttingBench/CuttingBench/CuttingBenchApp.swift`

Replaces the template's own `CuttingBenchApp.swift`. The template's `ContentView.swift` is deleted.

```swift
import SwiftUI

@main
struct CuttingBenchApp: App {
  var body: some Scene {
    DocumentGroup(newDocument: { PatternDocument() }) { file in
      BenchWindow(document: file.document)
    }
    .commands {
      CommandGroup(after: .newItem) {
        Button("Open Pattern…") { openPatternFromPatternsFolder() }
          .keyboardShortcut("o", modifiers: [.command, .shift])
      }
    }
  }
}
```

### 5. New: `CuttingBench/CuttingBench/BenchWindow.swift`

The layout root (D9, D10). One `VStack`: the split of viewport-plus-scrubber over tier table, then the
status strip. `.inspector` on the root content view puts the inspector down the trailing edge of the
whole window, so the status strip belongs to the main area rather than sitting under the inspector.

```swift
import SwiftUI

struct BenchWindow: View {
  @ObservedObject var document: PatternDocument
  @State private var inspectorShown = true

  var body: some View {
    VStack(spacing: 0) {
      VSplitView {
        VStack(spacing: 0) {
          ViewportRegion()
            .frame(minHeight: 240)
          Divider()
          ScrubberRegion()
        }
        TierTableRegion()
          .frame(minHeight: 140)
      }
      Divider()
      StatusStripRegion(pattern: document.pattern)
    }
    .frame(minWidth: 900, minHeight: 600)
    .inspector(isPresented: $inspectorShown) {
      InspectorRegion()
        .inspectorColumnWidth(min: 260, ideal: 300, max: 420)
    }
    .toolbar {
      Button {
        inspectorShown.toggle()
      } label: {
        Label("Inspector", systemImage: "sidebar.trailing")
      }
    }
    .navigationTitle(document.pattern?.name ?? "Untitled")
  }
}
```

### 6. New: `CuttingBench/CuttingBench/BenchRegions.swift`

The five regions, all empty (D11), plus the debug readout that is T2's and T3's verification handle.

- **`ViewportRegion`** — a single `Color` filling its space, with a centred secondary-text label
  reading `Viewport`. **It must stay one replaceable subview** (D2): part 2 swaps its body for an
  `NSViewRepresentable`-wrapped `MTKView`, so nothing else may draw into this region.
- **`ScrubberRegion`** — a fixed 32-point-high strip with a centred secondary-text label reading
  `Scrubber`.
- **`TierTableRegion`** — a SwiftUI `Table` over an empty array of `TierRow`, with the seven columns in
  D9's order and no rows:

  ```swift
  /// A tier table row. Every column is a string in this part — the table is empty (D11), and what
  /// fills it is a later slice's.
  struct TierRow: Identifiable {
    let id = UUID()
    var tier = ""
    var part = ""
    var angle = ""
    var indices = ""
    var meet = ""
    var wheel = ""
    var instructions = ""
  }
  ```

  Columns, in order: `Tier`, `Part`, `Angle`, `Indices`, `Meet`, `Wheel`, `Instructions`.
- **`InspectorRegion`** — a `ScrollView` of five `GroupBox`es in this order: `Pattern`, `Notes`,
  `Metrics`, `Light`, `Facet Count`. Each holds one centred secondary-text line reading `empty`.
  `Pattern` first and `Notes` directly below it is D9's ordering and is not the executor's to change.
- **`StatusStripRegion(pattern: Pattern?)`** — a 22-point-high row. Leading text reads `No findings`
  unconditionally, since nothing computes findings until part 4. **Trailing, behind `#if DEBUG`, the
  document summary**: with no pattern, `no pattern`; with one, `<name> · <state.rawValue> · <n> tiers`,
  reading `pattern.name`, `pattern.state.rawValue` and `pattern.tiers.count` straight off the document.
  This is the handle that proves decoding worked, and it is `permanent` — it displays real state and
  costs nothing.

All colours come from system semantic colours — `Color(nsColor: .textBackgroundColor)`,
`.secondary`, `Color(nsColor: .separatorColor)` — and there is no hardcoded sRGB value anywhere (D12).

## Explicitly not doing

- **No pattern geometry drawn, and no Metal.** The viewport is a labelled placeholder. Part 2 owns the
  renderer, and D2 requires the region stay one replaceable subview so it can.
- **No camera, no orbit, no snap views, no opacity control, no facet picking, no index ring.** Part 3.
- **No tier table contents, no inspector contents, no scrubber behaviour, no findings.** D11 — the
  regions are present and empty, and later slices fill them.
- **No editing and no draft type.** ADR-0003 puts the half-authored draft in the app, but it belongs to
  `4-Cutting-Bench-Authoring`; this part's document holds a decoded `Pattern?` and nothing mutates it.
- **No yield or rough-retention readout and no volume code** (D17).
- **No pattern browser and no thumbnails** (D16).
- **No new extension and no rename of the four authored patterns.** A distinct extension is the only
  thing that would give double-click routing, and it would mean editing files the guardrails name as
  external ground truth — `Kernel/Tests/FacetKernelTests/RegressionTests.swift:21`
  (`"facetsolve Design/Patterns/\(pattern).json --json"`) and `PatternDecodingTests.swift` — plus
  `design-authoring-format.md`. That is a deliberate decision for
  later, not a side effect of this build.
- **No change to `Kernel/`.** Everything needed is already public. A task that seems to need a kernel
  change is a stop.
- **No edit to `project.pbxproj`, entitlements or signing by the agent** (D13, D13b).
- **No third-party dependencies** — Swift, the standard library and the system frameworks only, per the
  protocol's guardrail.
- **No bespoke palette, type scale or spacing scale** (D12).
- **No unit test target.** Xcode's test-target checkbox stays unchecked in T1; part 2 adds tests where
  there is geometry worth pinning.

## Tasks

| # | Task | Status | Then | Commit | Note |
|---|---|---|---|---|---|
| T1 | **Owner:** create the Xcode project and target, link `Kernel/`, declare the document type | completed | **owner stop** | commit | Owner-run — the agent must not edit `project.pbxproj` |
| T2 | The document opens a pattern file and reports what it decoded | completed | **owner stop** | commit | |
| T3 | The window layout — five regions, present and empty | completed | **owner stop** | commit | |
| T4 | Close out | completed | **owner stop** | commit + push | Archives nothing — part 3 does that |

**Gates, for every task in this plan.** The protocol's gates 1 and 2 are unconditional and will pass
untouched, because no task here adds Swift under `Kernel/`; gate 3 does not apply for the same reason.
**The protocol's gates therefore say nothing about whether the app builds**, so every task from T2 on
carries these two as *Done when* items in its own right:

- `xcodebuild -project CuttingBench/CuttingBench.xcodeproj -scheme CuttingBench -destination 'platform=macOS' build` — succeeds, no warnings in the `CuttingBench` target.
- `xcrun swift-format lint --recursive --strict CuttingBench/CuttingBench` — clean. Fix with
  `xcrun swift-format format --in-place --recursive CuttingBench/CuttingBench`, which matches
  `Kernel/`'s own two-space, hundred-column default.

---

**T1 — Owner: create the Xcode project and target**

**This task is executed by the owner in Xcode.** The agent's part is to present this checklist, wait,
and then verify the result by reading files — never by editing anything inside
`CuttingBench.xcodeproj` (D13).

- **Files:** `CuttingBench/CuttingBench.xcodeproj` (new, owner), `CuttingBench/CuttingBench/` (new
  folder, owner — Xcode's template contents)
- **Owner checklist, in order:**
  1. **File ▸ New ▸ Project ▸ macOS ▸ App.** Not "Document App" — the document scaffolding is written
     by hand in T2, and the App template leaves fewer template files behind.
  2. Product Name `CuttingBench`. **Interface: SwiftUI. Language: Swift. Testing System: None.
     Storage: None.** Leave "Include Tests" unchecked — see *Explicitly not doing*.
  3. Save into the repository root `/Users/analyst/CCode/GemCutting`, so the project lands at
     `CuttingBench/CuttingBench.xcodeproj` with sources at `CuttingBench/CuttingBench/`. **Decline
     Xcode's offer to create a git repository** — one already exists.
  4. **Target ▸ General ▸ Minimum Deployments ▸ macOS: `26.0`** (D14).
  5. **File ▸ Add Package Dependencies… ▸ Add Local…** ▸ select the `Kernel` folder ▸ add the library
     product `FacetKernel` to the `CuttingBench` target.
  6. **Target ▸ Info ▸ Document Types**, one entry: Name `Faceting Pattern`, Types `public.json`,
     Role `Editor`, and one additional property `LSHandlerRank` (String) = `Alternate` (D6).
  7. **In `ContentView.swift`, add one temporary line** so the package link is provable:
     `Text("girdle default \(FacetKernel.Pattern.defaultGirdleTargetFraction)")`, with
     `import FacetKernel` at the top. T2 deletes this whole file.
  8. **Confirm the project navigator shows `CuttingBench` as a synchronized folder**, not a plain
     yellow group (D13a). If it is a plain group, stop and tell the agent — every task after this one
     assumes files can be added and deleted on disk without a `project.pbxproj` edit.
  9. ⌘B, then ⌘R.
- **Done when:**
  - `CuttingBench/CuttingBench.xcodeproj/project.pbxproj` exists and contains
    `PBXFileSystemSynchronizedRootGroup` — the agent verifies this by grep, and stops if it is absent.
  - `CuttingBench/CuttingBench/ContentView.swift` and
    `CuttingBench/CuttingBench/CuttingBenchApp.swift` exist.
  - `xcodebuild -project CuttingBench/CuttingBench.xcodeproj -scheme CuttingBench -destination 'platform=macOS' build` succeeds.
  - `grep -c 'MACOSX_DEPLOYMENT_TARGET = 26' CuttingBench/CuttingBench.xcodeproj/project.pbxproj`
    returns a count above zero.
- **Do not:** touch Signing & Capabilities — leave App Sandbox at its default On (D13b); change the
  bundle identifier or the entitlements file; add a test target; add any package other than the local
  `Kernel/`; write or edit any file under `CuttingBench.xcodeproj` as the agent.
- **Verification handle** — `temporary` (the `Text` in step 7; `ContentView.swift` is deleted in T2):
  - **Where:** the app's single window on ⌘R, and Finder's Open-With menu for a pattern file.
  - **Positive:** ⌘R → the window reads `girdle default 0.04`, which is
    `Pattern.defaultGirdleTargetFraction` read live out of the linked `FacetKernel`. In Finder,
    right-click `Design/Patterns/Pattern-Easy-Octagon.json` ▸ Open With → **`CuttingBench` appears in
    the list.**
  - **Negative:** **double-click that same file → CuttingBench does *not* open it**; whatever already
    owns `.json` on this machine does. That is handler rank `Alternate` behaving as D6 decided, and it
    is the check that the app has not claimed every JSON file on the machine.
  - **Reads:** `Pattern.defaultGirdleTargetFraction` in
    `Kernel/Sources/FacetKernel/Pattern.swift:100`, and the `LSHandlerRank` entry in the target's Info
    settings. **T1 is the one task whose handle does not read agent-written code, because T1 writes
    none** — what it proves is that the package link and the type declaration are real.

Commit point:

```
2-cutting-bench-app-shell-1 T1: add the CuttingBench Xcode project

- macOS 26.0 app target, SwiftUI, App Sandbox at Xcode's default
- links the local Kernel package's FacetKernel library
- declares public.json with LSHandlerRank Alternate, so a pattern can be
  opened without claiming every JSON file on the machine
```

---

**T2 — The document opens a pattern file and reports what it decoded**

**First, settle two claims this plan could not settle by reading** — both are one-line checks, and
neither is a judgement call:

1. `NSOpenPanel.directoryURL` set to a path outside the App Sandbox container really does open the
   panel there. The panel runs outside the sandbox, so it should.
2. `NSDocumentController.shared.openDocument(withContentsOf:display:)` really does open a
   `DocumentGroup` document window.

**If either fails, stop and report per the protocol's §8.** Do not disable the App Sandbox, do not
subclass `NSDocumentController`, and do not seed `NSNavLastRootDirectory` — D7 and D8 rejected all
three by name.

- **Files:** `CuttingBench/CuttingBench/PatternDocument.swift` (new),
  `CuttingBench/CuttingBench/PatternsFolder.swift` (new),
  `CuttingBench/CuttingBench/CuttingBenchApp.swift` (replace the template's contents),
  `CuttingBench/CuttingBench/BenchWindow.swift` (new — the `VStack` with `StatusStripRegion` only),
  `CuttingBench/CuttingBench/BenchRegions.swift` (new — `StatusStripRegion` only),
  `CuttingBench/CuttingBench/ContentView.swift` (delete)
- **Done when:**
  - `xcodebuild … build` succeeds with no warnings in the `CuttingBench` target.
  - `xcrun swift-format lint --recursive --strict CuttingBench/CuttingBench` is clean.
  - `CuttingBench/CuttingBench/ContentView.swift` no longer exists.
  - `swift test --package-path Kernel --disable-sandbox` is green and
    `git status --short Kernel` reports nothing — this part changes no kernel code.
  - The verification handle below behaves exactly as written.
- **Do not:** build any of the other four regions — the window in this task is the status strip and
  nothing else, and T3 adds the rest; add an inspector, a table or a split view; serialise JSON by
  hand anywhere (D5); give `PatternDocument` any mutating method — nothing edits a pattern in this part.
- **Verification handle** — `permanent`:
  - **Where:** the document window's status strip, bottom edge. Leading text is the findings line;
    trailing text, behind `#if DEBUG`, is the document summary.
  - **Positive:** ⌘⇧O → the panel opens **showing `Design/Patterns/`**. Choose
    `Pattern-Rands-Cut-Corner-Rectangle.json` → the strip reads
    `Rand's Cut Corner Rectangle · finished · 12 tiers`. ⌘⇧O again, choose
    `Pattern-Easy-Octagon.json` → **a second window**, reading `Easy Octagon · finished · 6 tiers`.
    The first window still reads `Rand's Cut Corner Rectangle · finished · 12 tiers`, unchanged.
  - **Negative:** ⌘N → a new window whose summary reads **`no pattern`**, with the leading text still
    `No findings`. Then create a non-pattern file — `printf '{"a":1}' > /tmp/not-a-pattern.json` — and
    open it with ⌘⇧O: **an alert reading "This file is not a valid faceting pattern."** and **no new
    document window**, with both existing windows' summaries unchanged.
  - **Reads:** `PatternDocument.pattern` in `CuttingBench/CuttingBench/PatternDocument.swift`, and
    `patternsFolder` in `CuttingBench/CuttingBench/PatternsFolder.swift`.

Commit point:

```
2-cutting-bench-app-shell-1 T2: open a pattern into a document

- PatternDocument is a ReferenceFileDocument over Pattern?, decoded with
  JSONDecoder and written only through FacetKernel.encoded (ADR-0003)
- File > Open Pattern... starts in Design/Patterns/ via a #filePath-derived
  path; there is no public hook into DocumentGroup's own open panel
- a debug summary in the status strip reads name, state and tier count
```

---

**T3 — The window layout: five regions, present and empty**

- **Files:** `CuttingBench/CuttingBench/BenchWindow.swift` (edit — add the split, the inspector and the
  toolbar toggle around the status strip T2 landed),
  `CuttingBench/CuttingBench/BenchRegions.swift` (edit — add `ViewportRegion`, `ScrubberRegion`,
  `TierTableRegion`, `TierRow` and `InspectorRegion`)
- **Done when:**
  - `xcodebuild … build` succeeds with no warnings in the `CuttingBench` target.
  - `xcrun swift-format lint --recursive --strict CuttingBench/CuttingBench` is clean.
  - `grep -c 'Color(red:\|Color(\.sRGB\|#[0-9a-fA-F]\{6\}' CuttingBench/CuttingBench/*.swift` returns
    `0` for every file — every colour is a system semantic colour (D12).
  - `TierTableRegion` declares exactly seven `TableColumn`s, titled in this order: `Tier`, `Part`,
    `Angle`, `Indices`, `Meet`, `Wheel`, `Instructions` (D9).
  - `InspectorRegion` declares exactly five `GroupBox`es, titled in this order: `Pattern`, `Notes`,
    `Metrics`, `Light`, `Facet Count` (D9).
  - `ViewportRegion`'s body is one view and one label, with nothing drawn into it (D2).
  - The verification handle below behaves exactly as written.
- **Do not:** put anything real in any region — no tier rows read from `document.pattern`, no metrics,
  no findings count, no scrubber control, no `Canvas`, no `MTKView`; reorder the table columns or the
  inspector boxes; add a second inspector or a segmented picker to switch inspector sections, which U1
  rejected because it buys viewport area by hiding the tier table; add a preference, a Settings scene
  or a colour picker (D12); move the status strip under the inspector (D10).
- **Verification handle** — `permanent`:
  - **Where:** the document window, with `Design/Patterns/Pattern-Standard-Round-Brilliant.json` open
    via ⌘⇧O.
  - **Positive:** the window shows, all at once — a `Viewport` placeholder top-left, a `Scrubber` strip
    directly beneath it, the tier table across the bottom of the main area showing **exactly the seven
    headers `Tier Part Angle Indices Meet Wheel Instructions` over zero rows**, an inspector down the
    right edge with **five boxes in the order `Pattern`, `Notes`, `Metrics`, `Light`, `Facet Count`**,
    and the status strip along the bottom of the main area reading `No findings` at the leading edge
    and `Standard Round Brilliant "Classic" · finished · 7 tiers` at the trailing edge. Click the
    toolbar's sidebar-trailing button → **the inspector collapses and the tier table widens to the
    window edge.**
  - **Negative:** with the inspector collapsed, **the status strip stays at the bottom of the main area
    and the tier table still shows zero rows** — the seven headers are there and nothing has appeared
    under them, because nothing in this part reads the pattern into the table. Then switch System
    Settings ▸ Appearance to Dark: **every region's background and text follow**, with no region left
    on a light background. A region that stays light is a hardcoded colour and a defect (D12).
  - **Reads:** `TierTableRegion` and `InspectorRegion` in
    `CuttingBench/CuttingBench/BenchRegions.swift`, and the `.inspector` modifier and `inspectorShown`
    state in `CuttingBench/CuttingBench/BenchWindow.swift`.

Commit point:

```
2-cutting-bench-app-shell-1 T3: lay out the bench window

- viewport over scrubber, tier table across the bottom, collapsible
  inspector down the trailing edge, status strip as the main area's last row
- all five regions present and empty; the tier table lands its seven column
  headers and the inspector its five cards, in the sketch's order
- every colour is a system semantic colour, so dark mode needs no work
```

---

**T4 — Close out**

- **Delete the temporary handles:** T1's `Text("girdle default …")` was the only one, and it went with
  `ContentView.swift` in T2. **Confirm `CuttingBench/CuttingBench/ContentView.swift` does not exist and
  no file under `CuttingBench/CuttingBench/` contains the string `girdle default`.** T2's and T3's
  handles are `permanent` and stay.
- **Confirm every item in this plan's Deferred section has a ticket** in `Design/Tickets/` with
  `Status: untriaged`. The tickets are filed as each item is found, per the protocol's §4 — this is the
  check, not the filing. If Deferred is empty, there is nothing to check.
- **Report the untriaged ticket count** in `Design/Tickets/` as one line.
- `commit + push` with the message below.
- **Archive nothing, and close no ticket.** This is part 1 of three. The exploration
  `2-Cutting-Bench-App-Shell` is the source for parts 2 and 3 and stays live, and this plan stays in
  `Design/Plans/`. Part 3 runs the archive routine for the exploration, all three parts and every
  ticket. Do not touch `Design/Archived/ArchivedCatalog.md`.
- **Set this plan's `Status:` line** to `COMPLETED <yyyy-mm-dd>` once the owner signs off T3, leaving
  the file where it is.

Commit point:

```
2-cutting-bench-app-shell-1 T4: close out part 1

- the app launches, opens a pattern through its own Open dialog, and shows
  the five layout regions present and empty
- nothing archived: parts 2 and 3 still read the exploration
```

## Deferred

Empty at authoring. The executor appends adjacent problems it found and must not fix — and files each
as a ticket in `Design/Tickets/` immediately with `Status: untriaged`, per the protocol's §4.



