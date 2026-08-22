import Foundation
import XCTest

/// Golden-file checks: each fixture is a `--json` run of `facetsolve` committed as it was printed, and
/// this re-runs the same command and compares byte for byte.
///
/// The fixtures are external ground truth. A fixture and the code disagreeing means the code changed or a
/// real discrepancy has been found; either way it is a stop, never an edit to the fixture.
///
/// The command that regenerates each one is `regenerate` below, and it carries the pattern's own
/// `--girdle` fraction: regenerated at the 0.04 default every crown offset would move, and the difference
/// would read as a solver regression. The plan asks for that command in a comment at the top of each
/// fixture, but a `.json` file carrying a comment is not JSON and could not then be the CLI's output
/// verbatim, which the same check requires — so it lives here, next to the comparison, and prints on
/// failure.
final class RegressionTests: XCTestCase {
  private struct Fixture {
    let pattern: String
    let girdle: String
    let file: String
    var regenerate: String {
      "facetsolve Design/Patterns/\(pattern).json --girdle \(girdle) --json"
    }
  }

  private static let fixtures: [Fixture] = [
    Fixture(
      pattern: AuthoredPatterns.easyOctagon,
      girdle: "0.033700",
      file: "easy-octagon.json"
    ),
    Fixture(
      pattern: AuthoredPatterns.noviceAsher,
      girdle: "0.032260",
      file: "novice-asher.json"
    ),
    Fixture(
      pattern: AuthoredPatterns.rands,
      girdle: "0.040493",
      file: "rands-cut-corner-rectangle.json"
    ),
  ]

  func testEachPatternStillSolvesToItsFixture() throws {
    for fixture in Self.fixtures {
      let run = try facetsolve([
        AuthoredPatterns.url(fixture.pattern).path, "--girdle", fixture.girdle, "--json",
      ])
      XCTAssertEqual(run.code, 0, fixture.file)

      let golden = try String(
        contentsOf: Self.directory.appendingPathComponent(fixture.file),
        encoding: .utf8
      )
      XCTAssertEqual(
        run.out,
        golden,
        "\(fixture.file) no longer matches. If the change is intended: \(fixture.regenerate)"
      )
    }
  }

  /// The girdle fraction is part of the fixture, not a detail of how it was made. At the 0.04 default the
  /// same pattern prints different crown offsets and different proportions, so a fixture regenerated
  /// without the flag would look like a regression in the solver.
  func testTheGirdleFractionIsPartOfTheFixture() throws {
    let fixture = Self.fixtures[0]
    let atTheDefault = try facetsolve([
      AuthoredPatterns.url(fixture.pattern).path, "--json",
    ])
    let golden = try String(
      contentsOf: Self.directory.appendingPathComponent(fixture.file),
      encoding: .utf8
    )

    XCTAssertEqual(atTheDefault.code, 0)
    XCTAssertNotEqual(atTheDefault.out, golden)
  }

  // MARK: - Running it

  private static let directory: URL =
    URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .appendingPathComponent("Fixtures")

  private func facetsolve(_ arguments: [String]) throws -> (out: String, code: Int32) {
    let process = Process()
    process.executableURL = Bundle(for: type(of: self)).bundleURL
      .deletingLastPathComponent()
      .appendingPathComponent("facetsolve")
    process.arguments = arguments
    let stdout = Pipe()
    process.standardOutput = stdout

    try process.run()
    let out = stdout.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()

    return (out: String(decoding: out, as: UTF8.self), code: process.terminationStatus)
  }
}
