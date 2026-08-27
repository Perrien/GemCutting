import Foundation
import XCTest

@testable import FacetKernel

/// The solver's absolute anchor.
///
/// Every other check in this package is internal: a pattern solves to the offsets its own diagram was
/// measured to, and the metrics agree with the solve. All of that can pass on a solver that is
/// self-consistently wrong. This one cannot. Its source is a published quartz standard round brilliant
/// whose four proportion ratios were computed without this kernel, and three of them depend on several
/// tiers and their meets at once.
///
/// `Pattern-Standard-Round-Brilliant.json` is a fixture under the same guardrail as the other patterns:
/// nothing here edits it, and no tolerance below is loosened to make a ratio pass. Its `notes` carry the
/// source, the attribution and the sheet's verbatim meet text.
///
/// The `s` and `t` meets are insensitive to which valid triple names them. The sheet says only "cut to
/// meet cm,cb" and "cut to meet s,cm"; six combinations of those facets were checked when this pattern
/// was authored and all give identical geometry, so a reader who picks a different triple has not broken
/// anything.
final class RoundBrilliantTests: XCTestCase {
  /// The sheet's own girdle, and the reason it is known: its stated identity `H/W = (P+C)/W + 0.02`. It
  /// is passed per solve and never made the default.
  private let girdle = 0.020000

  /// The ratios as published, and the tolerance they are published to.
  private let published = (pavilion: 0.466, crown: 0.218, height: 0.704, table: 0.516)
  private let tolerance = 0.001

  // MARK: - The published ratios

  /// The pavilion, crown and height ratios come out of the solve within a thousandth of the sheet's
  /// figures: 0.4663, 0.2177 and 0.7040 against 0.466, 0.218 and 0.704.
  ///
  /// The height ratio is the one that pins where the girdle band is measured from. Measuring the crown
  /// from the girdle's mid-plane instead of its top would move `C/W` by half the band — 2.2 points on this
  /// stone — and the identity the sheet publishes would stop holding.
  func testThePublishedDepthRatios() throws {
    let measured = try measure()

    XCTAssertEqual(
      measured.pavilionDepthFractionOfWidth, published.pavilion, accuracy: tolerance, "P/W")
    XCTAssertEqual(measured.crownHeightFractionOfWidth, published.crown, accuracy: tolerance, "C/W")
    XCTAssertEqual(measured.totalDepthFractionOfWidth, published.height, accuracy: tolerance, "H/W")
    XCTAssertEqual(
      measured.pavilionDepthFractionOfWidth + measured.crownHeightFractionOfWidth + 0.02,
      measured.totalDepthFractionOfWidth,
      accuracy: 1e-9,
      "the sheet's own identity: H/W = (P+C)/W + the 2% girdle"
    )
  }

  /// The table ratio is the one that earns its place. Nothing in the pattern says how big the table is: it
  /// falls out of the star and crown-main angles through three chained vertex meets, so a solver that
  /// mis-chains them breaks this and leaves the pavilion alone.
  ///
  /// `Metrics` derives it and `facetsolve --json` reports it, so the second assertion is what makes "one
  /// definition" a checked claim: the metric and the number the CLI prints are the same number, not two
  /// implementations that happen to agree to three places.
  func testThePublishedTableRatio() throws {
    let reported = try tableFractionOfWidth()

    XCTAssertEqual(reported, published.table, accuracy: tolerance, "T/W")
    XCTAssertEqual(try measure().tableFractionOfWidth, reported, accuracy: 1e-9, "one definition")
  }

  // MARK: - Counts, symmetry and the width axis

  func testSeventyThreeFacetsInTheSheetsOwnBreakdown() throws {
    let measured = try measure()

    XCTAssertEqual(measured.facetCount, 73)
    XCTAssertEqual(
      measured.facetsPerTier,
      ["pb": 16, "g": 16, "pm": 8, "cb": 16, "cm": 8, "s": 8, "t": 1],
      "16 pb + 16 g + 8 pm + 16 cb + 8 cm + 8 s + 1 t"
    )
    XCTAssertTrue(
      try pattern().notes.contains("73"), "the sheet declares 57 facets plus 16 on the girdle")
  }

  func testItIsRoundAndEightFold() throws {
    let measured = try measure()

    XCTAssertEqual(measured.lengthOverWidth, 1.000, accuracy: tolerance, "L/W")
    XCTAssertEqual(measured.rotationalOrder, 8)
  }

