import BenchGeometry
import MetalKit
import SwiftUI

/// `MTKView` does not redraw on an appearance change by itself, and every colour is resolved per draw
/// (D21), so without this the solid keeps yesterday's colours until something else invalidates it.
final class BenchMetalView: MTKView {
  override func viewDidChangeEffectiveAppearance() {
    super.viewDidChangeEffectiveAppearance()
    needsDisplay = true
  }
}

/// The bridge from SwiftUI to the `MTKView`. The view is redrawn on demand rather than at 60 Hz —
/// nothing in this part animates (D13).
struct MetalViewport: NSViewRepresentable {
  let mesh: SolidMesh
  /// Bumped by the store on every rebuild. Comparing this beats comparing two arrays of vertices.
  let generation: Int

  final class Coordinator {
    var renderer: BenchRenderer?
    var uploaded: Int?
  }

  func makeCoordinator() -> Coordinator { Coordinator() }

  func makeNSView(context: Context) -> BenchMetalView {
    let view = BenchMetalView(frame: .zero, device: nil)
    view.colorPixelFormat = .bgra8Unorm
    view.depthStencilPixelFormat = .depth32Float
    view.clearDepth = 1.0
    view.enableSetNeedsDisplay = true
    view.isPaused = true

    let renderer = BenchRenderer(view: view)
    view.device = renderer.device
    view.delegate = renderer
    context.coordinator.renderer = renderer
    return view
  }

  func updateNSView(_ view: BenchMetalView, context: Context) {
    guard context.coordinator.uploaded != generation else { return }
    context.coordinator.renderer?.setMesh(mesh)
    context.coordinator.uploaded = generation
    view.needsDisplay = true
  }
}
