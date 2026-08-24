import FacetKernel
import Foundation
import simd

/// One mesh vertex. **Seven `Float`s, no padding: stride 28, offsets 0, 12 and 24.** The vertex
/// descriptor in the renderer reads those three numbers, and `SolidMeshTests` pins them.
public struct MeshVertex: Equatable, Sendable {
  public var px: Float
  public var py: Float
  public var pz: Float
  public var nx: Float
  public var ny: Float
  public var nz: Float
  /// 0 for a cut facet, 1 for uncut rough. The shader mixes the two colours by it (D21).
  public var role: Float

  public init(
    px: Float,
    py: Float,
    pz: Float,
    nx: Float,
    ny: Float,
    nz: Float,
    role: Float
  ) {
    self.px = px
    self.py = py
    self.pz = pz
    self.nx = nx
    self.ny = ny
    self.nz = nz
    self.role = role
  }
}

public struct SolidMesh: Sendable {
  /// Three per triangle, fan-triangulated from each facet's polygon.
  public var triangleVertices: [MeshVertex]
  /// Two per segment. `nx`/`ny`/`nz` and `role` are zero and unread — the edge shader uses position
  /// only, and one vertex layout serving both pipelines is worth four unused bytes.
  public var edgeVertices: [MeshVertex]

  public init(triangleVertices: [MeshVertex], edgeVertices: [MeshVertex]) {
    self.triangleVertices = triangleVertices
    self.edgeVertices = edgeVertices
  }
}

/// Triangles and edges, in the exact layout the vertex descriptor reads.
///
/// Walks the facets in ascending plane-index order, so the output is deterministic. Every vertex of a
/// facet carries the **plane's own outward normal**, never a normal computed from the triangle, which is
/// what makes each facet one exact flat tone (D17).
public func solidMesh(_ solid: BenchSolid) -> SolidMesh {
  var triangleVertices: [MeshVertex] = []
  var edgeVertices: [MeshVertex] = []
  var seenEdges: Set<SIMD2<Int>> = []

  for planeIndex in solid.polytope.facets.keys.sorted() {
    guard let ring = solid.polytope.facets[planeIndex], ring.count >= 3 else { continue }
    let normal = unitNormal(solid.planes[planeIndex].n)
    let role = isRough(solid.origin[planeIndex]) ? Float(1) : Float(0)

    // The polygon is already wound counter-clockwise about the plane normal, so a fan from `v[0]`
    // needs no ordering work of its own.
    for i in 1..<(ring.count - 1) {
      for vertexIndex in [ring[0], ring[i], ring[i + 1]] {
        triangleVertices.append(
          meshVertex(solid.polytope.vertices[vertexIndex], normal: normal, role: role))
      }
    }

    // Each undirected pair of consecutive ring vertices, closing pair included. Keyed as (min, max) so
    // the pair shared by two facets is emitted once.
    for i in ring.indices {
      let a = ring[i]
      let b = ring[(i + 1) % ring.count]
      let key = SIMD2(min(a, b), max(a, b))
      guard seenEdges.insert(key).inserted else { continue }
      edgeVertices.append(meshVertex(solid.polytope.vertices[a], normal: .zero, role: 0))
      edgeVertices.append(meshVertex(solid.polytope.vertices[b], normal: .zero, role: 0))
    }
  }

  return SolidMesh(triangleVertices: triangleVertices, edgeVertices: edgeVertices)
}

private func meshVertex(
  _ point: (x: Double, y: Double, z: Double),
  normal: SIMD3<Float>,
  role: Float
) -> MeshVertex {
  MeshVertex(
    px: Float(point.x),
    py: Float(point.y),
    pz: Float(point.z),
    nx: normal.x,
    ny: normal.y,
    nz: normal.z,
    role: role)
}

private func unitNormal(_ n: (x: Double, y: Double, z: Double)) -> SIMD3<Float> {
  let length = (n.x * n.x + n.y * n.y + n.z * n.z).squareRoot()
  guard length > 0 else { return .zero }
  return SIMD3<Float>(Float(n.x / length), Float(n.y / length), Float(n.z / length))
}

private func isRough(_ origin: FacetOrigin?) -> Bool {
  guard let origin, case .rough = origin else { return false }
  return true
}
