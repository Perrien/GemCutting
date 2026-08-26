import FacetKernel
import Foundation
import XCTest
import simd

@testable import BenchGeometry

/// The click machine: what each click does to a pick, and the refusals it states.
/// `AuthoredPatterns` lives in `BenchSolidTests.swift`.
final class MeetPickTests: XCTestCase {

  // MARK: - The solid a pick is tested against

  func testTheIntermediateSolidBeforeP2CarriesG1AndP1AndNothingElse() throws {
    let fixture = try easyOctagon()
    let solid = intermediateBenchSolid(before: "P2", draft: fixture.draft, full: fixture.full)

    var named: [String: Int] = [:]
    for plane in solid.cutFacetIndices {
      guard case .cut(let ref) = solid.origin[plane] else { continue }
      named[ref.tier, default: 0] += 1
    }
    XCTAssertEqual(named, ["G1": 8, "P1": 8])
    XCTAssertEqual(solid.tiers.map(\.tier), ["G1", "P1"])
  }

  func testTheIntermediateSolidBeforeTheFirstTierIsTheBarePrism() throws {
    let fixture = try easyOctagon()
    let solid = intermediateBenchSolid(before: "G1", draft: fixture.draft, full: fixture.full)

    XCTAssertTrue(solid.cutFacetIndices.isEmpty)
    XCTAssertEqual(solid.roughFacetIndices.count, solid.polytope.facets.count)
    XCTAssertEqual(solid.polytope.vertices.count, benchSolid(for: nil).polytope.vertices.count)
  }

  func testALabelTheDraftDoesNotCarryIsTheBarePrismToo() throws {
    let fixture = try easyOctagon()
    let solid = intermediateBenchSolid(before: "nonesuch", draft: fixture.draft, full: fixture.full)
    XCTAssertTrue(solid.cutFacetIndices.isEmpty)
  }

  // MARK: - A click that missed

  func testAClickThatMissedTheSolidClearsThePick() throws {
    let fixture = try easyOctagon()
    let solid = intermediateBenchSolid(before: "P2", draft: fixture.draft, full: fixture.full)
    let cut = try XCTUnwrap(solid.cutFacetIndices.first)
    let edge = try someCutEdge(solid)

    for stage in [
      MeetPickStage.empty,
      .oneFacet(plane: cut),
      .edge(planes: edge.planes, corners: [edge.a, edge.b]),
      .point(planes: edge.planes, candidates: [cut], corner: edge.a),
    ] {
      XCTAssertEqual(
        advancing(pick("P2", stage), hit: nil, solid: solid, draft: fixture.draft), .cleared)
    }
  }

  // MARK: - The rough

  func testAClickOnARoughFacetIsRefusedByItsOwnName() throws {
    let fixture = try easyOctagon()
    let solid = intermediateBenchSolid(before: "P2", draft: fixture.draft, full: fixture.full)

    for plane in solid.roughFacetIndices {
      guard case .rough(let rough) = solid.origin[plane] else { return XCTFail("not rough") }
      let outcome = advancing(
        pick("P2", .empty), hit: .facet(plane: plane), solid: solid, draft: fixture.draft)
      // Refused carries no state, so the pick is left exactly as it was.
      XCTAssertEqual(outcome, .refused(.roughFacetNotNameable(name: rough.name)))
    }
  }

  func testTheRoughsRefusalNamesTheRoughsOwnFacets() throws {
    let fixture = try easyOctagon()
    // Before the first tier every facet is rough, which is the whole set of names there is to refuse.
    let solid = intermediateBenchSolid(before: "G1", draft: fixture.draft, full: fixture.full)

    var names: Set<String> = []
    for plane in solid.roughFacetIndices {
      guard
        case .refused(.roughFacetNotNameable(let name)) = advancing(
          pick("G1", .empty), hit: .facet(plane: plane), solid: solid, draft: fixture.draft)
      else { return XCTFail("plane \(plane) was not refused") }
      names.insert(name)
    }
    XCTAssertEqual(names, Set(["C", "P"] + (1...16).map { "G\($0)" }))
  }

