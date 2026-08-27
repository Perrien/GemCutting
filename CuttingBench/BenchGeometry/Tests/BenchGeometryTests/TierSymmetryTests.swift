import FacetKernel
import Foundation
import XCTest

@testable import BenchGeometry

/// The gears, the generator and its inverse, over the corpus. `AuthoredPatterns` lives in
/// `BenchSolidTests.swift`.
///
/// `Pattern` is qualified as `FacetKernel.Pattern` throughout: XCTest pulls in ApplicationServices, whose
/// Quickdraw.h declares a `Pattern` struct, and the bare name is ambiguous in a test file in this target.
final class TierSymmetryTests: XCTestCase {

  // MARK: - The round trip over the corpus

  /// **The case that matters most.** If a tier's derived seeds do not expand back to that tier's own stops,
  /// the controls would be showing the author a set they cannot regenerate. Thirty-two tiers.
  func testEveryAuthoredTiersSeedsExpandBackToItsOwnStops() throws {
    var checked = 0
    for name in AuthoredPatterns.all {
      let pattern = try AuthoredPatterns.load(name)
      for tier in pattern.tiers {
        let gear = pattern.wheel(of: tier)
        let symmetry = derivedSymmetry(stops: tier.indices, wheel: gear)
        XCTAssertEqual(
          expandedStops(
            seeds: symmetry.seeds, folds: symmetry.folds, mirror: symmetry.mirror, wheel: gear),
          tier.indices.sorted(),
          "\(name) tier \(tier.tier)")
        checked += 1
      }
    }
    XCTAssertEqual(checked, 32)
  }

  /// Which is what makes the sorted comparison above the right one: every authored list is already
  /// ascending, so the round trip is not quietly excusing a reordering.
  func testEveryAuthoredIndexListIsAlreadyAscending() throws {
    for name in AuthoredPatterns.all {
      let pattern = try AuthoredPatterns.load(name)
      for tier in pattern.tiers {
        XCTAssertEqual(tier.indices, tier.indices.sorted(), "\(name) tier \(tier.tier)")
      }
    }
  }

  // MARK: - The corpus's own readings

  /// One seed, eight-fold, mirrored — the reading the whole part exists to give the author.
  func testEasyOctagonsGirdleReadsAsOneSeedEightFoldMirrored() throws {
    let pattern = try AuthoredPatterns.load(AuthoredPatterns.easyOctagon)
    let girdle = try XCTUnwrap(pattern.tiers.first { $0.tier == "G1" })

    XCTAssertEqual(girdle.indices, [0, 12, 24, 36, 48, 60, 72, 84])
    XCTAssertEqual(
      derivedSymmetry(stops: girdle.indices, wheel: 96),
      TierSymmetry(seeds: [0], folds: 8, mirror: true))
  }

  /// **Not mirrored, because 78 is not in the set.** Folds and mirroring are read independently, so a
  /// four-fold set is not assumed to be mirrored as well.
  func testEasyOctagonsUpperCrownIsFourFoldAndNotMirrored() throws {
    let pattern = try AuthoredPatterns.load(AuthoredPatterns.easyOctagon)
    let crown = try XCTUnwrap(pattern.tiers.first { $0.tier == "C2" })

    XCTAssertEqual(crown.indices, [18, 42, 66, 90])
    XCTAssertEqual(
      derivedSymmetry(stops: crown.indices, wheel: 96),
      TierSymmetry(seeds: [18], folds: 4, mirror: false))
  }

  /// A single stop is one fold and mirrored: reflecting 0 gives 0.
  func testATableOfOneStopIsOneFoldAndMirrored() throws {
    let pattern = try AuthoredPatterns.load(AuthoredPatterns.easyOctagon)
    let table = try XCTUnwrap(pattern.tiers.first { $0.tier == "T" })

    XCTAssertEqual(table.indices, [0])
    XCTAssertEqual(
      derivedSymmetry(stops: table.indices, wheel: 96),
      TierSymmetry(seeds: [0], folds: 1, mirror: true))
  }

