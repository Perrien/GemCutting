import BenchGeometry
import SwiftUI

/// A meet point's colour. **Never the only distinction** — every dot carries its label too, so the
/// correspondence between viewport and table survives a screenshot and a colour-blind reader.
///
/// Neither the accent colour nor orange: those are the cut facets' and the picked facet's in the
/// renderer, and a meet point is neither.
func meetDotColor(_ role: MeetPointRole, warning: Bool) -> Color {
  guard !warning else { return .red }
  switch role {
  case .endpointA: return .teal
  case .endpointB: return .purple
  case .anchored, .vertex: return .yellow
  }
}

/// The selected tier's named points, as SwiftUI over the Metal view — the same mechanism and the same
/// matrices as the index ring, so a dot cannot disagree with the solid about where a point is.
///
/// **No occlusion test.** A meet is a claim about the stone as it stood when that tier was cut, so a
/// named point is routinely inside the finished solid, cut away by a later tier, or off the solid
/// altogether — and that last case is the fault worth seeing. The opacity slider is how the owner looks
/// inside.
///
/// `.allowsHitTesting(false)`, for the same reason the ring has it: the dots must not eat clicks meant
/// for the facet under them.
struct MeetPointOverlay: View {
  let dots: [MeetPointDot]
  let camera: BenchCameraState
  let warning: Bool

  var body: some View {
    GeometryReader { proxy in
      let size = proxy.size
      let aspect = size.height > 0 ? Float(size.width / size.height) : 1
      ForEach(dots) { dot in
        if let world = dot.world,
          let point = benchScreenPoint(world, aspect: aspect, camera: camera)
        {
          // The **circle** is what `.position` places, because `.position` centres the view it is applied
          // to: positioning the circle-and-label pair as one would put the dot half the label's width to
          // the left of the point it names. The label rides in an overlay, which does not enter the
          // circle's own layout.
          Circle()
            .fill(meetDotColor(dot.role, warning: warning))
            .frame(width: 9, height: 9)
            .overlay(alignment: .leading) {
              Text(dot.label)
                .font(.caption2.weight(.semibold))
                .fixedSize()
                .offset(x: 12)
            }
            .position(x: CGFloat(point.x) * size.width, y: CGFloat(point.y) * size.height)
        }
      }
    }
    .allowsHitTesting(false)
  }
}
