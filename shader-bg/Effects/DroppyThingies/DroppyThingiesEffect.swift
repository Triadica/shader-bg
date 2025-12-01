import Metal
import MetalKit

class DroppyThingiesEffect: VisualEffect {
  var name: String = "DroppyThingies"
  var displayName: String = "Droppy Thingies"
  var preferredFramesPerSecond: Int = 30
  var occludedFramesPerSecond: Int = 15

  private var renderer: DroppyThingiesRenderer?

  func setup(device: MTLDevice, size: CGSize) {
    renderer = DroppyThingiesRenderer(device: device)
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
