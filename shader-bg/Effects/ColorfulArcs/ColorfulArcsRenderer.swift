import Metal
import MetalKit

class ColorfulArcsRenderer {
  private var pipelineState: MTLComputePipelineState?
  private var commandQueue: MTLCommandQueue?

  private var time: Float = 0.0
  private var viewportSize: CGSize = .zero

  init(device: MTLDevice) {
    NSLog("[ColorfulArcsRenderer] 🔧 Initializing renderer")
    self.commandQueue = device.makeCommandQueue()

    guard let library = device.makeDefaultLibrary() else {
      NSLog("[ColorfulArcsRenderer] ❌ Failed to create Metal library")
      return
    }
    NSLog("[ColorfulArcsRenderer] ✅ Metal library created")

    guard let kernelFunction = library.makeFunction(name: "colorfulArcsCompute") else {
      NSLog("[ColorfulArcsRenderer] ❌ Failed to find colorfulArcsCompute function")
      return
    }
    NSLog("[ColorfulArcsRenderer] ✅ Found kernel function: colorfulArcsCompute")

    do {
      pipelineState = try device.makeComputePipelineState(function: kernelFunction)
      NSLog("[ColorfulArcsRenderer] ✅ Compute pipeline state created successfully")
    } catch {
      NSLog("[ColorfulArcsRenderer] ❌ Failed to create compute pipeline state: \(error)")
    }
  }

  func updateViewportSize(_ size: CGSize) {
    NSLog("[ColorfulArcsRenderer] 📐 Viewport size updated: \(size)")
    self.viewportSize = size
  }

  func draw(in view: MTKView) {
    guard let drawable = view.currentDrawable else {
      return
    }

    guard let pipelineState = pipelineState else {
      return
    }

    guard let commandQueue = commandQueue else {
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