  func testTheRefusalsSentenceReadsAsWritten() {
    XCTAssertEqual(
      DraftRefusal.roughFacetNotNameable(name: "G3").message,
      "G3 is part of the rough, not the stone. A meet may only name facets the pattern cuts.")
    XCTAssertEqual(
      DraftRefusal.roughDerivedPoint(tier: "P2").message,
      "P2's meet cannot be aimed at that point: naming it would need a facet of the rough, "
        + "which is a build constant with no design meaning.")
    XCTAssertEqual(
      DraftRefusal.pickedFacetsDoNotMeet(tier: "C2").message,
      "C2's three named facets do not meet at a point.")
  }

  // MARK: - The first two clicks

  func testAFacetFromEmptyIsHighlighted() throws {
    let fixture = try easyOctagon()
    let solid = intermediateBenchSolid(before: "P2", draft: fixture.draft, full: fixture.full)
    let cut = try XCTUnwrap(solid.cutFacetIndices.first)

    XCTAssertEqual(
      advancing(pick("P2", .empty), hit: .facet(plane: cut), solid: solid, draft: fixture.draft),
      .advanced(pick("P2", .oneFacet(plane: cut))))
  }

  func testTheSameFacetTwiceClearsIt() throws {
    let fixture = try easyOctagon()
    let solid = intermediateBenchSolid(before: "P2", draft: fixture.draft, full: fixture.full)
    let cut = try XCTUnwrap(solid.cutFacetIndices.first)

    XCTAssertEqual(
      advancing(
        pick("P2", .oneFacet(plane: cut)),
        hit: .facet(plane: cut),
        solid: solid,
        draft: fixture.draft),
      .advanced(pick("P2", .empty)))
  }

  func testASecondFacetSharingAnEdgeSelectsThatEdge() throws {
    let fixture = try easyOctagon()
    let solid = intermediateBenchSolid(before: "P2", draft: fixture.draft, full: fixture.full)
    // The pair comes from `solidEdges` — any edge's own two facets — so the case makes no claim about
    // which facets of a pattern are adjacent.
    let edge = try someCutEdge(solid)

    XCTAssertEqual(
      advancing(
        pick("P2", .oneFacet(plane: edge.planes[0])),
        hit: .facet(plane: edge.planes[1]),
        solid: solid,
        draft: fixture.draft),
      .advanced(pick("P2", .edge(planes: edge.planes, corners: [edge.a, edge.b]))))
  }

  func testASecondFacetSharingNothingDropsTheFirst() throws {
    let fixture = try easyOctagon()
    let solid = intermediateBenchSolid(before: "P2", draft: fixture.draft, full: fixture.full)
    let pair = try XCTUnwrap(strangers(solid), "no two cut facets of this solid are strangers")

    XCTAssertEqual(
      advancing(
        pick("P2", .oneFacet(plane: pair.0)),
        hit: .facet(plane: pair.1),
        solid: solid,
        draft: fixture.draft),
      .advanced(pick("P2", .oneFacet(plane: pair.1))))
  }

  // MARK: - The third click

  func testAThirdFacetThroughNeitherEndDropsTheEdge() throws {
    let fixture = try easyOctagon()
    let solid = intermediateBenchSolid(before: "P2", draft: fixture.draft, full: fixture.full)
    let edge = try someCutEdge(solid)
    let elsewhere = try XCTUnwrap(
      solid.cutFacetIndices.first { plane in
        let ring = solid.polytope.facets[plane] ?? []
        return !ring.contains(edge.a) && !ring.contains(edge.b)
      })

    XCTAssertEqual(
      advancing(
        pick("P2", .edge(planes: edge.planes, corners: [edge.a, edge.b])),
        hit: .facet(plane: elsewhere),
        solid: solid,
        draft: fixture.draft),
      .advanced(pick("P2", .oneFacet(plane: elsewhere))))
  }

  // MARK: - An edge takes the click at every stage

  func testAnEdgeClickSelectsItFromEveryStageAndClearsAnyHighlight() throws {
    let fixture = try easyOctagon()
    let solid = intermediateBenchSolid(before: "P2", draft: fixture.draft, full: fixture.full)
    let edge = try someCutEdge(solid)
    let other = try XCTUnwrap(solid.cutFacetIndices.last)

    for stage in [
      MeetPickStage.empty,
      .oneFacet(plane: other),
      .edge(planes: edge.planes, corners: [edge.a, edge.b]),
      .point(planes: edge.planes, candidates: [other], corner: edge.a),
    ] {
      XCTAssertEqual(
        advancing(
          pick("P2", stage),
          hit: .edge(planes: edge.planes, corners: [edge.a, edge.b]),
          solid: solid,
          draft: fixture.draft),
        .advanced(pick("P2", .edge(planes: edge.planes, corners: [edge.a, edge.b]))))
    }
  }

