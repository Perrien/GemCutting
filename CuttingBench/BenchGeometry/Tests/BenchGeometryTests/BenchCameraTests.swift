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
  func testTheFramingConstantsFitTheWholeRough() {
    let solid = benchSolid(for: nil)
    XCTAssertEqual(solid.polytope.vertices.count, 32)

    for aspect in [Float(0.75), Float(2.0)] {
      let viewProjection = benchProjectionMatrix(aspect: aspect) * benchViewMatrix()

      for vertex in solid.polytope.vertices {
        let world = SIMD4<Float>(Float(vertex.x), Float(vertex.y), Float(vertex.z), 1)
        let clip = viewProjection * world
        XCTAssertGreaterThan(clip.w, 0, "behind the camera at aspect \(aspect)")

        let ndc = SIMD3<Float>(clip.x / clip.w, clip.y / clip.w, clip.z / clip.w)
        XCTAssertLessThanOrEqual(abs(ndc.x), 1, "x off screen at aspect \(aspect)")
        XCTAssertLessThanOrEqual(abs(ndc.y), 1, "y off screen at aspect \(aspect)")
        XCTAssertGreaterThanOrEqual(ndc.z, 0, "z clipped near at aspect \(aspect)")
        XCTAssertLessThanOrEqual(ndc.z, 1, "z clipped far at aspect \(aspect)")
      }
    }
  }
}
