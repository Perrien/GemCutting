// PROTOTYPE — throwaway. Entry point.
import Foundation
import simd

let out = "renders"

func run() throws {
    let args = Array(CommandLine.arguments.dropFirst())
    let mode = args.first ?? "sheet"
    let r = try Renderer()
    print("device: \(r.device.name)")

    switch mode {
    case "still":
        var c = RenderConfig()
        c.spp = 1024
        let t0 = Date()
        let tex = r.render(c)
        try r.writePNG(tex, to: "\(out)/still.png")
        print("still.png  \(c.spp)spp in \(String(format: "%.2f", -t0.timeIntervalSinceNow))s")

    case "quad":
        // Fast iteration loop: four representative looks at low spp.
        var jobs: [(String, RenderConfig)] = []
        var a = RenderConfig(); a.material = materials["quartz"]!
        var b = RenderConfig(); b.material = materials["cz"]!
        var c2 = RenderConfig(); c2.material = materials["cz"]!; c2.envMode = 3
        var d = RenderConfig(); d.material = materials["corundum"]!; d.design = emeraldCut()
        for (n, var cfg) in [("q-amethyst", a), ("q-cz", b), ("q-cz-bench", c2),
                             ("q-sapphire-emerald", d)] {
            cfg.width = 700; cfg.height = 700; cfg.spp = 400
            jobs.append((n, cfg))
        }
        for (name, cfg) in jobs {
            let tex = r.render(cfg)
            try r.writePNG(tex, to: "\(out)/\(name).png")
            print("  \(name)")
        }

    case "fire":
        // Colourless RI ladder: isolates refractive index + dispersion from body
        // colour, which is what confounds the material-progression comparison.
        for (env, ename) in [(UInt32(0), "studio"), (UInt32(3), "bench")] {
            for key in ["glass", "corundum-clear", "cz", "diamond"] {
                var c = RenderConfig()
                c.envMode = env
                c.spp = 900
                if key == "corundum-clear" {
                    var m = materials["corundum"]!
                    m.absorb = SIMD3(0.02, 0.02, 0.02)
                    m.name = "Colourless sapphire"
                    c.material = m
                } else {
                    c.material = materials[key]!
                }
                let tex = r.render(c)
                try r.writePNG(tex, to: "\(out)/fire-\(ename)-\(key).png")
                print("  fire-\(ename)-\(key)  n=\(c.material.nD) disp=\(c.material.dispersion)")
            }
        }

    case "finish":
        // The coarse -> fine -> polish ladder, and stones caught mid-cut.
        for f in Finish.ladder {
            var c = RenderConfig()
            c.material = materials["quartz"]!
            c.finish = f
            c.envMode = 3
            c.spp = 1400
            let slug = f.name.replacingOccurrences(of: " ", with: "-")
                .replacingOccurrences(of: "(", with: "").replacingOccurrences(of: ")", with: "")
            let t0 = Date()
            let tex = r.render(c)
            try r.writePNG(tex, to: "\(out)/finish-\(slug).png")
            print("  finish-\(slug)  rough \(f.roughness) scatter \(f.scatter)"
                  + "  \(String(format: "%.1f", -t0.timeIntervalSinceNow))s")
        }
        // Partial cuts: pavilion done, crown still rough; and alternating facets.
        let partials: [(String, Design)] = [
            ("pavilion-polished", standardRoundBrilliant()
                .withPolishedTiers(["pavilion mains", "lower girdle halves"])),
            ("crown-polished", standardRoundBrilliant()
                .withPolishedTiers(["kites", "stars", "table", "upper girdle halves"])),
            ("alternating-facets", standardRoundBrilliant().withAlternatingFacetsPolished()),
        ]
        for (slug, design) in partials {
            var c = RenderConfig()
            c.material = materials["quartz"]!
            c.design = design
            c.finish = .midCut
            c.envMode = 3
            c.spp = 1400
            let tex = r.render(c)
            try r.writePNG(tex, to: "\(out)/partial-\(slug).png")
            print("  partial-\(slug)")
        }

    case "fdiag":
        print("GPUParams stride \(MemoryLayout<GPUParams>.stride), GPUPlane stride \(MemoryLayout<GPUPlane>.stride)")
        var combos: [(String, Finish)] = [
            ("base",      Finish(name: "b", roughness: 0,    scatter: 0,   edgeSoften: 0)),
            ("roughOnly", Finish(name: "r", roughness: 0.32, scatter: 0,   edgeSoften: 0)),
            ("scatOnly",  Finish(name: "s", roughness: 0,    scatter: 0.4, edgeSoften: 0)),
        ]
        for w in [Float(0.0004), 0.0010, 0.0022, 0.0050] {
            combos.append(("edge-\(w)", Finish(name: "e", roughness: 0, scatter: 0, edgeSoften: w)))
        }
        for (n, f) in combos {
            var c = RenderConfig()
            c.material = materials["quartz"]!
            c.finish = f; c.envMode = 3; c.spp = 300
            c.width = 600; c.height = 600
            let tex = r.render(c)
            try r.writePNG(tex, to: "\(out)/fdiag-\(n).png")
            print("  fdiag-\(n)")
        }

    case "frost":
        // Roughness (blurs transmission -> frosted but still translucent) against
        // scatter (diffuse pits -> chalky and opaque). Finding the balance is the
        // whole question for a part-cut stone.
        for rough in [Float(0.15), 0.30, 0.50] {
            for scat in [Float(0.05), 0.15, 0.35] {
                var c = RenderConfig()
                c.material = materials["quartz"]!
                c.finish = Finish(name: "m", roughness: rough, scatter: scat, edgeSoften: 0.0009)
                c.envMode = 3
                c.width = 620; c.height = 620; c.spp = 900
                let tex = r.render(c)
                try r.writePNG(tex, to: "\(out)/frost-r\(rough)-s\(scat).png")
                print("  frost r=\(rough) s=\(scat)")
            }
        }

    case "sheet":
        try renderSheet(r)

    case "bench":
        try bench(r)

    case "window":
        runWindow(r)

    default:
        print("usage: gemspike [sheet|still|bench|window]")
    }
}

