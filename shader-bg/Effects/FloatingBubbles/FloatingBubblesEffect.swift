import Metal
import MetalKit

class FloatingBubblesEffect: VisualEffect {
  var name: String = "FloatingBubbles"
  var displayName: String = "Floating Bubbles"
  var preferredFramesPerSecond: Int = 30
  var occludedFramesPerSecond: Int = 15

  private var renderer: FloatingBubblesRenderer?

  func setup(device: MTLDevice, size: CGSize) {
    renderer = FloatingBubblesRenderer(device: device)
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
