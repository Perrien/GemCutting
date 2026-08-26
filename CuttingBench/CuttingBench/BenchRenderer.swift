import AppKit
import BenchGeometry
import Metal
import MetalKit
import simd

/// **Field-for-field identical to `Uniforms` in `Shaders.metal`.** This is the side that carries the
/// comment saying so: change one and change the other.
struct Uniforms {
  var viewProjection: simd_float4x4
  var view: simd_float4x4
  var cutColor: SIMD4<Float>
  var roughColor: SIMD4<Float>
  var edgeColor: SIMD4<Float>
  var highlightColor: SIMD4<Float>
  /// `xyz`: the camera position in world space. `w` unused.
  var eye: SIMD4<Float>
  /// `x`: opacity. `y`: this pass's facing sign, `+1` near or `-1` far. `z`: the highlighted plane
  /// index, or `-1`. `w`: this edge pass's alpha.
  var params: SIMD4<Float>
}

/// Draws the bench solid: flat per-facet fill from each plane's own normal, on whatever camera the view
/// last set. Nothing here builds geometry — the mesh arrives through `setMesh` (D13).
final class BenchRenderer: NSObject, MTKViewDelegate {
  let device: MTLDevice

  /// Where the camera is. The view sets it before asking for a redraw (D1).
  var camera: BenchCameraState = .threeQuarter
  /// How opaque the solid is, `0...1`. The view sets it before asking for a redraw (D6).
  var opacity: Double = 1
  /// The picked facet's plane index, or `nil` for no selection (D12).
  var highlightedPlaneIndex: Int?
  /// How strongly the finished stone's wireframe shows while a meet is being picked. A build constant
  /// and not a preference.
  static let ghostEdgeAlpha: Float = 0.35

  private let commandQueue: MTLCommandQueue
  private let fillPipeline: MTLRenderPipelineState
  private let edgePipeline: MTLRenderPipelineState
  private let depthTestNoWrite: MTLDepthStencilState
  private let depthTestWrite: MTLDepthStencilState
  private let depthAlways: MTLDepthStencilState

  private var triangleBuffer: MTLBuffer?
  private var triangleCount = 0
  private var edgeBuffer: MTLBuffer?
  private var edgeCount = 0
  /// The finished stone's edges, drawn over the solid while a meet is being picked.
  private var ghostEdgeBuffer: MTLBuffer?
  private var ghostEdgeCount = 0

  init(view: MTKView) {
    // A Mac that cannot run Metal cannot run this OS, so neither of these is reachable and neither gets
    // a UI fallback.
    guard let device = MTLCreateSystemDefaultDevice() else {
      fatalError("This Mac has no Metal device")
    }
    guard let library = device.makeDefaultLibrary() else {
      fatalError("Shaders.metal is not compiled into the CuttingBench target")
    }
    guard let commandQueue = device.makeCommandQueue() else {
      fatalError("This Metal device gave no command queue")
    }

    self.device = device
    self.commandQueue = commandQueue

    // Two pipelines off one descriptor, differing only in their functions.
    let descriptor = MTLRenderPipelineDescriptor()
    descriptor.vertexDescriptor = BenchRenderer.vertexDescriptor()
    descriptor.colorAttachments[0].pixelFormat = view.colorPixelFormat
    descriptor.depthAttachmentPixelFormat = view.depthStencilPixelFormat

    // Both fill passes blend, which is what lets the far one show through the near one (D8). The edge
    // pipeline inherits this harmlessly: `.labelColor` is opaque, and blending an opaque source is a
    // no-op.
    descriptor.colorAttachments[0].isBlendingEnabled = true
    descriptor.colorAttachments[0].rgbBlendOperation = .add
    descriptor.colorAttachments[0].alphaBlendOperation = .add
    descriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
    descriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
    descriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
    descriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha

    descriptor.vertexFunction = library.makeFunction(name: "fill_vertex")
    descriptor.fragmentFunction = library.makeFunction(name: "fill_fragment")
    fillPipeline = try! device.makeRenderPipelineState(descriptor: descriptor)

    descriptor.vertexFunction = library.makeFunction(name: "edge_vertex")
    descriptor.fragmentFunction = library.makeFunction(name: "edge_fragment")
    edgePipeline = try! device.makeRenderPipelineState(descriptor: descriptor)

    // Three states, not one: the far fill pass tests without writing, the near one does both, and the
    // edges take one of each — depth off for the pass that draws the whole wireframe, depth on for the
    // pass that draws only what is visible (D8, D9). An edge still wins against the facet it lies on
    // by the epsilon in its own vertex function (D19) rather than by a bias whose semantics vary by
    // depth format.
    depthTestNoWrite = BenchRenderer.depthState(device, compare: .less, write: false)
    depthTestWrite = BenchRenderer.depthState(device, compare: .less, write: true)
    depthAlways = BenchRenderer.depthState(device, compare: .always, write: false)

    super.init()
  }

