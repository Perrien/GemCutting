import FacetKernel
import Foundation
import XCTest

@testable import BenchGeometry

/// The per-tier cache behind the deferred half of validation. `AuthoredPatterns` lives in
/// `BenchSolidTests.swift`; `geometricFindings` is the uncached oracle every case here is read against.
final class FindingsCacheTests: XCTestCase {

  // MARK: - The oracle

  /// The whole point of the cache: filled from cold, concatenated in cutting order and topped with the
  /// whole-solid half, it is the uncached check element for element.
  func testACacheFilledFromColdEqualsTheUncachedCheck() throws {
    for name in AuthoredPatterns.all {
      let pattern = try AuthoredPatterns.load(name)
      let solution = try XCTUnwrap(benchSolid(for: pattern).solution, name)

      var cache = TierFindingsCache()
      let needed = cache.retain(pattern)
      XCTAssertEqual(needed, pattern.tiers.map(\.tier), name)

      let computed = try XCTUnwrap(
        runTierChecks(tiers: needed, pattern: pattern, solution: solution), name)
      for (tier, findings) in computed { cache.record(findings, forTier: tier) }

      let kept = try XCTUnwrap(cache.complete, name)
      let uncached = try XCTUnwrap(
        geometricFindings(pattern: pattern, solution: solution), name)
      XCTAssertEqual(kept + solidFindings(solution, declaredFacetCount: nil), uncached, name)
    }
  }

  /// The same equality after an edit, which is the case the cache actually runs in: one tier recomputed,
  /// five reused, and the answer still the uncached one.
  func testTheOracleStillHoldsAfterAnEditReusesFiveOfSixTiers() throws {
    let original = try AuthoredPatterns.load(AuthoredPatterns.easyOctagon)
    var cache = TierFindingsCache()
    try fill(&cache, original)

    var edited = original
    edited.tiers[edited.tiers.count - 1].instructions = "level table"

    let needed = cache.retain(edited)
    XCTAssertEqual(needed, ["T"])

    let solution = try XCTUnwrap(benchSolid(for: edited).solution)
    let computed = try XCTUnwrap(
      runTierChecks(tiers: needed, pattern: edited, solution: solution))
    for (tier, findings) in computed { cache.record(findings, forTier: tier) }

    let kept = try XCTUnwrap(cache.complete)
    let uncached = try XCTUnwrap(geometricFindings(pattern: edited, solution: solution))
    XCTAssertEqual(kept + solidFindings(solution, declaredFacetCount: nil), uncached)
  }

  // MARK: - The prefix rule, per field

  /// The fields that reach neither the solve nor validation keep every tier.
  func testAFieldThatCannotMoveGeometryKeepsEveryTier() throws {
    let pattern = try AuthoredPatterns.load(AuthoredPatterns.easyOctagon)
    let all = pattern.tiers.count

    var name = pattern
    name.name = "Renamed"
    var designer = pattern
    designer.designer = "Somebody Else"
    var notes = pattern
    notes.notes = "a note"
    var ri = pattern
    ri.ri = 1.77
    var state = pattern
    state.state = .inProgress
    var version = pattern
    version.formatVersion = 99

    for (label, moved) in [
      ("name", name), ("designer", designer), ("notes", notes), ("ri", ri), ("state", state),
      ("formatVersion", version),
    ] {
      XCTAssertEqual(survivingTierPrefix(from: pattern, to: moved), all, label)
    }
  }

  /// The gear enters every plane normal and the girdle target every girdle meet's depth, so either keeps
  /// nothing.
  func testAFieldThatCanMoveGeometryKeepsNothing() throws {
    let pattern = try AuthoredPatterns.load(AuthoredPatterns.easyOctagon)

    var wheel = pattern
    wheel.wheel = 64
    XCTAssertEqual(survivingTierPrefix(from: pattern, to: wheel), 0)

    var girdle = pattern
    girdle.girdleTargetFraction = 0.06
    XCTAssertEqual(survivingTierPrefix(from: pattern, to: girdle), 0)

    // Absent-versus-present is a change even when the present value is the default the absent one means:
    // the field is compared, not the resolved target.
    var defaulted = pattern
    defaulted.girdleTargetFraction = FacetKernel.Pattern.defaultGirdleTargetFraction
    XCTAssertNotEqual(pattern.girdleTargetFraction, defaulted.girdleTargetFraction)
    XCTAssertEqual(survivingTierPrefix(from: pattern, to: defaulted), 0)
  }

  func testNoPreviousPatternKeepsNothing() throws {
    let pattern = try AuthoredPatterns.load(AuthoredPatterns.easyOctagon)
    XCTAssertEqual(survivingTierPrefix(from: nil, to: pattern), 0)
  }

