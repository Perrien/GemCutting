import FacetKernel
import Foundation

/// One leg of a traced path: where it ends, the facet it ended on, and how steeply it arrived.
public struct ProbeLeg: Identifiable, Equatable, Sendable {
  /// `E` for the entry, then `1`, `2`, … one per surface the ray reached. The viewport draws this chip and
  /// the card lists the same label, so an incidence figure stays attached to the right leg.
  public var label: String
  /// The facet's own name, from the drawn solid's origin map — `pb`, `t · 24`, never invented here.
  public var facet: String
  /// `45.00°`. The entry leg's is the incidence *before* refraction.
  public var incidence: String
  public var world: SIMD3<Float>

  public var id: String { label }

  public init(label: String, facet: String, incidence: String, world: SIMD3<Float>) {
    self.label = label
    self.facet = facet
    self.incidence = incidence
    self.world = world
  }
}

/// One probe: its path, how it finished, and the two stubs that show where the ray came from and went.
public struct ProbeReadout: Equatable, Sendable {
  /// The entry leg first, then one per surface. Empty when the ray never entered.
  public var legs: [ProbeLeg]
  /// A whole sentence, ready to show.
  public var ending: String
  /// Whether the ray left through a downward-facing facet — out of the back of the stone rather than back
  /// through the crown.
  ///
  /// **This is the window the probe exists to find.** A ray that returns through the table is the stone
  /// working: on every authored pattern at its own refractive index the path is in through the table,
  /// twice off the pavilion above the critical angle, and out the table again. Drawing that the same as a
  /// ray lost out of the back would call a correct stone a leak.
  ///
  /// Read from the exit facet's own outward normal, whose `z` is negative for every pavilion and girdle
  /// facet, so it needs no tier and tests no `part` of its own.
  public var leaked: Bool
  /// `0.5` world units straight up from the entry point. `nil` when there was no entry.
  public var entryStub: SIMD3<Float>?
  /// `0.5` world units along the exit direction from the last leg. `nil` unless the ray left — whichever
  /// way it went, so `leaked` is what says which of the two the stub is.
  public var exitStub: SIMD3<Float>?

  public init(
    legs: [ProbeLeg],
    ending: String,
    leaked: Bool,
    entryStub: SIMD3<Float>?,
    exitStub: SIMD3<Float>?
  ) {
    self.legs = legs
    self.ending = ending
    self.leaked = leaked
    self.entryStub = entryStub
    self.exitStub = exitStub
  }
}

/// Traces one ray straight down into the stone from a point on its surface.
///
/// **Traces the drawn solid's own planes, and only when the scaffolding has come away.** With the rough
/// gone the drawn solid *is* the pattern's own rough-free solid (`ADR-0004`), so this cannot report on a
/// rough-capped stone that does not exist — and every plane index the trace hands back is a valid key
/// into the solid's origin map, which is what lets a bounce carry a facet name.
///
/// `point` must already lie on the solid: `pickFacet` snaps it onto its plane, and a point a hair off is
/// enough to answer "no entry".
public func probeTrace(
  _ solid: BenchSolid,
  ri: Double,
  from point: (x: Double, y: Double, z: Double)
) -> ProbeReadout {
  // Belt and braces: the toggle is already unavailable while the scaffolding is there, so this catches a
  // wiring mistake rather than a normal state.
  guard !solid.includesRough else {
    return ProbeReadout(
      legs: [], ending: probeNeedsClosedStone, leaked: false, entryStub: nil, exitStub: nil)
  }

  // Vertical and downward is how windowing is judged — looking straight down at a face-up stone. A path
  // with more than eight legs is not a picture anyone reads, and the kernel says when it truncated one.
  let trace = traceRay(
    in: solid.planes, ri: ri, from: point, direction: (x: 0, y: 0, z: -1),
    bounceLimit: probeBounceLimit)

  var legs: [ProbeLeg] = []
  if let plane = trace.entryPlane, let incidence = trace.entryIncidenceDegrees {
    legs.append(
      ProbeLeg(
        label: "E",
        facet: facetName(solid, plane),
        incidence: degreeText(incidence),
        world: worldPoint(point)))
  }
  for (order, segment) in trace.segments.enumerated() {
    legs.append(
      ProbeLeg(
        label: String(order + 1),
        facet: facetName(solid, segment.plane),
        incidence: degreeText(segment.incidenceDegrees),
        world: worldPoint(segment.to)))
  }

  return ProbeReadout(
    legs: legs,
    ending: endingSentence(trace, legs: legs),
    leaked: leftThroughTheBack(trace, solid),
    entryStub: trace.entryPlane == nil
      ? nil
      : worldPoint((x: point.x, y: point.y, z: point.z + stubLength)),
    exitStub: exitStub(trace))
}

