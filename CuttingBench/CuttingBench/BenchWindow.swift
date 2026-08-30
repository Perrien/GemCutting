import BenchGeometry
import FacetKernel
import SwiftUI

/// The layout root (D9, D10). One `VStack`: the split of viewport-plus-scrubber over tier table, then
/// the status strip. `.inspector` on the root content view puts the inspector down the trailing edge of
/// the whole window, so the status strip belongs to the main area rather than sitting under the
/// inspector.
struct BenchWindow: View {
  @ObservedObject var document: PatternDocument
  /// Stored rather than session state, so whether the inspector is open survives a relaunch. One
  /// setting for every bench window: a new document opens the way the last one was arranged.
  @AppStorage("inspectorShown") private var inspectorShown = true
  @State private var store = BenchSolidStore()
  @State private var findingsStore = BenchFindingsStore()
  /// Where a refused edit is shown and logged. One presenter for the window, so there is exactly one place
  /// a refusal can appear.
  @State private var refusals = RefusalPresenter()
  /// The window's own undo manager, which is what makes ⌘Z an edit's inverse rather than the document's.
  @Environment(\.undoManager) private var undoManager
  /// The camera, held as a reference (see `BenchCameraModel`) precisely so this body never reads
  /// it: the viewport region is the one reader, which is what keeps a drag from re-evaluating the
  /// tier table, the inspector and the strip. The handlers below write and read it outside body.
  @State private var camera = BenchCameraModel()
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
  /// The meet being built by clicking, or `nil` for no pick in progress. The solid and mesh are held
  /// with it: they are the intermediate solid before the picking tier, built once when the pick starts,
  /// and every click is tested against that same solid.
  @State private var pick: MeetPickSession?
  /// A tangent-ratio drag in flight, and the stone it is previewing. **Nothing here reaches the
  /// document** (D12): the viewport prefers a session's solid over the store's, so a preview needs no new
  /// machinery.
  @State private var tuning: TuningPreview?
  /// An angle being derived from two clicks, or `nil` for none.
  @State private var derive: AngleDerivation?
  /// Bumped whenever what the viewport draws changes — the store's own rebuilds and the pick's arrival
  /// and departure alike. **One counter with one owner**, because `MetalViewport` compares a single `Int`
  /// and two independent sources would collide.
  @State private var drawGeneration = 0

  /// A pick and the stone it is being picked against.
  struct MeetPickSession {
    var state: MeetPickState
    var frame: PlaybackFrame
  }

  /// A rescale being previewed. `lastSolve` and `lastFinished` are the whole of the throttle (D13): no
  /// further preview starts until at least as long as the last one took has passed, so a gesture can
  /// never queue solves it will not finish.
  struct TuningPreview {
    var handle: String
    var target: Double
    var frame: PlaybackFrame
    var lastSolve: Duration?
    var lastFinished: ContinuousClock.Instant?
  }

  /// A two-point derivation and the stone its clicks are tested against, which is the intermediate solid
  /// before the aimed tier — the same solid a meet pick on that tier would use.
  struct AngleDerivation {
    var tier: String
    var aimedStop: Int
    var frame: PlaybackFrame
    var state: MeetPickState
    /// The first of the two ends, once it is taken.
    var first: DerivationEnd?
  }

