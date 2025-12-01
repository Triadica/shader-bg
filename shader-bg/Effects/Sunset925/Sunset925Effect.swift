import Metal
import MetalKit

class Sunset925Effect: VisualEffect {
  var name: String = "Sunset925"
  var displayName: String = "Sunset 9:25"
  var preferredFramesPerSecond: Int = 15  // 降低帧率以减少 GPU 开销
  var occludedFramesPerSecond: Int = 10

  private var renderer: Sunset925Renderer?

  func setup(device: MTLDevice, size: CGSize) {
    renderer = Sunset925Renderer(device: device)
  }

  func updateViewportSize(_ size: CGSize) {
    renderer?.updateViewportSize(size)
  }

  func handleSignificantResize(to size: CGSize) {
    // Handle significant resize if needed
  }

  func update(currentTime: CFTimeInterval) {
    let updateRate = PerformanceManager.shared.highPerformanceRate
    let _ = updateRate
  }

  func draw(in view: MTKView) {
    renderer?.draw(in: view)
  }

  func setUpdateRate(_ rate: Double) {
    // Handle update rate changes if needed
  }
}
