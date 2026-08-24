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
            onOrbit: orbit(dx:dy:),
            onPick: { _, _ in }
          )
          .frame(minHeight: 240)
          Divider()
          ScrubberRegion()
        }
        TierTableRegion()
          .frame(minHeight: 140)
      }
      Divider()
      #if DEBUG
        StatusStripRegion(pattern: document.pattern, solid: store.solid, tierLimit: $tierLimit)
      #else
        StatusStripRegion(pattern: document.pattern, solid: store.solid)
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
}
