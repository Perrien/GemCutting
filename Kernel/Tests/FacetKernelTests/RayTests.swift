import Foundation
import XCTest

@testable import FacetKernel

/// One ray, one wavelength, one path. What the probe is for is the question a faceter asks about a
/// pattern — where does the light go, and does this pavilion leak — so the checks below are the ones a
/// faceter would recognise: a vertical ray's incidence is the facet's own mast angle, and a 35-degree
/// pavilion in quartz leaks.
final class RayTests: XCTestCase {

  // MARK: - The critical angle

  func testTheCriticalAngleOfQuartzAndDiamond() {
    XCTAssertEqual(criticalAngleDegrees(ri: 1.54), 40.49266, accuracy: 1e-5)
    XCTAssertEqual(criticalAngleDegrees(ri: 2.16), 27.57847, accuracy: 1e-5)
  }

  /// Nothing is trapped in a medium no denser than air, so there is no angle beyond which a ray reflects.
  func testNothingIsTrappedInAirOrThinner() {
    XCTAssertEqual(criticalAngleDegrees(ri: 1), 90)
    XCTAssertEqual(criticalAngleDegrees(ri: 0.9), 90)
  }

  // MARK: - Into a real stone

  /// A ray straight down through the table meets a pavilion facet at that facet's own mast angle — the
  /// cleanest possible check on the incidence arithmetic, because the answer is a number the sheet prints.
  /// The round brilliant's pavilion tiers are 45 and 43 degrees, and which one a given ray finds depends
  /// on where across the table it entered.
  func testAVerticalRayMeetsThePavilionAtItsMastAngle() throws {
    let stone = try Self.roundBrilliant()
    let trace = traceRay(
      in: stone.solution.planes,
      ri: stone.pattern.ri,
      from: stone.pointOn(tier: "t", index: 0, offset: 0.4),
      direction: (x: 0, y: 0, z: -1)
    )

    XCTAssertEqual(trace.entryPlane, try stone.plane(tier: "t", index: 0))
    XCTAssertEqual(try XCTUnwrap(trace.entryIncidenceDegrees), 0, accuracy: 1e-9)

    let first = try XCTUnwrap(trace.segments.first)
    let mastAngles = [43.0, 45.0]
    XCTAssertTrue(
      mastAngles.contains { abs($0 - first.incidenceDegrees) <= 1e-9 },
      "first incidence \(first.incidenceDegrees) is neither pavilion angle"
    )
    XCTAssertGreaterThan(first.incidenceDegrees, trace.criticalAngleDegrees)
    XCTAssertGreaterThan(
      trace.segments.count, 1,
      "above the critical angle it reflects, so it cannot have left on the first surface"
    )
  }

  /// Snell's law on entry, on a facet that is not horizontal so there is a bend to measure. `cb` is cut at
  /// 47 degrees, so a ray straight down arrives 47 degrees off its normal, and inside quartz that becomes
  /// 28.35316 degrees. The last assertion is the law itself rather than the arithmetic: a sign slip that
  /// happened to land near the right number would still fail it.
  func testSnellHoldsOnEntry() throws {
    let stone = try Self.roundBrilliant()
    let entryPlane = try stone.plane(tier: "cb", index: 3)
    let trace = traceRay(
      in: stone.solution.planes,
      ri: stone.pattern.ri,
      from: stone.pointOn(tier: "cb", index: 3, offset: 0.4),
      direction: (x: 0, y: 0, z: -1)
    )

    XCTAssertEqual(trace.entryPlane, entryPlane)
    XCTAssertEqual(try XCTUnwrap(trace.entryIncidenceDegrees), 47.0, accuracy: 1e-9)

    let first = try XCTUnwrap(trace.segments.first)
    let inside = normalized(subtract(first.to, first.from))
    let normal = stone.solution.planes[entryPlane].n
    let bent = acos(-dot(inside, normal)) * 180 / Double.pi
    XCTAssertEqual(bent, 28.35316, accuracy: 1e-4)

    let radians = Double.pi / 180
    XCTAssertEqual(sin(47 * radians), stone.pattern.ri * sin(bent * radians), accuracy: 1e-12)
  }

  // MARK: - Which side the ray leaves by

