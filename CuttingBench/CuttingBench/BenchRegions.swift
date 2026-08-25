import BenchGeometry
import FacetKernel
import Foundation
import SwiftUI

/// The renderer's region. **One Metal subview plus the index-ring, meet-point and probe-path overlays**
/// (D2, U4), and nothing else may draw here.
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
  /// The last traced path. `nil` for none, and then the overlay draws nothing.
  let probe: ProbeReadout?
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
    // Last of the three, so the path draws over a dot rather than under it: the path is what the owner
    // just asked for and the dots are standing context.
    .overlay { ProbePathOverlay(probe: probe, camera: camera) }
  }
}

/// The strip directly under the viewport: the granularity control, the scrubber and the step readout.
///
/// **No state of its own**, like `ViewportRegion` and `TierTableRegion`. The window mutates the store
/// and rebuilds the findings after, so a pattern change and a scrub go down one path.
struct ScrubberRegion: View {
  /// Every position playback can reach. Empty when there is nothing to play.
  let steps: [PlaybackStep]
  let stepIndex: Int
  /// `nil` is playback off.
  let granularity: PlaybackGranularity?
  /// Non-`nil` while the frames are being built, which is when the slider is disabled.
  let progress: PlaybackProgress?
  /// Whether the solve placed any tier at all. `false` disables the whole strip.
  let canPlay: Bool
  let onGranularity: (PlaybackGranularity?) -> Void
  let onStep: (Int) -> Void

  var body: some View {
    HStack(spacing: 10) {
      picker
      if let progress {
        building(progress)
      } else {
        Slider(
          value: Binding(
            get: { Double(stepIndex) },
            set: { onStep(Int($0.rounded())) }),
          in: 0...Double(max(steps.count - 1, 1)),
          step: 1
        )
        .disabled(isIdle)
      }
      // A slider alone cannot reliably hit one step of seventy-four.
      Button {
        onStep(stepIndex - 1)
      } label: {
        Image(systemName: "chevron.left")
      }
      .disabled(isIdle || stepIndex <= 0)
      Button {
        onStep(stepIndex + 1)
      } label: {
        Image(systemName: "chevron.right")
      }
      .disabled(isIdle || stepIndex >= steps.count - 1)
      // A fixed width, so the strip does not reflow as the numbers change.
      Text(steps.indices.contains(stepIndex) ? steps[stepIndex].label : "—")
        .monospaced()
        .font(.callout)
        .foregroundStyle(.secondary)
        .frame(width: 220, alignment: .trailing)
    }
    .padding(.horizontal, 10)
    .frame(height: 32)
  }

  /// The tags are spelled as optionals, or the picker never matches its selection: the binding's value
  /// is `PlaybackGranularity?`, and a bare `.tag(PlaybackGranularity.tier)` is a different type from
  /// the selection's, so that row is simply never selected.
  ///
  /// **Enabled while a precompute runs**, because choosing Off is the cancel — there is no separate
  /// Cancel button, since the control that started the wait is the one to hand.
  private var picker: some View {
    Picker(
      "Playback",
      selection: Binding(get: { granularity }, set: { onGranularity($0) })
    ) {
      Text("Off").tag(Optional<PlaybackGranularity>.none)
      Text("Tier").tag(Optional(PlaybackGranularity.tier))
      Text("Facet").tag(Optional(PlaybackGranularity.facet))
    }
    .pickerStyle(.segmented)
    .labelsHidden()
    .frame(width: 180)
    .disabled(!canPlay)
  }

  /// Determinate, because the count is known before the work starts: an indeterminate spinner would say
  /// nothing about how long the one honest wait is.
  private func building(_ progress: PlaybackProgress) -> some View {
    HStack(spacing: 8) {
      ProgressView(value: Double(progress.done), total: Double(progress.total))
      Text("building \(progress.done)/\(progress.total)")
        .font(.callout)
        .foregroundStyle(.secondary)
    }
  }

  /// The slider and both chevrons are inert with playback off, while the frames are still being built,
  /// and when the sequence is too short to move through.
  private var isIdle: Bool {
    granularity == nil || progress != nil || steps.count < 2
  }
}

