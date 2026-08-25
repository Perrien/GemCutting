import BenchGeometry
import FacetKernel
import Foundation
import SwiftUI

/// The renderer's region. **One Metal subview plus the index-ring overlay** (D2, U4), and nothing
/// else may draw here.
struct ViewportRegion: View {
  let mesh: SolidMesh
  let generation: Int
  let camera: BenchCameraState
  let opacity: Double
  let highlightedPlaneIndex: Int?
  let ringLabels: [IndexRingLabel]
  let onOrbit: (CGFloat, CGFloat) -> Void
  let onPick: (CGPoint, CGSize) -> Void

  var body: some View {
    MetalViewport(
      mesh: mesh,
      generation: generation,
      camera: camera,
      opacity: opacity,
      highlightedPlaneIndex: highlightedPlaneIndex,
      onOrbit: onOrbit,
      onPick: onPick
    )
    .overlay { IndexRingOverlay(labels: ringLabels, camera: camera) }
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

/// The table across the bottom of the main area. **No column carries a sort key**: tier order is data,
/// and a sortable header invites reordering the one thing that must never be normalised.
struct TierTableRegion: View {
  let rows: [TierTableRow]

  var body: some View {
    Table(rows) {
      TableColumn("Tier") { row in
        HStack(spacing: 4) {
          if row.state == .stopped { Image(systemName: "exclamationmark.triangle") }
          cell(row.tier, row)
        }
      }
      TableColumn("Part") { row in cell(row.part, row) }
      TableColumn("Angle") { row in cell(row.angle, row) }
      TableColumn("Indices") { row in cell(row.indices, row) }
      TableColumn("Meet") { row in cell(row.meet, row) }
      TableColumn("Wheel") { row in cell(row.wheel, row, dimmed: row.wheelIsInherited) }
      TableColumn("Instructions") { row in cell(row.instructions, row) }
    }
  }

  /// Every cell of a tier the solve never reached reads secondary, and a Wheel cell does too when the
  /// gear is the header's rather than the tier's own. A `Table` has no row-level modifier, so the two
  /// rules live in one helper rather than in seven columns.
  ///
  /// The stopped tier is marked by a symbol and not by colour alone, so the marking survives both a
  /// screenshot and a colour-blind reader.
  private func cell(_ text: String, _ row: TierTableRow, dimmed: Bool = false) -> some View {
    Text(text).foregroundStyle(dimmed || row.state == .notReached ? .secondary : .primary)
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
  let solid: BenchSolid
  /// The picked facet's label, or `nil` for no selection (D11).
  let selectedFacet: String?
  #if DEBUG
    @Binding var tierLimit: Int?
  #endif

  var body: some View {
    HStack(spacing: 8) {
      Text(solid.stoppedReason ?? "No findings")
      Spacer(minLength: 8)
      Text(selectedFacet.map { "Facet \($0)" } ?? "No facet selected")
      #if DEBUG
        tierLimitStepper
        Text(documentSummary)
      #endif
    }
    .font(.callout)
    .foregroundStyle(.secondary)
    .padding(.horizontal, 10)
    .frame(height: 22)
  }

  #if DEBUG
    private var tierTotal: Int { pattern?.tiers.count ?? 0 }
    private var tiersShown: Int { tierLimit ?? tierTotal }

    /// The only way to see a rough-and-pattern solid at all: every authored pattern is `finished`, and a
    /// finished pattern cuts the whole prism away. A later slice's scrubber supersedes this.
    private var tierLimitStepper: some View {
      Stepper("tiers \(tiersShown)/\(tierTotal)") {
        setTierLimit(min(tiersShown + 1, tierTotal))
      } onDecrement: {
        setTierLimit(max(tiersShown - 1, 0))
      }
      .disabled(pattern == nil)
    }

    /// At the total it stores `nil` rather than the number, so the unlimited case stays the default.
    private func setTierLimit(_ value: Int) {
      tierLimit = value >= tierTotal ? nil : value
    }

    /// What the document decoded, and what the solid it produced is made of.
    private var documentSummary: String {
      let document =
        pattern.map { "\($0.name) · \($0.state.rawValue) · \($0.tiers.count) tiers" }
        ?? "no pattern"
      let counts =
        "\(solid.polytope.facets.count) facets "
        + "(\(solid.cutFacetIndices.count) cut, \(solid.roughFacetIndices.count) rough)"
      let rough = solid.includesRough ? "rough scaffolding" : "rough dropped"
      let stopped = solid.stoppedAtTier.map { " · stopped at \($0)" } ?? ""
      return "\(document) · \(counts) · \(rough)\(stopped)"
    }
  #endif
}
