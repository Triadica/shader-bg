import Metal
import MetalKit

class TorusInteriorRenderer {
  private var pipelineState: MTLComputePipelineState?
  private var commandQueue: MTLCommandQueue?

  private var time: Float = 0.0
  private var viewportSize: CGSize = .zero

  init(device: MTLDevice) {
    NSLog("[TorusInteriorRenderer] 🔧 Initializing renderer")
    self.commandQueue = device.makeCommandQueue()

    guard let library = device.makeDefaultLibrary() else {
      NSLog("[TorusInteriorRenderer] ❌ Failed to create Metal library")
      print("Failed to create Metal library")
      return
    }
    NSLog("[TorusInteriorRenderer] ✅ Metal library created")

    guard let kernelFunction = library.makeFunction(name: "torusInteriorCompute") else {
      NSLog("[TorusInteriorRenderer] ❌ Failed to find torusInteriorCompute function")
      print("Failed to find torusInteriorCompute function")
      return
    }
    NSLog("[TorusInteriorRenderer] ✅ Found kernel function: torusInteriorCompute")

    do {
      pipelineState = try device.makeComputePipelineState(function: kernelFunction)
      NSLog("[TorusInteriorRenderer] ✅ Compute pipeline state created successfully")
    } catch {
      NSLog("[TorusInteriorRenderer] ❌ Failed to create compute pipeline state: \(error)")
      print("Failed to create compute pipeline state: \(error)")
    }
  }

  func updateViewportSize(_ size: CGSize) {
    NSLog("[TorusInteriorRenderer] 📐 Viewport size updated: \(size)")
    self.viewportSize = size
  }

  private var drawCount: Int = 0

  func draw(in view: MTKView) {
    // 前几帧输出日志
    if drawCount < 3 {
      NSLog(
        "[TorusInteriorRenderer] 🎨 Draw call #\(drawCount) - viewportSize: \(viewportSize), time: \(time)"
      )
      drawCount += 1
    }

    guard let drawable = view.currentDrawable else {
      NSLog("[TorusInteriorRenderer] ❌ No drawable available")
      return
    }

    guard let pipelineState = pipelineState else {
      NSLog("[TorusInteriorRenderer] ❌ No pipeline state available")
      return
    }

    guard let commandQueue = commandQueue else {
      NSLog("[TorusInteriorRenderer] ❌ No command queue available")
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

    // 降低渲染分辨率以减少 GPU 开销：渲染到 1/2 分辨率
    let renderScale: CGFloat = 0.5
    var renderScaleVar = Float(renderScale)
    commandEncoder.setBytes(&renderScaleVar, length: MemoryLayout<Float>.stride, index: 1)

    let renderWidth = Int(viewportSize.width * renderScale)
    let renderHeight = Int(viewportSize.height * renderScale)

    let threadGroupSize = MTLSize(width: 16, height: 16, depth: 1)
    let threadGroups = MTLSize(
      width: (renderWidth + threadGroupSize.width - 1) / threadGroupSize.width,
      height: (renderHeight + threadGroupSize.height - 1) / threadGroupSize.height,
      depth: 1
    )

    commandEncoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupSize)
    commandEncoder.endEncoding()

    commandBuffer.present(drawable)
    commandBuffer.commit()
  }
}