  /// Attribute offsets come from `MemoryLayout`, never from hand-counted bytes. `SolidMeshTests` pins
  /// the four numbers the shader's `VertexIn` depends on.
  private static func vertexDescriptor() -> MTLVertexDescriptor {
    let descriptor = MTLVertexDescriptor()

    descriptor.attributes[0].format = .float3
    descriptor.attributes[0].offset = MemoryLayout<MeshVertex>.offset(of: \.px)!
    descriptor.attributes[0].bufferIndex = 0

    descriptor.attributes[1].format = .float3
    descriptor.attributes[1].offset = MemoryLayout<MeshVertex>.offset(of: \.nx)!
    descriptor.attributes[1].bufferIndex = 0

    descriptor.attributes[2].format = .float
    descriptor.attributes[2].offset = MemoryLayout<MeshVertex>.offset(of: \.role)!
    descriptor.attributes[2].bufferIndex = 0

    descriptor.attributes[3].format = .float
    descriptor.attributes[3].offset = MemoryLayout<MeshVertex>.offset(of: \.planeIndex)!
    descriptor.attributes[3].bufferIndex = 0

    descriptor.layouts[0].stride = MemoryLayout<MeshVertex>.stride
    return descriptor
  }

  private static func depthState(
    _ device: MTLDevice, compare: MTLCompareFunction, write: Bool
  ) -> MTLDepthStencilState {
    let descriptor = MTLDepthStencilDescriptor()
    descriptor.depthCompareFunction = compare
    descriptor.isDepthWriteEnabled = write
    return device.makeDepthStencilState(descriptor: descriptor)!
  }

  // MARK: - Geometry

  func setMesh(_ mesh: SolidMesh) {
    triangleBuffer = makeBuffer(mesh.triangleVertices)
    triangleCount = mesh.triangleVertices.count
    edgeBuffer = makeBuffer(mesh.edgeVertices)
    edgeCount = mesh.edgeVertices.count
  }

  /// The finished stone, in **edges only** — the ghost is never filled. `nil` clears it.
  func setGhostMesh(_ mesh: SolidMesh?) {
    ghostEdgeBuffer = mesh.flatMap { makeBuffer($0.edgeVertices) }
    ghostEdgeCount = mesh?.edgeVertices.count ?? 0
  }

  /// An empty array makes no buffer; the draw skips it.
  private func makeBuffer(_ vertices: [MeshVertex]) -> MTLBuffer? {
    guard !vertices.isEmpty else { return nil }
    return vertices.withUnsafeBytes { bytes in
      guard let base = bytes.baseAddress else { return nil }
      return device.makeBuffer(bytes: base, length: bytes.count, options: .storageModeShared)
    }
  }

  // MARK: - Drawing