// MARK: - Render sheet: the variants the ticket asks to compare

func renderSheet(_ r: Renderer) throws {
    var jobs: [(String, RenderConfig)] = []

    // 1. Material progression — does high RI look visibly different from low?
    for key in ["quartz", "topaz", "corundum", "cz", "diamond"] {
        var c = RenderConfig()
        c.material = materials[key]!
        c.spp = 900
        jobs.append(("material-\(key)", c))
    }

    // 2. Wavelength bins — where does dispersion stop being colour noise?
    for bins in [1, 3, 8, 24, 0] as [UInt32] {
        var c = RenderConfig()
        c.material = materials["cz"]!      // highest dispersion: worst case
        c.wavelengthBins = bins
        c.spp = 900
        jobs.append(("bins-\(bins == 0 ? 999 : Int(bins))", c))
    }

    // 3. Lighting environment — what sells it?
    for (i, name) in ["studio", "lamp", "softbox", "bench"].enumerated() {
        var c = RenderConfig()
        c.envMode = UInt32(i)
        c.material = materials["cz"]!
        c.spp = 900
        jobs.append(("env-\(name)", c))
    }

    // 4. Sample-count ladder — how long until it's clean?
    for spp in [8, 32, 128, 512, 2048] {
        var c = RenderConfig()
        c.spp = spp
        c.material = materials["cz"]!
        jobs.append(("spp-\(spp)", c))
    }

    // 5. Bounce depth — is TIR really bounded?
    for b in [1, 2, 4, 8, 16, 32] as [UInt32] {
        var c = RenderConfig()
        c.maxBounces = b
        c.material = materials["cz"]!
        c.spp = 900
        jobs.append(("bounces-\(b)", c))
    }

    // 6. A second design, to check nothing is tuned to the brilliant.
    var em = RenderConfig()
    em.design = emeraldCut()
    em.material = materials["corundum"]!
    em.spp = 900
    jobs.append(("design-emerald", em))

    // 7. Viewing angles.
    for (name, el, az) in [("face-up", Float(1.35), Float(0.6)),
                           ("tilted", Float(0.30), Float(0.9)),
                           ("profile", Float(0.05), Float(0.2))] {
        var c = RenderConfig()
        c.camera.elevation = el
        c.camera.azimuth = az
        c.material = materials["cz"]!
        c.spp = 900
        jobs.append(("view-\(name)", c))
    }

    for (name, c) in jobs {
        let t0 = Date()
        let tex = r.render(c)
        try r.writePNG(tex, to: "\(out)/\(name).png")
        print(String(format: "%-20s %5dspp  %6.2fs", (name as NSString).utf8String!,
                     c.spp, -t0.timeIntervalSinceNow))
    }
}

