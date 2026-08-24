import FacetKernel
import SwiftUI

/// The layout root. This part lands the status strip only; T3 adds the split, the inspector and the
/// toolbar toggle around it.
struct BenchWindow: View {
  @ObservedObject var document: PatternDocument

  var body: some View {
    VStack(spacing: 0) {
      Spacer(minLength: 0)
      Divider()
      StatusStripRegion(pattern: document.pattern)
    }
    .frame(minWidth: 900, minHeight: 600)
    .navigationTitle(document.pattern?.name ?? "Untitled")
  }
}
