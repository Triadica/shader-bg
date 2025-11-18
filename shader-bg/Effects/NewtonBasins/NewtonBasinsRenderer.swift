import Foundation
import Metal
import MetalKit

class NewtonBasinsRenderer {
  private var device: MTLDevice
  private var commandQueue: MTLCommandQueue
  private var pipelineState: MTLRenderPipelineState
  private var startTime: Date = Date()
  private var viewportSize: CGSize = .zero

  init?(device: MTLDevice) {
    self.device = device

    guard let queue = device.makeCommandQueue() else {
      NSLog("[NewtonBasinsRenderer] ❌ Failed to create command queue")
      return nil
    }
    self.commandQueue = queue

    do {
      let library = device.makeDefaultLibrary()
      guard let vertexFunction = library?.makeFunction(name: "newtonBasins_vertex"),
        let fragmentFunction = library?.makeFunction(name: "newtonBasins_fragment")
      else {
        NSLog("[NewtonBasinsRenderer] ❌ Failed to find shader functions")
        return nil
      }

      let pipelineDescriptor = MTLRenderPipelineDescriptor()
      pipelineDescriptor.vertexFunction = vertexFunction
      pipelineDescriptor.fragmentFunction = fragmentFunction
      pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm

      self.pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
      NSLog("[NewtonBasinsRenderer] ✅ Pipeline state created successfully")
    } catch {
      NSLog("[NewtonBasinsRenderer] ❌ Failed to create render pipeline state: \(error)")
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

    // 动画速度减少到 1/64 (1/8 * 1/8)
    var params = NewtonBasinsData()
    params.time = Float(Date().timeIntervalSince(startTime)) * 0.015625  // 1/64 速度
    params.resolution = SIMD2<Float>(Float(viewportSize.width), Float(viewportSize.height))

    renderEncoder.setFragmentBytes(&params, length: MemoryLayout<NewtonBasinsData>.stride, index: 0)
    renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)

    renderEncoder.endEncoding()
    commandBuffer.present(drawable)
    commandBuffer.commit()
  }
}
