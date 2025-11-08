//
//  PlasmaWavesRenderer.swift
//  shader-bg
//
//  Created by AI Assistant on 2025/11/08.
//

import Metal
import MetalKit

class PlasmaWavesRenderer {
  private var device: MTLDevice
  private var pipelineState: MTLComputePipelineState?
  private var commandQueue: MTLCommandQueue?

  var data: PlasmaWavesData
  var updateInterval: Double = 1.0 / 30.0  // 30 FPS

  init(device: MTLDevice, size: CGSize) {
    self.device = device
    self.data = PlasmaWavesData(
      time: 0.0,
      resolution: SIMD2<Float>(Float(size.width), Float(size.height))
    )

    setupPipeline()
  }

  private func setupPipeline() {
    commandQueue = device.makeCommandQueue()

    guard let library = device.makeDefaultLibrary() else {
      print("无法创建 Metal 库")
      return
    }

    guard let kernelFunction = library.makeFunction(name: "plasmaWavesShader") else {
      print("无法找到 plasmaWavesShader 函数")
      return
    }

    do {
      pipelineState = try device.makeComputePipelineState(function: kernelFunction)
    } catch {
      print("无法创建管线状态: \(error)")
    }
  }

  func update(currentTime: Double) {
    data.time += Float(updateInterval) * 0.5  // 减慢动画速度
  }

  func resize(size: CGSize) {
    data.resolution = SIMD2<Float>(Float(size.width), Float(size.height))
  }

  func draw(commandBuffer: MTLCommandBuffer, view: MTKView) {
    guard let drawable = view.currentDrawable,
      let pipelineState = pipelineState
    else { return }

    let texture = drawable.texture

    guard let computeEncoder = commandBuffer.makeComputeCommandEncoder() else { return }
    computeEncoder.setComputePipelineState(pipelineState)
    computeEncoder.setTexture(texture, index: 0)

    var localData = data
    computeEncoder.setBytes(&localData, length: MemoryLayout<PlasmaWavesData>.stride, index: 0)

    let threadGroupSize = MTLSize(width: 16, height: 16, depth: 1)
    let threadGroups = MTLSize(
      width: (texture.width + threadGroupSize.width - 1) / threadGroupSize.width,
      height: (texture.height + threadGroupSize.height - 1) / threadGroupSize.height,
      depth: 1
    )

    computeEncoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupSize)
    computeEncoder.endEncoding()

    commandBuffer.present(drawable)
    commandBuffer.commit()
  }
}
