import Foundation
import XCTest

@testable import FacetKernel

final class MetricsTests: XCTestCase {
  /// Each authored pattern with the girdle fraction its source diagram measures, and the figures its
  /// sheet and its own geometry pin.
  ///
  /// The girdle thickness is the diagram-measured value, which is what makes it an external check rather
  /// than an echo of the input: the solver was asked for a fraction of the width, and the width it
  /// measured has to be the width measured here for the thickness to come back.
  private struct Sheet {
    let file: String
    let girdle: Double
    let facets: Int
    let rotationalOrder: Int
    let width: Double
    let length: Double
    let lengthOverWidth: Double
    let girdleThickness: Double
    let girdlePercent: Double
    let tableFraction: Double
  }

  private static let sheets: [Sheet] = [
    Sheet(
      file: AuthoredPatterns.easyOctagon,
      girdle: 0.033700,
      facets: 37,
      rotationalOrder: 4,
      width: 2.000000,
      length: 2.000000,
      lengthOverWidth: 1.00000,
      girdleThickness: 0.067400,
      girdlePercent: 3.370,
      tableFraction: 0.630939
    ),
    Sheet(
      file: AuthoredPatterns.noviceAsher,
      girdle: 0.032260,
      facets: 49,
      rotationalOrder: 8,
      width: 2.000000,
      length: 2.000000,
      lengthOverWidth: 1.00000,
      girdleThickness: 0.064520,
      girdlePercent: 3.226,
      tableFraction: 0.503152
    ),
    Sheet(
      file: AuthoredPatterns.rands,
      girdle: 0.040493,
      facets: 53,
      rotationalOrder: 2,
      width: 1.464102,
      length: 2.000000,
      lengthOverWidth: 1.36603,
      girdleThickness: 0.059286,
      girdlePercent: 4.049,
      tableFraction: 0.395415
    ),
  ]

  // MARK: - Counts

  /// The sheet's declared count is a claim to agree with, not a number to read: it stays in `notes` as
  /// free text and nothing in the kernel parses it.
  func testFacetCountsMatchTheDeclaredCounts() throws {
    for sheet in Self.sheets {
      let pattern = try AuthoredPatterns.load(sheet.file)
      let measured = metrics(try solve(pattern, girdleTargetFraction: sheet.girdle))

      XCTAssertEqual(measured.facetCount, sheet.facets, pattern.name)
      XCTAssertTrue(
        pattern.notes.contains("\(sheet.facets) facets"),
        "\(pattern.name): the sheet declares \(sheet.facets) facets"
      )
      XCTAssertEqual(
        measured.facetsPerTier.values.reduce(0, +),
        sheet.facets,
        "\(pattern.name): the per-tier counts add up to the whole"
      )
    }
  }

  // MARK: - Symmetry

  /// Easy Octagon's sheet declares plain 4-fold. The solve is stronger than the claim: 4-fold *and* four
  /// mirror axes, at the corner azimuths its C2 facets sit on.
  func testEasyOctagonIsFourFoldWithMirrors() throws {
    let measured = try measure(AuthoredPatterns.easyOctagon, girdle: 0.033700)

    XCTAssertEqual(measured.rotationalOrder, 4)
    XCTAssertEqual(measured.mirrorAxes, [6, 18, 30, 42])
  }

  func testRotationalOrders() throws {
    for sheet in Self.sheets {
      let measured = try measure(sheet.file, girdle: sheet.girdle)
      XCTAssertEqual(measured.rotationalOrder, sheet.rotationalOrder, sheet.file)
    }
  }

  /// A horizontal facet's index stop is only where the lap sat; it carries no azimuth. Easy Octagon's
  /// table is one facet at index 0, so counting it as an azimuth would say the stone has no rotational
  /// symmetry at all.
  func testSymmetryExcludesHorizontalTiers() throws {
    let pattern = try AuthoredPatterns.load(AuthoredPatterns.easyOctagon)
    let solution = try solve(pattern, girdleTargetFraction: 0.033700)

    let withTheTable = rotationalOrder(
      of: survivingFacets(solution),
      wheel: commonWheel(of: solution)
    )
    XCTAssertEqual(withTheTable, 1, "the table alone would break every rotation")
    XCTAssertEqual(metrics(solution).rotationalOrder, 4)
  }