  func testAnEdgeOnTheRoughIsRefusedRatherThanSelected() throws {
    let fixture = try easyOctagon()
    let solid = intermediateBenchSolid(before: "P2", draft: fixture.draft, full: fixture.full)
    let roughEdge = try XCTUnwrap(
      solidEdges(solid).first { edge in
        edge.planes.contains { plane in
          if case .rough = solid.origin[plane] { return true }
          return false
        }
      })

    switch advancing(
      pick("P2", .empty),
      hit: .edge(planes: roughEdge.planes, corners: [roughEdge.a, roughEdge.b]),
      solid: solid,
      draft: fixture.draft)
    {
    case .refused(.roughFacetNotNameable): break
    case let other: XCTFail("an edge on the rough resolved as \(String(describing: other))")
    }
  }

  // MARK: - The corpus round-trip: every authored `vertex` meet, clicked back

  /// For every authored tier whose meet is a `vertex`: click its three named facets, in the file's own
  /// order, on the solid as it stands before that tier — and get back exactly the meet the file stores.
  func testEveryAuthoredVertexMeetIsReproducedByClickingItsThreeFacets() throws {
    var exercised = 0
    var perPattern: [String: Int] = [:]

    for name in AuthoredPatterns.all {
      let pattern = try AuthoredPatterns.load(name)
      let draft = PatternDraft(pattern)
      let full = benchSolid(for: pattern)

      for tier in pattern.tiers {
        guard case .vertex(let facets) = tier.meet else { continue }
        let solid = intermediateBenchSolid(before: tier.tier, draft: draft, full: full)

        // Each named facet's plane index in *that* solid, which is where the click would land.
        let planes = try facets.map { ref in
          try XCTUnwrap(
            solid.cutFacetIndices.first { plane in
              guard case .cut(let cut) = solid.origin[plane] else { return false }
              return cut.tier == ref.tier && cut.index == ref.index
            },
            "\(name): \(tier.tier) names \(ref.tier)@\(ref.index), which is not a facet before it")
        }

        var state = MeetPickState(tier: tier.tier)
        for (k, plane) in planes.enumerated() {
          let outcome = advancing(
            state, hit: .facet(plane: plane), solid: solid, draft: draft)
          if k < planes.count - 1 {
            guard case .advanced(let next) = outcome else {
              return XCTFail("\(name): \(tier.tier) click \(k + 1) gave \(outcome)")
            }
            state = next
          } else {
            XCTAssertEqual(
              outcome, .complete(tier.meet),
              "\(name): \(tier.tier)'s third click did not write the file's own meet")
            exercised += 1
            perPattern[name, default: 0] += 1
          }
        }
      }
    }

    // Not vacuous: `Easy Octagon` alone contributes `P2`, `C2` and `T`.
    XCTAssertEqual(perPattern[AuthoredPatterns.easyOctagon], 3)
    XCTAssertGreaterThanOrEqual(exercised, 3)
  }

  func testTheTripleIsNeverSortedSoADifferentClickOrderWritesADifferentMeet() throws {
    let fixture = try easyOctagon()
    let solid = intermediateBenchSolid(before: "P2", draft: fixture.draft, full: fixture.full)
    let authored = try XCTUnwrap(fixture.draft.tiers.first { $0.tier == "P2" }?.meet)
    guard case .vertex(let facets) = authored else { return XCTFail("P2's meet is not a vertex") }

    // The same three facets, the middle two swapped.
    let reordered = [facets[1], facets[0], facets[2]]
    let planes = try reordered.map { try plane(of: $0, in: solid) }

    var state = MeetPickState(tier: "P2")
    var last: MeetPickOutcome = .cleared
    for plane in planes {
      last = advancing(state, hit: .facet(plane: plane), solid: solid, draft: fixture.draft)
      if case .advanced(let next) = last { state = next }
    }

    XCTAssertEqual(last, .complete(.vertex(facets: reordered)))
    XCTAssertNotEqual(last, .complete(authored))
  }

  // MARK: - The candidate set, and the third name it fills in

