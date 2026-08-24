import Foundation
import XCTest

/// Golden-file checks: each fixture is a `--json` run of `facetsolve` committed as it was printed, and
/// this re-runs the same command and compares byte for byte.
///
/// The fixtures are external ground truth. A fixture and the code disagreeing means the code changed or a
/// real discrepancy has been found; either way it is a stop, never an edit to the fixture.
///
/// The command that regenerates each one is `regenerate` below. It passes no `--girdle`: each pattern
/// declares its own diagram-measured target in its header, which is the value these fixtures were
/// generated at, so the flag would only be a second place for that number to live. The plan asks for that
/// command in a comment at the top of each fixture, but a `.json` file carrying a comment is not JSON and
/// could not then be the CLI's output verbatim, which the same check requires — so it lives here, next to
/// the comparison, and prints on failure.
final class RegressionTests: XCTestCase {
  private struct Fixture {
    let pattern: String
    let file: String
    var regenerate: String {
      "facetsolve Design/Patterns/\(pattern).json --json"
    }
  }

  private static let fixtures: [Fixture] = [
    Fixture(pattern: AuthoredPatterns.easyOctagon, file: "easy-octagon.json"),
    Fixture(pattern: AuthoredPatterns.noviceAsher, file: "novice-asher.json"),
    Fixture(pattern: AuthoredPatterns.rands, file: "rands-cut-corner-rectangle.json"),
  ]

  func testEachPatternStillSolvesToItsFixture() throws {
    for fixture in Self.fixtures {
      let run = try facetsolve([AuthoredPatterns.url(fixture.pattern).path, "--json"])
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

  /// The girdle fraction is part of the fixture, not a detail of how it was made. Overriding the
  /// pattern's own target with the flag prints different crown offsets and different proportions, so a
  /// fixture regenerated at the 0.04 default would look like a regression in the solver.
  func testTheGirdleFractionIsPartOfTheFixture() throws {
    let fixture = Self.fixtures[0]
    let atTheDefault = try facetsolve([
      AuthoredPatterns.url(fixture.pattern).path, "--girdle", "0.04", "--json",
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
