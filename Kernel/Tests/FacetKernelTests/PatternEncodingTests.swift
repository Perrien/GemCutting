import FacetKernel
import Foundation
import XCTest

/// The writer beside the reader (ADR-0003). `Meet` decodes through a hand-written initialiser, so its
/// encoder is hand-written too — which is why the round trips here are not optional: nothing but a test
/// makes the two halves agree on a key name.
///
/// Equality for a round trip, never bytes against an authored file: `JSONEncoder` emits `90` where the
/// authored files write `90.00`, and the format document says those are the same value, so that
/// comparison would fail on something that is not a difference. Bytes against *another encoding of the
/// same pattern* is a different claim, and one test below makes it — see `testTheSaveIsDeterministic`.
final class PatternEncodingTests: XCTestCase {

  // MARK: - Round trips

  func testTheFourAuthoredPatternsRoundTripToAnEqualValue() throws {
    for name in [
      AuthoredPatterns.easyOctagon, AuthoredPatterns.noviceAsher,
      AuthoredPatterns.rands, AuthoredPatterns.roundBrilliant,
    ] {
      let original = try AuthoredPatterns.load(name)
      let reread = try decode(try encoded(original))
      XCTAssertEqual(reread, original, name)
    }
  }

  /// Two encodings of one pattern are the same bytes, which is the whole reason the writer sorts its
  /// keys. Without `.sortedKeys` a keyed container comes out in dictionary order, Foundation seeds string
  /// hashing per process, and saving an unchanged pattern would rewrite its field order every time.
  ///
  /// Within one process this cannot detect an unsorted encoder, so it checks the sorting directly too: a
  /// sorted file is one whose header keys are in ascending order.
  func testTheSaveIsDeterministic() throws {
    let pattern = try AuthoredPatterns.load(AuthoredPatterns.easyOctagon)
    XCTAssertEqual(try encoded(pattern), try encoded(pattern))

    let text = String(decoding: try encoded(pattern), as: UTF8.self)
    let headerKeys = text.split(separator: "\n").compactMap { line -> String? in
      guard line.hasPrefix("  \"") else { return nil }
      return line.dropFirst(3).prefix { $0 != "\"" }.description
    }
    XCTAssertEqual(headerKeys, headerKeys.sorted())
    XCTAssertEqual(headerKeys.first, "designer")
  }

  /// All five meet forms in one pattern, plus the two fields that must survive being optional: a tier
  /// carrying `instructions` and a tier cut on a wheel of its own.
  func testAllFiveMeetFormsRoundTrip() throws {
    let pattern = Self.everyForm
    let reread = try decode(try encoded(pattern))

    XCTAssertEqual(reread, pattern)
    XCTAssertEqual(
      reread.tiers.map(\.meet.kindName), ["size", "tcp", "vertex", "fraction", "girdle"])
    XCTAssertEqual(reread.tiers[3].instructions, "Cut to the step, then check it against P1.")
    XCTAssertEqual(reread.tiers[4].wheel, 120)
  }

  // MARK: - Absent stays absent

  /// Asserted against the JSON the encoder actually emitted, not against the `Pattern` it round-trips
  /// to: an encoder that wrote `null`, or wrote the default it filled in, would still round-trip to an
  /// equal value while quietly rewriting every file the app touches.
  func testAbsentStaysAbsentAndEmptyStaysEmpty() throws {
    var pattern = Self.everyForm
    pattern.girdleTargetFraction = nil
    pattern.tiers[0].instructions = ""
    pattern.tiers[1].instructions = nil

    let object = try json(of: pattern)
    XCTAssertNil(object["girdleTargetFraction"], "an undeclared target must not be written")

    let tiers = try XCTUnwrap(object["tiers"] as? [[String: Any]])
    XCTAssertEqual(tiers[0]["instructions"] as? String, "", "prose written as empty stays empty")
    XCTAssertNil(tiers[1]["instructions"], "prose never written stays unwritten")
    XCTAssertNil(tiers[0]["wheel"], "a tier inheriting the pattern's wheel is written without one")
    XCTAssertEqual(tiers[4]["wheel"] as? Int, 120, "a tier that overrides its wheel keeps it")
  }

  // MARK: - Encoding refuses what decoding refuses

