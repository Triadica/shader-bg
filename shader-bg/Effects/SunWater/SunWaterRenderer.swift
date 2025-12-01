import Foundation
import Metal
import MetalKit

class SunWaterRenderer {
  private var device: MTLDevice
  private var commandQueue: MTLCommandQueue
  private var pipelineState: MTLRenderPipelineState
  private var startTime: Date = Date()
  private var viewportSize: CGSize = .zero

  init?(device: MTLDevice) {
    self.device = device

    guard let queue = device.makeCommandQueue() else {
      NSLog("[SunWaterRenderer] ❌ Failed to create command queue")
      return nil
    }
    self.commandQueue = queue

    do {
      let library = device.makeDefaultLibrary()
      guard let vertexFunction = library?.makeFunction(name: "sunWater_vertex"),
        let fragmentFunction = library?.makeFunction(name: "sunWater_fragment")
      else {
        NSLog("[SunWaterRenderer] ❌ Failed to find shader functions")
        return nil
      }

      let pipelineDescriptor = MTLRenderPipelineDescriptor()
      pipelineDescriptor.vertexFunction = vertexFunction
      pipelineDescriptor.fragmentFunction = fragmentFunction
      pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm

      self.pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
      NSLog("[SunWaterRenderer] ✅ Pipeline state created successfully")
    } catch {
      NSLog("[SunWaterRenderer] ❌ Failed to create render pipeline state: \(error)")
      return nil
    }

    startTime = Date()
  }

  func updateViewportSize(_ size: CGSize) {
    viewportSize = size
  }

  func draw(in view: MTKView) {
    guard let drawable = view.currentDrawable,
      let commandBuffer = commandQueue.makeCommandBuffer(),
      let renderPassDescriptor = view.currentRenderPassDescriptor,
      let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
    else {
      return
    }

    renderEncoder.setRenderPipelineState(pipelineState)

    // 速度减少到 1/4
    var params = SunWaterData(
      time: Float(Date().timeIntervalSince(startTime)) * 0.25,
      resolution: SIMD2<Float>(Float(viewportSize.width), Float(viewportSize.height)),
      mouse: SIMD2<Float>(0.5, 0.5),
      padding: 0.0
    )

    renderEncoder.setFragmentBytes(&params, length: MemoryLayout<SunWaterData>.stride, index: 0)
    renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)

    renderEncoder.endEncoding()
    commandBuffer.present(drawable)
    commandBuffer.commit()
  }
}
