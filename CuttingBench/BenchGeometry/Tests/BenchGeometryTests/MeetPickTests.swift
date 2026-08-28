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

  /// **An edge click is taken from every stage**, and what it now produces is part 5's answer — a point
  /// anchored along the edge — never the pick left where it was. The `.edge` *stage* is still reached, but
  /// by two facet clicks, which `testASecondFacetSharingAnEdgeSelectsThatEdge` covers.
  func testAnEdgeClickAnchorsAPointFromEveryStage() throws {
    let fixture = try noviceAsher()
    let solid = intermediateBenchSolid(before: "P2", draft: fixture.draft, full: fixture.full)
    let edge = try anchorableEdge(solid, ofTier: "P2", draft: fixture.draft)
    let other = try XCTUnwrap(solid.cutFacetIndices.last)

    for stage in [
      MeetPickStage.empty,
      .oneFacet(plane: other),
      .edge(planes: edge.planes, corners: [edge.a, edge.b]),
      .point(planes: edge.planes, candidates: [other], corner: edge.a),
    ] {
      guard
        case .advanced(let next) = advancing(
          pick("P2", stage),
          hit: .edge(planes: edge.planes, corners: [edge.a, edge.b], along: 0.5),
          solid: solid,
          draft: fixture.draft),
        case .anchored(let planes, _, _, let percent) = next.stage
      else { return XCTFail("an edge click from \(stage) did not anchor a point") }

      XCTAssertEqual(planes, edge.planes)
      XCTAssertEqual(percent, 50, accuracy: 1e-9)
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
      hit: .edge(planes: roughEdge.planes, corners: [roughEdge.a, roughEdge.b], along: 0.5),
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
              outcome.completedMeet, tier.meet,
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

    XCTAssertEqual(last.completedMeet, .vertex(facets: reordered))
    XCTAssertNotEqual(last.completedMeet, authored)
  }

  // MARK: - The candidate set, and the third name it fills in

  func testThreeCutAndOneRoughFillTheThirdNameInWithoutAClick() throws {
    let solid = fourPlanesAtOneCorner(roughFrom: 3)
    XCTAssertEqual(candidatePlanes(atCorner: 0, named: [0, 1], solid: solid), [2])

    let outcome = advancing(
      pick("P2", .oneFacet(plane: 0)), hit: .facet(plane: 1), solid: solid, draft: draftOfOneTier())
    XCTAssertEqual(
      outcome.completedMeet,
      .vertex(facets: [
        FacetRef(tier: "G1", index: 0), FacetRef(tier: "G1", index: 1),
        FacetRef(tier: "G1", index: 2),
      ]))
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
      "Picking P2's meet · \(a) · \(b) · click a third facet through the point — "
        + "\(facetLabel(try XCTUnwrap(solid.origin[3]))), "
        + "\(facetLabel(try XCTUnwrap(solid.origin[4]))) or "
        + "\(facetLabel(try XCTUnwrap(solid.origin[5])))")
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

  // MARK: - A point anchored part-way along an edge

  /// **The corpus round-trip.** For every authored fraction: find the edge running from the point its
  /// `from` resolves to down to the side's axial point, click along it at the stored percentage, name the
  /// awaiting end, and get back the same fraction the file stores — **the same percentage, the same `to`,
  /// and a `from` at the same point** (D21). Not the same *spelling*: a corner has more than one legal
  /// triple, the corpus uses the two facets above the edge and the pick uses the edge's own two, and both
  /// resolve to one place.
  func testEveryAuthoredFractionIsReproducedByClickingAlongItsEdge() throws {
    var perPattern: [String: Int] = [:]

    for name in AuthoredPatterns.all {
      let pattern = try AuthoredPatterns.load(name)
      let draft = PatternDraft(pattern)
      let full = benchSolid(for: pattern)

      for spec in pattern.tiers {
        guard case .fraction(let from, let percent, let to) = spec.meet else { continue }
        let solid = intermediateBenchSolid(before: spec.tier, draft: draft, full: full)

        let outer = try XCTUnwrap(
          corner(of: solid, at: try resolved(from, part: spec.part, in: solid)),
          "\(name): \(spec.tier)'s `from` is not a corner of the solid before it")
        let axial = try XCTUnwrap(
          axialPoint(onTheSideOf: spec.part, cutBy: solid.tiers),
          "\(name): \(spec.tier)'s side has no axial point")
        let inner = try XCTUnwrap(
          corner(of: solid, at: axial), "\(name): no corner of the solid is at the axial point")

        let edge = try XCTUnwrap(
          solidEdges(solid).first {
            ($0.a == outer && $0.b == inner) || ($0.a == inner && $0.b == outer)
          },
          "\(name): no edge runs from \(spec.tier)'s outer corner to the axial point")

        // The click, at the percentage the file stores — measured from the outer end, so the parameter
        // depends on which of the edge's own corners that turned out to be.
        let ordered = fractionEndOrder(corners: [edge.a, edge.b], solid: solid)
        XCTAssertEqual(ordered.first, outer, "\(name): \(spec.tier)'s outer end is not `from`")
        let along = ordered[0] == edge.a ? percent / 100 : 1 - percent / 100

        var outcome = advancing(
          MeetPickState(tier: spec.tier),
          hit: .edge(planes: edge.planes, corners: [edge.a, edge.b], along: along),
          solid: solid,
          draft: draft)

        // The corpus's outer corner always offers two candidates, so one further click names it (D13).
        if case .advanced(let next) = outcome {
          guard case .anchored(_, _, let ends, _) = next.stage,
            case .awaiting(_, let candidates) = ends[0]
          else { return XCTFail("\(name): \(spec.tier) anchored with nothing awaiting") }
          XCTAssertEqual(
            ends[1], .named(to), "\(name): \(spec.tier)'s inner end is not the file's `to`")
          outcome = advancing(next, hit: .facet(plane: candidates[0]), solid: solid, draft: draft)
        }

        guard case .complete(.fraction(let wrote, let percentWrote, let toWrote), _) = outcome
        else {
          return XCTFail("\(name): \(spec.tier) did not complete as a fraction — \(outcome)")
        }
        XCTAssertEqual(percentWrote, percent, accuracy: 0.001)
        XCTAssertEqual(toWrote, to)

        // The endpoint itself, which is the property the format cares about.
        let wanted = try resolved(from, part: spec.part, in: solid)
        let got = try resolved(wrote, part: spec.part, in: solid)
        XCTAssertEqual(
          distance(wanted, got), 0, accuracy: 1e-6,
          "\(name): \(spec.tier)'s `from` (\(meetText(wrote))) is not where the file's is")

        perPattern[name, default: 0] += 1
      }
    }

    // Not vacuous, and `Novice Ash-er` carries every fraction in the corpus.
    XCTAssertEqual(perPattern[AuthoredPatterns.noviceAsher], 4)
  }

  // MARK: - Which end starts the measurement

  func testTheEndFurtherFromTheAxisIsFrom() throws {
    let fixture = try noviceAsher()
    let solid = intermediateBenchSolid(before: "P2", draft: fixture.draft, full: fixture.full)
    let edge = try edgeToTheAxialPoint(solid, onTheSideOf: .pav)

    let ordered = fractionEndOrder(corners: [edge.a, edge.b], solid: solid)
    XCTAssertEqual(ordered.count, 2)
    XCTAssertGreaterThan(radius(solid, ordered[0]), radius(solid, ordered[1]))

    // The same two corners the other way round give the same answer: the order is the geometry's, not the
    // argument's.
    XCTAssertEqual(fractionEndOrder(corners: [edge.b, edge.a], solid: solid), ordered)
  }

  func testAtEqualRadiusTheEndNearerTheGirdlePlaneIsFrom() {
    // Same radius, so the tie-break decides: the smaller `abs(z)` is `from`.
    let solid = twoCorners((x: 1, y: 0, z: -0.5), (x: 0, y: 1, z: 0.2))
    XCTAssertEqual(fractionEndOrder(corners: [0, 1], solid: solid), [1, 0])
    XCTAssertEqual(fractionEndOrder(corners: [1, 0], solid: solid), [1, 0])
  }

  // MARK: - The end zones

  func testAClickInAnEndZoneIsAPlainVertexAndNeverAFractionAtZeroOrAHundred() {
    // An edge with exactly one candidate at each end, so an end-zone click completes rather than waiting
    // for a third facet — which is `resolving`'s own rule, reached unchanged (D6).
    let solid = edgeWithOneCandidateAtEachEnd()
    let draft = draftOfOneTier()

    // Both ends of the zone, and its far edge at `0.19`/`0.81` — the whole fifth, not just the tip.
    for (along, third) in [(0.05, 2), (0.19, 2), (0.81, 3), (0.95, 3)] {
      let outcome = advancing(
        MeetPickState(tier: "P2"),
        hit: .edge(planes: [0, 1], corners: [0, 1], along: along),
        solid: solid,
        draft: draft)

      // The plain vertex at that corner, in the edge's own order plus the corner's own third name.
      XCTAssertEqual(
        outcome.completedMeet,
        .vertex(facets: [
          FacetRef(tier: "G1", index: 0), FacetRef(tier: "G1", index: 1),
          FacetRef(tier: "G1", index: third),
        ]),
        "a click at \(along) did not snap to that end's corner")

      // Never a fraction, and so never a percentage of 0 or 100.
      if case .complete(.fraction, _) = outcome { XCTFail("an end-zone click wrote a fraction") }
    }

    // Just outside the zone the point is anchored instead, which is what makes the boundary the zone's.
    // With one candidate at each end both are filled in without a click, so this is the case where the
    // anchoring click is also the completing one (D13).
    guard
      case .complete(.fraction(let from, let percent, let to), _) = advancing(
        MeetPickState(tier: "P2"),
        hit: .edge(planes: [0, 1], corners: [0, 1], along: 0.21),
        solid: solid,
        draft: draft)
    else { return XCTFail("a click at 0.21 did not anchor a point") }
    XCTAssertEqual(percent, 21, accuracy: 1e-9)
    XCTAssertEqual(
      from,
      .vertex(facets: [
        FacetRef(tier: "G1", index: 0), FacetRef(tier: "G1", index: 1),
        FacetRef(tier: "G1", index: 2),
      ]))
    XCTAssertEqual(
      to,
      .vertex(facets: [
        FacetRef(tier: "G1", index: 0), FacetRef(tier: "G1", index: 1),
        FacetRef(tier: "G1", index: 3),
      ]))
  }

  // MARK: - The inner end at the axial point

  /// **The one-`tcp`-per-side rule governs a top-level datum claim, not a fraction endpoint** (D10). The
  /// sharpest statement of it: on `Novice Ash-er`'s own draft, whose `P1` is already `tcp`, the very same
  /// corner is spelled `tcp` as a fraction's inner end and refused as a whole meet.
  func testTheInnerEndAtTheAxialPointIsTCPEvenWhenTheSidesDatumIsTaken() throws {
    let fixture = try noviceAsher()
    let solid = intermediateBenchSolid(before: "P2", draft: fixture.draft, full: fixture.full)
    let edge = try edgeToTheAxialPoint(solid, onTheSideOf: .pav)
    let ordered = fractionEndOrder(corners: [edge.a, edge.b], solid: solid)
    let culet = ordered[1]

    // The draft already carries `P1: tcp`, so the datum is spoken for.
    XCTAssertEqual(fixture.draft.tiers.first { $0.tier == "P1" }?.meet, .tcp)

    XCTAssertEqual(
      fractionEnd(
        atCorner: culet, named: edge.planes, ofTier: "P2", solid: solid, draft: fixture.draft),
      .success(.named(.tcp)))

    // The same corner as a whole meet is the `vertex` triple, because there the rule *is* asked.
    let third = try XCTUnwrap(
      candidatePlanes(atCorner: culet, named: edge.planes, solid: solid).first)
    let asAWholeMeet = meetPicked(
      planes: edge.planes + [third],
      atCorner: culet,
      ofTier: "P2",
      solid: solid,
      draft: fixture.draft)
    guard case .success(.vertex) = asAWholeMeet else {
      return XCTFail("the same corner as a whole meet gave \(asAWholeMeet)")
    }
  }

  // MARK: - How many candidates an end has

  func testAnEndWithOneCandidateIsFilledInWithoutAClick() {
    let solid = fourPlanesAtOneCorner(roughFrom: 3)
    XCTAssertEqual(
      fractionEnd(
        atCorner: 0, named: [0, 1], ofTier: "P2", solid: solid, draft: draftOfOneTier()),
      .success(
        .named(
          .vertex(facets: [
            FacetRef(tier: "G1", index: 0), FacetRef(tier: "G1", index: 1),
            FacetRef(tier: "G1", index: 2),
          ]))))
  }

  func testAnEndOnlyTheRoughCanNameIsRefusedAndLeavesTheStateUntouched() {
    let solid = fourPlanesAtOneCorner(roughFrom: 2)
    XCTAssertEqual(
      fractionEnd(
        atCorner: 0, named: [0, 1], ofTier: "P2", solid: solid, draft: draftOfOneTier()),
      .failure(.roughDerivedPoint(tier: "P2")))

    // And the whole click is refused, with the pick left exactly as it was — `refused` carries no state.
    XCTAssertEqual(
      advancing(
        pick("P2", .empty),
        hit: .edge(planes: [0, 1], corners: [0, 1], along: 0.5),
        solid: solid,
        draft: draftOfOneTier()),
      .refused(.roughDerivedPoint(tier: "P2")))
  }

  func testAnEndWithSeveralCandidatesWaitsWhileTheOtherIsAlreadyNamed() throws {
    let fixture = try noviceAsher()
    let solid = intermediateBenchSolid(before: "P2", draft: fixture.draft, full: fixture.full)
    let edge = try edgeToTheAxialPoint(solid, onTheSideOf: .pav)

    guard
      case .advanced(let next) = advancing(
        MeetPickState(tier: "P2"),
        hit: .edge(planes: edge.planes, corners: [edge.a, edge.b], along: 0.4),
        solid: solid,
        draft: fixture.draft),
      case .anchored(_, _, let ends, _) = next.stage
    else { return XCTFail("the click did not anchor") }

    guard case .awaiting(_, let candidates) = ends[0] else {
      return XCTFail("the outer end is not awaiting: \(ends[0])")
    }
    XCTAssertGreaterThan(candidates.count, 1)
    XCTAssertEqual(ends[1], .named(.tcp))
  }

  // MARK: - From the anchored stage

  func testFromAnchoredACandidateCompletesAndAnythingElseDropsTheAnchor() throws {
    let fixture = try noviceAsher()
    let solid = intermediateBenchSolid(before: "P2", draft: fixture.draft, full: fixture.full)
    let edge = try edgeToTheAxialPoint(solid, onTheSideOf: .pav)

    guard
      case .advanced(let anchored) = advancing(
        MeetPickState(tier: "P2"),
        hit: .edge(planes: edge.planes, corners: [edge.a, edge.b], along: 0.4),
        solid: solid,
        draft: fixture.draft),
      case .anchored(_, _, let ends, _) = anchored.stage,
      case .awaiting(_, let candidates) = ends[0]
    else { return XCTFail("the click did not anchor with an awaiting end") }

    // A candidate resolves that end, and with the other already named the pick completes.
    guard
      case .complete(.fraction(let from, let percent, let to), _) = advancing(
        anchored, hit: .facet(plane: candidates[0]), solid: solid, draft: fixture.draft)
    else { return XCTFail("a candidate click did not complete the fraction") }
    XCTAssertEqual(from, .vertex(facets: try refs(edge.planes + [candidates[0]], in: solid)))
    XCTAssertEqual(percent, 40, accuracy: 1e-9)
    XCTAssertEqual(to, .tcp)

    // Anything else drops the anchor and highlights that facet, and a miss ends the pick.
    let elsewhere = try XCTUnwrap(
      solid.cutFacetIndices.first { !candidates.contains($0) && !edge.planes.contains($0) })
    XCTAssertEqual(
      advancing(anchored, hit: .facet(plane: elsewhere), solid: solid, draft: fixture.draft),
      .advanced(pick("P2", .oneFacet(plane: elsewhere))))
    XCTAssertEqual(
      advancing(anchored, hit: nil, solid: solid, draft: fixture.draft), .cleared)
  }

  func testWithBothEndsAwaitingFromIsNamedFirstAndThenTo() {
    let solid = twoAwaitingEnds()
    let draft = draftOfOneTier()

    guard
      case .advanced(let anchored) = advancing(
        MeetPickState(tier: "P2"),
        hit: .edge(planes: [0, 1], corners: [0, 1], along: 0.25),
        solid: solid,
        draft: draft),
      case .anchored(_, let corners, let ends, let percent) = anchored.stage
    else { return XCTFail("the click did not anchor") }

    // Corner 0 is the further from the axis, so it is `from` and the parameter reads straight through.
    XCTAssertEqual(corners, [0, 1])
    XCTAssertEqual(percent, 25, accuracy: 1e-9)
    guard case .awaiting(let firstCorner, let firstCandidates) = ends[0],
      case .awaiting = ends[1]
    else { return XCTFail("both ends should be awaiting: \(ends)") }
    XCTAssertEqual(firstCorner, 0)

    // The first click names `from` only — `to` is still awaiting, and the pick has not completed.
    guard
      case .advanced(let half) = advancing(
        anchored, hit: .facet(plane: firstCandidates[0]), solid: solid, draft: draft),
      case .anchored(_, _, let halfEnds, _) = half.stage
    else { return XCTFail("the first candidate click did not advance") }
    guard case .named = halfEnds[0], case .awaiting(_, let secondCandidates) = halfEnds[1] else {
      return XCTFail("after the first click the ends read \(halfEnds)")
    }

    // The second names `to`, and that completes it.
    guard
      case .complete(.fraction(let from, let wrote, let to), _) = advancing(
        half, hit: .facet(plane: secondCandidates[0]), solid: solid, draft: draft)
    else { return XCTFail("the second candidate click did not complete the fraction") }
    XCTAssertEqual(wrote, 25, accuracy: 1e-9)
    // Both ends are the edge's two planes plus their own third, so they share two names and differ in one.
    guard case .vertex(let fromRefs) = from, case .vertex(let toRefs) = to else {
      return XCTFail("an end is not a vertex triple")
    }
    XCTAssertEqual(fromRefs.prefix(2), toRefs.prefix(2))
    XCTAssertNotEqual(fromRefs[2], toRefs[2])
  }

  func testAFractionWithAnEndStillAwaitingIsRefused() {
    XCTAssertEqual(
      meetFractionPicked(
        ends: [.named(.tcp), .awaiting(corner: 3, candidates: [1, 2])],
        percent: 50,
        ofTier: "P2"),
      .failure(.pickedFacetsDoNotMeet(tier: "P2")))
    XCTAssertEqual(
      meetFractionPicked(ends: [.named(.tcp)], percent: 50, ofTier: "P2"),
      .failure(.pickedFacetsDoNotMeet(tier: "P2")))
  }

  // MARK: - The anchored stage's own prompt and markers

  func testThePromptForAnAnchoredPointNamesTheEndItIsAskingAbout() {
    let solid = twoAwaitingEnds()
    let a = facetLabel(.cut(FacetRef(tier: "G1", index: 0)))
    let b = facetLabel(.cut(FacetRef(tier: "G1", index: 1)))
    let fromEnd =
      "\(facetLabel(.cut(FacetRef(tier: "G1", index: 2)))) or "
      + facetLabel(.cut(FacetRef(tier: "G1", index: 3)))
    let toEnd =
      "\(facetLabel(.cut(FacetRef(tier: "G1", index: 4)))) or "
      + facetLabel(.cut(FacetRef(tier: "G1", index: 5)))

    // `from` first: two candidates through the outer corner, named.
    XCTAssertEqual(
      meetPickPrompt(
        pick(
          "P2",
          .anchored(
            planes: [0, 1],
            corners: [0, 1],
            ends: [
              .awaiting(corner: 0, candidates: [2, 3]), .awaiting(corner: 1, candidates: [4, 5]),
            ],
            percent: 24.862)),
        solid: solid),
      "Picking P2's meet · 24.86% along \(a) – \(b) · click a facet through the from end — \(fromEnd)"
    )

    // Then `to`, once `from` is named — and the facets named are that end's own.
    XCTAssertEqual(
      meetPickPrompt(
        pick(
          "P2",
          .anchored(
            planes: [0, 1],
            corners: [0, 1],
            ends: [.named(.tcp), .awaiting(corner: 1, candidates: [4, 5])],
            percent: 50)),
        solid: solid),
      "Picking P2's meet · 50.00% along \(a) – \(b) · click a facet through the to end — \(toEnd)")

    // Both named is unreachable — the pick has completed — and says so rather than indexing into nothing.
    XCTAssertEqual(
      meetPickPrompt(
        pick(
          "P2",
          .anchored(
            planes: [0, 1], corners: [0, 1], ends: [.named(.tcp), .named(.tcp)], percent: 50)),
        solid: solid),
      "Picking P2's meet · 50.00% along \(a) – \(b) · complete")
  }

  func testTheAnchoredMarkersAreTheEdgeItsEndsThePointAndOneEndsCandidates() throws {
    let solid = twoAwaitingEnds()
    let markers = meetPickMarkers(
      pick(
        "P2",
        .anchored(
          planes: [0, 1],
          corners: [0, 1],
          ends: [
            .awaiting(corner: 0, candidates: [2, 3]), .awaiting(corner: 1, candidates: [4, 5]),
          ],
          percent: 25)),
      solid: solid)

    // Two named facets, two rings, the point, and **only the awaiting end being asked about** (D12).
    XCTAssertEqual(
      markers.map(\.kind),
      [.named(1), .named(2), .corner, .corner, .anchor(25), .candidate, .candidate])
    let anchor = try XCTUnwrap(markers.first { $0.kind == .anchor(25) })
    XCTAssertEqual(anchor.label, "25.00%")

    // The point sits at the percentage's own position between `from` and `to`, which is the arithmetic the
    // solver performs on the finished meet.
    let from = SIMD3<Float>(1, 0, 0.3)
    let to = SIMD3<Float>(0.2, 0, 0.1)
    XCTAssertEqual(simd_distance(anchor.world, from + 0.25 * (to - from)), 0, accuracy: 1e-6)

    // Identities are stable across two calls, so a `ForEach` keeps them.
    XCTAssertEqual(
      markers.map(\.id),
      ["named-0", "named-1", "corner-0", "corner-1", "anchor", "candidate-2", "candidate-3"])

    // With `from` named, only `to`'s candidates are marked — never both ends at once.
    let half = meetPickMarkers(
      pick(
        "P2",
        .anchored(
          planes: [0, 1],
          corners: [0, 1],
          ends: [.named(.tcp), .awaiting(corner: 1, candidates: [4, 5])],
          percent: 25)),
      solid: solid)
    XCTAssertEqual(half.filter { $0.kind == .candidate }.map(\.id), ["candidate-4", "candidate-5"])
  }

  /// Every marker of a real anchored pick sits on the solid it is drawn over — the point included, which is
  /// on the edge and so on the surface.
  func testEveryAnchoredMarkerSitsOnTheSolid() throws {
    let fixture = try noviceAsher()
    let solid = intermediateBenchSolid(before: "P2", draft: fixture.draft, full: fixture.full)
    let edge = try edgeToTheAxialPoint(solid, onTheSideOf: .pav)

    guard
      case .advanced(let anchored) = advancing(
        MeetPickState(tier: "P2"),
        hit: .edge(planes: edge.planes, corners: [edge.a, edge.b], along: 0.24862),
        solid: solid,
        draft: fixture.draft)
    else { return XCTFail("the click did not anchor") }

    let markers = meetPickMarkers(anchored, solid: solid)
    XCTAssertTrue(
      markers.contains {
        if case .anchor = $0.kind { return true }
        return false
      })
    for marker in markers {
      for plane in solid.planes {
        let signed =
          plane.n.x * Double(marker.world.x) + plane.n.y * Double(marker.world.y)
          + plane.n.z * Double(marker.world.z) - plane.d
        XCTAssertLessThanOrEqual(signed, 1e-6, "\(marker.id) is outside the solid")
      }
    }
  }

  // MARK: - Where the completed pick landed

  func testACornerCompletionReportsTheCornerItself() throws {
    let fixture = try easyOctagon()
    let solid = intermediateBenchSolid(before: "P2", draft: fixture.draft, full: fixture.full)
    guard case .vertex(let facets)? = fixture.draft.tiers.first(where: { $0.tier == "P2" })?.meet
    else { return XCTFail("P2's meet is not a vertex") }
    let planes = try facets.map { try plane(of: $0, in: solid) }

    // Two facets of the meet share an edge; the third click completes at whichever of its two corners
    // that third facet passes through.
    guard
      case .advanced(let one) = advancing(
        MeetPickState(tier: "P2"), hit: .facet(plane: planes[0]), solid: solid,
        draft: fixture.draft),
      case .advanced(let two) = advancing(
        one, hit: .facet(plane: planes[1]), solid: solid, draft: fixture.draft),
      case .edge(_, let corners) = two.stage
    else { return XCTFail("two clicks did not reach an edge") }
    let through = corners.filter { solid.polytope.facets[planes[2]]?.contains($0) ?? false }
    guard through.count == 1 else {
      return XCTFail("the third facet passes through \(through.count) of the edge's ends")
    }

    guard
      case .complete(_, let landed) = advancing(
        two, hit: .facet(plane: planes[2]), solid: solid, draft: fixture.draft)
    else { return XCTFail("the third click did not complete") }

    let vertex = solid.polytope.vertices[through[0]]
    XCTAssertEqual(landed.x, vertex.x)
    XCTAssertEqual(landed.y, vertex.y)
    XCTAssertEqual(landed.z, vertex.z)
  }

  func testAnAnchoredCompletionReportsThePointAtItsPercentage() throws {
    let fixture = try noviceAsher()
    let solid = intermediateBenchSolid(before: "P2", draft: fixture.draft, full: fixture.full)
    let edge = try edgeToTheAxialPoint(solid, onTheSideOf: .pav)

    guard
      case .advanced(let anchored) = advancing(
        MeetPickState(tier: "P2"),
        hit: .edge(planes: edge.planes, corners: [edge.a, edge.b], along: 0.4),
        solid: solid,
        draft: fixture.draft),
      case .anchored(_, let corners, let ends, let percent) = anchored.stage,
      case .awaiting(_, let candidates) = ends[0]
    else { return XCTFail("the click did not anchor with an awaiting end") }

    guard
      case .complete(_, let landed) = advancing(
        anchored, hit: .facet(plane: candidates[0]), solid: solid, draft: fixture.draft)
    else { return XCTFail("a candidate click did not complete the fraction") }

    // `corners` is stored `from` then `to`, so the percentage runs from the first of the two.
    let from = solid.polytope.vertices[corners[0]]
    let to = solid.polytope.vertices[corners[1]]
    let t = percent / 100
    XCTAssertEqual(landed.x, from.x + t * (to.x - from.x), accuracy: 1e-12)
    XCTAssertEqual(landed.y, from.y + t * (to.y - from.y), accuracy: 1e-12)
    XCTAssertEqual(landed.z, from.z + t * (to.z - from.z), accuracy: 1e-12)
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

  private func noviceAsher() throws -> (draft: PatternDraft, full: BenchSolid) {
    let pattern = try AuthoredPatterns.load(AuthoredPatterns.noviceAsher)
    return (PatternDraft(pattern), benchSolid(for: pattern))
  }

  /// The edge running from a corner down to the side's axial point — **the shape every fraction in the
  /// corpus is anchored along**, and the only edge whose inner end is spelled `tcp`.
  private func edgeToTheAxialPoint(
    _ solid: BenchSolid, onTheSideOf part: Part
  ) throws -> SolidEdge {
    let axial = try XCTUnwrap(
      axialPoint(onTheSideOf: part, cutBy: solid.tiers), "this side has no axial point")
    let tip = try XCTUnwrap(
      corner(of: solid, at: axial), "no corner of this solid sits at the axial point")
    let cut = Set(solid.cutFacetIndices)
    return try XCTUnwrap(
      solidEdges(solid).first {
        ($0.a == tip || $0.b == tip) && $0.planes.allSatisfy(cut.contains)
      },
      "no cut-cut edge of this solid reaches the axial point")
  }

  /// An edge both of whose facets are cut and both of whose ends can be spelled, so a click along it
  /// anchors rather than refusing. Found by measurement rather than named, so no case makes a claim about
  /// which edge of a pattern that happens to be.
  private func anchorableEdge(
    _ solid: BenchSolid, ofTier tier: String, draft: PatternDraft
  ) throws -> SolidEdge {
    let cut = Set(solid.cutFacetIndices)
    return try XCTUnwrap(
      solidEdges(solid).first { edge in
        guard edge.planes.allSatisfy(cut.contains) else { return false }
        return [edge.a, edge.b].allSatisfy { corner in
          if case .success = fractionEnd(
            atCorner: corner, named: edge.planes, ofTier: tier, solid: solid, draft: draft)
          {
            return true
          }
          return false
        }
      },
      "no edge of this solid has two cut facets and two spellable ends")
  }

  /// Where a meet's endpoint sits on this solid: the axial point for a `tcp`, and the three named planes'
  /// own intersection for a triple. The kernel's own solves, never a second copy.
  private func resolved(
    _ endpoint: Meet, part: Part, in solid: BenchSolid
  ) throws -> (x: Double, y: Double, z: Double) {
    switch endpoint {
    case .tcp:
      return try XCTUnwrap(axialPoint(onTheSideOf: part, cutBy: solid.tiers))
    case .vertex(let refs):
      let named = try refs.map { try plane(of: $0, in: solid) }
      return try XCTUnwrap(
        triplePoint(solid.planes[named[0]], solid.planes[named[1]], solid.planes[named[2]]))
    case .size, .girdle, .fraction:
      throw NotAnEndpoint()
    }
  }

  /// The corner of this solid at a point, or `nil` when none is.
  private func corner(
    of solid: BenchSolid, at point: (x: Double, y: Double, z: Double)
  ) -> Int? {
    solid.polytope.vertices.indices.first { distance(solid.polytope.vertices[$0], point) <= 1e-6 }
  }

  private func distance(
    _ a: (x: Double, y: Double, z: Double), _ b: (x: Double, y: Double, z: Double)
  ) -> Double {
    ((a.x - b.x) * (a.x - b.x) + (a.y - b.y) * (a.y - b.y) + (a.z - b.z) * (a.z - b.z)).squareRoot()
  }

  private func radius(_ solid: BenchSolid, _ corner: Int) -> Double {
    let point = solid.polytope.vertices[corner]
    return (point.x * point.x + point.y * point.y).squareRoot()
  }

  private func refs(_ planes: [Int], in solid: BenchSolid) throws -> [FacetRef] {
    try planes.map { plane in
      guard case .cut(let ref) = solid.origin[plane] else { throw NotAnEndpoint() }
      return ref
    }
  }

  /// Two corners and nothing else, for the ordering rules that are about position alone.
  private func twoCorners(
    _ first: (x: Double, y: Double, z: Double), _ second: (x: Double, y: Double, z: Double)
  ) -> BenchSolid {
    BenchSolid(
      planes: [],
      origin: [:],
      polytope: Polytope(vertices: [first, second], facets: [:]),
      includesRough: false)
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

  /// One edge with **exactly one** candidate at each end, so an end-zone click completes rather than
  /// waiting. Planes 0 and 1 share the edge; plane 2 passes through its outer corner only and plane 3
  /// through its inner corner only, and each triple's own intersection is that corner — which is what
  /// `meetPicked` checks before writing anything.
  private func edgeWithOneCandidateAtEachEnd() -> BenchSolid {
    let outer = (x: 1.0, y: 0.0, z: 0.3)
    let inner = (x: 0.2, y: 0.0, z: 0.1)
    // Two planes containing the whole segment: both normals are perpendicular to `inner - outer`.
    let length = (0.8 * 0.8 + 0.2 * 0.2).squareRoot()
    let planes = [
      Plane(n: (x: 0, y: 1, z: 0), d: 0),
      Plane(n: (x: 0.2 / length, y: 0, z: -0.8 / length), d: (0.2 * 1 - 0.8 * 0.3) / length),
      // One plane through each end, cutting the segment at that end.
      Plane(n: (x: 1, y: 0, z: 0), d: outer.x),
      Plane(n: (x: 1, y: 0, z: 0), d: inner.x),
    ]
    let vertices = [outer, inner, (x: 0.0, y: 4.0, z: 0.0), (x: 0.0, y: 5.0, z: 0.0)]
    let facets: [Int: [Int]] = [0: [0, 1, 2], 1: [0, 1, 3], 2: [0, 2, 3], 3: [1, 2, 3]]
    var origin: [Int: FacetOrigin] = [:]
    for index in 0..<4 { origin[index] = .cut(FacetRef(tier: "G1", index: index)) }

    return BenchSolid(
      planes: planes,
      origin: origin,
      polytope: Polytope(vertices: vertices, facets: facets),
      includesRough: false)
  }

  /// An edge whose **both** ends have several candidates: planes 0 and 1 share it, planes 2 and 3 pass
  /// through its outer corner and 4 and 5 through its inner one. Corner 0 is the further from the axis, so
  /// it is `from`. Every plane is cut, and the solid has no tiers, so no end is the axial point.
  private func twoAwaitingEnds() -> BenchSolid {
    let vertices: [(x: Double, y: Double, z: Double)] = [
      (x: 1, y: 0, z: 0.3),  // 0 — the outer corner, radius 1
      (x: 0.2, y: 0, z: 0.1),  // 1 — the inner corner, radius 0.2
      (x: 0, y: 5, z: 0), (x: 0, y: 6, z: 0), (x: 0, y: 7, z: 0),
    ]
    // The edge's own two facets carry both corners; the other four carry one each.
    let facets: [Int: [Int]] = [
      0: [0, 1, 2], 1: [0, 1, 3],
      2: [0, 2, 3], 3: [0, 3, 4],
      4: [1, 2, 3], 5: [1, 3, 4],
    ]
    var origin: [Int: FacetOrigin] = [:]
    for index in 0..<6 { origin[index] = .cut(FacetRef(tier: "G1", index: index)) }

    return BenchSolid(
      planes: (0..<6).map { Plane(n: (x: 1, y: 0, z: 0), d: Double($0)) },
      origin: origin,
      polytope: Polytope(vertices: vertices, facets: facets),
      includesRough: false)
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

/// A meet the format does not allow as a fraction's endpoint, which no fixture in this file produces.
private struct NotAnEndpoint: Error {}

extension MeetPickOutcome {
  /// The meet a completed pick wrote, or `nil` for any other outcome. The point a completion also
  /// carries has its own two cases; every other assertion in this file is about the meet alone.
  fileprivate var completedMeet: Meet? {
    guard case .complete(let meet, _) = self else { return nil }
    return meet
  }
}
