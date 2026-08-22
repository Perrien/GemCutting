// PROTOTYPE — throwaway. Answers .scratch/faceting-game/issues/01-render-proof.md
//
// A cut gem as an intersection of half-spaces. No mesh, no BVH, no convex-hull
// construction: the ticket's convexity claim means a ray/solid intersection is
// just slab clipping over the plane list.

import simd

struct Plane {
    var n: SIMD3<Float>
    var d: Float
    /// Per-facet multipliers on the global finish — lets a half-polished stone
    /// be expressed, which is what a stone actually looks like mid-cut.
    var roughMul: Float = 1
    var scatterMul: Float = 1
}

/// A facet tier in faceting-machine terms: mast angle + a list of index-wheel teeth.
struct Tier {
    var angle: Float          // mast angle, degrees. 0 = table, 90 = girdle.
    var indices: [Int]
    var crown: Bool           // false = cut with the stone flipped (pavilion)
    var depth: Float          // plane offset along its own normal
    var name: String
    var roughMul: Float = 1           // 0 = this tier is already polished
    var scatterMul: Float = 1
    var perFacetPolished: Set<Int> = []   // index-wheel teeth polished within this tier
}

struct Design {
    var name: String
    var wheel: Int            // index wheel teeth (96 or 120)
    var tiers: [Tier]

    var planes: [Plane] {
        var out: [Plane] = []
        for tier in tiers {
            let a = tier.angle * .pi / 180
            let sa = sin(a), ca = cos(a)
            let zsign: Float = tier.crown ? 1 : -1
            for idx in tier.indices {
                let theta = 2 * Float.pi * Float(idx) / Float(wheel)
                let done = tier.perFacetPolished.contains(idx)
                out.append(Plane(n: SIMD3(sa * cos(theta), sa * sin(theta), zsign * ca),
                                 d: tier.depth,
                                 roughMul: done ? 0 : tier.roughMul,
                                 scatterMul: done ? 0 : tier.scatterMul))
            }
        }
        return out
    }
}

// MARK: - Surface finish

/// How far through coarse → fine → polish a facet has been taken.
///
/// `roughness` is GGX alpha (microfacet tilt spread). `scatter` is the fraction
/// of surface hits that go diffuse instead — deep sub-grit pits, which is what
/// makes an unpolished facet read as chalky rather than merely blurry.
/// `edgeSoften` blends facet normals at junctions. It must stay under ~0.0015
/// (girdle radius 1.0): the blend is distance-based over the whole plane list, and
/// this design has near-coincident planes (pavilion mains vs lower girdle halves,
/// adjacent girdle facets) that smear into one surface above that. True rounding
/// needs a Minkowski/SDF solid, not normal blending.
struct Finish {
    var name: String
    var roughness: Float
    var scatter: Float
    var edgeSoften: Float
    var scatterAlbedo: Float = 0.55

    static let polished  = Finish(name: "polished",             roughness: 0.00, scatter: 0.00, edgeSoften: 0.0003)
    static let prepolish = Finish(name: "pre-polish (3000)",    roughness: 0.04, scatter: 0.02, edgeSoften: 0.0005)
    static let fineCut   = Finish(name: "fine cut (1200)",      roughness: 0.10, scatter: 0.05, edgeSoften: 0.0008)
    static let midCut    = Finish(name: "mid cut (600)",        roughness: 0.16, scatter: 0.10, edgeSoften: 0.0011)
    static let coarseCut = Finish(name: "coarse cut (100)",     roughness: 0.24, scatter: 0.18, edgeSoften: 0.0015)
    static let preform   = Finish(name: "preform (rounded)",    roughness: 0.34, scatter: 0.30, edgeSoften: 0.0018)

    static let ladder: [Finish] = [polished, prepolish, fineCut, midCut, coarseCut, preform]
}

// MARK: - Partial cut states

