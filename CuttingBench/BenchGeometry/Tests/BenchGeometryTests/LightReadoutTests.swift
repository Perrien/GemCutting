import FacetKernel
import Foundation
import XCTest

@testable import BenchGeometry

/// The Light card's contents. `AuthoredPatterns` lives in `BenchSolidTests.swift`.
final class LightReadoutTests: XCTestCase {

  // MARK: - The round brilliant, at its own refractive index

  func testTheRoundBrilliantClearsTheCriticalAngleOnBothPavilionTiers() throws {
    let pattern = try AuthoredPatterns.load(AuthoredPatterns.roundBrilliant)
    let summary = try measured(pattern: pattern, riOverride: "")

    XCTAssertEqual(summary.criticalAngle, "40.49°")
    XCTAssertEqual(summary.refractiveIndex, "1.54")
    XCTAssertEqual(summary.pavilionTiers.map(\.tier), ["pb", "pm"])
    XCTAssertEqual(summary.pavilionTiers.map(\.angle), ["45.00°", "43.00°"])
    XCTAssertEqual(summary.pavilionTiers.map(\.margin), ["4.51° clear", "2.51° clear"])
    XCTAssertEqual(summary.pavilionTiers.map(\.leaks), [false, false])
    XCTAssertTrue(summary.leakingTiers.isEmpty)
  }

  /// The override is the only way a leaking state can be reached: no authored pattern leaks at `1.54`.
  func testAtOneThirtyBothPavilionTiersOfTheRoundBrilliantLeak() throws {
    let pattern = try AuthoredPatterns.load(AuthoredPatterns.roundBrilliant)
    let summary = try measured(pattern: pattern, riOverride: "1.30")

    XCTAssertEqual(summary.criticalAngle, "50.28°")
    XCTAssertEqual(summary.refractiveIndex, "1.30 (override)")
    XCTAssertEqual(summary.pavilionTiers.map(\.angle), ["45.00°", "43.00°"])
    XCTAssertEqual(summary.pavilionTiers.map(\.margin), ["5.28° shallow", "7.28° shallow"])
    XCTAssertEqual(summary.pavilionTiers.map(\.leaks), [true, true])
    XCTAssertEqual(summary.leakingTiers, ["pb", "pm"])
  }

  // MARK: - The rules that hold over the whole corpus

  /// The word says which side of the critical angle the tier is on, so neither form ever needs a sign.
  func testNoMarginEverCarriesAMinusSign() throws {
    for name in AuthoredPatterns.all {
      let pattern = try AuthoredPatterns.load(name)
      for riOverride in ["1.30", "1.54"] {
        let summary = try measured(pattern: pattern, riOverride: riOverride)
        for row in summary.pavilionTiers {
          XCTAssertFalse(row.margin.contains("-"), "\(name) · \(riOverride) · \(row.tier)")
        }
      }
    }
  }

  /// The check asks whether a vertical ray reflects off the pavilion, and the pavilion is the only place
  /// that ray lands — so a `42.00°` crown tier and a `90.00°` girdle tier stay unmarked at an override
  /// whose critical angle is `50.28°`, while a shallower pavilion tier marks.
  func testOnlyPavilionTiersEverLeak() throws {
    for name in AuthoredPatterns.all {
      let pattern = try AuthoredPatterns.load(name)
      let summary = try measured(pattern: pattern, riOverride: "1.30")
      let pavilion = Set(pattern.tiers.filter { $0.part == .pav }.map(\.tier))

      XCTAssertFalse(summary.leakingTiers.isEmpty, name)
      XCTAssertTrue(summary.leakingTiers.isSubset(of: pavilion), name)
    }
  }

  /// The kernel lets a ray out at exactly the critical angle, so a tier sitting exactly there must mark —
  /// otherwise the table and a traced path would disagree on the one case hardest to explain. Asserted on
  /// a constructed tier, because no authored fixture may be edited to produce one.
  func testATierSittingExactlyAtTheCriticalAngleLeaks() throws {
    let exact = criticalAngleDegrees(ri: 1.54)
    let pattern = synthetic([
      TierSpec(tier: "p", part: .pav, angle: exact, indices: [0], meet: .tcp)
    ])
    let summary = try measured(pattern: pattern, riOverride: "")

    XCTAssertEqual(summary.leakingTiers, ["p"])
    XCTAssertEqual(summary.pavilionTiers.map(\.leaks), [true])
    XCTAssertEqual(summary.pavilionTiers.map(\.margin), ["0.00° shallow"])
  }

  // MARK: - The override field, which is free text

  func testTextThatIsNotARefractiveIndexFallsBackToThePatternsOwn() throws {
    let pattern = try AuthoredPatterns.load(AuthoredPatterns.roundBrilliant)

    for text in ["", "  ", "abc", "0", "-2"] {
      XCTAssertEqual(
        effectiveRefractiveIndex(pattern: pattern, override: text), 1.54,
        text.debugDescription)
    }
  }

  /// `criticalAngleDegrees(ri:)` answers a medium no denser than air honestly with `90°`, so a number
  /// above `0` is passed through however small — every pavilion tier marking is the right answer.
  func testANumberAtOrBelowOneIsPassedThroughRatherThanRejected() throws {
    let pattern = try AuthoredPatterns.load(AuthoredPatterns.roundBrilliant)
    XCTAssertEqual(effectiveRefractiveIndex(pattern: pattern, override: "0.9"), 0.9)
  }

