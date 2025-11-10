import MetalKit

class SineMountainsEffect: VisualEffect {
  var name: String = "SineMountains"
  var displayName: String = "Sine Mountains"

  // 20 FPS for smooth animation
  var preferredFramesPerSecond: Int = 20
  // 10 FPS when occluded
  var occludedFramesPerSecond: Int = 10

  private var renderer: SineMountainsRenderer?

  func setup(device: MTLDevice, size: CGSize) {
    NSLog("[SineMountainsEffect] 🎬 Setting up Sine Mountains effect with size: \(size)")
    renderer = SineMountainsRenderer(device: device)
    renderer?.updateViewportSize(size)
  }

  func updateViewportSize(_ size: CGSize) {
    NSLog("[SineMountainsEffect] 📏 Updating viewport size to: \(size)")
    renderer?.updateViewportSize(size)
  }

  func handleSignificantResize(to size: CGSize) {
    NSLog("[SineMountainsEffect] 🔄 Handling significant resize to: \(size)")
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
