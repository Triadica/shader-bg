//
//  PixellatedRainRenderer.swift
//  shader-bg
//
//  Created by GitHub Copilot on 2025/11/15.
//

import Foundation
import Metal
import MetalKit

class PixellatedRainRenderer {
  private var device: MTLDevice
  private var commandQueue: MTLCommandQueue
  private var pipelineState: MTLRenderPipelineState
  private var startTime: Date = Date()
  private var viewportSize: CGSize = .zero

  init?(device: MTLDevice) {
    self.device = device

    guard let queue = device.makeCommandQueue() else {
      NSLog("[PixellatedRainRenderer] ❌ Failed to create command queue")
      return nil
    }
    self.commandQueue = queue

    do {
      let library = device.makeDefaultLibrary()
      guard let vertexFunction = library?.makeFunction(name: "pixellatedRain_vertex"),
        let fragmentFunction = library?.makeFunction(name: "pixellatedRain_fragment")
      else {
        NSLog("[PixellatedRainRenderer] ❌ Failed to find shader functions")
        return nil
      }

      let pipelineDescriptor = MTLRenderPipelineDescriptor()
      pipelineDescriptor.vertexFunction = vertexFunction
      pipelineDescriptor.fragmentFunction = fragmentFunction
      pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm

      self.pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
      NSLog("[PixellatedRainRenderer] ✅ Pipeline state created successfully")
    } catch {
      NSLog("[PixellatedRainRenderer] ❌ Failed to create render pipeline state: \(error)")
      return nil
    }

    startTime = Date()
  }

  func updateViewportSize(_ size: CGSize) {
    viewportSize = size
  }

  func draw(in view: MTKView) {
    guard let drawable = view.currentDrawable,
      let commandBuffer = commandQueue.makeCommandBuffer(),
      let renderPassDescriptor = view.currentRenderPassDescriptor,
      let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
    else {
      return
    }

    renderEncoder.setRenderPipelineState(pipelineState)

    // 动画速度减少到 1/80 (1/10 * 1/8)
    var params = PixellatedRainData()
    params.time = Float(Date().timeIntervalSince(startTime)) * 0.0125  // 1/80 速度
    params.resolution = SIMD2<Float>(Float(viewportSize.width), Float(viewportSize.height))

    renderEncoder.setFragmentBytes(
      &params, length: MemoryLayout<PixellatedRainData>.stride, index: 0)
    renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)

    renderEncoder.endEncoding()
    commandBuffer.present(drawable)
    commandBuffer.commit()
  }
}