  /// **Two seeds**, because a rectangle's girdle takes two stops to state: the set is two orbits of the
  /// half-turn-plus-reflection group and neither generates the other.
  func testRandsGirdleReadsAsTwoSeedsTwoFoldMirrored() throws {
    let pattern = try AuthoredPatterns.load(AuthoredPatterns.rands)
    let girdle = try XCTUnwrap(pattern.tiers.first { $0.tier == "2" })

    XCTAssertEqual(girdle.indices, [0, 8, 40, 48, 56, 88])
    XCTAssertEqual(
      derivedSymmetry(stops: girdle.indices, wheel: 96),
      TierSymmetry(seeds: [0, 8], folds: 2, mirror: true))
  }

  // MARK: - Whether the Mirror control has anything to do

  /// The case the disabled state exists for: one seed at 0 taken eight-fold is mirror-symmetric by
  /// rotation alone, so regenerating it without the reflection produces the very same eight stops and the
  /// derived answer comes straight back `true`.
  func testMirroringIsNotEditableWhenRotationAloneAlreadyMirrorsTheSet() throws {
    let pattern = try AuthoredPatterns.load(AuthoredPatterns.easyOctagon)
    let girdle = try XCTUnwrap(pattern.tiers.first { $0.tier == "G1" })
    let symmetry = derivedSymmetry(stops: girdle.indices, wheel: 96)

    XCTAssertTrue(symmetry.mirror)
    XCTAssertFalse(mirrorIsEditable(symmetry, wheel: 96))
    // The reason, stated directly: dropping the reflection changes nothing.
    XCTAssertEqual(
      expandedStops(seeds: symmetry.seeds, folds: symmetry.folds, mirror: false, wheel: 96),
      girdle.indices)
  }

  /// A single stop reflects onto itself, so a table is mirrored and the control is inert there too.
  func testMirroringIsNotEditableForASingleStop() throws {
    let pattern = try AuthoredPatterns.load(AuthoredPatterns.easyOctagon)
    let table = try XCTUnwrap(pattern.tiers.first { $0.tier == "T" })
    let symmetry = derivedSymmetry(stops: table.indices, wheel: 96)

    XCTAssertTrue(symmetry.mirror)
    XCTAssertFalse(mirrorIsEditable(symmetry, wheel: 96))
  }

  /// Turning mirroring *on* always does something, because the expansion adds each seed's reflection and a
  /// set that already held them would have derived as mirrored to begin with.
  func testMirroringIsEditableOnASetThatIsNotMirrored() throws {
    let pattern = try AuthoredPatterns.load(AuthoredPatterns.easyOctagon)
    let crown = try XCTUnwrap(pattern.tiers.first { $0.tier == "C2" })
    let symmetry = derivedSymmetry(stops: crown.indices, wheel: 96)

    XCTAssertFalse(symmetry.mirror)
    XCTAssertTrue(mirrorIsEditable(symmetry, wheel: 96))
  }

  /// Mirrored *and* editable, which is the case that proves the rule is not just "mirrored means
  /// disabled": a rectangle's girdle needs the reflection, so dropping it loses two of the six stops.
  func testMirroringIsEditableWhereTheReflectionIsCarryingStops() throws {
    let pattern = try AuthoredPatterns.load(AuthoredPatterns.rands)
    let girdle = try XCTUnwrap(pattern.tiers.first { $0.tier == "2" })
    let symmetry = derivedSymmetry(stops: girdle.indices, wheel: 96)

    XCTAssertTrue(symmetry.mirror)
    XCTAssertTrue(mirrorIsEditable(symmetry, wheel: 96))
    XCTAssertEqual(
      expandedStops(seeds: symmetry.seeds, folds: symmetry.folds, mirror: false, wheel: 96),
      [0, 8, 48, 56], "dropping the reflection loses 40 and 88")
  }

  /// No stops generate nothing whichever way the flag is set, so the control is inert. Falls out of asking
  /// the one question rather than being special-cased.
  func testMirroringIsNotEditableForATierWithNoStops() {
    XCTAssertFalse(mirrorIsEditable(derivedSymmetry(stops: [], wheel: 96), wheel: 96))
  }

  /// A gear of zero has no arithmetic to do, and the control cannot act on it either.
  func testMirroringIsNotEditableOnANonPositiveGear() {
    XCTAssertFalse(mirrorIsEditable(TierSymmetry(seeds: [0], folds: 1, mirror: true), wheel: 0))
  }

