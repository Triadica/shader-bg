import MetalKit

class DomainRepetitionEffect: VisualEffect {
  var name: String = "DomainRepetition"
  var displayName: String = "Domain Repetition"

  private var renderer: DomainRepetitionRenderer?
  private var commandQueue: MTLCommandQueue?
  private var lastUpdateTime: Double = 0

  func setup(device: MTLDevice, size: CGSize) {
    commandQueue = device.makeCommandQueue()
    renderer = DomainRepetitionRenderer(device: device)
  }

  func update(currentTime: Double) {
    guard let renderer = renderer else { return }

    // 使用较低帧率 (15 FPS) - Raymarching 计算量较大
    let baseRate = PerformanceManager.shared.highPerformanceRate  // 15 FPS
    let currentRate = PerformanceManager.shared.currentUpdateRate

    // 根据性能调整更新频率
    let shouldUpdate = lastUpdateTime == 0 || (currentTime - lastUpdateTime) >= (1.0 / currentRate)

    if shouldUpdate {
      let frameRate = baseRate
      let normalizedDelta = 1.0 / frameRate

      renderer.updateInterval = normalizedDelta
      lastUpdateTime = currentTime
    }
  }

  func draw(in view: MTKView) {
    renderer?.draw(in: view)
  }

  func updateViewportSize(_ size: CGSize) {
    // Shader 会自动适应新尺寸
  }

  func setUpdateRate(_ rate: Double) {
    // 性能管理由 PerformanceManager 处理
  }
}
