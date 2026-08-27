import Foundation

/// An error in a pattern: as written it cannot be cut, or the stone it cuts is not the one it claims.
public enum Finding: Sendable, Equatable {
  /// A meet names a tier this pattern cuts later. Reversing the two yields a pattern that cannot be
  /// cut, so this is reported and never fixed by reordering.
  case forwardReference(tier: String, named: String)
  /// A meet names a facet of the tier being cut, which cannot fix that tier's own depth.
  case namesOwnFacet(tier: String)
  case unknownFacet(tier: String, named: FacetRef)
  /// The three named planes do not meet at a point — they are parallel, or share an axis.
  case singularTriple(tier: String)
  /// A second `tcp` on one side. The first tier to set a depth there consumed the free datum; on any
  /// later tier the same condition holds at every depth and constrains nothing.
  case secondTCPOnSide(tier: String, part: Part)
  /// `size` is the unit every other depth is expressed in, so exactly one tier carries it.
  case notExactlyOneSizeRow(count: Int)
  /// The named point is not a corner of the stone as it stands when this tier is cut. Either the meet
  /// names the wrong facets, or an earlier tier has already cut the point away.
  case vertexNotOnIntermediateSolid(tier: String, named: [FacetRef])
  /// The half-spaces do not bound a closed solid: some facet has an edge no other facet shares, so
  /// the surface is open. Names the tier owning the first such facet, or `nil` when the solid is too
  /// small to have a surface at all.
  case doesNotClose(tier: String?)
  case facetCountMismatch(solved: Int, declared: Int)
}

/// Something worth the author's attention that is not, by itself, wrong.
///
/// **Named `Notice` rather than `Observation` because a type shadows the module of the same name.** The
/// `Observation` framework is what the `@Observable` macro expands its references against, so a public
/// `Observation` here broke any file that imported this library whole and used that macro — with an
/// error pointing at the macro rather than at the collision. "Observation" is also this project's word
/// for an untriaged ticket, which is a different thing again.
public enum Notice: Sendable, Equatable {
  /// Every facet of this tier is cut away by a later one. Legitimate — a tier cut only to establish an
  /// intermediate point another tier then cuts to — and the declared facet count agrees, because the
  /// sheet never counted them either. It is also exactly what a mis-authored depth looks like, which is
  /// why it is reported rather than passed over.
  case tierContributesNoFacets(tier: String)
  /// These index stops of this tier land on a plane an earlier facet already occupies. Cutting the same
  /// facet twice is not an error, but it is rarely intended.
  case duplicatePlanes(tier: String, indices: [Int])
}

/// What validation found: errors in `findings`, everything informational in `notices`.
public struct Report: Sendable {
  public var findings: [Finding]
  public var notices: [Notice]

  public init(findings: [Finding], notices: [Notice]) {
    self.findings = findings
    self.notices = notices
  }
}

/// Checks a pattern against the solid it solved to. Reports; never throws, never mutates.
///
/// Two channels: `findings` are errors, `notices` are informational and gate nothing. A pattern
/// still being authored may carry findings — only a finished one must come back with none, which is the
/// caller's rule to enforce and not this function's.
///
/// The pattern's own structure is checked first — the facets each meet names, the single `size` row,
/// one `tcp` per side. When any of that is wrong the geometric checks do not run: those are exactly the
/// conditions under which `solve` refuses to place a plane, so no solid can correspond to the pattern
/// as written and reporting one's geometry would be fiction.
public func validate(_ pattern: Pattern, _ solution: Solution, declaredFacetCount: Int?) -> Report {
  let structural = structuralFindings(pattern)
  guard structural.isEmpty else { return Report(findings: structural, notices: []) }

  var findings: [Finding] = []
  for solved in solution.tiers {
    findings.append(contentsOf: namedPointFindings(inTier: solved.tier, of: pattern, solution))
  }
  findings.append(contentsOf: solidFindings(solution, declaredFacetCount: declaredFacetCount))

  return Report(findings: findings, notices: notices(solution))
}

/// The solid as it stands when `tier` is about to be cut: every plane of every earlier tier, and none
/// of that tier's own.
///
/// A named point has to be a corner of *this* solid rather than of the finished one. A point can exist
/// at one tier and be gone by the next — Easy Octagon's P1 axial point forms at 1.0951 half-widths and
/// P2 cuts it away — so checking against the finished polytope would pass patterns by luck and reject
/// correct ones.
public func intermediateSolid(before tier: String, of solution: Solution) -> Polytope {
  var placed: [Plane] = []
  for solved in solution.tiers {
    guard solved.tier != tier else { break }
    placed.append(contentsOf: planes(of: solved))
  }
  return intersectHalfSpaces(placed)
}

/// The half-spaces one solved tier expands to: one plane per index stop, all at the tier's depth.
public func planes(of tier: SolvedTier) -> [Plane] {
  tier.indices.map {
    Plane(
      n: planeNormal(angleDegrees: tier.angle, index: $0, wheel: tier.wheel, part: tier.part),
      d: tier.d
    )
  }
}

