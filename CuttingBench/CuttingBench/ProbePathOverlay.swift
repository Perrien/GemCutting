import BenchGeometry
import SwiftUI

/// The probe's path over the viewport — the same mechanism and the same matrices as the meet-point dots,
/// so a segment cannot disagree with the solid about where it runs and the renderer is not touched.
///
/// **No occlusion test**, for the reason the meet dots have none: the path runs inside the stone by
/// definition, and the opacity slider is how the owner looks in.
///
/// `.allowsHitTesting(false)`, like the other two overlays: the path must not eat the clicks that drive
/// it.
struct ProbePathOverlay: View {
  /// The last traced path, or `nil` for none — and then nothing is drawn at all.
  let probe: ProbeReadout?
  let camera: BenchCameraState

  var body: some View {
    GeometryReader { proxy in
      let size = proxy.size
      let aspect = size.height > 0 ? Float(size.width / size.height) : 1
      if let probe, !probe.legs.isEmpty {
        // A point behind the camera has no screen position, and the projection already answers that —
        // its leg is dropped here rather than second-guessed.
        let points = probe.legs.compactMap { screenPoint($0.world, aspect: aspect, size: size) }

        // Where the ray came from: straight down onto a face-up stone, so the stub is outside the solid
        // and dashed to say so.
        if let stub = probe.entryStub.flatMap({ screenPoint($0, aspect: aspect, size: size) }),
          let first = points.first
        {
          Path { path in
            path.move(to: stub)
            path.addLine(to: first)
          }
          .stroke(Color.green, style: stubStroke)
        }

        // Solid inside the stone: one line through every leg, in the order the ray reached them.
        Path { path in path.addLines(points) }
          .stroke(Color.green, lineWidth: 2)

        // Where the ray went. **Red only when it left through a downward-facing facet** — that is the
        // window the probe exists to find. A ray returning through the crown or the table has left too,
        // and that is the stone working, so it draws green.
        if let stub = probe.exitStub.flatMap({ screenPoint($0, aspect: aspect, size: size) }),
          let last = points.last
        {
          Path { path in
            path.move(to: last)
            path.addLine(to: stub)
          }
          .stroke(probe.leaked ? Color.red : Color.green, style: stubStroke)
        }

        ForEach(probe.legs) { leg in
          if let point = screenPoint(leg.world, aspect: aspect, size: size) {
            // The **circle** is what `.position` places, because `.position` centres the view it is
            // applied to: positioning the circle-and-label pair as one would put the chip half the
            // label's width off the point it names. The label rides in an overlay, which does not enter
            // the circle's own layout.
            Circle()
              .fill(Color.green)
              .frame(width: 9, height: 9)
              .overlay(alignment: .leading) {
                Text(leg.label)
                  .font(.caption2.weight(.semibold))
                  .fixedSize()
                  .offset(x: 12)
              }
              .position(point)
          }
        }
      }
    }
    .allowsHitTesting(false)
  }

  /// Both stubs, so the two can never drift apart in width or in dash.
  private var stubStroke: StrokeStyle { StrokeStyle(lineWidth: 1.5, dash: [4, 3]) }

  /// A world point in the proxy's own space, or `nil` when it is behind the camera.
  private func screenPoint(_ world: SIMD3<Float>, aspect: Float, size: CGSize) -> CGPoint? {
    guard let point = benchScreenPoint(world, aspect: aspect, camera: camera) else { return nil }
    return CGPoint(x: CGFloat(point.x) * size.width, y: CGFloat(point.y) * size.height)
  }
}
