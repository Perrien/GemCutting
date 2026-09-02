import FacetKernel
import Foundation
import XCTest

@testable import BenchGeometry

/// Every edit rule, over drafts of the corpus. `AuthoredPatterns` lives in `BenchSolidTests.swift`.
///
/// `Pattern` is qualified as `FacetKernel.Pattern` throughout: XCTest pulls in ApplicationServices, whose
/// Quickdraw.h declares a `Pattern` struct, and the bare name is ambiguous in a test file in this target.
final class DraftEditsTests: XCTestCase {

  // MARK: - The reference graph

  /// `C1` and `T` name no `G1` facet, and a tier that merely sits after `G1` is not a tier that names it.
  func testTiersNamingAGirdleAreOnlyTheTwoThatActuallyNameIt() throws {
    let draft = try octagon()

    XCTAssertEqual(tiersNaming(tier: "G1", in: draft), ["P2", "C2"])
    XCTAssertEqual(tiersNaming(tier: "C1", in: draft), ["C2", "T"])
    XCTAssertEqual(tiersNaming(tier: "P2", in: draft), [])
    XCTAssertEqual(tiersNaming(tier: "nope", in: draft), [])
  }

  /// Per stop, not per tier — which is what makes removing one stop from a list refusable on its own.
  func testTiersNamingAGirdleStopAreOnlyTheOnesNamingThatStop() throws {
    let draft = try octagon()

    XCTAssertEqual(tiersNaming(tier: "G1", index: 12, in: draft), ["P2", "C2"])
    XCTAssertEqual(tiersNaming(tier: "G1", index: 0, in: draft), ["P2"])
    XCTAssertEqual(tiersNaming(tier: "G1", index: 24, in: draft), ["C2"])
    XCTAssertEqual(tiersNaming(tier: "G1", index: 36, in: draft), [])
  }

  func testTiersNamedByATierAreDeduplicatedInFirstNamedOrder() throws {
    let draft = try octagon()

    let c2 = try XCTUnwrap(draft.tiers.first { $0.tier == "C2" })
    XCTAssertEqual(tiersNamed(by: c2), ["G1", "C1"])

    let p2 = try XCTUnwrap(draft.tiers.first { $0.tier == "P2" })
    XCTAssertEqual(tiersNamed(by: p2), ["G1", "P1"])

    // The three forms that name no facet triple name no tier either.
    let g1 = try XCTUnwrap(draft.tiers.first { $0.tier == "G1" })
    XCTAssertEqual(tiersNamed(by: g1), [])
    let c1 = try XCTUnwrap(draft.tiers.first { $0.tier == "C1" })
    XCTAssertEqual(tiersNamed(by: c1), [])
  }

  /// A `fraction`'s endpoints are read through `Meet.namedTriples`, so both ends count and neither is a
  /// special case here.
  func testAFractionsEndpointsBothCountAsNaming() throws {
    let draft = try asher()

    XCTAssertEqual(tiersNaming(tier: "G", in: draft), ["P2", "C2"])
    XCTAssertEqual(tiersNaming(tier: "P1", in: draft), ["P2", "P3"])

    let p3 = try XCTUnwrap(draft.tiers.first { $0.tier == "P3" })
    XCTAssertEqual(tiersNamed(by: p3), ["P1", "P2"])
  }

  // MARK: - Deleting a tier

  func testDeletingANamedTierIsRefusedAndNamesItsDependents() throws {
    let draft = try octagon()

    XCTAssertEqual(
      deleting(tier: "G1", from: draft),
      .failure(.tierReferenced(tier: "G1", by: ["P2", "C2"])))
  }

  func testDeletingATierNothingNamesRemovesItAndNothingElse() throws {
    let draft = try octagon()

    let edited = try XCTUnwrap(try deleting(tier: "T", from: draft).get())
    XCTAssertEqual(edited.tiers.map(\.tier), ["G1", "P1", "P2", "C1", "C2"])
    for tier in edited.tiers {
      XCTAssertEqual(tier, draft.tiers.first { $0.tier == tier.tier }, tier.tier)
    }
  }

  func testDeletingALabelTheDraftDoesNotCarryChangesNothing() throws {
    let draft = try octagon()

    XCTAssertEqual(deleting(tier: "nope", from: draft), .success(draft))
  }

  // MARK: - Moving a tier

  /// `P2`'s meet names `P1@0` as well as two `G1` facets, and `P1` is the tier it would move ahead of.
  func testMovingATierAheadOfOneItNamesIsRefused() throws {
    let draft = try octagon()

    XCTAssertEqual(
      moving(tier: "P2", by: -1, in: draft),
      .failure(.moveWouldPointForward(tier: "P2", named: "P1")))
  }

