import BenchGeometry
import SwiftUI

/// A pick marker's colour. **Never the only distinction** — every marker carries its label too, and a
/// corner is a ring rather than a chip.
///
/// Neither the accent colour, nor orange, nor any of the four meet-dot colours: those are the cut
/// facets', the highlighted facet's, and a stored meet's points'. One blue for all three kinds, because
/// they are all one thing the author is doing now.
func meetPickMarkerColor(_ kind: MeetPickMarker.Kind) -> Color {
  switch kind {
  case .named, .candidate, .corner: return .blue
  }
}

/// What the pick has clicked, as SwiftUI over the Metal view — the same mechanism and the same matrices
/// as the index ring and the meet dots, so a chip cannot disagree with the solid about where a facet is.
///
/// **No occlusion test**, the same rule `MeetPointOverlay` already states: a facet facing away is reached
/// by orbiting, and a marker the author cannot see is worse than one behind the stone. The opacity slider
/// is how they look inside.
///
/// `.allowsHitTesting(false)` is load-bearing: without it the chips eat the clicks meant for the facet
/// under them, which during a pick is every click that matters.
struct MeetPickOverlay: View {
  let markers: [MeetPickMarker]
  let camera: BenchCameraState

  var body: some View {
    GeometryReader { proxy in
      let size = proxy.size
      let aspect = size.height > 0 ? Float(size.width / size.height) : 1
      ForEach(markers) { marker in
        if let point = benchScreenPoint(marker.world, aspect: aspect, camera: camera) {
          content(marker)
            .position(x: CGFloat(point.x) * size.width, y: CGFloat(point.y) * size.height)
        }
      }
    }
    .allowsHitTesting(false)
  }

  /// The chip is `MeetDotChip`'s look and not a second one, so the viewport and the tier table keep
  /// reading as one thing.
  @ViewBuilder
  private func content(_ marker: MeetPickMarker) -> some View {
    let colour = meetPickMarkerColor(marker.kind)
    switch marker.kind {
    case .named(let n):
      MeetDotChip(label: "\(n) · \(marker.label)", colour: colour)
    case .candidate:
      // Half opacity, so the set awaiting a click reads as offered rather than chosen.
      MeetDotChip(label: marker.label, colour: colour).opacity(0.5)
    case .corner:
      // **No text beside it**: the ring's shape is what distinguishes it from a chip, and the word `end`
      // twice on one edge says nothing.
      Circle().strokeBorder(colour, lineWidth: 1.5).frame(width: 9, height: 9)
    }
  }
}
