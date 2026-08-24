import Foundation
import simd

/// The one fixed three-quarter view. **These constants are the tuning point at T4's owner stop** (D20) —
/// nothing else in the render is adjusted by eye, and moving `distance` in means re-running
/// `BenchCameraTests`' framing check.
public enum BenchCamera {
  public static let azimuthDegrees: Float = 45
  public static let elevationDegrees: Float = 25
  public static let distance: Float = 9
  public static let fieldOfViewDegrees: Float = 30
  /// The centre of the rough, not the centre of a stone: the rough is what has to fit the frame.
  public static let target = SIMD3<Float>(0, 0, -0.5)
  public static let near: Float = 0.1
  public static let far: Float = 100
}

/// Where the camera sits, in world space.
public func benchCameraPosition() -> SIMD3<Float> {
  let az = BenchCamera.azimuthDegrees * .pi / 180
  let el = BenchCamera.elevationDegrees * .pi / 180
  let direction = SIMD3<Float>(cos(el) * cos(az), cos(el) * sin(az), sin(el))
  return BenchCamera.target + BenchCamera.distance * direction
}

/// Right-handed look-at, world +z up. The stone's axis is +z, and the elevation keeps `up` clear of it.
public func benchViewMatrix() -> simd_float4x4 {
  let eye = benchCameraPosition()
  let zAxis = normalize(eye - BenchCamera.target)
  let xAxis = normalize(cross(SIMD3<Float>(0, 0, 1), zAxis))
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
