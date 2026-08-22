import Foundation
import XCTest

@testable import FacetKernel

/// Checks that run `facetsolve` as a subprocess, the way the owner runs it.
///
/// The plan's T8 lists only `main.swift` and `Package.swift`, but its *Done when* asks for a test on the
/// `--girdle` flag, so this file exists to carry it and the rest of that task's checks with it.
final class CLITests: XCTestCase {
  // MARK: - Human output

  func testEasyOctagonPrintsItsTiersAndMetrics() throws {
    let run = try facetsolve([pattern(AuthoredPatterns.easyOctagon)])

    XCTAssertEqual(run.code, 0)
    XCTAssertTrue(run.out.contains("Easy Octagon"), run.out)
    for tier in ["G1", "P1", "P2", "C1", "C2", "T"] {
      let line = try XCTUnwrap(run.line(startingWith: "  \(tier) "), "no line for tier \(tier)")
      XCTAssertTrue(line.contains("d = "), line)
    }
    XCTAssertTrue(try XCTUnwrap(run.line(containing: "facets ")).contains("37"), run.out)
    XCTAssertTrue(run.out.contains("no findings"), run.out)
    XCTAssertTrue(run.out.contains("no observations"), run.out)
  }

  /// The girdle band's thickness is a per-diagram measurement, and a crown tier is cut to the girdle, so
  /// the flag moves the whole crown. Easy Octagon's source diagram measures 3.37%; the 4% default is the
  /// 3-5% rule's midpoint and belongs to no diagram in particular.
  func testGirdleFlagMovesTheCrown() throws {
    let asDrawn = try facetsolve([pattern(AuthoredPatterns.easyOctagon), "--girdle", "0.0337"])
    let asDefaulted = try facetsolve([pattern(AuthoredPatterns.easyOctagon)])

    XCTAssertEqual(try XCTUnwrap(asDrawn.line(startingWith: "  C1 ")).contains("0.719219"), true)
    XCTAssertEqual(
      try XCTUnwrap(asDefaulted.line(startingWith: "  C1 ")).contains("0.728582"), true)
  }

  // MARK: - Exit codes

  /// T8's negative check, automated: a meet naming a facet of its own tier. The solver refuses the
  /// pattern outright, and the fault prints in the same spelling validation would give it.
  func testASelfReferenceExitsOneAndNamesTheTier() throws {
    let broken = try copy(
      AuthoredPatterns.easyOctagon,
      as: "self-reference",
      replacing: "{ \"tier\": \"G1\", \"index\": 12 }",
      with: "{ \"tier\": \"C2\", \"index\": 18 }",
      after: "\"tier\": \"C2\""
    )

    let run = try facetsolve([broken.path])
    XCTAssertEqual(run.code, 1)
    XCTAssertTrue(run.out.contains("namesOwnFacet(tier: \"C2\")"), run.out)

    let original = try facetsolve([pattern(AuthoredPatterns.easyOctagon)])
    XCTAssertEqual(original.code, 0, "the pattern in Design/Patterns is untouched")
  }

  /// Whether findings are fatal is the pattern's state, not the finding: a finished pattern claims to be
  /// valid, and one still being authored does not.
  func testOnlyAFinishedPatternExitsOneOnFindings() throws {
    let twoSizeRows = try copy(
      AuthoredPatterns.easyOctagon,
      as: "two-size-rows",
      replacing: "{ \"kind\": \"tcp\" }",
      with: "{ \"kind\": \"size\" }"
    )
    let stillAuthoring = try copy(
      AuthoredPatterns.easyOctagon,
      as: "two-size-rows-in-progress",
      replacing: "{ \"kind\": \"tcp\" }",
      with: "{ \"kind\": \"size\" }",
      and: ("\"state\": \"finished\"", "\"state\": \"in progress\"")
    )

    let finished = try facetsolve([twoSizeRows.path])
    XCTAssertEqual(finished.code, 1)
    XCTAssertTrue(finished.out.contains("notExactlyOneSizeRow(count: 2)"), finished.out)

    let unfinished = try facetsolve([stillAuthoring.path])
    XCTAssertEqual(unfinished.code, 0)
    XCTAssertTrue(unfinished.out.contains("notExactlyOneSizeRow(count: 2)"), unfinished.out)
  }

  /// A tier cut away entirely is legitimate — it was cut to establish a point a later tier meets — so it
  /// is reported and kept out of the exit code. Pulling Novice Ash-er's C2 fraction back to 0% cuts it to
  /// the ring C1 stands on, which removes every C1 facet.
  func testAnObservationDoesNotSetTheExitCode() throws {
    let consumed = try copy(
      AuthoredPatterns.noviceAsher,
      as: "consumed-tier",
      replacing: "\"percent\": 24.832",
      with: "\"percent\": 0"
    )

    let run = try facetsolve([consumed.path, "--girdle", "0.032260"])
    XCTAssertEqual(run.code, 0)
    XCTAssertTrue(run.out.contains("1 observation: tier C1 contributes no facets"), run.out)
    XCTAssertTrue(run.out.contains("no findings"), run.out)
  }

