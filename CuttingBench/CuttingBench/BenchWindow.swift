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
  @State private var camera = BenchCameraState.threeQuarter
  /// How opaque the solid is drawn, `0...1`. Not persisted: a document reopens fully opaque (D6).
  @State private var solidOpacity = 1.0
  /// The picked facet, as the plane the renderer highlights and the name the strip reads. Two
  /// optionals rather than one tuple, because a tuple is not `Equatable` (D11, D12).
  @State private var selectedPlaneIndex: Int?
  @State private var selectedFacetLabel: String?
  #if DEBUG
    /// The tier-limit diagnostic. `nil` is every tier, which is the default and the shipped behaviour.
    @State private var tierLimit: Int?
  #endif

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
            onOrbit: orbit(dx:dy:),
            onPick: pick(at:in:)
          )
          .frame(minHeight: 240)
          Divider()
          ScrubberRegion()
        }
        TierTableRegion(rows: tierTableRows(pattern: document.pattern, solid: store.solid))
          .frame(minHeight: 140)
      }
      Divider()
      #if DEBUG
        StatusStripRegion(
          pattern: document.pattern,
          solid: store.solid,
          selectedFacet: selectedFacetLabel,
          tierLimit: $tierLimit)
      #else
        StatusStripRegion(
          pattern: document.pattern,
          solid: store.solid,
          selectedFacet: selectedFacetLabel)
      #endif
    }
    .frame(minWidth: 900, minHeight: 600)
    .inspector(isPresented: $inspectorShown) {
      InspectorRegion()
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
    #if DEBUG
      .onChange(of: tierLimit) { rebuild() }
    #endif
  }

  private func rebuild() {
    // A plane index means nothing across a rebuild: the tier limit decides how many solved planes are
    // appended after the rough's eighteen, so keeping the selection would leave the highlight on an
    // unrelated plane and the strip reading the old name. Opening a different pattern is the same case.
    selectedPlaneIndex = nil
    selectedFacetLabel = nil
    #if DEBUG
      store.rebuildIfNeeded(pattern: document.pattern, tierLimit: tierLimit)
    #else
      store.rebuildIfNeeded(pattern: document.pattern, tierLimit: nil)
    #endif
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
  }
}
