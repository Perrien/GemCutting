// PROTOTYPE — throwaway.
import Foundation
import Metal
import simd
import ImageIO
import CoreGraphics
import UniformTypeIdentifiers

struct GPUPlane { var nx: Float; var ny: Float; var nz: Float; var d: Float
                  var roughMul: Float = 1; var scatterMul: Float = 1 }

/// Mirrors `Params` in shaders.metal byte for byte (all members align 4, total 128B).
struct GPUParams {
    var eyeX: Float = 0, eyeY: Float = 0, eyeZ: Float = 0
    var tanHalfFov: Float = 0
    var rX: Float = 0, rY: Float = 0, rZ: Float = 0
    var _p0: Float = 0
    var uX: Float = 0, uY: Float = 0, uZ: Float = 0
    var _p1: Float = 0
    var fX: Float = 0, fY: Float = 0, fZ: Float = 0
    var _p2: Float = 0
    var aR: Float = 0, aG: Float = 0, aB: Float = 0
    var envIntensity: Float = 1
    var width: UInt32 = 0
    var height: UInt32 = 0
    var planeCount: UInt32 = 0
    var spp: UInt32 = 1
    var frameIndex: UInt32 = 0
    var wavelengthBins: UInt32 = 0
    var maxBounces: UInt32 = 12
    var envMode: UInt32 = 0
    var riA: Float = 0
    var riB: Float = 0
    var exposure: Float = 1
    var roughness: Float = 0
    var scatter: Float = 0
    var edgeSoften: Float = 0
    var scatterAlbedo: Float = 0.55
    var _p4: Float = 0
}

struct Camera {
    var target = SIMD3<Float>(0, 0, -0.22)
    var distance: Float = 6.8
    var azimuth: Float = 0.6         // radians
    var elevation: Float = 0.95      // radians above the girdle plane
    var fovDeg: Float = 26

    var eye: SIMD3<Float> {
        let ce = cos(elevation), se = sin(elevation)
        return target + distance * SIMD3(ce * cos(azimuth), ce * sin(azimuth), se)
    }
    /// (right, up, fwd)
    var basis: (SIMD3<Float>, SIMD3<Float>, SIMD3<Float>) {
        let fwd = normalize(target - eye)
        let worldUp = SIMD3<Float>(0, 0, 1)
        let right = normalize(cross(fwd, worldUp))
        let up = cross(right, fwd)
        return (right, up, fwd)
    }
}

struct RenderConfig {
    var width = 900
    var height = 900
    var spp = 512
    var wavelengthBins: UInt32 = 0      // 0 = continuous spectrum
    var maxBounces: UInt32 = 14
    var envMode: UInt32 = 0
    var exposure: Float = 1.0
    var envIntensity: Float = 1.0
    var material = materials["quartz"]!
    var finish = Finish.polished
    var design = standardRoundBrilliant()
    var camera = Camera()
}

final class Renderer {
    let device: MTLDevice
    let queue: MTLCommandQueue
    let tracePSO: MTLComputePipelineState
    let resolvePSO: MTLComputePipelineState

    private var accum: MTLTexture!
    private var output: MTLTexture!
    private var planeBuf: MTLBuffer!
    private var planeCount: UInt32 = 0
    private(set) var accumulated: UInt32 = 0
    private var w = 0, h = 0

    init() throws {
        guard let dev = MTLCreateSystemDefaultDevice() else {
            throw Err("no Metal device")
        }
        device = dev
        queue = dev.makeCommandQueue()!

        guard let url = Bundle.module.url(forResource: "shaders", withExtension: "metal") else {
            throw Err("shaders.metal missing from bundle")
        }
        let src = try String(contentsOf: url, encoding: .utf8)
        let opts = MTLCompileOptions()
        opts.mathMode = .fast
        let lib = try dev.makeLibrary(source: src, options: opts)
        tracePSO = try dev.makeComputePipelineState(function: lib.makeFunction(name: "trace")!)
        resolvePSO = try dev.makeComputePipelineState(function: lib.makeFunction(name: "resolve")!)
    }

    struct Err: Error, CustomStringConvertible {
        let description: String
        init(_ d: String) { description = d }
    }

    func resize(_ width: Int, _ height: Int) {
        guard width != w || height != h else { return }
        w = width; h = height
        let d = MTLTextureDescriptor()
        d.textureType = .type2D
        d.pixelFormat = .rgba32Float
        d.width = width; d.height = height
        d.usage = [.shaderRead, .shaderWrite]
        d.storageMode = .shared
        accum = device.makeTexture(descriptor: d)!
        let o = MTLTextureDescriptor()
        o.textureType = .type2D
        o.pixelFormat = .rgba8Unorm
        o.width = width; o.height = height
        o.usage = [.shaderRead, .shaderWrite]
        o.storageMode = .shared
        output = device.makeTexture(descriptor: o)!
        reset()
    }

    func setDesign(_ design: Design) {
        let planes = design.planes.map {
            GPUPlane(nx: $0.n.x, ny: $0.n.y, nz: $0.n.z, d: $0.d,
                     roughMul: $0.roughMul, scatterMul: $0.scatterMul)
        }
        planeCount = UInt32(planes.count)
        planeBuf = device.makeBuffer(bytes: planes,
                                     length: planes.count * MemoryLayout<GPUPlane>.stride,
                                     options: .storageModeShared)
    }

    func reset() {
        accumulated = 0
        guard let accum else { return }
        let bytes = [Float](repeating: 0, count: w * h * 4)
        accum.replace(region: MTLRegionMake2D(0, 0, w, h), mipmapLevel: 0,
                      withBytes: bytes, bytesPerRow: w * 16)
    }

