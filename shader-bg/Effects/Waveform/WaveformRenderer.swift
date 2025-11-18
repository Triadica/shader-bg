//
//  WaveformRenderer.swift
//  shader-bg
//
//  Created on 2025-11-01.
//
//  Renders the "Waveform" demo adapted from XorDev's shader.
//

import Foundation
import Metal
import MetalKit
import simd

final class WaveformRenderer {
  let device: MTLDevice
  let commandQueue: MTLCommandQueue

  private var pipelineState: MTLRenderPipelineState!
  private var paramsBuffer: MTLBuffer!

  var viewportSize: CGSize
  private var currentTime: Float = 0

  init(device: MTLDevice, size: CGSize) {
    self.device = device
    self.viewportSize = size

    guard let queue = device.makeCommandQueue() else {
      fatalError("WaveformRenderer: failed to create command queue")
    }
    self.commandQueue = queue

    setupPipeline()
    setupBuffers()
  }

  private func setupPipeline() {
    guard let library = device.makeDefaultLibrary() else {
      fatalError("WaveformRenderer: failed to load default Metal library")
    }

    let vertexFunction = library.makeFunction(name: "waveformVertex")
    let fragmentFunction = library.makeFunction(name: "waveformFragment")

    let descriptor = MTLRenderPipelineDescriptor()
    descriptor.vertexFunction = vertexFunction
    descriptor.fragmentFunction = fragmentFunction
    descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm

    do {
      pipelineState = try device.makeRenderPipelineState(descriptor: descriptor)
    } catch {
      fatalError("WaveformRenderer: failed to create pipeline state: \(error)")
    }
  }

  private func setupBuffers() {
    paramsBuffer = device.makeBuffer(
      length: MemoryLayout<WaveformParams>.stride,
      options: [.storageModeShared]
    )
  }

  func update(time: Float) {
    currentTime = time
  }

  func draw(
    in view: MTKView,
    commandBuffer: MTLCommandBuffer,
    renderPassDescriptor: MTLRenderPassDescriptor
  ) {
    guard
      let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
    else {
      return
    }

    updateParams()

    renderEncoder.setRenderPipelineState(pipelineState)
    renderEncoder.setFragmentBuffer(paramsBuffer, offset: 0, index: 0)
    renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
    renderEncoder.endEncoding()
  }

  private func updateParams() {
    var params = WaveformParams(
      resolution: SIMD2<Float>(Float(viewportSize.width), Float(viewportSize.height)),
      time: currentTime
    )

    memcpy(paramsBuffer.contents(), &params, MemoryLayout<WaveformParams>.stride)
  }
}
