import FacetKernel
import Foundation
import XCTest

@testable import BenchGeometry

/// The verdict behind a `finished` claim: the one check in this app that blocks rather than reports.
/// `AuthoredPatterns` lives in `BenchSolidTests.swift`.
final class FinishCheckTests: XCTestCase {

  // MARK: - The baseline

  /// All four authored patterns are correct and complete, so all four may be claimed finished. Every other
  /// case here is read against that.
  func testEveryAuthoredPatternMayBeMarkedFinished() throws {
    for name in AuthoredPatterns.all {
      let draft = PatternDraft(try AuthoredPatterns.load(name))
      XCTAssertNil(finishRefusal(draft: draft, declaredFacets: ""), name)
    }
  }

  // MARK: - A draft with no file form at all

  /// Answered before the solve, because a draft with a meetless tier has no `Pattern` to solve. The
  /// sentence no longer opens with `This pattern cannot be saved yet:` — this case now answers a
  /// `finished` transition as well as a save.
  func testATierWithNoMeetRefusesAndNamesIt() throws {
    var draft = PatternDraft(try AuthoredPatterns.load(AuthoredPatterns.easyOctagon))
    draft.tiers.append(
      DraftTier(tier: "N1", part: .crown, angle: 30, indices: [0, 24, 48, 72], meet: nil))

    let refusal = try XCTUnwrap(finishRefusal(draft: draft, declaredFacets: ""))
    XCTAssertEqual(refusal, .tiersWithoutMeet(["N1"]))
    XCTAssertTrue(refusal.message.contains("N1"))
    XCTAssertFalse(refusal.message.hasPrefix("This pattern"))
  }

  func testAnEmptyDraftRefuses() {
    XCTAssertEqual(finishRefusal(draft: .empty, declaredFacets: ""), .noTiers)
  }

  // MARK: - A validation that finds something

  /// The size row is the unit every other depth is expressed in, so a pattern carrying none is wrong even
  /// though it still solves. The sentence is the findings popover's own, not a second wording here.
  func testAStructuralFaultRefusesAndListsIt() throws {
    var draft = PatternDraft(try AuthoredPatterns.load(AuthoredPatterns.easyOctagon))
    draft.tiers[0].meet = .tcp

    let refusal = try XCTUnwrap(finishRefusal(draft: draft, declaredFacets: ""))
    guard case .finishedWithFindings(let sentences) = refusal else {
      return XCTFail("expected findings, got \(refusal)")
    }
    XCTAssertEqual(sentences, [findingText(.notExactlyOneSizeRow(count: 0))])
  }

  // MARK: - A solve that stops short

  /// A stopped solve is not a finding, so without this refusal `finished` could be claimed on a pattern
  /// with a tier that will not place. A girdle meet needs the vertical planes that bound the outline, so a
  /// pattern cutting the crown before the girdle stops on its first tier.
  func testAStoppedSolveRefusesByItself() throws {
    let draft = draftOf([
      DraftTier(tier: "C1", part: .crown, angle: 40, indices: octagon, meet: .girdle),
      DraftTier(tier: "G", part: .gdl, angle: 90, indices: octagon, meet: .size),
    ])

    let refusal = try XCTUnwrap(finishRefusal(draft: draft, declaredFacets: ""))
    guard case .finishedWithSolveStoppedShort(let tier, let reason) = refusal else {
      return XCTFail("expected a stopped solve, got \(refusal)")
    }
    XCTAssertEqual(tier, "C1")
    // The kernel's own sentence, read from the kernel rather than copied, so this cannot pin a wording.
    XCTAssertEqual(reason, SolverError.girdleOutlineUndetermined(tier: "C1").description)
  }

  // MARK: - The declared facet count

  /// A field making no claim blocks nothing, and neither does a half-typed one: the same reading
  /// `facetCountCheck` already gives it.
  func testADeclaredCountThatMakesNoClaimDoesNotBlock() throws {
    let draft = PatternDraft(try AuthoredPatterns.load(AuthoredPatterns.easyOctagon))

    for typed in ["", "  ", "5x", "0", "-37", "37.0"] {
      XCTAssertNil(finishRefusal(draft: draft, declaredFacets: typed), "declared \"\(typed)\"")
    }
  }

