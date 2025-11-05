//
//  RedBlueSwirlRenderer.swift
//  shader-bg
//
//  Created on 2025-11-06.
//

import Metal
import MetalKit
import simd

class RedBlueSwirlRenderer {
  let device: MTLDevice
  let commandQueue: MTLCommandQueue

  // Metal resources
  private var renderPipelineState: MTLRenderPipelineState!
  private var paramsBuffer: MTLBuffer!

  var viewportSize: CGSize = .zero
  private var time: Float = 0.0
  private var lastUpdateTime: CFTimeInterval = 0.0
  private var lastDrawTime: CFTimeInterval = 0.0
  var updateInterval: Double = 1.0 / 10.0  // 10 FPS（降低帧率减少 GPU 消耗）

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

  deinit {
    // 清理 Metal 资源
    renderPipelineState = nil
    paramsBuffer = nil
    print("RedBlueSwirlRenderer 已释放")
  }

  private func setupPipeline() {
    guard let library = device.makeDefaultLibrary() else {
      fatalError("Failed to create Metal library")
    }

    let vertexFunction = library.makeFunction(name: "redBlueSwirlVertex")
    let fragmentFunction = library.makeFunction(name: "redBlueSwirlFragment")

    let pipelineDescriptor = MTLRenderPipelineDescriptor()
    pipelineDescriptor.vertexFunction = vertexFunction
    pipelineDescriptor.fragmentFunction = fragmentFunction
    pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm

    // 启用透明混合
    pipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
    pipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
    pipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
    pipelineDescriptor.colorAttachments[0].rgbBlendOperation = .add
    pipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .one
    pipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
    pipelineDescriptor.colorAttachments[0].alphaBlendOperation = .add

    do {
      renderPipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
    } catch {
      fatalError("Failed to create render pipeline state: \(error)")
    }
  }

  private func setupBuffers() {
    // 创建参数缓冲区
    paramsBuffer = device.makeBuffer(
      length: MemoryLayout<RedBlueSwirlParams>.stride,
      options: [.storageModeShared]
    )
  }

  func updateParticles(currentTime: CFTimeInterval) {
    // 限制更新频率
    if currentTime - lastUpdateTime < updateInterval {
      return
    }
    lastUpdateTime = currentTime

    // 更新时间（超级慢速度，再降低到 1/8）
    time += 0.00000102  // 10fps * 0.00000102 = 每秒增加约 0.0000102（超级慢）
  }

  func draw(in view: MTKView) {
    // 限制实际绘制频率
    let currentTime = CACurrentMediaTime()
    if currentTime - lastDrawTime < updateInterval {
      return
    }
    lastDrawTime = currentTime

    // 检查资源是否有效
    guard let renderPipeline = renderPipelineState,
      let paramsBuffer = paramsBuffer
    else {
      return
    }

    // 获取 drawable，如果失败则直接返回
    guard let drawable = view.currentDrawable else {
      return
    }

    // 更新参数（时间已在 updateParticles 中更新）
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

    // 再次检查 drawable 是否仍然有效（防止屏幕断开）
    if let finalDrawable = view.currentDrawable {
      commandBuffer.present(finalDrawable)
    }

    commandBuffer.commit()
  }

  private func updateParams(viewportSize: CGSize) {
    guard let paramsBuffer = paramsBuffer else { return }

    // 降低渲染分辨率到 40% 以减少 GPU 消耗
    let scale: Float = 0.4
    var params = RedBlueSwirlParams(
      time: time,
      resolution: SIMD2<Float>(
        Float(viewportSize.width) * scale, Float(viewportSize.height) * scale),
      padding: 0
    )

    paramsBuffer.contents().copyMemory(
      from: &params, byteCount: MemoryLayout<RedBlueSwirlParams>.stride)
  }
}
