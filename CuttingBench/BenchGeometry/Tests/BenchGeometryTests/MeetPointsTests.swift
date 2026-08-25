import FacetKernel
import Foundation
import XCTest

@testable import BenchGeometry

/// The named points of a tier's meet, read off the corpus. `AuthoredPatterns` lives in
/// `BenchSolidTests.swift`.
final class MeetPointsTests: XCTestCase {

  // MARK: - Nothing to draw

  func testNoPatternAndAnUnknownTierGiveNoDots() throws {
    XCTAssertTrue(meetPointDots(ofTier: "P1", pattern: nil, solid: benchSolid(for: nil)).isEmpty)

    let pattern = try AuthoredPatterns.load(AuthoredPatterns.easyOctagon)
    XCTAssertTrue(
      meetPointDots(ofTier: "P9", pattern: pattern, solid: benchSolid(for: pattern)).isEmpty)
  }

  /// `size`, `tcp` and `girdle` name no facet triple, so they name no point. This is the negative half of
  /// the handle: selecting one of these three rows clears the viewport.
  func testTheThreeFormlessMeetsGiveNoDots() throws {
    let pattern = try AuthoredPatterns.load(AuthoredPatterns.noviceAsher)
    let solid = benchSolid(for: pattern)

    for tier in ["G", "P1", "C1"] {
      XCTAssertTrue(
        meetPointDots(ofTier: tier, pattern: pattern, solid: solid).isEmpty,
        "tier \(tier) names no facet triple")
    }
  }

  // MARK: - A plain vertex

  func testAPlainVertexGivesOneDot() throws {
    let pattern = try AuthoredPatterns.load(AuthoredPatterns.easyOctagon)
    let dots = meetPointDots(ofTier: "P2", pattern: pattern, solid: benchSolid(for: pattern))

    XCTAssertEqual(dots.count, 1)
    let dot = try XCTUnwrap(dots.first)
    XCTAssertEqual(dot.label, "M")
    XCTAssertEqual(dot.role, .vertex)
    XCTAssertEqual(dot.facets, "G1@0 · G1@12 · P1@0")
    XCTAssertEqual(dot.id, "P2-M")
    XCTAssertNotNil(dot.world)
  }

  /// The dot is the point the kernel measures, not a second point derived alongside it: it lands on a
  /// corner of the solid as it stands when P2 is cut.
  func testTheVertexDotIsAcornerOfTheIntermediateSolid() throws {
    let pattern = try AuthoredPatterns.load(AuthoredPatterns.easyOctagon)
    let solid = benchSolid(for: pattern)
    let solution = try XCTUnwrap(solid.solution)
    let world = try XCTUnwrap(
      meetPointDots(ofTier: "P2", pattern: pattern, solid: solid).first?.world)

    let corners = intermediateSolid(before: "P2", of: solution).vertices
    XCTAssertTrue(
      corners.contains { apart($0, world) <= 1e-7 },
      "the dot sits on no corner of the solid P2 is cut against")
  }

  // MARK: - A fraction

  func testAFractionGivesThreeDotsInReadingOrder() throws {
    let pattern = try AuthoredPatterns.load(AuthoredPatterns.noviceAsher)
    let dots = meetPointDots(ofTier: "P2", pattern: pattern, solid: benchSolid(for: pattern))

    XCTAssertEqual(dots.map(\.label), ["A", "24.86%", "B"])
    XCTAssertEqual(dots.map(\.role), [.endpointA, .anchored, .endpointB])
    XCTAssertEqual(dots.map(\.facets), ["G@12 · G@24 · P1@24", "", "tcp"])
    XCTAssertEqual(dots.map(\.id), ["P2-A", "P2-anchored", "P2-B"])
    for dot in dots {
      XCTAssertNotNil(dot.world, dot.label)
    }
  }

  /// The **B** dot of a `to: tcp` fraction *is* the axial point, and which axial point comes from the
  /// tier's own part: a pavilion tier's is below the girdle and the crown has its own above it.
  func testTheBDotIsTheAxialPointOnTheTiersOwnSide() throws {
    let pattern = try AuthoredPatterns.load(AuthoredPatterns.noviceAsher)
    let solid = benchSolid(for: pattern)

    let pavilion = try XCTUnwrap(
      meetPointDots(ofTier: "P2", pattern: pattern, solid: solid).last?.world)
    XCTAssertEqual(pavilion.x, 0)
    XCTAssertEqual(pavilion.y, 0)
    XCTAssertLessThan(pavilion.z, 0)

    let crown = try XCTUnwrap(
      meetPointDots(ofTier: "T", pattern: pattern, solid: solid).last?.world)
    XCTAssertEqual(crown.x, 0)
    XCTAssertEqual(crown.y, 0)
    XCTAssertGreaterThan(crown.z, 0)
  }

  func testTheAnchoredDotLiesBetweenItsEndpoints() throws {
    let pattern = try AuthoredPatterns.load(AuthoredPatterns.noviceAsher)
    let dots = meetPointDots(ofTier: "P2", pattern: pattern, solid: benchSolid(for: pattern))

    let a = try XCTUnwrap(dots.first?.world)
    let anchored = try XCTUnwrap(dots[1].world)
    let b = try XCTUnwrap(dots.last?.world)

    XCTAssertLessThan(anchored.z, a.z)
    XCTAssertGreaterThan(anchored.z, b.z)
    XCTAssertLessThan(anchored.x, a.x)
    XCTAssertGreaterThan(anchored.x, b.x)
  }

  // MARK: - A point the solve never reached

  /// The cell is read off the pattern and must not go blank because the solve fell short: the chip keeps
  /// its facet text and the viewport simply draws nothing.
  func testAnUnresolvablePointKeepsItsChipAndLosesItsDot() throws {
    let pattern = try AuthoredPatterns.load(AuthoredPatterns.easyOctagon)
    let dots = meetPointDots(
      ofTier: "C2", pattern: pattern, solid: benchSolid(for: pattern, tierLimit: 2))

    XCTAssertEqual(dots.count, 1)
    let dot = try XCTUnwrap(dots.first)
    XCTAssertEqual(dot.facets, "G1@12 · G1@24 · C1@12")
    XCTAssertNil(dot.world)
  }

  // MARK: - Helpers

  private func apart(_ point: (x: Double, y: Double, z: Double), _ world: SIMD3<Float>) -> Double {
    let dx = point.x - Double(world.x)
    let dy = point.y - Double(world.y)
    let dz = point.z - Double(world.z)
    return (dx * dx + dy * dy + dz * dz).squareRoot()
  }
}
