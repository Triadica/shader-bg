//
//  NewtonCloudRenderer.swift
//  shader-bg
//
//  Created on 2025-11-08.
//

import MetalKit

class NewtonCloudRenderer: NSObject {
  var device: MTLDevice!
  var commandQueue: MTLCommandQueue!
  var renderPipelineState: MTLRenderPipelineState!
  var paramsBuffer: MTLBuffer!
  var viewportSize: CGSize = .zero
  private var time: Float = 0.0
  private var lastUpdateTime: CFTimeInterval = 0.0
  private var lastDrawTime: CFTimeInterval = 0.0
  var updateInterval: Double = 1.0 / 30.0  // 30 FPS

  init(device: MTLDevice, size: CGSize) {
    NSLog("[NewtonCloud] 🎨 NewtonCloudRenderer init with size: \(size)")
    self.device = device
    self.commandQueue = device.makeCommandQueue()!
    self.viewportSize = size

    super.init()

    setupPipeline()
    setupBuffers()
    NSLog("[NewtonCloud] ✅ NewtonCloudRenderer setup complete")
  }

  private func setupPipeline() {
    NSLog("[NewtonCloud] 📚 Setting up pipeline...")
    guard let library = device.makeDefaultLibrary() else {
      NSLog("[NewtonCloud] ❌ Failed to create Metal library")
      fatalError("Failed to create Metal library")
    }

    let vertexFunction = library.makeFunction(name: "newtonCloudVertex")
    let fragmentFunction = library.makeFunction(name: "newtonCloudFragment")

    if vertexFunction == nil {
      NSLog("[NewtonCloud] ❌ Failed to find newtonCloudVertex function")
    }
    if fragmentFunction == nil {
      NSLog("[NewtonCloud] ❌ Failed to find newtonCloudFragment function")
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
      length: MemoryLayout<NewtonCloudParams>.stride,
      options: []
    )
  }

  func updateParticles(currentTime: CFTimeInterval) {
    if currentTime - lastUpdateTime < updateInterval {
      return
    }
    lastUpdateTime = currentTime

    // 添加时间变量让画面产生动画效果，减慢到 1/4 速度
    time += 0.002  // 循环时间增量（降低到原来的 1/4）
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

    let scale: Float = 0.6  // 60% 分辨率
    var params = NewtonCloudParams(
      time: time,
      resolution: SIMD2<Float>(
        Float(viewportSize.width) * scale, Float(viewportSize.height) * scale),
      padding: 0
    )

    paramsBuffer.contents().copyMemory(
      from: &params, byteCount: MemoryLayout<NewtonCloudParams>.stride)
  }
}
