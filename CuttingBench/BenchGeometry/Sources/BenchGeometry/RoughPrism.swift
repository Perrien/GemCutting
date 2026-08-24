import FacetKernel
import Foundation

/// The rough stone's dimensions. Build constants with no UI and no preference (D4, D5, D6).
///
/// The radius clears the widest outline the format allows — a design normalised on its short axis puts
/// its ends out at `L/W` — and the depth clears both a deep pavilion and the deepest *intermediate*
/// axial point, which goes further than the final culet.
public enum Rough {
  public static let radius = 1.5
  public static let zTop = 1.0
  public static let zBottom = -2.0
  public static let wallCount = 16
}

/// One named surface of the rough. `wall`'s argument is the 16-stop index the wall's normal sits on,
/// 0 through 15, so `wall(0)` is named `G1` and points along +x (D7).
public enum RoughFacet: Equatable, Hashable, Sendable {
  case crownCap
  case pavilionCap
  case wall(Int)

  public var name: String {
    switch self {
    case .crownCap: "C"
    case .pavilionCap: "P"
    case .wall(let stop): "G\(stop + 1)"
    }
  }
}

/// The rough's eighteen half-spaces, in the fixed order `C`, `P`, `G1`…`G16` (D9). Index into this and
/// into `roughFacets` with the same integer.
///
/// The walls are built as exact vertical planes rather than through `planeNormal(angleDegrees: 90, …)`,
/// whose `z` comes back as -6.1e-17 (D10). A wall a hair off vertical is a wall whose edge-on fade and
/// hit test are a hair wrong.
public func roughPlanes() -> [Plane] {
  var planes = [
    Plane(n: (x: 0, y: 0, z: 1), d: Rough.zTop),
    Plane(n: (x: 0, y: 0, z: -1), d: -Rough.zBottom),
  ]
  for stop in 0..<Rough.wallCount {
    let theta = 2 * Double.pi * Double(stop) / Double(Rough.wallCount)
    planes.append(Plane(n: (x: cos(theta), y: sin(theta), z: 0), d: Rough.radius))
  }
  return planes
}

/// The name of each plane `roughPlanes()` returns, in the same order.
public func roughFacets() -> [RoughFacet] {
  [.crownCap, .pavilionCap] + (0..<Rough.wallCount).map { .wall($0) }
}
