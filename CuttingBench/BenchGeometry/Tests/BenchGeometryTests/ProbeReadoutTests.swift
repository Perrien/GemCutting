import FacetKernel
import Foundation
import XCTest

@testable import BenchGeometry

/// One traced ray, as the card lists it and the overlay draws it. `AuthoredPatterns` lives in
/// `BenchSolidTests.swift`.
final class ProbeReadoutTests: XCTestCase {

  // MARK: - Entering through the table

  /// The classic table test: a vertical ray onto a `0.00°` table arrives at zero incidence.
  func testTheEntryLegNamesTheTableAndArrivesSquareOnIt() throws {
    let probe = try tableProbe(AuthoredPatterns.roundBrilliant, ri: 1.54).probe

    XCTAssertEqual(probe.legs.first?.label, "E")
    XCTAssertEqual(probe.legs.first?.incidence, "0.00°")
    XCTAssertTrue(
      probe.legs.first?.facet.hasPrefix("t · ") ?? false, "\(probe.legs.first?.facet ?? "none")")
  }

  /// **The claim the whole critical-angle check rests on.** A ray entering through a `0.00°` table is
  /// undeviated, so its incidence on a pavilion facet is exactly that tier's authored angle — which is why
  /// the tier table can mark a leak from the authored angle alone, with no geometry at all.
  func testTheFirstBouncesIncidenceIsTheAuthoredAngleOfTheTierItLandedOn() throws {
    let pattern = try AuthoredPatterns.load(AuthoredPatterns.roundBrilliant)
    let probe = probeTrace(
      benchSolid(for: pattern), ri: 1.54, from: try tablePoint(pattern).point)

    let bounce = try XCTUnwrap(probe.legs.dropFirst().first)
    let tier = try XCTUnwrap(bounce.facet.split(separator: " · ").first.map(String.init))
    let spec = try XCTUnwrap(pattern.tiers.first { $0.tier == tier })

    XCTAssertEqual(spec.part, .pav)
    XCTAssertEqual(bounce.incidence, String(format: "%.2f°", spec.angle))
  }

  /// A pavilion facet at `45.00°` or `43.00°` is above the `40.49°` critical angle, so the ray must
  /// reflect and must therefore reach a further surface — twice off the pavilion and back out the table.
  func testAtItsOwnIndexTheRayReflectsAndTravelsOn() throws {
    let probe = try tableProbe(AuthoredPatterns.roundBrilliant, ri: 1.54).probe

    XCTAssertGreaterThanOrEqual(probe.legs.count, 3)
    XCTAssertFalse(probe.leaked)
  }

  /// At `1.30` the first pavilion facet is at or below the critical angle, so the ray leaves on its first
  /// bounce — the leak the probe exists to find.
  func testAtOneThirtyTheRayLeavesOnItsFirstBounce() throws {
    let probe = try tableProbe(AuthoredPatterns.roundBrilliant, ri: 1.30).probe

    XCTAssertEqual(probe.legs.count, 2)
    XCTAssertTrue(probe.leaked)
    XCTAssertTrue(probe.ending.hasPrefix("Left through "), probe.ending)
    XCTAssertTrue(probe.ending.contains("50.28°"), probe.ending)
  }

  // MARK: - The two stubs

  func testTheEntryStubRisesHalfAUnitAboveTheEntryPoint() throws {
    let probe = try tableProbe(AuthoredPatterns.roundBrilliant, ri: 1.54).probe

    let entry = try XCTUnwrap(probe.legs.first?.world)
    let stub = try XCTUnwrap(probe.entryStub)
    XCTAssertEqual(distance(stub, entry + SIMD3(0, 0, 0.5)), 0, accuracy: 1e-6)
  }

  /// The exit direction is normalised before it is scaled, or the stub would be the wrong length for a
  /// vector Snell's law did not return as a unit one.
  func testTheExitStubIsHalfAUnitPastTheFacetTheRayLeftThrough() throws {
    let leaking = try tableProbe(AuthoredPatterns.roundBrilliant, ri: 1.30).probe

    let last = try XCTUnwrap(leaking.legs.last?.world)
    let stub = try XCTUnwrap(leaking.exitStub)
    XCTAssertEqual(distance(stub, last), 0.5, accuracy: 1e-6)
  }

