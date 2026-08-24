import FacetKernel
import Foundation
import SwiftUI

/// The renderer's region. **One replaceable subview** (D2): part 2 swaps this body for an
/// `NSViewRepresentable`-wrapped `MTKView`, so nothing else may draw here.
struct ViewportRegion: View {
  var body: some View {
    Color(nsColor: .textBackgroundColor)
      .overlay {
        Text("Viewport")
          .foregroundStyle(.secondary)
      }
  }
}

/// The strip directly under the viewport. Empty in this part (D11).
struct ScrubberRegion: View {
  var body: some View {
    Text("Scrubber")
      .font(.callout)
      .foregroundStyle(.secondary)
      .frame(maxWidth: .infinity)
      .frame(height: 32)
  }
}

/// A tier table row. Every column is a string in this part — the table is empty (D11), and what
/// fills it is a later slice's.
struct TierRow: Identifiable {
  let id = UUID()
  var tier = ""
  var part = ""
  var angle = ""
  var indices = ""
  var meet = ""
  var wheel = ""
  var instructions = ""
}

/// The table across the bottom of the main area: seven headers over zero rows, which lands the column
/// order now (D9, D11).
struct TierTableRegion: View {
  private let rows: [TierRow] = []

  var body: some View {
    Table(rows) {
      TableColumn("Tier", value: \.tier)
      TableColumn("Part", value: \.part)
      TableColumn("Angle", value: \.angle)
      TableColumn("Indices", value: \.indices)
      TableColumn("Meet", value: \.meet)
      TableColumn("Wheel", value: \.wheel)
      TableColumn("Instructions", value: \.instructions)
    }
  }
}

/// The trailing column's stacked cards. `Pattern` first and `Notes` directly below it is D9's
/// ordering and is not the executor's to change.
struct InspectorRegion: View {
  var body: some View {
    ScrollView {
      VStack(spacing: 12) {
        GroupBox("Pattern") { EmptyCard() }
        GroupBox("Notes") { EmptyCard() }
        GroupBox("Metrics") { EmptyCard() }
        GroupBox("Light") { EmptyCard() }
        GroupBox("Facet Count") { EmptyCard() }
      }
      .padding(12)
    }
  }
}

/// What every inspector card holds until a later slice fills it (D11).
private struct EmptyCard: View {
  var body: some View {
    Text("empty")
      .font(.callout)
      .foregroundStyle(.secondary)
      .frame(maxWidth: .infinity)
  }
}

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