  /// A change to one tier keeps the tiers before it and no more, whichever of its fields moved.
  func testATierEditKeepsTheTiersBeforeIt() throws {
    let pattern = try AuthoredPatterns.load(AuthoredPatterns.easyOctagon)
    // `G1 P1 P2 C1 C2 T` — position 2 is P2, whose meet is a vertex naming G1 and P1.
    let at = 2

    var angle = pattern
    angle.tiers[at].angle += 1
    var indices = pattern
    indices.tiers[at].indices = [0, 24, 48, 72]
    var part = pattern
    part.tiers[at].part = .gdl
    var wheel = pattern
    wheel.tiers[at].wheel = 64
    var meet = pattern
    meet.tiers[at].meet = .tcp
    var instructions = pattern
    instructions.tiers[at].instructions = "slow"
    var label = pattern
    label.tiers[at].tier = "P2b"

    for (field, moved) in [
      ("angle", angle), ("indices", indices), ("part", part), ("wheel", wheel), ("meet", meet),
      ("instructions", instructions), ("tier", label),
    ] {
      XCTAssertEqual(survivingTierPrefix(from: pattern, to: moved), at, field)
    }
  }

  // MARK: - What each structural edit costs

  func testAppendingATierChecksExactlyOneTier() throws {
    let pattern = try AuthoredPatterns.load(AuthoredPatterns.easyOctagon)
    var cache = TierFindingsCache()
    try fill(&cache, pattern)

    var appended = pattern
    appended.tiers.append(
      TierSpec(tier: "N1", part: .crown, angle: 30, indices: [0, 24, 48, 72], meet: .tcp))

    XCTAssertEqual(cache.retain(appended), ["N1"])
  }

  func testDeletingATierChecksFromThatPositionOnward() throws {
    let pattern = try AuthoredPatterns.load(AuthoredPatterns.easyOctagon)
    var cache = TierFindingsCache()
    try fill(&cache, pattern)

    var deleted = pattern
    deleted.tiers.remove(at: 2)

    XCTAssertEqual(cache.retain(deleted), ["C1", "C2", "T"])
  }

  func testSwappingTwoAdjacentTiersChecksFromTheEarlierOfThem() throws {
    let pattern = try AuthoredPatterns.load(AuthoredPatterns.easyOctagon)
    var cache = TierFindingsCache()
    try fill(&cache, pattern)

    var swapped = pattern
    swapped.tiers.swapAt(3, 4)

    XCTAssertEqual(cache.retain(swapped), ["C2", "C1", "T"])
  }

  /// A rename leaves no entry under the old label: the renamed tier differs at its own position, so it and
  /// everything after it go, and the stale key goes with them.
  func testARenameDropsTheStaleEntry() throws {
    let pattern = try AuthoredPatterns.load(AuthoredPatterns.easyOctagon)
    var cache = TierFindingsCache()
    try fill(&cache, pattern)
    XCTAssertNotNil(cache.perTier["P2"])

    var renamed = pattern
    renamed.tiers[2].tier = "P2b"

    XCTAssertEqual(cache.retain(renamed), ["P2b", "C1", "C2", "T"])
    XCTAssertNil(cache.perTier["P2"])
    XCTAssertEqual(Set(cache.perTier.keys), ["G1", "P1"])
  }

  // MARK: - A short cache is not a result

  func testCompleteIsNilUntilEveryTierHasAnEntry() throws {
    let pattern = try AuthoredPatterns.load(AuthoredPatterns.easyOctagon)
    let solution = try XCTUnwrap(benchSolid(for: pattern).solution)

    var cache = TierFindingsCache()
    XCTAssertNil(cache.complete, "an empty cache holds no pattern and so no result")

    let needed = cache.retain(pattern)
    for (i, tier) in needed.enumerated() {
      XCTAssertNil(cache.complete, "complete after \(i) of \(needed.count) tiers")
      cache.record(namedPointFindings(inTier: tier, of: pattern, solution), forTier: tier)
    }
    XCTAssertNotNil(cache.complete)
  }

  // MARK: - Cancellation

  func testCancellationReportsNothingRatherThanAPartialList() throws {
    let pattern = try AuthoredPatterns.load(AuthoredPatterns.easyOctagon)
    let solution = try XCTUnwrap(benchSolid(for: pattern).solution)

    XCTAssertNil(
      runTierChecks(
        tiers: pattern.tiers.map(\.tier), pattern: pattern, solution: solution,
        isCancelled: { true }))
  }

  // MARK: - The constant

  func testTheQuietPeriodIsAQuarterOfASecond() {
    XCTAssertEqual(geometricQuietPeriod, .milliseconds(250))
  }

  // MARK: - Helpers

  /// Fills a cold cache with every tier of `pattern`, as the store's first pass does.
  private func fill(_ cache: inout TierFindingsCache, _ pattern: FacetKernel.Pattern) throws {
    let solution = try XCTUnwrap(benchSolid(for: pattern).solution)
    for tier in cache.retain(pattern) {
      cache.record(namedPointFindings(inTier: tier, of: pattern, solution), forTier: tier)
    }
  }
}
