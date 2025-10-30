//
//  ClockRenderer.swift
//  shader-bg
//
//  Created on 2025-10-31.
//
//  Renders the analog clock effect inspired by Inigo Quilez's "Clock" shader.
//

import Foundation
import Metal
import MetalKit
import simd

final class ClockRenderer {
  let device: MTLDevice
  let commandQueue: MTLCommandQueue

  private var pipelineState: MTLRenderPipelineState!
  private var paramsBuffer: MTLBuffer!

  var viewportSize: CGSize

  init(device: MTLDevice, size: CGSize) {
    self.device = device
    self.viewportSize = size

    guard let queue = device.makeCommandQueue() else {
      fatalError("ClockRenderer: failed to create command queue")
    }
    self.commandQueue = queue

    setupPipeline()
    setupBuffers()
  }

  private func setupPipeline() {
    guard let library = device.makeDefaultLibrary() else {
      fatalError("ClockRenderer: failed to load default Metal library")
    }

    let vertexFunction = library.makeFunction(name: "clockVertex")
    let fragmentFunction = library.makeFunction(name: "clockFragment")

    let descriptor = MTLRenderPipelineDescriptor()
    descriptor.vertexFunction = vertexFunction
    descriptor.fragmentFunction = fragmentFunction
    descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm

    do {
      pipelineState = try device.makeRenderPipelineState(descriptor: descriptor)
    } catch {
      fatalError("ClockRenderer: failed to create pipeline state: \(error)")
    }
  }

  private func setupBuffers() {
    let bufferLength = MemoryLayout<ClockParams>.stride
    paramsBuffer = device.makeBuffer(length: bufferLength, options: [.storageModeShared])
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
    let now = Date()
    let timeInterval = now.timeIntervalSince1970
    let integralSeconds = floor(timeInterval)
    let fractional = Float(timeInterval - integralSeconds)

    let calendar = Calendar.current
    let timeZone = TimeZone.current
    let components = calendar.dateComponents(in: timeZone, from: now)

    let baseSeconds = Float(components.second ?? 0)
    let baseMinutes = Float(components.minute ?? 0)
    let baseHours = Float(components.hour ?? 0)

    let seconds = baseSeconds + fractional
    let minutes = baseMinutes + seconds / 60.0
    let hours = baseHours.truncatingRemainder(dividingBy: 12.0) + minutes / 60.0

    var params = ClockParams(
      resolution: SIMD2<Float>(Float(viewportSize.width), Float(viewportSize.height)),
      seconds: seconds,
      minutes: minutes,
      hours: hours,
      fractionalSecond: fractional
    )

    memcpy(paramsBuffer.contents(), &params, MemoryLayout<ClockParams>.stride)
  }
}
