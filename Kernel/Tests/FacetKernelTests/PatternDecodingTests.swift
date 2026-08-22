import FacetKernel
import Foundation
import XCTest

/// The authored patterns, read from `Design/Patterns/` rather than copied into the package — one
/// corpus, so a pattern edit cannot pass here and fail in the app.
enum AuthoredPatterns {
  static let directory: URL =
    URL(fileURLWithPath: #filePath)  // .../Kernel/Tests/FacetKernelTests/PatternDecodingTests.swift
    .deletingLastPathComponent()  // FacetKernelTests
    .deletingLastPathComponent()  // Tests
    .deletingLastPathComponent()  // Kernel
    .deletingLastPathComponent()  // repository root
    .appendingPathComponent("Design")
    .appendingPathComponent("Patterns")

  static let easyOctagon = "Pattern-Easy-Octagon"
  static let noviceAsher = "Pattern-Novice-Ash-er"
  static let rands = "Pattern-Rands-Cut-Corner-Rectangle"
  static let roundBrilliant = "Pattern-Standard-Round-Brilliant"

  static func url(_ name: String) -> URL {
    directory.appendingPathComponent(name).appendingPathExtension("json")
  }

  // `Pattern` is qualified throughout this target: XCTest pulls in ApplicationServices, whose
  // Quickdraw.h declares a `Pattern` struct, and the bare name is ambiguous in a test file.
  static func load(_ name: String) throws -> FacetKernel.Pattern {
    try JSONDecoder().decode(FacetKernel.Pattern.self, from: Data(contentsOf: url(name)))
  }
}

final class PatternDecodingTests: XCTestCase {

  // MARK: - The authored corpus

  func testAuthoredPatternsDecodeWithExpectedTierCounts() throws {
    XCTAssertEqual(try AuthoredPatterns.load(AuthoredPatterns.easyOctagon).tiers.count, 6)
    XCTAssertEqual(try AuthoredPatterns.load(AuthoredPatterns.noviceAsher).tiers.count, 7)
    XCTAssertEqual(try AuthoredPatterns.load(AuthoredPatterns.rands).tiers.count, 12)
    // The round brilliant is the fourth file in the same folder; T10 pins its geometry, but it has
    // to decode here or nothing downstream can read it.
    XCTAssertEqual(try AuthoredPatterns.load(AuthoredPatterns.roundBrilliant).tiers.count, 7)
  }

  func testEasyOctagonHeaderAndP2Meet() throws {
    let pattern = try AuthoredPatterns.load(AuthoredPatterns.easyOctagon)
    XCTAssertEqual(pattern.state, .finished)
    XCTAssertEqual(pattern.wheel, 96)

    let p2 = try XCTUnwrap(pattern.tiers.first { $0.tier == "P2" })
    XCTAssertEqual(
      p2.meet,
      .vertex(facets: [
        FacetRef(tier: "G1", index: 0),
        FacetRef(tier: "G1", index: 12),
        FacetRef(tier: "P1", index: 0),
      ])
    )
  }

  func testNoviceAsherP2IsAFractionToTheAxialPoint() throws {
    let pattern = try AuthoredPatterns.load(AuthoredPatterns.noviceAsher)
    let p2 = try XCTUnwrap(pattern.tiers.first { $0.tier == "P2" })
    guard case .fraction(_, let percent, let to) = p2.meet else {
      return XCTFail("P2 decoded as \(p2.meet.kindName), expected a fraction")
    }
    XCTAssertEqual(percent, 24.862)
    XCTAssertEqual(to, .tcp)
  }

  func testNoPatternRelievesTheDecoderOfInheritingTheWheel() throws {
    // No authored pattern declares a per-tier wheel, so every tier inherits the pattern's.
    for name in [
      AuthoredPatterns.easyOctagon, AuthoredPatterns.noviceAsher,
      AuthoredPatterns.rands, AuthoredPatterns.roundBrilliant,
    ] {
      let pattern = try AuthoredPatterns.load(name)
      for tier in pattern.tiers {
        XCTAssertNil(tier.wheel, "\(name) tier \(tier.tier)")
        XCTAssertEqual(pattern.wheel(of: tier), pattern.wheel)
      }
    }
  }

  // MARK: - Rejections, each naming the offending tier

  func testVertexWithTwoFacetsIsRejected() {
    let json = pattern(tiers: [tier("P1", meet: vertexMeet(facetCount: 2))])
    expect(json, toFailWith: .vertexNeedsThreeFacets(tier: "P1", count: 2))
  }

