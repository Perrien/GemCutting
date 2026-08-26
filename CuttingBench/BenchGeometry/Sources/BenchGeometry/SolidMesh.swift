import FacetKernel
import Foundation
import simd

/// One mesh vertex. **Eight `Float`s, no padding: stride 32, offsets 0, 12, 24 and 28.** The vertex
/// descriptor in the renderer reads those four numbers, and `SolidMeshTests` pins them.
public struct MeshVertex: Equatable, Sendable {
  public var px: Float
  public var py: Float
  public var pz: Float
  public var nx: Float
  public var ny: Float
  public var nz: Float
  /// 0 for a cut facet, 1 for uncut rough. The shader mixes the two colours by it (D21).
  public var role: Float
  /// The plane this vertex's facet belongs to, so the shader can highlight one facet (D12). `-1` on an
  /// edge vertex, which is shared by two facets and belongs to neither.
  public var planeIndex: Float

  public init(
    px: Float,
    py: Float,
    pz: Float,
    nx: Float,
    ny: Float,
    nz: Float,
    role: Float,
    planeIndex: Float
  ) {
    self.px = px
    self.py = py
    self.pz = pz
    self.nx = nx
    self.ny = ny
    self.nz = nz
    self.role = role
    self.planeIndex = planeIndex
  }
}

public struct SolidMesh: Sendable {
  /// Three per triangle, fan-triangulated from each facet's polygon.
  public var triangleVertices: [MeshVertex]
  /// Two per segment. `nx`/`ny`/`nz` and `role` are zero, `planeIndex` is `-1`, and none of them is
  /// read — the edge shader uses position only, and one vertex layout serving both pipelines is worth
  /// the unused bytes.
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

  for planeIndex in solid.polytope.facets.keys.sorted() {
    guard let ring = solid.polytope.facets[planeIndex], ring.count >= 3 else { continue }
    let normal = unitNormal(solid.planes[planeIndex].n)
    let role = isRough(solid.origin[planeIndex]) ? Float(1) : Float(0)

    // The polygon is already wound counter-clockwise about the plane normal, so a fan from `v[0]`
    // needs no ordering work of its own.
    for i in 1..<(ring.count - 1) {
      for vertexIndex in [ring[0], ring[i], ring[i + 1]] {
        triangleVertices.append(
          meshVertex(
            solid.polytope.vertices[vertexIndex],
            normal: normal,
            role: role,
            planeIndex: Float(planeIndex)))
      }
    }
  }

  // One enumeration of the solid's edges, shared with the click: a line drawn here and an edge a
  // click can take are the same thing by construction.
  for edge in solidEdges(solid) {
    edgeVertices.append(
      meshVertex(solid.polytope.vertices[edge.a], normal: .zero, role: 0, planeIndex: -1))
    edgeVertices.append(
      meshVertex(solid.polytope.vertices[edge.b], normal: .zero, role: 0, planeIndex: -1))
  }

  return SolidMesh(triangleVertices: triangleVertices, edgeVertices: edgeVertices)
}

private func meshVertex(
  _ point: (x: Double, y: Double, z: Double),
  normal: SIMD3<Float>,
  role: Float,
  planeIndex: Float
) -> MeshVertex {
  MeshVertex(
    px: Float(point.x),
    py: Float(point.y),
    pz: Float(point.z),
    nx: normal.x,
    ny: normal.y,
    nz: normal.z,
    role: role,
    planeIndex: planeIndex)
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
