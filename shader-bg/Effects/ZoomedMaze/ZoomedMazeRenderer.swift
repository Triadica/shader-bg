import Metal
import MetalKit

class ZoomedMazeRenderer {
  private var pipelineState: MTLComputePipelineState?
  private var commandQueue: MTLCommandQueue?

  private var time: Float = 0.0
  private var viewportSize: CGSize = .zero

  init(device: MTLDevice) {
    NSLog("[ZoomedMazeRenderer] 🔧 Initializing renderer")
    self.commandQueue = device.makeCommandQueue()

    guard let library = device.makeDefaultLibrary() else {
      NSLog("[ZoomedMazeRenderer] ❌ Failed to create Metal library")
      print("Failed to create Metal library")
      return
    }
    NSLog("[ZoomedMazeRenderer] ✅ Metal library created")

    guard let kernelFunction = library.makeFunction(name: "zoomedMazeCompute") else {
      NSLog("[ZoomedMazeRenderer] ❌ Failed to find zoomedMazeCompute function")
      print("Failed to find zoomedMazeCompute function")
      return
    }
    NSLog("[ZoomedMazeRenderer] ✅ Found kernel function: zoomedMazeCompute")

    do {
      pipelineState = try device.makeComputePipelineState(function: kernelFunction)
      NSLog("[ZoomedMazeRenderer] ✅ Compute pipeline state created successfully")
    } catch {
      NSLog("[ZoomedMazeRenderer] ❌ Failed to create compute pipeline state: \(error)")
      print("Failed to create compute pipeline state: \(error)")
    }
  }

  func updateViewportSize(_ size: CGSize) {
    NSLog("[ZoomedMazeRenderer] 📐 Viewport size updated: \(size)")
    self.viewportSize = size
  }

  private var drawCount: Int = 0
  private var frameSkipCounter: Int = 0

  func draw(in view: MTKView) {
    // 极限优化: 跳帧实现更低帧率（每3帧渲染1帧 = 0.33 FPS）
    frameSkipCounter += 1
    if frameSkipCounter < 3 {
      return  // 跳过这一帧
    }
    frameSkipCounter = 0

    // 前几帧输出日志
    if drawCount < 3 {
      NSLog(
        "[ZoomedMazeRenderer] 🎨 Draw call #\(drawCount) - viewportSize: \(viewportSize), time: \(time)"
      )
      drawCount += 1
    }

    guard let drawable = view.currentDrawable else {
      NSLog("[ZoomedMazeRenderer] ❌ No drawable available")
      return
    }

    guard let pipelineState = pipelineState else {
      NSLog("[ZoomedMazeRenderer] ❌ No pipeline state available")
      return
    }

    guard let commandQueue = commandQueue else {
      NSLog("[ZoomedMazeRenderer] ❌ No command queue available")
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

    // 平衡优化: 提高渲染分辨率改善识别度（允许5%性能增加）
    // 性能分析: 分辨率对GPU影响是平方关系, 0.17² = 2.89% 像素
    let renderScale: CGFloat = 0.17
    var renderScaleVar = Float(renderScale)
    commandEncoder.setBytes(&renderScaleVar, length: MemoryLayout<Float>.stride, index: 1)

    let renderWidth = Int(viewportSize.width * renderScale)
    let renderHeight = Int(viewportSize.height * renderScale)

    // 修复黑边: 线程组需要基于完整纹理大小，而不是缩放后的大小
    // 因为每个线程渲染 blockSize×blockSize 的像素块
    let blockSize = Int(1.0 / renderScale)
    let threadGroupSize = MTLSize(width: 16, height: 16, depth: 1)

    // 计算需要多少线程来覆盖完整纹理（考虑blockSize）
    let threadsNeededX = (Int(viewportSize.width) + blockSize - 1) / blockSize
    let threadsNeededY = (Int(viewportSize.height) + blockSize - 1) / blockSize

    let threadGroups = MTLSize(
      width: (threadsNeededX + threadGroupSize.width - 1) / threadGroupSize.width,
      height: (threadsNeededY + threadGroupSize.height - 1) / threadGroupSize.height,
      depth: 1
    )

    commandEncoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupSize)
    commandEncoder.endEncoding()

    commandBuffer.present(drawable)
    commandBuffer.commit()
  }
}
