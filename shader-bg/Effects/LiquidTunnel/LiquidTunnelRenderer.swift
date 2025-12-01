//
//  LiquidTunnelRenderer.swift
//  shader-bg
//
//  Created by chen on 2025/10/28.
//

import Metal
import MetalKit
import simd

class LiquidTunnelRenderer {
  let device: MTLDevice
  let commandQueue: MTLCommandQueue

  var renderPipelineState: MTLRenderPipelineState?
  var paramsBuffer: MTLBuffer?
  var renderTexture: MTLTexture?  // 低分辨率渲染目标
  var renderPassDescriptor: MTLRenderPassDescriptor?

  var viewportSize: CGSize = .zero
  var renderScale: CGFloat = 0.5  // 渲染缩放：0.5 = 1/4 像素数
  var startTime: CFTimeInterval = CACurrentMediaTime()
  var lastUpdateTime: CFTimeInterval = 0
  var updateInterval: CFTimeInterval = 1.0 / 8.0  // 降低到 8 FPS，平衡性能和流畅度

  // 性能监控
  var lastLogTime: CFTimeInterval = 0
  var frameCount: Int = 0
  var totalFrameTime: CFTimeInterval = 0

  init(device: MTLDevice, size: CGSize) {
    self.device = device
    self.viewportSize = size

    guard let queue = device.makeCommandQueue() else {
      fatalError("Failed to create command queue")
    }
    self.commandQueue = queue

    setupPipeline()
    setupBuffer()
  }

  func setupPipeline() {
    guard let library = device.makeDefaultLibrary() else {
      fatalError("Failed to create Metal library")
    }

    // 设置 Render Pipeline
    let pipelineDescriptor = MTLRenderPipelineDescriptor()
    pipelineDescriptor.vertexFunction = library.makeFunction(name: "liquidTunnelVertexShader")
    pipelineDescriptor.fragmentFunction = library.makeFunction(name: "liquidTunnelFragmentShader")
    pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm

    // 启用混合
    pipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
    pipelineDescriptor.colorAttachments[0].rgbBlendOperation = .add
    pipelineDescriptor.colorAttachments[0].alphaBlendOperation = .add
    pipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
    pipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
    pipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
    pipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha

    do {
      renderPipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
    } catch {
      fatalError("Failed to create render pipeline state: \(error)")
    }
  }

  func setupBuffer() {
    // 使用降低的分辨率进行 raymarching 计算
    let renderWidth = Float(viewportSize.width) * Float(renderScale)
    let renderHeight = Float(viewportSize.height) * Float(renderScale)

    var params = LiquidTunnelParams(
      time: 0.0,
      resolution: SIMD2<Float>(renderWidth, renderHeight)
    )

    let paramsSize = MemoryLayout<LiquidTunnelParams>.stride
    paramsBuffer = device.makeBuffer(
      bytes: &params, length: paramsSize, options: .storageModeShared)

    NSLog(
      "[LiquidTunnel] 初始化 - 显示分辨率: %.0fx%.0f, 渲染分辨率: %.0fx%.0f (缩放: %.1f)",
      viewportSize.width, viewportSize.height, renderWidth, renderHeight, renderScale)
  }

  func updateParams(currentTime: CFTimeInterval) {
    guard let paramsBuffer = paramsBuffer else { return }

    let elapsedTime = Float(currentTime - startTime)

    // 使用降低的分辨率
    let renderWidth = Float(viewportSize.width) * Float(renderScale)
    let renderHeight = Float(viewportSize.height) * Float(renderScale)

    var params = LiquidTunnelParams(
      time: elapsedTime * 0.3,  // 进一步减慢时间流逝，让动画更平缓
      resolution: SIMD2<Float>(renderWidth, renderHeight)
    )

    let paramsPointer = paramsBuffer.contents().assumingMemoryBound(to: LiquidTunnelParams.self)
    paramsPointer.pointee = params
  }

  func draw(in view: MTKView) {
    let frameStartTime = CACurrentMediaTime()
    let currentTime = frameStartTime

    // 检查是否需要跳过此帧
    if currentTime - lastUpdateTime < updateInterval {
      return
    }

    updateParams(currentTime: currentTime)

    guard let renderPipeline = renderPipelineState,
      let paramsBuffer = paramsBuffer,
      let commandBuffer = commandQueue.makeCommandBuffer(),
      let renderPassDescriptor = view.currentRenderPassDescriptor,
      let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
    else {
      return
    }

    renderEncoder.setRenderPipelineState(renderPipeline)
    renderEncoder.setFragmentBuffer(paramsBuffer, offset: 0, index: 0)
    renderEncoder.setVertexBuffer(paramsBuffer, offset: 0, index: 0)

    // 绘制全屏三角形
    renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)

    renderEncoder.endEncoding()

    if let drawable = view.currentDrawable {
      commandBuffer.present(drawable)
    }

    commandBuffer.commit()

    // 性能监控
    let frameEndTime = CACurrentMediaTime()
    let frameTime = frameEndTime - frameStartTime
    totalFrameTime += frameTime
    frameCount += 1

    // 每秒输出一次性能日志
    if frameEndTime - lastLogTime >= 1.0 {
      let avgFrameTime = totalFrameTime / Double(frameCount)
      let fps = Double(frameCount) / (frameEndTime - lastLogTime)
      NSLog(
        "[LiquidTunnel] FPS: %.1f, 平均帧时间: %.2fms, 分辨率: %dx%d",
        fps, avgFrameTime * 1000, Int(viewportSize.width), Int(viewportSize.height))

      lastLogTime = frameEndTime
      frameCount = 0
      totalFrameTime = 0
    }
  }
}