  /// Swapping `C2` and `T` leaves `T` naming `C2@18` while `C2` is now cut later, so the first violation
  /// the walk finds belongs to the tier that stayed still rather than to the one that moved.
  func testMovingATierBehindOneThatNamesItIsRefusedInTheOvertakenTiersName() throws {
    let draft = try octagon()

    XCTAssertEqual(
      moving(tier: "C2", by: 1, in: draft),
      .failure(.moveWouldPointForward(tier: "T", named: "C2")))
  }

  /// A harmless move: `C1`'s meet is `girdle` and names nothing, and every meet that names `C1` — `C2` and
  /// `T` — still sits after it.
  func testAMoveThatBreaksNoReferenceIsAccepted() throws {
    let draft = try octagon()

    let edited = try XCTUnwrap(try moving(tier: "C1", by: -1, in: draft).get())
    XCTAssertEqual(edited.tiers.map(\.tier), ["G1", "P1", "C1", "P2", "C2", "T"])
  }

  func testAMoveOffEitherEndChangesNothing() throws {
    let draft = try octagon()

    XCTAssertEqual(moving(tier: "G1", by: -1, in: draft), .success(draft))
    XCTAssertEqual(moving(tier: "T", by: 1, in: draft), .success(draft))
  }

  func testMovingALabelTheDraftDoesNotCarryChangesNothing() throws {
    let draft = try octagon()

    XCTAssertEqual(moving(tier: "nope", by: 1, in: draft), .success(draft))
  }

  // MARK: - Renaming a tier

  /// A rename is the one structural repair that guesses nothing: it rewrites every `FacetRef` naming the
  /// tier, and the facet order inside each triple is left exactly as the author wrote it.
  func testARenamePropagatesIntoEveryMeetThatNamesTheTier() throws {
    let edited = try XCTUnwrap(try renaming(tier: "G1", to: "GDL", in: try octagon()).get())

    XCTAssertEqual(edited.tiers.map(\.tier), ["GDL", "P1", "P2", "C1", "C2", "T"])
    XCTAssertEqual(
      try tier("P2", of: edited).meet,
      .vertex(facets: [
        FacetRef(tier: "GDL", index: 0),
        FacetRef(tier: "GDL", index: 12),
        FacetRef(tier: "P1", index: 0),
      ]))
    XCTAssertEqual(
      try tier("C2", of: edited).meet,
      .vertex(facets: [
        FacetRef(tier: "GDL", index: 12),
        FacetRef(tier: "GDL", index: 24),
        FacetRef(tier: "C1", index: 12),
      ]))
  }

  /// A `fraction` names facets inside its endpoints, and the rewrite reaches both of them without touching
  /// the percentage.
  func testARenameReachesInsideBothEndpointsOfAFraction() throws {
    let edited = try XCTUnwrap(try renaming(tier: "G", to: "GG", in: try asher()).get())

    XCTAssertEqual(
      try tier("P2", of: edited).meet,
      .fraction(
        from: .vertex(facets: [
          FacetRef(tier: "GG", index: 12),
          FacetRef(tier: "GG", index: 24),
          FacetRef(tier: "P1", index: 24),
        ]),
        percent: 24.862,
        to: .tcp))
    XCTAssertEqual(
      try tier("C2", of: edited).meet,
      .fraction(
        from: .vertex(facets: [
          FacetRef(tier: "GG", index: 12),
          FacetRef(tier: "GG", index: 24),
          FacetRef(tier: "C1", index: 24),
        ]),
        percent: 24.832,
        to: .tcp))
  }

  /// The label is trimmed before it is judged, so trailing space cannot smuggle a duplicate past the check
  /// and produce a pattern the kernel would refuse to encode.
  func testARenameIsRefusedOnlyForAnEmptyOrDuplicateLabel() throws {
    let draft = try octagon()

    XCTAssertEqual(
      renaming(tier: "G1", to: "  P1 ", in: draft), .failure(.duplicateTierLabel("P1")))
    XCTAssertEqual(renaming(tier: "G1", to: "   ", in: draft), .failure(.emptyTierLabel))
    XCTAssertEqual(renaming(tier: "G1", to: "", in: draft), .failure(.emptyTierLabel))
    XCTAssertEqual(renaming(tier: "G1", to: "G1", in: draft), .success(draft))
    XCTAssertEqual(renaming(tier: "nope", to: "X", in: draft), .success(draft))
  }

  // MARK: - The angle

  func testAnAngleIsRefusedOnlyForNotBeingANumber() throws {
    let draft = try octagon()

    let edited = try XCTUnwrap(try setting(angle: "43.5", ofTier: "P2", in: draft).get())
    XCTAssertEqual(try tier("P2", of: edited).angle, 43.5)

    XCTAssertEqual(
      setting(angle: "forty", ofTier: "P2", in: draft),
      .failure(.notANumber(field: "angle", typed: "forty")))

    let padded = try XCTUnwrap(try setting(angle: " 12 ", ofTier: "P2", in: draft).get())
    XCTAssertEqual(try tier("P2", of: padded).angle, 12)
  }

