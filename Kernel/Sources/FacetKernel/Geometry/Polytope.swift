import Foundation

/// A solid built as the intersection of half-spaces: its corners, and the polygon each plane cuts.
public struct Polytope: Sendable {
  /// Every distinct corner of the solid.
  public var vertices: [(x: Double, y: Double, z: Double)]
  /// Plane index to its polygon's vertex indices, wound counter-clockwise about the plane normal.
  ///
  /// A plane touching the solid in fewer than three distinct vertices is not a facet of it and is
  /// absent from this map — the plane was cut away by the others, or only grazes an edge.
  public var facets: [Int: [Int]]

  public init(vertices: [(x: Double, y: Double, z: Double)], facets: [Int: [Int]]) {
    self.vertices = vertices
    self.facets = facets
  }
}

/// The single point where three planes meet, or `nil` when they do not meet at one.
///
/// Solved by Cramer's rule. Returns `nil` when `|det|` falls below `singularBelow`: three planes fix
/// a point only when their normals are independent, and faceting produces the degenerate case
/// readily — three girdle facets are all vertical and pin nothing, at a determinant near `2.5e-17`.
public func triplePoint(
  _ a: Plane,
  _ b: Plane,
  _ c: Plane,
  singularBelow: Double = 1e-10
) -> (x: Double, y: Double, z: Double)? {
  let bc = cross(b.n, c.n)
  let determinant = dot(a.n, bc)
  guard abs(determinant) >= singularBelow else { return nil }

  let ca = cross(c.n, a.n)
  let ab = cross(a.n, b.n)
  return (
    x: (a.d * bc.x + b.d * ca.x + c.d * ab.x) / determinant,
    y: (a.d * bc.y + b.d * ca.y + c.d * ab.y) / determinant,
    z: (a.d * bc.z + b.d * ca.z + c.d * ab.z) / determinant
  )
}

/// Intersects half-spaces into a solid.
///
/// Takes every triple of planes, keeps the points that satisfy `n · p <= d + tolerance` for all
/// planes, deduplicates them, and assigns each to every plane it lies on.
public func intersectHalfSpaces(_ planes: [Plane], tolerance: Double = 1e-7) -> Polytope {
  guard planes.count >= 3 else { return Polytope(vertices: [], facets: [:]) }

  var vertices: [(x: Double, y: Double, z: Double)] = []
  for i in planes.indices {
    for j in planes.indices where j > i {
      for k in planes.indices where k > j {
        guard let point = triplePoint(planes[i], planes[j], planes[k]) else { continue }
        guard satisfiesAll(point, planes, tolerance: tolerance) else { continue }
        guard !vertices.contains(where: { distance($0, point) <= tolerance }) else { continue }
        vertices.append(point)
      }
    }
  }

  var facets: [Int: [Int]] = [:]
  for (index, plane) in planes.enumerated() {
    let onPlane = vertices.indices.filter {
      abs(dot(plane.n, vertices[$0]) - plane.d) <= tolerance
    }
    guard onPlane.count >= 3 else { continue }
    facets[index] = wind(onPlane, about: plane.n, vertices: vertices)
  }

  return Polytope(vertices: vertices, facets: facets)
}

/// Orders a facet's vertices counter-clockwise about its plane normal.
private func wind(
  _ indices: [Int],
  about normal: (x: Double, y: Double, z: Double),
  vertices: [(x: Double, y: Double, z: Double)]
) -> [Int] {
  let centre = centroid(indices.map { vertices[$0] })
  // A right-handed basis in the plane: u x v = normal, so increasing angle from u toward v runs
  // counter-clockwise about the normal and leaves the polygon's signed area positive.
  let u = normalized(cross(normal, leastAlignedAxis(with: normal)))
  let v = normalized(cross(normal, u))
  return indices.sorted { lhs, rhs in
    let a = subtract(vertices[lhs], centre)
    let b = subtract(vertices[rhs], centre)
    return atan2(dot(a, v), dot(a, u)) < atan2(dot(b, v), dot(b, u))
  }
}

private func satisfiesAll(
  _ point: (x: Double, y: Double, z: Double),
  _ planes: [Plane],
  tolerance: Double
) -> Bool {
  for plane in planes where dot(plane.n, point) > plane.d + tolerance {
    return false
  }
  return true
}

private func leastAlignedAxis(
  with n: (x: Double, y: Double, z: Double)
) -> (x: Double, y: Double, z: Double) {
  if abs(n.x) <= abs(n.y), abs(n.x) <= abs(n.z) { return (x: 1, y: 0, z: 0) }
  if abs(n.y) <= abs(n.z) { return (x: 0, y: 1, z: 0) }
  return (x: 0, y: 0, z: 1)
}

private func centroid(
  _ points: [(x: Double, y: Double, z: Double)]
) -> (x: Double, y: Double, z: Double) {
  let count = Double(points.count)
  return points.reduce(into: (x: 0.0, y: 0.0, z: 0.0)) {
    $0.x += $1.x / count
    $0.y += $1.y / count
    $0.z += $1.z / count
  }
}

// MARK: - Vector arithmetic

func dot(
  _ a: (x: Double, y: Double, z: Double),
  _ b: (x: Double, y: Double, z: Double)
) -> Double {
  a.x * b.x + a.y * b.y + a.z * b.z
}

func cross(
  _ a: (x: Double, y: Double, z: Double),
  _ b: (x: Double, y: Double, z: Double)
) -> (x: Double, y: Double, z: Double) {
  (x: a.y * b.z - a.z * b.y, y: a.z * b.x - a.x * b.z, z: a.x * b.y - a.y * b.x)
}

func subtract(
  _ a: (x: Double, y: Double, z: Double),
  _ b: (x: Double, y: Double, z: Double)
) -> (x: Double, y: Double, z: Double) {
  (x: a.x - b.x, y: a.y - b.y, z: a.z - b.z)
}

func magnitude(_ a: (x: Double, y: Double, z: Double)) -> Double {
  dot(a, a).squareRoot()
}

func distance(
  _ a: (x: Double, y: Double, z: Double),
  _ b: (x: Double, y: Double, z: Double)
) -> Double {
  magnitude(subtract(a, b))
}

func normalized(_ a: (x: Double, y: Double, z: Double)) -> (x: Double, y: Double, z: Double) {
  let length = magnitude(a)
  guard length > 0 else { return a }
  return (x: a.x / length, y: a.y / length, z: a.z / length)
}
