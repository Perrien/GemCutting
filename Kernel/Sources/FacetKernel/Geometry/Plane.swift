import Foundation

/// A half-space. The solid is every point `p` satisfying `n · p <= d`.
public struct Plane: Equatable, Sendable {
  /// Outward unit normal.
  public var n: (x: Double, y: Double, z: Double)
  /// Offset along the normal.
  public var d: Double

  public init(n: (x: Double, y: Double, z: Double), d: Double) {
    self.n = n
    self.d = d
  }

  public static func == (lhs: Plane, rhs: Plane) -> Bool {
    lhs.n == rhs.n && lhs.d == rhs.d
  }
}

/// Which part of the stone a tier belongs to. Fixes the sign of a facet normal's `z`.
public enum Part: String, Codable, Sendable {
  case pav
  case gdl
  case crown
  case table
}

/// The outward unit normal of a facet cut at `angleDegrees` on stop `index` of a `wheel`-stop index
/// wheel.
///
/// The wheel convention is the one proven by the render spike: index 0 lies on the +x axis and the
/// index advances counter-clockwise. Crown and table facets tilt toward +z, pavilion and girdle
/// facets toward -z.
public func planeNormal(
  angleDegrees: Double,
  index: Int,
  wheel: Int,
  part: Part
) -> (x: Double, y: Double, z: Double) {
  let theta = 2 * Double.pi * Double(index) / Double(wheel)
  let a = angleDegrees * Double.pi / 180
  let zsign: Double
  switch part {
  case .crown, .table:
    zsign = 1
  case .pav, .gdl:
    zsign = -1
  }
  return (x: sin(a) * cos(theta), y: sin(a) * sin(theta), z: zsign * cos(a))
}