  func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
    // Nothing is cached against the drawable size: the aspect ratio is read per draw.
  }

  func draw(in view: MTKView) {
    let appearance = view.effectiveAppearance
    let background = rgba(.underPageBackgroundColor, in: appearance)
    view.clearColor = MTLClearColor(
      red: Double(background.x),
      green: Double(background.y),
      blue: Double(background.z),
      alpha: Double(background.w))

    let aspect = aspect(of: view)
    let viewMatrix = benchViewMatrix(camera, aspect: aspect)
    let eye = benchCameraPosition(camera, aspect: aspect)
    var uniforms = Uniforms(
      viewProjection: benchProjectionMatrix(aspect: aspect) * viewMatrix,
      view: viewMatrix,
      cutColor: rgba(.controlAccentColor, in: appearance),
      roughColor: rgba(.systemGray, in: appearance),
      edgeColor: rgba(.labelColor, in: appearance),
      highlightColor: rgba(.systemOrange, in: appearance),
      eye: SIMD4(eye.x, eye.y, eye.z, 0),
      params: SIMD4(Float(opacity), -1, Float(highlightedPlaneIndex ?? -1), 0))

    guard let passDescriptor = view.currentRenderPassDescriptor,
      let drawable = view.currentDrawable,
      let commandBuffer = commandQueue.makeCommandBuffer(),
      let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: passDescriptor)
    else { return }

    // Nothing is culled (D18): the bench solid is always closed, so with depth testing culling would be
    // a pure optimisation worth nothing at 60 triangles — and skipping it removes the front-facing
    // winding question, which Metal's y-down window coordinates invert.
    encoder.setCullMode(.none)

    if let triangleBuffer, triangleCount > 0 {
      encoder.setRenderPipelineState(fillPipeline)
      encoder.setVertexBuffer(triangleBuffer, offset: 0, index: 0)
      // Far facets first, writing no depth, then the near ones, which do. Exact back-to-front for a
      // convex solid, and it leaves the depth buffer holding the visible surface for the edges (D8).
      for (facingSign, depthState) in [(Float(-1), depthTestNoWrite), (Float(1), depthTestWrite)] {
        uniforms.params.y = facingSign
        encoder.setDepthStencilState(depthState)
        encoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 1)
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 1)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: triangleCount)
      }
    }

    if let edgeBuffer, edgeCount > 0 {
      encoder.setRenderPipelineState(edgePipeline)
      encoder.setVertexBuffer(edgeBuffer, offset: 0, index: 0)
      // Two passes over the same lines: every edge at the alpha the fill has given up, then the
      // visible ones at full strength on top. The hidden half of the wireframe fades in with the fill
      // instead of appearing all at once, and neither pass reads the depth buffer back (D9). At full
      // opacity the first pass is invisible, which leaves the image part 2 shipped.
      for (edgeAlpha, depthState) in [
        (Float(1 - opacity), depthAlways), (Float(1), depthTestNoWrite),
      ] {
        uniforms.params.w = edgeAlpha
        encoder.setDepthStencilState(depthState)
        encoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 1)
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 1)
        encoder.drawPrimitives(type: .line, vertexStart: 0, vertexCount: edgeCount)
      }
    }

    // The ghost: the finished stone's outline over the intermediate solid, while a meet is being picked.
    // **Last of the three edge passes, and depth-always**, so it shows through the solid rather than
    // being hidden inside it — which is the whole point of drawing it. It reuses `edgeColor`, so it
    // tracks light and dark appearance with everything else.
    if let ghostEdgeBuffer, ghostEdgeCount > 0 {
      encoder.setRenderPipelineState(edgePipeline)
      encoder.setVertexBuffer(ghostEdgeBuffer, offset: 0, index: 0)
      uniforms.params.w = BenchRenderer.ghostEdgeAlpha
      encoder.setDepthStencilState(depthAlways)
      encoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 1)
      encoder.setFragmentBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 1)
      encoder.drawPrimitives(type: .line, vertexStart: 0, vertexCount: ghostEdgeCount)
    }

    encoder.endEncoding()
    commandBuffer.present(drawable)
    commandBuffer.commit()
  }

  private func aspect(of view: MTKView) -> Float {
    let size = view.drawableSize
    guard size.height > 0 else { return 1 }
    return Float(size.width / size.height)
  }

  /// Resolved once per draw, through the view's own appearance — three `NSColor`s is cheap, and the view
  /// redraws only on demand. Baking sRGB values instead is what would stop the solid tracking light and
  /// dark appearance with the rest of the window (D21).
  private func rgba(_ color: NSColor, in appearance: NSAppearance) -> SIMD4<Float> {
    var out = SIMD4<Float>(0, 0, 0, 1)
    appearance.performAsCurrentDrawingAppearance {
      if let resolved = color.usingColorSpace(.sRGB) {
        out = SIMD4(
          Float(resolved.redComponent), Float(resolved.greenComponent),
          Float(resolved.blueComponent), Float(resolved.alphaComponent))
      }
    }
    return out
  }
}