// MARK: - The pieces

/// Out of the back of the stone rather than back through the crown: the exit facet's own outward normal,
/// whose `z` is negative for every pavilion and girdle facet. Geometry, so it needs no tier and tests no
/// `part`.
private func leftThroughTheBack(_ trace: RayTrace, _ solid: BenchSolid) -> Bool {
  guard trace.ending == .left, let last = trace.segments.last else { return false }
  return solid.planes[last.plane].n.z < 0
}

/// How the path finished, as one sentence each way.
private func endingSentence(_ trace: RayTrace, legs: [ProbeLeg]) -> String {
  switch trace.ending {
  case .left:
    // The raw figures, so the sentence and the last leg's own incidence read the same number.
    return String(
      format: "Left through %@ at %.2f° — at or below the critical angle %.2f°.",
      legs.last?.facet ?? missingFacetName,
      trace.segments.last?.incidenceDegrees ?? 0,
      trace.criticalAngleDegrees)
  case .cappedAtBounceLimit:
    return
      "Still bouncing after \(probeBounceLimit) reflections — the path is truncated, not finished."
  case .noEntry:
    guard !trace.segments.isEmpty else {
      // A pavilion facet faces down, a girdle facet is parallel to the ray, a rough wall is neither, and
      // the kernel answers all three the same way. Nothing here tests a `part` of its own.
      return "A vertical ray does not enter through this facet."
    }
    return
      "The trace found no next surface after \(trace.segments.count) legs, "
      + "which a convex solid should not allow."
  }
}

/// Where the ray went after it left, half a unit on from the facet it left through. `nil` unless it left.
private func exitStub(_ trace: RayTrace) -> SIMD3<Float>? {
  guard let direction = trace.exitDirection, let last = trace.segments.last else { return nil }
  // Normalised, because Snell's law on the way out returns a unit vector only for a unit input, and a
  // stub of the wrong length is a wrong picture.
  let unit = normalised(direction)
  return worldPoint(
    (
      x: last.to.x + unit.x * stubLength,
      y: last.to.y + unit.y * stubLength,
      z: last.to.z + unit.z * stubLength
    ))
}

/// The facet's own name from the drawn solid's origin map. A plane with no entry reads `—` rather than an
/// invented name: impossible today, and a missing entry is something a test can see.
private func facetName(_ solid: BenchSolid, _ plane: Int) -> String {
  solid.origin[plane].map(facetLabel) ?? missingFacetName
}

/// The overlay projects `Float` world points, which is what the renderer's own matrices take.
private func worldPoint(_ point: (x: Double, y: Double, z: Double)) -> SIMD3<Float> {
  SIMD3(Float(point.x), Float(point.y), Float(point.z))
}

private func degreeText(_ degrees: Double) -> String {
  String(format: "%.2f°", degrees)
}

private func normalised(
  _ vector: (x: Double, y: Double, z: Double)
) -> (x: Double, y: Double, z: Double) {
  let length = (vector.x * vector.x + vector.y * vector.y + vector.z * vector.z).squareRoot()
  guard length > 0 else { return vector }
  return (x: vector.x / length, y: vector.y / length, z: vector.z / length)
}

/// Reflections, not segments. Eight rather than the kernel's default of thirty-two: a longer path is not a
/// picture anyone reads, and the kernel's own ending says the path was truncated rather than finished, so
/// the card can say so honestly. One constant, so the cap and the sentence reporting it cannot drift.
private let probeBounceLimit = 8

/// Against a stone whose girdle radius is about `1`, so a stub reads as a direction without dominating
/// the picture.
private let stubLength = 0.5

/// Never a made-up name.
private let missingFacetName = "—"