  func testThreeCutAndOneRoughFillTheThirdNameInWithoutAClick() throws {
    let solid = fourPlanesAtOneCorner(roughFrom: 3)
    XCTAssertEqual(candidatePlanes(atCorner: 0, named: [0, 1], solid: solid), [2])

    let outcome = advancing(
      pick("P2", .oneFacet(plane: 0)), hit: .facet(plane: 1), solid: solid, draft: draftOfOneTier())
    XCTAssertEqual(
      outcome,
      .complete(
        .vertex(facets: [
          FacetRef(tier: "G1", index: 0), FacetRef(tier: "G1", index: 1),
          FacetRef(tier: "G1", index: 2),
        ])))
  }

  func testACornerOnlyTheRoughCanNameIsRefused() throws {
    let solid = fourPlanesAtOneCorner(roughFrom: 2)
    XCTAssertEqual(candidatePlanes(atCorner: 0, named: [0, 1], solid: solid), [])

    XCTAssertEqual(
      advancing(
        pick("P2", .oneFacet(plane: 0)), hit: .facet(plane: 1), solid: solid,
        draft: draftOfOneTier()),
      .refused(.roughDerivedPoint(tier: "P2")))
  }

  func testMoreThanOneCandidateWaitsForAThirdClick() throws {
    let solid = fivePlanesAtOneCorner()
    XCTAssertEqual(candidatePlanes(atCorner: 0, named: [0, 1], solid: solid), [2, 3, 4])

    XCTAssertEqual(
      advancing(
        pick("P2", .oneFacet(plane: 0)), hit: .facet(plane: 1), solid: solid,
        draft: draftOfOneTier()),
      .advanced(pick("P2", .point(planes: [0, 1], candidates: [2, 3, 4], corner: 0))))
  }

  func testAClickOffTheCandidatesDropsThePointAndNeverCompletes() throws {
    let solid = fivePlanesAtOneCorner()
    // Plane 5 carries no corner the point does, so it is neither a candidate nor a completion.
    XCTAssertEqual(
      advancing(
        pick("P2", .point(planes: [0, 1], candidates: [2, 3, 4], corner: 0)),
        hit: .facet(plane: 5),
        solid: solid,
        draft: draftOfOneTier()),
      .advanced(pick("P2", .oneFacet(plane: 5))))
  }

  // MARK: - `tcp`, both ways

  func testAPickAtTheFreeAxialPointIsWrittenAsTCP() throws {
    let fixture = try easyOctagon()
    let solid = intermediateBenchSolid(before: "P2", draft: fixture.draft, full: fixture.full)
    let culet = try axialCorner(of: solid, part: .pav)
    let named = try threePavilionFacets(through: culet, in: solid)

    // The solid and the draft are independent arguments, and this is the only way to reach the `tcp`
    // arm: a draft whose pavilion has not reached the axis. In a real draft the two conditions are
    // mutually exclusive — see `testTheAxialPointExistsOnlyOnceThatSidesDatumIsSpokenFor`.
    var freeDatum = PatternDraft.empty
    freeDatum.tiers = [
      DraftTier(tier: "G1", part: .gdl, angle: 90, indices: [0, 12], meet: .size),
      DraftTier(tier: "P2", part: .pav, angle: 43, indices: [6, 18], meet: nil),
    ]

    XCTAssertEqual(
      meetPicked(planes: named, atCorner: culet, ofTier: "P2", solid: solid, draft: freeDatum),
      .success(.tcp))
  }

  /// **Why the `tcp` arm never fires on a real draft.** The kernel reports an axial point on a side only
  /// once some earlier tier there has crossed the axis — and crossing the axis is exactly what claims that
  /// side's free datum, so `secondTCPOnSide` fires for any `tcp` written after it. Both halves are the
  /// kernel's own, and this states the consequence rather than working around it.
  func testTheAxialPointExistsOnlyOnceThatSidesDatumIsSpokenFor() throws {
    let fixture = try easyOctagon()
    let solid = intermediateBenchSolid(before: "P2", draft: fixture.draft, full: fixture.full)

    XCTAssertNotNil(axialPoint(onTheSideOf: .pav, cutBy: solid.tiers))

    var asTCP = fixture.draft
    let k = try XCTUnwrap(asTCP.position(ofTier: "P2"))
    asTCP.tiers[k].meet = .tcp
    let pattern = try XCTUnwrap(asTCP.displayPattern)
    XCTAssertTrue(
      structuralFindings(pattern).contains(.secondTCPOnSide(tier: "P2", part: .pav)))
  }

