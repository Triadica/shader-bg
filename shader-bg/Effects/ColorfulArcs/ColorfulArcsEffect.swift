import MetalKit

class ColorfulArcsEffect: VisualEffect {
  var name: String = "ColorfulArcs"
  var displayName: String = "Colorful Arcs"

  // 30 FPS for smooth animation
  var preferredFramesPerSecond: Int = 30
  // 15 FPS when occluded
  var occludedFramesPerSecond: Int = 15

  private var renderer: ColorfulArcsRenderer?

  func setup(device: MTLDevice, size: CGSize) {
    NSLog("[ColorfulArcsEffect] 🎬 Setting up Colorful Arcs effect with size: \(size)")
    renderer = ColorfulArcsRenderer(device: device)
    renderer?.updateViewportSize(size)
  }

  func updateViewportSize(_ size: CGSize) {
    NSLog("[ColorfulArcsEffect] 📏 Updating viewport size to: \(size)")
    renderer?.updateViewportSize(size)
  }

  func handleSignificantResize(to size: CGSize) {
    NSLog("[ColorfulArcsEffect] 🔄 Handling significant resize to: \(size)")
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