// MARK: - Bench

func bench(_ r: Renderer) throws {
    print("\n--- frame-rate budget (single stone, progressive accumulation) ---")
    for (w, h, label) in [(900, 900, "900²  (inset viewport)"),
                          (1440, 1440, "1440² (retina inset)"),
                          (2560, 1440, "2560×1440 (full window)")] {
        var c = RenderConfig()
        c.width = w; c.height = h
        c.material = materials["cz"]!
        r.resize(w, h)
        r.setDesign(c.design)
        r.reset()
        _ = r.accumulate(c, spp: 1)                       // warm up
        r.reset()
        var total = 0.0
        let iters = 12
        for _ in 0..<iters { total += r.accumulate(c, spp: 1) }
        let per = total / Double(iters)
        print(String(format: "%-26s  1spp = %6.1f ms  -> %5.1f fps   (%d planes, %d bounces)",
                     (label as NSString).utf8String!, per * 1000, 1 / per,
                     c.design.planes.count, Int(c.maxBounces)))
    }

    print("\n--- time to a clean still (900², CZ, continuous spectrum) ---")
    var c = RenderConfig()
    c.width = 900; c.height = 900
    c.material = materials["cz"]!
    r.resize(900, 900); r.setDesign(c.design); r.reset()
    var elapsed = 0.0
    var marks: Set<UInt32> = [16, 64, 256, 1024, 4096]
    var spp: UInt32 = 0
    while spp < 4096 {
        elapsed += r.accumulate(c, spp: 16)
        spp += 16
        if marks.contains(spp) {
            marks.remove(spp)
            print(String(format: "  %5d spp  %7.2f s", spp, elapsed))
        }
    }

    print("\n--- cost by material (RI drives bounce count), 900², 64spp ---")
    for key in ["quartz", "corundum", "cz", "diamond"] {
        var c = RenderConfig()
        c.width = 900; c.height = 900
        c.material = materials[key]!
        r.resize(900, 900); r.setDesign(c.design); r.reset()
        _ = r.accumulate(c, spp: 8)
        r.reset()
        var t = 0.0
        for _ in 0..<4 { t += r.accumulate(c, spp: 16) }
        print(String(format: "  %-22s n=%.3f  crit=%.1f deg  %6.2f s / 64spp",
                     (c.material.name as NSString).utf8String!, c.material.nD,
                     c.material.criticalAngleDeg, t))
    }

    print("\n--- cost by wavelength bins (900², CZ, 64spp) ---")
    for bins in [1, 3, 8, 24, 0] as [UInt32] {
        var c = RenderConfig()
        c.width = 900; c.height = 900
        c.material = materials["cz"]!
        c.wavelengthBins = bins
        r.resize(900, 900); r.setDesign(c.design); r.reset()
        _ = r.accumulate(c, spp: 8)
        r.reset()
        var t = 0.0
        for _ in 0..<4 { t += r.accumulate(c, spp: 16) }
        print(String(format: "  bins=%-4d %6.2f s / 64spp", bins == 0 ? 999 : Int(bins), t))
    }
}

do { try run() } catch { print("error: \(error)"); exit(1) }
