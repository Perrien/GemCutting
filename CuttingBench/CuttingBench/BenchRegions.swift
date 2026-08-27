import BenchGeometry
import FacetKernel
import Foundation
import SwiftUI

/// The renderer's region. **One Metal subview plus the index-ring, meet-point, meet-pick and
/// probe-path overlays** (D2, U4), and nothing else may draw here.
struct ViewportRegion: View {
  let mesh: SolidMesh
  let generation: Int
  /// The finished stone's mesh, drawn in edges only while a meet is being picked, or `nil` for none.
  let ghostMesh: SolidMesh?
  let ghostGeneration: Int
  let camera: BenchCameraState
  let opacity: Double
  let highlightedPlaneIndex: Int?
  let ringLabels: [IndexRingLabel]
  /// The selected tier's named points. Empty for no selection, and then the overlay draws nothing.
  let meetDots: [MeetPointDot]
  /// Whether this tier carries a finding whose geometry is one of these points.
  let meetWarning: Bool
  /// What the pick in progress has clicked, and what it may click next. Empty for no pick.
  let pickMarkers: [MeetPickMarker]
  /// The last traced path. `nil` for none, and then the overlay draws nothing.
  let probe: ProbeReadout?
  let onOrbit: (CGFloat, CGFloat) -> Void
  let onPick: (CGPoint, CGSize) -> Void

