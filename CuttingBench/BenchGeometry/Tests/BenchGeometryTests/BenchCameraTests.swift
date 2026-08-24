import FacetKernel
import Foundation
import XCTest
import simd

@testable import BenchGeometry

final class BenchCameraTests: XCTestCase {
  private let tol: Float = 1e-5

  // MARK: - The view matrix

  func testTheCameraPositionMapsToTheViewSpaceOrigin() {
    let mapped = benchViewMatrix() * SIMD4<Float>(benchCameraPosition(), 1)

    XCTAssertEqual(mapped.x, 0, accuracy: tol)
    XCTAssertEqual(mapped.y, 0, accuracy: tol)
    XCTAssertEqual(mapped.z, 0, accuracy: tol)
    XCTAssertEqual(mapped.w, 1, accuracy: tol)
  }

  func testTheTargetSitsStraightAheadAtTheCameraDistance() {
    let mapped = benchViewMatrix() * SIMD4<Float>(BenchCamera.target, 1)

    XCTAssertEqual(mapped.x, 0, accuracy: tol)
    XCTAssertEqual(mapped.y, 0, accuracy: tol)
    XCTAssertEqual(mapped.z, -BenchCamera.distance, accuracy: tol)
    XCTAssertEqual(mapped.w, 1, accuracy: tol)
  }

  // MARK: - The projection matrix

  func testTheDepthRangeIsMetalsZeroToOne() {
    let projection = benchProjectionMatrix(aspect: 1)

    let near = projection * SIMD4<Float>(0, 0, -BenchCamera.near, 1)
    XCTAssertEqual(near.z / near.w, 0, accuracy: tol)

    let far = projection * SIMD4<Float>(0, 0, -BenchCamera.far, 1)
    XCTAssertEqual(far.z / far.w, 1, accuracy: tol)
  }

  /// The test that fails if the distance constant is tuned too tight at T4's owner stop: the whole rough
  /// has to be on screen at a tall viewport and at a wide one.
  ///
  /// Widened to every camera the orbit can reach, and to the circle the index ring's labels sit on —
  /// every anchor any pattern can produce lies on it, so the circle is the framing constraint and no
  /// pattern needs loading.
  func testTheFramingConstantsFitTheWholeRough() {
    let solid = benchSolid(for: nil)
    XCTAssertEqual(solid.polytope.vertices.count, 32)

    let roughPoints = solid.polytope.vertices.map {
      SIMD3<Float>(Float($0.x), Float($0.y), Float($0.z))
    }
    let points = roughPoints + ringCirclePoints

    for elevation in [Float(-90), -25, 0, 25, 90] {
      for azimuth in [Float(0), 22.5, 45, 270] {
        let camera = BenchCameraState(azimuthDegrees: azimuth, elevationDegrees: elevation)

        for aspect in [Float(0.75), Float(2.0)] {
          let viewProjection = benchProjectionMatrix(aspect: aspect) * benchViewMatrix(camera)
          let at = "at azimuth \(azimuth), elevation \(elevation), aspect \(aspect)"

          for point in points {
            let clip = viewProjection * SIMD4<Float>(point, 1)
            XCTAssertGreaterThan(clip.w, 0, "behind the camera \(at)")

            let ndc = SIMD3<Float>(clip.x / clip.w, clip.y / clip.w, clip.z / clip.w)
            XCTAssertLessThanOrEqual(abs(ndc.x), 1, "x off screen \(at)")
            XCTAssertLessThanOrEqual(abs(ndc.y), 1, "y off screen \(at)")
            XCTAssertGreaterThanOrEqual(ndc.z, 0, "z clipped near \(at)")
            XCTAssertLessThanOrEqual(ndc.z, 1, "z clipped far \(at)")
          }
        }
      }
    }
  }

  // MARK: - Orbit

  func testOrbitWrapsTheAzimuthAndClampsTheElevationAtThePoles() {
    var camera = BenchCameraState(azimuthDegrees: 350, elevationDegrees: 80)

    // 40 points at 0.5° a point is 20°, so the azimuth passes 360 and the elevation passes 90.
    camera.orbit(dxPoints: 40, dyPoints: 40)
    XCTAssertEqual(camera.azimuthDegrees, 10, accuracy: tol)
    XCTAssertEqual(camera.elevationDegrees, 90, accuracy: tol)

    camera.orbit(dxPoints: 0, dyPoints: -800)
    XCTAssertEqual(camera.elevationDegrees, -90, accuracy: tol)
  }

  // MARK: - The poles

  func testThePoleBasesAreFiniteAndOrthonormal() {
    for camera in [BenchCameraState.faceUp, .faceDown] {
      let basis = viewBasis(benchViewMatrix(camera))

      for axis in [basis.x, basis.y, basis.z] {
        XCTAssertTrue(axis.x.isFinite, "NaN at \(camera)")
        XCTAssertTrue(axis.y.isFinite, "NaN at \(camera)")
        XCTAssertTrue(axis.z.isFinite, "NaN at \(camera)")
        XCTAssertEqual(length(axis), 1, accuracy: tol, "not unit at \(camera)")
      }

      XCTAssertEqual(dot(basis.x, basis.y), 0, accuracy: tol)
      XCTAssertEqual(dot(basis.y, basis.z), 0, accuracy: tol)
      XCTAssertEqual(dot(basis.z, basis.x), 0, accuracy: tol)
      XCTAssertEqual(length(cross(basis.x, basis.y) - basis.z), 0, accuracy: tol)
    }
  }