  /// Light enters through the crown or the table and should leave the same way. Out through the pavilion
  /// or the girdle is a leak — that is the whole difference between a stone that works and one that does
  /// not, and it is a property of where the last segment ends rather than of any single incidence.
  ///
  /// **It holds for light arriving near the axis, and it is not a universal law.** Measured on this stone:
  /// a ray entering the table within about 17 degrees of vertical comes back out of the table or a star
  /// facet, and beyond that it leaves straight through a pavilion main on the first surface. That is the
  /// brilliant's own behaviour — steeply angled light is what a real one leaks — and it is what the probe
  /// exists to show, not something for it to hide.
  func testARayNearTheAxisLeavesByTheCrownAndASteepOneLeaks() throws {
    let stone = try Self.roundBrilliant()
    let entry = stone.pointOn(tier: "t", index: 0, offset: 0.4)

    for direction in [(x: 0.0, y: 0.0, z: -1.0), (x: 0.1, y: 0.05, z: -1.0)] {
      let trace = traceRay(
        in: stone.solution.planes, ri: stone.pattern.ri, from: entry, direction: direction)

      XCTAssertEqual(trace.ending, .left, "\(direction)")
      let exit = try stone.part(whereItLeft: trace)
      XCTAssertTrue(
        [Part.table, .crown].contains(exit),
        "a ray this near the axis has to leave by the crown or the table, not the \(exit.rawValue)"
      )
    }

    let steep = traceRay(
      in: stone.solution.planes,
      ri: stone.pattern.ri,
      from: entry,
      direction: (x: 0.5, y: 0.25, z: -1)
    )
    XCTAssertEqual(steep.ending, .left)
    XCTAssertEqual(steep.segments.count, 1, "it leaks on the first surface it reaches")
    XCTAssertEqual(
      try stone.part(whereItLeft: steep), .pav,
      "steeply angled light leaves through the pavilion, which is what a real brilliant does"
    )
  }

  // MARK: - A stone that leaks

  /// A 35-degree pavilion in quartz is below the 40.49-degree critical angle, so a ray straight down
  /// through the table passes out of the back instead of bouncing. This is the reading the probe exists to
  /// give, and the stone is built here rather than authored because no real sheet publishes a leak.
  func testAShallowPavilionLeaksAndTheTraceSaysSo() throws {
    let pattern = Self.shallow
    let solution = try solve(pattern)

    // The stone this is a claim about: girdle, pavilion and table at these offsets, and nothing else.
    XCTAssertEqual(solution.polytope.facets.count, 17)
    XCTAssertEqual(solution.tiers.map { $0.tier }, ["G", "P", "T"])
    XCTAssertEqual(solution.tiers[0].d, 1.000000, accuracy: 1e-6)
    XCTAssertEqual(solution.tiers[1].d, 0.573576, accuracy: 1e-6)
    XCTAssertEqual(solution.tiers[2].d, 0.080000, accuracy: 1e-6)

    let trace = traceRay(
      in: solution.planes,
      ri: pattern.ri,
      from: (x: 0.2, y: 0.05, z: 0.08),
      direction: (x: 0, y: 0, z: -1)
    )

    // No bend at normal incidence: the table is horizontal and the ray arrives straight down.
    XCTAssertEqual(try XCTUnwrap(trace.entryIncidenceDegrees), 0, accuracy: 1e-12)
    let first = try XCTUnwrap(trace.segments.first)
    let inside = normalized(subtract(first.to, first.from))
    XCTAssertEqual(distance(inside, (x: 0, y: 0, z: -1)), 0, accuracy: 1e-12)

    XCTAssertEqual(trace.segments.count, 1)
    XCTAssertEqual(first.incidenceDegrees, 35.0, accuracy: 1e-9)
    XCTAssertLessThan(first.incidenceDegrees, trace.criticalAngleDegrees)
    XCTAssertEqual(trace.ending, .left)
    XCTAssertNotNil(trace.exitDirection)
    XCTAssertEqual(
      try Self.part(whereItLeft: trace, of: pattern, solution),
      .pav,
      "it leaves through the pavilion, which is the definition of a leaking stone"
    )
  }

  // MARK: - The two ways a trace stops early