/// The table across the bottom of the main area. **No column carries a sort key**: tier order is data,
/// and a sortable header invites reordering the one thing that must never be normalised.
struct TierTableRegion: View {
  let rows: [TierTableRow]
  /// The tier whose meet points are drawn. A view state and nothing more: nothing is edited through it
  /// and it is not persisted.
  @Binding var selection: String?
  /// The one findings value all three surfaces read, so none of them can disagree about the count.
  let findings: FindingsReadout

  var body: some View {
    Table(rows, selection: $selection) {
      TableColumn("Tier") { row in
        HStack(spacing: 4) {
          if row.state == .stopped { Image(systemName: "exclamationmark.triangle") }
          // Every tier with a finding is marked whether or not it is selected: the table is then the map
          // of where the faults are, which is what tells the owner which row to click. A symbol and a
          // number, so the marking is not colour alone, and a circle rather than the stopped tier's
          // triangle, so the two states stay distinguishable on one row.
          if let count = findings.perTier[row.tier], count > 0 {
            Label("\(count)", systemImage: "exclamationmark.circle")
              .labelStyle(.titleAndIcon)
              .foregroundStyle(.red)
          }
          cell(row.tier, row)
        }
      }
      TableColumn("Part") { row in cell(row.part, row) }
      TableColumn("Angle") { row in
        HStack(spacing: 4) {
          cell(row.angle, row)
          // In the Angle column because the mark is a statement about that angle, and orange rather than
          // the findings red because a shallow pavilion is not a fault. The symbol and the number each
          // carry it, so it is never colour alone.
          if row.leaksLight {
            Label(row.leakShortfall, systemImage: "sun.max")
              .labelStyle(.titleAndIcon)
              .foregroundStyle(.orange)
          }
        }
      }
      TableColumn("Indices") { row in cell(row.indices, row) }
      TableColumn("Meet") { row in
        if row.meetPoints.isEmpty {
          cell(row.meet, row)
        } else {
          let warning = findings.warningTiers.contains(row.tier)
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
  /// The debug refractive-index override as typed. Session state only, `#if DEBUG` in the card, and never
  /// read from or written to the document — a pattern's `ri` is authored, and editing it is another slice.
  @Binding var riOverride: String
  /// Whether a viewport click also traces a ray. Off by default: the path is a mode, not a side effect of
  /// picking a facet.
  @Binding var probeOn: Bool
  /// The last traced path, or `nil` for none. Cleared whenever the solid changes.
  let probe: ProbeReadout?

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
        GroupBox("Light") {
          LightCard(
            readout: lightReadout(pattern: pattern, solid: solid, riOverride: riOverride),
            riOverride: $riOverride,
            probeOn: $probeOn,
            probe: probe)
        }
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

/// What the pattern's refractive index means for the stone: the critical angle, every pavilion tier's
/// margin against it, and one traced ray on demand.
///
/// **Honest about its limit.** The check says when light definitely leaks and never that a stone performs
/// well, and the sentence saying so is a constant in the pure module rather than a string here, so no
/// later edit to this view can soften it.
private struct LightCard: View {
  let readout: LightReadout
  @Binding var riOverride: String
  @Binding var probeOn: Bool
  let probe: ProbeReadout?

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      switch readout {
      case .unavailable(let reason):
        Text(reason)
          .font(.callout)
          .foregroundStyle(.secondary)
      case .measured(let summary):
        LabeledContent("Critical angle", value: summary.criticalAngle)
        LabeledContent("Refractive index", value: summary.refractiveIndex)
        #if DEBUG
          // Temporary, and the only way a leaking state can be reached: no authored pattern leaks at its
          // own index, and the four fixtures are external ground truth that may not be edited. Free text
          // parsed by the readout, as the declared count is, so emptying the field *is* the clear.
          TextField("RI override", text: $riOverride)
            .textFieldStyle(.roundedBorder)
        #endif
        Divider()
        ForEach(summary.pavilionTiers) { row in
          LabeledContent(row.tier) { margin(row) }
        }
        Text(lightCaveat)
          .font(.callout)
          .foregroundStyle(.secondary)
        Divider()
        probeSection(summary.probe)
      }
    }
    .monospacedDigit()
    // Held at full width, as `MetricsCard` is, so a changing figure does not resize the card.
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  /// The angle and its margin. **The orange is on the margin, not on the tier label**, so the row still
  /// reads normally, and the symbol and the number each carry the marking so it is never colour alone.
  private func margin(_ row: PavilionAngleRow) -> some View {
    HStack(spacing: 6) {
      Text(row.angle)
      if row.leaks {
        Label(row.margin, systemImage: "sun.max")
          .labelStyle(.titleAndIcon)
          .foregroundStyle(.orange)
      } else {
        Text(row.margin)
          .foregroundStyle(.secondary)
      }
    }
  }

  /// The toggle when a ray can be traced, and the reason when it cannot — never an inert control.
  @ViewBuilder
  private func probeSection(_ availability: ProbeAvailability) -> some View {
    switch availability {
    case .unavailable(let reason):
      Text(reason)
        .font(.callout)
        .foregroundStyle(.secondary)
    case .available:
      Toggle("Probe", isOn: $probeOn)
      if let probe {
        ForEach(probe.legs) { leg in
          LabeledContent(leg.label, value: "\(leg.facet) · \(leg.incidence)")
        }
        Text(probe.ending)
          .font(.callout)
          .foregroundStyle(.secondary)
      }
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
    /// How many step frames are cached, and how many the list has. The owner's window onto the
    /// precompute.
    let cachedFrames: Int
    let stepTotal: Int
  #endif
  /// Whether the detail is open. View state: a popover closes when you look away and nothing about it is
  /// worth persisting.
  @State private var detailShown = false

  var body: some View {
    HStack(spacing: 8) {
      Button {
        detailShown.toggle()
      } label: {
        Text(findings.line)
      }
      .buttonStyle(.plain)
      // Inert rather than opening an empty popover.
      .disabled(findings.rows.isEmpty)
      // Above the strip, which sits at the bottom of the window.
      .popover(isPresented: $detailShown, arrowEdge: .top) {
        FindingsDetail(rows: findings.rows)
      }
      Spacer(minLength: 8)
      Text(selectedFacet.map { "Facet \($0)" } ?? "No facet selected")
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
    /// What the document decoded, what the solid it produced is made of, and how much of the playback
    /// sequence is cached.
    private var documentSummary: String {
      let document =
        pattern.map { "\($0.name) · \($0.state.rawValue) · \($0.tiers.count) tiers" }
        ?? "no pattern"
      let counts =
        "\(solid.polytope.facets.count) facets "
        + "(\(solid.cutFacetIndices.count) cut, \(solid.roughFacetIndices.count) rough)"
      let rough = solid.includesRough ? "rough scaffolding" : "rough dropped"
      let stopped = solid.stoppedAtTier.map { " · stopped at \($0)" } ?? ""
      return "\(document) · \(counts) · \(rough)\(stopped) · frames \(cachedFrames)/\(stepTotal)"
    }
  #endif
}

/// The findings, one line each, over the strip. **Never a separate Xcode-style problems list**: it is a
/// popover that closes when you look away, because a findings list is something you consult about the
/// row you are on, not a panel you work from.
///
/// The rows that are not findings — the solver's stop sentence, the note saying the geometric checks did
/// not run — read secondary, so the line's count and the list agree about what was counted.
private struct FindingsDetail: View {
  let rows: [FindingsRow]

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      ForEach(rows) { row in
        HStack(alignment: .firstTextBaseline, spacing: 6) {
          Text(row.tier ?? "—")
            .font(.caption.weight(.semibold))
            .monospaced()
            .frame(minWidth: 28, alignment: .leading)
          Text(row.text)
            .foregroundStyle(row.isFinding ? .primary : .secondary)
        }
      }
    }
    .font(.callout)
    .padding(12)
    .frame(width: 380, alignment: .leading)
  }
}