  /// **The distinction the exit stub's colour rests on.** At its own refractive index the ray comes back
  /// out through the table — the stone working — so there is an exit stub and it is not a leak. At `1.30`
  /// the same click goes out of the back. Both over the whole corpus, because a picture that called every
  /// correct stone a leak would be worse than no picture.
  func testAnExitThroughTheCrownIsNotALeakAndAnExitThroughThePavilionIs() throws {
    for name in AuthoredPatterns.all {
      let returning = try tableProbe(name, ri: 1.54).probe
      XCTAssertNotNil(returning.exitStub, name)
      XCTAssertFalse(returning.leaked, "\(name) returns through the crown: \(returning.ending)")

      let window = try tableProbe(name, ri: 1.30).probe
      XCTAssertNotNil(window.exitStub, name)
      XCTAssertTrue(window.leaked, "\(name) goes out of the back: \(window.ending)")
    }
  }

  // MARK: - The clicks that trace nothing

  /// A pavilion facet faces down, so a ray going down cannot enter through it. The kernel decides that,
  /// and this only says so in words.
  func testAVerticalRayDoesNotEnterThroughAPavilionFacet() throws {
    let pattern = try AuthoredPatterns.load(AuthoredPatterns.roundBrilliant)
    let solid = benchSolid(for: pattern)
    let hit = try XCTUnwrap(pickFacet(solid, origin: SIMD3(0, 0, -6), direction: SIMD3(0, 0, 1)))
    let probe = probeTrace(solid, ri: 1.54, from: hit.point)

    XCTAssertTrue(probe.legs.isEmpty)
    XCTAssertNil(probe.entryStub)
    XCTAssertNil(probe.exitStub)
    XCTAssertFalse(probe.leaked)
    XCTAssertEqual(probe.ending, "A vertical ray does not enter through this facet.")
  }

  /// The guard is belt and braces — the toggle is unavailable here — and it says exactly what the card
  /// says in its place, character for character.
  func testAnOpenSolidTracesNothingAndSaysWhatTheCardSays() throws {
    let pattern = try AuthoredPatterns.load(AuthoredPatterns.roundBrilliant)
    let probe = probeTrace(benchSolid(for: nil), ri: 1.54, from: (x: 0, y: 0, z: 1))

    let readout = lightReadout(pattern: pattern, solid: benchSolid(for: nil), riOverride: "")
    guard case .measured(let summary) = readout,
      case .unavailable(let sentence) = summary.probe
    else {
      return XCTFail("the card should give the closed-stone sentence for an open solid")
    }

    XCTAssertTrue(probe.legs.isEmpty)
    XCTAssertEqual(probe.ending, sentence)
  }

  // MARK: - The invariant: every leg carries a real facet name

  /// A `—` here would mean a plane the trace hit has no entry in the origin map, which is what the origin
  /// map exists to make impossible.
  func testNoLegEverReportsAnUnnamedFacet() throws {
    for name in AuthoredPatterns.all {
      let pattern = try AuthoredPatterns.load(name)
      let solid = benchSolid(for: pattern)

      for x in [-0.1, -0.05, 0.0, 0.05, 0.1] {
        for y in [-0.1, 0.0, 0.1] {
          let origin = SIMD3<Float>(Float(x), Float(y), 5)
          guard let hit = pickFacet(solid, origin: origin, direction: SIMD3(0, 0, -1)) else {
            continue
          }
          let probe = probeTrace(solid, ri: 1.54, from: hit.point)
          for leg in probe.legs {
            let context = "\(name) at \(x), \(y) · leg \(leg.label)"
            XCTAssertFalse(leg.facet.isEmpty, context)
            XCTAssertNotEqual(leg.facet, "—", context)
          }
        }
      }
    }
  }

  // MARK: - Helpers

  /// The click the app would make on the table, a little off its centre. Every test point comes through
  /// `pickFacet`, so none can start a ray off the surface — which is the path the app takes too.
  private func tablePoint(
    _ pattern: FacetKernel.Pattern
  ) throws -> (solid: BenchSolid, point: (x: Double, y: Double, z: Double)) {
    let solid = benchSolid(for: pattern)
    let hit = try XCTUnwrap(
      pickFacet(solid, origin: SIMD3(0.1, 0.05, 5), direction: SIMD3(0, 0, -1)))
    return (solid, hit.point)
  }

  private func tableProbe(
    _ name: String, ri: Double
  ) throws -> (solid: BenchSolid, probe: ProbeReadout) {
    let hit = try tablePoint(try AuthoredPatterns.load(name))
    return (hit.solid, probeTrace(hit.solid, ri: ri, from: hit.point))
  }

  private func distance(_ a: SIMD3<Float>, _ b: SIMD3<Float>) -> Double {
    let d = a - b
    return Double((d.x * d.x + d.y * d.y + d.z * d.z).squareRoot())
  }
}
