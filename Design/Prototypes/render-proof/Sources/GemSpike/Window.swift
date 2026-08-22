// PROTOTYPE — throwaway. Interactive window: a gem is judged in motion, so the
// user needs to spin it, not just look at stills.
import Foundation
import AppKit
import MetalKit

final class GemView: MTKView {
    let renderer: Renderer
    var config = RenderConfig()
    var hud: NSTextField!
    var lastDrag: NSPoint?
    var isFrozen = false
    var sppPerFrame: UInt32 = 1
    var frameMS = 0.0

    private let materialOrder = ["quartz", "topaz", "corundum", "cz", "diamond", "glass"]
    private var materialIdx = 0
    private var binOptions: [UInt32] = [0, 1, 3, 8, 24]
    private var binIdx = 0
    private var finishIdx = 0
    private var partialIdx = 0
    private let partialNames = ["all facets same finish", "pavilion polished",
                                "crown polished", "alternating facets polished"]

    private func applyPartial() {
        let base = config.design.name.hasPrefix("Emerald") ? emeraldCut() : standardRoundBrilliant()
        switch partialIdx {
        case 1: config.design = base.withPolishedTiers(["pavilion mains", "lower girdle halves"])
        case 2: config.design = base.withPolishedTiers(["kites", "stars", "table", "upper girdle halves"])
        case 3: config.design = base.withAlternatingFacetsPolished()
        default: config.design = base
        }
        renderer.setDesign(config.design)
        renderer.reset()
    }

    init(renderer: Renderer) {
        self.renderer = renderer
        super.init(frame: NSRect(x: 0, y: 0, width: 1100, height: 800), device: renderer.device)
        colorPixelFormat = .rgba8Unorm
        framebufferOnly = false
        isPaused = false
        enableSetNeedsDisplay = false
        preferredFramesPerSecond = 60
        config.material = materials[materialOrder[0]]!
        config.spp = 1
    }
    required init(coder: NSCoder) { fatalError() }

    override var acceptsFirstResponder: Bool { true }

    override func mouseDown(with e: NSEvent) { lastDrag = e.locationInWindow }
    override func mouseDragged(with e: NSEvent) {
        guard let l = lastDrag else { return }
        let p = e.locationInWindow
        config.camera.azimuth -= Float(p.x - l.x) * 0.008
        config.camera.elevation = max(-1.45, min(1.45,
            config.camera.elevation + Float(p.y - l.y) * 0.008))
        lastDrag = p
        renderer.reset()
    }
    override func mouseUp(with e: NSEvent) { lastDrag = nil }
    override func scrollWheel(with e: NSEvent) {
        config.camera.distance = max(1.9, min(12, config.camera.distance
                                              - Float(e.scrollingDeltaY) * 0.03))
        renderer.reset()
    }

