import MetalKit

class ZoomedMazeEffect: VisualEffect {
  var name: String = "ZoomedMaze"
  var displayName: String = "Zoomed Maze"

  // 超低帧率 0.375 FPS (3/8)，进一步降低GPU负载
  var preferredFramesPerSecond: Int = 1
  // 遮挡时降到最低
  var occludedFramesPerSecond: Int = 1

  private var renderer: ZoomedMazeRenderer?

  func setup(device: MTLDevice, size: CGSize) {
    NSLog("[ZoomedMazeEffect] 🎬 Setting up Zoomed Maze effect with size: \(size)")
    renderer = ZoomedMazeRenderer(device: device)
    renderer?.updateViewportSize(size)
  }

  func updateViewportSize(_ size: CGSize) {
    NSLog("[ZoomedMazeEffect] 📏 Updating viewport size to: \(size)")
    renderer?.updateViewportSize(size)
  }

  func handleSignificantResize(to size: CGSize) {
    NSLog("[ZoomedMazeEffect] 🔄 Handling significant resize to: \(size)")
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