  func testVertexWithFourFacetsIsRejected() {
    let json = pattern(tiers: [tier("P1", meet: vertexMeet(facetCount: 4))])
    expect(json, toFailWith: .vertexNeedsThreeFacets(tier: "P1", count: 4))
  }

  func testFractionEndingAtAGirdleMeetIsRejected() {
    let meet = fractionMeet(percent: 50, to: #"{ "kind": "girdle" }"#)
    expect(
      pattern(tiers: [tier("P2", meet: meet)]),
      toFailWith: .fractionEndpointNotVertexOrTCP(tier: "P2", endpoint: "to", kind: "girdle")
    )
  }

  func testNegativePercentIsRejected() {
    expect(
      pattern(tiers: [tier("P2", meet: fractionMeet(percent: -1))]),
      toFailWith: .percentOutOfRange(tier: "P2", percent: -1)
    )
  }

  func testPercentAbove100IsRejected() {
    expect(
      pattern(tiers: [tier("P2", meet: fractionMeet(percent: 101))]),
      toFailWith: .percentOutOfRange(tier: "P2", percent: 101)
    )
  }

  func testUnknownMeetKindIsRejected() {
    expect(
      pattern(tiers: [tier("P1", meet: #"{ "kind": "culet" }"#)]),
      toFailWith: .unknownMeetKind(tier: "P1", kind: "culet")
    )
  }

  func testDuplicateTierLabelIsRejected() {
    let json = pattern(tiers: [
      tier("P1", meet: #"{ "kind": "size" }"#),
      tier("P1", meet: #"{ "kind": "tcp" }"#),
    ])
    expect(json, toFailWith: .duplicateTierLabel("P1"))
  }

  func testFormatVersionTwoIsRejected() {
    let json = pattern(formatVersion: 2, tiers: [tier("P1", meet: #"{ "kind": "size" }"#)])
    expect(json, toFailWith: .unsupportedFormatVersion(2))
  }

  func testNonIntegerIndexIsRejected() {
    let json = pattern(tiers: [
      tier("P1", indices: "[0, 12.5]", meet: #"{ "kind": "size" }"#)
    ])
    expect(json, toFailWith: .nonIntegerIndex(tier: "P1", value: 12.5))
  }

  func testIndexOutsideTheWheelIsRejected() {
    let json = pattern(tiers: [
      tier("P1", indices: "[0, 96]", meet: #"{ "kind": "size" }"#)
    ])
    expect(json, toFailWith: .indexOutOfRange(tier: "P1", index: 96, wheel: 96))
  }

  // MARK: - Helpers

  private func expect(
    _ json: String,
    toFailWith expected: PatternError,
    file: StaticString = #filePath,
    line: UInt = #line
  ) {
    do {
      _ = try JSONDecoder().decode(FacetKernel.Pattern.self, from: Data(json.utf8))
      XCTFail("decoding succeeded; expected \(expected)", file: file, line: line)
    } catch let error as PatternError {
      XCTAssertEqual(error, expected, file: file, line: line)
    } catch {
      XCTFail("threw \(error); expected \(expected)", file: file, line: line)
    }
  }

  private func pattern(formatVersion: Int = 1, tiers: [String]) -> String {
    """
    {
      "formatVersion": \(formatVersion),
      "name": "Fixture",
      "state": "in progress",
      "wheel": 96,
      "ri": 1.54,
      "designer": "",
      "notes": "",
      "tiers": [\(tiers.joined(separator: ","))]
    }
    """
  }

  private func tier(
    _ label: String,
    part: String = "pav",
    angle: Double = 43,
    indices: String = "[0, 12]",
    meet: String
  ) -> String {
    """
    {
      "tier": "\(label)",
      "part": "\(part)",
      "angle": \(angle),
      "indices": \(indices),
      "meet": \(meet)
    }
    """
  }

  private func vertexMeet(facetCount: Int) -> String {
    let facets = (0..<facetCount)
      .map { #"{ "tier": "G1", "index": \#($0 * 12) }"# }
      .joined(separator: ",")
    return #"{ "kind": "vertex", "facets": [\#(facets)] }"#
  }

  private func fractionMeet(percent: Double, to: String = #"{ "kind": "tcp" }"#) -> String {
    """
    {
      "kind": "fraction",
      "from": \(vertexMeet(facetCount: 3)),
      "percent": \(percent),
      "to": \(to)
    }
    """
  }
}