  /// Symmetry describes the stone, not the file. Cutting Easy Octagon's table down to the girdle-top
  /// corner removes both crown tiers, and with C2's four facets gone the stone that remains is 8-fold.
  /// Counting the authored index sets would still report 4 — the symmetry of a shape this stone does not
  /// have.
  func testSymmetryComesFromSurvivingFacetsNotAuthoredIndices() throws {
    var pattern = try AuthoredPatterns.load(AuthoredPatterns.easyOctagon)
    pattern.tiers[5].meet = .vertex(facets: [
      FacetRef(tier: "G1", index: 0),
      FacetRef(tier: "G1", index: 12),
      FacetRef(tier: "C1", index: 0),
    ])
    let solution = try solve(pattern, girdleTargetFraction: 0.033700)
    let measured = metrics(solution)

    XCTAssertEqual(measured.facetsPerTier["C1"], 0)
    XCTAssertEqual(measured.facetsPerTier["C2"], 0)
    XCTAssertEqual(asAuthored(pattern), 4, "the authored index sets still describe a 4-fold stone")
    XCTAssertEqual(measured.rotationalOrder, 8, "the stone the pattern cuts is 8-fold")
  }

  // MARK: - Proportions

  /// The width and length are checked directly rather than through the girdle percentage, because the
  /// percentage would come back whatever axis convention was used. These pin the convention: width is the
  /// smaller of the two axis extents and length the larger, so `L/W` is never below 1. Rand's long axis
  /// lies on 0-48, so its width was already the short one and this rule leaves all three unchanged.
  func testWidthAndLengthAlongTheFixedAxes() throws {
    for sheet in Self.sheets {
      let measured = try measure(sheet.file, girdle: sheet.girdle)

      XCTAssertEqual(measured.widthNormalised, sheet.width, accuracy: 1e-5, sheet.file)
      XCTAssertEqual(measured.lengthNormalised, sheet.length, accuracy: 1e-5, sheet.file)
      XCTAssertEqual(
        measured.lengthOverWidth, sheet.lengthOverWidth, accuracy: 1e-5, sheet.file)
      XCTAssertGreaterThanOrEqual(measured.lengthOverWidth, 1, sheet.file)
    }
  }

  /// The case the fixed-axis rule got backwards, and it needs no pattern: four vertical planes half a unit
  /// out along `x` and a whole unit out along `y`. The outline is 1 wide and 2 long, and the width is on
  /// `x` — which the old rule, always reading width off `y`, reported as 2 wide by 1 long.
  func testTheSmallerAxisExtentIsTheWidth() throws {
    let planes = [
      Plane(n: (x: 1, y: 0, z: 0), d: 0.5),
      Plane(n: (x: -1, y: 0, z: 0), d: 0.5),
      Plane(n: (x: 0, y: 1, z: 0), d: 1.0),
      Plane(n: (x: 0, y: -1, z: 0), d: 1.0),
    ]

    let outline = try XCTUnwrap(girdleOutlineExtent(planes))
    XCTAssertEqual(outline.width, 1.0, accuracy: 1e-12)
    XCTAssertEqual(outline.length, 2.0, accuracy: 1e-12)
    XCTAssertFalse(outline.widthIsAlongY)
  }

  /// Rand's half-width is `sqrt(3) - 1` exactly, forced by its 30 and 60 degree index geometry rather
  /// than chosen, which is why its L/W is `(sqrt(3) + 1) / 2`.
  func testRandsHalfWidthIsRootThreeMinusOne() throws {
    let measured = try measure(AuthoredPatterns.rands, girdle: 0.040493)

    XCTAssertEqual(measured.widthNormalised / 2, 3.0.squareRoot() - 1, accuracy: 1e-5)
    XCTAssertEqual(
      measured.lengthOverWidth, (3.0.squareRoot() + 1) / 2, accuracy: 1e-5)
  }

  func testGirdleThicknessAndFraction() throws {
    for sheet in Self.sheets {
      let measured = try measure(sheet.file, girdle: sheet.girdle)

      XCTAssertEqual(
        measured.girdleThicknessNormalised, sheet.girdleThickness, accuracy: 1e-5, sheet.file)
      XCTAssertEqual(
        measured.girdleFractionOfWidth * 100, sheet.girdlePercent, accuracy: 0.001, sheet.file)
    }
  }

  /// The table's share of the width, for each sheet. Nothing in a pattern says how big a table is — it
  /// falls out of the crown angles through chained vertex meets — so these are the numbers the golden
  /// `--json` fixtures carry, now read from the metric rather than from the CLI that used to derive it.
  func testTheTableFractionOfWidth() throws {
    for sheet in Self.sheets {
      let measured = try measure(sheet.file, girdle: sheet.girdle)

      XCTAssertEqual(
        measured.tableFractionOfWidth, sheet.tableFraction, accuracy: 1e-6, sheet.file)
    }
  }

