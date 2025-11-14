import Metal
import MetalKit

class SpiralStainedGlassRenderer {
  private var device: MTLDevice
  private var pipelineState: MTLComputePipelineState!
  private var viewportSize: CGSize

  private var time: Float = 0.0
  var updateInterval: Double = 1.0 / 30.0

  init(device: MTLDevice, size: CGSize) {
    self.device = device
    self.viewportSize = size
    print("🔵 [SpiralStainedGlass] 初始化 Renderer，size: \(size)")
    setupPipeline()
  }

  private func setupPipeline() {
    print("🔵 [SpiralStainedGlass] 开始设置 pipeline...")
    guard let library = device.makeDefaultLibrary() else {
      fatalError("无法创建 Metal library")
    }

    print("🔵 [SpiralStainedGlass] 查找 spiralStainedGlassCompute 函数...")
    guard let function = library.makeFunction(name: "spiralStainedGlassCompute") else {
      fatalError("无法找到 spiralStainedGlassCompute 函数")
    }
    print("✅ [SpiralStainedGlass] 找到 spiralStainedGlassCompute 函数")

    do {
      pipelineState = try device.makeComputePipelineState(function: function)
      print("✅ [SpiralStainedGlass] Pipeline state 创建成功")
    } catch {
      fatalError("无法创建 pipeline state: \(error)")
    }
  }

  func update(currentTime: Double) {
    time += Float(updateInterval)
  }

  func draw(commandBuffer: MTLCommandBuffer, view: MTKView) {
    guard let drawable = view.currentDrawable,
      let computeEncoder = commandBuffer.makeComputeCommandEncoder()
    else {
      return
    }

    var data = SpiralStainedGlassData(
      time: time,
      resolution: SIMD2<Float>(Float(viewportSize.width), Float(viewportSize.height))
    )

    computeEncoder.setComputePipelineState(pipelineState)
    computeEncoder.setTexture(drawable.texture, index: 0)
    computeEncoder.setBytes(&data, length: MemoryLayout<SpiralStainedGlassData>.stride, index: 0)

    let threadGroupSize = MTLSize(width: 16, height: 16, depth: 1)
    let threadGroups = MTLSize(
      width: (drawable.texture.width + threadGroupSize.width - 1) / threadGroupSize.width,
      height: (drawable.texture.height + threadGroupSize.height - 1) / threadGroupSize.height,
      depth: 1
    )

    computeEncoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupSize)
    computeEncoder.endEncoding()

    commandBuffer.present(drawable)
    commandBuffer.commit()
  }

  func resize(size: CGSize) {
    viewportSize = size
  }
}