  /// An angle past 90 is a geometric consequence and the solve reports it. Refusing it here would be the
  /// tool deciding what the stone may be, which is the opposite of the rule.
  func testAnAngleBeyondNinetyIsAcceptedAndLeftToTheSolve() throws {
    let edited = try XCTUnwrap(try setting(angle: "120", ofTier: "P2", in: try octagon()).get())

    XCTAssertEqual(try tier("P2", of: edited).angle, 120)
  }

  // MARK: - The index stops

  // These three read `P2`, the one tier of `Easy Octagon` whose stops nothing names — so what they check
  // is the parsing, with the stop-reference rule tested on its own below. `C2`'s stop 18 is named by `T`,
  // so retyping its list at all is refused, which would make a parsing check unreachable there.

  func testIndexStopsSplitOnWhitespaceAndCommasAlike() throws {
    let edited = try XCTUnwrap(
      try setting(indices: "0, 12,24", ofTier: "P2", in: try octagon()).get())

    XCTAssertEqual(try tier("P2", of: edited).indices, [0, 12, 24])
  }

  /// The order is data. `Novice Ash-er`'s printed sheet reads its stops as `12 24 36 48 60 72 84 0`, and a
  /// pattern transcribed that way has to store them that way.
  func testIndexStopsKeepTheOrderTheyWereTypedIn() throws {
    let edited = try XCTUnwrap(
      try setting(indices: "12 0 84", ofTier: "P2", in: try octagon()).get())

    XCTAssertEqual(try tier("P2", of: edited).indices, [12, 0, 84])
  }

  func testIndexStopsAreRefusedForNotBeingWholeNumbersOrForBeingOutOfRange() throws {
    let draft = try octagon()

    XCTAssertEqual(
      setting(indices: "0 12.5", ofTier: "C2", in: draft),
      .failure(.indicesNotWholeNumbers(typed: "0 12.5")))
    XCTAssertEqual(
      setting(indices: "0 96", ofTier: "C2", in: draft),
      .failure(.indexOutOfRange(tier: "C2", index: 96, wheel: 96)))
    XCTAssertEqual(
      setting(indices: "0 -1", ofTier: "C2", in: draft),
      .failure(.indexOutOfRange(tier: "C2", index: -1, wheel: 96)))
  }

  /// An empty list is accepted: a tier with no stops cuts nothing, which the solve reports, and it is a
  /// legitimate half-way state while retyping a list.
  func testAnEmptyIndexListIsAccepted() throws {
    let edited = try XCTUnwrap(try setting(indices: "", ofTier: "P2", in: try octagon()).get())

    XCTAssertEqual(try tier("P2", of: edited).indices, [])
  }

  /// The refusal is about the stop that *goes*, not about the list that arrives — so dropping a named stop
  /// is refused and dropping an unnamed one from the same tier is not.
  func testRemovingANamedIndexStopIsRefusedAndRemovingAnUnnamedOneIsNot() throws {
    let draft = try octagon()

    XCTAssertEqual(
      setting(indices: "0 24 36 48 60 72 84", ofTier: "G1", in: draft),
      .failure(.stopReferenced(tier: "G1", index: 12, by: ["P2", "C2"])))

    let edited = try XCTUnwrap(
      try setting(indices: "0 12 24 48 60 72 84", ofTier: "G1", in: draft).get())
    XCTAssertEqual(try tier("G1", of: edited).indices, [0, 12, 24, 48, 60, 72, 84])
  }

  // MARK: - Symmetry

  // Nothing symmetry-shaped is stored, so each of these reads the tier's current stops, replaces the one
  // thing the author changed, and expands — and every one of them lands through the same stop-list writer
  // the Indices cell uses, which is why a generated list is refused for exactly what a typed one is.

  /// Seed 18 stepped by 12 and wrapped. `C2` derives four folds and no mirroring, and eight folds keeps 18
  /// — which is the one stop of `C2` that `T`'s meet names, so the regeneration is not refused.
  func testRaisingTheFoldsExpandsTheTiersOwnSeedAndLeavesEveryOtherTierAlone() throws {
    let draft = try octagon()
    let edited = try XCTUnwrap(try setting(folds: "8", ofTier: "C2", in: draft).get())

    XCTAssertEqual(try tier("C2", of: edited).indices, [6, 18, 30, 42, 54, 66, 78, 90])
    for label in draft.tiers.map(\.tier) where label != "C2" {
      XCTAssertEqual(try tier(label, of: edited).indices, try tier(label, of: draft).indices, label)
    }
  }

  /// A fold count that does not divide the gear would land between stops, so it is refused rather than
  /// rounded — and the sentence lists the counts the gear does reach.
  func testAFoldCountThatDoesNotDivideTheGearIsRefused() throws {
    let draft = try octagon()

    XCTAssertEqual(
      setting(folds: "7", ofTier: "G1", in: draft),
      .failure(.foldsNotADivisor(tier: "G1", folds: 7, wheel: 96)))
  }