  /// The cap is reachable and deterministic, and it says the path is truncated rather than finished.
  func testTheBounceLimitCapsThePath() throws {
    let stone = try Self.roundBrilliant()
    let trace = traceRay(
      in: stone.solution.planes,
      ri: stone.pattern.ri,
      from: stone.pointOn(tier: "t", index: 0, offset: 0.4),
      direction: (x: 0, y: 0, z: -1),
      bounceLimit: 1
    )

    XCTAssertEqual(trace.ending, .cappedAtBounceLimit)
    XCTAssertEqual(trace.segments.count, 1)
    XCTAssertNil(trace.exitDirection)
  }

  /// Both ways of missing the stone: a point that is not on it, and a point on it aimed away from it.
  func testNoEntryCoversBothWaysOfMissing() throws {
    let stone = try Self.roundBrilliant()

    let outside = traceRay(
      in: stone.solution.planes,
      ri: stone.pattern.ri,
      from: (x: 5, y: 5, z: 5),
      direction: (x: 0, y: 0, z: -1)
    )
    XCTAssertEqual(outside.ending, .noEntry)
    XCTAssertTrue(outside.segments.isEmpty)
    XCTAssertNil(outside.entryPlane)

    let facingAway = traceRay(
      in: stone.solution.planes,
      ri: stone.pattern.ri,
      from: stone.pointOn(tier: "t", index: 0, offset: 0.4),
      direction: (x: 0, y: 0, z: 1)
    )
    XCTAssertEqual(facingAway.ending, .noEntry)
    XCTAssertTrue(facingAway.segments.isEmpty)
  }

  // MARK: - Every segment, whatever the ray does

  /// Whatever path a ray takes, each segment ends on the plane it names and arrives at an angle that is an
  /// angle. Checked across a fan of directions so it is not one lucky path.
  func testEverySegmentEndsOnTheSolid() throws {
    let stone = try Self.roundBrilliant()
    let entry = stone.pointOn(tier: "t", index: 0, offset: 0.4)

    for tilt in stride(from: 0.0, through: 0.5, by: 0.1) {
      let trace = traceRay(
        in: stone.solution.planes,
        ri: stone.pattern.ri,
        from: entry,
        direction: (x: tilt, y: tilt / 2, z: -1)
      )
      XCTAssertFalse(trace.segments.isEmpty, "tilt \(tilt)")

      for segment in trace.segments {
        let plane = stone.solution.planes[segment.plane]
        XCTAssertEqual(dot(plane.n, segment.to), plane.d, accuracy: 1e-7, "tilt \(tilt)")
        XCTAssertGreaterThanOrEqual(segment.incidenceDegrees, 0, "tilt \(tilt)")
        XCTAssertLessThan(segment.incidenceDegrees, 90, "tilt \(tilt)")
      }
    }
  }

  // MARK: - Verification handle (T9, permanent)

  /// Prints the traced path for the round brilliant, then the same for the 35-degree pattern that leaks.
  ///
  /// Positive: every incidence before the last is greater than 40.49, and the tiers named are pavilion and
  /// crown tiers of that stone. Negative: the shallow pattern prints a single bounce at 35.00 and `left`.
  func testDump() throws {
    let stone = try Self.roundBrilliant()
    print(
      Self.dump(
        "round brilliant",
        traceRay(
          in: stone.solution.planes,
          ri: stone.pattern.ri,
          from: stone.pointOn(tier: "t", index: 0, offset: 0.4),
          direction: (x: 0, y: 0, z: -1)
        ),
        owners: stone.solution.planeOwner
      ))

    let shallow = try solve(Self.shallow)
    print(
      Self.dump(
        "35-degree pavilion",
        traceRay(
          in: shallow.planes,
          ri: Self.shallow.ri,
          from: (x: 0.2, y: 0.05, z: 0.08),
          direction: (x: 0, y: 0, z: -1)
        ),
        owners: shallow.planeOwner
      ))
  }

