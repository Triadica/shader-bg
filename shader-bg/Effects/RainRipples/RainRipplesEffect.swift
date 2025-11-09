import MetalKit

class RainRipplesEffect: VisualEffect {
  var name: String = "RainRipples"
  var displayName: String = "Rain Ripples"
  var preferredFramesPerSecond: Int = 30
  var occludedFramesPerSecond: Int = 15

  private var renderer: RainRipplesRenderer?

  func setup(device: MTLDevice, size: CGSize) {
    NSLog("[RainRipplesEffect] 🎬 Setting up Rain Ripples effect with size: \(size)")
    renderer = RainRipplesRenderer(device: device)
    renderer?.updateViewportSize(size)
  }

  func updateViewportSize(_ size: CGSize) {
    NSLog("[RainRipplesEffect] 📏 Updating viewport size to: \(size)")
    renderer?.updateViewportSize(size)
  }

  func handleSignificantResize(to size: CGSize) {
    NSLog("[RainRipplesEffect] 🔄 Handling significant resize to: \(size)")
    updateViewportSize(size)
  }

  func update(currentTime: CFTimeInterval) {
    // 不需要额外的更新逻辑，时间在 shader 中处理
  }

  func draw(in view: MTKView) {
    renderer?.draw(in: view)
  }

  func setUpdateRate(_ rate: Double) {
    // 不需要实现
  }
}