  /// The other side of the same refusal, and the case the two common gears cannot reach: the constraint is
  /// per tier, because a tier may be cut on its own gear.
  func testSevenFoldIsAcceptedOnATierCutOnAGearOfEightyFour() throws {
    var draft = try octagon()
    let position = try XCTUnwrap(draft.position(ofTier: "T"))
    draft.tiers[position].wheel = 84

    let edited = try XCTUnwrap(try setting(folds: "7", ofTier: "T", in: draft).get())

    XCTAssertEqual(try tier("T", of: edited).indices, [0, 12, 24, 36, 48, 60, 72])
  }

  /// The new seed rides the folds and mirroring the tier's **current** stops derive: `P2` reads eight folds
  /// and mirrored, so seed 0 gives `Easy Octagon`'s girdle list exactly.
  func testANewSeedRidesTheFoldsAndMirroringTheTiersOwnStopsDerive() throws {
    let edited = try XCTUnwrap(try setting(seeds: "0", ofTier: "P2", in: try octagon()).get())

    XCTAssertEqual(try tier("P2", of: edited).indices, [0, 12, 24, 36, 48, 60, 72, 84])
  }

  /// Seeds *are* index stops, so the field splits as the Indices cell does and a seed outside the gear
  /// reuses that cell's own sentence rather than getting a second one for the same fault.
  func testSeedsSplitOnCommasAndAreRefusedOutsideTheGear() throws {
    let draft = try octagon()

    XCTAssertEqual(
      setting(seeds: "0, 8", ofTier: "P2", in: draft),
      setting(seeds: "0 8", ofTier: "P2", in: draft))
    XCTAssertEqual(
      setting(seeds: "96", ofTier: "P2", in: draft),
      .failure(.indexOutOfRange(tier: "P2", index: 96, wheel: 96)))
  }

  func testSeedsAndFoldsAreRefusedForNotBeingWholeNumbers() throws {
    let draft = try octagon()

    XCTAssertEqual(
      setting(seeds: "nine", ofTier: "P2", in: draft),
      .failure(.indicesNotWholeNumbers(typed: "nine")))
    XCTAssertEqual(
      setting(folds: "nine", ofTier: "P2", in: draft),
      .failure(.notANumber(field: "folds", typed: "nine")))
  }

  /// Seed 0 at eight folds generates the same set with or without the reflection, so dropping mirroring
  /// here writes the list it already had.
  func testTurningMirroringOffLeavesAnEightFoldSetOnZeroIdentical() throws {
    let draft = try octagon()
    let edited = try XCTUnwrap(try setting(mirror: false, ofTier: "G1", in: draft).get())

    XCTAssertEqual(try tier("G1", of: edited).indices, try tier("G1", of: draft).indices)
  }

  /// **Making a set less symmetric is not refused for being less symmetric** — only for dropping a stop a
  /// later meet names. `Rand's` tier `2` derives two seeds, two folds and mirroring, and dropping the
  /// reflection loses 40 and 88, neither of which the pattern itself names.
  func testTurningMirroringOffDropsStopsAndIsRefusedOnlyForANamedOne() throws {
    let draft = try rands()

    let accepted = try XCTUnwrap(try setting(mirror: false, ofTier: "2", in: draft).get())
    XCTAssertEqual(try tier("2", of: accepted).indices, [0, 8, 48, 56])

    // Point a later tier's meet at the stop that would go, which no authored meet does.
    let pointed = try XCTUnwrap(
      try setting(
        meet: .vertex(facets: [
          FacetRef(tier: "2", index: 40),
          FacetRef(tier: "2", index: 48),
          FacetRef(tier: "1", index: 0),
        ]),
        ofTier: "3",
        in: draft
      ).get())

    XCTAssertEqual(
      setting(mirror: false, ofTier: "2", in: pointed),
      .failure(.stopReferenced(tier: "2", index: 40, by: ["3"])))
  }

  /// An empty seed field expands to nothing, exactly as an empty Indices cell is accepted — the tier cuts
  /// no facets, which the solve reports.
  func testAnEmptySeedFieldLeavesTheTierWithNoStops() throws {
    let edited = try XCTUnwrap(try setting(seeds: "", ofTier: "P2", in: try octagon()).get())

    XCTAssertEqual(try tier("P2", of: edited).indices, [])
  }

  /// The counts are computed into the sentence rather than spelled, so it cannot drift from what the setter
  /// actually accepts.
  func testTheFoldRefusalListsTheCountsTheGearDoesReach() {
    XCTAssertEqual(
      DraftRefusal.foldsNotADivisor(tier: "G1", folds: 7, wheel: 96).message,
      "7-fold does not divide G1's gear of 96. "
        + "On 96 the fold counts are 1, 2, 3, 4, 6, 8, 12, 16, 24, 32, 48, 96.")
  }

  // MARK: - The index gear

