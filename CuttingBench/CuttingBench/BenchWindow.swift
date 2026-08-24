import FacetKernel
import SwiftUI

/// The layout root (D9, D10). One `VStack`: the split of viewport-plus-scrubber over tier table, then
/// the status strip. `.inspector` on the root content view puts the inspector down the trailing edge of
/// the whole window, so the status strip belongs to the main area rather than sitting under the
/// inspector.
struct BenchWindow: View {
  @ObservedObject var document: PatternDocument
  @State private var inspectorShown = true

  var body: some View {
    VStack(spacing: 0) {
      VSplitView {
        VStack(spacing: 0) {
          ViewportRegion()
            .frame(minHeight: 240)
          Divider()
          ScrubberRegion()
        }
        TierTableRegion()
          .frame(minHeight: 140)
      }
      Divider()
      StatusStripRegion(pattern: document.pattern)
    }
    .frame(minWidth: 900, minHeight: 600)
    .inspector(isPresented: $inspectorShown) {
      InspectorRegion()
        .inspectorColumnWidth(min: 260, ideal: 300, max: 420)
    }
    .toolbar {
      Button {
        inspectorShown.toggle()
      } label: {
        Label("Inspector", systemImage: "sidebar.trailing")
      }
    }
    .navigationTitle(document.pattern?.name ?? "Untitled")
  }
}
