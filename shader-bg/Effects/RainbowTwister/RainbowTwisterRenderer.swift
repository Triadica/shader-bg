//
//  RainbowTwisterRenderer.swift
//  shader-bg
//
//  Created on 2025-11-01.
//

import Foundation
import Metal
import MetalKit

final class RainbowTwisterRenderer {
  let device: MTLDevice
  let commandQueue: MTLCommandQueue
  let pipelineState: MTLRenderPipelineState

  var viewportSize: CGSize = .zero
  private var params: RainbowTwisterParams

  init?(device: MTLDevice, size: CGSize) {
    self.device = device

    guard let queue = device.makeCommandQueue() else {
      NSLog("Failed to create command queue for RainbowTwister")
      return nil
    }
    self.commandQueue = queue

    guard let library = device.makeDefaultLibrary() else {
      NSLog("Failed to load Metal library for RainbowTwister")
      return nil
    }

    guard
      let vertexFunction = library.makeFunction(name: "rainbowTwisterVertex"),
      let fragmentFunction = library.makeFunction(name: "rainbowTwisterFragment")
    else {
      NSLog("Failed to load shader functions for RainbowTwister")
      return nil
    }

    let pipelineDescriptor = MTLRenderPipelineDescriptor()
    pipelineDescriptor.vertexFunction = vertexFunction
    pipelineDescriptor.fragmentFunction = fragmentFunction
    pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm

    do {
      self.pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
    } catch {
      NSLog("Failed to create pipeline state for RainbowTwister: \(error)")
      return nil
    }

    self.viewportSize = size
    self.params = RainbowTwisterParams(
      resolution: SIMD2<Float>(Float(size.width), Float(size.height)),
      time: 0
    )
  }

  func update(time: Float) {
    params.time = time
    params.resolution = SIMD2<Float>(Float(viewportSize.width), Float(viewportSize.height))
  }

  func draw(
    in view: MTKView,
    commandBuffer: MTLCommandBuffer,
    renderPassDescriptor: MTLRenderPassDescriptor
  ) {
    guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
    else {
      return
    }

    encoder.setRenderPipelineState(pipelineState)
    encoder.setFragmentBytes(&params, length: MemoryLayout<RainbowTwisterParams>.stride, index: 0)
    encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
    encoder.endEncoding()
  }
}