  func testWhenTheSidesDatumIsTakenTheVertexTripleIsWrittenWithNoRefusal() throws {
    let fixture = try easyOctagon()
    let solid = intermediateBenchSolid(before: "P2", draft: fixture.draft, full: fixture.full)
    let culet = try axialCorner(of: solid, part: .pav)
    let named = try threePavilionFacets(through: culet, in: solid)

    // `Easy Octagon` as authored: `P1` is already `tcp`, so the pavilion's datum is spoken for.
    let written = meetPicked(
      planes: named, atCorner: culet, ofTier: "P2", solid: solid, draft: fixture.draft)
    switch written {
    case .success(.vertex(let facets)):
      XCTAssertEqual(facets.map(\.tier), ["P1", "P1", "P1"])
    case let other:
      XCTFail("expected the vertex triple, got \(other)")
    }
  }

  func testACrownTierAtThePavilionAxialPointIsNeverTCP() throws {
    let fixture = try easyOctagon()
    let solid = intermediateBenchSolid(before: "P2", draft: fixture.draft, full: fixture.full)
    let culet = try axialCorner(of: solid, part: .pav)
    let named = try threePavilionFacets(through: culet, in: solid)

    // Asked for `C1`'s own side, the crown, where nothing has reached the axis at all.
    var freeDatum = PatternDraft.empty
    freeDatum.tiers = [
      DraftTier(tier: "G1", part: .gdl, angle: 90, indices: [0, 12], meet: .size),
      DraftTier(tier: "C1", part: .crown, angle: 42, indices: [0, 12], meet: nil),
    ]

    switch meetPicked(
      planes: named, atCorner: culet, ofTier: "C1", solid: solid, draft: freeDatum)
    {
    case .success(.vertex): break
    case let other: XCTFail("a crown tier wrote \(other) at the pavilion axial point")
    }
  }

  // MARK: - Three planes that pin no point

  func testThreeDependentNormalsRefuseThePick() {
    let solid = threeParallelishPlanes()
    XCTAssertEqual(
      meetPicked(
        planes: [0, 1, 2], atCorner: 0, ofTier: "P2", solid: solid, draft: draftOfOneTier()),
      .failure(.pickedFacetsDoNotMeet(tier: "P2")))
  }

  // MARK: - The prompt

  func testThePromptReadsItsFourSentences() throws {
    let fixture = try easyOctagon()
    let solid = intermediateBenchSolid(before: "P2", draft: fixture.draft, full: fixture.full)
    let edge = try someCutEdge(solid)
    let first = edge.planes[0]
    let second = edge.planes[1]
    let a = facetLabel(try XCTUnwrap(solid.origin[first]))
    let b = facetLabel(try XCTUnwrap(solid.origin[second]))

    XCTAssertEqual(
      meetPickPrompt(pick("P2", .empty), solid: solid),
      "Picking P2's meet · click a facet, or an edge")
    XCTAssertEqual(
      meetPickPrompt(pick("P2", .oneFacet(plane: first)), solid: solid),
      "Picking P2's meet · \(a) · click a second facet")
    XCTAssertEqual(
      meetPickPrompt(
        pick("P2", .edge(planes: [first, second], corners: [edge.a, edge.b])), solid: solid),
      "Picking P2's meet · edge \(a) – \(b) · click a third facet through one of its ends")
    XCTAssertEqual(
      meetPickPrompt(
        pick("P2", .point(planes: [first, second], candidates: [3, 4, 5], corner: edge.a)),
        solid: solid),
      "Picking P2's meet · \(a) · \(b) · click one of 3 facets through the point")
  }

  // MARK: - The markers

