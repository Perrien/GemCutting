import FacetKernel
import Foundation

/// A quarter of a gear, in stops, or `nil` for a gear a quarter turn cannot be expressed on (D17).
func quarterTurnStops(onWheel wheel: Int) -> Int? {
  wheel % 4 == 0 ? wheel / 4 : nil
}

/// The gear that stops this pattern turning, as the refusal names it, or `nil` when every gear divides
/// by 4.
///
/// Checked over the header's gear and every tier's effective gear, in file order. **The header's gear is
/// checked whether or not any tier inherits it**, because a tier added later would.
public func quarterTurnRefusal(in draft: PatternDraft) -> DraftRefusal? {
  if quarterTurnStops(onWheel: draft.wheel) == nil {
    return .quarterTurnGearNotDivisible(tier: nil, wheel: draft.wheel)
  }
  for tier in draft.tiers where quarterTurnStops(onWheel: draft.wheel(of: tier)) == nil {
    return .quarterTurnGearNotDivisible(tier: tier.tier, wheel: draft.wheel(of: tier))
  }
  return nil
}

/// The whole pattern, turned a quarter turn counter-clockwise — the direction the index advances in.
///
/// **Refuses as a whole or not at all** (D17): the gear check runs before anything is rewritten, so a
/// refused turn changes nothing. A quarter turn swaps the two axis extents, and width is the smaller of
/// them, so the width, the length-over-width and the girdle band sized from width all survive untouched.
///
/// The header gear, the refractive index, the girdle target, every angle, every `part` and the tier
/// order are all left exactly as they are.
public func turningAQuarter(_ draft: PatternDraft) -> Result<PatternDraft, DraftRefusal> {
  if let refusal = quarterTurnRefusal(in: draft) { return .failure(refusal) }

  let gearOfTier = { (label: String) -> Int? in
    draft.tiers.first { $0.tier == label }.map(draft.wheel(of:))
  }

  var turned = draft
  for position in turned.tiers.indices {
    let gear = draft.wheel(of: turned.tiers[position])
    guard let quarter = quarterTurnStops(onWheel: gear) else { continue }
    // **Rewritten in place, never sorted** (D18): the format permits any order and the order is data —
    // a sheet that reads a tier's stops as `12 24 36 48 60 72 84 0` has to stay that way.
    turned.tiers[position].indices = turned.tiers[position].indices.map { ($0 + quarter) % gear }
    turned.tiers[position].meet = turned.tiers[position].meet.map {
      BenchGeometry.turned($0, gearOfTier: gearOfTier)
    }
  }
  return .success(turned)
}

/// Every index inside a meet, advanced a quarter turn on the gear of the tier that index *names* — which
/// is not the gear of the tier carrying the meet. Recurses into a `fraction`'s two endpoints.
///
/// `size`, `tcp` and `girdle` carry no index and come back unchanged. An index naming a tier the draft
/// does not carry is left exactly as it is: a dangling reference is a fault the findings already report,
/// and inventing a gear for it would turn one fault into two.
func turned(_ meet: Meet, gearOfTier: (String) -> Int?) -> Meet {
  switch meet {
  case .size, .tcp, .girdle:
    return meet
  case .vertex(let facets):
    return .vertex(
      facets: facets.map { ref in
        guard let gear = gearOfTier(ref.tier), let quarter = quarterTurnStops(onWheel: gear) else {
          return ref
        }
        return FacetRef(tier: ref.tier, index: (ref.index + quarter) % gear)
      })
  case .fraction(let from, let percent, let to):
    return .fraction(
      from: turned(from, gearOfTier: gearOfTier),
      percent: percent,
      to: turned(to, gearOfTier: gearOfTier))
  }
}
