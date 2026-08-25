import FacetKernel
import Foundation
import XCTest
import simd

@testable import BenchGeometry

final class BenchCameraTests: XCTestCase {
  private let tol: Float = 1e-5

  // MARK: - The view matrix

  func testTheCameraPositionMapsToTheViewSpaceOrigin() {
    let mapped = benchViewMatrix(aspect: 1.5) * SIMD4<Float>(benchCameraPosition(aspect: 1.5), 1)

    XCTAssertEqual(mapped.x, 0, accuracy: tol)
    XCTAssertEqual(mapped.y, 0, accuracy: tol)
    XCTAssertEqual(mapped.z, 0, accuracy: tol)
    XCTAssertEqual(mapped.w, 1, accuracy: tol)
  }

  func testTheTargetSitsStraightAheadAtTheCameraDistance() {
    let mapped = benchViewMatrix(aspect: 1.5) * SIMD4<Float>(BenchCamera.target, 1)

    XCTAssertEqual(mapped.x, 0, accuracy: tol)
    XCTAssertEqual(mapped.y, 0, accuracy: tol)
    XCTAssertEqual(mapped.z, -benchCameraDistance(aspect: 1.5), accuracy: tol)
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

  /// The check that fails if the framing is fitted too tight: the framed volume has to be wholly on
  /// screen at every shape of window and every camera the orbit can reach — and so does every stone the
  /// corpus can cut, along with the deepest intermediate point any of them passes through, which is the
  /// guarantee that actually matters.
  func testTheFramingFitsTheFramedVolumeAndEveryAuthoredStone() throws {
    var points = framedVolumePoints + ringCirclePoints

    for name in AuthoredPatterns.all {
      let pattern = try AuthoredPatterns.load(name)
      points += worldVertices(of: benchSolid(for: pattern))
    }
    // `Novice Ash-er`'s P1 axial point forms at −1.19175 before P2 and P3 cut it back, which is the
    // lowest anything ever gets that is not the bare prism's own cap.
    points += worldVertices(
      of: benchSolid(for: try AuthoredPatterns.load(AuthoredPatterns.noviceAsher), tierLimit: 2))

    for aspect in [Float(0.5), 0.75, 1, 1.5, 2, 3.5] {
      for elevation in [Float(-90), -25, 0, 25, 90] {
        for azimuth in [Float(0), 11.25, 22.5, 45, 270] {
          let camera = BenchCameraState(azimuthDegrees: azimuth, elevationDegrees: elevation)
          let viewProjection =
            benchProjectionMatrix(aspect: aspect) * benchViewMatrix(camera, aspect: aspect)
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

  /// The point of fitting rather than fixing. A wide window brings the camera in, where one distance
  /// chosen for the narrowest window anyone might drag left most of a wide one empty; a tall window
  /// pulls it back far enough to keep the index numbers on screen, which the old fixed distance of 9 did
  /// not manage at all.
  func testTheFramingFollowsTheViewportsShape() {
    let wide = benchCameraDistance(aspect: 3)
    let square = benchCameraDistance(aspect: 1)
    let tall = benchCameraDistance(aspect: 0.5)

    XCTAssertLessThan(wide, 9)
    XCTAssertLessThanOrEqual(wide, square)
    XCTAssertLessThan(square, tall)

    // Past square it is the height that binds, so no window is ever framed closer than this.
    XCTAssertEqual(wide, benchCameraDistance(aspect: 10), accuracy: tol)
  }

  /// The one thing deliberately left outside the frame, recorded so it reads as a choice and not a bug:
  /// the bare prism's bottom cap. Every pavilion cuts it away before it is the lowest thing on screen,
  /// so framing for it would spend a fifth of the viewport's height on empty air.
  func testTheBarePrismsBottomCapIsDeliberatelyOutsideTheFrame() throws {
    let lowestOfPrism = benchSolid(for: nil).polytope.vertices.map(\.z).min()

    XCTAssertEqual(try XCTUnwrap(lowestOfPrism), -2, accuracy: 1e-9)
    XCTAssertGreaterThan(BenchCamera.framedBottom, -2)
    // Still clear of the deepest point a stone ever reaches.
    XCTAssertLessThan(BenchCamera.framedBottom, -1.216)
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
      let basis = viewBasis(benchViewMatrix(camera, aspect: 1.5))

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
    let view = benchViewMatrix(.faceUp, aspect: 1.5)

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
      benchViewMatrix(BenchCameraState(azimuthDegrees: 45, elevationDegrees: 89.9), aspect: 1.5))
    let atPole = viewBasis(
      benchViewMatrix(BenchCameraState(azimuthDegrees: 45, elevationDegrees: 90), aspect: 1.5))

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
      let axis = BenchCamera.target - benchCameraPosition(camera, aspect: 1.5)

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

  /// The framed volume's two rims, which is where its silhouette's extremes are.
  private var framedVolumePoints: [SIMD3<Float>] {
    (0..<32).flatMap { step -> [SIMD3<Float>] in
      let theta = 2 * Float.pi * Float(step) / 32
      let x = BenchCamera.framedRadius * cos(theta)
      let y = BenchCamera.framedRadius * sin(theta)
      return [
        SIMD3<Float>(x, y, BenchCamera.framedTop),
        SIMD3<Float>(x, y, BenchCamera.framedBottom),
      ]
    }
  }

  private func worldVertices(of solid: BenchSolid) -> [SIMD3<Float>] {
    solid.polytope.vertices.map { SIMD3<Float>(Float($0.x), Float($0.y), Float($0.z)) }
  }

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
