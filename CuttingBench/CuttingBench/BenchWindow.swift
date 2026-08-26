import BenchGeometry
import FacetKernel
import SwiftUI

/// The layout root (D9, D10). One `VStack`: the split of viewport-plus-scrubber over tier table, then
/// the status strip. `.inspector` on the root content view puts the inspector down the trailing edge of
/// the whole window, so the status strip belongs to the main area rather than sitting under the
/// inspector.
struct BenchWindow: View {
  @ObservedObject var document: PatternDocument
  @State private var inspectorShown = true
  @State private var store = BenchSolidStore()
  @State private var findingsStore = BenchFindingsStore()
  /// Where a refused edit is shown and logged. One presenter for the window, so there is exactly one place
  /// a refusal can appear.
  @State private var refusals = RefusalPresenter()
  /// The window's own undo manager, which is what makes ⌘Z an edit's inverse rather than the document's.
  @Environment(\.undoManager) private var undoManager
  @State private var camera = BenchCameraState.threeQuarter
  /// How opaque the solid is drawn, `0...1`. Not persisted: a document reopens fully opaque (D6).
  @State private var solidOpacity = 1.0
  /// The picked facet, as the plane the renderer highlights and the name the strip reads. Two
  /// optionals rather than one tuple, because a tuple is not `Equatable` (D11, D12).
  @State private var selectedPlaneIndex: Int?
  @State private var selectedFacetLabel: String?
  /// The count a printed sheet declares, typed at transcription time. Session state, never persisted: a
  /// pattern invented from scratch has no declared count, and a permanent header field would carry a
  /// one-time claim forever.
  @State private var declaredFacets = ""
  /// The tier whose meet points are drawn, as the table's own selection. A view state and nothing more:
  /// it is not persisted and nothing is edited through it.
  @State private var selectedTier: String?
  /// Whether a viewport click also traces a ray. A mode rather than a side effect of picking, so the path
  /// has a way to be off.
  @State private var probeOn = false
  /// The last traced path. Cleared with the solid, because a path is a claim about one solid and drawing it
  /// over the next one would be a picture of a stone that is not there.
  @State private var probe: ProbeReadout?

  var body: some View {
    VStack(spacing: 0) {
      VSplitView {
        VStack(spacing: 0) {
          ViewportRegion(
            mesh: store.mesh,
            generation: store.generation,
            camera: camera,
            opacity: solidOpacity,
            highlightedPlaneIndex: selectedPlaneIndex,
            ringLabels: indexRingLabels(store.solid),
            meetDots: meetDots,
            meetWarning: selectedTier.map { readout.warningTiers.contains($0) } ?? false,
            probe: probe,
            onOrbit: orbit(dx:dy:),
            onPick: pick(at:in:)
          )
          .frame(minHeight: 240)
          Divider()
          ScrubberRegion(
            steps: store.steps,
            stepIndex: store.stepIndex,
            granularity: store.granularity,
            progress: store.progress,
            canPlay: !store.full.tiers.isEmpty,
            onGranularity: setGranularity(_:),
            onStep: setStep(_:))
        }
        TierTableRegion(
          rows: tierTableRows(draft: document.draft, solid: store.solid, light: light),
          selection: $selectedTier,
          findings: readout,
          draft: document.draft,
          edit: edit
        )
        .frame(minHeight: 180)
      }
      Divider()
      #if DEBUG
        StatusStripRegion(
          pattern: document.pattern,
          solid: store.solid,
          selectedFacet: selectedFacetLabel,
          findings: readout,
          cachedFrames: store.cachedFrameCount,
          stepTotal: store.steps.count,
          draftLine: draftSummary(document.draft),
          tierChecks: findingsStore.tierChecksRun,
          geometricPasses: findingsStore.geometricPassesRun,
          isArmed: findingsStore.isArmed)
      #else
        StatusStripRegion(
          pattern: document.pattern,
          solid: store.solid,
          selectedFacet: selectedFacetLabel,
          findings: readout)
      #endif
    }
    .frame(minWidth: 900, minHeight: 600)
    .alert("Edit refused", isPresented: refusals.isPresented) {
      Button("OK") { refusals.dismiss() }
    } message: {
      Text(refusals.message ?? "")
    }
    .inspector(isPresented: $inspectorShown) {
      InspectorRegion(
        pattern: document.pattern,
        solid: store.solid,
        declaredFacets: $declaredFacets,
        probeOn: $probeOn,
        probe: probe,
        draft: document.draft,
        edit: edit
      )
      .inspectorColumnWidth(min: 260, ideal: 300, max: 420)
    }
    .toolbar {
      Button {
        camera = .faceUp
      } label: {
        Label("Face Up", systemImage: "arrow.down.to.line")
      }
      Button {
        camera = .faceDown
      } label: {
        Label("Face Down", systemImage: "arrow.up.to.line")
      }
      Slider(value: $solidOpacity, in: 0...1) { Text("Opacity") }
        .frame(width: 140)
      Button {
        inspectorShown.toggle()
      } label: {
        Label("Inspector", systemImage: "sidebar.trailing")
      }
    }
    .navigationTitle(document.pattern?.name ?? "Untitled")
    // The store is driven from here rather than from `body`'s own evaluation, so nothing mutates
    // observable state during a view update.
    .onChange(of: document.pattern, initial: true) { rebuild() }
  }