  /// Sixteen girdle facets are chords of an intended circle, so the width axis crosses a girdle *corner*
  /// rather than a flat and the width is `2 / cos(11.25 degrees)` rather than 2. This is where the axis
  /// convention meets a published width: measuring the width as twice the smallest girdle offset would
  /// give 2.0 here, and miss all four ratios above by about 2%.
  func testWidthCrossesAGirdleCorner() throws {
    let measured = try measure()

    XCTAssertEqual(measured.widthNormalised, 2.03918, accuracy: 1e-5)
    XCTAssertEqual(measured.lengthNormalised, 2.03918, accuracy: 1e-5)
  }

  /// A published stone with a fault in its transcription would be a poor anchor.
  func testTheAnchorItselfIsClean() throws {
    let solution = try solve(try pattern(), girdleTargetFraction: girdle)
    let report = validate(try pattern(), solution, declaredFacetCount: 73)

    XCTAssertEqual(report.findings, [])
    XCTAssertEqual(report.notices, [])
  }

  /// The pattern this anchor rests on is the sheet as transcribed: seven tiers on a 96 wheel, finished, at
  /// RI 1.54. A drift here would quietly change what the ratios above are testing.
  func testThePatternIsStillTheSheetAsTranscribed() throws {
    let brilliant = try pattern()

    XCTAssertEqual(brilliant.wheel, 96)
    XCTAssertEqual(brilliant.state, .finished)
    XCTAssertEqual(brilliant.ri, 1.54)

    let transcribed: [(String, Part, Double, Int)] = [
      ("pb", .pav, 45.00, 16),
      ("g", .gdl, 90.00, 16),
      ("pm", .pav, 43.00, 8),
      ("cb", .crown, 47.00, 16),
      ("cm", .crown, 42.00, 8),
      ("s", .crown, 27.00, 8),
      ("t", .table, 0.00, 1),
    ]
    XCTAssertEqual(brilliant.tiers.count, transcribed.count)
    for (spec, expected) in zip(brilliant.tiers, transcribed) {
      XCTAssertEqual(spec.tier, expected.0)
      XCTAssertEqual(spec.part, expected.1, spec.tier)
      XCTAssertEqual(spec.angle, expected.2, accuracy: 1e-12, spec.tier)
      XCTAssertEqual(spec.indices.count, expected.3, spec.tier)
    }
  }

  // MARK: - Verification handle (T10, permanent)

  /// Prints the row the owner checks: `no findings`, 73 facets, and the four ratios.
  ///
  /// T10's negative check: change `s`'s angle from 27.00 to 22.00 in a `/tmp` copy and run `facetsolve` on
  /// it. `T/W` moves off 0.516 by more than 0.01 while `P/W` stays at 0.466 — the table is downstream of
  /// the star and the pavilion is not, so a solver that mis-chains vertex meets breaks one and not the
  /// other.
  func testDump() throws {
    let measured = try measure()

    print(
      "Standard Round Brilliant: facets \(measured.facetCount)  "
        + "W \(String(format: "%.5f", measured.widthNormalised))  "
        + "L/W \(String(format: "%.3f", measured.lengthOverWidth))  "
        + "P/W \(String(format: "%.4f", measured.pavilionDepthFractionOfWidth))  "
        + "C/W \(String(format: "%.4f", measured.crownHeightFractionOfWidth))  "
        + "H/W \(String(format: "%.4f", measured.totalDepthFractionOfWidth))  "
        + "T/W \(String(format: "%.4f", try tableFractionOfWidth()))")

    XCTAssertEqual(measured.facetCount, 73)
  }

  // MARK: - Helpers

  private func pattern() throws -> FacetKernel.Pattern {
    try AuthoredPatterns.load(AuthoredPatterns.roundBrilliant)
  }

  private func measure() throws -> Metrics {
    metrics(try solve(try pattern(), girdleTargetFraction: girdle))
  }

  /// The table's extent along the width axis, over the width, as `facetsolve` reports it.
  private func tableFractionOfWidth() throws -> Double {
    let process = Process()
    process.executableURL = Bundle(for: type(of: self)).bundleURL
      .deletingLastPathComponent()
      .appendingPathComponent("facetsolve")
    process.arguments = [
      AuthoredPatterns.url(AuthoredPatterns.roundBrilliant).path,
      "--girdle", "0.020000", "--json",
    ]
    let stdout = Pipe()
    process.standardOutput = stdout

    try process.run()
    let out = stdout.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    XCTAssertEqual(process.terminationStatus, 0)

    let object = try XCTUnwrap(JSONSerialization.jsonObject(with: out) as? [String: Any])
    let reported = try XCTUnwrap(object["metrics"] as? [String: Any])
    return try XCTUnwrap(reported["tableFractionOfWidth"] as? Double)
  }
}
