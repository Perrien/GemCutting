import FacetKernel
import Foundation
import XCTest

@testable import BenchGeometry

/// The draft and its two conversions, read off the corpus and off cleared-meet cases the corpus cannot
/// reach. `AuthoredPatterns` lives in `BenchSolidTests.swift`.
///
/// `Pattern` is qualified as `FacetKernel.Pattern` throughout: XCTest pulls in ApplicationServices, whose
/// Quickdraw.h declares a `Pattern` struct, and the bare name is ambiguous in a test file in this target.
final class PatternDraftTests: XCTestCase {

  // MARK: - The corpus round-trips

  /// Equality is `Pattern`'s own, which compares the tiers as an ordered array — so this is the
  /// every-field-and-same-order check, not a count.
  func testEveryAuthoredPatternRoundTripsThroughTheDraftUnchanged() throws {
    for name in AuthoredPatterns.all {
      let pattern = try AuthoredPatterns.load(name)
      let draft = PatternDraft(pattern)

      XCTAssertEqual(draft.displayPattern, pattern, name)
      XCTAssertEqual(draft.completePattern(), .success(pattern), name)
    }
  }

  // MARK: - The empty draft

  func testAnEmptyDraftDisplaysNothingAndCannotBeSaved() {
    XCTAssertNil(PatternDraft.empty.displayPattern)
    XCTAssertEqual(PatternDraft.empty.completePattern(), .failure(.noTiers))
  }

  func testAnEmptyDraftIsTheDocumentedNewDocument() {
    let draft = PatternDraft.empty

    XCTAssertEqual(draft.formatVersion, 1)
    XCTAssertEqual(draft.name, "")
    XCTAssertEqual(draft.state, .inProgress)
    XCTAssertEqual(draft.wheel, 96)
    XCTAssertEqual(draft.ri, 1.54)
    XCTAssertNil(draft.girdleTargetFraction)
    XCTAssertEqual(draft.designer, "")
    XCTAssertEqual(draft.notes, "")
    XCTAssertTrue(draft.tiers.isEmpty)
  }

  // MARK: - A tier with no meet yet

  /// The display drops it and the save refuses it. Those are the two conversions, and there is no third.
  func testAClearedMeetDropsFromTheDisplayAndBlocksTheSave() throws {
    var draft = PatternDraft(try AuthoredPatterns.load(AuthoredPatterns.easyOctagon))
    XCTAssertEqual(draft.tiers[3].tier, "C1")
    draft.tiers[3].meet = nil

    let displayed = try XCTUnwrap(draft.displayPattern)
    XCTAssertEqual(displayed.tiers.map(\.tier), ["G1", "P1", "P2", "C2", "T"])
    XCTAssertEqual(draft.completePattern(), .failure(.tiersWithoutMeet(["C1"])))
  }

  func testTwoClearedMeetsAreBothNamedInFileOrderInOneFailure() throws {
    var draft = PatternDraft(try AuthoredPatterns.load(AuthoredPatterns.easyOctagon))
    // Cleared in the other order, so a passing assertion is file order rather than the order they were
    // touched in.
    draft.tiers[3].meet = nil
    draft.tiers[2].meet = nil

    XCTAssertEqual(draft.completePattern(), .failure(.tiersWithoutMeet(["P2", "C1"])))
  }

  /// A draft whose every meet is cleared has nothing left to solve, which is the same state as a new
  /// document as far as the display is concerned — but not as far as the save is.
  func testADraftWithNoMeetAtAllDisplaysNothingAndStillNamesItsTiers() throws {
    var draft = PatternDraft(try AuthoredPatterns.load(AuthoredPatterns.easyOctagon))
    for k in draft.tiers.indices { draft.tiers[k].meet = nil }

    XCTAssertNil(draft.displayPattern)
    XCTAssertEqual(
      draft.completePattern(),
      .failure(.tiersWithoutMeet(["G1", "P1", "P2", "C1", "C2", "T"])))
  }

  // MARK: - Looking a tier up