  func testTheRightDeclaredCountDoesNotBlock() throws {
    let pattern = try AuthoredPatterns.load(AuthoredPatterns.easyOctagon)
    let solution = try XCTUnwrap(benchSolid(for: pattern).solution)
    let solved = solution.polytope.facets.count
    XCTAssertEqual(solved, 37, "the sheet declares 37")

    XCTAssertNil(finishRefusal(draft: PatternDraft(pattern), declaredFacets: String(solved)))
  }

  func testAWrongDeclaredCountRefuses() throws {
    let draft = PatternDraft(try AuthoredPatterns.load(AuthoredPatterns.easyOctagon))

    let refusal = try XCTUnwrap(finishRefusal(draft: draft, declaredFacets: "99"))
    guard case .finishedWithFindings(let sentences) = refusal else {
      return XCTFail("expected findings, got \(refusal)")
    }
    XCTAssertEqual(sentences, [findingText(.facetCountMismatch(solved: 37, declared: 99))])
  }

  // MARK: - Going the other way

  /// Claiming `in progress` claims nothing, so the setter never refuses — not on a draft the finish check
  /// turns down, and not on one with no tiers at all.
  func testInProgressIsNeverChecked() throws {
    var refused = PatternDraft(try AuthoredPatterns.load(AuthoredPatterns.easyOctagon))
    refused.state = .finished
    refused.tiers[0].meet = nil
    XCTAssertNotNil(finishRefusal(draft: refused, declaredFacets: ""))

    let backed = try setting(state: .inProgress, in: refused).get()
    XCTAssertEqual(backed.state, .inProgress)

    let fromEmpty = try setting(state: .inProgress, in: .empty).get()
    XCTAssertEqual(fromEmpty.state, .inProgress)
  }

  func testTheStateSetterAlsoAppliesFinished() throws {
    let draft = PatternDraft(try AuthoredPatterns.load(AuthoredPatterns.easyOctagon))
    let finished = try setting(state: .finished, in: draft).get()
    XCTAssertEqual(finished.state, .finished)
    // Nothing but the field moved.
    var expected = draft
    expected.state = .finished
    XCTAssertEqual(finished, expected)
  }

  // MARK: - The sentence

  /// One bulleted line per finding, and a count that agrees with its own grammar. Built from the case
  /// directly: this is about the wording, not about which pattern produces how many findings.
  func testTheMessageListsEveryFindingOneBulletedLineEach() {
    let one = DraftRefusal.finishedWithFindings(["Something is wrong."]).message
    XCTAssertTrue(one.contains("1 finding fired"))
    XCTAssertFalse(one.contains("findings fired"))
    XCTAssertEqual(one.components(separatedBy: "• ").count - 1, 1)
    XCTAssertTrue(one.contains("• Something is wrong."))

    let two = DraftRefusal.finishedWithFindings([
      "Something is wrong.", "So is something else.",
    ]).message
    XCTAssertTrue(two.contains("2 findings fired"))
    XCTAssertEqual(two.components(separatedBy: "• ").count - 1, 2)
    XCTAssertTrue(two.contains("\n• So is something else."))
  }

  func testTheStoppedSolveSentenceNamesTheTierAndTheReason() {
    let message = DraftRefusal.finishedWithSolveStoppedShort(
      tier: "C1", reason: "tier C1: the girdle outline is not bounded"
    ).message

    XCTAssertEqual(
      message,
      "This pattern cannot be marked finished: the solve stops at C1 — "
        + "tier C1: the girdle outline is not bounded. "
        + "A tier that will not place has no facets on the stone.")
  }

  // MARK: - Helpers

  private let octagon = [0, 12, 24, 36, 48, 60, 72, 84]

  private func draftOf(_ tiers: [DraftTier]) -> PatternDraft {
    PatternDraft(
      formatVersion: 1,
      name: "synthetic",
      state: .inProgress,
      wheel: 96,
      ri: 1.54,
      girdleTargetFraction: nil,
      designer: "",
      notes: "",
      tiers: tiers)
  }
}