  var body: some View {
    VStack(spacing: 0) {
      VSplitView {
        VStack(spacing: 0) {
          ViewportRegion(
            mesh: drawnMesh,
            generation: drawGeneration,
            ghostMesh: ghostMesh,
            ghostGeneration: ghostGeneration,
            camera: camera,
            opacity: solidOpacity,
            highlightedPlaneIndex: selectedPlaneIndex,
            ringLabels: indexRingLabels(store.solid),
            meetDots: meetDots,
            meetWarning: selectedTier.map { readout.warningTiers.contains($0) } ?? false,
            pickMarkers: pick.map { meetPickMarkers($0.state, solid: $0.frame.solid) }
              ?? derive.map { meetPickMarkers($0.state, solid: $0.frame.solid) } ?? [],
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
          edit: edit,
          startPick: startPick(_:),
          startDerivation: startDerivation(_:aimedStop:),
          commitPercent: { tier, typed in
            edit("Change Meet") { setting(percent: typed, ofTier: tier, in: $0) }
          }
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
          pickPrompt: pick.map { meetPickPrompt($0.state, solid: $0.frame.solid) }
            ?? derive.map {
              angleDerivationPrompt(
                tier: $0.tier, aimedStop: $0.aimedStop, pointsTaken: $0.first == nil ? 0 : 1,
                stage: $0.state.stage, solid: $0.frame.solid)
            },
          cancelPick: endPick,
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
          findings: readout,
          pickPrompt: pick.map { meetPickPrompt($0.state, solid: $0.frame.solid) }
            ?? derive.map {
              angleDerivationPrompt(
                tier: $0.tier, aimedStop: $0.aimedStop, pointsTaken: $0.first == nil ? 0 : 1,
                stage: $0.state.stage, solid: $0.frame.solid)
            },
          cancelPick: endPick)
      #endif
    }
    .frame(minWidth: 900, minHeight: 600)
    // Invisible. Reaches the AppKit window and split views under this hierarchy and turns on their
    // per-name layout autosaving, which is the whole of how the window remembers its frame and its
    // dividers (see `BenchLayoutMemory.swift`).
    .background(LayoutMemory())
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
        edit: edit,
        setState: setState(_:),
        selectedTier: selectedTier,
        tuningTarget: tuning?.target,
        tuningDragEnabled: pick == nil && store.granularity == nil,
        commitTuning: commitTuning,
        tuningDragChanged: tuningDragChanged(_:),
        tuningDragEnded: tuningDragEnded
      )
      .inspectorColumnWidth(min: 260, ideal: 300, max: 420)
    }
    .toolbar {
      Button {
        camera.state = .faceUp
      } label: {
        Label("Face Up", systemImage: "arrow.down.to.line")
      }
      Button {
        camera.state = .faceDown
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
    // The menu bar cannot reach the focused document, and the turn needs this window's undo manager as
    // well as its draft — so the window publishes the action and the command calls it.
    .focusedSceneValue(\.turnAQuarter, turnAQuarter)
    // The store is driven from here rather than from `body`'s own evaluation, so nothing mutates
    // observable state during a view update.
    .onChange(of: document.pattern, initial: true) { rebuild() }
    // What the viewport draws follows the store's own rebuilds as well as the pick's arrival and
    // departure, and one counter carries both.
    .onChange(of: store.generation) { drawGeneration += 1 }
  }

  /// The solid on screen: the pick's intermediate stone while one is running, the tuning preview's while
  /// a grip is held, and the store's otherwise. The grip is disabled during a pick (D14), so the order
  /// only fixes what is already exclusive.
  private var drawnSolid: BenchSolid {
    pick?.frame.solid ?? derive?.frame.solid ?? tuning?.frame.solid ?? store.solid
  }
  private var drawnMesh: SolidMesh {
    pick?.frame.mesh ?? derive?.frame.mesh ?? tuning?.frame.mesh ?? store.mesh
  }

  /// The finished stone, drawn in edges only over the intermediate solid, and nothing when neither a pick
  /// nor a derivation runs. **The tuning preview shows no ghost**: it is the whole stone already.
  private var ghostMesh: SolidMesh? { pick == nil && derive == nil ? nil : store.fullMesh }
  /// A counter that changes whenever `ghostMesh` does: with the finished stone itself, **and** with the
  /// pick's arrival and departure, which `fullGeneration` cannot see because starting a pick rebuilds no
  /// stone. Doubling leaves the low bit for the pick, so no two states of the pair collide.
  private var ghostGeneration: Int {
    2 * store.fullGeneration + (pick == nil && derive == nil ? 0 : 1)
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

  /// The `state` switch. **The one check in this app that blocks rather than reports** (D8): everywhere
  /// else the author is mid-work, here they are asserting something about the result.
  ///
  /// Going back to `in progress` claims nothing, so it is applied without a check (D13). The refusal goes
  /// through the same presenter every other refused edit does, which is what puts it in the unified log.
  private func setState(_ state: PatternState) {
    if state == .finished,
      let refusal = finishRefusal(draft: document.draft, declaredFacets: declaredFacets)
    {
      refusals.present(refusal)
      return
    }
    edit("Change State", { setting(state: state, in: $0) })
  }

  /// **Pattern ▸ Turn a Quarter Turn.** One undoable action, no options and no dialog: there is exactly
  /// one rotation available, so there is nothing to configure (D19).
  private func turnAQuarter() {
    edit("Turn a Quarter Turn") { turningAQuarter($0) }
  }

  /// The Tuning card's field. One `DraftChange` for the whole side, so it undoes in one step (D9).
  private func commitTuning(_ typed: String) -> Bool {
    guard let selectedTier else { return false }
    return edit("Tune Side") { rescaling(handle: selectedTier, toTyped: typed, in: $0) }
  }

  /// One step of a tuning drag: hold the target, then preview if the throttle allows it (D13).
  private func tuningDragChanged(_ target: Double) {
    guard let handle = selectedTier else { return }
    if tuning == nil {
      // The store's own frame to start from, so the viewport does not blink at the first change.
      tuning = TuningPreview(
        handle: handle,
        target: target,
        frame: PlaybackFrame(solid: store.solid, mesh: store.mesh),
        lastSolve: nil,
        lastFinished: nil)
    }
    tuning?.target = target
    previewTuning()
  }

  /// The drag released: commit the target it reached, then drop the preview. A drag that ended where it
  /// started commits a draft equal to the current one, which registers no undo entry — that is `apply`'s
  /// existing rule, not a new one.
  private func tuningDragEnded() {
    if let session = tuning {
      _ = commitTuning(String(format: "%.2f", session.target))
    }
    tuning = nil
    drawGeneration += 1
  }

  /// The preview solve, or nothing when the last one has not yet earned another (D13).
  ///
  /// No timer, no background task and no queue: the throttle is entirely what the previous solve cost.
  private func previewTuning() {
    guard let session = tuning else { return }
    if let finished = session.lastFinished, let cost = session.lastSolve,
      ContinuousClock.now - finished < cost
    {
      return
    }
    // A refused target previews nothing and leaves the frame as it is — the card is already showing the
    // sentence.
    guard
      case .success(let previewDraft) = rescaling(
        handle: session.handle, toAngle: session.target, in: document.draft),
      let pattern = previewDraft.displayPattern
    else { return }

    var frame: PlaybackFrame?
    let cost = ContinuousClock().measure {
      let solid = benchSolid(for: pattern)
      frame = PlaybackFrame(solid: solid, mesh: solidMesh(solid))
    }
    guard let frame else { return }
    tuning?.frame = frame
    tuning?.lastSolve = cost
    tuning?.lastFinished = ContinuousClock.now
    drawGeneration += 1
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
    // A plane index means nothing across a rebuild, so a pick held across one would be clicking a solid
    // that no longer exists — the same reason the facet selection goes. A derivation is tested against
    // an intermediate solid the same way, so it goes with it.
    pick = nil
    derive = nil
    // A committed drag lands here too: the commit changes the document, which rebuilds.
    tuning = nil
    drawGeneration += 1
    // Last, because it reads the solid the store has just produced.
    findingsStore.rebuild(pattern: document.pattern, solid: store.solid)
  }

  /// **Pick in viewport…** on one tier's Meet menu. Not an edit: starting a pick changes no draft, so it
  /// registers no undo entry and passes through no funnel.
  ///
  /// The intermediate solid is built once, here, and every click of this pick is tested against it.
  private func startPick(_ tier: String) {
    let solid = intermediateBenchSolid(before: tier, draft: document.draft, full: store.full)
    pick = MeetPickSession(
      state: MeetPickState(tier: tier),
      frame: PlaybackFrame(solid: solid, mesh: solidMesh(solid)))
    drawGeneration += 1
    // All three describe the solid that was on screen a moment ago.
    selectedPlaneIndex = nil
    selectedFacetLabel = nil
    probe = nil
  }

  /// **Derive angle from two points… ▸ aim <tier>@<stop>** on one tier's Meet menu. Not an edit: aiming
  /// changes no draft, so it registers no undo entry and passes through no funnel — the same rule
  /// `startPick` states.
  ///
  /// The clicks are tested against the intermediate solid before the aimed tier, which is the solid a
  /// meet pick on that tier would use, built once here.
  private func startDerivation(_ tier: String, aimedStop: Int) {
    let solid = intermediateBenchSolid(before: tier, draft: document.draft, full: store.full)
    // A pick and a derivation are exclusive: each start clears the other, and a tuning preview cannot
    // survive a viewport that now belongs to the clicks.
    pick = nil
    tuning = nil
    derive = AngleDerivation(
      tier: tier,
      aimedStop: aimedStop,
      frame: PlaybackFrame(solid: solid, mesh: solidMesh(solid)),
      state: MeetPickState(tier: tier))
    drawGeneration += 1
    // All three describe the solid that was on screen a moment ago.
    selectedPlaneIndex = nil
    selectedFacetLabel = nil
    probe = nil
  }

  /// The Cancel button, and every path that ends a pick — or a derivation, which the same button ends
  /// because only one of the two is ever running. The same three clears, for the same reason.
  private func endPick() {
    pick = nil
    derive = nil
    drawGeneration += 1
    selectedPlaneIndex = nil
    selectedFacetLabel = nil
    probe = nil
  }

  /// One of the two points arriving. The first is held and the stage reset for the second; the second
  /// derives the angle and writes it together with the meet, in one undoable step.
  private func completeDerivation(_ session: AngleDerivation, end: DerivationEnd) {
    guard let first = session.first else {
      derive?.first = end
      derive?.state = MeetPickState(tier: session.tier)
      return
    }
    // A tier the draft no longer carries: there is nothing to write to, and nothing is written.
    guard let tier = document.draft.tiers.first(where: { $0.tier == session.tier }) else {
      endPick()
      return
    }
    let derived = derivedAngle(
      ofTier: session.tier,
      aimedStop: session.aimedStop,
      wheel: document.draft.wheel(of: tier),
      part: tier.part,
      stops: tier.indices,
      first: first,
      second: end)
    switch derived {
    case .success(let angle):
      _ = edit("Derive Angle") { setting(derived: angle, ofTier: session.tier, in: $0) }
      endPick()
    case .failure(let refusal):
      refusals.present(refusal)
      // **The first end is kept** and only the stage resets, so one more click retries the second point
      // — the same kindness the picker gives a mis-click. Cancel ends the session.
      derive?.state = MeetPickState(tier: session.tier)
    }
  }

  /// The facet the renderer highlights while a pick runs: the last one clicked, and nothing at `empty`.
  private func highlightedPlane(of state: MeetPickState) -> Int? {
    switch state.stage {
    case .empty: nil
    case .oneFacet(let plane): plane
    case .edge(let planes, _): planes.last
    case .point(let planes, _, _): planes.last
    case .anchored(let planes, _, _, _): planes.last
    }
  }

  /// Direct manipulation: the stone follows the pointer, so the camera goes the other way — a drag to
  /// the right turns the near side of the stone to the right, which moves the camera left around it
  /// (D4).
  private func orbit(dx: CGFloat, dy: CGFloat) {
    camera.state.orbit(dxPoints: Float(-dx), dyPoints: Float(-dy))
  }

  /// A click, unprojected to a world ray and put to the slab test. **No y flip**: an `NSView` is y-up
  /// unless `isFlipped` says otherwise and `MTKView` does not, so its coordinates and Metal's NDC
  /// already agree (D13). A click that misses the solid clears the selection.
  private func pick(at point: CGPoint, in size: CGSize) {
    guard size.width > 0, size.height > 0 else { return }

    // **Before the meet pick's branch**, because the two are exclusive and a derivation is the newer
    // state. A click during a derivation belongs to the derivation.
    if let session = derive {
      // The solid on screen, which is the one the click hit and the one the picker names facets on.
      let solid = drawnSolid
      let hit = meetPickHit(
        solid,
        click: (x: Double(point.x), y: Double(point.y)),
        size: (width: Double(size.width), height: Double(size.height)),
        camera: camera.state)
      switch advancing(session.state, hit: hit, solid: solid, draft: document.draft) {
      case .advanced(let next):
        derive?.state = next
        // The highlight follows the last facet clicked, in the solid on screen — which is the pick's.
        selectedPlaneIndex = highlightedPlane(of: next)
        selectedFacetLabel = selectedPlaneIndex.flatMap { solid.origin[$0] }.map(facetLabel)
      case .complete(let meet, let point):
        completeDerivation(session, end: DerivationEnd(meet: meet, point: point))
      case .refused(let refusal):
        refusals.present(refusal)
      case .cleared:
        endPick()
      }
      return
    }

    if let session = pick {
      // The solid on screen, which is the one the click hit and the one the pick names facets on.
      let solid = drawnSolid
      let hit = meetPickHit(
        solid,
        click: (x: Double(point.x), y: Double(point.y)),
        size: (width: Double(size.width), height: Double(size.height)),
        camera: camera.state)
      switch advancing(session.state, hit: hit, solid: solid, draft: document.draft) {
      case .advanced(let next):
        pick?.state = next
        // The highlight follows the last facet clicked, in the solid on screen — which is the pick's.
        selectedPlaneIndex = highlightedPlane(of: next)
        selectedFacetLabel = selectedPlaneIndex.flatMap { solid.origin[$0] }.map(facetLabel)
      case .complete(let meet, _):
        _ = edit("Change Meet") { setting(meet: meet, ofTier: session.state.tier, in: $0) }
        endPick()
      case .refused(let refusal):
        refusals.present(refusal)
      case .cleared:
        endPick()
      }
      // **Load-bearing**: while a pick is in progress the facet selection and the probe path below do not
      // run. The click belongs to the pick.
      return
    }

    let ray = benchRay(
      ndcX: Float(2 * point.x / size.width - 1),
      ndcY: Float(2 * point.y / size.height - 1),
      aspect: Float(size.width / size.height),
      camera: camera.state)
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
