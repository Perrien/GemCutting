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

  // MARK: - The part

  /// Always allowed, even for a tier three meets name: a new part moves the facet rather than removing it,
  /// so every reference still resolves — to a different point.
  func testChangingAPartIsAlwaysAllowed() throws {
    let edited = try XCTUnwrap(try setting(part: .crown, ofTier: "P2", in: try octagon()).get())

    XCTAssertEqual(try tier("P2", of: edited).part, .crown)
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

  // MARK: - Appending a tier

  func testAppendingTakesTheFirstUnusedNumberedLabelAndGuessesNothingElse() throws {
    let first = try XCTUnwrap(try appendingTier(to: try octagon()).get())

    XCTAssertEqual(first.tiers.map(\.tier), ["G1", "P1", "P2", "C1", "C2", "T", "N1"])
    let appended = try tier("N1", of: first)
    XCTAssertEqual(appended.part, .pav)
    XCTAssertEqual(appended.angle, 0)
    XCTAssertEqual(appended.indices, [])
    XCTAssertNil(appended.meet)
    XCTAssertNil(appended.instructions)
    XCTAssertNil(appended.wheel)

    let second = try XCTUnwrap(try appendingTier(to: first).get())
    let third = try XCTUnwrap(try appendingTier(to: second).get())
    XCTAssertEqual(third.tiers.suffix(3).map(\.tier), ["N1", "N2", "N3"])
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

  private func tier(_ label: String, of draft: PatternDraft) throws -> DraftTier {
    try XCTUnwrap(draft.tiers.first { $0.tier == label }, label)
  }
}