  /// A trailing separator is a number to Swift, and the field is passed through rather than second-guessed
  /// for it: rejecting `1.` would take a syntax rule that a bare `1` on the way to `1.54` defeats anyway,
  /// and both reach the same honest `90°`.
  func testAHalfTypedNumberIsTheNumberSwiftReadsIt() throws {
    let pattern = try AuthoredPatterns.load(AuthoredPatterns.roundBrilliant)
    XCTAssertEqual(effectiveRefractiveIndex(pattern: pattern, override: "1."), 1.0)
    XCTAssertEqual(effectiveRefractiveIndex(pattern: pattern, override: "1"), 1.0)
  }

  func testWithNoPatternThereIsNoRefractiveIndexAtAll() {
    XCTAssertNil(effectiveRefractiveIndex(pattern: nil, override: "1.30"))
  }

  // MARK: - No pattern, and the sentence both cards say

  func testWithNoPatternTheCardSaysExactlyWhatTheMetricsCardSays() {
    let solid = benchSolid(for: nil)
    XCTAssertEqual(
      lightReadout(pattern: nil, solid: solid, riOverride: ""), .unavailable("No pattern open."))
    XCTAssertEqual(unmeasurableReason(pattern: nil, solid: solid), "No pattern open.")
  }

  // MARK: - The probe's precondition

  func testTheProbeIsOfferedForEveryAuthoredPatternAndNotForAnOpenSolid() throws {
    for name in AuthoredPatterns.all {
      let pattern = try AuthoredPatterns.load(name)
      let summary = try measured(pattern: pattern, riOverride: "")
      XCTAssertEqual(summary.probe, .available, name)
    }

    // A solid still carrying the scaffolding, paired with a pattern so the readout reaches the probe at
    // all: what the precondition reads is the solid, not the pattern.
    let openSummary = try measured(
      pattern: try AuthoredPatterns.load(AuthoredPatterns.roundBrilliant),
      solid: benchSolid(for: nil),
      riOverride: "")
    XCTAssertEqual(
      openSummary.probe,
      .unavailable(
        "The probe needs a closed stone: the pattern's own planes do not bound one yet."))
  }

  // MARK: - No solve needed

  /// The Metrics card can only give a reason for a part-cut stone. This one is arithmetic over the
  /// authored angles, so it reports every pavilion tier the author wrote whatever the solve reached.
  func testAPartCutStoneStillReportsEveryPavilionTier() throws {
    let pattern = try AuthoredPatterns.load(AuthoredPatterns.easyOctagon)
    let solid = benchSolid(for: pattern, tierLimit: 2)
    let summary = try measured(pattern: pattern, solid: solid, riOverride: "")

    XCTAssertNotNil(unmeasurableReason(pattern: pattern, solid: solid))
    XCTAssertEqual(summary.pavilionTiers.map(\.tier), ["P1", "P2"])
    XCTAssertEqual(summary.pavilionTiers.map(\.angle), ["47.60°", "43.00°"])
  }

  // MARK: - The caveat, and the tier table's one way in

  func testTheCaveatSaysExactlyWhatTheCheckCanClaim() {
    XCTAssertEqual(
      lightCaveat, "A marked tier leaks a vertical ray. Nothing here says a stone performs well.")
  }

  func testLeakingRowAnswersOnlyForATierThatLeaks() throws {
    let pattern = try AuthoredPatterns.load(AuthoredPatterns.roundBrilliant)
    let solid = benchSolid(for: pattern)

    let clear = lightReadout(pattern: pattern, solid: solid, riOverride: "")
    XCTAssertNil(clear.leakingRow("pb"))

    let leaking = lightReadout(pattern: pattern, solid: solid, riOverride: "1.30")
    XCTAssertEqual(leaking.leakingRow("pb")?.margin, "5.28° shallow")
    XCTAssertNil(leaking.leakingRow("cm"))
    XCTAssertNil(leaking.leakingRow("nosuchtier"))
    XCTAssertNil(LightReadout.unavailable("No pattern open.").leakingRow("pb"))
  }

  // MARK: - Helpers

  private func synthetic(_ tiers: [TierSpec]) -> FacetKernel.Pattern {
    FacetKernel.Pattern(
      formatVersion: 1,
      name: "synthetic",
      state: .inProgress,
      wheel: 96,
      ri: 1.54,
      designer: "",
      notes: "",
      tiers: tiers)
  }

  /// The summary, or a thrown failure naming the sentence that came out instead.
  private func measured(
    pattern: FacetKernel.Pattern, solid: BenchSolid? = nil, riOverride: String
  ) throws -> LightSummary {
    let readout = lightReadout(
      pattern: pattern, solid: solid ?? benchSolid(for: pattern), riOverride: riOverride)
    guard case .measured(let summary) = readout else { throw Unmeasured(readout: readout) }
    return summary
  }
}

/// Thrown rather than skipped: a readout that gives a reason where a summary was expected is a failure,
/// not a case to pass over.
private struct Unmeasured: Error, CustomStringConvertible {
  let readout: LightReadout
  var description: String { "expected a measured readout, got \(readout)" }
}