// MARK: - The pattern's own structure

/// Everything readable from the pattern alone, in file order. Needs no solid and no solve: whether three
/// planes meet at a point depends on their normals, and a normal comes from an angle and an index stop.
///
/// This is the half an authoring UI can run on every keystroke, before anything has been solved.
public func structuralFindings(_ pattern: Pattern) -> [Finding] {
  var findings: [Finding] = []

  let sizeRows = pattern.tiers.filter { $0.meet.isSize }.count
  if sizeRows != 1 { findings.append(.notExactlyOneSizeRow(count: sizeRows)) }

  let specs = Dictionary(
    pattern.tiers.map { ($0.tier, $0) },
    uniquingKeysWith: { first, _ in first }
  )
  /// Tier label to the index stops it cuts, for the tiers cut so far — the only facets a meet may name.
  var placed: [String: Set<Int>] = [:]
  /// The sides whose surface already crosses the axis, and so have no free datum left.
  var spokenFor: Set<Bool> = []

  for spec in pattern.tiers {
    for triple in spec.meet.namedTriples {
      let problems = triple.compactMap {
        reference(problemWith: $0, in: spec, placed: placed, specs: specs)
      }
      findings.append(contentsOf: problems)
      guard problems.isEmpty, triple.count == 3 else { continue }

      let normals = triple.map { ref -> (x: Double, y: Double, z: Double) in
        let named = specs[ref.tier]!
        return planeNormal(
          angleDegrees: named.angle,
          index: ref.index,
          wheel: pattern.wheel(of: named),
          part: named.part
        )
      }
      if abs(dot(normals[0], cross(normals[1], normals[2]))) < singularBelow {
        findings.append(.singularTriple(tier: spec.tier))
      }
    }

    if spec.meet.isTCP, spokenFor.contains(isCrownSide(spec.part)) {
      findings.append(.secondTCPOnSide(tier: spec.tier, part: spec.part))
    }

    placed[spec.tier] = Set(spec.indices)
    // A 90-degree tier never reaches the axis, so it leaves the free datum alone.
    if abs(cos(spec.angle * Double.pi / 180)) >= 1e-9 { spokenFor.insert(isCrownSide(spec.part)) }
  }

  // Two bad references in one tier can name the same fault twice, and a fault stated twice reads as two
  // faults.
  return findings.reduce(into: []) { unique, finding in
    if !unique.contains(finding) { unique.append(finding) }
  }
}

private func reference(
  problemWith ref: FacetRef,
  in spec: TierSpec,
  placed: [String: Set<Int>],
  specs: [String: TierSpec]
) -> Finding? {
  guard ref.tier != spec.tier else { return .namesOwnFacet(tier: spec.tier) }
  guard let stops = placed[ref.tier] else {
    guard specs[ref.tier] != nil else { return .unknownFacet(tier: spec.tier, named: ref) }
    return .forwardReference(tier: spec.tier, named: ref.tier)
  }
  guard stops.contains(ref.index) else { return .unknownFacet(tier: spec.tier, named: ref) }
  return nil
}

// MARK: - The solid

/// The named-point check for one tier: every triple its meet names has to be a corner of the solid as it
/// stands when that tier is cut.
///
/// **Tier *k*'s result depends only on the tiers before *k*.** `intermediateSolid` walks the solved tiers
/// and breaks at this one, and the planes a triple may name are the planes of the tiers before it, so
/// nothing later in the pattern can change this answer. What follows from that: editing tier *j*
/// invalidates *j* onward and leaves every tier before it untouched, and appending a tier validates
/// exactly one tier. A caller keeping a per-tier cache can rely on that; the cache itself is app state and
/// does not belong here.
///
/// Returns `[]` for a label the pattern does not carry, and for one the solution does not — an unsolved
/// tier has no intermediate solid, and measuring it against the finished one would answer a different
/// question.
public func namedPointFindings(
  inTier tier: String,
  of pattern: Pattern,
  _ solution: Solution
) -> [Finding] {
  guard let spec = pattern.tiers.first(where: { $0.tier == tier }),
    solution.tiers.contains(where: { $0.tier == tier })
  else { return [] }

  let triples = spec.meet.namedTriples
  guard !triples.isEmpty else { return [] }

  let placed = placedPlanes(before: tier, of: solution)
  let solid = intermediateSolid(before: tier, of: solution)

  var findings: [Finding] = []
  for triple in triples {
    let named = triple.compactMap { placed[$0.tier]?[$0.index] }
    guard named.count == 3 else { continue }
    guard let point = triplePoint(named[0], named[1], named[2]) else { continue }
    let isCorner = solid.vertices.contains { distance($0, point) <= onSolidTolerance }
    if !isCorner {
      findings.append(.vertexNotOnIntermediateSolid(tier: tier, named: triple))
    }
  }
  return findings
}

