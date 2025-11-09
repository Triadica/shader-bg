import Metal
import MetalKit

class NeonParallaxRenderer {
  private var device: MTLDevice
  private var commandQueue: MTLCommandQueue?
  private var pipelineState: MTLComputePipelineState?
  private let startTime = Date()
  private var updateInterval: TimeInterval = 1.0 / 30.0

  init(device: MTLDevice) {
    self.device = device
    self.commandQueue = device.makeCommandQueue()
    setupPipeline()
  }

  private func setupPipeline() {
    guard let library = device.makeDefaultLibrary() else {
      print("Failed to create default library")
      return
    }

    guard let kernelFunction = library.makeFunction(name: "neonParallaxCompute") else {
      print("Failed to create kernel function: neonParallaxCompute")
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
      let commandBuffer = commandQueue?.makeCommandBuffer(),
      let commandEncoder = commandBuffer.makeComputeCommandEncoder()
    else { return }

    let elapsedTime = Float(Date().timeIntervalSince(startTime))
    let width = Float(drawable.texture.width)
    let height = Float(drawable.texture.height)

    var data = (
      time: elapsedTime,
      resolution: SIMD2<Float>(width, height),
      padding: SIMD2<Float>(0, 0)
    )

    commandEncoder.setComputePipelineState(pipelineState)
    commandEncoder.setTexture(drawable.texture, index: 0)
    commandEncoder.setBytes(&data, length: MemoryLayout.size(ofValue: data), index: 0)

    let threadGroupSize = MTLSize(width: 16, height: 16, depth: 1)
    let threadGroups = MTLSize(
      width: (Int(width) + threadGroupSize.width - 1) / threadGroupSize.width,
      height: (Int(height) + threadGroupSize.height - 1) / threadGroupSize.height,
      depth: 1
    )

    commandEncoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupSize)
    commandEncoder.endEncoding()

    commandBuffer.present(drawable)
    commandBuffer.commit()
  }

  func updateViewportSize(_ size: CGSize) {
    // Handle size changes if needed
  }
}