  // Neither setter ever rewrites a stop. A 96-wheel `24` is not a 120-wheel `24`, so every plane on an
  // affected tier moves — and that is a geometric consequence the solve reports, not a structural edit to
  // refuse. What *is* refused is a gear too small to hold a stop the tier already has.

  /// Accepted, and the stops come through untouched: a gear change moves planes, it does not renumber
  /// anything.
  func testATierTakingItsOwnGearKeepsItsStopsAndLeavesEveryOtherTierInheriting() throws {
    let draft = try octagon()
    let edited = try XCTUnwrap(try setting(wheel: 120, ofTier: "C2", in: draft).get())

    XCTAssertEqual(try tier("C2", of: edited).wheel, 120)
    XCTAssertEqual(try tier("C2", of: edited).indices, [18, 42, 66, 90])
    for label in draft.tiers.map(\.tier) where label != "C2" {
      XCTAssertNil(try tier(label, of: edited).wheel, label)
      XCTAssertEqual(draft.wheel(of: try tier(label, of: edited)), 96, label)
    }
  }

  /// The **first** offending stop in the order the author wrote them, not the largest: the sentence names
  /// the stop the author has to deal with first.
  func testAGearTooSmallForATiersOwnStopsIsRefusedNamingTheFirstOfThem() throws {
    let draft = try octagon()

    XCTAssertEqual(
      setting(wheel: 32, ofTier: "C2", in: draft),
      .failure(.indexOutOfRange(tier: "C2", index: 42, wheel: 32)))
  }

  /// Going back to inheritance is a gear change like any other, checked against the header's gear — so a
  /// tier that only fits on its own gear cannot silently fall back to one too small for it.
  func testGoingBackToInheritanceIsCheckedAgainstTheHeadersGear() throws {
    let onItsOwnGear = try XCTUnwrap(try setting(wheel: 120, ofTier: "C2", in: try octagon()).get())

    let restored = try XCTUnwrap(try setting(wheel: nil, ofTier: "C2", in: onItsOwnGear).get())
    XCTAssertNil(try tier("C2", of: restored).wheel)

    // 100 is a valid stop on 120 and rejected on 96. Stop 18 stays, because `T`'s meet names it.
    let outOfHeaderRange = try XCTUnwrap(
      try setting(indices: "18 100", ofTier: "C2", in: onItsOwnGear).get())
    XCTAssertEqual(
      setting(wheel: nil, ofTier: "C2", in: outOfHeaderRange),
      .failure(.indexOutOfRange(tier: "C2", index: 100, wheel: 96)))
  }

  /// Every tier inherits, so every plane in the pattern moves — and not one stop is rewritten.
  func testRaisingTheHeaderGearMovesEveryTierAndRewritesNoStops() throws {
    let draft = try octagon()
    let edited = try XCTUnwrap(try setting(wheel: 120, in: draft).get())

    XCTAssertEqual(edited.wheel, 120)
    for label in draft.tiers.map(\.tier) {
      XCTAssertNil(try tier(label, of: edited).wheel, label)
      XCTAssertEqual(try tier(label, of: edited).indices, try tier(label, of: draft).indices, label)
      XCTAssertEqual(edited.wheel(of: try tier(label, of: edited)), 120, label)
    }
  }

  /// The first tier in file order, and the first of its stops that will not fit.
  func testAHeaderGearTooSmallIsRefusedNamingTheFirstStopInFileOrder() throws {
    let draft = try octagon()

    XCTAssertEqual(
      setting(wheel: 32, in: draft),
      .failure(.indexOutOfRange(tier: "G1", index: 36, wheel: 32)))
  }

  /// A tier on its own gear is not affected by a header change, so it is not checked by one either.
  func testAHeaderGearChangeDoesNotCheckATierThatDeclaresItsOwn() throws {
    let onItsOwnGear = try XCTUnwrap(try setting(wheel: 120, ofTier: "C2", in: try octagon()).get())
    let withAHighStop = try XCTUnwrap(
      try setting(indices: "18 100", ofTier: "C2", in: onItsOwnGear).get())

    let edited = try XCTUnwrap(try setting(wheel: 96, in: withAHighStop).get())

    XCTAssertEqual(edited.wheel, 96)
    XCTAssertEqual(try tier("C2", of: edited).indices, [18, 100])
    XCTAssertEqual(try tier("C2", of: edited).wheel, 120)
  }

  // MARK: - The part

  /// Always allowed, even for a tier three meets name: a new part moves the facet rather than removing it,
  /// so every reference still resolves — to a different point.
  func testChangingAPartIsAlwaysAllowed() throws {
    let edited = try XCTUnwrap(try setting(part: .crown, ofTier: "P2", in: try octagon()).get())

    XCTAssertEqual(try tier("P2", of: edited).part, .crown)
  }

