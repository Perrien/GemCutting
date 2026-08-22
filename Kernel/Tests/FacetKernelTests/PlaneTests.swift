import FacetKernel
import Foundation
import XCTest

final class PlaneTests: XCTestCase {
  private let tol = 1e-12

  private func azimuth(_ n: (x: Double, y: Double, z: Double)) -> Double {
    atan2(n.y, n.x)
  }

  private func length(_ n: (x: Double, y: Double, z: Double)) -> Double {
    (n.x * n.x + n.y * n.y + n.z * n.z).squareRoot()
  }

  func testIndexZeroOn96WheelHasAzimuthZero() {
    let n = planeNormal(angleDegrees: 43, index: 0, wheel: 96, part: .pav)
    XCTAssertEqual(azimuth(n), 0, accuracy: tol)
    XCTAssertEqual(n.y, 0, accuracy: tol)
    XCTAssertGreaterThan(n.x, 0)
  }

  func testIndex24On96WheelHasAzimuthHalfPi() {
    let n = planeNormal(angleDegrees: 43, index: 24, wheel: 96, part: .pav)
    XCTAssertEqual(azimuth(n), Double.pi / 2, accuracy: tol)
    XCTAssertEqual(n.x, 0, accuracy: tol)
    XCTAssertGreaterThan(n.y, 0)
  }

  func testGirdleAt90DegreesHasZeroZ() {
    for index in [0, 12, 24, 48, 93] {
      let n = planeNormal(angleDegrees: 90, index: index, wheel: 96, part: .gdl)
      XCTAssertEqual(n.z, 0, accuracy: tol, "index \(index)")
    }
  }

  func testTableAtZeroDegreesIsUnitZ() {
    let n = planeNormal(angleDegrees: 0, index: 0, wheel: 96, part: .table)
    XCTAssertEqual(n.x, 0, accuracy: tol)
    XCTAssertEqual(n.y, 0, accuracy: tol)
    XCTAssertEqual(n.z, 1, accuracy: tol)
  }

  func testPavAndCrownDifferOnlyInSignOfZ() {
    for (angle, index) in [(43.0, 0), (27.0, 6), (47.0, 93)] {
      let pav = planeNormal(angleDegrees: angle, index: index, wheel: 96, part: .pav)
      let crown = planeNormal(angleDegrees: angle, index: index, wheel: 96, part: .crown)
      XCTAssertEqual(pav.x, crown.x, accuracy: tol, "angle \(angle) index \(index)")
      XCTAssertEqual(pav.y, crown.y, accuracy: tol, "angle \(angle) index \(index)")
      XCTAssertEqual(pav.z, -crown.z, accuracy: tol, "angle \(angle) index \(index)")
      XCTAssertLessThan(pav.z, 0)
      XCTAssertGreaterThan(crown.z, 0)
    }
  }

  func testEveryNormalIsUnitLength() {
    let parts: [Part] = [.pav, .gdl, .crown, .table]
    for part in parts {
      for angle in [0.0, 27.0, 42.0, 45.0, 43.0, 90.0] {
        for index in [0, 3, 6, 12, 24, 48, 72, 90, 93] {
          let n = planeNormal(angleDegrees: angle, index: index, wheel: 96, part: part)
          XCTAssertEqual(length(n), 1, accuracy: tol, "\(part) \(angle) \(index)")
        }
      }
    }
  }

  func testIndex24DiffersBetween96And120Wheels() {
    let on96 = planeNormal(angleDegrees: 43, index: 24, wheel: 96, part: .pav)
    let on120 = planeNormal(angleDegrees: 43, index: 24, wheel: 120, part: .pav)
    XCTAssertNotEqual(on96.x, on120.x, accuracy: 1e-9)
    XCTAssertNotEqual(on96.y, on120.y, accuracy: 1e-9)
    XCTAssertEqual(azimuth(on96), Double.pi / 2, accuracy: tol)
    XCTAssertEqual(azimuth(on120), 2 * Double.pi * 24 / 120, accuracy: tol)
  }
}