  /// The girdle band is its own share of the height: crown height is measured from its top and pavilion
  /// depth from its bottom, so the three add up to the total and none of them absorbs half the band.
  func testTheGirdleBandIsItsOwnShareOfTheHeight() throws {
    for sheet in Self.sheets {
      let measured = try measure(sheet.file, girdle: sheet.girdle)
      let parts =
        measured.pavilionDepthFractionOfWidth + measured.crownHeightFractionOfWidth
        + measured.girdleFractionOfWidth

      XCTAssertEqual(parts, measured.totalDepthFractionOfWidth, accuracy: 1e-12, sheet.file)
      XCTAssertTrue(measured.culetIsPoint, "\(sheet.file): all three end in a point culet")
    }
  }

  /// Nothing assumes a flat girdle. A stone cut pavilion straight to crown has no vertical facet to
  /// measure, so its outline is the widest ring the solid has and its band has no thickness.
  func testAKnifeEdgeGirdleStillMeasures() throws {
    let pattern = FacetKernel.Pattern(
      formatVersion: 1,
      name: "knife edge",
      state: .inProgress,
      wheel: 96,
      ri: 1.54,
      designer: "",
      notes: "",
      tiers: [
        TierSpec(
          tier: "P", part: .pav, angle: 45, indices: [0, 12, 24, 36, 48, 60, 72, 84], meet: .size),
        TierSpec(
          tier: "C", part: .crown, angle: 45, indices: [0, 12, 24, 36, 48, 60, 72, 84], meet: .tcp),
      ]
    )
    let measured = metrics(try solve(pattern))

    XCTAssertEqual(measured.girdleThicknessNormalised, 0, accuracy: 1e-12)
    XCTAssertEqual(measured.widthNormalised, measured.lengthNormalised, accuracy: 1e-12)
    XCTAssertEqual(measured.lengthOverWidth, 1, accuracy: 1e-12)
    XCTAssertEqual(
      measured.pavilionDepthFractionOfWidth,
      measured.crownHeightFractionOfWidth,
      accuracy: 1e-12,
      "a stone cut to the same angle both ways is as deep below the girdle as it is high above it"
    )
    XCTAssertEqual(
      measured.tableFractionOfWidth, 0,
      "a stone cut to a point both ways has no table facet, so it has no table"
    )
  }

  // MARK: - Verification handle (T7, permanent)

  /// Prints one row per authored pattern.
  ///
  /// T7's positive check: the Rand's row reads `facets 53  rot 2  L/W 1.36603  girdle 4.05%`. Its
  /// negative check: the Easy Octagon row reads `rot 4`, not `rot 8` — its crown's four 29.00 facets
  /// break 8-fold, so a measure that ignored a tier's index set would read 8 there.
  func testDump() throws {
    for sheet in Self.sheets {
      let pattern = try AuthoredPatterns.load(sheet.file)
      let measured = metrics(try solve(pattern, girdleTargetFraction: sheet.girdle))

      print(
        "\(pattern.name): facets \(measured.facetCount)  rot \(measured.rotationalOrder)  "
          + "L/W \(String(format: "%.5f", measured.lengthOverWidth))  "
          + "girdle \(String(format: "%.2f", measured.girdleFractionOfWidth * 100))%  "
          + "mirrors \(measured.mirrorAxes)  "
          + "W \(String(format: "%.5f", measured.widthNormalised))  "
          + "L \(String(format: "%.5f", measured.lengthNormalised))  "
          + "H/W \(String(format: "%.4f", measured.totalDepthFractionOfWidth))  "
          + "P/W \(String(format: "%.4f", measured.pavilionDepthFractionOfWidth))  "
          + "C/W \(String(format: "%.4f", measured.crownHeightFractionOfWidth))")

      XCTAssertEqual(measured.facetCount, sheet.facets)
    }
  }

  // MARK: - Helpers

  private func measure(_ file: String, girdle: Double) throws -> Metrics {
    metrics(try solve(try AuthoredPatterns.load(file), girdleTargetFraction: girdle))
  }

  /// The rotational order the authored index sets claim, whatever the solid turned out to be. Only a test
  /// computes this: it is the answer D18 rejects, and it is here to show the shipped code does not give
  /// it.
  private func asAuthored(_ pattern: FacetKernel.Pattern) -> Int {
    let authored = pattern.tiers.flatMap { tier in
      tier.indices.map {
        FacetAzimuth(part: tier.part, angle: tier.angle, position: $0)
      }
    }
    return rotationalOrder(
      of: authored.filter { abs($0.angle) > 1e-9 },
      wheel: pattern.wheel
    )
  }
}
