//
//  RainbowRoadRenderer.swift
//  shader-bg
//
//  Created on 2025-11-07.
//

import MetalKit

class RainbowRoadRenderer: NSObject {
  var device: MTLDevice!
  var commandQueue: MTLCommandQueue!
  var renderPipelineState: MTLRenderPipelineState!
  var paramsBuffer: MTLBuffer!
  var viewportSize: CGSize = .zero
  private var time: Float = 0.0
  private var lastUpdateTime: CFTimeInterval = 0.0
  private var lastDrawTime: CFTimeInterval = 0.0
  var updateInterval: Double = 1.0 / 15.0  // 降低到 15 FPS 以减少 GPU 负载

  init(device: MTLDevice, size: CGSize) {
    NSLog("[RainbowRoad] 🎨 RainbowRoadRenderer init with size: \(size)")
    self.device = device
    self.commandQueue = device.makeCommandQueue()!
    self.viewportSize = size

    super.init()

    setupPipeline()
    setupBuffers()
    NSLog("[RainbowRoad] ✅ RainbowRoadRenderer setup complete")
  }

  private func setupPipeline() {
    NSLog("[RainbowRoad] 📚 Setting up pipeline...")
    guard let library = device.makeDefaultLibrary() else {
      NSLog("[RainbowRoad] ❌ Failed to create Metal library")
      fatalError("Failed to create Metal library")
    }

    let vertexFunction = library.makeFunction(name: "rainbowRoadVertex")
    let fragmentFunction = library.makeFunction(name: "rainbowRoadFragment")

    if vertexFunction == nil {
      NSLog("[RainbowRoad] ❌ Failed to find rainbowRoadVertex function")
    }
    if fragmentFunction == nil {
      NSLog("[RainbowRoad] ❌ Failed to find rainbowRoadFragment function")
    }

    let pipelineDescriptor = MTLRenderPipelineDescriptor()
    pipelineDescriptor.vertexFunction = vertexFunction
    pipelineDescriptor.fragmentFunction = fragmentFunction
    pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm

    do {
      renderPipelineState = try device.makeRenderPipelineState(
        descriptor: pipelineDescriptor)
    } catch {
      fatalError("Failed to create pipeline state: \(error)")
    }
  }

  private func setupBuffers() {
    paramsBuffer = device.makeBuffer(
      length: MemoryLayout<RainbowRoadParams>.stride,
      options: []
    )
  }

  func updateParticles(currentTime: CFTimeInterval) {
    if currentTime - lastUpdateTime < updateInterval {
      return
    }
    lastUpdateTime = currentTime

    // 显著减慢动画速度到原速度的 1/20，并调整为 15fps
    time += 0.00111  // 15fps * 0.00111 = 每秒约 0.0167
  }

  func draw(in view: MTKView) {
    let currentTime = CACurrentMediaTime()
    if currentTime - lastDrawTime < updateInterval {
      return
    }
    lastDrawTime = currentTime

    guard let renderPipeline = renderPipelineState,
      let paramsBuffer = paramsBuffer
    else {
      return
    }

    guard let drawable = view.currentDrawable else {
      return
    }

    updateParams(viewportSize: view.drawableSize)

    let renderPassDescriptor = MTLRenderPassDescriptor()
    renderPassDescriptor.colorAttachments[0].texture = drawable.texture
    renderPassDescriptor.colorAttachments[0].loadAction = .clear
    renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(
      red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0)
    renderPassDescriptor.colorAttachments[0].storeAction = .store

    guard let commandBuffer = commandQueue.makeCommandBuffer(),
      let renderEncoder = commandBuffer.makeRenderCommandEncoder(
        descriptor: renderPassDescriptor)
    else {
      return
    }

    renderEncoder.setRenderPipelineState(renderPipeline)
    renderEncoder.setFragmentBuffer(paramsBuffer, offset: 0, index: 0)

    renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)

    renderEncoder.endEncoding()

    if let finalDrawable = view.currentDrawable {
      commandBuffer.present(finalDrawable)
    }

    commandBuffer.commit()
  }

  private func updateParams(viewportSize: CGSize) {
    guard let paramsBuffer = paramsBuffer else { return }

    // 降低分辨率到 40% 以减少 GPU 负载
    let scale: Float = 0.4
    var params = RainbowRoadParams(
      time: time,
      resolution: SIMD2<Float>(
        Float(viewportSize.width) * scale, Float(viewportSize.height) * scale),
      padding: 0
    )

    paramsBuffer.contents().copyMemory(
      from: &params, byteCount: MemoryLayout<RainbowRoadParams>.stride)
  }
}
