//
//  EventHorizonRenderer.swift
//  shader-bg
//
//  Created by GitHub Copilot on 2025/11/13.
//

import Metal
import MetalKit
import simd

class EventHorizonRenderer {
  let device: MTLDevice
  let commandQueue: MTLCommandQueue

  // Metal resources
  private var renderPipelineState: MTLRenderPipelineState!
  private var paramsBuffer: MTLBuffer!

  var viewportSize: CGSize = .zero
  private var time: Float = 0.0
  private var lastUpdateTime: CFTimeInterval = 0.0
  private var lastDrawTime: CFTimeInterval = 0.0
  var updateInterval: Double = 1.0 / 30.0  // 30 FPS

  init(device: MTLDevice, size: CGSize) {
    self.device = device
    self.viewportSize = size

    guard let queue = device.makeCommandQueue() else {
      fatalError("Failed to create command queue")
    }
    self.commandQueue = queue

    setupPipeline()
    setupBuffers()
  }

  private func setupPipeline() {
    guard let library = device.makeDefaultLibrary() else {
      fatalError("Failed to create Metal library")
    }

    let vertexFunction = library.makeFunction(name: "eventHorizonVertex")
    let fragmentFunction = library.makeFunction(name: "eventHorizonFragment")

    let pipelineDescriptor = MTLRenderPipelineDescriptor()
    pipelineDescriptor.vertexFunction = vertexFunction
    pipelineDescriptor.fragmentFunction = fragmentFunction
    pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm

    do {
      renderPipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
    } catch {
      fatalError("Failed to create render pipeline state: \(error)")
    }
  }

  private func setupBuffers() {
    // 创建参数缓冲区
    paramsBuffer = device.makeBuffer(
      length: MemoryLayout<EventHorizonParams>.stride,
      options: [.storageModeShared]
    )
  }

  func updateParticles(currentTime: CFTimeInterval) {
    // 限制更新频率
    if currentTime - lastUpdateTime < updateInterval {
      return
    }
    lastUpdateTime = currentTime

    // 更新时间 - 减慢到原速度的 1/8
    time += 0.00125  // 30fps * 0.00125 = 每秒增加约 0.0375 (原速度的 1/8)
  }

  func draw(in view: MTKView) {
    // 限制实际绘制频率
    let currentTime = CACurrentMediaTime()
    if currentTime - lastDrawTime < updateInterval {
      return
    }
    lastDrawTime = currentTime

    guard let drawable = view.currentDrawable,
      let renderPipeline = renderPipelineState,
      let paramsBuffer = paramsBuffer
    else {
      return
    }

    // 每次绘制更新时间 - 减慢到原速度的 1/8
    time += 0.00125  // 30fps * 0.00125 = 每秒增加约 0.0375 (原速度的 1/8)

    // 更新参数
    updateParams(viewportSize: view.drawableSize)

    let renderPassDescriptor = MTLRenderPassDescriptor()
    renderPassDescriptor.colorAttachments[0].texture = drawable.texture
    renderPassDescriptor.colorAttachments[0].loadAction = .clear
    renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(
      red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0)
    renderPassDescriptor.colorAttachments[0].storeAction = .store

    guard let commandBuffer = commandQueue.makeCommandBuffer(),
      let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
    else {
      return
    }

    renderEncoder.setRenderPipelineState(renderPipeline)
    renderEncoder.setFragmentBuffer(paramsBuffer, offset: 0, index: 0)

    // 绘制全屏三角形
    renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)

    renderEncoder.endEncoding()
    commandBuffer.present(drawable)
    commandBuffer.commit()
  }

  private func updateParams(viewportSize: CGSize) {
    guard let paramsBuffer = paramsBuffer else { return }

    var params = EventHorizonParams(
      time: time,
      resolution: SIMD2<Float>(Float(viewportSize.width), Float(viewportSize.height)),
      padding: SIMD2<Float>(0, 0)
    )

    paramsBuffer.contents().copyMemory(
      from: &params, byteCount: MemoryLayout<EventHorizonParams>.stride)
  }
}