extension Design {
    /// Mark a subset of tiers as already polished, leaving the rest at the
    /// global finish — a stone caught mid-cut.
    func withPolishedTiers(_ names: Set<String>) -> Design {
        var d = self
        d.tiers = d.tiers.map { t in
            var t = t
            if names.contains(t.name) { t.roughMul = 0; t.scatterMul = 0 }
            return t
        }
        d.name += " [polished: \(names.sorted().joined(separator: ", "))]"
        return d
    }

    /// Every other facet within each tier polished — what a stone looks like
    /// partway through a lap, one facet at a time.
    func withAlternatingFacetsPolished() -> Design {
        var d = self
        d.tiers = d.tiers.map { t in
            var t = t
            t.perFacetPolished = Set(t.indices.enumerated().compactMap { $0.offset % 2 == 0 ? $0.element : nil })
            return t
        }
        d.name += " [alternating facets polished]"
        return d
    }
}

// MARK: - Standard Round Brilliant

/// Girdle radius is 1.0; the girdle band straddles z = 0 with half-thickness `gt`.
///
/// Depths are derived from where each tier should meet the girdle or the table
/// rather than solved from meetpoints — meetpoint solving is the geometry
/// kernel's job (ticket 02), not this spike's. The proportions below land within
/// a percent or two of a real SRB, which is all the renderer needs.
func standardRoundBrilliant() -> Design {
    let gt: Float = 0.03            // girdle half-thickness
    let crownHeight: Float = 0.324  // 16.2% of girdle diameter

    func d(angleDeg: Float, throughRadius r: Float, atZ z: Float, crown: Bool) -> Float {
        let a = angleDeg * .pi / 180
        return sin(a) * r + (crown ? 1 : -1) * cos(a) * z
    }

    let pavAngle: Float = 40.75
    let lgfAngle: Float = 41.90
    let kiteAngle: Float = 34.50
    let ugfAngle: Float = 42.50
    let starAngle: Float = 15.00

    // Table octagon: vertices at the kite azimuths, edges facing the stars.
    let ka = kiteAngle * .pi / 180
    let tableCircumradius = (d(angleDeg: kiteAngle, throughRadius: 1, atZ: gt, crown: true)
                             - crownHeight * cos(ka)) / sin(ka)
    let tableInradius = tableCircumradius * cos(.pi / 8)
    let sa = starAngle * .pi / 180
    let starDepth = sin(sa) * tableInradius + cos(sa) * crownHeight

    let mains = stride(from: 0, to: 96, by: 12).map { $0 }        // 8
    let stars = stride(from: 6, to: 96, by: 12).map { $0 }        // 8
    let halves = stride(from: 3, to: 96, by: 6).map { $0 }        // 16
    let girdle = stride(from: 0, to: 96, by: 3).map { $0 }        // 32

    return Design(name: "Standard Round Brilliant (57)", wheel: 96, tiers: [
        Tier(angle: pavAngle, indices: mains, crown: false,
             depth: d(angleDeg: pavAngle, throughRadius: 1, atZ: -gt, crown: false),
             name: "pavilion mains"),
        Tier(angle: lgfAngle, indices: halves, crown: false,
             depth: d(angleDeg: lgfAngle, throughRadius: 1, atZ: -gt, crown: false),
             name: "lower girdle halves"),
        Tier(angle: 90, indices: girdle, crown: true, depth: 1.0, name: "girdle"),
        Tier(angle: kiteAngle, indices: mains, crown: true,
             depth: d(angleDeg: kiteAngle, throughRadius: 1, atZ: gt, crown: true),
             name: "kites"),
        Tier(angle: ugfAngle, indices: halves, crown: true,
             depth: d(angleDeg: ugfAngle, throughRadius: 1, atZ: gt, crown: true),
             name: "upper girdle halves"),
        Tier(angle: starAngle, indices: stars, crown: true, depth: starDepth, name: "stars"),
        Tier(angle: 0, indices: [0], crown: true, depth: crownHeight, name: "table"),
    ])
}