    override func keyDown(with e: NSEvent) {
        switch e.charactersIgnoringModifiers ?? "" {
        case "m":
            materialIdx = (materialIdx + 1) % materialOrder.count
            config.material = materials[materialOrder[materialIdx]]!
            renderer.reset()
        case "e":
            config.envMode = (config.envMode + 1) % 4
            renderer.reset()
        case "w":
            binIdx = (binIdx + 1) % binOptions.count
            config.wavelengthBins = binOptions[binIdx]
            renderer.reset()
        case "d":
            config.design = config.design.name.hasPrefix("Standard")
                ? emeraldCut() : standardRoundBrilliant()
            renderer.setDesign(config.design)
            renderer.reset()
        case "b":
            config.maxBounces = config.maxBounces >= 32 ? 1 : config.maxBounces * 2
            renderer.reset()
        case "f":
            finishIdx = (finishIdx + 1) % Finish.ladder.count
            config.finish = Finish.ladder[finishIdx]
            renderer.reset()
        case "p":
            partialIdx = (partialIdx + 1) % partialNames.count
            applyPartial()
        case "1": config.finish.roughness = max(0, config.finish.roughness - 0.02); renderer.reset()
        case "2": config.finish.roughness = min(1, config.finish.roughness + 0.02); renderer.reset()
        case "3": config.finish.scatter = max(0, config.finish.scatter - 0.02); renderer.reset()
        case "4": config.finish.scatter = min(1, config.finish.scatter + 0.02); renderer.reset()
        case "5": config.finish.edgeSoften = max(0, config.finish.edgeSoften - 0.0002); renderer.reset()
        case "6": config.finish.edgeSoften = min(0.004, config.finish.edgeSoften + 0.0002); renderer.reset()
        case "[": config.exposure = max(0.1, config.exposure / 1.25); renderer.reset()
        case "]": config.exposure *= 1.25; renderer.reset()
        case "+", "=": sppPerFrame = min(64, sppPerFrame * 2)
        case "-": sppPerFrame = max(1, sppPerFrame / 2)
        case " ": isFrozen.toggle()
        case "r": renderer.reset()
        case "s":
            let tex = renderer.resolveToTexture(config)
            let name = "renders/grab-\(config.material.name.replacingOccurrences(of: " ", with: "_"))-\(renderer.accumulated)spp.png"
            try? renderer.writePNG(tex, to: name)
            print("saved \(name)")
        case "q": NSApp.terminate(nil)
        default: break
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let drawable = currentDrawable else { return }
        let w = drawable.texture.width, h = drawable.texture.height
        config.width = w; config.height = h
        renderer.resize(w, h)
        if renderer.accumulated == 0 { renderer.setDesign(config.design) }

        if !isFrozen {
            frameMS = renderer.accumulate(config, spp: sppPerFrame) * 1000
        }
        renderer.resolve(config, into: drawable.texture)
        let cb = renderer.queue.makeCommandBuffer()!
        cb.present(drawable)
        cb.commit()

        hud.stringValue = String(format:
            "%@   n=%.3f (crit %.1f°)   env=%@   λbins=%@   bounces=%d   exp=%.2f\n"
            + "finish: %@   rough %.2f [1/2]   scatter %.2f [3/4]   edge %.4f [5/6]   %@ [p]\n"
            + "%d×%d   %d spp   %d spp/frame   %.1f ms/frame (%.0f fps)\n"
            + "drag orbit · scroll zoom · [m]aterial [e]nv [w]avelength [d]esign [f]inish [b]ounces [ ][ ] exposure +/- spp [s]ave [r]eset [q]uit",
            config.material.name, config.material.nD, config.material.criticalAngleDeg,
            ["studio", "jeweller's lamp", "softbox", "bench rig"][Int(config.envMode)],
            config.wavelengthBins == 0 ? "continuous" : "\(config.wavelengthBins)",
            config.maxBounces, config.exposure,
            config.finish.name, config.finish.roughness, config.finish.scatter,
            config.finish.edgeSoften, partialNames[partialIdx],
            w, h, renderer.accumulated, sppPerFrame, frameMS,
            frameMS > 0 ? 1000 / frameMS : 0)
    }
}

func runWindow(_ r: Renderer) {
    let app = NSApplication.shared
    app.setActivationPolicy(.regular)

    let view = GemView(renderer: r)
    let win = NSWindow(contentRect: view.frame,
                       styleMask: [.titled, .closable, .resizable, .miniaturizable],
                       backing: .buffered, defer: false)
    win.title = "GemSpike — render proof (PROTOTYPE)"
    win.contentView = view

    let hud = NSTextField(labelWithString: "")
    hud.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
    hud.textColor = .white
    hud.maximumNumberOfLines = 4
    hud.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(hud)
    NSLayoutConstraint.activate([
        hud.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
        hud.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -10),
        hud.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -12),
    ])
    view.hud = hud

    win.makeKeyAndOrderFront(nil)
    win.makeFirstResponder(view)
    app.activate(ignoringOtherApps: true)
    app.run()
}
