import Metal
import MetalKit

class RainRipplesRenderer {
  private var pipelineState: MTLComputePipelineState?
  private var commandQueue: MTLCommandQueue?

  private var time: Float = 0.0
  private var viewportSize: CGSize = .zero

  init(device: MTLDevice) {
    NSLog("[RainRipplesRenderer] 🔧 Initializing renderer")
    self.commandQueue = device.makeCommandQueue()

    guard let library = device.makeDefaultLibrary() else {
      NSLog("[RainRipplesRenderer] ❌ Failed to create Metal library")
      print("Failed to create Metal library")
      return
    }
    NSLog("[RainRipplesRenderer] ✅ Metal library created")

    guard let kernelFunction = library.makeFunction(name: "rainRipplesCompute") else {
      NSLog("[RainRipplesRenderer] ❌ Failed to find rainRipplesCompute function")
      print("Failed to find rainRipplesCompute function")
      return
    }
    NSLog("[RainRipplesRenderer] ✅ Found kernel function: rainRipplesCompute")

    do {
      pipelineState = try device.makeComputePipelineState(function: kernelFunction)
      NSLog("[RainRipplesRenderer] ✅ Compute pipeline state created successfully")
    } catch {
      NSLog("[RainRipplesRenderer] ❌ Failed to create compute pipeline state: \(error)")
      print("Failed to create compute pipeline state: \(error)")
    }
  }

  func updateViewportSize(_ size: CGSize) {
    NSLog("[RainRipplesRenderer] 📐 Viewport size updated: \(size)")
    self.viewportSize = size
  }

  private var drawCount: Int = 0

  func draw(in view: MTKView) {
    // 前几帧输出日志
    if drawCount < 3 {
      NSLog(
        "[RainRipplesRenderer] 🎨 Draw call #\(drawCount) - viewportSize: \(viewportSize), time: \(time)"
      )
      drawCount += 1
    }

    guard let drawable = view.currentDrawable else {
      NSLog("[RainRipplesRenderer] ❌ No drawable available")
      return
    }

    guard let pipelineState = pipelineState else {
      NSLog("[RainRipplesRenderer] ❌ No pipeline state available")
      return
    }

    guard let commandQueue = commandQueue else {
      NSLog("[RainRipplesRenderer] ❌ No command queue available")
      return
    }

    time += Float(1.0 / Double(view.preferredFramesPerSecond))

    guard let commandBuffer = commandQueue.makeCommandBuffer(),
      let commandEncoder = commandBuffer.makeComputeCommandEncoder()
    else {
      return
    }

    commandEncoder.setComputePipelineState(pipelineState)
    commandEncoder.setTexture(drawable.texture, index: 0)

    var timeVar = time
    commandEncoder.setBytes(&timeVar, length: MemoryLayout<Float>.stride, index: 0)

    let threadGroupSize = MTLSize(width: 16, height: 16, depth: 1)
    let threadGroups = MTLSize(
      width: (Int(viewportSize.width) + threadGroupSize.width - 1) / threadGroupSize.width,
      height: (Int(viewportSize.height) + threadGroupSize.height - 1) / threadGroupSize.height,
      depth: 1
    )

    commandEncoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupSize)
    commandEncoder.endEncoding()

    commandBuffer.present(drawable)
    commandBuffer.commit()
  }
}
