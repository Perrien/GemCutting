import BenchGeometry
import FacetKernel
import Foundation
import SwiftUI

/// The renderer's region. **One Metal subview plus the index-ring and meet-point overlays** (D2, U4),
/// and nothing else may draw here.
struct ViewportRegion: View {
  let mesh: SolidMesh
  let generation: Int
  let camera: BenchCameraState
  let opacity: Double
  let highlightedPlaneIndex: Int?
  let ringLabels: [IndexRingLabel]
  /// The selected tier's named points. Empty for no selection, and then the overlay draws nothing.
  let meetDots: [MeetPointDot]
  /// Whether this tier carries a finding whose geometry is one of these points.
  let meetWarning: Bool
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
    // After the ring, so a dot near the rim draws over a number rather than under it: the dot is about
    // the tier you selected and the number is standing context.
    .overlay { MeetPointOverlay(dots: meetDots, camera: camera, warning: meetWarning) }
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
  /// The tier whose meet points are drawn. A view state and nothing more: nothing is edited through it
  /// and it is not persisted.
  @Binding var selection: String?
  /// The tiers whose dots draw as a warning, because a finding says a named point of theirs is not a
  /// corner of the stone as it stands when they are cut.
  let warningTiers: Set<String>
  /// Tier label to how many findings name it. A tier with none is absent.
  let findingCounts: [String: Int]

  var body: some View {
    Table(rows, selection: $selection) {
      TableColumn("Tier") { row in
        HStack(spacing: 4) {
          if row.state == .stopped { Image(systemName: "exclamationmark.triangle") }
          cell(row.tier, row)
        }
      }
      TableColumn("Part") { row in cell(row.part, row) }
      TableColumn("Angle") { row in cell(row.angle, row) }
      TableColumn("Indices") { row in cell(row.indices, row) }
      TableColumn("Meet") { row in
        if row.meetPoints.isEmpty {
          cell(row.meet, row)
        } else {
          let warning = warningTiers.contains(row.tier)
          HStack(spacing: 8) {
            ForEach(row.meetPoints) { dot in
              HStack(spacing: 3) {
                MeetDotChip(label: dot.label, colour: meetDotColor(dot.role, warning: warning))
                if !dot.facets.isEmpty { cell(dot.facets, row) }
              }
            }
          }
        }
      }
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

/// A meet point's dot as it appears in the table: the same label and the same colour as the viewport's,
/// so the two are read as one thing. Tinted fill under a solid border rather than coloured text, which
/// keeps the label at `.primary` and readable in both appearances against every one of the four colours.
private struct MeetDotChip: View {
  let label: String
  let colour: Color

  var body: some View {
    Text(label)
      .font(.caption2.weight(.semibold))
      .padding(.horizontal, 4)
      .padding(.vertical, 1)
      .background(Capsule().fill(colour.opacity(0.25)))
      .overlay(Capsule().strokeBorder(colour))
  }
}

/// The trailing column's stacked cards. `Pattern` first and `Notes` directly below it is the app
/// shell's ordering and is not the executor's to change.
struct InspectorRegion: View {
  let pattern: FacetKernel.Pattern?
  let solid: BenchSolid
  /// The declared facet count as typed. Session state only: it is never read from the document and never
  /// written to it, because a declared count is a one-time claim made while transcribing a printed sheet.
  @Binding var declaredFacets: String

  var body: some View {
    ScrollView {
      VStack(spacing: 12) {
        GroupBox("Pattern") { EmptyCard() }
        GroupBox("Notes") { EmptyCard() }
        GroupBox("Metrics") {
          // Called here rather than cached in the store: measuring is arithmetic over facets the hull has
          // already produced, so a cache would add a second source of truth to save nothing measurable.
          MetricsCard(readout: metricsReadout(pattern: pattern, solid: solid))
        }
        GroupBox("Light") { EmptyCard() }
        GroupBox("Facet Count") {
          FacetCountCard(
            check: facetCountCheck(pattern: pattern, solid: solid, declared: declaredFacets),
            declaredFacets: $declaredFacets)
        }
      }
      .padding(12)
    }
  }
}

/// The stone's measurements: the trio that moves while authoring over the table that is read once a tier
/// lands.
///
/// **A part-cut stone shows the reason and no figures at all** — no dimmed table and no stale numbers.
/// Until something caps the solid, the pattern's own planes render a floating pavilion cone, so a crown
/// height or a table ratio taken from them describes that cone rather than the stone.
private struct MetricsCard: View {
  let readout: MetricsReadout

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      switch readout {
      case .unavailable(let reason):
        Text(reason)
          .font(.callout)
          .foregroundStyle(.secondary)
      case .measured(let summary):
        // Every row is a `LabeledContent`, so the label-and-value alignment is the platform's rather than
        // hand-built, and monospaced digits stop a changing figure shifting the column.
        LabeledContent("Facets", value: summary.facets)
        LabeledContent("Symmetry", value: summary.symmetry)
        LabeledContent("L/W", value: summary.lengthOverWidth)
        Divider()
        ForEach(summary.proportions) { row in
          LabeledContent(row.label, value: row.value)
        }
      }
    }
    .monospacedDigit()
    // Held at full width so stepping into and out of the part-cut state does not resize the card.
    .frame(maxWidth: .infinity, alignment: .leading)
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

/// The one check that catches a whole tier dropped in transcription: what the solve counted, what the
/// printed sheet claims, and the kernel's verdict on the two.
///
/// The field is free text and `facetCountCheck` parses it, which is what lets a half-typed `5` say it is
/// not a facet count rather than silently becoming a number the owner did not mean. **The solved line
/// never moves when the claim does** — that is the whole point of showing both.
private struct FacetCountCard: View {
  let check: FacetCountCheck
  @Binding var declaredFacets: String

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      if let solved = check.solved {
        LabeledContent("Solved", value: solved)
          .monospacedDigit()
      }
      TextField("Declared", text: $declaredFacets)
        .textFieldStyle(.roundedBorder)
      Text(check.verdict)
        .font(.callout)
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

/// The main area's bottom row. Leading text is the findings line. Trailing, behind `#if DEBUG`, is what
/// the document actually decoded.
struct StatusStripRegion: View {
  let pattern: FacetKernel.Pattern?
  let solid: BenchSolid
  /// The picked facet's label, or `nil` for no selection (D11).
  let selectedFacet: String?
  /// The one findings value all three surfaces read, so none of them can disagree about the count.
  let findings: FindingsReadout
  #if DEBUG
    @Binding var tierLimit: Int?
  #endif

  var body: some View {
    HStack(spacing: 8) {
      Text(findings.line)
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