/// An emerald cut — a second design shape, to check the renderer isn't tuned to
/// one polyhedron. Step cut, rectangular outline, 8 corners.
func emeraldCut() -> Design {
    // Outline: 4 sides + 4 corners, as vertical planes at differing depths.
    var tiers: [Tier] = []
    let side: Float = 0.72
    let end: Float = 1.0
    // wheel 96: 0/48 = ends, 24/72 = sides, corners at 12/36/60/84
    tiers.append(Tier(angle: 90, indices: [0, 48], crown: true, depth: end, name: "outline ends"))
    tiers.append(Tier(angle: 90, indices: [24, 72], crown: true, depth: side, name: "outline sides"))
    tiers.append(Tier(angle: 90, indices: [12, 36, 60, 84], crown: true, depth: 0.80, name: "corners"))

    let corners = [12, 36, 60, 84]
    let sides = [0, 24, 48, 72]
    // Crown: three steps
    tiers.append(Tier(angle: 45, indices: sides + corners, crown: true, depth: 0.62, name: "crown step 1"))
    tiers.append(Tier(angle: 30, indices: sides + corners, crown: true, depth: 0.50, name: "crown step 2"))
    tiers.append(Tier(angle: 0, indices: [0], crown: true, depth: 0.22, name: "table"))
    // Pavilion: three steps down to a keel
    tiers.append(Tier(angle: 43, indices: sides + corners, crown: false, depth: 0.66, name: "pav step 1"))
    tiers.append(Tier(angle: 50, indices: sides + corners, crown: false, depth: 0.78, name: "pav step 2"))
    tiers.append(Tier(angle: 58, indices: sides + corners, crown: false, depth: 0.86, name: "pav step 3"))
    return Design(name: "Emerald Cut (step)", wheel: 96, tiers: tiers)
}

// MARK: - Materials

/// Cauchy dispersion: n(λ) = A + B/λ²  (λ in µm).
/// B is fitted from the material's published dispersion (n_F − n_C).
struct Material {
    var name: String
    var nD: Float             // RI at the sodium D line, 589.3nm
    var dispersion: Float     // n_F − n_C  (486.1nm − 656.3nm)
    /// Absorption coefficient per unit length at ~610/550/465nm. Zero = colourless.
    var absorb: SIMD3<Float>

    var cauchy: (a: Float, b: Float) {
        let inv: Float = 1 / (0.4861 * 0.4861) - 1 / (0.6563 * 0.6563)   // 1.9105
        let b = dispersion / inv
        let a = nD - b / (0.5893 * 0.5893)
        return (a, b)
    }

    var criticalAngleDeg: Float { asin(1 / nD) * 180 / .pi }
}

let materials: [String: Material] = [
    // Amethyst: light purple — absorbs green strongly, red/blue weakly.
    "quartz":   Material(name: "Amethyst (quartz)", nD: 1.544, dispersion: 0.013,
                         absorb: SIMD3(0.30, 0.88, 0.22)),
    "topaz":    Material(name: "Blue topaz",        nD: 1.620, dispersion: 0.014,
                         absorb: SIMD3(0.85, 0.35, 0.07)),
    "corundum": Material(name: "Sapphire",          nD: 1.762, dispersion: 0.018,
                         absorb: SIMD3(1.15, 0.60, 0.10)),
    "cz":       Material(name: "Cubic zirconia",    nD: 2.160, dispersion: 0.060,
                         absorb: SIMD3(0.02, 0.02, 0.02)),
    "glass":    Material(name: "Colourless quartz", nD: 1.544, dispersion: 0.013,
                         absorb: SIMD3(0.02, 0.02, 0.02)),
    "diamond":  Material(name: "Diamond",           nD: 2.417, dispersion: 0.044,
                         absorb: SIMD3(0.01, 0.01, 0.01)),
]
