import FacetKernel
import Foundation
import XCTest
import simd

@testable import BenchGeometry

final class SolidMeshTests: XCTestCase {

  // MARK: - The layout the renderer hardcodes

  func testTheVertexLayoutIsSevenFloatsWithNoPadding() {
    XCTAssertEqual(MemoryLayout<MeshVertex>.stride, 28)
    XCTAssertEqual(MemoryLayout<MeshVertex>.offset(of: \.px), 0)
    XCTAssertEqual(MemoryLayout<MeshVertex>.offset(of: \.nx), 12)
    XCTAssertEqual(MemoryLayout<MeshVertex>.offset(of: \.role), 24)
  }

  // MARK: - The bare prism, counted exactly

  func testTheBarePrismsCountsAreExact() {
    let mesh = solidMesh(benchSolid(for: nil))

    // 60 triangles: 14 from each 16-gon cap, 2 from each of 16 quad walls.
    XCTAssertEqual(mesh.triangleVertices.count, 180)
    // 48 unique edges: 16 top, 16 bottom, 16 vertical.
    XCTAssertEqual(mesh.edgeVertices.count, 96)
  }

  /// Euler's formula, which is what proves the edges were deduplicated: a doubled edge list fails it.
  func testEulerHoldsForThePrismAndEveryAuthoredPattern() throws {
    let solids =
      try [benchSolid(for: nil)]
      + AuthoredPatterns.all.map {
        benchSolid(for: try AuthoredPatterns.load($0))
      }

    for solid in solids {
      let mesh = solidMesh(solid)
      XCTAssertEqual(
        mesh.edgeVertices.count / 2,
        solid.polytope.vertices.count + solid.polytope.facets.count - 2)
    }
  }

  // MARK: - Roles

  func testRoleIsOneForRoughAndZeroForCut() throws {
    let bare = solidMesh(benchSolid(for: nil))
    XCTAssertTrue(bare.triangleVertices.allSatisfy { $0.role == 1 })

    let octagon = solidMesh(
      benchSolid(for: try AuthoredPatterns.load(AuthoredPatterns.easyOctagon)))
    XCTAssertTrue(octagon.triangleVertices.allSatisfy { $0.role == 0 })

    let halfCut = solidMesh(
      benchSolid(for: try AuthoredPatterns.load(AuthoredPatterns.noviceAsher), tierLimit: 2))
    XCTAssertTrue(halfCut.triangleVertices.contains { $0.role == 1 })
    XCTAssertTrue(halfCut.triangleVertices.contains { $0.role == 0 })
  }

  // MARK: - Normals

  func testEveryNormalIsThePlanesOwnAndUnitLength() {
    let solid = benchSolid(for: nil)
    let mesh = solidMesh(solid)

    for vertex in mesh.triangleVertices {
      let length = simd_length(SIMD3<Float>(vertex.nx, vertex.ny, vertex.nz))
      XCTAssertEqual(length, 1, accuracy: 1e-6)
    }

    // Plane 2 is `G1`, whose outward normal lies on +x. Its triangles are the ones all three of whose
    // vertices sit on the wall — a cap triangle touching the wall only ever has two of them there.
    let triangles = stride(from: 0, to: mesh.triangleVertices.count, by: 3).map {
      Array(mesh.triangleVertices[$0..<($0 + 3)])
    }
    let wallTriangles = triangles.filter { triangle in
      triangle.allSatisfy { abs(Double($0.px) - Rough.radius) < 1e-6 }
    }
    XCTAssertEqual(wallTriangles.count, 2)
    for vertex in wallTriangles.flatMap({ $0 }) {
      XCTAssertEqual(vertex.nx, 1, accuracy: 1e-6)
      XCTAssertEqual(vertex.ny, 0, accuracy: 1e-6)
      XCTAssertEqual(vertex.nz, 0, accuracy: 1e-6)
    }
  }

  // MARK: - Determinism

  func testTwoCallsOnOneSolidAgree() throws {
    let solid = benchSolid(for: try AuthoredPatterns.load(AuthoredPatterns.roundBrilliant))
    let first = solidMesh(solid)
    let second = solidMesh(solid)

    XCTAssertEqual(first.triangleVertices, second.triangleVertices)
    XCTAssertEqual(first.edgeVertices, second.edgeVertices)
  }
}
