import BenchGeometry
import SwiftUI

/// The index stops around the rim, as SwiftUI text over the Metal view (D16, U4). Positioned through
/// the same pure matrices the renderer uses, so it cannot disagree with the solid about where the rim
/// is. `.allowsHitTesting(false)` is load-bearing: without it the numbers eat the clicks meant for the
/// facet under them.
struct IndexRingOverlay: View {
  let labels: [IndexRingLabel]
  let camera: BenchCameraState

  var body: some View {
    GeometryReader { proxy in
      let size = proxy.size
      let aspect = size.height > 0 ? Float(size.width / size.height) : 1
      ForEach(labels) { label in
        if let point = benchScreenPoint(label.anchor, aspect: aspect, camera: camera) {
          Text(label.text)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .position(x: CGFloat(point.x) * size.width, y: CGFloat(point.y) * size.height)
        }
      }
    }
    .allowsHitTesting(false)
    .opacity(indexRingAlpha(camera))
  }
}
