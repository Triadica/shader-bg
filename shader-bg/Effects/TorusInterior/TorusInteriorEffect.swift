import Metal
import MetalKit

class TorusInteriorEffect: VisualEffect {
  var name: String = "TorusInterior"
  var displayName: String = "Torus Interior"
  var preferredFramesPerSecond: Int = 5  // 进一步降低到 5 FPS (15 FPS 的 1/3)
  var occludedFramesPerSecond: Int = 3  // 降低到 3 FPS

  private var renderer: TorusInteriorRenderer?

  func setup(device: MTLDevice, size: CGSize) {
    NSLog("[TorusInteriorEffect] 🎬 Setting up effect with size: \(size)")
    renderer = TorusInteriorRenderer(device: device)
    renderer?.updateViewportSize(size)
    NSLog("[TorusInteriorEffect] ✅ Effect setup complete")
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
    if renderer == nil {
      NSLog("[TorusInteriorEffect] ⚠️ Renderer is nil in draw()")
    }
    renderer?.draw(in: view)
  }

  func setUpdateRate(_ rate: Double) {
    // Handle update rate changes if needed
  }
}
