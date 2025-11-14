import MetalKit

class MandalaEffect: VisualEffect {
  var name: String = "Mandala"
  var displayName: String = "Mandala"

  // 15 FPS for smooth animation with reduced performance
  var preferredFramesPerSecond: Int = 15
  // 8 FPS when occluded
  var occludedFramesPerSecond: Int = 8

  private var renderer: MandalaRenderer?

  func setup(device: MTLDevice, size: CGSize) {
    NSLog("[MandalaEffect] 🎬 Setting up Mandala effect with size: \(size)")
    renderer = MandalaRenderer(device: device)
    renderer?.updateViewportSize(size)
  }

  func updateViewportSize(_ size: CGSize) {
    NSLog("[MandalaEffect] 📏 Updating viewport size to: \(size)")
    renderer?.updateViewportSize(size)
  }

  func handleSignificantResize(to size: CGSize) {
    NSLog("[MandalaEffect] 🔄 Handling significant resize to: \(size)")
    updateViewportSize(size)
  }

  func update(currentTime: CFTimeInterval) {
    // Time is handled in shader
  }

  func draw(in view: MTKView) {
    renderer?.draw(in: view)
  }

  func setUpdateRate(_ rate: Double) {
    // Not needed
  }
}