  private static func dump(
    _ name: String,
    _ trace: RayTrace,
    owners: [Int: (tier: String, index: Int)]
  ) -> String {
    var lines = [
      "\(name): critical angle \(String(format: "%.2f", trace.criticalAngleDegrees))"
    ]
    for (step, segment) in trace.segments.enumerated() {
      let owner = owners[segment.plane]
      let facet = owner.map { "\($0.tier)@\($0.index)" } ?? "plane \(segment.plane)"
      let reflected = segment.incidenceDegrees > trace.criticalAngleDegrees
      lines.append(
        "  \(step + 1). \(facet.padding(toLength: 8, withPad: " ", startingAt: 0))"
          + "incidence \(String(format: "%6.2f", segment.incidenceDegrees))  "
          + (reflected ? "reflected" : "left")
      )
    }
    lines.append("  ending: \(trace.ending.rawValue)")
    return lines.joined(separator: "\n")
  }

  // MARK: - The stones

  /// The round brilliant solved at the 2% girdle its own sheet states, plus the lookups a test needs to
  /// name an entry point by facet rather than by coordinate.
  private struct Stone {
    let pattern: FacetKernel.Pattern
    let solution: Solution

    func plane(tier: String, index: Int) throws -> Int {
      try XCTUnwrap(
        solution.planeOwner.first { $0.value.tier == tier && $0.value.index == index }?.key,
        "no plane owned by \(tier)@\(index)"
      )
    }

    /// Which part of the stone the ray left through: the part of the tier owning its last surface.
    func part(whereItLeft trace: RayTrace) throws -> Part {
      try RayTests.part(whereItLeft: trace, of: pattern, solution)
    }

    /// A point inside the named facet's polygon: its centroid, moved `offset` of the way towards one of
    /// its corners so a ray does not enter on the axis or on an edge.
    func pointOn(
      tier: String,
      index: Int,
      offset: Double
    ) -> (x: Double, y: Double, z: Double) {
      guard let plane = try? plane(tier: tier, index: index),
        let polygon = solution.polytope.facets[plane],
        let corner = polygon.first
      else { return (x: 0, y: 0, z: 0) }

      let points = polygon.map { solution.polytope.vertices[$0] }
      let count = Double(points.count)
      let centre = (
        x: points.reduce(0) { $0 + $1.x } / count,
        y: points.reduce(0) { $0 + $1.y } / count,
        z: points.reduce(0) { $0 + $1.z } / count
      )
      let towards = solution.polytope.vertices[corner]
      return (
        x: centre.x + (towards.x - centre.x) * offset,
        y: centre.y + (towards.y - centre.y) * offset,
        z: centre.z + (towards.z - centre.z) * offset
      )
    }
  }

  private static func roundBrilliant() throws -> Stone {
    let pattern = try AuthoredPatterns.load(AuthoredPatterns.roundBrilliant)
    return Stone(pattern: pattern, solution: try solve(pattern))
  }

  /// The part of the stone a trace's last surface belongs to. The kernel reports the plane; which side of
  /// the stone that plane is on is the pattern's own `part`, so the two are read together here rather than
  /// a side being stored on the trace.
  private static func part(
    whereItLeft trace: RayTrace,
    of pattern: FacetKernel.Pattern,
    _ solution: Solution
  ) throws -> Part {
    let last = try XCTUnwrap(trace.segments.last, "the ray touched no surface")
    let owner = try XCTUnwrap(solution.planeOwner[last.plane], "plane \(last.plane) has no owner")
    let spec = try XCTUnwrap(
      pattern.tiers.first { $0.tier == owner.tier }, "no tier \(owner.tier)")
    return spec.part
  }

  /// A stone that leaks: quartz, a girdle, a 35-degree pavilion and a table. At the 0.04 default it solves
  /// clean to 17 facets, and 35 degrees is well below quartz's 40.49-degree critical angle.
  private static let shallow = FacetKernel.Pattern(
    formatVersion: 1,
    name: "Shallow Pavilion",
    state: .inProgress,
    wheel: 96,
    ri: 1.54,
    designer: "",
    notes: "",
    tiers: [
      TierSpec(tier: "G", part: .gdl, angle: 90, indices: octagon, meet: .size),
      TierSpec(tier: "P", part: .pav, angle: 35, indices: octagon, meet: .tcp),
      TierSpec(tier: "T", part: .table, angle: 0, indices: [0], meet: .girdle),
    ]
  )

  private static let octagon = [0, 12, 24, 36, 48, 60, 72, 84]
}