  /// Every rule the decoder enforces, checked against a pattern built in memory through
  /// `Pattern.init` — which performs no checks at all. That is exactly why this matters: without the
  /// shared rule function an app could hand the kernel a pattern it would then refuse to read back.
  func testEncodingRefusesWhatDecodingRefuses() {
    expect(Self.pattern(tiers: [Self.tier("P1"), Self.tier("P1", angle: 41)])) {
      $0 == .duplicateTierLabel("P1")
    }
    expect(Self.pattern(tiers: [Self.tier("")])) { $0 == .emptyTierLabel }
    expect(Self.pattern(tiers: [Self.tier("P1", indices: [0, 96])])) {
      $0 == .indexOutOfRange(tier: "P1", index: 96, wheel: 96)
    }
    expect(
      Self.pattern(
        tiers: [
          Self.tier(
            "P1",
            meet: .vertex(facets: [FacetRef(tier: "G1", index: 0), FacetRef(tier: "G1", index: 12)])
          )
        ])
    ) { $0 == .vertexNeedsThreeFacets(tier: "P1", count: 2) }
    expect(
      Self.pattern(
        tiers: [Self.tier("P2", meet: .fraction(from: Self.vertex, percent: 101, to: .tcp))])
    ) { $0 == .percentOutOfRange(tier: "P2", percent: 101) }
    expect(Self.pattern(formatVersion: 2, tiers: [Self.tier("P1")])) {
      $0 == .unsupportedFormatVersion(2)
    }
    expect(Self.pattern(wheel: 0, tiers: [Self.tier("P1")])) {
      $0 == .invalidWheel(tier: nil, wheel: 0)
    }
    expect(Self.pattern(tiers: [Self.tier("P1", wheel: -1)])) {
      $0 == .invalidWheel(tier: "P1", wheel: -1)
    }
    expect(Self.pattern(girdleTargetFraction: -0.01, tiers: [Self.tier("P1")])) {
      $0 == .invalidGirdleTarget(fraction: -0.01)
    }
  }

  /// The `formatVersion` guard stays inline in `init(from:)`, ahead of the tiers, so a file that is both
  /// a version this kernel cannot read *and* malformed reports the version — the fault that says nothing
  /// else in the file can be trusted to mean what it looks like.
  func testAVersionThisKernelCannotReadIsReportedBeforeAnythingElse() {
    let malformedAtVersionTwo = """
      {
        "formatVersion": 2,
        "name": "Fixture",
        "state": "in progress",
        "wheel": 0,
        "ri": 1.54,
        "designer": "",
        "notes": "",
        "tiers": [
          { "tier": "", "part": "pav", "angle": 43, "indices": [0, 999],
            "meet": { "kind": "size" } }
        ]
      }
      """
    do {
      _ = try decode(Data(malformedAtVersionTwo.utf8))
      XCTFail("decoding succeeded")
    } catch let error as PatternError {
      XCTAssertEqual(error, .unsupportedFormatVersion(2))
    } catch {
      XCTFail("threw \(error)")
    }
  }

  // MARK: - What the app will write

  /// The shape the bench saves mid-authoring: one tier, still in progress, with prose attached. Written
  /// to a real file and read by the real `facetsolve`, because "the kernel can read what it writes" is a
  /// claim about the file on disk and nothing less.
  func testAPatternTheAppCouldBuildIsReadBackByFacetsolve() throws {
    let draft = FacetKernel.Pattern(
      formatVersion: 1,
      name: "Draft",
      state: .inProgress,
      wheel: 96,
      ri: 1.54,
      designer: "",
      notes: "",
      tiers: [
        TierSpec(
          tier: "G",
          part: .gdl,
          angle: 90,
          indices: Self.octagon,
          meet: .size,
          instructions: "Cut the girdle to size, then stop for the night."
        )
      ]
    )

    let file = try write(try encoded(draft), as: "draft")
    let run = try facetsolve([file.path])

    XCTAssertEqual(run.code, 0, run.out + run.err)
    XCTAssertTrue(run.out.contains("Draft"), run.out)
    XCTAssertEqual(try decode(try Data(contentsOf: file)), draft)
  }

  /// The verification handle: prints the re-encoded `Pattern-Easy-Octagon.json`, then hands it to
  /// `facetsolve` to prove the printed text is a pattern and not just something that parses.
  func testDump() throws {
    let original = try AuthoredPatterns.load(AuthoredPatterns.easyOctagon)
    let data = try encoded(original)
    print(String(decoding: data, as: UTF8.self))

    let object = try XCTUnwrap(
      try JSONSerialization.jsonObject(with: data) as? [String: Any]
    )
    XCTAssertEqual(object["girdleTargetFraction"] as? Double, 0.0337)
    let tiers = try XCTUnwrap(object["tiers"] as? [[String: Any]])
    XCTAssertEqual(tiers.count, 6)
    for tier in tiers {
      XCTAssertNotNil((tier["meet"] as? [String: Any])?["kind"], "every meet carries its kind")
      XCTAssertNil(tier["wheel"], "all six tiers inherit 96, so none is written with a wheel")
    }

    let run = try facetsolve([try write(data, as: "easy-octagon-reencoded").path])
    XCTAssertEqual(run.code, 0, run.out + run.err)
    XCTAssertTrue(try XCTUnwrap(run.line(containing: "facets ")).contains("37"), run.out)
    XCTAssertTrue(run.out.contains("no findings"), run.out)
  }

