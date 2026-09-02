import FacetKernel
import Foundation
import XCTest

@testable import BenchGeometry

/// The detail pane's generator: what a typed seed set, fold count and mirror flag come to, and the four
/// faults that produce no list at all.
///
/// `Pattern` is qualified as `FacetKernel.Pattern` throughout: XCTest pulls in ApplicationServices, whose
/// Quickdraw.h declares a `Pattern` struct, and the bare name is ambiguous in a test file in this target.
final class StopsProposalTests: XCTestCase {

  // MARK: - What it generates

  func testOneSeedEightFoldOnNinetySixGeneratesEveryTwelfthStop() {
    let proposed = proposedStops(
      seeds: "0", folds: "8", mirror: false, ofTier: "P1", wheel: 96)
    XCTAssertEqual(try proposed.get(), [0, 12, 24, 36, 48, 60, 72, 84])
  }

  /// Commas and whitespace both separate, because the Indices cell's own parser accepts both and the two
  /// must not disagree about what a stop list is.
  func testSeedsSplitOnCommasAsWellAsSpaces() {
    let spaces = proposedStops(seeds: "0 1", folds: "8", mirror: false, ofTier: "P1", wheel: 96)
    let commas = proposedStops(seeds: "0,1", folds: "8", mirror: false, ofTier: "P1", wheel: 96)
    XCTAssertEqual(try spaces.get(), try commas.get())
    XCTAssertEqual(try spaces.get().count, 16)
  }

  /// Mirroring is applied before the rotation, so a seed that is not on the mirror line doubles the set.
  func testMirroringDoublesAnOffAxisSeed() {
    let plain = proposedStops(seeds: "4", folds: "4", mirror: false, ofTier: "C1", wheel: 96)
    let mirrored = proposedStops(seeds: "4", folds: "4", mirror: true, ofTier: "C1", wheel: 96)
    XCTAssertEqual(try plain.get(), [4, 28, 52, 76])
    XCTAssertEqual(try mirrored.get(), [4, 20, 28, 44, 52, 68, 76, 92])
  }

  /// A seed already on the mirror line generates the same set either way, which is what makes the pane's
  /// checkbox honest rather than inert: it is offered, and it simply shows the same list.
  func testMirroringASymmetricSeedChangesNothing() {
    let plain = proposedStops(seeds: "0", folds: "8", mirror: false, ofTier: "P1", wheel: 96)
    let mirrored = proposedStops(seeds: "0", folds: "8", mirror: true, ofTier: "P1", wheel: 96)
    XCTAssertEqual(try plain.get(), try mirrored.get())
  }

  /// The generated list is ascending and deduplicated whatever order the seeds arrive in — which is the
  /// whole reason the copy is a button rather than something that happens as you type. A pattern
  /// transcribed in a printed sheet's own order keeps that order until the author asks for this one.
  func testGeneratedStopsAreAscendingWhateverOrderTheSeedsAreTypedIn() {
    let ascending = proposedStops(seeds: "0 1", folds: "8", mirror: false, ofTier: "P1", wheel: 96)
    let reversed = proposedStops(seeds: "1 0", folds: "8", mirror: false, ofTier: "P1", wheel: 96)
    XCTAssertEqual(try ascending.get(), try reversed.get())
    XCTAssertEqual(try ascending.get(), try ascending.get().sorted())
  }

  func testARepeatedSeedGeneratesNoDuplicate() {
    let proposed = proposedStops(seeds: "0 0", folds: "4", mirror: false, ofTier: "P1", wheel: 96)
    XCTAssertEqual(try proposed.get(), [0, 24, 48, 72])
  }

  /// One fold is the generator honestly off: the seeds are the stops.
  func testOneFoldGeneratesTheSeedsThemselves() {
    let proposed = proposedStops(
      seeds: "3 17 40", folds: "1", mirror: false, ofTier: "P1", wheel: 96)
    XCTAssertEqual(try proposed.get(), [3, 17, 40])
  }

  /// **Not a refusal.** An empty field is what a half-typed one passes through, and saying "no stops" is
  /// an honest answer where a red sentence would be noise on every keystroke.
  func testAnEmptySeedListGeneratesNoStopsRatherThanRefusing() {
    let proposed = proposedStops(seeds: "", folds: "8", mirror: false, ofTier: "P1", wheel: 96)
    XCTAssertEqual(try proposed.get(), [])
  }

  // MARK: - The four faults

