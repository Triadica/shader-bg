import MetalKit

class PoincareHexagonsRenderer: NSObject {
  let device: MTLDevice
  let commandQueue: MTLCommandQueue
  var pipelineState: MTLRenderPipelineState!
  var params: PoincareHexagonsParams
  var startTime: CFAbsoluteTime

  init(device: MTLDevice, pixelFormat: MTLPixelFormat) {
    self.device = device
    self.commandQueue = device.makeCommandQueue()!
    self.params = PoincareHexagonsParams(
      time: 0,
      resolution: SIMD2<Float>(800, 600),
      mouse: SIMD4<Float>(0, 0, 0, 0),
      padding: 0
    )
    self.startTime = CFAbsoluteTimeGetCurrent()

    super.init()

    buildPipeline(pixelFormat: pixelFormat)
  }

  private func buildPipeline(pixelFormat: MTLPixelFormat) {
    guard let library = device.makeDefaultLibrary() else {
      fatalError("Could not load default library")
    }

    let vertexFunction = library.makeFunction(name: "poincareHexagonsVertex")
    let fragmentFunction = library.makeFunction(name: "poincareHexagonsFragment")

    let pipelineDescriptor = MTLRenderPipelineDescriptor()
    pipelineDescriptor.vertexFunction = vertexFunction
    pipelineDescriptor.fragmentFunction = fragmentFunction
    pipelineDescriptor.colorAttachments[0].pixelFormat = pixelFormat

    do {
      pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
    } catch {
      fatalError("Could not create pipeline state: \(error)")
    }
  }

  func updateParticles() {
    // Slow animation - reduce time increment to 1/8 of normal speed
    params.time += Float(1.0 / 60.0) * 0.125
  }

  func draw(in view: MTKView) {
    updateParticles()

    params.resolution = SIMD2<Float>(
      Float(view.drawableSize.width), Float(view.drawableSize.height))

    guard let drawable = view.currentDrawable,
      let descriptor = view.currentRenderPassDescriptor
    else { return }

    descriptor.colorAttachments[0].clearColor = MTLClearColor(
      red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0)
    descriptor.colorAttachments[0].loadAction = .clear

    guard let commandBuffer = commandQueue.makeCommandBuffer(),
      let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor)
    else { return }

    renderEncoder.setRenderPipelineState(pipelineState)

    var paramsBuffer = params
    renderEncoder.setFragmentBytes(
      &paramsBuffer, length: MemoryLayout<PoincareHexagonsParams>.stride, index: 0)

    renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
    renderEncoder.endEncoding()

    commandBuffer.present(drawable)
    commandBuffer.commit()
  }

  func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
    params.resolution = SIMD2<Float>(Float(size.width), Float(size.height))
  }
}