  /// Recomputed per body pass rather than cached: it is string formatting over at most a few dozen
  /// findings, and a cache would be a second place the count could be wrong.
  private var readout: FindingsReadout {
    findingsReadout(
      pattern: document.pattern,
      solid: store.solid,
      structural: findingsStore.structural,
      geometric: findingsStore.geometric,
      isChecking: findingsStore.isChecking)
  }

  /// The selected tier's named points, or none when nothing is selected.
  private var meetDots: [MeetPointDot] {
    guard let selectedTier else { return [] }
    return meetPointDots(ofTier: selectedTier, pattern: document.pattern, solid: store.solid)
  }

  /// Recomputed per body pass like `readout`, and for the same reason: it is string formatting over a
  /// handful of tiers, and a cache would be a second place the critical angle could be wrong.
  private var light: LightReadout {
    // The empty override is the ordinary case, and now the only one: the card reads the pattern's own
    // authored refractive index.
    lightReadout(pattern: document.pattern, solid: store.solid, riOverride: "")
  }

  /// A new document: one solve, and playback back to off.
  private func rebuild() {
    store.setPattern(document.pattern)
    afterSolidChanged()
  }

  /// Every edit in the window goes through here: apply it, register its undo, and present the refusal if
  /// there is one. Returns whether the edit was accepted, which is what an editable cell reverts on.
  @discardableResult
  private func edit(_ actionName: String, _ change: DraftChange) -> Bool {
    guard let refusal = document.apply(change, undoManager: undoManager, actionName: actionName)
    else {
      return true
    }
    refusals.present(refusal)
    return false
  }

  private func setGranularity(_ granularity: PlaybackGranularity?) {
    store.setGranularity(granularity)
    afterSolidChanged()
  }

  private func setStep(_ index: Int) {
    store.setStepIndex(index)
    afterSolidChanged()
  }

  /// The facet selection goes, the tier selection stays. A plane index means nothing across a rebuild —
  /// the rough's eighteen come and go and the cut planes are re-expanded — so a kept index would leave
  /// the highlight on an unrelated facet and the strip reading the old name. A tier *label* survives, and
  /// keeping it is what lets the owner scrub and watch one tier's meet dots arrive. A label the new
  /// pattern does not carry yields no dots, so a stale selection is inert rather than wrong.
  private func afterSolidChanged() {
    selectedPlaneIndex = nil
    selectedFacetLabel = nil
    // The path goes with the solid it was traced through. The Probe *mode* stays on: the owner turned it
    // on, and a rebuild is not them turning it off.
    probe = nil
    // Last, because it reads the solid the store has just produced.
    findingsStore.rebuild(pattern: document.pattern, solid: store.solid)
  }

  /// Direct manipulation: the stone follows the pointer, so the camera goes the other way — a drag to
  /// the right turns the near side of the stone to the right, which moves the camera left around it
  /// (D4).
  private func orbit(dx: CGFloat, dy: CGFloat) {
    camera.orbit(dxPoints: Float(-dx), dyPoints: Float(-dy))
  }

  /// A click, unprojected to a world ray and put to the slab test. **No y flip**: an `NSView` is y-up
  /// unless `isFlipped` says otherwise and `MTKView` does not, so its coordinates and Metal's NDC
  /// already agree (D13). A click that misses the solid clears the selection.
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

    // The pick above is unchanged and always happens; the trace is the mode on top of it. Straight down
    // from the point that was clicked, which is how windowing is judged — looking at a face-up stone from
    // above. A click that misses the solid clears the path, which is right: the owner clicked away from
    // the stone.
    guard probeOn, let hit,
      let ri = effectiveRefractiveIndex(pattern: document.pattern, override: "")
    else {
      probe = nil
      return
    }
    probe = probeTrace(store.solid, ri: ri, from: hit.point)
  }
}