  func testSeedsThatAreNotWholeNumbersAreRefused() {
    let proposed = proposedStops(
      seeds: "0 half", folds: "8", mirror: false, ofTier: "P1", wheel: 96)
    XCTAssertEqual(proposed.refusal, .indicesNotWholeNumbers(typed: "0 half"))
  }

  func testASeedOutsideTheGearIsRefusedNamingTheStop() {
    let proposed = proposedStops(seeds: "0 96", folds: "8", mirror: false, ofTier: "P1", wheel: 96)
    XCTAssertEqual(proposed.refusal, .indexOutOfRange(tier: "P1", index: 96, wheel: 96))
  }

  func testAFoldCountThatIsNotANumberIsRefused() {
    let proposed = proposedStops(
      seeds: "0", folds: "eight", mirror: false, ofTier: "P1", wheel: 96)
    XCTAssertEqual(proposed.refusal, .notANumber(field: "folds", typed: "eight"))
  }

  /// 7-fold is reachable on 84 and impossible on 96, which is the pair the sentence is written for.
  func testAFoldCountThatDoesNotDivideTheGearIsRefused() {
    let onNinetySix = proposedStops(
      seeds: "0", folds: "7", mirror: false, ofTier: "P1", wheel: 96)
    XCTAssertEqual(onNinetySix.refusal, .foldsNotADivisor(tier: "P1", folds: 7, wheel: 96))

    let onEightyFour = proposedStops(
      seeds: "0", folds: "7", mirror: false, ofTier: "P1", wheel: 84)
    XCTAssertEqual(try onEightyFour.get(), [0, 12, 24, 36, 48, 60, 72])
  }

  /// The seed list is judged before the fold count, so a message names the first thing wrong reading down
  /// the pane rather than whichever check happens to run first.
  func testABadSeedIsReportedAheadOfABadFoldCount() {
    let proposed = proposedStops(
      seeds: "half", folds: "seven", mirror: false, ofTier: "P1", wheel: 96)
    XCTAssertEqual(proposed.refusal, .indicesNotWholeNumbers(typed: "half"))
  }

  // MARK: - Against the corpus

  /// Every authored tier's own derived generator, typed back in as text, proposes exactly that tier's
  /// stops. This is what makes the pane's fields safe to open on: pressing Copy without touching anything
  /// writes the list the tier already has, so a redundant press is a genuine no-op.
  ///
  /// Compared against the sorted stops, because the generator's output is ascending and one authored
  /// pattern is transcribed in its printed sheet's order.
  func testEveryAuthoredTiersOwnGeneratorProposesItsOwnStops() throws {
    var checked = 0
    for name in AuthoredPatterns.all {
      let pattern = try AuthoredPatterns.load(name)
      for tier in pattern.tiers {
        let gear = pattern.wheel(of: tier)
        let symmetry = derivedSymmetry(stops: tier.indices, wheel: gear)
        let proposed = proposedStops(
          seeds: stopsText(symmetry.seeds),
          folds: String(symmetry.folds),
          mirror: symmetry.mirror,
          ofTier: tier.tier,
          wheel: gear)
        XCTAssertEqual(try proposed.get(), tier.indices.sorted(), "\(name) tier \(tier.tier)")
        checked += 1
      }
    }
    XCTAssertEqual(checked, 32)
  }

  // MARK: - The spelling

  /// The one spelling both the Indices cell and the proposal use, so what the pane shows is character for
  /// character what a copy writes.
  func testStopsTextIsSpaceSeparatedInTheOrderGiven() {
    XCTAssertEqual(stopsText([12, 24, 36, 48, 60, 72, 84, 0]), "12 24 36 48 60 72 84 0")
    XCTAssertEqual(stopsText([]), "")
  }

  /// What the pane writes round-trips through the cell's own parser, which is the guarantee that the copy
  /// can never be refused for its spelling.
  func testWhatTheProposalShowsParsesBackToTheSameStops() {
    let stops = try? proposedStops(
      seeds: "0 1", folds: "8", mirror: true, ofTier: "P1", wheel: 96
    ).get()
    let text = stopsText(stops ?? [])
    XCTAssertEqual(parsedStops(text), stops)
  }
}

extension Result where Failure == DraftRefusal {
  /// The refusal, or `nil` for a success — so a test asserts on the case it means rather than unwrapping
  /// through a `switch` every time.
  fileprivate var refusal: DraftRefusal? {
    switch self {
    case .success: nil
    case .failure(let refusal): refusal
    }
  }
}
