import FacetKernel
import Foundation

/// One undirected edge of the drawn solid: its two corners, and the two facets that share it.
public struct SolidEdge: Equatable, Sendable {
  /// Indices into `polytope.vertices`, `a < b`. The key `solidMesh` already dedupes on.
  public var a: Int
  public var b: Int
  /// The plane indices whose polygon rings both corners sit on, ascending. **Two on a closed convex
  /// solid**; an edge found on only one ring is still reported, so a caller can see it rather than
  /// having it silently dropped.
  public var planes: [Int]

  public init(a: Int, b: Int, planes: [Int]) {
    self.a = a
    self.b = b
    self.planes = planes
  }
}

/// Every undirected edge of the drawn solid, in ascending `(a, b)` order.
///
/// Walks each facet's ring in ascending plane-index order and keys each consecutive pair — the closing
/// pair included — as `(min, max)`, so the pair two facets share is emitted once and carries both of
/// their plane indices. **The same enumeration the wireframe draws**, which is what stops a click and a
/// drawn line disagreeing about where an edge is.
public func solidEdges(_ solid: BenchSolid) -> [SolidEdge] {
  var planesByPair: [SIMD2<Int>: [Int]] = [:]

  for planeIndex in solid.polytope.facets.keys.sorted() {
    guard let ring = solid.polytope.facets[planeIndex], ring.count >= 3 else { continue }
    for i in ring.indices {
      let a = ring[i]
      let b = ring[(i + 1) % ring.count]
      let key = SIMD2(min(a, b), max(a, b))
      // Ascending by construction: the facets are walked in ascending plane order, so appending
      // keeps that order without a sort.
      if planesByPair[key]?.contains(planeIndex) != true {
        planesByPair[key, default: []].append(planeIndex)
      }
    }
  }

  return planesByPair.keys
    .sorted { ($0.x, $0.y) < ($1.x, $1.y) }
    .map { SolidEdge(a: $0.x, b: $0.y, planes: planesByPair[$0] ?? []) }
}
