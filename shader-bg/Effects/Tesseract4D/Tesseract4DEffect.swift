import MetalKit

class Tesseract4DEffect: VisualEffect {
  var name: String = "Tesseract4D"
  var displayName: String = "4D Tesseract"

  private var renderer: Tesseract4DRenderer?
  private var commandQueue: MTLCommandQueue?
  private var lastUpdateTime: Double = 0

  func setup(device: MTLDevice, size: CGSize) {
    print("🔵 [Tesseract4D] 开始初始化...")
    commandQueue = device.makeCommandQueue()
    renderer = Tesseract4DRenderer(device: device, size: size)
    print("✅ [Tesseract4D] 初始化完成，准备渲染")
  }

  func update(currentTime: Double) {
    guard let renderer = renderer else { return }

    let baseRate = PerformanceManager.shared.highPerformanceRate
    let currentRate = PerformanceManager.shared.currentUpdateRate

    // 根据性能调整更新频率
    let shouldUpdate = lastUpdateTime == 0 || (currentTime - lastUpdateTime) >= (1.0 / currentRate)

    if shouldUpdate {
      // 根据实际帧率调整更新速度
      let frameRate = baseRate
      let normalizedDelta = 1.0 / frameRate

      renderer.updateInterval = normalizedDelta
      renderer.update(currentTime: currentTime)
      lastUpdateTime = currentTime
    }
  }

  func draw(in view: MTKView) {
    guard let renderer = renderer,
      let commandQueue = commandQueue,
      let commandBuffer = commandQueue.makeCommandBuffer()
    else {
      print("⚠️ [Tesseract4D] draw 失败：renderer/commandQueue/commandBuffer 为 nil")
      return
    }

    renderer.draw(commandBuffer: commandBuffer, view: view)
  }

  func updateViewportSize(_ size: CGSize) {
    renderer?.resize(size: size)
  }

  func setUpdateRate(_ rate: Double) {
    // 性能管理由 PerformanceManager 处理
  }
}