  func testTheMarkersCountAndSitOnTheSolid() throws {
    let fixture = try easyOctagon()
    let solid = intermediateBenchSolid(before: "P2", draft: fixture.draft, full: fixture.full)
    let edge = try someCutEdge(solid)
    let elsewhere = try XCTUnwrap(solid.cutFacetIndices.last)

    XCTAssertTrue(meetPickMarkers(pick("P2", .empty), solid: solid).isEmpty)

    let one = meetPickMarkers(pick("P2", .oneFacet(plane: edge.planes[0])), solid: solid)
    XCTAssertEqual(one.map(\.kind), [.named(1)])
    XCTAssertEqual(one.first?.label, facetLabel(try XCTUnwrap(solid.origin[edge.planes[0]])))

    let selected = meetPickMarkers(
      pick("P2", .edge(planes: edge.planes, corners: [edge.a, edge.b])), solid: solid)
    XCTAssertEqual(selected.map(\.kind), [.named(1), .named(2), .corner, .corner])
    XCTAssertEqual(selected.filter { $0.kind == .corner }.map(\.label), ["end", "end"])

    let waiting = meetPickMarkers(
      pick("P2", .point(planes: edge.planes, candidates: [elsewhere], corner: edge.a)),
      solid: solid)
    XCTAssertEqual(waiting.map(\.kind), [.named(1), .named(2), .candidate])

    // Every marker sits on the solid it is drawn over.
    for marker in one + selected + waiting {
      for plane in solid.planes {
        let signed =
          plane.n.x * Double(marker.world.x) + plane.n.y * Double(marker.world.y)
          + plane.n.z * Double(marker.world.z) - plane.d
        XCTAssertLessThanOrEqual(signed, 1e-6, "\(marker.id) is outside the solid")
      }
    }

    // Identities are stable across two calls, so a `ForEach` keeps them.
    XCTAssertEqual(
      selected.map(\.id),
      meetPickMarkers(
        pick("P2", .edge(planes: edge.planes, corners: [edge.a, edge.b])), solid: solid
      )
      .map(\.id))
  }

  // MARK: - Helpers

  private func pick(_ tier: String, _ stage: MeetPickStage) -> MeetPickState {
    var state = MeetPickState(tier: tier)
    state.stage = stage
    return state
  }

  private func easyOctagon() throws -> (draft: PatternDraft, full: BenchSolid) {
    let pattern = try AuthoredPatterns.load(AuthoredPatterns.easyOctagon)
    return (PatternDraft(pattern), benchSolid(for: pattern))
  }

  /// An edge both of whose facets are cut, so selecting it is not a rough refusal.
  private func someCutEdge(_ solid: BenchSolid) throws -> SolidEdge {
    let cut = Set(solid.cutFacetIndices)
    return try XCTUnwrap(
      solidEdges(solid).first { $0.planes.allSatisfy(cut.contains) },
      "no edge of this solid is shared by two cut facets")
  }

  /// Two cut facets whose polygons share no corner at all.
  private func strangers(_ solid: BenchSolid) -> (Int, Int)? {
    let cut = solid.cutFacetIndices
    for first in cut {
      for second in cut where second != first {
        let a = Set(solid.polytope.facets[first] ?? [])
        let b = Set(solid.polytope.facets[second] ?? [])
        if a.isDisjoint(with: b) { return (first, second) }
      }
    }
    return nil
  }

  /// One named facet's plane index in this solid.
  private func plane(of ref: FacetRef, in solid: BenchSolid) throws -> Int {
    try XCTUnwrap(
      solid.cutFacetIndices.first { plane in
        guard case .cut(let cut) = solid.origin[plane] else { return false }
        return cut.tier == ref.tier && cut.index == ref.index
      },
      "\(ref.tier)@\(ref.index) is not a facet of this solid")
  }

  /// The corner of this solid that sits on the axis on `part`'s side — the culet, for a pavilion that has
  /// reached the axis. Taken from the kernel's own `axialPoint`, so the test is not deciding where it is.
  private func axialCorner(of solid: BenchSolid, part: Part) throws -> Int {
    let axial = try XCTUnwrap(axialPoint(onTheSideOf: part, cutBy: solid.tiers))
    return try XCTUnwrap(
      solid.polytope.vertices.indices.first { index in
        let corner = solid.polytope.vertices[index]
        let dx = corner.x - axial.x
        let dy = corner.y - axial.y
        let dz = corner.z - axial.z
        return (dx * dx + dy * dy + dz * dz).squareRoot() <= 1e-9
      },
      "no corner of this solid sits at the axial point")
  }

  /// Three facets of the pavilion's first tier through one corner, in ascending plane order.
  private func threePavilionFacets(through corner: Int, in solid: BenchSolid) throws -> [Int] {
    let through = solid.cutFacetIndices.filter {
      solid.polytope.facets[$0]?.contains(corner) ?? false
    }
    XCTAssertGreaterThanOrEqual(through.count, 3)
    return Array(through.prefix(3))
  }

