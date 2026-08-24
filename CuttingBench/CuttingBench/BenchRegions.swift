import FacetKernel
import SwiftUI

/// The main area's bottom row. Leading text is the findings line — nothing computes findings until
/// part 4, so it is unconditional. Trailing, behind `#if DEBUG`, is what the document actually
/// decoded.
struct StatusStripRegion: View {
  let pattern: FacetKernel.Pattern?

  var body: some View {
    HStack(spacing: 8) {
      Text("No findings")
      Spacer(minLength: 8)
      #if DEBUG
        Text(documentSummary)
      #endif
    }
    .font(.callout)
    .foregroundStyle(.secondary)
    .padding(.horizontal, 10)
    .frame(height: 22)
  }

  #if DEBUG
    /// The handle that proves decoding worked.
    private var documentSummary: String {
      guard let pattern else { return "no pattern" }
      return "\(pattern.name) · \(pattern.state.rawValue) · \(pattern.tiers.count) tiers"
    }
  #endif
}
