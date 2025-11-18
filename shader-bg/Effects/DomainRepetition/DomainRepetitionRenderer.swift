import Foundation
import Metal
import MetalKit

class DomainRepetitionRenderer {
  private var device: MTLDevice
  private var commandQueue: MTLCommandQueue
  private var pipelineState: MTLComputePipelineState?

  private var startTime: Date
  var updateInterval: Double = 1.0 / 30.0  // 30 FPS

  init(device: MTLDevice) {
    self.device = device
    self.commandQueue = device.makeCommandQueue()!
    self.startTime = Date()

    setupPipeline()
  }

  private func setupPipeline() {
    guard let library = device.makeDefaultLibrary() else {
      print("Failed to create Metal library")
      return
    }

    guard let kernelFunction = library.makeFunction(name: "domainRepetitionCompute") else {
      print("Failed to create kernel function")
      return
    }

    do {
      pipelineState = try device.makeComputePipelineState(function: kernelFunction)
    } catch {
      print("Failed to create pipeline state: \(error)")
    }
  }

  func draw(in view: MTKView) {
    guard let drawable = view.currentDrawable,
      let pipelineState = pipelineState,
      let commandBuffer = commandQueue.makeCommandBuffer(),
      let commandEncoder = commandBuffer.makeComputeCommandEncoder()
    else {
      return
    }

    let elapsedTime = Float(Date().timeIntervalSince(startTime))

    var data = (
      time: elapsedTime,
      resolution: SIMD2<Float>(Float(view.drawableSize.width), Float(view.drawableSize.height)),
      padding: SIMD2<Float>(0, 0)
    )

    commandEncoder.setComputePipelineState(pipelineState)
    commandEncoder.setTexture(drawable.texture, index: 0)
    commandEncoder.setBytes(&data, length: MemoryLayout.size(ofValue: data), index: 0)

    let threadGroupSize = MTLSize(width: 16, height: 16, depth: 1)
    let threadGroups = MTLSize(
      width: (Int(view.drawableSize.width) + threadGroupSize.width - 1) / threadGroupSize.width,
      height: (Int(view.drawableSize.height) + threadGroupSize.height - 1) / threadGroupSize.height,
      depth: 1
    )

    commandEncoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupSize)
    commandEncoder.endEncoding()

    commandBuffer.present(drawable)
    commandBuffer.commit()
  }
}