  var body: some View {
    MetalViewport(
      mesh: mesh,
      generation: generation,
      ghostMesh: ghostMesh,
      ghostGeneration: ghostGeneration,
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
    // After the dots: a pick marker is what the author is doing now, and a stored meet's dots are
    // standing context.
    .overlay { MeetPickOverlay(markers: pickMarkers, camera: camera) }
    // Last of the four, so the path draws over a dot rather than under it: the path is what the owner
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
  /// The tier whose meet points are drawn, and the tier the structural buttons act on. Not persisted.
  @Binding var selection: String?
  /// The one findings value all three surfaces read, so none of them can disagree about the count.
  let findings: FindingsReadout
  /// The raw values the cells edit, and the labels the buttons act on. The formatted `rows` stay the
  /// display: a cell shows `47.60°` and edits `47.60`.
  let draft: PatternDraft
  let edit: (String, DraftChange) -> Bool
  /// Starts a pick on one tier. **Not `edit`**: starting a pick changes no draft, so it is not a
  /// `DraftChange` and must not register an undo entry.
  let startPick: (String) -> Void
  /// One tier's anchored percentage, as the tier label and the typed text. Beside `edit` because that is
  /// where every other cell's commit comes from, and it goes through the same funnel.
  let commitPercent: (String, String) -> Bool

  var body: some View {
    VStack(spacing: 0) {
      buttonRow
      Divider()
      table
    }
  }

  /// Add, delete and reorder, over the table rather than in it. **Delete and both moves act on the
  /// selection**, which is why the selection is no longer a read-only view state.
  ///
  /// Add is always live: appending can never create a forward reference, so there is nothing for it to be
  /// refused for. Delete asks for no confirmation — a refused delete already explains itself and an
  /// accepted one is one ⌘Z away.
  private var buttonRow: some View {
    HStack(spacing: 8) {
      Button {
        _ = edit("Add Tier") { appendingTier(to: $0) }
      } label: {
        Label("Add Tier", systemImage: "plus")
      }
      Button {
        guard let selection else { return }
        _ = edit("Delete Tier") { deleting(tier: selection, from: $0) }
      } label: {
        Label("Delete Tier", systemImage: "minus")
      }
      .disabled(selectedPosition == nil)
      Button {
        guard let selection else { return }
        _ = edit("Move Tier") { moving(tier: selection, by: -1, in: $0) }
      } label: {
        Label("Move Up", systemImage: "chevron.up")
      }
      .disabled(selectedPosition.map { $0 == 0 } ?? true)
      Button {
        guard let selection else { return }
        _ = edit("Move Tier") { moving(tier: selection, by: 1, in: $0) }
      } label: {
        Label("Move Down", systemImage: "chevron.down")
      }
      .disabled(selectedPosition.map { $0 == draft.tiers.count - 1 } ?? true)
      Spacer()
    }
    .padding(.horizontal, 10)
    .frame(height: 28)
  }

  /// Where the selected tier sits, or `nil` for no selection and for a label the draft does not carry — a
  /// stale selection is inert rather than wrong, so it disables the three buttons that would act on it.
  private var selectedPosition: Int? {
    selection.flatMap { draft.position(ofTier: $0) }
  }

  private var table: some View {
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
          EditableCell(stored: row.tier) { typed in
            edit("Rename Tier") { renaming(tier: row.tier, to: typed, in: $0) }
          }
        }
      }
      TableColumn("Part") { row in
        Picker(
          "Part",
          selection: Binding(
            get: { row.part },
            set: { chosen in
              guard let part = partCases.first(where: { $0.rawValue == chosen }) else { return }
              // Discarded rather than reverted: a `Picker` reads its value back from the draft, so a
              // refusal already leaves it showing the stored part. Only a text buffer needs the answer.
              _ = edit("Change Part") { setting(part: part, ofTier: row.tier, in: $0) }
            })
        ) {
          ForEach(partCases, id: \.rawValue) { part in
            Text(part.rawValue).tag(part.rawValue)
          }
        }
        .labelsHidden()
        .pickerStyle(.menu)
      }
      TableColumn("Angle") { row in
        HStack(spacing: 4) {
          // The number without the degree sign, so what the author edits is what they typed; the `°` is a
          // label beside the field rather than part of its text.
          EditableCell(stored: row.angleValue) { typed in
            edit("Change Angle") { setting(angle: typed, ofTier: row.tier, in: $0) }
          }
          Text("°")
            .foregroundStyle(row.state == .notReached ? .secondary : .primary)
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
      // Seeds, Folds and Mirror sit before Indices so the row reads left to right as the generation
      // itself: these seeds, expanded this many folds, optionally mirrored, giving these stops.
      // All three are derived from the stops every time the table is built — nothing symmetry-shaped is
      // stored, in the file or in the draft — so editing Indices directly re-derives them and a tier
      // whose stops are not symmetric honestly reads as 1-fold.
      TableColumn("Seeds") { row in
        EditableCell(stored: row.seeds) { typed in
          edit("Change Seed Stops") { setting(seeds: typed, ofTier: row.tier, in: $0) }
        }
      }
      TableColumn("Folds") { row in
        EditableCell(stored: row.folds) { typed in
          edit("Change Symmetry Folds") { setting(folds: typed, ofTier: row.tier, in: $0) }
        }
      }
      TableColumn("Mirror") { row in
        // Discarded rather than reverted, as the Part popup's result is: the binding's getter reads the
        // row, which is rebuilt from the draft, so a refused change leaves the toggle showing the stored
        // value with no revert code.
        Toggle(
          "",
          isOn: Binding(
            get: { row.mirror },
            set: { on in
              _ = edit("Change Mirroring") { setting(mirror: on, ofTier: row.tier, in: $0) }
            })
        )
        .labelsHidden()
      }
      TableColumn("Indices") { row in
        EditableCell(stored: row.indices) { typed in
          edit("Change Index Stops") { setting(indices: typed, ofTier: row.tier, in: $0) }
        }
      }
      TableColumn("Meet") { row in
        HStack(spacing: 6) {
          meetContent(row)
          meetMenu(row)
        }
      }
      TableColumn("Wheel") { row in
        // The `inherit` item carries the effective gear in its label, because that is what the cell showed
        // before it was a popup and a stop number means nothing without one. The tag stays the bare word,
        // so the label can change without moving the selection. `gearsOffered` adds a gear the document
        // already carries that is not one of the eight, or the popup would render blank.
        Picker(
          "Wheel",
          selection: Binding(
            get: { row.wheelIsInherited ? inheritTag : row.wheel },
            set: { chosen in
              if chosen == inheritTag {
                _ = edit("Change Index Gear") { setting(wheel: nil, ofTier: row.tier, in: $0) }
              } else if let gear = gearsOffered(including: draft.wheel)
                .first(where: { String($0) == chosen })
              {
                _ = edit("Change Index Gear") { setting(wheel: gear, ofTier: row.tier, in: $0) }
              }
            })
        ) {
          Text("\(inheritTag) (\(draft.wheel))").tag(inheritTag)
          ForEach(
            gearsOffered(including: row.wheelIsInherited ? nil : Int(row.wheel)), id: \.self
          ) { gear in
            Text(String(gear)).tag(String(gear))
          }
        }
        .labelsHidden()
        .pickerStyle(.menu)
      }
      TableColumn("Instructions") { row in
        EditableCell(stored: row.instructions) { typed in
          edit("Change Instructions") { setting(instructions: typed, ofTier: row.tier, in: $0) }
        }
      }
    }
  }

  /// What the meet actually is: each named point as a chip beside the facets it names, or the one-line form
  /// for the three that name none, and `—` for a tier whose depth is not decided yet.
  ///
  /// **Deliberately not inside the menu's label.** SwiftUI renders only the first element of a composed
  /// `Menu` label, which left the cell reading `M` with `G1@0 · G1@12 · P1@0` nowhere on screen — and
  /// saying what a meet is, is most of what this column is for.
  ///
  /// **The anchored dot is a field rather than a chip**, because its percentage is the one thing in a meet
  /// that is a number the author sets rather than a facet they clicked. Three decimals because that is the
  /// corpus's own precision — `Novice Ash-er` stores `24.862` — and the field shows what it will store, so
  /// committing the text as shown changes nothing.
  @ViewBuilder
  private func meetContent(_ row: TierTableRow) -> some View {
    if row.meetPoints.isEmpty {
      cell(row.meet, row)
    } else {
      let warning = findings.warningTiers.contains(row.tier)
      HStack(spacing: 8) {
        ForEach(row.meetPoints) { dot in
          HStack(spacing: 3) {
            if let percent = dot.percent {
              EditableCell(stored: String(format: "%.3f", percent)) { typed in
                commitPercent(row.tier, typed)
              }
            } else {
              MeetDotChip(label: dot.label, colour: meetDotColor(dot.role, warning: warning))
            }
            if !dot.facets.isEmpty { cell(dot.facets, row) }
          }
        }
      }
    }
  }

  /// The three forms that need no picking, *Not chosen yet*, and **Pick in viewport…**, which hands the
  /// rest to the viewport. A `vertex` is never typed here: which facets it names is a claim about the
  /// stone, and clicking them is how that claim is made.
  ///
  /// The result of the funnel is discarded because a menu reads its state back from the draft — a refusal
  /// leaves the cell reading the stored meet, so there is nothing to revert. Only a text buffer needs the
  /// answer.
  private func meetMenu(_ row: TierTableRow) -> some View {
    Menu {
      Button("Not chosen yet") {
        _ = edit("Change Meet") { setting(meet: nil, ofTier: row.tier, in: $0) }
      }
      Divider()
      Button("Pick in viewport…") { startPick(row.tier) }
      Divider()
      Button("size") { _ = edit("Change Meet") { setting(meet: .size, ofTier: row.tier, in: $0) } }
      Button("tcp") { _ = edit("Change Meet") { setting(meet: .tcp, ofTier: row.tier, in: $0) } }
      Button("girdle") {
        _ = edit("Change Meet") { setting(meet: .girdle, ofTier: row.tier, in: $0) }
      }
    } label: {
      Image(systemName: "chevron.up.chevron.down")
    }
    // An explicit chevron with the style's own indicator hidden, or the cell carries two of them.
    .menuStyle(.borderlessButton)
    .menuIndicator(.hidden)
    .fixedSize()
    .help("Change this tier's meet")
    .accessibilityLabel("Change meet")
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

/// A cell that commits on Return or on losing focus, and snaps back to the stored value when the edit is
/// refused. `stored` is what the draft holds; the buffer is local and never the source of truth.
///
/// **The commit boundary is what makes the refusal rules possible at all**: a refusal needs a whole value
/// to judge, and a half-typed index list means nothing.
private struct EditableCell: View {
  let stored: String
  /// Returns whether the edit was accepted.
  let commit: (String) -> Bool
  /// Vertical for prose that wants line breaks. Every field but Notes takes the default.
  var axis: Axis = .horizontal
  /// `false` where Return has to keep inserting a line break rather than committing — which is Notes, and
  /// only Notes: prose is the one thing here whose content includes the key that would submit it.
  var commitsOnReturn = true

  @State private var typed = ""
  @FocusState private var focused: Bool

  var body: some View {
    TextField("", text: $typed, axis: axis)
      .textFieldStyle(.plain)
      .focused($focused)
      .onSubmit { if commitsOnReturn { commitNow() } }
      .onChange(of: focused) { _, isFocused in if !isFocused { commitNow() } }
      // The buffer follows the draft, so an accepted edit, an undo and a rename all correct it.
      .onChange(of: stored, initial: true) { typed = stored }
  }

  /// On a refusal the draft is untouched, so `stored` is still the old value and assigning it is the
  /// revert. On acceptance `stored` changes and the observer above does it instead.
  private func commitNow() { if !commit(typed) { typed = stored } }
}

/// The four cases in the kernel's own declaration order. **`Part` gains no `CaseIterable` conformance**:
/// `allCases` is only synthesised at the point of declaration, so a retroactive conformance would mean
/// hand-writing this same list behind a protocol that buys nothing.
private let partCases: [Part] = [.pav, .gdl, .crown, .table]

/// The Wheel popup's tag for a tier declaring no gear of its own. A `String` tag rather than an `Int?`,
/// for the reason `partCases` is matched by `rawValue`: an optional tag is the case that idiom avoids.
private let inheritTag = "inherit"

/// A meet point's dot as it appears in the table: the same label and the same colour as the viewport's,
/// so the two are read as one thing. Tinted fill under a solid border rather than coloured text, which
/// keeps the label at `.primary` and readable in both appearances against every one of the four colours.
///
/// Not `private`: `MeetPickOverlay` draws the same chip for a clicked facet, and a second capsule with the
/// same job is how the two come to look different.
struct MeetDotChip: View {
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
  /// Whether a viewport click also traces a ray. Off by default: the path is a mode, not a side effect of
  /// picking a facet.
  @Binding var probeOn: Bool
  /// The last traced path, or `nil` for none. Cleared whenever the solid changes.
  let probe: ProbeReadout?
  /// The header fields the Pattern and Notes cards edit. The derived `pattern` stays what every other card
  /// measures, so no card can disagree with the draft about what is being solved.
  let draft: PatternDraft
  let edit: (String, DraftChange) -> Bool
  /// The `state` switch's setter. The window owns the check behind it, because the check needs the declared
  /// facet count, which is the window's session state.
  let setState: (PatternState) -> Void

  var body: some View {
    ScrollView {
      VStack(spacing: 12) {
        GroupBox("Pattern") { PatternCard(draft: draft, edit: edit, setState: setState) }
        GroupBox("Notes") { NotesCard(draft: draft, edit: edit) }
        GroupBox("Metrics") {
          // Called here rather than cached in the store: measuring is arithmetic over facets the hull has
          // already produced, so a cache would add a second source of truth to save nothing measurable.
          MetricsCard(readout: metricsReadout(pattern: pattern, solid: solid))
        }
        GroupBox("Light") {
          LightCard(
            readout: lightReadout(pattern: pattern, solid: solid, riOverride: ""),
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

/// The header fields, in the order the format writes them. The gear is a popup of the eight index gears: a
/// change is refused when it would put an existing stop of an inheriting tier out of range, and it never
/// renumbers a stop — the planes move, and the solve reports it. `state` is a two-way switch, and
/// whether `finished` may be claimed is `finishRefusal`'s question, asked by the window before the edit is
/// applied.
///
/// **RI shows three decimals and the girdle target four, because an editable field has to be able to
/// round-trip its own value.** Two decimals would render corundum's `1.762` as `1.76`, and committing that
/// would silently change the pattern. A field is only ever committed by an explicit edit, so a value
/// carrying more precision than the field shows is safe until the author touches it.
private struct PatternCard: View {
  let draft: PatternDraft
  let edit: (String, DraftChange) -> Bool
  /// Applied only once the transition has been allowed. The window owns the check, because the check
  /// needs the declared facet count, which is the window's session state.
  let setState: (PatternState) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      row("Name") {
        EditableCell(stored: draft.name) { typed in
          edit("Change Name") { setting(name: typed, in: $0) }
        }
      }
      row("State") {
        // A segmented `Picker` rather than a `Toggle`: the two values have names — `in progress` and
        // `finished` — and a switch would show only one of them.
        //
        // **The binding's getter is the draft**, so a refused transition needs no revert code: the draft
        // is untouched, the next body pass reads the old value back, and the control springs back. The
        // same mechanism `EditableCell` uses.
        Picker("", selection: Binding(get: { draft.state }, set: { setState($0) })) {
          Text(PatternState.inProgress.rawValue).tag(PatternState.inProgress)
          Text(PatternState.finished.rawValue).tag(PatternState.finished)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
      }
      row("Gear") {
        // No `inherit` item: the design's default gear has nothing above it to inherit from.
        Picker(
          "",
          selection: Binding(
            get: { String(draft.wheel) },
            set: { chosen in
              guard
                let gear = gearsOffered(including: draft.wheel)
                  .first(where: { String($0) == chosen })
              else { return }
              _ = edit("Change Index Gear") { setting(wheel: gear, in: $0) }
            })
        ) {
          ForEach(gearsOffered(including: draft.wheel), id: \.self) { gear in
            Text(String(gear)).tag(String(gear))
          }
        }
        .labelsHidden()
        .pickerStyle(.menu)
      }
      row("RI") {
        EditableCell(stored: String(format: "%.3f", draft.ri)) { typed in
          edit("Change Refractive Index") { setting(ri: typed, in: $0) }
        }
      }
      row("Girdle target") {
        // Empty is absent, which means the documented default rather than zero — and the fraction the file
        // stores, not a percentage, because a second unit is a second place the number can be wrong.
        EditableCell(
          stored: draft.girdleTargetFraction.map { String(format: "%.4f", $0) } ?? ""
        ) { typed in
          edit("Change Girdle Target") { setting(girdleTarget: typed, in: $0) }
        }
      }
      row("Designer") {
        EditableCell(stored: draft.designer) { typed in
          edit("Change Designer") { setting(designer: typed, in: $0) }
        }
      }
    }
    .monospacedDigit()
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  /// `LabeledContent`, as `MetricsCard`'s rows are, so the label-and-value alignment is the platform's
  /// rather than hand-built and the two cards read as one column.
  private func row(_ label: String, @ViewBuilder content: () -> some View) -> some View {
    LabeledContent(label, content: content)
  }
}

/// The pattern's prose, as one multi-line field.
///
/// **Commits on losing focus only.** Return inserts a line break in a vertical `TextField`, and notes are
/// prose that wants them — so the key that would submit is the key the content needs.
private struct NotesCard: View {
  let draft: PatternDraft
  let edit: (String, DraftChange) -> Bool

  var body: some View {
    EditableCell(
      stored: draft.notes,
      commit: { typed in edit("Change Notes") { setting(notes: typed, in: $0) } },
      axis: .vertical,
      commitsOnReturn: false
    )
    .lineLimit(3...10)
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
  /// What the pick in progress is waiting for, or `nil` when none is running. **Not behind `#if DEBUG`**:
  /// a pick is a normal working state, not a diagnostic.
  let pickPrompt: String?
  let cancelPick: () -> Void
  #if DEBUG
    /// How many step frames are cached, and how many the list has. The owner's window onto the
    /// precompute.
    let cachedFrames: Int
    let stepTotal: Int
    /// What the draft holds, which is not always what the display solves: a tier with no meet yet is a
    /// row the author wrote and a tier the stone has never heard of.
    let draftLine: String
    /// What the deferred half of validation has actually done, so the per-tier cache and the quiet
    /// period are both watchable.
    let tierChecks: Int
    let geometricPasses: Int
    let isArmed: Bool
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
      // The one thing on the strip the author is acting on, so it reads primary — and the facet text
      // beside it is the last facet they clicked, which is the same click.
      if let pickPrompt {
        Text(pickPrompt).foregroundStyle(.primary)
        Button("Cancel", action: cancelPick).buttonStyle(.link)
      }
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
      let checks = "checks \(geometricPasses) · tiers \(tierChecks)\(isArmed ? " · armed" : "")"
      return "\(document) · \(counts) · \(rough)\(stopped) · frames \(cachedFrames)/\(stepTotal)"
        + " · \(draftLine) · \(checks)"
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
