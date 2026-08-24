import Foundation
import simd

/// The framing constants every camera shares. **These are the tuning point at part 2's T4 owner stop**
/// (part 2's D20) — nothing else in the render is adjusted by eye, and moving `distance` in means
/// re-running `BenchCameraTests`' framing check. `azimuthDegrees` and `elevationDegrees` are the
/// *starting* orientation only: where the camera is now lives in a `BenchCameraState` (D1).
public enum BenchCamera {
  public static let azimuthDegrees: Float = 45
  public static let elevationDegrees: Float = 25
  public static let distance: Float = 9
  public static let fieldOfViewDegrees: Float = 30
  /// The centre of the rough, not the centre of a stone: the rough is what has to fit the frame.
  public static let target = SIMD3<Float>(0, 0, -0.5)
  public static let near: Float = 0.1
  public static let far: Float = 100
  public static let orbitDegreesPerPoint: Float = 0.5
}

/// Where the camera is, as a value. `distance` and the field of view are not in here: there is no
/// zoom (D1).
public struct BenchCameraState: Equatable, Sendable {
  public var azimuthDegrees: Float
  public var elevationDegrees: Float

  public init(azimuthDegrees: Float, elevationDegrees: Float) {
    self.azimuthDegrees = azimuthDegrees
    self.elevationDegrees = elevationDegrees
  }

  /// The three-quarter view part 2 shipped, and the app's starting camera.
  public static let threeQuarter = BenchCameraState(
    azimuthDegrees: BenchCamera.azimuthDegrees,
    elevationDegrees: BenchCamera.elevationDegrees)
  /// Straight down at the crown, and straight up at the pavilion. Exactly ±90, at the azimuth that
  /// puts +x at screen right (D3).
  public static let faceUp = BenchCameraState(azimuthDegrees: 270, elevationDegrees: 90)
  public static let faceDown = BenchCameraState(azimuthDegrees: 270, elevationDegrees: -90)

  /// One drag. Azimuth wraps, elevation clamps at the poles (D2, D4).
  public mutating func orbit(dxPoints: Float, dyPoints: Float) {
    azimuthDegrees =
      (azimuthDegrees + dxPoints * BenchCamera.orbitDegreesPerPoint)
      .truncatingRemainder(dividingBy: 360)
    elevationDegrees = min(
      90, max(-90, elevationDegrees + dyPoints * BenchCamera.orbitDegreesPerPoint))
  }
}

/// Where the camera sits, in world space.
public func benchCameraPosition(_ camera: BenchCameraState = .threeQuarter) -> SIMD3<Float> {
  let az = camera.azimuthDegrees * .pi / 180
  let el = camera.elevationDegrees * .pi / 180
  let direction = SIMD3<Float>(cos(el) * cos(az), cos(el) * sin(az), sin(el))
  return BenchCamera.target + BenchCamera.distance * direction
}

/// Right-handed look-at. The stone's axis is +z, and the camera never rolls: screen right stays in the
/// world's xy plane at every elevation (D2).
public func benchViewMatrix(_ camera: BenchCameraState = .threeQuarter) -> simd_float4x4 {
  let eye = benchCameraPosition(camera)
  let zAxis = normalize(eye - BenchCamera.target)

  // The +z up reference is parallel to the view direction at the poles, where
  // `cross(SIMD3<Float>(0, 0, 1), zAxis)` is the zero vector and its normalize is NaN. Normalising it
  // anywhere else divides out the cos(elevation), leaving a value that depends on the azimuth alone —
  // so this is the same axis at every elevation and defined at ±90 as well (D3).
  let az = camera.azimuthDegrees * .pi / 180
  let xAxis = SIMD3<Float>(-sin(az), cos(az), 0)
  let yAxis = cross(zAxis, xAxis)

  return simd_float4x4(
    columns: (
      SIMD4<Float>(xAxis.x, yAxis.x, zAxis.x, 0),
      SIMD4<Float>(xAxis.y, yAxis.y, zAxis.y, 0),
      SIMD4<Float>(xAxis.z, yAxis.z, zAxis.z, 0),
      SIMD4<Float>(-dot(xAxis, eye), -dot(yAxis, eye), -dot(zAxis, eye), 1)
    ))
}

/// Perspective, Metal's NDC: z in [0, 1], y up.
public func benchProjectionMatrix(aspect: Float) -> simd_float4x4 {
  let f = 1 / tan(BenchCamera.fieldOfViewDegrees * .pi / 360)
  let a = BenchCamera.far / (BenchCamera.near - BenchCamera.far)
  let b = BenchCamera.far * BenchCamera.near / (BenchCamera.near - BenchCamera.far)

  return simd_float4x4(
    columns: (
      SIMD4<Float>(f / aspect, 0, 0, 0),
      SIMD4<Float>(0, f, 0, 0),
      SIMD4<Float>(0, 0, a, -1),
      SIMD4<Float>(0, 0, b, 0)
    ))
}

/// The world ray under a point in Metal's NDC, `x` and `y` each in `-1...1` (D13). `direction` is not
/// unit. Inverts `projection * view` and takes the near point and the far point.
public func benchRay(
  ndcX: Float,
  ndcY: Float,
  aspect: Float,
  camera: BenchCameraState = .threeQuarter
) -> (origin: SIMD3<Float>, direction: SIMD3<Float>) {
  let inverse = (benchProjectionMatrix(aspect: aspect) * benchViewMatrix(camera)).inverse
  let near = unproject(inverse, ndcX: ndcX, ndcY: ndcY, ndcZ: 0)
  let far = unproject(inverse, ndcX: ndcX, ndcY: ndcY, ndcZ: 1)
  return (origin: near, direction: far - near)
}

/// Where a world point lands in the viewport, as a fraction of its size with `(0, 0)` **top-left** —
/// SwiftUI's own convention, so the overlay multiplies by its size and nothing else (D16). `nil` when
/// the point is behind the camera (`clip.w <= 0`).
public func benchScreenPoint(
  _ world: SIMD3<Float>,
  aspect: Float,
  camera: BenchCameraState = .threeQuarter
) -> (x: Double, y: Double)? {
  let viewProjection = benchProjectionMatrix(aspect: aspect) * benchViewMatrix(camera)
  let clip = viewProjection * SIMD4<Float>(world, 1)
  guard clip.w > 0 else { return nil }
  let ndc = SIMD2<Float>(clip.x / clip.w, clip.y / clip.w)
  // Metal's NDC y is up and SwiftUI's is down. **The y flip lives here and nowhere else.**
  return (x: Double((ndc.x + 1) / 2), y: Double((1 - ndc.y) / 2))
}

/// One NDC point back through the inverse, divided by its own `w`.
private func unproject(
  _ inverse: simd_float4x4,
  ndcX: Float,
  ndcY: Float,
  ndcZ: Float
) -> SIMD3<Float> {
  let point = inverse * SIMD4<Float>(ndcX, ndcY, ndcZ, 1)
  return SIMD3<Float>(point.x, point.y, point.z) / point.w
}