  /// A crown or a pavilion tier keeps whatever angle it had: the two ranges overlap, so the part says
  /// nothing about the angle.
  func testChangingToCrownOrPavilionLeavesTheAngleAlone() throws {
    let draft = try octagon()
    let before = try tier("P2", of: draft).angle

    for part in [Part.crown, .pav] {
      let edited = try XCTUnwrap(try setting(part: part, ofTier: "P2", in: draft).get())
      XCTAssertEqual(try tier("P2", of: edited).angle, before, "\(part.rawValue)")
    }
  }

  /// Declaring a tier a girdle or a table sets its angle too — 90 and 0, the one angle each is cut at.
  /// Read off a pavilion tier at 43°, so the assertion is about the new value and not about a tier that
  /// happened to be there already.
  func testChangingToGirdleOrTableSetsTheAngleWithIt() throws {
    let draft = try octagon()
    XCTAssertEqual(try tier("P2", of: draft).angle, 43)

    let girdle = try XCTUnwrap(try setting(part: .gdl, ofTier: "P2", in: draft).get())
    XCTAssertEqual(try tier("P2", of: girdle).part, .gdl)
    XCTAssertEqual(try tier("P2", of: girdle).angle, 90)

    let table = try XCTUnwrap(try setting(part: .table, ofTier: "P2", in: draft).get())
    XCTAssertEqual(try tier("P2", of: table).part, .table)
    XCTAssertEqual(try tier("P2", of: table).angle, 0)
  }

  /// The two parts that have one, and the two that do not.
  func testOnlyGirdleAndTableHaveADefiningAngle() {
    XCTAssertEqual(definingAngle(of: .gdl), 90)
    XCTAssertEqual(definingAngle(of: .table), 0)
    XCTAssertNil(definingAngle(of: .crown))
    XCTAssertNil(definingAngle(of: .pav))
  }

  /// Every girdle and table tier of every authored pattern already sits at its part's defining angle, which
  /// is what makes filling it in a convenience rather than a change of meaning.
  ///
  /// **A failure here means the assumption is wrong, never that the pattern is.** The authored patterns are
  /// ground truth; a girdle transcribed at anything but 90 would mean the fill has to stop overwriting.
  func testTheCorpusAgreesWithTheDefiningAngles() throws {
    for name in AuthoredPatterns.all {
      let pattern = try AuthoredPatterns.load(name)
      for spec in pattern.tiers {
        guard let expected = definingAngle(of: spec.part) else { continue }
        XCTAssertEqual(spec.angle, expected, "\(name) \(spec.tier)")
      }
    }
  }

  // MARK: - The instructions

  func testEmptyInstructionsAreStoredAsEmptyAndNeverAsAbsent() throws {
    let draft = try octagon()

    let cleared = try XCTUnwrap(try setting(instructions: "", ofTier: "G1", in: draft).get())
    XCTAssertEqual(try tier("G1", of: cleared).instructions, "")

    let written = try XCTUnwrap(
      try setting(instructions: "level girdle", ofTier: "G1", in: draft).get())
    XCTAssertEqual(try tier("G1", of: written).instructions, "level girdle")
  }

  // MARK: - The meet

  func testClearingAMeetDropsTheTierFromTheDisplayAndChoosingOneReplacesIt() throws {
    let draft = try octagon()

    let cleared = try XCTUnwrap(try setting(meet: nil, ofTier: "P2", in: draft).get())
    XCTAssertEqual(try XCTUnwrap(cleared.displayPattern).tiers.count, 5)
    XCTAssertNil(try tier("P2", of: cleared).meet)

    let chosen = try XCTUnwrap(try setting(meet: .girdle, ofTier: "P2", in: draft).get())
    XCTAssertEqual(try tier("P2", of: chosen).meet, .girdle)
  }

  // MARK: - The anchored percentage

  func testTypingAPercentageRewritesItAndLeavesBothEndpointsAlone() throws {
    let draft = try asher()
    guard case .fraction(let from, let stored, let to) = try tier("P2", of: draft).meet else {
      return XCTFail("Novice Ash-er's P2 is not a fraction")
    }
    XCTAssertEqual(stored, 24.862, accuracy: 1e-9)

    let edited = try XCTUnwrap(try setting(percent: "40", ofTier: "P2", in: draft).get())
    XCTAssertEqual(try tier("P2", of: edited).meet, .fraction(from: from, percent: 40, to: to))

    // And back to what the file stores, exactly.
    let restored = try XCTUnwrap(try setting(percent: "24.862", ofTier: "P2", in: edited).get())
    XCTAssertEqual(try tier("P2", of: restored).meet, try tier("P2", of: draft).meet)
  }