  /// Sixteen stops six apart, from one seed — the list this part exists to stop the author typing.
  func testTheRoundBrilliantsBreaksReadAsOneSeedSixteenFoldMirrored() throws {
    let pattern = try AuthoredPatterns.load(AuthoredPatterns.roundBrilliant)
    let breaks = try XCTUnwrap(pattern.tiers.first { $0.tier == "pb" })

    XCTAssertEqual(breaks.indices.count, 16)
    XCTAssertEqual(
      derivedSymmetry(stops: breaks.indices, wheel: 96),
      TierSymmetry(seeds: [3], folds: 16, mirror: true))
    XCTAssertEqual(
      expandedStops(seeds: [3], folds: 16, mirror: true, wheel: 96),
      [3, 9, 15, 21, 27, 33, 39, 45, 51, 57, 63, 69, 75, 81, 87, 93])
  }

  // MARK: - The two special cases

  /// By special case, not by the general rule: every rotation maps the empty set onto itself, so the rule
  /// would read the whole gear as the fold count. Every tier the Add Tier button appends starts here.
  func testAnEmptyStopListIsOneFoldNotMirroredAndNoSeeds() {
    for gear in indexGears {
      XCTAssertEqual(
        derivedSymmetry(stops: [], wheel: gear),
        TierSymmetry(seeds: [], folds: 1, mirror: false),
        "on \(gear)")
    }
  }

  /// **Raw mode is not a flag.** A set no rotation and no reflection maps onto itself reads as 1 fold, not
  /// mirrored, and seeds equal to the stops — so the expansion is the identity and the generator is
  /// transparently off.
  func testAnAsymmetricSetReadsAsOneFoldWithItsOwnStopsAsSeeds() {
    let symmetry = derivedSymmetry(stops: [0, 1, 5], wheel: 96)

    XCTAssertEqual(symmetry, TierSymmetry(seeds: [0, 1, 5], folds: 1, mirror: false))
    XCTAssertEqual(
      expandedStops(
        seeds: symmetry.seeds, folds: symmetry.folds, mirror: symmetry.mirror, wheel: 96),
      [0, 1, 5])
  }

  // MARK: - The fold counts a gear reaches

  /// 7-fold is reachable on 84 and impossible on 96, which is the whole reason the constraint is per tier:
  /// a tier may be cut on its own gear.
  func testSevenFoldIsReachableOnEightyFourAndNotOnNinetySix() {
    XCTAssertTrue(foldCounts(onWheel: 84).contains(7))
    XCTAssertFalse(foldCounts(onWheel: 96).contains(7))
  }

  /// One fold is always reachable — that is the generator off — and so is the gear itself, which is a stop
  /// at every index.
  func testFoldCountsRunFromOneToTheGearItself() {
    for gear in indexGears {
      let counts = foldCounts(onWheel: gear)
      XCTAssertEqual(counts.first, 1, "on \(gear)")
      XCTAssertEqual(counts.last, gear, "on \(gear)")
      XCTAssertEqual(counts, counts.sorted(), "on \(gear)")
    }
    XCTAssertEqual(
      foldCounts(onWheel: 96), [1, 2, 3, 4, 6, 8, 12, 16, 24, 32, 48, 96])
  }

  // MARK: - The gears a popup offers

  /// The eight, and only the eight, for a tier inheriting and for one already on a listed gear.
  func testTheGearsOfferedAreTheEightUnlessTheDocumentCarriesAnother() {
    XCTAssertEqual(gearsOffered(including: nil), [32, 64, 72, 80, 84, 88, 96, 120])
    XCTAssertEqual(gearsOffered(including: 96), [32, 64, 72, 80, 84, 88, 96, 120])
  }

  /// The kernel accepts any positive wheel, so a decoded file can hold 100 — and a popup whose selection
  /// matches no item renders blank rather than complaining.
  func testAGearTheDocumentAlreadyCarriesIsOfferedInItsOwnPlace() {
    XCTAssertEqual(gearsOffered(including: 100), [32, 64, 72, 80, 84, 88, 96, 100, 120])
  }
}