  /// A one-tier draft, for the synthetic solids: `meetPicked` asks a draft only for the picking tier's
  /// part and for whether its side's datum is free.
  private func draftOfOneTier() -> PatternDraft {
    var draft = PatternDraft.empty
    draft.tiers = [
      DraftTier(tier: "P2", part: .pav, angle: 43, indices: [0], meet: nil)
    ]
    return draft
  }

  /// Four planes meeting at one corner, built through `BenchSolid`'s own initialiser: planes from
  /// `roughFrom` on are the rough's, every earlier one a facet of tier `P2`. Each facet's ring carries
  /// the shared corner and two of its own, so no two of them share an edge.
  private func fourPlanesAtOneCorner(roughFrom: Int) -> BenchSolid {
    syntheticSolid(planeCount: 4, roughFrom: roughFrom)
  }

  /// The same shape with five cut planes through the corner, and a sixth facet nowhere near it.
  private func fivePlanesAtOneCorner() -> BenchSolid {
    syntheticSolid(planeCount: 5, roughFrom: 6, withAStranger: true)
  }

  private func syntheticSolid(
    planeCount: Int, roughFrom: Int, withAStranger: Bool = false
  ) -> BenchSolid {
    let corner = (x: 0.1, y: 0.2, z: 0.3)
    // Every plane passes exactly through the corner, so any three of them solve to it.
    let unitThird = 1.0 / 3.0.squareRoot()
    var normals: [(x: Double, y: Double, z: Double)] = [
      (x: 1, y: 0, z: 0),
      (x: 0, y: 1, z: 0),
      (x: 0, y: 0, z: 1),
      (x: unitThird, y: unitThird, z: unitThird),
      (x: 0.267261241912424, y: 0.534522483824849, z: 0.801783725737273),
    ]
    normals = Array(normals.prefix(planeCount))

    var planes = normals.map { n in
      Plane(n: n, d: n.x * corner.x + n.y * corner.y + n.z * corner.z)
    }
    var vertices = [corner]
    var facets: [Int: [Int]] = [:]
    var origin: [Int: FacetOrigin] = [:]

    for index in planes.indices {
      // Two corners of this facet's own, so its ring is a triangle sharing only corner 0.
      let own = vertices.count
      vertices.append((x: 1 + Double(index), y: 0, z: 0))
      vertices.append((x: 0, y: 1 + Double(index), z: 0))
      facets[index] = [0, own, own + 1]
      origin[index] =
        index >= roughFrom
        ? .rough(.wall(index)) : .cut(FacetRef(tier: "G1", index: index))
    }

    if withAStranger {
      let stranger = planes.count
      let own = vertices.count
      planes.append(Plane(n: (x: 0, y: 0, z: -1), d: 9))
      vertices.append(contentsOf: [
        (x: 5, y: 5, z: -9), (x: 6, y: 5, z: -9), (x: 5, y: 6, z: -9),
      ])
      facets[stranger] = [own, own + 1, own + 2]
      origin[stranger] = .cut(FacetRef(tier: "G1", index: stranger))
    }

    return BenchSolid(
      planes: planes,
      origin: origin,
      polytope: Polytope(vertices: vertices, facets: facets),
      tiers: [],
      includesRough: true)
  }

  /// Three planes whose normals are dependent — they share an axis and pin no point.
  private func threeParallelishPlanes() -> BenchSolid {
    let diagonal = 1.0 / 2.0.squareRoot()
    let normals: [(x: Double, y: Double, z: Double)] = [
      (x: 1, y: 0, z: 0),
      (x: 0, y: 1, z: 0),
      (x: diagonal, y: diagonal, z: 0),
    ]
    let planes = normals.map { Plane(n: $0, d: 1) }
    let facets = [0: [0, 1, 2], 1: [0, 1, 2], 2: [0, 1, 2]]
    var origin: [Int: FacetOrigin] = [:]
    for index in 0..<3 { origin[index] = .cut(FacetRef(tier: "G1", index: index)) }

    return BenchSolid(
      planes: planes,
      origin: origin,
      polytope: Polytope(
        vertices: [(x: 0, y: 0, z: 0), (x: 1, y: 0, z: 0), (x: 0, y: 1, z: 0)], facets: facets),
      includesRough: false)
  }
}
