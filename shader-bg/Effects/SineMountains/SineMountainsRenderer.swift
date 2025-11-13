import Metal
import MetalKit

class SineMountainsRenderer {
  private var device: MTLDevice
  private var commandQueue: MTLCommandQueue
  private var pipelineState: MTLComputePipelineState
  private var startTime: Date = Date()
  private var viewportSize: CGSize = .zero

  init?(device: MTLDevice) {
    self.device = device

    guard let queue = device.makeCommandQueue() else {
      NSLog("[SineMountainsRenderer] ❌ Failed to create command queue")
      return nil
    }
    self.commandQueue = queue

    do {
      let library = device.makeDefaultLibrary()
      guard let kernelFunction = library?.makeFunction(name: "sineMountainsCompute") else {
        NSLog("[SineMountainsRenderer] ❌ Failed to find sineMountainsCompute function")
        return nil
      }

      self.pipelineState = try device.makeComputePipelineState(function: kernelFunction)
      NSLog("[SineMountainsRenderer] ✅ Pipeline state created successfully")
    } catch {
      NSLog("[SineMountainsRenderer] ❌ Failed to create compute pipeline state: \(error)")
      return nil
    }
  }

  func updateViewportSize(_ size: CGSize) {
    viewportSize = size
  }

  func draw(in view: MTKView) {
    guard let drawable = view.currentDrawable,
      let commandBuffer = commandQueue.makeCommandBuffer(),
      let commandEncoder = commandBuffer.makeComputeCommandEncoder()
    else {
      return
    }

    commandEncoder.setComputePipelineState(pipelineState)
    commandEncoder.setTexture(drawable.texture, index: 0)

    var time = Float(Date().timeIntervalSince(startTime)) * 0.25  // 降低速度到 1/4
    commandEncoder.setBytes(&time, length: MemoryLayout<Float>.stride, index: 0)

    let threadGroupSize = MTLSize(width: 16, height: 16, depth: 1)
    let threadGroups = MTLSize(
      width: (drawable.texture.width + threadGroupSize.width - 1) / threadGroupSize.width,
      height: (drawable.texture.height + threadGroupSize.height - 1) / threadGroupSize.height,
      depth: 1)

    commandEncoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupSize)
    commandEncoder.endEncoding()

    commandBuffer.present(drawable)
    commandBuffer.commit()
  }
}
