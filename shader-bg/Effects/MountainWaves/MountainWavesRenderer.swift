import Foundation
import Metal
import MetalKit

class MountainWavesRenderer {
  private var device: MTLDevice
  private var pipelineState: MTLRenderPipelineState
  private var commandQueue: MTLCommandQueue
  private var startTime: Date = Date()
  private var viewportSize: CGSize = .zero

  init?(device: MTLDevice) {
    self.device = device

    do {
      let library = device.makeDefaultLibrary()
      guard let vertexFunction = library?.makeFunction(name: "mountainWaves_vertex"),
        let fragmentFunction = library?.makeFunction(name: "mountainWaves_fragment")
      else {
        NSLog("[MountainWavesRenderer] ❌ Failed to find shader functions")
        return nil
      }

      let pipelineDescriptor = MTLRenderPipelineDescriptor()
      pipelineDescriptor.vertexFunction = vertexFunction
      pipelineDescriptor.fragmentFunction = fragmentFunction
      pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm

      self.pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
      guard let commandQueue = device.makeCommandQueue() else {
        NSLog("[MountainWavesRenderer] ❌ Failed to create command queue")
        return nil
      }
      self.commandQueue = commandQueue
      NSLog("[MountainWavesRenderer] ✅ Pipeline state created successfully")
    } catch {
      NSLog("[MountainWavesRenderer] ❌ Failed to create render pipeline state: \(error)")
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

    // 再次放慢速度到 0.0625x (约 1/16)，让动画更平缓
    var params = MountainWavesData(
      time: Float(Date().timeIntervalSince(startTime)) * 0.0625,
      resolution: SIMD2<Float>(Float(viewportSize.width), Float(viewportSize.height)),
      mouse: SIMD2<Float>(0.5, 0.5),
      padding: 0.0
    )

    renderEncoder.setFragmentBytes(
      &params, length: MemoryLayout<MountainWavesData>.stride, index: 0)
    renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)

    renderEncoder.endEncoding()
    commandBuffer.present(drawable)
    commandBuffer.commit()
  }
}
