//
//  ApollianTwistRenderer.swift
//  shader-bg
//
//  Created on 2025-10-30.
//

import Metal
import MetalKit
import simd

class ApollianTwistRenderer {
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

    let vertexFunction = library.makeFunction(name: "apollianTwistVertex")
    let fragmentFunction = library.makeFunction(name: "apollianTwistFragment")

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
    let bufferSize = MemoryLayout<ApollianTwistParams>.stride
    paramsBuffer = device.makeBuffer(length: bufferSize, options: [.storageModeShared])
  }

  func draw(
    in view: MTKView, commandBuffer: MTLCommandBuffer,
    renderPassDescriptor: MTLRenderPassDescriptor
  ) {
    guard
      let renderEncoder = commandBuffer.makeRenderCommandEncoder(
        descriptor: renderPassDescriptor)
    else {
      return
    }

    // 更新时间（30fps，速度减慢 10 倍）
    // 原始速度是 1/60，现在是 1/60/10，但由于帧率从 60fps 降到 30fps
    // 所以实际时间增量保持为 1/60/10 即可获得更慢的效果
    time += 1.0 / 60.0 / 10.0

    // 更新参数缓冲区
    var params = ApollianTwistParams(
      resolution: SIMD2<Float>(Float(viewportSize.width), Float(viewportSize.height)),
      time: time
    )

    if let buffer = paramsBuffer {
      memcpy(buffer.contents(), &params, MemoryLayout<ApollianTwistParams>.stride)
    }

    renderEncoder.setRenderPipelineState(renderPipelineState)
    renderEncoder.setFragmentBuffer(paramsBuffer, offset: 0, index: 0)
    renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)

    renderEncoder.endEncoding()
  }
}