    private func params(_ c: RenderConfig, spp: UInt32) -> GPUParams {
        var p = GPUParams()
        let e = c.camera.eye
        let (r, u, f) = c.camera.basis
        p.eyeX = e.x; p.eyeY = e.y; p.eyeZ = e.z
        p.rX = r.x; p.rY = r.y; p.rZ = r.z
        p.uX = u.x; p.uY = u.y; p.uZ = u.z
        p.fX = f.x; p.fY = f.y; p.fZ = f.z
        p.tanHalfFov = tan(c.camera.fovDeg * .pi / 360)
        let ab = c.material.absorb
        p.aR = ab.x; p.aG = ab.y; p.aB = ab.z
        p.envIntensity = c.envIntensity
        p.width = UInt32(w); p.height = UInt32(h)
        p.planeCount = planeCount
        p.spp = spp
        p.frameIndex = accumulated
        p.wavelengthBins = c.wavelengthBins
        p.maxBounces = c.maxBounces
        p.envMode = c.envMode
        let (a, b) = c.material.cauchy
        p.riA = a; p.riB = b
        p.exposure = c.exposure
        p.roughness = c.finish.roughness
        p.scatter = c.finish.scatter
        p.edgeSoften = c.finish.edgeSoften
        p.scatterAlbedo = c.finish.scatterAlbedo
        return p
    }

    /// Adds `spp` samples per pixel to the accumulator. Returns GPU time in seconds.
    @discardableResult
    func accumulate(_ c: RenderConfig, spp: UInt32) -> Double {
        var p = params(c, spp: spp)
        let cb = queue.makeCommandBuffer()!
        let enc = cb.makeComputeCommandEncoder()!
        enc.setComputePipelineState(tracePSO)
        enc.setTexture(accum, index: 0)
        enc.setBuffer(planeBuf, offset: 0, index: 0)
        enc.setBytes(&p, length: MemoryLayout<GPUParams>.stride, index: 1)
        let tg = MTLSize(width: 8, height: 8, depth: 1)
        enc.dispatchThreadgroups(
            MTLSize(width: (w + 7) / 8, height: (h + 7) / 8, depth: 1),
            threadsPerThreadgroup: tg)
        enc.endEncoding()
        let t0 = DispatchTime.now().uptimeNanoseconds
        cb.commit()
        cb.waitUntilCompleted()
        let dt = Double(DispatchTime.now().uptimeNanoseconds - t0) / 1e9
        accumulated += spp
        return dt
    }

    func resolveToTexture(_ c: RenderConfig) -> MTLTexture {
        var p = params(c, spp: 0)
        let cb = queue.makeCommandBuffer()!
        let enc = cb.makeComputeCommandEncoder()!
        enc.setComputePipelineState(resolvePSO)
        enc.setTexture(accum, index: 0)
        enc.setTexture(output, index: 1)
        enc.setBytes(&p, length: MemoryLayout<GPUParams>.stride, index: 1)
        enc.dispatchThreadgroups(
            MTLSize(width: (w + 7) / 8, height: (h + 7) / 8, depth: 1),
            threadsPerThreadgroup: MTLSize(width: 8, height: 8, depth: 1))
        enc.endEncoding()
        cb.commit()
        cb.waitUntilCompleted()
        return output
    }

    /// Tonemap the accumulator straight into someone else's texture (the drawable).
    func resolve(_ c: RenderConfig, into dest: MTLTexture) {
        var p = params(c, spp: 0)
        let cb = queue.makeCommandBuffer()!
        let enc = cb.makeComputeCommandEncoder()!
        enc.setComputePipelineState(resolvePSO)
        enc.setTexture(accum, index: 0)
        enc.setTexture(dest, index: 1)
        enc.setBytes(&p, length: MemoryLayout<GPUParams>.stride, index: 1)
        enc.dispatchThreadgroups(
            MTLSize(width: (w + 7) / 8, height: (h + 7) / 8, depth: 1),
            threadsPerThreadgroup: MTLSize(width: 8, height: 8, depth: 1))
        enc.endEncoding()
        cb.commit()
        cb.waitUntilCompleted()
    }

    func render(_ c: RenderConfig, chunk: UInt32 = 32) -> MTLTexture {
        resize(c.width, c.height)
        setDesign(c.design)
        reset()
        var remaining = UInt32(c.spp)
        while remaining > 0 {
            let n = min(chunk, remaining)
            accumulate(c, spp: n)
            remaining -= n
        }
        return resolveToTexture(c)
    }

    func writePNG(_ tex: MTLTexture, to path: String) throws {
        let bpr = tex.width * 4
        var bytes = [UInt8](repeating: 0, count: bpr * tex.height)
        tex.getBytes(&bytes, bytesPerRow: bpr,
                     from: MTLRegionMake2D(0, 0, tex.width, tex.height), mipmapLevel: 0)
        let cs = CGColorSpaceCreateDeviceRGB()
        let provider = CGDataProvider(data: Data(bytes) as CFData)!
        let img = CGImage(width: tex.width, height: tex.height,
                          bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: bpr,
                          space: cs, bitmapInfo: CGBitmapInfo(rawValue:
                            CGImageAlphaInfo.noneSkipLast.rawValue),
                          provider: provider, decode: nil, shouldInterpolate: false,
                          intent: .defaultIntent)!
        let url = URL(fileURLWithPath: path)
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        guard let dest = CGImageDestinationCreateWithURL(
            url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            throw Err("cannot create \(path)")
        }
        CGImageDestinationAddImage(dest, img, nil)
        guard CGImageDestinationFinalize(dest) else { throw Err("png write failed") }
    }
}
