import FacetKernel
import Foundation
import XCTest

@testable import BenchGeometry

/// One enumeration of the drawn solid's edges — the one the wireframe draws and the one a click reads.
/// `AuthoredPatterns` lives in `BenchSolidTests.swift`.
final class SolidEdgesTests: XCTestCase {

  // MARK: - The bare prism, counted exactly

  /// 48 edges: 16 top, 16 bottom, 16 vertical — half the 96 edge vertices `SolidMeshTests` pins.
  func testTheBarePrismHas48Edges() {
    XCTAssertEqual(solidEdges(benchSolid(for: nil)).count, 48)
  }

  // MARK: - Two facets per edge, on the prism and on every authored pattern

  func testEveryEdgeIsSharedByExactlyTwoFacets() throws {
    for solid in try everySolid() {
      for edge in solidEdges(solid) {
        XCTAssertEqual(edge.planes.count, 2, "edge \(edge.a)–\(edge.b) is not shared by two facets")
      }
    }
  }

  func testEveryEdgesPlanesAreAscendingAndAreFacetsOfTheSolid() throws {
    for solid in try everySolid() {
      for edge in solidEdges(solid) {
        XCTAssertEqual(edge.planes, edge.planes.sorted())
        for plane in edge.planes {
          XCTAssertNotNil(solid.polytope.facets[plane])
        }
      }
    }
  }

  // MARK: - The key's shape, and the order it comes out in

  func testEveryEdgeHasItsCornersInAscendingOrder() throws {
    for solid in try everySolid() {
      for edge in solidEdges(solid) {
        XCTAssertLessThan(edge.a, edge.b)
      }
    }
  }

  func testTheListIsSortedByCornerPair() throws {
    for solid in try everySolid() {
      let edges = solidEdges(solid)
      let keys = edges.map { ($0.a, $0.b) }
      XCTAssertEqual(keys.map { [$0.0, $0.1] }, keys.sorted { $0 < $1 }.map { [$0.0, $0.1] })
      // Sorted and deduplicated: no pair appears twice.
      XCTAssertEqual(Set(keys.map { "\($0.0)-\($0.1)" }).count, edges.count)
    }
  }

  // MARK: - The mesh reads this and nothing else

  func testTheMeshsEdgeVerticesAreThisEnumerationsCorners() throws {
    for solid in try everySolid() {
      let edges = solidEdges(solid)
      let mesh = solidMesh(solid)
      XCTAssertEqual(mesh.edgeVertices.count, edges.count * 2)

      for (index, edge) in edges.enumerated() {
        let from = solid.polytope.vertices[edge.a]
        let to = solid.polytope.vertices[edge.b]
        XCTAssertEqual(Double(mesh.edgeVertices[index * 2].px), from.x, accuracy: 1e-6)
        XCTAssertEqual(Double(mesh.edgeVertices[index * 2].py), from.y, accuracy: 1e-6)
        XCTAssertEqual(Double(mesh.edgeVertices[index * 2].pz), from.z, accuracy: 1e-6)
        XCTAssertEqual(Double(mesh.edgeVertices[index * 2 + 1].px), to.x, accuracy: 1e-6)
        XCTAssertEqual(Double(mesh.edgeVertices[index * 2 + 1].py), to.y, accuracy: 1e-6)
        XCTAssertEqual(Double(mesh.edgeVertices[index * 2 + 1].pz), to.z, accuracy: 1e-6)
      }
    }
  }

  // MARK: - Determinism

  func testTwoCallsOnOneSolidAgree() throws {
    let solid = benchSolid(for: try AuthoredPatterns.load(AuthoredPatterns.roundBrilliant))
    XCTAssertEqual(solidEdges(solid), solidEdges(solid))
  }

  private func everySolid() throws -> [BenchSolid] {
    try [benchSolid(for: nil)]
      + AuthoredPatterns.all.map { benchSolid(for: try AuthoredPatterns.load($0)) }
  }
}