  // MARK: - Machine output

  func testJSONIsOneObjectWithThreeKeys() throws {
    let run = try facetsolve([
      pattern(AuthoredPatterns.easyOctagon), "--girdle", "0.0337", "--json",
    ])

    XCTAssertEqual(run.code, 0)
    XCTAssertEqual(run.err, "", "the object is all of stdout, and stderr stays empty")

    let decoded = try JSONSerialization.jsonObject(with: Data(run.out.utf8))
    let object = try XCTUnwrap(decoded as? [String: Any])
    XCTAssertEqual(object.keys.sorted(), ["findings", "metrics", "observations"])

    let metrics = try XCTUnwrap(object["metrics"] as? [String: Any])
    XCTAssertEqual(metrics["facetCount"] as? Int, 37)
    XCTAssertEqual(
      try XCTUnwrap(metrics["girdleFractionOfWidth"] as? Double), 0.0337, accuracy: 1e-9)
    XCTAssertEqual((object["findings"] as? [Any])?.count, 0)
    XCTAssertEqual((object["observations"] as? [Any])?.count, 0)
  }

  /// A pattern the solver refuses has no solid, so there are no metrics to report — but the object still
  /// has all three keys, so whatever reads it does not have to special-case the failure.
  func testJSONReportsARefusedSolveWithNullMetrics() throws {
    let broken = try copy(
      AuthoredPatterns.easyOctagon,
      as: "refused",
      replacing: "{ \"tier\": \"P1\", \"index\": 0 }",
      with: "{ \"tier\": \"C1\", \"index\": 0 }"
    )

    let run = try facetsolve([broken.path, "--json"])
    XCTAssertEqual(run.code, 1)

    let object = try XCTUnwrap(
      try JSONSerialization.jsonObject(with: Data(run.out.utf8)) as? [String: Any])
    XCTAssertEqual(object.keys.sorted(), ["findings", "metrics", "observations"])
    XCTAssertTrue(object["metrics"] is NSNull)
    XCTAssertEqual(
      object["findings"] as? [String], ["forwardReference(tier: \"P2\", named: \"C1\")"])
  }

  // MARK: - Running it

  private struct Run {
    let out: String
    let err: String
    let code: Int32

    func line(startingWith prefix: String) -> String? {
      out.split(separator: "\n").map(String.init).first { $0.hasPrefix(prefix) }
    }

    func line(containing text: String) -> String? {
      out.split(separator: "\n").map(String.init).first { $0.contains(text) }
    }
  }

  /// The executable sits beside the test bundle, because the test target depends on it.
  private var binary: URL {
    Bundle(for: type(of: self)).bundleURL
      .deletingLastPathComponent()
      .appendingPathComponent("facetsolve")
  }

  private func facetsolve(_ arguments: [String]) throws -> Run {
    let process = Process()
    process.executableURL = binary
    process.arguments = arguments
    let stdout = Pipe()
    let stderr = Pipe()
    process.standardOutput = stdout
    process.standardError = stderr

    try process.run()
    let out = stdout.fileHandleForReading.readDataToEndOfFile()
    let err = stderr.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()

    return Run(
      out: String(decoding: out, as: UTF8.self),
      err: String(decoding: err, as: UTF8.self),
      code: process.terminationStatus
    )
  }

  private func pattern(_ name: String) -> String {
    AuthoredPatterns.url(name).path
  }

  /// A copy of an authored pattern with one or two edits, written outside the repository. The originals
  /// are ground truth and nothing here touches them.
  private func copy(
    _ name: String,
    as label: String,
    replacing text: String,
    with replacement: String,
    after anchor: String? = nil,
    and second: (String, String)? = nil
  ) throws -> URL {
    var source = try String(contentsOf: AuthoredPatterns.url(name), encoding: .utf8)

    let from = try anchor.map { anchor -> String.Index in
      try XCTUnwrap(source.range(of: anchor)?.upperBound, "no anchor \(anchor)")
    }
    let target = try XCTUnwrap(
      source.range(of: text, range: (from ?? source.startIndex)..<source.endIndex),
      "no \(text) to replace"
    )
    source.replaceSubrange(target, with: replacement)

    if let second {
      let range = try XCTUnwrap(source.range(of: second.0), "no \(second.0) to replace")
      source.replaceSubrange(range, with: second.1)
    }

    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent("facetsolve-\(label)-\(UUID().uuidString)")
      .appendingPathExtension("json")
    try source.write(to: url, atomically: true, encoding: .utf8)
    scratch.append(url)
    return url
  }

  private var scratch: [URL] = []

  override func tearDown() {
    for url in scratch { try? FileManager.default.removeItem(at: url) }
    scratch = []
    super.tearDown()
  }
}