  /// **The meet form follows from the value**, exactly as snapping into an end zone does: `0` is the meet
  /// `from` spells and `100` is the meet `to` spells, and neither is a `fraction` at a percentage of zero.
  func testZeroAndOneHundredCollapseTheMeetToTheEndpointTheyName() throws {
    let draft = try asher()
    guard case .fraction(let from, _, let to) = try tier("P2", of: draft).meet else {
      return XCTFail("Novice Ash-er's P2 is not a fraction")
    }

    let atZero = try XCTUnwrap(try setting(percent: "0", ofTier: "P2", in: draft).get())
    XCTAssertEqual(try tier("P2", of: atZero).meet, from)
    XCTAssertEqual(meetText(try XCTUnwrap(try tier("P2", of: atZero).meet)), "G@12 · G@24 · P1@24")

    // `to` is `tcp` here, so 100 collapses to `tcp` — the endpoint's own form, whatever it is.
    let atHundred = try XCTUnwrap(try setting(percent: "100", ofTier: "P2", in: draft).get())
    XCTAssertEqual(try tier("P2", of: atHundred).meet, to)
    XCTAssertEqual(try tier("P2", of: atHundred).meet, .tcp)
  }

  func testAPercentageIsRefusedForNotBeingANumberAndForBeingOutOfRange() throws {
    let draft = try asher()

    XCTAssertEqual(
      setting(percent: "abc", ofTier: "P2", in: draft),
      .failure(.notANumber(field: "percentage", typed: "abc")))
    XCTAssertEqual(
      setting(percent: "-1", ofTier: "P2", in: draft),
      .failure(.percentNotInRange(tier: "P2", typed: "-1")))
    XCTAssertEqual(
      setting(percent: "101", ofTier: "P2", in: draft),
      .failure(.percentNotInRange(tier: "P2", typed: "101")))
    XCTAssertEqual(
      DraftRefusal.percentNotInRange(tier: "P2", typed: "140").message,
      "\"140\" is not a percentage between 0 and 100 for P2's meet.")
  }

  func testATierWhoseMeetIsNotAFractionIsReturnedUnchanged() throws {
    let draft = try asher()
    // `P1` is `tcp`, and a label the draft does not carry at all.
    XCTAssertEqual(try setting(percent: "40", ofTier: "P1", in: draft).get(), draft)
    XCTAssertEqual(try setting(percent: "40", ofTier: "nonesuch", in: draft).get(), draft)
  }

  // MARK: - Appending a tier

  func testAppendingTakesTheFirstUnusedNumberedLabelAndCarriesThePartOver() throws {
    let first = try XCTUnwrap(try appendingTier(to: try octagon()).get())

    XCTAssertEqual(first.tiers.map(\.tier), ["G1", "P1", "P2", "C1", "C2", "T", "N1"])
    let appended = try tier("N1", of: first)
    // The octagon ends on its table, so the tier after it is a table too, at a table's one angle.
    XCTAssertEqual(appended.part, .table)
    XCTAssertEqual(appended.angle, 0)
    XCTAssertEqual(appended.indices, [])
    XCTAssertNil(appended.meet)
    XCTAssertNil(appended.instructions)
    XCTAssertNil(appended.wheel)

    let second = try XCTUnwrap(try appendingTier(to: first).get())
    let third = try XCTUnwrap(try appendingTier(to: second).get())
    XCTAssertEqual(third.tiers.suffix(3).map(\.tier), ["N1", "N2", "N3"])
  }

  /// The angle follows the part exactly as choosing the part in the table does — a girdle stands at 90 by
  /// definition — and a crown or a pavilion, whose angle is the author's, starts at 0.
  func testTheCarriedPartBringsItsDefiningAngleAndAnEmptyPatternStartsAtPavilion() throws {
    var girdleLast = try octagon()
    girdleLast.tiers = Array(girdleLast.tiers.prefix(1))
    XCTAssertEqual(girdleLast.tiers.map(\.part), [.gdl])
    let afterGirdle = try XCTUnwrap(try appendingTier(to: girdleLast).get())
    XCTAssertEqual(afterGirdle.tiers.last?.part, .gdl)
    XCTAssertEqual(afterGirdle.tiers.last?.angle, 90)

    var pavilionLast = try octagon()
    pavilionLast.tiers = Array(pavilionLast.tiers.prefix(3))
    XCTAssertEqual(pavilionLast.tiers.last?.part, .pav)
    let afterPavilion = try XCTUnwrap(try appendingTier(to: pavilionLast).get())
    XCTAssertEqual(afterPavilion.tiers.last?.part, .pav)
    XCTAssertEqual(afterPavilion.tiers.last?.angle, 0)

    var empty = try octagon()
    empty.tiers = []
    let firstOfAll = try XCTUnwrap(try appendingTier(to: empty).get())
    XCTAssertEqual(firstOfAll.tiers.map(\.tier), ["N1"])
    XCTAssertEqual(firstOfAll.tiers.last?.part, .pav)
    XCTAssertEqual(firstOfAll.tiers.last?.angle, 0)
  }

