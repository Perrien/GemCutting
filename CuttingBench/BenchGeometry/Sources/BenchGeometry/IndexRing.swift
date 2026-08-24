import FacetKernel
import Foundation

/// The ring's build constants. No UI and no preference (D15, U4).
public enum IndexRing {
  /// Just outside the rough's radius of 1.5, so nothing on the stone occludes a number.
  public static let radius = 1.6
  /// The girdle plane. Every authored pattern's girdle sits about here.
  public static let z = 0.0
  /// Full alpha from this elevation up, zero at edge-on. **One constant**, tuned at T7's owner stop.
  public static let fadeDegrees: Float = 12
}

/// One number around the rim: what it reads and where in the world it sits.
public struct IndexRingLabel: Equatable, Sendable, Identifiable {
  public var wheel: Int
  public var index: Int
  public var text: String
  public var anchor: SIMD3<Float>

  /// The same pair the dedupe keys on, so `ForEach`'s idea of one label and this file's agree.
  public var id: SIMD2<Int> { SIMD2(wheel, index) }

  public init(wheel: Int, index: Int, text: String, anchor: SIMD3<Float>) {
    self.wheel = wheel
    self.index = index
    self.text = text
    self.anchor = anchor
  }
}

/// The index stops the pattern actually uses (D14, D17).
///
/// One label per distinct `(wheel, index)` across `solid.tiers`, ordered by azimuth, then wheel, then
/// index. `text` is the index alone while every label shares one wheel, and `"\(index)/\(wheel)"` as
/// soon as two wheels appear, so a tier cut in its own gear reads in it. Empty for no pattern, which
/// is what leaves a bare prism with no ring.
public func indexRingLabels(_ solid: BenchSolid) -> [IndexRingLabel] {
  var seen: Set<SIMD2<Int>> = []
  var stops: [(wheel: Int, index: Int)] = []
  for tier in solid.tiers {
    for index in tier.indices where seen.insert(SIMD2(tier.wheel, index)).inserted {
      stops.append((wheel: tier.wheel, index: index))
    }
  }

  // Decided once, after the dedupe, and applied to every label, so the whole ring reads in one style
  // rather than switching per label (D14).
  let oneWheel = Set(stops.map { $0.wheel }).count == 1

  return
    stops
    .map { stop in
      // Index 0 on +x, advancing counter-clockwise: the rough's walls' own convention, and
      // `planeNormal`'s.
      let theta = 2 * Double.pi * Double(stop.index) / Double(stop.wheel)
      return IndexRingLabel(
        wheel: stop.wheel,
        index: stop.index,
        text: oneWheel ? "\(stop.index)" : "\(stop.index)/\(stop.wheel)",
        anchor: SIMD3<Float>(
          Float(cos(theta) * IndexRing.radius),
          Float(sin(theta) * IndexRing.radius),
          Float(IndexRing.z)))
    }
    .sorted { a, b in
      // The azimuth is the index as a fraction of its own wheel, so two gears sort together rather
      // than one after the other.
      let azimuthA = Double(a.index) / Double(a.wheel)
      let azimuthB = Double(b.index) / Double(b.wheel)
      if azimuthA != azimuthB { return azimuthA < azimuthB }
      if a.wheel != b.wheel { return a.wheel < b.wheel }
      return a.index < b.index
    }
}

/// The ring's alpha at this camera: gone edge-on, where the rim projects to a line, and full from
/// `IndexRing.fadeDegrees` up (D15).
public func indexRingAlpha(_ camera: BenchCameraState) -> Double {
  Double(min(abs(camera.elevationDegrees) / IndexRing.fadeDegrees, 1))
}