  /// Face up is the plan view, so the conventional orientation is world +x at screen right and +y at
  /// screen up. That is what pins the snaps' azimuth of 270.
  func testFaceUpPutsWorldXAtScreenRightAndWorldYAtScreenUp() {
    let view = benchViewMatrix(.faceUp)

    let right = view * SIMD4<Float>(BenchCamera.target + SIMD3<Float>(1, 0, 0), 1)
    XCTAssertEqual(right.x, 1, accuracy: tol)
    XCTAssertEqual(right.y, 0, accuracy: tol)

    let up = view * SIMD4<Float>(BenchCamera.target + SIMD3<Float>(0, 1, 0), 1)
    XCTAssertEqual(up.x, 0, accuracy: tol)
    XCTAssertEqual(up.y, 1, accuracy: tol)
  }

  /// The assertion an up reference swapped *near* the pole rather than *at* it would fail: it would roll
  /// the image mid-drag.
  func testTheBasisIsContinuousThroughThePole() {
    let below = viewBasis(
      benchViewMatrix(BenchCameraState(azimuthDegrees: 45, elevationDegrees: 89.9)))
    let atPole = viewBasis(
      benchViewMatrix(BenchCameraState(azimuthDegrees: 45, elevationDegrees: 90)))

    for (a, b) in [(below.x, atPole.x), (below.y, atPole.y), (below.z, atPole.z)] {
      XCTAssertEqual(a.x, b.x, accuracy: 5e-3)
      XCTAssertEqual(a.y, b.y, accuracy: 5e-3)
      XCTAssertEqual(a.z, b.z, accuracy: 5e-3)
    }
  }

  // MARK: - The ray and the screen point

  func testTheCentreRayRunsFromTheCameraTowardTheTarget() {
    for camera in [BenchCameraState.threeQuarter, .faceUp, .faceDown] {
      let ray = benchRay(ndcX: 0, ndcY: 0, aspect: 1.5, camera: camera)
      let axis = BenchCamera.target - benchCameraPosition(camera)

      XCTAssertEqual(
        length(cross(normalize(ray.direction), normalize(axis))), 0, accuracy: 1e-4,
        "not down the view axis at \(camera)")
      XCTAssertGreaterThan(dot(ray.direction, axis), 0, "pointing backwards at \(camera)")
    }
  }

  func testTheTargetProjectsToTheCentreOfTheViewport() {
    for camera in [BenchCameraState.threeQuarter, .faceUp, .faceDown] {
      let point = benchScreenPoint(BenchCamera.target, aspect: 1.5, camera: camera)

      XCTAssertEqual(point?.x ?? .nan, 0.5, accuracy: 1e-5, "at \(camera)")
      XCTAssertEqual(point?.y ?? .nan, 0.5, accuracy: 1e-5, "at \(camera)")
    }
  }

  /// The one y flip in the codebase: Metal's NDC y is up and SwiftUI's is down, so a point above the
  /// target has to come back *below* the centre in the overlay's coordinates.
  func testAPointAboveTheTargetProjectsAboveTheCentreOfTheViewport() {
    let above = BenchCamera.target + SIMD3<Float>(0, 0, 1)
    let point = benchScreenPoint(above, aspect: 1.5, camera: .threeQuarter)

    XCTAssertNotNil(point)
    XCTAssertEqual(point?.x ?? .nan, 0.5, accuracy: 1e-5)
    XCTAssertLessThan(point?.y ?? .nan, 0.5)
  }

  // MARK: - Helpers

  /// The 32 points the framing check samples the index ring's circle at. Every ring anchor any
  /// pattern can produce lies on this circle, so the circle is the framing constraint and no pattern
  /// needs loading.
  private var ringCirclePoints: [SIMD3<Float>] {
    let radius = Float(IndexRing.radius)
    let z = Float(IndexRing.z)
    return (0..<32).map { stop in
      let theta = 2 * Float.pi * Float(stop) / 32
      return SIMD3<Float>(cos(theta) * radius, sin(theta) * radius, z)
    }
  }

  /// The view matrix's rows are the basis it was built from: row 0 is screen right, row 1 screen up,
  /// row 2 the direction back toward the camera.
  private func viewBasis(
    _ view: simd_float4x4
  ) -> (x: SIMD3<Float>, y: SIMD3<Float>, z: SIMD3<Float>) {
    (
      x: SIMD3(view[0][0], view[1][0], view[2][0]),
      y: SIMD3(view[0][1], view[1][1], view[2][1]),
      z: SIMD3(view[0][2], view[1][2], view[2][2])
    )
  }
}