  func testPositionFindsEveryLabelAtItsFilePositionAndNothingElse() throws {
    let pattern = try AuthoredPatterns.load(AuthoredPatterns.noviceAsher)
    let draft = PatternDraft(pattern)

    for (k, spec) in pattern.tiers.enumerated() {
      XCTAssertEqual(draft.position(ofTier: spec.tier), k, spec.tier)
    }
    XCTAssertNil(draft.position(ofTier: "nope"))
  }

  func testTheEffectiveGearIsTheTiersOwnWhereItDeclaresOneAndTheDraftsOtherwise() throws {
    var draft = PatternDraft(try AuthoredPatterns.load(AuthoredPatterns.noviceAsher))
    let c1 = try XCTUnwrap(draft.position(ofTier: "C1"))
    draft.tiers[c1].wheel = 64

    XCTAssertEqual(draft.wheel(of: draft.tiers[c1]), 64)
    for tier in draft.tiers where tier.tier != "C1" {
      XCTAssertEqual(draft.wheel(of: tier), 96, tier.tier)
    }
  }

  // MARK: - The debug summary

  func testTheDraftSummaryReadsItsThreeStatesVerbatim() throws {
    XCTAssertEqual(draftSummary(.empty), "draft 0 tiers · no tiers yet")

    var draft = PatternDraft(try AuthoredPatterns.load(AuthoredPatterns.easyOctagon))
    XCTAssertEqual(draftSummary(draft), "draft 6 tiers · complete")

    draft.tiers[3].meet = nil
    draft.tiers[2].meet = nil
    XCTAssertEqual(draftSummary(draft), "draft 6 tiers · no meet yet: P2, C1")
  }

  // MARK: - Every refusal's wording

  /// The alert and the log line read this one string, so its wording is checked here rather than in a
  /// window. Character for character: a refusal the owner cannot act on is a refusal that failed.
  func testEveryRefusalMessageReadsAsWritten() {
    XCTAssertEqual(
      DraftRefusal.tierReferenced(tier: "G1", by: ["P2", "C1"]).message,
      "G1 cannot be deleted: its facets are named by P2, C1. Re-aim or remove those meets first.")
    XCTAssertEqual(
      DraftRefusal.stopReferenced(tier: "G1", index: 12, by: ["C2", "T"]).message,
      "Index stop 12 cannot be removed from G1: it is named by C2, T. "
        + "Re-aim or remove those meets first.")
    XCTAssertEqual(
      DraftRefusal.moveWouldPointForward(tier: "P2", named: "G1").message,
      "P2 cannot move there: P2's meet names G1, and a meet may only name a tier cut earlier.")
    XCTAssertEqual(
      DraftRefusal.duplicateTierLabel("P2").message,
      "There is already a tier called P2.")
    XCTAssertEqual(DraftRefusal.emptyTierLabel.message, "A tier needs a label.")
    XCTAssertEqual(
      DraftRefusal.indexOutOfRange(tier: "G1", index: 100, wheel: 96).message,
      "Index stop 100 is outside 0...95 on G1's gear of 96.")
    XCTAssertEqual(
      DraftRefusal.indicesNotWholeNumbers(typed: "0 12 24.5").message,
      "\"0 12 24.5\" is not a list of whole index stops.")
    XCTAssertEqual(
      DraftRefusal.notANumber(field: "angle", typed: "forty").message,
      "\"forty\" is not a number for angle.")
    XCTAssertEqual(
      DraftRefusal.girdleTargetNotPositive(typed: "0").message,
      "A girdle target has to be greater than zero. "
        + "Leave the field empty for the default of 0.04.")
    XCTAssertEqual(
      DraftRefusal.tiersWithoutMeet(["P4", "C3"]).message,
      "This pattern cannot be saved yet: P4, C3 have no meet. "
        + "Choose one for each, or delete the tier.")
    XCTAssertEqual(DraftRefusal.noTiers.message, "This pattern has no tiers yet.")
  }

  /// One tier reads `has` and two read `have`. The save alert names whatever is actually missing, and a
  /// sentence that says `N1 have no meet` reads as a bug in the tool rather than a fault in the pattern.
  func testTheUnsavableSentenceAgreesWithItsOwnCount() {
    XCTAssertEqual(
      DraftRefusal.tiersWithoutMeet(["N1"]).message,
      "This pattern cannot be saved yet: N1 has no meet. Choose one for each, or delete the tier.")
  }
}