/// Closure and the facet count: whole-solid, cheap, and never cacheable — every tier can move them, so
/// there is nothing to reuse between edits.
public func solidFindings(_ solution: Solution, declaredFacetCount: Int?) -> [Finding] {
  var findings: [Finding] = []

  if let open = closureFinding(solution) { findings.append(open) }

  let solved = solution.polytope.facets.count
  if let declared = declaredFacetCount, solved != declared {
    findings.append(.facetCountMismatch(solved: solved, declared: declared))
  }

  return findings
}

/// Tier label to index stop to plane, for the tiers cut before `tier` — the only facets its meet may
/// name.
private func placedPlanes(before tier: String, of solution: Solution) -> [String: [Int: Plane]] {
  var placed: [String: [Int: Plane]] = [:]
  for solved in solution.tiers {
    guard solved.tier != tier else { break }
    for (stop, plane) in zip(solved.indices, planes(of: solved)) {
      placed[solved.tier, default: [:]][stop] = plane
    }
  }
  return placed
}

/// Whether the facet polygons form a closed surface: every edge belongs to exactly two of them.
///
/// Coincident planes are one facet counted twice, so identical polygons are collapsed first — a
/// duplicated plane is a notice, not an open solid.
private func closureFinding(_ solution: Solution) -> Finding? {
  let polytope = solution.polytope
  guard polytope.vertices.count >= 4, polytope.facets.count >= 4 else {
    return .doesNotClose(tier: nil)
  }

  var distinct: Set<[Int]> = []
  var shared: [Edge: Int] = [:]
  for plane in polytope.facets.keys.sorted() {
    let polygon = polytope.facets[plane]!
    guard distinct.insert(polygon.sorted()).inserted else { continue }
    for edge in edges(of: polygon) { shared[edge, default: 0] += 1 }
  }

  for plane in polytope.facets.keys.sorted() {
    let polygon = polytope.facets[plane]!
    guard edges(of: polygon).contains(where: { shared[$0] != 2 }) else { continue }
    return .doesNotClose(tier: solution.planeOwner[plane]?.tier)
  }
  return nil
}

private struct Edge: Hashable {
  let low: Int
  let high: Int

  init(_ a: Int, _ b: Int) {
    low = Swift.min(a, b)
    high = Swift.max(a, b)
  }
}

private func edges(of polygon: [Int]) -> [Edge] {
  polygon.indices.map { Edge(polygon[$0], polygon[($0 + 1) % polygon.count]) }
}

// MARK: - Notices

private func notices(_ solution: Solution) -> [Notice] {
  var notices: [Notice] = []

  let surviving = Set(solution.polytope.facets.keys.compactMap { solution.planeOwner[$0]?.tier })
  for tier in solution.tiers where !surviving.contains(tier.tier) {
    notices.append(.tierContributesNoFacets(tier: tier.tier))
  }

  var duplicated: [String: [Int]] = [:]
  for later in solution.planes.indices {
    let earlier = solution.planes.indices.first {
      $0 < later && isSamePlane(solution.planes[$0], solution.planes[later])
    }
    guard earlier != nil, let owner = solution.planeOwner[later] else { continue }
    duplicated[owner.tier, default: []].append(owner.index)
  }
  for tier in solution.tiers {
    guard let indices = duplicated[tier.tier] else { continue }
    notices.append(.duplicatePlanes(tier: tier.tier, indices: indices.sorted()))
  }

  return notices
}

private func isSamePlane(_ a: Plane, _ b: Plane) -> Bool {
  distance(a.n, b.n) <= identicalPlaneTolerance && abs(a.d - b.d) <= identicalPlaneTolerance
}

// MARK: - Reading a meet

extension Meet {
  /// Every triple of facets this meet names — its own if it is a vertex, its endpoints' if it is a
  /// fraction.
  public var namedTriples: [[FacetRef]] {
    switch self {
    case .size, .tcp, .girdle: []
    case .vertex(let facets): [facets]
    case .fraction(let from, _, let to): from.namedTriples + to.namedTriples
    }
  }

  var isSize: Bool {
    if case .size = self { true } else { false }
  }

  var isTCP: Bool {
    if case .tcp = self { true } else { false }
  }
}

/// Which end of the stone a tier is cut on. Crown and pavilion each have their own free datum, so the
/// `tcp` rule is per side and not per pattern.
private func isCrownSide(_ part: Part) -> Bool {
  switch part {
  case .crown, .table: true
  case .pav, .gdl: false
  }
}

/// A named point counts as a corner of the solid when it lands this close to one.
private let onSolidTolerance = 1e-7
/// Three planes fix a point only when their normals are independent; below this determinant they do not.
private let singularBelow = 1e-10
/// Two planes are the same facet when both normal and offset agree this closely.
private let identicalPlaneTolerance = 1e-9
