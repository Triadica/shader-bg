import Metal
import MetalKit

class ElectricityRenderer {
  private var device: MTLDevice
  private var pipelineState: MTLComputePipelineState!
  private var viewportSize: CGSize
  
  private var time: Float = 0.0
  var updateInterval: Double = 1.0 / 30.0
  
  init(device: MTLDevice, size: CGSize) {
    self.device = device
    self.viewportSize = size
    setupPipeline()
  }
  
  private func setupPipeline() {
    guard let library = device.makeDefaultLibrary() else {
      fatalError("无法创建 Metal library")
    }
    
    guard let function = library.makeFunction(name: "electricityCompute") else {
      fatalError("无法找到 electricityCompute 函数")
    }
    
    do {
      pipelineState = try device.makeComputePipelineState(function: function)
    } catch {
      fatalError("无法创建 pipeline state: \(error)")
    }
  }
  
  func update(currentTime: Double) {
    time += Float(updateInterval)
  }
  
  func draw(commandBuffer: MTLCommandBuffer, view: MTKView) {
    guard let drawable = view.currentDrawable,
          let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
      return
    }
    
    var data = ElectricityData(
      time: time,
      resolution: SIMD2<Float>(Float(viewportSize.width), Float(viewportSize.height))
    )
    
    computeEncoder.setComputePipelineState(pipelineState)
    computeEncoder.setTexture(drawable.texture, index: 0)
    computeEncoder.setBytes(&data, length: MemoryLayout<ElectricityData>.stride, index: 0)
    
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
