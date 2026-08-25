import Foundation
import simd

/// The framing constants every camera shares. `azimuthDegrees` and `elevationDegrees` are the
/// *starting* orientation only: where the camera is now lives in a `BenchCameraState`.
///
/// **There is no `distance` constant.** How far back the camera sits is fitted to the viewport's shape
/// by `benchCameraDistance(aspect:)`, because one distance chosen for the narrowest window a person
/// might drag spends most of a wide window on nothing — and wide is the shape this app is used at.
public enum BenchCamera {
  public static let azimuthDegrees: Float = 45
  public static let elevationDegrees: Float = 25
  public static let fieldOfViewDegrees: Float = 30
  public static let near: Float = 0.1
  public static let far: Float = 100
  public static let orbitDegreesPerPoint: Float = 0.5

  // MARK: - The framed volume

  /// A cylinder on the axis that everything ever drawn sits inside. **The frame is fitted to this, not
  /// to the solid**, which is what keeps the framing still: it does not shift when a tier is stepped,
  /// when the rough comes away, or as the stone is orbited. A stone that resized itself mid-scrub would
  /// be impossible to compare against the step before it.
  ///
  /// The index ring's circle, which is wider than both the rough's walls and any stone that can be cut
  /// inside them.
  public static let framedRadius = Float(IndexRing.radius)
  /// The rough's crown cap: the highest thing ever drawn.
  public static let framedTop: Float = 1
  /// The deepest a *stone* reaches — a barion's culet at −1.216 on a short-axis normalisation, and
  /// `Novice Ash-er`'s intermediate pavilion point at −1.19175 — with a little to spare.
  ///
  /// **Deliberately not the rough's bottom cap at −2.** The pavilion cuts that cap away before it is
  /// ever the lowest thing on screen, so framing for it would spend a fifth of the viewport's height on
  /// empty space. The cost is that the bare prism's own bottom point falls outside the frame, which is
  /// visible on a new document and while the first tier or two are cut, and is empty air after that.
  public static let framedBottom: Float = -1.25

  /// The centre of the framed volume, which is what the camera looks at.
  public static let target = SIMD3<Float>(0, 0, (framedTop + framedBottom) / 2)

  /// Room left around the framed volume. An exact fit puts the index ring's circle precisely on the
  /// frame's edge, and each number is *text centred on that circle*, so half of it would fall off the
  /// side. This is what that text needs, and it absorbs the hair of float slack an exact fit leaves as
  /// well.
  public static let framingMargin: Float = 1.04
}

/// One sample of the framed volume's silhouette, in the only two terms the fit needs.
private struct FramedSample: Sendable {
  /// How far the point is from the target.
  let radial: Float
  /// How much frame width it asks for: its distance from the view axis, across the screen.
  let acrossAxis: Float
}

/// The framed volume's silhouette, sampled once for the life of the process.
///
/// Only the two rims are sampled: a wall runs straight between them and the room a point asks for is
/// convex along that line, so its worst value is at one end or the other and never in the middle. And
/// only half a turn, because `cos` and `abs(sin)` repeat over the other half.
private let framedSamples: [FramedSample] = (0...16).flatMap { step -> [FramedSample] in
  let theta = Float.pi * Float(step) / 16
  let alongAxis = BenchCamera.framedRadius * cos(theta)
  let acrossAxis = BenchCamera.framedRadius * abs(sin(theta))
  return [BenchCamera.framedTop, BenchCamera.framedBottom].map { z in
    let height = z - BenchCamera.target.z
    return FramedSample(
      radial: (alongAxis * alongAxis + height * height).squareRoot(), acrossAxis: acrossAxis)
  }
}

/// The closest the camera can sit with the framed volume wholly inside a viewport of this shape.
///
/// Fitted to the **worst orientation the orbit can reach**, not the current one, so turning the stone
/// never resizes it — only reshaping the window does. Azimuth never enters it: the framed volume is a
/// cylinder, which presents the same silhouette at every azimuth.
///
/// **No orientation is swept**, because the worst one has a closed form. Turned to face the camera
/// squarely, a point at distance `radial` from the target needs the frame's half-height to reach
/// `radial · sin(half the field of view)` — which is the volume's bounding sphere, and a sphere looks
/// the same from every angle. The width term is the same statement across the screen instead of up it.
/// Both are worst cases rather than approximations, so the fit can never come out too close.
///
/// This matters because it is on the drag path: every index label asks for it on every frame, and a
/// version of this that swept 181 elevations cost 3 ms a call and dropped dragging to a crawl.
public func benchCameraDistance(aspect: Float) -> Float {
  let upTangent = tan(BenchCamera.fieldOfViewDegrees * .pi / 360)
  let rightTangent = upTangent * aspect
  let cosecant = (1 + 1 / (upTangent * upTangent)).squareRoot()
  var distance: Float = 0

  for sample in framedSamples {
    distance = max(
      distance, sample.radial * cosecant, sample.radial + sample.acrossAxis / rightTangent)
  }

  return distance * BenchCamera.framingMargin
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

/// Where the camera sits, in world space. `aspect` is the viewport's width over its height, which is
/// what fixes how far back it has to be.
public func benchCameraPosition(
  _ camera: BenchCameraState = .threeQuarter,
  aspect: Float
) -> SIMD3<Float> {
  let az = camera.azimuthDegrees * .pi / 180
  let el = camera.elevationDegrees * .pi / 180
  let direction = SIMD3<Float>(cos(el) * cos(az), cos(el) * sin(az), sin(el))
  return BenchCamera.target + benchCameraDistance(aspect: aspect) * direction
}

/// Right-handed look-at. The stone's axis is +z, and the camera never rolls: screen right stays in the
/// world's xy plane at every elevation.
public func benchViewMatrix(
  _ camera: BenchCameraState = .threeQuarter,
  aspect: Float
) -> simd_float4x4 {
  let eye = benchCameraPosition(camera, aspect: aspect)
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
  let inverse = (benchProjectionMatrix(aspect: aspect) * benchViewMatrix(camera, aspect: aspect))
    .inverse
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
  let viewProjection =
    benchProjectionMatrix(aspect: aspect) * benchViewMatrix(camera, aspect: aspect)
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
