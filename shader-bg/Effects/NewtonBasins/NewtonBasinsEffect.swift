import MetalKit

class NewtonBasinsEffect: VisualEffect {
  var name: String = "newton_basins"
  var displayName: String = "Newton Basins"

  var preferredFramesPerSecond: Int = 20
  var occludedFramesPerSecond: Int = 10

  private var renderer: NewtonBasinsRenderer?

  func setup(device: MTLDevice, size: CGSize) {
    NSLog("[NewtonBasinsEffect] 🎬 Setting up Newton Basins effect with size: \(size)")
    renderer = NewtonBasinsRenderer(device: device)
    renderer?.updateViewportSize(size)
  }

  func updateViewportSize(_ size: CGSize) {
    NSLog("[NewtonBasinsEffect] 📏 Updating viewport size to: \(size)")
    renderer?.updateViewportSize(size)
  }

  func handleSignificantResize(to size: CGSize) {
    NSLog("[NewtonBasinsEffect] 🔄 Handling significant resize to: \(size)")
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
