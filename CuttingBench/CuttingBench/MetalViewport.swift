import AppKit
import BenchGeometry
import MetalKit
import SwiftUI

/// The `MTKView` itself. Two jobs beyond drawing: `MTKView` does not redraw on an appearance change by
/// itself and every colour is resolved per draw (D21), so without `viewDidChangeEffectiveAppearance` the
/// solid keeps yesterday's colours until something else invalidates it; and the mouse handling, which
/// AppKit gives in view coordinates and SwiftUI would not.
final class BenchMetalView: MTKView {
  /// A drag this short is a click, not an orbit.
  static let clickSlopPoints: CGFloat = 3

  var onOrbit: ((CGFloat, CGFloat) -> Void)?
  var onPick: ((CGPoint, CGSize) -> Void)?
  private var lastPoint: CGPoint?
  private var dragDistance: CGFloat = 0

  override func viewDidChangeEffectiveAppearance() {
    super.viewDidChangeEffectiveAppearance()
    needsDisplay = true
  }

  // MARK: - The mouse
  //
  // The drag delta comes from successive `locationInWindow` conversions, never from `NSEvent.deltaY`: an
  // `NSView`'s coordinates are unambiguously y-up, so dragging up is a positive `dy` and raises the
  // elevation, while `deltaY`'s sign convention is precisely the thing that would otherwise have to be
  // guessed at.

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
}

/// The bridge from SwiftUI to the `MTKView`. The view is redrawn on demand rather than at 60 Hz —
/// nothing in this part animates, and the snaps are instant (D5, D13).
struct MetalViewport: NSViewRepresentable {
  let mesh: SolidMesh
  /// Bumped by the store on every rebuild. Comparing this beats comparing two arrays of vertices.
  let generation: Int
  let camera: BenchCameraState
  let opacity: Double
  let onOrbit: (CGFloat, CGFloat) -> Void
  let onPick: (CGPoint, CGSize) -> Void

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
    view.needsDisplay = true
  }
}