  /// The first *unused* label, not the next number up from the count — so an `N1` the author already has
  /// is never duplicated into a pattern the kernel would refuse to encode.
  func testAppendingSkipsALabelTheDraftAlreadyCarries() throws {
    var draft = try octagon()
    draft.tiers[0].tier = "N1"

    let edited = try XCTUnwrap(try appendingTier(to: draft).get())
    XCTAssertEqual(edited.tiers.last?.tier, "N2")
  }

  // MARK: - The header

  func testTheRefractiveIndexIsRefusedOnlyForNotBeingANumber() throws {
    let draft = try octagon()

    let edited = try XCTUnwrap(try setting(ri: "2.16", in: draft).get())
    XCTAssertEqual(edited.ri, 2.16)

    XCTAssertEqual(
      setting(ri: "quartz", in: draft),
      .failure(.notANumber(field: "refractive index", typed: "quartz")))
  }

  /// An empty field is absent, which means the documented default. Zero is not the same claim as absent,
  /// so it is refused and the sentence says where to put the default instead.
  func testAnEmptyGirdleTargetIsAbsentAndZeroIsRefused() throws {
    let draft = try octagon()

    XCTAssertNil(try XCTUnwrap(try setting(girdleTarget: "", in: draft).get()).girdleTargetFraction)
    XCTAssertNil(
      try XCTUnwrap(try setting(girdleTarget: "  ", in: draft).get()).girdleTargetFraction)
    XCTAssertEqual(
      try XCTUnwrap(try setting(girdleTarget: "0.05", in: draft).get()).girdleTargetFraction, 0.05)

    XCTAssertEqual(
      setting(girdleTarget: "0", in: draft), .failure(.girdleTargetNotPositive(typed: "0")))
    XCTAssertEqual(
      setting(girdleTarget: "-0.01", in: draft),
      .failure(.girdleTargetNotPositive(typed: "-0.01")))
    XCTAssertEqual(
      setting(girdleTarget: "thick", in: draft),
      .failure(.notANumber(field: "girdle target", typed: "thick")))
  }

  /// Verbatim, leading and trailing whitespace included. These three are prose, and trimming prose is the
  /// tool deciding what the author meant.
  func testTheThreeTextFieldsStoreWhatWasTypedExactly() throws {
    let draft = try octagon()

    XCTAssertEqual(try XCTUnwrap(try setting(name: "  Octo  ", in: draft).get()).name, "  Octo  ")
    XCTAssertEqual(
      try XCTUnwrap(try setting(designer: " me ", in: draft).get()).designer, " me ")
    XCTAssertEqual(
      try XCTUnwrap(try setting(notes: "line\nline ", in: draft).get()).notes, "line\nline ")
  }

  // MARK: - Nothing reorders

  /// The app never reorders tiers on its own. Every edit but the three that are *about* the order leaves
  /// the sequence exactly as it found it — normalising it for tidiness can turn a cuttable pattern into
  /// one that cannot be cut at all.
  func testNoValueEditEverReordersTheTiers() throws {
    let draft = try octagon()
    let order = draft.tiers.map(\.tier)

    let edits: [(String, DraftChange)] = [
      ("angle", { setting(angle: "43.5", ofTier: "P2", in: $0) }),
      ("indices", { setting(indices: "0 12 24 48 60 72 84", ofTier: "G1", in: $0) }),
      ("part", { setting(part: .crown, ofTier: "P2", in: $0) }),
      ("instructions", { setting(instructions: "level", ofTier: "G1", in: $0) }),
      ("meet", { setting(meet: nil, ofTier: "P2", in: $0) }),
      ("name", { setting(name: "Octo", in: $0) }),
      ("designer", { setting(designer: "me", in: $0) }),
      ("notes", { setting(notes: "note", in: $0) }),
      ("ri", { setting(ri: "2.16", in: $0) }),
      ("girdleTarget", { setting(girdleTarget: "0.05", in: $0) }),
    ]

    for (label, edit) in edits {
      let edited = try XCTUnwrap(try edit(draft).get(), label)
      XCTAssertEqual(edited.tiers.map(\.tier), order, label)
    }

    // A rename changes one label in place and nothing about the sequence it sits in.
    let renamedDraft = try XCTUnwrap(try renaming(tier: "G1", to: "GDL", in: draft).get())
    XCTAssertEqual(renamedDraft.tiers.map(\.tier), ["GDL"] + order.dropFirst())
  }

  // MARK: - Helpers

  private func octagon() throws -> PatternDraft {
    PatternDraft(try AuthoredPatterns.load(AuthoredPatterns.easyOctagon))
  }

  private func asher() throws -> PatternDraft {
    PatternDraft(try AuthoredPatterns.load(AuthoredPatterns.noviceAsher))
  }

  private func rands() throws -> PatternDraft {
    PatternDraft(try AuthoredPatterns.load(AuthoredPatterns.rands))
  }

  private func tier(_ label: String, of draft: PatternDraft) throws -> DraftTier {
    try XCTUnwrap(draft.tiers.first { $0.tier == label }, label)
  }
}