  // MARK: - Fixtures

  private static let octagon = [0, 12, 24, 36, 48, 60, 72, 84]

  private static let vertex = Meet.vertex(facets: [
    FacetRef(tier: "G", index: 0),
    FacetRef(tier: "G", index: 12),
    FacetRef(tier: "P1", index: 0),
  ])

  /// All five forms, an overriding wheel and a tier carrying prose. Solving it is not the point and it
  /// is not solved anywhere — it exists to be written and read back.
  private static let everyForm = FacetKernel.Pattern(
    formatVersion: 1,
    name: "Every Form",
    state: .inProgress,
    wheel: 96,
    ri: 1.54,
    girdleTargetFraction: 0.0337,
    designer: "the encoding test",
    notes: "One tier per meet form.",
    tiers: [
      TierSpec(tier: "G", part: .gdl, angle: 90, indices: octagon, meet: .size),
      TierSpec(tier: "P1", part: .pav, angle: 43, indices: octagon, meet: .tcp),
      TierSpec(tier: "P2", part: .pav, angle: 41, indices: [6, 18, 30, 42], meet: vertex),
      TierSpec(
        tier: "P3",
        part: .pav,
        angle: 39,
        indices: octagon,
        meet: .fraction(from: vertex, percent: 40, to: .tcp),
        instructions: "Cut to the step, then check it against P1."
      ),
      TierSpec(
        tier: "C1", part: .crown, angle: 42, indices: [0, 15, 30, 45], wheel: 120, meet: .girdle),
    ]
  )

  private static func pattern(
    formatVersion: Int = 1,
    wheel: Int = 96,
    girdleTargetFraction: Double? = nil,
    tiers: [TierSpec]
  ) -> FacetKernel.Pattern {
    FacetKernel.Pattern(
      formatVersion: formatVersion,
      name: "Fixture",
      state: .inProgress,
      wheel: wheel,
      ri: 1.54,
      girdleTargetFraction: girdleTargetFraction,
      designer: "",
      notes: "",
      tiers: tiers
    )
  }

  private static func tier(
    _ label: String,
    angle: Double = 43,
    indices: [Int] = [0, 12],
    wheel: Int? = nil,
    meet: Meet = .size
  ) -> TierSpec {
    TierSpec(tier: label, part: .pav, angle: angle, indices: indices, wheel: wheel, meet: meet)
  }

  // MARK: - Helpers

  private func decode(_ data: Data) throws -> FacetKernel.Pattern {
    try JSONDecoder().decode(FacetKernel.Pattern.self, from: data)
  }

  private func json(of pattern: FacetKernel.Pattern) throws -> [String: Any] {
    try XCTUnwrap(try JSONSerialization.jsonObject(with: try encoded(pattern)) as? [String: Any])
  }

  private func expect(
    _ pattern: FacetKernel.Pattern,
    file: StaticString = #filePath,
    line: UInt = #line,
    toFailWith matches: (PatternError) -> Bool
  ) {
    do {
      _ = try encoded(pattern)
      XCTFail("encoding succeeded; expected it to be refused", file: file, line: line)
    } catch let error as PatternError {
      XCTAssertTrue(matches(error), "refused with \(error)", file: file, line: line)
    } catch {
      XCTFail("threw \(error); expected a PatternError", file: file, line: line)
    }
  }

  private func write(_ data: Data, as name: String) throws -> URL {
    let file = FileManager.default.temporaryDirectory
      .appendingPathComponent("\(name)-\(ProcessInfo.processInfo.processIdentifier)")
      .appendingPathExtension("json")
    try data.write(to: file)
    addTeardownBlock { try? FileManager.default.removeItem(at: file) }
    return file
  }

  private struct Run {
    let out: String
    let err: String
    let code: Int32

    func line(containing text: String) -> String? {
      out.split(separator: "\n").map(String.init).first { $0.contains(text) }
    }
  }

  /// The executable sits beside the test bundle, because the test target depends on it.
  private func facetsolve(_ arguments: [String]) throws -> Run {
    let process = Process()
    process.executableURL = Bundle(for: type(of: self)).bundleURL
      .deletingLastPathComponent()
      .appendingPathComponent("facetsolve")
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
}
