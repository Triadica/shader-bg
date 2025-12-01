//
//  RhombusRenderer.swift
//  shader-bg
//
//  Created on 2025-10-29.
//

import Metal
import MetalKit
import simd

class RhombusRenderer {
  let device: MTLDevice
  let commandQueue: MTLCommandQueue

  // Metal resources
  private var renderPipelineState: MTLRenderPipelineState!
  private var paramsBuffer: MTLBuffer!

  var viewportSize: CGSize = .zero
  private var time: Float = 0.0

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

    let vertexFunction = library.makeFunction(name: "rhombusVertex")
    let fragmentFunction = library.makeFunction(name: "rhombusFragment")

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
      length: MemoryLayout<RhombusParams>.stride,
      options: [.storageModeShared]
    )
  }

  func draw(
    in view: MTKView, commandBuffer: MTLCommandBuffer, renderPassDescriptor: MTLRenderPassDescriptor
  ) {
    // 更新时间（速度减慢到 1/4）
    time += 1.0 / 60.0 / 4.0  // 假设60fps，速度为原来的 1/4

    // 更新参数
    updateParams(viewportSize: view.drawableSize)

    // 创建渲染编码器
    guard
      let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
    else {
      return
    }

    renderEncoder.setRenderPipelineState(renderPipelineState)
    renderEncoder.setFragmentBuffer(paramsBuffer, offset: 0, index: 0)

    // 绘制全屏四边形（2个三角形，6个顶点）
    renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)

    renderEncoder.endEncoding()
  }

  private func updateParams(viewportSize: CGSize) {
    guard let paramsBuffer = paramsBuffer else { return }

    var params = RhombusParams(
      resolution: SIMD2<Float>(Float(viewportSize.width), Float(viewportSize.height)),
      time: time,
      padding: 0
    )

    paramsBuffer.contents().copyMemory(from: &params, byteCount: MemoryLayout<RhombusParams>.stride)
  }
}
