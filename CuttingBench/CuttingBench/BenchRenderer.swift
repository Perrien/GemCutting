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
}

/// Draws the bench solid: flat per-facet fill from each plane's own normal, on whatever camera the view
/// last set. Nothing here builds geometry — the mesh arrives through `setMesh` (D13).
final class BenchRenderer: NSObject, MTKViewDelegate {
  let device: MTLDevice

  /// Where the camera is. The view sets it before asking for a redraw (D1).
  var camera: BenchCameraState = .threeQuarter

  private let commandQueue: MTLCommandQueue
  private let fillPipeline: MTLRenderPipelineState
  private let edgePipeline: MTLRenderPipelineState
  private let depthState: MTLDepthStencilState

  private var triangleBuffer: MTLBuffer?
  private var triangleCount = 0
  private var edgeBuffer: MTLBuffer?
  private var edgeCount = 0

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

    descriptor.vertexFunction = library.makeFunction(name: "fill_vertex")
    descriptor.fragmentFunction = library.makeFunction(name: "fill_fragment")
    fillPipeline = try! device.makeRenderPipelineState(descriptor: descriptor)

    descriptor.vertexFunction = library.makeFunction(name: "edge_vertex")
    descriptor.fragmentFunction = library.makeFunction(name: "edge_fragment")
    edgePipeline = try! device.makeRenderPipelineState(descriptor: descriptor)

    // One depth state, shared by both pipelines: an edge is depth-tested against the solid like
    // anything else, and wins against the facet it lies on by the epsilon in its own vertex function
    // (D19) rather than by a bias whose semantics vary by depth format.
    let depth = MTLDepthStencilDescriptor()
    depth.depthCompareFunction = .less
    depth.isDepthWriteEnabled = true
    depthState = device.makeDepthStencilState(descriptor: depth)!

    super.init()
  }

  /// Attribute offsets come from `MemoryLayout`, never from hand-counted bytes. `SolidMeshTests` pins
  /// the three numbers the shader's `VertexIn` depends on.
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

    descriptor.layouts[0].stride = MemoryLayout<MeshVertex>.stride
    return descriptor
  }

  // MARK: - Geometry

  func setMesh(_ mesh: SolidMesh) {
    triangleBuffer = makeBuffer(mesh.triangleVertices)
    triangleCount = mesh.triangleVertices.count
    edgeBuffer = makeBuffer(mesh.edgeVertices)
    edgeCount = mesh.edgeVertices.count
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

    let viewMatrix = benchViewMatrix(camera)
    var uniforms = Uniforms(
      viewProjection: benchProjectionMatrix(aspect: aspect(of: view)) * viewMatrix,
      view: viewMatrix,
      cutColor: rgba(.controlAccentColor, in: appearance),
      roughColor: rgba(.systemGray, in: appearance),
      edgeColor: rgba(.labelColor, in: appearance))

    guard let passDescriptor = view.currentRenderPassDescriptor,
      let drawable = view.currentDrawable,
      let commandBuffer = commandQueue.makeCommandBuffer(),
      let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: passDescriptor)
    else { return }

    // Nothing is culled (D18): the bench solid is always closed, so with depth testing culling would be
    // a pure optimisation worth nothing at 60 triangles — and skipping it removes the front-facing
    // winding question, which Metal's y-down window coordinates invert.
    encoder.setCullMode(.none)
    encoder.setDepthStencilState(depthState)
    encoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 1)
    encoder.setFragmentBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 1)

    if let triangleBuffer, triangleCount > 0 {
      encoder.setRenderPipelineState(fillPipeline)
      encoder.setVertexBuffer(triangleBuffer, offset: 0, index: 0)
      encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: triangleCount)
    }

    if let edgeBuffer, edgeCount > 0 {
      encoder.setRenderPipelineState(edgePipeline)
      encoder.setVertexBuffer(edgeBuffer, offset: 0, index: 0)
      encoder.drawPrimitives(type: .line, vertexStart: 0, vertexCount: edgeCount)
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
